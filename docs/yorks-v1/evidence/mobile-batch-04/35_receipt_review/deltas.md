# Ref 35 — Receipt review

Artifacts: reference, both after viewports, side-by-side, overlay, and diff.

Pixel diagnostic: MAE **22.33/255**, RMS **54.36/255**, pixels above 16:
**23.96%**, above 32: **13.13%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Initial state | prototype choices | every line visibly Pending with no selected outcome | intentional production exception |
| Bulk action | receive all | explicit user action fills Received/full quantity | screen local |
| Line control | Received/Missing/Damaged | equal-width 44px outcome control | shared component |
| Confirm | prototype footer | disabled until every line is explicitly reviewed | intentional production exception |

This intentionally rejects a misleading preselected “Received” state. The
360×800 fixture proves both cards and the disabled final action remain visible.
