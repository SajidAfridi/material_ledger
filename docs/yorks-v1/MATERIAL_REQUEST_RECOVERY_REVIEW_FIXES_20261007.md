# PR #53 recovery review corrections — 7 October 2026

The three P2 findings against `7a1e43d215a24d4b4afba7ce1f410dd320139fc2` were confirmed by tracing the recovery controller, global draft route and Save payload. They are client defects; this correction adds no database migration or production data cleanup.

## Corrected behavior

- **Accepted recovery baseline:** account recovery adoption and explicit Continue both set the accepted draft. Fresh-device recovery with 26 saved / 27 recovered lines can return without a false unsaved-changes prompt. Editing afterward and choosing Back → Discard restores the accepted 27 lines; it never calls the private-copy delete command.
- **Project revocation:** the comparison checks the recovered request's project, even on the global route. The controller provider observes permission, identity and role changes, immediately drops the protected server projection and invalidates in-flight reads. It retains owner-authored recovery and pending command intent. A newly authorized permission snapshot can re-fetch the comparison using the saved request's project context, including when local project selection is empty. Recovery denial does not replace ordinary draft error/retry handling. This is deliberately a narrow server-cache invalidation, not recreation of the draft controller from the app-wide cache list.
- **Complete comparison:** the view compares the non-commercial Save payload, matches lines by stable ID, and shows saved/recovered values for changed header fields, timing/date, delivery note, technical attributes, quantity, unit, source and order. Additions/removals are explicit; absent values say “Not set / cleared.” Project/scope changes are shown but do not bypass existing Save guards. Commercial fields never enter the comparison. Continue adopts the reviewed version; subsequent Save still uses server authorization and version checks.

## Regression evidence

- Fresh-device widget regression: 26 saved / 27 account-recovered lines → Continue → Back without edits; then edit → Back → Discard. Both preserve 27 device lines and issue zero account deletions.
- Global-route revocation widget regression: remove the saved request's project access while retaining another project's access and leaving the local project selection empty; comparison and controller server cache disappear immediately, local recovery stays intact, and regrant re-fetches the comparison.
- Controller regression: a protected request response arriving after revocation cannot repopulate the cache or authorize Continue.
- Comparison widgets: delivery-note-only difference, individually cleared model/size/equipment tag/planning tag/brand, and timing/cleared date. Commercial sentinel values remain absent.
- Updated, visually inspected [360px](../../test/goldens/r35/mr_recovery_review_360.png) and [1366px](../../test/goldens/r35/mr_recovery_review_1366.png) review evidence.

Validation: `flutter pub get`, changed-file format check, `flutter analyze`, and the full `flutter test` suite passed (**2,519 passed, four retained skips**). CI web build/startup budget passed (9,883,454-byte main bundle; 2,847,296 bytes gzip). The ephemeral CI-signed Android release build passed (111.9 MB); this is not a store-signed production APK. `git diff --check` and document links passed. No SQL changed, so database tests from the underlying repair were not rerun for this client-only correction. The earlier [database cleanup and release record](MATERIAL_REQUEST_DRAFT_REPAIR_20261007.md) remains historical evidence for that release, not proof that this follow-up is live.

## Preservation and rollback

No normalized request, line, archive, private account copy or migration is changed by this correction. Local unsaved input remains owner-scoped. Keep the database repair and archives from PR #53; a client rollback must not reinstate destructive recovery behavior. Browser/device acceptance and future production error rates remain distinct from automated regressions.

## Published follow-up

- Public app: <https://yorks-r35.vercel.app>.
- Runtime source: `835b569f7f7af2cec5c30aa19c2c1fbbe4e2ed24`, built from a clean isolated checkout with the existing production configuration and rollout flags.
- Deployment: `dpl_HhCHpT2robsQTTMagZzarPwAgbTK`; immutable URL: <https://yorks-r35-g4oiwhjun-sajid-alis-projects-0ec775a2.vercel.app>.
- Main bundle: 9,944,973 bytes (2,866,747 gzip); SHA-256 `8036bcf302c2246669de896c8958dec9860d52154f78f1075120d62904448df5`.
- Exactly 61 static files uploaded; source, environment files and Vercel local configuration excluded. Production backend, clean source stamp and absence of service-role JWTs verified before upload.
- Candidate and public deployment each passed all 26 route/asset hash checks, including deferred bundles and PWA files. The earlier `f892d4d` candidate was not promoted to the public domain.
- Signed-in Owner/Admin startup, the server-loaded 202-request register, seven-item My Material Requests view, and saved-draft open → Back passed on the published client. No Save, Submit or Delete action was invoked; browser error logs were empty. Fresh-device 26/27-line recovery and live revocation remain automated widget/controller evidence; production user records were not edited to reenact them.

The PR remains open for source review. Existing browser sessions should refresh to load the corrected client. No additional database mutation or cleanup was performed for these P2 corrections.

## Background typing correction — PR only, not deployed

The later P2 report identified a separate transition defect: autosync could receive `V1_PRIVATE_DRAFT_ALREADY_SAVED`, start a protected request read, and reject `_replace` calls before the visible form changed. A new controller regression reproduced the loss on the prior source: after typing “Typed during lookup,” the retained value was still “Before lookup.”

The controller now distinguishes the initial background lookup from a visible comparison/error. While that initial read is pending, the visible editor accepts and persists input; Save/Submit and private autosync remain paused. The comparison uses the latest draft, rather than the snapshot from before the wait. Completing the read, encountering an error, or invalidating authority ends that editing window. Newer lookups supersede older responses through the existing generation guard.

Regression coverage includes delayed autosync-triggered lookup and typing in the actual 360px and 1366px editors, device-store preservation before and after comparison, no second autosync, blocked Save/Submit during resolution, and rejection of edits/late responses after revocation. Existing recovery baselines and comparison goldens remain covered.

This typing correction is a source/automated-test update to PR #53. The preceding published artifact remains source `835b569f7f7af2cec5c30aa19c2c1fbbe4e2ed24`. Neither the new typing scenario nor the earlier three recovery edge cases has been reenacted against production user data; the recorded live checks were basic startup/register/saved-draft navigation only. No database changes or additional cleanup are part of this correction.

Final typing-correction gates: `flutter pub get`, changed-file formatting, analyzer and `git diff --check` passed; full Flutter suite **2,522 passed / four retained skips**. CI web/startup budget passed (9,883,525-byte main bundle; 2,847,322 gzip). Ephemeral CI-signed Android release build passed (111.9 MB), not a store release. No SQL changed, so database gates were not rerun. The new delayed-fetch regression failed on the old controller and passed after the correction; existing responsive recovery goldens also passed.


## Focused material-cell correction — PR only, not deployed

The background lookup continued accepting controller updates, but quantity and
size cells keep their input in a TextEditingController until blur or Enter.
Replacing the form at lookup completion disposed the focused cell before it
could commit. Four delayed-lookup widget regressions reproduced this on the
previous commit, covering quantity and size at 820px and 1366px.

The draft screen now registers a synchronous, screen-scoped focus flush with
its controller. A successful authorized lookup flushes blur handlers before
locking input and constructing the comparison. Lookup failures also flush
before replacing the form with the error state. Stale responses and revoked
access retain their existing generation/authorization guards. The registration
is removed when the screen is disposed or changes controllers. The controller
contains no Flutter focus or widget dependency.

All four regressions now prove that the field is still focused and its value is
uncommitted before completion, then confirm the edited value in both comparison
state and device storage. Existing title, authority-revocation, recovery-baseline
and desktop/360px visual golden coverage also passes.

Validation: dependency resolution and changed-file format check passed; analyzer
reported no issues; full Flutter suite passed 2,526 tests with 4 retained skips;
CI web build passed its startup budget (9,884,107 bytes, gzip 2,847,518); CI APK
build passed (111.9 MB, ephemeral signing, not a production release artifact).
No schema changes. This correction has not been deployed or runtime-verified
against a live cross-device recovery race.

### Owner draft diagnosis

Read-only production and the originating Chrome storage identify the requested
Shamsi draft as a stale local pending-save copy of an existing saved draft. The
local title is `testtest` with four lines, expected version zero and an unresolved
save operation from 18 September; the same ID is saved as `test` with one line at
version one. Status lookup found no receipt for that pending operation, and replay
returned HTTP 409. Absence of a title match was not treated as absence of the
underlying saved request. No unrelated Owner draft was selected for deletion.
The exact server snapshot is backed up outside the repository. Removal awaits
action-time confirmation for the browser's non-recoverable local copy.
