import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/rental_unit.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Add or edit a rental unit (procurement / admin). Pass [unit] to edit.
class AddUnitSheet extends ConsumerStatefulWidget {
  const AddUnitSheet({super.key, this.unit});

  final RentalUnit? unit;

  static Future<void> show(BuildContext context, {RentalUnit? unit}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddUnitSheet(unit: unit),
    );
  }

  @override
  ConsumerState<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<AddUnitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _rentController;
  late final TextEditingController _tenantController;
  late final TextEditingController _contactController;
  late final TextEditingController _notesController;
  late RentalType _type;
  late RentalStatus _status;
  DateTime? _leaseStart;
  DateTime? _leaseEnd;
  bool _busy = false;

  bool get _isEdit => widget.unit != null;

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
    _nameController = TextEditingController(text: u?.unitName ?? '');
    _locationController = TextEditingController(text: u?.location ?? '');
    _rentController = TextEditingController(
      text: u != null ? u.monthlyRentAED.toStringAsFixed(0) : '',
    );
    _tenantController = TextEditingController(text: u?.tenantName ?? '');
    _contactController = TextEditingController(text: u?.tenantContact ?? '');
    _notesController = TextEditingController(text: u?.notes ?? '');
    _type = u?.type ?? RentalType.shop;
    _status = u?.status ?? RentalStatus.vacant;
    _leaseStart = u?.leaseStart;
    _leaseEnd = u?.leaseEnd;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _rentController.dispose();
    _tenantController.dispose();
    _contactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final rent = double.parse(_rentController.text.trim());
    final tenant = _tenantController.text.trim();
    final contact = _contactController.text.trim();
    final notes = _notesController.text.trim();

    if (_isEdit) {
      final updated = RentalUnit(
        id: widget.unit!.id,
        unitName: name,
        type: _type,
        location: location,
        monthlyRentAED: rent,
        tenantName: tenant.isEmpty ? null : tenant,
        tenantContact: contact.isEmpty ? null : contact,
        leaseStart: _leaseStart,
        leaseEnd: _leaseEnd,
        status: _status,
        notes: notes.isEmpty ? null : notes,
        createdBy: widget.unit!.createdBy,
        createdAt: widget.unit!.createdAt,
      );
      await ref.read(rentalUnitsProvider.notifier).updateUnit(updated);
      await ref.logAudit(
        action: 'Rental unit updated',
        module: AuditModule.rentals,
        refId: updated.id,
        detail: '${updated.unitName} · ${updated.status.label}',
      );
    } else {
      final unit = await ref.read(rentalUnitsProvider.notifier).addUnit(
            unitName: name,
            type: _type,
            location: location,
            monthlyRentAED: rent,
            tenantName: tenant.isEmpty ? null : tenant,
            tenantContact: contact.isEmpty ? null : contact,
            leaseStart: _leaseStart,
            leaseEnd: _leaseEnd,
            notes: notes.isEmpty ? null : notes,
            createdBy: ref.read(actorNameProvider),
          );
      await ref.logAudit(
        action: 'Rental unit added',
        module: AuditModule.rentals,
        refId: unit.id,
        detail: '${unit.unitName} · ${unit.location}',
      );
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDate(bool start) async {
    final now = DateTime.now();
    final initial = (start ? _leaseStart : _leaseEnd) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 15),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _leaseStart = picked;
      } else {
        _leaseEnd = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
                        _isEdit
                            ? AppStrings.editUnit.primary
                            : AppStrings.addUnit.primary,
                        style: GoogleFonts.inter(
                          fontSize: 20,
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
              const Gap(AppSpacing.lg),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LedgerTextField(
                          controller: _nameController,
                          label: '${AppStrings.unitName.primary} *',
                          validator: _required,
                        ),
                        const Gap(AppSpacing.lg),
                        Text(
                          AppStrings.unitType.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(AppSpacing.sm),
                        Row(
                          children: [
                            for (final t in RentalType.values) ...[
                              _Chip(
                                label: t.label,
                                selected: _type == t,
                                onTap: () => setState(() => _type = t),
                              ),
                              const Gap(AppSpacing.sm),
                            ],
                          ],
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _locationController,
                          label: '${AppStrings.location.primary} *',
                          validator: _required,
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _rentController,
                          label: '${AppStrings.monthlyRent.primary} (AED) *',
                          hintText: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _positiveAmount,
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _tenantController,
                          label: AppStrings.tenant.primary,
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _contactController,
                          label: AppStrings.tenantContact.primary,
                          hintText: AppStrings.optional.primary,
                          keyboardType: TextInputType.phone,
                        ),
                        const Gap(AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: _DateField(
                                label: AppStrings.leaseStart.primary,
                                value: _leaseStart,
                                onTap: () => _pickDate(true),
                                onClear: () =>
                                    setState(() => _leaseStart = null),
                              ),
                            ),
                            const Gap(AppSpacing.lg),
                            Expanded(
                              child: _DateField(
                                label: AppStrings.leaseEnd.primary,
                                value: _leaseEnd,
                                onTap: () => _pickDate(false),
                                onClear: () => setState(() => _leaseEnd = null),
                              ),
                            ),
                          ],
                        ),
                        if (_isEdit) ...[
                          const Gap(AppSpacing.lg),
                          Text(
                            AppStrings.occupancy.primary,
                            style: AppTypography.titleSmall,
                          ),
                          const Gap(AppSpacing.sm),
                          Row(
                            children: [
                              for (final s in RentalStatus.values) ...[
                                _Chip(
                                  label: s.label,
                                  selected: _status == s,
                                  onTap: () => setState(() => _status = s),
                                ),
                                const Gap(AppSpacing.sm),
                              ],
                            ],
                          ),
                        ],
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _notesController,
                          label: AppStrings.notes.primary,
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.xxl),
                        PrimaryButton(
                          label: _isEdit
                              ? AppStrings.saveChanges.primary
                              : AppStrings.saveUnit.primary,
                          icon: Icons.check_rounded,
                          isLoading: _busy,
                          onPressed: _busy ? null : _save,
                        ),
                        const Gap(AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? AppStrings.fieldRequired.primary : null;

  String? _positiveAmount(String? v) {
    if ((v ?? '').trim().isEmpty) return AppStrings.fieldRequired.primary;
    final val = double.tryParse(v!.trim());
    if (val == null || val <= 0) return AppStrings.enterValidNumber.primary;
    return null;
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const Gap(AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const Gap(AppSpacing.sm),
                Expanded(
                  child: Text(
                    value == null
                        ? AppStrings.setDate.primary
                        : DateFormat('d MMM yyyy').format(value!),
                    style: AppTypography.bodyMedium.copyWith(
                      color: value == null
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (value != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
