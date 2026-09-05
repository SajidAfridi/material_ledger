-- Yorks personal notification controls.
--
-- The protected notification centre remains the complete in-app workflow
-- record. These preferences control only optional push delivery and foreground
-- presentation. Direct table access is denied; each active user can read and
-- update only their own row through narrow RPCs. Missing rows resolve to the
-- safe, backward-compatible defaults used before this migration.

create table if not exists public.v1_user_notification_preferences (
  auth_user_id uuid primary key references public.v1_profiles (auth_user_id)
    on delete cascade,
  push_enabled boolean not null default true,
  workflow_push_enabled boolean not null default true,
  team_chat_push_enabled boolean not null default true,
  foreground_alerts_enabled boolean not null default true,
  sound_enabled boolean not null default true,
  revision integer not null default 1 check (revision > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null references public.v1_profiles (auth_user_id)
);

alter table public.v1_user_notification_preferences enable row level security;
revoke all on table public.v1_user_notification_preferences
  from public, anon, authenticated;
grant all on table public.v1_user_notification_preferences to service_role;

create or replace function public.v1_notification_preferences_json(
  p_actor uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'schema_version', 1,
    'revision', coalesce(preference.revision, 0),
    'push_enabled', coalesce(preference.push_enabled, true),
    'workflow_push_enabled',
      coalesce(preference.workflow_push_enabled, true),
    'team_chat_push_enabled',
      coalesce(preference.team_chat_push_enabled, true),
    'foreground_alerts_enabled',
      coalesce(preference.foreground_alerts_enabled, true),
    'sound_enabled', coalesce(preference.sound_enabled, true),
    'updated_at', preference.updated_at
  )
  from (select 1) seed
  left join public.v1_user_notification_preferences preference
    on preference.auth_user_id = p_actor;
$$;

create or replace function public.v1_get_my_notification_preferences()
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
    raise exception 'V1_NOTIFICATION_PREFERENCES_READ_DENIED'
      using errcode = '42501';
  end if;
  return public.v1_notification_preferences_json(v_actor);
end;
$$;

create or replace function public.v1_notification_push_allowed(
  p_actor uuid,
  p_event_code text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(preference.push_enabled, true)
    and case
      when p_event_code in ('team_chat_message', 'team_chat_mention')
        then coalesce(preference.team_chat_push_enabled, true)
      else coalesce(preference.workflow_push_enabled, true)
    end
  from (select 1) seed
  left join public.v1_user_notification_preferences preference
    on preference.auth_user_id = p_actor;
$$;

create or replace function public.v1_update_my_notification_preferences(
  p_patch jsonb,
  p_expected_revision integer
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_current public.v1_user_notification_preferences%rowtype;
  v_current_revision integer := 0;
  v_push boolean;
  v_workflow boolean;
  v_chat boolean;
  v_foreground boolean;
  v_sound boolean;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_PREFERENCES_WRITE_DENIED'
      using errcode = '42501';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' or exists (
    select 1 from jsonb_object_keys(p_patch) key
    where key not in (
      'push_enabled', 'workflow_push_enabled', 'team_chat_push_enabled',
      'foreground_alerts_enabled', 'sound_enabled'
    )
  ) then
    raise exception 'V1_NOTIFICATION_PREFERENCES_PATCH_INVALID'
      using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_each(p_patch) pair
    where jsonb_typeof(pair.value) <> 'boolean'
  ) then
    raise exception 'V1_NOTIFICATION_PREFERENCES_VALUE_INVALID'
      using errcode = '22023';
  end if;

  -- Serialize the first write as well as later updates. Without locking the
  -- always-present profile row, two first-device changes could both observe
  -- revision zero and the ON CONFLICT path would silently accept both.
  perform 1
  from public.v1_profiles profile
  where profile.auth_user_id = v_actor
  for update;
  if not found then
    raise exception 'V1_NOTIFICATION_PREFERENCES_WRITE_DENIED'
      using errcode = '42501';
  end if;

  select * into v_current
  from public.v1_user_notification_preferences preference
  where preference.auth_user_id = v_actor
  for update;
  if found then v_current_revision := v_current.revision; end if;

  v_push := coalesce(
    (p_patch ->> 'push_enabled')::boolean,
    case when v_current_revision = 0 then true else v_current.push_enabled end
  );
  v_workflow := coalesce(
    (p_patch ->> 'workflow_push_enabled')::boolean,
    case when v_current_revision = 0 then true
      else v_current.workflow_push_enabled end
  );
  v_chat := coalesce(
    (p_patch ->> 'team_chat_push_enabled')::boolean,
    case when v_current_revision = 0 then true
      else v_current.team_chat_push_enabled end
  );
  v_foreground := coalesce(
    (p_patch ->> 'foreground_alerts_enabled')::boolean,
    case when v_current_revision = 0 then true
      else v_current.foreground_alerts_enabled end
  );
  v_sound := coalesce(
    (p_patch ->> 'sound_enabled')::boolean,
    case when v_current_revision = 0 then true else v_current.sound_enabled end
  );

  -- A repeated command that already reached the requested state is a safe
  -- no-op even if its original response was lost.
  if v_current_revision > 0
     and v_current.push_enabled = v_push
     and v_current.workflow_push_enabled = v_workflow
     and v_current.team_chat_push_enabled = v_chat
     and v_current.foreground_alerts_enabled = v_foreground
     and v_current.sound_enabled = v_sound then
    return public.v1_notification_preferences_json(v_actor);
  end if;
  if coalesce(p_expected_revision, -1) <> v_current_revision then
    raise exception 'V1_NOTIFICATION_PREFERENCES_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  insert into public.v1_user_notification_preferences (
    auth_user_id, push_enabled, workflow_push_enabled,
    team_chat_push_enabled, foreground_alerts_enabled, sound_enabled,
    revision, created_at, updated_at, updated_by
  ) values (
    v_actor, v_push, v_workflow, v_chat, v_foreground, v_sound,
    1, clock_timestamp(), clock_timestamp(), v_actor
  )
  on conflict (auth_user_id) do update set
    push_enabled = excluded.push_enabled,
    workflow_push_enabled = excluded.workflow_push_enabled,
    team_chat_push_enabled = excluded.team_chat_push_enabled,
    foreground_alerts_enabled = excluded.foreground_alerts_enabled,
    sound_enabled = excluded.sound_enabled,
    revision = public.v1_user_notification_preferences.revision + 1,
    updated_at = clock_timestamp(),
    updated_by = v_actor;

  -- A disabled preference stops only deliveries that have not left the
  -- durable outbox. Notification history is never removed or marked read.
  update public.v1_notification_push_outbox outbox
     set status = 'no_devices',
         last_error_code = 'USER_PREFERENCE_DISABLED',
         lease_until = null,
         completed_at = clock_timestamp(),
         updated_at = clock_timestamp()
    from public.v1_notifications notification
   where outbox.notification_id = notification.id
     and notification.recipient_auth_user_id = v_actor
     and outbox.status in ('pending', 'failed')
     and not public.v1_notification_push_allowed(
       v_actor, notification.event_code
     );

  -- Enabling delivery does not replay old history. It requeues only recent,
  -- unseen preference-suppressed events, matching device-registration retry
  -- behavior and preserving the outbox's notification-id idempotency.
  update public.v1_notification_push_outbox outbox
     set status = 'pending',
         next_attempt_at = clock_timestamp(),
         lease_until = null,
         last_error_code = null,
         completed_at = null,
         updated_at = clock_timestamp()
    from public.v1_notifications notification
   where outbox.notification_id = notification.id
     and notification.recipient_auth_user_id = v_actor
     and notification.seen_at is null
     and notification.created_at >= clock_timestamp() - interval '7 days'
     and outbox.status = 'no_devices'
     and outbox.last_error_code = 'USER_PREFERENCE_DISABLED'
     and public.v1_notification_push_allowed(
       v_actor, notification.event_code
     );

  return public.v1_notification_preferences_json(v_actor);
end;
$$;

-- Keep one durable outbox command per authoritative notification, but do not
-- manufacture optional delivery work when that recipient has disabled it.
create or replace function public.v1_enqueue_notification_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.v1_material_request_published_policy_boolean(
    'notifications.push_enabled', true
  ) and public.v1_notification_push_allowed(
    new.recipient_auth_user_id,
    new.event_code
  ) then
    insert into public.v1_notification_push_outbox (notification_id)
    values (new.id)
    on conflict (notification_id) do nothing;
  end if;
  return new;
end;
$$;

-- A queued event can be disabled before the worker claims it. Resolve the
-- preference again at claim time so that race also fails closed.
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
  select * into strict v_notification
  from public.v1_notifications notification
  where notification.id = p_notification_id;

  if not public.v1_notification_push_allowed(
    v_notification.recipient_auth_user_id,
    v_notification.event_code
  ) then
    update public.v1_notification_push_outbox outbox
       set status = 'no_devices',
           last_error_code = 'USER_PREFERENCE_DISABLED',
           lease_until = null,
           completed_at = clock_timestamp(),
           updated_at = clock_timestamp()
     where outbox.notification_id = p_notification_id
       and outbox.status in ('pending', 'failed', 'sending');
    return null;
  end if;

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
    'unreadCount', public.v1_notification_unread_count(
      v_notification.recipient_auth_user_id
    ),
    'attemptCount', v_attempt
  );
exception when no_data_found then
  return null;
end;
$$;

-- Preserve existing registration semantics and add the same preference gate
-- to the recent no-device requeue.
create or replace function public.v1_register_push_device(
  p_token text,
  p_platform text
) returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_token text := btrim(coalesce(p_token, ''));
  v_platform text := lower(btrim(coalesce(p_platform, 'unknown')));
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PUSH_DEVICE_REGISTER_DENIED' using errcode = '42501';
  end if;
  if length(v_token) not between 20 and 4096 then
    raise exception 'V1_PUSH_DEVICE_TOKEN_INVALID' using errcode = '22023';
  end if;
  if v_platform not in (
    'android', 'ios', 'web', 'macos', 'windows', 'linux', 'unknown'
  ) then
    v_platform := 'unknown';
  end if;

  insert into public.v1_push_device_tokens (
    token, auth_user_id, platform, created_at, last_seen_at
  ) values (
    v_token, v_actor, v_platform, clock_timestamp(), clock_timestamp()
  )
  on conflict (token) do update set
    auth_user_id = excluded.auth_user_id,
    platform = excluded.platform,
    last_seen_at = clock_timestamp();

  update public.v1_notification_push_outbox outbox
     set status = 'pending',
         next_attempt_at = clock_timestamp(),
         lease_until = null,
         last_error_code = null,
         updated_at = clock_timestamp(),
         completed_at = null
    from public.v1_notifications notification
   where outbox.notification_id = notification.id
     and notification.recipient_auth_user_id = v_actor
     and notification.seen_at is null
     and notification.created_at >= clock_timestamp() - interval '7 days'
     and outbox.status = 'no_devices'
     and public.v1_notification_push_allowed(
       v_actor, notification.event_code
     );
  return true;
end;
$$;

revoke all on function public.v1_notification_preferences_json(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_my_notification_preferences()
  from public, anon, authenticated;
revoke all on function public.v1_notification_push_allowed(uuid, text)
  from public, anon, authenticated;
revoke all on function public.v1_update_my_notification_preferences(jsonb, integer)
  from public, anon, authenticated;
revoke all on function public.v1_enqueue_notification_push()
  from public, anon, authenticated;
revoke all on function public.v1_claim_notification_push(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_register_push_device(text, text)
  from public, anon, authenticated;

grant execute on function public.v1_get_my_notification_preferences()
  to authenticated;
grant execute on function public.v1_update_my_notification_preferences(jsonb, integer)
  to authenticated;
grant execute on function public.v1_notification_preferences_json(uuid)
  to service_role;
grant execute on function public.v1_notification_push_allowed(uuid, text)
  to service_role;
grant execute on function public.v1_claim_notification_push(uuid)
  to service_role;
grant execute on function public.v1_register_push_device(text, text)
  to authenticated;

-- Rollback: restore the preceding enqueue, claim and registration function
-- bodies, then drop the four preference functions and preference table. This
-- does not remove notifications, read state, device tokens or business data.
