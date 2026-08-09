# Ref 28 — Material Request lifecycle

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. The after capture uses the authenticated
Material Request detail projection, not a synthetic lifecycle/audit feed.

Pixel diagnostic: MAE **25.59/255**, RMS **63.65/255**, pixels above 16:
**23.12%**, above 32: **15.04%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Header summary | status, requester and timing metrics | request state, number, project context and server-safe status chip | intentional production exception |
| Timeline | illustrative actor/status audit rows | current five-stage workflow and current owner/next action only | intentional production exception |
| Recent activity | sample historical events | no event/actor is invented when an authorised audit projection is unavailable | intentional production exception |
| Actions | menu in prototype | only the existing resolved primary action is rendered; absent workspace means no Arrange action | intentional production exception |
| Geometry/type/color | dense prototype cards and shell | shared Yorks phone components | screen local / global token |

At 360×800 the timeline is vertically scrollable and no action, table, or
footer is obscured by the shell navigation. No 360 source image exists.
