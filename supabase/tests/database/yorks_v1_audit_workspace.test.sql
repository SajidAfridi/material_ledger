begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

set local role postgres;

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_audit_workspace(text,text,text,timestamptz,timestamptz,integer,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_audit_workspace(text,text,text,timestamptz,timestamptz,integer,integer)',
    'execute'
  ),
  'The trusted Audit Workspace RPC is authenticated-only'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_audit_events', 'select')
  and not has_table_privilege('authenticated', 'public.v1_audit_events', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_audit_events', 'update')
  and not has_table_privilege('authenticated', 'public.v1_audit_events', 'delete'),
  'Clients cannot read or mutate the append-only audit table directly'
);

insert into public.v1_projects (
  id,
  project_ref,
  name,
  state,
  current_action_owner_role,
  created_by_auth_user_id,
  created_by_role
)
values (
  'ad200000-0000-4000-8000-000000000001'::uuid,
  'AUDIT',
  'Audit Fixture Project',
  'active',
  'project_engineer',
  '10000000-0000-4000-8000-000000000004'::uuid,
  'admin'
);

insert into public.v1_audit_events (
  id,
  event_type,
  entity_type,
  entity_id,
  project_id,
  actor_auth_user_id,
  actor_role,
  actor_exact_role,
  occurred_at,
  before_data,
  after_data,
  reason
)
values (
  'ad000000-0000-4000-8000-000000000001'::uuid,
  'material_request_cancelled',
  'material_request',
  'ad100000-0000-4000-8000-000000000001'::uuid,
  'ad200000-0000-4000-8000-000000000001'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid,
  'admin',
  'admin',
  clock_timestamp(),
  jsonb_build_object('unit_cost', '999.00', 'supplier_secret', 'private'),
  jsonb_build_object(
    'state', 'cancelled',
    'request_number', 'AUDIT-MR001',
    'total_cost', '999.00',
    'supplier_secret', 'private'
  ),
  'Beta audit cancellation fixture'
);

select is(
  (
    select project_ref_snapshot
    from public.v1_audit_events
    where entity_id = 'ad100000-0000-4000-8000-000000000001'::uuid
  ),
  'AUDIT',
  'New audit events preserve immutable project identity at insert time'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_audit_workspace()$$,
  '42501',
  'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED',
  'Project Engineer cannot open the organization Audit Workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_audit_workspace()$$,
  '42501',
  'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED',
  'Site Engineer cannot open the organization Audit Workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_get_audit_workspace()$$,
  '42501',
  'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED',
  'Procurement cannot open the organization Audit Workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000005","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_audit_workspace()$$,
  '42501',
  'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED',
  'Senior Mechanical Engineer cannot open the Admin-only Audit Workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000006","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select throws_ok(
  $$select public.v1_get_audit_workspace()$$,
  '42501',
  'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED',
  'Project Manager cannot open the Admin-only Audit Workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_get_audit_workspace()$$,
  'Active exact Admin can open the trusted Audit Workspace'
);

select is(
  public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) ->> 'filtered_count',
  '1',
  'Server-side search finds the immutable reference'
);

select is(
  public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) #>> '{events,0,actor_exact_role}',
  'admin',
  'The exact server-controlled actor role is preserved'
);

select is(
  public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) #>> '{events,0,reference}',
  'AUDIT-MR001',
  'The safe operational reference is projected'
);

select ok(
  (public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) #> '{events,0}') ? 'facts'
  and not ((public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) #> '{events,0}') ? 'before_data')
  and not ((public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  ) #> '{events,0}') ? 'after_data'),
  'The projection exposes allow-listed facts, never raw audit payloads'
);

select ok(
  position('999.00' in public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  )::text) = 0
  and position('supplier_secret' in public.v1_get_audit_workspace(
    'AUDIT-MR001', null, null, null, null, 12, 0
  )::text) = 0,
  'Commercial and supplier values cannot leak through Audit Workspace JSON'
);

select is(
  public.v1_get_audit_workspace(
    null, null, 'critical', null, null, 50, 0
  ) #>> '{events,0,severity}',
  'critical',
  'The critical quick filter is enforced by the trusted projection'
);

select throws_ok(
  $$select public.v1_get_audit_workspace(
    null, 'forged_module', null, null, null, 12, 0
  )$$,
  '22023',
  'V1_AUDIT_WORKSPACE_MODULE_INVALID',
  'Unknown module filters fail closed'
);

select throws_ok(
  $$select public.v1_get_audit_workspace(
    null, null, null, clock_timestamp(), clock_timestamp() - interval '1 day',
    12, 0
  )$$,
  '22023',
  'V1_AUDIT_WORKSPACE_DATE_RANGE_INVALID',
  'Reversed date ranges fail safely'
);

select * from finish();
rollback;
