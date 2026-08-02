-- Yorks V1: preserve non-commercial technical context on MR snapshots.
-- This is additive: existing requests keep an empty technical object and all
-- operational/commercial boundaries remain unchanged.

begin;

alter table public.v1_material_request_lines
  add column if not exists technical_attributes jsonb not null default '{}'::jsonb;

alter table public.v1_material_request_lines
  drop constraint if exists v1_material_request_lines_technical_attributes_object_check;

alter table public.v1_material_request_lines
  add constraint v1_material_request_lines_technical_attributes_object_check
  check (jsonb_typeof(technical_attributes) = 'object');

create or replace function public.v1_material_request_line_projection(
  p_line_id uuid,
  p_include_commercial boolean
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', line_record.id,
    'display_order', line_record.display_order,
    'source_kind', line_record.source_kind,
    'source_boq_group_id', line_record.source_boq_group_id,
    'source_boq_row_id', line_record.source_boq_row_id,
    'item_description', line_record.item_description,
    'brand_origin', line_record.brand_origin,
    -- Only the two approved non-commercial fields cross the MR boundary.
    -- Unknown legacy keys remain stored for preservation but are not projected.
    'technical_attributes', jsonb_strip_nulls(jsonb_build_object(
      'size', line_record.technical_attributes ->> 'size',
      'planning_model_tag', line_record.technical_attributes ->> 'planning_model_tag'
    )),
    'requested_qty', line_record.requested_qty::text,
    'unit', line_record.unit
  ) || case when p_include_commercial then jsonb_strip_nulls(
    jsonb_build_object(
      'unit_cost', commercial.unit_cost::text,
      'total_cost', (line_record.requested_qty * commercial.unit_cost)::text,
      'currency_code', commercial.currency_code
    )
  ) else '{}'::jsonb end
  from public.v1_material_request_lines line_record
  left join public.v1_material_request_line_commercials commercial
    on commercial.request_line_id = line_record.id
  where line_record.id = p_line_id;
$$;

create or replace function public.v1_save_material_request_draft(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_expected_version integer;
  v_project_id uuid;
  v_scope_id uuid;
  v_title text;
  v_timing text;
  v_scheduled_date date;
  v_delivery_note text;
  v_lines jsonb;
  v_existing public.v1_material_requests%rowtype;
  v_request_exists boolean := false;
  v_line jsonb;
  v_line_id uuid;
  v_line_order integer;
  v_source_kind text;
  v_source_group_id uuid;
  v_source_row_id uuid;
  v_description text;
  v_brand_origin text;
  v_technical_attributes jsonb;
  v_requested_qty numeric(18, 4);
  v_unit text;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'request_id', 'expected_version', 'project_id', 'scope_id', 'title',
      'timing', 'scheduled_date', 'delivery_note', 'lines'
    ],
    'material_request_draft'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_title := nullif(btrim(coalesce(p_payload ->> 'title', '')), '');
  v_timing := coalesce(p_payload ->> 'timing', '');
  v_scheduled_date := nullif(p_payload ->> 'scheduled_date', '')::date;
  v_delivery_note := nullif(btrim(coalesce(p_payload ->> 'delivery_note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 0
    or v_project_id is null or v_scope_id is null
    or v_timing not in ('urgent', 'normal', 'scheduled')
    or jsonb_typeof(v_lines) <> 'array'
    or (v_timing = 'scheduled' and v_scheduled_date is null)
    or (v_timing <> 'scheduled' and v_scheduled_date is not null) then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  if not public.v1_can_create_material_request(v_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = v_scope_id and scope.project_id = v_project_id
      and scope.is_active
  ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;

  select * into v_existing from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  v_request_exists := found;
  if v_request_exists then
    if v_existing.state <> 'draft'
      or v_existing.created_by_auth_user_id <> v_actor then
      raise exception 'V1_MATERIAL_REQUEST_DRAFT_EDIT_DENIED' using errcode = '42501';
    end if;
    if v_existing.record_version <> v_expected_version then
      raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
    end if;
  elsif v_expected_version <> 0 then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
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
    v_source_group_id := nullif(
      btrim(coalesce(v_line ->> 'source_boq_group_id', '')), ''
    )::uuid;
    v_source_row_id := nullif(
      btrim(coalesce(v_line ->> 'source_boq_row_id', '')), ''
    )::uuid;
    v_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_brand_origin := nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), '');
    v_technical_attributes := coalesce(v_line -> 'technical_attributes', '{}'::jsonb);
    v_requested_qty := nullif(v_line ->> 'requested_qty', '')::numeric(18, 4);
    v_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    if v_line_id is null or v_line_order is null or v_line_order < 1
      or v_source_kind not in ('boq', 'excel', 'custom')
      or v_description is null or v_requested_qty is null or v_requested_qty <= 0
      or v_unit is null or jsonb_typeof(v_technical_attributes) <> 'object'
      or exists (
        select 1
        from jsonb_object_keys(v_technical_attributes) as key_name
        where key_name not in ('size', 'planning_model_tag')
      ) then
      raise exception 'V1_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end if;
    if v_source_kind = 'boq' then
      if v_source_group_id is null or v_source_row_id is null or not exists (
        select 1
        from public.v1_boq_groups group_record
        join public.v1_boq_rows row_record on row_record.group_id = group_record.id
        where group_record.id = v_source_group_id
          and group_record.project_id = v_project_id
          and row_record.id = v_source_row_id
      ) then
        raise exception 'V1_MATERIAL_REQUEST_BOQ_SOURCE_INVALID' using errcode = '22023';
      end if;
    elsif v_source_group_id is not null or v_source_row_id is not null then
      raise exception 'V1_MATERIAL_REQUEST_SOURCE_INVALID' using errcode = '22023';
    end if;
  end loop;

  if v_request_exists then
    update public.v1_material_requests
       set project_id = v_project_id,
           scope_id = v_scope_id,
           title = v_title,
           timing = v_timing,
           scheduled_date = v_scheduled_date,
           delivery_note = v_delivery_note,
           record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_request_id;
  else
    insert into public.v1_material_requests (
      id, project_id, scope_id, title, timing, scheduled_date, delivery_note,
      state, record_version, created_by_auth_user_id,
      current_action_owner_role, current_action_code, created_at, updated_at
    ) values (
      v_request_id, v_project_id, v_scope_id, v_title, v_timing,
      v_scheduled_date, v_delivery_note, 'draft', 1, v_actor,
      case when v_role = 'admin' then 'admin' else v_role end,
      'draft_owner', clock_timestamp(), clock_timestamp()
    );
  end if;

  delete from public.v1_material_request_lines where request_id = v_request_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.v1_material_request_lines (
      id, request_id, display_order, source_kind, source_boq_group_id,
      source_boq_row_id, item_description, brand_origin, technical_attributes,
      requested_qty, unit, created_at, updated_at
    ) values (
      (v_line ->> 'id')::uuid,
      v_request_id,
      (v_line ->> 'display_order')::integer,
      v_line ->> 'source_kind',
      nullif(v_line ->> 'source_boq_group_id', '')::uuid,
      nullif(v_line ->> 'source_boq_row_id', '')::uuid,
      btrim(v_line ->> 'item_description'),
      nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), ''),
      coalesce(v_line -> 'technical_attributes', '{}'::jsonb),
      (v_line ->> 'requested_qty')::numeric(18, 4),
      btrim(v_line ->> 'unit'),
      clock_timestamp(), clock_timestamp()
    );
  end loop;
  return public.v1_material_request_projection(v_request_id);
end;
$$;

commit;
