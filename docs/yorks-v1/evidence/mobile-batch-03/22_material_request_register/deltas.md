# Ref 22 — Material Request register

Artifacts: `reference-390x844.png`, `flutter-after-390x844.png`,
`flutter-after-360x800.png`, `side-by-side-390x844.png`,
`alpha-overlay-390x844.png`, `pixel-diff-390x844.png`.

Flutter Before is unavailable for this exact authorized fixture. The current
after image is byte-identical to `mr_register_390x844.png` in the Batch 3
golden suite.

Pixel diagnostic: MAE **23.72/255**, RMS **60.97/255**, pixels above 16:
**21.03%**, above 32: **14.10%**.

| Category | R38 reference | Flutter after | Delta classification |
|---|---|---|---|
| Top chrome | shell menu/search/add | feature header with back/refresh; shell navigation is outside this isolated capture | shared component |
| Status filters | one tab row plus context chips | controller-backed status pills, with full server state copy | screen local |
| Cards | five compact sample records | two authorised fixture records with owner-safe data | intentional production exception |
| Card geometry | x≈15, w≈360, h≈72 | x=14, w=362, h≈160 | screen local |
| Typography/color/shadow | navy hierarchy, low-density cards | Yorks shared type/token system, 15px radius, 0/8/24 shadow | global token / shared component |

At 360×800 the row remains scrollable with bounded 44px filters and actions;
there is no canonical 360 source to diff.
