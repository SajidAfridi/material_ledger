import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/employee_record.dart';
import '../../../../shared/models/leave_record.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import 'my_leave_screen.dart' show MyLeaveScreen;

/// Admin/procurement approvals queue: pending leave requests to approve/reject,
/// plus recent decisions. Route-guarded by `canApproveLeave`.
class LeaveRequestsScreen extends ConsumerWidget {
  const LeaveRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final pending = ref.watch(pendingLeaveRequestsProvider);
    final decided =
        ref.watch(leaveRecordsProvider).where((l) => !l.isPending && l.isRequest).toList()
          ..sort((a, b) => (b.decidedAt ?? b.startDate).compareTo(a.decidedAt ?? a.startDate));

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
          english: AppStrings.leaveRequestsTitle.primary,
          secondary: AppStrings.leaveRequestsTitle.secondary(lang),
          englishStyle: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
          secondaryStyle: AppTypography.labelSmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveCenter(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              _SectionLabel('${LeaveRecordStatus.pending.label} (${pending.length})'),
              const Gap(AppSpacing.sm),
              if (pending.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Center(
                    child: Text(
                      AppStrings.noPendingLeave.primary,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                for (final r in pending) ...[
                  _RequestCard(record: r, actionable: true),
                  const Gap(AppSpacing.listItemGap),
                ],
              if (decided.isNotEmpty) ...[
                const Gap(AppSpacing.xl),
                const _SectionLabel('Recent decisions'),
                const Gap(AppSpacing.sm),
                for (final r in decided.take(10)) ...[
                  _RequestCard(record: r, actionable: false),
                  const Gap(AppSpacing.listItemGap),
                ],
              ],
              const Gap(AppSpacing.colossal),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: AppTypography.labelMedium.copyWith(
      color: AppColors.onSurfaceVariant,
      letterSpacing: 0.5,
    ),
  );
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.record, required this.actionable});
  final LeaveRecord record;
  final bool actionable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('d MMM yyyy');
    final lang = ref.watch(languageProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isOwn =
        record.requestedByUserId != null && record.requestedByUserId == currentUserId;

    // Resolve employee name + balance.
    Employee? emp;
    for (final e in ref.watch(employeesProvider)) {
      if (e.id == record.employeeId) {
        emp = e;
        break;
      }
    }
    final who = emp?.fullName ?? record.requestedByName ?? record.employeeId;
    final balance = ref.watch(leaveBalanceProvider(record.employeeId));
    final overBalance =
        record.type == LeaveType.annual && record.days > balance.remaining;

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
                    Text(who, style: AppTypography.titleSmall),
                    const Gap(2),
                    Text(
                      '${record.type.label} · ${df.format(record.startDate)} – ${df.format(record.endDate)} · ${record.days} ${AppStrings.daysUnit.primary}',
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
          if (record.type == LeaveType.annual) ...[
            const Gap(AppSpacing.xs),
            Text(
              '${AppStrings.leaveBalance.primary}: ${balance.remaining}/${balance.entitlement}${overBalance ? '  ⚠ ${AppStrings.overBalanceWarning.primary}' : ''}',
              style: AppTypography.bodySmall.copyWith(
                color: overBalance ? AppColors.warning : AppColors.onSurfaceVariant,
              ),
            ),
          ],
          if (!actionable &&
              record.approvedBy != null &&
              (record.decisionNote ?? '').isNotEmpty) ...[
            const Gap(AppSpacing.xs),
            Text(
              '${record.approvedBy}: ${record.decisionNote}',
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (actionable && isOwn) ...[
            const Gap(AppSpacing.sm),
            Text(
              'Your own request — another approver must decide it.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (actionable && !isOwn) ...[
            const Gap(AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _decide(context, ref, lang, approve: false),
                  child: Text(
                    AppStrings.rejectAction.primary,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
                const Gap(AppSpacing.sm),
                FilledButton(
                  onPressed: () => _decide(context, ref, lang, approve: true),
                  child: Text(AppStrings.approveAction.primary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    lang, {
    required bool approve,
  }) async {
    String? note;
    if (!approve) {
      note = await _askReason(context);
      if (note == null) return; // cancelled
    } else {
      // Approval is irreversible and deducts from the balance — confirm first.
      final ok = await _confirmApprove(context);
      if (ok != true) return;
    }
    if (!context.mounted) return;
    final user = ref.read(currentUserProvider);
    final actor = ref.read(actorNameProvider);
    final df = DateFormat('d MMM yyyy');
    final span = '${df.format(record.startDate)} – ${df.format(record.endDate)}';

    final updated = await ref
        .read(leaveRecordsProvider.notifier)
        .decide(
          record.id,
          approve: approve,
          decidedBy: actor,
          decidedByUserId: user?.id,
          decisionNote: note,
        );
    if (updated == null) {
      if (context.mounted && approve) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't approve — it overlaps an already-approved leave for "
              'this employee.',
            ),
          ),
        );
      }
      return;
    }

    if ((record.requestedByUserId ?? '').isNotEmpty) {
      await ref
          .read(notificationsProvider.notifier)
          .add(
            type: NotificationType.request,
            title: approve
                ? AppStrings.leaveApprovedMsg.primary
                : AppStrings.leaveRejectedMsg.primary,
            titleSecondary: approve
                ? AppStrings.leaveApprovedMsg.secondary(lang)
                : AppStrings.leaveRejectedMsg.secondary(lang),
            body: '${record.type.label} · $span · ${record.days}d',
            refId: record.id,
            route: RoutePaths.myLeave,
            userId: record.requestedByUserId!,
          );
    }
    await ref.logAudit(
      action: approve ? 'Leave approved' : 'Leave rejected',
      module: AuditModule.leave,
      refId: record.id,
      detail: '${record.requestedByName ?? record.employeeId} · ${record.type.label} · $span · ${record.days}d',
    );
  }

  Future<bool?> _confirmApprove(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.approveAction.primary,
          style: AppTypography.titleMedium,
        ),
        content: const Text(
          'Approving is final and deducts these days from the balance. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.cancel.primary),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.approveAction.primary),
          ),
        ],
      ),
    );
  }

  Future<String?> _askReason(BuildContext context) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          ),
          title: Text(
            AppStrings.rejectAction.primary,
            style: AppTypography.titleMedium,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: AppStrings.reasonOptional.primary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.cancel.primary),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(AppStrings.rejectAction.primary),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
