begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(15);

-- Keep this test independent of production/demo data so it passes after a
-- clean local reset.
insert into public.commercial_records (
  subject_type,
  subject_id,
  unit_cost_aed,
  updated_by_app_user_id
)
values (
  'material',
  '__rls_visibility_fixture__',
  10,
  'usr-rls-fixture'
)
on conflict (subject_type, subject_id) do update
set unit_cost_aed = excluded.unit_cost_aed,
    updated_by_app_user_id = excluded.updated_by_app_user_id;

-- The retained shell may use legacy commercial caps only for a live Auth user
-- whose exact current role is `engineer` and who has never materialised a V1
-- profile.  Build those identities through auth.users so the RLS bridge cannot
-- be satisfied by a forged/stale JWT alone.
set local role postgres;
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_user_id,
  'authenticated',
  'authenticated',
  fixture.email,
  source.encrypted_password,
  clock_timestamp(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'role', fixture.app_role,
    'app_user_id', fixture.app_user_id,
    'caps', fixture.caps
  ),
  jsonb_build_object('full_name', 'Commercial RLS legacy fixture'),
  clock_timestamp(),
  clock_timestamp(),
  '',
  '',
  '',
  ''
from (
  values
    (
      '10000000-0000-4000-8000-000000000095'::uuid,
      'rls-legacy-mapped@yorks.local.test',
      'engineer',
      'usr-rls-legacy-mapped',
      jsonb_build_array('viewCommercials')
    ),
    (
      '10000000-0000-4000-8000-000000000096'::uuid,
      'rls-legacy-active@yorks.local.test',
      'engineer',
      'usr-rls-legacy-active',
      jsonb_build_array('cost', 'goods')
    ),
    (
      '10000000-0000-4000-8000-000000000097'::uuid,
      'rls-noncanonical@yorks.local.test',
      'former_engineer',
      'usr-rls-noncanonical',
      jsonb_build_array('viewCommercials')
    )
) as fixture(auth_user_id, email, app_role, app_user_id, caps)
cross join lateral (
  select encrypted_password
  from auth.users
  where id = '10000000-0000-4000-8000-000000000001'::uuid
) source;

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000095","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-legacy-mapped","caps":[]}}',
  true
);

select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'Engineer cannot read commercial records'
);

select throws_ok(
  $$insert into public.commercial_records
      (subject_type, subject_id, unit_cost_aed)
    values ('material', '__rls_denied_engineer__', 1)$$,
  '42501'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000095","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-legacy-mapped","caps":["viewCommercials"]}}',
  true
);

select cmp_ok(
  (select count(*) from public.commercial_records),
  '>=',
  1::bigint,
  'User with viewCommercials can read without goods'
);

select throws_ok(
  $$insert into public.commercial_records
      (subject_type, subject_id, unit_cost_aed)
    values ('material', '__rls_denied_read_only__', 1)$$,
  '42501'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement","caps":["viewCommercials","goods"]}}',
  true
);

select cmp_ok(
  (select count(*) from public.commercial_records),
  '>=',
  1::bigint,
  'Procurement with viewCommercials can read commercial records'
);

select lives_ok(
  $$insert into public.commercial_records
      (subject_type, subject_id, unit_cost_aed, updated_by_app_user_id)
    values ('material', '__rls_allowed_procurement__', 12.50, 'usr-rls-proc')$$,
  'Procurement with viewCommercials and goods can insert'
);

select lives_ok(
  $$update public.commercial_records
    set unit_cost_aed = 13.25
    where subject_type = 'material'
      and subject_id = '__rls_allowed_procurement__'$$,
  'Procurement with viewCommercials and goods can update'
);

select lives_ok(
  $$insert into public.materials (id, data)
    values (
      '__cost_strip_trigger__',
      '{"id":"__cost_strip_trigger__","unitPrice":99,"nested":[{"unitCostAED":88,"name":"safe"}]}'::jsonb
    )$$,
  'Operational write accepts a payload containing legacy commercial keys'
);

select is(
  (
    select data
    from public.materials
    where id = '__cost_strip_trigger__'
  ),
  '{"id":"__cost_strip_trigger__","nested":[{"name":"safe"}]}'::jsonb,
  'Operational trigger recursively strips commercial keys'
);

set local role postgres;
insert into public.v1_user_capabilities (
  auth_user_id,
  capability,
  is_granted,
  reason,
  changed_by_auth_user_id
)
values (
  '10000000-0000-4000-8000-000000000003'::uuid,
  'view_commercials',
  false,
  'V1 stale-JWT commercial revocation test',
  '10000000-0000-4000-8000-000000000004'::uuid
)
on conflict (auth_user_id, capability) do update
  set is_granted = excluded.is_granted,
      reason = excluded.reason,
      changed_by_auth_user_id = excluded.changed_by_auth_user_id,
      updated_at = clock_timestamp();
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement","caps":["viewCommercials","goods"]}}',
  true
);

select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'A V1 Procurement view revocation denies commercial reads despite stale JWT caps'
);

select throws_ok(
  $$insert into public.commercial_records
      (subject_type, subject_id, unit_cost_aed)
    values ('material', '__rls_denied_procurement__', 1)$$,
  '42501'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000096","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-legacy-active","caps":["cost","goods"]}}',
  true
);

select cmp_ok(
  (select count(*) from public.commercial_records),
  '>=',
  1::bigint,
  'Legacy cost claim remains readable during capability migration'
);

set local role postgres;
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"site_engineer"'::jsonb
   ) || jsonb_build_object(
     '_v1_admin_audit_context',
     jsonb_build_object(
       'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
       'action', 'role_changed',
       'idempotency_key', '60000000-0000-4000-8000-000000000001',
       'request_hash',
         'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
     )
   )
 where id = '10000000-0000-4000-8000-000000000095'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000095","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-legacy-mapped","caps":["viewCommercials"]}}',
  true
);
select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'A stale legacy engineer JWT cannot read after the live identity maps to a V1 role'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000097","role":"authenticated","app_metadata":{"role":"former_engineer","app_user_id":"usr-rls-noncanonical","caps":["viewCommercials"]}}',
  true
);
select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'Arbitrary noncanonical role/cap claims cannot enter the legacy commercial fallback'
);

set local role postgres;
update auth.users
   set banned_until = clock_timestamp() + interval '1 hour'
 where id = '10000000-0000-4000-8000-000000000096'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000096","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-legacy-active","caps":["cost","goods"]}}',
  true
);
select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'A banned legacy engineer cannot use retained commercial caps'
);

select * from finish();
rollback;
