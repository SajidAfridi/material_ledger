# R38 Configuration Centre evidence — 14 August 2026

This evidence package covers AT-31 for the R38 Configuration Centre.

## Automated evidence

- `supabase/tests/database/yorks_r38_configuration_centre.test.sql` proves the
  exact-Admin RPC boundary, direct-table denial, typed validation, optimistic
  revision checks, idempotent publication, inert draft/master-data changes,
  immutable history and trusted audit attribution.
- `test/yorks_v1_configuration_repository_test.dart` covers projection parsing,
  RPC payloads, release environment projection and domain error mapping.
- `test/yorks_v1_configuration_test.dart` covers the forbidden state, draft
  validation/review flow, responsive interaction and the three golden layouts.
- `test/router_test.dart` covers exact-Admin route access and fail-closed
  redirects for the other Yorks roles.

Final local gate results on 14 August 2026:

- clean `supabase db reset`: passed;
- full pgTAP suite: 29 files / 784 assertions passed;
- Dart formatting check and `flutter analyze`: passed with no issues;
- full Flutter suite: 824 tests passed;
- R35 CI web build: `build/web` completed;
- R35 CI ephemeral-signing Android lane: release APK completed at
  `build/app/outputs/flutter-apk/app-release.apk`.

`supabase db lint --level warning` reported no Configuration Centre warning;
the remaining warnings pre-date this migration and are outside this slice.

## Responsive visual evidence

- Desktop 1366×768:
  `test/goldens/r38/configuration_desktop_1366x768.png`
- Tablet 900×1024:
  `test/goldens/r38/configuration_tablet_900x1024.png`
- Mobile 360×800:
  `test/goldens/r38/configuration_mobile_360x800.png`

The layouts preserve the R38 information hierarchy while changing navigation
and card flow at tablet/mobile widths. Controls retain the shared Yorks design
tokens and minimum interactive target sizing.

## Migration and rollback

The additive migration is
`supabase/migrations/20260814090919_yorks_r38_configuration_centre.sql`.
It seeds a deterministic baseline, keeps unpublished changes inert, publishes
atomically through trusted commands and retains immutable publication history.
Rollback guidance is recorded in `docs/yorks-v1/MIGRATION_AND_ROLLBACK_PLAN.md`;
published history is preserved rather than destructively removed.

## Scope safeguards

- Site Engineer project creation remains available under the Rev 2.0 product
  contract.
- Protected workflow, append-only audit, trusted server time/actor attribution
  and single-warehouse invariants are shown but cannot be weakened here.
- Accounts remains a configuration projection only; no deferred Accounts route
  or commercial workflow was enabled.
- Numbering is rendered as protected reference data: the canonical
  `{PROJECT_REF}-MR{NNN}`, `{PROJECT_REF}-DSP{NNN}` and
  `{PROJECT_REF}-RTN{NNN}` formats cannot be edited through Configuration.
- The file-policy baseline matches the existing protected 20 MiB upload and
  MIME allowlist; the screen cannot claim support for DWG or a higher limit.
- Published active units feed MR and Warehouse selectors through a role-safe
  runtime projection. Server triggers reject an inactive/unknown unit on new
  or unit-changing MR and inventory rows without rewriting historical rows.
