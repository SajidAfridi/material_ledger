begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(20);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_company_material_request_decisions'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_company_material_request_decisions', 'insert'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_decide_company_material_request(jsonb,uuid)', 'execute'
  ),
  'Decision evidence is RLS protected and exposed through the narrow RPC only'
);

set local role postgres;
insert into public.v1_company_material_request_categories (
  id, category_code, display_name
) values (
  'c2000000-0000-4000-8000-000000000001', 'ppe_approval',
  'Approval test equipment'
);
insert into public.v1_company_material_request_units (
  id, unit_code, display_name
) values (
  'c2000000-0000-4000-8000-000000000002', 'APPROVAL_TEST',
  'Approval test unit'
);
insert into public.v1_company_material_request_authorizations (
  auth_user_id, category_id, responsible_unit_id, authority
) values
  ('10000000-0000-4000-8000-000000000002',
   'c2000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000002', 'requester'),
  ('10000000-0000-4000-8000-000000000002',
   'c2000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000002', 'beneficiary'),
  ('10000000-0000-4000-8000-000000000002',
   'c2000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000002', 'receiver'),
  ('10000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000002', 'approver'),
  ('10000000-0000-4000-8000-000000000003',
   'c2000000-0000-4000-8000-000000000001',
   'c2000000-0000-4000-8000-000000000002', 'approver');
insert into public.v1_company_material_request_approval_routes (
  id, category_id, responsible_unit_id, primary_approver_auth_user_id,
  policy_version
) values (
  'c2000000-0000-4000-8000-000000000003',
  'c2000000-0000-4000-8000-000000000001',
  'c2000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001', 'cmr-approval-test-v1'
);

create temporary table cmr_approval_payloads (
  request_id uuid primary key,
  payload jsonb not null,
  submit_key uuid not null,
  decision_key uuid not null
);
insert into cmr_approval_payloads values
  (
    'c2000000-0000-4000-8000-000000000010',
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 0,
      'category_id', 'c2000000-0000-4000-8000-000000000001',
      'responsible_unit_id', 'c2000000-0000-4000-8000-000000000002',
      'purpose', 'Approve safety gloves',
      'timing', 'normal', 'scheduled_date', null,
      'delivery_collection_point', 'Workshop issue desk',
      'beneficiary_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'authorized_receiver_auth_user_id',
        '10000000-0000-4000-8000-000000000002',
      'lines', jsonb_build_array(jsonb_build_object(
        'id', 'c2000000-0000-4000-8000-000000000011',
        'display_order', 1, 'item_description', 'Safety gloves',
        'brand_origin', null, 'requested_qty', '2', 'unit', 'Pair'
      ))
    ),
    'c2000000-0000-4000-8000-000000000012',
    'c2000000-0000-4000-8000-000000000013'
  ),
  (
    'c2000000-0000-4000-8000-000000000020',
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000020',
      'expected_version', 0,
      'category_id', 'c2000000-0000-4000-8000-000000000001',
      'responsible_unit_id', 'c2000000-0000-4000-8000-000000000002',
      'purpose', 'Return safety boots for clarification',
      'timing', 'normal', 'scheduled_date', null,
      'delivery_collection_point', 'Workshop issue desk',
      'beneficiary_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'authorized_receiver_auth_user_id',
        '10000000-0000-4000-8000-000000000002',
      'lines', jsonb_build_array(jsonb_build_object(
        'id', 'c2000000-0000-4000-8000-000000000021',
        'display_order', 1, 'item_description', 'Safety boots',
        'brand_origin', null, 'requested_qty', '1', 'unit', 'Pair'
      ))
    ),
    'c2000000-0000-4000-8000-000000000022',
    'c2000000-0000-4000-8000-000000000023'
  );
grant select on cmr_approval_payloads to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_save_and_submit_company_material_request(
    (select payload from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000010'),
    (select submit_key from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000010')
  )$$,
  'Requester can create the approval fixture through the protected command'
);
select lives_ok(
  $$select public.v1_save_and_submit_company_material_request(
    (select payload from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000020'),
    (select submit_key from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000020')
  )$$,
  'Requester can create an independent return fixture'
);
select is(
  public.v1_list_company_material_request_approval_inbox(),
  '[]'::jsonb,
  'Requester cannot see the assigned approver inbox'
);
select throws_ok(
  $$select public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 2, 'decision', 'approved', 'reason', null
    ), 'c2000000-0000-4000-8000-000000000014'
  )$$,
  '42501', 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED',
  'Requester cannot approve their own company request'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_list_company_material_request_approval_inbox(),
  '[]'::jsonb,
  'Procurement cannot see an engineering approver inbox'
);
select throws_ok(
  $$select public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 2, 'decision', 'approved', 'reason', null
    ), 'c2000000-0000-4000-8000-000000000015'
  )$$,
  '42501', 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED',
  'Procurement cannot decide even with an explicit company approver grant'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  jsonb_array_length(public.v1_list_company_material_request_approval_inbox()),
  2,
  'Assigned independent approver sees both pending company requests'
);
select is(
  (public.v1_company_material_request_projection(
    'c2000000-0000-4000-8000-000000000010'
  ) ->> 'can_decide')::boolean,
  true,
  'Pending projection explicitly reports current decision authority'
);
select throws_ok(
  $$select public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 1, 'decision', 'approved', 'reason', null
    ), 'c2000000-0000-4000-8000-000000000016'
  )$$,
  '40001', 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT',
  'Stale approval versions fail closed'
);
select throws_ok(
  $$select public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000020',
      'expected_version', 2, 'decision', 'returned', 'reason', null
    ), 'c2000000-0000-4000-8000-000000000024'
  )$$,
  '22023', 'V1_COMPANY_MATERIAL_REQUEST_DECISION_PAYLOAD_INVALID',
  'Return requires a non-empty reason'
);

create temporary table cmr_decision_response as
select public.v1_decide_company_material_request(
  jsonb_build_object(
    'request_id', 'c2000000-0000-4000-8000-000000000010',
    'expected_version', 2, 'decision', 'approved', 'reason', null
  ),
  (select decision_key from cmr_approval_payloads
    where request_id = 'c2000000-0000-4000-8000-000000000010')
) as response;
grant select on cmr_decision_response to authenticated;
select is(
  (select response ->> 'state' from cmr_decision_response),
  'approved_for_procurement',
  'Assigned approver advances approved demand without touching stock'
);
select is(
  (select response ->> 'can_decide' from cmr_decision_response),
  'false',
  'A completed decision cannot be presented as still actionable'
);
select is(
  public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 2, 'decision', 'approved', 'reason', null
    ),
    (select decision_key from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000010')
  ),
  (select response from cmr_decision_response),
  'An exact approval retry returns the current projection without another effect'
);
select is(
  (public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000020',
      'expected_version', 2, 'decision', 'returned',
      'reason', 'Confirm the beneficiary boot size before procurement.'
    ),
    (select decision_key from cmr_approval_payloads
      where request_id = 'c2000000-0000-4000-8000-000000000020')
  ) ->> 'state'),
  'returned_for_changes',
  'Assigned approver can return a request with immutable guidance'
);

set local role postgres;
select is(
  (select count(*) from public.v1_company_material_request_decisions
   where request_id = 'c2000000-0000-4000-8000-000000000010'),
  1::bigint,
  'Idempotent retry appends exactly one decision record'
);
select is(
  (select count(*) from public.v1_company_material_request_events
   where request_id = 'c2000000-0000-4000-8000-000000000010'
     and event_type = 'company_request_approved'),
  1::bigint,
  'Approval appends exactly one server-authored event'
);
select is(
  (select count(*) from public.v1_notifications
   where entity_id = 'c2000000-0000-4000-8000-000000000010'
     and event_code = 'company_material_request_approved'),
  1::bigint,
  'Approval creates exactly one requester notification'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$insert into public.v1_company_material_request_decisions (
    request_id, request_record_version, decision, approval_route_id,
    approval_policy_version, decided_by_auth_user_id,
    decided_by_display_name, decided_by_exact_role, idempotency_key
  ) values (
    'c2000000-0000-4000-8000-000000000010', 3, 'approved',
    'c2000000-0000-4000-8000-000000000003', 'bypass',
    '10000000-0000-4000-8000-000000000001', 'Bypass',
    'project_engineer', 'c2000000-0000-4000-8000-000000000099'
  )$$,
  '42501', 'permission denied for table v1_company_material_request_decisions',
  'Authenticated clients cannot forge decision history'
);
select throws_ok(
  $$select public.v1_decide_company_material_request(
    jsonb_build_object(
      'request_id', 'c2000000-0000-4000-8000-000000000010',
      'expected_version', 3, 'decision', 'rejected',
      'reason', 'A second decision must never be accepted.'
    ), 'c2000000-0000-4000-8000-000000000017'
  )$$,
  '42501', 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED',
  'A completed company request cannot be decided twice'
);

select * from finish();
rollback;
