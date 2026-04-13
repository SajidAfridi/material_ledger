import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Primary CTA button with gradient (design spec: primary → onPrimaryFixedVariant at 135°).
/// Fully rounded to contrast against sharp, rectangular construction materials.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    this.isTrailingIcon = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;
  final bool isTrailingIcon;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      constraints: BoxConstraints(
        minHeight: AppSpacing.minTapTarget,
        minWidth: isExpanded ? double.infinity : 0,
      ),
      decoration: BoxDecoration(
        gradient: onPressed != null ? AppColors.primaryGradient : null,
        color: onPressed == null
            ? AppColors.onSurfaceVariant.withValues(alpha: 0.12)
            : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.onPrimary,
                    ),
                  )
                else ...[
                  if (icon != null && !isTrailingIcon) ...[
                    Icon(icon, size: 20, color: AppColors.onPrimary),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: onPressed != null
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (icon != null && isTrailingIcon) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(icon, size: 20, color: AppColors.onPrimary),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return child;
  }
}

/// Secondary button — No fill, ghost border (15% outline-variant).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isExpanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(
          isExpanded ? double.infinity : 0,
          AppSpacing.minTapTarget,
        ),
        shape: const StadiumBorder(),
        side: BorderSide(color: AppColors.ghostBorder),
      ),
      child: Row(
        mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(label),
        ],
      ),
    );
  }
}
