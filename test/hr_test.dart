import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/attendance_record.dart';
import 'package:material_ledger/shared/models/gratuity.dart';
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

  group('Gratuity estimate provider (UAE Art. 51)', () {
    test('emp-001 (>3yr service, 6500 salary, no separate basic wage) is entitled',
        () {
      final est = container.read(gratuityEstimateProvider('emp-001'));
      expect(est, isNotNull);
      expect(est!.entitled, true);
      // Cross-check against the pure calculator directly (mirrors the seed's
      // joinDate formula) — this verifies the PROVIDER's wiring (employee
      // lookup + salaryAED fallback when basicWageAED is unset), while the
      // exact math itself is covered by gratuity_test.dart.
      final expected = calculateGratuity(
        joinDate: DateTime(DateTime.now().year - 3, 2, 1),
        asOf: DateTime.now(),
        basicWageAED: 6500,
      );
      expect(est.amountAED, closeTo(expected.amountAED, 0.01));
    });

    test('an unknown employee id has no estimate', () {
      expect(container.read(gratuityEstimateProvider('nope')), isNull);
    });

    test('company-wide liability sums every active employee\'s estimate', () {
      final total = container.read(totalGratuityLiabilityProvider);
      final sumOfIndividuals = ['emp-001', 'emp-002', 'emp-003', 'emp-004', 'emp-005']
          .map((id) => container.read(gratuityEstimateProvider(id)))
          .where((e) => e != null && e.entitled)
          .fold(0.0, (s, e) => s + e!.amountAED);
      expect(total, closeTo(sumOfIndividuals, 1));
      expect(total, greaterThan(0));
    });
  });

  group('Sick-leave tier provider (UAE Art. 31)', () {
    test('a fresh sick request for emp-002 is all full-pay under 15 days', () {
      final split = container.read(sickLeaveTierProvider(('emp-002', 5)));
      expect(split.fullPayDays, 5);
      expect(split.halfPayDays, 0);
    });

    test('prior approved sick days push a new request into the half-pay tier',
        () async {
      // emp-004 has no seeded sick leave; approve 15 full-pay days first.
      await container.read(leaveRecordsProvider.notifier).addLeave(
            employeeId: 'emp-004',
            type: LeaveType.sick,
            startDate: DateTime(DateTime.now().year, 2, 1),
            endDate: DateTime(DateTime.now().year, 2, 15), // 15 days
            status: LeaveRecordStatus.approved,
          );
      final split = container.read(sickLeaveTierProvider(('emp-004', 5)));
      expect(split.fullPayDays, 0);
      expect(split.halfPayDays, 5);
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
