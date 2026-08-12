# Yorks R35 material-workflow trust remediation — 2026-08-11

## Outcome

The Material Request creation/submission flow was retained as a regression
boundary. The downstream arrangement, approval, dispatch, Delivery Order,
receipt-review, replacement-quantity, controlled-document and role-trust paths
were audited from Flutter through Riverpod/repositories to RPC/RLS and repaired.
No production service or production data was changed.

## Defects and root causes

| Defect | Root cause | Remediation |
| --- | --- | --- |
| Historical Delivery Order revisions could be falsely labelled as dispatch snapshots | A blanket backfill ignored that legacy revisions may be either dispatch- or receipt-derived | Fail-closed provenance preflight that first honors the immutable signed audit `snapshot_source`, then classifies only confirmed receipt-review revisions; ambiguous rows are never guessed |
| MR progress could compare against requested rather than approved quantity, call in-transit stock complete, and hide replacement need | Status was derived from one flattened fulfilled value | One numeric lifecycle projection now exposes requested, arranged, approved, dispatched, in-transit, good, missing, damaged, remaining and replacement quantities separately |
| Exact Senior Mechanical Engineer and Project Manager roles were normalized in documents/history | Workflow rows stored only the authorization-normalized role | Exact role and display-name snapshots are captured on arrangement, decision, dispatch, receipt, Delivery Order revision and audit events |
| Controlled MR/DO identity could change after project/profile edits | Projections used live project/profile joins | New records capture immutable document identity snapshots; legacy rows stay explicitly unverified instead of receiving fabricated history |
| Stale Admin JWTs could read all notifications | SELECT RLS trusted the token role without the live actor check | Notification RLS now uses the live server-controlled actor predicate |
| Site Engineer could be offered/attempt MR close through a PE-labelled membership | Close authorization did not enforce the exact-role boundary used by approval | Exact Site Engineer is denied; assigned PE, global engineer roles and Admin remain authorized |
| Mobile committed MRs omitted line-level lifecycle truth | Mobile used a summary-only branch | Mobile now shows original request facts and canonical arrangement/dispatch/receipt/replacement facts at 390×844 and 360×800 |
| Repeated-dispatch receipt/DO actions could target the wrong dispatch | Row callbacks reused a first-dispatch fallback | Every row carries its own dispatch ID; stale focused routes fail closed |
| Inventory creation and document-output retries could duplicate server commands | Retry identity was created in widget-local output paths | Critical mutations use the controller's persistent command lease; output retry reuses the confirmed DO revision |
| Client quantity checks used binary floating point | UI helpers parsed authoritative decimal strings as `double` | A scaled-integer `numeric(18,4)` quantity type is used for client validation and formatting |
| Critical forms could dismiss while committing and errors were generic | Dialog/pop state was not tied to the command lease | Commit surfaces use `PopScope`, server confirmation precedes success, and safe stock/cap/version errors are actionable |
| Delivery Report pagination could repeat a table header mid-page | Final rows/signature were emitted as a second headed table | Final rows remain inseparable with sign-off while continuing the page's existing table header |

## Database changes

- `20260810175326_yorks_v1_receipt_review_delivery_report_revisions.sql`
  now performs a provenance preflight and classifies provable legacy revisions
  as `receipt_review`.
- `20260811183000_yorks_v1_material_workflow_trust_remediation.sql` adds the
  exact-role/name/document snapshots, canonical lifecycle projection, trusted
  projection updates, close-role hardening, live notification RLS and the
  forward provenance repair.
- `yorks_v1_material_workflow_trust_remediation.test.sql` adds focused pgTAP
  coverage for exact roles, snapshots, quantities, replacement eligibility,
  stale-token RLS, commercial redaction, close denial and private helpers.

All changes are additive or replace function/policy definitions. Dispatch,
receipt, movement, revision and audit rows are not destructively rewritten.
Legacy identity remains `verified = false` where immutable evidence is absent.

Rollback must be forward-only: restore the prior function/policy definitions
if an application rollback is required, but keep captured columns and history.
Do not drop snapshot columns or rewrite dispatch/review/audit rows.

## Evidence

- MR partial-dispatch and missing-review goldens:
  `test/goldens/r35/trust/` at 1366×768, 390×844 and 360×800.
- Arrangement, approval, dispatch, receipt, exception and Delivery Order mobile
  goldens: `test/goldens/mobile_batch4/` at 390×844 and 360×800.
- Assigned-engineer immediate Delivery Order action:
  `test/goldens/r35/assigned_engineer_delivery_order_desktop.png` and
  `test/goldens/r35/assigned_engineer_delivery_order_mobile.png`.
- Rendered controlled documents: `output/pdf/r35-material-request.pdf`,
  `output/pdf/r35-delivery-order-dispatch.pdf`,
  `output/pdf/r35-delivery-report-receipt-reviewed.pdf` and the two-page
  `output/pdf/r35-delivery-report-multipage.pdf`.

Every generated PDF page was rendered and inspected. The current output has no
status column, title prefix, `Since 1984`, four-decimal display quantity or
clipped/blank page; it preserves the approved receipt pledge and fixed footer.

## Gates

- `flutter pub get` — pass
- changed-Dart format check — pass
- `flutter analyze` — pass, no issues
- `flutter test` — pass, 762 tests
- `supabase db reset` — pass
- `supabase test db` — pass, 25 files / 669 assertions
- R35 CI web build — pass (`build/web`)
- R35 CI ephemeral-signing release APK — pass
  (`build/app/outputs/flutter-apk/app-release.apk`)
- `git diff --check` — pass

## Production handoff

1. Take a database backup and deploy the database migrations before the web
   bundle.
2. Apply migrations first to a clone/staging database containing real beta
   history. If the provenance preflight raises
   `V1_DELIVERY_ORDER_LEGACY_REVISION_PROVENANCE_AMBIGUOUS`, stop and reconcile
   those rows from immutable receipt/audit evidence; do not force the migration.
3. Run the complete pgTAP suite against that staging database.
4. Set the protected GitHub `production` environment secrets
   `SUPABASE_URL_PRODUCTION`, `SUPABASE_ANON_KEY_PRODUCTION`, `VERCEL_TOKEN`,
   `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`; do not use the CI placeholder
   values used for this local build.
5. From `main`, run the protected `Controlled R35 production release` workflow
   with the staging acceptance record and approved rollback reference. It
   rebuilds with `R35_ENVIRONMENT=production` and deploys the prebuilt
   `build/web` bundle to Vercel.
6. Smoke-test one account for each
   exact role across full/partial arrangement, approval/return, two partial
   dispatches, receipt exception, replacement dispatch and both documents.
7. Verify authorized and unauthorized commercial projections using real beta
   accounts before widening access.

The repository remains intentionally undeployed by this remediation task.
