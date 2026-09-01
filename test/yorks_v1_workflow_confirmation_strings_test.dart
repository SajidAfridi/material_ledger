import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics_strings.dart';

void main() {
  test('arrangement confirmation reports every decision bucket', () {
    final copy = YorksV1ArrangementStrings.arrangementSavedSummary(
      full: 3,
      partial: 2,
      unavailable: 1,
    );

    expect(copy.en, startsWith('3 full · 2 partial · 1 unavailable.'));
    expect(copy.ar, contains('3'));
    expect(copy.ur, contains('2'));
    expect(copy.hi, contains('1'));
  });

  test(
    'dispatch confirmation is singular and identifies the server record',
    () {
      final copy = YorksV1LogisticsStrings.dispatchConfirmedSummary(
        number: 'YRA-322-DSP004',
        lines: 1,
      );

      expect(
        copy.en,
        'YRA-322-DSP004 · 1 line committed · Receipt review is next.',
      );
      expect(copy.ar, contains('YRA-322-DSP004'));
    },
  );

  test('receipt confirmation separates confirmed lines from exceptions', () {
    final copy = YorksV1LogisticsStrings.receiptConfirmedSummary(
      lines: 4,
      exceptionLines: 2,
    );

    expect(copy.en, '4 lines confirmed · 2 exceptions recorded.');
    expect(copy.ar, contains('4'));
    expect(copy.ur, contains('2'));
    expect(copy.hi, contains('2'));
  });
}
