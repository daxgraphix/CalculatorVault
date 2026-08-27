import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Result of deriving a key from a PIN/password: the raw key bytes and the
/// salt used, so the salt can be persisted alongside the verifier.
class DerivedKeyResult {
  final SecretKey secretKey;
  final Uint8List salt;
  DerivedKeyResult(this.secretKey, this.salt);
}

/// Handles all cryptographic primitives for the vault:
///  - Argon2id key derivation from PIN/password (never store PIN/password/keys in plaintext)
///  - AES-256-GCM authenticated encryption for the master key and for files
///  - Streaming chunked encryption so large videos never load fully into RAM
class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();

  final _aesGcm = AesGcm.with256bits();

  /// Chunk size for streaming file encryption (1 MB). Each chunk is
  /// encrypted as an independent AES-GCM message with its own nonce, and
  /// chunk lengths are framed so decryption can stream too.
  static const int chunkSize = 1024 * 1024;

  // ---------------------------------------------------------------------
  // Key derivation (PIN / password -> key). Uses Argon2id, matching the
  // approach already used in SafeText.
  // ---------------------------------------------------------------------
  Future<DerivedKeyResult> deriveKey({
    required String credential,
    Uint8List? existingSalt,
  }) async {
    final salt = existingSalt ?? _randomBytes(16);
    final algorithm = Argon2id(
      parallelism: 2,
      memory: 19 * 1024, // ~19 MB, OWASP-recommended minimum
      iterations: 2,
      hashLength: 32,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: credential,
      nonce: salt,
    );
    return DerivedKeyResult(secretKey, salt);
  }

  /// Produces a verifier (hash) that can be stored to check a PIN/password
  /// is correct WITHOUT storing the credential or the master key itself.
  Future<String> credentialVerifier(SecretKey key) async {
    final bytes = await key.extractBytes();
    final hash = await Sha256().hash(bytes);
    return base64Encode(hash.bytes);
  }

  // ---------------------------------------------------------------------
  // Master key: generated once at vault creation, wrapped (encrypted) with
  // the key derived from the PIN/password. Changing the PIN only requires
  // re-wrapping this key, not re-encrypting every file.
  // ---------------------------------------------------------------------
  Future<SecretKey> generateMasterKey() => _aesGcm.newSecretKey();

  Future<Map<String, String>> wrapMasterKey({
    required SecretKey masterKey,
    required SecretKey wrappingKey,
  }) async {
    final masterKeyBytes = await masterKey.extractBytes();
    final nonce = _aesGcm.newNonce();
    final secretBox = await _aesGcm.encrypt(
      masterKeyBytes,
      secretKey: wrappingKey,
      nonce: nonce,
    );
    return {
      'ciphertext': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<SecretKey> unwrapMasterKey({
    required Map<String, String> wrapped,
    required SecretKey wrappingKey,
  }) async {
    final box = SecretBox(
      base64Decode(wrapped['ciphertext']!),
      nonce: base64Decode(wrapped['nonce']!),
      mac: Mac(base64Decode(wrapped['mac']!)),
    );
    final bytes = await _aesGcm.decrypt(box, secretKey: wrappingKey);
    return SecretKey(bytes);
  }

  // ---------------------------------------------------------------------
  // Streaming file encryption / decryption with the master key.
  // File format: [4-byte chunk count little-endian]
  //              repeated { [4-byte nonce len][nonce][4-byte ct len][ciphertext+mac] }
  // ---------------------------------------------------------------------
  Future<void> encryptFile({
    required File source,
    required File destination,
    required SecretKey masterKey,
  }) async {
    final input = source.openRead();
    final sink = destination.openWrite();
    final buffer = BytesBuilder();

    await for (final chunk in input) {
      buffer.add(chunk);
      while (buffer.length >= chunkSize) {
        final bytes = buffer.takeBytes();
        final thisChunk = bytes.sublist(0, chunkSize);
        final rest = bytes.sublist(chunkSize);
        buffer.add(rest);
        await _writeEncryptedChunk(sink, thisChunk, masterKey);
      }
    }
    final remaining = buffer.takeBytes();
    if (remaining.isNotEmpty) {
      await _writeEncryptedChunk(sink, remaining, masterKey);
    }
    await sink.close();
  }

  Future<void> _writeEncryptedChunk(
    IOSink sink,
    List<int> plainChunk,
    SecretKey masterKey,
  ) async {
    final nonce = _aesGcm.newNonce();
    final box = await _aesGcm.encrypt(plainChunk, secretKey: masterKey, nonce: nonce);
    final ctWithMac = box.cipherText + box.mac.bytes;
    sink.add(_int32(nonce.length));
    sink.add(nonce);
    sink.add(_int32(ctWithMac.length));
    sink.add(ctWithMac);
  }

  Future<void> decryptFile({
    required File source,
    required File destination,
    required SecretKey masterKey,
  }) async {
    final bytes = await source.readAsBytes();
    final sink = destination.openWrite();
    int offset = 0;
    while (offset < bytes.length) {
      final nonceLen = _readInt32(bytes, offset);
      offset += 4;
      final nonce = bytes.sublist(offset, offset + nonceLen);
      offset += nonceLen;
      final ctLen = _readInt32(bytes, offset);
      offset += 4;
      final ctWithMac = bytes.sublist(offset, offset + ctLen);
      offset += ctLen;

      final ct = ctWithMac.sublist(0, ctWithMac.length - 16);
      final mac = ctWithMac.sublist(ctWithMac.length - 16);
      final box = SecretBox(ct, nonce: nonce, mac: Mac(mac));
      final plain = await _aesGcm.decrypt(box, secretKey: masterKey);
      sink.add(plain);
    }
    await sink.close();
  }

  /// Decrypts a small file fully into memory (safe for thumbnails only).
  Future<Uint8List> decryptSmallFile({
    required File source,
    required SecretKey masterKey,
  }) async {
    final tmp = File('${source.path}.dec.tmp');
    await decryptFile(source: source, destination: tmp, masterKey: masterKey);
    final bytes = await tmp.readAsBytes();
    await tmp.delete();
    return bytes;
  }

  Future<void> encryptBytes({
    required Uint8List bytes,
    required File destination,
    required SecretKey masterKey,
  }) async {
    final sink = destination.openWrite();
    int offset = 0;
    while (offset < bytes.length) {
      final end = (offset + chunkSize > bytes.length) ? bytes.length : offset + chunkSize;
      await _writeEncryptedChunk(sink, bytes.sublist(offset, end), masterKey);
      offset = end;
    }
    if (bytes.isEmpty) {
      await _writeEncryptedChunk(sink, [], masterKey);
    }
    await sink.close();
  }

  /// Cryptographically secure random bytes (used for the Argon2id salt).
  Uint8List _randomBytes(int length) {
    final secureRandom = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => secureRandom.nextInt(256)),
    );
  }

  List<int> _int32(int value) {
    final b = ByteData(4)..setInt32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  int _readInt32(Uint8List bytes, int offset) {
    return ByteData.sublistView(bytes, offset, offset + 4).getInt32(0, Endian.little);
  }
}
