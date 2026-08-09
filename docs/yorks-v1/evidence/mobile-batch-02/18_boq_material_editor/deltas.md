# Ref 18 — Focused BOQ material editor

This compares the supplied exact 390×844 reference PNG with the current
dynamic, controller-backed Flutter editor. It intentionally does not claim
pixel parity.

## Artifacts

- `reference-390x844.png`
- `flutter-after-390x844.png` — byte-identical to the current
  `boq_material_editor_390x844.png` golden.
- `side-by-side-390x844.png`
- `alpha-overlay-390x844.png`
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive evidence only.

No genuine prior focused-row Flutter editor artifact exists; “Flutter Before”
is unavailable.

## Measured 390×844 deltas

Pixel diagnostic: 78.90% changed pixels; mean absolute RGB-channel delta
16.87/255.

The supplied reference PNG itself visibly presents a 2×-scale/right-edge crop:
its app-bar title, copy and fields continue beyond x=390. The comparison keeps
that exact file, while Flutter deliberately does not reproduce the clipping.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| Top chrome | visible region h≈195 with cropped title/trailing Save | 26px safe area + 56px toolbar = 82px | −≈113px visible scale | intentional production exception |
| Body inset | x≈28, controls extend past x=390 | x=15 to 375, w=360 | fully bounded | intentional production exception |
| Page title | visually ≈48px in supplied PNG | 30px | −≈18px | screen local |
| Field value type | visually ≈25px in supplied PNG | 16px | −≈9px | screen local |
| Field height | visible reference fields ≈88–90px | Flutter fields ≈40px | −≈49px | shared component |
| Field spacing | ≈28px label-to-next-field rhythm | 16px field rhythm | −≈12px | screen local |
| Field model | fixed prototype fields | dynamic canonical and arbitrary columns | data-driven | intentional production exception |
| Model identity | “Model / Serial No.” conflated | Model and Equipment Tag are separate | split fields | intentional production exception |
| Commercial field | Unit Cost appears later in prototype | omitted without capability | removed | intentional production exception |
| Navigation/save | app-bar Save only | fixed 76px Previous / Next / Save bar | added navigation | screen local |
| Canvas/border | #F5F6FA, light field line | #F3F6FA, #DFE6EE | close token family | global token |

The production exceptions preserve responsive legibility, arbitrary imported
columns, canonical data separation and the commercial capability boundary.

## 360×800 adaptive acceptance

There is no canonical 360 reference. The 360 golden keeps every form control
inside 15px side insets and the Previous/Next/Save bar bounded to one row. The
remaining fields are reached by vertical scrolling above that bar. No 360 diff
was fabricated and no render overflow was recorded.
