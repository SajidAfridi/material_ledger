-- Yorks R38.9 category completion for the approved inventory workbooks.
--
-- Data preservation and rollback:
-- * existing category, item, movement and import identifiers are untouched;
-- * the supplied R38.9 canonical category set is added with deterministic IDs;
-- * workbook-only legacy labels become exact aliases, never fuzzy authority;
-- * rollback may deactivate these additions after confirming that no item or
--   import evidence references them; referenced rows must never be deleted.

insert into public.v1_inventory_categories (
  id, name, normalized_name, parent_category_id, is_system,
  created_by_auth_user_id
)
values
  (
    '41000000-0000-4000-8000-000000000013',
    'AC Units', 'acunits', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000014',
    'AC Unit Parts', 'acunitparts', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000015',
    'Access Doors', 'accessdoors',
    '41000000-0000-4000-8000-000000000008', true, null
  ),
  (
    '41000000-0000-4000-8000-000000000016',
    'Fasteners & Fixings', 'fastenersfixings',
    '41000000-0000-4000-8000-000000000011', true, null
  ),
  (
    '41000000-0000-4000-8000-000000000017',
    'Filters', 'filters', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000018',
    'Refrigerants & Chemicals', 'refrigerantschemicals', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000019',
    'Tools & Consumables', 'toolsconsumables', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000020',
    'General Items', 'generalitems', null, true, null
  ),
  (
    '41000000-0000-4000-8000-000000000021',
    'Pipe Fittings', 'pipefittings',
    '41000000-0000-4000-8000-000000000009', true, null
  ),
  (
    '41000000-0000-4000-8000-000000000022',
    'Pipes & Tubes', 'pipestubes',
    '41000000-0000-4000-8000-000000000009', true, null
  ),
  (
    '41000000-0000-4000-8000-000000000023',
    'Valves & Strainers', 'valvesstrainers',
    '41000000-0000-4000-8000-000000000009', true, null
  )
on conflict (normalized_name) do nothing;

insert into public.v1_inventory_category_aliases (
  category_id, alias_name, normalized_alias, created_by_auth_user_id
)
values
  (
    '41000000-0000-4000-8000-000000000013',
    'AC Unit', 'acunit', null
  ),
  (
    '41000000-0000-4000-8000-000000000015',
    'Acces Door', 'accesdoor', null
  ),
  (
    '41000000-0000-4000-8000-000000000001',
    'Air Inlet & Outlet', 'airinletoutlet', null
  ),
  (
    '41000000-0000-4000-8000-000000000005',
    'Air Terminals - Red', 'airterminalsred', null
  ),
  (
    '41000000-0000-4000-8000-000000000002',
    'Air Terminals - Round', 'airterminalsround', null
  ),
  (
    '41000000-0000-4000-8000-000000000008',
    'Ducting Materials', 'ductingmaterials', null
  ),
  (
    '41000000-0000-4000-8000-000000000010',
    'Electrical & Cable Management', 'electricalcablemanagement', null
  ),
  (
    '41000000-0000-4000-8000-000000000007',
    'Fans & Ventilation', 'fansventilation', null
  ),
  (
    '41000000-0000-4000-8000-000000000019',
    'Tools & Equipment', 'toolsequipment', null
  )
on conflict (normalized_alias) do nothing;
