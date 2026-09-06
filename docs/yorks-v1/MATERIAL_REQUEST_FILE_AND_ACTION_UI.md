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

Material Request discussion attachments show the marker, filename and byte
size. Ready uploads include a remove action before posting. Posted attachments
include a download cue and keep the existing protected download command.

## Record actions

Submitted Material Request headers have two stable action lanes:

1. the current workflow command and authorized decision actions; and
2. Excel, PDF, Print, Request Information, request cancellation and Refresh.

Cancellation remains permission-controlled and moves under More actions so an
exception command does not compete visually with daily work. The existing
confirmation and trusted server command remain unchanged.

Desktop aligns both lanes at the end of the header. Narrow desktop and tablet
stack them below the request identity without changing their order. Mobile
keeps its existing focused workflow action and uses recognizable document
markers in its supporting actions.

## Request Information

Request Information uses one content model throughout creation, submitted
detail, arrangement, dispatch, receipt and return routes. Saved workflow views
open it as an end-aligned side panel above 720 logical pixels and as a tall
bottom sheet at or below 720. RTL languages place the panel on the corresponding
directional end.

Opening or closing the panel does not issue a command, refresh protected data,
or replace working input. Escape, Back, the close control and barrier dismissal
close only the information surface.

## Acceptance

- Every action retains a visible text label or accessible tooltip.
- File format is never conveyed by colour alone.
- Touch targets remain at least 44 by 44 logical pixels.
- Long filenames truncate visually while the full filename remains the data
  used by the protected download.
- Drafts, quantities, comments and pending attachments survive opening and
  closing Request Information.
- Existing capability, RLS, document and audit boundaries remain unchanged.
