# Material Request File and Action UI

Status: implemented and locally verified

## Purpose

Material Request files and commands use one calm, recognizable visual system.
The file name, command label and server response remain authoritative. Colour
and icon shape provide a faster supporting cue without becoming the only way a
user can understand a file or action.

## File markers

The shared marker distinguishes PDF, spreadsheet, document, image, drawing,
archive and unknown files. Import and export actions add a small directional
badge to the underlying file marker. Unsupported formats use the neutral file
marker and are never presented as previewable merely because they have an
icon.

Primary file glyphs are Yorks-owned vector drawings rather than indirect font
icons. They therefore remain visible when Flutter optimizes icon fonts in web
and Android release builds.

Material Request discussion attachments show the marker, filename and byte
size. Ready uploads include a remove action before posting. Posted attachments
include a download cue and keep the existing protected download command.

## Record actions

Submitted Material Request headers have two stable action lanes:

1. authorized Cancel request, Edit request, then Arrange Items (or the current
   workflow decision), in that order; and
2. Excel, PDF, Print and Refresh, with Request Information at the directional end.

The 25 September 2026 user-approved header refinement makes Cancel request
visible beside Edit while preserving its destructive styling, confirmation and
trusted server command. Approvers see a separate, default-off Allow Procurement
to edit switch. Enabling directly grants the eligible Procurement role through one
server-confirmed command without a dialog; disabling removes Procurement delegation and keeps
any approver edit window. Editing access exposes the existing complete window
settings. Edit remains discoverable to eligible approvers while the window is
closed and opens that explicit settings confirmation before navigation.

No grant is inferred from a switch interaction or an optimistic local state.
Stale-version, revocation and arrangement-cutoff rules remain server enforced.
Mobile places grant settings in content rather than enlarging sticky workflow
actions. Narrow headers wrap action groups without squeezing record identity.

Desktop aligns both lanes at the end of the header. Narrow desktop and tablet
stack them below the request identity without changing their order. Mobile
keeps its existing focused workflow action and uses recognizable document
markers in its supporting actions.

## Request Information

Request Information uses one content model throughout creation, submitted
detail, arrangement, dispatch, receipt and return routes. The 25 September consistency refinement makes saved detail, arrangement,
dispatch/receipt and return views share one end-aligned, full-height overlay,
clamped to 430 logical pixels or 92% of the available viewport on phones.
RTL languages place it on the corresponding directional end. These routes
share the rounded surface, spacing, close control, subtle reduced-motion-aware
transition and bounded internal scroll. The workflow toolbar uses the same
open/closed panel glyph and expanded semantics; duplicate activation cannot
open multiple panels. History appears immediately inside the panel, followed
by workflow state/owner/next-action facts. Each route retains its authorized
stage-specific content. The draft composer retains its input-aware context
layout; no submitted history is invented for an unsaved draft.

Opening or closing the panel does not issue a command, refresh protected data,
or replace working input. Escape, Back, the close control and barrier dismissal
close only the information surface.

Routine request refreshes retain the last authorized history timeline while
one detail refresh future is resolved, then re-fetch history once. Explicit
history invalidation (including permission revisions) clears previous content;
access failures never fall back to cached history. The overlay panel fills the
available viewport height independently of loading/error/content height, with
internal scrolling for longer content. Header decisions share the identity row
when the available content width and text scale permit it, rather than relying
on the browser width alone.

## Acceptance

- Every action retains a visible text label or accessible tooltip.
- File format is never conveyed by colour alone.
- Touch targets remain at least 44 by 44 logical pixels.
- Long filenames truncate visually while the full filename remains the data
  used by the protected download.
- Drafts, quantities, comments and pending attachments survive opening and
  closing Request Information.
- Existing capability, RLS, document and audit boundaries remain unchanged.
- Optimized release builds show every primary file glyph; a coloured container
  without its glyph is a failed release state.

## External supplier arrangement refinement — 25 September 2026

Procurement can select Warehouse or External supplier directly, with an explicit
selected checkmark and the existing Yorks blue styling. Full external supply
continues to require neither a supplier name nor a reason. Save arrangement is
the single explicit, server-confirmed handoff; selecting a source never commits
stock or marks supplier readiness on the user's behalf.

Optional availability/date/reference fields and the overall Procurement note
start collapsed, preserving entered values while collapsed or resized. Existing
availability evidence opens initially; a published mandatory readiness policy
always exposes its controls and continues to block an unconfirmed save. Partial
and Cannot Provide Now retain their required exception reasons. The server RPC,
quantity validation, permissions, audit and analytics command paths are unchanged.
An immediate busy guard prevents repeat Save activation before the next frame.

The arrangement layout tests use the application theme and real fonts. Coverage
includes direct source selection, blank optional fields, live resizing through
1366/1024/768/360 widths, retained evidence, mandatory readiness and duplicate
Save activation. Existing arrangement validation, commercial revocation,
warehouse matching and retained-reservation tests remain in the focused gate.
There are no migrations in this UI slice; rollback is the preceding client
artifact, with no data rollback or historical record changes.
