-- Yorks V1 trusted push-notification delivery.
--
-- Supabase/Postgres remains the notification authority. Firebase Cloud
-- Messaging is transport only: clients register an owner-bound device token,
-- while an append-only v1_notifications row creates a durable delivery job.
-- The database invokes the Edge Function with only the notification UUID; the
-- server derives the recipient, safe copy and deep link from protected data.

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if not exists (
    select 1 from vault.secrets where name = 'yorks_push_webhook_secret'
  ) then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'yorks_push_webhook_secret',
      'Authenticates Postgres notification outbox calls to send-push'
    );
  end if;
end;
$$;

create table if not exists public.v1_push_device_tokens (
  token text primary key check (length(token) between 20 and 4096),
  auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete cascade,
  platform text not null check (platform in (
    'android', 'ios', 'web', 'macos', 'windows', 'linux', 'unknown'
  )),
  created_at timestamptz not null default clock_timestamp(),
  last_seen_at timestamptz not null default clock_timestamp()
);

create index if not exists v1_push_device_tokens_owner_idx
  on public.v1_push_device_tokens (auth_user_id, last_seen_at desc);

alter table public.v1_push_device_tokens enable row level security;
revoke all on table public.v1_push_device_tokens
  from public, anon, authenticated;
grant all on table public.v1_push_device_tokens to service_role;

create table if not exists public.v1_notification_push_outbox (
  notification_id uuid primary key references public.v1_notifications (id)
    on delete cascade,
  status text not null default 'pending' check (status in (
    'pending', 'sending', 'sent', 'no_devices', 'failed'
  )),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  next_attempt_at timestamptz not null default clock_timestamp(),
  lease_until timestamptz,
  last_error_code text,
  sent_device_count integer not null default 0
    check (sent_device_count >= 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz
);

create index if not exists v1_notification_push_outbox_pending_idx
  on public.v1_notification_push_outbox (next_attempt_at, created_at)
  where status in ('pending', 'failed', 'sending');

alter table public.v1_notification_push_outbox enable row level security;
revoke all on table public.v1_notification_push_outbox
  from public, anon, authenticated;
grant all on table public.v1_notification_push_outbox to service_role;

create or replace function public.v1_resolve_notification_request_id(
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
    when 'material_request' then p_entity_id
    when 'procurement_arrangement' then (
      select arrangement.request_id
      from public.v1_procurement_arrangements arrangement
      where arrangement.id = p_entity_id
    )
    when 'material_dispatch' then (
      select dispatch.request_id
      from public.v1_material_dispatches dispatch
      where dispatch.id = p_entity_id
    )
    when 'receipt_review' then (
      select dispatch.request_id
      from public.v1_receipt_reviews review
      join public.v1_material_dispatches dispatch
        on dispatch.id = review.dispatch_id
      where review.id = p_entity_id
    )
    when 'material_return' then (
      select material_return.request_id
      from public.v1_material_returns material_return
      where material_return.id = p_entity_id
    )
    when 'delivery_order' then (
      select delivery_order.request_id
      from public.v1_delivery_orders delivery_order
      where delivery_order.id = p_entity_id
    )
    else null::uuid
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
      notification.entity_type,
      notification.entity_id
    ),
    notification.project_id,
    notification.created_at,
    notification.seen_at
  from public.v1_notifications notification
  where notification.recipient_auth_user_id = v_actor
  order by notification.created_at desc, notification.id desc
  limit greatest(1, least(coalesce(p_limit, 100), 200));
end;
$$;

create or replace function public.v1_mark_notification_seen(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_SEEN_DENIED' using errcode = '42501';
  end if;
  update public.v1_notifications notification
     set seen_at = coalesce(notification.seen_at, clock_timestamp())
   where notification.id = p_notification_id
     and notification.recipient_auth_user_id = v_actor;
  if not found then
    raise exception 'V1_NOTIFICATION_SEEN_DENIED' using errcode = '42501';
  end if;
  return true;
end;
$$;

create or replace function public.v1_register_push_device(
  p_token text,
  p_platform text
)
returns boolean
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

  -- A user may install/open the app after an alert was created. Requeue only
  -- their recent, still-unseen no-device deliveries; the outbox remains
  -- idempotent by notification_id.
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
     and outbox.status = 'no_devices';
  return true;
end;
$$;

create or replace function public.v1_unregister_push_device(p_token text)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null then
    return false;
  end if;
  delete from public.v1_push_device_tokens token
   where token.token = btrim(coalesce(p_token, ''))
     and token.auth_user_id = v_actor;
  return found;
end;
$$;

-- Organization-wide Project Engineer roles receive approval/receipt work even
-- without a project_members row. Existing command RPCs continue to select the
-- project team; this recipient expansion adds only the approved global roles.
create or replace function public.v1_expand_global_notification_recipients()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 1 or new.event_code not in (
    'arrangement_review_required', 'receipt_review_required'
  ) then
    return new;
  end if;
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id,
    created_at
  )
  select profile.auth_user_id, new.event_code, new.entity_type, new.entity_id,
    new.project_id, new.created_at
  from public.v1_profiles profile
  join auth.users auth_user on auth_user.id = profile.auth_user_id
  where profile.is_active
    and coalesce(auth_user.raw_app_meta_data ->> 'role', '') in (
      'senior_mechanical_engineer', 'project_manager'
    )
    and not exists (
      select 1
      from public.v1_notifications existing
      where existing.recipient_auth_user_id = profile.auth_user_id
        and existing.event_code = new.event_code
        and existing.entity_type = new.entity_type
        and existing.entity_id = new.entity_id
    );
  return new;
end;
$$;

drop trigger if exists v1_notifications_expand_global_recipients
  on public.v1_notifications;
create trigger v1_notifications_expand_global_recipients
after insert on public.v1_notifications
for each row execute function public.v1_expand_global_notification_recipients();

create or replace function public.v1_enqueue_notification_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.v1_notification_push_outbox (notification_id)
  values (new.id)
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

drop trigger if exists v1_notifications_enqueue_push
  on public.v1_notifications;
create trigger v1_notifications_enqueue_push
after insert on public.v1_notifications
for each row execute function public.v1_enqueue_notification_push();

create or replace function public.v1_dispatch_push_notification(
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
begin
  if to_regclass('vault.decrypted_secrets') is null then
    return false;
  end if;
  execute
    'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_url using 'yorks_push_edge_url';
  execute
    'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_secret using 'yorks_push_webhook_secret';
  if nullif(v_url, '') is null or nullif(v_secret, '') is null then
    return false;
  end if;
  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-yorks-push-secret', v_secret
    ),
    body := jsonb_build_object('notificationId', p_notification_id),
    timeout_milliseconds := 5000
  );
  return true;
exception when others then
  -- Notification creation must never fail because transport is unavailable.
  return false;
end;
$$;

create or replace function public.v1_validate_push_webhook_secret(
  p_secret text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_expected text;
begin
  if nullif(p_secret, '') is null
     or to_regclass('vault.decrypted_secrets') is null then
    return false;
  end if;
  execute
    'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_expected using 'yorks_push_webhook_secret';
  return v_expected is not null
    and extensions.digest(p_secret, 'sha256')
      = extensions.digest(v_expected, 'sha256');
end;
$$;

create or replace function public.v1_claim_notification_push(
  p_notification_id uuid
)
returns jsonb
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
  if v_attempt is null then
    return null;
  end if;
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
    'attemptCount', v_attempt
  );
exception when no_data_found then
  return null;
end;
$$;

create or replace function public.v1_finish_notification_push(
  p_notification_id uuid,
  p_status text,
  p_sent_device_count integer default 0,
  p_error_code text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt integer;
  v_delay_seconds integer;
begin
  if p_status not in ('sent', 'no_devices', 'failed') then
    raise exception 'V1_PUSH_STATUS_INVALID' using errcode = '22023';
  end if;
  select outbox.attempt_count into v_attempt
  from public.v1_notification_push_outbox outbox
  where outbox.notification_id = p_notification_id
  for update;
  if v_attempt is null then
    return false;
  end if;
  v_delay_seconds := least(3600, 30 * (2 ^ least(v_attempt, 7))::integer);
  update public.v1_notification_push_outbox outbox
     set status = p_status,
         sent_device_count = greatest(0, coalesce(p_sent_device_count, 0)),
         last_error_code = left(nullif(btrim(coalesce(p_error_code, '')), ''), 120),
         next_attempt_at = case when p_status = 'failed'
           then clock_timestamp() + make_interval(secs => v_delay_seconds)
           else outbox.next_attempt_at end,
         lease_until = null,
         completed_at = case when p_status in ('sent', 'no_devices')
           then clock_timestamp() else null end,
         updated_at = clock_timestamp()
   where outbox.notification_id = p_notification_id;
  return found;
end;
$$;

create or replace function public.v1_dispatch_pending_pushes()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_count integer := 0;
begin
  for v_row in
    select outbox.notification_id
    from public.v1_notification_push_outbox outbox
    where (
      outbox.status in ('pending', 'failed')
      and outbox.next_attempt_at <= clock_timestamp()
    ) or (
      outbox.status = 'sending'
      and outbox.lease_until < clock_timestamp()
    )
    order by outbox.created_at
    limit 25
  loop
    if public.v1_dispatch_push_notification(v_row.notification_id) then
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;

create or replace function public.v1_kick_notification_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_dispatch_push_notification(new.notification_id);
  return new;
end;
$$;

drop trigger if exists v1_notification_push_outbox_kick
  on public.v1_notification_push_outbox;
create trigger v1_notification_push_outbox_kick
after insert on public.v1_notification_push_outbox
for each row execute function public.v1_kick_notification_push();

do $$
declare
  v_job_id bigint;
begin
  select jobid into v_job_id from cron.job
  where jobname = 'yorks-v1-push-outbox' limit 1;
  if v_job_id is not null then
    perform cron.unschedule(v_job_id);
  end if;
  perform cron.schedule(
    'yorks-v1-push-outbox',
    '* * * * *',
    'select public.v1_dispatch_pending_pushes();'
  );
end;
$$;

revoke all on function public.v1_resolve_notification_request_id(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_my_notifications(integer)
  from public, anon, authenticated;
revoke all on function public.v1_mark_notification_seen(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_register_push_device(text, text)
  from public, anon, authenticated;
revoke all on function public.v1_unregister_push_device(text)
  from public, anon, authenticated;
revoke all on function public.v1_dispatch_push_notification(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_dispatch_pending_pushes()
  from public, anon, authenticated;
revoke all on function public.v1_validate_push_webhook_secret(text)
  from public, anon, authenticated;
revoke all on function public.v1_claim_notification_push(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_finish_notification_push(uuid, text, integer, text)
  from public, anon, authenticated;

grant execute on function public.v1_list_my_notifications(integer)
  to authenticated;
grant execute on function public.v1_mark_notification_seen(uuid)
  to authenticated;
grant execute on function public.v1_register_push_device(text, text)
  to authenticated;
grant execute on function public.v1_unregister_push_device(text)
  to authenticated;
grant execute on function public.v1_resolve_notification_request_id(text, uuid)
  to service_role;
grant execute on function public.v1_dispatch_push_notification(uuid)
  to service_role;
grant execute on function public.v1_dispatch_pending_pushes()
  to service_role;
grant execute on function public.v1_validate_push_webhook_secret(text)
  to service_role;
grant execute on function public.v1_claim_notification_push(uuid)
  to service_role;
grant execute on function public.v1_finish_notification_push(uuid, text, integer, text)
  to service_role;

-- Rollback: unschedule yorks-v1-push-outbox, drop the three triggers, then the
-- functions and the two new tables. Existing v1_notifications rows and all
-- workflow records are unaffected. Never copy tokens into client-readable
-- legacy collections during rollback.
