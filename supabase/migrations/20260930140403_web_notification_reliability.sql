-- Web registrations are bound to the Supabase session that enrolled them.
-- Existing tokens are retained but must re-enroll before they can receive.
alter table public.v1_push_device_tokens add column if not exists auth_session_id uuid;
-- Web inbox paging and a separate protected attention projection. Additive:
-- retain all history, existing RPCs and Chat cursor authority. Rollback clients
-- first, then drop only the new functions; never restore unlimited retries.
create or replace function public.v1_notification_page(
  p_limit integer default 100, p_before_created_at timestamptz default null,
  p_before_id uuid default null, p_unread_only boolean default false,
  p_urgent_only boolean default false, p_search text default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid(); v_rows jsonb; v_chat jsonb; v_unread bigint;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_LIST_DENIED' using errcode = '42501';
  end if;
  if (p_before_created_at is null) <> (p_before_id is null) then
    raise exception 'V1_NOTIFICATION_CURSOR_INVALID' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
    select n.id notification_id, n.event_code, n.entity_type, n.entity_id,
      public.v1_resolve_notification_request_id(n.entity_type,n.entity_id) request_id,
      n.project_id,
      public.v1_resolve_notification_chat_conversation_id(n.entity_type,n.entity_id) chat_conversation_id,
      n.created_at, n.seen_at,
      case when public.v1_permission_actor_can_view_project(n.project_id) then
        (select concat_ws(' · ', p.project_ref, r.request_number)
          from public.v1_projects p left join public.v1_material_requests r
            on r.id=public.v1_resolve_notification_request_id(n.entity_type,n.entity_id)
          where p.id=n.project_id) else null end record_label
    from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor
      and not public.v1_notification_is_chat_transport(n.event_code,n.entity_type)
      and (p_search is null or btrim(p_search)='' or (
        replace(n.event_code,'_',' ') ilike '%'||left(btrim(p_search),120)||'%'
        or (public.v1_permission_actor_can_view_project(n.project_id) and exists(
          select 1 from public.v1_projects p left join public.v1_material_requests r
            on r.id=public.v1_resolve_notification_request_id(n.entity_type,n.entity_id)
          where p.id=n.project_id and concat_ws(' ',p.project_ref,r.request_number)
            ilike '%'||left(btrim(p_search),120)||'%'))))
      and (not p_unread_only or n.seen_at is null)
      and (not p_urgent_only or n.event_code in ('accounts_invoice_overdue','accounts_pdc_overdue'))
      and (p_before_created_at is null or (n.created_at,n.id) < (p_before_created_at,p_before_id))
    order by n.created_at desc,n.id desc
    limit greatest(1,least(coalesce(p_limit,100),200)) + 1
  ) r;
  -- Chat stays out of history and its unread total. This recipient-only feed
  -- gives foreground attention the same durable source as background push.
  -- Include fresh workflow events too so inbox filters never hide attention.
  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_chat from (
    select n.id notification_id,n.event_code,n.entity_type,n.entity_id,
      null::uuid request_id,n.project_id,
      public.v1_resolve_notification_chat_conversation_id(n.entity_type,n.entity_id) chat_conversation_id,
      n.created_at,n.seen_at
    from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor and n.seen_at is null
      and n.created_at > now() - interval '5 minutes'
    order by n.created_at desc,n.id desc limit 100
  ) r;
  select count(*) into v_unread from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor and n.seen_at is null
      and not public.v1_notification_is_chat_transport(n.event_code,n.entity_type);
  return jsonb_build_object('records',v_rows,'attention',v_chat,'unreadCount',v_unread, 'servicePaused', (select operator_paused or circuit_open_until is not null from public.v1_push_transport_control where id));
end; $$;
revoke all on function public.v1_notification_page(integer,timestamptz,uuid,boolean,boolean,text) from public,anon;
grant execute on function public.v1_notification_page(integer,timestamptz,uuid,boolean,boolean,text) to authenticated;

-- Revalidate immediately before claim and immediately before each device send.
create or replace function public.v1_push_notification_relevant(p_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.v1_notifications n
    join public.v1_profiles p on p.auth_user_id=n.recipient_auth_user_id
    where n.id=p_id and p.is_active and n.seen_at is null
      and n.created_at > now()-interval '24 hours'
      and public.v1_notification_push_allowed(n.recipient_auth_user_id,n.event_code));
$$;
revoke all on function public.v1_push_notification_relevant(uuid) from public,anon,authenticated;
create or replace function public.v1_claim_notification_push(
  p_notification_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_attempt integer;
  v_claim_id uuid := extensions.gen_random_uuid();
  v_notification public.v1_notifications%rowtype;
  v_control public.v1_push_transport_control%rowtype;
begin
  select * into v_control from public.v1_push_transport_control where id for update;
  if v_control.operator_paused then return null; end if;
  if v_control.circuit_open_until is not null
     and v_control.probe_notification_id is distinct from p_notification_id
    then return null; end if;
  select * into v_notification from public.v1_notifications
    where id = p_notification_id;
  if not found then return null; end if;
  if not public.v1_push_notification_relevant(p_notification_id) then
    update public.v1_notification_push_outbox o set
      status = 'no_devices', last_error_code = 'NOTIFICATION_NO_LONGER_RELEVANT',
      lease_until = null, dispatch_lease_until = null,
      completed_at = clock_timestamp(), updated_at = clock_timestamp()
      where o.notification_id = p_notification_id
        and o.status in ('pending','retry_wait','failed');
    update public.v1_push_transport_control set
      probe_notification_id = null,
      circuit_open_until = clock_timestamp() + interval '15 minutes',
      updated_at = clock_timestamp()
      where id and probe_notification_id = p_notification_id;
    return null;
  end if;
  update public.v1_notification_push_outbox o set
    status = 'sending', attempt_count = o.attempt_count + 1,
    claim_id = v_claim_id, last_attempt_at = clock_timestamp(),
    send_started_at = null,
    lease_until = clock_timestamp() + interval '2 minutes',
    dispatch_lease_until = null, updated_at = clock_timestamp()
    where o.notification_id = p_notification_id
      and o.status in ('pending','retry_wait','failed')
      and o.dispatch_lease_until > clock_timestamp()
      and o.attempt_count < 6
      and o.created_at >= clock_timestamp() - interval '24 hours'
    returning o.attempt_count into v_attempt;
  if v_attempt is null then return null; end if;
  return jsonb_build_object(
    'notificationId',v_notification.id,
    'expiresAt',v_notification.created_at + interval '24 hours',
    'recipientAuthUserId',v_notification.recipient_auth_user_id,
    'eventCode',v_notification.event_code,
    'entityType',v_notification.entity_type,
    'entityId',v_notification.entity_id,
    'requestId',public.v1_resolve_notification_request_id(
      v_notification.entity_type,v_notification.entity_id),
    'projectId',v_notification.project_id,
    'chatConversationId',public.v1_resolve_notification_chat_conversation_id(
      v_notification.entity_type,v_notification.entity_id),
    'unreadCount',public.v1_notification_unread_count(
      v_notification.recipient_auth_user_id),
    'attemptCount',v_attempt,'claimId',v_claim_id
  );
end;
$$;
revoke all on function public.v1_claim_notification_push(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_claim_notification_push(uuid)
  to service_role;

create or replace function public.v1_begin_push_device(
  p_notification_id uuid,p_claim_id uuid,p_token_hash text
) returns text language plpgsql security definer set search_path = '' as $$
declare v_o public.v1_notification_push_outbox%rowtype; v_status text;
begin
  perform 1 from public.v1_push_transport_control where id for update;
  if exists(select 1 from public.v1_push_transport_control where id and
    (operator_paused or (circuit_open_until is not null
      and probe_notification_id is distinct from p_notification_id))) then
    return 'blocked';
  end if;
  select * into v_o from public.v1_notification_push_outbox
    where notification_id=p_notification_id for update;
  if not found or v_o.status <> 'sending' or v_o.claim_id<>p_claim_id
    or p_claim_id is null or v_o.lease_until<=clock_timestamp() then
    return 'blocked';
  end if;
  if not public.v1_push_notification_relevant(p_notification_id) then return 'not_owned'; end if;
  select status into v_status from public.v1_push_device_deliveries
    where notification_id=p_notification_id and token_hash=p_token_hash;
  if v_status in ('sent','sending','dead_letter') then return v_status; end if;
  if not exists(select 1 from public.v1_push_device_tokens t
    join public.v1_notifications n on n.recipient_auth_user_id=t.auth_user_id
    where n.id=p_notification_id and t.retired_at is null
      and (t.platform<>'web' or (exists(select 1 from auth.sessions a
        where a.id=t.auth_session_id and a.user_id=t.auth_user_id
          and (a.not_after is null or a.not_after>clock_timestamp()))
        and t.installation_id is not null and n.created_at>=t.enrolled_at
        and t.web_origin=any((select allowed_web_origins
          from public.v1_push_transport_control where id)::text[])))
      and encode(extensions.digest(t.token,'sha256'),'hex')=p_token_hash) then
    return 'not_owned';
  end if;
  update public.v1_notification_push_outbox set
    send_started_at=coalesce(send_started_at,clock_timestamp())
    where notification_id=p_notification_id;
  insert into public.v1_push_device_deliveries
    (notification_id,token_hash,claim_id,status) values
    (p_notification_id,p_token_hash,p_claim_id,'sending')
    on conflict(notification_id,token_hash) do update set
      claim_id=excluded.claim_id,status='sending',error_code=null,
      updated_at=clock_timestamp();
  return 'ready';
end;
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
     and outbox.status in ('pending', 'retry_wait', 'failed')
     and not public.v1_notification_push_allowed(
       v_actor, notification.event_code
     );

  -- Enabling is prospective. Never replay previously suppressed history.
  return public.v1_notification_preferences_json(v_actor);
end;
$$;

create or replace function public.v1_push_backend_health()
returns jsonb language sql stable security definer set search_path = '' as $$
  with cutoff as (select clock_timestamp() as at),
  notification_counts as (
    select count(*) filter(where n.created_at>=c.at-interval '1 hour') as h1,
           count(*) as h24
    from public.v1_notifications n cross join cutoff c
    where n.created_at>=c.at-interval '24 hours'
  ),
  event_counts as (
    select count(*) filter(where e.event_code='claimed'
      and e.occurred_at>=c.at-interval '1 hour') as attempts_1h,
      count(*) filter(where e.event_code='sent'
      and e.occurred_at>=c.at-interval '1 hour') as sent_1h,
      count(*) filter(where e.event_code='no_devices'
      and e.occurred_at>=c.at-interval '1 hour') as no_devices_1h,
      count(*) filter(where e.event_code='dead_letter'
      and e.occurred_at>=c.at-interval '1 hour') as dead_letter_1h,
      count(*) filter(where e.event_code='claimed' and e.attempt_count>1
        and e.occurred_at>=c.at-interval '1 hour') as retries_1h,
      count(*) filter(where e.event_code='claimed' and e.attempt_count>1) as retries_24h,
      count(*) filter(where e.event_code='claimed') as attempts_24h,
      count(*) filter(where e.event_code='sent') as sent_24h,
      count(*) filter(where e.event_code='no_devices') as no_devices_24h,
      count(*) filter(where e.event_code='dead_letter') as dead_letter_24h,
      max(e.occurred_at) filter(where e.event_code='sent') as last_sent_at
    from public.v1_push_delivery_events e cross join cutoff c
    where e.occurred_at>=c.at-interval '24 hours'
  ),
  errors as (
    select coalesce(jsonb_object_agg(error_code,total),'{}'::jsonb) as categories
    from (select error_code,count(*) as total
      from public.v1_push_delivery_events e cross join cutoff c
      where e.occurred_at>=c.at-interval '24 hours'
        and e.error_code is not null
      group by error_code) grouped
  ),
  outbox_counts as (
    select count(*) filter(where status='retry_wait') as retrying,
           count(*) filter(where status='dead_letter') as dead_letter_total,
           max(attempt_count) as max_attempts,
           min(created_at) filter(where status='retry_wait') as oldest_retry
    from public.v1_notification_push_outbox
  ),
  devices as (select count(*) as tokens,
    count(distinct auth_user_id) as users from public.v1_push_device_tokens)
  select jsonb_build_object(
    'pendingCount',(select count(*) from public.v1_notification_push_outbox where status in ('pending','retry_wait')),
    'oldestPendingAt',(select min(created_at) from public.v1_notification_push_outbox where status in ('pending','retry_wait')),
    'eligibleWebInstallations',(select count(*) from public.v1_push_device_tokens where platform='web' and retired_at is null and installation_id is not null and auth_session_id is not null and exists(select 1 from auth.sessions a where a.id=auth_session_id and a.user_id=auth_user_id and (a.not_after is null or a.not_after>clock_timestamp())) and web_origin=any(t.allowed_web_origins)),
    'asOf',c.at,'notifications1h',n.h1,'notifications24h',n.h24,
    'attempts1h',e.attempts_1h,'attempts24h',e.attempts_24h,
    'retries1h',e.retries_1h,'retries24h',e.retries_24h,
    'sent1h',e.sent_1h,'sent24h',e.sent_24h,
    'noDevices1h',e.no_devices_1h,'noDevices24h',e.no_devices_24h,
    'deadLetter1h',e.dead_letter_1h,'deadLetter24h',e.dead_letter_24h,
    'successPercent24h',case when e.attempts_24h=0 then null
      else round(100.0*e.sent_24h/e.attempts_24h,1) end,
    'retrying',o.retrying,'deadLetterTotal',o.dead_letter_total,
    'highestHistoricalAttemptCount',o.max_attempts,
    'oldestRetry',o.oldest_retry,'latestSuccessfulPush',t.last_success_at,
    'errorsByCategory',er.categories,
    'activeTokens',d.tokens,'usersWithTokens',d.users,
    'operatorPaused',t.operator_paused,
    'circuitOpenUntil',t.circuit_open_until,
    'lastGlobalError',t.last_global_error_code,
    'lastWorkerAt',t.last_worker_at,
    'highestActiveAttemptCount', (select coalesce(max(attempt_count),0)
      from public.v1_notification_push_outbox where status in
        ('pending','retry_wait','sending','failed')))
  from cutoff c cross join notification_counts n cross join event_counts e
    cross join errors er cross join outbox_counts o cross join devices d
    cross join public.v1_push_transport_control t where t.id;
$$;
revoke all on function public.v1_push_backend_health()
  from public, anon, authenticated;
grant execute on function public.v1_push_backend_health() to service_role;
create or replace function public.v1_register_push_installation(
  p_token text,p_platform text,p_web_origin text,p_installation_id uuid
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_token text:=btrim(coalesce(p_token,''));
  v_session uuid := nullif(auth.jwt()->>'session_id','')::uuid;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PUSH_DEVICE_REGISTER_DENIED' using errcode='42501';
  end if;
  -- Serializes rotation against other registrations and the send gate.
  perform 1 from public.v1_push_transport_control where id for update;
  if p_platform<>'web' or p_installation_id is null or not exists(
    select 1 from public.v1_push_transport_control where id
      and p_web_origin=any(allowed_web_origins)) then
    raise exception 'V1_PUSH_ORIGIN_NOT_ALLOWED' using errcode='22023';
  end if;
  if length(v_token) not between 20 and 4096 then
    raise exception 'V1_PUSH_DEVICE_TOKEN_INVALID' using errcode='22023';
  end if;
  if not exists(select 1 from auth.sessions where id=v_session and user_id=v_actor
    and (not_after is null or not_after>clock_timestamp())) then
    raise exception 'V1_PUSH_SESSION_REQUIRED' using errcode='42501';
  end if;
  update public.v1_push_device_tokens set retired_at=clock_timestamp()
    where auth_user_id=v_actor and web_origin=p_web_origin
      and installation_id=p_installation_id and token<>v_token
      and retired_at is null;
  insert into public.v1_push_device_tokens
    (token,auth_user_id,platform,web_origin,installation_id,retired_at,enrolled_at,auth_session_id)
    values(v_token,v_actor,'web',p_web_origin,p_installation_id,null,clock_timestamp(),v_session)
    on conflict(token) do update set auth_user_id=excluded.auth_user_id,
      platform='web',web_origin=excluded.web_origin,auth_session_id=v_session,
      enrolled_at=case when public.v1_push_device_tokens.auth_user_id=v_actor
        and public.v1_push_device_tokens.web_origin=p_web_origin
        and public.v1_push_device_tokens.installation_id=p_installation_id
        then public.v1_push_device_tokens.enrolled_at else clock_timestamp() end,
      installation_id=excluded.installation_id,retired_at=null,
      last_seen_at=clock_timestamp();
  return true;
end;
$$;
revoke all on function public.v1_register_push_installation(text,text,text,uuid)
  from public,anon;
grant execute on function public.v1_register_push_installation(text,text,text,uuid)
  to authenticated;
