# Yorks workspace zoom evidence — 14 September 2026

Status: **implemented and locally verified; physical-device/platform matrix
remains outstanding.** No production release was performed.

## Result

- Browser builds use the browser's page zoom, trackpad/touch pinch and reset.
  Yorks does not apply a second workspace transform on web.
- Native builds use focal-point inspection zoom from 100% through 400% with
  touch pinch, trackpad pinch/pan, Ctrl/Command-wheel, keyboard shortcuts,
  middle-button pan and Space plus primary-button pan.
- The former bottom-right control is absent. Accessible native Zoom in, Zoom
  out and Reset zoom actions live in the existing account menu/drawer.
- A bounded in-memory route history restores an inspected native page during
  the same authenticated session and is discarded when identity changes.
- Embedded PDF previews own their gestures and cannot also zoom the workspace.
- System text scaling, business state, drafts, exports and server authority are
  unchanged.

## Automated evidence

- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 1,715 tests.
- `flutter test test/yorks_workspace_zoom_test.dart
  test/yorks_v1_workspace_shell_test.dart`: passed, 31 tests.
- Chrome-platform zoom ownership widget test: passed, 1 test.
- `node --test tool/yorks_browser_zoom_test.mjs`: passed, 2 tests.
- CI-configured `./tool/r35.sh build-web`: passed; startup budget passed.
- CI-configured `./tool/r35.sh build-apk`: passed; release APK generated with
  ephemeral CI signing, not a production-signed artifact.
- CI-configured `./tool/r35.sh build-macos`: passed; local release app generated
  for build verification. Distribution signing was not verified.

Focused coverage includes two-finger touch pinch/pan, trackpad pinch/pan,
pointer-centred modified-wheel zoom, keyboard and reduced-motion handling,
ordinary/Shift-wheel behavior, single-finger scrolling while magnified, mouse
panning, bounds, reset, focus visibility, form/dropdown preservation, route
restoration, identity isolation, PDF-viewer isolation and menu access at 1366px
and 360px.

## Browser witness

Chrome 152 on macOS loaded the CI-configured release web build without a
reported browser error. At an emulated 360 by 800 mobile viewport:

| State | Browser scale | Visual width | Layout width | Flutter view |
|---|---:|---:|---:|---:|
| Initial | 1.0 | 360 | 360 | 360 by 800 |
| Pinched | 2.0 | 180 | 360 | 360 by 800 |
| Reset | 1.0 | 360 | 360 | 360 by 800 |

This proves browser magnification without a responsive-layout switch during
pinch. The event witness also proved that Ctrl/Command zoom input was not
default-prevented, did not reach Flutter's competing handler, and ordinary
wheel input still reached Flutter.

The eight changed 1366px goldens differ only in the former control footprint:

- `test/goldens/r35/engineer_overview_desktop.png`
- `test/goldens/r35/procurement_overview_desktop.png`
- `test/goldens/r35/admin_overview_desktop.png`
- `test/goldens/r35/audit_workspace_desktop.png`
- `test/goldens/r35/senior_mechanical_overview_desktop.png`
- `test/goldens/r35/material_request_approval_header_1366x768.png`
- `test/goldens/r35/senior_user_management_nav_desktop.png`
- `test/goldens/mobile_touchups/user_management_1366x768.png`

Existing 360px visual baselines remained unchanged because the floating control
was already hidden at phone width.

## Data preservation and rollback

There is no migration, backend, authorization, record, cache or export change.
Rollback is the code-and-golden revert of this slice. No data operation is
required.

## Remaining release evidence

- Real trackpad/mouse checks in Chrome and Edge on Windows and macOS.
- Physical iOS and Android pinch, system magnifier and screen-reader checks.
- Native Windows and signed macOS release checks where applicable.
- The local Supabase reset/database suite was unavailable because Docker and
  local Postgres were not running. This slice contains no database change.
