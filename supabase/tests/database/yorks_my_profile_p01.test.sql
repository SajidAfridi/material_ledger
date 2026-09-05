begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

create function pg_temp.profile_claim(p_id uuid, p_role text) returns text
language sql as $$
 select set_config('request.jwt.claims', jsonb_build_object(
   'sub',p_id,'role','authenticated','app_metadata',jsonb_build_object(
   'role',p_role,'app_user_id',(select legacy_app_user_id from public.v1_profiles where auth_user_id=p_id)
 ))::text,true)
$$;
-- Claim setup is test-only and invoked as postgres, never a public RPC.
select ok(has_function_privilege('authenticated',
 'public.v1_get_my_yorks_profile(integer,integer)','execute')
 and not has_function_privilege('anon',
 'public.v1_get_my_yorks_profile(integer,integer)','execute'),
 'Only authenticated clients may execute the new projection');
select is((select provolatile::text from pg_proc
 where oid='public.v1_get_my_yorks_profile(integer,integer)'::regprocedure),
 's','Projection is STABLE and cannot write data');

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"project_engineer"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','project_engineer');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','project_engineer',
 'project_engineer: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','project_engineer: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'project_engineer: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'project_engineer: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"site_engineer"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','site_engineer');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','site_engineer',
 'site_engineer: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','site_engineer: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'site_engineer: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'site_engineer: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"procurement"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','procurement');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','procurement',
 'procurement: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','procurement: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'procurement: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'procurement: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"admin"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','admin');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','admin',
 'admin: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','admin: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'admin: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'admin: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"accountant"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','accountant');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','accountant',
 'accountant: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','accountant: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'accountant: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'accountant: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"senior_mechanical_engineer"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','senior_mechanical_engineer');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','senior_mechanical_engineer',
 'senior_mechanical_engineer: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','senior_mechanical_engineer: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'senior_mechanical_engineer: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'senior_mechanical_engineer: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"project_manager"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','project_manager');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','project_manager',
 'project_manager: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','project_manager: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'project_manager: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'project_manager: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"workshop_in_charge"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','workshop_in_charge');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','workshop_in_charge',
 'workshop_in_charge: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','workshop_in_charge: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'workshop_in_charge: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'workshop_in_charge: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

update auth.users set raw_app_meta_data=jsonb_set(raw_app_meta_data,'{role}','"document_controller"')
 where id='10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','document_controller');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'account'->>'exact_role','document_controller',
 'document_controller: live exact job role is preserved');
select is(public.v1_get_my_yorks_profile()->'account'->>'auth_user_id',
 '10000000-0000-4000-8000-000000000010','document_controller: identity is self-only');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'kind'<>'navigation' or a->>'action_id' like '%workforce%'),
 'document_controller: no business command or role-only Workforce shortcut');
select ok(not public.v1_get_my_yorks_profile()::text ~
 '"(salary|pay_rate|unit_cost|total_cost|banned_until|raw_app_meta_data|candidate|assignment_id)"',
 'document_controller: no commercial, Auth internals or shadow candidate fields');
set local role postgres;

insert into public.v1_projects(id,project_ref,name,state,created_by_auth_user_id,created_by_role)
values ('ba010000-0000-4000-8000-000000000001','P01-A','Own scope','active',
 '10000000-0000-4000-8000-000000000004','admin'),
 ('ba010000-0000-4000-8000-000000000002','P01-B','Private scope','active',
 '10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_members(project_id,member_auth_user_id,project_role,
 effective_from,reason,assigned_by_auth_user_id,assigned_by_role)
values ('ba010000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
 'project_engineer',now()-interval '1 day','P01 test',
 '10000000-0000-4000-8000-000000000004','admin'),
 ('ba010000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002',
 'site_engineer',now()-interval '1 day','P01 test',
 '10000000-0000-4000-8000-000000000004','admin');

select pg_temp.profile_claim('10000000-0000-4000-8000-000000000001','project_engineer');
set local role authenticated;
select ok(exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000001'
 and p->>'technical_access'='true' and jsonb_array_length(p->'memberships')=1),
 'Project Engineer sees actual dated membership');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000002'),
 'Project Engineer cannot see another engineer project');
select throws_ok($$select public.v1_get_my_yorks_profile(-1,25)$$,'22023','V1_MY_PROFILE_PAGE_INVALID','Negative offset denied');
select throws_ok($$select public.v1_get_my_yorks_profile(0,51)$$,'22023','V1_MY_PROFILE_PAGE_INVALID','Unbounded page denied');
select throws_ok($$select public.v1_get_my_yorks_profile(null,25)$$,'22023','V1_MY_PROFILE_PAGE_INVALID','Null page denied');
select ok(jsonb_array_length(public.v1_get_my_yorks_profile(999999,25)->'projects'->'items')=0
 and public.v1_get_my_yorks_profile(999999,25)->'projects'->>'has_more'='false','Past-last page is honestly empty');
set local role postgres;

select pg_temp.profile_claim('10000000-0000-4000-8000-000000000002','site_engineer');
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000001'),
 'Site Engineer cannot see another engineer project');
set local role postgres;

select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','document_controller');
set local role authenticated;
select ok((select count(*)=2 and bool_and(jsonb_array_length(p->'memberships')=0)
 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id' in ('ba010000-0000-4000-8000-000000000001','ba010000-0000-4000-8000-000000000002')),
 'Global engineering scope does not invent project membership records');
select ok(jsonb_array_length(public.v1_get_my_yorks_profile(0,1)->'projects'->'items')=1
 and public.v1_get_my_yorks_profile(0,1)->'projects'->>'has_more'='true'
 and public.v1_get_my_yorks_profile(0,1)->'projects'->'items'->0->>'project_id'
 <> public.v1_get_my_yorks_profile(1,1)->'projects'->'items'->0->>'project_id',
 'Pagination has stable distinct pages and explicit incompleteness');
set local role postgres;

select pg_temp.profile_claim('10000000-0000-4000-8000-000000000013','accountant');
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'technical_access'='true' or jsonb_array_length(p->'memberships')>0),
 'Accountant never gains technical membership');
select ok(exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000001'
 and p->>'accounts_access'='true'),'Accountant can see authorized Accounts scope without technical membership');
set local role postgres;

insert into public.v1_permission_assignments(auth_user_id,capability_key,effect,scope_kind,effective_from,effective_until,reason)
values ('10000000-0000-4000-8000-000000000001','material_requests.view','deny','organization',
 now()-interval '1 day',now()+interval '1 hour','P01 explicit denial');
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000001','project_engineer');
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'action_id'='open_material_requests'),'An explicit deny removes the corresponding shortcut');
select ok((public.v1_get_my_yorks_profile()->>'next_transition_at')::timestamptz>statement_timestamp(),
 'Scheduled permission changes provide a refresh deadline');
set local role postgres;
update public.v1_permission_assignments set effective_until=now()-interval '1 minute'
 where auth_user_id='10000000-0000-4000-8000-000000000001' and capability_key='material_requests.view';
set local role authenticated;
select ok(exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'action_id'='open_material_requests'),'Expired denial no longer suppresses the role default');
set local role postgres;

insert into public.v1_permission_assignments(auth_user_id,capability_key,effect,scope_kind,effective_from,reason)
values ('10000000-0000-4000-8000-000000000001','chat.view','deny','organization',
 now()-interval '1 day','P01 shadow decision test');
set local role authenticated;
select ok(exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'action_id'='open_chat'),'Shadow candidate cannot replace authoritative legacy access');
set local role postgres;

insert into public.v1_permission_assignments(auth_user_id,capability_key,effect,scope_kind,effective_from,reason)
values ('10000000-0000-4000-8000-000000000001','analytics.view','grant','organization',
 now()-interval '1 day','P01 explicit delegation');
set local role authenticated;
select ok(exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') a
 where a->>'action_id'='open_analytics'),'Effective delegation adds a navigation action without changing exact role');
set local role postgres;
insert into public.v1_permission_assignments(auth_user_id,capability_key,effect,scope_kind,effective_from,reason)
values ('10000000-0000-4000-8000-000000000001','projects.view','deny','organization',
 now()-interval '1 day','P01 visibility revocation');
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000001'
 and (p->>'technical_access'='true' or jsonb_array_length(p->'memberships')>0)),
 'Revoked technical access hides membership while independent Accounts scope may remain');
set local role postgres;
insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,scope_kind,effective_from,reason)
values ('ba010000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001',
 'view_project_accounts','deny','project',now()-interval '1 day','P01 Accounts visibility revocation');
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
values ('ba010000-0000-4000-8000-000000000004','ba010000-0000-4000-8000-000000000001');
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_get_my_yorks_profile()->'projects'->'items') p
 where p->>'project_id'='ba010000-0000-4000-8000-000000000001'),
 'Revoking both technical and Accounts scopes removes project identity entirely');
set local role postgres;

insert into public.v1_workforce_workers(id,worker_number,full_name,designation,employer_company,
 worker_type,joining_date,linked_auth_user_id,notes,created_by_auth_user_id,updated_by_auth_user_id)
values ('ba010000-0000-4000-8000-000000000003','P01-W','PRIVATE WORKER NAME','Private trade',
 'Private company','temporary_worker',current_date,
 '10000000-0000-4000-8000-000000000001','PRIVATE HR NOTES',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
set local role authenticated;
select is(public.v1_get_my_yorks_profile()->'work_identity'->'workforce_worker'->>'worker_id',
 'ba010000-0000-4000-8000-000000000003','Only the explicit self worker link is exposed');
select ok(public.v1_get_my_yorks_profile()->'work_identity'->'workforce_worker'->>'grants_self_service'='false'
 and public.v1_get_my_yorks_profile()::text not like '%PRIVATE%'
 and public.v1_get_my_yorks_profile()->>'operational_summary_state'='not_projected',
 'Worker link grants no self-service and absent metrics are not fabricated');
set local role postgres;

-- Repeated reads must not mutate identity, permission revisions, or audit history.
create temp table p01_before as select
 (select md5(coalesce(jsonb_agg(to_jsonb(p) order by auth_user_id)::text,'')) from public.v1_profiles p) profiles,
 (select md5(coalesce(jsonb_agg(to_jsonb(r) order by auth_user_id)::text,'')) from public.v1_permission_revisions r) revisions;
set local role authenticated;
select lives_ok($$select public.v1_get_my_yorks_profile() from generate_series(1,3)$$,'Repeated reads succeed');
set local role postgres;
select ok((select profiles=(select md5(coalesce(jsonb_agg(to_jsonb(p) order by auth_user_id)::text,'')) from public.v1_profiles p)
 and revisions=(select md5(coalesce(jsonb_agg(to_jsonb(r) order by auth_user_id)::text,'')) from public.v1_permission_revisions r)
 from p01_before),'Repeated reads preserve profiles and permission revisions');

select pg_temp.profile_claim('10000000-0000-4000-8000-000000000010','project_manager');
set local role authenticated;
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501','V1_MY_PROFILE_DENIED',
 'Stale exact claim denied even when both roles normalize to Project Engineer');
set local role postgres;
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000001','engineer');
set local role authenticated;
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501','V1_MY_PROFILE_DENIED','Legacy engineer claim is not promoted');
set local role postgres;
select pg_temp.profile_claim('10000000-0000-4000-8000-000000000001','project_engineer');
update public.v1_profiles set is_active=false where auth_user_id='10000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501','V1_MY_PROFILE_DENIED','Inactive profile fails closed');
set local role postgres;
update public.v1_profiles set is_active=true where auth_user_id='10000000-0000-4000-8000-000000000001';
update auth.users set banned_until=now()+interval '1 day' where id='10000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501','V1_MY_PROFILE_DENIED','Banned user cannot read a profile');
select set_config('request.jwt.claims','{}',true);
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501','V1_MY_PROFILE_DENIED','Missing authenticated identity is denied');
set local role anon;
select throws_ok($$select public.v1_get_my_yorks_profile()$$,'42501',null,'Anonymous execution denied');
set local role postgres;
select * from finish();
rollback;
