begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(37);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_delivery_orders'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_delivery_order_revisions'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_returns'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_return_lines'::regclass),
  'Batch 8 delivery-order and material-return relations enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_delivery_orders', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_material_returns', 'update')
  and has_function_privilege(
    'authenticated', 'public.v1_generate_delivery_order(jsonb,uuid)', 'execute'
  ) and has_function_privilege(
    'authenticated', 'public.v1_confirm_material_return(jsonb,uuid)', 'execute'
  ),
  'Batch 8 writes are available only through trusted RPCs'
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
      "project_ref":"B8-RET-001",
      "name":"Delivery and return project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Return preparer"
      }],
      "buildings":[{"code":"b8","name":"Returns Building"}],
      "attachments":[]
    }'::jsonb,
    '80000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the Batch 8 test project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B8-RET-001'),
      'state', 'active', 'expected_version', 1, 'reason', 'Ready for logistics'
    ), '80000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The test project is active before its committed logistics facts are prepared'
);

set local role postgres;
create temporary table v1_b8_targets as
select project.id as project_id,
  (select id from public.v1_project_scopes
    where project_id = project.id and scope_kind = 'building' limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'B8-RET-001';
grant select on table v1_b8_targets to authenticated;

-- This is committed test fixture data from the already-tested dispatch and
-- receipt commands. Batch 8 starts after receipt review, so these rows keep
-- the proof focused on the new state machines instead of bypassing them.
insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state, record_version,
  created_by_auth_user_id, requester_display_name, requester_project_role,
  current_action_owner_role, current_action_code, submitted_at,
  project_engineer_snapshot
) values (
  '81000000-0000-4000-8000-000000000001',
  (select project_id from v1_b8_targets), (select scope_id from v1_b8_targets),
  'B8-RET-001-MR001', 'Receipt reviewed materials', 'normal', 'received', 1,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer', 'site_engineer',
  'project_engineer', 'material_request_close_review', clock_timestamp(),
  '[{"display_name":"Local Project Engineer"}]'::jsonb
);
insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description, brand_origin,
  requested_qty, unit
) values
  ('81100000-0000-4000-8000-000000000001',
    '81000000-0000-4000-8000-000000000001', 1, 'custom', 'Copper pipe', 'UAE', 3, 'Mtr'),
  ('81100000-0000-4000-8000-000000000002',
    '81000000-0000-4000-8000-000000000001', 2, 'custom', 'Refrigerant valve', 'EU', 1, 'Nos');
insert into public.v1_inventory_items (
  id, item_description, brand_origin, unit, created_by_auth_user_id
) values (
  '81200000-0000-4000-8000-000000000001', 'Copper pipe', 'UAE', 'Mtr',
  '10000000-0000-4000-8000-000000000003'
);
insert into public.v1_inventory_balances (inventory_item_id, on_hand_qty)
values ('81200000-0000-4000-8000-000000000001', 0);
insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current,
  started_by_auth_user_id, saved_by_auth_user_id, saved_at
) values (
  '81300000-0000-4000-8000-000000000001',
  '81000000-0000-4000-8000-000000000001', 1, 'approved', true,
  '10000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000003', clock_timestamp()
);
insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, inventory_item_id,
  decision, arranged_qty, warehouse_available_at_save
) values (
  '81400000-0000-4000-8000-000000000001',
  '81300000-0000-4000-8000-000000000001',
  '81100000-0000-4000-8000-000000000001', 'warehouse',
  '81200000-0000-4000-8000-000000000001', 'full', 3, 3
), (
  '81400000-0000-4000-8000-000000000002',
  '81300000-0000-4000-8000-000000000001',
  '81100000-0000-4000-8000-000000000002', 'external_supplier',
  null, 'full', 1, null
);
insert into public.v1_material_request_line_approvals (
  request_line_id, arrangement_line_id, arrangement_id, approved_qty,
  approved_by_auth_user_id
) values (
  '81100000-0000-4000-8000-000000000001',
  '81400000-0000-4000-8000-000000000001',
  '81300000-0000-4000-8000-000000000001', 3,
  '10000000-0000-4000-8000-000000000001'
), (
  '81100000-0000-4000-8000-000000000002',
  '81400000-0000-4000-8000-000000000002',
  '81300000-0000-4000-8000-000000000001', 1,
  '10000000-0000-4000-8000-000000000001'
);
insert into public.v1_material_dispatches (
  id, request_id, project_id, dispatch_number, dispatch_date, delivery_reference, state,
  dispatched_by_auth_user_id, dispatched_by_role
) values (
  '81500000-0000-4000-8000-000000000001',
  '81000000-0000-4000-8000-000000000001',
  (select project_id from v1_b8_targets), 'B8-RET-001-DSP001', current_date, 'DN-B8-001',
  'received', '10000000-0000-4000-8000-000000000003', 'procurement'
), (
  '81500000-0000-4000-8000-000000000002',
  '81000000-0000-4000-8000-000000000001',
  (select project_id from v1_b8_targets), 'B8-RET-001-DSP002', current_date, 'DN-B8-002',
  'receipt_pending', '10000000-0000-4000-8000-000000000003', 'procurement'
);
insert into public.v1_material_dispatch_lines (
  id, dispatch_id, request_line_id, arrangement_line_id, source_kind,
  inventory_item_id, external_supplier, item_description, brand_origin, unit,
  approved_qty_snapshot, dispatched_qty
) values (
  '81600000-0000-4000-8000-000000000001',
  '81500000-0000-4000-8000-000000000001',
  '81100000-0000-4000-8000-000000000001',
  '81400000-0000-4000-8000-000000000001', 'warehouse',
  '81200000-0000-4000-8000-000000000001', null, 'Copper pipe', 'UAE', 'Mtr', 3, 3
), (
  '81600000-0000-4000-8000-000000000002',
  '81500000-0000-4000-8000-000000000001',
  '81100000-0000-4000-8000-000000000002',
  '81400000-0000-4000-8000-000000000002', 'external_supplier',
  null, 'Local Supplier', 'Refrigerant valve', 'EU', 'Nos', 1, 1
);
insert into public.v1_receipt_reviews (
  id, dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
) values (
  '81700000-0000-4000-8000-000000000001',
  '81500000-0000-4000-8000-000000000001',
  '81000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002', 'site_engineer'
);
insert into public.v1_receipt_review_lines (
  id, receipt_review_id, dispatch_line_id, outcome, dispatched_qty_snapshot,
  good_qty, exception_qty, note
) values (
  '81800000-0000-4000-8000-000000000001',
  '81700000-0000-4000-8000-000000000001',
  '81600000-0000-4000-8000-000000000001', 'received', 3, 3, 0, null
), (
  '81800000-0000-4000-8000-000000000002',
  '81700000-0000-4000-8000-000000000001',
  '81600000-0000-4000-8000-000000000002', 'received', 1, 1, 0, null
);

-- A project may have more than one Project Engineer. The supporting Engineer
-- must receive the same post-receipt controlled-document capability as the
-- Engineer who created the project.
insert into public.v1_project_members (
  project_id, member_auth_user_id, project_role, reason,
  assigned_by_auth_user_id, assigned_by_role
) values (
  (select project_id from v1_b8_targets),
  '10000000-0000-4000-8000-000000000004',
  'project_engineer', 'Supporting Project Engineer for Delivery Order proof',
  '10000000-0000-4000-8000-000000000001', 'project_engineer'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select ok(
  public.v1_can_generate_delivery_order(
    '81000000-0000-4000-8000-000000000001'::uuid
  ),
  'The assigned Project Engineer can generate a Delivery Order after receipt'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-supporting-project-engineer"}}',
  true
);
select ok(
  public.v1_can_generate_delivery_order(
    '81000000-0000-4000-8000-000000000001'::uuid
  ),
  'Every actively assigned Project Engineer can generate the same Delivery Order'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select ok(
  public.v1_can_generate_delivery_order(
    '81000000-0000-4000-8000-000000000001'::uuid
  ),
  'The assigned Site Engineer can generate a Delivery Order after receipt'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-unassigned-site-engineer"}}',
  true
);
select ok(
  not public.v1_can_generate_delivery_order(
    '81000000-0000-4000-8000-000000000001'::uuid
  ),
  'An unassigned Site Engineer cannot generate the project Delivery Order'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select ok(
  jsonb_array_length(public.v1_material_request_document_projection(
    '81000000-0000-4000-8000-000000000001'::uuid
  ) -> 'project_engineers') = 1
  and (public.v1_material_request_document_projection(
    '81000000-0000-4000-8000-000000000001'::uuid
  ) #>> '{dispatch,reference}') = 'DN-B8-001'
  and (public.v1_material_request_document_projection(
    '81000000-0000-4000-8000-000000000001'::uuid
  ) -> 'receipt_statuses') @> '[{"status":"Received"}]'::jsonb,
  'The controlled MR document projection includes Project Engineers, dispatch and receipt facts'
);

select throws_ok(
  $$insert into public.v1_delivery_orders (
    request_id, dispatch_id, project_id, delivery_order_reference,
    created_by_auth_user_id, created_by_role
  ) values (
    '81000000-0000-4000-8000-000000000001',
    '81500000-0000-4000-8000-000000000001',
    (select project_id from v1_b8_targets), 'BYPASS-DO', auth.uid(), 'procurement'
  )$$,
  '42501', null,
  'Procurement cannot bypass the Delivery Order command with a direct insert'
);

select throws_ok(
  $$select public.v1_generate_delivery_order(
    jsonb_build_object(
      'request_id', '81000000-0000-4000-8000-000000000001',
      'dispatch_id', '81500000-0000-4000-8000-000000000002',
      'expected_request_version', 1, 'expected_dispatch_version', 1,
      'delivery_order_reference', 'B8-DO-PREVIEW'
    ), '82000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '22023', 'V1_DELIVERY_ORDER_RECEIPT_REVIEW_REQUIRED',
  'Delivery Order generation is rejected until receipt review exists'
);

select lives_ok(
  $$select public.v1_generate_delivery_order(
    jsonb_build_object(
      'request_id', '81000000-0000-4000-8000-000000000001',
      'dispatch_id', '81500000-0000-4000-8000-000000000001',
      'expected_request_version', 1, 'expected_dispatch_version', 1,
      'delivery_order_reference', '  b8-do-001  '
    ), '82000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Procurement generates the first immutable Delivery Order revision'
);

set local role postgres;
select is(
  (select delivery_order_reference from public.v1_delivery_orders), 'B8-DO-001',
  'The authorized reference is normalized and stored globally'
);

select ok(
  (select count(*) = 1 from public.v1_delivery_order_revisions)
  and (select count(*) = 2 from public.v1_delivery_order_revision_lines)
  and (select bool_and((to_jsonb(line) - 'id' - 'delivery_order_revision_id'
    - 'receipt_review_line_id' - 'display_order') = jsonb_build_object(
      'item_description', item_description, 'good_quantity', good_quantity,
      'unit', unit
    )) from public.v1_delivery_order_revision_lines line),
  'The Delivery Order snapshot has good-received rows only and exactly four printable columns'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_generate_delivery_order(
    jsonb_build_object(
      'request_id', '81000000-0000-4000-8000-000000000001',
      'dispatch_id', '81500000-0000-4000-8000-000000000001',
      'expected_request_version', 1, 'expected_dispatch_version', 1,
      'delivery_order_reference', '  b8-do-001  '
    ), '82000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'A Delivery Order retry returns the committed snapshot'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_delivery_order_revisions), 1,
  'A Delivery Order retry never duplicates its immutable revision'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_generate_delivery_order(
    jsonb_build_object(
      'request_id', '81000000-0000-4000-8000-000000000001',
      'dispatch_id', '81500000-0000-4000-8000-000000000001',
      'expected_request_version', 1, 'expected_dispatch_version', 1,
      'delivery_order_reference', 'B8-DO-001'
    ), '82000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Regeneration appends a second Delivery Order revision'
);

set local role postgres;
select ok(
  (select count(*) = 2 from public.v1_delivery_order_revisions)
  and (select count(*) = 2 from public.v1_delivery_order_revision_lines
    where delivery_order_revision_id = (
      select id from public.v1_delivery_order_revisions where revision_number = 1
    ))
  and (select current_revision_id = (
    select id from public.v1_delivery_order_revisions where revision_number = 2
  ) from public.v1_delivery_orders),
  'Regeneration moves only the current pointer and preserves the prior revision snapshot'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_generate_delivery_order(
    jsonb_build_object(
      'request_id', '81000000-0000-4000-8000-000000000001',
      'dispatch_id', '81500000-0000-4000-8000-000000000001',
      'expected_request_version', 1, 'expected_dispatch_version', 1,
      'delivery_order_reference', 'B8-DO-001'
    ), '82000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'An assigned Site Engineer can generate the post-receipt Delivery Order revision'
);

select lives_ok(
  $$select public.v1_save_material_return_draft(
    jsonb_build_object(
      'return_id', null, 'request_id', '81000000-0000-4000-8000-000000000001',
      'expected_version', 0, 'note', 'Unused copper',
      'lines', jsonb_build_array(jsonb_build_object(
        'receipt_review_line_id', '81800000-0000-4000-8000-000000000001',
        'return_qty', '2'
      ))
    ), '83000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Site Engineer saves an editable warehouse return draft'
);

set local role postgres;
create temporary table v1_b8_warehouse_return as
select id as return_id, record_version from public.v1_material_returns
where note = 'Unused copper';
grant select on table v1_b8_warehouse_return to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_submit_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_warehouse_return),
      'expected_version', (select record_version from v1_b8_warehouse_return)
    ), '83000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Site Engineer submits a frozen return snapshot'
);

set local role postgres;
select ok(
  (select state = 'submitted' and return_number = 'B8-RET-001-RTN001'
    from public.v1_material_returns
    where id = (select return_id from v1_b8_warehouse_return))
  and (select eligible_quantity_at_submit = 3 from public.v1_material_return_lines
    where material_return_id = (select return_id from v1_b8_warehouse_return)),
  'Return submission allocates a number and freezes eligibility from good receipt facts'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_warehouse_return),
      'expected_version', 2, 'line_mappings', '[]'::jsonb
    ), '83000000-0000-4000-8000-000000000003'::uuid
  )$$,
  '42501', 'V1_RETURN_CONFIRM_DENIED',
  'Site Engineer cannot confirm a physical warehouse return'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_warehouse_return),
      'expected_version', 2, 'line_mappings', '[]'::jsonb
    ), '83000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Procurement confirms the physical warehouse return'
);

select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_warehouse_return),
      'expected_version', 2, 'line_mappings', '[]'::jsonb
    ), '83000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A confirmation retry returns the original committed response'
);

set local role postgres;
select ok(
  (select state = 'confirmed' from public.v1_material_returns
    where id = (select return_id from v1_b8_warehouse_return))
  and (select on_hand_qty = 2 from public.v1_inventory_balances
    where inventory_item_id = '81200000-0000-4000-8000-000000000001')
  and (select count(*) = 1 from public.v1_inventory_movements
    where source_entity_type = 'material_return_line'),
  'Confirmation increments stock and appends its movement exactly once'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_return_draft(
    jsonb_build_object(
      'return_id', null, 'request_id', '81000000-0000-4000-8000-000000000001',
      'expected_version', 0, 'note', 'Too much copper',
      'lines', jsonb_build_array(jsonb_build_object(
        'receipt_review_line_id', '81800000-0000-4000-8000-000000000001',
        'return_qty', '2'
      ))
    ), '83000000-0000-4000-8000-000000000005'::uuid
  )$$,
  'A second draft can be prepared without reserving stock'
);

set local role postgres;
create temporary table v1_b8_over_return as
select id as return_id, record_version from public.v1_material_returns
where note = 'Too much copper';
grant select on table v1_b8_over_return to authenticated;

set local role authenticated;
select throws_ok(
  $$select public.v1_submit_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_over_return),
      'expected_version', (select record_version from v1_b8_over_return)
    ), '83000000-0000-4000-8000-000000000006'::uuid
  )$$,
  '22023', 'V1_RETURN_ELIGIBLE_QTY_EXCEEDED',
  'Submission rejects returns above good received less prior confirmed returns'
);

select lives_ok(
  $$select public.v1_save_material_return_draft(
    jsonb_build_object(
      'return_id', null, 'request_id', '81000000-0000-4000-8000-000000000001',
      'expected_version', 0, 'note', 'Supplier valve return',
      'lines', jsonb_build_array(jsonb_build_object(
        'receipt_review_line_id', '81800000-0000-4000-8000-000000000002',
        'return_qty', '1'
      ))
    ), '83000000-0000-4000-8000-000000000007'::uuid
  )$$,
  'A supplier-source return draft retains its receipt provenance'
);

set local role postgres;
create temporary table v1_b8_supplier_return as
select id as return_id, record_version from public.v1_material_returns
where note = 'Supplier valve return';
grant select on table v1_b8_supplier_return to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_submit_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_supplier_return),
      'expected_version', (select record_version from v1_b8_supplier_return)
    ), '83000000-0000-4000-8000-000000000008'::uuid
  )$$,
  'The supplier-source return is submitted for Procurement confirmation'
);

set local role postgres;
create temporary table v1_b8_supplier_return_line as
select id as return_line_id from public.v1_material_return_lines
where material_return_id = (select return_id from v1_b8_supplier_return);
grant select on table v1_b8_supplier_return_line to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_supplier_return),
      'expected_version', 2, 'line_mappings', '[]'::jsonb
    ), '83000000-0000-4000-8000-000000000009'::uuid
  )$$,
  '22023', 'V1_RETURN_CONFIRM_MAPPINGS_INVALID',
  'Supplier-source stock cannot be confirmed without an identified inventory item'
);

select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_supplier_return),
      'expected_version', 2,
      'line_mappings', jsonb_build_array(jsonb_build_object(
        'return_line_id', (select return_line_id from v1_b8_supplier_return_line),
        'inventory_item_id', null,
        'new_inventory_item', jsonb_build_object(
          'item_description', 'Refrigerant valve', 'brand_origin', 'EU', 'unit', 'Nos'
        )
      ))
    ), '83000000-0000-4000-8000-000000000010'::uuid
  )$$,
  'Procurement maps supplier material to a new controlled inventory item on confirmation'
);

set local role postgres;
select ok(
  (select count(*) = 1 from public.v1_inventory_items
    where item_description = 'Refrigerant valve' and unit = 'Nos')
  and (select count(*) = 2 from public.v1_inventory_movements
    where source_entity_type = 'material_return_line'),
  'Supplier return creates identified stock and one auditable movement'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_save_material_return_draft(
    jsonb_build_object(
      'return_id', null, 'request_id', '81000000-0000-4000-8000-000000000001',
      'expected_version', 0, 'note', 'Return awaiting warehouse check',
      'lines', jsonb_build_array(jsonb_build_object(
        'receipt_review_line_id', '81800000-0000-4000-8000-000000000001',
        'return_qty', '1'
      ))
    ), '83000000-0000-4000-8000-000000000011'::uuid
  )$$,
  'The remaining good quantity can be prepared as another return draft'
);

set local role postgres;
create temporary table v1_b8_rejected_return as
select id as return_id, record_version from public.v1_material_returns
where note = 'Return awaiting warehouse check';
grant select on table v1_b8_rejected_return to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_submit_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_rejected_return),
      'expected_version', (select record_version from v1_b8_rejected_return)
    ), '83000000-0000-4000-8000-000000000012'::uuid
  )$$,
  'The final eligible draft can be submitted for a warehouse decision'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_reject_material_return(
    jsonb_build_object(
      'return_id', (select return_id from v1_b8_rejected_return),
      'expected_version', 2, 'reason', 'Warehouse count does not match'
    ), '83000000-0000-4000-8000-000000000013'::uuid
  )$$,
  'Procurement rejects a submitted return with a required reason'
);

set local role postgres;
select ok(
  (select state = 'rejected' and rejection_reason = 'Warehouse count does not match'
    from public.v1_material_returns
    where id = (select return_id from v1_b8_rejected_return))
  and (select count(*) = 2 from public.v1_inventory_movements
    where source_entity_type = 'material_return_line'),
  'A rejected return records its decision without moving stock'
);

select * from finish();
rollback;
