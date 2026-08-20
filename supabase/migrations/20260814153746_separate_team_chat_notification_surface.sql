-- Separate Team Chat attention from the workflow notification centre.
--
-- Chat messages still create recipient-owned notification rows because those
-- rows are the durable, idempotent source for the existing FCM outbox. They are
-- transport acknowledgements only: the Team Chat membership cursor owns chat
-- unread state and the workflow bell must never count or display them.

begin;

create or replace function public.v1_notification_is_chat_transport(
  p_event_code text,
  p_entity_type text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(p_event_code, '') in (
    'team_chat_message',
    'team_chat_mention'
  ) or coalesce(p_entity_type, '') in (
    'chat_message',
    'chat_conversation'
  );
$$;

-- Only native Chat entities resolve into Team Chat. A preserved legacy
-- Material Request notification must continue to open that request rather than
-- being mistaken for a contextual Chat notification.
create or replace function public.v1_resolve_notification_chat_conversation_id(
  p_entity_type text,
  p_entity_id uuid
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case p_entity_type
    when 'chat_message' then (
      select message.conversation_id
      from public.v1_chat_messages message
      where message.id = p_entity_id
    )
    when 'chat_conversation' then p_entity_id
    else null::uuid
  end;
$$;

-- Keep every Team Chat notification addressable by its message/conversation.
-- This also corrects contextual Material Request chat mentions. Preserved
-- pre-Team-Chat mention history retains its original workflow event and route.
create or replace function public.v1_send_chat_message(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_conversation public.v1_chat_conversations%rowtype;
  v_body text := nullif(btrim(coalesce(p_payload ->> 'body', '')), '');
  v_reply_id uuid := nullif(p_payload ->> 'reply_to_message_id', '')::uuid;
  v_link_type text := nullif(p_payload ->> 'linked_entity_type', '');
  v_link_id uuid := nullif(p_payload ->> 'linked_entity_id', '')::uuid;
  v_message_id uuid := gen_random_uuid();
  v_attachment_id uuid;
  v_mention_id uuid;
  v_attachment_count integer := 0;
  v_replay jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'conversation_id', 'body', 'reply_to_message_id',
    'linked_entity_type', 'linked_entity_id', 'attachment_ids',
    'mentioned_auth_user_ids'
  ], 'chat_message_payload');
  select * into v_conversation
  from public.v1_chat_conversations conversation
  where conversation.id = nullif(p_payload ->> 'conversation_id', '')::uuid
  for update;
  if not found or not public.v1_chat_is_active_member(v_conversation.id, v_actor)
    or v_exact_role = '' then
    raise exception 'V1_CHAT_SEND_DENIED' using errcode = '42501';
  end if;
  if v_conversation.kind = 'announcement' and v_exact_role <> 'admin' then
    raise exception 'V1_CHAT_ANNOUNCEMENT_POST_DENIED'
      using errcode = '42501';
  end if;
  if v_body is not null and char_length(v_body) > 4000 then
    raise exception 'V1_CHAT_MESSAGE_TOO_LONG' using errcode = '22023';
  end if;
  if p_payload ? 'attachment_ids' and
    jsonb_typeof(p_payload -> 'attachment_ids') <> 'array' then
    raise exception 'V1_CHAT_ATTACHMENTS_INVALID' using errcode = '22023';
  end if;
  if p_payload ? 'mentioned_auth_user_ids' and
    jsonb_typeof(p_payload -> 'mentioned_auth_user_ids') <> 'array' then
    raise exception 'V1_CHAT_MENTIONS_INVALID' using errcode = '22023';
  end if;
  v_attachment_count := coalesce(jsonb_array_length(
    coalesce(p_payload -> 'attachment_ids', '[]'::jsonb)
  ), 0);
  if v_body is null and v_attachment_count = 0 and v_link_id is null then
    raise exception 'V1_CHAT_EMPTY_MESSAGE' using errcode = '22023';
  end if;
  if v_attachment_count > 10 then
    raise exception 'V1_CHAT_TOO_MANY_ATTACHMENTS' using errcode = '22023';
  end if;
  if (v_link_type is null) <> (v_link_id is null)
    or (v_link_type is not null
      and v_link_type not in ('project', 'material_request')) then
    raise exception 'V1_CHAT_LINK_INVALID' using errcode = '22023';
  end if;
  if v_link_type = 'project' and not public.v1_project_readable(v_link_id) then
    raise exception 'V1_CHAT_LINK_DENIED' using errcode = '42501';
  end if;
  if v_link_type = 'material_request'
    and not public.v1_material_request_readable(v_link_id) then
    raise exception 'V1_CHAT_LINK_DENIED' using errcode = '42501';
  end if;
  if v_reply_id is not null and not exists (
    select 1 from public.v1_chat_messages replied
    where replied.id = v_reply_id
      and replied.conversation_id = v_conversation.id
  ) then
    raise exception 'V1_CHAT_REPLY_INVALID' using errcode = '22023';
  end if;
  v_replay := public.v1_idempotency_get_or_claim(
    'v1_send_chat_message', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;

  insert into public.v1_chat_messages (
    id, conversation_id, sender_auth_user_id, sender_exact_role,
    sender_display_name_snapshot, body, reply_to_message_id,
    linked_entity_type, linked_entity_id
  ) values (
    v_message_id, v_conversation.id, v_actor, v_exact_role,
    public.v1_chat_safe_display_name(v_actor), v_body, v_reply_id,
    v_link_type, v_link_id
  );

  for v_attachment_id in
    select distinct value::uuid
    from jsonb_array_elements_text(coalesce(
      p_payload -> 'attachment_ids', '[]'::jsonb
    )) value
  loop
    if not exists (
      select 1
      from public.v1_chat_attachment_upload_intents intent
      join storage.objects object
        on object.bucket_id = intent.bucket_id
       and object.name = intent.object_path
      where intent.id = v_attachment_id
        and intent.conversation_id = v_conversation.id
        and intent.actor_auth_user_id = v_actor
        and intent.finalized_at is null
        and intent.verified_at is not null
        and intent.expires_at > clock_timestamp()
        and coalesce((object.metadata ->> 'size')::bigint, intent.byte_size)
          = intent.byte_size
        and coalesce(object.metadata ->> 'mimetype', intent.mime_type)
          = intent.mime_type
    ) then
      raise exception 'V1_CHAT_ATTACHMENT_NOT_READY' using errcode = '22023';
    end if;
    insert into public.v1_chat_attachments (
      id, message_id, conversation_id, bucket_id, object_path,
      original_file_name, mime_type, byte_size, sha256,
      uploaded_by_auth_user_id
    )
    select intent.id, v_message_id, intent.conversation_id,
      intent.bucket_id, intent.object_path, intent.original_file_name,
      intent.mime_type, intent.byte_size, intent.sha256, v_actor
    from public.v1_chat_attachment_upload_intents intent
    where intent.id = v_attachment_id;
    update public.v1_chat_attachment_upload_intents intent
       set finalized_at = clock_timestamp()
     where intent.id = v_attachment_id;
  end loop;

  for v_mention_id in
    select distinct value::uuid
    from jsonb_array_elements_text(coalesce(
      p_payload -> 'mentioned_auth_user_ids', '[]'::jsonb
    )) value
  loop
    if v_mention_id <> v_actor and exists (
      select 1 from public.v1_chat_members member
      where member.conversation_id = v_conversation.id
        and member.auth_user_id = v_mention_id and member.left_at is null
    ) then
      insert into public.v1_chat_message_mentions (
        message_id, mentioned_auth_user_id
      ) values (v_message_id, v_mention_id)
      on conflict do nothing;
    end if;
  end loop;

  update public.v1_chat_conversations conversation
     set last_message_at = clock_timestamp(),
         updated_at = clock_timestamp()
   where conversation.id = v_conversation.id;
  update public.v1_chat_members member
     set last_read_at = clock_timestamp(),
         marked_unread_at = null,
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = v_conversation.id
     and member.auth_user_id = v_actor;
  update public.v1_chat_members member
     set is_archived = false,
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = v_conversation.id
     and member.auth_user_id <> v_actor
     and member.left_at is null
     and not member.is_muted
     and member.is_archived;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id,
    project_id, created_at
  )
  select member.auth_user_id,
    case when exists (
      select 1 from public.v1_chat_message_mentions mention
      where mention.message_id = v_message_id
        and mention.mentioned_auth_user_id = member.auth_user_id
    ) then 'team_chat_mention'
      else 'team_chat_message' end,
    'chat_message',
    v_message_id,
    v_conversation.project_id,
    clock_timestamp()
  from public.v1_chat_members member
  join public.v1_profiles profile
    on profile.auth_user_id = member.auth_user_id and profile.is_active
  where member.conversation_id = v_conversation.id
    and member.auth_user_id <> v_actor
    and member.left_at is null
    and (
      not member.is_muted
      or exists (
        select 1 from public.v1_chat_message_mentions mention
        where mention.message_id = v_message_id
          and mention.mentioned_auth_user_id = member.auth_user_id
      )
    );

  v_response := jsonb_build_object(
    'message', public.v1_chat_message_json(v_message_id, v_actor),
    'conversation', public.v1_chat_conversation_json(
      v_conversation.id, v_actor
    )
  );
  perform public.v1_write_audit_event(
    'chat_message_sent', 'chat_message', v_message_id,
    v_conversation.project_id, null,
    jsonb_build_object(
      'conversation_id', v_conversation.id,
      'has_body', v_body is not null,
      'attachment_count', v_attachment_count,
      'has_link', v_link_id is not null
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_send_chat_message', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_list_my_notifications(
  p_limit integer default 100
)
returns table (
  notification_id uuid,
  event_code text,
  entity_type text,
  entity_id uuid,
  request_id uuid,
  project_id uuid,
  chat_conversation_id uuid,
  created_at timestamptz,
  seen_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_LIST_DENIED' using errcode = '42501';
  end if;
  return query
  select notification.id,
    notification.event_code,
    notification.entity_type,
    notification.entity_id,
    public.v1_resolve_notification_request_id(
      notification.entity_type, notification.entity_id
    ),
    notification.project_id,
    public.v1_resolve_notification_chat_conversation_id(
      notification.entity_type, notification.entity_id
    ),
    notification.created_at,
    notification.seen_at
  from public.v1_notifications notification
  where notification.recipient_auth_user_id = v_actor
    and not public.v1_notification_is_chat_transport(
      notification.event_code, notification.entity_type
    )
  order by notification.created_at desc, notification.id desc
  limit greatest(1, least(coalesce(p_limit, 100), 200));
end;
$$;

create or replace function public.v1_mark_all_notifications_seen()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_updated integer := 0;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_SEEN_DENIED' using errcode = '42501';
  end if;

  update public.v1_notifications notification
     set seen_at = clock_timestamp()
   where notification.recipient_auth_user_id = v_actor
     and notification.seen_at is null
     and not public.v1_notification_is_chat_transport(
       notification.event_code, notification.entity_type
     );
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

create or replace function public.v1_mark_chat_read(
  p_conversation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.v1_chat_is_active_member(p_conversation_id, auth.uid()) then
    raise exception 'V1_CHAT_READ_DENIED' using errcode = '42501';
  end if;
  update public.v1_chat_members member
     set last_read_at = clock_timestamp(),
         marked_unread_at = null,
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = p_conversation_id
     and member.auth_user_id = auth.uid();
  update public.v1_notifications notification
     set seen_at = coalesce(notification.seen_at, clock_timestamp())
   where notification.recipient_auth_user_id = auth.uid()
     and notification.seen_at is null
     and public.v1_notification_is_chat_transport(
       notification.event_code, notification.entity_type
     )
     and (
       (notification.entity_type = 'chat_message' and exists (
         select 1 from public.v1_chat_messages message
         where message.id = notification.entity_id
           and message.conversation_id = p_conversation_id
       ))
       or (notification.entity_type = 'chat_conversation'
         and notification.entity_id = p_conversation_id)
     );
  return true;
end;
$$;

revoke all on function public.v1_notification_is_chat_transport(text, text)
  from public, anon, authenticated;
revoke all on function public.v1_list_my_notifications(integer),
  public.v1_mark_all_notifications_seen(),
  public.v1_mark_chat_read(uuid)
  from public, anon, authenticated;

grant execute on function public.v1_list_my_notifications(integer),
  public.v1_mark_all_notifications_seen(),
  public.v1_mark_chat_read(uuid)
  to authenticated;

comment on function public.v1_notification_is_chat_transport(text, text) is
  'Classifies private Team Chat push transport rows; these never enter the workflow notification centre.';

commit;

-- Rollback: restore the five prior function definitions from migrations
-- 20260813213940 and 20260814114626, then drop
-- public.v1_notification_is_chat_transport(text,text). Notification, chat,
-- outbox and seen/read history remain preserved; no row rewrite is required.
