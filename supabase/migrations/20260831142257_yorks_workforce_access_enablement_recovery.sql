-- Yorks Workforce access enablement recovery.
--
-- The permission catalogue and the dated responsibility model are deliberately
-- independent. This forward-only correction makes that dependency visible in
-- the protected User Management workspace, offers an explicit audited Admin
-- command that can save both reviewed parts in one transaction, and preserves
-- an authorized empty Workforce overview while master data is not configured.
--
-- Rollback: revoke the two new administration commands, restore the prior
-- v1_get_user_permission_workspace body, drop this overview wrapper, rename
-- v1_get_workforce_overview_authorized_data(jsonb) back to
-- v1_get_workforce_overview(jsonb), then restore the prior grants. The one
-- production responsibility created for a user is retained as auditable dated
-- authority and can be made ineffective through permission denial/expiry.

begin;

-- Preserve the accepted T10/T13 data projection unchanged. The wrapper only
-- handles the one state that the original projection misclassified: a caller
-- with complete organization capability plus organization responsibility when
-- no team/calendar context exists yet.
do $$
begin
  if to_regprocedure(
    'public.v1_get_workforce_overview_authorized_data(jsonb)'
  ) is null then
    alter function public.v1_get_workforce_overview(jsonb)
      rename to v1_get_workforce_overview_authorized_data;
  end if;
end;
$$;

revoke all on function public.v1_get_workforce_overview_authorized_data(jsonb)
  from public, anon, authenticated;

create or replace function public.v1_get_workforce_overview(
  p_request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_kind text;
  v_role text;
  v_summary jsonb;
  v_actions jsonb;
begin
  begin
    return public.v1_get_workforce_overview_authorized_data(p_request);
  exception when insufficient_privilege then
    v_kind := nullif(btrim(coalesce(p_request ->> 'overview_kind', '')), '');
    v_role := public.v1_permission_exact_role(auth.uid());

    if v_kind not in ('supervisor', 'management')
      or not public.v1_workforce_t10_organization_authorized(
        'workforce.view'
      )
      or (v_kind = 'management' and v_role not in (
        'project_manager', 'senior_mechanical_engineer'
      ))
      or exists (
        select 1 from public.v1_workforce_t10_team_contexts()
      )
    then
      raise exception 'V1_WORKFORCE_T10_READ_DENIED'
        using errcode = '42501';
    end if;

    v_summary := jsonb_build_object(
      'team_count', 0,
      'worker_count', 0,
      'present_count', 0,
      'absent_count', 0,
      'leave_count', 0,
      'not_entered_count', 0,
      'warning_count', 0,
      'returned_correction_count', 0,
      'today_entered_count', 0,
      'today_completion_percent', 0,
      'month_entered_count', 0,
      'month_required_count', 0,
      'month_completion_percent', 0
    );
    if v_kind = 'management' then
      v_summary := v_summary || jsonb_build_object(
        'active_project_count', 0,
        'review_queue_count', 0,
        'approval_queue_count', 0,
        'returned_count', 0,
        'overtime_exception_count', 0
      );
      v_actions := jsonb_build_object(
        'can_open_review_queue', false,
        'can_open_final_approval_queue', false
      );
    else
      v_actions := jsonb_build_object(
        'can_complete_today_attendance', false
      );
    end if;

    return jsonb_build_object(
      'schema_version', 1,
      'authorization_mode', 'enforced_t10',
      'source_version', 'workforce_t10_v1',
      'overview_kind', v_kind,
      'generated_at', statement_timestamp(),
      'as_of_mode', 'calendar_local_by_team',
      'as_of_groups', '[]'::jsonb,
      'summary', v_summary,
      'teams', '[]'::jsonb,
      'projects', '[]'::jsonb,
      'review_queue', '[]'::jsonb,
      'action_flags', v_actions,
      'policies', jsonb_build_object(
        'overtime_limit', 'not_configured',
        'supporting_evidence_requirement', 'not_configured'
      )
    );
  end;
end;
$$;

revoke all on function public.v1_get_workforce_overview(jsonb)
  from public, anon;
grant execute on function public.v1_get_workforce_overview(jsonb)
  to authenticated;

comment on function public.v1_get_workforce_overview(jsonb) is
  'T10 overview with an organization-authorized empty-state recovery when no team/calendar context exists.';

-- Enrich the existing target-user workspace without changing schema_version.
-- Older clients ignore the additive object; the updated client parses it
-- strictly and uses it only for presentation and reviewed Admin commands.
create or replace function public.v1_get_user_permission_workspace(
  p_target_app_user_id text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target uuid;
  v_workspace jsonb;
  v_reference_date date;
  v_responsibility jsonb;
  v_active_team_count integer;
  v_scheduled_team_count integer;
  v_active_worker_count integer;
  v_has_workforce_access boolean;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  if not public.v1_permission_actor_can_view() then
    raise exception 'V1_PERMISSION_WORKSPACE_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null then
    raise exception 'V1_PERMISSION_TARGET_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  v_workspace := public.v1_permission_workspace_json(v_target);
  -- Responsibility assignment is exact-Admin authority. Other authorized
  -- permission viewers retain the accepted workspace shape and receive no
  -- Workforce responsibility metadata or organization-wide master counts.
  if public.v1_permission_exact_role(v_actor) <> 'admin' then
    return v_workspace;
  end if;
  select min(
      (statement_timestamp() at time zone calendar.timezone_name)::date
    )
  into v_reference_date
  from public.v1_workforce_teams team
  join public.v1_workforce_team_schedule_links schedule
    on schedule.team_id = team.id
  join public.v1_workforce_calendars calendar
    on calendar.id = schedule.calendar_id
  where team.is_active;
  v_reference_date := coalesce(
    v_reference_date,
    (statement_timestamp() at time zone 'UTC')::date
  );

  select jsonb_build_object(
    'responsibility_assignment_id', responsibility.id,
    'valid_from', responsibility.valid_from,
    'valid_to', responsibility.valid_to,
    'record_version', responsibility.record_version
  )
  into v_responsibility
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.auth_user_id = v_target
    and responsibility.scope_kind = 'organization'
    and responsibility.valid_from <= v_reference_date
    and (
      responsibility.valid_to is null
      or responsibility.valid_to >= v_reference_date
    )
  order by responsibility.valid_to nulls first,
    responsibility.valid_from desc,
    responsibility.id
  limit 1;

  select count(*)::integer into v_active_team_count
  from public.v1_workforce_teams team
  where team.is_active;
  select count(distinct team.id)::integer into v_scheduled_team_count
  from public.v1_workforce_teams team
  join public.v1_workforce_team_schedule_links schedule
    on schedule.team_id = team.id
  join public.v1_workforce_calendars calendar
    on calendar.id = schedule.calendar_id
  where team.is_active and calendar.is_active
    and schedule.valid_from <= v_reference_date
    and (
      schedule.valid_to is null
      or schedule.valid_to >= v_reference_date
    );
  select count(*)::integer into v_active_worker_count
  from public.v1_workforce_workers worker
  where worker.current_status = 'active';

  select coalesce(bool_or(
    catalog ->> 'capability_key' = 'workforce.view'
      and coalesce((catalog ->> 'authoritative_effective')::boolean, false)
  ), false)
  into v_has_workforce_access
  from jsonb_array_elements(v_workspace -> 'catalog') catalog;

  return v_workspace || jsonb_build_object(
    'workforce_access', jsonb_build_object(
      'reference_date', v_reference_date,
      'has_operational_access', v_has_workforce_access,
      'organization_responsibility', v_responsibility,
      'can_assign_organization_responsibility',
        public.v1_permission_exact_role(v_actor) = 'admin',
      'active_worker_count', v_active_worker_count,
      'active_team_count', v_active_team_count,
      'scheduled_team_count', v_scheduled_team_count
    )
  );
end;
$$;

-- A standalone recovery command is required for retained half-enabled users.
-- The date is server-derived using the same calendar-local/UTC-empty fallback
-- as the accepted T10 organization authorization helper.
create or replace function public.v1_assign_user_workforce_organization(
  p_target_app_user_id text,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_target uuid;
  v_reference_date date;
  v_next_start date;
  v_existing_response jsonb;
  v_response jsonb;
begin
  perform public.v1_workforce_assert_admin();
  if nullif(btrim(coalesce(p_reason, '')), '') is null
    or char_length(p_reason) > 2000
  then
    raise exception 'V1_WORKFORCE_RESPONSIBILITY_REASON_REQUIRED'
      using errcode = '22023';
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null or not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = v_target and profile.is_active
  ) then
    raise exception 'V1_WORKFORCE_ACTIVE_RESPONSIBLE_USER_REQUIRED'
      using errcode = '23514';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_assign_user_workforce_organization',
    p_idempotency_key,
    jsonb_build_object(
      'target_app_user_id', p_target_app_user_id,
      'reason', btrim(p_reason)
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  select min(
      (statement_timestamp() at time zone calendar.timezone_name)::date
    )
  into v_reference_date
  from public.v1_workforce_teams team
  join public.v1_workforce_team_schedule_links schedule
    on schedule.team_id = team.id
  join public.v1_workforce_calendars calendar
    on calendar.id = schedule.calendar_id
  where team.is_active;
  v_reference_date := coalesce(
    v_reference_date,
    (statement_timestamp() at time zone 'UTC')::date
  );

  if not exists (
    select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = v_target
      and responsibility.scope_kind = 'organization'
      and responsibility.valid_from <= v_reference_date
      and (
        responsibility.valid_to is null
        or responsibility.valid_to >= v_reference_date
      )
  ) then
    select min(responsibility.valid_from)
    into v_next_start
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id = v_target
      and responsibility.scope_kind = 'organization'
      and responsibility.valid_from > v_reference_date;

    perform public.v1_save_workforce_responsibility_assignment(
      jsonb_build_object(
        'responsibility_assignment_id', p_idempotency_key,
        'auth_user_id', v_target,
        'scope_kind', 'organization',
        'valid_from', v_reference_date,
        'valid_to', case when v_next_start is null then null
          else v_next_start - 1 end,
        'reason', btrim(p_reason)
      ),
      null,
      p_idempotency_key
    );
  end if;

  v_response := public.v1_get_user_permission_workspace(
    p_target_app_user_id
  );
  perform public.v1_complete_idempotency(
    'v1_assign_user_workforce_organization',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

-- The combined command keeps reviewed organization capability changes and the
-- explicit organization responsibility in one database transaction. Any
-- validation or authorization error rolls both parts back.
create or replace function public.v1_apply_user_permission_changes_with_workforce(
  p_target_app_user_id text,
  p_changes jsonb,
  p_reason text,
  p_expected_revision bigint,
  p_assign_organization_responsibility boolean,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_existing_response jsonb;
  v_response jsonb;
begin
  if coalesce(p_assign_organization_responsibility, false) then
    perform public.v1_workforce_assert_admin();
    if p_changes is null or jsonb_typeof(p_changes) <> 'array'
      or not exists (
        select 1
        from jsonb_array_elements(p_changes) change
        where change ->> 'operation' = 'set'
          and change ->> 'effect' = 'grant'
          and change ->> 'scope_kind' = 'organization'
          and change ->> 'capability_key' like 'workforce.%'
      )
    then
      raise exception 'V1_WORKFORCE_ORGANIZATION_GRANT_REQUIRED'
        using errcode = '22023';
    end if;
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_apply_user_permission_changes_with_workforce',
    p_idempotency_key,
    jsonb_build_object(
      'target_app_user_id', p_target_app_user_id,
      'changes', p_changes,
      'reason', p_reason,
      'expected_revision', p_expected_revision,
      'assign_organization_responsibility',
        coalesce(p_assign_organization_responsibility, false)
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  perform public.v1_apply_user_permission_changes(
    p_target_app_user_id,
    p_changes,
    p_reason,
    p_expected_revision,
    p_idempotency_key
  );
  if coalesce(p_assign_organization_responsibility, false) then
    perform public.v1_assign_user_workforce_organization(
      p_target_app_user_id,
      p_reason,
      p_idempotency_key
    );
  end if;
  v_response := public.v1_get_user_permission_workspace(
    p_target_app_user_id
  );
  perform public.v1_complete_idempotency(
    'v1_apply_user_permission_changes_with_workforce',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_assign_user_workforce_organization(
  text, text, uuid
) from public, anon;
grant execute on function public.v1_assign_user_workforce_organization(
  text, text, uuid
) to authenticated;

revoke all on function public.v1_apply_user_permission_changes_with_workforce(
  text, jsonb, text, bigint, boolean, uuid
) from public, anon;
grant execute on function public.v1_apply_user_permission_changes_with_workforce(
  text, jsonb, text, bigint, boolean, uuid
) to authenticated;

comment on function public.v1_assign_user_workforce_organization(
  text, text, uuid
) is
  'Exact-Admin, audited, idempotent organization Workforce responsibility recovery for an active user.';

comment on function public.v1_apply_user_permission_changes_with_workforce(
  text, jsonb, text, bigint, boolean, uuid
) is
  'Atomic reviewed permission batch plus optional explicit organization Workforce responsibility.';

commit;
