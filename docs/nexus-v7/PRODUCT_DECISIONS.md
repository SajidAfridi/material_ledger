# Yorks Nexus V7 — Frozen Product and Transaction Decisions

> **Historical as of 1 August 2026.** These decisions are superseded for the
> overlapping Yorks V1 Rev 2.0 scope. Use
> [`../yorks-v1/PRODUCT_DECISIONS.md`](../yorks-v1/PRODUCT_DECISIONS.md).
> Non-conflicting security, data-preservation and unrelated-module safeguards
> survive through the new V1 contract.

Status: approved implementation contract for Batch 1 onward.

This document resolves the open product and data questions identified during the
final design review. It is authoritative when the approved visual prototype,
legacy SRS, or older implementation notes use ambiguous terminology.

## 1. Platform boundary

- Flutter, Riverpod and GoRouter remain the application foundation.
- Supabase Auth and Postgres are the production identity and data authority.
- Supabase Realtime may refresh permitted data, but it is not a transaction
  authority.
- Firebase is allowed only as Firebase Cloud Messaging transport. Firestore,
  Firebase Auth and Firebase Remote Config are not Nexus systems of record.
- Local storage supports cached reads, drafts and queued mutations. It is never
  authoritative for approvals, allocations, purchase orders, receipts, audit or
  commercial access.
- A release build without a complete Supabase URL and publishable key must fail
  closed. Local-only mode is explicit development behavior only.

## 2. Project creation and workspace

Browser project creation has three stages:

1. Essentials and Responsibility
2. Buildings
3. Review and Create

Mobile uses the same information in a shorter focused flow. Parties are an
optional section within Essentials and Responsibility. Attachments are optional
and may be added inline or from the project workspace; they are not a mandatory
wizard stage.

Every project supports multiple buildings. Floors or levels are optional. A
project-wide/common building scope is used for material lines that genuinely do
not belong to one physical building.

The workspace shows readiness, current action, blockers and connected records.
It may also show a separate project-specific physical/technical progress report.
The standard Yorks template is Cooling Load Design, Material Supply, Progress
Installation, Commissioning & Handover and Energizing Substation. Admin may
change stage names and weights per project; Engineer may update percentages;
Procurement is read-only. Weights must total 100 and every change records actor
and time. This report never changes readiness, lifecycle, approval, inventory or
procurement status.

## 3. Canonical status language

Project:

`Draft → Planning → Active → Archived`

Material Plan:

`Draft → Submitted → Under Procurement Review → Changes Requested → Ready for Approval → Approved → Superseded`

Material Request:

`Draft → Submitted → Under Procurement Review → Partially Sourced → Sourced → Partially Ordered → Ordered → Partially Received → Received → Closed`

RFQ:

`Draft → Sent → Responses Pending → Responses Received → Closed / Cancelled`

Purchase Order:

`Draft → Issued → Partially Received → Received → Closed / Cancelled`

Delivery Receipt:

`Draft → Posted → Corrected`

Do not introduce workflow statuses named `Arranged`, `Done`, `Processed` or
`Dispatched` without a direction-specific noun. Aggregate statuses are derived
from line transactions; they are not independently editable labels.

Every actionable record shows its current owner, next action, blocker and
required date.

## 4. Quantity vocabulary and invariants

- `requested_qty`: field requirement on an MR line.
- `on_hand_qty`: physical quantity recorded at a warehouse.
- `available_qty`: on hand minus active allocations and unavailable stock.
- `allocated_qty`: quantity explicitly committed from a warehouse.
- `to_purchase_qty`: external quantity Procurement intends to source.
- `ordered_qty`: quantity on an issued, non-cancelled PO line.
- `in_transit_qty`: ordered quantity not yet accepted at its destination.
- `received_qty`: accepted quantity recorded by posted receipts.
- `short_qty`: expected but not delivered.
- `damaged_qty`: delivered but damaged.
- `rejected_qty`: delivered but not accepted.
- `remaining_qty`: requested quantity not yet fulfilled or formally cancelled.

Phase 1 availability review is advisory and does not reserve stock. Allocation
occurs only during Phase 2 procurement through a server-confirmed transaction.

Line-level source quantities must reconcile. A workflow may not close while an
unresolved positive remaining quantity exists.

## 5. Plan and request rules

- Every material-plan line is building-scoped, including the explicit
  project-wide/common scope.
- Approved plans are immutable baselines. Corrections create a new version and
  preserve the complete prior version and diff.
- A Phase 2 request may reference an approved plan line.
- A within-plan request that does not change the technical specification routes
  directly to Procurement.
- A new item, over-plan quantity or technical substitution requires a concise
  exception reason and authorized approval.
- Emergency requests remain possible and auditable.
- Required-on-site date and delivery destination are mandatory at submission.
  Destination includes project and building, with floor/area/zone/room when
  known.

## 6. HVAC material specification

The approved visible column label `Model/Serial No.` remains unchanged until
Yorks explicitly approves a visual relabel. The data model separates:

- model or equipment tag, which may be known during planning; and
- manufacturer serial number, which normally becomes known at receipt or asset
  registration.

Category-specific HVAC details remain in a focused inspector or mobile editor,
not additional standard grid columns. Relevant details include duty/capacity,
airflow, pressure/class, material/gauge, approved equal/substitution, drawing or
submittal reference, installation area and conditional RAL colour.

The canonical specification is a reusable immutable value shape. Historical
transaction lines snapshot their display and technical values so later master
data edits cannot rewrite history.

## 7. Procurement decisions

- A Procurement Package groups selected MR lines; it is not a child of an
  allocation.
- A request line can split across warehouse stock and multiple suppliers.
- Inventory auto-check produces a proposed allocation only. Procurement
  explicitly confirms it.
- A hold requires a reason, next action owner and follow-up date.
- Quote comparison includes price, VAT treatment, delivery charges, lead time,
  availability, validity, payment terms, technical compliance and substitution
  status.
- RFQ, quotation and PO lines reuse the source material specification and retain
  source line IDs. No user re-enters the same item.
- PO revisions are immutable. A correction creates a new revision and preserves
  earlier issued values.

## 8. Receipt and stock directions

These are separate business events:

- Supplier Receipt: supplier to warehouse.
- Warehouse Issue: warehouse to project/site.
- Site Delivery Receipt: supplier or warehouse to site.
- Site Receipt Confirmation: site engineer confirms accepted physical delivery.

Receipts record delivered, accepted, short, damaged and rejected quantities,
support delivery-note/photo evidence, and assign unresolved discrepancies to an
owner. A posted correction creates a correcting event; it does not overwrite
the original receipt.

## 9. Identity, numbering and concurrency

- New relational records use UUID primary keys.
- `auth.users.id` is the authentication identity. A profile row references that
  UUID and preserves the legacy `AppUser.id` as a unique migration identifier.
- Human document numbers for MR, RFQ, PO and receipt are allocated server-side
  on first submission or issue, never by an offline client.
- Drafts may be edited offline. Committed transitions require the server.
- Concurrent draft updates use a version check. A stale writer receives a
  conflict and must review/merge; committed workflow records never use blind
  last-write-wins.

## 10. Master data and administration

- Admin owns units, categories, suppliers, warehouses and material templates.
- Procurement may request or propose a new supplier/material, but cannot silently
  mutate historical master data.
- Used master records are archived rather than deleted.
- Cost visibility is capability-based and enforced in database access, response
  shape, cache, export, print and notifications.
- Custom fields are limited to controlled category attributes. The MVP has no
  general custom-field or workflow builder.

## 11. Deletion and history

After downstream activity exists, projects and procurement documents cannot be
hard-deleted. Use archive, cancel, void or a correcting revision with a reason.
Comments, activity and audit are separate. Critical audit events are
server-generated and append-only.

## 12. Explicitly outside this transformation

- Rentals and HR redesign
- accounting integration
- supplier portal
- barcode/QR workflows
- AI recommendations
- advanced analytics or report builders
- full return/RMA management
- arbitrary saved layouts
- detailed programmes, Gantt scheduling or task-level progress management
- full offline approval, allocation, PO or receipt commitment
