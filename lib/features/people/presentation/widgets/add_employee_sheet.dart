import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/hr_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';

/// Onboard a new employee into the HR roster (gated by `writePeople`). Salary is
/// only shown/collected for users who may see it (`canSeeSalary` → admin).
class AddEmployeeSheet extends ConsumerStatefulWidget {
  const AddEmployeeSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddEmployeeSheet(),
    );
  }

  @override
  ConsumerState<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends ConsumerState<AddEmployeeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _dept = TextEditingController();
  final _nationality = TextEditingController();
  final _contact = TextEditingController();
  final _salary = TextEditingController();
  final _basicWage = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _dept.dispose();
    _nationality.dispose();
    _contact.dispose();
    _salary.dispose();
    _basicWage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final emp = await ref.read(employeesProvider.notifier).addEmployee(
            fullName: _name.text.trim(),
            jobRole: _role.text.trim(),
            department: _dept.text.trim(),
            nationality: _nationality.text.trim(),
            contact: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
            salaryAED: double.tryParse(_salary.text.trim()),
            basicWageAED: double.tryParse(_basicWage.text.trim()),
          );
      await ref.logAudit(
        action: 'Employee added',
        module: AuditModule.platform,
        refId: emp.id,
        detail: '${emp.fullName} · ${emp.jobRole}',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? AppStrings.fieldRequired.primary : null;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSeeSalary = ref.watch(canSeeSalaryProvider);
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
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Add employee',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
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
                  LedgerTextField(
                    controller: _name,
                    label: AppStrings.fullName.primary,
                    validator: _required,
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _role,
                    label: 'Job role',
                    validator: _required,
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _dept,
                    label: 'Department',
                    validator: _required,
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _nationality,
                    label: 'Nationality',
                    validator: _required,
                  ),
                  const Gap(AppSpacing.lg),
                  LedgerTextField(
                    controller: _contact,
                    label: 'Contact (optional)',
                    keyboardType: TextInputType.phone,
                  ),
                  if (canSeeSalary) ...[
                    const Gap(AppSpacing.lg),
                    LedgerTextField(
                      controller: _salary,
                      label: 'Monthly salary AED (optional)',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null; // optional
                        final n = double.tryParse(t);
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        if (n > 1000000) return 'Amount looks too large';
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.lg),
                    LedgerTextField(
                      controller: _basicWage,
                      label: 'Basic wage AED (optional — for gratuity)',
                      hintText: 'Excludes allowances; used for EOSB estimate',
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null; // optional
                        final n = double.tryParse(t);
                        if (n == null || n <= 0) return 'Enter a valid amount';
                        if (n > 1000000) return 'Amount looks too large';
                        return null;
                      },
                    ),
                  ],
                  const Gap(AppSpacing.xxl),
                  PrimaryButton(
                    label: 'Add employee',
                    icon: Icons.person_add_alt_1_rounded,
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
      ),
    );
  }
}
