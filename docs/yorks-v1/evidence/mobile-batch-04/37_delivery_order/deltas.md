# Ref 37 — Delivery Order

Artifacts: reference, both after viewports, side-by-side, overlay, and diff.

Pixel diagnostic: MAE **23.70/255**, RMS **56.76/255**, pixels above 16:
**20.31%**, above 32: **16.05%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Document preview | stylized mobile document | branded four-column immutable revision preview | screen local |
| Quantities | prototype delivery facts | committed dispatch snapshot quantities | intentional production exception |
| Arabic/header | pack company header | correct RTL legal name and emblem with a load-safe seal fallback | screen local |
| Actions | share/print/store | real PDF/print and feature-gated controlled version upload | intentional production exception |

Receipt outcome is deliberately absent: Product Decision 18 requires the
Delivery Order to snapshot committed dispatch quantities immediately after
dispatch. Commercial values are also absent.
