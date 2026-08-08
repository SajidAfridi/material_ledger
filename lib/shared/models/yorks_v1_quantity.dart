/// Formats a decimal quantity for presentation without changing its value.
///
/// PostgreSQL `numeric` projections may include scale padding (for example
/// `1.0000`). Yorks keeps quantities as decimal text on the client, so this
/// formatter removes only insignificant trailing zeroes and never converts
/// through a binary floating-point type.
String yorksV1DisplayQuantity(String raw) {
  final value = raw.trim();
  if (!RegExp(r'^[+-]?\d+(?:\.\d+)?$').hasMatch(value)) return raw;

  final decimalPoint = value.indexOf('.');
  if (decimalPoint < 0) return value;

  var end = value.length;
  while (end > decimalPoint + 1 && value.codeUnitAt(end - 1) == 0x30) {
    end--;
  }
  if (end == decimalPoint + 1) end = decimalPoint;
  return value.substring(0, end);
}
