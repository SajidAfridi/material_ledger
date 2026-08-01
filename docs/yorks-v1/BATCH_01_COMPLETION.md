# Yorks V1 R35 — Batch 1 Delivery Record

Implementation delivered: 1 August 2026
Acceptance state: **passed — 1 August 2026**

## Outcome

Batch 1 makes the V1 foundation reproducible and inactive by default. It adds
no normalized V1 workflow table, route or screen, and it does not alter the
legacy Flutter runtime behavior. Every Yorks V1 rollout flag remains false
unless explicitly enabled with the complete dependency chain.

## Delivered foundation

- A tracked [`supabase/config.toml`](../../supabase/config.toml), ordered
  prerequisite migration and deterministic local-only four-role seed.
- An additive legacy collection baseline that records the generic JSON tables,
  legacy JWT helpers, RLS, reporting views and Realtime prerequisites which
  earlier tracked migrations assumed were already present.
- pgTAP proof for the clean local baseline and a self-contained commercial RLS
  fixture, so database tests do not depend on accidental production/demo data.
- Independent `YorksV1FeatureFlags` / Riverpod provider with the approved
  Foundation → Projects → BOQ → Excel → Requests → Arrangement → Logistics →
  Returns/Documents fail-closed dependency chain. Existing Nexus flags cannot
  enable it.
- Android main-manifest Internet permission, unrestricted PWA orientation, and
  release signing that rejects a missing/invalid production keystore.
- A CI-only, non-publishable **Yorks CI Ephemeral** signing lane. Production
  signing material is ignored and cannot fall back to the Android debug key.
- GitHub Actions jobs for formatting/analyze/tests/web, clean local Supabase
  startup/reset/pgTAP, and release APK assembly/signature verification.
- A confirmed [`com.yorks.app` Android application identity](ANDROID_APPLICATION_ID_DECISION.md)
  aligned across Gradle namespace, application ID and Kotlin entry point.

## Migration and data posture

`20260724000000_legacy_collection_prerequisites.sql` is additive and exists so
a fresh local instance can replay the legacy migration history. It does not
create V1 normalized workflow records or seed business data.

The migration is intentionally backdated before previously tracked V7
migrations. Do **not** link or deploy it to a live environment blindly. First
compare `supabase_migrations.schema_migrations`, relation spellings and target
PostgreSQL version in staging; use `supabase db push --dry-run` and an explicit
migration-history review. No production credentials, database, signing key or
data were accessed in Batch 1.

## Verification

| Check | Result |
|---|---|
| `flutter pub get` | Passed |
| Dart format for changed Dart files | Passed; no formatting changes required |
| `flutter analyze` | Passed with no issues |
| `flutter test` | Passed, 357 tests |
| release web build with CI Supabase placeholders | Passed |
| CI-lane release APK build | Passed, 70 MB |
| APK signature | Verified as `CN=Yorks CI Ephemeral`; APK Signature Scheme v2 valid; not debug signed |
| APK package/permission inspection | Passed: `com.yorks.app`; `android.permission.INTERNET` present |
| Android identity configuration | `namespace` and `applicationId` set to `com.yorks.app`; Kotlin `MainActivity` package aligned. |
| ordinary release-signing check without credentials | Rejected as intended |
| PWA JSON/orientation and CI workflow YAML | Parsed; no portrait-only lock |
| prerequisite migration chain + seed | Replayed against an isolated PostgreSQL instance; focused RLS/token tests passed |
| `git diff --check` | Passed |
| `supabase db reset --local` | Passed: full tracked migration chain and deterministic seed replayed locally |
| Batch 1 pgTAP baseline | Passed: 15 assertions |
| Full `supabase test db --local` | Passed: 4 files, 60 assertions |

## Gate repair and follow-up

The seven historical `phase1_workflow_rls.test.sql` assertions used the third
`throws_ok` argument as a label, although pgTAP treats it as an expected error
message. They now pass a null message matcher and preserve the labels as the
fourth argument. This changes no historic migration, RLS policy or workflow
behavior; it restores the intended SQLSTATE-only regression proof.

Before a linked/staging deployment, continue to run the clean local gate and
let the GitHub Actions database workflow complete successfully:

   ```bash
   supabase start
   supabase db reset --local
   supabase test db --local
   ```

Before the first Play use, use the inspected `com.yorks.app` package and
production signing configuration. Production upload still requires protected
signing material and release-owner authorization.

Before any linked/staging deployment, verify the remote PostgreSQL major
version and historical migration ledger. The local config uses PostgreSQL
15, the Supabase CLI default, because no production access was authorized.

Known non-blocking baseline warnings remain: Flutter's future Built-in Kotlin
migration warning, the iOS CocoaPods/Swift Package Manager migration warning,
and available dependency updates outside current constraints.
