import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/constants.dart';
import '../../../../shared/controllers/yorks_v1_inventory_import_controller.dart';
import '../../../../shared/models/app_language.dart';
import '../../../../shared/models/yorks_v1_inventory_strings.dart';
import '../../../../shared/models/yorks_v1_inventory_workbook.dart';
import '../../../../shared/models/yorks_v1_logistics.dart';
import '../../../../shared/models/yorks_v1_logistics_strings.dart';
import '../../../../shared/providers/language_provider.dart';
import '../../../../shared/providers/yorks_v1_inventory_workbook_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_provider.dart';
import '../../../../shared/providers/yorks_v1_logistics_repository_provider.dart';

enum _WarehouseTab { overview, items, movements, reservations }

enum _StockFilter { all, healthy, low, out }

/// R38.3 warehouse workspace. All content comes from the role-safe logistics
/// projection and every mutation remains repository/RPC backed.
class YorksV1InventoryScreen extends ConsumerStatefulWidget {
  const YorksV1InventoryScreen({super.key});

  @override
  ConsumerState<YorksV1InventoryScreen> createState() =>
      _YorksV1InventoryScreenState();
}

class _YorksV1InventoryScreenState
    extends ConsumerState<YorksV1InventoryScreen> {
  _WarehouseTab _tab = _WarehouseTab.overview;
  _StockFilter _filter = _StockFilter.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final workspace = ref.watch(yorksV1InventoryWorkspaceProvider(null));
    final compact =
        MediaQuery.sizeOf(context).width <
        AppSpacing.yorksV1ShellDesktopBreakpoint;
    return Scaffold(
      backgroundColor: compact ? AppColors.mobileSurface : AppColors.surface,
      body: SafeArea(
        top: false,
        child: workspace.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _StateMessage(
            icon: Icons.cloud_off_rounded,
            message: YorksV1InventoryStrings.savingFailed.active(language),
            action: YorksV1LogisticsStrings.refresh.active(language),
            onAction: _refresh,
          ),
          data: (value) => _WarehouseBody(
            workspace: value,
            language: language,
            tab: _tab,
            filter: _filter,
            search: _search,
            onTab: (value) => setState(() => _tab = value),
            onFilter: (value) => setState(() => _filter = value),
            onSearch: (value) => setState(() => _search = value.trim()),
            onRefresh: _refresh,
            onAdd: () => _openAdjustment(value),
            onImport: () => _openImport(value),
            onDownload: () => _downloadTemplate(language),
            onExport: () => _export(value, language),
            onCategories: () => _openCategories(value),
            onItem: _openItem,
          ),
        ),
      ),
    );
  }

  void _refresh() => ref.invalidate(yorksV1InventoryWorkspaceProvider(null));

  Future<void> _openAdjustment(YorksV1InventoryWorkspace workspace) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _InventoryAdjustmentDialog(
        workspace: workspace,
        onCommitted: _refresh,
      ),
    );
  }

  Future<void> _openImport(YorksV1InventoryWorkspace workspace) async {
    ref.read(yorksV1InventoryImportControllerProvider.notifier).reset();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _InventoryImportDialog(workspace: workspace, onCommitted: _refresh),
    );
  }

  Future<void> _downloadTemplate(AppLanguage language) async {
    final saved = await ref
        .read(yorksV1InventoryWorkbookFileServiceProvider)
        .saveImportTemplate();
    if (mounted && saved) {
      _notice(YorksV1InventoryStrings.downloadFormat.active(language));
    }
  }

  Future<void> _export(
    YorksV1InventoryWorkspace workspace,
    AppLanguage language,
  ) async {
    final saved = await ref
        .read(yorksV1InventoryWorkbookFileServiceProvider)
        .saveStockRegister(
          workspace: workspace,
          suggestedName: 'Yorks_Warehouse_Stock_Register.csv',
        );
    if (mounted && saved) {
      _notice(YorksV1InventoryStrings.exportRegister.active(language));
    }
  }

  Future<void> _openCategories(YorksV1InventoryWorkspace workspace) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CategoriesDialog(
        categories: workspace.categories,
        onCommitted: _refresh,
      ),
    );
  }

  Future<void> _openItem(YorksV1LogisticsInventoryItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      builder: (_) => _InventoryItemDetailSheet(
        inventoryItemId: item.id,
        onChanged: _refresh,
      ),
    );
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _WarehouseBody extends StatelessWidget {
  const _WarehouseBody({
    required this.workspace,
    required this.language,
    required this.tab,
    required this.filter,
    required this.search,
    required this.onTab,
    required this.onFilter,
    required this.onSearch,
    required this.onRefresh,
    required this.onAdd,
    required this.onImport,
    required this.onDownload,
    required this.onExport,
    required this.onCategories,
    required this.onItem,
  });

  final YorksV1InventoryWorkspace workspace;
  final AppLanguage language;
  final _WarehouseTab tab;
  final _StockFilter filter;
  final String search;
  final ValueChanged<_WarehouseTab> onTab;
  final ValueChanged<_StockFilter> onFilter;
  final ValueChanged<String> onSearch;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onDownload;
  final VoidCallback onExport;
  final VoidCallback onCategories;
  final ValueChanged<YorksV1LogisticsInventoryItem> onItem;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <
        AppSpacing.yorksV1ShellDesktopBreakpoint;
    final pagePadding = compact
        ? AppSpacing.mobileScreenHorizontal
        : AppSpacing.screenHorizontal;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            compact ? AppSpacing.lg : AppSpacing.xxl,
            pagePadding,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSpacing.pageMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WarehouseHeader(
                    language: language,
                    compact: compact,
                    onRefresh: onRefresh,
                    onAdd: onAdd,
                    onImport: onImport,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _WarehouseTabs(
                    selected: tab,
                    language: language,
                    onSelected: onTab,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  switch (tab) {
                    _WarehouseTab.overview => _OverviewTab(
                      workspace: workspace,
                      language: language,
                      onAdd: onAdd,
                      onImport: onImport,
                      onDownload: onDownload,
                      onExport: onExport,
                      onCategories: onCategories,
                      onItem: onItem,
                    ),
                    _WarehouseTab.items => _ItemsTab(
                      workspace: workspace,
                      language: language,
                      filter: filter,
                      search: search,
                      onFilter: onFilter,
                      onSearch: onSearch,
                      onItem: onItem,
                    ),
                    _WarehouseTab.movements => _MovementsTab(
                      movements: workspace.recentMovements,
                      language: language,
                    ),
                    _WarehouseTab.reservations => _ReservationsTab(
                      reservations: workspace.reservations,
                      language: language,
                    ),
                  },
                  SizedBox(height: compact ? 112 : AppSpacing.massive),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WarehouseHeader extends StatelessWidget {
  const _WarehouseHeader({
    required this.language,
    required this.compact,
    required this.onRefresh,
    required this.onAdd,
    required this.onImport,
  });

  final AppLanguage language;
  final bool compact;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              YorksV1InventoryStrings.warehouse.active(language),
              style:
                  (compact
                          ? AppTypography.headlineMedium
                          : AppTypography.displaySmall)
                      .copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              YorksV1InventoryStrings.subtitle.active(language),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      if (!compact) ...[
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: Text(YorksV1LogisticsStrings.refresh.active(language)),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.upload_file_rounded, size: 18),
          label: Text(YorksV1InventoryStrings.importInventory.active(language)),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(YorksV1InventoryStrings.addReceive.active(language)),
        ),
      ] else
        IconButton.filled(
          tooltip: YorksV1InventoryStrings.addReceive.active(language),
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
        ),
    ],
  );
}

class _WarehouseTabs extends StatelessWidget {
  const _WarehouseTabs({
    required this.selected,
    required this.language,
    required this.onSelected,
  });

  final _WarehouseTab selected;
  final AppLanguage language;
  final ValueChanged<_WarehouseTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final labels = {
      _WarehouseTab.overview: YorksV1InventoryStrings.overview,
      _WarehouseTab.items: YorksV1InventoryStrings.items,
      _WarehouseTab.movements: YorksV1InventoryStrings.movements,
      _WarehouseTab.reservations: YorksV1InventoryStrings.reservations,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            for (final value in _WarehouseTab.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                child: _TabButton(
                  label: labels[value]!.active(language),
                  selected: value == selected,
                  onPressed: () => onSelected(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.navy : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? Colors.white : AppColors.inkSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.workspace,
    required this.language,
    required this.onAdd,
    required this.onImport,
    required this.onDownload,
    required this.onExport,
    required this.onCategories,
    required this.onItem,
  });

  final YorksV1InventoryWorkspace workspace;
  final AppLanguage language;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onDownload;
  final VoidCallback onExport;
  final VoidCallback onCategories;
  final ValueChanged<YorksV1LogisticsInventoryItem> onItem;

  @override
  Widget build(BuildContext context) {
    final stocked = workspace.items
        .where(
          (item) =>
              item.isActive &&
              (double.tryParse(item.availableQuantity) ?? 0) > 0,
        )
        .length;
    final attention = workspace.items
        .where(
          (item) => item.isActive && (item.isLowStock || item.isOutOfStock),
        )
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 560
                ? 2
                : 2;
            final width =
                (constraints.maxWidth - (columns - 1) * AppSpacing.md) /
                columns;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                _MetricCard(
                  width: width,
                  icon: Icons.inventory_2_outlined,
                  label: YorksV1InventoryStrings.totalItems.active(language),
                  value: '${workspace.summary.totalActiveItems}',
                  tone: AppColors.blue,
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.check_circle_outline_rounded,
                  label: YorksV1InventoryStrings.availableStock.active(
                    language,
                  ),
                  value: '$stocked',
                  tone: AppColors.success,
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.lock_clock_outlined,
                  label: YorksV1InventoryStrings.reservedStock.active(language),
                  value: '${workspace.summary.reservedCount}',
                  tone: AppColors.purple,
                ),
                _MetricCard(
                  width: width,
                  icon: Icons.warning_amber_rounded,
                  label: YorksV1InventoryStrings.needsAttention.active(
                    language,
                  ),
                  value: '${workspace.summary.attentionCount}',
                  tone: AppColors.warning,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _TrustCard(language: language),
        const SizedBox(height: AppSpacing.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final attentionCard = _Panel(
              title: YorksV1InventoryStrings.needsAttention.active(language),
              icon: Icons.warning_amber_rounded,
              child: attention.isEmpty
                  ? _InlineEmpty(
                      message: YorksV1InventoryStrings.healthy.active(language),
                    )
                  : Column(
                      children: [
                        for (final item in attention.take(5))
                          _AttentionRow(item: item, onTap: () => onItem(item)),
                      ],
                    ),
            );
            final tools = _Panel(
              title: YorksV1InventoryStrings.quickTools.active(language),
              icon: Icons.bolt_rounded,
              child: _QuickTools(
                language: language,
                onAdd: onAdd,
                onImport: onImport,
                onDownload: onDownload,
                onExport: onExport,
                onCategories: onCategories,
              ),
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: attentionCard),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(flex: 4, child: tools),
                    ],
                  )
                : Column(
                    children: [
                      attentionCard,
                      const SizedBox(height: AppSpacing.lg),
                      tools,
                    ],
                  );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _CategoryCoverage(workspace: workspace, language: language),
        const SizedBox(height: AppSpacing.xl),
        _Panel(
          title: YorksV1InventoryStrings.recentActivity.active(language),
          icon: Icons.history_rounded,
          child: workspace.recentMovements.isEmpty
              ? _InlineEmpty(
                  message: YorksV1InventoryStrings.noMovements.active(language),
                )
              : Column(
                  children: [
                    for (final movement in workspace.recentMovements.take(6))
                      _MovementTile(movement: movement),
                  ],
                ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });
  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: _Surface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: tone, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(value, style: AppTypography.headlineSmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({required this.language});
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AppColors.blueContainer,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      border: Border.all(color: AppColors.blueContainerStrong),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.blue),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  YorksV1InventoryStrings.stockFormula.active(language),
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  YorksV1InventoryStrings.formulaHelp.active(language),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.blue),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.titleMedium)),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(AppSpacing.lg), child: child),
      ],
    ),
  );
}

class _QuickTools extends StatelessWidget {
  const _QuickTools({
    required this.language,
    required this.onAdd,
    required this.onImport,
    required this.onDownload,
    required this.onExport,
    required this.onCategories,
  });
  final AppLanguage language;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onDownload;
  final VoidCallback onExport;
  final VoidCallback onCategories;

  @override
  Widget build(BuildContext context) {
    final tools = [
      (
        Icons.add_box_outlined,
        YorksV1InventoryStrings.addReceive.active(language),
        onAdd,
      ),
      (
        Icons.upload_file_rounded,
        YorksV1InventoryStrings.importInventory.active(language),
        onImport,
      ),
      (
        Icons.download_rounded,
        YorksV1InventoryStrings.downloadFormat.active(language),
        onDownload,
      ),
      (
        Icons.file_download_outlined,
        YorksV1InventoryStrings.exportRegister.active(language),
        onExport,
      ),
      (
        Icons.category_outlined,
        YorksV1InventoryStrings.manageCategories.active(language),
        onCategories,
      ),
    ];
    return Column(
      children: [
        for (final tool in tools)
          ListTile(
            minTileHeight: AppSpacing.minTapTarget,
            contentPadding: EdgeInsets.zero,
            leading: Icon(tool.$1, color: AppColors.navy),
            title: Text(
              tool.$2,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: tool.$3,
          ),
      ],
    );
  }
}

class _CategoryCoverage extends StatelessWidget {
  const _CategoryCoverage({required this.workspace, required this.language});
  final YorksV1InventoryWorkspace workspace;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final maxItems = math.max(
      1,
      workspace.categories.fold<int>(
        0,
        (best, category) => math.max(best, category.itemCount),
      ),
    );
    return _Panel(
      title: YorksV1InventoryStrings.categoryCoverage.active(language),
      icon: Icons.donut_large_rounded,
      child: Column(
        children: [
          for (final category in workspace.categories)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${category.itemCount}',
                        style: AppTypography.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: category.itemCount / maxItems,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    backgroundColor: AppColors.surfaceContainerHighest,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});
  final YorksV1LogisticsInventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 58,
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: item.isOutOfStock
          ? AppColors.errorContainer
          : AppColors.warningContainer,
      child: Icon(
        item.isOutOfStock
            ? Icons.remove_shopping_cart_outlined
            : Icons.warning_amber_rounded,
        color: item.isOutOfStock ? AppColors.error : AppColors.warning,
      ),
    ),
    title: Text(
      item.description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleSmall,
    ),
    subtitle: Text(
      '${_quantity(item.availableQuantity)} ${item.unit} · ${item.locationBin ?? '—'}',
      style: AppTypography.bodySmall,
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.workspace,
    required this.language,
    required this.filter,
    required this.search,
    required this.onFilter,
    required this.onSearch,
    required this.onItem,
  });
  final YorksV1InventoryWorkspace workspace;
  final AppLanguage language;
  final _StockFilter filter;
  final String search;
  final ValueChanged<_StockFilter> onFilter;
  final ValueChanged<String> onSearch;
  final ValueChanged<YorksV1LogisticsInventoryItem> onItem;

  @override
  Widget build(BuildContext context) {
    final key = search.toLowerCase();
    final items = workspace.items
        .where((item) {
          final filterMatch = switch (filter) {
            _StockFilter.all => true,
            _StockFilter.healthy => !item.isLowStock && !item.isOutOfStock,
            _StockFilter.low => item.isLowStock,
            _StockFilter.out => item.isOutOfStock,
          };
          final haystack =
              '${item.itemCode ?? ''} ${item.description} ${item.categoryName ?? ''} ${item.locationBin ?? ''}'
                  .toLowerCase();
          return filterMatch && (key.isEmpty || haystack.contains(key));
        })
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: YorksV1InventoryStrings.search.active(language),
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.line),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: YorksV1InventoryStrings.allStock.active(language),
                selected: filter == _StockFilter.all,
                onTap: () => onFilter(_StockFilter.all),
              ),
              _FilterChip(
                label: YorksV1InventoryStrings.healthy.active(language),
                selected: filter == _StockFilter.healthy,
                onTap: () => onFilter(_StockFilter.healthy),
              ),
              _FilterChip(
                label: YorksV1InventoryStrings.lowStock.active(language),
                selected: filter == _StockFilter.low,
                onTap: () => onFilter(_StockFilter.low),
              ),
              _FilterChip(
                label: YorksV1InventoryStrings.outOfStock.active(language),
                selected: filter == _StockFilter.out,
                onTap: () => onFilter(_StockFilter.out),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (items.isEmpty)
          _StateMessage(
            icon: Icons.inventory_2_outlined,
            message: YorksV1InventoryStrings.noItems.active(language),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= AppSpacing.yorksV1DesktopBreakpoint
                ? _InventoryTable(
                    items: items,
                    language: language,
                    onItem: onItem,
                  )
                : Column(
                    children: [
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _InventoryCard(
                            item: item,
                            language: language,
                            onTap: () => onItem(item),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    ),
  );
}

class _InventoryTable extends StatelessWidget {
  const _InventoryTable({
    required this.items,
    required this.language,
    required this.onItem,
  });
  final List<YorksV1LogisticsInventoryItem> items;
  final AppLanguage language;
  final ValueChanged<YorksV1LogisticsInventoryItem> onItem;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _InventoryTableRow(language: language),
        const Divider(height: 1),
        for (final item in items) ...[
          _InventoryTableRow(
            language: language,
            item: item,
            onTap: () => onItem(item),
          ),
          if (item != items.last) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _InventoryTableRow extends StatelessWidget {
  const _InventoryTableRow({required this.language, this.item, this.onTap});
  final AppLanguage language;
  final YorksV1LogisticsInventoryItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final header = item == null;
    Widget cell(String text, int flex, {TextAlign? align}) => Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: header ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        textAlign: align,
        style: header
            ? AppTypography.labelMedium
            : AppTypography.bodyMedium.copyWith(
                fontWeight: flex == 4 ? FontWeight.w700 : FontWeight.w400,
              ),
      ),
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: header
            ? [
                cell(YorksV1InventoryStrings.itemCode.active(language), 2),
                cell(
                  YorksV1LogisticsStrings.itemDescription.active(language),
                  4,
                ),
                cell(YorksV1InventoryStrings.category.active(language), 3),
                cell(
                  YorksV1LogisticsStrings.onHand.active(language),
                  2,
                  align: TextAlign.end,
                ),
                cell(
                  YorksV1LogisticsStrings.reserved.active(language),
                  2,
                  align: TextAlign.end,
                ),
                cell(
                  YorksV1LogisticsStrings.available.active(language),
                  2,
                  align: TextAlign.end,
                ),
                cell(YorksV1InventoryStrings.location.active(language), 2),
              ]
            : [
                cell(item!.itemCode ?? '—', 2),
                cell(item!.description, 4),
                cell(
                  item!.categoryName ??
                      YorksV1InventoryStrings.uncategorized.active(language),
                  3,
                ),
                cell(
                  '${_quantity(item!.onHandQuantity)} ${item!.unit}',
                  2,
                  align: TextAlign.end,
                ),
                cell(
                  '${_quantity(item!.reservedQuantity)} ${item!.unit}',
                  2,
                  align: TextAlign.end,
                ),
                cell(
                  '${_quantity(item!.availableQuantity)} ${item!.unit}',
                  2,
                  align: TextAlign.end,
                ),
                cell(item!.locationBin ?? '—', 2),
              ],
      ),
    );
    return header
        ? ColoredBox(color: AppColors.surfaceContainerLow, child: content)
        : InkWell(onTap: onTap, child: content);
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({
    required this.item,
    required this.language,
    required this.onTap,
  });
  final YorksV1LogisticsInventoryItem item;
  final AppLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium,
                  ),
                ),
                _StockBadge(item: item, language: language),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${item.itemCode ?? '—'} · ${item.categoryName ?? YorksV1InventoryStrings.uncategorized.active(language)}',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.onHand.active(language),
                    value: '${_quantity(item.onHandQuantity)} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.reserved.active(language),
                    value: '${_quantity(item.reservedQuantity)} ${item.unit}',
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: YorksV1LogisticsStrings.available.active(language),
                    value: '${_quantity(item.availableQuantity)} ${item.unit}',
                  ),
                ),
              ],
            ),
            if (item.locationBin != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.locationBin!,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.item, required this.language});
  final YorksV1LogisticsInventoryItem item;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final (label, color, surface) = item.isOutOfStock
        ? (
            YorksV1InventoryStrings.outOfStock.active(language),
            AppColors.error,
            AppColors.errorContainer,
          )
        : item.isLowStock
        ? (
            YorksV1InventoryStrings.lowStock.active(language),
            AppColors.warning,
            AppColors.warningContainer,
          )
        : (
            YorksV1InventoryStrings.healthy.active(language),
            AppColors.success,
            AppColors.successContainer,
          );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _MovementsTab extends StatelessWidget {
  const _MovementsTab({required this.movements, required this.language});
  final List<YorksV1InventoryMovement> movements;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => movements.isEmpty
      ? _StateMessage(
          icon: Icons.history_rounded,
          message: YorksV1InventoryStrings.noMovements.active(language),
        )
      : _Surface(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              for (final movement in movements)
                _MovementTile(movement: movement),
            ],
          ),
        );
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});
  final YorksV1InventoryMovement movement;

  @override
  Widget build(BuildContext context) {
    final negative = movement.quantityDelta.startsWith('-');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: negative
                ? AppColors.errorContainer
                : AppColors.successContainer,
            child: Icon(
              negative ? Icons.north_east_rounded : Icons.south_west_rounded,
              size: 18,
              color: negative ? AppColors.error : AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.itemDescription ?? movement.reason,
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${movement.reason} · ${movement.actorDisplayName}',
                  style: AppTypography.bodySmall,
                ),
                Text(
                  _dateTime(movement.createdAt),
                  style: AppTypography.labelSmall,
                ),
              ],
            ),
          ),
          Text(
            '${negative ? '' : '+'}${_quantity(movement.quantityDelta)} ${movement.unit ?? ''}',
            style: AppTypography.titleSmall.copyWith(
              color: negative ? AppColors.error : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationsTab extends StatelessWidget {
  const _ReservationsTab({required this.reservations, required this.language});
  final List<YorksV1InventoryReservation> reservations;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) => reservations.isEmpty
      ? _StateMessage(
          icon: Icons.lock_clock_outlined,
          message: YorksV1InventoryStrings.noReservations.active(language),
        )
      : Column(
          children: [
            for (final reservation in reservations)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reservation.itemDescription,
                              style: AppTypography.titleMedium,
                            ),
                          ),
                          Text(
                            '${_quantity(reservation.remainingQuantity)} ${reservation.unit}',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${reservation.requestNumber} · ${reservation.projectName}',
                        style: AppTypography.bodyMedium,
                      ),
                      Text(
                        reservation.scopeName,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
}

class _InventoryAdjustmentDialog extends ConsumerStatefulWidget {
  const _InventoryAdjustmentDialog({
    required this.workspace,
    required this.onCommitted,
    this.inventoryItem,
  });
  final YorksV1InventoryWorkspace workspace;
  final VoidCallback onCommitted;
  final YorksV1LogisticsInventoryItem? inventoryItem;

  @override
  ConsumerState<_InventoryAdjustmentDialog> createState() =>
      _InventoryAdjustmentDialogState();
}

class _InventoryAdjustmentDialogState
    extends ConsumerState<_InventoryAdjustmentDialog> {
  final _description = TextEditingController();
  final _itemCode = TextEditingController();
  final _brand = TextEditingController();
  final _minimum = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  String _unit = 'Nos';
  String? _categoryId;
  bool _newCategory = false;
  final _newCategoryName = TextEditingController();
  bool _remove = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _description,
      _itemCode,
      _brand,
      _minimum,
      _location,
      _notes,
      _quantity,
      _reason,
      _newCategoryName,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final compact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.inventoryItem == null) ...[
            _Input(
              controller: _description,
              label: YorksV1LogisticsStrings.itemDescription.active(language),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _itemCode,
                    label: YorksV1InventoryStrings.itemCode.active(language),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Input(
                    controller: _brand,
                    label: YorksV1LogisticsStrings.brandOrigin.active(language),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _unit,
              decoration: InputDecoration(
                labelText: YorksV1LogisticsStrings.unit.active(language),
                border: const OutlineInputBorder(),
              ),
              items:
                  const [
                        'Nos',
                        'Meter',
                        'Cm',
                        'Length',
                        'Set',
                        'Pairs',
                        'Roll',
                        'Box',
                      ]
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _unit = value ?? 'Nos'),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_newCategory)
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: YorksV1InventoryStrings.category.active(language),
                  border: const OutlineInputBorder(),
                ),
                items: widget.workspace.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _categoryId = value),
              )
            else
              _Input(
                controller: _newCategoryName,
                label: YorksV1InventoryStrings.categoryName.active(language),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _newCategory,
              title: Text(
                YorksV1InventoryStrings.newCategory.active(language),
                style: AppTypography.bodyMedium,
              ),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _newCategory = value ?? false),
            ),
            Row(
              children: [
                Expanded(
                  child: _Input(
                    controller: _minimum,
                    label: YorksV1InventoryStrings.minimumStock.active(
                      language,
                    ),
                    numeric: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _Input(
                    controller: _location,
                    label: YorksV1InventoryStrings.location.active(language),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _Input(
              controller: _notes,
              label: YorksV1InventoryStrings.notes.active(language),
              lines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
          ] else ...[
            Text(
              widget.inventoryItem!.description,
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(
                    YorksV1InventoryStrings.addStock.active(language),
                  ),
                  icon: const Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    YorksV1InventoryStrings.removeStock.active(language),
                  ),
                  icon: const Icon(Icons.remove_rounded),
                ),
              ],
              selected: {_remove},
              onSelectionChanged: _saving
                  ? null
                  : (value) => setState(() => _remove = value.first),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _Input(
            controller: _quantity,
            label: YorksV1InventoryStrings.stockQuantity.active(language),
            numeric: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _Input(
            controller: _reason,
            label: YorksV1LogisticsStrings.reason.active(language),
            lines: 2,
          ),
        ],
      ),
    );
    final actions = Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(YorksV1InventoryStrings.addReceive.active(language)),
          ),
        ],
      ),
    );
    final body = PopScope(
      canPop: !_saving,
      child: Column(
        children: [
          _DialogHeader(
            title: YorksV1InventoryStrings.addReceive.active(language),
            onClose: _saving ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(child: content),
          const Divider(height: 1),
          actions,
        ],
      ),
    );
    if (compact) return Dialog.fullscreen(child: SafeArea(child: body));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: SizedBox(
        width: 680,
        height: math.min(760, MediaQuery.sizeOf(context).height - 48),
        child: body,
      ),
    );
  }

  Future<void> _save() async {
    final quantity = double.tryParse(_quantity.text.trim());
    final newItem = widget.inventoryItem == null;
    if (quantity == null ||
        quantity <= 0 ||
        _reason.text.trim().isEmpty ||
        (newItem &&
            (_description.text.trim().isEmpty ||
                (!_newCategory && _categoryId == null) ||
                (_newCategory && _newCategoryName.text.trim().isEmpty)))) {
      _failure();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .adjustInventory(
            YorksV1InventoryAdjustmentInput(
              inventoryItemId: widget.inventoryItem?.id,
              description: newItem ? _description.text : null,
              itemCode: newItem ? _itemCode.text : null,
              brandOrigin: newItem ? _brand.text : null,
              unit: newItem ? _unit : null,
              categoryId: newItem && !_newCategory ? _categoryId : null,
              newCategoryName: newItem && _newCategory
                  ? _newCategoryName.text
                  : null,
              sourceCategoryText: newItem && _newCategory
                  ? _newCategoryName.text
                  : null,
              minimumStock: newItem ? _minimum.text : null,
              locationBin: newItem ? _location.text : null,
              notes: newItem ? _notes.text : null,
              quantityDelta: _remove
                  ? '-${_quantity.text.trim()}'
                  : _quantity.text,
              reason: _reason.text,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onCommitted();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _failure();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _failure() {
    final language = ref.read(languageProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(YorksV1InventoryStrings.savingFailed.active(language)),
      ),
    );
  }
}

class _InventoryImportDialog extends ConsumerWidget {
  const _InventoryImportDialog({
    required this.workspace,
    required this.onCommitted,
  });
  final YorksV1InventoryWorkspace workspace;
  final VoidCallback onCommitted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final state = ref.watch(yorksV1InventoryImportControllerProvider);
    final controller = ref.read(
      yorksV1InventoryImportControllerProvider.notifier,
    );
    final compact =
        MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;
    final preview = state.preview;
    Future<void> commit() async {
      final result = await controller.commit();
      if (result != null && context.mounted) {
        onCommitted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1InventoryStrings.importSucceeded.active(language),
            ),
          ),
        );
      }
    }

    final body = PopScope(
      canPop: !state.isBusy,
      child: Column(
        children: [
          _DialogHeader(
            title: YorksV1InventoryStrings.importTitle.active(language),
            onClose: state.isBusy ? null : () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TrustCard(language: language),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    YorksV1InventoryStrings.importHelp.active(language),
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: state.isBusy
                        ? null
                        : () => controller.chooseFile(workspace),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(
                      preview?.fileName ??
                          YorksV1InventoryStrings.selectFile.active(language),
                    ),
                  ),
                  if (state.status ==
                      YorksV1InventoryImportStatus.selecting) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _ImportMetric(
                            label: YorksV1InventoryStrings.rows.active(
                              language,
                            ),
                            value: preview.rowCount,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ImportMetric(
                            label: YorksV1InventoryStrings.errors.active(
                              language,
                            ),
                            value: preview.errorCount,
                            error: preview.errorCount > 0,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _ImportMetric(
                            label: YorksV1InventoryStrings.warnings.active(
                              language,
                            ),
                            value: preview.warningCount,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    for (final row in preview.rows)
                      _ImportRowCard(
                        row: row,
                        categories: workspace.categories,
                        language: language,
                        enabled: !state.isBusy,
                        onCategory: (categoryId) =>
                            controller.selectExistingCategory(
                              sourceCategory: row.sourceCategory,
                              categoryId: categoryId,
                            ),
                        onNew: () =>
                            controller.createNewCategory(row.sourceCategory),
                      ),
                  ],
                  if (state.status == YorksV1InventoryImportStatus.failed) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      YorksV1InventoryStrings.savingFailed.active(language),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: state.isBusy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: preview?.canCommit == true && !state.isBusy
                      ? commit
                      : null,
                  icon: state.status == YorksV1InventoryImportStatus.committing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined),
                  label: Text(
                    YorksV1InventoryStrings.commitImport.active(language),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (compact) return Dialog.fullscreen(child: SafeArea(child: body));
    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: SizedBox(
        width: 960,
        height: MediaQuery.sizeOf(context).height - 48,
        child: body,
      ),
    );
  }
}

class _ImportMetric extends StatelessWidget {
  const _ImportMetric({
    required this.label,
    required this.value,
    this.error = false,
  });
  final String label;
  final int value;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: error ? AppColors.errorContainer : AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelSmall),
        Text(
          '$value',
          style: AppTypography.titleLarge.copyWith(
            color: error ? AppColors.error : AppColors.ink,
          ),
        ),
      ],
    ),
  );
}

class _ImportRowCard extends StatelessWidget {
  const _ImportRowCard({
    required this.row,
    required this.categories,
    required this.language,
    required this.enabled,
    required this.onCategory,
    required this.onNew,
  });
  final YorksV1InventoryImportRow row;
  final List<YorksV1InventoryCategory> categories;
  final AppLanguage language;
  final bool enabled;
  final ValueChanged<String> onCategory;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final needsDecision = row.issues.any(
      (issue) =>
          issue.code ==
          YorksV1InventoryImportIssueCode.categoryDecisionRequired,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  child: Text(
                    '${row.sourceRowNumber}',
                    style: AppTypography.labelSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(row.description, style: AppTypography.titleSmall),
                ),
                Text(
                  '${_quantity(row.quantity)} ${row.unit}',
                  style: AppTypography.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${row.sourceCategory} · ${row.stockAction?.displayName ?? '—'}',
              style: AppTypography.bodySmall,
            ),
            if (row.hasErrors || needsDecision) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                needsDecision
                    ? YorksV1InventoryStrings.categoryDecision.active(language)
                    : YorksV1InventoryStrings.reviewRow.active(language),
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
            if (needsDecision) ...[
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: YorksV1InventoryStrings.category.active(language),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final suggestion in row.suggestions)
                    DropdownMenuItem(
                      value: suggestion.category.id,
                      child: Text(
                        '${suggestion.category.name} · ${(suggestion.score * 100).round()}%',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  for (final category in categories)
                    if (!row.suggestions.any(
                      (suggestion) => suggestion.category.id == category.id,
                    ))
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) onCategory(value);
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: enabled ? onNew : null,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  YorksV1InventoryStrings.newCategory.active(language),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoriesDialog extends ConsumerStatefulWidget {
  const _CategoriesDialog({
    required this.categories,
    required this.onCommitted,
  });
  final List<YorksV1InventoryCategory> categories;
  final VoidCallback onCommitted;
  @override
  ConsumerState<_CategoriesDialog> createState() => _CategoriesDialogState();
}

class _CategoriesDialogState extends ConsumerState<_CategoriesDialog> {
  final _name = TextEditingController();
  bool _saving = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    return AlertDialog(
      title: Text(YorksV1InventoryStrings.manageCategories.active(language)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Input(
                controller: _name,
                label: YorksV1InventoryStrings.categoryName.active(language),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _create,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    YorksV1InventoryStrings.newCategory.active(language),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final category in widget.categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    category.isSystem
                        ? Icons.verified_outlined
                        : Icons.category_outlined,
                    color: AppColors.blue,
                  ),
                  title: Text(category.name),
                  subtitle: category.aliases.isEmpty
                      ? null
                      : Text(
                          category.aliases.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: Text(
                    '${category.itemCount}',
                    style: AppTypography.titleSmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(yorksV1LogisticsRepositoryProvider)
          .createInventoryCategory(
            YorksV1InventoryCategoryCreationInput(
              name: name,
              idempotencyKey: const Uuid().v4(),
            ),
          );
      if (!mounted) return;
      widget.onCommitted();
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        final language = ref.read(languageProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              YorksV1InventoryStrings.savingFailed.active(language),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _InventoryItemDetailSheet extends ConsumerWidget {
  const _InventoryItemDetailSheet({
    required this.inventoryItemId,
    required this.onChanged,
  });
  final String inventoryItemId;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final detail = ref.watch(
      yorksV1InventoryItemDetailProvider(inventoryItemId),
    );
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .9,
        maxChildSize: .96,
        builder: (context, controller) => detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _StateMessage(
            icon: Icons.cloud_off_rounded,
            message: YorksV1InventoryStrings.savingFailed.active(language),
            action: YorksV1LogisticsStrings.refresh.active(language),
            onAction: () => ref.invalidate(
              yorksV1InventoryItemDetailProvider(inventoryItemId),
            ),
          ),
          data: (value) => ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value.item.description,
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${value.item.itemCode ?? '—'} · ${value.item.categoryName ?? YorksV1InventoryStrings.uncategorized.active(language)}',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _Surface(
                child: Row(
                  children: [
                    Expanded(
                      child: _Fact(
                        label: YorksV1LogisticsStrings.onHand.active(language),
                        value:
                            '${_quantity(value.item.onHandQuantity)} ${value.item.unit}',
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        label: YorksV1LogisticsStrings.reserved.active(
                          language,
                        ),
                        value:
                            '${_quantity(value.item.reservedQuantity)} ${value.item.unit}',
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        label: YorksV1LogisticsStrings.available.active(
                          language,
                        ),
                        value:
                            '${_quantity(value.item.availableQuantity)} ${value.item.unit}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _adjust(context, ref, value.item),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  YorksV1InventoryStrings.addReceive.active(language),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Panel(
                title: YorksV1InventoryStrings.movements.active(language),
                icon: Icons.history_rounded,
                child: value.movements.isEmpty
                    ? _InlineEmpty(
                        message: YorksV1InventoryStrings.noMovements.active(
                          language,
                        ),
                      )
                    : Column(
                        children: [
                          for (final movement in value.movements)
                            _MovementTile(movement: movement),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adjust(
    BuildContext context,
    WidgetRef ref,
    YorksV1LogisticsInventoryItem item,
  ) async {
    final workspace = await ref.read(
      yorksV1InventoryWorkspaceProvider(null).future,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _InventoryAdjustmentDialog(
        workspace: workspace,
        inventoryItem: item,
        onCommitted: () {
          ref.invalidate(yorksV1InventoryItemDetailProvider(item.id));
          onChanged();
        },
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title, required this.onClose});
  final String title;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    child: Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.titleLarge)),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.label,
    this.numeric = false,
    this.lines = 1,
  });
  final TextEditingController controller;
  final String label;
  final bool numeric;
  final int lines;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : lines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    minLines: lines,
    maxLines: lines,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surfaceContainerLowest,
    elevation: 1,
    shadowColor: AppColors.shadow,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      side: const BorderSide(color: AppColors.line),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppTypography.labelSmall),
      const SizedBox(height: AppSpacing.xs),
      Text(value, style: AppTypography.titleSmall),
    ],
  );
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Center(
      child: Text(
        message,
        style: AppTypography.bodyMedium.copyWith(color: AppColors.muted),
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.muted),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    ),
  );
}

String _quantity(String value) {
  final parsed = double.tryParse(value);
  if (parsed == null) return value;
  if (parsed == parsed.roundToDouble()) return parsed.toInt().toString();
  return parsed
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
