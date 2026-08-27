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
| AT-32 | Team Chat provides authorized Direct, Project, MR, Group and Announcement conversations; group creation is limited to Admin and the four global Project Engineer roles, Direct chat has exactly two visible participants, sends and attachments are idempotent/verified, read state follows the user across devices, a message increments only Team Chat (never the workflow bell), pushes deep-link to the exact thread, and 1366px/tablet/390px/360px states match the R38.5 review hierarchy without overflow. | model/widget/golden/route/Edge payload/pgTAP/Storage/RLS |
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
