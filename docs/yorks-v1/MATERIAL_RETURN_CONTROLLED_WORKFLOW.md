# Yorks V1 — Controlled Project Material Return Workflow

Status: implemented additive Yorks V1 extension, 24 August 2026.

## Purpose

Material Returns are a first-class project workflow for surplus or recoverable
material sent from site back to the Yorks warehouse. A return belongs to the
project and scope, so close-out users do not need to remember which historical
Material Request originally delivered every item.

## Lifecycle and ownership

`draft -> awaiting_approval -> approved -> dispatched -> confirmed`

- Project stakeholders with Engineering return authority create drafts from
  eligible delivered material and/or explicitly marked custom rows.
- An assigned Project Engineer, an organization-wide Engineering approver or
  Admin approves, returns for changes or rejects the submitted return.
- The approved-return owner records driver, vehicle and delivery-note evidence
  when materials leave site.
- Procurement or Admin reconciles every line as good, damaged or not received
  and confirms the physical warehouse handover.

Return-for-changes goes back to an editable draft. Rejection and cancellation
are terminal and require a reason. No pre-confirmation transition changes
warehouse stock.

## Traceability and quantity control

Delivered candidates are calculated across the selected project and scope from
receipt-review lines. The available quantity is good received minus quantities
already approved, dispatched or confirmed on other returns.

Every delivered return line freezes its receipt-review line, Material Request,
dispatch, item description, brand/origin, unit and source kind. Custom lines
freeze a custom provenance marker and must be mapped by Procurement to an
existing or newly created inventory item before any good quantity can enter
stock.

Submission and confirmation lock the return and affected receipt or inventory
rows, recheck record versions and quantities, then commit atomically. A repeated
idempotency key returns the original result and cannot duplicate numbers,
movements, notifications or audit events.

## User experience

The Material Return Centre is independent from Material Request detail. It has
an authorized project register, state/search filters, responsive cards, an
Excel-style desktop line editor and a mobile one-row card editor.

The detail view shows project/scope, lifecycle status, current ownership,
source trace, dispatch evidence and line-level warehouse outcomes. Server
capabilities control all actions; the client does not infer approval,
dispatch, receipt or cancellation authority.

## Controlled outputs

Excel export includes No., Item Description, Brand/Origin, Qty., Unit, Source
trace and Note. PDF and print share one renderer with the Yorks bilingual
header, project/date metadata, controlled return reference, material table,
sender/driver/engineer/receiver sign-off matrix and final-page company footer.

## Database and security

The additive migration extends the existing return tables without removing the
legacy request-scoped compatibility path. New reads use authorized projections;
all mutations use security-definer RPCs that derive the exact current Auth role,
project membership and server time.

RLS continues to deny ordinary direct writes. Engineering roles cannot confirm
warehouse receipt, Procurement cannot approve Engineering returns, archived
projects are read-only, and commercial values are absent from return payloads
and documents.

## Data preservation and rollback

Legacy submitted records remain readable and compatible; request attribution is
retained where present. New project-wide records may have no single request ID
because their line snapshots carry the precise source trace instead.

Rollback is application-first: disable the new routes and stop calling the new
RPCs while preserving the additive columns, states, audit and stock history.
Do not drop return rows, receipt facts or movements after production use; any
future correction must be an audited compensating command.

## Acceptance evidence

- Positive role coverage: Site/Project Engineering creation, global Engineering
  approval, Procurement receipt and Admin override.
- Negative role coverage: Procurement approval denied and Engineering warehouse
  confirmation denied.
- Quantity coverage: delivered eligibility, mixed delivered/custom rows and
  exact good/damaged/not-received reconciliation.
- Transaction coverage: numbering, idempotent retry, single stock movement,
  cancellation without stock effect and preserved source trace.
- Presentation coverage: desktop/mobile responsive render, one-page reference
  PDF, printable multi-page behavior and Excel source-trace round trip.
