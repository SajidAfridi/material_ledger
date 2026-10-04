# Universal Yorks workspace and explicit local draft save — 4 October 2026

Status: implementation and local gates passed; staging release verification in progress.

## Product-owner correction

The supplied new form designs belong inside the existing universal Yorks top
bar and persistent office sidebar. The previous release retained feature-owned
global chrome and connected its drawer/search to the workspace; that did not
satisfy the requested integration.

The create/edit route now renders the ordinary `YorksV1WorkspaceShell`.
Project setup supplies only content: heading, local save state, stages, forms,
review and action footer. The original shared header/sidebar, capability-filtered
destinations, keyboard search, account controls, sync state and navigation history
remain visible. Only draft-aware Back handling is delegated to the feature via
`featureOwnsBackNavigation`; there is one workspace zoom host. Layout decisions
use the content width remaining after the universal sidebar.

## Reported Save draft behavior

The previous manual button had no acknowledgement feedback beyond the same
already-autosaved status. Leaving still displayed the saved-draft dialog after a
manual save. Explicit Save draft now waits for durable local acknowledgement,
reports the result and permits leaving unchanged input without another warning.
Subsequent semantic edits restore the guard; navigation/disclosure state does
not invalidate the acknowledgement. Selection/composition-only date notifications
also preserve the confirmation; unfinished newly typed dates remain recoverable
and restore the exit guard. Local persistence failures retain input and report
failure instead of claiming a save. The confirmation toast belongs to the feature
Scaffold and leaves the stage rail and footer available.

A stable keyed route viewport preserves the actual editor State, controllers,
selection and pending input across sidebar/layout changes. Transient 1×1 browser
views defer impossible chrome without remounting the editor. Initial ownership
claim failures can retry with the existing fence. If storage recovery discovers
a newer/different/retired draft or another owner, it preserves both the original
slot and the current proposal in a unique quarantine record; it does not take
ownership or overwrite retained data. Delayed native acknowledgements also
capture newer proposal revisions before publishing a read-only refusal. Failed
quarantine acknowledgement retains the latest visible input and blocks unsafe
exit.

There is no new server command, SQL, RLS, role/capability or cloud draft behavior.
Save draft remains private to the current Auth user, backend and device.
Production remains a later release.

## Local validation

- `flutter pub get`: passed; dependency lock unchanged.
- `dart format --output=none --set-exit-if-changed` for all 14 changed Dart
  files: passed.
- `flutter analyze`: no issues.
- `flutter test`: **2,297 passed, four existing skips**.
- Focused draft reliability: **22 passed**, including retry, retained records,
  competing ownership and delayed acknowledgement/newer-input failure cases.
- Canonical workspace integration: **20 passed**, including permissions loading
  and denial, real Projects → Create entry/reentry, shared search/Back/Forward,
  Save → immediate exit and 1536 → 360 → 1×1 → desktop state preservation.
- Desktop/mobile interactions: **41 passed** without golden updates. Twenty-four
  affected goldens were intentionally refreshed for content-only presentation;
  no unrelated golden was updated.
- CI web with `YORKS_V1_PROJECT_SETUP=true`: passed, including startup budget:
  main JavaScript 10,004,347 bytes / verifier gzip 2,881,058.
- CI APK with `YORKS_CI_EPHEMERAL_SIGNING=true`: passed. APK signature v2 verified;
  certificate `CN=Yorks CI Ephemeral, OU=CI Only, O=Yorks, C=AE`. This is a CI
  validation artifact, not a production-signed Android release.
- `git diff --check` and all local links in changed reports: passed.

[Browser captures and scope](visual-evidence/universal-workspace-2026-10-04/README.md)
cover all five stages and confirmed-result presentation on desktop and 360px,
manual Save/exit/reentry, building-edit guarding and Arabic at 200% text. They
use a synthetic local fixture, not a remote project creation. The previous
post-accessibility breakpoint-resize Flutter engine semantics-map error remains
an open browser accessibility gate. Fresh phone/RTL sessions were error-free;
state/input/save decisions remained operational through the resize reproduction.
The SDK and accessibility remain unchanged.

There are no database changes. Database reset/RLS deployment, authenticated
live Create/Update/upload, real-device Android acceptance, production signing
and hosted-CI acceptance are not claimed. Historical evidence is retained in
earlier reports rather than relabelled as a pass for this change.

## Staging release

Source/artifact identity, route verification and authenticated staging browser
evidence will be added after release. Only the existing staging alias is
authorized. Production remains at its inspected prior deployment.

Rollback is the default-off `YORKS_V1_PROJECT_SETUP` flag or the previous verified
staging deployment. Preserve draft, journal, quarantine and tombstone namespaces.
No database rollback or historical-data mutation is needed.
