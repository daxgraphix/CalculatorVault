import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/settings_repository.dart';
import 'router.dart';
import 'theme.dart';
import '../core/providers.dart';

class CalculatorVaultApp extends ConsumerStatefulWidget {
  const CalculatorVaultApp({super.key});

  @override
  ConsumerState<CalculatorVaultApp> createState() => _CalculatorVaultAppState();
}

class _CalculatorVaultAppState extends ConsumerState<CalculatorVaultApp> {
  @override
  void initState() {
    super.initState();
    // Register the session manager as an app-lifecycle observer so
    // backgrounding the app enforces the auto-lock policy (see section 42:
    // App Lifecycle in the product spec).
    WidgetsBinding.instance.addObserver(ref.read(vaultSessionManagerProvider));

    final settings = ref.read(settingsRepositoryProvider);
    ref.read(vaultSessionManagerProvider).setAutoLockDuration(settings.getAutoLockDuration());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(ref.read(vaultSessionManagerProvider));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsRepositoryProvider);
    final themeMode = settings.getThemeMode();

    return MaterialApp.router(
      title: 'Calculator Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      routerConfig: router,
    );
  }
}
