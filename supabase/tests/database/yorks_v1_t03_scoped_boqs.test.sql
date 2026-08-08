begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(26);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_list_boq_groups_for_scope(uuid,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_assign_legacy_boq_group_scope(jsonb,uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.v1_seed_default_boq_groups_for_scope(uuid,uuid)', 'execute'
  ),
  'T03 exposes only the scoped BOQ projections and reconciliation command'
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
      "project_ref":"T03-R38-001",
      "name":"R38 Scoped BOQ Project",
      "parties":{},
      "initial_members":[],
      "buildings":[
        {"code":"df3w","name":"DF3W"},
        {"code":"df4w","name":"DF4W"}
      ],
      "attachments":[]
    }'::jsonb,
    'a3000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates Common plus two independent building BOQ scopes'
);

set local role postgres;
create temporary table v1_t03_targets as
select
  project.id as project_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'common'
  ) as common_scope_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_code = 'df3w'
  ) as df3w_scope_id,
  (
    select scope.id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_code = 'df4w'
  ) as df4w_scope_id
from public.v1_projects project
where project.project_ref = 'T03-R38-001';
grant select on table v1_t03_targets to authenticated;

select is(
  (
    select count(*) from public.v1_boq_groups group_record
    where group_record.project_id = (select project_id from v1_t03_targets)
      and not group_record.is_custom
  ),
  87::bigint,
  'New project materialises all 29 frozen folders independently in Common, DF3W and DF4W'
);

select ok(
  (
    select min(scope_group_count) = 29 and max(scope_group_count) = 29
    from (
      select scope_id, count(*) as scope_group_count
      from public.v1_boq_groups
      where project_id = (select project_id from v1_t03_targets)
        and not is_custom
      group by scope_id
    ) per_scope
  ),
  'Every physical/Common scope has exactly its own frozen folder structure'
);

select is(
  (
    select count(*) from public.v1_boq_groups
    where project_id = (select project_id from v1_t03_targets)
      and template_id = (
        select template_id from public.v1_boq_groups
        where project_id = (select project_id from v1_t03_targets)
        order by display_order
        limit 1
      )
  ),
  3::bigint,
  'The same default folder template has a separate persisted group in every scope'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  jsonb_array_length(public.v1_list_boq_groups_for_scope(
    (select project_id from v1_t03_targets), null
  )),
  87,
  'All returns a read-only aggregate containing every independent scope folder'
);

select is(
  jsonb_array_length(public.v1_list_boq_groups_for_scope(
    (select project_id from v1_t03_targets),
    (select df3w_scope_id from v1_t03_targets)
  )),
  29,
  'A selected building returns only its own 29 folders'
);

select is(
  jsonb_array_length(public.v1_list_boq_groups(
    (select project_id from v1_t03_targets)
  )),
  29,
  'The legacy one-argument BOQ projection remains a safe Common-only compatibility path'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select project_id from v1_t03_targets),
      'state', 'active',
      'expected_version', 1,
      'reason', 'T03 MR scope test'
    ),
    'a3000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Scoped project activates before controlled material-request testing'
);

select lives_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from v1_t03_targets),
      'scope_id', (select df3w_scope_id from v1_t03_targets),
      'name', 'T03 DF3W custom folder'
    ),
    'a3000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Engineer creates one project-wide folder definition from a selected scope'
);

set local role postgres;
alter table v1_t03_targets add column custom_group_id uuid;
update v1_t03_targets
set custom_group_id = (
  select id from public.v1_boq_groups
  where project_id = v1_t03_targets.project_id
    and name = 'T03 DF3W custom folder'
    and scope_id = v1_t03_targets.df3w_scope_id
);

select is(
  (
    select count(*) from public.v1_boq_groups
    where project_id = (select project_id from v1_t03_targets)
      and name = 'T03 DF3W custom folder'
      and not is_archived
  ),
  3::bigint,
  'The custom folder name is available independently in Common and every building'
);

select is(
  (
    select scope_id from public.v1_boq_groups
    where id = (select custom_group_id from v1_t03_targets)
  ),
  (select df3w_scope_id from v1_t03_targets),
  'The command still returns the selected building folder for repository compatibility'
);

select is(
  (
    select count(*)
    from public.v1_boq_rows row_record
    join public.v1_boq_groups group_record on group_record.id = row_record.group_id
    where group_record.project_id = (select project_id from v1_t03_targets)
      and group_record.name = 'T03 DF3W custom folder'
  ),
  0::bigint,
  'Project-wide folder creation never copies material rows between scopes'
);

select is(
  public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from v1_t03_targets),
      'scope_id', (select df3w_scope_id from v1_t03_targets),
      'name', 'T03 DF3W custom folder'
    ),
    'a3000000-0000-4000-8000-000000000003'::uuid
  ) ->> 'id',
  (select custom_group_id::text from v1_t03_targets),
  'Project-wide custom folder creation is idempotent for a command retry'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_create_boq_group(
    jsonb_build_object(
      'project_id', (select project_id from v1_t03_targets),
      'scope_id', (select df4w_scope_id from v1_t03_targets),
      'name', 'Procurement must not create BOQ folders'
    ),
    'a3000000-0000-4000-8000-000000000004'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'Procurement cannot create a custom folder through the scoped RPC'
);

set local role postgres;
alter table v1_t03_targets add column boq_group_id uuid;
update v1_t03_targets
set boq_group_id = (
  select id from public.v1_boq_groups
  where project_id = v1_t03_targets.project_id
    and scope_id = v1_t03_targets.df3w_scope_id
    and display_order = 1
);
insert into public.v1_boq_rows (
  id, group_id, display_order, raw_values, canonical_values,
  created_by_auth_user_id
) values (
  'a3100000-0000-4000-8000-000000000001'::uuid,
  (select boq_group_id from v1_t03_targets),
  1,
  '{}'::jsonb,
  '{"description":"DF3W Smoke Damper","quantity":"2","unit":"Nos"}'::jsonb,
  '10000000-0000-4000-8000-000000000001'::uuid
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_save_material_request_draft(
    jsonb_build_object(
      'request_id', 'a3200000-0000-4000-8000-000000000001',
      'expected_version', 0,
      'project_id', (select project_id from v1_t03_targets),
      'scope_id', (select df3w_scope_id from v1_t03_targets),
      'title', 'DF3W controlled request',
      'timing', 'normal',
      'scheduled_date', null,
      'delivery_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'id', 'a3300000-0000-4000-8000-000000000001',
        'display_order', 1,
        'source_kind', 'boq',
        'source_boq_group_id', (select boq_group_id from v1_t03_targets),
        'source_boq_row_id', 'a3100000-0000-4000-8000-000000000001',
        'item_description', 'DF3W Smoke Damper',
        'brand_origin', null,
        'technical_attributes', '{}'::jsonb,
        'requested_qty', '2',
        'unit', 'Nos'
      ))
    )
  )$$,
  'A building BOQ source saves into a draft for that same building'
);

select throws_ok(
  $$select public.v1_save_material_request_draft(
    jsonb_build_object(
      'request_id', 'a3200000-0000-4000-8000-000000000002',
      'expected_version', 0,
      'project_id', (select project_id from v1_t03_targets),
      'scope_id', (select common_scope_id from v1_t03_targets),
      'title', 'Invalid Common request',
      'timing', 'normal',
      'scheduled_date', null,
      'delivery_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'id', 'a3300000-0000-4000-8000-000000000002',
        'display_order', 1,
        'source_kind', 'boq',
        'source_boq_group_id', (select boq_group_id from v1_t03_targets),
        'source_boq_row_id', 'a3100000-0000-4000-8000-000000000001',
        'item_description', 'DF3W Smoke Damper',
        'brand_origin', null,
        'technical_attributes', '{}'::jsonb,
        'requested_qty', '2',
        'unit', 'Nos'
      ))
    )
  )$$,
  '22023',
  'V1_MATERIAL_REQUEST_BOQ_SOURCE_INVALID',
  'A building BOQ source cannot be written into Common'
);

set local role postgres;
update public.v1_material_requests
set scope_id = (select common_scope_id from v1_t03_targets)
where id = 'a3200000-0000-4000-8000-000000000001'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', 'a3200000-0000-4000-8000-000000000001',
      'expected_version', 1
    ),
    'a3000000-0000-4000-8000-000000000005'::uuid
  )$$,
  '22023',
  'V1_MATERIAL_REQUEST_BOQ_SCOPE_RECONCILIATION_REQUIRED',
  'Submission rejects a pre-existing draft whose BOQ source and scope disagree'
);

set local role postgres;
update public.v1_boq_groups
set scope_id = null
where id = (select custom_group_id from v1_t03_targets);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (
    select item ->> 'is_legacy_unassigned'
    from jsonb_array_elements(public.v1_list_boq_groups_for_scope(
      (select project_id from v1_t03_targets), null
    )) item
    where item ->> 'id' = (select custom_group_id::text from v1_t03_targets)
  ),
  'true',
  'Preserved scope-less BOQs remain visible in All without silent reassignment'
);

select lives_ok(
  $$select public.v1_assign_legacy_boq_group_scope(
    jsonb_build_object(
      'group_id', (select custom_group_id from v1_t03_targets),
      'scope_id', (select df4w_scope_id from v1_t03_targets),
      'expected_version', 1
    ),
    'a3000000-0000-4000-8000-000000000006'::uuid
  )$$,
  'Engineer explicitly assigns a preserved BOQ to one real building scope'
);

select is(
  (
    select scope_id from public.v1_boq_groups
    where id = (select custom_group_id from v1_t03_targets)
  ),
  (select df4w_scope_id from v1_t03_targets),
  'Explicit reconciliation writes exactly the selected real scope'
);

select is(
  public.v1_assign_legacy_boq_group_scope(
    jsonb_build_object(
      'group_id', (select custom_group_id from v1_t03_targets),
      'scope_id', (select df4w_scope_id from v1_t03_targets),
      'expected_version', 1
    ),
    'a3000000-0000-4000-8000-000000000006'::uuid
  ) ->> 'scope_id',
  (select df4w_scope_id::text from v1_t03_targets),
  'Legacy scope reconciliation is idempotent for a retry with the same key'
);

set local role postgres;
select is(
  (
    select count(*) from public.v1_audit_events
    where event_type = 'boq_group_scope_assigned'
      and entity_id = (select custom_group_id from v1_t03_targets)
  ),
  1::bigint,
  'Legacy scope reconciliation writes one append-only audit event'
);

alter table v1_t03_targets
  add column legacy_default_group_id uuid,
  add column target_placeholder_group_id uuid;
update v1_t03_targets
set legacy_default_group_id = (
      select id from public.v1_boq_groups
      where project_id = v1_t03_targets.project_id
        and scope_id = v1_t03_targets.df3w_scope_id
        and display_order = 2
    ),
    target_placeholder_group_id = (
      select id from public.v1_boq_groups
      where project_id = v1_t03_targets.project_id
        and scope_id = v1_t03_targets.df4w_scope_id
        and display_order = 2
    );
update public.v1_boq_groups
set scope_id = null
where id = (select legacy_default_group_id from v1_t03_targets);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_assign_legacy_boq_group_scope(
    jsonb_build_object(
      'group_id', (select legacy_default_group_id from v1_t03_targets),
      'scope_id', (select df4w_scope_id from v1_t03_targets),
      'expected_version', 1
    ),
    'a3000000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Explicitly mapping a legacy default safely supersedes only an empty generated placeholder'
);

set local role postgres;
select ok(
  (
    select is_archived from public.v1_boq_groups
    where id = (select target_placeholder_group_id from v1_t03_targets)
  ),
  'The empty generated placeholder is retained as an archived audit record'
);

select is(
  (
    select scope_id from public.v1_boq_groups
    where id = (select legacy_default_group_id from v1_t03_targets)
  ),
  (select df4w_scope_id from v1_t03_targets),
  'The preserved default group becomes the selected building folder without copying rows'
);

select * from finish();
rollback;
