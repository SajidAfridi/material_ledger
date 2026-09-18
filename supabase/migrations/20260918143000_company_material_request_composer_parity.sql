-- Yorks V1 Company Material Requests: composer parity and safe catalogue search.
--
-- This migration preserves the separate Company authority model while adding
-- the technical item fields used by the established Material Request editor.
-- Existing rows remain valid and nullable fields are never backfilled with
-- invented values. Rollback is application flag-off / previous artifact; the
-- additive columns and recorded request data must be preserved and fixed
-- forward.

begin;

alter table public.v1_company_material_request_lines
  add column if not exists size_text text,
  add column if not exists model_reference text,
  add column if not exists equipment_tag text;

do $constraints$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_company_material_request_lines_size_length'
      and conrelid = 'public.v1_company_material_request_lines'::regclass
  ) then
    alter table public.v1_company_material_request_lines
      add constraint v1_company_material_request_lines_size_length
      check (size_text is null or char_length(size_text) <= 300);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_company_material_request_lines_model_length'
      and conrelid = 'public.v1_company_material_request_lines'::regclass
  ) then
    alter table public.v1_company_material_request_lines
      add constraint v1_company_material_request_lines_model_length
      check (model_reference is null or char_length(model_reference) <= 300);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_company_material_request_lines_equipment_tag_length'
      and conrelid = 'public.v1_company_material_request_lines'::regclass
  ) then
    alter table public.v1_company_material_request_lines
      add constraint v1_company_material_request_lines_equipment_tag_length
      check (equipment_tag is null or char_length(equipment_tag) <= 300);
  end if;
end;
$constraints$;

do $wrap_save$
begin
  if to_regprocedure(
    'public.v1_save_company_material_request_draft_composer_parity_base(jsonb)'
  ) is null then
    alter function public.v1_save_company_material_request_draft(jsonb)
      rename to v1_save_company_material_request_draft_composer_parity_base;
  end if;
end;
$wrap_save$;

revoke all on function
  public.v1_save_company_material_request_draft_composer_parity_base(jsonb)
  from public, anon, authenticated;
grant execute on function
  public.v1_save_company_material_request_draft_composer_parity_base(jsonb)
  to service_role;

create or replace function public.v1_save_company_material_request_draft(
  p_payload jsonb
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base_payload jsonb;
  v_result jsonb;
  v_request_id uuid;
  v_line jsonb;
  v_line_id uuid;
  v_size text;
  v_model text;
  v_equipment_tag text;
begin
  if jsonb_typeof(p_payload -> 'lines') <> 'array' then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  v_base_payload := jsonb_set(
    p_payload,
    '{lines}',
    coalesce((
      select jsonb_agg(
        line_value - 'size' - 'model' - 'equipment_tag'
        order by ordinal
      )
      from jsonb_array_elements(p_payload -> 'lines')
        with ordinality as line(line_value, ordinal)
    ), '[]'::jsonb),
    true
  );

  v_result := public.v1_save_company_material_request_draft_composer_parity_base(
    v_base_payload
  );
  v_request_id := (v_result ->> 'id')::uuid;

  for v_line in select value from jsonb_array_elements(p_payload -> 'lines') loop
    perform public.v1_assert_object_keys(v_line, array[
      'id', 'display_order', 'item_description', 'brand_origin', 'size',
      'model', 'equipment_tag', 'requested_qty', 'unit'
    ], 'company_material_request_line');
    begin
      v_line_id := (v_line ->> 'id')::uuid;
    exception when others then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINE_INVALID'
        using errcode = '22023';
    end;
    v_size := nullif(btrim(coalesce(v_line ->> 'size', '')), '');
    v_model := nullif(btrim(coalesce(v_line ->> 'model', '')), '');
    v_equipment_tag := nullif(
      btrim(coalesce(v_line ->> 'equipment_tag', '')), ''
    );
    if v_line_id is null
      or char_length(coalesce(v_size, '')) > 300
      or char_length(coalesce(v_model, '')) > 300
      or char_length(coalesce(v_equipment_tag, '')) > 300 then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINE_INVALID'
        using errcode = '22023';
    end if;
    update public.v1_company_material_request_lines line_record
    set size_text = v_size,
        model_reference = v_model,
        equipment_tag = v_equipment_tag,
        updated_at = clock_timestamp()
    where line_record.id = v_line_id
      and line_record.request_id = v_request_id;
    if not found then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINE_INVALID'
        using errcode = '22023';
    end if;
  end loop;

  return public.v1_company_material_request_projection(v_request_id);
end;
$$;

revoke all on function public.v1_save_company_material_request_draft(jsonb)
  from public, anon;
grant execute on function public.v1_save_company_material_request_draft(jsonb)
  to authenticated, service_role;

do $wrap_projection$
begin
  if to_regprocedure(
    'public.v1_company_material_request_projection_composer_parity_base(uuid)'
  ) is null then
    alter function public.v1_company_material_request_projection(uuid)
      rename to v1_company_material_request_projection_composer_parity_base;
  end if;
end;
$wrap_projection$;

revoke all on function
  public.v1_company_material_request_projection_composer_parity_base(uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_company_material_request_projection_composer_parity_base(uuid)
  to service_role;

create or replace function public.v1_company_material_request_projection(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_lines jsonb;
begin
  v_result := public.v1_company_material_request_projection_composer_parity_base(
    p_request_id
  );
  select coalesce(jsonb_agg(
    line_value || jsonb_strip_nulls(jsonb_build_object(
      'size', line_record.size_text,
      'model', line_record.model_reference,
      'equipment_tag', line_record.equipment_tag
    )) order by (line_value ->> 'display_order')::integer
  ), '[]'::jsonb)
  into v_lines
  from jsonb_array_elements(v_result -> 'lines') line(line_value)
  join public.v1_company_material_request_lines line_record
    on line_record.id = (line_value ->> 'id')::uuid
   and line_record.request_id = p_request_id;
  return jsonb_set(v_result, '{lines}', v_lines, true);
end;
$$;

revoke all on function public.v1_company_material_request_projection(uuid)
  from public, anon;
grant execute on function public.v1_company_material_request_projection(uuid)
  to authenticated, service_role;

create or replace function public.v1_search_company_material_request_candidates(
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_query text,
  p_limit integer default 18
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := lower(regexp_replace(
    btrim(coalesce(p_query, '')), '\s+', ' ', 'g'
  ));
  v_limit integer := least(greatest(coalesce(p_limit, 18), 1), 30);
begin
  if v_actor is null
    or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_active_authorization(
      v_actor, p_category_id, p_responsible_unit_id, 'requester'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_SEARCH_DENIED'
      using errcode = '42501';
  end if;
  if length(v_query) < 2
    or not exists (
      select 1
      from public.v1_company_material_request_categories category
      join public.v1_company_material_request_units unit_record
        on unit_record.id = p_responsible_unit_id
      where category.id = p_category_id
        and category.is_active
        and unit_record.is_active
    ) then
    raise exception 'V1_COMPANY_MATERIAL_SEARCH_INVALID'
      using errcode = '22023';
  end if;

  return coalesce((
    with ranked as (
      select item.*,
        lower(concat_ws(' ', item.item_code, item.item_description,
          item.brand_origin, item.size_text, item.model_reference, item.unit
        )) as searchable_text,
        case
          when lower(coalesce(item.item_code, '')) = v_query then 0
          when lower(item.item_description) = v_query then 1
          when lower(item.item_description) like v_query || '%' then 2
          when lower(coalesce(item.item_code, '')) like v_query || '%' then 3
          else 4
        end as match_rank
      from public.v1_inventory_items item
      where item.is_active
        and position(v_query in lower(concat_ws(' ', item.item_code,
          item.item_description, item.brand_origin, item.size_text,
          item.model_reference, item.unit))) > 0
    ), limited as (
      select * from ranked
      order by match_rank, lower(item_description), id
      limit v_limit
    )
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id', limited.id,
      'source_kind', 'inventory',
      'item_code', limited.item_code,
      'item_description', limited.item_description,
      'brand_origin', limited.brand_origin,
      'size', limited.size_text,
      'model', limited.model_reference,
      'unit', limited.unit
    )) order by limited.match_rank, lower(limited.item_description), limited.id)
    from limited
  ), '[]'::jsonb);
end;
$$;

comment on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) is
  'Returns non-commercial active inventory catalogue suggestions only to an active requester authorized for the selected Company category and unit; stock and project facts are omitted.';

revoke all on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) from public, anon;
grant execute on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) to authenticated;

commit;
