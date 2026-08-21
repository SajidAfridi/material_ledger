begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(33);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_configuration_settings', 'update'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_procurement_arrangement_lines', 'update'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_material_requests', 'insert'
  ),
  'Phase 3 policy, evidence and replacement records remain command-only'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_material_request_phase3_policy_projection(uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_create_replacement_material_request(jsonb,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_material_request_published_policy_boolean(text,boolean)',
    'execute'
  ),
  'Only the protected Phase 3 client commands are executable by users'
);

select is(
  (select published_value from public.v1_configuration_settings
    where setting_key = 'requests.allow_authorized_creator_self_approval'),
  'true'::jsonb,
  'Authorized creator self-approval starts enabled for adoption'
);

select is(
  (select published_value from public.v1_configuration_settings
    where setting_key = 'procurement.require_external_source_readiness'),
  'false'::jsonb,
  'External readiness starts advisory rather than blocking'
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
      "project_ref":"MR-PH3-001",
      "name":"Phase 3 policy proof",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"ph3","name":"Phase 3 Building"}],
      "attachments":[]
    }'::jsonb,
    'b3000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the Phase 3 fixture project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-PH3-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for Phase 3 proof'
    ),
    'b3000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Phase 3 fixture project is activated'
);

set local role postgres;
create temporary table v1_ph3_targets as
select project.id as project_id,
  (select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'MR-PH3-001';
grant select on table v1_ph3_targets to authenticated;

insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code, submitted_at, cancelled_at,
  cancelled_by_auth_user_id, cancellation_reason, created_at, updated_at
) values
(
  'b3100000-0000-4000-8000-000000000001',
  (select project_id from v1_ph3_targets),
  (select scope_id from v1_ph3_targets),
  'MR-PH3-001-MR001', 'Creator approval policy', 'normal',
  'awaiting_request_approval', 1,
  '10000000-0000-4000-8000-000000000001', 'Local Project Engineer',
  'project_engineer', 'project_engineer', 'project_engineer',
  'request_approval_required', clock_timestamp(), null, null, null,
  clock_timestamp(),
  clock_timestamp()
),
(
  'b3100000-0000-4000-8000-000000000002',
  (select project_id from v1_ph3_targets),
  (select scope_id from v1_ph3_targets),
  'MR-PH3-001-MR002', 'Advisory external readiness', 'normal',
  'arranging', 2,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'procurement',
  'arrangement_in_progress', clock_timestamp(), null, null, null,
  clock_timestamp(),
  clock_timestamp()
),
(
  'b3100000-0000-4000-8000-000000000003',
  (select project_id from v1_ph3_targets),
  (select scope_id from v1_ph3_targets),
  'MR-PH3-001-MR003', 'Enforced external readiness', 'normal',
  'arranging', 2,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'procurement',
  'arrangement_in_progress', clock_timestamp(), null, null, null,
  clock_timestamp(),
  clock_timestamp()
),
(
  'b3100000-0000-4000-8000-000000000004',
  (select project_id from v1_ph3_targets),
  (select scope_id from v1_ph3_targets),
  'MR-PH3-001-MR004', 'Cancelled unavailable request', 'normal',
  'cancelled', 5,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'none', 'cancelled',
  clock_timestamp(), clock_timestamp(),
  '10000000-0000-4000-8000-000000000010',
  'Replacement requested after all items were unavailable',
  clock_timestamp(), clock_timestamp()
),
(
  'b3100000-0000-4000-8000-000000000005',
  (select project_id from v1_ph3_targets),
  (select scope_id from v1_ph3_targets),
  'MR-PH3-001-MR005', 'Admin replacement request', 'normal',
  'cancelled', 5,
  '10000000-0000-4000-8000-000000000002', 'Local Site Engineer',
  'site_engineer', 'site_engineer', 'none', 'cancelled',
  clock_timestamp(), clock_timestamp(),
  '10000000-0000-4000-8000-000000000004',
  'Admin is preparing an Engineering replacement',
  clock_timestamp(), clock_timestamp()
);

insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values
  ('b3110000-0000-4000-8000-000000000001',
    'b3100000-0000-4000-8000-000000000001', 1, 'custom',
    'Creator policy item', 1, 'Nos'),
  ('b3110000-0000-4000-8000-000000000002',
    'b3100000-0000-4000-8000-000000000002', 1, 'custom',
    'Advisory supplier item', 2, 'Nos'),
  ('b3110000-0000-4000-8000-000000000003',
    'b3100000-0000-4000-8000-000000000003', 1, 'custom',
    'Enforced supplier item', 3, 'Nos'),
  ('b3110000-0000-4000-8000-000000000004',
    'b3100000-0000-4000-8000-000000000004', 1, 'custom',
    'Unavailable replacement item', 4, 'Nos'),
  ('b3110000-0000-4000-8000-000000000005',
    'b3100000-0000-4000-8000-000000000005', 1, 'custom',
    'Admin replacement item', 2, 'Nos');

insert into public.v1_material_request_decisions (
  id, request_id, request_record_version, decision, reason,
  decided_by_auth_user_id, decided_by_role, decided_by_exact_role,
  decided_by_display_name_snapshot, created_at
) values
  ('b3120000-0000-4000-8000-000000000002',
    'b3100000-0000-4000-8000-000000000002', 1, 'approved', null,
    '10000000-0000-4000-8000-000000000001', 'project_engineer',
    'project_engineer', 'Local Project Engineer', clock_timestamp()),
  ('b3120000-0000-4000-8000-000000000003',
    'b3100000-0000-4000-8000-000000000003', 1, 'approved', null,
    '10000000-0000-4000-8000-000000000001', 'project_engineer',
    'project_engineer', 'Local Project Engineer', clock_timestamp());

insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current, record_version,
  started_by_auth_user_id, started_at, created_at, updated_at
) values
  ('b3130000-0000-4000-8000-000000000002',
    'b3100000-0000-4000-8000-000000000002', 1, 'working', false, 1,
    '10000000-0000-4000-8000-000000000003', clock_timestamp(),
    clock_timestamp(), clock_timestamp()),
  ('b3130000-0000-4000-8000-000000000003',
    'b3100000-0000-4000-8000-000000000003', 1, 'working', false, 1,
    '10000000-0000-4000-8000-000000000003', clock_timestamp(),
    clock_timestamp(), clock_timestamp());

insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current, record_version,
  started_by_auth_user_id, started_at, saved_at, saved_by_auth_user_id,
  created_at, updated_at
) values (
  'b3130000-0000-4000-8000-000000000004',
  'b3100000-0000-4000-8000-000000000004', 1, 'cancelled', false, 2,
  '10000000-0000-4000-8000-000000000003', clock_timestamp(),
  clock_timestamp(), '10000000-0000-4000-8000-000000000003',
  clock_timestamp(), clock_timestamp()
), (
  'b3130000-0000-4000-8000-000000000005',
  'b3100000-0000-4000-8000-000000000005', 1, 'cancelled', false, 2,
  '10000000-0000-4000-8000-000000000003', clock_timestamp(),
  clock_timestamp(), '10000000-0000-4000-8000-000000000003',
  clock_timestamp(), clock_timestamp()
);

insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, external_supplier,
  decision, arranged_qty, reason, created_at, updated_at
) values
  ('b3140000-0000-4000-8000-000000000002',
    'b3130000-0000-4000-8000-000000000002',
    'b3110000-0000-4000-8000-000000000002', 'external_supplier', null,
    null, null, null, clock_timestamp(), clock_timestamp()),
  ('b3140000-0000-4000-8000-000000000003',
    'b3130000-0000-4000-8000-000000000003',
    'b3110000-0000-4000-8000-000000000003', 'external_supplier', null,
    null, null, null, clock_timestamp(), clock_timestamp()),
  ('b3140000-0000-4000-8000-000000000004',
    'b3130000-0000-4000-8000-000000000004',
    'b3110000-0000-4000-8000-000000000004', 'external_supplier', null,
    'unavailable', 0, 'Not available', clock_timestamp(), clock_timestamp()),
  ('b3140000-0000-4000-8000-000000000005',
    'b3130000-0000-4000-8000-000000000005',
    'b3110000-0000-4000-8000-000000000005', 'external_supplier', null,
    'unavailable', 0, 'Not available', clock_timestamp(), clock_timestamp());

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

set local role postgres;
select ok(
  public.v1_can_decide_material_request(
    'b3100000-0000-4000-8000-000000000001'
  ),
  'An independently authorized Project Engineer creator may self-approve by default'
);

set local role authenticated;
select is(
  (public.v1_material_request_phase3_policy_projection(
    'b3100000-0000-4000-8000-000000000001'
  ) ->> 'allow_authorized_creator_self_approval')::boolean,
  true,
  'The role-safe request policy exposes the published self-approval rule'
);

set local role postgres;
update public.v1_configuration_settings
set published_value = 'false'::jsonb
where setting_key = 'requests.allow_authorized_creator_self_approval';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
set local role postgres;
select is(
  public.v1_can_decide_material_request(
    'b3100000-0000-4000-8000-000000000001'
  ),
  false,
  'Published separation-of-duties enforcement blocks the creator'
);
set local role authenticated;
select throws_ok(
  $$select public.v1_decide_material_request(
    '{"request_id":"b3100000-0000-4000-8000-000000000001","expected_version":1,"decision":"approved","reason":null}'::jsonb,
    'b3200000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_DECISION_DENIED',
  'The trusted approval command enforces the published self-approval rule'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
set local role postgres;
select ok(
  public.v1_can_decide_material_request(
    'b3100000-0000-4000-8000-000000000001'
  ),
  'An organization-wide engineering manager remains an independent approver'
);
set local role authenticated;
select lives_ok(
  $$select public.v1_decide_material_request(
    '{"request_id":"b3100000-0000-4000-8000-000000000001","expected_version":1,"decision":"approved","reason":null}'::jsonb,
    'b3200000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The independent Project Manager approves through the trusted command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

create temporary table v1_ph3_advisory_payload as
select '{
  "request_id":"b3100000-0000-4000-8000-000000000002",
  "arrangement_id":"b3130000-0000-4000-8000-000000000002",
  "expected_request_version":2,
  "expected_arrangement_version":1,
  "lines":[{
    "arrangement_line_id":"b3140000-0000-4000-8000-000000000002",
    "source_kind":"external_supplier",
    "external_supplier":"Advisory Supplier",
    "inventory_item_id":null,
    "decision":"full",
    "arranged_qty":2,
    "reason":null,
    "external_source_ready":false,
    "external_expected_date":null,
    "external_reference":null
  }]
}'::jsonb as payload;
grant select on table v1_ph3_advisory_payload to authenticated;

select lives_ok(
  $$select public.v1_save_arrangement(
    (select payload from v1_ph3_advisory_payload),
    'b3300000-0000-4000-8000-000000000001'::uuid
  )$$,
  'External readiness evidence is advisory while enforcement is unpublished'
);

set local role postgres;
select is(
  (select external_source_ready
    from public.v1_procurement_arrangement_lines
    where id = 'b3140000-0000-4000-8000-000000000002'),
  false,
  'Advisory save persists an explicit not-yet-confirmed readiness fact'
);
select is(
  (select state from public.v1_material_requests
    where id = 'b3100000-0000-4000-8000-000000000002'),
  'approved',
  'Advisory readiness does not block the existing approved arrangement flow'
);

update public.v1_configuration_settings
set published_value = 'true'::jsonb
where setting_key = 'procurement.require_external_source_readiness';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

create temporary table v1_ph3_enforced_payload as
select '{
  "request_id":"b3100000-0000-4000-8000-000000000003",
  "arrangement_id":"b3130000-0000-4000-8000-000000000003",
  "expected_request_version":2,
  "expected_arrangement_version":1,
  "lines":[{
    "arrangement_line_id":"b3140000-0000-4000-8000-000000000003",
    "source_kind":"external_supplier",
    "external_supplier":"Committed Supplier",
    "inventory_item_id":null,
    "decision":"full",
    "arranged_qty":3,
    "reason":null,
    "external_source_ready":false,
    "external_expected_date":"2026-09-01",
    "external_reference":"SUP-COMMIT-001"
  }]
}'::jsonb as payload;
grant select on table v1_ph3_enforced_payload to authenticated;

select throws_ok(
  $$select public.v1_save_arrangement(
    (select payload from v1_ph3_enforced_payload),
    'b3300000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023', 'V1_EXTERNAL_SOURCE_READINESS_REQUIRED',
  'Published enforcement blocks an unconfirmed external source atomically'
);

set local role postgres;
select is(
  (select state from public.v1_material_requests
    where id = 'b3100000-0000-4000-8000-000000000003'),
  'arranging',
  'A rejected readiness save leaves the request in Procurement arrangement'
);
select is(
  (select record_version from public.v1_procurement_arrangements
    where id = 'b3130000-0000-4000-8000-000000000003'),
  1,
  'A rejected readiness save does not mutate the arrangement version'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_save_arrangement(
    jsonb_set(
      (select payload from v1_ph3_enforced_payload),
      '{lines,0,external_source_ready}', 'true'::jsonb
    ),
    'b3300000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A confirmed external commitment passes the enforced server gate'
);

select is(
  public.v1_arrangement_projection(
    'b3100000-0000-4000-8000-000000000003'
  ) #>> '{arrangements,0,lines,0,external_reference}',
  'SUP-COMMIT-001',
  'The role-safe arrangement projection returns the commitment reference'
);
select is(
  public.v1_arrangement_projection(
    'b3100000-0000-4000-8000-000000000003'
  ) #>> '{arrangements,0,lines,0,external_expected_date}',
  '2026-09-01',
  'The role-safe arrangement projection returns the expected date'
);
select is(
  (public.v1_arrangement_projection(
    'b3100000-0000-4000-8000-000000000003'
  ) ->> 'external_source_readiness_required')::boolean,
  true,
  'The arrangement workspace exposes the published enforcement state'
);

select throws_ok(
  $$select public.v1_create_replacement_material_request(
    '{"source_request_id":"b3100000-0000-4000-8000-000000000004","expected_source_version":5}'::jsonb,
    'b3400000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501', 'V1_REPLACEMENT_REQUEST_DENIED',
  'Procurement cannot create an Engineering replacement request'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
set local role postgres;
select ok(
  public.v1_can_create_replacement_material_request(
    'b3100000-0000-4000-8000-000000000004'
  ),
  'A global engineering manager can replace a cancelled all-unavailable request'
);
set local role authenticated;
select lives_ok(
  $$select public.v1_create_replacement_material_request(
    '{"source_request_id":"b3100000-0000-4000-8000-000000000004","expected_source_version":5}'::jsonb,
    'b3400000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The trusted command creates a linked private Draft'
);
select lives_ok(
  $$select public.v1_create_replacement_material_request(
    '{"source_request_id":"b3100000-0000-4000-8000-000000000004","expected_source_version":5}'::jsonb,
    'b3400000-0000-4000-8000-000000000002'::uuid
  )$$,
  'An exact replacement retry returns the first authoritative Draft'
);

set local role postgres;
select is(
  (select count(*) from public.v1_material_requests
    where replacement_of_request_id =
      'b3100000-0000-4000-8000-000000000004'),
  1::bigint,
  'Replacement retries cannot duplicate the linked Draft'
);
select is(
  (select state from public.v1_material_requests
    where id = 'b3100000-0000-4000-8000-000000000004'),
  'cancelled',
  'Replacement creation never reopens the terminal source request'
);
select ok(
  (select replacement.state = 'draft'
      and replacement.created_by_auth_user_id =
        '10000000-0000-4000-8000-000000000010'
    from public.v1_material_requests replacement
    where replacement.replacement_of_request_id =
      'b3100000-0000-4000-8000-000000000004'),
  'The replacement is a private Engineering-owned Draft'
);
select ok(
  (select count(*) = 1
      and bool_and(line_record.replacement_of_request_line_id is not null)
    from public.v1_material_request_lines line_record
    join public.v1_material_requests replacement
      on replacement.id = line_record.request_id
    where replacement.replacement_of_request_id =
      'b3100000-0000-4000-8000-000000000004'),
  'Replacement lines preserve exact source-line provenance'
);

select is(
  (select count(*) from public.v1_audit_events
    where event_type = 'external_source_readiness_saved'
      and entity_id in (
        'b3130000-0000-4000-8000-000000000002',
        'b3130000-0000-4000-8000-000000000003'
      )),
  2::bigint,
  'Every successful external readiness save is append-only audited once'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_create_replacement_material_request(
    '{"source_request_id":"b3100000-0000-4000-8000-000000000005","expected_source_version":5}'::jsonb,
    'b3400000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Admin can create the controlled replacement through the same command'
);

set local role postgres;
select ok(
  (select replacement.requester_project_role = 'project_engineer'
      and replacement.requester_exact_role = 'admin'
    from public.v1_material_requests replacement
    where replacement.replacement_of_request_id =
      'b3100000-0000-4000-8000-000000000005'),
  'Admin replacement keeps exact role while using valid Engineering workflow attribution'
);

select * from finish();
rollback;
