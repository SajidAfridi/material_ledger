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

Explicit local development example:

```bash
flutter run \
  --dart-define=ALLOW_LOCAL_DEVELOPMENT=true \
  --dart-define=LOCAL_DEMO_PASSWORD=<secure-local-only-value>
```

## Verification evidence

- `flutter pub get` — passed.
- `flutter analyze` — passed with zero issues.
- `flutter test` — passed, 258 tests.
- `flutter build web --release` with non-secret CI Supabase placeholders —
  passed.
- `git diff --check` — passed.

The build reports a non-blocking Flutter notice that the existing iOS project
still uses custom CocoaPods integration while plugins now support Swift Package
Manager. This is platform build-system maintenance, not a Batch 0 functional
failure.

## Scope deliberately not started

- V7 normalized Postgres tables, migrations, commands or RLS policies.
- Project v2/domain migration.
- New V7 routes or user-visible screens.
- Browse Materials, Phase 1, Procurement Review or Phase 2 implementation.
- Rental or HR redesign.

## Required production operations

These are not code-complete claims and must be closed through the controlled
Supabase/deployment process before production go-live:

1. Rotate the historical demo-account passwords because an earlier tracked
   runbook contained reusable values; distribute replacements only through a
   secure channel.
2. Enable Supabase leaked-password protection.
3. Replace the generic JSONB synchronization tables with the normalized V7
   schema and single-policy RLS design in the planned domain batches.
4. Resolve UAE production hosting, backup/restore, disaster recovery and data
   residency evidence.
5. Complete and validate the iOS CocoaPods-to-Swift-Package migration before an
   iOS production release.

## Next controlled slice

Batch 1 / PR-01A is the Project v2 domain migration only. It may start after
reviewing this Batch 0 result. V7 feature flags remain off until their owning
vertical slices pass acceptance.

## Working rule

Move one vertical slice at a time. Each slice must leave the app buildable,
preserve legacy JSON and unrelated modules, and include tests, migration notes,
security review and rollback guidance before the next slice begins.
