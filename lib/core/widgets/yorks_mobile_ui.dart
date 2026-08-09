import 'package:flutter/material.dart';

import '../constants/constants.dart';
import 'brand_logo.dart';

/// Presentation-only building blocks for the Yorks 390px mobile workspace.
///
/// These widgets deliberately contain no navigation, authorization or data
/// access. Feature screens supply their existing controller-backed state.
abstract final class YorksMobileUi {
  static const double breakpoint = 720;
  static const double appBarHeight = 54;
  static const double navigationHeight = 64;
  static const double horizontalPadding = 14;
  static const double cardRadius = 15;

  static bool isActive(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= breakpoint;
}

class YorksMobileAppBar extends StatelessWidget {
  const YorksMobileAppBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.brand = false,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final bool brand;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    child: SafeArea(
      bottom: false,
      child: Container(
        height: YorksMobileUi.appBarHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: YorksMobileUi.horizontalPadding,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child:
                  leading ??
                  (brand ? const BrandLogo(size: 34, shadow: false) : null),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 54),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.ink,
                  fontSize: YorksMobileUi.isActive(context) ? 15 : 16,
                  fontWeight: YorksMobileUi.isActive(context)
                      ? FontWeight.w800
                      : null,
                ),
              ),
            ),
            Align(alignment: Alignment.centerRight, child: trailing),
          ],
        ),
      ),
    ),
  );
}

class YorksMobileIconButton extends StatelessWidget {
  const YorksMobileIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSpacing.minTapTarget,
    child: Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, size: 21, color: AppColors.inkSecondary),
        ),
        if (badge)
          const Positioned(
            top: 8,
            right: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 7),
            ),
          ),
      ],
    ),
  );
}

class YorksMobileCard extends StatelessWidget {
  const YorksMobileCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.surfaceContainerLowest,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mobile = YorksMobileUi.isActive(context);
    final card = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          mobile ? YorksMobileUi.cardRadius : 14,
        ),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (!mobile) return card;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(YorksMobileUi.cardRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E143255),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: card,
    );
  }
}

class YorksMobileSectionHeader extends StatelessWidget {
  const YorksMobileSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: AppTypography.bodySmall),
            ],
          ],
        ),
      ),
      ?action,
    ],
  );
}

class YorksMobileMetricCard extends StatelessWidget {
  const YorksMobileMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint = AppColors.blueContainer,
    this.iconColor = AppColors.blue,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => YorksMobileCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox.square(
            dimension: 32,
            child: Icon(icon, size: 17, color: iconColor),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.headlineMedium.copyWith(
            fontSize: 23,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, maxLines: 1, style: AppTypography.labelMedium),
      ],
    ),
  );
}

class YorksMobilePill extends StatelessWidget {
  const YorksMobilePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      color: selected ? AppColors.navy : AppColors.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? AppColors.navy : AppColors.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: selected ? AppColors.onPrimary : AppColors.inkSecondary,
              ),
            ),
          ),
        ),
      ),
    );
    if (!YorksMobileUi.isActive(context)) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Center(child: pill),
      ),
    );
  }
}
