import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';

/// Full-screen modal for adding a new material to inventory.
class AddMaterialSheet extends ConsumerStatefulWidget {
  const AddMaterialSheet({super.key});

  @override
  ConsumerState<AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends ConsumerState<AddMaterialSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urduNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _minStockController = TextEditingController();
  MaterialCategory _category = MaterialCategory.valves;
  MaterialUnit _unit = MaterialUnit.pieces;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _urduNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0;

    await ref
        .read(materialsProvider.notifier)
        .addMaterial(
          name: _nameController.text.trim(),
          urduName: _urduNameController.text.trim(),
          category: _category,
          unit: _unit,
          quantity: qty,
          unitPrice: price,
          minStockLevel: minStock,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
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
              // ─── Drag Handle ─────────────────────────────
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

              // ─── Header ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.addNewMaterial.primary,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            AppStrings.addNewMaterial.secondary(lang),
                            style: AppTypography.bodySmall,
                            textDirection: lang.isRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        ],
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

              // ─── Form ────────────────────────────────────
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
                        // Material Name
                        LedgerTextField(
                          controller: _nameController,
                          label: AppStrings.materialName.primary,
                          urduHint: AppStrings.materialName.secondary(lang),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? AppStrings.fieldRequired.primary
                              : null,
                        ),
                        const Gap(AppSpacing.lg),

                        // Urdu/Secondary Name
                        LedgerTextField(
                          controller: _urduNameController,
                          label: AppStrings.materialNameUrdu.primary,
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.xl),

                        // Category
                        Text(
                          AppStrings.category.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(AppSpacing.sm),
                        _CategorySelector(
                          selected: _category,
                          onChanged: (c) => setState(() => _category = c),
                        ),
                        const Gap(AppSpacing.xl),

                        // Unit
                        Text(
                          AppStrings.unit.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(AppSpacing.sm),
                        _UnitSelector(
                          selected: _unit,
                          onChanged: (u) => setState(() => _unit = u),
                        ),
                        const Gap(AppSpacing.xl),

                        // Quantity + Price row
                        Row(
                          children: [
                            Expanded(
                              child: LedgerTextField(
                                controller: _quantityController,
                                label: AppStrings.quantity.primary,
                                hintText: '0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) {
                                  if ((v ?? '').trim().isEmpty) {
                                    return AppStrings.fieldRequired.primary;
                                  }
                                  if (double.tryParse(v!.trim()) == null) {
                                    return AppStrings.enterValidNumber.primary;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const Gap(AppSpacing.lg),
                            Expanded(
                              child: LedgerTextField(
                                controller: _priceController,
                                label: AppStrings.unitPrice.primary,
                                hintText: '0.00',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (v) {
                                  if ((v ?? '').trim().isEmpty) {
                                    return AppStrings.fieldRequired.primary;
                                  }
                                  if (double.tryParse(v!.trim()) == null) {
                                    return AppStrings.enterValidNumber.primary;
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.lg),

                        // Min stock level
                        LedgerTextField(
                          controller: _minStockController,
                          label: AppStrings.minStockLevel.primary,
                          hintText: AppStrings.optional.primary,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        const Gap(AppSpacing.xxl),

                        // Save button
                        PrimaryButton(
                          label: AppStrings.saveMaterial.primary,
                          icon: Icons.check_rounded,
                          isLoading: _saving,
                          onPressed: _saving ? null : _save,
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
}

// ─── Category Selector (Horizontal Wrap) ─────────────────────────
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({required this.selected, required this.onChanged});

  final MaterialCategory selected;
  final ValueChanged<MaterialCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: MaterialCategory.values.map((cat) {
        final isSelected = cat == selected;
        return InkWell(
          onTap: () => onChanged(cat),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryContainer.withValues(alpha: 0.15)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CategoryIcons.icon(cat),
                  size: 16,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const Gap(AppSpacing.xs),
                Text(
                  cat.label,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Unit Selector (Horizontal Wrap) ─────────────────────────────
class _UnitSelector extends StatelessWidget {
  const _UnitSelector({required this.selected, required this.onChanged});

  final MaterialUnit selected;
  final ValueChanged<MaterialUnit> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: MaterialUnit.values.map((unit) {
        final isSelected = unit == selected;
        return InkWell(
          onTap: () => onChanged(unit),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryContainer.withValues(alpha: 0.15)
                  : AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              '${unit.symbol} — ${unit.label}',
              style: AppTypography.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
