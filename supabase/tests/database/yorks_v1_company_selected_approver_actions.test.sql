begin; create extension if not exists pgtap with schema extensions; set local search_path=public,extensions;
select plan(28);
insert into public.v1_company_material_request_categories (
  id, category_code, display_name, is_active
) values (
  '5dc10000-0000-4000-8000-000000000001',
  'staging_demo_ppe',
  'STAGING DEMO — Safety & PPE',
  true
)
on conflict (category_code) do update
set display_name = excluded.display_name,
    is_active = true,
    updated_at = clock_timestamp();

insert into public.v1_company_material_request_units (
  id, unit_code, display_name, is_active
) values (
  '5dc11000-0000-4000-8000-000000000001',
  'DEMO-WORKSHOP',
  'STAGING DEMO — Workshop Operations',
  true
)
on conflict (unit_code) do update
set display_name = excluded.display_name,
    is_active = true,
    updated_at = clock_timestamp();

-- Requesting authority is explicitly granted to named staging personas. The
-- beneficiary and receiver catalogue deliberately excludes the approvers, so
-- the standard selection has an independent route instead of a hidden
-- self-approval path.
insert into public.v1_company_material_request_authorizations (
  auth_user_id, category_id, responsible_unit_id, authority, effective_from
) values
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000004', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000009', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000004', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'approver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000009', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'approver', date '2026-01-01')
on conflict (
  auth_user_id, category_id, responsible_unit_id, authority, effective_from
) do update
set effective_to = null,
    updated_at = clock_timestamp();

insert into public.v1_company_material_request_approval_routes (
  id,
  category_id,
  responsible_unit_id,
  primary_approver_auth_user_id,
  alternate_approver_auth_user_id,
  policy_version,
  effective_from
) values (
  '5dc12000-0000-4000-8000-000000000001',
  '5dc10000-0000-4000-8000-000000000001',
  '5dc11000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000009',
  'STAGING-DEMO-T01-20260913',
  date '2026-01-01'
)
on conflict (category_id, responsible_unit_id, effective_from) do update
set primary_approver_auth_user_id = excluded.primary_approver_auth_user_id,
    alternate_approver_auth_user_id = excluded.alternate_approver_auth_user_id,
    policy_version = excluded.policy_version,
    effective_to = null,
    updated_at = clock_timestamp();


create temporary table command_state(response jsonb);
create temporary table command_payload(payload jsonb);
insert into command_payload values(jsonb_build_object(
'request_id','5dc20000-0000-4000-8000-000000000001','expected_version',0,
'category_id','5dc10000-0000-4000-8000-000000000001','responsible_unit_id','5dc11000-0000-4000-8000-000000000001',
'purpose','Company integration test','timing','normal','scheduled_date',null,'delivery_collection_point','Workshop',
'beneficiary_auth_user_id','10000000-0000-4000-8000-000000000002','authorized_receiver_auth_user_id','10000000-0000-4000-8000-000000000001',
'selected_approver_auth_user_id','10000000-0000-4000-8000-000000000009',
'lines',jsonb_build_array(jsonb_build_object('id','5dc21000-0000-4000-8000-000000000001','display_order',1,'item_description','Helmet',
'brand_origin',null,'requested_qty','2','unit','pcs'))));
grant all on command_state,command_payload to authenticated;

set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select lives_ok($$insert into command_state select public.v1_save_company_material_request_draft((select payload from command_payload))$$,'Site Engineer creates a private Company draft');
select is((select response->>'selected_approver_auth_user_id' from command_state),'10000000-0000-4000-8000-000000000009','Choice of independent senior approver persists');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select throws_ok($$select public.v1_company_material_request_projection('5dc20000-0000-4000-8000-000000000001')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Private draft excludes project_engineer');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select throws_ok($$select public.v1_company_material_request_projection('5dc20000-0000-4000-8000-000000000001')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Private draft excludes procurement');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select throws_ok($$select public.v1_company_material_request_projection('5dc20000-0000-4000-8000-000000000001')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Private draft excludes admin');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant"}}',true);
select throws_ok($$select public.v1_company_material_request_projection('5dc20000-0000-4000-8000-000000000001')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Private draft excludes accountant');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select lives_ok($$update command_state set response=public.v1_submit_company_material_request(jsonb_build_object('request_id',response->>'id','expected_version',response->>'record_version'),'5dc22000-0000-4000-8000-000000000001')$$,'Submit transfers to selected approver');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select throws_ok($$select public.v1_decide_company_material_request(jsonb_build_object('request_id','5dc20000-0000-4000-8000-000000000001','expected_version',2,'decision','approved','reason',null),gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED','Unassigned site_engineer cannot approve');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select throws_ok($$select public.v1_decide_company_material_request(jsonb_build_object('request_id','5dc20000-0000-4000-8000-000000000001','expected_version',2,'decision','approved','reason',null),gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED','Unassigned project_engineer cannot approve');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select throws_ok($$select public.v1_decide_company_material_request(jsonb_build_object('request_id','5dc20000-0000-4000-8000-000000000001','expected_version',2,'decision','approved','reason',null),gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED','Unassigned procurement cannot approve');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select throws_ok($$select public.v1_decide_company_material_request(jsonb_build_object('request_id','5dc20000-0000-4000-8000-000000000001','expected_version',2,'decision','approved','reason',null),gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED','Unassigned admin cannot approve');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant"}}',true);
select throws_ok($$select public.v1_decide_company_material_request(jsonb_build_object('request_id','5dc20000-0000-4000-8000-000000000001','expected_version',2,'decision','approved','reason',null),gen_random_uuid())$$,'42501','V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED','Unassigned accountant cannot approve');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select lives_ok($$select public.v1_company_material_request_evidence('5dc20000-0000-4000-8000-000000000001')$$,'Admin can inspect submitted evidence');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer"}}',true);
select lives_ok($$update command_state set response=public.v1_decide_company_material_request(jsonb_build_object('request_id',response->>'id','expected_version',response->>'record_version','decision','approved','reason',null),'5dc22000-0000-4000-8000-000000000002')$$,'Selected senior approver approves independently');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select lives_ok($$update command_state set response=public.v1_revise_and_resubmit_company_material_request(jsonb_build_object('request_id',response->>'id','expected_version',response->>'record_version','purpose','Corrected Company need','delivery_collection_point','Workshop','reason','Clarified specification','lines',jsonb_build_array(jsonb_build_object('id','5dc21000-0000-4000-8000-000000000001','item_description','Helmet adjustable','brand_origin',null,'requested_qty','3','unit','pcs'))),'5dc22000-0000-4000-8000-000000000003')$$,'Procurement can correct before dispatch');
select is((select response->>'state' from command_state),'awaiting_company_approval','Correction invalidates prior approval');
select lives_ok($$select public.v1_company_material_request_projection('5dc20000-0000-4000-8000-000000000001')$$,'Procurement retains access to corrected request awaiting approval');
set local role authenticated; select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select throws_ok($$select public.v1_cancel_company_material_request('5dc20000-0000-4000-8000-000000000001',2,'Changed',gen_random_uuid())$$,'40001','V1_COMPANY_MATERIAL_REQUEST_CONFLICT','Stale cancellation never overwrites correction');
select throws_ok($$select public.v1_cancel_company_material_request('5dc20000-0000-4000-8000-000000000001',4,' ',gen_random_uuid())$$,'22023','V1_COMPANY_CANCEL_REASON_REQUIRED','Cancellation needs a reason');
select lives_ok($$update command_state set response=public.v1_cancel_company_material_request((response->>'id')::uuid,(response->>'record_version')::integer,'No longer required','5dc22000-0000-4000-8000-000000000004')$$,'Requester cancels before dispatch');
select is((select response->>'state' from command_state),'cancelled','Cancelled record retained');
select is(public.v1_cancel_company_material_request('5dc20000-0000-4000-8000-000000000001',4,'No longer required','5dc22000-0000-4000-8000-000000000004')->>'record_version','5','Cancellation retry does not increment version');
set local role postgres;
select is((select count(*)::integer from public.v1_company_material_request_events where request_id='5dc20000-0000-4000-8000-000000000001' and event_type='company_request_cancelled'),1,'One immutable cancellation event');
select is((select count(*)::integer from public.v1_audit_events where entity_id='5dc20000-0000-4000-8000-000000000001' and event_type='company_request_cancelled'),1,'Central Audit Trail records cancellation once');
select is((select actor_exact_role from public.v1_audit_events where entity_id='5dc20000-0000-4000-8000-000000000001' and event_type='company_request_approved'),'senior_mechanical_engineer','Audit keeps exact senior role');
select is((select count(*)::integer from public.v1_notifications where entity_id='5dc20000-0000-4000-8000-000000000001' and event_code='company_material_request_cancelled'),3,'Cancellation notifies receiver approver and Procurement exactly once');
select ok(not has_function_privilege('authenticated','public.v1_resolve_selected_company_approver(uuid,uuid,uuid[],uuid)','execute'),'Client cannot bypass protected approver preflight');
select ok(not has_function_privilege('authenticated','public.v1_save_company_material_request_draft_selection_base(jsonb)','execute'),'Client cannot bypass selected-approver validation');
select * from finish();rollback;
