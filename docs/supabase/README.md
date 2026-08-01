# Backend setup — self-hosted Supabase (UAE region)

> **Historical generic-sync note.** Yorks V1 authority is now
> [`../yorks-v1/README.md`](../yorks-v1/README.md). This document and its
> `schema.sql` preserve the pre-V1 JSONB generation as migration evidence;
> they are not the source of truth for Yorks V1 behavior, security or rollout.
> For a new local environment use tracked `supabase/config.toml`, the ordered
> `supabase/migrations/` chain and `supabase/seed.sql`. Do not manually apply
> this historical schema file.

Because data must reside on **UAE soil**, the backend is **self-hosted Supabase /
Postgres** in a UAE region (AWS `me-central-1` Dubai, or Azure UAE North). Managed
Supabase Cloud has no UAE region, and Firebase can't self-host — so this is the path.

The Flutter app talks to a self-hosted instance exactly like a managed one; you only
change the URL.

## What's wired (Phase 1 — data writes)

- **`SupabaseSyncBackend`** ([lib/shared/sync/supabase_sync_backend.dart](../../lib/shared/sync/supabase_sync_backend.dart))
  implements the existing `SyncBackend` seam: every queued `MutationOp` becomes an
  idempotent UPSERT `{id, data, updated_at}` into the `<collection>` table, keyed on the
  client-generated `docId` (a resend overwrites the same row — never a duplicate).
- **Config-gated** in [lib/main.dart](../../lib/main.dart): the app uses the backend only
  when both `SUPABASE_URL` and `SUPABASE_ANON_KEY` are supplied at build time; otherwise it
  stays on the local sync backend (fully offline, unchanged). So nothing breaks before the
  server exists.
- **Error contract**: RLS/permission (`42xxx`), integrity (`23xxx`) and bad-data (`22xxx`)
  failures are **permanent** (dead-lettered + surfaced with Retry); timeouts, network, 5xx,
  token refresh are **transient** (retried with backoff). The outbox is unchanged.

## Deploy steps

1. **Provision** a self-hosted Supabase stack in a UAE region (Docker compose / your IaC).
2. **Run the schema and migrations**: apply [`schema.sql`](schema.sql) once
   (tables, generated columns, reporting views and helper functions), then
   apply tracked `supabase/migrations/*.sql` in timestamp order. Batch 6's
   self-contained migrations add, secure and seed the material masters. Batch
   8 adds the normalized Phase 1 plan/version/line/comment/activity projection,
   workflow guards and atomic project activation.
3. **Seed** existing data once, server-side with the `service_role` key (see the import
   block at the bottom of `schema.sql`). Never put `service_role` in the app.
4. **Point the app at it** (only after Phase 2 below — see the warning):
   ```
   flutter build apk \
     --dart-define=SUPABASE_URL=https://your-uae-host \
     --dart-define=SUPABASE_ANON_KEY=your-anon-key \
     --dart-define=SENTRY_DSN=...   # optional
   ```

## ⚠️ Phase 2 (Auth) is required before going live

RLS in `schema.sql` enforces the app's role × capability model from the JWT
(`app_metadata.role` + `app_metadata.caps[]`). Until **Phase 2 (Firebase-style Supabase
Auth + a claim-provisioning step that computes each user's effective caps via the same
`resolveCapability` logic)** is wired, signed-in users have no role/caps claim and
**authenticated writes are denied by design**. So:

- **Do not set `SUPABASE_URL` in production app builds until Phase 2 lands** — otherwise
  every write RLS-fails and dead-letters.
- Phase 2 scope (next): swap `AuthController.signIn` for Supabase Auth (UI unchanged);
  `currentRoleProvider` reads the role claim; a server function sets `role` + `caps` on
  user create/update; port per-user overrides into the caps claim.
- Phase 3: realtime/refresh reads into the repositories (true multi-device), and push.

## Phase 1 boundaries (by design — verified in adversarial review)

- **Writes only.** `apply()` upserts to the server; reads still come from the local cache.
  **Multi-device sync + realtime are Phase 2** (a `refresh()`/subscription path).
- **Stock/inventory is device-local and not synced** (no `inventory` collection in the seam).
  Two devices can diverge on reserved/available quantities until Phase 2 adds an inventory
  collection (or computes stock server-side from request/receipt deltas).
- **`isTransactional` is a no-op in Phase 1, and that's safe**: every op carries one
  collection's *absolute snapshot*, so the upsert-by-`id` is genuinely idempotent on resend —
  there is no multi-table server state to corrupt.

## Before go-live — Phase 2 must-dos (from the review)

1. **Auth + claims (the gate).** Wire Supabase Auth; a server function must set
   `app_metadata.role` + `app_metadata.caps[]` (computed with the same `resolveCapability`
   logic) so RLS passes. Until then, **keep `SUPABASE_URL` unset** (else writes RLS-fail and
   dead-letter en masse).
2. **Identity model — decide before any auth work.** RLS owner-checks compare
   `data->>'engineerId'` / `data->>'requestedByUserId'` to `auth.uid()`, but the app's
   `AppUser.id` ("usr-…") is **not** a Supabase UUID. **Recommended:** make the Supabase
   account the source of identity — on user creation use the Supabase `auth.uid()` as the
   `AppUser.id` going forward, and migrate existing ids during the one-time import. (Already
   done in Phase 1: `materialRequests` now stamps `engineerId`, and `leaveRecords` stamps
   `requestedByUserId` — so the owner fields are populated and ready.)
3. **Keep at least one admin.** Demoting the last admin bricks writes to `config` (admin-only
   RLS); recover via the `service_role` key. Don't expose `service_role` to the app.
4. **Field-level secrets** (cost/salary/finance) aren't enforced by table RLS — add a
   write-trigger that strips secret fields when the caller lacks the cap, if you ever allow
   writes outside the app seam.

## Why jsonb (not fully relational) in Phase 1

Each collection is `{id, data jsonb}` so the generic adapter handles every collection with
no per-model server code, and the app's snapshot writes map 1:1 (idempotent). You still get
SQL: **generated columns + views** (`v_rent_roll`, `v_rent_outstanding`, `v_leave_taken`)
read straight from `data`, so rent-roll/overdue/leave-balance are real SQL — the reason we
chose Postgres. Promote hot fields to proper relational columns later without touching the
app.
