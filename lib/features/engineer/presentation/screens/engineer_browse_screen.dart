import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/app_strings.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/project.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/project_provider.dart';

/// Browse Materials screen — full material catalog.
///
/// Mobile: vertical card list.
/// Web/Tablet (≥840): hero stats + category filters + data table + pagination.
class EngineerBrowseScreen extends ConsumerWidget {
  const EngineerBrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final allMaterials = ref.watch(materialsProvider);
    final filteredMaterials = ref.watch(browseMaterialsProvider);
    final paginated = ref.watch(paginatedBrowseMaterialsProvider);
    final currentPage = ref.watch(browsePageProvider);
    final totalPages = ref.watch(browseTotalPagesProvider);
    final categoryFilter = ref.watch(browseCategoryFilterProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = screenWidth >= 840;

    final activeCategories = allMaterials.map((m) => m.category).toSet().length;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // ─── Hero Stats ─────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.xxl,
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: _HeroStatsSection(
                totalItems: allMaterials.length,
                activeCategories: activeCategories,
                isWide: isWide,
                lang: lang,
              ),
            ),
          ),

          // ─── Search Bar ───────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: _SearchBar(
                isWide: isWide,
                onChanged: (query) {
                  ref.read(browseSearchQueryProvider.notifier).state = query;
                  ref.read(browsePageProvider.notifier).state = 0;
                },
              ),
            ),
          ),

          const SliverGap(AppSpacing.lg),

          // ─── Category Filter Tabs ───────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            sliver: SliverToBoxAdapter(
              child: _CategoryFilters(
                selected: categoryFilter,
                onChanged: (f) {
                  ref.read(browseCategoryFilterProvider.notifier).state = f;
                  ref.read(browsePageProvider.notifier).state = 0;
                },
                lang: lang,
                totalCount: filteredMaterials.length,
                isWide: isWide,
              ),
            ),
          ),

          const SliverGap(AppSpacing.lg),

          // ─── Material List / Table ──────────────────────
          if (isWide)
            _buildDataTable(context, ref, paginated, lang)
          else
            _buildCardList(context, ref, paginated, lang),

          // ─── Pagination ─────────────────────────────────
          if (filteredMaterials.length > browsePageSize)
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.xxl,
              ),
              sliver: SliverToBoxAdapter(
                child: _Pagination(
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPageChanged: (p) =>
                      ref.read(browsePageProvider.notifier).state = p,
                ),
              ),
            ),

          const SliverGap(AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    WidgetRef ref,
    List<MaterialItem> items,
    AppLanguage lang,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: LedgerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Table header
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.xl,
                  AppSpacing.xxl,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: BilingualText(
                        english: AppStrings.materialName.primary,
                        secondary: AppStrings.materialName.secondary(lang),
                        englishStyle: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: BilingualText(
                        english: AppStrings.category.primary.toUpperCase(),
                        secondary: AppStrings.category.secondary(lang),
                        englishStyle: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: BilingualText(
                        english: AppStrings.stockLevel.primary,
                        secondary: AppStrings.stockLevel.secondary(lang),
                        englishStyle: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: BilingualText(
                        english: AppStrings.unit.primary.toUpperCase(),
                        secondary: AppStrings.unit.secondary(lang),
                        englishStyle: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: BilingualText(
                        english: AppStrings.actions.primary,
                        secondary: AppStrings.actions.secondary(lang),
                        englishStyle: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurfaceVariant,
                        ),
                        crossAxisAlignment: CrossAxisAlignment.end,
                      ),
                    ),
                  ],
                ),
              ),
              ...items.map(
                (item) => _MaterialTableRow(
                  item: item,
                  lang: lang,
                  onAddToRequest: () => _addToRequest(ref, item),
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.colossal),
                  child: Text(
                    AppStrings.noMaterialsAdded.primary,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardList(
    BuildContext context,
    WidgetRef ref,
    List<MaterialItem> items,
    AppLanguage lang,
  ) {
    if (items.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        sliver: SliverToBoxAdapter(
          child: Center(
            child: LedgerCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.colossal),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                    ),
                    const Gap(AppSpacing.xl),
                    Text(
                      AppStrings.noMaterialsAdded.primary,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Gap(AppSpacing.listItemGap),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MaterialCard(
            item: item,
            lang: lang,
            onAddToRequest: () => _addToRequest(ref, item),
          );
        },
      ),
    );
  }

  void _addToRequest(WidgetRef ref, MaterialItem item) {
    ref
        .read(draftLineItemsProvider.notifier)
        .addItem(
          RequestLineItem(
            materialId: item.id,
            materialName: item.name,
            materialNameSecondary: item.urduName,
            quantity: 1,
            unitSymbol: item.unit.symbol,
          ),
        );
    ScaffoldMessenger.of(ref.context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to request'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SEARCH BAR
// ═══════════════════════════════════════════════════════════════════

class _SearchBar extends StatefulWidget {
  const _SearchBar({required this.isWide, required this.onChanged});
  final bool isWide;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: widget.isWide
            ? AppTypography.bodyLarge
            : AppTypography.bodyMedium,
        decoration: InputDecoration(
          hintText: AppStrings.searchInventory.primary,
          hintStyle:
              (widget.isWide
                      ? AppTypography.bodyLarge
                      : AppTypography.bodyMedium)
                  .copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.onSurfaceVariant,
            size: 22,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.onSurfaceVariant,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// HERO STATS
// ═══════════════════════════════════════════════════════════════════

class _HeroStatsSection extends StatelessWidget {
  const _HeroStatsSection({
    required this.totalItems,
    required this.activeCategories,
    required this.isWide,
    required this.lang,
  });

  final int totalItems;
  final int activeCategories;
  final bool isWide;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: _buildTotalItemsCard()),
          const Gap(AppSpacing.lg),
          Expanded(flex: 1, child: _buildCategoriesCard()),
        ],
      );
    }
    // Mobile: horizontal row with total + categories side by side
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildTotalItemsCard()),
        const Gap(AppSpacing.md),
        Expanded(flex: 1, child: _buildCategoriesCard()),
      ],
    );
  }

  Widget _buildTotalItemsCard() {
    return LedgerCard(
      color: AppColors.surfaceContainerLow,
      padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  totalItems.toString().replaceAllMapped(
                    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
                    (m) => '${m[1]},',
                  ),
                  style: AppTypography.displayLarge.copyWith(
                    fontSize: isWide ? 56 : 32,
                  ),
                ),
                const Gap(AppSpacing.xs),
                BilingualText(
                  english: AppStrings.totalItemsInStock.primary,
                  secondary: AppStrings.totalItemsInStock.secondary(lang),
                  englishStyle: isWide
                      ? AppTypography.titleMedium
                      : AppTypography.titleSmall,
                ),
                Gap(isWide ? AppSpacing.md : AppSpacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? AppSpacing.md : AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const Gap(AppSpacing.xs),
                      Flexible(
                        child: Text(
                          '+12% ${AppStrings.thisMonth.primary}',
                          style: AppTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isWide ? 12 : 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isWide) ...[
            const Gap(AppSpacing.xxl),
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: AppColors.onSurfaceVariant.withValues(alpha: 0.12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesCard() {
    return Container(
      padding: EdgeInsets.all(isWide ? AppSpacing.xxl : AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.categories.primary.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: isWide ? 12 : 10,
            ),
          ),
          const Gap(AppSpacing.sm),
          Icon(
            Icons.category_rounded,
            color: AppColors.onPrimary.withValues(alpha: 0.5),
            size: isWide ? 28 : 22,
          ),
          const Gap(AppSpacing.sm),
          Text(
            '$activeCategories ${AppStrings.activeCategories.primary}',
            style: GoogleFonts.inter(
              fontSize: isWide ? 28 : 20,
              fontWeight: FontWeight.w700,
              color: AppColors.onPrimary,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            AppStrings.activeCategories.secondary(lang),
            style: TextStyle(
              fontSize: isWide ? 13 : 11,
              color: AppColors.onPrimary.withValues(alpha: 0.7),
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CATEGORY FILTERS
// ═══════════════════════════════════════════════════════════════════

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.selected,
    required this.onChanged,
    required this.lang,
    required this.totalCount,
    required this.isWide,
  });

  final BrowseCategoryFilter selected;
  final ValueChanged<BrowseCategoryFilter> onChanged;
  final AppLanguage lang;
  final int totalCount;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: isWide
                      ? '${AppStrings.allMaterials.primary} | ${AppStrings.allMaterials.secondary(lang)}'
                      : AppStrings.allMaterials.primary,
                  icon: Icons.filter_list_rounded,
                  isSelected: selected == BrowseCategoryFilter.all,
                  onTap: () => onChanged(BrowseCategoryFilter.all),
                  isCompact: !isWide,
                ),
                Gap(isWide ? AppSpacing.md : AppSpacing.sm),
                _CategoryChip(
                  label: isWide
                      ? '${AppStrings.valvesFittings.primary} | ${AppStrings.valvesFittings.secondary(lang)}'
                      : AppStrings.valvesFittings.primary,
                  isSelected: selected == BrowseCategoryFilter.valvesFittings,
                  onTap: () => onChanged(BrowseCategoryFilter.valvesFittings),
                  isCompact: !isWide,
                ),
                Gap(isWide ? AppSpacing.md : AppSpacing.sm),
                _CategoryChip(
                  label: isWide
                      ? '${AppStrings.pipesDucts.primary} | ${AppStrings.pipesDucts.secondary(lang)}'
                      : AppStrings.pipesDucts.primary,
                  isSelected: selected == BrowseCategoryFilter.pipesDucts,
                  onTap: () => onChanged(BrowseCategoryFilter.pipesDucts),
                  isCompact: !isWide,
                ),
                Gap(isWide ? AppSpacing.md : AppSpacing.sm),
                _CategoryChip(
                  label: isWide
                      ? '${AppStrings.fastenersTools.primary} | ${AppStrings.fastenersTools.secondary(lang)}'
                      : AppStrings.fastenersTools.primary,
                  isSelected: selected == BrowseCategoryFilter.fasteners,
                  onTap: () => onChanged(BrowseCategoryFilter.fasteners),
                  isCompact: !isWide,
                ),
              ],
            ),
          ),
        ),
        if (isWide) ...[
          const Gap(AppSpacing.lg),
          Text(
            '${AppStrings.showing.primary} 1-${totalCount.clamp(0, browsePageSize)} ${AppStrings.of_.primary} $totalCount',
            style: AppTypography.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    this.isCompact = false,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? AppSpacing.md : AppSpacing.xl,
            vertical: isCompact ? AppSpacing.sm : AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: isCompact ? 14 : 16,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
                Gap(isCompact ? AppSpacing.xs : AppSpacing.sm),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 11 : 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// TABLE ROW (Wide)
// ═══════════════════════════════════════════════════════════════════

class _MaterialTableRow extends StatelessWidget {
  const _MaterialTableRow({
    required this.item,
    required this.lang,
    required this.onAddToRequest,
  });

  final MaterialItem item;
  final AppLanguage lang;
  final VoidCallback onAddToRequest;

  @override
  Widget build(BuildContext context) {
    final maxCapacity = item.minStockLevel > 0
        ? item.minStockLevel * 4
        : 2000.0;
    final stockPct = (item.quantity / maxCapacity * 100).clamp(0, 100).toInt();

    final statusChip = switch (item.stockStatus) {
      StockStatus.inStock => StatusChip.success(AppStrings.healthy.primary),
      StockStatus.lowStock => StatusChip.error(
        AppStrings.lowStock.primary.toUpperCase(),
      ),
      StockStatus.outOfStock => StatusChip.error(
        AppStrings.outOfStock.primary.toUpperCase(),
      ),
    };

    final categoryLabel = switch (item.category) {
      MaterialCategory.valves => 'Valves',
      MaterialCategory.pipes => 'Piping',
      MaterialCategory.fittings || MaterialCategory.copper => 'Fittings',
      MaterialCategory.fasteners => 'Fasteners',
      MaterialCategory.ducts => 'Ductwork',
      MaterialCategory.insulation => 'Insulation',
      MaterialCategory.electrical => 'Controls',
      _ => item.category.label,
    };

    final progressColor = item.stockStatus == StockStatus.inStock
        ? AppColors.primary
        : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Material Name
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    size: 20,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
                const Gap(AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.urduName.isNotEmpty)
                        Text(
                          item.urduName,
                          style: AppTypography.bodySmall.copyWith(fontSize: 11),
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Category
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  categoryLabel,
                  style: AppTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          // Stock Level
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$stockPct%',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(AppSpacing.sm),
                    statusChip,
                  ],
                ),
                const Gap(AppSpacing.xs),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: stockPct / 100,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      color: progressColor,
                      minHeight: 5,
                    ),
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  '${item.quantity.toStringAsFixed(0)} ${item.unit.label} ${AppStrings.remaining.primary}',
                  style: AppTypography.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          // Unit
          Expanded(
            flex: 1,
            child: Text(
              '${item.unit.label}\n(${item.unit.symbol})',
              style: AppTypography.bodyMedium,
            ),
          ),
          // Action
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: _AddToRequestButton(onTap: onAddToRequest, lang: lang),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// MOBILE CARD
// ═══════════════════════════════════════════════════════════════════

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.item,
    required this.lang,
    required this.onAddToRequest,
  });

  final MaterialItem item;
  final AppLanguage lang;
  final VoidCallback onAddToRequest;

  @override
  Widget build(BuildContext context) {
    final maxCapacity = item.minStockLevel > 0
        ? item.minStockLevel * 4
        : 2000.0;
    final stockPct = (item.quantity / maxCapacity * 100).clamp(0, 100).toInt();

    final statusChip = switch (item.stockStatus) {
      StockStatus.inStock => StatusChip.success(AppStrings.healthy.primary),
      StockStatus.lowStock => StatusChip.error(
        AppStrings.lowStock.primary.toUpperCase(),
      ),
      StockStatus.outOfStock => StatusChip.error(
        AppStrings.outOfStock.primary.toUpperCase(),
      ),
    };

    final progressColor = item.stockStatus == StockStatus.inStock
        ? AppColors.primary
        : AppColors.error;

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 20,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTypography.titleSmall),
                    if (item.urduName.isNotEmpty)
                      Text(
                        item.urduName,
                        style: AppTypography.bodySmall,
                        textDirection: TextDirection.rtl,
                      ),
                  ],
                ),
              ),
              statusChip,
            ],
          ),
          const Gap(AppSpacing.lg),
          Row(
            children: [
              Text(
                '$stockPct%',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(AppSpacing.md),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  child: LinearProgressIndicator(
                    value: stockPct / 100,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    color: progressColor,
                    minHeight: 5,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.xs),
          Text(
            '${item.quantity.toStringAsFixed(0)} ${item.unit.label} ${AppStrings.remaining.primary}',
            style: AppTypography.bodySmall,
          ),
          const Gap(AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.unit.label} (${item.unit.symbol})',
                style: AppTypography.bodySmall,
              ),
              _AddToRequestButton(onTap: onAddToRequest, lang: lang),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADD TO REQUEST BUTTON
// ═══════════════════════════════════════════════════════════════════

class _AddToRequestButton extends StatelessWidget {
  const _AddToRequestButton({required this.onTap, required this.lang});
  final VoidCallback onTap;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_shopping_cart_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const Gap(AppSpacing.xs),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to\nRequest',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                  Text(
                    AppStrings.addToRequest
                        .secondary(lang)
                        .replaceAll('\n', ' '),
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGINATION
// ═══════════════════════════════════════════════════════════════════

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 840;
    final maxVisiblePages = isCompact ? 3 : 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PaginationArrow(
          label: isCompact ? '' : AppStrings.previous.primary,
          icon: Icons.chevron_left_rounded,
          isLeading: true,
          enabled: currentPage > 0,
          onTap: () => onPageChanged(currentPage - 1),
        ),
        Gap(isCompact ? AppSpacing.sm : AppSpacing.lg),
        ...List.generate(totalPages.clamp(0, maxVisiblePages), (i) {
          final isActive = i == currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onPageChanged(i),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Container(
                  width: isCompact ? 32 : 36,
                  height: isCompact ? 32 : 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        if (totalPages > maxVisiblePages) ...[
          const Gap(AppSpacing.xs),
          Text('...', style: AppTypography.bodySmall),
          const Gap(AppSpacing.xs),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onPageChanged(totalPages - 1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: Container(
                width: isCompact ? 32 : 36,
                height: isCompact ? 32 : 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '$totalPages',
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
        Gap(isCompact ? AppSpacing.sm : AppSpacing.lg),
        _PaginationArrow(
          label: isCompact ? '' : AppStrings.next.primary,
          icon: Icons.chevron_right_rounded,
          isLeading: false,
          enabled: currentPage < totalPages - 1,
          onTap: () => onPageChanged(currentPage + 1),
        ),
      ],
    );
  }
}

class _PaginationArrow extends StatelessWidget {
  const _PaginationArrow({
    required this.label,
    required this.icon,
    required this.isLeading,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isLeading;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.onSurface : AppColors.onSurfaceVariant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLeading) Icon(icon, size: 18, color: color),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (!isLeading) Icon(icon, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
