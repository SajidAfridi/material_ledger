begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_company_material_requests'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_company_material_request_authorizations'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_company_material_requests', 'insert'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_company_material_request_authorizations', 'select'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_save_and_submit_company_material_request(jsonb,uuid)', 'execute'
  ),
  'Company request data is RLS-protected, command-only and exposes only narrow RPCs'
);

set local role postgres;
insert into public.v1_company_material_request_categories (
  id, category_code, display_name
) values (
  'c1000000-0000-4000-8000-000000000001', 'ppe', 'Personal protective equipment'
);
insert into public.v1_company_material_request_units (
  id, unit_code, display_name
) values (
  'c1000000-0000-4000-8000-000000000002', 'WORKSHOP', 'Workshop'
);
insert into public.v1_company_material_request_authorizations (
  auth_user_id, category_id, responsible_unit_id, authority
) values
  ('10000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002', 'requester'),
  ('10000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002', 'beneficiary'),
  ('10000000-0000-4000-8000-000000000002', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002', 'receiver'),
  ('10000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000001', 'c1000000-0000-4000-8000-000000000002', 'approver');
insert into public.v1_company_material_request_approval_routes (
  id, category_id, responsible_unit_id, primary_approver_auth_user_id, policy_version
) values (
  'c1000000-0000-4000-8000-000000000003',
  'c1000000-0000-4000-8000-000000000001',
  'c1000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  'cmr-test-v1'
);

create temporary table cmr_payloads (
  saved_payload jsonb not null,
  atomic_payload jsonb not null
);
insert into cmr_payloads (saved_payload, atomic_payload) values (
  jsonb_build_object(
    'request_id', 'c1000000-0000-4000-8000-000000000010',
    'expected_version', 0,
    'category_id', 'c1000000-0000-4000-8000-000000000001',
    'responsible_unit_id', 'c1000000-0000-4000-8000-000000000002',
    'purpose', 'Replace worn workshop safety jacket',
    'timing', 'normal', 'scheduled_date', null,
    'delivery_collection_point', 'Workshop issue desk',
    'beneficiary_auth_user_id', '10000000-0000-4000-8000-000000000002',
    'authorized_receiver_auth_user_id', '10000000-0000-4000-8000-000000000002',
    'lines', jsonb_build_array(jsonb_build_object(
      'id', 'c1000000-0000-4000-8000-000000000011',
      'display_order', 1,
      'item_description', 'High-visibility jacket, size L',
      'brand_origin', 'Approved PPE',
      'requested_qty', '1',
      'unit', 'Nos'
    ))
  ),
  jsonb_build_object(
    'request_id', 'c1000000-0000-4000-8000-000000000020',
    'expected_version', 0,
    'category_id', 'c1000000-0000-4000-8000-000000000001',
    'responsible_unit_id', 'c1000000-0000-4000-8000-000000000002',
    'purpose', 'Atomic company request',
    'timing', 'normal', 'scheduled_date', null,
    'delivery_collection_point', 'Workshop issue desk',
    'beneficiary_auth_user_id', '10000000-0000-4000-8000-000000000002',
    'authorized_receiver_auth_user_id', '10000000-0000-4000-8000-000000000002',
    'lines', jsonb_build_array(jsonb_build_object(
      'id', 'c1000000-0000-4000-8000-000000000021',
      'display_order', 1,
      'item_description', 'Safety gloves',
      'brand_origin', null,
      'requested_qty', '1',
      'unit', 'Pair'
    ))
  )
);
grant select on cmr_payloads to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_list_company_material_request_draft_options()$$,
  'Explicitly authorized requester sees only their configured category and unit choices'
);
select is(
  (public.v1_list_company_material_request_draft_options() -> 0 ->> 'category_code'),
  'ppe',
  'Requester options expose the permitted category without project data'
);
select is(
  (public.v1_list_company_material_request_draft_options() -> 0 -> 'beneficiaries' -> 0 ->> 'auth_user_id'),
  '10000000-0000-4000-8000-000000000002',
  'Beneficiary picker contains only the active explicitly authorized person'
);
select lives_ok(
  $$select public.v1_company_material_request_approval_preflight(
    'c1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002'
  )$$,
  'Preflight resolves the independent configured company approver'
);
select is(
  (public.v1_company_material_request_approval_preflight(
    'c1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002'
  ) ->> 'approver_auth_user_id'),
  '10000000-0000-4000-8000-000000000001',
  'Preflight cannot select the requester, beneficiary or receiver as approver'
);
select throws_ok(
  $$select public.v1_company_material_request_approval_preflight(
    'c1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002'
  )$$,
  '42501', 'V1_COMPANY_MATERIAL_REQUEST_PREFLIGHT_DENIED',
  'Preflight cannot disclose a route for a beneficiary outside the effective policy'
);
select lives_ok(
  $$select public.v1_save_company_material_request_draft(
    (select saved_payload from cmr_payloads)
  )$$,
  'Authorized Site Engineer saves a private company draft'
);
select is(
  (public.v1_company_material_request_projection(
    'c1000000-0000-4000-8000-000000000010'
  ) ->> 'state'),
  'draft',
  'Draft has no submitted workflow state'
);
select is(
  (public.v1_company_material_request_projection(
    'c1000000-0000-4000-8000-000000000010'
  ) ->> 'request_number') is null,
  true,
  'Draft has no controlled company reference'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_company_material_request_projection(
    'c1000000-0000-4000-8000-000000000010'
  )$$,
  '42501', 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE',
  'Project engineering authority does not disclose another company draft'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_list_company_material_request_draft_options(),
  '[]'::jsonb,
  'Procurement receives no company requester route without an explicit grant'
);
select throws_ok(
  $$insert into public.v1_company_material_requests (
    id, category_id, responsible_unit_id, purpose, delivery_collection_point,
    beneficiary_auth_user_id, beneficiary_display_name,
    authorized_receiver_auth_user_id, authorized_receiver_display_name,
    created_by_auth_user_id, requester_display_name, requester_exact_role
  ) values (
    'c1000000-0000-4000-8000-000000000099',
    'c1000000-0000-4000-8000-000000000001',
    'c1000000-0000-4000-8000-000000000002', 'Bypass', 'Nowhere',
    '10000000-0000-4000-8000-000000000003', 'Procurement',
    '10000000-0000-4000-8000-000000000003', 'Procurement',
    '10000000-0000-4000-8000-000000000003', 'Procurement', 'procurement'
  )$$,
  '42501', 'permission denied for table v1_company_material_requests',
  'Direct authenticated writes cannot bypass the trusted company command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
create temporary table cmr_submit_response as
select public.v1_submit_company_material_request(
  jsonb_build_object(
    'request_id', 'c1000000-0000-4000-8000-000000000010',
    'expected_version', 1
  ),
  'c1000000-0000-4000-8000-000000000012'
) as response;
grant select on cmr_submit_response to authenticated;
select is(
  (select response ->> 'state' from cmr_submit_response),
  'awaiting_company_approval',
  'Submit hands the company need to an independent company approver'
);
select is(
  (select response ->> 'request_number' from cmr_submit_response),
  'CMR-000001',
  'Submission allocates one independent company reference'
);
select is(
  (select response ->> 'approver_auth_user_id' from cmr_submit_response),
  '10000000-0000-4000-8000-000000000001',
  'Submission snapshots the resolved approver rather than a client choice'
);
select is(
  public.v1_submit_company_material_request(
    jsonb_build_object(
      'request_id', 'c1000000-0000-4000-8000-000000000010',
      'expected_version', 1
    ),
    'c1000000-0000-4000-8000-000000000012'
  ),
  (select response from cmr_submit_response),
  'An exact submit retry returns the first projection without another effect'
);

set local role postgres;
select is(
  (select count(*) from public.v1_company_material_request_events
   where request_id = 'c1000000-0000-4000-8000-000000000010'
     and event_type = 'company_request_submitted'),
  1::bigint,
  'One submitted audit event is appended for an idempotent command'
);
select is(
  (select count(*) from public.v1_notifications
   where entity_id = 'c1000000-0000-4000-8000-000000000010'
     and event_code = 'company_material_request_approval_requested'),
  1::bigint,
  'One approver notification is created for an idempotent command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
create temporary table cmr_atomic_response as
select public.v1_save_and_submit_company_material_request(
  (select atomic_payload from cmr_payloads),
  'c1000000-0000-4000-8000-000000000022'
) as response;
grant select on cmr_atomic_response to authenticated;
select is(
  (select response ->> 'state' from cmr_atomic_response),
  'awaiting_company_approval',
  'Atomic save and submit persists the private draft and approval handoff together'
);
select is(
  public.v1_save_and_submit_company_material_request(
    (select atomic_payload from cmr_payloads),
    'c1000000-0000-4000-8000-000000000022'
  ),
  (select response from cmr_atomic_response),
  'An exact atomic retry returns the saved response without re-saving a submitted request'
);

set local role postgres;
select is(
  (select count(*) from public.v1_company_material_request_events
   where request_id = 'c1000000-0000-4000-8000-000000000020'
     and event_type = 'company_request_submitted'),
  1::bigint,
  'The atomic retry cannot append a second submitted event'
);

set local role postgres;
update public.v1_company_material_request_approval_routes
set primary_approver_auth_user_id = '10000000-0000-4000-8000-000000000002',
    alternate_approver_auth_user_id = null
where id = 'c1000000-0000-4000-8000-000000000003';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_save_and_submit_company_material_request(
    jsonb_set(
      jsonb_set(
        (select atomic_payload from cmr_payloads),
        '{request_id}', to_jsonb('c1000000-0000-4000-8000-000000000030'::text)
      ),
      '{lines,0,id}', to_jsonb('c1000000-0000-4000-8000-000000000031'::text)
    ),
    'c1000000-0000-4000-8000-000000000032'
  )$$,
  '22023', 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED',
  'A requester cannot self-approve through a conflicted company route'
);

set local role postgres;
select is(
  (select count(*) from public.v1_company_material_requests
   where id = 'c1000000-0000-4000-8000-000000000030'),
  0::bigint,
  'Atomic submit rollback leaves no draft or submitted record when routing fails'
);

select * from finish();
rollback;
