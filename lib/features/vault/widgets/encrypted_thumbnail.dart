import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/models/vault_file.dart';
import '../domain/vault_providers.dart';

class EncryptedThumbnail extends ConsumerWidget {
  const EncryptedThumbnail({super.key, required this.file, this.fit = BoxFit.cover});
  final VaultFile file;
  final BoxFit fit;

  static const _iconByType = {
    VaultFileType.video: Icons.videocam,
    VaultFileType.audio: Icons.audiotrack,
    VaultFileType.document: Icons.description,
    VaultFileType.other: Icons.insert_drive_file,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultSessionManagerProvider);
    final repo = ref.watch(vaultFileRepositoryProvider);
    final key = session.masterKey;

    if (file.thumbnailFileName == null || key == null || file.fileType == VaultFileType.document) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(_iconByType[file.fileType] ?? Icons.insert_drive_file, size: 32),
      );
    }

    return FutureBuilder(
      future: repo.decryptThumbnail(file, key),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(_iconByType[file.fileType] ?? Icons.insert_drive_file, size: 32),
          );
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}
