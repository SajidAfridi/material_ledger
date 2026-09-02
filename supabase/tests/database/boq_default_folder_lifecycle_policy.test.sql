begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  not (
    select is_active
    from public.v1_boq_group_templates
    where template_key = 'ac_units'
  )
  and (
    select allows_scope_archive
    from public.v1_boq_group_templates
    where template_key = 'ac_units'
  ),
  'AC Units is inactive for future seeds but lifecycle-manageable when retained'
);

select ok(
  (
    select is_active and allows_scope_archive
    from public.v1_boq_group_templates
    where template_key = 'workshop_materials'
  ),
  'Workshop Materials remains the active seed and is lifecycle-manageable'
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
      "project_ref":"BOQ-LIFECYCLE-001",
      "name":"Default folder lifecycle",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"tower-a","name":"Tower A"}],
      "attachments":[]
    }'::jsonb,
    'fb100000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates a project under the revised seed policy'
);

set local role postgres;
create temporary table boq_lifecycle_targets as
select
  project.id as project_id,
  scope.id as scope_id,
  (
    select group_record.id
    from public.v1_boq_groups group_record
    join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.scope_id = scope.id
      and template.template_key = 'workshop_materials'
      and not group_record.is_archived
  ) as workshop_group_id,
  null::uuid as ac_group_id
from public.v1_projects project
join public.v1_project_scopes scope
  on scope.project_id = project.id and scope.scope_kind = 'common'
where project.project_ref = 'BOQ-LIFECYCLE-001';
grant select, update on table boq_lifecycle_targets to authenticated;

select is(
  (
    select count(*)
    from public.v1_boq_groups group_record
    join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.scope_id = (
      select scope_id from boq_lifecycle_targets
    )
      and template.template_key = 'workshop_materials'
      and not group_record.is_archived
  ),
  1::bigint,
  'The new Common scope receives one Workshop Materials folder'
);

select is(
  (
    select count(*)
    from public.v1_boq_groups group_record
    join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.project_id = (
      select project_id from boq_lifecycle_targets
    )
      and template.template_key = 'ac_units'
  ),
  0::bigint,
  'The new Common scope does not receive an AC Units folder'
);

insert into public.v1_boq_groups (
  project_id, scope_id, template_id, name, worksheet_title, display_order,
  is_custom, created_by_auth_user_id
)
select
  target.project_id,
  target.scope_id,
  template.id,
  'AC Units',
  'AC Units',
  20,
  false,
  '10000000-0000-4000-8000-000000000001'::uuid
from boq_lifecycle_targets target
join public.v1_boq_group_templates template
  on template.template_key = 'ac_units';

update boq_lifecycle_targets
set ac_group_id = (
  select group_record.id
  from public.v1_boq_groups group_record
  join public.v1_boq_group_templates template
    on template.id = group_record.template_id
  where group_record.scope_id = boq_lifecycle_targets.scope_id
    and template.template_key = 'ac_units'
);

insert into public.v1_boq_columns (
  id, group_id, heading, display_order, canonical_field,
  created_by_auth_user_id
) values (
  'fb120000-0000-4000-8000-000000000001',
  (select ac_group_id from boq_lifecycle_targets),
  'Item Description',
  1,
  'description',
  '10000000-0000-4000-8000-000000000001'::uuid
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (
    select item ->> 'can_archive'
    from jsonb_array_elements(public.v1_list_boq_folder_management(
      (select project_id from boq_lifecycle_targets),
      (select scope_id from boq_lifecycle_targets),
      true
    )) item
    where item ->> 'id' = (select ac_group_id::text from boq_lifecycle_targets)
  ),
  'true',
  'A retained AC Units folder exposes server-confirmed archive authority'
);

select is(
  public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select ac_group_id from boq_lifecycle_targets),
      'expected_version', 1,
      'name', 'Site equipment package',
      'reason', 'Use the current project filing name'
    ),
    'fb100000-0000-4000-8000-000000000002'::uuid
  ) ->> 'name',
  'Site equipment package',
  'A retained AC Units folder can be renamed without changing identity'
);

select lives_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select ac_group_id from boq_lifecycle_targets),
      'expected_version', 2,
      'reason', 'This scope no longer uses the package'
    ),
    'fb100000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A retained AC Units folder can be archived without deleting history'
);

select lives_ok(
  $$select public.v1_restore_boq_group(
    jsonb_build_object(
      'group_id', (select ac_group_id from boq_lifecycle_targets),
      'expected_version', 3,
      'reason', 'The package is active again'
    ),
    'fb100000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A retained AC Units folder can be restored with the same identity'
);

set local role postgres;
select ok(
  (
    select not group_record.is_archived
      and group_record.name = 'Site equipment package'
      and group_record.template_id = template.id
      and exists (
        select 1 from public.v1_boq_columns column_record
        where column_record.group_id = group_record.id
          and column_record.id = 'fb120000-0000-4000-8000-000000000001'
      )
    from public.v1_boq_groups group_record
    join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.id = (select ac_group_id from boq_lifecycle_targets)
      and template.template_key = 'ac_units'
  ),
  'Rename/archive/restore preserves the AC Units template and child history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select workshop_group_id from boq_lifecycle_targets),
      'expected_version', 1,
      'reason', 'Unassigned negative test'
    ),
    'fb100000-0000-4000-8000-000000000005'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'An unassigned Site Engineer cannot archive the default folder'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select workshop_group_id from boq_lifecycle_targets),
      'expected_version', 1,
      'reason', 'Procurement negative test'
    ),
    'fb100000-0000-4000-8000-000000000006'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'Procurement cannot archive Workshop Materials'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select workshop_group_id from boq_lifecycle_targets),
      'expected_version', 1,
      'reason', 'Admin lifecycle positive test'
    ),
    'fb100000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Admin may archive Workshop Materials through the protected command'
);

select lives_ok(
  $$select public.v1_restore_boq_group(
    jsonb_build_object(
      'group_id', (select workshop_group_id from boq_lifecycle_targets),
      'expected_version', 2,
      'reason', 'Admin restores the retained default'
    ),
    'fb100000-0000-4000-8000-000000000008'::uuid
  )$$,
  'Admin may restore Workshop Materials with the same stable identity'
);

set local role postgres;
select is(
  (
    select count(*)
    from public.v1_audit_events
    where entity_id = (select ac_group_id from boq_lifecycle_targets)
      and event_type in (
        'boq_group_renamed', 'boq_group_archived', 'boq_group_restored'
      )
  ),
  3::bigint,
  'AC Units lifecycle actions retain one append-only audit event each'
);

select * from finish();
rollback;
