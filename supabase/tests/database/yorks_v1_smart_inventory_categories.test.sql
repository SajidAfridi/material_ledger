begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(32);

select ok(
  (select bool_and(relrowsecurity) from pg_class
   where oid in (
     'public.v1_inventory_categories'::regclass,
     'public.v1_inventory_category_aliases'::regclass,
     'public.v1_inventory_import_batches'::regclass,
     'public.v1_inventory_import_rows'::regclass
   )),
  'Smart inventory category and import relations enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_inventory_categories', 'select')
  and not has_table_privilege('authenticated', 'public.v1_inventory_categories', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_inventory_import_rows', 'insert')
  and has_function_privilege('authenticated', 'public.v1_import_inventory(jsonb,uuid)', 'execute'),
  'Authenticated users reach inventory only through trusted projections and commands'
);

select is(
  (select count(*)::integer from public.v1_inventory_categories where is_system),
  24,
  'The approved Yorks inventory categories are seeded exactly once'
);

select ok(
  (
    select count(*) = 10
    from public.v1_inventory_categories
    where is_system and name in (
      'Air Inlet & Outlet', 'AC Unit Parts', 'Dampers & Fire Control',
      'Electrical & Controls', 'Fans & Ventilation', 'Ducting Materials',
      'Piping & Drain', 'Supports & Insulation', 'Tools & Equipment',
      'General Items'
    )
  ),
  'The Yorks controlled category vocabulary is pre-seeded'
);

select ok(
  (
    with source_labels(label) as (
      values
        ('AC Unit'), ('AC Unit Parts'), ('Access Doors'),
        ('Air Inlet & Outlet'), ('Dampers & Fire Control'),
        ('Ducting Materials'), ('Electrical & Cable Management'),
        ('Electrical & Controls'), ('Fans & Ventilation'),
        ('Fasteners & Fixings'), ('Filters'), ('Pipe Fittings'),
        ('Pipes & Tubes'), ('Refrigerants & Chemicals'),
        ('Supports & Insulation'), ('Tools & Equipment'),
        ('Valves & Strainers')
    ), resolutions as (
      select source.label, count(distinct candidate.category_id) match_count
      from source_labels source
      left join lateral (
        select category.id category_id
        from public.v1_inventory_categories category
        where category.is_active
          and category.normalized_name =
            public.v1_inventory_category_key(source.label)
        union all
        select alias.category_id
        from public.v1_inventory_category_aliases alias
        join public.v1_inventory_categories category
          on category.id = alias.category_id and category.is_active
        where alias.normalized_alias =
          public.v1_inventory_category_key(source.label)
      ) candidate on true
      group by source.label
    )
    select bool_and(match_count = 1) from resolutions
  ),
  'Every category label in the supplied PERFECT workbook resolves exactly once'
);

select ok(
  exists(
    select 1 from public.v1_inventory_categories
    where name = 'Access Doors'
      and parent_category_id =
        '41000000-0000-4000-8000-000000000008'
  )
  and exists(
    select 1 from public.v1_inventory_categories
    where name = 'Pipe Fittings'
      and parent_category_id =
        '41000000-0000-4000-8000-000000000009'
  ),
  'New workbook categories retain the approved one-level catalogue hierarchy'
);

select ok(
  exists(select 1 from public.v1_inventory_categories where name = 'SED'
    and parent_category_id = '41000000-0000-4000-8000-000000000001')
  and exists(select 1 from public.v1_inventory_categories where name = 'RED'
    and parent_category_id = '41000000-0000-4000-8000-000000000001')
  and not exists(select 1 from public.v1_inventory_categories where name like '%Smoke Extract%'),
  'SED and RED remain approved acronyms and are never expanded by inference'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Project Engineer cannot read the organization warehouse workspace'
);
select throws_ok(
  $$select public.v1_import_inventory('{"file_name":"forged.xlsx","rows":[]}'::jsonb, '91000000-0000-4000-8000-000000000001')$$,
  '42501', 'V1_INVENTORY_IMPORT_DENIED',
  'Project Engineer cannot import warehouse stock'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_create_inventory_category('{"name":"Forbidden"}'::jsonb, '91000000-0000-4000-8000-000000000002')$$,
  '42501', 'V1_INVENTORY_CATEGORY_CREATE_DENIED',
  'Site Engineer cannot create warehouse categories'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  'Senior Mechanical Engineer can read the warehouse workspace'
);
select throws_ok(
  $$select public.v1_create_inventory_category('{"name":"Forbidden SME write"}'::jsonb, '91000000-0000-4000-8000-000000000009')$$,
  '42501', 'V1_INVENTORY_CATEGORY_CREATE_DENIED',
  'Senior Mechanical Engineer read access does not grant inventory mutation'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Project Manager global project authority does not grant stock authority'
);

set local role postgres;
create temporary table v1_r383_payload as
select jsonb_build_object(
  'file_name', 'R38.3 Warehouse Review.xlsx',
  'rows', jsonb_build_array(
    jsonb_build_object(
      'source_row_number', 8,
      'inventory_item_id', null,
      'item_code', 'WH-GI-001',
      'item_description', 'GI duct sheet 24 gauge',
      'category_id', '41000000-0000-4000-8000-000000000008',
      'new_category_name', null,
      'source_category_text', 'Duct Accessories',
      'brand_origin', 'UAE',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '12',
      'reason', 'Verified opening balance',
      'minimum_stock', '4',
      'location_bin', 'A-01',
      'notes', 'R38.3 controlled import'
    ),
    jsonb_build_object(
      'source_row_number', 9,
      'inventory_item_id', null,
      'item_code', 'WH-AT-001',
      'item_description', 'Round air diffuser 300 mm',
      'category_id', '41000000-0000-4000-8000-000000000002',
      'new_category_name', null,
      'source_category_text', 'Round AC Terminal',
      'brand_origin', 'Yorks',
      'unit', 'Nos',
      'stock_action', 'add_stock',
      'quantity', '5',
      'reason', 'Goods received and checked',
      'minimum_stock', '2',
      'location_bin', 'B-03',
      'notes', null
    ),
    jsonb_build_object(
      'source_row_number', 10,
      'inventory_item_id', null,
      'item_code', 'WH-CP-001',
      'item_description', 'Custom access panel',
      'category_id', null,
      'new_category_name', 'custom panels',
      'source_category_text', 'Custom panels',
      'brand_origin', null,
      'unit', 'Nos',
      'stock_action', 'no_stock_change',
      'quantity', '0',
      'reason', 'Master data only',
      'minimum_stock', '0',
      'location_bin', 'C-01',
      'notes', null
    )
  )
) as payload;
grant select on table v1_r383_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  'Procurement reads the role-safe smart warehouse projection'
);

select lives_ok(
  $$select public.v1_create_inventory_category(
    '{"name":"Test Equipment"}'::jsonb,
    '91000000-0000-4000-8000-000000000010'
  )$$,
  'Procurement can explicitly create a reusable warehouse category'
);

select lives_ok(
  $$select public.v1_create_inventory_category(
    '{"name":"Test Equipment"}'::jsonb,
    '91000000-0000-4000-8000-000000000010'
  )$$,
  'Category creation returns the original result on an exact retry'
);

select lives_ok(
  $$select public.v1_import_inventory(
    (select payload from v1_r383_payload),
    '91000000-0000-4000-8000-000000000020'
  )$$,
  'Procurement atomically imports the reviewed workbook rows'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items
   where item_code in ('WH-GI-001', 'WH-AT-001', 'WH-CP-001')),
  3,
  'The import creates each reviewed item exactly once'
);

select is(
  (select count(*)::integer from public.v1_inventory_movements movement
   join public.v1_inventory_items item on item.id = movement.inventory_item_id
   where item.item_code in ('WH-GI-001', 'WH-AT-001', 'WH-CP-001')),
  2,
  'Only stock-changing rows append movements; No Stock Change does not fabricate one'
);

select ok(
  exists(
    select 1 from public.v1_inventory_category_aliases alias
    where alias.normalized_alias = 'roundacterminal'
      and alias.category_id = '41000000-0000-4000-8000-000000000002'
  ),
  'Accepted source wording is retained against the confirmed reusable category'
);

select ok(
  exists(select 1 from public.v1_inventory_categories where name = 'Custom Panels' and not is_system)
  and exists(select 1 from public.v1_inventory_items where item_code = 'WH-CP-001' and category_id = (select id from public.v1_inventory_categories where name = 'Custom Panels')),
  'An explicitly confirmed new category is normalized once and assigned to its item'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_import_inventory(
    (select payload from v1_r383_payload),
    '91000000-0000-4000-8000-000000000020'
  )$$,
  'An import retry returns the first committed response'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_import_batches
   where idempotency_key = '91000000-0000-4000-8000-000000000020'),
  1,
  'The import retry cannot duplicate its batch'
);

select is(
  (select on_hand_qty from public.v1_inventory_balances balance
   join public.v1_inventory_items item on item.id = balance.inventory_item_id
   where item.item_code = 'WH-GI-001'),
  12::numeric,
  'The import retry cannot duplicate stock quantity'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_import_inventory(
    jsonb_set((select payload from v1_r383_payload), '{file_name}', '"changed.xlsx"'),
    '91000000-0000-4000-8000-000000000020'
  )$$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same import command key rejects a different payload'
);

select throws_ok(
  $$select public.v1_adjust_inventory(
    jsonb_build_object(
      'inventory_item_id', (
        public.v1_inventory_workspace_projection('WH-GI-001')
          -> 'items' -> 0 ->> 'id'
      ),
      'item_code', null, 'item_description', null, 'category_id', null,
      'new_category_name', null, 'source_category_text', null,
      'brand_origin', null, 'unit', null, 'minimum_stock', null,
      'location_bin', null, 'notes', null,
      'quantity_delta', '-13', 'reason', 'Invalid over-removal'
    ), '91000000-0000-4000-8000-000000000030'
  )$$,
  '22023', 'V1_INVENTORY_ADJUSTMENT_BELOW_RESERVED',
  'A manual removal cannot make available stock negative'
);

select throws_ok(
  $$select public.v1_import_inventory(
    jsonb_build_object(
      'file_name', 'atomic-failure.xlsx',
      'rows', jsonb_build_array(
        jsonb_build_object(
          'source_row_number', 2, 'inventory_item_id', null,
          'item_code', 'WH-ATOMIC-001', 'item_description', 'Atomic valid row',
          'category_id', '41000000-0000-4000-8000-000000000012',
          'new_category_name', null, 'source_category_text', 'General',
          'brand_origin', null, 'unit', 'Nos', 'stock_action', 'add_stock',
          'quantity', '1', 'reason', 'Must roll back', 'minimum_stock', null,
          'location_bin', null, 'notes', null
        ),
        jsonb_build_object(
          'source_row_number', 3, 'inventory_item_id', null,
          'item_code', 'WH-ATOMIC-002', 'item_description', '',
          'category_id', '41000000-0000-4000-8000-000000000012',
          'new_category_name', null, 'source_category_text', 'General',
          'brand_origin', null, 'unit', 'Nos', 'stock_action', 'add_stock',
          'quantity', '1', 'reason', 'Invalid row', 'minimum_stock', null,
          'location_bin', null, 'notes', null
        )
      )
    ), '91000000-0000-4000-8000-000000000040'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_ROW_INVALID:3',
  'A later invalid import row aborts the entire workbook transaction'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items where item_code like 'WH-ATOMIC-%'),
  0,
  'The failed workbook leaves no partially-created inventory item'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$insert into public.v1_inventory_categories(
    name, normalized_name, created_by_auth_user_id
  ) values ('Bypass', 'bypass', auth.uid())$$,
  '42501', null,
  'Procurement cannot bypass category commands with direct table writes'
);

select is(
  (public.v1_inventory_workspace_projection('WH-GI-001') -> 'summary' ->> 'low_stock_count')::integer,
  0,
  'A stocked item above its real minimum is not falsely marked low stock'
);

select is(
  (public.v1_inventory_workspace_projection(null) -> 'summary' ->> 'incoming_count')::integer,
  0,
  'Deferred purchase-order incoming stock remains honestly zero'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_inventory_workspace_projection('WH-AT-001')$$,
  'Admin retains audited warehouse workspace authority'
);

select * from finish();
rollback;
