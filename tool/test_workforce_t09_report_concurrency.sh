#!/usr/bin/env bash

set -euo pipefail

task_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
task_workspace_root="$(cd "$task_script_dir/.." && pwd)"
task_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yorks-t09-report-concurrency.XXXXXX")"
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

# Establishes a clean local-only database and one accepted awaiting-approval
# T07 period. The inherited harness refuses every non-local database URL.
./tool/test_workforce_t07_lifecycle_concurrency.sh >/dev/null

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
task_team_id="59830000-0000-4000-8000-000000000001"
task_actor_id="10000000-0000-4000-8000-000000000001"
task_report_key="59990000-0000-4000-8000-000000000091"
task_issue_key="59990000-0000-4000-8000-000000000092"
task_claims='{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}'

docker exec -i "$task_db_container" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres >/dev/null <<'SQL'
begin;
insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
select ('599a0000-0000-4000-8000-'||lpad(row_number() over()::text,12,'9'))::uuid,
  '10000000-0000-4000-8000-000000000001'::uuid,capability,'grant','project',
  'permission_management','2025-01-01','T09 local report race authority',
  '10000000-0000-4000-8000-000000000004'::uuid
from (values ('workforce.view'),('workforce.timesheets.final_approve'),
  ('workforce.reports.export')) grant_row(capability);
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select id,'59810000-0000-4000-8000-000000000001'
from public.v1_permission_assignments
where reason='T09 local report race authority';
insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values(
  '599b0000-0000-4000-8000-000000000091',
  '10000000-0000-4000-8000-000000000001','project',
  '59810000-0000-4000-8000-000000000001','2025-01-01','2025-12-31',
  'T09 report race responsibility','10000000-0000-4000-8000-000000000004',
  'admin','10000000-0000-4000-8000-000000000004');
commit;

set role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',false);
select public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59980000-0000-4000-8000-000000000001","reason":"T09 race source approval"}',
  3,'59990000-0000-4000-8000-000000000090');
SQL

task_db_scalar() {
  docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres -c "$1"
}

task_snapshot_id="$(task_db_scalar "select id from public.v1_workforce_monthly_approved_snapshots where period_id='$task_period_id' order by approval_revision_number desc limit 1")"
[[ -n "$task_snapshot_id" ]] || { echo "T09 approved source was not created." >&2; exit 1; }

task_run_writer() {
  local task_app_name="$1" task_output="$2"
  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose \
    -v "claims=$task_claims" -v "snapshot_id=$task_snapshot_id" \
    -v "team_id=$task_team_id" -v "key=$task_report_key" \
    -U postgres -d postgres >"$task_output" 2>&1 <<'SQL'
set statement_timeout='30s';
set role authenticated;
select set_config('request.jwt.claims',:'claims',false);
select public.v1_generate_workforce_report(jsonb_build_object(
  'report_kind','supervisor_team_monthly','snapshot_ids',jsonb_build_array(:'snapshot_id'),
  'team_id',:'team_id'),:'key'::uuid);
SQL
}

task_blocker_app="yorks_t09_report_blocker"
task_writer_a_app="yorks_t09_report_writer_a"
task_writer_b_app="yorks_t09_report_writer_b"
task_writer_a_output="$task_tmp_dir/writer-a.log"
task_writer_b_output="$task_tmp_dir/writer-b.log"

docker exec -i -e "PGAPPNAME=$task_blocker_app" "$task_db_container" \
  psql -X -Atq -v ON_ERROR_STOP=1 -U postgres -d postgres >/dev/null 2>&1 <<'SQL' &
begin;
lock table public.v1_idempotency_keys in access exclusive mode;
select pg_sleep(30);
commit;
SQL
task_blocker_pid=$!
for ((task_attempt=0;task_attempt<100;task_attempt+=1)); do
  [[ "$(task_db_scalar "select count(*) from pg_stat_activity where application_name='$task_blocker_app' and wait_event='PgSleep'")" == "1" ]] && break
  sleep 0.05
done
[[ "$task_attempt" != "100" ]] || { echo "Could not establish T09 barrier." >&2; exit 1; }

task_run_writer "$task_writer_a_app" "$task_writer_a_output" &
task_writer_a_pid=$!
task_run_writer "$task_writer_b_app" "$task_writer_b_output" &
task_writer_b_pid=$!

task_waiting_count=0
for ((task_attempt=0;task_attempt<200;task_attempt+=1)); do
  task_waiting_count="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_writer_a_app','$task_writer_b_app') and wait_event_type='Lock' and query like '%v1_generate_workforce_report%'")"
  [[ "$task_waiting_count" == "2" ]] && break
  sleep 0.05
done
[[ "$task_waiting_count" == "2" ]] || { echo "Both T09 writers did not enter the RPC." >&2; exit 1; }
task_db_scalar "select count(*) from (select pg_terminate_backend(pid) from pg_stat_activity where application_name='$task_blocker_app') stopped" >/dev/null
task_blocker_app=""
wait "$task_blocker_pid" || true
wait "$task_writer_a_pid"
wait "$task_writer_b_pid"

task_artifact_a="$(tail -n 1 "$task_writer_a_output" | jq -er '.artifact_id')"
task_artifact_b="$(tail -n 1 "$task_writer_b_output" | jq -er '.artifact_id')"
[[ "$task_artifact_a" == "$task_artifact_b" ]] || {
  echo "T09 retry returned different artifacts: $task_artifact_a / $task_artifact_b" >&2
  exit 1
}

task_summary="$(task_db_scalar "select concat_ws('|',
  (select count(*) from public.v1_workforce_report_artifacts where generated_by_auth_user_id='$task_actor_id' and idempotency_key='$task_report_key'),
  (select count(*) from public.v1_workforce_report_artifact_snapshots where report_artifact_id='$task_artifact_a'),
  (select count(*) from public.v1_audit_events where event_type='report_generated' and entity_id='$task_artifact_a'),
  (select count(*) from public.v1_idempotency_keys where command_name='v1_generate_workforce_report' and idempotency_key='$task_report_key' and completed_at is not null))")"
[[ "$task_summary" == '1|1|1|1' ]] || {
  echo "T09 authoritative artifact mismatch: $task_summary" >&2
  exit 1
}

task_run_issue_writer() {
  local task_app_name="$1" task_output="$2"
  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose \
    -v "claims=$task_claims" -v "artifact_id=$task_artifact_a" \
    -v "key=$task_issue_key" -U postgres -d postgres >"$task_output" 2>&1 <<'SQL'
set statement_timeout='30s';
set role authenticated;
select set_config('request.jwt.claims',:'claims',false);
select public.v1_issue_workforce_report_export(jsonb_build_object(
  'artifact_id',:'artifact_id','format','pdf','action','download'),:'key'::uuid);
SQL
}

task_blocker_app="yorks_t09_issue_blocker"
task_issue_writer_a_app="yorks_t09_issue_writer_a"
task_issue_writer_b_app="yorks_t09_issue_writer_b"
task_issue_writer_a_output="$task_tmp_dir/issue-writer-a.log"
task_issue_writer_b_output="$task_tmp_dir/issue-writer-b.log"

docker exec -i -e "PGAPPNAME=$task_blocker_app" "$task_db_container" \
  psql -X -Atq -v ON_ERROR_STOP=1 -U postgres -d postgres >/dev/null 2>&1 <<'SQL' &
begin;
lock table public.v1_idempotency_keys in access exclusive mode;
select pg_sleep(30);
commit;
SQL
task_blocker_pid=$!
for ((task_attempt=0;task_attempt<100;task_attempt+=1)); do
  [[ "$(task_db_scalar "select count(*) from pg_stat_activity where application_name='$task_blocker_app' and wait_event='PgSleep'")" == "1" ]] && break
  sleep 0.05
done
[[ "$task_attempt" != "100" ]] || { echo "Could not establish T09 issuance barrier." >&2; exit 1; }

task_run_issue_writer "$task_issue_writer_a_app" "$task_issue_writer_a_output" &
task_issue_writer_a_pid=$!
task_run_issue_writer "$task_issue_writer_b_app" "$task_issue_writer_b_output" &
task_issue_writer_b_pid=$!
task_waiting_count=0
for ((task_attempt=0;task_attempt<200;task_attempt+=1)); do
  task_waiting_count="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_issue_writer_a_app','$task_issue_writer_b_app') and wait_event_type='Lock' and query like '%v1_issue_workforce_report_export%'")"
  [[ "$task_waiting_count" == "2" ]] && break
  sleep 0.05
done
[[ "$task_waiting_count" == "2" ]] || { echo "Both T09 issuance writers did not enter the RPC." >&2; exit 1; }
task_db_scalar "select count(*) from (select pg_terminate_backend(pid) from pg_stat_activity where application_name='$task_blocker_app') stopped" >/dev/null
task_blocker_app=""
wait "$task_blocker_pid" || true
wait "$task_issue_writer_a_pid"
wait "$task_issue_writer_b_pid"

task_issue_a="$(tail -n 1 "$task_issue_writer_a_output")"
task_issue_b="$(tail -n 1 "$task_issue_writer_b_output")"
[[ "$task_issue_a" == "$task_issue_b" ]] || {
  echo "T09 issuance retry returned different receipts." >&2
  exit 1
}
task_issue_summary="$(task_db_scalar "select concat_ws('|',
  (select count(*) from public.v1_audit_events where event_type='workforce_export_generated' and entity_id='$task_artifact_a' and idempotency_key='$task_issue_key'),
  (select count(*) from public.v1_idempotency_keys where command_name='v1_issue_workforce_report_export' and idempotency_key='$task_issue_key' and completed_at is not null))")"
[[ "$task_issue_summary" == '1|1' ]] || {
  echo "T09 authoritative issuance mismatch: $task_issue_summary" >&2
  exit 1
}

# The accepted T07 setup harness uses the seeded role fixtures to establish the
# approved source. Remove only those temporary access grants after the race so
# the retained report/lifecycle evidence can coexist with the complete pgTAP
# suite, whose transactions create their own grants for the same seeded actors.
docker exec -i "$task_db_container" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres >/dev/null <<'SQL'
begin;
delete from public.v1_permission_assignment_projects project_link
using public.v1_permission_assignments assignment
where project_link.assignment_id=assignment.id
  and assignment.reason in (
    'T07 local concurrency authority',
    'T09 local report race authority'
  );
delete from public.v1_permission_assignments
where reason in (
  'T07 local concurrency authority',
  'T09 local report race authority'
);
commit;
SQL

echo "T09 report retry race: PASS (two independent RPC sessions returned one artifact)"
echo "T09 issuance retry race: PASS (two independent RPC sessions returned one receipt)"
echo "T09 state: PASS (one snapshot link, generation audit, issuance audit and completed idempotency effects)"
echo "Workforce T09 local report concurrency harness: PASS"
