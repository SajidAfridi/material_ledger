-- Yorks performance review: make chat refresh acknowledgements demand-driven.
--
-- Data preservation: projection-only change. No chat row, cursor, message,
-- attachment, notification, audit event or membership is rewritten.
-- Rollback: restore the prior function bodies. Older clients ignore the added
-- JSON key; the trusted acknowledgement RPC and all grants/RLS remain intact.

create or replace function public.v1_chat_conversation_json(
  p_conversation_id uuid,
  p_actor uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', conversation.id,
    'kind', conversation.kind,
    'title', case
      when conversation.kind = 'direct' then coalesce((
        select public.v1_chat_safe_display_name(member.auth_user_id)
        from public.v1_chat_members member
        where member.conversation_id = conversation.id
          and member.auth_user_id <> p_actor and member.left_at is null
        order by member.joined_at limit 1
      ), conversation.title)
      else conversation.title
    end,
    'description', conversation.description,
    'project_id', conversation.project_id,
    'material_request_id', conversation.material_request_id,
    'created_at', conversation.created_at,
    'updated_at', conversation.updated_at,
    'last_message_at', conversation.last_message_at,
    'is_pinned', mine.is_pinned,
    'is_muted', mine.is_muted,
    'is_archived', mine.is_archived,
    'unread_count', (
      select count(*)
      from public.v1_chat_messages unread
      where unread.conversation_id = conversation.id
        and unread.kind = 'message'
        and unread.deleted_at is null
        and unread.sender_auth_user_id <> p_actor
        and unread.created_at > coalesce(
          mine.marked_unread_at,
          mine.last_read_at,
          mine.joined_at
        )
    ),
    'needs_delivery_ack', exists (
      select 1
      from public.v1_chat_messages pending_delivery
      where pending_delivery.conversation_id = conversation.id
        and pending_delivery.kind = 'message'
        and pending_delivery.deleted_at is null
        and pending_delivery.sender_auth_user_id <> p_actor
        and (
          mine.last_delivered_at is null
          or pending_delivery.created_at > mine.last_delivered_at
        )
    ),
    'last_message', (
      select public.v1_chat_message_json(last_message.id, p_actor)
      from public.v1_chat_messages last_message
      where last_message.conversation_id = conversation.id
      order by last_message.created_at desc, last_message.id desc
      limit 1
    ),
    'participant_count', (
      select count(*) from public.v1_chat_members active_member
      where active_member.conversation_id = conversation.id
        and active_member.left_at is null
    )
  )
  from public.v1_chat_conversations conversation
  join public.v1_chat_members mine
    on mine.conversation_id = conversation.id
   and mine.auth_user_id = p_actor
   and mine.left_at is null
  where conversation.id = p_conversation_id;
$$;

create or replace function public.v1_list_chat_conversations()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_CHAT_LIST_DENIED' using errcode = '42501';
  end if;

  -- Materialization guarantees that the protected conversation projection is
  -- evaluated once per row. The previous ORDER BY repeated the full helper,
  -- including unread, receipt, participant and last-message subqueries.
  return coalesce((
    with projected as materialized (
      select
        conversation.id,
        member.is_pinned,
        coalesce(
          conversation.last_message_at,
          conversation.created_at
        ) as activity_at,
        public.v1_chat_conversation_json(
          conversation.id,
          v_actor
        ) as item
      from public.v1_chat_conversations conversation
      join public.v1_chat_members member
        on member.conversation_id = conversation.id
       and member.auth_user_id = v_actor
       and member.left_at is null
      where public.v1_chat_is_active_member(conversation.id, v_actor)
    )
    select jsonb_agg(
      projected.item
      order by
        projected.is_pinned desc,
        ((projected.item ->> 'unread_count')::integer > 0) desc,
        projected.activity_at desc,
        projected.id desc
    )
    from projected
  ), '[]'::jsonb);
end;
$$;

comment on function public.v1_chat_conversation_json(uuid, uuid) is
  'Protected chat summary projection with explicit delivery-ack demand.';

comment on function public.v1_list_chat_conversations() is
  'Lists authorized chat summaries and evaluates each protected projection once.';
