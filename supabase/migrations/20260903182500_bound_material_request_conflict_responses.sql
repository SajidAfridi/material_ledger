-- Prevent the two other measured Material Request conflict paths from
-- entering PostgREST 14.5 serialization retries. Only the conflict raise is
-- replaced; all locks, authorization, validation, idempotency and writes are
-- identical to their preceding definitions. The shared helper preserves the
-- client-visible code/message and aborts the transaction with HTTP 409.
--
-- No rows, policies or grants change. Rollback: restore the two preceding
-- function definitions (which reintroduces the retry risk).

create or replace function public.v1_sync_material_request_private_draft(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_draft_id uuid;
  v_expected integer;
  v_client_updated_at timestamptz;
  v_data jsonb;
  v_line jsonb;
  v_current public.v1_material_request_private_drafts%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array[
      'draft_id', 'expected_sync_version', 'client_updated_at', 'draft_data'
    ], 'sync_material_request_private_draft'
  );
  v_draft_id := nullif(btrim(coalesce(p_payload ->> 'draft_id', '')), '')::uuid;
  v_expected := nullif(p_payload ->> 'expected_sync_version', '')::integer;
  v_client_updated_at := nullif(
    p_payload ->> 'client_updated_at', ''
  )::timestamptz;
  v_data := p_payload -> 'draft_data';
  if v_actor is null or not public.v1_current_actor_is_active()
    or v_draft_id is null or v_expected is null or v_expected < 0
    or v_client_updated_at is null or jsonb_typeof(v_data) <> 'object'
    or octet_length(v_data::text) > 1048576 then
    raise exception 'V1_PRIVATE_DRAFT_INVALID' using errcode = '22023';
  end if;
  perform public.v1_assert_object_keys(
    v_data, array[
      'project_id', 'scope_id', 'title', 'timing', 'scheduled_date',
      'delivery_note', 'lines'
    ], 'private_material_request_draft_data'
  );
  if jsonb_typeof(coalesce(v_data -> 'lines', '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(v_data -> 'lines', '[]'::jsonb)) > 1000
    or coalesce(v_data ->> 'timing', 'normal') not in (
      'urgent', 'normal', 'scheduled'
    ) or length(coalesce(v_data ->> 'title', '')) > 500
    or length(coalesce(v_data ->> 'delivery_note', '')) > 2000 then
    raise exception 'V1_PRIVATE_DRAFT_INVALID' using errcode = '22023';
  end if;
  if nullif(v_data ->> 'project_id', '') is not null
    and not public.v1_project_readable((v_data ->> 'project_id')::uuid) then
    raise exception 'V1_PRIVATE_DRAFT_PROJECT_DENIED' using errcode = '42501';
  end if;
  if nullif(v_data ->> 'scope_id', '') is not null and not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = (v_data ->> 'scope_id')::uuid
      and scope.project_id = (v_data ->> 'project_id')::uuid
      and scope.is_active
  ) then
    raise exception 'V1_PRIVATE_DRAFT_SCOPE_INVALID' using errcode = '22023';
  end if;
  for v_line in select value
    from jsonb_array_elements(coalesce(v_data -> 'lines', '[]'::jsonb))
  loop
    perform public.v1_assert_object_keys(
      v_line, array[
        'id', 'display_order', 'source_kind', 'source_boq_group_id',
        'source_boq_row_id', 'item_description', 'brand_origin',
        'technical_attributes', 'requested_qty', 'unit'
      ], 'private_material_request_draft_line'
    );
    if length(coalesce(v_line ->> 'item_description', '')) > 4000
      or length(coalesce(v_line ->> 'unit', '')) > 120
      or jsonb_typeof(coalesce(
        v_line -> 'technical_attributes', '{}'::jsonb
      )) <> 'object' then
      raise exception 'V1_PRIVATE_DRAFT_LINE_INVALID' using errcode = '22023';
    end if;
  end loop;
  if exists (
    select 1 from public.v1_material_requests request
    where request.id = v_draft_id and request.state <> 'draft'
  ) then
    raise exception 'V1_PRIVATE_DRAFT_ALREADY_SUBMITTED' using errcode = '22023';
  end if;

  select * into v_current
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = v_actor
  for update;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_sync_material_request_private_draft', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if (not found and v_expected <> 0)
    or (found and v_current.sync_version <> v_expected) then
    perform public.v1_raise_version_conflict('V1_PRIVATE_DRAFT_VERSION_CONFLICT');
  end if;

  insert into public.v1_material_request_private_drafts (
    draft_id, owner_auth_user_id, sync_version, draft_data,
    client_updated_at, created_at, updated_at
  ) values (
    v_draft_id, v_actor, 1, v_data, v_client_updated_at,
    clock_timestamp(), clock_timestamp()
  ) on conflict (draft_id, owner_auth_user_id) do update set
    sync_version = public.v1_material_request_private_drafts.sync_version + 1,
    draft_data = excluded.draft_data,
    client_updated_at = excluded.client_updated_at,
    updated_at = clock_timestamp();

  select jsonb_build_object(
    'draft_id', draft.draft_id,
    'sync_version', draft.sync_version,
    'draft_data', draft.draft_data,
    'client_updated_at', draft.client_updated_at,
    'server_updated_at', draft.updated_at
  ) into v_response
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = v_actor;

  perform public.v1_complete_idempotency(
    'v1_sync_material_request_private_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_update_material_request_for_approval(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_scope_id uuid;
  v_title text;
  v_timing text;
  v_scheduled_date date;
  v_delivery_note text;
  v_lines jsonb;
  v_line jsonb;
  v_line_id uuid;
  v_line_order integer;
  v_source_kind text;
  v_source_group_id uuid;
  v_source_row_id uuid;
  v_description text;
  v_technical_attributes jsonb;
  v_requested_qty numeric(18, 4);
  v_unit text;
  v_before jsonb;
  v_response jsonb;
  v_existing jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'request_id', 'expected_version', 'project_id', 'scope_id', 'title',
      'timing', 'scheduled_date', 'delivery_note', 'lines'
    ],
    'update_material_request_for_approval'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_title := nullif(btrim(coalesce(p_payload ->> 'title', '')), '');
  v_timing := coalesce(p_payload ->> 'timing', '');
  v_scheduled_date := nullif(p_payload ->> 'scheduled_date', '')::date;
  v_delivery_note := nullif(btrim(coalesce(p_payload ->> 'delivery_note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_scope_id is null or v_timing not in ('urgent', 'normal', 'scheduled')
    or jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) = 0
    or (v_timing = 'scheduled' and v_scheduled_date is null)
    or (v_timing <> 'scheduled' and v_scheduled_date is not null) then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_EDIT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_edit_material_request_before_approval(
    v_request_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_EDIT_DENIED'
      using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    perform public.v1_raise_version_conflict('V1_MATERIAL_REQUEST_VERSION_CONFLICT');
  end if;
  if nullif(p_payload ->> 'project_id', '')::uuid <> v_request.project_id
    or not exists (
      select 1 from public.v1_project_scopes scope
      where scope.id = v_scope_id and scope.project_id = v_request.project_id
        and scope.is_active
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array[
        'id', 'display_order', 'source_kind', 'source_boq_group_id',
        'source_boq_row_id', 'item_description', 'brand_origin',
        'technical_attributes', 'requested_qty', 'unit'
      ],
      'material_request_line'
    );
    v_line_id := nullif(btrim(coalesce(v_line ->> 'id', '')), '')::uuid;
    v_line_order := nullif(v_line ->> 'display_order', '')::integer;
    v_source_kind := coalesce(v_line ->> 'source_kind', '');
    v_source_group_id := nullif(v_line ->> 'source_boq_group_id', '')::uuid;
    v_source_row_id := nullif(v_line ->> 'source_boq_row_id', '')::uuid;
    v_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_technical_attributes := coalesce(v_line -> 'technical_attributes', '{}'::jsonb);
    v_requested_qty := nullif(v_line ->> 'requested_qty', '')::numeric(18, 4);
    v_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    if v_line_id is null or v_line_order is null or v_line_order < 1
      or v_source_kind not in ('boq', 'excel', 'custom')
      or v_description is null or v_requested_qty is null or v_requested_qty <= 0
      or v_unit is null or jsonb_typeof(v_technical_attributes) <> 'object' then
      raise exception 'V1_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end if;
    if v_source_kind = 'boq' then
      if v_source_group_id is null or v_source_row_id is null or not exists (
        select 1
        from public.v1_boq_groups group_record
        join public.v1_boq_rows row_record on row_record.group_id = group_record.id
        where group_record.id = v_source_group_id
          and group_record.project_id = v_request.project_id
          and group_record.scope_id = v_scope_id
          and not group_record.is_archived
          and row_record.id = v_source_row_id and not row_record.is_archived
      ) then
        raise exception 'V1_MATERIAL_REQUEST_BOQ_SOURCE_INVALID'
          using errcode = '22023';
      end if;
    elsif v_source_group_id is not null or v_source_row_id is not null then
      raise exception 'V1_MATERIAL_REQUEST_SOURCE_INVALID' using errcode = '22023';
    end if;
  end loop;
  if (select count(distinct (value ->> 'id')) from jsonb_array_elements(v_lines))
      <> jsonb_array_length(v_lines)
    or (select count(distinct (value ->> 'display_order'))
        from jsonb_array_elements(v_lines)) <> jsonb_array_length(v_lines) then
    raise exception 'V1_MATERIAL_REQUEST_LINES_DUPLICATE' using errcode = '22023';
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_update_material_request_for_approval', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_before := public.v1_material_request_projection(v_request_id);

  delete from public.v1_material_request_lines where request_id = v_request_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.v1_material_request_lines (
      id, request_id, display_order, source_kind, source_boq_group_id,
      source_boq_row_id, item_description, brand_origin, technical_attributes,
      requested_qty, unit, created_at, updated_at
    ) values (
      (v_line ->> 'id')::uuid, v_request_id,
      (v_line ->> 'display_order')::integer, v_line ->> 'source_kind',
      nullif(v_line ->> 'source_boq_group_id', '')::uuid,
      nullif(v_line ->> 'source_boq_row_id', '')::uuid,
      btrim(v_line ->> 'item_description'),
      nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), ''),
      public.v1_material_request_normalized_technical_attributes(
        coalesce(v_line -> 'technical_attributes', '{}'::jsonb),
        v_line ->> 'source_kind'
      ),
      (v_line ->> 'requested_qty')::numeric(18, 4),
      btrim(v_line ->> 'unit'), clock_timestamp(), clock_timestamp()
    );
  end loop;
  update public.v1_material_requests
  set scope_id = v_scope_id,
      title = v_title,
      timing = v_timing,
      scheduled_date = v_scheduled_date,
      delivery_note = v_delivery_note,
      state = 'awaiting_request_approval',
      current_action_owner_role = 'project_engineer',
      current_action_code = 'request_approval_required',
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_request_id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct member.member_auth_user_id, 'material_request_updated_for_approval',
    'material_request', v_request_id, v_request.project_id
  from public.v1_project_members member
  join public.v1_profiles profile on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = v_request.project_id
    and member.project_role = 'project_engineer'
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
    and profile.is_active and member.member_auth_user_id <> auth.uid();

  v_response := public.v1_material_request_projection(v_request_id);
  perform public.v1_write_audit_event(
    'material_request_updated_for_approval', 'material_request', v_request_id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'record_version', v_expected_version + 1,
      'line_count', jsonb_array_length(v_lines),
      'state', 'awaiting_request_approval'
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_update_material_request_for_approval', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;
