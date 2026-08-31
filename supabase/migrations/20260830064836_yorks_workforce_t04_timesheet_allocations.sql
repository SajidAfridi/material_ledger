-- Yorks Workforce T04: protected daily timesheet allocation authority.
--
-- This additive, route-less slice promotes only
-- workforce.timesheets.maintain in addition to the accepted T03 consumers.
-- It creates no monthly period, review lifecycle, route, UI, legacy migration,
-- feature enablement, remote migration or deployment.

begin;

create table public.v1_workforce_timesheet_allocation_sets (
  id uuid primary key default gen_random_uuid(),
  attendance_day_id uuid not null unique
    references public.v1_workforce_attendance_days (id) on delete restrict,
  worker_id uuid not null
    references public.v1_workforce_workers (id) on delete restrict,
  work_date date not null,
  current_revision_id uuid,
  current_revision_number bigint not null default 0 check (
    current_revision_number >= 0
  ),
  current_state text not null default 'withdrawn' check (
    current_state in ('active', 'withdrawn')
  ),
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  unique (worker_id, work_date),
  unique (id, current_revision_number),
  check (
    (current_revision_number = 0 and current_revision_id is null)
    or (current_revision_number > 0 and current_revision_id is not null)
  )
);

create table public.v1_workforce_timesheet_allocation_revisions (
  id uuid primary key default gen_random_uuid(),
  allocation_set_id uuid not null
    references public.v1_workforce_timesheet_allocation_sets (id)
    on delete restrict,
  revision_number bigint not null check (revision_number > 0),
  revision_state text not null check (revision_state in ('active', 'withdrawn')),
  attendance_record_version_basis bigint not null check (
    attendance_record_version_basis > 0
  ),
  total_regular_minutes integer not null check (
    total_regular_minutes between 0 and 1440
  ),
  total_overtime_minutes integer not null check (
    total_overtime_minutes between 0 and 1440
  ),
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  authority_kind text not null check (
    authority_kind in ('admin_organization', 'responsibility')
  ),
  responsibility_assignment_id uuid,
  responsibility_scope_kind text not null check (
    responsibility_scope_kind in (
      'organization', 'worker', 'team', 'project', 'project_scope',
      'internal_location'
    )
  ),
  responsibility_scope_reference text not null,
  responsibility_record_version bigint,
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (allocation_set_id, revision_number),
  unique (allocation_set_id, id),
  check (total_regular_minutes + total_overtime_minutes <= 1440),
  check (
    (revision_state = 'active'
      and total_regular_minutes + total_overtime_minutes > 0)
    or (revision_state = 'withdrawn'
      and total_regular_minutes = 0 and total_overtime_minutes = 0)
  )
);

alter table public.v1_workforce_timesheet_allocation_sets
  add constraint v1_workforce_timesheet_sets_current_revision_fk
  foreign key (id, current_revision_id)
  references public.v1_workforce_timesheet_allocation_revisions (
    allocation_set_id, id
  ) on delete restrict deferrable initially deferred;

create table public.v1_workforce_timesheet_allocations (
  id uuid primary key default gen_random_uuid(),
  allocation_revision_id uuid not null
    references public.v1_workforce_timesheet_allocation_revisions (id)
    on delete restrict,
  line_number integer not null check (line_number > 0),
  target_kind text not null check (
    target_kind in ('project_work', 'internal_work')
  ),

  project_id uuid references public.v1_projects (id) on delete restrict,
  project_ref_snapshot text,
  project_name_snapshot text,
  project_record_version_snapshot bigint,
  project_scope_id uuid,
  project_scope_kind_snapshot text,
  project_scope_code_snapshot text,
  project_scope_name_snapshot text,
  project_scope_record_version_snapshot bigint,

  internal_location_id uuid
    references public.v1_workforce_internal_locations (id) on delete restrict,
  internal_location_code_snapshot text,
  internal_location_name_snapshot text,
  department_cost_centre_snapshot text,
  internal_location_record_version_snapshot bigint,

  target_authority_kind text not null check (
    target_authority_kind in ('admin_organization', 'responsibility')
  ),
  target_responsibility_assignment_id uuid,
  target_responsibility_scope_kind text not null check (
    target_responsibility_scope_kind in (
      'organization', 'project', 'project_scope', 'internal_location'
    )
  ),
  target_responsibility_scope_reference text not null,
  target_responsibility_record_version bigint,

  activity_task text check (
    activity_task is null or char_length(activity_task) <= 500
  ),
  notes text check (notes is null or char_length(notes) <= 2000),
  regular_minutes integer not null check (regular_minutes between 0 and 1440),
  overtime_minutes integer not null check (
    overtime_minutes between 0 and 1440
  ),
  start_time_local time,
  end_time_local time,
  interval_start_at timestamptz,
  interval_end_at timestamptz,
  crosses_midnight boolean,
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (allocation_revision_id, line_number),
  foreign key (project_id, project_scope_id)
    references public.v1_project_scopes (project_id, id) on delete restrict,
  check (regular_minutes + overtime_minutes between 1 and 1440),
  check (
    (target_kind = 'project_work'
      and project_id is not null and project_scope_id is not null
      and project_ref_snapshot is not null
      and project_name_snapshot is not null
      and project_record_version_snapshot is not null
      and project_scope_kind_snapshot is not null
      and project_scope_code_snapshot is not null
      and project_scope_name_snapshot is not null
      and project_scope_record_version_snapshot is not null
      and internal_location_id is null
      and internal_location_code_snapshot is null
      and internal_location_name_snapshot is null
      and department_cost_centre_snapshot is null
      and internal_location_record_version_snapshot is null)
    or (target_kind = 'internal_work'
      and project_id is null and project_scope_id is null
      and project_ref_snapshot is null and project_name_snapshot is null
      and project_record_version_snapshot is null
      and project_scope_kind_snapshot is null
      and project_scope_code_snapshot is null
      and project_scope_name_snapshot is null
      and project_scope_record_version_snapshot is null
      and internal_location_id is not null
      and internal_location_code_snapshot is not null
      and internal_location_name_snapshot is not null
      and internal_location_record_version_snapshot is not null)
  ),
  check (
    (start_time_local is null and end_time_local is null
      and interval_start_at is null and interval_end_at is null
      and crosses_midnight is null)
    or (start_time_local is not null and end_time_local is not null
      and interval_start_at is not null and interval_end_at is not null
      and interval_end_at > interval_start_at
      and crosses_midnight is not null)
  ),
  exclude using gist (
    allocation_revision_id with =,
    tstzrange(interval_start_at, interval_end_at, '[)') with &&
  ) where (interval_start_at is not null)
);

create index v1_workforce_timesheet_sets_worker_date_idx
  on public.v1_workforce_timesheet_allocation_sets (worker_id, work_date);
create index v1_workforce_timesheet_sets_attendance_idx
  on public.v1_workforce_timesheet_allocation_sets (attendance_day_id);
create index v1_workforce_timesheet_revisions_set_idx
  on public.v1_workforce_timesheet_allocation_revisions (
    allocation_set_id, revision_number desc
  );
create index v1_workforce_timesheet_allocations_revision_idx
  on public.v1_workforce_timesheet_allocations (
    allocation_revision_id, line_number
  );
create index v1_workforce_timesheet_allocations_project_idx
  on public.v1_workforce_timesheet_allocations (project_id, project_scope_id)
  where project_id is not null;
create index v1_workforce_timesheet_allocations_internal_idx
  on public.v1_workforce_timesheet_allocations (internal_location_id)
  where internal_location_id is not null;

alter table public.v1_workforce_timesheet_allocation_sets enable row level security;
alter table public.v1_workforce_timesheet_allocation_revisions enable row level security;
alter table public.v1_workforce_timesheet_allocations enable row level security;

revoke all on table public.v1_workforce_timesheet_allocation_sets
  from public, anon, authenticated;
revoke all on table public.v1_workforce_timesheet_allocation_revisions
  from public, anon, authenticated;
revoke all on table public.v1_workforce_timesheet_allocations
  from public, anon, authenticated;
grant all on table public.v1_workforce_timesheet_allocation_sets to service_role;
grant all on table public.v1_workforce_timesheet_allocation_revisions to service_role;
grant all on table public.v1_workforce_timesheet_allocations to service_role;

create or replace function public.v1_workforce_timesheet_block_immutable_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'V1_WORKFORCE_TIMESHEET_HISTORY_IMMUTABLE'
    using errcode = '42501';
end;
$$;

create or replace function public.v1_workforce_timesheet_guard_set_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id <> old.id
    or new.attendance_day_id <> old.attendance_day_id
    or new.worker_id <> old.worker_id
    or new.work_date <> old.work_date
    or new.created_by_auth_user_id <> old.created_by_auth_user_id
    or new.created_at <> old.created_at
    or new.current_revision_number <> old.current_revision_number + 1
    or new.record_version <> old.record_version + 1
    or new.current_revision_id is null
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_SET_UPDATE_INVALID'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function public.v1_workforce_guard_attendance_allocations()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.v1_workforce_timesheet_allocation_sets allocation_set
    where allocation_set.attendance_day_id = old.id
      and allocation_set.current_state = 'active'
  ) then
    raise exception 'V1_WORKFORCE_ATTENDANCE_ACTIVE_ALLOCATIONS'
      using errcode = '40001';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_timesheet_sets_guard_update
before update on public.v1_workforce_timesheet_allocation_sets
for each row execute function public.v1_workforce_timesheet_guard_set_update();
create trigger v1_workforce_timesheet_sets_no_delete
before delete on public.v1_workforce_timesheet_allocation_sets
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_timesheet_revisions_immutable
before update on public.v1_workforce_timesheet_allocation_revisions
for each row execute function public.v1_workforce_timesheet_block_immutable_update();
create trigger v1_workforce_timesheet_revisions_no_delete
before delete on public.v1_workforce_timesheet_allocation_revisions
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_timesheet_allocations_immutable
before update on public.v1_workforce_timesheet_allocations
for each row execute function public.v1_workforce_timesheet_block_immutable_update();
create trigger v1_workforce_timesheet_allocations_no_delete
before delete on public.v1_workforce_timesheet_allocations
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_attendance_active_allocations_guard
before update of attendance_status, regular_minutes, overtime_minutes
on public.v1_workforce_attendance_days
for each row
when (
  old.attendance_status is distinct from new.attendance_status
  or old.regular_minutes is distinct from new.regular_minutes
  or old.overtime_minutes is distinct from new.overtime_minutes
)
execute function public.v1_workforce_guard_attendance_allocations();

create or replace function public.v1_workforce_timesheet_worker_authority(
  p_capability_key text,
  p_day public.v1_workforce_attendance_days
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_responsibility jsonb;
begin
  if p_capability_key not in ('workforce.view', 'workforce.timesheets.maintain')
    or v_actor is null or p_day.id is null
  then
    return '{}'::jsonb;
  end if;
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(
      p_capability_key, p_day.assignment_project_id_snapshot
    )
  then
    return '{}'::jsonb;
  end if;
  if v_role = 'admin' then
    return jsonb_build_object(
      'authority_kind', 'admin_organization',
      'responsibility_assignment_id', null,
      'scope_kind', 'organization',
      'scope_reference', 'admin:organization',
      'record_version', null
    );
  end if;
  v_responsibility := public.v1_workforce_matching_responsibility(
    v_actor, p_day.worker_id, p_day.work_date,
    p_day.assignment_team_id_snapshot, p_day.assignment_project_id_snapshot,
    p_day.assignment_project_scope_id_snapshot,
    p_day.assignment_internal_location_id_snapshot
  );
  if v_responsibility = '{}'::jsonb then
    return '{}'::jsonb;
  end if;
  return v_responsibility || jsonb_build_object(
    'authority_kind', 'responsibility'
  );
end;
$$;

create or replace function public.v1_workforce_timesheet_target_authority(
  p_capability_key text,
  p_work_date date,
  p_target_kind text,
  p_project_id uuid,
  p_project_scope_id uuid,
  p_internal_location_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_result jsonb;
begin
  if p_capability_key not in ('workforce.view', 'workforce.timesheets.maintain')
    or v_actor is null or p_work_date is null
    or p_target_kind not in ('project_work', 'internal_work')
  then
    return '{}'::jsonb;
  end if;
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(
      p_capability_key,
      case when p_target_kind = 'project_work' then p_project_id else null end
    )
  then
    return '{}'::jsonb;
  end if;
  if v_role = 'admin' then
    return jsonb_build_object(
      'authority_kind', 'admin_organization',
      'responsibility_assignment_id', null,
      'scope_kind', 'organization',
      'scope_reference', 'admin:organization',
      'record_version', null
    );
  end if;
  select jsonb_build_object(
    'authority_kind', 'responsibility',
    'responsibility_assignment_id', responsibility.id,
    'scope_kind', responsibility.scope_kind,
    'scope_reference', responsibility.scope_reference,
    'record_version', responsibility.record_version
  ) into v_result
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.auth_user_id = v_actor
    and responsibility.valid_from <= p_work_date
    and (responsibility.valid_to is null
      or responsibility.valid_to >= p_work_date)
    and (
      responsibility.scope_kind = 'organization'
      or (p_target_kind = 'project_work' and (
        (responsibility.scope_kind = 'project'
          and responsibility.project_id = p_project_id)
        or (responsibility.scope_kind = 'project_scope'
          and responsibility.project_id = p_project_id
          and responsibility.project_scope_id = p_project_scope_id)
      ))
      or (p_target_kind = 'internal_work'
        and responsibility.scope_kind = 'internal_location'
        and responsibility.internal_location_id = p_internal_location_id)
    )
  order by case responsibility.scope_kind
    when 'project_scope' then 0 when 'internal_location' then 1
    when 'project' then 2 else 3 end,
    responsibility.valid_from desc, responsibility.id
  limit 1;
  return coalesce(v_result, '{}'::jsonb);
end;
$$;

create or replace function public.v1_workforce_timesheet_set_json(
  p_allocation_set_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'allocation_set_id', allocation_set.id,
      'attendance_day_id', allocation_set.attendance_day_id,
      'worker_id', allocation_set.worker_id,
      'work_date', allocation_set.work_date,
      'state', allocation_set.current_state,
      'record_version', allocation_set.record_version,
      'current_revision', jsonb_build_object(
        'revision_id', revision.id,
        'revision_number', revision.revision_number,
        'state', revision.revision_state,
        'attendance_record_version_basis',
          revision.attendance_record_version_basis,
        'total_regular_minutes', revision.total_regular_minutes,
        'total_overtime_minutes', revision.total_overtime_minutes,
        'reason', revision.reason,
        'created_by_auth_user_id', revision.created_by_auth_user_id,
        'created_at', revision.created_at
      ),
      'attendance', jsonb_build_object(
        'status', day.attendance_status,
        'regular_minutes', day.regular_minutes,
        'overtime_minutes', day.overtime_minutes,
        'record_version', day.record_version,
        'calendar_timezone', day.calendar_timezone_snapshot
      ),
      'allocations', coalesce((
        select jsonb_agg(jsonb_build_object(
          'allocation_id', allocation.id,
          'line_number', allocation.line_number,
          'target_kind', allocation.target_kind,
          'project', case when allocation.target_kind = 'project_work' then
            jsonb_build_object(
              'project_id', allocation.project_id,
              'project_ref', allocation.project_ref_snapshot,
              'project_name', allocation.project_name_snapshot,
              'project_record_version',
                allocation.project_record_version_snapshot,
              'project_scope_id', allocation.project_scope_id,
              'project_scope_kind', allocation.project_scope_kind_snapshot,
              'project_scope_code', allocation.project_scope_code_snapshot,
              'project_scope_name', allocation.project_scope_name_snapshot,
              'project_scope_record_version',
                allocation.project_scope_record_version_snapshot
            ) else null end,
          'internal_location',
            case when allocation.target_kind = 'internal_work' then
              jsonb_build_object(
                'internal_location_id', allocation.internal_location_id,
                'location_code', allocation.internal_location_code_snapshot,
                'location_name', allocation.internal_location_name_snapshot,
                'department_cost_centre',
                  allocation.department_cost_centre_snapshot,
                'record_version',
                  allocation.internal_location_record_version_snapshot
              ) else null end,
          'activity_task', allocation.activity_task,
          'notes', allocation.notes,
          'regular_minutes', allocation.regular_minutes,
          'overtime_minutes', allocation.overtime_minutes,
          'start_time', allocation.start_time_local,
          'end_time', allocation.end_time_local,
          'crosses_midnight', allocation.crosses_midnight
        ) order by allocation.line_number)
        from public.v1_workforce_timesheet_allocations allocation
        where allocation.allocation_revision_id = revision.id
      ), '[]'::jsonb),
      'created_at', allocation_set.created_at,
      'updated_at', allocation_set.updated_at
    )
    from public.v1_workforce_timesheet_allocation_sets allocation_set
    join public.v1_workforce_timesheet_allocation_revisions revision
      on revision.id = allocation_set.current_revision_id
    join public.v1_workforce_attendance_days day
      on day.id = allocation_set.attendance_day_id
    where allocation_set.id = p_allocation_set_id
  ), '{}'::jsonb);
$$;

create or replace function public.v1_workforce_timesheet_current_targets_authorized(
  p_capability_key text,
  p_allocation_set_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from public.v1_workforce_timesheet_allocation_sets allocation_set
    join public.v1_workforce_timesheet_allocations allocation
      on allocation.allocation_revision_id = allocation_set.current_revision_id
    where allocation_set.id = p_allocation_set_id
      and public.v1_workforce_timesheet_target_authority(
        p_capability_key, allocation_set.work_date, allocation.target_kind,
        allocation.project_id, allocation.project_scope_id,
        allocation.internal_location_id
      ) = '{}'::jsonb
  );
$$;

create or replace function public.v1_get_workforce_timesheet_allocations(
  p_work_date date,
  p_worker_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_sets jsonb;
begin
  if v_actor is null or p_work_date is null then
    raise exception 'V1_WORKFORCE_TIMESHEET_READ_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_TIMESHEET_READ_DENIED'
      using errcode = '42501';
  end if;
  if v_role = 'admin' then
    if not public.v1_current_user_has_capability('workforce.view', null) then
      raise exception 'V1_WORKFORCE_TIMESHEET_READ_DENIED'
        using errcode = '42501';
    end if;
  elsif p_worker_id is null then
    raise exception 'V1_WORKFORCE_TIMESHEET_READ_SCOPE_REQUIRED'
      using errcode = '42501';
  end if;

  select coalesce(jsonb_agg(
    public.v1_workforce_timesheet_set_json(allocation_set.id)
    order by day.worker_name_snapshot, allocation_set.worker_id
  ), '[]'::jsonb) into v_sets
  from public.v1_workforce_timesheet_allocation_sets allocation_set
  join public.v1_workforce_attendance_days day
    on day.id = allocation_set.attendance_day_id
  where allocation_set.work_date = p_work_date
    and (p_worker_id is null or allocation_set.worker_id = p_worker_id)
    and public.v1_workforce_timesheet_worker_authority(
      'workforce.view', day
    ) <> '{}'::jsonb
    and public.v1_workforce_timesheet_current_targets_authorized(
      'workforce.view', allocation_set.id
    );

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t04',
    'actor_auth_user_id', v_actor,
    'work_date', p_work_date,
    'server_time', clock_timestamp(),
    'timesheet_days', v_sets
  );
end;
$$;

create or replace function public.v1_save_workforce_timesheet_allocations(
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
  v_actor uuid := auth.uid();
  v_attendance_day_id uuid;
  v_attendance_version bigint;
  v_reason text;
  v_items jsonb;
  v_item jsonb;
  v_line integer := 0;
  v_regular integer;
  v_overtime integer;
  v_total_regular integer := 0;
  v_total_overtime integer := 0;
  v_target_kind text;
  v_project_id uuid;
  v_project_scope_id uuid;
  v_internal_location_id uuid;
  v_project public.v1_projects%rowtype;
  v_scope public.v1_project_scopes%rowtype;
  v_location public.v1_workforce_internal_locations%rowtype;
  v_start_time time;
  v_end_time time;
  v_interval_start timestamptz;
  v_interval_end timestamptz;
  v_crosses boolean;
  v_start_day_offset integer;
  v_end_day_offset integer;
  v_day public.v1_workforce_attendance_days%rowtype;
  v_set public.v1_workforce_timesheet_allocation_sets%rowtype;
  v_revision public.v1_workforce_timesheet_allocation_revisions%rowtype;
  v_worker_authority jsonb;
  v_target_authority jsonb;
  v_existing_response jsonb;
  v_response jsonb;
  v_audit_project_id uuid;
begin
  if v_actor is null then
    raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array['attendance_day_id', 'attendance_record_version', 'allocations', 'reason'],
    'save_workforce_timesheet_allocations_payload'
  );
  begin
    v_attendance_day_id := nullif(btrim(coalesce(
      p_payload ->> 'attendance_day_id', ''
    )), '')::uuid;
    v_attendance_version := nullif(btrim(coalesce(
      p_payload ->> 'attendance_record_version', ''
    )), '')::bigint;
  exception when invalid_text_representation then
    raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_reason := btrim(coalesce(p_payload ->> 'reason', ''));
  v_items := p_payload -> 'allocations';
  if v_attendance_day_id is null or v_attendance_version is null
    or v_attendance_version < 1
    or v_reason = '' or char_length(v_reason) > 2000
    or jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0
    or (p_expected_version is not null and p_expected_version < 1)
    or p_idempotency_key is null
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
      using errcode = '22023';
  end if;

  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.id = v_attendance_day_id;
  if not found then
    raise exception 'V1_WORKFORCE_TIMESHEET_ATTENDANCE_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'v1_workforce_attendance|' || v_day.worker_id::text || '|' ||
      v_day.work_date::text, 0
    )
  );
  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.id = v_attendance_day_id for update;
  if v_day.record_version <> v_attendance_version then
    raise exception 'V1_WORKFORCE_TIMESHEET_ATTENDANCE_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if v_day.attendance_status <> 'present'
    or v_day.regular_minutes + v_day.overtime_minutes <= 0
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_PRESENT_ATTENDANCE_REQUIRED'
      using errcode = '23514';
  end if;
  v_worker_authority := public.v1_workforce_timesheet_worker_authority(
    'workforce.timesheets.maintain', v_day
  );
  if v_worker_authority = '{}'::jsonb then
    raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;

  select allocation_set.* into v_set
  from public.v1_workforce_timesheet_allocation_sets allocation_set
  where allocation_set.attendance_day_id = v_day.id for update;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_timesheet_allocations', p_idempotency_key,
    jsonb_build_object(
      'payload', p_payload, 'expected_version', p_expected_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_set.id is null then
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_TIMESHEET_SET_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_timesheet_allocation_sets (
      attendance_day_id, worker_id, work_date, current_state,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_day.id, v_day.worker_id, v_day.work_date, 'withdrawn', v_actor, v_actor
    ) returning * into v_set;
  elsif p_expected_version is null or p_expected_version <> v_set.record_version then
    raise exception 'V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  insert into public.v1_workforce_timesheet_allocation_revisions (
    allocation_set_id, revision_number, revision_state,
    attendance_record_version_basis, total_regular_minutes,
    total_overtime_minutes, reason, authority_kind,
    responsibility_assignment_id, responsibility_scope_kind,
    responsibility_scope_reference, responsibility_record_version,
    created_by_auth_user_id, idempotency_key
  ) values (
    v_set.id, v_set.current_revision_number + 1, 'active',
    v_day.record_version, v_day.regular_minutes, v_day.overtime_minutes,
    v_reason, v_worker_authority ->> 'authority_kind',
    nullif(v_worker_authority ->> 'responsibility_assignment_id', '')::uuid,
    v_worker_authority ->> 'scope_kind',
    v_worker_authority ->> 'scope_reference',
    nullif(v_worker_authority ->> 'record_version', '')::bigint,
    v_actor, p_idempotency_key
  ) returning * into v_revision;

  for v_item in select value from jsonb_array_elements(v_items)
  loop
    v_line := v_line + 1;
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
        using errcode = '22023';
    end if;
    perform public.v1_assert_object_keys(
      v_item,
      array[
        'target_kind', 'project_id', 'project_scope_id',
        'internal_location_id', 'activity_task', 'notes', 'regular_minutes',
        'overtime_minutes', 'start_time', 'end_time'
      ],
      'save_workforce_timesheet_allocation_item'
    );
    if jsonb_typeof(v_item -> 'regular_minutes') <> 'number'
      or jsonb_typeof(v_item -> 'overtime_minutes') <> 'number'
      or (v_item -> 'regular_minutes')::text !~ '^(0|[1-9][0-9]*)$'
      or (v_item -> 'overtime_minutes')::text !~ '^(0|[1-9][0-9]*)$'
    then
      raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
        using errcode = '22023';
    end if;
    begin
      v_regular := (v_item ->> 'regular_minutes')::integer;
      v_overtime := (v_item ->> 'overtime_minutes')::integer;
      v_project_id := nullif(btrim(coalesce(v_item ->> 'project_id', '')), '')::uuid;
      v_project_scope_id := nullif(btrim(coalesce(
        v_item ->> 'project_scope_id', ''
      )), '')::uuid;
      v_internal_location_id := nullif(btrim(coalesce(
        v_item ->> 'internal_location_id', ''
      )), '')::uuid;
    exception when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
        using errcode = '22023';
    end;
    v_target_kind := btrim(coalesce(v_item ->> 'target_kind', ''));
    if v_regular < 0 or v_overtime < 0
      or v_regular + v_overtime between 0 and 0
      or v_regular > 1440 or v_overtime > 1440
      or v_regular + v_overtime > 1440
      or char_length(coalesce(v_item ->> 'activity_task', '')) > 500
      or char_length(coalesce(v_item ->> 'notes', '')) > 2000
      or (v_target_kind = 'project_work' and (
        v_project_id is null or v_project_scope_id is null
        or v_internal_location_id is not null))
      or (v_target_kind = 'internal_work' and (
        v_internal_location_id is null or v_project_id is not null
        or v_project_scope_id is not null))
      or v_target_kind not in ('project_work', 'internal_work')
    then
      raise exception 'V1_WORKFORCE_TIMESHEET_INPUT_INVALID'
        using errcode = '22023';
    end if;

    v_start_time := null;
    v_end_time := null;
    v_interval_start := null;
    v_interval_end := null;
    v_crosses := null;
    if (v_item ? 'start_time') <> (v_item ? 'end_time')
      or ((v_item -> 'start_time') is null) <> ((v_item -> 'end_time') is null)
      or (v_item ? 'start_time' and (
        jsonb_typeof(v_item -> 'start_time') <> 'string'
        or jsonb_typeof(v_item -> 'end_time') <> 'string'))
    then
      raise exception 'V1_WORKFORCE_TIMESHEET_TIME_RANGE_INVALID'
        using errcode = '22023';
    end if;
    if v_item ? 'start_time' then
      begin
        v_start_time := (v_item ->> 'start_time')::time;
        v_end_time := (v_item ->> 'end_time')::time;
      exception when invalid_datetime_format then
        raise exception 'V1_WORKFORCE_TIMESHEET_TIME_RANGE_INVALID'
          using errcode = '22023';
      end;
      if v_start_time = v_end_time then
        raise exception 'V1_WORKFORCE_TIMESHEET_TIME_RANGE_INVALID'
          using errcode = '22023';
      end if;
      v_crosses := v_end_time < v_start_time;
      v_start_day_offset := case
        when coalesce(v_day.shift_crosses_midnight_snapshot, false)
          and v_day.shift_start_time_snapshot is not null
          and v_start_time < v_day.shift_start_time_snapshot
        then 1 else 0 end;
      v_end_day_offset := v_start_day_offset + case
        when v_crosses then 1 else 0 end;
      v_interval_start := (
        v_day.work_date + v_start_day_offset + v_start_time
      )
        at time zone v_day.calendar_timezone_snapshot;
      v_interval_end := (
        v_day.work_date + v_end_day_offset + v_end_time
      ) at time zone v_day.calendar_timezone_snapshot;
    end if;

    if v_target_kind = 'project_work' then
      select project.* into v_project
      from public.v1_projects project
      where project.id = v_project_id and project.state = 'active';
      select scope.* into v_scope
      from public.v1_project_scopes scope
      where scope.id = v_project_scope_id
        and scope.project_id = v_project_id and scope.is_active;
      if v_project.id is null or v_scope.id is null then
        raise exception 'V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED'
          using errcode = '23514';
      end if;
    else
      select location.* into v_location
      from public.v1_workforce_internal_locations location
      where location.id = v_internal_location_id and location.is_active;
      if v_location.id is null then
        raise exception 'V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED'
          using errcode = '23514';
      end if;
    end if;

    v_target_authority := public.v1_workforce_timesheet_target_authority(
      'workforce.timesheets.maintain', v_day.work_date, v_target_kind,
      v_project_id, v_project_scope_id, v_internal_location_id
    );
    if v_target_authority = '{}'::jsonb then
      raise exception 'V1_WORKFORCE_TIMESHEET_TARGET_DENIED'
        using errcode = '42501';
    end if;

    insert into public.v1_workforce_timesheet_allocations (
      allocation_revision_id, line_number, target_kind,
      project_id, project_ref_snapshot, project_name_snapshot,
      project_record_version_snapshot, project_scope_id,
      project_scope_kind_snapshot, project_scope_code_snapshot,
      project_scope_name_snapshot, project_scope_record_version_snapshot,
      internal_location_id, internal_location_code_snapshot,
      internal_location_name_snapshot, department_cost_centre_snapshot,
      internal_location_record_version_snapshot, target_authority_kind,
      target_responsibility_assignment_id,
      target_responsibility_scope_kind,
      target_responsibility_scope_reference,
      target_responsibility_record_version, activity_task, notes,
      regular_minutes, overtime_minutes, start_time_local, end_time_local,
      interval_start_at, interval_end_at, crosses_midnight,
      created_by_auth_user_id
    ) values (
      v_revision.id, v_line, v_target_kind,
      v_project_id, v_project.project_ref, v_project.name,
      v_project.record_version, v_project_scope_id, v_scope.scope_kind,
      v_scope.scope_code, v_scope.name, v_scope.record_version,
      v_internal_location_id, v_location.location_code,
      v_location.location_name, v_location.department,
      v_location.record_version, v_target_authority ->> 'authority_kind',
      nullif(v_target_authority ->> 'responsibility_assignment_id', '')::uuid,
      v_target_authority ->> 'scope_kind',
      v_target_authority ->> 'scope_reference',
      nullif(v_target_authority ->> 'record_version', '')::bigint,
      nullif(btrim(coalesce(v_item ->> 'activity_task', '')), ''),
      nullif(btrim(coalesce(v_item ->> 'notes', '')), ''),
      v_regular, v_overtime, v_start_time, v_end_time,
      v_interval_start, v_interval_end, v_crosses, v_actor
    );
    v_total_regular := v_total_regular + v_regular;
    v_total_overtime := v_total_overtime + v_overtime;
    v_project := null;
    v_scope := null;
    v_location := null;
  end loop;

  if v_total_regular <> v_day.regular_minutes
    or v_total_overtime <> v_day.overtime_minutes
    or v_total_regular + v_total_overtime > 1440
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_MINUTES_MISMATCH'
      using errcode = '23514';
  end if;

  update public.v1_workforce_timesheet_allocation_sets set
    current_revision_id = v_revision.id,
    current_revision_number = v_revision.revision_number,
    current_state = 'active',
    record_version = record_version + 1,
    updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where id = v_set.id returning * into v_set;

  select case when count(distinct allocation.project_id) = 1
    then min(allocation.project_id::text)::uuid else null end
    into v_audit_project_id
  from public.v1_workforce_timesheet_allocations allocation
  where allocation.allocation_revision_id = v_revision.id;
  v_response := jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t04',
    'timesheet_day', public.v1_workforce_timesheet_set_json(v_set.id)
  );
  perform public.v1_write_audit_event(
    'workforce_timesheet_allocations_saved', 'workforce_timesheet_allocation_set',
    v_set.id, v_audit_project_id, null,
    jsonb_build_object(
      'revision_id', v_revision.id,
      'revision_number', v_revision.revision_number,
      'attendance_day_id', v_day.id,
      'attendance_record_version_basis', v_day.record_version,
      'regular_minutes', v_total_regular,
      'overtime_minutes', v_total_overtime,
      'allocation_count', v_line,
      'record_version', v_set.record_version
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_timesheet_allocations', p_idempotency_key, v_response
  );
  return v_response;
exception
  when exclusion_violation then
    raise exception 'V1_WORKFORCE_TIMESHEET_TIME_OVERLAP'
      using errcode = '23P01';
end;
$$;

create or replace function public.v1_withdraw_workforce_timesheet_allocations(
  p_attendance_day_id uuid,
  p_reason text,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_reason text := btrim(coalesce(p_reason, ''));
  v_day public.v1_workforce_attendance_days%rowtype;
  v_set public.v1_workforce_timesheet_allocation_sets%rowtype;
  v_revision public.v1_workforce_timesheet_allocation_revisions%rowtype;
  v_authority jsonb;
  v_existing_response jsonb;
  v_response jsonb;
begin
  if v_actor is null or p_attendance_day_id is null
    or v_reason = '' or char_length(v_reason) > 2000
    or p_expected_version is null or p_expected_version < 1
    or p_idempotency_key is null
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_WITHDRAW_INVALID'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.id = p_attendance_day_id;
  if not found then
    raise exception 'V1_WORKFORCE_TIMESHEET_ATTENDANCE_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'v1_workforce_attendance|' || v_day.worker_id::text || '|' ||
      v_day.work_date::text, 0
    )
  );
  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.id = p_attendance_day_id for update;
  select allocation_set.* into v_set
  from public.v1_workforce_timesheet_allocation_sets allocation_set
  where allocation_set.attendance_day_id = v_day.id for update;
  if not found then
    raise exception 'V1_WORKFORCE_TIMESHEET_SET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  v_authority := public.v1_workforce_timesheet_worker_authority(
    'workforce.timesheets.maintain', v_day
  );
  if v_authority = '{}'::jsonb
    or not public.v1_workforce_timesheet_current_targets_authorized(
      'workforce.timesheets.maintain', v_set.id
    )
  then
    raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_withdraw_workforce_timesheet_allocations', p_idempotency_key,
    jsonb_build_object(
      'attendance_day_id', p_attendance_day_id,
      'reason', p_reason,
      'expected_version', p_expected_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;
  if v_set.current_state <> 'active' then
    raise exception 'V1_WORKFORCE_TIMESHEET_NOT_ACTIVE'
      using errcode = '23514';
  end if;
  if p_expected_version <> v_set.record_version then
    raise exception 'V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  insert into public.v1_workforce_timesheet_allocation_revisions (
    allocation_set_id, revision_number, revision_state,
    attendance_record_version_basis, total_regular_minutes,
    total_overtime_minutes, reason, authority_kind,
    responsibility_assignment_id, responsibility_scope_kind,
    responsibility_scope_reference, responsibility_record_version,
    created_by_auth_user_id, idempotency_key
  ) values (
    v_set.id, v_set.current_revision_number + 1, 'withdrawn',
    v_day.record_version, 0, 0, v_reason,
    v_authority ->> 'authority_kind',
    nullif(v_authority ->> 'responsibility_assignment_id', '')::uuid,
    v_authority ->> 'scope_kind', v_authority ->> 'scope_reference',
    nullif(v_authority ->> 'record_version', '')::bigint,
    v_actor, p_idempotency_key
  ) returning * into v_revision;
  update public.v1_workforce_timesheet_allocation_sets set
    current_revision_id = v_revision.id,
    current_revision_number = v_revision.revision_number,
    current_state = 'withdrawn',
    record_version = record_version + 1,
    updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where id = v_set.id returning * into v_set;
  v_response := jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t04',
    'timesheet_day', public.v1_workforce_timesheet_set_json(v_set.id)
  );
  perform public.v1_write_audit_event(
    'workforce_timesheet_allocations_withdrawn',
    'workforce_timesheet_allocation_set', v_set.id,
    v_day.assignment_project_id_snapshot, null,
    jsonb_build_object(
      'revision_id', v_revision.id,
      'revision_number', v_revision.revision_number,
      'attendance_day_id', v_day.id,
      'record_version', v_set.record_version,
      'state', 'withdrawn'
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_withdraw_workforce_timesheet_allocations',
    p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

update public.v1_capability_catalog
set status = 'operational', authorization_mode = 'enforced',
    is_assignable = true
where capability_key = 'workforce.timesheets.maintain';

do $workforce_t04_capability_contract$
begin
  if (
    select count(*)
    from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and catalog.status = 'operational'
      and catalog.authorization_mode = 'enforced'
      and catalog.is_assignable
  ) <> 3
  or exists (
    select 1
    from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and catalog.capability_key not in (
        'workforce.view', 'workforce.attendance.maintain',
        'workforce.timesheets.maintain'
      )
      and (
        catalog.status <> 'planned'
        or catalog.authorization_mode <> 'shadow'
        or catalog.is_assignable
      )
  ) then
    raise exception 'V1_WORKFORCE_T04_CAPABILITY_CUTOVER_CONFLICT'
      using errcode = '23514';
  end if;
end;
$workforce_t04_capability_contract$;

revoke all on function public.v1_workforce_timesheet_block_immutable_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_timesheet_guard_set_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_attendance_allocations()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_timesheet_worker_authority(
  text,public.v1_workforce_attendance_days
) from public, anon, authenticated;
revoke all on function public.v1_workforce_timesheet_target_authority(
  text,date,text,uuid,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_timesheet_set_json(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_timesheet_current_targets_authorized(
  text,uuid
) from public, anon, authenticated;
revoke all on function public.v1_get_workforce_timesheet_allocations(date,uuid)
  from public, anon;
revoke all on function public.v1_save_workforce_timesheet_allocations(
  jsonb,bigint,uuid
) from public, anon;
revoke all on function public.v1_withdraw_workforce_timesheet_allocations(
  uuid,text,bigint,uuid
) from public, anon;

grant execute on function public.v1_get_workforce_timesheet_allocations(
  date,uuid
) to authenticated;
grant execute on function public.v1_save_workforce_timesheet_allocations(
  jsonb,bigint,uuid
) to authenticated;
grant execute on function public.v1_withdraw_workforce_timesheet_allocations(
  uuid,text,bigint,uuid
) to authenticated;

commit;
