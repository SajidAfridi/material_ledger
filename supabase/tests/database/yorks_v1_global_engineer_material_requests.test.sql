begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"R40-MR-001",
      "name":"Global engineer material request project",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"r40","name":"R40 Building"}],
      "attachments":[]
    }'::jsonb,
    'a8000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A Project Engineer creates the active-project fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects where project_ref = 'R40-MR-001'
      ),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for global engineering material requests'
    ),
    'a8000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The material-request fixture project is activated'
);

set local role postgres;
create temporary table v1_r40_targets as
select
  project.id as project_id,
  (
    select scope.id
    from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1
  ) as scope_id
from public.v1_projects project
where project.project_ref = 'R40-MR-001';
grant select on table v1_r40_targets to authenticated;

create temporary table v1_r40_payloads as
select
  jsonb_build_object(
    'request_id', 'a8100000-0000-4000-8000-000000000001',
    'expected_version', 0,
    'project_id', project_id,
    'scope_id', scope_id,
    'title', 'Senior multi-line request',
    'timing', 'normal',
    'scheduled_date', null,
    'delivery_note', null,
    'lines', (
      select jsonb_agg(
        jsonb_build_object(
          'id', format(
            'a8110000-0000-4000-8000-%s', lpad(line_number::text, 12, '0')
          ),
          'display_order', line_number,
          'source_kind', 'custom',
          'source_boq_group_id', null,
          'source_boq_row_id', null,
          'item_description', format('damper line %s', line_number),
          'brand_origin', 'UAE',
          'technical_attributes', '{}'::jsonb,
          'requested_qty', '1',
          'unit', 'Nos'
        )
        order by line_number
      )
      from generate_series(1, 5) as line_number
    )
  ) as senior_payload,
  jsonb_build_object(
    'request_id', 'a8100000-0000-4000-8000-000000000002',
    'expected_version', 0,
    'project_id', project_id,
    'scope_id', scope_id,
    'title', 'Project manager request',
    'timing', 'normal',
    'scheduled_date', null,
    'delivery_note', null,
    'lines', jsonb_build_array(jsonb_build_object(
      'id', 'a8110000-0000-4000-8000-000000000006',
      'display_order', 1,
      'source_kind', 'custom',
      'source_boq_group_id', null,
      'source_boq_row_id', null,
      'item_description', 'fire rated sealant',
      'brand_origin', 'UAE',
      'technical_attributes', '{}'::jsonb,
      'requested_qty', '1',
      'unit', 'Box'
    ))
  ) as manager_payload
from v1_r40_targets;
grant select on table v1_r40_payloads to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_and_submit_material_request(
    (select senior_payload from v1_r40_payloads),
    'a8200000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Senior Mechanical Engineer submits five custom Material Request lines without a project membership row'
);

set local role postgres;
select ok(
  (
    select request.state = 'submitted'
      and request.requester_project_role = 'project_engineer'
      and request.requester_exact_role = 'senior_mechanical_engineer'
      and request.current_action_owner_role = 'procurement'
    from public.v1_material_requests request
    where request.id = 'a8100000-0000-4000-8000-000000000001'::uuid
  )
  and (
    select count(*) = 5
    from public.v1_material_request_lines line_record
    where line_record.request_id = 'a8100000-0000-4000-8000-000000000001'::uuid
  ),
  'The atomic command has no four-line limit and preserves Project Engineer workflow authority'
);

select is(
  (
    select public.v1_material_request_document_projection(
      'a8100000-0000-4000-8000-000000000001'::uuid
    ) -> 'request' ->> 'requester_exact_role'
  ),
  'senior_mechanical_engineer',
  'The controlled document projection preserves the Senior Mechanical Engineer exact role'
);

select is(
  (
    select item_description
    from public.v1_material_request_lines
    where request_id = 'a8100000-0000-4000-8000-000000000001'::uuid
      and display_order = 1
  ),
  'Damper line 1',
  'New Material Request lines normalize only their first description character'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);

select lives_ok(
  $$select public.v1_save_and_submit_material_request(
    (select manager_payload from v1_r40_payloads),
    'a8200000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Project Manager submits a Material Request without a project membership row'
);

set local role postgres;
select ok(
  (
    select request.state = 'submitted'
      and request.requester_project_role = 'project_engineer'
      and request.requester_exact_role = 'project_manager'
    from public.v1_material_requests request
    where request.id = 'a8100000-0000-4000-8000-000000000002'::uuid
  )
  and (
    select item_description = 'Fire rated sealant'
    from public.v1_material_request_lines
    where id = 'a8110000-0000-4000-8000-000000000006'::uuid
  ),
  'Project Manager submission keeps normalized workflow authority and its exact document role'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_save_and_submit_material_request(
    (select manager_payload from v1_r40_payloads)
      || jsonb_build_object('request_id', 'a8100000-0000-4000-8000-000000000003'),
    'a8200000-0000-4000-8000-000000000003'::uuid
  )$$,
  '42501',
  'V1_MATERIAL_REQUEST_DRAFT_DENIED',
  'An unassigned Site Engineer remains unable to create a Material Request'
);

select * from finish();
rollback;
