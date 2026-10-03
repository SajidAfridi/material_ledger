import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/services/push_installation_language.dart';
import 'package:material_ledger/shared/services/push_installation_lifecycle.dart';

void main() {
  test(
    'a language change during coalesced registration persists the latest choice',
    () async {
      var language = 'en';
      final firstUpdate = Completer<bool>();
      final updates = <String>[];
      final lifecycle = PushInstallationLifecycle(
        cleanupPending: () => false,
        setCleanupPending: (_) async {},
        deleteToken: () async {},
      );
      addTearDown(lifecycle.dispose);
      Future<String?> enroll(int generation) async {
        final saved = await syncCurrentPushLanguage(
          readLanguage: () => language,
          isCurrent: () => lifecycle.isCurrent(generation),
          update: (value) {
            updates.add(value);
            return updates.length == 1
                ? firstUpdate.future
                : Future.value(true);
          },
        );
        return saved ? 'registered' : null;
      }

      final first = lifecycle.register(enroll);
      await Future<void>.delayed(Duration.zero);
      expect(updates, ['en']);
      language = 'ar';
      final second = lifecycle.register(enroll);
      firstUpdate.complete(true);
      expect(await first, 'registered');
      expect(await second, 'registered');
      expect(updates, ['en', 'ar']);
    },
  );

  test(
    'retirement fences a pending locale and prevents an old-owner follow-up',
    () async {
      var current = true;
      var language = 'en';
      final response = Completer<bool>();
      final updates = <String>[];
      final syncing = syncCurrentPushLanguage(
        readLanguage: () => language,
        isCurrent: () => current,
        update: (value) {
          updates.add(value);
          return response.future;
        },
      );
      current = false;
      language = 'ar';
      response.complete(true);
      expect(await syncing, isFalse);
      expect(updates, ['en']);
    },
  );

  test(
    'server rejection does not report localized enrollment success',
    () async {
      var updates = 0;
      expect(
        await syncCurrentPushLanguage(
          readLanguage: () => 'ur',
          isCurrent: () => true,
          update: (_) async {
            updates++;
            return false;
          },
        ),
        isFalse,
      );
      expect(updates, 1);
    },
  );

  test('continuous language changes have a bounded attempt count', () async {
    var language = 0;
    const languages = ['en', 'ar', 'ur', 'hi'];
    final updates = <String>[];
    expect(
      await syncCurrentPushLanguage(
        readLanguage: () => languages[language],
        isCurrent: () => true,
        update: (value) async {
          updates.add(value);
          language++;
          return true;
        },
      ),
      isFalse,
    );
    expect(updates, ['en', 'ar', 'ur']);
  });

  testWidgets('a stalled language update has a bounded request budget', (
    tester,
  ) async {
    final response = Completer<bool>();
    final syncing = syncCurrentPushLanguage(
      readLanguage: () => 'hi',
      isCurrent: () => true,
      update: (_) => response.future,
      timeout: const Duration(seconds: 1),
    );
    final failure = expectLater(syncing, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 1));
    await failure;
    response.complete(true);
    await tester.pump();
  });
}
