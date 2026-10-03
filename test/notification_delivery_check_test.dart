import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/app_language.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/yorks_v1_notification.dart';

void main() {
  test(
    'requested delivery check stays explicit and opens its protected record',
    () {
      const requestId = '14000000-0000-4000-8000-000000000001';
      final record = YorksV1NotificationRecord(
        id: '11000000-0000-4000-8000-000000000001',
        eventCode: 'notification_delivery_check',
        entityType: 'material_request',
        entityId: requestId,
        requestId: requestId,
        createdAt: DateTime.utc(2026, 10, 2),
      );
      for (final language in AppLanguage.values) {
        final notification = record.toAppNotification(language);
        expect(notification.route, '/yorks/material-requests/$requestId');
        expect(notification.origin, NotificationOrigin.yorksV1);
        expect(notification.type, NotificationType.info);
        expect(notification.isRead, isFalse);
        expect(notification.isUrgent, isFalse);
        expect(notification.title, isNotEmpty);
        expect(notification.body, isNotEmpty);
        expect(
          notification.title,
          isNot(
            YorksV1NotificationCopy.forEvent('future_event').title(language),
          ),
        );
      }
      final english = record.toAppNotification(AppLanguage.english);
      expect(english.title, 'Yorks device alert check');
      expect(
        english.body,
        'This is the notification delivery check you requested. Open to view the linked Yorks record.',
      );
    },
  );
}
