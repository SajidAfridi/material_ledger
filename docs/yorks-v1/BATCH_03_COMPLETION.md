# Yorks V1 R35 — Batch 3 Completion

Status: **passed** on 2 August 2026.

## Delivered

- Normalized, ordered BOQ columns and rows with stable IDs, versioning and a
  canonical-plus-raw value model. Arbitrary spreadsheet headings and values
  remain intact without changing the approved visible material schema.
- The exact 29 default BOQ groups are materialized once per project and are
  idempotently backfilled for dormant V1 projects. Custom groups use the same
  versioned model and may be archived with an audit record; defaults cannot be
  archived.
- Server-authoritative, idempotent worksheet saves with stale-version conflict
  detection, append-only audit events and no direct authenticated table
  writes. A populated deleted column is archived server-side while its old
  values are retained.
- Role-safe BOQ RPC projections and RLS: assigned engineers/Admin can edit
  active projects, while Procurement has a read-only projection and is denied
  direct BOQ mutations. Commercial values remain separate from the ordinary
  worksheet projection.
- Yorks project BOQ folder and worksheet pages behind the default-off `boq`
  feature flag. The detail view supports inline title/header/cell editing,
  blank or similar row insertion below the selected row, and explicit save or
  conflict feedback.
- Responsive spreadsheet behavior: desktop uses a virtualized table with a
  sticky row-number lane, keyboard Up/Down/Enter/Shift+Enter navigation and
  normal Tab traversal; 360px mobile uses focused row cards and a previous/
  next row editor sheet.

## Verification

- `flutter pub get` — passed.
- Dart formatting check for all Batch 3 Dart files — passed.
- `flutter analyze` — passed with no issues.
- `flutter test` — 422 passed, including 500-row desktop and 360px mobile
  BOQ widget coverage plus controller conflict/row insertion tests.
- `supabase db reset --local --debug` and `supabase test db` — 189 pgTAP tests
  across 6 files passed, including 22 Batch 3 BOQ/RLS/idempotency tests.
- `flutter build web --release` with CI placeholder backend values — passed.
- `CI=true YORKS_CI_EPHEMERAL_SIGNING=true flutter build apk --release` with
  CI placeholder backend values — passed; output is
  `build/app/outputs/flutter-apk/app-release.apk`.

## Migration and rollback

`20260802000000_yorks_v1_batch3_boq_spreadsheet.sql` is additive. It extends
the Batch 2 BOQ group record with worksheet metadata and adds `v1_boq_columns`
and `v1_boq_rows`, protective RLS, and server commands. It preserves existing
group records and backfills default worksheet titles/structure. Roll back by
disabling the `projects` or `boq` rollout flags; retain the normalized rows,
versions and audit history.

## Known limitation

The B3 editor uses an explicit save action and keeps unsaved changes in the
current editor session. Workbook import/export, mapping, validation previews
and durable offline worksheet-draft recovery are intentionally deferred to
Batch 4's Excel/sync slice; no BOQ edit can create or submit a Material Request.

## Next dependency

Batch 4 adds a transactional Excel import/export round-trip while preserving
the B3 dynamic headings, raw values, role boundaries and version checks.
