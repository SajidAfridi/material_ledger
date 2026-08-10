begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(16);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_update_inventory_item(jsonb,uuid)', 'execute'
  ),
  'Authenticated clients can reach the versioned item metadata boundary'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_update_inventory_item(
    '{"inventory_item_id":"10000000-0000-4000-8000-000000000099","expected_metadata_version":1,"item_description":"Forged edit","category_id":"41000000-0000-4000-8000-000000000001","unit":"Nos"}'::jsonb,
    '93000000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_INVENTORY_ITEM_UPDATE_DENIED',
  'Project Engineer cannot edit the warehouse item master through the RPC'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_update_inventory_item(
    '{"inventory_item_id":"10000000-0000-4000-8000-000000000099","expected_metadata_version":1,"item_description":"Forged edit","category_id":"41000000-0000-4000-8000-000000000001","unit":"Nos"}'::jsonb,
    '93000000-0000-4000-8000-000000000002'
  )$$,
  '42501', 'V1_INVENTORY_ITEM_UPDATE_DENIED',
  'Site Engineer cannot edit the warehouse item master through the RPC'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_create_inventory_item(
    '{"item_code":"R383-EDIT-1","item_description":"Metadata edit test item","category_id":"41000000-0000-4000-8000-000000000001","new_category_name":null,"new_category_parent_id":null,"source_category_text":null,"brand_origin":"Yorks / UAE","size_text":"25 mm","model_reference":"META-25","unit":"Roll","minimum_stock":"2","location_bin":"G-02","notes":"Before edit","opening_quantity":"5","opening_reference":"OPEN-EDIT-1","reason":"Verified opening balance"}'::jsonb,
    '93000000-0000-4000-8000-000000000010'
  )$$,
  'Procurement creates the target inventory item through the controlled create command'
);

set local role postgres;
create temporary table v1_r383_edit_target as
select id as inventory_item_id
from public.v1_inventory_items
where item_code = 'R383-EDIT-1';
grant select on table v1_r383_edit_target to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_update_inventory_item(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_r383_edit_target),
      'expected_metadata_version', 1,
      'item_code', 'R383-EDIT-2',
      'item_description', 'Metadata edit test item revised',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'new_category_name', null,
      'new_category_parent_id', null,
      'source_category_text', null,
      'brand_origin', 'Yorks / UAE',
      'size_text', '30 mm',
      'model_reference', 'META-30',
      'unit', 'Roll',
      'minimum_stock', '3',
      'location_bin', 'G-03',
      'notes', 'After edit'
    ),
    '93000000-0000-4000-8000-000000000011'
  )$$,
  'Procurement updates descriptive item metadata through a versioned command'
);

set local role postgres;
select is(
  (select on_hand_qty from public.v1_inventory_balances
   where inventory_item_id = (select inventory_item_id from v1_r383_edit_target)),
  5::numeric,
  'A metadata edit cannot overwrite on-hand quantity'
);
select is(
  (select count(*)::integer from public.v1_inventory_movements
   where inventory_item_id = (select inventory_item_id from v1_r383_edit_target)),
  1,
  'A metadata edit cannot append, rewrite or remove stock movements'
);
select ok(
  exists(
    select 1 from public.v1_inventory_items
    where id = (select inventory_item_id from v1_r383_edit_target)
      and item_code = 'R383-EDIT-2'
      and item_description = 'Metadata edit test item revised'
      and size_text = '30 mm'
      and model_reference = 'META-30'
      and location_bin = 'G-03'
      and minimum_stock = 3
      and metadata_record_version = 2
  ),
  'The confirmed metadata projection advances only the metadata version'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_update_inventory_item(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_r383_edit_target),
      'expected_metadata_version', 1,
      'item_code', 'R383-EDIT-2',
      'item_description', 'Metadata edit test item revised',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'new_category_name', null,
      'new_category_parent_id', null,
      'source_category_text', null,
      'brand_origin', 'Yorks / UAE',
      'size_text', '30 mm',
      'model_reference', 'META-30',
      'unit', 'Roll',
      'minimum_stock', '3',
      'location_bin', 'G-03',
      'notes', 'After edit'
    ),
    '93000000-0000-4000-8000-000000000011'
  )$$,
  'A lost-response retry returns the committed metadata projection'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_audit_events
   where entity_type = 'inventory_item'
     and entity_id = (select inventory_item_id from v1_r383_edit_target)
     and event_type = 'inventory_item_metadata_updated'),
  1,
  'A retry cannot duplicate the metadata audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_update_inventory_item(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_r383_edit_target),
      'expected_metadata_version', 1,
      'item_code', 'R383-STALE',
      'item_description', 'Stale metadata edit',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'unit', 'Roll'
    ),
    '93000000-0000-4000-8000-000000000012'
  )$$,
  '40001', 'V1_INVENTORY_ITEM_METADATA_CONFLICT',
  'A stale metadata edit is rejected rather than silently overwriting a newer record'
);

set local role postgres;
select is(
  (select item_code from public.v1_inventory_items
   where id = (select inventory_item_id from v1_r383_edit_target)),
  'R383-EDIT-2',
  'The rejected stale edit leaves the committed metadata intact'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$update public.v1_inventory_items
    set notes = 'Bypass metadata command'
    where item_code = 'R383-EDIT-2'$$,
  '42501', null,
  'Procurement cannot bypass the metadata command with a direct table write'
);
select throws_ok(
  $$select public.v1_update_inventory_item(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_r383_edit_target),
      'expected_metadata_version', 2,
      'item_description', 'Forged field',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'unit', 'Roll',
      'quantity', '999'
    ),
    '93000000-0000-4000-8000-000000000013'
  )$$,
  '22023', 'V1_UNKNOWN_UPDATE_INVENTORY_ITEM_FIELDS: quantity',
  'The metadata command rejects a forged quantity field'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_update_inventory_item(
    jsonb_build_object(
      'inventory_item_id', (select inventory_item_id from v1_r383_edit_target),
      'expected_metadata_version', 2,
      'item_code', 'R383-EDIT-2',
      'item_description', 'Metadata edit test item approved',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'new_category_name', null,
      'new_category_parent_id', null,
      'source_category_text', null,
      'brand_origin', 'Yorks / UAE',
      'size_text', '30 mm',
      'model_reference', 'META-30',
      'unit', 'Roll',
      'minimum_stock', '3',
      'location_bin', 'G-03',
      'notes', 'Admin correction'
    ),
    '93000000-0000-4000-8000-000000000014'
  )$$,
  'Admin receives the same auditable metadata-only item command'
);

set local role postgres;
select is(
  (select metadata_record_version from public.v1_inventory_items
   where id = (select inventory_item_id from v1_r383_edit_target)),
  3,
  'The Admin edit also advances metadata version without changing stock version'
);

select * from finish();
rollback;
