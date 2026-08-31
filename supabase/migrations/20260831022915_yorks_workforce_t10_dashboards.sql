-- Yorks Workforce T10: protected read-only operational dashboards.
--
-- This additive slice creates no business row and promotes no capability. It
-- composes accepted T01-T09 facts into Supervisor, Management and Admin
-- summaries. Every date is derived from the exact linked calendar timezone.

begin;

-- T09 already treats these as optional typed validation evidence, but the T06
-- vocabulary predated that report. T10 does not manufacture either issue: it
-- only makes the two accepted typed codes representable and counts them when
-- a later configured validator has actually emitted them.
alter table public.v1_workforce_monthly_validation_issues
  drop constraint if exists
    v1_workforce_monthly_validation_issues_issue_code_check;
alter table public.v1_workforce_monthly_validation_issues
  add constraint v1_workforce_monthly_validation_issues_issue_code_check
  check (issue_code in (
    'schedule_context_missing', 'required_attendance_missing',
    'attendance_status_invalid', 'attendance_minutes_invalid',
    'absent_with_work_minutes', 'leave_with_work_minutes',
    'allocation_minutes_mismatch', 'allocation_interval_overlap',
    'daily_minutes_over_1440', 'attendance_before_joining',
    'attendance_after_leaving', 'worker_inactive',
    'assignment_invalid', 'supervisor_invalid',
    'allocation_target_invalid', 'validation_stale',
    'work_on_weekly_off', 'work_on_public_holiday',
    'work_on_site_closure', 'below_standard_minutes',
    'assignment_changed_in_period', 'supervisor_changed_in_period',
    'activity_missing', 'allocation_off_assignment',
    'attendance_backdated', 'overtime_limit_exceeded',
    'supporting_evidence_missing'
  ));

create or replace function public.v1_workforce_t10_team_contexts()
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'team_id', team.id,
    'team_code', team.team_code,
    'team_name', team.team_name,
    'department', team.department,
    'project_id', actual_target.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'project_state', project.state,
    'internal_location_id', actual_target.internal_location_id,
    'internal_location_name', location.location_name,
    'supervisor_auth_user_id', team.default_supervisor_auth_user_id,
    'supervisor_name', supervisor.display_name,
    'calendar_id', calendar.id,
    'calendar_name', calendar.calendar_name,
    'calendar_timezone', calendar.timezone_name,
    'local_date', local_clock.local_date,
    'period_month', date_trunc('month', local_clock.local_date)::date,
    'schedule_link_id', schedule.id
  )
  from public.v1_workforce_teams team
  join public.v1_workforce_team_schedule_links schedule
    on schedule.team_id = team.id
  join public.v1_workforce_calendars calendar
    on calendar.id = schedule.calendar_id
  cross join lateral (
    select (statement_timestamp() at time zone calendar.timezone_name)::date
      as local_date
  ) local_clock
  left join lateral (
    with current_source as materialized (
      select attendance.worker_id,
        attendance.assignment_project_id_snapshot as project_id,
        attendance.assignment_internal_location_id_snapshot
          as internal_location_id
      from public.v1_workforce_attendance_days attendance
      where attendance.work_date = local_clock.local_date
        and attendance.assignment_team_id_snapshot = team.id
      union all
      select worker.id,
        nullif(assignment.value ->> 'project_id', '')::uuid,
        nullif(assignment.value ->> 'internal_location_id', '')::uuid
      from public.v1_workforce_workers worker
      cross join lateral (
        select public.v1_workforce_effective_assignment(
          worker.id, local_clock.local_date
        ) as value
      ) assignment
      where worker.current_status = 'active'
        and worker.joining_date <= local_clock.local_date
        and (worker.leaving_date is null
          or worker.leaving_date >= local_clock.local_date)
        and nullif(assignment.value ->> 'team_id', '')::uuid = team.id
        and not exists (
          select 1
          from public.v1_workforce_attendance_days attendance
          where attendance.worker_id = worker.id
            and attendance.work_date = local_clock.local_date
        )
    )
    select case when count(distinct project_id) = 1
        then min(project_id::text)::uuid end as project_id,
      case when count(distinct internal_location_id) = 1
        then min(internal_location_id::text)::uuid end as internal_location_id
    from current_source
  ) actual_target on true
  left join public.v1_projects project on project.id = actual_target.project_id
  left join public.v1_workforce_internal_locations location
    on location.id = actual_target.internal_location_id
  left join public.v1_profiles supervisor
    on supervisor.auth_user_id = team.default_supervisor_auth_user_id
  where team.is_active
    and team.valid_from <= local_clock.local_date
    and (team.valid_to is null or team.valid_to >= local_clock.local_date)
    and schedule.valid_from <= local_clock.local_date
    and (schedule.valid_to is null or schedule.valid_to >= local_clock.local_date)
    and calendar.valid_from <= local_clock.local_date
    and (calendar.valid_to is null or calendar.valid_to >= local_clock.local_date)
  order by lower(team.team_name), team.id;
$$;

create or replace function public.v1_workforce_t10_team_authorized(
  p_team_context jsonb,
  p_capability_key text default 'workforce.view'
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_team_id uuid := nullif(p_team_context ->> 'team_id', '')::uuid;
  v_local_date date := nullif(p_team_context ->> 'local_date', '')::date;
  v_role text;
  v_candidate_count bigint;
begin
  if v_actor is null or v_team_id is null or v_local_date is null
    or p_capability_key not in (
      'workforce.view', 'workforce.attendance.maintain',
      'workforce.timesheets.maintain', 'workforce.timesheets.review',
      'workforce.timesheets.verify', 'workforce.timesheets.final_approve',
      'workforce.periods.reopen'
    )
    or not public.v1_current_actor_is_active()
  then
    return false;
  end if;

  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' then
    return false;
  end if;

  with candidate as materialized (
    select attendance.worker_id,
      jsonb_build_object(
        'team_id', attendance.assignment_team_id_snapshot,
        'project_id', attendance.assignment_project_id_snapshot,
        'project_scope_id', attendance.assignment_project_scope_id_snapshot,
        'internal_location_id',
          attendance.assignment_internal_location_id_snapshot
      ) as assignment
    from public.v1_workforce_attendance_days attendance
    where attendance.work_date = v_local_date
      and attendance.assignment_team_id_snapshot = v_team_id
    union all
    select worker.id as worker_id, assignment.value
    from public.v1_workforce_workers worker
    cross join lateral (
      select public.v1_workforce_effective_assignment(
        worker.id, v_local_date
      ) as value
    ) assignment
    where worker.current_status = 'active'
      and worker.joining_date <= v_local_date
      and (worker.leaving_date is null or worker.leaving_date >= v_local_date)
      and nullif(assignment.value ->> 'team_id', '')::uuid = v_team_id
      and not exists (
        select 1
        from public.v1_workforce_attendance_days attendance
        where attendance.worker_id = worker.id
          and attendance.work_date = v_local_date
      )
  ), scoped as materialized (
    select candidate.worker_id, candidate.assignment
    from candidate
    where nullif(candidate.assignment ->> 'team_id', '')::uuid = v_team_id
  )
  select count(*) into v_candidate_count from scoped;

  if v_candidate_count = 0 then
    return exists (
      select 1
      from public.v1_workforce_responsibility_assignments responsibility
      where responsibility.auth_user_id = v_actor
        and responsibility.valid_from <= v_local_date
        and (responsibility.valid_to is null
          or responsibility.valid_to >= v_local_date)
        and (
          responsibility.scope_kind = 'organization'
          or (responsibility.scope_kind = 'team'
            and responsibility.team_id = v_team_id)
        )
    ) and public.v1_current_user_has_capability(p_capability_key, null);
  end if;

  return not exists (
    with candidate as materialized (
      select attendance.worker_id,
        jsonb_build_object(
          'team_id', attendance.assignment_team_id_snapshot,
          'project_id', attendance.assignment_project_id_snapshot,
          'project_scope_id', attendance.assignment_project_scope_id_snapshot,
        'internal_location_id',
          attendance.assignment_internal_location_id_snapshot
        ) as assignment
      from public.v1_workforce_attendance_days attendance
      where attendance.work_date = v_local_date
        and attendance.assignment_team_id_snapshot = v_team_id
      union all
      select worker.id as worker_id, assignment.value
      from public.v1_workforce_workers worker
      cross join lateral (
        select public.v1_workforce_effective_assignment(
          worker.id, v_local_date
        ) as value
      ) assignment
      where worker.current_status = 'active'
        and worker.joining_date <= v_local_date
        and (worker.leaving_date is null or worker.leaving_date >= v_local_date)
        and nullif(assignment.value ->> 'team_id', '')::uuid = v_team_id
        and not exists (
          select 1
          from public.v1_workforce_attendance_days attendance
          where attendance.worker_id = worker.id
            and attendance.work_date = v_local_date
        )
    ), scoped as materialized (
      select candidate.worker_id, candidate.assignment
      from candidate
      where nullif(candidate.assignment ->> 'team_id', '')::uuid = v_team_id
    )
    select 1
    from scoped
    where not public.v1_current_user_has_capability(
        p_capability_key,
        nullif(scoped.assignment ->> 'project_id', '')::uuid
      )
      or public.v1_workforce_matching_responsibility(
        v_actor, scoped.worker_id, v_local_date, v_team_id,
        nullif(scoped.assignment ->> 'project_id', '')::uuid,
        nullif(scoped.assignment ->> 'project_scope_id', '')::uuid,
        nullif(scoped.assignment ->> 'internal_location_id', '')::uuid
      ) = '{}'::jsonb
      or exists (
        select 1
        from public.v1_workforce_timesheet_allocation_sets allocation_set
        join public.v1_workforce_timesheet_allocations allocation
          on allocation.allocation_revision_id =
            allocation_set.current_revision_id
        where allocation_set.worker_id = scoped.worker_id
          and allocation_set.work_date = v_local_date
          and allocation_set.current_state = 'active'
          and (
            not public.v1_current_user_has_capability(
              p_capability_key,
              case when allocation.target_kind = 'project_work'
                then allocation.project_id else null end
            )
            or not exists (
              select 1
              from public.v1_workforce_responsibility_assignments responsibility
              where responsibility.auth_user_id = v_actor
                and responsibility.valid_from <= v_local_date
                and (responsibility.valid_to is null
                  or responsibility.valid_to >= v_local_date)
                and (
                  responsibility.scope_kind = 'organization'
                  or (allocation.target_kind = 'project_work' and (
                    (responsibility.scope_kind = 'project'
                      and responsibility.project_id = allocation.project_id)
                    or (responsibility.scope_kind = 'project_scope'
                      and responsibility.project_id = allocation.project_id
                      and responsibility.project_scope_id =
                        allocation.project_scope_id)
                  ))
                  or (allocation.target_kind = 'internal_work'
                    and responsibility.scope_kind = 'internal_location'
                    and responsibility.internal_location_id =
                      allocation.internal_location_id)
                )
            )
          )
      )
  );
end;
$$;

create or replace function public.v1_workforce_t10_organization_authorized(
  p_capability_key text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_first_date date;
  v_last_date date;
begin
  if v_actor is null
    or public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(p_capability_key, null)
  then
    return false;
  end if;

  select min((context ->> 'local_date')::date),
    max((context ->> 'local_date')::date)
  into v_first_date, v_last_date
  from public.v1_workforce_t10_team_contexts() context;
  v_first_date := coalesce(v_first_date,
    (statement_timestamp() at time zone 'UTC')::date);
  v_last_date := coalesce(v_last_date, v_first_date);

  return exists (
    select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = v_actor
      and responsibility.scope_kind = 'organization'
      and responsibility.valid_from <= v_first_date
      and (responsibility.valid_to is null
        or responsibility.valid_to >= v_last_date)
  );
end;
$$;

create or replace function public.v1_workforce_t10_period_authorized(
  p_capability_key text,
  p_period_id uuid,
  p_require_targets boolean default true
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_date public.v1_workforce_monthly_period_dates%rowtype;
  v_target jsonb;
  v_month_end date;
begin
  if v_actor is null or p_period_id is null or p_capability_key not in (
      'workforce.view', 'workforce.timesheets.maintain',
      'workforce.timesheets.review',
      'workforce.timesheets.correct_during_review',
      'workforce.timesheets.verify',
      'workforce.timesheets.final_approve', 'workforce.periods.reopen'
    )
    or public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_actor_is_active()
  then
    return false;
  end if;
  select * into v_period
  from public.v1_workforce_monthly_periods period
  where period.id = p_period_id;
  if not found then
    return false;
  end if;
  v_month_end := (v_period.period_month + interval '1 month - 1 day')::date;

  if not exists (
    select 1
    from public.v1_workforce_monthly_period_dates period_date
    where period_date.validation_run_id = v_period.current_validation_run_id
  ) then
    return public.v1_current_user_has_capability(p_capability_key, null)
      and exists (
        select 1
        from public.v1_workforce_responsibility_assignments responsibility
        where responsibility.auth_user_id = v_actor
          and responsibility.valid_from <= v_period.period_month
          and (responsibility.valid_to is null
            or responsibility.valid_to >= v_month_end)
          and (
            responsibility.scope_kind = 'organization'
            or (responsibility.scope_kind = 'team'
              and responsibility.team_id = v_period.team_id)
          )
      );
  end if;

  for v_date in
    select *
    from public.v1_workforce_monthly_period_dates period_date
    where period_date.validation_run_id = v_period.current_validation_run_id
  loop
    if not public.v1_current_user_has_capability(
        p_capability_key,
        nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid
      )
      or public.v1_workforce_matching_responsibility(
        v_actor, v_date.worker_id, v_date.work_date,
        nullif(v_date.assignment_snapshot ->> 'team_id', '')::uuid,
        nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid,
        nullif(v_date.assignment_snapshot ->> 'project_scope_id', '')::uuid,
        nullif(v_date.assignment_snapshot ->> 'internal_location_id', '')::uuid
      ) = '{}'::jsonb
    then
      return false;
    end if;

    if p_require_targets
      and v_date.allocation_snapshot ->> 'allocation_state' = 'active'
    then
      for v_target in
        select value
        from jsonb_array_elements(coalesce(
          v_date.allocation_snapshot -> 'targets', '[]'::jsonb
        ))
      loop
        if not public.v1_current_user_has_capability(
            p_capability_key,
            case when v_target ->> 'target_kind' = 'project_work'
              then nullif(v_target ->> 'project_id', '')::uuid else null end
          )
          or not exists (
            select 1
            from public.v1_workforce_responsibility_assignments responsibility
            where responsibility.auth_user_id = v_actor
              and responsibility.valid_from <= v_date.work_date
              and (responsibility.valid_to is null
                or responsibility.valid_to >= v_date.work_date)
              and (
                responsibility.scope_kind = 'organization'
                or (v_target ->> 'target_kind' = 'project_work' and (
                  (responsibility.scope_kind = 'project'
                    and responsibility.project_id =
                      nullif(v_target ->> 'project_id', '')::uuid)
                  or (responsibility.scope_kind = 'project_scope'
                    and responsibility.project_id =
                      nullif(v_target ->> 'project_id', '')::uuid
                    and responsibility.project_scope_id =
                      nullif(v_target ->> 'project_scope_id', '')::uuid)
                ))
                or (v_target ->> 'target_kind' = 'internal_work'
                  and responsibility.scope_kind = 'internal_location'
                  and responsibility.internal_location_id =
                    nullif(v_target ->> 'internal_location_id', '')::uuid)
              )
          )
        then
          return false;
        end if;
      end loop;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t10_period_matches_project(
  p_period_id uuid,
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_project_id is null or exists (
    select 1
    from public.v1_workforce_monthly_periods period
    join public.v1_workforce_monthly_period_dates period_date
      on period_date.validation_run_id = period.current_validation_run_id
    where period.id = p_period_id
      and (
        nullif(period_date.assignment_snapshot ->> 'project_id', '')::uuid =
          p_project_id
        or exists (
          select 1
          from jsonb_array_elements(coalesce(
            period_date.allocation_snapshot -> 'targets', '[]'::jsonb
          )) target
          where target ->> 'target_kind' = 'project_work'
            and nullif(target ->> 'project_id', '')::uuid = p_project_id
        )
      )
  );
$$;

create or replace function public.v1_workforce_t10_team_matches_project(
  p_team_context jsonb,
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with input as materialized (
    select nullif(p_team_context ->> 'team_id', '')::uuid as team_id,
      nullif(p_team_context ->> 'local_date', '')::date as local_date
  ), current_source as materialized (
    select attendance.worker_id,
      attendance.assignment_project_id_snapshot as project_id
    from input
    join public.v1_workforce_attendance_days attendance
      on attendance.work_date = input.local_date
      and attendance.assignment_team_id_snapshot = input.team_id
    union all
    select worker.id,
      nullif(assignment.value ->> 'project_id', '')::uuid
    from input
    join public.v1_workforce_workers worker
      on worker.current_status = 'active'
      and worker.joining_date <= input.local_date
      and (worker.leaving_date is null
        or worker.leaving_date >= input.local_date)
    cross join lateral (
      select public.v1_workforce_effective_assignment(
        worker.id, input.local_date
      ) as value
    ) assignment
    where nullif(assignment.value ->> 'team_id', '')::uuid = input.team_id
      and not exists (
        select 1
        from public.v1_workforce_attendance_days attendance
        where attendance.worker_id = worker.id
          and attendance.work_date = input.local_date
      )
  ), project_targets as (
    select source.worker_id, source.project_id
    from current_source source
    union
    select source.worker_id, allocation.project_id
    from current_source source
    cross join input
    join public.v1_workforce_timesheet_allocation_sets allocation_set
      on allocation_set.worker_id = source.worker_id
      and allocation_set.work_date = input.local_date
      and allocation_set.current_state = 'active'
    join public.v1_workforce_timesheet_allocations allocation
      on allocation.allocation_revision_id = allocation_set.current_revision_id
      and allocation.target_kind = 'project_work'
  )
  select p_project_id is null or exists (
    select 1
    from project_targets target
    join public.v1_projects project on project.id = target.project_id
    where target.project_id = p_project_id
      and project.state = 'active'
  );
$$;

create or replace function public.v1_workforce_t10_team_metrics(
  p_team_context jsonb
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  with input as materialized (
    select
      (p_team_context ->> 'team_id')::uuid as team_id,
      (p_team_context ->> 'local_date')::date as local_date,
      (p_team_context ->> 'period_month')::date as period_month
  ), candidate as materialized (
    select attendance.worker_id
    from public.v1_workforce_attendance_days attendance, input
    where attendance.work_date = input.local_date
      and attendance.assignment_team_id_snapshot = input.team_id
    union all
    select worker.id as worker_id
    from public.v1_workforce_workers worker, input
    where worker.current_status = 'active'
      and worker.joining_date <= input.local_date
      and (worker.leaving_date is null
        or worker.leaving_date >= input.local_date)
      and nullif(public.v1_workforce_effective_assignment(
        worker.id, input.local_date
      ) ->> 'team_id', '')::uuid = input.team_id
      and not exists (
        select 1
        from public.v1_workforce_attendance_days attendance
        where attendance.worker_id = worker.id
          and attendance.work_date = input.local_date
      )
  ), today as materialized (
    select candidate.worker_id, attendance.attendance_status
    from candidate
    cross join input
    left join public.v1_workforce_attendance_days attendance
      on attendance.worker_id = candidate.worker_id
      and attendance.work_date = input.local_date
  ), month_source as materialized (
    select source_row
    from input
    cross join lateral public.v1_workforce_monthly_source_rows(
      input.team_id, input.period_month
    ) source_row
    where (source_row ->> 'work_date')::date <= input.local_date
      and coalesce((source_row ->> 'is_required')::boolean, false)
  ), month_completion as (
    select count(*)::bigint as required_count,
      count(*) filter (
        where nullif(source_row #>> '{attendance,attendance_status}', '')
          is not null
          and source_row #>> '{attendance,attendance_status}' <> 'not_entered'
      )::bigint as entered_count
    from month_source
  ), current_period as (
    select period.id, period.current_status,
      period.current_approval_revision_number,
      run.warning_issue_count
    from input
    join public.v1_workforce_monthly_periods period
      on period.team_id = input.team_id
      and period.period_month = input.period_month
    left join public.v1_workforce_monthly_validation_runs run
      on run.id = period.current_validation_run_id
  ), current_corrections as (
    select count(*)::integer as correction_count
    from current_period period
    join public.v1_workforce_monthly_reviewer_corrections correction
      on correction.period_id = period.id
      and correction.approval_revision_number =
        period.current_approval_revision_number
  ), attendance_authority as (
    select public.v1_workforce_t10_team_authorized(
      p_team_context, 'workforce.attendance.maintain'
    ) as can_complete
  )
  select jsonb_build_object(
    'worker_count', (select count(*) from today),
    'present_count', (select count(*) from today
      where attendance_status = 'present'),
    'absent_count', (select count(*) from today
      where attendance_status = 'absent'),
    'leave_count', (select count(*) from today
      where attendance_status in (
        'annual_leave', 'sick_leave', 'official_leave', 'unpaid_leave'
      )),
    'not_entered_count', (select count(*) from today
      where attendance_status is null or attendance_status = 'not_entered'),
    'today_entered_count', (select count(*) from today
      where attendance_status is not null
        and attendance_status <> 'not_entered'),
    'today_completion_percent', coalesce((select round(
      100.0 * count(*) filter (where attendance_status is not null
        and attendance_status <> 'not_entered') / nullif(count(*), 0), 1
    ) from today), 0),
    'month_required_count', (select required_count from month_completion),
    'month_entered_count', (select entered_count from month_completion),
    'month_completion_percent', coalesce((select round(
      100.0 * entered_count / nullif(required_count, 0), 1
    ) from month_completion), 0),
    'warning_count', coalesce((select warning_issue_count
      from current_period), 0),
    'returned_correction_count',
      (select count(*) from current_period
        where current_status = 'returned_for_correction')
      + coalesce((select correction_count from current_corrections), 0),
    'can_complete_today_attendance',
      coalesce((select can_complete from attendance_authority), false)
  );
$$;

create or replace function public.v1_workforce_t10_review_queue_item(
  p_period_id uuid
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'period_id', period.id,
    'team_id', period.team_id,
    'team_name', team.team_name,
    'period_month', period.period_month,
    'status', period.current_status,
    'record_version', period.record_version,
    'submitted_by_auth_user_id', submitter.actor_auth_user_id,
    'submitted_by_name', submitter_profile.display_name,
    'worker_count', coalesce(run.worker_count, 0),
    'regular_minutes', coalesce(run.regular_minutes, 0),
    'overtime_minutes', coalesce(run.overtime_minutes, 0),
    'warning_count', coalesce(run.warning_issue_count, 0),
    'blocking_issue_count', coalesce(run.blocking_issue_count, 0),
    'reviewer_correction_count', coalesce(corrections.value, 0),
    'missing_supporting_evidence_count', issues.supporting_count,
    'supporting_evidence_policy', case when issues.supporting_count > 0
      then 'typed_validation_issue' else 'not_configured' end,
    'high_overtime_exception_count', issues.overtime_count,
    'overtime_limit_policy', case when issues.overtime_count > 0
      then 'typed_validation_issue' else 'not_configured' end,
    'can_return', case when coalesce(
        (lifecycle.value ->> 'can_return')::boolean, false
      ) then public.v1_workforce_t10_period_authorized(
        'workforce.timesheets.review', period.id, true
      ) else false end,
    'can_correct', case when coalesce(
        (lifecycle.value ->> 'can_correct')::boolean, false
      ) then public.v1_workforce_t10_period_authorized(
        'workforce.timesheets.correct_during_review', period.id, true
      ) else false end,
    'can_verify', case when coalesce(
        (lifecycle.value ->> 'can_verify')::boolean, false
      ) then public.v1_workforce_t10_period_authorized(
        'workforce.timesheets.verify', period.id, true
      ) else false end,
    'can_final_approve', case when coalesce(
        (lifecycle.value ->> 'can_final_approve')::boolean, false
      ) then public.v1_workforce_t10_period_authorized(
        'workforce.timesheets.final_approve', period.id, true
      ) else false end,
    'updated_at', period.updated_at,
    'exception_priority', coalesce(run.blocking_issue_count, 0) * 1000
      + coalesce(run.warning_issue_count, 0) * 10
      + coalesce(corrections.value, 0)
      + issues.supporting_count * 20
      + issues.overtime_count * 20
      + case when period.current_status = 'returned_for_correction'
          then 100 else 0 end
  )
  from public.v1_workforce_monthly_periods period
  join public.v1_workforce_teams team on team.id = period.team_id
  left join public.v1_workforce_monthly_validation_runs run
    on run.id = period.current_validation_run_id
  left join lateral (
    select transition.actor_auth_user_id
    from public.v1_workforce_monthly_transitions transition
    where transition.period_id = period.id
      and transition.approval_revision_number =
        period.current_approval_revision_number
      and transition.action_kind = 'submit'
    order by transition.occurred_at desc, transition.id desc
    limit 1
  ) submitter on true
  left join public.v1_profiles submitter_profile
    on submitter_profile.auth_user_id = submitter.actor_auth_user_id
  left join lateral (
    select count(*)::integer as value
    from public.v1_workforce_monthly_reviewer_corrections correction
    where correction.period_id = period.id
      and correction.approval_revision_number =
        period.current_approval_revision_number
  ) corrections on true
  left join lateral (
    select count(*) filter (
        where issue.issue_code = 'supporting_evidence_missing'
      )::integer as supporting_count,
      count(*) filter (
        where issue.issue_code = 'overtime_limit_exceeded'
      )::integer as overtime_count
    from public.v1_workforce_monthly_validation_issues issue
    where issue.validation_run_id = period.current_validation_run_id
  ) issues on true
  cross join lateral (
    select public.v1_workforce_monthly_lifecycle_json(period.id) as value
  ) lifecycle
  where period.id = p_period_id;
$$;

create or replace function public.v1_get_workforce_overview(
  p_request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_kind text;
  v_team_id uuid;
  v_project_id uuid;
  v_contexts jsonb;
  v_as_of_groups jsonb;
  v_summary jsonb;
  v_projects jsonb := '[]'::jsonb;
  v_queue jsonb := '[]'::jsonb;
  v_all_queue jsonb := '[]'::jsonb;
  v_actions jsonb := '{}'::jsonb;
  v_overtime_policy text := 'not_configured';
  v_supporting_policy text := 'not_configured';
  v_authorized_period_count bigint := 0;
  v_authorized_period_ids uuid[] := array[]::uuid[];
begin
  if v_actor is null or p_request is null
    or jsonb_typeof(p_request) <> 'object'
    or exists (
      select 1 from jsonb_object_keys(p_request) key
      where key not in ('overview_kind', 'team_id', 'project_id')
    )
  then
    raise exception 'V1_WORKFORCE_T10_READ_INVALID' using errcode = '22023';
  end if;

  v_kind := nullif(btrim(coalesce(p_request ->> 'overview_kind', '')), '');
  begin
    v_team_id := nullif(p_request ->> 'team_id', '')::uuid;
    v_project_id := nullif(p_request ->> 'project_id', '')::uuid;
  exception when others then
    raise exception 'V1_WORKFORCE_T10_READ_INVALID' using errcode = '22023';
  end;
  if v_kind not in ('supervisor', 'management', 'admin')
    or (v_kind <> 'supervisor' and v_team_id is not null)
    or (v_kind <> 'management' and v_project_id is not null)
  then
    raise exception 'V1_WORKFORCE_T10_READ_INVALID' using errcode = '22023';
  end if;

  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active()
    or (v_kind = 'admin' and (
      v_role <> 'admin'
      or not public.v1_workforce_t10_organization_authorized(
        'workforce.view'
      )
    ))
    or (v_kind = 'management' and v_role not in (
      'project_manager', 'senior_mechanical_engineer'
    ))
  then
    raise exception 'V1_WORKFORCE_T10_READ_DENIED' using errcode = '42501';
  end if;

  if v_kind = 'admin' then
    select coalesce(array_agg(period.id), array[]::uuid[])
    into v_authorized_period_ids
    from public.v1_workforce_monthly_periods period
    where public.v1_workforce_t10_period_authorized(
      'workforce.view', period.id, true
    );

    with contexts as materialized (
      select context
      from public.v1_workforce_t10_team_contexts() context
    ), measured as materialized (
      select context,
        public.v1_workforce_t10_team_metrics(context) as metrics
      from contexts
    )
    select
      coalesce(jsonb_agg(context || jsonb_build_object('metrics', metrics)
        order by lower(context ->> 'team_name'), context ->> 'team_id'),
        '[]'::jsonb),
      coalesce((select jsonb_agg(jsonb_build_object(
        'calendar_timezone', grouped.timezone_name,
        'local_date', grouped.local_date,
        'team_count', grouped.team_count
      ) order by grouped.timezone_name, grouped.local_date)
      from (
        select context ->> 'calendar_timezone' as timezone_name,
          (context ->> 'local_date')::date as local_date,
          count(*) as team_count
        from contexts
        group by 1, 2
      ) grouped), '[]'::jsonb),
      jsonb_build_object(
        'active_worker_count', (select count(*)
          from public.v1_workforce_workers worker
          where worker.current_status = 'active'),
        'active_supervisor_count', (select count(distinct
            assignment.supervisor_auth_user_id)
          from public.v1_workforce_worker_assignments assignment
          join public.v1_profiles profile
            on profile.auth_user_id = assignment.supervisor_auth_user_id
            and profile.is_active
          where assignment.supervisor_auth_user_id is not null
            and exists (
              select 1 from contexts
              where nullif(context ->> 'team_id', '')::uuid = assignment.team_id
                and assignment.valid_from <=
                  (context ->> 'local_date')::date
                and (assignment.valid_to is null or assignment.valid_to >=
                  (context ->> 'local_date')::date)
            )),
        'missing_today_count', coalesce(sum(
          (metrics ->> 'not_entered_count')::integer
        ), 0),
        'monthly_pending_count', (select count(*)
          from public.v1_workforce_monthly_periods period
          where period.current_status in (
            'draft', 'ready_for_review', 'submitted', 'under_review', 'reopened'
          ) and period.id = any(v_authorized_period_ids)),
        'returned_count', (select count(*)
          from public.v1_workforce_monthly_periods period
          where period.current_status = 'returned_for_correction'
            and period.id = any(v_authorized_period_ids)),
        'awaiting_final_count', (select count(*)
          from public.v1_workforce_monthly_periods period
          where period.current_status = 'awaiting_final_approval'
            and period.id = any(v_authorized_period_ids)),
        'locked_count', (select count(*)
          from public.v1_workforce_monthly_periods period
          where period.current_status = 'locked'
            and period.id = any(v_authorized_period_ids)),
        'reopen_request_count', (select count(*)
          from public.v1_workforce_monthly_reopen_requests request
          join public.v1_workforce_monthly_periods period
            on period.id = request.period_id
          where request.authorized_at is null
            and period.id = any(v_authorized_period_ids)),
        'configuration_issue_count', (select count(distinct issue_identity)
          from (
            select 'schedule_context_missing:' || team.id::text
              as issue_identity
            from public.v1_workforce_teams team
            where team.is_active and not exists (
              select 1 from contexts
              where nullif(context ->> 'team_id', '')::uuid = team.id
            )
            union all
            select 'supervisor_invalid:' ||
              (context ->> 'team_id') as issue_identity
            from contexts
            where nullif(context ->> 'supervisor_auth_user_id', '') is null
            union all
            select issue.issue_code || ':' || period.team_id::text
              as issue_identity
            from public.v1_workforce_monthly_periods period
            join public.v1_workforce_monthly_validation_issues issue
              on issue.validation_run_id = period.current_validation_run_id
            where issue.issue_code in (
                'schedule_context_missing', 'assignment_invalid',
                'supervisor_invalid', 'allocation_target_invalid'
              )
              and period.id = any(v_authorized_period_ids)
          ) typed_issue)
      )
    into v_contexts, v_as_of_groups, v_summary
    from measured;

    with pending as materialized (
      select period.id
      from public.v1_workforce_monthly_periods period
      where period.current_status in (
        'submitted', 'under_review', 'returned_for_correction',
        'awaiting_final_approval'
      )
        and period.id = any(v_authorized_period_ids)
    ), candidate as materialized (
      select public.v1_workforce_t10_review_queue_item(pending.id) as value
      from pending
    )
    select coalesce(jsonb_agg(candidate.value order by
      (candidate.value ->> 'exception_priority')::integer desc,
      candidate.value ->> 'period_month' desc,
      lower(candidate.value ->> 'team_name'), candidate.value ->> 'period_id'),
      '[]'::jsonb)
    into v_all_queue
    from candidate;

    select coalesce(jsonb_agg(page.value order by page.ordinality), '[]'::jsonb)
    into v_queue
    from (
      select item.value, item.ordinality
      from jsonb_array_elements(v_all_queue) with ordinality item
      order by item.ordinality
      limit 12
    ) page;

    select case when coalesce(sum(
        (value ->> 'high_overtime_exception_count')::integer
      ), 0) > 0 then 'typed_validation_issue' else 'not_configured' end,
      case when coalesce(sum(
        (value ->> 'missing_supporting_evidence_count')::integer
      ), 0) > 0 then 'typed_validation_issue' else 'not_configured' end
    into v_overtime_policy, v_supporting_policy
    from jsonb_array_elements(v_all_queue) item(value);

    v_actions := jsonb_build_object(
      'can_open_reopen_queue', exists (
        select 1
        from public.v1_workforce_monthly_reopen_requests request
        cross join lateral (
          select public.v1_workforce_monthly_lifecycle_json(
            request.period_id
          ) as value
        ) lifecycle
        where request.authorized_at is null
          and coalesce((lifecycle.value ->>
            'can_authorize_reopen')::boolean, false)
          and public.v1_workforce_t10_period_authorized(
            'workforce.periods.reopen', request.period_id, true
          )
      ),
      'can_open_final_approval_queue', exists (
        select 1 from jsonb_array_elements(v_all_queue) item
        where coalesce((item ->> 'can_final_approve')::boolean, false)
      )
    );
  else
    with contexts as materialized (
      select context
      from public.v1_workforce_t10_team_contexts() context
      where (v_team_id is null
          or nullif(context ->> 'team_id', '')::uuid = v_team_id)
        and (v_kind <> 'management' or
          public.v1_workforce_t10_team_matches_project(
            context, v_project_id
          ))
        and public.v1_workforce_t10_team_authorized(
          context, 'workforce.view'
        )
    ), measured as materialized (
      select context,
        public.v1_workforce_t10_team_metrics(context) as metrics
      from contexts
    )
    select
      coalesce(jsonb_agg(context || jsonb_build_object('metrics', metrics)
        order by lower(context ->> 'team_name'), context ->> 'team_id'),
        '[]'::jsonb),
      coalesce((select jsonb_agg(jsonb_build_object(
        'calendar_timezone', grouped.timezone_name,
        'local_date', grouped.local_date,
        'team_count', grouped.team_count
      ) order by grouped.timezone_name, grouped.local_date)
      from (
        select context ->> 'calendar_timezone' as timezone_name,
          (context ->> 'local_date')::date as local_date,
          count(*) as team_count
        from contexts
        group by 1, 2
      ) grouped), '[]'::jsonb),
      jsonb_build_object(
        'team_count', count(*),
        'worker_count', coalesce(sum(
          (metrics ->> 'worker_count')::integer
        ), 0),
        'present_count', coalesce(sum(
          (metrics ->> 'present_count')::integer
        ), 0),
        'absent_count', coalesce(sum(
          (metrics ->> 'absent_count')::integer
        ), 0),
        'leave_count', coalesce(sum(
          (metrics ->> 'leave_count')::integer
        ), 0),
        'not_entered_count', coalesce(sum(
          (metrics ->> 'not_entered_count')::integer
        ), 0),
        'warning_count', coalesce(sum(
          (metrics ->> 'warning_count')::integer
        ), 0),
        'returned_correction_count', coalesce(sum(
          (metrics ->> 'returned_correction_count')::integer
        ), 0),
        'today_entered_count', coalesce(sum(
          (metrics ->> 'today_entered_count')::integer
        ), 0),
        'today_completion_percent', coalesce(round(
          100.0 * sum((metrics ->> 'today_entered_count')::integer)
            / nullif(sum((metrics ->> 'worker_count')::integer), 0), 1
        ), 0),
        'month_entered_count', coalesce(sum(
          (metrics ->> 'month_entered_count')::integer
        ), 0),
        'month_required_count', coalesce(sum(
          (metrics ->> 'month_required_count')::integer
        ), 0),
        'month_completion_percent', coalesce(round(
          100.0 * sum((metrics ->> 'month_entered_count')::integer)
            / nullif(sum((metrics ->> 'month_required_count')::integer), 0), 1
        ), 0)
      )
    into v_contexts, v_as_of_groups, v_summary
    from measured;

    if v_kind = 'supervisor' and jsonb_array_length(v_contexts) = 0 then
      raise exception 'V1_WORKFORCE_T10_READ_DENIED' using errcode = '42501';
    end if;

    if v_kind = 'management' then
      select coalesce(array_agg(period.id), array[]::uuid[])
      into v_authorized_period_ids
      from public.v1_workforce_monthly_periods period
      where public.v1_workforce_t10_period_authorized(
          'workforce.view', period.id, true
        )
        and public.v1_workforce_t10_period_matches_project(
          period.id, v_project_id
        );

      with context_rows as materialized (
        select value as context
        from jsonb_array_elements(v_contexts)
      ), current_source as materialized (
        select attendance.worker_id,
          attendance.assignment_team_id_snapshot as team_id,
          attendance.assignment_project_id_snapshot as project_id,
          attendance.work_date,
          attendance.attendance_status
        from context_rows context_row
        join public.v1_workforce_attendance_days attendance
          on attendance.assignment_team_id_snapshot =
            nullif(context_row.context ->> 'team_id', '')::uuid
          and attendance.work_date =
            (context_row.context ->> 'local_date')::date
        union all
        select worker.id,
          nullif(assignment.value ->> 'team_id', '')::uuid,
          nullif(assignment.value ->> 'project_id', '')::uuid,
          (context_row.context ->> 'local_date')::date,
          null::text
        from context_rows context_row
        join public.v1_workforce_workers worker
          on worker.current_status = 'active'
          and worker.joining_date <=
            (context_row.context ->> 'local_date')::date
          and (worker.leaving_date is null or worker.leaving_date >=
            (context_row.context ->> 'local_date')::date)
        cross join lateral (
          select public.v1_workforce_effective_assignment(
            worker.id, (context_row.context ->> 'local_date')::date
          ) as value
        ) assignment
        where nullif(assignment.value ->> 'team_id', '')::uuid =
            nullif(context_row.context ->> 'team_id', '')::uuid
          and not exists (
            select 1
            from public.v1_workforce_attendance_days attendance
            where attendance.worker_id = worker.id
              and attendance.work_date =
                (context_row.context ->> 'local_date')::date
          )
      ), project_source as materialized (
        select source.worker_id, source.team_id, source.project_id,
          source.attendance_status
        from current_source source
        where source.project_id is not null
        union
        select source.worker_id, source.team_id, allocation.project_id,
          source.attendance_status
        from current_source source
        join public.v1_workforce_timesheet_allocation_sets allocation_set
          on allocation_set.worker_id = source.worker_id
          and allocation_set.work_date = source.work_date
          and allocation_set.current_state = 'active'
        join public.v1_workforce_timesheet_allocations allocation
          on allocation.allocation_revision_id =
            allocation_set.current_revision_id
          and allocation.target_kind = 'project_work'
      ), grouped as materialized (
        select project.id as project_id,
          project.project_ref, project.name as project_name,
          count(distinct source.team_id)::integer as team_count,
          count(distinct source.worker_id)::integer as worker_count,
          count(distinct source.worker_id) filter (
            where source.attendance_status is null
              or source.attendance_status = 'not_entered'
          )::integer as missing_today_count,
          (select count(distinct issue.id)::integer
            from public.v1_workforce_monthly_periods period
            join public.v1_workforce_monthly_validation_issues issue
              on issue.validation_run_id = period.current_validation_run_id
            where issue.severity = 'warning'
              and public.v1_workforce_t10_period_matches_project(
                period.id, project.id
              )
              and period.id = any(v_authorized_period_ids)
          ) as warning_count
        from project_source source
        join public.v1_projects project on project.id = source.project_id
        where project.state = 'active'
          and (v_project_id is null or project.id = v_project_id)
        group by project.id, project.project_ref, project.name
      )
      select coalesce(jsonb_agg(jsonb_build_object(
        'project_id', project_id,
        'project_ref', project_ref,
        'project_name', project_name,
        'team_count', team_count,
        'worker_count', worker_count,
        'missing_today_count', missing_today_count,
        'warning_count', warning_count
      ) order by lower(project_ref), lower(project_name)), '[]'::jsonb)
      into v_projects from grouped;

      with pending as materialized (
        select period.id
        from public.v1_workforce_monthly_periods period
        where period.current_status in (
          'submitted', 'under_review', 'returned_for_correction',
          'awaiting_final_approval'
        )
          and period.id = any(v_authorized_period_ids)
      ), candidate as materialized (
        select public.v1_workforce_t10_review_queue_item(pending.id) as value
        from pending
      )
      select coalesce(jsonb_agg(candidate.value order by
        (candidate.value ->> 'exception_priority')::integer desc,
        candidate.value ->> 'period_month' desc,
        lower(candidate.value ->> 'team_name'), candidate.value ->> 'period_id'),
        '[]'::jsonb)
      into v_all_queue
      from candidate;

      select coalesce(jsonb_agg(page.value order by page.ordinality), '[]'::jsonb)
      into v_queue
      from (
        select item.value, item.ordinality
        from jsonb_array_elements(v_all_queue) with ordinality item
        order by item.ordinality
        limit 50
      ) page;

      with pending as materialized (
        select item.value
        from jsonb_array_elements(v_all_queue) item(value)
      )
      select count(*),
        case when coalesce(sum(
            (value ->> 'high_overtime_exception_count')::integer
          ), 0) > 0 then 'typed_validation_issue' else 'not_configured' end,
        case when coalesce(sum(
            (value ->> 'missing_supporting_evidence_count')::integer
          ), 0) > 0 then 'typed_validation_issue' else 'not_configured' end,
        v_summary || jsonb_build_object(
          'active_project_count', jsonb_array_length(v_projects),
          'review_queue_count', count(*) filter (
            where value ->> 'status' in ('submitted', 'under_review')
          ),
          'approval_queue_count', count(*) filter (
            where value ->> 'status' = 'awaiting_final_approval'
          ),
          'returned_count', count(*) filter (
            where value ->> 'status' = 'returned_for_correction'
          ),
          'overtime_exception_count', coalesce(sum(
            (value ->> 'high_overtime_exception_count')::integer
          ), 0)
        )
      into v_authorized_period_count, v_overtime_policy,
        v_supporting_policy, v_summary
      from pending;

      if jsonb_array_length(v_contexts) = 0
        and v_authorized_period_count = 0
      then
        raise exception 'V1_WORKFORCE_T10_READ_DENIED'
          using errcode = '42501';
      end if;
      v_actions := jsonb_build_object(
        'can_open_review_queue', exists (
          select 1 from jsonb_array_elements(v_all_queue) item
          where item ->> 'status' in (
              'submitted', 'under_review', 'returned_for_correction'
            )
            and (coalesce((item ->> 'can_return')::boolean, false)
              or coalesce((item ->> 'can_correct')::boolean, false)
              or coalesce((item ->> 'can_verify')::boolean, false))
        ),
        'can_open_final_approval_queue', exists (
          select 1 from jsonb_array_elements(v_all_queue) item
          where item ->> 'status' = 'awaiting_final_approval'
            and coalesce((item ->> 'can_final_approve')::boolean, false)
        )
      );
    else
      v_actions := jsonb_build_object(
        'can_complete_today_attendance', exists (
          select 1 from jsonb_array_elements(v_contexts) item
          where coalesce((item #>>
            '{metrics,can_complete_today_attendance}')::boolean, false)
        )
      );
    end if;
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t10',
    'source_version', 'workforce_t10_v1',
    'overview_kind', v_kind,
    'generated_at', statement_timestamp(),
    'as_of_mode', 'calendar_local_by_team',
    'as_of_groups', coalesce(v_as_of_groups, '[]'::jsonb),
    'summary', coalesce(v_summary, '{}'::jsonb),
    'teams', coalesce(v_contexts, '[]'::jsonb),
    'projects', coalesce(v_projects, '[]'::jsonb),
    'review_queue', coalesce(v_queue, '[]'::jsonb),
    'action_flags', coalesce(v_actions, '{}'::jsonb),
    'policies', jsonb_build_object(
      'overtime_limit', v_overtime_policy,
      'supporting_evidence_requirement', v_supporting_policy
    )
  );
end;
$$;

revoke all on function public.v1_workforce_t10_team_contexts()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_team_authorized(jsonb, text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_organization_authorized(text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_period_authorized(
  text, uuid, boolean
) from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_period_matches_project(
  uuid, uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_team_matches_project(
  jsonb, uuid
) from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_team_metrics(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_review_queue_item(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_workforce_overview(jsonb)
  from public, anon;
grant execute on function public.v1_get_workforce_overview(jsonb)
  to authenticated;

comment on function public.v1_get_workforce_overview(jsonb) is
  'T10 read-only Supervisor, Management and Admin Workforce overview; exact capability, responsibility and calendar-local dates.';

commit;
