# Yorks V1 R38 — Rendered UI Contract

Status: **V00 accepted with product-owner corrections — no Flutter or backend
implementation changes are part of this document.**

Captured: 2026-08-08

## 1. Authority and hard boundary

This contract records the rendered visual and interaction presentation of the
R38 HTML reference. It is the visual input for later Flutter convergence work.

The authority split is mandatory:

- **R38 HTML:** visual design, density, layout, hierarchy and interaction
  presentation.
- **Current Flutter:** application behavior, Riverpod/controller state,
  navigation and accessible platform implementation.
- **Supabase/Postgres:** persisted facts, Auth, RLS, RPCs, workflow invariants,
  idempotency, quantities, audit and document authority.

The R38 JavaScript implementation is not a product or business-logic source.
No localStorage authentication, permissions, workflow transitions, quantities,
stock behavior or audit behavior may be copied into Flutter.

V00 changes no Flutter widgets, controllers, repositories, routes, migrations,
RLS, RPCs, document logic or production services. A functional defect found
during a future visual pass must be documented and handled separately from UI
convergence.

The behavior and security rules in `SOURCE_OF_TRUTH.md`,
`PRODUCT_DECISIONS.md`, `ARCHITECTURE_AND_SECURITY_CONTRACT.md` and
`R35_UI_CONTRACT.md` remain authoritative where the prototype differs.

## 2. Reference artifact

| Property | Value |
|---|---|
| Artifact | `Yorks_AC_Ref_V1_R38_Building_Specific_BOQ_Final.html` |
| Local source | `/Users/eapple/Downloads/Yorks_AC_Ref_V1_R38_Building_Specific_BOQ_Final.html` |
| SHA-256 | `c9ad2f3d3a7848e82a56e849fc537d90f1769f758660302ca01f3dae2c6f3f88` |
| Size | 2,913,452 bytes; 8,870 lines |
| Rendering method | Local HTTP origin in the Codex in-app Chromium browser |
| Viewports | 1440x900, 1366x768, 1024x768, 390x844 and 360x800 CSS pixels |

R38 initializes an empty operational workspace on a clean origin. Empty shell
and portfolio evidence therefore preserve that approved state. To expose the
BOQ scope selector, folder grid and worksheet, V00 created a clearly synthetic
local project through the visible five-step prototype wizard and added one row
through the visible BOQ controls. That fixture is screenshot content only; its
data and JavaScript behavior are not implementation requirements.

Rendered computed styles, not static CSS declarations, are recorded below.
Fractional browser values may be rounded to the nearest Flutter logical pixel
only when screenshot geometry remains equivalent.

## 3. Screenshot evidence

Every state below was captured at every required viewport. The PNGs are the
pixel reference for later image comparisons.

| State | 1440x900 | 1366x768 | 1024x768 | 390x844 | 360x800 |
|---|---|---|---|---|---|
| Sign in | [PNG](evidence/r38-v00/login-1440x900.png) | [PNG](evidence/r38-v00/login-1366x768.png) | [PNG](evidence/r38-v00/login-1024x768.png) | [PNG](evidence/r38-v00/login-390x844.png) | [PNG](evidence/r38-v00/login-360x800.png) |
| Empty Overview | [PNG](evidence/r38-v00/overview-1440x900.png) | [PNG](evidence/r38-v00/overview-1366x768.png) | [PNG](evidence/r38-v00/overview-1024x768.png) | [PNG](evidence/r38-v00/overview-390x844.png) | [PNG](evidence/r38-v00/overview-360x800.png) |
| Project wizard, step 1 | [PNG](evidence/r38-v00/project-wizard-step1-1440x900.png) | [PNG](evidence/r38-v00/project-wizard-step1-1366x768.png) | [PNG](evidence/r38-v00/project-wizard-step1-1024x768.png) | [PNG](evidence/r38-v00/project-wizard-step1-390x844.png) | [PNG](evidence/r38-v00/project-wizard-step1-360x800.png) |
| BOQ Overview | [PNG](evidence/r38-v00/boq-overview-1440x900.png) | [PNG](evidence/r38-v00/boq-overview-1366x768.png) | [PNG](evidence/r38-v00/boq-overview-1024x768.png) | [PNG](evidence/r38-v00/boq-overview-390x844.png) | [PNG](evidence/r38-v00/boq-overview-360x800.png) |
| Common BOQ folders | [PNG](evidence/r38-v00/boq-common-groups-1440x900.png) | [PNG](evidence/r38-v00/boq-common-groups-1366x768.png) | [PNG](evidence/r38-v00/boq-common-groups-1024x768.png) | [PNG](evidence/r38-v00/boq-common-groups-390x844.png) | [PNG](evidence/r38-v00/boq-common-groups-360x800.png) |
| BOQ worksheet | [PNG](evidence/r38-v00/boq-worksheet-1440x900.png) | [PNG](evidence/r38-v00/boq-worksheet-1366x768.png) | [PNG](evidence/r38-v00/boq-worksheet-1024x768.png) | [PNG](evidence/r38-v00/boq-worksheet-390x844.png) | [PNG](evidence/r38-v00/boq-worksheet-360x800.png) |
| Profile modal/sheet | [PNG](evidence/r38-v00/profile-modal-1440x900.png) | [PNG](evidence/r38-v00/profile-modal-1366x768.png) | [PNG](evidence/r38-v00/profile-modal-1024x768.png) | [PNG](evidence/r38-v00/profile-modal-390x844.png) | [PNG](evidence/r38-v00/profile-modal-360x800.png) |

## 4. Global visual tokens

Use shared Flutter theme tokens/components before making screen-local changes.
Do not distribute these values as unrelated literals.

### 4.1 Color

| Intent | Rendered reference |
|---|---|
| Navy / record header | `#0D2F57` |
| Navy gradient end | `#174F87` |
| Secondary navy | `#123F73` |
| Primary action blue | `#1769D2` |
| General blue | `#1D68D9` |
| BOQ tab eyebrow blue | `#2F75C8` |
| Pale blue | `#EAF2FF` |
| Blue line | `#C9DCFF` |
| Primary ink | `#132033` |
| R26 heading ink | `#17263A` |
| Secondary ink | `#34435A` |
| Muted | `#68778A` / base `#6B788C` |
| Quiet muted | `#8F9AAE` |
| Divider | `#DFE6EE` / base `#DCE3EC` |
| Strong divider | `#C8D2DF` |
| Desktop canvas | `#EEF3F8` |
| Mobile canvas | `#F3F6FA` |
| Soft panel | `#F5F8FC` |
| Sidebar/topbar | `#F9FBFD`; topbar alpha 92% |
| Focus inset | `#2563EB`, 2px inset ring |
| Success background | `#E9F8F2` |
| Warning background | `#FFF5DF` |
| Error background | `#FFF0F0` |
| Purple background | `#F2EDFF` |

### 4.2 Type

The rendered family is
`-apple-system, system-ui, Segoe UI, Inter, Roboto, Helvetica, Arial, sans-serif`.
Flutter must keep its offline-safe Latin font and Arabic fallback, matching
metrics as closely as the platform allows.

| Use | Desktop | Mobile | Weight / detail |
|---|---|---|---|
| Base body | 13px | 12.5px | 400 |
| Record/page H1 | 25/29px | 20/23.2px | 700; letter spacing -0.625/-0.5px |
| Section H2 | 17/20.4px | 17/20.4px | 700; letter spacing -0.255px |
| Card H3 | 14/18.2px | 14/18.2px | 700 |
| Sign-in message H1 | 45/46.8px | 29/30.16px | 700 |
| Sign-in card H2 | 28/33.6px | 24/28.8px | 700 |
| Standard button | 12px | 12px | 720 |
| Small button | 11px | 11px | 720 |
| Form input | 11.5px | 11.5px | 400 |
| Table header | 8.5px | 8.5px | 700 |
| Table cell/editor | 10px | 10px | 400; main text editor 650 |
| BOQ scope eyebrow | 7px | 7px | 850; 0.56px tracking |
| BOQ scope title | 10px | 10px | 700 |
| BOQ scope count | 7.5px | 7.5px | 400 |

Use uppercase eyebrows sparingly. Primary hierarchy comes from size, weight,
spacing and grouping, not additional decoration.

### 4.3 Shape, line and elevation

| Element | Contract |
|---|---|
| Compact input radius | 9px |
| Button radius | 10px; small 8px; sign-in primary 12px |
| Notice radius | 12–13px |
| Card/panel radius | 15px |
| Desktop modal radius | 16px |
| Mobile bottom-sheet radius | 17px 17px 0 0 |
| Sign-in card radius | 20px desktop; 17px mobile |
| Record header bottom radius | 18px desktop; 14px mobile |
| Standard border | 1px `#DFE6EE` |
| Soft shadow | `0 4px 16px rgba(25,48,78,.06)` |
| Card shadow | `0 8px 24px rgba(20,50,85,.043)` |
| Primary action shadow | `0 6px 16px rgba(13,47,87,.14)` |
| Active BOQ tab shadow | `0 4px 13px rgba(13,47,87,.08)` |
| Desktop modal shadow | `0 28px 80px rgba(13,26,43,.25)` |
| Sign-in card shadow | `0 24px 72px rgba(25,48,78,.12)` |

## 5. Responsive frame contract

The rendered breakpoint changes at 720px. At 1024px the persistent desktop
shell remains present; content adapts within the remaining 764px.

| Viewport | Shell | Work area | Page padding | Body |
|---|---|---|---|---|
| 1440x900 | 260px fixed sidebar; 64px topbar | 1180px from x=260 | 24px 26px 96px for R26 pages | 13px; `#EEF3F8` |
| 1366x768 | same | 1106px | same | same |
| 1024x768 | same | 764px | same | same; tables scroll inside their panel |
| 390x844 | 246px off-canvas sidebar; 56px topbar | 390px | 16px 14px 86px | 12.5px; `#F3F6FA`; x overflow hidden |
| 360x800 | 246px off-canvas sidebar; 56px topbar | 360px | 16px 14px 86px | same |

At 900px height the sidebar uses 18px 14px 14px padding. At 768px height it
compacts to 12px 14px 10px. Desktop topbar horizontal padding is 24px; mobile
is 16px.

The rendered mobile bottom navigation is fixed 10px from each side, 62px high,
5px padded, 17px radius and `rgba(12,37,67,.94)`. Production acceptance is
stricter than the literal prototype rendering:

- the destinations remain in exactly one row and never wrap;
- every destination receives equal, bounded width;
- no icon, label, badge or other child renders below the bar;
- every destination has a minimum 44x44 semantic/hit target;
- scroll content includes enough safe-area-aware bottom inset to move fully
  above the floating bar;
- no button, table row, help copy, footer or final record content is obscured
  by the bar.

The R38 visible item box is only 31px high. Flutter must preserve the visual
icon/label geometry while expanding its semantic/hit area and satisfying the
requirements above.

## 6. Global shell and page hierarchy

### 6.1 Desktop shell

- Sidebar: fixed 260px, `#F9FBFD`, content clipped horizontally.
- Primary navigation row: about 231x42px, 10px horizontal padding, 10px radius,
  11px icon/text gap, 13px/650 text.
- Secondary navigation row: 39px high, 11.5px/650 text.
- Profile stamp: about 231x56px, 7px 9px padding, 13px radius, 1px soft border.
- Topbar: sticky 64px, breadcrumb/context left, 220x36px command field and sync
  state right.
- Selected navigation and active tabs require text/shape/icon differences in
  addition to color.

### 6.2 Record header

Project records use a navy gradient from `#0D2F57` to `#174F87`.

| Viewport | Header | Padding | Project tab rail |
|---|---|---|---|
| 1440 | 1180x152.5px | 22px 26px 0 | 1128x40px; 4px gap |
| 1024 | 764x181.5px | 22px 26px 0 | 712x40px; horizontal scroll |
| 390 | 390x195.2px | 17px 14px 0 | 366x43px; horizontal scroll |
| 360 | 360x218.39px | 17px 14px 0 | 336x43px; horizontal scroll |

Project tab buttons are 40px high with 12px 15px 13px padding. The active tab
is indicated by text weight/color and a bottom rule, not a filled pill.

The current Yorks project workspace target contains, in this order:

1. Overview
2. BOQ
3. Material Requests
4. Documents
5. Accounts

Accounts is part of visual convergence and remains capability/role controlled.
Its presence in the target does not weaken any existing route, query or command
authorization boundary.

### 6.3 Buttons and panels

- Standard buttons are 38px high, 13px horizontal padding, 7px internal gap.
- Primary: navy fill/border, white 12px/720 label, 10px radius and primary
  shadow.
- Secondary: white fill, `#DCE3EC` border, dark ink.
- Small: 32px high, 10px horizontal padding, 8px radius, 11px/720.
- Content cards/panels: white, 1px `#DFE6EE`, 15px radius, card shadow.
- Mini/stat cards: `#F5F8FC`, 1px `#E4EAF2`, 12px radius, 12px 13px padding.
- Empty state: centered icon/title/copy/action with about 42px 20px padding.

Critical server actions must continue to show authoritative loading, success,
conflict and failure state from the existing controller/repository path. The
prototype's “Saved” label is visual wording only and never licenses an
optimistic server success state.

## 7. Sign-in screen

Desktop uses a 45%/55% split. At 1440px this renders as a 648px navy brand
panel and a 792px form region; at 1024px it is 460.8px/563.2px. The brand panel
uses 44px 48px padding. The form region centers a fixed 455px card and uses
42px outer padding.

The desktop card is 455x498.84px, 30px padded, 20px radius. Inputs are 393x45px
with 9px radius; the primary sign-in button is 393x48px with 12px radius.

At 390/360px the layout becomes one column:

- brand panel: full width and 344.36px high, 23px 20px padding;
- form region: 18px 14px 28px padding;
- card: viewport minus 28px (362px or 332px), 22px 18px padding, 17px radius;
- form content: card width minus 38px (324px or 294px);
- inputs 45px and primary button 48px high.

Flutter keeps real Supabase Auth, secure configuration and existing error
handling. Prototype credentials or client-side authentication do not enter the
application.

## 8. Five-stage project wizard

The logical stages remain Project Details; Parties and Access; Buildings;
optional Attachments; Review and Create. Visual convergence occurs above the
existing project creation controller/repository contract.

### Desktop/tablet

- General page padding: 26px 30px 70px.
- Page header: 78.05px high, 22px action gap.
- Wizard: white, 1px line, 15px radius, soft shadow and clipped content.
- 1440: 1120x670px, columns 230px/888px.
- 1366: 1046x670px, columns 230px/814px.
- 1024: 704x679.7px, columns 230px/472px.
- Step rail: `#F5F8FB`, 22px 16px padding. Active step is 42px high,
  9px padding/radius/gap and pale blue.
- Wizard body: 20px 24px padding and local vertical overflow.
- Form: two equal columns, 15px gap. At 1440 each column is 412.5px; at 1024
  each is 204.5px.
- Inputs: 36px high, 10px horizontal padding, 9px radius, 11.5px text.
- Textarea: 88px high and 10px padding.
- Footer: 65px high and 13px 24px padding.

The rendered 1024px date rows are extremely tight. Flutter must preserve the
two-column hierarchy without cropping or overlapping segment fields, labels or
help text. If platform font metrics cannot fit, wrap the date segments inside
their own form cell and compare the resulting geometry; do not reproduce
unreadable clipping as “parity.”

### Mobile

- Page padding: 18px 14px 82px.
- Page header stacks and is 142.66px high.
- Wizard width is viewport minus 28px: 362px at 390 and 332px at 360.
- The step rail becomes a 67px horizontal strip with 14px padding. Active step
  is 38px high with 7px padding.
- Wizard main follows below the strip; body padding is 15px 14px.
- Form becomes one column with 15px gaps; usable widths are 332px and 302px.
- Footer is 61px high with 11px 14px padding.

Validation stays next to the affected field and stage. Draft recovery and
connected creation keep current Flutter semantics; the HTML draft store is not
copied.

## 9. BOQ scope selection

The first selector is **Overview**. It is summary-only: it summarizes each real
scope and opens one selected Common/building BOQ. Overview is not a persisted
scope, never combines all building materials into one editable BOQ, and is not
an MR source or direct BOQ export source.

Common remains a real independent BOQ scope for materials genuinely shared by
the project. Every physical building remains its own independent BOQ scope.

### Scope rail

- Container: full content width, 5px padding, 8px gap, 14px radius,
  `#F4F7FB`, 1px line and horizontal scrolling.
- Desktop: 69px high; each tab 142x57px minimum with 10px 13px padding.
- Mobile: 67px high; each tab 124x55px minimum with 9px 11px padding. The rail
  extends 4px into each page gutter to maximize visible tabs.
- Active: white, 1px `#9DB9D7`, 10px radius, navy title and active shadow.
- Inactive: transparent border/background and muted text.

The intro notice is 13px radius, `#F6F9FD`, 1px `#CFE0F3`. It uses 13px 15px
padding on desktop and 11px on mobile. It is 62px high at 1440, 68.14px at
1024, and 88.78px on 390/360.

### Folder and overview grids

- Desktop folder grid: three columns at 1440/1366; 13px gap.
- 1024: two columns (349.5px each in a 712px content area).
- Mobile: one column, 362px at 390 and 332px at 360.
- Folder card: 16px padding, 13px internal gap, 15px radius and card shadow.
- Overview scope cards use the same visual family and show scope type, title,
  purpose and three compact metrics without combining underlying rows.

## 10. BOQ worksheet

The worksheet stays inside a white 15px panel. Its command header is 69px high
on desktop and 161px on mobile, where controls wrap into a second group. The
table wrapper is the horizontal-scroll boundary; body/page horizontal overflow
remains hidden on mobile.

| Property | Desktop/tablet | Mobile |
|---|---|---|
| Table minimum width | 1260px | 1180px |
| Header height | 32.5px | 32.5px |
| Data row height | 47px | 47px |
| Header padding/type | 11px 10px; 8.5px/700 | same |
| Editor height | 46px | 46px |
| Editor padding/type | 11px 12px; 10px | same |
| Editor minimum width | 92px | 92px |
| Active editor focus | white fill; 2px inset `#2563EB` | same |
| Footer | 38.77px typical | 96.09px after wrapping |

At 1024 the worksheet panel is 712px wide and its scroll wrapper 710px. At
390/360 the panel is 362/332px and the wrapper 360/330px. Horizontal scrolling
must be local to the table.

The desktop Flutter grid still must provide sticky headers/identity lane,
keyboard navigation and row insertion below the active row. Mobile production
editing remains a focused one-row editor with 44x44 controls; the R38 shrunken
horizontal worksheet is a visual browsing reference, not permission to replace
the approved mobile editing model.

Arbitrary BOQ columns and canonical mappings continue to come from the current
Flutter model/repository layer. Commercial fields remain capability-controlled
in state, queries, caches, exports and documents.

## 11. Modal and sheet presentation

The profile presentation demonstrates the shared modal pattern:

- Desktop dialog: 520x444.94px centered, 16px radius, modal shadow.
- Header: 74.59px, 17px 19px padding.
- Body: 18px 19px padding.
- Footer: 63px, 12px 19px padding, 8px action gap.
- Summary card: 17px padding, 14px radius.
- Three stat tiles: one row on desktop, 8px gap, 11px padding, 10px radius.
- Mobile: full-width bottom sheet pinned to the bottom, 390x578.53px or
  360x595.2px, top corners 17px. Stat tiles stack into one column.

Dialogs preserve keyboard focus trapping, Escape/back behavior, semantic
labels and reduced-motion handling in Flutter.

## 12. Interaction presentation

- Focus is always visible. Spreadsheet focus uses the measured 2px inset blue
  ring; buttons and fields need equivalent high-contrast focus treatment.
- Hover may add elevation/tone on desktop but cannot be the only way to reveal
  information or actions.
- Saving/synced/offline/conflict/error presentation is compact and near the
  affected record. Only the current controller/repository result can claim a
  server-confirmed success.
- Active navigation, tabs, selected scope and status always combine color with
  text, shape, icon or rule.
- Primary actions use one dominant navy treatment per decision area.
- Destructive actions are visually separated and use explicit confirmation
  where current application behavior requires it.
- Motion remains short, subtle and non-blocking and respects reduced motion.

## 13. Production exceptions and exclusions

Do not reproduce these prototype behaviors even where visible in a screenshot:

- localStorage/sessionStorage auth, permissions, persistence or audit;
- client-side workflow, inventory, commercial or quantity authority;
- optimistic “Saved” as a substitute for server confirmation;
- hardcoded user-facing English or missing Arabic fallback;
- sub-44px interactive hit targets;
- mobile spreadsheet-only editing;
- unrestricted commercial data;
- legacy/deferred RFQ, quotation, PO or hidden command routes.

Accounts is part of the current Yorks target and must be included in visual
convergence subject to role permissions. Project workspace tabs are Overview,
BOQ, Material Requests, Documents and Accounts. The first selector inside BOQ
is the summary-only **Overview** described above.

The following are intentional production exceptions to literal screenshot
parity:

- responsive wrapping of segmented date controls at 1024px when required to
  prevent label, field or helper-text clipping/overlap;
- the one-row, equal-width, 44x44-target mobile navigation contract and the
  bottom content inset required to keep all content reachable;
- production authorization/localization/accessibility behavior described in
  this contract instead of the prototype's client-side shortcuts.

## 14. V01+ convergence order and gate

Implement and compare in this order:

1. global color, type, spacing, radius, line and elevation tokens;
2. role shell, topbar, record header, bottom navigation and responsive frame;
3. shared page header, buttons, cards, notices, status chips and empty states;
4. shared form, wizard, modal/sheet and table primitives;
5. screen composition and screen-local exceptions;
6. role/state variants backed by existing Flutter/Supabase behavior.

For each target state, render R38 and Flutter with equivalent visible content at
the exact viewport, capture both, create an image diff/overlay, record every
measurable delta and correct shared tokens/components before local overrides.
Acceptance requires:

- matching geometry, hierarchy, density, color, type, border, radius and
  elevation within platform-rendering tolerance;
- no page-level horizontal overflow except the deliberate local table/tab
  scroll areas;
- correct desktop, tablet and purpose-built mobile composition;
- keyboard/focus/semantics and 44x44 hit targets;
- unchanged controller/repository/RPC/RLS/workflow/security contracts;
- no HTML JavaScript business logic in Flutter.

## 15. V00 verification record

- 35 viewport PNGs captured: seven states at all five required sizes.
- All 35 PNG pixel dimensions match their filenames.
- All 35 relative evidence links in this contract resolve.
- `git diff --check` passes.
- No `lib/`, `test/`, `supabase/`, controller, repository, route, workflow,
  schema or production deployment change was made for V00.
- Flutter, database and release build gates were intentionally not rerun for
  this documentation/evidence-only extraction. The first Flutter convergence
  implementation slice must run the focused checks and complete gates required
  by `AGENTS.md`.
