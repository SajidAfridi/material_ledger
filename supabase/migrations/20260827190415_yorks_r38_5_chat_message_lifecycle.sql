-- Yorks R38.5 Team Chat message lifecycle and delivery/read receipts.
--
-- Ordinary collaboration messages may be version-edited or soft-deleted only
-- by their original sender. Material Request discussion remains append-only.
-- Prior content is retained in a private revision relation and deleted messages
-- remain as tombstones, so no committed collaboration history is erased.
-- Delivery and read facts are server-owned member cursors; the client never
-- infers them from presence, socket state or optimistic local state.

begin;

alter table public.v1_chat_members
  add column if not exists last_delivered_at timestamptz;

update public.v1_chat_members member
set last_delivered_at = member.last_read_at
where member.last_delivered_at is null
  and member.last_read_at is not null;

alter table public.v1_chat_messages
  add column if not exists version integer not null default 1,
  add column if not exists edited_at timestamptz,
  add column if not exists deleted_at timestamptz;

alter table public.v1_chat_messages
  drop constraint if exists v1_chat_messages_version_positive_check;
alter table public.v1_chat_messages
  add constraint v1_chat_messages_version_positive_check
  check (version > 0);

create table if not exists public.v1_chat_message_revisions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.v1_chat_messages (id)
    on delete restrict,
  conversation_id uuid not null references public.v1_chat_conversations (id)
    on delete restrict,
  prior_version integer not null check (prior_version > 0),
  operation text not null check (operation in ('edit', 'delete')),
  prior_body text,
  changed_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  changed_by_exact_role text not null,
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (message_id, prior_version),
  unique (changed_by_auth_user_id, operation, idempotency_key)
);

create index if not exists v1_chat_message_revisions_conversation_idx
  on public.v1_chat_message_revisions (conversation_id, created_at, id);

alter table public.v1_chat_message_revisions enable row level security;
revoke all on table public.v1_chat_message_revisions
from public, anon, authenticated;

create or replace function public.v1_chat_message_json(
  p_message_id uuid,
  p_actor uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', message.id,
    'conversation_id', message.conversation_id,
    'kind', message.kind,
    'system_event_code', message.system_event_code,
    'sender_auth_user_id', message.sender_auth_user_id,
    'sender_display_name', message.sender_display_name_snapshot,
    'sender_exact_role', message.sender_exact_role,
    'body', case when message.deleted_at is null then message.body end,
    'reply_to_message_id', message.reply_to_message_id,
    'linked_entity_type', case when message.deleted_at is null
      then message.linked_entity_type end,
    'linked_entity_id', case when message.deleted_at is null
      then message.linked_entity_id end,
    'created_at', message.created_at,
    'version', message.version,
    'edited_at', message.edited_at,
    'deleted_at', message.deleted_at,
    'is_mine', message.sender_auth_user_id = p_actor,
    'can_edit', message.kind = 'message'
      and message.deleted_at is null
      and message.sender_auth_user_id = p_actor
      and conversation.kind <> 'material_request',
    'can_delete', message.kind = 'message'
      and message.deleted_at is null
      and message.sender_auth_user_id = p_actor
      and conversation.kind <> 'material_request',
    'is_pinned', message.deleted_at is null and exists (
      select 1 from public.v1_chat_message_pins pin
      where pin.conversation_id = message.conversation_id
        and pin.message_id = message.id
    ),
    'acknowledgement_count', case when message.deleted_at is null then (
      select count(*) from public.v1_chat_message_acknowledgements ack
      where ack.message_id = message.id
    ) else 0 end,
    'acknowledged_by_me', message.deleted_at is null and exists (
      select 1 from public.v1_chat_message_acknowledgements ack
      where ack.message_id = message.id and ack.auth_user_id = p_actor
    ),
    'recipient_count', case
      when message.kind = 'message' and message.sender_auth_user_id = p_actor
        then receipt.recipient_count
      else 0
    end,
    'delivered_count', case
      when message.kind = 'message' and message.sender_auth_user_id = p_actor
        then receipt.delivered_count
      else 0
    end,
    'read_count', case
      when message.kind = 'message' and message.sender_auth_user_id = p_actor
        then receipt.read_count
      else 0
    end,
    'mentions', case when message.deleted_at is not null then '[]'::jsonb
      else coalesce((
        select jsonb_agg(
          mention.mentioned_auth_user_id
          order by mention.mentioned_auth_user_id
        )
        from public.v1_chat_message_mentions mention
        where mention.message_id = message.id
      ), '[]'::jsonb)
    end,
    'attachments', case when message.deleted_at is not null then '[]'::jsonb
      else coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', attachment.id,
          'file_name', attachment.original_file_name,
          'mime_type', attachment.mime_type,
          'byte_size', attachment.byte_size
        ) order by attachment.created_at, attachment.id)
        from public.v1_chat_attachments attachment
        where attachment.message_id = message.id
      ), '[]'::jsonb)
    end,
    'reply_preview', (
      select jsonb_build_object(
        'id', replied.id,
        'sender_display_name', replied.sender_display_name_snapshot,
        'body', case when replied.deleted_at is null then replied.body end,
        'is_deleted', replied.deleted_at is not null
      )
      from public.v1_chat_messages replied
      where replied.id = message.reply_to_message_id
    )
  )
  from public.v1_chat_messages message
  join public.v1_chat_conversations conversation
    on conversation.id = message.conversation_id
  left join lateral (
    select
      count(*)::integer as recipient_count,
      count(*) filter (
        where member.last_delivered_at >= message.created_at
      )::integer as delivered_count,
      count(*) filter (
        where member.last_read_at >= message.created_at
      )::integer as read_count
    from public.v1_chat_members member
    where member.conversation_id = message.conversation_id
      and member.auth_user_id <> message.sender_auth_user_id
      and member.left_at is null
      and member.joined_at <= message.created_at
  ) receipt on true
  where message.id = p_message_id;
$$;

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

create or replace function public.v1_mark_chat_delivered(
  p_conversation_ids uuid[]
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_updated integer := 0;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_CHAT_DELIVERY_DENIED' using errcode = '42501';
  end if;

  update public.v1_chat_members member
     set last_delivered_at = delivered.latest_message_at
    from (
      select message.conversation_id,
        max(message.created_at) as latest_message_at
      from public.v1_chat_messages message
      where message.conversation_id = any(
          coalesce(p_conversation_ids, array[]::uuid[])
        )
        and message.kind = 'message'
        and message.deleted_at is null
        and message.sender_auth_user_id <> v_actor
      group by message.conversation_id
    ) delivered
   where member.conversation_id = delivered.conversation_id
     and member.auth_user_id = v_actor
     and member.left_at is null
     and public.v1_chat_is_active_member(member.conversation_id, v_actor)
     and (
       member.last_delivered_at is null
       or member.last_delivered_at < delivered.latest_message_at
     );
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

create or replace function public.v1_mark_chat_read(
  p_conversation_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.v1_chat_is_active_member(p_conversation_id, auth.uid()) then
    raise exception 'V1_CHAT_READ_DENIED' using errcode = '42501';
  end if;
  update public.v1_chat_members member
     set last_delivered_at = clock_timestamp(),
         last_read_at = clock_timestamp(),
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

create or replace function public.v1_edit_chat_message(
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
  v_message public.v1_chat_messages%rowtype;
  v_conversation public.v1_chat_conversations%rowtype;
  v_body text := nullif(btrim(coalesce(p_payload ->> 'body', '')), '');
  v_expected_version integer := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_replay jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'message_id', 'body', 'expected_version'
  ], 'chat_message_edit_payload');

  select * into v_message
  from public.v1_chat_messages message
  where message.id = nullif(p_payload ->> 'message_id', '')::uuid
  for update;
  if not found then
    raise exception 'V1_CHAT_MESSAGE_NOT_FOUND' using errcode = 'P0002';
  end if;
  select * into strict v_conversation
  from public.v1_chat_conversations conversation
  where conversation.id = v_message.conversation_id;

  if v_actor is null or v_exact_role = ''
    or v_message.kind <> 'message'
    or v_message.sender_auth_user_id <> v_actor
    or not public.v1_chat_is_active_member(v_message.conversation_id, v_actor)
  then
    raise exception 'V1_CHAT_MESSAGE_EDIT_DENIED' using errcode = '42501';
  end if;
  if v_conversation.kind = 'material_request' then
    raise exception 'V1_CHAT_CONTROLLED_MESSAGE_IMMUTABLE'
      using errcode = '42501';
  end if;
  if v_body is null or char_length(v_body) > 4000 then
    raise exception 'V1_CHAT_MESSAGE_BODY_INVALID' using errcode = '22023';
  end if;

  v_replay := public.v1_idempotency_get_or_claim(
    'v1_edit_chat_message', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;

  if v_message.deleted_at is not null then
    raise exception 'V1_CHAT_MESSAGE_ALREADY_DELETED' using errcode = '55000';
  end if;
  if v_expected_version is null or v_expected_version <> v_message.version then
    raise exception 'V1_CHAT_MESSAGE_CONFLICT' using errcode = '40001';
  end if;
  if v_body = v_message.body then
    raise exception 'V1_CHAT_MESSAGE_UNCHANGED' using errcode = '22023';
  end if;

  insert into public.v1_chat_message_revisions (
    message_id, conversation_id, prior_version, operation, prior_body,
    changed_by_auth_user_id, changed_by_exact_role, idempotency_key
  ) values (
    v_message.id, v_message.conversation_id, v_message.version, 'edit',
    v_message.body, v_actor, v_exact_role, p_idempotency_key
  );

  update public.v1_chat_messages message
     set body = v_body,
         edited_at = clock_timestamp(),
         version = message.version + 1
   where message.id = v_message.id;
  update public.v1_chat_conversations conversation
     set updated_at = clock_timestamp()
   where conversation.id = v_message.conversation_id;

  v_response := public.v1_chat_message_json(v_message.id, v_actor);
  perform public.v1_write_audit_event(
    'chat_message_edited', 'chat_message', v_message.id,
    v_conversation.project_id, null,
    jsonb_build_object(
      'conversation_id', v_message.conversation_id,
      'prior_version', v_message.version,
      'version', v_message.version + 1
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_edit_chat_message', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_delete_chat_message(
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
  v_message public.v1_chat_messages%rowtype;
  v_conversation public.v1_chat_conversations%rowtype;
  v_expected_version integer := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_replay jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'message_id', 'expected_version'
  ], 'chat_message_delete_payload');

  select * into v_message
  from public.v1_chat_messages message
  where message.id = nullif(p_payload ->> 'message_id', '')::uuid
  for update;
  if not found then
    raise exception 'V1_CHAT_MESSAGE_NOT_FOUND' using errcode = 'P0002';
  end if;
  select * into strict v_conversation
  from public.v1_chat_conversations conversation
  where conversation.id = v_message.conversation_id;

  if v_actor is null or v_exact_role = ''
    or v_message.kind <> 'message'
    or v_message.sender_auth_user_id <> v_actor
    or not public.v1_chat_is_active_member(v_message.conversation_id, v_actor)
  then
    raise exception 'V1_CHAT_MESSAGE_DELETE_DENIED' using errcode = '42501';
  end if;
  if v_conversation.kind = 'material_request' then
    raise exception 'V1_CHAT_CONTROLLED_MESSAGE_IMMUTABLE'
      using errcode = '42501';
  end if;

  v_replay := public.v1_idempotency_get_or_claim(
    'v1_delete_chat_message', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;

  if v_message.deleted_at is not null then
    raise exception 'V1_CHAT_MESSAGE_ALREADY_DELETED' using errcode = '55000';
  end if;
  if v_expected_version is null or v_expected_version <> v_message.version then
    raise exception 'V1_CHAT_MESSAGE_CONFLICT' using errcode = '40001';
  end if;

  insert into public.v1_chat_message_revisions (
    message_id, conversation_id, prior_version, operation, prior_body,
    changed_by_auth_user_id, changed_by_exact_role, idempotency_key
  ) values (
    v_message.id, v_message.conversation_id, v_message.version, 'delete',
    v_message.body, v_actor, v_exact_role, p_idempotency_key
  );

  update public.v1_chat_messages message
     set body = null,
         deleted_at = clock_timestamp(),
         version = message.version + 1
   where message.id = v_message.id;
  update public.v1_chat_conversations conversation
     set updated_at = clock_timestamp()
   where conversation.id = v_message.conversation_id;
  update public.v1_notifications notification
     set seen_at = coalesce(notification.seen_at, clock_timestamp())
   where notification.entity_type = 'chat_message'
     and notification.entity_id = v_message.id
     and notification.seen_at is null;

  v_response := public.v1_chat_message_json(v_message.id, v_actor);
  perform public.v1_write_audit_event(
    'chat_message_deleted', 'chat_message', v_message.id,
    v_conversation.project_id, null,
    jsonb_build_object(
      'conversation_id', v_message.conversation_id,
      'prior_version', v_message.version,
      'version', v_message.version + 1
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_delete_chat_message', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_toggle_chat_acknowledgement(
  p_message_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
begin
  select message.conversation_id into v_conversation_id
  from public.v1_chat_messages message
  where message.id = p_message_id and message.deleted_at is null;
  if v_conversation_id is null
    or not public.v1_chat_is_active_member(v_conversation_id, auth.uid()) then
    raise exception 'V1_CHAT_ACK_DENIED' using errcode = '42501';
  end if;
  if exists (select 1 from public.v1_chat_message_acknowledgements ack
    where ack.message_id = p_message_id and ack.auth_user_id = auth.uid()) then
    delete from public.v1_chat_message_acknowledgements ack
    where ack.message_id = p_message_id and ack.auth_user_id = auth.uid();
    return false;
  end if;
  insert into public.v1_chat_message_acknowledgements (
    message_id, auth_user_id
  ) values (p_message_id, auth.uid());
  return true;
end;
$$;

create or replace function public.v1_toggle_chat_message_pin(
  p_message_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation_id uuid;
begin
  select message.conversation_id into v_conversation_id
  from public.v1_chat_messages message
  where message.id = p_message_id and message.deleted_at is null;
  if v_conversation_id is null
    or not public.v1_chat_is_active_member(v_conversation_id, auth.uid()) then
    raise exception 'V1_CHAT_PIN_DENIED' using errcode = '42501';
  end if;
  if exists (select 1 from public.v1_chat_message_pins pin
    where pin.conversation_id = v_conversation_id
      and pin.message_id = p_message_id) then
    delete from public.v1_chat_message_pins pin
    where pin.conversation_id = v_conversation_id
      and pin.message_id = p_message_id;
    return false;
  end if;
  insert into public.v1_chat_message_pins (
    conversation_id, message_id, pinned_by_auth_user_id
  ) values (v_conversation_id, p_message_id, auth.uid());
  return true;
end;
$$;

create or replace function public.v1_download_chat_attachment(
  p_attachment_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_attachment public.v1_chat_attachments%rowtype;
begin
  select attachment.* into v_attachment
  from public.v1_chat_attachments attachment
  join public.v1_chat_messages message on message.id = attachment.message_id
  where attachment.id = p_attachment_id
    and message.deleted_at is null;
  if not found or not public.v1_chat_is_active_member(
    v_attachment.conversation_id, auth.uid()
  ) then
    raise exception 'V1_CHAT_ATTACHMENT_READ_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'bucket_id', v_attachment.bucket_id,
    'object_path', v_attachment.object_path,
    'file_name', v_attachment.original_file_name,
    'mime_type', v_attachment.mime_type,
    'byte_size', v_attachment.byte_size
  );
end;
$$;

create or replace function public.v1_chat_attachment_readable(
  p_bucket_id text,
  p_object_path text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_bucket_id = 'yorks-chat-attachments'
    and (
      exists (
        select 1
        from public.v1_chat_attachments attachment
        join public.v1_chat_messages message
          on message.id = attachment.message_id
        where attachment.bucket_id = p_bucket_id
          and attachment.object_path = p_object_path
          and message.deleted_at is null
          and public.v1_chat_is_active_member(
            attachment.conversation_id, auth.uid()
          )
      )
      or public.v1_chat_upload_intent_permits(p_bucket_id, p_object_path)
    );
$$;

create or replace function public.v1_chat_message_sender_delivery_cursor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.kind = 'message' and new.sender_auth_user_id is not null then
    update public.v1_chat_members member
       set last_delivered_at = greatest(
         coalesce(member.last_delivered_at, new.created_at), new.created_at
       )
     where member.conversation_id = new.conversation_id
       and member.auth_user_id = new.sender_auth_user_id
       and member.left_at is null;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_chat_message_sender_delivery_cursor_trigger
  on public.v1_chat_messages;
create trigger v1_chat_message_sender_delivery_cursor_trigger
after insert on public.v1_chat_messages
for each row execute function public.v1_chat_message_sender_delivery_cursor();

revoke all on function public.v1_chat_message_sender_delivery_cursor(),
  public.v1_mark_chat_delivered(uuid[]),
  public.v1_edit_chat_message(jsonb, uuid),
  public.v1_delete_chat_message(jsonb, uuid)
from public, anon, authenticated;

grant execute on function public.v1_mark_chat_delivered(uuid[]),
  public.v1_edit_chat_message(jsonb, uuid),
  public.v1_delete_chat_message(jsonb, uuid)
to authenticated;

comment on table public.v1_chat_message_revisions is
  'Private immutable prior content for audited Team Chat edit/delete operations.';
comment on function public.v1_mark_chat_delivered(uuid[]) is
  'Advances server delivery cursors only for incoming messages synchronized by the current active participant.';
comment on function public.v1_edit_chat_message(jsonb, uuid) is
  'Version-edits the current sender own ordinary Chat message while preserving its prior body privately.';
comment on function public.v1_delete_chat_message(jsonb, uuid) is
  'Soft-deletes the current sender own ordinary Chat message and returns a durable tombstone projection.';

commit;

-- Rollback: deploy the prior client, revoke the three new authenticated RPCs
-- and restore the replaced projection/read/attachment functions from the R38.5
-- migrations. Retain the added columns, revision rows, cursor facts and soft
-- delete tombstones; never drop or rewrite committed collaboration history.
