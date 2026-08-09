-- Yorks R38.3: a separate, metadata-only item-master command for the
-- Warehouse Item detail workspace. Quantity remains exclusively controlled by
-- stock movements and Material Request reservations.
--
-- Data preservation and rollback:
-- * no relation or historical movement/reservation is removed or rewritten;
-- * balance.record_version is intentionally untouched by a metadata edit;
-- * callers may stop using this command to roll back the UI without changing
--   any committed warehouse quantity or inventory history.

create or replace function public.v1_update_inventory_item(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item_id uuid;
  v_expected_metadata_version integer;
  v_item public.v1_inventory_items%rowtype;
  v_existing jsonb;
  v_category jsonb;
  v_response jsonb;
  v_code text;
  v_description text;
  v_unit text;
  v_minimum_text text;
  v_minimum numeric(18,4);
  v_brand text;
  v_size text;
  v_model text;
  v_location text;
  v_notes text;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'inventory_item_id','expected_metadata_version','item_code',
      'item_description','category_id','new_category_name',
      'new_category_parent_id','source_category_text','brand_origin',
      'size_text','model_reference','unit','minimum_stock','location_bin',
      'notes'
    ],
    'update_inventory_item'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_ITEM_UPDATE_DENIED' using errcode = '42501';
  end if;

  begin
    v_item_id := nullif(btrim(coalesce(p_payload ->> 'inventory_item_id', '')), '')::uuid;
    v_expected_metadata_version := nullif(
      p_payload ->> 'expected_metadata_version', ''
    )::integer;
  exception
    when invalid_text_representation then
      raise exception 'V1_INVENTORY_ITEM_UPDATE_PAYLOAD_INVALID' using errcode = '22023';
  end;
  v_code := nullif(btrim(coalesce(p_payload ->> 'item_code', '')), '');
  v_description := nullif(btrim(coalesce(p_payload ->> 'item_description', '')), '');
  v_unit := nullif(btrim(coalesce(p_payload ->> 'unit', '')), '');
  v_minimum_text := nullif(btrim(coalesce(p_payload ->> 'minimum_stock', '')), '');
  v_brand := nullif(btrim(coalesce(p_payload ->> 'brand_origin', '')), '');
  v_size := nullif(btrim(coalesce(p_payload ->> 'size_text', '')), '');
  v_model := nullif(btrim(coalesce(p_payload ->> 'model_reference', '')), '');
  v_location := nullif(btrim(coalesce(p_payload ->> 'location_bin', '')), '');
  v_notes := nullif(btrim(coalesce(p_payload ->> 'notes', '')), '');
  begin
    v_minimum := v_minimum_text::numeric(18,4);
  exception
    when invalid_text_representation or numeric_value_out_of_range then
      raise exception 'V1_INVENTORY_ITEM_UPDATE_PAYLOAD_INVALID' using errcode = '22023';
  end;

  if v_item_id is null
    or v_expected_metadata_version is null
    or v_expected_metadata_version < 1
    or v_description is null
    or v_unit is null
    or char_length(v_description) > 500
    or char_length(v_unit) > 80
    or (v_code is not null and char_length(v_code) > 120)
    or (v_minimum is not null and v_minimum < 0) then
    raise exception 'V1_INVENTORY_ITEM_UPDATE_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  -- A lost response must return the original projection even if a later stock
  -- movement increments balance.record_version in the meantime.
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_update_inventory_item', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  select * into v_item
  from public.v1_inventory_items
  where id = v_item_id
  for update;
  if not found then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  if v_item.metadata_record_version <> v_expected_metadata_version then
    raise exception 'V1_INVENTORY_ITEM_METADATA_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_inventory_items item
    where item.id <> v_item_id
      and lower(btrim(item.item_description)) = lower(v_description)
      and lower(coalesce(btrim(item.brand_origin), '')) = lower(coalesce(v_brand, ''))
      and lower(btrim(item.unit)) = lower(v_unit)
  ) then
    raise exception 'V1_INVENTORY_ITEM_DUPLICATE' using errcode = '23505';
  end if;
  if v_code is not null and exists (
    select 1 from public.v1_inventory_items item
    where item.id <> v_item_id and lower(btrim(item.item_code)) = lower(v_code)
  ) then
    raise exception 'V1_INVENTORY_ITEM_CODE_DUPLICATE' using errcode = '23505';
  end if;

  v_category := public.v1_resolve_inventory_category_v2(
    nullif(p_payload ->> 'category_id', '')::uuid,
    p_payload ->> 'new_category_name',
    nullif(p_payload ->> 'new_category_parent_id', '')::uuid,
    p_payload ->> 'source_category_text'
  );
  if v_category is null then
    raise exception 'V1_INVENTORY_CATEGORY_REQUIRED' using errcode = '22023';
  end if;

  update public.v1_inventory_items
     set item_code = v_code,
         item_description = v_description,
         category_id = (v_category ->> 'id')::uuid,
         brand_origin = v_brand,
         size_text = v_size,
         model_reference = v_model,
         unit = v_unit,
         minimum_stock = v_minimum,
         location_bin = v_location,
         notes = v_notes,
         metadata_record_version = metadata_record_version + 1,
         updated_at = clock_timestamp()
   where id = v_item_id;

  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    'inventory_item_metadata_updated',
    'inventory_item',
    v_item_id,
    null,
    jsonb_build_object(
      'item_code', v_item.item_code,
      'item_description', v_item.item_description,
      'category_id', v_item.category_id,
      'brand_origin', v_item.brand_origin,
      'size_text', v_item.size_text,
      'model_reference', v_item.model_reference,
      'unit', v_item.unit,
      'minimum_stock', v_item.minimum_stock,
      'location_bin', v_item.location_bin,
      'notes', v_item.notes,
      'metadata_record_version', v_item.metadata_record_version
    ),
    v_response,
    'Inventory item metadata updated',
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_update_inventory_item', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_update_inventory_item(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_update_inventory_item(jsonb, uuid)
  to authenticated, service_role;
