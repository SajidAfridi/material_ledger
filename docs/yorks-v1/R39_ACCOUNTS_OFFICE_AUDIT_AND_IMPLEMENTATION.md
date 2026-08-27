# R39 Accounts office audit and implementation evidence

**Audit date:** 28 August 2026
**Repository SHA before this remediation:** `68996ff148cb285f0316ff4418a30b6fa30f2a31`
**Scope:** Accountant landing, office navigation, responsive portfolio registers,
and their protected read projection. This document does not declare the complete
Accounts programme or production rollout finished.

## 1. Authority and scope

The repository authority order in `AGENTS.md` applies. The approved R39 package
supersedes older Accounts-only deferral language, while the Yorks V1 SRS and R35
contracts remain authoritative for every unrelated workflow. Accounts is a
project commercial-control system for baselines, engineering-confirmed billing
progress, claims, certification, receipts/PDCs, matched supplier bills,
documents, reports and audit. It is not a general ledger, payroll, tax,
depreciation, inventory-valuation, company P&L or unrestricted bank-
reconciliation system.

This change is additive. It does not alter Projects, BOQ, Material Requests,
Procurement Arrangement, Inventory, Dispatch, Receipt, Delivery Orders,
Returns, Rentals, Configuration, Team Chat or Engineering Tools. Accounts may
only use their already-authorized facts and narrow record links.

## 2. Sources inspected

- Current Flutter shell, GoRouter graph, Riverpod Accounts controllers,
  repositories, responsive screens and test suite.
- Accounts migrations and pgTAP coverage from R39 T01 through T07.
- `docs/yorks-v1/README.md`, `SOURCE_OF_TRUTH.md`, `PRODUCT_DECISIONS.md`,
  `ARCHITECTURE_AND_SECURITY_CONTRACT.md`, `R35_UI_CONTRACT.md` and
  `R39_ACCOUNTS_FOUNDATION.md`.
- Approved R39 requirements package, especially functional, non-functional,
  UI/UX and decisions/non-regression contracts.
- The supplied Accounts workstation references and the observed locked
  Accountant screen.
- `Project Master File - Nexus 4 Station.xlsx` and `Equipment Schedule.xlsx`,
  inspected read-only with the bundled spreadsheet runtime.

## 3. Source-grounded workbook findings

The Project Master File supports a sample total contract value of
AED 17,192,000. Its summary allocates 25% each to DF3W, DF4W, DF6W and DF7W,
and totals the following stages to 100%:

| Source label | Percentage | Sample value |
|---|---:|---:|
| Cooling Load Design | 10% | AED 1,719,200 |
| Material Supply | 50% | AED 8,596,000 |
| Progress Installation | 30% | AED 5,157,600 |
| Comissioning & Handover | 5% | AED 859,600 |
| Energizing Substation | 5% | AED 859,600 |

The workbook also says `Note: 45 days PDC`, but does not establish which date
starts that term. These are project-specific evidence values, not organization
defaults.

The workbook is not safe as direct database authority:

- `Project Details` identifies project `N-17712-A`, while the summary and
  commercial worksheets use variants of `N-19957.2` / `N-1957.2`.
- The Communication Protocol sheet contains visible `#VALUE!` cells.
- Several date-like values are stored as Excel serial numbers.
- The Installation sheet retains a `Material Supply` subject line, consistent
  with copied-template content.
- Common material references exist, but the workbook does not authorize Common
  as a fifth physical commercial allocation.

The Equipment Schedule is technical evidence. It contains tags, size/location,
model/make, quantities, MASS references and statuses including `AP` and `AEN`.
It does not contain an approved mapping that makes those rows financially
authoritative. The meaning of `AEN` remains an explicit Yorks decision.

## 4. Current-state architecture and schema

The existing Accounts implementation already follows:

`Widget -> Riverpod controller -> repository -> protected Supabase RPC -> PostgreSQL`

The R39 T01-T07 foundation already provides:

- the exact `accountant` platform role and command-specific capability model;
- protected project scope independent of technical project membership;
- revisioned commercial profiles, physical-building and billing-stage
  allocations, billing progress and progress confirmation;
- normalized claims, immutable claim lines, client invoices, certification,
  receipts, PDCs and append-only PDC events;
- supplier bills, evidence matching, approval and supplier-payment controls;
- protected portfolio/project projections, controlled documents, exports,
  notifications, audit and release-health controls;
- RLS on normalized financial relations, transactional critical commands,
  numeric money parsing, version checks, idempotency and append-only audit.

No Flutter widget directly performs an authoritative Accounts write.

## 5. Existing behavior and root cause

The exact Accountant role and protected Accounts domain were present, but the
visible experience failed in two places:

1. `DashboardScreen` always rendered the rollout-locked Accountant view even
   when `YORKS_V1_ACCOUNTS` was enabled.
2. The shell exposed only a minimal Accounts entry instead of the approved
   Accountant office information architecture. Root and stale-session routing
   did not converge an authorized Accountant onto the Accounts control centre.

This was a client routing/presentation defect, not permission to bypass the
feature flag or server capability snapshot.

## 6. Gap matrix and remediation decision

| Area | Audit result | This remediation |
|---|---|---|
| Accountant landing | Enabled users still saw a locked empty state | Route authorized Accountants to the live control centre; keep the locked state when the operator flag is off |
| Office navigation | Missing portfolio registers and audit/report destinations | Add Overview, Project Accounts, Claims & Client Invoices, Receipts & PDC, Supplier Bills, Due Schedule, Documents, Reports and Audit Trail |
| Billing Progress | Already exists as a protected per-project core tab | Keep project billing as the authoritative detailed surface; expose a direct office route into the portfolio before project selection |
| Portfolio work queues | Existing portfolio supplied protected totals and action queue | Reuse it as the Accountant home; do not fabricate sample amounts |
| Cross-project registers | No single paginated server projection for office lists | Add one sectioned, server-filtered RPC and a Riverpod repository/controller consumer |
| Responsive UX | Project Accounts was responsive, but office registers were absent | Add desktop data tables, mobile record cards, tablet-safe wrapping, explicit empty/error/loading states and 44px actions |
| Commercial secrecy | Must remain independent per field family | Require project Accounts + commercial capability for client values; require both project Accounts and the same project's supplier-cost capability for supplier rows |
| Reports | Protected export service already exists | Reuse it; do not simulate scheduled delivery or unsupported exports |
| Bank reconciliation | Not approved by the authoritative V1 contract | Exclude bank reconciliation/import matching from this slice |
| Critical mutations | Existing T02-T04 RPCs own them | Do not duplicate or move critical writes into the office register |

## 7. Security and performance design

The office register is a `security definer` RPC with a pinned search path,
authenticated-only execution and an exact permitted-section allowlist. It
materializes permitted projects and capability booleans once per request, then
applies server-side search, status filtering and bounded pagination. It returns
fixed-precision monetary values as text for exact Dart parsing.

The response deliberately contains no portfolio-wide mutation-capability
booleans. Such booleans could be true because of authority on one project and
must never be reused to authorize an action on another. Every office row is
admitted by capabilities resolved for that row's own project; project detail
screens and trusted commands independently repeat their project-scoped checks.
Supplier rows require both `view_project_accounts` and `view_supplier_costs`
for that same project. Supplier matching reuses the T04
`v1_accounts_supplier_match_status` authority instead of reimplementing it.

Activity rows intentionally omit audit before/after values in the portfolio
register. Full protected history remains available through the existing
project-level inspector. Document rows require the existing controlled-document
read predicate. Multiple active links for one document/project are collapsed
to one row with a deterministic representative entity context. The function
performs no mutations and creates no alternate financial source of truth.

The client controller keeps the previous confirmed projection visible while a
new filter is loading. A monotonically increasing request generation prevents
an older search/status response or load-more response from overwriting a newer
result.

## 8. UX and accessibility review

- Existing Yorks shell, colors, spacing, typography and connection state are
  retained.
- The control centre leads with server-confirmed KPIs, action queues and the
  project register; there is no decorative hero that displaces work.
- Desktop uses a persistent Accountant sidebar and dense table; mobile uses
  focused cards and bottom navigation rather than a squeezed desktop table.
- Buttons and selectable rows preserve at least 44px interaction height.
- Statuses are displayed as text as well as color. Loading, no-data, denied,
  offline/server-error and retry states remain explicit.
- Keyboard and screen-reader coverage uses the existing Material controls and
  semantic table/card labels; a full assistive-technology UAT remains required.

## 9. Open Yorks decisions

The following are not invented by this change:

1. Meaning of `AEN` and other engineering-submittal codes.
2. Start basis for the sample 45-day PDC term.
3. Common-work allocation versus an explicit project-level commercial package.
4. Senior Engineer/Project Manager progress-approval thresholds.
5. Initial-release policy for VAT, retention and credit notes.
6. Whether supplier payments are executed in Yorks or only tracked.
7. Whether bank-statement reconciliation will be approved later.
8. Whether a Claim and Client Invoice remain one-to-one.
9. Final role matrix for unit prices, supplier values and complete totals.
10. Whether historical workbook values are migration input or evidence only.

## 10. Migration and rollback risk

The office migration adds one read-only RPC and no table, column, policy or
historical-row mutation. Rollback is a forward disable: turn off
`YORKS_V1_ACCOUNTS`, remove the office navigation consumers, then revoke/drop
the new RPC in a later migration. T01-T07 data remains intact. Production
enablement remains an explicit release-owner action after database, Flutter,
responsive and staging UAT gates pass together.

## 11. Completion boundary

This slice fixes the observed locked landing and implements the Accountant
office read experience on top of existing T01-T07 commands. It does not claim
that historical workbook migration, baseline import, every report variant,
automated external reminders, bank reconciliation or staging UAT is complete.
Those remain separately governed acceptance work.

## 12. Verification evidence

- `flutter pub get` — passed.
- Changed-Dart formatting gate — passed.
- Focused Accounts office/router tests — passed, 15 tests. This includes
  desktop, tablet and 390px mobile goldens, exact money parsing, out-of-order
  response protection, visible in-place refresh progress, due-record routing,
  localization and both directions of the organization Supplier Bills
  capability guard.
- `flutter analyze` — passed with no issues.
- Clean `npx --yes supabase db reset --local` — passed across the full tracked
  migration chain.
- Focused T08 pgTAP — passed, 11 assertions.
- Complete `npx --yes supabase test db --local` — passed, 58 files and 1,633
  assertions, including unrelated retained modules and the concurrently owned
  Team Chat migration.
- Accounts-enabled CI web release build — passed.
- Accounts-enabled CI ephemeral-signed Android release build — passed; output
  was a 98.0 MB APK. Gradle, Android Gradle Plugin and Kotlin emitted only
  future-support deprecation warnings.
- The complete Flutter suite was also attempted: 1,065 tests passed and 201
  failed in widespread pre-existing/unrelated golden comparisons. Those
  unrelated goldens were deliberately not rewritten, so this is not recorded
  as a globally green Flutter suite.

No production/staging migration, deployment, feature-flag change, commit or
push was performed in this slice.
