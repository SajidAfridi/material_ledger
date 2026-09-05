-- Yorks V1 bounded project startup projection.
--
-- This additive read-only RPC replaces four unbounded Overview queries with
-- exact lifecycle totals and a small non-commercial project card set. The
-- complete project/member/party/scope portfolio remains unchanged and is
-- fetched only inside the Projects workspace.
--
-- Rollback is forward-only: point the Overview back to the existing protected
-- portfolio repository and revoke this function in a corrective migration.
-- No stored project data is created, changed or removed.

create or replace function public.v1_project_overview(
  p_limit integer default 6
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 6), 1), 15);
  v_items jsonb;
  v_counts jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PROJECT_OVERVIEW_DENIED'
      using errcode = '42501';
  end if;

  with readable as materialized (
    select project.*
    from public.v1_projects project
    where public.v1_project_readable(project.id)
  ), bounded as (
    select project.*
    from readable project
    order by project.project_ref asc
    limit v_limit
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', project.id,
        'project_ref', project.project_ref,
        'name', project.name,
        'job_contract_reference', project.job_contract_reference,
        'project_site', project.project_site,
        'start_date', project.start_date,
        'target_completion_date', project.target_completion_date,
        'notes', project.notes,
        'state', project.state,
        'current_action_owner_role', project.current_action_owner_role,
        'record_version', project.record_version,
        'created_by_auth_user_id', project.created_by_auth_user_id,
        'created_at', project.created_at,
        'updated_at', project.updated_at,
        'client_name', (
          select party.party_name
          from public.v1_project_parties party
          where party.project_id = project.id
            and party.party_kind = 'client'
          order by party.party_order
          limit 1
        ),
        'active_building_count', (
          select count(*)
          from public.v1_project_scopes scope
          where scope.project_id = project.id
            and scope.scope_kind = 'building'
            and scope.is_active
        ),
        'active_project_engineer_count', (
          select count(*)
          from public.v1_project_members member
          where member.project_id = project.id
            and member.project_role = 'project_engineer'
            and member.effective_from <= current_timestamp
            and (
              member.effective_to is null
              or member.effective_to > current_timestamp
            )
        ),
        'active_site_engineer_count', (
          select count(*)
          from public.v1_project_members member
          where member.project_id = project.id
            and member.project_role = 'site_engineer'
            and member.effective_from <= current_timestamp
            and (
              member.effective_to is null
              or member.effective_to > current_timestamp
            )
        )
      ) order by project.project_ref asc
    ),
    '[]'::jsonb
  ) into v_items
  from bounded project;

  with readable as materialized (
    select project.state
    from public.v1_projects project
    where public.v1_project_readable(project.id)
  )
  select jsonb_build_object(
    'total', count(*),
    'active', count(*) filter (where state = 'active'),
    'on_hold', count(*) filter (where state = 'on_hold'),
    'completed', count(*) filter (where state = 'completed')
  ) into v_counts
  from readable;

  return jsonb_build_object('items', v_items, 'counts', v_counts);
end;
$$;

revoke all on function public.v1_project_overview(integer)
  from public, anon, authenticated;
grant execute on function public.v1_project_overview(integer)
  to authenticated, service_role;

comment on function public.v1_project_overview(integer)
is 'Bounded non-commercial first-screen project cards with exact authorized lifecycle totals.';

notify pgrst, 'reload schema';
