begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

select is(
  (
    select count(*)::integer
    from public.v1_inventory_categories
    where is_active and name in (
      'AC Unit', 'AC Unit Parts', 'Access Doors', 'Air Inlet & Outlet',
      'Dampers & Fire Control', 'Ducting Materials',
      'Electrical & Cable Management', 'Electrical & Controls',
      'Fans & Ventilation', 'Fasteners & Fixings', 'Filters',
      'Pipe Fittings', 'Pipes & Tubes', 'Refrigerants & Chemicals',
      'Supports & Insulation', 'Tools & Equipment', 'Valves & Strainers'
    )
  ),
  17,
  'Every approved category is active in the Supabase inventory catalogue'
);

select is(
  (
    select count(*)::integer
    from public.v1_configuration_units
    where is_active and lower(short_code) in (
      'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
      'each', 'ton', 'boxes', 'kg', 'litre', 'pack', 'lot', 'mtr',
      'cartridge', 'coil', 'cylinder', 'drum', 'sheet', 'tin'
    )
  ),
  22,
  'Every controlled template unit is active in Supabase configuration'
);

select ok(
  position(
    'correction_increase'
    in pg_get_functiondef('public.v1_import_inventory(jsonb,uuid)'::regprocedure)
  ) > 0
  and position(
    'correction_decrease'
    in pg_get_functiondef('public.v1_import_inventory(jsonb,uuid)'::regprocedure)
  ) > 0,
  'The trusted stock import command recognizes both correction actions'
);

select ok(
  position(
    '''cartridge'', ''coil'', ''cylinder'', ''drum'', ''sheet'', ''tin'''
    in pg_get_functiondef('public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure)
  ) > 0,
  'The receipt-provenance import command shares the expanded controlled units'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_import_inventory(
    jsonb_build_object(
      'file_name', 'r38_10-opening.xlsx',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'inventory_item_id', null,
        'item_code', 'R3810-CARTRIDGE-001',
        'item_description', 'Verified refrigerant cartridge',
        'category_id', '41000000-0000-4000-8000-000000000013',
        'new_category_name', null,
        'source_category_text', 'AC Unit',
        'brand_origin', null,
        'unit', 'Cartridge',
        'stock_action', 'opening_balance',
        'quantity', '3',
        'reason', 'Inventory import: Opening Balance',
        'minimum_stock', null,
        'location_bin', null,
        'notes', null
      ))
    ),
    '38100000-0000-4000-8000-000000000101'
  )$$,
  'Procurement can import a controlled Opening Balance row using Cartridge'
);

select lives_ok(
  $$select public.v1_import_inventory(
    jsonb_build_object(
      'file_name', 'r38_10-correction-increase.xlsx',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'inventory_item_id', null,
        'item_code', 'R3810-CARTRIDGE-001',
        'item_description', 'Verified refrigerant cartridge',
        'category_id', null,
        'new_category_name', null,
        'source_category_text', 'AC Unit',
        'brand_origin', null,
        'unit', 'Cartridge',
        'stock_action', 'correction_increase',
        'quantity', '2',
        'reason', 'Counted excess in bin A-01',
        'minimum_stock', null,
        'location_bin', null,
        'notes', 'Counted excess in bin A-01'
      ))
    ),
    '38100000-0000-4000-8000-000000000102'
  )$$,
  'A correction increase is an authorized audited stock action'
);

select lives_ok(
  $$select public.v1_import_inventory(
    jsonb_build_object(
      'file_name', 'r38_10-correction-decrease.xlsx',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'inventory_item_id', null,
        'item_code', 'R3810-CARTRIDGE-001',
        'item_description', 'Verified refrigerant cartridge',
        'category_id', null,
        'new_category_name', null,
        'source_category_text', 'AC Unit',
        'brand_origin', null,
        'unit', 'Cartridge',
        'stock_action', 'correction_decrease',
        'quantity', '1',
        'reason', 'Damaged during count',
        'minimum_stock', null,
        'location_bin', null,
        'notes', 'Damaged during count'
      ))
    ),
    '38100000-0000-4000-8000-000000000103'
  )$$,
  'A correction decrease uses the trusted reservation-safe stock command'
);

select lives_ok(
  $$select public.v1_import_inventory(
    jsonb_build_object(
      'file_name', 'r38_10-no-stock-change.xlsx',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'inventory_item_id', null,
        'item_code', 'R3810-CARTRIDGE-001',
        'item_description', 'Verified refrigerant cartridge',
        'category_id', null,
        'new_category_name', null,
        'source_category_text', 'AC Unit',
        'brand_origin', null,
        'unit', 'Cartridge',
        'stock_action', 'no_stock_change',
        'quantity', '0',
        'reason', 'Inventory import: No Stock Change',
        'minimum_stock', null,
        'location_bin', null,
        'notes', null
      ))
    ),
    '38100000-0000-4000-8000-000000000104'
  )$$,
  'No Stock Change preserves metadata without a stock movement'
);

set local role postgres;
select is(
  (
    select on_hand_qty
    from public.v1_inventory_balances balance
    join public.v1_inventory_items item on item.id = balance.inventory_item_id
    where item.item_code = 'R3810-CARTRIDGE-001'
  ),
  4::numeric,
  'Opening Balance plus correction increase and decrease produce the exact balance'
);

select is(
  (
    select count(*)::integer
    from public.v1_inventory_movements movement
    join public.v1_inventory_items item on item.id = movement.inventory_item_id
    where item.item_code = 'R3810-CARTRIDGE-001'
  ),
  3,
  'No Stock Change does not fabricate an inventory movement'
);

select * from finish();
rollback;
