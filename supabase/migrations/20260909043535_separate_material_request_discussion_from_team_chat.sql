-- Keep Material Request discussion inside its record by default.
--
-- The existing chat-backed storage remains intact so no comment, mention,
-- attachment or audit history is rewritten.  The backing conversation is not
-- discoverable in Team Chat until a user explicitly starts that conversation.
-- This is additive and reversible: setting is_listed_in_team_chat back to true
-- restores a conversation to the Team Chat register without changing data.

alter table public.v1_chat_conversations
  add column if not exists is_listed_in_team_chat boolean not null default true;

comment on column public.v1_chat_conversations.is_listed_in_team_chat is
  'False for record-only discussion backing threads; true after an explicit Team Chat start.';

-- Existing Material Request conversations were created implicitly by record
-- comments, and there was no prior marker that could prove an explicit start.
-- Hide them from the chat register.  Opening Start team conversation promotes
-- the same retained thread, so no messages or files are lost.
update public.v1_chat_conversations
set is_listed_in_team_chat = false
where kind = 'material_request';

create or replace function public.v1_default_material_request_discussion_hidden()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.kind = 'material_request' then
    new.is_listed_in_team_chat := false;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_default_material_request_discussion_hidden
  on public.v1_chat_conversations;
create trigger v1_default_material_request_discussion_hidden
before insert on public.v1_chat_conversations
for each row execute function
  public.v1_default_material_request_discussion_hidden();

create index if not exists v1_chat_conversations_listed_activity_idx
  on public.v1_chat_conversations (
    is_listed_in_team_chat,
    last_message_at desc,
    created_at desc,
    id desc
  );

create or replace function public.v1_ensure_material_request_discussion(
  p_request_id uuid,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_conversation_id uuid;
  v_response jsonb;
begin
  if v_actor is null
    or p_request_id is null
    or p_idempotency_key is null
    or not public.v1_current_actor_is_active()
    or not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DISCUSSION_DENIED'
      using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('chat-request:' || p_request_id::text, 0)
  );

  select conversation.id into v_conversation_id
  from public.v1_chat_conversations conversation
  where conversation.kind = 'material_request'
    and conversation.material_request_id = p_request_id;

  if v_conversation_id is null then
    v_response := public.v1_create_chat_conversation(
      jsonb_build_object(
        'kind', 'material_request',
        'material_request_id', p_request_id,
        'participant_auth_user_ids', '[]'::jsonb
      ),
      p_idempotency_key
    );
    v_conversation_id := (v_response -> 'conversation' ->> 'id')::uuid;
    update public.v1_chat_conversations conversation
       set is_listed_in_team_chat = false
     where conversation.id = v_conversation_id;
  else
    perform public.v1_sync_chat_context_members(v_conversation_id);
  end if;

  return jsonb_build_object(
    'conversation', public.v1_chat_conversation_json(
      v_conversation_id, v_actor
    )
  );
end;
$$;

create or replace function public.v1_start_material_request_team_conversation(
  p_request_id uuid,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_response jsonb;
  v_conversation_id uuid;
begin
  if v_actor is null
    or p_request_id is null
    or p_idempotency_key is null
    or not public.v1_current_actor_is_active()
    or not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_TEAM_CONVERSATION_DENIED'
      using errcode = '42501';
  end if;

  v_response := public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'material_request',
      'material_request_id', p_request_id,
      'participant_auth_user_ids', '[]'::jsonb
    ),
    p_idempotency_key
  );
  v_conversation_id := (v_response -> 'conversation' ->> 'id')::uuid;

  update public.v1_chat_conversations conversation
     set is_listed_in_team_chat = true,
         updated_at = greatest(conversation.updated_at, clock_timestamp())
   where conversation.id = v_conversation_id;
  perform public.v1_sync_chat_context_members(v_conversation_id);

  return jsonb_build_object(
    'conversation', public.v1_chat_conversation_json(
      v_conversation_id, v_actor
    )
  );
end;
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
      where conversation.is_listed_in_team_chat
        and public.v1_chat_is_active_member(conversation.id, v_actor)
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

create or replace function public.v1_search_chat(
  p_query text,
  p_limit integer default 50
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := btrim(coalesce(p_query, ''));
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_CHAT_SEARCH_DENIED' using errcode = '42501';
  end if;
  if char_length(v_query) < 2 then
    return public.v1_list_chat_conversations();
  end if;
  return coalesce((
    select jsonb_agg(result.payload order by result.is_pinned desc,
      result.has_unread desc, result.activity_at desc, result.id desc)
    from (
      select conversation.id,
        member.is_pinned,
        ((public.v1_chat_conversation_json(
          conversation.id, v_actor
        ) ->> 'unread_count')::integer > 0) as has_unread,
        coalesce(conversation.last_message_at, conversation.created_at)
          as activity_at,
        public.v1_chat_conversation_json(conversation.id, v_actor)
          || jsonb_build_object('search_preview', (
            select message.body
            from public.v1_chat_messages message
            where message.conversation_id = conversation.id
              and message.kind = 'message'
              and to_tsvector('simple', coalesce(message.body, ''))
                @@ plainto_tsquery('simple', v_query)
            order by message.created_at desc, message.id desc limit 1
          )) as payload
      from public.v1_chat_conversations conversation
      join public.v1_chat_members member
        on member.conversation_id = conversation.id
       and member.auth_user_id = v_actor and member.left_at is null
      where conversation.is_listed_in_team_chat
        and public.v1_chat_is_active_member(conversation.id, v_actor)
        and (
          conversation.title ilike '%' || v_query || '%'
          or coalesce(conversation.description, '') ilike '%'
            || v_query || '%'
          or exists (
            select 1 from public.v1_chat_members participant
            where participant.conversation_id = conversation.id
              and participant.left_at is null
              and public.v1_chat_safe_display_name(participant.auth_user_id)
                ilike '%' || v_query || '%'
          )
          or exists (
            select 1 from public.v1_chat_messages message
            where message.conversation_id = conversation.id
              and message.kind = 'message'
              and to_tsvector('simple', coalesce(message.body, ''))
                @@ plainto_tsquery('simple', v_query)
          )
        )
      order by member.is_pinned desc, activity_at desc, conversation.id desc
      limit greatest(1, least(coalesce(p_limit, 50), 100))
    ) result
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.v1_ensure_material_request_discussion(uuid, uuid),
  public.v1_start_material_request_team_conversation(uuid, uuid)
from public, anon;
grant execute on function public.v1_ensure_material_request_discussion(uuid, uuid),
  public.v1_start_material_request_team_conversation(uuid, uuid)
to authenticated, service_role;
