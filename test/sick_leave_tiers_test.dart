import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/sick_leave_tiers.dart';

void main() {
  group('splitSickLeaveTiers (UAE Art. 31)', () {
    test('a fresh request under 15 days is all full pay', () {
      final s = splitSickLeaveTiers(alreadyUsedDays: 0, requestedDays: 10);
      expect(s.fullPayDays, 10);
      expect(s.halfPayDays, 0);
      expect(s.unpaidDays, 0);
      expect(s.exceedsAnnualCap, false);
    });

    test('a request spanning the full→half boundary splits correctly', () {
      // 0 used; asking for 20 days → 15 full + 5 half.
      final s = splitSickLeaveTiers(alreadyUsedDays: 0, requestedDays: 20);
      expect(s.fullPayDays, 15);
      expect(s.halfPayDays, 5);
      expect(s.unpaidDays, 0);
    });

    test('a request spanning all three tiers splits correctly', () {
      // 0 used; asking for 50 days → 15 full + 30 half + 5 unpaid.
      final s = splitSickLeaveTiers(alreadyUsedDays: 0, requestedDays: 50);
      expect(s.fullPayDays, 15);
      expect(s.halfPayDays, 30);
      expect(s.unpaidDays, 5);
    });

    test('already used 15 days → a new request starts in the half-pay tier', () {
      final s = splitSickLeaveTiers(alreadyUsedDays: 15, requestedDays: 10);
      expect(s.fullPayDays, 0);
      expect(s.halfPayDays, 10);
      expect(s.unpaidDays, 0);
    });

    test('already used 89 days → 1 more day is unpaid, cap flagged', () {
      final s = splitSickLeaveTiers(alreadyUsedDays: 89, requestedDays: 5);
      expect(s.unpaidDays, 5); // all 5 land past the 90-day cap
      expect(s.exceedsAnnualCap, true);
      expect(s.totalDays, 5);
    });

    test('already at the 90-day cap → everything new is unpaid overflow', () {
      final s = splitSickLeaveTiers(alreadyUsedDays: 90, requestedDays: 3);
      expect(s.fullPayDays, 0);
      expect(s.halfPayDays, 0);
      expect(s.unpaidDays, 3);
      expect(s.exceedsAnnualCap, true);
    });

    test('zero requested days is a no-op', () {
      final s = splitSickLeaveTiers(alreadyUsedDays: 0, requestedDays: 0);
      expect(s.totalDays, 0);
      expect(s.exceedsAnnualCap, false);
    });
  });
}
