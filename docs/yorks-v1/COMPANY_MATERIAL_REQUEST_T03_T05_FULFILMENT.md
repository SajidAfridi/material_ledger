# Company Material Requests T03-T05 — fulfilment and custody

Status: **local implementation candidate; feature gated and not released**
Implemented: 18 September 2026

This slice completes the protected operational path after independent company
approval. Company use remains inside Material Requests and shares the existing
single warehouse. It does not create a project, BOQ, second warehouse or
parallel stock balance.

A returned approval stays on the same reference. Its requester may revise the
purpose, delivery point and requested line quantities, then resubmit after the
server rechecks every participant and resolves the current independent route.

## Lifecycle

1. Procurement records Full, Partial or Cannot Provide Now for every approved
   line. Partial and unavailable decisions require a reason; unavailable also
   requires a follow-up date.
2. A saved plan supersedes the former plan and releases only its remaining
   reservation. Warehouse quantities enter the same reservation relation used
   by project requests, distinguished by an enforced request kind.
3. Dispatch locks balances in deterministic item order, rechecks arranged and
   approved caps, consumes reservations and appends one inventory movement.
   External-source dispatch creates no warehouse movement.
4. Only the configured active receiver can reconcile each dispatch line as
   Received, Missing, Damaged or Incorrect. Good quantity remains distinct
   from exception quantity.
5. Good receipt does not fabricate beneficiary custody. The beneficiary may
   acknowledge directly, or the authorized receiver may record a witnessed
   handover with its evidence basis.
6. A requester, beneficiary or receiver can submit a provenance-bound return.
   Procurement confirms physical receipt; only a reusable warehouse-sourced
   item restores stock.
7. The requester, receiver or independent approver may close only after all
   approved need is received and handed over, with no in-transit dispatch or
   pending return. Procurement cannot close its own fulfilment.

Every critical command rechecks active identity, exact role or configured
authority, current state, expected version, quantities and idempotency. Direct
authenticated table writes remain revoked. Events retain actor, role, time and
the command's evidence reference.

## Shared reservation migration

Existing project reservation IDs and quantities are preserved. The migration
adds `request_kind = project` to those rows, makes the owner reference
polymorphic under a constraint trigger, and adds an exclusive company supply
line reference. Existing project availability sums continue to include every
active reservation; project `request_id <> current request` checks also count
company request IDs, so project and company dispatch cannot reserve the same
stock independently.

## UI and application path

The role-safe Company request detail presents only actions the projection
authorizes. Procurement plans from shared inventory or an external source and
dispatches ready quantities. Receivers confirm physical receipt; beneficiaries
or receivers confirm handover. Return and closure controls stay on the same
responsive detail screen. All writes follow Widget -> Riverpod provider ->
repository -> trusted RPC, and no critical success is optimistic.

## Verification and rollback

The focused pgTAP lifecycle test covers negative requester planning, shared
reservation, plan retry, arranged/approved dispatch caps, one stock decrement,
receipt/handover separation, explicit closure, duplicate-handover rejection,
return eligibility, reusable restock and audit events. The full database,
Flutter, web and Android gates remain required before release.

Rollback is flag-off plus the prior application artifact. Preserve every new
plan, reservation, dispatch, receipt, handover, return, event and inventory
movement. Forward-fix schema or command defects; never delete committed
custody or stock history.
