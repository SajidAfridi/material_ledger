import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The Architectural Ledger — Typography Tokens
///
/// Uses Inter for its neutral, high-legibility "Swiss" aesthetic.
/// Typography is the primary driver of the brand's authoritative voice.
abstract final class AppTypography {
  // ─── Editorial Scale ──────────────────────────────────────

  /// Display Large (56px) — Hero metrics (Total Stock Value)
  /// High-contrast, tight tracking (-2%)
  static TextStyle get displayLarge => GoogleFonts.inter(
    fontSize: 56,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.12, // -2%
    height: 1.1,
    color: AppColors.onSurface,
  );

  /// Display Medium (45px)
  static TextStyle get displayMedium => GoogleFonts.inter(
    fontSize: 45,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    height: 1.15,
    color: AppColors.onSurface,
  );

  /// Display Small (36px)
  static TextStyle get displaySmall => GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.72,
    height: 1.2,
    color: AppColors.onSurface,
  );

  /// Headline Large (32px)
  static TextStyle get headlineLarge => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.32,
    height: 1.25,
    color: AppColors.onSurface,
  );

  /// Headline Medium (28px) — Section titles
  static TextStyle get headlineMedium => GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.28,
    height: 1.3,
    color: AppColors.onSurface,
  );

  /// Headline Small (24px)
  static TextStyle get headlineSmall => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.24,
    height: 1.3,
    color: AppColors.onSurface,
  );

  /// Title Large (22px)
  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
    color: AppColors.onSurface,
  );

  /// Title Medium (16px)
  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
    color: AppColors.onSurface,
  );

  /// Title Small (14px) — English primary labels
  static TextStyle get titleSmall => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.onSurface,
  );

  /// Body Large (16px)
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
    color: AppColors.onSurface,
  );

  /// Body Medium (14px) — English body text
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
    color: AppColors.onSurface,
  );

  /// Body Small (12px)
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
    color: AppColors.onSurfaceVariant,
  );

  /// Label Large (14px)
  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
    color: AppColors.onSurface,
  );

  /// Label Medium (12px) — Metadata & Urdu translation layer
  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
    color: AppColors.onSurfaceVariant,
  );

  /// Label Small (11px)
  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
    color: AppColors.onSurfaceVariant,
  );

  // ─── Bilingual Helpers ────────────────────────────────────

  /// Urdu text style — 2pt smaller than the paired English style,
  /// using onSurfaceVariant, with increased line-height (1.5)
  /// to accommodate descending calligraphic strokes.
  static TextStyle urduStyle({required double englishFontSize}) => TextStyle(
    fontFamily: 'NotoNastaliqUrdu',
    fontSize: englishFontSize - 2,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onSurfaceVariant,
  );

  // ─── Text Theme ───────────────────────────────────────────
  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
