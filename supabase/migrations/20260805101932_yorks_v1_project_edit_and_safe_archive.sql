-- Yorks V1 R35 project maintenance.
--
-- This is intentionally an additive command migration. Projects are never
-- physically deleted: the Admin-only safe-delete command archives the project
-- and preserves every request, document, membership and audit reference.

create or replace function public.v1_can_edit_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null
      or public.v1_current_role() = ''
      or not public.v1_current_actor_is_active()
      then false
    when public.v1_current_role() = 'admin' then true
    when public.v1_current_role() in ('project_engineer', 'site_engineer') then
      public.v1_has_active_project_membership(p_project_id, auth.uid(), null)
    else false
  end;
$$;

create or replace function public.v1_update_project(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project public.v1_projects%rowtype;
  v_project_id uuid;
  v_expected_version integer;
  v_project_ref text;
  v_name text;
  v_parties jsonb;
  v_buildings jsonb;
  v_party jsonb;
  v_building jsonb;
  v_position integer;
  v_scope_id uuid;
  v_scope_code text;
  v_floors_levels jsonb;
  v_scope_flags jsonb;
  v_active_scope_ids uuid[] := array[]::uuid[];
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'expected_version', 'project_ref', 'name',
      'job_contract_reference', 'project_site', 'start_date',
      'target_completion_date', 'notes', 'parties', 'buildings'
    ],
    'update_project_payload'
  );
  if v_actor is null or v_role = '' then
    raise exception 'V1_AUTHENTICATED_ROLE_REQUIRED' using errcode = '42501';
  end if;

  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_expected_version := nullif(
    btrim(coalesce(p_payload ->> 'expected_version', '')), ''
  )::integer;
  v_project_ref := upper(nullif(
    btrim(coalesce(p_payload ->> 'project_ref', '')), ''
  ));
  v_name := nullif(btrim(coalesce(p_payload ->> 'name', '')), '');
  v_parties := coalesce(p_payload -> 'parties', '{}'::jsonb);
  v_buildings := coalesce(p_payload -> 'buildings', '[]'::jsonb);
  if v_project_id is null or v_expected_version is null
    or v_project_ref is null or v_name is null then
    raise exception 'V1_UPDATE_PROJECT_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  if jsonb_typeof(v_parties) <> 'object'
    or jsonb_typeof(v_buildings) <> 'array'
    or jsonb_array_length(v_buildings) = 0 then
    raise exception 'V1_UPDATE_PROJECT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  perform public.v1_assert_object_keys(
    v_parties,
    array[
      'client', 'consultant', 'main_contractor', 'subcontractors',
      'other_contractors'
    ],
    'update_project_parties'
  );
  if (v_parties ? 'subcontractors')
    and jsonb_typeof(v_parties -> 'subcontractors') <> 'array' then
    raise exception 'V1_SUBCONTRACTORS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;
  if (v_parties ? 'other_contractors')
    and jsonb_typeof(v_parties -> 'other_contractors') <> 'array' then
    raise exception 'V1_OTHER_CONTRACTORS_MUST_BE_AN_ARRAY' using errcode = '22023';
  end if;

  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED' using errcode = '42501';
  end if;

  select * into v_project
  from public.v1_projects project
  where project.id = v_project_id
  for update;
  if not found then
    raise exception 'V1_PROJECT_NOT_FOUND' using errcode = '22023';
  end if;
  if not public.v1_can_edit_project(v_project_id) then
    raise exception 'V1_PROJECT_EDIT_DENIED' using errcode = '42501';
  end if;
  if v_project.state not in ('draft', 'active') then
    raise exception 'V1_PROJECT_NOT_EDITABLE_IN_CURRENT_STATE'
      using errcode = '55000';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_update_project', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;
  if v_project.record_version <> v_expected_version then
    raise exception 'V1_PROJECT_VERSION_CONFLICT' using errcode = '40001';
  end if;

  -- Project setup is mutable, but its complete prior and resulting shape must
  -- remain recoverable from the immutable audit record.  This is especially
  -- important because party configuration is replaced as a set and retired
  -- building scopes are deactivated rather than removed.
  v_before := jsonb_build_object(
    'project', public.v1_project_projection(v_project_id),
    'parties', public.v1_project_parties_projection(v_project_id),
    'scopes', public.v1_project_scopes_projection(v_project_id)
  );
  update public.v1_projects project
     set project_ref = v_project_ref,
         name = v_name,
         job_contract_reference = nullif(
           btrim(coalesce(p_payload ->> 'job_contract_reference', '')), ''
         ),
         project_site = nullif(
           btrim(coalesce(p_payload ->> 'project_site', '')), ''
         ),
         start_date = nullif(
           btrim(coalesce(p_payload ->> 'start_date', '')), ''
         )::date,
         target_completion_date = nullif(
           btrim(coalesce(p_payload ->> 'target_completion_date', '')), ''
         )::date,
         notes = nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
         record_version = project.record_version + 1,
         updated_at = v_now
   where project.id = v_project_id
   returning * into v_project;

  -- Party rows are a mutable project-setup projection. Their prior values are
  -- retained in the immutable audit event below; no workflow table references
  -- a party row.
  delete from public.v1_project_parties party
  where party.project_id = v_project_id;
  if v_parties ? 'client' and v_parties -> 'client' <> 'null'::jsonb then
    perform public.v1_insert_project_party(v_project_id, 'client', 0, v_parties -> 'client');
  end if;
  if v_parties ? 'consultant' and v_parties -> 'consultant' <> 'null'::jsonb then
    perform public.v1_insert_project_party(v_project_id, 'consultant', 0, v_parties -> 'consultant');
  end if;
  if v_parties ? 'main_contractor' and v_parties -> 'main_contractor' <> 'null'::jsonb then
    perform public.v1_insert_project_party(v_project_id, 'main_contractor', 0, v_parties -> 'main_contractor');
  end if;
  v_position := 0;
  for v_party in select value from jsonb_array_elements(
    coalesce(v_parties -> 'subcontractors', '[]'::jsonb)
  ) loop
    perform public.v1_insert_project_party(v_project_id, 'subcontractor', v_position, v_party);
    v_position := v_position + 1;
  end loop;
  v_position := 0;
  for v_party in select value from jsonb_array_elements(
    coalesce(v_parties -> 'other_contractors', '[]'::jsonb)
  ) loop
    perform public.v1_insert_project_party(v_project_id, 'other_contractor', v_position, v_party);
    v_position := v_position + 1;
  end loop;

  -- Physical scopes retain identity. Omitted former buildings are deactivated,
  -- never deleted, so requests and receipt history stay attributable.
  for v_building in select value from jsonb_array_elements(v_buildings) loop
    perform public.v1_assert_object_keys(
      v_building,
      array['id', 'code', 'name', 'floors_levels', 'flags', 'delivery_address'],
      'update_project_building'
    );
    if nullif(btrim(coalesce(v_building ->> 'name', '')), '') is null then
      raise exception 'V1_BUILDING_NAME_REQUIRED' using errcode = '22023';
    end if;
    v_scope_id := nullif(btrim(coalesce(v_building ->> 'id', '')), '')::uuid;
    v_scope_code := lower(coalesce(
      nullif(btrim(coalesce(v_building ->> 'code', '')), ''),
      'building-' || coalesce((select count(*) + 1 from public.v1_project_scopes scope
        where scope.project_id = v_project_id and scope.scope_kind = 'building'), 1)::text
    ));
    if v_scope_code !~ '^[a-z0-9][a-z0-9_-]{0,63}$' then
      raise exception 'V1_BUILDING_CODE_INVALID' using errcode = '22023';
    end if;
    v_floors_levels := coalesce(v_building -> 'floors_levels', '[]'::jsonb);
    v_scope_flags := coalesce(v_building -> 'flags', '{}'::jsonb);
    if jsonb_typeof(v_floors_levels) <> 'array'
      or jsonb_typeof(v_scope_flags) <> 'object' then
      raise exception 'V1_BUILDING_CONFIGURATION_INVALID' using errcode = '22023';
    end if;
    if v_scope_id is null then
      insert into public.v1_project_scopes (
        project_id, scope_kind, scope_code, name, floors_levels, scope_flags,
        delivery_address, is_active, created_at, updated_at
      ) values (
        v_project_id, 'building', v_scope_code, btrim(v_building ->> 'name'),
        v_floors_levels, v_scope_flags,
        nullif(btrim(coalesce(v_building ->> 'delivery_address', '')), ''),
        true, v_now, v_now
      ) returning id into v_scope_id;
    else
      update public.v1_project_scopes scope
         set scope_code = v_scope_code,
             name = btrim(v_building ->> 'name'),
             floors_levels = v_floors_levels,
             scope_flags = v_scope_flags,
             delivery_address = nullif(
               btrim(coalesce(v_building ->> 'delivery_address', '')), ''
             ),
             is_active = true,
             record_version = scope.record_version + 1,
             updated_at = v_now
       where scope.id = v_scope_id
         and scope.project_id = v_project_id
         and scope.scope_kind = 'building';
      if not found then
        raise exception 'V1_PROJECT_BUILDING_NOT_FOUND' using errcode = '22023';
      end if;
    end if;
    v_active_scope_ids := array_append(v_active_scope_ids, v_scope_id);
  end loop;

  update public.v1_project_scopes scope
     set is_active = false,
         record_version = scope.record_version + 1,
         updated_at = v_now
   where scope.project_id = v_project_id
     and scope.scope_kind = 'building'
     and scope.is_active
     and not (scope.id = any(v_active_scope_ids));

  perform public.v1_write_audit_event(
    'project_updated', 'project', v_project_id, v_project_id, v_before,
    jsonb_build_object(
      'project', public.v1_project_projection(v_project_id),
      'parties', public.v1_project_parties_projection(v_project_id),
      'scopes', public.v1_project_scopes_projection(v_project_id)
    ),
    null, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'project_id', v_project_id,
    'record_version', v_project.record_version,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id),
    'parties', public.v1_project_parties_projection(v_project_id),
    'scopes', public.v1_project_scopes_projection(v_project_id)
  );
  perform public.v1_complete_idempotency(
    'v1_update_project', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_archive_project(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_now timestamptz := clock_timestamp();
  v_existing_response jsonb;
  v_project public.v1_projects%rowtype;
  v_project_id uuid;
  v_expected_version integer;
  v_reason text;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['project_id', 'expected_version', 'reason'],
    'archive_project_payload'
  );
  if v_actor is null or v_role <> 'admin' then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_expected_version := nullif(
    btrim(coalesce(p_payload ->> 'expected_version', '')), ''
  )::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_project_id is null or v_expected_version is null or v_reason is null then
    raise exception 'V1_ARCHIVE_PROJECT_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  select * into v_project from public.v1_projects project
  where project.id = v_project_id for update;
  if not found then
    raise exception 'V1_PROJECT_NOT_FOUND' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_archive_project', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_project.record_version <> v_expected_version then
    raise exception 'V1_PROJECT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if v_project.state = 'archived' then
    raise exception 'V1_PROJECT_ALREADY_ARCHIVED' using errcode = '55000';
  end if;
  if exists (
    select 1 from public.v1_material_requests request
    where request.project_id = v_project_id
      and request.state not in ('draft', 'received', 'closed', 'cancelled')
  ) then
    raise exception 'V1_ARCHIVE_PROJECT_HAS_OPEN_REQUESTS' using errcode = '55000';
  end if;
  update public.v1_projects project
     set state = 'archived', current_action_owner_role = 'none',
         record_version = project.record_version + 1, updated_at = v_now
   where project.id = v_project_id returning * into v_project;
  perform public.v1_write_audit_event(
    'project_archived', 'project', v_project_id, v_project_id,
    jsonb_build_object('state', 'pre_archive', 'record_version', v_expected_version),
    jsonb_build_object('state', 'archived', 'record_version', v_project.record_version,
      'safe_delete', true),
    v_reason, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'project_id', v_project_id, 'state', 'archived',
    'record_version', v_project.record_version,
    'idempotency_key', p_idempotency_key,
    'project', public.v1_project_projection(v_project_id)
  );
  perform public.v1_complete_idempotency(
    'v1_archive_project', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_edit_project(uuid) from public, anon, authenticated;
revoke all on function public.v1_update_project(jsonb, uuid) from public, anon, authenticated;
revoke all on function public.v1_archive_project(jsonb, uuid) from public, anon, authenticated;
grant execute on function public.v1_update_project(jsonb, uuid) to authenticated;
grant execute on function public.v1_archive_project(jsonb, uuid) to authenticated;
