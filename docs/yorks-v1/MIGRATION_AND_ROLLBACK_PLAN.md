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
- R38 adds `boq_groups.scope_id` and materialises the frozen 29 folders for
  every newly created Common/building scope. It never creates an `Overview`
  scope.
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
Site Engineer, Procurement and Admin identities after every relevant phase.

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
