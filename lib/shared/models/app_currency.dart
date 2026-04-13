/// Supported currencies.
///
/// Default is AED (Dirhams). Can be changed to PKR, INR, or USD.
enum AppCurrency {
  aed(
    code: 'AED',
    name: 'Dirham',
    nativeName: 'درهم',
    symbol: 'AED',
    flag: '🇦🇪',
  ),
  pkr(
    code: 'PKR',
    name: 'Pakistani Rupee',
    nativeName: 'پاکستانی روپیہ',
    symbol: 'PKR',
    flag: '🇵🇰',
  ),
  inr(
    code: 'INR',
    name: 'Indian Rupee',
    nativeName: 'भारतीय रुपया',
    symbol: '₹',
    flag: '🇮🇳',
  ),
  usd(
    code: 'USD',
    name: 'US Dollar',
    nativeName: 'US Dollar',
    symbol: '\$',
    flag: '🇺🇸',
  );

  const AppCurrency({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.symbol,
    required this.flag,
  });

  final String code;
  final String name;
  final String nativeName;
  final String symbol;
  final String flag;

  /// Format an amount with this currency's symbol.
  String format(double amount) {
    final formatted = amount.toStringAsFixed(2);
    return '$symbol $formatted';
  }

  /// Resolve from stored code string.
  static AppCurrency fromCode(String code) {
    return AppCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCurrency.aed,
    );
  }
}
