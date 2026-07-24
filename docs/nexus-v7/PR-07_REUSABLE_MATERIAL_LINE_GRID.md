# PR-07 — Reusable MaterialLineGrid

Status: implemented and verified on 24 July 2026.

## Outcome

Batch 7 provides an isolated, reusable material-line editor for the approved
Yorks Nexus column contract. It is deliberately not connected to Phase 1,
Material Requests or another production workflow. Batch 8 can adopt the
component only after defining the normalized plan/version schema and its RLS
commands.

The debug-only diagnostic route is:

`/debug/material-line-grid`

It loads 500 rows, exposes desktop and mobile-preview modes and is removed from
the release route tree through `kDebugMode`.

## Grid decision

The spike uses native Flutter widgets with two virtualized `ListView.builder`
lanes:

- a frozen S:No/status lane;
- a horizontally scrollable editable lane with a sticky header.

This was selected instead of a third-party data-grid dependency because it:

- preserves the existing Flutter/theme stack;
- gives exact control over the approved ten-column contract;
- keeps commercial columns physically absent for denied sessions;
- supports a separate mobile card/editor interaction;
- virtualizes 500 rows without building 500 rows of text fields at once;
- avoids introducing a large dependency before the workflow/domain schema is
  ready.

The controller is independent of Riverpod and can be owned by a future
workflow provider. It supplies immutable snapshots, undo/redo, validation,
Excel TSV paste and debounced autosave callbacks.

## Exact columns

The desktop grid renders:

1. S:No
2. Item Description
3. Size (If any)
4. Model/Serial No.
5. Make/Origin
6. QTY
7. Unit
8. Remarks
9. Unit Cost
10. Total Cost

Columns 9 and 10 exist only when the controller receives an authorized
commercial payload. The operational line model, denied controller state and
denied CSV contain no commercial field or value.

## Smart-row rules

Add Similar Row carries:

- Item Description;
- Size;
- Make/Origin;
- Unit;
- Remarks.

It clears:

- the derived S:No;
- Model/Serial No.;
- QTY;
- Unit Cost;
- derived Total Cost.

Manufacturer serials are never incremented or copied automatically.

## Editing behavior

- Tab and Shift+Tab use ordered Flutter focus traversal.
- Enter and Shift+Enter move vertically in the same column.
- Cmd/Ctrl+V and the Paste action accept Excel tab-separated rows.
- Blank Row, Similar Row, undo and redo retain complete snapshots.
- Validation identifies missing description, positive quantity and unit while
  preserving incomplete draft data.
- Autosave is debounced and receives commercials only for an authorized
  controller.
- CSV uses the exact visible schema and RFC-style quote escaping.
- The size builder supports rectangular, circular, linear, nominal-pipe and
  custom values.

## Responsive behavior

Desktop keeps the serial lane and header fixed while rows and columns scroll
independently. A footer makes additional horizontal columns explicit.

Mobile/tablet uses virtualized compact row cards. Tapping a card opens a focused
editor with a persistent Save action and the same structured size builder. It
does not render a squeezed desktop table.

## Performance evidence

- The diagnostic screen constructs 500 representative HVAC rows and reports
  the construction duration.
- Browser inspection built only the visible row window.
- The widget test proves row 500 is not mounted initially.
- A 500-row controller edit must complete within the deliberately generous
  200 ms regression budget.

## Supabase and security

No Supabase table, policy, grant, Storage bucket or realtime collection changes
in this batch. The spike does not persist a production record.

The future Phase 1 integration must map operational lines and protected
commercial line records to separate normalized tables/views. It must not store
Unit Cost inside the operational plan-line payload.

## Verification

- material-line model, controller, smart-row and security tests;
- Excel paste, validation, autosave, size formatting and CSV escaping tests;
- exact denied/authorized desktop-column tests;
- 500-row virtualization and edit-budget tests;
- keyboard navigation test;
- mobile card/focused-editor test;
- structured-size dialog test;
- router validation for every role;
- desktop, mobile-card and focused-editor browser inspection;
- Flutter analyzer, complete regression suite, release web build and diff
  validation.

## Rollback

Rollback is additive:

1. remove the debug route and demo screen;
2. remove `MaterialLineGrid`, its controller, draft models and CSV service;
3. restore the catalogue downloader's fixed filename signature;
4. remove the Batch 7 tests and this record.

No production data rollback or Supabase migration reversal is required.

## Next controlled slice

Batch 8 / PR-08 integrates the grid into the normalized Phase 1 plan workflow:
immutable versions, Procurement arrangement/comments, Engineer
approval/changes, append-only activity and project activation. Advisory
availability must not reserve stock.
