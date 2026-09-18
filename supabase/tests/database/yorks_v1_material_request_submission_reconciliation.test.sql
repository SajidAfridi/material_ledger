begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_comments'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_decisions'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_material_request_comment_contexts'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_material_request_comments', 'insert'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_material_request_comment_contexts', 'select'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_decide_material_request(jsonb,uuid)', 'execute'
  ),
  'Approval decisions, comments and contexts are RLS protected and command-only'
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
      "project_ref":"MR-RC-001",
      "name":"Approval First Material Request",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Request author"
      }],
      "buildings":[{"code":"af","name":"Approval Building"}],
      "attachments":[]
    }'::jsonb,
    'af000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the approval-first project fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-RC-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for approval-first testing'
    ),
    'af000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The approval-first project is activated'
);

set local role postgres;
create temporary table v1_af_targets as
select project.id as project_id,
  (select scope.id from public.v1_project_scopes scope
   where scope.project_id = project.id and scope.scope_kind = 'building'
   limit 1) as scope_id
from public.v1_projects project where project.project_ref = 'MR-RC-001';

create temporary table v1_af_payload as
select jsonb_build_object(
  'request_id', 'af100000-0000-4000-8000-000000000001',
  'expected_version', 0,
  'project_id', project_id,
  'scope_id', scope_id,
  'title', 'Approval first dampers',
  'timing', 'normal', 'scheduled_date', null,
  'delivery_note', 'Site store',
  'lines', jsonb_build_array(jsonb_build_object(
    'id', 'af110000-0000-4000-8000-000000000001',
    'display_order', 1, 'source_kind', 'custom',
    'source_boq_group_id', null, 'source_boq_row_id', null,
    'item_description', 'approval first damper',
    'brand_origin', 'UAE',
    'technical_attributes', jsonb_build_object(
      'size', '500 x 500', 'model', 'AF-500'
    ),
    'requested_qty', '2', 'unit', 'Nos'
  ))
) as payload from v1_af_targets;
grant select on table v1_af_targets, v1_af_payload to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select is(public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010'), null::jsonb,
 'No committed key is unconfirmed, not a rollback claim');
select lives_ok($$select public.v1_save_and_submit_material_request(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')$$,
 'Owner submits one logical intent');
select is(public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')->>'id',
 'af100000-0000-4000-8000-000000000001', 'Lost response can be reconciled without a write');
select is(public.v1_save_and_submit_material_request(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')->>'id',
 'af100000-0000-4000-8000-000000000001', 'Same intent replay returns one authorized record');
select throws_ok($$select public.v1_get_material_request_submission_result(
 (select payload || '{"title":"Changed intent"}'::jsonb from v1_af_payload),
 'af800000-0000-4000-8000-000000000010')$$,
 '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD', 'Changed payload cannot claim an earlier success');

set local role postgres;
select is((select count(*) from public.v1_material_requests
 where id='af100000-0000-4000-8000-000000000001'),1::bigint,'One header');
select is((select count(*) from public.v1_material_request_lines
 where request_id='af100000-0000-4000-8000-000000000001'),1::bigint,'One line');
select is((select count(*) from public.v1_idempotency_keys
 where actor_auth_user_id='10000000-0000-4000-8000-000000000001'
 and command_name='v1_save_and_submit_material_request'
 and idempotency_key='af800000-0000-4000-8000-000000000010'),1::bigint,
 'Reconciliation/replay creates no second command outcome');
create temporary table v1_rc_approved as select
 jsonb_set(jsonb_set(payload,'{request_id}','"af100000-0000-4000-8000-000000000020"'),
 '{lines,0,id}','"af110000-0000-4000-8000-000000000020"') as payload from v1_af_payload;
grant select on v1_rc_approved to authenticated;
set local role authenticated;
select lives_ok($$select public.v1_save_submit_and_approve_material_request(
 (select payload from v1_rc_approved), 'af800000-0000-4000-8000-000000000020')$$,
 'A genuinely different intent remains possible');
select is(public.v1_get_material_request_submission_result(
 (select payload from v1_rc_approved), 'af800000-0000-4000-8000-000000000020',true)->>'state',
 'approved_for_arrangement','Combined command reconciliation is mode-specific');
select is(public.v1_save_submit_and_approve_material_request(
 (select payload from v1_rc_approved), 'af800000-0000-4000-8000-000000000020')->>'state',
 'approved_for_arrangement','Combined authorized replay remains supported');

select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}', true);
select is(public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010'), null::jsonb,
 'Another assigned engineer cannot discover the first actor result');
select lives_ok($$select public.v1_save_and_submit_material_request(
 (select jsonb_set(jsonb_set(payload,'{request_id}','"af100000-0000-4000-8000-000000000030"'),
 '{lines,0,id}','"af110000-0000-4000-8000-000000000030"') from v1_af_payload),
 'af800000-0000-4000-8000-000000000030')$$, 'Assigned Site Engineer submits own intent');
select is(public.v1_get_material_request_submission_result(
 (select jsonb_set(jsonb_set(payload,'{request_id}','"af100000-0000-4000-8000-000000000030"'),
 '{lines,0,id}','"af110000-0000-4000-8000-000000000030"') from v1_af_payload),
 'af800000-0000-4000-8000-000000000030')->>'id',
 'af100000-0000-4000-8000-000000000030', 'Assigned Site Engineer reconciles own intent');
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}', true);
select throws_ok($$select public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')$$,
 '42501',null,'Procurement cannot reconcile engineering submission intents');
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}', true);
select is(public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010'), null::jsonb,
 'Admin cannot read another actor idempotency result using their key');

set local role postgres;
update public.v1_project_members set effective_from=now()-interval '1 day',
 effective_to=clock_timestamp(), revoked_by_auth_user_id='10000000-0000-4000-8000-000000000004',
 revoked_by_role='admin', revoked_reason='Synthetic revocation'
where project_id=(select project_id from v1_af_targets)
 and member_auth_user_id='10000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select throws_ok($$select public.v1_save_and_submit_material_request(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')$$,
 '42501',null,'Revoked owner cannot replay a cached submission');
select throws_ok($$select public.v1_save_submit_and_approve_material_request(
 (select payload from v1_rc_approved), 'af800000-0000-4000-8000-000000000020')$$,
 '42501',null,'Revoked owner cannot replay a cached approval');
select throws_ok($$select public.v1_get_material_request_submission_result(
 (select payload from v1_af_payload), 'af800000-0000-4000-8000-000000000010')$$,
 '42501',null,'Revoked owner cannot reconcile a cached submission');
set local role anon;
select throws_ok($$select public.v1_get_material_request_submission_result(
 '{}'::jsonb, 'af800000-0000-4000-8000-000000000010')$$,
 '42501',null,'Anonymous role has no result lookup grant');
select * from finish();
rollback;
