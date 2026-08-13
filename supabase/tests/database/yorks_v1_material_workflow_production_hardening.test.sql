begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_close_material_request(jsonb,uuid)', 'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_close_material_request(jsonb,uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.v1_can_close_material_request(uuid)', 'execute'
  ),
  'Closure is exposed only through the authenticated trusted command'
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
      "project_ref":"R35-HARD-001",
      "name":"Material workflow hardening",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Receipt reviewer"
      }],
      "buildings":[{"code":"hard","name":"Hardening Building"}],
      "attachments":[]
    }'::jsonb,
    'd0000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the hardening fixture project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects where project_ref = 'R35-HARD-001'
      ),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for workflow hardening tests'
    ),
    'd0000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The hardening fixture project is active'
);

set local role postgres;
create temporary table v1_hard_targets as
select project.id as project_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1
  ) as scope_id
from public.v1_projects project
where project.project_ref = 'R35-HARD-001';
grant select on table v1_hard_targets to authenticated;

insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, current_action_owner_role, current_action_code,
  submitted_at
) values
  (
    'd1000000-0000-4000-8000-000000000001',
    (select project_id from v1_hard_targets),
    (select scope_id from v1_hard_targets),
    'R35-HARD-001-MR001', 'Commercial arrangement', 'normal', 'arranging',
    1, '10000000-0000-4000-8000-000000000001',
    'Local Project Engineer', 'project_engineer', 'procurement',
    'arrangement_required', clock_timestamp()
  ),
  (
    'd1000000-0000-4000-8000-000000000002',
    (select project_id from v1_hard_targets),
    (select scope_id from v1_hard_targets),
    'R35-HARD-001-MR002', 'Unavailable arrangement', 'normal',
    'awaiting_approval', 1,
    '10000000-0000-4000-8000-000000000001',
    'Local Project Engineer', 'project_engineer', 'project_engineer',
    'arrangement_review_required', clock_timestamp()
  ),
  (
    'd1000000-0000-4000-8000-000000000003',
    (select project_id from v1_hard_targets),
    (select scope_id from v1_hard_targets),
    'R35-HARD-001-MR003', 'Received request closure', 'normal', 'received',
    1, '10000000-0000-4000-8000-000000000001',
    'Local Project Engineer', 'project_engineer', 'project_engineer',
    'material_request_close_review', clock_timestamp()
  );

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values
  ('d1100000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001', 1, 'custom',
    'Commercial damper', 2, 'Nos'),
  ('d1100000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000002', 1, 'custom',
    'Unavailable damper', 1, 'Nos'),
  ('d1100000-0000-4000-8000-000000000003',
    'd1000000-0000-4000-8000-000000000003', 1, 'custom',
    'Received damper', 1, 'Nos');

insert into public.v1_material_request_line_commercials (
  request_line_id, unit_cost, currency_code
) values ('d1100000-0000-4000-8000-000000000001', 25, 'AED');

insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current,
  started_by_auth_user_id, saved_by_auth_user_id, saved_at
) values
  ('d1200000-0000-4000-8000-000000000001',
    'd1000000-0000-4000-8000-000000000001', 1, 'working', false,
    '10000000-0000-4000-8000-000000000003', null, null),
  ('d1200000-0000-4000-8000-000000000002',
    'd1000000-0000-4000-8000-000000000002', 1, 'awaiting_approval', true,
    '10000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000003', clock_timestamp()),
  ('d1200000-0000-4000-8000-000000000003',
    'd1000000-0000-4000-8000-000000000003', 1, 'approved', true,
    '10000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000003', clock_timestamp());

insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, external_supplier,
  decision, arranged_qty, unit_cost
) values
  ('d1300000-0000-4000-8000-000000000001',
    'd1200000-0000-4000-8000-000000000001',
    'd1100000-0000-4000-8000-000000000001', 'external_supplier',
    'Approved Supplier', 'full', 2, 25),
  ('d1300000-0000-4000-8000-000000000002',
    'd1200000-0000-4000-8000-000000000002',
    'd1100000-0000-4000-8000-000000000002', null, null,
    'unavailable', 0, null),
  ('d1300000-0000-4000-8000-000000000003',
    'd1200000-0000-4000-8000-000000000003',
    'd1100000-0000-4000-8000-000000000003', 'external_supplier',
    'Approved Supplier', 'full', 1, null);

insert into public.v1_material_request_line_approvals (
  request_line_id, arrangement_line_id, arrangement_id, approved_qty,
  approved_by_auth_user_id
) values (
  'd1100000-0000-4000-8000-000000000003',
  'd1300000-0000-4000-8000-000000000003',
  'd1200000-0000-4000-8000-000000000003', 1,
  '10000000-0000-4000-8000-000000000001'
);

insert into public.v1_material_dispatches (
  id, request_id, project_id, dispatch_number, dispatch_date,
  delivery_reference, state, dispatched_by_auth_user_id, dispatched_by_role
) values (
  'd1400000-0000-4000-8000-000000000003',
  'd1000000-0000-4000-8000-000000000003',
  (select project_id from v1_hard_targets), 'R35-HARD-001-DSP001',
  current_date, 'DN-HARD-001', 'received',
  '10000000-0000-4000-8000-000000000003', 'procurement'
);
insert into public.v1_material_dispatch_lines (
  id, dispatch_id, request_line_id, arrangement_line_id, source_kind,
  external_supplier, item_description, unit, approved_qty_snapshot,
  dispatched_qty
) values (
  'd1500000-0000-4000-8000-000000000003',
  'd1400000-0000-4000-8000-000000000003',
  'd1100000-0000-4000-8000-000000000003',
  'd1300000-0000-4000-8000-000000000003', 'external_supplier',
  'Approved Supplier', 'Received damper', 'Nos', 1, 1
);
insert into public.v1_receipt_reviews (
  id, dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
) values (
  'd1600000-0000-4000-8000-000000000003',
  'd1400000-0000-4000-8000-000000000003',
  'd1000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000001', 'project_engineer'
);
insert into public.v1_receipt_review_lines (
  receipt_review_id, dispatch_line_id, outcome, dispatched_qty_snapshot,
  good_qty, exception_qty
) values (
  'd1600000-0000-4000-8000-000000000003',
  'd1500000-0000-4000-8000-000000000003', 'received', 1, 1, 0
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select ok(
  public.v1_arrangement_projection(
    'd1000000-0000-4000-8000-000000000001'
  ) -> 'arrangements' -> 0 -> 'lines' -> 0 ? 'unit_cost',
  'A caller with view_commercials receives the arrangement cost key'
);
select ok(
  public.v1_material_request_document_projection(
    'd1000000-0000-4000-8000-000000000001'
  ) -> 'request' -> 'lines' -> 0 ? 'unit_cost',
  'A caller with view_commercials receives commercial controlled output'
);

set local role postgres;
insert into public.v1_user_capabilities (
  auth_user_id, capability, is_granted, reason, changed_by_auth_user_id
) values
  ('10000000-0000-4000-8000-000000000003', 'view_commercials', false,
    'Hardening revocation proof', '10000000-0000-4000-8000-000000000004'),
  ('10000000-0000-4000-8000-000000000003', 'manage_commercials', false,
    'Hardening revocation proof', '10000000-0000-4000-8000-000000000004')
on conflict (auth_user_id, capability) do update set
  is_granted = excluded.is_granted,
  reason = excluded.reason,
  changed_by_auth_user_id = excluded.changed_by_auth_user_id;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select ok(
  not (
    public.v1_arrangement_projection(
      'd1000000-0000-4000-8000-000000000001'
    ) -> 'arrangements' -> 0 ? 'procurement_note'
  ) and not (
    public.v1_arrangement_projection(
      'd1000000-0000-4000-8000-000000000001'
    ) -> 'arrangements' -> 0 -> 'lines' -> 0 ? 'unit_cost'
  ),
  'A revoked arrangement response omits commercial keys entirely'
);
select ok(
  not (
    public.v1_material_request_document_projection(
      'd1000000-0000-4000-8000-000000000001'
    ) -> 'request' -> 'lines' -> 0 ? 'unit_cost'
  ),
  'A revoked controlled document omits commercial keys entirely'
);

select throws_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', 'd1000000-0000-4000-8000-000000000001',
      'arrangement_id', 'd1200000-0000-4000-8000-000000000001',
      'expected_request_version', 1,
      'expected_arrangement_version', 1,
      'procurement_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', 'd1300000-0000-4000-8000-000000000001',
        'source_kind', 'external_supplier',
        'external_supplier', 'Approved Supplier',
        'inventory_item_id', null,
        'decision', 'full',
        'arranged_qty', '2',
        'reason', null,
        'unit_cost', '30'
      ))
    ), 'd2000000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_ARRANGEMENT_COMMERCIAL_WRITE_DENIED',
  'A caller without manage_commercials cannot write arrangement cost'
);

select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_build_object(
      'request_id', 'd1000000-0000-4000-8000-000000000001',
      'arrangement_id', 'd1200000-0000-4000-8000-000000000001',
      'expected_request_version', 1,
      'expected_arrangement_version', 1,
      'procurement_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'arrangement_line_id', 'd1300000-0000-4000-8000-000000000001',
        'source_kind', 'external_supplier',
        'external_supplier', 'Approved Supplier',
        'inventory_item_id', null,
        'decision', 'full',
        'arranged_qty', '2',
        'reason', null,
        'unit_cost', null
      ))
    ), 'd2000000-0000-4000-8000-000000000002'
  )$$,
  'A non-commercial operational save remains available'
);

set local role postgres;
select is(
  (select unit_cost::text from public.v1_procurement_arrangement_lines
    where id = 'd1300000-0000-4000-8000-000000000001'),
  '25.0000',
  'A non-commercial save preserves the protected existing cost'
);
select ok(
  (
    select count(*) >= 2
    from public.v1_notifications notification
    join auth.users auth_user on auth_user.id = notification.recipient_auth_user_id
    where notification.entity_id = 'd1200000-0000-4000-8000-000000000001'
      and notification.event_code = 'arrangement_review_required'
      and auth_user.raw_app_meta_data ->> 'role' in (
        'senior_mechanical_engineer', 'project_manager'
      )
  ),
  'Arrangement review notification expansion reaches both global engineers'
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
      'request_id', 'd1000000-0000-4000-8000-000000000002',
      'arrangement_id', 'd1200000-0000-4000-8000-000000000002',
      'expected_request_version', 1,
      'expected_arrangement_version', 1,
      'decision', 'approved',
      'reason', null
    ), 'd2000000-0000-4000-8000-000000000003'
  )$$,
  'Project Engineer acknowledges an all-unavailable arrangement'
);

set local role postgres;
select ok(
  (
    select state = 'closed'
      and current_action_code = 'unavailable_closed'
      and cancelled_at is null
      and cancelled_by_auth_user_id is null
      and cancellation_reason is null
    from public.v1_material_requests
    where id = 'd1000000-0000-4000-8000-000000000002'
  ),
  'All-unavailable approval closes without fabricating cancellation facts'
);
select is(
  (
    select after_data ->> 'request_state'
    from public.v1_audit_events
    where entity_id = 'd1200000-0000-4000-8000-000000000002'
      and event_type = 'arrangement_approved'
    order by occurred_at desc limit 1
  ),
  'closed',
  'All-unavailable approval audit records the actual closed state'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
set local role postgres;
select ok(
  public.v1_can_close_material_request(
    'd1000000-0000-4000-8000-000000000003'
  ),
  'An active assigned Project Engineer is authorized to close'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select ok(
  public.v1_can_close_material_request(
    'd1000000-0000-4000-8000-000000000003'
  ),
  'An active assigned Site Engineer is authorized to close'
);
update public.v1_project_members
set effective_to = clock_timestamp(),
    revoked_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    revoked_by_role = 'admin',
    revoked_reason = 'Closure membership boundary proof'
where project_id = (select project_id from v1_hard_targets)
  and member_auth_user_id = '10000000-0000-4000-8000-000000000002'
  and project_role = 'site_engineer'
  and effective_to is null;
select ok(
  not public.v1_can_close_material_request(
    'd1000000-0000-4000-8000-000000000003'
  ),
  'An inactive Site Engineer membership is not authorized to close'
);
update public.v1_project_members
set effective_to = null,
    revoked_by_auth_user_id = null,
    revoked_by_role = null,
    revoked_reason = null
where project_id = (select project_id from v1_hard_targets)
  and member_auth_user_id = '10000000-0000-4000-8000-000000000002'
  and project_role = 'site_engineer';

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select ok(
  not public.v1_can_close_material_request(
    'd1000000-0000-4000-8000-000000000003'
  ),
  'Procurement is not authorized to close'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select ok(
  public.v1_can_close_material_request(
    'd1000000-0000-4000-8000-000000000003'
  ),
  'An active Admin is authorized to close'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_close_material_request(
    '{"request_id":"d1000000-0000-4000-8000-000000000003","expected_version":1}'::jsonb,
    'd2000000-0000-4000-8000-000000000004'
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_CLOSE_DENIED',
  'Procurement cannot close the request'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_close_material_request(
    '{"request_id":"d1000000-0000-4000-8000-000000000003","expected_version":1}'::jsonb,
    'd2000000-0000-4000-8000-000000000005'
  )$$,
  'An assigned Site Engineer closes a fully received request'
);
select is(
  public.v1_material_request_projection(
    'd1000000-0000-4000-8000-000000000003'
  ) ->> 'state',
  'closed',
  'The closure response is server-confirmed as closed'
);
select lives_ok(
  $$select public.v1_close_material_request(
    '{"request_id":"d1000000-0000-4000-8000-000000000003","expected_version":1}'::jsonb,
    'd2000000-0000-4000-8000-000000000005'
  )$$,
  'Retrying closure with the same key returns the completed response'
);
set local role postgres;
select is(
  (
    select count(*)::integer from public.v1_audit_events
    where entity_id = 'd1000000-0000-4000-8000-000000000003'
      and event_type = 'material_request_closed'
  ),
  1,
  'Idempotent closure writes one audit event'
);

select * from finish();
rollback;
