# Ref 39 — Material Return review

Artifacts: reference, both after viewports, side-by-side, overlay, and diff.

Pixel diagnostic: MAE **13.66/255**, RMS **39.59/255**, pixels above 16:
**14.99%**, above 32: **9.07%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Lines | selected prototype rows | selected real candidate and bounded quantity | intentional production exception |
| Notes | optional note | existing draft note field | screen local |
| Primary action | submit prototype | Save draft until the server returns a submittable version | intentional production exception |
| Stock consequence | short helper | Procurement confirmation explicitly precedes inventory change | intentional production exception |

The screen never claims stock was returned after draft save or Engineering
submit. Retry identity is retained until server confirmation.
