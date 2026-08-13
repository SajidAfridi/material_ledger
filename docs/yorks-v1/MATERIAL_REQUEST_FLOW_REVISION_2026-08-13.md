# Material Request Flow Revision — 13 August 2026

Status: product-owner approved implementation contract.

This revision changes the order of Engineering approval and Procurement
arrangement for newly submitted Material Requests. It also adds an authorized
discussion thread with mentions, non-commercial inventory-assisted item entry,
clear lifecycle presentation, and operational receipt photographs.

## Evidence-backed impact and defect table

| Area | Current behavior | Approved behavior | Root cause / implementation impact |
|---|---|---|---|
| Request approval order | Submit hands the request to Procurement; Engineering approves the completed arrangement | Submit hands the request to Engineering; Procurement may begin only after request approval | The current state/RPC contract encodes `submitted -> arranging -> awaiting_approval`. New states and a new request-decision command are required; this cannot be solved by relabeling UI actions. |
| Stage-one editing | Only creator-owned `draft` rows are editable | Until request approval, the creator and an authorized Project Engineer may edit the Engineering request through a version-checked command | The existing draft RPC rejects every submitted record and has creator-only ownership. A separate trusted edit command must preserve the submitted number, attribution and audit history. |
| Arrangement completion | A saved arrangement waits for Engineering approval | A saved arrangement for a pre-approved request becomes dispatch-approved immediately; legacy arrangements retain their recorded post-arrangement decision path | The existing save command always creates `awaiting_approval`. It must branch on a real immutable request-approval record, never infer approval from state or role. |
| Discussion | Normalized V1 Material Requests have no trusted discussion relation | Authorized participants can comment from the first server-backed request stage, mention authorized users and generate notifications | Legacy JSON comments are not a transaction or RLS authority. New append-only comment and mention relations/RPCs are required. |
| Mention privacy | No scoped mention directory | Mention suggestions contain only authorized display name, exact role and opaque user ID for participants allowed to read that request | The broad profile directory is unsuitable: it excludes global Engineer roles and is not scoped to an MR/project. |
| Inventory-assisted request entry | Engineers enter custom description fields manually | A non-commercial, project-authorized inventory search can copy item description, brand/origin, size, model and unit into a request line | Existing inventory projections expose operational stock/commercial context intended for Procurement. A new minimal search projection is required and quantity remains user-entered. |
| Engineering visibility | Submitted request visibility follows existing project/global-role reads; drafts remain creator/Admin only | Active assigned Project/Site Engineers and organization-wide Senior Mechanical Engineers/Project Managers can read all server-backed workflow stages and discussion; private local recovery input remains creator-only | Read helpers and tests must explicitly cover all four Engineering roles without widening Procurement or commercial access. |
| Status clarity | State appears in parts of the workspace but the next owner/action is not consistently prominent | Detail and controlled form show a stable human status plus current owner and next action | Presentation currently maps the old state order and cannot distinguish pre-approval from arrangement review. |
| Close authority | Only Project Engineer/global Project Engineer roles and Admin can close a fully received request | An actively assigned Site Engineer may also close after all server quantity and receipt checks pass | Both the private authorization helper and presentation preflight must widen; the trusted close command, membership check, version, idempotency and audit boundary remain unchanged. |
| Tablet/mobile refresh | A healthy Realtime channel can appear subscribed after browser/app suspension while no longer delivering workflow signals | Re-fetch authorized projections on foreground resume and a low-frequency safety interval, retain the visible projection during refresh, and offer pull-to-refresh on the mobile register | Realtime remains metadata-only; every refresh reuses normal protected RPC reads and no local state transition is synthesized. |
| Receipt evidence | Receipt review records quantities/notes only | After server confirmation, an authorized receiving Engineer may attach JPEG, PNG or WebP site photographs linked to that immutable receipt review | The generic document pipeline does not currently accept `receipt_review` as a link/upload target. The existing prepare/upload/finalize boundary will be extended rather than bypassed. |

## New-request state machine

```text
draft
  -> awaiting_request_approval
  -> approved_for_arrangement
  -> arranging
  -> approved
  -> partially_dispatched / dispatched
  -> partially_received / received
  -> closed
```

- Returning a request before approval moves it back to `draft` only through a
  trusted decision with a required reason. Its number, original submission
  attribution, decision history and audit events are retained.
- An edit in `awaiting_request_approval` replaces only the current Engineering
  line snapshot. It is version-checked, audited and forbidden after approval,
  after any arrangement exists, or after any reservation/dispatch activity.
- The request approval freezes the exact approved Engineering version. It does
  not create inventory reservations or commercial facts.
- Saving a complete arrangement for a request with a current approval creates
  approved line quantities from arranged quantities and makes positive lines
  dispatchable. Partial and unavailable decisions remain truthful exceptions.

## Existing-data preservation

- Existing `arranging` and `awaiting_approval` requests continue through the
  former post-arrangement approval path. No synthetic pre-approval row is
  created and no reservation is released or replaced by this migration.
- The former post-arrangement approval controls are disabled in production.
  They remain behind the off-by-default
  `YORKS_V1_LEGACY_ARRANGEMENT_REVIEW` compatibility flag only while historical
  beta records are reconciled.
- Existing `approved`, dispatch, receipt, Delivery Order, return, document and
  audit records are unchanged.
- Existing `submitted` records without an arrangement are reclassified as
  `awaiting_request_approval`, because no Procurement fact exists to preserve.
  The migration records the system transition through the row version and
  timestamp without fabricating a human actor event.
- Rollback is forward-only: disable new client actions, retain additive tables
  and functions, and deploy a corrective migration. Do not drop comment,
  decision, mention, document-link or audit history.

## Authorization summary

- Creator: edit own request before approval; comment when request-readable.
- Assigned Project Engineer: read, edit, approve/return and comment.
- Assigned Site Engineer: read and comment; can edit only when they are the
  creator; may close a fully resolved received request; cannot approve unless
  separately holding valid Project Engineer authority.
- Senior Mechanical Engineer / Project Manager: organization-wide read,
  edit, approve/return and comment with exact role preserved.
- Procurement: reads/comments only after request approval, arranges and
  dispatches; cannot approve or edit Engineering intent.
- Admin: audited override within the same versioned commands; no fabricated
  actor events.

## Acceptance additions

1. New submit produces `awaiting_request_approval`, not Procurement ownership.
2. Procurement begin-arrangement fails before request approval through RPC and
   ordinary table APIs.
3. Creator and valid Project Engineer edits are atomic, version-checked and
   audited; Site Engineer non-creator and Procurement edits fail.
4. Request approval is idempotent, preserves exact role and is required before
   the new arrangement path.
5. New arrangement save creates approved quantities once; a retry cannot
   duplicate approvals/reservations/audit.
6. Legacy awaiting-arrangement decisions remain resolvable without history
   rewrite.
7. Mentioned authorized users receive one notification; unauthorized or stale
   members cannot be mentioned or read the thread.
8. Inventory search returns no costs, balances, reservations, minimum stock or
   other protected fields and fills only descriptive request data.
9. Status/owner/next action are consistent across desktop, mobile and the
   controlled MR model.
10. Receipt photograph upload is available only after confirmed receipt and is
    readable only through the receipt/request project authorization boundary.
11. An actively assigned Site Engineer can close a fully resolved received
    request; Procurement and an unrelated or inactive Site Engineer cannot.
12. Tablet/mobile projections re-fetch after foreground resume and by safety
    interval without blanking the current view; mobile also supports pull to
    refresh.
