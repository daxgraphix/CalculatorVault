import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calculator/domain/access_trigger_service.dart';
import 'security/credential_manager.dart';
import 'security/session_manager.dart';
import 'storage/file_manager.dart';

final credentialManagerProvider = Provider<CredentialManager>((ref) => CredentialManager());

final vaultSessionManagerProvider = ChangeNotifierProvider<VaultSessionManager>((ref) {
  return VaultSessionManager();
});

final accessTriggerServiceProvider = Provider<AccessTriggerService>((ref) => AccessTriggerService());

final fileManagerProvider = Provider<FileManager>((ref) => FileManager.instance);

/// Auto-lock duration, backed by settings. Read at app start and whenever
/// the settings screen updates it (see settingsRepositoryProvider).
final autoLockDurationProvider = StateProvider<Duration>((ref) => const Duration(minutes: 1));
