begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select is(
  (select count(*)
   from public.v1_capability_catalog catalog
   where catalog.capability_key in (
     'workforce.workers.manage',
     'workforce.teams.manage',
     'workforce.configuration.manage'
   )
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable),
  3::bigint,
  'All three reviewed Workforce Administration capabilities are enforced and assignable'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_administration_options(date)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_transfer_workforce_worker_assignment(jsonb,uuid,bigint,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_assert_management(text)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_workforce_administration_options(date)',
    'execute'
  ),
  'Only the reviewed public administration RPCs are client-callable'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_workforce_workers', 'insert'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_workforce_workers', 'update'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_workforce_workers', 'delete'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_workforce_worker_assignments', 'delete'
  ),
  'Administration does not expose ordinary table mutation or destructive history access'
);

-- The test grants each non-Admin one bounded capability plus its required
-- Workforce view dependency. These rows model the audited permission command
-- result without changing built-in role defaults.
insert into public.v1_permission_assignments(
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '5af10000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'workforce.view', 'grant', 'organization', 'permission_management',
    '2026-08-01', 'Administration worker-manager test dependency',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '5af10000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'workforce.workers.manage', 'grant', 'organization',
    'permission_management', '2026-08-01',
    'Administration worker-manager test',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '5af10000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002',
    'workforce.view', 'grant', 'organization', 'permission_management',
    '2026-08-01', 'Administration team-manager test dependency',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '5af10000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002',
    'workforce.teams.manage', 'grant', 'organization',
    'permission_management', '2026-08-01',
    'Administration team-manager test',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '5af10000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000003',
    'workforce.view', 'grant', 'organization', 'permission_management',
    '2026-08-01', 'Administration configuration-manager dependency',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '5af10000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000003',
    'workforce.configuration.manage', 'grant', 'organization',
    'permission_management', '2026-08-01',
    'Administration configuration-manager test',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_get_workforce_administration_options('2026-08-31')$$,
  'Exact Admin can load the protected administration choices'
);
select ok(
  public.v1_get_workforce_administration_options('2026-08-31')::text
    !~* 'email|commercial|unit_cost|total_cost',
  'Administration choices contain no email or restricted commercial field'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_save_workforce_worker(
    '{
      "worker_id":"5af20000-0000-4000-8000-000000000001",
      "worker_number":"WF-ADMIN-001",
      "full_name":"Administration Test Worker",
      "designation":"Technician",
      "employer_company":"Yorks AC & Ref.",
      "worker_type":"yorks_employee",
      "joining_date":"2026-01-01",
      "current_status":"active"
    }'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000001'
  )$$,
  'A delegated worker manager can create a worker without Auth-user creation'
);
select throws_ok(
  $$select public.v1_save_workforce_team(
    '{"team_code":"DENIED","team_name":"Denied team","valid_from":"2026-01-01","is_active":true}'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000002'
  )$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'A worker manager does not inherit team management'
);
select lives_ok(
  $$select public.v1_save_workforce_worker_assignment(
    '{
      "assignment_id":"5af40000-0000-4000-8000-000000000001",
      "worker_id":"5af20000-0000-4000-8000-000000000001",
      "assignment_kind":"primary",
      "supervisor_auth_user_id":"10000000-0000-4000-8000-000000000001",
      "valid_from":"2026-01-01",
      "reason":"Initial supervised assignment"
    }'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000003'
  )$$,
  'A worker manager can create the initial dated assignment'
);
select lives_ok(
  $$select public.v1_transfer_workforce_worker_assignment(
    '{
      "worker_id":"5af20000-0000-4000-8000-000000000001",
      "assignment_kind":"primary",
      "supervisor_auth_user_id":"10000000-0000-4000-8000-000000000002",
      "valid_from":"2026-09-01",
      "reason":"Supervisor changed with history retained"
    }'::jsonb,
    '5af40000-0000-4000-8000-000000000001',
    1,
    '5af30000-0000-4000-8000-000000000004'
  )$$,
  'Assignment transfer atomically closes the current period and creates the next'
);
select is(
  (public.v1_transfer_workforce_worker_assignment(
    '{
      "worker_id":"5af20000-0000-4000-8000-000000000001",
      "assignment_kind":"primary",
      "supervisor_auth_user_id":"10000000-0000-4000-8000-000000000002",
      "valid_from":"2026-09-01",
      "reason":"Supervisor changed with history retained"
    }'::jsonb,
    '5af40000-0000-4000-8000-000000000001',
    1,
    '5af30000-0000-4000-8000-000000000004'
  ) ->> 'record_version')::integer,
  1,
  'An exact transfer retry returns the completed result without another period'
);
reset role;

select is(
  (select valid_to::text
   from public.v1_workforce_worker_assignments
   where id = '5af40000-0000-4000-8000-000000000001'),
  '2026-08-31',
  'The superseded assignment is retained and closes the day before transfer'
);
select is(
  (select count(*)::integer
   from public.v1_workforce_worker_assignments
   where worker_id = '5af20000-0000-4000-8000-000000000001'
     and assignment_kind = 'primary'),
  2,
  'The idempotent transfer leaves exactly two historical primary periods'
);

create temporary table workforce_administration_current_assignment as
select id, record_version
from public.v1_workforce_worker_assignments
where worker_id = '5af20000-0000-4000-8000-000000000001'
  and valid_from = '2026-09-01';
grant select on workforce_administration_current_assignment to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_transfer_workforce_worker_assignment(
    jsonb_build_object(
      'worker_id', '5af20000-0000-4000-8000-000000000001',
      'assignment_kind', 'primary',
      'supervisor_auth_user_id', 'ffffffff-ffff-4fff-8fff-ffffffffffff',
      'valid_from', '2026-10-01',
      'reason', 'Invalid inactive supervisor must roll back'
    ),
    (select id from workforce_administration_current_assignment),
    (select record_version from workforce_administration_current_assignment),
    '5af30000-0000-4000-8000-000000000009'
  )$$,
  '23514', 'V1_WORKFORCE_ACTIVE_SUPERVISOR_REQUIRED',
  'Assignment transfer repeats protected target validation and rolls back atomically'
);
reset role;
select is(
  (select valid_to::text
   from public.v1_workforce_worker_assignments
   where worker_id = '5af20000-0000-4000-8000-000000000001'
     and valid_from = '2026-09-01'),
  null,
  'A failed transfer leaves the current assignment open and unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_save_workforce_team(
    '{
      "team_id":"5af50000-0000-4000-8000-000000000001",
      "team_code":"WF-ADMIN-TEAM",
      "team_name":"Administration Test Team",
      "valid_from":"2026-01-01",
      "is_active":true
    }'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000005'
  )$$,
  'A delegated team manager can create a dated team'
);
select throws_ok(
  $$select public.v1_save_workforce_worker(
    '{"worker_number":"DENIED","full_name":"Denied","designation":"Denied","employer_company":"Denied","worker_type":"yorks_employee","joining_date":"2026-01-01","current_status":"active"}'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000006'
  )$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'A team manager does not inherit worker-master management'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_save_workforce_trade(
    '{"trade_id":"5af60000-0000-4000-8000-000000000001","trade_code":"WFADM","trade_name":"Administration Trade","is_active":true}'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000007'
  )$$,
  'A delegated configuration manager can create protected setup data'
);
select is(
  jsonb_array_length(
    public.v1_get_workforce_foundation(null,null,50,0,'2026-08-31')
      -> 'workers'
  ),
  0,
  'A configuration-only manager receives no worker master records'
);
select is(
  jsonb_array_length(
    public.v1_get_workforce_administration_options('2026-08-31')
      -> 'users'
  ),
  0,
  'A configuration-only manager receives no login-user choices'
);
select throws_ok(
  $$select public.v1_save_workforce_team(
    '{"team_code":"DENIED-CFG","team_name":"Denied team","valid_from":"2026-01-01","is_active":true}'::jsonb,
    null,
    '5af30000-0000-4000-8000-000000000008'
  )$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'A configuration manager does not inherit team management'
);
reset role;

select * from finish();
rollback;
