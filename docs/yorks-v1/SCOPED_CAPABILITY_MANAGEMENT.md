# Yorks V1 — Scoped Capability Management

Status: **approved for additive implementation on 24 August 2026**

This contract introduces person-specific permissions without replacing Yorks
roles, weakening workflow invariants or changing any user's effective access at
deployment. Roles remain the authoritative job identity and baseline template;
scoped capability assignments are controlled exceptions around that baseline.

## 1. Outcomes and non-goals

The capability workspace must let an authorized administrator answer, for any
active user:

- what the user can view or do;
- whether access comes from the role baseline, project membership, an explicit
  grant or an explicit deny;
- which projects the assignment covers, when it expires and who changed it;
- why a requested action is still blocked by state, separation of duties or a
  protected invariant.

This is not a client-side feature-toggle system. It does not make every server
rule optional, turn roles into labels, expose a capability before its protected
runtime consumer exists, or permit audit history to be edited/deleted.

## 2. Compatibility promise

The first production deployment is a zero-surprise migration:

1. the exact eight server-controlled roles and active project memberships stay
   unchanged;
2. a seeded role baseline reproduces the effective access that each role has
   immediately before this migration;
3. existing commercial overrides remain effective and are surfaced through the
   new projection without being reinterpreted or discarded;
4. workflow RPCs and RLS continue to use their existing authorization checks
   while the new resolver runs in shadow mode;
5. a parity report must show no unexplained allow/deny difference for active
   users before any runtime consumer cuts over; and
6. a cutover is capability-by-capability, reversible and guarded. There is no
   global switch that can widen access accidentally.

Legacy local-only preferences are not silently converted into server authority.
They must be classified, reconciled and explicitly migrated or retired.

## 3. Effective-permission evaluation

Every protected read or command resolves access on the server using this order:

1. authenticate the actor and reject inactive/deleted users or stale exact-role
   claims;
2. apply non-delegable hard invariants and separation-of-duties rules;
3. evaluate the most specific active scoped deny;
4. evaluate the most specific active scoped grant;
5. fall back to the immutable role-template baseline;
6. require active project membership when the capability is project scoped,
   except for an approved organization-wide engineering role/baseline;
7. apply record state, ownership, quantity, commercial-response and workflow
   preconditions; and
8. return the decision together with a safe explanation and revision.

An explicit assignment changes only the named capability and scope. It never
grants a related capability by implication. A UI-visible allow is advisory until
the trusted command accepts the same actor, scope, record state and revision.

## 4. Scope and assignment model

Supported assignment scope kinds are:

- `organization` — all eligible Yorks records for that capability;
- `project` — one or more explicitly selected active projects, with downstream
  records evaluated through those projects.

Assignments are `grant` or `deny`, have an optional validity window, an
administrative reason, optimistic revision and idempotency key. Expired or
revoked assignments remain in immutable history but have no current effect.
Project scope IDs are rejected for organization-only capabilities. Wildcards,
free-form module names and client-authored capability definitions are rejected.

Self-service remains an inherent record/ownership predicate rather than an
assignable scope. For example, a user may update approved non-authority fields
on their own profile, but an administrator cannot turn `self` into a wildcard
grant for protected domain actions.

Specificity is deterministic: a project assignment takes precedence over an
organization assignment for that project, and an explicit deny wins over an
explicit grant at the same specificity. Conflicting active duplicates are
prevented by the database.

## 5. Capability catalogue

Capability keys use `domain.action`. Each catalog row declares its supported
scopes, risk class, runtime wiring state, authorization mode and delegation
ceiling. Authorization mode is per capability (`shadow` or `enforced`); a
single global switch is prohibited because it would prevent controlled
consumer-by-consumer cutover. The initial
catalog covers the current Yorks surfaces:

- Projects: view, create, edit, state/archive and member management;
- BOQ: view, edit, import and export;
- Material Requests: view, create/edit/submit, Engineering approval,
  Procurement arrangement, dispatch, receipt review and close;
- Inventory: non-commercial view, item/category mutation, stock adjustment,
  import and export;
- Material Returns: view, create/edit/submit, Engineering decision, dispatch
  and warehouse confirmation;
- Documents: view, upload/link and version management;
- Team Chat: view/send, group management and announcements;
- Configuration: view, stage and publish;
- User Management: directory view, account administration and capability
  administration;
- Audit: view, export and append-only corrective note;
- Rentals and commercial projections: existing view/manage boundaries.

A capability is shown as assignable only when its server consumer, RLS/RPC
tests and role-safe response shape are marked `enforced`. `shadow` capabilities
may appear read-only for parity diagnostics, and their candidate assignments
must not change the currently authoritative route, response or command
decision. `planned` capabilities are not
shown as usable controls. Accounts controls remain planned until an
authoritative Accounts runtime exists.

The following are never delegable capabilities: changing or deleting audit
history; retrieving secrets/service credentials; bypassing RLS; editing
reference counters directly; fabricating workflow history; overriding quantity,
state or separation-of-duties rules; and changing one's own delegation ceiling.

## 6. Administration and delegation safety

The existing exact Admin and Senior Mechanical Engineer User Management
authority is preserved as the initial capability-administration baseline.
Changing assignments requires an active actor with both target visibility and
`permissions.manage` authority. Granting an access capability additionally
must stay within the actor's server-defined delegation ceiling; assigning a
permission-administration capability additionally requires
`permissions.delegate`. Viewing the workspace requires
`permissions.view` only.

The server must also enforce that:

- an actor cannot grant a capability or scope outside the actor's delegation
  ceiling;
- an actor cannot change their own effective permissions;
- a user cannot remove or expire the last active permission administrator;
- the `users.view` -> `permissions.view` -> `permissions.manage` ->
  `permissions.delegate` continuity chain is immediate and open-ended; those
  four capabilities cannot be future-dated or given an expiry because no
  transaction runs at a bare database-clock boundary to re-prove that a
  manager remains;
- exact role changes continue through the protected Auth/admin path and are
  separate from capability changes;
- every mutation includes a meaningful reason, expected revision and
  idempotency key; and
- deactivation immediately makes all grants ineffective without deleting
  assignment history.

Permission administrators can inspect why a mutation is rejected, but the
response must not reveal commercial data, secrets or unauthorized entity
metadata.

The target workspace includes a server-computed `actor_can_delegate` value for
each capability. The UI uses it to disable controls above the current actor's
exact-role ceiling, while the mutation RPC repeats the check. This projection
is advisory presentation data, not a substitute for transaction authority.

## 7. Server and data contract

The database owns:

- a protected capability catalogue and immutable role-template defaults;
- current scoped assignments plus append-only assignment revisions;
- a monotonically increasing user permission revision;
- one resolver used by protected RPCs/RLS helpers;
- an effective-permission snapshot for the authenticated user;
- an administrative target-user workspace and history projection;
- versioned set/clear commands plus one atomic reviewed multi-change command;
  and
- a parity projection comparing the legacy decision with the new shadow
  resolver while migration is in progress.

Ordinary authenticated clients receive no direct mutation grants on catalogue,
template, assignment, revision or parity tables. Security-definer functions set
a safe `search_path`, derive actor/role from Auth, validate exact current role,
lock deterministically and write the assignment, revision and trusted audit
event in one transaction.

The current-user projection returns only capability keys and scopes that the
user is authorized to know. Commercial permissions do not pull commercial
values into the response, cache or provider state.

## 8. Flutter and Realtime behavior

The path remains:

`Widget -> Riverpod controller -> repository -> protected RPC/query`

Route guards and action widgets consume one immutable, server-confirmed
permission snapshot. The prior confirmed snapshot remains visible during a
routine refresh, preventing navigation or button flicker. Initial load,
logout, identity change, inactive state, stale Auth or an unrecoverable refresh
fails closed for protected actions.

Realtime carries only a revision/change signal. On a relevant change the client
re-fetches the protected projection, atomically replaces the snapshot and
re-evaluates the active route. Missed events are covered by app-resume refresh
and a low-frequency safety refresh. Realtime payloads are never permission
authority.

## 9. User Management experience

User Management adds a responsive **Access** workspace beside Users, Project
Access and Access History:

- desktop: searchable user list, capability groups and a sticky explanation /
  change panel;
- tablet: master-detail with a collapsible user rail; and
- mobile: user picker followed by grouped capability cards and a focused edit
  sheet with at least 44x44 targets.

Each capability displays Effective, Source, Scope, Validity and Runtime state.
Inherited access is visually distinct from explicit grant/deny. Search and
filters support module, effective state, source, scope and expiring access.
Save is disabled until the reason and scope are valid. A conflict reloads the
fresh server revision without discarding the user's unsaved intention. Multiple
reviewed deltas commit in one target-locked transaction and increment the target
revision once; a validation or authorization failure changes nothing. Empty,
loading, offline, unauthorized, revoked-target and last-admin states have
specific accessible copy rather than a generic error.

The history timeline is append-only and includes actor, exact role, target,
capability, scope, before/after decision, reason and server time. Audit records
may be viewed/exported according to capability; they cannot be edited or
deleted. Any corrective note is a new linked event.

## 10. Rollout, rollback and acceptance

Release stages are:

1. catalogue, seeded templates, resolver, snapshots, administration RPCs and
   tests ship additively with workflow enforcement unchanged;
2. run parity for every active role/user plus explicit commercial overrides;
3. resolve every difference through an approved mapping, never by broadening a
   default;
4. enable the management UI for enforced capabilities;
5. cut over one protected consumer only after positive, negative, stale-token,
   direct-table, project-scope and separation-of-duties tests pass; and
6. observe audit/rejection telemetry before advancing the next consumer.

### Implemented first cutover

The first protected cutover is intentionally narrower than the catalogue. The
following capabilities are `enforced` because both their trusted consumer and
positive/negative permission tests ship in the same release:

- Projects: `projects.view`, `projects.create`, `projects.edit`,
  `projects.archive`;
- BOQ: `boq.view`, `boq.edit`;
- Material Requests and logistics: `material_requests.view`,
  `material_requests.create`, `material_requests.edit`,
  `material_requests.submit`, `material_requests.approve`,
  `material_requests.return_for_changes`, `material_requests.cancel`,
  `material_requests.close`, `procurement.arrange`, `dispatch.create`,
  `delivery_orders.generate`, `receipts.confirm`, `returns.view`,
  `returns.create`, `returns.approve` and `returns.dispatch`; and
- User and access administration: `users.view`, `users.create`,
  `users.roles.assign`, `users.password.reset`, `users.activation.manage`,
  `permissions.view`, `permissions.manage` and `permissions.delegate`.

The User Management cutover also replaces the durable Auth audit trigger in
the same migration. It rechecks the action-specific capability, active Auth
identity/profile, target hierarchy, self-mutation, last-Admin and idempotency
in the GoTrue transaction. V1 provisioning accepts exactly one server-owned
role and its server-owned compatibility claims; secondary roles, caller caps
and legacy-shell switches are rejected. A HMAC-bound pending marker makes the
two-stage GoTrue create resumable and is stripped when the one
`admin_user_created` audit commits. Retained legacy provisioning is disabled
by default and remains exact-Admin-only when explicitly enabled for recovery.

An enforced capability is still combined with its structural eligibility,
active project membership, workflow state and separation-of-duties predicates.
For example, a Procurement user cannot become an Engineering approver merely
through a grant, and a project-scoped grant cannot manufacture project access.
A Site Engineer may make an Engineering decision only while carrying the
dated Project Engineer membership required by the product contract.

All other operational catalogue rows remain `shadow` until their complete
read/command surface is separable and tested. In particular, project-team and
project-state management, granular BOQ import/export/folder actions, printing,
embedded logistics reads/evidence and warehouse return confirmation remain
legacy-authoritative. Planned Accounts and audit-corrective-note controls stay
disabled and nonassignable.

Rollback disables the new consumer and returns to the prior server check. It
does not drop capability data, remove audit history or rewrite roles. A
permission change made after UI activation must not be lost; rollback treats it
as retained configuration pending the next safe cutover.

Acceptance requires:

- an exact current-access preservation fixture for all eight roles and existing
  commercial overrides;
- positive and negative tests for every seeded capability;
- self-escalation, delegation-ceiling, last-admin, expiry and conflicting-writer
  proofs;
- no direct-table bypass and no unauthorized response fields;
- cross-device revision refresh without visual flicker;
- desktop, tablet and 360px mobile evidence including keyboard/focus and screen
  reader labels; and
- a documented parity report with zero unexplained differences before any
  workflow authorization cutover.
