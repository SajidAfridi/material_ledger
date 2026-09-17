# Yorks reliability, performance and usability remediation

Branch: `codex/yorks-reliability-remediation-20260917`; starting clean HEAD
`1b497e8`. Local implementation and synthetic fixtures only. Production and
staging inspection was read-only. No deployment, merge, live migration, live
operational write, analytics-setting change or new replay collection.

## Evidence boundary

Both supplied implementation requests and all three 17 September evidence files
were read. The historical snapshot ends **2026-09-17 14:40 UTC**. Current Yorks
contracts govern, including approval before arrangement and separate creation
Submit/Approve commands. Manual/non-stock materials remain valid. Material Master
is deferred. GeoIP is not travel evidence; another engineer may be a support user.

Live read-only checks reconfirmed active production `czykuksmlwswjsgotrpo`, staging
`iqltcyimlqtcwyzlemwx`, PostHog project 600792/UTC, and the owner-test person
`05dbd5b8-c16b-5f15-8909-1a320b3b8a50`. Exclude that resolved person and linked
anonymous events in analysis only, not all admins or normal app behavior.

The historical submission sample reproduced 13 permission-category and eight
network-category attempts (20,002–20,023 ms). Raw server error codes and logical
operation keys are absent. A narrowly scoped server read found four completed
outer submissions for four distinct requests at 13:12:03, 13:34:55, 13:51:10 and
14:04:58 UTC. Their nested command rows are not duplicates. Individual client
failures cannot be matched to those commits; no lost or duplicate MR is asserted.
The recorded dispatch failure at 07:55:46 UTC has only category `database`, role
`procurement`, and no duration/operation on the business event. It does not
identify a stock, permission or SQL cause. No historical writes were replayed.

The actual historical deployed Git revision remains unavailable from the supplied
version 1.0.0/build 1 telemetry. New release identity does not backfill that gap.

## Findings and bounded changes

| Finding | Verified cause | Change / status | Regression and remaining boundary |
|---|---|---|---|
| A1: Late private recovery overwrites submission | Three failing fault-injection tests: sync success/conflict/transport replaced submitting state; late callbacks could restore cleared drafts. | Fixed-and-tested-locally, `ad374fc`: generation guards, cancel queued sync, freeze pending edits. | Five race tests; not claimed as the historical timeout/denial cause. |
| A3: Disposed/account-changed command callbacks | Two failing disposal tests; later identity tests exercise owner changes. | Fixed-and-tested-locally, `ffef5f4` and `688935a`: ignore inactive callbacks, preserve original owner's recovery. | Save/submit success and denial disposal, status-read disposal/account switch. Full cross-account browser journey still pending. |
| B1: Authentication classified as authorization/server failure | Four failing mapping tests for 28000 and PGRST301/302/303. | Fixed-and-tested-locally, `83d8aa3`: explicit unauthenticated mapping; 42501 stays forbidden, PGRST300 stays server configuration. | Six mapping cases. Does not explain the historical thirteen denials. |
| A2: Timeout treated as known failure | `.timeout(20s)` stops waiting without cancelling the source future. | Fixed-and-tested-locally, `688935a`: durable account-owned intent marker, outcome unknown, explicit bounded status read, explicit same-key/payload/mode retry only after authorized unconfirmed lookup. | Before/after-commit response loss, reload, frozen edits, duplicate interactions, denied lookup/retry, stale identity. No automatic write retry or timeout increase. Returned/edit-before-approval flow is unchanged. |
| B2: Revoked user can replay cached success | Local before-test expected 42501 but received cached response. | Fixed-and-tested-locally, `5c6b70c`: replay rechecks current authorization; read-only result RPC binds original actor, command, key, hash, request, project and creator; current role-safe projection. | 23 focused pgTAP assertions; full 2,779 database assertions; two real concurrent sessions return one request and preserve side-effect counts. Live migration awaits authorization. |
| D1: Project Review loses inline validation on returning to invalid stage | Two before-failing desktop/mobile tests: `_setStage` cleared errors just presented. | Fixed-and-tested-locally, `21e71d4`: present validation after navigation. | Invalid date remains inline after toast expires; values preserved and no create RPC. No requirement removed. No claim that this explains all historical validation attempts. |
| E1: Automatic lookups labelled as struggle | Two before-failing tests for three typing lookups/two misses or 15-second delay. | Fixed-and-tested-locally, `d994b35`: remove speculative detector; preserve duration/count/availability observations and historical enum. | Manual entry remains allowed. No material text sent. |
| E2: Release metadata cannot distinguish builds | Launcher lacked checkout revision context. | Fixed-and-tested-locally, `07a4fdd`: actual Git hash, dirty suffix, actual build mode; direct builds report unknown. | Two isolated-repository launcher tests; no operator label accepted. Version/build and timer boundaries unchanged. |
| E3: Wrapped timeout category and outcomes | Domain wrapper obscured TimeoutException; attempt failure did not express uncertainty. | Fixed-and-tested-locally, `688935a`: observed timeout category, unknown outcome, separate unconfirmed/reconciled events. | Privacy-safe allowlist and taxonomy tests; no raw exceptions/payload/key sent. No correlation backfill; compare release cohorts only. |
| B/C/D remaining incidents | Historical normalized categories lack request traces, fields and original codes. | Insufficient-evidence for further permission, query, stock or validation changes. | Obtain representative local/profile request traces and original authorized incident codes; do not change RLS or indexes from event counts. |

## Investigation without speculative changes

- MR detail timer uses one `v1_material_request_projection` RPC plus model decode;
  it does not measure visible rendering. Register summaries are already paged.
  Recipient-filtered notification realtime triggers refresh; 20-second fallback
  applies while realtime is unavailable. No refetch defect is proved by counts.
- The central operation timer is per-operation and monotonic; browser scheduling
  and network wait remain inside client duration. No timer boundaries changed.
- Project validation is already stage-specific; the confirmed error-reset defect
  is separate from missing/conditional-field rules. Full keyboard focus-to-first-
  invalid-field and conditional-field matrix remain acceptance work.
- Auth password attempts terminate after authentication/profile materialization;
  restoration uses a separate event. Delivery loss, browser closure and unexpected
  materialization errors remain unresolved instrumentation cases. No missing
  terminal event is labelled a failed login.
- Analytics delivery stays centralized/best-effort. Replay is disabled in web
  (`disable_session_recording: true`, no autocapture/exception capture) and native
  (`sessionReplay = false`); production debug is off. Connector recording scope
  was unavailable, so no remote recording-content claim or setting edit.

## Verification and measurements

Environment: Flutter 3.48.0-1.0.pre-44 (`9c71d30c3f`), Dart 3.13.1,
Supabase CLI 2.117.0 through cached `npx --offline`, local PostgreSQL 17.6/Docker.
Online `flutter pub get` stalled and was stopped; `flutter pub get --offline`
passed using locked cached dependencies. Docker was initially stopped, then the
local stack was started and explicitly reset with `--local`, never `--linked`.

- Analyzer passed before the final Project validation slice; final gate below.
- A2 full Flutter suite: **1,747 passed**. The new full-form desktop/mobile tests
  separately passed after moving recovery controls above the scrolling form.
  An earlier run exposed two ownerless test fixtures; their explicit synthetic
  identity was corrected, without weakening the production guard.
- `supabase db reset --local`: passed, including the proposed migration/seed.
  `supabase test db`: **96 files, 2,779 assertions passed** (100 seconds).
  Reapplying the migration directly to the local DB also passed.
- Local two-connection probe: two identical commands returned one header/line;
  one outer key, one audit event, three recipient notifications. Another result
  read and replay left all counts unchanged. See [probe result](evidence/2026-09-17/mr-concurrency.json)
  and [reproduction script](../../test/support/yorks_mr_reconciliation_concurrency.py).
- Recovery panel screenshot/interaction coverage: desktop 1366 and mobile 360,
  English/Arabic at 1.5x text, 44px targets, checking disables actions, no retry
  before allowed. Full form screenshots at 1366x768 and 360x800 verify visible
  status action and preserved fields. This is not full accessibility compliance.
- A2 CI web release build and startup budget passed: main JS **10,126,866 bytes**,
  gzip **2,736,847**; A1 baseline 10,117,462 / 2,734,676. Size increase is not a
  performance improvement. CI Android passed, 105.1 MB, **ephemeral CI signing**;
  it is not a production-signed artifact. Final source gate remains below.
- No comparable production before/after latency, transfer, or rendering sample
  exists. No speedup or compute benefit is claimed. Local fixtures do not model
  production data volume or latency percentiles.

## Review, rollout and rollback

1. Review commits in this branch; no PR was opened, pushed, merged or deployed.
2. Review migration `20260917154516_material_request_submission_reconciliation.sql`
   separately. It changes function definitions only; strict anchors abort on
   definition drift, no backfill/index/data rewrite, original write locks remain.
3. With separate explicit staging authorization, apply the migration **before**
   the client. Repeat PE/Site/Procurement/Admin checks using synthetic accounts,
   revoked membership, dropped response, concurrent same-intent retry, account
   switch, reload and commercial-safe projection. Older backend lookup failure
   safely preserves unknown state but is not a usable rollout acceptance.
4. Build the reviewed clean revision through `tool/r35.sh`; validate matching
   `release_id`/build mode, web assets/routes and a properly signed Android lane.
   Employee browser/device acceptance and authorized production rollout remain.
5. Application rollback should retain the compatible read RPC and stricter
   replay guards. Do not revert clients while unresolved recovery drafts exist:
   older clients do not understand the marker. Reconcile them or forward-fix.
   Never delete key, audit, notification or workflow history. See the detailed
   [migration/rollback contract](../yorks-v1/MIGRATION_AND_ROLLBACK_PLAN.md).
6. After authorized release, use [query templates](evidence/2026-09-17/post-release-query-templates.json).
   Replace every UTC/release placeholder, revalidate owner-person mapping, retain
   `filterTestAccounts: true`, the exact owner-person exclusion, production and
   schema-v2 filters. Templates are prepared, not executed against a new release.
   Compare equal windows/releases, report samples and affected identities, and
   separate attempts, confirmed business outcomes and unresolved outcomes.
   Never sum failure streams, daily uniques or unrelated cross-role funnels.

## Current handoff / next bounded work

The final verification and local browser results are recorded below as they
complete. Remaining acceptance: authenticated Chrome/Edge procurement review
trace with representative synthetic volume (RPC count/bytes/wait/decode/render),
then Inventory/Projects/Dashboard; dispatch original server-code evidence;
conditional Project validation/focus recovery; stale search/reconnect navigation
and tablet/device walkthrough. No speculative performance or authorization fix
is justified by the current historical evidence. No background work is implied.


## Final verification record

- Final source analyzer: **pass**, no issues; all 17 changed Dart files pass
  `dart format --output=none --set-exit-if-changed`.
- Final complete Flutter suite: **1,751 passed**. Project Creation focused suite
  also passed all 23 tests after the two before-failing validation cases.
- Final local database gate: **2,779 passed**; no database changes followed it
  other than successful repeat application of the same idempotent migration and
  the synthetic concurrent-call probe.
- Chrome 152 / local profile build: login rendered. A synthetic Procurement
  sign-in returned local Auth HTTP 200, but the UI remained on login with a busy
  indicator during the bounded observation. See [observed state](evidence/2026-09-17/local-chrome-auth-pending.png).
  Auth success is not workspace readiness. Authenticated procurement/Edge/mobile
  browser acceptance and trustworthy performance measurement remain blocked by
  this unresolved local sign-in/materialization path. Do not label it a production
  regression or bypass release-security checks. Next bounded task: isolate that
  path against the baseline and collect sanitized Auth/profile HTTP timings.
- The local HTTP release build correctly failed closed. The browser used an
  explicit loopback-only profile configuration with PostHog off; no remote
  analytics delivery or production operational write was used for the smoke test.
- Task browser and profile/HTTP servers were stopped. Local Docker database/API
  containers remain available for reproducing the synthetic tests.

Final CI web build: **pass**, main JS 10,126,866 bytes, gzip 2,736,848 bytes;
startup budget retained. Sanitized gate excerpts are in
[verification.txt](evidence/2026-09-17/verification.txt). Source commit is
`21e71d4`; build metadata truthfully includes `-dirty` because documentation and
evidence were being finalized. No application source changed after that commit.

Final CI Android rebuild: **pass**, 105.1 MB, 42.8 seconds, ephemeral signing.
[Artifact hashes](evidence/2026-09-17/artifacts.json) identify the locally tested
CI outputs; they are not deployed or approved production artifacts. All final
source gates passed. The outstanding browser and production checks above remain
release blockers, so this is **ready for code review, not production-verified**.
