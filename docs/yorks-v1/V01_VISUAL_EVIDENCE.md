# Yorks V1 R38 — V01 Visual Convergence Evidence

Status: **V01 implemented and measured; visually converged within the recorded
production exceptions, not pixel-identical.**

Captured: 2026-08-08

## Scope and method

This pass is limited to the workspace shell, the empty Project Engineer
Overview and Project Creation step 1. BOQ is not included.

The approved R38 artifact SHA-256 is
`c9ad2f3d3a7848e82a56e849fc537d90f1769f758660302ca01f3dae2c6f3f88`.
R38 and the production Flutter widgets were rendered at exactly 1440x900,
1366x768, 1024x768, 390x844 and 360x800. Flutter used a local presentation
fixture with Omar Farooq, Project Engineer, empty authorized projections and a
local-only `YRA-`/2026-08-08 draft matching the visible R38 state. The fixture
issues no repository, Supabase, RPC or workflow write.

Each side-by-side file is `R38 | Flutter Before | Flutter After`. Overlay files
are a 50% R38/After alpha blend. Diff files are the absolute RGB difference
with 4x contrast. Workspace-shell metrics mask the page body and compare only
the sidebar/topbar or mobile topbar/navigation. Whole-screen metrics retain
font rasterization, current branding and intentional product differences.

## Evidence matrix

| Surface | Viewport | R38 | Flutter Before | Flutter After | Side by side | Overlay | Diff |
|---|---:|---|---|---|---|---|---|
| Workspace shell | 1440x900 | [PNG](evidence/r38-v01/workspace-shell/r38/workspace-shell-1440x900.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-before/workspace-shell-1440x900.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-after/workspace-shell-1440x900.png) | [PNG](evidence/r38-v01/workspace-shell/side-by-side/workspace-shell-1440x900.png) | [PNG](evidence/r38-v01/workspace-shell/overlay/workspace-shell-1440x900.png) | [PNG](evidence/r38-v01/workspace-shell/diff/workspace-shell-1440x900.png) |
| Workspace shell | 1366x768 | [PNG](evidence/r38-v01/workspace-shell/r38/workspace-shell-1366x768.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-before/workspace-shell-1366x768.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-after/workspace-shell-1366x768.png) | [PNG](evidence/r38-v01/workspace-shell/side-by-side/workspace-shell-1366x768.png) | [PNG](evidence/r38-v01/workspace-shell/overlay/workspace-shell-1366x768.png) | [PNG](evidence/r38-v01/workspace-shell/diff/workspace-shell-1366x768.png) |
| Workspace shell | 1024x768 | [PNG](evidence/r38-v01/workspace-shell/r38/workspace-shell-1024x768.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-before/workspace-shell-1024x768.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-after/workspace-shell-1024x768.png) | [PNG](evidence/r38-v01/workspace-shell/side-by-side/workspace-shell-1024x768.png) | [PNG](evidence/r38-v01/workspace-shell/overlay/workspace-shell-1024x768.png) | [PNG](evidence/r38-v01/workspace-shell/diff/workspace-shell-1024x768.png) |
| Workspace shell | 390x844 | [PNG](evidence/r38-v01/workspace-shell/r38/workspace-shell-390x844.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-before/workspace-shell-390x844.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-after/workspace-shell-390x844.png) | [PNG](evidence/r38-v01/workspace-shell/side-by-side/workspace-shell-390x844.png) | [PNG](evidence/r38-v01/workspace-shell/overlay/workspace-shell-390x844.png) | [PNG](evidence/r38-v01/workspace-shell/diff/workspace-shell-390x844.png) |
| Workspace shell | 360x800 | [PNG](evidence/r38-v01/workspace-shell/r38/workspace-shell-360x800.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-before/workspace-shell-360x800.png) | [PNG](evidence/r38-v01/workspace-shell/flutter-after/workspace-shell-360x800.png) | [PNG](evidence/r38-v01/workspace-shell/side-by-side/workspace-shell-360x800.png) | [PNG](evidence/r38-v01/workspace-shell/overlay/workspace-shell-360x800.png) | [PNG](evidence/r38-v01/workspace-shell/diff/workspace-shell-360x800.png) |
| Empty Engineer Overview | 1440x900 | [PNG](evidence/r38-v01/overview/r38/overview-1440x900.png) | [PNG](evidence/r38-v01/overview/flutter-before/overview-1440x900.png) | [PNG](evidence/r38-v01/overview/flutter-after/overview-1440x900.png) | [PNG](evidence/r38-v01/overview/side-by-side/overview-1440x900.png) | [PNG](evidence/r38-v01/overview/overlay/overview-1440x900.png) | [PNG](evidence/r38-v01/overview/diff/overview-1440x900.png) |
| Empty Engineer Overview | 1366x768 | [PNG](evidence/r38-v01/overview/r38/overview-1366x768.png) | [PNG](evidence/r38-v01/overview/flutter-before/overview-1366x768.png) | [PNG](evidence/r38-v01/overview/flutter-after/overview-1366x768.png) | [PNG](evidence/r38-v01/overview/side-by-side/overview-1366x768.png) | [PNG](evidence/r38-v01/overview/overlay/overview-1366x768.png) | [PNG](evidence/r38-v01/overview/diff/overview-1366x768.png) |
| Empty Engineer Overview | 1024x768 | [PNG](evidence/r38-v01/overview/r38/overview-1024x768.png) | [PNG](evidence/r38-v01/overview/flutter-before/overview-1024x768.png) | [PNG](evidence/r38-v01/overview/flutter-after/overview-1024x768.png) | [PNG](evidence/r38-v01/overview/side-by-side/overview-1024x768.png) | [PNG](evidence/r38-v01/overview/overlay/overview-1024x768.png) | [PNG](evidence/r38-v01/overview/diff/overview-1024x768.png) |
| Empty Engineer Overview | 390x844 | [PNG](evidence/r38-v01/overview/r38/overview-390x844.png) | [PNG](evidence/r38-v01/overview/flutter-before/overview-390x844.png) | [PNG](evidence/r38-v01/overview/flutter-after/overview-390x844.png) | [PNG](evidence/r38-v01/overview/side-by-side/overview-390x844.png) | [PNG](evidence/r38-v01/overview/overlay/overview-390x844.png) | [PNG](evidence/r38-v01/overview/diff/overview-390x844.png) |
| Empty Engineer Overview | 360x800 | [PNG](evidence/r38-v01/overview/r38/overview-360x800.png) | [PNG](evidence/r38-v01/overview/flutter-before/overview-360x800.png) | [PNG](evidence/r38-v01/overview/flutter-after/overview-360x800.png) | [PNG](evidence/r38-v01/overview/side-by-side/overview-360x800.png) | [PNG](evidence/r38-v01/overview/overlay/overview-360x800.png) | [PNG](evidence/r38-v01/overview/diff/overview-360x800.png) |
| Project Creation step 1 | 1440x900 | [PNG](evidence/r38-v01/project-create/r38/project-create-1440x900.png) | [PNG](evidence/r38-v01/project-create/flutter-before/project-create-1440x900.png) | [PNG](evidence/r38-v01/project-create/flutter-after/project-create-1440x900.png) | [PNG](evidence/r38-v01/project-create/side-by-side/project-create-1440x900.png) | [PNG](evidence/r38-v01/project-create/overlay/project-create-1440x900.png) | [PNG](evidence/r38-v01/project-create/diff/project-create-1440x900.png) |
| Project Creation step 1 | 1366x768 | [PNG](evidence/r38-v01/project-create/r38/project-create-1366x768.png) | [PNG](evidence/r38-v01/project-create/flutter-before/project-create-1366x768.png) | [PNG](evidence/r38-v01/project-create/flutter-after/project-create-1366x768.png) | [PNG](evidence/r38-v01/project-create/side-by-side/project-create-1366x768.png) | [PNG](evidence/r38-v01/project-create/overlay/project-create-1366x768.png) | [PNG](evidence/r38-v01/project-create/diff/project-create-1366x768.png) |
| Project Creation step 1 | 1024x768 | [PNG](evidence/r38-v01/project-create/r38/project-create-1024x768.png) | [PNG](evidence/r38-v01/project-create/flutter-before/project-create-1024x768.png) | [PNG](evidence/r38-v01/project-create/flutter-after/project-create-1024x768.png) | [PNG](evidence/r38-v01/project-create/side-by-side/project-create-1024x768.png) | [PNG](evidence/r38-v01/project-create/overlay/project-create-1024x768.png) | [PNG](evidence/r38-v01/project-create/diff/project-create-1024x768.png) |
| Project Creation step 1 | 390x844 | [PNG](evidence/r38-v01/project-create/r38/project-create-390x844.png) | [PNG](evidence/r38-v01/project-create/flutter-before/project-create-390x844.png) | [PNG](evidence/r38-v01/project-create/flutter-after/project-create-390x844.png) | [PNG](evidence/r38-v01/project-create/side-by-side/project-create-390x844.png) | [PNG](evidence/r38-v01/project-create/overlay/project-create-390x844.png) | [PNG](evidence/r38-v01/project-create/diff/project-create-390x844.png) |
| Project Creation step 1 | 360x800 | [PNG](evidence/r38-v01/project-create/r38/project-create-360x800.png) | [PNG](evidence/r38-v01/project-create/flutter-before/project-create-360x800.png) | [PNG](evidence/r38-v01/project-create/flutter-after/project-create-360x800.png) | [PNG](evidence/r38-v01/project-create/side-by-side/project-create-360x800.png) | [PNG](evidence/r38-v01/project-create/overlay/project-create-360x800.png) | [PNG](evidence/r38-v01/project-create/diff/project-create-360x800.png) |

The final 360px scroll-clearance capture proves the last form field and Continue
footer can move completely above the floating navigation: [PNG](evidence/r38-v01/project-create/mobile-bottom-clear-360x800.png).

Machine-readable measurements: [CSV](evidence/r38-v01/pixel-metrics.csv) and
[JSON](evidence/r38-v01/pixel-metrics.json).

## Pixel delta summary

`Changed` is the percentage of pixels whose largest RGB channel delta exceeds
12. MAE is mean absolute channel error on a 0–255 scale.

| Surface | Viewport | Before changed | After changed | Before MAE | After MAE |
|---|---:|---:|---:|---:|---:|
| Shell | 1440x900 | 3.396% | 2.277% | 1.984 | 1.600 |
| Shell | 1366x768 | 4.560% | 3.403% | 2.561 | 2.084 |
| Shell | 1024x768 | 9.069% | 4.513% | 5.901 | 2.698 |
| Shell | 390x844 | 9.748% | 2.759% | 14.213 | 1.465 |
| Shell | 360x800 | 10.351% | 3.057% | 14.790 | 1.604 |
| Overview | 1440x900 | 38.202% | 5.070% | 10.536 | 3.844 |
| Overview | 1366x768 | 40.702% | 6.804% | 11.939 | 4.834 |
| Overview | 1024x768 | 31.102% | 15.282% | 14.113 | 8.910 |
| Overview | 390x844 | 33.386% | 18.496% | 32.773 | 9.959 |
| Overview | 360x800 | 35.389% | 23.235% | 34.444 | 12.268 |
| Project Creation | 1440x900 | 14.827% | 8.390% | 8.576 | 5.190 |
| Project Creation | 1366x768 | 13.780% | 10.623% | 8.315 | 6.043 |
| Project Creation | 1024x768 | 22.613% | 12.889% | 11.456 | 7.674 |
| Project Creation | 390x844 | 28.535% | 19.120% | 25.759 | 10.065 |
| Project Creation | 360x800 | 29.947% | 20.308% | 26.869 | 10.854 |

Every measured viewport improved. The non-zero remainder is documented below;
it must not be represented as pixel parity.

## Workspace shell delta table

| Measure | R38 | Flutter Before | Flutter After | Classification |
|---|---|---|---|---|
| Desktop x/y and size | Sidebar `0/0/260/full`; topbar `260/0/(viewport-260)/64` | Sidebar 246px; topbar began at x=246 | Matches 260px sidebar and 64px topbar at 1440, 1366 and 1024 | Shared component |
| Mobile x/y and size | Topbar `0/0/viewport/56`; nav `10/(h-72)/(w-20)/62` | No R38 topbar; white docked navigation | Matches 56px topbar and 10px floating offsets/62px bar | Shared component |
| Typography | 13px navigation, compact 6.5–7px mobile labels | Larger/mixed shell hierarchy | R38 hierarchy and compact one-line mobile labels | Global token + shared component |
| Padding/gap | Desktop topbar 24px; nav 5px; mobile shell 16px | Wider search/navigation spacing | Matches measured shell density | Global token |
| Border/radius | 1px `#DFE6EE`; nav radius 17px | Heavier/default Material geometry | Matches line and radius | Global token |
| Color | Chrome `#F9FBFD`; mobile nav `rgba(12,37,67,.94)` | White/blue Material navigation | Matches reference chrome/nav tones | Global token |
| Shadow | Mobile `0 18px 50px rgba(11,31,53,.28)` | Default/navigation elevation | Matches R38 floating shadow | Shared component |
| Controls | Six Engineer destinations, one row, equal width, >=44x44 | Overflow destination moved to More/docked bar | Six equal bounded cells; 44x44 minimum; no wrapping/child escape | Intentional production exception + shared component |
| Table row density | Not applicable | Not applicable | Not applicable | Screen local |

## Empty Engineer Overview delta table

| Measure | R38 | Flutter Before | Flutter After | Classification |
|---|---|---|---|---|
| 1440 hero x/y/w/h | Main `286/88/694/234`; snapshot `998/88/416/234` | Main origin about x=282/y=96; left card about 31px narrower | Exact measured card origins/sizes | Screen local built from shared cards |
| 1024 hero x/y/w/h | Main `286/88/415/259`; snapshot `719/88/279/259` | Mobile shell/composition | Persistent office shell and matching two-panel hierarchy | Shared breakpoint + screen local |
| Mobile card geometry | 14px side inset, y=72, 15px radius | Missing R38 topbar and different grouping | Matches inset/origin/radius; content remains stacked | Global token + screen local |
| Typography | Greeting 7px tracked; title 29px desktop/24px mobile; section 17px | Larger legacy heading hierarchy | Matches measured R38 type scale | Global token |
| Padding/gap | Hero 23px desktop; 24px section gap; 8–10px local gaps | Excess vertical space and wider actions | R38 density and action alignment | Global token + shared component |
| Border/radius | 1px line, 15px cards, 12px stat tiles | Default Material cards | Matches contract | Global token |
| Color | Desktop `#EEF3F8`, mobile `#F3F6FA`, soft tile `#F5F8FC` | Flatter/whiter canvas | Matches reference canvas and tiles | Global token |
| Shadow | Card `0 8px 24px rgba(20,50,85,.043)` | Default elevation | Matches soft R38 elevation | Global token |
| Controls | R38 buttons 38px | 48px legacy actions | 38px desktop; 44px mobile semantic controls | Intentional production exception on mobile |
| Empty-panel density | R38 empty content begins about 42px inside card | Vertically centered too low | Top-aligned 42px rhythm and matching card height | Shared empty-state component |
| Table row density | Not applicable | Not applicable | Not applicable | Screen local |

At 360px, the 44px production controls make the hero end 17px below the
literal 38px-control R38 card. The following snapshot begins 19px lower and the
Needs Your Action heading 7px lower after the stacked layout absorbs the
difference. This is intentional accessibility geometry, not an unmeasured
miss.

## Project Creation step 1 delta table

| Measure | R38 | Flutter Before | Flutter After | Classification |
|---|---|---|---|---|
| 1440 frame x/y/w/h | `290/190/1120/670` | About `282/209/1120/670`; wider legacy rail | `290/190/1120/670` | Screen local + shared frame |
| 1024 frame x/y/w/h | `290/190/704/680`; columns 230/472 | Collapsed/mobile hierarchy | Matches persistent side rail and bounded two-column body | Shared breakpoint + frame |
| Mobile frame | x=14; width 362/332 | Navigation outside the framed hierarchy | x=14; width 362/332; navigation inside frame | Shared frame |
| Typography | H1 29/24px; stage H2 22/20px; labels 10.5px; inputs 11.5px | Larger legacy labels/controls | Matches R38 hierarchy | Global token |
| Padding/gap | Page 30px desktop/14px mobile; body 24x20; form gap 15px | Wider body and inconsistent run gaps | Matches contract | Global token + shared form |
| Border/radius | 1px line; 15px frame; 9px controls | Default Material form treatment | Matches R38 geometry | Global token |
| Color | Rail `#F5F8FC`, white body, pale-blue active stage | Flatter legacy rail | Matches reference | Global token |
| Shadow | `0 4px 16px rgba(25,48,78,.06)` | Default elevation | Matches soft frame shadow | Global token |
| Desktop controls | Input/date 36px; textarea 88px | Text fields painted about 25px inside larger boxes; prior form controls 48px | Painted and semantic bounds are 36px; textarea 88px | Shared form component |
| Mobile controls | Literal R38 input/active step 36–38px | Mixed 48px controls | 44px input, stage and action targets | Intentional production exception |
| Date layout | Three segments + calendar, 6px gaps; R38 clips at 1024 | Different picker hierarchy | Same hierarchy; Wrap prevents overflow; helper text remains legible | Intentional production exception + shared component |
| Form-row density | Two 15px-gapped columns desktop; one column mobile | Different ordering/density | Matches allowed-field order and R38 rhythm | Screen local |
| Table row density | Not applicable | Not applicable | Not applicable | Screen local |

The Engineer form deliberately omits the R38 Client Payment Terms control and
reserves its row rhythm without exposing a field or value. Commercial response
shape and authorization remain authoritative. The current Flutter date picker
remains controller-backed; no HTML JavaScript date-entry behavior was copied.

## Remaining differences

1. The current tracked Yorks geometric-Y brand asset differs from the circular
   seal in R38. V01 did not overwrite the separately changing branding asset.
2. R38 shows an Accounts global navigation destination. Accounts is now
   explicitly in the target contract, but V01 does not invent a route or bypass
   current role/route guards; its authorized project-workspace implementation
   remains a later, separately gated slice.
3. R38 says `Workspace saved`/`Saved just now`; Flutter shows its real connected
   status and local draft autosave state. Server confirmation wording is not
   copied from prototype state.
4. Flutter's platform text rasterization, icons and Arabic-capable font fallback
   produce residual anti-aliasing differences.
5. Mobile controls intentionally remain at least 44x44, so vertical geometry is
   slightly taller than the literal prototype.

No backend, repository, RPC, RLS, schema, quantity, permission, idempotency,
audit, workflow-state or controlled-document logic changed in V01.

## Verification gates

| Gate | Result |
|---|---|
| Dart formatting, changed files | Pass; no formatting changes required |
| `flutter analyze` | Pass; no issues |
| Focused shell/overview/project-creation tests | Pass; 22 tests |
| Focused operational-layout and user-provisioning regression tests | Pass; 19 tests |
| Full `flutter test` | Pass; 532 tests |
| CI-configured Flutter web build | Pass; `build/web` |
| Ephemerally signed CI Android release build | Pass; 81.8 MB APK |
| Local `supabase db reset --local` | Pass; all 37 tracked migrations and seed replayed |
| Local `supabase test db --local` | Pass; 15 files, 440 pgTAP tests |

The compile gates use `https://ci.invalid` and a non-secret CI publishable-key
placeholder. The database gates target only the repository's local Supabase
containers. No production system was queried, changed or deployed.
