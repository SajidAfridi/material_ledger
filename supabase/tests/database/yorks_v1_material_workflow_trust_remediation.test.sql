begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(20);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"R35-TRUST-001",
      "name":"Immutable material trust fixture",
      "job_contract_reference":"JOB-TRUST-001",
      "parties":{"main_contractor":{"name":"Original Contractor"}},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Receipt review fixture"
      }],
      "buildings":[{"code":"trust","name":"Original Building"}],
      "attachments":[]
    }'::jsonb,
    'e0000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the trust fixture project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects where project_ref = 'R35-TRUST-001'
      ),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for workflow trust tests'
    ),
    'e0000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The trust fixture project is active'
);

set local role postgres;
create temporary table v1_trust_targets as
select project.id as project_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1
  ) as scope_id
from public.v1_projects project
where project.project_ref = 'R35-TRUST-001';
grant select on table v1_trust_targets to authenticated;

insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code
) values (
  'e1000000-0000-4000-8000-000000000001',
  (select project_id from v1_trust_targets),
  (select scope_id from v1_trust_targets),
  null, 'Trust fixture material', 'normal', 'draft',
  1, '10000000-0000-4000-8000-000000000009',
  'Local Senior Mechanical Engineer', 'project_engineer',
  'senior_mechanical_engineer', 'project_engineer', 'draft_owner'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
update public.v1_material_requests
set request_number = 'R35-TRUST-001-MR001',
    state = 'approved',
    current_action_owner_role = 'procurement',
    current_action_code = 'dispatch_required',
    submitted_at = clock_timestamp()
where id = 'e1000000-0000-4000-8000-000000000001';

select ok(
  (select document_identity_verified
   from public.v1_material_requests
   where id = 'e1000000-0000-4000-8000-000000000001')
  and (select document_identity_snapshot ->> 'project_name'
       from public.v1_material_requests
       where id = 'e1000000-0000-4000-8000-000000000001')
      = 'Immutable material trust fixture',
  'Submission captures a verified immutable Material Request identity'
);

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values (
  'e1100000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001', 1, 'custom',
  'Trust damper', 10, 'Nos'
);
insert into public.v1_material_request_line_commercials (
  request_line_id, unit_cost, currency_code
) values ('e1100000-0000-4000-8000-000000000001', 100, 'AED');

insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current,
  started_by_auth_user_id
) values (
  'e1200000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001', 1, 'working', false,
  '10000000-0000-4000-8000-000000000003'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
update public.v1_procurement_arrangements
set status = 'approved', is_current = true,
    saved_at = clock_timestamp(),
    saved_by_auth_user_id = '10000000-0000-4000-8000-000000000003'
where id = 'e1200000-0000-4000-8000-000000000001';

select ok(
  (select saved_by_exact_role = 'procurement'
      and saved_by_display_name_snapshot = 'Local Procurement'
   from public.v1_procurement_arrangements
   where id = 'e1200000-0000-4000-8000-000000000001'),
  'Arrangement save snapshots Procurement identity'
);

insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, external_supplier,
  decision, arranged_qty, unit_cost
) values (
  'e1300000-0000-4000-8000-000000000001',
  'e1200000-0000-4000-8000-000000000001',
  'e1100000-0000-4000-8000-000000000001', 'external_supplier',
  'Trusted Supplier', 'full', 10, 100
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
insert into public.v1_arrangement_decisions (
  id, arrangement_id, request_id, decision,
  decided_by_auth_user_id, decided_by_role
) values (
  'e1400000-0000-4000-8000-000000000001',
  'e1200000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001', 'approved',
  '10000000-0000-4000-8000-000000000009', 'project_engineer'
);
insert into public.v1_material_request_line_approvals (
  request_line_id, arrangement_line_id, arrangement_id, approved_qty,
  approved_by_auth_user_id
) values (
  'e1100000-0000-4000-8000-000000000001',
  'e1300000-0000-4000-8000-000000000001',
  'e1200000-0000-4000-8000-000000000001', 10,
  '10000000-0000-4000-8000-000000000009'
);

select ok(
  (select decided_by_exact_role = 'senior_mechanical_engineer'
      and decided_by_display_name_snapshot = 'Local Senior Mechanical Engineer'
   from public.v1_arrangement_decisions
   where id = 'e1400000-0000-4000-8000-000000000001'),
  'Approval preserves the exact Senior Mechanical Engineer role and name'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
insert into public.v1_material_dispatches (
  id, request_id, project_id, dispatch_number, dispatch_date,
  delivery_reference, state, dispatched_by_auth_user_id, dispatched_by_role
) values
  ('e1500000-0000-4000-8000-000000000001',
    'e1000000-0000-4000-8000-000000000001',
    (select project_id from v1_trust_targets), 'R35-TRUST-001-DSP001',
    current_date, 'DN-TRUST-001', 'received',
    '10000000-0000-4000-8000-000000000003', 'procurement'),
  ('e1500000-0000-4000-8000-000000000002',
    'e1000000-0000-4000-8000-000000000001',
    (select project_id from v1_trust_targets), 'R35-TRUST-001-DSP002',
    current_date, 'DN-TRUST-002', 'receipt_pending',
    '10000000-0000-4000-8000-000000000003', 'procurement');

select ok(
  (select bool_and(dispatched_by_exact_role = 'procurement'
      and dispatched_by_display_name_snapshot = 'Local Procurement')
   from public.v1_material_dispatches
   where request_id = 'e1000000-0000-4000-8000-000000000001'),
  'Every dispatch snapshots the exact Procurement identity'
);

insert into public.v1_material_dispatch_lines (
  id, dispatch_id, request_line_id, arrangement_line_id, source_kind,
  external_supplier, item_description, unit, approved_qty_snapshot,
  dispatched_qty
) values
  ('e1600000-0000-4000-8000-000000000001',
    'e1500000-0000-4000-8000-000000000001',
    'e1100000-0000-4000-8000-000000000001',
    'e1300000-0000-4000-8000-000000000001', 'external_supplier',
    'Trusted Supplier', 'Trust damper', 'Nos', 10, 5),
  ('e1600000-0000-4000-8000-000000000002',
    'e1500000-0000-4000-8000-000000000002',
    'e1100000-0000-4000-8000-000000000001',
    'e1300000-0000-4000-8000-000000000001', 'external_supplier',
    'Trusted Supplier', 'Trust damper', 'Nos', 10, 4);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
insert into public.v1_receipt_reviews (
  id, dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
) values (
  'e1700000-0000-4000-8000-000000000001',
  'e1500000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000010', 'project_engineer'
);
insert into public.v1_receipt_review_lines (
  id, receipt_review_id, dispatch_line_id, outcome,
  dispatched_qty_snapshot, good_qty, exception_qty,
  missing_qty, damaged_qty, note
) values (
  'e1800000-0000-4000-8000-000000000001',
  'e1700000-0000-4000-8000-000000000001',
  'e1600000-0000-4000-8000-000000000001', 'missing', 5, 3, 2, 2, 0,
  'Two units were missing at site'
);

select ok(
  (select reviewed_by_exact_role = 'project_manager'
      and reviewed_by_display_name_snapshot = 'Local Project Manager'
   from public.v1_receipt_reviews
   where id = 'e1700000-0000-4000-8000-000000000001'),
  'Receipt review preserves the exact Project Manager role and name'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);

select ok(
  (public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) -> 'line_lifecycle') @> '[{
    "request_line_id":"e1100000-0000-4000-8000-000000000001",
    "requested_qty":"10.0000",
    "arranged_qty":"10.0000",
    "approved_qty":"10.0000",
    "dispatched_qty":"9.0000",
    "in_transit_qty":"4.0000",
    "reviewed_good_qty":"3.0000",
    "reviewed_missing_qty":"2.0000",
    "reviewed_damaged_qty":"0.0000",
    "remaining_approved_qty":"3.0000",
    "replacement_eligible_qty":"2.0000",
    "ordinary_outstanding_qty":"1.0000",
    "status":"Awaiting receipt review"
  }]'::jsonb,
  'Canonical lifecycle separates good, exception, transit, replacement and ordinary remainder'
);

select ok(
  public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{approval,role}' = 'senior_mechanical_engineer'
  and public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{dispatch,role}' = 'procurement',
  'Material Request controlled projection preserves exact workflow roles'
);

select ok(
  public.v1_arrangement_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{arrangements,0,decided_by_role}' = 'senior_mechanical_engineer',
  'Arrangement workspace preserves the exact approver role'
);

select ok(
  public.v1_logistics_workspace_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{dispatches,1,dispatched_by_role}' = 'procurement'
  and public.v1_logistics_workspace_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{dispatches,1,receipt_review,reviewed_by_role}' = 'project_manager'
  and public.v1_logistics_workspace_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{dispatches,1,delivery_reference}' = 'DN-TRUST-001',
  'Logistics workspace exposes immutable dispatch reference and exact actor roles'
);

set local role postgres;
insert into public.v1_delivery_orders (
  id, request_id, dispatch_id, project_id, delivery_order_reference,
  created_by_auth_user_id, created_by_role
) values (
  'e1900000-0000-4000-8000-000000000001',
  'e1000000-0000-4000-8000-000000000001',
  'e1500000-0000-4000-8000-000000000001',
  (select project_id from v1_trust_targets), 'R35-TRUST-DO-001',
  '10000000-0000-4000-8000-000000000009', 'project_engineer'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
insert into public.v1_delivery_order_revisions (
  id, delivery_order_id, receipt_review_id, revision_number,
  generated_by_auth_user_id, generated_by_role, snapshot_kind
) values (
  'e2000000-0000-4000-8000-000000000001',
  'e1900000-0000-4000-8000-000000000001', null, 1,
  '10000000-0000-4000-8000-000000000009', 'project_engineer', 'dispatch'
);
insert into public.v1_delivery_order_revision_lines (
  id, delivery_order_revision_id, receipt_review_line_id, dispatch_line_id,
  display_order, item_description, good_quantity, delivery_quantity, unit
) values (
  'e2100000-0000-4000-8000-000000000001',
  'e2000000-0000-4000-8000-000000000001', null,
  'e1600000-0000-4000-8000-000000000001', 1,
  'Trust damper', 5, 5, 'Nos'
);
update public.v1_delivery_orders
set current_revision_id = 'e2000000-0000-4000-8000-000000000001'
where id = 'e1900000-0000-4000-8000-000000000001';

select ok(
  (select document_identity_verified
      and generated_by_exact_role = 'senior_mechanical_engineer'
      and generated_by_display_name_snapshot = 'Local Senior Mechanical Engineer'
   from public.v1_delivery_order_revisions
   where id = 'e2000000-0000-4000-8000-000000000001'),
  'Delivery Order revision snapshots generator identity and exact role'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select public.v1_write_audit_event(
  'trust_projection_checked', 'material_request',
  'e1000000-0000-4000-8000-000000000001',
  (select project_id from v1_trust_targets), null, '{}'::jsonb, null,
  'e2200000-0000-4000-8000-000000000001'
);

update public.v1_projects
set name = 'Changed live project name'
where id = (select project_id from v1_trust_targets);
update public.v1_profiles
set display_name = case auth_user_id
  when '10000000-0000-4000-8000-000000000003' then 'Changed Procurement'
  when '10000000-0000-4000-8000-000000000009' then 'Changed Senior Engineer'
  else display_name end
where auth_user_id in (
  '10000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000009'
);

set local role authenticated;
select ok(
  public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{request,project_name}' = 'Immutable material trust fixture'
  and public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{arrangement,display_name}' = 'Local Procurement'
  and public.v1_material_request_document_projection(
    'e1000000-0000-4000-8000-000000000001'
  ) #>> '{approval,display_name}' = 'Local Senior Mechanical Engineer',
  'Material Request rendering does not rewrite snapshotted project or actor identity'
);

select ok(
  public.v1_delivery_order_projection(
    'e1900000-0000-4000-8000-000000000001'
  ) #>> '{revisions,0,document_identity,project_name}'
    = 'Immutable material trust fixture'
  and public.v1_delivery_order_projection(
    'e1900000-0000-4000-8000-000000000001'
  ) #>> '{revisions,0,generated_by_display_name}'
    = 'Local Senior Mechanical Engineer',
  'Delivery Order rendering preserves its immutable revision identity'
);

select ok(
  not (
    public.v1_material_request_document_projection(
      'e1000000-0000-4000-8000-000000000001'
    ) #> '{request,lines,0}' ? 'unit_cost'
  ),
  'Senior Mechanical Engineer controlled output contains no commercial key'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
set local role postgres;
select ok(
  public.v1_can_close_material_request(
    'e1000000-0000-4000-8000-000000000001'
  ),
  'An active assigned Site Engineer passes close authority; the command still validates state'
);

set local role postgres;
insert into public.v1_notifications (
  recipient_auth_user_id, event_code, entity_type, entity_id, project_id
) values (
  '10000000-0000-4000-8000-000000000002', 'trust_test',
  'material_request', 'e1000000-0000-4000-8000-000000000001',
  (select project_id from v1_trust_targets)
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-project-manager"}}',
  true
);
select is(
  (select count(*)::integer from public.v1_notifications
   where event_code = 'trust_test'),
  0,
  'A stale forged Admin JWT cannot read another recipient notification'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (select count(*)::integer from public.v1_notifications
   where event_code = 'trust_test'),
  1,
  'The active notification recipient retains positive RLS access'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select ok(
  public.v1_project_audit_projection(
    (select project_id from v1_trust_targets)
  ) @> '[{
    "event_type":"trust_projection_checked",
    "actor_display_name":"Local Senior Mechanical Engineer",
    "actor_identity_verified":true,
    "actor_role":"senior_mechanical_engineer"
  }]'::jsonb,
  'Audit projection keeps immutable actor name and exact role'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_material_request_line_lifecycle_projection(uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_capture_delivery_order_revision_identity()',
    'execute'
  ),
  'Internal lifecycle and snapshot helpers are not exposed as client RPCs'
);

select * from finish();
rollback;
