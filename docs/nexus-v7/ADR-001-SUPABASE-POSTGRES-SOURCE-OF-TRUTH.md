# ADR-001 — Supabase/Postgres is the Nexus production source of truth

- Status: Accepted direction
- Date: 24 July 2026
- Scope: Yorks Nexus V7 Materials & Projects transformation

## Context

The current app already contains a local `CollectionStore`, durable outbox,
realtime merge and Supabase/Postgres adapter. The V7 workflow is relational by
nature: projects, buildings, material lines, allocations, supplier quotes,
orders, receipts, quantities, revisions and audit events must remain connected.
The approved product direction also requires strict role/capability controls
around commercial information.

## Decision

Supabase/Postgres is the production system of record for Nexus. The Flutter app
may use local storage for offline drafts, cached reads and queued mutations, but
the local cache is not authoritative for committed approvals, stock allocation,
purchase orders, receipts or commercial access.

Use the existing seams and evolve them incrementally:

- Supabase Auth issues the user session and JWT.
- Postgres stores normalized Nexus records, quantities, revisions and audit
  events.
- RLS enforces row and role/capability access for exposed tables.
- Storage holds attachments; Postgres stores attachment metadata and links.
- Realtime refreshes permitted changes after the user's JWT is attached.
- Edge Functions handle genuinely privileged operations such as user
  administration and push delivery; the client never receives `service_role`.
- Server-side RPC/commands own critical transitions instead of trusting a
  generic client JSON upsert.

Firebase is not the production database or auth decision for V7. Existing push
transport code may remain as a transport integration only; it does not become
the source of truth.

## Canonical relationship graph

```text
Project
  ├─ ProjectBuilding
  ├─ MaterialPlan → MaterialPlanVersion → MaterialPlanLine
  ├─ MaterialRequest → MaterialRequestLine
  │                     ├─ FulfilmentAllocation (warehouse / external)
  │                     └─ ProcurementPackage
  │                           └─ RFQ → RFQLine → SupplierQuotation → QuotationLine
  │                                                   └─ PurchaseOrder → PurchaseOrderRevision → PurchaseOrderLine
  │                                                                       └─ DeliveryReceipt → DeliveryReceiptLine
  ├─ SupplierReceipt / WarehouseIssue / SiteDeliveryReceipt / SiteReceiptConfirmation
  ├─ Document / Attachment
  └─ Activity / ApprovalEvent / AuditEvent
```

Every downstream line must retain the source line ID. Quantities are derived
from explicit lines and transaction records, not copied display totals.

## Non-negotiable backend guardrails

1. Enable RLS on every table in an exposed schema and write policies for the
   actual project/role/capability model.
2. Never use editable `user_metadata` for authorization. Use server-controlled
   `app_metadata`/claims or relational authorization data.
3. Never expose `service_role` or secret keys to Flutter.
4. Do not rely on widget hiding for cost protection. Use protected tables,
   columns or safe views/RPC payloads, and test the response shape itself.
5. Critical commands are transactional, validated server-side and idempotent:
   allocation, RFQ creation, quote selection, PO creation, receipt posting and
   request closure.
6. Approval, revision, stock and receipt history is append-only or immutable;
   corrections create a new event/revision rather than destroying earlier data.
7. Attachments use Storage policies plus metadata RLS. A file path alone is not
   an authorization model.
8. Every migration is repeatable, backward-compatible and reviewed with
   positive/negative role tests and database advisors before release.
9. New exposed tables require explicit Data API grants as well as RLS; neither
   mechanism replaces the other.
10. Release builds fail closed when Supabase configuration is absent or partial.
    Firebase remains FCM transport only.

## Current environment and operational follow-up

`docs/supabase/PRODUCTION_STATUS.md` records a currently verified managed
project in Frankfurt. UAE residency/self-hosting is still a go-live decision;
the application must not treat the Frankfurt project as the final deployment.

Before self-hosted go-live, re-check the current Supabase deployment notes. The
24 July 2026 changelog includes upcoming self-hosted gateway and Postgres
upgrade considerations:

- [Supabase changelog](https://supabase.com/changelog.md)
- [Self-hosted Envoy gateway change](https://supabase.com/changelog/48048-self-hosted-supabase-envoy-becomes-the-default-api-gateway-b)
- [Self-hosted Postgres 15 to 17 change](https://supabase.com/changelog/46080-self-hosted-supabase-upgrading-from-pg-15-to-17-breaking-change)

This is an operational prerequisite, not a reason to change the application
architecture.

## Consequences

Positive:

- one relational source of truth for the connected lifecycle;
- server-enforced commercial and project access;
- reliable reporting over normalized quantities and documents;
- transactional/idempotent handling for inventory and procurement boundaries;
- existing offline/outbox UX can be retained while authority moves server-side.

Trade-offs:

- schema design and migration discipline are required before broad UI work;
- critical workflows need RPC/command tests, not only provider unit tests;
- local offline drafts require clear pending/unsynced status;
- hosting, backups, residency and Supabase upgrades must be operated deliberately.

## Revisit conditions

Reopen this ADR only if UAE counsel, hosting constraints or a verified
production requirement makes Supabase/Postgres infeasible. A UI preference or
short-term implementation inconvenience is not sufficient.
