begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(21);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_project_overview(integer)', 'execute'
  ) and has_function_privilege(
    'authenticated', 'public.v1_material_request_overview(integer)', 'execute'
  ),
  'Authenticated users can call only the protected startup projections'
);

select ok(
  not has_function_privilege(
    'anon', 'public.v1_project_overview(integer)', 'execute'
  ) and not has_function_privilege(
    'anon', 'public.v1_material_request_overview(integer)', 'execute'
  ),
  'Anonymous users cannot execute either startup projection'
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
      "project_ref":"START-OVERVIEW-001",
      "name":"Startup overview proof",
      "parties":{"client":{"name":"Startup Client"}},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Startup projection test"
      }],
      "buildings":[{"code":"start","name":"Startup Building"}],
      "attachments":[]
    }'::jsonb,
    'a1600000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the startup projection fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'START-OVERVIEW-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for startup projection proof'
    ),
    'a1600000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The startup projection fixture project is active'
);

set local role postgres;
insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code, submitted_at, created_at, updated_at
) values (
  'a1610000-0000-4000-8000-000000000001',
  (select id from public.v1_projects
    where project_ref = 'START-OVERVIEW-001'),
  (select id from public.v1_project_scopes
    where project_id = (select id from public.v1_projects
      where project_ref = 'START-OVERVIEW-001')
      and scope_kind = 'building' limit 1),
  'START-OVERVIEW-MR001', 'Bounded startup request', 'normal',
  'awaiting_request_approval', 2,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'project_engineer',
  'request_approval_required', clock_timestamp() - interval '1 hour',
  clock_timestamp() - interval '2 hours', clock_timestamp() - interval '1 hour'
);

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values (
  'a1620000-0000-4000-8000-000000000001',
  'a1610000-0000-4000-8000-000000000001', 1, 'custom',
  'Startup projection item', 2, 'Nos'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_project_overview(1)$$,
  'An active Project Engineer receives the project startup projection'
);

select lives_ok(
  $$select public.v1_material_request_overview(1)$$,
  'An active Project Engineer receives the request startup projection'
);

select is(
  jsonb_array_length(public.v1_project_overview(1) -> 'items'), 1,
  'Project startup rows obey the requested bound'
);

select is(
  jsonb_array_length(public.v1_material_request_overview(1) -> 'items'), 1,
  'Material Request startup rows obey the requested bound'
);

select ok(
  (public.v1_project_overview(1) -> 'counts' ->> 'total')::integer >= 1,
  'Project totals cover the full readable portfolio'
);

select ok(
  (public.v1_material_request_overview(1) -> 'counts' ->> 'total')::integer >= 1,
  'Request totals cover the full readable register'
);

select ok(
  not ((public.v1_project_overview(1) -> 'items' -> 0)
    ?| array['parties', 'buildings', 'active_members']),
  'Project startup cards exclude heavyweight nested collections'
);

select ok(
  not ((public.v1_material_request_overview(1) -> 'items' -> 0)
    ?| array['lines', 'comments', 'unit_cost', 'total_cost']),
  'Request startup rows exclude detail and commercial fields'
);

select is(
  (public.v1_material_request_overview(1)
    -> 'counts' ->> 'approvals')::integer,
  1,
  'The exact request aggregate includes the approval work item'
);

select is(
  (public.v1_project_overview(1)
    -> 'counts' ->> 'active')::integer,
  1,
  'The exact project aggregate includes the active fixture'
);

-- Compare the protected projection with its underlying authority as the test
-- owner; authenticated callers deliberately have no direct table access.
set local role postgres;

select is(
  (public.v1_material_request_overview(6)
    -> 'counts' ->> 'total')::bigint,
  (
    select count(*)
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
      request_record.id, auth.uid()
    )
  ),
  'Set-based Project Engineer readability matches participant authority'
);

select is(
  (public.v1_material_request_overview(6)
    -> 'counts' ->> 'needs_action')::bigint,
  (
    select count(*)
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
      request_record.id, auth.uid()
    ) and public.v1_material_request_actor_has_current_action(
      request_record.id
    )
  ),
  'Set-based Project Engineer action total matches workflow authority'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select is(
  (public.v1_material_request_overview(6)
    -> 'counts' ->> 'total')::bigint,
  (
    select count(*)
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
      request_record.id, auth.uid()
    )
  ),
  'Set-based Site Engineer readability matches participant authority'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  (public.v1_material_request_overview(6)
    -> 'counts' ->> 'total')::bigint,
  (
    select count(*)
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
      request_record.id, auth.uid()
    )
  ),
  'Set-based Procurement readability matches participant authority'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (public.v1_material_request_overview(6)
    -> 'counts' ->> 'total')::bigint,
  (
    select count(*)
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
      request_record.id, auth.uid()
    )
  ),
  'Set-based Admin readability matches participant authority'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000099","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"unknown-user"}}',
  true
);

select throws_ok(
  $$select public.v1_project_overview(6)$$,
  '42501', 'V1_PROJECT_OVERVIEW_DENIED',
  'An unprovisioned identity is denied the project startup projection'
);

select throws_ok(
  $$select public.v1_material_request_overview(6)$$,
  '42501', 'V1_MATERIAL_REQUEST_OVERVIEW_DENIED',
  'An unprovisioned identity is denied the request startup projection'
);

select * from finish();
rollback;
