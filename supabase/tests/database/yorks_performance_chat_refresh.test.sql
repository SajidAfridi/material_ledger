begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(9);

select ok(
  pg_get_functiondef(
    'public.v1_list_chat_conversations()'::regprocedure
  ) like '%with projected as materialized%',
  'Chat list materializes each protected conversation projection once'
);

select ok(
  pg_get_functiondef(
    'public.v1_chat_conversation_json(uuid,uuid)'::regprocedure
  ) like '%needs_delivery_ack%',
  'Chat summaries expose demand-driven delivery acknowledgement state'
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
      'kind', 'group',
      'title', 'Performance Review 20260903 1210',
      'description', 'Transaction-scoped delivery acknowledgement proof',
      'participant_auth_user_ids', jsonb_build_array(
        '10000000-0000-4000-8000-000000000002',
        '10000000-0000-4000-8000-000000000003'
      )
    ),
    '39310000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Manager creates an isolated performance-test conversation'
);

set local role postgres;
create temporary table v1_performance_chat_conversation as
select conversation.id as conversation_id
from public.v1_chat_conversations conversation
where conversation.kind = 'group'
  and conversation.title = 'Performance Review 20260903 1210'
order by conversation.created_at desc, conversation.id desc
limit 1;
grant select on table v1_performance_chat_conversation to authenticated;

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
        select conversation_id from v1_performance_chat_conversation
      ),
      'body', 'One pending delivery acknowledgement.',
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', '[]'::jsonb
    ),
    '39310000-0000-4000-8000-000000000002'::uuid
  )$$,
  'A member creates one incoming message for the recipient'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select ok(
  (
    select (item ->> 'needs_delivery_ack')::boolean
    from jsonb_array_elements(public.v1_list_chat_conversations()) item
    where item ->> 'id' = (
      select conversation_id::text from v1_performance_chat_conversation
    )
  ),
  'The exact recipient conversation requests one delivery acknowledgement'
);

select is(
  public.v1_mark_chat_delivered(array[
    (select conversation_id from v1_performance_chat_conversation)
  ]),
  1,
  'The pending delivery cursor advances exactly once'
);

select ok(
  not (
    select (item ->> 'needs_delivery_ack')::boolean
    from jsonb_array_elements(public.v1_list_chat_conversations()) item
    where item ->> 'id' = (
      select conversation_id::text from v1_performance_chat_conversation
    )
  ),
  'The refreshed projection suppresses a redundant acknowledgement'
);

select is(
  public.v1_mark_chat_delivered(array[
    (select conversation_id from v1_performance_chat_conversation)
  ]),
  0,
  'A repeated delivery command remains idempotent'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.v1_list_chat_conversations()) item
    where item ->> 'id' = (
      select conversation_id::text from v1_performance_chat_conversation
    )
  ),
  'An Admin outside the group does not inherit its private projection'
);

select * from finish();
rollback;
