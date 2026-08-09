# Ref 17 — BOQ materials

This evidence compares the exact 390×844 pack reference with the current
controller-backed Flutter fixture. It records remaining differences and does
not claim pixel parity.

## Artifacts

- `reference-390x844.png`
- `flutter-after-390x844.png` — byte-identical to the current
  `boq_materials_390x844.png` golden.
- `side-by-side-390x844.png`
- `alpha-overlay-390x844.png`
- `pixel-diff-390x844.png` — absolute RGB difference, brightened 2.5×.
- `flutter-after-360x800.png` — adaptive evidence only.

No exact/equivalent pre-Batch-2 Flutter worksheet-card artifact was found, so
“Flutter Before” is explicitly unavailable.

## Measured 390×844 deltas

Pixel diagnostic: 75.40% changed pixels; mean absolute RGB-channel delta
31.69/255. Shell and different real fixture content are included.

| Measurement | R38 reference | Flutter after | Delta | Classification |
|---|---:|---:|---:|---|
| Viewport | 390×844 | 390×844 | 0 | global token |
| Top chrome | 26px status + 54px app bar; one trailing menu | 26px safe area + 56px toolbar; repository-linked actions | +2px; action set differs | shared component |
| Screen inset | 14px | 12px outer worksheet padding | −2px | screen local |
| Worksheet summary | x=14, y≈94, w=362, h≈163 | x=13, y=91, w=364, h≈278 | +1px w, +115px h | screen local |
| Primary action grid | four 40px buttons, 8px gaps | first four 54px buttons, 8px gaps | +14px per control | intentional production exception |
| Additional actions | none | Save worksheet, Send Whole Group, Add column, Blank row, Similar row | added | screen local |
| Materials header | y≈280 with search/filter | replaced by truthful row/column counters | presentation differs | screen local |
| Material cards | x=14, w=362, min h=72, 8px gap | x=22, w=346, min h=102, 10px gap | +8px x, −16px w, +30px h | shared component |
| Visible density | five rows in first viewport | two rows in first viewport | −3 visible rows | screen local |
| Card styling | #DFE6EE, radius≈13–15px, soft shadow | #DFE6EE, radius=15px, 0 8px 24px shadow | close; radius up to +2px | global token |
| Primary color | reference navy #162E54 | Flutter blue #1D68D9 | color change | global token |
| Row content | size · make · model | size · make/origin · model · equipment tag | extra canonical field | intentional production exception |
| Shell navigation | 82px bottom nav | supplied outside isolated feature golden | absent in artifact | shared component |

The larger action and row targets preserve the 44px production minimum.
Equipment tag remains separate from manufacturer serial data, and no
capability-protected commercial column/value is rendered.

## 360×800 adaptive acceptance

No canonical 360 pack image exists. The inspected 360 golden keeps the 2×2
primary action grid bounded, wraps the two longer workflow actions without
horizontal overflow, lazily builds material cards, and remains vertically
scrollable. No 360 diff was fabricated and no render overflow was recorded.
