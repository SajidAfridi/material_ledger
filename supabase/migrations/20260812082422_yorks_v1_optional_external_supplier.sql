-- Product-owner-approved beta simplification: choosing External Supplier is
-- sufficient source attribution. Supplier name remains optional context.
-- Partial and unavailable decision reasons, quantities, authorization,
-- versions, locking, reservations, idempotency and audit remain unchanged.
do $optional_external_supplier$
declare
  v_definition text;
  v_old text := $old$or (v_decision <> 'unavailable' and v_source_kind = 'external_supplier' and (
        v_external_supplier is null or v_inventory_item_id is not null
      ))$old$;
  v_new text := $new$or (v_decision <> 'unavailable' and v_source_kind = 'external_supplier' and
        v_inventory_item_id is not null)$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_arrangement(jsonb,uuid)'::regprocedure
  );

  if position(v_old in v_definition) = 0 then
    if position(v_new in v_definition) > 0 then
      return;
    end if;
    raise exception 'V1_OPTIONAL_EXTERNAL_SUPPLIER_ANCHOR_MISSING';
  end if;

  v_definition := replace(v_definition, v_old, v_new);
  execute v_definition;
end;
$optional_external_supplier$;

comment on function public.v1_save_arrangement(jsonb, uuid) is
  'Trusted, versioned and idempotent arrangement save. External supplier name is optional; Partial and Cannot Provide Now reasons remain required.';
