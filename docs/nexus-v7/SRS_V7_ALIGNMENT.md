# Yorks Nexus V7 — SRS Alignment and Supersession Record

Status: approved conflict resolution for V7 implementation.

The existing SRS remains a source of business intent and legacy acceptance
history. The following entries supersede its outdated technical assumptions and
ambiguous workflow language for the V7 Materials and Projects transformation.

## Authority

When a listed SRS requirement conflicts with
`PRODUCT_DECISIONS.md`, the V7 decision applies. Requirements unrelated to
Projects, Browse Materials, Phase 1 planning, Procurement Review and Phase 2
requests remain unchanged.

## Required rewrites

| SRS area | V7 decision |
|---|---|
| Firebase Authentication | Superseded by Supabase Auth. |
| Firestore database and rules | Superseded by normalized Postgres, RLS and server commands. |
| Firebase deployment commands | Superseded by Flutter CI, versioned Postgres migrations and controlled environment deployment. |
| Firestore transactions | Superseded by Postgres transactions and idempotent server commands. |
| Firebase uptime/scaling language | Replaced with backend-neutral service objectives and tested Postgres query/load targets. |
| External PO handling out of scope | Superseded for V7: RFQ, quotation, PO revision and receipt continuity are approved later batches. |
| One building per project | Superseded by repeatable ProjectBuilding records and optional floors. |
| Authority Reference | Removed from new V7 entry. Existing `authorityRef` is retained only as legacy migration data and is never reinterpreted as Other Contractor. |
| Other Contractors replaces Authority Reference | Applies to the new UI only; it is not a data migration mapping. |
| Plan “Mark Done” | Replaced with Ready for Approval. |
| Procurement “Arranged” | Replaced with explicit availability/source states. |
| Automatic stock green tick/reservation | Availability is advisory in Phase 1. Allocation is explicit and server-confirmed in Phase 2. |
| Phase 2 request | Adds required-on-site date, destination, plan balance and exception handling. |
| Admin delete project/request | Replaced by archive, cancel, void or corrective revision after downstream activity exists. |
| RAL required broadly | RAL is category-dependent. |
| Hard-coded categories/units | Replaced by Admin-managed master data. |
| English-only operation | Superseded by English plus the configured secondary-language framework. |
| Internet required for all work | Drafts and queued mutations may work offline; committed approvals/orders/receipts require server confirmation. |
| “Every action” audit requirement | Replaced by an explicit critical audit-event matrix plus separate activity/comments. |
| Ten versus fifty concurrent users | One release load profile must be defined and tested; contradictory targets are invalid. |

## Consolidations

The duplicated notification requirements become one notification-event matrix.
Duplicated audit, security, deletion and comment requirements become the
separate Comment, Activity and Audit contracts in `PRODUCT_DECISIONS.md`.

## Requirements promoted to mandatory

- Immutable material-plan versions and diffs
- Source-line continuity through MR, allocation, RFQ, quote, PO and receipt
- Partial ordering and partial receiving
- Commercial-value absence from unauthorized responses and caches
- Required-on-site date and destination
- Receipt discrepancies and evidence
- Server-side idempotency and quantity reconciliation
- Positive and negative RLS tests

## Optional or deferred requirements

- Attachments during initial project creation
- Detailed parties before the project draft is created
- Floors when unknown
- RAL for irrelevant categories
- arbitrary custom fields
- full offline transaction commitment
- weighted project completion and construction-stage progress

## Acceptance language

V7 acceptance uses the checklist in
`NEXUS_V7_ACCEPTANCE_CHECKLIST.md`. Legacy acceptance statements remain useful
only where they do not conflict with this alignment record.
