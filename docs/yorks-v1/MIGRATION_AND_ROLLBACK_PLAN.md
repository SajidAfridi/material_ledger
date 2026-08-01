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
- legacy `engineer` creates a reconciliation row with no Project Engineer
  approval privilege;
- current assigned/design-engineer fields become suggested membership evidence;
- an approved mapping file creates dated memberships and claim updates through
  server administration;
- unmapped users remain blocked from privileged V1 actions.

### M2 — BOQ

- Create ordered groups/columns/rows for new V1 projects transactionally.
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

1. Deploy additive schema/RLS/RPC with all V1 flags off.
2. Backfill/reconcile a non-production snapshot.
3. Enable read-only V1 projections for Admin comparison.
4. Enable Projects, then BOQ, then MR draft/submit for a pilot group.
5. Enable arrangement/approval only after reservation concurrency tests pass.
6. Enable dispatch/receipt only after opening stock is signed off.
7. Enable return/documents after their idempotency/Storage gates pass.
8. Retain the legacy experience read-only during the agreed validation window.

Do not dual-write critical stock/workflow state from two authorities.

## 8. Rollback strategy

Schema migrations are additive; rollback normally means:

- turn off the affected V1 flag/routes;
- stop V1 command grants or deployment at a documented cutoff;
- preserve every committed V1 record and audit event;
- return users to the last safe read/write authority only if doing so cannot
  create conflicting stock/workflow writes;
- use the pre-migration backup for disaster recovery, not routine feature
  rollback.

Never roll back by dropping V1 tables that contain committed activity or by
copying stale legacy snapshots over normalized state.

If logistics has accepted a V1 command, legacy stock write paths remain disabled
even when the UI flag is rolled back. Operators use an audited correction or a
controlled server runbook.

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
- rollback/feature-disable procedure;
- known quarantine cases and operator action.
