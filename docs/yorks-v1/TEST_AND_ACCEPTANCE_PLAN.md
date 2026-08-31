# Yorks V1 R35 — Test and Acceptance Plan

## 1. Test layers

| Layer | Required proof |
|---|---|
| Dart unit | State derivation, decimal input normalization, canonical column mapping, reference formatting, role/capability resolution |
| Repository/controller | Draft recovery, typed RPC payload/result, connectivity, idempotent retry, conflict/error handling, notification refresh |
| Flutter widget | Nine-role navigation, action visibility, forms, dynamic grid, keyboard behavior, focused mobile editor, localization and responsive layouts |
| Database/pgTAP | Constraints, RLS, RPC authority, locks, state transitions, audit attribution, protected commercial projections |
| Concurrency/integration | Competing reservations/dispatches, duplicate commands, membership revocation and nine-role end-to-end flow |
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
| AT-25 | RLS negatives prove Procurement cannot mutate project/BOQ, unrelated assigned-role Engineers cannot access another project, all four global Engineer roles receive no commercial/stock authority, only Senior Mechanical Engineer receives the explicit non-commercial inventory-read exception, and Accountant receives no technical workflow authority. | nine-role pgTAP/API |
| AT-26 | Authorized MR comments are append-only; @mentions notify once and unauthorized/stale users cannot be mentioned or read the thread. | RPC/RLS/idempotency/widget |
| AT-27 | Inventory-assisted MR entry returns no commercial/stock fields and fills description, brand, size, model and unit while leaving quantity deliberate. | response-shape/repository/widget |
| AT-28 | Status, owner and next action match across desktop, mobile and the controlled MR projection for every revised stage. | unit/golden/PDF visual |
| AT-29 | A confirmed receipt accepts authorized JPEG/PNG site evidence through the document pipeline; pre-confirmation and unrelated-project uploads fail. | Storage/RPC/RLS/widget |
| AT-30 | An actively assigned Site Engineer can close a fully resolved received MR, Procurement cannot, and tablet/mobile request views recover after suspension through foreground and safety refreshes without clearing the visible projection. | widget/provider/RPC/pgTAP/mobile |
| AT-31 | Exact Admin stages typed Configuration changes and normalized category/unit actions, validates, reviews a required reason and publishes one immutable audited version; all other exact roles and direct table writes fail, while 1366px, tablet and 360px layouts remain usable without overflow. | model/repository/widget/route/pgTAP/responsive visual |
| AT-32 | Team Chat provides authorized Direct, Project, MR, Group and Announcement conversations; group creation is limited to Admin and the four global Project Engineer roles, Direct chat has exactly two visible participants, sends and attachments are idempotent/verified, read state follows the user across devices, ordinary sender edits and soft-deletes are versioned/idempotent while MR discussion stays append-only, receipt marks derive from server delivery/read cursors, a message increments only Team Chat (never the workflow bell), pushes deep-link to the exact thread, and 1366px/tablet/390px/360px states match the R38.5 review hierarchy without overflow. | model/widget/golden/route/Edge payload/pgTAP/Storage/RLS |
| AT-33 | Warehouse Inventory adds Procurement/Admin-only Supplier folders and a five-stage strict import: blank supplier identity is preserved in immutable Unknown Supplier, exact/alias/similar/new decisions are explicit, delivered equals accepted plus damaged plus rejected, external receipt evidence is required, opening balance uses one reviewed cutoff, secure documents and FIFO provenance remain linked, duplicate/failed imports create no partial stock, and desktop/tablet/390px/360px layouts stay bounded. | workbook fixtures/model/controller/widget/route/pgTAP/Storage/RLS/responsive visual |
| AT-34 | Phase 1 MR hardening keeps another user's draft absent from Engineering lists/detail/discussion until Submit; supports one mixed receipt line with exact Good/Missing/Damaged quantities; keeps all-unavailable arrangements editable by Procurement until explicit Engineering/Admin cancellation; and provides inline arrangement errors plus safe-area mobile approval actions. | model/widget/responsive visual/RPC/RLS/idempotency/pgTAP |
| AT-35 | Phase 2 loads 15 lightweight authorized MR summaries with server search/filter/sort/paging, cursor-pages older comments, privately syncs only the creator's draft across devices, version-checks claim/reassign without changing workflow state, notifies the assignee once, and derives a concise returned-request change summary from immutable revisions. | model/controller/repository/widget/RPC/RLS/idempotency/realtime/pgTAP |
| AT-36 | With the adoption default published, an independently authorized Project Engineer/global Engineering/Admin creator can approve their own current request; a Site Engineer creator cannot. | trusted RPC/role pgTAP |
| AT-37 | Publishing creator self-approval off blocks the creator in the trusted command while an independent authorized manager remains able to approve; unpublished draft configuration does not alter authority. | configuration/RPC/pgTAP |
| AT-38 | External readiness is auditable but nonblocking by default; after Admin publishes enforcement, unconfirmed positive external lines are rejected atomically and confirmed lines with optional date/reference succeed. | arrangement model/widget/RPC/atomic pgTAP |
| AT-39 | Procurement cannot create a replacement; authorized Engineering/Admin can create one linked private Draft only after explicit cancellation of a saved all-unavailable request, with idempotent retry and exact request/line provenance. | repository/controller/RPC/RLS/idempotency/pgTAP |
| AT-40 | Phase 3 Admin switches, desktop arrangement row, 360px editor and 360px replacement card remain localized, bounded, keyboard/touch usable and free of client-only authority. | widget/responsive visual/accessibility |
| AT-41 | MR description suggestions remain anchored to the active field, use a readable grouped BOQ/inventory panel with descriptive metadata, fit the viewport at 1366px, tablet and mobile widths, and copy no commercial value or quantity. | repository/widget/golden/responsive visual |
| AT-42 | Publishing or discarding Configuration changes clears staged settings/actions with production-safe primary-key predicates; a reviewed non-system category archive and controlled-unit creation publish atomically without weakening authority, history, audit, validation or idempotency. | migration/pgTAP/control-plane regression |

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
- AP-08: while `YORKS_V1_ACCOUNTS` is off, normalized Accounts routes/actions
  are unreachable. After the accepted T05+ cutover, only normalized
  capability-guarded Accounts links may resolve; direct/stale legacy Finance,
  RFQ/PO, Material Plan or contradictory Procurement links remain unreachable.
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

## 4. Nine-role security matrix

Every RLS/RPC change supplies positive and negative cases using representative
Project Engineer, Site Engineer, Senior Mechanical Engineer, Project Manager,
Workshop In-Charge, Document Controller, Procurement, Accountant and Admin JWT
claims.
Global Engineer tests must prove all-project MR approval/DO generation and
negative commercial, stock-write and Admin access; Senior Mechanical Engineer
also proves positive inventory read and negative inventory mutation.
Accountant tests prove no technical project membership and no Project, BOQ, MR,
Dispatch, Receipt, Inventory, Return or membership mutation.

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

## 9B. Scoped capability management acceptance

- AP-11: seeded role defaults reproduce the current effective decisions for all
  nine exact roles, project memberships and existing commercial overrides;
  Accountant has no technical membership or operational mutation baseline;
  parity has zero unexplained differences before consumer cutover.
- AP-12: organization and one/many-project grants and denies resolve
  deterministically; a project deny overrides an organization grant for that
  project, expiry/revocation/inactive target fail closed, and unknown
  capability/scope/effect inputs are rejected.
- AP-13: a permission administrator cannot target themselves, grant above the
  delegation ceiling, remove/expire the final active permission administrator,
  or bypass the version/reason/idempotency requirements. Future denies and
  expiring grants on `users.view`, `permissions.view`, `permissions.manage` or
  `permissions.delegate` are rejected, including cross-scheduled changes that
  would otherwise leave no manager at a later clock boundary.
- AP-14: stale competing changes have no partial effects; an exact retry returns
  the committed workspace without duplicating assignment, revision, history or
  audit evidence.
- AP-15: direct table APIs cannot read another user's assignments/history or
  mutate catalogue/template/assignment/scope/revision/history/parity data.
- AP-16: the current-user provider initiates its revision subscription before
  the first protected fetch. A confirmed initial snapshot may render read-only
  while the channel joins, but every mutation stays disabled until both the
  snapshot and invalidation channel are healthy. Once trusted, the provider
  retains the last confirmed snapshot and keeps eligible actions available
  during coalesced routine refreshes. An actual revision signal marks that
  snapshot stale and pauses writes until the replacement is confirmed. The
  provider purges on logout/inactive/authorization failure, polls safely if
  Realtime is unavailable, and atomically updates navigation, search targets
  and actions after a server-confirmed revision.
- AP-17: User Management presents inherited/granted/denied/protected/shadow
  states, reasoned review, conflict recovery and append-only history at 1366,
  1024, 390 and 360px with keyboard/focus, 200% text, secondary language,
  screen-reader labels and at least 44x44 controls.
- AP-18: Admin, Senior Mechanical Engineer and a bounded delegated actor pass
  real Edge -> GoTrue -> trigger tests for their allowed actions; inactive,
  revoked, stale, self-target and above-hierarchy actions fail. V1 Auth bodies
  with secondary roles, caller caps or a legacy-shell switch are rejected. A
  failure between identity creation and role stamping resumes under the same
  HMAC-bound idempotency key, while a lost-response retry returns the same
  stable app user ID with exactly one `admin_user_created` audit.

## 9C. R39 Accounts T01 foundation acceptance

T01 is documentation, role/catalogue/schema/RLS/default-policy foundation only.
It protects the default-stage template and its 100% total, but does not create
project physical-building allocation relations or row-level allocation
constraints. `YORKS_V1_ACCOUNTS` stays off, no normalized Accounts route or
mutation command is reachable, and `/admin/finance` remains non-authoritative.

| Requirement/test | Required T01 proof |
|---|---|
| FR-002, FR-003 | Additive normalized Accounts foundation only; no legacy Finance mutation authority and no behavior change in Projects, BOQ, MR, Procurement, Inventory, logistics, Returns or retained modules. |
| FR-014 | Default-off flag removes normalized routes, search targets and actions and fails closed when dependencies are absent. |
| FR-016, FR-017 | `accountant` is accepted by every centralized exact-role/Auth/audit constraint but rejected as technical project membership. |
| FR-018 | All 15 exact Accounts keys exist in one protected catalogue as shadow/nonassignable; Flutter has no role-name-derived command grant. |
| FR-019–FR-025 | Role/template projections preserve Engineering, Site, Procurement, Accountant, Admin and capability-based management separation; revocation/inactive/stale claims fail closed while history remains. |
| FR-029 | Defaults are 90/10 and protected stage-template rows are 10/50/30/5/5; a negative migration test proves that the T01 template cannot drift from 100% within numeric tolerance. |
| FR-030, FR-031 | T01 proves the protected policy says physical allocations total 100% and Common / All Buildings is non-physical, and proves no project allocation relation/command is exposed prematurely. T02 must prove row-level/server-command enforcement on the commercial baseline. |
| NFR-MAINT-003 | Clean reset/re-run is additive and repeatable; documented forward rollback disables the flag/consumer without deleting evidence. |
| NFR-MAINT-004 | Auth parsing, role constraints, user management, route guards, RLS/RPC allowlists, audit constraints, seed personas and tests use the same nine-role/15-capability source. |
| AT-SEC-003 | Accountant direct-table and ordinary-RPC BOQ/MR/Dispatch mutations are denied with no partial row or audit effect. |
| AT-SEC-006 | Inactive Accountant with a stale token cannot read or command Accounts and protected client state is purged. |
| AT-SEC-007 | Unknown role receives no Accounts capability, projection, route or command privilege. |

The parity fixture covers the prior eight operational roles plus Accountant.
It must report zero unexplained changes to existing access and prove that the
new role/capabilities remain inert outside the shadow foundation.

## 9D. R39 Accounts T02 server-slice acceptance

T02 is accepted only as a protected database/RPC slice. The app flag remains
off, normalized Accounts routes/UI are absent, no claim/invoice/supplier-bill
command is reachable, and no print/export/upload consumer is claimed. Tests
must create explicit real-project fixtures through protected setup; migrations
must not seed demo baseline money or reinterpret legacy Finance.

### T02 functional and calculation proof

| Requirement/test | Required proof in T02 | Phase boundary |
|---|---|---|
| FR-026–FR-028 | Initialize exactly one revision-1 profile with positive fixed-numeric contract value, currency, terms/reminder, explicit validated VAT, physical/stage allocation snapshots, effective date and audit; later change is a numbered immutable revision. | Complete in T02 except submitted invoice snapshot persistence, which T03 exercises. |
| FR-029 | New baseline defaults terms/reminder to 90/10 and validates `0 <= reminder <= terms`; later invoice snapshot is not synthesized. | Baseline complete T02; invoice retention T03. |
| FR-030, FR-031 | Active physical rows total 100.0000 within 0.00005 and Common is rejected/excluded. `99.9990` fails atomically. | Complete T02. |
| FR-032–FR-034 | Active stages total 100.0000, default order is 10/50/30/5/5, initialization is idempotent, Stage Value is server-derived, and rounded stage/building total reconciles to baseline. | Complete T02; T06 later compares export. |
| FR-035–FR-037 | No in-place baseline mutation; revision has reason/actor/exact role/time and preserves prior snapshot. | Revision complete T02; submitted-claim/invoice immutability completes T03. |
| FR-038 | Negative reminder and reminder greater than terms fail without partial rows/audit. | Complete T02. |
| FR-039, FR-040 | Role-safe baseline projection exposes active status, revision, effective date, allocations, actor and reason according to capability. | Projection complete T02; T05 rendering and T06 print/export deferred. |
| FR-041–FR-047 | Unique current progress dimension; suggestion and confirmation remain separate; 0–100; project/building scope enforced; suggestion evidence summary/reference retained; increased confirmation needs an authorized evidence reference. | Complete T02; no exception route is enabled. |
| FR-048 | Explicitly configured review rule produces pending blocker; only `review_commercial_progress` can satisfy it. Default is disabled/null and no threshold is invented. | Review facts complete T02; Prepare Claim command is T03. |
| FR-049, FR-050 | Confirmed Eligible and cumulative eligible are server-calculated decimal strings and reconcile row/register totals. | Complete T02. |
| FR-051, FR-052 | Protected seams exist and no T02 claim command can consume eligibility or permit unsafe state. | Non-cancelled/cancelled claim subtraction, double-claim and blocking references complete in T03. |
| FR-053–FR-055 | Every suggestion/confirmation/review/correction is append-only with before/after/evidence/reason/actor/role/time; commercial progress is separate from technical completion, claimed, certified and paid. | Complete for T02 facts; T03 adds later monetary states. |
| FR-056 | Server filters building/stage/action owner/evidence without changing unfiltered totals or hiding blockers. | Query complete T02; filter UI T05. |
| FR-057 | Authorized T02 projection/revision data source is internally consistent and role-safe. | Export file/layout T06. |
| FR-058, FR-059 | Non-value response includes percent/evidence/owner and omits every monetary key; Project Engineer confirms independently of value visibility. | Server shape complete T02; UI/network integration T05. |
| FR-060 | Projection returns server-derived command flags/blockers for Suggest, Confirm, Add Evidence and configured Review; Prepare Claim remains false/unreachable. | T02 facts complete; T03 adds claim authority and T05 renders actions. |

### Required scenario and edge-case matrix

| Test | T02 assertion |
|---|---|
| AT-E2E-001 | Admin initializes four physical buildings plus default stages; both sets total 100, revision 1 is active, one trusted audit exists. |
| AT-E2E-002 | Authorized Site Engineer suggestion with evidence is stored while confirmed and eligible remain unchanged. |
| AT-E2E-003 | Authorized Project Engineer confirms below suggestion; eligible uses confirmed %, both facts remain visible, one revision/audit is appended. |
| AT-E2E-004 | A fixture with an explicit management threshold returns a pending blocker; authorized review satisfies it. No Prepare Claim command exists until T03. |
| AT-BL-001 | Zero, negative, malformed/NaN/client-float contract values fail; no partial baseline/audit. |
| AT-BL-002 | 99.999% physical allocation fails outside the explicit tolerance. |
| AT-BL-003 | Common / All Buildings input is rejected and never appears as a physical row. |
| AT-BL-004 | Default 10/50/30/5/5 stages activate once and remain idempotent. |
| AT-BL-005 | Reminder greater than terms fails save/activation. |
| AT-BL-006 | T02 proves revision-only edit; T03 adds the submitted-claim blocker fixture. |
| AT-BL-007 | T02 preserves old baseline terms; T03 proves an existing invoice due date does not change. |
| AT-BL-008 | T02 report-source totals/revision/actor/allocations reconcile; T06 proves printed page layout. |
| AT-PROG-001 | -1% and 101% suggestion/confirmation fail server-side. |
| AT-PROG-002 | Increased confirmation without an authorized evidence reference fails; no unconfigured exception is accepted. |
| AT-PROG-003 | 80% suggestion + 60% confirmation exposes both and calculates eligibility from 60%. |
| AT-PROG-004 | T02 rejects unsupported correction paths; T03 proves reduction below an active claim basis returns exact claim references. |
| AT-PROG-005 | Two confirmations using one expected version yield exactly one success and one stale conflict. |
| AT-PROG-006, AT-PROG-007 | Deferred to T03: non-cancelled claim value is subtracted once; cancelled claim is released without rewriting history. |
| AT-PROG-008 | Site response retains percent/evidence/owner but has no money keys. |
| AT-SEC-001, AT-SEC-008 | Direct projection and serialized RPC/network fixture contain no protected monetary field names or values without capability. T05 repeats this through the app. |
| AT-SEC-004 | Unassigned Project Engineer guessing project/building UUIDs receives denial/no row and no existence leak. |
| AT-SEC-005 | Revoked/inactive actor immediately loses T02 read/command access; T05 later proves client-cache purge. |
| AT-CONC-002 | Same idempotency key + same canonical request hash returns the stable first result with one effect/audit. |
| AT-CONC-003 | Same key + different hash conflicts with no second effect/audit. |
| AT-CONC-005 | T02 versions immutable baselines; T03 proves open claim drafts become stale and are never silently rebased. |

### Database and integration commands

The T02 gate includes clean `supabase db reset`, `supabase test db`, focused
pgTAP for every table/RLS/RPC response shape, and at least two real-session
concurrency harnesses for progress version conflict and idempotency hash
conflict. Each SECURITY DEFINER function is tested for `search_path`, execute
grants, live-role recheck and direct-table denial. Flutter golden/responsive
evidence is explicitly not a T02 gate because T05 owns the UI.

The six T02 capabilities may leave shadow only after this matrix passes. The
feature flag still stays off and no production readiness statement is allowed.

## 9E. R39 Accounts T03 receivables-slice acceptance

T03 is accepted only when the protected claims/receivables server slice and
its typed Flutter boundary agree on the same state, amounts, identity and
command flags. The feature flag stays off and T03 adds no route, screen,
notification, document upload, report or export consumer.

| Requirement/test | Required T03 proof |
|---|---|
| FR-061–FR-067 | Project-scoped claim draft snapshots the active baseline and progress revisions; each line has eligible/prior/current values and evidence; creator/Admin versioned draft maintenance is enforced; submit moves to Accounts review; stale/cap/evidence failures are atomic. |
| FR-068–FR-080 | Case-insensitive invoice reference uniqueness per project; positive ex-VAT cap; explicit audited Admin exception; immutable VAT/terms/due snapshots; exact derived state; reasoned return/cancel; no hard deletion after submission. |
| FR-081–FR-090 | Certification facts are append-only cumulative revisions with required reference/date, invoice VAT snapshot, partial-difference reason, upper bound, expected-version and idempotency protection. |
| FR-091–FR-098 | Client payment facts are append-only; partial receipts derive state; project-wide case-insensitive references are unique; totals cannot exceed certified incl. VAT; correction is one exact linked reversal. |
| FR-099–FR-110 | Exact PDC states/transitions, required cheque facts, reason/action on return/bounce, replacement linkage, separate exposure and one payment only on evidence-backed clearance; due position derives from immutable invoice dates. Notification scheduling/UI remains T06. |
| AT-BL-006/007, AT-PROG-004/006/007, AT-CONC-005 | Submitted/non-cancelled claims block unsafe baseline/progress reduction with exact references, consume eligibility once, explicit cancellation releases without history rewrite, and baseline revision marks open drafts stale without rebasing. |
| AT-INV-001–009, AT-CERT-001–004, AT-PAY-001–005, AT-PDC-001–004/007 | Exact state/calculation/authority/append-only assertions pass. AT-INV-010, AT-CERT-005 and PDC notification portions remain T06. |
| AT-SEC-002–008 | Only the five promoted T03 capabilities can call their commands; Project Engineer cannot certify/pay/manage PDC, Accountant cannot mutate technical progress, Procurement cannot access client receivables, direct table writes fail, and revoked/inactive/stale identities fail closed. |
| AT-CONC-001–004 | Root/project lock order, expected version and request-hash idempotency produce one effect and one audit under duplicate, competing and lost-response retries. |

The database gate is clean `supabase db reset`, `supabase test db`, focused
pgTAP including real-session concurrency, direct-table/RLS and serialized
response-shape checks. The Flutter gate covers strict decimal-string decoding,
unknown-state rejection, project/entity response binding, protected-cache
purge, offline/denied/stale/uncertain mapping and same-key retry recovery.

## 9F. R39 Accounts T04 supplier-bill-slice acceptance

T04 is accepted only when supplier evidence, match state, approval and payment
are server-authoritative and the typed Flutter boundary preserves the same
identity, amounts, states and command flags. The feature flag stays off and T04
adds no route, screen, notification, upload, report or export consumer.

| Requirement/test | Required T04 proof |
|---|---|
| FR-111–FR-115 | Protected supplier bills store exact project/supplier/invoice/due/value/evidence facts; supplier invoice identity is case-insensitively unique within the project; no engineering or ordinary-table read/write leaks. |
| FR-116–FR-120 | PO/LPO requires reference plus current controlled document; accepted delivery is derived from confirmed good receipt; supplier invoice requires a current controlled document; `matched`/`review`/`blocked` is server-derived and explicit mismatch fails closed. |
| FR-121–FR-125 | Procurement creates/maintains evidence only; Accountant/Admin approves and pays; Procurement cannot self-approve; supplier-invoice document has no exception; Admin unmatched exceptions require a fresh reason and audit on each command. |
| FR-126–FR-130 | Partial payment, exact total-including-VAT cap, append-only payment and linked reversal, project-wide case-insensitive payment-reference uniqueness, cancellation protection and role-safe projections pass. T06 owns notifications/exports/doc-upload UI. |
| AT-SUP-001–010 | Complete, partial and missing evidence produce exact match states; cross-project evidence is rejected; payment cannot precede authority/evidence; retry produces one effect; overpayment/double reversal/payment-backed cancellation fail atomically; Admin exception is attributable. |
| AT-SEC-002–008 | Engineering and Procurement receivables reads fail; ordinary table APIs and internal helpers remain denied; stale/inactive/unknown identities fail closed; only the three promoted T04 capabilities execute their accepted commands. |
| User Management non-regression | Existing action-only password-reset/activation authority remains usable across Accounts-bearing target roles, while exact-role creation/change still evaluates the full Accounts-aware delegation ceiling and is denied outside it. |

The database gate is a clean reset plus focused pgTAP for capability state,
RLS/direct-table denial, controlled-document and trusted-receipt correlation,
role separation, match calculation, exception reason/audit, payment caps,
idempotency, reversal and append-only enforcement. Flutter tests cover strict
decimal/timestamp/state decoding, project/entity binding, no client-receivable
keys, command error mapping, persistent idempotency leases, uncertain retry and
protected-state purge.

## 9G. R39 Accounts T05-T07 application and release acceptance

| Surface | Required proof |
|---|---|
| Routes and caches | Flag-off and unauthorized deep links redirect safely; capability or identity loss removes protected state and commands. Legacy Finance is never a fallback. |
| Responsive UI | Portfolio, Billing, Invoices, Supplier Bills, Documents and Activity render without overflow at 1440x900, 1366x768, 1024x768, 820x1180, 390x844 and 360x800. Desktop keeps registers; compact widths use cards/focused controls. |
| Documents/audit | Accounts evidence uses controlled, versioned documents and append-only server audit with exact actor/role/time. Cross-project and unauthorized access fail at the server. |
| Notifications/jobs | Due reminders derive from immutable invoice/PDC facts. The service-only runner is idempotent/retryable and failed runs are visible in private operational health. |
| Export/print | Server-scoped structured projections drive both XLSX and PDF/print; formula-like cells are neutralized, headers repeat and totals reconcile. |
| Observability | Success metrics derive from committed audit facts; rejected/conflict/infrastructure client events carry safe structured outcome, latency and `ACC-…` support reference without payloads, SQL or commercial values. |
| Security/non-regression | Nine-role/15-capability positive/negative pgTAP, direct-table/RPC denial and unrelated module regression gates pass from a clean reset. |
| Release decision | Site Engineer, Project Engineer, Accountant, Procurement and Admin pass staging UAT on the same commit, no P0/P1 remains, artifact hashes are recorded and release owner explicitly approves flag enablement. |

Local implementation evidence and remaining external staging gates are kept in
[`R39_ACCOUNTS_T07_RELEASE_EVIDENCE.md`](R39_ACCOUNTS_T07_RELEASE_EVIDENCE.md).

## 9H. Workforce T01 foundation acceptance

T01 has no visual acceptance lane because it exposes no route. Its gate is a
clean migration reset plus focused/full pgTAP proving the 12-key shadow
catalogue, complete nine-role matrix, six private RLS relations, independent
worker identity, exact-Admin RPC boundary, optimistic versions, idempotent
retry, overlap exclusion, effective temporary precedence, responsibility
resolution, immutable history and one audit event per command. Every private
relation is checked across authenticated SELECT, INSERT, UPDATE and DELETE;
Site Engineer, Project Engineer and Procurement are denied the public RPC even
when responsibility exists. Assignment tests also prove finite worker/team
windows, invariant-preserving worker-date updates and active parent projects
when an otherwise-active project scope remains available.

Flutter acceptance proves the default-off/fail-closed flag, exact client key
vocabulary, strict schema-v1 decoding, workers without Auth links, exact RPC
parameters and offline/denied/conflict/malformed-response mapping. Analyzer and
applicable release builds remain required. No deployment or flag enablement is
part of this gate.

## 9I. Workforce T02 calendar/shift acceptance

T02 has no visual lane because it exposes no route. Its gate is a clean reset,
focused/full pgTAP and focused typed repository tests proving:

- all five new relations use RLS, expose no authenticated CRUD and allow
  direct table administration only to `service_role`;
- every Workforce capability remains planned, shadow and nonassignable;
- exact Admin can use every T02 projection/command while Project Engineer,
  Site Engineer and Procurement fail closed;
- IANA timezone, ordered effective dates, integer minute bounds, exactly seven
  unique ISO weekdays, unique dated exceptions and day-type/override
  consistency are enforced;
- calendar, shift and team effective configurations cannot overlap where
  ambiguous; referenced calendar/shift semantic fields, weekday meanings,
  effective team links and past/current overrides cannot drift in place;
- a non-overlapping successor version and future unused draft correction remain
  possible; calendar/shift parents with only expired retained references remain
  readable/retirable while current/future references cannot be stranded;
- past/current override active state is immutable, and deterministic boundary
  fixtures prove that the database session timezone cannot change override,
  team-link or parent-retirement decisions made in the linked calendar IANA
  timezone;
- cross-midnight shifts retain `shift_start_date` work-date semantics;
- mutations prove optimistic stale-version rejection, same-payload retry,
  different-payload idempotency conflict, one audit event per retry and no hard
  delete; and
- the schema-v1 Dart model/repository fails closed for flag-off, offline,
  missing backend, malformed response and invalid client input.

The gate also proves that T02 creates no attendance/timesheet fact, route,
sidebar entry, capability consumer, flag enablement, remote migration or
deployment. Stop before T03.

## 9J. Workforce T03 daily-attendance acceptance

T03 has no visual lane because it exposes no route. Its clean reset plus
focused/full pgTAP and focused Flutter gates must prove:

- the attendance relation uses RLS, has no authenticated CRUD, is directly
  administered only by `service_role` and cannot be hard-deleted;
- exactly one row exists per worker/date, statuses are closed, minutes are
  integers bounded by 1,440, present has positive time and every other status
  has zero time;
- creation requires active employment and an effective assignment/schedule;
  explicit work on a non-working day is retained rather than inferred;
- creation and correction reject a future work date using the exact retained
  calendar timezone and server clock, independent of the database session
  timezone; an existing future row remains preserved and read-only;
- exact assignment, responsibility, calendar, shift and day-type snapshots do
  not drift when parents change; later worker inactivity alone does not block a
  controlled versioned correction;
- only `workforce.view` and `workforce.attendance.maintain` are operational,
  enforced and assignable. Admin succeeds organization-wide; a genuinely
  capability-plus-responsibility-scoped maintainer succeeds only in scope;
  unscoped Project Engineer, Site Engineer, Procurement and inactive/revoked/
  expired actors fail closed;
- direct table APIs, wrong worker/date, unknown payload keys, stale version,
  different-payload idempotency reuse and competing writers fail safely, while
  identical retry returns one result and creates one audit effect; and
- the typed repository rejects flag-off, offline, missing backend, denied,
  stale, invalid input and malformed schema-v1 responses.

The gate also proves T03 adds no allocation/monthly period, timesheet,
notification, document, report/export, route/sidebar/screen, legacy migration,
feature enablement, remote migration or deployment. Stop before T04.

The competing-writer evidence is the repeatable local-only command
`./tool/test_workforce_t03_concurrency.sh`, not a sequential pgTAP substitute.
It must observe two independent writer sessions blocked inside the same
worker/date save RPC, then prove one create plus one `40001` loser and one
same-version correction plus one `40001` loser, with exactly one row and one
audit/idempotency effect per winning transition.

## 9K. Workforce T04 daily-allocation acceptance

T04 has no visual lane because it exposes no route. Its clean reset, focused
and complete pgTAP, strict Flutter and local concurrency gates must prove:

- private RLS relations deny authenticated CRUD/helpers, allow service-role
  administration only, retain immutable revisions and reject hard delete;
- active project/own-scope and active internal-location target shapes work,
  while mixed, cross-project, inactive, missing and unknown-key inputs fail;
- active revision regular/overtime sums reconcile separately and exactly to a
  present parent day; zero-time statuses, negative/fractional/over-1,440 and
  mismatched minute inputs fail;
- optional time evidence is paired, calendar-local, cross-midnight capable and
  non-overlapping; adjacent half-open intervals remain valid;
- Admin and a capability-plus-worker-and-target-responsibility maintainer read
  and write in scope. Role, technical membership, capability without
  responsibility, responsibility without capability, unauthorized target,
  inactive/revoked/expired identity and guessed UUIDs fail closed;
- save/withdraw are optimistic, idempotent and audited once. Identical retry
  returns one result/effect; stale or same-key/different-payload calls fail;
- active allocations block attendance correction; only a timesheet-authorized
  zero-line withdrawal revision releases that guard without changing the
  attendance row; and
- the typed model/repository/controller fails closed for flag-off, offline,
  missing backend, denied, stale, malformed input/response and uncertain
  network outcome.

The repeatable local-only `./tool/test_workforce_t04_concurrency.sh` must use
two independent database sessions on the same allocation set and prove one
winner, one stable conflict, one authoritative revision and no lost update or
duplicate audit/idempotency effect. The gate also proves there is no T05 route,
screen, roster action, monthly lifecycle, review, export, feature enablement,
remote migration or deployment.

T04 database acceptance must also prove that its pgTAP fixtures coexist with
other valid Workforce allocation history. Run this regression in order, with
no reset between the concurrency harness, the second focused run and the
complete suite:

```bash
npx --yes supabase db reset --local
npx --yes supabase test db --local \
  supabase/tests/database/yorks_workforce_t01_foundation.test.sql \
  supabase/tests/database/yorks_workforce_t02_calendars_shifts.test.sql \
  supabase/tests/database/yorks_workforce_t03_daily_attendance.test.sql \
  supabase/tests/database/yorks_workforce_t04_timesheet_allocations.test.sql
./tool/test_workforce_t04_concurrency.sh
npx --yes supabase test db --local \
  supabase/tests/database/yorks_workforce_t01_foundation.test.sql \
  supabase/tests/database/yorks_workforce_t02_calendars_shifts.test.sql \
  supabase/tests/database/yorks_workforce_t03_daily_attendance.test.sql \
  supabase/tests/database/yorks_workforce_t04_timesheet_allocations.test.sql
npx --yes supabase test db --local
```

The concurrency harness intentionally retains its local-only `593*` fixtures.
The second focused run and the complete suite must therefore pass without
assuming any Workforce allocation relation is empty. Every T04 data assertion,
snapshot scalar and mutation probe is scoped to the committed `592*` pgTAP
fixture allocation set, attendance day, revision or idempotency keys.

## 9L. Workforce T05 Supervisor Daily Roster acceptance

The T05 backend lane must prove:

- the migration chain parses from a clean local reset, adds no capability and
  keeps every internal SECURITY DEFINER helper unavailable to
  `public`/`anon`/`authenticated`;
- missing roster rows are a read-only projection with schedule suggestions,
  while future dates, an empty authorized result and authority-restricted rows
  expose no command authority or hidden allocation identifiers;
- read/filter `selectors` are distinct from mandatory `allocation_targets`;
  worker-only responsibility exposes no command target, while an explicit
  worker plus internal-location responsibility exposes only that active target;
- mixed retained calendar timezones keep page-level `is_future` coherent with
  returned-row command flags, page `limit`/`offset` round-trip exactly, and both
  roster reads and atomic saves accept at most 500 rows and reject 501;
- unscoped Project Engineer, Site Engineer and Procurement calls expose zero
  rows, zero selectors and no maintain flags; capability without dated
  responsibility, revoked/expired authority, banned identity, mixed worker
  scope and uncovered allocation target fail atomically;
- strict allowlists, integer minute bounds, optional overtime evidence,
  per-row attendance/allocation versions, root/child idempotency and audit all
  fail closed without partial writes;
- active allocation totals cannot be changed through `preserve`; `replace` and
  `withdraw` require their exact set version; and a restricted evidence-only
  `preserve` with null hidden set version updates attendance evidence while the
  allocation revision/history stays byte-for-byte authoritative; an active set
  with an uncovered target advertises no row or aggregate timesheet action;
- roster future save is denied and retained-future T04 save and withdraw are
  both rejected at the shared revision boundary; and
- every T05 scalar/count is scoped to its committed `594*` fixture so the suite
  passes with unrelated retained Workforce records.

The real two-session race and post-race isolation order is:

```bash
npx --yes supabase db reset --local
npx --yes supabase test db --local \
  supabase/tests/database/yorks_workforce_t03_daily_attendance.test.sql \
  supabase/tests/database/yorks_workforce_t04_timesheet_allocations.test.sql \
  supabase/tests/database/yorks_workforce_t05_supervisor_daily_roster.test.sql
./tool/test_workforce_t05_roster_concurrency.sh
npx --yes supabase test db --local \
  supabase/tests/database/yorks_workforce_t05_supervisor_daily_roster.test.sql
```

The `595*` harness must place two independent create writers and then two
same-version correction writers inside `v1_save_workforce_daily_roster` behind
the same canonical advisory-lock barrier. Each race yields one commit, one
stable `40001` loser, one authoritative row/version and one root
audit/idempotency effect. The final no-reset pgTAP proves retained valid roster
history cannot contaminate the isolated acceptance fixture.

Flutter acceptance must additionally prove:

- flag-off, unauthorized/inactive/revoked deep links and capability loss fail
  closed and purge protected roster/draft state;
- strict response and save models reject missing backend, offline critical
  save, denied, stale, malformed, unknown, future and uncertain outcomes while
  preserving a retryable local draft and stable idempotency key where safe;
- mixed attendance/timesheet authority, hidden-allocation preservation,
  selector/target validation, bulk selection, schedule prefill, Copy Previous
  Day sanitization, local Review Day and atomic Save Day behave exactly as the
  T05 authority contract requires;
- 1440x900, 1366x768 and 1024x768 desktop layouts have no page overflow, keep
  sticky Worker/header context and use deliberate local grid scrolling. The
  360x800 boundary has no editor or overflow;
- English plus the configured secondary-language/RTL lane, 44x44 actions,
  semantic worker labels, visible focus and Tab/Shift+Tab, arrows and
  Enter/Shift+Enter traversal remain deterministic; and
- production-shaped web and ephemeral-signed Android releases build with
  `YORKS_V1_WORKFORCE` off. No T05 test may enable production, migrate remotely,
  commit, push, deploy or begin the T06 monthly lifecycle.

## 9M. Workforce T06 Monthly Period and Validation acceptance

T06 is accepted only when a clean reset and focused/full database lanes prove:

- private period/run/worker/date/issue relations have RLS, no authenticated
  CRUD or helper execution, service-role direct administration and no hard
  delete; reading an absent period creates no row;
- team-plus-month uniqueness, first-of-month input, server-derived membership,
  retained effective assignment/supervisor/calendar/day-type/attendance/
  allocation evidence and immutable prior validation runs;
- an accepted T03 date remains in its retained team with its exact assignment,
  schedule and T04 allocation after an allowed T01 past-assignment move, while
  the replacement team cannot absorb it and no worker/date duplicate appears;
- after the last current assignment moves and the old team's mutable current
  window no longer overlaps the month, the authorized selector still returns
  the retained team, absent-period read creates nothing and explicit validation
  initializes one period. A replacement team cannot absorb the date, while a
  non-effective team with no retained attendance or period stays hidden and is
  rejected by read/validation;
- legitimate mid-month leaver history and valid retained allocation targets do
  not become blocking merely because the worker later leaves or a project,
  scope or internal location later closes. Missing supervisors block both
  branches, currently inactive prospective supervisors block, and later
  deactivation does not rewrite a non-null retained supervisor identity;
- exact calendar-local future dates are visible but excluded from required-day
  and missing-entry totals, including deterministic extreme-timezone cases;
- stable blocking/warning codes cover all applicable T06 cases without
  inventing an overtime ceiling, mandatory overtime reason or document rule;
- only zero blocking issues and a current source fingerprint produce
  `ready_for_review`; source change makes the projection stale/effectively
  `draft` until explicit revalidation;
- exact active Admin and a complete capability-plus-dated-responsibility
  maintainer succeed. Role-only Project Engineer, Site Engineer, Procurement,
  expired/revoked/capability-only/wrong-team/wrong-project and uncovered
  allocation-target callers fail closed without partial totals;
- initialization/revalidation is atomic, expected-versioned, UUID-idempotent
  and audited once; same payload retry returns one run/effect, different
  payload/stale writers fail, and the real two-session harness yields one
  winner, one stable conflict and no duplicate run/audit/idempotency effect;
- a realistic 500-worker, 31-date/15,500-worker-date fixture validates within
  the recorded local performance budget and uses indexed/paged projections;
  and
- focused T01-T06 plus the complete DB suite remain green before and after the
  concurrency harness's retained fixture.

The repeatable local-only
`./tool/test_workforce_t06_monthly_period_concurrency.sh` harness uses two
independent authenticated Admin sessions against the same exact team/month
lock. It must prove one version-1 winner, one stable optimistic-version
conflict, one immutable run, one audit/idempotency effect and no orphan
run-scoped rows. The harness intentionally retains its local-only `598*`
fixture; rerun the focused T06 pgTAP without a reset before the complete
database lane to prove fixture-scoped isolation.

Flutter acceptance proves exact schema-v1 mapping, flag/offline/backend/
denied/stale/malformed failures, server-only totals, paged 500-worker summaries,
exception-first filtering, compact accessible calendar and daily drill-down,
including strict retained project/internal target and historical assignment
fixtures after mutable parent changes.
Golden/widget evidence covers 1440x900, 1366x768, 1024x768, read-only 360x800
and Arabic RTL with no page overflow and no color-only status. No Submit,
review, verify, approve, lock or reopen action may appear. Analyzer, formatting,
diff/lint, production-shaped web and ephemeral-signed Android builds run with
`YORKS_V1_WORKFORCE` off. Stop before T07.

## 9N. Workforce T07 review and approval lifecycle

Database acceptance proves:

- private lifecycle relations have RLS, no authenticated direct CRUD and no
  callable internal helper seam;
- exact Admin and fully capability-plus-dated-responsibility scoped actors can
  perform only their approved step, while role-only Project Engineer, Site
  Engineer, Procurement, capability-only, responsibility-only, expired,
  revoked and uncovered-target callers fail closed;
- submit uses the current non-stale T06 run, zero blockers and the exact full
  warning-ID set; an incomplete, additional or stale acknowledgement fails;
- submitter/returner/corrector/verifier/final-approver separation, mandatory return scope,
  controlled reviewer correction, verify/forward, atomic approve/lock,
  request/authorize reopen and a second approval revision are enforced;
- ordinary T03/T04 writes cannot bypass locked/review state or edit beyond a
  returned/reopened worker/date scope; snapshot bytes/hash, transitions,
  corrections and prior revisions are immutable;
- stale versions and same-key/different-payload fail, while an identical retry
  returns one result/effect; and
- the local two-session harness races Verify & Forward at one expected period
  version and yields one winner, one stable `40001` conflict, one version
  advance and one transition/audit/idempotency effect.

Run the local-only concurrency proof with:

```bash
./tool/test_workforce_t07_lifecycle_concurrency.sh
```

The harness refuses non-loopback databases and retains only its disposable
T06/T07 fixtures. Rerun focused T01-T07 pgTAP and the complete database suite
without resetting afterward so every test proves isolation from valid retained
records.

Flutter acceptance proves strict schema-v1 queue/lifecycle/action mapping,
complete paged warning acknowledgement, stable uncertain retry, offline/flag/
backend/denied/stale/malformed failures, capability-loss purge and explicit
server-confirmed actions. Widget evidence covers desktop actions at 1440x900,
1366x768 and 1024x768 plus read-only 360x800 and Arabic RTL, visible focus,
44x44 targets, status text/icons and no overflow. Production-shaped web and
ephemeral-signed Android builds keep `YORKS_V1_WORKFORCE` off. Stop before T08.

## 9O. Workforce T08 collaboration, evidence and notifications

Database acceptance proves all new mapping/metadata/delivery relations have
RLS, no authenticated direct CRUD and no callable internal SECURITY DEFINER
helper. Exact Admin and complete capability-plus-dated-responsibility actors
may read only their periods/entities; role-only Project Engineer, Site
Engineer, Procurement, guessed UUID, revoked/expired capability or
responsibility, stale static conversation membership and unauthorized document
path calls fail closed.

The focused suite must prove explicit idempotent conversation opening;
canonical replies, mentions, attachments, edit/delete and receipt compatibility;
no lifecycle change from user text; one immutable system event per T07 audit;
exact notification recipients with preference-aware push-outbox reuse; all
eight evidence types, immutable versions and current entity authorization;
canonical-target/secondary-link mismatch rejection before side effects;
secondary-only read/download denial; unknown/malformed payload rejection; a
greater-than-500-worker exact daily digest with one recipient/window effect;
digest idempotency; Push-disabled in-app retention; and retained history without
hard delete. Every T07 lifecycle event must prove its system event, exact
next-action recipients and no self/role-only/inactive/stale/out-of-scope leak.
Run the canonical Team Chat, Documents and Notifications regressions plus
focused T01-T08 and the complete database suite.

Flutter acceptance proves strict collaboration/discussion/document/
notification schemas and period context, controlled file boundaries, stable
uncertain retry, offline/flag/backend/denied/malformed failures and protected-
state purge. Widget evidence covers desktop discussion/evidence/notifications,
minimum 44x44 actions, visible focus, 1440x900/1366x768/1024x768, Arabic RTL
and a deliberate read-only 360x800 summary with no overflow. Analyzer,
format/diff/advisors and Workforce-off web/signed Android builds remain gates.
Stop before T09.

## 9P. Workforce T09 protected reports and exports

Database acceptance proves the report ledger has RLS, no authenticated CRUD,
immutable rows and no callable internal SECURITY DEFINER helper. Exact active
Admin, Project Engineer, Site Engineer and Procurement permutations must each
prove that role alone is insufficient: successful generation requires both
`workforce.view` and `workforce.reports.export` plus complete dated worker and
allocation-target responsibility. Revoked/expired capability or responsibility,
technical membership, guessed IDs, worker self-service, unauthorized project/
internal targets, malformed/unknown payloads and direct table access fail.
Tests also prove future daily denial, organization-only exception scope, and
that a forged Team/worker/Project or mismatched month cannot relabel an
immutable approved source or produce a misleading empty artifact.

Focused tests cover every report kind; immutable approved-snapshot selection;
old report stability after reopen/new approval; current-report source labels;
exact required controlled field sets and values; server totals/man-days; an
explicit High Overtime `not_configured` result when no limit exists; no
prohibited fields/internal ID columns; same-key
same-payload retry, same-key different-payload denial, stale/competing artifact
generation and exactly one `report_generated` effect. Explicit online
Preview/Download/Share/Print issuance must reauthorize the artifact and return
exact source/payload hashes, actor role/capability/scope/server time while
writing one `workforce_export_generated` effect. A local two-session harness
must prove both generation and issuance same-key races converge to one retained
artifact/receipt and one audit/idempotency effect each.

Flutter tests validate strict schema-v1 decoding, context echo, feature-off,
offline/backend/denied/malformed/uncertain failures and protected-state purge.
XLSX evidence parses OOXML and proves true date/numeric cells, text worker IDs,
formula-prefix neutralization, filters and frozen panes. PDF evidence renders
short and multi-page A4 reports, repeated bilingual legal approved-month
headers, `MONTHLY TIMESHEET`, Month/Year, exact Prepared/Reviewed/Approved,
server date/revision/page footers, content-based Project/Company orientation
and RTL without clipping. Preview, Download, Share and Print must consume
byte-identical cached PDF bytes after online issuance. Widget/golden evidence
covers 1440x900, 1366x768, 1024x768 and read-only 360x800 in English and RTL.
Run focused T01-T09, the complete retained-state DB suite, analyzer/format/diff,
advisors and Workforce-off web/signed Android builds. Stop before T10.

## 9Q. Workforce T10 dashboards

Database acceptance proves one schema-v1 projection returns only its requested
Supervisor, Management or Admin shape, includes generated/source/as-of
evidence, and writes no audit, notification, report, issuance or workflow row.
Tests cover exact today/month formulas, all accepted attendance states,
calendar-local extreme timezones, mixed-timezone grouping, more than 500
workers, multiple teams/projects without duplicates, retained leaver/closed
target history, prospective missing rows, supervisor and configuration issues,
review lifecycle queues and stable concurrent reads.

The correction regression includes more than 50 authorized retained periods,
an older high-priority exception, typed `overtime_limit_exceeded` and
`supporting_evidence_missing` issues, current-versus-retained configuration
issue overlap, editable team-default drift, and later worker/team/project/
scope/internal-location closure. Full counts and policies are asserted before
visible limits; each command flag is tested with and without its exact
capability and every retained target responsibility.

Positive/negative cases cover exact Admin, Project Engineer, Site Engineer and
Procurement identities with capability plus responsibility, capability-only,
responsibility-only, wrong team/project/internal target, revoked/expired or
inactive actors, technical membership, guessed IDs, direct helper execution and
malformed/unknown request fields. Action flags must be false unless their exact
accepted command capability and full dated scope are present.

Flutter acceptance covers strict schema-v1 mapping, response-kind/source/as-of
validation, flag-off/offline/backend/denied/malformed failures, visible stale
last-confirmed evidence and protected-state purge. Widget evidence covers
loading, empty, error, permission and stale states; 1440x900, 1366x768,
1024x768 and read-only 360x800; English and Arabic RTL; focus order, semantics
and non-color status cues. Run focused T01-T10, retained/full DB, focused
Workforce Flutter, analyzer/format/diff/advisors and Workforce-off web/signed
Android builds. Stop before T11.

Run `./tool/test_workforce_t10_concurrent_reads.sh` only against the
repository-local Supabase database. It starts two independently authenticated
Admin RPC sessions, observes both active together, compares the authoritative
response after excluding only `generated_at`, and proves that audit,
notification, transition and report counts remain unchanged.

## 9R. Workforce T11 tablet attendance and review

Widget and route tests prove that 1180x820 and 1024x768 landscape tablets use
a bounded master roster plus one selected worker/day editor, while 820x1180
and 768x1024 portrait tablets use a focused single-column roster, a selected-
row modal editor and a sticky completion footer. The tablet path must not
render or horizontally squeeze the desktop spreadsheet and must not create
text controllers for every loaded worker. The accepted desktop layout remains
unchanged at 1200 logical pixels and above; 360x800 and 390-pixel phone widths
remain deliberate read-only boundaries for T12.

Interaction tests cover selection, direct attendance/minute/allocation edits,
standard-minute prefill, bulk draft transforms, Copy Previous Day, Review Day,
Back to Edit and explicit online Save. Offline drafts, loading, empty, denied,
stale, conflict, uncertain and saved states remain visible and fail closed.
Review tests prove exception-first period/detail navigation and that Return,
Correct, Verify, Approve and Reopen appear and invoke controllers only when
their exact accepted T07 server flag is true.

Accessibility evidence covers 44x44 targets, semantic labels, predictable
focus order, keyboard traversal, non-color status cues and reduced motion.
Visual/golden evidence covers English plus Arabic/Urdu RTL without clipping or
page-level overflow. Run focused T01–T11 Flutter/route tests, retained T01–T10
pgTAP/full DB regression, analyzer/format/diff/advisors and Workforce-off web/
signed Android builds. Stop before T12.

## 9S. Workforce T12 mobile attendance

Widget and route tests prove that 360x800 and 390x844 render Today’s Team
worker cards, native date selection, one focused worker editor, a bulk-draft
bottom sheet and a sticky completion footer without the desktop grid or page-
level overflow. English plus Arabic/Urdu RTL, text scaling, keyboard/system
insets, 44x44 actions, semantic labels, visible focus, reduced motion and
non-color status cues are required.

Interaction tests cover status/minute/authorized-target/activity/exception
editing, standard-minute prefill, local bulk transforms and affected counts,
Review Day, Back to Edit and explicit online Save. Future dates are not offered
by the picker and remain authoritatively denied by the accepted calendar-
timezone server rule. Offline drafts never claim server success; loading,
empty, forbidden, stale, conflict, uncertain, invalid and saved states remain
explicit. Restricted allocation details/options stay redacted and command
availability follows server-returned row flags only.

Large-roster tests prove exactly one focused editor/controller is mounted and
pagination/load-more does not silently omit editable workers. Run focused
T01–T12 Flutter/route tests, retained T01–T10 pgTAP/full DB regression,
analyzer/format/diff/advisors and Workforce-off web/signed Android builds.
Preserve the accepted tablet/desktop layouts and stop before T13.

## 9T. Workforce T13 hardening acceptance

Database/security acceptance inventories all accepted Workforce relations,
RLS flags, policies, grants, privileged helpers and public RPCs. Every exposed
relation must retain RLS, no `anon`/`authenticated` CRUD and service-role-only
direct administration. Internal privileged helpers must be non-executable by
`public`, `anon` and `authenticated`; public RPCs must keep only their intended
authenticated execution and live identity/capability/responsibility checks.
Storage/document paths remain canonical-target authorized, and release web
assets must contain no service-role/secret credential.

Concurrency acceptance reruns every repository-local genuine two-session
Workforce harness and proves deterministic lock/version behavior, identical
retry convergence, different-payload/stale conflict, one authoritative effect
and one append-only audit/idempotency effect. Sequential pgTAP calls do not
substitute for these races. Focused T01–T13 and the complete database suite
must stay green against retained harness fixtures wherever their contracts
require no-reset coexistence.

Period-authorization acceptance calls both T07 and T10 boundaries directly.
Admin capability without responsibility, and future/expired/partial-month
organization responsibility, must fail; complete-month organization authority
must pass. Project Manager and Senior Mechanical Engineer must receive the
same result for the same exact retained assignment and allocation-target
responsibilities. Removing any required project-scope or internal-location
target must fail both boundaries. Empty periods must preserve complete
organization or exact team-month semantics without a role shortcut.

Performance acceptance includes the existing 500-worker, 31-date/15,500-date
validation fixture, 500-row roster/save bounds, greater-than-500 paging and
dashboard aggregation plus representative 50-team/30-project, multiple-
allocation and retained two-year-history query paths where practical. Record
local timings and `EXPLAIN` evidence, confirm supporting indexes and bounded
Flutter controller/widget creation, and do not invent a numerical SLA absent
from authority.

Accessibility/responsive acceptance covers every Workforce route/surface at
1440x900, 1366x768, 1180x820, 1024x768, 820x1180, 768x1024, 430x932, 390x844
and 360x800. Prove English, Arabic, Urdu and Hindi, RTL, text scaling, keyboard
and visible focus, semantic labels, reduced motion, 44x44 actions, non-color
status/error cues, no page overflow and the complete loading/empty/error/
denied/offline/conflict/uncertain state family.

The final local gate includes clean reset, focused and complete database
suites, all genuine concurrency harnesses, focused/full Workforce Flutter,
honest repository-wide Flutter snapshot, analyzer/format/diff/ShellCheck,
database advisors/lint, credential scans and production-shaped Workforce-off
web plus ephemeral-signed Android builds. T13 may correct only reproduced
defects and must preserve all T01–T12 facts. At T13 acceptance the dedicated
T14 staging UAT was historically waived/not performed, never passed. The later
31 August product-owner decision withdraws that waiver and reinstates the
separate T14 gate; it does not change T13 evidence or authorize production.

## 9U. Workforce T14 dedicated staging UAT acceptance

T14 passes only when one immutable Workforce-enabled candidate is deployed to
an unaliased non-production target backed by an explicitly configured dedicated
Supabase staging project. Every scenario uses the same candidate, backend and
named non-production personas. The historic shared Supabase project, local
fixtures and production are prohibited substitutes.

Required persona classes are capability- and responsibility-based:

| Persona | Required T14 authority/evidence |
|---|---|
| Admin configuration/reopen | Exact active Admin plus the effective capabilities and organization responsibility required by each command; all actions audited. |
| Site Engineer maintainer/supervisor | Exact active Site Engineer, `workforce.view`, attendance/timesheet maintain capabilities and exact dated worker/team/project/scope/internal-target responsibility. |
| Configured reviewer | A distinct named actor in the accepted approval chain with review and, only for the controlled correction scenario, correct-during-review/verify capabilities plus complete dated scope. |
| Configured final approver | A distinct named Senior Mechanical Engineer or Project Manager chosen by the staging approval chain, with final-approve capability and complete dated scope. |
| Negative personas | Named Procurement role-only, Site Engineer role-only or wrong-scope, expired/revoked capability/responsibility and inactive identity cases. |

The approved source's 35 scenarios are the mandatory functional matrix. In
addition, flag-off and unauthorized deep links, stale/conflict/uncertain/offline
states, capability/responsibility revocation, all-future-work-date denial,
target redaction, protected document/report bytes, four-language/RTL,
desktop/tablet/mobile/accessibility, credential/commercial leakage and the
listed unrelated Yorks flows must pass. Opening/read paths must have no write
effect.

Automation is required for migration, RLS/RPC, concurrency/idempotency,
artifact/hash and non-regression checks, but cannot supply the manual witness
for roster interaction, lifecycle separation, responsive behavior, controlled
document bytes or PDF Preview/Download/Print consistency. Record witness name,
UTC timestamp, URL/deployment ID, candidate fingerprint, backend ref without
secrets, migration ledger, screenshot/log reference and result for every
scenario. Zero open P0/P1 product defects is required.

Current result: **not run/not passed; explicitly deferred until after
production**. Dedicated staging project `iqltcyimlqtcwyzlemwx` was created and
all tracked migrations plus `finalize-document-upload` were applied. A direct
hosted database sweep executed 75 files/2,300 assertions: every functional
assertion passed except the test's explicitly local-only 60-second T06 timing
budget, which measured 88,447.47 ms on hosted staging; the T10 file lost its
long sweep connection after 30 passing assertions and then passed 56/56 in an
isolated rerun. These are technical staging observations, not T14 UAT. Named
personas, an unaliased candidate and the human 35-scenario witness remain
outstanding. The product owner explicitly authorized production as an
exception and required T14 setup/UAT next; release evidence must preserve this
boundary.

The production exception release subsequently passed its technical gates and
was promoted as deployment `dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g`. This live
smoke evidence remains excluded from the T14 result above; see
[`WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md`](WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md).

## 10. Release evidence package

Batch 10 produces:

- scenario result matrix for AT-01–AT-40 and AP-01–AP-18;
- Flutter/database/concurrency/integration command logs;
- desktop/mobile screenshots and controlled-document renders;
- workbook round-trip fixtures/results;
- migration/reconciliation counts and quarantine report;
- staging seed/persona instructions;
- release notes, known limitations and operations/cutover runbook;
- signed artifact provenance without exposing secrets.

That list is the completed R35 release evidence baseline. R39 T07 appends the
Accounts requirements/test traceability matrix, nine-role and 15-capability
parity/security results, clean-reset and forward-rollback proof, all required
Accounts responsive/accessibility states, performance measurements, staged
Site Engineer/Project Engineer/Accountant/Procurement/Admin E2E and explicit
production flag-enablement approval.
