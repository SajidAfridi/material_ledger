# Production auth + RLS — status & runbook

_Applied to the current managed project `czykuksmlwswjsgotrpo` (Frankfurt).
Data residency is NOT yet UAE — see "Remaining" below._

## What is now live and verified

### 1. Real authentication (Supabase Auth)
Three admin-provisioned accounts exist in **Supabase Auth** (email + password,
email confirmed). There is **no self-signup** — the app has no signup UI, and
these were created server-side. Passwords are intentionally excluded from this
repository. Retrieve or rotate credentials through the approved secure channel.

| Email | Role | `app_user_id` |
|-------|------|---------------|
| owner@gmail.com | admin | usr-admin |
| engineer@gmail.com | engineer | usr-842c4097 |
| procurement@gmail.com | procurement | usr-a5a3776a |

Each user's `raw_app_meta_data` carries `role`, `caps[]`, and `app_user_id`.
Supabase embeds `app_metadata` into every JWT automatically, so **no custom
access-token hook is required**.

> Current-claim note (24 July 2026): Admin corrected the existing
> `procurement@gmail.com` identity from Engineer to Procurement. Its stable
> `app_user_id` remains `usr-a5a3776a`; the canonical Procurement capability
> set includes `viewCommercials` and `goods`. The user must sign in again (or
> otherwise refresh the Auth session) before persona testing so the client JWT
> contains the updated claims.

### 2. Strict, claim-based RLS (replaced the permissive demo policies)
Helper functions read the JWT: `app_role()`, `app_user_id()`, `app_has_cap()`
(all `search_path`-pinned). Policies on the 9 sync-backed tables:

- **rentalUnits / rentPayments** — read `rentals`, write `writeRentals`
- **employees / attendance** — read `people`, write `writePeople`
- **leaveRecords** — `approveLeave` OR owner (`requestedByUserId = app_user_id`)
- **materialRequests** — `goods` OR owner (`engineerId = app_user_id`)
- **goodsReceipts / returns** — `goods`
- **config** — admin only

`users` and `auditLogs` are **deny-all** (RLS on, no policy) — intentional:
the app never reads/writes them over the API (local-only by design). The
`rls_enabled_no_policy` advisor INFO on those is expected.

`materials`, `notifications`, `projects`, and `materialPlans` are now
write-synced too (this section undersold that when first written — see
"Projects + material plans sync" below for the two most recently added).

### 2A. Protected commercial values — live

Batch 2 moved material unit cost, goods-receipt cost and project contract value
out of shared operational JSON into `commercial_records`. RLS requires
`viewCommercials` to read and additionally Admin/`goods` to write. Recursive
database triggers strip commercial keys from all Materials/Projects planning
and request payloads even if a client bypasses the Flutter serializers.

The live migration moved 56 material costs, left zero commercial keys in the
five guarded operational tables and passed the positive/negative RLS matrix in
rolled-back transactions. `admin-users` active version 2 emits
`viewCommercials`; the legacy `cost` claim is accepted during migration.
Implementation, verification and rollback details are in
`docs/nexus-v7/PR-02_SECURE_COMMERCIAL_DATA.md`.

### 2B. Material category and unit masters — live

Batch 6 added `materialCategories` and `materialUnits` as synced JSONB
collections with explicit PostgREST grants, realtime identity and RLS.
Provisioned app users may read the masters. Category writes are Admin-only.
Admin may create/approve/archive units; Procurement may create or replay only a
custom `pendingReview` unit and cannot approve it.

The live migration and follow-up single-policy optimization are:

- `20260724090000_batch6_material_masters`
- `20260724091000_batch6_combine_unit_update_policy`
- `20260724092000_batch6_seed_master_defaults`

Live simulated-JWT checks verified Admin creation, Engineer read plus denied
write, Procurement pending-unit creation/replay plus denied self-approval, and
cleanup of all test rows. The security advisor reported no new Batch 6 issue;
the performance advisor reports the two new GIN indexes as unused immediately
after creation, which is expected until production queries accrue. Full details
are in `docs/nexus-v7/PR-06_DYNAMIC_MASTERS_BROWSE.md`.

The insert-only defaults migration left the live project with 8 categories and
18 units: 8 approved Yorks defaults plus 10 distinct pending legacy units.
Commercial-key scan result: zero rows.

### 3. Boundary verification (headless, via simulated + real JWTs)
| persona | requests | rentals | employees | leave | receipts |
|---|---|---|---|---|---|
| engineer | 2 (own only) | 0 | 0 | 0 | 0 |
| procurement | 12 | 3 | 5 | 5 | 6 |
| admin | 12 | 3 | 5 | 5 | 6 |
| anon (old app access) | **0** | 0 | 0 | 0 | 0 |

Writes: engineer can write their own request; **denied** when forging another's
`engineerId`, writing rentals, or writing as anon (RLS `42501`).

### 4. App wiring
- `AuthController.signIn` → Supabase Auth when configured (authoritative, **no**
  local-password fallback); local store only when Supabase is unconfigured
  (widget tests / offline dev).
- Launch: hydrate only when a real session is restored; if none, the stale local
  session is cleared so the app opens at login (no "ghost" signed-in state).
- Post-login: data is pulled with the user's JWT (RLS returns exactly their rows).
- `flutter analyze` clean; **167 tests pass**.

## Behaviour changes to know
- **Login is now server-side.** In debug the app points at this Frankfurt
  project, so login needs network + one of the accounts above. (Pure-offline dev
  now needs the app built with no `SUPABASE_URL`.)
- Writes only succeed while signed in with a valid session (by design).

## Device verification — DONE (iPhone 17 Pro simulator)
- Hardened build compiles, launches, `Supabase init completed`, no runtime errors.
- A **real on-device Flutter login** produced a valid persisted session
  (`sb-czykuksmlwswjsgotrpo-auth-token`): `owner@gmail.com`, claims
  `{app_user_id: usr-admin, role: admin, caps:[…]}`, and it was correctly
  restored on relaunch (session present → stayed signed in; no ghost state).
- Confirms the full chain on device: Flutter `signInWithPassword` → JWT with the
  right `app_metadata` → the same claims RLS was proven against.

Still worth an eyeball when convenient (not yet watched live, to avoid disrupting
the active owner session): use securely supplied credentials to sign in as the
engineer and confirm they see only their own requests; the procurement account
should see rentals + people + leave.

## EMERGENCY ROLLBACK (restore the permissive demo, if needed)
```sql
-- 1) drop every policy in the public schema
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname='public' loop
    execute format('drop policy if exists %I on %I;', r.policyname, r.tablename);
  end loop;
end $$;
-- 2) recreate the open demo policy on every app table
do $$
declare t text;
begin
  foreach t in array array['materialRequests','goodsReceipts','returns',
    'rentalUnits','rentPayments','employees','attendance','leaveRecords',
    'config','users','projects','materials','materialPlans','notifications',
    'auditLogs'] loop
    execute format($f$create policy %I on %I for all using (true) with check (true);$f$,
                   t || '_all', t);
  end loop;
end $$;
```
(The auth users can be left in place; they are harmless under permissive RLS.
You would also need to relax the app so it can read without a session again —
simplest is to sign in normally, since the accounts still work.)

## Admin user-provisioning — LIVE (Edge Function `admin-users`)
Creating/administering users beyond the 3 seeds is done. The client can't hold
the service_role key, so all identity-provider writes go through the
`admin-users` Edge Function (`supabase/functions/admin-users/index.ts`,
`verify_jwt = true`), which additionally checks the caller's
`app_metadata.role == 'admin'` before using the service_role key.

- Actions: `create`, `updateClaims` (role/caps), `setPassword`, `setActive`
  (ban/unban), `delete`. Users are keyed by the stable `app_user_id`; the
  function resolves that → auth UUID, so the app never stores the UUID.
- App wiring (`UsersNotifier`): create / setRole / setActive / setPassword /
  delete / per-user override all call the function first (remote-first; local
  roster only updates on success), then fall back to local-only when Supabase is
  unconfigured (tests/offline). New caps are recomputed and re-stamped into the
  JWT claim so RLS tracks role/override changes.
- Cross-device: a user provisioned on the admin's device is materialised from
  their JWT claims on first login elsewhere (`upsertFromClaims`).
- **Verified end-to-end** (curl): non-admin caller → 403; admin creates a user →
  the new user logs in with correct claims; deactivate → login "User is banned";
  delete → login "Invalid login credentials".

## Realtime sync — LIVE (`lib/shared/sync/realtime_sync.dart`)
Writes on one device now appear on others without a relaunch.

- Every write-synced table (13, as of the projects/materialPlans addition
  below) is in the `supabase_realtime` publication (with `replica identity
  full`). `RealtimeSync` subscribes to Postgres changes per
  table while signed in (`realtimeSyncProvider`, watched at the app root; no-op
  offline / logged-out / in tests), merges each change into the local store, and
  refreshes that collection's provider.
- **Critical**: the socket must carry the user's JWT (`realtime.setAuth`) before
  subscribing, else strict RLS treats it as anon and delivers nothing — the
  service sets it and re-sets on token refresh.
- **Data-loss fix**: launch/re-login hydration now *union-merges* cloud into
  local (`SupabaseBootstrap.mergeRows`, unit-tested) — a local-only offline
  create is preserved instead of overwritten.
- **Verified** (node, live against the project): with `setAuth`, an engineer
  receives their own insert; an admin-inserted row for the engineer arrives while
  a row for *another* user does **not** — realtime honours RLS. Delivery fails
  without `setAuth` (confirmed), which is why the app sets it explicitly.

## Projects + material plans sync — LIVE
Both were local/in-memory-only until now — `projects` had **zero** persistence
of any kind (not even `SharedPreferences`; every project vanished on app
restart), and `materialPlans` persisted locally but never synced. Procurement's
whole "accept a new project" and "review a Phase-1 plan" workflows depend on
these, so they're now on the same footing as every other collection:

- `ProjectsNotifier`/`MaterialPlansNotifier` are `CollectionStore`-backed and
  call `enqueueSync` on every write (create/update/delete/accept/activate/
  complete for projects; upsert/approve/reject/comment/item-status/mark-done
  for plans).
- **Soft delete**: the outbox only ever upserts (no SQL `DELETE` path exists
  anywhere in the sync engine), so a physical local removal would resurrect
  the row on the next hydration. Both models gained a `deleted` bool instead —
  deleting flips it, syncs that, then drops it from local state; every
  device's own load path filters `deleted` rows out, so the row still
  physically exists as a tombstone in the cloud table but never surfaces
  anywhere in the app.
- **RLS**: `projects` — an engineer reads/writes their own (`assignedEngineerId`)
  + reads (not writes) any unassigned job; `goods` cap reads/writes all.
  `materialPlans` has no owner field of its own (one per project), so its
  policy is the same rule via a correlated `EXISTS` against `projects`.
- **A real bug was caught by the verification step, not assumed away**: the
  first version of the "unassigned project" read clause (`assignedEngineerId
  IS NULL`) checked only the row, never the caller — so a fully anonymous,
  unauthenticated request also matched it. Fixed by requiring `app_user_id()
  <> ''` before that branch applies; re-verified anon → 0 rows, engineer →
  own + unassigned only, procurement/admin → all, writes to another's project
  → 0 rows affected (not an error), reassigning your own project away from
  yourself → rejected (`42501`).
- Contract value (`contractValueAED`) gets the same treatment as employee
  salary: stripped from the synced payload, preserved from the local record on
  hydration/realtime-merge — it never rides in a payload every `goods`-cap
  role (procurement included) can read.
- **One-time consequence, not a bug**: since projects/plans had no persistence
  before this, anything created purely in-session prior to this deploy was
  never actually saved anywhere and won't appear after the first restart.

## Batch 8 normalized Phase 1 workflow — LIVE

The generic `materialPlans` outbox remains backward compatible, but every
accepted snapshot is now transition-validated and projected into normalized
plan, immutable version, line, comment and activity tables. Reads use explicit
grants plus project-scoped RLS. Phase 1 payloads containing stock allocation or
reservation fields are rejected.

Engineer, Procurement and Admin transition rules were verified with simulated
JWT claims. Final Engineering approval activates the linked project inside the
same transaction; direct project activation without an approved Phase 1 plan is
rejected. Both Batch 8 migrations are recorded in Supabase migration history.

## Push notifications — plumbing DONE, needs your credentials to activate
FCM as pure push TRANSPORT (Supabase stays the backend/auth/db). Structured as
a swappable seam like every other optional integration in this app (Sentry,
Supabase): `PushService` interface, `NoopPushService` default,
`FcmPushService` the real implementation — activates automatically the moment
Firebase is configured, no further app-code changes needed.

**Foundational fix, done first**: `notifications` was local-only per device (no
`enqueueSync` call at all) — a notification created on one phone for another
user's account never reached that user's actual device; it only "worked" when
testing by switching accounts on the same phone. Now synced (RLS: a personal
notification is readable only by its target user or admin; a broadcast/
role-audience one is readable by anyone signed in — the app already filters by
role client-side).

**What's built and verified:**
- `notifications` + `device_tokens` tables, RLS, realtime — all live-verified via
  simulated JWTs (engineer sees their own + broadcasts, not another user's
  personal one; even admin can't `SELECT` `device_tokens`, only `service_role`
  can via the Edge Function).
- `supabase/functions/send-push` — looks up target `app_user_id`s' tokens and
  calls FCM HTTP v1 using a Google service-account OAuth2 exchange (dependency-
  free, Deno WebCrypto). Auth-gated (any signed-in user), then config-gated
  (responds `501` with no `FCM_SERVICE_ACCOUNT_JSON` secret set — never breaks
  the caller's flow). Verified via curl: 401 unauthenticated, 501 unconfigured.
- Flutter client (`push_service.dart`): permission request, background handler,
  foreground local-notification display, tap → deep-link (reusing the existing
  `route` field, via the same "read the current router from Riverpod" pattern
  `hardwareActionProvider` already used), device-token registration + refresh.
  Every step wrapped so a missing Firebase config is a silent no-op, never a
  crash — **verified live**: relaunched on the iPhone 17 Pro simulator, saw
  `Firebase.initializeApp()` throw `core/not-initialized` and get caught
  cleanly, app kept running normally.
- Wired into the single `notificationsProvider.add()` seam (not touched at each
  of the ~10 existing call sites): resolves the notification's `audience`/
  `userId` into concrete `app_user_id`s (`resolvePushTargets`, unit-tested),
  excludes the acting user, calls `send-push`. Best-effort — a push failure
  never breaks the in-app/synced notification.
- iOS: deployment target raised 13.0→15.0 (`firebase_messaging` requires it —
  found via a real failed build, not guessed), `Runner.entitlements`
  (`aps-environment: development`) + `UIBackgroundModes: remote-notification`
  wired into all 3 build configs. Verified: `pod install` + full simulator
  relaunch succeeded after each change.
- Android: **deliberately untouched.** The `google-services` Gradle plugin
  hard-fails the whole build if `google-services.json` is absent — applying it
  now would break `flutter run`/`build` on Android immediately. Wire it only
  once the file exists (see below).

**To actually go live, you need to:**
1. Create a Firebase project (free) — Cloud Messaging only, nothing else.
2. Download `google-services.json` → `android/app/`, apply the
   `com.google.gms.google-services` Gradle plugin (only then — see above).
3. Download `GoogleService-Info.plist` → `ios/Runner/` (add to the Xcode
   project).
4. Apple Developer Program membership → generate an APNs auth key (.p8),
   upload it to the Firebase project's Cloud Messaging settings.
5. Generate a Firebase service-account key (Project Settings → Service
   Accounts) → set its JSON as the `FCM_SERVICE_ACCOUNT_JSON` secret on the
   `send-push` Edge Function.
6. In Xcode, Signing & Capabilities → confirm "Push Notifications" + "Background
   Modes → Remote notifications" are checked against your real Team/provisioning
   (the entitlements file is staged; your Team must actually grant the
   capability).

Until then: the app behaves exactly as it does today — in-app notifications
work fully (now correctly synced across devices), push simply stays off.

## Remaining for full production (owner in brackets)
1. **UAE data residency** — this project is in Frankfurt. A real go-live needs a
   self-hosted Supabase/Postgres in a UAE region; point the app at it with
   `--dart-define=SUPABASE_URL/KEY`. [**You**]
2. ~~Change-password → Supabase~~ — **DONE.** `AuthController.changeOwnPassword`
   calls `client.auth.updateUser(...)` directly (verified in
   `session_provider.dart`) — self-service password changes hit Supabase Auth,
   not a local hash. The cross-device forced-password-change gap noted earlier
   is also fixed (see git history for that session's work).
3. ~~Role-matrix → claims propagation~~ — **DONE.** `restampRoleClaims` fires
   from `role_permissions_provider.dart` on every matrix edit, re-stamping the
   JWT for every affected user.
4. ~~Sync tail cases~~ — **DONE.** Every collection that supports deletion now
   uses the soft-delete/tombstone pattern (flip `deleted:true`, sync the flip as
   an upsert, drop it from local `state`, filter `!deleted` at load time) —
   `projects`, `materialPlans`, `materials`, `materialRequests`. This closes the
   exact gap this item described: a delete that happens offline queues in the
   outbox like any other write and flushes on reconnect (already covered by the
   existing offline-queue tests), and the tombstone reaches every other device
   via realtime or the next bootstrap re-hydration diff — no separate
   reconcile-on-reconnect pass needed since deletes are just upserts now. A full
   sweep of every `state.where(...)`/`removeWhere(...)` mutation across
   `lib/shared/providers/` (not just these 4 collections) confirmed no other
   collection has a live physical-removal-without-sync bug — the remaining hits
   are either pure read-filters, intentionally local-only (notification
   `dismiss`), or already backed by an external source of truth that's updated
   first (`UsersNotifier.deleteUser` via the service-role Edge Function, before
   the local cache follows). See [[materials-and-requests-soft-delete]].
5. **Auth dashboard toggles** — confirmed via `get_advisors` (not just
   assumed): "Leaked password protection" is currently **OFF**
   (`auth_leaked_password_protection` WARN). No tool available to me — Supabase
   MCP or otherwise — can read or write Auth platform config (signups toggle,
   password policy); this is genuinely dashboard-only. Turn it on at
   **Authentication → Policies → Password** (or **Auth settings**, depending on
   dashboard version) for project `czykuksmlwswjsgotrpo`, and confirm "Allow new
   signups" is off in the same area (the app has no signup UI regardless, so
   this is defense-in-depth, not a functional gap today). [**You**, 2 clicks]
6. **Secrets** — inject `SUPABASE_URL/KEY` + `SENTRY_DSN` from CI/secret store,
   not source. Current state is already sound as an interim measure: `main.dart`
   reads them via `String.fromEnvironment` (dart-define) with a hardcoded
   fallback that's the Frankfurt demo project's anon/publishable key (safe by
   design — protected by RLS, not secrecy) and is gated to `!kReleaseMode`, so it
   can never ship in a release build. There is **no CI configuration in this
   repo yet** (confirmed — no `.github/workflows`, no `codemagic.yaml`, nothing)
   — pick a CI provider before this item is actionable; "inject from CI" has
   nowhere to live until then. [**You** + me]
7. **PDPL/legal** — no tooling can assess legal/regulatory compliance; needs a
   human/counsel review. [**You**]
8. **Backups/DR** — confirmed via `get_organization`: this project is on the
   **Free** plan. Per current Supabase docs, Free-tier projects get **zero**
   automatic backups of any kind (daily backups start at Pro; PITR is a further
   paid add-on on top of Pro/Team) — right now, a lost/corrupted database has
   **no managed recovery path at all**. Supabase's own recommendation for Free
   tier: run `supabase db dump` on a schedule and store the dump somewhere safe
   (e.g. a private bucket) until upgrading. Upgrading to Pro ($25/mo at time of
   writing) turns on 7 days of automatic daily backups; PITR is an additional
   paid add-on on top of that if point-in-time recovery (not just daily
   snapshots) is required. This is a billing decision only you can make.
   [**You**]

### Found + fixed during this pass (not on the original list)
- **`notifications` RLS was more permissive than intended.** The read policy
  only checked whether `userId` was empty, never checking `audience` — so a
  role-scoped notification (e.g. `audience: 'procurement'`) was readable by
  *any* signed-in user of *any* role, not just procurement/admin. Verified
  empirically with a simulated engineer JWT before fixing (it could read a
  procurement-only row), then re-verified the full persona matrix after
  (engineer/procurement/target-user/admin/anon all scoped correctly). The
  insert/update policies were also `using(true) with check(true)` — any
  authenticated user could rewrite or mark-read *any* notification, including
  ones addressed to someone else. Fixed live via the `tighten_notifications_rls`
  migration (new `notification_visible_to_caller()` helper mirrors
  `notificationVisibleTo()` in `notification_provider.dart` exactly) and
  backported into `schema.sql` so a from-scratch deploy doesn't reintroduce it.
  Residual, accepted limitation: INSERT has no sender-identity field to check
  ownership against (any role can legitimately notify any other role/user in
  this app's design), so it only requires a genuinely provisioned app identity
  (`app_user_id() <> ''`) rather than fully closing "user A can forge a
  notification claiming to target user B" — closing that fully would need a
  schema change (a tracked sender field) that wasn't part of this fix.
- Ran a full security + performance advisor pass (`get_advisors`). Beyond the
  notifications fix above, everything else is either already-intentional
  (`users`/`auditLogs` deny-all) or pre-existing/cosmetic performance notes
  (2 unused indexes, several "multiple permissive policies" pairs from writing
  separate read+write policies on a handful of tables — harmless, not worth
  restructuring at this scale) — not blocking, left as-is.

## Push notifications — app-side DONE, needs your credentials to go live
See "Push notifications" section below for the full breakdown. Short version:
all Dart + Supabase-side plumbing is built, deployed, and verified (device-token
registration, RLS, the `send-push` Edge Function, FCM client wiring, iOS
entitlements) — but it stays silently inactive until you provide a Firebase
project (free) + an Apple Developer Program push key. **[You]**
