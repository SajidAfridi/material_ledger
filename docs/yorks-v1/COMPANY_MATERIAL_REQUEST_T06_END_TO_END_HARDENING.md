# Company Material Requests T06 — end-to-end hardening

Status: **local release candidate; feature gated and not deployed**
Implemented: 18 September 2026

T06 closes the verified gaps in the signed-in Company use lifecycle while
keeping Company use inside Material Requests. The local path now covers draft,
explicit submission, independent approval, remaining-demand planning, shared
warehouse reservation, dispatch, immutable issue evidence, receipt exception
reconciliation, beneficiary handover, return, independently approved remainder
withdrawal and explicit closure.

## Server authority

- A receiver cannot record `beneficiary_confirmed`; direct beneficiary
  acknowledgement and witnessed receiver acknowledgement remain distinct.
- Revised plans use approved need minus good receipt, in-transit quantity and
  approved withdrawal. Completed or fully withdrawn lines do not block a
  multi-line replan.
- Dispatch is capped against the same remaining-demand calculation even if an
  older client submits a stale arranged quantity.
- Remainder withdrawal is an append-only, reasoned and idempotent command for
  the current independent approver. It preserves the original requested
  quantity, retains delivered and in-transit facts, and creates a new supply
  plan version while releasing and recreating only operational reservations.
- Closing accepts good receipt plus approved withdrawal only when handover,
  transit and return checks are also resolved.
- Revoked beneficiary, receiver, requester or approver authority removes the
  corresponding future command flags and is rechecked by the trusted command.
- Authenticated clients cannot read or mutate the issue-note or withdrawal
  tables directly. They use role-safe projections and trusted RPCs.

## Application behavior

The Company workspace now contains local **My work**, **Requests**,
**Planning** and **Issue history** views. Planning remains Procurement-only.
Issue history identifies the immutable Company Issue Note for each dispatched
request, while its full snapshot remains available only through the protected
RPC. The request detail exposes the withdrawal command only when the server
returns that capability. Mobile detail screens retain enough bottom clearance
to scroll every action above the fixed navigation surface.

## Verification boundary

The focused database coverage proves immutable issue snapshots, handover
identity separation, remaining-demand caps, multi-line replanning, protected
registers, revoked-authority behavior, one withdrawal event per retry and
closure after an approved withdrawal. Flutter repository and responsive widget
tests cover the protected calls, registers, issue history and withdrawal
interaction.

This evidence is local. `YORKS_V1_COMPANY_MATERIAL_REQUESTS` remains off by
default. No remote migration, flag change, deployment or named-persona UAT is
part of T06.

The broader lifecycle review still requires a company-approved policy before a
worker without a login can receive by supervisor attestation. It also requires
release acceptance for cross-module Company return registers and the complete
controlled-document set beyond the immutable issue note. Those boundaries must
not be inferred from this signed-in lifecycle candidate.

## Data preservation and rollback

The migration is additive and backfills one immutable issue-note snapshot for
each existing Company dispatch. Existing requests, approvals, plans,
reservations, dispatches, receipts, handovers, returns, movements and events
remain intact. Rollback is flag-off plus the previous application artifact;
committed issue and withdrawal evidence must be preserved and defects fixed
forward.
