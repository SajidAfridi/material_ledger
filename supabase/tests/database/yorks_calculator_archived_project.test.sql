begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select lives_ok($test$select public.v1_create_project('{"project_ref":"CALC-ARCHIVE-TEST","name":"Calculator archive regression","buildings":[{"code":"A","name":"Building A"}],"initial_members":[],"attachments":[]}', '48000000-0000-4000-8000-000000000101')$test$, 'Create project fixture');
set local role postgres;
create temp table calculator_archive_fixture as
select id, jsonb_build_object('id','47000000-0000-4000-8000-000000000101',
 'project_id',id,'title','Archive regression','kind','duct','expected_version',0,
 'payload',jsonb_build_object('app','duct-calc','version',1,'flow','1000','future','preserved')) payload
from public.v1_projects where project_ref='CALC-ARCHIVE-TEST';
grant select on calculator_archive_fixture to authenticated;
insert into public.v1_project_members(project_id,member_auth_user_id,project_role,effective_from,reason,assigned_by_auth_user_id,assigned_by_role)
select id,'10000000-0000-4000-8000-000000000009','site_engineer',now()-interval '1 day','Test fixture','10000000-0000-4000-8000-000000000004','admin'
from calculator_archive_fixture;
set local role authenticated;
select lives_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture),'48000000-0000-4000-8000-000000000102')$test$, 'Nonarchived project accepts creation');
select is(public.v1_get_calculator('47000000-0000-4000-8000-000000000101')->>'can_edit','true','Live project calculator is editable');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select lives_ok($test$select public.v1_manage_calculator('{"id":"47000000-0000-4000-8000-000000000101","expected_version":1,"action":"access","user_id":"10000000-0000-4000-8000-000000000009","access":"edit"}', '49000000-0000-4000-8000-000000000101')$test$, 'Create explicit edit grant for role matrix');
select lives_ok($test$select public.v1_manage_calculator('{"id":"47000000-0000-4000-8000-000000000101","expected_version":2,"action":"access","user_id":"10000000-0000-4000-8000-000000000013","access":"edit"}', '49000000-0000-4000-8000-000000000103')$test$, 'Grant does not confer technical project membership on Accountant');
select lives_ok($test$select public.v1_archive_project(jsonb_build_object('project_id',(select id from calculator_archive_fixture),'expected_version',1,'reason','Archive regression fixture'),'49000000-0000-4000-8000-000000000102')$test$, 'Archive using trusted project command');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_calculator_options()->'projects') p where p->>'id'=(select id::text from calculator_archive_fixture)), 'Picker excludes archived project');
select throws_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture)||'{"id":"47000000-0000-4000-8000-000000000102"}'::jsonb,'48000000-0000-4000-8000-000000000103')$test$, '55000','CALCULATOR_PROJECT_ARCHIVED','Stale picker or direct RPC cannot create in archived project');
select throws_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture)||'{"expected_version":3,"title":"Must not save"}'::jsonb,'48000000-0000-4000-8000-000000000104')$test$, '55000','CALCULATOR_PROJECT_ARCHIVED','Existing calculator cannot save after project archive');
select is(public.v1_get_calculator('47000000-0000-4000-8000-000000000101')->>'can_edit','false','Read response exposes archived project as view only');
select is((select item->>'can_edit' from jsonb_array_elements(public.v1_list_calculators()->'items') item where item->>'id'='47000000-0000-4000-8000-000000000101'),'false','Library response exposes archived project as view only');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select lives_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture),'48000000-0000-4000-8000-000000000102')$test$, 'Previously committed intent can still be acknowledged after archive');
select is(public.v1_save_calculator((select payload from calculator_archive_fixture),'48000000-0000-4000-8000-000000000102')->>'can_edit','false','Replay rechecks current project editability');
select throws_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture)||'{"title":"Changed replay"}'::jsonb,'48000000-0000-4000-8000-000000000102')$test$, '22023','V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD','Archive does not weaken idempotency payload binding');
set local role postgres;
select is((select count(*) from public.v1_calculators where id in ('47000000-0000-4000-8000-000000000101','47000000-0000-4000-8000-000000000102')),1::bigint,'Rejected creation leaves no record');
select is((select record_version from public.v1_calculators where id='47000000-0000-4000-8000-000000000101'),3,'Rejected save and replays do not advance revision');
select is((select payload->>'future' from public.v1_calculators where id='47000000-0000-4000-8000-000000000101'),'preserved','Archive preserves calculator contents');
select is((select count(*) from public.v1_audit_events where entity_id='47000000-0000-4000-8000-000000000101' and event_type='calculator_saved'),1::bigint,'Only committed creation generates a save audit');
select is((select count(*) from public.v1_idempotency_keys where idempotency_key in ('48000000-0000-4000-8000-000000000103','48000000-0000-4000-8000-000000000104')),0::bigint,'Rejected commands leave no idempotency claims');

-- All nine exact roles; an edit grant never bypasses project access or archive.
-- Emit pgTAP results per role outside a DO block.
select set_config('calculator.test_roles','admin,project_engineer,site_engineer,senior_mechanical_engineer,project_manager,workshop_in_charge,document_controller,procurement,accountant',true);
create function pg_temp.check_archived_roles() returns setof text language plpgsql as $$
declare r text; denied boolean; actor uuid; begin
 for r in select unnest(string_to_array(current_setting('calculator.test_roles'),',')) loop
  actor:=case when r='accountant' then '10000000-0000-4000-8000-000000000013'::uuid else '10000000-0000-4000-8000-000000000009'::uuid end;
  update auth.users set raw_app_meta_data=raw_app_meta_data||jsonb_build_object('role',r) where id=actor;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor,'role','authenticated','app_metadata',jsonb_build_object('role',r))::text,true);
  denied:=r in ('procurement','accountant');
  return next throws_ok($test$select public.v1_save_calculator((select payload from calculator_archive_fixture)||'{"expected_version":3}'::jsonb,'48000000-0000-4000-8000-000000000105')$test$,
   case when denied then '42501' else '55000' end,
   case when denied then 'CALCULATOR_ACCESS_DENIED' else 'CALCULATOR_PROJECT_ARCHIVED' end,r||' cannot save into archived project');
 end loop;
end $$;
select * from pg_temp.check_archived_roles();
select * from finish();
rollback;
