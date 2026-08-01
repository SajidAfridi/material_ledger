# Yorks AC & Ref V1 R35 — Batch 6 Completion

Status: **passed** on 2 August 2026.

## Delivered

- A server-authoritative, versioned procurement-arrangement flow for submitted
  Material Requests. Procurement starts an arrangement explicitly, completes
  every requested line, then sends its immutable saved version for Project
  Engineer approval.
- A minimal warehouse inventory foundation: named items, balances, append-only
  movements and active reservations. Procurement can arrange from warehouse
  stock or record an external supplier without exposing commercial values.
- Exact Full, Partial and Cannot Provide Now line decisions. Partial and
  unavailable lines require a reason; arranged quantities cannot exceed the
  request or the safely available warehouse quantity.
- Atomic replacement reservations. A returned arrangement retains its
  reservation while it is reviewed; a replacement locks the inventory balance,
  releases the old reservation once and creates the new reservation in the
  same server transaction. Cancellation before dispatch releases the current
  reservation through the same protected path.
- Separate Engineer approve/return decisions, current action ownership,
  server-generated decision snapshots, append-only audit events and
  idempotency. Procurement cannot approve its own work; Site-only and
  Procurement decision attempts are rejected by the server.
- A default-off `YORKS_V1_ARRANGEMENT` responsive Yorks workspace. Procurement
  has an editable desktop table and focused mobile cards; the Project Engineer
  receives a read-only review and explicit approve/return controls. It shows
  arrangement version history and no commercial fields.

## Verification

- `flutter pub get` — passed.
- Dart formatting check for Batch 6 Dart files — passed.
- `flutter analyze` — passed with no issues.
- `flutter test` — 432 passed, including arrangement model/repository/feature
  flag tests.
- `supabase db reset --local --debug` and `supabase test db --local
  supabase/tests/database` — passed: 264 pgTAP tests across 9 files, including
  29 Batch 6 RLS, quantity, approval, replacement, cancellation and
  idempotency checks.
- `flutter build web --release` with CI placeholder backend values — passed;
  output is `build/web/main.dart.js`.
- `CI=true YORKS_CI_EPHEMERAL_SIGNING=true flutter build apk --release` with
  CI placeholder backend values — passed; output is
  `build/app/outputs/flutter-apk/app-release.apk`.
- `git diff --check` — passed.

## Migration and rollback

`20260802030000_yorks_v1_batch6_arrangement_inventory.sql` is additive. It
adds protected inventory, reservation, arrangement and decision records and
does not rewrite legacy/V7 data. Disable the default-off `arrangement` flag to
remove the new UI; retain arrangements, reservations, movement records and
audit history so rollback never loses a business transition.

## Known limitation

This batch intentionally establishes only the inventory and reservation slice
needed to prevent overcommitment during arrangement. Full inventory browsing,
dispatch, supplier receipt, warehouse issue, site delivery and site receipt
confirmation remain later workflow batches. The authenticated arrangement UI
still needs a manual persona walkthrough against a local or staging sign-in;
the server, model, repository and feature-flag paths are covered by automated
tests.

The Android release build retains the pre-existing forward-looking Flutter
Kotlin Gradle Plugin warning (including `sentry_flutter`). The APK builds
successfully; that platform-maintenance item is not introduced by this slice.

## Next dependency

The next batch can expand the protected warehouse inventory workspace and add
the first dispatch/receipt event without changing Batch 6 reservation or
arrangement history.
