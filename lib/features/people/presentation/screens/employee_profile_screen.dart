import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/leave_record.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../widgets/record_leave_sheet.dart';

/// Full employee profile. Salary and identity documents are restricted to
/// Admin (FR-128). Procurement & Admin can record leave / manage the roster.
class EmployeeProfileScreen extends ConsumerWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(currencyProvider);
    final employee = ref.watch(employeesProvider.notifier).byId(employeeId);

    if (employee == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(AppStrings.noDataYet.primary)),
      );
    }

    final balance = ref.watch(leaveBalanceProvider(employeeId));
    final leaves = ref
        .watch(leaveRecordsProvider)
        .where((l) => l.employeeId == employeeId)
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final canSeeSalary = ref.watch(canSeeSalaryProvider);
    final canWrite = ref.watch(canWritePeopleProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(employee.fullName, style: AppTypography.titleLarge),
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => RecordLeaveSheet.show(context, employee),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.event_available_outlined),
              label: Text(AppStrings.recordLeave.primary),
            )
          : null,
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              // ─── Identity ───────────────────────────────────
              LedgerCard(
                color: AppColors.surfaceContainerLowest,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryContainer.withValues(
                        alpha: 0.15,
                      ),
                      child: Text(
                        employee.initials,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Gap(AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.jobRole,
                            style: AppTypography.titleSmall,
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            '${employee.department} · ${employee.nationality}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              // ─── Leave balance ──────────────────────────────
              LedgerCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.leaveBalanceLabel.primary,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Gap(AppSpacing.xxs),
                        Text(
                          '${balance.remaining} / ${balance.entitlement}',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${AppStrings.leaveUsed.primary}: ${balance.usedAnnual}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),

              // ─── Details ────────────────────────────────────
              LedgerCard(
                child: Column(
                  children: [
                    if (employee.contact != null)
                      _Row(
                        icon: Icons.phone_outlined,
                        label: AppStrings.tenantContact.primary,
                        value: employee.contact!,
                      ),
                    if (employee.joinDate != null)
                      _Row(
                        icon: Icons.event_outlined,
                        label: AppStrings.joinDate.primary,
                        value: _fmt(employee.joinDate!),
                      ),
                    // Restricted fields — Admin only.
                    if (canSeeSalary) ...[
                      if (employee.salaryAED != null)
                        _Row(
                          icon: Icons.payments_outlined,
                          label: AppStrings.salary.primary,
                          value: currency.format(employee.salaryAED!),
                        ),
                      if (employee.emiratesId != null)
                        _Row(
                          icon: Icons.badge_outlined,
                          label: AppStrings.emiratesId.primary,
                          value: employee.emiratesId!,
                        ),
                      if (employee.passportNo != null)
                        _Row(
                          icon: Icons.menu_book_outlined,
                          label: AppStrings.passportNo.primary,
                          value: employee.passportNo!,
                        ),
                      if (employee.visaExpiry != null)
                        _Row(
                          icon: Icons.event_busy_outlined,
                          label: AppStrings.visaExpiry.primary,
                          value: _fmt(employee.visaExpiry!),
                        ),
                    ] else
                      _Row(
                        icon: Icons.lock_outline_rounded,
                        label: AppStrings.salary.primary,
                        value: AppStrings.restrictedLabel.primary,
                      ),
                  ],
                ),
              ),
              const Gap(AppSpacing.xl),

              // ─── Leave history ──────────────────────────────
              Text(
                AppStrings.leaveHistory.primary,
                style: AppTypography.titleMedium,
              ),
              const Gap(AppSpacing.md),
              if (leaves.isEmpty)
                Text(
                  AppStrings.noLeaveYet.primary,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                for (final l in leaves) ...[
                  _LeaveRow(leave: l),
                  const Gap(AppSpacing.listItemGap),
                ],
              const Gap(AppSpacing.huge),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onSurfaceVariant),
          const Gap(AppSpacing.md),
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveRow extends StatelessWidget {
  const _LeaveRow({required this.leave});

  final LeaveRecord leave;

  @override
  Widget build(BuildContext context) {
    final chip = switch (leave.status) {
      LeaveRecordStatus.approved => StatusChip.success(leave.status.label),
      LeaveRecordStatus.pending => StatusChip.warning(leave.status.label),
      LeaveRecordStatus.rejected => StatusChip.error(leave.status.label),
    };
    return LedgerCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${leave.type.label} · ${leave.days} day(s)',
                  style: AppTypography.titleSmall,
                ),
                const Gap(AppSpacing.xxs),
                Text(
                  '${_fmt(leave.startDate)} → ${_fmt(leave.endDate)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          chip,
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
