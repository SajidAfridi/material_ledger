begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select is(
  (select count(*) from public.v1_capability_catalog catalog
   where catalog.capability_key in (
       'workforce.view',
       'workforce.attendance.maintain',
       'workforce.timesheets.maintain'
     )
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable),
  3::bigint,
  'T06 reuses the three accepted operational Workforce capabilities'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_list_workforce_monthly_teams(date,text,integer,integer)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_monthly_period(uuid,date,text,text,text,integer,integer)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_monthly_worker_detail(uuid,uuid,uuid)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_list_workforce_monthly_issues(uuid,uuid,text,text,uuid,integer,integer)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_validate_workforce_monthly_period(jsonb,bigint,uuid)',
    'execute'
  ),
  'Authenticated callers receive only the five public T06 RPC grants'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_workforce_monthly_periods', 'select,insert,update,delete'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_workforce_monthly_validation_runs', 'select,insert,update,delete'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_workforce_monthly_period_workers', 'select,insert,update,delete'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_workforce_monthly_period_dates', 'select,insert,update,delete'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_workforce_monthly_validation_issues', 'select,insert,update,delete'
  ),
  'Authenticated direct CRUD is revoked from every private T06 relation'
);

select ok(
  not has_function_privilege(
    'authenticated', 'public.v1_workforce_monthly_source_rows(uuid,date)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'public.v1_workforce_monthly_source_fingerprint(uuid,date)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'public.v1_workforce_monthly_period_authorized(text,uuid,date,uuid,boolean)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'public.v1_workforce_monthly_add_issue(uuid,uuid,date,text,text,jsonb,integer)', 'execute'
  ),
  'T06 SECURITY DEFINER helpers are not client-executable'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59610000-0000-4000-8000-000000000001', 'WF-T06-A',
  'Workforce T06 Project', 'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values (
  '59620000-0000-4000-8000-000000000001',
  '59610000-0000-4000-8000-000000000001',
  'common', 'common', 'Common / All Buildings', true, true
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59630000-0000-4000-8000-000000000001', 'WF-T06-A',
  'T06 Authorized Team', '59610000-0000-4000-8000-000000000001',
  '59620000-0000-4000-8000-000000000001',
  '2026-08-01', '2026-08-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59640000-0000-4000-8000-000000000001', 'WF-T06-W1',
  'T06 Gap Worker', 'Ductman', 'Yorks AC & Ref.', 'yorks_employee',
  '2026-01-01', 'active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59650000-0000-4000-8000-000000000001',
    '59640000-0000-4000-8000-000000000001', 'primary',
    '59630000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '59610000-0000-4000-8000-000000000001',
    '59620000-0000-4000-8000-000000000001',
    '2026-08-01', '2026-08-05', 'T06 first retained assignment segment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59650000-0000-4000-8000-000000000002',
    '59640000-0000-4000-8000-000000000001', 'primary',
    '59630000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '59610000-0000-4000-8000-000000000001',
    '59620000-0000-4000-8000-000000000001',
    '2026-08-10', '2026-08-12', 'T06 second retained assignment segment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59660000-0000-4000-8000-000000000001', 'WF-T06-DXB',
  'T06 Dubai Calendar', 'Asia/Dubai', 480, 60,
  '2026-08-01', '2026-08-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select '59660000-0000-4000-8000-000000000001'::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59680000-0000-4000-8000-000000000001',
  '59630000-0000-4000-8000-000000000001',
  '59660000-0000-4000-8000-000000000001',
  '2026-08-01', '2026-08-31', 'T06 schedule',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_READ_DENIED',
  'Role-only Project Engineer cannot read a monthly period'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    null, '59690000-0000-4000-8000-000000000099'
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED',
  'Role-only Project Engineer cannot initialize a monthly period'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_READ_DENIED',
  'Role-only Site Engineer cannot read a monthly period'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    null, '59690000-0000-4000-8000-000000000098'
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED',
  'Role-only Procurement cannot initialize a monthly period'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
reset role;

select is(
  (public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  ) -> 'period')::text,
  'null',
  'Authorized absent-period read returns an explicit null period'
);
select is(
  (select count(*) from public.v1_workforce_monthly_periods period
   where period.team_id = '59630000-0000-4000-8000-000000000001'),
  0::bigint,
  'Reading an absent period creates no root'
);
select is(
  (public.v1_list_workforce_monthly_teams(
    '2026-08-01', 'T06 Authorized', 50, 0
  ) ->> 'total_count')::bigint,
  1::bigint,
  'Dedicated monthly team selector returns the authorized team without creation'
);

create temporary table t06_initial_response(value jsonb) on commit drop;
insert into t06_initial_response(value)
select public.v1_validate_workforce_monthly_period(
  '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
  null, '59690000-0000-4000-8000-000000000001'
);

select is((value ->> 'schema_version')::integer, 1,
  'Validation returns strict schema version 1') from t06_initial_response;
select is(value #>> '{period,record_version}', '1',
  'First initialization exposes period version 1') from t06_initial_response;
select is(value #>> '{period,current_validation_number}', '1',
  'First initialization creates validation run 1') from t06_initial_response;
select is(value #>> '{summary,date_count}', '8',
  'Date count uses actual retained worker/date rows and does not span assignment gaps')
from t06_initial_response;
select is(value #>> '{summary,worker_count}', '1',
  'Server derives the exact worker count') from t06_initial_response;
select is(value #>> '{summary,scheduled_day_count}', '8',
  'Server derives scheduled days only from applicable nonfuture dates')
from t06_initial_response;
select is(value #>> '{summary,missing_day_count}', '8',
  'Required missing entries are blocking and server-derived')
from t06_initial_response;
select is(value #>> '{period,effective_status}', 'draft',
  'Blocking issues keep the period draft') from t06_initial_response;
select is((value -> 'workers' -> 0 ->> 'status'), 'has_errors',
  'Worker summary exposes the error state without client totals')
from t06_initial_response;

select is(
  (select count(*) from public.v1_workforce_monthly_validation_runs run
   where run.period_id = (
     select period.id from public.v1_workforce_monthly_periods period
     where period.team_id = '59630000-0000-4000-8000-000000000001'
       and period.period_month = '2026-08-01'
   )),
  1::bigint,
  'Initialization creates exactly one immutable validation run'
);
select is(
  (select count(*) from public.v1_workforce_monthly_period_dates date_row
   join public.v1_workforce_monthly_validation_runs run
     on run.id = date_row.validation_run_id
   where run.period_id = (
     select period.id from public.v1_workforce_monthly_periods period
     where period.team_id = '59630000-0000-4000-8000-000000000001'
       and period.period_month = '2026-08-01'
   )),
  8::bigint,
  'Initialization retains exactly eight applicable date snapshots'
);
select is(
  (select count(*) from public.v1_workforce_monthly_validation_issues
   where issue_code = 'required_attendance_missing'
     and validation_run_id = (
       select period.current_validation_run_id
       from public.v1_workforce_monthly_periods period
       where period.team_id = '59630000-0000-4000-8000-000000000001'
         and period.period_month = '2026-08-01'
     )),
  8::bigint,
  'Initialization retains stable typed required-attendance issues'
);

select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    null, '59690000-0000-4000-8000-000000000001'
  ) #>> '{period,current_validation_run_id}',
  (select value #>> '{period,current_validation_run_id}'
   from t06_initial_response),
  'Same-key same-payload retry returns the original run'
);
select is(
  (select count(*) from public.v1_workforce_monthly_validation_runs run
   where run.period_id = (
     select period.id from public.v1_workforce_monthly_periods period
     where period.team_id = '59630000-0000-4000-8000-000000000001'
       and period.period_month = '2026-08-01'
   )),
  1::bigint,
  'Idempotent retry creates no duplicate validation run'
);
select is(
  (select count(*) from public.v1_audit_events audit
   where audit.event_type = 'workforce_monthly_period_validated'
     and audit.entity_id = (
       select period.id from public.v1_workforce_monthly_periods period
       where period.team_id = '59630000-0000-4000-8000-000000000001'
         and period.period_month = '2026-08-01'
     )),
  1::bigint,
  'Initialization and replay emit exactly one audit effect'
);

select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01","workers":[]}',
    1, '59690000-0000-4000-8000-000000000002'
  )$$,
  '22023', 'V1_WORKFORCE_MONTHLY_VALIDATE_PAYLOAD_INVALID',
  'Unknown/client worker payload keys fail before mutation'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-02"}',
    1, '59690000-0000-4000-8000-000000000003'
  )$$,
  '22023', 'V1_WORKFORCE_MONTHLY_VALIDATE_PAYLOAD_INVALID',
  'Period identity must use the first Gregorian date of the month'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    99, '59690000-0000-4000-8000-000000000004'
  )$$,
  '40001', 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT',
  'Stale expected period version fails atomically'
);

select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    1, '59690000-0000-4000-8000-000000000005'
  ) #>> '{period,record_version}',
  '2',
  'Explicit revalidation advances the period version exactly once'
);
select is(
  (select count(*) from public.v1_workforce_monthly_validation_runs run
   where run.period_id = (
     select period.id from public.v1_workforce_monthly_periods period
     where period.team_id = '59630000-0000-4000-8000-000000000001'
       and period.period_month = '2026-08-01'
   )),
  2::bigint,
  'Revalidation appends a second run without rewriting the first'
);
select is(
  (select count(*) from public.v1_workforce_monthly_period_dates
   where validation_run_id = (
     select run.id from public.v1_workforce_monthly_validation_runs run
     join public.v1_workforce_monthly_periods period
       on period.id = run.period_id
     where run.validation_number = 1
       and period.team_id = '59630000-0000-4000-8000-000000000001'
       and period.period_month = '2026-08-01'
   )),
  8::bigint,
  'Prior run date evidence remains retained after revalidation'
);

select lives_ok(
  $$select public.v1_get_workforce_monthly_worker_detail(
    (select id from public.v1_workforce_monthly_periods
     where team_id = '59630000-0000-4000-8000-000000000001'
       and period_month = '2026-08-01'),
    (select current_validation_run_id
     from public.v1_workforce_monthly_periods
     where team_id = '59630000-0000-4000-8000-000000000001'
       and period_month = '2026-08-01'),
    '59640000-0000-4000-8000-000000000001'
  )$$,
  'Authorized worker daily drill-down returns retained evidence'
);
select is(
  (public.v1_list_workforce_monthly_issues(
    (select id from public.v1_workforce_monthly_periods
     where team_id = '59630000-0000-4000-8000-000000000001'
       and period_month = '2026-08-01'),
    (select current_validation_run_id
     from public.v1_workforce_monthly_periods
     where team_id = '59630000-0000-4000-8000-000000000001'
       and period_month = '2026-08-01'),
    'blocking', 'required_attendance_missing', null, 500, 0
  ) ->> 'total_count')::bigint,
  8::bigint,
  'Exception-first list filters stable issue codes with exact pagination'
);
reset role;

select throws_ok(
  $$delete from public.v1_workforce_monthly_validation_runs
    where id = (
      select run.id from public.v1_workforce_monthly_validation_runs run
      join public.v1_workforce_monthly_periods period
        on period.id = run.period_id
      where run.validation_number = 1
        and period.team_id = '59630000-0000-4000-8000-000000000001'
        and period.period_month = '2026-08-01'
    )$$,
  '42501', 'V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Validation history cannot be hard-deleted even by direct administration'
);
select throws_ok(
  $$update public.v1_workforce_monthly_validation_runs
    set validation_status = 'ready_for_review'
    where id = (
      select run.id from public.v1_workforce_monthly_validation_runs run
      join public.v1_workforce_monthly_periods period
        on period.id = run.period_id
      where run.validation_number = 1
        and period.team_id = '59630000-0000-4000-8000-000000000001'
        and period.period_month = '2026-08-01'
    )$$,
  '23514', 'V1_WORKFORCE_MONTHLY_HISTORY_IMMUTABLE',
  'Validation history cannot be updated in place'
);

-- T06 never accepts role labels or capability grants without the exact dated
-- responsibility path. These fixtures are deliberately added after the
-- immutable-history checks so they cannot influence the initial Admin run.
insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '596a0000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002', 'workforce.view',
    'grant', 'organization', 'permission_management', '2026-01-01',
    'T06 capability-only view negative',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596a0000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.maintain', 'grant', 'organization',
    'permission_management', '2026-01-01',
    'T06 capability-only validate negative',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (public.v1_list_workforce_monthly_teams(
    '2026-08-01', 'T06 Authorized', 50, 0
  ) ->> 'total_count')::bigint,
  0::bigint,
  'Capability without responsibility exposes no monthly team selector'
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_READ_DENIED',
  'Capability without responsibility cannot read monthly totals'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    2, '59690000-0000-4000-8000-000000000097'
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED',
  'Capability without responsibility cannot validate'
);
reset role;

insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '596a0000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000001', 'workforce.view',
    'grant', 'project', 'permission_management', '2026-01-01',
    'T06 exact project view grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596a0000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000001',
    'workforce.timesheets.maintain', 'grant', 'project',
    'permission_management', '2026-01-01',
    'T06 exact project validate grant',
    '10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_permission_assignment_projects (
  assignment_id, project_id
) values
  ('596a0000-0000-4000-8000-000000000003',
   '59610000-0000-4000-8000-000000000001'),
  ('596a0000-0000-4000-8000-000000000004',
   '59610000-0000-4000-8000-000000000001');
insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, project_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '596b0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001', 'project',
  '59610000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', 'T06 exact project responsibility',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  (public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  ) #>> '{capabilities,can_validate}')::boolean,
  true,
  'Complete project capability and responsibility exposes validation authority'
);
select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    2, '59690000-0000-4000-8000-000000000006'
  ) #>> '{period,record_version}',
  '3',
  'A complete non-Admin authority path may explicitly revalidate'
);
reset role;

update auth.users
set banned_until = clock_timestamp() + interval '1 day'
where id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_READ_DENIED',
  'An inactive identity loses monthly read authority'
);
reset role;
update auth.users
set banned_until = null
where id = '10000000-0000-4000-8000-000000000001';

update public.v1_permission_assignments
set effective_until = '2026-07-31'
where id in (
  '596a0000-0000-4000-8000-000000000003',
  '596a0000-0000-4000-8000-000000000004'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001', '2026-08-01',
    null, null, null, 50, 0
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_READ_DENIED',
  'Expired capability grants lose monthly read authority'
);
reset role;
update public.v1_permission_assignments
set effective_until = null
where id in (
  '596a0000-0000-4000-8000-000000000003',
  '596a0000-0000-4000-8000-000000000004'
);

update public.v1_workforce_responsibility_assignments
set valid_to = '2026-07-31', record_version = record_version + 1,
    updated_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    updated_at = clock_timestamp()
where id = '596b0000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    3, '59690000-0000-4000-8000-000000000096'
  )$$,
  '42501', 'V1_WORKFORCE_MONTHLY_VALIDATE_DENIED',
  'Expired dated responsibility loses monthly validation authority'
);
reset role;
update public.v1_workforce_responsibility_assignments
set valid_to = '2027-12-31', record_version = record_version + 1,
    updated_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    updated_at = clock_timestamp()
where id = '596b0000-0000-4000-8000-000000000001';

-- Calendar-boundary fixtures are derived from the server clock on every run.
-- Kiritimati and Honolulu are exactly one civil date apart, so this remains
-- deterministic without pinning assertions to August 2026.
create temporary table t06_calendar_boundary (
  east_date date not null,
  west_date date not null,
  period_month date not null
) on commit drop;
insert into t06_calendar_boundary (east_date, west_date, period_month)
select
  (clock_timestamp() at time zone 'Pacific/Kiritimati')::date,
  (clock_timestamp() at time zone 'Pacific/Honolulu')::date,
  date_trunc(
    'month', (clock_timestamp() at time zone 'Pacific/Kiritimati')::date
  )::date;
grant select on pg_temp.t06_calendar_boundary to authenticated;

select is(
  (select east_date from t06_calendar_boundary),
  (select west_date + 1 from t06_calendar_boundary),
  'Extreme calendar fixtures derive adjacent civil dates from server time'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values
  (
    '596c0000-0000-4000-8000-000000000001', 'WF-T06-TZ-E',
    'T06 Kiritimati Project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '596c0000-0000-4000-8000-000000000002', 'WF-T06-TZ-W',
    'T06 Honolulu Project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );
insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values
  (
    '596c1000-0000-4000-8000-000000000001',
    '596c0000-0000-4000-8000-000000000001',
    'common', 'common', 'Common / All Buildings', true, true
  ),
  (
    '596c1000-0000-4000-8000-000000000002',
    '596c0000-0000-4000-8000-000000000002',
    'common', 'common', 'Common / All Buildings', true, true
  );
insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '596c2000-0000-4000-8000-000000000001', 'WF-T06-TZ-E',
    'T06 Kiritimati Team', '596c0000-0000-4000-8000-000000000001',
    '596c1000-0000-4000-8000-000000000001',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary), true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596c2000-0000-4000-8000-000000000002', 'WF-T06-TZ-W',
    'T06 Honolulu Team', '596c0000-0000-4000-8000-000000000002',
    '596c1000-0000-4000-8000-000000000002',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary), true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '596c3000-0000-4000-8000-000000000001', 'WF-T06-TZ-E-W1',
    'T06 Kiritimati Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2020-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596c3000-0000-4000-8000-000000000002', 'WF-T06-TZ-W-W1',
    'T06 Honolulu Worker', 'Technician', 'Yorks AC & Ref.',
    'yorks_employee', '2020-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '596c4000-0000-4000-8000-000000000001',
    '596c3000-0000-4000-8000-000000000001', 'primary',
    '596c2000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '596c0000-0000-4000-8000-000000000001',
    '596c1000-0000-4000-8000-000000000001',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary),
    'T06 calendar boundary east assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596c4000-0000-4000-8000-000000000002',
    '596c3000-0000-4000-8000-000000000002', 'primary',
    '596c2000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000004',
    '596c0000-0000-4000-8000-000000000002',
    '596c1000-0000-4000-8000-000000000002',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary),
    'T06 calendar boundary west assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '596c5000-0000-4000-8000-000000000001', 'WF-T06-KIRITIMATI',
    'T06 Kiritimati Calendar', 'Pacific/Kiritimati', 480, 60,
    '2020-01-01', '2035-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596c5000-0000-4000-8000-000000000002', 'WF-T06-HONOLULU',
    'T06 Honolulu Calendar', 'Pacific/Honolulu', 480, 60,
    '2020-01-01', '2035-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select calendar_id, weekday, 'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from unnest(array[
  '596c5000-0000-4000-8000-000000000001'::uuid,
  '596c5000-0000-4000-8000-000000000002'::uuid
]) calendar_id
cross join generate_series(1, 7) weekday;
insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '596c6000-0000-4000-8000-000000000001',
    '596c2000-0000-4000-8000-000000000001',
    '596c5000-0000-4000-8000-000000000001',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary),
    'T06 calendar boundary east schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '596c6000-0000-4000-8000-000000000002',
    '596c2000-0000-4000-8000-000000000002',
    '596c5000-0000-4000-8000-000000000002',
    (select east_date from t06_calendar_boundary),
    (select east_date from t06_calendar_boundary),
    'T06 calendar boundary west schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

alter table public.v1_workforce_attendance_days
  disable trigger v1_workforce_attendance_future_date_guard;
alter table public.v1_workforce_timesheet_allocation_revisions
  disable trigger v1_workforce_timesheet_revision_future_date_guard;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  format(
    $sql$select public.v1_save_workforce_attendance_day(
      jsonb_build_object(
        'worker_id','596c3000-0000-4000-8000-000000000002',
        'work_date',%L::date,'attendance_status','present',
        'regular_minutes',480,'overtime_minutes',60,
        'reason','Retained pre-guard future evidence fixture'
      ),null,'596c7000-0000-4000-8000-000000000001'
    )$sql$,
    (select east_date::text from t06_calendar_boundary)
  ),
  'A controlled test fixture preserves legacy future attendance evidence'
);
reset role;
create temporary table t06_future_attendance(day_id uuid not null)
  on commit drop;
insert into t06_future_attendance(day_id)
select id from public.v1_workforce_attendance_days
where worker_id = '596c3000-0000-4000-8000-000000000002'
  and work_date = (select east_date from t06_calendar_boundary);
grant select on pg_temp.t06_future_attendance to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from t06_future_attendance),
      'attendance_record_version',1,
      'reason','Retained pre-guard future allocation evidence fixture',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work',
        'project_id','596c0000-0000-4000-8000-000000000002',
        'project_scope_id','596c1000-0000-4000-8000-000000000002',
        'activity_task','Retained future evidence',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'596c7000-0000-4000-8000-000000000002'
  )$sql$,
  'A controlled test fixture preserves legacy future allocation evidence'
);
reset role;
alter table public.v1_workforce_timesheet_allocation_revisions
  enable trigger v1_workforce_timesheet_revision_future_date_guard;
alter table public.v1_workforce_attendance_days
  enable trigger v1_workforce_attendance_future_date_guard;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
create temporary table t06_east_response(value jsonb) on commit drop;
insert into t06_east_response(value)
select public.v1_validate_workforce_monthly_period(
  jsonb_build_object(
    'team_id','596c2000-0000-4000-8000-000000000001',
    'period_month',(select period_month from t06_calendar_boundary)
  ),null,'596c8000-0000-4000-8000-000000000001'
);
create temporary table t06_west_response(value jsonb) on commit drop;
insert into t06_west_response(value)
select public.v1_validate_workforce_monthly_period(
  jsonb_build_object(
    'team_id','596c2000-0000-4000-8000-000000000002',
    'period_month',(select period_month from t06_calendar_boundary)
  ),null,'596c8000-0000-4000-8000-000000000002'
);

select is(
  (select concat_ws('|',
    value #>> '{summary,date_count}',
    value #>> '{summary,future_day_count}',
    value #>> '{summary,scheduled_day_count}',
    value #>> '{summary,missing_day_count}'
  ) from t06_east_response),
  '1|0|1|1',
  'Kiritimati treats its calendar-local current date as required'
);
select is(
  (select concat_ws('|',
    value #>> '{summary,date_count}',
    value #>> '{summary,future_day_count}',
    value #>> '{summary,scheduled_day_count}',
    value #>> '{summary,missing_day_count}',
    value #>> '{summary,regular_minutes}',
    value #>> '{summary,overtime_minutes}',
    value #>> '{summary,allocation_minutes}'
  ) from t06_west_response),
  '1|1|0|0|0|0|0',
  'Honolulu excludes its future day and retained evidence from all authoritative totals'
);
select is(
  (
    public.v1_get_workforce_monthly_worker_detail(
      (select (value #>> '{period,period_id}')::uuid from t06_west_response),
      (select (value #>> '{period,current_validation_run_id}')::uuid
       from t06_west_response),
      '596c3000-0000-4000-8000-000000000002'
    ) #>> '{days,0,is_future}'
  ) || '|' || (
    public.v1_get_workforce_monthly_worker_detail(
      (select (value #>> '{period,period_id}')::uuid from t06_west_response),
      (select (value #>> '{period,current_validation_run_id}')::uuid
       from t06_west_response),
      '596c3000-0000-4000-8000-000000000002'
    ) #>> '{days,0,attendance,regular_minutes}'
  ) || '|' || (
    public.v1_get_workforce_monthly_worker_detail(
      (select (value #>> '{period,period_id}')::uuid from t06_west_response),
      (select (value #>> '{period,current_validation_run_id}')::uuid
       from t06_west_response),
      '596c3000-0000-4000-8000-000000000002'
    ) #>> '{days,0,allocation,total_regular_minutes}'
  ),
  'true|480|480',
  'Legacy future attendance/allocation evidence remains readable in day detail'
);
reset role;

-- Active allocation targets are an additional validation boundary. The
-- monthly read remains complete for the worker/date assignment, but target
-- identities are redacted and can_validate is false until the exact target
-- capability and responsibility are also present.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59640000-0000-4000-8000-000000000001","work_date":"2026-08-01","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"T06 target authority fixture"}'::jsonb,
    null,'596d0000-0000-4000-8000-000000000001'
  )$sql$,
  'Admin creates target-authority attendance evidence'
);
reset role;
create temporary table t06_target_attendance(day_id uuid not null)
  on commit drop;
insert into t06_target_attendance(day_id)
select id from public.v1_workforce_attendance_days
where worker_id = '59640000-0000-4000-8000-000000000001'
  and work_date = '2026-08-01';
grant select on pg_temp.t06_target_attendance to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from t06_target_attendance),
      'attendance_record_version',1,
      'reason','T06 active outside target',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work',
        'project_id','596c0000-0000-4000-8000-000000000002',
        'project_scope_id','596c1000-0000-4000-8000-000000000002',
        'activity_task','Outside project target',
        'regular_minutes',480,'overtime_minutes',0
      ))
    ),null,'596d0000-0000-4000-8000-000000000002'
  )$sql$,
  'Admin creates an active allocation target outside the worker project'
);
create temporary table t06_active_target_response(value jsonb) on commit drop;
insert into t06_active_target_response(value)
select public.v1_validate_workforce_monthly_period(
  '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
  3,'596d0000-0000-4000-8000-000000000003'
);
reset role;
grant select on pg_temp.t06_active_target_response to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '596c2000-0000-4000-8000-000000000002',
    (select period_month from t06_calendar_boundary),
    null,null,null,50,0
  )$$,
  '42501','V1_WORKFORCE_MONTHLY_READ_DENIED',
  'A wrong-team and wrong-project caller cannot read another complete month'
);
select is(
  (public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001','2026-08-01',
    null,null,null,50,0
  ) #>> '{capabilities,can_validate}')::boolean,
  false,
  'An uncovered active allocation target removes monthly validation authority'
);
select is(
  (
    with detail as (
      select public.v1_get_workforce_monthly_worker_detail(
        (select (value #>> '{period,period_id}')::uuid
         from t06_active_target_response),
        (select (value #>> '{period,current_validation_run_id}')::uuid
         from t06_active_target_response),
        '59640000-0000-4000-8000-000000000001'
      ) as value
    )
    select concat_ws('|',
      value #>> '{days,0,allocation,targets_restricted}',
      coalesce(value #>> '{days,0,allocation,allocation_set_id}','NULL'),
      value #>> '{days,0,allocation,total_regular_minutes}',
      coalesce(jsonb_typeof(value #> '{days,0,allocation,targets}'),'NULL')
    ) from detail
  ),
  'true|NULL|480|null',
  'Worker detail redacts every active allocation identifier and target'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    4,'596d0000-0000-4000-8000-000000000004'
  )$$,
  '42501','V1_WORKFORCE_MONTHLY_VALIDATE_DENIED',
  'An uncovered active allocation target fails validation closed'
);
reset role;

insert into public.v1_permission_assignment_projects (
  assignment_id, project_id
) values
  ('596a0000-0000-4000-8000-000000000003',
   '596c0000-0000-4000-8000-000000000002'),
  ('596a0000-0000-4000-8000-000000000004',
   '596c0000-0000-4000-8000-000000000002');
insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, project_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '596b0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001','project',
  '596c0000-0000-4000-8000-000000000002',
  '2026-01-01','2027-12-31','T06 active target responsibility',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    4,'596d0000-0000-4000-8000-000000000005'
  ) #>> '{period,record_version}',
  '5',
  'Exact worker and active-target authority restores validation'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from t06_target_attendance),
    'T06 void target authority fixture',2,
    '596d0000-0000-4000-8000-000000000006'
  )$sql$,
  'Admin withdraws the active target without rewriting retained history'
);
reset role;
update public.v1_workforce_responsibility_assignments
set valid_to = '2026-07-31', record_version = record_version + 1,
    updated_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    updated_at = clock_timestamp()
where id = '596b0000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    5,'596d0000-0000-4000-8000-000000000007'
  ) #>> '{period,record_version}',
  '6',
  'A withdrawn allocation target no longer gates validation authority'
);
reset role;

-- Source changes never mutate retained runs on read. They surface one
-- deterministic projection issue and keep the stored period recoverable by an
-- explicit expected-version revalidation.
update public.v1_workforce_workers
set full_name = 'T06 Gap Worker Updated', record_version = record_version + 1,
    updated_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    updated_at = clock_timestamp()
where id = '59640000-0000-4000-8000-000000000001';
create temporary table t06_main_period_ids (
  period_id uuid not null,
  validation_run_id uuid not null
) on commit drop;
insert into t06_main_period_ids(period_id, validation_run_id)
select id, current_validation_run_id
from public.v1_workforce_monthly_periods
where team_id = '59630000-0000-4000-8000-000000000001'
  and period_month = '2026-08-01';
grant select on pg_temp.t06_main_period_ids to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  (select concat_ws('|',
    value #>> '{period,is_stale}',
    value #>> '{period,effective_status}',
    value #>> '{period,stored_status}'
  ) from (select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001','2026-08-01',
    null,null,null,50,0
  ) value) projection),
  'true|draft|draft',
  'A source change makes the projection stale without rewriting stored history'
);
select is(
  (public.v1_list_workforce_monthly_issues(
    (select period_id from t06_main_period_ids),
    (select validation_run_id from t06_main_period_ids),
    'blocking','validation_stale',null,500,0
  ) ->> 'total_count')::bigint,
  1::bigint,
  'Stale issue counts have one matching exception-list projection'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    1,'59690000-0000-4000-8000-000000000001'
  )$$,
  '22023','V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Same key with a different expected-version payload fails closed'
);
select is(
  public.v1_validate_workforce_monthly_period(
    '{"team_id":"59630000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    6,'596e0000-0000-4000-8000-000000000001'
  ) #>> '{period,record_version}',
  '7',
  'Explicit revalidation captures the changed source at the expected version'
);

select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001','2026-08-01',
    null,null,null,501,0
  )$$,
  '22023','V1_WORKFORCE_MONTHLY_READ_INVALID',
  'Worker summary pages reject a limit above 500'
);
select throws_ok(
  $$select public.v1_list_workforce_monthly_teams(
    '2026-08-01',null,501,0
  )$$,
  '22023','V1_WORKFORCE_MONTHLY_TEAMS_INVALID',
  'Monthly team selectors reject a limit above 500'
);
select throws_ok(
  $$select public.v1_list_workforce_monthly_issues(
    (select period_id from t06_main_period_ids),
    (select validation_run_id from t06_main_period_ids),
    null,null,null,501,0
  )$$,
  '22023','V1_WORKFORCE_MONTHLY_ISSUES_INVALID',
  'Monthly issue pages reject a limit above 500'
);
select is(
  (select concat_ws('|',
    value #>> '{filters,worker_limit}',
    value #>> '{filters,worker_offset}'
  ) from (select public.v1_get_workforce_monthly_period(
    '59630000-0000-4000-8000-000000000001','2026-08-01',
    null,null,null,500,1
  ) value) projection),
  '500|1',
  'Monthly worker response echoes the exact 500-row page context'
);
reset role;

insert into public.v1_workforce_teams (
  id, team_code, team_name, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '596f0000-0000-4000-8000-000000000001','WF-T06-EXPIRED',
  'T06 Expired Team','2025-01-01','2025-01-31',false,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_monthly_period(
    '596f0000-0000-4000-8000-000000000001','2026-08-01',
    null,null,null,50,0
  )$$,
  '23514','V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE',
  'An absent non-effective team month cannot be read as an authoritative period'
);
select throws_ok(
  $$select public.v1_validate_workforce_monthly_period(
    '{"team_id":"596f0000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',
    null,'596f1000-0000-4000-8000-000000000001'
  )$$,
  '23514','V1_WORKFORCE_MONTHLY_TEAM_NOT_EFFECTIVE',
  'Admin cannot initialize a non-effective team month'
);
reset role;

-- Realistic page/performance fixture: 500 workers across all 31 dates of a
-- past month, producing 15,500 immutable worker-date and issue snapshots.
insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59710000-0000-4000-8000-000000000001','WF-T06-PERF',
  'T06 500 Worker Performance Project','active','project_engineer',
  '10000000-0000-4000-8000-000000000004','admin'
);
insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values (
  '59720000-0000-4000-8000-000000000001',
  '59710000-0000-4000-8000-000000000001',
  'common','common','Common / All Buildings',true,true
);
insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59730000-0000-4000-8000-000000000001','WF-T06-PERF',
  'T06 500 Worker Performance Team',
  '59710000-0000-4000-8000-000000000001',
  '59720000-0000-4000-8000-000000000001',
  '2025-01-01','2025-01-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);
insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
)
select
  md5('t06-performance-worker-' || sequence)::uuid,
  'WF-T06-P-' || lpad(sequence::text, 3, '0'),
  'T06 Performance Worker ' || lpad(sequence::text, 3, '0'),
  'Technician','Yorks AC & Ref.','yorks_employee','2020-01-01','active',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1,500) sequence;
insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
)
select
  md5('t06-performance-assignment-' || sequence)::uuid,
  md5('t06-performance-worker-' || sequence)::uuid,
  'primary','59730000-0000-4000-8000-000000000001'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '59710000-0000-4000-8000-000000000001'::uuid,
  '59720000-0000-4000-8000-000000000001'::uuid,
  '2025-01-01','2025-01-31','T06 performance assignment',
  '10000000-0000-4000-8000-000000000004'::uuid,'admin',
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1,500) sequence;
insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59740000-0000-4000-8000-000000000001','WF-T06-PERF',
  'T06 Performance Calendar','Asia/Dubai',480,60,
  '2025-01-01','2025-01-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);
insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select '59740000-0000-4000-8000-000000000001'::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1,7) weekday;
insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59750000-0000-4000-8000-000000000001',
  '59730000-0000-4000-8000-000000000001',
  '59740000-0000-4000-8000-000000000001',
  '2025-01-01','2025-01-31','T06 performance schedule',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

create temporary table t06_performance_result (
  value jsonb not null,
  elapsed_ms numeric not null
) on commit drop;
grant select, insert on pg_temp.t06_performance_result to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
insert into t06_performance_result(value, elapsed_ms)
with started as materialized (
  select clock_timestamp() as started_at
), validated as materialized (
  select public.v1_validate_workforce_monthly_period(
    '{"team_id":"59730000-0000-4000-8000-000000000001","period_month":"2025-01-01"}',
    null,'59760000-0000-4000-8000-000000000001'
  ) as value, started_at
  from started
)
select value,
  extract(epoch from (clock_timestamp() - started_at)) * 1000
from validated;

select is(
  (select concat_ws('|',
    value #>> '{summary,worker_count}',
    value #>> '{summary,date_count}',
    value #>> '{summary,scheduled_day_count}',
    value #>> '{summary,missing_day_count}',
    value ->> 'total_count'
  ) from t06_performance_result),
  '500|15500|15500|15500|500',
  '500 workers produce exactly 15,500 server-derived date snapshots'
);
select ok(
  (select elapsed_ms < 60000 from t06_performance_result),
  '500-worker validation completes within the recorded local 60-second budget'
);
select diag(
  'T06 500-worker local validation elapsed_ms=' ||
  (select round(elapsed_ms,2) from t06_performance_result)
);
select is(
  (
    with projection as (
      select public.v1_get_workforce_monthly_period(
        '59730000-0000-4000-8000-000000000001','2025-01-01',
        null,null,null,500,0
      ) as value
    )
    select concat_ws('|',
      value #>> '{filters,worker_limit}',
      value #>> '{filters,worker_offset}',
      value ->> 'total_count',
      jsonb_array_length(value -> 'workers')
    ) from projection
  ),
  '500|0|500|500',
  'The accepted 500-row maximum returns all paged workers with exact echoes'
);
reset role;

select * from finish();
rollback;
