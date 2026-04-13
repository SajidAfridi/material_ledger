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
import '../widgets/add_material_sheet.dart';
import '../../../transactions/presentation/widgets/record_transaction_sheet.dart';

/// Inventory — Material listing screen.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  void _openAddMaterial(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => const AddMaterialSheet(),
      ),
    );
  }

  void _openRecordTransaction(BuildContext context, MaterialItem material) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, controller) =>
            RecordTransactionSheet(preselectedMaterial: material),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final materials = ref.watch(materialsProvider);
    final currency = ref.watch(currencyProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Header ──────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BilingualText(
                    english: AppStrings.inventory.primary,
                    secondary: AppStrings.inventory.secondary(lang),
                    englishStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.28,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      if (materials.isNotEmpty)
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.search_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLowest,
                          ),
                        ),
                      const Gap(AppSpacing.xs),
                      IconButton(
                        onPressed: () => _openAddMaterial(context),
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Content ─────────────────────────────────────
          if (materials.isEmpty)
            _buildEmptyState(lang, context)
          else
            _buildMaterialList(materials, lang, currency, context, ref),

          // Bottom spacing
          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildEmptyState(dynamic lang, BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: LedgerCard(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.colossal,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 64,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const Gap(AppSpacing.xl),
                  BilingualText(
                    english: AppStrings.noMaterialsAdded.primary,
                    secondary: AppStrings.noMaterialsAdded.secondary(lang),
                    englishStyle: AppTypography.titleMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    crossAxisAlignment: CrossAxisAlignment.center,
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    AppStrings.tapToAddFirst.primary,
                    style: AppTypography.bodySmall,
                  ),
                  const Gap(AppSpacing.xxl),
                  PrimaryButton(
                    label: AppStrings.addMaterial.primary,
                    icon: Icons.add_rounded,
                    isExpanded: false,
                    onPressed: () => _openAddMaterial(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialList(
    List<MaterialItem> materials,
    dynamic lang,
    dynamic currency,
    BuildContext context,
    WidgetRef ref,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverList.separated(
        itemCount: materials.length,
        separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
        itemBuilder: (context, index) {
          final item = materials[index];
          return _MaterialCard(
            item: item,
            currency: currency,
            onTap: () => _openRecordTransaction(context, item),
            onDelete: () => _confirmDelete(context, ref, item),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MaterialItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        ),
        title: Text(
          AppStrings.delete.primary,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        content: Text(
          AppStrings.confirmDelete.primary,
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              AppStrings.cancel.primary,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppStrings.delete.primary,
              style: AppTypography.labelLarge.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(materialsProvider.notifier).deleteMaterial(item.id);
    }
  }
}

// ─── Material Card ───────────────────────────────────────────────
class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.item,
    required this.currency,
    required this.onTap,
    required this.onDelete,
  });

  final MaterialItem item;
  final dynamic currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusChip = switch (item.stockStatus) {
      StockStatus.inStock => StatusChip.success(AppStrings.inStock.primary),
      StockStatus.lowStock => StatusChip.warning(AppStrings.lowStock.primary),
      StockStatus.outOfStock => StatusChip.error(AppStrings.outOfStock.primary),
    };

    return LedgerCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  CategoryIcons.icon(item.category),
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTypography.titleSmall),
                    if (item.urduName.isNotEmpty) ...[
                      const Gap(AppSpacing.xxs),
                      Text(
                        item.urduName,
                        style: AppTypography.bodySmall,
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ],
                ),
              ),
              statusChip,
            ],
          ),
          const Gap(AppSpacing.lg),
          Row(
            children: [
              _StatBlock(
                label: AppStrings.quantity.primary,
                value: item.formattedQuantity,
              ),
              const Gap(AppSpacing.xxl),
              _StatBlock(
                label: AppStrings.unitPrice.primary,
                value: currency.format(item.unitPrice),
              ),
              const Gap(AppSpacing.xxl),
              _StatBlock(
                label: AppStrings.totalValue.primary,
                value: currency.format(item.totalValue),
                valueColor: AppColors.primary,
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: Text(AppStrings.recordTransaction.primary),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  textStyle: AppTypography.labelMedium,
                ),
              ),
              const Gap(AppSpacing.sm),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const Gap(AppSpacing.xxs),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: valueColor ?? AppColors.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
