begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(13);

select ok(exists (
  select 1 from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public'
    and tablename = 'materialCategories'
), 'Subscribed categories are in the Realtime publication');
select ok(exists (
  select 1 from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public'
    and tablename = 'materialUnits'
), 'Subscribed units are in the Realtime publication');
select ok((
  select count(*) = 2 and bool_and(relrowsecurity)
  from pg_class where relnamespace = 'public'::regnamespace
    and relname in ('materialCategories', 'materialUnits')
), 'Both published masters still enforce RLS');

insert into public."materialCategories" (id, data) values (
  '__performance_master_category__',
  '{"id":"__performance_master_category__","name":"Performance fixture"}'
);
insert into public."materialUnits" (id, data) values (
  '__performance_master_unit__',
  '{"id":"__performance_master_unit__","name":"Performance fixture","isCustom":false,"status":"approved"}'
);
create function pg_temp.performance_master_count() returns bigint
language plpgsql as $$
begin
  return (select count(*) from public."materialCategories"
    where id = '__performance_master_category__') +
    (select count(*) from public."materialUnits"
    where id = '__performance_master_unit__');
exception when insufficient_privilege then return 0;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-perf-pe"}}', true);
select is(pg_temp.performance_master_count(), 2::bigint,
  'Project Engineer can still read only the authorized master projection');
select throws_ok($$insert into public."materialCategories" (id,data)
  values ('__perf_pe_denied__','{}')$$, '42501');

select set_config('request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-perf-se"}}', true);
select is(pg_temp.performance_master_count(), 2::bigint,
  'Site Engineer retains master read access');
select throws_ok($$insert into public."materialUnits" (id,data)
  values ('__perf_se_denied__','{}')$$, '42501');

select set_config('request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-perf-proc"}}', true);
select is(pg_temp.performance_master_count(), 2::bigint,
  'Procurement retains master read access');
select throws_ok($$insert into public."materialCategories" (id,data)
  values ('__perf_proc_denied__','{}')$$, '42501');
select throws_ok($$insert into public."materialUnits" (id,data)
  values ('__perf_proc_unit_denied__','{"isCustom":true,"status":"approved"}')$$, '42501');

select set_config('request.jwt.claims',
  '{"role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-perf-admin"}}', true);
select is(pg_temp.performance_master_count(), 2::bigint,
  'Admin retains master read access');
select lives_ok($$insert into public."materialCategories" (id,data)
  values ('__perf_admin_allowed__','{"name":"Authorized fixture"}')$$,
  'Admin retains category creation authority');

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(pg_temp.performance_master_count(), 0::bigint,
  'Publication membership grants no anonymous master access');
set local role postgres;
select * from finish();
rollback;
