import 'package:flutter/material.dart';

import '../../../../core/constants/constants.dart';

class YorksPermissionSurface extends StatelessWidget {
  const YorksPermissionSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: highlighted
          ? AppColors.blueContainer.withValues(alpha: .42)
          : AppColors.surfaceContainerLowest,
      border: Border.all(
        color: highlighted ? AppColors.blueContainerStrong : AppColors.line,
      ),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0918324B),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class YorksPermissionSectionTitle extends StatelessWidget {
  const YorksPermissionSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: AppSpacing.md),
        trailing!,
      ],
    ],
  );
}

class YorksPermissionPill extends StatelessWidget {
  const YorksPermissionPill({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
  });

  final String label;
  final YorksPermissionPillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      YorksPermissionPillTone.allowed => const (
        AppColors.successContainer,
        AppColors.onSuccessContainer,
        Color(0xFFCCEADF),
      ),
      YorksPermissionPillTone.denied => const (
        AppColors.errorContainer,
        AppColors.onErrorContainer,
        Color(0xFFF0CCCC),
      ),
      YorksPermissionPillTone.info => const (
        AppColors.blueContainer,
        AppColors.blue,
        AppColors.blueContainerStrong,
      ),
      YorksPermissionPillTone.warning => const (
        AppColors.warningContainer,
        AppColors.onWarningContainer,
        Color(0xFFF2DDAA),
      ),
      YorksPermissionPillTone.neutral => const (
        AppColors.neutralContainer,
        AppColors.neutralText,
        AppColors.line,
      ),
    };
    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colors.$1,
          border: Border.all(color: colors.$3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.$2),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AppTypography.labelSmall.copyWith(
                  color: colors.$2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum YorksPermissionPillTone { allowed, denied, info, warning, neutral }

class YorksPermissionStatePanel extends StatelessWidget {
  const YorksPermissionStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.blueContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              ),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(icon, color: AppColors.blue, size: 30),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (primaryLabel != null || secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (secondaryLabel != null)
                    OutlinedButton(
                      onPressed: onSecondary,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  if (primaryLabel != null)
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(primaryLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
