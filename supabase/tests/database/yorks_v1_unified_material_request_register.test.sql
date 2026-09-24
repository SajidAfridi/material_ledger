begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
-- Rollback-only fixtures, uniquely named and independent of existing local data.
insert into public.v1_company_material_request_categories(id,category_code,display_name,is_active)
values('aa930000-0000-4000-8000-000000000001','unified_register_proof','Unified register proof',true);
insert into public.v1_company_material_request_units(id,unit_code,display_name,is_active)
values('aa930000-0000-4000-8000-000000000002','UNIFIED-REGISTER-PROOF','Unified register workshop',true);
insert into public.v1_company_material_request_approval_routes(id,category_id,responsible_unit_id,primary_approver_auth_user_id,policy_version,effective_from)
values('aa930000-0000-4000-8000-000000000003','aa930000-0000-4000-8000-000000000001','aa930000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004','register-proof',current_date);
insert into public.v1_company_material_request_authorizations(auth_user_id,category_id,responsible_unit_id,authority,effective_from)
values('10000000-0000-4000-8000-000000000004','aa930000-0000-4000-8000-000000000001','aa930000-0000-4000-8000-000000000002','approver',current_date-1);
insert into public.v1_company_material_requests(
 id,category_id,responsible_unit_id,purpose,timing,delivery_collection_point,
 beneficiary_auth_user_id,beneficiary_display_name,authorized_receiver_auth_user_id,authorized_receiver_display_name,
 created_by_auth_user_id,requester_display_name,requester_exact_role,state,record_version,
 request_number,submitted_at,approval_route_id,approval_policy_version,approver_auth_user_id,approver_display_name,updated_at)
select ('aa931000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'aa930000-0000-4000-8000-000000000001','aa930000-0000-4000-8000-000000000002','UNIFIED-REGISTER-PROOF Company '||i,'normal','Workshop',
 '10000000-0000-4000-8000-000000000001','Receiver','10000000-0000-4000-8000-000000000001','Receiver',
 '10000000-0000-4000-8000-000000000002','Register Site Engineer','site_engineer',
 case i when 122 then 'draft' when 123 then 'cancelled' when 124 then 'rejected' else 'awaiting_company_approval' end,2,
 case when i<>122 then 'UNIFIED-REGISTER-PROOF-C'||i end,
 case when i<>122 then now()-interval '1 day' end,
 case when i<>122 then 'aa930000-0000-4000-8000-000000000003'::uuid end,
 case when i<>122 then 'register-proof' end,
 case when i<>122 then '10000000-0000-4000-8000-000000000004'::uuid end,
 case when i<>122 then 'Admin approver' end,
 now()-i*interval '1 second'
from generate_series(1,124) i;
insert into public.v1_company_material_request_lines(id,request_id,display_order,item_description,requested_qty,unit)
select gen_random_uuid(),id,1,'Company catalogue needle',1,'pcs'
from public.v1_company_material_requests where purpose like 'UNIFIED-REGISTER-PROOF Company%';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select public.v1_create_project('{"project_ref":"UNIFIED-REGISTER-PROOF","name":"Unified register proof","parties":{},"initial_members":[{"auth_user_id":"10000000-0000-4000-8000-000000000002","project_role":"site_engineer","reason":"Test"}],"buildings":[{"code":"main","name":"Main"}],"attachments":[]}'::jsonb,'aa932000-0000-4000-8000-000000000001');
set local role postgres;
insert into public.v1_material_requests(id,project_id,scope_id,request_number,title,timing,state,record_version,created_by_auth_user_id,requester_display_name,requester_project_role,requester_exact_role,current_action_owner_role,current_action_code,submitted_at,updated_at)
select ('aa931000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,p.id,(select id from public.v1_project_scopes where project_id=p.id limit 1),
 'UNIFIED-REGISTER-PROOF-P'||i,'Project proof','normal','awaiting_request_approval',2,'10000000-0000-4000-8000-000000000002','Register Site Engineer','site_engineer','site_engineer','project_engineer','request_approval_required',now()-interval '1 day',now()-(i*2-0.5)*interval '1 second'
from public.v1_projects p cross join generate_series(1,2) i where p.project_ref='UNIFIED-REGISTER-PROOF';
-- Deliberately shared UUIDs across the independent tables exercise the discriminator.
create temporary table results(data jsonb);
grant all on results to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
insert into results select public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_limit=>100);
select is((select (data->>'total_count')::int from results),125,'Admin sees both request types, excluding another creator private draft');
select is((select jsonb_array_length(data->'items') from results),100,'Combined page has 100 records');
select is((select data->>'has_more' from results),'true','Combined page reports remaining records');
select is((select count(*)::int from results,jsonb_array_elements(data->'items') item where item->>'request_kind'='project'),2,'Chronological page includes Project records among Company requests');
select is(jsonb_array_length(public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_limit=>100,p_offset=>100)->'items'),25,'Second page includes records beyond Company 100-row boundary');
select is((select count(*)::int from results,jsonb_array_elements(data->'items') a join jsonb_array_elements(public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_limit=>100,p_offset=>100)->'items') b on a->>'id'=b->>'id' and a->>'request_kind'=b->>'request_kind'),0,'Stable combined pages have no duplicates');
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle')->>'total_count')::int,123,'Search finds Company line descriptions across all pages');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_metric=>'closed')->>'total_count')::int,2,'Cancelled and rejected requests remain visible as terminal records');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_states=>array['cancelled'])->'items'->0->>'state'),'cancelled','Company cancellation retains its native state');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_register_view=>'assigned')->>'total_count')::int,123,'Assigned uses the actual selected Company approver');
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle',p_register_view=>'my_work')->>'total_count')::int,121,'My Work includes pending independent approvals only');
select ok(not exists(select 1 from results,jsonb_array_elements(data->'items') item where item->>'request_kind'='company' and (item->>'project_id' is not null or item->>'scope_id' is not null)),'Company summaries do not invent Project or scope IDs');
select ok(not exists(select 1 from results,jsonb_array_elements(data->'items') item where item ?| array['unit_cost','total_cost','commercial','cost','lines']),'Register summaries contain no commercial data or full material payloads');
select is((public.v1_list_unified_material_request_summaries(p_project_id=>(select id from public.v1_projects where project_ref='UNIFIED-REGISTER-PROOF'))->>'total_count')::int,2,'Project-scoped register excludes Company requests');
select is((public.v1_list_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF')->>'total_count')::int,2,'Legacy Project summary endpoint is unchanged');
select throws_ok($$select public.v1_list_unified_material_request_summaries(p_sort=>null)$$,'42501','V1_MATERIAL_REQUEST_SUMMARY_LIST_DENIED','Null sort is rejected');
select throws_ok($$select public.v1_list_unified_material_request_summaries(p_search=>repeat('x',301))$$,'42501','V1_MATERIAL_REQUEST_SUMMARY_LIST_DENIED','Oversized searches are rejected');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF')->>'total_count')::int,126,'Site Engineer retains their Company draft plus both submitted request types');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_register_view=>'mine')->>'total_count')::int,126,'Mine combines both request types for the same creator');
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle',p_register_view=>'my_work')->>'total_count')::int,0,'Requester does not gain approval work');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle')->>'total_count')::int,123,'Named receiver can see submitted requests, not private drafts');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle')->>'total_count')::int,0,'Procurement cannot discover unapproved Company demand');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle')->>'total_count')::int,0,'Unrelated Accountant cannot discover Company requests');
set local role postgres;
update public.v1_company_material_request_authorizations set effective_to=current_date-1 where category_id='aa930000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle',p_register_view=>'my_work')->>'total_count')::int,0,'Revoked approval authority disappears from My Work immediately');
select is((public.v1_list_unified_material_request_summaries(p_search=>'Company catalogue needle')->>'total_count')::int,123,'Admin read oversight remains separate from action authority');
select ok(not has_function_privilege('anon','public.v1_list_unified_material_request_summaries(uuid,text,text[],uuid,text,timestamptz,boolean,text,text,integer,integer,text,text)','execute'),'Anonymous has no execute privilege');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_request_kind=>'project')->>'total_count')::int,2,'Project folders query only real Project requests');
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF',p_request_kind=>'company')->>'total_count')::int,123,'Explicit Company scope pages the full authorized set');
set local role postgres;
insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,scope_kind,reason,changed_by_auth_user_id)
values('aa934000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','material_requests.view','deny','organization','Register independent Company scope proof','10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select is((public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF')->>'total_count')::int,124,'Denied Project view does not prevent independently authorized Company records');
select is((public.v1_list_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF')->>'total_count')::int,0,'Project permission deny is still enforced in the same session');
set local role postgres;
update public.v1_company_material_requests set state='partially_received'
where id='aa931000-0000-4000-8000-000000000001';
set local role authenticated;
select is(public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF-C1',p_states=>array['partially_received'])->'items'->0->>'current_action_owner_role','procurement','Receipt exceptions return outstanding supply to Procurement');
select is(public.v1_list_unified_material_request_summaries(p_search=>'UNIFIED-REGISTER-PROOF-C1',p_states=>array['partially_received'])->'items'->0->>'current_action_code','arrange','Receipt exceptions show the replacement arrangement action');
select * from finish();
rollback;
