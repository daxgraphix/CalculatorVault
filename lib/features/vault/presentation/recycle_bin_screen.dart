import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vault_providers.dart';
import '../widgets/encrypted_thumbnail.dart';

class RecycleBinScreen extends ConsumerWidget {
  const RecycleBinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(vaultFileListProvider(const VaultFilesQuery(includeDeleted: true)));
    final repo = ref.watch(vaultFileRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recycle Bin')),
      body: files.isEmpty
          ? const Center(child: Text('Recycle bin is empty'))
          : ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index];
                return ListTile(
                  leading: SizedBox(
                    width: 48,
                    height: 48,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: EncryptedThumbnail(file: file),
                    ),
                  ),
                  title: Text(file.originalName, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Deleted ${file.deletedAt != null ? _timeAgo(file.deletedAt!) : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Restore',
                        onPressed: () async {
                          await repo.restore(file);
                          ref.read(vaultRefreshProvider.notifier).state++;
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        tooltip: 'Delete permanently',
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete permanently?'),
                              content: const Text('This cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await repo.permanentlyDelete(file);
                            ref.read(vaultRefreshProvider.notifier).state++;
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}
