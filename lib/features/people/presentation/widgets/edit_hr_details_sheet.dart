import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/employee_record.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';

/// Admin-only editor for an employee's compensation + identity-document
/// details — the fields that drive the gratuity estimate and the document-
/// expiry alerts (visa / Emirates ID / passport). Without this sheet those
/// fields could never be set after onboarding.
class EditHrDetailsSheet extends ConsumerStatefulWidget {
  const EditHrDetailsSheet({super.key, required this.employee});

  final Employee employee;

  static Future<void> show(BuildContext context, Employee employee) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditHrDetailsSheet(employee: employee),
    );
  }

  @override
  ConsumerState<EditHrDetailsSheet> createState() => _EditHrDetailsSheetState();
}

class _EditHrDetailsSheetState extends ConsumerState<EditHrDetailsSheet> {
  final _df = DateFormat('d MMM yyyy');
  late final _salary = TextEditingController(
    text: widget.employee.salaryAED?.toStringAsFixed(0) ?? '',
  );
  late final _basicWage = TextEditingController(
    text: widget.employee.basicWageAED?.toStringAsFixed(0) ?? '',
  );
  late final _emiratesId = TextEditingController(text: widget.employee.emiratesId ?? '');
  late final _passportNo = TextEditingController(text: widget.employee.passportNo ?? '');
  late DateTime? _joinDate = widget.employee.joinDate;
  late DateTime? _visaExpiry = widget.employee.visaExpiry;
  late DateTime? _eidExpiry = widget.employee.emiratesIdExpiry;
  late DateTime? _passportExpiry = widget.employee.passportExpiry;
  bool _busy = false;

  @override
  void dispose() {
    _salary.dispose();
    _basicWage.dispose();
    _emiratesId.dispose();
    _passportNo.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? current) => showDatePicker(
        context: context,
        initialDate: current ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _save() async {
    setState(() => _busy = true);
    final updated = widget.employee.copyWith(
      salaryAED: double.tryParse(_salary.text.trim()),
      basicWageAED: double.tryParse(_basicWage.text.trim()),
      emiratesId: _emiratesId.text.trim().isEmpty ? null : _emiratesId.text.trim(),
      passportNo: _passportNo.text.trim().isEmpty ? null : _passportNo.text.trim(),
      joinDate: _joinDate,
      visaExpiry: _visaExpiry,
      emiratesIdExpiry: _eidExpiry,
      passportExpiry: _passportExpiry,
    );
    await ref.read(employeesProvider.notifier).updateEmployee(updated);
    await ref.logAudit(
      action: 'HR details updated',
      module: AuditModule.platform,
      refId: updated.id,
      detail: updated.fullName,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'HR details',
                        style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Gap(AppSpacing.lg),
                _DateRow(
                  label: 'Join date',
                  value: _joinDate,
                  df: _df,
                  onTap: () async {
                    final d = await _pick(_joinDate);
                    if (d != null) setState(() => _joinDate = d);
                  },
                ),
                const Gap(AppSpacing.lg),
                LedgerTextField(
                  controller: _salary,
                  label: 'Monthly salary AED',
                  keyboardType: TextInputType.number,
                ),
                const Gap(AppSpacing.lg),
                LedgerTextField(
                  controller: _basicWage,
                  label: 'Basic wage AED (for gratuity)',
                  keyboardType: TextInputType.number,
                ),
                const Gap(AppSpacing.xl),
                Text('Identity documents', style: AppTypography.titleSmall),
                const Gap(AppSpacing.md),
                LedgerTextField(controller: _emiratesId, label: 'Emirates ID number'),
                const Gap(AppSpacing.lg),
                _DateRow(
                  label: 'Emirates ID expiry',
                  value: _eidExpiry,
                  df: _df,
                  onTap: () async {
                    final d = await _pick(_eidExpiry);
                    if (d != null) setState(() => _eidExpiry = d);
                  },
                ),
                const Gap(AppSpacing.lg),
                LedgerTextField(controller: _passportNo, label: 'Passport number'),
                const Gap(AppSpacing.lg),
                _DateRow(
                  label: 'Passport expiry',
                  value: _passportExpiry,
                  df: _df,
                  onTap: () async {
                    final d = await _pick(_passportExpiry);
                    if (d != null) setState(() => _passportExpiry = d);
                  },
                ),
                const Gap(AppSpacing.lg),
                _DateRow(
                  label: 'Visa expiry',
                  value: _visaExpiry,
                  df: _df,
                  onTap: () async {
                    final d = await _pick(_visaExpiry);
                    if (d != null) setState(() => _visaExpiry = d);
                  },
                ),
                const Gap(AppSpacing.xxl),
                PrimaryButton(
                  label: 'Save',
                  icon: Icons.check_rounded,
                  isLoading: _busy,
                  isExpanded: true,
                  onPressed: _busy ? null : _save,
                ),
                const Gap(AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.df,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final DateFormat df;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outlineVariant),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
            Text(
              value == null ? 'Not set' : df.format(value!),
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(AppSpacing.xs),
            const Icon(Icons.calendar_today_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}
