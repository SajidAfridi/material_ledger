# Ref 26 — Review and submit

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. The after view uses the actual selected project,
scope, timing and draft line count, and keeps Submit disabled until the local
workflow validation and explicit review confirmation are true.

Pixel diagnostic: MAE **15.53/255**, RMS **43.48/255**, pixels above 16:
**16.80%**, above 32: **9.44%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Summary | two-by-two facts plus BOQ/custom/suggested metrics | single truthful request facts surface | intentional production exception |
| Review controls | two visual toggles | one explicit review confirmation matching current workflow command | intentional production exception |
| Suggested quantity | sample warning metric | only shown when a real draft line has `quantityIsSuggested` | intentional production exception |
| Fixed actions | navy 50px split bar | shared 44px-safe action bar and disabled submit state | shared component |
| Geometry/type/color | prototype density/tokens | current shared mobile components | screen local / global token |

The adaptive 360 screen maintains bounded controls and scrollable content; no
literal 360 source comparison is asserted.
