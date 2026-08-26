-- Yorks R39 Accounts T01: exact identity, shadow capability contract and
-- protected module defaults.
--
-- This migration does not enable an Accounts workflow command. The fifteen
-- R39 capability keys are deliberately planned/nonassignable until their
-- protected T02-T06 consumers, state machines and response shapes ship.
-- Accountant is a platform/commercial role only: it is never a technical
-- project member and every non-Accounts project capability remains denied.
--
-- The repository has no database feature-flag registry. YORKS_V1_ACCOUNTS
-- therefore remains an application/runtime flag; the server fails closed by
-- keeping every R39 capability planned and every command flag false.
--
-- Data preservation: all changes are additive or strict-superset role checks.
-- No project, BOQ, material, inventory, document or audit row is rewritten.
-- Rollback: disable YORKS_V1_ACCOUNTS, revoke v1_get_accounts_foundation and
-- retain the catalog/default rows. Never delete permission or actor history.

begin;

create or replace function public.v1_accounts_is_capability_key(
  p_capability_key text
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_capability_key = any(array[
    'view_project_accounts',
    'view_project_commercial_values',
    'suggest_billing_progress',
    'confirm_billing_progress',
    'prepare_client_claim',
    'manage_client_invoices',
    'record_client_certification',
    'record_client_payment',
    'manage_pdc',
    'manage_supplier_bills',
    'approve_supplier_bill_payment',
    'configure_project_commercials',
    'view_supplier_costs',
    'export_accounts_registers',
    'review_commercial_progress'
  ]::text[]);
$$;

-- The established catalog uses dotted operational keys. R39's approved keys
-- are exact snake_case identifiers. Admit only those fifteen exceptions; do
-- not weaken validation for arbitrary non-namespaced keys.
alter table public.v1_capability_catalog
  drop constraint if exists v1_capability_catalog_capability_key_check;
alter table public.v1_capability_catalog
  add constraint v1_capability_catalog_capability_key_check check (
    capability_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
    or public.v1_accounts_is_capability_key(capability_key)
  );

create or replace function public.v1_canonical_role_from_exact_role(
  p_role text
)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case p_role
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'workshop_in_charge' then 'project_engineer'
    when 'document_controller' then 'project_engineer'
    when 'procurement' then 'procurement'
    when 'accountant' then 'accountant'
    when 'admin' then 'admin'
    else ''
  end;
$$;

create or replace function public.v1_is_valid_role(p_role text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select public.v1_canonical_role_from_exact_role(p_role) <> '';
$$;

create or replace function public.v1_safe_auth_audit_role(
  p_raw_app_meta_data jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case coalesce(p_raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'senior_mechanical_engineer'
    when 'project_manager' then 'project_manager'
    when 'workshop_in_charge' then 'workshop_in_charge'
    when 'document_controller' then 'document_controller'
    when 'procurement' then 'procurement'
    when 'accountant' then 'accountant'
    when 'admin' then 'admin'
    when 'engineer' then 'engineer'
    else 'unrecognized'
  end;
$$;

-- Preserve the final no-op-aware profile synchronizer and add only the new
-- exact-to-canonical role mapping. Guarded replacement fails the migration if
-- upstream role normalization changed unexpectedly.
do $profile_sync_rewrite$
declare
  v_definition text;
  v_updated text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_sync_profile_from_auth(uuid)'::regprocedure
  );
  if position('when ''accountant'' then ''accountant''' in v_definition) > 0 then
    return;
  end if;
  v_updated := replace(
    v_definition,
    'when ''procurement'' then ''procurement''',
    'when ''procurement'' then ''procurement''
    when ''accountant'' then ''accountant'''
  );
  if v_updated = v_definition then
    raise exception 'R39_ACCOUNTANT_PROFILE_SYNC_ROLE_ANCHOR_MISSING';
  end if;
  execute v_updated;
end;
$profile_sync_rewrite$;

-- Canonical identity, legacy commercial compatibility, audit and controlled
-- document actor columns must all be able to retain Accountant attribution.
alter table public.v1_profiles
  drop constraint if exists v1_profiles_canonical_role_snapshot_check;
alter table public.v1_profiles
  add constraint v1_profiles_canonical_role_snapshot_check check (
    canonical_role_snapshot in (
      '', 'project_engineer', 'site_engineer', 'procurement', 'accountant',
      'admin'
    )
  );

alter table public.v1_role_capability_defaults
  drop constraint if exists v1_role_capability_defaults_role_name_check;
alter table public.v1_role_capability_defaults
  add constraint v1_role_capability_defaults_role_name_check check (
    role_name in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );

alter table public.v1_audit_events
  drop constraint if exists v1_audit_events_actor_role_check;
alter table public.v1_audit_events
  add constraint v1_audit_events_actor_role_check check (
    actor_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );
alter table public.v1_audit_events
  drop constraint if exists v1_audit_events_actor_exact_role_check;
alter table public.v1_audit_events
  drop constraint if exists v1_audit_events_actor_exact_role_expanded_check;
alter table public.v1_audit_events
  add constraint v1_audit_events_actor_exact_role_r39_check check (
    actor_exact_role is null or actor_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin'
    )
  );

alter table public.v1_permission_role_defaults
  drop constraint if exists v1_permission_role_defaults_role_name_check;
alter table public.v1_permission_role_defaults
  add constraint v1_permission_role_defaults_role_name_check check (
    role_name in (
      'project_engineer', 'site_engineer',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin'
    )
  );

alter table public.v1_permission_change_events
  drop constraint if exists v1_permission_change_events_actor_exact_role_check;
alter table public.v1_permission_change_events
  add constraint v1_permission_change_events_actor_exact_role_check check (
    actor_exact_role in (
      'project_engineer', 'site_engineer',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin', 'system'
    )
  );

alter table public.v1_documents
  drop constraint if exists v1_documents_created_by_role_check;
alter table public.v1_documents
  add constraint v1_documents_created_by_role_check check (
    created_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );
alter table public.v1_document_versions
  drop constraint if exists v1_document_versions_uploaded_by_role_check;
alter table public.v1_document_versions
  add constraint v1_document_versions_uploaded_by_role_check check (
    uploaded_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );
alter table public.v1_document_links
  drop constraint if exists v1_document_links_linked_by_role_check;
alter table public.v1_document_links
  add constraint v1_document_links_linked_by_role_check check (
    linked_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );
alter table public.v1_document_links
  drop constraint if exists v1_document_links_removed_by_role_check;
alter table public.v1_document_links
  add constraint v1_document_links_removed_by_role_check check (
    removed_by_role is null or removed_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );
alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_actor_role_check;
alter table public.v1_document_upload_intents
  add constraint v1_document_upload_intents_actor_role_check check (
    actor_role in (
      'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
    )
  );

insert into public.v1_role_capability_defaults (
  role_name, capability, is_enabled
)
values
  ('accountant', 'view_commercials', false),
  ('accountant', 'manage_commercials', false)
on conflict (role_name, capability) do update
set is_enabled = excluded.is_enabled;

insert into public.v1_capability_catalog (
  capability_key, module_key, action_key, label, description, risk_level,
  allowed_scope_kinds, requires_project_access, dependencies, status,
  authorization_mode, is_assignable, display_order
)
values
  ('view_project_accounts', 'accounts', 'view_project_accounts',
   'View project accounts', 'Read the role-safe Accounts projection for an authorized project.',
   'critical', array['project'], true, '{}', 'planned', 'shadow', false, 374),
  ('view_project_commercial_values', 'accounts', 'view_project_commercial_values',
   'View project commercial values', 'Read protected project contract and client commercial values.',
   'critical', array['project'], true, array['view_project_accounts'], 'planned', 'shadow', false, 375),
  ('suggest_billing_progress', 'accounts', 'suggest_billing_progress',
   'Suggest billing progress', 'Suggest evidence-backed project billing progress.',
   'high', array['project'], true, array['view_project_accounts'], 'planned', 'shadow', false, 376),
  ('confirm_billing_progress', 'accounts', 'confirm_billing_progress',
   'Confirm billing progress', 'Confirm defensible project billing progress.',
   'critical', array['project'], true, array['view_project_accounts','view_project_commercial_values'], 'planned', 'shadow', false, 377),
  ('prepare_client_claim', 'accounts', 'prepare_client_claim',
   'Prepare client claim', 'Prepare a claim draft from confirmed project progress.',
   'critical', array['project'], true, array['view_project_accounts','view_project_commercial_values'], 'planned', 'shadow', false, 378),
  ('manage_client_invoices', 'accounts', 'manage_client_invoices',
   'Manage client invoices', 'Review, submit, return or cancel authorized client invoices.',
   'critical', array['project'], true, array['view_project_accounts','view_project_commercial_values'], 'planned', 'shadow', false, 379),
  ('record_client_certification', 'accounts', 'record_client_certification',
   'Record client certification', 'Record client or consultant certification facts.',
   'critical', array['project'], true, array['manage_client_invoices'], 'planned', 'shadow', false, 380),
  ('record_client_payment', 'accounts', 'record_client_payment',
   'Record client payment', 'Append an authoritative client payment record.',
   'critical', array['project'], true, array['manage_client_invoices'], 'planned', 'shadow', false, 381),
  ('manage_pdc', 'accounts', 'manage_pdc',
   'Manage PDC', 'Create and transition authorized post-dated cheque records.',
   'critical', array['project'], true, array['manage_client_invoices'], 'planned', 'shadow', false, 382),
  ('manage_supplier_bills', 'accounts', 'manage_supplier_bills',
   'Manage supplier bills', 'Maintain supplier bill and matching evidence.',
   'critical', array['project'], true, array['view_supplier_costs'], 'planned', 'shadow', false, 383),
  ('approve_supplier_bill_payment', 'accounts', 'approve_supplier_bill_payment',
   'Approve supplier bill payment', 'Approve a fully matched supplier bill for payment.',
   'critical', array['project'], true, array['manage_supplier_bills','view_supplier_costs'], 'planned', 'shadow', false, 384),
  ('configure_project_commercials', 'accounts', 'configure_project_commercials',
   'Configure project commercials', 'Initialize or revise a protected project commercial baseline.',
   'critical', array['project'], true, array['view_project_accounts','view_project_commercial_values'], 'planned', 'shadow', false, 385),
  ('view_supplier_costs', 'accounts', 'view_supplier_costs',
   'View supplier costs', 'Read protected project supplier-cost projections.',
   'critical', array['project'], true, '{}', 'planned', 'shadow', false, 386),
  ('export_accounts_registers', 'accounts', 'export_accounts_registers',
   'Export Accounts registers', 'Export role-safe project Accounts registers.',
   'critical', array['project'], true, array['view_project_accounts'], 'planned', 'shadow', false, 387),
  ('review_commercial_progress', 'accounts', 'review_commercial_progress',
   'Review commercial progress', 'Perform an explicitly authorized management review.',
   'critical', array['project'], true, array['view_project_accounts','view_project_commercial_values'], 'planned', 'shadow', false, 388)
on conflict (capability_key) do nothing;

do $catalog_contract$
begin
  if (
    select count(*)
    from public.v1_capability_catalog catalog
    where public.v1_accounts_is_capability_key(catalog.capability_key)
      and catalog.module_key = 'accounts'
      and catalog.status = 'planned'
      and catalog.authorization_mode = 'shadow'
      and not catalog.is_assignable
      and catalog.requires_project_access
      and catalog.allowed_scope_kinds = array['project']::text[]
  ) <> 15 then
    raise exception 'R39_ACCOUNTS_CAPABILITY_CATALOG_CONFLICT'
      using errcode = '23514';
  end if;
end;
$catalog_contract$;

-- Complete the explicit matrix for all nine exact roles and every capability.
insert into public.v1_permission_role_defaults (
  role_name, capability_key, is_granted, can_delegate
)
select role_name, capability.capability_key, false, false
from unnest(array[
  'project_engineer', 'site_engineer',
  'senior_mechanical_engineer', 'project_manager',
  'workshop_in_charge', 'document_controller',
  'procurement', 'accountant', 'admin'
]::text[]) role_name
cross join public.v1_capability_catalog capability
on conflict (role_name, capability_key) do nothing;

-- Future role ceilings. They remain ineffective while the catalog rows are
-- planned; T02-T06 must activate only the capability whose consumer ships.
update public.v1_permission_role_defaults role_default
set is_granted = false,
    can_delegate = false,
    updated_at = clock_timestamp()
where public.v1_accounts_is_capability_key(role_default.capability_key);

update public.v1_permission_role_defaults
set is_granted = true,
    updated_at = clock_timestamp()
where role_name = 'project_engineer'
  and capability_key = any(array[
    'view_project_accounts', 'view_project_commercial_values',
    'confirm_billing_progress', 'prepare_client_claim',
    'export_accounts_registers'
  ]::text[]);

update public.v1_permission_role_defaults
set is_granted = true,
    updated_at = clock_timestamp()
where role_name = 'site_engineer'
  and capability_key = any(array[
    'view_project_accounts', 'suggest_billing_progress'
  ]::text[]);

update public.v1_permission_role_defaults
set is_granted = true,
    updated_at = clock_timestamp()
where role_name in ('senior_mechanical_engineer', 'project_manager')
  and capability_key = any(array[
    'view_project_accounts', 'view_project_commercial_values',
    'export_accounts_registers'
  ]::text[]);

update public.v1_permission_role_defaults
set is_granted = true,
    updated_at = clock_timestamp()
where role_name = 'procurement'
  and capability_key = any(array[
    'manage_supplier_bills', 'view_supplier_costs'
  ]::text[]);

update public.v1_permission_role_defaults
set is_granted = true,
    updated_at = clock_timestamp()
where role_name = 'accountant'
  and capability_key = any(array[
    'view_project_accounts', 'view_project_commercial_values',
    'manage_client_invoices', 'record_client_certification',
    'record_client_payment', 'manage_pdc', 'manage_supplier_bills',
    'approve_supplier_bill_payment', 'view_supplier_costs',
    'export_accounts_registers'
  ]::text[]);

update public.v1_permission_role_defaults
set is_granted = true,
    can_delegate = true,
    updated_at = clock_timestamp()
where role_name = 'admin'
  and capability_key = any(array[
    'view_project_accounts', 'view_project_commercial_values',
    'manage_client_invoices', 'record_client_certification',
    'record_client_payment', 'manage_pdc', 'manage_supplier_bills',
    'approve_supplier_bill_payment', 'configure_project_commercials',
    'view_supplier_costs', 'export_accounts_registers',
    'review_commercial_progress'
  ]::text[]);

-- Accountant is never structurally visible to generic project capabilities,
-- even if an old technical membership row somehow survives a role change.
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
  if v_exact_role = 'accountant' then
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

-- This is an Accounts structural scope check, not a grant resolver. Role
-- templates/assignments still decide the capability, while this function
-- prevents any grant from crossing the approved role/project boundary.
create or replace function public.v1_accounts_has_project_scope(
  p_auth_user_id uuid,
  p_project_id uuid,
  p_capability_key text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text := public.v1_permission_exact_role(p_auth_user_id);
  v_has_membership boolean := false;
begin
  if v_exact_role = ''
    or p_project_id is null
    or not coalesce(public.v1_accounts_is_capability_key(p_capability_key), false)
    or not exists (
      select 1 from public.v1_projects project where project.id = p_project_id
    ) then
    return false;
  end if;

  if v_exact_role in ('accountant', 'admin') then
    return true;
  end if;
  if v_exact_role = 'procurement' then
    return p_capability_key in ('manage_supplier_bills', 'view_supplier_costs');
  end if;
  if v_exact_role in ('senior_mechanical_engineer', 'project_manager') then
    return p_capability_key in (
      'view_project_accounts', 'view_project_commercial_values',
      'export_accounts_registers', 'review_commercial_progress'
    );
  end if;
  if v_exact_role not in ('project_engineer', 'site_engineer') then
    return false;
  end if;

  select exists (
    select 1
    from public.v1_project_members member
    where member.project_id = p_project_id
      and member.member_auth_user_id = p_auth_user_id
      and member.project_role = v_exact_role
      and member.effective_from <= clock_timestamp()
      and (
        member.effective_to is null
        or member.effective_to > clock_timestamp()
      )
  ) into v_has_membership;
  if not v_has_membership then
    return false;
  end if;

  if v_exact_role = 'site_engineer' then
    return p_capability_key in (
      'view_project_accounts', 'suggest_billing_progress'
    );
  end if;
  return p_capability_key in (
    'view_project_accounts', 'view_project_commercial_values',
    'confirm_billing_progress', 'prepare_client_claim',
    'export_accounts_registers'
  );
end;
$$;

create or replace function public.v1_permission_has_capability_project_scope(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when catalog.module_key = 'accounts'
      and public.v1_accounts_is_capability_key(catalog.capability_key)
    then public.v1_accounts_has_project_scope(
      p_auth_user_id, p_project_id, p_capability_key
    )
    else public.v1_permission_has_project_access(
      p_auth_user_id, p_project_id
    )
  end
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;
$$;

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
  if v_role = 'accountant'
    and not public.v1_accounts_is_capability_key(p_capability_key) then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
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
    and not public.v1_permission_has_capability_project_scope(
      p_auth_user_id, p_capability_key, p_project_id
    ) then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
  end if;

  select assignment.effect into v_effect
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_auth_user_id
    and assignment.capability_key = p_capability_key
    and assignment.origin = 'permission_management'
    and assignment.effective_from <= clock_timestamp()
    and (assignment.effective_until is null
      or assignment.effective_until > clock_timestamp())
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
  if v_role = 'accountant'
    and not public.v1_accounts_is_capability_key(p_capability_key) then
    return jsonb_build_object('effective', false, 'source', 'hard_invariant');
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
    and not public.v1_permission_has_capability_project_scope(
      p_auth_user_id, p_capability_key, p_project_id
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
        'effective', v_override, 'source', 'legacy_override'
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
        'effective', v_override, 'source', 'legacy_override'
      );
    end if;
  end if;
  select assignment.effect into v_effect
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id = p_auth_user_id
    and assignment.capability_key = p_capability_key
    and assignment.origin <> 'permission_management'
    and assignment.effective_from <= clock_timestamp()
    and (assignment.effective_until is null
      or assignment.effective_until > clock_timestamp())
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
      'effective', v_effect = 'grant', 'source', 'legacy_override'
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

-- Prevent malformed grants from being stored for Accountant even before a
-- consumer resolver is called. Historical assignments are retained across a
-- role change but remain ineffective through the hard resolver invariant.
create or replace function public.v1_permission_guard_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_catalog_found boolean;
  v_target_role text;
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = new.capability_key;
  v_catalog_found := found;
  v_target_role := public.v1_permission_display_exact_role(new.auth_user_id);
  if v_target_role = 'accountant'
    and new.effect = 'grant'
    and (
      not v_catalog_found
      or not public.v1_accounts_is_capability_key(new.capability_key)
    ) then
    raise exception 'V1_ACCOUNTANT_NON_ACCOUNTS_CAPABILITY_DENIED'
      using errcode = '42501';
  end if;
  if not v_catalog_found
    or new.scope_kind <> all(v_catalog.allowed_scope_kinds)
    or v_catalog.status <> 'operational'
    or not v_catalog.is_assignable then
    raise exception 'V1_PERMISSION_ASSIGNMENT_NOT_ALLOWED'
      using errcode = '42501';
  end if;
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

create or replace function public.v1_accounts_guard_technical_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (new.effective_to is null or new.effective_to > clock_timestamp())
    and public.v1_permission_display_exact_role(
      new.member_auth_user_id
    ) = 'accountant' then
    raise exception 'V1_ACCOUNTANT_TECHNICAL_MEMBERSHIP_FORBIDDEN'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_accounts_guard_technical_membership
  on public.v1_project_members;
create trigger v1_accounts_guard_technical_membership
before insert or update on public.v1_project_members
for each row execute function public.v1_accounts_guard_technical_membership();

create or replace function public.v1_accounts_guard_profile_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.canonical_role_snapshot = 'accountant'
    and exists (
      select 1
      from public.v1_project_members member
      where member.member_auth_user_id = new.auth_user_id
        and member.effective_from <= clock_timestamp()
        and (
          member.effective_to is null
          or member.effective_to > clock_timestamp()
        )
    ) then
    raise exception 'V1_ACCOUNTANT_ACTIVE_TECHNICAL_MEMBERSHIP_EXISTS'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_accounts_guard_profile_role_change
  on public.v1_profiles;
create trigger v1_accounts_guard_profile_role_change
before insert or update of canonical_role_snapshot on public.v1_profiles
for each row execute function public.v1_accounts_guard_profile_role_change();

-- T01 contains only migration-controlled defaults. Project baselines and all
-- monetary/transactional records belong to later phases.
create table public.v1_accounts_foundation_settings (
  singleton boolean primary key default true check (singleton),
  default_payment_terms_days integer not null default 90
    check (default_payment_terms_days > 0),
  default_reminder_lead_days integer not null default 10
    check (default_reminder_lead_days >= 0),
  common_scope_is_physical boolean not null default false
    check (not common_scope_is_physical),
  schema_version integer not null default 1 check (schema_version = 1),
  created_at timestamptz not null default clock_timestamp(),
  check (default_reminder_lead_days <= default_payment_terms_days)
);

create table public.v1_accounts_billing_stage_templates (
  stage_key text primary key
    check (stage_key ~ '^[a-z][a-z0-9_]*$'),
  stage_name text not null check (btrim(stage_name) <> ''),
  allocation_percent numeric(7,4) not null
    check (allocation_percent > 0 and allocation_percent <= 100),
  display_order integer not null unique check (display_order > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp()
);

insert into public.v1_accounts_foundation_settings (
  singleton, default_payment_terms_days, default_reminder_lead_days,
  common_scope_is_physical, schema_version
) values (true, 90, 10, false, 1);

insert into public.v1_accounts_billing_stage_templates (
  stage_key, stage_name, allocation_percent, display_order
)
values
  ('design', 'Design', 10.0000, 1),
  ('material_supply', 'Material Supply', 50.0000, 2),
  ('installation', 'Installation', 30.0000, 3),
  ('commissioning_handover', 'Commissioning & Handover', 5.0000, 4),
  ('energizing', 'Energizing', 5.0000, 5);

-- R38 retained three Accounts-shaped configuration rows before an Accounts
-- runtime existed. The configuration control plane deliberately classified
-- them as planned/non-operational. Keep that history, but fail closed if it
-- disagrees with the new protected foundation rather than silently creating
-- two apparent authorities. Draft values are intentionally excluded.
do $legacy_accounts_configuration_contract$
begin
  if (
    select count(*)
    from public.v1_configuration_settings setting
    where setting.setting_key = any(array[
      'accounts.billing_stage_weights',
      'accounts.payment_terms_days',
      'accounts.pdc_reminder_days'
    ]::text[])
      and setting.control_mode = 'planned'
      and setting.enforcement_target = 'retained_reference'
      and setting.default_value = case setting.setting_key
        when 'accounts.billing_stage_weights' then
          '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":5}'::jsonb
        when 'accounts.payment_terms_days' then '90'::jsonb
        when 'accounts.pdc_reminder_days' then '10'::jsonb
      end
      and setting.published_value = case setting.setting_key
        when 'accounts.billing_stage_weights' then
          '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":5}'::jsonb
        when 'accounts.payment_terms_days' then '90'::jsonb
        when 'accounts.pdc_reminder_days' then '10'::jsonb
      end
  ) <> 3 then
    raise exception 'R39_LEGACY_ACCOUNTS_CONFIGURATION_CONFLICT'
      using errcode = '23514';
  end if;
end;
$legacy_accounts_configuration_contract$;

create or replace function public.v1_accounts_validate_stage_templates()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total numeric(12,4);
begin
  select coalesce(sum(stage.allocation_percent), 0)
  into v_total
  from public.v1_accounts_billing_stage_templates stage
  where stage.is_active;
  if v_total <> 100.0000 then
    raise exception 'R39_ACCOUNTS_DEFAULT_STAGE_TOTAL_INVALID'
      using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger v1_accounts_validate_stage_templates
after insert or update or delete on public.v1_accounts_billing_stage_templates
deferrable initially deferred
for each row execute function public.v1_accounts_validate_stage_templates();

alter table public.v1_accounts_foundation_settings enable row level security;
alter table public.v1_accounts_billing_stage_templates enable row level security;

revoke all on table public.v1_accounts_foundation_settings
  from public, anon, authenticated;
revoke all on table public.v1_accounts_billing_stage_templates
  from public, anon, authenticated;
grant all on table public.v1_accounts_foundation_settings to service_role;
grant all on table public.v1_accounts_billing_stage_templates to service_role;

-- Safe, non-commercial bootstrap projection. It deliberately returns no
-- contract, invoice, supplier or monetary value and every command is false.
create or replace function public.v1_get_accounts_foundation(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_result jsonb;
begin
  if v_actor is null or p_project_id is null
    or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_FOUNDATION_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  v_exact_role := public.v1_permission_exact_role(v_actor);
  if v_exact_role = '' or not exists (
    select 1
    from public.v1_permission_role_defaults role_default
    where role_default.role_name = v_exact_role
      and public.v1_accounts_is_capability_key(role_default.capability_key)
      and role_default.is_granted
      and public.v1_accounts_has_project_scope(
        v_actor, p_project_id, role_default.capability_key
      )
  ) then
    raise exception 'R39_ACCOUNTS_FOUNDATION_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'schema_version', 1,
    'foundation_ready', true,
    'consumers_enabled', false,
    'project_id', p_project_id,
    'defaults', jsonb_build_object(
      'payment_terms_days', settings.default_payment_terms_days,
      'reminder_lead_days', settings.default_reminder_lead_days,
      'common_scope_is_physical', settings.common_scope_is_physical
    ),
    'billing_stages', (
      select jsonb_agg(jsonb_build_object(
        'stage_key', stage.stage_key,
        'stage_name', stage.stage_name,
        'allocation_percent', stage.allocation_percent,
        'display_order', stage.display_order
      ) order by stage.display_order)
      from public.v1_accounts_billing_stage_templates stage
      where stage.is_active
    ),
    'capabilities', (
      select jsonb_object_agg(
        catalog.capability_key,
        jsonb_build_object(
          'template_granted', coalesce(role_default.is_granted, false),
          'has_project_scope', public.v1_accounts_has_project_scope(
            v_actor, p_project_id, catalog.capability_key
          ),
          'command_enabled', false,
          'runtime_status', catalog.status
        ) order by catalog.display_order
      )
      from public.v1_capability_catalog catalog
      left join public.v1_permission_role_defaults role_default
        on role_default.role_name = v_exact_role
       and role_default.capability_key = catalog.capability_key
      where public.v1_accounts_is_capability_key(catalog.capability_key)
    )
  ) into v_result
  from public.v1_accounts_foundation_settings settings
  where settings.singleton;
  return v_result;
end;
$$;

revoke all on function public.v1_accounts_is_capability_key(text)
  from public, anon, authenticated;
grant execute on function public.v1_accounts_is_capability_key(text)
  to service_role;
revoke all on function public.v1_accounts_has_project_scope(uuid,uuid,text)
  from public, anon, authenticated;
revoke all on function public.v1_permission_has_capability_project_scope(
  uuid,text,uuid
) from public, anon, authenticated;
revoke all on function public.v1_accounts_guard_technical_membership()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_guard_profile_role_change()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_stage_templates()
  from public, anon, authenticated;
revoke all on function public.v1_get_accounts_foundation(uuid)
  from public, anon;
grant execute on function public.v1_get_accounts_foundation(uuid)
  to authenticated, service_role;

-- Reassert the established resolver/guard execution boundary after replacing
-- their bodies.
revoke all on function public.v1_permission_has_project_access(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_permission_candidate_raw(uuid,text,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_permission_legacy_raw(uuid,text,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_permission_guard_assignment()
  from public, anon, authenticated;

commit;
