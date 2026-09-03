# Yorks Performance Review

Date: 2026-09-03  
Owner: Codex investigation, implementation and verification  
Status: **two safe fixes implemented; chat database slice passed dedicated staging; production unchanged**

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

root shell (delayed non-critical startup)
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

### P0 — Pool headroom and measurement reliability

**Evidence:** production inspection connections intermittently failed; after a
successful staging migration and pgTAP run, two read-only staging `EXPLAIN
ANALYZE` attempts timed out/terminated at the pooler.

**Status:** unresolved infrastructure signal, not a proven pool-capacity
diagnosis. A direct PostgreSQL client subsequently succeeded and produced the
chat timings below; the earlier CLI failures do not invalidate those timings.

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
**implemented locally; app not deployed**.

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
**database migration applied to staging; client not deployed; production
unchanged**.

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
passed during this review. Status: **pre-existing implementation; provenance
must be reconciled before a release candidate is formed**.

### P2 — Indexes and small-table sequential scans

The request/project, permission, chat-member and chat-message indexes show
substantial use. Tiny lookup tables may still be cheaper to scan sequentially.
No speculative index is proposed. Revisit only with an exact slow query and
`EXPLAIN (ANALYZE, BUFFERS)` evidence.

### P2 — Safety polling and foreground recovery

Notifications poll every 30 seconds only when their live signal is unavailable;
Material Requests fall back every 20 seconds; Chat falls back every 30 seconds.
These are correctness safeguards. Optimize by proving channel health and
coalescing invalidations, not by deleting recovery paths.

Code audit also found inverted reconnect detection in chat and notifications:
a repeated healthy `subscribed` callback refreshes, while an unavailable-to-
subscribed transition can skip the recovery refresh. Initial reads precede
subscription registration, leaving a join gap. This is a separate pending
client lifecycle slice, requiring duplicate-status, reconnect, late-join and
in-flight-event tests before implementation is accepted.

### P3 — Asset egress and cache headers

The supplied 4.706 GB egress reading is close to quota, but this review has not
yet obtained a provider breakdown by Storage object, REST response, Realtime or
web asset. No compression or cache change is safe without that attribution.

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
| Full Flutter gate in existing working tree | 1,481 passed before the final fail-closed helper refinement |
| Final commercial client authority/revocation focused gate | 16 passed |
| Isolated candidate focused chat/commercial gate | 31 passed, including four responsive goldens |
| Flutter dependency resolution and analysis | Passed; no dependency upgrade |
| CI web build in existing working tree | Passed; 9,532,490-byte JS / 2,586,594-byte gzip |
| CI Android build in existing working tree | Passed; ephemeral signing, not production-signing proof |
| Dedicated staging migration dry run | Exactly one migration pending |
| Dedicated staging migration apply | Passed |
| Dedicated staging collision-safe performance pgTAP | 9 passed |
| Legacy staging chat suites | Not valid on retained data; fixtures selected historical Direct rows and failed assumptions |
| Staging execution timing | Direct PostgreSQL client succeeded; samples above |
| Production schema/app deployment | Not performed |

## Release boundary and next measurements

1. Form a clean, reviewable candidate that separates these changes from the
   pre-existing dirty startup/profile work.
2. Deploy the staging-bound web client so the commercial channel/RPC reduction
   can be observed end to end.
3. Capture a fixed staging window: REST requests, Realtime messages,
   subscription writes, chat list RPCs, delivery RPCs, CPU, memory and egress.
4. Run named Admin, Procurement, Project Engineer and Site Engineer smoke flows
   for chat receipt/read behavior and commercial revoke/purge behavior.
5. Promote the migration and app together only after the staged counters fall
   and all authorization cases remain green. Then repeat the same fixed-window
   production measurement; do not use cumulative totals as the after result.

The backward-compatible database slice can be released independently of the
app: old clients ignore the added JSON key and benefit from the single
projection. App publication must not overwrite uncommitted startup work already
present in the deployed application. A clean candidate is being verified at
`codex/performance-refresh-20260903`, based on GitHub `f37ee8a`, with only the
review-owned files copied in. Main and all unrelated work remain untouched.
