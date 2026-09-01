begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_material_request_actor_has_current_action(uuid)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.v1_material_request_exception_codes(uuid)',
    'execute'
  ),
  'Internal action and exception helpers cannot be called directly by clients'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_list_material_request_summaries(uuid,text,text[],uuid,text,timestamptz,boolean,text,text,integer,integer,text)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_material_request_operations_dashboard(uuid)',
    'execute'
  ),
  'Authenticated clients receive only the protected register and dashboard surfaces'
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
      "project_ref":"MR-ACT-001",
      "name":"MR action intelligence proof",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Site receipt reviewer"
      }],
      "buildings":[{"code":"act","name":"Action Building"}],
      "attachments":[]
    }'::jsonb,
    'a1000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the operational projection fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-ACT-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for action intelligence proof'
    ),
    'a1000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The action intelligence fixture project is active'
);

set local role postgres;
create temporary table v1_action_targets as
select project.id project_id,
  (select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1) scope_id
from public.v1_projects project where project.project_ref = 'MR-ACT-001';
grant select on table v1_action_targets to authenticated;

insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, scheduled_date,
  state, record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code, submitted_at, created_at, updated_at
) values
(
  'a1100000-0000-4000-8000-000000000001',
  (select project_id from v1_action_targets),
  (select scope_id from v1_action_targets),
  'MR-ACT-001-MR001', 'Engineering approval work', 'normal', null,
  'awaiting_request_approval', 2,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'project_engineer',
  'request_approval_required', clock_timestamp() - interval '7 hours',
  clock_timestamp() - interval '1 day', clock_timestamp() - interval '7 hours'
),
(
  'a1100000-0000-4000-8000-000000000002',
  (select project_id from v1_action_targets),
  (select scope_id from v1_action_targets),
  'MR-ACT-001-MR002', 'Procurement arrangement work', 'scheduled',
  current_date - 1,
  'approved_for_arrangement', 3,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'procurement',
  'arrangement_required', clock_timestamp() - interval '2 days',
  clock_timestamp() - interval '3 days', clock_timestamp() - interval '30 hours'
),
(
  'a1100000-0000-4000-8000-000000000003',
  (select project_id from v1_action_targets),
  (select scope_id from v1_action_targets),
  'MR-ACT-001-MR003', 'Arrangement exceptions', 'scheduled',
  current_date - 2,
  'awaiting_approval', 4,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'project_engineer',
  'arrangement_review_required', clock_timestamp() - interval '4 days',
  clock_timestamp() - interval '5 days', clock_timestamp() - interval '51 hours'
);

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values
(
  'a1110000-0000-4000-8000-000000000001',
  'a1100000-0000-4000-8000-000000000003', 1, 'custom',
  'Externally supplied damper', 10, 'Nos'
),
(
  'a1110000-0000-4000-8000-000000000002',
  'a1100000-0000-4000-8000-000000000003', 2, 'custom',
  'Unavailable access panel', 5, 'Nos'
);

insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current, record_version,
  started_by_auth_user_id, started_at, saved_at, saved_by_auth_user_id,
  created_at, updated_at
) values (
  'a1120000-0000-4000-8000-000000000001',
  'a1100000-0000-4000-8000-000000000003', 1, 'awaiting_approval', true, 2,
  '10000000-0000-4000-8000-000000000003',
  clock_timestamp() - interval '3 days',
  clock_timestamp() - interval '2 days',
  '10000000-0000-4000-8000-000000000003',
  clock_timestamp() - interval '3 days', clock_timestamp() - interval '2 days'
);

insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, external_supplier,
  decision, arranged_qty, reason, external_source_ready,
  external_expected_date
) values
(
  'a1130000-0000-4000-8000-000000000001',
  'a1120000-0000-4000-8000-000000000001',
  'a1110000-0000-4000-8000-000000000001',
  'external_supplier', 'Supplier A', 'partial', 6,
  'Four units remain outstanding', false, current_date - 1
),
(
  'a1130000-0000-4000-8000-000000000002',
  'a1120000-0000-4000-8000-000000000001',
  'a1110000-0000-4000-8000-000000000002',
  'warehouse', null, 'unavailable', 0,
  'No warehouse stock', false, null
);

insert into public.v1_material_returns (
  id, request_id, project_id, scope_id, state, note, purpose,
  requested_return_date, record_version, drafted_by_auth_user_id,
  drafted_by_role, drafted_at, created_at, updated_at
) values (
  'a1140000-0000-4000-8000-000000000001',
  'a1100000-0000-4000-8000-000000000003',
  (select project_id from v1_action_targets),
  (select scope_id from v1_action_targets),
  'draft', 'Return unused material', 'Surplus material', current_date - 1, 1,
  '10000000-0000-4000-8000-000000000002', 'site_engineer',
  clock_timestamp() - interval '2 days',
  clock_timestamp() - interval '2 days', clock_timestamp() - interval '2 days'
);

select is(
  public.v1_material_request_exception_codes(
    'a1100000-0000-4000-8000-000000000003'
  ),
  array[
    'unavailable_supply', 'partial_arrangement',
    'late_external_supply', 'overdue_return'
  ]::text[],
  'Exception codes derive unavailable, partial, late external and overdue return facts'
);

select is(
  (public.v1_material_request_line_lifecycle_projection(
    'a1100000-0000-4000-8000-000000000003'
  ) -> 0 ->> 'still_needed_qty')::numeric,
  10::numeric,
  'The line ledger reports still-needed quantity from trusted request facts'
);

select ok(
  (public.v1_material_request_line_lifecycle_projection(
    'a1100000-0000-4000-8000-000000000003'
  ) -> 0) ?& array['reserved_qty', 'returned_qty', 'still_needed_qty'],
  'The lifecycle response includes reserved, returned and still-needed columns'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select is(
  (public.v1_list_material_request_summaries(
    p_register_view => 'my_work'
  ) ->> 'total_count')::integer,
  0,
  'A Site Engineer does not inherit Project Engineer or Procurement work'
);

select is(
  (public.v1_list_material_request_summaries(
    p_register_view => 'exceptions'
  ) ->> 'total_count')::integer,
  1,
  'The Site Engineer can see the exception request in an authorized project'
);

select ok(
  (public.v1_list_material_request_summaries(
    p_register_view => 'exceptions'
  ) -> 'items' -> 0) ?& array[
    'current_action_started_at', 'current_action_age_hours',
    'required_on_site_overdue', 'actor_can_act', 'exception_codes'
  ],
  'Exception cards receive owner-age, overdue and exception facts'
);

select is(
  public.v1_material_request_operations_dashboard() ->> 'action_due_policy',
  'not_configured',
  'The dashboard fails honestly instead of inventing an action due policy'
);

select is(
  (public.v1_material_request_operations_dashboard()
    ->> 'required_date_overdue_count')::integer,
  2,
  'Required-on-site overdue count is derived from scheduled active requests'
);

select ok(
  not (public.v1_material_request_operations_dashboard()
    ?| array['unit_cost', 'total_cost', 'commercials']),
  'The operational dashboard contains no commercial response shape'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (public.v1_list_material_request_summaries(
    p_register_view => 'my_work'
  ) ->> 'total_count')::integer,
  2,
  'Project Engineer My Work contains approval and arrangement review actions'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  (public.v1_list_material_request_summaries(
    p_register_view => 'my_work'
  ) ->> 'total_count')::integer,
  1,
  'Procurement My Work contains the request ready for arrangement'
);

select ok(
  jsonb_typeof(public.v1_material_request_operations_dashboard()) = 'object',
  'Procurement receives the authorized non-commercial operational dashboard'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (public.v1_list_material_request_summaries(
    p_register_view => 'my_work'
  ) ->> 'total_count')::integer,
  3,
  'Admin receives only genuine actionable requests rather than closed history'
);

set local role anon;
select throws_ok(
  $$select public.v1_material_request_operations_dashboard()$$,
  '42501', 'permission denied for function v1_material_request_operations_dashboard',
  'Anonymous dashboard access fails closed'
);

select * from finish();
rollback;
