# Yorks V1 R35 — Dependency-Ordered Implementation Plan

Status: Batches 0–9 are complete. Batch 10 is in its controlled release
readiness phase; local evidence is complete, while staging, signing and
deployment require release-owner authority.

## Delivery strategy

- Preserve the working application and introduce each V1 slice behind a
  guarded rollout while it is under development. This plan is historical:
  accepted R35 slices are enabled by default under the current canonical build
  configuration in `README.md` and `TERRA.md`.
- Build normalized server authority before exposing dependent UI.
- Keep unrelated modules stable and test them continuously.
- Use web and Android evidence in every UI batch, not only at release.
- Treat the SRS three-day grouping as a demo acceleration target, never a
  security/migration waiver.

Dependency chain:

```text
B0 Re-baseline
  -> B1 Platform/local Supabase/release safety
  -> B2 Identity/projects/membership/command foundation
  -> B3 BOQ
  -> B4 Excel
  -> B5 Material Requests
  -> B6 Inventory kernel + arrangement/reservation/approval
  -> B7 Inventory UI + dispatch/receipt
  -> B8 Delivery Orders + returns
  -> B9 Documents/audit/retained modules
  -> B10 staging/release
```

## Batch 0 — Re-baseline and repository audit

Completion: **passed**. See
[`BATCH_00_COMPLETION.md`](BATCH_00_COMPLETION.md).

Scope:

- approve Rev 2.0 authority and source fingerprints;
- replace repository `AGENTS.md`;
- freeze product/transaction decisions;
- document exact current reuse/gaps;
- define architecture, state/RPC/RLS, UI, migration/rollback and test contracts;
- mark Nexus V7 product documents historical for overlapping V1 scope;
- run documentation and existing baseline gates.

No Flutter feature code, migration or production data change is permitted.

Gate:

- all Yorks V1 documents agree on roles, states, flow, scope and deferments;
- internal links and `git diff --check` pass;
- current Flutter analyze/test/web/Android baseline passes or an unrelated
  failure is reported;
- worktree contains only the approved Batch 0 documentation slice.

## Batch 1 — Platform baseline and release blockers

Implementation status: **passed.** See
[`BATCH_01_COMPLETION.md`](BATCH_01_COMPLETION.md).

Deliver:

- tracked local Supabase config, complete prerequisite migration baseline and
  deterministic non-secret four-role seed;
- independent `YorksV1FeatureFlags`, all off;
- CI for changed-Dart format, analyze, full tests, clean Supabase reset/pgTAP,
  web release and Android release assembly;
- Android main-manifest Internet permission;
- production signing that fails closed while CI uses a distinct ephemeral key;
- removal of PWA portrait-only lock;
- recorded decision for permanent Android app ID/namespace;
- no-behavior-change architecture proof.

Gate: fresh checkout resets/tests local Supabase and builds web/Android with all
V1 flags off. Release APK is not Android-debug signed and contains Internet
permission.

Rollback: flags stay off; configuration/docs can revert; additive prerequisite
schema remains inert.

## Batch 2 — Four roles, projects and historical membership

Implementation status: **passed.** See
[`BATCH_02_COMPLETION.md`](BATCH_02_COMPLETION.md).

Deliver:

- command/idempotency/audit helpers;
- protected profiles/capabilities with exact four-role claims;
- normalized projects, Common/physical scopes and dated project members;
- user provisioning/deactivation allowlist updates;
- project repository/controller and membership-aware route guards;
- five-stage project creation presentation connected to a server transaction;
- zero-loss project/user reconciliation report.

BOQ group creation support is completed in Batch 3 before Projects are enabled
to pilot users.

Gate: PE/Site/Admin creation positive; Procurement route/RPC/table negative;
Site activation without a PE denied; revoked access blocks future action and
preserves historical attribution.

Rollback: V1 Projects flag off; normalized/audit history retained.

## Batch 3 — BOQ groups and dynamic spreadsheet

Implementation status: **passed.** See
[`BATCH_03_COMPLETION.md`](BATCH_03_COMPLETION.md).

Deliver:

- ordered BOQ groups/columns/rows and canonical-plus-raw values;
- exactly one idempotent Workshop Materials default for every new
  Common/building scope; dormant
  project-level BOQs remain unassigned for explicit reconciliation rather than
  being backfilled by inference;
- custom groups, direct header/cell editing, archive/delete rules;
- Blank/Similar insertion below active row;
- desktop virtualized keyboard grid and focused mobile row editor;
- scope-selectable project BOQ folder/detail pages, a read-only All overview
  and read-only Procurement projection;
- 500-row performance tests.

Gate: one Workshop Materials default per real scope, All is read-only,
cross-scope BOQ-to-MR sources fail, arbitrary values survive save/reload and
changed-structure re-import after deletion, keyboard and 360px behavior pass,
Procurement direct write denied, V7 plans untouched.

Rollback: BOQ/Projects flags off; rows retained.

## Batch 4 — Real Excel round-trip

Completion: **passed**. See
[`BATCH_04_COMPLETION.md`](BATCH_04_COMPLETION.md).

Deliver:

- licensed workbook/file-picker dependencies;
- worksheet selection, title/header detection, mapping preview and validation;
- version-checked transactional import;
- faithful current title/header/row export;
- representative MSD and header-only fixtures on web and Android.

Gate: import/export/re-import retains arbitrary columns and rows; failure leaves
zero partial changes; import never submits an MR; Procurement import denied.

Rollback: feature flag off; committed imports remain revisioned data.

## Batch 5 — Material Request vertical slice

Deliver:

- normalized MR header/lines/counters/state constraints;
- creator-only recoverable drafts from group, selected BOQ, Excel and custom
  rows;
- Project/Building/Common and Urgent/Normal/Scheduled validation;
- explicit Submit RPC, server number and requester project-role snapshot;
- list/detail/current-action screens;
- protected commercial/non-commercial projections;
- controlled MR Excel/PDF/print and deletion/cancel policy.

Gate: Procurement cannot see drafts; submit is idempotent and creates no stock
reservation; references are unique; role-safe bytes/state contain no leaked
cost; web/Android MR flow passes.

Rollback: Requests flag off; submitted normalized records remain auditable.

## Batch 6 — Inventory kernel, arrangement, reservation and approval

This corrects the Execution Pack dependency: the headless inventory/reservation
kernel must exist before arrangement can reserve stock.

Deliver:

- minimal single-warehouse items, reservations and append-only movement
  foundation;
- versioned complete arrangement/lines;
- Full/Partial/Unavailable decisions, source and reason validation;
- locked atomic reservation replacement;
- Project Engineer approve/return decision and separation of duties;
- Procurement queue/read-only project context;
- concurrency/idempotency/RLS tests.

Gate: two requests cannot over-reserve; arranged never exceeds requested;
partial/unavailable reasons required; Site-only/Procurement approval denied;
return/cancel/replacement handles reservations exactly once.

Rollback: arrangement flag off; release/compensate only through trusted command.

## Batch 7 — Inventory workspace, dispatch and receipt review

Deliver:

- Inventory browse/search/item management and movement ledger for
  Procurement/Admin;
- typed inventory repository replacing client quantity mutation;
- locked/idempotent dispatch with reservation consumption and movement;
- Received/Missing/Damaged receipt review with partial good quantity;
- replacement eligibility/current-action states;
- complete competing-MR tests.

Gate: requested/approved/received/in-transit/stock caps hold at commit; one
movement per effect; assigned Engineer review only; retries and competing
dispatches cannot over-supply or drive stock negative.

Rollback after a committed stock command is roll-forward maintenance plus
audited compensation, never restoration of the old writer.

### R38.3 smart warehouse refinement

Status: implemented as an additive Batch 7 refinement. The warehouse now uses
the approved category/alias master, item code/minimum/location metadata,
atomic reviewed workbook import, exact client download template and responsive
Overview/Items/Movements/Reservations workspace. Procurement/Admin authority
and the existing reservation/dispatch transaction model are unchanged. The
R38.3 convergence follow-up adds one optional category-family level, ranked
canonical/alias/fuzzy suggestions, explicit create-versus-adjust entry paths,
and separate trusted item-master/opening-balance and versioned stock-movement
commands. Fuzzy results remain advisory; a user selection is required before
an alias or item relationship is written.

## Batch 8 — Delivery Orders and Material Returns

Implementation status: **passed.** See
[`BATCH_08_COMPLETION.md`](BATCH_08_COMPLETION.md).

Deliver:

- immutable four-column DO revision snapshot from committed dispatch quantity;
- return drafts/autocomplete from net eligible received quantities;
- return submit, Procurement confirm/reject and mapped-stock movement;
- Return Excel/PDF/print and web/Android flows.

Gate: dispatch-stage DO is immutable and has no receipt side effect; over-return rejected;
confirmation posts stock once; short/multi-page output passes visual QA.

Rollback: snapshots remain; use reject/supersede/compensating events.

## Batch 9 — Documents, audit and retained modules

Implementation status: **passed.** See
[`BATCH_09_COMPLETION.md`](BATCH_09_COMPLETION.md).

Deliver:

- Storage-backed immutable document versions and classified many-to-many links;
- project/BOQ/MR/dispatch/return document experiences;
- server audit projections for every critical RPC;
- explicit removal/guarding of Accounts, RFQ/PO, Material Plan and stale hidden
  V1 routes;
- smoke/fix Configuration, Rentals, User Management and Audit;
- implement/verify Duct Sizer and ESP Calculator without making their results
  authoritative engineering approvals.

Gate: four-role Storage tests; client audit writes denied; every critical RPC
emits one event; retained modules work; deferred routes are unreachable.

Rollback: document UI off; objects/versions/audit retained.

The Accounts item above is historical Batch 9 protection of the legacy
prototype/Finance route. It remains correct for `/admin/finance` and stale
links, but the approved 25 August 2026 R39 package now authorizes a separate
normalized Accounts rollout behind `YORKS_V1_ACCOUNTS`.

## Batch 10 — Release validation and controlled cutover

Implementation status: **local evidence passed; staging/production cutover
pending.** See [`BATCH_10_RELEASE_READINESS.md`](BATCH_10_RELEASE_READINESS.md)
and [`RELEASE_NOTES_DRAFT.md`](RELEASE_NOTES_DRAFT.md).

Deliver:

- AT-01–AT-25 and Android production gates;
- complete RLS/concurrency/idempotency/integration suite;
- real workbook and controlled-document visual QA;
- staging with four representative roles and end-to-end data;
- migration reconciliation, backup/restore and cutover rehearsal;
- release notes, known limitations and operations/cutover runbook;
- web deployment and correctly signed Android APK/AAB provenance.

Gate: every Definition of Done item passes; no unexplained legacy data loss;
release owner accepts remaining limitations. Credentials/production deployment
require explicit authorization.

## R39 Accounts — bounded T00–T07 rollout

This later Accounts-only plan does not reopen completed R35 batches or alter
non-Accounts behavior. The binding contract is
[`R39_ACCOUNTS_FOUNDATION.md`](R39_ACCOUNTS_FOUNDATION.md).

| Phase | Scope | Gate |
|---|---|---|
| T00 | Audit current roles, capabilities, routes, Finance boundary, shell and tests | Read-only evidence; no mutation |
| T01 | Ninth exact Accountant role, 15 exact capability keys, default-off flag, additive/shadow schema/RLS, 90/10 policy and protected 10/50/30/5/5 stage template with a 100% invariant; physical-building allocation policy only | Existing eight-role parity unchanged; AT-SEC-003/006/007; no project physical-allocation relation, route or command cutover |
| T02 | Commercial baseline, project physical-building/stage allocation relations and Billing Progress server authority | Six T02 capabilities only; protected role-safe projections/commands, explicit VAT, 100%/Common rules, evidence/review, revision/lock/idempotency proof; flag/UI stay off |
| T03 | Claims, invoice, certification, PDC and client payments | State, calculation, idempotency and append-only payment proof |
| T04 | Supplier bills and three-way match | Match/payment gate, role separation and operational-fact non-regression |
| T05 | Normalized routes, portfolio and project UI | Flag/capability guards plus all required responsive/accessibility states |
| T06 | Documents, audit, notifications, exports and reports | Existing protected subsystems reused; no data leakage or duplicate evidence |
| T07 | Golden/security/performance, staging UAT and release evidence | Complete accepted gate before production flag enablement |

Every phase is additive and rollback-safe. A later phase does not start until
its upstream server authority is complete; disabling the Accounts flag or
returning a consumer to shadow never deletes committed evidence.

Local implementation status on 26 August 2026: T01-T06 are implemented behind
the default-off flag and their focused database/Flutter gates pass. T07 local
security, operational-observability and six-viewport gates are implemented.
The production flag remains off because the same-commit five-persona staging
UAT and release-owner approval are external release gates, not facts that a
local implementation can manufacture. See
[`R39_ACCOUNTS_T07_RELEASE_EVIDENCE.md`](R39_ACCOUNTS_T07_RELEASE_EVIDENCE.md).

### T02 execution checklist

1. Add the six protected baseline/progress/current/revision relations listed in
   [`R39_ACCOUNTS_FOUNDATION.md`](R39_ACCOUNTS_FOUNDATION.md); no legacy
   Finance backfill, demo amounts or client-authoritative calculations.
2. Add exact baseline initialize/revise and progress suggest/confirm/review
   RPCs plus baseline/current/revision projections from
   [`STATE_RPC_RLS_MATRIX.md`](STATE_RPC_RLS_MATRIX.md). Every command uses
   live exact identity, project/building scope, expected version,
   deterministic locks, request-hash idempotency and same-transaction audit.
3. Enforce positive fixed-numeric contract, explicit validated VAT snapshot,
   90/10 terms, 100.0000 physical/stage totals within 0.00005, Common
   exclusion, 0–100 progress, unique current dimensions and append-only
   revisions. Review policy defaults disabled/null; no unapproved amount
   threshold, quorum or expiry is invented.
4. Keep value visibility separate from confirm authority. A non-value response
   omits monetary keys, not merely their values. Suggestions accept a nonblank
   summary or authorized reference; increased confirmation requires an
   authorized reference and no T02 exception shortcut.
5. Promote only `view_project_accounts`,
   `view_project_commercial_values`, `suggest_billing_progress`,
   `confirm_billing_progress`, `configure_project_commercials` and
   `review_commercial_progress` after the T02 database gate. Keep
   `YORKS_V1_ACCOUNTS` off and all routes/actions absent.
6. Run the exact FR-026–FR-060 and requested AT-E2E/BL/PROG/SEC/CONC split in
   [`TEST_AND_ACCEPTANCE_PLAN.md`](TEST_AND_ACCEPTANCE_PLAN.md), including clean
   reset, direct-table denial, serialized response-shape and concurrent-session
   proof.

T02 deliberately does not implement claim/invoice semantics or complete the
claim-dependent parts of FR-035/037/051/052, AT-BL-006/007,
AT-PROG-004/006/007 and AT-CONC-005; T03 owns them. T05 owns normalized routes,
responsive UI, cache purge and action rendering. T06 owns Accounts document
upload/link UI, baseline/progress print, export and report layout. T02 therefore
cannot enable the feature flag or claim production readiness.

### T03 execution checklist

1. Add protected normalized claim, claim-line, client-invoice,
   certification, client-payment, PDC and PDC-event relations. Enable RLS
   before grants, deny all authenticated direct writes and retain append-only
   financial evidence.
2. Replace the T02 claim-consumption and stale-draft seams with real
   claim-backed logic. Every non-cancelled claim consumes eligible value once;
   draft deletion or explicit cancellation is the only release path.
3. Add trusted, project-scoped RPCs for claim draft/save/submit/cancel, invoice
   draft/submit/return/cancel, cumulative certification, payment/reversal and
   PDC lifecycle commands. Each command re-checks exact capability and scope,
   locks its project/root rows, validates expected version, uses payload-hash
   idempotency and appends audit in the same transaction.
4. Snapshot baseline revision, progress revision, VAT, payment terms and claim
   values. Derive invoice totals, due date, certification/payment status,
   still-due amount and PDC exposure only on the server using fixed-precision
   numeric arithmetic.
5. Promote only `prepare_client_claim`, `manage_client_invoices`,
   `record_client_certification`, `record_client_payment` and `manage_pdc`
   after their positive, negative, direct-table, stale-version, idempotency and
   concurrency tests pass. Require protected commercial-value visibility in
   addition to claim preparation authority.
6. Add typed Flutter domain/input/repository/controller boundaries for the T03
   RPCs without adding a route, screen or action. Keep
   `YORKS_V1_ACCOUNTS` off; T05 owns responsive UI and T06 owns shared
   notification, document, export and report consumers.

The binding T03 lifecycle and correction defaults are recorded in
[`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md). T03 is not a general ledger,
does not add supplier-bill behavior, and cannot rewrite legacy Finance or any
technical/operational workflow.

### T04 execution checklist

1. Add protected supplier-bill and append-only supplier-payment relations with
   project correlation, fixed-precision values, exact states, case-insensitive
   invoice/payment reference uniqueness, RLS and no authenticated direct
   mutation grants.
2. Derive all three match groups on the server. PO/LPO requires both external
   reference and controlled document; accepted delivery comes only from a
   confirmed receipt with positive good quantity; supplier invoice requires a
   current commercial project-linked document.
3. Add versioned and idempotent draft/create/update, approve, pay, reverse and
   cancel commands plus protected get/list projections. Lock project/root
   records, re-check exact actor/capability/scope and append audit atomically.
4. Enforce separation of duties: Procurement maintains evidence but cannot
   approve; Accountant/Admin approves and pays; only exact Admin may use an
   unmatched exception, with a fresh reason per exceptional command. The
   supplier-invoice document remains mandatory.
5. Derive `matched`, `review` and `blocked`, then `pending`, `approved`,
   `partially_paid`, `paid`, `blocked` and `cancelled`. Prevent overpayment,
   cancellation with nonzero net payment and a second reversal.
6. Promote only `manage_supplier_bills`,
   `approve_supplier_bill_payment` and `view_supplier_costs` after the T04
   positive/negative/direct-table/idempotency tests pass. Add strict typed
   Flutter input/model/repository/controller boundaries, but no route or UI.

T04 remains behind the default-off `YORKS_V1_ACCOUNTS` flag. T05 owns the
responsive Accounts surfaces; T06 owns Accounts uploads, notifications,
exports and reports. T04 does not change logistics records, create a full PO
workflow or bridge normalized data into legacy Finance.

### T05-T07 execution checklist

1. Keep every normalized route behind `YORKS_V1_ACCOUNTS` and server-returned
   capabilities. Treat legacy `/admin/finance` as non-authoritative evidence,
   never as an Accounts fallback.
2. Render role-safe portfolio and project views for Overview, Billing Progress,
   Client Invoices, Receipts/PDC, Supplier Bills, Documents and Activity.
   Revoke/deactivate/identity changes purge protected projections.
3. Reuse the controlled Yorks document store and immutable audit stream. Link
   Accounts classifications to exact authorized entities; never create a
   parallel attachment or client-authored audit subsystem.
4. Generate XLSX and PDF/print from the same protected server report model.
   Preserve numeric cells, neutralize spreadsheet formula injection, repeat
   PDF headers and include project/access/generated-by/page context.
5. Run due reminders through a service-only, retryable, idempotent job record.
   Expose admin-only readiness and operational-health projections; keep
   metrics/job tables private and show privacy-safe support references for
   user-visible failures.
6. Prove the 1440x900, 1366x768, 1024x768, 820x1180, 390x844 and 360x800
   viewports across the critical Accounts views. Update only intentional
   Accounts goldens; unrelated historical golden drift is not silently
   rebaselined.
7. Keep the feature flag off until Site Engineer, Project Engineer, Accountant,
   Procurement and Admin complete staging UAT on the same release commit, no
   P0/P1 issue remains and the release owner records approval.

## Workforce phased execution

### T01 — worker master and effective assignment foundation

1. Register the twelve planned/shadow/nonassignable `workforce.*` capability
   rows and the complete exact-role matrix without changing runtime authority.
2. Add private normalized trades, internal locations, teams, workers, effective
   assignments and responsibility scopes with RLS and history preservation.
3. Expose exact-Admin, versioned, idempotent foundation RPCs and a strict typed
   Flutter repository behind default-off `YORKS_V1_WORKFORCE`.
4. Add no route or Workforce UI. Later attendance/timesheet phases begin only
   after the T01 database and client gates pass.

### T02 — calendars and shift configuration

1. Add private effective calendar versions, seven ISO weekday rows and dated
   holiday, closure, Ramadan and other schedule overrides.
2. Add private effective reusable normal-site, warehouse, workshop, Ramadan,
   night and other shift versions. Freeze cross-midnight `work_date` to the
   start date in the linked calendar timezone.
3. Add non-overlapping dated team defaults referencing exact retained calendar
   and optional shift versions. Reject any parent edit that would strand a
   retained link or dated override.
4. Freeze semantic fields on referenced calendar/shift versions, effective
   team links and all past/current override fields including active state.
   Derive every boundary from the exact linked calendar timezone, not the
   database session. Permit new non-overlapping versions, future unused draft
   correction and retirement of calendar/shift parents with only expired
   references without deleting or changing retained meaning.
5. Expose only exact-Admin, optimistic-versioned, idempotent, audited schema-v1
   RPC/repository boundaries. Keep capabilities planned/shadow/nonassignable,
   `YORKS_V1_WORKFORCE` default-off and all routes/UI absent.
6. Create no daily attendance, allocation, overtime or timesheet fact. Stop
   before T03 attendance authority.

### T03 — daily attendance domain

1. Add one private, no-hard-delete daily row per worker/work date with closed
   attendance statuses and integer regular/overtime minutes capped at one day.
2. Resolve and retain the exact effective assignment, responsibility,
   calendar, optional shift and day type on first save. Keep those snapshots
   unchanged during later versioned corrections.
3. Promote only `workforce.view` and
   `workforce.attendance.maintain` to operational/enforced/assignable. Require
   both capability and dated responsibility for non-Admin scope; keep exact
   active Admin organization authority and all other Workforce keys shadow.
4. Expose strict schema-v1 scoped read and online/server-confirmed save
   boundaries with row locking, expected version, UUID idempotency and one
   append-only audit effect.
5. Prove Admin/scoped-maintainer positive paths and role, identity, scope,
   employment, malformed, stale, retry, direct-table and competing-writer
   negatives in pgTAP plus strict Flutter repository tests. Use
   `./tool/test_workforce_t03_concurrency.sh` for the actual two-session create
   and same-version correction races; a sequential call is not concurrency
   evidence.
6. Deny both creation and correction for a future work date using the exact
   retained calendar timezone and server clock. Preserve any pre-existing
   future row as read-only evidence; never authorize this boundary from the
   database session timezone or client clock.
7. Add no route, UI, allocation, monthly period, timesheet, bulk/copy action,
   notification, report/export, legacy migration, flag enablement or
   deployment. Stop before T04 allocations.

### T04 — daily timesheet allocations

1. Add a private versioned allocation-set root, immutable allocation revision
   headers and immutable allocation rows beneath exactly one T03 attendance
   day. Keep all direct authenticated CRUD denied and retain every revision.
2. Accept only explicit project-plus-own-Building/Common or internal-location
   targets. Snapshot target identity and Department/Cost Centre meaning; never
   infer a target from assignment/team context and store no pay/cost fields.
3. Reconcile active allocation regular/overtime minute sums separately and
   exactly to the parent present day. Validate optional paired, non-overlapping
   calendar-local intervals with shift-start-date cross-midnight semantics.
4. Guard T03 attendance correction while an active allocation set exists.
   Provide a distinct timesheet-authorized, versioned withdrawal revision so
   attendance authority is never inherited by a timesheet-only maintainer.
5. Promote only `workforce.timesheets.maintain`; require capability plus dated
   retained-worker responsibility and capability plus explicit dated
   responsibility for every target. Keep exact Admin audited organization
   authority and all remaining Workforce capabilities shadow.
6. Expose strict schema-v1 read/save/withdraw repository/controller boundaries
   with worker/date locking, expected versions, UUID idempotency and one audit
   effect. Prove the actual two-session allocation race with
   `./tool/test_workforce_t04_concurrency.sh`.
7. Add no route/UI, roster/bulk action, monthly period, lifecycle review,
   report/export, migration of legacy data, flag enablement or deployment.
   Stop before T05.

### T05 — Supervisor Daily Roster desktop workflow

1. Add one additive future-date/roster composition migration. Enforce the
   product-owner no-future-date rule from the exact retained calendar timezone
   across attendance creation/correction and T04 save/withdraw while preserving
   any pre-existing future evidence as readable and read-only.
2. Expose a strict schema-v1 roster projection that returns only authorized,
   effectively assigned workers, retained attendance/allocation state and
   server-derived schedule/day-type suggestions. Reading never creates a fact.
3. Compose explicit Save Day through one sorted worker/date-locking,
   optimistic-versioned, UUID-idempotent transaction. Preserve active hidden
   allocations for attendance-only evidence changes and require exact
   timesheet authority/version for replacement or withdrawal.
4. Keep Review Day, bulk edits and Copy Previous Day local until Save. Recompute
   selected-date assignment/schedule/target validity, clear unsafe prior facts
   and mark copied rows as needing review.
5. Add strict typed model/repository/controller boundaries plus a default-off,
   permission-guarded Workforce route/sidebar/search entry. Purge protected
   roster and draft state on flag, identity or capability loss.
6. Deliver the desktop-first sticky roster grid, deliberate local scrolling,
   keyboard/focus/semantics/localization states and overflow-free 1440x900,
   1366x768 and 1024x768 evidence. Keep 360x800 deliberately read-only and
   overflow-free; do not shrink the desktop spreadsheet into a mobile editor.
7. Prove exact role/capability/responsibility/target negatives, malformed/stale/
   idempotent paths, a true two-session roster race, focused Flutter state and
   viewport tests, full applicable database/analyzer/build gates and the
   default-off production shape. Add no monthly lifecycle, approval, document,
   notification, report/export, legacy migration, flag enablement, remote
   migration or deployment. Stop before T06.

### T06 — Monthly period and validation

1. Add private team/month period roots plus immutable validation runs,
   run-scoped worker summaries, worker/date evidence and typed validation
   issues. Reading creates nothing; explicit initialization/revalidation is
   versioned, idempotent, atomic and non-destructive.
2. Derive membership, schedule/day type, daily/worker/period totals and source
   fingerprints only from accepted T01-T05 facts. Attendance dates use exact
   retained T03 worker/assignment/team/supervisor/calendar context and retain
   their T04 allocations; only missing dates use the current effective T01
   assignment. Do not let later assignment edits, worker status changes,
   supervisor deactivation or target closure reinterpret accepted history.
   Exclude exact calendar-local future dates from completeness and never trust
   client totals.
   Use the same private team-month applicability predicate for selector, absent
   read and validation: accept current window overlap, retained T03 team/month
   evidence or an existing period, while preserving all existing authority
   checks and rejecting a genuinely non-effective empty team.
3. Produce stable blocking/warning issue codes. Blocking issues or changed
   source fingerprints yield effective `draft`; only a clean run yields
   `ready_for_review`. Missing supervisor IDs and structurally invalid retained
   windows remain blocking; current supervisor activity applies only to
   prospective dates because no dated supervisor-status history exists in T03.
   Add no warning acknowledgement or submission action.
4. Reuse only `workforce.view` and `workforce.timesheets.maintain`, requiring
   complete dated worker and allocation-target responsibility for non-Admin
   callers. Promote no T07 capability and expose no partial authoritative
   monthly totals.
5. Add strict schema-v1 model/repository/controller boundaries and a guarded
   desktop Monthly view with worker summaries, compact calendar, daily drill-
   down, exception filters and explicit loading/empty/denied/stale/offline
   states. Keep 360x800 read-only and color-independent.
6. Prove RLS/ACL, exact authority, history, stale/idempotent/concurrent writes,
   500-worker/15,500-date performance, malformed client boundaries, desktop/
   RTL viewports and default-off release builds. Add no T07 submission/review/
   approval/lock/reopen, document, notification, report/export, migration,
   remote change or deployment. Stop before T07.

### T07 — Review and approval lifecycle

1. Add one forward-only migration for immutable approval revisions,
   transitions, exact return/reopen edit scopes, reviewer corrections, reopen
   requests and approved snapshots. All lifecycle reads are non-mutating.
2. Promote only the five T07 keys required by the source: review,
   correct-during-review, verify, final-approve and reopen. Every non-Admin
   command requires exact active capability plus complete dated worker and
   allocation-target responsibility. Keep submitter/reviewer/final-approver
   separation mandatory even for Admin.
3. Submit only a current `ready_for_review` run with zero blockers and the
   exact complete warning-ID acknowledgement set. Return and reopen identify
   exact worker/date pairs; ordinary T03/T04 writers remain blocked outside
   those server-retained edit scopes.
4. Reuse T03/T04 writers for controlled reviewer correction inside a trusted
   transaction context, then append before/after evidence and require explicit
   revalidation/resubmission. Verify & Forward and Approve & Lock remain
   distinct authority steps; approval atomically creates an immutable hashed
   snapshot and locks the period.
5. Reopen is request then independent authorization. Preserve every earlier
   snapshot, advance the approval revision and expose only the approved
   correction scope. Revalidation, resubmission, review and approval are
   required again.
6. Add strict schema-v1 lifecycle/queue models, an isolated review repository
   boundary, protected Riverpod state and desktop actions in the existing
   Monthly screen. Compact/mobile remains read-only. Feature-off, permission
   loss, offline, stale, uncertain and malformed states fail closed and clear
   protected state where authority is lost.
7. Prove exact positive/negative role and scope authority, no self-action,
   warning acknowledgement, idempotency, stale writers, immutable history,
   two independent-session lifecycle writers, strict Flutter decoding and
   responsive English/RTL output. Add no comments/documents/notifications,
   reports/exports, dashboard, mobile editor, legacy migration, flag
   enablement, commit, push, remote migration or deployment. Stop before T08.

### T08 — Discussion, evidence and notifications

1. Reuse the accepted canonical Team Chat, Documents/version store,
   Notifications and push-outbox services. Add only Workforce mappings,
   metadata and role-safe schema-v1 RPCs; do not create parallel collaboration,
   blob or delivery engines.
2. Map one monthly period to one explicit, idempotently opened group
   conversation. Resolve effective members from exact active identity,
   capability and dated responsibility on every read/command. Retain canonical
   comments/replies/mentions/attachments/edit/delete/receipts; comment text is
   never lifecycle authority.
3. Append immutable system messages from accepted T07 audit events and deliver
   next-action notifications to capability-plus-responsibility scoped actors.
   Reuse preference-aware durable outbox delivery and deduplicate by the source
   audit/event/recipient identity.
4. Add the eight frozen Workforce evidence types through the canonical
   prepare/upload/finalize/version path with operational classification and
   Worker/Attendance Day/Monthly Period authority. Resolve the canonical target
   before idempotency, validate every optional link against the same retained
   worker/day/current period run, and authorize reads from the canonical target
   rather than a secondary link. Retain all versions and deny direct
   table/object-path access.
5. Add explicit Admin-only, idempotent daily-missing and monthly-incomplete
   digest dispatch. Page through the complete daily roster so teams above 500
   workers are counted exactly. Do not invent cron, cadence, escalation or
   external channel policy.
6. Add strict repository/controller models and integrate the desktop Monthly/
   Review view. Keep 360x800 read-only and overflow-free; fail closed and purge
   protected state on authority loss.
7. Prove role/scope negatives, static-member revocation, notification/push
   deduplication, immutable document versions, idempotency, strict Flutter
   mapping, responsive/RTL output and default-off build gates. Add no T09,
   route, flag enablement, legacy migration, commit, push, remote migration or
   deployment. Stop before T09.

### T09 — Protected Excel and PDF reports

1. Add one forward-only migration for immutable report artifact payloads,
   exact approval-snapshot selection, strict report-kind/scope validation,
   request-hash idempotency and append-only export audit.
2. Promote only `workforce.reports.export`. Require it together with
   `workforce.view` and complete dated responsibility for every returned
   worker and allocation target, including Admin. Add no worker self-service.
3. Build Daily, Worker, Team, Project, Company and seven exception report
   payloads on the server. Monthly final outputs read only immutable T07
   snapshots; current daily/exception outputs carry explicit non-approved
   source status/version/time. Use exact report-specific controlled fields;
   High Overtime returns typed `not_configured` evidence when no threshold is
   configured.
4. Reuse Yorks OOXML and PDF engines. Add typed/date/numeric XLSX cells,
   formula-injection hardening, frozen identity/header panes and filters.
   Generate one PDF byte buffer per immutable artifact and share it across
   Preview/Download/Share/Print, with the approved-month legal bilingual
   header and Prepared/Reviewed/Approved/date/revision/page footer.
5. Add strict schema-v1 domain/repository/controller boundaries and the
   guarded Monthly Reports desktop surface. Preserve a read-only 360x800
   boundary and English/Arabic/Urdu/Hindi localization.
6. Separate generation audit from explicit issuance: generation writes one
   `report_generated`; each online idempotent artifact/format/action issuance
   writes one `workforce_export_generated` before cached bytes are consumed.
   Prove authorization permutations, immutable source retention, sanitization,
   totals, idempotency, competing generation, exact audit effects, XLSX
   structure, PDF short/multi-page/RTL rendering, responsive states and
   Workforce-off release builds. Stop before T10.

### T10 — Admin and management Workforce dashboards

1. Add one forward-only read-projection migration with explicit Supervisor,
   Management and Admin response shapes, server-generated timestamps, source
   version and calendar-local as-of groups.
2. Reuse accepted capability/responsibility and retained T03-T07 authority.
   Aggregate complete authorized populations beyond 500 rows without client
   paging, N+1 RPCs or role-label shortcuts.
3. Calculate today/month completion, attendance states, warnings, review/
   approval queues, reopen/configuration issues and action flags on Postgres.
   Use retained historical facts and prospective dated assignment/calendar
   context without current-state reinterpretation.
4. Add strict domain/repository/controller mapping and a guarded Overview route
   within the existing default-off Workforce shell. Preserve the existing
   Attendance, Timesheets and Reports surfaces.
5. Prove formula, mixed-timezone, >500, deduplication, closure/leaver/history,
   permission and no-side-effect behavior in pgTAP, plus strict Flutter,
   responsive/RTL/accessibility and Workforce-off release gates. Stop before
   T11.

Status: independently accepted. The correction gate additionally proves no
exact-role shortcut, complete retained-target authorization for every action,
full counts before compact limits, actual assignment/allocation project
grouping, retained closed-target queues, stable configuration de-duplication
and typed overtime/evidence issue handling.

### T11 — Purpose-built tablet attendance and review

1. Add no migration, capability, route or lifecycle state. Reuse the accepted
   T05/T07 controllers, repositories, RPCs and server-returned action flags.
2. Preserve the deliberate phone boundary below 720 logical pixels for T12
   and desktop spreadsheet/review behavior at 1200 and above.
3. Build a 720–1199 tablet attendance editor: landscape master/detail,
   portrait focused roster plus selected-row sheet, sticky completion footer,
   one active row editor, explicit Review/Back/Save states and no optimistic
   server success.
4. Build an exception-first tablet review hierarchy. Expose Return, Correct,
   Verify, Approve and Reopen only from accepted T07 flags; keep all lifecycle
   and separation-of-duties authority on the server.
5. Prove 1180x820, 1024x768, 820x1180 and 768x1024 plus the unchanged 360x800
   boundary, English and Arabic/Urdu RTL, 44x44 targets, focus/semantics,
   reduced motion, no overflow and bounded editor/controller creation.
6. Run focused T01–T11 Flutter/route regression, retained T01–T10 database
   gates, analyzer/format/diff/lint and Workforce-off release builds. Stop
   before T12 and do not commit, push, migrate remotely, enable or deploy.

Status: independently accepted.

### T12 — Purpose-built mobile attendance

1. Add no migration, capability, route or lifecycle state. Reuse the accepted
   T05 projection/controller/repository/RPC, local drafts and explicit Review/
   Save boundary.
2. Replace the phone read-only placeholder below 720 logical pixels with a
   Today’s Team card roster, one focused worker editor, native date selection,
   authorized target picker and keyboard-safe minute/status/activity controls.
3. Add a phone bulk-draft bottom sheet with an affected count and a sticky
   completion footer exposing only Review Day, Back to Edit and Save Day.
   Opening or editing creates no server fact; offline drafts remain local and
   explicit online Save alone may report authoritative success.
4. Honor server-returned row editability, redaction, capability and target
   options without role inference. Preserve the accepted no-future-date rule,
   protected-state purge and visible loading/empty/denied/stale/conflict/
   uncertain/invalid/saved states.
5. Prove 360x800 and 390x844 in English and Arabic/Urdu RTL, keyboard/system
   insets, text scaling, 44x44 actions, semantics/focus/reduced motion,
   non-color cues and bounded editor/controller creation for large rosters.
6. Run focused T01–T12 Flutter/route regression, retained T01–T10 database
   gates, analyzer/format/diff/lint and Workforce-off release builds. Preserve
   T11 tablet and desktop behavior. Stop before T13 and do not commit, push,
   migrate remotely, enable or deploy.

Status: independently accepted.

### T13 — Security, concurrency, accessibility and performance hardening

1. Freeze the accepted T01–T12 object/command/surface inventory and audit every
   relation, RLS/ACL, Storage/document boundary, public RPC and internal
   privileged helper. Public execution and direct-table access must remain no
   broader than the accepted capability-plus-responsibility contract.
2. Rerun every real repository-local independent-session race for critical
   attendance, allocation, roster, monthly, lifecycle and report commands;
   verify stable idempotency, stale conflicts, deterministic locks, one
   authoritative effect and append-only audit. Sequential calls are not race
   evidence.
3. Reuse the accepted 500-worker/15,500-date gate and exercise the approved
   50-team/30-project, multiple-allocation and retained two-year-history paths
   where practical. Record query plans, wall times, pagination/virtualization,
   bounded controller creation and release-mode profiling without inventing an
   unapproved SLA.
4. Recheck every Workforce surface at 1440x900, 1366x768, 1180x820, 1024x768,
   820x1180, 768x1024, 430x932, 390x844 and 360x800 with four-language/RTL,
   text-scale, 44x44, focus/keyboard, semantics, reduced-motion, non-color and
   complete state-family proof.
5. Implement only a reproduced hardening defect or an evidence gap. Preserve
   all retained T01–T12 facts, capabilities, routes and defaults; use a new
   additive migration for any server correction and never rewrite an accepted
   migration.
6. Remove any reproduced T07/T10 role shortcut without merging their distinct
   boundaries: complete-month organization responsibility may short-circuit;
   partial/future/expired organization windows may not; exact retained
   assignment and allocation-target checks remain mandatory for scoped actors,
   and empty periods retain organization/exact-team semantics.
7. Run clean reset, focused/full retained-state database gates, every genuine
   concurrency harness, focused/full Workforce Flutter, analyzer/format/diff/
   lint, credential scan and Workforce-off web/signed Android release-shaped
   builds. Stop before release and do not commit, push, migrate remotely,
   enable or deploy.

Status: independently accepted on 31 August 2026. At acceptance time the
product owner had waived T14; the repository retains that historical fact as
not performed/not passed.

### T14 — Dedicated staging UAT

1. Record the later 31 August product-owner withdrawal of the T14 waiver. Do
   not rewrite the historical waiver into a pass.
2. Freeze one immutable candidate source/artifact and deploy it only to an
   unaliased non-production web target with `YORKS_V1_WORKFORCE=true`, backed
   by an explicitly configured dedicated non-production Supabase project.
3. Use named non-production Admin, scoped Site Engineer maintainer, configured
   reviewer, distinct final approver and unauthorized/revoked/wrong-scope
   personas. Role labels alone are never authority.
4. Execute the approved source's 35 staging scenarios on that same candidate,
   including exact capability/responsibility/target negatives, all-future-date
   denial, daily/monthly/lifecycle/collaboration/report/dashboard coverage and
   People/HR, Leave, Auth, Projects/BOQ/MR, Inventory, Returns, Accounts, Team
   Chat, Rentals, Configuration, User Management and Audit non-regression.
5. Capture candidate/backend/deployment identity, migration ledger, hashes,
   UTC timestamps, witnesses, screenshots/logs, P0/P1 findings, rollback and
   manual limitations. Automation does not replace required human witness.
6. Stop instead of substituting local fixtures, the historic shared project or
   production when staging configuration or named personas are absent.
7. Do not commit/push main, migrate production, enable the live flag, promote a
   Vercel alias or start the later production release.

Status: infrastructure initialized but UAT not performed/passed. Dedicated
Frankfurt project `iqltcyimlqtcwyzlemwx` carries the complete tracked ledger
and protected document Function. Named personas, the immutable unaliased
candidate and human witness remain outstanding. The product owner explicitly
deferred those T14 activities until after an immediate production-release
exception; production evidence must not be relabeled as T14. See
[`WORKFORCE_T14_STAGING_UAT_EVIDENCE.md`](WORKFORCE_T14_STAGING_UAT_EVIDENCE.md).

## Batch completion discipline

Each batch reports:

- exact scope/files/symbols;
- migrations, data preservation and rollback;
- positive/negative permissions and concurrency/idempotency proof;
- desktop/mobile visual evidence;
- commands and results;
- known limitations and next dependency;
- clean worktree/PR state.

Do not begin a downstream batch while its upstream server authority or gate is
incomplete.
