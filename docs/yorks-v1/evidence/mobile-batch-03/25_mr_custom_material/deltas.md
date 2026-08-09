# Ref 25 — Custom material

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. The after screen writes only to the existing
draft controller; it cannot create or mutate a BOQ row.

Pixel diagnostic: MAE **14.93/255**, RMS **41.49/255**, pixels above 16:
**14.78%**, above 32: **9.31%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Field order | description, size, model, make, quantity, reason | description, brand/origin, size, model/tag, quantity/unit | intentional production exception |
| Reason controls | prototype-only unplanned-material reason | no corresponding trusted MR schema field is invented | intentional production exception |
| Inputs | tall standalone controls | compact grouped controller-backed fields | screen local |
| Actions | full-width navy add button | bounded Back + Add custom item bar, 44px targets | shared component |
| Type/color/radius | prototype tokens | shared Yorks token system | global token |

At 360×800 the form scrolls fully above its sticky action bar; no source image
exists for a literal 360 diff.
