begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  (select relrowsecurity from pg_class
   where oid = 'public.v1_user_notification_preferences'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_user_notification_preferences', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_user_notification_preferences', 'update'
  ),
  'Personal notification preferences are protected from direct table access'
);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_get_my_notification_preferences()', 'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_update_my_notification_preferences(jsonb,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_get_my_notification_preferences()', 'execute'
  )
  and not has_function_privilege(
    'authenticated', 'public.v1_claim_notification_push(uuid)', 'execute'
  ),
  'Only narrow self-service RPCs are client callable'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  public.v1_get_my_notification_preferences(),
  jsonb_build_object(
    'schema_version', 1, 'revision', 0,
    'push_enabled', true, 'workflow_push_enabled', true,
    'team_chat_push_enabled', true,
    'foreground_alerts_enabled', true, 'sound_enabled', true,
    'updated_at', null
  ),
  'A missing row resolves to backward-compatible enabled defaults'
);

select is(
  public.v1_update_my_notification_preferences(
    '{"push_enabled":false,"workflow_push_enabled":true,"team_chat_push_enabled":true,"foreground_alerts_enabled":false,"sound_enabled":false}',
    0
  ) ->> 'revision',
  '1',
  'An active user creates only their own preference row'
);

select is(
  public.v1_update_my_notification_preferences(
    '{"push_enabled":false,"workflow_push_enabled":true,"team_chat_push_enabled":true,"foreground_alerts_enabled":false,"sound_enabled":false}',
    0
  ) ->> 'revision',
  '1',
  'A lost-response retry is idempotent when the desired state already matches'
);

select throws_ok(
  $$select public.v1_update_my_notification_preferences(
    '{"push_enabled":true,"unknown":true}', 1
  )$$,
  '22023', 'V1_NOTIFICATION_PREFERENCES_PATCH_INVALID',
  'Unknown preference keys are rejected'
);

select throws_ok(
  $$select public.v1_update_my_notification_preferences(
    '{"push_enabled":"yes"}', 1
  )$$,
  '22023', 'V1_NOTIFICATION_PREFERENCES_VALUE_INVALID',
  'Non-boolean preference values are rejected'
);

set local role postgres;
insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id, created_at
) values (
  '9a000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted', 'material_request',
  '9b000000-0000-4000-8000-000000000001', clock_timestamp()
);

select ok(
  not exists (
    select 1 from public.v1_notification_push_outbox
    where notification_id = '9a000000-0000-4000-8000-000000000001'
  ) and exists (
    select 1 from public.v1_notifications
    where id = '9a000000-0000-4000-8000-000000000001'
  ),
  'Disabling push suppresses transport without removing in-app history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  (select count(*) from public.v1_list_my_notifications(200)
   where notification_id = '9a000000-0000-4000-8000-000000000001'),
  1::bigint,
  'The durable notification centre remains available when push is off'
);

select is(
  public.v1_update_my_notification_preferences(
    '{"push_enabled":true,"workflow_push_enabled":true,"team_chat_push_enabled":true,"foreground_alerts_enabled":false,"sound_enabled":false}',
    1
  ) ->> 'revision',
  '2',
  'Push can be re-enabled without changing presentation choices'
);

select throws_ok(
  $$select public.v1_update_my_notification_preferences(
    '{"push_enabled":false}', 1
  )$$,
  '40001', 'V1_NOTIFICATION_PREFERENCES_VERSION_CONFLICT',
  'A stale, different preference change cannot overwrite a newer revision'
);

select is(
  public.v1_update_my_notification_preferences(
    '{"workflow_push_enabled":false}', 2
  ) ->> 'revision',
  '3',
  'Workflow push has its own explicit preference'
);

set local role postgres;
insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id, created_at
) values
  (
    '9a000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003',
    'arrangement_review_required', 'material_request',
    '9b000000-0000-4000-8000-000000000002', clock_timestamp()
  ),
  (
    '9a000000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000003',
    'team_chat_message', 'chat_message',
    '9b000000-0000-4000-8000-000000000003', clock_timestamp()
  );

select ok(
  not exists (
    select 1 from public.v1_notification_push_outbox
    where notification_id = '9a000000-0000-4000-8000-000000000002'
  ) and exists (
    select 1 from public.v1_notification_push_outbox
    where notification_id = '9a000000-0000-4000-8000-000000000003'
  ),
  'Workflow and Team Chat push categories are enforced independently'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select is(
  public.v1_get_my_notification_preferences() ->> 'revision',
  '0',
  'Another active user cannot see or inherit Procurement preferences'
);

select throws_ok(
  $$select * from public.v1_user_notification_preferences$$,
  '42501', null,
  'An authenticated user cannot inspect preference rows directly'
);

set local role anon;
select throws_ok(
  $$select public.v1_get_my_notification_preferences()$$,
  '42501', 'permission denied for function v1_get_my_notification_preferences',
  'Anonymous users cannot read notification preferences'
);

select * from finish();
rollback;
