#!/usr/bin/env bash

set -euo pipefail

task_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
task_workspace_root="$(cd "$task_script_dir/.." && pwd)"
task_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yorks-t07-lifecycle-concurrency.XXXXXX")"
task_db_container=""
task_blocker_app=""

task_cleanup() {
  if [[ -n "$task_db_container" && -n "$task_blocker_app" ]]; then
    docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres \
      -c "select pg_terminate_backend(pid) from pg_stat_activity where application_name = '$task_blocker_app'" \
      >/dev/null 2>&1 || true
  fi
  rm -R -- "$task_tmp_dir"
}
trap task_cleanup EXIT INT TERM

cd "$task_workspace_root"

# Reuse the accepted local-only T06 harness to establish a clean reset and a
# retained normalized Workforce parent fixture. It never targets remote URLs.
./tool/test_workforce_t06_monthly_period_concurrency.sh >/dev/null

task_status_json="$(npx --yes supabase status --output json 2>/dev/null)"
task_db_url="$(printf '%s' "$task_status_json" | jq -er '.DB_URL')"
case "$task_db_url" in
  postgresql://postgres:*@127.0.0.1:*/* | postgresql://postgres:*@localhost:*/*) ;;
  *) echo "Refusing to run against a non-local database: $task_db_url" >&2; exit 1 ;;
esac
task_db_container="$(docker ps \
  --filter "label=com.supabase.cli.workdir=$task_workspace_root" \
  --filter "name=supabase_db_" --format '{{.Names}}')"
if [[ -z "$task_db_container" || "$(printf '%s\n' "$task_db_container" | wc -l | tr -d ' ')" != "1" ]]; then
  echo "Expected exactly one repository-local Supabase database container." >&2
  exit 1
fi

task_period_id="59980000-0000-4000-8000-000000000001"
task_claims_a='{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}'
task_claims_b='{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}'

docker exec -i "$task_db_container" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres >/dev/null <<'SQL'
begin;
insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,record_version,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '59980000-0000-4000-8000-000000000001','59830000-0000-4000-8000-000000000001',
  '2025-03-01','59981000-0000-4000-8000-000000000001',1,'ready_for_review',1,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
  validation_status,source_fingerprint,worker_count,date_count,authority_snapshot,
  validated_by_auth_user_id,validated_by_exact_role,idempotency_key) values(
  '59981000-0000-4000-8000-000000000001','59980000-0000-4000-8000-000000000001',1,
  'ready_for_review',public.v1_workforce_monthly_source_fingerprint(
    '59830000-0000-4000-8000-000000000001','2025-03-01'),1,1,
  '{"fixture":"t07-concurrency"}','10000000-0000-4000-8000-000000000004','admin',
  '59990000-0000-4000-8000-000000000001');
insert into public.v1_workforce_monthly_period_dates(validation_run_id,worker_id,
  work_date,is_future,is_required,day_type,daily_status,worker_snapshot,
  assignment_snapshot,schedule_snapshot,scheduled_minutes,regular_minutes,
  overtime_minutes,allocation_minutes) values(
  '59981000-0000-4000-8000-000000000001','59840000-0000-4000-8000-000000000001',
  '2025-03-01',false,false,'not_scheduled','not_started',
  '{"worker_number":"WF-T07-RACE","worker_name":"T07 Race Worker"}',
  '{"team_id":"59830000-0000-4000-8000-000000000001","project_id":"59810000-0000-4000-8000-000000000001","project_scope_id":"59820000-0000-4000-8000-000000000001"}',
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":0,"day_type":"not_scheduled"}',
  0,0,0,0);

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
select ('599a0000-0000-4000-8000-'||lpad(row_number() over()::text,12,'0'))::uuid,
  actor,capability,'grant','project','permission_management','2025-01-01',
  'T07 local concurrency authority','10000000-0000-4000-8000-000000000004'
from (values
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.timesheets.review'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.timesheets.verify'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.timesheets.review'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.timesheets.verify')
) grant_row(actor,capability);
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select id,'59810000-0000-4000-8000-000000000001'
from public.v1_permission_assignments where reason='T07 local concurrency authority';
insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,scope_kind,
  project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values
  ('599b0000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002',
    'project','59810000-0000-4000-8000-000000000001','2025-01-01','2025-12-31',
    'T07 race reviewer A','10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004'),
  ('599b0000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003',
    'project','59810000-0000-4000-8000-000000000001','2025-01-01','2025-12-31',
    'T07 race reviewer B','10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004'),
  ('599b0000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000004',
    'organization',null,'2025-03-01','2025-03-31',
    'T07 race Admin full-period organization authority',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59980000-0000-4000-8000-000000000001","warning_issue_ids":[],"reason":"T07 race submission"}',
  1,'59990000-0000-4000-8000-000000000002');
commit;
SQL

task_db_scalar() {
  docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres -c "$1"
}

task_run_writer() {
  local task_app_name="$1" task_claims="$2" task_key="$3" task_output="$4"
  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose \
    -v "claims=$task_claims" -v "period_id=$task_period_id" -v "key=$task_key" \
    -U postgres -d postgres >"$task_output" 2>&1 <<'SQL'
set statement_timeout='30s';
set role authenticated;
select set_config('request.jwt.claims',:'claims',false);
select public.v1_verify_workforce_monthly_period(
  jsonb_build_object('period_id',:'period_id','reason','T07 competing verification'),
  2,:'key'::uuid);
SQL
}

task_writer_a_app="yorks_t07_verify_writer_a"
task_writer_b_app="yorks_t07_verify_writer_b"
task_blocker_app="yorks_t07_verify_blocker"
task_writer_a_output="$task_tmp_dir/writer-a.log"
task_writer_b_output="$task_tmp_dir/writer-b.log"

docker exec -i -e "PGAPPNAME=$task_blocker_app" "$task_db_container" \
  psql -X -Atq -v ON_ERROR_STOP=1 -v "period_id=$task_period_id" \
  -U postgres -d postgres >/dev/null 2>&1 <<'SQL' &
begin;
select pg_advisory_xact_lock(hashtextextended(
  'v1_workforce_t07_period|'||:'period_id',0));
select pg_sleep(30);
commit;
SQL
task_blocker_pid=$!
for ((task_attempt=0;task_attempt<100;task_attempt+=1)); do
  [[ "$(task_db_scalar "select count(*) from pg_stat_activity where application_name='$task_blocker_app' and wait_event='PgSleep'")" == "1" ]] && break
  sleep 0.05
done
[[ "$task_attempt" != "100" ]] || { echo "Could not establish T07 barrier." >&2; exit 1; }

task_run_writer "$task_writer_a_app" "$task_claims_a" \
  '59990000-0000-4000-8000-000000000003' "$task_writer_a_output" &
task_writer_a_pid=$!
task_run_writer "$task_writer_b_app" "$task_claims_b" \
  '59990000-0000-4000-8000-000000000004' "$task_writer_b_output" &
task_writer_b_pid=$!

task_waiting_count=0
for ((task_attempt=0;task_attempt<200;task_attempt+=1)); do
  task_waiting_count="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_writer_a_app','$task_writer_b_app') and wait_event_type='Lock' and query like '%v1_verify_workforce_monthly_period%'")"
  [[ "$task_waiting_count" == "2" ]] && break
  sleep 0.05
done
[[ "$task_waiting_count" == "2" ]] || { echo "Both T07 writers did not enter the RPC." >&2; exit 1; }
task_db_scalar "select count(*) from (select pg_terminate_backend(pid) from pg_stat_activity where application_name='$task_blocker_app') stopped" >/dev/null
task_blocker_app=""
wait "$task_blocker_pid" || true
wait "$task_writer_a_pid" && task_writer_a_status=0 || task_writer_a_status=$?
wait "$task_writer_b_pid" && task_writer_b_status=0 || task_writer_b_status=$?
if [[ "$task_writer_a_status" == 0 && "$task_writer_b_status" != 0 ]]; then
  task_loser_output="$task_writer_b_output"
elif [[ "$task_writer_b_status" == 0 && "$task_writer_a_status" != 0 ]]; then
  task_loser_output="$task_writer_a_output"
else
  echo "Expected one T07 winner; statuses $task_writer_a_status/$task_writer_b_status." >&2
  exit 1
fi
rg -q '40001: +V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' "$task_loser_output" || {
  echo "T07 loser did not return stable 40001 conflict." >&2; sed -n '1,80p' "$task_loser_output" >&2; exit 1; }

task_summary="$(task_db_scalar "select concat_ws('|',
  (select concat_ws(':',record_version,current_status) from public.v1_workforce_monthly_periods where id='$task_period_id'),
  (select count(*) from public.v1_workforce_monthly_transitions where period_id='$task_period_id' and action_kind='verify_forward'),
  (select count(*) from public.v1_audit_events where event_type='workforce_monthly_period_verified' and idempotency_key in ('59990000-0000-4000-8000-000000000003','59990000-0000-4000-8000-000000000004')),
  (select count(*) from public.v1_idempotency_keys where command_name='v1_verify_workforce_monthly_period' and idempotency_key in ('59990000-0000-4000-8000-000000000003','59990000-0000-4000-8000-000000000004') and completed_at is not null))")"
[[ "$task_summary" == '3:awaiting_final_approval|1|1|1' ]] || {
  echo "T07 authoritative state mismatch: $task_summary" >&2; exit 1; }

echo "T07 verify race: PASS (two independent RPC sessions; one winner, one stable 40001 conflict)"
echo "T07 state: PASS (one authoritative transition, audit and completed idempotency effect)"
echo "Workforce T07 local lifecycle concurrency harness: PASS"
