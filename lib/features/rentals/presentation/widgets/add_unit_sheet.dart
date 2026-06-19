import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/audit_log.dart';
import '../../../../shared/models/rental_unit.dart';
import '../../../../shared/providers/audit_log_provider.dart';
import '../../../../shared/providers/rentals_provider.dart';
import '../../../../shared/providers/session_provider.dart';

/// Add a rental unit (procurement / admin).
class AddUnitSheet extends ConsumerStatefulWidget {
  const AddUnitSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddUnitSheet(),
    );
  }

  @override
  ConsumerState<AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<AddUnitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _rentController = TextEditingController();
  final _tenantController = TextEditingController();
  final _contactController = TextEditingController();
  RentalType _type = RentalType.shop;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _rentController.dispose();
    _tenantController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final tenant = _tenantController.text.trim();
    final unit = await ref
        .read(rentalUnitsProvider.notifier)
        .addUnit(
          unitName: _nameController.text.trim(),
          type: _type,
          location: _locationController.text.trim(),
          monthlyRentAED: double.parse(_rentController.text.trim()),
          tenantName: tenant.isEmpty ? null : tenant,
          tenantContact: _contactController.text.trim().isEmpty
              ? null
              : _contactController.text.trim(),
          createdBy: ref.read(actorNameProvider),
        );
    await ref.logAudit(
      action: 'Rental unit added',
      module: AuditModule.rentals,
      refId: unit.id,
      detail: '${unit.unitName} · ${unit.location}',
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
                        AppStrings.addUnit.primary,
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
                          label: AppStrings.unitName.primary,
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
                              _TypeChip(
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
                          label: AppStrings.location.primary,
                          validator: _required,
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _rentController,
                          label: '${AppStrings.monthlyRent.primary} (AED)',
                          hintText: '0.00',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty) {
                              return AppStrings.fieldRequired.primary;
                            }
                            final val = double.tryParse(v!.trim());
                            if (val == null || val <= 0) {
                              return AppStrings.enterValidNumber.primary;
                            }
                            return null;
                          },
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
                        const Gap(AppSpacing.xxl),
                        PrimaryButton(
                          label: AppStrings.saveUnit.primary,
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
