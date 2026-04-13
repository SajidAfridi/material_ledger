import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/inventory_transaction.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';

/// Bottom sheet for recording a material transaction (in/out).
class RecordTransactionSheet extends ConsumerStatefulWidget {
  const RecordTransactionSheet({super.key, this.preselectedMaterial});

  /// If provided, the material is preselected and locked.
  final MaterialItem? preselectedMaterial;

  @override
  ConsumerState<RecordTransactionSheet> createState() =>
      _RecordTransactionSheetState();
}

class _RecordTransactionSheetState
    extends ConsumerState<RecordTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _type = TransactionType.incoming;
  MaterialItem? _selectedMaterial;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedMaterial = widget.preselectedMaterial;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedMaterial == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final qty = double.tryParse(_quantityController.text.trim()) ?? 0;
    final mat = _selectedMaterial!;

    // Check for outgoing stock
    if (_type == TransactionType.outgoing && qty > mat.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.insufficientStock.primary),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Record transaction
    await ref
        .read(transactionsProvider.notifier)
        .addTransaction(
          materialId: mat.id,
          materialName: mat.name,
          type: _type,
          quantity: qty,
          unitSymbol: mat.unit.symbol,
          notes: _notesController.text.trim(),
        );

    // Adjust stock
    final delta = _type == TransactionType.incoming ? qty : -qty;
    await ref.read(materialsProvider.notifier).adjustQuantity(mat.id, delta);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final materials = ref.watch(materialsProvider);
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
              // ─── Drag Handle ────────────────────────────
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

              // ─── Header ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.recordTransaction.primary,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Gap(AppSpacing.xxs),
                          Text(
                            AppStrings.recordTransaction.secondary(lang),
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
              const Gap(AppSpacing.xl),

              // ─── Form ───────────────────────────────────
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
                        // Transaction Type Toggle
                        _TypeToggle(
                          type: _type,
                          onChanged: (t) => setState(() => _type = t),
                        ),
                        const Gap(AppSpacing.xl),

                        // Material Selector
                        if (widget.preselectedMaterial == null) ...[
                          Text(
                            AppStrings.selectMaterial.primary,
                            style: AppTypography.titleSmall,
                          ),
                          const Gap(AppSpacing.sm),
                          _MaterialDropdown(
                            materials: materials,
                            selected: _selectedMaterial,
                            onChanged: (m) =>
                                setState(() => _selectedMaterial = m),
                          ),
                          const Gap(AppSpacing.xl),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xl,
                            ),
                            child: LedgerCard(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const Gap(AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.preselectedMaterial!.name,
                                          style: AppTypography.titleSmall,
                                        ),
                                        Text(
                                          'Available: ${widget.preselectedMaterial!.formattedQuantity}',
                                          style: AppTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Quantity
                        LedgerTextField(
                          controller: _quantityController,
                          label: AppStrings.quantity.primary,
                          hintText: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          suffixIcon: _selectedMaterial != null
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.md,
                                  ),
                                  child: Text(
                                    _selectedMaterial!.unit.symbol,
                                    style: AppTypography.labelMedium,
                                  ),
                                )
                              : null,
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
                        const Gap(AppSpacing.lg),

                        // Notes
                        LedgerTextField(
                          controller: _notesController,
                          label: AppStrings.notes.primary,
                          hintText: AppStrings.optional.primary,
                          maxLines: 3,
                        ),
                        const Gap(AppSpacing.xxl),

                        // Save
                        PrimaryButton(
                          label: AppStrings.record.primary,
                          icon: Icons.check_rounded,
                          isLoading: _saving,
                          onPressed: (_saving || _selectedMaterial == null)
                              ? null
                              : _save,
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

// ─── Transaction Type Toggle ─────────────────────────────────────
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final TransactionType type;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        children: TransactionType.values.map((t) {
          final isSelected = t == type;
          final isIncoming = t == TransactionType.incoming;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isIncoming
                            ? AppColors.successContainer.withValues(alpha: 0.3)
                            : AppColors.errorContainer.withValues(alpha: 0.3))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isIncoming
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 18,
                      color: isSelected
                          ? (isIncoming ? AppColors.success : AppColors.error)
                          : AppColors.onSurfaceVariant,
                    ),
                    const Gap(AppSpacing.xs),
                    Text(
                      t.label,
                      style: AppTypography.labelLarge.copyWith(
                        color: isSelected
                            ? (isIncoming ? AppColors.success : AppColors.error)
                            : AppColors.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Material Dropdown ───────────────────────────────────────────
class _MaterialDropdown extends StatelessWidget {
  const _MaterialDropdown({
    required this.materials,
    required this.selected,
    required this.onChanged,
  });

  final List<MaterialItem> materials;
  final MaterialItem? selected;
  final ValueChanged<MaterialItem> onChanged;

  @override
  Widget build(BuildContext context) {
    if (materials.isEmpty) {
      return LedgerCard(
        color: AppColors.surfaceContainerLow,
        child: Center(
          child: Text(
            AppStrings.noMaterialsAdded.primary,
            style: AppTypography.bodySmall,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusSm),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: selected?.id,
        isExpanded: true,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
        hint: Text(
          AppStrings.selectMaterial.primary,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        items: materials.map((m) {
          return DropdownMenuItem(
            value: m.id,
            child: Text(
              '${m.name} (${m.formattedQuantity})',
              style: AppTypography.bodyMedium,
            ),
          );
        }).toList(),
        onChanged: (id) {
          if (id == null) return;
          onChanged(materials.firstWhere((m) => m.id == id));
        },
      ),
    );
  }
}
