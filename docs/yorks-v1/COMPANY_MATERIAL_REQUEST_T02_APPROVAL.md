# Company Material Requests T02 — independent approval

Status: **local implementation candidate; feature gated and not released**  
Implemented: 18 September 2026

T02 extends the approved T01 company-use request aggregate through one
independent decision. It does not make a Company Material Request a project,
BOQ, building, warehouse, inventory pool or top-level module.

## Included behavior

- The assigned, active company approver receives a server-filtered inbox.
- The approver can open the current role-safe request projection and record
  Approve, Return for changes or Reject.
- Return and Reject require a reason. Approve forbids a reason.
- The server rechecks exact active identity, the snapshotted assignment,
  current category/unit approver authorization, separation from requester,
  beneficiary and receiver, pending state and expected record version.
- Procurement cannot decide, even if an erroneous approver authorization row
  exists.
- One immutable decision, audit event and requester notification are appended.
- A same-key/same-payload retry converges; a stale or second decision fails
  without another effect.
- The Flutter repository uses only the inbox, safe projection and decision
  RPCs. Responsive inbox/detail screens expose no table mutation path.

States added by this slice are `approved_for_procurement`,
`returned_for_changes` and `rejected`. The decision itself does not reserve,
move, value or issue stock.

## Authority and access

`v1_company_material_request_assigned_approver` is the shared server predicate.
It requires the snapshotted approver and a current explicit approver grant for
the request category and responsible unit. It rejects Procurement and any
actor who is the requester, beneficiary or receiver.

`v1_list_company_material_request_approval_inbox()` returns only pending rows
which pass that predicate. `v1_decide_company_material_request(jsonb, uuid)` is
the only client decision command. The decision relation has RLS enabled and no
authenticated table privileges.

## Explicit boundary before fulfilment

The broader lifecycle review remains a proposal. T02 does not authorize
Procurement visibility, arrangement, reservation, dispatch, Delivery Order,
receipt, beneficiary issue/attestation, return or closure. Those stages require
product-owner decisions recorded in
[`COMPANY_MATERIAL_REQUEST_LIFECYCLE_REVIEW.md`](COMPANY_MATERIAL_REQUEST_LIFECYCLE_REVIEW.md),
including company categories/units, requester/receiver populations, custody
handover evidence and allowance/replacement rules. The current feature flag
therefore remains off by default.

`returned_for_changes` preserves the reason and request history. Editing and
resubmission are not exposed until that follow-up contract is approved, so an
operator must not present T02 as a complete fulfilment lifecycle.

## Verification

- `supabase db reset --local` applies the additive migration on a clean stack.
- The focused pgTAP file proves 20 permission, separation, reason, version,
  idempotency, event and notification assertions.
- Repository tests prove exact RPC names and payload shapes.
- Widget tests exercise the 360px inbox and a desktop approval confirmation.
- Full repository gates remain required before merge or release.

## Rollback and preservation

Disable `YORKS_V1_COMPANY_MATERIAL_REQUESTS` and restore the prior application
artifact. Keep the additive states, decisions, events and notifications. Never
delete or rewrite a recorded decision. A forward migration is required for any
contract change.
