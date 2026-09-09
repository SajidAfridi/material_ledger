begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_material_request_history(uuid,timestamptz,uuid,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_material_request_history(uuid,timestamptz,uuid,integer)',
    'execute'
  ),
  'Request history is an authenticated protected read surface'
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
      "project_ref":"MR-HISTORY-001",
      "name":"Request history proof",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"History fixture requester"
      }],
      "buildings":[{"code":"hist","name":"History Building"}],
      "attachments":[]
    }'::jsonb,
    'e1000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the request history fixture project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-HISTORY-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for request history testing'
    ),
    'e1000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The request history fixture project is active'
);

set local role postgres;
create temporary table v1_history_targets as
select project.id as project_id,
  (select scope.id from public.v1_project_scopes scope
   where scope.project_id = project.id and scope.scope_kind = 'building'
   limit 1) as scope_id
from public.v1_projects project
where project.project_ref = 'MR-HISTORY-001';
grant select on table v1_history_targets to authenticated;

insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code, submitted_at, created_at, updated_at
) values
(
  'e1100000-0000-4000-8000-000000000001',
  (select project_id from v1_history_targets),
  (select scope_id from v1_history_targets),
  'MR-HISTORY-001-MR001', 'History-visible request', 'normal',
  'awaiting_request_approval', 2,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'project_engineer',
  'request_approval_required', clock_timestamp() - interval '2 hours',
  clock_timestamp() - interval '1 day', clock_timestamp() - interval '2 hours'
),
(
  'e1100000-0000-4000-8000-000000000002',
  (select project_id from v1_history_targets),
  (select scope_id from v1_history_targets),
  'MR-HISTORY-001-MR002', 'Unrelated request', 'normal', 'submitted', 1,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'procurement', 'arrangement_required',
  clock_timestamp() - interval '1 hour', clock_timestamp() - interval '1 day',
  clock_timestamp() - interval '1 hour'
);

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values
(
  'e1110000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000001', 1, 'custom',
  'History duct', 2, 'Nos'
),
(
  'e1110000-0000-4000-8000-000000000002',
  'e1100000-0000-4000-8000-000000000002', 1, 'custom',
  'Private unrelated duct', 1, 'Nos'
);

insert into public.v1_audit_events (
  id, event_type, entity_type, entity_id, project_id,
  actor_auth_user_id, actor_role, actor_exact_role, occurred_at,
  after_data, reason
) values
(
  'e1200000-0000-4000-8000-000000000001',
  'material_request_submitted', 'material_request',
  'e1100000-0000-4000-8000-000000000001',
  (select project_id from v1_history_targets),
  '10000000-0000-4000-8000-000000000002', 'site_engineer', 'site_engineer',
  clock_timestamp() - interval '50 minutes',
  '{"state":"awaiting_request_approval","record_version":"2","supplier_cost":"999.00"}'::jsonb,
  null
),
(
  'e1200000-0000-4000-8000-000000000002',
  'procurement_item_clarified', 'material_request_line',
  'e1110000-0000-4000-8000-000000000001',
  (select project_id from v1_history_targets),
  '10000000-0000-4000-8000-000000000003', 'procurement', 'procurement',
  clock_timestamp() - interval '40 minutes',
  '{"request_state":"awaiting_request_approval","model_reference":"HX-20"}'::jsonb,
  'Clarification returned to Engineering. Supplier price AED 12345.'
),
(
  'e1200000-0000-4000-8000-000000000003',
  'procurement_item_clarified', 'material_request_line',
  'e1110000-0000-4000-8000-000000000002',
  (select project_id from v1_history_targets),
  '10000000-0000-4000-8000-000000000003', 'procurement', 'procurement',
  clock_timestamp() - interval '30 minutes',
  '{"supplier_cost":"12345.00","model_reference":"DO-NOT-LEAK"}'::jsonb,
  'Unrelated request activity'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  jsonb_array_length(public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  ) -> 'items'),
  3,
  'Request history includes its durable creation event and only verified related events'
);

select ok(
  public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text like '%Local Procurement%'
  and public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text like '%MR-HISTORY-001-MR001%',
  'History preserves retained actor attribution and the request reference'
);

select ok(
  public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text not like '%999.00%'
  and public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text not like '%DO-NOT-LEAK%'
  and public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text not like '%12345.00%',
  'History redacts raw commercial facts and unrelated request activity'
);

select ok(
  not ((public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  ) -> 'items' -> 0) ? 'actor_auth_user_id')
  and not ((public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  ) -> 'items' -> 0) ? 'before_data')
  and not ((public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  ) -> 'items' -> 0) ? 'after_data')
  and not ((public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  ) -> 'items' -> 0) ? 'reason'),
  'History returns human-readable attribution without raw audit payloads or free text'
);

select ok(
  public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )::text not like '%HX-20%',
  'History allowlists only workflow facts and does not expose line detail or free text'
);

select ok(
  (public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001', null, null, 1
  ) ->> 'has_more')::boolean
  and public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001', null, null, 1
  ) ? 'next_before_occurred_at'
  and public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001', null, null, 1
  ) ? 'next_before_id',
  'History returns a stable cursor when additional events exist'
);

select is(
  jsonb_array_length(public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001',
    (public.v1_get_material_request_history(
      'e1100000-0000-4000-8000-000000000001', null, null, 1
    ) ->> 'next_before_occurred_at')::timestamptz,
    (public.v1_get_material_request_history(
      'e1100000-0000-4000-8000-000000000001', null, null, 1
    ) ->> 'next_before_id')::uuid,
    20
  ) -> 'items'),
  2,
  'The next cursor page returns the remaining events without duplication'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_HISTORY_NOT_READABLE',
  'Procurement cannot inspect an ordinary pre-approval request history'
);

select throws_ok(
  $$select public.v1_get_material_request_history(
    'e1100000-0000-4000-8000-000000000001', now(), null, 5
  )$$,
  '22023', 'V1_MATERIAL_REQUEST_HISTORY_INPUT_INVALID',
  'A partial cursor is rejected rather than interpreted ambiguously'
);

select * from finish();
rollback;
