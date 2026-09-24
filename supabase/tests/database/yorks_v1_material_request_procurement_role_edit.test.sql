begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  has_function_privilege('authenticated',
    'public.v1_set_material_request_post_approval_edit(jsonb,uuid)', 'execute')
  and not has_function_privilege('anon',
    'public.v1_set_material_request_post_approval_edit(jsonb,uuid)', 'execute')
  and not has_table_privilege('authenticated',
    'public.v1_material_requests', 'update'),
  'Grant mutation is an authenticated trusted command, not a table write'
);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select lives_ok($$select public.v1_create_project(
  '{"project_ref":"MR-POST-EDIT-001","name":"Post Approval Editing",
    "parties":{},"initial_members":[{"auth_user_id":
    "10000000-0000-4000-8000-000000000002","project_role":"site_engineer",
    "reason":"Request creator"}],"buildings":[{"code":"main",
    "name":"Main Building"}],"attachments":[]}'::jsonb,
  'ae000000-0000-4000-8000-000000000001'::uuid)$$,
  'Project Engineer creates the isolated editing fixture');
select lives_ok($$select public.v1_set_project_state(jsonb_build_object(
  'project_id', (select id from public.v1_projects
    where project_ref = 'MR-POST-EDIT-001'),
  'state', 'active', 'expected_version', 1,
  'reason', 'Ready for post-approval edit testing'),
  'ae000000-0000-4000-8000-000000000002'::uuid)$$,
  'Project is activated');

set local role postgres;
create temporary table post_edit_fixture as select
  project.id as project_id,
  (select id from public.v1_project_scopes scope
    where scope.project_id = project.id and scope.scope_kind = 'building'
    limit 1) as scope_id
from public.v1_projects project
where project.project_ref = 'MR-POST-EDIT-001';
create temporary table post_edit_payload as select jsonb_build_object(
  'request_id', 'ae100000-0000-4000-8000-000000000001',
  'expected_version', 0,
  'project_id', project_id, 'scope_id', scope_id,
  'title', 'Initial engineering request', 'timing', 'normal',
  'scheduled_date', null, 'delivery_note', null,
  'lines', jsonb_build_array(jsonb_build_object(
    'id', 'ae110000-0000-4000-8000-000000000001',
    'display_order', 1, 'source_kind', 'custom',
    'source_boq_group_id', null, 'source_boq_row_id', null,
    'item_description', 'Duct fitting', 'brand_origin', null,
    'technical_attributes', '{}'::jsonb,
    'requested_qty', '2', 'unit', 'Nos'
  ))) as payload from post_edit_fixture;
grant select on table post_edit_fixture, post_edit_payload to authenticated;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}', true);
select lives_ok($$select public.v1_save_material_request_draft(
  (select payload from post_edit_payload))$$,
  'Site Engineer creates request');
select lives_ok($$select public.v1_submit_material_request(
  jsonb_build_object('request_id',
    'ae100000-0000-4000-8000-000000000001', 'expected_version', 1),
  'ae200000-0000-4000-8000-000000000001'::uuid)$$,
  'Site Engineer submits request');
select throws_ok($$select public.v1_set_material_request_post_approval_edit(
  jsonb_build_object('request_id',
    'ae100000-0000-4000-8000-000000000001', 'expected_version', 2,
    'enabled', true, 'procurement_editor_auth_user_id', null),
  'ae200000-0000-4000-8000-000000000002'::uuid)$$,
  '42501', 'V1_POST_APPROVAL_EDIT_GRANT_DENIED',
  'Site Engineer cannot grant editing');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select lives_ok($$select public.v1_decide_material_request(
  jsonb_build_object('request_id',
    'ae100000-0000-4000-8000-000000000001', 'expected_version', 2,
    'decision', 'approved', 'reason', null),
  'ae200000-0000-4000-8000-000000000003'::uuid)$$,
  'Project Engineer approves request');
select ok((select
    (projection ->> 'post_approval_edit_enabled')::boolean = false
    and projection ->> 'procurement_editor_auth_user_id' is null
  from (select public.v1_material_request_projection(
    'ae100000-0000-4000-8000-000000000001'::uuid) as projection) projected),
  'Editing is off by default after approval');
select ok((public.v1_material_request_projection(
  'ae100000-0000-4000-8000-000000000001'::uuid) ->> 'can_manage_post_approval_edit')::boolean,
  'Assigned Project Engineer can manage the grant');

select lives_ok($$select public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":3,"enabled":true,"procurement_role_edit_enabled":true}'::jsonb, 'be000000-0000-4000-8000-000000000001'::uuid)$$, 'Approver grants all Procurement users');
select is((public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":3,"enabled":true,"procurement_role_edit_enabled":true}'::jsonb, 'be000000-0000-4000-8000-000000000001'::uuid) ->> 'record_version')::integer,4,'Role grant retry is idempotent');
select throws_ok($$select public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":3,"enabled":true,"procurement_role_edit_enabled":false}'::jsonb, 'be000000-0000-4000-8000-000000000002'::uuid)$$,'40001','V1_MATERIAL_REQUEST_VERSION_CONFLICT','Stale competing revoke cannot overwrite grant');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
set local role postgres;
select ok(public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'First Procurement user can edit');
set local role authenticated;
select throws_ok($$select public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":4,"enabled":true,"procurement_role_edit_enabled":false}'::jsonb, 'be000000-0000-4000-8000-000000000003'::uuid)$$,'42501','V1_POST_APPROVAL_EDIT_GRANT_DENIED','Procurement cannot change access');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}', true);
set local role postgres;
select ok(not public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'Site Engineer does not inherit the role grant');
set local role authenticated;
set local role postgres;
update auth.users set raw_app_meta_data = jsonb_set(raw_app_meta_data, '{role}', '"procurement"'::jsonb)
where id = '10000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
set local role postgres;
select ok(public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'Second independent Procurement user can edit');
set local role authenticated;
select lives_ok($$select public.v1_update_material_request_for_approval((select payload from post_edit_payload) || '{"expected_version":4,"title":"Role amendment"}'::jsonb, 'be000000-0000-4000-8000-000000000004'::uuid)$$,'Role-granted Procurement saves amendment');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
select ok((public.v1_material_request_projection('ae100000-0000-4000-8000-000000000001'::uuid)->>'post_approval_amendment_pending')::boolean,'Other Procurement user can read pending amendment');
select throws_ok($$select public.v1_decide_material_request('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":5,"decision":"approved"}'::jsonb,'be000000-0000-4000-8000-000000000005'::uuid)$$,'42501',null,'Procurement cannot approve its proposal');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}', true);
select lives_ok($$select public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":5,"enabled":true,"procurement_role_edit_enabled":false}'::jsonb, 'be000000-0000-4000-8000-000000000006'::uuid)$$,'Approver revokes role grant during pending amendment');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
set local role postgres;
select ok(not public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'Revocation immediately blocks first Procurement user');
set local role authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
set local role postgres;
select ok(not public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'Revocation immediately blocks second Procurement user');
set local role authenticated;

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}', true);
select lives_ok($$select public.v1_set_material_request_post_approval_edit('{"request_id":"ae100000-0000-4000-8000-000000000001","expected_version":6,"enabled":true,"procurement_role_edit_enabled":true}'::jsonb, 'be000000-0000-4000-8000-000000000007'::uuid)$$,'Admin can restore explicit role grant');
set local role postgres;
update public.v1_profiles set is_active = false where auth_user_id = '10000000-0000-4000-8000-000000000002';

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"procurement"}}', true);
set local role postgres;
select ok(not public.v1_can_edit_material_request_post_approval('ae100000-0000-4000-8000-000000000001'::uuid),'Inactive Procurement user remains denied');
set local role authenticated;
set local role postgres;
select is((select count(*)::integer from public.v1_audit_events where entity_id='ae100000-0000-4000-8000-000000000001'::uuid and event_type='material_request_post_approval_edit_grant_changed'),3,'Audit contains one event per successful change and none for retry or rejected changes');
select ok((select bool_and(after_data ? 'procurement_role_edit_enabled') from public.v1_audit_events where entity_id='ae100000-0000-4000-8000-000000000001'::uuid and event_type='material_request_post_approval_edit_grant_changed'),'Audit explicitly records role-wide grant state');
select * from finish();
rollback;
