# Yorks V1 R39 — Accounts Foundation and Phased Rollout

Status: **approved for additive implementation on 25 August 2026**

This contract reconciles the approved Yorks Accounts R39 package with the
existing Yorks V1 source of truth. It supersedes only earlier statements that
Accounts is deferred, unavailable, or permanently unreachable. Every
non-Accounts workflow, role boundary, quantity invariant and retained module
continues unchanged.

Accounts is project commercial control, not a general accounting ERP. It
connects defensible technical progress to claims, certification, collections,
PDC evidence and matched supplier bills. It does not add a general ledger,
payroll, bank reconciliation, tax, depreciation, inventory valuation,
company-wide profit and loss, or a complete RFQ/PO suite.

## 1. Authority and non-regression

For Accounts-only conflicts, the approved 25 August 2026 R39 requirements,
workflow, test matrix, implementation prompt and decision record take
precedence over older R35/R38 statements that kept Accounts hidden. The
existing Yorks V1 contracts remain authoritative for Auth, scoped permissions,
projects, BOQ, Material Requests, Procurement, Inventory, Dispatch, Receipt,
Delivery Orders, Returns, Documents, Notifications, Audit, Configuration,
Rentals, Team Chat and Engineering Tools.

Accounts may read trusted operational facts through narrow authorized
projections. It never rewrites project technical data, BOQ rows, Material
Request quantities, arrangements, reservations, inventory movements, dispatch
quantities, receipt outcomes, returns or project membership. This is the
binding boundary for FR-002 and FR-003.

The legacy `/admin/finance` route and its current Finance model are preserved
only as legacy evidence. They are not an Accounts authority, cannot create or
mutate normalized Accounts records and must not be used as a fallback when a
normalized Accounts dependency is unavailable.

## 2. Phased rollout and route boundary

The exact feature flag is `YORKS_V1_ACCOUNTS`. It defaults **off** and fails
closed. An unavailable dependency, missing capability projection or disabled
flag removes Accounts navigation, command-search targets, deep links and
actions instead of exposing a partial workspace (FR-014).

| Phase | Bounded outcome | Runtime authority |
|---|---|---|
| T00 | Current-system and requirements audit | No mutation |
| T01 | Exact role, capability catalogue, feature flag, additive/shadow schema and RLS foundation, default stage policy | Existing consumers remain authoritative; no Accounts route or command cutover |
| T02 | Commercial baseline, physical-building/stage allocations and Billing Progress | Activate only the six T02 server capabilities and tested projections/commands; the app flag and normalized UI remain off |
| T03 | Claims, client invoices, certification, PDC and client payments | Cut over only its tested projections/commands |
| T04 | Supplier bills and three-way match | Cut over only its tested projections/commands |
| T05 | Normalized routes, portfolio and project Accounts UI | Reachable only behind the enabled flag and server capability projection |
| T06 | Documents, audit, notifications, exports and reports | Reuse existing protected Yorks subsystems |
| T07 | Golden, security, performance, staging UAT and release evidence | Production enablement only after the complete acceptance gate |

T01 is additive and shadow-only. It may add protected catalogue/default rows,
role constraints, normalized empty schema, policies and negative tests, but it
must not broaden a current user's effective access or make Accounts reachable.
T02–T07 cut over one protected surface at a time. Rollback returns an affected
consumer/flag to disabled or shadow while retaining committed records,
revisions, documents and audit evidence.

## 3. Exact role model

Yorks now has nine exact, singular, server-controlled Auth roles:

- `project_engineer`
- `site_engineer`
- `senior_mechanical_engineer`
- `project_manager`
- `workshop_in_charge`
- `document_controller`
- `procurement`
- `accountant`
- `admin`

`accountant` is a platform role, not a technical project-membership role
(FR-016 and FR-017). It never normalizes to Project Engineer or Site Engineer,
cannot be inserted into technical project membership, and receives project
scope only through protected Accounts capability resolution. Its exact role is
retained in audit and controlled records.

The Accountant can manage authorized client invoices, certification, PDCs,
payments, supplier-bill Accounts controls, Accounts documents and Accounts
activity. It cannot mutate Projects, BOQ, Material Requests, Dispatch, Receipt,
Inventory, Returns or technical membership (FR-021 and AT-SEC-003).

Project Engineer, Site Engineer, Procurement, Admin and management review
authority remain separated as specified by FR-019 through FR-024. Revocation,
deactivation, stale exact-role claims or scope removal fail closed immediately
without deleting historical attribution (FR-025, AT-SEC-006 and AT-SEC-007).

## 4. Exact Accounts capability catalogue

The following 15 keys are exact and centralized. The server returns effective
capabilities and record-specific command flags; Flutter never infers authority
from a role label, job title, route visibility or local enum (FR-018).

1. `view_project_accounts`
2. `view_project_commercial_values`
3. `suggest_billing_progress`
4. `confirm_billing_progress`
5. `prepare_client_claim`
6. `manage_client_invoices`
7. `record_client_certification`
8. `record_client_payment`
9. `manage_pdc`
10. `manage_supplier_bills`
11. `approve_supplier_bill_payment`
12. `configure_project_commercials`
13. `view_supplier_costs`
14. `export_accounts_registers`
15. `review_commercial_progress`

Each catalogue row declares organization/project scope, risk, delegation
ceiling, runtime wiring and `shadow` or `enforced` authorization mode.
Assignments never bypass exact active identity, project scope, document
classification, record state, separation of duties, expected version,
idempotency or append-only audit. T01 seeds these keys in `shadow`; a key
becomes assignable/enforced only with its protected consumer and positive and
negative tests.

## 5. Binding defaults and allocation rules

- Payment terms default to **90 days**, are configurable per commercial
  baseline and are snapshotted on invoice submission.
- Reminder lead defaults to **10 days**, is configurable and is snapshotted for
  the submitted invoice policy.
- Default billing stages are Design **10%**, Material Supply **50%**,
  Installation **30%**, Commissioning & Handover **5%**, and Energizing **5%**.
- The protected default-stage template totals exactly 100% within the server's
  explicit numeric tolerance. T01 enforces that template invariant and
  protects its seeded rows from drift.
- T01 freezes the downstream commercial-baseline policy that physical building
  allocations must total exactly 100% within that tolerance and that
  `Common / All Buildings` is not a physical commercial allocation.
- T01 does **not** create project physical-building allocation relations or
  row-level allocation constraints. T02 adds those relations with the
  commercial baseline and enforces the 100% total and Common exclusion on the
  server.

T01 implements the FR-029 defaults and records the binding FR-030/FR-031
policy. T02 implements the project-row authority and runtime enforcement for
FR-030/FR-031. These are server-owned defaults and rules, not hardcoded UI
authority. Existing submitted invoices keep their snapshots; later
configuration changes are forward-only.

## 6. T02 commercial baseline and Billing Progress contract

T02 is a server-authority slice, not an Accounts launch. It keeps
`YORKS_V1_ACCOUNTS` off, adds no route or reachable Flutter workspace, and
does not claim production readiness. It may move only
`view_project_accounts`, `view_project_commercial_values`,
`suggest_billing_progress`, `confirm_billing_progress`,
`configure_project_commercials` and `review_commercial_progress` from shadow
to their tested T02 runtime mode. Every T03 claim/invoice key, the T05 UI and
routes, and the T06 document-upload, export and report consumers stay shadow.

### 6.1 Protected records and state

T02 owns the normalized `v1_accounts_project_commercial_profiles`,
`v1_accounts_baseline_revisions`,
`v1_accounts_baseline_building_allocations`,
`v1_accounts_baseline_stage_allocations`,
`v1_accounts_billing_progress` and
`v1_accounts_billing_progress_revisions` relations. Ordinary authenticated
clients have no direct write grant. Baseline revision 1 is initialized once;
later changes create a numbered revision with reason, actor, exact role,
server time and before/after snapshot. Activation atomically makes the valid
new revision current and supersedes the prior current revision. It never
updates a historical revision in place.

An active baseline snapshots currency, positive fixed-numeric contract value,
payment terms, reminder lead, an explicitly supplied validated VAT rate,
physical-building allocations, stage allocations, effective date and
approving actor. There is no approved Accounts VAT default: T02 must not copy
Rentals' 5%, infer 0%, or activate a baseline without an explicit VAT snapshot.
Payment terms default to 90 and reminder lead to 10, with
`0 <= reminder <= payment terms` enforced by the server.

Physical-building and stage percentages use `numeric(7,4)`. Each active set
must total 100.0000 within the explicit 0.00005 comparison tolerance;
99.9990 is outside that tolerance. `Common / All Buildings` is rejected from
physical allocation input. The server derives Stage Value as contract value ×
building allocation × stage allocation and reconciles the rounded schedule
back to the baseline; the client never supplies an authoritative Stage Value.

There is one current progress row per project, baseline revision, physical
building and stage, enforced by a unique key. Suggested and confirmed progress
are separate 0–100 fixed-numeric facts. Suggestions never change confirmed or
eligible values. Every suggestion, confirmation, review or controlled
correction appends a revision with prior/new facts, evidence, reason, actor,
exact role and server time; no client-authored actor or timestamp is accepted.

### 6.2 Evidence and review policy

Until a project evidence policy is explicitly configured, T02 uses the
least-privilege fallback allowed by FR-045/FR-047:

- a suggestion needs either a nonblank evidence summary or an already
  authorized project-linked document reference;
- an increased confirmation needs at least one authorized evidence reference;
  a summary alone is insufficient; and
- no exception route exists in T02. An evidence exception therefore fails
  closed until a later approved policy defines its approver and evidence.

T02 reuses already protected project document references for validation only.
It does not add an Accounts upload surface; Accounts document upload/link UI
and exports remain T06.

Management review defaults to disabled with a null threshold. It becomes
required only after an authorized baseline explicitly configures its project,
role and/or amount rule. A required review is recorded only by an actor with
`review_commercial_progress`; the projection exposes the pending blocker and
future claim preparation remains blocked until satisfied. The package does
not approve an implicit monetary threshold, quorum or review expiry, so T02
must not invent one.

| Package gap | Safe T02 decision | Why it is permitted |
|---|---|---|
| No numeric Accounts VAT default | No default; explicit validated 0–100 fixed-numeric snapshot is required | FR-028 requires a snapshot but authorizes no rate. Borrowing Rentals' 5% or assuming 0% would invent financial policy. |
| No management amount threshold, quorum or expiry | Default policy is disabled/null; an authorized baseline may explicitly configure a positive threshold and/or allowed confirming exact roles | FR-048 says review *may* be required, so disabled is a faithful inert state, not a business threshold assumption. |
| No full evidence-mode/minimum-summary policy | Suggestion accepts a nonblank summary or authorized reference; increased confirmation requires an authorized reference; no exception path is exposed | FR-045 permits summary or evidence for suggestions, while FR-047 expressly requires a reference or approved exception for an increase. No exception approver/process is approved. |
| Numeric tolerance value is not named | Percentages are stored at four decimals and totals use an explicit 0.00005 comparison tolerance | This is the narrow fixed-precision implementation constant needed to satisfy FR-030/FR-032 and ensures AT-BL-002's 99.999% fails. |

### 6.3 Server calculations and role-safe projections

The server calculates Stage Value, Confirmed Eligible, cumulative Confirmed
Eligible and Confirmed Commercial Progress. Monetary and percentage JSON
numbers are serialized as decimal strings so browser floating-point cannot
become authority. Technical project completion remains a separate operational
fact and is never replaced by commercial progress.

T02 provides only these protected commands/projections:

- `v1_initialize_project_commercial_baseline`
- `v1_revise_project_commercial_baseline`
- `v1_suggest_billing_progress`
- `v1_confirm_billing_progress`
- `v1_review_commercial_progress`
- `v1_get_project_commercial_baseline`
- `v1_list_billing_progress`
- `v1_list_billing_progress_revisions`

All commands derive the current actor and exact role, re-check active identity,
capability, project/building scope and record state, require expected version
plus idempotency key/request hash, lock affected rows in deterministic order,
and append trusted audit in the same transaction. The same key and same hash
returns the prior result; the same key with a different hash is a conflict.

The non-monetary projection includes identifiers, baseline status/revision,
building/stage labels, suggested and confirmed percentages, evidence state,
workflow owner, review blockers, version and record-specific command flags. It
contains no monetary field key. The commercial projection adds contract,
currency, VAT, terms, allocations, Stage Value, Confirmed Eligible,
cumulative eligible and commercial-progress amounts only when
`view_project_commercial_values` is effective. Confirming progress does not by
itself grant value visibility. Unauthorized project access returns no row or
is denied; it never returns zero-valued protected placeholders.

T02 has no claim table or claim command. Its protected claim-consumption seam
is zero only while T03 is absent, so Available to Claim equals cumulative
eligible and is not actionable. T03 atomically replaces that seam and
completes non-cancelled-claim subtraction, unsafe-reduction blockers, stale
claim-draft handling and double-claim concurrency. T02 may expose a future
`prepare_claim` blocker/next-action fact, but cannot make Prepare Claim
reachable.

Filtering arguments for building, stage, action owner and evidence may narrow
rows only; unfiltered totals and blockers remain server-derived. T05 renders
those filters and next actions. FR-039/FR-057 and AT-BL-008 require a role-safe
report source, but actual print/export/layout is T06.

### 6.1 T03 claim and client-receivables boundary

T03 adds a separate claim root plus immutable line snapshots, client invoices,
cumulative certification revisions, append-only client payments, PDCs and
append-only PDC events. It replaces the T02 claim-consumption/stale-draft seams
without changing a historical baseline or progress fact.

Every non-cancelled claim reserves its eligible amount once. Draft deletion or
explicit cancellation releases capacity; return/resubmission does not. A claim
line snapshots baseline revision, progress revision/version, building/stage,
stage value, confirmed percent, eligible amount, prior claimed amount, current
claim and evidence reference. Baseline revision marks open claim work stale
instead of rebasing it. Reducing confirmed progress below active claim basis is
blocked with the exact authorized claim references.

Invoices snapshot VAT, payment terms, reminder lead, submission and due dates.
Certification uses cumulative append-only revisions and the invoice VAT
snapshot. Payments are append-only facts; an exact linked reversal corrects a
receipt. PDC receipt/deposit remains separate from payment, while an explicit
evidence-backed clearance atomically adds one linked payment. The precise
lifecycle/release/exposure rules are frozen in
[`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

T03 promotes only `prepare_client_claim`, `manage_client_invoices`,
`record_client_certification`, `record_client_payment` and `manage_pdc` after
their command/projection tests. It adds no route/UI, supplier-bill behavior,
parallel notification system, document upload, export or report. The feature
flag remains off; T05 and T06 own those consumers.

### 6.2 T04 supplier-bill and three-way-match boundary

T04 adds protected project supplier bills and append-only supplier-payment
facts without creating a Purchase Order suite. A bill retains the external
PO/LPO reference, supplier identity, case-insensitively unique supplier invoice
reference within its project, invoice and due dates, fixed-precision ex-VAT,
VAT and total values, controlled evidence links, notes, state, actor, exact role
and version.

Three independent evidence groups are evaluated by the server: (1) both an
external PO/LPO reference and a current project-linked commercial PO/LPO
document, (2) a confirmed operational receipt review whose server-derived good
quantity is positive, and (3) a current project-linked commercial supplier
invoice document. `matched` requires all three; `review` means exactly two;
`blocked` means fewer than two or an explicit mismatch. The trusted receipt
and delivery reference are read from the accepted logistics records and cannot
be supplied or overridden by an Accounts client.

Procurement may create and maintain draft evidence only. Accountant or Admin
may approve and record payment, Procurement cannot approve its own work, and
the supplier-invoice document is mandatory even for Admin. Only exact Admin
may approve or pay an otherwise unmatched bill, with a fresh nonblank reason
captured by that command and audit event. A prior exception does not silently
authorize a later payment exception.

Payment state is derived as `pending`, `approved`, `partially_paid`, `paid`,
`blocked` or `cancelled`. Net payments cannot exceed the snapshotted total
including VAT. Corrections are exact linked reversals of append-only facts;
payment references are case-insensitively unique within the project. A bill
with nonzero net payment cannot be cancelled. T04 promotes only
`manage_supplier_bills`, `approve_supplier_bill_payment` and
`view_supplier_costs` after their protected command/projection tests.

T04 adds no route, screen, document uploader, notification, export, report or
legacy Finance bridge. `YORKS_V1_ACCOUNTS` remains off; T05 and T06 own those
consumers.

Activating Accounts role defaults must not revoke an already authorized,
action-only User Management password-reset or activation command. Those two
actions evaluate the established non-Accounts target hierarchy. Exact-role
creation and role change continue to evaluate the complete role template,
including operational Accounts capabilities, through a separate strict Auth
guard before the durable User Management audit trigger.

### 6.3 T05-T07 normalized application and release boundary

T05 exposes only normalized `/accounts` and project Accounts routes behind the
default-off feature flag and live protected capability projection. Portfolio,
project overview, Billing Progress, client receivables/PDC, supplier bills,
Documents and Activity use typed Riverpod controller/repository boundaries.
No screen derives authority from a displayed role, and legacy Finance is not a
fallback.

T06 reuses the protected Yorks controlled-document store, storage finalizer,
append-only audit and notification subsystem. Accounts document metadata is a
classification/link extension, not a second file store. Structured
server-scoped report projections are the one source for XLSX and PDF/print;
exports neutralize spreadsheet formulas and preserve commercial response
shapes. `export_accounts_registers` is the fifteenth operational capability.

T07 adds private transaction-success metrics derived from committed audit,
privacy-safe client rejection/conflict/infrastructure telemetry, service-only
idempotent reminder job runs and Admin-only readiness/health projections.
Every user-visible Accounts infrastructure failure may carry an `ACC-…`
support reference; logs never include RPC payloads, commercial values, SQL or
stack details. The required six-viewport matrix covers Portfolio, Billing,
Invoices, Supplier Bills, Documents and Activity.

These local gates do not enable production. `YORKS_V1_ACCOUNTS` remains off
until all five staging personas pass on one release commit, no P0/P1 remains
and the release owner explicitly approves enablement.

## 7. T01 security and maintainability gate

T01 is incomplete unless it proves:

- migrations are additive, repeatable and rollback-safe without destructive
  reinterpretation (NFR-MAINT-003);
- the ninth role and all 15 capability keys are centralized across Auth role
  constraints, audit constraints, protected projections, user management,
  route guards, seed personas and tests (NFR-MAINT-004);
- Accountant direct table/RPC attempts against BOQ, MR and Dispatch are denied
  with no partial effect (AT-SEC-003);
- inactive Accountant plus stale token receives no Accounts read or command
  result and protected client state is purged (AT-SEC-006); and
- an unknown exact role receives no Accounts capability, projection, route or
  command privilege (AT-SEC-007).

The T01 evidence must also demonstrate that the feature flag remains off, no
normalized Accounts route is reachable, `/admin/finance` has gained no
authority, and existing eight-role operational behavior is unchanged except
for recognizing the ninth exact role as denied outside its future Accounts
surface.

## 8. Requirement traceability

| Requirement | Repository decision |
|---|---|
| FR-002 | Normalized Accounts is separate from legacy Finance authority. |
| FR-003 | The rollout changes Accounts only, except read-only contextual links. |
| FR-014 | `YORKS_V1_ACCOUNTS` defaults off and every incomplete dependency fails closed. |
| FR-016 | `accountant` is the ninth exact server-authorized role. |
| FR-017 | Accountant is never a technical project member. |
| FR-018 | Server capabilities and record command flags are authoritative. |
| FR-019 | Authorized Project Engineer may confirm progress, prepare claims and add evidence, not record payment facts. |
| FR-020 | Authorized Site Engineer may suggest progress/evidence without protected values or confirmation authority. |
| FR-021 | Accountant controls authorized Accounts facts but no technical workflow mutation. |
| FR-022 | Procurement controls supplier-bill evidence only, not client certification/payment or receivables by default. |
| FR-023 | Admin configures baselines and every exceptional correction is reasoned/audited. |
| FR-024 | Management review requires `review_commercial_progress`, not a display title. |
| FR-025 | Revocation fails closed immediately while historical attribution remains. |
| FR-029 | T01 protects the 90/10 policy and 10/50/30/5/5 default-stage rows; the stage template totals 100% within numeric tolerance. Submitted invoices later retain snapshots. |
| FR-030 | T01 freezes the 100% physical-building allocation policy; T02 creates the project allocation relation and enforces its total within numeric tolerance. |
| FR-031 | T01 freezes Common / All Buildings as non-physical; T02 excludes it from project physical-allocation rows and commands. |
| NFR-MAINT-003 | Migrations and rollback are additive and data-preserving. |
| NFR-MAINT-004 | Role/capability constraints have one centralized, tested source. |
| AT-SEC-003 | Accountant BOQ/MR/Dispatch mutation is denied with no partial effect. |
| AT-SEC-006 | Inactive Accountant plus stale token receives no protected access. |
| AT-SEC-007 | Unknown roles receive no Accounts privilege. |

### T02 traceability

| Requirement/test | T02 contract or deferred completion |
|---|---|
| FR-026 | One protected project profile owns numbered immutable commercial baseline revisions. |
| FR-027 | Contract value is positive fixed numeric; zero, negative, NaN and malformed input fail. |
| FR-028 | Each baseline snapshots currency, terms, reminder and explicitly supplied VAT; T03 snapshots invoice policy. |
| FR-029 | T02 consumes protected 90/10 defaults; T03 proves submitted invoice retention. |
| FR-030 | Physical-building allocation rows total 100.0000 within 0.00005. |
| FR-031 | Common / All Buildings is rejected and excluded from physical allocations. |
| FR-032 | Active stage allocations total 100.0000 within 0.00005. |
| FR-033 | Ordered 10/50/30/5/5 default stages initialize idempotently with no demo money. |
| FR-034 | Stage Value is server-calculated and schedule totals reconcile to baseline within rounding tolerance. |
| FR-035 | In-place edit is forbidden; later change is a reasoned numbered revision. T03 adds submitted-claim blocking proof. |
| FR-036 | Baseline revision preserves before/after, reason, actor, exact role, approval and server time. |
| FR-037 | Earlier baselines remain immutable; T03 proves historical claim/certification/payment/PDC due-date preservation. |
| FR-038 | Server enforces `0 <= reminder <= payment terms`. |
| FR-039 | T02 supplies the role-safe report source; T06 implements baseline print/export. |
| FR-040 | T02 exposes baseline status/revision facts; T05 renders them. |
| FR-041 | Unique current progress row per project/revision/physical building/stage. |
| FR-042 | Suggested and confirmed progress remain separate; suggestion is never claimable. |
| FR-043 | Suggestion/confirmation percentages are server-validated 0–100. |
| FR-044 | Site suggestion requires active authorized project/building scope. |
| FR-045 | Suggestion revision retains evidence summary/reference, actor, exact role and server time. |
| FR-046 | Confirmation independently records suggestion context and the confirmed fact. |
| FR-047 | An increased confirmation needs an authorized evidence reference; no unconfigured exception route exists. |
| FR-048 | Explicit review policy produces a blocker satisfied only by `review_commercial_progress`; claim preparation remains T03. |
| FR-049 | Confirmed Eligible is server-calculated from Stage Value × confirmed percentage. |
| FR-050 | Cumulative Confirmed Eligible sums current rows under the active baseline and reconciles to the register. |
| FR-051 | T02 reserves the claim-consumption seam; T03 implements non-cancelled subtraction and double-claim prevention. |
| FR-052 | T02 versions progress; T03 returns blocking claim references for unsafe reduction/correction. |
| FR-053 | Suggestion, confirmation, review and correction append immutable revisions/audit. |
| FR-054 | Confirmed Commercial Progress is server-derived and never operational completion. |
| FR-055 | Technical progress, eligible, claimed, certified and paid remain distinct facts. |
| FR-056 | Server filters rows without changing unfiltered calculations or hiding blockers; T05 renders filters. |
| FR-057 | T02 supplies the authorized register/revision source; T06 implements export. |
| FR-058 | Non-value projection contains percentage/evidence/owner and no monetary keys; T05 renders guidance. |
| FR-059 | Project Engineer confirmation authority is independent from commercial-value visibility. |
| FR-060 | T02 returns server command flags/blockers; T03 adds Prepare Claim and T05 renders next actions. |
| AT-E2E-001–004 | T02 proves baseline activation, suggestion independence, lower confirmation and configured review blocker; claim preparation itself remains T03. |
| AT-BL-001–005 | T02 proves positive contract, 100% allocation/stage rules, Common rejection and reminder bounds. |
| AT-BL-006, AT-BL-007 | T02 proves revision-only history and immutable baseline snapshots; submitted-claim/invoice cross-phase assertions complete in T03. |
| AT-BL-008 | T02 proves report-source reconciliation; T06 proves printed page content/layout. |
| AT-PROG-001–005, AT-PROG-008 | T02 proves range/evidence/confirmed-value/version concurrency and non-monetary response shape. |
| AT-PROG-006, AT-PROG-007 | T03 completes non-cancelled/cancelled claim subtraction exactly once. |
| AT-SEC-001, AT-SEC-004, AT-SEC-005, AT-SEC-008 | Value fields are absent without capability; guessed/revoked scopes fail closed; direct/network response shapes leak no protected fields. |
| AT-CONC-002, AT-CONC-003 | Every T02 command proves same-key/same-hash replay and same-key/different-hash conflict. |
| AT-CONC-005 | T02 exposes immutable baseline revision/version facts; T03 completes open-claim-draft staleness without rebasing. |
