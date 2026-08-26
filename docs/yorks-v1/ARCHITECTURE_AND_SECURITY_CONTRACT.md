# Yorks V1 R35 — Architecture and Security Contract

## 1. Runtime architecture

```text
Flutter widget
  -> Riverpod presentation/controller state
    -> feature repository
      -> local draft/cache service (drafts and permitted reads only)
      -> Supabase query/view (authorized reads)
      -> trusted Postgres RPC (critical commands)
        -> locks + constraints + state/version checks
        -> normalized rows + movements + audit + notification
  <- Realtime change signal triggers an authorized re-fetch
```

Widgets contain interaction and rendering only. They do not construct raw
Supabase writes or decide whether a critical transition is valid.

## 2. Reuse versus replacement

Reuse:

- Flutter/Riverpod/GoRouter composition and dependency injection;
- fail-closed Supabase bootstrap and `app_metadata` claim extraction;
- local draft/outbox/retry and Realtime refresh mechanics where permitted;
- design tokens, bilingual widgets, responsive shells and audit/current-action
  presentation;
- material-grid virtualization, keyboard mechanics and focused mobile editor;
- commercial boundary pattern and pgTAP test style;
- legacy JSON decoding and unrelated retained modules.

Replace or isolate:

- generic JSON upsert as an authority for V1 workflow;
- local SharedPreferences inventory reservations/mutations;
- client-side request/dispatch/return state changes;
- three-role route assumptions and unassigned-project visibility;
- client-supplied critical actors/timestamps;
- metadata-only document placeholders;
- old Phase 1/RFQ/PO and legacy Finance/Accounts prototype navigation in the V1
  experience. The later normalized R39 Accounts feature is a separate,
  default-off authority and never reuses `/admin/finance` as its repository or
  command path.

## 3. Normalized domain boundary

The V1 domain is additive and normalized:

- identity: `profiles`, `user_capabilities`
- projects: `projects`, `project_scopes`, `project_members`
- BOQ: `boq_groups(scope_id)`, `boq_columns`, `boq_rows`, optional row
  revisions. `scope_id` references one real active Common/building scope;
  `null` is retained only for pre-R38 reconciliation, never for a new write.
- requests: `material_requests`, `material_request_lines`
- arrangement: `procurement_arrangements`,
  `procurement_arrangement_lines`, `approval_decisions`
- stock: `inventory_items`, `inventory_reservations`,
  `inventory_movements`
- logistics: `dispatches`, `dispatch_lines`, `receipt_reviews`,
  `receipt_review_lines`, `delivery_orders`
- returns: `material_returns`, `material_return_lines`
- documents: `documents`, `document_links`
- operations: `notifications`, `audit_events`, `idempotency_keys`,
  `reference_counters`, `app_settings`
- R39 Accounts (phased/default-off): protected commercial baselines and
  revisions, building/stage allocations, progress evidence/confirmations,
  claims/invoices/certification, append-only payments/PDCs, matched supplier
  bills and linked documents/audit. T01 installs only an additive/shadow
  foundation; T02–T07 add and cut over bounded consumers.

### R39 T02 bounded server authority

T02 adds only the protected profile/baseline/building-allocation/stage-
allocation/current-progress/progress-revision relations and their trusted
RPCs. `YORKS_V1_ACCOUNTS` remains off and Flutter has no normalized Accounts
route until T05. Direct authenticated relation writes are revoked; exposed
relations have RLS, and SECURITY DEFINER functions use an empty fixed
`search_path`, derive `auth.uid()`, re-check the live exact role/profile,
enforce project/building scope and receive only narrow execute grants.

All T02 money/percentage values are PostgreSQL fixed numeric and serialized as
decimal strings. The server calculates Stage Value, Confirmed Eligible,
cumulative eligible and commercial progress. Role-safe projections have two
deliberate schemas: a non-monetary shape with percentages/evidence/owner and no
monetary field keys, and a value shape available only with
`view_project_commercial_values`. Confirmation capability is independent from
value visibility.

Baseline/profile, allocation and current progress rows are locked in stable
project -> baseline -> building -> stage order. Critical commands require
expected version and canonical payload hash. Same idempotency key/hash returns
the first result; a different hash conflicts. Every accepted command appends
revision and trusted audit in the same transaction. Realtime remains only a
refetch signal.

T02 can validate already-authorized project document references as progress
evidence, but does not create an Accounts upload/export subsystem. T03 owns
claim/invoice consumption and stale-claim behavior, T05 owns routes/UI, and T06
owns Accounts document upload/link, print/export and report consumers. A
protected T02 claim-consumption seam is non-actionable while T03 is absent; no
Prepare Claim command or fake claim row is introduced.

Commercial columns use protected relations or protected views. Operational
tables do not embed commercial values into a JSON payload available to all
project members.

## 4. Identity and authorization

Authentication identity is `auth.users.id`. `profiles.auth_user_id` references
it and retains a unique legacy application user ID for migration.

Authorization sources:

1. exact `app_metadata.role` for platform role;
2. protected role-template defaults and active scoped capability assignments;
3. active dated project membership for project-specific operations;
4. record state/source ownership for command eligibility.

Capability assignments are controlled exceptions, not identity. Effective
access is resolved on the server from active identity, hard invariants, the most
specific explicit deny/grant, role-template baseline, project scope and record
state. Existing workflow checks remain authoritative during the shadow-parity
rollout described in
[`SCOPED_CAPABILITY_MANAGEMENT.md`](SCOPED_CAPABILITY_MANAGEMENT.md). A client
may render a server-confirmed snapshot but cannot author or infer authority.

The exact `senior_mechanical_engineer`, `project_manager`,
`workshop_in_charge` and `document_controller` claims are the approved
exception to item 3: trusted functions treat the current authenticated holder
as a Project Engineer across every project while retaining the exact raw claim
for display/audit. This exception grants no Procurement, stock, commercial or
Admin capability. Senior Mechanical Engineer separately receives the
non-commercial inventory read projection, while every inventory mutation still
checks Procurement/Admin stock authority.
Before any role-dependent result is returned, the command compares that JWT
claim with the current protected `auth.users.raw_app_meta_data.role` value and
the active profile mirror. A stale claim is denied rather than relying on its
normalised role alone.

Unknown or missing roles receive no privileged application role. Email domains,
names, editable metadata and client-provided role strings are never authority.

## 5. Read paths

- Project/Site Engineer project queries join active/historical membership as
  appropriate and return only authorized project data.
- Procurement project/BOQ views are read-only and exclude unauthorized
  commercial fields.
- `v1_list_boq_groups_for_scope(project, null)` is the Overview projection;
  null is not a database scope. A non-null scope returns only that independent
  Common/building workbook set. The compatibility list RPC returns Common only.
- Custom BOQ folder names are project-wide definitions materialized as one
  independent empty group per active real scope. The read path never merges or
  copies their rows, columns, quantities, exports or MR sources.
- Draft MR queries are creator/Admin-only.
- Submitted operational data uses role-specific secure views or RPC-returned
  records.
- Commercial views require `view_commercials` and never use UI filtering as the
  boundary.
- Storage downloads require authorization for every current document link plus
  classification. Cross-project links are Admin-only and reasoned.

## 6. Command paths

Critical commands are `security definer` functions only when required and must:

1. set a safe `search_path`;
2. derive actor/role from the authenticated server context;
3. validate active account, role, capability and project membership;
4. lock the root and quantity-bearing rows in deterministic order;
5. validate optimistic record version and current state;
6. validate decimal quantities and reconciliation constraints;
7. claim/validate an idempotency key;
8. write domain effects, reference number, activity/audit and notification in
   one transaction;
9. return the committed authoritative projection.

Ordinary table grants do not permit clients to bypass command functions for
critical transitions.

## 7. Audit and attribution

`audit_events` is append-only. Clients have no insert/update/delete grant.
Trusted functions write:

- actor Auth UUID and stable profile ID;
- server-resolved role and relevant project role;
- command and source entity/version;
- before/after state or quantity summary without secrets;
- server timestamp and idempotency key;
- reason where required.

Client-generated comments/activity may exist as separate collaboration records,
but they never masquerade as server audit.

## 8. Idempotency and concurrency

- Critical commands use UUID idempotency keys generated by the client before
  the call and persisted until a result is confirmed.
- The server stores actor, command, key, request hash and response reference.
- Same key/same request returns the prior result; same key/different request
  fails.
- Editable records carry an integer version. A stale expected version produces
  a conflict response.
- Quantity commands lock inventory/reservation/request rows before reading the
  values used for validation.
- Use Postgres `numeric`, not Dart binary-double results, as the final quantity
  authority.

## 9. Local data and sync

The existing outbox may deliver non-critical draft/document metadata commands
where the repository explicitly supports idempotency. It cannot turn a generic
snapshot upsert into a stock transaction.

Local caches are projections. On Realtime events the app invalidates and
re-fetches through the same authorized read path. A missed Realtime event cannot
change correctness.

Offline critical actions stay pending with clear copy. Reconnect executes the
trusted command; it does not apply a local success retroactively.

## 10. Secrets, configuration and release

- Flutter contains only the Supabase URL and publishable key.
- Release startup fails closed without complete HTTPS configuration.
- Service-role, signing and deployment credentials live only in protected CI or
  server environments.
- Android release must declare Internet access and must not be presented as
  production-signed when it used a debug key.
- Logs, crash reports and analytics exclude tokens, unrestricted document URLs
  and protected commercial payloads.

## 11. Feature rollout

During incremental delivery, V1 flags were independently enabled in this
order. That historical rollout is complete: the canonical R35 build now
enables the complete chain by default, while an explicit disabled dependency
fails closed. The flags remain available only for non-release test/development
coverage; they are not a production partial-rollout or rollback switch.

1. `YORKS_V1_FOUNDATION`
2. `YORKS_V1_PROJECTS`
3. `YORKS_V1_BOQ`
4. `YORKS_V1_EXCEL`
5. `YORKS_V1_REQUESTS`
6. `YORKS_V1_ARRANGEMENT`
7. `YORKS_V1_LOGISTICS`
8. `YORKS_V1_RETURNS_DOCUMENTS`

Enabling a downstream flag without its dependencies fails closed. Legacy V7
flags are not silently repurposed.
