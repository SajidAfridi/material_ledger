# Current Material Request User Guide

Status: **current operating guide**  
Authority: the approved approval-first revision in
[`MATERIAL_REQUEST_FLOW_REVISION_2026-08-13.md`](MATERIAL_REQUEST_FLOW_REVISION_2026-08-13.md)
and the protected server projection. Historical batch screenshots remain
evidence of their original releases, not current workflow authority.

## The flow in plain language

1. **Engineering prepares the request.** A Project Engineer or Site Engineer
   selects the project and exact Common/building scope, adds BOQ or custom
   items, saves a private Draft and explicitly submits it.
2. **Engineering approves the need.** An authorized Project Engineer reviews
   the submitted quantities and either approves them for Procurement or
   returns them for changes with a reason.
3. **Procurement arranges every line.** Procurement records Full, Partial or
   Cannot Provide Now and chooses Warehouse or External Supplier. Saving a
   complete arrangement makes its positive quantities ready for controlled
   dispatch; new requests do not need a second Engineering approval.
4. **Procurement dispatches approved quantities.** The server rechecks the
   approved outstanding quantity and warehouse availability, then commits one
   dispatch and creates its immutable Delivery Order quantity snapshot. The
   success notice identifies the committed dispatch.
5. **The site reviews the delivery.** An authorized receiving Engineer records
   Good, Missing and Damaged quantities for every dispatched line. The totals
   must exactly equal the dispatch. A confirmed receipt may include site
   photographs.
6. **Engineering closes resolved work.** When all required good quantities are
   received, an authorized Engineer closes the request. Missing or damaged
   quantities remain visible for replacement dispatch until resolved.
7. **Returns are a separate controlled flow.** Engineering selects eligible
   good-received material, submits a return, obtains Engineering approval and
   dispatches it back. Procurement confirms physical warehouse receipt before
   inventory is restored.

## What the register tells you

Every request card shows four different facts:

- **Status** — where the request is in the immutable workflow.
- **Current owner** — the role that has authority for the next workflow step.
- **Next action** — the server-projected work needed to move the request.
- **Coordinator** — an optional person who follows up on the record. Claiming
  or reassigning a Coordinator never changes status, authority or Current
  owner.

The phone tabs are broad work groups rather than individual states:

- **Draft** — private editable drafts.
- **Submitted** — submitted, awaiting Engineering approval, returned for
  changes, approved for arrangement, arranging and the preserved legacy
  awaiting-approval state.
- **Approved** — approved, dispatch, receipt and closed states.

The role-aware register views answer a different question:

- **My Work** — records where you can perform the protected Current action
  now. It is based on server authorization, not only the owner label.
- **Exceptions** — current unavailable, partial, late-supply, receipt,
  replacement and return issues that need attention.
- **Coordinated Requests** — records assigned to you for follow-up; this does
  not make you the workflow owner.

Open **Insights** for approval, arrangement, warehouse fill, receipt,
replacement and return timing facts. A Scheduled request shows its Required on
site date and a factual overdue warning. Action age is shown, but an Action due
date is not displayed until Yorks approves an SLA policy.

## How to read the line ledger

The request detail keeps the complete quantity trail together:

`Requested | Arranged | Reserved | Dispatched | Good | Missing | Damaged | Returned | Still Needed`

This makes partial supply, goods in transit, receipt exceptions, warehouse
returns and outstanding need visible without comparing separate screens.

## Who does what

| Role | Main responsibility in this flow |
|---|---|
| Project Engineer | Create/edit requests, approve Engineering need, confirm receipts and close resolved requests for authorized projects |
| Site Engineer | Create/edit their request, confirm receipts and close resolved requests; cannot approve unless separately holding Project Engineer authority |
| Procurement | Arrange approved requests, reserve warehouse quantities, dispatch and confirm physical material returns |
| Admin | Audited administration/override through the same protected commands; does not fabricate missing workflow history |
| Global Engineering roles | Organization-wide Project Engineer authority as defined in the source-of-truth role matrix |
| Accountant | No technical MR, arrangement, dispatch, receipt or return mutation authority |

## How to read confirmations

Critical actions never succeed only on the screen. A success notice appears
after the protected server command returns:

- arrangement: counts Full, Partial and Unavailable decisions;
- dispatch: identifies the committed dispatch and line count;
- receipt: identifies confirmed lines and recorded exception lines;
- material return: identifies the return, resulting state and line count.

If a command times out or fails, refresh the record before retrying. The same
idempotency identity is retained until confirmation so a retry cannot create a
second reservation, dispatch, receipt or inventory movement.

## Historical requests

Records that already entered the former `awaiting_approval` post-arrangement
lane keep that factual history and compatibility path. They are not silently
converted. This exception must not be used as the operating guide for a newly
submitted request.

Implementation definitions and security boundaries are recorded in
[`MATERIAL_REQUEST_ACTION_INTELLIGENCE.md`](MATERIAL_REQUEST_ACTION_INTELLIGENCE.md).
