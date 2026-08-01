# Yorks Nexus V7 — Implementation Status

Last updated: 24 July 2026

## Batch 0A — Product contract: complete

- [x] Approved implementation pack and V7 design are under
      `docs/nexus-v7/`.
- [x] Product decisions freeze workflow, quantities, statuses, approvals,
      receipt directions and the three-stage project-creation flow.
- [x] The legacy SRS is reconciled against V7.
- [x] Supabase Auth/Postgres are the system of record; Firebase is FCM
      transport only.
- [x] Legacy Firebase/Firestore documents and rules are explicitly marked as
      non-authoritative.
- [x] Implementation, acceptance and test documents use the same vocabulary.

## Batch 0B — Baseline and security configuration: complete

- [x] GitHub Actions quality gate: changed-file formatting, full analysis,
      complete tests and release web build.
- [x] Generated `build/**` plugin examples excluded from application analysis.
- [x] Independent V7 feature flags added; every flag defaults off.
- [x] Release startup fails closed without a complete HTTPS Supabase
      configuration.
- [x] Local development requires both `ALLOW_LOCAL_DEVELOPMENT=true` and an
      explicit `LOCAL_DEMO_PASSWORD`.
- [x] Hard-coded Supabase demo endpoint/key and reusable seed password removed
      from application source.
- [x] Supabase roles resolve only from exact `app_metadata.role` values; there
      is no email or `user_metadata` authorization fallback.
- [x] Connected mode removes legacy local password hashes.
- [x] Material cost and derived reservations are excluded from shared material
      writes, empty-cloud seeding and incoming local-cache merges.
- [x] Salary, basic wage and project contract value remain stripped from the
      generic bootstrap upload path.
- [x] Credential values removed from the production-status runbook.

## Batch 1 / PR-01A — Project v2 domain migration: complete

- [x] Backward-compatible Project v2 aggregate with explicit data version.
- [x] Stable project party and multiple-building value objects.
- [x] Optional floors/levels and boolean-only FRP-room applicability.
- [x] Yorks reference, job/contract number, project manager and multiple design
      engineers.
- [x] Creator/updater identity, role and UTC timestamp metadata.
- [x] Deterministic, idempotent flat-building migration.
- [x] Legacy authority reference preserved in migration metadata and never
      reinterpreted as Other Contractors.
- [x] Case-insensitive Yorks-reference uniqueness in the provider.
- [x] Legacy and V7 engineer assignments both enforced by project visibility.
- [x] Existing screens, routes and feature-flag defaults unchanged.
- [x] No Supabase schema or RLS exposure added in this slice.

Migration and rollback details are recorded in
`PR-01A_PROJECT_V2_MIGRATION.md`.

## Batch 2 / PR-02 — Secure commercial data: complete

- [x] Canonical `viewCommercials` capability with legacy `cost` migration
      compatibility.
- [x] Separate commercial records for material, goods-receipt and project
      values.
- [x] Operational models, caches, realtime hydration, outbox payloads and CSV
      export enforce the boundary.
- [x] Denied screens do not build commercial fields; provider writes also fail
      closed.
- [x] Admin behavior is preserved; Procurement visibility follows the editable
      Access & Roles configuration.
- [x] Commercial writes require both visibility and Admin/`goods` authority.
- [x] Live Supabase RLS table and five recursive cost-stripping triggers.
- [x] Existing 56 material costs migrated with zero remaining commercial keys
      in operational tables.
- [x] Positive, negative and read-only RLS cases verified against the live
      database in rolled-back transactions.
- [x] `admin-users` active version 2 emits canonical claims with JWT
      verification enabled.
- [x] Flutter security/provider/UI tests and tracked pgTAP coverage added.

Architecture, migration evidence and rollback details are recorded in
`PR-02_SECURE_COMMERCIAL_DATA.md`.

## Operational Procurement identity: complete

- [x] Existing `procurement@gmail.com` Auth identity was selected unambiguously.
- [x] Role corrected from Engineer to Procurement without changing its stable
      `app_user_id` (`usr-a5a3776a`).
- [x] Canonical Procurement capabilities verified, including
      `viewCommercials` and `goods`.
- [x] Admin, Engineer and Procurement roles now each have a live identity.
- [ ] The Procurement user must sign in again before real-persona testing so a
      fresh JWT contains the corrected claims.

## Batch 3 / PR-03 — V7 visual foundation: complete

- [x] Approved V7 palette, type, spacing, radius and responsive tokens applied
      at the shared theme layer.
- [x] Bundled offline-stable English and Arabic font families registered.
- [x] Existing shared cards and primary/secondary buttons aligned to V7 while
      preserving their public APIs.
- [x] Reusable responsive page/header shell with a 330 px desktop inspector and
      stacked tablet/mobile behavior.
- [x] Reusable section card, status tones, current-action owner card, audit
      metadata and activity-row components.
- [x] Mobile action targets enforce a minimum 44 px height.
- [x] Desktop and mobile golden baselines render with real fonts and icons.
- [x] No routes, providers, workflows, database schemas or feature flags
      changed in this slice.

Architecture, visual mapping, tests and rollback details are recorded in
`PR-03_V7_VISUAL_FOUNDATION.md`.

## Batch 4 / PR-04 — Project creation flow: complete

- [x] Existing `/projects/new` route preserved with a default-off V7 Projects
      flag and unchanged legacy fallback.
- [x] Shared Engineer, Procurement and Admin flow with exactly Essentials &
      Responsibility, Buildings, and Review & Create.
- [x] Per-user autosaved drafts restore step and values after reopening.
- [x] Required-field, date, engineer, Yorks-reference and unique building-code
      validation.
- [x] Optional secondary name, project manager, parties, notes and document
      reference metadata.
- [x] Multiple physical buildings, optional floors and boolean-only FRP.
- [x] Explicit `COMMON` project-wide building scope on every new project.
- [x] Other Contractors remains separate from preserved legacy Authority
      Reference.
- [x] Actor, role and UTC timestamp retained for projects and attachment
      metadata.
- [x] Engineer creation enters Procurement acceptance; office creation avoids
      redundant self-acceptance.
- [x] Responsive desktop/tablet/mobile implementation with inspected goldens.
- [x] Existing JSONB outbox and RLS boundary reused; no Supabase schema or
      policy expansion.

Architecture, compatibility, rollout and rollback details are recorded in
`PR-04_PROJECT_CREATION_FLOW.md`.

## Batch 5 / PR-05 — Project workspace and readiness: complete

- [x] Feature-flagged shared `/projects/:id` workspace for Engineer,
      Procurement and Admin.
- [x] Overview, Material Plan, Requests, Procurement, Documents and Activity
      connected by stable project identity.
- [x] Current action and current owner derived from acceptance, plan and
      request states.
- [x] Concrete blockers and an unweighted operational readiness checklist.
- [x] Engineer deep links fail closed outside assigned project visibility.
- [x] Procurement can reach the shared project register; destructive deletion
      remains Admin-only.
- [x] Existing plan, request, receipt and Procurement screens remain the sole
      owners of workflow mutations.
- [x] RFQ/PO areas declare their later-batch boundary without fake records.
- [x] Project/building document metadata and actor/role/time remain traceable.
- [x] Desktop tabs and inspector plus a separate mobile section selector.
- [x] Arabic secondary copy uses the bundled deterministic Arabic-script font.
- [x] Desktop/mobile goldens inspected with no overflow.
- [x] Existing Supabase-backed providers and visibility boundary reused; no
      schema, Storage or RLS expansion.

Architecture, security boundary, verification and rollback details are recorded
in `PR-05_PROJECT_WORKSPACE.md`.

## Batch 6 / PR-06 — Dynamic masters and Browse Materials: complete

- [x] Stable Admin-managed category and unit records with archive-only history.
- [x] Eight approved HVAC category groups and the eight frozen default units.
- [x] Deterministic, idempotent migration from every legacy category/unit value.
- [x] Unmatched legacy units preserved as pending custom records for review.
- [x] Procurement may propose a pending custom unit; only Admin may approve,
      edit status or archive it.
- [x] Existing material JSON remains readable while stable category/unit master
      IDs become authoritative.
- [x] Feature-flagged shared Browse route for Engineer, Procurement and Admin.
- [x] Finder-style desktop rail/list/inspector and separate mobile card/detail
      interaction.
- [x] Search, category filtering, live on-hand/allocated/available quantities
      and explicit unavailable in-transit state.
- [x] Engineer UI, local state and CSV omit commercial columns and values;
      authorized roles resolve costs only from the protected in-memory boundary.
- [x] Real browser CSV download with non-web clipboard fallback.
- [x] Admin master register and master-aware catalogue material form.
- [x] Two synced Supabase master collections with explicit API grants, realtime
      hydration and RLS.
- [x] Live positive/negative RLS checks for Admin, Engineer and Procurement.
- [x] Desktop and mobile browser inspection completed without overflow.
- [x] Phase 1 planning and the reusable material-line grid remain untouched.

Architecture, migration, security, verification and rollback details are
recorded in `PR-06_DYNAMIC_MASTERS_BROWSE.md`.

## Batch 7 / PR-07 — Reusable MaterialLineGrid: complete

- [x] Exact eight operational columns plus two capability-controlled commercial
      columns.
- [x] Operational line JSON, denied controller state and denied CSV contain no
      commercial field or value.
- [x] Native Flutter frozen S:No lane, sticky header and virtualized editable
      rows.
- [x] Direct cell editing with Tab/Shift+Tab and Enter/Shift+Enter navigation.
- [x] Excel TSV paste from keyboard or toolbar.
- [x] Add Blank Row, exact Smart Similar Row, row validation and undo/redo.
- [x] Rectangular, circular, linear, nominal-pipe and custom size builder.
- [x] Debounced autosave callback that preserves incomplete draft values.
- [x] Exact role-safe CSV schema and escaping.
- [x] Separate virtualized mobile cards and focused editor.
- [x] Debug-only 500-row diagnostic route with desktop/mobile preview.
- [x] 500-row virtualization and bounded-edit regression proof.
- [x] No Phase 1, Material Request or production workflow integration.
- [x] No Supabase schema, RLS, Storage or realtime expansion.

Architecture, security boundary, performance evidence, verification and
rollback details are recorded in `PR-07_REUSABLE_MATERIAL_LINE_GRID.md`.

## Batch 8 / PR-08 — Phase 1 Material Planning: complete

- [x] Engineer Phase 1 draft uses the approved reusable material grid, mixed
      catalogue/custom lines, building scope, autosave and explicit submission.
- [x] Every submission creates a monotonic immutable version and transfers
      current ownership to Procurement.
- [x] Procurement receives a read-only specification with advisory on-hand and
      available quantities, warehouse/external/mixed proposed source and
      plan/line comments.
- [x] Phase 1 source review cannot allocate or reserve warehouse stock in
      Flutter or at the database boundary.
- [x] Ready for Approval returns ownership to Engineering; Engineering can
      approve or request selected-line changes with a reason.
- [x] Revised submissions reset source review without overwriting prior
      versions, comments or activity.
- [x] Final approval activates the project atomically in Supabase; direct
      activation without an approved plan is rejected.
- [x] Five normalized plan/version/line/comment/activity tables have explicit
      grants, project-scoped RLS and realtime publication.
- [x] Project completeness is a configurable, audited reporting layer with
      100%-weight validation and no workflow side effects.
- [x] Android Studio includes a tracked Chrome/Supabase run target, the Yorks
      logo is explicitly circular, and Phase 1 mobile action bars remain
      bounded.

Architecture, migration, security, verification and rollback details are
recorded in `PR-08_PHASE_1_MATERIAL_PLANNING.md`.

## Local development

Explicit local development example:

```bash
flutter run \
  --dart-define=ALLOW_LOCAL_DEVELOPMENT=true \
  --dart-define=LOCAL_DEMO_PASSWORD=<secure-local-only-value>
```

## Verification evidence

- `flutter pub get` — passed.
- `flutter analyze` — passed with zero issues.
- `flutter test` — passed, 352 tests.
- `flutter build web --release` with non-secret CI Supabase placeholders —
  passed.
- Live Supabase commercial, material-master and Phase 1 workflow matrices —
  passed.
- Supabase security/performance advisor pass — no unresolved Batch 8 security
  finding.
- `git diff --check` — passed.

The build reports a non-blocking Flutter notice that the existing iOS project
still uses custom CocoaPods integration while plugins now support Swift Package
Manager. This is platform build-system maintenance, not a Batch 0 functional
failure.

## Scope deliberately not started

- Remaining V7 normalized Phase 2, RFQ, quotation, PO and receipt domains.
- Phase 2 Material Request implementation.
- Binary Documents workspace.
- Rental or HR redesign.

## Required production operations

These are not code-complete claims and must be closed through the controlled
Supabase/deployment process before production go-live:

1. Rotate the historical demo-account passwords because an earlier tracked
   runbook contained reusable values; distribute replacements only through a
   secure channel.
2. Enable Supabase leaked-password protection.
3. Continue replacing the remaining generic JSONB synchronization tables with
   normalized V7 domain schemas and single-policy RLS designs. The commercial
   boundary is complete.
4. Resolve UAE production hosting, backup/restore, disaster recovery and data
   residency evidence.
5. Complete and validate the iOS CocoaPods-to-Swift-Package migration before an
   iOS production release.
## Next controlled slice

Batch 9 / PR-09 is the simplified Phase 2 Material Request flow. It reuses the
approved material browser/grid, requires an Active project and destination, and
keeps within-plan requests separate from auditable new/over-plan/substitution
exceptions.

## Working rule

Move one vertical slice at a time. Each slice must leave the app buildable,
preserve legacy JSON and unrelated modules, and include tests, migration notes,
security review and rollback guidance before the next slice begins.
