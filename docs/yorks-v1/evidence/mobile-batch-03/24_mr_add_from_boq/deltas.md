# Ref 24 — Add from BOQ

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. The after fixture contains five folders from
one selected real scope; a zero-row folder is rendered disabled rather than
being made a selectable source.

Pixel diagnostic: MAE **17.14/255**, RMS **51.38/255**, pixels above 16:
**16.27%**, above 32: **9.53%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Scope title/tabs | DF3W eyebrow and Folders/Materials/Selected tabs | compact scope-safe folder picker | screen local |
| Folder rows | one grouped list with selected/empty chips | individual 15px Yorks cards and an honest disabled Empty folder | shared component |
| Selection | reference sample starts with 3 selected | current starts unselected; selected row IDs come only from the existing draft | intentional production exception |
| Source boundary | prototype presentation | existing repository query is scoped and never calls aggregate Overview | intentional production exception |
| Color/shadow | prototype blue/navy | shared Yorks mobile tokens | global token |

The 360 capture has no overflow and preserves a one-row, real-scope selection
flow. It is adaptive evidence only.
