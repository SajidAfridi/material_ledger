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

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_my_yorks_profile_workspace()',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_my_yorks_profile_workspace()',
    'execute'
  ),
  'Only authenticated clients may execute the self workspace projection'
);
select ok(
  (select provolatile = 's' and prosecdef
   from pg_proc
   where oid = 'public.v1_get_my_yorks_profile_workspace()'::regprocedure)
  and (select proconfig = array['search_path=""']
       from pg_proc
       where oid = 'public.v1_get_my_yorks_profile_workspace()'::regprocedure),
  'The projection is STABLE, security definer, and has an empty search path'
);
select is(
  (select pronargs
   from pg_proc
   where oid = 'public.v1_get_my_yorks_profile_workspace()'::regprocedure),
  0::smallint,
  'The caller cannot select a user, role, project, worker, or date'
);
select ok(
  not has_table_privilege(
    'authenticated',
    'public.v1_workforce_workers',
    'select'
  ),
  'The protected profile does not open direct Workforce table access'
);

-- Exercise the two additional role boundaries required by the Yorks security
-- matrix before using the richer project fixtures below. Project Engineer and
-- Admin receive scoped assertions later in this file.
update auth.users
set raw_app_meta_data = jsonb_set(
  raw_app_meta_data, '{role}', '"site_engineer"'
)
where id = '10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000010',
  'site_engineer'
);
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'account'->>'exact_role'
      = 'site_engineer'
  and public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'grants_self_service' = 'false'
  and not public.v1_get_my_yorks_profile_workspace()::text ~
    '"(attendance|assignment_id|team_id|supervisor|mobile_number|notes|salary|pay_rate|unit_cost|total_cost|raw_app_meta_data|candidate)"',
  'Site Engineer receives only self-bound safe workspace facts'
);
set local role postgres;

update auth.users
set raw_app_meta_data = jsonb_set(
  raw_app_meta_data, '{role}', '"procurement"'
)
where id = '10000000-0000-4000-8000-000000000010';
select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000010',
  'procurement'
);
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'account'->>'exact_role'
      = 'procurement'
  and public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'grants_self_service' = 'false'
  and not public.v1_get_my_yorks_profile_workspace()::text ~
    '"(attendance|assignment_id|team_id|supervisor|mobile_number|notes|salary|pay_rate|unit_cost|total_cost|raw_app_meta_data|candidate)"',
  'Procurement receives only self-bound safe workspace facts'
);
set local role postgres;

insert into public.v1_projects(
  id, project_ref, name, state, created_by_auth_user_id, created_by_role
) values
  (
    'bc040000-0000-4000-8000-000000000001', 'P04-A',
    'My Yorks profile scope', 'active',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    'bc040000-0000-4000-8000-000000000002', 'P04-B',
    'Private profile scope', 'active',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );
insert into public.v1_project_scopes(
  id, project_id, scope_kind, scope_code, name, is_immutable
) values
  (
    'bc040000-0000-4000-8000-000000000011',
    'bc040000-0000-4000-8000-000000000001',
    'common', 'common', 'Common / All Buildings', true
  ),
  (
    'bc040000-0000-4000-8000-000000000012',
    'bc040000-0000-4000-8000-000000000002',
    'common', 'common', 'Common / All Buildings', true
  );
insert into public.v1_project_members(
  project_id, member_auth_user_id, project_role, effective_from,
  reason, assigned_by_auth_user_id, assigned_by_role
) values
  (
    'bc040000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    'project_engineer', now() - interval '1 day', 'P04/P05 test',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    'bc040000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'site_engineer', now() - interval '1 day', 'P04/P05 peer test',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

insert into public.v1_material_requests(
  id, project_id, scope_id, request_number, title, state,
  created_by_auth_user_id, requester_display_name, requester_project_role,
  current_action_owner_role, current_action_code, submitted_at
) values
  (
    'bc040000-0000-4000-8000-000000000021',
    'bc040000-0000-4000-8000-000000000001',
    'bc040000-0000-4000-8000-000000000011',
    'P04-MR-001', 'P04 open request', 'submitted',
    '10000000-0000-4000-8000-000000000001', 'P04 Engineer',
    'project_engineer', 'project_engineer', 'engineering_approval',
    now() - interval '1 hour'
  ),
  (
    'bc040000-0000-4000-8000-000000000022',
    'bc040000-0000-4000-8000-000000000001',
    'bc040000-0000-4000-8000-000000000011',
    'P04-MR-002', 'P04 closed request', 'closed',
    '10000000-0000-4000-8000-000000000001', 'P04 Engineer',
    'project_engineer', 'none', 'closed', now() - interval '2 hours'
  );

insert into public.v1_workforce_workers(
  id, worker_number, full_name, preferred_display_name, designation,
  department, employer_company, worker_type, mobile_number, joining_date,
  current_status, linked_auth_user_id, notes,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    'bc040000-0000-4000-8000-000000000031', 'P04-W-SELF',
    'Self Worker Full Name', 'Self Work Name', 'Project Engineer',
    'Projects', 'PRIVATE SELF EMPLOYER', 'temporary_worker',
    'PRIVATE SELF MOBILE', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000001', 'PRIVATE SELF NOTES',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    'bc040000-0000-4000-8000-000000000032', 'P04-W-PEER',
    'PRIVATE PEER WORKER', null, 'Private designation', null,
    'PRIVATE PEER EMPLOYER', 'agency_worker', 'PRIVATE PEER MOBILE',
    '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000002', 'PRIVATE PEER NOTES',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000001',
  'project_engineer'
);
set local role authenticated;
select is(
  public.v1_get_my_yorks_profile_workspace()->'account'->>'auth_user_id',
  '10000000-0000-4000-8000-000000000001',
  'The projection is bound to the signed-in account'
);
select is(
  public.v1_get_my_yorks_profile_workspace()->'account'->>'exact_role',
  'project_engineer',
  'The live exact role is preserved'
);
select is(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
    ->>'technical_project_count',
  '1',
  'Only the effective technical project scope is counted'
);
select is(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
    ->>'active_direct_membership_count',
  '1',
  'Only an effective visible direct membership is counted'
);
select ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.v1_get_my_yorks_profile_workspace()->'today'->'metrics'
    ) metric
    where metric->>'metric_key' = 'material_requests_open'
      and metric->>'value' = '1'
  ),
  'Only readable non-closed requests are summarized'
);
select ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.v1_get_my_yorks_profile_workspace()->'today'->'metrics'
    ) metric
    where metric->>'metric_key' = 'material_requests_needing_action'
      and metric->>'value' = '1'
  ),
  'The current-action count is resolved by the protected server predicate'
);
select is(
  public.v1_get_my_yorks_profile_workspace()->'work_identity'
    ->'legacy_employee'->>'state',
  'not_projected',
  'Legacy employee data is not treated as account authority'
);
select ok(
  public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'worker_id' =
        'bc040000-0000-4000-8000-000000000031'
  and public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'display_name' = 'Self Work Name'
  and public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'grants_self_service' = 'false',
  'A linked worker exposes only safe self identity and grants no authority'
);
select ok(
  public.v1_get_my_yorks_profile_workspace()::text not like '%PRIVATE%'
  and not public.v1_get_my_yorks_profile_workspace()::text ~
    '"(actions|attendance|assignment_id|team_id|supervisor|mobile_number|notes|joining_date|leaving_date|employer_company|trade_id|salary|pay_rate|unit_cost|total_cost|raw_app_meta_data|candidate)"',
  'The response excludes peer, HR, attendance, assignment, commercial, Auth, and candidate data'
);
select ok(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->>'accounts_portfolio_available' = 'false'
  and not exists(
    select 1
    from jsonb_array_elements(
      public.v1_get_my_yorks_profile_workspace()->'today'->'metrics'
    ) metric
    where metric->>'metric_key' = 'accounts_projects'
  ),
  'Project-specific Accounts visibility never becomes portfolio access'
);
set local role postgres;

update public.v1_workforce_workers
set current_status = 'left_company', leaving_date = current_date
where id = 'bc040000-0000-4000-8000-000000000031';
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'state' = 'linked'
  and public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'current_status' = 'left_company'
  and public.v1_get_my_yorks_profile_workspace()::text not like '%leaving_date%',
  'A leaver stays a truthful identity without leaking employment dates'
);
set local role postgres;

insert into public.v1_permission_assignments(
  auth_user_id, capability_key, effect, scope_kind,
  effective_from, effective_until, reason
) values (
  '10000000-0000-4000-8000-000000000001', 'analytics.view',
  'grant', 'organization', now() - interval '1 day',
  now() + interval '1 hour', 'P04 explicit grant source'
);
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->'effective_source_kinds' ? 'explicit_grant'
  and public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->'effective_source_kinds' ? 'role_default',
  'Effective navigation sources explain role and person-specific access'
);
select ok(
  (public.v1_get_my_yorks_profile_workspace()->>'next_transition_at')::timestamptz
    > statement_timestamp(),
  'A scheduled access change supplies an automatic refresh deadline'
);
set local role postgres;

insert into public.v1_permission_assignments(
  auth_user_id, capability_key, effect, scope_kind, effective_from, reason
) values (
  '10000000-0000-4000-8000-000000000001', 'projects.view',
  'deny', 'organization', now() - interval '1 day',
  'P04 revoked technical visibility'
);
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->>'technical_project_count' = '0'
  and public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->>'active_direct_membership_count' = '0',
  'A project denial removes project and direct-membership counts together'
);
select ok(
  not exists(
    select 1
    from jsonb_array_elements(
      public.v1_get_my_yorks_profile_workspace()->'today'->'metrics'
    ) metric
    where metric->>'metric_key' in (
      'technical_projects',
      'material_requests_needing_action',
      'material_requests_open'
    )
  ),
  'Denied project and request facts are omitted instead of rendered as zero'
);
select ok(
  not exists(
    select 1
    from jsonb_array_elements(public.v1_get_my_yorks_profile()->'actions') action
    where action->>'action_id' = 'open_projects'
  ),
  'P01 and the sidecar converge after an effective project denial'
);
set local role postgres;

select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000004',
  'admin'
);
set local role authenticated;
select ok(
  public.v1_get_my_yorks_profile_workspace()->'access_scope'
      ->>'accounts_portfolio_available' = 'true'
  and exists(
    select 1
    from jsonb_array_elements(
      public.v1_get_my_yorks_profile_workspace()->'today'->'metrics'
    ) metric
    where metric->>'metric_key' = 'accounts_projects'
  ),
  'An authorized portfolio role receives a server-confirmed Accounts summary'
);
select is(
  public.v1_get_my_yorks_profile_workspace()->'work_identity'
      ->'workforce_worker'->>'state',
  'unlinked',
  'A Yorks account without a worker link remains valid and explicit'
);
set local role postgres;

create temp table p04_before as select
  (select md5(coalesce(jsonb_agg(to_jsonb(profile) order by auth_user_id)::text,''))
   from public.v1_profiles profile) profiles,
  (select md5(coalesce(jsonb_agg(to_jsonb(revision) order by auth_user_id)::text,''))
   from public.v1_permission_revisions revision) revisions,
  (select md5(coalesce(jsonb_agg(to_jsonb(worker) order by id)::text,''))
   from public.v1_workforce_workers worker) workers;
set local role authenticated;
select lives_ok(
  $$select public.v1_get_my_yorks_profile_workspace() from generate_series(1,3)$$,
  'Repeated workspace reads succeed'
);
set local role postgres;
select ok(
  (select profiles = (
     select md5(coalesce(jsonb_agg(to_jsonb(profile) order by auth_user_id)::text,''))
     from public.v1_profiles profile
   ) and revisions = (
     select md5(coalesce(jsonb_agg(to_jsonb(revision) order by auth_user_id)::text,''))
     from public.v1_permission_revisions revision
   ) and workers = (
     select md5(coalesce(jsonb_agg(to_jsonb(worker) order by id)::text,''))
     from public.v1_workforce_workers worker
   ) from p04_before),
  'Repeated reads preserve account, permission, and worker state'
);

select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000004',
  'project_manager'
);
set local role authenticated;
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', 'V1_MY_PROFILE_WORKSPACE_DENIED',
  'A stale exact-role claim fails closed'
);
set local role postgres;
select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000001',
  'engineer'
);
set local role authenticated;
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', 'V1_MY_PROFILE_WORKSPACE_DENIED',
  'A legacy engineer claim is not promoted'
);
set local role postgres;
select pg_temp.profile_claim(
  '10000000-0000-4000-8000-000000000001',
  'project_engineer'
);
update public.v1_profiles
set is_active = false
where auth_user_id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', 'V1_MY_PROFILE_WORKSPACE_DENIED',
  'An inactive account cannot read workspace facts'
);
set local role postgres;
update public.v1_profiles
set is_active = true
where auth_user_id = '10000000-0000-4000-8000-000000000001';
update auth.users
set banned_until = now() + interval '1 day'
where id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', 'V1_MY_PROFILE_WORKSPACE_DENIED',
  'A banned account cannot read workspace facts'
);
select set_config('request.jwt.claims','{}',true);
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', 'V1_MY_PROFILE_WORKSPACE_DENIED',
  'A missing authenticated identity is denied'
);
set local role anon;
select throws_ok(
  $$select public.v1_get_my_yorks_profile_workspace()$$,
  '42501', null,
  'Anonymous execution is denied'
);
set local role postgres;

select * from finish();
rollback;
