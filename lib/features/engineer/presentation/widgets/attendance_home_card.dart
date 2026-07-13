import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/employee.dart';
import '../../../../shared/providers/employee_provider.dart';
import '../../../../shared/providers/language_provider.dart';

/// Compact "My data" card for the home dashboard, showing the signed-in
/// engineer's live HR snapshot — today's attendance, annual leave left, and any
/// pending leave requests. Tapping it (or "Show more") opens the full detail.
class AttendanceHomeCard extends ConsumerWidget {
  const AttendanceHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final emp = ref.watch(employeeProvider);
    final status = _statusView(emp.today);

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
                  icon: status.icon,
                  label: AppStrings.todayLabel.primary,
                  value: status.label,
                  accent: status.color,
                ),
              ),
              _divider(),
              Expanded(
                child: _MiniStat(
                  icon: Icons.event_available_rounded,
                  label: AppStrings.annualLeftLabel.primary,
                  value: emp.linked
                      ? '${emp.annualRemaining}/${emp.annualEntitlement}'
                      : '—',
                  accent: AppColors.primary,
                ),
              ),
              _divider(),
              Expanded(
                child: _MiniStat(
                  icon: Icons.pending_actions_rounded,
                  label: AppStrings.pendingLabel.primary,
                  value: emp.linked ? '${emp.pendingRequests}' : '—',
                  accent: emp.pendingRequests > 0
                      ? AppColors.warning
                      : AppColors.onSurfaceVariant,
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

/// Icon / label / colour for a [SelfAttendance] state (English label — the
/// mini-stat values on this card are single-line and English, matching the
/// rest of the card's compact stat treatment).
({IconData icon, String label, Color color}) _statusView(SelfAttendance s) {
  return switch (s) {
    SelfAttendance.present => (
      icon: Icons.check_circle_rounded,
      label: 'Present',
      color: AppColors.success,
    ),
    SelfAttendance.halfDay => (
      icon: Icons.timelapse_rounded,
      label: 'Half day',
      color: AppColors.warning,
    ),
    SelfAttendance.onLeave => (
      icon: Icons.beach_access_rounded,
      label: 'On leave',
      color: AppColors.primary,
    ),
    SelfAttendance.absent => (
      icon: Icons.cancel_rounded,
      label: 'Absent',
      color: AppColors.error,
    ),
    SelfAttendance.notMarked => (
      icon: Icons.remove_circle_outline_rounded,
      label: AppStrings.notMarkedYet.primary,
      color: AppColors.onSurfaceVariant,
    ),
  };
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
