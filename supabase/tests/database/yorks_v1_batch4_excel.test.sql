begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_import_boq_worksheet(jsonb,uuid)', 'execute'
  ) and not has_table_privilege('authenticated', 'public.v1_boq_groups', 'update'),
  'Workbook import is a trusted command, not a direct BOQ group update'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'v1_boq_groups'
      and column_name = 'last_import_source'
  ),
  'BOQ groups retain reviewed workbook source provenance'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B4-XLSX-001",
      "name":"Workbook Import Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Workbook editor"
      }],
      "buildings":[{"code":"b4","name":"Workbook Building"}],
      "attachments":[]
    }'::jsonb,
    '40000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates a project with an assigned Site Engineer importer'
);

select lives_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B4-XLSX-001'),
      'name', 'Workbook import test group'
    ),
    '40000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Project Engineer creates an isolated custom group for the Admin import proof'
);

set local role postgres;
create temporary table v1_b4_targets as
select
  project.id as project_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id and group_record.display_order = 3
  ) as worksheet_group_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id
      and group_record.name = 'Workbook import test group'
  ) as custom_group_id
from public.v1_projects project
where project.project_ref = 'B4-XLSX-001';
grant select on table v1_b4_targets to authenticated;

create temporary table v1_b4_import_payloads as
select jsonb_build_object(
  'group_id', worksheet_group_id,
  'expected_version', 1,
  'worksheet_title', 'MSD Equipment Schedule',
  'columns', jsonb_build_array(
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000001',
      'heading', 'Item Description', 'display_order', 1,
      'canonical_field', 'description', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000002',
      'heading', 'Brand / Origin', 'display_order', 2,
      'canonical_field', 'brand_origin', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000003',
      'heading', 'Model / Tag', 'display_order', 3,
      'canonical_field', 'planning_model_tag', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000004',
      'heading', 'Air flow (L/s)', 'display_order', 4,
      'canonical_field', null, 'is_commercial', false
    )
  ),
  'rows', jsonb_build_array(
    jsonb_build_object(
      'id', '42000000-0000-4000-8000-000000000001', 'display_order', 1,
      'raw_values', jsonb_build_object(
        '41000000-0000-4000-8000-000000000001', 'Motorized Smoke Damper',
        '41000000-0000-4000-8000-000000000002', 'UAE',
        '41000000-0000-4000-8000-000000000003', 'MSD-01A',
        '41000000-0000-4000-8000-000000000004', '708'
      )
    ),
    jsonb_build_object(
      'id', '42000000-0000-4000-8000-000000000002', 'display_order', 2,
      'raw_values', jsonb_build_object(
        '41000000-0000-4000-8000-000000000001', 'Volume Control Damper',
        '41000000-0000-4000-8000-000000000002', 'Italy',
        '41000000-0000-4000-8000-000000000003', 'VCD-02',
        '41000000-0000-4000-8000-000000000004', '450'
      )
    )
  ),
  'source', jsonb_build_object(
    'file_name', 'MSD Equipment Schedule.xlsx',
    'worksheet_name', 'MSD Schedule',
    'header_row_number', 3,
    'header_row_numbers', jsonb_build_array(3),
    'header_hierarchy', jsonb_build_array(
      jsonb_build_object('source_index', 0, 'labels', jsonb_build_array('Item Description')),
      jsonb_build_object('source_index', 1, 'labels', jsonb_build_array('Brand / Origin')),
      jsonb_build_object('source_index', 2, 'labels', jsonb_build_array('Model / Tag')),
      jsonb_build_object('source_index', 3, 'labels', jsonb_build_array('Air flow (L/s)'))
    )
  )
) as payload
from v1_b4_targets;
grant select on table v1_b4_import_payloads to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_import_boq_worksheet(
    (select payload from v1_b4_import_payloads),
    '40000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'AT-03: assigned Site Engineer imports a reviewed MSD worksheet atomically'
);

set local role postgres;
select is(
  (
    select public.v1_get_boq_worksheet(worksheet_group_id)
      #>> '{group,worksheet_title}' from v1_b4_targets
  ),
  'MSD Equipment Schedule',
  'Imported worksheet title is retained'
);

select is(
  (
    select jsonb_array_length(public.v1_get_boq_worksheet(worksheet_group_id) -> 'columns')
    from v1_b4_targets
  ),
  4,
  'Imported arbitrary headings create the reviewed worksheet column set'
);

select is(
  (
    select public.v1_get_boq_worksheet(worksheet_group_id)
      #>> '{rows,0,raw_values,41000000-0000-4000-8000-000000000004}'
    from v1_b4_targets
  ),
  '708',
  'AT-04: arbitrary technical values survive XLSX import'
);

select is(
  (
    select public.v1_get_boq_worksheet(worksheet_group_id)
      #>> '{rows,0,canonical_values,planning_model_tag}'
    from v1_b4_targets
  ),
  'MSD-01A',
  'Imported canonical mappings remain separate from arbitrary headings'
);

select is(
  (
    select last_import_source #>> '{worksheet_name}'
    from public.v1_boq_groups where id = (select worksheet_group_id from v1_b4_targets)
  ),
  'MSD Schedule',
  'Reviewed workbook source metadata is retained without workbook bytes'
);

select is(
  (
    select last_import_source #>> '{header_hierarchy,3,labels,0}'
    from public.v1_boq_groups where id = (select worksheet_group_id from v1_b4_targets)
  ),
  'Air flow (L/s)',
  'Reviewed header hierarchy is retained as import provenance'
);

select is(
  (
    select count(*) from public.v1_audit_events
    where event_type = 'boq_import_committed'
      and entity_id = (select worksheet_group_id from v1_b4_targets)
  ),
  1::bigint,
  'Workbook import creates one server-generated audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_import_boq_worksheet(
    (select payload from v1_b4_import_payloads),
    '40000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A same-actor/same-payload import retry returns the original result'
);

set local role postgres;
select is(
  (
    select record_version from public.v1_boq_groups
    where id = (select worksheet_group_id from v1_b4_targets)
  ),
  2,
  'Import retry does not apply another worksheet revision'
);

select is(
  (
    select count(*) from public.v1_audit_events
    where event_type = 'boq_import_committed'
      and entity_id = (select worksheet_group_id from v1_b4_targets)
  ),
  1::bigint,
  'Import retry does not duplicate its audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_set(
      jsonb_set(
        (select payload from v1_b4_import_payloads),
        '{expected_version}', '2'::jsonb
      ),
      '{rows}', '[]'::jsonb
    ),
    '40000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Header-only workbook import is valid and creates no material rows'
);

select is(
  (
    select jsonb_array_length(public.v1_get_boq_worksheet(worksheet_group_id) -> 'rows')
    from v1_b4_targets
  ),
  0,
  'Header-only import leaves an intentionally empty worksheet'
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          (select payload from v1_b4_import_payloads),
          '{expected_version}', '3'::jsonb
        ),
        '{columns}', jsonb_build_array(
          jsonb_build_object(
            'id', '41000000-0000-4000-8000-000000000010',
            'heading', 'Duplicate', 'display_order', 1,
            'canonical_field', 'description', 'is_commercial', false
          ),
          jsonb_build_object(
            'id', '41000000-0000-4000-8000-000000000011',
            'heading', 'duplicate', 'display_order', 2,
            'canonical_field', 'description', 'is_commercial', false
          )
        )
      ),
      '{source,header_hierarchy}',
      jsonb_build_array(
        jsonb_build_object('source_index', 0, 'labels', jsonb_build_array('Duplicate')),
        jsonb_build_object('source_index', 1, 'labels', jsonb_build_array('duplicate'))
      )
    ),
    '40000000-0000-4000-8000-000000000005'::uuid
  )$$,
  '22023',
  'V1_BOQ_IMPORT_COLUMN_MAPPING_DUPLICATE',
  'Duplicate headings or canonical mappings fail before a partial worksheet write'
);

select is(
  (
    select record_version from public.v1_boq_groups
    where id = (select worksheet_group_id from v1_b4_targets)
  ),
  3,
  'Rejected mapping leaves the committed header-only revision untouched'
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_set(
      (select payload from v1_b4_import_payloads),
      '{expected_version}', '2'::jsonb
    ),
    '40000000-0000-4000-8000-000000000006'::uuid
  )$$,
  '40001',
  'V1_BOQ_VERSION_CONFLICT',
  'Stale workbook import fails without overwriting the newer worksheet'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select custom_group_id from v1_b4_targets),
      'expected_version', 1,
      'worksheet_title', 'Admin workbook',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000020',
        'heading', 'Description', 'display_order', 1,
        'canonical_field', 'description', 'is_commercial', false
      )),
      'rows', '[]'::jsonb,
      'source', jsonb_build_object(
        'file_name', 'admin.xlsx', 'worksheet_name', 'BOQ', 'header_row_number', 1
      )
    ),
    '40000000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Admin may import a BOQ worksheet through the same trusted command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    (select payload from v1_b4_import_payloads),
    '40000000-0000-4000-8000-000000000008'::uuid
  )$$,
  '42501',
  'V1_BOQ_IMPORT_DENIED',
  'AT-25: Procurement cannot import a BOQ through the direct RPC'
);

select throws_ok(
  $$update public.v1_boq_groups
      set last_import_source = '{"file_name":"bypass.xlsx"}'::jsonb
    where id = (select worksheet_group_id from v1_b4_targets)$$,
  '42501',
  null,
  'Procurement cannot bypass import provenance through a direct table update'
);

select * from finish();

rollback;
