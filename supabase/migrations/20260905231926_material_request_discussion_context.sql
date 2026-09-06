-- Material Request discussion hardening.
--
-- This keeps Team Chat as the canonical message/attachment store while making
-- the Material Request detail a first-class discussion surface. Existing
-- messages and attachments are preserved. The only new relation stores an
-- optional, request-scoped record reference for each comment.

create table if not exists public.v1_material_request_comment_contexts (
  comment_id uuid primary key references public.v1_chat_messages (id)
    on delete restrict,
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  context_type text not null check (context_type in (
    'material_request', 'request_line', 'arrangement', 'dispatch',
    'receipt_review', 'delivery_order', 'material_return'
  )),
  context_entity_id uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (context_type = 'material_request' and context_entity_id = request_id)
      or context_type <> 'material_request'
  )
);

create index if not exists v1_mr_comment_context_request_idx
  on public.v1_material_request_comment_contexts (
    request_id, created_at desc, comment_id desc
  );

alter table public.v1_material_request_comment_contexts enable row level security;
revoke all on table public.v1_material_request_comment_contexts
  from public, anon, authenticated;
grant all on table public.v1_material_request_comment_contexts to service_role;

create or replace function public.v1_material_request_context_valid(
  p_request_id uuid,
  p_context_type text,
  p_context_entity_id uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_context_type
    when 'material_request' then p_context_entity_id = p_request_id
    when 'request_line' then exists (
      select 1 from public.v1_material_request_lines line
      where line.id = p_context_entity_id and line.request_id = p_request_id
    )
    when 'arrangement' then exists (
      select 1 from public.v1_procurement_arrangements arrangement
      where arrangement.id = p_context_entity_id
        and arrangement.request_id = p_request_id
    )
    when 'dispatch' then exists (
      select 1 from public.v1_material_dispatches dispatch
      where dispatch.id = p_context_entity_id
        and dispatch.request_id = p_request_id
    )
    when 'receipt_review' then exists (
      select 1
      from public.v1_receipt_reviews review
      join public.v1_material_dispatches dispatch
        on dispatch.id = review.dispatch_id
      where review.id = p_context_entity_id
        and dispatch.request_id = p_request_id
    )
    when 'delivery_order' then exists (
      select 1
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch
        on dispatch.id = delivery_order.dispatch_id
      where delivery_order.id = p_context_entity_id
        and dispatch.request_id = p_request_id
    )
    when 'material_return' then exists (
      select 1 from public.v1_material_returns material_return
      where material_return.id = p_context_entity_id
        and material_return.request_id = p_request_id
    )
    else false
  end;
$$;

create or replace function public.v1_material_request_comment_json(
  p_comment_id uuid,
  p_actor uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', comment_record.id,
    'request_id', comment_record.request_id,
    'conversation_id', message.conversation_id,
    'body', comment_record.body,
    'author_auth_user_id', comment_record.author_auth_user_id,
    'author_role', comment_record.author_role,
    'author_exact_role', comment_record.author_exact_role,
    'author_display_name', comment_record.author_display_name_snapshot,
    'created_at', comment_record.created_at,
    'parent_comment_id', message.reply_to_message_id,
    'reply_preview', case when replied.id is null then null else
      jsonb_build_object(
        'id', replied.id,
        'sender_display_name', replied.sender_display_name_snapshot,
        'body', replied.body
      ) end,
    'context', case when comment_context.comment_id is null then null else
      jsonb_build_object(
        'type', comment_context.context_type,
        'entity_id', comment_context.context_entity_id
      ) end,
    'mentions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', mention.mentioned_auth_user_id,
        'display_name', mention.mentioned_display_name_snapshot,
        'exact_role', mention.mentioned_exact_role
      ) order by mention.mentioned_display_name_snapshot,
        mention.mentioned_auth_user_id)
      from public.v1_material_request_comment_mentions mention
      where mention.comment_id = comment_record.id
    ), '[]'::jsonb),
    'attachments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', attachment.id,
        'file_name', attachment.original_file_name,
        'mime_type', attachment.mime_type,
        'byte_size', attachment.byte_size
      ) order by attachment.created_at, attachment.id)
      from public.v1_chat_attachments attachment
      where attachment.message_id = message.id
    ), '[]'::jsonb)
  )
  from public.v1_material_request_comments comment_record
  join public.v1_chat_messages message on message.id = comment_record.id
  left join public.v1_chat_messages replied
    on replied.id = message.reply_to_message_id
  left join public.v1_material_request_comment_contexts comment_context
    on comment_context.comment_id = message.id
  where comment_record.id = p_comment_id
    and public.v1_material_request_readable(comment_record.request_id)
    and p_actor = auth.uid();
$$;

create or replace function public.v1_material_request_comment_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with recent as (
    select comment_record.id, comment_record.created_at
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
    order by comment_record.created_at desc, comment_record.id desc
    limit 20
  )
  select coalesce(jsonb_agg(
    public.v1_material_request_comment_json(recent.id, auth.uid())
    order by recent.created_at, recent.id
  ), '[]'::jsonb)
  from recent;
$$;

create or replace function public.v1_list_material_request_comments(
  p_request_id uuid,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_has_more boolean;
  v_oldest_created_at timestamptz;
  v_oldest_id uuid;
begin
  if not public.v1_material_request_readable(p_request_id)
    or (p_before_created_at is null) <> (p_before_id is null) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_PAGE_DENIED'
      using errcode = '42501';
  end if;
  with page as (
    select comment_record.id, comment_record.created_at
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
      and (p_before_created_at is null or
        (comment_record.created_at, comment_record.id)
          < (p_before_created_at, p_before_id))
    order by comment_record.created_at desc, comment_record.id desc
    limit v_limit + 1
  ), kept as (
    select * from page order by created_at desc, id desc limit v_limit
  )
  select coalesce(jsonb_agg(
      public.v1_material_request_comment_json(kept.id, auth.uid())
      order by kept.created_at, kept.id
    ), '[]'::jsonb),
    count(*) = v_limit and exists (select 1 from page offset v_limit),
    min(kept.created_at)
  into v_items, v_has_more, v_oldest_created_at
  from kept;
  if v_oldest_created_at is not null then
    select kept.id into v_oldest_id
    from (
      select comment_record.id, comment_record.created_at
      from public.v1_material_request_comments comment_record
      where comment_record.request_id = p_request_id
        and (p_before_created_at is null or
          (comment_record.created_at, comment_record.id)
            < (p_before_created_at, p_before_id))
      order by comment_record.created_at desc, comment_record.id desc
      limit v_limit
    ) kept
    order by kept.created_at, kept.id limit 1;
  end if;
  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_before_created_at', case when v_has_more then v_oldest_created_at end,
    'next_before_id', case when v_has_more then v_oldest_id end
  );
end;
$$;

create or replace function public.v1_get_material_request_comment_window(
  p_request_id uuid,
  p_comment_id uuid,
  p_radius integer default 10
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_radius integer := least(greatest(coalesce(p_radius, 10), 1), 25);
  v_anchor bigint;
  v_items jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_WINDOW_DENIED'
      using errcode = '42501';
  end if;
  with ordered as (
    select comment_record.id,
      row_number() over (
        order by comment_record.created_at, comment_record.id
      ) as row_number
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
  )
  select ordered.row_number into v_anchor
  from ordered where ordered.id = p_comment_id;
  if v_anchor is null then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_NOT_FOUND'
      using errcode = '22023';
  end if;
  with ordered as (
    select comment_record.id, comment_record.created_at,
      row_number() over (
        order by comment_record.created_at, comment_record.id
      ) as row_number
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
  )
  select coalesce(jsonb_agg(
      public.v1_material_request_comment_json(ordered.id, auth.uid())
      order by ordered.created_at, ordered.id
    ), '[]'::jsonb)
  into v_items
  from ordered
  where ordered.row_number between v_anchor - v_radius and v_anchor + v_radius;
  return jsonb_build_object('items', v_items, 'anchor_id', p_comment_id);
end;
$$;

create or replace function public.v1_add_material_request_comment(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_body text;
  v_mentions jsonb;
  v_attachments jsonb;
  v_parent_id uuid;
  v_context_type text;
  v_context_id uuid;
  v_existing jsonb;
  v_thread_response jsonb;
  v_message_response jsonb;
  v_conversation_id uuid;
  v_message_id uuid;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'request_id', 'body', 'mentioned_auth_user_ids', 'attachment_ids',
    'parent_comment_id', 'context_type', 'context_entity_id'
  ], 'material_request_comment');
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_body := nullif(btrim(coalesce(p_payload ->> 'body', '')), '');
  v_mentions := coalesce(p_payload -> 'mentioned_auth_user_ids', '[]'::jsonb);
  v_attachments := coalesce(p_payload -> 'attachment_ids', '[]'::jsonb);
  v_parent_id := nullif(p_payload ->> 'parent_comment_id', '')::uuid;
  v_context_type := coalesce(nullif(p_payload ->> 'context_type', ''),
    'material_request');
  v_context_id := coalesce(
    nullif(p_payload ->> 'context_entity_id', '')::uuid, v_request_id
  );
  if v_request_id is null or v_body is null or char_length(v_body) > 4000
    or jsonb_typeof(v_mentions) <> 'array'
    or jsonb_typeof(v_attachments) <> 'array'
    or not public.v1_material_request_readable(v_request_id)
    or not public.v1_material_request_context_valid(
      v_request_id, v_context_type, v_context_id
    ) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_INVALID'
      using errcode = '22023';
  end if;
  if v_parent_id is not null and not exists (
    select 1 from public.v1_material_request_comments parent_comment
    where parent_comment.id = v_parent_id
      and parent_comment.request_id = v_request_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_PARENT_INVALID'
      using errcode = '22023';
  end if;
  -- Replies remain one level deep: replying to a reply targets its root.
  if v_parent_id is not null then
    select coalesce(message.reply_to_message_id, message.id)
      into v_parent_id
    from public.v1_chat_messages message where message.id = v_parent_id;
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_add_material_request_comment', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_thread_response := public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'material_request', 'material_request_id', v_request_id,
      'participant_auth_user_ids', '[]'::jsonb
    ), p_idempotency_key
  );
  v_conversation_id := (v_thread_response -> 'conversation' ->> 'id')::uuid;
  v_message_response := public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', v_conversation_id,
      'body', v_body,
      'reply_to_message_id', v_parent_id,
      'attachment_ids', v_attachments,
      'mentioned_auth_user_ids', v_mentions
    ), p_idempotency_key
  );
  v_message_id := (v_message_response -> 'message' ->> 'id')::uuid;
  insert into public.v1_material_request_comments (
    id, request_id, body, author_auth_user_id, author_role,
    author_exact_role, author_display_name_snapshot, created_at
  )
  select message.id, v_request_id, message.body,
    message.sender_auth_user_id,
    public.v1_canonical_role_from_exact_role(message.sender_exact_role),
    message.sender_exact_role, message.sender_display_name_snapshot,
    message.created_at
  from public.v1_chat_messages message where message.id = v_message_id
  on conflict (id) do nothing;
  insert into public.v1_material_request_comment_mentions (
    comment_id, mentioned_auth_user_id, mentioned_display_name_snapshot,
    mentioned_exact_role, created_at
  )
  select mention.message_id, mention.mentioned_auth_user_id,
    public.v1_chat_safe_display_name(mention.mentioned_auth_user_id),
    public.v1_chat_exact_role(mention.mentioned_auth_user_id),
    mention.created_at
  from public.v1_chat_message_mentions mention
  where mention.message_id = v_message_id
  on conflict do nothing;
  insert into public.v1_material_request_comment_contexts (
    comment_id, request_id, context_type, context_entity_id
  ) values (v_message_id, v_request_id, v_context_type, v_context_id)
  on conflict (comment_id) do nothing;
  -- Mentions made from the request discussion belong in the workflow
  -- notification centre and return to the exact comment, not Team Chat.
  update public.v1_notifications notification
     set event_code = 'material_request_mentioned'
   where notification.entity_type = 'chat_message'
     and notification.entity_id = v_message_id
     and notification.event_code = 'team_chat_mention';
  perform public.v1_write_audit_event(
    'material_request_commented', 'chat_message', v_message_id,
    (select request.project_id from public.v1_material_requests request
      where request.id = v_request_id),
    null,
    jsonb_build_object(
      'request_id', v_request_id,
      'conversation_id', v_conversation_id,
      'mention_count', jsonb_array_length(v_mentions),
      'attachment_count', jsonb_array_length(v_attachments),
      'is_reply', v_parent_id is not null,
      'context_type', v_context_type,
      'context_entity_id', v_context_id
    ), null, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'comment_id', v_message_id,
    'conversation_id', v_conversation_id,
    'comments', public.v1_material_request_comment_projection(v_request_id)
  );
  perform public.v1_complete_idempotency(
    'v1_add_material_request_comment', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_resolve_notification_request_id(
  p_entity_type text,
  p_entity_id uuid
) returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case p_entity_type
    when 'material_request' then p_entity_id
    when 'procurement_arrangement' then (
      select arrangement.request_id from public.v1_procurement_arrangements arrangement
      where arrangement.id = p_entity_id
    )
    when 'material_dispatch' then (
      select dispatch.request_id from public.v1_material_dispatches dispatch
      where dispatch.id = p_entity_id
    )
    when 'receipt_review' then (
      select dispatch.request_id from public.v1_receipt_reviews review
      join public.v1_material_dispatches dispatch on dispatch.id = review.dispatch_id
      where review.id = p_entity_id
    )
    when 'material_return' then (
      select material_return.request_id from public.v1_material_returns material_return
      where material_return.id = p_entity_id
    )
    when 'delivery_order' then (
      select dispatch.request_id from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch on dispatch.id = delivery_order.dispatch_id
      where delivery_order.id = p_entity_id
    )
    when 'chat_message' then (
      select conversation.material_request_id
      from public.v1_chat_messages message
      join public.v1_chat_conversations conversation
        on conversation.id = message.conversation_id
      where message.id = p_entity_id
        and conversation.kind = 'material_request'
    )
    else null::uuid
  end;
$$;

create or replace function public.v1_notification_unread_count(
  p_actor uuid
) returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select least(999, greatest(0,
    (
      select count(*)
      from public.v1_notifications notification
      where notification.recipient_auth_user_id = p_actor
        and notification.seen_at is null
        and notification.event_code not in (
          'team_chat_message', 'team_chat_mention'
        )
    ) + (
      select count(*)
      from public.v1_chat_members member
      join public.v1_chat_messages message
        on message.conversation_id = member.conversation_id
      where member.auth_user_id = p_actor
        and member.left_at is null
        and not member.is_muted
        and message.kind = 'message'
        and message.sender_auth_user_id <> p_actor
        and message.created_at > coalesce(
          member.marked_unread_at,
          member.last_read_at,
          member.joined_at
        )
        and not exists (
          select 1 from public.v1_notifications notification
          where notification.recipient_auth_user_id = p_actor
            and notification.entity_type = 'chat_message'
            and notification.entity_id = message.id
            and notification.event_code = 'material_request_mentioned'
        )
    )
  ))::integer;
$$;

-- Security-definer helpers and mutations are callable only through the exact
-- roles required by the application. Internal JSON helpers are never exposed.
revoke all on function public.v1_material_request_context_valid(uuid, text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_comment_json(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_material_request_comment_window(uuid, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.v1_get_material_request_comment_window(uuid, uuid, integer)
  to authenticated;

-- Rollback: restore the prior v1_add_material_request_comment,
-- v1_list_material_request_comments, v1_material_request_comment_projection
-- and v1_resolve_notification_request_id bodies, then drop the three helper
-- functions and v1_material_request_comment_contexts. Existing messages,
-- attachments, mentions and notifications remain valid and are not deleted.
