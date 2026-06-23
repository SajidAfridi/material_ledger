import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/core/security/session_lock.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('SessionLockController — cold-start policy', () {
    test('starts UNLOCKED when App Lock is disabled', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(sessionLockedProvider), isFalse);
    });

    test('starts LOCKED on cold start when App Lock is enabled', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      // Cold start with the setting on → locked (the overlay then gates on a
      // signed-in session in _AppChrome).
      expect(c.read(sessionLockedProvider), isTrue);
    });

    test('unlock() clears the lock (e.g. after biometric / fresh login)',
        () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(sessionLockedProvider), isTrue);

      c.read(sessionLockedProvider.notifier).unlock();
      expect(c.read(sessionLockedProvider), isFalse);
    });

    test('enabling App Lock mid-session does NOT lock the current session',
        () async {
      // The setting starts off → controller constructs unlocked.
      SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(sessionLockedProvider), isFalse);

      // Turn it on while using the app — current session stays unlocked; the
      // lock only takes effect on the next cold start.
      await c.read(appLockEnabledProvider.notifier).setEnabled(true);
      expect(c.read(appLockEnabledProvider), isTrue);
      expect(c.read(sessionLockedProvider), isFalse);
    });
  });
}
