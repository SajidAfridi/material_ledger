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
