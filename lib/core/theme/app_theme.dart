import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// The Architectural Ledger — App Theme
///
/// Constructs the full [ThemeData] from design tokens.
/// Uses MD3 tonal system with custom color scheme.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = _colorScheme;
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surface,

      // ─── AppBar ──────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge,
      ),

      // ─── Card — No borders, tonal layering ──────────────
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── Elevated Button (Primary CTA) ──────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.onPrimary,
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppSpacing.minTapTarget),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: AppTypography.labelLarge.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),

      // ─── Outlined Button (Secondary — Ghost Border) ─────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, AppSpacing.minTapTarget),
          shape: const StadiumBorder(),
          side: BorderSide(color: AppColors.ghostBorder),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ─── Text Button ────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          shape: const StadiumBorder(),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      // ─── Floating Action Button (Glass & Gradient) ──────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),

      // ─── Input Fields (Flat, bottom-only primary stroke) ─
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: const UnderlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSm),
          ),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSm),
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSm),
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.error, width: 2),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusSm),
          ),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),

      // ─── Bottom Navigation ──────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primaryFixed,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return AppTypography.labelMedium;
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.primary, size: 24);
          }
          return IconThemeData(color: AppColors.onSurfaceVariant, size: 24);
        }),
        elevation: 0,
        height: 72,
      ),

      // ─── Chip (Status chips — 10% fill, 100% text) ─────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        labelStyle: AppTypography.labelMedium,
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      // ─── Divider — PROHIBITED but needed for system ────
      dividerTheme: const DividerThemeData(
        thickness: 0,
        space: AppSpacing.listItemGap,
        color: Colors.transparent,
      ),

      // ─── SnackBar (floating so it never lifts the docked FAB) ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onInverseSurface,
        ),
        actionTextColor: AppColors.primaryFixed,
        elevation: 3,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),

      // ─── Dialog ────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
      ),

      // ─── Bottom Sheet ──────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        showDragHandle: false,
        dragHandleColor: AppColors.outlineVariant,
      ),
    );
  }

  // ─── Color Scheme ───────────────────────────────────────────
  static ColorScheme get _colorScheme => const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.onPrimaryContainer,
    primaryFixed: AppColors.primaryFixed,
    onPrimaryFixed: AppColors.onPrimaryFixed,
    onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: AppColors.onTertiaryContainer,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.onInverseSurface,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    scrim: AppColors.scrim,
    shadow: AppColors.shadow,
  );
}
