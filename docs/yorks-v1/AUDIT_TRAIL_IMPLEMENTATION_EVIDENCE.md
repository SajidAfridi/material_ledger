# Audit Trail investigation implementation

Date: 18 September 2026. Local candidate; no production migration or deployment.

## Delivered scope

- Last-30-calendar-days initial range; Today/7/30/custom/all-time choices, with
  exclusive upper date bounds, device timezone labels and UTC event details.
- Filtered summary counts, compact mobile summary, quieter action styling,
  wider feed, bounded scrolling with a fixed desktop table header, density
  choice, and a collapsed secondary overview. Primary labels describe records
  with activity, flagged events and attribution coverage rather than health.
- Actor/project/event/classification/scope filters, mobile quick-filter access,
  clear controls, server-generated freshness, and the last successful filter
  scope when a refresh fails. Copy/download are disabled for stale/pending data.
- Every event opens details with actor, recorded role, exact time, safe facts,
  before-state evidence where retained, reason, event ID, and same-record
  history. Existing MR/return navigation uses a pushed route so Back preserves
  the investigation. Unsupported entity destinations keep inspectable evidence.
- A V2 read RPC retains the old V1 RPC for compatibility. Summary and feed
  filters agree. Date/entity predicates are applied before expensive projection.
  Normal next/previous navigation uses retained timestamp/ID cursors, with a
  server as-of timestamp. The old 100,000-offset clamp cannot repeat deep pages.
- A private 106-entry presentation catalogue retains existing severity rules
  for recognized emitted names. Unknown event types remain visible and marked
  unclassified. New module mappings include Accounts/Workforce/Configuration and
  company entity types already present in the central ledger.
- Current-page CSV copy is explicitly labelled and reports its row count in
  the tooltip. Filtered CSV download includes IDs, UTC timestamps, filter/as-of
  metadata and row count. Spreadsheet formula prefixes are neutralized.
- Filtered exports are bounded to 5,000 events. A single server statement
  creates the complete result; oversize requests fail with a narrowing prompt.
  Per-actor UUID receipts, advisory locking and immutable stored payloads make
  same-key retry return identical evidence with one export audit event. A
  changed filter cannot reuse that key. Receipt rows have RLS, no client grants,
  and an append-only trigger. The client rejects incomplete export responses.
- Auth identity/role changes invalidate audit state. Denied reads purge retained
  data. Details and filter modals cannot reveal prior evidence after their
  owning audit controller loses access or is replaced.

## Coverage and deliberate boundaries

This remains an active exact-Admin central-audit workspace. It does not grant
new capabilities or edit/delete audit history. No commercial before/after JSON
is exposed: only the documented non-commercial fact allowlist is returned.

Company requests maintain a separate protected event relation and participant
read policy. This change does not union that private history into the central
ledger or grant Admin participant access. The Company scope filter applies to
company entity events actually present in the central ledger. Likewise, module
classification is not a claim that every separate module-specific ledger is
aggregated here. Extending that coverage needs its own authority-preserving
integration and positive/negative tests.

History groups by exact entity type/ID; it does not infer cross-document links
from matching display references. Missing historical facts remain missing;
current record values are not reconstructed as earlier evidence. The cursor
prevents page-boundary repeats, while a genuinely late-committing/backdated
event can still require Refresh to enter the active investigation. Export
receipts, unlike the live feed, are immutable snapshots.

Saved personal views, automatic new-event cues and review annotations were
optional follow-ons in the plan and remain deferred. No new alert-resolution
workflow or severity policy is invented. Source record availability continues
to be checked by its existing route/repository guards.

## Scale measurements

The reproducible [local benchmark](../../tool/audit_workspace_benchmark.sql)
uses a disposable seeded database and rolls all fixtures back. Bulk setup
temporarily disables user capture triggers and supplies explicit synthetic
attribution, then enables them before measurement. This measures reads, not
production write-trigger throughput. An initial attempt with per-row capture
enabled was cancelled during million-row setup and rolled back; it is not a
completed million-row write benchmark.

Five local samples per scenario, 730-day event distribution:

| Events | Scenario | p50 ms | p95 ms | Response bytes |
|---:|---|---:|---:|---:|
| 10,000 | 30-day feed | 4.81 | 10.36 | 9,078 |
| 10,000 | Same-record history | 0.94 | 2.65 | 1,875 |
| 100,000 | 30-day feed | 38.27 | 38.92 | 9,092 |
| 100,000 | Same-record history | 1.18 | 2.10 | 7,739 |
| 1,000,000 | 30-day feed | 444.34 | 465.34 | 9,104 |
| 1,000,000 | Same-record history | 2.19 | 2.87 | 9,046 |

The same-record lookup used `v1_audit_entity_time_idx`: index-only scan, 17 shared
buffer hits, 0.037 ms execution for 12 IDs. These are local warm-read timings
before the final cursor parameter addition, not production latency/SLA claims.
The measured scenarios use the same date/entity predicates in the final RPC.
All-time million-row aggregation and browser input-to-paint p95 are not measured.

## Verification and release

Focused Flutter coverage includes formula-safe CSV, rejected partial exports,
late response suppression, denied-cache purge, stale filter/export behavior,
event detail/history, mobile/tablet layouts, Arabic/Urdu RTL and enlarged text.
Database coverage includes exact-role denials, safe before-state projection,
calendar boundaries, combined-filter summary parity, identity history, cursors,
export retry/conflict, size limits and absence of partial failed-export rows.

Visual evidence: [desktop](../../test/goldens/r35/audit_workspace_desktop.png),
[360px](../../test/goldens/r35/audit_workspace_mobile_360.png),
[mobile details](../../test/goldens/r35/audit_details_360.png),
[tablet filters](../../test/goldens/r35/audit_filters_tablet.png),
[Arabic large text](../../test/goldens/r35/audit_workspace_ar_large.png), and
[Urdu large text](../../test/goldens/r35/audit_workspace_ur_large.png).

Observed verification:

- `flutter pub get`, formatting and `flutter analyze`: passed.
- Full `flutter test`: 1,784 passed. The final narrow audit suite passed 17
  tests after the modal/accessibility/initial-date lifecycle refinements.
- `supabase db reset --local`: passed with seed and the complete migration ledger.
- Full `supabase test db --local`: 101 files / 2,916 assertions passed.
- Local security advisors at warning/error level: no issues found.
- Production-shaped web and APK builds passed; final artifact measurements are
  recorded below. APK signing is ephemeral CI signing, not production signing.

Final web artifact: `main.dart.js` 10,181,949 bytes; gzip 2,747,960 bytes;
`index.html` 11,024 bytes. Final Android artifact: release APK 105.7 MB.
The isolated build's nine audit/tool source files were byte-compared with the
working candidate and matched. Final `git diff --check` and all local links in
the plan/evidence documents passed.

Builds use an isolated
checkout containing only this audit slice; unrelated worktree edits are retained.
The raw JavaScript cap increases by 50 kB to 10,200,000 for the new investigation
flow. The gzip ceiling remains 2,900,000 bytes; no runtime dependency was added.

Rollout order: apply the additive migration to dedicated staging; build the
matching app; run named-Admin and denied-persona investigations and actual file
downloads; then obtain release acceptance. No remote migration, deployment,
production signing or named-persona staging acceptance is claimed here.
Rollback restores the prior app and revokes the new RPCs while retaining the
central audit ledger and immutable export receipts. The V1 read RPC is untouched.
