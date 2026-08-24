begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(97);

select ok(
  (select bool_and(relrowsecurity) from pg_class
   where oid in (
     'public.v1_suppliers'::regclass,
     'public.v1_supplier_aliases'::regclass,
     'public.v1_supplier_receipt_batches'::regclass,
     'public.v1_supplier_receipt_lines'::regclass,
     'public.v1_supplier_receipt_line_commercials'::regclass,
     'public.v1_inventory_import_results'::regclass,
     'public.v1_inventory_opening_balance_cutoffs'::regclass,
     'public.v1_inventory_import_row_results'::regclass,
     'public.v1_dispatch_batch_allocations'::regclass,
     'public.v1_dispatch_batch_allocation_gaps'::regclass,
     'public.v1_dispatch_batch_receipt_allocations'::regclass,
     'public.v1_dispatch_batch_receipt_gaps'::regclass,
     'public.v1_material_return_batch_allocations'::regclass,
     'public.v1_material_return_batch_allocation_gaps'::regclass
   )),
  'Every R38.9 supplier, receipt, import-result and allocation table enables RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_suppliers', 'select')
    and not has_table_privilege('authenticated', 'public.v1_suppliers', 'insert')
    and not has_table_privilege('authenticated', 'public.v1_supplier_receipt_lines', 'insert')
    and not has_table_privilege('authenticated', 'public.v1_supplier_receipt_line_commercials', 'select')
    and not has_table_privilege('authenticated', 'public.v1_inventory_opening_balance_cutoffs', 'select')
    and not has_table_privilege('authenticated', 'public.v1_dispatch_batch_allocation_gaps', 'insert')
    and not has_table_privilege('authenticated', 'public.v1_dispatch_batch_receipt_allocations', 'select')
    and not has_table_privilege('authenticated', 'public.v1_material_return_batch_allocations', 'insert')
    and has_function_privilege(
      'authenticated',
      'public.v1_supplier_directory_projection(text,text,integer,integer)',
      'execute'
    )
    and has_function_privilege(
      'authenticated', 'public.v1_import_inventory_r38_9(jsonb,uuid)', 'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.v1_supplier_item_trail_projection(uuid,uuid,text,integer,integer)', 'execute'
    )
    and has_function_privilege(
      'authenticated',
      'public.v1_supplier_receipt_batch_detail_projection(uuid,uuid,text,integer,integer)', 'execute'
    ),
  'Authenticated clients reach supplier state only through trusted RPCs'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_resolve_inventory_supplier_r38_9(uuid,text,text,uuid,integer)',
    'execute'
  )
    and not has_function_privilege(
      'authenticated', 'public.v1_supplier_name_key(text)', 'execute'
    )
    and not has_function_privilege(
      'authenticated', 'public.v1_protect_unknown_supplier()', 'execute'
    )
    and not has_function_privilege(
      'authenticated', 'public.v1_allocate_dispatch_line_fifo_r38_9()', 'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.v1_supplier_reconciliation_count_r38_9(uuid)', 'execute'
    )
    and not has_function_privilege(
      'authenticated', 'public.v1_supplier_trace_header_r38_9(uuid)', 'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.v1_attribute_receipt_review_line_r38_9(uuid)', 'execute'
    )
    and not has_function_privilege(
      'authenticated',
      'public.v1_attribute_material_return_r38_9(uuid,uuid)', 'execute'
    ),
  'Internal supplier helpers are not client-callable'
);

select ok(
  has_table_privilege('service_role', 'public.v1_suppliers', 'select')
    and has_table_privilege('service_role', 'public.v1_supplier_receipt_lines', 'insert')
    and has_table_privilege('service_role', 'public.v1_inventory_import_results', 'update')
    and has_table_privilege('service_role', 'public.v1_inventory_opening_balance_cutoffs', 'insert')
    and has_table_privilege('service_role', 'public.v1_dispatch_batch_allocation_gaps', 'select')
    and has_table_privilege('service_role', 'public.v1_dispatch_batch_receipt_allocations', 'insert')
    and has_table_privilege('service_role', 'public.v1_material_return_batch_allocations', 'select'),
  'The server service role retains explicit supplier table authority'
);

select ok(
  exists(
    select 1 from public.v1_suppliers
    where id = '00000000-0000-4000-8000-000000000389'
      and supplier_code = 'SUP-UNKNOWN'
      and name = 'Unknown Supplier'
      and normalized_name = 'unknownsupplier'
      and status = 'active' and is_system
  ),
  'The stable Unknown Supplier identity is seeded exactly as contracted'
);

select is(
  (select count(*)::integer from public.v1_suppliers where is_system),
  1,
  'Only one system supplier folder exists'
);

select throws_ok(
  $$update public.v1_suppliers set notes = 'forged'
    where id = '00000000-0000-4000-8000-000000000389'$$,
  '42501', 'V1_UNKNOWN_SUPPLIER_IMMUTABLE',
  'Even an owner-side update cannot rewrite Unknown Supplier history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_supplier_directory_projection(null, null, 25, 0)$$,
  '42501', 'V1_SUPPLIER_DIRECTORY_DENIED',
  'Project Engineer cannot enumerate supplier identities'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    '{"file_name":"forged.xlsx","file_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","rows":[]}'::jsonb,
    '98000000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_INVENTORY_IMPORT_R38_9_DENIED',
  'Project Engineer cannot reach the supplier-aware stock command'
);
select throws_ok(
  $$select public.v1_prepare_supplier_document_upload('{}'::jsonb,
    '98000000-0000-4000-8000-000000000090')$$,
  '42501', 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED',
  'Project Engineer cannot prepare a supplier document upload'
);
select throws_ok(
  $$select public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    '41000000-0000-4000-8000-000000000012'
  )$$,
  '42501', 'V1_SUPPLIER_ITEM_TRAIL_DENIED',
  'Project Engineer cannot read supplier item provenance'
);
select throws_ok(
  $$select public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    '41000000-0000-4000-8000-000000000012'
  )$$,
  '42501', 'V1_SUPPLIER_RECEIPT_BATCH_DETAIL_DENIED',
  'Project Engineer cannot read supplier receipt details'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_supplier_directory_projection(null, null, 25, 0)$$,
  '42501', 'V1_SUPPLIER_DIRECTORY_DENIED',
  'Senior Mechanical Engineer inventory read does not reveal supplier folders'
);
select throws_ok(
  $$select public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    '41000000-0000-4000-8000-000000000012'
  )$$,
  '42501', 'V1_SUPPLIER_ITEM_TRAIL_DENIED',
  'Senior Mechanical Engineer inventory read does not reveal item provenance'
);
select throws_ok(
  $$select public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    '41000000-0000-4000-8000-000000000012'
  )$$,
  '42501', 'V1_SUPPLIER_RECEIPT_BATCH_DETAIL_DENIED',
  'Senior Mechanical Engineer inventory read does not reveal receipt evidence'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_create_supplier(
    '{"canonical_name":"Forbidden Supplier","description":null,"aliases":[]}'::jsonb,
    '98000000-0000-4000-8000-000000000002'
  )$$,
  '42501', 'V1_SUPPLIER_CREATE_DENIED',
  'Site Engineer cannot create a supplier master'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_supplier_directory_projection(null, null, 25, 0)$$,
  'Procurement can open the supplier directory'
);
select is(
  (public.v1_create_supplier(
    '{"canonical_name":"R38.9 Command Supplier","description":"Created by pgTAP","aliases":["R389 Command"]}'::jsonb,
    '98000000-0000-4000-8000-000000000003'
  ) ->> 'canonical_name'),
  'R38.9 Command Supplier',
  'Supplier creation returns the exact typed directory-entry shape'
);
select lives_ok(
  $$select public.v1_create_supplier(
    '{"canonical_name":"R38.9 Command Supplier","description":"Created by pgTAP","aliases":["R389 Command"]}'::jsonb,
    '98000000-0000-4000-8000-000000000003'
  )$$,
  'An exact supplier-create retry returns the first response'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_suppliers
   where normalized_name = 'r389commandsupplier'),
  1,
  'Supplier-create idempotency cannot duplicate the canonical record'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_create_supplier(
    '{"canonical_name":"Changed Supplier","description":"Different payload","aliases":[]}'::jsonb,
    '98000000-0000-4000-8000-000000000003'
  )$$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'A supplier idempotency key cannot authorize a different request'
);
select throws_ok(
  $$select public.v1_create_supplier(
    '{"canonical_name":"Unknown field","description":null,"aliases":[],"forged":true}'::jsonb,
    '98000000-0000-4000-8000-000000000004'
  )$$,
  '22023', 'V1_UNKNOWN_CREATE_SUPPLIER_FIELDS: forged',
  'Supplier creation rejects unknown payload fields'
);
select throws_ok(
  $$select public.v1_supplier_directory_projection(null, null, 101, 0)$$,
  '22023', 'V1_SUPPLIER_DIRECTORY_ARGUMENT_INVALID',
  'Supplier directory pagination is bounded server-side'
);
select ok(
  (public.v1_prepare_supplier_document_upload(
    jsonb_build_object(
      'project_id', '00000000-0000-4000-8000-000000000389',
      'entity_type', 'supplier',
      'entity_id', '00000000-0000-4000-8000-000000000389',
      'classification', 'operational',
      'file_name', 'unknown-supplier-note.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 100,
      'sha256', repeat('f', 64),
      'origin', 'uploaded',
      'supplier_document_type', 'other'
    ), '98000000-0000-4000-8000-000000000091'
  ) ->> 'object_path') like
    'documents/suppliers/00000000-0000-4000-8000-000000000389/%/content',
  'Supplier documents receive a private supplier-scoped object path'
);
select ok(
  (public.v1_prepare_supplier_document_upload(
    jsonb_build_object(
      'project_id', '00000000-0000-4000-8000-000000000389',
      'entity_type', 'supplier',
      'entity_id', '00000000-0000-4000-8000-000000000389',
      'classification', 'commercial',
      'file_name', 'unknown-supplier-commercial.xlsx',
      'mime_type',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'byte_size', 20971520,
      'sha256', repeat('e', 64),
      'origin', 'uploaded',
      'supplier_document_type', 'invoice',
      'business_reference', 'INV-R389-001'
    ), '98000000-0000-4000-8000-000000000092'
  ) ->> 'object_path') like
    'documents/suppliers/00000000-0000-4000-8000-000000000389/%/content',
  'Authorized commercial evidence uses the shared protected 20 MB document boundary'
);
select ok(
  public.v1_supplier_document_workspace_projection(
    '00000000-0000-4000-8000-000000000389'
  ) ?& array['project_id', 'documents', 'audit_entries']
  and public.v1_supplier_document_workspace_projection(
    '00000000-0000-4000-8000-000000000389'
  ) ->> 'project_id' = '00000000-0000-4000-8000-000000000389',
  'The one-argument supplier document RPC returns the shared typed workspace contract'
);

set local role postgres;
select ok(
  exists(
    select 1 from public.v1_document_upload_intents intent
    where intent.idempotency_key = '98000000-0000-4000-8000-000000000091'
      and intent.project_id is null
      and intent.target_entity_type = 'supplier'
      and intent.target_entity_id = '00000000-0000-4000-8000-000000000389'
      and exists(
        select 1 from public.v1_document_upload_intents commercial_intent
        where commercial_intent.idempotency_key =
            '98000000-0000-4000-8000-000000000092'
          and commercial_intent.project_id is null
          and commercial_intent.classification = 'commercial'
          and commercial_intent.byte_size = 20971520
      )
  ),
  'Supplier upload intents never fabricate a project foreign key'
);

create temporary table v1_r389_commercial_document_intent as
select intent.id upload_intent_id, intent.object_path
from public.v1_document_upload_intents intent
where intent.idempotency_key = '98000000-0000-4000-8000-000000000092';
grant select on table v1_r389_commercial_document_intent
  to authenticated, service_role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$insert into storage.objects(bucket_id, name, owner_id, metadata)
    values (
      'yorks-documents',
      (select object_path from v1_r389_commercial_document_intent),
      auth.uid()::text,
      '{"size":20971520,"mimetype":"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"}'::jsonb
    )$$,
  'The existing private Storage policy accepts the supplier-scoped upload intent'
);
set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select lives_ok(
  $$select public.v1_create_document_version(
    (select upload_intent_id from v1_r389_commercial_document_intent),
    repeat('e', 64), 20971520,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  )$$,
  'The existing trusted finalizer creates a supplier document with no fake project'
);

set local role postgres;
create temporary table v1_r389_finalized_document_proof as
select exists(
  select 1 from public.v1_document_links link
  where link.entity_type = 'supplier'
    and link.entity_id = '00000000-0000-4000-8000-000000000389'
    and link.project_id is null
) has_null_project_link;
grant select on table v1_r389_finalized_document_proof to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.v1_supplier_document_workspace_projection(
        '00000000-0000-4000-8000-000000000389'
      ) -> 'documents'
    ) document_record
    cross join lateral jsonb_array_elements(document_record -> 'links') link
    where document_record ->> 'classification' = 'commercial'
      and document_record -> 'current_version'
        ?& array['id', 'revision_number', 'bucket_id', 'object_path',
          'original_file_name', 'mime_type', 'byte_size', 'sha256',
          'origin', 'uploaded_at', 'uploaded_by_auth_user_id',
          'uploaded_by_role', 'uploaded_by_display_name']
      and link ->> 'project_id' =
        '00000000-0000-4000-8000-000000000389'
      and link ->> 'entity_type' = 'supplier'
  )
  and (select has_null_project_link from v1_r389_finalized_document_proof)
  and exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_folder_projection(
        '00000000-0000-4000-8000-000000000389', 'documents', 25, 0
      ) -> 'documents'
    ) document_record
    where document_record ->> 'classification' = 'commercial'
  ),
  'Authorized projections expose finalized supplier evidence in both shared and flat typed shapes'
);

set local role postgres;
insert into public.v1_user_capabilities (
  auth_user_id, capability, is_granted, reason, changed_by_auth_user_id
) values (
  '10000000-0000-4000-8000-000000000003', 'manage_commercials', false,
  'R38.9 manage-versus-view proof',
  '10000000-0000-4000-8000-000000000004'
) on conflict (auth_user_id, capability) do update set
  is_granted = excluded.is_granted,
  reason = excluded.reason,
  changed_by_auth_user_id = excluded.changed_by_auth_user_id,
  updated_at = clock_timestamp();
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_prepare_supplier_document_upload(
    jsonb_build_object(
      'project_id', '00000000-0000-4000-8000-000000000389',
      'entity_type', 'supplier',
      'entity_id', '00000000-0000-4000-8000-000000000389',
      'classification', 'commercial',
      'file_name', 'view-only-commercial.pdf',
      'mime_type', 'application/pdf', 'byte_size', 100,
      'sha256', repeat('c', 64), 'origin', 'uploaded',
      'supplier_document_type', 'invoice',
      'business_reference', 'INV-R389-VIEW-ONLY'
    ), '98000000-0000-4000-8000-000000000094'
  )$$,
  '42501', 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED',
  'Commercial supplier document creation requires manage, not view, capability'
);
select lives_ok(
  $$select public.v1_prepare_supplier_document_upload(
    jsonb_build_object(
      'project_id', '00000000-0000-4000-8000-000000000389',
      'entity_type', 'supplier',
      'entity_id', '00000000-0000-4000-8000-000000000389',
      'classification', 'operational',
      'file_name', 'view-only-operational.pdf',
      'mime_type', 'application/pdf', 'byte_size', 100,
      'sha256', repeat('b', 64), 'origin', 'uploaded',
      'supplier_document_type', 'other'
    ), '98000000-0000-4000-8000-000000000095'
  )$$,
  'Inventory authority still permits an operational supplier document'
);
set local role postgres;
delete from public.v1_user_capabilities
where auth_user_id = '10000000-0000-4000-8000-000000000003'
  and capability = 'manage_commercials';

insert into public.v1_user_capabilities (
  auth_user_id, capability, is_granted, reason, changed_by_auth_user_id
) values (
  '10000000-0000-4000-8000-000000000003', 'view_commercials', false,
  'R38.9 supplier document revocation proof',
  '10000000-0000-4000-8000-000000000004'
) on conflict (auth_user_id, capability) do update set
  is_granted = excluded.is_granted,
  reason = excluded.reason,
  changed_by_auth_user_id = excluded.changed_by_auth_user_id,
  updated_at = clock_timestamp();
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_prepare_supplier_document_upload(
    jsonb_build_object(
      'project_id', '00000000-0000-4000-8000-000000000389',
      'entity_type', 'supplier',
      'entity_id', '00000000-0000-4000-8000-000000000389',
      'classification', 'commercial',
      'file_name', 'revoked-commercial.pdf',
      'mime_type', 'application/pdf', 'byte_size', 100,
      'sha256', repeat('d', 64), 'origin', 'uploaded',
      'supplier_document_type', 'invoice',
      'business_reference', 'INV-R389-REVOKED'
    ), '98000000-0000-4000-8000-000000000093'
  )$$,
  '42501', 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED',
  'A live commercial-capability revocation blocks supplier commercial evidence'
);
select ok(
  public.v1_supplier_document_workspace_projection(
    '00000000-0000-4000-8000-000000000389'
  ) -> 'documents' = '[]'::jsonb
  and public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'documents', 25, 0
  ) -> 'documents' = '[]'::jsonb,
  'Commercial supplier evidence is absent from every projection after live capability revocation'
);
set local role postgres;
delete from public.v1_user_capabilities
where auth_user_id = '10000000-0000-4000-8000-000000000003'
  and capability = 'view_commercials';

set local role postgres;
create temporary table v1_r389_import_payload as
select jsonb_build_object(
  'file_name', 'R38.9 Supplier Receipt Proof.xlsx',
  'file_sha256', repeat('b', 64),
  'import_mode', 'strict',
  'opening_balance_as_of_date', '2026-08-01',
  'rows', jsonb_build_array(
    jsonb_build_object(
      'source_row_number', 5,
      'inventory_item_id', null,
      'item_code', 'R389-UNKNOWN-001',
      'item_description', 'R38.9 unknown supplier receipt item',
      'category_id', '41000000-0000-4000-8000-000000000012',
      'new_category_name', null,
      'source_category_text', 'General',
      'brand_origin', 'UAE',
      'unit', 'Nos',
      'stock_action', 'add_stock',
      'quantity', '7',
      'delivered_quantity', '10',
      'reason', 'Condition split proof',
      'minimum_stock', '1',
      'location_bin', 'R389-U',
      'notes', 'Unknown supplier is deliberate',
      'source_type', 'external_supplier',
      'external_supplier_name', 'N/A',
      'supplier_reference', 'DN-R389-UNKNOWN',
      'received_date', '2026-08-20',
      'accepted_quantity', '7',
      'damaged_quantity', '2',
      'rejected_quantity', '1',
      'tracking_mode', 'bulk',
      'unit_price', '5',
      'total_price', '50',
      'calculated_total_price', '50',
      'currency_code', 'AED',
      'raw_source_values', jsonb_build_object('External Supplier Name', 'N/A')
    ),
    jsonb_build_object(
      'source_row_number', 6,
      'item_code', 'R389-NEW-001',
      'item_description', 'R38.9 explicit supplier item',
      'category_id', '41000000-0000-4000-8000-000000000012',
      'source_category_text', 'General',
      'brand_origin', 'Germany',
      'unit', 'Nos',
      'stock_action', 'add_stock',
      'quantity', '5',
      'delivered_quantity', '5',
      'reason', 'Explicit new supplier proof',
      'location_bin', 'R389-N',
      'source_type', 'external_supplier',
      'new_supplier_name', 'R38.9 Imported Supplier',
      'external_supplier_name', 'R389 Imported Vendor',
      'supplier_name_snapshot', 'R38.9 Imported Supplier',
      'supplier_resolution', 'createNew',
      'supplier_reference', 'DN-R389-NEW',
      'received_date', '2026-08-20',
      'accepted_quantity', '5',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'raw_source_values', jsonb_build_object('External Supplier Name', 'R389 Imported Vendor')
    ),
    jsonb_build_object(
      'source_row_number', 7,
      'item_code', 'R389-OPENING-001',
      'item_description', 'R38.9 opening balance item',
      'category_id', '41000000-0000-4000-8000-000000000012',
      'source_category_text', 'General',
      'unit', 'Nos',
      'stock_action', 'opening_balance',
      'quantity', '3',
      'delivered_quantity', '3',
      'reason', 'Controlled opening balance proof',
      'location_bin', 'R389-O',
      'source_type', 'opening_balance',
      'accepted_quantity', '3',
      'damaged_quantity', '0',
      'rejected_quantity', '0',
      'tracking_mode', 'bulk',
      'raw_source_values', jsonb_build_object('Source Type', 'Opening Balance')
    )
  )
) as payload;
grant select on table v1_r389_import_payload to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r389_import_payload),
    '98000000-0000-4000-8000-000000000010'
  )$$,
  'Procurement atomically commits reviewed supplier receipt rows'
);
select ok(
  (public.v1_import_inventory_r38_9(
    (select payload from v1_r389_import_payload),
    '98000000-0000-4000-8000-000000000010'
  ) @> '{"row_count":"3","created_items":"3","created_suppliers":"1","receipt_batches":"3","movements":"3","excluded_count":"0"}'::jsonb),
  'The committed summary uses the typed explicit result contract'
);
select is(
  (public.v1_import_inventory_r38_9(
    (select payload from v1_r389_import_payload),
    '98000000-0000-4000-8000-000000000010'
  ) ->> 'warning_count')::integer,
  4,
  'Unknown Supplier and generated opening metadata remain visible warnings'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items
   where item_code like 'R389-%-001'),
  3,
  'The import creates each reviewed inventory item exactly once'
);
select is(
  (select count(*)::integer from public.v1_supplier_receipt_batches batch
   join public.v1_inventory_import_results result
     on result.import_batch_id = batch.import_batch_id
   where result.file_sha256 = repeat('b', 64)),
  3,
  'Supplier, reference, date and location grouping creates three receipt batches'
);
select ok(
  exists(
    select 1 from public.v1_supplier_receipt_lines line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = line.receipt_batch_id
    join public.v1_inventory_items item on item.id = line.inventory_item_id
    join public.v1_inventory_import_row_results row_result
      on row_result.receipt_line_id = line.id
    where item.item_code = 'R389-UNKNOWN-001'
      and line.delivered_qty = 10 and line.accepted_qty = 7
      and line.damaged_qty = 2 and line.rejected_qty = 1
      and receipt_batch.supplier_id =
        '00000000-0000-4000-8000-000000000389'
      and row_result.source_supplier_text = 'N/A'
      and row_result.raw_source_values ->> 'External Supplier Name' = 'N/A'
  ),
  'Condition totals are authoritative and an N/A sentinel maps to Unknown without losing source evidence'
);
select is(
  (select balance.on_hand_qty from public.v1_inventory_balances balance
   join public.v1_inventory_items item on item.id = balance.inventory_item_id
   where item.item_code = 'R389-UNKNOWN-001'),
  7::numeric,
  'Only accepted quantity enters usable On Hand stock'
);
select is(
  (select count(*)::integer from public.v1_inventory_movements movement
   join public.v1_inventory_items item on item.id = movement.inventory_item_id
   where item.item_code like 'R389-%-001'
     and movement.source_entity_type = 'supplier_receipt_line'),
  3,
  'Every supplier stock increase points to its immutable receipt line'
);
select ok(
  exists(
    select 1 from public.v1_supplier_receipt_batches
    where supplier_id = '00000000-0000-4000-8000-000000000389'
      and source_type = 'opening_balance'
      and supplier_reference = 'OPENING-' || upper(substr(repeat('b', 64), 1, 12))
      and received_date = '2026-08-01'
  ),
  'Opening Balance omissions use Unknown Supplier and controlled reference/date values'
);
select ok(
  exists(
    select 1 from public.v1_inventory_import_row_results row_result
    where row_result.source_row_number = 6
      and row_result.supplier_name_snapshot = 'R38.9 Imported Supplier'
      and row_result.supplier_resolution_snapshot = 'createNew'
      and row_result.raw_source_values ->> 'External Supplier Name' =
        'R389 Imported Vendor'
  ),
  'Import row results retain raw and reviewed supplier-resolution evidence'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r389_import_payload),
    '98000000-0000-4000-8000-000000000010'
  )$$,
  'An exact import retry returns the first authoritative response'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_import_batches
   where idempotency_key = '98000000-0000-4000-8000-000000000010'),
  1,
  'The import retry cannot duplicate its batch'
);
select is(
  (select balance.on_hand_qty from public.v1_inventory_balances balance
   join public.v1_inventory_items item on item.id = balance.inventory_item_id
   where item.item_code = 'R389-NEW-001'),
  5::numeric,
  'The import retry cannot duplicate stock'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_set((select payload from v1_r389_import_payload), '{file_name}', '"changed.xlsx"'),
    '98000000-0000-4000-8000-000000000010'
  )$$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same import key rejects a different workbook payload'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    (select payload from v1_r389_import_payload),
    '98000000-0000-4000-8000-000000000011'
  )$$,
  '23505', 'V1_INVENTORY_IMPORT_FILE_ALREADY_COMMITTED',
  'A committed file fingerprint cannot enter stock again under a new key'
);

select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_set(
      (select payload from v1_r389_import_payload)
        - 'opening_balance_as_of_date',
      '{file_sha256}', to_jsonb(repeat('8', 64))
    ), '98000000-0000-4000-8000-000000000018'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_OPENING_DATE_REQUIRED',
  'Any Opening Balance row requires one explicit workbook cut-off date'
);
set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_import_batches
   where idempotency_key = '98000000-0000-4000-8000-000000000018'),
  0,
  'A missing Opening Balance cut-off leaves no import claim or partial batch'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_set(
      jsonb_set(
        (select payload from v1_r389_import_payload),
        '{file_name}', '"Alternative Opening Balance.xlsx"'
      ),
      '{file_sha256}', to_jsonb(repeat('9', 64))
    ), '98000000-0000-4000-8000-000000000019'
  )$$,
  '23505',
  'V1_INVENTORY_OPENING_BALANCE_CUTOFF_ALREADY_CLAIMED:2026-08-01',
  'A different master workbook cannot claim an already committed cut-off date'
);
set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_import_batches
   where idempotency_key = '98000000-0000-4000-8000-000000000019'),
  0,
  'A competing Opening Balance workbook rolls back without a second batch'
);

select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 atomic failure.xlsx',
      'file_sha256', repeat('c', 64),
      'rows', jsonb_build_array(
        jsonb_build_object(
          'source_row_number', 2, 'item_code', 'R389-ATOMIC-001',
          'item_description', 'Valid row that must roll back',
          'category_id', '41000000-0000-4000-8000-000000000012',
          'source_category_text', 'General', 'unit', 'Nos',
          'stock_action', 'add_stock', 'quantity', '1',
          'delivered_quantity', '1', 'reason', 'Atomic proof',
          'source_type', 'external_supplier',
          'supplier_reference', 'DN-R389-ATOMIC',
          'received_date', '2026-08-20', 'accepted_quantity', '1',
          'damaged_quantity', '0', 'rejected_quantity', '0'
        ),
        jsonb_build_object(
          'source_row_number', 3, 'item_code', 'R389-ATOMIC-002',
          'item_description', '',
          'category_id', '41000000-0000-4000-8000-000000000012',
          'source_category_text', 'General', 'unit', 'Nos',
          'stock_action', 'add_stock', 'quantity', '1',
          'delivered_quantity', '1', 'reason', 'Invalid row',
          'source_type', 'external_supplier',
          'supplier_reference', 'DN-R389-ATOMIC',
          'received_date', '2026-08-20', 'accepted_quantity', '1',
          'damaged_quantity', '0', 'rejected_quantity', '0'
        )
      )
    ), '98000000-0000-4000-8000-000000000012'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:3',
  'A later invalid row aborts the strict workbook transaction'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items
   where item_code like 'R389-ATOMIC-%'),
  0,
  'A failed strict workbook leaves no partial item or stock effect'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 unresolved supplier.xlsx',
      'file_sha256', repeat('d', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-FUZZY-001',
        'item_description', 'Unresolved fuzzy supplier row',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'source_category_text', 'General', 'unit', 'Nos',
        'stock_action', 'add_stock', 'quantity', '1',
        'delivered_quantity', '1', 'reason', 'Must choose explicitly',
        'source_type', 'external_supplier',
        'external_supplier_name', 'Unapproved Fuzzy Vendor',
        'supplier_reference', 'DN-R389-FUZZY',
        'received_date', '2026-08-20', 'accepted_quantity', '1',
        'damaged_quantity', '0', 'rejected_quantity', '0'
      ))
    ), '98000000-0000-4000-8000-000000000013'
  )$$,
  '22023', 'V1_SUPPLIER_DECISION_REQUIRED:Unapproved Fuzzy Vendor',
  'A similar or unknown nonblank supplier name never merges silently'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items
   where item_code = 'R389-FUZZY-001'),
  0,
  'An unresolved supplier decision rolls back its proposed inventory item'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 missing reference.xlsx',
      'file_sha256', repeat('e', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-NOREF-001',
        'item_description', 'Missing external reference',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'source_category_text', 'General', 'unit', 'Nos',
        'stock_action', 'add_stock', 'quantity', '1',
        'delivered_quantity', '1', 'reason', 'Must fail',
        'source_type', 'external_supplier', 'received_date', '2026-08-20',
        'accepted_quantity', '1', 'damaged_quantity', '0',
        'rejected_quantity', '0'
      ))
    ), '98000000-0000-4000-8000-000000000014'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_EXTERNAL_RECEIPT_REQUIRED:2',
  'External receipts require reference and received date even with Unknown Supplier'
);

select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-return.xlsx', 'file_sha256', repeat('1', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-UNSUPPORTED-RETURN',
        'item_description', 'Material Return must use its workflow',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'unit', 'Nos', 'stock_action', 'add_stock', 'quantity', '1',
        'delivered_quantity', '1', 'reason', 'Must fail closed',
        'source_type', 'material_return', 'accepted_quantity', '1',
        'damaged_quantity', '0', 'rejected_quantity', '0'
      ))
    ), '98000000-0000-4000-8000-000000000015'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:2',
  'Material Return input cannot bypass the authoritative return workflow'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-transfer.xlsx', 'file_sha256', repeat('2', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-UNSUPPORTED-TRANSFER',
        'item_description', 'Internal Transfer is outside one warehouse',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'unit', 'Nos', 'stock_action', 'add_stock', 'quantity', '1',
        'delivered_quantity', '1', 'reason', 'Must fail closed',
        'source_type', 'internal_transfer', 'accepted_quantity', '1',
        'damaged_quantity', '0', 'rejected_quantity', '0'
      ))
    ), '98000000-0000-4000-8000-000000000016'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:2',
  'Internal Transfer input cannot invent a multi-warehouse transaction'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-correction.xlsx', 'file_sha256', repeat('3', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-UNSUPPORTED-CORRECTION',
        'item_description', 'Correction requires the audited adjustment command',
        'category_id', '41000000-0000-4000-8000-000000000012',
        'unit', 'Nos', 'stock_action', 'correction_increase', 'quantity', '1',
        'delivered_quantity', '1', 'reason', 'Must fail closed',
        'source_type', 'correction', 'accepted_quantity', '1',
        'damaged_quantity', '0', 'rejected_quantity', '0'
      ))
    ), '98000000-0000-4000-8000-000000000017'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:2',
  'Correction input cannot bypass the existing audited stock adjustment command'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-remove.xlsx', 'file_sha256', repeat('6', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-UNSUPPORTED-REMOVE',
        'item_description', 'Removal must use a controlled stock command',
        'unit', 'Nos', 'stock_action', 'remove_stock', 'quantity', '1',
        'reason', 'Must fail closed', 'source_type', 'external_supplier',
        'supplier_reference', 'DN-REMOVE', 'received_date', '2026-08-20'
      ))
    ), '98000000-0000-4000-8000-000000000018'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:2',
  'Direct remove_stock import cannot bypass stock authority'
);
select throws_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'unsupported-no-change.xlsx',
      'file_sha256', repeat('7', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2, 'item_code', 'R389-UNSUPPORTED-NOCHANGE',
        'item_description', 'Metadata-only import is not a stock receipt',
        'unit', 'Nos', 'stock_action', 'no_stock_change', 'quantity', '1',
        'reason', 'Must fail closed', 'source_type', 'external_supplier',
        'supplier_reference', 'DN-NOCHANGE', 'received_date', '2026-08-20'
      ))
    ), '98000000-0000-4000-8000-000000000019'
  )$$,
  '22023', 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:2',
  'Direct no_stock_change import cannot bypass receipt and audit authority'
);

set local role postgres;
select is(
  (select count(*)::integer from public.v1_inventory_items
   where item_code like 'R389-UNSUPPORTED-%'),
  0,
  'Every unsupported source/action attempt leaves inventory unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select ok(
  (public.v1_supplier_directory_projection(null, null, 25, 0)
    ?& array['summary', 'suppliers', 'total_count', 'limit', 'offset']),
  'Supplier directory projection exposes the exact typed workspace keys'
);
select ok(
  exists(
    select 1
    from jsonb_array_elements(
      public.v1_supplier_directory_projection('Unknown', 'identity_missing', 25, 0)
        -> 'suppliers'
    ) entry
    where entry ->> 'id' = '00000000-0000-4000-8000-000000000389'
      and entry ->> 'canonical_name' = 'Unknown Supplier'
      and entry ->> 'status' = 'identity_missing'
      and (entry ->> 'is_system_unknown')::boolean
  ),
  'Unknown Supplier is a clear, filterable reconciliation folder'
);
select ok(
  (public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'overview', 25, 0
  ) ?& array['supplier', 'unit_totals', 'items', 'batches', 'documents',
    'destinations', 'activity', 'total_count', 'limit', 'offset']),
  'Supplier folder projection exposes every typed folder collection'
);
select ok(
  exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_folder_projection(
        '00000000-0000-4000-8000-000000000389', 'items_received', 25, 0
      ) -> 'items'
    ) item
    where item ->> 'item_code' = 'R389-UNKNOWN-001'
      and item ->> 'accepted_quantity' = '7.0000'
      and item ->> 'current_on_hand' = '7.0000'
  ),
  'Items Received keeps quantities in one real unit and reports current stock'
);
select ok(
  exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_folder_projection(
        '00000000-0000-4000-8000-000000000389', 'receipt_batches', 25, 0
      ) -> 'batches'
    ) batch
    where batch ?& array['receipt_number', 'source_type', 'received_date',
      'warehouse_location', 'line_count', 'unit_totals',
      'received_by_display_name', 'created_at']
  ),
  'Receipt batches expose one physical batch with nested unit-safe totals'
);
select ok(
  jsonb_array_length(public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'documents', 25, 0
  ) -> 'documents') = 1
    and (public.v1_supplier_folder_projection(
      '00000000-0000-4000-8000-000000000389', 'documents', 25, 0
    ) ->> 'documents_supported')::boolean,
  'Supplier folders expose finalized authorized evidence through the protected document path'
);
select ok(
  public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'receipt_batches', 25, 0
  )::text !~ '(unit_price|total_price|commercial)',
  'The supplier folder response contains no commercial field in its typed shape'
);

select throws_ok(
  $$insert into public.v1_supplier_aliases(
      supplier_id, alias_name, normalized_alias, created_by_auth_user_id
    ) values (
      '00000000-0000-4000-8000-000000000389', 'Bypass', 'bypass', auth.uid()
    )$$,
  '42501', null,
  'Procurement cannot bypass trusted supplier commands with a direct write'
);

-- Add one later receipt for the already imported item and one ordinary legacy
-- opening balance. These two stocks let the dispatch-line trigger prove both
-- deterministic FIFO provenance and the explicit no-fabrication fallback.
do $fifo_receipt_setup$
begin
  perform public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 later supplier receipt.xlsx',
      'file_sha256', repeat('4', 64),
      'rows', jsonb_build_array(
        jsonb_build_object(
          'source_row_number', 2,
          'item_code', 'R389-UNKNOWN-001',
          'item_description', 'R38.9 unknown supplier receipt item',
          'brand_origin', 'UAE', 'unit', 'Nos',
          'stock_action', 'add_stock', 'quantity', '4',
          'delivered_quantity', '4', 'reason', 'Later FIFO receipt proof',
          'source_type', 'external_supplier',
          'external_supplier_name', 'Unknown Supplier',
          'supplier_reference', 'DN-R389-UNKNOWN-LATER',
          'received_date', '2026-08-21', 'accepted_quantity', '4',
          'damaged_quantity', '0', 'rejected_quantity', '0',
          'tracking_mode', 'bulk'
        ),
        jsonb_build_object(
          'source_row_number', 3,
          'item_code', 'R389-UNKNOWN-LATER-002',
          'item_description', 'Second line in one Unknown receipt batch',
          'category_id', '41000000-0000-4000-8000-000000000012',
          'unit', 'Set', 'stock_action', 'add_stock', 'quantity', '1',
          'delivered_quantity', '1', 'reason', 'Line-count proof',
          'source_type', 'external_supplier',
          'external_supplier_name', 'Unknown Supplier',
          'supplier_reference', 'DN-R389-UNKNOWN-LATER',
          'received_date', '2026-08-21', 'accepted_quantity', '1',
          'damaged_quantity', '0', 'rejected_quantity', '0',
          'tracking_mode', 'bulk'
        )
      )
    ), '98000000-0000-4000-8000-000000000020'
  );
  perform public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 multilingual supplier receipt.xlsx',
      'file_sha256', repeat('5', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'item_code', 'R389-UNKNOWN-001',
        'item_description', 'R38.9 unknown supplier receipt item',
        'brand_origin', 'UAE', 'unit', 'Nos',
        'stock_action', 'add_stock', 'quantity', '2',
        'delivered_quantity', '2', 'reason', 'Multi-supplier provenance proof',
        'source_type', 'external_supplier',
        'new_supplier_name', 'شركة التبريد المتحدة',
        'external_supplier_name', 'یورکس سپلائر',
        'supplier_reference', 'DN-R389-MULTILINGUAL',
        'received_date', '2026-08-22', 'accepted_quantity', '2',
        'damaged_quantity', '0', 'rejected_quantity', '0',
        'tracking_mode', 'bulk'
      ))
    ), '98000000-0000-4000-8000-000000000022'
  );
  perform public.v1_create_inventory_item(
    jsonb_build_object(
      'item_code', 'R389-LEGACY-001',
      'item_description', 'R38.9 stock without supplier provenance',
      'unit', 'Nos', 'opening_quantity', '2',
      'opening_reference', 'LEGACY-R389',
      'reason', 'Legacy stock provenance fallback proof'
    ), '98000000-0000-4000-8000-000000000021'
  );
end;
$fifo_receipt_setup$;

set local role postgres;
select ok(
  exists(
    select 1
    from public.v1_suppliers supplier
    join public.v1_supplier_aliases supplier_alias
      on supplier_alias.supplier_id = supplier.id
    where supplier.name = 'شركة التبريد المتحدة'
      and supplier.normalized_name <> ''
      and supplier_alias.alias_name = 'یورکس سپلائر'
      and supplier_alias.normalized_alias <> ''
  ),
  'Unicode-only Arabic and Urdu supplier identities remain nonempty and exact'
);
select is(
  (select count(*)::integer
   from public.v1_audit_events audit_event
   join public.v1_suppliers supplier on supplier.id = audit_event.entity_id
   where supplier.name = 'شركة التبريد المتحدة'
     and audit_event.event_type in (
       'supplier_created', 'supplier_mapping_accepted'
     )
     and audit_event.after_data ->> 'import_batch_id' is not null),
  2,
  'Inline supplier creation and mapping acceptance emit AUD-005/AUD-003 evidence'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_import_inventory_r38_9(
    jsonb_build_object(
      'file_name', 'R38.9 multilingual supplier receipt.xlsx',
      'file_sha256', repeat('5', 64),
      'rows', jsonb_build_array(jsonb_build_object(
        'source_row_number', 2,
        'item_code', 'R389-UNKNOWN-001',
        'item_description', 'R38.9 unknown supplier receipt item',
        'brand_origin', 'UAE', 'unit', 'Nos',
        'stock_action', 'add_stock', 'quantity', '2',
        'delivered_quantity', '2', 'reason', 'Multi-supplier provenance proof',
        'source_type', 'external_supplier',
        'new_supplier_name', 'شركة التبريد المتحدة',
        'external_supplier_name', 'یورکس سپلائر',
        'supplier_reference', 'DN-R389-MULTILINGUAL',
        'received_date', '2026-08-22', 'accepted_quantity', '2',
        'damaged_quantity', '0', 'rejected_quantity', '0',
        'tracking_mode', 'bulk'
      ))
    ), '98000000-0000-4000-8000-000000000022'
  )$$,
  'An exact import retry returns before supplier identity and audit side effects'
);

set local role postgres;
select is(
  (select count(*)::integer
   from public.v1_audit_events audit_event
   join public.v1_suppliers supplier on supplier.id = audit_event.entity_id
   where supplier.name = 'شركة التبريد المتحدة'
     and audit_event.event_type in (
       'supplier_created', 'supplier_mapping_accepted'
     )),
  2,
  'The import idempotency boundary prevents duplicate supplier audit events'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '98900000-0000-4000-8000-000000000001', 'R389-FIFO-001',
  'R38.9 FIFO provenance project', 'active', 'procurement',
  '10000000-0000-4000-8000-000000000001', 'project_engineer'
);
insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable
) values (
  '98900000-0000-4000-8000-000000000002',
  '98900000-0000-4000-8000-000000000001',
  'common', 'common', 'Common / All Buildings', true
);
insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, state,
  created_by_auth_user_id, requester_display_name, requester_project_role,
  requester_exact_role, current_action_owner_role, current_action_code,
  submitted_at
) values
  ('98910000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000002', 'R389-FIFO-MR-001',
   'Imported supplier stock dispatch', 'approved',
   '10000000-0000-4000-8000-000000000001', 'Local Project Engineer',
   'project_engineer', 'project_engineer', 'procurement', 'dispatch_required',
   clock_timestamp()),
  ('98910000-0000-4000-8000-000000000002',
   '98900000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000002', 'R389-FIFO-MR-002',
   'Legacy warehouse stock dispatch', 'approved',
   '10000000-0000-4000-8000-000000000001', 'Local Project Engineer',
   'project_engineer', 'project_engineer', 'procurement', 'dispatch_required',
   clock_timestamp());
insert into public.v1_material_request_lines (
  id, request_id, display_order, source_kind, item_description,
  requested_qty, unit
) values
  ('98920000-0000-4000-8000-000000000001',
   '98910000-0000-4000-8000-000000000001', 1, 'custom',
   'R38.9 unknown supplier receipt item', 13, 'Nos'),
  ('98920000-0000-4000-8000-000000000002',
   '98910000-0000-4000-8000-000000000002', 1, 'custom',
   'R38.9 stock without supplier provenance', 2, 'Nos');
insert into public.v1_procurement_arrangements (
  id, request_id, arrangement_version, status, is_current,
  started_by_auth_user_id, saved_at, saved_by_auth_user_id,
  saved_by_exact_role, saved_by_display_name_snapshot
) values
  ('98930000-0000-4000-8000-000000000001',
   '98910000-0000-4000-8000-000000000001', 1, 'approved', true,
   '10000000-0000-4000-8000-000000000003', clock_timestamp(),
   '10000000-0000-4000-8000-000000000003', 'procurement',
   'Local Procurement'),
  ('98930000-0000-4000-8000-000000000002',
   '98910000-0000-4000-8000-000000000002', 1, 'approved', true,
   '10000000-0000-4000-8000-000000000003', clock_timestamp(),
   '10000000-0000-4000-8000-000000000003', 'procurement',
   'Local Procurement');
insert into public.v1_procurement_arrangement_lines (
  id, arrangement_id, request_line_id, source_kind, decision,
  arranged_qty, inventory_item_id, warehouse_available_at_save
) values
  ('98940000-0000-4000-8000-000000000001',
   '98930000-0000-4000-8000-000000000001',
   '98920000-0000-4000-8000-000000000001', 'warehouse', 'full', 13,
   (select id from public.v1_inventory_items
    where item_code = 'R389-UNKNOWN-001'), 13),
  ('98940000-0000-4000-8000-000000000002',
   '98930000-0000-4000-8000-000000000002',
   '98920000-0000-4000-8000-000000000002', 'warehouse', 'full', 2,
   (select id from public.v1_inventory_items
    where item_code = 'R389-LEGACY-001'), 2);
insert into public.v1_material_dispatches (
  id, request_id, project_id, dispatch_number, dispatch_date,
  delivery_reference, state, dispatched_by_auth_user_id,
  dispatched_by_role, dispatched_by_exact_role,
  dispatched_by_display_name_snapshot
) values
  ('98950000-0000-4000-8000-000000000001',
   '98910000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000001', 'R389-FIFO-DSP-001',
   current_date, 'DN-R389-FIFO-001', 'receipt_pending',
   '10000000-0000-4000-8000-000000000003', 'procurement', 'procurement',
   'Local Procurement'),
  ('98950000-0000-4000-8000-000000000002',
   '98910000-0000-4000-8000-000000000002',
   '98900000-0000-4000-8000-000000000001', 'R389-FIFO-DSP-002',
   current_date, 'DN-R389-FIFO-002', 'receipt_pending',
   '10000000-0000-4000-8000-000000000003', 'procurement', 'procurement',
   'Local Procurement');
insert into public.v1_material_dispatch_lines (
  id, dispatch_id, request_line_id, arrangement_line_id, source_kind,
  inventory_item_id, item_description, unit, approved_qty_snapshot,
  dispatched_qty
) values
  ('98960000-0000-4000-8000-000000000001',
   '98950000-0000-4000-8000-000000000001',
   '98920000-0000-4000-8000-000000000001',
   '98940000-0000-4000-8000-000000000001', 'warehouse',
   (select id from public.v1_inventory_items
    where item_code = 'R389-UNKNOWN-001'),
   'R38.9 unknown supplier receipt item', 'Nos', 13, 13),
  ('98960000-0000-4000-8000-000000000002',
   '98950000-0000-4000-8000-000000000002',
   '98920000-0000-4000-8000-000000000002',
   '98940000-0000-4000-8000-000000000002', 'warehouse',
   (select id from public.v1_inventory_items
    where item_code = 'R389-LEGACY-001'),
   'R38.9 stock without supplier provenance', 'Nos', 2, 2);

select ok(
  (select count(*) = 3 and sum(allocation.allocated_qty) = 13
   from public.v1_dispatch_batch_allocations allocation
   where allocation.dispatch_line_id =
     '98960000-0000-4000-8000-000000000001')
  and exists(
    select 1
    from public.v1_dispatch_batch_allocations allocation
    join public.v1_supplier_receipt_lines receipt_line
      on receipt_line.id = allocation.receipt_line_id
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where allocation.dispatch_line_id =
        '98960000-0000-4000-8000-000000000001'
      and receipt_batch.received_date = '2026-08-20'
      and allocation.allocated_qty = 7
  )
  and exists(
    select 1
    from public.v1_dispatch_batch_allocations allocation
    join public.v1_supplier_receipt_lines receipt_line
      on receipt_line.id = allocation.receipt_line_id
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where allocation.dispatch_line_id =
        '98960000-0000-4000-8000-000000000001'
      and receipt_batch.received_date = '2026-08-21'
      and allocation.allocated_qty = 4
  )
  and exists(
    select 1
    from public.v1_dispatch_batch_allocations allocation
    join public.v1_supplier_receipt_lines receipt_line
      on receipt_line.id = allocation.receipt_line_id
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    join public.v1_suppliers supplier on supplier.id = receipt_batch.supplier_id
    where allocation.dispatch_line_id =
        '98960000-0000-4000-8000-000000000001'
      and supplier.name = 'شركة التبريد المتحدة'
      and allocation.allocated_qty = 2
  )
  and not exists(
    select 1 from public.v1_dispatch_batch_allocation_gaps gap
    where gap.dispatch_line_id =
      '98960000-0000-4000-8000-000000000001'
  ),
  'A post-import dispatch consumes multiple receipt batches and suppliers in deterministic FIFO order'
);
select ok(
  exists(
    select 1 from public.v1_material_dispatch_lines dispatch_line
    where dispatch_line.id = '98960000-0000-4000-8000-000000000002'
  )
  and not exists(
    select 1 from public.v1_dispatch_batch_allocations allocation
    where allocation.dispatch_line_id =
      '98960000-0000-4000-8000-000000000002'
  )
  and exists(
    select 1 from public.v1_dispatch_batch_allocation_gaps gap
    where gap.dispatch_line_id =
        '98960000-0000-4000-8000-000000000002'
      and gap.unallocated_qty = 2
      and gap.reason_code = 'legacy_or_unproven_stock'
  ),
  'Legacy-only stock still dispatches and records an explicit unproven gap without a fake supplier'
);

insert into public.v1_receipt_reviews (
  id, dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
) values
  ('98970000-0000-4000-8000-000000000001',
   '98950000-0000-4000-8000-000000000001',
   '98910000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000001', 'project_engineer'),
  ('98970000-0000-4000-8000-000000000002',
   '98950000-0000-4000-8000-000000000002',
   '98910000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000001', 'project_engineer');
insert into public.v1_receipt_review_lines (
  id, receipt_review_id, dispatch_line_id, outcome,
  dispatched_qty_snapshot, good_qty, exception_qty,
  missing_qty, damaged_qty, note
) values
  ('98971000-0000-4000-8000-000000000001',
   '98970000-0000-4000-8000-000000000001',
   '98960000-0000-4000-8000-000000000001', 'received', 13, 13, 0, 0, 0, null),
  ('98971000-0000-4000-8000-000000000002',
   '98970000-0000-4000-8000-000000000002',
   '98960000-0000-4000-8000-000000000002', 'damaged', 2, 1, 1, 0, 1,
   'Legacy quantity review proof');

select ok(
  (select count(*) = 3 and sum(good_qty) = 13 and sum(exception_qty) = 0
   from public.v1_dispatch_batch_receipt_allocations
   where receipt_review_line_id =
     '98971000-0000-4000-8000-000000000001')
  and not exists(
    select 1 from public.v1_dispatch_batch_receipt_gaps
    where receipt_review_line_id =
      '98971000-0000-4000-8000-000000000001'
  )
  and exists(
    select 1 from public.v1_dispatch_batch_receipt_gaps receipt_gap
    where receipt_gap.receipt_review_line_id =
        '98971000-0000-4000-8000-000000000002'
      and receipt_gap.good_qty = 1 and receipt_gap.exception_qty = 1
  ),
  'Site receipt good and exception quantities are apportioned once and legacy remainder stays explicit'
);

insert into public.v1_material_returns (
  id, request_id, project_id, scope_id, return_number, state, note,
  drafted_by_auth_user_id, drafted_by_role,
  submitted_by_auth_user_id, submitted_by_role, submitted_at
) values
  ('98980000-0000-4000-8000-000000000001',
   '98910000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000002', 'R389-RET-001', 'dispatched',
   'Return across supplier allocations',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   clock_timestamp()),
  ('98980000-0000-4000-8000-000000000002',
   '98910000-0000-4000-8000-000000000002',
   '98900000-0000-4000-8000-000000000001',
   '98900000-0000-4000-8000-000000000002', 'R389-RET-002', 'dispatched',
   'Return of legacy unproven stock',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   clock_timestamp());
insert into public.v1_material_return_lines (
  id, material_return_id, receipt_review_line_id, dispatch_line_id,
  request_line_id, source_kind, source_inventory_item_id, item_description,
  unit, good_quantity_snapshot, eligible_quantity_at_submit,
  return_quantity, display_order
) values
  ('98981000-0000-4000-8000-000000000001',
   '98980000-0000-4000-8000-000000000001',
   '98971000-0000-4000-8000-000000000001',
   '98960000-0000-4000-8000-000000000001',
   '98920000-0000-4000-8000-000000000001', 'warehouse',
   (select id from public.v1_inventory_items where item_code = 'R389-UNKNOWN-001'),
   'R38.9 unknown supplier receipt item', 'Nos', 13, 5, 5, 1),
  ('98981000-0000-4000-8000-000000000002',
   '98980000-0000-4000-8000-000000000002',
   '98971000-0000-4000-8000-000000000002',
   '98960000-0000-4000-8000-000000000002',
   '98920000-0000-4000-8000-000000000002', 'warehouse',
   (select id from public.v1_inventory_items where item_code = 'R389-LEGACY-001'),
   'R38.9 stock without supplier provenance', 'Nos', 1, 1, 1, 1);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', '98980000-0000-4000-8000-000000000001',
      'expected_version', 1, 'line_mappings', '[]'::jsonb
    ), '98982000-0000-4000-8000-000000000001'
  )$$,
  'Procurement confirms the multi-supplier Material Return through stock authority'
);
select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', '98980000-0000-4000-8000-000000000002',
      'expected_version', 1, 'line_mappings', '[]'::jsonb
    ), '98982000-0000-4000-8000-000000000002'
  )$$,
  'Procurement confirms a legacy return without fabricating a supplier'
);
select lives_ok(
  $$select public.v1_confirm_material_return(
    jsonb_build_object(
      'return_id', '98980000-0000-4000-8000-000000000001',
      'expected_version', 1, 'line_mappings', '[]'::jsonb
    ), '98982000-0000-4000-8000-000000000001'
  )$$,
  'An exact return-confirm retry returns the authoritative first response'
);

set local role postgres;
select ok(
  (select count(*) = 2 and sum(returned_qty) = 5
   from public.v1_material_return_batch_allocations
   where material_return_line_id =
     '98981000-0000-4000-8000-000000000001')
  and not exists(
    select 1
    from public.v1_material_return_batch_allocations return_attribution
    join public.v1_dispatch_batch_receipt_allocations receipt_attribution
      on receipt_attribution.id = return_attribution.receipt_attribution_id
    where return_attribution.returned_qty > receipt_attribution.good_qty
  )
  and exists(
    select 1
    from public.v1_material_return_batch_allocations return_attribution
    join public.v1_dispatch_batch_receipt_allocations receipt_attribution
      on receipt_attribution.id = return_attribution.receipt_attribution_id
    join public.v1_dispatch_batch_allocations allocation
      on allocation.id = receipt_attribution.dispatch_allocation_id
    join public.v1_supplier_receipt_lines receipt_line
      on receipt_line.id = allocation.receipt_line_id
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    join public.v1_suppliers supplier on supplier.id = receipt_batch.supplier_id
    where return_attribution.material_return_line_id =
        '98981000-0000-4000-8000-000000000001'
      and supplier.name = 'شركة التبريد المتحدة'
      and return_attribution.returned_qty = 2
  ),
  'Reverse FIFO attributes a return exactly once across suppliers and caps every source allocation'
);
select ok(
  exists(
    select 1 from public.v1_material_return_batch_allocation_gaps return_gap
    where return_gap.material_return_line_id =
        '98981000-0000-4000-8000-000000000002'
      and return_gap.returned_qty = 1
      and return_gap.reason_code = 'legacy_or_unproven_stock'
  )
  and (select count(*) from public.v1_material_return_batch_allocations
       where material_return_line_id =
         '98981000-0000-4000-8000-000000000001') = 2,
  'Unproven return remainder stays in a gap and retry creates no duplicate attribution'
);

insert into public.v1_material_dispatches (
  id, request_id, project_id, dispatch_number, dispatch_date,
  delivery_reference, state, dispatched_by_auth_user_id, dispatched_by_role,
  dispatched_by_exact_role, dispatched_by_display_name_snapshot
) values (
  '98950000-0000-4000-8000-000000000003',
  '98910000-0000-4000-8000-000000000001',
  '98900000-0000-4000-8000-000000000001', 'R389-FIFO-DSP-003',
  current_date, 'DN-R389-FIFO-003', 'receipt_pending',
  '10000000-0000-4000-8000-000000000003', 'procurement', 'procurement',
  'Local Procurement'
);
insert into public.v1_material_dispatch_lines (
  id, dispatch_id, request_line_id, arrangement_line_id, source_kind,
  inventory_item_id, item_description, unit, approved_qty_snapshot,
  dispatched_qty
) values (
  '98960000-0000-4000-8000-000000000003',
  '98950000-0000-4000-8000-000000000003',
  '98920000-0000-4000-8000-000000000001',
  '98940000-0000-4000-8000-000000000001', 'warehouse',
  (select id from public.v1_inventory_items where item_code = 'R389-UNKNOWN-001'),
  'R38.9 unknown supplier receipt item', 'Nos', 13, 5
);
select ok(
  (select count(*) = 2 and sum(allocated_qty) = 5
   from public.v1_dispatch_batch_allocations
   where dispatch_line_id = '98960000-0000-4000-8000-000000000003')
  and not exists(
    select 1 from public.v1_dispatch_batch_allocation_gaps
    where dispatch_line_id = '98960000-0000-4000-8000-000000000003'
  ),
  'Confirmed returned provenance is recredited and later re-dispatch has no false gap'
);

insert into public.v1_receipt_reviews (
  id, dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
) values (
  '98970000-0000-4000-8000-000000000003',
  '98950000-0000-4000-8000-000000000003',
  '98910000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001', 'project_engineer'
);
insert into public.v1_receipt_review_lines (
  id, receipt_review_id, dispatch_line_id, outcome,
  dispatched_qty_snapshot, good_qty, exception_qty,
  missing_qty, damaged_qty, note
) values (
  '98971000-0000-4000-8000-000000000003',
  '98970000-0000-4000-8000-000000000003',
  '98960000-0000-4000-8000-000000000003', 'damaged', 5, 3, 2, 0, 2,
  'Non-duplicating allocation receipt proof'
);
select ok(
  (select sum(good_qty) = 3 and sum(exception_qty) = 2
   from public.v1_dispatch_batch_receipt_allocations
   where receipt_review_line_id =
     '98971000-0000-4000-8000-000000000003')
  and not exists(
    select 1
    from public.v1_dispatch_batch_receipt_allocations receipt_attribution
    join public.v1_dispatch_batch_allocations allocation
      on allocation.id = receipt_attribution.dispatch_allocation_id
    where receipt_attribution.receipt_review_line_id =
        '98971000-0000-4000-8000-000000000003'
      and receipt_attribution.good_qty + receipt_attribution.exception_qty >
        allocation.allocated_qty
  ),
  'Multi-allocation receipt facts sum to the authoritative review and never multiply'
);

select set_config(
  'test.r389_unknown_item_id',
  (select id::text from public.v1_inventory_items
   where item_code = 'R389-UNKNOWN-001'),
  true
);
select set_config(
  'test.r389_unknown_later_batch_id',
  (select id::text from public.v1_supplier_receipt_batches
   where supplier_reference = 'DN-R389-UNKNOWN-LATER'),
  true
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select ok(
  exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_directory_projection(
        'Unknown', 'identity_missing', 25, 0
      ) -> 'unit_totals'
    ) unit_total
    where unit_total ->> 'unit' = 'Nos'
      and unit_total ->> 'accepted_quantity' = '14.0000'
  )
  and exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_directory_projection(
        'Unknown', 'identity_missing', 25, 0
      ) -> 'unit_totals'
    ) unit_total
    where unit_total ->> 'unit' = 'Set'
      and unit_total ->> 'accepted_quantity' = '1.0000'
  )
  and exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_directory_projection(
        'Unknown', 'identity_missing', 25, 0
      ) -> 'suppliers'
    ) supplier
    where supplier ->> 'id' = '00000000-0000-4000-8000-000000000389'
      and supplier ->> 'receipt_batch_count' = '3'
      and supplier ->> 'reconciliation_count' = '4'
  )
  and public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'overview', 25, 0
  ) -> 'supplier' ->> 'reconciliation_count' = '4'
  and (select count(*)
       from jsonb_array_elements(public.v1_supplier_folder_projection(
         '00000000-0000-4000-8000-000000000389',
         'receipt_batches', 25, 0
       ) -> 'batches') receipt_batch
       where receipt_batch ->> 'supplier_reference' =
         'DN-R389-UNKNOWN-LATER') = 1
  and exists(
    select 1
    from jsonb_array_elements(public.v1_supplier_folder_projection(
      '00000000-0000-4000-8000-000000000389',
      'receipt_batches', 25, 0
    ) -> 'batches') receipt_batch
    where receipt_batch ->> 'supplier_reference' =
        'DN-R389-UNKNOWN-LATER'
      and jsonb_array_length(receipt_batch -> 'unit_totals') = 2
  ),
  'Directory totals stay unit-safe and Unknown reconciliation counts four source lines rather than three batches'
);

select ok(
  public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid
  ) ?& array['supplier', 'item', 'section', 'total_count', 'limit', 'offset',
    'receipt_lines', 'movements', 'reservations', 'destinations',
    'provenance_gaps', 'activity']
  and jsonb_array_length(public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid
  ) -> 'receipt_lines') = 2
  and jsonb_array_length(public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid
  ) -> 'destinations') = 0
  and public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid
  )::text !~ '(unit_price|total_price|commercial)',
  'Item trail returns one bounded selected section and no commercial fields'
);

select ok(
  (public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid,
    'destinations', 1, 0
  ) ->> 'total_count') = '3'
  and jsonb_array_length(public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid,
    'destinations', 1, 0
  ) -> 'destinations') = 1
  and (public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid,
    'destinations', 1, 0
  ) -> 'destinations' -> 0 ->> 'allocation_id') <>
  (public.v1_supplier_item_trail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_item_id')::uuid,
    'destinations', 1, 1
  ) -> 'destinations' -> 0 ->> 'allocation_id'),
  'Item destination history has deterministic bounded pagination'
);

select ok(
  (select sum((destination ->> 'good_received_quantity')::numeric) = 14
     and sum((destination ->> 'exception_quantity')::numeric) = 0
     and sum((destination ->> 'confirmed_return_quantity')::numeric) = 3
   from jsonb_array_elements(public.v1_supplier_folder_projection(
     '00000000-0000-4000-8000-000000000389', 'destinations', 25, 0
   ) -> 'destinations') destination)
  and not exists(
    select 1 from jsonb_array_elements(public.v1_supplier_folder_projection(
      '00000000-0000-4000-8000-000000000389', 'destinations', 25, 0
    ) -> 'destinations') destination
    where not (destination ?& array[
      'supplier_id', 'inventory_item_id', 'receipt_line_id',
      'receipt_batch_id', 'dispatch_line_id', 'dispatch_id', 'request_id',
      'project_id', 'scope_id', 'material_return_ids', 'provenance_state'
    ])
  ),
  'Folder destinations expose drill-through IDs and exact non-duplicated receipt/return facts'
);

select ok(
  (public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid
  ) -> 'batch' ->> 'line_count') = '2'
  and (public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid
  ) -> 'batch' ->> 'received_by_role') = 'procurement'
  and exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_receipt_batch_detail_projection(
        '00000000-0000-4000-8000-000000000389',
        current_setting('test.r389_unknown_later_batch_id')::uuid
      ) -> 'batch' -> 'unit_totals'
    ) unit_total
    where unit_total ->> 'unit' = 'Nos'
      and unit_total ->> 'accepted_quantity' = '4.0000'
  )
  and exists(
    select 1 from jsonb_array_elements(
      public.v1_supplier_receipt_batch_detail_projection(
        '00000000-0000-4000-8000-000000000389',
        current_setting('test.r389_unknown_later_batch_id')::uuid
      ) -> 'batch' -> 'unit_totals'
    ) unit_total
    where unit_total ->> 'unit' = 'Set'
      and unit_total ->> 'accepted_quantity' = '1.0000'
  )
  and jsonb_array_length(public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid,
    'activity', 100, 0
  ) -> 'activity') >= 2
  and public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid
  )::text !~ '(unit_price|total_price|commercial)',
  'Receipt detail returns every line, split unit totals, immutable actor/audit evidence and no commercial fields'
);

select ok(
  (public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid,
    'lines', 1, 0
  ) ->> 'total_count') = '2'
  and jsonb_array_length(public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid,
    'lines', 1, 0
  ) -> 'lines') = 1
  and (public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid,
    'lines', 1, 0
  ) -> 'lines' -> 0 ->> 'id') <>
  (public.v1_supplier_receipt_batch_detail_projection(
    '00000000-0000-4000-8000-000000000389',
    current_setting('test.r389_unknown_later_batch_id')::uuid,
    'lines', 1, 1
  ) -> 'lines' -> 0 ->> 'id'),
  'Receipt batch lines have deterministic bounded pagination'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_supplier_directory_projection(null, 'all', 25, 0)$$,
  'Admin retains supplier-directory authority'
);
select lives_ok(
  $tap$do $admin_trace$
    begin
      perform public.v1_supplier_item_trail_projection(
        '00000000-0000-4000-8000-000000000389',
        current_setting('test.r389_unknown_item_id')::uuid
      );
      perform public.v1_supplier_receipt_batch_detail_projection(
        '00000000-0000-4000-8000-000000000389',
        current_setting('test.r389_unknown_later_batch_id')::uuid
      );
    end;
  $admin_trace$$tap$,
  'Admin retains supplier item-trail and receipt-detail authority'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select ok(
  jsonb_array_length(public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'activity_audit', 25, 0
  ) -> 'activity') >= 2,
  'Supplier activity contains server-generated receipt audit events'
);
select throws_ok(
  $$select public.v1_supplier_folder_projection(
    '00000000-0000-4000-8000-000000000389', 'forged_section', 25, 0
  )$$,
  '22023', 'V1_SUPPLIER_FOLDER_ARGUMENT_INVALID',
  'Unknown supplier folder sections are rejected server-side'
);

set local role postgres;
select ok(
  exists(
    select 1 from public.v1_supplier_aliases alias
    join public.v1_suppliers supplier on supplier.id = alias.supplier_id
    where supplier.normalized_name = 'r389importedsupplier'
      and alias.normalized_alias = 'r389importedvendor'
  ),
  'An explicitly approved source name is retained once as a canonical alias'
);

select * from finish();
rollback;
