import 'package:flutter/material.dart';

import '../constants/constants.dart';
import 'status_chip.dart';

/// Makes the current workflow state, next action and owner explicit.
///
/// All copy is supplied by the caller so localisation remains at the feature
/// boundary.
class CurrentActionCard extends StatelessWidget {
  const CurrentActionCard({
    super.key,
    required this.title,
    required this.message,
    this.ownerLabel,
    this.ownerName,
    this.tone = NexusStatusTone.success,
    this.icon = Icons.check_rounded,
  }) : assert(
         (ownerLabel == null) == (ownerName == null),
         'ownerLabel and ownerName must be supplied together',
       );

  final String title;
  final String message;
  final String? ownerLabel;
  final String? ownerName;
  final NexusStatusTone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = NexusStatusPalette.forTone(tone);

    return Semantics(
      container: true,
      label: title,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: palette.background.withValues(alpha: 0.72),
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd + 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, size: 16, color: palette.foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: AppTypography.bodySmall.copyWith(
                      color: palette.foreground,
                    ),
                  ),
                  if (ownerName != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$ownerLabel: ',
                            style: AppTypography.labelMedium.copyWith(
                              color: palette.foreground.withValues(alpha: 0.8),
                            ),
                          ),
                          TextSpan(
                            text: ownerName,
                            style: AppTypography.labelMedium.copyWith(
                              color: palette.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
