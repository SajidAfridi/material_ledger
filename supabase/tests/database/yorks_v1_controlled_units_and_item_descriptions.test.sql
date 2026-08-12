begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select is(
  (select data ->> 'name' from public."materialUnits" where id = 'unit-ton'),
  'Ton',
  'Ton is an approved controlled unit'
);

select is(
  (select data ->> 'name' from public."materialUnits" where id = 'unit-boxes'),
  'Boxes',
  'Boxes is an approved controlled unit'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_create_inventory_item(
    jsonb_build_object(
      'item_code', 'UNIT-TON-001',
      'item_description', 'ton of sealant',
      'category_id', '41000000-0000-4000-8000-000000000012',
      'new_category_name', null,
      'new_category_parent_id', null,
      'source_category_text', 'General & Custom',
      'brand_origin', null,
      'size_text', null,
      'model_reference', null,
      'unit', 'Ton',
      'minimum_stock', null,
      'location_bin', 'U-01',
      'notes', null,
      'opening_quantity', '0',
      'opening_reference', null,
      'reason', null
    ), '92000000-0000-4000-8000-000000000101'
  )$$,
  'Procurement can create an inventory item measured in Ton'
);

set local role postgres;
select is(
  (select item_description from public.v1_inventory_items where item_code = 'UNIT-TON-001'),
  'Ton of sealant',
  'The inventory write boundary capitalizes the first entered character'
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
      'file_name', 'controlled-units.xlsx',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'inventory_item_id', null,
        'item_code', 'UNIT-BOX-001',
        'item_description', 'box of fittings',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'new_category_name', null,
        'source_category_text', 'General & Custom',
        'brand_origin', null,
        'unit', 'Boxes',
        'stock_action', 'opening_balance',
        'quantity', '1',
        'reason', 'Verified opening balance',
        'minimum_stock', null,
        'location_bin', 'U-02',
        'notes', null
      ))
    ), '92000000-0000-4000-8000-000000000102'
  )$$,
  'Workbook import accepts Boxes from the controlled allowlist'
);

set local role postgres;
select is(
  (select unit from public.v1_inventory_items where item_code = 'UNIT-BOX-001'),
  'Boxes',
  'Workbook import preserves the Boxes unit exactly'
);

select is(
  (select item_description from public.v1_inventory_items where item_code = 'UNIT-BOX-001'),
  'Box of fittings',
  'Workbook-created inventory items use the same first-character normalization'
);

select * from finish();
rollback;
