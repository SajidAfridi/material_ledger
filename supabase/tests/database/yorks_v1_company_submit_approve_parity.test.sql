begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

insert into public.v1_company_material_request_categories
  (id, category_code, display_name, is_active)
values ('6ca10000-0000-4000-8000-000000000001', 'company_self_approval_test',
  'Company self approval test', true);
insert into public.v1_company_material_request_units
  (id, unit_code, display_name, is_active)
values ('6ca11000-0000-4000-8000-000000000001', 'COMPANY-SELF-TEST',
  'Company self approval unit', true);
insert into public.v1_company_material_request_authorizations
  (auth_user_id, category_id, responsible_unit_id, authority, effective_from)
values
  ('10000000-0000-4000-8000-000000000009','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','requester',current_date),
  ('10000000-0000-4000-8000-000000000009','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','approver',current_date),
  ('10000000-0000-4000-8000-000000000002','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','requester',current_date),
  ('10000000-0000-4000-8000-000000000002','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','beneficiary',current_date),
  ('10000000-0000-4000-8000-000000000001','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','receiver',current_date),
  ('10000000-0000-4000-8000-000000000003','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','requester',current_date),
  ('10000000-0000-4000-8000-000000000004','6ca10000-0000-4000-8000-000000000001','6ca11000-0000-4000-8000-000000000001','requester',current_date);
insert into public.v1_company_material_request_approval_routes
  (id,category_id,responsible_unit_id,primary_approver_auth_user_id,policy_version,effective_from)
values ('6ca12000-0000-4000-8000-000000000001',
  '6ca10000-0000-4000-8000-000000000001',
  '6ca11000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000009', 'SELF-TEST-1', current_date);

create temporary table self_command(payload jsonb, response jsonb, command_key uuid);
insert into self_command(payload, command_key) values (
  jsonb_build_object(
    'request_id','6ca20000-0000-4000-8000-000000000001','expected_version',0,
    'category_id','6ca10000-0000-4000-8000-000000000001',
    'responsible_unit_id','6ca11000-0000-4000-8000-000000000001',
    'purpose','Workshop consumables','timing','normal','scheduled_date',null,
    'delivery_collection_point','Workshop',
    'beneficiary_auth_user_id','10000000-0000-4000-8000-000000000002',
    'authorized_receiver_auth_user_id','10000000-0000-4000-8000-000000000001',
    'selected_approver_auth_user_id','10000000-0000-4000-8000-000000000009',
    'lines',jsonb_build_array(jsonb_build_object(
      'id','6ca21000-0000-4000-8000-000000000001','display_order',1,
      'item_description','Helmet','requested_qty','2','unit','pcs'))),
  '6ca22000-0000-4000-8000-000000000001');
grant all on self_command to authenticated;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer"}}',true);
select is((select response->>'approver_auth_user_id' from (
  select public.v1_company_material_request_approval_choices(
    '6ca10000-0000-4000-8000-000000000001',
    '6ca11000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001', null) response) x),
  '10000000-0000-4000-8000-000000000009',
  'Authorized senior requester is the default approver');
select lives_ok($$update self_command set response =
  public.v1_save_submit_and_approve_company_material_request(payload,command_key)$$,
  'Senior requester submits and approves atomically');
select is((select response->>'state' from self_command), 'approved_for_procurement',
  'Fast path ends in procurement approval');
select is((select response->>'record_version' from self_command), '3',
  'Save, submit and decision each advance version once');
select is((select response->>'approver_auth_user_id' from self_command),
  '10000000-0000-4000-8000-000000000009',
  'Requester remains the recorded approver');
set local role postgres;
select is((select count(*)::integer from public.v1_company_material_request_decisions
  where request_id='6ca20000-0000-4000-8000-000000000001'),1,
  'Exactly one server decision is recorded');
select is((select count(*)::integer from public.v1_company_material_request_events
  where request_id='6ca20000-0000-4000-8000-000000000001'
    and event_type in ('company_request_submitted','company_request_approved')),2,
  'Submission and approval remain separate audit events');
select is((select count(*)::integer from public.v1_notifications
  where entity_id='6ca20000-0000-4000-8000-000000000001'
    and recipient_auth_user_id='10000000-0000-4000-8000-000000000009'
    and event_code='company_material_request_approved'),1,
  'Approval notifies the requester');
select is((select count(*)::integer from public.v1_notifications
  where entity_id='6ca20000-0000-4000-8000-000000000001'
    and recipient_auth_user_id='10000000-0000-4000-8000-000000000009'
    and event_code='company_material_request_approval_requested'
    and seen_at is not null),1,
  'Atomic self-handoff does not leave an unread approval task');
set local role authenticated;
select is((select public.v1_save_submit_and_approve_company_material_request(
  payload,command_key)->>'record_version' from self_command),'3',
  'Idempotent retry returns the same version');
set local role postgres;
select is((select count(*)::integer from public.v1_company_material_request_decisions
  where request_id='6ca20000-0000-4000-8000-000000000001'),1,
  'Retry does not duplicate the decision');
set local role authenticated;
select throws_ok($$select public.v1_save_submit_and_approve_company_material_request(
  (select payload from self_command),gen_random_uuid())$$,'42501',
  'V1_COMPANY_MATERIAL_REQUEST_DRAFT_WRITE_DENIED','Approved request cannot be overwritten as a draft');
select throws_ok($$select public.v1_save_submit_and_approve_company_material_request(
  (select jsonb_set(payload,'{beneficiary_auth_user_id}',
    '"10000000-0000-4000-8000-000000000009"'::jsonb) from self_command),
  gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED',
  'Beneficiary cannot self-approve');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select throws_ok($$select public.v1_save_submit_and_approve_company_material_request(
  (select payload from self_command),gen_random_uuid())$$,'42501',
  'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED',
  'Site Engineer cannot use approver fast path');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select throws_ok($$select public.v1_save_submit_and_approve_company_material_request(
  (select payload from self_command),gen_random_uuid())$$,'42501',
  'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED',
  'Procurement cannot use approver fast path');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select throws_ok($$select public.v1_save_submit_and_approve_company_material_request(
  (select payload from self_command),gen_random_uuid())$$,'42501',
  'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED',
  'Admin without category grant cannot use fast path');
set local role postgres;
select * from finish();
rollback;
