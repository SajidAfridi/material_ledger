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
  group('removed profile App Lock compatibility', () {
    test('starts unlocked when the old preference is disabled', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(sessionLockedProvider), isFalse);
    });

    test('ignores an old enabled value and starts unlocked', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(appLockEnabledProvider), isFalse);
      expect(c.read(sessionLockedProvider), isFalse);
    });

    test('unlock remains a safe no-op for retained callers', () async {
      SharedPreferences.setMockInitialValues({'app_lock_enabled': true});
      final prefs = await SharedPreferences.getInstance();
      final c = _container(prefs);
      expect(c.read(sessionLockedProvider), isFalse);

      c.read(sessionLockedProvider.notifier).unlock();
      expect(c.read(sessionLockedProvider), isFalse);
    });

    test(
      'obsolete enable calls cannot restore the removed preference',
      () async {
        SharedPreferences.setMockInitialValues({'app_lock_enabled': false});
        final prefs = await SharedPreferences.getInstance();
        final c = _container(prefs);
        expect(c.read(sessionLockedProvider), isFalse);

        await c.read(appLockEnabledProvider.notifier).setEnabled(true);
        expect(c.read(appLockEnabledProvider), isFalse);
        expect(c.read(sessionLockedProvider), isFalse);
      },
    );
  });
}
