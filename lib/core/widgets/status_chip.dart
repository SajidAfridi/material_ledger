import 'package:flutter/material.dart';

import '../constants/constants.dart';

enum NexusStatusTone {
  info,
  success,
  warning,
  danger,
  purple,
  neutral,
  outline,
}

/// Compact V7 status pill for operational state, never for primary actions.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = NexusStatusTone.neutral,
    this.icon,
    this.showDot = false,
  });

  factory StatusChip.success(String label, {IconData? icon}) =>
      StatusChip(label: label, tone: NexusStatusTone.success, icon: icon);

  factory StatusChip.warning(String label, {IconData? icon}) =>
      StatusChip(label: label, tone: NexusStatusTone.warning, icon: icon);

  factory StatusChip.error(String label, {IconData? icon}) =>
      StatusChip(label: label, tone: NexusStatusTone.danger, icon: icon);

  factory StatusChip.info(String label, {IconData? icon}) =>
      StatusChip(label: label, tone: NexusStatusTone.info, icon: icon);

  factory StatusChip.purple(String label, {IconData? icon}) =>
      StatusChip(label: label, tone: NexusStatusTone.purple, icon: icon);

  final String label;
  final NexusStatusTone tone;
  final IconData? icon;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final palette = NexusStatusPalette.forTone(tone);

    return Semantics(
      label: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: 25),
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDot) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: palette.foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (icon != null) ...[
              Icon(icon, size: 13, color: palette.foreground),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: palette.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class NexusStatusPalette {
  const NexusStatusPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static NexusStatusPalette forTone(NexusStatusTone tone) => switch (tone) {
    NexusStatusTone.info => const NexusStatusPalette(
      background: AppColors.blueContainer,
      foreground: Color(0xFF1252B1),
      border: Color(0xFFD2E2FF),
    ),
    NexusStatusTone.success => const NexusStatusPalette(
      background: AppColors.successContainer,
      foreground: AppColors.onSuccessContainer,
      border: Color(0xFFCCEEE1),
    ),
    NexusStatusTone.warning => const NexusStatusPalette(
      background: AppColors.warningContainer,
      foreground: AppColors.onWarningContainer,
      border: Color(0xFFF4DFB0),
    ),
    NexusStatusTone.danger => const NexusStatusPalette(
      background: AppColors.errorContainer,
      foreground: AppColors.onErrorContainer,
      border: Color(0xFFF3CACA),
    ),
    NexusStatusTone.purple => const NexusStatusPalette(
      background: AppColors.purpleContainer,
      foreground: Color(0xFF5A3BB5),
      border: Color(0xFFDED2FF),
    ),
    NexusStatusTone.neutral => const NexusStatusPalette(
      background: AppColors.neutralContainer,
      foreground: AppColors.neutralText,
      border: Color(0xFFE0E6ED),
    ),
    NexusStatusTone.outline => const NexusStatusPalette(
      background: AppColors.surfaceContainerLowest,
      foreground: AppColors.neutralText,
      border: AppColors.line,
    ),
  };
}
