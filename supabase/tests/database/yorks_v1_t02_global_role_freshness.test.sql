begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

select ok(
  public.v1_is_valid_role('project_engineer')
  and public.v1_is_valid_role('site_engineer')
  and public.v1_is_valid_role('senior_mechanical_engineer')
  and public.v1_is_valid_role('project_manager')
  and public.v1_is_valid_role('workshop_in_charge')
  and public.v1_is_valid_role('document_controller')
  and public.v1_is_valid_role('procurement')
  and public.v1_is_valid_role('admin'),
  'Exactly the eight approved Auth roles are valid'
);

select ok(
  not public.v1_is_valid_role('engineer')
  and not public.v1_is_valid_role('administrator')
  and not public.v1_is_valid_role(''),
  'Legacy, guessed and missing roles remain invalid'
);

select ok(
  not has_function_privilege(
    'authenticated', 'public.v1_current_role()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.v1_current_exact_role()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_has_active_project_membership(uuid,uuid,text)',
    'execute'
  ),
  'Internal role and membership helpers are not Data API endpoints'
);

select is(
  (
    select count(distinct auth_user.raw_app_meta_data ->> 'role')::integer
    from auth.users auth_user
    where auth_user.id in (
      '10000000-0000-4000-8000-000000000001'::uuid,
      '10000000-0000-4000-8000-000000000002'::uuid,
      '10000000-0000-4000-8000-000000000003'::uuid,
      '10000000-0000-4000-8000-000000000004'::uuid,
      '10000000-0000-4000-8000-000000000009'::uuid,
      '10000000-0000-4000-8000-000000000010'::uuid
    )
  ),
  6,
  'The deterministic local seed contains one account for each approved role'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"T02-ROLE-001",
      "name":"T02 global role freshness project",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"t02","name":"T02 Building"}],
      "attachments":[]
    }'::jsonb,
    '92000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the isolated T02 project'
);

set local role postgres;
create temporary table v1_t02_targets as
select id as project_id, record_version
from public.v1_projects
where project_ref = 'T02-ROLE-001';
grant select on table v1_t02_targets to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);

select ok(
  public.v1_project_readable((select project_id from v1_t02_targets)),
  'Senior Mechanical Engineer can read an unassigned project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select project_id from v1_t02_targets),
      'state', 'active',
      'expected_version', (select record_version from v1_t02_targets),
      'reason', 'Global Project Engineer activation proof'
    ),
    '92000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Senior Mechanical Engineer can activate the unassigned project'
);

set local role postgres;
select ok(
  exists (
    select 1
    from public.v1_audit_events event
    where event.event_type = 'project_state_changed'
      and event.project_id = (select project_id from v1_t02_targets)
      and event.actor_role = 'project_engineer'
      and event.actor_exact_role = 'senior_mechanical_engineer'
  ),
  'Audit retains the exact global role beside normalized workflow authority'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select is(
  public.v1_get_current_commercial_capabilities()
    #>> '{capabilities,view_commercials,effective}',
  'false',
  'Senior Mechanical Engineer has no commercial capability by default'
);

select lives_ok(
  $$select public.v1_get_user_commercial_capabilities(
    '10000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Senior Mechanical Engineer can inspect a safe user capability envelope'
);

select lives_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000001",
      "capability":"view_commercials",
      "is_granted":true,
      "reason":"Senior user-configuration authorization proof"
    }'::jsonb,
    '92000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Senior Mechanical Engineer can configure an allowed user capability'
);

set local role postgres;
update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000009',
           'action', 'password_reset',
           'idempotency_key', '92000000-0000-4000-8000-000000000004',
           'request_hash',
             'abababababababababababababababababababababababababababababababab'
         )
       )
 where id = '10000000-0000-4000-8000-000000000010'::uuid;
select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.entity_id = '10000000-0000-4000-8000-000000000010'::uuid
      and audit.actor_auth_user_id =
        '10000000-0000-4000-8000-000000000009'::uuid
      and audit.actor_role = 'project_engineer'
      and audit.actor_exact_role = 'senior_mechanical_engineer'
  ),
  'Senior-authored user changes retain normalized and exact audit attribution'
);

update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"project_engineer"'::jsonb
   )
 where id = '10000000-0000-4000-8000-000000000009'::uuid;

set local role authenticated;
-- The JWT still says Senior Mechanical Engineer.  Its live Auth role is now
-- Project Engineer without a project membership, so the formerly global token
-- must fail closed instead of keeping all-project authority until expiry.
select ok(
  not public.v1_project_readable((select project_id from v1_t02_targets)),
  'A stale global-role JWT loses project access after the protected role changes'
);

select throws_ok(
  $$select public.v1_get_current_commercial_capabilities()$$,
  '42501',
  'V1_ACTIVE_V1_ACTOR_REQUIRED',
  'A stale role JWT cannot obtain a refreshed authorization envelope'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select ok(
  not public.v1_project_readable((select project_id from v1_t02_targets)),
  'A refreshed project-engineer JWT still requires a dated project membership'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select ok(
  public.v1_project_readable((select project_id from v1_t02_targets))
  and (public.v1_get_current_commercial_capabilities()
    #>> '{capabilities,view_commercials,effective}') = 'false',
  'Project Manager has all-project read authority and no commercial access'
);

select throws_ok(
  $$select public.v1_get_user_commercial_capabilities(
    '10000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_ACTIVE_ADMIN_REQUIRED',
  'Project Manager cannot inspect another user capability envelope'
);

select * from finish();
rollback;
