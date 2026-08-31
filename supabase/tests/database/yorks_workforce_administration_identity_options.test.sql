begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

-- Reproduce the production shape: a retained profile/app-user reference whose
-- Auth identity no longer has a valid server-controlled exact role.
update auth.users
set raw_app_meta_data = raw_app_meta_data - 'role'
where id = '10000000-0000-4000-8000-000000000010';

select is(
  public.v1_permission_exact_role(
    '10000000-0000-4000-8000-000000000010'
  ),
  '',
  'The regression fixture retains no exact server-controlled role'
);
select is(
  (
    select legacy_app_user_id
    from public.v1_profiles
    where auth_user_id = '10000000-0000-4000-8000-000000000010'
  ),
  'usr-local-project-manager',
  'The regression fixture still retains its preserved app-user identity'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_get_workforce_administration_options('2026-08-31')$$,
  'Admin options remain loadable when a preserved profile has no exact role'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_administration_options('2026-08-31')
        -> 'users'
    ) option
    where nullif(btrim(option ->> 'exact_role'), '') is null
  ),
  'Every returned login choice has a non-empty exact server role'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_administration_options('2026-08-31')
        -> 'users'
    ) option
    where option ->> 'app_user_id' = 'usr-local-project-manager'
  ),
  'The unassignable preserved identity is omitted without role inference'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_administration_options('2026-08-31')
        -> 'users'
    ) option
    where option ->> 'app_user_id' = 'usr-local-admin'
      and option ->> 'exact_role' = 'admin'
  ),
  'Valid assignable identities remain available to Admin'
);

select ok(
  public.v1_get_workforce_administration_options('2026-08-31')::text
    !~* 'email|commercial|unit_cost|total_cost',
  'The corrected choices still omit identity email and commercial data'
);

reset role;
select * from finish();
rollback;
