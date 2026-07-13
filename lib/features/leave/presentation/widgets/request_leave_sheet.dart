import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/feedback/feedback_service.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_notification.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/employee_record.dart';
import '../../../../shared/models/leave_record.dart';
import '../../../../shared/models/user_role.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/notification_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Engineer self-service: file a leave request for the [employee] linked to the
/// signed-in login. Submitting creates a `pending` [LeaveRecord], notifies the
/// approvers, and audits the action.
class RequestLeaveSheet extends ConsumerStatefulWidget {
  const RequestLeaveSheet({super.key, required this.employee});

  final Employee employee;

  static Future<void> show(BuildContext context, Employee employee) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RequestLeaveSheet(employee: employee),
    );
  }

  @override
  ConsumerState<RequestLeaveSheet> createState() => _RequestLeaveSheetState();
}

class _RequestLeaveSheetState extends ConsumerState<RequestLeaveSheet> {
  final _df = DateFormat('d MMM yyyy');
  LeaveType _type = LeaveType.annual;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _days =>
      (_startDate != null && _endDate != null && !_endDate!.isBefore(_startDate!))
      ? _endDate!.difference(_startDate!).inDays + 1
      : 0;

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate == null || _endDate!.isBefore(picked)) _endDate = picked;
        _error = null;
      });
    }
  }

  Future<void> _pickEnd() async {
    final base = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: _startDate ?? DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      AppFeedback.warning();
      setState(() => _error = AppStrings.pickStartEndDate.primary);
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      AppFeedback.warning();
      setState(() => _error = AppStrings.endAfterStart.primary);
      return;
    }
    final emp = widget.employee;
    // Block overlapping leave rather than only warning — two overlapping
    // requests would both consume balance for the same days.
    if (ref
        .read(leaveRecordsProvider.notifier)
        .leaveOverlaps(emp.id, _startDate!, _endDate!)) {
      AppFeedback.warning();
      setState(() => _error = AppStrings.leaveOverlapWarning.primary);
      return;
    }
    final user = ref.read(currentUserProvider);
    final actor = ref.read(actorNameProvider);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rec = await ref
          .read(leaveRecordsProvider.notifier)
          .submitRequest(
            employeeId: emp.id,
            requestedByUserId: user?.id ?? '',
            requestedByName: actor,
            type: _type,
            startDate: _startDate!,
            endDate: _endDate!,
            reason: _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
          );

      final span = '${_df.format(_startDate!)} – ${_df.format(_endDate!)}';
      await ref
          .read(notificationsProvider.notifier)
          .add(
            type: NotificationType.request,
            title: 'Leave request · ${emp.fullName}',
            titleSecondary: 'چھٹی کی درخواست · ${emp.fullName}',
            body: '${_type.label} · $span · ${rec.days}d',
            refId: rec.id,
            route: RoutePaths.leaveRequests,
            audience: UserRole.procurement.name, // procurement; admin sees all
          );
      await ref.logAudit(
        action: 'Leave requested',
        module: AuditModule.leave,
        refId: rec.id,
        detail: '${emp.fullName} · ${_type.label} · $span · ${rec.days}d',
      );

      if (!mounted) return;
      AppFeedback.confirm();
      showSyncSnack(context, ref, savedLabel: AppStrings.leaveSubmitted.primary);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Bad state: ', '');
      setState(() {
        _busy = false;
        _error = msg;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final balance = ref.watch(leaveBalanceProvider(widget.employee.id));
    ref.watch(leaveRecordsProvider); // rebuild overlap check on data change
    final overlap =
        _startDate != null &&
        _endDate != null &&
        !_endDate!.isBefore(_startDate!) &&
        ref
            .read(leaveRecordsProvider.notifier)
            .leaveOverlaps(widget.employee.id, _startDate!, _endDate!);
    final overBalance = _type == LeaveType.annual && _days > balance.remaining;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Gap(AppSpacing.md),
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Gap(AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.requestLeave.primary,
                          style: GoogleFonts.inter(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Gap(AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Balance hint
                      Text(
                        '${AppStrings.leaveBalance.primary}: ${balance.remaining} / ${balance.entitlement} ${AppStrings.daysUnit.primary}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      // Type chips
                      Text(
                        AppStrings.leaveTypeLabel.primary,
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const Gap(AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final t in LeaveType.values)
                            _TypeChip(
                              label: t.label,
                              selected: _type == t,
                              onTap: () => setState(() => _type = t),
                            ),
                        ],
                      ),
                      const Gap(AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: LedgerTextField(
                              controller: TextEditingController(
                                text: _startDate == null ? '' : _df.format(_startDate!),
                              ),
                              label: AppStrings.startDate.primary,
                              readOnly: true,
                              onTap: _pickStart,
                              suffixIcon: const Icon(Icons.calendar_today_rounded),
                            ),
                          ),
                          const Gap(AppSpacing.md),
                          Expanded(
                            child: LedgerTextField(
                              controller: TextEditingController(
                                text: _endDate == null ? '' : _df.format(_endDate!),
                              ),
                              label: AppStrings.leaveEndDate.primary,
                              readOnly: true,
                              onTap: _pickEnd,
                              suffixIcon: const Icon(Icons.calendar_today_rounded),
                            ),
                          ),
                        ],
                      ),
                      const Gap(AppSpacing.md),
                      LedgerTextField(
                        controller: _reasonController,
                        label: AppStrings.reasonOptional.primary,
                        maxLines: 2,
                      ),
                      if (_days > 0) ...[
                        const Gap(AppSpacing.md),
                        Text(
                          '$_days ${AppStrings.daysUnit.primary}',
                          style: AppTypography.titleSmall,
                        ),
                      ],
                      if (_type == LeaveType.sick && _days > 0) ...[
                        const Gap(AppSpacing.sm),
                        Builder(
                          builder: (context) {
                            final split = ref.watch(
                              sickLeaveTierProvider((widget.employee.id, _days)),
                            );
                            final parts = [
                              if (split.fullPayDays > 0) '${split.fullPayDays}d full pay',
                              if (split.halfPayDays > 0) '${split.halfPayDays}d half pay',
                              if (split.unpaidDays > 0) '${split.unpaidDays}d unpaid',
                            ];
                            if (parts.isEmpty) return const SizedBox.shrink();
                            return Text(
                              'Pay tiers: ${parts.join(' · ')}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ],
                      if (overBalance) ...[
                        const Gap(AppSpacing.sm),
                        _Warn(AppStrings.overBalanceWarning.primary),
                      ],
                      if (overlap) ...[
                        const Gap(AppSpacing.sm),
                        _Warn(AppStrings.leaveOverlapWarning.primary),
                      ],
                      if (_error != null) ...[
                        const Gap(AppSpacing.sm),
                        Text(
                          _error!,
                          style: AppTypography.bodySmall.copyWith(color: AppColors.error),
                        ),
                      ],
                      const Gap(AppSpacing.xxl),
                      PrimaryButton(
                        label: AppStrings.requestLeave.primary,
                        icon: Icons.send_rounded,
                        isLoading: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                      const Gap(AppSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Warn extends StatelessWidget {
  const _Warn(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
        const Gap(AppSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}
