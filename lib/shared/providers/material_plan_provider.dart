import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_plan.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';
import '../sync/sync_engine.dart';

const _kPlansKey = 'material_plans_list_v2';
const _uuid = Uuid();

/// All Phase 1 material plans (one per project).
final materialPlansProvider =
    StateNotifierProvider<MaterialPlansNotifier, List<MaterialPlan>>((ref) {
      return MaterialPlansNotifier(
        ref,
        ref.watch(storageProvider).collection<MaterialPlan>(
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
    final plan = MaterialPlan(
      id: 'plan-${_uuid.v4().substring(0, 8)}',
      projectId: projectId,
    );
    upsertPlan(plan);
    return plan;
  }

  /// Engineer submits the plan to procurement (FR-020). If the plan had
  /// already been arranged (has a baseline) this is an edit-after-arrangement,
  /// so it returns to procurement re-review and the diff is preserved
  /// (FR-030/031); otherwise it is a first submission.
  Future<void> submitPlan(String projectId, List<PlanItem> items) async {
    final existing = planForProject(projectId);
    final wasArranged = existing != null && existing.baselineItems.isNotEmpty;
    final plan =
        (existing ??
                MaterialPlan(
                  id: 'plan-${_uuid.v4().substring(0, 8)}',
                  projectId: projectId,
                ))
            .copyWith(
              items: items,
              status: wasArranged
                  ? MaterialPlanStatus.procurementReview
                  : MaterialPlanStatus.submitted,
              submittedAt: DateTime.now(),
              version: (existing?.version ?? 0) + 1,
            );
    await upsertPlan(plan);
  }

  /// Engineer gives final approval (FR-029). Caller activates the project.
  Future<void> approvePlan(String planId) async {
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
          updated = p.copyWith(
            status: MaterialPlanStatus.approved,
            approvedAt: DateTime.now(),
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
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
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
                  authorName: authorName,
                  authorRole: 'Engineer',
                  text: comment.trim(),
                  timestamp: DateTime.now(),
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
  }) async {
    if (text.trim().isEmpty) return;
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
          updated = p.copyWith(
            comments: [
              ...p.comments,
              PlanComment(
                authorName: authorName,
                authorRole: authorRole,
                text: text.trim(),
                timestamp: DateTime.now(),
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
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
          updated = p.copyWith(
            status: MaterialPlanStatus.procurementReview,
            items: [
              for (final i in p.items)
                if (i.id == itemId) i.copyWith(status: status) else i,
            ],
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.itemStatus');
  }

  /// Mark every outstanding item as Arranged (convenience).
  Future<void> markAllArranged(String planId) async {
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
                    : i.copyWith(status: PlanItemStatus.arranged),
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
  Future<void> markPlanDone(String planId) async {
    MaterialPlan? updated;
    state = [
      for (final p in state)
        if (p.id == planId)
          updated = p.copyWith(
            status: MaterialPlanStatus.pendingEngineerApproval,
            baselineItems: p.items,
            submittedAt: DateTime.now(),
          )
        else
          p,
    ];
    await _persist();
    if (updated != null) await _syncPlan(updated, kind: 'plan.markDone');
  }
}

// No pre-seeded demo plan — engineers build real Phase-1 plans as projects
// come in during testing/production use.
final _seedPlans = <MaterialPlan>[];
