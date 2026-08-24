-- Yorks Scoped Capability Management foundation.
--
-- This migration is deliberately additive and shadow-only. Existing Yorks
-- workflow RPC/RLS predicates remain authoritative until a later, separately
-- accepted cutover migration replaces each consumer. The catalog, exact-role
-- templates, normalized person overrides, effective resolver and immutable
-- history are introduced now so current access can be measured and edited
-- without silently changing an operational workflow.
--
-- Data preservation:
-- * public.v1_user_capabilities and public.v1_role_capability_defaults retain
--   their existing commercial behavior and public RPC contracts.
-- * existing commercial overrides are mirrored into this foundation and the
--   live resolver continues to consult the legacy commercial authority.
-- * retained server-backed AppUser overrides are copied when present. Missing
--   device-only data is never guessed; the client keeps its compatibility
--   overlay until a later evidence-backed cutover.
--
-- Rollback: revoke the nine public permission RPCs and redeploy the previous
-- client. Retain every assignment, revision and change event. Never drop or
-- rewrite permission history after an administrator has used this workspace.

begin;

create table public.v1_capability_catalog (
  capability_key text primary key
    check (capability_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'),
  module_key text not null check (module_key ~ '^[a-z][a-z0-9_]*$'),
  action_key text not null check (action_key ~ '^[a-z][a-z0-9_]*$'),
  label text not null check (btrim(label) <> ''),
  description text not null check (btrim(description) <> ''),
  risk_level text not null
    check (risk_level in ('low', 'medium', 'high', 'critical')),
  allowed_scope_kinds text[] not null default array['organization']::text[],
  requires_project_access boolean not null default false,
  dependencies text[] not null default '{}'::text[],
  status text not null default 'operational'
    check (status in ('operational', 'planned')),
  authorization_mode text not null default 'shadow'
    check (authorization_mode in ('shadow', 'enforced')),
  is_assignable boolean not null default true,
  display_order integer not null unique check (display_order > 0),
  created_at timestamptz not null default clock_timestamp(),
  check (cardinality(allowed_scope_kinds) > 0),
  check (allowed_scope_kinds <@ array['organization', 'project']::text[]),
  check (
    not requires_project_access
    or 'project' = any (allowed_scope_kinds)
  ),
  check (
    (status = 'operational')
    or (status = 'planned' and not is_assignable)
  )
);

create table public.v1_permission_role_defaults (
  role_name text not null check (role_name in (
    'project_engineer', 'site_engineer',
    'senior_mechanical_engineer', 'project_manager',
    'workshop_in_charge', 'document_controller',
    'procurement', 'admin'
  )),
  capability_key text not null
    references public.v1_capability_catalog (capability_key) on delete restrict,
  is_granted boolean not null default false,
  can_delegate boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (role_name, capability_key)
);

create table public.v1_permission_revisions (
  auth_user_id uuid primary key
    references public.v1_profiles (auth_user_id) on delete restrict,
  app_user_id text not null unique,
  revision bigint not null default 0 check (revision >= 0),
  updated_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (btrim(app_user_id) <> '')
);

create table public.v1_permission_assignments (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  capability_key text not null
    references public.v1_capability_catalog (capability_key) on delete restrict,
  effect text not null check (effect in ('grant', 'deny')),
  scope_kind text not null check (scope_kind in ('organization', 'project')),
  origin text not null default 'permission_management'
    check (origin in (
      'permission_management', 'legacy_commercial', 'legacy_app_user'
    )),
  effective_from timestamptz not null default clock_timestamp(),
  effective_until timestamptz,
  reason text not null check (btrim(reason) <> '' and char_length(reason) <= 2000),
  version bigint not null default 1 check (version > 0),
  changed_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (effective_until is null or effective_until > effective_from),
  unique (auth_user_id, capability_key, scope_kind, effect)
);

create unique index v1_permission_assignments_organization_current_idx
  on public.v1_permission_assignments (auth_user_id, capability_key)
  where scope_kind = 'organization';
create unique index v1_permission_assignments_project_effect_current_idx
  on public.v1_permission_assignments (
    auth_user_id, capability_key, effect
  ) where scope_kind = 'project';

create table public.v1_permission_assignment_projects (
  assignment_id uuid not null
    references public.v1_permission_assignments (id) on delete cascade,
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key (assignment_id, project_id)
);

create index v1_permission_assignments_target_idx
  on public.v1_permission_assignments (
    auth_user_id, capability_key, scope_kind, effect
  );
create index v1_permission_assignments_active_idx
  on public.v1_permission_assignments (auth_user_id, effective_from, effective_until);
create index v1_permission_assignments_capability_idx
  on public.v1_permission_assignments (capability_key, auth_user_id);
create index v1_permission_assignments_changed_by_idx
  on public.v1_permission_assignments (changed_by_auth_user_id)
  where changed_by_auth_user_id is not null;
create index v1_permission_assignment_projects_project_idx
  on public.v1_permission_assignment_projects (project_id, assignment_id);
create index v1_permission_role_defaults_capability_idx
  on public.v1_permission_role_defaults (capability_key, role_name);
create index v1_permission_revisions_updated_by_idx
  on public.v1_permission_revisions (updated_by_auth_user_id)
  where updated_by_auth_user_id is not null;

create table public.v1_permission_change_events (
  id uuid primary key default gen_random_uuid(),
  target_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  event_kind text not null
    check (event_kind in ('set', 'clear', 'migration', 'legacy_sync')),
  capability_key text not null
    references public.v1_capability_catalog (capability_key) on delete restrict,
  effect text check (effect is null or effect in ('grant', 'deny')),
  scope_kind text not null check (scope_kind in ('organization', 'project')),
  project_ids uuid[] not null default '{}'::uuid[],
  before_state jsonb,
  after_state jsonb,
  reason text not null check (btrim(reason) <> '' and char_length(reason) <= 2000),
  actor_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_exact_role text not null check (actor_exact_role in (
    'project_engineer', 'site_engineer',
    'senior_mechanical_engineer', 'project_manager',
    'workshop_in_charge', 'document_controller',
    'procurement', 'admin', 'system'
  )),
  occurred_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid,
  event_ordinal integer not null default 1 check (event_ordinal > 0),
  revision bigint not null check (revision >= 0),
  check (
    (actor_exact_role = 'system' and actor_auth_user_id is null)
    or (actor_exact_role <> 'system' and actor_auth_user_id is not null)
  )
);

create unique index v1_permission_change_events_idempotency_idx
  on public.v1_permission_change_events (
    actor_auth_user_id, idempotency_key, event_ordinal
  )
  where actor_auth_user_id is not null and idempotency_key is not null;
create index v1_permission_change_events_target_idx
  on public.v1_permission_change_events (
    target_auth_user_id, occurred_at desc, id desc
  );
create index v1_permission_change_events_capability_idx
  on public.v1_permission_change_events (capability_key, occurred_at desc);
create index v1_permission_change_events_actor_idx
  on public.v1_permission_change_events (
    actor_auth_user_id, occurred_at desc
  ) where actor_auth_user_id is not null;

-- A scope is an entitlement boundary, never a replacement for the existing
-- project-membership/global-engineer access rule.
insert into public.v1_capability_catalog (
  capability_key, module_key, action_key, label, description, risk_level,
  allowed_scope_kinds, requires_project_access, dependencies, status,
  is_assignable, display_order
)
values
  ('projects.view', 'projects', 'view', 'View projects', 'Read an otherwise authorized project.', 'low', array['organization','project'], true, '{}', 'operational', true, 10),
  ('projects.view_all', 'projects', 'view_all', 'View all projects', 'Protected role boundary for organization-wide visibility; person grants cannot replace project membership.', 'high', array['organization'], false, array['projects.view'], 'operational', false, 11),
  ('projects.create', 'projects', 'create', 'Create projects', 'Create a project through the trusted project command.', 'high', array['organization'], false, '{}', 'operational', true, 12),
  ('projects.edit', 'projects', 'edit', 'Edit projects', 'Edit an authorized project through versioned commands.', 'high', array['organization','project'], true, array['projects.view'], 'operational', true, 13),
  ('projects.change_state', 'projects', 'change_state', 'Change project state', 'Run allowed project lifecycle transitions.', 'high', array['organization','project'], true, array['projects.view'], 'operational', true, 14),
  ('projects.archive', 'projects', 'archive', 'Archive projects', 'Run the audited safe-archive command.', 'critical', array['organization','project'], true, array['projects.view'], 'operational', true, 15),
  ('projects.manage_team', 'projects', 'manage_team', 'Manage project team', 'Assign or revoke dated project access.', 'critical', array['organization','project'], true, array['projects.view'], 'operational', true, 16),
  ('boq.view', 'boq', 'view', 'View BOQ', 'Read authorized BOQ workbooks.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 30),
  ('boq.edit', 'boq', 'edit', 'Edit BOQ', 'Edit rows and columns through protected commands.', 'high', array['organization','project'], true, array['boq.view'], 'operational', true, 31),
  ('boq.import', 'boq', 'import', 'Import BOQ', 'Commit a reviewed atomic BOQ import.', 'high', array['organization','project'], true, array['boq.edit'], 'operational', true, 32),
  ('boq.export', 'boq', 'export', 'Export BOQ', 'Export an authorized BOQ workbook.', 'medium', array['organization','project'], true, array['boq.view'], 'operational', true, 33),
  ('boq.manage_folders', 'boq', 'manage_folders', 'Manage BOQ folders', 'Create controlled project-wide BOQ folder definitions.', 'high', array['organization','project'], true, array['boq.edit'], 'operational', true, 34),
  ('material_requests.view', 'material_requests', 'view', 'View material requests', 'Read authorized request summaries and details.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 50),
  ('material_requests.create', 'material_requests', 'create', 'Create material requests', 'Create a private Engineering request draft.', 'medium', array['organization','project'], true, array['material_requests.view'], 'operational', true, 51),
  ('material_requests.edit', 'material_requests', 'edit', 'Edit material requests', 'Edit an eligible request version.', 'high', array['organization','project'], true, array['material_requests.view'], 'operational', true, 52),
  ('material_requests.submit', 'material_requests', 'submit', 'Submit material requests', 'Submit or resubmit Engineering intent.', 'high', array['organization','project'], true, array['material_requests.edit'], 'operational', true, 53),
  ('material_requests.approve', 'material_requests', 'approve', 'Approve material requests', 'Approve current Engineering intent; separation-of-duty rules still apply.', 'critical', array['organization','project'], true, array['material_requests.view'], 'operational', true, 54),
  ('material_requests.return_for_changes', 'material_requests', 'return_for_changes', 'Return requests for changes', 'Return current Engineering intent with a reason.', 'high', array['organization','project'], true, array['material_requests.view'], 'operational', true, 55),
  ('material_requests.cancel', 'material_requests', 'cancel', 'Cancel material requests', 'Cancel an eligible request with retained history.', 'critical', array['organization','project'], true, array['material_requests.view'], 'operational', true, 56),
  ('material_requests.close', 'material_requests', 'close', 'Close material requests', 'Close a fully resolved request.', 'high', array['organization','project'], true, array['material_requests.view'], 'operational', true, 57),
  ('material_requests.print', 'material_requests', 'print', 'Print material requests', 'Generate an authorized controlled request document.', 'medium', array['organization','project'], true, array['material_requests.view'], 'operational', true, 58),
  ('procurement.view', 'procurement', 'view', 'View procurement', 'Read authorized arrangement facts.', 'low', array['organization','project'], true, array['material_requests.view'], 'operational', true, 70),
  ('procurement.arrange', 'procurement', 'arrange', 'Arrange materials', 'Start and save a procurement arrangement.', 'critical', array['organization','project'], true, array['procurement.view'], 'operational', true, 71),
  ('procurement.external_readiness.manage', 'procurement', 'external_readiness_manage', 'Manage external readiness', 'Record external-source readiness evidence.', 'high', array['organization','project'], true, array['procurement.arrange'], 'operational', true, 72),
  ('dispatch.view', 'dispatch', 'view', 'View dispatches', 'Read authorized dispatch history.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 90),
  ('dispatch.create', 'dispatch', 'create', 'Create dispatches', 'Commit an approved dispatch through the stock transaction.', 'critical', array['organization','project'], true, array['dispatch.view'], 'operational', true, 91),
  ('delivery_orders.generate', 'dispatch', 'generate_delivery_order', 'Generate delivery orders', 'Generate an immutable Delivery Order revision.', 'high', array['organization','project'], true, array['dispatch.view'], 'operational', true, 92),
  ('delivery_reports.print', 'dispatch', 'print_delivery_report', 'Print delivery reports', 'Print an authorized immutable delivery snapshot.', 'medium', array['organization','project'], true, array['dispatch.view'], 'operational', true, 93),
  ('receipts.view', 'receipts', 'view', 'View receipt reviews', 'Read authorized receipt-review facts.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 110),
  ('receipts.confirm', 'receipts', 'confirm', 'Confirm receipts', 'Confirm reconciled good, missing and damaged quantities.', 'critical', array['organization','project'], true, array['receipts.view'], 'operational', true, 111),
  ('receipts.attach_evidence', 'receipts', 'attach_evidence', 'Attach receipt evidence', 'Attach verified site photographs to a confirmed review.', 'high', array['organization','project'], true, array['receipts.view'], 'operational', true, 112),
  ('returns.view', 'returns', 'view', 'View material returns', 'Read authorized project material returns.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 130),
  ('returns.create', 'returns', 'create', 'Create material returns', 'Create and submit an eligible material return.', 'high', array['organization','project'], true, array['returns.view'], 'operational', true, 131),
  ('returns.approve', 'returns', 'approve', 'Approve material returns', 'Approve, return or reject a submitted return.', 'critical', array['organization','project'], true, array['returns.view'], 'operational', true, 132),
  ('returns.dispatch', 'returns', 'dispatch', 'Dispatch material returns', 'Record physical return handover.', 'high', array['organization','project'], true, array['returns.view'], 'operational', true, 133),
  ('returns.confirm', 'returns', 'confirm', 'Confirm warehouse returns', 'Confirm physical warehouse receipt and stock movement.', 'critical', array['organization','project'], true, array['returns.view'], 'operational', true, 134),
  ('inventory.view', 'inventory', 'view', 'View inventory', 'Read the permitted warehouse projection.', 'low', array['organization'], false, '{}', 'operational', true, 150),
  ('inventory.items.manage', 'inventory', 'items_manage', 'Manage inventory items', 'Create or edit inventory item master data.', 'high', array['organization'], false, array['inventory.view'], 'operational', true, 151),
  ('inventory.stock.adjust', 'inventory', 'stock_adjust', 'Adjust inventory stock', 'Commit an append-only stock movement.', 'critical', array['organization'], false, array['inventory.view'], 'operational', true, 152),
  ('inventory.import', 'inventory', 'import', 'Import inventory', 'Commit a reviewed atomic inventory import.', 'critical', array['organization'], false, array['inventory.view'], 'operational', true, 153),
  ('inventory.categories.manage', 'inventory', 'categories_manage', 'Manage inventory categories', 'Create and maintain controlled categories.', 'high', array['organization'], false, array['inventory.view'], 'operational', true, 154),
  ('inventory.suppliers.manage', 'inventory', 'suppliers_manage', 'Manage inventory suppliers', 'Manage supplier folders and receipt provenance.', 'critical', array['organization'], false, array['inventory.view'], 'operational', true, 155),
  ('inventory.export', 'inventory', 'export', 'Export inventory', 'Export an authorized warehouse register.', 'medium', array['organization'], false, array['inventory.view'], 'operational', true, 156),
  ('commercials.view', 'commercials', 'view', 'View commercial values', 'Receive commercial response shapes and documents.', 'critical', array['organization'], false, '{}', 'operational', true, 170),
  ('commercials.manage', 'commercials', 'manage', 'Manage commercial values', 'Write protected commercial values.', 'critical', array['organization'], false, array['commercials.view'], 'operational', true, 171),
  ('documents.view', 'documents', 'view', 'View documents', 'Read documents after linked-entity authorization.', 'low', array['organization','project'], true, array['projects.view'], 'operational', true, 190),
  ('documents.upload', 'documents', 'upload', 'Upload documents', 'Prepare and finalize an authorized document upload.', 'high', array['organization','project'], true, array['documents.view'], 'operational', true, 191),
  ('documents.versions.manage', 'documents', 'versions_manage', 'Manage document versions', 'Append and supersede controlled document versions.', 'high', array['organization','project'], true, array['documents.view'], 'operational', true, 192),
  ('documents.commercial.view', 'documents', 'commercial_view', 'View commercial documents', 'View commercial-classified documents after link checks.', 'critical', array['organization','project'], true, array['documents.view','commercials.view'], 'operational', true, 193),
  ('documents.admin_restricted.view', 'documents', 'admin_restricted_view', 'View restricted documents', 'View admin-restricted document classifications.', 'critical', array['organization'], false, array['documents.view'], 'operational', true, 194),
  ('chat.view', 'chat', 'view', 'View Team Chat', 'Read conversations where current membership and context allow.', 'low', array['organization'], false, '{}', 'operational', true, 210),
  ('chat.send', 'chat', 'send', 'Send chat messages', 'Send an append-only message as an active member.', 'medium', array['organization'], false, array['chat.view'], 'operational', true, 211),
  ('chat.groups.create', 'chat', 'groups_create', 'Create chat groups', 'Create a controlled custom Team Chat group.', 'high', array['organization'], false, array['chat.view'], 'operational', true, 212),
  ('chat.groups.manage', 'chat', 'groups_manage', 'Manage chat groups', 'Manage a group where ownership or Admin participation allows.', 'high', array['organization'], false, array['chat.view'], 'operational', true, 213),
  ('chat.announcements.create', 'chat', 'announcements_create', 'Create announcements', 'Create an organization announcement conversation.', 'critical', array['organization'], false, array['chat.view'], 'operational', true, 214),
  ('chat.announcements.send', 'chat', 'announcements_send', 'Send announcements', 'Send to an authorized announcement audience.', 'critical', array['organization'], false, array['chat.view'], 'operational', true, 215),
  ('rentals.view', 'rentals', 'view', 'View rentals', 'Read normalized rental properties and protected lease facts.', 'high', array['organization'], false, '{}', 'operational', true, 230),
  ('rentals.manage', 'rentals', 'manage', 'Manage rentals', 'Create or edit rental property and lease facts.', 'critical', array['organization'], false, array['rentals.view'], 'operational', true, 231),
  ('rentals.import_export', 'rentals', 'import_export', 'Import or export rentals', 'Run controlled rental workbook operations.', 'critical', array['organization'], false, array['rentals.view'], 'operational', true, 232),
  ('rentals.documents.manage', 'rentals', 'documents_manage', 'Manage rental documents', 'Manage protected rental controlled documents.', 'critical', array['organization'], false, array['rentals.view'], 'operational', true, 233),
  ('people.view', 'people', 'view', 'View People and HR', 'Read the authorized employee and attendance workspace.', 'high', array['organization'], false, '{}', 'operational', true, 250),
  ('people.manage', 'people', 'manage', 'Manage People and HR', 'Create or edit employee and attendance facts.', 'critical', array['organization'], false, array['people.view'], 'operational', true, 251),
  ('people.salary.view', 'people', 'salary_view', 'View salary information', 'Read salary and compensation fields.', 'critical', array['organization'], false, array['people.view'], 'operational', true, 252),
  ('leave.view_own', 'leave', 'view_own', 'View own leave', 'Read the current user own leave records.', 'low', array['organization'], false, '{}', 'operational', true, 270),
  ('leave.request', 'leave', 'request', 'Request leave', 'Create a leave request for the current user.', 'medium', array['organization'], false, array['leave.view_own'], 'operational', true, 271),
  ('leave.view_all', 'leave', 'view_all', 'View all leave', 'Read organization leave requests.', 'high', array['organization'], false, '{}', 'operational', true, 272),
  ('leave.manage', 'leave', 'manage', 'Manage leave', 'Approve, reject or record employee leave.', 'critical', array['organization'], false, array['leave.view_all'], 'operational', true, 273),
  ('configuration.view', 'configuration', 'view', 'View configuration', 'Read the protected configuration control plane.', 'critical', array['organization'], false, '{}', 'operational', true, 290),
  ('configuration.stage', 'configuration', 'stage', 'Stage configuration', 'Edit a staged operational configuration revision.', 'critical', array['organization'], false, array['configuration.view'], 'operational', true, 291),
  ('configuration.publish', 'configuration', 'publish', 'Publish configuration', 'Publish an approved staged configuration revision.', 'critical', array['organization'], false, array['configuration.stage'], 'operational', true, 292),
  ('users.view', 'users', 'view', 'View users', 'Read the protected user-management directory.', 'high', array['organization'], false, '{}', 'operational', true, 310),
  ('users.create', 'users', 'create', 'Create users', 'Create a protected Auth and profile record.', 'critical', array['organization'], false, array['users.view','users.roles.assign'], 'operational', true, 311),
  ('users.profile.edit', 'users', 'profile_edit', 'Edit user profiles', 'Edit protected user profile fields.', 'critical', array['organization'], false, array['users.view'], 'operational', true, 312),
  ('users.roles.assign', 'users', 'roles_assign', 'Assign user roles', 'Assign one exact server-controlled Yorks role.', 'critical', array['organization'], false, array['users.view'], 'operational', true, 313),
  ('users.password.reset', 'users', 'password_reset', 'Reset user passwords', 'Issue an audited password reset or recovery action.', 'critical', array['organization'], false, array['users.view'], 'operational', true, 314),
  ('users.activation.manage', 'users', 'activation_manage', 'Manage user activation', 'Activate or deactivate a user account with audit evidence.', 'critical', array['organization'], false, array['users.view'], 'operational', true, 315),
  ('users.delete', 'users', 'delete', 'Remove users', 'Planned retained-record removal workflow; current production deactivates users instead.', 'critical', array['organization'], false, array['users.view'], 'planned', false, 316),
  ('permissions.view', 'permissions', 'view', 'View permissions', 'Read effective permission sources and history.', 'high', array['organization'], false, array['users.view'], 'operational', true, 330),
  ('permissions.manage', 'permissions', 'manage', 'Manage permissions', 'Set or clear scoped person assignments within the delegation ceiling.', 'critical', array['organization'], false, array['permissions.view'], 'operational', true, 331),
  ('permissions.delegate', 'permissions', 'delegate', 'Delegate permissions', 'Grant capabilities only within the actor delegation ceiling.', 'critical', array['organization'], false, array['permissions.manage'], 'operational', true, 332),
  ('permissions.role_templates.manage', 'permissions', 'role_templates_manage', 'Manage role templates', 'Future protected role-template publication workflow.', 'critical', array['organization'], false, array['permissions.manage'], 'planned', false, 333),
  ('audit.view', 'audit', 'view', 'View audit trail', 'Read the immutable authorized audit projection.', 'critical', array['organization'], false, '{}', 'operational', true, 350),
  ('audit.export', 'audit', 'export', 'Export audit trail', 'Export authorized immutable audit evidence.', 'critical', array['organization'], false, array['audit.view'], 'operational', true, 351),
  ('audit.review_note.append', 'audit', 'append_review_note', 'Append audit review note', 'Future append-only review note; never edits or deletes audit facts.', 'critical', array['organization'], false, array['audit.view'], 'planned', false, 352),
  ('accounts.view', 'accounts', 'view', 'View accounts', 'Planned Accounts workspace visibility.', 'critical', array['organization'], false, '{}', 'planned', false, 370),
  ('accounts.edit', 'accounts', 'edit', 'Edit accounts', 'Planned Accounts write authority.', 'critical', array['organization'], false, array['accounts.view'], 'planned', false, 371),
  ('accounts.approve', 'accounts', 'approve', 'Approve accounts', 'Planned Accounts approval authority.', 'critical', array['organization'], false, array['accounts.view'], 'planned', false, 372),
  ('accounts.export', 'accounts', 'export', 'Export accounts', 'Planned Accounts export authority.', 'critical', array['organization'], false, array['accounts.view'], 'planned', false, 373);

-- Materialize the complete false-by-default matrix, then apply the exact
-- current Yorks role templates. This makes role parity queryable and prevents
-- a missing row from being confused with a migration failure.
insert into public.v1_permission_role_defaults (
  role_name, capability_key, is_granted, can_delegate
)
select role_name, capability.capability_key, false, false
from unnest(array[
  'project_engineer', 'site_engineer',
  'senior_mechanical_engineer', 'project_manager',
  'workshop_in_charge', 'document_controller',
  'procurement', 'admin'
]::text[]) role_name
cross join public.v1_capability_catalog capability;

-- Common authenticated collaboration and self-service defaults.
update public.v1_permission_role_defaults
set is_granted = true
where capability_key = any (array[
  'chat.view', 'chat.send', 'leave.view_own', 'leave.request'
])
and role_name <> 'admin';

-- Assigned Project Engineer template.
update public.v1_permission_role_defaults
set is_granted = true
where role_name = 'project_engineer'
and capability_key = any (array[
  'projects.view','projects.create','projects.edit','projects.change_state',
  'projects.manage_team','boq.view','boq.edit','boq.import','boq.export',
  'boq.manage_folders','material_requests.view','material_requests.create',
  'material_requests.edit','material_requests.submit',
  'material_requests.approve','material_requests.return_for_changes',
  'material_requests.cancel','material_requests.close',
  'material_requests.print','procurement.view','dispatch.view',
  'delivery_orders.generate','delivery_reports.print','receipts.view',
  'receipts.confirm','receipts.attach_evidence','returns.view',
  'returns.create','returns.approve','returns.dispatch','documents.view',
  'documents.upload','documents.versions.manage'
]);

-- Site Engineer preserves project/BOQ/request creation and receipt/return
-- duties without approval or team-management authority.
update public.v1_permission_role_defaults
set is_granted = true
where role_name = 'site_engineer'
and capability_key = any (array[
  'projects.view','projects.create','projects.edit','boq.view','boq.edit',
  'boq.import','boq.export','boq.manage_folders','material_requests.view',
  'material_requests.create','material_requests.edit',
  'material_requests.submit',
  'material_requests.close','material_requests.print','procurement.view',
  'dispatch.view','delivery_orders.generate','delivery_reports.print',
  'receipts.view','receipts.confirm','receipts.attach_evidence',
  'returns.view','returns.create','returns.dispatch','documents.view',
  'documents.upload','documents.versions.manage'
]);

-- Four organization-wide Engineering roles inherit the Project Engineer
-- template and all-project scope. Their exact titles remain distinct.
update public.v1_permission_role_defaults target
set is_granted = source.is_granted
from public.v1_permission_role_defaults source
where source.role_name = 'project_engineer'
  and target.role_name in (
    'senior_mechanical_engineer','project_manager',
    'workshop_in_charge','document_controller'
  )
  and target.capability_key = source.capability_key;
update public.v1_permission_role_defaults
set is_granted = true
where role_name in (
  'senior_mechanical_engineer','project_manager',
  'workshop_in_charge','document_controller'
)
and capability_key = 'projects.view_all';
update public.v1_permission_role_defaults
set is_granted = true
where role_name in (
  'senior_mechanical_engineer','project_manager',
  'workshop_in_charge','document_controller'
)
and capability_key in ('chat.groups.create','chat.groups.manage');

-- Senior Mechanical Engineer separately preserves the approved read-only
-- inventory and audited user/capability-management surface.
update public.v1_permission_role_defaults
set is_granted = true
where role_name = 'senior_mechanical_engineer'
and capability_key = any (array[
  'inventory.view','users.view','users.create','users.profile.edit',
  'users.roles.assign','users.password.reset','users.activation.manage',
  'permissions.view','permissions.manage',
  'permissions.delegate'
]);

-- Procurement's current office, warehouse, HR and leave authority.
update public.v1_permission_role_defaults
set is_granted = true
where role_name = 'procurement'
and capability_key = any (array[
  'projects.view','projects.view_all','boq.view','boq.export',
  'material_requests.view','material_requests.print','procurement.view',
  'procurement.arrange','procurement.external_readiness.manage',
  'dispatch.view','dispatch.create','delivery_orders.generate',
  'delivery_reports.print','receipts.view','returns.view','returns.confirm',
  'inventory.view','inventory.items.manage','inventory.stock.adjust',
  'inventory.import','inventory.categories.manage',
  'inventory.suppliers.manage','inventory.export','commercials.view',
  'commercials.manage','documents.view','documents.upload',
  'documents.versions.manage','documents.commercial.view','people.view',
  'people.manage','leave.view_all','leave.manage'
]);

-- Exact Admin remains the broad operational template. Planned/nonassignable
-- capabilities stay false even for Admin until a real protected consumer is
-- introduced.
update public.v1_permission_role_defaults role_default
set is_granted = true,
    can_delegate = capability.is_assignable
from public.v1_capability_catalog capability
where role_default.role_name = 'admin'
  and role_default.capability_key = capability.capability_key
  and capability.status = 'operational';

-- Admin's broad operational template does not invent employee self-service;
-- the retained Leave route expressly excludes Admin for these two actions.
update public.v1_permission_role_defaults
set is_granted = false,
    can_delegate = false
where role_name = 'admin'
  and capability_key in ('leave.view_own', 'leave.request');

-- A delegated permission manager can administer only capabilities already in
-- that exact role's operational template. The permission-management
-- capabilities themselves remain separately protected below.
update public.v1_permission_role_defaults role_default
set can_delegate = true
from public.v1_capability_catalog capability
where role_default.capability_key = capability.capability_key
  and role_default.is_granted
  and capability.status = 'operational'
  and capability.is_assignable;

-- A Senior permission manager can delegate only its own operational ceiling,
-- plus the retained commercial envelope it was already authorized to
-- administer. This preserves capability administration without giving the
-- actor commercial visibility.
update public.v1_permission_role_defaults
set can_delegate = true
where role_name = 'senior_mechanical_engineer'
and (
  is_granted
  or capability_key in ('commercials.view', 'commercials.manage')
);

-- All canonical profiles with a stable application ID receive a revision row.
insert into public.v1_permission_revisions (auth_user_id, app_user_id)
select profile.auth_user_id, profile.legacy_app_user_id
from public.v1_profiles profile
where nullif(btrim(profile.legacy_app_user_id), '') is not null
on conflict (auth_user_id) do nothing;

create or replace function public.v1_permission_sync_revision_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_changed boolean := false;
begin
  if tg_op = 'UPDATE' then
    v_changed := (
      old.legacy_app_user_id,
      old.canonical_role_snapshot,
      old.is_active
    ) is distinct from (
      new.legacy_app_user_id,
      new.canonical_role_snapshot,
      new.is_active
    );
  end if;

  if nullif(btrim(new.legacy_app_user_id), '') is not null then
    insert into public.v1_permission_revisions (
      auth_user_id, app_user_id, revision, updated_by_auth_user_id, updated_at
    ) values (
      new.auth_user_id, new.legacy_app_user_id, 0, null, clock_timestamp()
    )
    on conflict (auth_user_id) do update
      set app_user_id = excluded.app_user_id,
          revision = public.v1_permission_revisions.revision
            + case when v_changed then 1 else 0 end,
          updated_by_auth_user_id = case when v_changed
            and exists (
              select 1 from public.v1_profiles actor
              where actor.auth_user_id = auth.uid()
            ) then auth.uid()
            else public.v1_permission_revisions.updated_by_auth_user_id
          end,
          updated_at = case when v_changed
            then clock_timestamp()
            else public.v1_permission_revisions.updated_at
          end
      where public.v1_permission_revisions.app_user_id
          is distinct from excluded.app_user_id
        or v_changed;
  end if;
  return new;
end;
$$;

create trigger v1_permission_sync_revision_profile
after insert or update of
  legacy_app_user_id, canonical_role_snapshot, is_active
on public.v1_profiles
for each row execute function public.v1_permission_sync_revision_profile();

-- Exact global Engineering roles share the same canonical profile snapshot.
-- A change between those exact Auth roles therefore does not write the profile
-- mirror, but it still changes role-template authority and must wake the
-- affected user's permission client. Canonical-role and active-state changes
-- are already signalled exactly once by the profile trigger above.
create or replace function public.v1_permission_signal_exact_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_role text := coalesce(old.raw_app_meta_data ->> 'role', '');
  v_new_role text := coalesce(new.raw_app_meta_data ->> 'role', '');
begin
  if v_old_role is distinct from v_new_role
    and public.v1_is_valid_role(v_old_role)
    and public.v1_is_valid_role(v_new_role)
    and public.v1_canonical_role_from_exact_role(v_old_role)
      = public.v1_canonical_role_from_exact_role(v_new_role) then
    update public.v1_permission_revisions revision
    set revision = revision.revision + 1,
        updated_by_auth_user_id = case when exists (
          select 1 from public.v1_profiles actor
          where actor.auth_user_id = auth.uid()
        ) then auth.uid() else null end,
        updated_at = clock_timestamp()
    where revision.auth_user_id = new.id;
  end if;
  return new;
end;
$$;

create trigger v1_permission_signal_exact_role_change
after update of raw_app_meta_data on auth.users
for each row execute function public.v1_permission_signal_exact_role_change();

-- Project membership is a separate access predicate, but it participates in
-- the effective snapshot. Transition tables let one statement wake each
-- affected person once even when a bulk team edit touches several rows.
create or replace function public.v1_permission_signal_membership_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.v1_permission_revisions revision
  set revision = revision.revision + 1,
      updated_by_auth_user_id = case when exists (
        select 1 from public.v1_profiles actor
        where actor.auth_user_id = auth.uid()
      ) then auth.uid() else null end,
      updated_at = clock_timestamp()
  from (
    select distinct member.member_auth_user_id
    from new_permission_members member
  ) affected
  where revision.auth_user_id = affected.member_auth_user_id;
  return null;
end;
$$;

create or replace function public.v1_permission_signal_membership_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.v1_permission_revisions revision
  set revision = revision.revision + 1,
      updated_by_auth_user_id = case when exists (
        select 1 from public.v1_profiles actor
        where actor.auth_user_id = auth.uid()
      ) then auth.uid() else null end,
      updated_at = clock_timestamp()
  from (
    select member_auth_user_id from old_permission_members
    union
    select member_auth_user_id from new_permission_members
  ) affected
  where revision.auth_user_id = affected.member_auth_user_id;
  return null;
end;
$$;

create or replace function public.v1_permission_signal_membership_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.v1_permission_revisions revision
  set revision = revision.revision + 1,
      updated_by_auth_user_id = case when exists (
        select 1 from public.v1_profiles actor
        where actor.auth_user_id = auth.uid()
      ) then auth.uid() else null end,
      updated_at = clock_timestamp()
  from (
    select distinct member.member_auth_user_id
    from old_permission_members member
  ) affected
  where revision.auth_user_id = affected.member_auth_user_id;
  return null;
end;
$$;

create trigger v1_permission_signal_membership_insert
after insert on public.v1_project_members
referencing new table as new_permission_members
for each statement execute function
  public.v1_permission_signal_membership_insert();

create trigger v1_permission_signal_membership_update
after update on public.v1_project_members
referencing old table as old_permission_members
  new table as new_permission_members
for each statement execute function
  public.v1_permission_signal_membership_update();

create trigger v1_permission_signal_membership_delete
after delete on public.v1_project_members
referencing old table as old_permission_members
for each statement execute function
  public.v1_permission_signal_membership_delete();

-- Mirror current commercial overrides without modifying the retained source.
insert into public.v1_permission_assignments (
  auth_user_id, capability_key, effect, scope_kind, origin, effective_from, reason,
  changed_by_auth_user_id, created_at, updated_at
)
select
  legacy.auth_user_id,
  case legacy.capability
    when 'view_commercials' then 'commercials.view'
    else 'commercials.manage'
  end,
  case when legacy.is_granted then 'grant' else 'deny' end,
  'organization',
  'legacy_commercial',
  least(legacy.created_at, legacy.updated_at),
  legacy.reason,
  legacy.changed_by_auth_user_id,
  legacy.created_at,
  legacy.updated_at
from public.v1_user_capabilities legacy
join public.v1_permission_revisions revision
  on revision.auth_user_id = legacy.auth_user_id
on conflict do nothing;

-- Preserve any retained server-backed person overrides. Each mapping remains
-- visible as migration evidence; planned Accounts rows are retained but the
-- resolver always reports planned_disabled.
with legacy_override_map(json_key, capability_key) as (
  values
    ('canSeeCostOverride', 'commercials.view'),
    ('canViewFinanceOverride', 'accounts.view'),
    ('canSeeSalaryOverride', 'people.salary.view'),
    ('canAccessRentalsOverride', 'rentals.view'),
    ('canAccessPeopleOverride', 'people.view'),
    ('canReceiveGoodsOverride', 'inventory.view')
), source_rows as (
  select
    profile.auth_user_id,
    mapping.capability_key,
    (legacy_user.data ->> mapping.json_key)::boolean as is_granted,
    legacy_user.updated_at
  from public.users legacy_user
  join public.v1_profiles profile
    on profile.legacy_app_user_id = legacy_user.id
  cross join legacy_override_map mapping
  where jsonb_typeof(legacy_user.data -> mapping.json_key) = 'boolean'
)
insert into public.v1_permission_assignments (
  auth_user_id, capability_key, effect, scope_kind, origin, effective_from, reason,
  created_at, updated_at
)
select
  source.auth_user_id,
  source.capability_key,
  case when source.is_granted then 'grant' else 'deny' end,
  'organization',
  'legacy_app_user',
  source.updated_at,
  'Preserved retained per-user override',
  source.updated_at,
  source.updated_at
from source_rows source
join public.v1_permission_revisions revision
  on revision.auth_user_id = source.auth_user_id
on conflict do nothing;

-- Exact-role and scope helpers intentionally accept Auth UUIDs only inside the
-- trusted database boundary. Public administration RPCs accept the stable
-- application user ID and never disclose the Auth identifier.
create or replace function public.v1_permission_exact_role(p_auth_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when profile.is_active
      and public.v1_is_valid_role(
        coalesce(auth_user.raw_app_meta_data ->> 'role', '')
      )
      and profile.canonical_role_snapshot =
        public.v1_canonical_role_from_exact_role(
          coalesce(auth_user.raw_app_meta_data ->> 'role', '')
        )
      and (
        auth_user.banned_until is null
        or auth_user.banned_until <= clock_timestamp()
      )
    then coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    else ''
  end
  from auth.users auth_user
  join public.v1_profiles profile
    on profile.auth_user_id = auth_user.id
  where auth_user.id = p_auth_user_id;
$$;

create or replace function public.v1_permission_display_exact_role(
  p_auth_user_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.v1_is_valid_role(
      coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    ) then coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    else ''
  end
  from auth.users auth_user
  where auth_user.id = p_auth_user_id;
$$;

create or replace function public.v1_permission_target_auth_id(
  p_target_app_user_id text
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile.auth_user_id
  from public.v1_profiles profile
  where profile.legacy_app_user_id = nullif(btrim(p_target_app_user_id), '');
$$;

create or replace function public.v1_permission_has_project_access(
  p_auth_user_id uuid,
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text := public.v1_permission_exact_role(p_auth_user_id);
  v_project_state text;
begin
  if v_exact_role = '' or p_project_id is null then
    return false;
  end if;

  if v_exact_role in (
    'admin', 'senior_mechanical_engineer', 'project_manager',
    'workshop_in_charge', 'document_controller'
  ) then
    return exists (
      select 1 from public.v1_projects project where project.id = p_project_id
    );
  end if;

  if v_exact_role = 'procurement' then
    select project.state into v_project_state
    from public.v1_projects project
    where project.id = p_project_id;
    return v_project_state in ('active', 'on_hold');
  end if;

  return exists (
    select 1
    from public.v1_project_members member
    where member.project_id = p_project_id
      and member.member_auth_user_id = p_auth_user_id
      and member.effective_from <= clock_timestamp()
      and (
        member.effective_to is null
        or member.effective_to > clock_timestamp()
      )
  );
end;
$$;

-- Returns the candidate result before dependencies are applied. Project
-- membership remains a separate hard predicate and cannot be manufactured by
-- a project-scoped permission assignment.
create or replace function public.v1_permission_candidate_raw(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_role text := public.v1_permission_exact_role(p_auth_user_id);
  v_effect text;
  v_default boolean := false;
  v_legacy_result jsonb;
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;

  if not found then
    return jsonb_build_object('effective', false, 'source', 'unknown');
  end if;
  if v_role = '' then
    return jsonb_build_object('effective', false, 'source', 'inactive');
  end if;
  if v_catalog.status <> 'operational' then
    return jsonb_build_object('effective', false, 'source', 'planned_disabled');
  end if;
  if p_capability_key = 'commercials.manage'
    and v_role not in ('procurement', 'admin') then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
  end if;
  if p_project_id is not null
    and v_catalog.requires_project_access
    and not public.v1_permission_has_project_access(
      p_auth_user_id, p_project_id
    ) then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
  end if;

  select assignment.effect into v_effect
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_auth_user_id
    and assignment.capability_key = p_capability_key
    and assignment.origin = 'permission_management'
    and assignment.effective_from <= clock_timestamp()
    and (
      assignment.effective_until is null
      or assignment.effective_until > clock_timestamp()
    )
    and (
      assignment.scope_kind = 'organization'
      or (
        p_project_id is not null
        and assignment.scope_kind = 'project'
        and exists (
          select 1
          from public.v1_permission_assignment_projects assignment_project
          where assignment_project.assignment_id = assignment.id
            and assignment_project.project_id = p_project_id
        )
      )
    )
  order by
    case assignment.scope_kind when 'project' then 0 else 1 end,
    case assignment.effect when 'deny' then 0 else 1 end
  limit 1;

  if v_effect = 'deny' then
    return jsonb_build_object('effective', false, 'source', 'explicit_deny');
  elsif v_effect = 'grant' then
    return jsonb_build_object('effective', true, 'source', 'explicit_grant');
  end if;

  v_legacy_result := public.v1_permission_legacy_raw(
    p_auth_user_id, p_capability_key, p_project_id
  );
  if v_legacy_result ->> 'source' = 'legacy_override' then
    return v_legacy_result;
  end if;

  select role_default.is_granted into v_default
  from public.v1_permission_role_defaults role_default
  where role_default.role_name = v_role
    and role_default.capability_key = p_capability_key;

  return jsonb_build_object(
    'effective', coalesce(v_default, false),
    'source', case when coalesce(v_default, false)
      then 'role_default' else 'none' end
  );
end;
$$;

create or replace function public.v1_permission_candidate_resolution(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_dependency text;
  v_dependency_result jsonb;
begin
  v_result := public.v1_permission_candidate_raw(
    p_auth_user_id, p_capability_key, p_project_id
  );
  if not coalesce((v_result ->> 'effective')::boolean, false) then
    return v_result;
  end if;

  for v_dependency in
    select unnest(catalog.dependencies)
    from public.v1_capability_catalog catalog
    where catalog.capability_key = p_capability_key
  loop
    v_dependency_result := public.v1_permission_candidate_resolution(
      p_auth_user_id, v_dependency, p_project_id
    );
    if not coalesce(
      (v_dependency_result ->> 'effective')::boolean,
      false
    ) then
      return jsonb_build_object(
        'effective', false,
        'source', 'hard_invariant',
        'missing_dependency', v_dependency
      );
    end if;
  end loop;
  return v_result;
end;
$$;

-- Shadow authority reads only existing role behavior and pre-migration
-- overrides. New permission-management assignments are intentionally absent.
create or replace function public.v1_permission_legacy_raw(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_role text := public.v1_permission_exact_role(p_auth_user_id);
  v_effect text;
  v_default boolean := false;
  v_legacy_capability text;
  v_override boolean;
  v_json_key text;
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;
  if not found then
    return jsonb_build_object('effective', false, 'source', 'unknown');
  end if;
  if v_role = '' then
    return jsonb_build_object('effective', false, 'source', 'inactive');
  end if;
  if v_catalog.status <> 'operational' then
    return jsonb_build_object('effective', false, 'source', 'planned_disabled');
  end if;
  if p_capability_key = 'commercials.manage'
    and v_role not in ('procurement', 'admin') then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
  end if;
  if p_project_id is not null
    and v_catalog.requires_project_access
    and not public.v1_permission_has_project_access(
      p_auth_user_id, p_project_id
    ) then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
  end if;

  v_legacy_capability := case p_capability_key
    when 'commercials.view' then 'view_commercials'
    when 'commercials.manage' then 'manage_commercials'
    else null
  end;
  if v_legacy_capability is not null then
    select legacy.is_granted into v_override
    from public.v1_user_capabilities legacy
    where legacy.auth_user_id = p_auth_user_id
      and legacy.capability = v_legacy_capability;
    if found then
      return jsonb_build_object(
        'effective', v_override,
        'source', 'legacy_override'
      );
    end if;
  end if;

  v_json_key := case p_capability_key
    when 'commercials.view' then 'canSeeCostOverride'
    when 'accounts.view' then 'canViewFinanceOverride'
    when 'people.salary.view' then 'canSeeSalaryOverride'
    when 'rentals.view' then 'canAccessRentalsOverride'
    when 'people.view' then 'canAccessPeopleOverride'
    when 'inventory.view' then 'canReceiveGoodsOverride'
    else null
  end;
  if v_json_key is not null then
    select (legacy_user.data ->> v_json_key)::boolean into v_override
    from public.users legacy_user
    join public.v1_profiles profile
      on profile.legacy_app_user_id = legacy_user.id
    where profile.auth_user_id = p_auth_user_id
      and jsonb_typeof(legacy_user.data -> v_json_key) = 'boolean';
    if found then
      return jsonb_build_object(
        'effective', v_override,
        'source', 'legacy_override'
      );
    end if;
  end if;

  select assignment.effect into v_effect
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_auth_user_id
    and assignment.capability_key = p_capability_key
    and assignment.origin <> 'permission_management'
    and assignment.effective_from <= clock_timestamp()
    and (
      assignment.effective_until is null
      or assignment.effective_until > clock_timestamp()
    )
    and (
      assignment.scope_kind = 'organization'
      or (
        p_project_id is not null
        and assignment.scope_kind = 'project'
        and exists (
          select 1
          from public.v1_permission_assignment_projects assignment_project
          where assignment_project.assignment_id = assignment.id
            and assignment_project.project_id = p_project_id
        )
      )
    )
  order by
    case assignment.scope_kind when 'project' then 0 else 1 end,
    case assignment.effect when 'deny' then 0 else 1 end
  limit 1;
  if v_effect is not null then
    return jsonb_build_object(
      'effective', v_effect = 'grant',
      'source', 'legacy_override'
    );
  end if;

  select role_default.is_granted into v_default
  from public.v1_permission_role_defaults role_default
  where role_default.role_name = v_role
    and role_default.capability_key = p_capability_key;
  return jsonb_build_object(
    'effective', coalesce(v_default, false),
    'source', case when coalesce(v_default, false)
      then 'role_default' else 'none' end
  );
end;
$$;

create or replace function public.v1_permission_legacy_resolution(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_dependency text;
  v_dependency_result jsonb;
begin
  v_result := public.v1_permission_legacy_raw(
    p_auth_user_id, p_capability_key, p_project_id
  );
  if not coalesce((v_result ->> 'effective')::boolean, false) then
    return v_result;
  end if;
  for v_dependency in
    select unnest(catalog.dependencies)
    from public.v1_capability_catalog catalog
    where catalog.capability_key = p_capability_key
  loop
    v_dependency_result := public.v1_permission_legacy_resolution(
      p_auth_user_id, v_dependency, p_project_id
    );
    if not coalesce(
      (v_dependency_result ->> 'effective')::boolean,
      false
    ) then
      return jsonb_build_object(
        'effective', false,
        'source', 'hard_invariant',
        'missing_dependency', v_dependency
      );
    end if;
  end loop;
  return v_result;
end;
$$;

create or replace function public.v1_permission_authoritative_resolution(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_mode text;
begin
  select catalog.authorization_mode into v_mode
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;
  if v_mode is null then
    return jsonb_build_object('effective', false, 'source', 'unknown');
  end if;
  if v_mode = 'enforced' then
    return public.v1_permission_candidate_resolution(
      p_auth_user_id, p_capability_key, p_project_id
    );
  end if;
  return public.v1_permission_legacy_resolution(
    p_auth_user_id, p_capability_key, p_project_id
  );
end;
$$;

-- Pre-cutover parity is a reusable database release gate, not a handwritten
-- deployment query. It compares the legacy and candidate decision for every
-- active canonical profile at organization scope and, for project-bound
-- capabilities, at every project structurally accessible to that profile.
-- The report contains only stable application/capability/project identifiers
-- and counts; it never includes names, emails, Auth UUIDs or domain payloads.
create or replace function public.v1_permission_cutover_parity_report(
  p_capability_keys text[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_keys text[];
  v_requested_count integer;
  v_catalog_count integer;
  v_result jsonb;
begin
  select coalesce(array_agg(key order by key), '{}'::text[])
  into v_keys
  from (
    select distinct nullif(btrim(value), '') as key
    from unnest(coalesce(p_capability_keys, '{}'::text[])) value
  ) requested
  where key is not null;
  v_requested_count := cardinality(coalesce(p_capability_keys, '{}'::text[]));
  if cardinality(v_keys) = 0
    or cardinality(v_keys) <> v_requested_count then
    raise exception 'V1_PERMISSION_CUTOVER_PARITY_KEYS_INVALID'
      using errcode = '22023';
  end if;
  select count(*)::integer into v_catalog_count
  from public.v1_capability_catalog catalog
  where catalog.capability_key = any(v_keys)
    and catalog.status = 'operational';
  if v_catalog_count <> cardinality(v_keys) then
    raise exception 'V1_PERMISSION_CUTOVER_PARITY_CATALOG_MISMATCH'
      using errcode = '22023';
  end if;

  with active_profile as (
    select profile.auth_user_id, profile.legacy_app_user_id
    from public.v1_profiles profile
    where nullif(btrim(profile.legacy_app_user_id), '') is not null
      and public.v1_permission_exact_role(profile.auth_user_id) <> ''
  ), requested_capability as (
    select catalog.capability_key, catalog.requires_project_access
    from public.v1_capability_catalog catalog
    where catalog.capability_key = any(v_keys)
  ), decision as (
    select
      profile.legacy_app_user_id as app_user_id,
      capability.capability_key,
      'organization'::text as scope_kind,
      null::uuid as project_id,
      coalesce((public.v1_permission_legacy_resolution(
        profile.auth_user_id, capability.capability_key, null
      ) ->> 'effective')::boolean, false) as legacy_effective,
      coalesce((public.v1_permission_candidate_resolution(
        profile.auth_user_id, capability.capability_key, null
      ) ->> 'effective')::boolean, false) as candidate_effective
    from active_profile profile
    cross join requested_capability capability
    union all
    select
      profile.legacy_app_user_id,
      capability.capability_key,
      'project'::text,
      project.id,
      coalesce((public.v1_permission_legacy_resolution(
        profile.auth_user_id, capability.capability_key, project.id
      ) ->> 'effective')::boolean, false),
      coalesce((public.v1_permission_candidate_resolution(
        profile.auth_user_id, capability.capability_key, project.id
      ) ->> 'effective')::boolean, false)
    from active_profile profile
    join requested_capability capability
      on capability.requires_project_access
    join public.v1_projects project
      on public.v1_permission_has_project_access(
        profile.auth_user_id, project.id
      )
  ), mismatch as (
    select *
    from decision
    where legacy_effective is distinct from candidate_effective
  )
  select jsonb_build_object(
    'schema_version', 1,
    'capability_keys', to_jsonb(v_keys),
    'active_profile_count', (select count(*) from active_profile),
    'decision_count', (select count(*) from decision),
    'mismatch_count', (select count(*) from mismatch),
    'mismatches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'app_user_id', limited.app_user_id,
        'capability_key', limited.capability_key,
        'scope_kind', limited.scope_kind,
        'project_id', limited.project_id,
        'legacy_effective', limited.legacy_effective,
        'candidate_effective', limited.candidate_effective
      ) order by limited.app_user_id, limited.capability_key,
        limited.scope_kind, limited.project_id)
      from (
        select *
        from mismatch
        order by app_user_id, capability_key, scope_kind, project_id
        limit 50
      ) limited
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.v1_assert_permission_cutover_parity(
  p_capability_keys text[]
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_report jsonb := public.v1_permission_cutover_parity_report(
    p_capability_keys
  );
begin
  if coalesce((v_report ->> 'mismatch_count')::bigint, 0) <> 0 then
    raise exception 'V1_PERMISSION_CUTOVER_PARITY_MISMATCH'
      using errcode = '23514', detail = v_report::text;
  end if;
  return v_report;
end;
$$;

-- Safe, target-free decision endpoint for Edge actions and future protected
-- workflow consumers. Unknown capability keys and stale identities fail closed.
create or replace function public.v1_current_user_has_capability(
  p_capability_key text,
  p_project_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and coalesce((
      public.v1_permission_authoritative_resolution(
        auth.uid(), p_capability_key, p_project_id
      ) ->> 'effective'
    )::boolean, false);
$$;

create or replace function public.v1_permission_guard_assignment_project()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.v1_permission_assignments%rowtype;
begin
  select * into v_assignment
  from public.v1_permission_assignments assignment
  where assignment.id = new.assignment_id;
  if not found or v_assignment.scope_kind <> 'project' then
    raise exception 'V1_PERMISSION_PROJECT_SCOPE_REQUIRED'
      using errcode = '23514';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'v1_permission_project_effect|' ||
      v_assignment.auth_user_id::text || '|' ||
      v_assignment.capability_key || '|' || new.project_id::text,
      0
    )
  );
  if exists (
    select 1
    from public.v1_permission_assignments opposite
    join public.v1_permission_assignment_projects opposite_project
      on opposite_project.assignment_id = opposite.id
    where opposite.auth_user_id = v_assignment.auth_user_id
      and opposite.capability_key = v_assignment.capability_key
      and opposite.scope_kind = 'project'
      and opposite.effect <> v_assignment.effect
      and opposite_project.project_id = new.project_id
  ) then
    raise exception 'V1_PERMISSION_CONFLICTING_PROJECT_EFFECT'
      using errcode = '23505';
  end if;
  return new;
end;
$$;

create trigger v1_permission_guard_assignment_project
before insert or update on public.v1_permission_assignment_projects
for each row execute function public.v1_permission_guard_assignment_project();

create or replace function public.v1_permission_guard_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = new.capability_key;
  if not found
    or new.scope_kind <> all(v_catalog.allowed_scope_kinds)
    or v_catalog.status <> 'operational'
    or not v_catalog.is_assignable then
    raise exception 'V1_PERMISSION_ASSIGNMENT_NOT_ALLOWED'
      using errcode = '42501';
  end if;

  -- Permission-administration continuity cannot depend on a future database
  -- clock boundary. No transaction runs when an effective_until timestamp is
  -- reached, so two otherwise-valid schedules could silently expire the last
  -- manager after both mutations had committed. Keep the complete dependency
  -- chain immediate and open-ended; ordinary capabilities remain schedulable.
  if new.capability_key = any(array[
      'users.view', 'permissions.view',
      'permissions.manage', 'permissions.delegate'
    ]::text[])
    and (
      new.effective_from > clock_timestamp()
      or new.effective_until is not null
    ) then
    raise exception 'V1_PERMISSION_MANAGER_SCHEDULE_FORBIDDEN'
      using errcode = '23514';
  end if;

  new.updated_at := clock_timestamp();
  if tg_op = 'UPDATE' then
    new.version := old.version + 1;
    if new.id <> old.id
      or new.auth_user_id <> old.auth_user_id
      or new.capability_key <> old.capability_key
      or new.scope_kind <> old.scope_kind
      or new.effect <> old.effect
      or new.origin <> old.origin
      or new.created_at <> old.created_at then
      raise exception 'V1_PERMISSION_ASSIGNMENT_IDENTITY_IMMUTABLE'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger v1_permission_guard_assignment
before insert or update on public.v1_permission_assignments
for each row execute function public.v1_permission_guard_assignment();

create or replace function public.v1_permission_history_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'V1_PERMISSION_HISTORY_IMMUTABLE'
    using errcode = '42501';
end;
$$;

create trigger v1_permission_history_immutable
before update or delete on public.v1_permission_change_events
for each row execute function public.v1_permission_history_immutable();

create or replace function public.v1_permission_mode_summary()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when bool_and(catalog.authorization_mode = 'shadow') then 'shadow'
    when bool_and(catalog.authorization_mode = 'enforced') then 'enforced'
    else 'mixed'
  end
  from public.v1_capability_catalog catalog
  where catalog.status = 'operational';
$$;

create or replace function public.v1_permission_actor_can_view()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_user_has_capability('permissions.view', null);
$$;

create or replace function public.v1_permission_actor_can_manage()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_user_has_capability('permissions.manage', null);
$$;

create or replace function public.v1_permission_actor_can_delegate(
  p_capability_key text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_permission_actor_can_manage()
    and (
      p_capability_key not like 'permissions.%'
      or public.v1_current_user_has_capability('permissions.delegate', null)
    )
    and exists (
      select 1
      from public.v1_permission_role_defaults role_default
      where role_default.role_name = public.v1_current_exact_role()
        and role_default.capability_key = p_capability_key
        and role_default.can_delegate
    );
$$;

-- A permission administrator may only name a project that the same live actor
-- can currently read through the authoritative project capability. Structural
-- membership/global-role access alone is insufficient when an explicit deny
-- has removed projects.view for that project.
create or replace function public.v1_permission_actor_can_view_project(
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and p_project_id is not null
    and public.v1_current_actor_is_active()
    and coalesce((
      public.v1_permission_authoritative_resolution(
        auth.uid(), 'projects.view', p_project_id
      ) ->> 'effective'
    )::boolean, false);
$$;

create or replace function public.v1_permission_actor_has_full_project_visibility(
  p_project_ids uuid[]
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select cardinality(coalesce(p_project_ids, '{}'::uuid[])) > 0
    and not exists (
      select 1
      from unnest(coalesce(p_project_ids, '{}'::uuid[])) project_id
      where not public.v1_permission_actor_can_view_project(project_id)
    );
$$;

-- Organization scope for a project-bound capability is stronger than a
-- projects.view_all marker: the actor must belong to an exact role whose
-- structural contract covers every project state, retain the authoritative
-- all-project capability, and currently resolve projects.view on every
-- existing project. Procurement intentionally fails this predicate because
-- its structural context excludes completed/archived projects.
create or replace function public.v1_permission_actor_has_unrestricted_project_authority()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_exact_role() in (
      'admin', 'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    and public.v1_current_user_has_capability('projects.view_all', null)
    and not exists (
      select 1
      from public.v1_projects project
      where not public.v1_permission_actor_can_view_project(project.id)
    );
$$;

-- Read projection scope is separate from mutation authority: permissions.view
-- may inspect only assignments whose complete scope is visible. An
-- organization assignment for a project-bound capability therefore requires
-- all-project authority even when the viewer is not allowed to edit it.
create or replace function public.v1_permission_actor_can_view_assignment_scope(
  p_capability_key text,
  p_scope_kind text,
  p_project_ids uuid[] default '{}'::uuid[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_requires_project_access boolean;
begin
  select catalog.requires_project_access
  into v_requires_project_access
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key
    and catalog.status = 'operational';
  if not found then
    return false;
  end if;
  if p_scope_kind = 'organization' then
    return cardinality(coalesce(p_project_ids, '{}'::uuid[])) = 0
      and (
        not v_requires_project_access
        or public.v1_permission_actor_has_unrestricted_project_authority()
      );
  end if;
  return p_scope_kind = 'project'
    and public.v1_permission_actor_has_full_project_visibility(
      p_project_ids
    );
end;
$$;

-- One durable scope predicate is shared by set, clear and the advisory
-- workspace projection. Organization-wide assignment of a project-bound
-- capability requires the immutable/nonassignable all-project authority;
-- project scope requires access to every selected project.
create or replace function public.v1_permission_actor_can_administer_scope(
  p_capability_key text,
  p_scope_kind text,
  p_project_ids uuid[] default '{}'::uuid[]
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_project_ids uuid[] := coalesce(p_project_ids, '{}'::uuid[]);
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key
    and catalog.status = 'operational'
    and catalog.is_assignable;
  if not found
    or p_scope_kind <> all(v_catalog.allowed_scope_kinds)
    or not public.v1_permission_actor_can_delegate(p_capability_key) then
    return false;
  end if;

  if p_scope_kind = 'organization' then
    return cardinality(v_project_ids) = 0
      and (
        not v_catalog.requires_project_access
        or public.v1_permission_actor_has_unrestricted_project_authority()
      );
  end if;
  if p_scope_kind <> 'project' or cardinality(v_project_ids) = 0 then
    return false;
  end if;
  return public.v1_permission_actor_has_full_project_visibility(
    v_project_ids
  );
end;
$$;

-- The client receives a scope ceiling directly from the trusted server and
-- must fail closed when this array is absent or empty. It never infers broad
-- organization authority from an exact-role label.
create or replace function public.v1_permission_actor_delegable_scope_kinds(
  p_capability_key text
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_result text[] := '{}'::text[];
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key
    and catalog.status = 'operational'
    and catalog.is_assignable;
  if not found
    or not public.v1_permission_actor_can_delegate(p_capability_key) then
    return v_result;
  end if;
  if 'organization' = any(v_catalog.allowed_scope_kinds)
    and (
      not v_catalog.requires_project_access
      or public.v1_permission_actor_has_unrestricted_project_authority()
    ) then
    v_result := array_append(v_result, 'organization');
  end if;
  if 'project' = any(v_catalog.allowed_scope_kinds)
    and exists (
      select 1
      from public.v1_projects project
      where public.v1_permission_actor_can_view_project(project.id)
    ) then
    v_result := array_append(v_result, 'project');
  end if;
  return v_result;
end;
$$;

-- Security-definer JSON builders must apply the caller's project boundary
-- explicitly. These helpers redact both current assignments and retained
-- before/after history without revealing an inaccessible project identifier.
create or replace function public.v1_permission_visible_project_ids(
  p_project_ids uuid[]
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(project_id order by project_id), '[]'::jsonb)
  from unnest(coalesce(p_project_ids, '{}'::uuid[])) project_id
  where public.v1_permission_actor_can_view_project(project_id);
$$;

create or replace function public.v1_permission_visible_assignment_state(
  p_state jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_project_ids uuid[];
  v_result jsonb := '[]'::jsonb;
begin
  if p_state is null then
    return null;
  end if;
  if jsonb_typeof(p_state) <> 'array' then
    return null;
  end if;
  for v_item in select value from jsonb_array_elements(p_state)
  loop
    if jsonb_typeof(v_item) = 'object' then
      v_item := v_item - 'project_id' - 'project_ref' - 'project_name';
      if jsonb_typeof(v_item -> 'project_ids') = 'array' then
        select coalesce(array_agg(value::uuid), '{}'::uuid[])
        into v_project_ids
        from jsonb_array_elements_text(v_item -> 'project_ids') value
        where value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
        v_item := jsonb_set(
          v_item,
          '{project_ids}',
          public.v1_permission_visible_project_ids(v_project_ids),
          true
        );
      end if;
      v_result := v_result || jsonb_build_array(v_item);
    end if;
  end loop;
  return v_result;
end;
$$;

-- Internal exact-role template ceiling shared by existing-target mutation and
-- pre-creation checks. users.create alone is intentionally insufficient: an
-- actor must also hold users.roles.assign before a requested Auth role can be
-- stamped.
create or replace function public.v1_permission_actor_can_assign_role_template(
  p_requested_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_role text;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  v_actor_role := public.v1_permission_exact_role(v_actor);
  if v_actor_role = ''
    or p_requested_exact_role is null
    or not coalesce(
      public.v1_is_valid_role(p_requested_exact_role), false
    ) then
    return false;
  end if;
  if not public.v1_current_user_has_capability(
    'users.roles.assign', null
  ) then
    return false;
  end if;

  -- Exact Admin and Senior Mechanical Engineer retain their established full
  -- exact-role assignment surface. This is a deliberate compatibility
  -- exception: capability delegation by SME remains bounded below, but the
  -- initial cutover must not silently remove existing User Management power.
  if v_actor_role in ('admin', 'senior_mechanical_engineer') then
    return true;
  end if;

  if not public.v1_current_user_has_capability(
    'permissions.delegate', null
  ) then
    return false;
  end if;

  return not exists (
    select 1
    from public.v1_permission_role_defaults requested_default
    join public.v1_capability_catalog catalog
      on catalog.capability_key = requested_default.capability_key
    where requested_default.role_name = p_requested_exact_role
      and requested_default.is_granted
      and catalog.status = 'operational'
      and not exists (
        select 1
        from public.v1_permission_role_defaults actor_ceiling
        where actor_ceiling.role_name = v_actor_role
          and actor_ceiling.capability_key = requested_default.capability_key
          and actor_ceiling.can_delegate
      )
  );
end;
$$;

-- Preflight for an existing-target admin-users Edge role mutation. The client
-- supplies only the stable Yorks application user ID; target Auth UUIDs and
-- both role templates stay inside the trusted database boundary. Self-role
-- mutation, stale/inactive actors, invalid roles and missing targets fail
-- closed.
create or replace function public.v1_current_user_can_assign_exact_role(
  p_target_app_user_id text,
  p_requested_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null or v_target = v_actor then
    return false;
  end if;
  return public.v1_permission_actor_can_assign_role_template(
    p_requested_exact_role
  );
end;
$$;

-- Preflight used before GoTrue creates a new identity. This closes the gap
-- where users.create could otherwise stamp an exact role outside the actor's
-- delegation ceiling before any stable target existed.
create or replace function public.v1_current_user_can_assign_new_exact_role(
  p_requested_exact_role text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_permission_actor_can_assign_role_template(
    p_requested_exact_role
  );
$$;

create or replace function public.v1_permission_assignment_json(
  p_assignment_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', assignment.id,
    'capability_key', assignment.capability_key,
    'effect', assignment.effect,
    'scope_kind', assignment.scope_kind,
    'origin', assignment.origin,
    -- This is the authoritative persisted/audit snapshot builder. It must not
    -- depend on auth.uid(); viewer-specific omission/redaction belongs only in
    -- workspace and history response builders below.
    'project_ids', to_jsonb(array(
      select assignment_project.project_id
      from public.v1_permission_assignment_projects assignment_project
      where assignment_project.assignment_id = assignment.id
      order by assignment_project.project_id
    )),
    'effective_from', assignment.effective_from,
    'effective_until', assignment.effective_until,
    'reason', assignment.reason,
    'version', assignment.version,
    'changed_by', case
      when actor.auth_user_id is null then jsonb_build_object(
        'actor_kind', 'system',
        'app_user_id', null,
        'display_name', 'System migration',
        'exact_role', 'system'
      )
      else jsonb_build_object(
        'actor_kind', 'user',
        'app_user_id', actor.legacy_app_user_id,
        'display_name', actor.display_name,
        'exact_role', public.v1_permission_display_exact_role(
          actor.auth_user_id
        )
      )
    end,
    'created_at', assignment.created_at,
    'updated_at', assignment.updated_at
  )
  from public.v1_permission_assignments assignment
  left join public.v1_profiles actor
    on actor.auth_user_id = assignment.changed_by_auth_user_id
  where assignment.id = p_assignment_id;
$$;

create or replace function public.v1_permission_scope_state_json(
  p_auth_user_id uuid,
  p_capability_key text,
  p_scope_kind text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    public.v1_permission_assignment_json(assignment.id)
    order by assignment.effect, assignment.id
  ), '[]'::jsonb)
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_auth_user_id
    and assignment.capability_key = p_capability_key
    and assignment.scope_kind = p_scope_kind;
$$;

-- Keep the retained commercial authority and the shadow candidate projection
-- convergent while its established RPC remains the operational writer. A new
-- permission-management override intentionally takes ownership and is never
-- overwritten by this compatibility trigger.
create or replace function public.v1_permission_sync_legacy_commercial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_target uuid := coalesce(new.auth_user_id, old.auth_user_id);
  v_legacy_capability text := coalesce(new.capability, old.capability);
  v_capability_key text;
  v_assignment_id uuid;
  v_before jsonb;
  v_after jsonb;
  v_revision bigint;
  v_actor uuid := case when tg_op = 'DELETE'
    then old.changed_by_auth_user_id else new.changed_by_auth_user_id end;
  v_actor_role text;
  v_reason text := case when tg_op = 'DELETE'
    then old.reason else new.reason end;
begin
  v_capability_key := case v_legacy_capability
    when 'view_commercials' then 'commercials.view'
    when 'manage_commercials' then 'commercials.manage'
    else null
  end;
  if v_capability_key is null or exists (
    select 1
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id = v_target
      and assignment.capability_key = v_capability_key
      and assignment.scope_kind = 'organization'
      and assignment.origin = 'permission_management'
  ) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  v_before := public.v1_permission_scope_state_json(
    v_target, v_capability_key, 'organization'
  );
  delete from public.v1_permission_assignments assignment
  where assignment.auth_user_id = v_target
    and assignment.capability_key = v_capability_key
    and assignment.scope_kind = 'organization'
    and assignment.origin = 'legacy_commercial';

  if tg_op <> 'DELETE' then
    insert into public.v1_permission_assignments (
      auth_user_id, capability_key, effect, scope_kind, origin,
      effective_from, reason, changed_by_auth_user_id,
      created_at, updated_at
    ) values (
      v_target, v_capability_key,
      case when new.is_granted then 'grant' else 'deny' end,
      'organization', 'legacy_commercial',
      least(new.created_at, new.updated_at), new.reason,
      new.changed_by_auth_user_id, new.created_at, new.updated_at
    ) returning id into v_assignment_id;
  end if;
  v_after := public.v1_permission_scope_state_json(
    v_target, v_capability_key, 'organization'
  );

  update public.v1_permission_revisions revision
  set revision = revision.revision + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
  where revision.auth_user_id = v_target
  returning revision.revision into v_revision;
  if not found then
    raise exception 'V1_PERMISSION_TARGET_REVISION_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  v_actor_role := coalesce(nullif(
    public.v1_permission_display_exact_role(v_actor), ''
  ), 'system');
  insert into public.v1_permission_change_events (
    target_auth_user_id, event_kind, capability_key, effect, scope_kind,
    project_ids, before_state, after_state, reason,
    actor_auth_user_id, actor_exact_role, revision, event_ordinal
  ) values (
    v_target, 'legacy_sync', v_capability_key,
    case when tg_op = 'DELETE' then null
      when new.is_granted then 'grant' else 'deny' end,
    'organization', '{}'::uuid[], v_before, v_after,
    coalesce(nullif(btrim(v_reason), ''), 'Legacy commercial synchronization'),
    case when v_actor_role = 'system' then null else v_actor end,
    v_actor_role, v_revision, 1
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger v1_permission_sync_legacy_commercial
after insert or update or delete on public.v1_user_capabilities
for each row execute function public.v1_permission_sync_legacy_commercial();

create or replace function public.v1_permission_capability_json(
  p_auth_user_id uuid,
  p_capability_key text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_role text := public.v1_permission_exact_role(p_auth_user_id);
  v_role_default boolean := false;
  v_authoritative jsonb;
  v_candidate jsonb;
  v_project_overrides jsonb;
  v_organization_summary_visible boolean;
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;
  if not found then
    return null;
  end if;
  select role_default.is_granted into v_role_default
  from public.v1_permission_role_defaults role_default
  where role_default.role_name = v_role
    and role_default.capability_key = p_capability_key;

  v_authoritative := public.v1_permission_authoritative_resolution(
    p_auth_user_id, p_capability_key, null
  );
  v_candidate := public.v1_permission_candidate_resolution(
    p_auth_user_id, p_capability_key, null
  );
  v_organization_summary_visible := not v_catalog.requires_project_access
    or public.v1_permission_actor_has_unrestricted_project_authority();

  -- Every project that is structurally available to the target and currently
  -- visible to the actor receives a resolution row, even when this exact
  -- capability has no project assignment. This is required for a project deny
  -- on a dependency (for example projects.view) to propagate into the client
  -- presentation for boq.edit and every other dependent capability.
  select coalesce(jsonb_agg(jsonb_build_object(
    'assignment_id', case when project_assignment.scope_fully_visible
      then project_assignment.id else null end,
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'effect', case when project_assignment.scope_fully_visible
      then project_assignment.effect else null end,
    'has_project_access', public.v1_permission_has_project_access(
      p_auth_user_id, project.id
    ),
    'authoritative_effective', coalesce((
      public.v1_permission_authoritative_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'effective'
    )::boolean, false),
    'authoritative_source', coalesce(
      public.v1_permission_authoritative_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'source',
      'unknown'
    ),
    'candidate_effective', coalesce((
      public.v1_permission_candidate_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'effective'
    )::boolean, false),
    'candidate_source', coalesce(
      public.v1_permission_candidate_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'source',
      'unknown'
    ),
    'parity', coalesce((
      public.v1_permission_authoritative_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'effective'
    )::boolean, false) = coalesce((
      public.v1_permission_candidate_resolution(
        p_auth_user_id, p_capability_key, project.id
      ) ->> 'effective'
    )::boolean, false),
    'effective_from', case when project_assignment.scope_fully_visible
      then project_assignment.effective_from else null end,
    'effective_until', case when project_assignment.scope_fully_visible
      then project_assignment.effective_until else null end
  ) order by project.project_ref, project.id), '[]'::jsonb)
  into v_project_overrides
  from public.v1_projects project
  left join lateral (
    select
      assignment.id,
      assignment.effect,
      assignment.effective_from,
      assignment.effective_until,
      public.v1_permission_actor_can_view_assignment_scope(
        assignment.capability_key,
        assignment.scope_kind,
        array(
          select complete_scope.project_id
          from public.v1_permission_assignment_projects complete_scope
          where complete_scope.assignment_id = assignment.id
          order by complete_scope.project_id
        )
      ) as scope_fully_visible
    from public.v1_permission_assignments assignment
    join public.v1_permission_assignment_projects assignment_project
      on assignment_project.assignment_id = assignment.id
    where assignment.auth_user_id = p_auth_user_id
      and assignment.capability_key = p_capability_key
      and assignment.scope_kind = 'project'
      and assignment_project.project_id = project.id
    order by assignment.effect, assignment.id
    limit 1
  ) project_assignment on true
  where v_catalog.requires_project_access
    and public.v1_permission_has_project_access(
      p_auth_user_id, project.id
    )
    and public.v1_permission_actor_can_view_project(project.id);

  return jsonb_build_object(
    'capability_key', v_catalog.capability_key,
    'module_key', v_catalog.module_key,
    'action_key', v_catalog.action_key,
    'label', v_catalog.label,
    'description', v_catalog.description,
    'risk_level', v_catalog.risk_level,
    'allowed_scope_kinds', to_jsonb(v_catalog.allowed_scope_kinds),
    'requires_project_access', v_catalog.requires_project_access,
    'dependencies', to_jsonb(v_catalog.dependencies),
    'runtime_status', v_catalog.status,
    'is_assignable', v_catalog.is_assignable,
    -- This projection is about the live actor, never the target. It lets the
    -- client disable controls above the actor's exact-role delegation ceiling
    -- without exposing any additional target data. The mutation RPC repeats
    -- the same check and remains authoritative.
    'actor_can_delegate', public.v1_permission_actor_can_delegate(
      v_catalog.capability_key
    ),
    'actor_delegable_scope_kinds', to_jsonb(
      public.v1_permission_actor_delegable_scope_kinds(
        v_catalog.capability_key
      )
    ),
    'display_order', v_catalog.display_order,
    'authorization_mode', v_catalog.authorization_mode,
    'role_default', coalesce(v_role_default, false),
    'organization_summary_visible', v_organization_summary_visible,
    'authoritative_effective', case when v_organization_summary_visible
      then coalesce((v_authoritative ->> 'effective')::boolean, false)
      else null end,
    'authoritative_source', case when v_organization_summary_visible
      then coalesce(v_authoritative ->> 'source', 'unknown')
      else null end,
    'candidate_effective', case when v_organization_summary_visible
      then coalesce((v_candidate ->> 'effective')::boolean, false)
      else null end,
    'candidate_source', case when v_organization_summary_visible
      then coalesce(v_candidate ->> 'source', 'unknown')
      else null end,
    'parity', case when v_organization_summary_visible
      then coalesce((v_authoritative ->> 'effective')::boolean, false)
        = coalesce((v_candidate ->> 'effective')::boolean, false)
      else null end,
    'project_overrides', v_project_overrides
  );
end;
$$;

create or replace function public.v1_permission_history_json(
  p_target_auth_user_id uuid,
  p_limit integer default 50,
  p_before_occurred_at timestamptz default null,
  p_before_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with authorized as (
    select event.*
    from public.v1_permission_change_events event
    join public.v1_capability_catalog catalog
      on catalog.capability_key = event.capability_key
    where event.target_auth_user_id = p_target_auth_user_id
      and (
        p_before_occurred_at is null
        or (event.occurred_at, event.id) <
          (p_before_occurred_at, p_before_id)
      )
      and (
        (
          event.scope_kind = 'organization'
          and (
            not catalog.requires_project_access
            or public.v1_permission_actor_has_unrestricted_project_authority()
          )
        )
        or (
          event.scope_kind = 'project'
          and exists (
            select 1
            from unnest(event.project_ids) project_id
            where public.v1_permission_actor_can_view_project(project_id)
          )
        )
      )
  ), page as (
    select *
    from authorized
    order by occurred_at desc, id desc
    limit greatest(1, least(coalesce(p_limit, 50), 200)) + 1
  ), visible as (
    select * from page
    order by occurred_at desc, id desc
    limit greatest(1, least(coalesce(p_limit, 50), 200))
  ), rendered as (
    select jsonb_build_object(
      'id', event.id,
      'event_kind', event.event_kind,
      'capability_key', event.capability_key,
      'effect', event.effect,
      'scope_kind', event.scope_kind,
      'project_ids', public.v1_permission_visible_project_ids(
        event.project_ids
      ),
      'actor_can_administer_scope',
        public.v1_permission_actor_can_administer_scope(
          event.capability_key, event.scope_kind, event.project_ids
        ),
      -- A mixed-scope event is useful as a signal for the visible project, but
      -- its retained assignment snapshots can carry hidden-project reasons,
      -- effective windows or identifiers. Suppress those snapshots entirely
      -- unless the caller can see the event's complete project scope.
      'before', case
        when event.scope_kind = 'project'
          and jsonb_array_length(
            public.v1_permission_visible_project_ids(event.project_ids)
          ) < cardinality(event.project_ids)
        then null
        else public.v1_permission_visible_assignment_state(
          event.before_state
        )
      end,
      'after', case
        when event.scope_kind = 'project'
          and jsonb_array_length(
            public.v1_permission_visible_project_ids(event.project_ids)
          ) < cardinality(event.project_ids)
        then null
        else public.v1_permission_visible_assignment_state(
          event.after_state
        )
      end,
      'reason', case
        when event.scope_kind = 'project'
          and jsonb_array_length(
            public.v1_permission_visible_project_ids(event.project_ids)
          ) < cardinality(event.project_ids)
        then 'Partially visible project-scoped permission change'
        else event.reason
      end,
      'actor', jsonb_build_object(
        'actor_kind', case when event.actor_exact_role = 'system'
          then 'system' else 'user' end,
        'app_user_id', actor.legacy_app_user_id,
        'display_name', case when event.actor_exact_role = 'system'
          then 'System migration' else actor.display_name end,
        'exact_role', event.actor_exact_role
      ),
      'occurred_at', event.occurred_at,
      'idempotency_key', event.idempotency_key,
      'revision', event.revision,
      'event_ordinal', event.event_ordinal
    ) as item,
    event.occurred_at,
    event.id
    from visible event
    left join public.v1_profiles actor
      on actor.auth_user_id = event.actor_auth_user_id
  ), final_cursor as (
    select occurred_at, id
    from visible
    order by occurred_at asc, id asc
    limit 1
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(rendered.item order by rendered.occurred_at desc, rendered.id desc)
      from rendered
    ), '[]'::jsonb),
    'next_cursor', case when (select count(*) from page) >
      greatest(1, least(coalesce(p_limit, 50), 200))
      then (select jsonb_build_object(
        'occurred_at', final_cursor.occurred_at,
        'id', final_cursor.id
      ) from final_cursor)
      else null end
  );
$$;

create or replace function public.v1_permission_workspace_json(
  p_target_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_profile public.v1_profiles%rowtype;
  v_exact_role text;
  v_revision bigint;
  v_capabilities jsonb;
  v_assignments jsonb;
  v_projects jsonb;
  v_history jsonb;
begin
  select * into v_profile
  from public.v1_profiles profile
  where profile.auth_user_id = p_target_auth_user_id;
  if not found or nullif(btrim(v_profile.legacy_app_user_id), '') is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  v_exact_role := public.v1_permission_exact_role(p_target_auth_user_id);
  select revision.revision into v_revision
  from public.v1_permission_revisions revision
  where revision.auth_user_id = p_target_auth_user_id;

  select coalesce(jsonb_agg(
    public.v1_permission_capability_json(
      p_target_auth_user_id, catalog.capability_key
    ) order by catalog.display_order
  ), '[]'::jsonb)
  into v_capabilities
  from public.v1_capability_catalog catalog;

  select coalesce(jsonb_agg(
    public.v1_permission_assignment_json(assignment.id)
      || jsonb_build_object(
        'actor_can_administer_scope',
        public.v1_permission_actor_can_administer_scope(
          assignment.capability_key,
          assignment.scope_kind,
          array(
            select assignment_project.project_id
            from public.v1_permission_assignment_projects assignment_project
            where assignment_project.assignment_id = assignment.id
            order by assignment_project.project_id
          )
        )
      )
    order by assignment.capability_key, assignment.scope_kind,
      assignment.effect
  ), '[]'::jsonb)
  into v_assignments
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_target_auth_user_id
    and public.v1_permission_actor_can_view_assignment_scope(
      assignment.capability_key,
      assignment.scope_kind,
      array(
        select assignment_project.project_id
        from public.v1_permission_assignment_projects assignment_project
        where assignment_project.assignment_id = assignment.id
        order by assignment_project.project_id
      )
    );

  select coalesce(jsonb_agg(jsonb_build_object(
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'state', project.state,
    'has_access', true
  ) order by project.project_ref, project.id), '[]'::jsonb)
  into v_projects
  from public.v1_projects project
  where public.v1_permission_has_project_access(
    p_target_auth_user_id, project.id
  )
    and public.v1_permission_actor_can_view_project(project.id);

  v_history := public.v1_permission_history_json(
    p_target_auth_user_id, 25, null, null
  );

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', public.v1_permission_mode_summary(),
    'generated_at', clock_timestamp(),
    'actor', (
      select jsonb_build_object(
        'actor_kind', 'user',
        'app_user_id', actor.legacy_app_user_id,
        'display_name', actor.display_name,
        'exact_role', public.v1_permission_display_exact_role(
          actor.auth_user_id
        )
      )
      from public.v1_profiles actor
      where actor.auth_user_id = auth.uid()
    ),
    'target', jsonb_build_object(
      'app_user_id', v_profile.legacy_app_user_id,
      'display_name', v_profile.display_name,
      'exact_role', public.v1_permission_display_exact_role(
        p_target_auth_user_id
      ),
      'is_active', v_exact_role <> ''
    ),
    'revision', coalesce(v_revision, 0),
    'catalog', v_capabilities,
    'assignments', v_assignments,
    'projects', v_projects,
    'recent_history', coalesce(v_history -> 'items', '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_get_current_permission_snapshot()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.v1_profiles%rowtype;
  v_workspace jsonb;
  v_next_transition_at timestamptz;
begin
  if v_actor is null then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  select * into v_profile
  from public.v1_profiles profile
  where profile.auth_user_id = v_actor;
  insert into public.v1_permission_revisions (
    auth_user_id, app_user_id
  ) values (v_actor, v_profile.legacy_app_user_id)
  on conflict (auth_user_id) do update
    set app_user_id = excluded.app_user_id
    where public.v1_permission_revisions.app_user_id
      is distinct from excluded.app_user_id;

  v_workspace := public.v1_permission_workspace_json(v_actor);
  select min(transition_at) into v_next_transition_at
  from (
    select assignment.effective_from as transition_at
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id = v_actor
      and assignment.effective_from > clock_timestamp()
    union all
    select assignment.effective_until
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id = v_actor
      and assignment.effective_until > clock_timestamp()
    union all
    select member.effective_from
    from public.v1_project_members member
    where member.member_auth_user_id = v_actor
      and member.effective_from > clock_timestamp()
    union all
    select member.effective_to
    from public.v1_project_members member
    where member.member_auth_user_id = v_actor
      and member.effective_to > clock_timestamp()
  ) transitions;
  return jsonb_build_object(
    'schema_version', v_workspace -> 'schema_version',
    'authorization_mode', v_workspace -> 'authorization_mode',
    'generated_at', v_workspace -> 'generated_at',
    'next_transition_at', v_next_transition_at,
    'user', v_workspace -> 'target',
    'revision', v_workspace -> 'revision',
    'capabilities', v_workspace -> 'catalog',
    'project_access', v_workspace -> 'projects'
  );
end;
$$;

create or replace function public.v1_get_user_permission_workspace(
  p_target_app_user_id text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_target uuid;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  if not public.v1_permission_actor_can_view() then
    raise exception 'V1_PERMISSION_WORKSPACE_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  return public.v1_permission_workspace_json(v_target);
end;
$$;

create or replace function public.v1_list_user_permission_history(
  p_target_app_user_id text,
  p_limit integer default 50,
  p_before_occurred_at timestamptz default null,
  p_before_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_target uuid;
  v_page jsonb;
begin
  if auth.uid() is null
    or not public.v1_current_actor_is_active()
    or not public.v1_permission_actor_can_view() then
    raise exception 'V1_PERMISSION_HISTORY_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  if (p_before_occurred_at is null) <> (p_before_id is null) then
    raise exception 'V1_PERMISSION_HISTORY_CURSOR_INVALID'
      using errcode = '22023';
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  v_page := public.v1_permission_history_json(
    v_target, p_limit, p_before_occurred_at, p_before_id
  );
  return jsonb_build_object(
    'schema_version', 1,
    'target_app_user_id', p_target_app_user_id,
    'items', v_page -> 'items',
    'next_cursor', v_page -> 'next_cursor'
  );
end;
$$;

create or replace function public.v1_apply_user_permission_changes(
  p_target_app_user_id text,
  p_changes jsonb,
  p_reason text,
  p_expected_revision bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_role text := public.v1_current_exact_role();
  v_target uuid;
  v_revision bigint;
  v_replayed jsonb;
  v_payload jsonb;
  v_change jsonb;
  v_operation text;
  v_capability_key text;
  v_effect text;
  v_scope_kind text;
  v_assignment_id uuid;
  v_assignment_origin text;
  v_opposite_assignment_id uuid;
  v_project_ids uuid[];
  v_effective_from timestamptz;
  v_effective_until timestamptz;
  v_before jsonb;
  v_after jsonb;
  v_assignment_snapshot jsonb;
  v_events jsonb := '[]'::jsonb;
  v_event jsonb;
  v_ordinal integer := 0;
  v_workspace jsonb;
  v_dependency text;
  v_project_id uuid;
  v_resolution jsonb;
  v_manager_count integer;
begin
  if v_actor is null
    or not public.v1_current_actor_is_active()
    or not public.v1_permission_actor_can_manage() then
    raise exception 'V1_PERMISSION_MANAGEMENT_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  if nullif(btrim(p_reason), '') is null or char_length(p_reason) > 2000 then
    raise exception 'V1_PERMISSION_REASON_REQUIRED'
      using errcode = '22023';
  end if;
  if p_changes is null
    or jsonb_typeof(p_changes) <> 'array'
    or jsonb_array_length(p_changes) < 1
    or jsonb_array_length(p_changes) > 200 then
    raise exception 'V1_PERMISSION_CHANGES_INVALID'
      using errcode = '22023';
  end if;
  if p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'V1_PERMISSION_EXPECTED_REVISION_REQUIRED'
      using errcode = '22023';
  end if;

  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  if v_target = v_actor then
    raise exception 'V1_PERMISSION_SELF_ESCALATION_DENIED'
      using errcode = '42501';
  end if;
  if public.v1_permission_exact_role(v_target) = '' then
    raise exception 'V1_PERMISSION_INACTIVE_TARGET_DENIED'
      using errcode = '42501';
  end if;

  v_payload := jsonb_build_object(
    'target_app_user_id', p_target_app_user_id,
    'changes', p_changes,
    'reason', btrim(p_reason),
    'expected_revision', p_expected_revision
  );
  v_replayed := public.v1_idempotency_get_or_claim(
    'v1_apply_user_permission_changes', p_idempotency_key, v_payload
  );
  if v_replayed is not null then
    -- Never replay a previously stored workspace verbatim: the actor may have
    -- lost project access since the successful command. Rebuild the same
    -- revision through the current projection boundary instead.
    return public.v1_permission_workspace_json(v_target);
  end if;

  -- Permission administration is low-volume and high-risk. A shared
  -- transaction lock makes last-manager continuity and cross-target batches
  -- linearizable instead of relying on two independent target-row locks.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('v1_permission_manager_continuity', 0)
  );

  select revision.revision into v_revision
  from public.v1_permission_revisions revision
  where revision.auth_user_id = v_target
  for update;
  if not found then
    raise exception 'V1_PERMISSION_TARGET_REVISION_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  if v_revision <> p_expected_revision then
    raise exception 'V1_PERMISSION_REVISION_CONFLICT'
      using errcode = '40001',
        detail = jsonb_build_object(
          'expected_revision', p_expected_revision,
          'current_revision', v_revision
        )::text;
  end if;

  -- Validate all syntax, scope, target ownership and delegation ceilings before
  -- writing the first assignment. Unknown JSON keys are rejected to prevent a
  -- misspelled field from appearing to succeed.
  for v_change in select value from jsonb_array_elements(p_changes)
  loop
    if jsonb_typeof(v_change) <> 'object' then
      raise exception 'V1_PERMISSION_CHANGE_OBJECT_REQUIRED'
        using errcode = '22023';
    end if;
    v_operation := v_change ->> 'operation';
    if v_operation = 'set' then
      if v_change - array[
        'operation','capability_key','effect','scope_kind','project_ids',
        'effective_from','effective_until'
      ]::text[] <> '{}'::jsonb then
        raise exception 'V1_PERMISSION_CHANGE_UNKNOWN_FIELD'
          using errcode = '22023';
      end if;
      v_capability_key := nullif(btrim(v_change ->> 'capability_key'), '');
      v_effect := v_change ->> 'effect';
      v_scope_kind := v_change ->> 'scope_kind';
      if v_effect not in ('grant', 'deny')
        or v_scope_kind not in ('organization', 'project')
        or jsonb_typeof(v_change -> 'project_ids') <> 'array' then
        raise exception 'V1_PERMISSION_CHANGE_VALUE_INVALID'
          using errcode = '22023';
      end if;
      if not exists (
        select 1
        from public.v1_capability_catalog catalog
        where catalog.capability_key = v_capability_key
          and catalog.status = 'operational'
          and catalog.is_assignable
          and v_scope_kind = any(catalog.allowed_scope_kinds)
      ) then
        raise exception 'V1_PERMISSION_ASSIGNMENT_NOT_ALLOWED'
          using errcode = '42501';
      end if;
      if not public.v1_permission_actor_can_delegate(v_capability_key) then
        raise exception 'V1_PERMISSION_DELEGATION_CEILING_EXCEEDED'
          using errcode = '42501';
      end if;

      select coalesce(array_agg(value::uuid order by value::uuid), '{}'::uuid[])
      into v_project_ids
      from (
        select distinct jsonb_array_elements_text(
          v_change -> 'project_ids'
        ) as value
      ) project_value;
      if cardinality(v_project_ids) <>
        jsonb_array_length(v_change -> 'project_ids') then
        raise exception 'V1_PERMISSION_PROJECT_IDS_DUPLICATED'
          using errcode = '22023';
      end if;
      if v_scope_kind = 'organization' and cardinality(v_project_ids) <> 0 then
        raise exception 'V1_PERMISSION_ORGANIZATION_PROJECTS_FORBIDDEN'
          using errcode = '22023';
      elsif v_scope_kind = 'project' and cardinality(v_project_ids) = 0 then
        raise exception 'V1_PERMISSION_PROJECT_SCOPE_EMPTY'
          using errcode = '22023';
      end if;
      if not public.v1_permission_actor_can_administer_scope(
        v_capability_key, v_scope_kind, v_project_ids
      ) then
        if v_scope_kind = 'organization' then
          raise exception
            'V1_PERMISSION_ORGANIZATION_SCOPE_GLOBAL_AUTHORITY_REQUIRED'
            using errcode = '42501';
        end if;
        raise exception 'V1_PERMISSION_PROJECT_SCOPE_ACCESS_DENIED'
          using errcode = '42501';
      end if;

      v_effective_from := case
        when not (v_change ? 'effective_from')
          or v_change -> 'effective_from' = 'null'::jsonb
        then clock_timestamp()
        else (v_change ->> 'effective_from')::timestamptz
      end;
      v_effective_until := case
        when not (v_change ? 'effective_until')
          or v_change -> 'effective_until' = 'null'::jsonb
        then null
        else (v_change ->> 'effective_until')::timestamptz
      end;
      if v_effective_until is not null
        and v_effective_until <= v_effective_from then
        raise exception 'V1_PERMISSION_VALIDITY_INVALID'
          using errcode = '22023';
      end if;
      if v_capability_key = any(array[
          'users.view', 'permissions.view',
          'permissions.manage', 'permissions.delegate'
        ]::text[])
        and (
          v_effective_from > clock_timestamp()
          or v_effective_until is not null
        ) then
        raise exception 'V1_PERMISSION_MANAGER_SCHEDULE_FORBIDDEN'
          using errcode = '23514';
      end if;
    elsif v_operation = 'clear' then
      if v_change - array['operation','assignment_id']::text[] <>
        '{}'::jsonb then
        raise exception 'V1_PERMISSION_CHANGE_UNKNOWN_FIELD'
          using errcode = '22023';
      end if;
      v_assignment_id := (v_change ->> 'assignment_id')::uuid;
      select
        assignment.capability_key,
        assignment.scope_kind,
        array(
          select assignment_project.project_id
          from public.v1_permission_assignment_projects assignment_project
          where assignment_project.assignment_id = assignment.id
          order by assignment_project.project_id
        )
      into v_capability_key, v_scope_kind, v_project_ids
      from public.v1_permission_assignments assignment
      where assignment.id = v_assignment_id
        and assignment.auth_user_id = v_target;
      if not found then
        raise exception 'V1_PERMISSION_ASSIGNMENT_NOT_FOUND'
          using errcode = 'P0002';
      end if;
      if not public.v1_permission_actor_can_delegate(v_capability_key) then
        raise exception 'V1_PERMISSION_DELEGATION_CEILING_EXCEEDED'
          using errcode = '42501';
      end if;
      if not public.v1_permission_actor_can_administer_scope(
        v_capability_key, v_scope_kind, v_project_ids
      ) then
        if v_scope_kind = 'organization' then
          raise exception
            'V1_PERMISSION_ORGANIZATION_SCOPE_GLOBAL_AUTHORITY_REQUIRED'
            using errcode = '42501';
        end if;
        raise exception 'V1_PERMISSION_PROJECT_SCOPE_ACCESS_DENIED'
          using errcode = '42501';
      end if;
    else
      raise exception 'V1_PERMISSION_OPERATION_INVALID'
        using errcode = '22023';
    end if;
  end loop;

  if exists (
    select 1
    from (
      select
        change ->> 'capability_key' as capability_key,
        change ->> 'scope_kind' as scope_kind,
        count(*)
      from jsonb_array_elements(p_changes) change
      where change ->> 'operation' = 'set'
      group by change ->> 'capability_key', change ->> 'scope_kind'
      having count(*) > 1
    ) duplicate_set
  ) or exists (
    select 1
    from (
      select change ->> 'assignment_id', count(*)
      from jsonb_array_elements(p_changes) change
      where change ->> 'operation' = 'clear'
      group by change ->> 'assignment_id'
      having count(*) > 1
    ) duplicate_clear
  ) then
    raise exception 'V1_PERMISSION_DUPLICATE_DELTA'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_changes) set_change
    join jsonb_array_elements(p_changes) clear_change
      on set_change ->> 'operation' = 'set'
      and clear_change ->> 'operation' = 'clear'
    join public.v1_permission_assignments cleared
      on cleared.id = (clear_change ->> 'assignment_id')::uuid
      and cleared.auth_user_id = v_target
      and cleared.capability_key = set_change ->> 'capability_key'
      and cleared.scope_kind = set_change ->> 'scope_kind'
  ) then
    raise exception 'V1_PERMISSION_CONFLICTING_DELTA'
      using errcode = '22023';
  end if;

  -- Apply all validated deltas under the target revision lock. Any later
  -- invariant failure rolls the entire transaction back, including idempotency.
  for v_change in select value from jsonb_array_elements(p_changes)
  loop
    v_ordinal := v_ordinal + 1;
    v_assignment_id := null;
    v_assignment_origin := null;
    v_opposite_assignment_id := null;
    v_before := null;
    v_after := null;
    v_assignment_snapshot := null;
    v_operation := v_change ->> 'operation';
    if v_operation = 'clear' then
      v_assignment_id := (v_change ->> 'assignment_id')::uuid;
      v_assignment_snapshot := public.v1_permission_assignment_json(
        v_assignment_id
      );
      v_capability_key := v_assignment_snapshot ->> 'capability_key';
      v_effect := v_assignment_snapshot ->> 'effect';
      v_scope_kind := v_assignment_snapshot ->> 'scope_kind';
      v_before := public.v1_permission_scope_state_json(
        v_target, v_capability_key, v_scope_kind
      );
      select coalesce(array_agg(value::uuid), '{}'::uuid[])
      into v_project_ids
      from jsonb_array_elements_text(
        v_assignment_snapshot -> 'project_ids'
      ) value;
      delete from public.v1_permission_assignments assignment
      where assignment.id = v_assignment_id;
      v_after := public.v1_permission_scope_state_json(
        v_target, v_capability_key, v_scope_kind
      );
    else
      v_capability_key := v_change ->> 'capability_key';
      v_effect := v_change ->> 'effect';
      v_scope_kind := v_change ->> 'scope_kind';
      select coalesce(array_agg(value::uuid order by value::uuid), '{}'::uuid[])
      into v_project_ids
      from jsonb_array_elements_text(v_change -> 'project_ids') value;
      v_effective_from := case
        when not (v_change ? 'effective_from')
          or v_change -> 'effective_from' = 'null'::jsonb
        then clock_timestamp()
        else (v_change ->> 'effective_from')::timestamptz
      end;
      v_effective_until := case
        when not (v_change ? 'effective_until')
          or v_change -> 'effective_until' = 'null'::jsonb
        then null
        else (v_change ->> 'effective_until')::timestamptz
      end;

      select assignment.id, assignment.origin
      into v_assignment_id, v_assignment_origin
      from public.v1_permission_assignments assignment
      where assignment.auth_user_id = v_target
        and assignment.capability_key = v_capability_key
        and assignment.scope_kind = v_scope_kind
        and assignment.effect = v_effect
      for update;
      v_before := public.v1_permission_scope_state_json(
        v_target, v_capability_key, v_scope_kind
      );

      if v_assignment_id is not null
        and v_assignment_origin <> 'permission_management' then
        delete from public.v1_permission_assignments assignment
        where assignment.id = v_assignment_id;
        v_assignment_id := null;
      end if;

      if v_scope_kind = 'organization' then
        delete from public.v1_permission_assignments assignment
        where assignment.auth_user_id = v_target
          and assignment.capability_key = v_capability_key
          and assignment.scope_kind = 'organization'
          and assignment.effect <> v_effect;
      else
        select assignment.id into v_opposite_assignment_id
        from public.v1_permission_assignments assignment
        where assignment.auth_user_id = v_target
          and assignment.capability_key = v_capability_key
          and assignment.scope_kind = 'project'
          and assignment.effect <> v_effect
        for update;
        if v_opposite_assignment_id is not null then
          delete from public.v1_permission_assignment_projects assignment_project
          where assignment_project.assignment_id = v_opposite_assignment_id
            and assignment_project.project_id = any(v_project_ids);
          delete from public.v1_permission_assignments assignment
          where assignment.id = v_opposite_assignment_id
            and not exists (
              select 1
              from public.v1_permission_assignment_projects assignment_project
              where assignment_project.assignment_id = assignment.id
            );
        end if;
      end if;

      if v_assignment_id is null then
        insert into public.v1_permission_assignments (
          auth_user_id, capability_key, effect, scope_kind, origin,
          effective_from, effective_until, reason,
          changed_by_auth_user_id
        ) values (
          v_target, v_capability_key, v_effect, v_scope_kind,
          'permission_management', v_effective_from, v_effective_until,
          btrim(p_reason), v_actor
        ) returning id into v_assignment_id;
      else
        update public.v1_permission_assignments assignment
        set effective_from = v_effective_from,
            effective_until = v_effective_until,
            reason = btrim(p_reason),
            changed_by_auth_user_id = v_actor
        where assignment.id = v_assignment_id;
      end if;
      if v_scope_kind = 'project' then
        delete from public.v1_permission_assignment_projects assignment_project
        where assignment_project.assignment_id = v_assignment_id;
        insert into public.v1_permission_assignment_projects (
          assignment_id, project_id
        )
        select v_assignment_id, project_id
        from unnest(v_project_ids) project_id;
      end if;
      v_after := public.v1_permission_scope_state_json(
        v_target, v_capability_key, v_scope_kind
      );
    end if;

    v_events := v_events || jsonb_build_array(jsonb_build_object(
      'event_kind', v_operation,
      'capability_key', v_capability_key,
      'effect', v_effect,
      'scope_kind', v_scope_kind,
      'project_ids', to_jsonb(v_project_ids),
      'before', v_before,
      'after', v_after,
      'event_ordinal', v_ordinal
    ));
  end loop;

  -- A new explicit grant is valid only when every transitive dependency is
  -- effective after the complete batch. Denies are allowed to cascade their
  -- dependants to ineffective and are never silently converted to more rows.
  for v_change in
    select value
    from jsonb_array_elements(p_changes)
    where value ->> 'operation' = 'set'
      and value ->> 'effect' = 'grant'
  loop
    v_capability_key := v_change ->> 'capability_key';
    v_scope_kind := v_change ->> 'scope_kind';
    if v_scope_kind = 'organization' then
      v_resolution := public.v1_permission_candidate_resolution(
        v_target, v_capability_key, null
      );
      if not coalesce((v_resolution ->> 'effective')::boolean, false) then
        raise exception 'V1_PERMISSION_DEPENDENCY_NOT_EFFECTIVE'
          using errcode = '23514', detail = v_resolution::text;
      end if;
    else
      for v_project_id in
        select value::uuid
        from jsonb_array_elements_text(v_change -> 'project_ids') value
      loop
        v_resolution := public.v1_permission_candidate_resolution(
          v_target, v_capability_key, v_project_id
        );
        if not coalesce((v_resolution ->> 'effective')::boolean, false) then
          raise exception 'V1_PERMISSION_DEPENDENCY_NOT_EFFECTIVE'
            using errcode = '23514', detail = v_resolution::text;
        end if;
      end loop;
    end if;
  end loop;

  select count(*) into v_manager_count
  from public.v1_profiles profile
  where coalesce((public.v1_permission_candidate_resolution(
      profile.auth_user_id, 'permissions.manage', null
    ) ->> 'effective')::boolean, false)
    and coalesce((public.v1_permission_candidate_resolution(
      profile.auth_user_id, 'permissions.delegate', null
    ) ->> 'effective')::boolean, false);
  if v_manager_count < 1 then
    raise exception 'V1_PERMISSION_LAST_MANAGER_REQUIRED'
      using errcode = '23514';
  end if;

  v_revision := v_revision + 1;
  update public.v1_permission_revisions revision
  set revision = v_revision,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
  where revision.auth_user_id = v_target;

  for v_event in select value from jsonb_array_elements(v_events)
  loop
    insert into public.v1_permission_change_events (
      target_auth_user_id, event_kind, capability_key, effect,
      scope_kind, project_ids, before_state, after_state, reason,
      actor_auth_user_id, actor_exact_role, idempotency_key,
      event_ordinal, revision
    ) values (
      v_target, v_event ->> 'event_kind',
      v_event ->> 'capability_key', v_event ->> 'effect',
      v_event ->> 'scope_kind',
      array(
        select value::uuid
        from jsonb_array_elements_text(v_event -> 'project_ids') value
      ),
      v_event -> 'before', v_event -> 'after', btrim(p_reason),
      v_actor, v_actor_role, p_idempotency_key,
      (v_event ->> 'event_ordinal')::integer, v_revision
    );
  end loop;

  perform public.v1_write_audit_event(
    'permission_assignments_changed', 'permission_workspace', v_target,
    null,
    jsonb_build_object('revision', p_expected_revision),
    jsonb_build_object('revision', v_revision, 'changes', v_events),
    btrim(p_reason), p_idempotency_key
  );

  v_workspace := public.v1_permission_workspace_json(v_target);
  perform public.v1_complete_idempotency(
    'v1_apply_user_permission_changes', p_idempotency_key, v_workspace
  );
  return v_workspace;
end;
$$;

create or replace function public.v1_set_user_permission_assignment(
  p_target_app_user_id text,
  p_capability_key text,
  p_effect text,
  p_scope_kind text,
  p_project_ids uuid[],
  p_effective_from timestamptz,
  p_effective_until timestamptz,
  p_reason text,
  p_expected_revision bigint,
  p_idempotency_key uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.v1_apply_user_permission_changes(
    p_target_app_user_id,
    jsonb_build_array(jsonb_build_object(
      'operation', 'set',
      'capability_key', p_capability_key,
      'effect', p_effect,
      'scope_kind', p_scope_kind,
      'project_ids', to_jsonb(coalesce(p_project_ids, '{}'::uuid[])),
      'effective_from', to_jsonb(p_effective_from),
      'effective_until', to_jsonb(p_effective_until)
    )),
    p_reason, p_expected_revision, p_idempotency_key
  );
$$;

create or replace function public.v1_clear_user_permission_assignment(
  p_target_app_user_id text,
  p_assignment_id uuid,
  p_reason text,
  p_expected_revision bigint,
  p_idempotency_key uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.v1_apply_user_permission_changes(
    p_target_app_user_id,
    jsonb_build_array(jsonb_build_object(
      'operation', 'clear', 'assignment_id', p_assignment_id
    )),
    p_reason, p_expected_revision, p_idempotency_key
  );
$$;

-- Retained override mirrors receive explicit system-authored evidence without
-- pretending that a person performed the migration.
insert into public.v1_permission_change_events (
  target_auth_user_id, event_kind, capability_key, effect, scope_kind,
  project_ids, before_state, after_state, reason, actor_auth_user_id,
  actor_exact_role, occurred_at, revision, event_ordinal
)
select
  assignment.auth_user_id,
  case assignment.origin
    when 'legacy_commercial' then 'legacy_sync'
    else 'migration'
  end,
  assignment.capability_key,
  assignment.effect,
  assignment.scope_kind,
  '{}'::uuid[],
  null,
  public.v1_permission_assignment_json(assignment.id),
  assignment.reason,
  null,
  'system',
  assignment.created_at,
  0,
  1
from public.v1_permission_assignments assignment
where assignment.origin <> 'permission_management';

create or replace function public.v1_permission_active_manager_count(
  p_exclude_auth_user_id uuid default null
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.v1_profiles profile
  where profile.auth_user_id is distinct from p_exclude_auth_user_id
    and coalesce((public.v1_permission_candidate_resolution(
      profile.auth_user_id, 'permissions.manage', null
    ) ->> 'effective')::boolean, false)
    and coalesce((public.v1_permission_candidate_resolution(
      profile.auth_user_id, 'permissions.delegate', null
    ) ->> 'effective')::boolean, false);
$$;

create or replace function public.v1_permission_protect_last_manager_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('v1_permission_manager_continuity', 0)
  );
  if old.is_active
    and not new.is_active
    and coalesce((public.v1_permission_candidate_resolution(
      old.auth_user_id, 'permissions.manage', null
    ) ->> 'effective')::boolean, false)
    and coalesce((public.v1_permission_candidate_resolution(
      old.auth_user_id, 'permissions.delegate', null
    ) ->> 'effective')::boolean, false)
    and public.v1_permission_active_manager_count(old.auth_user_id) < 1 then
    raise exception 'V1_PERMISSION_LAST_MANAGER_REQUIRED'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_permission_protect_last_manager_profile
before update of is_active on public.v1_profiles
for each row execute function public.v1_permission_protect_last_manager_profile();

create or replace function public.v1_permission_protect_last_manager_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_role text := coalesce(new.raw_app_meta_data ->> 'role', '');
  v_new_active boolean := new.banned_until is null
    or new.banned_until <= clock_timestamp();
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('v1_permission_manager_continuity', 0)
  );
  if (
      old.raw_app_meta_data ->> 'role'
        is distinct from new.raw_app_meta_data ->> 'role'
      or old.banned_until is distinct from new.banned_until
    )
    and coalesce((public.v1_permission_candidate_resolution(
      old.id, 'permissions.manage', null
    ) ->> 'effective')::boolean, false)
    and coalesce((public.v1_permission_candidate_resolution(
      old.id, 'permissions.delegate', null
    ) ->> 'effective')::boolean, false)
    and not (
      v_new_active
      and v_new_role in ('admin', 'senior_mechanical_engineer')
    )
    and public.v1_permission_active_manager_count(old.id) < 1 then
    raise exception 'V1_PERMISSION_LAST_MANAGER_REQUIRED'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_permission_protect_last_manager_auth
before update of raw_app_meta_data, banned_until on auth.users
for each row execute function public.v1_permission_protect_last_manager_auth();

alter table public.v1_capability_catalog enable row level security;
alter table public.v1_permission_role_defaults enable row level security;
alter table public.v1_permission_revisions enable row level security;
alter table public.v1_permission_assignments enable row level security;
alter table public.v1_permission_assignment_projects enable row level security;
alter table public.v1_permission_change_events enable row level security;

create policy v1_permission_revisions_self_or_manager_select
on public.v1_permission_revisions
for select
to authenticated
using (
  (select auth.uid()) = auth_user_id
  or (select public.v1_current_user_has_capability(
    'permissions.view', null
  ))
);

revoke all on table public.v1_capability_catalog
  from public, anon, authenticated;
revoke all on table public.v1_permission_role_defaults
  from public, anon, authenticated;
revoke all on table public.v1_permission_revisions
  from public, anon, authenticated;
revoke all on table public.v1_permission_assignments
  from public, anon, authenticated;
revoke all on table public.v1_permission_assignment_projects
  from public, anon, authenticated;
revoke all on table public.v1_permission_change_events
  from public, anon, authenticated;
grant select on table public.v1_permission_revisions to authenticated;
grant all on table public.v1_capability_catalog to service_role;
grant all on table public.v1_permission_role_defaults to service_role;
grant all on table public.v1_permission_revisions to service_role;
grant all on table public.v1_permission_assignments to service_role;
grant all on table public.v1_permission_assignment_projects to service_role;
grant all on table public.v1_permission_change_events to service_role;

do $revoke_permission_functions$
declare
  v_function regprocedure;
begin
  foreach v_function in array array[
    'public.v1_permission_exact_role(uuid)'::regprocedure,
    'public.v1_permission_sync_revision_profile()'::regprocedure,
    'public.v1_permission_signal_exact_role_change()'::regprocedure,
    'public.v1_permission_signal_membership_insert()'::regprocedure,
    'public.v1_permission_signal_membership_update()'::regprocedure,
    'public.v1_permission_signal_membership_delete()'::regprocedure,
    'public.v1_permission_display_exact_role(uuid)'::regprocedure,
    'public.v1_permission_target_auth_id(text)'::regprocedure,
    'public.v1_permission_has_project_access(uuid,uuid)'::regprocedure,
    'public.v1_permission_candidate_raw(uuid,text,uuid)'::regprocedure,
    'public.v1_permission_candidate_resolution(uuid,text,uuid)'::regprocedure,
    'public.v1_permission_legacy_raw(uuid,text,uuid)'::regprocedure,
    'public.v1_permission_legacy_resolution(uuid,text,uuid)'::regprocedure,
    'public.v1_permission_authoritative_resolution(uuid,text,uuid)'::regprocedure,
    'public.v1_permission_cutover_parity_report(text[])'::regprocedure,
    'public.v1_assert_permission_cutover_parity(text[])'::regprocedure,
    'public.v1_permission_guard_assignment_project()'::regprocedure,
    'public.v1_permission_guard_assignment()'::regprocedure,
    'public.v1_permission_history_immutable()'::regprocedure,
    'public.v1_permission_mode_summary()'::regprocedure,
    'public.v1_permission_actor_can_view()'::regprocedure,
    'public.v1_permission_actor_can_manage()'::regprocedure,
    'public.v1_permission_actor_can_delegate(text)'::regprocedure,
    'public.v1_permission_actor_can_view_project(uuid)'::regprocedure,
    'public.v1_permission_actor_has_full_project_visibility(uuid[])'::regprocedure,
    'public.v1_permission_actor_has_unrestricted_project_authority()'::regprocedure,
    'public.v1_permission_actor_can_view_assignment_scope(text,text,uuid[])'::regprocedure,
    'public.v1_permission_actor_can_administer_scope(text,text,uuid[])'::regprocedure,
    'public.v1_permission_actor_delegable_scope_kinds(text)'::regprocedure,
    'public.v1_permission_visible_project_ids(uuid[])'::regprocedure,
    'public.v1_permission_visible_assignment_state(jsonb)'::regprocedure,
    'public.v1_permission_actor_can_assign_role_template(text)'::regprocedure,
    'public.v1_permission_assignment_json(uuid)'::regprocedure,
    'public.v1_permission_scope_state_json(uuid,text,text)'::regprocedure,
    'public.v1_permission_sync_legacy_commercial()'::regprocedure,
    'public.v1_permission_capability_json(uuid,text)'::regprocedure,
    'public.v1_permission_history_json(uuid,integer,timestamptz,uuid)'::regprocedure,
    'public.v1_permission_workspace_json(uuid)'::regprocedure,
    'public.v1_permission_active_manager_count(uuid)'::regprocedure,
    'public.v1_permission_protect_last_manager_profile()'::regprocedure,
    'public.v1_permission_protect_last_manager_auth()'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated',
      v_function);
  end loop;
end;
$revoke_permission_functions$;

revoke all on function public.v1_current_user_has_capability(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_current_user_can_assign_exact_role(text, text)
  from public, anon, authenticated;
revoke all on function public.v1_current_user_can_assign_new_exact_role(text)
  from public, anon, authenticated;
revoke all on function public.v1_get_current_permission_snapshot()
  from public, anon, authenticated;
revoke all on function public.v1_get_user_permission_workspace(text)
  from public, anon, authenticated;
revoke all on function public.v1_list_user_permission_history(
  text, integer, timestamptz, uuid
) from public, anon, authenticated;
revoke all on function public.v1_apply_user_permission_changes(
  text, jsonb, text, bigint, uuid
) from public, anon, authenticated;
revoke all on function public.v1_set_user_permission_assignment(
  text, text, text, text, uuid[], timestamptz, timestamptz,
  text, bigint, uuid
) from public, anon, authenticated;
revoke all on function public.v1_clear_user_permission_assignment(
  text, uuid, text, bigint, uuid
) from public, anon, authenticated;

grant execute on function public.v1_current_user_has_capability(text, uuid)
  to authenticated;
grant execute on function public.v1_current_user_can_assign_exact_role(
  text, text
) to authenticated;
grant execute on function public.v1_current_user_can_assign_new_exact_role(text)
  to authenticated;
grant execute on function public.v1_get_current_permission_snapshot()
  to authenticated;
grant execute on function public.v1_get_user_permission_workspace(text)
  to authenticated;
grant execute on function public.v1_list_user_permission_history(
  text, integer, timestamptz, uuid
) to authenticated;
grant execute on function public.v1_apply_user_permission_changes(
  text, jsonb, text, bigint, uuid
) to authenticated;
grant execute on function public.v1_set_user_permission_assignment(
  text, text, text, text, uuid[], timestamptz, timestamptz,
  text, bigint, uuid
) to authenticated;
grant execute on function public.v1_clear_user_permission_assignment(
  text, uuid, text, bigint, uuid
) to authenticated;

alter table public.v1_permission_revisions replica identity full;
do $realtime_permission_revision$
begin
  if not exists (
    select 1
    from pg_catalog.pg_publication_tables publication_table
    where publication_table.pubname = 'supabase_realtime'
      and publication_table.schemaname = 'public'
      and publication_table.tablename = 'v1_permission_revisions'
  ) then
    alter publication supabase_realtime
      add table public.v1_permission_revisions;
  end if;
end;
$realtime_permission_revision$;

commit;
