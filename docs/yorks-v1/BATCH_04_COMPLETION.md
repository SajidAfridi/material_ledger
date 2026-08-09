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

## 9 August 2026 commercial-import security correction

`20260809143000_yorks_v1_boq_commercial_import_classification.sql` closes a
classification gap discovered during the mobile BOQ review. Exact canonical
`Unit Cost` and `Total Cost` mappings are now commercial columns, and the
trusted import/save commands reject either canonical meaning if a client marks
it non-commercial. The server also normalizes those exact headings and the
approved Unit Price/Rate and Total Price/Amount aliases, so omitting or forging
`canonical_field` cannot move them into operational storage. Authorized values
are split into `commercial_values`; the ordinary `raw_values`, role-safe
Project Engineer projection, source metadata and audit payload contain no cost
value or commercial key. Arbitrary technical headings—including headings that
merely contain the word “cost”—remain lossless operational columns unless
explicitly mapped to a canonical cost.

Before enabling the new command definitions, the migration idempotently repairs
pre-existing exact recognized cost headings: it moves each stable column key
from `raw_values` to `commercial_values`, assigns the required commercial
canonical mapping, and increments affected row, column and group versions and
timestamps. It preflight-aborts the entire transaction if duplicate headings
would claim the same active canonical field or if raw and commercial maps
already contain different values for one key. It never reclassifies broader
technical headings such as `Operating Cost Index`.

Rollback is to disable Excel import while retaining remediated protected values
and their history; do not reverse-copy those values into `raw_values` because
that would recreate the disclosure. Focused Dart coverage also proves an
uncertain import retry reuses the same generated column/row IDs, payload and
idempotency key rather than creating a second logical command.

The correction was revalidated on 9 August 2026 with a clean local database
reset, a second application of the installed migration (no-op repeatability),
the focused 44-test pgTAP correction coverage and the full local database suite
(15 files / 470 tests). Focused Flutter BOQ/import coverage, static analysis,
the full 599-test Flutter suite, the CI web build and CI ephemeral-signed APK
build also passed. No remote Supabase project was changed.
