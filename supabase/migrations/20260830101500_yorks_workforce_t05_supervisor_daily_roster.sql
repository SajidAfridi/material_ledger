-- Yorks Workforce T05: permission-safe supervisor daily roster authority.
--
-- This additive slice composes the accepted T03 attendance and T04 allocation
-- commands into one atomic roster save. It adds no capability, monthly period,
-- review/approval state, payroll rule, notification, route, feature enablement,
-- legacy migration, remote migration or deployment.
--
-- Data preservation and rollback:
-- - existing attendance and allocation rows are not rewritten or deleted;
-- - overtime_reason is nullable evidence only and is not pay/approval authority;
-- - roster reads never create attendance or allocation rows;
-- - rollback is forward-only by revoking the T05 RPC grants in a later
--   migration. Retained attendance/allocation/audit history must not be dropped.

begin;

alter table public.v1_workforce_attendance_days
  add column overtime_reason text check (
    overtime_reason is null or (
      btrim(overtime_reason) <> '' and char_length(overtime_reason) <= 2000
    )
  );

comment on column public.v1_workforce_attendance_days.overtime_reason is
  'Optional T05 overtime evidence. No threshold, approval or pay semantics.';

create or replace function public.v1_workforce_normalize_overtime_reason()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.overtime_reason := nullif(btrim(coalesce(new.overtime_reason, '')), '');
  if new.overtime_minutes = 0 then
    new.overtime_reason := null;
  end if;
  return new;
end;
$$;

create or replace function public.v1_get_workforce_daily_roster(
  p_work_date date,
  p_team_id uuid default null,
  p_project_id uuid default null,
  p_project_scope_id uuid default null,
  p_internal_location_id uuid default null,
  p_query text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_rows jsonb;
  v_total_count bigint;
  v_is_future boolean;
  v_can_attendance boolean;
  v_can_timesheet boolean;
  v_teams jsonb;
  v_projects jsonb;
  v_scopes jsonb;
  v_locations jsonb;
begin
  if v_actor is null or p_work_date is null
    or p_limit is null or p_limit < 1 or p_limit > 500
    or p_offset is null or p_offset < 0
    or (p_project_scope_id is not null and p_project_id is null)
  then
    raise exception 'V1_WORKFORCE_ROSTER_READ_INVALID'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_ROSTER_READ_DENIED'
      using errcode = '42501';
  end if;

  with candidate_workers as materialized (
    select worker.id as worker_id
    from public.v1_workforce_workers worker
    where worker.current_status = 'active'
      and worker.joining_date <= p_work_date
      and (worker.leaving_date is null or worker.leaving_date >= p_work_date)
      and public.v1_workforce_effective_assignment(
        worker.id, p_work_date
      ) <> '{}'::jsonb
    union
    select day.worker_id
    from public.v1_workforce_attendance_days day
    where day.work_date = p_work_date
  ), authorized_rows as materialized (
    select row_data
    from candidate_workers candidate
    cross join lateral (
      select public.v1_workforce_daily_roster_row_json(
        candidate.worker_id, p_work_date
      ) as row_data
    ) projected
    where row_data <> '{}'::jsonb
  ), filtered_rows as materialized (
    select row_data
    from authorized_rows
    where (p_team_id is null
        or row_data #>> '{assignment,team_id}' = p_team_id::text)
      and (p_project_id is null
        or row_data #>> '{assignment,project_id}' = p_project_id::text)
      and (p_project_scope_id is null
        or row_data #>> '{assignment,project_scope_id}' =
          p_project_scope_id::text)
      and (p_internal_location_id is null
        or row_data #>> '{assignment,internal_location_id}' =
          p_internal_location_id::text)
      and (
        v_query is null
        or lower(coalesce(row_data ->> 'worker_number', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data ->> 'worker_name', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data ->> 'designation', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data ->> 'trade_name', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data #>> '{assignment,team_name}', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data #>> '{assignment,project_ref}', ''))
          like '%' || v_query || '%'
        or lower(coalesce(row_data #>> '{assignment,project_name}', ''))
          like '%' || v_query || '%'
      )
  )
  select
    coalesce((
      select jsonb_agg(page.row_data - '_is_future'
        order by lower(page.row_data ->> 'worker_name'),
          page.row_data ->> 'worker_number', page.row_data ->> 'worker_id')
      from (
        select filtered.row_data
        from filtered_rows filtered
        order by lower(filtered.row_data ->> 'worker_name'),
          filtered.row_data ->> 'worker_number',
          filtered.row_data ->> 'worker_id'
        limit p_limit offset p_offset
      ) page
    ), '[]'::jsonb),
    (select count(*) from filtered_rows),
    coalesce((
      select bool_or((row_data ->> '_is_future')::boolean)
      from filtered_rows
    ), true),
    coalesce((
      select bool_or((row_data ->> 'can_maintain_attendance')::boolean)
      from filtered_rows
    ), false),
    coalesce((
      select bool_or((row_data ->> 'can_maintain_timesheet')::boolean)
      from filtered_rows
    ), false),
    coalesce((
      select jsonb_agg(selector.value order by selector.sort_name)
      from (
        select distinct on (row_data #>> '{assignment,team_id}')
          jsonb_build_object(
            'team_id', row_data #>> '{assignment,team_id}',
            'team_name', row_data #>> '{assignment,team_name}'
          ) as value,
          lower(row_data #>> '{assignment,team_name}') as sort_name
        from authorized_rows
        where nullif(row_data #>> '{assignment,team_id}', '') is not null
        order by row_data #>> '{assignment,team_id}', sort_name
      ) selector
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(selector.value order by selector.sort_name)
      from (
        select distinct on (row_data #>> '{assignment,project_id}')
          jsonb_build_object(
            'project_id', row_data #>> '{assignment,project_id}',
            'project_ref', row_data #>> '{assignment,project_ref}',
            'project_name', row_data #>> '{assignment,project_name}'
          ) as value,
          lower(coalesce(row_data #>> '{assignment,project_ref}', '') ||
            ' ' || coalesce(row_data #>> '{assignment,project_name}', ''))
            as sort_name
        from authorized_rows
        where nullif(row_data #>> '{assignment,project_id}', '') is not null
        order by row_data #>> '{assignment,project_id}', sort_name
      ) selector
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(selector.value order by selector.sort_name)
      from (
        select distinct on (row_data #>> '{assignment,project_scope_id}')
          jsonb_build_object(
            'project_id', row_data #>> '{assignment,project_id}',
            'project_scope_id',
              row_data #>> '{assignment,project_scope_id}',
            'project_scope_name',
              row_data #>> '{assignment,project_scope_name}'
          ) as value,
          lower(row_data #>> '{assignment,project_scope_name}') as sort_name
        from authorized_rows
        where nullif(
          row_data #>> '{assignment,project_scope_id}', ''
        ) is not null
        order by row_data #>> '{assignment,project_scope_id}', sort_name
      ) selector
    ), '[]'::jsonb),
    coalesce((
      select jsonb_agg(selector.value order by selector.sort_name)
      from (
        select distinct on (
          row_data #>> '{assignment,internal_location_id}'
        )
          jsonb_build_object(
            'internal_location_id',
              row_data #>> '{assignment,internal_location_id}',
            'internal_location_name',
              row_data #>> '{assignment,internal_location_name}'
          ) as value,
          lower(row_data #>> '{assignment,internal_location_name}')
            as sort_name
        from authorized_rows
        where nullif(
          row_data #>> '{assignment,internal_location_id}', ''
        ) is not null
        order by
          row_data #>> '{assignment,internal_location_id}', sort_name
      ) selector
    ), '[]'::jsonb)
  into v_rows, v_total_count, v_is_future, v_can_attendance,
    v_can_timesheet, v_teams, v_projects, v_scopes, v_locations;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t05',
    'actor_auth_user_id', v_actor,
    'work_date', p_work_date,
    'is_future', v_is_future,
    'server_time', clock_timestamp(),
    'filters', jsonb_build_object(
      'team_id', p_team_id,
      'project_id', p_project_id,
      'project_scope_id', p_project_scope_id,
      'internal_location_id', p_internal_location_id,
      'query', nullif(btrim(coalesce(p_query, '')), '')
    ),
    'capabilities', jsonb_build_object(
      'can_view', true,
      'can_maintain_attendance', v_can_attendance,
      'can_maintain_timesheet', v_can_timesheet
    ),
    'selectors', jsonb_build_object(
      'teams', v_teams,
      'projects', v_projects,
      'project_scopes', v_scopes,
      'internal_locations', v_locations
    ),
    'total_count', v_total_count,
    'rows', v_rows
  );
end;
$$;

-- Internal evidence mutation used by the atomic roster composition. It keeps
-- the accepted T03 six-key payload unchanged for older clients.
create or replace function public.v1_workforce_set_overtime_reason(
  p_attendance_day_id uuid,
  p_overtime_reason text,
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
  v_reason text := nullif(btrim(coalesce(p_overtime_reason, '')), '');
  v_day public.v1_workforce_attendance_days%rowtype;
  v_authority jsonb;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  if v_actor is null or p_attendance_day_id is null
    or p_expected_version is null or p_expected_version < 1
    or p_idempotency_key is null
    or char_length(coalesce(v_reason, '')) > 2000
  then
    raise exception 'V1_WORKFORCE_OVERTIME_REASON_INPUT_INVALID'
      using errcode = '22023';
  end if;

  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.id = p_attendance_day_id;
  if not found then
    raise exception 'V1_WORKFORCE_ATTENDANCE_NOT_FOUND'
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

  v_authority := public.v1_workforce_attendance_authority_context(
    'workforce.attendance.maintain', v_day.worker_id, v_day.work_date,
    v_day.assignment_team_id_snapshot,
    v_day.assignment_project_id_snapshot,
    v_day.assignment_project_scope_id_snapshot,
    v_day.assignment_internal_location_id_snapshot
  );
  if v_authority = '{}'::jsonb then
    raise exception 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED'
      using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_workforce_set_overtime_reason', p_idempotency_key,
    jsonb_build_object(
      'attendance_day_id', p_attendance_day_id,
      'overtime_reason', p_overtime_reason,
      'expected_version', p_expected_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  if v_day.record_version <> p_expected_version then
    raise exception 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if v_day.overtime_minutes = 0 then
    v_reason := null;
  end if;

  if v_day.overtime_reason is distinct from v_reason then
    v_before := jsonb_build_object(
      'overtime_reason', v_day.overtime_reason,
      'record_version', v_day.record_version
    );
    update public.v1_workforce_attendance_days set
      overtime_reason = v_reason,
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_day.id returning * into v_day;

    perform public.v1_write_audit_event(
      'workforce_attendance_overtime_reason_updated',
      'workforce_attendance_day', v_day.id,
      v_day.assignment_project_id_snapshot, v_before,
      jsonb_build_object(
        'overtime_reason', v_day.overtime_reason,
        'record_version', v_day.record_version
      ), 'Roster overtime evidence updated', p_idempotency_key
    );
  end if;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'attendance_day_id', v_day.id,
    'record_version', v_day.record_version,
    'overtime_reason', v_day.overtime_reason
  );
  perform public.v1_complete_idempotency(
    'v1_workforce_set_overtime_reason', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create trigger v1_workforce_attendance_00_overtime_reason_normalize
before insert or update on public.v1_workforce_attendance_days
for each row execute function public.v1_workforce_normalize_overtime_reason();

-- T03 permits corrections only to the mutable attendance facts. T05 extends
-- that allowlist solely with optional overtime evidence; retained worker,
-- assignment, authority and schedule snapshots remain immutable.
create or replace function public.v1_workforce_guard_attendance_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    to_jsonb(new) - array[
      'attendance_status', 'regular_minutes', 'overtime_minutes',
      'overtime_reason', 'reason', 'record_version',
      'updated_by_auth_user_id', 'updated_at'
    ]::text[]
  ) is distinct from (
    to_jsonb(old) - array[
      'attendance_status', 'regular_minutes', 'overtime_minutes',
      'overtime_reason', 'reason', 'record_version',
      'updated_by_auth_user_id', 'updated_at'
    ]::text[]
  ) or new.record_version <> old.record_version + 1 then
    raise exception 'V1_WORKFORCE_ATTENDANCE_CONTEXT_IMMUTABLE'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- T04 save and withdraw both append a revision. Guard that shared mutation
-- boundary explicitly so neither command can mutate a retained future row,
-- even when a future fixture predates the T03 attendance trigger.
create or replace function public.v1_workforce_guard_future_timesheet_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_day public.v1_workforce_attendance_days%rowtype;
  v_calendar_today date;
begin
  select day.* into v_day
  from public.v1_workforce_timesheet_allocation_sets allocation_set
  join public.v1_workforce_attendance_days day
    on day.id = allocation_set.attendance_day_id
  where allocation_set.id = new.allocation_set_id;

  if not found then
    raise exception 'V1_WORKFORCE_TIMESHEET_ATTENDANCE_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  begin
    v_calendar_today := (
      clock_timestamp() at time zone v_day.calendar_timezone_snapshot
    )::date;
  exception when invalid_parameter_value then
    raise exception 'V1_WORKFORCE_ATTENDANCE_RETAINED_TIMEZONE_INVALID'
      using errcode = '23514';
  end;

  if v_day.work_date > v_calendar_today then
    raise exception 'V1_WORKFORCE_TIMESHEET_FUTURE_DATE_FORBIDDEN'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_timesheet_revision_future_date_guard
before insert on public.v1_workforce_timesheet_allocation_revisions
for each row execute function
  public.v1_workforce_guard_future_timesheet_revision();

create or replace function public.v1_workforce_roster_authority_context(
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
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_responsibility jsonb;
begin
  if p_capability_key not in (
    'workforce.view', 'workforce.attendance.maintain',
    'workforce.timesheets.maintain'
  ) or v_actor is null or p_worker_id is null or p_work_date is null then
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

create or replace function public.v1_workforce_roster_child_key(
  p_root_key uuid,
  p_worker_id uuid,
  p_action text
)
returns uuid
language sql
immutable
strict
set search_path = ''
as $$
  select md5(
    'v1_workforce_roster|' || p_root_key::text || '|' ||
    p_worker_id::text || '|' || p_action
  )::uuid;
$$;

create or replace function public.v1_save_workforce_daily_roster(
  p_work_date date,
  p_rows jsonb,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_command_reason text := btrim(coalesce(p_reason, ''));
  v_existing_response jsonb;
  v_response jsonb;
  v_response_rows jsonb := '[]'::jsonb;
  v_item jsonb;
  v_worker_id uuid;
  v_seen_workers uuid[] := array[]::uuid[];
  v_status text;
  v_regular integer;
  v_overtime integer;
  v_overtime_reason text;
  v_row_reason text;
  v_action text;
  v_expected_attendance bigint;
  v_expected_allocation bigint;
  v_allocations jsonb;
  v_worker public.v1_workforce_workers%rowtype;
  v_day public.v1_workforce_attendance_days%rowtype;
  v_set public.v1_workforce_timesheet_allocation_sets%rowtype;
  v_assignment jsonb;
  v_schedule jsonb;
  v_attendance_authority jsonb;
  v_timesheet_authority jsonb;
  v_calendar_today date;
  v_totals_changed boolean;
  v_attendance_changed boolean;
  v_evidence_changed boolean;
  v_child_key uuid;
  v_allocation_json jsonb;
  v_worker_ids jsonb := '[]'::jsonb;
begin
  if v_actor is null or p_work_date is null or p_idempotency_key is null
    or v_command_reason = '' or char_length(v_command_reason) > 2000
    or jsonb_typeof(p_rows) <> 'array'
    or jsonb_array_length(p_rows) < 1
    or jsonb_array_length(p_rows) > 200
  then
    raise exception 'V1_WORKFORCE_ROSTER_SAVE_INVALID'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_actor_is_active()
  then
    raise exception 'V1_WORKFORCE_ROSTER_SAVE_DENIED'
      using errcode = '42501';
  end if;

  -- Validate the complete allowlisted request before taking worker locks.
  for v_item in
    select value from jsonb_array_elements(p_rows)
  loop
    if jsonb_typeof(v_item) <> 'object' then
      raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
        using errcode = '22023';
    end if;
    perform public.v1_assert_object_keys(
      v_item,
      array[
        'worker_id', 'expected_attendance_version', 'attendance_status',
        'regular_minutes', 'overtime_minutes', 'overtime_reason', 'reason',
        'allocation_action', 'expected_allocation_version', 'allocations'
      ],
      'save_workforce_daily_roster_row'
    );
    if not (v_item ?& array[
      'worker_id', 'expected_attendance_version', 'attendance_status',
      'regular_minutes', 'overtime_minutes', 'overtime_reason', 'reason',
      'allocation_action', 'expected_allocation_version', 'allocations'
    ]::text[])
      or jsonb_typeof(v_item -> 'worker_id') <> 'string'
      or jsonb_typeof(v_item -> 'attendance_status') <> 'string'
      or jsonb_typeof(v_item -> 'regular_minutes') <> 'number'
      or jsonb_typeof(v_item -> 'overtime_minutes') <> 'number'
      or (v_item -> 'regular_minutes')::text !~ '^(0|[1-9][0-9]*)$'
      or (v_item -> 'overtime_minutes')::text !~ '^(0|[1-9][0-9]*)$'
      or jsonb_typeof(v_item -> 'reason') <> 'string'
      or jsonb_typeof(v_item -> 'allocation_action') <> 'string'
      or jsonb_typeof(v_item -> 'overtime_reason') not in ('string', 'null')
      or jsonb_typeof(v_item -> 'expected_attendance_version')
        not in ('number', 'null')
      or jsonb_typeof(v_item -> 'expected_allocation_version')
        not in ('number', 'null')
      or jsonb_typeof(v_item -> 'allocations') not in ('array', 'null')
    then
      raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
        using errcode = '22023';
    end if;
    if jsonb_typeof(v_item -> 'expected_attendance_version') = 'number'
      and (v_item -> 'expected_attendance_version')::text
        !~ '^[1-9][0-9]*$'
    then
      raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
        using errcode = '22023';
    end if;
    if jsonb_typeof(v_item -> 'expected_allocation_version') = 'number'
      and (v_item -> 'expected_allocation_version')::text
        !~ '^[1-9][0-9]*$'
    then
      raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
        using errcode = '22023';
    end if;

    begin
      v_worker_id := (v_item ->> 'worker_id')::uuid;
      v_regular := (v_item ->> 'regular_minutes')::integer;
      v_overtime := (v_item ->> 'overtime_minutes')::integer;
    exception
      when invalid_text_representation or numeric_value_out_of_range then
        raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
          using errcode = '22023';
    end;
    v_status := btrim(coalesce(v_item ->> 'attendance_status', ''));
    v_overtime_reason := nullif(btrim(coalesce(
      v_item ->> 'overtime_reason', ''
    )), '');
    v_row_reason := btrim(coalesce(v_item ->> 'reason', ''));
    v_action := btrim(coalesce(v_item ->> 'allocation_action', ''));
    v_allocations := v_item -> 'allocations';

    if v_worker_id is null or v_worker_id = any(v_seen_workers)
      or v_status not in (
        'present', 'absent', 'annual_leave', 'sick_leave', 'official_leave',
        'unpaid_leave', 'not_entered'
      )
      or v_regular < 0 or v_regular > 1440
      or v_overtime < 0 or v_overtime > 1440
      or v_regular + v_overtime > 1440
      or (v_status = 'present' and v_regular + v_overtime = 0)
      or (v_status <> 'present' and (v_regular <> 0 or v_overtime <> 0))
      or char_length(coalesce(v_overtime_reason, '')) > 2000
      or v_row_reason = '' or char_length(v_row_reason) > 2000
      or v_action not in ('preserve', 'replace', 'withdraw')
      or (v_action = 'replace' and (
        jsonb_typeof(v_allocations) <> 'array'
        or jsonb_array_length(v_allocations) = 0))
      or (v_action in ('preserve', 'withdraw') and (
        jsonb_typeof(v_allocations) not in ('array', 'null')
        or (jsonb_typeof(v_allocations) = 'array'
          and jsonb_array_length(v_allocations) <> 0)))
    then
      raise exception 'V1_WORKFORCE_ROSTER_ROW_INVALID'
        using errcode = '22023';
    end if;
    v_seen_workers := array_append(v_seen_workers, v_worker_id);
  end loop;

  -- All commands use T03/T04's canonical worker/date advisory key. Sorting
  -- makes multi-row requests deterministic and prevents lock-order deadlocks.
  for v_worker_id in
    select distinct (row_value ->> 'worker_id')::uuid
    from jsonb_array_elements(p_rows) row_value
    order by 1
  loop
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'v1_workforce_attendance|' || v_worker_id::text || '|' ||
        p_work_date::text, 0
      )
    );
  end loop;

  -- Authorization and calendar-local future checks happen for every row before
  -- claiming root idempotency. No partial row can commit.
  for v_item in
    select value from jsonb_array_elements(p_rows)
  loop
    v_worker_id := (v_item ->> 'worker_id')::uuid;
    v_action := v_item ->> 'allocation_action';
    v_assignment := null;
    v_schedule := null;
    v_day := null;

    select day.* into v_day
    from public.v1_workforce_attendance_days day
    where day.worker_id = v_worker_id and day.work_date = p_work_date
    for update;

    if v_day.id is not null then
      v_assignment := jsonb_build_object(
        'team_id', v_day.assignment_team_id_snapshot,
        'project_id', v_day.assignment_project_id_snapshot,
        'project_scope_id', v_day.assignment_project_scope_id_snapshot,
        'internal_location_id', v_day.assignment_internal_location_id_snapshot
      );
      v_schedule := jsonb_build_object(
        'calendar_timezone', v_day.calendar_timezone_snapshot
      );
    else
      select worker.* into v_worker
      from public.v1_workforce_workers worker
      where worker.id = v_worker_id for update;
      if not found or v_worker.current_status <> 'active'
        or p_work_date < v_worker.joining_date
        or (v_worker.leaving_date is not null
          and p_work_date > v_worker.leaving_date)
      then
        raise exception 'V1_WORKFORCE_ATTENDANCE_ACTIVE_EMPLOYMENT_REQUIRED'
          using errcode = '23514';
      end if;
      v_assignment := public.v1_workforce_effective_assignment(
        v_worker_id, p_work_date
      );
      if v_assignment = '{}'::jsonb
        or nullif(v_assignment ->> 'team_id', '') is null
      then
        raise exception 'V1_WORKFORCE_ATTENDANCE_ASSIGNMENT_REQUIRED'
          using errcode = '23514';
      end if;
      v_schedule := public.v1_workforce_attendance_schedule_context(
        (v_assignment ->> 'team_id')::uuid, p_work_date
      );
      if v_schedule = '{}'::jsonb then
        raise exception 'V1_WORKFORCE_ATTENDANCE_SCHEDULE_REQUIRED'
          using errcode = '23514';
      end if;
    end if;

    begin
      v_calendar_today := (
        clock_timestamp() at time zone (v_schedule ->> 'calendar_timezone')
      )::date;
    exception when invalid_parameter_value then
      raise exception 'V1_WORKFORCE_ATTENDANCE_RETAINED_TIMEZONE_INVALID'
        using errcode = '23514';
    end;
    if p_work_date > v_calendar_today then
      raise exception 'V1_WORKFORCE_ROSTER_FUTURE_DATE_FORBIDDEN'
        using errcode = '22023';
    end if;

    v_attendance_authority := public.v1_workforce_roster_authority_context(
      'workforce.attendance.maintain', v_worker_id, p_work_date,
      nullif(v_assignment ->> 'team_id', '')::uuid,
      nullif(v_assignment ->> 'project_id', '')::uuid,
      nullif(v_assignment ->> 'project_scope_id', '')::uuid,
      nullif(v_assignment ->> 'internal_location_id', '')::uuid
    );
    if v_attendance_authority = '{}'::jsonb then
      raise exception 'V1_WORKFORCE_ROSTER_SAVE_DENIED'
        using errcode = '42501';
    end if;

    if v_action in ('replace', 'withdraw') then
      v_timesheet_authority := public.v1_workforce_roster_authority_context(
        'workforce.timesheets.maintain', v_worker_id, p_work_date,
        nullif(v_assignment ->> 'team_id', '')::uuid,
        nullif(v_assignment ->> 'project_id', '')::uuid,
        nullif(v_assignment ->> 'project_scope_id', '')::uuid,
        nullif(v_assignment ->> 'internal_location_id', '')::uuid
      );
      if v_timesheet_authority = '{}'::jsonb then
        raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
          using errcode = '42501';
      end if;
      if v_day.id is not null then
        select allocation_set.* into v_set
        from public.v1_workforce_timesheet_allocation_sets allocation_set
        where allocation_set.attendance_day_id = v_day.id;
        if v_set.id is not null
          and not public.v1_workforce_timesheet_current_targets_authorized(
            'workforce.timesheets.maintain', v_set.id
          )
        then
          raise exception 'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED'
            using errcode = '42501';
        end if;
      end if;
    end if;
  end loop;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_daily_roster', p_idempotency_key,
    jsonb_build_object(
      'work_date', p_work_date,
      'rows', p_rows,
      'reason', p_reason
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  for v_item in
    select value from jsonb_array_elements(p_rows)
  loop
    v_worker_id := (v_item ->> 'worker_id')::uuid;
    v_status := v_item ->> 'attendance_status';
    v_regular := (v_item ->> 'regular_minutes')::integer;
    v_overtime := (v_item ->> 'overtime_minutes')::integer;
    v_overtime_reason := nullif(btrim(coalesce(
      v_item ->> 'overtime_reason', ''
    )), '');
    if v_overtime = 0 then
      v_overtime_reason := null;
    end if;
    v_row_reason := btrim(v_item ->> 'reason');
    v_action := v_item ->> 'allocation_action';
    v_allocations := v_item -> 'allocations';
    v_expected_attendance := case
      when jsonb_typeof(v_item -> 'expected_attendance_version') = 'null'
        then null
      else (v_item ->> 'expected_attendance_version')::bigint
    end;
    v_expected_allocation := case
      when jsonb_typeof(v_item -> 'expected_allocation_version') = 'null'
        then null
      else (v_item ->> 'expected_allocation_version')::bigint
    end;

    v_day := null;
    v_set := null;
    select day.* into v_day
    from public.v1_workforce_attendance_days day
    where day.worker_id = v_worker_id and day.work_date = p_work_date
    for update;
    if v_day.id is null then
      if v_expected_attendance is not null then
        raise exception 'V1_WORKFORCE_ATTENDANCE_NOT_FOUND'
          using errcode = 'P0002';
      end if;
    elsif v_expected_attendance is null
      or v_expected_attendance <> v_day.record_version
    then
      raise exception 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT'
        using errcode = '40001';
    end if;

    if v_day.id is not null then
      select allocation_set.* into v_set
      from public.v1_workforce_timesheet_allocation_sets allocation_set
      where allocation_set.attendance_day_id = v_day.id
      for update;
    end if;
    if v_set.id is null then
      if v_expected_allocation is not null then
        raise exception 'V1_WORKFORCE_TIMESHEET_SET_NOT_FOUND'
          using errcode = 'P0002';
      end if;
    elsif (
      v_action in ('replace', 'withdraw')
      and v_expected_allocation is null
    ) or (
      v_expected_allocation is not null
      and v_expected_allocation <> v_set.record_version
    )
    then
      raise exception 'V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT'
        using errcode = '40001';
    end if;

    v_totals_changed := v_day.id is null
      or v_day.attendance_status is distinct from v_status
      or v_day.regular_minutes is distinct from v_regular
      or v_day.overtime_minutes is distinct from v_overtime;
    v_attendance_changed := v_totals_changed
      or v_day.reason is distinct from v_row_reason;
    v_evidence_changed := v_day.id is null
      or v_day.overtime_reason is distinct from v_overtime_reason;

    if v_set.id is not null and v_set.current_state = 'active'
      and v_action = 'preserve' and v_totals_changed
    then
      raise exception 'V1_WORKFORCE_ROSTER_ACTIVE_ALLOCATIONS_REQUIRE_ACTION'
        using errcode = '23514';
    end if;

    if v_action = 'withdraw'
      or (v_action = 'replace' and v_set.id is not null
        and v_set.current_state = 'active' and v_totals_changed)
    then
      if v_set.id is null or v_set.current_state <> 'active' then
        raise exception 'V1_WORKFORCE_TIMESHEET_NOT_ACTIVE'
          using errcode = '23514';
      end if;
      v_child_key := public.v1_workforce_roster_child_key(
        p_idempotency_key, v_worker_id,
        case when v_action = 'withdraw'
          then 'withdraw' else 'replace_withdraw' end
      );
      perform public.v1_withdraw_workforce_timesheet_allocations(
        v_day.id, v_command_reason, v_set.record_version, v_child_key
      );
      select allocation_set.* into v_set
      from public.v1_workforce_timesheet_allocation_sets allocation_set
      where allocation_set.attendance_day_id = v_day.id for update;
    end if;

    if v_attendance_changed then
      v_child_key := public.v1_workforce_roster_child_key(
        p_idempotency_key, v_worker_id, 'attendance'
      );
      perform public.v1_save_workforce_attendance_day(
        jsonb_build_object(
          'worker_id', v_worker_id,
          'work_date', p_work_date,
          'attendance_status', v_status,
          'regular_minutes', v_regular,
          'overtime_minutes', v_overtime,
          'reason', v_row_reason
        ), v_expected_attendance, v_child_key
      );
      select day.* into v_day
      from public.v1_workforce_attendance_days day
      where day.worker_id = v_worker_id and day.work_date = p_work_date
      for update;
    end if;

    if v_evidence_changed then
      v_child_key := public.v1_workforce_roster_child_key(
        p_idempotency_key, v_worker_id, 'overtime_reason'
      );
      perform public.v1_workforce_set_overtime_reason(
        v_day.id, v_overtime_reason, v_day.record_version, v_child_key
      );
      select day.* into v_day
      from public.v1_workforce_attendance_days day
      where day.id = v_day.id for update;
    end if;

    if v_action = 'replace' then
      v_child_key := public.v1_workforce_roster_child_key(
        p_idempotency_key, v_worker_id, 'replace'
      );
      perform public.v1_save_workforce_timesheet_allocations(
        jsonb_build_object(
          'attendance_day_id', v_day.id,
          'attendance_record_version', v_day.record_version,
          'allocations', v_allocations,
          'reason', v_command_reason
        ), case when v_set.id is null then null else v_set.record_version end,
        v_child_key
      );
      select allocation_set.* into v_set
      from public.v1_workforce_timesheet_allocation_sets allocation_set
      where allocation_set.attendance_day_id = v_day.id for update;
    end if;

    v_allocation_json := null;
    if v_set.id is not null
      and public.v1_workforce_timesheet_current_targets_authorized(
        'workforce.view', v_set.id
      )
    then
      v_allocation_json :=
        public.v1_workforce_timesheet_set_json(v_set.id);
    end if;

    v_response_rows := v_response_rows || jsonb_build_array(
      jsonb_build_object(
        'worker_id', v_worker_id,
        'attendance_day_id', v_day.id,
        'attendance_record_version', v_day.record_version,
        'attendance', public.v1_workforce_attendance_day_json(v_day.id)
          || jsonb_build_object(
            'overtime_reason', v_day.overtime_reason
          ),
        'allocation_set', v_allocation_json,
        'allocation_set_id', case
          when v_allocation_json is null then null else v_set.id
        end,
        'allocation_set_record_version', case
          when v_allocation_json is null then null else v_set.record_version
        end,
        'allocation_state', case
          when v_allocation_json is null then null else v_set.current_state
        end
      )
    );
    v_worker_ids := v_worker_ids || jsonb_build_array(v_worker_id);
  end loop;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t05',
    'work_date', p_work_date,
    'saved_at', clock_timestamp(),
    'row_count', jsonb_array_length(v_response_rows),
    'rows', v_response_rows
  );
  perform public.v1_write_audit_event(
    'workforce_daily_roster_saved', 'workforce_daily_roster',
    p_idempotency_key, null, null,
    jsonb_build_object(
      'work_date', p_work_date,
      'row_count', jsonb_array_length(v_response_rows),
      'worker_ids', v_worker_ids
    ), v_command_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_daily_roster', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_workforce_daily_roster_row_json(
  p_worker_id uuid,
  p_work_date date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_worker public.v1_workforce_workers%rowtype;
  v_day public.v1_workforce_attendance_days%rowtype;
  v_set public.v1_workforce_timesheet_allocation_sets%rowtype;
  v_assignment jsonb;
  v_schedule jsonb;
  v_attendance jsonb;
  v_view_authority jsonb;
  v_attendance_authority jsonb;
  v_timesheet_authority jsonb;
  v_targets_visible boolean := true;
  v_is_future boolean;
  v_worker_number text;
  v_worker_name text;
begin
  if p_worker_id is null or p_work_date is null then
    return '{}'::jsonb;
  end if;

  select worker.* into v_worker
  from public.v1_workforce_workers worker
  where worker.id = p_worker_id;
  if not found then
    return '{}'::jsonb;
  end if;

  select day.* into v_day
  from public.v1_workforce_attendance_days day
  where day.worker_id = p_worker_id and day.work_date = p_work_date;

  if v_day.id is not null then
    v_assignment := jsonb_build_object(
      'assignment_id', v_day.assignment_id_snapshot,
      'assignment_kind', v_day.assignment_kind_snapshot,
      'team_id', v_day.assignment_team_id_snapshot,
      'team_name', v_day.assignment_team_name_snapshot,
      'supervisor_auth_user_id',
        v_day.assignment_supervisor_auth_user_id_snapshot,
      'supervisor_name', v_day.assignment_supervisor_name_snapshot,
      'project_id', v_day.assignment_project_id_snapshot,
      'project_ref', v_day.assignment_project_ref_snapshot,
      'project_name', v_day.assignment_project_name_snapshot,
      'project_scope_id', v_day.assignment_project_scope_id_snapshot,
      'project_scope_name', v_day.assignment_project_scope_name_snapshot,
      'internal_location_id', v_day.assignment_internal_location_id_snapshot,
      'internal_location_name',
        v_day.assignment_internal_location_name_snapshot,
      'valid_from', v_day.assignment_valid_from_snapshot,
      'valid_to', v_day.assignment_valid_to_snapshot,
      'record_version', v_day.assignment_record_version_snapshot
    );
    v_schedule := public.v1_workforce_attendance_day_json(v_day.id)
      -> 'schedule';
    v_attendance := public.v1_workforce_attendance_day_json(v_day.id)
      || jsonb_build_object('overtime_reason', v_day.overtime_reason);
    v_worker_number := v_day.worker_number_snapshot;
    v_worker_name := v_day.worker_name_snapshot;
  else
    if v_worker.current_status <> 'active'
      or p_work_date < v_worker.joining_date
      or (v_worker.leaving_date is not null
        and p_work_date > v_worker.leaving_date)
    then
      return '{}'::jsonb;
    end if;
    v_assignment := public.v1_workforce_effective_assignment(
      p_worker_id, p_work_date
    );
    if v_assignment = '{}'::jsonb
      or nullif(v_assignment ->> 'team_id', '') is null
    then
      return '{}'::jsonb;
    end if;
    v_schedule := public.v1_workforce_attendance_schedule_context(
      (v_assignment ->> 'team_id')::uuid, p_work_date
    );
    if v_schedule = '{}'::jsonb then
      return '{}'::jsonb;
    end if;
    v_attendance := null;
    v_worker_number := v_worker.worker_number;
    v_worker_name := coalesce(
      v_worker.preferred_display_name, v_worker.full_name
    );
  end if;

  v_view_authority := public.v1_workforce_roster_authority_context(
    'workforce.view', p_worker_id, p_work_date,
    nullif(v_assignment ->> 'team_id', '')::uuid,
    nullif(v_assignment ->> 'project_id', '')::uuid,
    nullif(v_assignment ->> 'project_scope_id', '')::uuid,
    nullif(v_assignment ->> 'internal_location_id', '')::uuid
  );
  if v_view_authority = '{}'::jsonb then
    return '{}'::jsonb;
  end if;

  v_attendance_authority := public.v1_workforce_roster_authority_context(
    'workforce.attendance.maintain', p_worker_id, p_work_date,
    nullif(v_assignment ->> 'team_id', '')::uuid,
    nullif(v_assignment ->> 'project_id', '')::uuid,
    nullif(v_assignment ->> 'project_scope_id', '')::uuid,
    nullif(v_assignment ->> 'internal_location_id', '')::uuid
  );
  v_timesheet_authority := public.v1_workforce_roster_authority_context(
    'workforce.timesheets.maintain', p_worker_id, p_work_date,
    nullif(v_assignment ->> 'team_id', '')::uuid,
    nullif(v_assignment ->> 'project_id', '')::uuid,
    nullif(v_assignment ->> 'project_scope_id', '')::uuid,
    nullif(v_assignment ->> 'internal_location_id', '')::uuid
  );

  begin
    v_is_future := p_work_date > (
      clock_timestamp() at time zone (v_schedule ->> 'calendar_timezone')
    )::date;
  exception when invalid_parameter_value then
    raise exception 'V1_WORKFORCE_ATTENDANCE_RETAINED_TIMEZONE_INVALID'
      using errcode = '23514';
  end;

  if v_day.id is not null then
    select allocation_set.* into v_set
    from public.v1_workforce_timesheet_allocation_sets allocation_set
    where allocation_set.attendance_day_id = v_day.id;
    if v_set.id is not null then
      v_targets_visible :=
        public.v1_workforce_timesheet_current_targets_authorized(
          'workforce.view', v_set.id
        );
    end if;
  end if;

  return jsonb_build_object(
    'worker_id', v_worker.id,
    'worker_number', v_worker_number,
    'worker_name', v_worker_name,
    'designation', v_worker.designation,
    'trade_id', v_worker.trade_id,
    'trade_name', (
      select trade.trade_name
      from public.v1_workforce_trades trade
      where trade.id = v_worker.trade_id
    ),
    'department', v_worker.department,
    'employer_company', v_worker.employer_company,
    'worker_type', v_worker.worker_type,
    'assignment', v_assignment,
    'schedule_suggestion', v_schedule || jsonb_build_object(
      'source', 'schedule_only',
      'suggested_attendance_status', case
        when coalesce((v_schedule ->> 'scheduled_minutes')::integer, 0) > 0
          then 'present'
        else 'not_entered'
      end,
      'suggested_regular_minutes',
        coalesce((v_schedule ->> 'scheduled_minutes')::integer, 0),
      'suggested_overtime_minutes', 0,
      'requires_confirmation', true
    ),
    'attendance', v_attendance,
    'allocation_set', case
      when v_set.id is not null and v_targets_visible
        then public.v1_workforce_timesheet_set_json(v_set.id)
      else null
    end,
    'has_active_allocation_lock',
      coalesce(v_set.current_state = 'active', false),
    'allocation_details_restricted',
      coalesce(v_set.id is not null and not v_targets_visible, false),
    'can_maintain_attendance',
      not v_is_future and v_attendance_authority <> '{}'::jsonb,
    'can_maintain_timesheet',
      not v_is_future and v_timesheet_authority <> '{}'::jsonb,
    '_is_future', v_is_future
  );
end;
$$;

-- T05 consumes only the three capabilities already promoted by T03/T04.
-- The remaining Workforce keys must stay planned, shadow and nonassignable.
do $workforce_t05_capability_contract$
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
    raise exception 'V1_WORKFORCE_T05_CAPABILITY_CONTRACT_CONFLICT'
      using errcode = '23514';
  end if;
end;
$workforce_t05_capability_contract$;

revoke all on function public.v1_workforce_normalize_overtime_reason()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_attendance_history()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_future_timesheet_revision()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_roster_authority_context(
  text,uuid,date,uuid,uuid,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_roster_child_key(uuid,uuid,text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_set_overtime_reason(
  uuid,text,bigint,uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_daily_roster_row_json(uuid,date)
  from public, anon, authenticated;
revoke all on function public.v1_get_workforce_daily_roster(
  date,uuid,uuid,uuid,uuid,text,integer,integer
) from public, anon;
revoke all on function public.v1_save_workforce_daily_roster(
  date,jsonb,text,uuid
) from public, anon;

grant execute on function public.v1_get_workforce_daily_roster(
  date,uuid,uuid,uuid,uuid,text,integer,integer
) to authenticated;
grant execute on function public.v1_save_workforce_daily_roster(
  date,jsonb,text,uuid
) to authenticated;

commit;
