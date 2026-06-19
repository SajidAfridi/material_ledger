import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_item.dart';

/// Bottom sheet to pick a material from inventory (FR-035/FR-050/FR-051).
/// Returns the chosen [MaterialItem], or null if dismissed.
class InventoryPickerSheet extends StatefulWidget {
  const InventoryPickerSheet({super.key, required this.materials});

  final List<MaterialItem> materials;

  static Future<MaterialItem?> show(
    BuildContext context,
    List<MaterialItem> materials,
  ) {
    return showModalBottomSheet<MaterialItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryPickerSheet(materials: materials),
    );
  }

  @override
  State<InventoryPickerSheet> createState() => _InventoryPickerSheetState();
}

class _InventoryPickerSheetState extends State<InventoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase().trim();
    final filtered = q.isEmpty
        ? widget.materials
        : widget.materials
              .where(
                (m) =>
                    m.name.toLowerCase().contains(q) ||
                    m.urduName.toLowerCase().contains(q) ||
                    m.category.label.toLowerCase().contains(q),
              )
              .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        child: Column(
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
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.addFromInventory.primary,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: AppStrings.searchParameters.primary,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            const Gap(AppSpacing.md),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.sm,
                  AppSpacing.xxl,
                  AppSpacing.xxl,
                ),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
                itemBuilder: (context, i) {
                  final m = filtered[i];
                  return LedgerCard(
                    color: AppColors.surfaceContainerLowest,
                    onTap: () => Navigator.pop(context, m),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.name,
                                style: AppTypography.titleSmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Gap(2),
                              Text(
                                '${m.category.label} · ${m.formattedQuantity} ${m.unit.symbol}',
                                style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppSpacing.md),
                        _StockBadge(status: m.stockStatus),
                        const Gap(AppSpacing.sm),
                        const Icon(
                          Icons.add_circle_rounded,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.status});

  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      StockStatus.inStock => StatusChip.success(AppStrings.inStock.primary),
      StockStatus.lowStock => StatusChip.warning(AppStrings.lowStock.primary),
      StockStatus.outOfStock => StatusChip.error(AppStrings.outOfStock.primary),
    };
  }
}
