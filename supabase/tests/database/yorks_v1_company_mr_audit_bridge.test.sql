begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(28);
set local role postgres;
insert into public.v1_company_material_request_categories(id,category_code,display_name)
values('c4000000-0000-4000-8000-000000000001','ppe_hardening','PPE hardening');
insert into public.v1_company_material_request_units(id,unit_code,display_name)
values('c4000000-0000-4000-8000-000000000002','HARDENING','Hardening unit');
insert into public.v1_company_material_request_authorizations(
  auth_user_id,category_id,responsible_unit_id,authority
) values
('10000000-0000-4000-8000-000000000002','c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000002','requester'),
('10000000-0000-4000-8000-000000000002','c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000002','beneficiary'),
('10000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000002','receiver'),
('10000000-0000-4000-8000-000000000004','c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000002','approver');
insert into public.v1_company_material_request_approval_routes(
  id,category_id,responsible_unit_id,primary_approver_auth_user_id,policy_version
) values('c4000000-0000-4000-8000-000000000003','c4000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004',
  'cmr-hardening-v1');
insert into public.v1_company_material_requests(
  id,request_number,state,record_version,category_id,responsible_unit_id,purpose,timing,
  delivery_collection_point,beneficiary_auth_user_id,beneficiary_display_name,
  authorized_receiver_auth_user_id,authorized_receiver_display_name,
  created_by_auth_user_id,requester_display_name,requester_exact_role,
  approval_route_id,approval_policy_version,approver_auth_user_id,approver_display_name,submitted_at
) values('c4000000-0000-4000-8000-000000000010','CMR-HARDENING','partially_received',6,
  'c4000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000002',
  'Issue ten safety jackets','normal','Workshop issue desk',
  '10000000-0000-4000-8000-000000000002','Site Engineer',
  '10000000-0000-4000-8000-000000000001','Project Engineer',
  '10000000-0000-4000-8000-000000000002','Site Engineer','site_engineer',
  'c4000000-0000-4000-8000-000000000003','cmr-hardening-v1',
  '10000000-0000-4000-8000-000000000004','Admin',clock_timestamp());
insert into public.v1_company_material_request_lines(
  id,request_id,display_order,item_description,requested_qty,unit
) values
('c4000000-0000-4000-8000-000000000011','c4000000-0000-4000-8000-000000000010',
  1,'Safety jacket size L',10,'Nos'),
('c4000000-0000-4000-8000-000000000018','c4000000-0000-4000-8000-000000000010',
  2,'Safety gloves',2,'Pairs');
insert into public.v1_company_material_request_withdrawals(
  id,request_id,reason,approved_by_auth_user_id,idempotency_key
) values('c4000000-0000-4000-8000-000000000019',
  'c4000000-0000-4000-8000-000000000010','Gloves no longer required',
  '10000000-0000-4000-8000-000000000004','c4000000-0000-4000-8000-000000000038');
insert into public.v1_company_material_request_withdrawal_lines(
  withdrawal_id,request_line_id,withdrawn_qty
) values('c4000000-0000-4000-8000-000000000019',
  'c4000000-0000-4000-8000-000000000018',2);
insert into public.v1_company_material_supply_plans(
  id,request_id,plan_version,is_current,saved_by_auth_user_id,superseded_at
) values('c4000000-0000-4000-8000-000000000012','c4000000-0000-4000-8000-000000000010',
  1,false,'10000000-0000-4000-8000-000000000003',clock_timestamp());
insert into public.v1_company_material_supply_lines(
  id,plan_id,request_line_id,decision,source_kind,external_supplier,arranged_qty,reason
) values('c4000000-0000-4000-8000-000000000013','c4000000-0000-4000-8000-000000000012',
  'c4000000-0000-4000-8000-000000000011','partial','external_supplier','Supplier A',6,
  'Initial partial supply');
insert into public.v1_company_material_dispatches(
  id,request_id,dispatch_number,state,dispatched_by_auth_user_id,idempotency_key
) values('c4000000-0000-4000-8000-000000000014','c4000000-0000-4000-8000-000000000010',
  'CM-DSP-9000001','received','10000000-0000-4000-8000-000000000003',
  'c4000000-0000-4000-8000-000000000030');
insert into public.v1_company_material_dispatch_lines(
  id,dispatch_id,supply_line_id,request_line_id,source_kind,dispatched_qty
) values('c4000000-0000-4000-8000-000000000015','c4000000-0000-4000-8000-000000000014',
  'c4000000-0000-4000-8000-000000000013','c4000000-0000-4000-8000-000000000011',
  'external_supplier',6);
insert into public.v1_company_material_receipts(
  id,dispatch_id,request_id,confirmed_by_auth_user_id,idempotency_key
) values('c4000000-0000-4000-8000-000000000016','c4000000-0000-4000-8000-000000000014',
  'c4000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000001',
  'c4000000-0000-4000-8000-000000000031');
insert into public.v1_company_material_receipt_lines(
  id,receipt_id,dispatch_line_id,request_line_id,outcome,good_qty,exception_qty
) values('c4000000-0000-4000-8000-000000000017','c4000000-0000-4000-8000-000000000016',
  'c4000000-0000-4000-8000-000000000015','c4000000-0000-4000-8000-000000000011',
  'received',6,0);
insert into public.v1_company_material_request_events(
  request_id,event_type,actor_auth_user_id,actor_exact_role,data,idempotency_key
) values('c4000000-0000-4000-8000-000000000010','company_material_dispatched',
  '10000000-0000-4000-8000-000000000003','procurement',
  jsonb_build_object('dispatch_id','c4000000-0000-4000-8000-000000000014'),
  'c4000000-0000-4000-8000-000000000030');


select ok(not has_function_privilege('authenticated', 'public.v1_company_material_request_projection_dispatch_review_base(uuid)', 'execute'), 'New internal projection cannot bypass the public API');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}', true);
create temporary table review_plan as select public.v1_save_company_material_supply_plan(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010', 'expected_version',6,
    'lines',jsonb_build_array(jsonb_build_object('request_line_id','c4000000-0000-4000-8000-000000000011',
      'decision','full','source_kind','external_supplier','external_supplier','Supplier A','arranged_qty','4'))),
  'c4000000-0000-4000-8000-000000000090') response;
select is((select response#>>'{current_supply_plan,lines,0,dispatchable_qty}' from review_plan),'4.0000', 'Replanned dispatch is capped by the four outstanding units');
select is((select response->>'can_dispatch' from review_plan),'true','Procurement can dispatch the outstanding plan');
create temporary table review_dispatch as select public.v1_dispatch_company_materials(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',(select (response->>'record_version')::integer from review_plan),
    'lines',jsonb_build_array(jsonb_build_object('supply_line_id',(select response#>>'{current_supply_plan,lines,0,id}' from review_plan), 'dispatch_qty','1'))),
  'c4000000-0000-4000-8000-000000000091') response;
select is((select response#>>'{current_supply_plan,lines,0,dispatchable_qty}' from review_dispatch),'3.0000', 'Partial dispatch review shows only three remaining units');
select ok(not (select response::text ~ 'unit_cost|total_cost|unit_price' from review_dispatch), 'Review exposes no commercial values');
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select is(public.v1_company_material_request_projection('c4000000-0000-4000-8000-000000000010')->>'can_dispatch','false','Authorized Project Engineer receiver cannot dispatch');
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}', true);
select is(public.v1_company_material_request_projection('c4000000-0000-4000-8000-000000000010')->>'can_dispatch','false','Site Engineer requester cannot dispatch');
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}', true);
select is(public.v1_company_material_request_projection('c4000000-0000-4000-8000-000000000010')->>'can_dispatch','false','Independent Admin approver cannot become Procurement');
select is((public.v1_company_material_request_workspace_page('requests','Issue ten safety jackets',0,1)->>'total_count')::integer, 1, 'Search counts only readable matching requests');
select is(jsonb_array_length(public.v1_company_material_request_workspace_page('requests','Issue ten safety jackets',1,1)->'items'), 0, 'Offset applies after the authorized search');
select is((public.v1_company_material_request_workspace_page('requests','unmatched-query',0,15)->>'total_count')::integer, 0, 'Search returns an honest empty count');
select throws_ok($$select public.v1_company_material_request_workspace_page('planning','',0,15)$$, '42501','V1_COMPANY_REGISTER_DENIED','Company approver cannot open Procurement planning through the paging endpoint');

set local role postgres;
select is((select count(*)::integer from public.v1_audit_events where entity_type='company_material_request' and entity_id='c4000000-0000-4000-8000-000000000010'),
  (select count(*)::integer from public.v1_company_material_request_events where request_id='c4000000-0000-4000-8000-000000000010'), 'Every Company event reaches the central audit ledger once');
select ok(not exists(select 1 from public.v1_company_material_request_events e join public.v1_audit_events a on a.id=e.id
  where e.request_id='c4000000-0000-4000-8000-000000000010' and (a.occurred_at<>e.occurred_at or a.actor_exact_role<>e.actor_exact_role)), 'Bridge preserves original timestamps and exact actor roles');
select public.v1_bridge_company_audit_event(id,false) from public.v1_company_material_request_events where request_id='c4000000-0000-4000-8000-000000000010';
select is((select count(*)::integer from public.v1_audit_events where entity_type='company_material_request' and entity_id='c4000000-0000-4000-8000-000000000010'),
  (select count(*)::integer from public.v1_company_material_request_events where request_id='c4000000-0000-4000-8000-000000000010'), 'Replaying bridge adds no duplicate audit evidence');
select ok(not exists(select 1 from public.v1_audit_events where entity_type='company_material_request' and after_data::text ~ 'unit_cost|total_cost|beneficiary_auth_user_id'), 'Central audit contains only allowlisted noncommercial metadata');
select ok(not has_function_privilege('authenticated','public.v1_bridge_company_audit_event(uuid,boolean)','execute'), 'Ordinary clients cannot manufacture audit events');
select ok(not has_function_privilege('anon','public.v1_bridge_company_audit_event(uuid,boolean)','execute'), 'Anonymous clients cannot manufacture audit events');
select ok(not has_table_privilege('authenticated','public.v1_company_material_request_events','insert'), 'Company source events remain server only');
select ok(not has_table_privilege('authenticated','public.v1_audit_events','update'), 'Central audit remains append only');
select is((select count(*)::integer from public.v1_audit_event_catalogue where event_type like 'company_%'),16,'All Company lifecycle events have severity classifications');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select ok(jsonb_array_length(public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')->'events')>0,'Project Engineer receiver can inspect readable Company evidence');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select ok(jsonb_array_length(public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')->'events')>0,'Site Engineer requester can inspect readable Company evidence');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select ok(jsonb_array_length(public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')->'events')>0,'Procurement can inspect readable Company evidence');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select ok(jsonb_array_length(public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')->'events')>0,'Assigned Admin approver can inspect readable Company evidence');
select ok(not has_function_privilege('anon','public.v1_company_material_request_evidence(uuid)','execute'),'Anonymous cannot inspect Company evidence');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select throws_ok($$select public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Unrelated senior engineer cannot read Company evidence');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant","app_user_id":"usr-local-accountant"}}',true);
select throws_ok($$select public.v1_company_material_request_evidence('c4000000-0000-4000-8000-000000000010')$$,'42501','V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE','Accountant cannot read Company evidence');
select * from finish();
rollback;
