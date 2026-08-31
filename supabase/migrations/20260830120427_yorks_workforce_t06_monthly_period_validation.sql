-- Yorks Workforce T06: private monthly period validation snapshots.
--
-- This additive slice creates no submission/review/approval lifecycle and
-- promotes no capability. T01-T05 remain the source of assignment, schedule,
-- attendance and allocation truth. T06 only retains immutable validation
-- evidence and exposes strict, role-safe schema-v1 projections.

begin;

create table public.v1_workforce_monthly_periods (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null
    references public.v1_workforce_teams (id) on delete restrict,
  period_month date not null,
  current_validation_run_id uuid,
  current_validation_number bigint not null default 0 check (
    current_validation_number >= 0
  ),
  current_status text not null default 'draft' check (
    current_status in ('draft', 'ready_for_review')
  ),
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  unique (team_id, period_month),
  unique (id, current_validation_number),
  check (period_month = date_trunc('month', period_month)::date),
  check (
    (current_validation_number = 0 and current_validation_run_id is null)
    or (current_validation_number > 0 and current_validation_run_id is not null)
  )
);

create table public.v1_workforce_monthly_validation_runs (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null
    references public.v1_workforce_monthly_periods (id) on delete restrict,
  validation_number bigint not null check (validation_number > 0),
  validation_status text not null check (
    validation_status in ('draft', 'ready_for_review')
  ),
  source_fingerprint text not null check (
    source_fingerprint ~ '^[0-9a-f]{64}$'
  ),
  worker_count integer not null default 0 check (worker_count >= 0),
  date_count integer not null default 0 check (date_count >= 0),
  scheduled_day_count integer not null default 0 check (
    scheduled_day_count >= 0
  ),
  future_day_count integer not null default 0 check (future_day_count >= 0),
  present_day_count integer not null default 0 check (present_day_count >= 0),
  absent_day_count integer not null default 0 check (absent_day_count >= 0),
  leave_day_count integer not null default 0 check (leave_day_count >= 0),
  weekly_off_day_count integer not null default 0 check (
    weekly_off_day_count >= 0
  ),
  public_holiday_day_count integer not null default 0 check (
    public_holiday_day_count >= 0
  ),
  site_closure_day_count integer not null default 0 check (
    site_closure_day_count >= 0
  ),
  missing_day_count integer not null default 0 check (missing_day_count >= 0),
  regular_minutes bigint not null default 0 check (regular_minutes >= 0),
  overtime_minutes bigint not null default 0 check (overtime_minutes >= 0),
  allocation_minutes bigint not null default 0 check (allocation_minutes >= 0),
  blocking_issue_count integer not null default 0 check (
    blocking_issue_count >= 0
  ),
  warning_issue_count integer not null default 0 check (
    warning_issue_count >= 0
  ),
  project_count integer not null default 0 check (project_count >= 0),
  location_count integer not null default 0 check (location_count >= 0),
  authority_snapshot jsonb not null check (
    jsonb_typeof(authority_snapshot) = 'object'
  ),
  validated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  validated_by_exact_role text not null check (validated_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  validated_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (period_id, validation_number),
  unique (period_id, id),
  unique (period_id, validation_number, id),
  unique (validated_by_auth_user_id, idempotency_key)
);

alter table public.v1_workforce_monthly_periods
  add constraint v1_workforce_monthly_periods_current_run_fk
  foreign key (
    id, current_validation_number, current_validation_run_id
  ) references public.v1_workforce_monthly_validation_runs (
    period_id, validation_number, id
  )
  on delete restrict deferrable initially deferred;

create table public.v1_workforce_monthly_period_workers (
  id uuid primary key default gen_random_uuid(),
  validation_run_id uuid not null
    references public.v1_workforce_monthly_validation_runs (id)
    on delete restrict deferrable initially deferred,
  worker_id uuid not null
    references public.v1_workforce_workers (id) on delete restrict,
  worker_number_snapshot text not null,
  worker_name_snapshot text not null,
  trade_name_snapshot text,
  employer_name_snapshot text not null,
  first_applicable_date date not null,
  last_applicable_date date not null,
  supervisors_snapshot jsonb not null default '[]'::jsonb check (
    jsonb_typeof(supervisors_snapshot) = 'array'
  ),
  projects_snapshot jsonb not null default '[]'::jsonb check (
    jsonb_typeof(projects_snapshot) = 'array'
  ),
  locations_snapshot jsonb not null default '[]'::jsonb check (
    jsonb_typeof(locations_snapshot) = 'array'
  ),
  scheduled_day_count integer not null default 0 check (
    scheduled_day_count >= 0
  ),
  present_day_count integer not null default 0 check (present_day_count >= 0),
  absent_day_count integer not null default 0 check (absent_day_count >= 0),
  leave_day_count integer not null default 0 check (leave_day_count >= 0),
  weekly_off_day_count integer not null default 0 check (
    weekly_off_day_count >= 0
  ),
  public_holiday_day_count integer not null default 0 check (
    public_holiday_day_count >= 0
  ),
  regular_minutes bigint not null default 0 check (regular_minutes >= 0),
  overtime_minutes bigint not null default 0 check (overtime_minutes >= 0),
  missing_day_count integer not null default 0 check (missing_day_count >= 0),
  blocking_issue_count integer not null default 0 check (
    blocking_issue_count >= 0
  ),
  warning_issue_count integer not null default 0 check (
    warning_issue_count >= 0
  ),
  worker_status text not null check (
    worker_status in ('complete', 'has_warnings', 'has_errors')
  ),
  unique (validation_run_id, worker_id),
  check (last_applicable_date >= first_applicable_date)
);

create table public.v1_workforce_monthly_period_dates (
  id uuid primary key default gen_random_uuid(),
  validation_run_id uuid not null
    references public.v1_workforce_monthly_validation_runs (id)
    on delete restrict deferrable initially deferred,
  worker_id uuid not null
    references public.v1_workforce_workers (id) on delete restrict,
  work_date date not null,
  is_future boolean not null,
  is_required boolean not null,
  day_type text,
  daily_status text not null check (daily_status in (
    'future', 'not_started', 'complete', 'has_warnings', 'has_errors'
  )),
  worker_snapshot jsonb not null check (jsonb_typeof(worker_snapshot) = 'object'),
  assignment_snapshot jsonb not null check (
    jsonb_typeof(assignment_snapshot) = 'object'
  ),
  schedule_snapshot jsonb check (
    schedule_snapshot is null or jsonb_typeof(schedule_snapshot) = 'object'
  ),
  attendance_snapshot jsonb check (
    attendance_snapshot is null or jsonb_typeof(attendance_snapshot) = 'object'
  ),
  allocation_snapshot jsonb check (
    allocation_snapshot is null or jsonb_typeof(allocation_snapshot) = 'object'
  ),
  scheduled_minutes integer not null default 0 check (
    scheduled_minutes between 0 and 1440
  ),
  regular_minutes integer not null default 0 check (
    regular_minutes between 0 and 1440
  ),
  overtime_minutes integer not null default 0 check (
    overtime_minutes between 0 and 1440
  ),
  allocation_minutes integer not null default 0 check (
    allocation_minutes between 0 and 1440
  ),
  blocking_issue_count integer not null default 0 check (
    blocking_issue_count >= 0
  ),
  warning_issue_count integer not null default 0 check (
    warning_issue_count >= 0
  ),
  unique (validation_run_id, worker_id, work_date),
  check (regular_minutes + overtime_minutes <= 1440)
);

create table public.v1_workforce_monthly_validation_issues (
  id uuid primary key default gen_random_uuid(),
  validation_run_id uuid not null
    references public.v1_workforce_monthly_validation_runs (id)
    on delete restrict deferrable initially deferred,
  worker_id uuid
    references public.v1_workforce_workers (id) on delete restrict,
  work_date date,
  severity text not null check (severity in ('blocking', 'warning')),
  issue_code text not null check (
    issue_code in (
      'schedule_context_missing', 'required_attendance_missing',
      'attendance_status_invalid', 'attendance_minutes_invalid',
      'absent_with_work_minutes', 'leave_with_work_minutes',
      'allocation_minutes_mismatch', 'allocation_interval_overlap',
      'daily_minutes_over_1440', 'attendance_before_joining',
      'attendance_after_leaving', 'worker_inactive',
      'assignment_invalid', 'supervisor_invalid',
      'allocation_target_invalid', 'validation_stale',
      'work_on_weekly_off',
      'work_on_public_holiday', 'work_on_site_closure',
      'below_standard_minutes', 'assignment_changed_in_period',
      'supervisor_changed_in_period', 'activity_missing',
      'allocation_off_assignment', 'attendance_backdated'
    )
  ),
  message_key text not null check (
    btrim(message_key) <> '' and char_length(message_key) <= 160
  ),
  issue_context jsonb not null default '{}'::jsonb check (
    jsonb_typeof(issue_context) = 'object'
  ),
  sort_order integer not null default 0,
  unique nulls not distinct (
    validation_run_id, worker_id, work_date, issue_code
  )
);

create index v1_workforce_monthly_runs_period_idx
  on public.v1_workforce_monthly_validation_runs (
    period_id, validation_number desc
  );
create index v1_workforce_monthly_workers_page_idx
  on public.v1_workforce_monthly_period_workers (
    validation_run_id, lower(worker_name_snapshot), worker_id
  );
create index v1_workforce_monthly_dates_worker_idx
  on public.v1_workforce_monthly_period_dates (
    validation_run_id, worker_id, work_date
  );
create index v1_workforce_monthly_dates_date_idx
  on public.v1_workforce_monthly_period_dates (
    validation_run_id, work_date, worker_id
  );
create index v1_workforce_monthly_issues_filter_idx
  on public.v1_workforce_monthly_validation_issues (
    validation_run_id, severity, issue_code, worker_id, work_date
  );

alter table public.v1_workforce_monthly_periods enable row level security;
alter table public.v1_workforce_monthly_validation_runs enable row level security;
alter table public.v1_workforce_monthly_period_workers enable row level security;
alter table public.v1_workforce_monthly_period_dates enable row level security;
alter table public.v1_workforce_monthly_validation_issues enable row level security;

revoke all on table public.v1_workforce_monthly_periods
  from public, anon, authenticated;
revoke all on table public.v1_workforce_monthly_validation_runs
  from public, anon, authenticated;
revoke all on table public.v1_workforce_monthly_period_workers
  from public, anon, authenticated;
revoke all on table public.v1_workforce_monthly_period_dates
  from public, anon, authenticated;
revoke all on table public.v1_workforce_monthly_validation_issues
  from public, anon, authenticated;
grant all on table public.v1_workforce_monthly_periods to service_role;
grant all on table public.v1_workforce_monthly_validation_runs to service_role;
grant all on table public.v1_workforce_monthly_period_workers to service_role;
grant all on table public.v1_workforce_monthly_period_dates to service_role;
grant all on table public.v1_workforce_monthly_validation_issues to service_role;

create trigger v1_workforce_monthly_periods_no_delete
before delete on public.v1_workforce_monthly_periods
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_monthly_runs_no_delete
before delete on public.v1_workforce_monthly_validation_runs
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_monthly_workers_no_delete
before delete on public.v1_workforce_monthly_period_workers
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_monthly_dates_no_delete
before delete on public.v1_workforce_monthly_period_dates
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_monthly_issues_no_delete
before delete on public.v1_workforce_monthly_validation_issues
for each row execute function public.v1_workforce_block_delete();

create or replace function public.v1_workforce_monthly_block_immutable_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'V1_WORKFORCE_MONTHLY_HISTORY_IMMUTABLE'
    using errcode = '23514';
end;
$$;

create or replace function public.v1_workforce_monthly_guard_period_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (
    to_jsonb(new) - array[
      'current_validation_run_id', 'current_validation_number',
      'current_status', 'record_version', 'updated_by_auth_user_id',
      'updated_at'
    ]::text[]
  ) is distinct from (
    to_jsonb(old) - array[
      'current_validation_run_id', 'current_validation_number',
      'current_status', 'record_version', 'updated_by_auth_user_id',
      'updated_at'
    ]::text[]
  ) or new.record_version <> (case
      when old.current_validation_number = 0 then old.record_version
      else old.record_version + 1
    end)
    or new.current_validation_number <> old.current_validation_number + 1
    or not exists (
      select 1
      from public.v1_workforce_monthly_validation_runs run
      where run.id = new.current_validation_run_id
        and run.period_id = new.id
        and run.validation_number = new.current_validation_number
        and run.validation_status = new.current_status
    )
  then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_UPDATE_INVALID'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_monthly_periods_update_guard
before update on public.v1_workforce_monthly_periods
for each row execute function public.v1_workforce_monthly_guard_period_update();
create trigger v1_workforce_monthly_runs_immutable
before update on public.v1_workforce_monthly_validation_runs
for each row execute function public.v1_workforce_monthly_block_immutable_update();
create trigger v1_workforce_monthly_workers_immutable
before update on public.v1_workforce_monthly_period_workers
for each row execute function public.v1_workforce_monthly_block_immutable_update();
create trigger v1_workforce_monthly_dates_immutable
before update on public.v1_workforce_monthly_period_dates
for each row execute function public.v1_workforce_monthly_block_immutable_update();
create trigger v1_workforce_monthly_issues_immutable
before update on public.v1_workforce_monthly_validation_issues
for each row execute function public.v1_workforce_monthly_block_immutable_update();

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
  effective_members as materialized (
    select worker.id as worker_id, dates.work_date, assignment.value as assignment
    from public.v1_workforce_workers worker
    cross join month_dates dates
    cross join lateral (
      select public.v1_workforce_effective_assignment(
        worker.id, dates.work_date
      ) as value
    ) assignment
    where nullif(assignment.value ->> 'team_id', '')::uuid = p_team_id
  ),
  members as materialized (
    select worker_id, work_date, assignment from effective_members
  ),
  source as (
    select
      member.worker_id,
      member.work_date,
      worker.worker_number,
      worker.full_name,
      worker.employer_company,
      worker.joining_date,
      worker.leaving_date,
      worker.current_status,
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
      member.assignment || jsonb_build_object(
        'source', 'effective_assignment'
      ) as assignment,
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
        'shift_crosses_midnight',
          attendance.shift_crosses_midnight_snapshot,
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
      on attendance.worker_id = member.worker_id
      and attendance.work_date = member.work_date
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
              project.id is null or project.state <> 'active'
              or scope.id is null or not scope.is_active
            ))
            or (line.target_kind = 'internal_work' and (
              location.id is null or not location.is_active
            ))
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

create or replace function public.v1_workforce_monthly_source_fingerprint(
  p_team_id uuid,
  p_period_month date
)
returns text
language sql
security definer
set search_path = ''
as $$
  select public.v1_hash_json(coalesce(
    jsonb_agg(source_row order by
      (source_row ->> 'worker_id')::uuid,
      (source_row ->> 'work_date')::date
    ),
    '[]'::jsonb
  ))
  from public.v1_workforce_monthly_source_rows(
    p_team_id, p_period_month
  ) source_row;
$$;

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
  v_role text;
  v_month_end date := (p_period_month + interval '1 month - 1 day')::date;
begin
  if v_actor is null or p_team_id is null or p_period_month is null then
    return false;
  end if;
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(p_capability_key, null)
  then
    return false;
  end if;
  if v_role = 'admin' then
    return true;
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
      and (responsibility.valid_to is null
        or responsibility.valid_to >= v_month_end)
  );
end;
$$;

create or replace function public.v1_workforce_monthly_period_authorized(
  p_capability_key text,
  p_team_id uuid,
  p_period_month date,
  p_validation_run_id uuid default null,
  p_require_allocation_targets boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_source_count bigint;
  v_run_count bigint;
  v_source_authority_missing boolean;
  v_target_authority_missing boolean;
begin
  if p_capability_key not in (
    'workforce.view', 'workforce.timesheets.maintain'
  ) or v_actor is null or p_team_id is null or p_period_month is null then
    return false;
  end if;
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_role = 'admin' then
    return true;
  end if;

  with source as materialized (
    select source_row
    from public.v1_workforce_monthly_source_rows(
      p_team_id, p_period_month
    ) source_row
  )
  select
    count(*),
    coalesce(bool_or(public.v1_workforce_roster_authority_context(
      p_capability_key,
      (source_row ->> 'worker_id')::uuid,
      (source_row ->> 'work_date')::date,
      nullif(source_row #>> '{assignment,team_id}', '')::uuid,
      nullif(source_row #>> '{assignment,project_id}', '')::uuid,
      nullif(source_row #>> '{assignment,project_scope_id}', '')::uuid,
      nullif(source_row #>> '{assignment,internal_location_id}', '')::uuid
    ) = '{}'::jsonb), false),
    coalesce(bool_or(
      p_require_allocation_targets
      and source_row #>> '{allocation,allocation_state}' = 'active'
      and exists (
        select 1
        from jsonb_array_elements(coalesce(
          source_row #> '{allocation,targets}', '[]'::jsonb
        )) target
        where public.v1_workforce_timesheet_target_authority(
          p_capability_key,
          (source_row ->> 'work_date')::date,
          target ->> 'target_kind',
          nullif(target ->> 'project_id', '')::uuid,
          nullif(target ->> 'project_scope_id', '')::uuid,
          nullif(target ->> 'internal_location_id', '')::uuid
        ) = '{}'::jsonb
      )
    ), false)
  into v_source_count, v_source_authority_missing,
    v_target_authority_missing
  from source;

  if v_source_authority_missing or v_target_authority_missing then
    return false;
  end if;

  if p_validation_run_id is not null then
    select count(*) into v_run_count
    from public.v1_workforce_monthly_period_dates retained
    where retained.validation_run_id = p_validation_run_id;

    if exists (
      select 1
      from public.v1_workforce_monthly_period_dates retained
      where retained.validation_run_id = p_validation_run_id
        and public.v1_workforce_roster_authority_context(
          p_capability_key, retained.worker_id, retained.work_date,
          nullif(retained.assignment_snapshot ->> 'team_id', '')::uuid,
          nullif(retained.assignment_snapshot ->> 'project_id', '')::uuid,
          nullif(retained.assignment_snapshot ->> 'project_scope_id', '')::uuid,
          nullif(
            retained.assignment_snapshot ->> 'internal_location_id', ''
          )::uuid
        ) = '{}'::jsonb
    ) then
      return false;
    end if;
  else
    v_run_count := 0;
  end if;

  if v_source_count = 0 and v_run_count = 0 then
    return public.v1_workforce_monthly_empty_scope_authorized(
      p_capability_key, p_team_id, p_period_month
    );
  end if;
  return true;
end;
$$;

create or replace function public.v1_workforce_monthly_period_meta_json(
  p_period_id uuid,
  p_current_source_fingerprint text default null
)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'period_id', period.id,
    'team_id', period.team_id,
    'team_name', team.team_name,
    'period_month', period.period_month,
    'stored_status', period.current_status,
    'effective_status', case
      when run.source_fingerprint is distinct from p_current_source_fingerprint
        then 'draft'
      else period.current_status
    end,
    'is_stale', run.source_fingerprint is distinct from
      p_current_source_fingerprint,
    'record_version', period.record_version,
    'current_validation_run_id', period.current_validation_run_id,
    'current_validation_number', period.current_validation_number,
    'source_fingerprint', run.source_fingerprint,
    'current_source_fingerprint', p_current_source_fingerprint,
    'validated_at', run.validated_at,
    'validated_by_auth_user_id', run.validated_by_auth_user_id
  )
  from public.v1_workforce_monthly_periods period
  join public.v1_workforce_teams team on team.id = period.team_id
  join public.v1_workforce_monthly_validation_runs run
    on run.id = period.current_validation_run_id
  where period.id = p_period_id;
$$;

create or replace function public.v1_get_workforce_monthly_period(
  p_team_id uuid,
  p_period_month date,
  p_query text default null,
  p_issue_severity text default null,
  p_issue_code text default null,
  p_worker_limit integer default 50,
  p_worker_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_issue_code text := nullif(btrim(coalesce(p_issue_code, '')), '');
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_run public.v1_workforce_monthly_validation_runs%rowtype;
  v_source_fingerprint text;
  v_stale boolean;
  v_can_validate boolean;
  v_workers jsonb;
  v_issue_counts jsonb;
  v_total_count bigint;
  v_summary jsonb;
begin
  if v_actor is null or p_team_id is null or p_period_month is null
    or p_period_month <> date_trunc('month', p_period_month)::date
    or p_worker_limit is null or p_worker_limit < 1 or p_worker_limit > 500
    or p_worker_offset is null or p_worker_offset < 0
    or char_length(coalesce(p_query, '')) > 200
    or char_length(coalesce(p_issue_code, '')) > 80
    or (p_issue_severity is not null
      and p_issue_severity not in ('blocking', 'warning'))
  then
    raise exception 'V1_WORKFORCE_MONTHLY_READ_INVALID'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not exists (
    select 1 from public.v1_workforce_teams team where team.id = p_team_id
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAM_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  select * into v_period
  from public.v1_workforce_monthly_periods period
  where period.team_id = p_team_id and period.period_month = p_period_month;

  if v_period.id is null and not exists (
    select 1
    from public.v1_workforce_teams team
    where team.id = p_team_id
      and team.valid_from < p_period_month + interval '1 month'
      and (team.valid_to is null or team.valid_to >= p_period_month)
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE'
      using errcode = '23514';
  end if;

  if not public.v1_workforce_monthly_period_authorized(
    'workforce.view', p_team_id, p_period_month,
    v_period.current_validation_run_id, false
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_READ_DENIED'
      using errcode = '42501';
  end if;

  v_can_validate := public.v1_workforce_monthly_period_authorized(
    'workforce.timesheets.maintain', p_team_id, p_period_month,
    v_period.current_validation_run_id, true
  );

  if v_period.id is null then
    return jsonb_build_object(
      'schema_version', 1,
      'authorization_mode', 'enforced_t06',
      'actor_auth_user_id', v_actor,
      'server_time', clock_timestamp(),
      'filters', jsonb_build_object(
        'team_id', p_team_id,
        'period_month', p_period_month,
        'query', nullif(btrim(coalesce(p_query, '')), ''),
        'issue_severity', p_issue_severity,
        'issue_code', v_issue_code,
        'worker_limit', p_worker_limit,
        'worker_offset', p_worker_offset
      ),
      'capabilities', jsonb_build_object(
        'can_view', true, 'can_validate', v_can_validate
      ),
      'period', null,
      'summary', null,
      'issue_counts', '[]'::jsonb,
      'total_count', 0,
      'workers', '[]'::jsonb
    );
  end if;

  select * into strict v_run
  from public.v1_workforce_monthly_validation_runs run
  where run.id = v_period.current_validation_run_id;
  v_source_fingerprint := public.v1_workforce_monthly_source_fingerprint(
    p_team_id, p_period_month
  );
  v_stale := v_run.source_fingerprint <> v_source_fingerprint;

  with matching as materialized (
    select worker.*
    from public.v1_workforce_monthly_period_workers worker
    where worker.validation_run_id = v_run.id
      and (v_query is null or lower(
        worker.worker_number_snapshot || ' ' || worker.worker_name_snapshot
        || ' ' || coalesce(worker.trade_name_snapshot, '') || ' '
        || worker.employer_name_snapshot
      ) like '%' || v_query || '%')
      and (p_issue_severity is null or exists (
        select 1
        from public.v1_workforce_monthly_validation_issues issue
        where issue.validation_run_id = v_run.id
          and issue.worker_id = worker.worker_id
          and issue.severity = p_issue_severity
      ))
      and (v_issue_code is null or exists (
        select 1
        from public.v1_workforce_monthly_validation_issues issue
        where issue.validation_run_id = v_run.id
          and issue.worker_id = worker.worker_id
          and issue.issue_code = v_issue_code
      ))
  ), page as (
    select * from matching
    order by lower(worker_name_snapshot), worker_id
    limit p_worker_limit offset p_worker_offset
  )
  select
    (select count(*) from matching),
    coalesce(jsonb_agg(jsonb_build_object(
      'worker_id', page.worker_id,
      'worker_number', page.worker_number_snapshot,
      'worker_name', page.worker_name_snapshot,
      'trade_name', page.trade_name_snapshot,
      'employer_name', page.employer_name_snapshot,
      'first_applicable_date', page.first_applicable_date,
      'last_applicable_date', page.last_applicable_date,
      'supervisors', page.supervisors_snapshot,
      'projects', page.projects_snapshot,
      'locations', page.locations_snapshot,
      'scheduled_day_count', page.scheduled_day_count,
      'present_day_count', page.present_day_count,
      'absent_day_count', page.absent_day_count,
      'leave_day_count', page.leave_day_count,
      'weekly_off_day_count', page.weekly_off_day_count,
      'public_holiday_day_count', page.public_holiday_day_count,
      'regular_minutes', page.regular_minutes,
      'overtime_minutes', page.overtime_minutes,
      'missing_day_count', page.missing_day_count,
      'blocking_issue_count', page.blocking_issue_count,
      'warning_issue_count', page.warning_issue_count,
      'status', page.worker_status
    ) order by lower(page.worker_name_snapshot), page.worker_id), '[]'::jsonb)
  into v_total_count, v_workers
  from page;

  select coalesce(jsonb_agg(jsonb_build_object(
    'severity', counts.severity,
    'issue_code', counts.issue_code,
    'count', counts.issue_count
  ) order by counts.severity, counts.issue_code), '[]'::jsonb)
  into v_issue_counts
  from (
    select issue.severity, issue.issue_code, count(*)::integer as issue_count
    from public.v1_workforce_monthly_validation_issues issue
    where issue.validation_run_id = v_run.id
    group by issue.severity, issue.issue_code
    union all
    select 'blocking', 'validation_stale', 1 where v_stale
  ) counts;

  v_summary := jsonb_build_object(
    'worker_count', v_run.worker_count,
    'date_count', v_run.date_count,
    'scheduled_day_count', v_run.scheduled_day_count,
    'future_day_count', v_run.future_day_count,
    'present_day_count', v_run.present_day_count,
    'absent_day_count', v_run.absent_day_count,
    'leave_day_count', v_run.leave_day_count,
    'weekly_off_day_count', v_run.weekly_off_day_count,
    'public_holiday_day_count', v_run.public_holiday_day_count,
    'site_closure_day_count', v_run.site_closure_day_count,
    'missing_day_count', v_run.missing_day_count,
    'regular_minutes', v_run.regular_minutes,
    'overtime_minutes', v_run.overtime_minutes,
    'allocation_minutes', v_run.allocation_minutes,
    'blocking_issue_count', v_run.blocking_issue_count
      + case when v_stale then 1 else 0 end,
    'warning_issue_count', v_run.warning_issue_count,
    'project_count', v_run.project_count,
    'location_count', v_run.location_count
  );

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t06',
    'actor_auth_user_id', v_actor,
    'server_time', clock_timestamp(),
    'filters', jsonb_build_object(
      'team_id', p_team_id,
      'period_month', p_period_month,
      'query', nullif(btrim(coalesce(p_query, '')), ''),
      'issue_severity', p_issue_severity,
      'issue_code', v_issue_code,
      'worker_limit', p_worker_limit,
      'worker_offset', p_worker_offset
    ),
    'capabilities', jsonb_build_object(
      'can_view', true,
      'can_validate', v_can_validate
    ),
    'period', public.v1_workforce_monthly_period_meta_json(
      v_period.id, v_source_fingerprint
    ),
    'summary', v_summary,
    'issue_counts', v_issue_counts,
    'total_count', v_total_count,
    'workers', v_workers
  );
end;
$$;

create or replace function public.v1_list_workforce_monthly_teams(
  p_period_month date,
  p_query text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_total_count bigint;
  v_teams jsonb;
begin
  if v_actor is null or p_period_month is null
    or p_period_month <> date_trunc('month', p_period_month)::date
    or p_limit is null or p_limit < 1 or p_limit > 500
    or p_offset is null or p_offset < 0
    or char_length(coalesce(p_query, '')) > 200
  then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAMS_INVALID'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_actor_is_active()
  then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAMS_DENIED'
      using errcode = '42501';
  end if;

  with authorized as materialized (
    select team.*
    from public.v1_workforce_teams team
    where team.valid_from < p_period_month + interval '1 month'
      and (team.valid_to is null or team.valid_to >= p_period_month)
      and (v_query is null or lower(
        team.team_code || ' ' || team.team_name || ' '
        || coalesce(team.department, '')
      ) like '%' || v_query || '%')
      and public.v1_workforce_monthly_period_authorized(
        'workforce.view', team.id, p_period_month,
        (select period.current_validation_run_id
         from public.v1_workforce_monthly_periods period
         where period.team_id = team.id
           and period.period_month = p_period_month),
        false
      )
  ), page as (
    select * from authorized
    order by lower(team_name), id
    limit p_limit offset p_offset
  )
  select
    (select count(*) from authorized),
    coalesce(jsonb_agg(jsonb_build_object(
      'team_id', page.id,
      'team_code', page.team_code,
      'team_name', page.team_name,
      'department', page.department,
      'period_exists', period.id is not null,
      'period_id', period.id,
      'stored_status', period.current_status,
      'record_version', period.record_version,
      'current_validation_number', period.current_validation_number
    ) order by lower(page.team_name), page.id), '[]'::jsonb)
  into v_total_count, v_teams
  from page
  left join public.v1_workforce_monthly_periods period
    on period.team_id = page.id and period.period_month = p_period_month;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t06',
    'actor_auth_user_id', v_actor,
    'server_time', clock_timestamp(),
    'filters', jsonb_build_object(
      'period_month', p_period_month,
      'query', nullif(btrim(coalesce(p_query, '')), ''),
      'limit', p_limit,
      'offset', p_offset
    ),
    'total_count', v_total_count,
    'teams', v_teams
  );
end;
$$;

create or replace function public.v1_get_workforce_monthly_worker_detail(
  p_period_id uuid,
  p_validation_run_id uuid,
  p_worker_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_run public.v1_workforce_monthly_validation_runs%rowtype;
  v_worker public.v1_workforce_monthly_period_workers%rowtype;
  v_source_fingerprint text;
  v_days jsonb;
begin
  if v_actor is null or p_period_id is null
    or p_validation_run_id is null or p_worker_id is null
  then
    raise exception 'V1_WORKFORCE_MONTHLY_DETAIL_INVALID'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  select * into v_period
  from public.v1_workforce_monthly_periods period
  where period.id = p_period_id;
  if v_period.id is null then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  select * into v_run
  from public.v1_workforce_monthly_validation_runs run
  where run.id = p_validation_run_id and run.period_id = p_period_id;
  if v_run.id is null then
    raise exception 'V1_WORKFORCE_MONTHLY_RUN_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  if not public.v1_workforce_monthly_period_authorized(
    'workforce.view', v_period.team_id, v_period.period_month, v_run.id, false
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_DETAIL_DENIED'
      using errcode = '42501';
  end if;
  select * into v_worker
  from public.v1_workforce_monthly_period_workers worker
  where worker.validation_run_id = v_run.id and worker.worker_id = p_worker_id;
  if v_worker.id is null then
    raise exception 'V1_WORKFORCE_MONTHLY_WORKER_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  v_source_fingerprint := public.v1_workforce_monthly_source_fingerprint(
    v_period.team_id, v_period.period_month
  );

  select coalesce(jsonb_agg(jsonb_build_object(
    'work_date', date_row.work_date,
    'is_future', date_row.is_future,
    'is_required', date_row.is_required,
    'day_type', date_row.day_type,
    'daily_status', date_row.daily_status,
    'assignment', date_row.assignment_snapshot,
    'schedule', date_row.schedule_snapshot,
    'attendance', date_row.attendance_snapshot,
    'allocation', case
      when date_row.allocation_snapshot is null then null
      when target_access.targets_authorized then
        date_row.allocation_snapshot || jsonb_build_object(
          'targets_restricted', false
        )
      else jsonb_build_object(
        'allocation_set_id', null,
        'allocation_set_version', null,
        'allocation_state', null,
        'allocation_revision_id', null,
        'allocation_revision_number', null,
        'attendance_record_version_basis', null,
        'total_regular_minutes', coalesce(
          (date_row.allocation_snapshot ->> 'total_regular_minutes')::integer,
          0
        ),
        'total_overtime_minutes', coalesce(
          (date_row.allocation_snapshot ->> 'total_overtime_minutes')::integer,
          0
        ),
        'line_count', coalesce(
          (date_row.allocation_snapshot ->> 'line_count')::integer, 0
        ),
        'targets_restricted', true,
        'targets', null
      )
    end,
    'scheduled_minutes', date_row.scheduled_minutes,
    'regular_minutes', date_row.regular_minutes,
    'overtime_minutes', date_row.overtime_minutes,
    'allocation_minutes', date_row.allocation_minutes,
    'blocking_issue_count', date_row.blocking_issue_count,
    'warning_issue_count', date_row.warning_issue_count,
    'issues', coalesce(day_issues.issues, '[]'::jsonb)
  ) order by date_row.work_date), '[]'::jsonb)
  into v_days
  from public.v1_workforce_monthly_period_dates date_row
  left join lateral (
    select not exists (
      select 1
      from jsonb_array_elements(coalesce(
        date_row.allocation_snapshot -> 'targets', '[]'::jsonb
      )) target
      where public.v1_workforce_timesheet_target_authority(
        'workforce.view', date_row.work_date,
        target ->> 'target_kind',
        nullif(target ->> 'project_id', '')::uuid,
        nullif(target ->> 'project_scope_id', '')::uuid,
        nullif(target ->> 'internal_location_id', '')::uuid
      ) = '{}'::jsonb
    ) as targets_authorized
  ) target_access on true
  left join lateral (
    select jsonb_agg(jsonb_build_object(
      'issue_id', issue.id,
      'severity', issue.severity,
      'issue_code', issue.issue_code,
      'message_key', issue.message_key,
      'context', issue.issue_context
    ) order by issue.severity, issue.sort_order, issue.issue_code) as issues
    from public.v1_workforce_monthly_validation_issues issue
    where issue.validation_run_id = v_run.id
      and issue.worker_id = date_row.worker_id
      and issue.work_date = date_row.work_date
  ) day_issues on true
  where date_row.validation_run_id = v_run.id
    and date_row.worker_id = p_worker_id;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t06',
    'actor_auth_user_id', v_actor,
    'server_time', clock_timestamp(),
    'period', public.v1_workforce_monthly_period_meta_json(
      v_period.id, v_source_fingerprint
    ),
    'validation_run', jsonb_build_object(
      'validation_run_id', v_run.id,
      'validation_number', v_run.validation_number,
      'validation_status', v_run.validation_status,
      'source_fingerprint', v_run.source_fingerprint,
      'is_current_run', v_period.current_validation_run_id = v_run.id,
      'validated_at', v_run.validated_at,
      'validated_by_auth_user_id', v_run.validated_by_auth_user_id
    ),
    'worker', jsonb_build_object(
      'worker_id', v_worker.worker_id,
      'worker_number', v_worker.worker_number_snapshot,
      'worker_name', v_worker.worker_name_snapshot,
      'trade_name', v_worker.trade_name_snapshot,
      'employer_name', v_worker.employer_name_snapshot,
      'first_applicable_date', v_worker.first_applicable_date,
      'last_applicable_date', v_worker.last_applicable_date,
      'supervisors', v_worker.supervisors_snapshot,
      'projects', v_worker.projects_snapshot,
      'locations', v_worker.locations_snapshot,
      'scheduled_day_count', v_worker.scheduled_day_count,
      'present_day_count', v_worker.present_day_count,
      'absent_day_count', v_worker.absent_day_count,
      'leave_day_count', v_worker.leave_day_count,
      'weekly_off_day_count', v_worker.weekly_off_day_count,
      'public_holiday_day_count', v_worker.public_holiday_day_count,
      'regular_minutes', v_worker.regular_minutes,
      'overtime_minutes', v_worker.overtime_minutes,
      'missing_day_count', v_worker.missing_day_count,
      'blocking_issue_count', v_worker.blocking_issue_count,
      'warning_issue_count', v_worker.warning_issue_count,
      'status', v_worker.worker_status
    ),
    'days', v_days
  );
end;
$$;

create or replace function public.v1_list_workforce_monthly_issues(
  p_period_id uuid,
  p_validation_run_id uuid,
  p_severity text default null,
  p_issue_code text default null,
  p_worker_id uuid default null,
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
  v_issue_code text := nullif(btrim(coalesce(p_issue_code, '')), '');
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_run public.v1_workforce_monthly_validation_runs%rowtype;
  v_current_source_fingerprint text;
  v_stale boolean;
  v_total_count bigint;
  v_issues jsonb;
begin
  if v_actor is null or p_period_id is null or p_validation_run_id is null
    or (p_severity is not null and p_severity not in ('blocking', 'warning'))
    or char_length(coalesce(p_issue_code, '')) > 80
    or p_limit is null or p_limit < 1 or p_limit > 500
    or p_offset is null or p_offset < 0
  then
    raise exception 'V1_WORKFORCE_MONTHLY_ISSUES_INVALID'
      using errcode = '22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  select * into v_period
  from public.v1_workforce_monthly_periods period
  where period.id = p_period_id;
  select * into v_run
  from public.v1_workforce_monthly_validation_runs run
  where run.id = p_validation_run_id and run.period_id = p_period_id;
  if v_period.id is null or v_run.id is null then
    raise exception 'V1_WORKFORCE_MONTHLY_RUN_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  if not public.v1_workforce_monthly_period_authorized(
    'workforce.view', v_period.team_id, v_period.period_month, v_run.id, false
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_ISSUES_DENIED'
      using errcode = '42501';
  end if;

  v_current_source_fingerprint :=
    public.v1_workforce_monthly_source_fingerprint(
      v_period.team_id, v_period.period_month
    );
  v_stale := v_run.source_fingerprint <> v_current_source_fingerprint;

  with matching as materialized (
    select issue.*, worker.worker_number_snapshot, worker.worker_name_snapshot
    from (
      select stored.*
      from public.v1_workforce_monthly_validation_issues stored
      where stored.validation_run_id = v_run.id
      union all
      select
        md5(v_run.id::text || '|validation_stale')::uuid as id,
        v_run.id as validation_run_id,
        null::uuid as worker_id,
        null::date as work_date,
        'blocking'::text as severity,
        'validation_stale'::text as issue_code,
        'workforce.monthly.issue.validation_stale'::text as message_key,
        jsonb_build_object(
          'validated_source_fingerprint', v_run.source_fingerprint,
          'current_source_fingerprint', v_current_source_fingerprint
        ) as issue_context,
        0::integer as sort_order
      where v_stale
    ) issue
    left join public.v1_workforce_monthly_period_workers worker
      on worker.validation_run_id = issue.validation_run_id
      and worker.worker_id = issue.worker_id
    where (p_severity is null or issue.severity = p_severity)
      and (v_issue_code is null or issue.issue_code = v_issue_code)
      and (p_worker_id is null or issue.worker_id = p_worker_id)
  ), page as (
    select * from matching
    order by
      case severity when 'blocking' then 0 else 1 end,
      work_date nulls first, lower(worker_name_snapshot) nulls first,
      sort_order, issue_code, id
    limit p_limit offset p_offset
  )
  select
    (select count(*) from matching),
    coalesce(jsonb_agg(jsonb_build_object(
      'issue_id', page.id,
      'severity', page.severity,
      'issue_code', page.issue_code,
      'worker_id', page.worker_id,
      'worker_number', page.worker_number_snapshot,
      'worker_name', page.worker_name_snapshot,
      'work_date', page.work_date,
      'message_key', page.message_key,
      'context', page.issue_context
    ) order by
      case page.severity when 'blocking' then 0 else 1 end,
      page.work_date nulls first,
      lower(page.worker_name_snapshot) nulls first,
      page.sort_order, page.issue_code, page.id), '[]'::jsonb)
  into v_total_count, v_issues
  from page;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_t06',
    'actor_auth_user_id', v_actor,
    'server_time', clock_timestamp(),
    'filters', jsonb_build_object(
      'period_id', p_period_id,
      'validation_run_id', p_validation_run_id,
      'severity', p_severity,
      'issue_code', v_issue_code,
      'worker_id', p_worker_id,
      'limit', p_limit,
      'offset', p_offset
    ),
    'total_count', v_total_count,
    'issues', v_issues
  );
end;
$$;

create or replace function public.v1_workforce_monthly_add_issue(
  p_validation_run_id uuid,
  p_worker_id uuid,
  p_work_date date,
  p_severity text,
  p_issue_code text,
  p_context jsonb default '{}'::jsonb,
  p_sort_order integer default 0
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.v1_workforce_monthly_validation_issues (
    validation_run_id, worker_id, work_date, severity, issue_code,
    message_key, issue_context, sort_order
  ) values (
    p_validation_run_id, p_worker_id, p_work_date, p_severity, p_issue_code,
    'workforce.monthly.issue.' || p_issue_code,
    coalesce(p_context, '{}'::jsonb), p_sort_order
  );
end;
$$;

create or replace function public.v1_validate_workforce_monthly_period(
  p_payload jsonb,
  p_expected_period_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_team_id uuid;
  v_period_month date;
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_period_id uuid;
  v_run_id uuid := gen_random_uuid();
  v_validation_number bigint;
  v_is_initial boolean;
  v_existing_response jsonb;
  v_source_fingerprint text;
  v_final_fingerprint text;
  v_source_row jsonb;
  v_worker_id uuid;
  v_work_date date;
  v_worker jsonb;
  v_assignment jsonb;
  v_schedule jsonb;
  v_attendance jsonb;
  v_allocation jsonb;
  v_is_future boolean;
  v_is_required boolean;
  v_day_type text;
  v_scheduled_minutes integer;
  v_regular_minutes integer;
  v_overtime_minutes integer;
  v_allocation_minutes integer;
  v_status text;
  v_blocking integer;
  v_warning integer;
  v_run_status text;
  v_before jsonb;
  v_after jsonb;
  v_response jsonb;
  v_payload_key_count integer;
  v_worker_count integer;
  v_date_count integer;
  v_scheduled_count integer;
  v_future_count integer;
  v_present_count integer;
  v_absent_count integer;
  v_leave_count integer;
  v_weekly_off_count integer;
  v_public_holiday_count integer;
  v_site_closure_count integer;
  v_missing_count integer;
  v_total_regular bigint;
  v_total_overtime bigint;
  v_total_allocation bigint;
  v_blocking_count integer;
  v_warning_count integer;
  v_project_count integer;
  v_location_count integer;
begin
  if v_actor is null or p_payload is null
    or jsonb_typeof(p_payload) <> 'object'
    or p_idempotency_key is null
    or (p_expected_period_version is not null
      and p_expected_period_version < 1)
  then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_INVALID'
      using errcode = '22023';
  end if;
  select count(*) into v_payload_key_count from jsonb_object_keys(p_payload);
  if v_payload_key_count <> 2
    or not (p_payload ? 'team_id')
    or not (p_payload ? 'period_month')
    or exists (
      select 1 from jsonb_object_keys(p_payload) key_name
      where key_name not in ('team_id', 'period_month')
    )
  then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  begin
    v_team_id := nullif(btrim(p_payload ->> 'team_id'), '')::uuid;
    v_period_month := nullif(btrim(p_payload ->> 'period_month'), '')::date;
  exception when others then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_PAYLOAD_INVALID'
      using errcode = '22023';
  end;
  if v_team_id is null or v_period_month is null
    or v_period_month <> date_trunc('month', v_period_month)::date
  then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  v_role := public.v1_permission_exact_role(v_actor);
  if v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED'
      using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_workforce_teams team where team.id = v_team_id
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAM_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'v1_workforce_monthly_period|' || v_team_id::text || '|'
      || v_period_month::text,
    0
  ));
  select * into v_period
  from public.v1_workforce_monthly_periods period
  where period.team_id = v_team_id and period.period_month = v_period_month
  for update;

  if v_period.id is null and not exists (
    select 1
    from public.v1_workforce_teams team
    where team.id = v_team_id
      and team.valid_from < v_period_month + interval '1 month'
      and (team.valid_to is null or team.valid_to >= v_period_month)
  ) then
    raise exception 'V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE'
      using errcode = '23514';
  end if;

  if not public.v1_workforce_monthly_period_authorized(
      'workforce.view', v_team_id, v_period_month,
      v_period.current_validation_run_id, false
    )
    or not public.v1_workforce_monthly_period_authorized(
      'workforce.timesheets.maintain', v_team_id, v_period_month,
      v_period.current_validation_run_id, true
    )
  then
    raise exception 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED'
      using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_validate_workforce_monthly_period', p_idempotency_key,
    jsonb_build_object(
      'payload', p_payload,
      'expected_period_version', p_expected_period_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  v_is_initial := v_period.id is null;
  if v_is_initial then
    if p_expected_period_version is not null then
      raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_period_id := gen_random_uuid();
    insert into public.v1_workforce_monthly_periods (
      id, team_id, period_month, created_by_auth_user_id,
      updated_by_auth_user_id
    ) values (
      v_period_id, v_team_id, v_period_month, v_actor, v_actor
    );
    v_validation_number := 1;
    v_before := null;
  else
    if p_expected_period_version is null
      or p_expected_period_version <> v_period.record_version
    then
      raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_period_id := v_period.id;
    v_validation_number := v_period.current_validation_number + 1;
    v_before := jsonb_build_object(
      'period_id', v_period.id,
      'current_validation_run_id', v_period.current_validation_run_id,
      'current_validation_number', v_period.current_validation_number,
      'current_status', v_period.current_status,
      'record_version', v_period.record_version
    );
  end if;

  v_source_fingerprint := public.v1_workforce_monthly_source_fingerprint(
    v_team_id, v_period_month
  );

  for v_source_row in
    select source_row
    from public.v1_workforce_monthly_source_rows(
      v_team_id, v_period_month
    ) source_row
    order by (source_row ->> 'worker_id')::uuid,
      (source_row ->> 'work_date')::date
  loop
    v_worker_id := (v_source_row ->> 'worker_id')::uuid;
    v_work_date := (v_source_row ->> 'work_date')::date;
    v_worker := v_source_row -> 'worker';
    v_assignment := v_source_row -> 'assignment';
    v_schedule := nullif(v_source_row -> 'schedule', 'null'::jsonb);
    v_attendance := nullif(v_source_row -> 'attendance', 'null'::jsonb);
    v_allocation := nullif(v_source_row -> 'allocation', 'null'::jsonb);
    v_is_future := coalesce((v_source_row ->> 'is_future')::boolean, false);
    v_is_required := coalesce((v_source_row ->> 'is_required')::boolean, false);
    v_day_type := nullif(v_schedule ->> 'day_type', '');
    v_scheduled_minutes := coalesce(
      (v_schedule ->> 'scheduled_minutes')::integer, 0
    );
    v_regular_minutes := coalesce(
      (v_attendance ->> 'regular_minutes')::integer, 0
    );
    v_overtime_minutes := coalesce(
      (v_attendance ->> 'overtime_minutes')::integer, 0
    );
    v_allocation_minutes := case
      when v_allocation is null
        or v_allocation ->> 'allocation_state' <> 'active' then 0
      else coalesce(
        (v_allocation ->> 'total_regular_minutes')::integer, 0
      ) + coalesce(
        (v_allocation ->> 'total_overtime_minutes')::integer, 0
      )
    end;
    v_blocking := 0;
    v_warning := 0;

    if not v_is_future then
      if v_schedule is null then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'schedule_context_missing', '{}'::jsonb, 10
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_is_required and (
        v_attendance is null
        or v_attendance ->> 'attendance_status' = 'not_entered'
      ) then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'required_attendance_missing', jsonb_build_object(
            'scheduled_minutes', v_scheduled_minutes
          ), 20
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_attendance is not null
        and v_attendance ->> 'attendance_status' not in (
          'present', 'absent', 'annual_leave', 'sick_leave',
          'official_leave', 'unpaid_leave', 'not_entered'
        )
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'attendance_status_invalid', '{}'::jsonb, 30
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_regular_minutes < 0 or v_overtime_minutes < 0 then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'attendance_minutes_invalid', '{}'::jsonb, 40
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_regular_minutes + v_overtime_minutes > 1440 then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'daily_minutes_over_1440', jsonb_build_object(
            'total_minutes', v_regular_minutes + v_overtime_minutes
          ), 50
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_attendance ->> 'attendance_status' = 'absent'
        and v_regular_minutes + v_overtime_minutes > 0
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'absent_with_work_minutes', '{}'::jsonb, 60
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_attendance ->> 'attendance_status' in (
          'annual_leave', 'sick_leave', 'official_leave', 'unpaid_leave'
        ) and v_regular_minutes + v_overtime_minutes > 0
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'leave_with_work_minutes', '{}'::jsonb, 70
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_work_date < (v_worker ->> 'joining_date')::date then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'attendance_before_joining', '{}'::jsonb, 80
        );
        v_blocking := v_blocking + 1;
      end if;
      if nullif(v_worker ->> 'leaving_date', '') is not null
        and v_work_date > (v_worker ->> 'leaving_date')::date
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'attendance_after_leaving', '{}'::jsonb, 90
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_assignment is null or v_assignment = '{}'::jsonb
        or nullif(v_assignment ->> 'team_id', '')::uuid <> v_team_id
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'assignment_invalid', '{}'::jsonb, 100
        );
        v_blocking := v_blocking + 1;
      end if;
      if nullif(v_assignment ->> 'supervisor_auth_user_id', '') is not null
        and not exists (
          select 1 from public.v1_profiles profile
          where profile.auth_user_id = nullif(
            v_assignment ->> 'supervisor_auth_user_id', ''
          )::uuid and profile.is_active
        )
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'supervisor_invalid', '{}'::jsonb, 110
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_allocation is not null
        and v_allocation ->> 'allocation_state' = 'active'
        and v_allocation_minutes <> v_regular_minutes + v_overtime_minutes
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'allocation_minutes_mismatch', jsonb_build_object(
            'attendance_minutes', v_regular_minutes + v_overtime_minutes,
            'allocation_minutes', v_allocation_minutes
          ), 120
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_allocation ->> 'allocation_state' = 'active' and coalesce(
        (v_allocation ->> 'has_interval_overlap')::boolean, false
      ) then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'allocation_interval_overlap', '{}'::jsonb, 130
        );
        v_blocking := v_blocking + 1;
      end if;
      if v_allocation ->> 'allocation_state' = 'active' and coalesce(
        (v_allocation ->> 'has_invalid_target')::boolean, false
      ) then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'blocking',
          'allocation_target_invalid', '{}'::jsonb, 140
        );
        v_blocking := v_blocking + 1;
      end if;

      if v_regular_minutes + v_overtime_minutes > 0
        and v_day_type = 'weekly_off'
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'work_on_weekly_off', '{}'::jsonb, 210
        );
        v_warning := v_warning + 1;
      end if;
      if v_regular_minutes + v_overtime_minutes > 0
        and v_day_type = 'public_holiday'
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'work_on_public_holiday', '{}'::jsonb, 220
        );
        v_warning := v_warning + 1;
      end if;
      if v_regular_minutes + v_overtime_minutes > 0
        and v_day_type = 'site_closed'
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'work_on_site_closure', '{}'::jsonb, 230
        );
        v_warning := v_warning + 1;
      end if;
      if v_attendance ->> 'attendance_status' = 'present'
        and v_scheduled_minutes > 0
        and v_regular_minutes < v_scheduled_minutes
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'below_standard_minutes', jsonb_build_object(
            'scheduled_minutes', v_scheduled_minutes,
            'regular_minutes', v_regular_minutes
          ), 240
        );
        v_warning := v_warning + 1;
      end if;
      if v_allocation ->> 'allocation_state' = 'active' and coalesce(
        (v_allocation ->> 'has_missing_activity')::boolean, false
      )
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'activity_missing', '{}'::jsonb, 250
        );
        v_warning := v_warning + 1;
      end if;
      if v_allocation ->> 'allocation_state' = 'active' and coalesce(
        (v_allocation ->> 'has_off_assignment_target')::boolean, false
      ) then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'allocation_off_assignment', '{}'::jsonb, 260
        );
        v_warning := v_warning + 1;
      end if;
      if v_attendance is not null and v_schedule is not null
        and (
          (v_attendance ->> 'created_at')::timestamptz at time zone
            (v_schedule ->> 'calendar_timezone')
        )::date > v_work_date
      then
        perform public.v1_workforce_monthly_add_issue(
          v_run_id, v_worker_id, v_work_date, 'warning',
          'attendance_backdated', '{}'::jsonb, 270
        );
        v_warning := v_warning + 1;
      end if;
    end if;

    v_status := case
      when v_is_future then 'future'
      when v_blocking > 0 then 'has_errors'
      when v_warning > 0 then 'has_warnings'
      when v_attendance is null then 'not_started'
      else 'complete'
    end;
    insert into public.v1_workforce_monthly_period_dates (
      validation_run_id, worker_id, work_date, is_future, is_required,
      day_type, daily_status, worker_snapshot, assignment_snapshot,
      schedule_snapshot, attendance_snapshot, allocation_snapshot,
      scheduled_minutes, regular_minutes, overtime_minutes,
      allocation_minutes, blocking_issue_count, warning_issue_count
    ) values (
      v_run_id, v_worker_id, v_work_date, v_is_future, v_is_required,
      v_day_type, v_status, v_worker, v_assignment, v_schedule,
      v_attendance, v_allocation, v_scheduled_minutes, v_regular_minutes,
      v_overtime_minutes, v_allocation_minutes, v_blocking, v_warning
    );
  end loop;

  insert into public.v1_workforce_monthly_validation_issues (
    validation_run_id, worker_id, work_date, severity, issue_code,
    message_key, issue_context, sort_order
  )
  select v_run_id, date_row.worker_id, null, 'blocking', 'worker_inactive',
    'workforce.monthly.issue.worker_inactive',
    jsonb_build_object(
      'current_status', min(date_row.worker_snapshot ->> 'current_status')
    ), 150
  from public.v1_workforce_monthly_period_dates date_row
  where date_row.validation_run_id = v_run_id
    and date_row.worker_snapshot ->> 'current_status' <> 'active'
  group by date_row.worker_id;

  insert into public.v1_workforce_monthly_validation_issues (
    validation_run_id, worker_id, work_date, severity, issue_code,
    message_key, issue_context, sort_order
  )
  select v_run_id, changes.worker_id, null, 'warning',
    'assignment_changed_in_period',
    'workforce.monthly.issue.assignment_changed_in_period',
    jsonb_build_object('assignment_count', changes.assignment_count), 280
  from (
    select date_row.worker_id,
      count(distinct date_row.assignment_snapshot ->> 'assignment_id')::integer
        as assignment_count
    from public.v1_workforce_monthly_period_dates date_row
    where date_row.validation_run_id = v_run_id
    group by date_row.worker_id
    having count(distinct date_row.assignment_snapshot ->> 'assignment_id') > 1
  ) changes;

  insert into public.v1_workforce_monthly_validation_issues (
    validation_run_id, worker_id, work_date, severity, issue_code,
    message_key, issue_context, sort_order
  )
  select v_run_id, changes.worker_id, null, 'warning',
    'supervisor_changed_in_period',
    'workforce.monthly.issue.supervisor_changed_in_period',
    jsonb_build_object('supervisor_count', changes.supervisor_count), 290
  from (
    select date_row.worker_id,
      count(distinct coalesce(
        date_row.assignment_snapshot ->> 'supervisor_auth_user_id',
        '__none__'
      ))::integer as supervisor_count
    from public.v1_workforce_monthly_period_dates date_row
    where date_row.validation_run_id = v_run_id
    group by date_row.worker_id
    having count(distinct coalesce(
      date_row.assignment_snapshot ->> 'supervisor_auth_user_id',
      '__none__'
    )) > 1
  ) changes;

  insert into public.v1_workforce_monthly_period_workers (
    validation_run_id, worker_id, worker_number_snapshot,
    worker_name_snapshot, trade_name_snapshot, employer_name_snapshot,
    first_applicable_date, last_applicable_date, supervisors_snapshot,
    projects_snapshot, locations_snapshot, scheduled_day_count,
    present_day_count, absent_day_count, leave_day_count,
    weekly_off_day_count, public_holiday_day_count, regular_minutes,
    overtime_minutes, missing_day_count, blocking_issue_count,
    warning_issue_count, worker_status
  )
  select
    v_run_id,
    grouped.worker_id,
    grouped.worker_number,
    grouped.worker_name,
    grouped.trade_name,
    grouped.employer_name,
    grouped.first_date,
    grouped.last_date,
    grouped.supervisors,
    grouped.projects,
    grouped.locations,
    grouped.scheduled_count,
    grouped.present_count,
    grouped.absent_count,
    grouped.leave_count,
    grouped.weekly_off_count,
    grouped.public_holiday_count,
    grouped.regular_total,
    grouped.overtime_total,
    grouped.missing_count,
    coalesce(issue_counts.blocking_count, 0),
    coalesce(issue_counts.warning_count, 0),
    case when coalesce(issue_counts.blocking_count, 0) > 0 then 'has_errors'
      when coalesce(issue_counts.warning_count, 0) > 0 then 'has_warnings'
      else 'complete' end
  from (
    select
      date_row.worker_id,
      min(date_row.worker_snapshot ->> 'worker_number') as worker_number,
      min(date_row.worker_snapshot ->> 'worker_name') as worker_name,
      min(date_row.worker_snapshot ->> 'trade_name') as trade_name,
      min(date_row.worker_snapshot ->> 'employer_name') as employer_name,
      min(date_row.work_date) as first_date,
      max(date_row.work_date) as last_date,
      (select coalesce(jsonb_agg(value order by value::text), '[]'::jsonb)
       from (select distinct jsonb_build_object(
         'supervisor_auth_user_id',
           detail.assignment_snapshot -> 'supervisor_auth_user_id',
         'supervisor_name', detail.assignment_snapshot -> 'supervisor_name'
       ) as value
       from public.v1_workforce_monthly_period_dates detail
       where detail.validation_run_id = v_run_id
         and detail.worker_id = date_row.worker_id
         and detail.assignment_snapshot ->> 'supervisor_auth_user_id'
           is not null) values_) as supervisors,
      (select coalesce(jsonb_agg(value order by value::text), '[]'::jsonb)
       from (select distinct jsonb_build_object(
         'project_id', detail.assignment_snapshot -> 'project_id',
         'project_ref', detail.assignment_snapshot -> 'project_ref',
         'project_name', detail.assignment_snapshot -> 'project_name',
         'project_scope_id', detail.assignment_snapshot -> 'project_scope_id',
         'project_scope_name',
           detail.assignment_snapshot -> 'project_scope_name'
       ) as value
       from public.v1_workforce_monthly_period_dates detail
       where detail.validation_run_id = v_run_id
         and detail.worker_id = date_row.worker_id
         and detail.assignment_snapshot ->> 'project_id' is not null) values_)
        as projects,
      (select coalesce(jsonb_agg(value order by value::text), '[]'::jsonb)
       from (select distinct jsonb_build_object(
         'internal_location_id',
           detail.assignment_snapshot -> 'internal_location_id',
         'internal_location_name',
           detail.assignment_snapshot -> 'internal_location_name'
       ) as value
       from public.v1_workforce_monthly_period_dates detail
       where detail.validation_run_id = v_run_id
         and detail.worker_id = date_row.worker_id
         and detail.assignment_snapshot ->> 'internal_location_id'
           is not null) values_) as locations,
      count(*) filter (where date_row.is_required)::integer
        as scheduled_count,
      count(*) filter (where not date_row.is_future
        and date_row.attendance_snapshot ->> 'attendance_status' = 'present')::integer
        as present_count,
      count(*) filter (where not date_row.is_future
        and date_row.attendance_snapshot ->> 'attendance_status' = 'absent')::integer
        as absent_count,
      count(*) filter (where not date_row.is_future
        and date_row.attendance_snapshot ->> 'attendance_status' in (
          'annual_leave', 'sick_leave', 'official_leave', 'unpaid_leave'
        ))::integer as leave_count,
      count(*) filter (where not date_row.is_future
        and date_row.day_type = 'weekly_off')::integer as weekly_off_count,
      count(*) filter (where not date_row.is_future
        and date_row.day_type = 'public_holiday')::integer
        as public_holiday_count,
      coalesce(sum(date_row.regular_minutes) filter (
        where not date_row.is_future
      ), 0)::bigint as regular_total,
      coalesce(sum(date_row.overtime_minutes) filter (
        where not date_row.is_future
      ), 0)::bigint as overtime_total,
      count(*) filter (where date_row.is_required and (
        date_row.attendance_snapshot is null
        or date_row.attendance_snapshot ->> 'attendance_status' = 'not_entered'
      ))::integer as missing_count
    from public.v1_workforce_monthly_period_dates date_row
    where date_row.validation_run_id = v_run_id
    group by date_row.worker_id
  ) grouped
  left join lateral (
    select
      count(*) filter (where issue.severity = 'blocking')::integer
        as blocking_count,
      count(*) filter (where issue.severity = 'warning')::integer
        as warning_count
    from public.v1_workforce_monthly_validation_issues issue
    where issue.validation_run_id = v_run_id
      and issue.worker_id = grouped.worker_id
  ) issue_counts on true;

  select
    count(*)::integer,
    (select count(*)::integer
     from public.v1_workforce_monthly_period_dates date_row
     where date_row.validation_run_id = v_run_id),
    coalesce(sum(worker.scheduled_day_count), 0)::integer,
    (select count(*)::integer
     from public.v1_workforce_monthly_period_dates date_row
     where date_row.validation_run_id = v_run_id and date_row.is_future),
    coalesce(sum(worker.present_day_count), 0)::integer,
    coalesce(sum(worker.absent_day_count), 0)::integer,
    coalesce(sum(worker.leave_day_count), 0)::integer,
    coalesce(sum(worker.weekly_off_day_count), 0)::integer,
    coalesce(sum(worker.public_holiday_day_count), 0)::integer,
    (select count(*)::integer
     from public.v1_workforce_monthly_period_dates date_row
     where date_row.validation_run_id = v_run_id
       and not date_row.is_future and date_row.day_type = 'site_closed'),
    coalesce(sum(worker.missing_day_count), 0)::integer,
    coalesce(sum(worker.regular_minutes), 0)::bigint,
    coalesce(sum(worker.overtime_minutes), 0)::bigint,
    (select coalesce(sum(date_row.allocation_minutes), 0)::bigint
     from public.v1_workforce_monthly_period_dates date_row
     where date_row.validation_run_id = v_run_id
       and not date_row.is_future),
    (select count(*)::integer
     from public.v1_workforce_monthly_validation_issues issue
     where issue.validation_run_id = v_run_id
       and issue.severity = 'blocking'),
    (select count(*)::integer
     from public.v1_workforce_monthly_validation_issues issue
     where issue.validation_run_id = v_run_id and issue.severity = 'warning')
  into v_worker_count, v_date_count, v_scheduled_count, v_future_count,
    v_present_count, v_absent_count, v_leave_count, v_weekly_off_count,
    v_public_holiday_count, v_site_closure_count, v_missing_count,
    v_total_regular, v_total_overtime, v_total_allocation,
    v_blocking_count, v_warning_count
  from public.v1_workforce_monthly_period_workers worker
  where worker.validation_run_id = v_run_id;

  select count(distinct nullif(
      date_row.assignment_snapshot ->> 'project_id', ''
    ))::integer,
    count(distinct nullif(
      date_row.assignment_snapshot ->> 'internal_location_id', ''
    ))::integer
  into v_project_count, v_location_count
  from public.v1_workforce_monthly_period_dates date_row
  where date_row.validation_run_id = v_run_id;

  v_run_status := case when v_blocking_count = 0
    then 'ready_for_review' else 'draft' end;
  v_final_fingerprint := public.v1_workforce_monthly_source_fingerprint(
    v_team_id, v_period_month
  );
  if v_final_fingerprint <> v_source_fingerprint then
    raise exception 'V1_WORKFORCE_MONTHLY_SOURCE_CHANGED'
      using errcode = '40001';
  end if;

  insert into public.v1_workforce_monthly_validation_runs (
    id, period_id, validation_number, validation_status,
    source_fingerprint, worker_count, date_count, scheduled_day_count,
    future_day_count, present_day_count, absent_day_count, leave_day_count,
    weekly_off_day_count, public_holiday_day_count, site_closure_day_count,
    missing_day_count, regular_minutes, overtime_minutes, allocation_minutes,
    blocking_issue_count, warning_issue_count, project_count, location_count,
    authority_snapshot, validated_by_auth_user_id, validated_by_exact_role,
    idempotency_key
  ) values (
    v_run_id, v_period_id, v_validation_number, v_run_status,
    v_source_fingerprint, v_worker_count, v_date_count, v_scheduled_count,
    v_future_count, v_present_count, v_absent_count, v_leave_count,
    v_weekly_off_count, v_public_holiday_count, v_site_closure_count,
    v_missing_count, v_total_regular, v_total_overtime, v_total_allocation,
    v_blocking_count, v_warning_count, v_project_count, v_location_count,
    jsonb_build_object(
      'authority_kind', case when v_role = 'admin'
        then 'admin_organization' else 'complete_month_responsibility' end,
      'exact_role', v_role,
      'capabilities', jsonb_build_array(
        'workforce.view', 'workforce.timesheets.maintain'
      )
    ),
    v_actor, v_role, p_idempotency_key
  );

  update public.v1_workforce_monthly_periods period
  set current_validation_run_id = v_run_id,
      current_validation_number = v_validation_number,
      current_status = v_run_status,
      record_version = case when v_is_initial
        then period.record_version else period.record_version + 1 end,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
  where period.id = v_period_id;

  select jsonb_build_object(
    'period_id', period.id,
    'current_validation_run_id', period.current_validation_run_id,
    'current_validation_number', period.current_validation_number,
    'current_status', period.current_status,
    'record_version', period.record_version,
    'source_fingerprint', v_source_fingerprint,
    'worker_count', v_worker_count,
    'blocking_issue_count', v_blocking_count,
    'warning_issue_count', v_warning_count
  ) into v_after
  from public.v1_workforce_monthly_periods period
  where period.id = v_period_id;

  perform public.v1_write_audit_event(
    'workforce_monthly_period_validated', 'workforce_monthly_period',
    v_period_id, null, v_before, v_after,
    'Monthly period validation', p_idempotency_key
  );
  v_response := public.v1_get_workforce_monthly_period(
    v_team_id, v_period_month, null, null, null, 50, 0
  );
  perform public.v1_complete_idempotency(
    'v1_validate_workforce_monthly_period', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_workforce_monthly_block_immutable_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_guard_period_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_source_rows(uuid,date)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_source_fingerprint(uuid,date)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_empty_scope_authorized(
  text,uuid,date
) from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_period_authorized(
  text,uuid,date,uuid,boolean
) from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_period_meta_json(uuid,text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_monthly_add_issue(
  uuid,uuid,date,text,text,jsonb,integer
) from public, anon, authenticated;

revoke all on function public.v1_list_workforce_monthly_teams(
  date,text,integer,integer
) from public, anon;
revoke all on function public.v1_get_workforce_monthly_period(
  uuid,date,text,text,text,integer,integer
) from public, anon;
revoke all on function public.v1_get_workforce_monthly_worker_detail(
  uuid,uuid,uuid
) from public, anon;
revoke all on function public.v1_list_workforce_monthly_issues(
  uuid,uuid,text,text,uuid,integer,integer
) from public, anon;
revoke all on function public.v1_validate_workforce_monthly_period(
  jsonb,bigint,uuid
) from public, anon;

grant execute on function public.v1_list_workforce_monthly_teams(
  date,text,integer,integer
) to authenticated, service_role;
grant execute on function public.v1_get_workforce_monthly_period(
  uuid,date,text,text,text,integer,integer
) to authenticated, service_role;
grant execute on function public.v1_get_workforce_monthly_worker_detail(
  uuid,uuid,uuid
) to authenticated, service_role;
grant execute on function public.v1_list_workforce_monthly_issues(
  uuid,uuid,text,text,uuid,integer,integer
) to authenticated, service_role;
grant execute on function public.v1_validate_workforce_monthly_period(
  jsonb,bigint,uuid
) to authenticated, service_role;

comment on function public.v1_validate_workforce_monthly_period(
  jsonb,bigint,uuid
) is
  'T06 atomic team-month initialization/revalidation. Payload keys are exactly team_id and period_month; workers, dates, totals and lifecycle actions are server-only.';

commit;
