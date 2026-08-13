import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';
import 'package:material_ledger/shared/providers/yorks_v1_notification_provider.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_notification_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'single acknowledgement is optimistic and survives a second device',
    () async {
      final gate = Completer<void>();
      final repository = _FakeNotificationRepository([
        _record('11000000-0000-4000-8000-000000000001'),
      ], markGate: gate);
      final notifier = _notifier(repository);
      addTearDown(notifier.dispose);
      await notifier.start();

      final acknowledgement = notifier.markSeen(repository.records.single.id);
      expect(notifier.state.valueOrNull!.single.seenAt, isNotNull);
      expect(repository.markSeenCalls, 1);

      gate.complete();
      await acknowledgement;
      final secondDevice = _notifier(repository);
      addTearDown(secondDevice.dispose);
      await secondDevice.start();
      expect(secondDevice.state.valueOrNull!.single.seenAt, isNotNull);
    },
  );

  test('mark all acknowledges every item with one server command', () async {
    final repository = _FakeNotificationRepository([
      _record('11000000-0000-4000-8000-000000000001'),
      _record('11000000-0000-4000-8000-000000000002'),
    ]);
    final notifier = _notifier(repository);
    addTearDown(notifier.dispose);
    await notifier.start();

    final acknowledgement = notifier.markAllSeen();
    expect(
      notifier.state.valueOrNull!.every((record) => record.seenAt != null),
      isTrue,
    );
    await acknowledgement;
    expect(repository.markAllSeenCalls, 1);
    expect(repository.markSeenCalls, 0);
  });
}

YorksV1NotificationsNotifier _notifier(
  YorksV1NotificationRepository repository,
) => YorksV1NotificationsNotifier(
  client: SupabaseClient('https://ci.invalid', 'ci-publishable-key'),
  repository: repository,
  authUserId: '10000000-0000-4000-8000-000000000001',
);

YorksV1NotificationRecord _record(String id) => YorksV1NotificationRecord(
  id: id,
  eventCode: 'material_request_mentioned',
  entityType: 'material_request',
  entityId: '12000000-0000-4000-8000-000000000001',
  createdAt: DateTime(2026, 8, 14),
);

class _FakeNotificationRepository implements YorksV1NotificationRepository {
  _FakeNotificationRepository(this.records, {this.markGate});

  List<YorksV1NotificationRecord> records;
  final Completer<void>? markGate;
  int markSeenCalls = 0;
  int markAllSeenCalls = 0;

  @override
  Future<List<YorksV1NotificationRecord>> listMine({int limit = 100}) async =>
      List.of(records.take(limit));

  @override
  Future<void> markSeen(String notificationId) async {
    markSeenCalls += 1;
    await markGate?.future;
    final now = DateTime.now();
    records = [
      for (final record in records)
        if (record.id == notificationId) record.acknowledgedAt(now) else record,
    ];
  }

  @override
  Future<int> markAllSeen() async {
    markAllSeenCalls += 1;
    final now = DateTime.now();
    final unread = records.where((record) => record.seenAt == null).length;
    records = [
      for (final record in records)
        if (record.seenAt == null) record.acknowledgedAt(now) else record,
    ];
    return unread;
  }
}
