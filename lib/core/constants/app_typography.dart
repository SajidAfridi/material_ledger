import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Yorks Nexus V7 type scale.
///
/// The bundled Noto Sans family is deliberately neutral, browser-dense and
/// deterministic offline. Arabic keeps its dedicated family and line height.
abstract final class AppTypography {
  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    required double height,
    double letterSpacing = 0,
    Color color = AppColors.onSurface,
  }) => TextStyle(
    fontFamily: 'NexusSans',
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );

  static TextStyle get displayLarge => _inter(
    size: 40,
    weight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -1.2,
  );

  static TextStyle get displayMedium => _inter(
    size: 36,
    weight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -1,
  );

  static TextStyle get displaySmall => _inter(
    size: 32,
    weight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -1.12,
  );

  static TextStyle get headlineLarge => displaySmall;

  static TextStyle get headlineMedium => _inter(
    size: 24,
    weight: FontWeight.w700,
    height: 1.18,
    letterSpacing: -0.48,
  );

  static TextStyle get headlineSmall => _inter(
    size: 21,
    weight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.42,
  );

  static TextStyle get titleLarge => headlineSmall;

  static TextStyle get titleMedium => _inter(
    size: 16,
    weight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.1,
  );

  static TextStyle get titleSmall =>
      _inter(size: 14, weight: FontWeight.w700, height: 1.35);

  static TextStyle get bodyLarge =>
      _inter(size: 16, weight: FontWeight.w400, height: 1.5);

  static TextStyle get bodyMedium => _inter(
    size: 13,
    weight: FontWeight.w400,
    height: 1.5,
    color: AppColors.inkSecondary,
  );

  static TextStyle get bodySmall => _inter(
    size: 12,
    weight: FontWeight.w400,
    height: 1.45,
    color: AppColors.muted,
  );

  static TextStyle get labelLarge =>
      _inter(size: 12, weight: FontWeight.w700, height: 1.3);

  static TextStyle get labelMedium => _inter(
    size: 10.5,
    weight: FontWeight.w700,
    height: 1.3,
    color: AppColors.muted,
  );

  static TextStyle get labelSmall => _inter(
    size: 10,
    weight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0.2,
    color: AppColors.muted,
  );

  static TextStyle get eyebrow => _inter(
    size: 10,
    weight: FontWeight.w800,
    height: 1.2,
    letterSpacing: 1,
    color: AppColors.blue,
  );

  static TextStyle urduStyle({required double englishFontSize}) => TextStyle(
    fontFamily: 'NotoSansArabic',
    fontSize: englishFontSize - 2,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.onSurfaceVariant,
  );

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
