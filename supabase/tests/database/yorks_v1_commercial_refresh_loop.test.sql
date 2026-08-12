begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(2);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

-- Ensure the server-owned profile mirror is current before taking the value
-- that the second identical protected read must preserve.
select lives_ok(
  $$select public.v1_get_current_commercial_capabilities()$$,
  'The current commercial-capability lookup remains available to Procurement'
);

create temporary table yorks_v1_profile_before_repeat as
select updated_at
from public.v1_profiles
where auth_user_id = '10000000-0000-4000-8000-000000000003'::uuid;

select public.v1_get_current_commercial_capabilities();

select is(
  (
    select profile.updated_at
    from public.v1_profiles profile
    where profile.auth_user_id = '10000000-0000-4000-8000-000000000003'::uuid
  ),
  (select updated_at from yorks_v1_profile_before_repeat),
  'An unchanged capability refresh does not update v1_profiles or emit a self-refresh signal'
);

select * from finish();
rollback;
