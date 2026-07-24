import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_plan.dart';
import '../models/user_role.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';
import 'session_provider.dart';

const _kPlansKey = 'material_plans_list_v2';
const _uuid = Uuid();

/// All Phase 1 material plans (one per project).
final materialPlansProvider =
    StateNotifierProvider<MaterialPlansNotifier, List<MaterialPlan>>((ref) {
      return MaterialPlansNotifier(
        ref,
        ref
            .watch(storageProvider)
            .collection<MaterialPlan>(
              _kPlansKey,
              toJson: (p) => p.toJson(),
              fromJson: MaterialPlan.fromJson,
            ),
      );
    });

/// The plan for a given project, if one exists.
final planForProjectProvider = Provider.family<MaterialPlan?, String>((
  ref,
  projectId,
) {
  final plans = ref.watch(materialPlansProvider);
  for (final p in plans) {
    if (p.projectId == projectId) return p;
  }
  return null;
});

/// Statuses that put a plan in procurement's review queue (same set the
/// procurement workspace lists). Single source of truth for the count.
const planReviewQueueStatuses = {
  MaterialPlanStatus.submitted,
  MaterialPlanStatus.procurementReview,
};

/// Plans waiting on procurement to review/arrange — drives the Home
/// "Awaiting you" KPI and the Materials-hub Procurement badge.
final planReviewQueueCountProvider = Provider<int>((ref) {
  return ref
      .watch(materialPlansProvider)
      .where((p) => planReviewQueueStatuses.contains(p.status))
      .length;
});

class MaterialPlansNotifier extends StateNotifier<List<MaterialPlan>> {
  MaterialPlansNotifier(this._ref, this._store) : super(_load(_store)) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final Ref _ref;
  final CollectionStore<MaterialPlan> _store;

  bool _canActAs(UserRole role) {
    final actorRole = _ref.read(currentUserProvider)?.role;
    return actorRole == UserRole.admin || actorRole == role;
  }

  ({String? userId, String name, String role}) _actor({
    UserRole? fallbackRole,
  }) {
    final user = _ref.read(currentUserProvider);
    return (
      userId: user?.id,
      name: user?.fullName ?? 'System',
      role: user?.role.label ?? fallbackRole?.label ?? 'System',
    );
  }

  MaterialPlanActivity _event(
    String action, {
    required ({String? userId, String name, String role}) actor,
    String detail = '',
    DateTime? at,
  }) => MaterialPlanActivity(
    action: action,
    actorName: actor.name,
    actorRole: actor.role,
    actorUserId: actor.userId,
    timestamp: at ?? DateTime.now().toUtc(),
    detail: detail,
  );

  /// Reads from the store (or the empty seed on first run) and drops any
  /// soft-deleted row — see [MaterialPlan.deleted].
  static List<MaterialPlan> _load(CollectionStore<MaterialPlan> store) {
    final all = store.isSeeded ? store.readAll() : _seedPlans;
    return all.where((p) => !p.deleted).toList();
  }

  Future<void> _persist() => _store.writeAll(state);

  Future<void> _syncPlan(MaterialPlan p, {required String kind}) {
    return _ref.enqueueSync(
      collection: 'materialPlans',
      docId: p.id,
      kind: kind,
      label: 'Material plan',
      payload: p.toJson(),
    );
  }

  MaterialPlan? planForProject(String projectId) {
    for (final p in state) {
      if (p.projectId == projectId) return p;
    }
    return null;
  }

  /// Delete a project's Phase-1 plan — called when the project itself is
  /// removed, so no orphaned plan is left behind.
  ///
  /// Soft delete (mirrors [ProjectsNotifier.deleteProject]): the outbox only
  /// ever upserts, so a physical row removal would resurrect on the next cloud
  /// hydration. Flip `deleted`, sync that, then drop it locally.
  Future<void> removeForProject(String projectId) async {
    MaterialPlan? tombstone;
    for (final p in state) {
      if (p.projectId == projectId) tombstone = p.copyWith(deleted: true);
    }
    if (tombstone == null) return;
    state = state.where((p) => p.projectId != projectId).toList();
    await _persist();
    await _syncPlan(tombstone, kind: 'plan.delete');
  }

  /// Insert or replace a plan (by project).
  Future<void> upsertPlan(MaterialPlan plan) async {
    final exists = state.any((p) => p.projectId == plan.projectId);
    state = exists
        ? [
            for (final p in state)
              if (p.projectId == plan.projectId) plan else p,
          ]
        : [plan, ...state];
    await _persist();
    await _syncPlan(plan, kind: 'plan.upsert');
  }

  /// Create a draft plan for a project if none exists, returning it.
  MaterialPlan ensurePlan(String projectId) {
    final existing = planForProject(projectId);
    if (existing != null) return existing;
    if (!_canActAs(UserRole.engineer)) {
      throw StateError('Only Engineering can create a Phase 1 plan.');
    }
    final plan = MaterialPlan(
      id: 'plan-${_uuid.v4().substring(0, 8)}',
      projectId: projectId,
      version: 0,
      currentOwnerRole: UserRole.engineer.name,
    );
    upsertPlan(plan);
    return plan;
  }

  /// Engineer submits the plan to procurement (FR-020). If the plan had
  /// already been arranged (has a baseline) this is an edit-after-arrangement,
  /// so it returns to procurement re-review and the diff is preserved
  /// (FR-030/031); otherwise it is a first submission.
  Future<void> saveDraft(String projectId, List<PlanItem> items) async {
    if (!_canActAs(UserRole.engineer)) return;
    final existing = planForProject(projectId);
    if (existing != null &&
        !{
          MaterialPlanStatus.draft,
          MaterialPlanStatus.rejected,
        }.contains(existing.status)) {
      return;
    }
    final actor = _actor(fallbackRole: UserRole.engineer);
    final now = DateTime.now().toUtc();
    final plan =
        (existing ??
                MaterialPlan(
                  id: 'plan-${_uuid.v4().substring(0, 8)}',
                  projectId: projectId,
                  version: 0,
                ))
            .copyWith(
              items: items,
              status: existing?.status ?? MaterialPlanStatus.draft,
              currentOwnerRole: UserRole.engineer.name,
              updatedAt: now,
              updatedByUserId: actor.userId,
            );
    final exists = state.any((row) => row.projectId == projectId);
    state = exists
        ? [
            for (final row in state)
              if (row.projectId == projectId) plan else row,
          ]
        : [plan, ...state];
    await _persist();
  }

  Future<void> submitPlan(String projectId, List<PlanItem> items) async {
    if (!_canActAs(UserRole.engineer)) return;
    final existing = planForProject(projectId);
    if (items.isEmpty ||
        (existing != null &&
            !{
              MaterialPlanStatus.draft,
              MaterialPlanStatus.rejected,
            }.contains(existing.status))) {
      return;
    }
    final wasArranged = existing != null && existing.baselineItems.isNotEmpty;
    final actor = _actor(fallbackRole: UserRole.engineer);
    final now = DateTime.now().toUtc();
    final nextVersion =
        existing == null ||
            (existing.status == MaterialPlanStatus.draft &&
                existing.versions.isEmpty)
        ? 1
        : existing.version + 1;
    final submittedItems = [
      for (final item in items)
        item.copyWith(
          status: PlanItemStatus.pending,
          proposedSource: PlanProposedSource.notReviewed,
          onHandQtySnapshot: null,
          availableQtySnapshot: null,
          procurementNote: '',
        ),
    ];
    final plan =
        (existing ??
                MaterialPlan(
                  id: 'plan-${_uuid.v4().substring(0, 8)}',
                  projectId: projectId,
                  version: 0,
                ))
            .copyWith(
              items: submittedItems,
              status: wasArranged
                  ? MaterialPlanStatus.procurementReview
                  : MaterialPlanStatus.submitted,
              submittedAt: now,
              reviewedAt: null,
              approvedAt: null,
              version: nextVersion,
              versions: [
                ...?existing?.versions,
                MaterialPlanVersion(
                  version: nextVersion,
                  items: submittedItems,
                  createdAt: now,
                  createdByUserId: actor.userId,
                  createdByName: actor.name,
                  createdByRole: actor.role,
                ),
              ],
              activity: [
                ...?existing?.activity,
                _event(
                  'Plan submitted',
                  actor: actor,
                  detail: 'Version $nextVersion · ${items.length} lines',
                  at: now,
                ),
              ],
              currentOwnerRole: UserRole.procurement.name,
              updatedAt: now,
              updatedByUserId: actor.userId,
            );
    await upsertPlan(plan);
  }

  /// Engineer gives final approval (FR-029). Caller activates the project.
  Future<void> approvePlan(String planId) async {
    if (!_canActAs(UserRole.engineer)) return;
    final actor = _actor(fallbackRole: UserRole.engineer);
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId &&
            p.status == MaterialPlanStatus.pendingEngineerApproval)
          updated = p.copyWith(
            status: MaterialPlanStatus.approved,
            approvedAt: now,
            currentOwnerRole: 'none',
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                'Plan approved',
                actor: actor,
                detail: 'Version ${p.version} approved',
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.approve');
  }

  /// Engineer rejects specific items with a reason (FR-027/FR-028).
  Future<void> requestChanges({
    required String planId,
    required Set<String> rejectedItemIds,
    required String comment,
    required String authorName,
  }) async {
    if (!_canActAs(UserRole.engineer)) return;
    if (rejectedItemIds.isEmpty || comment.trim().isEmpty) return;
    final actor = _actor(fallbackRole: UserRole.engineer);
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId &&
            p.status == MaterialPlanStatus.pendingEngineerApproval)
          updated = p.copyWith(
            status: MaterialPlanStatus.rejected,
            items: [
              for (final i in p.items)
                if (rejectedItemIds.contains(i.id))
                  i.copyWith(status: PlanItemStatus.rejected)
                else
                  i,
            ],
            comments: [
              ...p.comments,
              if (comment.trim().isNotEmpty)
                PlanComment(
                  id: _uuid.v4(),
                  authorUserId: actor.userId,
                  authorName: authorName,
                  authorRole: actor.role,
                  text: comment.trim(),
                  timestamp: now,
                ),
            ],
            currentOwnerRole: UserRole.engineer.name,
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                'Changes requested',
                actor: actor,
                detail: '${rejectedItemIds.length} lines selected',
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.requestChanges');
  }

  Future<void> addComment({
    required String planId,
    required String text,
    required String authorName,
    String authorRole = 'Engineer',
    String? lineItemId,
  }) async {
    if (!_canActAs(UserRole.procurement)) return;
    if (text.trim().isEmpty) return;
    final actor = _actor();
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId &&
            {
              MaterialPlanStatus.submitted,
              MaterialPlanStatus.procurementReview,
            }.contains(p.status))
          updated = p.copyWith(
            comments: [
              ...p.comments,
              PlanComment(
                id: _uuid.v4(),
                authorUserId: actor.userId,
                authorName: authorName,
                authorRole: authorRole,
                text: text.trim(),
                timestamp: now,
                lineItemId: lineItemId,
              ),
            ],
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                lineItemId == null
                    ? 'Plan comment added'
                    : 'Line comment added',
                actor: actor,
                detail: lineItemId ?? '',
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.comment');
  }

  // ─── Procurement actions (FR plan review) ────────────────────────

  /// Procurement sets a single item's arrangement status (Arranged / In stock).
  Future<void> setItemStatus(
    String planId,
    String itemId,
    PlanItemStatus status,
  ) async {
    final source = switch (status) {
      PlanItemStatus.ticked => PlanProposedSource.warehouse,
      PlanItemStatus.arranged => PlanProposedSource.externalSupplier,
      _ => PlanProposedSource.notReviewed,
    };
    return setProposedSource(planId: planId, itemId: itemId, source: source);
  }

  /// Procurement records an advisory source and current availability snapshot.
  /// This never allocates or reserves warehouse stock.
  Future<void> setProposedSource({
    required String planId,
    required String itemId,
    required PlanProposedSource source,
    double? onHandQty,
    double? availableQty,
    String procurementNote = '',
  }) async {
    if (!_canActAs(UserRole.procurement)) return;
    final actor = _actor(fallbackRole: UserRole.procurement);
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId &&
            {
              MaterialPlanStatus.submitted,
              MaterialPlanStatus.procurementReview,
            }.contains(p.status))
          updated = p.copyWith(
            status: MaterialPlanStatus.procurementReview,
            items: [
              for (final i in p.items)
                if (i.id == itemId)
                  i.copyWith(
                    status: switch (source) {
                      PlanProposedSource.warehouse => PlanItemStatus.ticked,
                      PlanProposedSource.externalSupplier ||
                      PlanProposedSource.mixed => PlanItemStatus.arranged,
                      PlanProposedSource.notReviewed => PlanItemStatus.pending,
                    },
                    proposedSource: source,
                    onHandQtySnapshot: onHandQty,
                    availableQtySnapshot: availableQty,
                    procurementNote: procurementNote.trim(),
                  )
                else
                  i,
            ],
            currentOwnerRole: UserRole.procurement.name,
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                'Proposed source updated',
                actor: actor,
                detail: '$itemId · ${source.label}',
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.sourceReview');
  }

  /// Mark every outstanding item as Arranged (convenience).
  Future<void> markAllArranged(String planId) async {
    if (!_canActAs(UserRole.procurement)) return;
    final actor = _actor(fallbackRole: UserRole.procurement);
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
          updated = p.copyWith(
            status: MaterialPlanStatus.procurementReview,
            items: [
              for (final i in p.items)
                i.status == PlanItemStatus.ticked
                    ? i
                    : i.copyWith(
                        status: PlanItemStatus.arranged,
                        proposedSource: PlanProposedSource.externalSupplier,
                      ),
            ],
            currentOwnerRole: UserRole.procurement.name,
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                'All unreviewed lines proposed for external sourcing',
                actor: actor,
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.markAllArranged');
  }

  /// Procurement clicks "Mark Done" → sends the plan back to the Engineer for
  /// final review (FR). Captures the current items as the baseline so any later
  /// engineer edit shows a diff and requires re-review.
  Future<void> markPlanDone(String planId) => sendReadyForApproval(planId);

  Future<void> sendReadyForApproval(String planId) async {
    if (!_canActAs(UserRole.procurement)) return;
    final actor = _actor(fallbackRole: UserRole.procurement);
    final now = DateTime.now().toUtc();
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId &&
            p.status == MaterialPlanStatus.procurementReview &&
            p.allSourcesReviewed)
          updated = p.copyWith(
            status: MaterialPlanStatus.pendingEngineerApproval,
            baselineItems: p.baselineItems.isEmpty ? p.items : p.baselineItems,
            reviewedAt: now,
            currentOwnerRole: UserRole.engineer.name,
            updatedAt: now,
            updatedByUserId: actor.userId,
            activity: [
              ...p.activity,
              _event(
                'Ready for approval',
                actor: actor,
                detail: 'Version ${p.version} · ${p.items.length} lines',
                at: now,
              ),
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) {
      await _syncPlan(updated, kind: 'plan.readyForApproval');
    }
  }
}

// No pre-seeded demo plan — engineers build real Phase-1 plans as projects
// come in during testing/production use.
final _seedPlans = <MaterialPlan>[];
