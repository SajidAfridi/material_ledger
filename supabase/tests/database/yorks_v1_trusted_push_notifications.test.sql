begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(23);

select ok(
  (select relrowsecurity from pg_class
   where oid = 'public.v1_push_device_tokens'::regclass)
  and (select relrowsecurity from pg_class
   where oid = 'public.v1_notification_push_outbox'::regclass),
  'Push token and delivery outbox tables enforce RLS'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_push_device_tokens', 'select'
  )
  and not has_table_privilege(
    'authenticated', 'public.v1_notification_push_outbox', 'select'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_register_push_device(text,text)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_list_my_notifications(integer)', 'execute'
  ),
  'Clients use narrow token and notification RPCs, never protected tables'
);

select ok(
  not has_function_privilege(
    'authenticated', 'public.v1_claim_notification_push(uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_finish_notification_push(uuid,text,integer,text)',
    'execute'
  ),
  'Only the service worker can claim or finish push deliveries'
);

set local role postgres;
select is(
  public.v1_validate_push_webhook_secret('not-the-server-secret'),
  false,
  'A forged webhook secret is rejected'
);

select is(
  public.v1_validate_push_webhook_secret(
    (select decrypted_secret from vault.decrypted_secrets
     where name = 'yorks_push_webhook_secret')
  ),
  true,
  'The database-generated webhook secret validates server calls'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_register_push_device(
    'test-fcm-token-procurement-00000000000000000001', 'web'
  )$$,
  'An active Procurement user registers an owner-bound web token'
);

set local role postgres;
select is(
  (select auth_user_id from public.v1_push_device_tokens
   where token = 'test-fcm-token-procurement-00000000000000000001'),
  '10000000-0000-4000-8000-000000000003'::uuid,
  'Token ownership comes from auth.uid rather than client metadata'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select throws_ok(
  $$select * from public.v1_push_device_tokens$$,
  '42501', null,
  'A Site Engineer cannot read protected device tokens'
);

select is(
  public.v1_unregister_push_device(
    'test-fcm-token-procurement-00000000000000000001'
  ),
  false,
  'A different user cannot unregister Procurement device tokens'
);

set local role postgres;
insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id, created_at
) values
  (
    '91000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003',
    'material_request_submitted', 'material_request',
    '92000000-0000-4000-8000-000000000001', clock_timestamp()
  ),
  (
    '91000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000002',
    'receipt_review_required', 'material_dispatch',
    '92000000-0000-4000-8000-000000000002', clock_timestamp()
  );

select is(
  (select count(*) from public.v1_notification_push_outbox
   where notification_id in (
     '91000000-0000-4000-8000-000000000001',
     '91000000-0000-4000-8000-000000000002'
   )),
  2::bigint,
  'Every authoritative notification creates one durable push command'
);

select is(
  (select count(*) from public.v1_notifications
   where event_code = 'receipt_review_required'
     and entity_id = '92000000-0000-4000-8000-000000000002'
     and recipient_auth_user_id in (
       '10000000-0000-4000-8000-000000000009',
       '10000000-0000-4000-8000-000000000010'
     )),
  2::bigint,
  'Senior Mechanical Engineer and Project Manager receive global PE work'
);

select is(
  (select count(*) from public.v1_notification_push_outbox
   where notification_id in (
     select id from public.v1_notifications
     where event_code = 'receipt_review_required'
       and entity_id = '92000000-0000-4000-8000-000000000002'
   )),
  3::bigint,
  'Expanded global recipients each receive an independent delivery command'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select is(
  (select count(*) from public.v1_list_my_notifications(100)),
  1::bigint,
  'Personal notification list excludes every other recipient'
);

select is(
  (select request_id from public.v1_list_my_notifications(100) limit 1),
  '92000000-0000-4000-8000-000000000001'::uuid,
  'Notification projection resolves the safe Material Request deep link'
);

select lives_ok(
  $$select public.v1_mark_notification_seen(
    '91000000-0000-4000-8000-000000000001'
  )$$,
  'Recipient can idempotently acknowledge their own notification'
);

select ok(
  (select seen_at is not null from public.v1_list_my_notifications(100)
   where notification_id = '91000000-0000-4000-8000-000000000001'),
  'Acknowledgement is visible in the authoritative projection'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_mark_notification_seen(
    '91000000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_NOTIFICATION_SEEN_DENIED',
  'Another recipient cannot acknowledge Procurement notifications'
);

set local role postgres;
update public.v1_notifications set seen_at = null
where id = '91000000-0000-4000-8000-000000000001';
update public.v1_notification_push_outbox
set status = 'no_devices', completed_at = clock_timestamp()
where notification_id = '91000000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_register_push_device(
    'test-fcm-token-procurement-00000000000000000002', 'android'
  )$$,
  'A later device registration safely requeues recent unseen alerts'
);

set local role postgres;
select is(
  (select status from public.v1_notification_push_outbox
   where notification_id = '91000000-0000-4000-8000-000000000001'),
  'pending',
  'No-device delivery becomes pending after recipient registers a device'
);

select is(
  (public.v1_claim_notification_push(
    '91000000-0000-4000-8000-000000000001'
  ) ->> 'recipientAuthUserId'),
  '10000000-0000-4000-8000-000000000003',
  'Service claim derives recipient identity from the notification row'
);

select lives_ok(
  $$select public.v1_finish_notification_push(
    '91000000-0000-4000-8000-000000000001', 'sent', 2, null
  )$$,
  'Service records the transport result'
);

select ok(
  (select status = 'sent' and sent_device_count = 2
     and completed_at is not null and lease_until is null
   from public.v1_notification_push_outbox
   where notification_id = '91000000-0000-4000-8000-000000000001'),
  'Completed delivery is terminal and retains its device count'
);

select is(
  public.v1_claim_notification_push(
    '91000000-0000-4000-8000-000000000001'
  ),
  null::jsonb,
  'A sent outbox command cannot be claimed twice'
);

select * from finish();
rollback;
