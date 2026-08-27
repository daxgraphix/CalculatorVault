import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers.dart';
import '../../../core/storage/hive_boxes.dart';
import '../../../core/storage/models/vault_file.dart';
import '../domain/vault_providers.dart';

class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.fileId});
  final String fileId;

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  File? _decryptedTempFile;
  VideoPlayerController? _videoController;
  bool _loading = true;

  VaultFile get file => HiveBoxes.files.get(widget.fileId)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(vaultSessionManagerProvider);
    final repo = ref.read(vaultFileRepositoryProvider);
    final key = session.masterKey;
    if (key == null) {
      if (mounted) context.go('/auth');
      return;
    }
    final temp = await repo.decryptToTempFile(file, key);
    _decryptedTempFile = temp;

    if (file.fileType == VaultFileType.video) {
      _videoController = VideoPlayerController.file(temp);
      await _videoController!.initialize();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    // Best-effort cleanup of the decrypted temp file so plaintext never
    // lingers on disk longer than needed for playback/viewing.
    _decryptedTempFile?.delete().catchError((_) => _decryptedTempFile!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(file.originalName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(file.isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () async {
              await ref.read(vaultFileRepositoryProvider).toggleFavorite(file);
              ref.read(vaultRefreshProvider.notifier).state++;
              setState(() {});
            },
          ),
          PopupMenuButton<String>(
            onSelected: _onMenuSelect,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Export / Share')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (file.fileType) {
      case VaultFileType.photo:
        return PhotoView(imageProvider: FileImage(_decryptedTempFile!));
      case VaultFileType.video:
        if (_videoController == null || !_videoController!.value.isInitialized) {
          return const Center(child: Text('Unable to play video', style: TextStyle(color: Colors.white)));
        }
        return Center(
          child: AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                VideoPlayer(_videoController!),
                VideoProgressIndicator(_videoController!, allowScrubbing: true),
                IconButton(
                  iconSize: 64,
                  color: Colors.white,
                  icon: Icon(_videoController!.value.isPlaying ? Icons.pause_circle : Icons.play_circle),
                  onPressed: () => setState(() {
                    _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                  }),
                ),
              ],
            ),
          ),
        );
      case VaultFileType.audio:
      case VaultFileType.document:
      case VaultFileType.other:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(file.originalName, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => OpenFilex.open(_decryptedTempFile!.path),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open with system app'),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Opening this file exports a temporary copy outside protected storage.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _onMenuSelect(String value) async {
    if (value == 'export' && _decryptedTempFile != null) {
      await SharePlus.instance.share(ShareParams(files: [XFile(_decryptedTempFile!.path)]));
    } else if (value == 'delete') {
      await ref.read(vaultFileRepositoryProvider).softDelete(file);
      ref.read(vaultRefreshProvider.notifier).state++;
      if (mounted) context.pop();
    }
  }
}
