import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/material_item.dart';
import '../models/material_request.dart';
import '../models/project.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'inventory_provider.dart';
import 'material_plan_provider.dart';
import 'material_request_provider.dart';
import 'session_provider.dart';

// ─── Projects ──────────────────────────────────────────────────────

const _kProjectsKey = 'projects_list_v1';

/// All available projects.
final projectsProvider = StateNotifierProvider<ProjectsNotifier, List<Project>>(
  (ref) => ProjectsNotifier(
    ref,
    ref.watch(storageProvider).collection<Project>(
      _kProjectsKey,
      toJson: (p) => p.toJson(),
      fromJson: Project.fromJson,
    ),
  ),
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
  ProjectsNotifier(this._ref, this._store) : super(_load(_store)) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<Project> _store;

  /// Reads from the store (or the empty seed on first run) and drops any
  /// soft-deleted row — see [Project.deleted].
  static List<Project> _load(CollectionStore<Project> store) {
    final all = store.isSeeded ? store.readAll() : _mockProjects;
    return all.where((p) => !p.deleted).toList();
  }

  Future<void> _persist() => _store.writeAll(state);

  /// Syncs a project, stripping the finance-gated contract value from the
  /// shared cloud payload — the same treatment employees' salary gets (see
  /// hr_provider.dart). It stays in this device's local store (so the
  /// finance-gated UI can still show it here), but never rides in the payload
  /// every 'goods'-cap role can read.
  Future<void> _syncProject(Project p, {required String kind}) {
    final payload = p.toJson()..remove('contractValueAED');
    return _ref.enqueueSync(
      collection: 'projects',
      docId: p.id,
      kind: kind,
      label: 'Project',
      payload: payload,
    );
  }

  Future<void> addProject(Project project) async {
    state = [project, ...state];
    await _persist();
    await _syncProject(project, kind: 'project.create');
  }

  Future<void> updateProject(Project project) async {
    state = [
      for (final p in state)
        if (p.id == project.id) project else p,
    ];
    await _persist();
    await _syncProject(project, kind: 'project.update');
  }

  /// Admin deletes a project (FR-317). REFUSED (returns false) while it still
  /// has open requests in flight — those hold stock reservations that would be
  /// orphaned with no UI path to release them, permanently distorting the shared
  /// godown's free-to-promise stock. Close or cancel the requests first. On a
  /// successful delete the project's Phase-1 plan is removed too, so nothing is
  /// left dangling.
  ///
  /// This is a SOFT delete: the outbox only ever upserts (see
  /// SupabaseSyncBackend.apply), so a physical row removal would just resurrect
  /// the next time any device hydrates from the cloud. Flip `deleted`, sync
  /// that, then drop it from local state — every device's own [_load] filters
  /// it out from then on, on every future read.
  Future<bool> deleteProject(String projectId) async {
    final p = byId(projectId);
    if (p == null) return false;
    if (openRequestCountFor(p) > 0) return false;
    final tombstone = p.copyWith(deleted: true, lastUpdated: DateTime.now());
    state = state.where((x) => x.id != projectId).toList();
    await _persist();
    await _syncProject(tombstone, kind: 'project.delete');
    await _ref.read(materialPlansProvider.notifier).removeForProject(projectId);
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
  Future<bool> completeProject(String projectId) async {
    if (!canComplete(projectId)) return false;
    Project? updated;
    state = [
      for (final p in state)
        if (p.id == projectId)
          updated = p.copyWith(
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
    await _persist();
    if (updated != null) await _syncProject(updated, kind: 'project.complete');
    return true;
  }

  /// Procurement acknowledges a newly-created project. No-op (returns null) if
  /// the project doesn't exist or was already accepted — callers use the
  /// non-null return to know whether to notify/toast.
  Future<Project?> acceptProject(
    String projectId, {
    required String acceptedBy,
  }) async {
    final p = byId(projectId);
    if (p == null || p.acceptedByProcurement) return null;
    final updated = p.copyWith(
      acceptedByProcurement: true,
      acceptedAt: DateTime.now(),
      acceptedBy: acceptedBy,
      lastUpdated: DateTime.now(),
    );
    state = [
      for (final x in state)
        if (x.id == projectId) updated else x,
    ];
    await _persist();
    await _syncProject(updated, kind: 'project.accept');
    return updated;
  }

  /// Activate a project after its Phase 1 plan is approved
  /// (Planning → Active, clears the approval flag).
  Future<void> activateFromPlanApproval(String projectId) async {
    Project? updated;
    state = [
      for (final p in state)
        if (p.id == projectId)
          updated = p.copyWith(
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
    await _persist();
    if (updated != null) await _syncProject(updated, kind: 'project.activate');
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

/// Projects an engineer has created that procurement hasn't yet acknowledged —
/// drives the Procurement workspace's "New projects" queue and every badge that
/// surfaces it (Home KPI, Materials hub). Uses the full register (not
/// [visibleProjectsProvider]) since acceptance is a procurement/admin action
/// regardless of which engineer a job is assigned to.
final projectsAwaitingAcceptanceProvider = Provider<List<Project>>((ref) {
  return ref.watch(projectsProvider).where((p) => !p.acceptedByProcurement).toList();
});

final projectsAwaitingAcceptanceCountProvider = Provider<int>((ref) {
  return ref.watch(projectsAwaitingAcceptanceProvider).length;
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

const _kDraftItemsKey = 'new_request_draft_items_v1';

/// Manages the draft line items for the "New Request" form.
///
/// The draft is persisted to local storage on every change, so a multi-item,
/// multi-minute request-in-progress survives the OS killing the app on a
/// low-memory field device — the items are restored automatically the next time
/// the New Request screen opens. Submitting or discarding clears it.
final draftLineItemsProvider =
    StateNotifierProvider<DraftLineItemsNotifier, List<RequestLineItem>>(
      (ref) => DraftLineItemsNotifier(
        ref.watch(storageProvider).collection<RequestLineItem>(
          _kDraftItemsKey,
          toJson: (i) => i.toJson(),
          fromJson: RequestLineItem.fromJson,
        ),
      ),
    );

class DraftLineItemsNotifier extends StateNotifier<List<RequestLineItem>> {
  DraftLineItemsNotifier(this._store)
      : super(_store.isSeeded ? _store.readAll() : []);

  final CollectionStore<RequestLineItem> _store;

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
    _persist();
  }

  void removeItem(String materialId) {
    state = state.where((e) => e.materialId != materialId).toList();
    _persist();
  }

  void updateQuantity(String materialId, double quantity) {
    state = [
      for (final item in state)
        if (item.materialId == materialId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];
    _persist();
  }

  void clear() {
    state = [];
    _persist();
  }

  void _persist() => _store.writeAll(state);
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

// No pre-seeded demo projects — the office creates real projects as they
// come in during testing/production use.
final _mockProjects = <Project>[];
