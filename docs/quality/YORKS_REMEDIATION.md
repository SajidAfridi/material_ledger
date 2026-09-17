# Yorks reliability, performance and usability remediation

Branch: `codex/yorks-reliability-remediation-20260917`.
Starting commit: `1b497e8`. Starting worktree: clean.
Scope: local implementation and tests; remote inspection read-only. No merge,
deployment, live migration, operational transaction or remote setting change.

## Evidence and interpretation

Read the three supplied 17 September evidence files and both implementation
requests. Snapshot cutoff is **2026-09-17 14:40 UTC**, not a release diagnosis.
Follow the current Yorks authority, including approval before arrangement and
separate Submit/Approve creation commands. Manual/non-stock entry is valid;
lookup misses and typing are not failed tasks. Material Master is deferred.

Live read-only checks on 17 September:

- Supabase lists production `czykuksmlwswjsgotrpo` and staging
  `iqltcyimlqtcwyzlemwx` as active. No staging data was changed.
- PostHog project 600792 is UTC. Targeted Auth lookup and event identity lookup
  reconfirmed owner test person `05dbd5b8-c16b-5f15-8909-1a320b3b8a50`.
  Exclude that person, including linked anonymous events, only in analysis.
- Production schema-v2 MR submission failures from 13:00 to 14:40 UTC reproduce
  13 permission-category and 8 network-category events; network durations are
  20,002–20,023 ms. These are client categories, not original server codes.
- Narrow server idempotency inspection for the affected actor returned **four
  completed outer save-and-submit commands for four distinct request IDs** in
  that interval, each with its nested submit. Nested rows are not duplicates.
  Their completion times were 13:12:03, 13:34:55, 13:51:10 and 14:04:58 UTC.
  No client operation key exists in these events, so individual failed attempts
  cannot be conclusively reconciled. No duplicate or lost MR is asserted.
- Live function definitions confirm actor/command/key-scoped idempotency,
  canonical payload hashing and transaction advisory locking. Wrapper replay
  precedes project-access rechecks: audit revoked-access replay before adding
  automatic write retries. No retry or policy change is included here.
- Other-account support/testing remains uncertain. GeoIP is not travel or
  compromise evidence. This is incident debugging, not a governed KPI.

## Batch tracker

| Finding | Evidence / verified cause | Status / change | Regression / remaining risk / next action |
|---|---|---|---|
| A1: Background recovery overwrites pending or completed submission | Three fault-injection tests failed before the fix: late private sync success, conflict, and transport failure replaced `submitting`. A late success could also persist a cleared draft. | Fixed and tested locally: connected commands supersede older recovery callbacks, cancel queued autosave, and prevent pending edits from changing the intent. | Five new tests; full MR suite 53 passed. No claim this caused historical denials/timeouts. Test full gate before release. |
| A2: Twenty-second submission outcomes are ambiguous | Repository `.timeout(20s)` wraps the RPC without transport cancellation; controller reduces it to backend-unavailable/failed. | Confirmed code behavior; recovery implementation pending. | Keep timeout unchanged. Add explicit unknown state and bounded authorized status reconciliation; verify payload/key and revoked-access semantics first. |
| A3: Late command after disposal/account change | Two fault-injection tests reproduced disposed-controller exceptions for success and denial. | Fixed and tested locally for disposal: late command callbacks return without state/navigation outcome or draft cleanup; stale provider notifications are suppressed. | MR suite 57 passed; cross-account browser walkthrough remains unverified. No automatic resubmit. |
| B: Permission-category incident | Raw codes absent from historical analytics; four successful server commits do not explain 13 denials. | Insufficient evidence for an RLS change. | Trace scoped membership, original server codes and replay authorization; preserve intended denials. |
| B1: JWT failures misclassified | Four mapping tests reproduced `28000` as denied and `PGRST301/302/303` as server rejection. | Fixed locally: map explicit authentication codes to unauthenticated; keep 42501 denied and PGRST300 server configuration failure. | Six mapping cases, MR suite 63 passed. No RLS/grants change or claim about the historical denials. |
| C: Procurement MR load, Inventory, Projects, Dashboard | Snapshot client p95s only; no comparable request trace or SQL plan yet. | Investigation pending. | Measure release/profile fixtures, request counts/bytes and primary-content readiness before optimization; inspect dispatch failure separately. |
| D: Forms, navigation, lookup | Project validation counts do not identify invalid fields; manual material entry is expected behavior. | Investigation pending. | Reproduce conditional validation and navigation recovery; desktop/360px evidence required for presentation changes. |
| E: Telemetry and release identity | Historical metadata is 1.0.0/build 1; wrapped timeouts become network. | Investigation pending. | Preserve timers, add real build identity and controlled outcomes; verify replay-off code and blocked delivery. |

## Verification record

- Flutter 3.48.0-1.0.pre-44 (`9c71d30c3f`); Dart 3.13.1.
- Before fix: three new pending-submission race tests failed with the expected
  wrong states (`savedToAccount`, `conflict`, `local`).
- After fix: `flutter test test/yorks_v1_material_request_test.dart`: **53 pass**.
- Online `flutter pub get` stalled resolving dependencies; stopped after over
  two minutes. `flutter pub get --offline`: **pass**, cached locked dependencies.
- A1 full gate: analyzer passed; 1,720 tests passed; release web build passed
  its existing startup budget (main JS 10,117,462 bytes, gzip 2,734,676 bytes).
  These are artifact sizes, not end-user latency measurements.
- A3: two disposal tests failed before the fix, then MR suite **57 passed**, including save and submit disposal coverage.
  Final analyzer/suite/build results after later changes remain pending.
- Supabase CLI is absent from PATH; Docker CLI exists but its daemon/socket is
  unavailable. Local database reset/pgTAP not run. No privileged SQL read is
  treated as a role test. No database files have been changed.
- Official Dart timeout contract confirms late source completion is possible:
  [Future.timeout](https://api.dart.dev/dart-async/Future/timeout.html).
  Supabase changelog web fetch rejected its content type; shell fetch stalled
  and was stopped. No new SDK/database API was selected from unverified docs.

## Release and rollback

No release is authorized by this task. For A1 alone there is no migration,
API change, new dependency or flag; old clients remain compatible. After full
local checks and desktop/mobile state evidence, review the commit and obtain
separate staging/deployment approval. Roll back by reverting the A1 commit and
rebuilding through the existing signed release process; no data rollback.
This reintroduces the recovery race, so prefer a tested forward fix.

Post-release: compare like-for-like production schema-v2 operation samples,
with the revalidated owner-person exclusion, exact UTC windows, release and
sample counts. Report attempted submissions separately from confirmed server
outcomes and unresolved attempts. Do not add reliability errors to operation
failures or sum daily unique users. Verify no pending-state regressions and
preserved drafts with named scoped synthetic users before broader rollout.

## Resume point

A1 commit: `ad374fc`. A3 follows as a separate commit. A2 needs a tested
reconciliation/access design; continue independent safe investigation while
the local database environment is unavailable. Then B, C, D and E in order.
Do not present this tracker or one controller fix as completion of all batches.
Local temporary logs are `/tmp/yorks-race-before.log`,
`/tmp/yorks-mr-after.log`, `/tmp/yorks-pub-get.log`,
`/tmp/yorks-pub-offline.log`, `/tmp/yorks-analyze.log`, and
`/tmp/yorks-full-tests.log` (copy relevant evidence before final handoff).

B1 API reference: [PostgREST error codes](https://docs.postgrest.org/en/stable/references/errors.html).
A3 commit: `ffef5f4`. B1 focused MR suite: 63 passed.

## Additional safe slice E1

The central lookup detector labelled three typing lookups with two empty results,
or 15 seconds without selection, as struggle. Both material-request and inventory
regression cases failed before correction. Removed that speculative detector;
kept result counts/durations and inventory no-result observations unchanged.
Historical event enum remains for interpretation/compatibility. Updated the
analytics contract and proposed dashboard interpretation; no remote edit.
`flutter test --no-pub test/analytics_service_test.dart`: **17 passed**.
B1 commit: `83d8aa3`.

C/D inspection so far: MR detail timing wraps a single projection RPC plus
model decoding, not visible rendering; the summary register is already paged,
and realtime listens to recipient-filtered notifications with a 20-second
fallback only while unavailable. Project creation already has stage-specific
validation and retained inline error state. These code facts do not prove
acceptable latency or explain the historical validation failures. No speculative
performance change or validation relaxation is included.

Replay audit: `web/index.html` sets `disable_session_recording: true` and disables
autocapture and exception capture; native sink sets `sessionReplay = false`.
Production debug is gated off in `AnalyticsConfiguration`. Actual remote replay
contents remain unavailable (connector lacks recording-read scope); no setting
was changed.

## Additional safe slice E2

R35 now injects the checkout's full Git revision and marks uncommitted builds
`-dirty`. Central telemetry adds validated `release_id` and actual `build_mode`;
app version/build and existing operation timers remain unchanged. Direct builds
without metadata honestly report unknown. No names, paths, keys or content are
used as release labels. Two synthetic-repository launcher tests verify clean
and dirty revisions and rejection of an operator label; 19 analytics tests pass.
E1 commit: `d994b35`.

The A3-era CI Android build passed (105.1 MB), using the required **ephemeral CI
certificate**, not a production signing identity. Gradle/AGP/Kotlin emitted
future-support warnings; dependencies were not upgraded in this task. Rebuild
final source before treating it as the final candidate.
