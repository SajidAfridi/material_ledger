import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'retains the same command key across controller reconstruction',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var sequence = 0;
      String nextKey() => 'key-${sequence++}';
      final firstStore = YorksV1CriticalCommandKeyStore(
        preferences: preferences,
        actorAuthUserId: 'actor-1',
        uuidFactory: nextKey,
      );
      final first = await firstStore.acquire(
        operation: 'dispatch_materials',
        entityId: 'request-1',
        payload: const {'request_id': 'request-1', 'quantity': '2'},
      );

      final reconstructedStore = YorksV1CriticalCommandKeyStore(
        preferences: preferences,
        actorAuthUserId: 'actor-1',
        uuidFactory: nextKey,
      );
      final retry = await reconstructedStore.acquire(
        operation: 'dispatch_materials',
        entityId: 'request-1',
        payload: const {'request_id': 'request-1', 'quantity': '2'},
      );

      expect(retry, first);
      expect(sequence, 1);
    },
  );

  test(
    'changes the key with changed intent and stores no command payload',
    () async {
      final preferences = await SharedPreferences.getInstance();
      var sequence = 0;
      final store = YorksV1CriticalCommandKeyStore(
        preferences: preferences,
        actorAuthUserId: 'actor-1',
        uuidFactory: () => 'key-${sequence++}',
      );
      final first = await store.acquire(
        operation: 'save_arrangement',
        entityId: 'arrangement-1',
        payload: const {'unit_cost': '125.50', 'note': 'protected supplier'},
      );
      final changed = await store.acquire(
        operation: 'save_arrangement',
        entityId: 'arrangement-1',
        payload: const {'unit_cost': '126.00', 'note': 'protected supplier'},
      );

      expect(changed, isNot(first));
      expect(preferences.getKeys(), hasLength(1));
      final stored = preferences.getString(preferences.getKeys().single)!;
      expect(stored, isNot(contains('125.50')));
      expect(stored, isNot(contains('126.00')));
      expect(stored, isNot(contains('protected supplier')));
    },
  );

  test('clears a lease only after confirmation', () async {
    final preferences = await SharedPreferences.getInstance();
    var sequence = 0;
    final store = YorksV1CriticalCommandKeyStore(
      preferences: preferences,
      actorAuthUserId: 'actor-1',
      uuidFactory: () => 'key-${sequence++}',
    );
    final first = await store.acquire(
      operation: 'confirm_receipt',
      entityId: 'dispatch-1',
      payload: const {'dispatch_id': 'dispatch-1'},
    );
    await store.confirm(
      operation: 'confirm_receipt',
      entityId: 'dispatch-1',
      idempotencyKey: 'not-the-active-key',
    );
    expect(
      await store.acquire(
        operation: 'confirm_receipt',
        entityId: 'dispatch-1',
        payload: const {'dispatch_id': 'dispatch-1'},
      ),
      first,
    );

    await store.confirm(
      operation: 'confirm_receipt',
      entityId: 'dispatch-1',
      idempotencyKey: first,
    );
    expect(
      await store.acquire(
        operation: 'confirm_receipt',
        entityId: 'dispatch-1',
        payload: const {'dispatch_id': 'dispatch-1'},
      ),
      isNot(first),
    );
  });
}
