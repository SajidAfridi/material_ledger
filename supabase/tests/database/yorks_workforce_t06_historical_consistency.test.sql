begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_workforce_monthly_guard_date_context()',
    'execute'
  ),
  'The T06 corrective date-context helper is not client-executable'
);

-- One historical month exercises retained project and internal allocations,
-- an allowed T01 assignment move, a legitimate leaver, and structurally
-- missing versus currently inactive supervisors.
insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values
  (
    '59a10000-0000-4000-8000-000000000001', 'WF-T06-HIST-A',
    'T06 Historical Project A', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '59a10000-0000-4000-8000-000000000002', 'WF-T06-HIST-B',
    'T06 Historical Project B', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values
  (
    '59a20000-0000-4000-8000-000000000001',
    '59a10000-0000-4000-8000-000000000001',
    'building', 'B01', 'Historical Building A', false, true
  ),
  (
    '59a20000-0000-4000-8000-000000000002',
    '59a10000-0000-4000-8000-000000000002',
    'building', 'B01', 'Historical Building B', false, true
  );

insert into public.v1_workforce_internal_locations (
  id, location_code, location_name, department, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59a30000-0000-4000-8000-000000000001', 'WF-T06-HIST-INT',
  'Historical Workshop', 'Workshop / Cost Centre', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59a40000-0000-4000-8000-000000000001', 'WF-T06-HIST-A',
    'T06 Historical Team A',
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001',
    '2025-06-01', '2025-06-30', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a40000-0000-4000-8000-000000000002', 'WF-T06-HIST-B',
    'T06 Historical Team B',
    '59a10000-0000-4000-8000-000000000002',
    '59a20000-0000-4000-8000-000000000002',
    '2025-06-01', '2025-06-30', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59a50000-0000-4000-8000-000000000001', 'WF-T06-HIST-W1',
    'Historical Project Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a50000-0000-4000-8000-000000000002', 'WF-T06-HIST-W2',
    'Historical Internal Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a50000-0000-4000-8000-000000000003', 'WF-T06-HIST-W3',
    'Historical Mid Month Leaver', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a50000-0000-4000-8000-000000000004', 'WF-T06-HIST-W4',
    'Missing Supervisor Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a50000-0000-4000-8000-000000000005', 'WF-T06-HIST-W5',
    'Inactive Supervisor Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a50000-0000-4000-8000-000000000006', 'WF-T06-HIST-W6',
    'Retained Supervisor Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2024-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, internal_location_id,
  valid_from, valid_to, reason, assigned_by_auth_user_id,
  assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59a60000-0000-4000-8000-000000000001',
    '59a50000-0000-4000-8000-000000000001', 'primary',
    '59a40000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001', null,
    '2025-06-10', '2025-06-10', 'Historical project day',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a60000-0000-4000-8000-000000000002',
    '59a50000-0000-4000-8000-000000000002', 'primary',
    '59a40000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    null, null, '59a30000-0000-4000-8000-000000000001',
    '2025-06-11', '2025-06-11', 'Historical internal day',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a60000-0000-4000-8000-000000000003',
    '59a50000-0000-4000-8000-000000000003', 'primary',
    '59a40000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001', null,
    '2025-06-12', '2025-06-12', 'Leaver final assignment day',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a60000-0000-4000-8000-000000000004',
    '59a50000-0000-4000-8000-000000000004', 'primary',
    '59a40000-0000-4000-8000-000000000001', null,
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001', null,
    '2025-06-13', '2025-06-13', 'Missing supervisor evidence',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a60000-0000-4000-8000-000000000005',
    '59a50000-0000-4000-8000-000000000005', 'primary',
    '59a40000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001', null,
    '2025-06-14', '2025-06-14', 'Inactive supervisor evidence',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a60000-0000-4000-8000-000000000006',
    '59a50000-0000-4000-8000-000000000006', 'primary',
    '59a40000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59a10000-0000-4000-8000-000000000001',
    '59a20000-0000-4000-8000-000000000001', null,
    '2025-06-15', '2025-06-15', 'Supervisor retained while active',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59a70000-0000-4000-8000-000000000001', 'WF-T06-HISTORY',
  'T06 Historical Calendar', 'Asia/Dubai', 480, 60,
  '2025-06-01', '2025-06-30', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select '59a70000-0000-4000-8000-000000000001'::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59a80000-0000-4000-8000-000000000001',
    '59a40000-0000-4000-8000-000000000001',
    '59a70000-0000-4000-8000-000000000001',
    '2025-06-01', '2025-06-30', 'Historical Team A schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59a80000-0000-4000-8000-000000000002',
    '59a40000-0000-4000-8000-000000000002',
    '59a70000-0000-4000-8000-000000000001',
    '2025-06-01', '2025-06-30', 'Historical Team B schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59a50000-0000-4000-8000-000000000001","work_date":"2025-06-10","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Accepted project history"}',
    null, '59a90000-0000-4000-8000-000000000001'
  )$$,
  'T03 accepts the project attendance fact before its assignment moves'
);
select lives_ok(
  $$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59a50000-0000-4000-8000-000000000002","work_date":"2025-06-11","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Accepted internal history"}',
    null, '59a90000-0000-4000-8000-000000000002'
  )$$,
  'T03 accepts the internal attendance fact before its location closes'
);
select lives_ok(
  $$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59a50000-0000-4000-8000-000000000003","work_date":"2025-06-12","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Accepted leaver history"}',
    null, '59a90000-0000-4000-8000-000000000003'
  )$$,
  'T03 accepts the leaver attendance while the worker is active'
);
select lives_ok(
  $$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59a50000-0000-4000-8000-000000000006","work_date":"2025-06-15","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Accepted supervisor history"}',
    null, '59a90000-0000-4000-8000-000000000009'
  )$$,
  'T03 accepts a supervisor identity while that supervisor is active'
);

reset role;
create temporary table t06_history_attendance_ids on commit drop as
select worker_id, id as attendance_day_id
from public.v1_workforce_attendance_days
where worker_id in (
  '59a50000-0000-4000-8000-000000000001',
  '59a50000-0000-4000-8000-000000000002'
);
grant select on pg_temp.t06_history_attendance_ids to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(
        select attendance_day_id from t06_history_attendance_ids
        where worker_id='59a50000-0000-4000-8000-000000000001'
      ),
      'attendance_record_version',1,
      'reason','Accepted retained project allocation',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work',
        'project_id','59a10000-0000-4000-8000-000000000001',
        'project_scope_id','59a20000-0000-4000-8000-000000000001',
        'activity_task','Historical project task',
        'regular_minutes',480,'overtime_minutes',0
      ))
    ),null,'59a90000-0000-4000-8000-000000000004'
  )$$,
  'T04 accepts the project allocation while its target is active'
);
select lives_ok(
  $$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(
        select attendance_day_id from t06_history_attendance_ids
        where worker_id='59a50000-0000-4000-8000-000000000002'
      ),
      'attendance_record_version',1,
      'reason','Accepted retained internal allocation',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','internal_work',
        'internal_location_id','59a30000-0000-4000-8000-000000000001',
        'activity_task','Historical internal task',
        'regular_minutes',480,'overtime_minutes',0
      ))
    ),null,'59a90000-0000-4000-8000-000000000005'
  )$$,
  'T04 accepts the internal allocation while its target is active'
);

select lives_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59a40000-0000-4000-8000-000000000001","period_month":"2025-06-01"}',
    null,'59a90000-0000-4000-8000-000000000006'
  )$$,
  'The first historical Team A validation succeeds'
);
reset role;

create temporary table t06_history_before on commit drop as
select
  run.id as run_id,
  run.source_fingerprint,
  public.v1_hash_json(to_jsonb(run)) as row_fingerprint
from public.v1_workforce_monthly_periods period
join public.v1_workforce_monthly_validation_runs run
  on run.id=period.current_validation_run_id
where period.team_id='59a40000-0000-4000-8000-000000000001'
  and period.period_month='2025-06-01';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_save_workforce_worker_assignment(
    '{"assignment_id":"59a60000-0000-4000-8000-000000000001","worker_id":"59a50000-0000-4000-8000-000000000001","assignment_kind":"primary","team_id":"59a40000-0000-4000-8000-000000000002","supervisor_auth_user_id":"10000000-0000-4000-8000-000000000004","project_id":"59a10000-0000-4000-8000-000000000002","project_scope_id":"59a20000-0000-4000-8000-000000000002","valid_from":"2025-06-10","valid_to":"2025-06-10","reason":"Allowed T01 historical assignment correction"}',
    1,'59a90000-0000-4000-8000-000000000007'
  )$$,
  'T01 still permits its optimistic past assignment correction'
);
reset role;

update public.v1_projects
set state='completed', record_version=record_version+1,
  updated_at=clock_timestamp()
where id='59a10000-0000-4000-8000-000000000001';
update public.v1_project_scopes
set is_active=false
where id='59a20000-0000-4000-8000-000000000001';
update public.v1_workforce_internal_locations
set is_active=false, record_version=record_version+1,
  updated_at=clock_timestamp()
where id='59a30000-0000-4000-8000-000000000001';
update public.v1_workforce_workers
set current_status='left_company', leaving_date='2025-06-12',
  record_version=record_version+1, updated_at=clock_timestamp()
where id='59a50000-0000-4000-8000-000000000003';
update public.v1_profiles set is_active=false
where auth_user_id='10000000-0000-4000-8000-000000000001';

select is(
  (
    select concat_ws('|',
      source_row #>> '{assignment,team_id}',
      source_row #>> '{assignment,assignment_id}',
      source_row #>> '{assignment,source}',
      source_row #>> '{schedule,source}',
      source_row #>> '{allocation,allocation_state}'
    )
    from public.v1_workforce_monthly_source_rows(
      '59a40000-0000-4000-8000-000000000001','2025-06-01'
    ) source_row
    where source_row ->> 'worker_id' =
      '59a50000-0000-4000-8000-000000000001'
      and source_row ->> 'work_date' = '2025-06-10'
  ),
  '59a40000-0000-4000-8000-000000000001|59a60000-0000-4000-8000-000000000001|attendance_snapshot|attendance_snapshot|active',
  'Team A retains the exact T03 assignment, schedule and T04 allocation after the T01 move'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_source_rows(
      '59a40000-0000-4000-8000-000000000002','2025-06-01'
    ) source_row
    where source_row ->> 'worker_id' =
      '59a50000-0000-4000-8000-000000000001'
      and source_row ->> 'work_date' = '2025-06-10'
  ),
  0::bigint,
  'Team B cannot absorb a worker/date already owned by retained Team A attendance'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_source_rows(
      '59a40000-0000-4000-8000-000000000001','2025-06-01'
    ) source_row
    where source_row ->> 'worker_id' in (
      '59a50000-0000-4000-8000-000000000001',
      '59a50000-0000-4000-8000-000000000002'
    )
      and coalesce(
        (source_row #>> '{allocation,has_invalid_target}')::boolean, false
      )
  ),
  0::bigint,
  'Later project, scope and internal-location closure does not invalidate retained T04 targets'
);
select is(
  (
    select concat_ws('|',
      source_row #>> '{worker,current_status}',
      source_row #>> '{worker,status_basis}',
      source_row #>> '{assignment,source}'
    )
    from public.v1_workforce_monthly_source_rows(
      '59a40000-0000-4000-8000-000000000001','2025-06-01'
    ) source_row
    where source_row ->> 'worker_id' =
      '59a50000-0000-4000-8000-000000000003'
  ),
  'active|attendance_snapshot|attendance_snapshot',
  'A legitimate leaver retains the active T03 status that applied on the work date'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59a40000-0000-4000-8000-000000000001","period_month":"2025-06-01"}',
    1,'59a90000-0000-4000-8000-000000000008'
  )$$,
  'Explicit corrected revalidation appends after mutable parent changes'
);
reset role;

select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_issues issue
    join public.v1_workforce_monthly_validation_runs run
      on run.id=issue.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and issue.worker_id='59a50000-0000-4000-8000-000000000003'
      and issue.issue_code='worker_inactive'
  ),
  0::bigint,
  'Later left_company state creates no retroactive worker_inactive blocker'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_issues issue
    join public.v1_workforce_monthly_validation_runs run
      on run.id=issue.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and issue.worker_id in (
        '59a50000-0000-4000-8000-000000000001',
        '59a50000-0000-4000-8000-000000000002'
      )
      and issue.issue_code='allocation_target_invalid'
  ),
  0::bigint,
  'Closed retained project and internal targets create no retroactive blocking issue'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_issues issue
    join public.v1_workforce_monthly_validation_runs run
      on run.id=issue.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and issue.worker_id='59a50000-0000-4000-8000-000000000004'
      and issue.issue_code='supervisor_invalid'
      and issue.issue_context ->> 'reason'='missing_supervisor'
  ),
  1::bigint,
  'A missing supervisor is an explicit blocking supervisor_invalid issue'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_issues issue
    join public.v1_workforce_monthly_validation_runs run
      on run.id=issue.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and issue.worker_id='59a50000-0000-4000-8000-000000000005'
      and issue.issue_code='supervisor_invalid'
  ),
  1::bigint,
  'A currently inactive supervisor remains a distinct blocking supervisor_invalid issue for a prospective day'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_issues issue
    join public.v1_workforce_monthly_validation_runs run
      on run.id=issue.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and issue.worker_id='59a50000-0000-4000-8000-000000000006'
      and issue.issue_code='supervisor_invalid'
  ),
  0::bigint,
  'Later supervisor deactivation does not retroactively invalidate a retained T03 supervisor identity'
);
select is(
  (
    select public.v1_hash_json(to_jsonb(run))
    from public.v1_workforce_monthly_validation_runs run
    join t06_history_before before on before.run_id=run.id
  ),
  (select row_fingerprint from t06_history_before),
  'The complete prior validation-run row remains byte-stable after revalidation'
);
select is(
  (
    select run.source_fingerprint
    from public.v1_workforce_monthly_validation_runs run
    join t06_history_before before on before.run_id=run.id
  ),
  (select source_fingerprint from t06_history_before),
  'The immutable prior run retains its original source fingerprint'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_validation_runs run
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
  ),
  2::bigint,
  'Corrected revalidation appends exactly one new immutable run'
);
select is(
  (
    select concat_ws('|',
      date_row.assignment_snapshot ->> 'team_id',
      date_row.assignment_snapshot ->> 'assignment_id',
      date_row.assignment_snapshot ->> 'source'
    )
    from public.v1_workforce_monthly_period_dates date_row
    join public.v1_workforce_monthly_validation_runs run
      on run.id=date_row.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
      and date_row.worker_id='59a50000-0000-4000-8000-000000000001'
      and date_row.work_date='2025-06-10'
  ),
  '59a40000-0000-4000-8000-000000000001|59a60000-0000-4000-8000-000000000001|attendance_snapshot',
  'The new run retains Team A assignment evidence rather than current Team B'
);
select is(
  (
    select count(*)
    from public.v1_workforce_monthly_period_dates date_row
    join public.v1_workforce_monthly_validation_runs run
      on run.id=date_row.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
  ),
  (
    select count(distinct concat_ws('|',
      date_row.worker_id::text,date_row.work_date::text
    ))
    from public.v1_workforce_monthly_period_dates date_row
    join public.v1_workforce_monthly_validation_runs run
      on run.id=date_row.validation_run_id
    join public.v1_workforce_monthly_periods period on period.id=run.period_id
    where period.team_id='59a40000-0000-4000-8000-000000000001'
      and period.period_month='2025-06-01'
      and run.validation_number=2
  ),
  'The canonical retained/prospective union has no worker/date duplicates'
);

select * from finish();
rollback;
