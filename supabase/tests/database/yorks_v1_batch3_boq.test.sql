begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(22);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.v1_boq_columns'::regclass)
  and (select relrowsecurity from pg_class where oid = 'public.v1_boq_rows'::regclass),
  'Batch 3 BOQ columns and rows enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_boq_columns', 'select')
  and not has_table_privilege('authenticated', 'public.v1_boq_rows', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_boq_rows', 'update'),
  'Clients have no direct BOQ column or row table access'
);

select ok(
  has_function_privilege('authenticated', 'public.v1_list_boq_groups(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.v1_get_boq_worksheet(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.v1_save_boq_worksheet(jsonb,uuid)', 'execute')
  and not has_function_privilege(
    'authenticated', 'public.v1_validate_boq_values(jsonb,uuid,boolean)', 'execute'
  ),
  'Only BOQ projections and trusted commands are client-callable'
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
      "project_ref":"B3-BOQ-001",
      "name":"BOQ Worksheet Project",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"b3","name":"BOQ Building"}],
      "attachments":[]
    }'::jsonb,
    '30000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates a project with the frozen BOQ group set'
);

select is(
  (
    select count(*) from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and not group_record.is_custom
  ),
  58::bigint,
  'AT-02: exactly 29 default groups exist independently for Common and the building'
);

select is(
  jsonb_array_length(public.v1_list_boq_groups(
    (select id from public.v1_projects where project_ref = 'B3-BOQ-001')
  )),
  29,
  'Authorised Project Engineer receives the ordered BOQ folder projection'
);

select lives_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select group_record.id from public.v1_boq_groups group_record
        join public.v1_projects project on project.id = group_record.project_id
        where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
          and group_record.scope_id = (
            select scope.id from public.v1_project_scopes scope
            where scope.project_id = project.id and scope.scope_kind = 'common'
          )
      ),
      'expected_version', 1,
      'worksheet_title', 'MSD Equipment Schedule',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'id', '31000000-0000-4000-8000-000000000001',
          'heading', 'Item Description', 'display_order', 1,
          'canonical_field', 'description', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', '31000000-0000-4000-8000-000000000002',
          'heading', 'Model / Tag', 'display_order', 2,
          'canonical_field', 'planning_model_tag', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', '31000000-0000-4000-8000-000000000003',
          'heading', 'Air flow (L/s)', 'display_order', 3,
          'canonical_field', null, 'is_commercial', false
        )
      ),
      'rows', jsonb_build_array(
        jsonb_build_object(
          'id', '32000000-0000-4000-8000-000000000001',
          'display_order', 1,
          'raw_values', jsonb_build_object(
            '31000000-0000-4000-8000-000000000001', 'Motorized Smoke Damper',
            '31000000-0000-4000-8000-000000000002', 'MSD-01A',
            '31000000-0000-4000-8000-000000000003', 708
          )
        ),
        jsonb_build_object(
          'id', '32000000-0000-4000-8000-000000000002',
          'display_order', 2,
          'raw_values', jsonb_build_object(
            '31000000-0000-4000-8000-000000000001', 'Volume Control Damper',
            '31000000-0000-4000-8000-000000000002', 'VCD-02',
            '31000000-0000-4000-8000-000000000003', 450
          )
        )
      ),
      'reason', 'Initial direct worksheet entry'
    ),
    '30000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Engineer saves ordered arbitrary BOQ columns and rows atomically'
);

select is(
  (
    select public.v1_get_boq_worksheet(group_record.id) #>> '{group,worksheet_title}'
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ),
  'MSD Equipment Schedule',
  'Worksheet title round-trips through the role-safe projection'
);

select is(
  (
    select jsonb_array_length(public.v1_get_boq_worksheet(group_record.id) -> 'columns')
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ),
  3,
  'Dynamic worksheet returns all active operational columns'
);

select is(
  (
    select public.v1_get_boq_worksheet(group_record.id)
      #>> '{rows,0,canonical_values,planning_model_tag}'
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ),
  'MSD-01A',
  'Planning model/tag maps separately from a receipt serial number'
);

select is(
  (
    select public.v1_get_boq_worksheet(group_record.id)
      #>> '{rows,0,raw_values,31000000-0000-4000-8000-000000000003}'
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ),
  '708',
  'Arbitrary technical values survive the worksheet save and reload'
);

select lives_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select group_record.id from public.v1_boq_groups group_record
        join public.v1_projects project on project.id = group_record.project_id
        where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
          and group_record.scope_id = (
            select scope.id from public.v1_project_scopes scope
            where scope.project_id = project.id and scope.scope_kind = 'common'
          )
      ),
      'expected_version', 2,
      'worksheet_title', 'MSD Equipment Schedule',
      'columns', jsonb_build_array(
        jsonb_build_object(
          'id', '31000000-0000-4000-8000-000000000001',
          'heading', 'Item Description', 'display_order', 1,
          'canonical_field', 'description', 'is_commercial', false
        ),
        jsonb_build_object(
          'id', '31000000-0000-4000-8000-000000000002',
          'heading', 'Model / Tag', 'display_order', 2,
          'canonical_field', 'planning_model_tag', 'is_commercial', false
        )
      ),
      'rows', jsonb_build_array(
        jsonb_build_object(
          'id', '32000000-0000-4000-8000-000000000001', 'display_order', 1,
          'raw_values', jsonb_build_object(
            '31000000-0000-4000-8000-000000000001', 'Motorized Smoke Damper',
            '31000000-0000-4000-8000-000000000002', 'MSD-01A',
            '31000000-0000-4000-8000-000000000003', 708
          )
        ),
        jsonb_build_object(
          'id', '32000000-0000-4000-8000-000000000002', 'display_order', 2,
          'raw_values', jsonb_build_object(
            '31000000-0000-4000-8000-000000000001', 'Volume Control Damper',
            '31000000-0000-4000-8000-000000000002', 'VCD-02',
            '31000000-0000-4000-8000-000000000003', 450
          )
        )
      ),
      'reason', 'Remove obsolete airflow heading'
    ),
    '30000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Deleting a populated column archives it as a worksheet revision'
);

select ok(
  (
    select public.v1_get_boq_worksheet(group_record.id)
      #>> '{rows,0,raw_values,31000000-0000-4000-8000-000000000003}'
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ) = '708',
  'Column deletion preserves legacy row values instead of discarding them'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select group_record.id from public.v1_boq_groups group_record
        join public.v1_projects project on project.id = group_record.project_id
        where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
          and group_record.scope_id = (
            select scope.id from public.v1_project_scopes scope
            where scope.project_id = project.id and scope.scope_kind = 'common'
          )
      ),
      'expected_version', 2,
      'worksheet_title', 'Stale save', 'columns', '[]'::jsonb,
      'rows', '[]'::jsonb, 'reason', 'Stale client'
    ),
    '30000000-0000-4000-8000-000000000004'::uuid
  )$$,
  '40001',
  'V1_BOQ_VERSION_CONFLICT',
  'Stale worksheet writers receive a conflict instead of overwriting changes'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select group_record.id from public.v1_boq_groups group_record
        join public.v1_projects project on project.id = group_record.project_id
        where project.project_ref = 'B3-BOQ-001' and group_record.display_order = 3
          and group_record.scope_id = (
            select scope.id from public.v1_project_scopes scope
            where scope.project_id = project.id and scope.scope_kind = 'common'
          )
      ),
      'expected_version', 3,
      'worksheet_title', 'No cost exposure',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '31000000-0000-4000-8000-000000000001',
        'heading', 'Item Description', 'display_order', 1,
        'canonical_field', 'description', 'is_commercial', false
      ), jsonb_build_object(
        'id', '31000000-0000-4000-8000-000000000009',
        'heading', 'Unit Cost', 'display_order', 2,
        'canonical_field', null, 'is_commercial', true
      )),
      'rows', '[]'::jsonb, 'reason', 'Attempt commercial input'
    ),
    '30000000-0000-4000-8000-000000000005'::uuid
  )$$,
  '42501',
  'V1_BOQ_COMMERCIAL_COLUMN_DENIED',
  'Project Engineer cannot introduce a commercial BOQ column'
);

select lives_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B3-BOQ-001'),
      'scope_id', (
        select scope.id from public.v1_project_scopes scope
        join public.v1_projects project on project.id = scope.project_id
        where project.project_ref = 'B3-BOQ-001' and scope.scope_kind = 'common'
      ),
      'name', 'Project-specific Dampers'
    ),
    '30000000-0000-4000-8000-000000000006'::uuid
  )$$,
  'Engineer can create a project-specific BOQ group'
);

select is(
  (
    select display_order from public.v1_boq_groups
    where project_id = (select id from public.v1_projects where project_ref = 'B3-BOQ-001')
      and name = 'Project-specific Dampers'
  ),
  30,
  'Custom group is ordered after the frozen 29 defaults'
);

select lives_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (
        select id from public.v1_boq_groups
        where name = 'Project-specific Dampers'
      ),
      'expected_version', 1
    ),
    '30000000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Custom group uses an auditable archive rather than hard delete'
);

select is(
  jsonb_array_length(public.v1_list_boq_groups(
    (select id from public.v1_projects where project_ref = 'B3-BOQ-001')
  )),
  29,
  'Archived custom group leaves the active folder projection unchanged'
);

set local role postgres;
create temporary table v1_b3_targets as
select
  project.id as project_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'common'
  ) as common_scope_id,
  (
    select group_record.id from public.v1_boq_groups group_record
    where group_record.project_id = project.id and group_record.display_order = 3
      and group_record.scope_id = (
        select scope.id from public.v1_project_scopes scope
        where scope.project_id = project.id and scope.scope_kind = 'common'
      )
  ) as worksheet_group_id
from public.v1_projects project
where project.project_ref = 'B3-BOQ-001';
grant select on table v1_b3_targets to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from v1_b3_targets),
      'scope_id', (select common_scope_id from v1_b3_targets),
      'name', 'Procurement denied'
    ),
    '30000000-0000-4000-8000-000000000008'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'AT-25: Procurement cannot create a BOQ group through its direct RPC'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select worksheet_group_id from v1_b3_targets
      ),
      'expected_version', 3,
      'worksheet_title', 'Procurement overwrite', 'columns', '[]'::jsonb,
      'rows', '[]'::jsonb, 'reason', 'Denied'
    ),
    '30000000-0000-4000-8000-000000000009'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'AT-25: Procurement cannot change BOQ columns or rows'
);

select throws_ok(
  $$insert into public.v1_boq_rows (
    id, group_id, display_order, created_by_auth_user_id
  ) values (
    '32000000-0000-4000-8000-000000000009'::uuid,
    (select worksheet_group_id from v1_b3_targets),
    99, '10000000-0000-4000-8000-000000000003'::uuid
  )$$,
  '42501',
  null,
  'AT-25: Procurement cannot bypass BOQ command authority through a table write'
);

select * from finish();

rollback;
