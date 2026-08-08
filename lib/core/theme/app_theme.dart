import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Constructs the shared Yorks V1 light theme from design tokens.
abstract final class AppTheme {
  static ThemeData get light {
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.surface,
      focusColor: AppColors.blue.withValues(alpha: 0.10),
      hoverColor: AppColors.surfaceContainer,
      splashColor: AppColors.blue.withValues(alpha: 0.08),
      // Yorks V1 is an operational workspace: route changes and state
      // updates should be immediate, not theatrical.  Keeping this at the
      // theme boundary also covers Material routes that are not owned by the
      // Yorks workspace shell.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _YorksNoPageTransitionBuilder(),
          TargetPlatform.iOS: _YorksNoPageTransitionBuilder(),
          TargetPlatform.macOS: _YorksNoPageTransitionBuilder(),
          TargetPlatform.windows: _YorksNoPageTransitionBuilder(),
          TargetPlatform.linux: _YorksNoPageTransitionBuilder(),
          TargetPlatform.fuchsia: _YorksNoPageTransitionBuilder(),
        },
      ),
      splashFactory: NoSplash.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLow,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.titleLarge,
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 0,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        margin: EdgeInsets.zero,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.onPrimary,
          backgroundColor: AppColors.navy,
          disabledForegroundColor: AppColors.mutedLight,
          disabledBackgroundColor: AppColors.surfaceContainerHighest,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          elevation: 0,
          textStyle: AppTypography.labelLarge.copyWith(
            color: AppColors.onPrimary,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkSecondary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          side: const BorderSide(color: AppColors.line),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.mutedLight,
          fontSize: 11.5,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navy,
        indicatorColor: AppColors.surfaceContainerLowest.withValues(
          alpha: 0.14,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSmall.copyWith(
            color: selected
                ? AppColors.onPrimary
                : AppColors.onPrimary.withValues(alpha: 0.72),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? AppColors.onPrimary
                : AppColors.onPrimary.withValues(alpha: 0.72),
            size: 22,
          );
        }),
        elevation: 0,
        height: 68,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutralContainer,
        labelStyle: AppTypography.labelMedium,
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.line),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),

      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
        color: AppColors.line,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onInverseSurface,
        ),
        actionTextColor: AppColors.blueContainerStrong,
        elevation: 3,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 4,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        elevation: 4,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.lineStrong,
      ),

      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(
          AppColors.surfaceContainerLow,
        ),
        headingTextStyle: AppTypography.labelSmall.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: AppTypography.bodySmall.copyWith(
          color: AppColors.onSurface,
        ),
        dividerThickness: 1,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
      ),
    );
  }

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

/// A deliberate no-motion transition for the Yorks operational shell.
///
/// The prototype uses stable panels and immediate navigation. Returning the
/// destination directly avoids a route-level animation even for retained
/// screens that still use a standard Material route.
final class _YorksNoPageTransitionBuilder extends PageTransitionsBuilder {
  const _YorksNoPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    Route<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
