begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(66);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_chat_conversations'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_chat_messages'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_chat_messages', 'insert'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_send_chat_message(jsonb,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_chat_is_active_member(uuid,uuid)',
    'execute'
  )
  and not (select public from storage.buckets
    where id = 'yorks-chat-attachments'),
  'Chat is private, RLS protected and writable only through trusted RPCs'
);

select is(
  (
    select count(*)
    from public.v1_chat_conversations conversation
    where conversation.kind = 'direct'
      and (
        select array_agg(member.auth_user_id order by member.auth_user_id)
        from public.v1_chat_members member
        where member.conversation_id = conversation.id
          and member.left_at is null
      ) = array[
        '10000000-0000-4000-8000-000000000002'::uuid,
        '10000000-0000-4000-8000-000000000003'::uuid
      ]
  ),
  0::bigint,
  'The Direct pair fixture begins without a pre-existing canonical conversation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'direct',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Site Engineer creates a private Direct Message'
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'direct',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Concurrent-style Direct creation resolves to the canonical pair'
);

set local role postgres;
create temporary table v1_chat_test_direct as
select id as conversation_id
from public.v1_chat_conversations
where kind = 'direct'
limit 1;
grant select on table v1_chat_test_direct to authenticated, service_role;
select is(
  (select count(*) from public.v1_chat_conversations where kind = 'direct'),
  1::bigint,
  'A Direct pair has one canonical conversation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  jsonb_array_length(public.v1_search_chat('Direct', 50)), 0,
  'Admin does not silently inherit access to private Direct Messages'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Please confirm the delivery window.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000003'::uuid
  )$$,
  'An active Direct participant sends a message'
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Please confirm the delivery window.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A lost-response retry uses the same idempotency key safely'
);

set local role postgres;
select is(
  (select count(*) from public.v1_chat_messages
    where conversation_id = (select conversation_id from v1_chat_test_direct)
      and kind = 'message'),
  1::bigint,
  'A message retry creates one immutable message'
);

create temporary table v1_chat_test_direct_message as
select id as message_id
from public.v1_chat_messages
where conversation_id = (select conversation_id from v1_chat_test_direct)
  and kind = 'message'
limit 1;
grant select on table v1_chat_test_direct_message
  to authenticated, service_role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  public.v1_toggle_chat_acknowledgement(
    (select message_id from v1_chat_test_direct_message)
  ), true,
  'An active participant can acknowledge a message without approving workflow'
);
select is(
  public.v1_toggle_chat_message_pin(
    (select message_id from v1_chat_test_direct_message)
  ), true,
  'An active participant can pin a message in the conversation'
);

set local role postgres;
select ok(
  exists (
    select 1 from public.v1_chat_message_acknowledgements acknowledgement
    where acknowledgement.message_id =
      (select message_id from v1_chat_test_direct_message)
  ) and exists (
    select 1 from public.v1_chat_message_pins pin
    where pin.message_id = (select message_id from v1_chat_test_direct_message)
  ),
  'Acknowledgement and pin are durable chat facts, not message mutations'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  (public.v1_list_chat_conversations() -> 0 ->> 'unread_count')::integer,
  1,
  'The recipient receives a backend-authoritative unread count'
);
select is(
  (select count(*) from public.v1_list_my_notifications()
   where event_code in ('team_chat_message', 'team_chat_mention')
      or entity_type in ('chat_message', 'chat_conversation')),
  0::bigint,
  'Chat transport rows never appear in the workflow notification centre'
);
with unread_workflow as materialized (
  select count(*)::integer as expected
  from public.v1_list_my_notifications()
  where seen_at is null
)
select is(
  public.v1_mark_all_notifications_seen(),
  (select expected from unread_workflow),
  'Mark all acknowledges only the workflow-centre rows visible before the call'
);

set local role postgres;
select ok(
  (
    select count(*) = 1
    from public.v1_notifications notification
    join public.v1_notification_push_outbox outbox
      on outbox.notification_id = notification.id
    where notification.recipient_auth_user_id =
        '10000000-0000-4000-8000-000000000003'::uuid
      and notification.entity_type = 'chat_message'
      and notification.seen_at is null
  ),
  'The hidden Chat transport row still owns exactly one durable push job'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_mark_chat_read(
    (select conversation_id from v1_chat_test_direct)
  )$$,
  'Opening the conversation acknowledges it on the backend'
);

set local role postgres;
select ok(
  not exists (
    select 1 from public.v1_notifications notification
    where notification.recipient_auth_user_id =
        '10000000-0000-4000-8000-000000000003'::uuid
      and notification.entity_type = 'chat_message'
      and notification.seen_at is null
  ),
  'Reading on one device marks matching Chat notifications seen for all devices'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_set_chat_preference(
    (select conversation_id from v1_chat_test_direct), 'muted', true
  ), true,
  'A participant can mute a conversation'
);
select is(
  public.v1_set_chat_preference(
    (select conversation_id from v1_chat_test_direct), 'archived', true
  ), true,
  'Archive is stored as the current participant preference only'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Reply inside the same Direct Message.',
      'reply_to_message_id',
        (select message_id from v1_chat_test_direct_message),
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000022'::uuid
  )$$,
  'A reply preserves one-level context inside the same conversation'
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Routine muted update.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000004'::uuid
  )$$,
  'A normal message remains available in a muted conversation'
);

set local role postgres;
select ok(
  exists (
    select 1 from public.v1_chat_messages message
    where message.conversation_id =
        (select conversation_id from v1_chat_test_direct)
      and message.body = 'Reply inside the same Direct Message.'
      and message.reply_to_message_id =
        (select message_id from v1_chat_test_direct_message)
  ),
  'Reply projection points to the immutable parent message'
);
select ok(
  (select member.is_archived
   from public.v1_chat_members member
   where member.conversation_id =
       (select conversation_id from v1_chat_test_direct)
     and member.auth_user_id =
       '10000000-0000-4000-8000-000000000003'::uuid),
  'Muted incoming activity does not force an archived conversation open'
);
select is(
  (select count(*) from public.v1_notifications notification
    where notification.recipient_auth_user_id =
        '10000000-0000-4000-8000-000000000003'::uuid
      and notification.event_code = 'team_chat_message'),
  1::bigint,
  'Mute suppresses subsequent normal Chat notifications'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_set_chat_preference(
    (select conversation_id from v1_chat_test_direct), 'muted', false
  ), true,
  'A participant can restore normal notification behavior'
);
select is(
  public.v1_mark_chat_unread(
    (select conversation_id from v1_chat_test_direct)
  ), true,
  'Mark unread restores the conversation to this user unread workflow'
);
select ok(
  (public.v1_list_chat_conversations() -> 0 ->> 'unread_count')::integer > 0,
  'Mark unread is reflected by the authoritative conversation projection'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'New unmuted activity restores the conversation.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000023'::uuid
  )$$,
  'A new unmuted message is committed normally'
);

set local role postgres;
select ok(
  not (select member.is_archived
       from public.v1_chat_members member
       where member.conversation_id =
           (select conversation_id from v1_chat_test_direct)
         and member.auth_user_id =
           '10000000-0000-4000-8000-000000000003'::uuid),
  'New unmuted activity restores the recipient archived conversation'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', '@Procurement urgent confirmation required.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000005'::uuid
  )$$,
  'A participant can explicitly mention another participant'
);

set local role postgres;
select is(
  (select count(*) from public.v1_notifications notification
    where notification.recipient_auth_user_id =
        '10000000-0000-4000-8000-000000000003'::uuid
      and notification.event_code = 'team_chat_mention'),
  1::bigint,
  'An explicit mention remains alerting even when normal messages are muted'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'group', 'title', 'Unauthorized group',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000006'::uuid
  )$$,
  '42501', 'V1_CHAT_GROUP_CREATE_DENIED',
  'Site Engineer cannot create a Working Group'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'group', 'title', 'Delivery Coordination',
      'description', 'Temporary working group',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000002',
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000007'::uuid
  )$$,
  'Project Manager can create a Working Group'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'group', 'title', 'SME Coordination',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000001'
      )
    ), '38500000-0000-4000-8000-000000000008'::uuid
  )$$,
  'Senior Mechanical Engineer can create a Working Group'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'group', 'title', 'Admin Coordination',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000001'
      )
    ), '38500000-0000-4000-8000-000000000009'::uuid
  )$$,
  'Admin can create a Working Group'
);

set local role postgres;
create temporary table v1_chat_test_group as
select id as conversation_id
from public.v1_chat_conversations
where kind = 'group' and title = 'Delivery Coordination';
grant select on table v1_chat_test_group to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select lives_ok(
  $$select public.v1_update_chat_group(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_group),
      'title', 'Delivery Coordination Updated',
      'description', 'Controlled participant update',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000002',
        '10000000-0000-4000-8000-000000000003',
        '10000000-0000-4000-8000-000000000001'
      )
    ), '38500000-0000-4000-8000-000000000010'::uuid
  )$$,
  'Working Group owner can update controlled participants'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_update_chat_group(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_group),
      'title', 'Unauthorized change',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000003'
      )
    ), '38500000-0000-4000-8000-000000000011'::uuid
  )$$,
  '42501', 'V1_CHAT_GROUP_UPDATE_DENIED',
  'A normal Working Group member cannot manage participants'
);
select throws_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_group),
      'body', 'Invalid cross-conversation reply.',
      'reply_to_message_id',
        (select message_id from v1_chat_test_direct_message),
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000024'::uuid
  )$$,
  '22023', 'V1_CHAT_REPLY_INVALID',
  'A reply parent from another conversation is rejected'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'announcement', 'title', 'Operational Notice',
      'description', 'Read-only operational announcement',
      'participant_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000012'::uuid
  )$$,
  'Admin can create an organization announcement'
);

set local role postgres;
create temporary table v1_chat_test_announcement as
select id as conversation_id
from public.v1_chat_conversations
where kind = 'announcement' and title = 'Operational Notice';
grant select on table v1_chat_test_announcement to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_announcement), null, 50
  )$$,
  'An active organization user can read the Admin announcement channel'
);
select throws_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_announcement),
      'body', 'Unauthorized announcement.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000013'::uuid
  )$$,
  '42501', 'V1_CHAT_ANNOUNCEMENT_POST_DENIED',
  'Non-Admin announcement composer is server-enforced read-only'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_announcement),
      'body', 'Approved operational announcement.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000014'::uuid
  )$$,
  'Admin can publish an announcement message'
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
      "project_ref":"CHAT-001",
      "name":"Team Chat Security Project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Chat participant"
      }],
      "buildings":[{"code":"chat","name":"Chat Building"}],
      "attachments":[]
    }'::jsonb,
    '38500000-0000-4000-8000-000000000015'::uuid
  )$$,
  'Project fixture is created through its trusted command'
);
select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'CHAT-001'),
      'state', 'active', 'expected_version', 1,
      'reason', 'Ready for chat testing'
    ), '38500000-0000-4000-8000-000000000016'::uuid
  )$$,
  'Project fixture is activated'
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'project',
      'project_id', (select id from public.v1_projects
        where project_ref = 'CHAT-001'),
      'participant_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000017'::uuid
  )$$,
  'Project Chat is created canonically from authorized Project access'
);
select lives_ok(
  $$select public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'project',
      'project_id', (select id from public.v1_projects
        where project_ref = 'CHAT-001'),
      'participant_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000025'::uuid
  )$$,
  'A simultaneous-style Project Chat request returns the canonical channel'
);

set local role postgres;
create temporary table v1_chat_test_project as
select conversation.id as conversation_id, conversation.project_id
from public.v1_chat_conversations conversation
join public.v1_projects project on project.id = conversation.project_id
where conversation.kind = 'project' and project.project_ref = 'CHAT-001';
grant select on table v1_chat_test_project to authenticated;
select is(
  (select count(*) from public.v1_chat_conversations conversation
   where conversation.kind = 'project'
     and conversation.project_id = (select project_id from v1_chat_test_project)),
  1::bigint,
  'One Project has exactly one canonical Team Chat channel'
);
select ok(
  exists (
    select 1 from public.v1_chat_members member
    where member.conversation_id = (
      select conversation_id from v1_chat_test_project
    ) and member.auth_user_id =
      '10000000-0000-4000-8000-000000000002'::uuid
      and member.left_at is null
  ),
  'Project Chat synchronizes the assigned engineering team'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_project), null, 50
  )$$,
  'An assigned Site Engineer can read the Project Chat'
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Open the linked Project for the controlled record.',
      'linked_entity_type', 'project',
      'linked_entity_id', (select project_id from v1_chat_test_project),
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000026'::uuid
  )$$,
  'An authorized participant may add a shortcut to a readable Yorks record'
);

set local role postgres;
update public.v1_project_members member
set effective_from = member.effective_from - interval '1 second',
    effective_to = clock_timestamp(),
    revoked_by_auth_user_id =
      '10000000-0000-4000-8000-000000000001'::uuid,
    revoked_by_role = 'project_engineer',
    revoked_reason = 'Chat revocation test'
where member.project_id = (select project_id from v1_chat_test_project)
  and member.member_auth_user_id =
    '10000000-0000-4000-8000-000000000002'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_project), null, 50
  )$$,
  '42501', 'V1_CHAT_READ_DENIED',
  'Project membership revocation blocks future Chat access without deleting history'
);
select throws_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'A Chat shortcut must not bypass revoked Project access.',
      'linked_entity_type', 'project',
      'linked_entity_id', (select project_id from v1_chat_test_project),
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000027'::uuid
  )$$,
  '42501', 'V1_CHAT_LINK_DENIED',
  'Chat does not grant access to a linked Project after authority is revoked'
);

select lives_ok(
  $$select public.v1_prepare_chat_attachment(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'file_name', 'delivery-note.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('a', 64)
    ), '38500000-0000-4000-8000-000000000018'::uuid
  )$$,
  'A participant prepares a scoped private attachment intent'
);

set local role postgres;
create temporary table v1_chat_test_attachment as
select id as attachment_id, object_path
from public.v1_chat_attachment_upload_intents
where original_file_name = 'delivery-note.pdf';
grant select on table v1_chat_test_attachment to authenticated, service_role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values (
      'yorks-chat-attachments',
      (select object_path from v1_chat_test_attachment),
      '10000000-0000-4000-8000-000000000002',
      '{"size":12,"mimetype":"application/pdf"}'::jsonb
    )$$,
  'Storage accepts exactly the actor-scoped attachment object path'
);
select throws_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Unverified attachment',
      'attachment_ids', jsonb_build_array(
        (select attachment_id from v1_chat_test_attachment)
      ),
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000019'::uuid
  )$$,
  '22023', 'V1_CHAT_ATTACHMENT_NOT_READY',
  'A client cannot bind an attachment before server-side byte verification'
);

set local role service_role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000000","role":"service_role"}',
  true
);
select throws_ok(
  $$select public.v1_verify_chat_attachment_upload(
    (select attachment_id from v1_chat_test_attachment),
    repeat('b', 64), 12, 'application/pdf'
  )$$,
  '22023', 'V1_CHAT_UPLOAD_VERIFICATION_FAILED',
  'The service finalizer rejects a mismatched byte digest'
);
select lives_ok(
  $$select public.v1_verify_chat_attachment_upload(
    (select attachment_id from v1_chat_test_attachment),
    repeat('a', 64), 12, 'application/pdf'
  )$$,
  'The service finalizer accepts matching verified object metadata and digest'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'body', 'Verified delivery note attached.',
      'attachment_ids', jsonb_build_array(
        (select attachment_id from v1_chat_test_attachment)
      ),
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38500000-0000-4000-8000-000000000020'::uuid
  )$$,
  'A verified attachment is bound once to the immutable Chat message'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_download_chat_attachment(
    (select attachment_id from v1_chat_test_attachment)
  )$$,
  'Another active thread participant receives authorized download coordinates'
);
select is(
  jsonb_array_length(public.v1_search_chat('delivery note', 50)), 1,
  'Server-side search finds authorized message history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  jsonb_array_length(public.v1_search_chat('delivery-note', 50)), 0,
  'Search does not leak private Direct attachment or message metadata to Admin'
);
select throws_ok(
  $$select public.v1_update_chat_group(
    jsonb_build_object(
      'conversation_id', (select conversation_id from v1_chat_test_direct),
      'title', 'Three-person Direct',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000001'
      )
    ), '38500000-0000-4000-8000-000000000021'::uuid
  )$$,
  '42501', 'V1_CHAT_GROUP_UPDATE_DENIED',
  'A Direct Message cannot be converted into a three-person group'
);

set local role postgres;
insert into public.v1_chat_messages (
  id, conversation_id, kind, sender_auth_user_id, sender_exact_role,
  sender_display_name_snapshot, body, created_at
)
select gen_random_uuid(),
  (select conversation_id from v1_chat_test_direct),
  'message',
  '10000000-0000-4000-8000-000000000002'::uuid,
  'site_engineer',
  'Site Engineer',
  format('Pagination fixture %s', item),
  clock_timestamp() + (item || ' seconds')::interval
from generate_series(1, 12) item;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  jsonb_array_length(public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_direct), null, 5
  ) -> 'messages'),
  5,
  'Conversation reads return only the requested newest message page'
);
select is(
  jsonb_array_length(public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_direct),
    (select min(latest.created_at)
     from (
       select message.created_at
       from public.v1_chat_messages message
       where message.conversation_id =
         (select conversation_id from v1_chat_test_direct)
       order by message.created_at desc, message.id desc
       limit 5
     ) latest),
    5
  ) -> 'messages'),
  5,
  'Cursor pagination returns an older bounded page without full-history fetch'
);

set local role postgres;
update public.v1_profiles profile
set is_active = false
where profile.auth_user_id =
  '10000000-0000-4000-8000-000000000002'::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_test_direct), null, 50
  )$$,
  '42501', 'V1_CHAT_READ_DENIED',
  'An inactive user immediately loses future Chat read authority'
);

select * from finish();
rollback;
