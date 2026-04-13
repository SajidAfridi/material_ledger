import 'package:flutter/material.dart';

/// The Architectural Ledger — Color Tokens
///
/// Derived from the design spec: deep authoritative blue primary,
/// MD3 tonal system for hierarchy through color, not chrome.
///
/// **The "No-Line" Rule**: 1px solid borders are PROHIBITED.
/// Boundaries defined solely through background color shifts.
abstract final class AppColors {
  // ─── Primary ───────────────────────────────────────────────
  static const Color primary = Color(0xFF003FB1);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1A56DB);
  static const Color onPrimaryContainer = Color(0xFFD6E2FF);
  static const Color primaryFixed = Color(0xFFD6E2FF);
  static const Color onPrimaryFixed = Color(0xFF001A40);
  static const Color onPrimaryFixedVariant = Color(0xFF0040A0);

  // ─── Secondary ─────────────────────────────────────────────
  static const Color secondary = Color(0xFF565E71);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFDAE2F9);
  static const Color onSecondaryContainer = Color(0xFF131B2C);

  // ─── Tertiary ──────────────────────────────────────────────
  static const Color tertiary = Color(0xFF705574);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFAD8FD);
  static const Color onTertiaryContainer = Color(0xFF29132E);

  // ─── Error ─────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  // ─── Surface Hierarchy (Tonal Layering) ────────────────────
  /// Layer 0 — Base canvas for the entire application
  static const Color surface = Color(0xFFF7F9FB);

  /// Layer 1 — The Worksurface (sidebars, secondary zones)
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E2E4);

  /// Layer 2 — The Sheet (primary content cards)
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);

  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF434654);
  static const Color inverseSurface = Color(0xFF2E3133);
  static const Color onInverseSurface = Color(0xFFF0F0F3);

  // ─── Outline ───────────────────────────────────────────────
  /// Use at 15% opacity for "Ghost Borders"
  static const Color outline = Color(0xFF74777F);
  static const Color outlineVariant = Color(0xFFC4C6D0);

  // ─── Status Colors (10% opacity fill + 100% text) ─────────
  static const Color success = Color(0xFF1B6D2F);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFA4F4A8);
  static const Color onSuccessContainer = Color(0xFF002107);

  static const Color warning = Color(0xFF7D5700);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFFDEA6);
  static const Color onWarningContainer = Color(0xFF271900);

  // ─── Scrim & Shadow ────────────────────────────────────────
  static const Color scrim = Color(0xFF000000);

  /// Ambient shadow: tinted with primary at 4% opacity, 24px blur
  static const Color shadow = Color(0x0A003FB1);

  // ─── Helpers ───────────────────────────────────────────────

  /// Ghost border color — outlineVariant at 15% opacity
  static Color get ghostBorder => outlineVariant.withValues(alpha: 0.15);

  /// Glass effect for floating mobile elements
  static Color get glassPrimaryContainer =>
      primaryContainer.withValues(alpha: 0.9);

  /// Primary CTA gradient (135° angle)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, onPrimaryFixedVariant],
  );
}
