import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/material_request_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';

/// Build a notification with a fixed timestamp (DateTime can't be const).
AppNotification _notif({
  String audience = '',
  String refId = '',
  String route = '',
  NotificationType type = NotificationType.info,
}) => AppNotification(
      id: 'n',
      type: type,
      title: 'T',
      titleSecondary: '',
      timestamp: DateTime(2025, 1, 1),
      audience: audience,
      refId: refId,
      route: route,
    );

void main() {
  group('Notification deep-link + audience', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('add() persists refId, route and audience', () async {
      await container.read(notificationsProvider.notifier).add(
            type: NotificationType.request,
            title: 'New material request',
            titleSecondary: '',
            refId: 'req-xyz',
            route: '/admin/dispatch/req-xyz',
            audience: 'procurement',
          );
      final n = container.read(notificationsProvider).first;
      expect(n.refId, 'req-xyz');
      expect(n.route, '/admin/dispatch/req-xyz');
      expect(n.audience, 'procurement');
    });

    test('markRead preserves the deep-link fields (copyWith)', () async {
      await container.read(notificationsProvider.notifier).add(
            type: NotificationType.plan,
            title: 'Plan',
            titleSecondary: '',
            refId: 'proj-1',
            route: '/plan/proj-1',
            audience: 'engineer',
          );
      final id = container.read(notificationsProvider).first.id;
      await container.read(notificationsProvider.notifier).markRead(id);
      final n =
          container.read(notificationsProvider).firstWhere((x) => x.id == id);
      expect(n.isRead, true);
      expect(n.route, '/plan/proj-1');
      expect(n.refId, 'proj-1');
      expect(n.audience, 'engineer');
    });

    test('JSON round-trip keeps new fields; missing keys default to empty', () {
      final original = _notif(
        type: NotificationType.request,
        refId: 'req-1',
        route: '/admin/dispatch/req-1',
        audience: 'procurement',
      );
      final back = AppNotification.fromJson(original.toJson());
      expect(back.refId, 'req-1');
      expect(back.route, '/admin/dispatch/req-1');
      expect(back.audience, 'procurement');

      // Old persisted JSON (pre-deep-link) decodes cleanly to broadcast.
      final legacy = AppNotification.fromJson({
        'id': 'old',
        'type': 'plan',
        'title': 'Legacy',
        'titleSecondary': '',
        'timestamp': '2025-01-01T00:00:00.000',
      });
      expect(legacy.refId, '');
      expect(legacy.route, '');
      expect(legacy.audience, ''); // broadcast — still visible to everyone
    });

    test('procurement alert reaches procurement + admin only', () {
      final n = _notif(audience: 'procurement', type: NotificationType.request);
      expect(notificationVisibleTo(n, UserRole.procurement), true);
      expect(notificationVisibleTo(n, UserRole.admin), true); // read-all
      expect(notificationVisibleTo(n, UserRole.engineer), false);
    });

    test('engineer alert reaches engineer + admin only', () {
      final n = _notif(audience: 'engineer', type: NotificationType.plan);
      expect(notificationVisibleTo(n, UserRole.engineer), true);
      expect(notificationVisibleTo(n, UserRole.admin), true);
      expect(notificationVisibleTo(n, UserRole.procurement), false);
    });

    test('empty audience broadcasts to every role', () {
      final n = _notif();
      for (final role in UserRole.values) {
        expect(notificationVisibleTo(n, role), true);
      }
    });
  });

  group('Procurement queue counts', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('a newly submitted request lands in the dispatch queue count', () async {
      final before = container.read(dispatchQueueCountProvider);
      await container.read(materialRequestsProvider.notifier).addRequest(
            projectName: 'Test',
            projectNameSecondary: '',
            itemCount: 1,
            lineItems: const [
              RequestLineItem(
                materialId: 'mat-001',
                materialName: 'Gate Valve 2" (Brass)',
                materialNameSecondary: '',
                quantity: 2,
                unitSymbol: 'pcs',
              ),
            ],
          );
      expect(container.read(dispatchQueueCountProvider), before + 1);
    });

    test('addRequest returns the created request (for deep-linking)', () async {
      final req = await container
          .read(materialRequestsProvider.notifier)
          .addRequest(
            projectName: 'Test',
            projectNameSecondary: '',
            itemCount: 0,
          );
      expect(req.id, isNotEmpty);
      expect(req.status, RequestStatus.pending);
    });
  });
}
