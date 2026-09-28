-- Read-only Inventory workspace profile for the dedicated Yorks staging
-- project. Run through `supabase db query --linked --file ...` only after the
-- caller has verified the linked project ref. The in-script data guard then
-- refuses any target other than the dedicated local-test staging fixture.
-- EXPLAIN ANALYZE executes only the
-- STABLE projection RPC; the surrounding rolled-back transaction preserves
-- permanent state and the statement timeout bounds shared-staging impact.

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
    raise exception
      'INVENTORY_PROFILE_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
end;
$target_guard$;

create temporary table inventory_profile_results (
  profile_order integer generated always as identity,
  profile_label text not null,
  plan_line text not null
) on commit drop;

create function pg_temp.capture_inventory_explain(
  p_profile_label text,
  p_search text
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_plan_line text;
begin
  for v_plan_line in execute format(
    'explain (analyze, buffers, verbose, settings, summary) select public.v1_inventory_workspace_projection(%L)',
    p_search
  ) loop
    insert into pg_temp.inventory_profile_results (
      profile_label, plan_line
    ) values (p_profile_label, v_plan_line);
  end loop;
end;
$$;
grant execute on function pg_temp.capture_inventory_explain(text, text)
to authenticated;
grant select, insert on table pg_temp.inventory_profile_results
to authenticated;
grant usage, select on sequence inventory_profile_results_profile_order_seq
to authenticated;

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
      and (auth_user.banned_until is null
        or auth_user.banned_until <= clock_timestamp())
    order by profile.created_at
    limit 1
  ),
  true
);
set local role authenticated;

-- Exact full Inventory load issued by YorksV1LogisticsRepository.getInventory.
select pg_temp.capture_inventory_explain(
  'procurement_full_workspace', null
);

-- Representative filtered load. The response contract remains complete, but
-- item projection work should fall with the matching item set.
select pg_temp.capture_inventory_explain(
  'procurement_cable_search', 'cable'
);

reset role;
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
      and (auth_user.banned_until is null
        or auth_user.banned_until <= clock_timestamp())
    order by profile.created_at
    limit 1
  ),
  true
);
set local role authenticated;

-- Confirm the read-only exact role reaches the same RPC under its real JWT
-- boundary. A selective filter bounds the repeated staging workload.
select pg_temp.capture_inventory_explain(
  'senior_mechanical_engineer_cable_search', 'cable'
);

reset role;
select profile_label, plan_line
from pg_temp.inventory_profile_results
order by profile_order;
rollback;
