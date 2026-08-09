# Ref 16 — Building BOQ folders

This evidence compares the exact 390×844 pack reference with the current
controller-backed Flutter fixture. It is evidence of remaining deltas, not a
pixel-parity claim.

## Artifacts

- `reference-390x844.png` — approved pack reference.
- `flutter-after-390x844.png` — current Flutter golden, byte-identical to
  `test/goldens/mobile_batch2/boq_building_folders_390x844.png`.
- `side-by-side-390x844.png` — labelled reference/after comparison.
- `alpha-overlay-390x844.png` — 50/50 alpha overlay at the exact viewport.
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive Flutter evidence only.

No genuine prior Flutter artifact exists for this selected-building folder
state. The older scoped-BOQ golden is the different **Overview** aggregate
state, so it is not presented as “Flutter Before”.

## Measured 390×844 deltas

Pixel diagnostic: 85.23% of pixels differ; mean absolute RGB-channel delta is
24.47/255. This includes shell, fixture-data and intentional truth-model
differences.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| Top chrome | 26px status + 54px app bar | 26px safe area + 56px Material toolbar | +2px | shared component |
| Scope selector | absent on this screen | horizontal rail at y=90, h=58 | +58px control | shared component |
| Page inset/title | x=14; y≈104; 25px title | x=16; y≈201; 26px title | +2px x, +97px y, +1px type | screen local |
| Filter controls | y≈199; h=31 | y≈252; h=44 | +53px y, +13px h | intentional production exception |
| Folder surface | one x=14, w=362 list | separate x=17, w=356 cards | +3px x, −6px w | shared component |
| Folder density | 62px rows, no gap | 88px minimum cards, 8px gap | +26px row, +8px gap | shared component |
| Border/radius/shadow | #DFE6EE, 15px, 0 8px 24px soft shadow | #DFE6EE, 15px, 0 8px 24px soft shadow | materially aligned | global token |
| Canvas/text | dominant #F5F6FA / #1A2B47 | #EEF3F8 / #132033 | token shift | global token |
| Folder status | “Ready” / “Not started” chips | no inferred readiness chip | removed | intentional production exception |
| Counts/data | 29 / 18 / 11; six visible rows | 6 / 5 / 1; real fixture counts | state differs | screen local |
| Bottom action/navigation | 82px four-destination nav | 56px New Group FAB; shell nav outside this isolated golden | different composition | shared component |

The 44px filters intentionally exceed the prototype's 31px controls to meet
the production minimum semantic hit target. Readiness is deliberately not
invented from row count; only truthful Started/Empty filtering is shown.

## 360×800 adaptive acceptance

The pack contains no canonical 360 reference, so no overlay or pixel diff was
fabricated. The 360 golden was visually inspected: the title uses bounded
ellipsis, the scope rail remains horizontally scrollable, filters remain 44px,
and the folder list remains vertically scrollable around the FAB. No render
overflow was recorded by the golden test.
