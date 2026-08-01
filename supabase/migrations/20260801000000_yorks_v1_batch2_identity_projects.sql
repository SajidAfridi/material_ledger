-- Yorks V1 Batch 2: additive identity, project, membership and BOQ-group
-- foundation.  This migration deliberately does not alter legacy JSON tables
-- such as public.projects or public.materialPlans.
--
-- Rollback: disable the V1 rollout flags/routes and revoke the public V1 RPC
-- grants if required.  Do not drop these additive relations after any
-- committed activity: audit, membership and reconciliation history are
-- retained as the rollback record.

create extension if not exists pgcrypto with schema extensions;

-- Reconciliation records are deliberately protected.  They retain uncertainty
-- from legacy data rather than converting it into a privileged V1 identity.
create table if not exists public.v1_reconciliation_issues (
  id uuid primary key default gen_random_uuid(),
  source_system text not null,
  source_entity text not null,
  source_id text not null,
  issue_code text not null,
  field_path text,
  raw_payload jsonb,
  payload_hash text,
  proposed_mapping jsonb,
  resolution_status text not null default 'pending'
    check (resolution_status in ('pending', 'resolved', 'rejected')),
  resolution_reason text,
  resolved_by_auth_user_id uuid,
  resolved_at timestamptz,
  resulting_v1_entity_type text,
  resulting_v1_id uuid,
  created_at timestamptz not null default now(),
  unique (source_system, source_entity, source_id, issue_code)
);

alter table public.v1_reconciliation_issues
  add column if not exists resulting_v1_entity_type text;
alter table public.v1_reconciliation_issues
  add column if not exists resulting_v1_id uuid;

create index if not exists v1_reconciliation_issues_pending_idx
  on public.v1_reconciliation_issues (resolution_status, created_at)
  where resolution_status = 'pending';

-- This is a display/migration mirror only.  It is never the authority for an
-- actor's role; every command re-derives that role from JWT app_metadata.
create table if not exists public.v1_profiles (
  auth_user_id uuid primary key references auth.users (id) on delete restrict,
  legacy_app_user_id text unique,
  display_name text not null default '',
  canonical_role_snapshot text not null default ''
    check (canonical_role_snapshot in (
      '', 'project_engineer', 'site_engineer', 'procurement', 'admin'
    )),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists v1_profiles_directory_idx
  on public.v1_profiles (is_active, display_name, auth_user_id);

create table if not exists public.v1_role_capability_defaults (
  role_name text not null check (role_name in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  capability text not null check (capability in (
    'view_commercials', 'manage_commercials'
  )),
  is_enabled boolean not null default true,
  primary key (role_name, capability)
);

create table if not exists public.v1_user_capabilities (
  auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  capability text not null check (capability in (
    'view_commercials', 'manage_commercials'
  )),
  is_granted boolean not null,
  reason text not null check (btrim(reason) <> ''),
  changed_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (auth_user_id, capability)
);

insert into public.v1_role_capability_defaults (
  role_name,
  capability,
  is_enabled
)
values
  ('procurement', 'view_commercials', true),
  ('procurement', 'manage_commercials', true),
  ('admin', 'view_commercials', true),
  ('admin', 'manage_commercials', true)
on conflict (role_name, capability) do nothing;

create table if not exists public.v1_projects (
  id uuid primary key default gen_random_uuid(),
  project_ref text not null unique check (btrim(project_ref) <> ''),
  name text not null check (btrim(name) <> ''),
  job_contract_reference text,
  project_site text,
  start_date date,
  target_completion_date date,
  notes text,
  state text not null default 'draft'
    check (state in ('draft', 'active', 'on_hold', 'completed', 'archived')),
  current_action_owner_role text not null default 'project_engineer'
    check (current_action_owner_role in (
      'project_engineer', 'site_engineer', 'procurement', 'admin', 'none'
    )),
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    target_completion_date is null
    or start_date is null
    or target_completion_date >= start_date
  )
);

create index if not exists v1_projects_state_updated_idx
  on public.v1_projects (state, updated_at desc);

create table if not exists public.v1_project_parties (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  party_kind text not null check (party_kind in (
    'client', 'consultant', 'main_contractor', 'subcontractor',
    'other_contractor'
  )),
  party_order integer not null default 0 check (party_order >= 0),
  party_name text not null check (btrim(party_name) <> ''),
  contact_name text,
  contact_phone text,
  contact_email text,
  address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, party_kind, party_order)
);

create unique index if not exists v1_project_parties_single_primary_kind_idx
  on public.v1_project_parties (project_id, party_kind)
  where party_kind in ('client', 'consultant', 'main_contractor');

create table if not exists public.v1_project_scopes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  scope_kind text not null check (scope_kind in ('common', 'building')),
  scope_code text not null check (btrim(scope_code) <> ''),
  name text not null check (btrim(name) <> ''),
  floors_levels jsonb not null default '[]'::jsonb
    check (jsonb_typeof(floors_levels) = 'array'),
  scope_flags jsonb not null default '{}'::jsonb
    check (jsonb_typeof(scope_flags) = 'object'),
  delivery_address text,
  is_active boolean not null default true,
  is_immutable boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (
      scope_kind = 'common'
      and scope_code = 'common'
      and name = 'Common / All Buildings'
      and is_immutable
    )
    or (
      scope_kind = 'building'
      and not is_immutable
    )
  )
);

create unique index if not exists v1_project_scopes_common_once_idx
  on public.v1_project_scopes (project_id)
  where scope_kind = 'common';

create unique index if not exists v1_project_scopes_code_unique_idx
  on public.v1_project_scopes (project_id, lower(scope_code));

create table if not exists public.v1_project_attachment_intakes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  file_name text not null check (btrim(file_name) <> ''),
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  intake_status text not null default 'pending_document_link'
    check (intake_status = 'pending_document_link'),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.v1_boq_group_templates (
  id uuid primary key default gen_random_uuid(),
  template_key text not null unique check (template_key ~ '^[a-z0-9_]+$'),
  display_name text not null unique check (btrim(display_name) <> ''),
  display_order integer not null unique check (display_order between 1 and 29),
  is_frozen boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  check (is_frozen)
);

create table if not exists public.v1_boq_groups (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  template_id uuid references public.v1_boq_group_templates (id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  display_order integer not null check (display_order > 0),
  is_custom boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, display_order),
  unique (project_id, template_id),
  check ((is_custom and template_id is null) or (not is_custom and template_id is not null))
);

create table if not exists public.v1_project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  member_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  project_role text not null check (project_role in (
    'project_engineer', 'site_engineer'
  )),
  effective_from timestamptz not null default now(),
  effective_to timestamptz,
  reason text not null check (btrim(reason) <> ''),
  assigned_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  assigned_by_role text not null check (assigned_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  revoked_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  revoked_by_role text check (revoked_by_role is null or revoked_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  revoked_reason text,
  created_at timestamptz not null default now(),
  check (effective_to is null or effective_to > effective_from),
  check (
    (effective_to is null and revoked_by_auth_user_id is null
      and revoked_by_role is null and revoked_reason is null)
    or (effective_to is not null and revoked_by_auth_user_id is not null
      and revoked_by_role is not null and revoked_reason is not null
      and btrim(revoked_reason) <> '')
  )
);

create unique index if not exists v1_project_members_one_active_role_idx
  on public.v1_project_members (project_id, member_auth_user_id, project_role)
  where effective_to is null;

create index if not exists v1_project_members_active_project_idx
  on public.v1_project_members (project_id, project_role, member_auth_user_id)
  where effective_to is null;

create table if not exists public.v1_audit_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (btrim(event_type) <> ''),
  entity_type text not null check (btrim(entity_type) <> ''),
  entity_id uuid not null,
  project_id uuid references public.v1_projects (id) on delete restrict,
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  occurred_at timestamptz not null default now(),
  idempotency_key uuid,
  before_data jsonb,
  after_data jsonb,
  reason text,
  request_hash text,
  unique (actor_auth_user_id, idempotency_key, event_type)
);

create index if not exists v1_audit_events_project_idx
  on public.v1_audit_events (project_id, occurred_at desc);

create table if not exists public.v1_idempotency_keys (
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  command_name text not null check (btrim(command_name) <> ''),
  idempotency_key uuid not null,
  request_hash text not null,
  response_json jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (actor_auth_user_id, command_name, idempotency_key)
);

-- The immutable, ordered default catalogue is installed once.  The migration
-- never overwrites a template row on replay.
insert into public.v1_boq_group_templates (
  template_key,
  display_name,
  display_order,
  is_frozen,
  is_active
)
values
  ('ac_units', 'AC Units', 1, true, true),
  ('ventilation_fans', 'Ventilation Fans', 2, true, true),
  ('mfd_msfd_msd_mvcd_vcd', 'MFD, MSFD, MSD, MVCD & VCD', 3, true, true),
  ('air_inlet_outlet', 'Air Inlet & Outlet', 4, true, true),
  ('cable_tray', 'Cable Tray', 5, true, true),
  ('sound_attenuator', 'Sound Attenuator', 6, true, true),
  ('electric_duct_heater', 'Electric Duct Heater', 7, true, true),
  ('fire_rated_duct_vcd', 'Fire-Rated Duct & VCD', 8, true, true),
  ('hvac_control_panel', 'HVAC Control Panel', 9, true, true),
  ('aluminium_cladding_sheet', 'Aluminium Cladding Sheet', 10, true, true),
  ('flexible_duct_connector', 'Flexible Duct Connector', 11, true, true),
  ('spring_mounts_neoprene_pads', 'Spring Mounts & Neoprene Pads', 12, true, true),
  ('junction_box', 'Junction Box', 13, true, true),
  ('power_control_cables', 'Power & Control Cables', 14, true, true),
  ('glands_accessories', 'Glands & Accessories', 15, true, true),
  ('electrical_material', 'Electrical Material', 16, true, true),
  ('refrigerant_pipe', 'Refrigerant Pipe', 17, true, true),
  ('container_temporary_facilities', 'Container & Temporary Facilities', 18, true, true),
  ('fire_rated_gi_duct_draft_paper', 'Fire-Rated & GI Duct Draft Paper', 19, true, true),
  ('gi_ductwork', 'GI Ductwork', 20, true, true),
  ('duct_insulation', 'Duct Insulation', 21, true, true),
  ('chilled_water_piping', 'Chilled Water Piping', 22, true, true),
  ('pipe_insulation', 'Pipe Insulation', 23, true, true),
  ('valves_accessories', 'Valves & Accessories', 24, true, true),
  ('drainage_piping', 'Drainage Piping', 25, true, true),
  ('supports_accessories', 'Supports & Accessories', 26, true, true),
  ('filters_consumables', 'Filters & Consumables', 27, true, true),
  ('testing_commissioning_materials', 'Testing & Commissioning Materials', 28, true, true),
  ('miscellaneous_common_materials', 'Miscellaneous / Common Materials', 29, true, true)
on conflict (template_key) do nothing;

-- Exact application roles always come from server-controlled app_metadata in
-- the authenticated JWT.  A PostgreSQL API role or editable user_metadata is
-- never treated as an application role.
create or replace function public.v1_current_role()
returns text
language sql
stable
set search_path = ''
as $$
  select case coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end;
$$;

create or replace function public.v1_current_actor_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select auth.uid();
$$;

create or replace function public.v1_is_valid_role(p_role text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_role in ('project_engineer', 'site_engineer', 'procurement', 'admin');
$$;

create or replace function public.v1_assert_object_keys(
  p_value jsonb,
  p_allowed_keys text[],
  p_context text
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_unknown text[];
begin
  if p_value is null or jsonb_typeof(p_value) <> 'object' then
    raise exception 'V1_%_MUST_BE_AN_OBJECT', upper(p_context)
      using errcode = '22023';
  end if;

  select array_agg(key order by key)
    into v_unknown
  from jsonb_object_keys(p_value) as key
  where not (key = any (p_allowed_keys));

  if v_unknown is not null then
    raise exception 'V1_UNKNOWN_%_FIELDS: %', upper(p_context),
      array_to_string(v_unknown, ', ')
      using errcode = '22023';
  end if;
end;
$$;

-- Directory-facing labels are never permitted to become an email address. The
-- opaque UUID fallback is intentionally not user-facing: the Flutter safe-name
-- helper replaces it with localized copy before presentation.
create or replace function public.v1_safe_profile_display_name(
  p_display_name text,
  p_auth_user_id uuid
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when nullif(btrim(p_display_name), '') is null
      or position('@' in btrim(p_display_name)) > 0
      then p_auth_user_id::text
    else btrim(p_display_name)
  end;
$$;

-- Synchronise a safe profile mirror only from server-owned Auth fields.
-- Unknown/legacy roles are quarantined and never become V1 profiles or roles.
create or replace function public.v1_sync_profile_from_auth(
  p_auth_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user auth.users%rowtype;
  v_role text;
  v_legacy_app_user_id text;
  v_display_name text;
  v_is_active boolean;
begin
  select * into v_user
  from auth.users
  where id = p_auth_user_id;

  if not found then
    raise exception 'V1_AUTH_USER_NOT_FOUND'
      using errcode = '22023';
  end if;

  v_role := case coalesce(v_user.raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end;

  if v_role = '' then
    update public.v1_profiles
       set is_active = false,
           updated_at = clock_timestamp()
     where auth_user_id = p_auth_user_id;

    -- Every noncanonical Auth role is quarantined.  The narrow `engineer`
    -- code is retained because an explicit Edge role mapping resolves it in
    -- the same Auth transaction; all other/missing values remain visible as
    -- a stable reconciliation issue instead of silently disappearing.
    insert into public.v1_reconciliation_issues (
      source_system,
      source_entity,
      source_id,
      issue_code,
      field_path,
      raw_payload,
      payload_hash
    )
    values (
      'auth',
      'users',
      p_auth_user_id::text,
      case coalesce(v_user.raw_app_meta_data ->> 'role', '')
        when 'engineer' then 'legacy_engineer_requires_explicit_mapping'
        else 'noncanonical_auth_role_requires_explicit_mapping'
      end,
      'raw_app_meta_data.role',
      jsonb_build_object(
        'role', v_user.raw_app_meta_data ->> 'role',
        'legacy_app_user_id', v_user.raw_app_meta_data ->> 'app_user_id'
      ),
      encode(
        extensions.digest(
          convert_to(coalesce(v_user.raw_app_meta_data::text, ''), 'utf8'),
          'sha256'
        ),
        'hex'
      )
    )
    on conflict (source_system, source_entity, source_id, issue_code)
      do nothing;

    return;
  end if;

  v_legacy_app_user_id := nullif(
    btrim(coalesce(v_user.raw_app_meta_data ->> 'app_user_id', '')),
    ''
  );
  v_display_name := public.v1_safe_profile_display_name(
    v_user.raw_user_meta_data ->> 'full_name',
    p_auth_user_id
  );
  v_is_active := v_user.banned_until is null
    or v_user.banned_until <= clock_timestamp();

  if v_legacy_app_user_id is not null and exists (
    select 1
    from public.v1_profiles profile
    where profile.legacy_app_user_id = v_legacy_app_user_id
      and profile.auth_user_id <> p_auth_user_id
  ) then
    insert into public.v1_reconciliation_issues (
      source_system,
      source_entity,
      source_id,
      issue_code,
      field_path,
      raw_payload,
      payload_hash
    )
    values (
      'auth',
      'users',
      p_auth_user_id::text,
      'duplicate_legacy_app_user_id',
      'raw_app_meta_data.app_user_id',
      jsonb_build_object('legacy_app_user_id', v_legacy_app_user_id),
      encode(
        extensions.digest(convert_to(v_legacy_app_user_id, 'utf8'), 'sha256'),
        'hex'
      )
    )
    on conflict (source_system, source_entity, source_id, issue_code)
      do nothing;
    v_legacy_app_user_id := null;
  end if;

  insert into public.v1_profiles (
    auth_user_id,
    legacy_app_user_id,
    display_name,
    canonical_role_snapshot,
    is_active
  )
  values (
    p_auth_user_id,
    v_legacy_app_user_id,
    v_display_name,
    v_role,
    v_is_active
  )
  on conflict (auth_user_id) do update
    set legacy_app_user_id = coalesce(
          public.v1_profiles.legacy_app_user_id,
          excluded.legacy_app_user_id
        ),
        display_name = excluded.display_name,
        canonical_role_snapshot = excluded.canonical_role_snapshot,
        is_active = excluded.is_active,
        updated_at = clock_timestamp();
end;
$$;

create or replace function public.v1_sync_profile_from_auth_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_sync_profile_from_auth(new.id);
  return new;
end;
$$;

drop trigger if exists v1_sync_profile_from_auth on auth.users;
create trigger v1_sync_profile_from_auth
after insert or update of raw_app_meta_data, raw_user_meta_data, email, banned_until
on auth.users
for each row execute function public.v1_sync_profile_from_auth_trigger();

select public.v1_sync_profile_from_auth(id)
from auth.users;

-- The Edge admin-users endpoint carries this short-lived context in the same
-- Auth write that it is asking GoTrue to make.  The BEFORE trigger below is
-- deliberately the transaction boundary for both the Auth mutation and its
-- audit event: a failed audit aborts the Auth write, and the context is
-- removed before the profile-sync AFTER trigger observes the new Auth row.
--
-- A context-free Auth change still passes through the last-active-Admin guard.
-- This keeps the invariant authoritative even for a future trusted server
-- caller that does not use the current Edge endpoint.
create or replace function public.v1_auth_user_is_active(
  p_banned_until timestamptz
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_banned_until is null or p_banned_until <= clock_timestamp();
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
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    when 'engineer' then 'engineer'
    else 'unrecognized'
  end;
$$;

create or replace function public.v1_auth_users_admin_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_app_metadata jsonb := coalesce(new.raw_app_meta_data, '{}'::jsonb);
  v_context jsonb;
  v_actor_text text;
  v_actor_auth_user_id uuid;
  v_action text;
  v_idempotency_text text;
  v_idempotency_key uuid;
  v_request_hash text;
  v_event_type text;
  v_actor_auth auth.users%rowtype;
  v_before_data jsonb;
  v_after_data jsonb;
  v_reason text;
  v_existing_audit public.v1_audit_events%rowtype;
  v_is_retry boolean := false;
  v_old_raw_role text;
  v_new_raw_role text;
  v_reconciliation_issue_code text;
  v_reconciliation_issue public.v1_reconciliation_issues%rowtype;
  v_reconciliation_before jsonb;
begin
  -- This branch deliberately applies even when there is no audit context.
  -- Serialisation means two concurrent role-demotion/deactivation requests
  -- cannot both count the other Admin from an obsolete snapshot.
  if tg_op = 'UPDATE'
    and coalesce(old.raw_app_meta_data ->> 'role', '') = 'admin'
    and public.v1_auth_user_is_active(old.banned_until)
    and (
      coalesce(new.raw_app_meta_data ->> 'role', '') <> 'admin'
      or not public.v1_auth_user_is_active(new.banned_until)
    )
  then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('v1_last_active_exact_admin', 0)
    );

    if not exists (
      select 1
      from auth.users other_user
      where other_user.id <> old.id
        and coalesce(other_user.raw_app_meta_data ->> 'role', '') = 'admin'
        and public.v1_auth_user_is_active(other_user.banned_until)
    ) then
      raise exception 'V1_LAST_ACTIVE_ADMIN_REQUIRED'
        using errcode = '55000';
    end if;
  end if;

  v_context := v_new_app_metadata -> '_v1_admin_audit_context';
  if v_context is null then
    -- Quarantined identities can become exact V1 identities only through an
    -- audited Admin command.  Otherwise a trusted direct Auth write could
    -- create a profile while leaving the protected reconciliation issue
    -- pending, which is both misleading and not replay-safe.
    if tg_op = 'UPDATE'
      and not public.v1_is_valid_role(
        coalesce(old.raw_app_meta_data ->> 'role', '')
      )
      and public.v1_is_valid_role(
        coalesce(new.raw_app_meta_data ->> 'role', '')
      )
    then
      raise exception
        'V1_NONCANONICAL_ROLE_MAPPING_REQUIRES_AUDITED_ADMIN_COMMAND'
        using errcode = '42501';
    end if;
    return new;
  end if;

  perform public.v1_assert_object_keys(
    v_context,
    array[
      'actor_auth_user_id', 'action', 'idempotency_key', 'request_hash'
    ],
    'admin_audit_context'
  );
  v_actor_text := nullif(
    btrim(coalesce(v_context ->> 'actor_auth_user_id', '')),
    ''
  );
  v_action := nullif(btrim(coalesce(v_context ->> 'action', '')), '');
  v_idempotency_text := nullif(
    btrim(coalesce(v_context ->> 'idempotency_key', '')),
    ''
  );
  v_request_hash := lower(nullif(
    btrim(coalesce(v_context ->> 'request_hash', '')),
    ''
  ));
  if v_actor_text is null
    or v_action is null
    or v_idempotency_text is null
    or v_request_hash is null
  then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  begin
    v_actor_auth_user_id := v_actor_text::uuid;
  exception
    when invalid_text_representation then
      raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_INVALID'
        using errcode = '22023';
  end;
  begin
    v_idempotency_key := v_idempotency_text::uuid;
  exception
    when invalid_text_representation then
      raise exception 'V1_ADMIN_AUDIT_CONTEXT_IDEMPOTENCY_KEY_INVALID'
        using errcode = '22023';
  end;
  if v_request_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_REQUEST_HASH_INVALID'
      using errcode = '22023';
  end if;

  if v_action not in (
    'created', 'role_changed', 'password_reset', 'active_changed'
  ) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTION_INVALID'
      using errcode = '22023';
  end if;
  if (tg_op = 'INSERT' and v_action <> 'created')
    or (tg_op = 'UPDATE' and v_action = 'created') then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTION_INVALID_FOR_OPERATION'
      using errcode = '22023';
  end if;
  v_event_type := 'admin_user_' || v_action;

  -- The actor is derived from a server-only context and then checked against
  -- live Auth state plus the V1 profile mirror.  A cached Admin JWT, editable
  -- user metadata, or a stale/deactivated profile cannot authorize this write.
  select * into v_actor_auth
  from auth.users actor_user
  where actor_user.id = v_actor_auth_user_id
  for key share;
  if not found
    or coalesce(v_actor_auth.raw_app_meta_data ->> 'role', '') <> 'admin'
    or not public.v1_auth_user_is_active(v_actor_auth.banned_until)
  then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN'
      using errcode = '42501';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor_auth_user_id);
  if not exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = v_actor_auth_user_id
      and profile.is_active
      and profile.canonical_role_snapshot = 'admin'
  ) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    v_before_data := null;
  else
    v_before_data := jsonb_build_object(
      'role', public.v1_safe_auth_audit_role(old.raw_app_meta_data),
      'active', public.v1_auth_user_is_active(old.banned_until)
    );
  end if;
  v_after_data := jsonb_build_object(
    'role', public.v1_safe_auth_audit_role(new.raw_app_meta_data),
    'active', public.v1_auth_user_is_active(new.banned_until)
  );
  if v_action = 'password_reset' then
    v_after_data := v_after_data || jsonb_build_object('password_reset', true);
  end if;
  v_reason := case v_action
    when 'created' then 'Admin user provisioning command'
    when 'role_changed' then 'Admin user role change'
    when 'password_reset' then 'Admin password reset command'
    when 'active_changed' then 'Admin account activation change'
  end;

  -- The trigger is the durable command boundary for GoTrue writes.  The Edge
  -- sends an opaque HMAC request hash (never raw password or input) plus a
  -- client-stable UUID.  A transaction lock and the primary admin audit event
  -- form the claim: identical retries keep the Auth outcome but add neither a
  -- duplicate audit nor duplicate reconciliation resolution; a reused key for
  -- a different target, safe outcome or hash conflicts before Auth commits.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor_auth_user_id::text || '|' || v_event_type || '|'
        || v_idempotency_key::text,
      0
    )
  );
  select * into v_existing_audit
  from public.v1_audit_events audit
  where audit.actor_auth_user_id = v_actor_auth_user_id
    and audit.event_type = v_event_type
    and audit.idempotency_key = v_idempotency_key
  for update;
  if found then
    if v_existing_audit.entity_type <> 'auth_user'
      or v_existing_audit.entity_id <> new.id
      or v_existing_audit.request_hash is distinct from v_request_hash
      or v_existing_audit.after_data is distinct from v_after_data
    then
      raise exception 'V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST'
        using errcode = '22023';
    end if;
    -- A completed Auth-admin retry must be a true no-op.  Allowing NEW to
    -- continue would let an old deactivate/password/role command reapply
    -- after a later valid command changed the account, without a fresh audit.
    -- Returning OLD keeps the current row unchanged while still letting the
    -- Auth API treat the retry as a completed update.
    if tg_op = 'UPDATE' then
      return old;
    end if;
    v_is_retry := true;
  else
    -- Do not delegate this insert to a post-Auth Edge request.  It must be in
    -- this Auth transaction so a successful user mutation always has exactly
    -- the corresponding trusted, safe audit event.
    insert into public.v1_audit_events (
      event_type,
      entity_type,
      entity_id,
      project_id,
      actor_auth_user_id,
      actor_role,
      occurred_at,
      idempotency_key,
      before_data,
      after_data,
      reason,
      request_hash
    )
    values (
      v_event_type,
      'auth_user',
      new.id,
      null,
      v_actor_auth_user_id,
      'admin',
      clock_timestamp(),
      v_idempotency_key,
      v_before_data,
      v_after_data,
      v_reason,
      v_request_hash
    );
  end if;

  -- Every quarantined role (not only the historical `engineer` label) must be
  -- explicitly mapped through the same Auth transaction.  The relevant issue
  -- is resolved only on the first successful command claim; a retry cannot
  -- create another audit or resolve an already-complete issue a second time.
  if tg_op = 'UPDATE' then
    v_old_raw_role := coalesce(old.raw_app_meta_data ->> 'role', '');
    v_new_raw_role := coalesce(new.raw_app_meta_data ->> 'role', '');
  end if;
  if tg_op = 'UPDATE'
    and not v_is_retry
    and not public.v1_is_valid_role(v_old_raw_role)
    and public.v1_is_valid_role(v_new_raw_role)
  then
    if v_action <> 'role_changed' then
      raise exception
        'V1_NONCANONICAL_ROLE_MAPPING_REQUIRES_ROLE_AUDIT_ACTION'
        using errcode = '22023';
    end if;

    v_reconciliation_issue_code := case v_old_raw_role
      when 'engineer' then 'legacy_engineer_requires_explicit_mapping'
      else 'noncanonical_auth_role_requires_explicit_mapping'
    end;

    select * into v_reconciliation_issue
    from public.v1_reconciliation_issues issue
    where issue.source_system = 'auth'
      and issue.source_entity = 'users'
      and issue.source_id = new.id::text
      and issue.issue_code = v_reconciliation_issue_code
    for update;
    if not found then
      raise exception 'V1_NONCANONICAL_ROLE_RECONCILIATION_NOT_FOUND'
        using errcode = '55000';
    end if;
    if v_reconciliation_issue.resolution_status <> 'pending' then
      raise exception 'V1_NONCANONICAL_ROLE_RECONCILIATION_NOT_PENDING'
        using errcode = '55000';
    end if;

    v_reconciliation_before := jsonb_build_object(
      'resolution_status', v_reconciliation_issue.resolution_status
    );
    update public.v1_reconciliation_issues issue
       set resolution_status = 'resolved',
           resolution_reason =
             'Explicit Admin role mapping resolved noncanonical Auth role reconciliation',
           resolved_by_auth_user_id = v_actor_auth_user_id,
           resolved_at = clock_timestamp(),
           resulting_v1_entity_type = 'profile',
           resulting_v1_id = new.id
     where issue.id = v_reconciliation_issue.id
     returning * into v_reconciliation_issue;

    insert into public.v1_audit_events (
      event_type,
      entity_type,
      entity_id,
      project_id,
      actor_auth_user_id,
      actor_role,
      occurred_at,
      idempotency_key,
      before_data,
      after_data,
      reason,
      request_hash
    )
    values (
      'reconciliation_issue_resolved',
      'reconciliation_issue',
      v_reconciliation_issue.id,
      null,
      v_actor_auth_user_id,
      'admin',
      clock_timestamp(),
      v_idempotency_key,
      v_reconciliation_before,
      jsonb_build_object(
        'resolution_status', v_reconciliation_issue.resolution_status,
        'resulting_v1_entity_type',
          v_reconciliation_issue.resulting_v1_entity_type,
        'resulting_v1_id', v_reconciliation_issue.resulting_v1_id,
        'resolved_by_auth_user_id',
          v_reconciliation_issue.resolved_by_auth_user_id,
        'resolved_at', v_reconciliation_issue.resolved_at
      ),
      v_reconciliation_issue.resolution_reason,
      v_request_hash
    );
  end if;

  -- The transient context must never persist in Auth app_metadata or appear
  -- in the profile-sync trigger's server-owned input.
  new.raw_app_meta_data := v_new_app_metadata - '_v1_admin_audit_context';
  return new;
end;
$$;

drop trigger if exists v1_auth_users_admin_audit on auth.users;
create trigger v1_auth_users_admin_audit
before insert or update of raw_app_meta_data, raw_user_meta_data, banned_until
on auth.users
for each row execute function public.v1_auth_users_admin_audit_trigger();

-- Auth can revoke a user while an already-issued JWT remains locally cached.
-- Commands re-sync the actor first, then use this protected predicate before
-- claiming idempotency or changing any project state.
create or replace function public.v1_current_actor_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1
      from public.v1_profiles profile
      where profile.auth_user_id = auth.uid()
        and profile.is_active
        and profile.canonical_role_snapshot = public.v1_current_role()
    );
$$;

-- This narrow wrapper is granted only because RLS expressions execute with
-- the querying role. It exposes no profile fields and delegates to the
-- private predicate above, which remains unavailable as a general RPC.
create or replace function public.v1_rls_current_actor_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_actor_is_active();
$$;

-- Use a protected server lookup for capability defaults/overrides.  A profile
-- row or editable metadata cannot grant capability by itself.
create or replace function public.v1_has_capability(p_capability text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_override boolean;
  v_default boolean;
begin
  if v_actor is null
    or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if p_capability not in ('view_commercials', 'manage_commercials') then
    return false;
  end if;
  -- Product Decision §3 is an invariant rather than a UI convention: a
  -- Project/Site Engineer may receive a view override, but never commercial
  -- management even if a malformed historical override somehow exists.
  if p_capability = 'manage_commercials'
    and v_role in ('project_engineer', 'site_engineer') then
    return false;
  end if;
  -- A commercial manager must also retain the ability to view the protected
  -- value it is changing.  Revoking view therefore fail-closes direct writes
  -- even if a previous manage override/default remains present.
  if p_capability = 'manage_commercials'
    and not public.v1_has_capability('view_commercials') then
    return false;
  end if;

  select capability.is_granted
    into v_override
  from public.v1_user_capabilities capability
  where capability.auth_user_id = v_actor
    and capability.capability = p_capability;

  if found then
    return v_override;
  end if;

  select defaults.is_enabled
    into v_default
  from public.v1_role_capability_defaults defaults
  where defaults.role_name = v_role
    and defaults.capability = p_capability;

  return coalesce(v_default, false);
end;
$$;

-- This is deliberately a non-commercial authorization envelope.  It carries
-- no role label, profile/display field, cost, supplier or operational data and
-- is shared by the self-refresh and Admin capability commands below.
create or replace function public.v1_commercial_capability_envelope(
  p_target_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_target public.v1_profiles%rowtype;
  v_view_default boolean := false;
  v_manage_default boolean := false;
  v_view_override boolean;
  v_manage_override boolean;
  v_view_effective boolean;
  v_manage_effective boolean;
begin
  select * into v_target
  from public.v1_profiles profile
  where profile.auth_user_id = p_target_auth_user_id;
  if not found or v_target.canonical_role_snapshot = '' then
    raise exception 'V1_COMMERCIAL_CAPABILITY_TARGET_NOT_CANONICAL'
      using errcode = '22023';
  end if;

  select defaults.is_enabled into v_view_default
  from public.v1_role_capability_defaults defaults
  where defaults.role_name = v_target.canonical_role_snapshot
    and defaults.capability = 'view_commercials';
  select defaults.is_enabled into v_manage_default
  from public.v1_role_capability_defaults defaults
  where defaults.role_name = v_target.canonical_role_snapshot
    and defaults.capability = 'manage_commercials';
  select capability.is_granted into v_view_override
  from public.v1_user_capabilities capability
  where capability.auth_user_id = p_target_auth_user_id
    and capability.capability = 'view_commercials';
  select capability.is_granted into v_manage_override
  from public.v1_user_capabilities capability
  where capability.auth_user_id = p_target_auth_user_id
    and capability.capability = 'manage_commercials';

  v_view_effective := v_target.is_active
    and coalesce(v_view_override, v_view_default, false);
  v_manage_effective := v_target.is_active
    and v_target.canonical_role_snapshot in ('procurement', 'admin')
    and v_view_effective
    and coalesce(v_manage_override, v_manage_default, false);

  return jsonb_build_object(
    'capabilities', jsonb_build_object(
      'view_commercials', jsonb_build_object(
        'role_default', coalesce(v_view_default, false),
        'effective', v_view_effective,
        'override', v_view_override
      ),
      'manage_commercials', jsonb_build_object(
        'role_default', coalesce(v_manage_default, false),
        'effective', v_manage_effective,
        'override', v_manage_override
      )
    )
  );
end;
$$;

-- RLS expressions execute with the querying role, so use a narrow callable
-- wrapper rather than exposing the capability implementation helper itself.
create or replace function public.v1_rls_has_commercial_capability(
  p_capability text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_has_capability(p_capability);
$$;

-- The retained flag-off commercial shell is narrowly limited to an active,
-- live Auth user whose *current* exact server role is the historical
-- `engineer` label and which has never materialised a V1 profile.  RLS must
-- not choose this legacy branch from a stale JWT alone: after an explicit
-- engineer -> V1 mapping, that old token has neither a current legacy Auth
-- identity nor an unmaterialised profile and therefore fails closed.
create or replace function public.v1_rls_can_use_legacy_commercial_fallback()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and coalesce(
      (select auth.jwt()) -> 'app_metadata' ->> 'role', ''
    ) = 'engineer'
    and exists (
      select 1
      from auth.users auth_user
      where auth_user.id = auth.uid()
        and coalesce(auth_user.raw_app_meta_data ->> 'role', '') = 'engineer'
        and public.v1_auth_user_is_active(auth_user.banned_until)
    )
    and not exists (
      select 1
      from public.v1_profiles profile
      where profile.auth_user_id = auth.uid()
    );
$$;

-- The safe directory is an RPC rather than a broad table grant.  It returns
-- only selection data and no email, capability or legacy identity fields.
create or replace function public.v1_list_active_profile_directory()
returns table (
  auth_user_id uuid,
  display_name text,
  eligible_role text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or v_role not in (
    'project_engineer', 'site_engineer', 'admin'
  ) then
    raise exception 'V1_PROJECT_DIRECTORY_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  perform public.v1_sync_profile_from_auth(auth.uid());
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  return query
  select
    profile.auth_user_id,
    public.v1_safe_profile_display_name(
      profile.display_name,
      profile.auth_user_id
    ),
    profile.canonical_role_snapshot
  from public.v1_profiles profile
  where profile.is_active
    and profile.canonical_role_snapshot in ('project_engineer', 'site_engineer')
  order by lower(
    public.v1_safe_profile_display_name(
      profile.display_name,
      profile.auth_user_id
    )
  ), profile.auth_user_id;
end;
$$;

create or replace function public.v1_has_active_project_membership(
  p_project_id uuid,
  p_auth_user_id uuid,
  p_required_project_role text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_project_members member
    join public.v1_profiles profile
      on profile.auth_user_id = member.member_auth_user_id
    where member.project_id = p_project_id
      and member.member_auth_user_id = p_auth_user_id
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
      and profile.is_active
      and (
        p_required_project_role is null
        or member.project_role = p_required_project_role
      )
  );
$$;

create or replace function public.v1_project_readable(p_project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_state text;
begin
  if v_actor is null
    or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  if v_role = 'admin' then
    return true;
  end if;

  if v_role in ('project_engineer', 'site_engineer') then
    return public.v1_has_active_project_membership(
      p_project_id,
      v_actor,
      null
    );
  end if;

  if v_role = 'procurement' then
    select project.state into v_state
    from public.v1_projects project
    where project.id = p_project_id;
    return v_state in ('active', 'on_hold');
  end if;

  return false;
end;
$$;

create or replace function public.v1_can_manage_project(p_project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
begin
  if v_actor is null
    or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  if v_role = 'admin' then
    return true;
  end if;

  return v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      p_project_id,
      v_actor,
      'project_engineer'
    );
end;
$$;

create or replace function public.v1_has_active_project_engineer(
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_project_members member
    join public.v1_profiles profile
      on profile.auth_user_id = member.member_auth_user_id
    where member.project_id = p_project_id
      and member.project_role = 'project_engineer'
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
      and profile.is_active
  );
$$;

create or replace function public.v1_hash_json(p_value jsonb)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select encode(
    extensions.digest(convert_to(p_value::text, 'utf8'), 'sha256'),
    'hex'
  );
$$;

create or replace function public.v1_idempotency_get_or_claim(
  p_command_name text,
  p_idempotency_key uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_existing public.v1_idempotency_keys%rowtype;
  v_hash text := public.v1_hash_json(p_payload);
begin
  if v_actor is null or public.v1_current_role() = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;
  if p_idempotency_key is null then
    raise exception 'V1_IDEMPOTENCY_KEY_REQUIRED'
      using errcode = '22023';
  end if;

  -- Serialise the previously-absent-key path.  Without this transaction-scoped
  -- lock, two same-key requests can both observe no row and one would fail on
  -- the primary key instead of returning the first committed response.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor::text || '|' || p_command_name || '|' || p_idempotency_key::text,
      0
    )
  );

  select * into v_existing
  from public.v1_idempotency_keys key_record
  where key_record.actor_auth_user_id = v_actor
    and key_record.command_name = p_command_name
    and key_record.idempotency_key = p_idempotency_key
  for update;

  if found then
    if v_existing.request_hash <> v_hash then
      raise exception 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD'
        using errcode = '22023';
    end if;
    if v_existing.response_json is null then
      raise exception 'V1_IDEMPOTENCY_COMMAND_STILL_IN_FLIGHT'
        using errcode = '55P03';
    end if;
    return v_existing.response_json;
  end if;

  insert into public.v1_idempotency_keys (
    actor_auth_user_id,
    command_name,
    idempotency_key,
    request_hash
  )
  values (v_actor, p_command_name, p_idempotency_key, v_hash);

  return null;
end;
$$;

create or replace function public.v1_complete_idempotency(
  p_command_name text,
  p_idempotency_key uuid,
  p_response jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  update public.v1_idempotency_keys key_record
     set response_json = p_response,
         completed_at = clock_timestamp()
   where key_record.actor_auth_user_id = v_actor
     and key_record.command_name = p_command_name
     and key_record.idempotency_key = p_idempotency_key;

  if not found then
    raise exception 'V1_IDEMPOTENCY_CLAIM_NOT_FOUND'
      using errcode = '55000';
  end if;
end;
$$;

create or replace function public.v1_write_audit_event(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_project_id uuid,
  p_before_data jsonb,
  p_after_data jsonb,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_id uuid;
begin
  if v_actor is null or v_role = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  insert into public.v1_audit_events (
    event_type,
    entity_type,
    entity_id,
    project_id,
    actor_auth_user_id,
    actor_role,
    occurred_at,
    idempotency_key,
    before_data,
    after_data,
    reason,
    request_hash
  )
  values (
    p_event_type,
    p_entity_type,
    p_entity_id,
    p_project_id,
    v_actor,
    v_role,
    clock_timestamp(),
    p_idempotency_key,
    p_before_data,
    p_after_data,
    p_reason,
    (
      select key_record.request_hash
      from public.v1_idempotency_keys key_record
      where key_record.actor_auth_user_id = v_actor
        and key_record.idempotency_key = p_idempotency_key
      order by key_record.created_at desc
      limit 1
    )
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Current-session capability refresh is intentionally parameterless: Flutter
-- can fail closed and purge protected local state without ever receiving a
-- role input, target ID or commercial business projection.
create or replace function public.v1_get_current_commercial_capabilities()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or public.v1_current_role() = '' then
    raise exception 'V1_ACTIVE_V1_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_V1_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  return public.v1_commercial_capability_envelope(v_actor);
end;
$$;

-- Admin-facing lookups are separate from the parameterless self projection.
-- This response remains the same safe typed authorization envelope, with no
-- raw profile data or commercial record fields.
create or replace function public.v1_get_user_commercial_capabilities(
  p_target_auth_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or public.v1_current_role() <> 'admin' then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
  if p_target_auth_user_id is null then
    raise exception 'V1_COMMERCIAL_CAPABILITY_TARGET_REQUIRED'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(p_target_auth_user_id);
  return public.v1_commercial_capability_envelope(p_target_auth_user_id);
end;
$$;

-- The only V1 commercial-override writer.  It re-derives the Admin and target
-- from authoritative Auth/profile rows, validates Product Decision §3, uses
-- an idempotency key and appends an audit event.  Direct table mutation stays
-- unavailable to authenticated clients.
create or replace function public.v1_set_user_commercial_capability(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_auth_user_id uuid;
  v_target_auth auth.users%rowtype;
  v_target public.v1_profiles%rowtype;
  v_capability text;
  v_is_granted boolean;
  v_reason text;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['target_auth_user_id', 'capability', 'is_granted', 'reason'],
    'set_user_commercial_capability_payload'
  );
  if v_actor is null or public.v1_current_role() <> 'admin' then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  begin
    v_target_auth_user_id := nullif(
      btrim(coalesce(p_payload ->> 'target_auth_user_id', '')),
      ''
    )::uuid;
  exception
    when invalid_text_representation then
      raise exception 'V1_COMMERCIAL_CAPABILITY_TARGET_INVALID'
        using errcode = '22023';
  end;
  v_capability := nullif(
    btrim(coalesce(p_payload ->> 'capability', '')),
    ''
  );
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if not (p_payload ? 'is_granted')
    or jsonb_typeof(p_payload -> 'is_granted') <> 'boolean' then
    raise exception 'V1_COMMERCIAL_CAPABILITY_GRANT_BOOLEAN_REQUIRED'
      using errcode = '22023';
  end if;
  v_is_granted := (p_payload ->> 'is_granted')::boolean;
  if v_target_auth_user_id is null
    or v_capability not in ('view_commercials', 'manage_commercials')
    or v_reason is null then
    raise exception 'V1_COMMERCIAL_CAPABILITY_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if char_length(v_reason) > 2000 then
    raise exception 'V1_COMMERCIAL_CAPABILITY_REASON_TOO_LONG'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  -- Lock the Auth target before refreshing its profile.  A concurrent role or
  -- activation change cannot make an override decision against a stale target
  -- snapshot and then commit ahead of this command.
  select * into v_target_auth
  from auth.users auth_user
  where auth_user.id = v_target_auth_user_id
  for update;
  if not found then
    raise exception 'V1_COMMERCIAL_CAPABILITY_TARGET_NOT_FOUND'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_target_auth_user_id);
  select * into v_target
  from public.v1_profiles profile
  where profile.auth_user_id = v_target_auth_user_id
  for update;
  if not found or v_target.canonical_role_snapshot = '' then
    raise exception 'V1_COMMERCIAL_CAPABILITY_TARGET_NOT_CANONICAL'
      using errcode = '22023';
  end if;
  if v_capability = 'manage_commercials'
    and v_target.canonical_role_snapshot in (
      'project_engineer', 'site_engineer'
    ) then
    raise exception 'V1_ENGINEER_MANAGE_COMMERCIALS_NOT_ALLOWED'
      using errcode = '42501';
  end if;
  if v_is_granted and not v_target.is_active then
    raise exception 'V1_COMMERCIAL_CAPABILITY_GRANT_TARGET_INACTIVE'
      using errcode = '42501';
  end if;

  -- Authorization and the target's current exact role are checked before a
  -- completed retry can be returned.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_set_user_commercial_capability',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  v_before := public.v1_commercial_capability_envelope(v_target_auth_user_id)
    -> 'capabilities' -> v_capability;

  insert into public.v1_user_capabilities (
    auth_user_id,
    capability,
    is_granted,
    reason,
    changed_by_auth_user_id,
    created_at,
    updated_at
  )
  values (
    v_target_auth_user_id,
    v_capability,
    v_is_granted,
    v_reason,
    v_actor,
    clock_timestamp(),
    clock_timestamp()
  )
  on conflict (auth_user_id, capability) do update
    set is_granted = excluded.is_granted,
        reason = excluded.reason,
        changed_by_auth_user_id = excluded.changed_by_auth_user_id,
        updated_at = excluded.updated_at;

  v_response := public.v1_commercial_capability_envelope(v_target_auth_user_id);
  perform public.v1_write_audit_event(
    'commercial_capability_changed',
    'user_capability',
    v_target_auth_user_id,
    null,
    v_before,
    v_response -> 'capabilities' -> v_capability,
    v_reason,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_set_user_commercial_capability',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

-- Reconciliation is an administrative migration record, not a generic JSON
-- collection.  The command below preserves the raw/source evidence while
-- writing a typed resolution, actor, server timestamp and resulting V1 ID.
create or replace function public.v1_resolve_reconciliation_issue(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_issue public.v1_reconciliation_issues%rowtype;
  v_issue_id uuid;
  v_resolution_status text;
  v_resolution_reason text;
  v_resulting_v1_entity_type text;
  v_resulting_v1_id uuid;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'issue_id',
      'resolution_status',
      'resolution_reason',
      'resulting_v1_entity_type',
      'resulting_v1_id'
    ],
    'resolve_reconciliation_issue_payload'
  );
  if v_actor is null or v_role <> 'admin' then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  begin
    v_issue_id := nullif(
      btrim(coalesce(p_payload ->> 'issue_id', '')),
      ''
    )::uuid;
  exception
    when invalid_text_representation then
      raise exception 'V1_RECONCILIATION_ISSUE_ID_INVALID'
        using errcode = '22023';
  end;
  v_resolution_status := nullif(
    btrim(coalesce(p_payload ->> 'resolution_status', '')),
    ''
  );
  v_resolution_reason := nullif(
    btrim(coalesce(p_payload ->> 'resolution_reason', '')),
    ''
  );
  v_resulting_v1_entity_type := nullif(
    btrim(coalesce(p_payload ->> 'resulting_v1_entity_type', '')),
    ''
  );
  begin
    v_resulting_v1_id := nullif(
      btrim(coalesce(p_payload ->> 'resulting_v1_id', '')),
      ''
    )::uuid;
  exception
    when invalid_text_representation then
      raise exception 'V1_RECONCILIATION_RESULTING_V1_ID_INVALID'
        using errcode = '22023';
  end;

  if v_issue_id is null
    or v_resolution_status not in ('resolved', 'rejected')
    or v_resolution_reason is null then
    raise exception 'V1_RECONCILIATION_RESOLUTION_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if char_length(v_resolution_reason) > 2000 then
    raise exception 'V1_RECONCILIATION_RESOLUTION_REASON_TOO_LONG'
      using errcode = '22023';
  end if;
  if v_resolution_status = 'resolved'
    and (
      v_resulting_v1_entity_type is null
      or v_resulting_v1_id is null
    ) then
    raise exception 'V1_RECONCILIATION_RESULT_REQUIRED_FOR_RESOLUTION'
      using errcode = '22023';
  end if;
  if v_resolution_status = 'rejected'
    and (
      v_resulting_v1_entity_type is not null
      or v_resulting_v1_id is not null
    ) then
    raise exception 'V1_RECONCILIATION_RESULT_NOT_ALLOWED_FOR_REJECTION'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  select * into v_issue
  from public.v1_reconciliation_issues issue
  where issue.id = v_issue_id
  for update;
  if not found then
    raise exception 'V1_RECONCILIATION_ISSUE_NOT_FOUND'
      using errcode = '22023';
  end if;

  -- Re-authorize and lock the issue before looking up a completed retry.  A
  -- revoked Admin must not retrieve a previously successful response.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_resolve_reconciliation_issue',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_issue.resolution_status <> 'pending' then
    raise exception 'V1_RECONCILIATION_ISSUE_NOT_PENDING'
      using errcode = '55000';
  end if;

  -- Batch 2 reconciliation results are identity/project mappings.  Do not let
  -- an arbitrary free-form type create a dangling "resolved" record.
  if v_resolution_status = 'resolved' then
    if v_resulting_v1_entity_type = 'profile' then
      if not exists (
        select 1
        from public.v1_profiles profile
        where profile.auth_user_id = v_resulting_v1_id
      ) then
        raise exception 'V1_RECONCILIATION_RESULTING_PROFILE_NOT_FOUND'
          using errcode = '22023';
      end if;
    elsif v_resulting_v1_entity_type = 'project' then
      if not exists (
        select 1
        from public.v1_projects project
        where project.id = v_resulting_v1_id
      ) then
        raise exception 'V1_RECONCILIATION_RESULTING_PROJECT_NOT_FOUND'
          using errcode = '22023';
      end if;
    else
      raise exception 'V1_RECONCILIATION_RESULTING_ENTITY_TYPE_INVALID'
        using errcode = '22023';
    end if;
  end if;

  v_before := jsonb_build_object(
    'resolution_status', v_issue.resolution_status
  );
  update public.v1_reconciliation_issues issue
     set resolution_status = v_resolution_status,
         resolution_reason = v_resolution_reason,
         resolved_by_auth_user_id = v_actor,
         resolved_at = clock_timestamp(),
         resulting_v1_entity_type = case
           when v_resolution_status = 'resolved'
             then v_resulting_v1_entity_type
           else null
         end,
         resulting_v1_id = case
           when v_resolution_status = 'resolved' then v_resulting_v1_id
           else null
         end
   where issue.id = v_issue_id
   returning * into v_issue;

  perform public.v1_write_audit_event(
    case v_resolution_status
      when 'resolved' then 'reconciliation_issue_resolved'
      else 'reconciliation_issue_rejected'
    end,
    'reconciliation_issue',
    v_issue.id,
    null,
    v_before,
    jsonb_build_object(
      'resolution_status', v_issue.resolution_status,
      'resulting_v1_entity_type', v_issue.resulting_v1_entity_type,
      'resulting_v1_id', v_issue.resulting_v1_id,
      'resolved_by_auth_user_id', v_issue.resolved_by_auth_user_id,
      'resolved_at', v_issue.resolved_at
    ),
    v_issue.resolution_reason,
    p_idempotency_key
  );

  v_response := jsonb_build_object(
    'issue_id', v_issue.id,
    'source_system', v_issue.source_system,
    'source_entity', v_issue.source_entity,
    'source_id', v_issue.source_id,
    'issue_code', v_issue.issue_code,
    'resolution_status', v_issue.resolution_status,
    'resulting_v1_entity_type', v_issue.resulting_v1_entity_type,
    'resulting_v1_id', v_issue.resulting_v1_id,
    'resolved_by_auth_user_id', v_issue.resolved_by_auth_user_id,
    'resolved_at', v_issue.resolved_at
  );
  perform public.v1_complete_idempotency(
    'v1_resolve_reconciliation_issue',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

-- A safe Admin-only report supplies the reconciliation queue/counts without
-- exposing raw legacy payloads, payload hashes or proposed mapping details.
create or replace function public.v1_get_reconciliation_report()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_response jsonb;
begin
  if v_actor is null or v_role <> 'admin' then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total', count(*),
    'pending', count(*) filter (where issue.resolution_status = 'pending'),
    'resolved', count(*) filter (where issue.resolution_status = 'resolved'),
    'rejected', count(*) filter (where issue.resolution_status = 'rejected'),
    'by_issue_code', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'issue_code', counts.issue_code,
            'total', counts.total,
            'pending', counts.pending,
            'resolved', counts.resolved,
            'rejected', counts.rejected
          )
          order by counts.issue_code
        )
        from (
          select
            counted.issue_code,
            count(*) as total,
            count(*) filter (
              where counted.resolution_status = 'pending'
            ) as pending,
            count(*) filter (
              where counted.resolution_status = 'resolved'
            ) as resolved,
            count(*) filter (
              where counted.resolution_status = 'rejected'
            ) as rejected
          from public.v1_reconciliation_issues counted
          group by counted.issue_code
        ) counts
      ),
      '[]'::jsonb
    ),
    'pending_issues', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', issue.id,
          'source_system', issue.source_system,
          'source_entity', issue.source_entity,
          'source_id', issue.source_id,
          'issue_code', issue.issue_code,
          'field_path', issue.field_path,
          'created_at', issue.created_at
        )
        order by issue.created_at, issue.id
      ) filter (where issue.resolution_status = 'pending'),
      '[]'::jsonb
    )
  ) into v_response
  from public.v1_reconciliation_issues issue;

  return v_response;
end;
$$;

create or replace function public.v1_prevent_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'V1_AUDIT_EVENTS_ARE_APPEND_ONLY'
    using errcode = '55000';
end;
$$;

drop trigger if exists v1_audit_events_append_only on public.v1_audit_events;
create trigger v1_audit_events_append_only
before update or delete on public.v1_audit_events
for each row execute function public.v1_prevent_audit_mutation();

create or replace function public.v1_prevent_common_scope_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and old.scope_kind = 'common' then
    raise exception 'V1_COMMON_SCOPE_IS_IMMUTABLE'
      using errcode = '55000';
  end if;
  if tg_op = 'UPDATE' and (
    old.scope_kind = 'common'
    or new.scope_kind = 'common'
  ) then
    raise exception 'V1_COMMON_SCOPE_IS_IMMUTABLE'
      using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_common_scope_immutable on public.v1_project_scopes;
create trigger v1_common_scope_immutable
before update or delete on public.v1_project_scopes
for each row execute function public.v1_prevent_common_scope_mutation();

create or replace function public.v1_project_projection(p_project_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', project.id,
    'reference', project.project_ref,
    'name', project.name,
    'job_contract_reference', project.job_contract_reference,
    'project_site', project.project_site,
    'start_date', project.start_date,
    'target_completion_date', project.target_completion_date,
    'notes', project.notes,
    'state', project.state,
    'current_action_owner_role', project.current_action_owner_role,
    'record_version', project.record_version,
    'created_by_auth_user_id', project.created_by_auth_user_id,
    'created_by_role', project.created_by_role,
    'created_at', project.created_at,
    'updated_at', project.updated_at
  )
  from public.v1_projects project
  where project.id = p_project_id;
$$;

create or replace function public.v1_project_parties_projection(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', party.id,
        'party_kind', party.party_kind,
        'party_order', party.party_order,
        'name', party.party_name,
        'contact_name', party.contact_name,
        'contact_phone', party.contact_phone,
        'contact_email', party.contact_email,
        'address', party.address
      )
      order by party.party_kind, party.party_order, party.id
    ),
    '[]'::jsonb
  )
  from public.v1_project_parties party
  where party.project_id = p_project_id;
$$;

create or replace function public.v1_project_scopes_projection(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', scope.id,
        'project_id', scope.project_id,
        'scope_kind', scope.scope_kind,
        'code', scope.scope_code,
        'name', scope.name,
        'floors_levels', scope.floors_levels,
        'flags', scope.scope_flags,
        'delivery_address', scope.delivery_address,
        'is_active', scope.is_active,
        'is_immutable', scope.is_immutable,
        'record_version', scope.record_version
      )
      order by case scope.scope_kind when 'common' then 0 else 1 end,
        lower(scope.scope_code), scope.id
    ),
    '[]'::jsonb
  )
  from public.v1_project_scopes scope
  where scope.project_id = p_project_id;
$$;

create or replace function public.v1_project_members_projection(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', member.id,
        'project_id', member.project_id,
        'auth_user_id', member.member_auth_user_id,
        'display_name', public.v1_safe_profile_display_name(
          profile.display_name,
          profile.auth_user_id
        ),
        'project_role', member.project_role,
        'effective_from', member.effective_from,
        'effective_to', member.effective_to,
        'reason', member.reason,
        'assigned_by_auth_user_id', member.assigned_by_auth_user_id,
        'assigned_by_role', member.assigned_by_role,
        'created_at', member.created_at,
        'revoked_by_auth_user_id', member.revoked_by_auth_user_id,
        'revoked_by_role', member.revoked_by_role,
        'revoked_reason', member.revoked_reason
      )
      order by member.effective_to nulls first, lower(
        public.v1_safe_profile_display_name(
          profile.display_name,
          profile.auth_user_id
        )
      ),
        member.effective_from, member.id
    ),
    '[]'::jsonb
  )
  from public.v1_project_members member
  join public.v1_profiles profile
    on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = p_project_id;
$$;

create or replace function public.v1_project_attachment_intakes_projection(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', intake.id,
        'file_name', intake.file_name,
        'mime_type', intake.mime_type,
        'size_bytes', intake.size_bytes,
        'intake_status', intake.intake_status,
        'created_at', intake.created_at
      )
      order by intake.created_at, intake.id
    ),
    '[]'::jsonb
  )
  from public.v1_project_attachment_intakes intake
  where intake.project_id = p_project_id;
$$;

create or replace function public.v1_member_projection(p_member_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', member.id,
    'project_id', member.project_id,
    'auth_user_id', member.member_auth_user_id,
    'display_name', public.v1_safe_profile_display_name(
      profile.display_name,
      profile.auth_user_id
    ),
    'project_role', member.project_role,
    'effective_from', member.effective_from,
    'effective_to', member.effective_to,
    'reason', member.reason,
    'assigned_by_auth_user_id', member.assigned_by_auth_user_id,
    'assigned_by_role', member.assigned_by_role,
    'created_at', member.created_at,
    'revoked_by_auth_user_id', member.revoked_by_auth_user_id,
    'revoked_by_role', member.revoked_by_role,
    'revoked_reason', member.revoked_reason
  )
  from public.v1_project_members member
  join public.v1_profiles profile
    on profile.auth_user_id = member.member_auth_user_id
  where member.id = p_member_id;
$$;

create or replace function public.v1_validate_party_object(
  p_party jsonb,
  p_context text
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform public.v1_assert_object_keys(
    p_party,
    array['name', 'contact_name', 'contact_phone', 'contact_email', 'address'],
    p_context
  );

  if nullif(btrim(coalesce(p_party ->> 'name', '')), '') is null then
    raise exception 'V1_%_NAME_REQUIRED', upper(p_context)
      using errcode = '22023';
  end if;
end;
$$;

create or replace function public.v1_insert_project_party(
  p_project_id uuid,
  p_party_kind text,
  p_party_order integer,
  p_party jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_validate_party_object(
    p_party,
    'project_party_' || p_party_kind
  );

  insert into public.v1_project_parties (
    project_id,
    party_kind,
    party_order,
    party_name,
    contact_name,
    contact_phone,
    contact_email,
    address
  )
  values (
    p_project_id,
    p_party_kind,
    p_party_order,
    btrim(p_party ->> 'name'),
    nullif(btrim(coalesce(p_party ->> 'contact_name', '')), ''),
    nullif(btrim(coalesce(p_party ->> 'contact_phone', '')), ''),
    nullif(btrim(coalesce(p_party ->> 'contact_email', '')), ''),
    nullif(btrim(coalesce(p_party ->> 'address', '')), '')
  );
end;
$$;

create or replace function public.v1_target_is_eligible_team_member(
  p_auth_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = p_auth_user_id
      and profile.is_active
      and profile.canonical_role_snapshot in ('project_engineer', 'site_engineer')
  );
$$;

create or replace function public.v1_insert_active_project_member(
  p_project_id uuid,
  p_member_auth_user_id uuid,
  p_project_role text,
  p_reason text,
  p_assigned_by_auth_user_id uuid,
  p_assigned_by_role text,
  p_effective_from timestamptz default clock_timestamp()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.v1_project_members%rowtype;
  v_member_id uuid;
begin
  if p_project_role not in ('project_engineer', 'site_engineer') then
    raise exception 'V1_INVALID_PROJECT_MEMBER_ROLE'
      using errcode = '22023';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'V1_PROJECT_MEMBER_REASON_REQUIRED'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(p_member_auth_user_id);

  if not public.v1_target_is_eligible_team_member(p_member_auth_user_id) then
    raise exception 'V1_PROJECT_MEMBER_MUST_HAVE_PROJECT_OR_SITE_ENGINEER_CLAIM'
      using errcode = '42501';
  end if;

  select * into v_existing
  from public.v1_project_members member
  where member.project_id = p_project_id
    and member.member_auth_user_id = p_member_auth_user_id
    and member.effective_to is null
  for update;

  if found then
    if v_existing.project_role = p_project_role then
      return v_existing.id;
    end if;

    update public.v1_project_members
       set effective_to = p_effective_from,
           revoked_by_auth_user_id = p_assigned_by_auth_user_id,
           revoked_by_role = p_assigned_by_role,
           revoked_reason = 'Replaced by a new project role assignment'
     where id = v_existing.id;
  end if;

  insert into public.v1_project_members (
    project_id,
    member_auth_user_id,
    project_role,
    effective_from,
    reason,
    assigned_by_auth_user_id,
    assigned_by_role
  )
  values (
    p_project_id,
    p_member_auth_user_id,
    p_project_role,
    p_effective_from,
    btrim(p_reason),
    p_assigned_by_auth_user_id,
    p_assigned_by_role
  )
  returning id into v_member_id;

  return v_member_id;
end;
$$;

-- `v1_create_project` is the only Batch 2 project writer.  It keeps all
-- creation-stage facts in one transaction and seeds the frozen 29 groups.
create or replace function public.v1_create_project(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project_id uuid;
  v_common_scope_id uuid;
  v_project public.v1_projects%rowtype;
  v_project_ref text;
  v_name text;
  v_parties jsonb;
  v_initial_members jsonb;
  v_buildings jsonb;
  v_attachments jsonb;
  v_member jsonb;
  v_party jsonb;
  v_building jsonb;
  v_attachment jsonb;
  v_member_role text;
  v_member_auth_user_id uuid;
  v_member_base_role text;
  v_creator_project_role text;
  v_site_initial_pe_count integer := 0;
  v_position integer := 0;
  v_scope_code text;
  v_floors_levels jsonb;
  v_scope_flags jsonb;
  v_response jsonb;
  v_default_group_count integer;
begin
  if v_actor is null or v_role not in (
    'project_engineer', 'site_engineer', 'admin'
  ) then
    raise exception 'V1_ROLE_NOT_ALLOWED_TO_CREATE_PROJECT'
      using errcode = '42501';
  end if;

  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_ref', 'name', 'job_contract_reference', 'project_site',
      'start_date', 'target_completion_date', 'notes', 'parties',
      'initial_members', 'buildings', 'attachments'
    ],
    'project_payload'
  );

  v_project_ref := upper(nullif(btrim(coalesce(p_payload ->> 'project_ref', '')), ''));
  v_name := nullif(btrim(coalesce(p_payload ->> 'name', '')), '');
  if v_project_ref is null then
    raise exception 'V1_PROJECT_REF_REQUIRED' using errcode = '22023';
  end if;
  if v_name is null then
    raise exception 'V1_PROJECT_NAME_REQUIRED' using errcode = '22023';
  end if;

  v_parties := coalesce(p_payload -> 'parties', '{}'::jsonb);
  v_initial_members := coalesce(p_payload -> 'initial_members', '[]'::jsonb);
  v_buildings := coalesce(p_payload -> 'buildings', '[]'::jsonb);
  v_attachments := coalesce(p_payload -> 'attachments', '[]'::jsonb);

  perform public.v1_assert_object_keys(
    v_parties,
    array[
      'client', 'consultant', 'main_contractor', 'subcontractors',
      'other_contractors'
    ],
    'project_parties'
  );
  if jsonb_typeof(v_initial_members) <> 'array' then
    raise exception 'V1_INITIAL_MEMBERS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;
  if jsonb_typeof(v_buildings) <> 'array' then
    raise exception 'V1_BUILDINGS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;
  if jsonb_array_length(v_buildings) = 0 then
    raise exception 'V1_AT_LEAST_ONE_PHYSICAL_BUILDING_REQUIRED'
      using errcode = '22023';
  end if;
  if jsonb_typeof(v_attachments) <> 'array' then
    raise exception 'V1_ATTACHMENTS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;
  if (v_parties ? 'subcontractors')
    and jsonb_typeof(v_parties -> 'subcontractors') <> 'array' then
    raise exception 'V1_SUBCONTRACTORS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;
  if (v_parties ? 'other_contractors')
    and jsonb_typeof(v_parties -> 'other_contractors') <> 'array' then
    raise exception 'V1_OTHER_CONTRACTORS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;

  -- Ensure the actor profile exists before the idempotency FK is claimed.  A
  -- canonical signed-in user must not fail merely because this is their first
  -- V1 command after Auth provisioning.
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_create_project',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  v_creator_project_role := case
    when v_role = 'project_engineer' then 'project_engineer'
    when v_role = 'site_engineer' then 'site_engineer'
    else null
  end;

  insert into public.v1_projects (
    project_ref,
    name,
    job_contract_reference,
    project_site,
    start_date,
    target_completion_date,
    notes,
    created_by_auth_user_id,
    created_by_role,
    created_at,
    updated_at
  )
  values (
    v_project_ref,
    v_name,
    nullif(btrim(coalesce(p_payload ->> 'job_contract_reference', '')), ''),
    nullif(btrim(coalesce(p_payload ->> 'project_site', '')), ''),
    nullif(btrim(coalesce(p_payload ->> 'start_date', '')), '')::date,
    nullif(btrim(coalesce(p_payload ->> 'target_completion_date', '')), '')::date,
    nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
    v_actor,
    v_role,
    v_now,
    v_now
  )
  returning * into v_project;
  v_project_id := v_project.id;

  insert into public.v1_project_scopes (
    project_id,
    scope_kind,
    scope_code,
    name,
    floors_levels,
    scope_flags,
    is_active,
    is_immutable,
    created_at,
    updated_at
  )
  values (
    v_project_id,
    'common',
    'common',
    'Common / All Buildings',
    '[]'::jsonb,
    '{}'::jsonb,
    true,
    true,
    v_now,
    v_now
  )
  returning id into v_common_scope_id;

  if v_parties ? 'client' and v_parties -> 'client' <> 'null'::jsonb then
    perform public.v1_insert_project_party(
      v_project_id, 'client', 0, v_parties -> 'client'
    );
  end if;
  if v_parties ? 'consultant' and v_parties -> 'consultant' <> 'null'::jsonb then
    perform public.v1_insert_project_party(
      v_project_id, 'consultant', 0, v_parties -> 'consultant'
    );
  end if;
  if v_parties ? 'main_contractor'
    and v_parties -> 'main_contractor' <> 'null'::jsonb then
    perform public.v1_insert_project_party(
      v_project_id, 'main_contractor', 0, v_parties -> 'main_contractor'
    );
  end if;

  v_position := 0;
  for v_party in
    select value from jsonb_array_elements(
      coalesce(v_parties -> 'subcontractors', '[]'::jsonb)
    )
  loop
    perform public.v1_insert_project_party(
      v_project_id, 'subcontractor', v_position, v_party
    );
    v_position := v_position + 1;
  end loop;

  v_position := 0;
  for v_party in
    select value from jsonb_array_elements(
      coalesce(v_parties -> 'other_contractors', '[]'::jsonb)
    )
  loop
    perform public.v1_insert_project_party(
      v_project_id, 'other_contractor', v_position, v_party
    );
    v_position := v_position + 1;
  end loop;

  v_position := 0;
  for v_building in select value from jsonb_array_elements(v_buildings)
  loop
    perform public.v1_assert_object_keys(
      v_building,
      array['code', 'name', 'floors_levels', 'flags', 'delivery_address'],
      'building'
    );
    if nullif(btrim(coalesce(v_building ->> 'name', '')), '') is null then
      raise exception 'V1_BUILDING_NAME_REQUIRED' using errcode = '22023';
    end if;
    v_scope_code := lower(coalesce(
      nullif(btrim(coalesce(v_building ->> 'code', '')), ''),
      'building-' || (v_position + 1)::text
    ));
    if v_scope_code !~ '^[a-z0-9][a-z0-9_-]{0,63}$' then
      raise exception 'V1_BUILDING_CODE_INVALID' using errcode = '22023';
    end if;
    v_floors_levels := coalesce(v_building -> 'floors_levels', '[]'::jsonb);
    v_scope_flags := coalesce(v_building -> 'flags', '{}'::jsonb);
    if jsonb_typeof(v_floors_levels) <> 'array' then
      raise exception 'V1_BUILDING_FLOORS_LEVELS_MUST_BE_AN_ARRAY'
        using errcode = '22023';
    end if;
    if jsonb_typeof(v_scope_flags) <> 'object' then
      raise exception 'V1_BUILDING_FLAGS_MUST_BE_AN_OBJECT'
        using errcode = '22023';
    end if;

    insert into public.v1_project_scopes (
      project_id,
      scope_kind,
      scope_code,
      name,
      floors_levels,
      scope_flags,
      delivery_address,
      created_at,
      updated_at
    )
    values (
      v_project_id,
      'building',
      v_scope_code,
      btrim(v_building ->> 'name'),
      v_floors_levels,
      v_scope_flags,
      nullif(btrim(coalesce(v_building ->> 'delivery_address', '')), ''),
      v_now,
      v_now
    );
    v_position := v_position + 1;
  end loop;

  if v_creator_project_role is not null then
    perform public.v1_insert_active_project_member(
      v_project_id,
      v_actor,
      v_creator_project_role,
      'Project creator',
      v_actor,
      v_role,
      v_now
    );
  end if;

  for v_member in select value from jsonb_array_elements(v_initial_members)
  loop
    perform public.v1_assert_object_keys(
      v_member,
      array['auth_user_id', 'project_role', 'reason'],
      'initial_member'
    );
    v_member_auth_user_id := nullif(
      btrim(coalesce(v_member ->> 'auth_user_id', '')),
      ''
    )::uuid;
    v_member_role := nullif(btrim(coalesce(v_member ->> 'project_role', '')), '');
    if v_member_auth_user_id is null or v_member_role is null then
      raise exception 'V1_INITIAL_MEMBER_ID_AND_ROLE_REQUIRED'
        using errcode = '22023';
    end if;

    perform public.v1_sync_profile_from_auth(v_member_auth_user_id);
    select profile.canonical_role_snapshot into v_member_base_role
    from public.v1_profiles profile
    where profile.auth_user_id = v_member_auth_user_id
      and profile.is_active;

    if v_member_base_role not in ('project_engineer', 'site_engineer') then
      raise exception 'V1_INITIAL_MEMBER_MUST_HAVE_PROJECT_OR_SITE_ENGINEER_CLAIM'
        using errcode = '42501';
    end if;
    if v_member_role not in ('project_engineer', 'site_engineer') then
      raise exception 'V1_INVALID_PROJECT_MEMBER_ROLE'
        using errcode = '22023';
    end if;

    -- The creator's implied role may be shown in the UI payload; accepting the
    -- exact duplicate preserves the five-stage review without duplicating history.
    if v_creator_project_role is not null
      and v_member_auth_user_id = v_actor
      and v_member_role = v_creator_project_role then
      continue;
    end if;

    if v_role = 'site_engineer'
      and not (
        v_member_role = 'project_engineer'
        and v_member_base_role = 'project_engineer'
        and v_member_auth_user_id <> v_actor
      ) then
      raise exception 'V1_SITE_CREATOR_MAY_ASSIGN_ONLY_ONE_INITIAL_PROJECT_ENGINEER'
        using errcode = '42501';
    end if;

    if v_role = 'site_engineer' then
      v_site_initial_pe_count := v_site_initial_pe_count + 1;
      if v_site_initial_pe_count > 1 then
        raise exception 'V1_SITE_CREATOR_MAY_ASSIGN_ONLY_ONE_INITIAL_PROJECT_ENGINEER'
          using errcode = '42501';
      end if;
    end if;

    perform public.v1_insert_active_project_member(
      v_project_id,
      v_member_auth_user_id,
      v_member_role,
      coalesce(
        nullif(btrim(coalesce(v_member ->> 'reason', '')), ''),
        'Initial project team assignment'
      ),
      v_actor,
      v_role,
      v_now
    );
  end loop;

  insert into public.v1_boq_groups (
    project_id,
    template_id,
    name,
    display_order,
    is_custom,
    created_by_auth_user_id,
    created_at,
    updated_at
  )
  select
    v_project_id,
    template.id,
    template.display_name,
    template.display_order,
    false,
    v_actor,
    v_now,
    v_now
  from public.v1_boq_group_templates template
  where template.is_frozen
    and template.is_active
  order by template.display_order;

  select count(*) into v_default_group_count
  from public.v1_boq_groups group_record
  where group_record.project_id = v_project_id
    and not group_record.is_custom;
  if v_default_group_count <> 29 then
    raise exception 'V1_FROZEN_BOQ_TEMPLATE_MUST_CONTAIN_29_GROUPS'
      using errcode = '55000';
  end if;

  v_position := 0;
  for v_attachment in select value from jsonb_array_elements(v_attachments)
  loop
    perform public.v1_assert_object_keys(
      v_attachment,
      array[
        'file_name', 'mime_type', 'size_bytes', 'storage_object_path', 'sha256'
      ],
      'attachment'
    );
    if nullif(btrim(coalesce(v_attachment ->> 'file_name', '')), '') is null then
      raise exception 'V1_ATTACHMENT_FILE_NAME_REQUIRED' using errcode = '22023';
    end if;
    if (v_attachment ? 'size_bytes')
      and jsonb_typeof(v_attachment -> 'size_bytes') <> 'number' then
      raise exception 'V1_ATTACHMENT_SIZE_BYTES_MUST_BE_A_NUMBER'
        using errcode = '22023';
    end if;
    -- B2 retains only intake metadata.  A guessed object path or client hash
    -- must never masquerade as a Storage-authorized document link before the
    -- classified Storage/link command arrives in Batch 9.
    if nullif(btrim(coalesce(v_attachment ->> 'storage_object_path', '')), '')
      is not null
      or nullif(btrim(coalesce(v_attachment ->> 'sha256', '')), '') is not null
    then
      raise exception 'V1_ATTACHMENT_STORAGE_LINKS_ARE_DEFERRED_TO_BATCH_9'
        using errcode = '22023';
    end if;

    insert into public.v1_project_attachment_intakes (
      project_id,
      file_name,
      mime_type,
      size_bytes,
      created_by_auth_user_id,
      created_at
    )
    values (
      v_project_id,
      btrim(v_attachment ->> 'file_name'),
      nullif(btrim(coalesce(v_attachment ->> 'mime_type', '')), ''),
      nullif(btrim(coalesce(v_attachment ->> 'size_bytes', '')), '')::bigint,
      v_actor,
      v_now
    );
    v_position := v_position + 1;
  end loop;

  v_response := jsonb_build_object(
    'project_id', v_project_id,
    'project_ref', v_project.project_ref,
    'state', v_project.state,
    'record_version', v_project.record_version,
    'common_scope_id', v_common_scope_id,
    'created_at', v_project.created_at,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id),
    'parties', public.v1_project_parties_projection(v_project_id),
    'scopes', public.v1_project_scopes_projection(v_project_id),
    'members', public.v1_project_members_projection(v_project_id),
    'attachments', public.v1_project_attachment_intakes_projection(v_project_id)
  );

  perform public.v1_write_audit_event(
    'project_created',
    'project',
    v_project_id,
    v_project_id,
    null,
    jsonb_build_object(
      'state', v_project.state,
      'record_version', v_project.record_version,
      'default_boq_group_count', v_default_group_count
    ),
    null,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_project', p_idempotency_key, v_response
  );

  return v_response;
end;
$$;

-- Team changes are historical: a replacement/revocation closes the old row and
-- writes a new record or audited close instead of deleting attribution.
create or replace function public.v1_assign_project_member(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project public.v1_projects%rowtype;
  v_existing_member public.v1_project_members%rowtype;
  v_member_id uuid;
  v_project_id uuid;
  v_member_auth_user_id uuid;
  v_project_role text;
  v_expected_version integer;
  v_reason text;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'member_auth_user_id', 'project_role',
      'expected_version', 'reason'
    ],
    'assign_project_member_payload'
  );
  if v_actor is null or v_role = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_member_auth_user_id := nullif(
    btrim(coalesce(p_payload ->> 'member_auth_user_id', '')), ''
  )::uuid;
  v_project_role := nullif(btrim(coalesce(p_payload ->> 'project_role', '')), '');
  v_expected_version := nullif(
    btrim(coalesce(p_payload ->> 'expected_version', '')), ''
  )::integer;
  v_reason := coalesce(
    nullif(btrim(coalesce(p_payload ->> 'reason', '')), ''),
    'Project team assignment'
  );
  if v_project_id is null or v_member_auth_user_id is null
    or v_project_role is null or v_expected_version is null then
    raise exception 'V1_ASSIGN_PROJECT_MEMBER_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if v_project_role not in ('project_engineer', 'site_engineer') then
    raise exception 'V1_INVALID_PROJECT_MEMBER_ROLE'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  select * into v_project
  from public.v1_projects project
  where project.id = v_project_id
  for update;
  if not found then
    raise exception 'V1_PROJECT_NOT_FOUND' using errcode = '22023';
  end if;
  if not public.v1_can_manage_project(v_project_id) then
    raise exception 'V1_PROJECT_TEAM_MANAGEMENT_DENIED'
      using errcode = '42501';
  end if;

  -- Re-authorize before returning a completed retry. A previously authorized
  -- actor may have been revoked since the original command completed.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_assign_project_member',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_project.record_version <> v_expected_version then
    raise exception 'V1_PROJECT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if v_project.state not in ('draft', 'active', 'on_hold') then
    raise exception 'V1_PROJECT_TEAM_NOT_EDITABLE_IN_CURRENT_STATE'
      using errcode = '55000';
  end if;

  perform public.v1_sync_profile_from_auth(v_member_auth_user_id);
  if not public.v1_target_is_eligible_team_member(v_member_auth_user_id) then
    raise exception 'V1_PROJECT_MEMBER_MUST_HAVE_PROJECT_OR_SITE_ENGINEER_CLAIM'
      using errcode = '42501';
  end if;

  select * into v_existing_member
  from public.v1_project_members member
  where member.project_id = v_project_id
    and member.member_auth_user_id = v_member_auth_user_id
    and member.effective_to is null
  for update;

  if found and v_existing_member.project_role = v_project_role then
    v_member_id := v_existing_member.id;
  else
    if found
      and v_existing_member.project_role = 'project_engineer'
      and v_project_role <> 'project_engineer'
      and v_project.state = 'active'
      and not exists (
        select 1
        from public.v1_project_members member
        where member.project_id = v_project_id
          and member.project_role = 'project_engineer'
          and member.member_auth_user_id <> v_member_auth_user_id
          and member.effective_to is null
          and member.effective_from <= v_now
      )
    then
      raise exception 'V1_ACTIVE_PROJECT_REQUIRES_PROJECT_ENGINEER'
        using errcode = '55000';
    end if;

    v_before := jsonb_build_object(
      'record_version', v_project.record_version,
      'previous_member_id', case when found then v_existing_member.id else null end,
      'previous_project_role', case when found then v_existing_member.project_role else null end
    );
    v_member_id := public.v1_insert_active_project_member(
      v_project_id,
      v_member_auth_user_id,
      v_project_role,
      v_reason,
      v_actor,
      v_role,
      v_now
    );

    update public.v1_projects project
       set record_version = project.record_version + 1,
           updated_at = v_now
     where project.id = v_project_id
     returning * into v_project;

    perform public.v1_write_audit_event(
      'project_member_assigned',
      'project_member',
      v_member_id,
      v_project_id,
      v_before,
      jsonb_build_object(
        'record_version', v_project.record_version,
        'member_id', v_member_id,
        'member_auth_user_id', v_member_auth_user_id,
        'project_role', v_project_role
      ),
      v_reason,
      p_idempotency_key
    );
  end if;

  v_response := jsonb_build_object(
    'project_id', v_project_id,
    'member_auth_user_id', v_member_auth_user_id,
    'project_role', v_project_role,
    'membership_id', v_member_id,
    'effective_from', (
      select member.effective_from
      from public.v1_project_members member
      where member.id = v_member_id
    ),
    'project_record_version', v_project.record_version,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id),
    'member', public.v1_member_projection(v_member_id)
  );
  perform public.v1_complete_idempotency(
    'v1_assign_project_member', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_revoke_project_member(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project public.v1_projects%rowtype;
  v_member public.v1_project_members%rowtype;
  v_project_id uuid;
  v_member_auth_user_id uuid;
  v_project_role text;
  v_expected_version integer;
  v_reason text;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'member_auth_user_id', 'project_role',
      'expected_version', 'reason'
    ],
    'revoke_project_member_payload'
  );
  if v_actor is null or v_role = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_member_auth_user_id := nullif(
    btrim(coalesce(p_payload ->> 'member_auth_user_id', '')), ''
  )::uuid;
  v_project_role := nullif(btrim(coalesce(p_payload ->> 'project_role', '')), '');
  v_expected_version := nullif(
    btrim(coalesce(p_payload ->> 'expected_version', '')), ''
  )::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_project_id is null or v_member_auth_user_id is null
    or v_project_role is null or v_expected_version is null or v_reason is null then
    raise exception 'V1_REVOKE_PROJECT_MEMBER_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if v_project_role not in ('project_engineer', 'site_engineer') then
    raise exception 'V1_INVALID_PROJECT_MEMBER_ROLE'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  select * into v_project
  from public.v1_projects project
  where project.id = v_project_id
  for update;
  if not found then
    raise exception 'V1_PROJECT_NOT_FOUND' using errcode = '22023';
  end if;
  if not public.v1_can_manage_project(v_project_id) then
    raise exception 'V1_PROJECT_TEAM_MANAGEMENT_DENIED'
      using errcode = '42501';
  end if;

  -- Re-authorize before returning a completed retry. A previously authorized
  -- actor may have been revoked since the original command completed.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_revoke_project_member',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_project.record_version <> v_expected_version then
    raise exception 'V1_PROJECT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if v_project.state not in ('draft', 'active', 'on_hold') then
    raise exception 'V1_PROJECT_TEAM_NOT_EDITABLE_IN_CURRENT_STATE'
      using errcode = '55000';
  end if;

  select * into v_member
  from public.v1_project_members member
  where member.project_id = v_project_id
    and member.member_auth_user_id = v_member_auth_user_id
    and member.project_role = v_project_role
    and member.effective_to is null
  for update;
  if not found then
    raise exception 'V1_ACTIVE_PROJECT_MEMBER_NOT_FOUND'
      using errcode = '22023';
  end if;

  if v_project.state = 'active'
    and v_member.project_role = 'project_engineer'
    and not exists (
      select 1
      from public.v1_project_members member
      where member.project_id = v_project_id
        and member.project_role = 'project_engineer'
        and member.member_auth_user_id <> v_member_auth_user_id
        and member.effective_to is null
        and member.effective_from <= v_now
    )
  then
    raise exception 'V1_ACTIVE_PROJECT_REQUIRES_PROJECT_ENGINEER'
      using errcode = '55000';
  end if;

  v_before := jsonb_build_object(
    'record_version', v_project.record_version,
    'member_id', v_member.id,
    'project_role', v_member.project_role
  );
  update public.v1_project_members member
     set effective_to = v_now,
         revoked_by_auth_user_id = v_actor,
         revoked_by_role = v_role,
         revoked_reason = v_reason
   where member.id = v_member.id;

  update public.v1_projects project
     set record_version = project.record_version + 1,
         updated_at = v_now
   where project.id = v_project_id
   returning * into v_project;

  perform public.v1_write_audit_event(
    'project_member_revoked',
    'project_member',
    v_member.id,
    v_project_id,
    v_before,
    jsonb_build_object('record_version', v_project.record_version),
    v_reason,
    p_idempotency_key
  );

  v_response := jsonb_build_object(
    'project_id', v_project_id,
    'member_auth_user_id', v_member_auth_user_id,
    'project_role', v_project_role,
    'membership_id', v_member.id,
    'project_record_version', v_project.record_version,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id),
    'member', public.v1_member_projection(v_member.id)
  );
  perform public.v1_complete_idempotency(
    'v1_revoke_project_member', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_set_project_state(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project public.v1_projects%rowtype;
  v_project_id uuid;
  v_requested_state text;
  v_expected_version integer;
  v_reason text;
  v_before jsonb;
  v_response jsonb;
  v_owner text;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['project_id', 'state', 'expected_version', 'reason'],
    'set_project_state_payload'
  );
  if v_actor is null or v_role = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_requested_state := lower(nullif(
    btrim(coalesce(p_payload ->> 'state', '')), ''
  ));
  v_expected_version := nullif(
    btrim(coalesce(p_payload ->> 'expected_version', '')), ''
  )::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_project_id is null or v_requested_state is null
    or v_expected_version is null then
    raise exception 'V1_SET_PROJECT_STATE_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if v_requested_state not in (
    'draft', 'active', 'on_hold', 'completed', 'archived'
  ) then
    raise exception 'V1_INVALID_PROJECT_STATE' using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  select * into v_project
  from public.v1_projects project
  where project.id = v_project_id
  for update;
  if not found then
    raise exception 'V1_PROJECT_NOT_FOUND' using errcode = '22023';
  end if;
  if not public.v1_can_manage_project(v_project_id) then
    raise exception 'V1_PROJECT_STATE_CHANGE_DENIED'
      using errcode = '42501';
  end if;

  -- Re-authorize before returning a completed retry. A previously authorized
  -- actor may have been revoked since the original command completed.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_set_project_state',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_project.record_version <> v_expected_version then
    raise exception 'V1_PROJECT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  if (v_project.state = 'draft' and v_requested_state = 'active')
    or (v_project.state = 'active' and v_requested_state in ('on_hold', 'completed'))
    or (v_project.state = 'on_hold' and v_requested_state in ('active', 'completed'))
    or (v_project.state = 'completed' and v_requested_state = 'archived'
      and v_role = 'admin')
  then
    null;
  else
    raise exception 'V1_INVALID_PROJECT_STATE_TRANSITION'
      using errcode = '55000';
  end if;

  if (v_project.state = 'active' and v_requested_state = 'on_hold')
    or (v_project.state = 'on_hold' and v_requested_state = 'active')
    or v_requested_state = 'archived'
  then
    if v_reason is null then
      raise exception 'V1_PROJECT_STATE_REASON_REQUIRED'
        using errcode = '22023';
    end if;
  end if;

  if v_requested_state = 'active'
    and not public.v1_has_active_project_engineer(v_project_id) then
    raise exception 'V1_ACTIVE_PROJECT_REQUIRES_PROJECT_ENGINEER'
      using errcode = '55000';
  end if;

  v_before := jsonb_build_object(
    'state', v_project.state,
    'record_version', v_project.record_version,
    'current_action_owner_role', v_project.current_action_owner_role
  );
  v_owner := case v_requested_state
    when 'active' then 'project_engineer'
    when 'on_hold' then 'project_engineer'
    else 'none'
  end;
  update public.v1_projects project
     set state = v_requested_state,
         current_action_owner_role = v_owner,
         record_version = project.record_version + 1,
         updated_at = v_now
   where project.id = v_project_id
   returning * into v_project;

  perform public.v1_write_audit_event(
    'project_state_changed',
    'project',
    v_project_id,
    v_project_id,
    v_before,
    jsonb_build_object(
      'state', v_project.state,
      'record_version', v_project.record_version,
      'current_action_owner_role', v_project.current_action_owner_role
    ),
    v_reason,
    p_idempotency_key
  );

  v_response := jsonb_build_object(
    'project_id', v_project_id,
    'state', v_project.state,
    'record_version', v_project.record_version,
    'current_action_owner_role', v_project.current_action_owner_role,
    'updated_at', v_project.updated_at,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id)
  );
  perform public.v1_complete_idempotency(
    'v1_set_project_state', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Every V1 relation is exposed only through explicit grants plus RLS.  There
-- are intentionally no authenticated direct-write grants for the project,
-- team, scope or BOQ foundations; commands above own all mutations.
alter table public.v1_reconciliation_issues enable row level security;
alter table public.v1_profiles enable row level security;
alter table public.v1_role_capability_defaults enable row level security;
alter table public.v1_user_capabilities enable row level security;
alter table public.v1_projects enable row level security;
alter table public.v1_project_parties enable row level security;
alter table public.v1_project_scopes enable row level security;
alter table public.v1_project_attachment_intakes enable row level security;
alter table public.v1_boq_group_templates enable row level security;
alter table public.v1_boq_groups enable row level security;
alter table public.v1_project_members enable row level security;
alter table public.v1_audit_events enable row level security;
alter table public.v1_idempotency_keys enable row level security;

revoke all on table public.v1_reconciliation_issues from public, anon, authenticated;
revoke all on table public.v1_profiles from public, anon, authenticated;
revoke all on table public.v1_role_capability_defaults from public, anon, authenticated;
revoke all on table public.v1_user_capabilities from public, anon, authenticated;
revoke all on table public.v1_projects from public, anon, authenticated;
revoke all on table public.v1_project_parties from public, anon, authenticated;
revoke all on table public.v1_project_scopes from public, anon, authenticated;
revoke all on table public.v1_project_attachment_intakes from public, anon, authenticated;
revoke all on table public.v1_boq_group_templates from public, anon, authenticated;
revoke all on table public.v1_boq_groups from public, anon, authenticated;
revoke all on table public.v1_project_members from public, anon, authenticated;
revoke all on table public.v1_audit_events from public, anon, authenticated;
revoke all on table public.v1_idempotency_keys from public, anon, authenticated;

grant select on table public.v1_profiles to authenticated;
grant select on table public.v1_user_capabilities to authenticated;
grant select on table public.v1_projects to authenticated;
grant select on table public.v1_project_parties to authenticated;
grant select on table public.v1_project_scopes to authenticated;
grant select on table public.v1_project_attachment_intakes to authenticated;
grant select on table public.v1_boq_group_templates to authenticated;
grant select on table public.v1_boq_groups to authenticated;
grant select on table public.v1_project_members to authenticated;

grant all on table public.v1_reconciliation_issues to service_role;
grant all on table public.v1_profiles to service_role;
grant all on table public.v1_role_capability_defaults to service_role;
grant all on table public.v1_user_capabilities to service_role;
grant all on table public.v1_projects to service_role;
grant all on table public.v1_project_parties to service_role;
grant all on table public.v1_project_scopes to service_role;
grant all on table public.v1_project_attachment_intakes to service_role;
grant all on table public.v1_boq_group_templates to service_role;
grant all on table public.v1_boq_groups to service_role;
grant all on table public.v1_project_members to service_role;
grant all on table public.v1_audit_events to service_role;
grant all on table public.v1_idempotency_keys to service_role;

drop policy if exists v1_profiles_select_self_or_admin on public.v1_profiles;
create policy v1_profiles_select_self_or_admin
on public.v1_profiles
for select
to authenticated
using (
  -- A deactivated/demoted session may read only its own noncommercial signal
  -- row so Realtime can tell Flutter to purge.  Authority-sensitive reads of
  -- any other row still require the live active exact-Admin predicate.
  (select auth.uid()) = auth_user_id
  or (
    (select public.v1_rls_current_actor_is_active())
    and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') = 'admin'
  )
);

drop policy if exists v1_user_capabilities_select_self_or_admin
  on public.v1_user_capabilities;
create policy v1_user_capabilities_select_self_or_admin
on public.v1_user_capabilities
for select
to authenticated
using (
  -- Same self-only signal exception as v1_profiles; it does not restore a
  -- revoked capability because all effective checks remain server-side.
  (select auth.uid()) = auth_user_id
  or (
    (select public.v1_rls_current_actor_is_active())
    and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') = 'admin'
  )
);

-- The retained commercial table remains available while the flag-off shell is
-- still supported, but V1 access is always decided by the live protected
-- capability.  The compatibility path is deliberately narrower than a JWT
-- role check: only a live, active, never-materialised exact legacy `engineer`
-- may use legacy caps.  A stale legacy token after an explicit V1 mapping,
-- arbitrary noncanonical role, or banned legacy account fails closed.
drop policy if exists commercial_records_select on public.commercial_records;
create policy commercial_records_select
on public.commercial_records
for select
to authenticated
using (
  case
    when public.v1_rls_can_use_legacy_commercial_fallback()
      then public.app_has_cap('viewCommercials')
    else public.v1_rls_has_commercial_capability('view_commercials')
  end
);

drop policy if exists commercial_records_insert on public.commercial_records;
create policy commercial_records_insert
on public.commercial_records
for insert
to authenticated
with check (
  case
    when public.v1_rls_can_use_legacy_commercial_fallback()
      then public.app_has_cap('viewCommercials')
      and (public.app_role() = 'admin' or public.app_has_cap('goods'))
    else public.v1_rls_has_commercial_capability('manage_commercials')
  end
);

drop policy if exists commercial_records_update on public.commercial_records;
create policy commercial_records_update
on public.commercial_records
for update
to authenticated
using (
  case
    when public.v1_rls_can_use_legacy_commercial_fallback()
      then public.app_has_cap('viewCommercials')
      and (public.app_role() = 'admin' or public.app_has_cap('goods'))
    else public.v1_rls_has_commercial_capability('manage_commercials')
  end
)
with check (
  case
    when public.v1_rls_can_use_legacy_commercial_fallback()
      then public.app_has_cap('viewCommercials')
      and (public.app_role() = 'admin' or public.app_has_cap('goods'))
    else public.v1_rls_has_commercial_capability('manage_commercials')
  end
);

drop policy if exists v1_projects_select_authorized on public.v1_projects;
create policy v1_projects_select_authorized
on public.v1_projects
for select
to authenticated
using ((select public.v1_project_readable(id)));

drop policy if exists v1_project_parties_select_authorized
  on public.v1_project_parties;
create policy v1_project_parties_select_authorized
on public.v1_project_parties
for select
to authenticated
using ((select public.v1_project_readable(project_id)));

drop policy if exists v1_project_scopes_select_authorized
  on public.v1_project_scopes;
create policy v1_project_scopes_select_authorized
on public.v1_project_scopes
for select
to authenticated
using ((select public.v1_project_readable(project_id)));

drop policy if exists v1_project_attachment_intakes_select_authorized
  on public.v1_project_attachment_intakes;
create policy v1_project_attachment_intakes_select_authorized
on public.v1_project_attachment_intakes
for select
to authenticated
using ((select public.v1_project_readable(project_id)));

drop policy if exists v1_boq_group_templates_select_authenticated
  on public.v1_boq_group_templates;
create policy v1_boq_group_templates_select_authenticated
on public.v1_boq_group_templates
for select
to authenticated
using (
  (select public.v1_rls_current_actor_is_active())
  and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )
);

drop policy if exists v1_boq_groups_select_authorized on public.v1_boq_groups;
create policy v1_boq_groups_select_authorized
on public.v1_boq_groups
for select
to authenticated
using ((select public.v1_project_readable(project_id)));

drop policy if exists v1_project_members_select_authorized
  on public.v1_project_members;
create policy v1_project_members_select_authorized
on public.v1_project_members
for select
to authenticated
using ((select public.v1_project_readable(project_id)));

-- New PostgreSQL functions are executable by PUBLIC unless explicitly
-- revoked.  Keep all implementation helpers private.  The only callable V1
-- endpoints are the selected commands/directory and the non-mutating RLS
-- predicate required by project table policies.
revoke all on function public.v1_current_role() from public, anon, authenticated;
revoke all on function public.v1_current_actor_id() from public, anon, authenticated;
revoke all on function public.v1_is_valid_role(text) from public, anon, authenticated;
revoke all on function public.v1_assert_object_keys(jsonb, text[], text)
  from public, anon, authenticated;
revoke all on function public.v1_safe_profile_display_name(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_sync_profile_from_auth(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_sync_profile_from_auth_trigger()
  from public, anon, authenticated;
revoke all on function public.v1_auth_user_is_active(timestamptz)
  from public, anon, authenticated;
revoke all on function public.v1_safe_auth_audit_role(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_auth_users_admin_audit_trigger()
  from public, anon, authenticated;
revoke all on function public.v1_current_actor_is_active()
  from public, anon, authenticated;
revoke all on function public.v1_rls_current_actor_is_active()
  from public, anon, authenticated;
revoke all on function public.v1_has_capability(text)
  from public, anon, authenticated;
revoke all on function public.v1_commercial_capability_envelope(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_rls_has_commercial_capability(text)
  from public, anon, authenticated;
revoke all on function public.v1_rls_can_use_legacy_commercial_fallback()
  from public, anon, authenticated;
revoke all on function public.v1_has_active_project_membership(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.v1_can_manage_project(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_has_active_project_engineer(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_hash_json(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_idempotency_get_or_claim(text, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_complete_idempotency(text, uuid, jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_write_audit_event(
  text, text, uuid, uuid, jsonb, jsonb, text, uuid
) from public, anon, authenticated;
revoke all on function public.v1_resolve_reconciliation_issue(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_reconciliation_report()
  from public, anon, authenticated;
revoke all on function public.v1_get_current_commercial_capabilities()
  from public, anon, authenticated;
revoke all on function public.v1_get_user_commercial_capabilities(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_set_user_commercial_capability(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_prevent_audit_mutation()
  from public, anon, authenticated;
revoke all on function public.v1_prevent_common_scope_mutation()
  from public, anon, authenticated;
revoke all on function public.v1_project_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_project_parties_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_project_scopes_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_project_members_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_project_attachment_intakes_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_member_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_validate_party_object(jsonb, text)
  from public, anon, authenticated;
revoke all on function public.v1_insert_project_party(uuid, text, integer, jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_target_is_eligible_team_member(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_insert_active_project_member(
  uuid, uuid, text, text, uuid, text, timestamptz
) from public, anon, authenticated;

revoke all on function public.v1_project_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_active_profile_directory()
  from public, anon, authenticated;
revoke all on function public.v1_create_project(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_assign_project_member(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_revoke_project_member(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_set_project_state(jsonb, uuid)
  from public, anon, authenticated;

grant execute on function public.v1_project_readable(uuid) to authenticated;
grant execute on function public.v1_rls_current_actor_is_active()
  to authenticated;
grant execute on function public.v1_rls_has_commercial_capability(text)
  to authenticated;
grant execute on function public.v1_rls_can_use_legacy_commercial_fallback()
  to authenticated;
grant execute on function public.v1_list_active_profile_directory()
  to authenticated;
grant execute on function public.v1_create_project(jsonb, uuid) to authenticated;
grant execute on function public.v1_assign_project_member(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_revoke_project_member(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_set_project_state(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_resolve_reconciliation_issue(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_get_reconciliation_report()
  to authenticated;
grant execute on function public.v1_get_current_commercial_capabilities()
  to authenticated;
grant execute on function public.v1_get_user_commercial_capabilities(uuid)
  to authenticated;
grant execute on function public.v1_set_user_commercial_capability(jsonb, uuid)
  to authenticated;

-- Target sessions receive revocation/demotion refresh signals through their
-- existing self-only RLS policies.  Membership is idempotent so local resets
-- and repeated migration validation do not fail when the tables are already
-- part of Supabase Realtime.
do $$
begin
  if exists (
    select 1
    from pg_catalog.pg_publication publication
    where publication.pubname = 'supabase_realtime'
  ) then
    begin
      alter publication supabase_realtime add table public.v1_user_capabilities;
    exception
      when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table public.v1_profiles;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;
