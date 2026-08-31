-- Yorks Workforce T01: normalized worker master, teams, effective assignments,
-- responsibility scopes, shadow capabilities and protected Admin commands.
--
-- This migration is deliberately additive. The legacy employees/attendance
-- JSON collections remain untouched and are not copied, dual-written or
-- reinterpreted. Workforce capability rows remain planned, shadow and
-- nonassignable, so no existing Yorks route or workflow authorization changes.
-- Exact Admin is the temporary legacy authority for the T01 worker-master RPCs;
-- later phases may cut over one tested Workforce capability consumer at a time.
--
-- Data preservation: workers, teams and assignments are never hard-deleted.
-- Effective periods and audit facts preserve historical responsibility.
-- Rollback: keep YORKS_V1_WORKFORCE false, revoke the public Workforce RPC
-- execute grants and retain every normalized row and audit event.

begin;

create extension if not exists btree_gist with schema extensions;

create or replace function public.v1_workforce_is_capability_key(
  p_capability_key text
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select p_capability_key = any(array[
    'workforce.view',
    'workforce.attendance.maintain',
    'workforce.timesheets.maintain',
    'workforce.timesheets.review',
    'workforce.timesheets.correct_during_review',
    'workforce.timesheets.verify',
    'workforce.timesheets.final_approve',
    'workforce.periods.reopen',
    'workforce.reports.export',
    'workforce.workers.manage',
    'workforce.teams.manage',
    'workforce.configuration.manage'
  ]::text[]);
$$;

insert into public.v1_capability_catalog (
  capability_key, module_key, action_key, label, description, risk_level,
  allowed_scope_kinds, requires_project_access, dependencies, status,
  authorization_mode, is_assignable, display_order
)
values
  ('workforce.view', 'workforce', 'view',
   'View Workforce', 'Read a role-safe Workforce projection within effective responsibility scope.',
   'high', array['organization','project'], false, '{}', 'planned', 'shadow', false, 410),
  ('workforce.attendance.maintain', 'workforce', 'attendance_maintain',
   'Maintain attendance', 'Maintain daily attendance for workers inside effective responsibility scope.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 411),
  ('workforce.timesheets.maintain', 'workforce', 'timesheets_maintain',
   'Maintain timesheets', 'Maintain regular, overtime and allocation facts inside effective responsibility scope.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 412),
  ('workforce.timesheets.review', 'workforce', 'timesheets_review',
   'Review timesheets', 'Return or verify submitted Workforce periods in assigned review scope.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 413),
  ('workforce.timesheets.correct_during_review', 'workforce', 'timesheets_correct_during_review',
   'Correct during review', 'Apply a reasoned, before-and-after reviewer correction inside assigned review scope.',
   'critical', array['organization','project'], false, array['workforce.timesheets.review'], 'planned', 'shadow', false, 414),
  ('workforce.timesheets.verify', 'workforce', 'timesheets_verify',
   'Verify timesheets', 'Verify a reviewed Workforce period and forward it to final approval.',
   'critical', array['organization','project'], false, array['workforce.timesheets.review'], 'planned', 'shadow', false, 415),
  ('workforce.timesheets.final_approve', 'workforce', 'timesheets_final_approve',
   'Final approve timesheets', 'Approve a verified Workforce period before immutable locking.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 416),
  ('workforce.periods.reopen', 'workforce', 'periods_reopen',
   'Reopen Workforce periods', 'Run the controlled, reasoned reopen workflow for an approved period.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 417),
  ('workforce.reports.export', 'workforce', 'reports_export',
   'Export Workforce reports', 'Generate role-safe Workforce registers and controlled reports.',
   'high', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 418),
  ('workforce.workers.manage', 'workforce', 'workers_manage',
   'Manage workers', 'Create and maintain normalized worker master records without creating Auth users.',
   'critical', array['organization'], false, array['workforce.view'], 'planned', 'shadow', false, 419),
  ('workforce.teams.manage', 'workforce', 'teams_manage',
   'Manage Workforce teams', 'Create teams and maintain effective worker and supervisor assignments.',
   'critical', array['organization','project'], false, array['workforce.view'], 'planned', 'shadow', false, 420),
  ('workforce.configuration.manage', 'workforce', 'configuration_manage',
   'Manage Workforce configuration', 'Maintain protected Workforce calendars, shifts and approval chains in later phases.',
   'critical', array['organization'], false, array['workforce.view'], 'planned', 'shadow', false, 421)
on conflict (capability_key) do nothing;

do $workforce_catalog_contract$
begin
  if (
    select count(*)
    from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and catalog.module_key = 'workforce'
      and catalog.status = 'planned'
      and catalog.authorization_mode = 'shadow'
      and not catalog.is_assignable
  ) <> 12 then
    raise exception 'V1_WORKFORCE_CAPABILITY_CATALOG_CONFLICT'
      using errcode = '23514';
  end if;
end;
$workforce_catalog_contract$;

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

-- These are future Admin template ceilings only. Planned/shadow rows have no
-- operational consumer and cannot be assigned from User Management in T01.
update public.v1_permission_role_defaults role_default
set is_granted = (role_default.role_name = 'admin'),
    can_delegate = (role_default.role_name = 'admin'),
    updated_at = clock_timestamp()
where public.v1_workforce_is_capability_key(role_default.capability_key);

create table public.v1_workforce_trades (
  id uuid primary key default gen_random_uuid(),
  trade_code text not null check (
    btrim(trade_code) <> '' and char_length(trade_code) <= 40
  ),
  trade_name text not null check (
    btrim(trade_name) <> '' and char_length(trade_name) <= 120
  ),
  description text check (
    description is null or char_length(description) <= 1000
  ),
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp()
);

create unique index v1_workforce_trades_code_uidx
  on public.v1_workforce_trades (lower(btrim(trade_code)));
create unique index v1_workforce_trades_name_uidx
  on public.v1_workforce_trades (lower(btrim(trade_name)));

create table public.v1_workforce_internal_locations (
  id uuid primary key default gen_random_uuid(),
  location_code text not null check (
    btrim(location_code) <> '' and char_length(location_code) <= 40
  ),
  location_name text not null check (
    btrim(location_name) <> '' and char_length(location_name) <= 160
  ),
  department text check (
    department is null or char_length(department) <= 120
  ),
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp()
);

create unique index v1_workforce_internal_locations_code_uidx
  on public.v1_workforce_internal_locations (lower(btrim(location_code)));
create unique index v1_workforce_internal_locations_name_uidx
  on public.v1_workforce_internal_locations (lower(btrim(location_name)));

-- The composite key permits project/scope foreign keys to prove that a
-- Building/Common scope belongs to the selected project.
create unique index if not exists v1_project_scopes_project_id_id_uidx
  on public.v1_project_scopes (project_id, id);

create table public.v1_workforce_teams (
  id uuid primary key default gen_random_uuid(),
  team_code text not null check (
    btrim(team_code) <> '' and char_length(team_code) <= 40
  ),
  team_name text not null check (
    btrim(team_name) <> '' and char_length(team_name) <= 160
  ),
  department text check (
    department is null or char_length(department) <= 120
  ),
  default_supervisor_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  default_project_id uuid
    references public.v1_projects (id) on delete restrict,
  default_project_scope_id uuid,
  default_internal_location_id uuid
    references public.v1_workforce_internal_locations (id) on delete restrict,
  valid_from date not null,
  valid_to date,
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (valid_to is null or valid_to >= valid_from),
  check (
    default_project_scope_id is null or default_project_id is not null
  ),
  check (
    default_project_id is null or default_internal_location_id is null
  ),
  foreign key (default_project_id, default_project_scope_id)
    references public.v1_project_scopes (project_id, id) on delete restrict
);

create unique index v1_workforce_teams_code_uidx
  on public.v1_workforce_teams (lower(btrim(team_code)));
create unique index v1_workforce_teams_name_uidx
  on public.v1_workforce_teams (lower(btrim(team_name)));
create index v1_workforce_teams_project_idx
  on public.v1_workforce_teams (default_project_id, is_active);

create table public.v1_workforce_workers (
  id uuid primary key default gen_random_uuid(),
  worker_number text not null check (
    btrim(worker_number) <> '' and char_length(worker_number) <= 60
  ),
  full_name text not null check (
    btrim(full_name) <> '' and char_length(full_name) <= 180
  ),
  preferred_display_name text check (
    preferred_display_name is null
    or (btrim(preferred_display_name) <> ''
      and char_length(preferred_display_name) <= 120)
  ),
  designation text not null check (
    btrim(designation) <> '' and char_length(designation) <= 120
  ),
  trade_id uuid
    references public.v1_workforce_trades (id) on delete restrict,
  department text check (
    department is null or char_length(department) <= 120
  ),
  employer_company text not null check (
    btrim(employer_company) <> '' and char_length(employer_company) <= 180
  ),
  worker_type text not null check (worker_type in (
    'yorks_employee', 'temporary_worker', 'subcontractor_worker',
    'agency_worker'
  )),
  mobile_number text check (
    mobile_number is null or char_length(mobile_number) <= 40
  ),
  joining_date date not null,
  leaving_date date,
  current_status text not null default 'active' check (current_status in (
    'active', 'inactive', 'left_company', 'suspended'
  )),
  linked_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  notes text check (notes is null or char_length(notes) <= 4000),
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (leaving_date is null or leaving_date >= joining_date),
  check (current_status <> 'left_company' or leaving_date is not null)
);

create unique index v1_workforce_workers_number_uidx
  on public.v1_workforce_workers (lower(btrim(worker_number)));
create unique index v1_workforce_workers_linked_auth_uidx
  on public.v1_workforce_workers (linked_auth_user_id)
  where linked_auth_user_id is not null;
create index v1_workforce_workers_status_name_idx
  on public.v1_workforce_workers (current_status, lower(full_name), id);
create index v1_workforce_workers_trade_idx
  on public.v1_workforce_workers (trade_id, current_status);

create table public.v1_workforce_worker_assignments (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null
    references public.v1_workforce_workers (id) on delete restrict,
  assignment_kind text not null check (
    assignment_kind in ('primary', 'temporary')
  ),
  team_id uuid
    references public.v1_workforce_teams (id) on delete restrict,
  supervisor_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  project_id uuid
    references public.v1_projects (id) on delete restrict,
  project_scope_id uuid,
  internal_location_id uuid
    references public.v1_workforce_internal_locations (id) on delete restrict,
  valid_from date not null,
  valid_to date,
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  assigned_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  assigned_by_exact_role text not null check (assigned_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  record_version bigint not null default 1 check (record_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (valid_to is null or valid_to >= valid_from),
  check (assignment_kind <> 'temporary' or valid_to is not null),
  check (project_scope_id is null or project_id is not null),
  check (project_id is null or internal_location_id is null),
  check (
    team_id is not null
    or supervisor_auth_user_id is not null
    or project_id is not null
    or internal_location_id is not null
  ),
  foreign key (project_id, project_scope_id)
    references public.v1_project_scopes (project_id, id) on delete restrict,
  exclude using gist (
    worker_id with =,
    (daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    )) with &&
  ) where (assignment_kind = 'primary'),
  exclude using gist (
    worker_id with =,
    (daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    )) with &&
  ) where (assignment_kind = 'temporary')
);

create index v1_workforce_worker_assignments_worker_date_idx
  on public.v1_workforce_worker_assignments (
    worker_id, assignment_kind, valid_from, valid_to
  );
create index v1_workforce_worker_assignments_team_idx
  on public.v1_workforce_worker_assignments (team_id, valid_from, valid_to)
  where team_id is not null;
create index v1_workforce_worker_assignments_supervisor_idx
  on public.v1_workforce_worker_assignments (
    supervisor_auth_user_id, valid_from, valid_to
  ) where supervisor_auth_user_id is not null;
create index v1_workforce_worker_assignments_project_idx
  on public.v1_workforce_worker_assignments (
    project_id, project_scope_id, valid_from, valid_to
  ) where project_id is not null;

create table public.v1_workforce_responsibility_assignments (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  scope_kind text not null check (scope_kind in (
    'organization', 'worker', 'team', 'project', 'project_scope',
    'internal_location'
  )),
  worker_id uuid
    references public.v1_workforce_workers (id) on delete restrict,
  team_id uuid
    references public.v1_workforce_teams (id) on delete restrict,
  project_id uuid
    references public.v1_projects (id) on delete restrict,
  project_scope_id uuid,
  internal_location_id uuid
    references public.v1_workforce_internal_locations (id) on delete restrict,
  scope_reference text generated always as (
    case scope_kind
      when 'organization' then 'organization'
      when 'worker' then 'worker:' || worker_id::text
      when 'team' then 'team:' || team_id::text
      when 'project' then 'project:' || project_id::text
      when 'project_scope' then 'project_scope:' || project_scope_id::text
      when 'internal_location' then
        'internal_location:' || internal_location_id::text
    end
  ) stored,
  valid_from date not null,
  valid_to date,
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  assigned_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  assigned_by_exact_role text not null check (assigned_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  record_version bigint not null default 1 check (record_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (valid_to is null or valid_to >= valid_from),
  check (
    (scope_kind = 'organization'
      and worker_id is null and team_id is null and project_id is null
      and project_scope_id is null and internal_location_id is null)
    or (scope_kind = 'worker'
      and worker_id is not null and team_id is null and project_id is null
      and project_scope_id is null and internal_location_id is null)
    or (scope_kind = 'team'
      and worker_id is null and team_id is not null and project_id is null
      and project_scope_id is null and internal_location_id is null)
    or (scope_kind = 'project'
      and worker_id is null and team_id is null and project_id is not null
      and project_scope_id is null and internal_location_id is null)
    or (scope_kind = 'project_scope'
      and worker_id is null and team_id is null and project_id is not null
      and project_scope_id is not null and internal_location_id is null)
    or (scope_kind = 'internal_location'
      and worker_id is null and team_id is null and project_id is null
      and project_scope_id is null and internal_location_id is not null)
  ),
  foreign key (project_id, project_scope_id)
    references public.v1_project_scopes (project_id, id) on delete restrict,
  exclude using gist (
    auth_user_id with =,
    scope_reference with =,
    (daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    )) with &&
  )
);

create index v1_workforce_responsibility_actor_date_idx
  on public.v1_workforce_responsibility_assignments (
    auth_user_id, valid_from, valid_to
  );
create index v1_workforce_responsibility_worker_idx
  on public.v1_workforce_responsibility_assignments (worker_id)
  where worker_id is not null;
create index v1_workforce_responsibility_team_idx
  on public.v1_workforce_responsibility_assignments (team_id)
  where team_id is not null;
create index v1_workforce_responsibility_project_idx
  on public.v1_workforce_responsibility_assignments (
    project_id, project_scope_id
  ) where project_id is not null;

alter table public.v1_workforce_trades enable row level security;
alter table public.v1_workforce_internal_locations enable row level security;
alter table public.v1_workforce_teams enable row level security;
alter table public.v1_workforce_workers enable row level security;
alter table public.v1_workforce_worker_assignments enable row level security;
alter table public.v1_workforce_responsibility_assignments
  enable row level security;

revoke all on table public.v1_workforce_trades
  from public, anon, authenticated;
revoke all on table public.v1_workforce_internal_locations
  from public, anon, authenticated;
revoke all on table public.v1_workforce_teams
  from public, anon, authenticated;
revoke all on table public.v1_workforce_workers
  from public, anon, authenticated;
revoke all on table public.v1_workforce_worker_assignments
  from public, anon, authenticated;
revoke all on table public.v1_workforce_responsibility_assignments
  from public, anon, authenticated;

grant all on table public.v1_workforce_trades to service_role;
grant all on table public.v1_workforce_internal_locations to service_role;
grant all on table public.v1_workforce_teams to service_role;
grant all on table public.v1_workforce_workers to service_role;
grant all on table public.v1_workforce_worker_assignments to service_role;
grant all on table public.v1_workforce_responsibility_assignments
  to service_role;

create or replace function public.v1_workforce_block_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN'
    using errcode = '42501';
end;
$$;

create trigger v1_workforce_trades_no_delete
before delete on public.v1_workforce_trades
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_internal_locations_no_delete
before delete on public.v1_workforce_internal_locations
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_teams_no_delete
before delete on public.v1_workforce_teams
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_workers_no_delete
before delete on public.v1_workforce_workers
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_worker_assignments_no_delete
before delete on public.v1_workforce_worker_assignments
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_responsibility_assignments_no_delete
before delete on public.v1_workforce_responsibility_assignments
for each row execute function public.v1_workforce_block_delete();

create or replace function public.v1_workforce_validate_worker_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_worker public.v1_workforce_workers%rowtype;
  v_team public.v1_workforce_teams%rowtype;
begin
  select worker.* into strict v_worker
  from public.v1_workforce_workers worker
  where worker.id = new.worker_id;

  if new.valid_from < v_worker.joining_date
    or (v_worker.leaving_date is not null
      and (new.valid_to is null or new.valid_to > v_worker.leaving_date))
  then
    raise exception 'V1_WORKFORCE_ASSIGNMENT_OUTSIDE_EMPLOYMENT'
      using errcode = '23514';
  end if;

  if new.team_id is not null then
    select team.* into strict v_team
    from public.v1_workforce_teams team
    where team.id = new.team_id;
    if not v_team.is_active
      or new.valid_from < v_team.valid_from
      or (v_team.valid_to is not null
        and (new.valid_to is null or new.valid_to > v_team.valid_to))
    then
      raise exception 'V1_WORKFORCE_ASSIGNMENT_OUTSIDE_TEAM_WINDOW'
        using errcode = '23514';
    end if;
  end if;

  if new.supervisor_auth_user_id is not null
    and not exists (
      select 1 from public.v1_profiles profile
      where profile.auth_user_id = new.supervisor_auth_user_id
        and profile.is_active
    )
  then
    raise exception 'V1_WORKFORCE_ACTIVE_SUPERVISOR_REQUIRED'
      using errcode = '23514';
  end if;

  if new.project_id is not null
    and not exists (
      select 1 from public.v1_projects project
      where project.id = new.project_id
        and project.state = 'active'
    )
  then
    raise exception 'V1_WORKFORCE_ACTIVE_PROJECT_REQUIRED'
      using errcode = '23514';
  end if;

  if new.project_scope_id is not null
    and not exists (
      select 1 from public.v1_project_scopes scope
      where scope.id = new.project_scope_id
        and scope.project_id = new.project_id
        and scope.is_active
    )
  then
    raise exception 'V1_WORKFORCE_ACTIVE_PROJECT_SCOPE_REQUIRED'
      using errcode = '23514';
  end if;

  if new.internal_location_id is not null
    and not exists (
      select 1 from public.v1_workforce_internal_locations location
      where location.id = new.internal_location_id
        and location.is_active
    )
  then
    raise exception 'V1_WORKFORCE_ACTIVE_INTERNAL_LOCATION_REQUIRED'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger v1_workforce_worker_assignments_validate
before insert or update on public.v1_workforce_worker_assignments
for each row execute function public.v1_workforce_validate_worker_assignment();

create or replace function public.v1_workforce_assert_admin()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    raise exception 'V1_WORKFORCE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active()
    or public.v1_permission_exact_role(v_actor) <> 'admin'
  then
    raise exception 'V1_WORKFORCE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
  return v_actor;
end;
$$;

create or replace function public.v1_workforce_effective_assignment(
  p_worker_id uuid,
  p_on_date date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'assignment_id', assignment.id,
      'assignment_kind', assignment.assignment_kind,
      'team_id', assignment.team_id,
      'team_name', team.team_name,
      'supervisor_auth_user_id', assignment.supervisor_auth_user_id,
      'supervisor_name', supervisor.display_name,
      'project_id', assignment.project_id,
      'project_ref', project.project_ref,
      'project_name', project.name,
      'project_scope_id', assignment.project_scope_id,
      'project_scope_name', scope.name,
      'internal_location_id', assignment.internal_location_id,
      'internal_location_name', location.location_name,
      'valid_from', assignment.valid_from,
      'valid_to', assignment.valid_to,
      'record_version', assignment.record_version
    )
    from public.v1_workforce_worker_assignments assignment
    left join public.v1_workforce_teams team on team.id = assignment.team_id
    left join public.v1_profiles supervisor
      on supervisor.auth_user_id = assignment.supervisor_auth_user_id
    left join public.v1_projects project on project.id = assignment.project_id
    left join public.v1_project_scopes scope
      on scope.id = assignment.project_scope_id
    left join public.v1_workforce_internal_locations location
      on location.id = assignment.internal_location_id
    where assignment.worker_id = p_worker_id
      and assignment.valid_from <= p_on_date
      and (assignment.valid_to is null or assignment.valid_to >= p_on_date)
    order by
      case assignment.assignment_kind when 'temporary' then 0 else 1 end,
      assignment.valid_from desc,
      assignment.id
    limit 1
  ), '{}'::jsonb);
$$;

create or replace function public.v1_workforce_responsibility_allows(
  p_auth_user_id uuid,
  p_worker_id uuid,
  p_on_date date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_assignment jsonb;
begin
  if p_auth_user_id is null or p_worker_id is null or p_on_date is null then
    return false;
  end if;
  if not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = p_auth_user_id and profile.is_active
  ) then
    return false;
  end if;

  v_assignment := public.v1_workforce_effective_assignment(
    p_worker_id, p_on_date
  );

  return exists (
    select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = p_auth_user_id
      and responsibility.valid_from <= p_on_date
      and (responsibility.valid_to is null
        or responsibility.valid_to >= p_on_date)
      and (
        responsibility.scope_kind = 'organization'
        or (responsibility.scope_kind = 'worker'
          and responsibility.worker_id = p_worker_id)
        or (responsibility.scope_kind = 'team'
          and responsibility.team_id = nullif(
            v_assignment ->> 'team_id', ''
          )::uuid)
        or (responsibility.scope_kind = 'project'
          and responsibility.project_id = nullif(
            v_assignment ->> 'project_id', ''
          )::uuid)
        or (responsibility.scope_kind = 'project_scope'
          and responsibility.project_scope_id = nullif(
            v_assignment ->> 'project_scope_id', ''
          )::uuid)
        or (responsibility.scope_kind = 'internal_location'
          and responsibility.internal_location_id = nullif(
            v_assignment ->> 'internal_location_id', ''
          )::uuid)
      )
  );
end;
$$;

create or replace function public.v1_workforce_worker_json(
  p_worker_id uuid,
  p_on_date date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'worker_id', worker.id,
    'worker_number', worker.worker_number,
    'full_name', worker.full_name,
    'preferred_display_name', worker.preferred_display_name,
    'designation', worker.designation,
    'trade_id', worker.trade_id,
    'trade_name', trade.trade_name,
    'department', worker.department,
    'employer_company', worker.employer_company,
    'worker_type', worker.worker_type,
    'mobile_number', worker.mobile_number,
    'joining_date', worker.joining_date,
    'leaving_date', worker.leaving_date,
    'current_status', worker.current_status,
    'linked_auth_user_id', worker.linked_auth_user_id,
    'notes', worker.notes,
    'record_version', worker.record_version,
    'created_at', worker.created_at,
    'updated_at', worker.updated_at,
    'effective_assignment', public.v1_workforce_effective_assignment(
      worker.id, p_on_date
    )
  )
  from public.v1_workforce_workers worker
  left join public.v1_workforce_trades trade on trade.id = worker.trade_id
  where worker.id = p_worker_id;
$$;

create or replace function public.v1_get_workforce_foundation(
  p_query text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0,
  p_on_date date default current_date
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
begin
  if p_limit < 1 or p_limit > 100 or p_offset < 0 or p_on_date is null then
    raise exception 'V1_WORKFORCE_FOUNDATION_FILTER_INVALID'
      using errcode = '22023';
  end if;
  if v_status is not null and v_status not in (
    'active', 'inactive', 'left_company', 'suspended'
  ) then
    raise exception 'V1_WORKFORCE_STATUS_INVALID'
      using errcode = '22023';
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'admin_legacy_t01',
    'actor_auth_user_id', v_actor,
    'on_date', p_on_date,
    'server_time', clock_timestamp(),
    'trades', coalesce((
      select jsonb_agg(jsonb_build_object(
        'trade_id', trade.id,
        'trade_code', trade.trade_code,
        'trade_name', trade.trade_name,
        'description', trade.description,
        'is_active', trade.is_active,
        'record_version', trade.record_version
      ) order by lower(trade.trade_name), trade.id)
      from public.v1_workforce_trades trade
    ), '[]'::jsonb),
    'teams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'team_id', team.id,
        'team_code', team.team_code,
        'team_name', team.team_name,
        'department', team.department,
        'default_supervisor_auth_user_id',
          team.default_supervisor_auth_user_id,
        'default_project_id', team.default_project_id,
        'default_project_scope_id', team.default_project_scope_id,
        'default_internal_location_id', team.default_internal_location_id,
        'valid_from', team.valid_from,
        'valid_to', team.valid_to,
        'is_active', team.is_active,
        'record_version', team.record_version
      ) order by lower(team.team_name), team.id)
      from public.v1_workforce_teams team
    ), '[]'::jsonb),
    'internal_locations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'internal_location_id', location.id,
        'location_code', location.location_code,
        'location_name', location.location_name,
        'department', location.department,
        'is_active', location.is_active,
        'record_version', location.record_version
      ) order by lower(location.location_name), location.id)
      from public.v1_workforce_internal_locations location
    ), '[]'::jsonb),
    'workers', coalesce((
      select jsonb_agg(public.v1_workforce_worker_json(
        filtered.id, p_on_date
      ) order by lower(filtered.worker_number), filtered.id)
      from (
        select worker.id, worker.worker_number
        from public.v1_workforce_workers worker
        where (v_status is null or worker.current_status = v_status)
          and (
            v_query is null
            or lower(worker.worker_number) like '%' || v_query || '%'
            or lower(worker.full_name) like '%' || v_query || '%'
            or lower(coalesce(worker.preferred_display_name, ''))
              like '%' || v_query || '%'
            or lower(worker.designation) like '%' || v_query || '%'
          )
        order by lower(worker.worker_number), worker.id
        limit p_limit offset p_offset
      ) filtered
    ), '[]'::jsonb),
    'worker_count', (
      select count(*)
      from public.v1_workforce_workers worker
      where (v_status is null or worker.current_status = v_status)
        and (
          v_query is null
          or lower(worker.worker_number) like '%' || v_query || '%'
          or lower(worker.full_name) like '%' || v_query || '%'
          or lower(coalesce(worker.preferred_display_name, ''))
            like '%' || v_query || '%'
          or lower(worker.designation) like '%' || v_query || '%'
        )
    )
  );
end;
$$;

create or replace function public.v1_save_workforce_trade(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_before jsonb;
  v_trade public.v1_workforce_trades%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['trade_id','trade_code','trade_name','description','is_active'],
    'save_workforce_trade_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_trade', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'trade_id', '')), '')::uuid;
  exception when invalid_text_representation then
    raise exception 'V1_WORKFORCE_TRADE_ID_INVALID' using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());

  if btrim(coalesce(p_payload ->> 'trade_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'trade_name', '')) = ''
  then
    raise exception 'V1_WORKFORCE_TRADE_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;

  select trade.* into v_trade
  from public.v1_workforce_trades trade
  where trade.id = v_id
  for update;

  if found then
    v_before := jsonb_build_object(
      'trade_code', v_trade.trade_code,
      'trade_name', v_trade.trade_name,
      'is_active', v_trade.is_active,
      'record_version', v_trade.record_version
    );
    if p_expected_version is null or p_expected_version <> v_trade.record_version then
      raise exception 'V1_WORKFORCE_TRADE_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    update public.v1_workforce_trades set
      trade_code = upper(btrim(p_payload ->> 'trade_code')),
      trade_name = btrim(p_payload ->> 'trade_name'),
      description = nullif(btrim(coalesce(p_payload ->> 'description', '')), ''),
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_trade;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_TRADE_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_trades (
      id, trade_code, trade_name, description, is_active,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'trade_code')),
      btrim(p_payload ->> 'trade_name'),
      nullif(btrim(coalesce(p_payload ->> 'description', '')), ''),
      coalesce((p_payload ->> 'is_active')::boolean, true),
      v_actor, v_actor
    ) returning * into v_trade;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'trade_id', v_trade.id,
    'record_version', v_trade.record_version,
    'trade_code', v_trade.trade_code,
    'trade_name', v_trade.trade_name,
    'is_active', v_trade.is_active
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_trade_created'
      else 'workforce_trade_updated' end,
    'workforce_trade', v_trade.id, null, v_before,
    v_response - 'schema_version',
    'Workforce trade master saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_trade', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_internal_location(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_before jsonb;
  v_location public.v1_workforce_internal_locations%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['internal_location_id','location_code','location_name','department','is_active'],
    'save_workforce_internal_location_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_internal_location', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(
      p_payload ->> 'internal_location_id', ''
    )), '')::uuid;
  exception when invalid_text_representation then
    raise exception 'V1_WORKFORCE_INTERNAL_LOCATION_ID_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if btrim(coalesce(p_payload ->> 'location_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'location_name', '')) = ''
  then
    raise exception 'V1_WORKFORCE_INTERNAL_LOCATION_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;

  select location.* into v_location
  from public.v1_workforce_internal_locations location
  where location.id = v_id for update;
  if found then
    v_before := jsonb_build_object(
      'location_code', v_location.location_code,
      'location_name', v_location.location_name,
      'is_active', v_location.is_active,
      'record_version', v_location.record_version
    );
    if p_expected_version is null
      or p_expected_version <> v_location.record_version then
      raise exception 'V1_WORKFORCE_INTERNAL_LOCATION_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    update public.v1_workforce_internal_locations set
      location_code = upper(btrim(p_payload ->> 'location_code')),
      location_name = btrim(p_payload ->> 'location_name'),
      department = nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_location;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_INTERNAL_LOCATION_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_internal_locations (
      id, location_code, location_name, department, is_active,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'location_code')),
      btrim(p_payload ->> 'location_name'),
      nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      coalesce((p_payload ->> 'is_active')::boolean, true),
      v_actor, v_actor
    ) returning * into v_location;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'internal_location_id', v_location.id,
    'record_version', v_location.record_version,
    'location_code', v_location.location_code,
    'location_name', v_location.location_name,
    'is_active', v_location.is_active
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_internal_location_created'
      else 'workforce_internal_location_updated' end,
    'workforce_internal_location', v_location.id, null, v_before,
    v_response - 'schema_version',
    'Workforce internal location saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_internal_location', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_worker(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_trade_id uuid;
  v_linked_auth_user_id uuid;
  v_joining_date date;
  v_leaving_date date;
  v_status text := btrim(coalesce(p_payload ->> 'current_status', 'active'));
  v_worker_type text := btrim(coalesce(p_payload ->> 'worker_type', ''));
  v_before jsonb;
  v_worker public.v1_workforce_workers%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'worker_id','worker_number','full_name','preferred_display_name',
      'designation','trade_id','department','employer_company','worker_type',
      'mobile_number','joining_date','leaving_date','current_status',
      'linked_auth_user_id','notes'
    ],
    'save_workforce_worker_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_worker', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'worker_id', '')), '')::uuid;
    v_trade_id := nullif(btrim(coalesce(p_payload ->> 'trade_id', '')), '')::uuid;
    v_linked_auth_user_id := nullif(btrim(coalesce(
      p_payload ->> 'linked_auth_user_id', ''
    )), '')::uuid;
    v_joining_date := nullif(btrim(coalesce(
      p_payload ->> 'joining_date', ''
    )), '')::date;
    v_leaving_date := nullif(btrim(coalesce(
      p_payload ->> 'leaving_date', ''
    )), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_WORKER_REFERENCE_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());

  if btrim(coalesce(p_payload ->> 'worker_number', '')) = ''
    or btrim(coalesce(p_payload ->> 'full_name', '')) = ''
    or btrim(coalesce(p_payload ->> 'designation', '')) = ''
    or btrim(coalesce(p_payload ->> 'employer_company', '')) = ''
    or v_joining_date is null
    or v_worker_type not in (
      'yorks_employee', 'temporary_worker', 'subcontractor_worker',
      'agency_worker'
    )
    or v_status not in ('active','inactive','left_company','suspended')
  then
    raise exception 'V1_WORKFORCE_WORKER_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;
  if v_leaving_date is not null and v_leaving_date < v_joining_date then
    raise exception 'V1_WORKFORCE_WORKER_DATE_INVALID'
      using errcode = '22023';
  end if;
  if v_status = 'left_company' and v_leaving_date is null then
    raise exception 'V1_WORKFORCE_LEAVING_DATE_REQUIRED'
      using errcode = '22023';
  end if;
  if v_linked_auth_user_id is not null and not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = v_linked_auth_user_id
  ) then
    raise exception 'V1_WORKFORCE_LINKED_USER_NOT_FOUND'
      using errcode = '23503';
  end if;

  select worker.* into v_worker
  from public.v1_workforce_workers worker
  where worker.id = v_id for update;
  if found then
    v_before := jsonb_build_object(
      'worker_number', v_worker.worker_number,
      'full_name', v_worker.full_name,
      'trade_id', v_worker.trade_id,
      'designation', v_worker.designation,
      'current_status', v_worker.current_status,
      'joining_date', v_worker.joining_date,
      'leaving_date', v_worker.leaving_date,
      'record_version', v_worker.record_version
    );
    if p_expected_version is null or p_expected_version <> v_worker.record_version then
      raise exception 'V1_WORKFORCE_WORKER_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    if exists (
      select 1
      from public.v1_workforce_worker_assignments assignment
      where assignment.worker_id = v_id
        and (
          assignment.valid_from < v_joining_date
          or (
            v_leaving_date is not null
            and (
              assignment.valid_to is null
              or assignment.valid_to > v_leaving_date
            )
          )
        )
    ) then
      raise exception 'V1_WORKFORCE_WORKER_DATES_CONFLICT_WITH_ASSIGNMENTS'
        using errcode = '23514';
    end if;
    update public.v1_workforce_workers set
      worker_number = upper(btrim(p_payload ->> 'worker_number')),
      full_name = btrim(p_payload ->> 'full_name'),
      preferred_display_name = nullif(btrim(coalesce(
        p_payload ->> 'preferred_display_name', ''
      )), ''),
      designation = btrim(p_payload ->> 'designation'),
      trade_id = v_trade_id,
      department = nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      employer_company = btrim(p_payload ->> 'employer_company'),
      worker_type = v_worker_type,
      mobile_number = nullif(btrim(coalesce(p_payload ->> 'mobile_number', '')), ''),
      joining_date = v_joining_date,
      leaving_date = v_leaving_date,
      current_status = v_status,
      linked_auth_user_id = v_linked_auth_user_id,
      notes = nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_worker;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_WORKER_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_workers (
      id, worker_number, full_name, preferred_display_name, designation,
      trade_id, department, employer_company, worker_type, mobile_number,
      joining_date, leaving_date, current_status, linked_auth_user_id, notes,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'worker_number')),
      btrim(p_payload ->> 'full_name'),
      nullif(btrim(coalesce(p_payload ->> 'preferred_display_name', '')), ''),
      btrim(p_payload ->> 'designation'), v_trade_id,
      nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      btrim(p_payload ->> 'employer_company'), v_worker_type,
      nullif(btrim(coalesce(p_payload ->> 'mobile_number', '')), ''),
      v_joining_date, v_leaving_date, v_status, v_linked_auth_user_id,
      nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
      v_actor, v_actor
    ) returning * into v_worker;
  end if;

  v_response := public.v1_workforce_worker_json(v_worker.id, current_date)
    || jsonb_build_object('schema_version', 1);
  perform public.v1_write_audit_event(
    case
      when v_before is null then 'workforce_worker_created'
      when v_before ->> 'current_status' = 'active'
        and v_worker.current_status <> 'active'
        then 'workforce_worker_deactivated'
      else 'workforce_worker_updated'
    end,
    'workforce_worker', v_worker.id, null, v_before,
    jsonb_build_object(
      'worker_number', v_worker.worker_number,
      'full_name', v_worker.full_name,
      'trade_id', v_worker.trade_id,
      'designation', v_worker.designation,
      'current_status', v_worker.current_status,
      'joining_date', v_worker.joining_date,
      'leaving_date', v_worker.leaving_date,
      'record_version', v_worker.record_version
    ),
    'Workforce worker master saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_worker', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_team(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_supervisor uuid;
  v_project uuid;
  v_scope uuid;
  v_location uuid;
  v_valid_from date;
  v_valid_to date;
  v_before jsonb;
  v_team public.v1_workforce_teams%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'team_id','team_code','team_name','department',
      'default_supervisor_auth_user_id','default_project_id',
      'default_project_scope_id','default_internal_location_id',
      'valid_from','valid_to','is_active'
    ],
    'save_workforce_team_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_team', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'team_id', '')), '')::uuid;
    v_supervisor := nullif(btrim(coalesce(
      p_payload ->> 'default_supervisor_auth_user_id', ''
    )), '')::uuid;
    v_project := nullif(btrim(coalesce(
      p_payload ->> 'default_project_id', ''
    )), '')::uuid;
    v_scope := nullif(btrim(coalesce(
      p_payload ->> 'default_project_scope_id', ''
    )), '')::uuid;
    v_location := nullif(btrim(coalesce(
      p_payload ->> 'default_internal_location_id', ''
    )), '')::uuid;
    v_valid_from := nullif(btrim(coalesce(
      p_payload ->> 'valid_from', ''
    )), '')::date;
    v_valid_to := nullif(btrim(coalesce(
      p_payload ->> 'valid_to', ''
    )), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_TEAM_REFERENCE_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if btrim(coalesce(p_payload ->> 'team_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'team_name', '')) = ''
    or v_valid_from is null
    or (v_valid_to is not null and v_valid_to < v_valid_from)
    or (v_project is not null and v_location is not null)
    or (v_scope is not null and v_project is null)
  then
    raise exception 'V1_WORKFORCE_TEAM_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;
  if v_supervisor is not null and not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = v_supervisor and profile.is_active
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_SUPERVISOR_REQUIRED'
      using errcode = '23514';
  end if;
  if v_project is not null and not exists (
    select 1 from public.v1_projects project
    where project.id = v_project and project.state = 'active'
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_PROJECT_REQUIRED'
      using errcode = '23514';
  end if;
  if v_scope is not null and not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = v_scope and scope.project_id = v_project and scope.is_active
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_PROJECT_SCOPE_REQUIRED'
      using errcode = '23514';
  end if;
  if v_location is not null and not exists (
    select 1 from public.v1_workforce_internal_locations location
    where location.id = v_location and location.is_active
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_INTERNAL_LOCATION_REQUIRED'
      using errcode = '23514';
  end if;

  select team.* into v_team
  from public.v1_workforce_teams team
  where team.id = v_id for update;
  if found then
    v_before := jsonb_build_object(
      'team_code', v_team.team_code,
      'team_name', v_team.team_name,
      'is_active', v_team.is_active,
      'valid_from', v_team.valid_from,
      'valid_to', v_team.valid_to,
      'record_version', v_team.record_version
    );
    if p_expected_version is null or p_expected_version <> v_team.record_version then
      raise exception 'V1_WORKFORCE_TEAM_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    if exists (
      select 1
      from public.v1_workforce_worker_assignments assignment
      where assignment.team_id = v_id
        and (
          assignment.valid_from < v_valid_from
          or (
            v_valid_to is not null
            and (
              assignment.valid_to is null
              or assignment.valid_to > v_valid_to
            )
          )
        )
    ) then
      raise exception 'V1_WORKFORCE_TEAM_DATES_CONFLICT_WITH_ASSIGNMENTS'
        using errcode = '23514';
    end if;
    update public.v1_workforce_teams set
      team_code = upper(btrim(p_payload ->> 'team_code')),
      team_name = btrim(p_payload ->> 'team_name'),
      department = nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      default_supervisor_auth_user_id = v_supervisor,
      default_project_id = v_project,
      default_project_scope_id = v_scope,
      default_internal_location_id = v_location,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_team;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_TEAM_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_teams (
      id, team_code, team_name, department,
      default_supervisor_auth_user_id, default_project_id,
      default_project_scope_id, default_internal_location_id,
      valid_from, valid_to, is_active,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'team_code')),
      btrim(p_payload ->> 'team_name'),
      nullif(btrim(coalesce(p_payload ->> 'department', '')), ''),
      v_supervisor, v_project, v_scope, v_location, v_valid_from, v_valid_to,
      coalesce((p_payload ->> 'is_active')::boolean, true), v_actor, v_actor
    ) returning * into v_team;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'team_id', v_team.id,
    'team_code', v_team.team_code,
    'team_name', v_team.team_name,
    'department', v_team.department,
    'default_supervisor_auth_user_id', v_team.default_supervisor_auth_user_id,
    'default_project_id', v_team.default_project_id,
    'default_project_scope_id', v_team.default_project_scope_id,
    'default_internal_location_id', v_team.default_internal_location_id,
    'valid_from', v_team.valid_from,
    'valid_to', v_team.valid_to,
    'is_active', v_team.is_active,
    'record_version', v_team.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_team_created'
      else 'workforce_team_updated' end,
    'workforce_team', v_team.id, v_team.default_project_id, v_before,
    v_response - 'schema_version', 'Workforce team saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_team', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_worker_assignment(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_exact_role text := public.v1_permission_exact_role(v_actor);
  v_existing jsonb;
  v_id uuid;
  v_worker uuid;
  v_team uuid;
  v_supervisor uuid;
  v_project uuid;
  v_scope uuid;
  v_location uuid;
  v_valid_from date;
  v_valid_to date;
  v_kind text := btrim(coalesce(p_payload ->> 'assignment_kind', ''));
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_before jsonb;
  v_assignment public.v1_workforce_worker_assignments%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'assignment_id','worker_id','assignment_kind','team_id',
      'supervisor_auth_user_id','project_id','project_scope_id',
      'internal_location_id','valid_from','valid_to','reason'
    ],
    'save_workforce_worker_assignment_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_worker_assignment', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'assignment_id', '')), '')::uuid;
    v_worker := nullif(btrim(coalesce(p_payload ->> 'worker_id', '')), '')::uuid;
    v_team := nullif(btrim(coalesce(p_payload ->> 'team_id', '')), '')::uuid;
    v_supervisor := nullif(btrim(coalesce(
      p_payload ->> 'supervisor_auth_user_id', ''
    )), '')::uuid;
    v_project := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
    v_scope := nullif(btrim(coalesce(p_payload ->> 'project_scope_id', '')), '')::uuid;
    v_location := nullif(btrim(coalesce(
      p_payload ->> 'internal_location_id', ''
    )), '')::uuid;
    v_valid_from := nullif(btrim(coalesce(p_payload ->> 'valid_from', '')), '')::date;
    v_valid_to := nullif(btrim(coalesce(p_payload ->> 'valid_to', '')), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_ASSIGNMENT_REFERENCE_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if v_worker is null or v_valid_from is null or v_reason is null
    or v_kind not in ('primary','temporary')
    or (v_kind = 'temporary' and v_valid_to is null)
    or (v_valid_to is not null and v_valid_to < v_valid_from)
    or (v_project is not null and v_location is not null)
    or (v_scope is not null and v_project is null)
    or (v_team is null and v_supervisor is null
      and v_project is null and v_location is null)
  then
    raise exception 'V1_WORKFORCE_ASSIGNMENT_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;

  select assignment.* into v_assignment
  from public.v1_workforce_worker_assignments assignment
  where assignment.id = v_id for update;
  if found then
    v_before := jsonb_build_object(
      'worker_id', v_assignment.worker_id,
      'assignment_kind', v_assignment.assignment_kind,
      'team_id', v_assignment.team_id,
      'supervisor_auth_user_id', v_assignment.supervisor_auth_user_id,
      'project_id', v_assignment.project_id,
      'project_scope_id', v_assignment.project_scope_id,
      'internal_location_id', v_assignment.internal_location_id,
      'valid_from', v_assignment.valid_from,
      'valid_to', v_assignment.valid_to,
      'record_version', v_assignment.record_version
    );
    if p_expected_version is null
      or p_expected_version <> v_assignment.record_version then
      raise exception 'V1_WORKFORCE_ASSIGNMENT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    update public.v1_workforce_worker_assignments set
      worker_id = v_worker,
      assignment_kind = v_kind,
      team_id = v_team,
      supervisor_auth_user_id = v_supervisor,
      project_id = v_project,
      project_scope_id = v_scope,
      internal_location_id = v_location,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      reason = v_reason,
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_assignment;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_ASSIGNMENT_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_worker_assignments (
      id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
      project_id, project_scope_id, internal_location_id,
      valid_from, valid_to, reason,
      assigned_by_auth_user_id, assigned_by_exact_role,
      updated_by_auth_user_id
    ) values (
      v_id, v_worker, v_kind, v_team, v_supervisor,
      v_project, v_scope, v_location, v_valid_from, v_valid_to, v_reason,
      v_actor, v_exact_role, v_actor
    ) returning * into v_assignment;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'assignment_id', v_assignment.id,
    'worker_id', v_assignment.worker_id,
    'assignment_kind', v_assignment.assignment_kind,
    'team_id', v_assignment.team_id,
    'supervisor_auth_user_id', v_assignment.supervisor_auth_user_id,
    'project_id', v_assignment.project_id,
    'project_scope_id', v_assignment.project_scope_id,
    'internal_location_id', v_assignment.internal_location_id,
    'valid_from', v_assignment.valid_from,
    'valid_to', v_assignment.valid_to,
    'record_version', v_assignment.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_assignment_created'
      else 'workforce_assignment_updated' end,
    'workforce_assignment', v_assignment.id, v_assignment.project_id,
    v_before, v_response - 'schema_version', v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_worker_assignment', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_responsibility_assignment(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_exact_role text := public.v1_permission_exact_role(v_actor);
  v_existing jsonb;
  v_id uuid;
  v_target_auth uuid;
  v_worker uuid;
  v_team uuid;
  v_project uuid;
  v_scope uuid;
  v_location uuid;
  v_valid_from date;
  v_valid_to date;
  v_scope_kind text := btrim(coalesce(p_payload ->> 'scope_kind', ''));
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_before jsonb;
  v_responsibility public.v1_workforce_responsibility_assignments%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'responsibility_assignment_id','auth_user_id','scope_kind','worker_id',
      'team_id','project_id','project_scope_id','internal_location_id',
      'valid_from','valid_to','reason'
    ],
    'save_workforce_responsibility_assignment_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_responsibility_assignment', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(
      p_payload ->> 'responsibility_assignment_id', ''
    )), '')::uuid;
    v_target_auth := nullif(btrim(coalesce(p_payload ->> 'auth_user_id', '')), '')::uuid;
    v_worker := nullif(btrim(coalesce(p_payload ->> 'worker_id', '')), '')::uuid;
    v_team := nullif(btrim(coalesce(p_payload ->> 'team_id', '')), '')::uuid;
    v_project := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
    v_scope := nullif(btrim(coalesce(p_payload ->> 'project_scope_id', '')), '')::uuid;
    v_location := nullif(btrim(coalesce(
      p_payload ->> 'internal_location_id', ''
    )), '')::uuid;
    v_valid_from := nullif(btrim(coalesce(p_payload ->> 'valid_from', '')), '')::date;
    v_valid_to := nullif(btrim(coalesce(p_payload ->> 'valid_to', '')), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_RESPONSIBILITY_REFERENCE_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if v_target_auth is null or v_valid_from is null or v_reason is null
    or v_scope_kind not in (
      'organization','worker','team','project','project_scope',
      'internal_location'
    )
    or (v_valid_to is not null and v_valid_to < v_valid_from)
    or not (
      (v_scope_kind = 'organization'
        and v_worker is null and v_team is null and v_project is null
        and v_scope is null and v_location is null)
      or (v_scope_kind = 'worker'
        and v_worker is not null and v_team is null and v_project is null
        and v_scope is null and v_location is null)
      or (v_scope_kind = 'team'
        and v_worker is null and v_team is not null and v_project is null
        and v_scope is null and v_location is null)
      or (v_scope_kind = 'project'
        and v_worker is null and v_team is null and v_project is not null
        and v_scope is null and v_location is null)
      or (v_scope_kind = 'project_scope'
        and v_worker is null and v_team is null and v_project is not null
        and v_scope is not null and v_location is null)
      or (v_scope_kind = 'internal_location'
        and v_worker is null and v_team is null and v_project is null
        and v_scope is null and v_location is not null)
    )
  then
    raise exception 'V1_WORKFORCE_RESPONSIBILITY_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = v_target_auth and profile.is_active
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_RESPONSIBLE_USER_REQUIRED'
      using errcode = '23514';
  end if;

  select responsibility.* into v_responsibility
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.id = v_id for update;
  if found then
    v_before := jsonb_build_object(
      'auth_user_id', v_responsibility.auth_user_id,
      'scope_kind', v_responsibility.scope_kind,
      'scope_reference', v_responsibility.scope_reference,
      'valid_from', v_responsibility.valid_from,
      'valid_to', v_responsibility.valid_to,
      'record_version', v_responsibility.record_version
    );
    if p_expected_version is null
      or p_expected_version <> v_responsibility.record_version then
      raise exception 'V1_WORKFORCE_RESPONSIBILITY_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    update public.v1_workforce_responsibility_assignments set
      auth_user_id = v_target_auth,
      scope_kind = v_scope_kind,
      worker_id = v_worker,
      team_id = v_team,
      project_id = v_project,
      project_scope_id = v_scope,
      internal_location_id = v_location,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      reason = v_reason,
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_responsibility;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_RESPONSIBILITY_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_responsibility_assignments (
      id, auth_user_id, scope_kind, worker_id, team_id, project_id,
      project_scope_id, internal_location_id, valid_from, valid_to, reason,
      assigned_by_auth_user_id, assigned_by_exact_role,
      updated_by_auth_user_id
    ) values (
      v_id, v_target_auth, v_scope_kind, v_worker, v_team, v_project,
      v_scope, v_location, v_valid_from, v_valid_to, v_reason,
      v_actor, v_exact_role, v_actor
    ) returning * into v_responsibility;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'responsibility_assignment_id', v_responsibility.id,
    'auth_user_id', v_responsibility.auth_user_id,
    'scope_kind', v_responsibility.scope_kind,
    'scope_reference', v_responsibility.scope_reference,
    'worker_id', v_responsibility.worker_id,
    'team_id', v_responsibility.team_id,
    'project_id', v_responsibility.project_id,
    'project_scope_id', v_responsibility.project_scope_id,
    'internal_location_id', v_responsibility.internal_location_id,
    'valid_from', v_responsibility.valid_from,
    'valid_to', v_responsibility.valid_to,
    'record_version', v_responsibility.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_responsibility_created'
      else 'workforce_responsibility_updated' end,
    'workforce_responsibility_assignment', v_responsibility.id,
    v_responsibility.project_id, v_before, v_response - 'schema_version',
    v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_responsibility_assignment',
    p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke execute on function public.v1_workforce_is_capability_key(text)
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_block_delete()
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_validate_worker_assignment()
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_assert_admin()
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_effective_assignment(uuid,date)
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_responsibility_allows(uuid,uuid,date)
  from public, anon, authenticated;
revoke execute on function public.v1_workforce_worker_json(uuid,date)
  from public, anon, authenticated;

revoke execute on function public.v1_get_workforce_foundation(
  text,text,integer,integer,date
) from public, anon;
revoke execute on function public.v1_save_workforce_trade(
  jsonb,bigint,uuid
) from public, anon;
revoke execute on function public.v1_save_workforce_internal_location(
  jsonb,bigint,uuid
) from public, anon;
revoke execute on function public.v1_save_workforce_worker(
  jsonb,bigint,uuid
) from public, anon;
revoke execute on function public.v1_save_workforce_team(
  jsonb,bigint,uuid
) from public, anon;
revoke execute on function public.v1_save_workforce_worker_assignment(
  jsonb,bigint,uuid
) from public, anon;
revoke execute on function public.v1_save_workforce_responsibility_assignment(
  jsonb,bigint,uuid
) from public, anon;

grant execute on function public.v1_get_workforce_foundation(
  text,text,integer,integer,date
) to authenticated;
grant execute on function public.v1_save_workforce_trade(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_internal_location(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_worker(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_team(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_worker_assignment(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_responsibility_assignment(
  jsonb,bigint,uuid
) to authenticated;

commit;
