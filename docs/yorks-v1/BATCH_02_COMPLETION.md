# Yorks V1 R35 — Batch 2 Completion

> **HISTORICAL BATCH EVIDENCE — NOT CURRENT BUILD CONFIGURATION.** Read the
> canonical build section in `README.md` and `TERRA.md` for current defaults.

Status: **passed** on 1 August 2026.

## Delivered

- Exact four-role identity foundation, protected profiles, capability defaults
  and dated project membership history.
- Five-stage R35 project creation with Common/All Buildings scope, physical
  buildings, 29 server-materialized BOQ groups, audit history and idempotent
  creation.
- Auth-admin commands require a stable UUID idempotency key and an opaque
  server HMAC request hash. Replays are true no-ops; a reused key with a
  different request is rejected before mutation.
- Historical/noncanonical identity reconciliation is atomic and auditable.
- Commercial access is fail-closed: live active identity, exact canonical role
  and protected capabilities are all required. Stale, banned and noncanonical
  legacy JWTs cannot use the legacy compatibility path.
- Yorks R35 public branding is applied to Flutter, Android and web. Android
  package identity is `com.yorks.app`.
- Local Supabase email/password sign-in is enabled for deterministic seed
  personas while global self-sign-up remains disabled.

## Verification

- `flutter analyze` — passed.
- `flutter test` — 417 passed.
- `flutter build web --release` with CI placeholder backend values — passed.
- `CI=true YORKS_CI_EPHEMERAL_SIGNING=true flutter build apk --release` with
  CI placeholder backend values — passed.
- `supabase db reset --local` and `supabase test db --local` — 167 pgTAP tests
  across 5 files passed.
- Admin Edge Function Deno tests — 13 passed; type check passed.
- Independent integration repros passed for replay after a newer account
  command, generic identity mapping and stale/banned/noncanonical legacy RLS.
- Browser evidence: signed-in Project Engineer dashboard and the R35 project
  creation flow render on mobile and desktop local web viewports.

## Migration and rollback

The migration is additive and preserves legacy identity/project data through
reconciliation rather than reinterpretation. Roll back by disabling the Batch
2 feature flags; retain normalized records and append-only audit history.

## Known limitation

Admin retry keys persist for the active sheet/session. A manual retry after an
app restart is a new command; the server still validates and audits it.

## Next dependency

Batch 3 implements editable BOQ groups and the responsive spreadsheet without
weakening the Batch 2 identity, project or commercial-access boundaries.
