import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/leave_record.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../widgets/request_leave_sheet.dart';

/// Engineer self-service: view my leave balance + history and file new requests.
class MyLeaveScreen extends ConsumerWidget {
  const MyLeaveScreen({super.key});

  static StatusChip chipFor(LeaveRecordStatus s) => switch (s) {
    LeaveRecordStatus.approved => StatusChip.success(s.label),
    LeaveRecordStatus.pending => StatusChip.warning(s.label),
    LeaveRecordStatus.rejected => StatusChip.error(s.label),
    LeaveRecordStatus.cancelled => StatusChip.info(s.label),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final employee = ref.watch(currentUserEmployeeProvider);
    final records = ref.watch(myLeaveRecordsProvider);

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
        title: BilingualText(
          english: AppStrings.myLeave.primary,
          secondary: AppStrings.myLeave.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      floatingActionButton: employee == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => RequestLeaveSheet.show(context, employee),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_rounded),
              label: Text(AppStrings.requestLeave.primary),
            ),
      body: SafeArea(
        top: false,
        child: employee == null
            ? _UnlinkedState()
            : ResponsiveCenter(
                maxWidth: 720,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  children: [
                    _BalanceCard(employeeId: employee.id),
                    const Gap(AppSpacing.lg),
                    if (records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.huge),
                        child: Center(
                          child: Text(
                            AppStrings.noLeaveRequests.primary,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final r in records) ...[
                        _LeaveCard(record: r),
                        const Gap(AppSpacing.listItemGap),
                      ],
                    const Gap(AppSpacing.colossal),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(leaveBalanceProvider(employeeId));
    return LedgerCard(
      color: AppColors.primaryFixed.withValues(alpha: 0.35),
      child: Row(
        children: [
          Icon(Icons.beach_access_rounded, color: AppColors.primary, size: 28),
          const Gap(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.leaveBalance.primary, style: AppTypography.labelMedium),
                const Gap(2),
                Text(
                  '${b.remaining} / ${b.entitlement} ${AppStrings.daysUnit.primary}',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Text(
            '${b.usedAnnual} used',
            style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends ConsumerWidget {
  const _LeaveCard({required this.record});
  final LeaveRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('d MMM yyyy');
    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.type.label} · ${record.days} ${AppStrings.daysUnit.primary}',
                      style: AppTypography.titleSmall,
                    ),
                    const Gap(2),
                    Text(
                      '${df.format(record.startDate)} – ${df.format(record.endDate)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              MyLeaveScreen.chipFor(record.status),
            ],
          ),
          if ((record.reason ?? '').isNotEmpty) ...[
            const Gap(AppSpacing.sm),
            Text(record.reason!, style: AppTypography.bodySmall),
          ],
          if (record.status == LeaveRecordStatus.rejected &&
              (record.decisionNote ?? '').isNotEmpty) ...[
            const Gap(AppSpacing.sm),
            Text(
              '${AppStrings.rejectAction.primary}: ${record.decisionNote!}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.error),
            ),
          ],
          if (record.isPending) ...[
            const Gap(AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(AppStrings.withdrawConfirmTitle.primary),
                      content: Text(AppStrings.withdrawConfirmBody.primary),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(AppStrings.cancel.primary),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(AppStrings.withdrawAction.primary),
                        ),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  await ref.read(leaveRecordsProvider.notifier).withdraw(record.id);
                  await ref.logAudit(
                    action: 'Leave withdrawn',
                    module: AuditModule.leave,
                    refId: record.id,
                    detail: '${record.type.label} · ${record.days}d',
                  );
                  AppFeedback.confirm();
                },
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(AppStrings.withdrawAction.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnlinkedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 48,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const Gap(AppSpacing.lg),
            Text(
              AppStrings.notLinkedToEmployee.primary,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
