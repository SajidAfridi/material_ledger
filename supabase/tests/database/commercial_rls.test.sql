begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(12);

set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-engineer","caps":[]}}',
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
  '{"role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-rls-read-only","caps":["viewCommercials"]}}',
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
  '{"role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-rls-proc","caps":["viewCommercials","goods"]}}',
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

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-rls-proc-no-commercial","caps":["goods"]}}',
  true
);

select is(
  (select count(*) from public.commercial_records),
  0::bigint,
  'Procurement without viewCommercials cannot read commercial records'
);

select throws_ok(
  $$insert into public.commercial_records
      (subject_type, subject_id, unit_cost_aed)
    values ('material', '__rls_denied_procurement__', 1)$$,
  '42501'
);

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-rls-legacy","caps":["cost","goods"]}}',
  true
);

select cmp_ok(
  (select count(*) from public.commercial_records),
  '>=',
  1::bigint,
  'Legacy cost claim remains readable during capability migration'
);

select * from finish();
rollback;
