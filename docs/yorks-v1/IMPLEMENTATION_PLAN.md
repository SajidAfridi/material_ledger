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
- exactly 29 idempotent defaults for every new Common/building scope; dormant
  project-level BOQs remain unassigned for explicit reconciliation rather than
  being backfilled by inference;
- custom groups, direct header/cell editing, archive/delete rules;
- Blank/Similar insertion below active row;
- desktop virtualized keyboard grid and focused mobile row editor;
- scope-selectable project BOQ folder/detail pages, a read-only All overview
  and read-only Procurement projection;
- 500-row performance tests.

Gate: 29 defaults per real scope, All is read-only, cross-scope BOQ-to-MR
sources fail, arbitrary values survive save/reload, keyboard and 360px behavior
pass, Procurement direct write denied, V7 plans untouched.

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
