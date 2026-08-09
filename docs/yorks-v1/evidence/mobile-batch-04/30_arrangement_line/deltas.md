# Ref 30 — Arrangement line detail

Artifacts: `reference-390x844.png`, both Flutter-after viewports, labelled
side-by-side, alpha overlay, and pixel diff.

Pixel diagnostic: MAE **13.42/255**, RMS **39.76/255**, pixels above 16:
**13.41%**, above 32: **8.16%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Decision control | three compact options | equal-width 44px Full/Partial/Cannot Provide control | shared component |
| Source and quantity | static example | real source, inventory availability, quantity and optional cost controls | intentional production exception |
| Quantity rule | short prototype hint | explicit arranged/requested cap and warehouse recheck | intentional production exception |
| Footer | previous/next | fixed Previous and Save & Next above safe area | shared component |

The 360 adaptation ellipsizes only the longest segmented label; the semantic
tap target remains 44px and every field remains scroll-reachable.
