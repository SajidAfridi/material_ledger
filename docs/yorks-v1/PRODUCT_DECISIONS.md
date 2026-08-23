# Yorks V1 R35 — Frozen Product and Transaction Decisions

Status: approved Batch 0 contract from 1 August 2026.

This file resolves material ambiguities in Rev 2.0 and the effective R35
prototype. It applies least privilege, data preservation and the approved source
hierarchy. A later change requires explicit product approval and matching
updates to state, RLS, migration and acceptance documents.

## 1. Platform and authority

- Flutter, Riverpod and GoRouter remain the application foundation.
- Product-authority clarification (1 August 2026): the Rev 2.0 SRS defines
  the production flows and the effective R35 HTML defines the target UI and
  interaction model. Existing V1/V7 behavior is retained only where it does
  not conflict; it is replaced or isolated when the approved product requires
  different behavior.
- Public product identity is **Yorks AC. & Ref.**; the full company label is
  **Yorks Air Conditioning & Refrigeration LLC-SPC**, both taken from the
  approved R35 HTML. Historical Nexus terms may remain only in internal code
  namespaces and historical documentation, never in user-facing product copy.
- Supabase Auth and Postgres are the production identity and data authority.
- Postgres constraints and trusted RPCs own state and quantity invariants.
- Realtime only signals an authorized refresh.
- Local storage supports permitted cache, draft recovery and queued
  non-critical work. It is not authoritative for committed transitions.
- Controlled-document snapshots are immutable historical truth.
- Firebase is allowed only for FCM transport.
- Product-owner clarification (14 August 2026): Team Chat owns message and
  mention attention. A Chat event may use a private `v1_notifications` row as
  the durable FCM/outbox transport source, but it never appears in or increments
  the workflow notification centre/bell. The authoritative Chat badge and
  cross-device read state come from the conversation-member cursor. New
  contextual Material Request discussion uses Team Chat and follows the same
  rule. Ordinary workflow notifications and preserved pre-Team-Chat history
  retain their existing workflow surface.

## 2. Roles and identity

Canonical Auth role claims are:

- `project_engineer`
- `site_engineer`
- `senior_mechanical_engineer`
- `project_manager`
- `workshop_in_charge`
- `document_controller`
- `procurement`
- `admin`

Claims come from server-controlled `app_metadata.role`. A protected profile may
mirror the claim for display and query convenience but cannot grant privilege.
Every server-authorized read or command compares the exact presented claim with
the current protected Auth record. A stale JWT fails closed even when its old
and new exact roles both normalize to the Project Engineer workflow role.

`senior_mechanical_engineer`, `project_manager`, `workshop_in_charge` and
`document_controller` are organization-wide Project Engineer roles. Trusted
commands normalize them to Project Engineer workflow authority and allow
access to every existing project without inserting synthetic membership
history. They can perform Project Engineer workflow actions and generate an
authorized Delivery Order, but they do not receive Procurement or stock
authority. Their exact claim remains available for display and audit. By
product-owner approval on 9 August 2026, Senior
Mechanical Engineer additionally receives audited User Management and user
capability-configuration authority. This does not grant that actor direct
commercial visibility or unrelated Admin modules. Project Manager retains no
user-management or capability-management authority; neither do Workshop
In-Charge or Document Controller. By product-owner approval on 15 August 2026,
Senior Mechanical Engineer also receives the full non-commercial
Browse/Inventory read projection. Item/category edits, stock receipts and
adjustments, imports and all other inventory writes remain Procurement/Admin
commands.

New server audit events retain both the normalized workflow role and the exact
Auth role. Historical events keep their existing canonical role and are not
silently backfilled with an invented exact claim.

A submitted MR also freezes that exact server-controlled role. Controlled
documents and audit presentation use the immutable exact role, so a Senior
Mechanical Engineer, Project Manager, Workshop In-Charge or Document Controller
is never relabeled as a Project Engineer on the form even though authorization
uses the normalized workflow role.

A Project Engineer approves the submitted Material Request only when they also
hold an active Project Engineer membership for that project. Procurement may
arrange only after that immutable approval. Saving the arrangement then makes
its arranged quantities dispatch-ready without a second Engineering review.
The legacy arrangement-decision command remains server-protected only for
historical records already in `awaiting_approval`; its UI is disabled by
default and new records never enter that state. A Site Engineer may create and
submit an MR, but cannot grant the request approval; an old or incorrect
`project_engineer` membership label must not elevate a Site Engineer account
into approval authority. Admin retains its audited override.

Legacy `engineer` identities are not automatically promoted. Migration creates
a reconciliation entry and blocks privileged Project Engineer actions until an
Admin records an explicit mapping. Existing project assignment provides
evidence, not automatic privilege escalation.

Admin creates/disables users through a protected server/Edge Function using a
service-role secret that never ships to Flutter. Referenced users are
deactivated rather than deleted.

## 3. Default commercial access

Capabilities are `view_commercials` and `manage_commercials`.

- Project Engineer and Site Engineer have no commercial access by default.
- Procurement and Admin have both capabilities by default; Admin can revoke
  either through protected capability administration.
- Project/Site Engineers have neither capability by default. V1 may grant an
  Engineer `view_commercials`, but never `manage_commercials`.
- An unauthorized response does not contain zeroed or masked cost fields. It
  uses a non-commercial database view/response shape with no cost schema.
- Commercial values never enter unauthorized Riverpod state, local caches,
  exports, print jobs, notifications or logs.
- The authorized controlled MR table has the seven approved columns including
  Unit Cost and Total Cost. The non-commercial projection contains only R No,
  Item Description, Brand/Origin, Qty and Unit.
- Cost uses fixed-decimal values and an explicit currency code, default AED.
  Total Cost is derived consistently from quantity and Unit Cost; the client
  cannot submit an authoritative total.
- Capability revocation purges protected local projections before reload.

Widening Engineer cost access is a later explicit business/security decision,
not an inferred consequence of MR approval.

## 4. Projects, scopes and membership

Project lifecycle:

`draft -> active -> on_hold -> completed -> archived`

- Draft and Active project information may be edited by an authorized Project
  or Site Engineer, subject to membership rules.
- The project creator receives an initial active project membership at creation,
  so they may edit their Draft or Active project while that membership remains
  active. Revocation removes that future authority; it does not rewrite history.
- On Hold blocks new MR submission and dispatch but permits authorized review,
  documents and an Admin-controlled resume.
- Completed blocks new BOQ/MR work but permits outstanding receipt, return,
  document and closure activity.
- Archived is read-only except for audited Admin correction metadata.
- “Delete project” is an Admin-only safe archive, never a physical delete. It
  requires an auditable reason and is blocked while any Material Request is
  operationally open; requests, documents, scopes, memberships and audit
  history are retained.
- Procurement may read Active and On Hold projects. It may also read Completed
  projects while an authorized receipt, return or document action remains open.
  Archived access is search/audit-only.

Every project has physical Building scopes plus one explicit immutable Common
scope. Each real scope owns its own BOQ groups, columns, rows, imports,
documents, exports and BOQ-derived Material Request sources. The UI's
**Overview**
option is a read-only project overview, never a persisted scope, editable
worksheet, export target or MR source. It summarizes every scope without
flattening building rows into an ambiguous editable table.

Existing pre-R38 project-level BOQ groups remain scope-less and visible in
Overview
as `legacy/unassigned`. Their folder name may be represented by independent
empty folder shells in Common/buildings, but their rows and columns are not
copied or inferred into any scope.
An authorized engineer must explicitly version-map one such group to one active
real scope; submitted history or draft sources for a different scope block that
mapping and require reconciliation. Every submitted MR selects exactly one
active scope; a BOQ source must belong to that same scope and may never be
silently mixed across Common/buildings.

Membership records have effective-from/effective-to timestamps, actor and
reason. Revocation prevents future actions but never removes historical access
attribution.

A Site Engineer may select an initial Project Engineer during project creation.
That one creation-time assignment is permitted by the transaction; after
creation, team access changes require an active Project Engineer or Admin.
Activation requires at least one active Project Engineer.

## 5. Project creation experience

The effective R35 five stages are approved:

1. Project Details
2. Parties and Access
3. Buildings
4. Attachments — optional
5. Review and Create

Draft input autosaves per user/device. Creation itself requires connectivity and
one server transaction that creates the project, Common scope, physical
buildings, initial membership history and one **Workshop Materials** BOQ group
for **each** real scope.

No weighted project-completeness percentage participates in V1 readiness or
workflow. Existing progress data remains historical and isolated.

## 6. BOQ groups, columns and rows

- Every Common/building scope starts with one independent **Workshop
  Materials** BOQ group. Admin-configured custom folder names remain
  project-wide structural definitions.
- A custom folder name is a project-wide structural definition. Creating it
  from one real scope creates an independent empty group with the same name in
  Common and every active building, and future scopes receive the name too.
  Rows, columns, quantities, imports, exports and MR sources never copy between
  those sibling groups.
- Overview shows per-scope folder, started-folder and material
  counts. It does not merge rows, permit worksheet mutation or serve as an MR
  source.
- Columns and rows are ordered records with optimistic versions.
- Imported arbitrary columns are preserved in raw JSON and remain editable in
  that worksheet.
- Canonical mappings exist separately for description, brand/origin, quantity,
  unit, planning model/tag and other searchable/transfer fields.
- S:No is derived from row order and is not a durable business identifier.
- Blank Row and Similar Row insert immediately below the active row.
- Deleting a populated column requires confirmation and preserves its legacy
  values in revision/audit history; it does not silently discard them.
- Saving or importing a reviewed worksheet is an atomic active-snapshot
  replacement. Archived row/column order values never block a later import,
  revised IDs and reordered coordinates are accepted, malformed duplicate
  IDs/orders/headings/mappings fail before commit, and an idempotent retry does
  not create another revision.
- BOQ import and editing never submit an MR.

Planning model/equipment tag is separate from manufacturer serial number.
Manufacturer serial is captured only at receipt/asset registration when known.
Legacy `modelSerial` values are retained with provenance until reconciled; they
are not guessed into either field.

The approved default group set is frozen to one folder:

1. Workshop Materials

The former 29 templates remain preserved as inactive historical definitions.
Existing folders carrying any row, column, controlled document or Material
Request source remain visible; empty legacy shells are not shown in normal BOQ
navigation and are never physically deleted by this rollout.

## 7. Material Request creation and submission

An MR draft belongs to one project and one Building/Common scope. It may contain
rows from:

- a whole BOQ group;
- selected BOQ rows;
- an MR Excel import;
- custom rows.

BOQ selection copies a snapshot into the draft only when the source group's
scope equals the selected MR scope. Later BOQ edits do not rewrite the request.
Changing an MR scope warns before removing incompatible BOQ-derived rows;
custom and Excel rows remain. The trusted save and submit commands enforce the
same-scope invariant regardless of client state.

Timing values are `urgent`, `normal` and `scheduled`. Scheduled requires a
scheduled date. Destination is derived from the selected project scope and its
delivery information; an optional delivery note may refine floor/area/zone.
Urgent/Normal do not invent a scheduled date.

Drafts are visible only to their creator and authorized Admin support. Explicit
Submit requires connectivity and atomically:

- validates active project membership and scope;
- snapshots requester name and project role;
- assigns a server number;
- freezes submitted line snapshots;
- moves the MR to `awaiting_request_approval`;
- creates current-owner and audit/notification records.

Until approval, the creator and an assigned/global Project Engineer may update
the current Engineering intent through a version-checked audited command.
Procurement cannot read or arrange the new request until Engineering approval.
The server-backed `draft` remains private to its creator and authorized Admin
support, including discussion. Assigned/global Engineering participants become
readers and may participate only after explicit submission; mentions identify
a protected user ID and create a notification only when that user is also
allowed to read the request.

Custom-row item description supports one non-commercial ranked material
search. Results are ordered from the selected Building/Common BOQ scope, then
the remaining real scopes in the same project BOQ, then the inventory
catalogue. A selected same-scope BOQ result retains its exact group/row source;
a result from another project scope or inventory is copied as descriptive
custom input because an MR may never claim a cross-scope BOQ source. Item
description, brand/origin, size, model/tag and unit may be copied while
quantity remains deliberate user input. No match leaves free-text entry fully
available. The response contains no cost, balance, reservation, minimum-stock,
location or other protected inventory facts.

The same ranked, non-commercial discovery is available while editing a BOQ
description cell. Desktop keeps suggestions inside the active spreadsheet
cell; mobile uses the focused row editor. The current row is excluded from its
own results. Selecting a suggestion copies only mapped description,
brand/origin, size, model/tag and unit values in one local worksheet revision;
quantity and commercial fields remain deliberate input. Searches are
debounced and stale responses are discarded, while unmatched free text remains
valid.

Procurement arrangement shows the immutable request-line BOQ correlation and
uses it to rank warehouse candidates, but never auto-selects a stock item.
Availability, reservation and quantity rules remain authoritative only in the
connected arrangement command; they are not prerequisites for Engineering to
raise a request.

## 8. Canonical MR lifecycle

Machine states:

`draft -> awaiting_request_approval -> approved_for_arrangement -> arranging -> approved -> partially_dispatched -> dispatched -> partially_received -> received -> closed`

Alternative transitions:

- `awaiting_request_approval -> draft` with an immutable `returned` request
  decision and required reason; the request number and submission history stay
  intact and a resubmission returns to request approval
- eligible pre-dispatch records -> `cancelled`
- approved but undispatched records -> `cancelled` with reason and reservation
  release

`deleted` is not a workflow state. A draft may be physically removed if it has
never been submitted. Submitted records follow controlled deletion/cancellation
rules and preserve lines/history.

The first transition to `arranging` occurs only after a current immutable
request-approval decision and when Procurement explicitly starts the first
arrangement version. It is server-recorded, not inferred from opening a screen.
Existing requests already in `arranging` or `awaiting_approval` retain their
recorded legacy post-arrangement approval path until resolved; no synthetic
pre-approval is created.

`closed` is explicit and allowed when all approved quantities are resolved, no
dispatch/receipt is open, and any unavailable-at-zero lines remain preserved.
Unavailable original requested quantity does not fabricate an outstanding
approved quantity. An actively assigned Project Engineer or Site Engineer,
either organization-wide Project Engineer role, or Admin may close. Procurement
may not close its own fulfilled workflow.

## 9. Arrangement and reservation

Every request line has exactly one current arrangement decision:

- `full`: arranged quantity equals requested quantity;
- `partial`: arranged quantity is greater than zero and below requested, with a
  required reason;
- `unavailable`: arranged quantity is zero, with a required reason.

Warehouse is the default source. A line may instead use an external supplier
source. The supplier name is optional operational context because V1 has no
full supplier/RFQ/PO lifecycle. Selecting External Supplier is sufficient for
a Full line; Partial and Cannot Provide Now still require their decision reason.

Saving a complete arrangement version atomically:

- validates every line and current request version;
- locks affected inventory rows;
- replaces the prior active version and reservations;
- prevents aggregate warehouse reservations exceeding availability;
- snapshots arranged quantities as approved quantities for the already
  approved Engineering request;
- moves positive supply to dispatch-ready `approved`; or, when every line is
  unavailable, retains the current arrangement as editable Procurement work in
  `arranging` with zero approved quantity.

An all-unavailable arrangement never silently completes or cancels the
request. Procurement may revise and save the current work when supply becomes
possible. A valid Project Engineer/global Engineering approver or Admin may
explicitly cancel it with a reason; cancellation is terminal for Procurement
editing and preserves the unavailable decisions and audit history.

One `inventory_reservations` table owns the commitment. Presentation values
such as “allocated” are derived from approved reservation status; there is no
second unmodeled allocation authority.

Reservation states are `active`, `partially_consumed`, `consumed` and
`released`. Dispatch consumes the corresponding quantity. Replacement of an
arrangement, cancellation, closure or explicit audited override releases the
remainder. Returning an arrangement for changes keeps the current reservation
until Procurement saves its replacement or the MR is cancelled, preventing
another request from taking the stock mid-review.

## 10. Approval

Only an active assigned Project Engineer, organization-wide Senior Mechanical
Engineer/Project Manager, or authorized Admin override can approve/return the
current request version before Procurement arrangement. Procurement
self-approval is rejected even if the user has another editable client-side
label. Approval freezes the exact Engineering version and actor role; it does
not reserve stock or create commercial facts.

Temporary adoption policy: a request creator whose exact role is not Site
Engineer may approve their own submitted request when they independently hold
the required Project Engineer/global Engineering/Admin authority. A Site
Engineer creator cannot self-approve. Admin may publish
`requests.allow_authorized_creator_self_approval = false` to require an
independent authorized approver. The trusted decision command reads only the
published value, so a configuration draft cannot change workflow behavior and
historical decisions are never rewritten.

External supplier identity remains optional during the adoption period. This
is a deliberate temporary policy, not proof of supplier readiness. Procurement
may record a lightweight confirmation, expected date and commitment reference
on each positive external line. Admin may later publish
`procurement.require_external_source_readiness = true`; the trusted arrangement
save then rejects any positive external line without confirmation. Supplier
name remains optional and the control does not introduce an RFQ, quotation or
Purchase Order workflow.

A cancelled request whose latest saved arrangement records every line as
unavailable may be copied once into a new private Engineering Draft by an
otherwise authorized MR creator. The replacement keeps exact request- and
line-level source links, while the cancelled source remains terminal and
unchanged. Procurement cannot create the replacement. It must be explicitly
reviewed and submitted through the familiar MR flow; it is never an automatic
resubmission.

The pre-revision `awaiting_approval` state remains a compatibility lane only
for arrangements already saved before this change. Those exact legacy records
may still be approved/returned using their historical command and are never
silently relabeled as pre-approved requests.

## 11. Inventory and dispatch

V1 has one logical warehouse. Inventory uses decimal quantities and append-only
movements. On-hand is changed only by trusted stock commands.

The approved R38.3 warehouse refinement keeps a normalized category master and
accepted source-text aliases. Seeded category names, including SED and RED, are
literal business labels and are never expanded by inference. Imports never
overwrite a balance: Opening Balance, Add Stock and Remove Stock append a
server movement, while No Stock Change may update verified item master data
without fabricating a movement. Minimum stock is an operational attention
threshold only; it is not a valuation, reorder or purchase-order workflow.
Close category matches are advisory until an authorized user confirms an
existing category or explicitly creates a new one.

During the current catalogue-reconciliation period, Procurement may also save
an inventory item without a category. The item remains truthfully
uncategorized; the client and server do not invent a fallback category or
alias. Making category selection mandatory later is a separate product and
migration decision. When a category is supplied, the same trusted resolver,
parent-category creation and duplicate protections remain mandatory.

Dispatch is one server transaction that:

- validates Procurement/Admin authority, current state and idempotency key;
- locks request, reservation and inventory rows;
- caps each line by approved minus good-received minus in-transit quantity;
- caps warehouse lines by stock available at commit;
- consumes reservations and decrements on-hand exactly once;
- creates dispatch/line snapshots, movement and audit records;
- sets the appropriate partial/full dispatch state.

An external-source dispatch does not mutate warehouse stock but remains subject
to the approved quantity cap.

## 12. Receipt review and Delivery Order

Each dispatch line is reviewed with one UI outcome:

- Received — good quantity equals dispatched quantity;
- Missing — reviewer enters good quantity, and the remainder is missing;
- Damaged — reviewer enters good quantity, and the remainder is damaged.

This permits partial good receipt without inventing a fourth visible status.
One line cannot be both Missing and Damaged in the same review; Procurement may
split a dispatch line when those outcomes must be recorded separately.

The review must reconcile to the dispatched quantity. Only good quantity
increments `good_received_qty`. Missing/damaged quantity remains replacement
eligible within the approved cap.

After confirmation, an authorized receiving Engineer may attach JPEG or PNG
site photographs to the immutable receipt-review entity. The existing
prepare/upload/finalize document transaction and entity authorization are used;
the receipt command itself never claims upload success.

A Delivery Order snapshot may be created as soon as its dispatch is committed.
An assigned Project/Site Engineer, either organization-wide Project Engineer
role, Procurement or Admin may generate it. This document-only command does not
permit an Engineer to dispatch stock, arrange a request or confirm a material
return. Cardinality is one current DO revision per dispatch; regeneration
creates an immutable new revision and supersedes, never overwrites, the prior
snapshot. A dispatch revision uses immutable dispatched quantities and the
approved four columns: S.No, Description, Qty and Unit.

The Description cell also renders the Size and, when present, Model/Planning
Model Tag captured on the submitted Material Request line. These values are
frozen into each Delivery Report revision; preview, Excel, PDF and print must
not resolve them from a later mutable inventory record. Size remains explicitly
labelled even when a legacy request did not capture a value.

When a receipt review is confirmed, the server appends a distinct immutable
`receipt_review` Delivery Report revision when a Delivery Order already exists.
The current printable report then shows each confirmed good quantity, including
zero for a fully missing or damaged line, while the earlier `dispatch` revision
continues to prove what Procurement committed. If no Delivery Order existed at
receipt time, generating one afterwards creates that receipt-reviewed revision.
Material Returns remain later, separate inventory facts: they do not rewrite
either dispatch or receipt evidence.

Controlled MR and DO documents use `YORKS Airconditioning & Refrigeration
LLC-SPC` and `يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و`, show the approved Abu
Dhabi telephone/fax/P.O. Box and `yorks_sk@yorks.ae`, include the building
number on the DO, and render the project name as `<job/contract ref>-<project
name>` when the project has a job/contract reference.

## 13. Material Returns

Return lifecycle:

`draft -> submitted -> confirmed | rejected`

- Eligible quantity is good received minus prior confirmed returns.
- Submission freezes project, scope, source request/dispatch/receipt links and
  line snapshots.
- Only Procurement/Admin can confirm physical warehouse receipt.
- Confirmation is idempotent and appends movements once.
- A supplier-sourced line must be mapped to an existing inventory item or a new
  Admin/Procurement-proposed item before warehouse confirmation. No stock is
  posted to an unidentified item.
- Rejection requires a reason and does not change stock.

## 14. Documents and links

Documents are immutable versions with object path, hash, mime type, size,
revision, uploader and timestamps. A current version supersedes but does not
delete its predecessor.

A document may have multiple links. Normal links belong to one project.
Cross-project links require Admin and a reason. A reader must be authorized for
every current link, then pass the document classification:

- `operational` follows linked-entity access;
- `commercial` additionally requires `view_commercials`;
- `admin_restricted` requires Admin.

Knowledge of a Storage path never grants access. Link creation/removal is
audited and cannot broaden a document beyond its classification.

PDF and print use one domain template. Generated MR, DO and Return snapshots are
stored with source record/version references.

## 15. Numbering and idempotency

- UUIDs are internal primary keys.
- Project reference remains an Admin-controlled unique value.
- MR, dispatch and return human numbers are allocated server-side from a
  per-project locked counter on first committed transition.
- A retry with the same actor, command type and idempotency key returns the
  original result.
- A different payload with a reused key is rejected.

Sequences start at `001`, are never reused and use:

- `{PROJECT_REF}-MR{NNN}`
- `{PROJECT_REF}-DSP{NNN}`
- `{PROJECT_REF}-RTN{NNN}`

The Delivery Order reference is entered by an authorized user, normalized and
globally unique. Historical references are never renumbered; collisions are
reported and retained through a migration alias/exception.

## 16. Deletion, correction and audit

- Creator may hard-delete an unsubmitted local/server draft with no links.
- Assigned Project Engineer/Admin may cancel or delete a submitted pre-approval
  MR only when no dispatch exists; server audit/history is retained.
- Approved undispatched MRs soft-cancel with a reason and release reservations.
- Dispatched, received, return-confirmed, generated-document and audit records
  are never application-hard-deleted.
- Corrections create append-only correcting events or new versions.
- Critical actor, role and timestamp are derived on the server.

## 17. Offline behavior

Project/MR/return drafts and BOQ draft edits may recover locally. Committed
project creation, MR submission, arrangement, approval, inventory adjustment,
dispatch, receipt confirmation, DO generation, return submission/confirmation
and user administration require server confirmation.

The UI shows Offline, Saving, Synced, Conflict and Failed states explicitly.
Critical actions never show success before the server commits.

## 18. Deferred and retained behavior

- Accounts and Finance navigation is unavailable in the Yorks V1 experience.
  Existing records/code remain preserved behind a disabled legacy boundary.
- Full RFQ, quotation comparison, PO and supplier portal remain deferred.
  R38.9 separately approves controlled supplier receipt provenance inside the
  Warehouse Inventory workspace; it does not authorize purchasing workflow,
  multi-warehouse behavior or accounting valuation.
- Configuration, Rentals, User Management, Audit Trail, Duct Sizer and ESP
  Calculator remain and receive smoke/regression fixes only.
- Multi-warehouse, portals, barcode/QR, AI and complex BI are deferred.

## 19. R38.9 supplier identity and receipt import

- Supplier folders are Procurement/Admin-only and remain nested under
  Warehouse Inventory. Engineering inventory-read capability does not expose
  suppliers, documents, receipt/commercial fields or supplier exports.
- A blank, whitespace-only, `Unknown` or `N/A` supplier maps to one immutable
  system `Unknown Supplier` identity. The original raw value and
  `unknown_missing` resolution are retained.
- Missing supplier is a visible warning, not a blocker. External Supplier rows
  still require a Delivery Note/reference and Received Date. Opening Balance
  rows may omit those fields and retain Opening Balance provenance.
- Manufacturer Serial No is optional evidence and is never generated by Yorks.
  Blank values and conventional absence markers (`N/A`, `NA`, `Unknown`,
  `None`, `Nil` or a dash) normalize to no serial/bulk tracking while the raw
  workbook cell remains in import evidence. Each genuine manufacturer serial
  requires its own quantity-one row; duplicate genuine serials remain blocking.
- Supplier aliases only auto-resolve on an exact approved normalized alias.
  Similar names require an explicit Procurement/Admin decision.
- Import stages before final confirmation are quantity-neutral. The trusted
  commit is strict, idempotent, append-only and authoritative for supplier,
  receipt, movement, balance and audit effects.
- Delivered quantity equals Accepted + Damaged + Rejected. Only Accepted enters
  usable On Hand; Damaged is quarantined and Rejected does not enter stock.
- The two supplied master workbooks are reconciliation alternatives, not two
  stock sources. Neither may be committed to production before signed cutoff,
  staging rehearsal and source/commit/quarantine reconciliation.

## 20. Material Request Phase 2 collaboration and scale

- Material Request registers use an authorized server summary projection with
  server-side search, filter, sort and paging. The initial request page contains
  15 rows. A summary never embeds request lines, comments, commercial values or
  another user's private draft; full detail is fetched only after the user opens
  one request.
- The discussion projection returns the newest 20 comments. Older comments use
  a stable server cursor and are loaded explicitly without reloading or
  duplicating the newest page.
- **Claim** and **Reassign** are version-checked responsibility markers for
  coordination. They never approve, arrange, dispatch, cancel, change state or
  replace the canonical workflow owner/next-action calculation. Reassignment
  requires a reason and notifies the new assignee.
- Private draft sync is owner-only recovery across the same user's devices. It
  coexists with the local draft for offline recovery, shows **Saved to your
  account** only after server confirmation, and never makes an unsubmitted
  request visible to another participant or Procurement.
- Returned requests expose a concise server-derived change summary from the
  immutable Engineering revision snapshots. It highlights item additions,
  removals, quantity changes, detail changes and delivery-note changes without
  rewriting the decision or audit history.
- Phase 2 preserves the temporary adoption policies: an independently
  authorized non-Site-Engineer creator may self-approve; supplier readiness is
  non-blocking; and an all-unavailable request stays Procurement-editable until
  explicit authorized cancellation makes it terminal.
