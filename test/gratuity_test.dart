import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/gratuity.dart';

void main() {
  group('calculateGratuity (UAE Art. 51)', () {
    test('under 1 year of service → not entitled', () {
      final est = calculateGratuity(
        joinDate: DateTime(2026, 1, 1),
        asOf: DateTime(2026, 6, 1),
        basicWageAED: 5000,
      );
      expect(est.entitled, false);
      expect(est.amountAED, 0);
    });

    test('1-5 years → 21 days/year, scaled by actual elapsed time', () {
      final joinDate = DateTime(2023, 1, 1);
      final asOf = DateTime(2026, 1, 1); // ~3 calendar years
      final est = calculateGratuity(
        joinDate: joinDate,
        asOf: asOf,
        basicWageAED: 6000,
      );
      expect(est.entitled, true);
      // Recompute expected via the same day-count/365.25 basis the
      // implementation uses — real calendar spans aren't exact multiples of
      // 365.25 days (leap years), so this avoids a false idealized assumption.
      final years = asOf.difference(joinDate).inDays / 365.25;
      final dailyWage = 6000 / 30;
      expect(est.yearsOfService, closeTo(years, 0.001));
      expect(est.amountAED, closeTo(years * 21 * dailyWage, 0.01));
    });

    test('beyond 5 years → 21 days/yr for first 5, 30 days/yr after', () {
      final joinDate = DateTime(2018, 1, 1);
      final asOf = DateTime(2026, 1, 1); // ~8 years
      final est = calculateGratuity(
        joinDate: joinDate,
        asOf: asOf,
        basicWageAED: 6000,
      );
      final years = asOf.difference(joinDate).inDays / 365.25;
      final dailyWage = 6000 / 30;
      final expected = 5 * 21 * dailyWage + (years - 5) * 30 * dailyWage;
      expect(est.amountAED, closeTo(expected, 0.01));
    });

    test('capped at 2 years total wage no matter how long the service', () {
      final est = calculateGratuity(
        joinDate: DateTime(1990, 1, 1),
        asOf: DateTime(2026, 1, 1), // 36 years
        basicWageAED: 5000,
      );
      expect(est.amountAED, 5000 * 24); // capped
    });

    test('zero/negative basic wage → not entitled (nothing to compute on)', () {
      final est = calculateGratuity(
        joinDate: DateTime(2020, 1, 1),
        asOf: DateTime(2026, 1, 1),
        basicWageAED: 0,
      );
      expect(est.entitled, false);
      expect(est.amountAED, 0);
    });
  });
}
