begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_workforce_monthly_team_applicable(uuid,date)',
    'execute'
  ),
  'The canonical team-month applicability predicate is not client-executable'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59b10000-0000-4000-8000-000000000001', 'WF-T06-APPLICABLE',
  'T06 Historical Applicability Project', 'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values (
  '59b20000-0000-4000-8000-000000000001',
  '59b10000-0000-4000-8000-000000000001',
  'building', 'B01', 'Historical Applicability Building', false, true
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_supervisor_auth_user_id,
  default_project_id, default_project_scope_id, valid_from, valid_to,
  is_active, created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59b30000-0000-4000-8000-000000000001', 'WF-T06-APPLICABLE-A',
    'Historical Applicability Team A',
    '10000000-0000-4000-8000-000000000004',
    '59b10000-0000-4000-8000-000000000001',
    '59b20000-0000-4000-8000-000000000001',
    '2025-04-01', '2025-04-30', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59b30000-0000-4000-8000-000000000002', 'WF-T06-APPLICABLE-B',
    'Historical Applicability Team B',
    '10000000-0000-4000-8000-000000000004',
    '59b10000-0000-4000-8000-000000000001',
    '59b20000-0000-4000-8000-000000000001',
    '2025-04-01', '2025-04-30', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59b30000-0000-4000-8000-000000000003', 'WF-T06-NO-EVIDENCE',
    'Genuinely Non Effective Team',
    '10000000-0000-4000-8000-000000000004',
    '59b10000-0000-4000-8000-000000000001',
    '59b20000-0000-4000-8000-000000000001',
    '2025-05-01', '2025-05-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59b40000-0000-4000-8000-000000000001', 'WF-T06-APPLICABLE-W1',
  'Historical Applicability Worker', 'Technician', 'Yorks AC & Ref.',
  'yorks_employee', '2024-01-01', 'active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59b50000-0000-4000-8000-000000000001',
  '59b40000-0000-4000-8000-000000000001', 'primary',
  '59b30000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '59b10000-0000-4000-8000-000000000001',
  '59b20000-0000-4000-8000-000000000001',
  '2025-04-15', '2025-04-15', 'Original Team A work date',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59b60000-0000-4000-8000-000000000001', 'WF-T06-APPLICABLE',
  'Historical Applicability Calendar', 'Asia/Dubai', 480, 60,
  '2025-04-01', '2025-04-30', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select '59b60000-0000-4000-8000-000000000001'::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59b70000-0000-4000-8000-000000000001',
    '59b30000-0000-4000-8000-000000000001',
    '59b60000-0000-4000-8000-000000000001',
    '2025-04-01', '2025-04-30', 'Team A schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59b70000-0000-4000-8000-000000000002',
    '59b30000-0000-4000-8000-000000000002',
    '59b60000-0000-4000-8000-000000000001',
    '2025-04-01', '2025-04-30', 'Team B schedule',
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
    '{"worker_id":"59b40000-0000-4000-8000-000000000001","work_date":"2025-04-15","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Accepted Team A history"}',
    null, '59b90000-0000-4000-8000-000000000001'
  )$$,
  'T03 accepts the Team A attendance fact before mutable parent edits'
);

select lives_ok(
  $$select public.v1_save_workforce_worker_assignment(
    '{"assignment_id":"59b50000-0000-4000-8000-000000000001","worker_id":"59b40000-0000-4000-8000-000000000001","assignment_kind":"primary","team_id":"59b30000-0000-4000-8000-000000000002","supervisor_auth_user_id":"10000000-0000-4000-8000-000000000004","project_id":"59b10000-0000-4000-8000-000000000001","project_scope_id":"59b20000-0000-4000-8000-000000000001","valid_from":"2025-04-15","valid_to":"2025-04-15","reason":"Current assignment moved to Team B"}',
    1, '59b90000-0000-4000-8000-000000000002'
  )$$,
  'The T01 command moves the only current assignment from Team A to Team B'
);
reset role;

-- The accepted T02 retained-schedule guard normally prevents narrowing a
-- parent team window. Suppress that independent trigger only inside this
-- rolled-back fixture so the T01 command can reproduce the audited persisted
-- parent-state condition without weakening T02 in production.
set local session_replication_role = replica;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_save_workforce_team(
    '{"team_id":"59b30000-0000-4000-8000-000000000001","team_code":"WF-T06-APPLICABLE-A","team_name":"Historical Applicability Team A","default_supervisor_auth_user_id":"10000000-0000-4000-8000-000000000004","default_project_id":"59b10000-0000-4000-8000-000000000001","default_project_scope_id":"59b20000-0000-4000-8000-000000000001","valid_from":"2025-03-01","valid_to":"2025-03-31","is_active":false}',
    1, '59b90000-0000-4000-8000-000000000003'
  )$$,
  'The T01 command records a non-overlapping current Team A window after its assignment moves'
);
reset role;
set local session_replication_role = origin;

select is(
  (select concat_ws('|', valid_from, valid_to, is_active)
   from public.v1_workforce_teams
   where id='59b30000-0000-4000-8000-000000000001'),
  '2025-03-01|2025-03-31|f',
  'The current Team A parent state no longer overlaps the retained April month'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (select count(*)
   from jsonb_array_elements(
     public.v1_list_workforce_monthly_teams(
       '2025-04-01', null, 50, 0
     ) -> 'teams'
   ) team
   where team ->> 'team_id'='59b30000-0000-4000-8000-000000000001'),
  1::bigint,
  'The authorized selector retains Team A from its accepted T03 April evidence'
);

select is(
  public.v1_get_workforce_monthly_period(
    '59b30000-0000-4000-8000-000000000001',
    '2025-04-01', null, null, null, 50, 0
  ) -> 'period',
  'null'::jsonb,
  'The retained absent-period read succeeds without manufacturing a period'
);
reset role;

select is(
  (select count(*) from public.v1_workforce_monthly_periods period
   where period.team_id='59b30000-0000-4000-8000-000000000001'
     and period.period_month='2025-04-01'),
  0::bigint,
  'Reading retained Team A history creates no monthly period'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59b30000-0000-4000-8000-000000000001","period_month":"2025-04-01"}',
    null, '59b90000-0000-4000-8000-000000000004'
  )$$,
  'Explicit validation initializes retained Team A history exactly once'
);
reset role;

select is(
  (select count(*) from public.v1_workforce_monthly_periods period
   where period.team_id='59b30000-0000-4000-8000-000000000001'
     and period.period_month='2025-04-01'),
  1::bigint,
  'Retained Team A produces exactly one April period'
);
select is(
  (select count(*) from public.v1_audit_events audit
   where audit.event_type='workforce_monthly_period_validated'
     and audit.entity_id=(
       select period.id from public.v1_workforce_monthly_periods period
       where period.team_id='59b30000-0000-4000-8000-000000000001'
         and period.period_month='2025-04-01'
     )),
  1::bigint,
  'Retained Team A initialization emits one audit effect'
);
select is(
  (select count(*)
   from public.v1_workforce_monthly_source_rows(
     '59b30000-0000-4000-8000-000000000002', '2025-04-01'
   ) source_row
   where source_row ->> 'worker_id'='59b40000-0000-4000-8000-000000000001'
     and source_row ->> 'work_date'='2025-04-15'),
  0::bigint,
  'Team B cannot absorb the retained Team A attendance date'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  (select count(*)
   from jsonb_array_elements(
     public.v1_list_workforce_monthly_teams(
       '2025-04-01', null, 50, 0
     ) -> 'teams'
   ) team
   where team ->> 'team_id'='59b30000-0000-4000-8000-000000000003'),
  0::bigint,
  'A genuinely non-effective team with no retained evidence or period stays hidden'
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59b30000-0000-4000-8000-000000000003',
    '2025-04-01', null, null, null, 50, 0
  )$$,
  '23514', 'V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE',
  'Absent-period read still rejects a genuinely non-effective empty team'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59b30000-0000-4000-8000-000000000003","period_month":"2025-04-01"}',
    null, '59b90000-0000-4000-8000-000000000005'
  )$$,
  '23514', 'V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE',
  'Validation still rejects a genuinely non-effective empty team'
);
reset role;

select * from finish();
rollback;
