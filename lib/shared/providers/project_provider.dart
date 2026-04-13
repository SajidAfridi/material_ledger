import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_item.dart';
import '../models/material_request.dart';
import '../models/project.dart';
import 'inventory_provider.dart';

// ─── Admin-created Projects ──────────────────────────────────────

/// All available projects (admin-created).
final projectsProvider = Provider<List<Project>>((ref) => _mockProjects);

// ─── Browse Screen Providers ──────────────────────────────────────

/// Category filter for the browse screen.
///
/// Optimized for HVAC supply: valves & fittings, pipes & ducts, fasteners.
enum BrowseCategoryFilter { all, valvesFittings, pipesDucts, fasteners }

final browseCategoryFilterProvider = StateProvider<BrowseCategoryFilter>(
  (ref) => BrowseCategoryFilter.all,
);

/// Search query for the browse screen.
final browseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Current browse page (0-indexed).
final browsePageProvider = StateProvider<int>((ref) => 0);

/// Items per page for browse.
const int browsePageSize = 10;

/// Filtered materials based on selected category AND search query.
final browseMaterialsProvider = Provider<List<MaterialItem>>((ref) {
  final filter = ref.watch(browseCategoryFilterProvider);
  final query = ref.watch(browseSearchQueryProvider).toLowerCase().trim();
  final materials = ref.watch(materialsProvider);

  var filtered = switch (filter) {
    BrowseCategoryFilter.all => materials,
    BrowseCategoryFilter.valvesFittings =>
      materials
          .where(
            (m) =>
                m.category == MaterialCategory.valves ||
                m.category == MaterialCategory.fittings ||
                m.category == MaterialCategory.copper,
          )
          .toList(),
    BrowseCategoryFilter.pipesDucts =>
      materials
          .where(
            (m) =>
                m.category == MaterialCategory.pipes ||
                m.category == MaterialCategory.ducts ||
                m.category == MaterialCategory.insulation,
          )
          .toList(),
    BrowseCategoryFilter.fasteners =>
      materials
          .where(
            (m) =>
                m.category == MaterialCategory.fasteners ||
                m.category == MaterialCategory.tools,
          )
          .toList(),
  };

  if (query.isNotEmpty) {
    filtered = filtered
        .where(
          (m) =>
              m.name.toLowerCase().contains(query) ||
              m.urduName.toLowerCase().contains(query) ||
              m.category.label.toLowerCase().contains(query),
        )
        .toList();
  }

  return filtered;
});

/// Paginated materials for current page.
final paginatedBrowseMaterialsProvider = Provider<List<MaterialItem>>((ref) {
  final all = ref.watch(browseMaterialsProvider);
  final page = ref.watch(browsePageProvider);
  final start = page * browsePageSize;
  if (start >= all.length) return [];
  final end = (start + browsePageSize).clamp(0, all.length);
  return all.sublist(start, end);
});

/// Total page count.
final browseTotalPagesProvider = Provider<int>((ref) {
  final total = ref.watch(browseMaterialsProvider).length;
  return (total / browsePageSize).ceil().clamp(1, 999);
});

// ─── New Request — Draft Line Items ──────────────────────────────

/// Manages the draft line items for the "New Request" form.
final draftLineItemsProvider =
    StateNotifierProvider<DraftLineItemsNotifier, List<RequestLineItem>>(
      (ref) => DraftLineItemsNotifier(),
    );

class DraftLineItemsNotifier extends StateNotifier<List<RequestLineItem>> {
  DraftLineItemsNotifier() : super([]);

  void addItem(RequestLineItem item) {
    // If same material already in the list, increase quantity
    final existing = state.indexWhere((e) => e.materialId == item.materialId);
    if (existing >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existing)
            state[i].copyWith(quantity: state[i].quantity + item.quantity)
          else
            state[i],
      ];
    } else {
      state = [...state, item];
    }
  }

  void removeItem(String materialId) {
    state = state.where((e) => e.materialId != materialId).toList();
  }

  void updateQuantity(String materialId, double quantity) {
    state = [
      for (final item in state)
        if (item.materialId == materialId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
  }

  void clear() => state = [];
}

// ─── Selected project for new request ────────────────────────────

final selectedProjectProvider = StateProvider<Project?>((ref) => null);

// ─── Priority selection for new request ──────────────────────────

final selectedPriorityProvider = StateProvider<RequestPriority>(
  (ref) => RequestPriority.normal,
);

// ─── Web Stock Filter ────────────────────────────────────────────

/// Stock filter for the web new-request material browsing panel.
enum WebStockFilter { all, available, lowStock }

final webStockFilterProvider = StateProvider<WebStockFilter>(
  (ref) => WebStockFilter.all,
);

/// Filtered materials for the web new-request center panel.
/// Composes category, search, and stock filter.
final webFilteredMaterialsProvider = Provider<List<MaterialItem>>((ref) {
  final base = ref.watch(browseMaterialsProvider);
  final stockFilter = ref.watch(webStockFilterProvider);

  return switch (stockFilter) {
    WebStockFilter.all => base,
    WebStockFilter.available =>
      base.where((m) => m.stockStatus == StockStatus.inStock).toList(),
    WebStockFilter.lowStock =>
      base.where((m) => m.stockStatus == StockStatus.lowStock).toList(),
  };
});

// ─── Mock Data ──────────────────────────────────────────────────

final _mockProjects = [
  const Project(
    id: 'proj-001',
    name: 'Al-Burj Tower — HVAC Fit-Out',
    nameSecondary: 'البرج ٹاور — ایچ وی اے سی',
    siteLocation: 'Block A, Sector 7',
  ),
  const Project(
    id: 'proj-002',
    name: 'Marina Bay Mall — Chiller Plant',
    nameSecondary: 'مرینا بے مال — چلر پلانٹ',
    siteLocation: 'Zone E, Basement Level',
  ),
  const Project(
    id: 'proj-003',
    name: 'Green Valley Hospital — AHU Installation',
    nameSecondary: 'گرین ویلی ہسپتال — اے ایچ یو',
    siteLocation: 'Phase 2, Medical Wing',
  ),
  const Project(
    id: 'proj-004',
    name: 'Heritage Hotel — Ductwork',
    nameSecondary: 'ہیریٹیج ہوٹل — ڈکٹ ورک',
    siteLocation: 'Downtown, Heritage Block',
  ),
  const Project(
    id: 'proj-005',
    name: 'City Centre — Piping & Valves',
    nameSecondary: 'سٹی سنٹر — پائپنگ اور والوز',
    siteLocation: 'Commercial District',
  ),
  const Project(
    id: 'proj-006',
    name: 'Industrial Zone — Boiler Room',
    nameSecondary: 'صنعتی زون — بوائلر روم',
    siteLocation: 'Zone F, Industrial Area',
  ),
];
