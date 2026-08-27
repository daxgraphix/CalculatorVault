import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';

enum VaultSessionStatus { locked, authenticating, unlocked, locking, error }

/// Holds the vault's runtime session. The decrypted master key lives ONLY
/// here, in memory, for the lifetime of an unlocked session — it is never
/// persisted. When the session locks, the key reference is dropped.
class VaultSessionManager extends ChangeNotifier with WidgetsBindingObserver {
  VaultSessionStatus _status = VaultSessionStatus.locked;
  SecretKey? _masterKey;
  DateTime? _createdAt;
  DateTime? _lastActivity;
  Duration _autoLockDuration = const Duration(minutes: 1);
  Timer? _autoLockTimer;

  VaultSessionStatus get status => _status;
  SecretKey? get masterKey => _status == VaultSessionStatus.unlocked ? _masterKey : null;
  bool get isUnlocked => _status == VaultSessionStatus.unlocked;

  void setAutoLockDuration(Duration d) {
    _autoLockDuration = d;
    if (isUnlocked) _resetAutoLockTimer();
  }

  void beginAuthenticating() {
    _status = VaultSessionStatus.authenticating;
    notifyListeners();
  }

  void unlock(SecretKey masterKey) {
    _masterKey = masterKey;
    _createdAt = DateTime.now();
    _lastActivity = DateTime.now();
    _status = VaultSessionStatus.unlocked;
    _resetAutoLockTimer();
    notifyListeners();
  }

  void authenticationFailed() {
    _status = VaultSessionStatus.locked;
    notifyListeners();
  }

  void recordActivity() {
    if (!isUnlocked) return;
    _lastActivity = DateTime.now();
    _resetAutoLockTimer();
  }

  void lock() {
    _autoLockTimer?.cancel();
    _masterKey = null;
    _createdAt = null;
    _lastActivity = null;
    _status = VaultSessionStatus.locked;
    notifyListeners();
  }

  void _resetAutoLockTimer() {
    _autoLockTimer?.cancel();
    if (_autoLockDuration == Duration.zero) return; // "Never"
    _autoLockTimer = Timer(_autoLockDuration, lock);
  }

  // -- App lifecycle: background the app -> lock according to policy ------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // "Immediately" is the safe default when backgrounded; longer
      // durations are honored via the timer already running.
      if (_autoLockDuration == const Duration(seconds: 0)) {
        lock();
      }
    }
  }

  @override
  void dispose() {
    _autoLockTimer?.cancel();
    super.dispose();
  }
}
