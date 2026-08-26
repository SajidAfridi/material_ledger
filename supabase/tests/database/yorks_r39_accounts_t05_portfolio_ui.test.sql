begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_accounts_portfolio(uuid,text,text,text,text,text,text,text,timestamptz,uuid,integer)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_get_project_accounts_overview(uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_accounts_portfolio_role_allowed()',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_project_accounts_overview(uuid)',
    'execute'
  ),
  'T05 exposes only the two protected authenticated projection RPCs'
);

insert into public.v1_projects (
  id, project_ref, name, project_site, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role, updated_at
) values
  (
    '39510000-0000-4000-8000-000000000001', 'R39-T05-001',
    'Accounts portfolio initialized project', 'Abu Dhabi', 'active',
    'project_engineer', '10000000-0000-4000-8000-000000000004',
    'admin', '2026-08-26 09:00:00+00'
  ),
  (
    '39510000-0000-4000-8000-000000000002', 'R39-T05-002',
    'Accounts portfolio uninitialized project', 'Dubai', 'active',
    'project_engineer', '10000000-0000-4000-8000-000000000004',
    'admin', '2026-08-26 08:00:00+00'
  );

insert into public.v1_project_parties (
  id, project_id, party_kind, party_name
) values (
  '39511000-0000-4000-8000-000000000001',
  '39510000-0000-4000-8000-000000000001',
  'client', 'T05 Client LLC'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable
) values
  (
    '39520000-0000-4000-8000-000000000001',
    '39510000-0000-4000-8000-000000000001',
    'building', 'b01', 'Building 01', false
  ),
  (
    '39520000-0000-4000-8000-000000000002',
    '39510000-0000-4000-8000-000000000002',
    'building', 'b01', 'Building 01', false
  );

insert into public.v1_project_members (
  project_id, member_auth_user_id, project_role, effective_from,
  reason, assigned_by_auth_user_id, assigned_by_role
) values
  (
    '39510000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', 'project_engineer',
    '2026-08-25 00:00:00+00', 'T05 project Accounts member',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '39510000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000002', 'site_engineer',
    '2026-08-25 00:00:00+00', 'T05 role-safe progress member',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

create temporary table v1_r39_t05_results (
  result_key text primary key,
  payload jsonb not null
);
grant select, insert, update on v1_r39_t05_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

insert into v1_r39_t05_results (result_key, payload)
select 'initialize', public.v1_initialize_project_commercial_baseline(
  '39510000-0000-4000-8000-000000000001',
  '1000000.00', 'AED', '5.0000', 20, 10,
  jsonb_build_array(jsonb_build_object(
    'building_scope_id', '39520000-0000-4000-8000-000000000001',
    'allocation_percent', '100.0000'
  )),
  null,
  '{"always_required":false}'::jsonb,
  'Initialize the T05 projection fixture',
  '39590000-0000-4000-8000-000000000001'
);

insert into v1_r39_t05_results (result_key, payload)
select 'admin_portfolio', public.v1_get_accounts_portfolio(
  null,null,null,null,null,null,null,null,null,null,25
);

select is(
  (select payload->>'actor_exact_role' from v1_r39_t05_results
    where result_key = 'admin_portfolio'),
  'admin',
  'Portfolio role comes from the protected exact-role claim'
);
select is(
  (select payload->>'authorized_project_count' from v1_r39_t05_results
    where result_key = 'admin_portfolio'),
  '2',
  'Admin portfolio sees every Accounts-authorized project without membership rows'
);
select is(
  (select payload->'totals'->>'contract_baseline'
    from v1_r39_t05_results where result_key = 'admin_portfolio'),
  '1000000.00',
  'Portfolio monetary values remain decimal strings'
);
select is(
  (select payload->'projects'->0->>'project_id'
    from v1_r39_t05_results where result_key = 'admin_portfolio'),
  '39510000-0000-4000-8000-000000000001',
  'Portfolio rows are ordered by latest authorized activity'
);

insert into v1_r39_t05_results (result_key, payload)
select 'empty_search', public.v1_get_accounts_portfolio(
  null,null,null,null,null,null,null,'no such project',null,null,25
);
select ok(
  (select payload->>'filtered_project_count' = '0'
      and payload->'totals'->>'project_count' = '2'
    from v1_r39_t05_results where result_key = 'empty_search'),
  'Filters narrow rows without changing portfolio totals'
);

insert into v1_r39_t05_results (result_key, payload)
select 'page_one', public.v1_get_accounts_portfolio(
  null,null,null,null,null,null,null,null,null,null,1
);
insert into v1_r39_t05_results (result_key, payload)
select 'page_two', public.v1_get_accounts_portfolio(
  null,null,null,null,null,null,null,null,
  (select (payload->'next_cursor'->>'before_activity_at')::timestamptz
    from v1_r39_t05_results where result_key = 'page_one'),
  (select (payload->'next_cursor'->>'before_project_id')::uuid
    from v1_r39_t05_results where result_key = 'page_one'),
  1
);
select ok(
  (select payload->'next_cursor' is not null
    from v1_r39_t05_results where result_key = 'page_one')
  and (select payload->'projects'->0->>'project_id'
    from v1_r39_t05_results where result_key = 'page_one')
    <> (select payload->'projects'->0->>'project_id'
      from v1_r39_t05_results where result_key = 'page_two'),
  'Keyset pagination returns the next project without skipping or repeating it'
);

select throws_ok(
  $sql$select public.v1_get_accounts_portfolio(
    null,null,'invalid',null,null,null,null,null,null,null,25
  )$sql$,
  '22023', 'R39_ACCOUNTS_INVALID_PORTFOLIO_FILTER',
  'Invalid portfolio filters fail closed on the server'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_get_accounts_portfolio(
    null,null,null,null,null,null,null,null,null,null,25
  )$sql$,
  '42501', 'R39_ACCOUNTS_ACCESS_DENIED',
  'Site Engineers cannot open an organization Accounts portfolio'
);
insert into v1_r39_t05_results (result_key, payload)
select 'site_project', public.v1_get_project_accounts_overview(
  '39510000-0000-4000-8000-000000000001'
);
select ok(
  (select payload ? 'progress' and payload ? 'baseline'
      and not (payload ? 'receivables') and not (payload ? 'supplier')
      and not ((payload->'baseline') ? 'contract_value')
      and position('1000000' in payload::text) = 0
    from v1_r39_t05_results where result_key = 'site_project'),
  'Site projection includes operational progress but omits all protected money and supplier domains'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $sql$select public.v1_get_accounts_portfolio(
    null,null,null,null,null,null,null,null,null,null,25
  )$sql$,
  '42501', 'R39_ACCOUNTS_ACCESS_DENIED',
  'Procurement cannot open the client-commercial portfolio'
);
insert into v1_r39_t05_results (result_key, payload)
select 'procurement_project', public.v1_get_project_accounts_overview(
  '39510000-0000-4000-8000-000000000001'
);
select ok(
  (select payload ? 'supplier'
      and not (payload ? 'baseline') and not (payload ? 'progress')
      and not (payload ? 'receivables')
      and payload->'capabilities'->>'view_supplier_costs' = 'true'
      and payload->'capabilities'->>'view_project_accounts' = 'false'
    from v1_r39_t05_results where result_key = 'procurement_project'),
  'Procurement receives a supplier-only project response shape'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant","app_user_id":"usr-local-accountant"}}',
  true
);
insert into v1_r39_t05_results (result_key, payload)
select 'accountant_portfolio', public.v1_get_accounts_portfolio(
  null,null,null,null,null,null,null,null,null,null,25
);
select ok(
  (select payload->>'actor_exact_role' = 'accountant'
      and payload->>'authorized_project_count' = '2'
    from v1_r39_t05_results where result_key = 'accountant_portfolio'),
  'Accountant receives the global project-scoped Accounts portfolio without technical membership'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select is(
  public.v1_get_accounts_portfolio(
    null,null,null,null,null,null,null,null,null,null,25
  )->>'authorized_project_count',
  '2',
  'Project Manager portfolio authority is organization-wide and Accounts-specific'
);

reset role;
select * from finish();
rollback;
