import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/security/credential_manager.dart';
import '../core/storage/models/vault_file.dart';
import '../features/authentication/presentation/vault_auth_screen.dart';
import '../features/backup/presentation/backup_screens.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/folders/presentation/folders_screen.dart';
import '../features/onboarding/presentation/onboarding_screens.dart';
import '../features/onboarding/presentation/setup_credential_screen.dart';
import '../features/settings/presentation/access_trigger_settings_screen.dart';
import '../features/settings/presentation/change_credential_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/vault/presentation/import_screen.dart';
import '../features/vault/presentation/media_grid_screen.dart';
import '../features/vault/presentation/media_viewer_screen.dart';
import '../features/vault/presentation/recycle_bin_screen.dart';
import '../features/vault/presentation/vault_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const _SplashRedirect()),

      GoRoute(path: '/onboarding', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/onboarding/privacy', builder: (context, state) => const PrivacyIntroScreen()),
      GoRoute(path: '/onboarding/security', builder: (context, state) => const SecuritySetupScreen()),
      GoRoute(
        path: '/onboarding/setup-credential',
        builder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'pin';
          return SetupCredentialScreen(isPin: type == 'pin');
        },
      ),

      GoRoute(path: '/calculator', builder: (context, state) => const CalculatorScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const VaultAuthScreen()),
      GoRoute(path: '/vault', builder: (context, state) => const VaultHomeScreen()),

      GoRoute(path: '/vault/photos', builder: (context, state) => const MediaGridScreen(title: 'Photos', type: VaultFileType.photo)),
      GoRoute(path: '/vault/videos', builder: (context, state) => const MediaGridScreen(title: 'Videos', type: VaultFileType.video)),
      GoRoute(path: '/vault/documents', builder: (context, state) => const MediaGridScreen(title: 'Documents', type: VaultFileType.document)),
      GoRoute(path: '/vault/audio', builder: (context, state) => const MediaGridScreen(title: 'Audio', type: VaultFileType.audio)),
      GoRoute(path: '/vault/favorites', builder: (context, state) => const MediaGridScreen(title: 'Favorites', favoritesOnly: true)),
      GoRoute(
        path: '/vault/search',
        builder: (context, state) => MediaGridScreen(
          title: 'Search',
          showSearchBar: true,
          searchQuery: state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/vault/folder/:id',
        builder: (context, state) => MediaGridScreen(
          title: state.uri.queryParameters['name'] ?? 'Album',
          folderId: state.pathParameters['id'],
        ),
      ),
      GoRoute(path: '/vault/folders', builder: (context, state) => const FoldersScreen()),
      GoRoute(path: '/vault/recycle-bin', builder: (context, state) => const RecycleBinScreen()),
      GoRoute(
        path: '/vault/viewer/:id',
        builder: (context, state) => MediaViewerScreen(fileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vault/import',
        builder: (context, state) => ImportScreen(folderId: state.uri.queryParameters['folderId']),
      ),

      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/settings/change-credential', builder: (context, state) => const ChangeCredentialScreen()),
      GoRoute(path: '/settings/access-trigger', builder: (context, state) => const AccessTriggerSettingsScreen()),
      GoRoute(path: '/settings/backup', builder: (context, state) => const CreateBackupScreen()),
      GoRoute(path: '/settings/restore', builder: (context, state) => const RestoreBackupScreen()),
    ],
  );
});

/// Decides whether to land on onboarding or the calculator, based on
/// whether a vault credential has already been set up.
class _SplashRedirect extends ConsumerWidget {
  const _SplashRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credManager = ref.watch(_credManagerProvider);
    return FutureBuilder<bool>(
      future: credManager.hasVaultBeenSetUp(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _LoadingScaffold();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (snapshot.data == true) {
            GoRouter.of(context).go('/calculator');
          } else {
            GoRouter.of(context).go('/onboarding');
          }
        });
        return const _LoadingScaffold();
      },
    );
  }
}

final _credManagerProvider = Provider((ref) => CredentialManager());

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
