# Arrangement Workbench — implementation and acceptance plan

Date: 10 September 2026

Status: **planned; no application or database changes implemented by this document**

Requirements: [Arrangement Workbench SRS](ARRANGEMENT_WORKBENCH_SRS.md).

## 1. Delivery approach

Preserve the working production chain and integrate one tested vertical slice
at a time. First establish recovery/state correctness, then change presentation.
Do not replace the entire arrangement screen and discover missing behavior at
the end. A generated image is not a golden test or proof of interaction parity.

The user-facing result is:

1. Arrange opens the correct working version and restores permitted progress.
2. Save progress saves incomplete work privately without reserving anything.
3. Back to request safely saves/retains or deliberately discards changes.
4. Continue arrangement restores the exact accepted checkpoint and context.
5. Review surfaces all exceptions before the existing final save.
6. Confirmed save returns to the MR and preserves the complete logistics chain.

Every slice must update its evidence and stop on an unexplained regression,
authority conflict or data-preservation risk. This plan does not authorize a
commit, merge, migration to a remote backend, push, flag enablement or production
deployment. Later implementation/release requests establish those boundaries.

## 2. Exact implementation surface

Paths below are repository-relative. Existing files are reuse boundaries;
proposed files do not exist merely because they appear in this plan.

| Area | Existing files / protected endpoints | Planned change |
|---|---|---|
| Arrangement UI | `lib/features/materials/presentation/screens/yorks_v1_arrangement_screen.dart` | Extract reusable editor composition, source/stock/exception surfaces and focused mobile flow; preserve working and historical lanes. |
| Entry, return and private resume cue | `lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart`; `lib/app/router.dart` | One guarded exit path for modal/route/system Back; private Continue arrangement cue and origin restoration. |
| Arrangement domain | `lib/shared/models/yorks_v1_arrangement.dart`; `lib/shared/models/yorks_v1_arrangement_strings.dart` | Preserve operational DTOs; add localized save/restore/conflict/error copy and explicit commercial patch semantics only if required. |
| Editor/progress domain (new) | `lib/shared/models/yorks_v1_arrangement_progress.dart`; `lib/shared/controllers/yorks_v1_arrangement_editor_controller.dart`; `lib/shared/providers/yorks_v1_arrangement_editor_provider.dart` | Typed raw input, checkpoint versions, accepted versus recovery state, validation, navigation and uncertainty orchestration. |
| Local recovery (new) | `lib/shared/services/yorks_v1_arrangement_recovery_store.dart` | Versioned, actor/environment-scoped, serialized non-commercial recovery; bounded errors and purge integration. |
| Progress repository (new) | `lib/shared/repositories/yorks_v1_arrangement_progress_repository.dart` and matching provider | Owner-only typed checkpoint/read/discard/attempt methods; no direct widget RPC. |
| Current repository/providers | `lib/shared/repositories/yorks_v1_arrangement_repository.dart`; `lib/shared/providers/yorks_v1_arrangement_provider.dart`; `lib/shared/providers/yorks_v1_arrangement_repository_provider.dart` | Preserve final begin/save/clarify/decide and explicit refresh behavior; add authorized stale-state reconciliation without destroying input. |
| Critical commands | `lib/shared/controllers/yorks_v1_material_workflow_command_controller.dart`; `lib/shared/services/yorks_v1_critical_command_key_store.dart`; matching command provider | Reuse persistent keys/fingerprints; add narrow frozen-intent/outcome integration without regressing approval, dispatch, receipt or return callers. |
| Draft pattern reference | `lib/shared/controllers/yorks_v1_material_request_draft_controller.dart`; `lib/shared/repositories/collection_store.dart` | Reuse accepted/recovery distinction and serialized persistence. Do not widen Engineering MR-private-draft APIs to Procurement. |
| Server | `supabase/migrations/`; existing `v1_arrangement_projection`, `v1_begin_arrangement`, `v1_save_arrangement`, `v1_update_material_request_procurement_item`, legacy `v1_decide_arrangement` | Add isolated progress relations/RLS/RPCs and protected final-attempt receipt lookup. Extend existing functions only where necessary for atomic compatibility. |
| Design/localization | Existing core/shared tokens, controls and language providers; arrangement strings | Use the app's actual typography, spacing, direction and accessibility behavior. No copied mockup CSS or hard-coded English in widgets. |
| Analytics | `lib/shared/models/analytics_event.dart`; `lib/shared/services/analytics_service.dart`; `docs/analytics/POSTHOG_ANALYTICS.md` | Preserve current Phase 2 events; add only approved allowlisted outcome metadata if needed. |
| Regression tests | `test/yorks_v1_arrangement_test.dart`; `test/yorks_v1_arrangement_layout_test.dart`; `test/yorks_v1_material_workflow_trust_test.dart`; relevant existing database tests | Keep current tests; add cases below without replacing them with weaker screenshot-only assertions. |

### Existing server tests to retain

- `supabase/tests/database/yorks_v1_batch6_arrangement_inventory.test.sql`
- `supabase/tests/database/yorks_v1_material_request_procurement_item_clarification.test.sql`
- `supabase/tests/database/yorks_v1_material_request_phase3_policy_controls.test.sql`
- `supabase/tests/database/yorks_v1_material_workflow_production_hardening.test.sql`
- `supabase/tests/database/yorks_v1_material_workflow_trust_remediation.test.sql`
- `supabase/tests/database/scoped_capability_core_workflow_cutover.test.sql`

Add dedicated progress contract/RLS/concurrency tests, editor controller/store
tests, navigation integration tests and responsive evidence. Existing logistics,
receipt, return, document, commercial and session tests remain part of the gate.

## 3. Ordered implementation slices

### A0 — Freeze parity and fixtures

Requirements: all AW requirements, especially AW-08, AW-14–24, AW-27–30.

- Record branch/HEAD, dirty files, actual migration ledger, current configuration
  and source-of-truth revisions; protect unrelated work.
- Map each SRS parity row to current route/control/command/test and its new
  destination. Inspect the latest SQL definitions, not only original migrations.
- Record current server payload/field/decimal limits and exact commercial
  omission/clear behavior. Freeze them in new contract tests before DTO changes.
- Capture current desktop/tablet/360px behavior for mixed sources, reasons,
  clarification, all-unavailable, legacy and denied states.
- Build deterministic fixtures with 1, 20, 100 and 500 lines (up to current
  supported server limits), shared warehouse item references, long names,
  decimal quantities, mixed units and authorized/denied commercial variants.
- Record current timing/frame behavior and existing failures separately.

Exit: approved parity checklist, no unexplained authority conflict, runnable
baseline evidence. Do not claim current code already supports account progress.

### A1 — Private checkpoint and command-recovery backend

Requirements: AW-01–07, AW-20, AW-22, AW-25–26, AW-32–34.

- Add owner-private progress roots/revisions/line values and protected
  commercial companions using one additive migration. No legacy data copy,
  hydration migration, generic public JSON snapshot or new business state.
- Implement proposed get/save/discard RPCs with live role/capability/scope,
  membership/line ownership, current working-state, schema/bounds, expected
  progress revision, safe search path and request-hash idempotency checks.
- Implement the protected frozen-final-intent/outcome seam using the current
  critical-command key mechanism. Resolve receipts for repeated calls even
  after the request advances, subject to current read/redaction authority.
- Ensure current request/arrangement versions, reservations, audit handoffs,
  approvals and notifications are untouched by a progress checkpoint.
- While clarification locks operations, deny changed operational checkpoint
  payloads; preserve the prior checkpoint for restore after exact reapproval.
- Positive/negative RLS and real competing-session tests precede any UI use.
- Record schema counts, grants, indexes, expected query plans and rollback.

Exit: A1 database tests pass; same-key changed-payload denial, two-device
conflict, final/cancel/progress races and cost-redaction proof exist. No flag or
production enablement. Backend additive contract remains compatible with old app.

### A2 — Shared editor state, recovery and navigation

Requirements: AW-01–13, AW-21–26, AW-31, AW-33.

- Extract typed editor state/controllers without changing the visible layout
  first. One mounted editor model feeds desktop and mobile.
- Add generation-aware local recovery, accepted checkpoints, Save progress,
  account restore and comparison. Reject late hydration/write responses that
  would replace newer typing or mark it saved.
- Introduce exactly one exit coordinator, including embedded close callbacks,
  dialog barrier, router/Back and nested sheets. Retain original destination,
  MR context, focus and private resume cue.
- Connect frozen final intent and outcome lookup to existing command controller;
  retries must reuse original payload/key. Confirmed command plus refresh
  failure is a saved state, not an unsaved retry state.
- Checkpoint before clarification; preserve locked operations and rebase only
  after an explicit latest-revision comparison.
- Test screen disposal/remount, resize, query refresh, account switches,
  multi-tab, offline, delayed responses and local storage exceptions.

Exit: new state and save/resume behavior work under the existing UI, with all
old arrangement tests passing. No visual redesign hides behavioral regressions.

### A3 — Desktop workbench integration

Requirements: AW-14–21, AW-23, AW-27–28, AW-30.

- Integrate compact header, live save-state cue, explicit Back to request and
  Request Information, compact count/filter area, sticky item/header grid,
  inline exception reasons, note and single primary Review/Save area.
- Distinguish planned versus committed stock; show current effective availability
  and changed-stock errors without destructive refresh.
- Preserve source/readiness/cost/clarification/create-inventory behavior and
  all active and historical states, not only the happy-path mockup.
- Implement stable-ID row editing, keyboard traversal and focused error reveal
  through virtualization/filtering. Do not add unsupported request-line CRUD.
- Correct the image count and “Reserved” inconsistencies before goldens.

Exit: desktop 1440x900 and 1366x768, constrained 1024x768, keyboard, zoom and
large-list evidence pass; old and new end-to-end scenarios remain equivalent.

### A4 — Focused tablet/mobile and inclusive states

Requirements: AW-08–13, AW-14–23, AW-27, AW-29–30.

- Reuse the same controller in item list, one-row editor and Review flow.
- Keep source evidence, commercial controls, reasons, external readiness and
  Clarify item reachable without desktop horizontal editing.
- Use honest Continue/Next item wording, visible save status and Save progress
  from every step. Handle keyboard/safe-area and previous-item navigation.
- Complete loading/empty/error/denied/offline/stale/conflict/uncertain/saved
  states; preserve focus and input across rotation or responsive layout changes.
- Localize copy/semantics and prove direction, long content and text scaling.

Exit: 360x800, 390x844, 768x1024 and 1024x768 evidence; Android Back/keyboard
and browser Back work without input loss or duplicate commands.

### A5 — End-to-end hardening and staged acceptance

Requirements: all AW-01–34 and the complete matrix below.

- Run full applicable Flutter/database/build gates and independent-session races.
- Exercise both the current production lane and legacy historical lane through
  real protected commands, including clarification, stock and policy conflicts.
- Perform named Procurement/Engineering walkthroughs on an isolated staging
  candidate, including explicit Save progress & return and next-device resume.
- Compare performance and task completion against A0, investigate regressions.
- Produce source/backend/artifact-bound evidence, migration preservation and
  reversible application cutover instructions. Only then seek release approval.

Exit: no unresolved P0 data-loss, authority, quantity, duplicate-effect or
accessibility failure; named-persona acceptance is observed, not inferred.

### A6 — Separately authorized release and observation

- Use the accepted complete R35 chain; never repurpose its core feature flags
  as a partial rollout switch. If isolation needs a new presentation flag,
  propose `YORKS_V1_ARRANGEMENT_WORKBENCH`, default off until acceptance and
  tested with both editors. It grants no authority and must not use PostHog
  identity/analytics availability as a workflow switch.
- Deploy compatible additive schema before the accepted client. Verify old
  clients still respect server version/clarification/stock rules.
- Promote only the tested artifact after explicit production authorization,
  then verify routes, backend binding, static/PWA assets and byte/hash identity.
- Observe error, conflict, save/resume and uncertain-result rates with existing
  privacy-safe monitoring. A failed analytics call cannot block Procurement.
- Record release owner, migration ledger, rollback artifact and unresolved
  nonblocking limitations. Do not call monitoring or manual UAT passed in advance.

## 4. Edge-case acceptance matrix

All cases are mandatory for initial cutover. Unit/widget evidence alone does
not prove database concurrency, device lifecycle or browser navigation.

Legend: U = unit/controller/store; W = widget; D = database/RLS;
C = independent concurrent database sessions; E = end-to-end/device/browser;
V = rendered visual/accessibility/manual review.

| ID | Scenario and required outcome | SRS | Evidence |
|---|---|---|---|
| AC-01 | First Arrange begins once; double tap/repeated tab cannot create a second working version. Direct read/restore creates none. | 08, 25 | D,C,E |
| AC-02 | Existing work opens without another begin; correct request and exact scope are retained. | 06,08–09 | U,W,E |
| AC-03 | Blank source, invalid decimal fragment, partial reason and note save as private progress; no reservation/state/notification change. | 01–04,32 | U,D,E |
| AC-04 | Save progress & return restores the same MR/scroll; Continue restores every permitted field and review position. | 04,09–13 | W,E |
| AC-05 | Same actor resumes a confirmed checkpoint on another device; another actor cannot list/read/write it. | 01,06–07,32 | D,E |
| AC-06 | Delayed local write/account response cannot overwrite newer input or falsely mark it saved. | 03–06 | U,W |
| AC-07 | Close X, barrier, Escape, header Back, system/gesture Back, sidebar and browser route navigation all use one guard. | 09–10 | W,E |
| AC-08 | Clean departure has no unnecessary prompt; dirty Keep editing changes nothing; Discard returns to last accepted checkpoint. | 04,10–11 | U,W,E |
| AC-09 | Discard saved progress retires only the owner's checkpoint, not MR, clarification, inventory item or reservation. | 11,33 | D,E |
| AC-10 | Offline local recovery permits deliberate exit; unsaved costs are explicitly warned, not silently lost under an account-save claim. | 03,05,07,10 | U,W,E |
| AC-11 | Local storage full/disabled/corrupt yields actionable failure; account save can still succeed; unreadable recovery is not silently discarded. | 03,06 | U,W,E |
| AC-12 | Reload/app pause/kill restores only acknowledged recovery; no duplicate final mutation and no guarantee about unacknowledged keystrokes. | 03,07,25 | E |
| AC-13 | Request Information open/close, nested cancellation, filter/search and rotation retain raw input, caret and line selection. | 12,28–30 | W,E,V |
| AC-14 | Two devices for the same actor save different edits: expected progress revision conflicts; neither silently wins. | 06,26,33 | D,C,E |
| AC-15 | Two Procurement actors use private checkpoints; one final commit makes the other's base stale without deleting or force-applying it. | 01,26,33 | D,C,E |
| AC-16 | Full exact, Partial strict positive below requested + reason, unavailable zero + reason; incomplete checkpoint is still allowed. | 02,15,21 | U,D,W |
| AC-17 | Decimal precision/overflow/negative/nonfinite/scientific/malformed/localized input are handled consistently; mixed-unit totals not invented. | 15 | U,D,W |
| AC-18 | Decision/source toggling preserves recoverable text but final payload contains no incompatible hidden-source fields or reused readiness. | 16,20 | U,W,D |
| AC-19 | Defaults are suggestions; unreviewed/invalid/Full counts are distinct; confirm unchanged lines is explicit and bounded. | 14,23 | U,W |
| AC-20 | Warehouse selection shows identity/unit/availability without promising reservation; no match and real zero-stock item creation work. | 17,24 | W,D,E |
| AC-21 | Inventory loading/denied/failed/stale does not become zero available or erase the selected source. Late search response is ignored. | 17–18 | U,W |
| AC-22 | Same inventory item used by several request rows is validated in aggregate, including hidden rows. | 18,21 | U,D,C |
| AC-23 | Eligible retained reservation is counted once; consumed/released/other-request quantities are excluded. | 18 | D,C,W |
| AC-24 | Another request consumes/reserves stock before final save: atomic shortage response, old reservations intact, entries retained. | 18,24 | D,C,E |
| AC-25 | Unit mismatch/inactive item or stale inventory reference requires explicit correction, never automatic conversion/substitution. | 17–18,26 | U,D,W |
| AC-26 | External supplier name stays optional; published readiness enforcement on/off works; mid-edit policy change is revalidated. | 19 | D,W,E |
| AC-27 | Optional expected date/reference survives checkpoint/restore; date-only value does not shift with timezone. | 02,19 | U,W,E |
| AC-28 | Cost absent/unchanged/clear/zero/value semantics are distinct; unauthorized input cannot clear existing protected cost. | 05,20,32 | U,D,W |
| AC-29 | Cost permission revoked while open or after save timeout purges local state and redacts reads/retries/exports/analytics. | 07,20,25,34 | D,E |
| AC-30 | Clarification starts after progress checkpoint, preserves original identity and allowed fields, then locks operations. | 12,22 | D,W,E |
| AC-31 | Clarification pending/returned forbids changed operational progress payloads via direct RPC, while allowed further identity correction works. | 22,32 | D,E |
| AC-32 | Approve exact latest correction resumes same arrangement; later correction invalidates approval; affected source/review facts revalidate. | 22,26 | D,C,E |
| AC-33 | Clarification/final-save/approval race is serialized; no stale approval or post-save identity edit, including all-unavailable. | 22,24–26 | D,C |
| AC-34 | Invalid off-screen/filtered row appears in full-set summary; action reveals and focuses exact desktop/mobile input. | 21,23,28–29 | W,E,V |
| AC-35 | Normal final save reserves once, marks positive quantities dispatch-ready, and does not decrement on-hand or auto-dispatch. | 23–24 | D,E |
| AC-36 | All-unavailable save remains arranging with zero approved, no dispatch, saved reasons and allowed later arrangement revision. | 24,33 | D,W,E |
| AC-37 | Legacy awaiting-approval/returned record preserves its recorded lane/reservations; no new synthetic approval or conversion. | 24 | D,E |
| AC-38 | Timeout before commit and timeout after commit both resolve the same frozen intent/key; changed-payload resubmit is blocked. | 25 | U,D,C,E |
| AC-39 | Uncertain save survives navigation/reload/device switch; authorized lookup miss is not treated as definitive rollback. | 10,25,33 | D,C,E |
| AC-40 | Confirmed commit followed by response parsing/local key-clear/refresh failure reconciles success without duplicate effects. | 13,25 | U,D,E |
| AC-41 | Same-key/same-payload retries return one effect; same-key/different payload fails; parallel requests use independent command identities. | 25,33 | D,C |
| AC-42 | New request/arrangement revision never updates expected versions silently under stale edits; explicit compare/rebase invalidates affected review. | 06,26 | U,D,W |
| AC-43 | Remote cancel, dispatch, new version, project restriction or deleted/removed line while editing blocks obsolete submission and preserves authorized comparison. | 07,24,26 | D,C,E |
| AC-44 | Logout/session expiry/account/environment switch leaves no accessible cross-user cache; confirmed private checkpoint restores only after current authorization. | 07,32 | U,D,E |
| AC-45 | Procurement/Admin positive and Project Engineer/Site Engineer/global Engineering/Accountant/anon/wrong-scope/stale-role negatives prove no widened authority. Include explicit capability grants/denies. | 01,20,32 | D,E |
| AC-46 | Direct progress-table CRUD, forged owner/project/line, unknown keys, oversized payload, schema mismatch and replay after revocation fail safely. | 07,25,32 | D |
| AC-47 | After final save, dispatch subset -> immutable DO -> Good/Missing/Damaged review -> eligible replacement -> confirmed return/close retains caps and one movement. | 13,24 | D,E |
| AC-48 | All-unavailable cancellation/replacement remains authorized Engineering-only policy; replacement has one linked private Draft, not Procurement creation. | 24 | D,E |
| AC-49 | MR context, document preview/export/print, discussion/replies/attachments/history and Team Chat separation remain accessible on return. | 09,12–13,27 | W,E,V |
| AC-50 | Desktop sticky grid and keyboard work with 1/20/100/500 permitted lines, stable focus, filtering, zoom and no lost values. | 21,28 | U,W,E,V |
| AC-51 | 360/390px focused flow, tablet rotation, Android keyboard/safe area and Back retain every source/reason/cost/readiness action. | 29–30 | W,E,V |
| AC-52 | English and supported secondary languages/RTL, 200% text, reduced motion, screen reader and 44px targets pass. | 30 | W,E,V |
| AC-53 | Analytics disabled/failing/offline never blocks work; events contain only approved metadata and no duplicated final-save success on replay. | 34 | U,E |
| AC-54 | Old client/new backend and gated fallback keep progress readable/recoverable, reject stale final writes, and preserve all committed records. | 26,32–33 | D,E |

### Exact reference journey: leave and resume

Use a 4-line MR: warehouse Full; warehouse Partial with reason; external Full
with readiness/date/reference; unavailable with reason. Include an authorized
cost and overall note.

1. Enter only part of the second line; leave its reason incomplete.
2. Back to request -> Save progress & return. Assert account checkpoint success,
   no reservation/state/handoff change and correct MR destination.
3. Close the first browser/device; open the same MR as the same actor elsewhere.
4. Continue arrangement restores all fields exactly; line 2 is still incomplete,
   not magically valid. Different Procurement and Engineering accounts cannot
   inspect that private checkpoint.
5. Complete line 2; clarify another item's model. Assert exact-revision
   Engineering handoff and operational lock without losing arrangement input.
6. Engineering approves the correction; Procurement resumes the same working
   arrangement and rechecks the affected inventory match.
7. Reduce warehouse availability concurrently. Final save must either commit
   valid stock once or return a shortage without partial effects.
8. Correct source/quantity explicitly; Review -> Save arrangement. Simulate a
   dropped response and recover the exact confirmed result without a second save.
9. Return to MR: actual confirmed state/owner/next action, correct history and
   existing discussion; then run the controlled dispatch/receipt/return chain.

## 5. Security, migration and rollback checklist

- Read [migration safeguards](MIGRATION_AND_ROLLBACK_PLAN.md) before authoring
  SQL; record exact new relations/functions/grants and forward-safe rollback.
- No reinterpretation of old arrangement `saved_at`, identities, line decisions,
  approved quantities, reservations, commercials, history or document snapshots.
- No migration copies current defaults into a claim that a person reviewed
  them. Reviewed metadata belongs only to the new private editor checkpoint.
- No direct progress relation access. Verify owner and independent commercial
  capability on every read/write/replay; test all nine exact roles and forged IDs.
- Transaction locks follow existing order; idempotency/effects remain atomic;
  concurrency proof uses independent database sessions rather than sequential retry.
- Additive migration is tested against clean reset and a retained-state fixture,
  with column/function signature compatibility for the previous client.
- Application rollback returns to the prior verified artifact/old editor only
  after resolving pending final intents. Keep the progress recovery adapter or
  a read-only recovery entry accessible; do not strand acknowledged checkpoints
  behind a disabled UI. If that bridge cannot be retained, block cutover until a
  tested alternative exists.
- Retain progress revisions, attempt receipts, operational records and audit;
  use a forward migration to revoke a faulty new command if needed. Do not drop
  tables, delete checkpoints or unwind committed reservations as UI rollback.
- Stop for any commercial shape uncertainty, unmapped retained state, destructive
  migration need, unexplained test failure or missing release authority.

## 6. Verification gates and evidence record

### Planning baseline actually checked on 10 September 2026

Source: `be2e953`. Initial worktree contained only the pre-existing untracked
design-reference folder. This task adds Markdown planning documents and a README
index; it does not edit Dart, SQL, configuration or generated application assets.

Executed:

```bash
flutter test test/yorks_v1_arrangement_test.dart \
  test/yorks_v1_arrangement_layout_test.dart \
  test/yorks_v1_material_workflow_trust_test.dart
```

Result: **27 tests passed**. This establishes a narrow current baseline only.
It does not prove the proposed progress recovery, new UI, database concurrency
or full release. Full analyzer/test/build/database gates were not rerun for
this documentation-only task. No existing historic suite count is relabeled
as a fresh pass.

Documentation acceptance: run `git diff --check`, verify every local Markdown
link added here resolves, check requirement/acceptance numbering and confirm
that changes remain limited to the plan/SRS/index/design-reference notes.

Planning checks completed: `git diff --check` passed; all 68 local Markdown
links across the SRS, implementation plan, reference notes and docs index
resolved; requirement IDs AW-01–34 and acceptance cases AC-01–54 were verified
unique and sequential. Existing design PNGs were preserved without modification.

### Required implementation gate

Run narrow tests for every slice, then the complete applicable gate from
[AGENTS.md](../../AGENTS.md) and the
[test contract](TEST_AND_ACCEPTANCE_PLAN.md):

```bash
flutter pub get
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid SUPABASE_ANON_KEY=ci-publishable-key \
  ./tool/r35.sh build-web
CI=true YORKS_CI_EPHEMERAL_SIGNING=true \
R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid SUPABASE_ANON_KEY=ci-publishable-key \
  ./tool/r35.sh build-apk
```

For database work, confirm the target is the local project, start the local
stack if necessary, then run `supabase db reset` and `supabase test db`. Never
substitute a linked production database. A missing harness dependency is blocked
evidence, not a passing test. CI ephemeral APK signing is not production signing;
release validation requires the configured protected signing lane.

Use `./tool/r35.sh run` with an explicitly reviewed local/staging configuration
for interactive verification; do not silently choose a production backend.

### Staging evidence must record

| Evidence | Required contents |
|---|---|
| Candidate | Source SHA, clean/isolated build provenance, app/config versions and enabled presentation flag. |
| Backend | Exact non-production target and migration ledger; no credentials in documents/logs. |
| Automated | Command, exit code, test count, failures, timestamp and output location for every gate. |
| Concurrency | Distinct sessions, race inputs, observed committed effects and loser response. |
| UI | Desktop/tablet/360px/390px screenshots, actual interactive paths, RTL, keyboard/focus and accessibility observations. |
| Personas | Named non-production Procurement, authorized Engineering, Admin and denied/revoked/wrong-scope accounts; no role-name-only assertion. |
| End-to-end | AC-01–54 results plus reference leave/resume journey, receipt/DO/return snapshots and save/stock evidence. |
| Release | Explicit authorization, backup/restore evidence, protected signing where applicable, artifact hash, route/PWA/backend binding and rollback verification. |

### Definition of done

Every SRS requirement has passing evidence or a clearly recorded approved
nonblocking limitation. No P0 silent data loss, duplicate critical effect,
commercial disclosure, authorization bypass, stale overwrite or broken existing
workflow may be waived as a visual refinement. All current entry points have
new destinations; all new states have recovery actions. The user can save an
incomplete arrangement, return to the MR, resume and complete the real chain.

This plan is ready to begin A0/A1 after implementation is requested. All later
phase gates remain **not performed** until their evidence is produced.
