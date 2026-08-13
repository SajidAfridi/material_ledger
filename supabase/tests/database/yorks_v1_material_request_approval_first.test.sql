begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(36);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_comments'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_decisions'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_material_request_comments', 'insert'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_decide_material_request(jsonb,uuid)', 'execute'
  ),
  'Approval decisions and comments are RLS protected and command-only'
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
      "project_ref":"MR-AF-001",
      "name":"Approval First Material Request",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Request author"
      }],
      "buildings":[{"code":"af","name":"Approval Building"}],
      "attachments":[]
    }'::jsonb,
    'af000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the approval-first project fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-AF-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for approval-first testing'
    ),
    'af000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The approval-first project is activated'
);

set local role postgres;
create temporary table v1_af_targets as
select project.id as project_id,
  (select scope.id from public.v1_project_scopes scope
   where scope.project_id = project.id and scope.scope_kind = 'building'
   limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'MR-AF-001';

create temporary table v1_af_payload as
select jsonb_build_object(
  'request_id', 'af100000-0000-4000-8000-000000000001',
  'expected_version', 0,
  'project_id', project_id,
  'scope_id', scope_id,
  'title', 'Approval first dampers',
  'timing', 'normal', 'scheduled_date', null,
  'delivery_note', 'Site store',
  'lines', jsonb_build_array(jsonb_build_object(
    'id', 'af110000-0000-4000-8000-000000000001',
    'display_order', 1, 'source_kind', 'custom',
    'source_boq_group_id', null, 'source_boq_row_id', null,
    'item_description', 'approval first damper',
    'brand_origin', 'UAE',
    'technical_attributes', jsonb_build_object(
      'size', '500 x 500', 'model', 'AF-500'
    ),
    'requested_qty', '2', 'unit', 'Nos'
  ))
) as payload from v1_af_targets;
grant select on table v1_af_targets, v1_af_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(
    (select payload from v1_af_payload)
  )$$,
  'Assigned Site Engineer saves the server-backed request draft'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  jsonb_array_length(public.v1_list_material_requests(
    (select project_id from v1_af_targets)
  )), 1,
  'Assigned Project Engineer sees the server-backed draft stage'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select is(
  public.v1_material_request_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  ) ->> 'state', 'draft',
  'Senior Mechanical Engineer sees the draft without project membership'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select is(
  public.v1_material_request_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  ) ->> 'state', 'draft',
  'Project Manager sees the draft without project membership'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_material_request_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_NOT_READABLE',
  'Procurement cannot read the pre-approved draft'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_add_material_request_comment(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'body', 'Please confirm the delivery note.',
      'mentioned_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000002'
      )
    ), 'af200000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer comments and mentions an authorized Site Engineer from draft'
);
select lives_ok(
  $$select public.v1_add_material_request_comment(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'body', 'Please confirm the delivery note.',
      'mentioned_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000002'
      )
    ), 'af200000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A duplicate comment retry returns the original response'
);

set local role postgres;
select is(
  (select count(*) from public.v1_material_request_comments
   where request_id = 'af100000-0000-4000-8000-000000000001'::uuid),
  1::bigint,
  'Comment retry creates one immutable comment'
);
select is(
  (select count(*) from public.v1_notifications
   where event_code = 'material_request_mentioned'
     and entity_id = 'af100000-0000-4000-8000-000000000001'::uuid),
  1::bigint,
  'A validated mention creates exactly one notification'
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
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 1
    ), 'af300000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Site Engineer submits the request for Engineering approval'
);

set local role postgres;
select ok(
  (select state = 'awaiting_request_approval'
     and current_action_owner_role = 'project_engineer'
     and current_action_code = 'request_approval_required'
   from public.v1_material_requests
   where id = 'af100000-0000-4000-8000-000000000001'::uuid),
  'Submission enters the explicit Engineering approval state'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_list_material_requests((select project_id from v1_af_targets)),
  '[]'::jsonb,
  'Procurement cannot list a request awaiting Engineering approval'
);
select throws_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 2
    ), 'af300000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023', 'V1_BEGIN_ARRANGEMENT_STATE_INVALID',
  'Procurement cannot begin arrangement before approval'
);
select lives_ok(
  $$select public.v1_adjust_inventory(
    jsonb_build_object(
      'inventory_item_id', null,
      'item_description', 'Approval First Damper',
      'brand_origin', 'UAE', 'unit', 'Nos', 'quantity_delta', '3',
      'reason', 'Autocomplete fixture'
    ), 'af300000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Procurement creates an inventory item for Engineering autocomplete'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select ok(
  jsonb_array_length(public.v1_search_material_request_inventory_items(
    (select project_id from v1_af_targets), 'Approval First', 12
  )) = 1
  and not ((public.v1_search_material_request_inventory_items(
    (select project_id from v1_af_targets), 'Approval First', 12
  ) -> 0) ? 'unit_cost')
  and not ((public.v1_search_material_request_inventory_items(
    (select project_id from v1_af_targets), 'Approval First', 12
  ) -> 0) ? 'on_hand_qty'),
  'Engineering inventory autocomplete returns one non-commercial safe shape'
);
select throws_ok(
  $$select public.v1_decide_material_request(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 2, 'decision', 'approved', 'reason', null
    ), 'af400000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_DECISION_DENIED',
  'Site Engineer cannot grant request approval'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_update_material_request_for_approval(
    (select payload from v1_af_payload) || jsonb_build_object(
      'expected_version', 2,
      'title', 'Edited and approved dampers'
    ), 'af400000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Assigned Project Engineer edits the request before approval'
);
select throws_ok(
  $$select public.v1_update_material_request_for_approval(
    (select payload from v1_af_payload) || jsonb_build_object(
      'expected_version', 2,
      'title', 'Stale overwrite'
    ), 'af400000-0000-4000-8000-000000000003'::uuid
  )$$,
  '40001', 'V1_MATERIAL_REQUEST_VERSION_CONFLICT',
  'A stale Engineering edit fails without overwriting the request'
);
select lives_ok(
  $$select public.v1_decide_material_request(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 3, 'decision', 'approved', 'reason', null
    ), 'af400000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Assigned Project Engineer approves the edited request'
);

select ok(
  (public.v1_material_request_document_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  ) -> 'approval' ->> 'display_name') <> ''
  and (public.v1_material_request_document_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  ) -> 'approval' ->> 'role') = 'project_engineer'
  and (public.v1_material_request_document_projection(
    'af100000-0000-4000-8000-000000000001'::uuid
  ) -> 'approval' ->> 'reference') = 'Request v3',
  'Controlled MR form uses the immutable request approval actor and version'
);

set local role postgres;
select ok(
  (select state = 'approved_for_arrangement'
     and current_action_owner_role = 'procurement'
   from public.v1_material_requests
   where id = 'af100000-0000-4000-8000-000000000001'::uuid)
  and (select decided_by_exact_role = 'project_engineer'
       from public.v1_material_request_decisions
       where request_id = 'af100000-0000-4000-8000-000000000001'::uuid
         and decision = 'approved'),
  'Approval preserves exact role and transfers ownership to Procurement'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_decide_material_request(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 3, 'decision', 'approved', 'reason', null
    ), 'af400000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A repeated approval retry returns the original authoritative result'
);

set local role postgres;
select is(
  (select count(*) from public.v1_material_request_decisions
   where request_id = 'af100000-0000-4000-8000-000000000001'::uuid
     and decision = 'approved'),
  1::bigint,
  'Approval retry creates one immutable decision'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  jsonb_array_length(public.v1_list_material_requests(
    (select project_id from v1_af_targets)
  )), 1,
  'Procurement sees the request only after Engineering approval'
);
select lives_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 4
    ), 'af500000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement begins the approved arrangement'
);

set local role postgres;
create temporary table v1_af_arrangement as
select arrangement.id as arrangement_id, line_record.id as arrangement_line_id
from public.v1_procurement_arrangements arrangement
join public.v1_procurement_arrangement_lines line_record
  on line_record.arrangement_id = arrangement.id
where arrangement.request_id = 'af100000-0000-4000-8000-000000000001'::uuid
  and arrangement.status = 'working';
grant select on table v1_af_arrangement to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_af_arrangement),
      'expected_request_version', 5,
      'expected_arrangement_version', 1,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', (select arrangement_line_id from v1_af_arrangement),
        'source_kind', 'external_supplier', 'external_supplier', null,
        'inventory_item_id', null, 'decision', 'full',
        'arranged_qty', '2', 'reason', null
      ))
    ), 'af500000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Procurement completes a pre-approved external arrangement without supplier text'
);

set local role postgres;
select ok(
  (select state = 'approved' and record_version = 7
   from public.v1_material_requests
   where id = 'af100000-0000-4000-8000-000000000001'::uuid)
  and (select approved_qty = 2
       from public.v1_material_request_line_approvals
       where request_line_id = 'af110000-0000-4000-8000-000000000001'::uuid),
  'The pre-approved arrangement becomes dispatch-ready without a second approval'
);
select ok(
  (select status = 'approved'
   from public.v1_procurement_arrangements
   where request_id = 'af100000-0000-4000-8000-000000000001'::uuid
     and is_current)
  and not exists (
    select 1 from public.v1_audit_events
    where entity_id = (select arrangement_id from v1_af_arrangement)
      and event_type = 'arrangement_approved'
  )
  and not exists (
    select 1 from public.v1_notifications
    where entity_id = (select arrangement_id from v1_af_arrangement)
      and event_code = 'arrangement_review_required'
  ),
  'Saving a pre-approved arrangement creates no second review task or approval event'
);
select is(
  (select count(*) from public.v1_inventory_reservations
   where request_id = 'af100000-0000-4000-8000-000000000001'::uuid),
  0::bigint,
  'External Supplier arrangement creates no warehouse reservation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'expected_version', 7, 'dispatch_date', current_date::text,
      'delivery_reference', 'AF-DN-001', 'driver_name', null,
      'vehicle_reference', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', 'af110000-0000-4000-8000-000000000001',
        'dispatch_qty', '2'
      ))
    ), 'af600000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement dispatches the fully arranged external quantity'
);

set local role postgres;
create temporary table v1_af_dispatch as
select dispatch.id as dispatch_id, dispatch.record_version as dispatch_version,
  line_record.id as dispatch_line_id
from public.v1_material_dispatches dispatch
join public.v1_material_dispatch_lines line_record
  on line_record.dispatch_id = dispatch.id
where dispatch.request_id = 'af100000-0000-4000-8000-000000000001'::uuid;
grant select on table v1_af_dispatch to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', 'af100000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_af_dispatch),
      'expected_request_version', 8,
      'expected_dispatch_version', (select dispatch_version from v1_af_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_af_dispatch),
        'outcome', 'received', 'good_qty', '2', 'note', null
      ))
    ), 'af600000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Site Engineer confirms the dispatched receipt'
);

set local role postgres;
create temporary table v1_af_receipt as
select id as receipt_review_id from public.v1_receipt_reviews
where request_id = 'af100000-0000-4000-8000-000000000001'::uuid
  and state = 'confirmed';
grant select on table v1_af_receipt to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_af_targets),
      'entity_type', 'receipt_review',
      'entity_id', (select receipt_review_id from v1_af_receipt),
      'document_id', null, 'classification', 'operational',
      'file_name', 'site-receipt.jpg', 'mime_type', 'image/jpeg',
      'byte_size', 12, 'sha256', repeat('a', 64), 'origin', 'uploaded',
      'source_entity_type', null, 'source_entity_id', null,
      'source_revision', null
    ), 'af600000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Receiving Engineer can prepare a controlled site-photo upload after confirmation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_af_targets),
      'entity_type', 'receipt_review',
      'entity_id', (select receipt_review_id from v1_af_receipt),
      'document_id', null, 'classification', 'operational',
      'file_name', 'unauthorized.jpg', 'mime_type', 'image/jpeg',
      'byte_size', 12, 'sha256', repeat('b', 64), 'origin', 'uploaded',
      'source_entity_type', null, 'source_entity_id', null,
      'source_revision', null
    ), 'af600000-0000-4000-8000-000000000004'::uuid
  )$$,
  '42501', 'V1_DOCUMENT_TARGET_WRITE_DENIED',
  'Procurement cannot attach receiving-engineer site evidence'
);

select * from finish();
rollback;
