# Yorks Nexus V7 — Flutter Implementation Plan

Repository: `SajidAfridi/material_ledger`
Target: Implement the approved Yorks Nexus V7 Materials & Projects experience inside the existing Flutter application without rewriting or destabilising the other company modules.

## 1. Delivery strategy

Use an incremental, vertical-slice migration:

1. Preserve the current application and backend.
2. Add the V7 domain model and migrations first.
3. Add the new UI behind feature flags.
4. Move one workflow at a time: Project Creation → Phase 1 Plan → Procurement Review → Engineer Approval → Phase 2 Material Request → Allocation → RFQ/Quote → PO/Receipt.
5. Run old and new flows side by side during pilot.
6. Remove legacy screens only after migration and client acceptance.

Do not attempt the full V7 implementation in one branch or one Codex task.

## 2. Target workflows

### Phase 1 — Project planning

`Project Draft → Planning → Material Plan Submitted → Procurement Review → Ready for Approval → Engineer Approval → Active`

The project remains in `Planning` until its material plan is approved. Keep project lifecycle and material-plan workflow as separate state machines.

### Phase 2 — Site material request

`MR Draft → Submitted → Procurement Review → Partially Sourced/Sourced → Partially Ordered/Ordered → Partially Received/Received → Closed`

An MR can be fulfilled from warehouse stock, external suppliers, or a mixture of both. Downstream RFQs, supplier quotations, POs and receipts must remain linked to the original MR lines.

## 3. Domain model

### Project aggregate

Add or migrate to:

- `yorksReference`
- `name`
- optional `secondaryName`
- `clientName`
- `contractOrJobNumber`
- `siteLocation`
- `consultant`
- `mainContractor`
- `subContractors[]`
- `otherContractors[]`
- `projectManagerUserId`
- `designEngineerUserIds[]`
- `buildings[]`
- `attachments[]`
- `lifecycleStatus`
- audit metadata

`ProjectBuilding`:

- `id`
- `code`
- `name`
- optional `floorsOrLevels`
- `hasFrpRoom` boolean only
- optional notes
- attachments
- active/archive metadata

Every plan and request line references one building, including an explicit
Project-wide/Common building scope. Required-on-site destination may add an
optional floor, area, zone or room.

### Canonical material specification

Use one shared technical specification object:

- `itemDescription`
- `sizeDisplay`
- optional structured `sizeData`
- `modelOrTag`
- `makeOrigin`
- `unitId`
- `remarks`
- category and catalogue references

Document-specific line models then add only their own quantities and workflow data:

- `MaterialPlanLine.plannedQty`
- `MaterialRequestLine.requestedQty`
- `AllocationLine.allocatedQty`
- `PurchaseOrderLine.orderedQty`
- `DeliveryReceiptLine.receivedQty`

Manufacturer serial number is receipt/asset data and is not stored in the
planning-time model/tag field. Existing `modelSerialNo` JSON remains readable
during migration.

Commercial values must not live in the engineer-readable line payload.

### Exact visible material columns

1. S:No
2. Item Description
3. Size (If any)
4. Model/Serial No.
5. Make/Origin
6. QTY
7. Unit
8. Remarks
9. Unit Cost
10. Total Cost

Cost columns are capability-controlled and may be absent entirely from the payload and export.

### Master data

Replace hard-coded enums with Admin-managed records:

- material categories
- units
- document types
- progress-stage templates
- role/capability settings

Default units:

- Nos
- Meter
- Cm
- Length
- Set
- Pairs
- Roll
- Box

Support “Custom unit…” with Admin review/archive.

## 4. Backend and security

Continue using Supabase/Postgres and the existing local outbox/realtime architecture, but move critical transitions into server-validated commands or RPCs.

Recommended command boundaries:

- `submit_project_plan`
- `mark_plan_ready_for_approval`
- `approve_project_plan`
- `submit_material_request`
- `allocate_request_line`
- `create_rfq_from_request`
- `create_po_from_quote`
- `receive_purchase_order`
- `close_material_request`

Phase 1 availability review is advisory and never calls the allocation command.
Within-plan requests route directly to Procurement. New, over-plan and
substituted items require an exception reason and approval.

Critical rules:

- stock allocation and receipt are transactional
- commands are idempotent
- audit events are server-generated and append-only
- price/cost data is stored separately and protected by RLS
- engineer sessions never receive restricted commercial values
- attachments use Supabase Storage plus metadata/RLS
- every migration is backward compatible and repeatable
- release builds fail closed when Supabase configuration is incomplete
- Firebase remains FCM transport only

## 5. Backward-compatible migration rules

### Project

- If `buildings` is absent, create one building from legacy `buildingName` and `floorNumbers`.
- Default `hasFrpRoom` to false unless known.
- Preserve legacy `authorityRef` in a migration note; do not silently convert it into an “Other Contractor”.
- Preserve old IDs and timestamps.

### Material plan/request lines

- `description` → `itemDescription`
- `size` → `sizeDisplay`
- `tagNo` → `modelOrTag` when suitable
- `brand + countryOfOrigin` → `makeOrigin`
- `note`, `RAL`, mounting, airflow and submittal reference → append to `remarks` so no legacy information is lost
- map old units to approved units; unmatched values become custom units
- migrate cost to the secure commercial table

Store a schema/data migration version and make the migration idempotent.

## 6. UI architecture

Retain the existing Riverpod, GoRouter, theme tokens and responsive shells. Add reusable V7 components:

- `NexusPageHeader`
- `ProjectWorkspaceHeader`
- `WorkspaceTabBar`
- `StatusPill`
- `CurrentActionCard`
- `AuditMeta`
- `MaterialBrowser`
- `MaterialLineGrid`
- `SmartRowToolbar`
- `SizeBuilderSheet`
- `RelatedRecordsPanel`
- `ActivityTimeline`
- `ResponsiveSideSheet`
- `ProjectReadinessCard`

### Project creation wizard

Shared by Engineer, Procurement and Admin:

1. Essentials & Responsibility
2. Buildings
3. Review & Create

Requirements:

- autosaved draft
- duplicate Yorks-reference validation
- multiple addable buildings
- floors optional
- FRP room Yes/No only
- review screen before commit
- creator/role/timestamps recorded automatically
- parties remain optional within the first stage
- attachments are optional and inline or added from the workspace

### Material grid

Desktop:

- direct cell editing
- Tab/Shift+Tab and Enter navigation
- paste from Excel
- sticky header and S:No
- row selection
- undo/redo
- Add Blank Row
- Add Similar Row
- size popup
- CSV export
- validation without losing draft data

Mobile/tablet:

- compact row cards
- tap row to open focused editor
- camera/file attachments
- sticky Save/Add action

Smart Similar Row copies:

- Item Description
- Size
- Make/Origin
- Unit
- Remarks

It clears:

- S:No
- Model/Serial No.
- QTY
- Unit Cost
- Total Cost

Do not auto-increment manufacturer serial numbers. Model/equipment tags may be
copied only through an explicit user action.

## 7. PR roadmap

### PR-00A — Final product contract

- freeze workflow, quantity, approval and receiving decisions
- reconcile the SRS and mark Firebase/Firestore notes as legacy
- remove weighted project completeness from the MVP contract
- no product behaviour changes

### PR-00B — Baseline, CI and security configuration

- add GitHub Actions: format, analyze, test, web build
- add feature flags
- exclude generated build artifacts from repository analysis
- fail closed when release backend configuration is missing
- remove shared production credentials from source-controlled instructions
- prohibit privileged role inference from email or editable metadata
- stop commercial fields entering shared material payloads
- no product behaviour changes

### PR-01 — Domain models and migrations

- new project/building/party models
- canonical material line specification
- dynamic units/categories models
- backward-compatible JSON decoding
- migration tests

### PR-02 — Secure commercial data

- separate commercial/cost records
- add `viewCommercials` capability
- RLS and role tests
- cost-safe queries and CSV exports
- remove restricted values from engineer payloads

### PR-03 — V7 visual foundation

- tokens and reusable components
- responsive page shell
- status/action/audit components
- golden tests
- no workflow changes

### PR-04 — Project creation flow

- replace role-specific one-page form
- three-stage responsive flow
- multiple buildings and FRP Yes/No
- optional inline attachments metadata
- review/create
- autosave and validation
- role access for Engineer, Procurement and Admin

### PR-05 — Project workspace and readiness

- project workspace route
- Overview, Material Plan, Requests, Procurement, Documents, Activity
- current action, blockers and connected-record readiness
- current action owner and audit metadata

### PR-06 — Dynamic masters and Browse Materials

- Admin-managed categories and units
- complete HVAC browser
- search/filter
- role-safe stock/cost display
- custom material/unit flow
- CSV export

### PR-07 — Reusable material line grid

- exact ten-column schema
- smart row behaviour
- structured size builder
- keyboard/paste support
- validation and autosave
- desktop/mobile adaptations

### PR-08 — Phase 1 plan workflow

- plan draft and version tables
- plan lines
- procurement availability/source review and comments
- diff view
- engineer approval/rejection
- activate project after approval
- append-only activity

### PR-09 — Simplified Phase 2 Material Request

- three-step flow: Project/Building → Materials → Review/Submit
- same browser and grid as Phase 1
- draft autosave
- normal/urgent
- required-on-site date and destination
- plan balance with exception reason/approval for new, over-plan or substituted lines
- procurement notification and queue
- status visibility for engineer

### PR-10 — Procurement package, RFQ and quotation comparison

- warehouse/external split
- procurement package
- RFQ and supplier recipients
- supplier quotations and line comparison
- price, VAT/delivery, lead time, availability, validity and technical compliance
- source selection without re-entering MR lines

### PR-11 — Purchase Orders, revisions and delivery receipts

- create PO from selected quote
- immutable PO revisions
- partial ordering and partial receipt
- packing slip/delivery document uploads
- separate Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt Confirmation
- accepted, short, damaged and rejected quantities
- ordered/received/outstanding quantities
- downstream status propagation to MR

### PR-12 — Hardening and rollout

- end-to-end tests
- RLS penetration tests
- 500-row grid benchmark
- offline/reconnect tests
- responsive/RTL audit
- Nexus seed dataset
- migration dry run
- pilot feature flags and rollback procedure

## 8. Definition of done for every PR

- scoped issue and acceptance criteria
- no unrelated module changes
- `dart format --set-exit-if-changed .`
- `flutter analyze`
- `flutter test`
- relevant widget/golden/integration tests
- old JSON remains readable
- no restricted cost data leaks
- actor and timestamp captured for workflow events
- English/secondary-language strings use the existing localisation system
- desktop, tablet and mobile manually checked
- PR includes screenshots for UI work
- rollback/migration note included

## 9. Rollout

1. Deploy schema and code to Development.
2. Seed a copy of the Nexus project.
3. Run Engineer + Procurement end-to-end acceptance.
4. Enable V7 only for pilot users.
5. Run both legacy and V7 screens in parallel.
6. Migrate existing projects and inspect the report.
7. Enable all users.
8. Keep legacy read-only routes for one release.
9. Remove legacy screens only after client sign-off.

## 10. Do not do these

- Do not ask Codex to “implement V7” in one task.
- Do not start with visual screens before model/RLS migrations.
- Do not keep workflow state as unrelated booleans.
- Do not hide costs only in Flutter.
- Do not copy HTML prototype code directly into Flutter.
- Do not let two parallel agents edit the same core model/provider.
- Do not delete legacy data or screens before the pilot passes.
