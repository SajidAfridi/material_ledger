import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/employee_record.dart';
import '../../../../shared/models/leave_record.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/sync/sync_indicators.dart';

/// Record approved leave for an employee (admin). Days are derived from the
/// date range; annual leave consumes the 30-day balance.
class RecordLeaveSheet extends ConsumerStatefulWidget {
  const RecordLeaveSheet({super.key, required this.employee});

  final Employee employee;

  static Future<void> show(BuildContext context, Employee employee) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordLeaveSheet(employee: employee),
    );
  }

  @override
  ConsumerState<RecordLeaveSheet> createState() => _RecordLeaveSheetState();
}

class _RecordLeaveSheetState extends ConsumerState<RecordLeaveSheet> {
  LeaveType _type = LeaveType.annual;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  bool _busy = false;

  int get _days => _end.difference(_start).inDays + 1;

  Future<void> _pick(bool isStart) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await ref
        .read(leaveRecordsProvider.notifier)
        .addLeave(
          employeeId: widget.employee.id,
          type: _type,
          startDate: _start,
          endDate: _end,
          status: LeaveRecordStatus.approved,
          approvedBy: ref.read(actorNameProvider),
        );
    await ref.logAudit(
      action: 'Leave recorded',
      module: AuditModule.people,
      refId: widget.employee.id,
      detail: '${widget.employee.fullName} · ${_type.label} · $_days day(s)',
    );
    if (!mounted) return;
    showSyncSnack(context, ref, savedLabel: AppStrings.leaveRecorded.primary);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusXl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AppStrings.recordLeave.primary} — ${widget.employee.fullName}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
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
              const Gap(AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final t in LeaveType.values)
                    _Chip(
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
                    child: _DateField(
                      label: AppStrings.leaveStart.primary,
                      value: _fmt(_start),
                      onTap: () => _pick(true),
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Expanded(
                    child: _DateField(
                      label: AppStrings.leaveEnd.primary,
                      value: _fmt(_end),
                      onTap: () => _pick(false),
                    ),
                  ),
                ],
              ),
              const Gap(AppSpacing.md),
              Text(
                '$_days day(s)',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Gap(AppSpacing.xl),
              PrimaryButton(
                label: AppStrings.recordLeave.primary,
                icon: Icons.check_rounded,
                isLoading: _busy,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Chip extends StatelessWidget {
  const _Chip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.primaryContainer.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: AppTypography.labelLarge.copyWith(
            color: selected ? AppColors.onPrimary : AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const Gap(AppSpacing.xxs),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const Gap(AppSpacing.xs),
                Text(value, style: AppTypography.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
