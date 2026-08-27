import 'package:flutter/services.dart';

/// Bridges to native Android to set/clear FLAG_SECURE, which prevents:
///  - Screenshots of vault screens
///  - Vault content appearing in the "Recent Apps" preview thumbnail
///
/// This is one of the few things that genuinely requires native code (see
/// section 44/45 of the product spec) — Flutter has no direct equivalent.
class PrivacyProtection {
  PrivacyProtection._();

  static const _channel = MethodChannel('calculator_vault/privacy_protection');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableSecureFlag');
    } on PlatformException {
      // Non-fatal: continue without native screen protection rather than
      // crashing the app (e.g. running on a platform without the plugin).
    } on MissingPluginException {
      // Expected when running before the native Kotlin side is wired up in
      // a fresh `flutter create`-generated MainActivity — see
      // android/app/.../MainActivity.kt for the required registration.
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableSecureFlag');
    } on PlatformException {
      // no-op
    } on MissingPluginException {
      // no-op
    }
  }
}
