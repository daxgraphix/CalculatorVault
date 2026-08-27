import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/hive_boxes.dart';

enum AppThemeMode { system, light, dark }
enum RecycleBinRetention { days7, days30, never }

class SettingsRepository {
  final _box = HiveBoxes.settingsBox;

  static const _kTheme = 'theme_mode';
  static const _kAutoLockSeconds = 'auto_lock_seconds';
  static const _kScreenProtection = 'screen_protection';
  static const _kHaptics = 'haptics';
  static const _kSound = 'sound';
  static const _kRecycleBinRetention = 'recycle_bin_retention';
  static const _kGridSize = 'grid_size';

  AppThemeMode getThemeMode() {
    final v = _box.get(_kTheme, defaultValue: 'system') as String;
    return AppThemeMode.values.firstWhere((e) => e.name == v, orElse: () => AppThemeMode.system);
  }

  Future<void> setThemeMode(AppThemeMode mode) => _box.put(_kTheme, mode.name);

  Duration getAutoLockDuration() {
    final seconds = _box.get(_kAutoLockSeconds, defaultValue: 60) as int;
    return Duration(seconds: seconds);
  }

  Future<void> setAutoLockDuration(Duration d) => _box.put(_kAutoLockSeconds, d.inSeconds);

  bool getScreenProtectionEnabled() => _box.get(_kScreenProtection, defaultValue: true) as bool;
  Future<void> setScreenProtectionEnabled(bool v) => _box.put(_kScreenProtection, v);

  bool getHapticsEnabled() => _box.get(_kHaptics, defaultValue: true) as bool;
  Future<void> setHapticsEnabled(bool v) => _box.put(_kHaptics, v);

  bool getSoundEnabled() => _box.get(_kSound, defaultValue: false) as bool;
  Future<void> setSoundEnabled(bool v) => _box.put(_kSound, v);

  RecycleBinRetention getRecycleBinRetention() {
    final v = _box.get(_kRecycleBinRetention, defaultValue: 'days30') as String;
    return RecycleBinRetention.values.firstWhere((e) => e.name == v, orElse: () => RecycleBinRetention.days30);
  }

  Future<void> setRecycleBinRetention(RecycleBinRetention r) => _box.put(_kRecycleBinRetention, r.name);

  int getGridSize() => _box.get(_kGridSize, defaultValue: 3) as int;
  Future<void> setGridSize(int v) => _box.put(_kGridSize, v);
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) => SettingsRepository());
