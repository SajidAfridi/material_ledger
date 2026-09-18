# Audit Trail improvement plan

Date: 18 September 2026
Status: Approved for implementation on 18 September 2026. The core local
candidate is implemented; see [implementation evidence](AUDIT_TRAIL_IMPLEMENTATION_EVIDENCE.md)
for tested scope, measurements, remaining optional work, and release boundary.

## Objective

Keep the working Audit Trail and make it faster to answer: who changed what,
when, why, and what happened next? Prioritize clearer existing behavior and
easier investigation before adding more dashboard features.

This review uses the supplied desktop screenshot and current repository code.
It is not a live production, accessibility-conformance, or database performance
audit. Screenshot observations do not prove defects in the deployed build.

## Current strengths and verified boundaries

- The existing screen has a consistent Yorks shell, recognizable actor/role
  attribution, localized labels, search, date/module/quick filters, pagination,
  summary panels, and desktop/mobile presentations.
- Search already has a 320 ms debounce; the controller already ignores late
  responses from superseded requests. Preserve both.
- Reads follow widget -> Riverpod -> repository -> trusted RPC. The current
  workspace RPC requires an active exact Admin. Preserve this boundary.
- Existing tests cover repository mapping, offline rejection, response races,
  responsive layouts, and desktop/360px/390px golden images.
- Summary totals come from the unfiltered base, while the feed follows filters.
  Actors use 30 days, alerts use 7 days, and activity comparisons use consecutive
  7-day periods. The screenshot presents a growth value beside “All recorded
  time”; these meanings need explicit separation.
- The current export action copies only the displayed page to the clipboard as
  CSV. It is not an all-results file download. Quoting cells currently does not
  neutralize spreadsheet formula prefixes.
- Rows directly open only Material Request and Material Return destinations.
  There is no universal event inspection action in that row implementation.
- The controller retains prior results on errors. This helps transient recovery,
  but authorization-denied responses need a distinct purge path; a new filter
  must not make old results look like successfully loaded matching results.
- Module classification and several quick-filter categories use a fixed list
  and event-name matching. Coverage of newer modules/events needs reconciliation,
  rather than assuming every System entry is classified correctly.

## Phase 1 — Improve the current screen

### 1. Make scope and metric meaning explicit

Recommend Last 30 days as the initial investigation range, with Today, Last 7
days, Last 30 days, custom dates, and All recorded time readily available.
Retain the user's selected range for their session.

Make the primary event count follow the same authorized filters as the feed.
Place lifetime statistics in a clearly labeled secondary Overview section.
Show each metric's date range, definition, and comparison period. Suppress
percentage comparisons when a prior comparable period does not exist. Activity
growth should be neutral, not automatically green: more events are not evidence
of better operations.

Rename “Entities monitored” to “Records with activity” if its definition remains
distinct entity type/ID pairs. Explain attribution as actor/role evidence
completeness, not proof that every system event was captured or that the whole
system is tamper-proof. Empty evidence should say “No events to assess”, not
imply verified 100% coverage. Until there is a review workflow, describe audit
alerts as flagged events, not unresolved incidents.

### 2. Give the feed more space

Replace the six tall cards with a compact summary strip. Keep overview charts
and top-record categories collapsible or in an Overview tab. Move quick filters
beside the feed so they remain visible without competing with a right rail.

Use a sticky table header and comfortable/compact density options. Recommended
default columns: Time; Actor and role; Action; Record and project; Change/reason.
Move repetitive Module/Entity labels into optional columns or event details.
Show the actual MR/DO/return number where recorded; display project reference
separately. Do not manufacture missing historical document references.

In the screenshot, actor names and action chips are crowded, long project names
are truncated, and similar blue chips compete for attention. Add firm column
gaps/minimum widths, use quieter action text, and reserve status emphasis for
meaningful warning/critical categories with text/icon cues. Reveal full text in
details and keyboard-accessible tooltips. Use consistent sentence case.

### 3. Make filters understandable and recoverable

Group search, period, module, and quick filters in one toolbar. Display removable
active-filter chips, “Clear all”, and “Showing X–Y of Z matching events”. Keep
search visibly scoped to Audit Trail to distinguish it from global search.

Add explicit actor, project/company scope, event type, and severity filters in a
progressively disclosed filter panel. All options/results must be server-safe;
company-use events must not require a fictional project. Support exact reference
lookup without requiring knowledge of raw event codes.

Show timezone next to the range, with an exact UTC timestamp in details. Define
calendar ranges as start-inclusive/end-exclusive in the chosen timezone.

### 4. Improve feedback and accessibility

Show “Updated at …” from the server-generated timestamp. Distinguish initial
loading, updating, no events, no matches, offline, retryable failure, and access
denied. Retained data must show its last successful filter/time. Disable export
of ambiguously scoped stale results. Purge protected data on access revocation.

Preserve existing mobile cards; do not compress the desktop table into a phone.
Use a filter sheet, full-screen event details, 44px minimum targets, visible
keyboard focus, screen-reader labels, large-text support, RTL, and reduced
motion. Check the screenshot's lower-right zoom overlay against current shared
shell behavior; solve any overlap in the shared component, not with audit-only
positioning hacks.

**Acceptance:** filters and scope labels agree; no clipped primary controls at
1366px and 360px; keyboard users can search/filter/open/close and regain focus;
empty and stale states cannot be mistaken for current verified results.

## Phase 2 — Explain events and preserve investigation context

Open every event in a desktop side panel or mobile detail page. Include the
human-readable action, immutable actor/role at event time, exact timestamp,
record/project or company scope, reason, safe facts, and copyable event ID.
Provide a separate authorized “Open record” action. Closing details restores
the prior filters, scroll position, and focused row.

Present before/after values only when retained authoritative evidence supports
them. Otherwise state “Change details were not recorded for this event.” Never
derive historical facts from today's mutable record or display unrestricted
raw JSON. Keep commercial/private fields out of unauthorized projections.

Add a same-record timeline using stable entity identity, not matching display
references. Show request submission, the exact approval stage/revision,
arrangement, dispatch, receipt, and return when related evidence exists. The
two nearby approvals in the screenshot should become explainable by recorded
stage/version; do not assume they are duplicates or hide either event.

Preserve archived/deleted-source events. An unavailable destination should show
an explanation while retaining accessible audit evidence. Resolve navigation
through existing route guards and server capabilities.

**Acceptance:** an Admin can investigate a cancellation, understand the prior
recorded approval context, inspect its reason, open the record, and return to
the exact feed position. Revoked access reveals no cached detail facts.

## Phase 3 — Make export useful and classifications reliable

First rename the existing action “Copy current page” and disclose its row count.
Neutralize spreadsheet formula prefixes and test quotes, commas, line breaks,
Unicode, RTL, and formula-looking actor/reference/reason values.

Then add “Download filtered results” through the existing file-saving pattern.
The server must authorize the complete result set. Include applied filters,
timezone, generated/as-of time, event IDs, and exported count. Enforce size/time
bounds and use a stable snapshot/cursor across batches so concurrent arrivals
cannot cause missing or duplicated rows. Never silently export only page one.
For larger exports, design a bounded background job only when measured demand
justifies it. Keep export issuance auditable without recursive export loops.

Reconcile known event types into an explicit, tested presentation catalogue:
localized label, module, severity, safe fact labels, and navigation support.
Include newer Accounts, Workforce, company-use, and configuration events where
the authorized ledger supports them. Unknown events remain visible under an
honest fallback; do not quietly drop or classify them as harmless. Preserve raw
historical event identity. Severity policy needs business agreement: cancellation
alone is not proof of a security incident.

**Acceptance:** exported count matches the chosen scope, unsafe spreadsheet
inputs remain text, protected fields never leak, unknown events remain visible,
and the UI consistently describes recorded event meaning.

## Phase 4 — Performance and selective additions

Measure realistic 10k/100k/1m-event datasets in isolated test infrastructure.
Capture query plans, response bytes, render costs, and search/page p50/p95.
The current RPC builds a materialized base and calculates summaries with each
request; measure before choosing indexes, separating summary/feed reads, or
adding short-lived authorized summary caching. Retain the existing debounce
and race protection. Consider stable (timestamp, ID) cursor pagination before
large offsets become expensive or new arrivals shift result pages.

Optional additions after core acceptance:

1. Saved personal filter views, with safe filter-only links that reveal no data
   without authorization. Avoid embedding sensitive search text in shared URLs.
2. “New events available” refresh cue that preserves an active investigation,
   rather than automatically reordering rows while someone reads.
3. Review annotations for flagged events only if there is a real review owner
   and process. Store these separately with their own audit history; never mark
   an immutable source event edited, resolved, or deleted.

Defer AI summaries, anomaly scoring, more decorative charts, real-time streaming
for its own sake, and new permission roles. They are not prerequisites for a
more useful Audit Trail.

## Delivery and verification

Implement coherent slices in the order above, with authorization/cache clearing
and export safety prioritized alongside Phase 1. No historical audit rewrites,
privilege widening, destructive migrations, or automatic production release.
Use additive migrations and preserve existing RPC compatibility where needed.
Rollback disables new read/export UI and RPCs while retaining all audit history.

Primary files: [screen](../../lib/shared/screens/activity_log_screen.dart),
[controller](../../lib/shared/providers/yorks_v1_audit_provider.dart),
[repository](../../lib/shared/repositories/yorks_v1_audit_repository.dart),
[models](../../lib/shared/models/yorks_v1_audit_workspace.dart),
[strings](../../lib/shared/models/yorks_v1_audit_strings.dart),
[workspace RPC](../../supabase/migrations/20260813081945_audit_workspace_dashboard.sql),
[Flutter tests](../../test/yorks_v1_audit_workspace_test.dart), and
[database tests](../../supabase/tests/database/yorks_v1_audit_workspace.test.sql).

Extend existing tests for range boundaries/timezones, combined filters, exact
reference search, event-stage labels, stale responses, access revocation,
snapshot pagination, export safety, unknown events, and missing source records.
Verify positive Admin and negative exact-role/direct-access cases, especially
Project Engineer, Site Engineer, Procurement, Accountant, inactive and revoked
identities. Run applicable database, Flutter, web/APK, and visual gates before
release. Visual evidence must include desktop, tablet, 360px/390px, RTL, and
increased text size. Run staging investigations on named personas before release.

Measure usefulness with concrete tasks: locate one MR's cancellation and reason;
explain two approvals; find an actor's changes in a date range; export exactly
those matching events; resume the same investigation after opening a record.
Record baseline completion time and errors before setting improvement targets.

The original planning turn was documentation-only. Implementation and its
separate verification record are linked above; no production release is implied.
