begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select ok(
  not has_function_privilege(
    'authenticated', 'public.v1_boq_group_projection(uuid)', 'execute'
  ),
  'BOQ trust metadata remains available only through protected projections'
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
      "project_ref":"BOQ-TRUST-001",
      "name":"BOQ Trust Metadata",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"trust","name":"Trust Building"}],
      "attachments":[]
    }'::jsonb,
    '76000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the BOQ trust fixture'
);

select lives_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (
        select group_record.id
        from public.v1_boq_groups group_record
        join public.v1_projects project on project.id = group_record.project_id
        where project.project_ref = 'BOQ-TRUST-001'
          and group_record.name = 'Workshop Materials'
          and group_record.scope_id = (
            select scope.id
            from public.v1_project_scopes scope
            where scope.project_id = project.id
              and scope.scope_kind = 'common'
          )
      ),
      'expected_version', 1,
      'worksheet_title', 'Workshop consumables',
      'columns', jsonb_build_array(jsonb_build_object(
        'id', '76000000-0000-4000-8000-000000000002',
        'heading', 'Item Description',
        'display_order', 1,
        'canonical_field', 'description',
        'is_commercial', false
      )),
      'rows', jsonb_build_array(jsonb_build_object(
        'id', '76000000-0000-4000-8000-000000000003',
        'display_order', 1,
        'raw_values', jsonb_build_object(
          '76000000-0000-4000-8000-000000000002', 'Tarpaulin'
        )
      )),
      'reason', 'Create searchable BOQ row'
    ),
    '76000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Worksheet save remains atomic while recording revision history'
);

select is(
  (
    select public.v1_get_boq_worksheet(group_record.id)
      #>> '{group,last_edited_role}'
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'BOQ-TRUST-001'
      and group_record.name = 'Workshop Materials'
      and group_record.scope_id = (
        select scope.id
        from public.v1_project_scopes scope
        where scope.project_id = project.id
          and scope.scope_kind = 'common'
      )
  ),
  'project_engineer',
  'The worksheet projection attributes the latest audited editor role'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects where project_ref = 'BOQ-TRUST-001'
      ),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for linked request test'
    ),
    '76000000-0000-4000-8000-000000000005'::uuid
  )$$,
  'Project is activated through its trusted lifecycle command'
);

select lives_ok(
  $$select public.v1_save_material_request_draft(
    jsonb_build_object(
      'request_id', '76000000-0000-4000-8000-000000000006',
      'expected_version', 0,
      'project_id', (
        select id from public.v1_projects where project_ref = 'BOQ-TRUST-001'
      ),
      'scope_id', (
        select scope.id
        from public.v1_project_scopes scope
        join public.v1_projects project on project.id = scope.project_id
        where project.project_ref = 'BOQ-TRUST-001'
          and scope.scope_kind = 'common'
      ),
      'title', 'Workshop cover material',
      'timing', 'normal',
      'scheduled_date', null,
      'delivery_note', null,
      'lines', jsonb_build_array(jsonb_build_object(
        'id', '76000000-0000-4000-8000-000000000007',
        'display_order', 1,
        'source_kind', 'boq',
        'source_boq_group_id', (
          select group_record.id
          from public.v1_boq_groups group_record
          join public.v1_projects project on project.id = group_record.project_id
          where project.project_ref = 'BOQ-TRUST-001'
            and group_record.name = 'Workshop Materials'
            and group_record.scope_id = (
              select scope.id
              from public.v1_project_scopes scope
              where scope.project_id = project.id
                and scope.scope_kind = 'common'
            )
        ),
        'source_boq_row_id', '76000000-0000-4000-8000-000000000003',
        'item_description', 'Tarpaulin',
        'brand_origin', null,
        'technical_attributes', '{}'::jsonb,
        'requested_qty', '1',
        'unit', 'Nos'
      ))
    )
  )$$,
  'Creator saves a private BOQ-backed request draft'
);

select is(
  (
    select (public.v1_get_boq_worksheet(group_record.id)
      #>> '{group,linked_request_count}')::integer
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'BOQ-TRUST-001'
      and group_record.name = 'Workshop Materials'
      and group_record.scope_id = (
        select scope.id
        from public.v1_project_scopes scope
        where scope.project_id = project.id
          and scope.scope_kind = 'common'
      )
  ),
  1,
  'The draft creator sees the linked request count'
);

set local role postgres;
create temporary table v1_boq_trust_target as
select group_record.id as group_id
from public.v1_boq_groups group_record
join public.v1_projects project on project.id = group_record.project_id
where project.project_ref = 'BOQ-TRUST-001'
  and group_record.name = 'Workshop Materials'
  and group_record.scope_id = (
    select scope.id
    from public.v1_project_scopes scope
    where scope.project_id = project.id
      and scope.scope_kind = 'common'
  );
grant select on table v1_boq_trust_target to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  (
    select (public.v1_get_boq_worksheet(group_id)
      #>> '{group,linked_request_count}')::integer
    from v1_boq_trust_target
  ),
  0,
  'Procurement cannot infer another user private draft from BOQ counts'
);

select throws_ok(
  $$select public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', (select group_id from v1_boq_trust_target),
      'expected_version', 2,
      'worksheet_title', 'Denied',
      'columns', '[]'::jsonb,
      'rows', '[]'::jsonb,
      'reason', 'Denied'
    ),
    '76000000-0000-4000-8000-000000000008'::uuid
  )$$,
  '42501',
  'V1_BOQ_EDIT_DENIED',
  'Procurement remains unable to mutate BOQ through the trusted save command'
);

select * from finish();
rollback;
