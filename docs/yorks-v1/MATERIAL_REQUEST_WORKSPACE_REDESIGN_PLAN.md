# Material Request workspace redesign: integration and acceptance plan

Status: proposed implementation plan; application changes and release pending.
Prepared: 8 September 2026.
Inspected source: `dd8708cc66cadb88c93072b28c1e6caf09c3ba66`.

## 1. Outcome and scope

Integrate the reviewed Material Request design into the existing Flutter
workflow. Make the current task clear, give material items more usable space,
and put request information and factual history in one optional panel.
Preserve every authorized operation and its existing server-side rules.

The scope covers shared presentation across creation/editing, submitted
request detail, Engineering approval, Procurement arrangement/clarification,
dispatch, receipt review, and linked Delivery Orders/returns. Phase 2 approval
is the first visual implementation slice, not the only acceptance scenario.
The register receives regression coverage; it is not being redesigned.

The user requested a plan in this turn. This document does not claim that the
new UI has been implemented, tested end-to-end, staged or released.

### Reviewed visual references

- [Information panel open](design/material-request-workspace-20260908/panel-open-concept.png)
- [Information panel closed](design/material-request-workspace-20260908/panel-closed-concept.png)

These generated images contain illustrative data. They establish hierarchy
and appearance, not field authority, exact text, responsive measurements or
proof of functionality. The measured Flutter references produced in MRUI-01
below become the visual acceptance baseline. No mock names, quantities, audit
events, verification ticks or example-data labels enter production.

### Authority and constitution

Follow [source authority](SOURCE_OF_TRUTH.md),
[product decisions](PRODUCT_DECISIONS.md),
[UI contract](R35_UI_CONTRACT.md),
[architecture/security](ARCHITECTURE_AND_SECURITY_CONTRACT.md), and the
[current operating guide](CURRENT_MATERIAL_REQUEST_USER_GUIDE.md).
The user's Constitution v1.1 informs clarity, familiar interaction, preserving
work, truthful state, proportional confirmation, accessibility and verification
(particularly sections 8–14, 22–32, 35–49 and 61–63).

Use the later approved approval-first workflow and the 7 September
[Procurement clarification contract](MATERIAL_REQUEST_PROCUREMENT_ITEM_CLARIFICATION.md).
Earlier arrange-then-approve language applies only to retained legacy requests
whose actual history requires that lane. This redesign does not convert them.

## 2. Findings from the current implementation

| Inspected area | Current behavior | Integration consequence |
|---|---|---|
| `_RequestDetailBody` in `yorks_v1_material_request_screens.dart` | Desktop uses a fixed 372px rail; non-desktop places rail content above the operational content. | Replace the layout composition with an optional inspector; preserve the underlying action/access resolution. |
| `_RequestedItemsSurface` | The read-only table has a 920px minimum width and horizontal scrolling. | Available main-column width must drive docking and table layout; a 14-inch monitor alone does not guarantee enough space. |
| `yorks_v1_request_information.dart` | Saved routes use a 440px modal side panel, or a bottom sheet at 720px and below. | Introduce a docked mode with shared content/state ownership; retain an accessible sheet where docking would squeeze the task. |
| `_RequestRecordContent` | Material items, quantity ledger, formal preview, arrangement, dispatch/receipt and documents/returns all have existing surfaces. | Every surface needs an explicit destination. Collapsing future work must not remove active work, exceptions or document preview. |
| `_RequestApprovalActions` | Existing confirmation, required return reason, permissions, versioned command and refresh behavior. | Move the same decision behavior into one action area; do not replace it with a visual-only button or synthetic checklist. |
| `YorksV1MaterialWorkflowCommandController` | Acquires and confirms durable command identities around the existing commands. | Preserve its retry behavior across remounts, resizing and panel changes. |
| Audit sources | `v1_get_audit_workspace` explicitly requires Admin. `v1_project_audit_projection` is project-wide, without request paging. | Neither is a drop-in source for the proposed ordinary-user request history. A narrow request-authorized history projection is required. |
| Shared typography | Yorks uses its bundled `NexusSans` and Arabic fallback, not Segoe UI. | Keep the existing font family; adopt familiar Windows interaction patterns without changing the app-wide font. |

These are source observations, not a new live-production audit. The current
application has substantially more behavior than the four-row design example.

## 3. Functional preservation map

Every row must have a recorded old entry point, new entry point, applicable
actor/state, command/projection, and acceptance test before cutover.

| Function | New presentation | Required preserved behavior |
|---|---|---|
| BOQ/custom/Excel creation and smart search | Existing focused editor inside the shared workspace shell | Scope checks, descriptive-only search, deliberate quantity, import validation, no implicit submission. |
| Private draft, server recovery, edit and resubmit | Same editor and draft-exit guard | Unsaved input survives; draft visibility and submission history stay intact. |
| Initial Engineering approval/return | One top-right decision group beside the request identity on wide layouts, retained in the mobile task action surface | Confirm exact request/version; retain required return reason and published self-approval policy. |
| Procurement identity correction and reapproval | Clearly visible original-versus-corrected comparison before the decision area | Saved correction returns to Engineering; arrangement remains blocked until the exact revision is approved. Further correction invalidates that approval. Preserve working arrangement and post-save edit lock. |
| Full/Partial/Cannot Provide Now | Current arrangement section/editor | Required reasons, source/readiness policy, reservation and quantity checks, all-unavailable behavior. |
| Dispatch and replacement dispatch | Active logistics section and appropriate primary action | Approved outstanding caps, inventory availability, one movement per committed effect. |
| Receipt, including mixed good/missing/damaged | Existing focused receipt editor | Exact reconciliation, outstanding replacements, evidence upload and server confirmation. |
| Delivery Orders | Visible action beside eligible committed dispatch; formal preview remains reachable | Available from dispatch, independent of receipt; immutable dispatched quantities and numbering. |
| Returns | Linked records and existing project/scope return workflow | May span multiple requests; eligibility, approval, handover and Procurement physical confirmation remain intact. |
| Quantity history | Expandable ledger beside material items | All existing requested/arranged/reserved/dispatched/good/missing/damaged/returned/still-needed facts. No recalculation from visible rows. |
| PDF, print, Excel and formal preview | Grouped utilities plus explicit preview entry | Existing canonical columns, capability-dependent commercial fields, shared PDF/print bytes and document history. Item filtering does not silently change an export. |
| Discussion | Full main-workspace-width section at the end | Paste, mentions, replies, attachments, upload/retry, earlier pages, exact-comment notification links and optional Team Chat. |
| Claim/reassign | Quiet Coordinator section in the inspector | Assignment is not approval authority; preserve reason, stale-write checks and notification behavior. |
| Cancel, close and replacement draft | State-appropriate task action; when cancellation is the only secondary destructive action it is shown directly as a red outlined button | A calm confirmation-first dialog retains the required reason, eligibility, reservations, provenance and retained records. |
| Refresh, direct links and Back | Same routes with predictable transient-panel behavior | Realtime remains a refresh signal; stale/denied records cannot retain enabled actions or protected content. |
| Historical/closed/cancelled requests | Readable retained record with history and documents | Never imply a new approval, remove history or unlock a completed operation. |

Existing urgent/scheduled delivery information, delivery notes, return reasons,
change summaries, current-owner facts and exceptions must stay discoverable.
An omitted element in a generated image is not authorization to delete it.

## 4. Shared layout and interaction contract

### Stable reading order

1. Request number, title, project and real scope.
2. Grouped utilities: Edit where allowed; Excel, PDF/preview, Print; More;
   Refresh; panel icon with the persistent label **Request Information**.
3. One status summary: state, current owner, actionable next step, relevant
   delivery timing and blocker. Keep the stage cue; expose the complete
   lifecycle through an expandable progress/history view.
4. Current material/operational task with its one top-right decision group on wide layouts.
5. Secondary history/documents/later phases, expandable as appropriate.
6. Request discussion.

Use one mounted decision controller and one visible action group per task. The
approved visual-reference adaptation keeps Approve and Return for changes in
the top-right request header on desktop; mobile retains the existing reachable
task action surface.
For long content, that group may pin within the main workspace without
covering rows or the final fields. On mobile use the established safe-area
action bar. Do not introduce another independent copy in the header.
Approval confirmation remains proportional to its existing workflow meaning.
Return for changes continues to require a reason.

### Material table and search

- Preserve the operational descriptive fields, original order, stable line
  IDs, full descriptions, numeric formatting and separate units.
- Use **Model / Tag** for planning identity, preserving the underlying model
  and equipment-tag distinctions; do not imply a manufacturer serial number.
- Right-align quantities. Do not sum different units or turn missing fields
  into fabricated values. Clearly distinguish absent, denied and failed data.
- Wrap long descriptions and technical values; retain readable typography,
  sticky identity/header and keyboard-accessible scrolling where required.
- Find an item matches permitted description, size, model/tag and brand text.
  It preserves original line numbers and displays “N of M items”. Filtering
  does not change approval scope: explain that approval applies to the entire
  request, and keep exception/change indicators visible outside the filter.
- Design and measure at 1, 25, 100 and 500 lines. Bound row rendering when
  needed. A four-row screenshot cannot pass large-request acceptance.
- Creation keeps editable fields and existing spreadsheet keyboard behavior;
  read-only detail must not appear editable merely to resemble Excel.

### Panel and state persistence

- Same panel icon, text label, placement, tooltip and selected indication on
  creation, detail, arrangement and logistics-related screens.
- Contents: request facts; request-scoped history; Coordinator. Drafts show
  their legitimate private context and no invented submission/approval event.
- Initial preference: closed to prioritize work. Remember only the layout
  preference per user on the device, separately for wide/compact modes.
  Record position/expanded sections are session state keyed by request ID.
  Do not persist sensitive history as a general preference or leak it on logout.
- Docked panel uses local presentation state, no dimming and no focus trap.
  Closing returns focus to its toggle. Escape closes the active transient
  surface first; ordinary browser Back remains route navigation in docked mode.
- Compact overlay/sheet is modal with a labelled close control, focus
  containment, safe-area handling and Back/Escape closing the sheet first.
- Resizing must preserve row focus, both scroll positions, draft/comment text,
  reply target, attachments, arrangement input and command-in-progress state.
  Keep controllers above the responsive branches; never rebuild an editor's
  identity solely because the panel changes mode.
- Opening the history may issue one lazy authorized read. Closing/reopening
  reuses fresh permitted results; no automatic workflow writes or repeated
  full-workspace refetch. Failure of history alone must not erase the request.

### Stage-aware disclosure

At initial approval, empty future phases may be one compact collapsed section.
When arrangement, dispatch, receipt or return contains current work, a blocker,
an exception or relevant records, expose its summary and action immediately.
Expand the required section on an action/notification deep link. Never hide
partial or missing/damaged quantities solely to keep the screenshot tidy.
Keep formal preview and linked Delivery Orders accessible independently of
receipt completion. Keep procurement corrections prominent during reapproval.

For Steps 2 and 3, the combined Procurement, delivery and returns disclosure
stays collapsed until it has a real working/saved arrangement, dispatch,
receipt, return or recoverable data failure. If an operator opens it earlier,
future phases use compact, left-aligned status rows rather than large centered
empty-state canvases. Request discussion remains a separate full-width section
immediately after the disclosure and is never placed inside its collapsible
subtree. Quantity-ledger headers use balanced minimum widths and header-only
density so a single trailing character does not wrap while an oversized Item
column consumes the available canvas.

### Discussion continuity

Reuse the existing discussion controller and protected commands. Preserve
newest-20 paging, older-page cursors, copy/paste, selected mentions, reply
context, upload progress, failures and stable retry identities.
The secondary Team Chat action moves under a clearly labelled More menu.
Attachments retain their file marker, filename, size and protected action.
An exact-comment link loads the required page, opens any collapsed discussion,
scrolls to the comment and briefly highlights it without losing typed input.
Unavailable/deleted/forbidden targets receive a meaningful state, not a jump
to the top or an endless loading state.

## 5. Request history data contract

Proposed additive read surface: `v1_get_material_request_history` with request
ID, bounded limit and a stable cursor. Confirm exact naming during implementation.
Reuse existing audit and immutable decision evidence; do not create a second
audit store or copy project-wide audit data into Flutter for client filtering.

Required response fields include event ID/type, root request ID, related record
type/ID, recorded actor name/role, UTC occurrence time, permitted reason,
record/revision reference, and explicitly allowlisted operational change data.
Use retained actor snapshots. A missing historical identity is **Not recorded**
or clearly labelled as an unverified current identity, never silently presented
as a verified historical name. Historical events must survive actor departure.

- Recheck the current actor and exact request readability on every page.
  Preserve creator-private drafts and pre-approval Procurement denial.
- Include related arrangement, clarification, decision, dispatch, receipt,
  document and return events only through validated relationships to this MR.
  A project-scoped return involving other MRs must not disclose their lines or
  unrelated sensitive details through this history.
- Return field-allowlisted data. Do not send raw `before_data`/`after_data`,
  costs, private system events or other request content and hide it in widgets.
- Initially display the latest 5 events, newest first. Load full request
  history in pages of 20 using `(occurred_at, id)` ordering. Handle simultaneous
  new events without gaps or duplicates; unknown allowed event types receive
  neutral truthful labels. Approval Pending is current state, not an audit event.
- “View full audit trail” opens the complete history for this request under
  the same authorization. It must not route ordinary users into the Admin-only
  organization audit workspace or grant new Admin privileges.
- History errors show Retry and retained-data status. Empty history must be
  distinguishable from denied/unavailable history. Realtime refresh is bounded
  and read-only; opening a panel never records a fake approval/view event.
- Add a forward-safe migration and indexes only as necessary. Existing
  audit events, IDs, timestamps, decisions and notifications remain untouched.
  Test direct-call denial, inactive/revoked/wrong-scope users and redaction.

## 6. Responsive measurements and visual acceptance

Use existing Yorks tokens, not image-estimated literals or global restyling.

| Concern | Proposed starting specification |
|---|---|
| Shell | Retain current sidebar/top-bar behavior and `AppSpacing.topBarHeight` (64). Validate expanded and collapsed global navigation. |
| Page | `AppSpacing.pageMaxWidth` (1740); outer desktop padding `xxxl` (32), compact `lg` (16), section gap `lg` (16). |
| Surfaces | `radiusMd` (10), existing divider/surface colors, restrained shadows; consistent section headers. |
| Titles/body | Existing `AppTypography.headlineMedium` (24), `titleMedium` (16), `bodyLarge` (16) for decision-relevant text. Use bundled font and RTL fallback. Metadata may be smaller, not critical quantities/actions. |
| Controls | `AppSpacing.minTapTarget` (44), common height and aligned icon/text baselines; no pill-sized primary buttons spanning half the screen. |
| Inspector | Start from `AppSpacing.inspectorWidth` (330), inner `lg` (16), gap `xxl` (24). Verify real localized content before freezing widths. |
| Docking | Measure available workspace **after** sidebar and gutters. Dock only if main content can retain at least 800 logical pixels plus inspector/gap: initial threshold 1154. If long text/scaling cannot fit, prefer a sheet over reducing text size. |
| Compact | At/below the existing 720 boundary use focused cards and the tall information sheet. Intermediate widths use a side sheet as needed. Keep the existing global-shell breakpoint separate from workspace docking. |
| Motion | Reuse the 180ms panel transition; reduced motion makes it immediate. No animation blocks reading or commands. |

The 800px minimum is a proposed design measurement to prove with real rows,
not a claim that the current 920px table already fits. The new table should
allocate recovered width primarily to descriptions and technical values.

Reference matrix: 1366×768, 1512×982, 1920×1080 and 2560×1440; tablet
1024×768 and 820×1180; mobile 390×844 and 360×800. Include both panel states
where meaningful, global sidebar open/closed, browser zoom 100/125/150/200%,
English/Arabic/Urdu/Hindi, long names and increased text scale.
The same monitor can require different modes with OS scaling or window resizing.

Pixel acceptance means measured component geometry and typography at pinned
viewports, not copying generated image artifacts. Produce Flutter captures,
overlays and golden comparisons. Investigate anchor alignment differences over
2 logical pixels; do not blanket-update goldens to hide regressions. Require
no clipping, accidental page-level horizontal overflow, obscured action,
missing glyph or unexplained spacing mismatch. Accept intentional platform
font rasterization differences separately from layout differences.

Verify keyboard traversal, visible focus, appropriate semantics, screen-reader
announcements, 44px targets and measured contrast (4.5:1 ordinary text, 3:1
large text/meaningful control boundaries). Test actual Windows Edge/Chrome and
macOS browser interactions. macOS browser emulation is not a Windows witness.

## 7. Implementation slices and exit gates

These IDs are local to this redesign, avoiding existing historical task IDs.
Implement sequentially with focused proof before expanding the shared shell.

| Slice | Work | Exit evidence |
|---|---|---|
| MRUI-01: Baseline and measured design | Complete the preservation matrix for live code, capture baseline UI/states, define component geometry and adapt the two concept references to real fields and fonts. Freeze command placement and responsive behavior. | Every existing function mapped; approved measured open/closed references; baseline results explicitly recorded. |
| MRUI-02: Shared workspace shell | Extract small composition widgets, consistent utility bar, state strip, panel toggle and responsive inspector. Keep controllers/commands intact. First integrate initial Engineering approval. | Panel toggle, resize, Back/Escape, focus and retained-input tests pass; no mutation on open/close. |
| MRUI-03: Protected history | Implement request-authorized history projection, paging, provider/repository and inspector timeline/full-history view. | Positive/negative access and redaction tests; complete retained events; bounded reads; no invented history. |
| MRUI-04: Materials and decision area | Build readable adaptive table/cards, local item find, quantity-history disclosure, one top-right desktop decision group and preserved confirmations. | Search never changes decision/export scope; edits/approval/return and stale/timeout cases pass; long and large requests remain usable. |
| MRUI-05: Whole-flow consistency | Apply shared shell/panel to editor, arrangement/reapproval, logistics and document/return surfaces. Make active sections prominent; retain discussion and exact-comment links. | Complete workflow preservation matrix green, including clarification reapproval, legacy lane and exceptions. |
| MRUI-06: Visual and functional acceptance | Complete browser/device, localization, keyboard/accessibility, performance, security, quantity and end-to-end evidence. Run repository gates and document remaining issues. | No missing function or open blocking defect; every required scenario has evidence, not just a screenshot. |
| MRUI-07: Staging and release | Build a controlled candidate, rehearse with named staging actors, collect user review, then release through the normal authorized production process with rollback. | Same source/artifact/backend identified throughout; staging sign-off; verified production routes/PWA/config/assets and a usable rollback artifact. |

A new presentation rollout switch, if used, defaults off and is enabled for the
staging candidate only after its dependencies pass. Proposed name:
`YORKS_V1_MR_WORKSPACE_REDESIGN`. Keep the old presentation available during
acceptance without maintaining duplicate business logic. Its state must not
alter unrelated feature flags, especially Overview/Analytics or Accounts.

### Expected code boundaries

- Main integration: `lib/features/materials/presentation/screens/yorks_v1_material_request_screens.dart`.
- Shared panel: `lib/features/materials/presentation/widgets/yorks_v1_request_information.dart`.
- Related screens: `yorks_v1_arrangement_screen.dart`, `yorks_v1_logistics_screen.dart`,
  `yorks_v1_returns_documents_screen.dart` in the same screens directory.
- Reuse models/providers/repositories: `yorks_v1_material_request*`,
  `yorks_v1_arrangement*`, `yorks_v1_logistics*`, existing documents/discussion
  services and `yorks_v1_material_workflow_command_controller.dart`.
- Add small workspace/table/decision/history widgets under the existing
  materials widget directory; avoid growing the 15,000+ line screen file with
  another self-contained framework. Extract only the surfaces this task touches.
- Add strict history DTO/repository/provider through the normal
  Widget → Riverpod → repository → protected query path.
- Keep `lib/app/router.dart` changes limited to preserving entry/return and
  exact-comment behavior or a request-scoped full-history destination if needed.
- Add history SQL/permission tests in the normal migration/database-test
  directories; preserve existing mutation RPCs.
- Localize all changed copy using current strings/providers. Existing uses of
  `.primary` in touched widgets require review so selected language is respected.

## 8. Verification matrix

### Functional end-to-end journeys

1. Create with BOQ, Excel and custom input; recover draft; submit; approve;
   arrange warehouse/supplier; dispatch; generate DO; receive; close.
2. Return before approval with reason; edit; resubmit; confirm original number,
   change summary and immutable decision history.
3. Procurement changes description/model; Engineering sees original and
   revised identity; approval unlocks the same arrangement. Repeat correction,
   rejection, stale decision and post-save lock scenarios.
4. Full/partial/unavailable arrangement with readiness policy both permissive
   and enforced; all-unavailable cancellation and one linked replacement draft.
5. Partial dispatch, mixed missing/damaged receipt, replacement dispatch and
   exact outstanding reconciliation; quantity history matches source facts.
6. Project/scope return with eligible lines, approval, handover and Procurement
   confirmation; no duplicated stock and no unrelated request data in history.
7. Comment paste, mention/reply, multiple supported files, failed upload/post,
   safe retry, older paging and notification jump to an older exact comment.
8. Claim/reassign, cancel and close, refresh and direct deep links; Coordinator
   never substitutes for workflow owner or grants an action.
9. Actual PDF/print/Excel preview/download and long/multi-page documents. Keep
   file icons visible in optimized release builds and preserve prior approved
   print-field/logo changes. Verify exported rows are not the local filtered subset.
10. Legacy request with retained post-arrangement approval and historical actor
    snapshots; no synthetic approval-first conversion.

### Recovery, permissions and scale

- Anonymous/inactive/revoked/wrong-project users and all nine exact roles;
  explicit capability grants/denials, private drafts and commercial redaction.
- Offline before command, network interruption after commit, double click,
  repeated idempotency key, conflicting payload, concurrent reviewer and stale
  version. Assert absence of duplicate state/stock/document/notification effects.
- Loading, refreshing, empty, invalid, failed, denied and uncertain states.
  A projection error must not become “No dispatch yet” or zero quantities.
- Panel open/close while composing, uploading, searching, editing, scrolling,
  command submission, role revocation and switching to another request.
- History pagination with concurrent events; many comments and 500 material
  lines; long localized strings, fractional quantities and mixed units.
- Measure before/after under the same fixture/device. Proposed local targets:
  visible panel response within 100ms excluding animation/network, no command
  calls from layout interactions, no request-history fetch loop or per-event
  query fan-out. These are acceptance targets, not measured guarantees.
- Regress authentication, app navigation, BOQ, Inventory, notifications,
  Overview/Analytics, Accounts, Workforce and Rentals where shared code touches
  them. Do not expand the redesign into those modules.

### Automated and manual evidence

Extend existing meaningful request/action/trust/realtime/arrangement/logistics
tests. In particular retain:

- `test/yorks_v1_material_request_detail_action_test.dart`
- `test/yorks_v1_material_request_test.dart`
- `test/yorks_v1_material_request_phase3_test.dart`
- `test/yorks_v1_material_request_realtime_test.dart`
- `test/yorks_v1_material_request_trust_golden_test.dart`
- `test/yorks_v1_material_workflow_trust_test.dart`
- `test/yorks_v1_arrangement_layout_test.dart`
- `test/yorks_v1_logistics_screen_test.dart`
- SQL suites for approval-first, procurement clarification, ranked search,
  Phase 2 collaboration, policy controls, action intelligence and stock flows.

Add tests for behavior introduced here: state preservation across layout
changes, scoped history/redaction, panel focus/Back, full-request action scope
under filtering, and stage-aware exposure of exceptions. Do not replace these
with tests that merely assert widget class names.

Run the complete applicable [repository acceptance gate](TEST_AND_ACCEPTANCE_PLAN.md):
dependency resolution, changed-file formatting, analyzer, Flutter tests,
CI-shaped web and Android builds, clean local test database reset/full DB suite,
and diff checks. Use a verified disposable/local test database for destructive
reset; never reset staging or production. Production Android claims require
the proper signing lane, not the CI ephemeral certificate.

Staging manual review should include an Engineering reviewer, a Procurement
operator and an Admin, with the Site Engineer and negative-persona scenarios
also covered. Ask the operator to find an item, explain owner/next action,
inspect the author/approver, approve or return, and recover from a staged error.
Target completion without coaching or data loss for every required task;
record confusion as a defect. Do not turn this exercise into employee scoring.

## 9. Release and rollback contract

- One identified source candidate, environment configuration and migration
  ledger. Rehearse new read-only history infrastructure in dedicated staging.
- Compare existing record IDs, versions, totals, documents and history around
  forward migration. The layout switch must not rewrite business records.
- Publish the candidate for user review after automated/local acceptance.
  Production is a later explicitly identified release, not implied by this plan.
- At release verify actual Flutter files, root and MR deep routes, comment
  links, PWA/service-worker assets, backend/flags and artifact hashes before and
  after promotion. Verify all intended existing flags remain present.
- Keep the previous known-good artifact/configuration. Roll back the frontend
  or presentation switch if the release fails; retain additive history data
  and helpers, and repair forward rather than deleting historical records.
- No known P0/P1, lost existing function, inaccessible critical control,
  permission leak, quantity mismatch or unresolved required visual defect ships.
  Every required criterion is passed or explicitly unresolved; “not run” is
  never recorded as passing.

## 10. Definition of completion and current evidence

Completion requires all mapped functionality preserved, all required test and
visual scenarios passed, named staging review, and release evidence if a
production rollout is performed. A static mockup, green build or successful
single request is insufficient. This establishes full coverage of the agreed
acceptance matrix; it is not a promise that no future software defect is possible.

Current planning-turn evidence:

- Working tree was clean before preparation; source commit recorded above.
- Read the current screen/panel/action implementations, audit boundaries,
  token definitions, current workflow contracts, constitution and test inventory.
- Ran `flutter test --no-pub test/yorks_v1_material_request_detail_action_test.dart test/yorks_v1_material_request_phase3_test.dart`: **9 tests passed**.
- These tests establish a narrow existing baseline only. Full Flutter/DB/build,
  browser/visual, new-history, staging and production checks are **not run for
  the redesign**, which has not been implemented.
- This change adds the plan and its two local concept references. No
  application, permission, database, deployment or business-data changes.

At implementation start, refresh source/dirty-worktree state, migration ledger,
baseline test evidence and relevant actor permissions. Record exact command
results, screenshots and unresolved issues per slice.
