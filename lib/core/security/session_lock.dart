import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/language_provider.dart';

const _kLockEnabledKey = 'app_lock_enabled';
const _kLockTimeoutKey = 'app_lock_timeout_min';

/// User setting: lock the app after inactivity / on resume. Off by default.
final appLockEnabledProvider =
    StateNotifierProvider<_LockEnabledNotifier, bool>((ref) {
      return _LockEnabledNotifier(ref.watch(sharedPreferencesProvider));
    });

class _LockEnabledNotifier extends StateNotifier<bool> {
  _LockEnabledNotifier(this._prefs)
    : super(_prefs.getBool(_kLockEnabledKey) ?? false);
  final SharedPreferences _prefs;
  Future<void> setEnabled(bool v) async {
    await _prefs.setBool(_kLockEnabledKey, v);
    state = v;
  }
}

/// Idle timeout in minutes before the app auto-locks (default 5).
final appLockTimeoutProvider =
    StateNotifierProvider<_LockTimeoutNotifier, int>((ref) {
      return _LockTimeoutNotifier(ref.watch(sharedPreferencesProvider));
    });

class _LockTimeoutNotifier extends StateNotifier<int> {
  _LockTimeoutNotifier(this._prefs)
    : super(_prefs.getInt(_kLockTimeoutKey) ?? 5);
  final SharedPreferences _prefs;
  Future<void> setMinutes(int m) async {
    await _prefs.setInt(_kLockTimeoutKey, m);
    state = m;
  }
}

/// Whether the app is currently locked (must biometric/PIN-unlock to continue).
/// Locks on resume-from-background and after the idle timeout, but only while
/// the lock is enabled AND a user is signed in.
final sessionLockedProvider =
    StateNotifierProvider<SessionLockController, bool>((ref) {
      return SessionLockController(ref);
    });

class SessionLockController extends StateNotifier<bool>
    with WidgetsBindingObserver {
  SessionLockController(this._ref) : super(false) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Ref _ref;
  Timer? _idleTimer;

  /// True while the biometric sheet is being shown. The OS sheet briefly
  /// backgrounds the app; without this guard the resulting lifecycle bounce
  /// would re-lock immediately after a successful unlock (infinite re-prompt).
  bool _authenticating = false;
  void setAuthenticating(bool value) => _authenticating = value;

  bool get _armed =>
      _ref.read(appLockEnabledProvider) && _ref.read(isLoggedInProvider);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock when the app is actually backgrounded — NOT on resume (a successful
    // biometric unlock triggers a resume, which must not re-lock), and never
    // while the biometric sheet itself is up.
    if (_authenticating) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_armed) lock();
    }
  }

  /// Called on user interaction to (re)start the idle countdown.
  void registerInteraction() {
    if (state) return; // already locked
    _idleTimer?.cancel();
    if (!_armed) return;
    _idleTimer = Timer(Duration(minutes: _ref.read(appLockTimeoutProvider)), lock);
  }

  void lock() {
    _idleTimer?.cancel();
    if (!state) state = true;
  }

  void unlock() {
    state = false;
    registerInteraction();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
