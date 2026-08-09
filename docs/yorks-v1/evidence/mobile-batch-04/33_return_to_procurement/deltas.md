# Ref 33 — Return to Procurement

Artifacts: reference, both after viewports, side-by-side, overlay, and diff.

Pixel diagnostic: MAE **14.70/255**, RMS **43.13/255**, pixels above 16:
**13.77%**, above 32: **10.05%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Reason form | category plus note | one required reason matching the existing RPC contract | intentional production exception |
| Guidance | return consequence | new editable version and immutable history explained | screen local |
| Actions | cancel/return | bounded localized Cancel/Return | shared component |

No unpersisted “reason category” was invented. Empty text cannot invoke the
trusted return decision.
