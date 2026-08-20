-- Yorks R38.10 controlled inventory import contract.
--
-- This is an additive, data-preserving alignment with the approved Yorks
-- opening-balance workbook. The worksheet no longer asks users to maintain a
-- Source Type column: receipt provenance is derived server-side from the
-- controlled stock action. Existing categories, item links, stock movements
-- and import evidence retain their stable identifiers.

-- Keep the existing canonical identities while presenting the approved
-- category vocabulary consistently in the app, template and database. The
-- legacy normalized keys intentionally remain stable so historical mappings
-- continue to resolve without a data rewrite.
update public.v1_inventory_categories
set name = case normalized_name
  when 'acunits' then 'AC Unit'
  when 'airterminals' then 'Air Inlet & Outlet'
  when 'ductworkaccessories' then 'Ducting Materials'
  when 'fansequipment' then 'Fans & Ventilation'
  when 'toolsconsumables' then 'Tools & Equipment'
  else name
end,
updated_at = clock_timestamp()
where normalized_name in (
  'acunits', 'airterminals', 'ductworkaccessories', 'fansequipment',
  'toolsconsumables'
);

-- Electrical & Cable Management is a distinct approved family, not an alias
-- of Electrical & Controls. Remove the historic alias before inserting the
-- master row so imports resolve to the exact, intended category.
delete from public.v1_inventory_category_aliases
where normalized_alias = 'electricalcablemanagement';

insert into public.v1_inventory_categories (
  id, name, normalized_name, is_system, created_by_auth_user_id
)
values (
  '41000000-0000-4000-8000-000000000024',
  'Electrical & Cable Management',
  'electricalcablemanagement',
  true,
  null
)
on conflict (normalized_name) do update
set name = excluded.name,
    is_system = true,
    is_active = true,
    updated_at = clock_timestamp();

-- Preserve accepted legacy spellings as explicit aliases. They are mapping
-- evidence only; the names above remain the values shown in the UI/template.
insert into public.v1_inventory_category_aliases (
  category_id, alias_name, normalized_alias, created_by_auth_user_id
)
select category.id, seed.alias_name, seed.normalized_alias, null
from (
  values
    ('acunits', 'AC Units', 'acunits'),
    ('airterminals', 'Air Terminals', 'airterminals'),
    ('ductworkaccessories', 'Ductwork & Accessories', 'ductworkaccessories'),
    ('fansequipment', 'Fans & Equipment', 'fansequipment'),
    ('toolsconsumables', 'Tools & Consumables', 'toolsconsumables')
) as seed(category_normalized_name, alias_name, normalized_alias)
join public.v1_inventory_categories category
  on category.normalized_name = seed.category_normalized_name
on conflict (normalized_alias) do nothing;

-- The supplied approved opening balance contains these controlled units. They
-- are configuration records, so all clients retrieve one authoritative unit
-- source rather than inventing per-workbook values.
insert into public.v1_configuration_units (
  id, name, short_code, unit_type, decimal_places, is_system, is_active
)
select seed.id, seed.name, seed.short_code, seed.unit_type,
  seed.decimal_places, true, true
from (
  values
    ('c3810000-0000-4000-8000-000000000017'::uuid, 'Cartridge', 'Cartridge', 'count', 0),
    ('c3810000-0000-4000-8000-000000000018'::uuid, 'Coil', 'Coil', 'count', 0),
    ('c3810000-0000-4000-8000-000000000019'::uuid, 'Cylinder', 'Cylinder', 'count', 0),
    ('c3810000-0000-4000-8000-000000000020'::uuid, 'Drum', 'Drum', 'count', 0),
    ('c3810000-0000-4000-8000-000000000021'::uuid, 'Sheet', 'Sheet', 'count', 0),
    ('c3810000-0000-4000-8000-000000000022'::uuid, 'Tin', 'Tin', 'count', 0)
) as seed(id, name, short_code, unit_type, decimal_places)
where not exists (
  select 1
  from public.v1_configuration_units unit_record
  where lower(btrim(unit_record.short_code)) = lower(seed.short_code)
    and unit_record.is_active
)
on conflict (id) do update
set name = excluded.name,
    short_code = excluded.short_code,
    unit_type = excluded.unit_type,
    decimal_places = excluded.decimal_places,
    is_system = true,
    is_active = true,
    updated_at = clock_timestamp();

-- Both trusted import paths use the same Supabase-controlled unit set. The
-- R38.9 path remains receipt-provenance-only; corrections/removals use the
-- established adjustment import command below and never create fake receipts.
do $r38_10_units$
declare
  v_definition text;
  v_old text := $old$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'ton', 'boxes'$old$;
  v_new text := $new$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'each', 'ton', 'boxes', 'kg', 'litre', 'pack', 'lot', 'mtr',
        'cartridge', 'coil', 'cylinder', 'drum', 'sheet', 'tin'$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure
  );
  if position(v_new in v_definition) = 0 then
    if position(v_old in v_definition) = 0 then
      raise exception 'V1_R38_10_R389_UNIT_ALLOWLIST_NOT_FOUND';
    end if;
    execute replace(v_definition, v_old, v_new);
  end if;
end;
$r38_10_units$;

-- Extend the non-receipt import command with the two explicit correction
-- actions. A correction is still an append-only `adjustment` movement; a
-- decrease is locked against reservations before it can reduce on-hand stock.
alter table public.v1_inventory_import_rows
  drop constraint if exists v1_inventory_import_rows_stock_action_check;

alter table public.v1_inventory_import_rows
  add constraint v1_inventory_import_rows_stock_action_check
  check (stock_action in (
    'opening_balance', 'add_stock', 'remove_stock',
    'correction_increase', 'correction_decrease', 'no_stock_change'
  ));

do $r38_10_adjustments$
declare
  v_definition text;
  v_old_actions text := $old$'opening_balance', 'add_stock', 'remove_stock', 'no_stock_change'$old$;
  v_new_actions text := $new$'opening_balance', 'add_stock', 'remove_stock',
        'correction_increase', 'correction_decrease', 'no_stock_change'$new$;
  v_old_units text := $old$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box', 'ton', 'boxes'$old$;
  v_new_units text := $new$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'each', 'ton', 'boxes', 'kg', 'litre', 'pack', 'lot', 'mtr',
        'cartridge', 'coil', 'cylinder', 'drum', 'sheet', 'tin'$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory(jsonb,uuid)'::regprocedure
  );
  if position(v_new_actions in v_definition) = 0 then
    if position(v_old_actions in v_definition) = 0 then
      raise exception 'V1_R38_10_IMPORT_ACTION_ALLOWLIST_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old_actions, v_new_actions);
    v_definition := replace(
      v_definition,
      'if v_action = ''remove_stock'' then',
      'if v_action in (''remove_stock'', ''correction_increase'', ''correction_decrease'') then'
    );
    v_definition := replace(
      v_definition,
      'when ''remove_stock'' then -v_quantity',
      E'when ''remove_stock'' then -v_quantity\n      when ''correction_decrease'' then -v_quantity'
    );
  end if;
  if position(v_new_units in v_definition) = 0 then
    if position(v_old_units in v_definition) = 0 then
      raise exception 'V1_R38_10_IMPORT_UNIT_ALLOWLIST_NOT_FOUND';
    end if;
    v_definition := replace(v_definition, v_old_units, v_new_units);
  end if;
  execute v_definition;
end;
$r38_10_adjustments$;
