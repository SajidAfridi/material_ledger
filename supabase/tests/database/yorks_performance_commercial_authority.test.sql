begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(6);

-- Compare the old and consolidated server decisions, not role-based guesses.
-- These transaction-local fixtures do not depend on empty business tables.
create function pg_temp.commercial_snapshot_parity(
  p_auth_user_id uuid, p_role text, p_app_user_id text
) returns boolean language plpgsql as $$
declare
  v_snapshot jsonb;
  v_legacy jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_auth_user_id, 'role', 'authenticated',
    'app_metadata', jsonb_build_object('role', p_role,
      'app_user_id', p_app_user_id)
  )::text, true);
  v_snapshot := public.v1_get_current_permission_snapshot();
  v_legacy := public.v1_get_current_commercial_capabilities();
  return (
    select count(*) = 2 and bool_and(
      (capability ->> 'authoritative_effective')::boolean =
      (v_legacy -> 'capabilities' -> case capability ->> 'capability_key'
        when 'commercials.view' then 'view_commercials'
        else 'manage_commercials' end ->> 'effective')::boolean
    )
    from jsonb_array_elements(v_snapshot -> 'capabilities') capability
    where capability ->> 'capability_key' in (
      'commercials.view', 'commercials.manage'
    )
  );
end;
$$;

set local role authenticated;
select ok(pg_temp.commercial_snapshot_parity(
  '10000000-0000-4000-8000-000000000001', 'project_engineer',
  'usr-local-project-engineer'), 'Project Engineer commercial parity');
select ok(pg_temp.commercial_snapshot_parity(
  '10000000-0000-4000-8000-000000000002', 'site_engineer',
  'usr-local-site-engineer'), 'Site Engineer commercial parity');
select ok(pg_temp.commercial_snapshot_parity(
  '10000000-0000-4000-8000-000000000003', 'procurement',
  'usr-local-procurement'), 'Procurement commercial parity');
select ok(pg_temp.commercial_snapshot_parity(
  '10000000-0000-4000-8000-000000000004', 'admin',
  'usr-local-admin'), 'Admin commercial parity');

set local role postgres;
create temporary table performance_commercial_revision as
select revision from public.v1_permission_revisions
where auth_user_id = '10000000-0000-4000-8000-000000000003';
insert into public.v1_user_capabilities (
  auth_user_id, capability, is_granted, reason, changed_by_auth_user_id
) values (
  '10000000-0000-4000-8000-000000000003', 'view_commercials', false,
  'Performance consolidation revoke parity proof',
  '10000000-0000-4000-8000-000000000004'
) on conflict (auth_user_id, capability) do update
set is_granted = false,
    reason = excluded.reason,
    changed_by_auth_user_id = excluded.changed_by_auth_user_id;
select ok(
  (select revision from public.v1_permission_revisions
   where auth_user_id = '10000000-0000-4000-8000-000000000003') >
  (select revision from performance_commercial_revision),
  'Legacy commercial revocation signals the consolidated permission stream'
);

set local role authenticated;
select ok(
  pg_temp.commercial_snapshot_parity(
    '10000000-0000-4000-8000-000000000003', 'procurement',
    'usr-local-procurement'
  ) and not (public.v1_get_current_commercial_capabilities()
    -> 'capabilities' -> 'view_commercials' ->> 'effective')::boolean,
  'Revoked Procurement access stays denied with the same server decision'
);

select * from finish();
rollback;
