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

/// Exact client-side companion to PostgreSQL `numeric(18,4)` quantities.
///
/// This type is for validation and presentation only; PostgreSQL remains the
/// workflow authority. Keeping a scaled integer here prevents binary `double`
/// rounding from rejecting or accepting a boundary value differently from the
/// server.
final class YorksV1DecimalQuantity
    implements Comparable<YorksV1DecimalQuantity> {
  const YorksV1DecimalQuantity._(this._scaledValue);

  static const int scale = 4;
  static final BigInt _factor = BigInt.from(10000);
  static final RegExp _pattern = RegExp(r'^([+-]?)(\d{1,14})(?:\.(\d{1,4}))?$');

  final BigInt _scaledValue;

  static YorksV1DecimalQuantity? tryParse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    final whole = BigInt.tryParse(match.group(2)!);
    if (whole == null) return null;
    final fractionText = (match.group(3) ?? '').padRight(scale, '0');
    final fraction = BigInt.tryParse(fractionText) ?? BigInt.zero;
    final unsigned = whole * _factor + fraction;
    return YorksV1DecimalQuantity._(
      match.group(1) == '-' ? -unsigned : unsigned,
    );
  }

  static final zero = YorksV1DecimalQuantity._(BigInt.zero);

  bool get isZero => _scaledValue == BigInt.zero;
  bool get isPositive => _scaledValue > BigInt.zero;
  bool get isNegative => _scaledValue < BigInt.zero;

  YorksV1DecimalQuantity operator +(YorksV1DecimalQuantity other) =>
      YorksV1DecimalQuantity._(_scaledValue + other._scaledValue);

  YorksV1DecimalQuantity operator -(YorksV1DecimalQuantity other) =>
      YorksV1DecimalQuantity._(_scaledValue - other._scaledValue);

  YorksV1DecimalQuantity max(YorksV1DecimalQuantity other) =>
      compareTo(other) >= 0 ? this : other;

  YorksV1DecimalQuantity min(YorksV1DecimalQuantity other) =>
      compareTo(other) <= 0 ? this : other;

  @override
  int compareTo(YorksV1DecimalQuantity other) =>
      _scaledValue.compareTo(other._scaledValue);

  String get canonicalText {
    final negative = _scaledValue.isNegative;
    final absolute = _scaledValue.abs();
    final whole = absolute ~/ _factor;
    final fraction = (absolute % _factor).toString().padLeft(scale, '0');
    final value = yorksV1DisplayQuantity('$whole.$fraction');
    return negative && value != '0' ? '-$value' : value;
  }

  @override
  String toString() => canonicalText;

  @override
  bool operator ==(Object other) =>
      other is YorksV1DecimalQuantity && other._scaledValue == _scaledValue;

  @override
  int get hashCode => _scaledValue.hashCode;
}
