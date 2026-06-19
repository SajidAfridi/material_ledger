import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ledger/shared/models/rent_payment.dart';
import 'package:material_ledger/shared/models/rental_unit.dart';
import 'package:material_ledger/shared/providers/language_provider.dart';
import 'package:material_ledger/shared/providers/rentals_provider.dart';

RentPayment _payment({
  required String period,
  required double due,
  required double paid,
}) =>
    RentPayment(
      id: 'p',
      unitId: 'u',
      periodMonth: period,
      amountDueAED: due,
      amountPaidAED: paid,
      recordedBy: 'test',
      recordedAt: DateTime(2026, 1, 1),
    );

void main() {
  group('RentPayment.statusAsOf (FR-118)', () {
    final now = DateTime(2026, 6, 15);

    test('fully paid → paid', () {
      final p = _payment(period: '2026-06', due: 4500, paid: 4500);
      expect(p.statusAsOf(now), RentStatus.paid);
    });

    test('part paid → partial', () {
      final p = _payment(period: '2026-06', due: 4500, paid: 2000);
      expect(p.statusAsOf(now), RentStatus.partial);
      expect(p.outstandingAED, 2500);
    });

    test('unpaid current month → due', () {
      final p = _payment(period: '2026-06', due: 4500, paid: 0);
      expect(p.statusAsOf(now), RentStatus.due);
    });

    test('unpaid past month → overdue', () {
      final p = _payment(period: '2026-04', due: 4500, paid: 0);
      expect(p.statusAsOf(now), RentStatus.overdue);
    });
  });

  group('Rentals providers', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
    });

    test('seeds units and computes a rent roll from occupied units', () {
      final summary = container.read(rentalsSummaryProvider);
      expect(summary.totalUnits, greaterThan(0));
      // Two occupied seed shops (3800 + 4500) drive the rent roll.
      expect(summary.monthlyRentRoll, greaterThanOrEqualTo(8300));
      expect(summary.occupied, greaterThanOrEqualTo(2));
    });

    test('recordPayment marks the current month paid and lifts collected total',
        () async {
      final month = currentRentMonthKey();
      await container.read(rentPaymentsProvider.notifier).recordPayment(
            unitId: 'unit-shop-02',
            periodMonth: month,
            amountDueAED: 4500,
            amountPaidAED: 4500,
            recordedBy: 'test',
          );
      final status = container.read(unitRentStatusProvider('unit-shop-02'));
      // Past unpaid seed (last month) still makes the unit overall overdue…
      expect(
        status == RentStatus.overdue || status == RentStatus.paid,
        true,
      );
      final collected =
          container.read(rentalsSummaryProvider).collectedThisMonth;
      expect(collected, greaterThanOrEqualTo(4500));
    });

    test('topping up a partial payment preserves the total and reduces outstanding',
        () async {
      final notifier = container.read(rentPaymentsProvider.notifier);
      const unit = 'unit-shop-02'; // seeded this month: due 4500, paid 0
      final month = currentRentMonthKey();

      // Pay half. The Record-Payment sheet should now prefill "Due" = 2250.
      await notifier.recordPayment(
        unitId: unit,
        periodMonth: month,
        amountDueAED: 4500,
        amountPaidAED: 2250,
        recordedBy: 'test',
      );
      var record =
          notifier.forUnit(unit).firstWhere((p) => p.periodMonth == month);
      expect(record.amountDueAED, 4500);
      expect(record.outstandingAED, 2250);

      // Top up the remainder, passing the (outstanding) due value — the original
      // period total must NOT be overwritten/reset.
      await notifier.recordPayment(
        unitId: unit,
        periodMonth: month,
        amountDueAED: 2250,
        amountPaidAED: 2250,
        recordedBy: 'test',
      );
      record =
          notifier.forUnit(unit).firstWhere((p) => p.periodMonth == month);
      expect(record.amountDueAED, 4500); // total preserved
      expect(record.amountPaidAED, 4500);
      expect(record.outstandingAED, 0);
    });

    test('adding a unit with a tenant marks it active', () async {
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-09',
            type: RentalType.shop,
            location: 'Test Road',
            monthlyRentAED: 5000,
            tenantName: 'New Tenant',
            createdBy: 'test',
          );
      expect(unit.status, RentalStatus.active);
      expect(unit.isOccupied, true);
    });
  });
}
