# Yorks AC. & Ref. V1 R35 — Batch 7 Completion

> **HISTORICAL BATCH EVIDENCE — NOT CURRENT BUILD CONFIGURATION.** Read the
> canonical build section in `README.md` and `TERRA.md` for current defaults.

Status: **passed** on 2 August 2026.

## Delivered

- A protected, role-safe inventory workspace with search, item detail, an
  append-only movement ledger, controlled stock adjustments and auditable
  archive/reactivate actions. It exposes no commercial fields.
- Server-authoritative dispatch commands for approved warehouse and external
  supplier lines. The command locks the Material Request, reservation and
  inventory balances; creates an immutable `DSP` reference; applies each stock
  movement exactly once; and is idempotent by caller key.
- Dispatch cap enforcement for approved quantity, previously good-received
  quantity, already in-transit quantity, remaining reservation and safely
  available warehouse stock. Concurrent or retried commands cannot consume a
  different request's reservation or reduce stock below zero.
- A separate receipt-review command for the assigned Project/Site Engineer or
  Admin. Every dispatch line is resolved as Received, Missing or Damaged; only
  good quantity satisfies the request, and exception quantities remain visible
  to Procurement for a replacement decision.
- Derived, server-generated logistics state/current-owner updates,
  notifications and append-only audit events. Procurement can dispatch but
  cannot confirm receipt; unassigned Engineers cannot confirm receipt.
- Default-off `YORKS_V1_LOGISTICS` routes and responsive Yorks UI: desktop
  tables support the operational view while mobile uses focused cards and a
  receipt editor. The Material Request detail links to dispatch/receipt work,
  and Procurement/Admin have an inventory entry point.

## Verification

- `flutter pub get` — passed.
- Dart formatting check for Batch 7 Dart files — passed.
- `flutter analyze` — passed with no issues.
- `flutter test` — 437 passed, including Batch 7 model/repository and
  responsive 360px screen tests.
- `supabase db reset --local --debug` and `supabase test db --local
  supabase/tests/database` — passed: 293 pgTAP tests across 10 files,
  including 29 Batch 7 direct-write, RLS, stock-cap, retry, competing-dispatch
  and receipt-authorisation checks.
- `supabase db diff --local --schema public` — passed with no untracked schema
  changes.
- `supabase db advisors --local` — no Batch 7 warnings. The reported
  performance warnings are pre-existing legacy duplicate-index and permissive
  policy findings.
- `flutter build web --release` with CI placeholder backend values — passed;
  output is `build/web`.
- `CI=true YORKS_CI_EPHEMERAL_SIGNING=true flutter build apk --release` with
  CI placeholder backend values — passed; output is
  `build/app/outputs/flutter-apk/app-release.apk`.
- Local browser smoke test — passed for the Yorks shell and explicit
  local-development sign-in. The protected logistics UI is intentionally
  unavailable without a Supabase-backed session; its responsive presentation
  is covered by widget tests.
- `git diff --check` — passed.

## Migration and rollback

`20260802040000_yorks_v1_batch7_logistics.sql` is additive. It retains the
Batch 6 reservation history and adds consumed-reservation accounting, dispatch,
dispatch-line, receipt-review and receipt-review-line records plus protected
projections and trusted RPCs. Disable the default-off `logistics` flag to
remove the new UI. Do not delete dispatch, receipt, movement or audit history:
rollback is a forward corrective migration or a compensating transaction.

## Known limitation

This batch deliberately stops at dispatch and receipt review. Supplier Receipt,
Warehouse Issue, Site Delivery Receipt, Site Receipt Confirmation, Delivery
Orders and returns remain distinct later workflow events. An authenticated
persona walkthrough still needs a local or staging Supabase sign-in once
provisioned; the server, role and responsive UI paths are covered
automatically.

The Android release build retains the pre-existing Flutter Kotlin Gradle Plugin
warning (including `sentry_flutter`). The APK builds successfully; the warning
is not introduced by this batch.

## Next dependency

The next batch can add Delivery Orders and the separate warehouse/site receipt
events without rewriting dispatch, review, reservation or inventory history.
