begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select ok(
  public.v1_is_valid_role('workshop_in_charge')
    and public.v1_is_valid_role('document_controller')
    and public.v1_canonical_role_from_exact_role('workshop_in_charge') = 'project_engineer'
    and public.v1_canonical_role_from_exact_role('document_controller') = 'project_engineer',
  'The two exact job roles normalize to Project Engineer workflow authority'
);

select ok(
  public.v1_safe_auth_audit_role('{"role":"workshop_in_charge"}'::jsonb)
      = 'workshop_in_charge'
    and public.v1_safe_auth_audit_role('{"role":"document_controller"}'::jsonb)
      = 'document_controller',
  'Audit keeps each exact job title instead of relabelling it'
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
      "project_ref":"ROLE-ACCESS-001",
      "name":"Role accessibility proof",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"main","name":"Main"}],
      "attachments":[]
    }'::jsonb,
    '9a000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A project exists for organization-wide access tests'
);

set local role postgres;
create temporary table v1_role_access_target as
select id as project_id from public.v1_projects
where project_ref = 'ROLE-ACCESS-001';
grant select on table v1_role_access_target to authenticated;

update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}', '"workshop_in_charge"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"workshop_in_charge","app_user_id":"usr-local-project-manager"}}',
  true
);
set local role postgres;
select ok(
  public.v1_current_exact_role() = 'workshop_in_charge'
    and public.v1_current_role() = 'project_engineer'
    and public.v1_current_actor_is_active(),
  'Workshop In-Charge is an active exact role with normalized Project Engineer authority'
);
select ok(
  public.v1_has_active_project_membership(
    (select project_id from v1_role_access_target),
    '10000000-0000-4000-8000-000000000010',
    'project_engineer'
  ),
  'Workshop In-Charge can access an unassigned project like Project Manager'
);
select is(
  public.v1_user_configuration_actor(),
  false,
  'Workshop In-Charge does not inherit User Management authority'
);
set local role authenticated;
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Workshop In-Charge does not inherit the separate SME inventory-read grant'
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    '{
      "kind":"group",
      "title":"Workshop coordination",
      "participant_auth_user_ids":["10000000-0000-4000-8000-000000000001"]
    }'::jsonb,
    '9a000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Workshop In-Charge can create a Team Chat group like Project Manager'
);

set local role postgres;
update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}', '"document_controller"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"document_controller","app_user_id":"usr-local-project-manager"}}',
  true
);
set local role postgres;
select ok(
  public.v1_current_exact_role() = 'document_controller'
    and public.v1_current_role() = 'project_engineer'
    and public.v1_current_actor_is_active(),
  'Document Controller is an active exact role with normalized Project Engineer authority'
);
select ok(
  public.v1_has_active_project_membership(
    (select project_id from v1_role_access_target),
    '10000000-0000-4000-8000-000000000010',
    'project_engineer'
  ),
  'Document Controller can access an unassigned project like Project Manager'
);
select is(
  public.v1_user_configuration_actor(),
  false,
  'Document Controller does not inherit User Management authority'
);
set local role authenticated;
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Document Controller does not inherit the separate SME inventory-read grant'
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    '{
      "kind":"group",
      "title":"Document coordination",
      "participant_auth_user_ids":["10000000-0000-4000-8000-000000000001"]
    }'::jsonb,
    '9a000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Document Controller can create a Team Chat group like Project Manager'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
set local role postgres;
select is(
  public.v1_can_manage_inventory(),
  false,
  'Senior Mechanical Engineer still has no stock-management authority'
);
set local role authenticated;
select lives_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  'Senior Mechanical Engineer can read Browse / Inventory'
);
select throws_ok(
  $$select public.v1_create_inventory_category(
    '{"name":"SME must not create"}'::jsonb,
    '9a000000-0000-4000-8000-000000000004'::uuid
  )$$,
  '42501', 'V1_INVENTORY_CATEGORY_CREATE_DENIED',
  'Senior Mechanical Engineer cannot mutate the catalogue'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Project Engineer remains denied the organization warehouse workspace'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_inventory_workspace_projection(null)$$,
  '42501', 'V1_INVENTORY_WORKSPACE_DENIED',
  'Site Engineer remains denied the organization warehouse workspace'
);

select * from finish();
rollback;
