# Ref 21 — Excel import: Review

This compares the exact 390×844 pack reference with the current immutable
preview review step. It is a delta record, not a pixel-parity claim.

## Artifacts

- `reference-390x844.png`
- `flutter-after-390x844.png` — byte-identical to the current
  `boq_import_review_390x844.png` golden.
- `side-by-side-390x844.png`
- `alpha-overlay-390x844.png`
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive evidence only.

No genuine prior Flutter review-step artifact exists; “Flutter Before” is
unavailable.

## Measured 390×844 deltas

Pixel diagnostic: 79.35% changed pixels; mean absolute RGB-channel delta
15.84/255. Fixture data and validation state are included.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| App-bar title | “Review Import” | “Review” | shorter step title | screen local |
| Top chrome | 80px | 82px | +2px | shared component |
| Stepper | x=14, y=94, w=362, h=61; 25px nodes | x=0, y=82, w=390, h=78; 40px nodes | −14px x, +28px w, +17px h | shared component |
| Heading | x=14, y≈166; title 25px | x=14, y≈212; title 30px | +46px y, +5px type | global token |
| KPI cards | two columns, ≈80px high | two columns, ≈112px high | +≈32px h | shared component |
| KPI state | 22 rows, 7 columns, 2 warnings, 0 fatal | 2 rows, 5 columns, 4 mapped, 0 fatal | fixture/metric differs | screen local |
| Warning block | 2-value amber warning, h≈78 | absent because fixture has no validation issues | removed by state | intentional production exception |
| Review summary | two ≈62–80px list rows with Ready chips | one x=15, y=553, w=360, h≈125 combined card | composition differs | screen local |
| Preservation copy | “No data will be dropped” | “no source column will be dropped” | equivalent guarantee | intentional production exception |
| Bottom action | ≈62px, “Back / Import 22 Materials”, navy | 76px, “Previous / Import 2 Materials”, blue | +14px; fixture count/color | shared component |
| Canvas/border/radius | #F5F6FA, #DFE6EE, 13–15px | #F3F6FA, #DFE6EE, 15px | close token family | global token |

The current no-warning state is truthful to the selected workbook. The preview
remains open on import failure/conflict, and the controller mutates only after
the final Import action.

## 360×800 adaptive acceptance

There is no canonical 360 reference. Visual inspection confirms the 2×2 KPI
grid, summary card and Previous/Import actions remain bounded and readable;
longer content can scroll above the fixed action bar. No 360 diff was
fabricated and no render overflow was recorded.
