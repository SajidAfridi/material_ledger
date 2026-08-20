-- Yorks notification delivery reliability and server-owned badge counts.
--
-- This migration is additive and data preserving. It does not rewrite
-- notification history, read cursors, registered devices, or outbox results.
-- The push claim receives only one derived integer: the recipient's current
-- unresolved workflow + unmuted Team Chat count. Protected record content
-- never enters the transport payload.

create or replace function public.v1_notification_unread_count(
  p_actor uuid
)
returns integer
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
        and notification.entity_type not in (
          'chat_message', 'chat_conversation'
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
    )
  ))::integer;
$$;

-- Keep the existing atomic lease/claim behavior and add only unreadCount.
-- It is derived after the lease is acquired, so a retried delivery always
-- carries the latest server-authoritative badge rather than a stale snapshot.
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
    'unreadCount', public.v1_notification_unread_count(
      v_notification.recipient_auth_user_id
    ),
    'attemptCount', v_attempt
  );
exception when no_data_found then
  return null;
end;
$$;

revoke all on function public.v1_notification_unread_count(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_claim_notification_push(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_notification_unread_count(uuid)
  to service_role;
grant execute on function public.v1_claim_notification_push(uuid)
  to service_role;

-- Rollback: restore the prior v1_claim_notification_push body without the
-- unreadCount member, then drop v1_notification_unread_count(uuid). Preserve
-- every notification, chat cursor, token and outbox attempt.
