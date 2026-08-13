-- A single recipient-owned command keeps unread state authoritative across
-- browser, installed PWA and native sessions without an N-request client loop.
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
     and notification.seen_at is null;
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

revoke all on function public.v1_mark_all_notifications_seen()
  from public, anon, authenticated;
grant execute on function public.v1_mark_all_notifications_seen()
  to authenticated;

-- Rollback: drop public.v1_mark_all_notifications_seen(). Existing seen_at
-- acknowledgements are user activity and intentionally remain preserved.
