import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Manages the app-private directory where encrypted vault files and
/// thumbnails live. This directory is not accessible to other apps and is
/// removed automatically on uninstall — but the files inside are ALSO
/// individually encrypted, so even a rooted-device file copy is useless
/// without the vault credential.
class FileManager {
  FileManager._();
  static final FileManager instance = FileManager._();

  Directory? _vaultDir;
  Directory? _thumbDir;
  Directory? _tempDir;

  Future<Directory> get vaultDir async {
    if (_vaultDir != null) return _vaultDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'vault', 'files'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _vaultDir = dir;
    return dir;
  }

  Future<Directory> get thumbnailDir async {
    if (_thumbDir != null) return _thumbDir!;
    final appDir = await getApplicationSupportDirectory();
    final dir = Directory(p.join(appDir.path, 'vault', 'thumbnails'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _thumbDir = dir;
    return dir;
  }

  Future<Directory> get tempDir async {
    if (_tempDir != null) return _tempDir!;
    final appDir = await getTemporaryDirectory();
    final dir = Directory(p.join(appDir.path, 'vault_tmp'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _tempDir = dir;
    return dir;
  }

  Future<File> encryptedFilePath(String encryptedFileName) async {
    final dir = await vaultDir;
    return File(p.join(dir.path, encryptedFileName));
  }

  Future<File> thumbnailFilePath(String thumbFileName) async {
    final dir = await thumbnailDir;
    return File(p.join(dir.path, thumbFileName));
  }

  Future<void> deleteEncryptedFile(String encryptedFileName) async {
    final f = await encryptedFilePath(encryptedFileName);
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteThumbnail(String thumbFileName) async {
    final f = await thumbnailFilePath(thumbFileName);
    if (await f.exists()) await f.delete();
  }

  /// Total bytes used by the vault (encrypted files + thumbnails).
  Future<int> totalStorageUsed() async {
    int total = 0;
    for (final dir in [await vaultDir, await thumbnailDir]) {
      await for (final entity in dir.list()) {
        if (entity is File) total += await entity.length();
      }
    }
    return total;
  }

  Future<void> wipeEverything() async {
    for (final dir in [await vaultDir, await thumbnailDir, await tempDir]) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    }
  }
}
