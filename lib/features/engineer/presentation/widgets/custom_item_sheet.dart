import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_plan.dart';

/// Bottom sheet to create a custom (non-inventory) item with the full SRS
/// spec, including the RAL colour required for grilles/dampers (FR-018/FR-054).
/// Returns a [PlanItem] (isCustom = true) or null if dismissed.
class CustomItemSheet extends StatefulWidget {
  const CustomItemSheet({super.key});

  static Future<PlanItem?> show(BuildContext context) {
    return showModalBottomSheet<PlanItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CustomItemSheet(),
    );
  }

  @override
  State<CustomItemSheet> createState() => _CustomItemSheetState();
}

class _CustomItemSheetState extends State<CustomItemSheet> {
  static const _uuid = Uuid();
  static const _ralOptions = <(String, Color)>[
    ('RAL 9006', Color(0xFFA5A5A5)),
    ('RAL 9010', Color(0xFFFFFFFF)),
    ('RAL 9005', Color(0xFF0A0A0A)),
    ('RAL 7035', Color(0xFFD7D7D7)),
  ];

  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _brand = TextEditingController();
  final _origin = TextEditingController();
  final _size = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'nos');
  final _note = TextEditingController();
  String _ral = '';

  @override
  void dispose() {
    for (final c in [
      _description,
      _brand,
      _origin,
      _size,
      _qty,
      _unit,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      PlanItem(
        id: 'pi-${_uuid.v4().substring(0, 6)}',
        description: _description.text.trim(),
        brand: _brand.text.trim(),
        countryOfOrigin: _origin.text.trim(),
        size: _size.text.trim(),
        quantity: double.tryParse(_qty.text.trim()) ?? 1,
        unitSymbol: _unit.text.trim().isEmpty ? 'nos' : _unit.text.trim(),
        ralColour: _ral,
        isCustom: true,
        note: _note.text.trim(),
      ),
    );
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.customItem.primary,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl,
                    AppSpacing.md,
                    AppSpacing.xxl,
                    AppSpacing.xxl,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LedgerTextField(
                          controller: _description,
                          label: AppStrings.description.primary,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? AppStrings.fieldRequired.primary
                              : null,
                        ),
                        const Gap(AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: LedgerTextField(
                                controller: _brand,
                                label: AppStrings.brand.primary,
                                hintText: AppStrings.optional.primary,
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            Expanded(
                              child: LedgerTextField(
                                controller: _origin,
                                label: AppStrings.countryOfOrigin.primary,
                                hintText: AppStrings.optional.primary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: LedgerTextField(
                                controller: _size,
                                label: AppStrings.sizeLabel.primary,
                                validator: (v) => (v ?? '').trim().isEmpty
                                    ? AppStrings.fieldRequired.primary
                                    : null,
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            Expanded(
                              child: LedgerTextField(
                                controller: _qty,
                                label: AppStrings.quantity.primary,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final n = double.tryParse((v ?? '').trim());
                                  if (n == null || n <= 0) {
                                    return AppStrings.fieldRequired.primary;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const Gap(AppSpacing.md),
                            Expanded(
                              child: LedgerTextField(
                                controller: _unit,
                                label: AppStrings.unit.primary,
                              ),
                            ),
                          ],
                        ),
                        const Gap(AppSpacing.xl),
                        Text(
                          AppStrings.ralColour.primary,
                          style: AppTypography.titleSmall,
                        ),
                        const Gap(2),
                        Text(
                          AppStrings.ralColourHint.primary,
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const Gap(AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            for (final (label, color) in _ralOptions)
                              _RalChip(
                                label: label,
                                color: color,
                                selected: _ral == label,
                                onTap: () => setState(
                                  () => _ral = _ral == label ? '' : label,
                                ),
                              ),
                          ],
                        ),
                        const Gap(AppSpacing.xl),
                        LedgerTextField(
                          controller: _note,
                          label: AppStrings.notes.primary,
                          hintText: AppStrings.optional.primary,
                          maxLines: 2,
                        ),
                        const Gap(AppSpacing.xxl),
                        PrimaryButton(
                          label: AppStrings.addToPlan.primary,
                          icon: Icons.add_rounded,
                          onPressed: _submit,
                        ),
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

class _RalChip extends StatelessWidget {
  const _RalChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryContainer.withValues(alpha: 0.12)
          : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
              ),
              const Gap(AppSpacing.sm),
              Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color: selected ? AppColors.primary : AppColors.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
