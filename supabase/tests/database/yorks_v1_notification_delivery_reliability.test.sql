begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(7);

select has_function(
  'public',
  'v1_notification_unread_count',
  array['uuid'],
  'Server badge count function exists'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_notification_unread_count(uuid)',
    'execute'
  )
  and has_function_privilege(
    'service_role',
    'public.v1_notification_unread_count(uuid)',
    'execute'
  ),
  'Only trusted server delivery can derive another recipient badge count'
);

create temporary table notification_badge_baseline(value integer not null);
insert into notification_badge_baseline(value)
values (public.v1_notification_unread_count(
  '10000000-0000-4000-8000-000000000003'
));

insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id, seen_at
) values
  (
    '9a000000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000003',
    'material_request_submitted', 'material_request',
    '9b000000-0000-4000-8000-000000000001', null
  ),
  (
    '9a000000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003',
    'material_request_mentioned', 'material_request',
    '9b000000-0000-4000-8000-000000000002', clock_timestamp()
  );

select is(
  public.v1_notification_unread_count(
    '10000000-0000-4000-8000-000000000003'
  ),
  (select value + 1 from notification_badge_baseline),
  'Only unseen workflow rows increase the external application badge'
);

insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id
) values (
  '9a000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000003',
  'team_chat_message', 'chat_message',
  '9b000000-0000-4000-8000-000000000003'
);

select is(
  public.v1_notification_unread_count(
    '10000000-0000-4000-8000-000000000003'
  ),
  (select value + 1 from notification_badge_baseline),
  'Chat transport rows do not duplicate Team Chat cursor-owned unread state'
);

insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id
) values (
  '9a000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000003',
  'material_request_cancelled', 'material_request',
  '9b000000-0000-4000-8000-000000000004'
);

select is(
  (
    public.v1_claim_notification_push(
      '9a000000-0000-4000-8000-000000000004'
    ) ->> 'unreadCount'
  )::integer,
  (select value + 2 from notification_badge_baseline),
  'A push claim carries the latest server-authoritative unresolved count'
);

select is(
  public.v1_claim_notification_push(
    '9a000000-0000-4000-8000-000000000004'
  ),
  null::jsonb,
  'A retry cannot claim the same active delivery lease twice'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_notification_unread_count(
    '10000000-0000-4000-8000-000000000003'
  )$$,
  '42501', null,
  'An authenticated client cannot enumerate server badge counts'
);

select * from finish();
rollback;
