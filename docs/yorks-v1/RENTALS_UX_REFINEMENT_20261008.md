# Rentals UX refinement — 8 October 2026

## Request and scope

The owner asked to apply the Overview/Analytics improvement approach to Rentals.
The first reversible UI slice is prepared for staging review. Production rollout
preference was requested separately and has not yet been confirmed for this slice.

The [R38.4 rental contract](R38_4_RENTAL_PROPERTIES.md) continues to govern every
property, lease, receipt, cheque, workbook and document operation. Exact Admin
access, server version checks, idempotency and historical records are unchanged.

## Observed problems

Read-only production inspection of `/rentals` at desktop width showed repeated
headings, an import/export toolbar competing with the title, six monetary/ratio
cards before records and a misleading 0% occupancy for an empty portfolio.
Source inspection found mobile sections in a horizontal rail, property navigation
using replacement rather than a returnable detail route, and a wide property
editor whose two-column breakpoint made mid-width screens inefficient.

## First slice implemented

- One workspace heading in the existing universal shell.
- Compact import/template and export menus; Add property stays prominent.
- A mobile section dropdown exposes every existing register in one control.
- Property attention precedes the preview and KPI cards. Archived properties do
  not become vacancy/expiry actions, but outstanding balances remain visible.
- Empty portfolios explain Add property / workbook import without empty KPIs.
  Zero denominators render no percentage even in a nonempty historical portfolio.
- Property detail navigation uses push, preserving the register's search and tab
  when returning. Refresh loading does not present old data as newly confirmed.
- The property editor is bounded at 920px and uses two columns from 560px of
  form content; all existing fields and validation remain available.
- Changed workspace controls use centralized EN/AR/UR/HI copy, separate from
  stable workbook names and persisted business values.

## Further review identified

The remaining property-detail and editor copy is inherited English-only content;
full module localization is not claimed by this slice. A second slice should
simplify detail actions and progressive disclosure in the longer lease form.

The existing editor closes before its asynchronous save completes. In addition,
`saveProperty` performs a detail read after the mutation, so a rejected detail
read can be presented as a save failure after a successful write. A separate
command-result/recovery slice should preserve input, distinguish unconfirmed
outcomes, and retain the command key on retry. Do not treat a UI-only redesign as
proof of these transaction recovery semantics. No live payments or other business
records were created to test the design.

## Verification

The focused rental suite covers five-sheet template/import preview, duplicate
payment blocking, five Excel exports, controlled Documents, desktop/mobile
registers and detail, plus the empty-state/import-menu regression. Updated
visuals are under `test/goldens/r38_4/`. Full gate and staging results are recorded
below when complete. Physical-device, screen-reader and real-user acceptance
remain separate from browser and automated evidence.

### Completed gate and staging record

- Source: `3de1d8046bab49a0492fcdf6febd218d741df050`.
- Full Flutter suite: 2,560 passed, four retained skips; rental suite: 12 passed.
- Analyzer, dependency resolution, changed-file format and diff checks passed.
- CI web and ephemeral-signed APK gates passed. No distribution Android release.
- Local database reset and pgTAP: 125 files, 3,661 tests passed. No hosted schema
  or business data changes were made.
- Staging deployment: `dpl_DgQYDFzyFKLSfT2bJt6yDUbjaZCo` at
  `https://yorks-r35-n6jalcgky-sajid-alis-projects-0ec775a2.vercel.app`.
- Existing staging alias updated after 27 route/asset hash checks passed:
  `https://yorks-r35-staging.vercel.app/#/rentals`.
- Production remains unchanged. This is the first UI refinement, not completion
  of the wider save-recovery, detail-form and full localization work identified
  above.
