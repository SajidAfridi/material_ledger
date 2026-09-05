import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/language_provider.dart';

const _kLockEnabledKey = 'app_lock_enabled';

/// Retained compatibility provider for the removed local App Lock preference.
///
/// Yorks authentication and server-controlled session policy remain the
/// authority. P06 removes this device-only profile option, and deliberately
/// clears a previously stored value so an older enabled preference cannot lock
/// somebody out after the control used to disable it has disappeared.
final appLockEnabledProvider =
    StateNotifierProvider<_LockEnabledNotifier, bool>((ref) {
      return _LockEnabledNotifier(ref.watch(sharedPreferencesProvider));
    });

class _LockEnabledNotifier extends StateNotifier<bool> {
  _LockEnabledNotifier(this._prefs) : super(false) {
    if (_prefs.containsKey(_kLockEnabledKey)) {
      unawaited(_prefs.remove(_kLockEnabledKey));
    }
  }
  final SharedPreferences _prefs;

  @Deprecated('The Yorks profile App Lock preference was removed in P06.')
  Future<void> setEnabled(bool v) async {
    await _prefs.remove(_kLockEnabledKey);
    state = false;
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
