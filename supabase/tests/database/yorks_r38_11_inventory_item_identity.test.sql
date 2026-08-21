begin;

select plan(5);

set local role postgres;
create temporary table v1_r3811_import_payload as
select jsonb_build_object(
  'file_name', 'R38.11 distinct compressor codes.xlsx',
  'file_sha256', repeat('0', 64),
  'import_mode', 'strict',
  'opening_balance_as_of_date', '2099-12-30',
  'rows', jsonb_build_array(
    jsonb_build_object(
      'source_row_number', 12,
      'item_code', 'R3811-COMP-0001',
      'item_description', 'Compressor',
      'category_id', '41000000-0000-4000-8000-000000000014',
      'source_category_text', 'AC Unit Parts',
      'brand_origin', 'Mitsubishi',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '11',
      'delivered_quantity', '11',
      'reason', 'Distinct model ANB33FDUMT',
      'source_type', 'opening_balance',
      'supplier_id', '00000000-0000-4000-8000-000000000389',
      'accepted_quantity', '11',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'unit_price', '14.6363636364',
      'total_price', '161',
      'calculated_total_price', '161',
      'imported_total_price', '161.0000000004',
      'model_tag', 'ANB33FDUMT',
      'raw_source_values', jsonb_build_object('model', 'ANB33FDUMT')
    ),
    jsonb_build_object(
      'source_row_number', 13,
      'item_code', 'R3811-COMP-0002',
      'item_description', 'Compressor',
      'category_id', '41000000-0000-4000-8000-000000000014',
      'source_category_text', 'AC Unit Parts',
      'brand_origin', 'Mitsubishi',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '1',
      'delivered_quantity', '1',
      'reason', 'Distinct model PH340G2CS-4KTS1',
      'source_type', 'opening_balance',
      'supplier_id', '00000000-0000-4000-8000-000000000389',
      'accepted_quantity', '1',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'model_tag', 'PH340G2CS-4KTS1',
      'raw_source_values', jsonb_build_object('model', 'PH340G2CS-4KTS1')
    ),
    jsonb_build_object(
      'source_row_number', 14,
      'item_code', 'R3811-COMP-0002',
      'item_description', 'Compressor',
      'category_id', '41000000-0000-4000-8000-000000000014',
      'source_category_text', 'AC Unit Parts',
      'brand_origin', 'Mitsubishi',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '1',
      'delivered_quantity', '1',
      'reason', 'Second serialized unit of the same catalogue item',
      'source_type', 'opening_balance',
      'supplier_id', '00000000-0000-4000-8000-000000000389',
      'accepted_quantity', '1',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'serialized',
      'serial_number', 'R3811-SERIAL-0002',
      'model_tag', 'PH340G2CS-4KTS1',
      'raw_source_values', jsonb_build_object('model', 'PH340G2CS-4KTS1')
    )
  )
) payload;
grant select on v1_r3811_import_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r3811_import_payload),
    '98000000-0000-4000-8000-000000009811'
  )$$,
  'Explicitly coded items with the same description, brand and unit import independently'
);

set local role postgres;

select is(
  (select count(*)::integer from public.v1_inventory_items
    where item_code in ('R3811-COMP-0001', 'R3811-COMP-0002')),
  2,
  'Both explicit item codes create durable catalogue identities'
);

select isnt(
  (select id from public.v1_inventory_items where item_code = 'R3811-COMP-0001'),
  (select id from public.v1_inventory_items where item_code = 'R3811-COMP-0002'),
  'Distinct explicit codes never collapse into one item ID'
);

select is(
  (select count(*)::integer
    from public.v1_inventory_import_rows import_row
    join public.v1_inventory_items item
      on item.id = import_row.inventory_item_id
    where item.item_code = 'R3811-COMP-0002'),
  2,
  'Multiple serialized rows for one explicit item remain separate evidence'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (public.v1_import_inventory_r38_9(
    (select payload from v1_r3811_import_payload),
    '98000000-0000-4000-8000-000000009811'
  ) ->> 'row_count')::integer,
  3,
  'The idempotent retry returns the authoritative three-row result'
);

select * from finish();
rollback;
