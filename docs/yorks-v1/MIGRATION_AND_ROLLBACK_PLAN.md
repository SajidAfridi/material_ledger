# Yorks V1 R35 — Migration and Rollback Plan

## 1. Goals

- Introduce V1 without mutating the meaning of existing V7/legacy records.
- Keep current JSON decoding and unrelated modules operational during rollout.
- Make every schema/data step idempotent, observable and reversible at the
  application-routing level.
- Quarantine uncertainty instead of guessing or silently discarding it.
- Preserve IDs, references, timestamps, actors, commercial boundaries and
  `authorityRef` semantics.

## 2. Non-goals

- No destructive rewrite of production data.
- No automatic promotion of legacy Engineer users.
- No automatic reinterpretation of Phase 1 plans as approved BOQ/MR history.
- No migration through Flutter hydration, SharedPreferences merge, empty-table
  seed upload or generic last-write-wins sync.
- No dropping V7 tables during the Yorks V1 rollout.

## 3. Prerequisites

Before a production migration:

1. create a database backup and record restore evidence;
2. export/count every relevant legacy collection/table and local dataset in
   scope;
3. freeze source hashes and application version;
4. run the current baseline tests/builds;
5. deploy additive schema with all V1 flags off;
6. run positive/negative RLS and clean-reset tests;
7. prepare explicit user-role/project-membership reconciliation input;
8. define the maintenance/dual-read window and rollback owner.

Credentials or production access are never assumed by an implementation task.

## 4. Additive schema phases

### M0 — local Supabase baseline

- Track `supabase/config.toml`, complete prerequisite migrations and deterministic
  non-secret development seed.
- Prove `supabase db reset` and `supabase test db` from a clean checkout.
- Do not expose new routes.

### M1 — identity and projects

- Add profiles/capabilities, projects/scopes and historical memberships.
- Retain legacy AppUser ID as a unique migration key.
- Copy project IDs/references unchanged where valid.
- Always create one explicit Common scope without reinterpreting a physical
  building.
- Preserve `authorityRef` in its own legacy/canonical field.

Legacy role handling:

- canonical known claims map exactly;
- new trusted audit rows retain the exact current Auth role alongside the
  normalized workflow role; historical rows remain unmodified when that exact
  value was not captured;
- legacy `engineer` creates a reconciliation row with no Project Engineer
  approval privilege;
- current assigned/design-engineer fields become suggested membership evidence;
- an approved mapping file creates dated memberships and claim updates through
  server administration;
- unmapped users remain blocked from privileged V1 actions.

### M2 — BOQ

- Create ordered groups/columns/rows for new V1 projects transactionally.
- R38 adds `boq_groups.scope_id`; the 23 August 2026 product revision now
  materialises only Workshop Materials for every newly created Common/building
  scope. It never creates an `Overview` scope. The prior 29 template records
  remain inactive historical definitions, and populated legacy folders remain
  visible without cloning or deleting their contents.
- The 8 August folder-structure correction additively materialises each active
  custom folder name as an empty sibling group in Common and every active
  building, and seeds those names into future scopes. Existing groups and all
  child rows/columns remain untouched; rollback disables the replacement
  creation/seed function but does not delete the additive empty shells.
- Existing project-level groups remain `scope_id = null`, are visible only in
  the Overview summary as legacy/unassigned, and require an explicit audited,
  version-checked mapping to one active real scope. Do not copy, infer or
  reinterpret rows. Mapping is blocked where submitted/differently-scoped MR
  history would become ambiguous. An explicit default-folder mapping may only
  supersede an empty generated placeholder; a populated/document-linked target
  is rejected rather than merged or discarded.
- Preserve old V7 Phase 1 plan tables as read-only historical records.
- Offer a reviewed import tool that maps a selected historical plan/version to
  a BOQ draft with provenance; do not auto-convert it.
- Store raw imported headings/values alongside canonical mappings.

### M3 — Material Requests

- New submissions use normalized V1 tables only.
- Phase 3 additively seeds published configuration values for creator
  self-approval and external-source readiness, adds nullable readiness evidence
  to arrangement lines, and adds request/line replacement provenance. Existing
  requests and arrangements retain their values and state.
- Replacement recovery is forward-only evidence: rollback hides/revokes the
  new command and republishes the adoption defaults. Never drop provenance or
  readiness columns after production evidence exists, and never reopen or
  delete a cancelled source.
- Existing legacy requests are inventoried and copied to a migration staging
  relation with raw JSON, source ID and source status.
- Only unambiguous records may be transformed to a V1 historical projection.
- Ambiguous status, scope, quantities or actors remain quarantined/read-only
  with a reconciliation reason.
- Never make a legacy draft visible to Procurement merely because it was in a
  shared collection.

### M4 — inventory and logistics

- Reconcile each inventory item identity/unit and capture a signed opening
  balance at a declared cutoff time.
- Preserve existing movement history as legacy ledger entries with provenance;
  do not invent transaction links.
- After cutoff, only V1 trusted commands write normalized reservations,
  movements, dispatches, reviews, DOs and returns.
- Reconcile on-hand as opening balance plus normalized movements; report every
  difference before enabling logistics.
- R38.9 supplier provenance is additive: preserve raw supplier text, workbook
  fingerprint, source sheet/row and every mapping/quarantine decision. Missing
  supplier identity resolves to the protected Unknown Supplier record; it does
  not authorize inventing aliases or external receipt evidence.
- The pack's 1,240-row Opening Balance workbook and the separately supplied
  1,154-row ready/reconciled workbook are alternative migration candidates.
  Never import both. Reconcile `source = committed + quarantine/exclusions`,
  verify no fingerprint or opening-balance command has already committed, and
  rehearse against a staging snapshot before any production stock command.
- Receipt-reviewed Delivery Report support is additive: existing Delivery Order
  revisions are classified as immutable `dispatch` evidence, and no historical
  review is silently converted. A current receipt-reviewed report is created
  only by the trusted receipt-confirmation command or a later explicit document
  generation. Rollback leaves appended revisions intact and returns the UI to
  the preserved dispatch snapshot rather than copying protected facts back.
- Delivery Report Size/Model enrichment is additive and quantity-neutral.
  Existing revision lines are linked deterministically through their immutable
  dispatch line to the submitted MR technical attributes; no inventory master
  data is consulted. Rows without trustworthy legacy metadata retain null and
  render an explicit missing Size instead of fabricating a value. Rollback may
  stop projecting the two nullable columns, but must not delete revision lines,
  dispatch links, quantities or audit history.

### M5 — documents and audit

- Retain metadata-only attachments and broken/missing object references in a
  reconciliation report.
- Migrate verifiable objects into versioned document records with hash, size,
  mime and classification.
- Do not fabricate uploader/time when absent; preserve Unknown/Legacy provenance.
- Server audit begins at V1 command activation. Client activity remains clearly
  labeled historical collaboration, not reclassified as trusted audit.

### M6 — scoped capability management

- Add the protected capability catalogue, immutable role defaults, current
  organization/project assignments, normalized project scopes, target revision
  and append-only change history without modifying roles or memberships.
- Seed defaults to reproduce the effective role access in force before the
  migration. Keep existing `v1_user_capabilities` commercial overrides and
  their protected consumers unchanged; the new projection reports them without
  deleting, copying or changing their meaning.
- Keep all workflow RPC/RLS consumers on their prior checks while the new
  resolver runs in shadow mode. Record a role/user/capability parity report and
  block consumer cutover on every unexplained difference.
- Accept stable application user IDs at the administration boundary. Resolve
  the private Auth UUID through protected server data only; never expose it as
  a client-selectable target or infer it locally.
- Rollback disables each new consumer and management route but retains the
  catalogue, assignments, revisions and history. Never drop an assignment that
  was created after management activation or rewrite it into a role.
- The additive implementation is split into three ordered migrations:
  `20260824075503_scoped_capability_management.sql` creates the shadow resolver,
  assignments, revision signal and administration contract;
  `20260824084245_scoped_capability_core_workflow_cutover.sql` enables only the
  tested project/material workflow consumers; and
  `20260824091000_scoped_capability_user_administration_cutover.sql` enables the
  action-specific User Management and permission-administration consumers only
  after installing a versioned capability-aware Auth audit trigger. That same
  transaction adds resumable HMAC-bound V1 provisioning, server-owned singular
  role/compatibility claims, target hierarchy and action-specific durable
  audit checks.
  A rollback is a corrective forward migration that returns only affected
  catalogue rows to `shadow`; it does not drop the new data or audit evidence.

### M7 — R39 Accounts phased foundation

The approved 25 August 2026 Accounts rollout is separate from the completed R35
chain and begins default-off.

- T01 additively extends every centralized exact-role constraint, Auth/audit
  validation, seed persona and test fixture with `accountant`. Accountant is a
  platform role only; no technical `project_members` row is created or
  backfilled (FR-016 and FR-017).
- Add the 15 exact Accounts catalogue keys defined in
  [`R39_ACCOUNTS_FOUNDATION.md`](R39_ACCOUNTS_FOUNDATION.md) as `shadow` and
  nonassignable. Seeded templates must preserve all eight existing operational
  role decisions and grant no technical authority to Accountant
  (NFR-MAINT-004).
- Add only normalized, protected, empty Accounts foundation relations/types,
  explicit foreign keys, RLS deny-by-default policies and server-owned default
  stage policy required by T01. Do not copy, reinterpret or dual-write legacy
  Finance records (FR-002 and FR-003).
- Seed the protected forward defaults: 90 payment-term days, 10 reminder-lead
  days and stage-template rows Design 10%, Material Supply 50%, Installation
  30%, Commissioning & Handover 5%, Energizing 5%. T01 enforces that the
  protected stage template totals 100% within explicit numeric tolerance
  (FR-029).
- Record the binding FR-030/FR-031 policy in T01: future physical building
  allocations must total 100% within explicit numeric tolerance and
  Common / All Buildings is non-physical. T01 creates no project
  physical-building allocation relation or row-level allocation constraint.
- Add `YORKS_V1_ACCOUNTS` default-off wiring. During T01 there is no normalized
  route, action, command cutover or Accounts value projection. Legacy
  `/admin/finance` remains non-authoritative and is never a fallback (FR-014).

T02 adds the commercial baseline, project physical-building allocation
relations, 100% row-level/server command enforcement, Common exclusion and
Billing Progress. T03–T04 add the receivable and supplier-bill consumers in
bounded additive migrations. T05 enables normalized routes/UI only behind the
flag and server projection. T06 adds shared Documents/Audit/Notifications and
exports without parallel subsystems. T07 supplies the complete security,
performance, responsive, staging and release evidence before production
enablement.

### M7.1 — T02 baseline and Billing Progress migration order

T02 is an additive server slice and follows this order in one versioned
migration plus pgTAP gate:

1. Verify the T01 exact nine-role/15-capability catalogue, protected 90/10
   settings and 10/50/30/5/5 stage template. Abort on drift; do not repair it
   from application hydration.
2. Create protected normalized
   `v1_accounts_project_commercial_profiles`,
   `v1_accounts_baseline_revisions`,
   `v1_accounts_baseline_building_allocations`,
   `v1_accounts_baseline_stage_allocations`,
   `v1_accounts_billing_progress` and
   `v1_accounts_billing_progress_revisions` with explicit foreign keys,
   checks, current-row uniqueness and append-only history guards.
3. Enable RLS before any grant. Revoke direct authenticated write access;
   service/definer functions receive only the required relation privileges.
   Protected views/functions use an empty fixed `search_path`, derive
   `auth.uid()`, re-check live exact role and active profile, and are explicitly
   revoked from `public`/`anon` before narrow authenticated execute grants.
4. Install deferred constraints/command validation for positive fixed-numeric
   contract value, explicit validated VAT snapshot, terms/reminder bounds,
   physical-building and stage totals of 100.0000 within 0.00005, Common
   exclusion, 0–100 progress and one current Building × Stage row. No default
   VAT is seeded; Rentals' 5% is unrelated.
5. Install the T02 commands and role-safe projections listed in
   [`STATE_RPC_RLS_MATRIX.md`](STATE_RPC_RLS_MATRIX.md), including deterministic
   row-lock order, expected versions, payload-hash idempotency and same-
   transaction audit.
6. Promote only `view_project_accounts`,
   `view_project_commercial_values`, `suggest_billing_progress`,
   `confirm_billing_progress`, `configure_project_commercials` and
   `review_commercial_progress` to their tested T02 runtime consumers. Remove
   the T01 catalogue dependency that made value visibility a prerequisite for
   `confirm_billing_progress`; FR-059 requires confirmation authority and
   monetary response shape to remain separate.
7. Leave every T03/T04/T06 capability and consumer shadow. Keep
   `YORKS_V1_ACCOUNTS` off, add no route, and run clean-reset, positive,
   negative, concurrency and response-shape tests before accepting the server
   slice.

The migration creates no demo money, baseline or progress record and does not
backfill legacy Finance. An authorized initialize command creates baseline
revision 1 only when a real project is explicitly configured. Management
review is stored disabled/null until configured; no implicit amount threshold,
quorum or expiry is migrated. Existing protected project document references
may be validated as T02 evidence, but Accounts document upload/link UI and
exports are not introduced.

T02 prepares forward-compatible claim-consumption and claim-draft-staleness
seams without a claim relation or command. They return no consumed amount while
T03 is absent, and no Prepare Claim action is reachable. T03 must replace those
seams atomically and complete FR-035/037/051/052,
AT-BL-006/007, AT-PROG-006/007 and AT-CONC-005 against real immutable claim
rows. T05 later installs routes/UI; T06 later installs Accounts upload,
print/export/report consumers.

T02 rollback is forward-only:

- disable `YORKS_V1_ACCOUNTS` (it should already be off) and revoke/return the
  six T02 catalogue consumers to `shadow`;
- redeploy the prior accepted server consumer while retaining every baseline,
  allocation, progress revision and audit row;
- never drop or rewrite a historical revision, collapse it into legacy
  Finance, or delete an idempotency result; and
- if a defect affects calculations, block new T02 commands, retain reads only
  where the response shape is proven safe, and ship a corrective migration
  that appends/recomputes a new revision rather than mutating evidence.

### M7.2 — T03 claims and receivables migration order

T03 is one additive migration after T01/T02 and follows this order:

1. Verify the five T03 capability catalogue rows are still shadow and that the
   T02 baseline/progress relations and protected seams have their accepted
   shape. Abort on drift.
2. Create empty protected claim/line, invoice, certification, payment, PDC and
   PDC-event relations with exact state checks, project/root correlations,
   uniqueness/indexes and append-only guards. Do not import or dual-write
   legacy Finance.
3. Enable RLS before grants, revoke direct public/anon/authenticated writes and
   install fixed-search-path trusted helpers/commands. All mutations derive
   live actor/role/scope, lock deterministic roots, validate expected versions,
   use request-hash idempotency and append audit atomically.
4. Replace the T02 claim-consumption and stale-draft functions. Existing T02
   rows remain unchanged; future claims retain immutable references to their
   original baseline and progress revisions.
5. Install role-safe claims/receivables projections and promote only
   `prepare_client_claim`, `manage_client_invoices`,
   `record_client_certification`, `record_client_payment` and `manage_pdc`
   after clean reset, pgTAP and concurrency proof.
6. Keep `YORKS_V1_ACCOUNTS` off and add no production route. T05/T06 remain
   responsible for UI, documents, notifications, exports and reports.

T03 rollback is forward-only: return the five T03 consumers to `shadow`, keep
the feature flag off and deploy a corrective migration. Never delete a claim,
invoice, certification, payment, PDC, event, snapshot, audit or idempotency
fact, and never reinterpret it as a legacy Finance row.

### M7.3 — T04 supplier-bill migration order

T04 is one additive migration after T01–T03 and follows this order:

1. Verify the three T04 capability rows are still shadow and that trusted
   documents, dispatches and confirmed receipt reviews have their accepted
   shape. Abort on drift.
2. Create empty protected supplier-bill and supplier-payment relations with
   exact states, fixed-precision values, project/root correlations,
   case-insensitive reference uniqueness and append-only payment guards. Do
   not backfill or dual-write legacy Finance.
3. Enable RLS before grants, revoke direct public/anon/authenticated writes and
   install fixed-search-path trusted helpers/commands. Match state derives
   from controlled documents and confirmed operational receipt facts; no
   caller-provided accepted quantity is trusted.
4. Install versioned, request-hash idempotent create/update/approve/pay/reverse/
   cancel commands and role-safe get/list projections. Every command checks
   live exact role, capability and scope, locks deterministic roots and appends
   audit in the same transaction.
5. Promote only `manage_supplier_bills`,
   `approve_supplier_bill_payment` and `view_supplier_costs` after clean reset,
   pgTAP and Flutter boundary proof. Keep all T05/T06 consumers absent.
6. Preserve action-only User Management target administration by excluding
   inherent Accounts defaults from reset/activation hierarchy checks, and add
   an earlier strict Auth guard that still enforces the full Accounts-aware
   template for role-bearing creation/change commands.
7. Keep `YORKS_V1_ACCOUNTS` off and preserve the operational chain unchanged.

T04 rollback is forward-only: return those three consumers to `shadow`, revoke
authenticated execution of the exact T04 commands/projections and deploy a
corrective migration. Never delete a supplier bill, payment, reversal,
document link, operational receipt, audit event or idempotency result, and
never reinterpret one as a legacy Finance row.

Rollback is a forward corrective migration that disables
`YORKS_V1_ACCOUNTS`, returns affected Accounts catalogue rows to `shadow` and
redeploys the prior accepted consumer. It never deletes Accounts rows,
snapshots, documents, revisions, payments or audit evidence. This satisfies
NFR-MAINT-003.

### M7.4 — T05-T07 application, evidence and release controls

- T05 adds only flag/capability-guarded normalized routes and Flutter
  projections; it does not migrate or backfill legacy Finance.
- T06 reuses the protected document/audit/notification relations, adds
  Accounts classification metadata/links and structured report projections,
  then promotes only `export_accounts_registers` after its access tests pass.
- T07 adds private operational metric/job-run relations, supporting indexes,
  a service-only idempotent reminder runner and admin-only readiness/health
  projections. It does not enable `YORKS_V1_ACCOUNTS`.
- First response to a release defect is an application deployment with the
  flag off. A reviewed corrective forward migration may then apply
  `supabase/snippets/r39_accounts_t05_t07_forward_disable.sql`; T02-T04 command
  defects additionally use the existing T01-T04 artifact.
- Rollback never drops Accounts relations or objects and never edits an
  applied migration. Compare protected business/document/audit/metric/job row
  counts before and after; any discrepancy stops the rollout.
- Re-enable only through another tested forward migration and a separate
  flag-on application release after five-persona same-commit staging UAT.

## 5. Quarantine contract

Use a protected migration issue/reconciliation relation or immutable report
containing:

- source collection/table and stable source ID;
- raw payload hash and retained raw payload/object reference;
- issue type and field path;
- proposed mapping, if any;
- resolution status, resolver, reason and server time;
- resulting V1 ID when resolved.

Examples requiring quarantine:

- unknown user role or no Auth UUID;
- duplicate project reference/building code;
- undecodable JSON or unknown enum;
- missing scope/project/material identity;
- combined model/serial with no reliable classification;
- commercial value found in an operational payload;
- request quantity/state inconsistency;
- inventory balance that cannot reconcile to known movements;
- attachment metadata without a verifiable object.

The migration fails its acceptance gate if any source row disappears from both
the target and the reconciliation report.

## 6. Verification and reconciliation

Each migration records before/after counts by entity and status, plus:

- stable ID/reference preservation;
- actor/timestamp null/unknown counts;
- scope and membership mapping counts;
- commercial-field leakage scan;
- BOQ raw/canonical mapping completeness;
- requested/arranged/approved/dispatch/receipt quantity checks;
- inventory opening/current balance reconciliation;
- object count/hash verification;
- quarantine count and categorized reasons.

Positive and negative RLS tests run against representative Project Engineer,
Site Engineer, Procurement, Accountant and Admin identities after every
relevant Accounts phase. T01 additionally proves that existing eight-role
operational decisions remain unchanged, Accountant cannot mutate
BOQ/MR/Dispatch, inactive Accountant stale tokens fail closed and unknown roles
gain nothing (AT-SEC-003, AT-SEC-006 and AT-SEC-007).

## 7. Application rollout

The numbered feature-flag sequence below is **historical implementation
evidence**, not a current production release procedure. The accepted R35
release is complete-R35-only: staging and production receive the whole Yorks
chain, and the previous approved complete build is the rollback artifact.

1. Deploy additive schema/RLS/RPC to an isolated staging project.
2. Backfill/reconcile a non-production snapshot and run the full database,
   RLS, document and operational witness suite.
3. Deploy the complete R35 app/function build to a named pilot group only after
   staging acceptance and signed opening-stock/reconciliation evidence.
4. Retain legacy data read-only during the agreed validation window without
   dual-writing critical stock or workflow state from two authorities.

The individual flags remain test/development controls only. They are not a
production partial-rollout or rollback mechanism.

R39 Accounts is the documented exception to that completed-R35 statement while
its new phases are in progress. `YORKS_V1_ACCOUNTS` remains independently off
through T01–T04, may be enabled only in controlled staging for T05–T07 evidence,
and reaches production only after the complete R39 acceptance gate. Disabling
it removes normalized Accounts navigation/routes/actions but does not make
legacy `/admin/finance` authoritative.

## 8. Rollback strategy

Schema migrations are additive; the complete-R35 rollback normally means:

- stop new traffic/deployment at a documented cutoff and redeploy the prior
  approved complete-R35 app/function build;
- preserve every committed V1 record and audit event;
- return users to the last safe read/write authority only if doing so cannot
  create conflicting stock/workflow writes;
- use the pre-migration backup for disaster recovery, not routine feature
  rollback.

Never roll back by dropping V1 tables that contain committed activity or by
copying stale legacy snapshots over normalized state.

If logistics has accepted a V1 command, legacy stock write paths remain
disabled after a build rollback. Operators use an audited correction or a
controlled server runbook.

If Accounts has accepted a later-phase command, rollback disables new Accounts
traffic and restores the prior accepted Accounts consumer/flag state while
retaining every committed commercial fact. It never converts normalized
Accounts data into legacy Finance rows or resumes an obsolete mutation path.

R38.3 smart-warehouse rollout is additive. Existing items stay uncategorized
until Procurement/Admin confirms a mapping; no historical balance, reservation
or movement is rewritten. Rollback revokes the new category/import RPC grants
and redeploys the prior complete build while retaining category, alias, import
batch and import-row audit records. Any committed imported quantity is reversed
only by an authorized compensating stock movement, never by deleting the batch
or copying an older balance.

R38.9 supplier-folder rollback follows the same rule. Revoke the new
supplier/import RPC grants and redeploy the prior approved build while retaining
all supplier, alias, receipt-batch, receipt-line, document-link, import-result
and audit rows. Never delete a receipt batch to change stock; use an authorized
compensating movement and retain the original provenance.

Migration `20260809174308_yorks_v1_inventory_category_families_commands.sql`
adds one nullable parent-family link plus size/model metadata and a separate
metadata version. It preserves every inventory, balance, reservation, movement
and import ID. Only the four known seeded Air Terminal children are renamed and
parented by exact stable ID; this deterministic correction is repeatable and no
historical item is inferred or fuzzily reclassified. The migration also adds
the standard `pg_trgm` extension for advisory category ranking and keeps every
write behind role-checked, idempotent trusted commands. A build rollback must
revoke the new suggestion/create-item/stock-adjust grants and redeploy the prior
client while retaining committed categories, aliases, item metadata and stock
movements. Physical quantity is corrected only by an authorized compensating
movement.

Migration `20260810214737_yorks_v1_optional_arrangement_inventory_category_and_mr_progress.sql`
temporarily permits an inventory item created during arrangement reconciliation
to retain a null category, while preserving the same trusted create command and
all stock invariants. It also adds read-only MR dispatch-progress projections;
it does not rewrite requested, approved, dispatched or received quantities. A
rollback retains any truthfully uncategorized item and its movement history;
operators may classify it later through the audited metadata workflow, never by
deleting or recreating the item.

Migration `20260811062730_yorks_v1_material_workflow_production_hardening.sql`
is additive and preserves every request, arrangement, reservation, dispatch,
receipt, document, notification and audit row. It replaces trusted function
definitions in place to enforce protected commercial response shapes and
writes, correctly closes all-unavailable approvals, and adds an idempotent
received-request close command. Re-running is anchor-checked and fails before
mutation if the expected deployed definitions have drifted. Rollback redeploys
the prior complete client and revokes the new close-command grant; it retains
all committed closures and audit evidence. A closure is corrected only through
an authorized, audited forward migration or command, never by deleting history.

Migration `20260812082422_yorks_v1_optional_external_supplier.sql` replaces
only the trusted `v1_save_arrangement` function definition so a Full External
Supplier line may omit the supplier-name context. It changes no table, row,
reservation, quantity, version, idempotency key or audit record, and it retains
the required reason for Partial and Cannot Provide Now decisions. The migration
is anchor-checked and repeatable; it fails before mutation if the deployed
function has drifted. Rollback restores the prior trusted function definition
and redeploys the prior client. Existing arrangements with a null supplier name
remain truthful history and must not be fabricated or destructively rewritten.

Migration `20260814090919_yorks_r38_configuration_centre.sql` is additive. It
introduces an exact-Admin configuration catalogue, one server-versioned shared
draft, normalized controlled units, staged category/unit actions and immutable
publication/change history. It seeds missing defaults with `ON CONFLICT DO
NOTHING`; it does not replace an existing value, project, BOQ, request,
inventory quantity, document or audit record. Draft changes are inert until
`v1_publish_configuration` validates and commits them in one transaction.
Category and unit retirement changes only future selection (`is_active`); all
historical references remain intact. Re-running is deterministic because
stable seed IDs/keys conflict safely and every command requires an idempotency
key plus the current draft revision.

Rollback revokes the eight public configuration RPC grants and redeploys the
prior client while retaining all settings, drafts, master actions,
publications, publication changes and audit evidence. A published mistake is
corrected by a later audited publication. Never delete or update immutable
publication history, reactivate/archive master data by direct table write, or
copy a stale configuration snapshot over newer operational facts.

Migration `20260814114626_yorks_r38_5_team_chat.sql` is additive. It introduces
normalized conversation, membership, append-only message, mention,
acknowledgement, pin, upload-intent and attachment relations; a private
`yorks-chat-attachments` bucket; trusted member-scoped RPCs; Realtime refresh
publication; and Team Chat notification projections. Existing Project and
Material Request discussion history is retained. The compatibility comment
RPC now writes the one canonical MR Team Chat stream while preserving the
existing immutable comment identifiers/read projection for older clients.
Workflow audit facts create best-effort system messages and are guarded so a
chat projection failure can never abort the source workflow command.

Direct conversations have a canonical unordered participant key and remain
exactly two-person. Project/MR conversations use one canonical context key,
derive participants from current server authority and re-check that contextual
access at every read/send/download boundary. Message retries retain a unique
idempotency key and payload hash. Attachment objects remain private and inert
until the authenticated caller obtains a short-lived actor-scoped intent, the
`finalize-chat-attachment` Edge Function verifies object byte count, content
type and SHA-256 with service authority, and the send RPC atomically binds the
verified object to an append-only message.

Rollback revokes the Team Chat RPC grants, disables `YORKS_R38_TEAM_CHAT` in a
replacement complete build and redeploys the prior client/functions. Retain
all conversations, members, messages, notification cursors, upload intents,
attachments and audit facts. Do not drop the private bucket or rewrite MR
comments after users have created chat activity. Unbound expired upload objects
may be removed only through a separately reviewed retention job; bound message
attachments are retained under the document/audit policy. Re-enabling the same
migration/build resumes from the preserved authoritative state without local
unread reconstruction.

Migration `20260814153746_separate_team_chat_notification_surface.sql` is an
additive presentation/command-boundary correction. It preserves Chat
notification and outbox rows for idempotent push delivery, but excludes those
transport rows from `v1_list_my_notifications` and workflow **Mark all read**.
All new Chat mentions, including contextual MR Chat, identify their exact
`chat_message`; preserved legacy `material_request_mentioned` history keeps its
original workflow event and request route. Chat read advances
the authoritative membership cursor and acknowledges only the matching hidden
transport rows. Rollback restores the prior function definitions and drops the
classifier only; no notification, outbox, cursor or audit row is rewritten or
deleted.

Migration `20260814200329_expand_global_engineering_roles_and_sme_inventory_read.sql`
is additive and quantity-neutral. It adds Workshop In-Charge and Document
Controller as exact audit roles normalized to the existing organization-wide
Project Engineer authority, expands only the exact-role constraints, and adds
a separate inventory-read predicate for Senior Mechanical Engineer. Existing
profiles retain the canonical Project Engineer mirror; no synthetic project
membership, workflow row, stock, reservation, movement, document or audit event
is rewritten. Assigning either new exact role is performed only through the
audited `admin-users` command after the complete compatible client, Edge
Function and schema are deployed together. Rollback first restores affected
users to a supported exact role through the same audited command, then
redeploys the prior complete build/functions. The expanded constraints and
historical exact-role evidence remain in place; never erase or relabel audit or
controlled-document history.

Migration `20260820233221_yorks_v1_material_request_phase2_collaboration.sql`
is additive and quantity-neutral. It adds owner-private draft recovery,
versioned coordination assignments, immutable Engineering revision snapshots,
lightweight server-paged request summaries, cursor-paged comments and
server-derived change summaries. It does not alter the Material Request state
machine, request quantities, reservations, approvals, dispatches, receipts or
returns. Direct table access is revoked; trusted functions re-check the actor,
request/project visibility, version and idempotency identity. Existing requests
are backfilled only with immutable revision evidence derived from their current
stored Engineering facts.

Rollback first deploys the prior client, then revokes the Phase 2 RPC grants in
a corrective migration. Retain private recovery rows, assignment/audit history
and revision snapshots so a later compatible client can resume safely. Do not
drop or rewrite Phase 2 history, and do not copy a private draft into a submitted
request outside the normal versioned submit command.

## 8H. Workforce T01 foundation

Migration `20260829225746_yorks_workforce_t01_foundation.sql` is additive and
route-less. It adds private worker, trade, internal-location, team, effective
assignment and responsibility relations plus exact-Admin protected RPCs. It
does not copy, reinterpret or dual-write legacy employee/attendance JSON and
does not create Auth users, technical project memberships or attendance facts.
Effective assignments fail closed against finite worker/team windows and
non-active projects. Worker employment-date edits are rejected when they would
make retained assignment history invalid, and team-window edits use the same
rule; the history is never silently trimmed, deleted or reinterpreted.

The rollback is to keep `YORKS_V1_WORKFORCE=false`, revoke authenticated RPC
execution if required and retain all normalized, idempotency and audit rows. A
correction ships forward; no Workforce relation or history is dropped.

## 8I. Workforce T02 calendars and shifts

Migration `20260830021205_yorks_workforce_t02_calendars_shifts.sql` is additive
after accepted T01. It adds effective calendars, seven-row ISO weekday sets,
dated calendar exceptions, reusable effective shifts and non-overlapping dated
team schedule defaults. It does not alter the T01 migration, copy legacy data,
create attendance/timesheet rows, enable a capability consumer or add a route.

All new relations use RLS with authenticated direct CRUD revoked and
service-role-only table access. Exact Admin commands own optimistic versions,
idempotency and audit. Calendar/shift/team date changes fail when they would
invalidate retained exceptions or team links; rollback never trims those rows.

Correction migration
`20260830042048_yorks_workforce_t02_retained_version_semantics.sql` is additive
after the initial T02 migration. It freezes semantic fields on referenced
calendar/shift versions and weekdays, freezes effective team links and
past/current dated overrides, preserves future unused optimistic drafts, and
permits inactive retirement only when no current/future use is stranded. It
adds guard-supporting indexes and table-trigger enforcement but no relation,
public RPC, capability consumer, route, flag change or operational fact.

Follow-up correction migration
`20260830044311_yorks_workforce_t02_calendar_local_history_guards.sql` replaces
only the four temporal guard functions. It makes past/current override
`is_active` immutable and evaluates override, team-link and parent-retirement
boundaries from `clock_timestamp()` in each exact referenced calendar IANA
timezone. It adds no public function, table, capability, route, flag or fact;
rollback remains a forward correction with all retained rows preserved.

T02 rollback is forward-only: keep `YORKS_V1_WORKFORCE=false`, revoke the five
T02 public RPC grants if required, retain every configuration, idempotency and
audit row, and ship a corrective migration. Do not drop the five relations,
reuse a code across overlapping dates, hard-delete history or reinterpret an
existing team default.

## 8J. Workforce T03 daily attendance

T03 is one additive migration after the accepted T01/T02 chain. It first
creates the private daily-attendance relation, worker/date and scoped-read
indexes, RLS/ACL/hard-delete boundaries and exact retained snapshot columns.
It then installs internal assignment/schedule/responsibility resolution,
schema-v1 scoped projection and the versioned/idempotent save command. Only
after those objects exist does it promote `workforce.view` and
`workforce.attendance.maintain` to operational, enforced and assignable. The
other ten Workforce capabilities stay planned/shadow/nonassignable.

No legacy employee or attendance collection is copied, reinterpreted or dual-
written. Existing T01/T02 rows are not rewritten. The first committed daily
row stores exact assignment, authority and schedule semantics, so later parent
changes do not alter historical attendance meaning. Corrections update only
status, minutes, reason, version and actor/timestamp, with before/after audit.

T03 rollback is forward-only: keep `YORKS_V1_WORKFORCE=false`, revoke the two
T03 public RPC grants if required, return the two capability consumers to
planned/shadow/nonassignable, and retain every attendance, audit and
idempotency row. Do not drop the relation, delete a day or rebase a retained
snapshot. No route, UI, allocation, timesheet, remote migration or deployment
is part of this phase.

The 30 August 2026 future-attendance resolution ships as a later additive T03
corrective migration. A table-boundary guard rejects inserts and corrections
whose work date is later than `clock_timestamp()` in the row's exact retained
calendar timezone. It copies, deletes and backfills nothing. Existing future
rows remain readable but read-only until their calendar-local date arrives.
Rollback is also forward-only: keep the rows and deploy a new corrective
migration if policy changes; never remove the guard by rewriting the accepted
T03 migration or purge future evidence.

## 8K. Workforce T04 daily timesheet allocations

T04 is one additive migration after accepted T01-T03. It creates a private
one-per-attendance allocation-set root, immutable revision headers and
immutable allocation rows, followed by RLS/ACL/trigger guards, strict
schema-v1 read/save/withdraw RPCs and indexes. The migration installs a
table-boundary trigger that rejects T03 attendance semantic changes while an
active allocation revision exists, and promotes only
`workforce.timesheets.maintain` to operational/enforced/assignable.

No T01-T03 row or legacy collection is copied, rewritten or dual-written. The
first save appends target snapshots and an active revision; later saves append
new revisions and move only the root's current pointer/version. Withdrawal is
also an immutable revision and does not change the attendance fact.

Rollback is forward-only: keep `YORKS_V1_WORKFORCE=false`, revoke the three T04
public RPC grants if required, return only `workforce.timesheets.maintain` to
planned/shadow/nonassignable, retain every root/revision/row/audit/idempotency
fact and deploy a corrective migration. Never drop or update history, remove
the attendance child guard while an active set exists, infer target identity,
or migrate remotely in T04. No route/UI or deployment belongs to this phase.

## 8L. Workforce T05 supervisor daily roster backend

Migration `20260830101500_yorks_workforce_t05_supervisor_daily_roster.sql` is
additive after the accepted T01-T04 chain and the later T03 future-date guard.
It adds nullable `overtime_reason` evidence to retained attendance rows,
installs normalization/history guards, installs a revision-boundary future-date
guard shared by both T04 save and withdraw, and adds the schema-v1 roster read
and atomic save RPCs. It promotes no capability, rewrites no existing row,
backfills no legacy collection and creates no attendance/allocation fact on
read.

Corrective migration
`20260830111341_fix_workforce_t05_roster_authority_aggregation_bounds.sql`
replaces only the T05 roster projection/helper/save definitions. It separates
view-derived filter selectors from exact dated allocation command targets,
makes mixed-calendar `is_future` an all-returned-page aggregate, prevents active
hidden targets from advertising mutation authority, echoes the page context and
aligns read/save limits at 500. It rewrites no retained row and promotes no
capability.

The roster save reuses T03/T04 worker/date locks, optimistic row versions,
idempotency and audit. `replace` and `withdraw` always require an exact visible
allocation-set version. A restricted evidence-only `preserve` may omit the
hidden allocation version, but may not change locked totals or expose any set
identifier/version/state in its response. Optional overtime evidence is not a
pay, threshold or approval rule, and the prior T03 payload remains compatible.

Rollback is forward-only: keep `YORKS_V1_WORKFORCE=false`, revoke authenticated
execution on `v1_get_workforce_daily_roster` and
`v1_save_workforce_daily_roster`, retain the nullable evidence column and every
attendance/allocation/audit/idempotency row, and ship a corrective migration.
Do not drop the T04 future-revision guard, delete a roster child fact, expose a
  restricted allocation identifier, return a current Workforce consumer to
  shadow solely to undo T05, or migrate/deploy remotely as part of this slice.

## 8M. Workforce T06 monthly period and validation

T06 is one additive migration after accepted T01-T05. It creates private
team/month period roots, immutable validation runs, run-scoped worker summaries,
retained worker/date evidence and typed validation issues, followed by RLS/
ACL/hard-delete guards, indexed projection paths and strict schema-v1 get and
validate RPCs. It promotes no capability: `workforce.view` and
`workforce.timesheets.maintain` remain the only read/validation consumers.

Initialization/revalidation inserts a complete new run and advances only the
period current-run pointer/status/version. It copies, deletes, updates or dual-
writes no legacy employee/attendance row and never mutates T01-T05 attendance,
allocation, assignment, calendar or roster facts. Earlier runs and their
worker/date/issue evidence remain readable and immutable. The period projection
derives stale state from a server source fingerprint; it does not rewrite a
prior run when daily evidence changes.

Correction migration
`20260830140235_fix_workforce_t06_historical_monthly_source.sql` is additive
and data-preserving. It replaces the shared monthly source with one canonical
retained/prospective union: accepted T03 dates use their exact worker,
assignment, team, supervisor and schedule snapshots and keep the authoritative
T04 allocation attached; only dates without attendance use the T01 effective-
assignment resolver. It removes current active-state checks from retained
worker/supervisor/target meaning, while prospective current-unresolved rows
continue to fail closed. The correction adds only a private insert-time
structural guard for missing supervisors and retained assignment windows. It
does not update, delete or re-fingerprint a prior run; explicit revalidation
appends a new immutable run.

Follow-up correction migration
`20260830150826_fix_workforce_t06_historical_team_month_applicability.sql` is
function-only and data-preserving. It adds one private team-month applicability
predicate and makes the authorized selector, absent-period read and validation
use it consistently. Current validity overlap, retained T03 team/month evidence
or an existing period preserves reachability; no period or operational fact is
created by the predicate/read, and existing capability/responsibility/target
authorization remains unchanged. The migration is repeatable and neither
updates nor deletes prior period/run/audit/idempotency evidence.

Rollback is forward-only: keep `YORKS_V1_WORKFORCE=false`, revoke authenticated
execution on the T06 public RPCs if required, keep the guarded Monthly route
unreachable, retain every period/run/worker/date/issue/audit/idempotency fact
and ship a corrective migration. Never drop monthly history, synthesize a
submission, downgrade accepted T03/T04 invariants, migrate legacy JSON or
delete a period to undo T06.

## 8N. Workforce T07 review and approval lifecycle

T07 is one additive migration after accepted T01-T06. It widens the protected
monthly status constraint and adds private approval revisions, transitions,
exact edit scopes, reviewer-correction evidence, reopen requests, immutable
approved snapshots and transaction correction contexts. Existing T01-T06
facts are not rewritten, backfilled, submitted or approved. Opening a queue or
lifecycle projection creates no record.

The migration replaces only the trusted T03/T04/T05 write guards needed to
honour submitted, returned, locked and reopened periods; it does not weaken
their attendance, allocation, target, minute, employment, future-date,
idempotency or responsibility invariants. Five review capabilities become
operational/assignable only after the complete migration succeeds; the feature
flag remains default-off.

Rollback is forward-only and preserves all lifecycle evidence:

1. keep `YORKS_V1_WORKFORCE=false` and remove the guarded UI consumer;
2. revoke authenticated execution on the T07 public queue/projection/command
   RPCs;
3. return the five T07 capability consumers to planned/shadow/nonassignable;
4. preserve every approval revision, transition, correction, reopen request,
   snapshot, audit and idempotency result; and
5. correct defects with a new forward migration. Never drop, unlock, rewrite
   or hash-regenerate an approved snapshot or prior revision.

No production migration, legacy backfill, feature enablement, push or
deployment belongs to T07 acceptance.

## 8O. Workforce T08 collaboration, evidence and notifications

T08 is one additive migration after accepted T01-T07. It creates private,
RLS-enabled period/conversation mapping, Workforce document upload/version
metadata and notification delivery/digest ledgers. It additively widens only
the canonical Chat and Documents role/entity allowlists needed for Worker,
Attendance Day and Monthly Period links, then exposes dedicated role-safe
schema-v1 RPCs. Existing messages, documents, notifications, T01-T07 facts and
legacy JSON are neither rewritten nor backfilled.

The T08 prepare boundary resolves canonical Worker/Attendance Day/Monthly
Period identity and validates optional links against the exact retained period
run before creating idempotency, upload-intent, metadata or Storage authority.
Canonical-target authorization governs document reads; secondary retained
links cannot grant access. Daily digest enumeration is bounded at 500 rows per
page but continues until the complete eligible roster is counted. These are
forward-safe command/projection corrections and rewrite no retained evidence.

The canonical controlled-document finalizer remains the only version writer;
the T08 trigger appends Workforce metadata after successful finalization. The
T07 audit bridge adds collaboration system events and delivery ledger rows
without becoming transition authority. New tables revoke all anonymous and
authenticated CRUD, retain service-role administration and block hard delete.

Rollback is forward-only and preserves evidence:

1. keep `YORKS_V1_WORKFORCE=false` and remove the T08 Monthly UI consumer;
2. revoke authenticated execution on the six T08 public RPCs;
3. disable the T08 audit/message/finalization triggers only through a new
   corrective migration if containment is required;
4. retain every conversation/message/receipt, document version/link,
   notification/outbox row, delivery/digest record, audit and idempotency
   result; and
5. never delete or rewrite a T07 transition, controlled document version or
   canonical Chat history to undo T08.

No production migration, legacy backfill, feature enablement, commit, push or
deployment belongs to T08 acceptance.

## 8P. Workforce T09 protected reports and exports

T09 is one additive migration after accepted T01-T08. It adds a private,
RLS-enabled, append-only report-artifact ledger whose immutable schema-v1 JSON
payload identifies the exact source snapshot/current projection, scope,
server-derived totals, actor and generation time. It promotes only
`workforce.reports.export`; no existing attendance, allocation, period,
approval, document or collaboration row is rewritten or backfilled.

Monthly final artifacts reference an immutable T07 approved snapshot and copy
its snapshot ID/revision/hash into the retained report identity. Current daily
and exception artifacts retain their source status/fingerprint/version and
must not be relabelled approved. Generation is transactional, request-hash
idempotent and emits one append-only `report_generated` effect. Explicit
artifact/format/action issuance is separately online, request-hash idempotent,
reauthorizes the artifact and emits one `workforce_export_generated` effect
before cached bytes are previewed/downloaded/shared/printed. Tables have RLS, no
authenticated CRUD, service-role administration and hard-delete/update guards.
Final worker/team/project scope is matched to identities retained in the exact
approved payload. Daily future dates and ignored/broadened exception scopes are
rejected at the server boundary; no client scope hint can relabel a source.
Private immutable authority evidence supports reauthorization of report
history after capability/responsibility changes and is never included in the
sanitized report payload, XLSX or PDF.

Rollback is forward-only and preserves evidence:

1. keep `YORKS_V1_WORKFORCE=false` and remove the T09 UI consumer;
2. revoke authenticated execution on T09 projection, generation and issuance
   RPCs;
3. return `workforce.reports.export` to planned/shadow/nonassignable in a new
   corrective migration if containment is required;
4. retain every report payload, approved-snapshot reference, hash, audit and
   idempotency result; and
5. fix generator/projection defects with an additive migration. Never delete,
   regenerate or relabel a previously issued artifact.

No production migration, legacy backfill, feature enablement, commit, push or
deployment belongs to T09 acceptance.

## 8Q. Workforce T10 dashboard projection

T10 is one additive, forward-only function migration after accepted T01-T09.
It creates no data table, legacy copy, daily attendance, allocation, period,
report or export fact. It additively admits the two already-defined typed
validation issue codes used by the read projection but creates no issue row or
policy fact. The public read RPC is granted only to authenticated;
all internal SECURITY DEFINER helpers are revoked from public/anon/
authenticated. Existing RLS and table ACLs remain unchanged.

Rollback is containment without data loss: keep `YORKS_V1_WORKFORCE=false`,
remove/disable the T10 route consumer and revoke authenticated execute on the
T10 read RPC in a new forward migration. Correct formula or response defects
by replacing the function additively. No prior T01-T09 fact, audit,
idempotency, approval snapshot or report artifact is deleted or rewritten.
No production migration, feature enablement, commit, push or deployment
belongs to T10 acceptance.

The corrected projection caches authorized period identities per request,
orders the complete exception queue before applying compact limits, resolves
current project rows from actual assignment/allocation targets, and keeps
retained closed-target history readable. Rollback must not remove the admitted
typed issue codes because retained rows may use them; contain the consumer and
replace the projection functions in a later forward migration instead.

Rollback of the correction is also forward-only. Keep every prior and
corrected run readable, revoke public monthly RPC execution if containment is
required, and ship another additive function correction. Never move retained
attendance into a currently edited assignment/team or reactivate a historical
target merely to satisfy a current-state check.

## 8R. Workforce T11 tablet presentation

T11 has no database migration, backfill, capability promotion, route addition
or persisted data change. It reuses the accepted T05/T07 server projections
and commands. Every T01–T10 table, RLS policy, audit event, idempotency result,
attendance/allocation revision, period snapshot, document and report artifact
is preserved byte-for-byte.

Rollback is presentation-only containment: keep `YORKS_V1_WORKFORCE=false`
and revert the tablet-specific attendance/review composition while retaining
the accepted desktop and phone read-only boundaries. No database rollback is
required or permitted. A future defect in an accepted server boundary must be
fixed by a separately authorized additive migration, never by weakening RLS or
rewriting retained facts. No production migration, feature enablement, commit,
push or deployment belongs to T11 acceptance.

## 8S. Workforce T12 mobile presentation

T12 has no database migration, backfill, capability promotion, route addition
or persisted-data change. It reuses the accepted T05 projection, local-draft
controller and atomic Save Day command. Every T01–T11 relation, RLS policy,
audit event, idempotency result, attendance/allocation revision, approval
snapshot, document and report artifact is preserved byte-for-byte.

Rollback is presentation-only containment: keep `YORKS_V1_WORKFORCE=false`
and restore the prior phone read-only composition while retaining accepted
tablet and desktop behavior. No database rollback is required or permitted.
Any server-authority defect requires a separately authorized additive
migration, never client inference, weakened RLS or rewritten history. No
production migration, feature enablement, commit, push or deployment belongs
to T12 acceptance.

## 8T. Workforce T13 hardening

T13 adds no schema by default. It first audits the accepted T01–T12 migration
chain, relation RLS/ACLs, function execution grants, Storage/document seams,
indexes, immutable guards, concurrency/idempotency and application release
artifacts. Evidence-only tests and local harnesses may be added without
changing retained data meaning.

If the audit reproduces a server defect, the correction must be created with
the Supabase migration command as a new additive, forward-only migration.
Never edit an accepted Workforce migration, backfill or delete retained
history, widen direct authenticated table access, expose an internal helper or
weaken capability/responsibility/target checks. Application-only corrections
must likewise preserve route/capability/state authority and remain behind the
default-off flag.

The local audit reproduced repeated assignment/authorization work in the T10
overview and approval-queue paths. Forward migration
`20260831090940_yorks_workforce_t13_query_performance.sql` therefore replaces
only trusted function definitions: monthly prospective assignment resolution
uses the same deterministic temporary-before-primary order set-wise, T10 team
contexts use one set-wise current-source pass, and organization fast paths are
allowed only when capability and responsibility cover the complete date
window. It creates no relation, changes no grant, backfills no row and rewrites
no retained fact. The migration also replaces the T06 empty-period resolver
and the T07/T10 period-authority definitions separately: no role, including
Admin, bypasses responsibility; complete-month organization windows are the
only organization fast path; partial windows cannot fall through; and retained
assignment/allocation targets keep their exact dated checks. The remaining
guarded definition patches fail closed if accepted source functions do not
match their expected inputs.

Rollback is containment and evidence preservation: keep
`YORKS_V1_WORKFORCE=false`, revoke only a proven defective new consumer through
a later forward migration if required, redeploy the prior accepted client when
separately authorized, and retain every T01–T12 fact, revision, snapshot,
document, notification, audit and idempotency row. T13 performs no production
migration or deployment. At T13 acceptance the T14 staging phase was waived
and recorded as not performed/not passed. The later 31 August 2026
product-owner decision reinstates T14 but does not alter that historical fact.
If the correction must be contained, keep the feature off and use a later
forward migration to restore the accepted T06/T07/T10 function definitions;
do not roll back or delete any T01–T12 history.

## 8U. Workforce T14 staging containment and rollback

T14 may apply the complete tracked ledger through the accepted T13 migration
only to a dedicated non-production Supabase project named/configured by the
release owner. The ignored staging config must contain an explicit staging
project ref, database password, URL and publishable key; the deployment script
must reject the historic shared ref. The web candidate must use that publishable
configuration with `YORKS_V1_WORKFORCE=true` and be deployed only to an
unaliased non-production URL.

Before mutation, record the empty/dedicated target identity, backup/reset
owner, dry-run ledger, candidate source fingerprint and approved named persona
seed plan. Apply migrations forward, verify ledger equality, RLS/RPC grants,
Storage/Edge functions and then create only attributable staging UAT records.
Never copy production service-role credentials into Flutter, Vercel Preview
variables, logs or evidence.

Rollback is staging containment: stop traffic to the preview, keep the live
production flag/alias untouched, retain evidence needed for diagnosis and reset
or discard only the release-owner-approved dedicated staging project. Do not
delete or rewrite production history. A corrected T14 candidate must repeat the
complete applicable ledger and scenario matrix.

Current staging state: release-owner-authorized Frankfurt project
`iqltcyimlqtcwyzlemwx` was created, its empty ledger was dry-run and the full
tracked migration chain through T13 plus `finalize-document-upload` were
applied. Production was not touched by that operation. Named non-production
personas, the unaliased candidate and manual T14 witness remain outstanding.
The product owner explicitly deferred T14 UAT until after an immediate
production-release exception. Keep staging containment and do not treat the
production release as a substitute for the later UAT.

The exception release then aligned production ref `czykuksmlwswjsgotrpo`
through `20260831090940` and promoted verified deployment
`dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g`. Its prior-deployment, source and
forward-migration rollback evidence is recorded in
[`WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md`](WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md).

## 9. Migration stop conditions

Stop before production mutation when:

- a source count cannot reconcile to target plus quarantine;
- a role/membership mapping could grant approval authority without evidence;
- cost data appears in an Engineer-readable payload/view;
- a project/building/material ID collision lacks a deterministic resolution;
- inventory opening balance is disputed;
- an existing status cannot map without changing its business meaning;
- rollback would require overwriting committed newer data;
- backup/restore, required credentials or an operations owner is unavailable.
- adding Accountant would leave an Auth, audit, RLS, route, seed or test
  allowlist inconsistent;
- an Accounts migration would reinterpret legacy Finance data, create
  technical Accountant membership or expose a normalized route while the flag
  is off; or
- the T01 protected default-stage template cannot enforce its 100% invariant;
  or
- the T02 project physical-building allocation relation cannot enforce its
  100% total and Common / All Buildings exclusion without treating Common as a
  physical commercial scope.

## 10. Required notes per migration PR

Every migration PR includes:

- source and target relations/functions;
- additive/destructive classification;
- legacy/default mapping table;
- idempotency/re-run behavior;
- counts and verification queries;
- positive and negative RLS tests;
- complete-build redeploy/rollback procedure;
- known quarantine cases and operator action.
