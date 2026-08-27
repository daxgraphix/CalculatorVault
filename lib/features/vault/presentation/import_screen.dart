import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/storage/models/vault_file.dart';
import '../domain/vault_providers.dart';

enum ImportItemState { waiting, encrypting, verifying, saving, completed, failed, cancelled }

class ImportItem {
  ImportItem(this.path, this.name);
  final String path;
  final String name;
  ImportItemState state = ImportItemState.waiting;
  double progress = 0;
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.folderId});
  final String? folderId;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final List<ImportItem> _items = [];
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add to Vault')),
      body: Column(
        children: [
          if (_items.isEmpty) _buildPickerGrid() else _buildQueue(),
        ],
      ),
    );
  }

  Widget _buildPickerGrid() {
    return Expanded(
      child: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
        children: [
          _PickTile(icon: Icons.photo_outlined, label: 'Photos', onTap: _pickPhotos),
          _PickTile(icon: Icons.videocam_outlined, label: 'Videos', onTap: _pickVideos),
          _PickTile(icon: Icons.audiotrack_outlined, label: 'Audio', onTap: () => _pickFiles(FileType.audio)),
          _PickTile(icon: Icons.description_outlined, label: 'Documents', onTap: () => _pickFiles(FileType.custom, extensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'zip'])),
          _PickTile(icon: Icons.insert_drive_file_outlined, label: 'Any file', onTap: () => _pickFiles(FileType.any)),
        ],
      ),
    );
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    setState(() => _items.addAll(images.map((x) => ImportItem(x.path, x.name))));
    if (_items.isNotEmpty) _startImport();
  }

  Future<void> _pickVideos() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() => _items.add(ImportItem(video.path, video.name)));
      _startImport();
    }
  }

  Future<void> _pickFiles(FileType type, {List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
      allowMultiple: true,
    );
    if (result != null) {
      setState(() => _items.addAll(result.files.where((f) => f.path != null).map((f) => ImportItem(f.path!, f.name))));
      _startImport();
    }
  }

  Widget _buildQueue() {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            title: Text(item.name, overflow: TextOverflow.ellipsis),
            subtitle: LinearProgressIndicator(value: item.state == ImportItemState.completed ? 1 : item.progress),
            trailing: _statusIcon(item.state),
          );
        },
      ),
    );
  }

  Widget _statusIcon(ImportItemState state) {
    switch (state) {
      case ImportItemState.completed:
        return const Icon(Icons.check_circle, color: Colors.green);
      case ImportItemState.failed:
        return const Icon(Icons.error, color: Colors.red);
      case ImportItemState.cancelled:
        return const Icon(Icons.cancel, color: Colors.grey);
      default:
        return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    }
  }

  Future<void> _startImport() async {
    if (_importing) return;
    _importing = true;
    final session = ref.read(vaultSessionManagerProvider);
    final repo = ref.read(vaultFileRepositoryProvider);
    final key = session.masterKey;
    if (key == null) {
      if (mounted) context.go('/auth');
      return;
    }

    for (final item in _items) {
      if (item.state != ImportItemState.waiting) continue;
      setState(() => item.state = ImportItemState.encrypting);
      try {
        final file = File(item.path);
        final ext = item.name.split('.').last.toLowerCase();
        final type = _typeFromExtension(ext);
        Uint8List? thumbBytes;
        if (type == VaultFileType.photo) {
          // Use the original bytes as the thumbnail source; downscaling is
          // left to Image.memory's cacheWidth in the grid for simplicity.
          thumbBytes = await file.readAsBytes();
        }

        setState(() => item.state = ImportItemState.verifying);
        await repo.importFile(
          sourceFile: file,
          type: type,
          mimeType: 'application/octet-stream',
          masterKey: key,
          folderId: widget.folderId,
          thumbnailBytes: thumbBytes,
        );

        setState(() {
          item.state = ImportItemState.completed;
          item.progress = 1;
        });
      } catch (e) {
        setState(() => item.state = ImportItemState.failed);
      }
    }

    ref.read(vaultRefreshProvider.notifier).state++;
    _importing = false;
  }

  VaultFileType _typeFromExtension(String ext) {
    const photoExts = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'];
    const videoExts = ['mp4', 'mov', 'mkv', 'avi', '3gp', 'webm'];
    const audioExts = ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'];
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'zip'];
    if (photoExts.contains(ext)) return VaultFileType.photo;
    if (videoExts.contains(ext)) return VaultFileType.video;
    if (audioExts.contains(ext)) return VaultFileType.audio;
    if (docExts.contains(ext)) return VaultFileType.document;
    return VaultFileType.other;
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
