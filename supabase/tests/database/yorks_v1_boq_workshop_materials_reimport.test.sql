begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

select is(
  (select count(*) from public.v1_boq_group_templates where is_active),
  1::bigint,
  'Only one BOQ seed template is active'
);

select is(
  (select display_name from public.v1_boq_group_templates where is_active),
  'Workshop Materials',
  'Workshop Materials is the universal BOQ seed folder'
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
      "project_ref":"BOQ-REIMPORT-001",
      "name":"BOQ Re-import Regression",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"workshop","name":"Workshop"}],
      "attachments":[]
    }'::jsonb,
    'b2300000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A project is created with Common and building BOQ scopes'
);

select is(
  (
    select jsonb_array_length(public.v1_list_boq_groups(project.id))
    from public.v1_projects project
    where project.project_ref = 'BOQ-REIMPORT-001'
  ),
  1,
  'The Common scope exposes only Workshop Materials'
);

select is(
  (
    select jsonb_array_length(public.v1_list_boq_groups_for_scope(
      project.id,
      scope_record.id
    ))
    from public.v1_projects project
    join public.v1_project_scopes scope_record
      on scope_record.project_id = project.id
    where project.project_ref = 'BOQ-REIMPORT-001'
      and scope_record.scope_kind = 'building'
  ),
  1,
  'Each building scope exposes only Workshop Materials'
);

set local role postgres;
create temporary table v1_boq_reimport_target as
select group_record.id as group_id
from public.v1_boq_groups group_record
join public.v1_projects project on project.id = group_record.project_id
join public.v1_project_scopes scope_record on scope_record.id = group_record.scope_id
where project.project_ref = 'BOQ-REIMPORT-001'
  and scope_record.scope_kind = 'common'
  and group_record.name = 'Workshop Materials';
grant select on table v1_boq_reimport_target to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select group_id from v1_boq_reimport_target),
      'expected_version', 1,
      'worksheet_title', 'Original Import',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000001',
          'heading', 'Description', 'display_order', 1,
          'canonical_field', 'description', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000002',
          'heading', 'Quantity', 'display_order', 2,
          'canonical_field', 'quantity', 'is_commercial', false
        )
      ),
      'rows', jsonb_build_array(jsonb_build_object(
        'id', 'b2320000-0000-4000-8000-000000000001',
        'display_order', 1,
        'raw_values', jsonb_build_object(
          'b2310000-0000-4000-8000-000000000001', 'Cable tray',
          'b2310000-0000-4000-8000-000000000002', 10
        )
      )),
      'source', jsonb_build_object(
        'file_name', 'original.xlsx', 'worksheet_name', 'BOQ',
        'header_row_number', 1
      )
    ),
    'b2330000-0000-4000-8000-000000000001'::uuid
  )$$,
  'The original worksheet imports'
);

select lives_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (select group_id from v1_boq_reimport_target),
      'expected_version', 2,
      'worksheet_title', 'Cleared Worksheet',
      'columns', '[]'::jsonb,
      'rows', '[]'::jsonb,
      'reason', 'User removed incorrect imported rows and columns'
    ),
    'b2330000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Deleting every imported row and column preserves an empty active snapshot'
);

select lives_ok(
  $$select public.v1_import_boq_worksheet(
    jsonb_build_object(
      'group_id', (select group_id from v1_boq_reimport_target),
      'expected_version', 3,
      'worksheet_title', 'Corrected Import',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000011',
          'heading', 'Item Description', 'display_order', 1,
          'canonical_field', 'description', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000012',
          'heading', 'Brand / Origin', 'display_order', 2,
          'canonical_field', 'brand_origin', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000013',
          'heading', 'Size', 'display_order', 3,
          'canonical_field', null, 'is_commercial', false
        )
      ),
      'rows', jsonb_build_array(
        jsonb_build_object(
          'id', 'b2320000-0000-4000-8000-000000000011',
          'display_order', 1,
          'raw_values', jsonb_build_object(
            'b2310000-0000-4000-8000-000000000011', 'Cable tray',
            'b2310000-0000-4000-8000-000000000012', 'Yorks',
            'b2310000-0000-4000-8000-000000000013', '300 mm'
          )
        ),
        jsonb_build_object(
          'id', 'b2320000-0000-4000-8000-000000000012',
          'display_order', 2,
          'raw_values', jsonb_build_object(
            'b2310000-0000-4000-8000-000000000011', 'Support channel',
            'b2310000-0000-4000-8000-000000000012', 'Local',
            'b2310000-0000-4000-8000-000000000013', '41 x 41'
          )
        )
      ),
      'source', jsonb_build_object(
        'file_name', 'corrected.xlsx', 'worksheet_name', 'Revised BOQ',
        'header_row_number', 2
      )
    ),
    'b2330000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A corrected import with fresh IDs and a changed structure succeeds'
);

set local role postgres;
select is(
  (select count(*) from public.v1_boq_columns
    where group_id = (select group_id from v1_boq_reimport_target)
      and not is_archived),
  3::bigint,
  'Only the three corrected columns are active'
);

select is(
  (select count(*) from public.v1_boq_rows
    where group_id = (select group_id from v1_boq_reimport_target)
      and not is_archived),
  2::bigint,
  'Only the two corrected rows are active'
);

select is(
  (select count(*) from public.v1_boq_columns
    where group_id = (select group_id from v1_boq_reimport_target)
      and is_archived),
  2::bigint,
  'The removed original columns remain archived as history'
);

select is(
  (select count(*) from public.v1_boq_rows
    where group_id = (select group_id from v1_boq_reimport_target)
      and is_archived),
  1::bigint,
  'The removed original row remains archived as history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (select group_id from v1_boq_reimport_target),
      'expected_version', 4,
      'worksheet_title', 'Invalid Duplicate Order',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000021',
          'heading', 'Description', 'display_order', 1,
          'canonical_field', 'description', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', 'b2310000-0000-4000-8000-000000000022',
          'heading', 'Size', 'display_order', 1,
          'canonical_field', null, 'is_commercial', false
        )
      ),
      'rows', '[]'::jsonb,
      'reason', 'Invalid duplicate order test'
    ),
    'b2330000-0000-4000-8000-000000000004'::uuid
  )$$,
  '22023',
  'V1_BOQ_COLUMN_ID_OR_ORDER_DUPLICATE',
  'Duplicate proposed column coordinates fail with a controlled validation error'
);

select is(
  (select record_version from public.v1_boq_groups
    where id = (select group_id from v1_boq_reimport_target)),
  4,
  'A rejected replacement leaves the committed worksheet version unchanged'
);

select * from finish();
rollback;
