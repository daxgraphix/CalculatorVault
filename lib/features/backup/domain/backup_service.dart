import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/storage/file_manager.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/models/vault_file.dart';
import '../../../core/storage/models/vault_folder.dart';

/// Creates and restores `.cvault` encrypted backup archives.
///
/// The backup has its OWN password, independent of the vault's PIN/password,
/// so it stays portable without exposing the device's internal key
/// hierarchy. Format:
///   1. A plaintext-manifest-free zip is assembled containing already
///      individually-encrypted vault files + thumbnails, plus a metadata
///      JSON (file list, folder list — the ONLY plaintext-adjacent data,
///      and it contains no file contents).
///   2. The whole zip is then re-encrypted end-to-end with a key derived
///      (Argon2id) from the backup password, so even the metadata JSON is
///      protected.
class BackupService {
  final _crypto = CryptoService.instance;
  final _fileManager = FileManager.instance;

  Future<File> createBackup({required String backupPassword}) async {
    final tempDir = await _fileManager.tempDir;
    final zipPath = p.join(tempDir.path, 'export_${DateTime.now().millisecondsSinceEpoch}.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // Metadata: file & folder records (paths reference the encrypted file
    // names already inside app-private storage — no plaintext content here).
    final filesMeta = HiveBoxes.files.values.where((f) => !f.isDeleted).map((f) => {
          'id': f.id,
          'originalName': f.originalName,
          'encryptedFileName': f.encryptedFileName,
          'thumbnailFileName': f.thumbnailFileName,
          'mimeType': f.mimeType,
          'fileType': f.fileType.index,
          'fileSize': f.fileSize,
          'createdAt': f.createdAt.toIso8601String(),
          'modifiedAt': f.modifiedAt.toIso8601String(),
          'folderId': f.folderId,
          'isFavorite': f.isFavorite,
        }).toList();

    final foldersMeta = HiveBoxes.folders.values.map((f) => {
          'id': f.id,
          'name': f.name,
          'parentId': f.parentId,
          'createdAt': f.createdAt.toIso8601String(),
          'modifiedAt': f.modifiedAt.toIso8601String(),
        }).toList();

    final manifest = jsonEncode({
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'files': filesMeta,
      'folders': foldersMeta,
    });

    final manifestFile = File(p.join(tempDir.path, 'manifest.json'));
    await manifestFile.writeAsString(manifest);
    encoder.addFile(manifestFile);

    final vaultDir = await _fileManager.vaultDir;
    final thumbDir = await _fileManager.thumbnailDir;
    if (await vaultDir.exists()) encoder.addDirectory(vaultDir, includeDirName: true);
    if (await thumbDir.exists()) encoder.addDirectory(thumbDir, includeDirName: true);

    encoder.close();
    await manifestFile.delete();

    // Re-encrypt the whole zip end-to-end with a key derived from the
    // backup password.
    final derived = await _crypto.deriveKey(credential: backupPassword);
    final outputFile = File(p.join(tempDir.path, 'calculator_vault_backup_${DateTime.now().millisecondsSinceEpoch}.cvault'));
    await _crypto.encryptFile(source: File(zipPath), destination: outputFile, masterKey: derived.secretKey);

    // Prepend the salt so restore can re-derive the same key.
    final saltedOutput = File('${outputFile.path}.final');
    final sink = saltedOutput.openWrite();
    sink.add(derived.salt.length.toString().padLeft(4, '0').codeUnits);
    sink.add(derived.salt);
    sink.add(await outputFile.readAsBytes());
    await sink.close();
    await outputFile.delete();
    await File(zipPath).delete();

    final finalPath = saltedOutput.path.replaceAll('.final', '');
    await saltedOutput.rename(finalPath);
    return File(finalPath);
  }

  Future<void> restoreBackup({required File backupFile, required String backupPassword, required SecretKey vaultMasterKey}) async {
    final bytes = await backupFile.readAsBytes();
    final saltLen = int.parse(String.fromCharCodes(bytes.sublist(0, 4)));
    final salt = bytes.sublist(4, 4 + saltLen);
    final encryptedZipBytes = bytes.sublist(4 + saltLen);

    final tempDir = await _fileManager.tempDir;
    final encryptedZipFile = File(p.join(tempDir.path, 'restore_in.bin'));
    await encryptedZipFile.writeAsBytes(encryptedZipBytes);

    final derived = await _crypto.deriveKey(credential: backupPassword, existingSalt: salt);
    final zipFile = File(p.join(tempDir.path, 'restore.zip'));
    await _crypto.decryptFile(source: encryptedZipFile, destination: zipFile, masterKey: derived.secretKey);

    final extractDir = Directory(p.join(tempDir.path, 'restore_extract'));
    if (await extractDir.exists()) await extractDir.delete(recursive: true);
    await extractDir.create(recursive: true);

    final archive = ZipDecoder().decodeBytes(await zipFile.readAsBytes());
    for (final entry in archive) {
      final outPath = p.join(extractDir.path, entry.name);
      if (entry.isFile) {
        final outFile = File(outPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(entry.content as List<int>);
      }
    }

    final manifestFile = File(p.join(extractDir.path, 'manifest.json'));
    final manifest = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;

    // Restore folders first (files reference folderId).
    for (final f in (manifest['folders'] as List)) {
      final folder = VaultFolder(
        id: f['id'],
        name: f['name'],
        parentId: f['parentId'],
        createdAt: DateTime.parse(f['createdAt']),
        modifiedAt: DateTime.parse(f['modifiedAt']),
      );
      await HiveBoxes.folders.put(folder.id, folder);
    }

    final vaultDir = await _fileManager.vaultDir;
    final thumbDir = await _fileManager.thumbnailDir;

    for (final f in (manifest['files'] as List)) {
      final id = f['id'] as String;
      final encName = f['encryptedFileName'] as String;
      final thumbName = f['thumbnailFileName'] as String?;

      final extractedFile = File(p.join(extractDir.path, 'files', encName));
      if (await extractedFile.exists()) {
        await extractedFile.copy(p.join(vaultDir.path, encName));
      }
      if (thumbName != null) {
        final extractedThumb = File(p.join(extractDir.path, 'thumbnails', thumbName));
        if (await extractedThumb.exists()) {
          await extractedThumb.copy(p.join(thumbDir.path, thumbName));
        }
      }

      final record = VaultFile(
        id: id,
        originalName: f['originalName'],
        encryptedFileName: encName,
        thumbnailFileName: thumbName,
        mimeType: f['mimeType'],
        fileType: VaultFileType.values[f['fileType']],
        fileSize: f['fileSize'],
        createdAt: DateTime.parse(f['createdAt']),
        modifiedAt: DateTime.parse(f['modifiedAt']),
        folderId: f['folderId'],
        isFavorite: f['isFavorite'] ?? false,
      );
      await HiveBoxes.files.put(record.id, record);
    }

    await extractDir.delete(recursive: true);
    await zipFile.delete();
    await encryptedZipFile.delete();
  }

  Future<Directory> get downloadsDirectory async {
    if (Platform.isAndroid) {
      return Directory('/storage/emulated/0/Download');
    }
    return getApplicationDocumentsDirectory();
  }
}
