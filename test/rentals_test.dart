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

    test('partly paid PAST month → overdue (a late balance is still overdue)',
        () {
      final p = _payment(period: '2026-04', due: 4500, paid: 2000);
      expect(p.statusAsOf(now), RentStatus.overdue);
      expect(p.outstandingAED, 2500);
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

    test('no rental units are pre-seeded — a clean slate for real use', () {
      final summary = container.read(rentalsSummaryProvider);
      expect(summary.totalUnits, 0);
      expect(summary.monthlyRentRoll, 0);
      expect(summary.occupied, 0);
    });

    test('adding occupied units contributes to the rent roll', () async {
      final notifier = container.read(rentalUnitsProvider.notifier);
      await notifier.addUnit(
        unitName: 'SHOP-A',
        type: RentalType.shop,
        location: 'Test',
        monthlyRentAED: 3800,
        tenantName: 'Tenant A',
        createdBy: 'test',
      );
      await notifier.addUnit(
        unitName: 'SHOP-B',
        type: RentalType.shop,
        location: 'Test',
        monthlyRentAED: 4500,
        tenantName: 'Tenant B',
        createdBy: 'test',
      );
      final summary = container.read(rentalsSummaryProvider);
      expect(summary.totalUnits, 2);
      expect(summary.occupied, 2);
      expect(summary.monthlyRentRoll, 8300);
    });

    test('recordPayment marks the current month paid', () async {
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-TEST',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 4500,
            tenantName: 'Tenant',
            createdBy: 'test',
          );
      final month = currentRentMonthKey();
      await container.read(rentPaymentsProvider.notifier).recordPayment(
            unitId: unit.id,
            periodMonth: month,
            amountDueAED: 4500,
            amountPaidAED: 4500,
            recordedBy: 'test',
          );
      expect(container.read(unitRentStatusProvider(unit.id)), RentStatus.paid);
      final collected =
          container.read(rentalsSummaryProvider).collectedThisMonth;
      expect(collected, greaterThanOrEqualTo(4500));
    });

    test('topping up a partial payment preserves the total and reduces outstanding',
        () async {
      final notifier = container.read(rentPaymentsProvider.notifier);
      // A bare unit id string is enough here — this test exercises the
      // payment-ledger accumulate/cap logic in isolation, independent of
      // whether a RentalUnit with this id actually exists.
      const unit = 'unit-topup-test';
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
      // A bare unit id is enough — voiding only touches the payment ledger.
      const unit = 'unit-void-test';
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

    test('recordPayment caps a fresh overpayment at the amount due', () async {
      final notifier = container.read(rentPaymentsProvider.notifier);
      final month = currentRentMonthKey();
      final p = await notifier.recordPayment(
        unitId: 'unit-overpay-test',
        periodMonth: month,
        amountDueAED: 9000,
        amountPaidAED: 12000, // fat-finger overpay
        recordedBy: 'test',
      );
      expect(p.amountPaidAED, 9000); // capped, not 12000
      expect(p.outstandingAED, 0);
    });

    test('recordPayment caps a top-up so the period is never over-collected',
        () async {
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-CAP',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 4500,
            tenantName: 'Tenant',
            createdBy: 'test',
          );
      final notifier = container.read(rentPaymentsProvider.notifier);
      final month = currentRentMonthKey();
      await notifier.recordPayment(
        unitId: unit.id,
        periodMonth: month,
        amountDueAED: 4500,
        amountPaidAED: 3000,
        recordedBy: 'test',
      );
      // Another 3000 would total 6000 → capped at the 4500 due.
      final r = await notifier.recordPayment(
        unitId: unit.id,
        periodMonth: month,
        amountDueAED: 4500,
        amountPaidAED: 3000,
        recordedBy: 'test',
      );
      expect(r.amountPaidAED, 4500);
      expect(r.outstandingAED, 0);
      // Collected this month never exceeds the rent roll.
      final summary = container.read(rentalsSummaryProvider);
      expect(summary.collectedThisMonth, lessThanOrEqualTo(summary.monthlyRentRoll));
    });

    test('overdue derives from occupancy — an unbilled past month counts',
        () async {
      final now = DateTime.now();
      // Lease started 2 months ago; no payment records entered at all, so LAST
      // month is fully unpaid → 4500 overdue with no record ever entered for it.
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-OD',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 4500,
            tenantName: 'Tenant',
            leaseStart: DateTime(now.year, now.month - 2, 1),
            createdBy: 'test',
          );
      expect(
        container.read(rentalsSummaryProvider).overdueTotal,
        greaterThanOrEqualTo(4500),
      );

      // A partial payment against that past month reduces the arrears.
      final notifier = container.read(rentPaymentsProvider.notifier);
      final last = DateTime(now.year, now.month - 1, 1);
      final lastKey = '${last.year}-${last.month.toString().padLeft(2, '0')}';
      final before = container.read(rentalsSummaryProvider).overdueTotal;
      await notifier.recordPayment(
        unitId: unit.id,
        periodMonth: lastKey,
        amountDueAED: 4500,
        amountPaidAED: 1000,
        recordedBy: 'test',
      );
      final after = container.read(rentalsSummaryProvider).overdueTotal;
      expect(after, before - 1000); // 1000 collected → 1000 less overdue
    });

    test('rent KPIs reconcile: collected + currentDue == rent roll', () async {
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-KPI',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 4500,
            tenantName: 'Tenant',
            createdBy: 'test',
          );
      await container.read(rentPaymentsProvider.notifier).recordPayment(
            unitId: unit.id,
            periodMonth: currentRentMonthKey(),
            amountDueAED: 4500,
            amountPaidAED: 2000,
            recordedBy: 'test',
          );
      final s = container.read(rentalsSummaryProvider);
      // Every occupied unit's current-month rent is either collected or still
      // due — nothing falls through the cracks.
      expect(
        s.collectedThisMonth + s.currentMonthDue,
        closeTo(s.monthlyRentRoll, 0.01),
      );
    });

    test('VAT breakdown derives net+VAT from the VAT-inclusive rent (default 5%)',
        () async {
      final unit = await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-VAT',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 3800,
            tenantName: 'Tenant',
            createdBy: 'test',
          );
      expect(unit.vatRatePercent, 5.0);
      // 3800 gross → net = 3800 / 1.05.
      expect(unit.netRentAED, closeTo(3800 / 1.05, 0.01));
      expect(unit.vatAmountAED, closeTo(3800 - 3800 / 1.05, 0.01));
      // Net + VAT reconstructs the original gross exactly.
      expect(unit.netRentAED + unit.vatAmountAED, closeTo(3800, 0.001));
    });

    test('adding a unit with a security deposit tracks it as a liability',
        () async {
      final before = container.read(totalSecurityDepositsHeldProvider);
      await container.read(rentalUnitsProvider.notifier).addUnit(
            unitName: 'SHOP-DEP',
            type: RentalType.shop,
            location: 'Test',
            monthlyRentAED: 5000,
            securityDepositAED: 10000,
            createdBy: 'test',
          );
      expect(container.read(totalSecurityDepositsHeldProvider), before + 10000);
    });

    test('marking an occupied unit vacant drops it from the rent roll',
        () async {
      final notifier = container.read(rentalUnitsProvider.notifier);
      final unit = await notifier.addUnit(
        unitName: 'SHOP-VACATE',
        type: RentalType.shop,
        location: 'Test',
        monthlyRentAED: 3800,
        tenantName: 'Tenant',
        createdBy: 'test',
      );
      final before = container.read(rentalsSummaryProvider).monthlyRentRoll;
      await notifier.updateUnit(unit.copyWith(status: RentalStatus.vacant));
      expect(
        container.read(rentalsSummaryProvider).monthlyRentRoll,
        before - 3800,
      );
      expect(notifier.byId(unit.id)!.isOccupied, false);
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
