# Ref 12 — Create Project: Review

Assessment: the production-backed review state is visually close to the R38
composition, but measurable spacing, type and control differences remain.
Pixel parity is not claimed.

## Artifact provenance

- [R38 reference, 390×844](reference-390x844.png) — existing normalized pack
  raster, SHA-256
  `73a8d85ef618005059c3eeb57d7af0e9a313235125b02eb209a4296dc4db0455`.
  The file is JPEG-encoded despite its historical `.png` suffix, so small
  compression deltas are present in pixel statistics.
- [Flutter after, 390×844](flutter-after-390x844.png) — exact RGB copy of
  `test/goldens/mobile_batch2/project_review_390x844.png`, SHA-256
  `e05ecfbec82cefe0a29cfda86cc3c4de04004511aa1a8b4e491f368af07b0618`.
- [Side by side, 390×844](side-by-side-390x844.png),
  [50% alpha overlay](alpha-overlay-390x844.png), and
  [4× RGB pixel diff](pixel-diff-390x844.png).
- [Flutter adaptive capture, 360×800](flutter-after-360x800.png) — exact RGB
  copy of the deterministic 360 golden, SHA-256
  `fb15409e99b2152cd61fa861285e551dea5e08b989f212905f8413ff40e108f7`.
  The pack has no canonical 360 reference, so no 360 reference, overlay, diff
  or side-by-side was created.
- Flutter Before: unavailable. No deterministic pre-convergence mobile Review
  artifact exists with equivalent fixture and state. The legacy creation and
  Attachments goldens are different surfaces and were not substituted.

## Pixel summary at 390×844

The RGB mean absolute error is **9.71/255**, RGB RMS error is **31.91/255**,
**10.59%** of pixels have a maximum-channel delta greater than 16, and
**6.36%** exceed 32. The raw difference spans the full viewport because the
reference renders simulated OS status glyphs while the Flutter test owns only
the safe-area pixels.

## Measurable deltas

| Category | R38 reference | Flutter after | Delta | Classification |
|---|---|---|---|---|
| App bar position/size | `x0 y26`, `390×54` | `x0 y26`, `390×54` | Exact application bar geometry | shared component |
| OS status content | Simulated `9:41` and system glyphs in `y0–25` | Blank 26px safe area | Glyphs intentionally not app-rendered | intentional production exception |
| Stepper position/size | `x14 y94`, `362×61` | `x0 y80`, `390×72` | `x −14`, `y −14`, `w +28`, `h +11` | shared component |
| Page title type | 25px / 29px | 21px / 25.2px | `−4px` size, `−3.8px` line box | global token |
| Main content padding | 14px horizontal | 14px horizontal | Exact | shared component |
| Review-card white-fill bounds | `x15 y260`, `360×195` | `x15 y239`, `360×245` | `y −21`, `h +50` | screen-local |
| Summary grid | Two columns; nominal 8px gaps | Two columns; 8px cross/main gaps | Column count and gaps exact | screen-local |
| First metric fill | `x29 y307`, `162×39` | `x29 y319`, `162×45` | `y +12`, `h +6` | screen-local |
| Metric radius | 9px | 10px | `+1px` | shared component |
| Success callout | `x14 y456`, about `362×79` | `x14 y496`, about `362×97` | `y +40`, `h +18` | screen-local |
| Callout icon/type | 34px icon; 10px / 15px body | 44px icon; 12px / 17.4px body | Icon `+10px`; body `+2px` | shared component |
| Card border/radius | 1px `#DFE6EE`; 15px | 1px `#DFE6EE`; 15px | Exact | shared component |
| Card shadow | `0 8px 24px rgba(20,50,85,.055)` | `0 8px 20px rgba(25,48,78,.059)` | Blur `−4px`; comparable alpha | shared component |
| Canvas/soft colors | `#F3F6FA` / `#F5F8FC` source tokens | `#F3F6FA` / `#F5F8FC` | Token intent exact; reference JPEG adds noise | global token |
| Sticky buttons | 40px visual height, 8px gap | 44px visual height, 8px gap | Height `+4px`; gap exact | intentional production exception |
| Button presentation | Text-only Back/Create Project | Back arrow; create/document icon; localized sentence case | Extra icons and casing differ | screen-local |

## Remaining differences

- The full-width stepper begins immediately below the app bar instead of
  sitting inside the 14px content inset. This is a **shared component** delta.
- The settled high-text-scale layout keeps all six metrics readable without
  clipping, but its 45px metric fills contribute to a review card that is 50px
  taller than the reference. The three-line outcome message also remains one
  line taller than the reference. These combine the recorded **global token**,
  **shared component** and **screen-local** deltas; they are not hidden by the
  capture.
- The 44px actions deliberately exceed the 40px pack controls to preserve the
  minimum touch target. This is an **intentional production exception**.
- The displayed Ready state comes from loaded directory data and valid draft
  input; creation remains server-confirmed. This is an **intentional production
  exception** to treating prototype text as state authority.

## 360×800 adaptive acceptance

The adaptive capture keeps the two-column summary, complete success callout,
44px actions and bottom safe inset visible with no horizontal overflow. It is
accepted as adaptive evidence only; it is not a comparison or parity claim.
