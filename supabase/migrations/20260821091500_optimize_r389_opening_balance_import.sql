-- R38.13: make the supplier-aware opening-balance command practical at the
-- approved workbook size.
--
-- The command is deliberately atomic and server-authoritative. Its original
-- row loop nevertheless re-resolved the same Unknown Supplier, re-locked the
-- same receipt batch, and re-read a newly-created zero balance for every
-- workbook line. On the production database that repetitive work exceeded the
-- short REST statement timeout for the valid 1,155-row opening balance.
--
-- Data preservation: no existing inventory, supplier, receipt, movement or
-- import data is changed. This only avoids redundant reads within one new
-- import transaction.
-- Rollback: restore the prior loop blocks if a future workflow needs to make
-- a just-created inventory row concurrently reservable before import commit.

do $r38_13_opening_balance_import$
declare
  v_definition text;
  v_declarations_old text := $old$  v_unit_totals jsonb;
  v_batch_record record;$old$;
  v_declarations_new text := $new$  v_unit_totals jsonb;
  v_batch_record record;
  v_unknown_supplier public.v1_suppliers%rowtype;
  v_cached_receipt_key text;
  v_receipt_cache_key text;
  v_cached_receipt_batch_id uuid;$new$;
  v_before_loop_old text := $old$  if v_has_opening_balance then
    insert into public.v1_inventory_opening_balance_cutoffs (
      as_of_date, import_batch_id, file_sha256, claimed_by_auth_user_id
    ) values (
      v_opening_balance_as_of_date, v_batch_id, v_file_sha256, v_actor
    );
  end if;

  for v_row in select value from jsonb_array_elements(v_rows)$old$;
  v_before_loop_new text := $new$  if v_has_opening_balance then
    insert into public.v1_inventory_opening_balance_cutoffs (
      as_of_date, import_batch_id, file_sha256, claimed_by_auth_user_id
    ) values (
      v_opening_balance_as_of_date, v_batch_id, v_file_sha256, v_actor
    );
  end if;

  -- A missing supplier is a protected, canonical system identity. Resolve it
  -- once per import instead of performing the same locked lookup for every
  -- opening-balance row.
  select * into v_unknown_supplier
  from public.v1_suppliers
  where id = '00000000-0000-4000-8000-000000000389'::uuid;
  if not found then
    raise exception 'V1_UNKNOWN_SUPPLIER_NOT_FOUND' using errcode = '22023';
  end if;

  for v_row in select value from jsonb_array_elements(v_rows)$new$;
  v_supplier_old text := $old$    v_supplier_resolution := public.v1_resolve_inventory_supplier_r38_9(
      v_supplier_id, v_new_supplier_name, v_source_supplier_text,
      v_batch_id, v_row_number
    );
    v_supplier_id := (v_supplier_resolution ->> 'id')::uuid;
    v_supplier_code := v_supplier_resolution ->> 'supplier_code';
    v_supplier_name := v_supplier_resolution ->> 'name';
    if (v_supplier_resolution ->> 'created')::boolean then
      v_created_suppliers := v_created_suppliers + 1;
    end if;
    if (v_supplier_resolution ->> 'used_unknown')::boolean then
      v_unknown_supplier_rows := v_unknown_supplier_rows + 1;
      v_warnings := array_append(v_warnings, 'unknown_supplier');
    end if;$old$;
  v_supplier_new text := $new$    if v_supplier_id is null
      and v_new_supplier_name is null
      and (
        v_source_supplier_text is null
        or public.v1_supplier_name_key(v_source_supplier_text) in (
          'unknown', 'unknownsupplier', 'na'
        )
      ) then
      v_supplier_id := v_unknown_supplier.id;
      v_supplier_code := v_unknown_supplier.supplier_code;
      v_supplier_name := v_unknown_supplier.name;
      v_unknown_supplier_rows := v_unknown_supplier_rows + 1;
      v_warnings := array_append(v_warnings, 'unknown_supplier');
    elsif v_supplier_id = '00000000-0000-4000-8000-000000000389'::uuid
      and v_new_supplier_name is null
      and (
        v_source_supplier_text is null
        or public.v1_supplier_name_key(v_source_supplier_text) in (
          'unknown', 'unknownsupplier', 'na'
        )
      ) then
      v_supplier_code := v_unknown_supplier.supplier_code;
      v_supplier_name := v_unknown_supplier.name;
      v_unknown_supplier_rows := v_unknown_supplier_rows + 1;
      v_warnings := array_append(v_warnings, 'unknown_supplier');
    else
      v_supplier_resolution := public.v1_resolve_inventory_supplier_r38_9(
        v_supplier_id, v_new_supplier_name, v_source_supplier_text,
        v_batch_id, v_row_number
      );
      v_supplier_id := (v_supplier_resolution ->> 'id')::uuid;
      v_supplier_code := v_supplier_resolution ->> 'supplier_code';
      v_supplier_name := v_supplier_resolution ->> 'name';
      if (v_supplier_resolution ->> 'created')::boolean then
        v_created_suppliers := v_created_suppliers + 1;
      end if;
      if (v_supplier_resolution ->> 'used_unknown')::boolean then
        v_unknown_supplier_rows := v_unknown_supplier_rows + 1;
        v_warnings := array_append(v_warnings, 'unknown_supplier');
      end if;
    end if;$new$;
  v_receipt_old text := $old$    if v_action in ('opening_balance', 'add_stock') then
      v_normalized_reference :=
        public.v1_supplier_reference_key(v_supplier_reference);
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
        'v1_supplier_receipt:' || v_supplier_id::text || ':' ||
        v_source_type || ':' || v_normalized_reference || ':' ||
        v_received_date::text || ':' || lower(coalesce(v_location_bin, '')), 0
      ));
      select id, import_batch_id = v_batch_id into
        v_receipt_batch_id, v_created_receipt_batch
      from public.v1_supplier_receipt_batches
      where supplier_id = v_supplier_id
        and source_type = v_source_type
        and normalized_reference = v_normalized_reference
        and received_date = v_received_date
        and coalesce(lower(btrim(location_bin)), '') =
          coalesce(lower(btrim(v_location_bin)), '')
        and state = 'committed'
      for update;
      if found and not v_created_receipt_batch then
        raise exception 'V1_SUPPLIER_RECEIPT_REFERENCE_ALREADY_COMMITTED:%',
          v_row_number using errcode = '23505';
      elsif not found then
        v_receipt_batch_id := gen_random_uuid();
        insert into public.v1_supplier_receipt_batches (
          id, import_batch_id, supplier_id, supplier_code_snapshot,
          supplier_name_snapshot, source_type, supplier_reference,
          normalized_reference, received_date, location_bin,
          created_by_auth_user_id
        ) values (
          v_receipt_batch_id, v_batch_id, v_supplier_id, v_supplier_code,
          v_supplier_name, v_source_type, v_supplier_reference,
          v_normalized_reference, v_received_date, v_location_bin, v_actor
        );
        v_created_receipt_batches := v_created_receipt_batches + 1;
      end if;
    end if;$old$;
  v_receipt_new text := $new$    if v_action in ('opening_balance', 'add_stock') then
      v_normalized_reference :=
        public.v1_supplier_reference_key(v_supplier_reference);
      v_receipt_cache_key := v_supplier_id::text || ':' || v_source_type || ':' ||
        v_normalized_reference || ':' || v_received_date::text || ':' ||
        lower(coalesce(v_location_bin, ''));
      if v_cached_receipt_batch_id is not null
        and v_cached_receipt_key = v_receipt_cache_key then
        v_receipt_batch_id := v_cached_receipt_batch_id;
      else
        perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
          'v1_supplier_receipt:' || v_receipt_cache_key, 0
        ));
        select id, import_batch_id = v_batch_id into
          v_receipt_batch_id, v_created_receipt_batch
        from public.v1_supplier_receipt_batches
        where supplier_id = v_supplier_id
          and source_type = v_source_type
          and normalized_reference = v_normalized_reference
          and received_date = v_received_date
          and coalesce(lower(btrim(location_bin)), '') =
            coalesce(lower(btrim(v_location_bin)), '')
          and state = 'committed'
        for update;
        if found and not v_created_receipt_batch then
          raise exception 'V1_SUPPLIER_RECEIPT_REFERENCE_ALREADY_COMMITTED:%',
            v_row_number using errcode = '23505';
        elsif not found then
          v_receipt_batch_id := gen_random_uuid();
          insert into public.v1_supplier_receipt_batches (
            id, import_batch_id, supplier_id, supplier_code_snapshot,
            supplier_name_snapshot, source_type, supplier_reference,
            normalized_reference, received_date, location_bin,
            created_by_auth_user_id
          ) values (
            v_receipt_batch_id, v_batch_id, v_supplier_id, v_supplier_code,
            v_supplier_name, v_source_type, v_supplier_reference,
            v_normalized_reference, v_received_date, v_location_bin, v_actor
          );
          v_created_receipt_batches := v_created_receipt_batches + 1;
        end if;
        v_cached_receipt_batch_id := v_receipt_batch_id;
        v_cached_receipt_key := v_receipt_cache_key;
      end if;
    end if;$new$;
  v_balance_old text := $old$    select * into v_balance from public.v1_inventory_balances
    where inventory_item_id = v_item_id for update;
    select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
      into v_reserved
    from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.state in ('active', 'partially_consumed');$old$;
  v_balance_new text := $new$    if v_created_item then
      -- The balance row was inserted in this transaction and cannot have a
      -- committed reservation yet. Avoid re-reading a known zero balance.
      v_balance.on_hand_qty := 0;
      v_reserved := 0;
    else
      select * into v_balance from public.v1_inventory_balances
      where inventory_item_id = v_item_id for update;
      select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
        into v_reserved
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = v_item_id
        and reservation.state in ('active', 'partially_consumed');
    end if;$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure
  );

  if position(v_declarations_new in v_definition) = 0 then
    if position(v_declarations_old in v_definition) = 0 then
      raise exception 'V1_R38_13_DECLARATIONS_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_declarations_old, v_declarations_new);
  end if;
  if position(v_before_loop_new in v_definition) = 0 then
    if position(v_before_loop_old in v_definition) = 0 then
      raise exception 'V1_R38_13_LOOP_SETUP_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_before_loop_old, v_before_loop_new);
  end if;
  if position(v_supplier_new in v_definition) = 0 then
    if position(v_supplier_old in v_definition) = 0 then
      raise exception 'V1_R38_13_SUPPLIER_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_supplier_old, v_supplier_new);
  end if;
  if position(v_receipt_new in v_definition) = 0 then
    if position(v_receipt_old in v_definition) = 0 then
      raise exception 'V1_R38_13_RECEIPT_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_receipt_old, v_receipt_new);
  end if;
  if position(v_balance_new in v_definition) = 0 then
    if position(v_balance_old in v_definition) = 0 then
      raise exception 'V1_R38_13_BALANCE_BLOCK_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_balance_old, v_balance_new);
  end if;

  execute v_definition;
end;
$r38_13_opening_balance_import$;
