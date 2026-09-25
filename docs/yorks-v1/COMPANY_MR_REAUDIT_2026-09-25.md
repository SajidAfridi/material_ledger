# Company Material Requests — integration re-audit

Date: 25 September 2026. Status: local candidate; full release gate remains red.
The Company feature remains off by default. No production migration or deployment
is implied by local evidence.

## User-visible outcome

- The main Material Requests register combines readable Project and Company
  requests with real type labels, native states, stable combined pagination and
  server search. Project folders retain real Project records only. Company
  requests never acquire artificial Project membership or commercial fields.
- Company creation reuses the Project MR material editor and catalogue-search
  interaction, including keyboard selection and focused phone editing. It retains
  Company category/unit, beneficiary, receiver and independent approval rules.
- A Site Engineer can select one eligible independent Project Engineer or senior
  approver from the configured Company category/unit authorization. An active
  Yorks login is required for the beneficiary. Self-approval remains forbidden.
- Private draft creation and explicit submission remain separate. Submitted
  requests support protected editing and cancellation before fulfilment locks.
  Procurement corrections release reservations and require fresh independent
  approval. Editing cannot erase dispatched quantities or their history.
- Arrangement, dispatch, receipt, beneficiary handover, returns, withdrawal and
  closure retain server-confirmed, versioned and idempotent commands. Arrangement
  and receipt commit a reviewed basket; partial quantities and reasons remain
  explicit.
- Notifications link to Company records, Realtime triggers authorized refresh,
  workspace search finds Company records, and central Audit records trusted
  actor/role/time with before/after revision evidence. The request detail exposes
  immutable issue evidence and its activity history on demand.

## Important repairs

The re-audit corrected a Save/Cancel validation inversion in the supply dialog,
phone dropdown overflow, insufficient muted-text contrast, stale catalogue
responses, uncertain mutation results incorrectly treated as confirmed failures,
missing audit and notification handoffs, and route/sidebar gating that blocked
Company-only participants from the shared MR home. Dialog controllers now outlive
route teardown, preventing disposal errors after editing or cancellation.

Search data and UI load on intent to preserve the existing startup budget.
Project capability denies still protect Project-scoped routes; the combined
register independently filters both domains on the server.

## Analytics evidence

The read-only [PostHog query record](../analytics/COMPANY_MR_REAUDIT_POSTHOG_2026-09-25.json)
covers 25 August–24 September UTC, project 600792. Historical MR-load attempts
numbered 2,181 with 197 reported failures and p95 11,479 ms. MR-submit attempts
numbered 74 with 27 reported failures and p95 20,017.1 ms. These are attempt
counts, not unique rejected business operations; a timeout may follow a commit.
No historical Company workflow events were available, so this cannot establish
Company production success or failure rates.

The candidate introduces distinct Company started/opened/confirmed/failed/
unconfirmed events and route classification. Telemetry uses fixed operation
names and durations, without query text, people, identifiers, payloads, reasons,
quantities or commercial values. PostHog is disabled in synthetic local testing.
The [analytics contract](../analytics/POSTHOG_ANALYTICS.md) documents this boundary.

## Verification

Source implementation: `ff9354c` (followed only by evidence documentation).
Earlier checkpoint results do not certify the final artifact.

| Gate | Observed result |
|---|---|
| Dependency resolution and changed-Dart formatting | Passed; 45 changed Dart files |
| Final analyzer | No issues |
| Focused Company/integration/router/analytics tests | 134 passed |
| Main entry and shared command palette | 1 + 1 passed |
| Search launch/disposal and Workforce navigation regression | 17 passed; repeated activation, failed chunk retry and workspace replacement covered |
| New unified-register real-font fixtures | 3 passed: 1440, 1024 and 360px |
| Company responsive checks | 360, 390, 600, 768, 1024, 1366, 1920px and short landscape; RTL and 200% text fixtures |
| Fresh isolated Supabase reset | Passed |
| Complete database suite | 109 files, 3,071 checks passed |
| Auth + REST with technical personas | [30 checks passed](evidence/company-mr-2026-09-25/auth-rest-lifecycle.json), including private-draft denials, independent approval, Procurement revision/reapproval, dispatch, receipt, handover, closure and cancellation retry |
| Database lint | 37 functions report retained warnings; no warning for the new unified register after volatility correction; not a clean global lint claim |
| Company-enabled CI web | Passed; initial JavaScript 10,263,683 bytes / gzip 2,766,299; existing budget unchanged |
| Company-enabled Android CI release build | Passed, 106.8 MB, ephemeral CI signing; not a production-signed artifact |
| Full Flutter suite | 1,606 passed; 264 failed. Every remaining failure name matches the prior checkpoint; [exact results](evidence/company-mr-2026-09-25/flutter-suite.json). Gate remains red |

[Artifact hashes](evidence/company-mr-2026-09-25/artifacts.json) identify the CI
outputs. The web uses the explicit `ci.invalid` backend and is not a live
application deployment.

Local browser verification used the same source in debug mode and the isolated
Auth/REST database. A signed-in Site Engineer reached the combined home despite
having no Project MR read grant. Company records appeared on desktop (1366px)
and phone (360px); global search opened the actual Company route. The phone
composer offered the active Yorks-login beneficiary, receiver and independent
Admin/Senior Mechanical Engineer choices. Activity showed
exact roles, Procurement revision and fresh approval, and the immutable issue
note showed the dispatched quantity. This is synthetic local verification, not
production or named-employee UAT.

## Preservation and rollback

The audit/search, selected-approver/actions and unified-register migrations are
additive. Preserve all request/line IDs, versions, approvals, original events,
issue notes, reservations and append-only inventory movements. Historical audit
imports retain original event times and explicitly identify imported snapshots;
they do not invent historical display names.

Rollback is Company flag off plus the previous compatible application artifact.
Keep schema additions and committed business evidence; fix forward. No migration
in this candidate deletes or reinterprets existing Company or Project records.

## Release boundary

Named-persona staging acceptance and properly signed Android release validation
remain distinct from local tests. Existing unrelated visual-baseline failures
must be reviewed rather than overwritten. Cross-module Company return registers
and a complete controlled-document set beyond immutable issue evidence retain
the explicit [T06 acceptance boundaries](COMPANY_MATERIAL_REQUEST_T06_END_TO_END_HARDENING.md).
