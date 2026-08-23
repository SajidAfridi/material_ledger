begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(44);

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
      'scope_id', (
        select scope.id from public.v1_project_scopes scope
        join public.v1_projects project on project.id = scope.project_id
        where project.project_ref = 'B4-XLSX-001' and scope.scope_kind = 'common'
      ),
      'name', 'Workbook import test group'
    ),
    '40000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Project Engineer creates an isolated custom group for the Admin import proof'
);

do $$
begin
  perform public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects where project_ref = 'B4-XLSX-001'
      ),
      'scope_id', (
        select scope.id from public.v1_project_scopes scope
        join public.v1_projects project on project.id = scope.project_id
        where project.project_ref = 'B4-XLSX-001'
          and scope.scope_kind = 'common'
      ),
      'name', 'Legacy commercial repair group'
    ),
    '40000000-0000-4000-8000-000000000015'::uuid
  );
end;
$$;

set local role postgres;
create temporary table v1_b4_targets as
select
  project.id as project_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id
      and group_record.name = 'Workshop Materials'
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ) as worksheet_group_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id
      and group_record.name = 'Workbook import test group'
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ) as custom_group_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id
      and group_record.name = 'Legacy commercial repair group'
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ) as repair_group_id
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
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000009',
      'heading', 'Size (mm x mm)', 'display_order', 5,
      'canonical_field', 'size', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000010',
      'heading', 'Model', 'display_order', 6,
      'canonical_field', 'model', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000011',
      'heading', 'Equipment tag', 'display_order', 7,
      'canonical_field', 'equipment_tag', 'is_commercial', false
    )
  ),
  'rows', jsonb_build_array(
    jsonb_build_object(
      'id', '42000000-0000-4000-8000-000000000001', 'display_order', 1,
      'raw_values', jsonb_build_object(
        '41000000-0000-4000-8000-000000000001', 'Motorized Smoke Damper',
        '41000000-0000-4000-8000-000000000002', 'UAE',
        '41000000-0000-4000-8000-000000000003', 'MSD-01A',
        '41000000-0000-4000-8000-000000000004', '708',
        '41000000-0000-4000-8000-000000000009', '600 x 600',
        '41000000-0000-4000-8000-000000000010', 'MFD-600',
        '41000000-0000-4000-8000-000000000011', 'MSD-01A'
      )
    ),
    jsonb_build_object(
      'id', '42000000-0000-4000-8000-000000000002', 'display_order', 2,
      'raw_values', jsonb_build_object(
        '41000000-0000-4000-8000-000000000001', 'Volume Control Damper',
        '41000000-0000-4000-8000-000000000002', 'Italy',
        '41000000-0000-4000-8000-000000000003', 'VCD-02',
        '41000000-0000-4000-8000-000000000004', '450',
        '41000000-0000-4000-8000-000000000009', '1100c450',
        '41000000-0000-4000-8000-000000000010', 'VCD-1100',
        '41000000-0000-4000-8000-000000000011', 'VCD-02'
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
      jsonb_build_object('source_index', 3, 'labels', jsonb_build_array('Air flow (L/s)')),
      jsonb_build_object('source_index', 4, 'labels', jsonb_build_array('Size (mm x mm)')),
      jsonb_build_object('source_index', 5, 'labels', jsonb_build_array('Model')),
      jsonb_build_object('source_index', 6, 'labels', jsonb_build_array('Equipment tag'))
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
  7,
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
    select last_import_source #>> '{header_hierarchy,6,labels,0}'
    from public.v1_boq_groups where id = (select worksheet_group_id from v1_b4_targets)
  ),
  'Equipment tag',
  'Reviewed header hierarchy is retained as import provenance'
);

select is(
  (
    select concat_ws(
      '|',
      public.v1_get_boq_worksheet(worksheet_group_id)
        #>> '{rows,0,canonical_values,size}',
      public.v1_get_boq_worksheet(worksheet_group_id)
        #>> '{rows,0,canonical_values,model}',
      public.v1_get_boq_worksheet(worksheet_group_id)
        #>> '{rows,0,canonical_values,equipment_tag}'
    ) from v1_b4_targets
  ),
  '600 x 600|MFD-600|MSD-01A',
  'Equipment Schedule technical mappings are accepted and retained by the trusted import command'
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

set local role postgres;
create temporary table v1_b4_commercial_payloads as
select jsonb_build_object(
  'group_id', custom_group_id,
  'expected_version', 2,
  'worksheet_title', 'Admin commercial workbook',
  'columns', jsonb_build_array(
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000020',
      'heading', 'Description', 'display_order', 1,
      'canonical_field', 'description', 'is_commercial', false
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000021',
      'heading', 'Unit Cost', 'display_order', 2,
      'canonical_field', 'unit_cost', 'is_commercial', true
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000022',
      'heading', 'Total Cost', 'display_order', 3,
      'canonical_field', 'total_cost', 'is_commercial', true
    ),
    jsonb_build_object(
      'id', '41000000-0000-4000-8000-000000000023',
      'heading', 'Operating Cost Index', 'display_order', 4,
      'canonical_field', null, 'is_commercial', false
    )
  ),
  'rows', jsonb_build_array(jsonb_build_object(
    'id', '42000000-0000-4000-8000-000000000020',
    'display_order', 1,
    'raw_values', jsonb_build_object(
      '41000000-0000-4000-8000-000000000020', 'Imported fan',
      '41000000-0000-4000-8000-000000000021', '125.50',
      '41000000-0000-4000-8000-000000000022', '251.00',
      '41000000-0000-4000-8000-000000000023', 'OCI-7'
    )
  )),
  'source', jsonb_build_object(
    'file_name', 'commercial.xlsx',
    'worksheet_name', 'BOQ',
    'header_row_number', 1,
    'header_row_numbers', jsonb_build_array(1),
    'header_hierarchy', jsonb_build_array(
      jsonb_build_object('source_index', 0, 'labels', jsonb_build_array('Description')),
      jsonb_build_object('source_index', 1, 'labels', jsonb_build_array('Unit Cost')),
      jsonb_build_object('source_index', 2, 'labels', jsonb_build_array('Total Cost')),
      jsonb_build_object('source_index', 3, 'labels', jsonb_build_array('Operating Cost Index'))
    )
  )
) as payload
from v1_b4_targets;
grant select on table v1_b4_commercial_payloads to authenticated;

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

select lives_ok(
  $$select public.v1_import_boq_worksheet(
    (select payload from v1_b4_commercial_payloads),
    '40000000-0000-4000-8000-000000000009'::uuid
  )$$,
  'An authorized Admin imports canonical costs through protected commercial columns'
);

set local role postgres;
select is(
  (
    select concat_ws(
      '|',
      commercial_values ->> '41000000-0000-4000-8000-000000000021',
      commercial_values ->> '41000000-0000-4000-8000-000000000022'
    )
    from public.v1_boq_rows
    where id = '42000000-0000-4000-8000-000000000020'
  ),
  '125.50|251.00',
  'Canonical cost values are stored only in the protected commercial map'
);

select ok(
  (
    select not (raw_values ? '41000000-0000-4000-8000-000000000021')
      and not (raw_values ? '41000000-0000-4000-8000-000000000022')
      and raw_values ->> '41000000-0000-4000-8000-000000000023' = 'OCI-7'
    from public.v1_boq_rows
    where id = '42000000-0000-4000-8000-000000000020'
  ),
  'Arbitrary technical values remain operational while canonical costs do not leak there'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  (
    select public.v1_get_boq_worksheet(custom_group_id)
      #>> '{rows,0,raw_values,41000000-0000-4000-8000-000000000021}'
    from v1_b4_targets
  ),
  '125.50',
  'An authorized commercial projection contains the imported Unit Cost value'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (select custom_group_id from v1_b4_targets),
      'expected_version', 3,
      'worksheet_title', 'Malicious worksheet',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000024',
        'heading', 'Hidden cost bypass', 'display_order', 1,
        'canonical_field', 'unit_cost', 'is_commercial', false
      )),
      'rows', '[]'::jsonb,
      'reason', 'Attempt cost reclassification'
    ),
    '40000000-0000-4000-8000-000000000010'::uuid
  )$$,
  '22023',
  'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION',
  'The trusted save command rejects canonical Unit Cost disguised as operational'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (select custom_group_id from v1_b4_targets),
      'expected_version', 3,
      'worksheet_title', 'Omitted save mapping',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000028',
        'heading', 'Total Cost', 'display_order', 1,
        'canonical_field', null, 'is_commercial', false
      )),
      'rows', jsonb_build_array(jsonb_build_object(
        'id', '42000000-0000-4000-8000-000000000028',
        'display_order', 1,
        'raw_values', jsonb_build_object(
          '41000000-0000-4000-8000-000000000028', '999.00'
        )
      )),
      'reason', 'Attempt omitted cost mapping'
    ),
    '40000000-0000-4000-8000-000000000014'::uuid
  )$$,
  '22023',
  'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION',
  'Server-owned heading classification also protects the direct save command'
);

set local role postgres;
insert into public.v1_boq_columns (
  id, group_id, heading, display_order, canonical_field, is_commercial,
  created_by_auth_user_id
)
select
  source.id,
  target.repair_group_id,
  source.heading,
  source.display_order,
  source.canonical_field,
  false,
  '10000000-0000-4000-8000-000000000001'::uuid
from v1_b4_targets target
cross join (values
  (
    '41000000-0000-4000-8000-000000000040'::uuid,
    'Description'::text,
    1,
    'description'::text
  ),
  (
    '41000000-0000-4000-8000-000000000041'::uuid,
    'Unit Cost'::text,
    2,
    null::text
  ),
  (
    '41000000-0000-4000-8000-000000000042'::uuid,
    'Operating Cost Index'::text,
    3,
    null::text
  )
) as source(id, heading, display_order, canonical_field);

insert into public.v1_boq_rows (
  id, group_id, display_order, raw_values, commercial_values,
  created_by_auth_user_id
)
select
  '42000000-0000-4000-8000-000000000040'::uuid,
  repair_group_id,
  1,
  jsonb_build_object(
    '41000000-0000-4000-8000-000000000040', 'Legacy imported fan',
    '41000000-0000-4000-8000-000000000041', '999.00',
    '41000000-0000-4000-8000-000000000042', 'OCI-legacy'
  ),
  jsonb_build_object(
    '41000000-0000-4000-8000-000000000041', '1000.00'
  ),
  '10000000-0000-4000-8000-000000000001'::uuid
from v1_b4_targets;

select throws_ok(
  $$select public.v1_reclassify_legacy_boq_commercial_columns()$$,
  '22023',
  'V1_BOQ_COMMERCIAL_RECLASSIFICATION_VALUE_CONFLICT',
  'Legacy remediation preflight rejects conflicting raw/commercial values'
);

select ok(
  (
    select row_record.raw_values
        ->> '41000000-0000-4000-8000-000000000041' = '999.00'
      and row_record.commercial_values
        ->> '41000000-0000-4000-8000-000000000041' = '1000.00'
      and row_record.record_version = 1
      and not cost_column.is_commercial
      and cost_column.record_version = 1
      and group_record.record_version = 1
    from public.v1_boq_rows row_record
    join public.v1_boq_columns cost_column
      on cost_column.id = '41000000-0000-4000-8000-000000000041'
    join public.v1_boq_groups group_record
      on group_record.id = row_record.group_id
    where row_record.id = '42000000-0000-4000-8000-000000000040'
  ),
  'Conflict preflight leaves all legacy values and versions untouched'
);

update public.v1_boq_rows
set commercial_values =
  commercial_values - '41000000-0000-4000-8000-000000000041'
where id = '42000000-0000-4000-8000-000000000040';

select is(
  public.v1_reclassify_legacy_boq_commercial_columns(),
  1,
  'Migration repair reclassifies one legacy group with an exact Unit Cost heading'
);

select is(
  (
    select commercial_values
      ->> '41000000-0000-4000-8000-000000000041'
    from public.v1_boq_rows
    where id = '42000000-0000-4000-8000-000000000040'
  ),
  '999.00',
  'Legacy Unit Cost value is moved without loss into commercial_values'
);

select ok(
  (
    select not (row_record.raw_values
        ? '41000000-0000-4000-8000-000000000041')
      and row_record.raw_values
        ->> '41000000-0000-4000-8000-000000000042' = 'OCI-legacy'
      and not technical_column.is_commercial
      and technical_column.canonical_field is null
    from public.v1_boq_rows row_record
    join public.v1_boq_columns technical_column
      on technical_column.id = '41000000-0000-4000-8000-000000000042'
    where row_record.id = '42000000-0000-4000-8000-000000000040'
  ),
  'Repair removes the raw cost key but retains broader technical cost heading and value'
);

select is(
  (
    select concat_ws(
      '|',
      group_record.record_version,
      cost_column.record_version,
      row_record.record_version
    )
    from public.v1_boq_groups group_record
    join public.v1_boq_columns cost_column
      on cost_column.group_id = group_record.id
      and cost_column.id = '41000000-0000-4000-8000-000000000041'
    join public.v1_boq_rows row_record
      on row_record.group_id = group_record.id
      and row_record.id = '42000000-0000-4000-8000-000000000040'
  ),
  '2|2|2',
  'Repair increments affected group, column and row versions exactly once'
);

select is(
  public.v1_reclassify_legacy_boq_commercial_columns(),
  0,
  'Legacy cost remediation is idempotent on the same installed data'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  (
    select public.v1_get_boq_worksheet(repair_group_id)
      #>> '{rows,0,raw_values,41000000-0000-4000-8000-000000000041}'
    from v1_b4_targets
  ),
  '999.00',
  'Admin projection retains visibility of the remediated legacy Unit Cost'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select ok(
  (
    select jsonb_array_length(
        public.v1_get_boq_worksheet(repair_group_id) -> 'columns'
      ) = 2
      and not ((
        public.v1_get_boq_worksheet(repair_group_id)
          #> '{rows,0,raw_values}'
      ) ? '41000000-0000-4000-8000-000000000041')
      and public.v1_get_boq_worksheet(repair_group_id)
        #>> '{rows,0,raw_values,41000000-0000-4000-8000-000000000042}'
        = 'OCI-legacy'
    from v1_b4_targets
  ),
  'Project Engineer projection redacts remediated cost while retaining technical cost index'
);
select is(
  (
    select jsonb_array_length(
      public.v1_get_boq_worksheet(custom_group_id) -> 'columns'
    ) from v1_b4_targets
  ),
  2,
  'Project Engineer projection omits both imported commercial columns'
);

select ok(
  (
    select not ((
      public.v1_get_boq_worksheet(custom_group_id)
        #> '{rows,0,raw_values}'
    ) ? '41000000-0000-4000-8000-000000000021')
    and not ((
      public.v1_get_boq_worksheet(custom_group_id)
        #> '{rows,0,raw_values}'
    ) ? '41000000-0000-4000-8000-000000000022')
    from v1_b4_targets
  ),
  'Project Engineer row projection contains no commercial value keys'
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select worksheet_group_id from v1_b4_targets),
      'expected_version', 3,
      'worksheet_title', 'Disguised cost import',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000025',
        'heading', 'Unit Cost', 'display_order', 1,
        'canonical_field', 'unit_cost', 'is_commercial', false
      )),
      'rows', '[]'::jsonb,
      'source', jsonb_build_object(
        'file_name', 'bypass.xlsx', 'worksheet_name', 'BOQ',
        'header_row_number', 1, 'header_row_numbers', jsonb_build_array(1),
        'header_hierarchy', jsonb_build_array(jsonb_build_object(
          'source_index', 0, 'labels', jsonb_build_array('Unit Cost')
        ))
      )
    ),
    '40000000-0000-4000-8000-000000000011'::uuid
  )$$,
  '22023',
  'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION',
  'The trusted import rejects a canonical cost marked non-commercial'
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select worksheet_group_id from v1_b4_targets),
      'expected_version', 3,
      'worksheet_title', 'Omitted cost mapping',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000027',
        'heading', 'Unit Cost', 'display_order', 1,
        'canonical_field', null, 'is_commercial', false
      )),
      'rows', jsonb_build_array(jsonb_build_object(
        'id', '42000000-0000-4000-8000-000000000027',
        'display_order', 1,
        'raw_values', jsonb_build_object(
          '41000000-0000-4000-8000-000000000027', '999.00'
        )
      )),
      'source', jsonb_build_object(
        'file_name', 'omitted.xlsx', 'worksheet_name', 'BOQ',
        'header_row_number', 1, 'header_row_numbers', jsonb_build_array(1),
        'header_hierarchy', jsonb_build_array(jsonb_build_object(
          'source_index', 0, 'labels', jsonb_build_array('Unit Cost')
        ))
      )
    ),
    '40000000-0000-4000-8000-000000000013'::uuid
  )$$,
  '22023',
  'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION',
  'Server-owned heading classification rejects Unit Cost when canonical mapping is omitted'
);

select throws_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select worksheet_group_id from v1_b4_targets),
      'expected_version', 3,
      'worksheet_title', 'Unauthorized commercial import',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '41000000-0000-4000-8000-000000000026',
        'heading', 'Total Cost', 'display_order', 1,
        'canonical_field', 'total_cost', 'is_commercial', true
      )),
      'rows', '[]'::jsonb,
      'source', jsonb_build_object(
        'file_name', 'denied.xlsx', 'worksheet_name', 'BOQ',
        'header_row_number', 1, 'header_row_numbers', jsonb_build_array(1),
        'header_hierarchy', jsonb_build_array(jsonb_build_object(
          'source_index', 0, 'labels', jsonb_build_array('Total Cost')
        ))
      )
    ),
    '40000000-0000-4000-8000-000000000012'::uuid
  )$$,
  '42501',
  'V1_BOQ_COMMERCIAL_IMPORT_DENIED',
  'Project Engineer cannot import a correctly classified commercial column'
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
