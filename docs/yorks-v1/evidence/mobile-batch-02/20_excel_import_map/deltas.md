# Ref 20 — Excel import: Map

This compares the exact 390×844 pack reference with the current editable
mapping step. It records remaining deltas and does not claim pixel parity.

## Artifacts

- `reference-390x844.png`
- `flutter-after-390x844.png` — byte-identical to the current
  `boq_import_map_390x844.png` golden.
- `side-by-side-390x844.png`
- `alpha-overlay-390x844.png`
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive evidence only.

No equivalent prior Flutter map-step artifact was found; “Flutter Before” is
unavailable.

## Measured 390×844 deltas

Pixel diagnostic: 67.10% changed pixels; mean absolute RGB-channel delta
15.83/255.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| App-bar title | “Map Columns” | “Map” | shorter step title | screen local |
| Top chrome | 80px | 82px | +2px | shared component |
| Stepper | x=14, y=94, w=362, h=61; 25px nodes | x=0, y=82, w=390, h=78; 40px nodes | −14px x, +28px w, +17px h | shared component |
| Heading | x=14, y≈166; title 25px | x=14, y≈212; title 30px | +46px y, +5px type | global token |
| Mapping region | x=14, y≈279, w=362; six ≈70px summary rows | x=15, y=320, w=360; paired ≈40px input/select controls | +41px y; interaction changed | screen local |
| Mapping affordance | Mapped chip + chevron | directly editable heading + canonical dropdown | interactive instead of summary | screen local |
| Arbitrary column | explanatory callout only | “Air flow (L/s)” retained with “Keep as worksheet-only column” | explicit preservation | intentional production exception |
| Visible density | six mapped rows + callout | five complete mappings plus arbitrary-column controls; scroll continues | different composition | screen local |
| Bottom controls | ≈62px, “Back / Review Import”, navy primary | 76px, “Previous / Continue”, blue primary | +14px; labels/colors differ | shared component |
| Surface/border/radius | #F5F6FA, #DFE6EE, 15px | #F3F6FA, #DFE6EE, 10–15px controls | token/shape shift | global token |

Direct mapping controls are retained because arbitrary headings must be
reviewable without silently dropping data. No mutation occurs on this step.

## 360×800 adaptive acceptance

The pack provides no canonical 360 reference. The 360 golden keeps every
heading/mapping pair within 15px insets, exposes remaining mappings through
vertical scrolling, and keeps Previous/Continue in one bounded row. No 360
diff was fabricated and no render overflow was recorded.
