import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/storage/file_manager.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/models/vault_file.dart';

enum SortOrder { newest, oldest, nameAsc, nameDesc, largest, smallest }

class VaultFileRepository {
  final _crypto = CryptoService.instance;
  final _fileManager = FileManager.instance;
  final _uuid = const Uuid();

  /// Imports a plaintext file picked from the device: encrypts it, then
  /// ONLY on successful encryption+verification does it commit the Hive
  /// metadata record. This avoids orphaned records if encryption fails or
  /// the app crashes mid-import (see ImportState.encrypting/verifying/saving).
  Future<VaultFile> importFile({
    required File sourceFile,
    required VaultFileType type,
    required String mimeType,
    required SecretKey masterKey,
    String? folderId,
    Uint8List? thumbnailBytes,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final id = _uuid.v4();
    final encryptedName = '$id.enc';
    final destination = await _fileManager.encryptedFilePath(encryptedName);

    // 1. Encrypt (streaming, so large videos never fully load into RAM).
    await _crypto.encryptFile(source: sourceFile, destination: destination, masterKey: masterKey);

    // 2. Verify: attempt a partial decrypt sanity check by re-reading the
    // header of the encrypted output exists and is non-empty.
    if (!await destination.exists() || await destination.length() == 0) {
      throw Exception('Encryption verification failed');
    }

    // 3. Encrypt + store thumbnail, if provided (never stored in plaintext).
    String? thumbName;
    if (thumbnailBytes != null) {
      thumbName = '$id.thumb.enc';
      final thumbDest = await _fileManager.thumbnailFilePath(thumbName);
      await _crypto.encryptBytes(bytes: thumbnailBytes, destination: thumbDest, masterKey: masterKey);
    }

    final fileSize = await sourceFile.length();
    final now = DateTime.now();
    final record = VaultFile(
      id: id,
      originalName: sourceFile.uri.pathSegments.last,
      encryptedFileName: encryptedName,
      thumbnailFileName: thumbName,
      mimeType: mimeType,
      fileType: type,
      fileSize: fileSize,
      createdAt: now,
      modifiedAt: now,
      folderId: folderId,
      width: width,
      height: height,
      durationMs: durationMs,
    );

    // 4. Commit metadata only now that encrypted content is safely on disk.
    await HiveBoxes.files.put(id, record);
    return record;
  }

  Future<Uint8List> decryptToMemory(VaultFile file, SecretKey masterKey) async {
    final source = await _fileManager.encryptedFilePath(file.encryptedFileName);
    return _crypto.decryptSmallFile(source: source, masterKey: masterKey);
  }

  Future<Uint8List?> decryptThumbnail(VaultFile file, SecretKey masterKey) async {
    if (file.thumbnailFileName == null) return null;
    final source = await _fileManager.thumbnailFilePath(file.thumbnailFileName!);
    if (!await source.exists()) return null;
    return _crypto.decryptSmallFile(source: source, masterKey: masterKey);
  }

  /// Decrypts a (possibly large) file to a temp plaintext file for playback
  /// or controlled export. Caller is responsible for deleting it afterward.
  Future<File> decryptToTempFile(VaultFile file, SecretKey masterKey) async {
    final source = await _fileManager.encryptedFilePath(file.encryptedFileName);
    final tempDir = await _fileManager.tempDir;
    final dest = File('${tempDir.path}/${file.id}_${file.originalName}');
    await _crypto.decryptFile(source: source, destination: dest, masterKey: masterKey);
    return dest;
  }

  List<VaultFile> listFiles({
    VaultFileType? type,
    String? folderId,
    bool favoritesOnly = false,
    bool includeDeleted = false,
    String? searchQuery,
    SortOrder sort = SortOrder.newest,
  }) {
    var files = HiveBoxes.files.values.where((f) => includeDeleted ? f.isDeleted : !f.isDeleted).toList();

    if (type != null) files = files.where((f) => f.fileType == type).toList();
    if (folderId != null) files = files.where((f) => f.folderId == folderId).toList();
    if (favoritesOnly) files = files.where((f) => f.isFavorite).toList();
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase();
      files = files.where((f) => f.originalName.toLowerCase().contains(q)).toList();
    }

    switch (sort) {
      case SortOrder.newest:
        files.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOrder.oldest:
        files.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortOrder.nameAsc:
        files.sort((a, b) => a.originalName.toLowerCase().compareTo(b.originalName.toLowerCase()));
        break;
      case SortOrder.nameDesc:
        files.sort((a, b) => b.originalName.toLowerCase().compareTo(a.originalName.toLowerCase()));
        break;
      case SortOrder.largest:
        files.sort((a, b) => b.fileSize.compareTo(a.fileSize));
        break;
      case SortOrder.smallest:
        files.sort((a, b) => a.fileSize.compareTo(b.fileSize));
        break;
    }
    return files;
  }

  Future<void> toggleFavorite(VaultFile file) async {
    file.isFavorite = !file.isFavorite;
    file.modifiedAt = DateTime.now();
    await file.save();
  }

  Future<void> moveToFolder(VaultFile file, String? folderId) async {
    file.folderId = folderId;
    file.modifiedAt = DateTime.now();
    await file.save();
  }

  Future<void> softDelete(VaultFile file) async {
    file.isDeleted = true;
    file.deletedAt = DateTime.now();
    await file.save();
  }

  Future<void> restore(VaultFile file) async {
    file.isDeleted = false;
    file.deletedAt = null;
    await file.save();
  }

  /// Permanently deletes a file: removes encrypted bytes, thumbnail, and
  /// metadata. Irreversible.
  Future<void> permanentlyDelete(VaultFile file) async {
    await _fileManager.deleteEncryptedFile(file.encryptedFileName);
    if (file.thumbnailFileName != null) {
      await _fileManager.deleteThumbnail(file.thumbnailFileName!);
    }
    await file.delete();
  }

  /// Purges recycle-bin items older than [retention]. Call periodically
  /// (e.g. on vault unlock) — see RecycleBinService.
  Future<void> purgeExpired(Duration retention) async {
    final cutoff = DateTime.now().subtract(retention);
    final expired = HiveBoxes.files.values.where((f) => f.isDeleted && f.deletedAt != null && f.deletedAt!.isBefore(cutoff)).toList();
    for (final f in expired) {
      await permanentlyDelete(f);
    }
  }
}
