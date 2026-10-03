import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/services/push_installation_lifecycle.dart';

void main() {
  test(
    'account switch fences old enrollment and orders cleanup before new enrollment',
    () async {
      var pending = false;
      final deleted = Completer<void>();
      final oldToken = Completer<String?>();
      final events = <String>[];
      final lifecycle = PushInstallationLifecycle(
        cleanupPending: () => pending,
        setCleanupPending: (value) async => pending = value,
        deleteToken: () async {
          events.add('delete');
          await deleted.future;
        },
      );
      final first = lifecycle.register((generation) async {
        await oldToken.future;
        if (!lifecycle.isCurrent(generation)) return null;
        events.add('old owner');
        return 'old';
      });
      await Future<void>.delayed(Duration.zero);
      final cleanup = lifecycle.retire(() async => events.add('unregister'));
      final next = lifecycle.register((_) async {
        events.add('new owner');
        return 'new';
      });
      await Future<void>.delayed(Duration.zero);
      expect(pending, isTrue);
      expect(events, ['unregister', 'delete']);
      oldToken.complete('old');
      expect(await first, isNull);
      deleted.complete();
      await cleanup;
      expect(await next, 'new');
      expect(events, ['unregister', 'delete', 'new owner']);
      expect(pending, isFalse);
    },
  );

  test(
    'offline logout persists cleanup across restart and blocks registration until retry succeeds',
    () async {
      var pending = false;
      var offline = true;
      var registrations = 0;
      PushInstallationLifecycle make() => PushInstallationLifecycle(
        cleanupPending: () => pending,
        setCleanupPending: (value) async => pending = value,
        deleteToken: () async {
          if (offline) throw StateError('offline');
        },
      );
      final original = make();
      await expectLater(
        original.retire(() async => throw StateError('offline')),
        throwsStateError,
      );
      original.dispose();
      expect(pending, isTrue);
      final restored = make();
      Future<String?> enroll(int _) async {
        registrations++;
        return 'fresh';
      }

      await expectLater(restored.register(enroll), throwsStateError);
      expect(registrations, 0);
      offline = false;
      expect(await restored.register(enroll), 'fresh');
      expect(pending, isFalse);
      expect(registrations, 1);
    },
  );

  test(
    'duplicate foreground enrollment coalesces and disposal fences completion',
    () async {
      final token = Completer<String?>();
      var calls = 0;
      final lifecycle = PushInstallationLifecycle(
        cleanupPending: () => false,
        setCleanupPending: (_) async {},
        deleteToken: () async {},
      );
      Future<String?> enroll(int generation) async {
        calls++;
        await token.future;
        return lifecycle.isCurrent(generation) ? 'fresh' : null;
      }

      final one = lifecycle.register(enroll);
      final two = lifecycle.register(enroll);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      lifecycle.dispose();
      token.complete();
      expect(await one, isNull);
      expect(await two, isNull);
    },
  );
}
