# Yorks Performance Review

Date: 2026-09-03
Owner: Codex investigation, implementation and verification
Status: **first performance batch released: both database fixes and verified
web client live in production. Broader load attribution remains open.**

## Guardrails

- Supabase/Postgres remains authoritative. No RLS policy, role boundary,
  command invariant, idempotency rule or protected response shape was weakened.
- No production data was reset, vacuumed, deleted or rewritten.
- No index was added from scan counts alone. The database has a 1.00 reported
  table/index cache hit rate and the relevant indexes are actively used.
- Existing dirty-worktree changes were preserved. The three uncommitted startup
  migrations through `20260902163200` were already present in production before
  this review; this document does not claim authorship of them.
- Database counters below are cumulative since the production statistics reset,
  reported as roughly 22 days old during this investigation. Short snapshot
  deltas are used to distinguish historical incidents from current activity.

## Request and refresh map

```text
sign-in
  -> exact V1 identity
  -> current permission snapshot RPC
  -> one per-user permission-revision Realtime channel
  -> protected screens/repositories

root shell (existing released startup; pending startup redesign excluded)
  -> workflow notifications
  -> push registration
  -> legacy collection sync
  -> 14 broad legacy Postgres Changes subscriptions

Team Chat while mounted
  -> list-conversations RPC
  -> one channel covering messages + conversations + members
  -> selected-thread RPC
  -> delivery acknowledgement only when the server says a cursor is pending
```

Realtime remains a refresh signal; every protected projection and critical
command is still re-authorized by Postgres.

## Production baseline and attribution

| Signal | Observed evidence | Interpretation |
|---|---:|---|
| Realtime change polling | 2,149,890 calls; 24h 21m cumulative execution; 56.0% of recorded DB execution | Primary sustained database load surface |
| PostgREST session setup | 345,776,121 calls; 2h 07m cumulative execution | Very high request/connection churn, not one slow business query |
| Realtime subscription writes | 708,256 cumulative writes | Persistent subscription churn is material on a Nano project |
| Commercial capability RPC | 193,819 calls; 14m 30s cumulative execution | Mostly historical feedback-loop load; only 12 additional calls between review snapshots |
| Profile writes | 192,675 cumulative; no increase between review snapshots | Confirms the August profile-update loop is no longer actively writing |
| Idempotency-key writes | 137,787,940 cumulative; only 20 additional writes between snapshots | Severe historical/test-era amplification, not evidence of a current 137M-write loop |
| Realtime polling delta | +5,768 calls between review snapshots | Realtime load is still accumulating materially now |
| Realtime subscription delta | +1,408 writes between review snapshots | Subscription registration/re-registration is still active now |
| Chat-member writes | 4,938 cumulative, +44 between snapshots | Consistent with receipt/member refresh amplification plus real chat activity |
| Push dispatch cron | 32,658 calls; about 6m 09s cumulative | Frequent but low individual cost; not a P0 root cause |

The operator-provided Supabase baseline also reported CPU at 100%, memory near
80%, disk I/O near 91%, 3.44M Realtime messages and 4.706 GB of 5 GB egress.
CLI production inspections intermittently timed out or terminated, which is
consistent with pool pressure but does not by itself prove one query is at
fault.

## Prioritized findings

### P0 — Realtime and connection churn

**Evidence:** Realtime polling owns 56.0% of cumulative recorded DB execution;
polling and subscription counters continued to rise during the review. The app
can mount 14 broad legacy `all events` table subscriptions in addition to
normalized notification, permission, request and chat subscriptions.

**Supported explanation:** long-lived broad subscriptions and overlapping
feature-specific signals multiply Realtime authorization work on a very small database. The
table scan counts are a symptom of repeated policy/projection evaluation, not
large tables. Polling calls are **not** the billed Realtime message count, and
these cumulative counters cannot attribute all 3.44M billed messages. Supabase
documents the per-subscriber authorization cost of Postgres Changes in its
[performance guidance](https://supabase.com/docs/guides/realtime/postgres-changes#database-instance-and-realtime-performance).

**Status:** partially reduced by the commercial consolidation below. A broader
legacy-subscription change is intentionally not bundled into this slice because
missed refreshes would be a correctness regression.

**Next safe test:** inventory which legacy collection consumers are actually
mounted per route, then lazy-subscribe by active module with reconnect and
foreground recovery tests. Acceptance requires no stale Inventory, Rentals,
People, Leave, receipt or workflow state.

### P0 — Missing master-table publication entries

**Component/evidence:** production `supabase_realtime` omits
`materialCategories` and `materialUnits` despite both being requested by
`RealtimeSync` on every login. The tracked prerequisites migration and dedicated
staging include both. At inspection, production had 40 live subscription rows,
none for either master table. These tables exist and have RLS enabled.

**Root cause/current behaviour:** production publication drift leaves two
requested subscriptions unable to initialize. It is a confirmed broken refresh
contract and a plausible contributor to retries, not proof that it caused all
3.44M messages. Broad subscriptions alone also do not prove a runaway loop.

**Fix:** independently staged migration
`20260903133000_repair_material_master_realtime_publication.sql` restores only
these two intended entries, with a three-second lock timeout. No row, RLS
policy, grant, replica identity or API changes. Removing those exact entries
is the transport-only rollback; never delete the tables or their data.

**Tests/result:** 13 publication/permission assertions passed locally and on
staging; the existing nine master-RLS assertions also passed locally. Four
exact roles retain reads and their existing write restrictions; anonymous
access stays denied. A live 22-second local WebSocket probe received `error`
for both tables when publication entries were temporarily absent, then `ok`
after restoration. Dedicated staging also returned `ok` for both. Only local
transport was temporarily changed during reproduction, and was restored via
an exit trap. Overlapping local probes make their registration-count deltas
unsuitable for a speedup claim; only the transport verdicts are used.

**Status/expected impact:** applied and ledger-verified in production. Both
publication entries are present. Should restore category/unit refresh and eliminate this particular
subscription setup failure. Production CPU/message impact remains to measure.

### P0 — Firebase worker imported Flutter's unregister/reload stub

**Evidence/root cause:** the original bootstrap awaits Firebase worker setup;
that worker imports `flutter_service_worker.js`. Both the live production
endpoint and current Flutter build return a 784-byte cleanup stub at that path.
Its activation handler unregisters the *current* registration and navigates its
controlled windows. Importing it into Firebase therefore installs cleanup logic
inside the push worker. The staging browser emitted a specific
`prepareServiceWorker took more than 4000ms` warning before rendering sign-in.
This is a concrete startup delay and a possible registration/reload amplifier;
it is not proof of the exact historical billed-message total.
Flutter's current [web guidance](https://docs.flutter.dev/platform-integration/web/faq#how-do-i-configure-a-service-worker)
also confirms that applications must own any required service worker rather
than relying on Flutter to provide an offline-cache worker.

**Fix/provenance:** adopt the already-present, uncommitted Firebase worker
header correction only; do not claim authorship of that existing correction.
Its push handlers remain byte-for-byte unchanged. The isolated candidate's
bootstrap now calls `_flutter.loader.load()` without waiting on a worker.
The existing signed-in `PushService.getToken` still explicitly registers
`firebase-messaging-sw.js`. No draft storage, authorization, FCM payload,
notification routing or document quality changes. No functioning offline cache
is removed: the deployed generated worker already unregisters rather than
caching assets.

**Tests/risk/status:** two bootstrap contract tests and three executed worker
tests passed, preserving Firebase-only imports, fallback message contents,
deduplication and notification-payload handling. This narrowly overlaps the
pending startup work, but none of its splash/layout/coordinator changes are
included. The first temporary production candidate was deliberately not
promoted after the browser check exposed this issue. The updated staging browser
rendered sign-in with no new service-worker warnings; the earlier two warnings
were timestamped to the previous deployment. All eight artifact/route checks
passed before the corrected deployment was promoted. Roll back the
deployment if necessary; restoring the old worker would reintroduce this known
defect, so do not describe it as a healthy push fallback.

### P0 — Pool headroom and measurement reliability

**Evidence:** production inspection connections intermittently failed; after a
successful staging migration and pgTAP run, two read-only staging `EXPLAIN
ANALYZE` attempts timed out/terminated at the pooler.

**Status:** unresolved infrastructure signal, not a proven pool-capacity
diagnosis. A direct PostgreSQL client subsequently succeeded and produced the
chat timings below; the earlier CLI failures do not invalidate those timings.
One production migration attempt failed authenticating the temporary CLI
role; ledger verification proved it had not applied. A serial retry succeeded.
Run linked diagnostics/deployments serially to avoid potential temporary-role
credential conflicts, and distinguish tool-authentication errors from actual
application database timeouts.

**Next safe test:** capture provider pool metrics and a fixed five-minute
request/Realtime window when the pool accepts diagnostics. Do not reset
`pg_stat_statements` until an approved before/after window is ready.

### P1 — Duplicate current-session commercial authority stream

**Evidence:** the global permission snapshot already contains authoritative
`commercials.view` and `commercials.manage`, yet commercial UI state also
mounted `v1_get_current_commercial_capabilities` plus two Realtime channels.

**Root cause:** the earlier commercial boundary predated the scoped permission
snapshot and remained as a second live authority-refresh mechanism.

**Fix:** `canViewCommercialsProvider`, `canManageCommercialsProvider` and the
commercial purge listener now use the global protected permission snapshot.
Access requires a confirmed active user, no current error, healthy revision signal, non-stale
snapshot and authoritative server grant. The legacy provider remains available
as an unmounted compatibility/test seam.

**Risk and rollback:** low client-only risk. Revert the provider consumers to
the dedicated commercial provider if parity fails. Database RLS and RPC checks
are unchanged.

**Expected impact:** two fewer Realtime subscriptions and no routine dedicated
commercial-capability RPC per active exact-V1 session after the app is released.

**Verification:** 57 focused commercial/permission tests passed, including
immediate revocation purge. Six additional client authority tests cover
untrusted/error states, ordinary refresh and four exact roles. Six database
assertions passed locally and on staging: legacy/consolidated parity for Project
Engineer, Site Engineer, Procurement and Admin; revision propagation; and a
denied revocation. Staging test mutations rolled back. Status:
**released in the verified production web client**.

### P1 — Chat list, delivery acknowledgement and member-event amplification

**Evidence:** production cumulative scans were disproportionate to retained
rows: roughly 307k conversation scans and 223k message scans for 75
conversations and 397 messages at the first snapshot. Production request
statistics recorded 45,733 list calls averaging 199.74 ms and 10,775 delivery
calls averaging 138.68 ms (cumulative, not a controlled latency window).
Every list refresh called
`v1_mark_chat_delivered` for every conversation. A real cursor update then
emitted a member event and caused another list/thread refresh. The list function
also evaluated the full protected conversation helper once for output and again
for unread sorting.

**Fix:** migration `20260903121000_optimize_team_chat_refresh.sql` adds a
non-commercial `needs_delivery_ack` projection, preserves old-client behavior,
and materializes each conversation projection once. The client calls the
existing trusted acknowledgement RPC only for projected pending conversations.

**Risk and rollback:** projection-only migration; no data rewrite. Restore the
prior function bodies and client mapping to roll back. Older clients ignore the
new key. New clients conservatively retain the old behaviour if the key is
absent. RLS, grants, receipt cursors and sender/recipient authority are
unchanged.

**Expected impact:** a steady-state 30-second fallback or Realtime refresh no
longer emits a delivery RPC. A genuine incoming message advances once; the next
projection suppresses repeats. Each conversation summary is built once per list
request rather than twice.

**Verification:** 72 Flutter chat/commercial/permission tests passed in the
combined focused run; local chat pgTAP passed 92 assertions; the new collision-
safe contract passed 9/9 locally and 9/9 on dedicated staging. Status:
**database migration applied to staging and production; client verified on
dedicated staging and released in production**.

Production function-definition hashes match the tested local database:
conversation helper `c4e5c100f7215876b333f8ae1249fe09`, list RPC
`7fe87c6c774e416ef133fa8b51cc9d9b`. The delivery command remains unchanged at
`0a9fd2bc3333678ef9414b6ac20d4f13`. Its grants, the private helper grants and
both empty search paths were verified unchanged after application.

**Measured staging result:** the retained Project Manager sees one conversation.
After warm-up, five alternating samples of the prior repeated-helper list
expression versus the new RPC had identical JSON. Baseline samples were
16.56/9.47/9.31/9.34/9.30 ms; candidate samples were
8.66/8.39/7.96/8.06/7.89 ms. Median: **9.34 → 8.06 ms (13.7% lower)**.
Both sides used the new helper, so this isolates query structure rather than
claiming a complete old/new client benchmark. A separate first-call
`EXPLAIN (ANALYZE, BUFFERS)` recorded 325.478 ms and 2,969 shared-buffer hits.
Neither small sample is a production p95 or a CPU/egress reduction claim.
Reproduce with [`../../tool/yorks-performance-chat-benchmark.sql`](../../tool/yorks-performance-chat-benchmark.sql).

### P1 — Startup projections already in the worktree/production

**Evidence:** the existing dirty worktree paints before non-critical startup,
delays global background services and uses bounded project/material-request
overview projections. The matching uncommitted migrations are already recorded
in the production migration ledger.

**Verification observed:** 8 startup architecture/projection/web contract tests
passed during this review. Status: **pre-existing implementation; production
database provenance verified, unreleased client changes excluded from this batch**.

### P2 — Indexes and small-table sequential scans

The request/project, permission, chat-member and chat-message indexes show
substantial use. Tiny lookup tables may still be cheaper to scan sequentially.
No speculative index is proposed. Revisit only with an exact slow query and
`EXPLAIN (ANALYZE, BUFFERS)` evidence.

### P1 — Refresh bursts, join gaps and reconnect recovery

Notifications poll every 30 seconds only when their live signal is unavailable;
Material Requests fall back every 20 seconds; Chat falls back every 30 seconds.
These are correctness safeguards. Optimize by proving channel health and
coalescing invalidations, not by deleting recovery paths.

**Evidence/root cause:** code audit found inverted reconnect detection in chat and notifications:
a repeated healthy `subscribed` callback refreshes, while an unavailable-to-
subscribed transition can skip the recovery refresh. Initial reads precede
subscription registration, leaving a join gap. Chat's old list-only guard also
allowed every overlapping refresh caller to fetch the selected thread, while
notification/list events arriving mid-fetch could be dropped altogether.

**Fix:** small shared invalidation queue, not a data cache: concurrent signals
coalesce, but one trailing authorized fetch reconciles changes during a read.
Availability transitions trigger one refresh, including the initial join;
repeated healthy acknowledgements do not. Chat startup is idempotent and
disposal suppresses late state publication/delivery writes. Existing 30-second
safety polling and foreground recovery remain intact. No server command is
queued, cached or optimistically acknowledged by this helper.

**Verification/measured contract:** nine new regression tests passed. A burst
of 20 chat refresh requests produces two list reads and two selected-thread
reads, not 20 thread reads. Notification bursts retain a trailing read rather
than dropping the event; this is correctness protection, not a claimed
20-to-2 reduction from its old single-flight implementation. Tests cover an
event during the trailing read, retry after failure, disposal, initial/late/
recovered joins and duplicate readiness. Combined focused run: 38 tests,
including chat interaction and four responsive goldens, passed.

**Risk/rollback/status:** client-only, separately reviewable; revert the queue
and readiness use if a lifecycle regression is observed. Released in production;
final isolated tests, CI web and CI Android build passed. Material Requests retain
their existing independent signal and fallback in this slice.

### P3 — Asset egress and cache headers

The supplied 4.706 GB egress reading is close to quota, but this review has not
yet obtained a provider breakdown by Storage object, REST response, Realtime or
web asset. No compression or cache change is safe without that attribution.

### P1 — Legacy sync ownership and logout finality

**Evidence/root cause:** the root-owned legacy collection sync had no idempotent
`start` guard. Two calls on one instance registered 28 channels instead of 14.
If logout stopped the object while its initial Realtime token setup was still
awaiting, startup then attached an auth listener after shutdown. A queued
Postgres callback also remained able to modify the logged-out local cache.

**Fix:** startup is single-owner and cannot run after stop; shutdown during
token setup is checked before the auth listener is attached; refreshed-token
and row callbacks become no-ops once stopped. No table, event type, RLS rule,
local data shape or foreground refresh is removed.

**Measured contract/risk:** four regression tests first reproduced all four
failures, then passed after the guard. The focused auth/session/sync run passed
33 tests and the isolated full suite passed 1,494. This prevents 14 duplicate
subscriptions per accidental second start and a logout-time listener leak. The
normal one-start path still owns exactly 14 table subscriptions. It does not
claim that duplicate start was observed in production or caused the historical
Realtime total. Client-only rollback is the prior `RealtimeSync` lifecycle.
Status: **released in the verified production web client**.

## Verification ledger

| Gate | Result |
|---|---|
| Focused commercial + permission Flutter tests | 57 passed |
| Combined chat + commercial + permission Flutter tests | 72 passed |
| Local database reset through all migrations | Passed |
| Local lifecycle + full Team Chat pgTAP | 92 passed |
| Local collision-safe performance pgTAP | 9 passed |
| Commercial authority parity pgTAP | 6 passed locally and 6 on staging |
| Full local database gate before added parity test | 83 files / 2,464 assertions passed |
| Final full local database gate | 85 files / 2,483 assertions passed |
| Final full Flutter gate in existing working tree | 1,500 passed, including preserved startup work |
| Final commercial client authority/revocation focused gate | 16 passed |
| Isolated candidate focused chat/commercial gate | 31 passed, including four responsive goldens |
| Isolated candidate full Flutter gate before lifecycle slice | 1,477 passed |
| Final isolated full Flutter gate, including worker fix | 1,490 passed |
| Lifecycle + chat compatibility/notification gate | 38 passed |
| Bootstrap contract + executed worker tests | 2 Flutter and 3 Node tests passed |
| Flutter dependency resolution and analysis | Passed; no dependency upgrade |
| CI web build in existing working tree | Passed; 9,532,490-byte JS / 2,586,594-byte gzip |
| CI Android build in existing working tree | Passed; ephemeral signing, not production-signing proof |
| Dedicated staging migration dry run | Exactly one migration pending |
| Dedicated staging migration apply | Passed |
| Dedicated staging collision-safe performance pgTAP | 9 passed |
| Legacy staging chat suites | Not valid on retained data; fixtures selected historical Direct rows and failed assumptions |
| Staging execution timing | Direct PostgreSQL client succeeded; samples above |
| Production chat migration | Applied alone; ledger and function/grant hashes verified |
| Production master-publication repair | Applied separately; ledger and both entries verified |
| Final isolated CI web / staging web / production web builds | Passed after worker correction |
| Final isolated CI Android build | Passed; ephemeral signing, not a production Android release |
| Updated staging browser | Sign-in rendered; earlier four-second worker warning absent |
| Staging, temporary production, promoted public URL | Eight routes/assets each hash-verified |
| Legacy sync lifecycle | 4 regression tests; 33 focused and 1,494 full Flutter tests passed |
| Second-slice CI web / CI Android / staging / production web builds | Passed; Android used ephemeral signing |
| Production web app deployment | Promoted `dpl_Zei7RhZrfm84Cyti5XMnNS1MrnGR` |

## Released batch and remaining measurement boundary

The release gate used deterministic request-count regression tests, four-role
server parity/denial tests, collision-safe staging chat tests, complete local
Flutter/database suites, signed-out browser validation and byte-matched deployed
artifacts. A comparable multi-user CPU/egress window and named-persona manual
browser UAT were **not** obtained and are **not** claimed as passed. The measured
small-data chat query improvement is independent of those missing measurements.
Live subscriber counts changed from 40 to 21 to 1 during investigation, so a
falling aggregate counter rate would not establish a client optimization gain.

Next: capture equal, representative before/after windows for REST requests,
Realtime messages, subscription writes, chat list/delivery calls, CPU, memory,
temporary writes and egress. Retain foreground/reconnect recovery and all
authorization checks. Users with an already-open older client may need to
close/reopen Yorks to use the new client code; do not force-reload active drafts.

The backward-compatible database slice can be released independently of the
app: old clients ignore the added JSON key and benefit from the single
projection. The isolated candidate is on
`codex/performance-refresh-20260903`, based on GitHub `f37ee8a`, with only the
selected performance files copied in. The main branch reference and unrelated
dirty work were preserved. Review-owned edits are also retained in that working
checkout; it is intentionally not claimed clean.

Live provenance was checked rather than inferred from the dirty worktree:
before this release, production was deployment
`dpl_CbRqPVqXqgzv9nU9Ug5QUSjFmFnz` from September 2.
Its 3,588-byte HTML matches the clean base at SHA-256
`31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5`, not the
7,488-byte uncommitted startup build. Thus the isolated candidate preserves the
current released UI; the new startup migration ledger entries do not imply
that the corresponding uncommitted client was deployed.

The browser skill was used for live signed-out staging rendering and form
validation. It exposed the worker delay above and held promotion. Authenticated
authorization evidence remains the real staging API and four-role database
tests; no browser permission grant or test-password entry was needed.

Initial staging preview (first client slice, commit `f4ecdf6`):
[Yorks performance preview](https://yorks-r35-hjm075rzc-sajid-alis-projects-0ec775a2.vercel.app).
It embeds only the dedicated staging backend. Downloaded `main.dart.js` matches
SHA-256 `a658a64a74806af1e364dd88ca66db84cd47dc2ae6ef2345abe18b95f4947303`.
The root returns 200; Vercel appends its expected preview-feedback script to
otherwise identical HTML. A partial JS download was retried and hash-checked;
HTTP 200 alone was not accepted as artifact proof.

Final worker-fixed staging (source commit `b10de00`):
[Yorks staged candidate](https://yorks-r35-3m27ytv6j-sajid-alis-projects-0ec775a2.vercel.app),
deployment `dpl_HeN2Nq6BpiRDpdgQeLCcvsgvLqzH`.
Its 9,525,450-byte JS is SHA-256
`008738943e9203a416c4badd8e4ef1e7f0bad523282562b184003dbaeddaf5dd`.

Initial production release (same source, production backend configuration):
[immutable deployment](https://yorks-r35-qtw9agq3y-sajid-alis-projects-0ec775a2.vercel.app),
deployment `dpl_5rYk4zY8UZhxxah6vkVgVHw8zbTv`, promoted September 3 at
approximately 13:58 UTC. Its isolated build is
`/private/tmp/yorks-performance-release-web.wbHf5q`.
Production `main.dart.js` is 9,525,530 bytes, SHA-256
`231dbf9a7e480525cbc4b06138b78188961dd36c6de41f315adb45a6f069683d`.
The production backend is present; staging and CI placeholders are absent.

Single-owner lifecycle staging (source commit `90ea359`):
[Yorks lifecycle staging](https://yorks-r35-cbf9rdtod-sajid-alis-projects-0ec775a2.vercel.app),
deployment `dpl_4MBGpWdSFbY4EgFsK8ivsiuuZLdu`. All eight artifact checks passed;
signed-out sign-in rendered with no browser warnings or errors.

Current production:
[Yorks production](https://yorks-r35.vercel.app),
[immutable deployment](https://yorks-r35-6pq30qlmr-sajid-alis-projects-0ec775a2.vercel.app),
deployment `dpl_Zei7RhZrfm84Cyti5XMnNS1MrnGR`, promoted September 3 at
approximately 17:42 UTC. Its isolated build is
`/private/tmp/yorks-performance-sync-production.seICWn`. Production
`main.dart.js` is 9,525,603 bytes, SHA-256
`a127622245cc70d426c9ed31bd93be866a7a9898c34334cad7aa20c612d8d218`.
The production backend is present; staging and CI placeholders are absent.

Both temporary deployments and the promoted public URL passed the same eight
checks: root, Material Requests and Team Chat deep-route HTML, main JS,
bootstrap, generated Flutter cleanup worker, Firebase worker and manifest.
The checks compare bytes after removing only Vercel's explicit preview toolbar
suffix. Bootstrap SHA-256:
`f26b01dd7d057774b69b17f5bdd243b3513dd02f316159bdd27812ec85b66645`;
Firebase worker:
`5e5e4a4b1fed3318b09136d64014d899c17a8c08220a2cc5cb75dc3902e89c1c`.
Reproduce with [`../../tool/verify-yorks-web-release.mjs`](../../tool/verify-yorks-web-release.mjs).

Post-promotion snapshot at 13:59:15 UTC: two live subscription rows, 2,160,079
cumulative Realtime polls, 395,901 subscription registrations, 45,885 chat list
calls, 10,927 delivery calls and 65,549,063,003 cumulative temporary bytes.
Profiles and idempotency writes remained unchanged from 13:00. This establishes
an after-release baseline, **not** a CPU/message/egress reduction verdict.

After the lifecycle release, the 17:43:10 UTC snapshot had 32 live subscription
rows, 2,165,112 cumulative Realtime polls, 397,439 subscription registrations,
46,042 chat list calls, 11,083 delivery calls and 67,022,063,032 cumulative
temporary bytes. The four-hour interval and subscriber-count change make it
unsuitable for a controlled before/after rate claim; it is retained as the new
production baseline.

Rollback: retain the prior known deployment for artifact rollback; the two
database changes are backward compatible, so no destructive rollback or row
reconciliation is needed. Reverting the worker correction would restore a known
startup/push defect. The earlier temporary deployment
`dpl_9uuUQUFrgrtX28E2CgBjFfcCy3C2` was held and was never promoted to the public URL.

## Remaining attribution and after-Micro comparison

- **CPU:** cumulative Realtime polling was 56% of recorded execution. That is
  not a current CPU-utilization measurement or proof of a single root cause.
- **Disk I/O:** database statistics showed about 65 GB cumulative temporary
  writes despite the tiny retained database. Between 13:00:19 and 13:06:10 UTC,
  temporary bytes increased by 59,897,996 while ordinary block reads stayed
  at 3,285. Attribute temporary I/O/logical-decoding spills before changing
  memory settings or adding indexes. No such configuration was changed.
  A later check found zero spill bytes on both active logical-decoding slots;
  only about 449 KB of retained WAL. The largest currently retained temporary-
  block query is `v1_inventory_workspace_projection` (646 calls; 83,980 blocks
  written), which does not explain the entire historical 65 GB. Its enriched
  item CTE and full JSON payload need a separate query-plan/parity experiment.
- **RLS/indexes:** repeated authorization scans are evident, but this slice
  establishes no missing index or individual policy rewrite as safe and
  beneficial. No blanket advisor fix, unused-index deletion or RLS weakening.
- **Egress:** the 4.706 GB operator reading is not yet broken down by REST,
  Storage and Realtime. Vercel's Flutter bundle is not Supabase egress. Fewer
  duplicate responses should help, but no GB saving is claimed without the
  provider breakdown and representative payload measurements. A real staging
  Project Engineer HTTP sample returned 117,106 decoded bytes for permissions,
  1,340 for chat, 2,294 for notifications and 1,573 for requests, all HTTP 200.
  End-to-end times were 2,359/407/396/1,044 ms respectively. These are one-shot
  staging/network observations, not production p95 or compressed wire sizes.
- **Next source boundary:** the three pre-existing production startup migrations
  remain uncommitted separately. Do not include their client/UI changes or the
  unrelated profile/splash work in this release. Reconcile those in their own
  reviewed change.
- **After Pro/Micro:** reuse `tool/yorks-performance-counters.sql` with equal,
  timestamped windows and comparable users/actions. Record RPC delta mean/p95,
  CPU, memory, I/O, temporary bytes, pool timeouts, subscriber/message counts,
  REST bytes and screen timings. Preserve the pre-upgrade snapshots; never reset
  shared statistics or claim the hardware upgrade fixed duplicated work.
