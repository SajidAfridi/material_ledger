begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_chat_message_revisions'::regclass)
  and not has_table_privilege(
    'authenticated', 'public.v1_chat_message_revisions', 'select'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_edit_chat_message(jsonb,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_delete_chat_message(jsonb,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated', 'public.v1_mark_chat_delivered(uuid[])', 'execute'
  ),
  'Message revisions stay private while lifecycle and receipt commands are explicit RPCs'
);

select ok(
  pg_get_functiondef(
    'public.v1_edit_chat_message(jsonb,uuid)'::regprocedure
  ) like '%V1_CHAT_CONTROLLED_MESSAGE_IMMUTABLE%'
  and pg_get_functiondef(
    'public.v1_delete_chat_message(jsonb,uuid)'::regprocedure
  ) like '%V1_CHAT_CONTROLLED_MESSAGE_IMMUTABLE%',
  'Edit and delete commands retain the AT-26 immutable Material Request policy'
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
    ), '38600000-0000-4000-8000-000000000001'::uuid
  )$$,
  'A Direct conversation is created for lifecycle testing'
);

set local role postgres;
create temporary table v1_chat_lifecycle_conversation as
select conversation.id as conversation_id
from public.v1_chat_conversations conversation
where conversation.kind = 'direct'
limit 1;
grant select on table v1_chat_lifecycle_conversation to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', (
        select conversation_id from v1_chat_lifecycle_conversation
      ),
      'body', 'Original dispatch update.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ), '38600000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The sender commits the original message once'
);

set local role postgres;
create temporary table v1_chat_lifecycle_message as
select message.id as message_id
from public.v1_chat_messages message
where message.conversation_id = (
    select conversation_id from v1_chat_lifecycle_conversation
  )
  and message.kind = 'message'
limit 1;
grant select on table v1_chat_lifecycle_message to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select ok(
  (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'can_edit')::boolean
  and (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'can_delete')::boolean
  and (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'recipient_count')::integer = 1
  and (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'delivered_count')::integer = 0,
  'The sender projection exposes authority and starts with a server-sent receipt'
);

select lives_ok(
  $$select public.v1_edit_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'body', 'Updated dispatch timing.',
      'expected_version', 1
    ), '38600000-0000-4000-8000-000000000003'::uuid
  )$$,
  'The original sender can version-edit an ordinary Chat message'
);
select lives_ok(
  $$select public.v1_edit_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'body', 'Updated dispatch timing.',
      'expected_version', 1
    ), '38600000-0000-4000-8000-000000000003'::uuid
  )$$,
  'A lost edit response replays under the same idempotency key'
);

set local role postgres;
select ok(
  (select message.body = 'Updated dispatch timing.'
      and message.version = 2
      and message.edited_at is not null
   from public.v1_chat_messages message
   where message.id = (select message_id from v1_chat_lifecycle_message)),
  'The edit updates only the current version and records its server timestamp'
);
select is(
  (select count(*) from public.v1_chat_message_revisions revision
   where revision.message_id = (
     select message_id from v1_chat_lifecycle_message
   ) and revision.operation = 'edit'),
  1::bigint,
  'An idempotent edit retains exactly one immutable prior-content revision'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_edit_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'body', 'Stale overwrite attempt.',
      'expected_version', 1
    ), '38600000-0000-4000-8000-000000000004'::uuid
  )$$,
  '40001', 'V1_CHAT_MESSAGE_CONFLICT',
  'A competing stale edit fails instead of overwriting current content'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_edit_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'body', 'Recipient rewrite attempt.',
      'expected_version', 2
    ), '38600000-0000-4000-8000-000000000005'::uuid
  )$$,
  '42501', 'V1_CHAT_MESSAGE_EDIT_DENIED',
  'Another active participant cannot edit the sender message'
);
select is(
  public.v1_mark_chat_delivered(array[
    (select conversation_id from v1_chat_lifecycle_conversation)
  ]),
  1,
  'Recipient synchronization advances one delivery cursor'
);
select is(
  public.v1_mark_chat_delivered(array[
    (select conversation_id from v1_chat_lifecycle_conversation)
  ]),
  0,
  'Repeated synchronization does not churn the delivery cursor'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select ok(
  (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'delivered_count')::integer = 1
  and (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'read_count')::integer = 0,
  'The sender sees delivered without a fabricated read receipt'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select is(
  public.v1_mark_chat_read(
    (select conversation_id from v1_chat_lifecycle_conversation)
  ),
  true,
  'Opening the thread advances both recipient delivery and read truth'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'read_count')::integer,
  1,
  'The sender sees the server-owned read cursor from another device'
);
select throws_ok(
  $$update public.v1_chat_messages
       set body = 'Direct table bypass'
     where id = (select message_id from v1_chat_lifecycle_message)$$,
  '42501', 'permission denied for table v1_chat_messages',
  'Authenticated clients cannot bypass the edit RPC through table UPDATE'
);
select throws_ok(
  $$select * from public.v1_chat_message_revisions$$,
  '42501', 'permission denied for table v1_chat_message_revisions',
  'Authenticated clients cannot read retained prior message content'
);

select lives_ok(
  $$select public.v1_delete_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'expected_version', 2
    ), '38600000-0000-4000-8000-000000000006'::uuid
  )$$,
  'The original sender can soft-delete the current message version'
);
select lives_ok(
  $$select public.v1_delete_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'expected_version', 2
    ), '38600000-0000-4000-8000-000000000006'::uuid
  )$$,
  'A lost delete response replays without another lifecycle mutation'
);
select ok(
  (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 -> 'body') = 'null'::jsonb
  and (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'deleted_at') is not null
  and not (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'can_edit')::boolean
  and not (public.v1_get_chat_conversation(
    (select conversation_id from v1_chat_lifecycle_conversation), null, 50
  ) -> 'messages' -> 0 ->> 'can_delete')::boolean,
  'Delete returns a durable non-editable tombstone with no message body'
);

set local role postgres;
select is(
  (select count(*) from public.v1_chat_message_revisions revision
   where revision.message_id = (
     select message_id from v1_chat_lifecycle_message
   )),
  2::bigint,
  'Edit and delete retain two ordered prior-version facts'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_delete_chat_message(
    jsonb_build_object(
      'message_id', (select message_id from v1_chat_lifecycle_message),
      'expected_version', 3
    ), '38600000-0000-4000-8000-000000000007'::uuid
  )$$,
  '42501', 'V1_CHAT_MESSAGE_DELETE_DENIED',
  'Another participant cannot delete the sender tombstone or its history'
);
select throws_ok(
  $$select public.v1_toggle_chat_message_pin(
    (select message_id from v1_chat_lifecycle_message)
  )$$,
  '42501', 'V1_CHAT_PIN_DENIED',
  'A deleted tombstone cannot be newly pinned'
);

select * from finish();
rollback;
