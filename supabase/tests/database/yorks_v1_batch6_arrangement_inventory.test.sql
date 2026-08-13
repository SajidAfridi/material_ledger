begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(30);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_inventory_reservations'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_procurement_arrangements'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_inventory_movements'::regclass),
  'Batch 6 inventory, reservation and arrangement relations enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_inventory_items', 'select')
  and not has_table_privilege('authenticated', 'public.v1_inventory_reservations', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_procurement_arrangements', 'update')
  and has_function_privilege(
    'authenticated', 'public.v1_save_arrangement(jsonb,uuid)', 'execute'
  ),
  'Inventory and arrangements are reachable only through controlled RPCs'
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
      "project_ref":"B6-ARR-001",
      "name":"Arrangement Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Arrangement requester"
      }],
      "buildings":[{"code":"b6","name":"Arrangement Building"}],
      "attachments":[]
    }'::jsonb,
    '60000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates a project for the arrangement transaction'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B6-ARR-001'),
      'state', 'active', 'expected_version', 1, 'reason', 'Ready for arranging'
    ),
    '60000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Only an active project accepts its submitted Material Requests'
);

set local role postgres;
create temporary table v1_b6_targets as
select project.id as project_id,
  (select id from public.v1_project_scopes
    where project_id = project.id and scope_kind = 'building' limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'B6-ARR-001';
grant select on table v1_b6_targets to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(jsonb_build_object(
    'request_id', '61000000-0000-4000-8000-000000000001',
    'expected_version', 0,
    'project_id', (select project_id from v1_b6_targets),
    'scope_id', (select scope_id from v1_b6_targets),
    'title', 'Primary arrangement request', 'timing', 'normal',
    'scheduled_date', null, 'delivery_note', null,
    'lines', jsonb_build_array(
      jsonb_build_object(
        'id', '61100000-0000-4000-8000-000000000001', 'display_order', 1,
        'source_kind', 'custom', 'source_boq_group_id', null,
        'source_boq_row_id', null, 'item_description', 'Duct Damper',
        'brand_origin', 'UAE', 'requested_qty', '4', 'unit', 'Nos'
      ),
      jsonb_build_object(
        'id', '61100000-0000-4000-8000-000000000002', 'display_order', 2,
        'source_kind', 'custom', 'source_boq_group_id', null,
        'source_boq_row_id', null, 'item_description', 'Flexible Connector',
        'brand_origin', null, 'requested_qty', '1', 'unit', 'Nos'
      )
    )
  ))$$,
  'Site Engineer creates a private request draft without an arrangement'
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'expected_version', 1
    ), '62000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Site Engineer submits the first request to Procurement'
);

select lives_ok(
  $$select public.v1_save_material_request_draft(jsonb_build_object(
    'request_id', '61000000-0000-4000-8000-000000000002',
    'expected_version', 0,
    'project_id', (select project_id from v1_b6_targets),
    'scope_id', (select scope_id from v1_b6_targets),
    'title', 'Competing request', 'timing', 'normal',
    'scheduled_date', null, 'delivery_note', null,
    'lines', jsonb_build_array(jsonb_build_object(
      'id', '61100000-0000-4000-8000-000000000003', 'display_order', 1,
      'source_kind', 'custom', 'source_boq_group_id', null,
      'source_boq_row_id', null, 'item_description', 'Duct Damper',
      'brand_origin', 'UAE', 'requested_qty', '2', 'unit', 'Nos'
    ))
  ))$$,
  'A second request can be submitted for the same warehouse item'
);

select lives_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000002',
      'expected_version', 1
    ), '62000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Competing request receives its own submitted record'
);

-- This Batch 6 suite retains its historical post-submit arrangement contract.
-- The approval-first path is covered by the dedicated revision suite.
set local role postgres;
update public.v1_material_requests
set state = 'submitted', current_action_owner_role = 'procurement',
    current_action_code = 'arrangement_required'
where id in (
  '61000000-0000-4000-8000-000000000001'::uuid,
  '61000000-0000-4000-8000-000000000002'::uuid
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
      'inventory_item_id', null, 'item_description', 'Duct Damper',
      'brand_origin', 'UAE', 'unit', 'Nos', 'quantity_delta', '5',
      'reason', 'Signed opening balance'
    ), '63000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement creates the minimal warehouse item through its stock command'
);

set local role postgres;
create temporary table v1_b6_inventory as
select id as inventory_item_id from public.v1_inventory_items
where item_description = 'Duct Damper' and brand_origin = 'UAE' and unit = 'Nos';
grant select on table v1_b6_inventory to authenticated;

set local role authenticated;
select throws_ok(
  $$select * from public.v1_inventory_reservations$$,
  '42501', null,
  'Procurement cannot bypass reservations with a direct table read'
);

select lives_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'expected_version', 2
    ), '64000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement explicitly starts the first arrangement version'
);

set local role postgres;
create temporary table v1_b6_arrangement_one as
select id as arrangement_id, record_version as arrangement_version
from public.v1_procurement_arrangements
where request_id = '61000000-0000-4000-8000-000000000001'::uuid
  and status = 'working';
create temporary table v1_b6_arrangement_one_lines as
select arrangement_line.id as arrangement_line_id, request_line.display_order
from public.v1_procurement_arrangement_lines arrangement_line
join public.v1_material_request_lines request_line
  on request_line.id = arrangement_line.request_line_id
where arrangement_line.arrangement_id = (select arrangement_id from v1_b6_arrangement_one);
grant select on table v1_b6_arrangement_one, v1_b6_arrangement_one_lines to authenticated;

set local role authenticated;
select throws_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 3, 'expected_arrangement_version', 1,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_one_lines where display_order = 1),
          'source_kind', 'warehouse', 'external_supplier', null,
          'inventory_item_id', (select inventory_item_id from v1_b6_inventory),
          'decision', 'partial', 'arranged_qty', '2', 'reason', null
        ),
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_one_lines where display_order = 2),
          'source_kind', 'external_supplier', 'external_supplier', null,
          'inventory_item_id', null, 'decision', 'full',
          'arranged_qty', '1', 'reason', null
        )
      )
    ), '64000000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023', 'V1_ARRANGEMENT_LINE_INVALID',
  'Partial arrangements require a reason'
);

select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 3, 'expected_arrangement_version', 1,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_one_lines where display_order = 1),
          'source_kind', 'warehouse', 'external_supplier', null,
          'inventory_item_id', (select inventory_item_id from v1_b6_inventory),
          'decision', 'partial', 'arranged_qty', '2', 'reason', 'Only two in stock'
        ),
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_one_lines where display_order = 2),
          'source_kind', 'external_supplier', 'external_supplier', null,
          'inventory_item_id', null, 'decision', 'full',
          'arranged_qty', '1', 'reason', null
        )
      )
    ), '64000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Procurement saves a Full external-supplier line without supplier name or reason'
);

set local role postgres;
select ok(
  (select state = 'awaiting_approval' and record_version = 4
    from public.v1_material_requests
    where id = '61000000-0000-4000-8000-000000000001'::uuid)
  and (select count(*) = 1 from public.v1_inventory_reservations
       where request_id = '61000000-0000-4000-8000-000000000001'::uuid
         and reserved_qty = 2 and state = 'active'),
  'Saving moves the request to review and creates exactly one warehouse reservation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_decide_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 4, 'expected_arrangement_version', 2,
      'decision', 'returned', 'reason', 'Need a replacement plan'
    ), '65000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_ARRANGEMENT_DECISION_DENIED',
  'A Site Engineer without Project Engineer membership cannot decide an arrangement'
);

-- A legacy or mistaken membership label must not grant a Site Engineer the
-- Project Engineer approval command. This is the real production boundary:
-- Site may create the MR, but the Project Engineer reviews Procurement's work.
set local role postgres;
update public.v1_project_members
   set project_role = 'project_engineer'
 where project_id = (select project_id from v1_b6_targets)
   and member_auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid
   and effective_to is null;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_decide_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 4, 'expected_arrangement_version', 2,
      'decision', 'returned', 'reason', 'Site Engineer must not approve'
    ), '65000000-0000-4000-8000-000000000010'::uuid
  )$$,
  '42501', 'V1_ARRANGEMENT_DECISION_DENIED',
  'A Site Engineer cannot approve even when a legacy membership says Project Engineer'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_decide_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 4, 'expected_arrangement_version', 2,
      'decision', 'approved', 'reason', null
    ), '65000000-0000-4000-8000-000000000002'::uuid
  )$$,
  '42501', 'V1_ARRANGEMENT_DECISION_DENIED',
  'Procurement cannot approve its own arrangement'
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
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_one),
      'expected_request_version', 4, 'expected_arrangement_version', 2,
      'decision', 'returned', 'reason', 'Need full warehouse quantity'
    ), '65000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Assigned Project Engineer returns the version with an immutable reason'
);

set local role postgres;
select ok(
  (select state = 'arranging' from public.v1_material_requests
    where id = '61000000-0000-4000-8000-000000000001'::uuid)
  and (select state = 'active' from public.v1_inventory_reservations
       where request_id = '61000000-0000-4000-8000-000000000001'::uuid),
  'A return routes work to Procurement but deliberately retains its reservation'
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
      'request_id', '61000000-0000-4000-8000-000000000001',
      'expected_version', 5
    ), '64000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Procurement starts a replacement version after the return'
);

set local role postgres;
create temporary table v1_b6_arrangement_two as
select id as arrangement_id, record_version as arrangement_version
from public.v1_procurement_arrangements
where request_id = '61000000-0000-4000-8000-000000000001'::uuid
  and status = 'working';
create temporary table v1_b6_arrangement_two_lines as
select arrangement_line.id as arrangement_line_id, request_line.display_order
from public.v1_procurement_arrangement_lines arrangement_line
join public.v1_material_request_lines request_line
  on request_line.id = arrangement_line.request_line_id
where arrangement_line.arrangement_id = (select arrangement_id from v1_b6_arrangement_two);
grant select on table v1_b6_arrangement_two, v1_b6_arrangement_two_lines to authenticated;

set local role authenticated;
select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_two),
      'expected_request_version', 6, 'expected_arrangement_version', 1,
      'lines', jsonb_build_array(
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_two_lines where display_order = 1),
          'source_kind', 'warehouse', 'external_supplier', null,
          'inventory_item_id', (select inventory_item_id from v1_b6_inventory),
          'decision', 'full', 'arranged_qty', '4', 'reason', null
        ),
        jsonb_build_object(
          'arrangement_line_id', (select arrangement_line_id
            from v1_b6_arrangement_two_lines where display_order = 2),
          'source_kind', 'external_supplier', 'external_supplier', 'External supplier',
          'inventory_item_id', null, 'decision', 'unavailable',
          'arranged_qty', '0', 'reason', 'Supplier confirmation pending'
        )
      )
    ), '64000000-0000-4000-8000-000000000005'::uuid
  )$$,
  'Replacement save atomically replaces the retained reservation'
);

select lives_ok(
  $$select public.v1_begin_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000002',
      'expected_version', 2
    ), '64000000-0000-4000-8000-000000000006'::uuid
  )$$,
  'Procurement starts the competing request arrangement'
);

set local role postgres;
create temporary table v1_b6_arrangement_competing as
select id as arrangement_id from public.v1_procurement_arrangements
where request_id = '61000000-0000-4000-8000-000000000002'::uuid
  and status = 'working';
create temporary table v1_b6_arrangement_competing_lines as
select id as arrangement_line_id from public.v1_procurement_arrangement_lines
where arrangement_id = (select arrangement_id from v1_b6_arrangement_competing);
grant select on table v1_b6_arrangement_competing, v1_b6_arrangement_competing_lines to authenticated;

set local role authenticated;
select throws_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000002',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_competing),
      'expected_request_version', 3, 'expected_arrangement_version', 1,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', (select arrangement_line_id
          from v1_b6_arrangement_competing_lines limit 1),
        'source_kind', 'warehouse', 'external_supplier', null,
        'inventory_item_id', (select inventory_item_id from v1_b6_inventory),
        'decision', 'full', 'arranged_qty', '2', 'reason', null
      ))
    ), '64000000-0000-4000-8000-000000000007'::uuid
  )$$,
  '22023', 'V1_INVENTORY_RESERVATION_EXCEEDS_AVAILABLE',
  'A competing request cannot over-reserve the final available warehouse quantity'
);

set local role postgres;
select ok(
  (select count(*) = 1 from public.v1_inventory_reservations
    where request_id = '61000000-0000-4000-8000-000000000001'::uuid
      and state = 'active' and reserved_qty = 4)
  and (select count(*) = 1 from public.v1_inventory_reservations
    where request_id = '61000000-0000-4000-8000-000000000001'::uuid
      and state = 'released' and reserved_qty = 2),
  'Replacement releases the old reservation once and leaves one new commitment'
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
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_two),
      'expected_request_version', 7, 'expected_arrangement_version', 2,
      'decision', 'approved', 'reason', null
    ), '65000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Project Engineer approves the replacement arrangement'
);

select lives_ok(
  $$select public.v1_decide_arrangement(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'arrangement_id', (select arrangement_id from v1_b6_arrangement_two),
      'expected_request_version', 7, 'expected_arrangement_version', 2,
      'decision', 'approved', 'reason', null
    ), '65000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A same-key approval retry returns its authoritative result'
);

set local role postgres;
select ok(
  (select state = 'approved' and record_version = 8
    from public.v1_material_requests
    where id = '61000000-0000-4000-8000-000000000001'::uuid)
  and (select approved_qty = 4 from public.v1_material_request_line_approvals
       where request_line_id = '61100000-0000-4000-8000-000000000001'::uuid)
  and (select approved_qty = 0 from public.v1_material_request_line_approvals
       where request_line_id = '61100000-0000-4000-8000-000000000002'::uuid),
  'Approval snapshots arranged quantities, including zero for unavailable lines'
);

select is(
  (select count(*) from public.v1_audit_events
    where event_type = 'arrangement_approved'
      and entity_id = (select arrangement_id from v1_b6_arrangement_two)),
  1::bigint,
  'Approval retry creates one append-only audit event'
);

set local role authenticated;
select lives_ok(
  $$select public.v1_cancel_material_request(
    jsonb_build_object(
      'request_id', '61000000-0000-4000-8000-000000000001',
      'expected_version', 8, 'reason', 'Approved scope withdrawn before dispatch'
    ), '66000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer can cancel an approved but undispatched request'
);

set local role postgres;
select ok(
  (select state = 'cancelled' from public.v1_material_requests
    where id = '61000000-0000-4000-8000-000000000001'::uuid)
  and not exists (
    select 1 from public.v1_inventory_reservations
    where request_id = '61000000-0000-4000-8000-000000000001'::uuid
      and state in ('active', 'partially_consumed')
  ),
  'Cancellation releases the live warehouse reservation exactly once'
);

select * from finish();
rollback;
