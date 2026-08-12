-- Yorks V1: add the two requested controlled unit values without changing any
-- existing unit record, material request, inventory item or stock balance.
-- The inventory description trigger covers every future trusted command,
-- including item creation, metadata edits and workbook imports.
--
-- Data preservation and rollback:
-- * existing master, item, movement, reservation and document rows are not
--   rewritten;
-- * existing custom legacy units remain available under their stable IDs;
-- * rolling back a client build simply hides these choices; committed rows
--   remain valid operational history.

insert into public."materialUnits" (id, data)
values
  (
    'unit-ton',
    jsonb_build_object(
      'id', 'unit-ton',
      'name', 'Ton',
      'symbol', 'Ton',
      'secondaryName', 'ٹن',
      'sortOrder', 8,
      'isCustom', false,
      'status', 'approved',
      'updatedAt', '2026-08-10T15:51:02.000Z',
      'updatedBy', 'Yorks V1 controlled-unit migration'
    )
  ),
  (
    'unit-boxes',
    jsonb_build_object(
      'id', 'unit-boxes',
      'name', 'Boxes',
      'symbol', 'Boxes',
      'secondaryName', 'ڈبے',
      'sortOrder', 9,
      'isCustom', false,
      'status', 'approved',
      'updatedAt', '2026-08-10T15:51:02.000Z',
      'updatedBy', 'Yorks V1 controlled-unit migration'
    )
  )
on conflict (id) do nothing;

create or replace function public.v1_normalize_inventory_item_description()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.item_description := nullif(btrim(new.item_description), '');
  if new.item_description is not null then
    new.item_description := upper(left(new.item_description, 1))
      || substr(new.item_description, 2);
  end if;
  return new;
end;
$$;

drop trigger if exists v1_normalize_inventory_item_description
  on public.v1_inventory_items;
create trigger v1_normalize_inventory_item_description
before insert or update of item_description on public.v1_inventory_items
for each row execute function public.v1_normalize_inventory_item_description();

-- Workbook import has a closed unit allowlist. Extend only that authoritative
-- list so direct RPC imports accept the exact same controlled options as the
-- Material Request and Warehouse forms.
do $controlled_inventory_units$
declare
  v_definition text;
  v_old text := $old$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box'$old$;
  v_new text := $new$'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box', 'ton', 'boxes'$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_inventory(jsonb,uuid)'::regprocedure
  );
  if position(v_new in v_definition) > 0 then
    return;
  end if;
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_INVENTORY_IMPORT_UNIT_ALLOWLIST_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$controlled_inventory_units$;
