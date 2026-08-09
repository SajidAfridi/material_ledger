# Ref 23 — New MR information

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. The after image is byte-identical to the Batch
3 information golden and shows the real private-draft controller state.

Pixel diagnostic: MAE **16.86/255**, RMS **44.14/255**, pixels above 16:
**18.83%**, above 32: **12.28%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Header/progress | large new-request heading and segmented control | compact feature bar and three-step controller progress | shared component |
| Project/scope | selector rows | actual project/scope dropdowns populated from authorised projections | intentional production exception |
| Timing/date | prototype shows required date independently | current workflow requires a date only for Scheduled timing | intentional production exception |
| Insets/fields | x≈14–28, 52px controls | x=14–28, 40–48px controls | screen local |
| Color/radius/shadow | navy primary/soft 14px cards | current shared token palette/15px surface | global token |

At 360×800 the content and fixed Continue control remain above the safe area;
no literal 360 comparison is claimed.
