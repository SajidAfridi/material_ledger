-- Workforce T13 hardening: preserve the accepted T01-T10 result shapes while
-- removing repeated per-team/per-worker assignment and authorization scans
-- from protected overview and approval-queue reads.

begin;

-- T06 prospective monthly membership used the exact T01 resolver once for
-- every worker/day. Resolve the same temporary-before-primary rule set-wise so
-- validation fingerprints and read-only lifecycle projections remain exact at
-- the two-year/500-worker acceptance scale.
do $patch_monthly_source$
declare
  v_definition text;
  v_old text := $old$
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
$old$;
  v_new text := $new$
  prospective_assignment_candidates as materialized (
    select
      worker.id as worker_id,
      dates.work_date,
      assignment.team_id,
      jsonb_build_object(
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
      ) as assignment,
      row_number() over (
        partition by worker.id, dates.work_date
        order by
          case assignment.assignment_kind when 'temporary' then 0 else 1 end,
          assignment.valid_from desc,
          assignment.id
      ) as authority_rank
    from public.v1_workforce_workers worker
    cross join month_dates dates
    join public.v1_workforce_worker_assignments assignment
      on assignment.worker_id = worker.id
      and assignment.valid_from <= dates.work_date
      and (assignment.valid_to is null
        or assignment.valid_to >= dates.work_date)
    left join public.v1_workforce_teams team on team.id = assignment.team_id
    left join public.v1_profiles supervisor
      on supervisor.auth_user_id = assignment.supervisor_auth_user_id
    left join public.v1_projects project on project.id = assignment.project_id
    left join public.v1_project_scopes scope
      on scope.id = assignment.project_scope_id
    left join public.v1_workforce_internal_locations location
      on location.id = assignment.internal_location_id
    where exists (
      select 1
      from public.v1_workforce_worker_assignments team_candidate
      where team_candidate.worker_id = worker.id
        and team_candidate.team_id = p_team_id
        and team_candidate.valid_from <= dates.work_date
        and (team_candidate.valid_to is null
          or team_candidate.valid_to >= dates.work_date)
    )
  ),
  prospective_members as materialized (
    select
      candidate.worker_id,
      candidate.work_date,
      null::uuid as attendance_id,
      candidate.assignment || jsonb_build_object(
        'source', 'effective_assignment'
      ) as assignment
    from prospective_assignment_candidates candidate
    where candidate.authority_rank = 1
      and candidate.team_id = p_team_id
      and not exists (
        select 1
        from public.v1_workforce_attendance_days retained
        where retained.worker_id = candidate.worker_id
          and retained.work_date = candidate.work_date
      )
  ),
$new$;
begin
  select pg_get_functiondef(
    'public.v1_workforce_monthly_source_rows(uuid,date)'::regprocedure
  ) into v_definition;

  if v_definition is null
    or strpos(v_definition, v_old) = 0
    or strpos(v_definition, v_new) > 0
  then
    raise exception 'V1_WORKFORCE_T13_MONTHLY_SOURCE_PATCH_MISMATCH';
  end if;

  v_definition := replace(v_definition, v_old, v_new);
  if strpos(v_definition, v_old) > 0
    or strpos(v_definition, v_new) = 0
  then
    raise exception 'V1_WORKFORCE_T13_MONTHLY_SOURCE_PATCH_NOT_UNIQUE';
  end if;
  execute v_definition;
end;
$patch_monthly_source$;

create or replace function public.v1_workforce_t10_team_contexts()
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with active_contexts as materialized (
    select team.id as team_id, team.team_code, team.team_name,
      team.department, team.default_supervisor_auth_user_id,
      schedule.id as schedule_link_id, calendar.id as calendar_id,
      calendar.calendar_name, calendar.timezone_name as calendar_timezone,
      (statement_timestamp() at time zone calendar.timezone_name)::date
        as local_date
    from public.v1_workforce_teams team
    join public.v1_workforce_team_schedule_links schedule
      on schedule.team_id = team.id
    join public.v1_workforce_calendars calendar
      on calendar.id = schedule.calendar_id
    where team.is_active
      and team.valid_from <=
        (statement_timestamp() at time zone calendar.timezone_name)::date
      and (team.valid_to is null or team.valid_to >=
        (statement_timestamp() at time zone calendar.timezone_name)::date)
      and schedule.valid_from <=
        (statement_timestamp() at time zone calendar.timezone_name)::date
      and (schedule.valid_to is null or schedule.valid_to >=
        (statement_timestamp() at time zone calendar.timezone_name)::date)
      and calendar.valid_from <=
        (statement_timestamp() at time zone calendar.timezone_name)::date
      and (calendar.valid_to is null or calendar.valid_to >=
        (statement_timestamp() at time zone calendar.timezone_name)::date)
  ), local_dates as materialized (
    select distinct context.local_date from active_contexts context
  ), assignment_candidates as materialized (
    select worker.id as worker_id, dates.local_date,
      assignment.team_id, assignment.project_id,
      assignment.internal_location_id,
      row_number() over (
        partition by worker.id, dates.local_date
        order by
          case assignment.assignment_kind when 'temporary' then 0 else 1 end,
          assignment.valid_from desc,
          assignment.id
      ) as authority_rank
    from public.v1_workforce_workers worker
    cross join local_dates dates
    join public.v1_workforce_worker_assignments assignment
      on assignment.worker_id = worker.id
      and assignment.valid_from <= dates.local_date
      and (assignment.valid_to is null
        or assignment.valid_to >= dates.local_date)
    where worker.current_status = 'active'
      and worker.joining_date <= dates.local_date
      and (worker.leaving_date is null
        or worker.leaving_date >= dates.local_date)
  ), current_source as materialized (
    select attendance.worker_id, attendance.work_date as local_date,
      attendance.assignment_team_id_snapshot as team_id,
      attendance.assignment_project_id_snapshot as project_id,
      attendance.assignment_internal_location_id_snapshot
        as internal_location_id
    from public.v1_workforce_attendance_days attendance
    join active_contexts context
      on context.team_id = attendance.assignment_team_id_snapshot
      and context.local_date = attendance.work_date
    union all
    select candidate.worker_id, candidate.local_date, candidate.team_id,
      candidate.project_id, candidate.internal_location_id
    from assignment_candidates candidate
    join active_contexts context
      on context.team_id = candidate.team_id
      and context.local_date = candidate.local_date
    where candidate.authority_rank = 1
      and not exists (
        select 1
        from public.v1_workforce_attendance_days attendance
        where attendance.worker_id = candidate.worker_id
          and attendance.work_date = candidate.local_date
      )
  ), actual_targets as materialized (
    select source.team_id, source.local_date,
      case when count(distinct source.project_id) = 1
        then min(source.project_id::text)::uuid end as project_id,
      case when count(distinct source.internal_location_id) = 1
        then min(source.internal_location_id::text)::uuid end
        as internal_location_id
    from current_source source
    group by source.team_id, source.local_date
  )
  select jsonb_build_object(
    'team_id', context.team_id,
    'team_code', context.team_code,
    'team_name', context.team_name,
    'department', context.department,
    'project_id', target.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'project_state', project.state,
    'internal_location_id', target.internal_location_id,
    'internal_location_name', location.location_name,
    'supervisor_auth_user_id', context.default_supervisor_auth_user_id,
    'supervisor_name', supervisor.display_name,
    'calendar_id', context.calendar_id,
    'calendar_name', context.calendar_name,
    'calendar_timezone', context.calendar_timezone,
    'local_date', context.local_date,
    'period_month', date_trunc('month', context.local_date)::date,
    'schedule_link_id', context.schedule_link_id
  )
  from active_contexts context
  left join actual_targets target
    on target.team_id = context.team_id
    and target.local_date = context.local_date
  left join public.v1_projects project on project.id = target.project_id
  left join public.v1_workforce_internal_locations location
    on location.id = target.internal_location_id
  left join public.v1_profiles supervisor
    on supervisor.auth_user_id = context.default_supervisor_auth_user_id
  order by lower(context.team_name), context.team_id;
$$;

-- Organization authority is already broader than every worker and target
-- scope. Short-circuiting it preserves the exact accepted authorization while
-- avoiding a second scan of the same candidate set.
do $patch_team_authority$
declare
  v_definition text;
  v_old text := $old$
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' then
    return false;
  end if;

  with candidate as materialized (
$old$;
  v_new text := $new$
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' then
    return false;
  end if;

  if public.v1_current_user_has_capability(p_capability_key, null)
    and exists (
      select 1
      from public.v1_workforce_responsibility_assignments responsibility
      where responsibility.auth_user_id = v_actor
        and responsibility.scope_kind = 'organization'
        and responsibility.valid_from <= v_local_date
        and (responsibility.valid_to is null
          or responsibility.valid_to >= v_local_date)
    )
  then
    return true;
  end if;

  with candidate as materialized (
$new$;
begin
  select pg_get_functiondef(
    'public.v1_workforce_t10_team_authorized(jsonb,text)'::regprocedure
  ) into v_definition;
  if v_definition is null or strpos(v_definition, v_old) = 0
    or strpos(v_definition, v_new) > 0 then
    raise exception 'V1_WORKFORCE_T13_TEAM_AUTH_PATCH_MISMATCH';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$patch_team_authority$;

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

  select min((statement_timestamp() at time zone calendar.timezone_name)::date),
    max((statement_timestamp() at time zone calendar.timezone_name)::date)
  into v_first_date, v_last_date
  from public.v1_workforce_teams team
  join public.v1_workforce_team_schedule_links schedule
    on schedule.team_id = team.id
  join public.v1_workforce_calendars calendar
    on calendar.id = schedule.calendar_id
  where team.is_active;
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

-- The T06 empty-period resolver applies capability plus full-month
-- organization/exact-team responsibility to every exact role, including
-- Admin. Reading an empty period never invents worker or target scope.
create or replace function public.v1_workforce_monthly_empty_scope_authorized(
  p_capability_key text,
  p_team_id uuid,
  p_period_month date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_month_end date :=
    (p_period_month + interval '1 month - 1 day')::date;
begin
  if v_actor is null or p_team_id is null or p_period_month is null
    or public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(p_capability_key, null)
  then
    return false;
  end if;
  return exists (
    select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = v_actor
      and responsibility.scope_kind in ('organization', 'team')
      and (
        responsibility.scope_kind = 'organization'
        or responsibility.team_id = p_team_id
      )
      and responsibility.valid_from <= p_period_month
      and (
        responsibility.valid_to is null
        or responsibility.valid_to >= v_month_end
      )
  );
end;
$$;

-- T07 and T10 remain separate accepted boundaries. Both are role-neutral:
-- organization responsibility is valid only when it covers the whole period;
-- otherwise every retained assignment and active allocation target needs its
-- own effective responsibility on the retained work date.
create or replace function public.v1_workforce_t07_period_authorized(
  p_capability_key text,
  p_period_id uuid,
  p_require_targets boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_actor uuid := auth.uid();
  v_date public.v1_workforce_monthly_period_dates%rowtype;
  v_target jsonb;
  v_month_end date;
begin
  if v_actor is null or p_capability_key not in (
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
  v_month_end :=
    (v_period.period_month + interval '1 month - 1 day')::date;

  if public.v1_current_user_has_capability(p_capability_key, null)
    and exists (
      select 1
      from public.v1_workforce_responsibility_assignments responsibility
      where responsibility.auth_user_id = v_actor
        and responsibility.scope_kind = 'organization'
        and responsibility.valid_from <= v_period.period_month
        and (
          responsibility.valid_to is null
          or responsibility.valid_to >= v_month_end
        )
    )
  then
    return true;
  end if;

  if not exists (
    select 1
    from public.v1_workforce_monthly_period_dates period_date
    where period_date.validation_run_id = v_period.current_validation_run_id
  ) then
    return public.v1_workforce_monthly_empty_scope_authorized(
      p_capability_key, v_period.team_id, v_period.period_month
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
      or not exists (
        select 1
        from public.v1_workforce_responsibility_assignments responsibility
        where responsibility.auth_user_id = v_actor
          and responsibility.valid_from <= v_date.work_date
          and (
            responsibility.valid_to is null
            or responsibility.valid_to >= v_date.work_date
          )
          and (
            (responsibility.scope_kind = 'organization'
              and responsibility.valid_from <= v_period.period_month
              and (
                responsibility.valid_to is null
                or responsibility.valid_to >= v_month_end
              ))
            or (responsibility.scope_kind = 'worker'
              and responsibility.worker_id = v_date.worker_id)
            or (responsibility.scope_kind = 'team'
              and responsibility.team_id =
                nullif(v_date.assignment_snapshot ->> 'team_id', '')::uuid)
            or (responsibility.scope_kind = 'project'
              and responsibility.project_id =
                nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid)
            or (responsibility.scope_kind = 'project_scope'
              and responsibility.project_id =
                nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid
              and responsibility.project_scope_id = nullif(
                v_date.assignment_snapshot ->> 'project_scope_id', ''
              )::uuid)
            or (responsibility.scope_kind = 'internal_location'
              and responsibility.internal_location_id = nullif(
                v_date.assignment_snapshot ->> 'internal_location_id', ''
              )::uuid)
          )
      )
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
              and (
                responsibility.valid_to is null
                or responsibility.valid_to >= v_date.work_date
              )
              and (
                (responsibility.scope_kind = 'organization'
                  and responsibility.valid_from <= v_period.period_month
                  and (
                    responsibility.valid_to is null
                    or responsibility.valid_to >= v_month_end
                  ))
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
                  and responsibility.internal_location_id = nullif(
                    v_target ->> 'internal_location_id', ''
                  )::uuid)
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
  v_month_end :=
    (v_period.period_month + interval '1 month - 1 day')::date;

  if public.v1_current_user_has_capability(p_capability_key, null)
    and exists (
      select 1
      from public.v1_workforce_responsibility_assignments responsibility
      where responsibility.auth_user_id = v_actor
        and responsibility.scope_kind = 'organization'
        and responsibility.valid_from <= v_period.period_month
        and (
          responsibility.valid_to is null
          or responsibility.valid_to >= v_month_end
        )
    )
  then
    return true;
  end if;

  if not exists (
    select 1
    from public.v1_workforce_monthly_period_dates period_date
    where period_date.validation_run_id = v_period.current_validation_run_id
  ) then
    return public.v1_workforce_monthly_empty_scope_authorized(
      p_capability_key, v_period.team_id, v_period.period_month
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
      or not exists (
        select 1
        from public.v1_workforce_responsibility_assignments responsibility
        where responsibility.auth_user_id = v_actor
          and responsibility.valid_from <= v_date.work_date
          and (
            responsibility.valid_to is null
            or responsibility.valid_to >= v_date.work_date
          )
          and (
            (responsibility.scope_kind = 'organization'
              and responsibility.valid_from <= v_period.period_month
              and (
                responsibility.valid_to is null
                or responsibility.valid_to >= v_month_end
              ))
            or (responsibility.scope_kind = 'worker'
              and responsibility.worker_id = v_date.worker_id)
            or (responsibility.scope_kind = 'team'
              and responsibility.team_id =
                nullif(v_date.assignment_snapshot ->> 'team_id', '')::uuid)
            or (responsibility.scope_kind = 'project'
              and responsibility.project_id =
                nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid)
            or (responsibility.scope_kind = 'project_scope'
              and responsibility.project_id =
                nullif(v_date.assignment_snapshot ->> 'project_id', '')::uuid
              and responsibility.project_scope_id = nullif(
                v_date.assignment_snapshot ->> 'project_scope_id', ''
              )::uuid)
            or (responsibility.scope_kind = 'internal_location'
              and responsibility.internal_location_id = nullif(
                v_date.assignment_snapshot ->> 'internal_location_id', ''
              )::uuid)
          )
      )
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
              and (
                responsibility.valid_to is null
                or responsibility.valid_to >= v_date.work_date
              )
              and (
                (responsibility.scope_kind = 'organization'
                  and responsibility.valid_from <= v_period.period_month
                  and (
                    responsibility.valid_to is null
                    or responsibility.valid_to >= v_month_end
                  ))
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
                  and responsibility.internal_location_id = nullif(
                    v_target ->> 'internal_location_id', ''
                  )::uuid)
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

revoke all on function public.v1_workforce_monthly_empty_scope_authorized(
  text, uuid, date
) from public, anon, authenticated;
revoke all on function public.v1_workforce_t07_period_authorized(
  text, uuid, boolean
) from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_period_authorized(
  text, uuid, boolean
) from public, anon, authenticated;

revoke all on function public.v1_workforce_t10_team_contexts()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_t10_organization_authorized(text)
  from public, anon, authenticated;

comment on function public.v1_workforce_t10_team_contexts() is
  'T13 set-based equivalent of the accepted T10 calendar-local team context resolver.';

commit;
