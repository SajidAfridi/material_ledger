-- Keep the lightweight current-user permission projection comfortably below
-- PostgREST's statement timeout. The original implementation reused the full
-- administrative workspace builder and consequently recomputed delegation,
-- history and project visibility many times for every catalogue row.
--
-- This migration is additive and decision-preserving: the existing role
-- templates, person assignments, resolver, RLS and trusted command checks are
-- unchanged. Only the JSON projection path is replaced. Rollback may restore
-- the prior function bodies without deleting permission data or audit history.

create or replace function public.v1_permission_capability_projection_json(
  p_target_auth_user_id uuid,
  p_capability_key text,
  p_actor_exact_role text,
  p_actor_can_manage boolean,
  p_actor_can_delegate_permissions boolean,
  p_actor_has_unrestricted_projects boolean,
  p_actor_visible_project_ids uuid[],
  p_target_visible_project_ids uuid[],
  p_include_shadow_project_rows boolean
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_catalog public.v1_capability_catalog%rowtype;
  v_target_exact_role text;
  v_role_default boolean := false;
  v_actor_template_can_delegate boolean := false;
  v_actor_can_delegate boolean := false;
  v_actor_delegable_scope_kinds text[] := '{}'::text[];
  v_organization_summary_visible boolean;
  v_authoritative jsonb;
  v_candidate jsonb;
  v_project_rows jsonb := '[]'::jsonb;
  v_actor_visible_project_ids uuid[] := coalesce(
    p_actor_visible_project_ids, '{}'::uuid[]
  );
  v_target_visible_project_ids uuid[] := coalesce(
    p_target_visible_project_ids, '{}'::uuid[]
  );
begin
  select * into v_catalog
  from public.v1_capability_catalog catalog
  where catalog.capability_key = p_capability_key;
  if not found then
    return null;
  end if;

  v_target_exact_role := public.v1_permission_exact_role(
    p_target_auth_user_id
  );
  select role_default.is_granted into v_role_default
  from public.v1_permission_role_defaults role_default
  where role_default.role_name = v_target_exact_role
    and role_default.capability_key = p_capability_key;
  select role_default.can_delegate into v_actor_template_can_delegate
  from public.v1_permission_role_defaults role_default
  where role_default.role_name = p_actor_exact_role
    and role_default.capability_key = p_capability_key;

  v_actor_can_delegate := coalesce(p_actor_can_manage, false)
    and (
      p_capability_key not like 'permissions.%'
      or coalesce(p_actor_can_delegate_permissions, false)
    )
    and coalesce(v_actor_template_can_delegate, false);

  if v_catalog.status = 'operational'
    and v_catalog.is_assignable
    and v_actor_can_delegate then
    if 'organization' = any(v_catalog.allowed_scope_kinds)
      and (
        not v_catalog.requires_project_access
        or coalesce(p_actor_has_unrestricted_projects, false)
      ) then
      v_actor_delegable_scope_kinds := array_append(
        v_actor_delegable_scope_kinds, 'organization'
      );
    end if;
    if 'project' = any(v_catalog.allowed_scope_kinds)
      and cardinality(v_actor_visible_project_ids) > 0 then
      v_actor_delegable_scope_kinds := array_append(
        v_actor_delegable_scope_kinds, 'project'
      );
    end if;
  end if;

  v_organization_summary_visible := not v_catalog.requires_project_access
    or coalesce(p_actor_has_unrestricted_projects, false);
  if v_organization_summary_visible then
    v_candidate := public.v1_permission_candidate_resolution(
      p_target_auth_user_id, p_capability_key, null
    );
    v_authoritative := case
      when v_catalog.authorization_mode = 'enforced' then v_candidate
      else public.v1_permission_legacy_resolution(
        p_target_auth_user_id, p_capability_key, null
      )
    end;
  end if;

  if v_catalog.requires_project_access
    and (
      coalesce(p_include_shadow_project_rows, false)
      or (
        v_catalog.status = 'operational'
        and v_catalog.authorization_mode = 'enforced'
      )
    )
    and cardinality(v_target_visible_project_ids) > 0 then
    with target_project as materialized (
      select project.id, project.project_ref, project.name
      from public.v1_projects project
      where project.id = any(v_target_visible_project_ids)
    ), candidate as materialized (
      select
        project.id,
        project.project_ref,
        project.name,
        public.v1_permission_candidate_resolution(
          p_target_auth_user_id, p_capability_key, project.id
        ) as resolution
      from target_project project
    ), resolved as materialized (
      select
        candidate.id,
        candidate.project_ref,
        candidate.name,
        candidate.resolution as candidate_resolution,
        case
          when v_catalog.authorization_mode = 'enforced'
            then candidate.resolution
          else public.v1_permission_legacy_resolution(
            p_target_auth_user_id, p_capability_key, candidate.id
          )
        end as authoritative_resolution
      from candidate
    ), ranked_assignment as materialized (
      select
        project.id as project_id,
        assignment.id,
        assignment.effect,
        assignment.effective_from,
        assignment.effective_until,
        not exists (
          select 1
          from public.v1_permission_assignment_projects complete_scope
          where complete_scope.assignment_id = assignment.id
            and not (
              complete_scope.project_id = any(v_actor_visible_project_ids)
            )
        ) as scope_fully_visible,
        row_number() over (
          partition by project.id
          order by assignment.effect, assignment.id
        ) as row_number
      from target_project project
      join public.v1_permission_assignment_projects assignment_project
        on assignment_project.project_id = project.id
      join public.v1_permission_assignments assignment
        on assignment.id = assignment_project.assignment_id
       and assignment.auth_user_id = p_target_auth_user_id
       and assignment.capability_key = p_capability_key
       and assignment.scope_kind = 'project'
    ), selected_assignment as materialized (
      select *
      from ranked_assignment
      where row_number = 1
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'assignment_id', case when assignment.scope_fully_visible
        then assignment.id else null end,
      'project_id', resolved.id,
      'project_ref', resolved.project_ref,
      'project_name', resolved.name,
      'effect', case when assignment.scope_fully_visible
        then assignment.effect else null end,
      'has_project_access', true,
      'authoritative_effective', coalesce((
        resolved.authoritative_resolution ->> 'effective'
      )::boolean, false),
      'authoritative_source', coalesce(
        resolved.authoritative_resolution ->> 'source', 'unknown'
      ),
      'candidate_effective', coalesce((
        resolved.candidate_resolution ->> 'effective'
      )::boolean, false),
      'candidate_source', coalesce(
        resolved.candidate_resolution ->> 'source', 'unknown'
      ),
      'parity', coalesce((
        resolved.authoritative_resolution ->> 'effective'
      )::boolean, false) = coalesce((
        resolved.candidate_resolution ->> 'effective'
      )::boolean, false),
      'effective_from', case when assignment.scope_fully_visible
        then assignment.effective_from else null end,
      'effective_until', case when assignment.scope_fully_visible
        then assignment.effective_until else null end
    ) order by resolved.project_ref, resolved.id), '[]'::jsonb)
    into v_project_rows
    from resolved
    left join selected_assignment assignment
      on assignment.project_id = resolved.id;
  end if;

  return jsonb_build_object(
    'capability_key', v_catalog.capability_key,
    'module_key', v_catalog.module_key,
    'action_key', v_catalog.action_key,
    'label', v_catalog.label,
    'description', v_catalog.description,
    'risk_level', v_catalog.risk_level,
    'allowed_scope_kinds', to_jsonb(v_catalog.allowed_scope_kinds),
    'requires_project_access', v_catalog.requires_project_access,
    'dependencies', to_jsonb(v_catalog.dependencies),
    'runtime_status', v_catalog.status,
    'is_assignable', v_catalog.is_assignable,
    'actor_can_delegate', v_actor_can_delegate,
    'actor_delegable_scope_kinds', to_jsonb(
      v_actor_delegable_scope_kinds
    ),
    'display_order', v_catalog.display_order,
    'authorization_mode', v_catalog.authorization_mode,
    'role_default', coalesce(v_role_default, false),
    'organization_summary_visible', v_organization_summary_visible,
    'authoritative_effective', case when v_organization_summary_visible
      then coalesce((v_authoritative ->> 'effective')::boolean, false)
      else null end,
    'authoritative_source', case when v_organization_summary_visible
      then coalesce(v_authoritative ->> 'source', 'unknown')
      else null end,
    'candidate_effective', case when v_organization_summary_visible
      then coalesce((v_candidate ->> 'effective')::boolean, false)
      else null end,
    'candidate_source', case when v_organization_summary_visible
      then coalesce(v_candidate ->> 'source', 'unknown')
      else null end,
    'parity', case when v_organization_summary_visible
      then coalesce((v_authoritative ->> 'effective')::boolean, false)
        = coalesce((v_candidate ->> 'effective')::boolean, false)
      else null end,
    'project_overrides', v_project_rows
  );
end;
$$;

revoke all on function public.v1_permission_capability_projection_json(
  uuid, text, text, boolean, boolean, boolean, uuid[], uuid[], boolean
) from public, anon, authenticated;

create or replace function public.v1_permission_workspace_json(
  p_target_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_exact_role text;
  v_actor_can_manage boolean;
  v_actor_can_delegate_permissions boolean;
  v_actor_visible_project_ids uuid[] := '{}'::uuid[];
  v_actor_has_unrestricted_projects boolean := false;
  v_target_visible_project_ids uuid[] := '{}'::uuid[];
  v_profile public.v1_profiles%rowtype;
  v_target_exact_role text;
  v_revision bigint;
  v_capabilities jsonb;
  v_assignments jsonb;
  v_projects jsonb;
  v_history jsonb;
begin
  select * into v_profile
  from public.v1_profiles profile
  where profile.auth_user_id = p_target_auth_user_id;
  if not found or nullif(btrim(v_profile.legacy_app_user_id), '') is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  if v_actor is null then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;

  v_actor_exact_role := public.v1_permission_exact_role(v_actor);
  v_target_exact_role := public.v1_permission_exact_role(
    p_target_auth_user_id
  );
  v_actor_can_manage := public.v1_current_user_has_capability(
    'permissions.manage', null
  );
  v_actor_can_delegate_permissions :=
    public.v1_current_user_has_capability('permissions.delegate', null);

  select coalesce(array_agg(project.id order by project.id), '{}'::uuid[])
  into v_actor_visible_project_ids
  from public.v1_projects project
  where public.v1_permission_actor_can_view_project(project.id);

  v_actor_has_unrestricted_projects := v_actor_exact_role in (
      'admin', 'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    and public.v1_current_user_has_capability('projects.view_all', null)
    and cardinality(v_actor_visible_project_ids) = (
      select count(*) from public.v1_projects
    );

  select coalesce(array_agg(project.id order by project.id), '{}'::uuid[])
  into v_target_visible_project_ids
  from public.v1_projects project
  where project.id = any(v_actor_visible_project_ids)
    and public.v1_permission_has_project_access(
      p_target_auth_user_id, project.id
    );

  select revision.revision into v_revision
  from public.v1_permission_revisions revision
  where revision.auth_user_id = p_target_auth_user_id;

  select coalesce(jsonb_agg(
    public.v1_permission_capability_projection_json(
      p_target_auth_user_id,
      catalog.capability_key,
      v_actor_exact_role,
      v_actor_can_manage,
      v_actor_can_delegate_permissions,
      v_actor_has_unrestricted_projects,
      v_actor_visible_project_ids,
      v_target_visible_project_ids,
      true
    ) order by catalog.display_order
  ), '[]'::jsonb)
  into v_capabilities
  from public.v1_capability_catalog catalog;

  with assignment_scope as materialized (
    select
      assignment.*,
      catalog.requires_project_access,
      catalog.status as runtime_status,
      catalog.is_assignable,
      catalog.allowed_scope_kinds,
      coalesce(actor_default.can_delegate, false) as template_can_delegate,
      coalesce(array_agg(
        assignment_project.project_id order by assignment_project.project_id
      ) filter (where assignment_project.project_id is not null),
        '{}'::uuid[]) as project_ids
    from public.v1_permission_assignments assignment
    join public.v1_capability_catalog catalog
      on catalog.capability_key = assignment.capability_key
    left join public.v1_permission_role_defaults actor_default
      on actor_default.role_name = v_actor_exact_role
     and actor_default.capability_key = assignment.capability_key
    left join public.v1_permission_assignment_projects assignment_project
      on assignment_project.assignment_id = assignment.id
    where assignment.auth_user_id = p_target_auth_user_id
    group by assignment.id, catalog.capability_key,
      catalog.requires_project_access, catalog.status,
      catalog.is_assignable, catalog.allowed_scope_kinds,
      actor_default.can_delegate
  ), visible_assignment as materialized (
    select assignment.*
    from assignment_scope assignment
    where assignment.runtime_status = 'operational'
      and (
        (
          assignment.scope_kind = 'organization'
          and cardinality(assignment.project_ids) = 0
          and (
            not assignment.requires_project_access
            or v_actor_has_unrestricted_projects
          )
        )
        or (
          assignment.scope_kind = 'project'
          and cardinality(assignment.project_ids) > 0
          and assignment.project_ids <@ v_actor_visible_project_ids
        )
      )
  )
  select coalesce(jsonb_agg(
    public.v1_permission_assignment_json(assignment.id)
      || jsonb_build_object(
        'actor_can_administer_scope',
          assignment.is_assignable
          and assignment.scope_kind = any(assignment.allowed_scope_kinds)
          and v_actor_can_manage
          and (
            assignment.capability_key not like 'permissions.%'
            or v_actor_can_delegate_permissions
          )
          and assignment.template_can_delegate
          and (
            (
              assignment.scope_kind = 'organization'
              and (
                not assignment.requires_project_access
                or v_actor_has_unrestricted_projects
              )
            )
            or (
              assignment.scope_kind = 'project'
              and cardinality(assignment.project_ids) > 0
              and assignment.project_ids <@ v_actor_visible_project_ids
            )
          )
      )
    order by assignment.capability_key, assignment.scope_kind,
      assignment.effect
  ), '[]'::jsonb)
  into v_assignments
  from visible_assignment assignment;

  select coalesce(jsonb_agg(jsonb_build_object(
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'state', project.state,
    'has_access', true
  ) order by project.project_ref, project.id), '[]'::jsonb)
  into v_projects
  from public.v1_projects project
  where project.id = any(v_target_visible_project_ids);

  v_history := public.v1_permission_history_json(
    p_target_auth_user_id, 25, null, null
  );

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', public.v1_permission_mode_summary(),
    'generated_at', clock_timestamp(),
    'actor', (
      select jsonb_build_object(
        'actor_kind', 'user',
        'app_user_id', actor.legacy_app_user_id,
        'display_name', actor.display_name,
        'exact_role', public.v1_permission_display_exact_role(
          actor.auth_user_id
        )
      )
      from public.v1_profiles actor
      where actor.auth_user_id = v_actor
    ),
    'target', jsonb_build_object(
      'app_user_id', v_profile.legacy_app_user_id,
      'display_name', v_profile.display_name,
      'exact_role', public.v1_permission_display_exact_role(
        p_target_auth_user_id
      ),
      'is_active', v_target_exact_role <> ''
    ),
    'revision', coalesce(v_revision, 0),
    'catalog', v_capabilities,
    'assignments', v_assignments,
    'projects', v_projects,
    'recent_history', coalesce(v_history -> 'items', '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_get_current_permission_snapshot()
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_profile public.v1_profiles%rowtype;
  v_actor_exact_role text;
  v_actor_can_manage boolean;
  v_actor_can_delegate_permissions boolean;
  v_actor_visible_project_ids uuid[] := '{}'::uuid[];
  v_actor_has_unrestricted_projects boolean := false;
  v_revision bigint;
  v_capabilities jsonb;
  v_projects jsonb;
  v_next_transition_at timestamptz;
begin
  if v_actor is null then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  select * into v_profile
  from public.v1_profiles profile
  where profile.auth_user_id = v_actor;
  insert into public.v1_permission_revisions (
    auth_user_id, app_user_id
  ) values (v_actor, v_profile.legacy_app_user_id)
  on conflict (auth_user_id) do update
    set app_user_id = excluded.app_user_id
    where public.v1_permission_revisions.app_user_id
      is distinct from excluded.app_user_id;

  v_actor_exact_role := public.v1_permission_exact_role(v_actor);
  v_actor_can_manage := public.v1_current_user_has_capability(
    'permissions.manage', null
  );
  v_actor_can_delegate_permissions :=
    public.v1_current_user_has_capability('permissions.delegate', null);

  select coalesce(array_agg(project.id order by project.id), '{}'::uuid[])
  into v_actor_visible_project_ids
  from public.v1_projects project
  where public.v1_permission_actor_can_view_project(project.id);

  v_actor_has_unrestricted_projects := v_actor_exact_role in (
      'admin', 'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    and public.v1_current_user_has_capability('projects.view_all', null)
    and cardinality(v_actor_visible_project_ids) = (
      select count(*) from public.v1_projects
    );

  select revision.revision into v_revision
  from public.v1_permission_revisions revision
  where revision.auth_user_id = v_actor;

  select coalesce(jsonb_agg(
    public.v1_permission_capability_projection_json(
      v_actor,
      catalog.capability_key,
      v_actor_exact_role,
      v_actor_can_manage,
      v_actor_can_delegate_permissions,
      v_actor_has_unrestricted_projects,
      v_actor_visible_project_ids,
      v_actor_visible_project_ids,
      false
    ) order by catalog.display_order
  ), '[]'::jsonb)
  into v_capabilities
  from public.v1_capability_catalog catalog;

  select coalesce(jsonb_agg(jsonb_build_object(
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'state', project.state,
    'has_access', true
  ) order by project.project_ref, project.id), '[]'::jsonb)
  into v_projects
  from public.v1_projects project
  where project.id = any(v_actor_visible_project_ids);

  select min(transition_at) into v_next_transition_at
  from (
    select assignment.effective_from as transition_at
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id = v_actor
      and assignment.effective_from > clock_timestamp()
    union all
    select assignment.effective_until
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id = v_actor
      and assignment.effective_until > clock_timestamp()
    union all
    select member.effective_from
    from public.v1_project_members member
    where member.member_auth_user_id = v_actor
      and member.effective_from > clock_timestamp()
    union all
    select member.effective_to
    from public.v1_project_members member
    where member.member_auth_user_id = v_actor
      and member.effective_to > clock_timestamp()
  ) transitions;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', public.v1_permission_mode_summary(),
    'generated_at', clock_timestamp(),
    'next_transition_at', v_next_transition_at,
    'user', jsonb_build_object(
      'app_user_id', v_profile.legacy_app_user_id,
      'display_name', v_profile.display_name,
      'exact_role', public.v1_permission_display_exact_role(v_actor),
      'is_active', v_actor_exact_role <> ''
    ),
    'revision', coalesce(v_revision, 0),
    'capabilities', v_capabilities,
    'project_access', v_projects
  );
end;
$$;

revoke all on function public.v1_get_current_permission_snapshot()
  from public, anon;
grant execute on function public.v1_get_current_permission_snapshot()
  to authenticated;

comment on function public.v1_permission_capability_projection_json(
  uuid, text, text, boolean, boolean, boolean, uuid[], uuid[], boolean
) is
  'Internal cached-context capability JSON projection. It preserves resolver decisions while avoiding repeated actor and project authorization scans.';

comment on function public.v1_get_current_permission_snapshot() is
  'Returns the authenticated actor permission snapshot through the lightweight cached-context projection; role defaults and explicit assignments remain authoritative in the shared resolver.';
