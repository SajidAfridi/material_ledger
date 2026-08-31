-- Production-safe forward correction for Workforce Administration choices.
--
-- Two preserved login profiles can legitimately retain a legacy app-user ID
-- while having no current server-controlled exact role. They are not valid
-- Workforce supervisor/link targets, and emitting an empty exact_role violates
-- the strict schema-v1 client contract. Filter those identities instead of
-- inferring a role or mutating their preserved Auth/profile records.
--
-- Rollback: replace this function with its definition from
-- 20260831155531_yorks_workforce_administration_enablement.sql. No row is
-- inserted, updated, deleted or reinterpreted by this migration.

create or replace function public.v1_get_workforce_administration_options(
  p_on_date date default current_date
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_foundation_manager();
  v_can_assign boolean :=
    public.v1_current_user_has_capability(
      'workforce.workers.manage', null
    )
    or public.v1_current_user_has_capability(
      'workforce.teams.manage', null
    );
begin
  if p_on_date is null then
    raise exception 'V1_WORKFORCE_ADMINISTRATION_DATE_INVALID'
      using errcode = '22023';
  end if;
  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_administration',
    'actor_auth_user_id', v_actor,
    'on_date', p_on_date,
    'server_time', clock_timestamp(),
    'users', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', profile.auth_user_id,
        'app_user_id', profile.legacy_app_user_id,
        'display_name', profile.display_name,
        'exact_role', identity.exact_role,
        'is_active', profile.is_active
      ) order by lower(profile.display_name), profile.auth_user_id)
      from public.v1_profiles profile
      cross join lateral (
        select public.v1_permission_exact_role(
          profile.auth_user_id
        ) as exact_role
      ) identity
      where v_can_assign
        and nullif(btrim(profile.legacy_app_user_id), '') is not null
        and nullif(btrim(identity.exact_role), '') is not null
    ), '[]'::jsonb),
    'projects', coalesce((
      select jsonb_agg(jsonb_build_object(
        'project_id', project.id,
        'project_ref', project.project_ref,
        'project_name', project.name,
        'state', project.state,
        'scopes', coalesce((
          select jsonb_agg(jsonb_build_object(
            'project_scope_id', scope.id,
            'scope_code', scope.scope_code,
            'scope_name', scope.name,
            'scope_kind', scope.scope_kind,
            'is_active', scope.is_active
          ) order by case scope.scope_kind when 'common' then 0 else 1 end,
            lower(scope.name), scope.id)
          from public.v1_project_scopes scope
          where scope.project_id = project.id
        ), '[]'::jsonb)
      ) order by lower(project.project_ref), project.id)
      from public.v1_projects project
      where v_can_assign and project.state <> 'archived'
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_get_workforce_administration_options(date)
  from public, anon;
grant execute on function public.v1_get_workforce_administration_options(date)
  to authenticated;

comment on function public.v1_get_workforce_administration_options(date) is
  'Role-safe non-commercial user/project choices; identities without a current exact server role are excluded rather than inferred.';
