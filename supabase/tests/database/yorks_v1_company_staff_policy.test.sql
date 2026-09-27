begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
select is((select count(*)::integer from v1_company_material_request_staff_policies),0,
  'Migration installs without implicit policy');
insert into v1_company_material_request_categories(category_code,display_name)
values ('staff_policy_test','Staff policy test');
insert into v1_company_material_request_units(unit_code,display_name)
values ('STAFF-POLICY-TEST','Staff policy test');
create temporary table policy_fixture as select c.id category_id,u.id unit_id
from v1_company_material_request_categories c cross join v1_company_material_request_units u
where c.category_code='staff_policy_test' and u.unit_code='STAFF-POLICY-TEST';
insert into v1_company_material_request_staff_policies(category_id,responsible_unit_id,policy_version)
select category_id,unit_id,'STAFF-TEST-1' from policy_fixture;
create temporary table staff_fixture as select gen_random_uuid() id,role
from unnest(array['project_engineer','site_engineer','procurement','admin','accountant',
  'senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller']) role;
insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data)
select id,id::text||'@staff-policy.local.test',jsonb_build_object('role',role),
  jsonb_build_object('full_name','Staff policy fixture') from staff_fixture;
-- New Auth accounts acquire only the explicitly configured Company scope.
select is((select count(*)::integer from v1_company_material_request_authorizations a
  where a.auth_user_id=s.id and a.category_id=f.category_id),
  case when s.role in ('site_engineer','procurement','accountant') then 3 else 4 end,
  s.role||' gets requester, beneficiary, receiver and only eligible approval')
from staff_fixture s cross join policy_fixture f order by s.role;
select ok(v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  s.role||' may request') from staff_fixture s cross join policy_fixture f order by s.role;
select is(v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'approver'),
  s.role not in ('site_engineer','procurement','accountant'),s.role||' approval stays role-safe')
from staff_fixture s cross join policy_fixture f order by s.role;
select is((select count(*)::integer from v1_company_material_request_staff_policy_events e
  join staff_fixture s on e.subject_auth_user_id=s.id),33,'Every generated grant has immutable provenance');
select is((select sum(v1_provision_company_material_request_staff_authorizations(id))::integer
  from staff_fixture),0,'Retry provisions no duplicate grants or events');
update v1_company_material_request_authorizations set effective_from=current_date-2,effective_to=current_date-1
where auth_user_id=(select id from staff_fixture where role='site_engineer') and authority='requester';
select is(v1_provision_company_material_request_staff_authorizations(
  (select id from staff_fixture where role='site_engineer')),0,'Provisioning never revives revoked authority');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Revocation denies subsequent requests') from staff_fixture s cross join policy_fixture f where s.role='site_engineer';
update auth.users set raw_app_meta_data=jsonb_build_object('role','site_engineer')
where id=(select id from staff_fixture where role='project_engineer');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'approver'),
  'Demotion immediately removes existing approver grant authority')
from staff_fixture s cross join policy_fixture f where s.role='project_engineer';
update auth.users set raw_app_meta_data=jsonb_build_object('role','project_engineer')
where id=(select id from staff_fixture where role='procurement');
select ok(v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'approver'),
  'Promotion provisions approver grant only in published scope')
from staff_fixture s cross join policy_fixture f where s.role='procurement';
update auth.users set raw_app_meta_data=jsonb_build_object('role','senior_mechanical_engineer')
where id=(select id from staff_fixture where role='procurement');
select ok(v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'approver'),
  'Global engineer canonical PE mirror remains valid')
from staff_fixture s cross join policy_fixture f where s.role='procurement';
update auth.users set banned_until=clock_timestamp()+interval '1 day'
where id=(select id from staff_fixture where role='admin');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Banned account cannot use retained grant') from staff_fixture s cross join policy_fixture f where s.role='admin';
update auth.users set deleted_at=clock_timestamp() where id=(select id from staff_fixture where role='accountant');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Soft-deleted account cannot use retained grant') from staff_fixture s cross join policy_fixture f where s.role='accountant';
update v1_profiles set is_active=false where auth_user_id=(select id from staff_fixture where role='project_manager');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'approver'),
  'Inactive profile denies retained approver grant') from staff_fixture s cross join policy_fixture f where s.role='project_manager';
update v1_profiles set canonical_role_snapshot='admin' where auth_user_id=(select id from staff_fixture where role='document_controller');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Inconsistent protected role mirror fails closed') from staff_fixture s cross join policy_fixture f where s.role='document_controller';
update auth.users set raw_app_meta_data=jsonb_build_object('role','engineer')
where id=(select id from staff_fixture where role='workshop_in_charge');
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Unknown legacy role gains no fallback access') from staff_fixture s cross join policy_fixture f where s.role='workshop_in_charge';
update v1_company_material_request_staff_policies set is_active=false;
select ok(not v1_company_material_request_active_authorization(s.id,f.category_id,f.unit_id,'requester'),
  'Disabling published policy removes automatically derived authority')
from staff_fixture s cross join policy_fixture f where s.role='senior_mechanical_engineer';
select throws_ok($$update v1_company_material_request_staff_policy_events set source_command='tampered'$$,
  '55000','V1_AUDIT_EVENTS_ARE_APPEND_ONLY','Provenance cannot be rewritten even by operator');
select throws_ok($$delete from v1_company_material_request_staff_policy_events$$,
  '55000','V1_AUDIT_EVENTS_ARE_APPEND_ONLY','Provenance cannot be deleted');
select ok(not has_function_privilege('authenticated',
  'v1_provision_company_material_request_staff_authorizations(uuid)','EXECUTE'),
  'Clients cannot provision their own authority');
select ok(not has_function_privilege('anon',
  'v1_provision_company_material_request_staff_authorizations(uuid)','EXECUTE'),
  'Anonymous provisioning denied');
select ok(not has_function_privilege('authenticated','v1_company_staff_policy_auth_trigger()','EXECUTE'),
  'Auth trigger has no public RPC execution');
select ok(not has_table_privilege('authenticated','v1_company_material_request_staff_policies','SELECT'),
  'Policy configuration is not exposed to clients');
select ok(not has_table_privilege('anon','v1_company_material_request_staff_policy_events','SELECT'),
  'Subject authority provenance is not anonymously exposed');
set local role authenticated;
select throws_ok($$select v1_provision_company_material_request_staff_authorizations(gen_random_uuid())$$,
  '42501',null,'Direct authenticated provisioning RPC denied');
select throws_ok($$insert into v1_company_material_request_staff_policies(category_id,responsible_unit_id,policy_version)
  values(gen_random_uuid(),gen_random_uuid(),'FORGED')$$,'42501',null,'Ordinary policy writes denied');
select throws_ok($$select * from v1_company_material_request_staff_policy_events$$,
  '42501',null,'Ordinary provenance reads denied');
set local role postgres;
select * from finish();
rollback;
