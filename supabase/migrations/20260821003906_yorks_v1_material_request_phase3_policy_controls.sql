-- Yorks V1 Material Request Phase 3 policy controls and replacement recovery.
--
-- Data preservation:
-- * both controls are additive and published with the product-owner-approved
--   adoption defaults (creator self-approval allowed; external readiness is
--   captured but not yet mandatory);
-- * existing arrangement rows remain valid and gain only nullable readiness
--   evidence;
-- * a replacement is a new private Draft linked to the cancelled source. It
--   never reopens or rewrites the terminal source request or its arrangement;
-- * configuration drafts remain inert. Workflow commands read published_value
--   directly and therefore change only after the existing audited publish RPC.
--
-- Rollback is forward-only: publish the adoption defaults again, revoke the
-- Phase 3 RPCs, and hide the Phase 3 client controls. Do not drop linkage or
-- readiness columns after production evidence exists.

insert into public.v1_configuration_settings (
  setting_key, area, value_type, default_value, published_value, display_order
)
values
  ('requests.allow_authorized_creator_self_approval', 'material_requests',
    'boolean', 'true'::jsonb, 'true'::jsonb, 230),
  ('procurement.require_external_source_readiness',
    'procurement_inventory', 'boolean', 'false'::jsonb, 'false'::jsonb, 320)
on conflict (setting_key) do nothing;

alter function public.v1_validate_configuration_setting_value(text, jsonb)
  rename to v1_validate_configuration_setting_value_before_phase3;

create or replace function public.v1_validate_configuration_setting_value(
  p_setting_key text,
  p_value jsonb
) returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_setting_key in (
    'requests.allow_authorized_creator_self_approval',
    'procurement.require_external_source_readiness'
  ) then
    if p_value is null or jsonb_typeof(p_value) <> 'boolean' then
      raise exception 'V1_CONFIGURATION_BOOLEAN_REQUIRED'
        using errcode = '22023';
    end if;
    return;
  end if;
  perform public.v1_validate_configuration_setting_value_before_phase3(
    p_setting_key, p_value
  );
end;
$$;

revoke all on function
  public.v1_validate_configuration_setting_value_before_phase3(text, jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_validate_configuration_setting_value(text, jsonb)
  from public, anon, authenticated;
grant execute on function
  public.v1_validate_configuration_setting_value_before_phase3(text, jsonb)
  to service_role;
grant execute on function public.v1_validate_configuration_setting_value(text, jsonb)
  to service_role;

create or replace function public.v1_material_request_published_policy_boolean(
  p_setting_key text,
  p_fallback boolean
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when jsonb_typeof(setting.published_value) = 'boolean'
      then (setting.published_value #>> '{}')::boolean
    else p_fallback
  end
  from public.v1_configuration_settings setting
  where setting.setting_key = p_setting_key
  union all
  select p_fallback
  where not exists (
    select 1 from public.v1_configuration_settings setting
    where setting.setting_key = p_setting_key
  )
  limit 1;
$$;

revoke all on function
  public.v1_material_request_published_policy_boolean(text, boolean)
  from public, anon, authenticated;
grant execute on function
  public.v1_material_request_published_policy_boolean(text, boolean)
  to service_role;

-- Published policy now participates in both capability projection and the
-- trusted decision command. A draft configuration change cannot affect it.
create or replace function public.v1_can_decide_material_request(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_role text := public.v1_current_role();
  v_allow_self boolean := public.v1_material_request_published_policy_boolean(
    'requests.allow_authorized_creator_self_approval', true
  );
begin
  if auth.uid() is null or v_role not in ('project_engineer', 'admin')
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found then return false; end if;
  if not v_allow_self and v_request.created_by_auth_user_id = auth.uid() then
    return false;
  end if;
  return v_role = 'admin' or public.v1_has_active_project_membership(
    v_request.project_id, auth.uid(), 'project_engineer'
  );
end;
$$;

revoke all on function public.v1_can_decide_material_request(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_can_decide_material_request(uuid)
  to service_role;

-- Evidence for a lightweight external commitment. Supplier identity remains
-- optional; the confirmation, expected date and reference describe readiness
-- without introducing the deferred RFQ/quotation/PO suite.
alter table public.v1_procurement_arrangement_lines
  add column if not exists external_source_ready boolean not null default false,
  add column if not exists external_expected_date date,
  add column if not exists external_reference text;

alter table public.v1_procurement_arrangement_lines
  drop constraint if exists v1_arrangement_lines_external_readiness_check;
alter table public.v1_procurement_arrangement_lines
  add constraint v1_arrangement_lines_external_readiness_check check (
    (source_kind = 'external_supplier' and decision in ('full', 'partial'))
    or (external_source_ready = false and external_expected_date is null
      and external_reference is null)
  );
alter table public.v1_procurement_arrangement_lines
  drop constraint if exists v1_arrangement_lines_external_reference_check;
alter table public.v1_procurement_arrangement_lines
  add constraint v1_arrangement_lines_external_reference_check check (
    external_reference is null
    or (btrim(external_reference) <> '' and length(external_reference) <= 180)
  );

comment on column public.v1_procurement_arrangement_lines.external_source_ready is
  'Procurement confirmation that external quantity is physically available or firmly committed.';
comment on column public.v1_procurement_arrangement_lines.external_expected_date is
  'Optional expected availability date for an external source commitment.';
comment on column public.v1_procurement_arrangement_lines.external_reference is
  'Optional supplier commitment/reference; not a Purchase Order workflow.';

-- Preserve the complete commercial-safe legacy projection, then add only the
-- operational readiness keys and the published enforcement state.
alter function public.v1_arrangement_projection(uuid)
  rename to v1_arrangement_projection_before_phase3;

create or replace function public.v1_arrangement_projection(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result := public.v1_arrangement_projection_before_phase3(p_request_id);
  select jsonb_set(
    v_result || jsonb_build_object(
      'external_source_readiness_required',
      public.v1_material_request_published_policy_boolean(
        'procurement.require_external_source_readiness', false
      )
    ),
    '{arrangements}',
    coalesce(jsonb_agg(
      (arrangement_entry.value - 'lines') || jsonb_build_object(
        'lines', coalesce((
          select jsonb_agg(
            line_entry.value || jsonb_build_object(
              'external_source_ready', line_record.external_source_ready,
              'external_expected_date', line_record.external_expected_date,
              'external_reference', line_record.external_reference
            ) order by line_entry.ordinality
          )
          from jsonb_array_elements(coalesce(
            arrangement_entry.value -> 'lines', '[]'::jsonb
          )) with ordinality line_entry(value, ordinality)
          join public.v1_procurement_arrangement_lines line_record
            on line_record.id = (line_entry.value ->> 'id')::uuid
        ), '[]'::jsonb)
      ) order by arrangement_entry.ordinality
    ), '[]'::jsonb)
  ) into v_result
  from jsonb_array_elements(coalesce(
    v_result -> 'arrangements', '[]'::jsonb
  )) with ordinality arrangement_entry(value, ordinality);
  return v_result;
end;
$$;

revoke all on function public.v1_arrangement_projection_before_phase3(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_arrangement_projection(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_arrangement_projection_before_phase3(uuid)
  to service_role;
grant execute on function public.v1_arrangement_projection(uuid)
  to authenticated, service_role;

alter function public.v1_save_arrangement(jsonb, uuid)
  rename to v1_save_arrangement_before_phase3;

create or replace function public.v1_phase3_nested_idempotency_key(
  p_key uuid
) returns uuid
language sql
immutable
set search_path = ''
as $$
  select (
    substr(md5(p_key::text || ':phase3:arrangement'), 1, 8) || '-' ||
    substr(md5(p_key::text || ':phase3:arrangement'), 9, 4) || '-' ||
    substr(md5(p_key::text || ':phase3:arrangement'), 13, 4) || '-' ||
    substr(md5(p_key::text || ':phase3:arrangement'), 17, 4) || '-' ||
    substr(md5(p_key::text || ':phase3:arrangement'), 21, 12)
  )::uuid;
$$;

create or replace function public.v1_save_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lines jsonb;
  v_line jsonb;
  v_request_id uuid;
  v_project_id uuid;
  v_arrangement_id uuid;
  v_external boolean;
  v_unavailable boolean;
  v_ready boolean;
  v_expected_date date;
  v_reference text;
  v_require_readiness boolean :=
    public.v1_material_request_published_policy_boolean(
      'procurement.require_external_source_readiness', false
    );
  v_legacy_payload jsonb;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'arrangement_id', 'expected_request_version',
      'expected_arrangement_version', 'procurement_note', 'lines'],
    'save_arrangement_phase3'
  );
  v_arrangement_id := nullif(btrim(coalesce(
    p_payload ->> 'arrangement_id', ''
  )), '')::uuid;
  v_request_id := nullif(btrim(coalesce(
    p_payload ->> 'request_id', ''
  )), '')::uuid;
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_arrangement_id is null
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array['arrangement_line_id', 'source_kind', 'external_supplier',
        'inventory_item_id', 'decision', 'arranged_qty', 'reason', 'unit_cost',
        'external_source_ready', 'external_expected_date',
        'external_reference'],
      'arrangement_line_phase3'
    );
    if v_line ? 'external_source_ready'
      and jsonb_typeof(v_line -> 'external_source_ready')
        not in ('boolean', 'null') then
      raise exception 'V1_EXTERNAL_SOURCE_READINESS_INVALID'
        using errcode = '22023';
    end if;
    v_external := coalesce(v_line ->> 'source_kind', '') = 'external_supplier';
    v_unavailable := coalesce(v_line ->> 'decision', '') = 'unavailable';
    v_ready := coalesce((v_line ->> 'external_source_ready')::boolean, false);
    v_reference := nullif(btrim(coalesce(
      v_line ->> 'external_reference', ''
    )), '');
    if v_reference is not null and length(v_reference) > 180 then
      raise exception 'V1_EXTERNAL_SOURCE_REFERENCE_INVALID'
        using errcode = '22023';
    end if;
    begin
      v_expected_date := nullif(btrim(coalesce(
        v_line ->> 'external_expected_date', ''
      )), '')::date;
    exception when others then
      raise exception 'V1_EXTERNAL_SOURCE_EXPECTED_DATE_INVALID'
        using errcode = '22023';
    end;
    if (not v_external or v_unavailable) and (
      v_ready or v_reference is not null or v_expected_date is not null
    ) then
      raise exception 'V1_EXTERNAL_SOURCE_EVIDENCE_NOT_APPLICABLE'
        using errcode = '22023';
    end if;
    if v_external and not v_unavailable and v_require_readiness
      and not v_ready then
      raise exception 'V1_EXTERNAL_SOURCE_READINESS_REQUIRED'
        using errcode = '22023';
    end if;
  end loop;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_arrangement_phase3', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  select jsonb_set(
    p_payload, '{lines}',
    coalesce(jsonb_agg(
      value - 'external_source_ready' - 'external_expected_date'
        - 'external_reference'
      order by ordinality
    ), '[]'::jsonb)
  ) into v_legacy_payload
  from jsonb_array_elements(v_lines) with ordinality entry(value, ordinality);

  perform public.v1_save_arrangement_before_phase3(
    v_legacy_payload,
    public.v1_phase3_nested_idempotency_key(p_idempotency_key)
  );

  update public.v1_procurement_arrangement_lines line_record
  set external_source_ready = case
        when entry.value ->> 'source_kind' = 'external_supplier'
          and entry.value ->> 'decision' <> 'unavailable'
        then coalesce((entry.value ->> 'external_source_ready')::boolean, false)
        else false end,
      external_expected_date = case
        when entry.value ->> 'source_kind' = 'external_supplier'
          and entry.value ->> 'decision' <> 'unavailable'
        then nullif(btrim(coalesce(
          entry.value ->> 'external_expected_date', ''
        )), '')::date else null end,
      external_reference = case
        when entry.value ->> 'source_kind' = 'external_supplier'
          and entry.value ->> 'decision' <> 'unavailable'
        then nullif(btrim(coalesce(
          entry.value ->> 'external_reference', ''
        )), '') else null end,
      updated_at = clock_timestamp()
  from jsonb_array_elements(v_lines) entry(value)
  where line_record.id = (entry.value ->> 'arrangement_line_id')::uuid
    and line_record.arrangement_id = v_arrangement_id;

  if exists (
    select 1 from jsonb_array_elements(v_lines) entry(value)
    where entry.value ->> 'source_kind' = 'external_supplier'
      and entry.value ->> 'decision' <> 'unavailable'
  ) then
    select request_record.project_id into v_project_id
    from public.v1_material_requests request_record
    where request_record.id = v_request_id;
    perform public.v1_write_audit_event(
      'external_source_readiness_saved', 'procurement_arrangement',
      v_arrangement_id, v_project_id, null,
      jsonb_build_object(
        'request_id', v_request_id,
        'enforcement_required', v_require_readiness,
        'external_line_count', (select count(*)
          from jsonb_array_elements(v_lines) entry(value)
          where entry.value ->> 'source_kind' = 'external_supplier'
            and entry.value ->> 'decision' <> 'unavailable'),
        'confirmed_line_count', (select count(*)
          from jsonb_array_elements(v_lines) entry(value)
          where entry.value ->> 'source_kind' = 'external_supplier'
            and entry.value ->> 'decision' <> 'unavailable'
            and coalesce(
              (entry.value ->> 'external_source_ready')::boolean, false
            )),
        'expected_date_count', (select count(*)
          from jsonb_array_elements(v_lines) entry(value)
          where nullif(btrim(coalesce(
            entry.value ->> 'external_expected_date', ''
          )), '') is not null),
        'reference_count', (select count(*)
          from jsonb_array_elements(v_lines) entry(value)
          where nullif(btrim(coalesce(
            entry.value ->> 'external_reference', ''
          )), '') is not null)
      ), 'External source readiness evidence saved', p_idempotency_key
    );
  end if;

  v_response := public.v1_arrangement_projection(
    v_request_id
  );
  perform public.v1_complete_idempotency(
    'v1_save_arrangement_phase3', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_phase3_nested_idempotency_key(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_save_arrangement_before_phase3(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_phase3_nested_idempotency_key(uuid)
  to service_role;
grant execute on function public.v1_save_arrangement_before_phase3(jsonb, uuid)
  to service_role;
grant execute on function public.v1_save_arrangement(jsonb, uuid)
  to authenticated, service_role;

-- A replacement is linked evidence, not a reopened lifecycle. Only one live
-- replacement chain step may originate from a cancelled all-unavailable
-- request, and the new draft is private to the actor until explicit submit.
alter table public.v1_material_requests
  add column if not exists replacement_of_request_id uuid
    references public.v1_material_requests (id) on delete restrict;
alter table public.v1_material_request_lines
  add column if not exists replacement_of_request_line_id uuid
    references public.v1_material_request_lines (id) on delete restrict;

create unique index if not exists v1_material_requests_replacement_source_uidx
  on public.v1_material_requests (replacement_of_request_id)
  where replacement_of_request_id is not null;
create index if not exists v1_material_request_lines_replacement_source_idx
  on public.v1_material_request_lines (replacement_of_request_line_id)
  where replacement_of_request_line_id is not null;

create or replace function public.v1_can_create_replacement_material_request(
  p_source_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_source public.v1_material_requests%rowtype;
  v_arrangement_id uuid;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_source
  from public.v1_material_requests request_record
  where request_record.id = p_source_request_id;
  if not found or v_source.state <> 'cancelled'
    or not public.v1_material_request_readable(v_source.id)
    or not public.v1_can_create_material_request(v_source.project_id)
    or exists (
      select 1 from public.v1_material_requests replacement
      where replacement.replacement_of_request_id = v_source.id
    )
    or exists (
      select 1 from public.v1_material_dispatches dispatch
      where dispatch.request_id = v_source.id
    ) then
    return false;
  end if;
  select arrangement.id into v_arrangement_id
  from public.v1_procurement_arrangements arrangement
  where arrangement.request_id = v_source.id
    and arrangement.saved_at is not null
  order by arrangement.arrangement_version desc, arrangement.id desc
  limit 1;
  if v_arrangement_id is null then return false; end if;
  return exists (
    select 1 from public.v1_procurement_arrangement_lines line_record
    where line_record.arrangement_id = v_arrangement_id
  ) and not exists (
    select 1 from public.v1_procurement_arrangement_lines line_record
    where line_record.arrangement_id = v_arrangement_id
      and (line_record.decision <> 'unavailable'
        or line_record.arranged_qty <> 0)
  );
end;
$$;

create or replace function public.v1_material_request_phase3_policy_projection(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_replacement_id uuid;
  v_replacement_readable boolean := false;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_POLICY_NOT_READABLE'
      using errcode = '42501';
  end if;
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  select replacement.id into v_replacement_id
  from public.v1_material_requests replacement
  where replacement.replacement_of_request_id = p_request_id;
  if v_replacement_id is not null then
    v_replacement_readable := public.v1_material_request_readable(
      v_replacement_id
    );
  end if;
  return jsonb_build_object(
    'request_id', p_request_id,
    'allow_authorized_creator_self_approval',
      public.v1_material_request_published_policy_boolean(
        'requests.allow_authorized_creator_self_approval', true
      ),
    'require_external_source_readiness',
      public.v1_material_request_published_policy_boolean(
        'procurement.require_external_source_readiness', false
      ),
    'can_create_replacement',
      public.v1_can_create_replacement_material_request(p_request_id),
    'replacement_exists', v_replacement_id is not null,
    'replacement_request_id', case when v_replacement_readable
      then v_replacement_id else null end,
    'replacement_of_request_id', v_request.replacement_of_request_id
  );
end;
$$;

create or replace function public.v1_create_replacement_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_source_id uuid;
  v_expected_version integer;
  v_source public.v1_material_requests%rowtype;
  v_replacement_id uuid := gen_random_uuid();
  v_existing jsonb;
  v_response jsonb;
  v_actor_name text;
  v_exact_role text := public.v1_current_exact_role();
begin
  perform public.v1_assert_object_keys(
    p_payload, array['source_request_id', 'expected_source_version'],
    'create_replacement_material_request'
  );
  v_source_id := nullif(btrim(coalesce(
    p_payload ->> 'source_request_id', ''
  )), '')::uuid;
  v_expected_version := nullif(
    p_payload ->> 'expected_source_version', ''
  )::integer;
  if v_source_id is null or v_expected_version is null
    or v_expected_version < 1 then
    raise exception 'V1_REPLACEMENT_REQUEST_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_source
  from public.v1_material_requests request_record
  where request_record.id = v_source_id
  for update;
  if not found then
    raise exception 'V1_REPLACEMENT_REQUEST_NOT_ELIGIBLE'
      using errcode = '22023';
  end if;
  if not public.v1_material_request_readable(v_source_id)
    or not public.v1_can_create_material_request(v_source.project_id) then
    raise exception 'V1_REPLACEMENT_REQUEST_DENIED'
      using errcode = '42501';
  end if;
  -- Resolve an exact retry before re-evaluating one-time eligibility. The
  -- first successful call creates the linked replacement, which intentionally
  -- makes the source ineligible for a second distinct command.
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_replacement_material_request', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if not public.v1_can_create_replacement_material_request(v_source_id) then
    raise exception 'V1_REPLACEMENT_REQUEST_NOT_ELIGIBLE'
      using errcode = '22023';
  end if;
  if v_source.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  select public.v1_safe_profile_display_name(
    profile.display_name, profile.auth_user_id
  ) into v_actor_name
  from public.v1_profiles profile
  where profile.auth_user_id = auth.uid();

  insert into public.v1_material_requests (
    id, project_id, scope_id, title, timing, scheduled_date, delivery_note,
    state, record_version, created_by_auth_user_id, requester_display_name,
    requester_project_role, requester_exact_role,
    current_action_owner_role, current_action_code,
    replacement_of_request_id, created_at, updated_at
  ) values (
    v_replacement_id, v_source.project_id, v_source.scope_id, v_source.title,
    v_source.timing, v_source.scheduled_date, v_source.delivery_note,
    'draft', 1, auth.uid(), v_actor_name,
    case when public.v1_current_role() = 'site_engineer'
      then 'site_engineer' else 'project_engineer' end,
    v_exact_role, 'project_engineer', 'draft_owner', v_source.id,
    clock_timestamp(), clock_timestamp()
  );
  insert into public.v1_material_request_lines (
    id, request_id, display_order, source_kind, source_boq_group_id,
    source_boq_row_id, item_description, brand_origin, requested_qty, unit,
    technical_attributes, replacement_of_request_line_id, created_at,
    updated_at
  )
  select gen_random_uuid(), v_replacement_id, source_line.display_order,
    source_line.source_kind, source_line.source_boq_group_id,
    source_line.source_boq_row_id, source_line.item_description,
    source_line.brand_origin, source_line.requested_qty, source_line.unit,
    coalesce(source_line.technical_attributes, '{}'::jsonb), source_line.id,
    clock_timestamp(), clock_timestamp()
  from public.v1_material_request_lines source_line
  where source_line.request_id = v_source.id
  order by source_line.display_order, source_line.id;

  v_response := public.v1_material_request_projection(v_replacement_id);
  perform public.v1_write_audit_event(
    'material_request_replacement_draft_created', 'material_request',
    v_replacement_id, v_source.project_id, null,
    jsonb_build_object(
      'state', 'draft',
      'source_request_id', v_source.id,
      'source_request_number', v_source.request_number,
      'source_record_version', v_source.record_version,
      'line_count', (select count(*)
        from public.v1_material_request_lines line_record
        where line_record.request_id = v_replacement_id),
      'created_by_exact_role', v_exact_role
    ), 'All-unavailable cancelled request replacement', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_replacement_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_create_replacement_material_request(uuid)
  from public, anon, authenticated;
revoke all on function
  public.v1_material_request_phase3_policy_projection(uuid)
  from public, anon, authenticated;
revoke all on function
  public.v1_create_replacement_material_request(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_can_create_replacement_material_request(uuid)
  to service_role;
grant execute on function
  public.v1_material_request_phase3_policy_projection(uuid)
  to authenticated, service_role;
grant execute on function
  public.v1_create_replacement_material_request(jsonb, uuid)
  to authenticated, service_role;
