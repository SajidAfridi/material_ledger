# Yorks V1 R35 — Test and Acceptance Plan

## 1. Test layers

| Layer | Required proof |
|---|---|
| Dart unit | State derivation, decimal input normalization, canonical column mapping, reference formatting, role/capability resolution |
| Repository/controller | Draft recovery, typed RPC payload/result, connectivity, idempotent retry, conflict/error handling, notification refresh |
| Flutter widget | Eight-role navigation, action visibility, forms, dynamic grid, keyboard behavior, focused mobile editor, localization and responsive layouts |
| Database/pgTAP | Constraints, RLS, RPC authority, locks, state transitions, audit attribution, protected commercial projections |
| Concurrency/integration | Competing reservations/dispatches, duplicate commands, membership revocation and eight-role end-to-end flow |
| Visual/manual | Effective R35 parity, Android/web layouts, Excel round-trip, PDF/print short/multi-page output |

No screen-level success substitutes for a direct database negative test.

## 2. Golden acceptance scenarios

AT-01–AT-25 are the preserved Rev 2.0 scenarios. Later accepted production
slices extend the same stable sequence without renumbering those originals.

| ID | Scenario | Primary automated/manual evidence |
|---|---|---|
| AT-01 | Site Engineer creates a project, assigns a Project Engineer and multiple buildings; Procurement cannot create/edit it. | RPC/RLS/route/widget/integration |
| AT-02 | New project receives one independent Workshop Materials BOQ group for Common and each physical building; creating a custom folder name materializes an independent empty sibling in every real scope without copying rows. Historical populated template folders remain visible while untouched inactive shells are suppressed. | database/repository/widget |
| AT-03 | MSD worksheet imports title, seven columns and all rows into the direct-edit grid. | workbook fixture/integration |
| AT-04 | User edits/deletes a cell, row and non-protected column; a later import may use fresh IDs and a changed column/row order without archived-key collisions, and export reproduces the changed worksheet. | controller/workbook/database round-trip |
| AT-05 | Similar Row inserts directly below and preserves configured fields with sequential S:No. | unit/widget |
| AT-06 | Whole BOQ group creates an MR draft but Procurement sees nothing until explicit Submit. | RLS/repository/integration |
| AT-07 | Engineer selects individual BOQ and custom items only from the matching Common/building scope and submits a Scheduled MR. | widget/RPC/integration |
| AT-08 | MR number is unique and project/requester/header data is automatic. | database concurrency/integration |
| AT-09 | Engineering approves the submitted request first; only then Procurement arrangement defaults Warehouse, changes one line to supplier, partially supplies one and marks one unavailable with reason. | repository/widget/RPC |
| AT-10 | Database rejects arrangement above requested and prevents double reservation. | constraint/concurrency pgTAP |
| AT-11 | Creator and assigned/global Project Engineer can edit a submitted pre-approval request with version/audit protection; Procurement and an unrelated Site Engineer cannot. | widget/RPC/RLS/integration |
| AT-12 | Procurement cannot approve a request or arrange/dispatch before Engineering approval. | RPC/RLS negative/integration |
| AT-13 | Dispatch cannot exceed approved outstanding quantity or warehouse availability. | RPC/concurrency |
| AT-14 | Engineer marks one line Received, one Missing and one Damaged; MR remains partially received. | controller/RPC/integration |
| AT-15 | Replacement dispatch is possible only for outstanding quantity and cannot over-supply. | RPC/concurrency |
| AT-16 | When all approved quantity is good received, MR becomes Received and dispatch action disappears. | state unit/RPC/widget |
| AT-17 | DO reference is entered at dispatch stage, dispatched quantities are immutable and PDF/print identity/footer is correct. | RPC/snapshot/PDF visual |
| AT-18 | Return autocomplete shows only eligible good-received items for the selected project/scope. | query/controller/widget |
| AT-19 | Return over eligible quantity is blocked; Procurement confirmation adds inventory once. | RPC/idempotency/concurrency |
| AT-20 | MR/Return/DO short and multi-page PDFs have no overlap; print opens content, not a blank tab. | render/visual/manual browser |
| AT-21 | Project Engineer removes Site Engineer access; old requests retain the original requester. | membership RLS/integration |
| AT-22 | MR deletion/cancel rules are enforced by state and role. | RPC/RLS matrix |
| AT-23 | Admin Configuration, Rentals, Users and Audit still load and operate. | regression/widget/smoke |
| AT-24 | Duct Sizer and ESP Calculator remain available. | widget/smoke |
| AT-25 | RLS negatives prove Procurement cannot mutate project/BOQ, unrelated assigned-role Engineers cannot access another project, all four global Engineer roles receive no commercial/stock authority, and only Senior Mechanical Engineer receives the explicit non-commercial inventory-read exception. | eight-role pgTAP/API |
| AT-26 | Authorized MR comments are append-only; @mentions notify once and unauthorized/stale users cannot be mentioned or read the thread. | RPC/RLS/idempotency/widget |
| AT-27 | Inventory-assisted MR entry returns no commercial/stock fields and fills description, brand, size, model and unit while leaving quantity deliberate. | response-shape/repository/widget |
| AT-28 | Status, owner and next action match across desktop, mobile and the controlled MR projection for every revised stage. | unit/golden/PDF visual |
| AT-29 | A confirmed receipt accepts authorized JPEG/PNG site evidence through the document pipeline; pre-confirmation and unrelated-project uploads fail. | Storage/RPC/RLS/widget |
| AT-30 | An actively assigned Site Engineer can close a fully resolved received MR, Procurement cannot, and tablet/mobile request views recover after suspension through foreground and safety refreshes without clearing the visible projection. | widget/provider/RPC/pgTAP/mobile |
| AT-31 | Exact Admin stages typed Configuration changes and normalized category/unit actions, validates, reviews a required reason and publishes one immutable audited version; all other exact roles and direct table writes fail, while 1366px, tablet and 360px layouts remain usable without overflow. | model/repository/widget/route/pgTAP/responsive visual |
| AT-32 | Team Chat provides authorized Direct, Project, MR, Group and Announcement conversations; group creation is limited to Admin and the four global Project Engineer roles, Direct chat has exactly two visible participants, sends and attachments are idempotent/verified, read state follows the user across devices, a message increments only Team Chat (never the workflow bell), pushes deep-link to the exact thread, and 1366px/tablet/390px/360px states match the R38.5 review hierarchy without overflow. | model/widget/golden/route/Edge payload/pgTAP/Storage/RLS |
| AT-33 | Warehouse Inventory adds Procurement/Admin-only Supplier folders and a five-stage strict import: blank supplier identity is preserved in immutable Unknown Supplier, exact/alias/similar/new decisions are explicit, delivered equals accepted plus damaged plus rejected, external receipt evidence is required, opening balance uses one reviewed cutoff, secure documents and FIFO provenance remain linked, duplicate/failed imports create no partial stock, and desktop/tablet/390px/360px layouts stay bounded. | workbook fixtures/model/controller/widget/route/pgTAP/Storage/RLS/responsive visual |
| AT-34 | Phase 1 MR hardening keeps another user's draft absent from Engineering lists/detail/discussion until Submit; supports one mixed receipt line with exact Good/Missing/Damaged quantities; keeps all-unavailable arrangements editable by Procurement until explicit Engineering/Admin cancellation; and provides inline arrangement errors plus safe-area mobile approval actions. | model/widget/responsive visual/RPC/RLS/idempotency/pgTAP |
| AT-35 | Phase 2 loads 15 lightweight authorized MR summaries with server search/filter/sort/paging, cursor-pages older comments, privately syncs only the creator's draft across devices, version-checks claim/reassign without changing workflow state, notifies the assignee once, and derives a concise returned-request change summary from immutable revisions. | model/controller/repository/widget/RPC/RLS/idempotency/realtime/pgTAP |
| AT-36 | With the adoption default published, an independently authorized Project Engineer/global Engineering/Admin creator can approve their own current request; a Site Engineer creator cannot. | trusted RPC/role pgTAP |
| AT-37 | Publishing creator self-approval off blocks the creator in the trusted command while an independent authorized manager remains able to approve; unpublished draft configuration does not alter authority. | configuration/RPC/pgTAP |
| AT-38 | External readiness is auditable but nonblocking by default; after Admin publishes enforcement, unconfirmed positive external lines are rejected atomically and confirmed lines with optional date/reference succeed. | arrangement model/widget/RPC/atomic pgTAP |
| AT-39 | Procurement cannot create a replacement; authorized Engineering/Admin can create one linked private Draft only after explicit cancellation of a saved all-unavailable request, with idempotent retry and exact request/line provenance. | repository/controller/RPC/RLS/idempotency/pgTAP |
| AT-40 | Phase 3 Admin switches, desktop arrangement row, 360px editor and 360px replacement card remain localized, bounded, keyboard/touch usable and free of client-only authority. | widget/responsive visual/accessibility |

The BOQ **Overview** option is read-only summary, not the Common scope and not a
persisted scope. Common is its own real BOQ. Database coverage proves per-scope
one Workshop Materials folder per real scope, Overview aggregation,
project-wide custom-folder naming with row isolation, Procurement write denial,
legacy assignment idempotency and save/submit MR scope negatives.

## 3. Additional production gates

Rev 2.0 is browser-first but the approved delivery target also includes
Android. Add:

- AP-01: release merged Android manifest declares Internet permission.
- AP-02: production publishing fails when the controlled signing configuration
  is absent; CI uses a clearly separate ephemeral certificate.
- AP-03: project creation, MR create/submit, approval, receipt and return pass on
  a 360px Android emulator/device with keyboard and safe-area changes.
- AP-04: file picker, XLSX import/export, document upload/download and PDF share
  work on Android and web.
- AP-05: offline/reconnect and ambiguous-network retries show Pending/Failed and
  commit critical effects at most once.
- AP-06: web PWA has no portrait-only lock and the BOQ workspace is usable at
  1366x768.
- AP-07: unauthorized commercial values are absent from API JSON, Riverpod
  state, SharedPreferences, export bytes, PDF bytes and notifications.
- AP-08: direct/stale legacy deep links cannot reach Accounts, RFQ/PO, Material
  Plan or contradictory procurement actions.
- AP-09: the R38.3 warehouse renders at 1366x768 and 360x800 without overflow;
  the exact five-sheet client template downloads unchanged, exact aliases map,
  fuzzy categories require confirmation, failed/retried imports retain one
  command identity, and a bad later row leaves no partial item or movement.
- AP-10: Android, physical iOS and supported installed web/PWA clients receive
  one safe Team Chat push for unread non-muted activity (mentions still alert),
  foreground refresh does not duplicate the message, no Chat row or count
  enters the workflow notification centre, opening the exact thread suppresses
  its redundant in-app alert, and marking the thread read updates the backend
  cursor observed by the user on another device. Windows/macOS validate the
  installed HTTPS web app; iOS/iPadOS web validates a Home Screen install on
  16.4 or later after an explicit user alert opt-in.
- AP-11: the R38.9 template, QA workbook and selected reconciled opening-balance
  candidate are rehearsed in staging. Header mapping uses names rather than
  positions; formula text is neutralized; unsupported categories/units remain
  explicit decisions; `source = committed + quarantine/exclusions`; the two
  alternative master workbooks cannot both commit; and 20,000-row parsing,
  1,000-supplier search plus 10,000-line supplier-folder pagination stay
  responsive without loading the complete result set into one widget tree.
- AP-12: at 360px and desktop widths, approval actions remain reachable without
  covering the final request content; each invalid arrangement row is directly
  reachable from the validation summary; mixed receipt quantities reject
  under/over reconciliation; and cancelling an all-unavailable request removes
  it from every Procurement edit path.
- AP-13: a 100-request register never transfers full request lines/comments,
  page navigation requests exact 15-row server windows, older discussion pages
  remain stable while new comments arrive, two devices converge on the same
  owner-private draft, stale draft/assignment writes fail without partial
  effects, and assignment never changes the request state or canonical owner.

## 4. Eight-role security matrix

Every RLS/RPC change supplies positive and negative cases using representative
Project Engineer, Site Engineer, Senior Mechanical Engineer, Project Manager,
Workshop In-Charge, Document Controller, Procurement and Admin JWT claims.
Global Engineer tests must prove all-project MR approval/DO generation and
negative commercial, stock-write and Admin access; Senior Mechanical Engineer
also proves positive inventory read and negative inventory mutation.

Required adversarial techniques:

- direct table select/insert/update/delete;
- direct RPC call without using the Flutter screen;
- guessed project/entity/document IDs;
- unrelated and revoked membership;
- stale version and wrong state;
- caller-provided actor/role/timestamp spoof;
- stale JWT whose exact role no longer matches the protected Auth role,
  including a global-engineer-to-project-engineer demotion;
- missing/revoked commercial capability;
- Storage path/object guessing;
- repeated idempotency key with same and different payload;
- two sessions racing reservation, dispatch or return confirmation.

Tests assert both the denial and absence of partial rows/movements/audit side
effects.

## 5. Quantity and concurrency suites

Test boundary values with Postgres numeric precision:

- zero, fractional and maximum configured decimal scale;
- partial/full/unavailable arrangement;
- aggregate reservations equal/one increment above availability;
- dispatch equal/above approved outstanding and available stock;
- partial receipt followed by replacement in transit;
- good plus separate missing plus damaged reconciliation, including a mixed
  exception on one line and under/over-sum rejection;
- two MRs for the final available stock;
- repeated dispatch after timeout;
- concurrent return submissions for the same remaining eligible quantity;
- confirmed return retry and inventory movement uniqueness.

The result must reconcile root state, line facts, reservations, movements,
notifications and audit events.

## 6. Excel evidence

BOQ fixtures include:

- representative MSD Equipment Schedule with optional title/header rows;
- header-only workbook;
- arbitrary extra technical columns;
- duplicate/blank headings;
- mixed numeric/text quantity cells;
- long/unicode/Arabic values;
- malformed/unsupported workbook.

Prove worksheet selection, mapping preview, explicit transactional commit and
visible title/headings/row export. A failed import creates no partial schema or
rows. Import never submits an MR.

MR and Return workbook tests use their controlled canonical columns and exclude
project metadata that the application supplies.

Only licensed/sanitized fixtures are committed to the repository.

## 7. PDF and print evidence

Render and visually inspect:

- short and multi-page MR, authorized and non-commercial projections;
- long project/client/requester names;
- Arabic/English company header and logo;
- final-page-only approvals/signatures/footer;
- DO with only good quantities and multiple pages;
- Return with four signature roles and multiple pages;
- Chrome and Edge print flow with visible content/no blank tab;
- Android view/share of generated PDFs.

PDF and print use the same domain snapshot/template. Snapshot hash/reference is
asserted so later master edits cannot alter historical output.

## 8. Responsive/accessibility evidence

For each UI batch test:

- 1366x768 desktop web;
- representative tablet width;
- 360px mobile and Android emulator/device;
- text scaling and English/secondary-language copy;
- 44x44 tap targets;
- keyboard traversal/focus visibility on desktop;
- non-color status cues and semantic labels;
- loading, empty, forbidden, offline, conflict and error states;
- no overflow, covered action or unreachable control.

Team Chat additionally tests the 1366px three-pane workspace, 900px two-pane
workspace, 390px conversation list and 360px focused thread/composer. The
desktop details pane collapses before the conversation list, mobile never
shrinks the three-pane layout, the composer stays above safe-area/bottom
navigation, and interactive controls retain at least 44x44 targets.

BOQ specifically tests 500 rows, virtualized focus, sticky identity/header,
Tab/Shift+Tab/arrows/Enter and mobile focused-row Previous/Next behavior. BOQ
material assistance is covered on desktop and 360px mobile, including source
search, current-row exclusion, one-pass mapped field placement, stale search
suppression and preservation of user-entered quantity.

## 9. Per-batch gate

Every implementation batch requires:

1. narrow unit/repository/widget/database tests for changed behavior;
2. positive and negative role tests for changed access;
3. migration idempotency and rollback notes;
4. UI evidence for changed screens;
5. `flutter pub get`;
6. formatting of changed Dart files;
7. `flutter analyze`;
8. complete `flutter test`;
9. release web build with CI Supabase placeholders;
10. release Android build with CI Supabase placeholders;
11. clean `supabase db reset` and `supabase test db` from Batch 1 onward;
12. `git diff --check` and no unrelated worktree changes.

Never waive a failed security/quantity test to meet the rapid-demo timebox.

## 9A. Phase 3 Material Request policy acceptance

- AT-36: with the adoption default published, an independently authorized
  Project Engineer/global Engineering/Admin creator can approve their own
  current request; a Site Engineer creator cannot.
- AT-37: publishing creator self-approval off blocks the creator in the trusted
  command while an independent authorized manager remains able to approve.
  Draft configuration changes do not alter either result.
- AT-38: external readiness is recorded but nonblocking by default. After the
  Admin publishes enforcement, an unconfirmed positive external line is
  rejected without changing the request, arrangement, reservations or audit;
  a confirmed line with date/reference succeeds.
- AT-39: Procurement cannot create a replacement. An authorized Engineering
  actor can create one linked private Draft only after explicit cancellation
  of a saved all-unavailable request; an exact retry returns the same Draft,
  source state remains cancelled and every cloned line retains its source link.
- AT-40: the Admin switches, desktop arrangement row, 360px focused editor and
  360px replacement card render without overflow, preserve at least 44px
  actions and expose no client-only authority.

## 10. Release evidence package

Batch 10 produces:

- scenario result matrix for AT-01–AT-40 and AP-01–AP-10;
- Flutter/database/concurrency/integration command logs;
- desktop/mobile screenshots and controlled-document renders;
- workbook round-trip fixtures/results;
- migration/reconciliation counts and quarantine report;
- staging seed/persona instructions;
- release notes, known limitations and operations/cutover runbook;
- signed artifact provenance without exposing secrets.
