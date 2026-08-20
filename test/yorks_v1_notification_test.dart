import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';
import 'package:material_ledger/shared/services/push_service.dart';

void main() {
  test('push payload keeps Team Chat on its dedicated surface', () {
    final chat = PushMessage.fromData({
      'notificationId': '21000000-0000-4000-8000-000000000001',
      'eventCode': 'team_chat_message',
      'surface': 'team_chat',
      'type': 'info',
      'title': 'New Team Chat message',
      'route': '/yorks/team-chat/22000000-0000-4000-8000-000000000001',
    });
    final workflow = PushMessage.fromData({
      'eventCode': 'material_request_submitted',
      'surface': 'workflow',
      'type': 'request',
      'title': 'New material request',
    });

    expect(chat.isTeamChat, isTrue);
    expect(workflow.isTeamChat, isFalse);
  });

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

  test('project membership alert uses the protected project route', () {
    final notification = YorksV1NotificationRecord.fromRpcJson({
      'notification_id': '21000000-0000-4000-8000-000000000002',
      'event_code': 'project_member_assigned',
      'entity_type': 'project_member',
      'entity_id': '24000000-0000-4000-8000-000000000001',
      'request_id': null,
      'project_id': '23000000-0000-4000-8000-000000000001',
      'created_at': '2026-08-13T12:00:00Z',
      'seen_at': null,
    }).toAppNotification(AppLanguage.english);

    expect(notification.title, 'Project access assigned');
    expect(
      notification.route,
      '/yorks/projects/23000000-0000-4000-8000-000000000001',
    );
  });

  test('return decisions and cancellation have specific safe copy', () {
    expect(
      record(
        eventCode: 'material_return_confirmed',
      ).toAppNotification(AppLanguage.english).title,
      'Material return confirmed',
    );
    expect(
      record(
        eventCode: 'material_request_cancelled',
      ).toAppNotification(AppLanguage.english).title,
      'Material request cancelled',
    );
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
