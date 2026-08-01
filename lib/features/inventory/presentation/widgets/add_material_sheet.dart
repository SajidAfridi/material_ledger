import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_master.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/nexus_feature_flags_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';

/// Full-screen modal for adding or editing a material in inventory.
class AddMaterialSheet extends ConsumerStatefulWidget {
  const AddMaterialSheet({super.key, this.material});

  final MaterialItem? material;

  @override
  ConsumerState<AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends ConsumerState<AddMaterialSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _urduNameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _minStockController;
  late final TextEditingController _brandController;
  late final TextEditingController _countryController;
  late final TextEditingController _sizeController;
  late final TextEditingController _ralController;
  late MaterialCategory _category;
  late MaterialUnit _unit;
  late String _categoryMasterId;
  late String _unitMasterId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.material;
    _nameController = TextEditingController(text: item?.name);
    _urduNameController = TextEditingController(text: item?.urduName);
    _quantityController = TextEditingController(
      text: item == null
          ? ''
          : item.quantity.toStringAsFixed(
              item.quantity.truncateToDouble() == item.quantity ? 0 : 2,
            ),
    );
    _priceController = TextEditingController(
      text: item == null
          ? ''
          : item.unitPrice == 0
          ? ''
          : item.unitPrice.toStringAsFixed(2),
    );
    _minStockController = TextEditingController(
      text: item == null
          ? ''
          : item.minStockLevel == 0
          ? ''
          : item.minStockLevel.toStringAsFixed(0),
    );
    _brandController = TextEditingController(text: item?.brand);
    _countryController = TextEditingController(text: item?.countryOfOrigin);
    _sizeController = TextEditingController(text: item?.size);
    _ralController = TextEditingController(text: item?.ralColour);
    _category = item?.category ?? MaterialCategory.airInletOutlet;
    _unit = item?.unit ?? MaterialUnit.pieces;
    _categoryMasterId = item?.categoryMasterId ?? 'cat-air-terminals';
    _unitMasterId = item?.unitMasterId ?? 'unit-nos';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urduNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _minStockController.dispose();
    _brandController.dispose();
    _countryController.dispose();
    _sizeController.dispose();
    _ralController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final canViewCommercials = ref.read(canViewCommercialsProvider);
    final price = canViewCommercials
        ? double.tryParse(_priceController.text.trim()) ?? 0
        : null;
    final minStock = double.tryParse(_minStockController.text.trim()) ?? 0;

    final brand = _brandController.text.trim();
    final country = _countryController.text.trim();
    final size = _sizeController.text.trim();
    final ral = _ralController.text.trim();
    final mastersEnabled = ref.read(nexusFeatureFlagsProvider).browseMaterials;
    final selectedUnit = ref
        .read(materialUnitsProvider)
        .where((value) => value.id == _unitMasterId)
        .firstOrNull;
    if (mastersEnabled) {
      _category = MaterialCategory.fromLabel(
        legacyCategoryLabelForMasterId(_categoryMasterId),
      );
      _unit = MaterialUnit.fromSymbol(
        legacyUnitSymbolForMasterId(
          _unitMasterId,
          fallback: selectedUnit?.symbol ?? _unit.symbol,
        ),
      );
    }

    if (widget.material != null) {
      final updated = widget.material!.copyWith(
        name: _nameController.text.trim(),
        urduName: _urduNameController.text.trim(),
        category: _category,
        unit: _unit,
        categoryMasterId: mastersEnabled ? _categoryMasterId : null,
        unitMasterId: mastersEnabled ? _unitMasterId : null,
        minStockLevel: minStock,
        brand: brand,
        countryOfOrigin: country,
        size: size,
        ralColour: ral,
      );
      await ref
          .read(materialsProvider.notifier)
          .updateMaterial(updated, unitCostAED: price);
    } else {
      final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
      await ref
          .read(materialsProvider.notifier)
          .addMaterial(
            name: _nameController.text.trim(),
            urduName: _urduNameController.text.trim(),
            category: _category,
            unit: _unit,
            categoryMasterId: mastersEnabled ? _categoryMasterId : null,
            unitMasterId: mastersEnabled ? _unitMasterId : null,
            quantity: qty,
            unitPrice: price ?? 0,
            minStockLevel: minStock,
            brand: brand,
            countryOfOrigin: country,
            size: size,
            ralColour: ral,
          );
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _addCustomUnit() async {
    final name = TextEditingController();
    final symbol = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Unit name'),
            ),
            TextField(
              controller: symbol,
              decoration: const InputDecoration(labelText: 'Symbol'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true ||
        name.text.trim().isEmpty ||
        symbol.text.trim().isEmpty) {
      return;
    }
    final id = await ref
        .read(materialUnitsProvider.notifier)
        .add(name: name.text, symbol: symbol.text);
    final unit = ref
        .read(materialUnitsProvider)
        .where((value) => value.id == id)
        .firstOrNull;
    if (!mounted) return;
    if (unit?.isSelectable == true) {
      setState(() => _unitMasterId = id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom unit sent to Admin for approval.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final canViewCommercials = ref.watch(canViewCommercialsProvider);
    final mastersEnabled = ref.watch(nexusFeatureFlagsProvider).browseMaterials;
    final categories = ref.watch(activeMaterialCategoriesProvider);
    final units = ref.watch(selectableMaterialUnitsProvider);
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
                            widget.material != null
                                ? AppStrings.editMaterial.primary
                                : AppStrings.addNewMaterial.primary,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            widget.material != null
                                ? AppStrings.editMaterial.secondary(lang)
                                : AppStrings.addNewMaterial.secondary(lang),
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
                        if (mastersEnabled)
                          DropdownButtonFormField<String>(
                            initialValue:
                                categories.any(
                                  (value) => value.id == _categoryMasterId,
                                )
                                ? _categoryMasterId
                                : categories.firstOrNull?.id,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final category in categories)
                                DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _categoryMasterId = value);
                              }
                            },
                          )
                        else
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
                        if (mastersEnabled)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue:
                                    units.any(
                                      (value) => value.id == _unitMasterId,
                                    )
                                    ? _unitMasterId
                                    : units.firstOrNull?.id,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (final unit in units)
                                    DropdownMenuItem(
                                      value: unit.id,
                                      child: Text(
                                        '${unit.symbol} — ${unit.name}',
                                      ),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _unitMasterId = value);
                                  }
                                },
                              ),
                              TextButton.icon(
                                onPressed: _addCustomUnit,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Custom unit…'),
                              ),
                            ],
                          )
                        else
                          _UnitSelector(
                            selected: _unit,
                            onChanged: (u) => setState(() => _unit = u),
                          ),
                        const Gap(AppSpacing.xl),

                        // ─── Stock details (Air Inlet & Outlet spec) ──
                        Text(
                          AppStrings.stockDetails.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(AppSpacing.sm),
                        LedgerTextField(
                          controller: _brandController,
                          label: AppStrings.brandSupplier.primary,
                          hintText: AppStrings.optional.primary,
                        ),
                        const Gap(AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: LedgerTextField(
                                controller: _countryController,
                                label: AppStrings.countryOfOrigin.primary,
                                hintText: AppStrings.optional.primary,
                              ),
                            ),
                            const Gap(AppSpacing.lg),
                            Expanded(
                              child: LedgerTextField(
                                controller: _sizeController,
                                label: AppStrings.sizeLabel.primary,
                                hintText: AppStrings.optional.primary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.lg),
                        LedgerTextField(
                          controller: _ralController,
                          label: AppStrings.ralColour.primary,
                          hintText: 'RAL 9010',
                        ),
                        const Gap(AppSpacing.xl),

                        // Note: quantity not editable here — use Record Transaction
                        if (widget.material != null) ...[
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMd,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                                const Gap(AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    'To adjust stock quantity, use Record Transaction.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Gap(AppSpacing.xl),
                        ],

                        // Quantity + protected Unit Price. Engineers can create
                        // operational catalogue rows without ever receiving or
                        // submitting a commercial field.
                        if (widget.material == null || canViewCommercials) ...[
                          Row(
                            children: [
                              if (widget.material == null) ...[
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
                                      final val = double.tryParse(v!.trim());
                                      // 0 is allowed (an unstocked item), but
                                      // guard negatives and fat-finger values.
                                      if (val == null || val < 0) {
                                        return AppStrings
                                            .enterValidNumber
                                            .primary;
                                      }
                                      if (val > 1000000) return 'Too large';
                                      return null;
                                    },
                                  ),
                                ),
                                if (canViewCommercials)
                                  const Gap(AppSpacing.lg),
                              ],
                              if (canViewCommercials)
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
                                      final val = double.tryParse(v!.trim());
                                      if (val == null || val < 0) {
                                        return AppStrings
                                            .enterValidNumber
                                            .primary;
                                      }
                                      if (val > 1000000) return 'Too large';
                                      return null;
                                    },
                                  ),
                                ),
                            ],
                          ),
                          const Gap(AppSpacing.lg),
                        ],

                        // Min stock level
                        LedgerTextField(
                          controller: _minStockController,
                          label: AppStrings.minStockLevel.primary,
                          hintText: AppStrings.optional.primary,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            if (v != null && v.trim().isNotEmpty) {
                              final val = double.tryParse(v.trim());
                              if (val == null || val < 0) {
                                return AppStrings.enterValidNumber.primary;
                              }
                            }
                            return null;
                          },
                        ),
                        const Gap(AppSpacing.xxl),

                        // Save button
                        PrimaryButton(
                          label: widget.material != null
                              ? AppStrings.saveChanges.primary
                              : AppStrings.saveMaterial.primary,
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
