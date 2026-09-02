begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_list_boq_folder_management(uuid,uuid,boolean)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_rename_boq_group(jsonb,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_restore_boq_group(jsonb,uuid)', 'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_rename_boq_group(jsonb,uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.v1_can_manage_boq_folders(uuid)', 'execute'
  ),
  'Only authenticated clients receive the reviewed folder-management RPC surface'
);

select is(
  (
    select authorization_mode
    from public.v1_capability_catalog
    where capability_key = 'boq.manage_folders'
  ),
  'enforced',
  'boq.manage_folders is an authoritative protected consumer'
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
      "project_ref":"BOQ-SCOPE-LOCAL-001",
      "name":"Scope-local BOQ folders",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"tower-a","name":"Tower A"}],
      "attachments":[]
    }'::jsonb,
    'fa100000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates Common and one building with independent defaults'
);

set local role postgres;
create temporary table boq_scope_local_targets as
select
  project.id as project_id,
  (
    select scope.id
    from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'common'
  ) as common_scope_id,
  (
    select scope.id
    from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_code = 'tower-a'
  ) as tower_scope_id,
  (
    select group_record.id
    from public.v1_boq_groups group_record
    join public.v1_project_scopes scope on scope.id = group_record.scope_id
    where group_record.project_id = project.id
      and scope.scope_kind = 'common'
      and not group_record.is_custom
      and not group_record.is_archived
  ) as common_workshop_id
from public.v1_projects project
where project.project_ref = 'BOQ-SCOPE-LOCAL-001';
grant select, update on table boq_scope_local_targets to authenticated;

select is(
  (
    select count(*)
    from public.v1_boq_groups
    where project_id = (select project_id from boq_scope_local_targets)
      and not is_archived
  ),
  2::bigint,
  'Each initial scope receives only its own Workshop Materials foundation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  jsonb_array_length(public.v1_list_boq_folder_management(
    (select project_id from boq_scope_local_targets),
    (select common_scope_id from boq_scope_local_targets),
    true
  )),
  1,
  'Protected management read returns only the selected real scope'
);

select is(
  (
    select item ->> 'template_key'
    from jsonb_array_elements(public.v1_list_boq_folder_management(
      (select project_id from boq_scope_local_targets),
      (select common_scope_id from boq_scope_local_targets),
      true
    )) item
  ),
  'workshop_materials',
  'The visible default label remains separate from the protected template identity'
);

select lives_ok(
  $$select public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select common_workshop_id from boq_scope_local_targets),
      'expected_version', 1,
      'name', 'Common procurement schedule',
      'reason', 'Use the project team wording for Common'
    ),
    'fa100000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Workshop Materials can be renamed in Common without changing its identity'
);

set local role postgres;
select ok(
  (
    select group_record.name = 'Common procurement schedule'
      and group_record.worksheet_title = 'Workshop Materials'
      and template.template_key = 'workshop_materials'
    from public.v1_boq_groups group_record
    join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.id = (
      select common_workshop_id from boq_scope_local_targets
    )
  ),
  'Rename changes only the folder label and preserves worksheet/template identity'
);

select is(
  (
    select name
    from public.v1_boq_groups
    where scope_id = (select tower_scope_id from boq_scope_local_targets)
      and not is_custom and not is_archived
  ),
  'Workshop Materials',
  'Renaming Common does not rename the building folder'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select common_workshop_id from boq_scope_local_targets),
      'expected_version', 2,
      'name', 'Missing reason'
    ),
    'fa100000-0000-4000-8000-000000000003'::uuid
  )$$,
  '22023', 'V1_BOQ_RENAME_PAYLOAD_INVALID',
  'Rename requires an auditable reason'
);

select lives_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from boq_scope_local_targets),
      'scope_id', (select tower_scope_id from boq_scope_local_targets),
      'name', 'Tower A specialist package'
    ),
    'fa100000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Engineer creates a custom folder only in Tower A'
);

set local role postgres;
alter table boq_scope_local_targets add column custom_group_id uuid;
update boq_scope_local_targets
set custom_group_id = (
  select id
  from public.v1_boq_groups
  where scope_id = boq_scope_local_targets.tower_scope_id
    and name = 'Tower A specialist package'
    and not is_archived
);

select is(
  (
    select count(*)
    from public.v1_boq_groups
    where project_id = (select project_id from boq_scope_local_targets)
      and name = 'Tower A specialist package'
      and not is_archived
  ),
  1::bigint,
  'Custom folder creation does not materialize sibling shells'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name
) values (
  'fa120000-0000-4000-8000-000000000001',
  (select project_id from boq_scope_local_targets),
  'building', 'tower-b', 'Tower B'
);

select is(
  (
    select count(*)
    from public.v1_boq_groups
    where scope_id = 'fa120000-0000-4000-8000-000000000001'
      and not is_archived
  ),
  1::bigint,
  'A future building receives only the frozen Workshop Materials foundation'
);

select is(
  (
    select count(*)
    from public.v1_boq_groups
    where scope_id = 'fa120000-0000-4000-8000-000000000001'
      and is_custom
  ),
  0::bigint,
  'A future building never inherits another scope custom folder'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$update public.v1_boq_groups
    set name = 'Direct table bypass'
    where id = (select custom_group_id from boq_scope_local_targets)$$,
  '42501', 'permission denied for table v1_boq_groups',
  'Authenticated clients cannot bypass the trusted commands through table APIs'
);

select throws_ok(
  $$select public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select custom_group_id from boq_scope_local_targets),
      'expected_version', 99,
      'name', 'Stale rename',
      'reason', 'Exercise stale protection'
    ),
    'fa100000-0000-4000-8000-000000000005'::uuid
  )$$,
  '40001', 'V1_BOQ_VERSION_CONFLICT',
  'Folder rename rejects a stale expected version'
);

select is(
  public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select custom_group_id from boq_scope_local_targets),
      'expected_version', 1,
      'name', 'Tower A installation package',
      'reason', 'Align the folder with site terminology'
    ),
    'fa100000-0000-4000-8000-000000000006'::uuid
  ) ->> 'name',
  'Tower A installation package',
  'Custom folder rename returns the selected scope projection'
);

select is(
  public.v1_rename_boq_group(
    jsonb_build_object(
      'group_id', (select custom_group_id from boq_scope_local_targets),
      'expected_version', 1,
      'name', 'Tower A installation package',
      'reason', 'Align the folder with site terminology'
    ),
    'fa100000-0000-4000-8000-000000000006'::uuid
  ) ->> 'record_version',
  '2',
  'Rename retry is idempotent and does not advance the version twice'
);

select is(
  (
    select item ->> 'can_archive'
    from jsonb_array_elements(public.v1_list_boq_folder_management(
      (select project_id from boq_scope_local_targets),
      (select common_scope_id from boq_scope_local_targets),
      true
    )) item
    where item ->> 'id' = (
      select common_workshop_id::text from boq_scope_local_targets
    )
  ),
  'true',
  'Workshop Materials exposes server-confirmed archive authority'
);

select lives_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select common_workshop_id from boq_scope_local_targets),
      'expected_version', 2,
      'reason', 'Temporarily hide the Common default folder'
    ),
    'fa100000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Workshop Materials may be soft-archived after its visible rename'
);

select lives_ok(
  $$select public.v1_restore_boq_group(
    jsonb_build_object(
      'group_id', (select common_workshop_id from boq_scope_local_targets),
      'expected_version', 3,
      'reason', 'Return the retained Common default folder'
    ),
    'fa100000-0000-4000-8000-000000000011'::uuid
  )$$,
  'Workshop Materials restores with the same stable group identity'
);

select lives_ok(
  $$select public.v1_archive_boq_group(
    jsonb_build_object(
      'group_id', (select custom_group_id from boq_scope_local_targets),
      'expected_version', 2,
      'reason', 'Package is temporarily not in use'
    ),
    'fa100000-0000-4000-8000-000000000008'::uuid
  )$$,
  'A custom folder is soft-archived through the trusted command'
);

select is(
  (
    select item ->> 'can_restore'
    from jsonb_array_elements(public.v1_list_boq_folder_management(
      (select project_id from boq_scope_local_targets),
      (select tower_scope_id from boq_scope_local_targets),
      true
    )) item
    where item ->> 'id' = (select custom_group_id::text from boq_scope_local_targets)
  ),
  'true',
  'Management read retains the archived folder and exposes server-confirmed restore authority'
);

select is(
  jsonb_array_length(public.v1_list_boq_folder_management(
    (select project_id from boq_scope_local_targets),
    (select tower_scope_id from boq_scope_local_targets),
    false
  )),
  1,
  'Active-only management read hides the archived custom folder'
);

select lives_ok(
  $$select public.v1_restore_boq_group(
    jsonb_build_object(
      'group_id', (select custom_group_id from boq_scope_local_targets),
      'expected_version', 3,
      'reason', 'Package returned to the active scope'
    ),
    'fa100000-0000-4000-8000-000000000009'::uuid
  )$$,
  'Custom folder restore reactivates the same stable group'
);

set local role postgres;
select is(
  (
    select count(*)
    from public.v1_audit_events
    where entity_id in (
      (select common_workshop_id from boq_scope_local_targets),
      (select custom_group_id from boq_scope_local_targets)
    )
      and event_type in (
        'boq_group_renamed', 'boq_group_archived', 'boq_group_restored'
      )
  ),
  6::bigint,
  'Template and custom rename/archive/restore each produce one append-only audit event'
);

insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, reason,
  changed_by_auth_user_id
) values (
  'fa130000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'boq.manage_folders', 'deny', 'organization',
  'Folder-management custom denial test',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_list_boq_folder_management(
    (select project_id from boq_scope_local_targets),
    (select common_scope_id from boq_scope_local_targets),
    true
  )$$,
  '42501', 'V1_BOQ_FOLDER_MANAGEMENT_DENIED',
  'A custom denial overrides an otherwise eligible Project Engineer'
);

select throws_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from boq_scope_local_targets),
      'scope_id', (select common_scope_id from boq_scope_local_targets),
      'name', 'Denied folder'
    ),
    'fa100000-0000-4000-8000-000000000010'::uuid
  )$$,
  '42501', 'V1_BOQ_EDIT_DENIED',
  'The same custom denial blocks folder mutation commands'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_list_boq_folder_management(
    (select project_id from boq_scope_local_targets),
    (select tower_scope_id from boq_scope_local_targets),
    true
  )$$,
  '42501', 'V1_BOQ_FOLDER_MANAGEMENT_DENIED',
  'Procurement cannot acquire folder management through page visibility'
);

select * from finish();
rollback;
