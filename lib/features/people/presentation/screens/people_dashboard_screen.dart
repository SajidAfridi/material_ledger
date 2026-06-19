import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/employee_record.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';

/// People / HR module home: workforce summary + employee roster.
/// Procurement & Admin read and write (HR was moved to Procurement).
class PeopleDashboardScreen extends ConsumerWidget {
  const PeopleDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final employees = ref.watch(employeesProvider);
    final summary = ref.watch(hrSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // tab root — nothing to go back to
        title: BilingualText(
          english: AppStrings.people.primary,
          secondary: AppStrings.people.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.w800,
          ),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Summary ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: AppStrings.employees.primary,
                      value: '${summary.total}',
                      color: AppColors.primary,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _StatCard(
                      label: AppStrings.presentToday.primary,
                      value: '${summary.presentToday}',
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: AppStrings.onLeaveLabel.primary,
                      value: '${summary.onLeaveToday}',
                      color: AppColors.warning,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _StatCard(
                      label: AppStrings.absentLabel.primary,
                      value: '${summary.absentToday}',
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.xl),

              Text(AppStrings.employees.primary, style: AppTypography.titleMedium),
              const Gap(AppSpacing.md),

              if (employees.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      AppStrings.noEmployeesYet.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final e in employees) ...[
                  _EmployeeCard(employee: e),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LedgerCard(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.headlineSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeCard extends ConsumerWidget {
  const _EmployeeCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(leaveBalanceProvider(employee.id));
    final statusChip = switch (employee.status) {
      EmployeeStatus.active => StatusChip.success(employee.status.label),
      EmployeeStatus.onLeave => StatusChip.warning(employee.status.label),
      EmployeeStatus.inactive => StatusChip.error(employee.status.label),
    };
    return LedgerCard(
      onTap: () => context.push(RoutePaths.employeeProfilePath(employee.id)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.15),
            child: Text(
              employee.initials,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Gap(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(employee.fullName, style: AppTypography.titleSmall),
                const Gap(AppSpacing.xxs),
                Text(
                  '${employee.jobRole} · ${employee.nationality}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Gap(AppSpacing.xs),
                Text(
                  '${AppStrings.leaveUsed.primary}: ${balance.usedAnnual}/${balance.entitlement}',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          statusChip,
        ],
      ),
    );
  }
}
