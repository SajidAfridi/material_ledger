import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_item.dart';
import '../models/material_request.dart';
import '../models/project.dart';
import 'inventory_provider.dart';
import 'material_plan_provider.dart';
import 'material_request_provider.dart';
import 'session_provider.dart';

// ─── Admin-created Projects ──────────────────────────────────────

/// All available projects.
final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) => ProjectsNotifier(ref, _mockProjects),
);

/// Request statuses that count as "open" — a project can't be closed out while
/// any of these exist against it (FR-095 closeout enforcement).
const _openRequestStatuses = {
  RequestStatus.draft,
  RequestStatus.pending,
  RequestStatus.sourcing,
  RequestStatus.partial,
  RequestStatus.onHold,
  RequestStatus.dispatched,
};

class ProjectsNotifier extends StateNotifier<List<Project>> {
  ProjectsNotifier(this._ref, super.initialProjects);

  final Ref _ref;

  void addProject(Project project) {
    state = [project, ...state];
  }

  void updateProject(Project project) {
    state = [
      for (final p in state)
        if (p.id == project.id) project else p,
    ];
  }

  /// Admin deletes a project (FR-317). REFUSED (returns false) while it still
  /// has open requests in flight — those hold stock reservations that would be
  /// orphaned with no UI path to release them, permanently distorting the shared
  /// godown's free-to-promise stock. Close or cancel the requests first. On a
  /// successful delete the project's Phase-1 plan is removed too, so nothing is
  /// left dangling.
  bool deleteProject(String projectId) {
    final p = byId(projectId);
    if (p == null) return false;
    if (openRequestCountFor(p) > 0) return false;
    state = state.where((x) => x.id != projectId).toList();
    _ref.read(materialPlansProvider.notifier).removeForProject(projectId);
    return true;
  }

  Project? byId(String id) {
    for (final p in state) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// True when [r] belongs to project [p]. Keys off the stable projectId when
  /// present (so two same-named jobs don't share requests); falls back to the
  /// name for legacy requests created before requests carried a projectId.
  bool _matchesProject(MaterialRequest r, Project p) =>
      r.projectId != null ? r.projectId == p.id : r.projectName == p.name;

  /// Number of open requests against a project.
  int openRequestCountFor(Project project) {
    return _ref
        .read(materialRequestsProvider)
        .where(
          (r) =>
              _matchesProject(r, project) &&
              _openRequestStatuses.contains(r.status),
        )
        .length;
  }

  /// A project may only be closed out when it is active and has no open
  /// requests still in flight (FR-095).
  bool canComplete(String projectId) {
    final p = byId(projectId);
    if (p == null) return false;
    if (p.phase?.state == ProjectState.completed) return false;
    return openRequestCountFor(p) == 0;
  }

  /// Close out a project. Returns false (no-op) if it still has open requests.
  bool completeProject(String projectId) {
    if (!canComplete(projectId)) return false;
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            awaitingApproval: false,
            openRequestCount: 0,
            lastUpdated: DateTime.now(),
            phase: const ProjectPhase(
              number: 3,
              name: 'Completed',
              nameSecondary: 'مکمل',
              state: ProjectState.completed,
            ),
          )
        else
          p,
    ];
    return true;
  }

  /// Activate a project after its Phase 1 plan is approved
  /// (Planning → Active, clears the approval flag).
  void activateFromPlanApproval(String projectId) {
    state = [
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            awaitingApproval: false,
            lastUpdated: DateTime.now(),
            phase: const ProjectPhase(
              number: 2,
              name: 'Active',
              nameSecondary: 'فعال',
              state: ProjectState.active,
            ),
          )
        else
          p,
    ];
  }
}

/// Projects visible to the signed-in user. Engineers see only the jobs assigned
/// to them (plus any not yet assigned to anyone); procurement and admin see the
/// full job register. Mirrors how the paper "Running Jobs" sheet works — one
/// engineer per job, management sees all.
final visibleProjectsProvider = Provider<List<Project>>((ref) {
  final projects = ref.watch(projectsProvider);
  final role = ref.watch(currentRoleProvider);
  if (role.usesAdminPanel) return projects; // procurement + admin → whole register
  final uid = ref.watch(currentUserProvider)?.id;
  return projects
      .where((p) => p.assignedEngineerId == null || p.assignedEngineerId == uid)
      .toList();
});

/// Whether a given project can currently be closed out (drives the UI control).
final canCompleteProjectProvider = Provider.family<bool, String>((
  ref,
  projectId,
) {
  // Watch requests so the result recomputes as statuses change.
  ref.watch(materialRequestsProvider);
  return ref.read(projectsProvider.notifier).canComplete(projectId);
});

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
                m.category == MaterialCategory.insulation ||
                m.category == MaterialCategory.airInletOutlet,
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

// ─── Engineer Dashboard — Project Filter ─────────────────────────

/// Filter applied to the dashboard "My projects" list.
enum DashboardProjectFilter { all, active, planning, onHold, completed }

final engineerProjectFilterProvider = StateProvider<DashboardProjectFilter>(
  (ref) => DashboardProjectFilter.all,
);

/// Projects filtered by the active dashboard filter.
final engineerFilteredProjectsProvider = Provider<List<Project>>((ref) {
  final filter = ref.watch(engineerProjectFilterProvider);
  final projects = ref.watch(visibleProjectsProvider);
  return switch (filter) {
    DashboardProjectFilter.all => projects,
    DashboardProjectFilter.active =>
      projects.where((p) => p.phase?.state == ProjectState.active).toList(),
    DashboardProjectFilter.planning =>
      projects.where((p) => p.phase?.state == ProjectState.planning).toList(),
    DashboardProjectFilter.onHold =>
      projects.where((p) => p.phase?.state == ProjectState.onHold).toList(),
    DashboardProjectFilter.completed =>
      projects.where((p) => p.phase?.state == ProjectState.completed).toList(),
  };
});

/// First project currently awaiting engineer approval (if any).
final pendingApprovalProjectProvider = Provider<Project?>((ref) {
  final projects = ref.watch(visibleProjectsProvider);
  for (final p in projects) {
    if (p.awaitingApproval) return p;
  }
  return null;
});

/// Phase shown in the dashboard header — derived from the pending-approval
/// project, or the first active project, or the first project.
final currentPhaseProvider = Provider<({Project project, ProjectPhase phase})?>(
  (ref) {
    final projects = ref.watch(visibleProjectsProvider);
    if (projects.isEmpty) return null;
    final candidate = projects.firstWhere(
      (p) => p.awaitingApproval && p.phase != null,
      orElse: () => projects.firstWhere(
        (p) => p.phase?.state == ProjectState.active,
        orElse: () => projects.first,
      ),
    );
    final phase = candidate.phase;
    if (phase == null) return null;
    return (project: candidate, phase: phase);
  },
);

/// Count of projects in any non-completed state.
final activeProjectCountProvider = Provider<int>((ref) {
  return ref
      .watch(projectsProvider)
      .where((p) => p.phase?.state != ProjectState.completed)
      .length;
});

/// Count of projects requiring engineer attention (approvals).
final actionsNeededCountProvider = Provider<int>((ref) {
  return ref.watch(visibleProjectsProvider).where((p) => p.awaitingApproval).length;
});

// ─── Mock Data ──────────────────────────────────────────────────

final _now = DateTime.now();

final _mockProjects = <Project>[
  Project(
    id: 'proj-001',
    name: 'Al Raha Beach Tower C — HVAC',
    nameSecondary: 'الراحہ بیچ ٹاور سی — ایچ وی اے سی',
    siteLocation: 'Al Raha Beach, Abu Dhabi',
    clientName: 'Aldar Properties',
    jobNumber: '301',
    mainContractor: 'KEC',
    authorityRef: 'ADWEA-3301',
    consultant: 'Hyder Consulting',
    contractValueAED: 4180000,
    assignedEngineerId: 'usr-eng',
    buildingName: 'Tower C',
    floorNumbers: 'Basement, G, 1-14',
    startDate: _now.subtract(const Duration(days: 10)),
    expectedEndDate: _now.add(const Duration(days: 90)),
    siteNotes:
        'Requires coordination with the main developer Aldar. Strict safety requirements.',
    phase: const ProjectPhase(
      number: 1,
      name: 'Planning',
      nameSecondary: 'پلاننگ',
      state: ProjectState.planning,
    ),
    lastUpdated: _now.subtract(const Duration(hours: 1)),
    awaitingApproval: true,
  ),
  Project(
    id: 'proj-002',
    name: 'Musaffah Warehouse — Chiller Install',
    nameSecondary: 'مصفح گودام — چلر انسٹال',
    siteLocation: 'Musaffah, Abu Dhabi',
    clientName: 'Gulf Industrial',
    jobNumber: '305',
    mainContractor: 'ELMEC',
    authorityRef: 'N-17727',
    contractValueAED: 1410000,
    assignedEngineerId: 'usr-eng',
    buildingName: 'Main Warehouse',
    floorNumbers: 'Ground Floor only',
    startDate: _now.subtract(const Duration(days: 30)),
    expectedEndDate: _now.add(const Duration(days: 15)),
    siteNotes:
        'Chiller installation needs heavy crane access. Confirm slab loading capacity.',
    phase: const ProjectPhase(
      number: 2,
      name: 'Active',
      nameSecondary: 'فعال',
      state: ProjectState.active,
    ),
    lastUpdated: _now.subtract(const Duration(hours: 3)),
    openRequestCount: 3,
  ),
  Project(
    id: 'proj-003',
    name: 'Khalidiyah Residences — Duct Work',
    nameSecondary: 'خالدیہ رہائش گاہیں — ڈکٹ ورک',
    siteLocation: 'Al Khalidiyah, Abu Dhabi',
    clientName: 'Bloom Properties',
    jobNumber: '312',
    mainContractor: 'DANWAY',
    authorityRef: 'ADWEA-1132',
    consultant: 'AECOM',
    contractValueAED: 3750000,
    assignedEngineerId: 'usr-eng',
    buildingName: 'Block A & B',
    floorNumbers: 'Floors 1-6',
    startDate: _now.subtract(const Duration(days: 45)),
    expectedEndDate: _now.add(const Duration(days: 20)),
    siteNotes:
        'Duct work on upper levels to be completed before ceiling contractors start.',
    phase: const ProjectPhase(
      number: 2,
      name: 'Active',
      nameSecondary: 'فعال',
      state: ProjectState.active,
    ),
    lastUpdated: _now.subtract(const Duration(hours: 6)),
    openRequestCount: 2,
  ),
  Project(
    id: 'proj-004',
    name: 'Corniche Clinic — FCU Replacement',
    nameSecondary: 'کارنیش کلینک — ایف سی یو متبادل',
    siteLocation: 'Corniche Road, Abu Dhabi',
    clientName: 'DOH',
    jobNumber: '320',
    mainContractor: 'REMCON',
    authorityRef: 'SHMG-2033',
    consultant: 'Mott MacDonald',
    contractValueAED: 4716750,
    assignedEngineerId: 'usr-eng',
    buildingName: 'East Wing',
    floorNumbers: 'G, 1, 2',
    startDate: _now.subtract(const Duration(days: 60)),
    expectedEndDate: _now.subtract(const Duration(days: 2)),
    siteNotes: 'FCU replacements in clinical area. Clean room protocol active.',
    phase: const ProjectPhase(
      number: 2,
      name: 'Active',
      nameSecondary: 'فعال',
      state: ProjectState.active,
    ),
    lastUpdated: _now.subtract(const Duration(days: 1)),
    allDispatched: true,
  ),
  Project(
    id: 'proj-005',
    name: 'City Centre — Piping & Valves',
    nameSecondary: 'سٹی سنٹر — پائپنگ اور والوز',
    siteLocation: 'Commercial District',
    clientName: 'Aldar Commercial',
    jobNumber: '315',
    mainContractor: 'L&T',
    authorityRef: 'ADWEA-5701',
    contractValueAED: 5700000,
    assignedEngineerId: 'usr-eng',
    buildingName: 'Retail Hub',
    floorNumbers: 'Ground & Mezzanine',
    startDate: _now.subtract(const Duration(days: 5)),
    expectedEndDate: _now.add(const Duration(days: 60)),
    siteNotes: 'High quality bronze valves required for pressure testing.',
    phase: const ProjectPhase(
      number: 1,
      name: 'Planning',
      nameSecondary: 'پلاننگ',
      state: ProjectState.planning,
    ),
    lastUpdated: _now.subtract(const Duration(days: 2)),
  ),
  Project(
    id: 'proj-006',
    name: 'Industrial Zone — Boiler Room',
    nameSecondary: 'صنعتی زون — بوائلر روم',
    siteLocation: 'Zone F, Industrial Area',
    clientName: 'Mubadala',
    jobNumber: 'B067',
    mainContractor: 'AG POWER',
    authorityRef: 'A-17676',
    contractValueAED: 1025000,
    assignedEngineerId: 'usr-eng',
    buildingName: 'Boiler Building 2',
    floorNumbers: 'Ground, Roof',
    startDate: _now.subtract(const Duration(days: 90)),
    expectedEndDate: _now.add(const Duration(days: 40)),
    siteNotes: 'Currently on hold waiting for boilers delivery from Germany.',
    phase: const ProjectPhase(
      number: 3,
      name: 'On Hold',
      nameSecondary: 'رکا ہوا',
      state: ProjectState.onHold,
    ),
    lastUpdated: _now.subtract(const Duration(days: 4)),
  ),
];
