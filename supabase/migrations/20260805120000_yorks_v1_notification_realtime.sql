-- R35 in-app action indicators.
--
-- Notifications contain only an event code and entity identifiers. They are
-- safe to expose as a recipient-scoped read signal; workflow data remains
-- behind the existing trusted projection RPCs. This migration is additive and
-- does not grant any write access to authenticated clients.

grant select on table public.v1_notifications to authenticated;

drop policy if exists v1_notifications_select_recipient
  on public.v1_notifications;
create policy v1_notifications_select_recipient
on public.v1_notifications
for select
to authenticated
using (
  recipient_auth_user_id = (select auth.uid())
  or coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') = 'admin'
);

do $$
begin
  if exists (
    select 1 from pg_catalog.pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_catalog.pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'v1_notifications'
  ) then
    alter publication supabase_realtime add table public.v1_notifications;
  end if;
end;
$$;
