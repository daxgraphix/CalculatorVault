import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers.dart';
import '../../vault/domain/vault_providers.dart';
import '../domain/backup_service.dart';

class CreateBackupScreen extends ConsumerStatefulWidget {
  const CreateBackupScreen({super.key});

  @override
  ConsumerState<CreateBackupScreen> createState() => _CreateBackupScreenState();
}

class _CreateBackupScreenState extends ConsumerState<CreateBackupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  File? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Backup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose a backup password. It can be different from your vault '
              'PIN/password — you will need it to restore this backup.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Backup password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm backup password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Create Backup')),
            ),
            if (_result != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(_result!.path)])),
                icon: const Icon(Icons.share),
                label: const Text('Share / Save backup file'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Backup password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = BackupService();
      final file = await service.createBackup(backupPassword: _password.text);
      setState(() {
        _result = file;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Backup failed: $e';
      });
    }
  }
}

class RestoreBackupScreen extends ConsumerStatefulWidget {
  const RestoreBackupScreen({super.key});

  @override
  ConsumerState<RestoreBackupScreen> createState() => _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends ConsumerState<RestoreBackupScreen> {
  final _password = TextEditingController();
  File? _selectedFile;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from Backup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(_selectedFile == null ? 'Select .cvault file' : _selectedFile!.path.split('/').last),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Backup password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy || _selectedFile == null ? null : _restore,
              child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Restore')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFile = File(result.files.single.path!));
    }
  }

  Future<void> _restore() async {
    final session = ref.read(vaultSessionManagerProvider);
    final key = session.masterKey;
    if (key == null) {
      setState(() => _error = 'Unlock the vault first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = BackupService();
      await service.restoreBackup(backupFile: _selectedFile!, backupPassword: _password.text, vaultMasterKey: key);
      ref.read(vaultRefreshProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore complete')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Restore failed. Check the password and file.';
      });
    }
  }
}
