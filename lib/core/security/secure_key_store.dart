import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin abstraction over platform-secure storage.
///
/// On Android, `flutter_secure_storage` stores values in `EncryptedSharedPreferences`,
/// with the encryption key itself protected by the Android Keystore
/// (hardware-backed on supported devices). This satisfies "key protection via
/// Android Keystore" without hand-rolling a Kotlin MethodChannel bridge.
///
/// If you later want a raw Keystore MethodChannel (e.g. for StrongBox pinning
/// or custom key attestation), implement this same interface natively and
/// swap the implementation — nothing above this layer needs to change.
abstract class SecureKeyStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class AndroidKeystoreSecureStore implements SecureKeyStore {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
