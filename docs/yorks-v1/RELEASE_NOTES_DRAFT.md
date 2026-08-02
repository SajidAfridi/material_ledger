# Yorks AC. & Ref. V1 R35 — Release Notes Draft

Status: **draft for staging acceptance; not a production-release announcement**.

## What is included

- Yorks AC. & Ref. project creation with project responsibility, buildings,
  optional attachments and the approved five-stage review flow.
- Editable, project-scoped BOQ groups and spreadsheet-style material rows,
  including Excel import/export and focused mobile editing.
- Controlled Material Requests from BOQ groups, selected rows, Excel imports
  and custom lines, with project/scope/timing validation and a server-assigned
  request number on submission.
- Procurement arrangement, reservation and Project Engineer approval, followed
  by trusted dispatch and receipt review.
- Delivery Order revisions, material returns, controlled PDF/Excel/print
  output and immutable document versions.
- Role-safe documents and audit views, retained Configuration, Rentals, User
  Management and Audit modules, plus reference-only Duct Sizer and ESP
  Calculator tools.

## Security and data handling

- Production authority remains Supabase Auth/Postgres; critical transitions are
  trusted, idempotent server commands.
- Project/Site Engineers do not receive commercial values by default.
- Documents are private, versioned and access-checked for every current link.
- Existing V7/legacy records are preserved; the rollout is additive and uses
  reconciliation/quarantine rather than silent reinterpretation.

## Known release conditions

- Batch 10 needs a completed staging acceptance witness, a provider-confirmed
  backup/restore rehearsal, web-host authorization and production Android
  signing provenance before public release.
- GitHub Actions currently cannot execute because the repository account is
  locked for billing; local gates are recorded separately in
  [`BATCH_10_RELEASE_READINESS.md`](BATCH_10_RELEASE_READINESS.md).
- The iOS CocoaPods and future Kotlin Gradle Plugin notices are maintenance
  work for a later platform update; current web and Android verification builds
  pass.
