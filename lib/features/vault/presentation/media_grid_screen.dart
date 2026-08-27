import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/storage/models/vault_file.dart';
import '../domain/vault_file_repository.dart';
import '../domain/vault_providers.dart';
import '../widgets/encrypted_thumbnail.dart';

class MediaGridScreen extends ConsumerStatefulWidget {
  const MediaGridScreen({
    super.key,
    required this.title,
    this.type,
    this.folderId,
    this.favoritesOnly = false,
    this.searchQuery,
    this.showSearchBar = false,
  });

  final String title;
  final VaultFileType? type;
  final String? folderId;
  final bool favoritesOnly;
  final String? searchQuery;
  final bool showSearchBar;

  @override
  ConsumerState<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends ConsumerState<MediaGridScreen> {
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;
  SortOrder _sort = SortOrder.newest;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.searchQuery ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final query = VaultFilesQuery(
      type: widget.type,
      folderId: widget.folderId,
      favoritesOnly: widget.favoritesOnly,
      searchQuery: _query.isEmpty ? null : _query,
      sort: _sort,
    );
    final files = ref.watch(vaultFileListProvider(query));
    final repo = ref.watch(vaultFileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _selecting ? Text('${_selected.length} selected') : Text(widget.title),
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_selected.clear))
            : null,
        actions: _selecting
            ? [
                IconButton(icon: const Icon(Icons.favorite_border), onPressed: () => _bulkFavorite(files, repo)),
                IconButton(icon: const Icon(Icons.drive_file_move_outline), onPressed: () => _bulkMove(files, repo)),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _bulkDelete(files, repo)),
              ]
            : [
                PopupMenuButton<SortOrder>(
                  icon: const Icon(Icons.sort),
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: SortOrder.newest, child: Text('Newest')),
                    PopupMenuItem(value: SortOrder.oldest, child: Text('Oldest')),
                    PopupMenuItem(value: SortOrder.nameAsc, child: Text('Name A–Z')),
                    PopupMenuItem(value: SortOrder.nameDesc, child: Text('Name Z–A')),
                    PopupMenuItem(value: SortOrder.largest, child: Text('Largest')),
                    PopupMenuItem(value: SortOrder.smallest, child: Text('Smallest')),
                  ],
                ),
              ],
      ),
      body: Column(
        children: [
          if (widget.showSearchBar)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: files.isEmpty
                ? const Center(child: Text('No files here yet'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final isSelected = _selected.contains(file.id);
                      return GestureDetector(
                        onTap: () {
                          if (_selecting) {
                            setState(() => isSelected ? _selected.remove(file.id) : _selected.add(file.id));
                          } else {
                            context.push('/vault/viewer/${file.id}');
                          }
                        },
                        onLongPress: () => setState(() => _selected.add(file.id)),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            EncryptedThumbnail(file: file),
                            if (file.isFavorite)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(Icons.favorite, color: Colors.redAccent, size: 16),
                              ),
                            if (isSelected)
                              Container(
                                color: Colors.black45,
                                child: const Icon(Icons.check_circle, color: Colors.white),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkFavorite(List<VaultFile> files, VaultFileRepository repo) async {
    for (final f in files.where((f) => _selected.contains(f.id))) {
      await repo.toggleFavorite(f);
    }
    ref.read(vaultRefreshProvider.notifier).state++;
    setState(_selected.clear);
  }

  Future<void> _bulkDelete(List<VaultFile> files, VaultFileRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Recycle Bin?'),
        content: Text('${_selected.length} item(s) will be moved to the recycle bin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final f in files.where((f) => _selected.contains(f.id))) {
      await repo.softDelete(f);
    }
    ref.read(vaultRefreshProvider.notifier).state++;
    setState(_selected.clear);
  }

  Future<void> _bulkMove(List<VaultFile> files, VaultFileRepository repo) async {
    final folders = ref.read(vaultFolderListProvider);
    final targetId = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Move to', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(title: const Text('Unfiled'), onTap: () => Navigator.pop(context, '')),
          for (final folder in folders)
            ListTile(title: Text(folder.name), onTap: () => Navigator.pop(context, folder.id)),
        ],
      ),
    );
    if (targetId == null) return;
    for (final f in files.where((f) => _selected.contains(f.id))) {
      await repo.moveToFolder(f, targetId.isEmpty ? null : targetId);
    }
    ref.read(vaultRefreshProvider.notifier).state++;
    setState(_selected.clear);
  }
}
