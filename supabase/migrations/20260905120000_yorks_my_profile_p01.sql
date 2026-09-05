-- My Yorks P01: self-only, read-only profile contract. No role/template,
-- operational data, HR JSON, or existing consumer is changed.
-- Rollback: revoke authenticated execution of this new RPC. Preserve all data.
begin;

create or replace function public.v1_get_my_yorks_profile(
  p_project_offset integer default 0,
  p_project_limit integer default 25
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text;
  v_profile public.v1_profiles%rowtype;
  v_projects jsonb;
  v_total integer;
  v_capabilities jsonb;
  v_actions jsonb;
  v_worker uuid;
  v_next timestamptz;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MY_PROFILE_DENIED' using errcode = '42501';
  end if;
  if p_project_offset is null or p_project_offset < 0
    or p_project_limit is null or p_project_limit not between 1 and 50 then
    raise exception 'V1_MY_PROFILE_PAGE_INVALID' using errcode = '22023';
  end if;
  v_role := public.v1_current_exact_role();
  select * into strict v_profile from public.v1_profiles where auth_user_id = v_actor;

  -- Accounts visibility is independent of technical membership. Only project
  -- identifiers/names are returned; no Accounts value is selected or serialized.
  with candidates as materialized (
    select p.id, p.project_ref, p.name,
      public.v1_permission_actor_can_view_project(p.id) as technical_access,
      public.v1_current_user_has_capability('view_project_accounts', p.id) as accounts_access
    from public.v1_projects p
  ), visible as materialized (
    select * from candidates where technical_access or accounts_access
  ), bounded as (
    select * from visible order by project_ref, id
    offset p_project_offset limit p_project_limit
  )
  select (select count(*) from visible), coalesce(jsonb_agg(jsonb_build_object(
    'project_id', p.id, 'project_ref', p.project_ref, 'project_name', p.name,
    'technical_access', p.technical_access, 'accounts_access', p.accounts_access,
    'memberships', case when p.technical_access then (
      select coalesce(jsonb_agg(jsonb_build_object(
        'project_role', m.project_role, 'effective_from', m.effective_from,
        'effective_until', m.effective_to
      ) order by m.effective_from, m.id), '[]'::jsonb)
      from public.v1_project_members m
      where m.project_id = p.id and m.member_auth_user_id = v_actor
        and m.effective_from <= statement_timestamp()
        and (m.effective_to is null or m.effective_to > statement_timestamp())
    ) else '[]'::jsonb end
  ) order by p.project_ref, p.id), '[]'::jsonb)
  into v_total, v_projects from bounded p;

  -- Use authoritative resolution, never a shadow candidate or a role shortcut.
  -- A null organization decision means project context is required; it is not
  -- a denial or an organization-wide grant. Record commands still reauthorize.
  select coalesce(jsonb_agg(jsonb_build_object(
    'capability_key', c.capability_key, 'authorization_mode', c.authorization_mode,
    'requires_record_check', true,
    'organization', case when not c.requires_project_access then
      (select jsonb_build_object(
        'effective', coalesce((r.value ->> 'effective')::boolean, false),
        'source', r.value ->> 'source'
      ) from (select public.v1_permission_authoritative_resolution(
        v_actor, c.capability_key, null
      ) as value) r)
      else null end,
    'projects', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'project_id', p.value ->> 'project_id',
        'effective', coalesce((r.value ->> 'effective')::boolean, false),
        'source', r.value ->> 'source'
      ) order by p.value ->> 'project_id'), '[]'::jsonb)
      from jsonb_array_elements(v_projects) p(value)
      cross join lateral (select public.v1_permission_authoritative_resolution(
        v_actor, c.capability_key, (p.value ->> 'project_id')::uuid
      ) as value) r
      where 'project' = any(c.allowed_scope_kinds)
    )
  ) order by c.display_order, c.capability_key), '[]'::jsonb)
  into v_capabilities from public.v1_capability_catalog c
  where c.status = 'operational';

  -- P01 exposes workspace navigation only, never an executable business command.
  -- Project-scoped entries concern this page of scopes; has_more is explicit.
  with entries(action_id, capability_key, required_feature) as (values
    ('open_projects', 'projects.view', 'projects'),
    ('open_material_requests', 'material_requests.view', 'requests'),
    ('open_accounts', 'view_project_accounts', 'accounts'),
    ('open_inventory', 'inventory.view', 'inventory_suppliers'),
    ('open_returns', 'returns.view', 'returns_documents'),
    ('open_chat', 'chat.view', 'team_chat'),
    ('open_rentals', 'rentals.view', 'foundation'),
    ('open_users', 'users.view', 'foundation'),
    ('open_configuration', 'configuration.view', 'foundation'),
    ('open_audit', 'audit.view', 'foundation'),
    ('open_analytics', 'analytics.view', 'analytics')
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'action_id', e.action_id, 'capability_key', e.capability_key,
    'required_feature', e.required_feature, 'kind', 'navigation'
  ) order by e.action_id), '[]'::jsonb) into v_actions
  from entries e join jsonb_array_elements(v_capabilities) c(value)
    on c.value ->> 'capability_key' = e.capability_key
  where coalesce((c.value -> 'organization' ->> 'effective')::boolean, false)
    or exists (select 1 from jsonb_array_elements(c.value -> 'projects') p(value)
      where (p.value ->> 'effective')::boolean);

  -- Auth linkage proves only the link. It does not grant worker self-service,
  -- disclose employment/attendance, or reinterpret a legacy HR collection.
  select id into v_worker from public.v1_workforce_workers
  where linked_auth_user_id = v_actor;
  select min(t) into v_next from (
    select effective_from as t from public.v1_permission_assignments where auth_user_id = v_actor
    union all select effective_until from public.v1_permission_assignments where auth_user_id = v_actor
    union all select effective_from from public.v1_project_members where member_auth_user_id = v_actor
    union all select effective_to from public.v1_project_members where member_auth_user_id = v_actor
  ) transitions where t > statement_timestamp();

  return jsonb_build_object(
    'schema_version', 1, 'generated_at', statement_timestamp(), 'next_transition_at', v_next,
    'permission_revision', coalesce((select revision from public.v1_permission_revisions where auth_user_id = v_actor), 0),
    'account', jsonb_build_object(
      'auth_user_id', v_actor, 'app_user_id', v_profile.legacy_app_user_id,
      'display_name', v_profile.display_name,
      'email', (select email from auth.users where id = v_actor),
      'exact_role', v_role, 'status', 'active', 'workspace_key', v_role
    ),
    'work_identity', jsonb_build_object(
      'legacy_employee', jsonb_build_object('state', 'not_projected'),
      'workforce_worker', jsonb_build_object(
        'state', case when v_worker is null then 'unlinked' else 'linked' end,
        'worker_id', v_worker, 'grants_self_service', false
      )
    ),
    'projects', jsonb_build_object('total', v_total, 'offset', p_project_offset,
      'has_more', p_project_offset + jsonb_array_length(v_projects) < v_total,
      'items', v_projects),
    'capabilities', v_capabilities, 'actions', v_actions,
    'operational_summary_state', 'not_projected',
    'workforce_scope_state', 'requires_work_date_context'
  );
end;
$$;
revoke all on function public.v1_get_my_yorks_profile(integer, integer) from public, anon, authenticated;
grant execute on function public.v1_get_my_yorks_profile(integer, integer) to authenticated;
comment on function public.v1_get_my_yorks_profile(integer, integer) is
  'P01 self-only profile foundation. Read-only, bounded, exact live Auth identity; navigation is not command authority. No HR or commercial values.';
notify pgrst, 'reload schema';
commit;
