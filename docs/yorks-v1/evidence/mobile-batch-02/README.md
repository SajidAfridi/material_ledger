# Mobile UI Batch 02 Evidence

Status: **verified locally**
References: **12–21**
Acceptance viewports: **390×844** and **360×800 logical pixels**

This directory is the evidence index for the second ten-screen mobile slice:

1. Create Project — Review
2. Project Overview
3. Project Details & Team
4. BOQ Scope Overview
5. Building BOQ Folders
6. BOQ Materials
7. Add / Edit Material
8. Excel Import — Upload
9. Excel Import — Map Columns
10. Excel Import — Review

The supplied pack contains canonical 390×844 visual references only. Every
completed surface therefore has a deterministic Flutter-after capture at both
acceptance viewports, plus a 390×844 comparison and classified measurable
deltas. A literal 360×800 comparison is not fabricated when the pack provides
no 360 reference; those captures are explicitly adaptive evidence.

No pixel-parity claim is made. Each screen's `deltas.md` names the remaining
differences and their classification.

## Reference fingerprints

| Artifact | SHA-256 |
|---|---|
| `screen_manifest.json` | `7487b4233b5b7179a8cc572fc3b54068380704badf3bb464d74d69223d34c18c` |
| `design_tokens.json` | `a9e055732f548ced2f18fc6facd29c822397fe1a6985f950d5d65faae3c54694` |
| `docs/MOBILE_UI_CONTRACT.md` | `778800cb866b90693c265218be1e40c6dbf9a49ecb811d29ebd98f1cb388911c` |

The approved reference PNGs are 780×1688 exports of a 390×844 logical
viewport. A changed fingerprint requires a new evidence baseline.

## Required artifact layout

Each completed reference directory contains:

```text
reference-390x844.png
flutter-after-390x844.png
flutter-after-360x800.png
side-by-side-390x844.png
alpha-overlay-390x844.png
pixel-diff-390x844.png
deltas.md
```

No Batch 2 screen had an equivalent deterministic Flutter-Before artifact, so
none is represented as if it were one. `deltas.md` records position, size,
typography, padding, gap, border, radius, color, shadow, density, controls and
remaining differences. Every remaining difference is classified as a global
token, shared component, screen-local issue or intentional production
exception.

## Evidence ledger

| Ref | Surface | 390×844 | 360×800 | State/permission variants | Remaining deltas | Status |
|---:|---|---|---|---|---|---|
| 12 | Create Project — Review | [After + comparison](12_project_create_review/deltas.md) | Adaptive after | validation, directory error/retry, server-confirmed create | Classified in `deltas.md` | Verified |
| 13 | Project Overview | [After + comparison](13_project_overview/deltas.md) | Adaptive after | loading/error/zero, lifecycle, selected MR route | Classified in `deltas.md` | Verified |
| 14 | Project Details & Team | [After + comparison](14_project_details_team/deltas.md) | Adaptive after | membership/global-role authority, manage allow/deny | Classified in `deltas.md` | Verified |
| 15 | BOQ Scope Overview | [After + comparison](15_boq_scope_overview/deltas.md) | Adaptive after | summary-only, no MR/export source | Classified in `deltas.md` | Verified |
| 16 | Building BOQ Folders | [After + comparison](16_boq_building_folders/deltas.md) | Adaptive after | All/Started/Empty filters, true row counts | Classified in `deltas.md` | Verified |
| 17 | BOQ Materials | [After + comparison](17_boq_materials/deltas.md) | Adaptive after | authorized commercial shape, lazy material cards | Classified in `deltas.md` | Verified |
| 18 | Add / Edit Material | [After + comparison](18_boq_material_editor/deltas.md) | Adaptive after | read-only, conflict, dirty exit, dynamic columns | Classified in `deltas.md` | Verified |
| 19 | Excel Import — Upload | [After + comparison](19_excel_import_upload/deltas.md) | Adaptive after | local selection/decode failure, no mutation | Classified in `deltas.md` | Verified |
| 20 | Excel Import — Map Columns | [After + comparison](20_excel_import_map/deltas.md) | Adaptive after | validation issues, protected cost classification | Classified in `deltas.md` | Verified |
| 21 | Excel Import — Review | [After + comparison](21_excel_import_review/deltas.md) | Adaptive after | final command only, conflict/failure recovery | Classified in `deltas.md` | Verified |

## Functional witness checklist

- [x] Review/Create preserves draft validation, exact idempotent command,
      server confirmation and attachment failure handling.
- [x] Project Overview distinguishes provider loading/failure from valid zero
      counts and adds no weighted progress.
- [x] Team reads and actions preserve membership/global-role authority and
      never widen the protected user directory.
- [x] BOQ Overview is non-editable and cannot export or source an MR.
- [x] Common and each building remain independent real scopes.
- [x] Folder filters and cards use the same authorized group provider.
- [x] Material list/editor preserve arbitrary columns, capability-safe response
      shape, dirty/save/failure/conflict and read-only states.
- [x] Mobile row deletion retains the existing confirmation requirement.
- [x] Excel Back/Cancel is non-mutating and preserves local mappings where
      appropriate.
- [x] Only final Excel Import calls the trusted command, once; server
      failure/conflict remains recoverable.
- [x] Procurement/read-only and archived/legacy BOQ variants cannot mutate.
- [x] Keyboard, text scale, 44×44 targets, safe areas and shell navigation
      insets pass at both viewports.
- [x] Existing tablet/desktop/web presentation remains unchanged above the
      `YorksMobileUi` guard.

## Test record

The final local commit identifies this evidence set. No production deployment
was made.

| Gate | Result | Evidence |
|---|---|---|
| Focused project creation/workspace widget tests | Passed | `test/yorks_mobile_project_batch2_test.dart` 15/15; shell invariants 4/4 |
| Focused BOQ/controller/import tests | Passed | Batch 2 BOQ 23/23; commercial-import coverage 4/4 |
| Mobile goldens at 390×844 and 360×800 | Passed | refs 12–21; current golden pixels are the recorded Flutter-after captures |
| `dart format --output=none --set-exit-if-changed ...` | Passed | 17 changed Dart files, 0 reformatted |
| `flutter analyze` | Passed | No issues |
| `flutter test` | Passed | 599 tests |
| R35 CI web build | Passed | `./tool/r35.sh build-web` with CI placeholder backend values |
| R35 CI APK build | Passed | CI ephemeral-signed `app-release.apk` |
| Desktop/web regression witness | Passed | 48 focused project/workspace/BOQ/shell checks, including desktop goldens |
| Local Supabase reset and pgTAP | Passed | migration reset and 15 files / 470 tests |

The database gate is included because the separately documented commercial
import classification defect was corrected in the same coherent BOQ slice. The
additive migration preserves technical columns, fails closed for unauthorized
commercial mappings, and has positive/negative RLS coverage.
