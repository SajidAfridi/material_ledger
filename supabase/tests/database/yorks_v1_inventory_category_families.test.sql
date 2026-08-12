begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_inventory_category_suggestions(text,integer)',
    'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_create_inventory_item(jsonb,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_adjust_inventory_stock(jsonb,uuid)', 'execute'
  ),
  'Authenticated clients reach the new warehouse boundary only through RPCs'
);

select ok(
  (select parent_category_id from public.v1_inventory_categories
   where id = '41000000-0000-4000-8000-000000000002')
    = '41000000-0000-4000-8000-000000000001'
  and (select name from public.v1_inventory_categories
       where id = '41000000-0000-4000-8000-000000000002') = 'Round',
  'The exact seeded Round category keeps its ID and gains the Air Terminals family'
);

select is(
  (public.v1_inventory_category_projection(
    '41000000-0000-4000-8000-000000000002'
  ) ->> 'display_path'),
  'Air Terminals › Round',
  'The category projection returns the approved one-level display path'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_category_suggestions('round', 8)$$,
  '42501', 'V1_INVENTORY_CATEGORY_SUGGEST_DENIED',
  'Project Engineer cannot query the organization warehouse category library'
);
select throws_ok(
  $$select public.v1_create_inventory_item(
    '{"item_description":"Forged item","unit":"Nos","category_id":"41000000-0000-4000-8000-000000000012","opening_quantity":"0","reason":""}'::jsonb,
    '92000000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_INVENTORY_ITEM_CREATE_DENIED',
  'Project Engineer cannot create a warehouse item through a direct RPC call'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  (public.v1_inventory_category_suggestions('round ac terminal', 8)
    -> 0 ->> 'display_path'),
  'Air Terminals › Round',
  'An exact saved alias resolves to its canonical family path'
);
select ok(
  (public.v1_inventory_category_suggestions('round air outlet', 8)
    -> 0 ->> 'display_path') = 'Air Terminals › Round'
  and (public.v1_inventory_category_suggestions('round air outlet', 8)
    -> 0 ->> 'match_kind') = 'related'
  and (public.v1_inventory_category_suggestions('round air outlet', 8)
    -> 0 ->> 'similarity_score')::numeric >= 0.25,
  'A similar category is ranked as an advisory result, never an exact match'
);

select lives_ok(
  $$select public.v1_create_inventory_category(
    '{"name":"Slot Diffuser","parent_category_id":"41000000-0000-4000-8000-000000000001"}'::jsonb,
    '92000000-0000-4000-8000-000000000002'
  )$$,
  'Procurement can explicitly create a one-level child category'
);

select throws_ok(
  $$select public.v1_create_inventory_category(
    jsonb_build_object(
      'name', 'Nested child',
      'parent_category_id', (
        public.v1_inventory_category_suggestions('Slot Diffuser', 1)
          -> 0 ->> 'category_id'
      )
    ),
    '92000000-0000-4000-8000-000000000003'
  )$$,
  '22023', 'V1_INVENTORY_CATEGORY_PARENT_INVALID',
  'A category family cannot be nested beyond one optional parent level'
);

select lives_ok(
  $$select public.v1_create_inventory_item(
    '{"item_code":"R383-CREATE-1","item_description":"Round diffuser 300 mm","category_id":"41000000-0000-4000-8000-000000000002","new_category_name":null,"new_category_parent_id":null,"source_category_text":"Round Ceiling Outlet","brand_origin":"Yorks","size_text":"300 mm","model_reference":"RD-300","unit":"Nos","minimum_stock":"2","location_bin":"Main Warehouse / A-01","notes":"Controlled item master","opening_quantity":"5","opening_reference":"COUNT-001","reason":"Verified opening count"}'::jsonb,
    '92000000-0000-4000-8000-000000000010'
  )$$,
  'Procurement atomically creates an item master and opening balance'
);

select lives_ok(
  $$select public.v1_create_inventory_item(
    '{"item_code":"R383-UNCATEGORIZED-1","item_description":"Arrangement-created uncategorized item","unit":"Nos","opening_quantity":"0","reason":""}'::jsonb,
    '92000000-0000-4000-8000-000000000013'
  )$$,
  'Procurement may create an uncategorized item during catalogue reconciliation'
);

set local role postgres;
select is(
  (select category_id from public.v1_inventory_items
   where item_code = 'R383-UNCATEGORIZED-1'),
  null::uuid,
  'The optional category is stored as null rather than a fabricated category'
);
select is(
  (select on_hand_qty from public.v1_inventory_balances balance
   join public.v1_inventory_items item on item.id = balance.inventory_item_id
   where item.item_code = 'R383-CREATE-1'),
  5::numeric,
  'The opening balance is authoritative inventory quantity'
);
select is(
  (select count(*)::integer from public.v1_inventory_movements movement
   join public.v1_inventory_items item on item.id = movement.inventory_item_id
   where item.item_code = 'R383-CREATE-1'
     and movement.movement_type = 'opening_balance'),
  1,
  'Item creation appends exactly one opening-balance movement'
);
select ok(
  exists (
    select 1
    from public.v1_inventory_category_aliases alias
    join public.v1_audit_events audit
      on audit.entity_id = alias.id
     and audit.event_type = 'inventory_category_alias_created'
    where alias.normalized_alias = 'roundceilingoutlet'
      and alias.category_id = '41000000-0000-4000-8000-000000000002'
  ),
  'An explicitly confirmed category phrase becomes one audited alias'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_create_inventory_item(
    '{"item_code":"R383-CREATE-1","item_description":"Round diffuser 300 mm","category_id":"41000000-0000-4000-8000-000000000002","new_category_name":null,"new_category_parent_id":null,"source_category_text":"Round Ceiling Outlet","brand_origin":"Yorks","size_text":"300 mm","model_reference":"RD-300","unit":"Nos","minimum_stock":"2","location_bin":"Main Warehouse / A-01","notes":"Controlled item master","opening_quantity":"5","opening_reference":"COUNT-001","reason":"Verified opening count"}'::jsonb,
    '92000000-0000-4000-8000-000000000010'
  )$$,
  'An exact item-creation retry returns the committed response'
);
select is(
  jsonb_array_length(
    public.v1_inventory_workspace_projection('R383-CREATE-1') -> 'items'
  ),
  1,
  'The item-creation retry cannot duplicate the item master'
);

select lives_ok(
  $$select public.v1_adjust_inventory_stock(
    jsonb_build_object(
      'inventory_item_id', (public.v1_inventory_workspace_projection('R383-CREATE-1')->'items'->0->>'id')::uuid,
      'expected_version', 1, 'action', 'add', 'quantity', '2.5',
      'reason', 'Goods received', 'reference', 'GRN-001'
    ),
    '92000000-0000-4000-8000-000000000011'
  )$$,
  'A versioned receive command appends stock'
);
select is(
  (public.v1_inventory_workspace_projection('R383-CREATE-1')
    -> 'items' -> 0 ->> 'on_hand_qty')::numeric,
  7.5::numeric,
  'The receive command changes on hand without touching reservations'
);
select lives_ok(
  $$select public.v1_adjust_inventory_stock(
    jsonb_build_object(
      'inventory_item_id', (public.v1_inventory_workspace_projection('R383-CREATE-1')->'items'->0->>'id')::uuid,
      'expected_version', 1, 'action', 'add', 'quantity', '2.5',
      'reason', 'Goods received', 'reference', 'GRN-001'
    ),
    '92000000-0000-4000-8000-000000000011'
  )$$,
  'A lost-response receive retry returns the original result'
);
select is(
  jsonb_array_length(public.v1_inventory_item_workspace_projection(
    (public.v1_inventory_workspace_projection('R383-CREATE-1')
      ->'items'->0->>'id')::uuid
  ) -> 'movements'),
  2,
  'The receive retry cannot duplicate a movement'
);
select throws_ok(
  $$select public.v1_adjust_inventory_stock(
    jsonb_build_object(
      'inventory_item_id', (public.v1_inventory_workspace_projection('R383-CREATE-1')->'items'->0->>'id')::uuid,
      'expected_version', 1, 'action', 'remove', 'quantity', '1',
      'reason', 'Stale removal', 'reference', null
    ),
    '92000000-0000-4000-8000-000000000012'
  )$$,
  '40001', 'V1_INVENTORY_ITEM_VERSION_CONFLICT',
  'A stale stock command fails before changing quantity'
);
select is(
  (public.v1_inventory_workspace_projection('R383-CREATE-1')
    -> 'items' -> 0 ->> 'on_hand_qty')::numeric,
  7.5::numeric,
  'The stale command leaves the authoritative balance unchanged'
);
select throws_ok(
  $$update public.v1_inventory_items set notes='Bypass' where item_code='R383-CREATE-1'$$,
  '42501', null,
  'Procurement cannot bypass the trusted item commands with a table update'
);

select * from finish();
rollback;
