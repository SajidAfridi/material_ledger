# Yorks V1 R35 — Batch 0 Completion

> **HISTORICAL BATCH EVIDENCE — NOT CURRENT BUILD CONFIGURATION.** Read the
> canonical build section in `README.md` and `TERRA.md` for current defaults.

Completed: 1 August 2026
Scope: governance, product contract, repository audit and baseline verification
Feature/database changes: none

## Outcome

Yorks V1 Rev 2.0 is now the repository authority for overlapping Projects,
BOQ, Material Requests, Procurement, Inventory, Dispatch, Receipt, Delivery
Order, Returns, Documents and retained Admin behavior.

The effective final R35 experience is the non-conflicting UI/interaction target.
The Execution Pack supplies sequencing. Nexus V7 documents are historical; only
their non-conflicting security, migration, localization, architecture and
unrelated-module safeguards continue through the V1 contract.

## Artifacts created

- `docs/yorks-v1/README.md`
- `docs/yorks-v1/SOURCE_OF_TRUTH.md`
- `docs/yorks-v1/PRODUCT_DECISIONS.md`
- `docs/yorks-v1/CURRENT_TO_TARGET_GAP_ANALYSIS.md`
- `docs/yorks-v1/ARCHITECTURE_AND_SECURITY_CONTRACT.md`
- `docs/yorks-v1/STATE_RPC_RLS_MATRIX.md`
- `docs/yorks-v1/R35_UI_CONTRACT.md`
- `docs/yorks-v1/MIGRATION_AND_ROLLBACK_PLAN.md`
- `docs/yorks-v1/TEST_AND_ACCEPTANCE_PLAN.md`
- `docs/yorks-v1/IMPLEMENTATION_PLAN.md`
- this completion record

Repository `AGENTS.md` now governs Yorks V1 work. The Nexus V7 README and frozen
product decisions carry prominent historical notices rather than being deleted.

## Frozen decisions

- Four canonical roles with exact server-controlled Auth claims and dated
  project membership.
- No automatic promotion of legacy Engineer users.
- Effective R35 five-stage project wizard.
- Project-level dynamic BOQ with exactly 29 ordered defaults; each MR selects
  one Building/Other/Common scope.
- Seven-column controlled MR, with a separate non-commercial projection.
- Project/Site Engineers have no commercial access by default.
- Separate planning model/tag and receipt manufacturer serial data.
- Explicit MR Submit; no reservation at draft/submit.
- Full/Partial/Unavailable arrangement replaces warehouse reservations
  atomically.
- Project Engineer approval separation and returned decision history.
- Decimal-safe quantity caps, locked stock and idempotent critical commands.
- Partial-good Missing/Damaged receipt behavior and replacement limits.
- Immutable post-review DO revisions containing only good quantities.
- Returns affect inventory only on idempotent Procurement confirmation.
- Classified document versions require authorization for every current link.
- Accounts and full RFQ/quotation/PO remain preserved but unavailable/deferred.

## Source fingerprints

- Rev 2.0 SRS: `b9bd71e5474c5f09391764a294a094fc0565e1ca2d2a2d4a3ebd3fc0ffc0293d`
- R35 HTML: `420436288da54dce8e3e6dc35f4c43e9e7524738d3381050a641f2912818c75c`
- Execution Pack: `02a25c24197ff5b0f9729aab96a0c16b1f469a1938e0f6aa966bce3f73737067`

## Verification

| Command/check | Result |
|---|---|
| `flutter pub get` | Passed |
| Dart format | Not applicable — no Dart files changed |
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed, 352 tests |
| release web build with CI Supabase placeholders | Passed |
| release Android APK build with CI Supabase placeholders | Passed, 72.9 MB |
| Yorks V1 README internal links | Verified |
| `git diff --check` plus new-document whitespace review | Passed; intentional Markdown hard-break spaces only |
| `supabase db reset` / `supabase test db` | Not runnable yet: tracked local Supabase config/prerequisite baseline is a Batch 1 deliverable |

No product credential or production database was used.

## Known baseline warnings and blockers

Batch 1 must address:

- `android.permission.INTERNET` is absent from the main/release manifest;
- Android release currently falls back to the Android debug key when no
  keystore is configured;
- permanent `com.yorks.app` application identity/namespace and signing
  ownership require confirmation before store release;
- web PWA manifest forces portrait-primary orientation;
- CI does not build Android or run Supabase reset/pgTAP;
- no tracked `supabase/config.toml`/deterministic local seed exists;
- Flutter warns that the application/plugins must migrate from the Kotlin
  Gradle Plugin before a future Flutter version enforces Built-in Kotlin;
- Flutter reports newer dependency releases outside current constraints;
- iOS still has a CocoaPods/Swift Package Manager migration warning, outside
  the user’s immediate Android/web target but retained as a known limitation.

The R35 prototype was inspected completely at source/override level. The
in-app browser blocked its local `file://` URL, so runtime prototype screenshots
and focus behavior were not independently verified in Batch 0. Flutter UI
batches require direct responsive/runtime evidence.

## Next batch

Batch 1 is Platform Baseline and Release Blockers:

1. tracked local Supabase configuration, prerequisite migration chain and seed;
2. all-off Yorks V1 feature flags;
3. database plus Android CI gates;
4. release Android Internet/signing safety;
5. PWA orientation correction;
6. permanent Android application identity decision and no-behavior-change proof.

No normalized feature schema or UI should begin until Batch 1’s fresh-checkout
reset/build gate passes.
