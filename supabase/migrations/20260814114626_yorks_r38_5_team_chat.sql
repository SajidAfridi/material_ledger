-- Yorks R38.5 Team Chat: private, role-safe operational coordination.
--
-- Chat deliberately carries no workflow authority. Project and Material
-- Request links are navigation context only; all controlled transitions remain
-- in their existing trusted RPCs. All relations are additive and no legacy
-- chat/comment data is reinterpreted.
--
-- Rollback: disable the Team Chat route, revoke the callable RPC grants and
-- remove the chat tables from the Realtime publication. Once chat activity
-- exists, retain all relations and Storage objects as the audit/coordination
-- record rather than dropping or deleting them.

begin;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'yorks-chat-attachments',
  'yorks-chat-attachments',
  false,
  20971520,
  array[
    'application/pdf',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png',
    'image/webp',
    'text/plain',
    'text/csv'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.v1_chat_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in (
    'project', 'material_request', 'direct', 'group', 'announcement'
  )),
  title text not null check (
    btrim(title) <> '' and char_length(title) <= 120
  ),
  description text check (
    description is null or char_length(description) <= 500
  ),
  project_id uuid references public.v1_projects (id) on delete restrict,
  material_request_id uuid references public.v1_material_requests (id)
    on delete restrict,
  direct_key text,
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_exact_role text not null check (created_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  last_message_at timestamptz,
  check (
    (kind = 'project' and project_id is not null
      and material_request_id is null and direct_key is null)
    or (kind = 'material_request' and project_id is not null
      and material_request_id is not null and direct_key is null)
    or (kind = 'direct' and project_id is null
      and material_request_id is null and direct_key is not null)
    or (kind in ('group', 'announcement') and project_id is null
      and material_request_id is null and direct_key is null)
  )
);

create unique index if not exists v1_chat_conversations_project_unique
  on public.v1_chat_conversations (project_id)
  where kind = 'project';
create unique index if not exists v1_chat_conversations_request_unique
  on public.v1_chat_conversations (material_request_id)
  where kind = 'material_request';
create unique index if not exists v1_chat_conversations_direct_unique
  on public.v1_chat_conversations (direct_key)
  where kind = 'direct';
create index if not exists v1_chat_conversations_activity_idx
  on public.v1_chat_conversations (
    coalesce(last_message_at, created_at) desc, id desc
  );

create table if not exists public.v1_chat_members (
  conversation_id uuid not null
    references public.v1_chat_conversations (id) on delete restrict,
  auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  member_role text not null default 'member'
    check (member_role in ('owner', 'member')),
  joined_at timestamptz not null default clock_timestamp(),
  left_at timestamptz,
  last_read_at timestamptz,
  marked_unread_at timestamptz,
  is_pinned boolean not null default false,
  is_muted boolean not null default false,
  is_archived boolean not null default false,
  preferences_updated_at timestamptz not null default clock_timestamp(),
  primary key (conversation_id, auth_user_id),
  check (left_at is null or left_at >= joined_at)
);
create index if not exists v1_chat_members_active_user_idx
  on public.v1_chat_members (auth_user_id, conversation_id)
  where left_at is null;

create table if not exists public.v1_chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.v1_chat_conversations (id) on delete restrict,
  kind text not null default 'message' check (kind in ('message', 'system')),
  system_event_code text,
  sender_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  sender_exact_role text check (sender_exact_role is null or sender_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )),
  sender_display_name_snapshot text check (
    sender_display_name_snapshot is null or (
      btrim(sender_display_name_snapshot) <> ''
        and char_length(sender_display_name_snapshot) <= 120
    )
  ),
  body text,
  reply_to_message_id uuid references public.v1_chat_messages (id)
    on delete restrict,
  linked_entity_type text check (
    linked_entity_type is null
      or linked_entity_type in ('project', 'material_request')
  ),
  linked_entity_id uuid,
  source_audit_event_id uuid unique references public.v1_audit_events (id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  check (body is null or char_length(body) <= 4000),
  check (
    (kind = 'message' and sender_auth_user_id is not null
      and sender_exact_role is not null
      and sender_display_name_snapshot is not null
      and system_event_code is null)
    or (kind = 'system' and sender_auth_user_id is null
      and sender_exact_role is null
      and sender_display_name_snapshot is null
      and system_event_code is not null
      and btrim(system_event_code) <> '')
  ),
  check (
    (kind = 'message' and source_audit_event_id is null)
      or kind = 'system'
  ),
  check (
    (linked_entity_type is null and linked_entity_id is null)
      or (linked_entity_type is not null and linked_entity_id is not null)
  )
);
create index if not exists v1_chat_messages_conversation_idx
  on public.v1_chat_messages (conversation_id, created_at desc, id desc);
create index if not exists v1_chat_messages_body_search_idx
  on public.v1_chat_messages using gin (
    to_tsvector('simple', coalesce(body, ''))
  ) where kind = 'message';

create table if not exists public.v1_chat_message_mentions (
  message_id uuid not null references public.v1_chat_messages (id)
    on delete restrict,
  mentioned_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key (message_id, mentioned_auth_user_id)
);

create table if not exists public.v1_chat_message_acknowledgements (
  message_id uuid not null references public.v1_chat_messages (id)
    on delete restrict,
  auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  primary key (message_id, auth_user_id)
);

create table if not exists public.v1_chat_message_pins (
  conversation_id uuid not null references public.v1_chat_conversations (id)
    on delete restrict,
  message_id uuid not null references public.v1_chat_messages (id)
    on delete restrict,
  pinned_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  pinned_at timestamptz not null default clock_timestamp(),
  primary key (conversation_id, message_id)
);

create table if not exists public.v1_chat_attachment_upload_intents (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.v1_chat_conversations (id)
    on delete restrict,
  actor_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  bucket_id text not null default 'yorks-chat-attachments'
    check (bucket_id = 'yorks-chat-attachments'),
  object_path text not null unique check (btrim(object_path) <> ''),
  original_file_name text not null check (
    btrim(original_file_name) <> ''
      and char_length(original_file_name) <= 180
      and position('/' in original_file_name) = 0
      and position(chr(92) in original_file_name) = 0
  ),
  mime_type text not null check (mime_type in (
    'application/pdf',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg', 'image/png', 'image/webp', 'text/plain', 'text/csv'
  )),
  byte_size bigint not null check (byte_size > 0 and byte_size <= 20971520),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  verified_at timestamptz,
  finalized_at timestamptz,
  check (expires_at > created_at)
);

create table if not exists public.v1_chat_attachments (
  id uuid primary key,
  message_id uuid not null references public.v1_chat_messages (id)
    on delete restrict,
  conversation_id uuid not null references public.v1_chat_conversations (id)
    on delete restrict,
  bucket_id text not null default 'yorks-chat-attachments'
    check (bucket_id = 'yorks-chat-attachments'),
  object_path text not null unique check (btrim(object_path) <> ''),
  original_file_name text not null,
  mime_type text not null,
  byte_size bigint not null check (byte_size > 0 and byte_size <= 20971520),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  uploaded_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists v1_chat_attachments_message_idx
  on public.v1_chat_attachments (message_id, created_at, id);

alter table public.v1_chat_conversations enable row level security;
alter table public.v1_chat_members enable row level security;
alter table public.v1_chat_messages enable row level security;
alter table public.v1_chat_message_mentions enable row level security;
alter table public.v1_chat_message_acknowledgements enable row level security;
alter table public.v1_chat_message_pins enable row level security;
alter table public.v1_chat_attachment_upload_intents enable row level security;
alter table public.v1_chat_attachments enable row level security;

revoke all on table public.v1_chat_conversations,
  public.v1_chat_members,
  public.v1_chat_messages,
  public.v1_chat_message_mentions,
  public.v1_chat_message_acknowledgements,
  public.v1_chat_message_pins,
  public.v1_chat_attachment_upload_intents,
  public.v1_chat_attachments
from public, anon, authenticated;

grant all on table public.v1_chat_conversations,
  public.v1_chat_members,
  public.v1_chat_messages,
  public.v1_chat_message_mentions,
  public.v1_chat_message_acknowledgements,
  public.v1_chat_message_pins,
  public.v1_chat_attachment_upload_intents,
  public.v1_chat_attachments
to service_role;

-- Callable predicates keep Storage and Realtime policies fail-closed without
-- exposing raw chat tables through the Data API.
create or replace function public.v1_chat_is_active_member(
  p_conversation_id uuid,
  p_auth_user_id uuid default auth.uid()
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_auth_user_id is not null
    and p_auth_user_id = auth.uid()
    and public.v1_current_actor_is_active()
    and exists (
      select 1
      from public.v1_chat_members member
      join public.v1_profiles profile
        on profile.auth_user_id = member.auth_user_id
      join public.v1_chat_conversations conversation
        on conversation.id = member.conversation_id
      where member.conversation_id = p_conversation_id
        and member.auth_user_id = p_auth_user_id
        and member.left_at is null
        and profile.is_active
        and case conversation.kind
          when 'project' then public.v1_project_readable(
            conversation.project_id
          )
          when 'material_request' then public.v1_material_request_readable(
            conversation.material_request_id
          )
          else true
        end
    );
$$;

create or replace function public.v1_chat_safe_display_name(
  p_auth_user_id uuid
) returns text
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_safe_profile_display_name(
    profile.display_name, profile.auth_user_id
  )
  from public.v1_profiles profile
  where profile.auth_user_id = p_auth_user_id
    and profile.is_active;
$$;

create or replace function public.v1_chat_exact_role(
  p_auth_user_id uuid
) returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'senior_mechanical_engineer'
    when 'project_manager' then 'project_manager'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end
  from auth.users auth_user
  join public.v1_profiles profile
    on profile.auth_user_id = auth_user.id and profile.is_active
  where auth_user.id = p_auth_user_id
    and (auth_user.banned_until is null
      or auth_user.banned_until <= clock_timestamp());
$$;

create or replace function public.v1_sync_chat_context_members(
  p_conversation_id uuid
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conversation public.v1_chat_conversations%rowtype;
begin
  select * into v_conversation
  from public.v1_chat_conversations conversation
  where conversation.id = p_conversation_id
  for update;
  if not found or v_conversation.kind not in ('project', 'material_request') then
    return;
  end if;

  if v_conversation.kind = 'project' then
    with eligible as (
      select member.member_auth_user_id as auth_user_id
      from public.v1_project_members member
      where member.project_id = v_conversation.project_id
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null
          or member.effective_to > clock_timestamp())
      union
      select v_conversation.created_by_auth_user_id
      union
      select profile.auth_user_id
      from public.v1_profiles profile
      where profile.is_active
        and public.v1_chat_exact_role(profile.auth_user_id) in (
          'admin', 'senior_mechanical_engineer', 'project_manager'
        )
      union
      select arrangement.started_by_auth_user_id
      from public.v1_procurement_arrangements arrangement
      join public.v1_material_requests request
        on request.id = arrangement.request_id
      where request.project_id = v_conversation.project_id
      union
      select dispatch.dispatched_by_auth_user_id
      from public.v1_material_dispatches dispatch
      join public.v1_material_requests request
        on request.id = dispatch.request_id
      where request.project_id = v_conversation.project_id
    )
    insert into public.v1_chat_members (
      conversation_id, auth_user_id, member_role
    )
    select p_conversation_id, eligible.auth_user_id,
      case when eligible.auth_user_id = v_conversation.created_by_auth_user_id
        then 'owner' else 'member' end
    from eligible
    join public.v1_profiles profile
      on profile.auth_user_id = eligible.auth_user_id and profile.is_active
    where public.v1_chat_exact_role(eligible.auth_user_id) <> ''
    on conflict (conversation_id, auth_user_id) do update
      set left_at = null,
          joined_at = case when v1_chat_members.left_at is null
            then v1_chat_members.joined_at else clock_timestamp() end;
  else
    with eligible as (
      select request.created_by_auth_user_id as auth_user_id
      from public.v1_material_requests request
      where request.id = v_conversation.material_request_id
      union
      select member.member_auth_user_id
      from public.v1_project_members member
      where member.project_id = v_conversation.project_id
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null
          or member.effective_to > clock_timestamp())
      union
      select profile.auth_user_id
      from public.v1_profiles profile
      where profile.is_active
        and public.v1_chat_exact_role(profile.auth_user_id) in (
          'admin', 'senior_mechanical_engineer', 'project_manager'
        )
      union
      select profile.auth_user_id
      from public.v1_profiles profile
      join public.v1_material_requests request
        on request.id = v_conversation.material_request_id
      where profile.is_active
        and public.v1_chat_exact_role(profile.auth_user_id) = 'procurement'
        and request.state in (
          'submitted', 'approved_for_arrangement', 'arranging',
          'awaiting_approval', 'approved', 'partially_dispatched',
          'dispatched', 'partially_received', 'received', 'closed',
          'cancelled'
        )
    )
    insert into public.v1_chat_members (
      conversation_id, auth_user_id, member_role
    )
    select p_conversation_id, eligible.auth_user_id,
      case when eligible.auth_user_id = v_conversation.created_by_auth_user_id
        then 'owner' else 'member' end
    from eligible
    join public.v1_profiles profile
      on profile.auth_user_id = eligible.auth_user_id and profile.is_active
    where public.v1_chat_exact_role(eligible.auth_user_id) <> ''
    on conflict (conversation_id, auth_user_id) do update
      set left_at = null,
          joined_at = case when v1_chat_members.left_at is null
            then v1_chat_members.joined_at else clock_timestamp() end;
  end if;

  update public.v1_chat_members member
     set left_at = clock_timestamp()
   where member.conversation_id = p_conversation_id
     and member.left_at is null
     and not case v_conversation.kind
       when 'project' then public.v1_has_active_project_membership(
         v_conversation.project_id, member.auth_user_id, null
       ) or public.v1_chat_exact_role(member.auth_user_id) in (
         'admin', 'senior_mechanical_engineer', 'project_manager'
       ) or exists (
         select 1
         from public.v1_procurement_arrangements arrangement
         join public.v1_material_requests request
           on request.id = arrangement.request_id
         where request.project_id = v_conversation.project_id
           and arrangement.started_by_auth_user_id = member.auth_user_id
       ) or exists (
         select 1
         from public.v1_material_dispatches dispatch
         join public.v1_material_requests request
           on request.id = dispatch.request_id
         where request.project_id = v_conversation.project_id
           and dispatch.dispatched_by_auth_user_id = member.auth_user_id
       ) or member.auth_user_id = v_conversation.created_by_auth_user_id
       else public.v1_material_request_participant(
         v_conversation.material_request_id, member.auth_user_id
       )
     end;
end;
$$;

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
    'body', message.body,
    'reply_to_message_id', message.reply_to_message_id,
    'linked_entity_type', message.linked_entity_type,
    'linked_entity_id', message.linked_entity_id,
    'created_at', message.created_at,
    'is_mine', message.sender_auth_user_id = p_actor,
    'is_pinned', exists (
      select 1 from public.v1_chat_message_pins pin
      where pin.conversation_id = message.conversation_id
        and pin.message_id = message.id
    ),
    'acknowledgement_count', (
      select count(*) from public.v1_chat_message_acknowledgements ack
      where ack.message_id = message.id
    ),
    'acknowledged_by_me', exists (
      select 1 from public.v1_chat_message_acknowledgements ack
      where ack.message_id = message.id and ack.auth_user_id = p_actor
    ),
    'mentions', coalesce((
      select jsonb_agg(mention.mentioned_auth_user_id order by mention.mentioned_auth_user_id)
      from public.v1_chat_message_mentions mention
      where mention.message_id = message.id
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
    ), '[]'::jsonb),
    'reply_preview', (
      select jsonb_build_object(
        'id', replied.id,
        'sender_display_name', replied.sender_display_name_snapshot,
        'body', replied.body
      )
      from public.v1_chat_messages replied
      where replied.id = message.reply_to_message_id
    )
  )
  from public.v1_chat_messages message
  where message.id = p_message_id;
$$;

create or replace function public.v1_list_chat_directory()
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
    raise exception 'V1_CHAT_DIRECTORY_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'auth_user_id', profile.auth_user_id,
      'display_name', public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      ),
      'exact_role', public.v1_chat_exact_role(profile.auth_user_id)
    ) order by lower(public.v1_safe_profile_display_name(
      profile.display_name, profile.auth_user_id
    )), profile.auth_user_id)
    from public.v1_profiles profile
    where profile.is_active
      and public.v1_chat_exact_role(profile.auth_user_id) <> ''
  ), '[]'::jsonb);
end;
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
    select jsonb_agg(public.v1_chat_conversation_json(
      conversation.id, v_actor
    ) order by member.is_pinned desc,
      ((public.v1_chat_conversation_json(
        conversation.id, v_actor
      ) ->> 'unread_count')::integer > 0) desc,
      coalesce(conversation.last_message_at, conversation.created_at) desc,
      conversation.id desc)
    from public.v1_chat_conversations conversation
    join public.v1_chat_members member
      on member.conversation_id = conversation.id
     and member.auth_user_id = v_actor
     and member.left_at is null
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
      where public.v1_chat_is_active_member(conversation.id, v_actor)
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

create or replace function public.v1_list_chat_context_targets(
  p_kind text default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or (p_kind is not null and p_kind not in ('project', 'material_request')) then
    raise exception 'V1_CHAT_CONTEXT_LIST_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(target.payload order by target.sort_at desc, target.id)
    from (
      select project.id,
        project.updated_at as sort_at,
        jsonb_build_object(
          'id', project.id,
          'kind', 'project',
          'title', project.project_ref,
          'subtitle', project.name,
          'project_id', project.id
        ) as payload
      from public.v1_projects project
      where (p_kind is null or p_kind = 'project')
        and public.v1_project_readable(project.id)
        and project.state <> 'archived'
      union all
      select request.id,
        request.updated_at as sort_at,
        jsonb_build_object(
          'id', request.id,
          'kind', 'material_request',
          'title', request.request_number,
          'subtitle', project.project_ref || ' · ' || scope.name,
          'project_id', request.project_id
        ) as payload
      from public.v1_material_requests request
      join public.v1_projects project on project.id = request.project_id
      join public.v1_project_scopes scope on scope.id = request.scope_id
      where (p_kind is null or p_kind = 'material_request')
        and request.request_number is not null
        and public.v1_material_request_readable(request.id)
    ) target
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_get_chat_conversation(
  p_conversation_id uuid,
  p_before timestamptz default null,
  p_limit integer default 50
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_conversation jsonb;
begin
  if not public.v1_chat_is_active_member(p_conversation_id, v_actor) then
    raise exception 'V1_CHAT_READ_DENIED' using errcode = '42501';
  end if;
  v_conversation := public.v1_chat_conversation_json(
    p_conversation_id, v_actor
  );
  return v_conversation || jsonb_build_object(
    'participants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', member.auth_user_id,
        'display_name', public.v1_chat_safe_display_name(member.auth_user_id),
        'exact_role', public.v1_chat_exact_role(member.auth_user_id),
        'member_role', member.member_role
      ) order by
        case when member.member_role = 'owner' then 0 else 1 end,
        lower(public.v1_chat_safe_display_name(member.auth_user_id))
      )
      from public.v1_chat_members member
      where member.conversation_id = p_conversation_id
        and member.left_at is null
    ), '[]'::jsonb),
    'messages', coalesce((
      select jsonb_agg(public.v1_chat_message_json(
        ordered.id, v_actor
      ) order by ordered.created_at, ordered.id)
      from (
        select message.id, message.created_at
        from public.v1_chat_messages message
        where message.conversation_id = p_conversation_id
          and (p_before is null or message.created_at < p_before)
        order by message.created_at desc, message.id desc
        limit greatest(1, least(coalesce(p_limit, 50), 100))
      ) ordered
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_create_chat_conversation(
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
  v_kind text := coalesce(p_payload ->> 'kind', '');
  v_title text := btrim(coalesce(p_payload ->> 'title', ''));
  v_description text := nullif(btrim(coalesce(p_payload ->> 'description', '')), '');
  v_project_id uuid;
  v_request_id uuid;
  v_other uuid;
  v_participant uuid;
  v_conversation_id uuid;
  v_direct_key text;
  v_replay jsonb;
  v_response jsonb;
  v_created boolean := false;
begin
  if v_actor is null or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_CHAT_CREATE_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(p_payload, array[
    'kind', 'title', 'description', 'participant_auth_user_ids',
    'project_id', 'material_request_id'
  ], 'chat_create_payload');
  if v_kind not in (
    'project', 'material_request', 'direct', 'group', 'announcement'
  ) then
    raise exception 'V1_CHAT_KIND_INVALID' using errcode = '22023';
  end if;
  v_replay := public.v1_idempotency_get_or_claim(
    'v1_create_chat_conversation', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;

  if v_kind = 'direct' then
    if jsonb_typeof(p_payload -> 'participant_auth_user_ids') <> 'array'
      or jsonb_array_length(p_payload -> 'participant_auth_user_ids') <> 1 then
      raise exception 'V1_CHAT_DIRECT_PARTICIPANT_INVALID'
        using errcode = '22023';
    end if;
    v_other := (p_payload -> 'participant_auth_user_ids' ->> 0)::uuid;
    if v_other = v_actor or public.v1_chat_exact_role(v_other) = '' then
      raise exception 'V1_CHAT_DIRECT_PARTICIPANT_INVALID'
        using errcode = '22023';
    end if;
    v_direct_key := least(v_actor::text, v_other::text) || ':'
      || greatest(v_actor::text, v_other::text);
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('chat-direct:' || v_direct_key, 0)
    );
    select conversation.id into v_conversation_id
    from public.v1_chat_conversations conversation
    where conversation.kind = 'direct'
      and conversation.direct_key = v_direct_key;
    if v_conversation_id is null then
      v_created := true;
      insert into public.v1_chat_conversations (
        kind, title, direct_key, created_by_auth_user_id,
        created_by_exact_role
      ) values (
        'direct', 'Direct message', v_direct_key, v_actor, v_exact_role
      ) returning id into v_conversation_id;
      insert into public.v1_chat_members (
        conversation_id, auth_user_id, member_role
      ) values
        (v_conversation_id, v_actor, 'owner'),
        (v_conversation_id, v_other, 'member');
    end if;
  elsif v_kind = 'group' then
    if v_exact_role not in (
      'admin', 'project_manager', 'senior_mechanical_engineer'
    ) then
      raise exception 'V1_CHAT_GROUP_CREATE_DENIED' using errcode = '42501';
    end if;
    if char_length(v_title) < 2 or char_length(v_title) > 120
      or jsonb_typeof(p_payload -> 'participant_auth_user_ids') <> 'array'
      or jsonb_array_length(p_payload -> 'participant_auth_user_ids') < 1
      or jsonb_array_length(p_payload -> 'participant_auth_user_ids') > 99 then
      raise exception 'V1_CHAT_GROUP_INPUT_INVALID' using errcode = '22023';
    end if;
    insert into public.v1_chat_conversations (
      kind, title, description, created_by_auth_user_id,
      created_by_exact_role
    ) values (
      'group', v_title, v_description, v_actor, v_exact_role
    ) returning id into v_conversation_id;
    v_created := true;
    insert into public.v1_chat_members (
      conversation_id, auth_user_id, member_role
    ) values (v_conversation_id, v_actor, 'owner');
    for v_participant in
      select distinct value::uuid
      from jsonb_array_elements_text(
        p_payload -> 'participant_auth_user_ids'
      ) value
    loop
      if v_participant <> v_actor
        and public.v1_chat_exact_role(v_participant) <> '' then
        insert into public.v1_chat_members (
          conversation_id, auth_user_id, member_role
        ) values (v_conversation_id, v_participant, 'member')
        on conflict do nothing;
      end if;
    end loop;
    if (select count(*) from public.v1_chat_members member
      where member.conversation_id = v_conversation_id) < 2 then
      raise exception 'V1_CHAT_GROUP_PARTICIPANT_INVALID'
        using errcode = '22023';
    end if;
  elsif v_kind = 'announcement' then
    if v_exact_role <> 'admin' then
      raise exception 'V1_CHAT_ANNOUNCEMENT_CREATE_DENIED'
        using errcode = '42501';
    end if;
    if char_length(v_title) < 2 or char_length(v_title) > 120 then
      raise exception 'V1_CHAT_ANNOUNCEMENT_INPUT_INVALID'
        using errcode = '22023';
    end if;
    insert into public.v1_chat_conversations (
      kind, title, description, created_by_auth_user_id,
      created_by_exact_role
    ) values (
      'announcement', v_title, v_description, v_actor, v_exact_role
    ) returning id into v_conversation_id;
    v_created := true;
    insert into public.v1_chat_members (
      conversation_id, auth_user_id, member_role
    )
    select v_conversation_id, profile.auth_user_id,
      case when profile.auth_user_id = v_actor then 'owner' else 'member' end
    from public.v1_profiles profile
    where profile.is_active
      and public.v1_chat_exact_role(profile.auth_user_id) <> '';
  elsif v_kind = 'project' then
    v_project_id := nullif(p_payload ->> 'project_id', '')::uuid;
    if v_project_id is null or not public.v1_project_readable(v_project_id) then
      raise exception 'V1_CHAT_PROJECT_DENIED' using errcode = '42501';
    end if;
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('chat-project:' || v_project_id::text, 0)
    );
    select conversation.id into v_conversation_id
    from public.v1_chat_conversations conversation
    where conversation.kind = 'project'
      and conversation.project_id = v_project_id;
    if v_conversation_id is null then
      v_created := true;
      select project.project_ref || ' · Project Team' into v_title
      from public.v1_projects project where project.id = v_project_id;
      insert into public.v1_chat_conversations (
        kind, title, description, project_id, created_by_auth_user_id,
        created_by_exact_role
      ) values (
        'project', v_title,
        (select project.name from public.v1_projects project
          where project.id = v_project_id),
        v_project_id,
        v_actor, v_exact_role
      ) returning id into v_conversation_id;
    end if;
    perform public.v1_sync_chat_context_members(v_conversation_id);
  else
    v_request_id := nullif(p_payload ->> 'material_request_id', '')::uuid;
    if v_request_id is null
      or not public.v1_material_request_readable(v_request_id) then
      raise exception 'V1_CHAT_REQUEST_DENIED' using errcode = '42501';
    end if;
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('chat-request:' || v_request_id::text, 0)
    );
    select conversation.id into v_conversation_id
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id = v_request_id;
    if v_conversation_id is null then
      v_created := true;
      select coalesce(request.request_number, 'Draft request') || ' · '
          || scope.name,
        request.project_id
        into v_title, v_project_id
      from public.v1_material_requests request
      join public.v1_project_scopes scope on scope.id = request.scope_id
      where request.id = v_request_id;
      insert into public.v1_chat_conversations (
        kind, title, description, project_id, material_request_id,
        created_by_auth_user_id, created_by_exact_role
      ) values (
        'material_request', v_title,
        (select project.project_ref || ' · ' || project.name
          from public.v1_projects project where project.id = v_project_id),
        v_project_id, v_request_id,
        v_actor, v_exact_role
      ) returning id into v_conversation_id;
    end if;
    perform public.v1_sync_chat_context_members(v_conversation_id);
  end if;

  v_response := jsonb_build_object(
    'conversation', public.v1_chat_conversation_json(
      v_conversation_id, v_actor
    )
  );
  if v_created then
    perform public.v1_write_audit_event(
      'chat_conversation_created', 'chat_conversation', v_conversation_id,
      v_project_id, null, v_response -> 'conversation', null,
      p_idempotency_key
    );
  end if;
  perform public.v1_complete_idempotency(
    'v1_create_chat_conversation', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_update_chat_group(
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
  v_conversation_id uuid := nullif(
    p_payload ->> 'conversation_id', ''
  )::uuid;
  v_title text := btrim(coalesce(p_payload ->> 'title', ''));
  v_description text := nullif(
    btrim(coalesce(p_payload ->> 'description', '')), ''
  );
  v_participant uuid;
  v_replay jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'conversation_id', 'title', 'description', 'participant_auth_user_ids'
  ], 'chat_group_update_payload');
  if not public.v1_chat_is_active_member(v_conversation_id, v_actor)
    or not exists (
      select 1
      from public.v1_chat_conversations conversation
      join public.v1_chat_members member
        on member.conversation_id = conversation.id
       and member.auth_user_id = v_actor and member.left_at is null
      where conversation.id = v_conversation_id
        and conversation.kind = 'group'
        and (member.member_role = 'owner' or v_exact_role = 'admin')
    ) then
    raise exception 'V1_CHAT_GROUP_UPDATE_DENIED' using errcode = '42501';
  end if;
  if char_length(v_title) < 2 or char_length(v_title) > 120
    or (v_description is not null and char_length(v_description) > 500)
    or jsonb_typeof(p_payload -> 'participant_auth_user_ids') <> 'array'
    or jsonb_array_length(p_payload -> 'participant_auth_user_ids') < 1
    or jsonb_array_length(p_payload -> 'participant_auth_user_ids') > 99 then
    raise exception 'V1_CHAT_GROUP_UPDATE_INVALID' using errcode = '22023';
  end if;
  v_replay := public.v1_idempotency_get_or_claim(
    'v1_update_chat_group', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;

  update public.v1_chat_conversations conversation
     set title = v_title,
         description = v_description,
         updated_at = clock_timestamp()
   where conversation.id = v_conversation_id;
  for v_participant in
    select distinct value::uuid
    from jsonb_array_elements_text(
      p_payload -> 'participant_auth_user_ids'
    ) value
  loop
    if public.v1_chat_exact_role(v_participant) = '' then
      raise exception 'V1_CHAT_GROUP_PARTICIPANT_INVALID'
        using errcode = '22023';
    end if;
    insert into public.v1_chat_members (
      conversation_id, auth_user_id, member_role
    ) values (v_conversation_id, v_participant, 'member')
    on conflict (conversation_id, auth_user_id) do update
      set left_at = null,
          joined_at = case when v1_chat_members.left_at is null
            then v1_chat_members.joined_at else clock_timestamp() end;
  end loop;

  update public.v1_chat_members member
     set left_at = clock_timestamp()
   where member.conversation_id = v_conversation_id
     and member.left_at is null
     and member.member_role <> 'owner'
     and not exists (
       select 1
       from jsonb_array_elements_text(
         p_payload -> 'participant_auth_user_ids'
       ) value
       where value::uuid = member.auth_user_id
     );
  if (select count(*) from public.v1_chat_members member
    where member.conversation_id = v_conversation_id
      and member.left_at is null) < 2 then
    raise exception 'V1_CHAT_GROUP_PARTICIPANT_INVALID'
      using errcode = '22023';
  end if;

  v_response := jsonb_build_object(
    'conversation', public.v1_chat_conversation_json(
      v_conversation_id, v_actor
    )
  );
  perform public.v1_write_audit_event(
    'chat_group_updated', 'chat_conversation', v_conversation_id,
    null, null,
    jsonb_build_object(
      'title', v_title,
      'participant_count', (
        select count(*) from public.v1_chat_members member
        where member.conversation_id = v_conversation_id
          and member.left_at is null
      )
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_update_chat_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_prepare_chat_attachment(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_conversation_id uuid := nullif(p_payload ->> 'conversation_id', '')::uuid;
  v_file_name text := btrim(coalesce(p_payload ->> 'file_name', ''));
  v_mime_type text := coalesce(p_payload ->> 'mime_type', '');
  v_byte_size bigint := coalesce((p_payload ->> 'byte_size')::bigint, 0);
  v_sha256 text := lower(coalesce(p_payload ->> 'sha256', ''));
  v_intent_id uuid := gen_random_uuid();
  v_object_path text;
  v_replay jsonb;
  v_response jsonb;
begin
  if not public.v1_chat_is_active_member(v_conversation_id, v_actor) then
    raise exception 'V1_CHAT_ATTACHMENT_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(p_payload, array[
    'conversation_id', 'file_name', 'mime_type', 'byte_size', 'sha256'
  ], 'chat_attachment_payload');
  if v_file_name = '' or char_length(v_file_name) > 180
    or position('/' in v_file_name) > 0
    or position(chr(92) in v_file_name) > 0
    or v_mime_type not in (
      'application/pdf',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg', 'image/png', 'image/webp', 'text/plain', 'text/csv'
    ) or v_byte_size < 1 or v_byte_size > 20971520
    or v_sha256 !~ '^[a-f0-9]{64}$' then
    raise exception 'V1_CHAT_ATTACHMENT_INVALID' using errcode = '22023';
  end if;
  v_replay := public.v1_idempotency_get_or_claim(
    'v1_prepare_chat_attachment', p_idempotency_key, p_payload
  );
  if v_replay is not null then return v_replay; end if;
  v_object_path := v_conversation_id::text || '/' || v_intent_id::text || '/file';
  insert into public.v1_chat_attachment_upload_intents (
    id, conversation_id, actor_auth_user_id, object_path,
    original_file_name, mime_type, byte_size, sha256, expires_at
  ) values (
    v_intent_id, v_conversation_id, v_actor, v_object_path,
    v_file_name, v_mime_type, v_byte_size, v_sha256,
    clock_timestamp() + interval '30 minutes'
  );
  v_response := jsonb_build_object(
    'attachment_id', v_intent_id,
    'bucket_id', 'yorks-chat-attachments',
    'object_path', v_object_path,
    'file_name', v_file_name,
    'mime_type', v_mime_type,
    'byte_size', v_byte_size,
    'sha256', v_sha256
  );
  perform public.v1_complete_idempotency(
    'v1_prepare_chat_attachment', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_chat_upload_intent_projection(
  p_upload_intent_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_intent public.v1_chat_attachment_upload_intents%rowtype;
begin
  select * into v_intent
  from public.v1_chat_attachment_upload_intents intent
  where intent.id = p_upload_intent_id;
  if not found or v_intent.actor_auth_user_id <> auth.uid()
    or not public.v1_chat_is_active_member(
      v_intent.conversation_id, auth.uid()
    ) then
    raise exception 'V1_CHAT_UPLOAD_INTENT_READ_DENIED'
      using errcode = '42501';
  end if;
  return jsonb_build_object(
    'upload_intent_id', v_intent.id,
    'bucket_id', v_intent.bucket_id,
    'object_path', v_intent.object_path,
    'mime_type', v_intent.mime_type,
    'byte_size', v_intent.byte_size,
    'expires_at', v_intent.expires_at,
    'verified_at', v_intent.verified_at
  );
end;
$$;

create or replace function public.v1_verify_chat_attachment_upload(
  p_upload_intent_id uuid,
  p_verified_sha256 text,
  p_verified_byte_size bigint,
  p_verified_mime_type text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_intent public.v1_chat_attachment_upload_intents%rowtype;
  v_object storage.objects%rowtype;
  v_metadata_size bigint;
  v_metadata_mime text;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'V1_CHAT_UPLOAD_FINALIZER_SERVICE_ONLY'
      using errcode = '42501';
  end if;
  select * into v_intent
  from public.v1_chat_attachment_upload_intents intent
  where intent.id = p_upload_intent_id
  for update;
  if not found then
    raise exception 'V1_CHAT_UPLOAD_INTENT_NOT_FOUND' using errcode = '22023';
  end if;
  if v_intent.verified_at is not null then
    return jsonb_build_object(
      'attachment_id', v_intent.id,
      'verified_at', v_intent.verified_at
    );
  end if;
  if v_intent.expires_at <= clock_timestamp()
    or lower(coalesce(p_verified_sha256, '')) <> v_intent.sha256
    or p_verified_byte_size <> v_intent.byte_size
    or p_verified_mime_type <> v_intent.mime_type then
    raise exception 'V1_CHAT_UPLOAD_VERIFICATION_FAILED'
      using errcode = '22023';
  end if;
  select * into v_object
  from storage.objects object
  where object.bucket_id = v_intent.bucket_id
    and object.name = v_intent.object_path;
  if not found
    or coalesce(v_object.owner_id, '')
      <> v_intent.actor_auth_user_id::text then
    raise exception 'V1_CHAT_UPLOAD_OBJECT_NOT_OWNED'
      using errcode = '42501';
  end if;
  v_metadata_size := nullif(v_object.metadata ->> 'size', '')::bigint;
  v_metadata_mime := coalesce(
    nullif(v_object.metadata ->> 'mimetype', ''),
    nullif(v_object.metadata ->> 'contentType', '')
  );
  if v_metadata_size <> v_intent.byte_size
    or v_metadata_mime <> v_intent.mime_type then
    raise exception 'V1_CHAT_UPLOAD_METADATA_MISMATCH'
      using errcode = '22023';
  end if;
  update public.v1_chat_attachment_upload_intents intent
     set verified_at = clock_timestamp()
   where intent.id = v_intent.id
  returning intent.verified_at into v_intent.verified_at;
  return jsonb_build_object(
    'attachment_id', v_intent.id,
    'verified_at', v_intent.verified_at
  );
end;
$$;

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

create or replace function public.v1_append_chat_system_event(
  p_conversation_id uuid,
  p_event_code text,
  p_source_audit_event_id uuid,
  p_occurred_at timestamptz
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message_id uuid;
begin
  if p_event_code not in (
    'project_channel_created',
    'material_request_submitted',
    'material_request_updated_for_approval',
    'material_request_approved',
    'material_request_returned',
    'arrangement_started',
    'arrangement_saved',
    'arrangement_approved',
    'arrangement_returned',
    'materials_dispatched',
    'receipt_confirmed',
    'material_request_closed',
    'material_request_cancelled'
  ) then
    raise exception 'V1_CHAT_SYSTEM_EVENT_INVALID' using errcode = '22023';
  end if;
  insert into public.v1_chat_messages (
    conversation_id, kind, system_event_code, source_audit_event_id,
    created_at
  ) values (
    p_conversation_id, 'system', p_event_code, p_source_audit_event_id,
    coalesce(p_occurred_at, clock_timestamp())
  )
  on conflict (source_audit_event_id) do update
    set source_audit_event_id = excluded.source_audit_event_id
  returning id into v_message_id;
  update public.v1_chat_conversations conversation
     set last_message_at = greatest(
           coalesce(conversation.last_message_at, '-infinity'::timestamptz),
           coalesce(p_occurred_at, clock_timestamp())
         ),
         updated_at = greatest(
           conversation.updated_at,
           coalesce(p_occurred_at, clock_timestamp())
         )
   where conversation.id = p_conversation_id;
  return v_message_id;
end;
$$;

create or replace function public.v1_chat_audit_event_bridge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_conversation_id uuid;
  v_event_code text;
  v_response jsonb;
begin
  if new.event_type in (
    'chat_conversation_created', 'chat_message_sent'
  ) then return new; end if;
  v_event_code := case new.event_type
    when 'material_request_submitted' then 'material_request_submitted'
    when 'material_request_updated_for_approval'
      then 'material_request_updated_for_approval'
    when 'material_request_approved' then 'material_request_approved'
    when 'material_request_returned' then 'material_request_returned'
    when 'arrangement_begun' then 'arrangement_started'
    when 'arrangement_saved' then 'arrangement_saved'
    when 'arrangement_approved' then 'arrangement_approved'
    when 'arrangement_returned' then 'arrangement_returned'
    when 'materials_dispatched' then 'materials_dispatched'
    when 'receipt_review_confirmed' then 'receipt_confirmed'
    when 'material_request_closed' then 'material_request_closed'
    when 'material_request_cancelled' then 'material_request_cancelled'
    else null
  end;
  if v_event_code is null then return new; end if;
  v_request_id := public.v1_resolve_notification_request_id(
    new.entity_type, new.entity_id
  );
  if v_request_id is null and new.entity_type = 'material_request' then
    v_request_id := new.entity_id;
  end if;
  if v_request_id is null then return new; end if;

  -- The originating trusted RPC still has the actor's authenticated context,
  -- so canonical creation reuses the same participant/access calculation.
  v_response := public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'material_request',
      'material_request_id', v_request_id,
      'participant_auth_user_ids', '[]'::jsonb
    ),
    gen_random_uuid()
  );
  v_conversation_id := (v_response -> 'conversation' ->> 'id')::uuid;
  perform public.v1_append_chat_system_event(
    v_conversation_id, v_event_code, new.id, new.occurred_at
  );
  return new;
exception
  when others then
    -- Chat is a projection of trusted workflow history, never transaction
    -- authority. An unavailable or ineligible context must not make the
    -- originating workflow/audit command fail.
    return new;
end;
$$;

drop trigger if exists v1_chat_audit_event_bridge on public.v1_audit_events;
create trigger v1_chat_audit_event_bridge
after insert on public.v1_audit_events
for each row execute function public.v1_chat_audit_event_bridge();

-- The compact Material Request Discussion is a contextual view over this same
-- canonical chat history. Legacy comment tables remain preserved for rollback,
-- while all new discussion writes enter v1_chat_messages.
create or replace function public.v1_material_request_comment_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', message.id,
    'request_id', p_request_id,
    'body', message.body,
    'author_auth_user_id', message.sender_auth_user_id,
    'author_role', public.v1_canonical_role_from_exact_role(
      message.sender_exact_role
    ),
    'author_exact_role', message.sender_exact_role,
    'author_display_name', message.sender_display_name_snapshot,
    'created_at', message.created_at,
    'mentions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', mention.mentioned_auth_user_id,
        'display_name', public.v1_chat_safe_display_name(
          mention.mentioned_auth_user_id
        ),
        'exact_role', public.v1_chat_exact_role(
          mention.mentioned_auth_user_id
        )
      ) order by public.v1_chat_safe_display_name(
        mention.mentioned_auth_user_id
      ))
      from public.v1_chat_message_mentions mention
      where mention.message_id = message.id
    ), '[]'::jsonb)
  ) order by message.created_at, message.id), '[]'::jsonb)
  from public.v1_chat_conversations conversation
  join public.v1_chat_messages message
    on message.conversation_id = conversation.id
   and message.kind = 'message'
  where conversation.kind = 'material_request'
    and conversation.material_request_id = p_request_id;
$$;

-- Preserve every pre-R38.5 Request Discussion message in the canonical MR
-- thread. Stable comment UUIDs become stable chat-message UUIDs; the legacy
-- tables remain untouched as rollback evidence and are no longer written by
-- the application after this migration.
insert into public.v1_chat_conversations (
  id, kind, title, description, project_id, material_request_id,
  created_by_auth_user_id, created_by_exact_role, created_at, updated_at,
  last_message_at
)
select gen_random_uuid(), 'material_request',
  request.request_number || ' · Material Request',
  'Request coordination thread', request.project_id, request.id,
  first_comment.author_auth_user_id, first_comment.author_exact_role,
  first_comment.created_at, latest_comment.created_at,
  latest_comment.created_at
from public.v1_material_requests request
join lateral (
  select comment_record.author_auth_user_id,
    comment_record.author_exact_role, comment_record.created_at
  from public.v1_material_request_comments comment_record
  where comment_record.request_id = request.id
  order by comment_record.created_at, comment_record.id limit 1
) first_comment on true
join lateral (
  select comment_record.created_at
  from public.v1_material_request_comments comment_record
  where comment_record.request_id = request.id
  order by comment_record.created_at desc, comment_record.id desc limit 1
) latest_comment on true
where request.request_number is not null
on conflict do nothing;

insert into public.v1_chat_members (
  conversation_id, auth_user_id, member_role, joined_at
)
select distinct conversation.id, candidate.auth_user_id,
  case when candidate.auth_user_id = conversation.created_by_auth_user_id
    then 'owner' else 'member' end,
  conversation.created_at
from public.v1_chat_conversations conversation
join public.v1_material_requests request
  on request.id = conversation.material_request_id
join lateral (
  select request.created_by_auth_user_id as auth_user_id
  union select comment_record.author_auth_user_id
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = request.id
  union select project_member.member_auth_user_id
    from public.v1_project_members project_member
    where project_member.project_id = request.project_id
      and project_member.effective_from <= clock_timestamp()
      and (project_member.effective_to is null
        or project_member.effective_to > clock_timestamp())
  union select profile.auth_user_id
    from public.v1_profiles profile
    where profile.is_active and public.v1_chat_exact_role(
      profile.auth_user_id
    ) in ('admin', 'procurement', 'senior_mechanical_engineer',
      'project_manager')
) candidate on true
join public.v1_profiles profile
  on profile.auth_user_id = candidate.auth_user_id
where conversation.kind = 'material_request'
  and profile.is_active
on conflict (conversation_id, auth_user_id) do nothing;

insert into public.v1_chat_messages (
  id, conversation_id, kind, sender_auth_user_id, sender_exact_role,
  sender_display_name_snapshot, body, created_at
)
select comment_record.id, conversation.id, 'message',
  comment_record.author_auth_user_id, comment_record.author_exact_role,
  comment_record.author_display_name_snapshot, comment_record.body,
  comment_record.created_at
from public.v1_material_request_comments comment_record
join public.v1_chat_conversations conversation
  on conversation.kind = 'material_request'
 and conversation.material_request_id = comment_record.request_id
on conflict (id) do nothing;

insert into public.v1_chat_message_mentions (
  message_id, mentioned_auth_user_id, created_at
)
select mention.comment_id, mention.mentioned_auth_user_id, mention.created_at
from public.v1_material_request_comment_mentions mention
join public.v1_chat_messages message on message.id = mention.comment_id
on conflict do nothing;

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
  v_existing jsonb;
  v_thread_response jsonb;
  v_message_response jsonb;
  v_conversation_id uuid;
  v_message_id uuid;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'body', 'mentioned_auth_user_ids'],
    'material_request_comment'
  );
  v_request_id := nullif(btrim(coalesce(
    p_payload ->> 'request_id', ''
  )), '')::uuid;
  v_body := nullif(btrim(coalesce(p_payload ->> 'body', '')), '');
  v_mentions := coalesce(
    p_payload -> 'mentioned_auth_user_ids', '[]'::jsonb
  );
  if v_request_id is null or v_body is null or char_length(v_body) > 4000
    or jsonb_typeof(v_mentions) <> 'array'
    or not public.v1_material_request_readable(v_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_INVALID'
      using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_add_material_request_comment', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_thread_response := public.v1_create_chat_conversation(
    jsonb_build_object(
      'kind', 'material_request',
      'material_request_id', v_request_id,
      'participant_auth_user_ids', '[]'::jsonb
    ),
    p_idempotency_key
  );
  v_conversation_id := (
    v_thread_response -> 'conversation' ->> 'id'
  )::uuid;
  v_message_response := public.v1_send_chat_message(
    jsonb_build_object(
      'conversation_id', v_conversation_id,
      'body', v_body,
      'attachment_ids', '[]'::jsonb,
      'mentioned_auth_user_ids', v_mentions
    ),
    p_idempotency_key
  );
  v_message_id := (v_message_response -> 'message' ->> 'id')::uuid;

  -- Retain the legacy relations as a read-compatible immutable projection for
  -- older releases and rollback. Team Chat remains the canonical write path;
  -- the projection shares the exact message identifier and cannot diverge.
  insert into public.v1_material_request_comments (
    id, request_id, body, author_auth_user_id, author_role,
    author_exact_role, author_display_name_snapshot, created_at
  )
  select message.id, v_request_id, message.body,
    message.sender_auth_user_id,
    public.v1_canonical_role_from_exact_role(message.sender_exact_role),
    message.sender_exact_role, message.sender_display_name_snapshot,
    message.created_at
  from public.v1_chat_messages message
  where message.id = v_message_id
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
  perform public.v1_write_audit_event(
    'material_request_commented', 'chat_message', v_message_id,
    (select request.project_id from public.v1_material_requests request
      where request.id = v_request_id),
    null,
    jsonb_build_object(
      'request_id', v_request_id,
      'conversation_id', v_conversation_id,
      'mention_count', jsonb_array_length(v_mentions)
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
     set last_read_at = clock_timestamp(),
         marked_unread_at = null,
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = p_conversation_id
     and member.auth_user_id = auth.uid();
  update public.v1_notifications notification
     set seen_at = coalesce(notification.seen_at, clock_timestamp())
   where notification.recipient_auth_user_id = auth.uid()
     and notification.seen_at is null
     and (
       (notification.entity_type = 'chat_message' and exists (
         select 1 from public.v1_chat_messages message
         where message.id = notification.entity_id
           and message.conversation_id = p_conversation_id
       ))
       or (notification.entity_type = 'chat_conversation'
         and notification.entity_id = p_conversation_id)
       or (notification.entity_type = 'material_request' and exists (
         select 1 from public.v1_chat_conversations conversation
         where conversation.id = p_conversation_id
           and conversation.kind = 'material_request'
           and conversation.material_request_id = notification.entity_id
       ))
     );
  return true;
end;
$$;

create or replace function public.v1_mark_chat_unread(
  p_conversation_id uuid
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last_other_at timestamptz;
begin
  if not public.v1_chat_is_active_member(p_conversation_id, auth.uid()) then
    raise exception 'V1_CHAT_UNREAD_DENIED' using errcode = '42501';
  end if;
  select message.created_at into v_last_other_at
  from public.v1_chat_messages message
  where message.conversation_id = p_conversation_id
    and message.sender_auth_user_id <> auth.uid()
  order by message.created_at desc, message.id desc limit 1;
  if v_last_other_at is null then return false; end if;
  update public.v1_chat_members member
     set marked_unread_at = v_last_other_at - interval '1 microsecond',
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = p_conversation_id
     and member.auth_user_id = auth.uid();
  return true;
end;
$$;

create or replace function public.v1_set_chat_preference(
  p_conversation_id uuid,
  p_preference text,
  p_enabled boolean
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.v1_chat_is_active_member(p_conversation_id, auth.uid())
    or p_preference not in ('pinned', 'muted', 'archived') then
    raise exception 'V1_CHAT_PREFERENCE_DENIED' using errcode = '42501';
  end if;
  update public.v1_chat_members member
     set is_pinned = case when p_preference = 'pinned'
       then p_enabled else member.is_pinned end,
         is_muted = case when p_preference = 'muted'
       then p_enabled else member.is_muted end,
         is_archived = case when p_preference = 'archived'
       then p_enabled else member.is_archived end,
         preferences_updated_at = clock_timestamp()
   where member.conversation_id = p_conversation_id
     and member.auth_user_id = auth.uid();
  return true;
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
  from public.v1_chat_messages message where message.id = p_message_id;
  if not public.v1_chat_is_active_member(v_conversation_id, auth.uid()) then
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
  from public.v1_chat_messages message where message.id = p_message_id;
  if not public.v1_chat_is_active_member(v_conversation_id, auth.uid()) then
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
  select * into v_attachment from public.v1_chat_attachments attachment
  where attachment.id = p_attachment_id;
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

create or replace function public.v1_chat_upload_intent_permits(
  p_bucket_id text,
  p_object_path text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_bucket_id = 'yorks-chat-attachments'
    and auth.uid() is not null
    and public.v1_current_actor_is_active()
    and exists (
      select 1 from public.v1_chat_attachment_upload_intents intent
      where intent.bucket_id = p_bucket_id
        and intent.object_path = p_object_path
        and intent.actor_auth_user_id = auth.uid()
        and intent.finalized_at is null
        and intent.expires_at > clock_timestamp()
    );
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
        select 1 from public.v1_chat_attachments attachment
        where attachment.bucket_id = p_bucket_id
          and attachment.object_path = p_object_path
          and public.v1_chat_is_active_member(
            attachment.conversation_id, auth.uid()
          )
      )
      or public.v1_chat_upload_intent_permits(p_bucket_id, p_object_path)
    );
$$;

drop policy if exists v1_chat_attachment_insert_intent on storage.objects;
create policy v1_chat_attachment_insert_intent
on storage.objects for insert to authenticated
with check (public.v1_chat_upload_intent_permits(bucket_id, name));

drop policy if exists v1_chat_attachment_select_member on storage.objects;
create policy v1_chat_attachment_select_member
on storage.objects for select to authenticated
using (public.v1_chat_attachment_readable(bucket_id, name));

-- Realtime only signals authorized clients to refetch trusted RPC projections.
drop policy if exists v1_chat_conversations_select_member
  on public.v1_chat_conversations;
create policy v1_chat_conversations_select_member
on public.v1_chat_conversations for select to authenticated
using (public.v1_chat_is_active_member(id, auth.uid()));

drop policy if exists v1_chat_members_select_self_conversation
  on public.v1_chat_members;
create policy v1_chat_members_select_self_conversation
on public.v1_chat_members for select to authenticated
using (public.v1_chat_is_active_member(conversation_id, auth.uid()));

drop policy if exists v1_chat_messages_select_member
  on public.v1_chat_messages;
create policy v1_chat_messages_select_member
on public.v1_chat_messages for select to authenticated
using (public.v1_chat_is_active_member(conversation_id, auth.uid()));

drop policy if exists v1_chat_acknowledgements_select_member
  on public.v1_chat_message_acknowledgements;
create policy v1_chat_acknowledgements_select_member
on public.v1_chat_message_acknowledgements for select to authenticated
using (exists (
  select 1 from public.v1_chat_messages message
  where message.id = message_id
    and public.v1_chat_is_active_member(message.conversation_id, auth.uid())
));

drop policy if exists v1_chat_pins_select_member
  on public.v1_chat_message_pins;
create policy v1_chat_pins_select_member
on public.v1_chat_message_pins for select to authenticated
using (public.v1_chat_is_active_member(conversation_id, auth.uid()));

grant select on table public.v1_chat_conversations,
  public.v1_chat_members, public.v1_chat_messages,
  public.v1_chat_message_acknowledgements,
  public.v1_chat_message_pins to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_chat_conversations'
  ) then
    alter publication supabase_realtime
      add table public.v1_chat_conversations;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_chat_messages'
  ) then
    alter publication supabase_realtime add table public.v1_chat_messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_chat_members'
  ) then
    alter publication supabase_realtime add table public.v1_chat_members;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_chat_message_acknowledgements'
  ) then
    alter publication supabase_realtime
      add table public.v1_chat_message_acknowledgements;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_chat_message_pins'
  ) then
    alter publication supabase_realtime
      add table public.v1_chat_message_pins;
  end if;
end;
$$;

create or replace function public.v1_resolve_notification_chat_conversation_id(
  p_entity_type text,
  p_entity_id uuid
) returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select case p_entity_type
    when 'chat_message' then (
      select message.conversation_id
      from public.v1_chat_messages message where message.id = p_entity_id
    )
    when 'chat_conversation' then p_entity_id
    else null::uuid
  end;
$$;

drop function if exists public.v1_list_my_notifications(integer);
create function public.v1_list_my_notifications(
  p_limit integer default 100
) returns table (
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
  order by notification.created_at desc, notification.id desc
  limit greatest(1, least(coalesce(p_limit, 100), 200));
end;
$$;

-- Push claims include the route-safe chat conversation ID; no message text or
-- attachment metadata crosses the notification transport boundary.
create or replace function public.v1_claim_notification_push(
  p_notification_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt integer;
  v_notification public.v1_notifications%rowtype;
begin
  update public.v1_notification_push_outbox outbox
     set status = 'sending',
         attempt_count = outbox.attempt_count + 1,
         lease_until = clock_timestamp() + interval '2 minutes',
         updated_at = clock_timestamp()
   where outbox.notification_id = p_notification_id
     and (
       (outbox.status in ('pending', 'failed')
        and outbox.next_attempt_at <= clock_timestamp())
       or (outbox.status = 'sending'
        and outbox.lease_until < clock_timestamp())
     )
  returning outbox.attempt_count into v_attempt;
  if v_attempt is null then return null; end if;
  select * into strict v_notification
  from public.v1_notifications notification
  where notification.id = p_notification_id;
  return jsonb_build_object(
    'notificationId', v_notification.id,
    'recipientAuthUserId', v_notification.recipient_auth_user_id,
    'eventCode', v_notification.event_code,
    'entityType', v_notification.entity_type,
    'entityId', v_notification.entity_id,
    'requestId', public.v1_resolve_notification_request_id(
      v_notification.entity_type, v_notification.entity_id
    ),
    'projectId', v_notification.project_id,
    'chatConversationId',
      public.v1_resolve_notification_chat_conversation_id(
        v_notification.entity_type, v_notification.entity_id
      ),
    'attemptCount', v_attempt
  );
exception when no_data_found then
  return null;
end;
$$;

revoke all on function public.v1_chat_is_active_member(uuid, uuid),
  public.v1_chat_safe_display_name(uuid),
  public.v1_chat_exact_role(uuid),
  public.v1_sync_chat_context_members(uuid),
  public.v1_chat_message_json(uuid, uuid),
  public.v1_chat_conversation_json(uuid, uuid),
  public.v1_chat_upload_intent_projection(uuid),
  public.v1_verify_chat_attachment_upload(uuid, text, bigint, text),
  public.v1_append_chat_system_event(uuid, text, uuid, timestamptz),
  public.v1_chat_audit_event_bridge(),
  public.v1_chat_upload_intent_permits(text, text),
  public.v1_chat_attachment_readable(text, text),
  public.v1_resolve_notification_chat_conversation_id(text, uuid)
from public, anon, authenticated;

-- Authenticated SELECT/Realtime and Storage policies execute this caller-bound
-- boolean predicate. It reveals no row values and cannot test another actor
-- because the function requires p_auth_user_id = auth.uid().
grant execute on function public.v1_chat_is_active_member(uuid, uuid)
to authenticated;

revoke all on function public.v1_list_chat_directory(),
  public.v1_list_chat_conversations(),
  public.v1_search_chat(text, integer),
  public.v1_list_chat_context_targets(text),
  public.v1_get_chat_conversation(uuid, timestamptz, integer),
  public.v1_create_chat_conversation(jsonb, uuid),
  public.v1_update_chat_group(jsonb, uuid),
  public.v1_prepare_chat_attachment(jsonb, uuid),
  public.v1_chat_upload_intent_projection(uuid),
  public.v1_send_chat_message(jsonb, uuid),
  public.v1_mark_chat_read(uuid),
  public.v1_mark_chat_unread(uuid),
  public.v1_set_chat_preference(uuid, text, boolean),
  public.v1_toggle_chat_acknowledgement(uuid),
  public.v1_toggle_chat_message_pin(uuid),
  public.v1_download_chat_attachment(uuid),
  public.v1_list_my_notifications(integer),
  public.v1_claim_notification_push(uuid)
from public, anon;

grant execute on function public.v1_list_chat_directory(),
  public.v1_list_chat_conversations(),
  public.v1_search_chat(text, integer),
  public.v1_list_chat_context_targets(text),
  public.v1_get_chat_conversation(uuid, timestamptz, integer),
  public.v1_create_chat_conversation(jsonb, uuid),
  public.v1_update_chat_group(jsonb, uuid),
  public.v1_prepare_chat_attachment(jsonb, uuid),
  public.v1_chat_upload_intent_projection(uuid),
  public.v1_send_chat_message(jsonb, uuid),
  public.v1_mark_chat_read(uuid),
  public.v1_mark_chat_unread(uuid),
  public.v1_set_chat_preference(uuid, text, boolean),
  public.v1_toggle_chat_acknowledgement(uuid),
  public.v1_toggle_chat_message_pin(uuid),
  public.v1_download_chat_attachment(uuid),
  public.v1_list_my_notifications(integer)
to authenticated;

grant execute on function public.v1_claim_notification_push(uuid)
to service_role;

grant execute on function public.v1_verify_chat_attachment_upload(
  uuid, text, bigint, text
) to service_role;

-- Storage evaluates every applicable bucket policy. These helpers expose no
-- rows and return true only for the current actor's exact live upload intent
-- or an attachment in a conversation the actor can still access.
grant execute on function public.v1_chat_upload_intent_permits(text, text),
  public.v1_chat_attachment_readable(text, text)
to authenticated;

commit;
