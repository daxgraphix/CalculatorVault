import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/models/vault_file.dart';
import '../../../core/storage/models/vault_folder.dart';
import 'vault_file_repository.dart';

final vaultFileRepositoryProvider = Provider<VaultFileRepository>((ref) => VaultFileRepository());

/// Refresh token: bump to force dependent providers (file/folder lists) to
/// re-read from Hive after a mutation.
final vaultRefreshProvider = StateProvider<int>((ref) => 0);

final vaultFolderListProvider = Provider<List<VaultFolder>>((ref) {
  ref.watch(vaultRefreshProvider);
  return HiveBoxes.folders.values.toList()..sort((a, b) => a.name.compareTo(b.name));
});

class FolderRepository {
  final _uuid = const Uuid();

  Future<VaultFolder> create(String name, {String? parentId}) async {
    final now = DateTime.now();
    final folder = VaultFolder(id: _uuid.v4(), name: name, parentId: parentId, createdAt: now, modifiedAt: now);
    await HiveBoxes.folders.put(folder.id, folder);
    return folder;
  }

  Future<void> rename(VaultFolder folder, String newName) async {
    folder.name = newName;
    folder.modifiedAt = DateTime.now();
    await folder.save();
  }

  /// Deletes a folder. Files inside are NOT deleted — they become
  /// unfiled (folderId = null), matching common "safe delete" UX.
  Future<void> delete(VaultFolder folder) async {
    final files = HiveBoxes.files.values.where((f) => f.folderId == folder.id);
    for (final f in files) {
      f.folderId = null;
      await f.save();
    }
    await folder.delete();
  }
}

final folderRepositoryProvider = Provider<FolderRepository>((ref) => FolderRepository());

class VaultFilesQuery {
  final VaultFileType? type;
  final String? folderId;
  final bool favoritesOnly;
  final bool includeDeleted;
  final String? searchQuery;
  final SortOrder sort;

  const VaultFilesQuery({
    this.type,
    this.folderId,
    this.favoritesOnly = false,
    this.includeDeleted = false,
    this.searchQuery,
    this.sort = SortOrder.newest,
  });
}

final vaultFileListProvider = Provider.family<List<VaultFile>, VaultFilesQuery>((ref, query) {
  ref.watch(vaultRefreshProvider);
  final repo = ref.watch(vaultFileRepositoryProvider);
  return repo.listFiles(
    type: query.type,
    folderId: query.folderId,
    favoritesOnly: query.favoritesOnly,
    includeDeleted: query.includeDeleted,
    searchQuery: query.searchQuery,
    sort: query.sort,
  );
});

final vaultCountsProvider = Provider((ref) {
  ref.watch(vaultRefreshProvider);
  final all = HiveBoxes.files.values.where((f) => !f.isDeleted);
  return {
    for (final type in VaultFileType.values)
      type: all.where((f) => f.fileType == type).length,
  };
});
