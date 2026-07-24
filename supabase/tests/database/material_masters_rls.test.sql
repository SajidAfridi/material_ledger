begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-master-admin","caps":[]}}',
  true
);

select lives_ok(
  $$insert into public."materialCategories" (id, data)
    values ('__rls_category__', '{"id":"__rls_category__","name":"Test","archived":false}'::jsonb)$$,
  'Admin can create a material category'
);

select lives_ok(
  $$insert into public."materialUnits" (id, data)
    values ('__rls_unit__', '{"id":"__rls_unit__","name":"Nos","symbol":"Nos","isCustom":false,"status":"approved"}'::jsonb)$$,
  'Admin can create an approved unit'
);

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-master-engineer","caps":[]}}',
  true
);

select is(
  (select count(*) from public."materialCategories" where id = '__rls_category__'),
  1::bigint,
  'Engineer can read category masters'
);

select throws_ok(
  $$insert into public."materialCategories" (id, data)
    values ('__engineer_denied__', '{"id":"__engineer_denied__","name":"Denied"}'::jsonb)$$,
  '42501'
);

select set_config(
  'request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-master-proc","caps":["goods"]}}',
  true
);

select throws_ok(
  $$insert into public."materialCategories" (id, data)
    values ('__proc_category_denied__', '{"id":"__proc_category_denied__","name":"Denied"}'::jsonb)$$,
  '42501'
);

select lives_ok(
  $$insert into public."materialUnits" (id, data)
    values (
      '__proc_pending_unit__',
      '{"id":"__proc_pending_unit__","name":"Coil","symbol":"coil","isCustom":true,"status":"pendingReview"}'::jsonb
    )$$,
  'Procurement can propose a pending custom unit'
);

select throws_ok(
  $$insert into public."materialUnits" (id, data)
    values (
      '__proc_approved_denied__',
      '{"id":"__proc_approved_denied__","name":"Coil","symbol":"coil","isCustom":true,"status":"approved"}'::jsonb
    )$$,
  '42501'
);

select lives_ok(
  $$update public."materialUnits"
    set data = data || '{"updatedBy":"Procurement"}'::jsonb
    where id = '__proc_pending_unit__'$$,
  'Procurement can safely replay its pending-unit upsert'
);

select throws_ok(
  $$update public."materialUnits"
    set data = data || '{"status":"approved"}'::jsonb
    where id = '__proc_pending_unit__'$$,
  '42501'
);

select * from finish();
rollback;
