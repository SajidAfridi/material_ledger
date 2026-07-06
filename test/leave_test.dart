import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/app_notification.dart';
import 'package:material_ledger/shared/models/leave_record.dart';
import 'package:material_ledger/shared/models/role_permissions.dart';
import 'package:material_ledger/shared/models/user_role.dart';
import 'package:material_ledger/shared/providers/hr_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/notification_provider.dart';

void main() {
  group('LeaveNotifier — request workflow', () {
    late ProviderContainer container;
    late LeaveNotifier notifier;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      notifier = container.read(leaveRecordsProvider.notifier);
    });

    test('submitRequest creates a pending request with computed days', () async {
      final r = await notifier.submitRequest(
        employeeId: 'emp-001',
        requestedByUserId: 'u1',
        requestedByName: 'Ahmed',
        type: LeaveType.annual,
        startDate: DateTime(2026, 3, 10),
        endDate: DateTime(2026, 3, 12),
        reason: 'Family',
      );
      expect(r.status, LeaveRecordStatus.pending);
      expect(r.days, 3);
      expect(r.isRequest, isTrue);
      expect(r.requestedByUserId, 'u1');
      expect(container.read(pendingLeaveRequestsProvider).any((x) => x.id == r.id), isTrue);
    });

    test('decide approves a request, stamping decider + time', () async {
      final r = await notifier.submitRequest(
        employeeId: 'emp-001',
        requestedByUserId: 'u1',
        requestedByName: 'Ahmed',
        type: LeaveType.annual,
        startDate: DateTime(2026, 3, 10),
        endDate: DateTime(2026, 3, 12),
      );
      final updated = await notifier.decide(
        r.id,
        approve: true,
        decidedBy: 'Owner (Admin)',
        decidedByUserId: 'admin',
      );
      expect(updated, isNotNull);
      expect(updated!.status, LeaveRecordStatus.approved);
      expect(updated.approvedBy, 'Owner (Admin)');
      expect(updated.decidedAt, isNotNull);
      // No longer in the pending queue.
      expect(container.read(pendingLeaveRequestsProvider).any((x) => x.id == r.id), isFalse);
    });

    test('decide rejects with a reason', () async {
      final r = await notifier.submitRequest(
        employeeId: 'emp-001',
        requestedByUserId: 'u1',
        requestedByName: 'Ahmed',
        type: LeaveType.unpaid,
        startDate: DateTime(2026, 3, 10),
        endDate: DateTime(2026, 3, 11),
      );
      final updated = await notifier.decide(
        r.id,
        approve: false,
        decidedBy: 'Owner (Admin)',
        decidedByUserId: 'admin',
        decisionNote: 'Peak season',
      );
      expect(updated!.status, LeaveRecordStatus.rejected);
      expect(updated.decisionNote, 'Peak season');
    });

    test('a user cannot decide their own request', () async {
      final r = await notifier.submitRequest(
        employeeId: 'emp-002',
        requestedByUserId: 'u-self',
        requestedByName: 'Self',
        type: LeaveType.annual,
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 2),
      );
      final blocked = await notifier.decide(
        r.id,
        approve: true,
        decidedBy: 'Self',
        decidedByUserId: 'u-self', // same user
      );
      expect(blocked, isNull);
      final still = notifier.forEmployee('emp-002').firstWhere((x) => x.id == r.id);
      expect(still.status, LeaveRecordStatus.pending);
    });

    test('withdraw only cancels a pending request', () async {
      final r = await notifier.submitRequest(
        employeeId: 'emp-001',
        requestedByUserId: 'u1',
        requestedByName: 'Ahmed',
        type: LeaveType.annual,
        startDate: DateTime(2026, 5, 1),
        endDate: DateTime(2026, 5, 3),
      );
      await notifier.withdraw(r.id);
      var rec = notifier.forEmployee('emp-001').firstWhere((x) => x.id == r.id);
      expect(rec.status, LeaveRecordStatus.cancelled);

      // Withdrawing a non-pending record is a no-op.
      await notifier.withdraw(r.id);
      rec = notifier.forEmployee('emp-001').firstWhere((x) => x.id == r.id);
      expect(rec.status, LeaveRecordStatus.cancelled);
    });

    test('leaveOverlaps detects active overlaps and ignores rejected', () async {
      await notifier.submitRequest(
        employeeId: 'emp-005',
        requestedByUserId: 'u5',
        requestedByName: 'Omar',
        type: LeaveType.annual,
        startDate: DateTime(2026, 6, 10),
        endDate: DateTime(2026, 6, 15),
      );
      expect(
        notifier.leaveOverlaps('emp-005', DateTime(2026, 6, 14), DateTime(2026, 6, 18)),
        isTrue,
      );
      expect(
        notifier.leaveOverlaps('emp-005', DateTime(2026, 6, 16), DateTime(2026, 6, 18)),
        isFalse,
      );
    });

    test('only APPROVED annual leave reduces the balance', () async {
      // emp-001 seed: 8 approved annual days this year → 22 remaining.
      final year = DateTime.now().year;
      final before = container.read(leaveBalanceProvider('emp-001'));

      final r = await notifier.submitRequest(
        employeeId: 'emp-001',
        requestedByUserId: 'u1',
        requestedByName: 'Ahmed',
        type: LeaveType.annual,
        startDate: DateTime(year, 8, 1),
        endDate: DateTime(year, 8, 3), // 3 days
      );
      // Pending → balance unchanged.
      expect(
        container.read(leaveBalanceProvider('emp-001')).remaining,
        before.remaining,
      );

      await notifier.decide(r.id, approve: true, decidedBy: 'Admin', decidedByUserId: 'admin');
      // Approved → balance drops by 3.
      expect(
        container.read(leaveBalanceProvider('emp-001')).remaining,
        before.remaining - 3,
      );
    });
  });

  group('approveLeave capability', () {
    final perms = RolePermissions.fromRoleDefaults();
    test('engineers cannot approve leave', () {
      expect(
        resolveCapability(null, UserRole.engineer, perms, RoleCapability.approveLeave),
        isFalse,
      );
    });
    test('procurement and admin can approve leave', () {
      expect(
        resolveCapability(null, UserRole.procurement, perms, RoleCapability.approveLeave),
        isTrue,
      );
      expect(
        resolveCapability(null, UserRole.admin, perms, RoleCapability.approveLeave),
        isTrue,
      );
    });
  });

  group('per-user notification targeting', () {
    AppNotification userNote(String userId) => AppNotification(
      id: 'n1',
      type: NotificationType.request,
      title: 'Leave approved',
      titleSecondary: '',
      timestamp: DateTime(2026, 1, 1),
      userId: userId,
    );

    test('only the targeted user (and admin) sees a user-targeted note', () {
      final n = userNote('u-eng-1');
      // The target engineer sees it.
      expect(
        notificationVisibleTo(n, UserRole.engineer, currentUserId: 'u-eng-1'),
        isTrue,
      );
      // A different engineer does NOT.
      expect(
        notificationVisibleTo(n, UserRole.engineer, currentUserId: 'u-eng-2'),
        isFalse,
      );
      // Admin reads all.
      expect(notificationVisibleTo(n, UserRole.admin, currentUserId: 'x'), isTrue);
    });

    test('role-audience notes still work when no userId is set', () {
      final n = AppNotification(
        id: 'n2',
        type: NotificationType.request,
        title: 'New leave request',
        titleSecondary: '',
        timestamp: DateTime(2026, 1, 1),
        audience: 'procurement',
      );
      expect(notificationVisibleTo(n, UserRole.procurement), isTrue);
      expect(notificationVisibleTo(n, UserRole.engineer), isFalse);
    });
  });
}
