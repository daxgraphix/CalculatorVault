import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/storage/models/vault_file.dart';
import '../domain/vault_providers.dart';
import '../widgets/encrypted_thumbnail.dart';

class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionManagerProvider);
    if (!session.isUnlocked) {
      // Guard: if the session expired while this screen was still mounted
      // (e.g. returning from background), bounce back to auth.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/auth');
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    final counts = ref.watch(vaultCountsProvider);
    final recent = ref.watch(vaultFileListProvider(const VaultFilesQuery()));

    return GestureDetector(
      onTap: () => session.recordActivity(),
      onPanDown: (_) => session.recordActivity(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vault'),
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock Vault',
              onPressed: () {
                session.lock();
                context.go('/calculator');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => ref.read(vaultRefreshProvider.notifier).state++,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (q) => context.push('/vault/search?q=$q'),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _CategoryTile(
                    label: 'Photos',
                    icon: Icons.photo_outlined,
                    count: counts[VaultFileType.photo] ?? 0,
                    onTap: () => context.push('/vault/photos'),
                  ),
                  _CategoryTile(
                    label: 'Videos',
                    icon: Icons.videocam_outlined,
                    count: counts[VaultFileType.video] ?? 0,
                    onTap: () => context.push('/vault/videos'),
                  ),
                  _CategoryTile(
                    label: 'Documents',
                    icon: Icons.description_outlined,
                    count: counts[VaultFileType.document] ?? 0,
                    onTap: () => context.push('/vault/documents'),
                  ),
                  _CategoryTile(
                    label: 'Audio',
                    icon: Icons.audiotrack_outlined,
                    count: counts[VaultFileType.audio] ?? 0,
                    onTap: () => context.push('/vault/audio'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Recently Added', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No files yet — tap + to add some.')),
                )
              else
                SizedBox(
                  height: 96,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length > 20 ? 20 : recent.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = recent[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 96,
                          height: 96,
                          child: EncryptedThumbnail(file: file),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/vault/import'),
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Albums'),
            NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Favorites'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          ],
          onDestinationSelected: (i) {
            switch (i) {
              case 1:
                context.push('/vault/folders');
                break;
              case 2:
                context.push('/vault/favorites');
                break;
              case 3:
                context.push('/vault/search');
                break;
            }
          },
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label, required this.icon, required this.count, required this.onTap});
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('$count', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
