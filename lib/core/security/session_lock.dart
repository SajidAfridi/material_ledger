import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/language_provider.dart';

const _kLockEnabledKey = 'app_lock_enabled';

/// User setting: require a biometric / passcode unlock when the app is launched
/// fresh (cold start). Off by default. Toggled from the engineer profile.
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

/// Whether the app is currently locked behind biometric / device passcode.
///
/// **Policy: lock only on a cold start** — i.e. when the app process is launched
/// fresh while App Lock is enabled and a session was restored. We deliberately
/// do NOT lock on resume from background: switching to another app, or opening
/// the receipt in the system preview, must never strand the user behind a lock.
/// A fresh credential login calls [unlock], so the user is not biometric-prompted
/// right after typing their password.
final sessionLockedProvider =
    StateNotifierProvider<SessionLockController, bool>((ref) {
      return SessionLockController(ref);
    });

class SessionLockController extends StateNotifier<bool> {
  SessionLockController(this._ref) : super(false) {
    // Cold start: begin locked if App Lock is enabled. The overlay only actually
    // appears once a (restored) session is present — see `_AppChrome.showLock`.
    if (_ref.read(appLockEnabledProvider)) state = true;
  }

  final Ref _ref;

  void lock() {
    if (!state) state = true;
  }

  void unlock() {
    if (state) state = false;
  }
}
