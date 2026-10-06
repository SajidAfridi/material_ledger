-- Run only on the explicitly verified Yorks staging target. Every fixture,
-- grant, revision, audit and idempotency key below rolls back in this transaction.
begin;
do $$
declare
 admin_id uuid; accountant_id uuid; project_id uuid;
 general_id uuid := gen_random_uuid(); project_calc_id uuid := gen_random_uuid();
 saved_key uuid := gen_random_uuid(); intent jsonb; result jsonb;
begin
 select u.id into strict admin_id from auth.users u join public.v1_profiles p on p.auth_user_id=u.id
 where u.raw_app_meta_data->>'role'='admin' and p.is_active and u.deleted_at is null
 and (u.banned_until is null or u.banned_until <= now()) order by u.id limit 1;
 select u.id into strict accountant_id from auth.users u join public.v1_profiles p on p.auth_user_id=u.id
 where u.raw_app_meta_data->>'role'='accountant' and p.is_active and u.deleted_at is null
 and (u.banned_until is null or u.banned_until <= now()) order by u.id limit 1;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated','app_metadata',jsonb_build_object('role','admin'))::text,true);
 intent:=jsonb_build_object('id',general_id,'title','Transactional calculator witness','kind','duct','expected_version',0,
  'payload',jsonb_build_object('app','duct-calc','version',1,'flow','1000','future','preserved'));
 perform public.v1_save_calculator(intent,gen_random_uuid());
 perform public.v1_manage_calculator(jsonb_build_object('id',general_id,'expected_version',1,'action','access','user_id',accountant_id,'access','view'),gen_random_uuid());
 perform set_config('request.jwt.claims',jsonb_build_object('sub',accountant_id,'role','authenticated','app_metadata',jsonb_build_object('role','accountant'))::text,true);
 result:=public.v1_get_calculator(general_id);
 if result->>'can_edit'<>'false' then raise exception 'VIEW_GRANT_MUST_BE_READ_ONLY'; end if;
 if not exists(select 1 from jsonb_array_elements(public.v1_list_calculators()->'items') item where item->>'id'=general_id::text) then raise exception 'GRANTED_ACCOUNTANT_LIBRARY_MISSING'; end if;
 if public.v1_list_calculators()->>'can_create'<>'false' or public.v1_list_calculators()->>'can_manage'<>'false' then raise exception 'ACCOUNTANT_AUTHORITY_EXPANDED'; end if;
 begin
  perform public.v1_save_calculator(intent||jsonb_build_object('expected_version',2),gen_random_uuid());
  raise exception 'VIEWER_SAVE_UNEXPECTEDLY_SUCCEEDED';
 exception when insufficient_privilege then
  if sqlerrm<>'CALCULATOR_ACCESS_DENIED' then raise; end if;
 end;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated','app_metadata',jsonb_build_object('role','admin'))::text,true);
 perform public.v1_manage_calculator(jsonb_build_object('id',general_id,'expected_version',2,'action','access','user_id',accountant_id,'access','edit'),gen_random_uuid());
 perform set_config('request.jwt.claims',jsonb_build_object('sub',accountant_id,'role','authenticated','app_metadata',jsonb_build_object('role','accountant'))::text,true);
 result:=public.v1_save_calculator(intent||jsonb_build_object('expected_version',3,'title','Accountant scoped edit witness'),gen_random_uuid());
 if result->>'record_version'<>'4' or result->>'can_edit'<>'true' then raise exception 'ACCOUNTANT_EDIT_GRANT_FAILED'; end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated','app_metadata',jsonb_build_object('role','admin'))::text,true);
 result:=public.v1_create_project(jsonb_build_object('project_ref','CALC-WITNESS-'||upper(substr(gen_random_uuid()::text,1,8)),'name','Transactional archive witness',
  'buildings',jsonb_build_array(jsonb_build_object('code','A','name','A')),'initial_members','[]'::jsonb,'attachments','[]'::jsonb),gen_random_uuid());
 project_id:=(result->>'project_id')::uuid;
 intent:=intent||jsonb_build_object('id',project_calc_id,'project_id',project_id);
 perform public.v1_save_calculator(intent,saved_key);
 perform public.v1_archive_project(jsonb_build_object('project_id',project_id,'expected_version',1,'reason','Transactional archive witness'),gen_random_uuid());
 if exists(select 1 from jsonb_array_elements(public.v1_calculator_options()->'projects') p where p->>'id'=project_id::text) then raise exception 'ARCHIVED_PROJECT_IN_PICKER'; end if;
 begin
  perform public.v1_save_calculator(intent||jsonb_build_object('id',gen_random_uuid()),gen_random_uuid());
  raise exception 'ARCHIVED_PROJECT_CREATE_UNEXPECTEDLY_SUCCEEDED';
 exception when sqlstate '55000' then
  if sqlerrm<>'CALCULATOR_PROJECT_ARCHIVED' then raise; end if;
 end;
 begin
  perform public.v1_save_calculator(intent||jsonb_build_object('expected_version',1,'title','Rejected update'),gen_random_uuid());
  raise exception 'ARCHIVED_PROJECT_UPDATE_UNEXPECTEDLY_SUCCEEDED';
 exception when sqlstate '55000' then
  if sqlerrm<>'CALCULATOR_PROJECT_ARCHIVED' then raise; end if;
 end;
 result:=public.v1_get_calculator(project_calc_id);
 if result->>'can_edit'<>'false' or result->>'record_version'<>'1' or result->'payload'->>'future'<>'preserved' then raise exception 'ARCHIVE_READ_PROJECTION_FAILED'; end if;
 result:=public.v1_save_calculator(intent,saved_key);
 if result->>'can_edit'<>'false' or result->>'record_version'<>'1' then raise exception 'ARCHIVE_REPLAY_FAILED'; end if;
end $$;
select 'PASS: Accountant view/edit grants and archived-project create/update/replay protection; all fixtures rolled back' as verification;
rollback;
