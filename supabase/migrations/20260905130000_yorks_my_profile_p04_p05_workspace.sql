-- My Yorks P04/P05: protected, self-only workspace facts for the canonical
-- profile page. P01 remains the canonical identity/capability/action contract.
-- This sidecar never grants an action, reads a legacy employee record, or
-- exposes Workforce attendance, assignments, commercial values or HR notes.
-- Rollback: revoke authenticated execution of this new RPC. Preserve all data.
begin;

create or replace function public.v1_get_my_yorks_profile_workspace()
returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_technical_project_ids uuid[] := '{}'::uuid[];
  v_accounts_project_ids uuid[] := '{}'::uuid[];
  v_technical_project_count integer := 0;
  v_accounts_project_count integer := 0;
  v_direct_membership_count integer := 0;
  v_effective_source_kinds jsonb := '[]'::jsonb;
  v_today_metrics jsonb := '[]'::jsonb;
  v_worker_id uuid;
  v_worker_number text;
  v_worker_display_name text;
  v_worker_designation text;
  v_worker_department text;
  v_worker_type text;
  v_worker_status text;
  v_worker_found boolean := false;
  v_next timestamptz;
  v_projects_available boolean := false;
  v_material_requests_available boolean := false;
  v_accounts_portfolio_available boolean := false;
  v_open_material_requests integer := 0;
  v_material_requests_needing_action integer := 0;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MY_PROFILE_WORKSPACE_DENIED' using errcode = '42501';
  end if;

  v_role := public.v1_current_exact_role();
  if v_role = '' then
    raise exception 'V1_MY_PROFILE_WORKSPACE_DENIED' using errcode = '42501';
  end if;

  -- Technical and Accounts visibility deliberately remain separate. Neither
  -- count selects project names, commercial fields or membership history.
  select
    coalesce(array_agg(project.id order by project.id), '{}'::uuid[]),
    count(*)::integer
  into v_technical_project_ids, v_technical_project_count
  from public.v1_projects project
  where public.v1_permission_actor_can_view_project(project.id);

  select
    coalesce(array_agg(project.id order by project.id), '{}'::uuid[]),
    count(*)::integer
  into v_accounts_project_ids, v_accounts_project_count
  from public.v1_projects project
  where public.v1_current_user_has_capability(
    'view_project_accounts', project.id
  );

  select count(*)::integer into v_direct_membership_count
  from public.v1_project_members membership
  where membership.member_auth_user_id = v_actor
    and membership.project_id = any(v_technical_project_ids)
    and membership.effective_from <= statement_timestamp()
    and (
      membership.effective_to is null
      or membership.effective_to > statement_timestamp()
    );

  -- Only the P01 navigation capability set is summarized. This prevents a
  -- profile surface from becoming a low-level permission catalogue and keeps
  -- commercial/mutation capabilities outside this response shape.
  with selected_capability(capability_key) as (values
    ('projects.view'),
    ('material_requests.view'),
    ('view_project_accounts'),
    ('inventory.view'),
    ('returns.view'),
    ('chat.view'),
    ('rentals.view'),
    ('users.view'),
    ('configuration.view'),
    ('audit.view'),
    ('analytics.view')
  ), effective_decisions as materialized (
    select resolution.value ->> 'source' as source
    from selected_capability selected
    join public.v1_capability_catalog catalog
      on catalog.capability_key = selected.capability_key
     and catalog.status = 'operational'
    cross join lateral (
      select public.v1_permission_authoritative_resolution(
        v_actor, catalog.capability_key, null
      ) as value
    ) resolution
    where not catalog.requires_project_access
      and coalesce((resolution.value ->> 'effective')::boolean, false)

    union all

    select resolution.value ->> 'source' as source
    from selected_capability selected
    join public.v1_capability_catalog catalog
      on catalog.capability_key = selected.capability_key
     and catalog.status = 'operational'
    cross join lateral unnest(
      case when catalog.capability_key = 'view_project_accounts'
        then v_accounts_project_ids
        else v_technical_project_ids
      end
    ) as project_scope(project_id)
    cross join lateral (
      select public.v1_permission_authoritative_resolution(
        v_actor, catalog.capability_key, project_scope.project_id
      ) as value
    ) resolution
    where 'project' = any(catalog.allowed_scope_kinds)
      and coalesce((resolution.value ->> 'effective')::boolean, false)
  )
  select to_jsonb(coalesce(
    array_agg(distinct source order by source)
      filter (where source is not null and btrim(source) <> ''),
    '{}'::text[]
  )) into v_effective_source_kinds
  from effective_decisions;

  -- These summary gates are server decisions. The Flutter client still uses
  -- the P01 action identifiers and normal route/RPC guards before navigation.
  v_projects_available := public.v1_current_user_has_capability(
    'projects.view', null
  ) or cardinality(v_technical_project_ids) > 0;
  v_material_requests_available := public.v1_current_user_has_capability(
    'material_requests.view', null
  ) or exists (
    select 1
    from unnest(v_technical_project_ids) project_id
    where public.v1_current_user_has_capability(
      'material_requests.view', project_id
    )
  );
  v_accounts_portfolio_available := public.v1_accounts_portfolio_role_allowed()
    and public.v1_current_user_has_capability('view_project_accounts', null);

  if v_projects_available then
    v_today_metrics := v_today_metrics || jsonb_build_array(jsonb_build_object(
      'metric_key', 'technical_projects',
      'value', v_technical_project_count
    ));
  end if;

  if v_material_requests_available then
    select count(*)::integer into v_open_material_requests
    from public.v1_material_requests request_record
    where request_record.state not in ('closed', 'cancelled')
      and public.v1_material_request_participant(request_record.id, v_actor);

    select count(*)::integer into v_material_requests_needing_action
    from public.v1_material_requests request_record
    where request_record.state not in ('closed', 'cancelled')
      and public.v1_material_request_participant(request_record.id, v_actor)
      and public.v1_material_request_actor_has_current_action(
        request_record.id
      );

    v_today_metrics := v_today_metrics || jsonb_build_array(
      jsonb_build_object(
        'metric_key', 'material_requests_needing_action',
        'value', v_material_requests_needing_action
      ),
      jsonb_build_object(
        'metric_key', 'material_requests_open',
        'value', v_open_material_requests
      )
    );
  end if;

  -- The organization-wide Accounts portfolio has a stricter structural role
  -- rule than a project-scoped Accounts read. Do not make the profile a route
  -- bypass for someone who only has a project-specific commercial scope.
  if v_accounts_portfolio_available then
    v_today_metrics := v_today_metrics || jsonb_build_array(jsonb_build_object(
      'metric_key', 'accounts_projects',
      'value', v_accounts_project_count
    ));
  end if;

  -- A linked worker is self identity only. We intentionally omit contact
  -- data, employer, notes, employment dates, trade, team, supervisor,
  -- assignment, attendance, allocation and every commercial field.
  select
    worker.id,
    worker.worker_number,
    coalesce(worker.preferred_display_name, worker.full_name),
    worker.designation,
    worker.department,
    worker.worker_type,
    worker.current_status
  into
    v_worker_id,
    v_worker_number,
    v_worker_display_name,
    v_worker_designation,
    v_worker_department,
    v_worker_type,
    v_worker_status
  from public.v1_workforce_workers worker
  where worker.linked_auth_user_id = v_actor;
  v_worker_found := found;

  select min(transition_at) into v_next from (
    select effective_from as transition_at
    from public.v1_permission_assignments
    where auth_user_id = v_actor
    union all
    select effective_until
    from public.v1_permission_assignments
    where auth_user_id = v_actor
    union all
    select effective_from
    from public.v1_project_members
    where member_auth_user_id = v_actor
    union all
    select effective_to
    from public.v1_project_members
    where member_auth_user_id = v_actor
  ) transitions
  where transition_at > statement_timestamp();

  return jsonb_build_object(
    'schema_version', 1,
    'generated_at', statement_timestamp(),
    'next_transition_at', v_next,
    'permission_revision', coalesce((
      select revision
      from public.v1_permission_revisions
      where auth_user_id = v_actor
    ), 0),
    'account', jsonb_build_object(
      'auth_user_id', v_actor,
      'exact_role', v_role
    ),
    'today', jsonb_build_object(
      'state', 'available',
      'metrics', v_today_metrics
    ),
    'access_scope', jsonb_build_object(
      'technical_project_count', v_technical_project_count,
      'accounts_project_count', v_accounts_project_count,
      'active_direct_membership_count', v_direct_membership_count,
      'effective_source_kinds', v_effective_source_kinds,
      'accounts_portfolio_available', v_accounts_portfolio_available
    ),
    'work_identity', jsonb_build_object(
      'legacy_employee', jsonb_build_object('state', 'not_projected'),
      'workforce_worker', jsonb_build_object(
        'state', case when v_worker_found then 'linked' else 'unlinked' end,
        'worker_id', case when v_worker_found then v_worker_id else null end,
        'worker_number', case when v_worker_found then v_worker_number else null end,
        'display_name', case when v_worker_found then v_worker_display_name else null end,
        'designation', case when v_worker_found then v_worker_designation else null end,
        'department', case when v_worker_found then v_worker_department else null end,
        'worker_type', case when v_worker_found then v_worker_type else null end,
        'current_status', case when v_worker_found then v_worker_status else null end,
        'grants_self_service', false
      )
    )
  );
end;
$$;

revoke all on function public.v1_get_my_yorks_profile_workspace()
  from public, anon, authenticated;
grant execute on function public.v1_get_my_yorks_profile_workspace()
  to authenticated;
comment on function public.v1_get_my_yorks_profile_workspace() is
  'P04/P05 self-only My Yorks workspace facts. P01 remains identity/capability/action authority; no worker self-service, attendance, assignment, contact, HR notes or commercial values.';

notify pgrst, 'reload schema';
commit;
