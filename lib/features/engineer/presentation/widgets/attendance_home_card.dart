import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';

/// Compact "My data" attendance card for the home dashboard. Tapping it (or
/// "Show more") opens the full employee detail screen.
class AttendanceHomeCard extends ConsumerWidget {
  const AttendanceHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final a = ref.watch(employeeProvider).attendance;

    return LedgerCard(
      onTap: () => context.push(RoutePaths.employeeDetail),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: BilingualText(
                  english: AppStrings.myData.primary,
                  secondary: AppStrings.myData.secondary(lang),
                  englishStyle: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  secondaryStyle: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.showMore.primary,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.login_rounded,
                  label: AppStrings.checkInLabel.primary,
                  value: a.checkIn,
                  accent: AppColors.success,
                ),
              ),
              _divider(),
              Expanded(
                child: _MiniStat(
                  icon: Icons.logout_rounded,
                  label: AppStrings.checkOutLabel.primary,
                  value: a.checkOut,
                  accent: AppColors.primary,
                ),
              ),
              _divider(),
              Expanded(
                child: _MiniStat(
                  icon: Icons.timelapse_rounded,
                  label: AppStrings.remainingLabel.primary,
                  value: '${a.remainingHours} ${AppStrings.hoursUnit.primary}',
                  accent: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 36,
    color: AppColors.surfaceContainerHigh,
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: accent),
        const Gap(AppSpacing.xs),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(2),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
