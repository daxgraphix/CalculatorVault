import 'package:cryptography/cryptography.dart';

import '../crypto/crypto_service.dart';
import 'secure_key_store.dart';

enum CredentialType { pin, password }

/// Weak-credential rejection list, checked at setup time.
const kWeakPins = ['0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777', '8888', '9999', '1234', '4321', '0123'];

class CredentialManager {
  CredentialManager({SecureKeyStore? keyStore})
      : _keyStore = keyStore ?? AndroidKeystoreSecureStore();

  final SecureKeyStore _keyStore;
  final _crypto = CryptoService.instance;

  static const _kSaltKey = 'cv_salt';
  static const _kVerifierKey = 'cv_verifier';
  static const _kWrappedMasterKeyCt = 'cv_mk_ct';
  static const _kWrappedMasterKeyNonce = 'cv_mk_nonce';
  static const _kWrappedMasterKeyMac = 'cv_mk_mac';
  static const _kCredentialType = 'cv_cred_type';
  static const _kFailedAttempts = 'cv_failed_attempts';
  static const _kLockoutUntil = 'cv_lockout_until';

  bool isValidPin(String pin) {
    if (pin.length < 4 || pin.length > 8) return false;
    if (!RegExp(r'^\d+$').hasMatch(pin)) return false;
    if (kWeakPins.contains(pin)) return false;
    return true;
  }

  bool isValidPassword(String password) {
    if (password.length < 8) return false;
    return true;
  }

  Future<bool> hasVaultBeenSetUp() async {
    final v = await _keyStore.read(_kVerifierKey);
    return v != null;
  }

  /// Creates the vault: generates a random master key, derives a wrapping
  /// key from the PIN/password via Argon2id, wraps the master key with it,
  /// and stores everything except the credential and the raw master key.
  Future<void> setUpCredential({
    required String credential,
    required CredentialType type,
  }) async {
    final derived = await _crypto.deriveKey(credential: credential);
    final verifier = await _crypto.credentialVerifier(derived.secretKey);
    final masterKey = await _crypto.generateMasterKey();
    final wrapped = await _crypto.wrapMasterKey(
      masterKey: masterKey,
      wrappingKey: derived.secretKey,
    );

    await _keyStore.write(_kSaltKey, _bytesToHex(derived.salt));
    await _keyStore.write(_kVerifierKey, verifier);
    await _keyStore.write(_kWrappedMasterKeyCt, wrapped['ciphertext']!);
    await _keyStore.write(_kWrappedMasterKeyNonce, wrapped['nonce']!);
    await _keyStore.write(_kWrappedMasterKeyMac, wrapped['mac']!);
    await _keyStore.write(_kCredentialType, type.name);
  }

  Future<CredentialType?> getCredentialType() async {
    final t = await _keyStore.read(_kCredentialType);
    if (t == null) return null;
    return CredentialType.values.firstWhere((e) => e.name == t);
  }

  /// Verifies the credential and, if correct, returns the unwrapped master
  /// key (kept only in memory by the caller). Returns null if incorrect.
  Future<SecretKey?> verifyAndUnwrap(String credential) async {
    if (await isLockedOut()) return null;

    final saltHex = await _keyStore.read(_kSaltKey);
    final verifier = await _keyStore.read(_kVerifierKey);
    if (saltHex == null || verifier == null) return null;

    final salt = _hexToBytes(saltHex);
    final derived = await _crypto.deriveKey(credential: credential, existingSalt: salt);
    final candidateVerifier = await _crypto.credentialVerifier(derived.secretKey);

    if (candidateVerifier != verifier) {
      await _recordFailedAttempt();
      return null;
    }

    await _resetFailedAttempts();

    final ct = await _keyStore.read(_kWrappedMasterKeyCt);
    final nonce = await _keyStore.read(_kWrappedMasterKeyNonce);
    final mac = await _keyStore.read(_kWrappedMasterKeyMac);
    if (ct == null || nonce == null || mac == null) return null;

    return _crypto.unwrapMasterKey(
      wrapped: {'ciphertext': ct, 'nonce': nonce, 'mac': mac},
      wrappingKey: derived.secretKey,
    );
  }

  /// Changes the PIN/password: re-wraps the existing master key under a new
  /// derived key. Does NOT require re-encrypting any vault files.
  Future<bool> changeCredential({
    required String currentCredential,
    required String newCredential,
    required CredentialType newType,
  }) async {
    final masterKey = await verifyAndUnwrap(currentCredential);
    if (masterKey == null) return false;

    final derived = await _crypto.deriveKey(credential: newCredential);
    final verifier = await _crypto.credentialVerifier(derived.secretKey);
    final wrapped = await _crypto.wrapMasterKey(masterKey: masterKey, wrappingKey: derived.secretKey);

    await _keyStore.write(_kSaltKey, _bytesToHex(derived.salt));
    await _keyStore.write(_kVerifierKey, verifier);
    await _keyStore.write(_kWrappedMasterKeyCt, wrapped['ciphertext']!);
    await _keyStore.write(_kWrappedMasterKeyNonce, wrapped['nonce']!);
    await _keyStore.write(_kWrappedMasterKeyMac, wrapped['mac']!);
    await _keyStore.write(_kCredentialType, newType.name);
    return true;
  }

  // -- Failed attempt / lockout handling -----------------------------------

  Future<int> getFailedAttempts() async {
    final raw = await _keyStore.read(_kFailedAttempts);
    return int.tryParse(raw ?? '0') ?? 0;
  }

  Future<void> _recordFailedAttempt() async {
    final attempts = await getFailedAttempts() + 1;
    await _keyStore.write(_kFailedAttempts, attempts.toString());
    if (attempts >= 5) {
      // Exponential backoff, capped at 5 minutes.
      final lockoutSeconds = (30 * (attempts - 4)).clamp(30, 300);
      final until = DateTime.now().add(Duration(seconds: lockoutSeconds));
      await _keyStore.write(_kLockoutUntil, until.toIso8601String());
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _keyStore.delete(_kFailedAttempts);
    await _keyStore.delete(_kLockoutUntil);
  }

  Future<bool> isLockedOut() async {
    final until = await _keyStore.read(_kLockoutUntil);
    if (until == null) return false;
    return DateTime.now().isBefore(DateTime.parse(until));
  }

  Future<Duration?> lockoutRemaining() async {
    final until = await _keyStore.read(_kLockoutUntil);
    if (until == null) return null;
    final dt = DateTime.parse(until);
    final remaining = dt.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Wipes ALL credential and key material. Used by app reset. Does not
  /// delete vault files themselves — call VaultResetService for that.
  Future<void> wipeAll() => _keyStore.deleteAll();

  String _bytesToHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
