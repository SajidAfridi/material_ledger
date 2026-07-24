import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/constants.dart';
import '../../../../shared/models/material_item.dart';
import '../../../../shared/models/material_master.dart';
import '../../../../shared/providers/inventory_provider.dart';
import '../../../../shared/providers/material_master_provider.dart';
import '../../../../shared/providers/permissions_provider.dart';
import '../../../../shared/providers/session_provider.dart';
import '../../../../shared/services/catalogue_csv_download.dart';
import '../../../../shared/services/material_catalogue_csv_export.dart';
import '../../../inventory/presentation/widgets/add_material_sheet.dart';

class BrowseMaterialsScreen extends ConsumerStatefulWidget {
  const BrowseMaterialsScreen({super.key});

  @override
  ConsumerState<BrowseMaterialsScreen> createState() =>
      _BrowseMaterialsScreenState();
}

class _BrowseMaterialsScreenState extends ConsumerState<BrowseMaterialsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _categoryId;
  String? _selectedId;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSeeCost = ref.watch(canViewCommercialsProvider);
    final role = ref.watch(currentRoleProvider);
    final materials = canSeeCost
        ? ref.watch(materialsWithCommercialsProvider)
        : ref.watch(materialsProvider);
    final categories = ref.watch(materialCategoriesProvider);
    final units = ref.watch(materialUnitsProvider);
    final categoryById = {for (final value in categories) value.id: value};
    final unitById = {for (final value in units) value.id: value};
    final query = _search.text.trim().toLowerCase();
    final filtered = [
      for (final item in materials)
        if ((_categoryId == null || item.categoryMasterId == _categoryId) &&
            _matches(item, query, categoryById[item.categoryMasterId]))
          item,
    ]..sort((a, b) => a.name.compareTo(b.name));
    final selected =
        filtered.where((item) => item.id == _selectedId).firstOrNull ??
        filtered.firstOrNull;
    if (selected != null && _selectedId == null) _selectedId = selected.id;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _search.clear();
          setState(() {});
        },
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                controller: _search,
                focusNode: _searchFocus,
                resultCount: filtered.length,
                isAdmin: role.isAdmin,
                onSearch: () => setState(() {}),
                onExport: () =>
                    _export(filtered, categoryById, unitById, canSeeCost),
                onAdd: role.isAdmin ? _openAddMaterial : null,
                onMasters: role.isAdmin
                    ? () => context.push(RoutePaths.materialMasters)
                    : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 760) {
                      return _MobileBrowser(
                        items: filtered,
                        categories: categories,
                        categoryById: categoryById,
                        unitById: unitById,
                        selectedCategoryId: _categoryId,
                        canSeeCost: canSeeCost,
                        onCategory: (value) =>
                            setState(() => _categoryId = value),
                      );
                    }
                    return _DesktopBrowser(
                      items: filtered,
                      allMaterials: materials,
                      categories: categories,
                      categoryById: categoryById,
                      unitById: unitById,
                      selectedCategoryId: _categoryId,
                      selected: selected,
                      canSeeCost: canSeeCost,
                      showInspector: constraints.maxWidth >= 1040,
                      onCategory: (value) =>
                          setState(() => _categoryId = value),
                      onSelected: (value) =>
                          setState(() => _selectedId = value.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _matches(
    MaterialItem item,
    String query,
    MaterialCategoryMaster? category,
  ) {
    if (query.isEmpty) return true;
    return [
      item.id,
      item.name,
      item.urduName,
      item.size,
      item.brand,
      item.countryOfOrigin,
      item.ralColour,
      item.storeLocation,
      category?.name ?? item.category.label,
    ].any((value) => value.toLowerCase().contains(query));
  }

  Future<void> _export(
    List<MaterialItem> materials,
    Map<String, MaterialCategoryMaster> categories,
    Map<String, MaterialUnitMaster> units,
    bool includeCommercials,
  ) async {
    final csv = MaterialCatalogueCsvExport.build(
      materials: materials,
      categories: categories,
      units: units,
      includeCommercials: includeCommercials,
    );
    final downloaded = await downloadCatalogueCsv(csv);
    if (!downloaded) {
      await Clipboard.setData(ClipboardData(text: csv));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          downloaded
              ? 'Catalogue CSV downloaded'
              : 'Catalogue CSV copied to clipboard',
        ),
      ),
    );
  }

  Future<void> _openAddMaterial() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddMaterialSheet(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.focusNode,
    required this.resultCount,
    required this.isAdmin,
    required this.onSearch,
    required this.onExport,
    this.onAdd,
    this.onMasters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int resultCount;
  final bool isAdmin;
  final VoidCallback onSearch;
  final VoidCallback onExport;
  final VoidCallback? onAdd;
  final VoidCallback? onMasters;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.lg,
        AppSpacing.screenHorizontal,
        AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Browse Materials',
                      style: AppTypography.headlineSmall,
                    ),
                    Text(
                      '$resultCount catalogue items · stock values are live',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow && onMasters != null)
                TextButton.icon(
                  onPressed: onMasters,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Master data'),
                ),
              if (!narrow && onAdd != null)
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add material'),
                ),
              IconButton(
                tooltip: 'Export filtered catalogue as CSV',
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined),
              ),
              if (narrow && isAdmin)
                PopupMenuButton<String>(
                  onSelected: (value) =>
                      value == 'masters' ? onMasters?.call() : onAdd?.call(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add', child: Text('Add material')),
                    PopupMenuItem(value: 'masters', child: Text('Master data')),
                  ],
                ),
            ],
          ),
          const Gap(AppSpacing.md),
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'Search description, code, size, make or origin',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onSearch();
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopBrowser extends StatelessWidget {
  const _DesktopBrowser({
    required this.items,
    required this.allMaterials,
    required this.categories,
    required this.categoryById,
    required this.unitById,
    required this.selectedCategoryId,
    required this.selected,
    required this.canSeeCost,
    required this.showInspector,
    required this.onCategory,
    required this.onSelected,
  });

  final List<MaterialItem> items;
  final List<MaterialItem> allMaterials;
  final List<MaterialCategoryMaster> categories;
  final Map<String, MaterialCategoryMaster> categoryById;
  final Map<String, MaterialUnitMaster> unitById;
  final String? selectedCategoryId;
  final MaterialItem? selected;
  final bool canSeeCost;
  final bool showInspector;
  final ValueChanged<String?> onCategory;
  final ValueChanged<MaterialItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 230,
          child: _CategoryRail(
            categories: categories,
            materials: allMaterials,
            selectedId: selectedCategoryId,
            onSelected: onCategory,
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: _MaterialList(
            items: items,
            selectedId: selected?.id,
            categoryById: categoryById,
            unitById: unitById,
            canSeeCost: canSeeCost,
            onSelected: onSelected,
          ),
        ),
        if (showInspector) ...[
          const VerticalDivider(width: 1),
          SizedBox(
            width: 330,
            child: _Inspector(
              item: selected,
              categoryById: categoryById,
              unitById: unitById,
              canSeeCost: canSeeCost,
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.materials,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MaterialCategoryMaster> categories;
  final List<MaterialItem> materials;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        _RailTile(
          label: 'All materials',
          count: materials.length,
          selected: selectedId == null,
          onTap: () => onSelected(null),
        ),
        for (final category in visible)
          if (!category.archived ||
              materials.any(
                (material) => material.categoryMasterId == category.id,
              ))
            _RailTile(
              label: category.name,
              count: materials
                  .where((material) => material.categoryMasterId == category.id)
                  .length,
              selected: selectedId == category.id,
              archived: category.archived,
              onTap: () => onSelected(category.id),
            ),
      ],
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.archived = false,
  });

  final String label;
  final int count;
  final bool selected;
  final bool archived;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      leading: Icon(
        archived ? Icons.archive_outlined : Icons.folder_outlined,
        size: 18,
      ),
      title: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: Text('$count', style: AppTypography.labelSmall),
      onTap: onTap,
    );
  }
}

class _MaterialList extends StatelessWidget {
  const _MaterialList({
    required this.items,
    required this.selectedId,
    required this.categoryById,
    required this.unitById,
    required this.canSeeCost,
    required this.onSelected,
  });

  final List<MaterialItem> items;
  final String? selectedId;
  final Map<String, MaterialCategoryMaster> categoryById;
  final Map<String, MaterialUnitMaster> unitById;
  final bool canSeeCost;
  final ValueChanged<MaterialItem> onSelected;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('No materials match these filters.'));
    }
    return Column(
      children: [
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          color: AppColors.surfaceContainerLow,
          child: const Row(
            children: [
              Expanded(flex: 4, child: Text('MATERIAL')),
              Expanded(flex: 2, child: Text('CATEGORY')),
              Expanded(child: Text('AVAILABLE')),
              Expanded(child: Text('UNIT')),
              Expanded(child: Text('STORE')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemExtent: 62,
            itemBuilder: (context, index) {
              final item = items[index];
              final selected = item.id == selectedId;
              return InkWell(
                onTap: () => onSelected(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.07)
                      : null,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              [
                                item.id,
                                item.size,
                                item.brand,
                              ].where((value) => value.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          categoryById[item.categoryMasterId]?.name ??
                              item.category.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: _StockText(
                          value: item.availableQty,
                          status: item.stockStatus,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          unitById[item.unitMasterId]?.symbol ??
                              item.unit.symbol,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item.storeLocation.isEmpty ? '—' : item.storeLocation,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileBrowser extends StatelessWidget {
  const _MobileBrowser({
    required this.items,
    required this.categories,
    required this.categoryById,
    required this.unitById,
    required this.selectedCategoryId,
    required this.canSeeCost,
    required this.onCategory,
  });

  final List<MaterialItem> items;
  final List<MaterialCategoryMaster> categories;
  final Map<String, MaterialCategoryMaster> categoryById;
  final Map<String, MaterialUnitMaster> unitById;
  final String? selectedCategoryId;
  final bool canSeeCost;
  final ValueChanged<String?> onCategory;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DropdownButtonFormField<String>(
            initialValue: selectedCategoryId ?? 'all',
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All materials'),
              ),
              for (final category in categories)
                if (!category.archived)
                  DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
            ],
            onChanged: (value) =>
                onCategory(value == null || value == 'all' ? null : value),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No materials match these filters.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${categoryById[item.categoryMasterId]?.name ?? item.category.label}'
                          ' · ${_fmt(item.availableQty)} ${unitById[item.unitMasterId]?.symbol ?? item.unit.symbol} available',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => _Inspector(
                            item: item,
                            categoryById: categoryById,
                            unitById: unitById,
                            canSeeCost: canSeeCost,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Inspector extends StatelessWidget {
  const _Inspector({
    required this.item,
    required this.categoryById,
    required this.unitById,
    required this.canSeeCost,
  });

  final MaterialItem? item;
  final Map<String, MaterialCategoryMaster> categoryById;
  final Map<String, MaterialUnitMaster> unitById;
  final bool canSeeCost;

  @override
  Widget build(BuildContext context) {
    final value = item;
    if (value == null) return const Center(child: Text('Select a material'));
    final unit = unitById[value.unitMasterId]?.symbol ?? value.unit.symbol;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value.name, style: AppTypography.titleLarge),
          if (value.urduName.isNotEmpty) ...[
            const Gap(AppSpacing.xs),
            Text(
              value.urduName,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
          const Gap(AppSpacing.lg),
          _Detail(
            label: 'Category',
            value:
                categoryById[value.categoryMasterId]?.name ??
                value.category.label,
          ),
          _Detail(label: 'Code', value: value.id),
          _Detail(label: 'Size', value: value.size),
          _Detail(label: 'Make / brand', value: value.brand),
          _Detail(label: 'Origin', value: value.countryOfOrigin),
          _Detail(label: 'RAL colour', value: value.ralColour),
          _Detail(label: 'Store', value: value.storeLocation),
          const Divider(height: AppSpacing.xxl),
          _Detail(label: 'On hand', value: '${_fmt(value.quantity)} $unit'),
          _Detail(
            label: 'Allocated',
            value: '${_fmt(value.reservedQty)} $unit',
          ),
          _Detail(
            label: 'Available',
            value: '${_fmt(value.availableQty)} $unit',
          ),
          const _Detail(
            label: 'In transit',
            value: '— Not tracked in this batch',
          ),
          if (canSeeCost) ...[
            const Divider(height: AppSpacing.xxl),
            _Detail(
              label: 'Unit cost',
              value: 'AED ${value.unitPrice.toStringAsFixed(2)}',
            ),
            _Detail(
              label: 'Stock value',
              value: 'AED ${value.totalValue.toStringAsFixed(2)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockText extends StatelessWidget {
  const _StockText({required this.value, required this.status});

  final double value;
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      StockStatus.inStock => AppColors.success,
      StockStatus.lowStock => AppColors.warning,
      StockStatus.outOfStock => AppColors.error,
    };
    return Text(
      _fmt(value),
      style: AppTypography.bodyMedium.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _fmt(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
