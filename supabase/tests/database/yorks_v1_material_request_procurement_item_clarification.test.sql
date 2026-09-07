begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_update_material_request_procurement_item(jsonb,uuid)',
    'execute'
  ) and not has_function_privilege(
    'anon',
    'public.v1_update_material_request_procurement_item(jsonb,uuid)',
    'execute'
  ),
  'clarification is exposed only as an authenticated trusted command'
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
      "project_ref":"MR-CLARIFY-001",
      "name":"Procurement Clarification Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Request creator"
      }],
      "buildings":[{"code":"main","name":"Main Building"}],
      "attachments":[]
    }'::jsonb,
    '90700000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the clarification test project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-CLARIFY-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for Material Requests'
    ),
    '90700000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Project is activated through the trusted command'
);

set local role postgres;
create temporary table v1_clarification_target as
select project.id as project_id,
  (select id from public.v1_project_scopes
    where project_id = project.id and scope_kind = 'building' limit 1) as scope_id
from public.v1_projects project
where project.project_ref = 'MR-CLARIFY-001';
grant select on table v1_clarification_target to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(jsonb_build_object(
    'request_id', '90710000-0000-4000-8000-000000000001',
    'expected_version', 0,
    'project_id', (select project_id from v1_clarification_target),
    'scope_id', (select scope_id from v1_clarification_target),
    'title', 'Ambiguous fan request', 'timing', 'normal',
    'scheduled_date', null, 'delivery_note', null,
    'lines', jsonb_build_array(jsonb_build_object(
      'id', '90720000-0000-4000-8000-000000000001',
      'display_order', 1, 'source_kind', 'custom',
      'source_boq_group_id', null, 'source_boq_row_id', null,
      'item_description', 'Exhaust fan', 'brand_origin', null,
      'technical_attributes', jsonb_build_object('size', '12 inch'),
      'requested_qty', '3', 'unit', 'Nos'
    ))
  ))$$,
  'Site Engineer saves the original ambiguous request'
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'expected_version', 1
    ), '90730000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Site Engineer submits the request'
);

set local role postgres;
update public.v1_material_requests
set state = 'submitted', current_action_owner_role = 'procurement',
    current_action_code = 'arrangement_required'
where id = '90710000-0000-4000-8000-000000000001'::uuid;

select is(
  (select requested_item_description
   from public.v1_material_request_lines
   where id = '90720000-0000-4000-8000-000000000001'::uuid),
  'Exhaust fan',
  'the submitted request has an immutable original-description snapshot'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'expected_version', 2
    ), '90730000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Procurement begins the arrangement before clarifying the item'
);

set local role postgres;
create temporary table v1_clarification_arrangement as
select arrangement.id as arrangement_id, arrangement_line.id as arrangement_line_id
from public.v1_procurement_arrangements arrangement
join public.v1_procurement_arrangement_lines arrangement_line
  on arrangement_line.arrangement_id = arrangement.id
where arrangement.request_id =
    '90710000-0000-4000-8000-000000000001'::uuid
  and arrangement.status = 'working';
grant select on table v1_clarification_arrangement to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 3,
      'item_description', 'Unauthorized edit',
      'model_reference', 'BAD-1'
    ), '90730000-0000-4000-8000-000000000003'::uuid
  )$$,
  '42501', 'V1_PROCUREMENT_ITEM_CLARIFICATION_DENIED',
  'Site Engineering cannot use the Procurement clarification command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 2,
      'item_description', 'Exhaust fan EF-300',
      'model_reference', 'EF-300'
    ), '90730000-0000-4000-8000-000000000004'::uuid
  )$$,
  '40001', 'V1_MATERIAL_REQUEST_VERSION_CONFLICT',
  'a stale Procurement screen cannot overwrite current item identity'
);

select lives_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 3,
      'item_description', 'Exhaust fan EF-300',
      'model_reference', 'EF-300'
    ), '90730000-0000-4000-8000-000000000005'::uuid
  )$$,
  'Procurement clarifies the effective description and model'
);

set local role postgres;
select ok(
  (select item_description = 'Exhaust fan EF-300'
      and technical_attributes ->> 'model' = 'EF-300'
      and requested_item_description = 'Exhaust fan'
      and requested_technical_attributes ->> 'size' = '12 inch'
      and not (requested_technical_attributes ? 'model')
      and procurement_clarification_version = 1
   from public.v1_material_request_lines
   where id = '90720000-0000-4000-8000-000000000001'::uuid),
  'effective identity changes while all original Engineering evidence remains'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 3,
      'item_description', 'Exhaust fan EF-300',
      'model_reference', 'EF-300'
    ), '90730000-0000-4000-8000-000000000005'::uuid
  )$$,
  'an identical retry returns the first confirmed response'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_audit_events
   where event_type = 'procurement_item_clarified'
     and entity_id = '90720000-0000-4000-8000-000000000001'::uuid),
  1,
  'an identical retry creates no duplicate audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 4,
      'item_description', 'Different payload',
      'model_reference', null
    ), '90730000-0000-4000-8000-000000000005'::uuid
  )$$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'one command key cannot be reused for a different correction'
);

select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id
        from v1_clarification_arrangement),
      'expected_request_version', 4,
      'expected_arrangement_version', 1,
      'procurement_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', (select arrangement_line_id
          from v1_clarification_arrangement),
        'source_kind', 'external_supplier', 'external_supplier', null,
        'inventory_item_id', null, 'decision', 'full', 'arranged_qty', '3',
        'reason', null, 'unit_cost', null,
        'external_source_ready', false,
        'external_expected_date', null, 'external_reference', null
      ))
    ), '90730000-0000-4000-8000-000000000006'::uuid
  )$$,
  'Procurement saves the arrangement after clarification'
);

select throws_ok(
  $$select public.v1_update_material_request_procurement_item(
    jsonb_build_object(
      'request_id', '90710000-0000-4000-8000-000000000001',
      'request_line_id', '90720000-0000-4000-8000-000000000001',
      'expected_request_version', 5,
      'item_description', 'Too late',
      'model_reference', 'LATE-1'
    ), '90730000-0000-4000-8000-000000000007'::uuid
  )$$,
  '22023', 'V1_PROCUREMENT_ITEM_CLARIFICATION_LOCKED',
  'item identity is locked after the arrangement is saved'
);

select throws_ok(
  $$update public.v1_material_request_lines
    set item_description = 'Direct bypass'
    where id = '90720000-0000-4000-8000-000000000001'::uuid$$,
  '42501', null,
  'Procurement cannot bypass the command with a direct line update'
);

set local role postgres;
select throws_ok(
  $$update public.v1_material_request_lines
    set requested_item_description = 'Rewrite history'
    where id = '90720000-0000-4000-8000-000000000001'::uuid$$,
  '42501', 'V1_MATERIAL_REQUEST_REQUESTED_SNAPSHOT_IMMUTABLE',
  'even privileged writes cannot rewrite original requested evidence'
);

select * from finish();
rollback;
