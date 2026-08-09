# Ref 34 — Dispatch entry

Artifacts: reference, both after viewports, side-by-side, overlay, and diff.

Pixel diagnostic: MAE **15.84/255**, RMS **42.10/255**, pixels above 16:
**19.59%**, above 32: **12.18%**.

| Category | Reference | Flutter after | Classification |
|---|---|---|---|
| Dispatch facts | prototype document/date fields | real reference, date, driver and vehicle inputs | screen local |
| Items | sample approved rows | server-projected outstanding, approved and warehouse availability | intentional production exception |
| Protection | stock hint | explicit transaction-time availability recheck | intentional production exception |
| Action | dispatch total | live positive quantity total and trusted command | shared component / screen local |

The UI never presents more than the server-projected outstanding quantity as
dispatchable; the database remains final authority.
