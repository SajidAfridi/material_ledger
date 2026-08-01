# PR-08 — Phase 1 Material Planning

Status: implemented and verified on 24 July 2026.

## Delivered workflow

Engineering builds a project plan with the approved `MaterialLineGrid`, mixes
catalogue and custom items, assigns project-wide or building scope, autosaves
drafts and explicitly submits a locked version.

Procurement receives the same specification read-only. Each line shows current
on-hand/available stock when linked to the catalogue and accepts an advisory
Warehouse, External supplier or Mixed source. Comments may target the complete
plan or one line. Source review does not reserve, allocate, issue or order
stock.

When every line is reviewed, Procurement sends the version Ready for Approval.
Engineering either approves it or selects affected lines and supplies a change
reason. A revised submission creates the next version and returns to
Procurement. Final approval activates the project.

## Domain and persistence

The backward-compatible `MaterialPlan` aggregate now retains:

- stable catalogue/category/building references;
- immutable submitted versions;
- line-level proposed source and availability snapshots;
- plan/line comments;
- actor, role, timestamp, current owner and activity;
- exact Draft → Submitted → Under Procurement Review → Changes Requested →
  Ready for Approval → Approved lifecycle.

The existing idempotent `materialPlans` outbox snapshot remains the client write
seam. Database triggers validate persona transitions and project the accepted
snapshot into:

- `phase1_plans`;
- `phase1_plan_versions`;
- `phase1_plan_lines`;
- `phase1_plan_comments`;
- `phase1_plan_activity`.

All five tables use explicit authenticated read grants, project-scoped RLS and
realtime publication. Approved versions are immutable. Payloads containing
`allocatedQty`, `reservedQty` or `allocationId` are rejected.

Final approval updates the parent project in the same database transaction.
A separate project trigger rejects a transition to Active when no approved
Phase 1 plan exists.

Tracked migrations:

- `supabase/migrations/20260724044059_batch8_phase1_workflow.sql`
- `supabase/migrations/20260724044651_batch8_atomic_project_activation.sql`
- `supabase/migrations/20260724050201_batch8_project_progress_invariants.sql`

## Project progress clarification

The client’s requested project-completeness panel is implemented as reporting,
not workflow. Each project starts from the Yorks five-stage template. Admin may
add/remove/rename/reweight stages; Engineer may update progress; Procurement is
read-only. Weights must total 100. Stage changes retain actor/time and never
activate a project, approve a plan, reserve stock or change Procurement status.

## Operational fixes included

- A tracked `Nexus Chrome (Supabase)` Android Studio run target supplies the
  connected development configuration and Batch 8 flags.
- The brand asset uses an explicit oval clip.
- Phase 1 bottom action bars have bounded height.
- Building-scope rows stack on narrow/mobile widths.

## Verification and rollback

Coverage includes the full Engineer → Procurement → Engineer revision and
approval handoff, role denial, immutable versions, comments, zero stock
reservation, progress validation, circular logo and 390 px mobile layout.
Tracked pgTAP coverage exercises positive and negative RLS transitions and
atomic activation.

Rollback is application-first: disable `NEXUS_V7_PHASE1_PLANNING` and
`NEXUS_V7_PROCUREMENT_REVIEW`. Preserve normalized rows and immutable history.
Do not drop tables or rewrite approved versions during rollback.
