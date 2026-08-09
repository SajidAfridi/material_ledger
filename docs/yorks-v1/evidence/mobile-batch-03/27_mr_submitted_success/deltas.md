# Ref 27 — Submitted confirmation

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable. This surface is created only after the existing
connected `saveAndSubmit` command returns a server record.

Pixel diagnostic: MAE **18.96/255**, RMS **52.53/255**, pixels above 16:
**12.59%**, above 32: **9.45%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Completion panel | full-height bordered sheet | compact success card centered in the real route | screen local |
| Copy/reference | `MR-018` sample and traceability copy | server-returned `YRA-322-MR101` and authoritative confirmation copy | intentional production exception |
| Actions | one primary and text back action | two bounded actions: View request and Back to requests | shared component |
| Safe area/color | prototype shell | current shell-safe route with shared tokens | global token / shared component |

The 360 after capture keeps both actions visible above the safe area. No 360
reference was supplied.
