import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/providers/yorks_v1_material_request_provider.dart';

void main() {
  group('Yorks V1 Material Request Realtime refresh', () {
    test(
      'uses a safe signal only to invalidate authorized projections',
      () async {
        late Future<void> Function(YorksV1MaterialRequestRefreshReason reason)
        emit;
        final notifier = YorksV1MaterialRequestRealtimeNotifier(
          enabled: true,
          authUserId: '10000000-0000-4000-8000-000000000001',
          client: null,
          signalSubscription: ({required onSignal, required onUnavailable}) {
            emit = onSignal;
            return Future.value(true);
          },
          fallbackInterval: const Duration(days: 1),
        );
        addTearDown(notifier.dispose);

        await notifier.start();
        // The post-join re-fetch is a revision only; the notifier contains no
        // request/arrangement/quantity payload to act as client authority.
        expect(notifier.state, 1);

        await emit(YorksV1MaterialRequestRefreshReason.arrangement);
        await emit(YorksV1MaterialRequestRefreshReason.dispatch);
        await emit(YorksV1MaterialRequestRefreshReason.receiptReview);

        expect(notifier.state, 4);
      },
    );

    test('recognizes only V1 workflow notification envelopes', () {
      const expectedReasons = <String, YorksV1MaterialRequestRefreshReason>{
        'material_request': YorksV1MaterialRequestRefreshReason.materialRequest,
        'procurement_arrangement':
            YorksV1MaterialRequestRefreshReason.arrangement,
        'material_dispatch': YorksV1MaterialRequestRefreshReason.dispatch,
        'receipt_review': YorksV1MaterialRequestRefreshReason.receiptReview,
        'delivery_order': YorksV1MaterialRequestRefreshReason.deliveryOrder,
        'material_return': YorksV1MaterialRequestRefreshReason.materialReturn,
      };
      for (final entry in expectedReasons.entries) {
        expect(
          YorksV1MaterialRequestRealtimeNotifier.reasonFromNotification({
            'entity_type': entry.key,
            'entity_id': 'opaque-id',
          }),
          entry.value,
        );
      }
      expect(
        YorksV1MaterialRequestRealtimeNotifier.reasonFromNotification({
          'entity_type': 'attendance',
        }),
        isNull,
      );
    });

    test('a dropped signal never synthesizes a local workflow state', () async {
      late void Function(Object? error) signalUnavailable;
      final notifier = YorksV1MaterialRequestRealtimeNotifier(
        enabled: true,
        authUserId: '10000000-0000-4000-8000-000000000001',
        client: null,
        signalSubscription: ({required onSignal, required onUnavailable}) {
          signalUnavailable = onUnavailable;
          return Future.value(false);
        },
        fallbackInterval: const Duration(days: 1),
      );
      addTearDown(notifier.dispose);

      await notifier.start();
      signalUnavailable(StateError('websocket unavailable'));

      expect(notifier.state, 0);
    });

    test(
      'a healthy Realtime channel does not run periodic refreshes',
      () async {
        final notifier = YorksV1MaterialRequestRealtimeNotifier(
          enabled: true,
          authUserId: '10000000-0000-4000-8000-000000000001',
          client: null,
          signalSubscription: ({required onSignal, required onUnavailable}) {
            return Future.value(true);
          },
          fallbackInterval: const Duration(milliseconds: 5),
        );
        addTearDown(notifier.dispose);

        await notifier.start();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(notifier.state, 1);
      },
    );

    test(
      'an unavailable channel retains the authorized polling fallback',
      () async {
        final notifier = YorksV1MaterialRequestRealtimeNotifier(
          enabled: true,
          authUserId: '10000000-0000-4000-8000-000000000001',
          client: null,
          signalSubscription: ({required onSignal, required onUnavailable}) {
            return Future.value(false);
          },
          fallbackInterval: const Duration(milliseconds: 5),
        );
        addTearDown(notifier.dispose);

        await notifier.start();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(notifier.state, greaterThan(0));
      },
    );
  });
}
