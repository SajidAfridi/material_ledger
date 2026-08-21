-- R38.12: converge the supplier-aware inventory import onto the live,
-- server-controlled unit master.
--
-- A previously deployed copy of the R38.10 migration could be recorded in the
-- migration ledger while the R38.9 function still retained its original
-- ten-unit literal allowlist. That left valid workbook values such as Pack,
-- Kg, Cartridge and Sheet accepted by the template/client but rejected by the
-- trusted command.
--
-- Data preservation: this changes validation for future imports only. Existing
-- items, balances, movements, receipt evidence and import results are not
-- rewritten.
-- Rollback: restore the extended literal allowlist only if configuration units
-- cease to be the authoritative source; do not remove imported stock.

do $r38_12_controlled_units$
declare
  v_definition text;
  v_legacy text := $legacy$or lower(v_unit) not in (
        'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'ton', 'boxes'
      )$legacy$;
  v_extended text := $extended$or lower(v_unit) not in (
        'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'each', 'ton', 'boxes', 'kg', 'litre', 'pack', 'lot', 'mtr',
        'cartridge', 'coil', 'cylinder', 'drum', 'sheet', 'tin'
      )$extended$;
  v_controlled text := $controlled$or not exists (
        select 1
        from public.v1_configuration_units controlled_unit
        where controlled_unit.is_active
          and (
            lower(btrim(controlled_unit.short_code)) = lower(btrim(v_unit))
            or lower(btrim(controlled_unit.name)) = lower(btrim(v_unit))
          )
      )$controlled$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure
  );

  if position(v_controlled in v_definition) = 0 then
    if position(v_extended in v_definition) > 0 then
      v_definition := replace(v_definition, v_extended, v_controlled);
    elsif position(v_legacy in v_definition) > 0 then
      v_definition := replace(v_definition, v_legacy, v_controlled);
    else
      raise exception 'V1_R38_12_R389_UNIT_VALIDATION_BLOCK_NOT_FOUND';
    end if;
    execute v_definition;
  end if;
end;
$r38_12_controlled_units$;

