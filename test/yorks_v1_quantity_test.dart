import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_quantity.dart';

void main() {
  test('quantity presentation removes only insignificant decimal zeroes', () {
    expect(yorksV1DisplayQuantity('1.0000'), '1');
    expect(yorksV1DisplayQuantity('12.3400'), '12.34');
    expect(yorksV1DisplayQuantity('0.1250'), '0.125');
    expect(yorksV1DisplayQuantity('7'), '7');
  });

  test('quantity presentation preserves non-numeric input and precision', () {
    expect(
      yorksV1DisplayQuantity(' 1.23000000000000000001 '),
      '1.23000000000000000001',
    );
    expect(yorksV1DisplayQuantity('pending'), 'pending');
  });
}
