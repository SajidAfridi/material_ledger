# Web notification reliability candidate — 30 September 2026

Status: **incomplete, local candidate; not approved for deployment or transport restart**.

Branch: `codex/web-notification-reliability`, based on
`b86ff4362cde5c214aaff2906c05b0adac258074`.
The primary checkout and its unrelated work were preserved.

This implements part of the 30 September notification audit, prioritizing the
website and installed PWA. No migration, Edge deployment, web promotion,
transport restart, backlog replay, or live test notification was performed in
this implementation run. The designated Owner/Chrome-on-Mac probe remains
authorized but unexecuted. Do not store account credentials in this document.

## Implemented candidate

- Protected paginated history RPC with stable timestamp/ID cursors, independent
  unread totals, search/filter parameters, and authorized request/project labels.
  Chat attention records are separate from the workflow inbox and its count.
- Preserved validated internal destinations through sign-in, password changes,
  and router reconstruction; unsafe return locations are rejected.
- Bounded registration waits, capability checks, session/account fencing,
  preference-aware enrollment, and silent initialization. Web enrollment records
  the authenticated session; per-device dispatch rejects a deleted/expired session.
- Notification expiry enforced at claim/submission with remaining FCM/APNs/web
  lifetimes. Preference changes no longer re-enqueue old suppressed notifications.
- Accounts/Workforce event copy generated from a shared module catalogue, with
  four in-app languages and guarded workspace destinations.
- Search, load-earlier history, stale-data feedback, date grouping, localized
  relative times, unread semantics, delivery-pause messaging, and iOS Home Screen
  guidance. Mark-read waits for the server instead of restoring an obsolete list
  after a concurrent refresh.
- Focus/lifecycle foreground guards, bounded alert history, burst grouping,
  and toast dismissal paused during hover/focus. Worker fallback clicks preserve
  unrelated open tabs and validate same-origin destinations.

These are source changes with scoped validation, not a claim of complete audit
closure or real-device delivery.

## Validation

| Check | Result |
|---|---|
| Flutter dependency resolution | Completed |
| Flutter analysis | No issues |
| Focused notification/routing suite | 72 passed |
| Full Flutter suite | 1,701 passed, 4 skipped, 275 failed |
| Local Supabase reset | Passed |
| Full database suite | 116 files, 3,325 assertions passed |
| Edge tests | 21 passed |
| Push failure classifier tests | 10 passed |
| Whitespace check | Passed |
| CI web / APK builds | Not run after stop condition |
| New staging deployment and signed-in browser flow | Not performed |
| Owner live FCM receipt and tap | Not performed |

The full Flutter suite reports failures in notification snapshots and unrelated
project, analytics, warehouse, Team Chat, and other screens. Their individual
causes have not all been established; do not label all failures pre-existing.
No unrelated goldens were regenerated. The new date headers also require
deterministic test dates before notification snapshot baselines are accepted.

Desktop (1366px) and mobile (360px) notification render outputs were inspected:
the content fits and detail actions are visible. These are Flutter test renders,
not production browser or physical-device acceptance.

Local evidence is saved at
`/Users/eapple/Downloads/yorks-notification-implementation-20260930/`:
analysis, full/focused Flutter, database reset/test and Edge logs, plus desktop
and mobile screenshots. The original audit and 74-state matrix remain at
`/Users/eapple/Downloads/yorks-notification-audit-20260930/`.

## Stop condition and remaining work

The applicable `AGENTS.md` says: **“Stop and report instead of guessing when …
tests expose an unrelated existing failure.”** Unrelated-screen failures triggered
that gate. Rollout and the live probe are held; their absence is not a request
for the user to repeat already-given deployment or probe authorization.

Before considering this candidate complete:

1. Triage the full-suite failures under an approved scope, stabilize notification
   dates, review changed notification snapshots, and run the required web/APK gates.
2. Correct the current grouped-Chat burst destination: it still points to the
   workflow inbox, which deliberately excludes Chat. Test Chat-only and mixed
   bursts. Preserve pause status while loading more history and verify pagination
   across refreshes; refresh currently resets loaded history to the first page.
3. Finish exact Accounts/Workforce record destinations. Current mappings open
   the relevant project tab/workspace. Extend catalogue coverage to all producers
   and add reproducible generation/CI checks; MR/Chat copy is still separate.
4. Complete event-specific current-access and actionable-state checks before
   delivery. The new relevance gate currently covers age, seen state, active
   profile and preferences, not every revoked entity grant or completed action.
5. Verify intent preservation through onboarding/maintenance gates, account
   changes, and deleted/denied entities. Successful-open acknowledgement currently
   checks stable routing, not confirmed entity rendering.
6. Add direct registration lifecycle fault-injection tests and worker click tests.
   Resolve durable retry of offline token cleanup, preference convergence timing,
   shared bell/history filter state, and device-language push copy.
7. Apply and validate the additive database/Edge/web candidate in staging, then
   perform the one fresh designated browser probe: durable history, provider
   acceptance, OS display, exact tap destination, and read/badge convergence.
8. Review eligible queue age before any restart, retain dead letters terminal,
   and validate bounded recovery without replaying accumulated history. Follow
   with actual browser/PWA device tests for background/closed app, offline,
   permission revocation, Focus, multiple tabs, and account switching.

Native store packaging, native installation identity and APNs readiness remain
later work per the user's web/PWA priority. No all-OS sign-off is implied.

## Data preservation and rollback

Migration `20260930140403_web_notification_reliability.sql` is additive: the new
session column is nullable; historical notifications, tokens, delivery ledgers,
and terminal outbox outcomes are retained. Existing web installations must
re-enroll to supply session binding before becoming eligible under the new gate.

Keep transport paused during rollout. Deploy compatible database, Edge, and web
code together only after the staging gate. If rollback is needed, pause dispatch
first and retain the additive schema and delivery history. Do not restore old
retry functions, broadly replay jobs, remove session checks, or drop the new RPC
while clients depend on it. Use a reviewed forward correction for database
behavior; a web rollback alone is not a transport recovery procedure.
