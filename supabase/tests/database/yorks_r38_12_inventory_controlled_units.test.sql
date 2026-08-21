begin;

select plan(5);

set local role postgres;

select ok(
  position(
    'from public.v1_configuration_units controlled_unit'
    in pg_get_functiondef(
      'public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure
    )
  ) > 0,
  'R38.9 import validates units against the controlled configuration master'
);

create temporary table v1_r3812_import_payload as
select jsonb_build_object(
  'file_name', 'R38.12 controlled workbook units.xlsx',
  'file_sha256', repeat('2', 64),
  'import_mode', 'strict',
  'opening_balance_as_of_date', '2099-12-29',
  'rows', jsonb_agg(
    jsonb_build_object(
      'source_row_number', source_row_number,
      'item_code', 'R3812-UNIT-' || lpad(source_row_number::text, 2, '0'),
      'item_description', 'Controlled unit ' || unit_code,
      'category_id', '41000000-0000-4000-8000-000000000014',
      'source_category_text', 'AC Unit Parts',
      'unit', unit_code,
      'stock_action', 'opening_balance',
      'quantity', '1',
      'delivered_quantity', '1',
      'reason', 'Controlled unit regression',
      'source_type', 'opening_balance',
      'supplier_id', '00000000-0000-4000-8000-000000000389',
      'accepted_quantity', '1',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'raw_source_values', jsonb_build_object('unit', unit_code)
    ) order by source_row_number
  )
) payload
from (
  values
    (1, 'Box'), (2, 'Cartridge'), (3, 'Coil'), (4, 'Cylinder'),
    (5, 'Drum'), (6, 'Kg'), (7, 'Length'), (8, 'Meter'),
    (9, 'Nos'), (10, 'Pack'), (11, 'Roll'), (12, 'Set'),
    (13, 'Sheet'), (14, 'Tin')
) as workbook_units(source_row_number, unit_code);
grant select on v1_r3812_import_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r3812_import_payload),
    '98000000-0000-4000-8000-000000009812'
  )$$,
  'All units used by the approved 1,155-row workbook import successfully'
);

select is(
  (public.v1_import_inventory_r38_9(
    (select payload from v1_r3812_import_payload),
    '98000000-0000-4000-8000-000000009812'
  ) ->> 'row_count')::integer,
  14,
  'Retry is idempotent and returns the authoritative fourteen-row result'
);

set local role postgres;

select is(
  (select count(*)::integer
   from public.v1_inventory_items
   where item_code like 'R3812-UNIT-%'),
  14,
  'Every workbook unit retains its own inventory item'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-unit.xlsx',
      'file_sha256', repeat('3', 64),
      'import_mode', 'strict',
      'opening_balance_as_of_date', '2099-12-28',
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 1,
        'item_code', 'R3812-UNSUPPORTED',
        'item_description', 'Unsupported unit',
        'category_id', '41000000-0000-4000-8000-000000000014',
        'unit', 'Pallet',
        'stock_action', 'opening_balance',
        'quantity', '1',
        'delivered_quantity', '1',
        'reason', 'Must fail closed',
        'source_type', 'opening_balance',
        'supplier_id', '00000000-0000-4000-8000-000000000389',
        'accepted_quantity', '1',
        'damaged_quantity', '0',
        'rejected_quantity', '0',
        'tracking_mode', 'bulk',
        'raw_source_values', '{}'::jsonb
      ))
    ),
    '98000000-0000-4000-8000-000000009813'
  )$$,
  '22023',
  'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:1',
  'A unit absent from the controlled master still fails closed'
);

select * from finish();
rollback;
