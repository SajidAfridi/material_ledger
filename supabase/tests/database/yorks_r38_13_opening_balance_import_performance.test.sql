begin;

select plan(5);

set local role postgres;

select ok(
  position(
    'v_cached_receipt_batch_id'
    in pg_get_functiondef('public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure)
  ) > 0
  and position(
    'if v_created_item then'
    in pg_get_functiondef('public.v1_import_inventory_r38_9(jsonb,uuid)'::regprocedure)
  ) > 0,
  'Workbook imports cache their receipt batch and skip redundant zero-balance reads'
);

create temporary table v1_r3813_import_payload as
select jsonb_build_object(
  'file_name', 'R38.13 opening balance performance.xlsx',
  'file_sha256', repeat('4', 64),
  'import_mode', 'strict',
  'opening_balance_as_of_date', '2099-12-27',
  'rows', jsonb_agg(
    jsonb_build_object(
      'source_row_number', row_number,
      'item_code', 'R3813-PERF-' || lpad(row_number::text, 4, '0'),
      'item_description', 'Performance controlled item ' || row_number,
      'category_id', '41000000-0000-4000-8000-000000000014',
      'source_category_text', 'AC Unit Parts',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '1',
      'delivered_quantity', '1',
      'reason', 'Bounded atomic import regression',
      'source_type', 'opening_balance',
      'supplier_id', '00000000-0000-4000-8000-000000000389',
      'accepted_quantity', '1',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'raw_source_values', jsonb_build_object('generated', row_number)
    ) order by row_number
  )
) payload
from generate_series(1, 1155) row_number;
grant select on v1_r3813_import_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
set local statement_timeout = '5s';

select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r3813_import_payload),
    '98000000-0000-4000-8000-000000009813'
  )$$,
  'A 1,155-row Unknown Supplier opening balance completes inside the production timeout budget'
);

set local role postgres;

select is(
  (select count(*)::integer
   from public.v1_supplier_receipt_batches
   where import_batch_id = (
     select (public.v1_import_inventory_r38_9(
       (select payload from v1_r3813_import_payload),
       '98000000-0000-4000-8000-000000009813'
     ) ->> 'import_batch_id')::uuid
   )),
  1,
  'All same-source opening-balance lines retain one authoritative receipt batch'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (public.v1_import_inventory_r38_9(
    (select payload from v1_r3813_import_payload),
    '98000000-0000-4000-8000-000000009813'
  ) ->> 'movements')::integer,
  1155,
  'Idempotent retry returns the original movement count without duplicating stock'
);

set local role postgres;

select is(
  (select count(*)::integer from public.v1_inventory_movements movement
   join public.v1_inventory_items item on item.id = movement.inventory_item_id
   where item.item_code like 'R3813-PERF-%'),
  1155,
  'The timeout-bounded import creates exactly one movement per generated row'
);

select * from finish();
rollback;
