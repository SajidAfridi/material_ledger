begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(35);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_material_requests'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_lines'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_line_commercials'::regclass),
  'Material request header, lines and commercial rows all enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_material_requests', 'select')
  and not has_table_privilege('authenticated', 'public.v1_material_request_lines', 'insert')
  and not has_table_privilege(
    'authenticated', 'public.v1_material_request_line_commercials', 'select'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_submit_material_request(jsonb,uuid)', 'execute'
  ),
  'MR access is through trusted projections and commands, not tables'
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
      "project_ref":"B5-MR-001",
      "name":"Material Request Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"MR requester"
      }],
      "buildings":[{"code":"b5","name":"MR Building"}],
      "attachments":[]
    }'::jsonb,
    '50000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates an MR project with a Site Engineer member'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B5-MR-001'),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for material requests'
    ),
    '50000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Only an active project can be used for MR submission'
);

set local role postgres;
create temporary table v1_b5_targets as
select
  project.id as project_id,
  (select id from public.v1_project_scopes
    where project_id = project.id and scope_kind = 'building' limit 1) as scope_id,
  (select id from public.v1_boq_groups
    where project_id = project.id
      and scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'building'
        limit 1
      )
      and display_order = 1
    limit 1) as boq_group_id
from public.v1_projects project
where project.project_ref = 'B5-MR-001';

insert into public.v1_boq_rows (
  id, group_id, display_order, raw_values, canonical_values,
  created_by_auth_user_id
) values (
  '51000000-0000-4000-8000-000000000001'::uuid,
  (select boq_group_id from v1_b5_targets), 1,
  '{}'::jsonb,
  '{"description":"Motorized Smoke Damper","brand_origin":"UAE","quantity":"4","unit":"Nos"}'::jsonb,
  '10000000-0000-4000-8000-000000000001'::uuid
);

create temporary table v1_b5_payloads as
select jsonb_build_object(
  'request_id', '52000000-0000-4000-8000-000000000001',
  'expected_version', 0,
  'project_id', project_id,
  'scope_id', scope_id,
  'title', 'Level 1 dampers',
  'timing', 'normal',
  'scheduled_date', null,
  'delivery_note', 'Deliver to the building store',
  'lines', jsonb_build_array(jsonb_build_object(
    'id', '53000000-0000-4000-8000-000000000001',
    'display_order', 1,
    'source_kind', 'boq',
    'source_boq_group_id', boq_group_id,
    'source_boq_row_id', '51000000-0000-4000-8000-000000000001',
    'item_description', 'Motorized Smoke Damper',
    'brand_origin', 'UAE',
    'technical_attributes', jsonb_build_object(
      'size', '600 x 600',
      'model', 'MSD-600',
      'equipment_tag', 'MSD-01A',
      'quantity_suggested', 'true',
      'planning_model_tag', 'MSD-01A'
    ),
    'requested_qty', '4',
    'unit', 'Nos'
  ))
) as first_draft_payload
from v1_b5_targets;
grant select on table v1_b5_targets, v1_b5_payloads to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(
    (select first_draft_payload from v1_b5_payloads)
  )$$,
  'AT-01: assigned Site Engineer saves a creator-owned BOQ-backed draft'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) ->> 'state'),
  'draft',
  'A saved request remains a draft without a Procurement-visible number'
);

select ok(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) ->> 'request_number') is null
  and (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,source_kind}') = 'boq',
  'Draft retains the BOQ source snapshot but has no allocated request number'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,technical_attributes,size}'),
  '600 x 600',
  'Draft preserves non-commercial technical size context'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,technical_attributes,planning_model_tag}'),
  'MSD-01A',
  'Draft preserves the planning model tag separately from receipt serial data'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,technical_attributes,model}'),
  'MSD-600',
  'Draft preserves the BOQ model separately from equipment tag data'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,technical_attributes,equipment_tag}'),
  'MSD-01A',
  'Draft preserves a searchable equipment tag without treating it as serial data'
);

select is(
  (select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,technical_attributes,quantity_suggested}'),
  'true',
  'Draft preserves the explicit review marker for an inferred quantity'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  public.v1_list_material_requests((select project_id from v1_b5_targets)),
  '[]'::jsonb,
  'AT-02: Procurement cannot list a private draft'
);

select throws_ok(
  $$select public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501',
  'V1_MATERIAL_REQUEST_NOT_READABLE',
  'Procurement cannot deep-link to a creator draft'
);

select throws_ok(
  $$select * from public.v1_material_requests$$,
  '42501',
  null,
  'Procurement cannot bypass MR projections through direct table reads'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  jsonb_array_length(
    public.v1_list_material_requests((select project_id from v1_b5_targets))
  ),
  1,
  'A server-backed draft is visible to authorized Engineering/Admin participants'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '52000000-0000-4000-8000-000000000001',
      'expected_version', 1
    ),
    '54000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'AT-03: the assigned Site Engineer submits a saved draft exactly once'
);

set local role postgres;
select is(
  (select request_number from public.v1_material_requests
    where id = '52000000-0000-4000-8000-000000000001'::uuid),
  'B5MR001-MR001',
  'Submit atomically assigns the first project-scoped MR reference'
);

select ok(
  (select state = 'awaiting_request_approval'
      and requester_project_role = 'site_engineer'
      and requester_display_name = 'Local Site Engineer'
      and current_action_owner_role = 'project_engineer'
      and current_action_code = 'request_approval_required'
    from public.v1_material_requests
    where id = '52000000-0000-4000-8000-000000000001'::uuid),
  'Submit snapshots requester identity and routes the next action to Engineering'
);

select is(
  (select count(*) from public.v1_audit_events
    where event_type = 'material_request_submitted'
      and entity_id = '52000000-0000-4000-8000-000000000001'::uuid),
  1::bigint,
  'Submit creates one append-only server audit event'
);

select ok(
  (select count(*) from public.v1_notifications
    where event_code = 'material_request_approval_required'
      and entity_id = '52000000-0000-4000-8000-000000000001'::uuid) >= 1,
  'Submit creates code-only Engineering approval notifications'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '52000000-0000-4000-8000-000000000001',
      'expected_version', 1
    ),
    '54000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A same-key submit retry returns the original confirmed response'
);

set local role postgres;
select ok(
  (select next_request_sequence = 2
     from public.v1_material_request_reference_counters
     where project_id = (select project_id from v1_b5_targets))
  and (select count(*) from public.v1_audit_events
       where event_type = 'material_request_submitted'
         and entity_id = '52000000-0000-4000-8000-000000000001'::uuid) = 1,
  'Retry does not create another reference, event or stock side effect'
);

select ok(
  not exists (
    select 1
    from pg_constraint constraint_record
    where constraint_record.conrelid = 'public.v1_material_requests'::regclass
      and constraint_record.conname = 'v1_material_requests_request_number_key'
  ),
  'Archived projects cannot reserve a globally unique displayed MR number'
);

select lives_ok(
  $$select public.v1_save_material_request_draft(
    jsonb_set(
      jsonb_set(
        (select first_draft_payload from v1_b5_payloads),
        '{request_id}',
        '"52000000-0000-4000-8000-000000000002"'::jsonb
      ),
      '{lines,0,id}',
      '"53000000-0000-4000-8000-000000000002"'::jsonb
    )
  )$$,
  'A second draft can be saved for the same active project'
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '52000000-0000-4000-8000-000000000002',
      'expected_version', 1
    ),
    '54000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'A second draft receives its own atomic project-scoped sequence'
);

set local role postgres;
select is(
  (select request_number from public.v1_material_requests
    where id = '52000000-0000-4000-8000-000000000002'::uuid),
  'B5MR001-MR002',
  'The next Material Request increments to MR002 for the same project'
);

select ok(
  (select next_request_sequence = 3
     from public.v1_material_request_reference_counters
     where project_id = (select project_id from v1_b5_targets)),
  'Each successful Material Request consumes exactly one project sequence'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

set local role postgres;
insert into public.v1_material_request_line_commercials (
  request_line_id, unit_cost, currency_code, updated_by_auth_user_id
) values (
  '53000000-0000-4000-8000-000000000001'::uuid,
  125.0000, 'AED', '10000000-0000-4000-8000-000000000004'::uuid
);

-- Continue this legacy projection test from an explicitly approved request;
-- the approval command itself is exercised by the current revision suite.
insert into public.v1_material_request_decisions (
  request_id, request_record_version, decision, reason,
  decided_by_auth_user_id, decided_by_role, decided_by_exact_role,
  decided_by_display_name_snapshot
) values (
  '52000000-0000-4000-8000-000000000001'::uuid, 2, 'approved', null,
  '10000000-0000-4000-8000-000000000001'::uuid, 'project_engineer',
  'project_engineer', 'Local Project Engineer'
);
update public.v1_material_requests
set state = 'approved_for_arrangement',
    current_action_owner_role = 'procurement',
    current_action_code = 'arrangement_required', record_version = 3
where id = '52000000-0000-4000-8000-000000000001'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select ok(
  not ((public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) -> 'lines' -> 0) ? 'unit_cost')
  and not ((public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) -> 'lines' -> 0) ? 'total_cost'),
  'AT-04: Site Engineer receives no commercial field keys or values'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select ok(
  (public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) -> 'lines' -> 0) ? 'unit_cost'
  and (public.v1_material_request_projection(
    '52000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{lines,0,total_cost}') = '500.00000000',
  'Authorized Procurement receives its controlled commercial projection'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.v1_list_material_requests((select project_id from v1_b5_targets))
    ) request_record
    where request_record ->> 'request_number' = 'B5MR001-MR001'
  ),
  'Procurement sees the first submitted request after server confirmation'
);

set local role postgres;
select is(
  (select request_number from public.v1_material_requests
    where id = '52000000-0000-4000-8000-000000000001'::uuid),
  'B5MR001-MR001',
  'Display reference removes separator punctuation and starts at MR001'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_cancel_material_request(
    jsonb_build_object(
      'request_id', '52000000-0000-4000-8000-000000000001',
      'expected_version', 3,
      'reason', 'Scope quantity corrected before arranging'
    ),
    '55000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A Project Engineer may cancel an eligible pre-arrangement request with a reason'
);

set local role postgres;
select ok(
  (select state = 'cancelled'
      and current_action_owner_role = 'none'
      and cancellation_reason = 'Scope quantity corrected before arranging'
    from public.v1_material_requests
    where id = '52000000-0000-4000-8000-000000000001'::uuid),
  'Cancellation preserves an accountable state and reason instead of deleting history'
);

select is(
  (select count(*) from public.v1_audit_events
    where event_type = 'material_request_cancelled'
      and entity_id = '52000000-0000-4000-8000-000000000001'::uuid),
  1::bigint,
  'Cancellation has one server-generated append-only audit event'
);

select * from finish();
rollback;
