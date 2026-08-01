begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(29);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_material_dispatches'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_receipt_reviews'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_receipt_review_lines'::regclass),
  'Batch 7 dispatch and receipt relations enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_material_dispatches', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_receipt_reviews', 'update')
  and has_function_privilege(
    'authenticated', 'public.v1_dispatch_materials(jsonb,uuid)', 'execute'
  ) and has_function_privilege(
    'authenticated', 'public.v1_confirm_receipt(jsonb,uuid)', 'execute'
  ),
  'Logistics mutations are reachable only through trusted commands'
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
      "project_ref":"B7-LOG-001",
      "name":"Logistics Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Receipt reviewer"
      }],
      "buildings":[{"code":"b7","name":"Logistics Building"}],
      "attachments":[]
    }'::jsonb,
    '70000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the logistics test project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B7-LOG-001'),
      'state', 'active', 'expected_version', 1, 'reason', 'Ready for dispatch'
    ), '70000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The project is activated before Material Request submission'
);

set local role postgres;
create temporary table v1_b7_targets as
select project.id as project_id,
  (select id from public.v1_project_scopes
    where project_id = project.id and scope_kind = 'building' limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'B7-LOG-001';
grant select on table v1_b7_targets to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(jsonb_build_object(
    'request_id', '71000000-0000-4000-8000-000000000001',
    'expected_version', 0,
    'project_id', (select project_id from v1_b7_targets),
    'scope_id', (select scope_id from v1_b7_targets),
    'title', 'Dispatch and receipt request', 'timing', 'normal',
    'scheduled_date', null, 'delivery_note', null,
    'lines', jsonb_build_array(jsonb_build_object(
      'id', '71100000-0000-4000-8000-000000000001', 'display_order', 1,
      'source_kind', 'custom', 'source_boq_group_id', null,
      'source_boq_row_id', null, 'item_description', 'VAV Damper',
      'brand_origin', 'UAE', 'requested_qty', '4', 'unit', 'Nos'
    ))
  ))$$,
  'Site Engineer prepares a request whose stock will be dispatched'
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 1
    ), '72000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'The request is submitted to Procurement'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_adjust_inventory(
    jsonb_build_object(
      'inventory_item_id', null, 'item_description', 'VAV Damper',
      'brand_origin', 'UAE', 'unit', 'Nos', 'quantity_delta', '4',
      'reason', 'Opening balance for dispatch test'
    ), '73000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement creates the controlled warehouse item'
);

set local role postgres;
create temporary table v1_b7_inventory as
select id as inventory_item_id from public.v1_inventory_items
where item_description = 'VAV Damper' and brand_origin = 'UAE' and unit = 'Nos';
grant select on table v1_b7_inventory to authenticated;

set local role authenticated;
select throws_ok(
  $$insert into public.v1_material_dispatches (
    request_id, project_id, dispatch_number, dispatch_date,
    dispatched_by_auth_user_id, dispatched_by_role
  ) values (
    '71000000-0000-4000-8000-000000000001',
    (select project_id from v1_b7_targets), 'BYPASS', current_date,
    auth.uid(), 'procurement'
  )$$,
  '42501', null,
  'Procurement cannot bypass the dispatch command with a direct insert'
);

select lives_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 2
    ), '74000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement explicitly begins the request arrangement'
);

set local role postgres;
create temporary table v1_b7_arrangement as
select id as arrangement_id, record_version as arrangement_version
from public.v1_procurement_arrangements
where request_id = '71000000-0000-4000-8000-000000000001'::uuid
  and status = 'working';
create temporary table v1_b7_arrangement_lines as
select id as arrangement_line_id from public.v1_procurement_arrangement_lines
where arrangement_id = (select arrangement_id from v1_b7_arrangement);
grant select on table v1_b7_arrangement, v1_b7_arrangement_lines to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b7_arrangement),
      'expected_request_version', 3, 'expected_arrangement_version', 1,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', (select arrangement_line_id from v1_b7_arrangement_lines),
        'source_kind', 'warehouse', 'external_supplier', null,
        'inventory_item_id', (select inventory_item_id from v1_b7_inventory),
        'decision', 'full', 'arranged_qty', '4', 'reason', null
      ))
    ), '74000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The full warehouse arrangement creates one reservation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_decide_arrangement(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b7_arrangement),
      'expected_request_version', 4, 'expected_arrangement_version', 2,
      'decision', 'approved', 'reason', null
    ), '75000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer approves the arrangement before dispatch'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Site Engineer cannot access the general inventory workspace'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  (public.v1_inventory_workspace_projection('vav') -> 'items' -> 0 ->> 'available_qty')::numeric,
  0::numeric,
  'Procurement inventory workspace reports the active reservation as unavailable stock'
);

select lives_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 5, 'dispatch_date', current_date::text,
      'driver_name', 'Yorks Driver', 'vehicle_reference', 'Van 7',
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '3'
      ))
    ), '76000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement dispatches a subset through the locked transaction'
);

select lives_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 5, 'dispatch_date', current_date::text,
      'driver_name', 'Yorks Driver', 'vehicle_reference', 'Van 7',
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '3'
      ))
    ), '76000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A dispatch retry returns the original committed result'
);

set local role postgres;
create temporary table v1_b7_first_dispatch as
select id as dispatch_id, record_version as dispatch_version
from public.v1_material_dispatches
where request_id = '71000000-0000-4000-8000-000000000001'::uuid
order by created_at limit 1;
create temporary table v1_b7_first_dispatch_lines as
select id as dispatch_line_id from public.v1_material_dispatch_lines
where dispatch_id = (select dispatch_id from v1_b7_first_dispatch);
grant select on table v1_b7_first_dispatch, v1_b7_first_dispatch_lines to authenticated;

select ok(
  (select on_hand_qty = 1 and record_version = 3
    from public.v1_inventory_balances
    where inventory_item_id = (select inventory_item_id from v1_b7_inventory))
  and (select reserved_qty = 4 and consumed_qty = 3 and state = 'partially_consumed'
    from public.v1_inventory_reservations
    where request_id = '71000000-0000-4000-8000-000000000001'::uuid)
  and (select count(*) = 1 from public.v1_inventory_movements
    where movement_type = 'dispatch'),
  'Retry does not duplicate the warehouse movement or reservation consumption'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 6, 'dispatch_date', current_date::text,
      'driver_name', null, 'vehicle_reference', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '2'
      ))
    ), '76000000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023', 'V1_DISPATCH_APPROVED_CAP_EXCEEDED',
  'A competing dispatch cannot exceed approved quantity less in-transit stock'
);

select throws_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_b7_first_dispatch),
      'expected_request_version', 6,
      'expected_dispatch_version', (select dispatch_version from v1_b7_first_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_b7_first_dispatch_lines),
        'outcome', 'missing', 'good_qty', '2', 'note', 'One item missing'
      ))
    ), '77000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_RECEIPT_CONFIRM_DENIED',
  'Procurement may read but cannot confirm a site receipt'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_b7_first_dispatch),
      'expected_request_version', 6,
      'expected_dispatch_version', (select dispatch_version from v1_b7_first_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_b7_first_dispatch_lines),
        'outcome', 'received', 'good_qty', '2', 'note', null
      ))
    ), '77000000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023', 'V1_RECEIPT_LINE_INVALID',
  'Received outcome must reconcile to the full dispatched quantity'
);

select lives_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_b7_first_dispatch),
      'expected_request_version', 6,
      'expected_dispatch_version', (select dispatch_version from v1_b7_first_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_b7_first_dispatch_lines),
        'outcome', 'missing', 'good_qty', '2', 'note', 'One item missing'
      ))
    ), '77000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Site Engineer records a reconciled Missing receipt outcome'
);

set local role postgres;
select ok(
  (select state = 'partially_received' and current_action_owner_role = 'procurement'
    from public.v1_material_requests
    where id = '71000000-0000-4000-8000-000000000001'::uuid)
  and (select good_qty = 2 and exception_qty = 1 and outcome = 'missing'
    from public.v1_receipt_review_lines),
  'Only good quantity is received and the missing amount becomes replacement eligible'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 7, 'dispatch_date', current_date::text,
      'driver_name', null, 'vehicle_reference', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '2'
      ))
    ), '76000000-0000-4000-8000-000000000003'::uuid
  )$$,
  '22023', 'V1_DISPATCH_STOCK_CAP_EXCEEDED',
  'A replacement dispatch cannot consume stock held for another commitment'
);

select lives_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 7, 'dispatch_date', current_date::text,
      'driver_name', null, 'vehicle_reference', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '1'
      ))
    ), '76000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Procurement dispatches the remaining reserved warehouse quantity'
);

set local role postgres;
create temporary table v1_b7_second_dispatch as
select id as dispatch_id, record_version as dispatch_version
from public.v1_material_dispatches
where request_id = '71000000-0000-4000-8000-000000000001'::uuid
order by created_at desc limit 1;
create temporary table v1_b7_second_dispatch_lines as
select id as dispatch_line_id from public.v1_material_dispatch_lines
where dispatch_id = (select dispatch_id from v1_b7_second_dispatch);
grant select on table v1_b7_second_dispatch, v1_b7_second_dispatch_lines to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_b7_second_dispatch),
      'expected_request_version', 8,
      'expected_dispatch_version', (select dispatch_version from v1_b7_second_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_b7_second_dispatch_lines),
        'outcome', 'received', 'good_qty', '1', 'note', null
      ))
    ), '77000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A subsequent full receipt still leaves the original short quantity open'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_adjust_inventory(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_b7_inventory),
      'item_description', null, 'brand_origin', null, 'unit', null,
      'quantity_delta', '1', 'reason', 'Replacement stock received outside V1 supplier flow'
    ), '73000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'An authorized inventory adjustment replenishes stock for a replacement'
);

select lives_ok(
  $$select public.v1_dispatch_materials(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'expected_version', 9, 'dispatch_date', current_date::text,
      'driver_name', null, 'vehicle_reference', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'request_line_id', '71100000-0000-4000-8000-000000000001',
        'dispatch_qty', '1'
      ))
    ), '76000000-0000-4000-8000-000000000005'::uuid
  )$$,
  'Replacement eligibility permits a later warehouse dispatch without over-consuming a reservation'
);

set local role postgres;
create temporary table v1_b7_third_dispatch as
select id as dispatch_id, record_version as dispatch_version
from public.v1_material_dispatches
where request_id = '71000000-0000-4000-8000-000000000001'::uuid
order by created_at desc limit 1;
create temporary table v1_b7_third_dispatch_lines as
select id as dispatch_line_id from public.v1_material_dispatch_lines
where dispatch_id = (select dispatch_id from v1_b7_third_dispatch);
grant select on table v1_b7_third_dispatch, v1_b7_third_dispatch_lines to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_confirm_receipt(
    jsonb_build_object(
      'request_id', '71000000-0000-4000-8000-000000000001',
      'dispatch_id', (select dispatch_id from v1_b7_third_dispatch),
      'expected_request_version', 10,
      'expected_dispatch_version', (select dispatch_version from v1_b7_third_dispatch),
      'lines', jsonb_build_array(jsonb_build_object(
        'dispatch_line_id', (select dispatch_line_id from v1_b7_third_dispatch_lines),
        'outcome', 'received', 'good_qty', '1', 'note', null
      ))
    ), '77000000-0000-4000-8000-000000000005'::uuid
  )$$,
  'The final good receipt resolves the approved quantity'
);

set local role postgres;
select ok(
  (select state = 'received' and current_action_owner_role = 'project_engineer'
    from public.v1_material_requests
    where id = '71000000-0000-4000-8000-000000000001'::uuid)
  and (select on_hand_qty = 0 from public.v1_inventory_balances
    where inventory_item_id = (select inventory_item_id from v1_b7_inventory))
  and (select count(*) = 3 from public.v1_inventory_movements
    where movement_type = 'dispatch'),
  'Receipt and replacement transitions end received without negative stock or duplicate movements'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$insert into public.v1_receipt_reviews (
    dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
  ) values (
    (select dispatch_id from v1_b7_third_dispatch),
    '71000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002', 'site_engineer'
  )$$,
  '42501', null,
  'No client can append a second receipt review outside the command'
);

select * from finish();
rollback;
