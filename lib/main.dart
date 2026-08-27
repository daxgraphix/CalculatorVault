import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/platform/privacy_protection.dart';
import 'core/storage/hive_boxes.dart';
import 'features/settings/domain/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();

  // Apply screen protection (FLAG_SECURE on Android) if enabled — prevents
  // vault content from appearing in the system app switcher / screenshots.
  final settings = SettingsRepository();
  if (settings.getScreenProtectionEnabled()) {
    await PrivacyProtection.enable();
  }

  runApp(const ProviderScope(child: CalculatorVaultApp()));
}
