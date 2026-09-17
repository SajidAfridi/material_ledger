begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select ok(not has_function_privilege('anon',
  'public.v1_get_audit_workspace_v2(text,text,text,timestamptz,timestamptz,integer,integer,uuid,uuid,text,text,uuid,text,text,timestamptz,timestamptz,uuid)','execute'),
  'Anonymous cannot investigate audit');
select ok(not has_table_privilege('authenticated','public.v1_audit_export_receipts','select')
  and not has_table_privilege('authenticated','public.v1_audit_export_receipts','insert'),
  'Export receipts cannot be read or inserted directly');
select ok((select relrowsecurity from pg_class where oid='public.v1_audit_export_receipts'::regclass),
  'Export receipts retain RLS');

insert into public.v1_audit_events(id,event_type,entity_type,entity_id,actor_auth_user_id,actor_role,actor_exact_role,occurred_at,before_data,after_data,reason)
values
('ad300000-0000-4000-8000-000000000001','material_request_cancelled','material_request',
 'ad310000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','admin','admin',
 '2026-01-02T00:00:00Z','{"state":"approved","unit_cost":"SECRET"}',
 '{"state":"cancelled","request_number":"INVESTIGATION-MR1","total_cost":"SECRET","record_version":2}','Investigation fixture'),
('ad300000-0000-4000-8000-000000000002','material_request_approved','material_request',
 'ad310000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','admin','admin',
 '2026-01-01T00:00:00Z','{"state":"submitted"}',
 '{"state":"approved","request_number":"INVESTIGATION-MR1","record_version":1}','Investigation fixture'),
('ad300000-0000-4000-8000-000000000003','company_request_submitted','company_material_request',
 'ad310000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004','admin','admin',
 '2026-01-03T00:00:00Z',null,'{"request_number":"INVESTIGATION-CO1"}','Investigation fixture');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select throws_ok($$select public.v1_get_audit_workspace_v2()$$,'42501','V1_AUDIT_WORKSPACE_ADMIN_REQUIRED','Project Engineer denied');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select throws_ok($$select public.v1_get_audit_workspace_v2()$$,'42501','V1_AUDIT_WORKSPACE_ADMIN_REQUIRED','Site Engineer denied');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select throws_ok($$select public.v1_get_audit_workspace_v2()$$,'42501','V1_AUDIT_WORKSPACE_ADMIN_REQUIRED','Procurement denied');
select throws_ok($$select public.v1_export_audit_workspace('{}','ad320000-0000-4000-8000-000000000001')$$,'42501','V1_AUDIT_WORKSPACE_ADMIN_REQUIRED','Procurement export denied');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"accountant"}}',true);
select throws_ok($$select public.v1_get_audit_workspace_v2()$$,'42501','V1_AUDIT_WORKSPACE_ADMIN_REQUIRED','Accountant denied even with Admin profile');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);

select is((public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_from=>'2026-01-01',p_to=>'2026-01-02')->>'filtered_count')::integer,1,'End-exclusive calendar boundary');
select is((public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_severity=>'critical')->'summary'->>'total_activities')::integer,1,'Summary uses the same combined filters');
select is((public.v1_get_audit_workspace_v2(p_entity_id=>'ad310000-0000-4000-8000-000000000001',p_entity_type=>'material_request')->>'filtered_count')::integer,2,'History uses stable identity');
select is((public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_scope=>'company')->>'filtered_count')::integer,1,'Company scope requires no fictional project');
select is(public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_scope=>'company')->'events'->0->>'module','material_requests','Company requests classified');
select ok(public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-')::text not like '%SECRET%','Before/after projection excludes commercial and unknown facts');
select is(public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_severity=>'critical')->'events'->0->'before_facts'->>'state','approved','Retained before-state available');
select is((public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-NONE')->'summary'->>'data_integrity_percent')::numeric,0::numeric,'Empty evidence does not imply complete attribution');
select is((public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_as_of=>'2026-01-02')->>'filtered_count')::integer,2,'As-of excludes later events');
select is(public.v1_get_audit_workspace_v2(p_search=>'INVESTIGATION-',p_cursor_at=>'2026-01-02',p_cursor_id=>'ad300000-0000-4000-8000-000000000001')->'events'->0->>'id',
 'ad300000-0000-4000-8000-000000000002','Cursor advances by immutable time and ID without repeating an earlier row');
select throws_ok($$select public.v1_get_audit_workspace_v2(p_severity=>'forged')$$,'22023','V1_AUDIT_FILTER_INVALID','Invalid severity rejected');

create temporary table export_result as select public.v1_export_audit_workspace(
 '{"p_search":"INVESTIGATION-"}', 'ad320000-0000-4000-8000-000000000001') as payload;
select is((select payload->>'filtered_count' from export_result),'3','Export includes all matching rows');
select is(public.v1_export_audit_workspace('{"p_search":"INVESTIGATION-"}','ad320000-0000-4000-8000-000000000001'),
 (select payload from export_result),'Retry returns immutable same export');
select throws_ok($$select public.v1_export_audit_workspace('{"p_search":"changed"}','ad320000-0000-4000-8000-000000000001')$$,'22023','V1_AUDIT_EXPORT_CONFLICT','Changed retry cannot reuse export identity');
reset role;
select is((select count(*)::integer from public.v1_audit_events where event_type='audit_export_generated' and entity_id='ad320000-0000-4000-8000-000000000001'),1,'Export audit emitted once');
insert into public.v1_audit_events(event_type,entity_type,entity_id,actor_auth_user_id,actor_role,actor_exact_role,reason)
select 'fixture_created','audit_fixture',gen_random_uuid(),'10000000-0000-4000-8000-000000000004','admin','admin','INVESTIGATION-LARGE' from generate_series(1,5001);
set local role authenticated;
select throws_ok($$select public.v1_export_audit_workspace('{"p_search":"INVESTIGATION-LARGE"}','ad320000-0000-4000-8000-000000000002')$$,'22023','V1_AUDIT_EXPORT_NARROW_RANGE','Oversize export never silently truncates');
reset role;
select is((select count(*)::integer from public.v1_audit_export_receipts where id='ad320000-0000-4000-8000-000000000002'),0,'Failed export leaves no receipt');
select * from finish();
rollback;
