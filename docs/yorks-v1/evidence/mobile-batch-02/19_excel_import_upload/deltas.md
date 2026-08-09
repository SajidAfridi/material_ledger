# Ref 19 — Excel import: File

This compares the exact 390×844 pack reference with the current preview-only
Flutter import flow. It documents remaining differences rather than claiming
pixel parity.

## Artifacts

- `reference-390x844.png`
- `flutter-after-390x844.png` — byte-identical to the current
  `boq_import_upload_390x844.png` golden.
- `side-by-side-390x844.png`
- `alpha-overlay-390x844.png`
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive evidence only.

No prior Flutter full-screen File/Sheet/Map/Review artifact exists; “Flutter
Before” is unavailable.

## Measured 390×844 deltas

Pixel diagnostic: 74.08% changed pixels; mean absolute RGB-channel delta
17.96/255.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| App-bar title | “Import Excel” | “File” | step-name title | screen local |
| Top chrome | 26px + 54px = 80px | 26px + 56px = 82px | +2px | shared component |
| Stepper | x=14, y=94, w=362, h=61; 25px nodes | x=0, y=82, w=390, h=78; 40px nodes | −14px x, +28px w, +17px h | shared component |
| Heading | x=14, y≈166; title 25px | x=14, y≈212; title 30px | +46px y, +5px type | global token |
| Upload card | x=14, y≈259, w=362, h≈265 | x=15, y=289, w=360, h≈249 | +1px x, −2px w, +30px y, −≈16px h | screen local |
| Choose-file control | reference h=40 | Flutter h=44 | +4px | intentional production exception |
| Destination callout | y≈527, h≈76, near-white | y=548, h≈86, #EAF2FF | +21px y, +10px h | shared component |
| Bottom action zone | ≈62px; enabled navy Continue | 76px; disabled grey Continue before selection | +14px and disabled | intentional production exception |
| Primary typography/color | 25px title, #162E54 action | 30px title, #1D68D9 active tokens | type/color shift | global token |
| Border/radius/shadow | #DFE6EE, 15px, soft shadow | #DFE6EE, 15px, same 0/8/24 family | aligned | global token |

The disabled Continue state is truthful: selecting a file creates only an
in-memory preview and no controller mutation occurs here.

## 360×800 adaptive acceptance

No canonical 360 reference exists. Visual inspection confirms the four steps,
upload card, callout and disabled Continue action remain bounded; the content
can scroll if localized copy grows. No 360 diff was fabricated and no render
overflow was recorded.
