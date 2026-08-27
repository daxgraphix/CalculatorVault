import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/security/credential_manager.dart';
import '../../../core/storage/file_manager.dart';
import '../../../core/storage/hive_boxes.dart';
import '../domain/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _storageBytes = 0;

  @override
  void initState() {
    super.initState();
    FileManager.instance.totalStorageUsed().then((v) => setState(() => _storageBytes = v));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsRepositoryProvider);
    final session = ref.watch(vaultSessionManagerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Security'),
          ListTile(
            title: const Text('Change PIN / Password'),
            leading: const Icon(Icons.password_outlined),
            onTap: () => context.push('/settings/change-credential'),
          ),
          ListTile(
            title: const Text('Auto-lock'),
            subtitle: Text(_autoLockLabel(settings.getAutoLockDuration())),
            leading: const Icon(Icons.timer_outlined),
            onTap: () => _pickAutoLock(context, settings, session),
          ),
          SwitchListTile(
            title: const Text('Screen protection'),
            subtitle: const Text('Hide vault content in the app switcher'),
            secondary: const Icon(Icons.security_outlined),
            value: settings.getScreenProtectionEnabled(),
            onChanged: (v) async {
              await settings.setScreenProtectionEnabled(v);
              setState(() {});
            },
          ),
          const _SectionHeader('Calculator'),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            secondary: const Icon(Icons.vibration),
            value: settings.getHapticsEnabled(),
            onChanged: (v) async {
              await settings.setHapticsEnabled(v);
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Vault access trigger'),
            subtitle: const Text('Optional secret code, or long-press "="'),
            leading: const Icon(Icons.pin_outlined),
            onTap: () => context.push('/settings/access-trigger'),
          ),
          const _SectionHeader('Vault'),
          ListTile(
            title: const Text('Recycle bin'),
            subtitle: Text(_retentionLabel(settings.getRecycleBinRetention())),
            leading: const Icon(Icons.delete_outline),
            onTap: () => _pickRetention(context, settings),
          ),
          ListTile(
            title: const Text('View recycle bin'),
            leading: const Icon(Icons.restore_from_trash_outlined),
            onTap: () => context.push('/vault/recycle-bin'),
          ),
          ListTile(
            title: const Text('Storage used'),
            subtitle: Text(_formatBytes(_storageBytes)),
            leading: const Icon(Icons.storage_outlined),
          ),
          const _SectionHeader('Backup'),
          ListTile(
            title: const Text('Create backup'),
            leading: const Icon(Icons.backup_outlined),
            onTap: () => context.push('/settings/backup'),
          ),
          ListTile(
            title: const Text('Restore from backup'),
            leading: const Icon(Icons.restore_outlined),
            onTap: () => context.push('/settings/restore'),
          ),
          const _SectionHeader('Appearance'),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(settings.getThemeMode().name),
            leading: const Icon(Icons.palette_outlined),
            onTap: () => _pickTheme(context, settings),
          ),
          const _SectionHeader('About'),
          const ListTile(title: Text('Version'), subtitle: Text('1.0.0'), leading: Icon(Icons.info_outline)),
          const ListTile(
            title: Text('Privacy'),
            subtitle: Text('No account, no cloud, fully offline. Files are AES-256-GCM encrypted at rest.'),
            leading: Icon(Icons.privacy_tip_outlined),
          ),
          const _SectionHeader('Danger zone'),
          ListTile(
            title: const Text('Reset App', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently deletes all vault data. Cannot be undone.'),
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
            onTap: () => _confirmReset(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _autoLockLabel(Duration d) {
    if (d == Duration.zero) return 'Immediately';
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    if (d.inMinutes == 1) return '1 minute';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return 'Never';
  }

  String _retentionLabel(RecycleBinRetention r) {
    switch (r) {
      case RecycleBinRetention.days7:
        return '7 days';
      case RecycleBinRetention.days30:
        return '30 days';
      case RecycleBinRetention.never:
        return 'Never (keep forever)';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _pickAutoLock(BuildContext context, SettingsRepository settings, dynamic session) async {
    const options = {
      'Immediately': Duration.zero,
      '30 seconds': Duration(seconds: 30),
      '1 minute': Duration(minutes: 1),
      '5 minutes': Duration(minutes: 5),
      '10 minutes': Duration(minutes: 10),
      'Never': Duration(days: 9999),
    };
    final chosen = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: options.entries
            .map((e) => ListTile(title: Text(e.key), onTap: () => Navigator.pop(context, e.value)))
            .toList(),
      ),
    );
    if (chosen != null) {
      await settings.setAutoLockDuration(chosen);
      session.setAutoLockDuration(chosen);
      setState(() {});
    }
  }

  Future<void> _pickRetention(BuildContext context, SettingsRepository settings) async {
    final chosen = await showModalBottomSheet<RecycleBinRetention>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: RecycleBinRetention.values
            .map((r) => ListTile(title: Text(_retentionLabel(r)), onTap: () => Navigator.pop(context, r)))
            .toList(),
      ),
    );
    if (chosen != null) {
      await settings.setRecycleBinRetention(chosen);
      setState(() {});
    }
  }

  Future<void> _pickTheme(BuildContext context, SettingsRepository settings) async {
    final chosen = await showModalBottomSheet<AppThemeMode>(
      context: context,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: AppThemeMode.values
            .map((m) => ListTile(title: Text(m.name), onTap: () => Navigator.pop(context, m)))
            .toList(),
      ),
    );
    if (chosen != null) {
      await settings.setThemeMode(chosen);
      setState(() {});
    }
  }

  Future<void> _confirmReset(BuildContext context) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App?'),
        content: const Text('This permanently deletes all vault files, folders, and settings. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirm != true || !context.mounted) return;

    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you absolutely sure?'),
        content: const Text('Type RESET to confirm this action is irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (secondConfirm != true || !context.mounted) return;

    await ref.read(credentialManagerProvider).wipeAll();
    await HiveBoxes.wipeAll();
    await FileManager.instance.wipeEverything();
    ref.read(vaultSessionManagerProvider).lock();
    if (context.mounted) context.go('/onboarding');
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
