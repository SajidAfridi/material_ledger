-- R38.11: keep an explicit inventory item code authoritative during the
-- supplier-aware import.
--
-- Data preservation: this only changes future matching. Existing items,
-- balances, receipt evidence, movements and imports are untouched.
-- Rollback: restore the prior fallback condition only after confirming that no
-- workbook relies on distinct codes for otherwise similar catalogue items.

-- The original identity index predates controlled item codes and therefore
-- collapsed every same-description/brand/unit record into one item. Preserve
-- that safeguard only for legacy code-less records; coded catalogue items use
-- the already-existing case-insensitive item-code unique index.
drop index if exists public.v1_inventory_items_identity_unique_idx;
create unique index if not exists v1_inventory_items_identity_unique_idx
  on public.v1_inventory_items (
    lower(btrim(item_description)),
    lower(coalesce(btrim(brand_origin), '')),
    lower(btrim(unit))
  )
  where item_code is null;

do $r38_11_explicit_item_code$
declare
  v_definition text;
  v_identity_old text := $old$if v_item_id is null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_description)) = lower(btrim(v_description))
        and lower(coalesce(btrim(brand_origin), '')) =
          lower(coalesce(btrim(v_brand_origin), ''))
        and lower(btrim(unit)) = lower(btrim(v_unit));
    end if;$old$;
  v_identity_new text := $new$if v_item_id is null and v_item_code is null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_description)) = lower(btrim(v_description))
        and lower(coalesce(btrim(brand_origin), '')) =
          lower(coalesce(btrim(v_brand_origin), ''))
        and lower(btrim(unit)) = lower(btrim(v_unit))
        and item_code is null;
    end if;$new$;
  v_balance_old text := $old$if v_action = 'opening_balance' and v_balance.on_hand_qty <> 0 then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_OPENING_BALANCE_CONFLICT:%',
        v_row_number using errcode = '40001';
    end if;$old$;
  v_balance_new text := $new$if v_action = 'opening_balance'
      and v_balance.on_hand_qty <> 0
      and not exists (
        select 1
        from public.v1_inventory_import_rows prior_batch_row
        where prior_batch_row.import_batch_id = v_batch_id
          and prior_batch_row.inventory_item_id = v_item_id
          and prior_batch_row.id <> v_import_row_id
      ) then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_OPENING_BALANCE_CONFLICT:%',
        v_row_number using errcode = '40001';
    end if;$new$;
  v_price_old text := $old$if v_total_price is not null and v_total_price <> v_quantity * v_unit_price then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_calculated_total_price is not null
        and v_calculated_total_price <> v_quantity * v_unit_price then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_imported_total_price is not null
        and v_imported_total_price <> v_quantity * v_unit_price then
        v_warnings := array_append(v_warnings, 'imported_total_recalculated');
      end if;$old$;
  v_price_new text := $new$if v_total_price is not null
        and round(v_total_price, 2) <> round(v_quantity * v_unit_price, 2) then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_calculated_total_price is not null
        and round(v_calculated_total_price, 2) <>
          round(v_quantity * v_unit_price, 2) then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_imported_total_price is not null
        and round(v_imported_total_price, 2) <>
          round(v_quantity * v_unit_price, 2) then
        v_warnings := array_append(v_warnings, 'imported_total_recalculated');
      end if;$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure
  );

  if position(v_identity_new in v_definition) = 0 then
    if position(v_identity_old in v_definition) = 0 then
      raise exception 'V1_R38_11_EXPLICIT_ITEM_CODE_MATCH_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_identity_old, v_identity_new);
  end if;

  if position(v_balance_new in v_definition) = 0 then
    if position(v_balance_old in v_definition) = 0 then
      raise exception 'V1_R38_11_OPENING_BALANCE_GUARD_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_balance_old, v_balance_new);
  end if;

  if position(v_price_new in v_definition) = 0 then
    if position(v_price_old in v_definition) = 0 then
      raise exception 'V1_R38_11_TOTAL_PRICE_GUARD_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_price_old, v_price_new);
  end if;

  execute v_definition;
end;
$r38_11_explicit_item_code$;
