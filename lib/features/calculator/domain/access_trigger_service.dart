import '../../../core/storage/hive_boxes.dart';

/// Detects the configured "Vault Access Trigger" without putting any
/// encryption/authentication logic inside the calculator itself. The
/// calculator only asks: "was the trigger just satisfied?" — everything
/// else (PIN/password screen, session creation) is handled by the
/// authentication + session layers.
///
/// Two trigger mechanisms are supported, both configurable in Settings:
///  1. A secret numeric code evaluated instead of a normal result
///     (e.g. typing 007 and pressing "=").
///  2. A long-press on the "=" button (always available as a fallback so
///     the user is never locked out of their own vault).
class AccessTriggerService {
  static const _kTriggerCodeKey = 'access_trigger_code';
  static const _kTriggerEnabledKey = 'access_trigger_code_enabled';

  String? getTriggerCode() {
    final box = HiveBoxes.settingsBox;
    final enabled = box.get(_kTriggerEnabledKey, defaultValue: false) as bool;
    if (!enabled) return null;
    return box.get(_kTriggerCodeKey) as String?;
  }

  Future<void> setTriggerCode(String? code) async {
    final box = HiveBoxes.settingsBox;
    if (code == null || code.isEmpty) {
      await box.put(_kTriggerEnabledKey, false);
      await box.delete(_kTriggerCodeKey);
    } else {
      await box.put(_kTriggerEnabledKey, true);
      await box.put(_kTriggerCodeKey, code);
    }
  }

  /// Returns true if the raw calculator input (before evaluation) exactly
  /// matches the configured trigger code.
  bool matchesTrigger(String rawExpression) {
    final code = getTriggerCode();
    if (code == null) return false;
    return rawExpression.trim() == code.trim();
  }
}
