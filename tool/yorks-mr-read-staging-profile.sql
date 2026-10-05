-- Read-only MR detail/Procurement projection profile for the dedicated Yorks
-- technical staging project. EXPLAIN ANALYZE executes only STABLE projection
-- functions and the transaction is rolled back. The fixture guard refuses
-- production and any target containing non-local-test identities.

begin;
set local statement_timeout = '90s';
set local lock_timeout = '5s';

do $target_guard$
begin
  if (select count(*) from auth.users) <> 7
    or exists (
      select 1
      from auth.users auth_user
      where auth_user.email not like '%@yorks.local.test'
    ) then
    raise exception 'MR_READ_PROFILE_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
end;
$target_guard$;

create temporary table mr_read_profile_target (
  id uuid primary key
) on commit drop;
grant select, insert on table mr_read_profile_target to authenticated;

create temporary table mr_read_profile_results (
  profile_order integer generated always as identity,
  profile_label text not null,
  plan_line text not null
) on commit drop;

create function pg_temp.capture_mr_read_explain(
  p_profile_label text,
  p_function_name text
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_plan_line text;
begin
  for v_plan_line in execute format(
    'explain (analyze, buffers, verbose, settings, summary) '
      'select public.%I(target.id) '
      'from pg_temp.mr_read_profile_target target',
    p_function_name
  ) loop
    insert into pg_temp.mr_read_profile_results (
      profile_label, plan_line
    ) values (p_profile_label, v_plan_line);
  end loop;
end;
$$;
grant execute on function pg_temp.capture_mr_read_explain(text, text)
to authenticated;
grant select, insert on table mr_read_profile_results to authenticated;
grant usage, select on sequence mr_read_profile_results_profile_order_seq
to authenticated;

-- The technical fixture has no Workshop In-Charge identity. Senior Mechanical
-- Engineer exercises the same organization-wide engineering read boundary;
-- Workshop In-Charge remains covered by the identical non-Procurement client
-- branch and automated tests.
select set_config(
  'request.jwt.claims',
  (
    select jsonb_build_object(
      'sub', auth_user.id,
      'role', 'authenticated',
      'app_metadata', jsonb_build_object(
        'role', 'senior_mechanical_engineer',
        'app_user_id', auth_user.raw_app_meta_data ->> 'app_user_id'
      )
    )::text
    from auth.users auth_user
    join public.v1_profiles profile
      on profile.auth_user_id = auth_user.id
    where profile.is_active
      and auth_user.raw_app_meta_data ->> 'role' =
        'senior_mechanical_engineer'
    order by profile.created_at
    limit 1
  ),
  true
);

-- Use the same server predicate as the projection while retaining the
-- privileged test harness' ability to select a fixture row.
insert into mr_read_profile_target (id)
select request.id
from public.v1_material_requests request
where request.state <> 'draft'
  and public.v1_material_request_readable(request.id)
order by (
  select count(*)
  from public.v1_material_request_lines line
  where line.request_id = request.id
) desc,
request.updated_at desc,
request.id
limit 1;

set local role authenticated;

select pg_temp.capture_mr_read_explain(
  'global_engineering_material_request_projection',
  'v1_material_request_projection'
);

-- Procurement is the only ordinary role that needs the transactional
-- arrangement workspace on initial entry after this remediation.
reset role;
select set_config(
  'request.jwt.claims',
  (
    select jsonb_build_object(
      'sub', auth_user.id,
      'role', 'authenticated',
      'app_metadata', jsonb_build_object(
        'role', 'procurement',
        'app_user_id', auth_user.raw_app_meta_data ->> 'app_user_id'
      )
    )::text
    from auth.users auth_user
    join public.v1_profiles profile
      on profile.auth_user_id = auth_user.id
    where profile.is_active
      and auth_user.raw_app_meta_data ->> 'role' = 'procurement'
    order by profile.created_at
    limit 1
  ),
  true
);
set local role authenticated;

select pg_temp.capture_mr_read_explain(
  'procurement_arrangement_projection',
  'v1_arrangement_projection'
);

reset role;
select profile_label, plan_line
from mr_read_profile_results
order by profile_order;
rollback;
