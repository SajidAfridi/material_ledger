# Ref 15 — BOQ Scope Overview

Assessment: this evidence uses the integrated Project → BOQ composition and
the real summary-only provider data. The scope hierarchy is recognizable, but
selector detail, card density and controls still differ. Pixel parity is not
claimed.

## Artifact provenance

- [R38 reference, 390×844](reference-390x844.png) — existing normalized pack
  raster, SHA-256
  `3953be3b669c71938e0dc292a50c3aec11b2f2ff8ac5f7eb30b9912b8f5dd0a1`.
  It is JPEG-encoded despite its historical `.png` suffix.
- [Flutter after, 390×844](flutter-after-390x844.png) — exact RGB copy of the
  required integrated
  `test/goldens/mobile_batch2/project_boq_scope_overview_390x844.png`,
  SHA-256
  `ae29696a8b53ba8a9033b8f8f1ea7ab3a57c6328e6606f4f491d5f7c4d5d9d2d`.
  The standalone `boq_scope_overview` golden was deliberately not used.
- [Side by side, 390×844](side-by-side-390x844.png),
  [50% alpha overlay](alpha-overlay-390x844.png), and
  [4× RGB pixel diff](pixel-diff-390x844.png).
- [Flutter adaptive capture, 360×800](flutter-after-360x800.png) — exact RGB
  copy of the integrated 360 golden. No canonical 360 pack render exists and
  no 360 reference/diff was fabricated.
- Flutter Before: unavailable. The prior scoped-BOQ mobile artifact is a
  standalone, obfuscated 360 fixture rather than this integrated route/state;
  it was not presented as equivalent evidence.

## Pixel summary at 390×844

The RGB mean absolute error is **12.46/255**, RGB RMS error is **34.98/255**,
**20.23%** of pixels have a maximum-channel delta greater than 16, and
**7.36%** exceed 32. Counts and metric names intentionally follow the loaded
production summaries, not the prototype's static values.

## Measurable deltas

| Category | R38 reference | Flutter after | Delta | Classification |
|---|---|---|---|---|
| App bar | `x0 y26`, `390×54`; 44px search target | `x0 y26`, `390×54`; no search control | Geometry exact; one control absent | screen-local |
| OS status content | Simulated status glyphs | Blank safe area | OS chrome is not app-rendered | intentional production exception |
| Project tabs | Five tabs at about `y94`, 40px high | Four tabs at `y80`, 45px high | `y −14`, `h +5`; Accounts absent | intentional production exception |
| Scope selector first item | `x14 y147`, `124×57` | `x16 y134`, `112×57` | `x +2`, `y −13`, `w −12`; height exact | screen-local |
| Scope selector radius | 11px | 14px | `+3px` | shared component |
| Scope selector content | Eyebrow, concise name and count | One real-scope label | Two supporting lines absent | screen-local |
| Information callout | About `x14 y216`, `362×78` | About `x14 y203`, `362×85` | `y −13`, `h +7` | screen-local |
| Callout icon/gap | 34px icon; 10px gap | 48px icon; 12px gap | Icon `+14px`; gap `+2px` | shared component |
| Callout body type | 10px / 15px | 12px / 17.4px | `+2px`, `+2.4px` line box | global token |
| Common-card white-fill bounds | `x15 y295`, `360×107` | `x15 y301`, `360×126` | `y +6`, `h +19` | screen-local |
| First building-card fill | `x15 y415`, `360×122` | `x15 y441`, `360×126` | `y +26`, `h +4` | screen-local |
| Second building-card fill | `x15 y550`, `360×122` | `x15 y581`, `360×126` | `y +31`, `h +4` | screen-local |
| Card title type | 12px | 16px / 20.8px | `+4px` | global token |
| Metric cell | About 106–108px wide × 45px high | About 102px wide × 60px high | Width `−4–6px`; height `+15px` | screen-local |
| Metric type | Label 7.5px; value 12px | Label 12px; value 16px | `+4.5px` / `+4px` | global token |
| Card border/radius/shadow | 1px; 15px; `0 8px 24px` | 1px; 15px; `0 8px 24px` | Nominally exact | shared component |
| Card affordance | Subtitle plus Shared/building chip | Chevron; no subtitle/chip | Presentation differs | screen-local |
| Summary metrics | Folders, Materials, Requests with mock counts | Folders, Materials, Started with provider counts | Metric and values intentionally differ | intentional production exception |
| Bottom navigation at 390 | `x10 y770`, `370×64` | `x10 y770`, `370×64` | Exact | shared component |

## Remaining differences

- Accounts is absent because this fixture has no implemented and authorized
  destination. The four-tab result is an **intentional production exception**.
- Search, selector eyebrow/count lines, scope subtitles and chips are missing;
  these are **screen-local** visual/control deltas.
- The production Overview reports per-scope folder, material and started-folder
  counts, as required by the BOQ contract. It does not copy prototype counts or
  use Requests as a substitute. This is an **intentional production
  exception**.
- Larger **global token** typography and the 48px **shared component** callout
  icon increase vertical density. Cards otherwise retain the target 15px
  radius, 1px border and ambient shadow.
- At 360×800 the integrated capture retains the same one-row navigation at
  `x10 y726`, `340×64`. All four destinations remain equally bounded and the
  final BOQ card scrolls above it. This is the accepted **shared component**
  adaptive behavior.

## 360×800 adaptive acceptance

The selector remains horizontally scrollable, card text stays within the
360px width, and the one-row bottom navigation remains visible without
covering content. The 360 state is accepted as adaptive evidence; it is not
pixel-compared because the pack supplies no canonical 360 reference.
