import 'package:flutter/material.dart';

import '../constants/constants.dart';

/// Status chip following design spec:
/// 10% opacity fill + 100% opacity text color.
/// No heavy solid blocks of color.
class StatusChip extends StatelessWidget {
  const StatusChip._({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  /// Success status (e.g., "In Stock")
  factory StatusChip.success(String label, {IconData? icon}) => StatusChip._(
    label: label,
    backgroundColor: AppColors.successContainer.withValues(alpha: 0.3),
    textColor: AppColors.success,
    icon: icon,
  );

  /// Warning status (e.g., "Low Stock")
  factory StatusChip.warning(String label, {IconData? icon}) => StatusChip._(
    label: label,
    backgroundColor: AppColors.warningContainer.withValues(alpha: 0.3),
    textColor: AppColors.warning,
    icon: icon,
  );

  /// Error status (e.g., "Out of Stock")
  factory StatusChip.error(String label, {IconData? icon}) => StatusChip._(
    label: label,
    backgroundColor: AppColors.errorContainer.withValues(alpha: 0.3),
    textColor: AppColors.error,
    icon: icon,
  );

  /// Neutral/info status
  factory StatusChip.info(String label, {IconData? icon}) => StatusChip._(
    label: label,
    backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
    textColor: AppColors.primary,
    icon: icon,
  );

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
