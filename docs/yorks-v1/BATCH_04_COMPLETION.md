# Yorks V1 R35 — Batch 4 Completion

> **HISTORICAL BATCH EVIDENCE — NOT CURRENT BUILD CONFIGURATION.** Read the
> canonical build section in `README.md` and `TERRA.md` for current defaults.

Status: **passed** on 2 August 2026.

## Delivered

- A cross-platform XLSX gateway using `file_selector` for the native/browser
  file flow, and a pure-Dart OOXML ZIP/XML codec for scalar BOQ cells. It
  accepts bounded `.xlsx` workbooks and exports a valid one-sheet workbook;
  source bytes are never written to the local BOQ cache or database.
- A reviewed import experience: sheet choice, detected editable title,
  selectable header row, canonical-field suggestions, editable heading/mapping
  preview, sample values and pre-commit blank/duplicate validation. It wraps
  on narrow mobile widths and remains a bounded, scrollable dialog on desktop.
- Faithful BOQ export of the active worksheet title, visible ordered headings
  and raw row values. Standard and arbitrary technical headings are retained;
  importing a workbook does not make its fields standard material columns.
- `v1_import_boq_worksheet`, an Excel-flagged, role-checked, idempotent and
  expected-version-checked command. It validates the import as a complete
  snapshot before delegating to the existing atomic BOQ save command, then
  records server-generated import provenance and audit activity.
- Additive provenance fields on BOQ groups: import time, importing Auth user
  and sanitized source metadata (file name, worksheet name and header row).
  No workbook bytes or unprotected commercial values are stored in source
  metadata.
- Procurement remains read-only: the UI exposes export only, and the database
  command rejects Procurement independently of UI state. Imports cannot call,
  create or submit a Material Request.

## Verification

- `flutter pub get` — passed.
- Dart formatting check for all Batch 4 Dart files — passed.
- `flutter analyze` — passed with no issues.
- `flutter test test/yorks_v1_boq_test.dart` — 9 passed, including MSD
  export/decode/re-import, header-only/invalid-heading validation, malformed
  workbook rejection, 360px focused row editor and 500-row desktop grid.
- `supabase db reset --local --debug` and `supabase test db` — passed: 211
  pgTAP tests across 7 files, including 22 Batch 4 import/RLS/idempotency
  checks.
- `flutter test` — 426 passed.
- `flutter build web --release` with CI placeholder backend values — passed.
- `CI=true YORKS_CI_EPHEMERAL_SIGNING=true flutter build apk --release` with
  CI placeholder backend values — passed; output is
  `build/app/outputs/flutter-apk/app-release.apk`.
- `git diff --check` — passed.

## Migration and rollback

`20260802010000_yorks_v1_batch4_boq_excel.sql` is additive. It adds BOQ import
provenance and the server command without rewriting a legacy/V7 record.
Disable the default-off `excel` flag to roll the experience back; successful
imports remain versioned BOQ data with their audit/provenance history intact.

## Known limitation

The interchange supports scalar `.xlsx` cells only. It deliberately does not
preserve workbook formatting, macros, formulas or unsupported `.xls` files.
Formula cells import their stored scalar values when present. Durable offline
worksheet-draft recovery remains outside this batch.

The Android release build also reports Flutter's forward-looking Kotlin Gradle
Plugin migration warning (including `sentry_flutter`). The release APK builds
successfully today; this retained platform maintenance item is not introduced
by the Excel slice.

## Next dependency

Batch 5 creates the recoverable Material Request draft/submit vertical slice.
Its controlled exports are separate from BOQ interchange, and it must retain
the Batch 4 rule that an imported BOQ never submits a request by itself.
