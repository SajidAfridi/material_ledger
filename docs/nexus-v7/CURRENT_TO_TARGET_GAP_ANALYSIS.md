# Yorks Nexus V7 — Current-to-Target Gap Analysis

Status: baseline audit completed 24 July 2026. This is an evidence-based
planning document, not authorization to rewrite the application.

## 1. Current repository map

### Application shell and navigation

- `lib/main.dart` bootstraps the app, optional Supabase, observability and
  notifications.
- `lib/app/router.dart` owns GoRouter paths, role redirects and the current
  engineer/office shells. Existing routes include `/projects`, `/projects/new`,
  `/new-request`, `/request/:id`, `/admin/procurement`, `/admin/dispatch/:id`,
  `/plan/*`, `/receipt/:id`, `/materials` and `/admin/projects`.
- `lib/app/app_shell.dart` and `lib/app/engineer_shell.dart` provide the
  existing responsive navigation surfaces.

### Existing domain and state seams

- `lib/shared/models/project.dart` contains `Project`, `ProjectPhase` and the
  legacy `RequestLineItem`. `Project` is currently a flat record with one
  `buildingName`, one `floorNumbers` string, `authorityRef`, one assigned
  engineer and lifecycle flags.
- `lib/shared/models/material_plan.dart` contains `MaterialPlan`, `PlanItem`
  and `PlanComment`. It already has plan status, arrangement status, baseline
  items, comments and a version integer, but the line model is not the approved
  canonical V7 line specification.
- `lib/shared/models/material_request.dart` contains `MaterialRequest`,
  `RequestComment` and the imported `RequestLineItem`. It has project name and
  optional project ID, request status/priority, comments and dispatched/received
  quantities, but no procurement package, RFQ, quotation, PO or delivery
  receipt relationship model.
- `lib/shared/models/material_item.dart` is the inventory catalogue model. It
  currently includes stock, reserved quantity, unit price, category/unit enums,
  brand/origin and size.
- `lib/shared/models/goods_receipt.dart` represents a stock receipt, not the V7
  site delivery-receipt aggregate linked to a PO and receipt lines.
- `lib/shared/models/audit_log.dart` and
  `lib/shared/providers/audit_log_provider.dart` provide an audit surface, but
  critical V7 transitions still need server-generated append-only events.

### Providers and workflow logic

- `lib/shared/providers/project_provider.dart` persists projects through the
  `CollectionStore`, syncs them through the outbox, supports soft delete,
  procurement acceptance and project activation.
- `lib/shared/providers/material_plan_provider.dart` handles plan upsert,
  submit, arrange, comments, approval, requested changes and activation.
- `lib/shared/providers/material_request_provider.dart` handles draft/submit,
  reservation, dispatch, comments, line edits, hold/cancel and engineer receipt
  confirmation. It already clamps receipt to dispatched quantity and keeps
  partial work open.
- `lib/shared/providers/inventory_provider.dart` owns stock, reservations,
  dispatch/receipt mutations and the stock movement ledger.
- `lib/shared/providers/goods_receipt_provider.dart` records warehouse goods
  receipts and weighted-average stock cost; it is not yet a PO delivery receipt
  workflow.
- `lib/shared/providers/role_permissions_provider.dart` and
  `lib/shared/providers/users_provider.dart` implement the current capability
  matrix and claim restamping seam.

### Supabase, offline and sync

- `lib/shared/repositories/collection_store.dart`,
  `lib/shared/repositories/local_store.dart` and
  `lib/shared/repositories/storage.dart` provide local persistence abstraction.
- `lib/shared/sync/outbox.dart`, `mutation_op.dart`, `sync_engine.dart` and
  `supabase_sync_backend.dart` provide queued generic upsert sync.
- `lib/shared/sync/supabase_bootstrap.dart` hydrates and union-merges remote
  rows; `lib/shared/sync/realtime_sync.dart` listens with the user's JWT.
- `docs/supabase/schema.sql` and `docs/supabase/PRODUCTION_STATUS.md` document
  the current claim-based RLS and Supabase deployment. The current recorded
  managed project is Frankfurt; UAE residency/self-hosting remains a go-live
  decision.
- `supabase/functions/admin-users` handles privileged identity administration;
  `supabase/functions/send-push` is a push transport integration. The client
  does not hold `service_role`.

### Existing tests

The suite already covers request dispatch, partial receipt, reservation
reconciliation, stock movement, project register behaviour, local decoding,
outbox/reconnect, role permissions, notifications, routing and sync merging.
Representative files include `test/materials_flow_test.dart`,
`test/dispatch_logic_test.dart`, `test/project_register_test.dart`,
`test/stock_movement_test.dart`, `test/sync_integration_test.dart`,
`test/sync_merge_test.dart`, `test/role_permissions_test.dart` and
`test/supabase_sync_backend_test.dart`.

## 2. Current versus V7 target

| Area | Current evidence | V7 target | Gap severity |
|---|---|---|---|
| Project identity | Flat `Project`; legacy building/floor strings; `authorityRef` | Unique Yorks reference, parties, repeatable buildings, optional floors, FRP boolean, attachments and metadata | High |
| Material specification | `PlanItem` and `RequestLineItem` use different fields and names | One canonical technical specification shared by plan/MR/all downstream lines | High |
| Workflow state | Enums and provider methods exist, but state transitions are mostly client-side | Explicit state machines for plan, MR, package, RFQ, PO and receipt with server validation | High |
| Procurement documents | No first-class RFQ, supplier quotation, PO or PO revision models | Linked package → RFQ → quote comparison → immutable PO revisions → partial receipts | Critical |
| Quantity reconciliation | Request line tracks requested/dispatched/received and inventory reservations | Requested/allocated/ordered/received/outstanding derived across MRLine, allocation, POLine and receipt lines | High |
| Project workspace | Project and plan/request screens exist separately | Project as a container of connected registers, documents, activity and current owner | High |
| Engineer/procurement separation | Role routes and capability matrix exist | Mobile field flow and desktop procurement flow with server-safe payloads | High |
| Commercial data | Inventory and historical models contain cost; audit notes a remaining API/cache leak risk | Separate protected commercial boundary; no restricted cost in engineer payload/cache/export | Critical |
| Auditability | Local audit provider and synced audit infrastructure exist | Server-generated append-only events for all approvals, allocations, revisions, orders and receipts | High |
| Attachments | Existing app has document/notification seams, but no V7 transaction attachment graph | Storage objects plus metadata linked to project/building/MR/PO/receipt and protected by RLS | High |
| Master data | Units and categories are Dart enums/seeded records | Admin-managed categories, units, document types and stage templates | Medium |
| Offline semantics | Durable outbox, soft-delete and realtime merge exist | Offline drafts; critical transitions only commit after server validation and remain idempotent | High |
| UI foundation | Existing Architectural Ledger tokens and screens | Approved Nexus shell, workspace, grids, side-by-side sourcing, mobile row editor | High |
| Test proof | Good legacy regression coverage | V7 model migrations, state machines, RLS matrix, integration, responsive/golden and benchmark coverage | High |

## 3. Target lifecycle

### Project and Phase 1 plan

`Project Draft → Planning → Material Plan Submitted → Procurement Review → Ready for Approval → Engineer Approval → Active`

Project lifecycle and material-plan lifecycle remain separate. A project becomes
Active only after the final material-plan approval command succeeds.

### Phase 2 request and procurement

`MR Draft → Submitted → Procurement Processing → Partially Ordered / Ordered → Partially Received / Received → Closed`

The request is the source of truth for the field need. It may be fulfilled by
warehouse stock, one supplier or several suppliers. Every downstream line keeps
its `source_mr_line_id` and allocated/ordered/received quantities.

## 4. Backward-compatible migration rules

1. Keep existing JSON decoders working throughout the migration. Additive
   fields and explicit schema/data version markers are required.
2. If a legacy project has `buildingName` or `floorNumbers` but no buildings,
   materialise one `ProjectBuilding` with `hasFrpRoom = false` and preserve the
   original values in migration metadata.
3. Preserve `authorityRef` in a legacy migration note. Never reinterpret it as
   an Other Contractor.
4. Map legacy line data as follows:
   `description → itemDescription`, `size → sizeDisplay`,
   `tagNo → modelSerialNo` when suitable, `brand + countryOfOrigin → makeOrigin`.
5. Append legacy `note`, RAL, mounting, airflow and submittal references to
   `remarks` when they do not have a V7 standard column. No information may be
   silently dropped.
6. Map known units to managed unit IDs; unmatched units become reviewable
   custom units.
7. Move commercial values into the protected commercial boundary before any
   engineer-readable payload is emitted.
8. Use stable IDs and source-link fields. Never create downstream records by
   copying only display names.
9. Keep legacy screens read-only or side-by-side during the pilot; do not delete
   them until migration and acceptance evidence is complete.

## 5. Delivery sequence

1. Baseline, documentation, CI and feature flags.
2. Project/building and canonical line models with migration tests.
3. Protected commercial data and RLS negative tests.
4. Visual foundation and shared responsive components.
5. Project creation wizard and project workspace.
6. Managed units/categories and Browse Materials.
7. Reusable MaterialLineGrid.
8. Phase 1 plan and approval vertical slice.
9. Phase 2 Material Request vertical slice.
10. Procurement package, RFQ and quotation comparison.
11. PO revisions, partial receipts and status propagation.
12. Hardening, migration dry run, pilot rollout and rollback rehearsal.

The supplied `NEXUS_V7_IMPLEMENTATION_PLAN.md` and `CODEX_TASKS.md` remain the
authoritative detailed task definitions.

## 6. Resolved decisions before schema implementation

The final review decisions are frozen in `PRODUCT_DECISIONS.md`:

- `auth.users.id` is the authentication identity; the profile preserves legacy
  `AppUser.id` as a unique migration identifier;
- Admin owns supplier and warehouse masters; Procurement may propose additions;
- Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt
  Confirmation are explicitly separate;
- plans use a parent plus immutable version and line rows;
- commercial access is capability-based and enforced in payloads, caches and
  exports;
- stale offline draft updates fail a version check and require review/merge;
- internal IDs are UUIDs and human document numbers are server-allocated on
  first submission/issue;
- every plan line is building-scoped, including Project-wide/Common;
- Phase 1 availability review never reserves stock.

UAE residency, backups and disaster recovery remain production operational
decisions, not reasons to leave the domain model ambiguous.

## 7. Risks to keep visible

- generic JSONB upserts can bypass invariants if used for critical transitions;
- RLS can protect rows but not accidentally leaked fields in a broad payload;
- quantity totals can drift if allocation/order/receipt writes are not
  transactional and idempotent;
- client-side status booleans can create impossible states;
- an offline local write must not be mistaken for a committed approval/order;
- a visual prototype can hide missing empty, error, partial and permission
  states;
- changing old field meaning can corrupt historic jobs.
