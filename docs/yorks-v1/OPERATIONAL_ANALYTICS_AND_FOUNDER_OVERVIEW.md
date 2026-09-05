# Yorks Operational Analytics and Founder Overview

Status: approved implementation contract, 4 September 2026.

This contract governs the Yorks company **Overview** and the separately
authorized, read-only **Analytics** workspace. It extends the existing R35
operational system; it does not replace the Projects, Material Requests,
Accounts, Workforce, Rentals, Inventory or Audit workspaces that own their
records and commands.

## 1. Product contract

The Overview is the calm first screen for the founder and other authorized
leaders. It answers three questions without requiring system knowledge:

1. What is happening across the company?
2. What genuinely needs my attention?
3. Where should I go to inspect or act?

Analytics is the deeper read-only investigation screen. It adds explicit
filters, comparisons and traceable source links. It never creates, edits,
approves or deletes an operational record.

The visible name **Yorks Command Centre** is retired. The screen and its shell
destination are named **Overview**. This is a presentation change only.

## 2. Authority and effective access

`analytics.view` is the independent entry capability. Admin receives it from
the exact-role template at first enablement. An authorized permission
administrator may later grant or deny it at organization scope through the
existing audited access workspace.

Effective Analytics access is always the intersection of `analytics.view`, the
domain read capability, record/project access and any sensitive-field
capability.

Therefore Analytics never widens another module:

- Projects require the existing project read authority.
- Material Requests require the existing request read authority and request
  participant/readability rules.
- Accounts facts require the accepted Accounts capabilities and response
  shapes. Money is never combined across currencies.
- Workforce facts require Workforce capability plus complete dated
  responsibility.
- Rentals remain inside their accepted protected authority.
- Commercial, salary, document and audit fields retain their own independent
  capability boundaries.

The route is also gated by `YORKS_V1_ANALYTICS`. The flag defaults off until
the protected projection, route, responsive UI and tests pass together.

`analytics.export` is reserved as planned/shadow/nonassignable. It must remain
unavailable until a separately approved server-defined export contract exists.

## 3. Source and response contract

Flutter never builds company totals by hydrating every operational record.
The source is a protected, bounded, schema-versioned Postgres projection:

`Widget -> Riverpod provider -> repository -> v1_get_operational_analytics_foundation`

The current accepted response is schema version 2. The projection calls or
reads only existing protected source-domain authority and returns bounded
summary shapes; it does not create a second operational source of truth.

The response envelope contains:

- `schema_version`;
- `generated_at` in server UTC;
- requested and effective filters;
- the bounded month window and display timezone;
- per-domain coverage (`available`, `source_only`, `denied`);
- `is_partial` and typed warnings;
- only the domain payloads the actor may receive.

A zero is valid only when its domain is `available` and the protected query
completed. `source_only` means Analytics may link to that separately protected
workspace but does not yet aggregate it. Denied and malformed data are never
rendered as zero.

`is_partial` is true whenever any declared domain is `source_only` or
`denied`. The foundation therefore remains visibly partial until every domain
is represented by an accepted protected Analytics projection.

## 4. Frozen company-view KPIs

### Projects

- Total = readable projects in the effective filter.
- Active, On Hold, Completed, Draft and Archived = exact current lifecycle
  state counts over that same readable set.
- Current-project lists may use current state. Historical operational facts are
  not reinterpreted when a project later changes state.
- Project review is capped at 100 readable projects and shows reference, state,
  current action-owner role, readable open-request count, the actor's request
  action count and latest readable project/request activity.

### Material Requests

- Total = readable requests in the effective filter, including private drafts
  only when the normal request authority permits them.
- Open = all readable non-draft requests except Received, Closed and Cancelled.
- Awaiting engineering approval = `submitted`, `awaiting_request_approval` and
  retained `awaiting_approval` records.
- To arrange = `approved_for_arrangement` plus `arranging`.
- Changes requested = `changes_requested`.
- Dispatch ready = `approved` plus `partially_dispatched`.
- Receipt pending = `dispatched` plus `partially_received`.
- Delivery exceptions = `changes_requested`, `partially_dispatched` and
  `partially_received`.
- Monthly flow = submitted and closed counts grouped by server UTC month over
  the selected 3, 6 or 12 complete/current calendar-month buckets.
- Important request records are capped at 12 and contain the protected request
  reference, project, state, timing, current owner, next action and server age.
  They never create a new command path; opening one re-authorizes in Material
  Requests.

### Accounts

- Accounts is available only where the actor passes the accepted Accounts
  portfolio role gate and both `view_project_accounts` and
  `view_project_commercial_values` for each included project.
- Amounts are grouped by the baseline ISO currency and returned as decimal
  text. Currencies are never converted, added together or ranked against one
  another.
- Contract value and claimed value follow the accepted R39 ex-VAT definitions.
  Certified and received follow the accepted invoice certification and net
  receipt functions. Outstanding is the non-negative certified less received
  position. Labels do not imply profit, cash forecast or company P&L.
- Attention is the protected count of overdue and due-soon invoices, returned
  invoices and PDC actions. Detailed action remains in Accounts.
- Monthly claimed, latest-revision certified and net-received movements use the
  selected server-UTC month window and remain separated per currency.

### Workforce

- Company Workforce facts are available only to exact Admin with complete
  organization Workforce authority. A project filter does not reinterpret
  company workforce as project workforce.
- Current worker, supervisor and attendance/action counts come from the
  accepted protected Workforce admin overview.
- Time totals include only the latest approved snapshot of each monthly period
  and its recorded validation run. Regular and overtime minutes remain
  separate. They are evidence of approved hours, never a productivity or
  performance score.

### Rentals

- Company Rental facts are available only to exact Admin. A project filter does
  not attach rental business data to a technical project.
- The projection returns aggregate property, occupancy, rent-roll, collection,
  outstanding, deposit and attention counts in AED, plus bounded monthly
  collections.
- It never returns tenant, contact, unit, contract, cheque or document details.
  Detailed review remains in the protected Rentals workspace.

The company view intentionally contains no weighted project completion,
productivity score, payroll, P&L, inventory valuation, forecast, prediction or
AI recommendation. Inventory and Audit remain explicit source links until
separately accepted aggregate contracts exist.

## 5. Overview behavior

- Use the title **Overview** and plain-language server-confirmed subtitle.
- While the Analytics rollout and capability are effective, Admin Overview
  reuses the same schema-v2 company projection for its five-domain summary.
  It does not calculate a competing client-side Accounts, Workforce or Rental
  total. If that projection is unavailable, the established protected
  Project/Material Request overview remains usable with an honest partial-data
  notice.
- Show a small number of decision cards: active projects, important actions,
  open requests, Accounts position, active workers, Rental occupancy and real
  domain attention signals. Multiple currencies show a currency-group count;
  they are not combined into a headline amount.
- A card is absent or explicitly unavailable when its source is not confirmed.
- Material-flow visuals use the total request population when they include
  received and closed states; they must not be labeled as open requests.
- Every attention item links to the protected source workspace. The target
  screen re-authorizes normally.
- Admin controls remain navigation links, not Analytics mutations.

## 6. Analytics behavior

- Header: Analytics, read-only label, last-confirmed server time and Refresh.
- Filters: 3/6/12-month period and All Authorized Projects or one readable
  project. Filters can narrow results but never widen authority.
- Domain selector: Company, Accounts, Projects, Material Requests, Workforce
  and Rentals. It changes presentation only and never expands the RPC scope.
- Summary: only confirmed KPIs with visible definitions and source domain.
- Visuals: currency-separated Accounts position and monthly movements, Project
  review, Material Request pipeline and monthly flow, approved Workforce hours,
  and aggregate Rental occupancy/collections. Charts retain visible values and
  legends without hover.
- Important for you: actual readable Material Request records plus confirmed
  aggregate attention signals that link to their protected source workspaces.
- Coverage: unavailable domains show their honest inclusion state and link to
  the protected source where appropriate; they are not silently shown as zero.
- Partial state: successful domains remain visible with a warning identifying
  missing domains. A complete failure shows Retry and no synthetic values.
- Empty state: a confirmed empty authorized scope is distinguished from denied
  or unavailable data.

## 7. Responsive and accessibility contract

Reference layouts are desktop at 1100px and above, tablet at 721-1099px and
mobile at 720px and below.

- Desktop uses a stable filter row, multi-column summary and side-by-side
  investigation panels.
- Tablet uses two columns where values remain legible and collapses dense
  comparisons to labeled rows.
- Mobile uses a purpose-built single column: status, filters, important cards,
  flow, then coverage/source links. It never shrinks a desktop dashboard.
- Interactive targets are at least 44x44 logical pixels.
- Keyboard focus, semantics, non-color state cues, text scaling and RTL are
  required. Motion is optional, brief and respects reduced motion.

## 8. Verification and rollback

Acceptance requires:

- catalogue/default/delegation and anonymous/unauthorized pgTAP coverage;
- project/request scope-intersection and commercial-response-shape tests;
- response parser tests for valid, partial, malformed and true-zero payloads;
- route, flag, permission-revision and deep-link tests;
- desktop, tablet, 360x800 and RTL widget evidence;
- focused format/analyze/tests plus the applicable repository release gates.

Rollback is forward-only. Disable `YORKS_V1_ANALYTICS`, revoke authenticated
execution of the projection if containment is required, and deploy a corrective
migration/client. Retain capability assignments and their audit history. No
operational record is created or changed by this feature.
