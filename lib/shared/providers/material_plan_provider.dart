import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/material_plan.dart';
import '../repositories/collection_store.dart';
import '../repositories/storage.dart';

const _kPlansKey = 'material_plans_list_v1';
const _uuid = Uuid();

/// All Phase 1 material plans (one per project).
final materialPlansProvider =
    StateNotifierProvider<MaterialPlansNotifier, List<MaterialPlan>>((ref) {
      return MaterialPlansNotifier(
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
  MaterialPlansNotifier(this._store)
    : super(_store.isSeeded ? _store.readAll() : _seedPlans) {
    if (!_store.isSeeded) _store.writeAll(state);
  }

  final CollectionStore<MaterialPlan> _store;

  Future<void> _persist() => _store.writeAll(state);

  MaterialPlan? planForProject(String projectId) {
    for (final p in state) {
      if (p.projectId == projectId) return p;
    }
    return null;
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
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
            status: MaterialPlanStatus.approved,
            approvedAt: DateTime.now(),
          )
        else
          p,
    ];
    await _persist();
  }

  /// Engineer rejects specific items with a reason (FR-027/FR-028).
  Future<void> requestChanges({
    required String planId,
    required Set<String> rejectedItemIds,
    required String comment,
    required String authorName,
  }) async {
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
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
  }

  Future<void> addComment({
    required String planId,
    required String text,
    required String authorName,
    String authorRole = 'Engineer',
  }) async {
    if (text.trim().isEmpty) return;
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
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
  }

  // ─── Procurement actions (FR plan review) ────────────────────────

  /// Procurement sets a single item's arrangement status (Arranged / In stock).
  Future<void> setItemStatus(
    String planId,
    String itemId,
    PlanItemStatus status,
  ) async {
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
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
  }

  /// Mark every outstanding item as Arranged (convenience).
  Future<void> markAllArranged(String planId) async {
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
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
  }

  /// Procurement clicks "Mark Done" → sends the plan back to the Engineer for
  /// final review (FR). Captures the current items as the baseline so any later
  /// engineer edit shows a diff and requires re-review.
  Future<void> markPlanDone(String planId) async {
    state = [
      for (final p in state)
        if (p.id == planId)
          p.copyWith(
            status: MaterialPlanStatus.pendingEngineerApproval,
            baselineItems: p.items,
            submittedAt: DateTime.now(),
          )
        else
          p,
    ];
    await _persist();
  }
}

// ─── Seed: one arranged plan awaiting the engineer's approval ───────
final _seedPlans = <MaterialPlan>[
  MaterialPlan(
    id: 'plan-proj-001',
    projectId: 'proj-001',
    status: MaterialPlanStatus.pendingEngineerApproval,
    submittedAt: DateTime.now().subtract(const Duration(days: 1)),
    baselineItems: _proj001Items,
    items: _proj001Items,
  ),
];

const _proj001Items = <PlanItem>[
  PlanItem(
    id: 'pi-1',
    description: 'Copper pipe 22mm (Type L)',
    descriptionSecondary: 'تانبے کا پائپ 22mm',
    brand: 'Mueller',
    size: '22mm',
    quantity: 120,
    unitSymbol: 'm',
    status: PlanItemStatus.ticked,
  ),
  PlanItem(
    id: 'pi-2',
    description: 'GI duct sheet 24G',
    descriptionSecondary: 'جی آئی ڈکٹ شیٹ',
    size: '4x8 ft',
    quantity: 40,
    unitSymbol: 'sheets',
    status: PlanItemStatus.ticked,
  ),
  PlanItem(
    id: 'pi-3',
    description: 'Supply grille (powder-coated)',
    descriptionSecondary: 'سپلائی گرل',
    brand: 'Systemair',
    size: '600x600mm',
    quantity: 24,
    unitSymbol: 'nos',
    ralColour: 'RAL 9010',
    status: PlanItemStatus.arranged,
  ),
  PlanItem(
    id: 'pi-4',
    description: 'Fire damper 300mm',
    descriptionSecondary: 'فائر ڈیمپر',
    size: '300mm',
    quantity: 6,
    unitSymbol: 'nos',
    ralColour: 'RAL 9006',
    status: PlanItemStatus.lowStock,
  ),
  PlanItem(
    id: 'pi-5',
    description: 'Special GI bracket (fabricated)',
    descriptionSecondary: 'خصوصی جی آئی بریکٹ',
    brand: 'Local fab',
    countryOfOrigin: 'UAE',
    size: '150x80mm',
    quantity: 50,
    unitSymbol: 'nos',
    isCustom: true,
    status: PlanItemStatus.arranged,
    note: 'Sourced externally — sample approved on site',
  ),
];
