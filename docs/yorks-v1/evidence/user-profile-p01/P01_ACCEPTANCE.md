# My Yorks P01 acceptance evidence

Date: 5 September 2026  
Scope: canonical signed-in profile contract and protected read projection only

## Implemented contract

- `v1_get_my_yorks_profile(integer, integer)` is a self-only, `STABLE`,
  `SECURITY DEFINER` RPC granted only to `authenticated`.
- The response preserves the exact live Auth role, active account state,
  bounded effective project scopes, authoritative capability decisions and
  navigation-only action identifiers.
- The response exposes no business command, commercial value, raw Auth
  metadata, shadow candidate decision, attendance fact or HR detail.
- An optional normalized Workforce worker link remains distinct from Auth
  identity and explicitly grants no worker self-service.
- Missing operational summaries are represented as `not_projected`, never as
  fabricated zeroes.
- The Flutter decoder accepts an exact schema and rejects unknown fields,
  malformed types, stale identity/role mismatches, unsupported actions and
  unexpected authorization shapes.
- The Riverpod controller drops old evidence on session, exact identity,
  connectivity and permission-revision changes. Scheduled permission expiry
  triggers a refresh using server-relative time.

## Data preservation and rollback

The migration creates or replaces one read RPC and changes no table, row,
role default, permission assignment, Workforce record or legacy employee data.
Rollback is to revoke/drop this unused P01 RPC and remove its dormant client
consumer. Existing data and behavior are preserved.

## Verification

- Clean local Supabase reset: passed; migration ledger contains
  `20260905120000_yorks_my_profile_p01`.
- Migration repeatability: passed by reapplying with `ON_ERROR_STOP=1`.
- Focused pgTAP: 66/66 passed, covering all nine exact roles, self-only
  identity, project and Accounts separation, positive/negative/delegated/
  expired scopes, shadow parity, inactive/banned/stale/anonymous denial,
  pagination, worker-link privacy and read idempotency.
- Complete database suite: 88 files / 2,599 assertions passed on an isolated
  rerun.
- Focused Flutter tests: 40/40 passed, including all nine roles, strict decoder
  failures, repository fail-closed behavior, timeout, concurrent refresh,
  expiry and provider invalidation.
- `flutter analyze`: passed with no issues.
- Complete `flutter test`: 1,566/1,566 passed after P01 integration.
- Production-shaped web build: passed; startup budget passed
  (`main.dart.js` 9,656,233 bytes, gzip 2,618,794 bytes).
- Ephemeral-signing Android release build: passed; APK produced at
  `build/app/outputs/flutter-apk/app-release.apk` (103.7 MB). This is a CI gate,
  not a distributable production signing claim.
- `git diff --check`: passed.

## Boundary

P01 is a data and state foundation. The visible profile remains unchanged until
P02. Role-aware operational summary cards are P04; optional work identity and
language/preferences are P05. No staging or production action is part of P01.
