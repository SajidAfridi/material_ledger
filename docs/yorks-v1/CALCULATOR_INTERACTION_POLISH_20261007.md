# Calculator interaction refinement — audit candidate

The product owner requested this refinement on 6 October 2026, with a separate
Astra audit before production publication. **Production publication is not
authorized for this candidate.** Staging evidence is added after acceptance.

## Scope

- Creation uses one compact dialog: calculator selection, name and a searchable
  General/project scope picker. A typed search is not treated as a selected
  project. The create action requires a name and a real selection.
- Duct uses a code-native airflow mark, independent of a cached icon font.
- Desktop Import and Export are explicit controls. Export groups JSON and
  Print/PDF; phones use the compact Files menu. An editor import can be undone.
- Previous-device import reports available, missing and invalid stored data
  separately. It explains the same-browser/device boundary, offers a JSON-file
  alternative and preserves every legacy key, including corrupt data.
- The record title replaces the local breadcrumb/Back row. Shared top-bar Back
  and Forward consult the edit guard before consuming workspace history. Native
  Back retains the calculator guard and does not issue a second shell Back.
- Access management shares the creation dialog's tokens, search and dropdowns.
  Owner, individual grants, view/edit meaning, successful updates and failures
  remain explicit. Typed person searches cannot grant the previous selection.
- Managed dropdowns share an anchored, keyboard-operable menu. Their storage
  keys are isolated from expansion-panel state. Retained calculator routes keep
  their prior controls; no legacy golden is replaced to hide a regression.

## Edit history and keyboard

Undo/redo cover title, numeric values, engineering settings, imports and ESP row
structure. History is local to the mounted editor, limited to 100 snapshots and
8 MiB, with same-field typing coalesced for 650ms. Unknown imported fields and
row identities survive undo/redo and duplication. A new edit removes the redo
branch. Saving an existing record keeps local history; opening another record
or reloading starts a new session. Undo is a local edit and never rewinds a
server revision; the user must explicitly save it as a new revision.

| Action | macOS | Windows/Linux |
|---|---|---|
| Save | Command-S | Ctrl-S |
| Undo | Command-Z | Ctrl-Z |
| Redo | Shift-Command-Z | Ctrl-Shift-Z; Ctrl-Y also supported |
| Add row | Shift-Command-Enter | Ctrl-Shift-Enter |
| Duplicate row | Option-Command-Enter | Ctrl-Alt-Enter |
| Print/PDF | Command-P | Ctrl-P |

Row shortcuts appear beside the desktop buttons. Add/duplicate insert below
the active row; the last row is used when no row is active. An empty duplicate
retains the established safe first-row fallback. Shortcut help is in the
secondary menu. Buttons and shortcuts use the same permission, busy and pending
command guards. Flutter's overridable text actions prevent double undo; picker
search text retains native undo rather than changing calculator inputs.

## Telemetry

The existing guarded, opt-in PostHog service is reused. Calculator events have
a finite property catalogue: calculator kind, General/project scope, controlled
action, button/keyboard/file/device source, outcome, access mode and bounded
counts. No title, value, reference, query, filename, person, project/record ID,
file contents or raw exception is sent. Capture does not block commands.

Creation intent is distinct from server-confirmed creation. Save and access
outcomes are emitted only after the trusted command returns. List/open/options,
save and management commands have fixed operation names for timing and safe
failure categories. Routes map to identifier-free calculator library/editor
screens. Session replay and autocapture remain disabled in the client.

## Preservation and review

No calculator formula, repository, RPC, RLS, migration, grant policy, feature
default or production configuration is changed. The three existing sharing
manager roles remain Admin, Senior Mechanical Engineer and Project Manager;
project scope still needs project access. Server revision checks, idempotent
pending recovery, historical grants/audit and old device data are preserved.

The audit should review the creation and access dialogs, long searchable lists,
Mac/Windows shortcuts, query-vs-input undo, read-only and pending states, imported
extension preservation, shared Back/Forward, mobile/RTL layout and the bounded
telemetry catalogue. Physical device and printer acceptance is a separate gate.
Staging publication does not approve a production release.
