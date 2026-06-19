import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/attendance_record.dart';
import 'package:material_ledger/shared/models/leave_record.dart';
import 'package:material_ledger/shared/providers/hr_provider.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
  });

  group('Leave balance (FR-127, 30-day annual entitlement)', () {
    test('seed: emp-001 has 8 approved annual days → 22 remaining', () {
      final bal = container.read(leaveBalanceProvider('emp-001'));
      expect(bal.entitlement, 30);
      expect(bal.usedAnnual, 8);
      expect(bal.remaining, 22);
    });

    test('recording approved annual leave reduces the balance', () async {
      await container.read(leaveRecordsProvider.notifier).addLeave(
            employeeId: 'emp-001',
            type: LeaveType.annual,
            startDate: DateTime(DateTime.now().year, 5, 1),
            endDate: DateTime(DateTime.now().year, 5, 5), // 5 days
            status: LeaveRecordStatus.approved,
          );
      final bal = container.read(leaveBalanceProvider('emp-001'));
      expect(bal.usedAnnual, 13);
      expect(bal.remaining, 17);
    });

    test('sick leave does NOT consume the annual balance', () async {
      await container.read(leaveRecordsProvider.notifier).addLeave(
            employeeId: 'emp-001',
            type: LeaveType.sick,
            startDate: DateTime(DateTime.now().year, 5, 1),
            endDate: DateTime(DateTime.now().year, 5, 3),
            status: LeaveRecordStatus.approved,
          );
      final bal = container.read(leaveBalanceProvider('emp-001'));
      expect(bal.usedAnnual, 8); // unchanged
    });

    test('pending annual leave does NOT consume the balance until approved',
        () async {
      await container.read(leaveRecordsProvider.notifier).addLeave(
            employeeId: 'emp-002',
            type: LeaveType.annual,
            startDate: DateTime(DateTime.now().year, 5, 1),
            endDate: DateTime(DateTime.now().year, 5, 4),
            status: LeaveRecordStatus.pending,
          );
      expect(container.read(leaveBalanceProvider('emp-002')).usedAnnual, 0);
    });
  });

  group('HR attendance summary (FR-125)', () {
    test('seed: 3 present, 1 on leave, 1 absent of 5', () {
      final s = container.read(hrSummaryProvider);
      expect(s.total, 5);
      expect(s.presentToday, 3);
      expect(s.onLeaveToday, 1);
      expect(s.absentToday, 1);
    });

    test('marking an absentee present updates the summary', () async {
      await container.read(attendanceProvider.notifier).markToday(
            employeeId: 'emp-005',
            status: AttendanceStatus.present,
            recordedBy: 'test',
          );
      final s = container.read(hrSummaryProvider);
      expect(s.presentToday, 4);
      expect(s.absentToday, 0);
    });
  });
}
