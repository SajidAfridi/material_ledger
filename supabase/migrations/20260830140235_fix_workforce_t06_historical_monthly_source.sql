-- Workforce T06 correction: retain the exact T03/T04 meaning of historical
-- worker dates when mutable T01 or current parent state changes later.
--
-- This forward-only migration creates no new business fact. It replaces the
-- canonical monthly source resolver and adds insert-time validation for the
-- two structural assignment facts that the original loop did not distinguish.

begin;

create or replace function public.v1_workforce_monthly_source_rows(
  p_team_id uuid,
  p_period_month date
)
returns setof jsonb
language sql
security definer
set search_path = ''
as $$
  with month_dates as materialized (
    select generate_series(
      p_period_month::timestamp,
      (p_period_month + interval '1 month - 1 day')::timestamp,
      interval '1 day'
    )::date as work_date
  ),
  retained_members as materialized (
    select
      attendance.worker_id,
      attendance.work_date,
      attendance.id as attendance_id,
      jsonb_build_object(
        'assignment_id', attendance.assignment_id_snapshot,
        'assignment_kind', attendance.assignment_kind_snapshot,
        'team_id', attendance.assignment_team_id_snapshot,
        'team_name', attendance.assignment_team_name_snapshot,
        'supervisor_auth_user_id',
          attendance.assignment_supervisor_auth_user_id_snapshot,
        'supervisor_name', attendance.assignment_supervisor_name_snapshot,
        'project_id', attendance.assignment_project_id_snapshot,
        'project_ref', attendance.assignment_project_ref_snapshot,
        'project_name', attendance.assignment_project_name_snapshot,
        'project_scope_id', attendance.assignment_project_scope_id_snapshot,
        'project_scope_name',
          attendance.assignment_project_scope_name_snapshot,
        'internal_location_id',
          attendance.assignment_internal_location_id_snapshot,
        'internal_location_name',
          attendance.assignment_internal_location_name_snapshot,
        'valid_from', attendance.assignment_valid_from_snapshot,
        'valid_to', attendance.assignment_valid_to_snapshot,
        'record_version', attendance.assignment_record_version_snapshot,
        'source', 'attendance_snapshot'
      ) as assignment
    from public.v1_workforce_attendance_days attendance
    where attendance.assignment_team_id_snapshot = p_team_id
      and attendance.work_date >= p_period_month
      and attendance.work_date < p_period_month + interval '1 month'
  ),
  prospective_members as materialized (
    select
      worker.id as worker_id,
      dates.work_date,
      null::uuid as attendance_id,
      assignment.value || jsonb_build_object(
        'source', 'effective_assignment'
      ) as assignment
    from public.v1_workforce_workers worker
    cross join month_dates dates
    cross join lateral (
      select public.v1_workforce_effective_assignment(
        worker.id, dates.work_date
      ) as value
    ) assignment
    where nullif(assignment.value ->> 'team_id', '')::uuid = p_team_id
      and not exists (
        select 1
        from public.v1_workforce_attendance_days retained
        where retained.worker_id = worker.id
          and retained.work_date = dates.work_date
      )
  ),
  members as materialized (
    select * from retained_members
    union all
    select * from prospective_members
  ),
  source as (
    select
      member.worker_id,
      member.work_date,
      case when attendance.id is null then worker.worker_number
        else attendance.worker_number_snapshot end as worker_number,
      case when attendance.id is null then worker.full_name
        else attendance.worker_name_snapshot end as full_name,
      worker.employer_company,
      case when attendance.id is null then worker.joining_date
        else attendance.worker_joining_date_snapshot end as joining_date,
      case when attendance.id is null then worker.leaving_date
        else attendance.worker_leaving_date_snapshot end as leaving_date,
      case
        when attendance.id is not null then attendance.worker_status_snapshot
        when worker.current_status = 'left_company'
          and worker.leaving_date is not null
          and member.work_date <= worker.leaving_date then 'active'
        else worker.current_status
      end as current_status,
      case
        when attendance.id is not null then 'attendance_snapshot'
        when worker.current_status = 'left_company'
          and worker.leaving_date is not null
          and member.work_date <= worker.leaving_date
          then 'employment_window'
        else 'current_unresolved'
      end as worker_status_basis,
      case
        when nullif(
          member.assignment ->> 'supervisor_auth_user_id', ''
        ) is null then false
        when member.assignment ->> 'source' = 'attendance_snapshot' then true
        else exists (
          select 1
          from public.v1_profiles supervisor
          where supervisor.auth_user_id = nullif(
            member.assignment ->> 'supervisor_auth_user_id', ''
          )::uuid
            and supervisor.is_active
        )
      end as supervisor_currently_active,
      worker.record_version as worker_record_version,
      trade.trade_name,
      attendance.id as attendance_id,
      attendance.record_version as attendance_record_version,
      attendance.attendance_status,
      attendance.regular_minutes,
      attendance.overtime_minutes,
      attendance.overtime_reason,
      attendance.reason as attendance_reason,
      attendance.created_by_auth_user_id as attendance_created_by,
      attendance.created_at as attendance_created_at,
      attendance.updated_by_auth_user_id as attendance_updated_by,
      attendance.updated_at as attendance_updated_at,
      member.assignment,
      case when attendance.id is not null then jsonb_build_object(
        'team_schedule_link_id', attendance.team_schedule_link_id_snapshot,
        'team_schedule_record_version',
          attendance.team_schedule_record_version_snapshot,
        'calendar_id', attendance.calendar_id_snapshot,
        'calendar_code', attendance.calendar_code_snapshot,
        'calendar_name', attendance.calendar_name_snapshot,
        'calendar_timezone', attendance.calendar_timezone_snapshot,
        'calendar_record_version', attendance.calendar_record_version_snapshot,
        'calendar_date_override_id',
          attendance.calendar_date_override_id_snapshot,
        'calendar_date_override_version',
          attendance.calendar_date_override_version_snapshot,
        'calendar_override_kind', attendance.calendar_override_kind_snapshot,
        'calendar_exception_name',
          attendance.calendar_exception_name_snapshot,
        'day_type_source', attendance.day_type_source_snapshot,
        'iso_weekday', attendance.iso_weekday_snapshot,
        'day_type', attendance.day_type_snapshot,
        'scheduled_minutes', attendance.scheduled_minutes_snapshot,
        'break_minutes', attendance.break_minutes_snapshot,
        'shift_template_id', attendance.shift_template_id_snapshot,
        'shift_code', attendance.shift_code_snapshot,
        'shift_name', attendance.shift_name_snapshot,
        'shift_kind', attendance.shift_kind_snapshot,
        'shift_start_time', attendance.shift_start_time_snapshot,
        'shift_end_time', attendance.shift_end_time_snapshot,
        'shift_scheduled_minutes',
          attendance.shift_scheduled_minutes_snapshot,
        'shift_break_minutes', attendance.shift_break_minutes_snapshot,
        'shift_crosses_midnight', attendance.shift_crosses_midnight_snapshot,
        'shift_work_date_basis', attendance.shift_work_date_basis_snapshot,
        'shift_record_version', attendance.shift_record_version_snapshot,
        'source', 'attendance_snapshot'
      ) else nullif(public.v1_workforce_attendance_schedule_context(
        nullif(member.assignment ->> 'team_id', '')::uuid,
        member.work_date
      ), '{}'::jsonb) || jsonb_build_object(
        'source', 'effective_schedule'
      ) end as schedule,
      allocation.value as allocation
    from members member
    join public.v1_workforce_workers worker on worker.id = member.worker_id
    left join public.v1_workforce_trades trade on trade.id = worker.trade_id
    left join public.v1_workforce_attendance_days attendance
      on attendance.id = member.attendance_id
    left join lateral (
      select jsonb_build_object(
        'allocation_set_id', allocation_set.id,
        'allocation_set_version', allocation_set.record_version,
        'allocation_state', allocation_set.current_state,
        'allocation_revision_id', revision.id,
        'allocation_revision_number', revision.revision_number,
        'attendance_record_version_basis',
          revision.attendance_record_version_basis,
        'total_regular_minutes', coalesce(revision.total_regular_minutes, 0),
        'total_overtime_minutes', coalesce(revision.total_overtime_minutes, 0),
        'line_count', coalesce(lines.line_count, 0),
        'has_interval_overlap', coalesce(lines.has_interval_overlap, false),
        'has_missing_activity', coalesce(lines.has_missing_activity, false),
        'has_off_assignment_target', coalesce(
          lines.has_off_assignment_target, false
        ),
        'has_invalid_target', coalesce(lines.has_invalid_target, false),
        'targets', coalesce(lines.targets, '[]'::jsonb)
      ) as value
      from public.v1_workforce_timesheet_allocation_sets allocation_set
      left join public.v1_workforce_timesheet_allocation_revisions revision
        on revision.id = allocation_set.current_revision_id
      left join lateral (
        select
          count(*)::integer as line_count,
          coalesce(bool_or(
            btrim(coalesce(line.activity_task, '')) = ''
          ), false) as has_missing_activity,
          coalesce(bool_or(
            (line.target_kind = 'project_work' and (
              line.project_id is distinct from nullif(
                member.assignment ->> 'project_id', ''
              )::uuid
              or line.project_scope_id is distinct from nullif(
                member.assignment ->> 'project_scope_id', ''
              )::uuid
            ))
            or (line.target_kind = 'internal_work'
              and line.internal_location_id is distinct from nullif(
                member.assignment ->> 'internal_location_id', ''
              )::uuid)
          ), false) as has_off_assignment_target,
          coalesce(bool_or(
            (line.target_kind = 'project_work' and (
              project.id is null or scope.id is null
              or scope.project_id is distinct from line.project_id
            ))
            or (line.target_kind = 'internal_work' and location.id is null)
          ), false) as has_invalid_target,
          exists (
            select 1
            from public.v1_workforce_timesheet_allocations left_line
            join public.v1_workforce_timesheet_allocations right_line
              on right_line.allocation_revision_id =
                left_line.allocation_revision_id
              and right_line.line_number > left_line.line_number
              and left_line.interval_start_at is not null
              and right_line.interval_start_at is not null
              and tstzrange(
                left_line.interval_start_at, left_line.interval_end_at, '[)'
              ) && tstzrange(
                right_line.interval_start_at, right_line.interval_end_at, '[)'
              )
            where left_line.allocation_revision_id = revision.id
          ) as has_interval_overlap,
          jsonb_agg(jsonb_build_object(
            'line_number', line.line_number,
            'target_kind', line.target_kind,
            'project_id', line.project_id,
            'project_ref', line.project_ref_snapshot,
            'project_name', line.project_name_snapshot,
            'project_scope_id', line.project_scope_id,
            'project_scope_kind', line.project_scope_kind_snapshot,
            'project_scope_code', line.project_scope_code_snapshot,
            'project_scope_name', line.project_scope_name_snapshot,
            'internal_location_id', line.internal_location_id,
            'internal_location_code', line.internal_location_code_snapshot,
            'internal_location_name', line.internal_location_name_snapshot,
            'activity_task', line.activity_task,
            'notes', line.notes,
            'regular_minutes', line.regular_minutes,
            'overtime_minutes', line.overtime_minutes,
            'start_time_local', line.start_time_local,
            'end_time_local', line.end_time_local,
            'interval_start_at', line.interval_start_at,
            'interval_end_at', line.interval_end_at,
            'crosses_midnight', line.crosses_midnight
          ) order by line.line_number) as targets
        from public.v1_workforce_timesheet_allocations line
        left join public.v1_projects project on project.id = line.project_id
        left join public.v1_project_scopes scope
          on scope.id = line.project_scope_id
        left join public.v1_workforce_internal_locations location
          on location.id = line.internal_location_id
        where line.allocation_revision_id = revision.id
      ) lines on true
      where allocation_set.worker_id = member.worker_id
        and allocation_set.work_date = member.work_date
    ) allocation on true
  )
  select jsonb_build_object(
    'worker_id', source.worker_id,
    'work_date', source.work_date,
    'worker', jsonb_build_object(
      'worker_id', source.worker_id,
      'worker_number', source.worker_number,
      'worker_name', source.full_name,
      'trade_name', source.trade_name,
      'employer_name', source.employer_company,
      'joining_date', source.joining_date,
      'leaving_date', source.leaving_date,
      'current_status', source.current_status,
      'status_basis', source.worker_status_basis,
      'supervisor_currently_active', source.supervisor_currently_active,
      'record_version', source.worker_record_version
    ),
    'assignment', source.assignment,
    'schedule', source.schedule,
    'attendance', case when source.attendance_id is null then null
      else jsonb_build_object(
        'attendance_day_id', source.attendance_id,
        'record_version', source.attendance_record_version,
        'attendance_status', source.attendance_status,
        'regular_minutes', source.regular_minutes,
        'overtime_minutes', source.overtime_minutes,
        'overtime_reason', source.overtime_reason,
        'reason', source.attendance_reason,
        'created_by_auth_user_id', source.attendance_created_by,
        'created_at', source.attendance_created_at,
        'updated_by_auth_user_id', source.attendance_updated_by,
        'updated_at', source.attendance_updated_at
      ) end,
    'allocation', source.allocation,
    'is_future', case
      when source.schedule is null then false
      else source.work_date > (
        clock_timestamp() at time zone (source.schedule ->> 'calendar_timezone')
      )::date
    end,
    'is_required', case
      when source.schedule is null then false
      when source.work_date > (
        clock_timestamp() at time zone (source.schedule ->> 'calendar_timezone')
      )::date then false
      else source.schedule ->> 'day_type' = 'regular_working_day'
        and coalesce((source.schedule ->> 'scheduled_minutes')::integer, 0) > 0
    end
  )
  from source
  order by source.worker_id, source.work_date;
$$;

-- The original T06 validator asked today's profile row whether every retained
-- supervisor was still active. T03 retained the supervisor identity at the
-- accepted work date, so only prospective rows may use current profile state.
-- Patch the one narrow condition rather than duplicating the complete trusted
-- command in this forward migration; fail the migration if the expected
-- accepted T06 function body is not present exactly once.
do $patch_validator$
declare
  v_definition text;
  v_old text := E'if nullif(v_assignment ->> ''supervisor_auth_user_id'', '''') is not null\n        and not exists (';
  v_new text := E'if v_assignment ->> ''source'' <> ''attendance_snapshot''\n        and nullif(v_assignment ->> ''supervisor_auth_user_id'', '''') is not null\n        and not exists (';
begin
  select pg_get_functiondef(
    'public.v1_validate_workforce_monthly_period(jsonb,bigint,uuid)'::regprocedure
  ) into v_definition;

  if v_definition is null then
    raise exception 'V1_WORKFORCE_T06_VALIDATOR_PATCH_SOURCE_MISMATCH';
  end if;

  if strpos(v_definition, v_new) > 0
    and strpos(v_definition, v_old) = 0
  then
    return;
  end if;
  if strpos(v_definition, v_old) = 0
    or strpos(v_definition, v_new) > 0
  then
    raise exception 'V1_WORKFORCE_T06_VALIDATOR_PATCH_SOURCE_MISMATCH';
  end if;

  v_definition := replace(v_definition, v_old, v_new);
  if strpos(v_definition, v_old) > 0
    or strpos(v_definition, v_new) = 0
  then
    raise exception 'V1_WORKFORCE_T06_VALIDATOR_PATCH_NOT_UNIQUE';
  end if;
  execute v_definition;
end;
$patch_validator$;

create or replace function public.v1_workforce_monthly_guard_date_context()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_added integer := 0;
begin
  if nullif(new.assignment_snapshot ->> 'valid_from', '') is null
    or new.work_date < (new.assignment_snapshot ->> 'valid_from')::date
    or (
      nullif(new.assignment_snapshot ->> 'valid_to', '') is not null
      and new.work_date > (new.assignment_snapshot ->> 'valid_to')::date
    )
  then
    perform public.v1_workforce_monthly_add_issue(
      new.validation_run_id, new.worker_id, new.work_date, 'blocking',
      'assignment_invalid',
      jsonb_build_object('reason', 'retained_window_mismatch'), 105
    );
    v_added := v_added + 1;
  end if;

  if nullif(
    new.assignment_snapshot ->> 'supervisor_auth_user_id', ''
  ) is null then
    perform public.v1_workforce_monthly_add_issue(
      new.validation_run_id, new.worker_id, new.work_date, 'blocking',
      'supervisor_invalid',
      jsonb_build_object('reason', 'missing_supervisor'), 110
    );
    v_added := v_added + 1;
  end if;

  if v_added > 0 then
    new.blocking_issue_count := new.blocking_issue_count + v_added;
    new.daily_status := 'has_errors';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_workforce_monthly_dates_context_guard
  on public.v1_workforce_monthly_period_dates;
create trigger v1_workforce_monthly_dates_context_guard
before insert on public.v1_workforce_monthly_period_dates
for each row execute function public.v1_workforce_monthly_guard_date_context();

revoke all on function public.v1_workforce_monthly_guard_date_context()
  from public, anon, authenticated;
grant execute on function public.v1_workforce_monthly_guard_date_context()
  to service_role;

commit;
