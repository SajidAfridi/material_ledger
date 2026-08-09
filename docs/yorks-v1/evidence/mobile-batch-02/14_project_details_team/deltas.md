# Ref 14 — Project Details and Team

Assessment: role-backed team data, hierarchy and card structure are present,
but the Flutter type scale and row content make the surface materially taller
than the reference. Pixel parity is not claimed.

## Artifact provenance

- [R38 reference, 390×844](reference-390x844.png) — existing normalized pack
  raster, SHA-256
  `5c42c35cc1f2a5907ff18a461e95af30e9dc9b57edff02caa2fa2f00d07e9f86`.
  It is JPEG-encoded despite its historical `.png` suffix.
- [Flutter after, 390×844](flutter-after-390x844.png) — exact RGB copy of
  `test/goldens/mobile_batch2/project_details_team_390x844.png`, SHA-256
  `c409a7950e15f53e4fee56376a686e325d9737b5e2ddefa2a4c418d43625ac65`.
- [Side by side, 390×844](side-by-side-390x844.png),
  [50% alpha overlay](alpha-overlay-390x844.png), and
  [4× RGB pixel diff](pixel-diff-390x844.png).
- [Flutter adaptive capture, 360×800](flutter-after-360x800.png) — exact RGB
  copy of the deterministic 360 golden. The pack supplies no canonical 360
  render, so no 360 diff or synthetic reference exists.
- Flutter Before: unavailable. No deterministic earlier mobile Team view uses
  this route, member fixture and permission state.

## Pixel summary at 390×844

The RGB mean absolute error is **9.71/255**, RGB RMS error is **29.98/255**,
**20.07%** of pixels have a maximum-channel delta greater than 16, and
**6.43%** exceed 32. The full-frame raw-diff bounds include the simulated
reference status glyphs.

## Measurable deltas

| Category | R38 reference | Flutter after | Delta | Classification |
|---|---|---|---|---|
| App bar | `x0 y26`, `390×54`; title “Project Details”; trailing menu | `x0 y26`, `390×54`; title “Project details”; no trailing menu | Geometry exact; casing/control differ | screen-local |
| OS status content | Simulated status glyphs | Blank safe area | OS chrome is not app-rendered | intentional production exception |
| Detail tabs | Control at about `y94`, 40px high | Control at `y80`, 45px high | `y −14`, `h +5` | shared component |
| First card white-fill bounds | `x15 y148`, `360×190` | `x15 y140`, `360×224` | `y −8`, `h +34` | screen-local |
| Second card white-fill bounds | `x15 y351`, `360×138` | `x15 y377`, `360×195` | `y +26`, `h +57` | screen-local |
| Card horizontal geometry | `x14`, 362px, 14px padding, 15px radius | Same | Exact | shared component |
| Card-to-card gap | 11px | 11px | Exact | shared component |
| Section title type | 16px / 20px | 21px / 25.2px | `+5px` size, `+5.2px` line box | global token |
| Person-row bounds | First row about `x29 y192`, `332×58` | `x29 y214`, `332×64` | `h +6`; width exact | screen-local |
| Person-row gap | 8px | 8px | Exact | shared component |
| Avatar | 36px | 44px | `+8px` | shared component |
| Supporting type | 9px reference role/date line | 12px / 17.4px production role and assignment line | `+3px` | global token |
| Status pill | 23px minimum | 26px minimum | `+3px` | shared component |
| History note | 9px / 14px; one line | 12px / 17.4px; two lines | `+3px`; one extra line | global token |
| Border/radius | 1px `#DFE6EE`; card 15px; row 12px | Same | Exact | shared component |
| Card shadow | `0 8px 24px rgba(20,50,85,.055)` | `0 8px 20px rgba(25,48,78,.059)` | Blur `−4px` | shared component |
| Manage control | Small visual text action | Material text action with at least a 44px semantic target | Larger hit area | intentional production exception |
| Bottom navigation | `x10 y770`, `370×64` | `x10 y770`, `370×64` | Exact | shared component |

## Remaining differences

- The trailing menu shown by the pack is absent on this detail state and the
  title casing differs. Both are **screen-local** deltas.
- Section headings, supporting metadata and the history note use a larger
  **global token** scale. Together with 44px avatars, this expands the two
  cards by 34px and 57px.
- Flutter displays each member's actual project role and effective assignment
  date, then ellipsizes safely. It does not invent “Lead Project Engineer.”
  This content difference is an **intentional production exception**.
- Manage remains permission-gated and reuses the existing team command. Its
  larger target is an **intentional production exception** for accessibility.
- The 20px card blur remains a **shared component** delta from the 24px pack
  shadow.

## 360×800 adaptive acceptance

The adaptive capture retains three equal tabs, both team cards, safe
ellipsis, two Manage actions and a one-row `340×64` bottom navigation. The
history note wraps to two lines without collision. It is accepted as adaptive
evidence only, not as a 360 parity result.
