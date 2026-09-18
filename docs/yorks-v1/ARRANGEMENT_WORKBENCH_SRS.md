# Arrangement Workbench — integration SRS

Date: 10 September 2026

Status: **implementation-ready proposal; not implemented or release-approved**

Scope: Procurement arrangement experience inside the existing Material Request (MR).

Companion: [implementation and acceptance plan](ARRANGEMENT_WORKBENCH_IMPLEMENTATION_PLAN.md).

## 1. Outcome and authority

Procurement must be able to understand the approved need, arrange every line,
handle shortages and clarifications, save unfinished work, return to the MR,
and resume without repeating work. Final arrangement save must preserve every
existing authorization, quantity, reservation, history and downstream rule.

This is an integration into Yorks, not a new procurement product. Apply the
[source hierarchy](SOURCE_OF_TRUTH.md), [product decisions](PRODUCT_DECISIONS.md),
[current approval-first guide](CURRENT_MATERIAL_REQUEST_USER_GUIDE.md),
[clarification contract](MATERIAL_REQUEST_PROCUREMENT_ITEM_CLARIFICATION.md),
[security contract](ARCHITECTURE_AND_SECURITY_CONTRACT.md), and
[state/RPC matrix](STATE_RPC_RLS_MATRIX.md). The later approved approval-first
and clarification decisions govern conflicting historical arrange-then-approve
wording. Do not silently convert legacy records.

The generated [desktop and mobile references](evidence/arrangement-workbench-design-20260910/README.md)
guide composition, not business behavior. Their illustrative counts, reservation
labels and omitted controls are corrected by this SRS.

### Goals

- No silent loss of acknowledged saved work, accidental workflow transition,
  duplicate reservation, or concealed shortage.
- One consistent editing model across desktop, tablet, mobile, modal and route.
- Clear separation of private progress, confirmed arrangement and actual stock.
- Fewer interruptions: contextual source/stock evidence, visible exceptions,
  focused correction, reliable Back and resumable work.
- Preserve all currently supported operations, languages and downstream records.

### Non-goals

No RFQ, quotation comparison, PO suite, supplier portal, multi-warehouse,
automatic substitute approval, split sourcing within one request line,
Procurement request creation, new approval authority, or new accounting logic.
No silent stock creation, reservation during editing, automatic final save on
reconnect, mandatory new date/supplier policy, or unrelated module redesign.
No production mutation is authorized by writing this plan.

## 2. Current implementation and preservation boundary

Source inspected at `be2e953` on 10 September 2026; these are repository
observations, not a live-production or device certification.

| Existing surface | Verified behavior / integration requirement |
|---|---|
| `yorks_v1_arrangement_screen.dart`, `_ArrangementEditorState` | Lines, raw quantity/cost/reason/supplier controllers and note are screen-owned. No arrangement-progress repository operation was found. Add durable editor state; do not describe the current editor as already recovery-safe. |
| `PopScope`, embedded `onClose`, MR `_openArrangement` | Editor pop is gated mainly by `_busy`; desktop opens a dismissible dialog and compact layouts push a route. Centralize dirty/uncertain exit handling across every entry and dismissal path. |
| `_MobileArrangementFlow._next` | Changes line/review position, not persistence. Replace misleading save wording unless an actual checkpoint is acknowledged. |
| `_save`, `_validateLines` | Full/Partial/unavailable, quantity, source, reason, cost, external policy and aggregate warehouse validation exist. Preserve and centralize them; keep server checks authoritative. |
| `_inventoryItemsForRequest` | Adds eligible retained request reservations back for replacement validation. Preserve exact effective availability without double-counting or treating consumed/released quantities as reusable. |
| `didUpdateWidget` / arrangement provider | Same-ID refresh can update request version separately from line state; provider intentionally avoids Realtime-driven editor destruction. Keep immutable edit-base versions and explicitly reconcile newer projections. |
| Workflow command controller / critical-command key store | Durable per-actor command keys and payload fingerprints already exist. Reuse them; do not create a competing idempotency system. Extend uncertainty recovery where needed. |
| MR private draft controller | Provides separate accepted-draft and recovery concepts with serialized persistence. Reuse the pattern, not its Engineering-only MR-draft RPC or access policy. |
| Clarify item and Create inventory item | Real protected commands with distinct effects. Preserve them, including cancellation and ambiguous-result recovery inside nested editors. |
| MR record, discussion, history, documents, logistics | Remain the source of truth. The workbench must not replace or duplicate these modules. |

### Mandatory functional parity map

| Function | Destination in the new experience | Non-regression requirement |
|---|---|---|
| Approved need, project/scope, schedule, delivery notes | Compact header; requested-item column/card; Request Information | Exact original evidence, current effective identity and real scope remain accessible. |
| Full / Partial / Cannot Provide Now | Per-line decision control | Explicit three-way decision; partial/unavailable reasons; no dropped lines. |
| Warehouse matching | Source cell / focused source section | Ranked search, explicit selection, item code/unit/availability, retained reservations and real create-inventory action. |
| External supplier | Conditional source section | Optional supplier name, readiness flag, optional expected date/reference; enforce only published policy. |
| Unit cost | Capability-controlled column/field | AED, decimal validation, absent unauthorized keys/values, preserve-versus-clear semantics. |
| Clarification | Visible line action before first final save | Original/effective comparison, latest-revision Engineering review, operational lock and audit. |
| Procurement note and reasons | Note below items; inline reason per exception | Note never substitutes for a required line reason; incomplete text is recoverable. |
| Existing final save | Review summary followed by Save arrangement | Same trusted transactional effects, versions and durable command identity. |
| Legacy review/return/replacement | Existing state-appropriate review/history | No conversion, reservation release or synthetic approval. |
| Request context and communication | Request Information and Back to request | Information panel does not reset editor; discussion stays visible full-width at the MR record end, not hidden in this editor or replaced with Team Chat. |
| Dispatch / DO / receipt / return / close | Existing MR workflow after confirmed save | Approved caps, immutable documents, good/missing/damaged reconciliation and return eligibility unchanged. |

## 3. Three different kinds of save

All requirements below are P0 unless marked otherwise. “Must” is acceptance
language for the proposed implementation, not a claim that it exists today.

| Action/state | Persistence | Changes workflow/reservations? | User-facing meaning |
|---|---|---|---|
| Edit + device recovery | Allowlisted non-commercial recovery on this device | No | “Saved on this device”; not a shared arrangement and not necessarily the latest keystroke until acknowledged. |
| Save progress | Owner-private server checkpoint, including authorized cost input | No | “Progress saved to your account · [server time]”. May contain incomplete/invalid business input. |
| Save arrangement | Existing final trusted command | Yes, existing atomic replacement/reservation and state rules | “Arrangement saved” only after server confirmation; positive lines become dispatch-ready in the current lane. |

**AW-01 — Private progress.** One active progress root per backend/environment,
actor, request and working arrangement. It belongs to that actor, not to the
Coordinator or the Procurement role collectively. It resumes across that
actor's devices. Other Procurement actors may still use the existing authorized
working arrangement; they neither see nor overwrite someone else's private
checkpoint. This adds no record lock, team draft sharing or takeover authority.

**AW-02 — Incomplete is saveable.** Save progress accepts missing source,
blank/partial decimal text, incomplete reason, unreviewed lines and incomplete
readiness evidence. It validates shape, bounds, identity and authorization, not
final business completeness. It never calls `v1_save_arrangement` or
`v1_begin_arrangement` as a fallback. Every entered permitted field survives an
acknowledged account checkpoint exactly, including meaningful intermediate text.

**AW-03 — Honest durability.** Persist non-commercial local recovery after a
short serialized debounce (initial target 500 ms), and flush it on controlled
exit, field navigation and app pause when the platform permits. Show Saving,
Saved on device, Account saved, Unsaved changes, or Save failed distinctly.
An older write response cannot mark newer edits saved. Local storage failure
does not disable the independent account-save path.

**AW-04 — Deliberate account checkpoints.** Save progress and Save progress &
return explicitly save the complete snapshot to the account; no per-keystroke
remote autosave is required in this slice. Track the last explicitly accepted
snapshot separately from crash recovery. Discard changes restores that boundary,
not the latest autosaved keystroke. For a newly opened editor, the boundary is
the restored account checkpoint or original server working snapshot.

**AW-05 — Privacy boundary.** Do not put costs, commercial final-command payloads
or unrestricted projections in SharedPreferences, generic caches, logs or
analytics. Local recovery excludes commercial fields; authorized cost edits
remain in memory until an account checkpoint succeeds. Display “Cost changes
are not saved to your account yet” when applicable. Offline departure must
explicitly warn that unsaved costs cannot be recovered after closing/reloading.
Do not quietly downgrade an all-fields save promise to non-commercial recovery.

**AW-06 — Restore safely.** On opening, authorize the live workspace first,
then fetch the actor's checkpoint and compare schema, base versions and local
generation. Restore matching confirmed progress; offer a newer device recovery
copy without replacing it during a late network response. Divergent device and
account copies require a comparison/choice. Client timestamps alone never select
a winner. Unsupported/corrupt recovery is retained/quarantined and reported,
not silently treated as an empty arrangement.

**AW-07 — Expiry and scope.** Namespace recovery and command references by
environment, account, request and arrangement. Never restore production data
into staging, another user, request or newly created arrangement. Logout and
revocation purge protected in-memory/local content under existing session policy;
account checkpoints remain private and inaccessible without current authority.
Explicit logout may offer Save progress first, but security expiry/revocation
must not wait for a save or retain access to data. Browser-close/crash/device
storage removal can lose unacknowledged changes; never promise otherwise.

## 4. End-to-end flow and navigation

```text
MR approved for Procurement
  -> explicit Arrange / existing begin command, if needed
  -> restore authorized working arrangement + private progress
  -> edit sources, quantities, exceptions and note
       -> Save progress -> continue, or return to the same MR
       -> Clarify item -> Engineering review -> same preserved workbench
       -> Review arrangement -> resolve blocking issues
  -> explicit Save arrangement -> reconcile server result
  -> MR refreshed with confirmed state, owner, next action and history
  -> existing dispatch -> DO -> receipt -> return/close rules
```

**AW-08 — Entry.** Clicking Arrange may execute the existing begin command once
when `canBegin` is true and no working arrangement exists. Page load, deep link,
preview, Back and restore do not create another version. Repeated taps/tabs and
ambiguous begin results use the existing command identity and server uniqueness.
Opening an existing working arrangement does not count as beginning another.

**AW-09 — Return to record.** The explicit Back to request action returns to the
same MR ID, restoring the calling record's scroll/section and register filters
where possible. It does not mark a notification read again or switch projects.
A direct-linked editor with no valid origin falls back to that MR detail, then
the authorized register if the record is no longer readable. Ordinary system
Back follows the existing previous-Yorks-place navigation contract.

**AW-10 — One exit guard.** Header Back, close X, Escape, dialog barrier,
Android/system/gesture Back, browser navigation, sidebar navigation and route
replacement all delegate to the same controller decision. Use a route-backed,
bounded desktop overlay or guarded existing modal; do not permit barrier/X to
bypass the guard. Nested panel Back closes that panel first. Do not show two
prompts because both a widget and router independently intercept departure.

| Exit condition | Required experience |
|---|---|
| No edits since accepted checkpoint | Leave immediately; confirmed progress remains recoverable. |
| Dirty + online | “Save progress before leaving?” with Save progress & return, Discard changes, and Keep editing. Save does not require final validation. |
| Dirty + offline | Keep editing or explicitly Keep device copy & return; show account-save unavailability and any unsaved-cost limitation. Discard remains deliberate. |
| Progress save pending | Keep existing screen/input, disable duplicate save; wait for bounded response. If it fails, remain with Retry / Keep editing / permitted device-only exit. |
| Final save in flight or uncertain | Do not discard, issue a different final payload or show failure-as-rollback. Use the uncertainty behavior in AW-25; Back may return to the record after the bounded timeout with “Checking arrangement save” and a durable recovery link. |
| Request cancelled or authority removed | Disable mutations immediately, explain what changed and route to permitted content. Never show an optimistic saved result; privacy takes precedence over recovery. |

**AW-11 — Discard scope.** “Discard changes” discards only edits since the
accepted checkpoint. “Discard saved progress”, a separate confirmed secondary
action, retires the actor's checkpoint and recovery copy. Neither cancels the
MR, undoes a saved clarification, deletes an inventory item, releases a
reservation, or rolls back a confirmed final arrangement. A checkpoint from a
prior visit is not silently deleted by the close button.

**AW-12 — Nested tasks.** Request Information is read-only and preserves all
input/focus. Inventory creation and clarification use their own dirty and
pending-command guards. Cancelling a nested task returns to the original line
and caret; completing one updates only its authoritative result. Preserve the
outer progress before launching a workflow-changing clarification. Do not
require saving progress merely to inspect Request Information.

**AW-13 — MR continuity.** After Save progress & return, the owner sees a private
“Continue arrangement” cue with account/device save state. Shared state remains
Procurement Arrangement, never Ready for Delivery. After final success, refresh
MR detail, list, arrangement, inventory and affected logistics projections through
existing invalidation paths. Restore focus to the relevant action/status. A
refresh failure after confirmed commit shows “Saved; latest details could not
load” with Retry; it does not invite a second save. Final save never auto-dispatches.

## 5. Line editing, stock and business validation

**AW-14 — Deliberate review without busywork.** Retain existing Full/Warehouse
defaults as suggestions, not confirmed stock. Distinguish reviewed, needs input
and not yet reviewed as presentation metadata, not new workflow decisions.
Review permits an explicit “Confirm unchanged lines” with affected count;
do not force an extra checkbox for every valid unchanged line. Final submission
requires the user to review the complete scope, including filtered-out rows.

**AW-15 — Quantity truth.** Full equals requested; Partial is positive and below
requested with a nonblank line reason; Cannot Provide Now is zero with a
nonblank reason. Use the existing decimal parser and server numeric precision,
no binary-double comparison, scientific notation, NaN, silent rounding or
automatic unit conversion. Invalid text stays visible for correction. Do not
sum Nos, metres and kilograms into one total. Unknown source quantity is not zero.

**AW-16 — Decision/source changes.** Full may deliberately fill requested
quantity; Partial retains compatible entered quantity or asks for a smaller one;
unavailable sets effective quantity to zero and reveals the required reason.
Keep a per-line in-session recovery buffer for prior inputs when toggling, but
never serialize hidden stale supplier/warehouse/cost fields as active values.
Switching Warehouse/External clears the incompatible effective source; returning
may offer the prior selection after revalidation. Never silently shrink a Full
line to available stock, auto-change a decision or copy readiness between items.

**AW-17 — Warehouse context.** Show item identity, exact unit, Available now,
planned quantity for this request and the as-of freshness state. Existing
committed reservations are separate from “Will reserve on save”. Matching is
not availability confirmation: a green selection icon cannot mean enough stock.
Inventory search is cancellable/bounded and ignores late results from old queries.
Unit mismatch, deleted/inactive item or denied inventory read blocks that source
with a specific correction; it does not manufacture a replacement item.

**AW-18 — Aggregate availability.** Validate the sum across all request lines
using the same inventory item, not just visible/filtered rows. Obtain effective
replaceable quantity under the existing server rules: free stock plus only this
request's eligible retained unconsumed reservations, counted once. Never add
consumed, released or other-request reservations. Server locks/rechecks at final
commit. On shortage, show affected lines, planned and newly available quantities;
keep all edits and offer Change quantity/decision, Change source or Refresh stock.
Failed final save preserves old reservations atomically.

**AW-19 — External supply.** Keep supplier name optional under current policy.
Always expose Source ready / firmly committed, optional expected date and
reference for positive external lines. Label readiness Recommended or Required
from the published configuration. A new policy/version invalidates prior review
and is checked at commit. A late date is explanatory information unless an
approved rule says it blocks; do not invent an SLA or reject historical evidence.
Date input follows existing calendar/date-only semantics without timezone drift.

**AW-20 — Commercial fields.** Resolve read/manage authority separately; never
infer it from Procurement text or selected source. Preserve absence, unchanged,
explicit clear and decimal value distinctly. Unauthorized responses and recovery
payloads contain no cost keys/values; omission must not clear protected existing
costs. If the current final RPC cannot express this safely, add a tested,
backward-compatible protected patch contract before enabling this UI. Capability
loss removes cost state immediately and requires re-review; it must not erase
authorized server-held values as a side effect of non-commercial saving.

**AW-21 — Validation hierarchy.** Field-level feedback on blur/decision change;
one compact summary at Review/final attempt with exact row and field focus.
Incomplete drafts remain saveable. Errors clear only when corrected/revalidated,
not merely on any unrelated keystroke. Hidden/filter-excluded errors remain
counted; selecting one reveals the row, opens its mobile editor and focuses the
field. Distinguish invalid input, stale data, denied access and service failure.

## 6. Clarification, review and final commit

**AW-22 — Identity clarification.** Before first final save, preserve the current
progress checkpoint, then use the existing protected name/model command. Explain
before confirmation that it sends the correction for Engineering review and
locks operational editing. Quantity, unit, brand, original identity/provenance,
commercials and arrangement decisions are not editable in this dialog.
Do not silently commit arrangement work with the clarification.

While clarification awaits approval or is returned, operational fields/final
save remain locked according to server flags. Further allowed identity
corrections use the same existing command and advance the exact review revision.
Progress is retained; no operational edits can be smuggled through a progress RPC
while locked. A read/unchanged checkpoint acknowledgement may succeed, but a
changed operational payload must be rejected. Approval resumes the same working
arrangement; show the effective changes, revalidate matching/units/stock and
invalidate reviewed flags for affected items before rebasing. Engineering return
goes to Procurement correction, not to an invented second MR. A saved
all-unavailable arrangement also closes identity clarification permanently.

**AW-23 — Review.** Desktop uses a compact inline review surface; mobile has a
dedicated Review step. Show total line count, Full/Partial/unavailable counts,
unreviewed/blocking count, source summary, required reasons, external readiness,
note and authorized costs. Display counts from the complete set. One primary
Save arrangement action explains its real effect. Review is editable and does
not reserve anything. Returning to a line preserves every other line and scroll.

**AW-24 — Final effects.** Keep `v1_save_arrangement` and existing lane selection
as authority. The final command uses exact request/arrangement/clarification
versions, complete line set and immutable intent. It rechecks actor, scope,
configuration, quantities and stock, replaces reservations atomically and emits
the existing audit/notification effects once. Progress save reserves nothing;
final save reserves warehouse quantity; warehouse on-hand changes at dispatch,
not arrangement. External arrangements do not manufacture warehouse stock.

All-unavailable final save remains arranging/editable with zero approved
quantity, explicit reasons and no dispatch call-to-action. Cancellation/replacement
remain authorized Engineering/Admin actions under the existing policy. Legacy
post-arrangement approval records retain their actual review/return lane and
reservation semantics. Already dispatched/closed/cancelled or superseded records
never become editable merely because private progress exists.

**AW-25 — Uncertain results.** Reuse the durable critical-command key store and
controller. Persist the frozen intent as a protected server checkpoint before
final invocation, and retain only opaque IDs/fingerprint/key locally. If checkpoint
creation fails, do not invoke final save. The extra checkpoint is not a new
business transition and must not change expected request versions.

Prepare the attempt by binding the existing controller-acquired command key to
that immutable checkpoint and canonical final-payload digest on the server.
Preparation and outcome lookup are separate from the final operational command;
preparation is not evidence that the final command ran. The same actor can recover
the exact authorized intent/key on another device. Do not overwrite a prepared
attempt with a newer edited checkpoint. A definitive validation/conflict rejection
may unlock correction after refetch; a transport error or lookup miss may not.

On timeout/transport failure, show “We could not confirm whether this saved”
and offer Check status, not a generic invitation to submit changed work. An
authorized command-result lookup or same-key/same-payload replay resolves the
original attempt. A lookup miss alone does not prove an in-flight command failed;
same-key replay/server locking resolves that race. Freeze operational editing
until that intent is confirmed committed or definitively rejected. Back may leave
the checking state after the bounded request timeout; recovery on re-entry,
reload or another device consults the retained attempt. Never auto-submit a new
command after reconnect. Refresh/later workflow state must not obscure the
original committed receipt. Replayed responses must be reauthorized/redacted.

**AW-26 — Conflicts.** Track edit-base versions independently from latest display
versions. On any newer server revision, retain local inputs and show a compare
view. Never adopt a new expected version while keeping stale input implicitly.
Unchanged line IDs/fields may be carried into an explicit rebase; changed identity,
quantity, unit, source, policy or commercial authority requires review. Removed
lines remain visible as non-submittable conflict evidence while authorized.
No last-write-wins, auto-overwrite or privileged “force save”. Request finalization,
cancel or newer arrangement blocks reuse of the old draft. Offer View current
request and deliberate retirement of obsolete progress, not lost edits disguised
as a successful merge.

## 7. Layout, accessibility and copy

**AW-27 — Yorks visual continuity.** Use existing AppColors/AppSpacing/
AppTypography, bundled NexusSans, shared controls, thin borders, light surfaces,
navy primary action and restrained semantic colors. Keep the office shell and
stage 3 of 7 cue; do not renumber the business lifecycle. Avoid giant summary
cards or a permanently open inspector that compresses the actual work.

**AW-28 — Desktop.** Bounded wide workbench; compact request/context header,
save-state cue and Back to request; secondary Request Information; compact
counts/search/filter bar; sticky table header and requested-item column; inline
source/quantity/cost controls; expanded exception reason beneath its row; note
below items; sticky Review/Save area. Preserve long item context through wrap or
accessible expansion. Filter changes never dispose input. Large lists instantiate
bounded row editors. Keyboard Tab/Shift+Tab, arrows and Enter/Shift+Enter follow
existing grid conventions without stealing text-caret keys or submitting a form
accidentally. No add/delete request-line affordance is introduced in arrangement.

**AW-29 — Tablet/mobile.** Follow the existing shared breakpoint/layout rules;
choose layout by available content width, not device name. A narrow tablet may
use cards plus a focused editor, never a compressed spreadsheet. Below the
compact boundary: item cards -> one line editor -> review, with safe-area sticky
actions. Show requested identity/quantity before decision/source/quantity;
conditional cost/readiness/reason controls remain reachable. Previous/Next and
Back to items retain raw edits. Label navigation “Continue”/“Next item”; show
device/account saving independently. Save progress remains available from every
step. Rotation/resizing must keep one controller, item selection and caret.

**AW-30 — Inclusive operation.** Minimum 44x44 targets, visible keyboard focus,
correct screen-reader labels/error associations and non-color status text.
Restore focus after dialogs; announce save state politely without per-keystroke
noise. Test 200% text scaling, long/RTL content, reduced motion, browser zoom,
software keyboard and platform insets. Every new visible/accessibility string
uses the configured language system; preserve English and all supported secondary
languages, with direction-aware panels and no hard-coded UI strings.

### Key copy contract (localized during implementation)

| Context | Copy intent |
|---|---|
| Private account save | “Progress saved to your account. Stock has not been reserved.” |
| Device-only state | “Saved on this device. Save progress to continue on another device.” |
| Warehouse planned quantity | “Will reserve on arrangement save”; never “Reserved” before confirmation. |
| Final action explanation | “Save the arrangement and reserve warehouse quantities for dispatch.” Adapt for legacy/all-unavailable lane. |
| Stock changed | “Availability changed. Review these items; your entries are still here.” |
| Clarification pending | “Waiting for Engineering to approve the latest item correction. Your arrangement progress is preserved.” |
| Offline | “You can keep editing permitted draft fields. Connect to save progress to your account or save the final arrangement.” |
| Confirmed save, refresh failed | “Arrangement saved. We could not load the latest request details.” |

## 8. Proposed architecture and data contract

**AW-31 — One controller.** Introduce a typed arrangement-editor Riverpod
controller and local-recovery service. UI widgets own only focus/text adapter
lifetime, not authoritative draft/command state. The controller owns snapshots,
raw input, reviewed fields, validation, local/remote generations, exit decision,
conflicts and pending intent. Use existing repositories for all operational
commands; widgets never call Supabase.

Proposed names below are implementation targets, **not existing APIs**:

| Boundary | Contract |
|---|---|
| `YorksV1ArrangementProgress` | Schema version, request/working arrangement IDs, base request/arrangement/clarification versions, stable line IDs, raw permitted inputs, reviewed metadata, note, progress revision and accepted checkpoint. No caller-authored workflow state or reservation. |
| `YorksV1ArrangementEditorController` | load/restore, edit, local flush, saveProgress, resolveExit, validate/review, reconcile/rebase, clarify handoff, final save and resolveAttempt. |
| `v1_get_my_arrangement_progress` | Owner-only, current-authority read; returns checkpoint metadata and role-safe data or typed absent/stale/denied result. |
| `v1_save_arrangement_progress` | Owner/private expected-revision save, request-root/state checks, typed bounded payload, request-hash idempotency; returns exact acknowledged generation, revision and server time. |
| `v1_discard_my_arrangement_progress` | Owner-only expected-revision, idempotent soft-retirement; no business reversal. |
| `v1_prepare_arrangement_attempt` | Binds the owner's immutable checkpoint revision, original versions, canonical final-payload digest and existing command key; no reservation or workflow effect. Repeated preparation returns the same binding. |
| `v1_get_my_arrangement_attempt` | Narrow authorized outcome/receipt lookup for the actor's exact retained final intent/key; no general idempotency-table access. |

**AW-32 — Storage.** Add separate protected progress roots/revisions/line values
and a protected commercial companion keyed to the exact revision. A checkpoint
revision is immutable once referenced by a final intent. Keep raw incomplete
numeric strings separate from typed final quantities. Derive owner/project on
the server; validate line membership, exact key allowlists, schema version,
length/line/payload limits against current MR limits, and reject unexpected keys.
Do not repurpose Engineering private MR draft tables or generic JSON sync.
Indexes cover owner/request/working-arrangement lookup and revision uniqueness.

Store the attempt binding separately from the current editable checkpoint
pointer. Derive committed outcome from the existing trusted command receipt,
not a client-set success flag. A prepared-but-unresolved binding cannot be
reported as failed merely because no committed receipt is visible yet. Preserve
existing final RPC clients/signatures or add a compatible versioned wrapper;
all paths must retain the same request locks, version checks and stock authority.

Reads may show an obsolete checkpoint only while the owner retains request read
and arrange authority, as non-editable comparison evidence. Writes additionally
require an editable current working arrangement. Permission denial is distinct
from absent progress. No Admin cross-user peek, Engineering read, public RPC
grant, direct authenticated table CRUD or client-authored audit. Cost reads/writes
recheck current commercial capabilities independently, including on retries.

**AW-33 — Concurrency and lifecycle.** Progress saves serialize by root and
expected progress revision; concurrent actors have private roots, concurrent
devices for one actor conflict. Follow existing deterministic request-root lock
order so checkpoint/final/cancel/clarification races cannot deadlock or revive
stale work. The final attempt references an immutable checkpoint/digest, key and
original versions; completion marks the submitting revision consumed only after
confirmed commit. Other drafts become stale by version comparison, not deletion.
All-unavailable final success consumes that intent but does not prevent a new
checkpoint for the still-editable working record. Discard/supersede are retained
metadata events; no automatic hard-deletion/retention purge is introduced here.

**AW-34 — Audit, analytics and notifications.** Explicit progress save/discard
has minimal protected server attribution, never a workflow handoff or a public
discussion event. No keystroke audit. Preserve existing final/clarification
audit and notification deduplication. Extend the central privacy-safe PostHog
schema only if needed for progress-save outcome, resume, validation category,
conflict and uncertain-result resolution. Exclude item/supplier names, notes,
costs, raw payloads and identifiers outside the approved analytics allowlist;
respect opt-out/masking and never make analytics success a workflow dependency.

## 9. Acceptance, measurement and delivery boundary

All AW-01–AW-34 are release requirements. The companion plan assigns each to
bounded implementation slices and test cases. Do not claim literal perfection
or guarantee recovery of unacknowledged input after an OS kill. The measurable
standard is zero silent loss in tested controlled exits/recovery, zero duplicate
critical effects, zero unauthorized disclosure, and parity for every existing
function listed above.

Measure baseline versus candidate on identical small, mixed-source and large
request fixtures: task completion, navigation/restore success, validation
correction steps, input latency and final-save latency. Target no regression in
render/input performance and publish the additional checkpoint round trip cost.
Usability improvements require observed Procurement and Engineering walkthroughs,
not only green unit tests or generated mockups.

P1, after P0 acceptance: optional safe bulk draft helpers with affected-count
preview/undo and remote autosave, if evidence demonstrates value. P2/separately
approved: shared Procurement drafts/takeover, split sources and supplier suite.
Do not let these expand the initial cutover.

Selected planning defaults: private per-actor account progress; explicit remote
checkpoints; non-commercial local recovery; single-source lines; unchanged
workflow authority. These are proposed additions for this feature, not previously
approved production facts. A different privacy/ownership/business requirement
requires an explicit SRS revision, not an implementation-time guess.
