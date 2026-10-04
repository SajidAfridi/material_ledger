# Universal workspace and Save draft verification — 4 October 2026

These browser captures use `tool/project_setup_visual_fixture.dart` with
synthetic permitted read context and ordinary browser draft storage. The fixture
has no remote backend. Completion is a synthetic confirmed result; it is not
evidence that a live Create or upload command ran.

The new project content sits inside the original `YorksV1WorkspaceShell`.
Desktop includes the persistent office sidebar and shared top bar; phone uses
the original compact workspace header. Setup supplies its own stage navigation,
forms and actions only. The owner correction supersedes the mockups' global
chrome. Field requirements and attachment restrictions retain the approved
behavior/security contract rather than adopting inconsistent sample copy.

## Captures

- [Desktop details](desktop-details.jpg), [parties](desktop-parties.jpg),
  [buildings](desktop-buildings.jpg), [building editor](desktop-building-editor.jpg),
  [attachments](desktop-attachments.jpg), [review](desktop-review.jpg) and
  [confirmed result](desktop-created.jpg).
- [Explicit save acknowledgement](desktop-save-confirmed.jpg),
  [saved exit to the synthetic Projects index](desktop-saved-exit.jpg),
  [restored input](desktop-draft-restored.jpg) and
  [Save on Review](desktop-review-saved.jpg). Back exited directly after Save,
  including after a screenshot and a phone/desktop resize.
- Phone at 360 CSS pixels: [details](mobile-details.jpg),
  [parties](mobile-parties.jpg), [building editor](mobile-building-editor.jpg),
  [attachments](mobile-attachments.jpg), [review](mobile-review.jpg),
  [confirmed result](mobile-created.jpg) and
  [Arabic at 200% text](mobile-arabic-200pct.jpg).

[Capture metadata](captures.json) records the actual CSS viewport. Provider
screenshots may resample pixel dimensions; the capture retains the full app
context and removes only compositor padding. Desktop captures use the available
browser size or a 1536 CSS pixel override. All temporary overrides were reset.
Phone editors/lists are scrollable with fixed reachable actions; these viewport
captures are supplemented by top/bottom widget goldens at 431px and interaction
checks at 360px. Canonical integration tests also cover 1280px and 1366px.

## Browser accessibility boundary

Fresh phone stages, Arabic 200% text and completion had no captured console
errors. Manual save and exit worked on desktop and phone. After accessibility
is enabled, a desktop/phone breakpoint resize can still emit Flutter's
`Semantics node map was inconsistent after update` error. The editor remained
operational and retained its input/save decision, but that resize accessibility
gate remains open. A plain shared workspace control did not reproduce the
nested form failure. Installed engine code contains a related nested subtree
cleanup defect; attribution of this app event to that code is an inference,
not a completed independent engine reproduction. Semantics remain enabled and
the Flutter SDK is unchanged.

The [release report](../../UNIVERSAL_WORKSPACE_AND_DRAFT_SAVE_2026-10-04.md)
records full gates, actual staging delivery and authenticated browser evidence.
