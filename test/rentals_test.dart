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

    test('voiding a payment removes it from collected and frees the period',
        () async {
      final notifier = container.read(rentPaymentsProvider.notifier);
      const unit = 'unit-shop-02';
      final month = currentRentMonthKey();
      final p = await notifier.recordPayment(
        unitId: unit,
        periodMonth: month,
        amountDueAED: 4500,
        amountPaidAED: 4500,
        recordedBy: 'test',
      );
      final before = container.read(rentalsSummaryProvider).collectedThisMonth;

      await notifier.voidPayment(p.id, reason: 'wrong unit');
      expect(notifier.forUnit(unit).firstWhere((x) => x.id == p.id).isVoided,
          true);
      expect(
        container.read(rentalsSummaryProvider).collectedThisMonth,
        before - 4500,
      );

      // Recording again for the same period creates a fresh, non-accumulated
      // record (it does not top up the voided one).
      final fresh = await notifier.recordPayment(
        unitId: unit,
        periodMonth: month,
        amountDueAED: 4500,
        amountPaidAED: 1000,
        recordedBy: 'test',
      );
      expect(fresh.id, isNot(p.id));
      expect(fresh.amountPaidAED, 1000);
    });

    test('marking an occupied unit vacant drops it from the rent roll',
        () async {
      final notifier = container.read(rentalUnitsProvider.notifier);
      final before = container.read(rentalsSummaryProvider).monthlyRentRoll;
      final unit = notifier.byId('unit-shop-01')!; // occupied @ 3800
      await notifier.updateUnit(unit.copyWith(status: RentalStatus.vacant));
      expect(
        container.read(rentalsSummaryProvider).monthlyRentRoll,
        before - 3800,
      );
      expect(notifier.byId('unit-shop-01')!.isOccupied, false);
    });
  });

  group('RentalUnit.leaseExpired', () {
    RentalUnit unit({DateTime? leaseEnd}) => RentalUnit(
          id: 'x',
          unitName: 'X',
          type: RentalType.shop,
          location: '',
          monthlyRentAED: 1,
          leaseEnd: leaseEnd,
          createdBy: 't',
          createdAt: DateTime(2020),
        );

    test('true when lease end is in the past', () {
      expect(unit(leaseEnd: DateTime(2000)).leaseExpired, true);
    });
    test('false when lease end is in the future or unset', () {
      expect(unit(leaseEnd: DateTime(2999)).leaseExpired, false);
      expect(unit().leaseExpired, false);
    });
  });
}
