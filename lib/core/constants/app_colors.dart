import 'package:flutter/material.dart';

/// Yorks Nexus V7 colour tokens.
///
/// These values mirror the approved V7 client design. The Material aliases
/// remain intentionally stable so existing screens can migrate incrementally.
abstract final class AppColors {
  // ─── Brand and action colours ─────────────────────────────
  static const Color navy = Color(0xFF0D2F57);
  static const Color navyHover = Color(0xFF123F73);
  static const Color blue = Color(0xFF1D68D9);
  static const Color blueContainer = Color(0xFFEAF2FF);
  static const Color blueContainerStrong = Color(0xFFC9DCFF);

  static const Color primary = blue;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = blueContainer;
  static const Color onPrimaryContainer = navy;
  static const Color primaryFixed = blueContainer;
  static const Color onPrimaryFixed = navy;
  static const Color onPrimaryFixedVariant = Color(0xFF1252B1);

  static const Color secondary = Color(0xFF34435A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFF0F4F8);
  static const Color onSecondaryContainer = Color(0xFF132033);

  static const Color tertiary = Color(0xFF6D4BD1);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFF2EDFF);
  static const Color onTertiaryContainer = Color(0xFF5A3BB5);

  // ─── Text ─────────────────────────────────────────────────
  static const Color ink = Color(0xFF132033);
  static const Color inkSecondary = Color(0xFF34435A);
  static const Color muted = Color(0xFF6B788C);
  static const Color mutedLight = Color(0xFF8F9AAE);

  // ─── Surfaces ─────────────────────────────────────────────
  /// Application canvas behind the workspace.
  static const Color surface = Color(0xFFEEF3F8);

  /// Slightly lighter canvas used by the focused R38 mobile workspace.
  static const Color mobileSurface = Color(0xFFF3F6FA);

  /// Persistent sidebar and top-bar surface from the rendered R38 shell.
  static const Color workspaceChrome = Color(0xFFF9FBFD);

  /// White records, panels and cards.
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F8FC);
  static const Color surfaceContainer = Color(0xFFF0F4F8);
  static const Color surfaceContainerHigh = Color(0xFFEDF1F5);
  static const Color surfaceContainerHighest = Color(0xFFE4EAF1);

  static const Color onSurface = ink;
  static const Color onSurfaceVariant = muted;
  static const Color inverseSurface = navy;
  static const Color onInverseSurface = Color(0xFFFFFFFF);

  // ─── Lines ────────────────────────────────────────────────
  static const Color line = Color(0xFFDFE6EE);
  static const Color lineStrong = Color(0xFFC8D2DF);
  static const Color outline = lineStrong;
  static const Color outlineVariant = line;

  // ─── Semantic states ──────────────────────────────────────
  static const Color success = Color(0xFF0D8B63);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFE9F8F2);
  static const Color onSuccessContainer = Color(0xFF087452);

  static const Color warning = Color(0xFFAD6A00);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFFF5DF);
  static const Color onWarningContainer = Color(0xFF8C5700);

  static const Color error = Color(0xFFC23737);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFF0F0);
  static const Color onErrorContainer = Color(0xFFA72E2E);

  static const Color purple = Color(0xFF6D4BD1);
  static const Color purpleContainer = Color(0xFFF2EDFF);
  static const Color neutralContainer = Color(0xFFF1F4F7);
  static const Color neutralText = Color(0xFF536175);

  // ─── Effects ──────────────────────────────────────────────
  static const Color scrim = Color(0xFF000000);
  static const Color shadow = Color(0x0F19304E);

  /// Compatibility alias used by existing outlined controls.
  static Color get ghostBorder => line;

  static Color get glassPrimaryContainer =>
      surfaceContainerLowest.withValues(alpha: 0.96);

  /// Compatibility alias for legacy callers. V7 primary actions are solid.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [navy, navy],
  );
}
