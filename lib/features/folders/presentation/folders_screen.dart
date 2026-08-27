import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../vault/domain/vault_providers.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(vaultFolderListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Albums')),
      body: folders.isEmpty
          ? const Center(child: Text('No albums yet'))
          : ListView.builder(
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder.name),
                  onTap: () => context.push('/vault/folder/${folder.id}?name=${Uri.encodeComponent(folder.name)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      final repo = ref.read(folderRepositoryProvider);
                      if (v == 'rename') {
                        final name = await _promptName(context, initial: folder.name);
                        if (name != null && name.isNotEmpty) {
                          await repo.rename(folder, name);
                          ref.read(vaultRefreshProvider.notifier).state++;
                        }
                      } else if (v == 'delete') {
                        await repo.delete(folder);
                        ref.read(vaultRefreshProvider.notifier).state++;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete album')),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final name = await _promptName(context);
          if (name != null && name.isNotEmpty) {
            await ref.read(folderRepositoryProvider).create(name);
            ref.read(vaultRefreshProvider.notifier).state++;
          }
        },
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }

  Future<String?> _promptName(BuildContext context, {String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initial == null ? 'New Album' : 'Rename Album'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }
}
