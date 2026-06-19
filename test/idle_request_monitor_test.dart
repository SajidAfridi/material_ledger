import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/app/idle_request_monitor.dart';
import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/user_role.dart';

MaterialRequest _req({
  required String id,
  required RequestStatus status,
  required DateTime requestDate,
}) => MaterialRequest(
      id: id,
      projectName: 'P',
      projectNameSecondary: '',
      status: status,
      requestDate: requestDate,
      itemCount: 1,
    );

AppNotification _adminFlag(String refId) => AppNotification(
      id: 'n-$refId',
      type: NotificationType.request,
      title: 'Idle',
      titleSecondary: '',
      timestamp: DateTime(2026, 1, 1),
      refId: refId,
      audience: 'admin',
    );

void main() {
  final now = DateTime(2026, 6, 19, 12);
  final old = now.subtract(const Duration(hours: 30)); // > 24h
  final fresh = now.subtract(const Duration(hours: 2)); // < 24h

  group('staleRequests (FR-066)', () {
    test('flags a pending request idle beyond the threshold', () {
      final stale = staleRequests(
        [_req(id: 'req-1', status: RequestStatus.pending, requestDate: old)],
        const [],
        now,
      );
      expect(stale.map((r) => r.id), ['req-1']);
    });

    test('ignores a pending request still within the threshold', () {
      final stale = staleRequests(
        [_req(id: 'req-2', status: RequestStatus.pending, requestDate: fresh)],
        const [],
        now,
      );
      expect(stale, isEmpty);
    });

    test('ignores requests that have already had action (not pending)', () {
      final stale = staleRequests(
        [
          _req(id: 'd', status: RequestStatus.dispatched, requestDate: old),
          _req(id: 'h', status: RequestStatus.onHold, requestDate: old),
          _req(id: 'p', status: RequestStatus.partial, requestDate: old),
        ],
        const [],
        now,
      );
      expect(stale, isEmpty);
    });

    test('does not re-flag a request already alerted to admin (dedup)', () {
      final stale = staleRequests(
        [_req(id: 'req-3', status: RequestStatus.pending, requestDate: old)],
        [_adminFlag('req-3')],
        now,
      );
      expect(stale, isEmpty);
    });

    test('an engineer-audience notification does not count as flagged', () {
      // A dispatch notification for the same request is audience=engineer; it
      // must NOT suppress the admin idle alert.
      final engineerNote = AppNotification(
        id: 'e',
        type: NotificationType.request,
        title: 'Dispatched',
        titleSecondary: '',
        timestamp: DateTime(2026, 1, 1),
        refId: 'req-4',
        audience: UserRole.engineer.name,
      );
      final stale = staleRequests(
        [_req(id: 'req-4', status: RequestStatus.pending, requestDate: old)],
        [engineerNote],
        now,
      );
      expect(stale.map((r) => r.id), ['req-4']);
    });
  });
}
