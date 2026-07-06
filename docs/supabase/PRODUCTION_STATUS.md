# Production auth + RLS — status & runbook

_Applied to the current managed project `czykuksmlwswjsgotrpo` (Frankfurt).
Data residency is NOT yet UAE — see "Remaining" below._

## What is now live and verified

### 1. Real authentication (Supabase Auth)
Three admin-provisioned accounts exist in **Supabase Auth** (email + password,
email confirmed). There is **no self-signup** — the app has no signup UI, and
these were created server-side.

| Email | Password | Role | `app_user_id` |
|-------|----------|------|---------------|
| owner@gmail.com | test@123 | admin | usr-admin |
| alasad@gmail.com | test@123 | procurement | usr-proc |
| imrankhan@gmail.com | test@123 | engineer | usr-eng |

Each user's `raw_app_meta_data` carries `role`, `caps[]`, and `app_user_id`.
Supabase embeds `app_metadata` into every JWT automatically, so **no custom
access-token hook is required**. Verified by a live password-grant call — the
engineer token returns
`app_metadata = {app_user_id: usr-eng, caps: [], role: engineer}`.

### 2. Strict, claim-based RLS (replaced the permissive demo policies)
Helper functions read the JWT: `app_role()`, `app_user_id()`, `app_has_cap()`
(all `search_path`-pinned). Policies on the 9 sync-backed tables:

- **rentalUnits / rentPayments** — read `rentals`, write `writeRentals`
- **employees / attendance** — read `people`, write `writePeople`
- **leaveRecords** — `approveLeave` OR owner (`requestedByUserId = app_user_id`)
- **materialRequests** — `goods` OR owner (`engineerId = app_user_id`)
- **goodsReceipts / returns** — `goods`
- **config** — admin only

All other tables (`users, projects, materials, materialPlans, notifications,
auditLogs`) are **deny-all** (RLS on, no policy) — intentional: the app never
reads/writes them over the API (they're local, deterministic seeds). The
`rls_enabled_no_policy` advisor INFO on those is expected.

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
the active owner session): sign in as **imrankhan@gmail.com / test@123** and
confirm the engineer sees only their own requests; **alasad@gmail.com** sees
rentals + people + leave.

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

- The 8 write-synced tables are in the `supabase_realtime` publication (with
  `replica identity full`). `RealtimeSync` subscribes to Postgres changes per
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

## Remaining for full production (owner in brackets)
1. **UAE data residency** — this project is in Frankfurt. A real go-live needs a
   self-hosted Supabase/Postgres in a UAE region; point the app at it with
   `--dart-define=SUPABASE_URL/KEY`. [**You**]
2. **Change-password → Supabase** — `change_password_screen` updates the local
   hash, not Supabase Auth; wire it to the `admin-users` `setPassword` action (or
   `auth.updateUser` for self-service). (No seeded user forces a change, so
   unused today.) [Me, next]
3. **Role-matrix → claims propagation** — per-user overrides re-stamp the JWT
   claim, but an admin editing a *role-level* default (Access & Roles) does not
   yet re-push claims for every user of that role. [Me, next]
4. **Sync tail cases** — realtime covers online propagation; a delete that
   happens while a device is offline still needs a reconcile-on-reconnect pass
   (tombstones / full re-hydrate diff). [Me, later]
5. **Auth dashboard toggles** — turn OFF "Allow new signups" and turn ON "Leaked
   password protection" (HaveIBeenPwned) in Auth settings. [**You**, 2 clicks]
6. **Secrets** — inject `SUPABASE_URL/KEY` + `SENTRY_DSN` from CI/secret store,
   not source. [**You** + me]
7. **PDPL/legal, backups/DR, APNs cert (iOS push)**. [**You**]
