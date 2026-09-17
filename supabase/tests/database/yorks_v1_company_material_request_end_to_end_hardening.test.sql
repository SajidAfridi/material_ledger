begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(23);

select ok(
  has_function_privilege('authenticated',
    'public.v1_list_company_material_request_register(text,integer)','execute')
  and has_function_privilege('authenticated',
    'public.v1_list_company_material_issue_notes(uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_withdraw_company_material_request_remainder(jsonb,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_company_material_request_projection(uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_company_material_request_projection_base(uuid)','execute')
  and not has_table_privilege('authenticated',
    'public.v1_company_material_issue_notes','select')
  and not has_table_privilege('authenticated',
    'public.v1_company_material_request_withdrawals','select'),
  'Company registers, issue evidence and withdrawals are available only through protected commands'
);

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

select is((select count(*) from public.v1_company_material_issue_notes
  where dispatch_id='c4000000-0000-4000-8000-000000000014'),1::bigint,
  'A committed dispatch creates exactly one immutable issue note');
select is((select snapshot#>>'{lines,0,quantity}' from public.v1_company_material_issue_notes
  where dispatch_id='c4000000-0000-4000-8000-000000000014'),'6.0000',
  'Issue note snapshots the committed quantity without commercial fields');
select throws_ok($$update public.v1_company_material_issue_notes set snapshot='{}'::jsonb
  where dispatch_id='c4000000-0000-4000-8000-000000000014'$$,
  '42501','V1_COMPANY_ISSUE_NOTE_IMMUTABLE','Issue-note history cannot be rewritten');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_confirm_company_material_handover(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',6,'acknowledgement_basis','beneficiary_confirmed',
    'lines',jsonb_build_array(jsonb_build_object(
      'receipt_line_id','c4000000-0000-4000-8000-000000000017','quantity','6'))),
  'c4000000-0000-4000-8000-000000000032')$$,
  '42501','V1_COMPANY_HANDOVER_DENIED',
  'An authorized receiver cannot impersonate beneficiary acknowledgement');
create temporary table cmr_witnessed as select public.v1_confirm_company_material_handover(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',6,'acknowledgement_basis','authorized_receiver_witnessed',
    'lines',jsonb_build_array(jsonb_build_object(
      'receipt_line_id','c4000000-0000-4000-8000-000000000017','quantity','6'))),
  'c4000000-0000-4000-8000-000000000033') response;
grant select on cmr_witnessed to authenticated;
select is((select response->>'state' from cmr_witnessed),'partially_received',
  'Witnessed handover preserves the four-unit outstanding need');
select is(jsonb_array_length(public.v1_list_company_material_issue_notes(
  'c4000000-0000-4000-8000-000000000010')),1,
  'An authorized receiver can read the immutable issue history');
select is(jsonb_array_length(public.v1_list_company_material_request_register(
  'issue_history',100)),1,'Issue history register exposes the attributable request');
select throws_ok($$select public.v1_list_company_material_request_register('planning',100)$$,
  '42501','V1_COMPANY_REGISTER_DENIED','Non-Procurement actors cannot browse company planning');

set local role postgres;
create temporary table revoked_return_line as
  select handover_line.id
  from public.v1_company_material_handover_lines handover_line
  join public.v1_company_material_handovers handover
    on handover.id=handover_line.handover_id
  where handover.request_id='c4000000-0000-4000-8000-000000000010'
  limit 1;
grant select on revoked_return_line to authenticated;
delete from public.v1_company_material_request_authorizations
  where auth_user_id='10000000-0000-4000-8000-000000000001'
    and category_id='c4000000-0000-4000-8000-000000000001'
    and responsible_unit_id='c4000000-0000-4000-8000-000000000002'
    and authority='receiver';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select ok(
  not (public.v1_company_material_request_projection(
    'c4000000-0000-4000-8000-000000000010')->>'can_handover')::boolean
  and not (public.v1_company_material_request_projection(
    'c4000000-0000-4000-8000-000000000010')->>'can_submit_return')::boolean,
  'Revoked receiver authority removes future custody actions from the projection');
select throws_ok($$select public.v1_submit_company_material_return(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'reason','Attempt after receiver revocation','lines',jsonb_build_array(
      jsonb_build_object('handover_line_id',(select id from revoked_return_line),
        'quantity','1'))),
  'c4000000-0000-4000-8000-000000000039')$$,
  '42501','V1_COMPANY_RETURN_DENIED',
  'Revoked receiver authority cannot submit a company return through the RPC');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_save_company_material_supply_plan(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',7,'lines',jsonb_build_array(jsonb_build_object(
      'request_line_id','c4000000-0000-4000-8000-000000000011','decision','full',
      'source_kind','external_supplier','inventory_item_id',null,'external_supplier','Supplier B',
      'arranged_qty','5','expected_available_date',(current_date+2)::text,
      'follow_up_date',null,'reason',null))),
  'c4000000-0000-4000-8000-000000000034')$$,
  '22023','V1_COMPANY_SUPPLY_PLAN_LINE_INVALID',
  'A revised plan cannot reserve or source beyond remaining approved need');
create temporary table cmr_remaining_plan as select public.v1_save_company_material_supply_plan(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',7,'lines',jsonb_build_array(jsonb_build_object(
      'request_line_id','c4000000-0000-4000-8000-000000000011','decision','full',
      'source_kind','external_supplier','inventory_item_id',null,'external_supplier','Supplier B',
      'arranged_qty','4','expected_available_date',(current_date+2)::text,
      'follow_up_date',null,'reason',null))),
  'c4000000-0000-4000-8000-000000000035') response;
grant select on cmr_remaining_plan to authenticated;
select is((select response#>>'{current_supply_plan,lines,0,arranged_qty}' from cmr_remaining_plan),
  '4.0000','A revised plan covers only open lines and ignores an already withdrawn line');
select is(jsonb_array_length(public.v1_list_company_material_request_register(
  'planning',100)),1,'Procurement planning includes the partially fulfilled demand');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_withdraw_company_material_request_remainder(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',8,'reason','Demand cancelled by management',
    'lines',jsonb_build_array(jsonb_build_object(
      'request_line_id','c4000000-0000-4000-8000-000000000011','quantity','4'))),
  'c4000000-0000-4000-8000-000000000036')$$,
  '42501','V1_COMPANY_WITHDRAWAL_DENIED',
  'The requester cannot approve withdrawal of its own outstanding demand');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
create temporary table cmr_withdrawal as select
  public.v1_withdraw_company_material_request_remainder(
    jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
      'expected_version',8,'reason','Demand cancelled by management',
      'lines',jsonb_build_array(jsonb_build_object(
        'request_line_id','c4000000-0000-4000-8000-000000000011','quantity','4'))),
    'c4000000-0000-4000-8000-000000000036') response;
grant select on cmr_withdrawal to authenticated;
select is((select response->>'state' from cmr_withdrawal),'fulfilled',
  'An approved withdrawal resolves only the four-unit unfulfilled balance');
select is((select response#>>'{lines,0,withdrawn_qty}' from cmr_withdrawal),'4.0000',
  'The projection preserves withdrawn quantity separately from approved need');
select is((select response#>>'{current_supply_plan,lines,0,arranged_qty}' from cmr_withdrawal),
  '0.0000','Withdrawal supersedes the former supply plan without leaving excess supply');
select is((select public.v1_withdraw_company_material_request_remainder(
  jsonb_build_object('request_id','c4000000-0000-4000-8000-000000000010',
    'expected_version',8,'reason','Demand cancelled by management',
    'lines',jsonb_build_array(jsonb_build_object(
      'request_line_id','c4000000-0000-4000-8000-000000000011','quantity','4'))),
  'c4000000-0000-4000-8000-000000000036')->>'record_version'),'9',
  'A lost withdrawal response retries without duplicating the command');

set local role postgres;
select throws_ok($$update public.v1_company_material_request_withdrawals
  set reason='Rewritten' where request_id='c4000000-0000-4000-8000-000000000010'$$,
  '42501','V1_COMPANY_WITHDRAWAL_IMMUTABLE',
  'Approved remainder withdrawal evidence cannot be rewritten');
select is((select count(*) from public.v1_company_material_request_events
  where request_id='c4000000-0000-4000-8000-000000000010'
    and event_type='company_request_remainder_withdrawn'),1::bigint,
  'Withdrawal retry appends exactly one audit event');
select is((select count(*) from public.v1_company_material_issue_notes
  where dispatch_id='c4000000-0000-4000-8000-000000000014'),1::bigint,
  'Planning revisions cannot duplicate the committed issue note');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is((public.v1_close_company_material_request(
  'c4000000-0000-4000-8000-000000000010',9,
  'c4000000-0000-4000-8000-000000000037')->>'state'),'closed',
  'Closure accepts good receipt plus independently approved withdrawal as resolved need');

select * from finish();
rollback;
