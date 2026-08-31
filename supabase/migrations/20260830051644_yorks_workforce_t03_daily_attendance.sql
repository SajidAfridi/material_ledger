-- Yorks Workforce T03: protected daily attendance authority.
--
-- This additive, route-less slice promotes only workforce.view and
-- workforce.attendance.maintain. It creates no allocation, timesheet, report,
-- notification, UI, legacy copy/dual-write, feature enablement or deployment.

begin;

create table public.v1_workforce_attendance_days (
  id uuid primary key default gen_random_uuid(),
  worker_id uuid not null
    references public.v1_workforce_workers (id) on delete restrict,
  work_date date not null,
  attendance_status text not null check (attendance_status in (
    'present', 'absent', 'annual_leave', 'sick_leave', 'official_leave',
    'unpaid_leave', 'not_entered'
  )),
  regular_minutes integer not null default 0 check (
    regular_minutes between 0 and 1440
  ),
  overtime_minutes integer not null default 0 check (
    overtime_minutes between 0 and 1440
  ),
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),

  -- Retained worker and effective assignment facts. These columns are written
  -- only on first creation and never rebased by the correction command.
  worker_number_snapshot text not null,
  worker_name_snapshot text not null,
  worker_joining_date_snapshot date not null,
  worker_leaving_date_snapshot date,
  worker_status_snapshot text not null check (
    worker_status_snapshot = 'active'
  ),
  assignment_id_snapshot uuid not null,
  assignment_kind_snapshot text not null check (
    assignment_kind_snapshot in ('primary', 'temporary')
  ),
  assignment_team_id_snapshot uuid not null,
  assignment_team_name_snapshot text not null,
  assignment_supervisor_auth_user_id_snapshot uuid,
  assignment_supervisor_name_snapshot text,
  assignment_project_id_snapshot uuid,
  assignment_project_ref_snapshot text,
  assignment_project_name_snapshot text,
  assignment_project_scope_id_snapshot uuid,
  assignment_project_scope_name_snapshot text,
  assignment_internal_location_id_snapshot uuid,
  assignment_internal_location_name_snapshot text,
  assignment_valid_from_snapshot date not null,
  assignment_valid_to_snapshot date,
  assignment_record_version_snapshot bigint not null check (
    assignment_record_version_snapshot > 0
  ),

  -- Initial command authority is retained separately from later audit actors.
  initial_authority_kind text not null check (
    initial_authority_kind in ('admin_organization', 'responsibility')
  ),
  initial_responsibility_assignment_id uuid,
  initial_responsibility_scope_kind text not null check (
    initial_responsibility_scope_kind in (
      'organization', 'worker', 'team', 'project', 'project_scope',
      'internal_location'
    )
  ),
  initial_responsibility_scope_reference text not null,
  initial_responsibility_record_version bigint,

  -- Exact retained calendar/shift/day-type facts for this work date.
  team_schedule_link_id_snapshot uuid not null,
  team_schedule_record_version_snapshot bigint not null check (
    team_schedule_record_version_snapshot > 0
  ),
  calendar_id_snapshot uuid not null,
  calendar_code_snapshot text not null,
  calendar_name_snapshot text not null,
  calendar_timezone_snapshot text not null,
  calendar_record_version_snapshot bigint not null check (
    calendar_record_version_snapshot > 0
  ),
  calendar_date_override_id_snapshot uuid,
  calendar_date_override_version_snapshot bigint,
  calendar_override_kind_snapshot text,
  calendar_exception_name_snapshot text,
  day_type_source_snapshot text not null check (
    day_type_source_snapshot in ('weekday', 'date_override')
  ),
  iso_weekday_snapshot smallint not null check (
    iso_weekday_snapshot between 1 and 7
  ),
  day_type_snapshot text not null check (day_type_snapshot in (
    'regular_working_day', 'weekly_off', 'public_holiday', 'site_closed',
    'not_scheduled'
  )),
  scheduled_minutes_snapshot integer not null check (
    scheduled_minutes_snapshot between 0 and 1440
  ),
  break_minutes_snapshot integer not null check (
    break_minutes_snapshot between 0 and 1440
  ),
  shift_template_id_snapshot uuid,
  shift_code_snapshot text,
  shift_name_snapshot text,
  shift_kind_snapshot text,
  shift_start_time_snapshot time,
  shift_end_time_snapshot time,
  shift_scheduled_minutes_snapshot integer,
  shift_break_minutes_snapshot integer,
  shift_crosses_midnight_snapshot boolean,
  shift_work_date_basis_snapshot text,
  shift_record_version_snapshot bigint,

  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),

  unique (worker_id, work_date),
  check (regular_minutes + overtime_minutes <= 1440),
  check (
    (attendance_status = 'present'
      and regular_minutes + overtime_minutes > 0)
    or (attendance_status <> 'present'
      and regular_minutes = 0 and overtime_minutes = 0)
  ),
  check (
    (initial_authority_kind = 'admin_organization'
      and initial_responsibility_assignment_id is null
      and initial_responsibility_scope_kind = 'organization'
      and initial_responsibility_record_version is null)
    or (initial_authority_kind = 'responsibility'
      and initial_responsibility_assignment_id is not null
      and initial_responsibility_record_version > 0)
  ),
  check (
    (day_type_source_snapshot = 'weekday'
      and calendar_date_override_id_snapshot is null
      and calendar_date_override_version_snapshot is null
      and calendar_override_kind_snapshot is null
      and calendar_exception_name_snapshot is null)
    or (day_type_source_snapshot = 'date_override'
      and calendar_date_override_id_snapshot is not null
      and calendar_date_override_version_snapshot > 0
      and calendar_override_kind_snapshot is not null
      and calendar_exception_name_snapshot is not null)
  ),
  check (scheduled_minutes_snapshot + break_minutes_snapshot <= 1440),
  check (
    (day_type_snapshot = 'regular_working_day'
      and scheduled_minutes_snapshot > 0)
    or (day_type_snapshot <> 'regular_working_day'
      and scheduled_minutes_snapshot = 0 and break_minutes_snapshot = 0)
  ),
  check (
    (shift_template_id_snapshot is null
      and shift_code_snapshot is null
      and shift_name_snapshot is null
      and shift_kind_snapshot is null
      and shift_start_time_snapshot is null
      and shift_end_time_snapshot is null
      and shift_scheduled_minutes_snapshot is null
      and shift_break_minutes_snapshot is null
      and shift_crosses_midnight_snapshot is null
      and shift_work_date_basis_snapshot is null
      and shift_record_version_snapshot is null)
    or (shift_template_id_snapshot is not null
      and shift_code_snapshot is not null
      and shift_name_snapshot is not null
      and shift_kind_snapshot is not null
      and shift_scheduled_minutes_snapshot between 1 and 1440
      and shift_break_minutes_snapshot between 0 and 1440
      and shift_crosses_midnight_snapshot is not null
      and shift_work_date_basis_snapshot = 'shift_start_date'
      and shift_record_version_snapshot > 0
      and ((shift_start_time_snapshot is null
          and shift_end_time_snapshot is null)
        or (shift_start_time_snapshot is not null
          and shift_end_time_snapshot is not null)))
  )
);

create index v1_workforce_attendance_days_date_worker_idx
  on public.v1_workforce_attendance_days (work_date, worker_id);
create index v1_workforce_attendance_days_project_date_idx
  on public.v1_workforce_attendance_days (
    assignment_project_id_snapshot, work_date, worker_id
  ) where assignment_project_id_snapshot is not null;
create index v1_workforce_attendance_days_team_date_idx
  on public.v1_workforce_attendance_days (
    assignment_team_id_snapshot, work_date, worker_id
  );

alter table public.v1_workforce_attendance_days enable row level security;
revoke all on table public.v1_workforce_attendance_days
  from public, anon, authenticated;
grant all on table public.v1_workforce_attendance_days to service_role;

create trigger v1_workforce_attendance_days_no_delete
before delete on public.v1_workforce_attendance_days
for each row execute function public.v1_workforce_block_delete();

create or replace function public.v1_workforce_guard_attendance_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    to_jsonb(new) - array[
      'attendance_status', 'regular_minutes', 'overtime_minutes', 'reason',
      'record_version', 'updated_by_auth_user_id', 'updated_at'
    ]::text[]
  ) is distinct from (
    to_jsonb(old) - array[
      'attendance_status', 'regular_minutes', 'overtime_minutes', 'reason',
      'record_version', 'updated_by_auth_user_id', 'updated_at'
    ]::text[]
  ) or new.record_version <> old.record_version + 1 then
    raise exception 'V1_WORKFORCE_ATTENDANCE_CONTEXT_IMMUTABLE'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_attendance_days_history_guard
before update on public.v1_workforce_attendance_days
for each row execute function public.v1_workforce_guard_attendance_history();

create or replace function public.v1_workforce_attendance_schedule_context(
  p_team_id uuid,
  p_work_date date
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with schedule as (
    select
      link.id as team_schedule_link_id,
      link.record_version as team_schedule_record_version,
      calendar.id as calendar_id,
      calendar.calendar_code,
      calendar.calendar_name,
      calendar.timezone_name,
      calendar.record_version as calendar_record_version,
      calendar.standard_scheduled_minutes,
      calendar.break_minutes as calendar_break_minutes,
      weekday.iso_weekday,
      weekday.day_type as weekday_day_type,
      override.id as override_id,
      override.record_version as override_record_version,
      override.override_kind,
      override.exception_name,
      override.day_type as override_day_type,
      override.scheduled_minutes as override_scheduled_minutes,
      override.break_minutes as override_break_minutes,
      coalesce(override.shift_template_id, link.shift_template_id) as shift_id
    from public.v1_workforce_team_schedule_links link
    join public.v1_workforce_calendars calendar
      on calendar.id = link.calendar_id
    join public.v1_workforce_calendar_weekdays weekday
      on weekday.calendar_id = calendar.id
      and weekday.iso_weekday = extract(isodow from p_work_date)::smallint
    left join public.v1_workforce_calendar_dates override
      on override.calendar_id = calendar.id
      and override.calendar_date = p_work_date
      and override.is_active
    where link.team_id = p_team_id
      and link.valid_from <= p_work_date
      and (link.valid_to is null or link.valid_to >= p_work_date)
      and calendar.valid_from <= p_work_date
      and (calendar.valid_to is null or calendar.valid_to >= p_work_date)
    order by link.valid_from desc, link.id
    limit 1
  )
  select coalesce((
    select jsonb_build_object(
      'team_schedule_link_id', schedule.team_schedule_link_id,
      'team_schedule_record_version', schedule.team_schedule_record_version,
      'calendar_id', schedule.calendar_id,
      'calendar_code', schedule.calendar_code,
      'calendar_name', schedule.calendar_name,
      'calendar_timezone', schedule.timezone_name,
      'calendar_record_version', schedule.calendar_record_version,
      'calendar_date_override_id', schedule.override_id,
      'calendar_date_override_version', schedule.override_record_version,
      'calendar_override_kind', schedule.override_kind,
      'calendar_exception_name', schedule.exception_name,
      'day_type_source', case when schedule.override_id is null
        then 'weekday' else 'date_override' end,
      'iso_weekday', schedule.iso_weekday,
      'day_type', coalesce(
        schedule.override_day_type, schedule.weekday_day_type
      ),
      'scheduled_minutes', case
        when schedule.override_id is not null
          then schedule.override_scheduled_minutes
        when schedule.weekday_day_type <> 'regular_working_day' then 0
        when shift.id is not null then shift.scheduled_minutes
        else schedule.standard_scheduled_minutes
      end,
      'break_minutes', case
        when schedule.override_id is not null
          then schedule.override_break_minutes
        when schedule.weekday_day_type <> 'regular_working_day' then 0
        when shift.id is not null then shift.break_minutes
        else schedule.calendar_break_minutes
      end,
      'shift_template_id', shift.id,
      'shift_code', shift.shift_code,
      'shift_name', shift.shift_name,
      'shift_kind', shift.shift_kind,
      'shift_start_time', shift.start_time,
      'shift_end_time', shift.end_time,
      'shift_scheduled_minutes', shift.scheduled_minutes,
      'shift_break_minutes', shift.break_minutes,
      'shift_crosses_midnight', shift.crosses_midnight,
      'shift_work_date_basis', shift.work_date_basis,
      'shift_record_version', shift.record_version
    )
    from schedule
    left join public.v1_workforce_shift_templates shift
      on shift.id = schedule.shift_id
  ), '{}'::jsonb);
$$;

create or replace function public.v1_workforce_matching_responsibility(
  p_auth_user_id uuid,
  p_worker_id uuid,
  p_work_date date,
  p_team_id uuid,
  p_project_id uuid,
  p_project_scope_id uuid,
  p_internal_location_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'responsibility_assignment_id', responsibility.id,
      'scope_kind', responsibility.scope_kind,
      'scope_reference', responsibility.scope_reference,
      'record_version', responsibility.record_version
    )
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = p_auth_user_id
      and responsibility.valid_from <= p_work_date
      and (responsibility.valid_to is null
        or responsibility.valid_to >= p_work_date)
      and (
        responsibility.scope_kind = 'organization'
        or (responsibility.scope_kind = 'worker'
          and responsibility.worker_id = p_worker_id)
        or (responsibility.scope_kind = 'team'
          and responsibility.team_id = p_team_id)
        or (responsibility.scope_kind = 'project'
          and responsibility.project_id = p_project_id)
        or (responsibility.scope_kind = 'project_scope'
          and responsibility.project_id = p_project_id
          and responsibility.project_scope_id = p_project_scope_id)
        or (responsibility.scope_kind = 'internal_location'
          and responsibility.internal_location_id = p_internal_location_id)
      )
    order by case responsibility.scope_kind
      when 'worker' then 0
      when 'project_scope' then 1
      when 'team' then 2
      when 'internal_location' then 3
      when 'project' then 4
      else 5 end,
      responsibility.valid_from desc,
      responsibility.id
    limit 1
  ), '{}'::jsonb);
$$;

create or replace function public.v1_workforce_attendance_authority_context(
  p_capability_key text,
  p_worker_id uuid,
  p_work_date date,
  p_team_id uuid,
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
  v_responsibility jsonb;
begin
  if p_capability_key not in (
    'workforce.view', 'workforce.attendance.maintain'
  ) or v_actor is null then
    return '{}'::jsonb;
  end if;
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = ''
    or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(
      p_capability_key, p_project_id
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
    v_actor, p_worker_id, p_work_date, p_team_id, p_project_id,
    p_project_scope_id, p_internal_location_id
  );
  if v_responsibility = '{}'::jsonb then
    return '{}'::jsonb;
  end if;
  return v_responsibility || jsonb_build_object(
    'authority_kind', 'responsibility'
  );
end;
$$;

create or replace function public.v1_workforce_attendance_day_json(
  p_attendance_day_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'attendance_day_id', day.id,
      'worker_id', day.worker_id,
      'worker_number', day.worker_number_snapshot,
      'worker_name', day.worker_name_snapshot,
      'worker_joining_date', day.worker_joining_date_snapshot,
      'worker_leaving_date', day.worker_leaving_date_snapshot,
      'worker_status_at_creation', day.worker_status_snapshot,
      'work_date', day.work_date,
      'attendance_status', day.attendance_status,
      'regular_minutes', day.regular_minutes,
      'overtime_minutes', day.overtime_minutes,
      'reason', day.reason,
      'record_version', day.record_version,
      'created_at', day.created_at,
      'updated_at', day.updated_at,
      'assignment', jsonb_build_object(
        'assignment_id', day.assignment_id_snapshot,
        'assignment_kind', day.assignment_kind_snapshot,
        'team_id', day.assignment_team_id_snapshot,
        'team_name', day.assignment_team_name_snapshot,
        'supervisor_auth_user_id',
          day.assignment_supervisor_auth_user_id_snapshot,
        'supervisor_name', day.assignment_supervisor_name_snapshot,
        'project_id', day.assignment_project_id_snapshot,
        'project_ref', day.assignment_project_ref_snapshot,
        'project_name', day.assignment_project_name_snapshot,
        'project_scope_id', day.assignment_project_scope_id_snapshot,
        'project_scope_name', day.assignment_project_scope_name_snapshot,
        'internal_location_id', day.assignment_internal_location_id_snapshot,
        'internal_location_name',
          day.assignment_internal_location_name_snapshot,
        'valid_from', day.assignment_valid_from_snapshot,
        'valid_to', day.assignment_valid_to_snapshot,
        'record_version', day.assignment_record_version_snapshot
      ),
      'initial_authority', jsonb_build_object(
        'authority_kind', day.initial_authority_kind,
        'responsibility_assignment_id',
          day.initial_responsibility_assignment_id,
        'scope_kind', day.initial_responsibility_scope_kind,
        'scope_reference', day.initial_responsibility_scope_reference,
        'record_version', day.initial_responsibility_record_version
      ),
      'schedule', jsonb_build_object(
        'team_schedule_link_id', day.team_schedule_link_id_snapshot,
        'team_schedule_record_version',
          day.team_schedule_record_version_snapshot,
        'calendar_id', day.calendar_id_snapshot,
        'calendar_code', day.calendar_code_snapshot,
        'calendar_name', day.calendar_name_snapshot,
        'calendar_timezone', day.calendar_timezone_snapshot,
        'calendar_record_version', day.calendar_record_version_snapshot,
        'calendar_date_override_id',
          day.calendar_date_override_id_snapshot,
        'calendar_date_override_version',
          day.calendar_date_override_version_snapshot,
        'calendar_override_kind', day.calendar_override_kind_snapshot,
        'calendar_exception_name', day.calendar_exception_name_snapshot,
        'day_type_source', day.day_type_source_snapshot,
        'iso_weekday', day.iso_weekday_snapshot,
        'day_type', day.day_type_snapshot,
        'scheduled_minutes', day.scheduled_minutes_snapshot,
        'break_minutes', day.break_minutes_snapshot,
        'shift_template_id', day.shift_template_id_snapshot,
        'shift_code', day.shift_code_snapshot,
        'shift_name', day.shift_name_snapshot,
        'shift_kind', day.shift_kind_snapshot,
        'shift_start_time', day.shift_start_time_snapshot,
        'shift_end_time', day.shift_end_time_snapshot,
        'shift_scheduled_minutes', day.shift_scheduled_minutes_snapshot,
        'shift_break_minutes', day.shift_break_minutes_snapshot,
        'shift_crosses_midnight', day.shift_crosses_midnight_snapshot,
        'shift_work_date_basis', day.shift_work_date_basis_snapshot,
        'shift_record_version', day.shift_record_version_snapshot
      )
    )
    from public.v1_workforce_attendance_days day
    where day.id = p_attendance_day_id
  ), '{}'::jsonb);
$$;

create or replace function public.v1_get_workforce_attendance(
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
  v_assignment jsonb;
  v_authority jsonb;
  v_days jsonb;
begin
  if v_actor is null or p_work_date is null then
    raise exception 'V1_WORKFORCE_ATTENDANCE_READ_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  v_role := public.v1_permission_exact_role(v_actor);
  if not public.v1_current_actor_is_active() or v_role = '' then
    raise exception 'V1_WORKFORCE_ATTENDANCE_READ_DENIED'
      using errcode = '42501';
  end if;
  if v_role = 'admin' then
    if not public.v1_current_user_has_capability('workforce.view', null) then
      raise exception 'V1_WORKFORCE_ATTENDANCE_READ_DENIED'
        using errcode = '42501';
    end if;
  elsif p_worker_id is null then
    raise exception 'V1_WORKFORCE_ATTENDANCE_READ_SCOPE_REQUIRED'
      using errcode = '42501';
  else
    select public.v1_workforce_attendance_authority_context(
      'workforce.view', day.worker_id, day.work_date,
      day.assignment_team_id_snapshot, day.assignment_project_id_snapshot,
      day.assignment_project_scope_id_snapshot,
      day.assignment_internal_location_id_snapshot
    ) into v_authority
    from public.v1_workforce_attendance_days day
    where day.worker_id = p_worker_id and day.work_date = p_work_date;
    if v_authority is null then
      v_assignment := public.v1_workforce_effective_assignment(
        p_worker_id, p_work_date
      );
      if v_assignment = '{}'::jsonb then
        raise exception 'V1_WORKFORCE_ATTENDANCE_READ_DENIED'
          using errcode = '42501';
      end if;
      v_authority := public.v1_workforce_attendance_authority_context(
        'workforce.view', p_worker_id, p_work_date,
        nullif(v_assignment ->> 'team_id', '')::uuid,
        nullif(v_assignment ->> 'project_id', '')::uuid,
        nullif(v_assignment ->> 'project_scope_id', '')::uuid,
        nullif(v_assignment ->> 'internal_location_id', '')::uuid
      );
    end if;
    if coalesce(v_authority, '{}'::jsonb) = '{}'::jsonb then
      raise exception 'V1_WORKFORCE_ATTENDANCE_READ_DENIED'
        using errcode = '42501';
    end if;
  end if;

  select coalesce(jsonb_agg(
    public.v1_workforce_attendance_day_json(day.id)
    order by day.worker_name_snapshot, day.worker_id
  ), '[]'::jsonb) into v_days
  from public.v1_workforce_attendance_days day
  where day.work_date = p_work_date
    and (p_worker_id is null or day.worker_id = p_worker_id)
    and public.v1_workforce_attendance_authority_context(
      'workforce.view', day.worker_id, day.work_date,
      day.assignment_team_id_snapshot, day.assignment_project_id_snapshot,
      day.assignment_project_scope_id_snapshot,
      day.assignment_internal_location_id_snapshot
    ) <> '{}'::jsonb;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t03',
    'actor_auth_user_id', v_actor,
    'work_date', p_work_date,
    'server_time', clock_timestamp(),
    'days', v_days
  );
end;
$$;

create or replace function public.v1_save_workforce_attendance_day(
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
  v_worker_id uuid;
  v_work_date date;
  v_status text;
  v_regular integer;
  v_overtime integer;
  v_reason text;
  v_worker public.v1_workforce_workers%rowtype;
  v_day public.v1_workforce_attendance_days%rowtype;
  v_assignment jsonb;
  v_schedule jsonb;
  v_authority jsonb;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  if v_actor is null then
    raise exception 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'worker_id', 'work_date', 'attendance_status', 'regular_minutes',
      'overtime_minutes', 'reason'
    ],
    'save_workforce_attendance_day_payload'
  );
  begin
    v_worker_id := nullif(btrim(coalesce(
      p_payload ->> 'worker_id', ''
    )), '')::uuid;
    v_work_date := nullif(btrim(coalesce(
      p_payload ->> 'work_date', ''
    )), '')::date;
    v_regular := nullif(btrim(coalesce(
      p_payload ->> 'regular_minutes', ''
    )), '')::integer;
    v_overtime := nullif(btrim(coalesce(
      p_payload ->> 'overtime_minutes', ''
    )), '')::integer;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_status := btrim(coalesce(p_payload ->> 'attendance_status', ''));
  v_reason := btrim(coalesce(p_payload ->> 'reason', ''));
  if v_worker_id is null or v_work_date is null
    or v_status not in (
      'present', 'absent', 'annual_leave', 'sick_leave', 'official_leave',
      'unpaid_leave', 'not_entered'
    )
    or v_regular is null or v_overtime is null
    or v_regular < 0 or v_regular > 1440
    or v_overtime < 0 or v_overtime > 1440
    or v_regular + v_overtime > 1440
    or (v_status = 'present' and v_regular + v_overtime = 0)
    or (v_status <> 'present' and (v_regular <> 0 or v_overtime <> 0))
    or v_reason = '' or char_length(v_reason) > 2000
    or (p_expected_version is not null and p_expected_version < 1)
    or p_idempotency_key is null
  then
    raise exception 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID'
      using errcode = '22023';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'v1_workforce_attendance|' || v_worker_id::text || '|' ||
      v_work_date::text, 0
    )
  );
  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.worker_id = v_worker_id and day.work_date = v_work_date
  for update;

  if found then
    v_authority := public.v1_workforce_attendance_authority_context(
      'workforce.attendance.maintain', v_day.worker_id, v_day.work_date,
      v_day.assignment_team_id_snapshot,
      v_day.assignment_project_id_snapshot,
      v_day.assignment_project_scope_id_snapshot,
      v_day.assignment_internal_location_id_snapshot
    );
  else
    select worker.* into v_worker
    from public.v1_workforce_workers worker
    where worker.id = v_worker_id for update;
    if not found
      or v_worker.current_status <> 'active'
      or v_work_date < v_worker.joining_date
      or (v_worker.leaving_date is not null
        and v_work_date > v_worker.leaving_date)
    then
      raise exception 'V1_WORKFORCE_ATTENDANCE_ACTIVE_EMPLOYMENT_REQUIRED'
        using errcode = '23514';
    end if;
    v_assignment := public.v1_workforce_effective_assignment(
      v_worker_id, v_work_date
    );
    if v_assignment = '{}'::jsonb
      or nullif(v_assignment ->> 'team_id', '') is null
    then
      raise exception 'V1_WORKFORCE_ATTENDANCE_ASSIGNMENT_REQUIRED'
        using errcode = '23514';
    end if;
    v_schedule := public.v1_workforce_attendance_schedule_context(
      (v_assignment ->> 'team_id')::uuid, v_work_date
    );
    if v_schedule = '{}'::jsonb then
      raise exception 'V1_WORKFORCE_ATTENDANCE_SCHEDULE_REQUIRED'
        using errcode = '23514';
    end if;
    v_authority := public.v1_workforce_attendance_authority_context(
      'workforce.attendance.maintain', v_worker_id, v_work_date,
      (v_assignment ->> 'team_id')::uuid,
      nullif(v_assignment ->> 'project_id', '')::uuid,
      nullif(v_assignment ->> 'project_scope_id', '')::uuid,
      nullif(v_assignment ->> 'internal_location_id', '')::uuid
    );
  end if;
  if v_authority = '{}'::jsonb then
    raise exception 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_attendance_day', p_idempotency_key,
    jsonb_build_object(
      'payload', p_payload, 'expected_version', p_expected_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_day.id is not null then
    if p_expected_version is null
      or p_expected_version <> v_day.record_version
    then
      raise exception 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_before := jsonb_build_object(
      'attendance_status', v_day.attendance_status,
      'regular_minutes', v_day.regular_minutes,
      'overtime_minutes', v_day.overtime_minutes,
      'reason', v_day.reason,
      'record_version', v_day.record_version
    );
    update public.v1_workforce_attendance_days set
      attendance_status = v_status,
      regular_minutes = v_regular,
      overtime_minutes = v_overtime,
      reason = v_reason,
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_day.id returning * into v_day;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_ATTENDANCE_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_attendance_days (
      worker_id, work_date, attendance_status, regular_minutes,
      overtime_minutes, reason, worker_number_snapshot, worker_name_snapshot,
      worker_joining_date_snapshot, worker_leaving_date_snapshot,
      worker_status_snapshot,
      assignment_id_snapshot, assignment_kind_snapshot,
      assignment_team_id_snapshot, assignment_team_name_snapshot,
      assignment_supervisor_auth_user_id_snapshot,
      assignment_supervisor_name_snapshot, assignment_project_id_snapshot,
      assignment_project_ref_snapshot, assignment_project_name_snapshot,
      assignment_project_scope_id_snapshot,
      assignment_project_scope_name_snapshot,
      assignment_internal_location_id_snapshot,
      assignment_internal_location_name_snapshot,
      assignment_valid_from_snapshot, assignment_valid_to_snapshot,
      assignment_record_version_snapshot, initial_authority_kind,
      initial_responsibility_assignment_id,
      initial_responsibility_scope_kind,
      initial_responsibility_scope_reference,
      initial_responsibility_record_version,
      team_schedule_link_id_snapshot,
      team_schedule_record_version_snapshot, calendar_id_snapshot,
      calendar_code_snapshot, calendar_name_snapshot,
      calendar_timezone_snapshot, calendar_record_version_snapshot,
      calendar_date_override_id_snapshot,
      calendar_date_override_version_snapshot,
      calendar_override_kind_snapshot, calendar_exception_name_snapshot,
      day_type_source_snapshot, iso_weekday_snapshot, day_type_snapshot,
      scheduled_minutes_snapshot, break_minutes_snapshot,
      shift_template_id_snapshot, shift_code_snapshot, shift_name_snapshot,
      shift_kind_snapshot, shift_start_time_snapshot, shift_end_time_snapshot,
      shift_scheduled_minutes_snapshot, shift_break_minutes_snapshot,
      shift_crosses_midnight_snapshot, shift_work_date_basis_snapshot,
      shift_record_version_snapshot, created_by_auth_user_id,
      updated_by_auth_user_id
    ) values (
      v_worker_id, v_work_date, v_status, v_regular, v_overtime, v_reason,
      v_worker.worker_number, coalesce(
        v_worker.preferred_display_name, v_worker.full_name
      ),
      v_worker.joining_date, v_worker.leaving_date, v_worker.current_status,
      (v_assignment ->> 'assignment_id')::uuid,
      v_assignment ->> 'assignment_kind',
      (v_assignment ->> 'team_id')::uuid,
      v_assignment ->> 'team_name',
      nullif(v_assignment ->> 'supervisor_auth_user_id', '')::uuid,
      v_assignment ->> 'supervisor_name',
      nullif(v_assignment ->> 'project_id', '')::uuid,
      v_assignment ->> 'project_ref', v_assignment ->> 'project_name',
      nullif(v_assignment ->> 'project_scope_id', '')::uuid,
      v_assignment ->> 'project_scope_name',
      nullif(v_assignment ->> 'internal_location_id', '')::uuid,
      v_assignment ->> 'internal_location_name',
      (v_assignment ->> 'valid_from')::date,
      nullif(v_assignment ->> 'valid_to', '')::date,
      (v_assignment ->> 'record_version')::bigint,
      v_authority ->> 'authority_kind',
      nullif(v_authority ->> 'responsibility_assignment_id', '')::uuid,
      v_authority ->> 'scope_kind', v_authority ->> 'scope_reference',
      nullif(v_authority ->> 'record_version', '')::bigint,
      (v_schedule ->> 'team_schedule_link_id')::uuid,
      (v_schedule ->> 'team_schedule_record_version')::bigint,
      (v_schedule ->> 'calendar_id')::uuid,
      v_schedule ->> 'calendar_code', v_schedule ->> 'calendar_name',
      v_schedule ->> 'calendar_timezone',
      (v_schedule ->> 'calendar_record_version')::bigint,
      nullif(v_schedule ->> 'calendar_date_override_id', '')::uuid,
      nullif(v_schedule ->> 'calendar_date_override_version', '')::bigint,
      v_schedule ->> 'calendar_override_kind',
      v_schedule ->> 'calendar_exception_name',
      v_schedule ->> 'day_type_source',
      (v_schedule ->> 'iso_weekday')::smallint,
      v_schedule ->> 'day_type',
      (v_schedule ->> 'scheduled_minutes')::integer,
      (v_schedule ->> 'break_minutes')::integer,
      nullif(v_schedule ->> 'shift_template_id', '')::uuid,
      v_schedule ->> 'shift_code', v_schedule ->> 'shift_name',
      v_schedule ->> 'shift_kind',
      nullif(v_schedule ->> 'shift_start_time', '')::time,
      nullif(v_schedule ->> 'shift_end_time', '')::time,
      nullif(v_schedule ->> 'shift_scheduled_minutes', '')::integer,
      nullif(v_schedule ->> 'shift_break_minutes', '')::integer,
      nullif(v_schedule ->> 'shift_crosses_midnight', '')::boolean,
      v_schedule ->> 'shift_work_date_basis',
      nullif(v_schedule ->> 'shift_record_version', '')::bigint,
      v_actor, v_actor
    ) returning * into v_day;
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'attendance_day_id', v_day.id,
    'worker_id', v_day.worker_id,
    'work_date', v_day.work_date,
    'record_version', v_day.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_attendance_day_created'
      else 'workforce_attendance_day_corrected' end,
    'workforce_attendance_day', v_day.id,
    v_day.assignment_project_id_snapshot, v_before,
    jsonb_build_object(
      'attendance_status', v_day.attendance_status,
      'regular_minutes', v_day.regular_minutes,
      'overtime_minutes', v_day.overtime_minutes,
      'reason', v_day.reason,
      'record_version', v_day.record_version,
      'retained_assignment_id', v_day.assignment_id_snapshot,
      'retained_calendar_id', v_day.calendar_id_snapshot,
      'retained_shift_id', v_day.shift_template_id_snapshot,
      'retained_day_type', v_day.day_type_snapshot
    ),
    v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_attendance_day', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- T03 activates only the two tested daily-attendance consumers.
update public.v1_capability_catalog
set status = 'operational', authorization_mode = 'enforced',
    is_assignable = true
where capability_key in (
  'workforce.view', 'workforce.attendance.maintain'
);

do $workforce_t03_capability_contract$
begin
  if (
    select count(*)
    from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and catalog.status = 'operational'
      and catalog.authorization_mode = 'enforced'
      and catalog.is_assignable
  ) <> 2
  or exists (
    select 1
    from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and catalog.capability_key not in (
        'workforce.view', 'workforce.attendance.maintain'
      )
      and (
        catalog.status <> 'planned'
        or catalog.authorization_mode <> 'shadow'
        or catalog.is_assignable
      )
  ) then
    raise exception 'V1_WORKFORCE_T03_CAPABILITY_CUTOVER_CONFLICT'
      using errcode = '23514';
  end if;
end;
$workforce_t03_capability_contract$;

revoke all on function public.v1_workforce_attendance_schedule_context(
  uuid,date
) from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_attendance_history()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_matching_responsibility(
  uuid,uuid,date,uuid,uuid,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_attendance_authority_context(
  text,uuid,date,uuid,uuid,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_attendance_day_json(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_workforce_attendance(date,uuid)
  from public, anon;
revoke all on function public.v1_save_workforce_attendance_day(
  jsonb,bigint,uuid
) from public, anon;

grant execute on function public.v1_get_workforce_attendance(date,uuid)
  to authenticated;
grant execute on function public.v1_save_workforce_attendance_day(
  jsonb,bigint,uuid
) to authenticated;

commit;
