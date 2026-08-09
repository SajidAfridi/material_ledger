# Ref 13 — Project Overview

Assessment: the hierarchy and principal dimensions converge, while the
production exceptions for progress, Accounts and authoritative record data
create substantial pixel differences. Pixel parity is not claimed.

## Artifact provenance

- [R38 reference, 390×844](reference-390x844.png) — existing normalized pack
  raster, SHA-256
  `6b720480b780f5e3c7226382f246de237866d0bc5284d6335ebdbc5924b27e44`.
  It is JPEG-encoded despite its historical `.png` suffix.
- [Flutter after, 390×844](flutter-after-390x844.png) — exact RGB copy of
  `test/goldens/mobile_batch2/project_overview_390x844.png`, SHA-256
  `3ee62edb38ee012481630a89471313fa710e29b4aa8018008532bde12296a6e1`.
- [Side by side, 390×844](side-by-side-390x844.png),
  [50% alpha overlay](alpha-overlay-390x844.png), and
  [4× RGB pixel diff](pixel-diff-390x844.png).
- [Flutter adaptive capture, 360×800](flutter-after-360x800.png) — exact RGB
  copy of the deterministic 360 golden. No canonical 360 pack reference
  exists; no 360 reference or comparison image was fabricated.
- Flutter Before: unavailable. `v7_project_workspace_mobile.png` is a different
  legacy workflow and fixture, not an equivalent prior render, so it was not
  relabelled as Before.

## Pixel summary at 390×844

The RGB mean absolute error is **16.17/255**, RGB RMS error is **41.92/255**,
**26.74%** of pixels have a maximum-channel delta greater than 16, and
**9.88%** exceed 32. These numbers include the intentional removal of weighted
progress and the use of real Material Request rows instead of prototype events.

## Measurable deltas

| Category | R38 reference | Flutter after | Delta | Classification |
|---|---|---|---|---|
| App bar position/size | `x0 y26`, `390×54` | `x0 y26`, `390×54` | Exact | shared component |
| OS status content | Simulated status glyphs | Blank 26px safe area | OS chrome is not app-rendered | intentional production exception |
| Hero bounds | `x14 y94`, `362×135` | `x14 y94`, `362×117` | `h −18`; x/y/width exact | intentional production exception |
| Hero title type | 22px / 26px | 22px / 25.96px | Effectively exact | screen-local |
| Hero gradient | `#0D2F57 → #174F87` | `#0D2F57 → #123F73` | End stop `ΔRGB(−5,−16,−20)` | global token |
| Hero progress | 5px track plus label/value | Absent | 18px hero-height reduction | intentional production exception |
| Project tabs | Five 39px tabs | Four 44px equal-width tabs | `h +5`; each tab about `+18px` wider | intentional production exception |
| Active tab rule | 2px blue | 2px blue | Thickness exact; width follows tab count | shared component |
| KPI grid outer geometry | `x14`, 362px; 2 columns; 9px gap; 82px rows | Same | Width, columns, gap and row height exact | shared component |
| KPI top position | About `y294` | About `y305` | `y +11` | screen-local |
| KPI typography | Label 9px / `.8px`; value 22px / 27px | Label 9px / `.75px`; value 24px / 28.3px | Value `+2px`; tracking `−.05px` | global token |
| Attention-list white fill | `x15 y514`, `360×140` | `x15 y550`, `360×141` | `y +36`; height within 1px | screen-local |
| Attention row density | About 70px per row | About 70px per row | Effectively exact | shared component |
| List shadow | `0 8px 24px rgba(20,50,85,.055)` | No list shadow | Shadow removed | shared component |
| Recent section | Header around `y678`; one row visible | Header around `y725`; rows below first fold | Header `y +47` | screen-local |
| Bottom navigation | `x10 y770`, `370×64`; 4 equal items | `x10 y770`, `370×64`; 4 equal items | Geometry exact | shared component |
| Record content | Mock MR, delivery and activity entries | Authorized MR numbers, states, scope, count and owner | Text/entity content intentionally differs | intentional production exception |

## Remaining differences

- Weighted project completeness is absent by product contract, so the hero is
  18px shorter. This is an **intentional production exception**, not a missing
  UI implementation.
- Accounts is not rendered because this fixture has no implemented and
  authorized Accounts destination. This is an **intentional production
  exception**; the four remaining destinations divide the tab width equally.
- The prototype's mixed delivery/activity rows are not invented. The current
  view renders authorized Material Request data and truthful owners, an
  **intentional production exception**.
- Recent Material Requests starts lower and is below the first viewport. Its
  position is a **screen-local** density delta; the scroll content remains
  available above the fixed navigation.
- The darker Flutter gradient end stop and nav hue remain a **global token**
  delta. The list's absent ambient shadow is a **shared component** delta.

## 360×800 adaptive acceptance

The adaptive capture preserves the hero, four equal tabs, 2×2 KPI grid, two
attention rows and one-row `340×64` bottom navigation. Long owner text
ellipsizes rather than wrapping or escaping. This is adaptive acceptance only;
there is no 360 visual-reference comparison.
