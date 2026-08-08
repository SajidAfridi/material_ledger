# Yorks V1 R35 — Production UI Contract

This contract translates the effective final R35 prototype into accessible,
localized Flutter behavior. The prototype supplies visual/interaction intent;
Rev 2.0, `PRODUCT_DECISIONS.md` and server security override its localStorage
implementation and legacy hidden routes.

## 1. Experience principles

- Calm before clever: clear owner/action/state before metrics or decoration.
- Information before decoration: dense office tables remain readable and
  familiar to engineers who use Excel.
- Confidence through transparency: actor, role, time, version, source and next
  owner are visible on important records.
- One action hierarchy per screen: primary action, restrained secondary actions
  and reasoned/destructive actions separated.
- Responsive does not mean compressed: mobile uses purpose-built cards and
  focused editors rather than a miniature desktop worksheet.

## 2. Role navigation

### Project Engineer and Site Engineer

Primary navigation:

- Overview
- Projects
- Material Requests
- Material Returns
- Duct Sizer
- ESP Calculator

Project Engineer-only actions appear through capability/current-project
membership, not a separate static navigation tree. Site Engineer never sees an
enabled team-management or arrangement-approval action without active Project
Engineer membership.

### Procurement

- Overview
- Material Requests
- Browse / Inventory
- Dispatches
- Material Returns
- Projects — View Only

Project and BOQ pages use explicit read-only presentation. Controls are not
merely removed from the DOM/widget tree; routes and database writes are also
denied.

### Admin

Operational navigation:

- Overview
- Projects
- Material Requests
- Inventory
- Material Returns
- Dispatches

Administration:

- Configuration
- Rental Properties
- User Management
- Audit Trail

Accounts, RFQ, quotation, PO, legacy Material Plan and hidden prototype routes
are absent from V1 navigation and command search.

## 3. Global shell

Desktop reference:

- persistent approximately 246px sidebar;
- 64px top bar with breadcrumbs, current context, sync state, notifications and
  profile;
- max-width work area with responsive full-width exception for spreadsheets;
- clear workspace label by role;
- selected navigation state uses icon, text and non-color cues.

Tablet:

- collapsible/off-canvas sidebar;
- optional list/detail two-pane layouts;
- horizontal scrolling only where a real table requires it;
- primary actions remain visible without covering review content.

Mobile:

- compact header and bottom navigation for core operational routes;
- secondary/Admin routes through an accessible menu;
- safe-area aware fixed actions;
- 44x44 minimum targets and no hidden hover-only behavior.

Reference breakpoints are desktop at 1100px and above, tablet 721–1099px and
mobile at 720px and below. Widget decisions may use existing responsive helpers
instead of hardcoded media checks, but acceptance includes 1366x768 and 360px.

## 4. Visual language

Effective R35 reference colors:

| Token intent | Reference |
|---|---|
| Navy / record header | `#0D2F57` |
| Primary blue | `#1769D2` |
| Ink | `#17263A` |
| Muted text | `#68778A` |
| Divider | `#DFE6EE` |
| Soft background | `#F5F8FC` |
| Success | `#0C8A61` |
| Warning | `#B77916` |
| Error | `#C53B45` |

Map these through existing `AppColors`; do not scatter literals. Preserve
existing offline-safe fonts and Arabic fallback. Typical radii are 9–14px with
restrained shadows, white cards, navy record headers, compact status chips and
formal white controlled-document pages.

Status never relies on color alone. Pair tone with text/icon/shape. Motion is
normally 150–200ms, non-blocking and disabled/reduced when the platform requests
reduced motion.

## 5. Shared components

Production components should cover:

- role-aware shell/sidebar/bottom navigation;
- page header with eyebrow, title, description and actions;
- current-action/owner banner;
- status chip and reason indicator;
- actor/role/time/version audit row;
- stat tile and information card;
- empty, loading, offline, saving, synced, conflict, failed and forbidden
  states;
- reason dialog and destructive confirmation;
- dynamic BOQ grid and focused mobile row editor;
- read-only table/grid projection;
- arrangement decision table;
- dispatch quantity editor;
- receipt outcome editor;
- document uploader/version/link list;
- formal controlled-document preview.

Extend existing shared widgets where their semantics fit. Do not fork nearly
identical screens by role when policy/actions can be injected safely.

## 6. Project screens

### Portfolio

- searchable/filterable project cards or rows;
- project reference, name, site, state, team summary and current action;
- Procurement variant explicitly says View Only;
- no arbitrary weighted-completeness percentage.

### Five-stage creation

1. **Project Details** — Yorks reference, name, client, job/contract reference,
   site, start/end dates and notes.
2. **Parties and Access** — consultant, main contractor, subcontractors, other
   contractors, Project Engineers and Site Engineers. At least one Project
   Engineer is required for activation.
3. **Buildings** — code, name, optional floors/levels and relevant flags. Common
   is system-provided, not a duplicate user-entered building.
4. **Attachments** — optional upload/link metadata with clear skip behavior.
5. **Review and Create** — grouped review, validation links back to stages and
   explicit connected creation.

Mobile uses the same five logical stages with focused sections and recoverable
draft state.

### Project workspace

Only these primary tabs:

- Overview
- BOQ
- Material Requests
- Documents

Overview shows project facts, team, scopes, counts, recent MRs and current
action. Team history/change controls appear only for Project Engineer/Admin.

## 7. BOQ experience

BOQ landing begins with an **All** overview followed by one explicit Common or
building selector. All summarizes each real scope's folders, started folders
and material count and opens a selected scope; it never flattens rows into an
editable table or provides an MR source/export target. A scope view uses
ordered folder/group cards with row/document/request counts. Legacy
project-level BOQs are labelled as requiring scope assignment and can only be
explicitly mapped to one real scope by an authorized engineer.
Group detail provides:

- editable worksheet title and headers;
- direct cell editing and visible active focus;
- Add Blank Row and Add Similar Row immediately below the active row;
- import/export;
- selected rows or entire group to MR draft;
- linked documents and linked requests;
- explicit autosave/sync/conflict state.

Desktop spreadsheet requirements:

- sticky header and S:No/first identity lane;
- Tab/Shift+Tab, arrows and Enter/Shift+Enter navigation;
- no focus loss during virtualized scrolling;
- inline row actions reachable by keyboard;
- clear column-delete confirmation if populated;
- usable at 500 rows and 1366x768.

Mobile BOQ is viewable and searchable. Editing opens one row in a focused full
screen/bottom-sheet editor with Previous/Next, Save and validation. Do not make
the 1160px desktop table the mobile editor.

## 8. Material Request experience

New MR fields:

- optional request title;
- project;
- Building/Common scope;
- Urgent, Normal or Scheduled timing;
- scheduled date only when Scheduled;
- optional delivery note;
- rows from BOQ, Excel or custom entry.

The draft screen makes “Draft — visible only to you” explicit. Selecting BOQ
content never submits and shows only folders in the chosen Common/building
scope. Changing scope confirms removal of incompatible BOQ-derived rows while
retaining custom/Excel rows. “Submit to Procurement” is the unambiguous
connected primary action with validation and connectivity state.

MR detail shows:

- reference, project/scope, requester name/project role and timing;
- current state, owner, next action and blocker;
- immutable requested line snapshots;
- current arrangement and earlier versions;
- approval decision;
- dispatch/receipt/DO/return chain;
- activity/documents appropriate to access.

Unauthorized viewers receive a non-commercial table with no cost columns.

## 9. Procurement arrangement and approval

Arrangement screen columns:

- requested item/context;
- decision: Full, Partial or Cannot Provide Now;
- source/supplier;
- requested quantity;
- arranged quantity;
- authorized Unit Cost;
- warehouse availability or required reason/note.

Partial rows use a warning treatment; unavailable rows remain visibly crossed
or exception-styled and are never hidden. The page summarizes reserved stock and
the effect of replacing the current version.

Project Engineer approval is a review screen, not an editable Procurement form.
It shows every line, all partial/unavailable reasons, reservation summary,
version and Procurement actor/time. Actions are Approve and Return to
Procurement with reason.

## 10. Inventory, dispatch and receipt

Inventory is a Procurement/Admin workspace with search, category filter, item
facts and on-hand/reserved/available/in-transit presentation. Movements are an
append-only history. Engineer request/approval screens show only permitted
context, not the general inventory/commercial workspace.

Dispatch editor shows Approved, Good Received, In Transit, Still Needed and
Dispatch Now. The server-provided maximum is explanatory, not trusted client
enforcement. Reference/date are required; driver/vehicle may be optional.

Receipt editor requires every line outcome:

- Received;
- Missing plus good quantity/note;
- Damaged plus good quantity/note.

It includes an explicit all-lines-reviewed confirmation and shows the resulting
replacement eligibility before commit.

## 11. Delivery Order and returns

DO preview is available from the committed dispatch stage and clearly
identifies its dispatch revision. On the Material Request detail, an authorized
Project/Site Engineer, Senior Mechanical Engineer, Project Manager,
Procurement or Admin sees **Generate Delivery Order** without waiting for
receipt confirmation. It contains only S.No, Description, dispatched Qty and
Unit; later receipt results remain separate.

Return creation uses project/scope first, then autocomplete restricted to
eligible received material. Each row shows available-to-return quantity. Return
detail exposes submit/confirm/reject ownership and immutable source links.

## 12. Formal documents

MR, DO and Return PDF/print share:

- Yorks bilingual company header/logo;
- document title and controlled reference fields;
- black/gray print-safe tables;
- source/revision/page number;
- final-page-only approval/signature/footer blocks;
- predictable wrapping for long names and multi-page rows;
- no browser pop-up dependency that produces blank tabs.

MR authorized columns: R No, Item Description, Brand/Origin, Qty, Unit, Unit
Cost, Total Cost. DO columns: S.No, Description, Qty, Unit. Return columns and
signature blocks follow the Rev 2.0 controlled format.

## 13. Accessibility and localization

- All user-facing copy comes from centralized strings with English and the
  configured secondary language.
- Controls have semantic labels, roles and error associations.
- Desktop office workflows are fully keyboard operable.
- Focus order follows visual order and remains visible.
- Validation names the field and remediation; it does not rely on a toast alone.
- Tables provide accessible row/column context where Flutter supports it.
- Contrast and text scaling are verified; fixed-height text containers are
  avoided.

## 14. Intentional deviations from the prototype

Production must not reproduce these prototype defects:

- localStorage auth, permissions, state, stock or audit;
- legacy hidden routes or stale command-palette links;
- always-visible commercial values;
- hardcoded English;
- 28–38px tap targets;
- horizontal-scroll-only mobile editing;
- incomplete arrow/Tab spreadsheet navigation;
- combined planning model and receipt serial;
- Remarks/column behavior that conflicts with Rev 2.0 controlled outputs;
- client-side hard deletion of downstream records;
- “Saved” feedback that means only localStorage rather than authoritative sync.

## 15. Visual evidence gate

Every UI batch supplies:

- desktop evidence at 1366x768;
- mobile evidence at 360px and an Android emulator/device;
- the relevant role variants;
- loading/empty/error/forbidden/offline/conflict states;
- commercial allowed/denied variants where applicable;
- keyboard and 44px target tests for grids/actions;
- a short parity checklist against the effective final R35 screen.

Batch 0 inspected the complete HTML/CSS/JavaScript override chain statically.
The in-app browser blocked the local `file://` artifact, so runtime prototype
screenshots/focus behavior were not independently verified. Each implementation
batch must verify the resulting Flutter screen directly rather than claiming
pixel parity from source inspection alone.
