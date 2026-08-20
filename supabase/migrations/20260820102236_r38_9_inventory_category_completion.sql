-- Yorks R38.9 category completion for the approved inventory workbooks.
--
-- Data preservation and rollback:
-- * existing category, item, movement and import identifiers are untouched;
-- * the supplied R38.9 canonical category set is added with deterministic IDs;
-- * workbook-only legacy labels become exact aliases, never fuzzy authority;
-- * rollback may deactivate these additions after confirming that no item or
--   import evidence references them; referenced rows must never be deleted.

-- Some production databases contain a user-created canonical category whose
-- normalized name already matches a newly approved Yorks category (for
-- example, "AC Units"). Keep that stable identity; replacing it would break
-- existing item and movement history. The seed therefore resolves parents and
-- aliases by controlled normalized names rather than assuming every database
-- owns the deterministic system UUID.
with category_seed (
  id, name, normalized_name, parent_normalized_name
) as (
  values
    ('41000000-0000-4000-8000-000000000013'::uuid, 'AC Units', 'acunits', null::text),
    ('41000000-0000-4000-8000-000000000014'::uuid, 'AC Unit Parts', 'acunitparts', null::text),
    ('41000000-0000-4000-8000-000000000015'::uuid, 'Access Doors', 'accessdoors', 'ductworkaccessories'),
    ('41000000-0000-4000-8000-000000000016'::uuid, 'Fasteners & Fixings', 'fastenersfixings', 'supportsinsulation'),
    ('41000000-0000-4000-8000-000000000017'::uuid, 'Filters', 'filters', null::text),
    ('41000000-0000-4000-8000-000000000018'::uuid, 'Refrigerants & Chemicals', 'refrigerantschemicals', null::text),
    ('41000000-0000-4000-8000-000000000019'::uuid, 'Tools & Consumables', 'toolsconsumables', null::text),
    ('41000000-0000-4000-8000-000000000020'::uuid, 'General Items', 'generalitems', null::text),
    ('41000000-0000-4000-8000-000000000021'::uuid, 'Pipe Fittings', 'pipefittings', 'pipingdrain'),
    ('41000000-0000-4000-8000-000000000022'::uuid, 'Pipes & Tubes', 'pipestubes', 'pipingdrain'),
    ('41000000-0000-4000-8000-000000000023'::uuid, 'Valves & Strainers', 'valvesstrainers', 'pipingdrain')
)
insert into public.v1_inventory_categories (
  id, name, normalized_name, parent_category_id, is_system,
  created_by_auth_user_id
)
select
  seed.id,
  seed.name,
  seed.normalized_name,
  parent.id,
  true,
  null
from category_seed seed
left join public.v1_inventory_categories parent
  on parent.normalized_name = seed.parent_normalized_name
where seed.parent_normalized_name is null or parent.id is not null
on conflict (normalized_name) do nothing;

with alias_seed (category_normalized_name, alias_name, normalized_alias) as (
  values
    ('acunits', 'AC Unit', 'acunit'),
    ('accessdoors', 'Acces Door', 'accesdoor'),
    ('airterminals', 'Air Inlet & Outlet', 'airinletoutlet'),
    ('airterminalsred', 'Air Terminals - Red', 'airterminalsred'),
    ('airterminalsround', 'Air Terminals - Round', 'airterminalsround'),
    ('ductworkaccessories', 'Ducting Materials', 'ductingmaterials'),
    ('electricalcontrols', 'Electrical & Cable Management', 'electricalcablemanagement'),
    ('fansequipment', 'Fans & Ventilation', 'fansventilation'),
    ('toolsconsumables', 'Tools & Equipment', 'toolsequipment')
)
insert into public.v1_inventory_category_aliases (
  category_id, alias_name, normalized_alias, created_by_auth_user_id
)
select category.id, seed.alias_name, seed.normalized_alias, null
from alias_seed seed
join public.v1_inventory_categories category
  on category.normalized_name = seed.category_normalized_name
on conflict (normalized_alias) do nothing;
