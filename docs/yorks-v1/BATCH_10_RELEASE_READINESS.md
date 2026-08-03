# Yorks AC. & Ref. V1 R35 — Batch 10 Release Readiness

Status: **local release remediation passed; dedicated staging and production
cutover remain blocked pending release-owner authority.**

## Audit baseline and release decision

This audit began from baseline commit
`9d9d3857e8cd864227b5c115dd87cfa0875a77c8` on 4 August 2026. The release
strategy is **complete-R35-only**:

- every release build must include the entire Yorks V1 chain;
- an explicitly disabled downstream R35 flag fails the release build closed;
- no controlled partial rollout or legacy Nexus V7 feature flag is a release
  mechanism; and
- rollback means redeploying the prior approved complete-R35 app/function
  build, preserving all additive schema, documents and audit history.

The remediation commit SHA is recorded after the implementation commit is
created. It is intentionally not guessed in this document.

## P0 remediation record

| Blocker | Result | Evidence / remaining authority |
|---|---|---|
| P0-1 — sparse workbook boundary | **Passed locally** | `_sourceColumnIndexes` now takes the maximum non-empty source coordinate over all header/data rows. Regression coverage proves MSD: 7 columns/22 rows; VCD: 8; SAR: 8; VENT.FAN: 19; Package Unit: 20 with header rows 3/4; trailing `MASS`/`STATUS`; and exact `1100c450`. |
| P0-2 — backend drift | **Shared remote verified, untouched** | The configured historic shared project has 32 migrations and ends at `yorks_v1_batch9_documents_audit`; it lacks `20260803192654_yorks_v1_boq_header_hierarchy` and `20260803211633_yorks_v1_document_replacement_version_link`. A clean local replay applied all 22 tracked migrations. Dedicated staging creation/deployment is pending owner confirmation. |
| P0-3 — controlled-document finalizer | **Database path passed locally; staging deployment pending** | Added the additive replacement-version migration and pgTAP proof: revision 2 retains one active link and creates one supersession audit event. `finalize-document-upload` is absent from the historic shared remote and must be deployed only to dedicated staging. The live upload/download/replacement witness is specified in `R35_STAGING_DEPLOYMENT.md`. |
| P0-4 — implicit shared backend | **Passed** | `main.dart` and `tool/r35.sh` no longer embed a shared URL/key. `.r35.env` is explicit and ignored; missing configuration exits closed. CI supplies explicit invalid placeholder values. |
| P0-5 — release/rollback agreement | **Passed** | This record, `TERRA.md`, `README.md`, `AGENTS.md`, launcher and CI describe complete-R35-only releases. Historical batch documents remain historical evidence, not a release rollout instruction. |
| P0-6 — prescribed gates | **Passed locally** | Exact results and hashes below. |

## Exact local evidence — 4 August 2026

| Command | Result |
|---|---|
| `flutter pub get` | Passed. |
| `flutter analyze` | Passed — no issues. |
| `flutter test` | Passed — **500 tests**. |
| `npx supabase db reset --local` | Passed — **22 tracked migrations** replayed and deterministic local seed applied. (`npx` is equivalent here because the Supabase CLI is not globally installed on this workstation.) |
| `npx supabase test db --local` | Passed — **12 files, 359 tests**. |
| `R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-web` | Passed. |
| `CI=true YORKS_CI_EPHEMERAL_SIGNING=true R35_ENVIRONMENT=ci SUPABASE_URL=https://ci.invalid SUPABASE_ANON_KEY=ci-publishable-key ./tool/r35.sh build-apk` | Passed. |

The local RPC inspection after reset returned `true` for both
`header_row_numbers` and `header_hierarchy` in
`v1_import_boq_worksheet(jsonb, uuid)`.

### Verification-only artifacts

These artifacts contain the CI placeholder backend and the CI ephemeral Android
certificate. They are reproducibility evidence only and are not deployable
production releases.

| Artifact | SHA-256 | Notes |
|---|---|---|
| `build/web/main.dart.js` | `34debb6ce84ca189fc88e24a6e3818aebb7960535ebaaedc7ec65c0281c1de2c` | 48 MiB generated web directory. |
| `build/app/outputs/flutter-apk/app-release.apk` | `07659059cef3c9577b2af6a9788f2ce2adc783561667ed74f72258ce65f642a9` | 77 MiB; CI-only signing lane. |

No new product-screen screenshot was captured for this audit because no screen
was redesigned or changed. Existing desktop/360px golden and widget coverage
continues to run inside the 500-test Flutter gate. The required live staging
screenshots are the upload, authorized download, denied download and
replacement-version witness in `R35_STAGING_DEPLOYMENT.md`.

## Dedicated staging procedure

The full operator procedure and evidence checklist live in
[`R35_STAGING_DEPLOYMENT.md`](R35_STAGING_DEPLOYMENT.md). The safe entry point
is:

```bash
cp tool/r35.staging.env.example .r35.staging.env
# Fill the dedicated staging values; do not use the historic shared project.
R35_STAGING_CONFIG_FILE=.r35.staging.env ./tool/r35-staging.sh deploy
```

The script refuses the historic shared project ref, links only to the explicit
staging ref, applies tracked migrations to the empty staging target, deploys
`finalize-document-upload` with JWT verification intact, and verifies both the
function and header-hierarchy RPC afterwards.

## Remaining staging and production blockers

1. A release owner must explicitly approve creation of a dedicated empty
   Supabase staging project. The currently connected organization quotes **$0
   monthly** for a new project (the provider still requires user confirmation
   before creation). The historic shared project will not be modified.
2. Deploy the 22 tracked migrations and `finalize-document-upload` to that
   staging target, then record the full project-document upload, download and
   replacement-version witness.
3. Build a staging web artifact with the dedicated staging publishable key and
   run AT-01–AT-25/AP-03–AP-08 with named non-production personas.
4. Obtain production target/backup authority, a protected production signing
   lane and web-hosting authority. No production credentials, service-role key
   or signing material belongs in the app, Git or this document.

## Migration, rollback and scope notes

`20260803211633_yorks_v1_document_replacement_version_link.sql` is additive:
it replaces only the trusted document-finalizer function. It preserves every
document, version, link, audit event and existing Storage object. The corrected
function leaves the original current link in place when it creates revision 2;
it does not alter authorization, document classification or workflow state.

No unrelated modules, screens, navigation or Yorks workflow semantics were
modified in this remediation.
