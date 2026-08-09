import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';

void main() {
  const requestId = '22000000-0000-4000-8000-000000000001';

  YorksV1NotificationRecord record({
    String eventCode = 'material_request_submitted',
    DateTime? seenAt,
  }) {
    return YorksV1NotificationRecord.fromRpcJson({
      'notification_id': '21000000-0000-4000-8000-000000000001',
      'event_code': eventCode,
      'entity_type': 'material_request',
      'entity_id': requestId,
      'request_id': requestId,
      'project_id': '23000000-0000-4000-8000-000000000001',
      'created_at': '2026-08-09T12:00:00Z',
      'seen_at': seenAt?.toUtc().toIso8601String(),
    });
  }

  test('server notification maps to the exact Material Request route', () {
    final notification = record().toAppNotification(AppLanguage.english);

    expect(notification.origin, NotificationOrigin.yorksV1);
    expect(notification.type, NotificationType.request);
    expect(notification.refId, requestId);
    expect(notification.route, '/yorks/material-requests/$requestId');
    expect(notification.isRead, isFalse);
    expect(notification.title, 'New material request');
  });

  test('seen_at is the only authoritative read-state source', () {
    final notification = record(
      seenAt: DateTime.utc(2026, 8, 9, 12, 5),
    ).toAppNotification(AppLanguage.english);

    expect(notification.isRead, isTrue);
  });

  test('workflow notification copy supports every configured language', () {
    for (final language in AppLanguage.values) {
      final notification = record().toAppNotification(language);
      expect(notification.title.trim(), isNotEmpty, reason: language.code);
      expect(notification.body.trim(), isNotEmpty, reason: language.code);
    }
  });

  test('unknown server event remains safe and routes to its request', () {
    final notification = record(
      eventCode: 'future_server_event',
    ).toAppNotification(AppLanguage.english);

    expect(notification.type, NotificationType.info);
    expect(notification.title, 'Yorks workflow update');
    expect(notification.route, '/yorks/material-requests/$requestId');
  });

  test('legacy JSON remains legacy while server origin round-trips', () {
    final legacy = AppNotification.fromJson({
      'id': 'legacy',
      'type': 'info',
      'title': 'Legacy',
      'timestamp': '2026-08-09T12:00:00Z',
    });
    expect(legacy.origin, NotificationOrigin.legacy);

    final server = record().toAppNotification(AppLanguage.english);
    expect(
      AppNotification.fromJson(server.toJson()).origin,
      NotificationOrigin.yorksV1,
    );
  });
}
