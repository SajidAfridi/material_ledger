#!/usr/bin/env bash
set -euo pipefail
# Local-only, transactional migration replay. All fixture and DDL changes roll back.
task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
{
cat <<'SQL'
begin;
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id)
values('9b000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003',
'material_request_submitted','material_request','9b000000-0000-4000-8000-000000000002');
update public.v1_notification_push_outbox set status='failed',attempt_count=605,
last_error_code='FCM_SEND_FAILED',created_at=clock_timestamp()-interval '30 days'
where notification_id='9b000000-0000-4000-8000-000000000001';
SQL
cat "$task_root/supabase/migrations/20260929150000_bound_push_delivery_and_health.sql"
cat "$task_root/supabase/migrations/20260929150000_bound_push_delivery_and_health.sql"
cat <<'SQL'
do $$ begin
if not exists(select 1 from public.v1_notification_push_outbox
where notification_id='9b000000-0000-4000-8000-000000000001'
and status='dead_letter' and attempt_count=605 and last_error_code='FCM_SEND_FAILED')
then raise exception 'Historical evidence not preserved'; end if;
if not exists(select 1 from public.v1_notifications
where id='9b000000-0000-4000-8000-000000000001')
then raise exception 'In-app history lost'; end if;
if not (public.v1_push_backend_health() ? 'retries1h')
then raise exception 'Missing retry health metric'; end if;
end $$;
rollback;
SQL
} | docker exec -i supabase_db_material_ledger psql -X -q -U postgres -d postgres -v ON_ERROR_STOP=1
echo 'PASS: repeated migration retains notification, terminalizes poison job, preserves 605 attempts/error, and exposes health.'
