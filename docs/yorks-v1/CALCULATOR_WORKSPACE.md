# Combined calculator workspace

## Approved scope — 6 October 2026

The product owner requested one home for Duct Sizer and ESP Calculator, named
saved calculations, general or project scope, explicit view/edit sharing,
existing import/export/print workflows, and a calm Codex-inspired interface
inside the existing Yorks shell. Admin, Senior Mechanical Engineer and Project
Manager are the approved sharing managers.

## Behavior and boundaries

- The home lists authorized records with search, calculator type, general/project
  and archived filters. Open a record or create a separate named calculation.
- Technical engineering users and Admin can create records. Existing device
  calculations are preserved and can be explicitly imported into a new record.
- General calculations require ownership, an explicit grant, or a manager role.
  Project calculations additionally require current project read access. A
  calculator grant never creates project membership or BOQ/MR/stock authority.
- Managers grant view/edit access and revoke grants. Viewers can export/print
  but cannot change values. Only managers archive/restore; history is retained.
- Project and calculator type are fixed after first save. A new calculation or
  explicit JSON import creates a separate identity, without moving shared data.
- Save uses server confirmation, an expected revision and an idempotency key.
  Concurrent stale writes conflict. An uncertain save retains its exact intent
  under a backend/account/record-specific recovery key and retries that intent.
- Unsaved edits have a navigation guard. Permission refresh never overwrites
  locally edited inputs or silently advances the loaded revision.
- JSON imports retain unknown fields and validate format, tool, size and numeric
  values. Existing duct and ESP formats remain supported. JSON export and print
  use the current inputs, including unsaved edits; the PDF identifies the saved
  revision or unsaved state.

## Implementation map

| Layer | Source |
|---|---|
| UI | `lib/features/engineering_tools/presentation/screens/yorks_calculator_workspace.dart` |
| Retained engineering editors | `lib/features/engineering_tools/presentation/screens/yorks_v1_engineering_calculator_screens.dart` |
| Models and localized workspace copy | `lib/shared/models/yorks_v1_calculator_{workspace,strings}.dart` |
| Controller/provider/repository | Corresponding `yorks_v1_calculator_*` files under `lib/shared/` |
| File download | `lib/shared/services/calculator_file_download*.dart` |
| Routes and existing shell | `lib/app/router.dart`, `lib/app/yorks_v1_workspace_shell.dart` |
| Database | `supabase/migrations/20261006092502_calculator_workspace.sql` |
| Tests | `test/yorks_calculator_workspace_test.dart`, `supabase/tests/database/yorks_calculator_workspace.test.sql` |

Widgets call the controller/repository. Private RLS tables have no ordinary
client table privileges. Trusted RPCs check live active identity, project access,
manager roles, grants and revisions; save/access/archive actions append audit.
The feature adds no stock, commercial or material-request mutation authority.

## Preservation and rollout

`YORKS_V1_CALCULATOR_WORKSPACE` defaults to false. With it off, existing tool
routes and device storage continue to work. With it on, both legacy tool entry
routes open the combined home within the universal Yorks shell. The two retained
calculators remain the calculation engines; no formula migration is performed.

The migration is additive and repeatable. Existing collections, local files and
legacy calculation keys are not deleted or overwritten. Disable the feature flag
to roll back the interface; retain new tables, grants and audit. Do not drop data
or run a generic remote database push across an unreconciled migration ledger.

Production enablement is not part of this implementation's acceptance claim.
Apply only this reviewed additive migration to an explicitly verified target,
then enable the feature in a tested artifact. Staging browser/persona acceptance
must precede production promotion.

## Verification record and required stop

Status: **implementation candidate; release gate blocked**. The feature remains
OFF by default. No staging or production database/deployment was changed.

Completed local evidence:

- `flutter pub get` succeeded; changed Dart formatting and `git diff --check`
  passed. The analyzer reported no issues before the final library-refresh
  change; that change compiled in the feature-enabled builds and focused tests.
- Complete Flutter suite: 2,466 passed, four skipped. The final focused suite
  has 19 passing tests, including a subsequently added routed create/save/back
  test proving the home refreshes with the new calculation.
- Nine rendered goldens: home, Duct and ESP at 1366, 768 and 360 pixels, under
  `test/goldens/calculators/`. New workspace labels are localized in English,
  Arabic, Urdu and Hindi; a localized Arabic home is covered. Retained engineering
  editor terminology has not received a complete secondary-language audit.
- Local Supabase reset succeeded. Calculator database suite: **42 passed**.
  The earlier complete database run passed 3,584 assertions; the extended latest
  run executed 3,588 assertions and failed one unrelated existing MR assertion.
- Both default-off and feature-enabled release web/APK builds succeeded using
  CI placeholder backend configuration. Web startup budget passed. APK signing
  used the repository's ephemeral CI signing lane, not production signing.
- Real browser against the local backend: Admin sign-in, integrated Yorks shell,
  named Duct creation, input edit, save/reopen, view sharing to a Site Engineer,
  exact JSON export values and PDF generation (`%PDF-1.5`, 11,668 bytes) worked.
  The observed shell breadcrumb mismatch was fixed afterward; final shell
  browser revalidation remains outstanding. Responsive widget evidence covers
  the final mobile layout and focused ESP row editor.
- Local debug startup stalled; a compiled profile build was used for local HTTP
  backend browser checks. The production release's HTTPS requirement remains
  intact. Profile-size budget failure is not a release-size pass; actual release
  artifacts passed the startup budget independently.

The latest full database failure is in the unchanged
`supabase/tests/database/yorks_v1_unified_material_request_register.test.sql`,
assertion 14: **Scope filter keeps Project requests and excludes Company
requests**, actual **0**, expected **2**. No MR source or test was modified.
The supplied `AGENTS.md` says to stop and report when tests expose an unrelated
existing failure, so further implementation/release work stops here. Diagnosis
of that separate failure, a final all-green gate, final browser revalidation,
staging persona acceptance and deployment remain outstanding. An earlier green
run does not supersede this latest failed result.

The local browser verification records are deliberate local-only test data.
Database assertions were adjusted to identify their own fixtures so authorized
browser-created calculator records do not change their expected totals.
