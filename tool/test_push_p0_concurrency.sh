#!/usr/bin/env bash
set -euo pipefail

task_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_tmp="$(mktemp -d "${TMPDIR:-/tmp}/yorks-push-race.XXXXXX")"
task_id='9e000000-0000-4000-8000-000000000001'
task_container=''

task_cleanup() {
  if [[ -n "$task_container" ]]; then
    docker exec -i "$task_container" psql -X -Atq -U postgres -d postgres \
      -v ON_ERROR_STOP=1 <<'SQL' >/dev/null 2>&1 || true
delete from public.v1_push_delivery_events
  where notification_id='9e000000-0000-4000-8000-000000000001';
delete from public.v1_notification_push_outbox
  where notification_id='9e000000-0000-4000-8000-000000000001';
delete from public.v1_notifications
  where id='9e000000-0000-4000-8000-000000000001';
update public.v1_push_transport_control set operator_paused=true where id;
SQL
  fi
  rm -rf -- "$task_tmp"
}
trap task_cleanup EXIT INT TERM

cd "$task_root"
task_status="$(npx supabase status --output json 2>/dev/null)"
task_db_url="$(printf '%s' "$task_status" | jq -er '.DB_URL')"
case "$task_db_url" in
  postgresql://postgres:*@127.0.0.1:*/* | postgresql://postgres:*@localhost:*/*) ;;
  *) echo "Refusing non-local database" >&2; exit 1 ;;
esac
task_container="$(docker ps --filter 'name=supabase_db_material_ledger' \
  --format '{{.Names}}')"
if [[ -z "$task_container" || "$task_container" == *$'\n'* ]]; then
  echo "Expected exactly one local Supabase database container" >&2
  exit 1
fi

docker exec -i "$task_container" psql -X -Atq -U postgres -d postgres \
  -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
update public.v1_push_transport_control set operator_paused=false where id;
insert into public.v1_notifications
  (id,recipient_auth_user_id,event_code,entity_type,entity_id)
values ('9e000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9f000000-0000-4000-8000-000000000001');
update public.v1_notification_push_outbox
set dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id='9e000000-0000-4000-8000-000000000001';
SQL

# Worker A holds the outbox row lock after claim. Worker B uses a separate
# Postgres session and must wait, then observe that the job is already sending.
docker exec -i "$task_container" psql -X -Atq -U postgres -d postgres \
  -v ON_ERROR_STOP=1 >"$task_tmp/a.txt" <<'SQL' &
begin;
set local application_name='yorks-push-test-worker-a';
select public.v1_claim_notification_push(
  '9e000000-0000-4000-8000-000000000001');
select pg_sleep(3);
commit;
SQL
task_a_pid=$!
# Wait until A has claimed and is holding its transaction open in pg_sleep.
for task_poll in {1..50}; do
  task_ready="$(docker exec "$task_container" psql -X -Atq -U postgres -d postgres -c "select count(*) from pg_stat_activity where application_name='yorks-push-test-worker-a' and wait_event='PgSleep'")"
  [[ "$task_ready" == 1 ]] && break
  sleep 0.1
done
[[ "$task_ready" == 1 ]] || { echo "Worker A did not acquire claim" >&2; exit 1; }
docker exec -i "$task_container" psql -X -Atq -U postgres -d postgres \
  -v ON_ERROR_STOP=1 >"$task_tmp/b.txt" <<'SQL' &
select public.v1_claim_notification_push(
  '9e000000-0000-4000-8000-000000000001');
SQL
task_b_pid=$!
wait "$task_a_pid"
wait "$task_b_pid"
if ! rg -q '"claimId"' "$task_tmp/a.txt" ||
  [[ -n "$(tr -d '[:space:]' < "$task_tmp/b.txt")" ]]; then
  echo "Concurrent claim failed: first worker or contender result unexpected" >&2
  exit 1
fi
task_attempts="$(docker exec -i "$task_container" psql -X -Atq -U postgres \
  -d postgres -c "select attempt_count from public.v1_notification_push_outbox
  where notification_id='$task_id'")"
if [[ "$task_attempts" != 1 ]]; then
  echo "Expected one attempt, got $task_attempts" >&2
  exit 1
fi

# The worker stalled before marking send-start. Expire it; a new dispatcher
# may recover it. The previous claim must not finish the replacement's send.
docker exec -i "$task_container" psql -X -Atq -U postgres -d postgres \
  -v ON_ERROR_STOP=1 <<'SQL' >/dev/null
update public.v1_notification_push_outbox set
  lease_until=clock_timestamp()-interval '1 second'
where notification_id='9e000000-0000-4000-8000-000000000001';
select public.v1_dispatch_pending_pushes();
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id='9e000000-0000-4000-8000-000000000001';
SQL

task_result="$(docker exec -i "$task_container" psql -X -Atq -U postgres \
  -d postgres -v ON_ERROR_STOP=1 <<'SQL'
with a as (
  select public.v1_claim_notification_push(
    '9e000000-0000-4000-8000-000000000001') as claim
), b as (
  select public.v1_finish_notification_push(
    '9e000000-0000-4000-8000-000000000001',
    (a.claim->>'claimId')::uuid,'sent',1,null,null) as finished from a
)
select finished from b;
SQL
)"
if [[ "$task_result" != "t" ]]; then
  echo "Replacement worker failed to finish" >&2
  exit 1
fi
task_old_claim="$(node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{for(const l of s.split("\n")){try{let x=JSON.parse(l);if(x.claimId){process.stdout.write(x.claimId);break}}catch{}}})' \
  <"$task_tmp/a.txt")"
task_stale="$(docker exec -i "$task_container" psql -X -Atq -U postgres \
  -d postgres -v ON_ERROR_STOP=1 -c "select public.v1_finish_notification_push(
  '$task_id','$task_old_claim','retryable',0,'FCM_UNAVAILABLE',null)")"
if [[ "$task_stale" != "f" ]]; then
  echo "Stale finish was accepted" >&2
  exit 1
fi
echo "PASS: two independent sessions produced one claim; replacement succeeded; stale finish rejected."
