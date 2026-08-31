-- Yorks Workforce Administration enablement.
--
-- This forward-only migration promotes the three retained T01/T02 Workforce
-- master-data capabilities only after their protected RPC consumers exist.
-- It replaces the temporary exact-Admin assertion inside those bounded
-- consumers with live capability checks while preserving the exact-Admin-only
-- responsibility-assignment and digest commands.
--
-- Data preservation: no Workforce, identity, project or attendance row is
-- changed or deleted. Worker/project changes continue through dated versions.
-- Rollback: make the three catalogue rows nonassignable/shadow again and deny
-- the administration route. Retain all master rows, assignments and audit.

begin;

update public.v1_capability_catalog catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true,
    description = case catalog.capability_key
      when 'workforce.workers.manage' then
        'Create, update, deactivate and retain normalized worker master records without creating Auth users.'
      when 'workforce.teams.manage' then
        'Create and close Workforce teams and maintain dated worker, supervisor and project assignments.'
      when 'workforce.configuration.manage' then
        'Maintain protected trades, internal locations, calendars, shifts and dated team schedules.'
      else catalog.description
    end
where catalog.capability_key in (
  'workforce.workers.manage',
  'workforce.teams.manage',
  'workforce.configuration.manage'
);

do $catalog_contract$
begin
  if (
    select count(*)
    from public.v1_capability_catalog catalog
    where catalog.capability_key in (
      'workforce.workers.manage',
      'workforce.teams.manage',
      'workforce.configuration.manage'
    )
      and catalog.status = 'operational'
      and catalog.authorization_mode = 'enforced'
      and catalog.is_assignable
      and catalog.allowed_scope_kinds = array['organization']::text[]
      and catalog.dependencies = array['workforce.view']::text[]
  ) <> 2
    or not exists (
      select 1
      from public.v1_capability_catalog catalog
      where catalog.capability_key = 'workforce.teams.manage'
        and catalog.status = 'operational'
        and catalog.authorization_mode = 'enforced'
        and catalog.is_assignable
        and catalog.allowed_scope_kinds = array['organization','project']::text[]
        and catalog.dependencies = array['workforce.view']::text[]
    )
  then
    raise exception 'V1_WORKFORCE_ADMINISTRATION_CATALOG_CONFLICT'
      using errcode = '23514';
  end if;
end;
$catalog_contract$;

create or replace function public.v1_workforce_assert_management(
  p_capability_key text
)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if p_capability_key not in (
    'workforce.workers.manage',
    'workforce.teams.manage',
    'workforce.configuration.manage'
  ) then
    raise exception 'V1_WORKFORCE_MANAGEMENT_CAPABILITY_INVALID'
      using errcode = '22023';
  end if;
  if v_actor is null then
    raise exception 'V1_WORKFORCE_MANAGEMENT_REQUIRED'
      using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active()
    or public.v1_permission_exact_role(v_actor) = ''
    or not public.v1_current_user_has_capability(p_capability_key, null)
  then
    raise exception 'V1_WORKFORCE_MANAGEMENT_REQUIRED'
      using errcode = '42501';
  end if;
  return v_actor;
end;
$$;

create or replace function public.v1_workforce_assert_foundation_manager()
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if public.v1_current_user_has_capability(
      'workforce.workers.manage', null
    ) then
    return public.v1_workforce_assert_management(
      'workforce.workers.manage'
    );
  end if;
  if public.v1_current_user_has_capability(
      'workforce.teams.manage', null
    ) then
    return public.v1_workforce_assert_management(
      'workforce.teams.manage'
    );
  end if;
  return public.v1_workforce_assert_management(
    'workforce.configuration.manage'
  );
end;
$$;

create or replace function public.v1_workforce_assert_assignment_manager()
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if public.v1_current_user_has_capability(
      'workforce.workers.manage', null
    ) then
    return public.v1_workforce_assert_management(
      'workforce.workers.manage'
    );
  end if;
  return public.v1_workforce_assert_management(
    'workforce.teams.manage'
  );
end;
$$;

-- Patch only the exact, independently accepted T01/T02 consumers. Each patch
-- verifies one legacy assertion before replacement so schema drift fails the
-- migration rather than broadening a different function accidentally.
do $patch_consumers$
declare
  v_signature text;
  v_capability text;
  v_definition text;
  v_replacement text;
  v_signatures constant text[][] := array[
    array[
      'public.v1_get_workforce_foundation(text,text,integer,integer,date)',
      'foundation'
    ],
    array[
      'public.v1_save_workforce_trade(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_internal_location(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_worker(jsonb,bigint,uuid)',
      'workforce.workers.manage'
    ],
    array[
      'public.v1_save_workforce_team(jsonb,bigint,uuid)',
      'workforce.teams.manage'
    ],
    array[
      'public.v1_save_workforce_worker_assignment(jsonb,bigint,uuid)',
      'assignment'
    ],
    array[
      'public.v1_get_workforce_configuration(date)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_calendar(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_shift_template(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_calendar_date(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ],
    array[
      'public.v1_save_workforce_team_schedule(jsonb,bigint,uuid)',
      'workforce.configuration.manage'
    ]
  ];
  v_item text[];
begin
  foreach v_item slice 1 in array v_signatures loop
    v_signature := v_item[1];
    v_capability := v_item[2];
    select pg_get_functiondef(to_regprocedure(v_signature))
      into v_definition;
    if v_definition is null
      or (length(v_definition) - length(replace(
        v_definition,
        'public.v1_workforce_assert_admin()',
        ''
      ))) / length('public.v1_workforce_assert_admin()') <> 1
    then
      raise exception 'V1_WORKFORCE_ADMINISTRATION_PATCH_MISMATCH:%',
        v_signature using errcode = '23514';
    end if;
    v_replacement := case v_capability
      when 'foundation' then
        'public.v1_workforce_assert_foundation_manager()'
      when 'assignment' then
        'public.v1_workforce_assert_assignment_manager()'
      else format(
        'public.v1_workforce_assert_management(%L)',
        v_capability
      )
    end;
    v_definition := replace(
      v_definition,
      'public.v1_workforce_assert_admin()',
      v_replacement
    );
    if v_capability = 'foundation' then
      v_definition := replace(
        v_definition,
        '''admin_legacy_t01''',
        '''enforced_administration'''
      );
    elsif v_signature = 'public.v1_get_workforce_configuration(date)' then
      v_definition := replace(
        v_definition,
        '''admin_legacy_t02''',
        '''enforced_administration'''
      );
    end if;
    execute v_definition;
  end loop;
end;
$patch_consumers$;

-- The accepted T02 reader was STABLE while its exact-Admin assertion was
-- stable. Capability resolution synchronizes and re-checks active identity,
-- so the patched reader must truthfully advertise VOLATILE semantics.
alter function public.v1_get_workforce_configuration(date) volatile;

-- Configuration-only delegates need trades, locations and teams for schedule
-- setup, but they must not receive the worker master projection. Keep the
-- accepted response shape and return an authoritative empty worker slice.
create or replace function public.v1_get_workforce_foundation(
  p_query text default null,
  p_status text default null,
  p_limit integer default 50,
  p_offset integer default 0,
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
  v_query text := nullif(lower(btrim(coalesce(p_query, ''))), '');
  v_status text := nullif(btrim(coalesce(p_status, '')), '');
  v_can_read_workers boolean :=
    public.v1_current_user_has_capability(
      'workforce.workers.manage', null
    )
    or public.v1_current_user_has_capability(
      'workforce.teams.manage', null
    );
begin
  if p_limit < 1 or p_limit > 100 or p_offset < 0 or p_on_date is null then
    raise exception 'V1_WORKFORCE_FOUNDATION_FILTER_INVALID'
      using errcode = '22023';
  end if;
  if v_status is not null and v_status not in (
    'active', 'inactive', 'left_company', 'suspended'
  ) then
    raise exception 'V1_WORKFORCE_STATUS_INVALID'
      using errcode = '22023';
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'enforced_administration',
    'actor_auth_user_id', v_actor,
    'on_date', p_on_date,
    'server_time', clock_timestamp(),
    'trades', coalesce((
      select jsonb_agg(jsonb_build_object(
        'trade_id', trade.id,
        'trade_code', trade.trade_code,
        'trade_name', trade.trade_name,
        'description', trade.description,
        'is_active', trade.is_active,
        'record_version', trade.record_version
      ) order by lower(trade.trade_name), trade.id)
      from public.v1_workforce_trades trade
    ), '[]'::jsonb),
    'teams', coalesce((
      select jsonb_agg(jsonb_build_object(
        'team_id', team.id,
        'team_code', team.team_code,
        'team_name', team.team_name,
        'department', team.department,
        'default_supervisor_auth_user_id',
          team.default_supervisor_auth_user_id,
        'default_project_id', team.default_project_id,
        'default_project_scope_id', team.default_project_scope_id,
        'default_internal_location_id', team.default_internal_location_id,
        'valid_from', team.valid_from,
        'valid_to', team.valid_to,
        'is_active', team.is_active,
        'record_version', team.record_version
      ) order by lower(team.team_name), team.id)
      from public.v1_workforce_teams team
    ), '[]'::jsonb),
    'internal_locations', coalesce((
      select jsonb_agg(jsonb_build_object(
        'internal_location_id', location.id,
        'location_code', location.location_code,
        'location_name', location.location_name,
        'department', location.department,
        'is_active', location.is_active,
        'record_version', location.record_version
      ) order by lower(location.location_name), location.id)
      from public.v1_workforce_internal_locations location
    ), '[]'::jsonb),
    'workers', case when v_can_read_workers then coalesce((
      select jsonb_agg(public.v1_workforce_worker_json(
        filtered.id, p_on_date
      ) order by lower(filtered.worker_number), filtered.id)
      from (
        select worker.id, worker.worker_number
        from public.v1_workforce_workers worker
        where (v_status is null or worker.current_status = v_status)
          and (
            v_query is null
            or lower(worker.worker_number) like '%' || v_query || '%'
            or lower(worker.full_name) like '%' || v_query || '%'
            or lower(coalesce(worker.preferred_display_name, ''))
              like '%' || v_query || '%'
            or lower(worker.designation) like '%' || v_query || '%'
          )
        order by lower(worker.worker_number), worker.id
        limit p_limit offset p_offset
      ) filtered
    ), '[]'::jsonb) else '[]'::jsonb end,
    'worker_count', case when v_can_read_workers then (
      select count(*)
      from public.v1_workforce_workers worker
      where (v_status is null or worker.current_status = v_status)
        and (
          v_query is null
          or lower(worker.worker_number) like '%' || v_query || '%'
          or lower(worker.full_name) like '%' || v_query || '%'
          or lower(coalesce(worker.preferred_display_name, ''))
            like '%' || v_query || '%'
          or lower(worker.designation) like '%' || v_query || '%'
        )
    ) else 0 end
  );
end;
$$;

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
        'exact_role', public.v1_permission_exact_role(profile.auth_user_id),
        'is_active', profile.is_active
      ) order by lower(profile.display_name), profile.auth_user_id)
      from public.v1_profiles profile
      where v_can_assign
        and nullif(btrim(profile.legacy_app_user_id), '') is not null
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

create or replace function public.v1_transfer_workforce_worker_assignment(
  p_payload jsonb,
  p_expected_current_assignment_id uuid,
  p_expected_current_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_assignment_manager();
  v_actor_role text := public.v1_permission_exact_role(v_actor);
  v_existing_response jsonb;
  v_worker_id uuid;
  v_team_id uuid;
  v_supervisor_id uuid;
  v_project_id uuid;
  v_project_scope_id uuid;
  v_internal_location_id uuid;
  v_effective_from date;
  v_valid_to date;
  v_assignment_kind text;
  v_current public.v1_workforce_worker_assignments%rowtype;
  v_created public.v1_workforce_worker_assignments%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'worker_id','assignment_kind','team_id','supervisor_auth_user_id',
      'project_id','project_scope_id','internal_location_id',
      'valid_from','valid_to','reason'
    ],
    'transfer_workforce_worker_assignment_payload'
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_transfer_workforce_worker_assignment',
    p_idempotency_key,
    jsonb_build_object(
      'payload', p_payload,
      'expected_current_assignment_id', p_expected_current_assignment_id,
      'expected_current_version', p_expected_current_version
    )
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  begin
    v_worker_id := nullif(btrim(coalesce(
      p_payload ->> 'worker_id', ''
    )), '')::uuid;
    v_team_id := nullif(btrim(coalesce(
      p_payload ->> 'team_id', ''
    )), '')::uuid;
    v_supervisor_id := nullif(btrim(coalesce(
      p_payload ->> 'supervisor_auth_user_id', ''
    )), '')::uuid;
    v_project_id := nullif(btrim(coalesce(
      p_payload ->> 'project_id', ''
    )), '')::uuid;
    v_project_scope_id := nullif(btrim(coalesce(
      p_payload ->> 'project_scope_id', ''
    )), '')::uuid;
    v_internal_location_id := nullif(btrim(coalesce(
      p_payload ->> 'internal_location_id', ''
    )), '')::uuid;
    v_effective_from := nullif(btrim(coalesce(
      p_payload ->> 'valid_from', ''
    )), '')::date;
    v_valid_to := nullif(btrim(coalesce(
      p_payload ->> 'valid_to', ''
    )), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_TRANSFER_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_assignment_kind := btrim(coalesce(
    p_payload ->> 'assignment_kind', ''
  ));
  if v_worker_id is null
    or v_effective_from is null
    or v_assignment_kind not in ('primary','temporary')
    or (v_assignment_kind = 'temporary' and v_valid_to is null)
    or (v_valid_to is not null and v_valid_to < v_effective_from)
    or (v_project_scope_id is not null and v_project_id is null)
    or (v_project_id is not null and v_internal_location_id is not null)
    or (
      v_team_id is null
      and v_supervisor_id is null
      and v_project_id is null
      and v_internal_location_id is null
    )
    or nullif(btrim(coalesce(p_payload ->> 'reason', '')), '') is null
  then
    raise exception 'V1_WORKFORCE_TRANSFER_INPUT_INVALID'
      using errcode = '22023';
  end if;

  perform 1
  from public.v1_workforce_workers worker
  where worker.id = v_worker_id
  for update;
  if not found then
    raise exception 'V1_WORKFORCE_WORKER_NOT_FOUND'
      using errcode = 'P0002';
  end if;

  select assignment.* into v_current
  from public.v1_workforce_worker_assignments assignment
  where assignment.worker_id = v_worker_id
    and assignment.assignment_kind = v_assignment_kind
    and assignment.valid_from <= v_effective_from
    and (
      assignment.valid_to is null
      or assignment.valid_to >= v_effective_from
    )
  order by assignment.valid_from desc, assignment.id
  limit 1
  for update;

  if found then
    if p_expected_current_assignment_id is null
      or p_expected_current_assignment_id <> v_current.id
      or p_expected_current_version is null
      or p_expected_current_version <> v_current.record_version
    then
      raise exception 'V1_WORKFORCE_ASSIGNMENT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    if v_current.valid_from >= v_effective_from then
      raise exception 'V1_WORKFORCE_TRANSFER_DATE_MUST_FOLLOW_CURRENT_START'
        using errcode = '23514';
    end if;
    update public.v1_workforce_worker_assignments assignment
    set valid_to = v_effective_from - 1,
        record_version = assignment.record_version + 1,
        updated_by_auth_user_id = v_actor,
        updated_at = clock_timestamp()
    where assignment.id = v_current.id;
  elsif p_expected_current_assignment_id is not null
    or p_expected_current_version is not null
  then
    raise exception 'V1_WORKFORCE_ASSIGNMENT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  insert into public.v1_workforce_worker_assignments (
    worker_id, assignment_kind, team_id, supervisor_auth_user_id,
    project_id, project_scope_id, internal_location_id,
    valid_from, valid_to, reason,
    assigned_by_auth_user_id, assigned_by_exact_role,
    updated_by_auth_user_id
  ) values (
    v_worker_id, v_assignment_kind, v_team_id, v_supervisor_id,
    v_project_id, v_project_scope_id, v_internal_location_id,
    v_effective_from, v_valid_to, btrim(p_payload ->> 'reason'),
    v_actor, v_actor_role, v_actor
  ) returning * into v_created;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'assignment_id', v_created.id,
    'record_version', v_created.record_version,
    'superseded_assignment_id', v_current.id,
    'superseded_record_version', case when v_current.id is null then null
      else v_current.record_version + 1 end
  );
  perform public.v1_write_audit_event(
    'workforce_worker_assignment_transferred',
    'workforce_worker_assignment',
    v_created.id,
    v_project_id,
    case when v_current.id is null then null else to_jsonb(v_current) end,
    to_jsonb(v_created),
    btrim(p_payload ->> 'reason'),
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_transfer_workforce_worker_assignment',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_workforce_assert_management(text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_assert_foundation_manager()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_assert_assignment_manager()
  from public, anon, authenticated;
revoke all on function public.v1_get_workforce_administration_options(date)
  from public, anon;
grant execute on function public.v1_get_workforce_administration_options(date)
  to authenticated;
revoke all on function public.v1_transfer_workforce_worker_assignment(
  jsonb, uuid, bigint, uuid
) from public, anon;
grant execute on function public.v1_transfer_workforce_worker_assignment(
  jsonb, uuid, bigint, uuid
) to authenticated;

comment on function public.v1_get_workforce_administration_options(date) is
  'Role-safe non-commercial user/project choices for capability-guarded Workforce Administration forms.';
comment on function public.v1_transfer_workforce_worker_assignment(
  jsonb, uuid, bigint, uuid
) is
  'Capability-guarded atomic dated worker assignment transfer preserving the superseded assignment.';

commit;
