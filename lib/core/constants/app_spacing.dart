/// The Architectural Ledger — Spacing Tokens
///
/// "If you think there is enough padding, add 8px more."
abstract final class AppSpacing {
  // ─── Base Unit ─────────────────────────────────────────────
  static const double unit = 4.0;

  // ─── Named Spacing ────────────────────────────────────────
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
  static const double massive = 48.0;
  static const double gigantic = 56.0;
  static const double colossal = 64.0;

  // ─── Semantic Spacing ─────────────────────────────────────
  /// Space between list items (divider-free rule: 12px)
  static const double listItemGap = md;

  /// Bilingual text gap: Urdu sits 4px below English baseline
  static const double bilingualGap = xs;

  /// Content padding inside cards/sheets
  static const double cardPadding = xxl;

  /// Screen-level horizontal padding
  static const double screenHorizontal = lg;
  static const double screenVertical = xxl;

  // ─── Radius ───────────────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusFull = 999.0;

  // ─── Elevation / Blur ─────────────────────────────────────
  /// Ambient shadow blur for Level 3 elevation
  static const double ambientBlur = 24.0;

  /// Backdrop blur for glass effect on floating elements
  static const double backdropBlur = 12.0;

  // ─── Interactive ──────────────────────────────────────────
  /// Minimum tap target height (industrial environments)
  static const double minTapTarget = 48.0;
}
