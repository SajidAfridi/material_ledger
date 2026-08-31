#!/usr/bin/env bash

set -euo pipefail

task_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
task_workspace_root="$(cd "$task_script_dir/.." && pwd)"
task_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yorks-t03-concurrency.XXXXXX")"
task_db_container=""
task_blocker_app=""

task_cleanup() {
  if [[ -n "$task_db_container" && -n "$task_blocker_app" ]]; then
    docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres \
      -c "select pg_terminate_backend(pid) from pg_stat_activity where application_name = '$task_blocker_app'" \
      >/dev/null 2>&1 || true
  fi
  if [[ -d "$task_tmp_dir" ]]; then
    rm -R -- "$task_tmp_dir"
  fi
}
trap task_cleanup EXIT INT TERM

cd "$task_workspace_root"

echo "Resetting the repository-local Supabase database..."
npx --yes supabase db reset --local >/dev/null

task_status_json="$(npx --yes supabase status --output json 2>/dev/null)"
task_db_url="$(printf '%s' "$task_status_json" | jq -er '.DB_URL')"
case "$task_db_url" in
  postgresql://postgres:*@127.0.0.1:*/* | postgresql://postgres:*@localhost:*/*)
    ;;
  *)
    echo "Refusing to run against a non-local database: $task_db_url" >&2
    exit 1
    ;;
esac

task_db_containers="$(
  docker ps \
    --filter "label=com.supabase.cli.workdir=$task_workspace_root" \
    --filter "name=supabase_db_" \
    --format '{{.Names}}'
)"
if [[ -z "$task_db_containers" || "$(printf '%s\n' "$task_db_containers" | wc -l | tr -d ' ')" != "1" ]]; then
  echo "Expected exactly one repository-local Supabase database container." >&2
  exit 1
fi
task_db_container="$task_db_containers"

task_worker_id="59240000-0000-4000-8000-000000000001"
task_work_date="2026-08-30"
task_admin_claims='{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}'

docker exec -i "$task_db_container" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres >/dev/null <<'SQL'
begin;

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59210000-0000-4000-8000-000000000001', 'WF-T03-CONCURRENCY',
  'Workforce T03 concurrency fixture', 'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable
) values (
  '59220000-0000-4000-8000-000000000001',
  '59210000-0000-4000-8000-000000000001',
  'common', 'common', 'Common / All Buildings', true
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59230000-0000-4000-8000-000000000001', 'WF-T03-CONCURRENCY',
  'T03 Concurrency Team', '59210000-0000-4000-8000-000000000001',
  '59220000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59240000-0000-4000-8000-000000000001', 'WF-T03-CONCURRENT-WORKER',
  'T03 Concurrent Worker', 'Ductman', 'Yorks AC & Ref.',
  'yorks_employee', '2026-01-01', 'active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59250000-0000-4000-8000-000000000001',
  '59240000-0000-4000-8000-000000000001', 'primary',
  '59230000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '59210000-0000-4000-8000-000000000001',
  '59220000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', 'T03 concurrency fixture assignment',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59260000-0000-4000-8000-000000000001', 'WF-T03-CONCURRENCY',
  'T03 Concurrency Calendar', 'Asia/Dubai', 480, 60,
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select
  '59260000-0000-4000-8000-000000000001'::uuid,
  weekday, 'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59280000-0000-4000-8000-000000000001',
  '59230000-0000-4000-8000-000000000001',
  '59260000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', 'T03 concurrency fixture schedule',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

commit;
SQL

task_db_scalar() {
  docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres \
    -c "$1"
}

task_run_writer() {
  local task_app_name="$1"
  local task_payload="$2"
  local task_expected_version="$3"
  local task_idempotency_key="$4"
  local task_output_file="$5"

  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose \
    -v "claims=$task_admin_claims" \
    -v "payload=$task_payload" \
    -v "expected_version=$task_expected_version" \
    -v "idempotency_key=$task_idempotency_key" \
    -U postgres -d postgres >"$task_output_file" 2>&1 <<'SQL'
set statement_timeout = '15s';
set role authenticated;
select set_config('request.jwt.claims', :'claims', false);
select public.v1_save_workforce_attendance_day(
  :'payload'::jsonb,
  :expected_version::bigint,
  :'idempotency_key'::uuid
);
SQL
}

task_run_race() {
  local task_phase="$1"
  local task_expected_version="$2"
  local task_payload_a="$3"
  local task_idempotency_a="$4"
  local task_payload_b="$5"
  local task_idempotency_b="$6"
  local task_writer_a_app="yorks_t03_${task_phase}_writer_a"
  local task_writer_b_app="yorks_t03_${task_phase}_writer_b"
  local task_writer_a_output="$task_tmp_dir/${task_phase}_writer_a.log"
  local task_writer_b_output="$task_tmp_dir/${task_phase}_writer_b.log"
  local task_blocker_output="$task_tmp_dir/${task_phase}_blocker.log"
  local task_blocker_pid
  local task_writer_a_pid
  local task_writer_b_pid
  local task_writer_a_status
  local task_writer_b_status
  local task_loser_output
  local task_waiting_count="0"
  local task_attempt

  task_blocker_app="yorks_t03_${task_phase}_blocker"
  docker exec -i -e "PGAPPNAME=$task_blocker_app" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 \
    -v "worker_id=$task_worker_id" -v "work_date=$task_work_date" \
    -U postgres -d postgres >"$task_blocker_output" 2>&1 <<'SQL' &
begin;
select pg_advisory_xact_lock(
  pg_catalog.hashtextextended(
    'v1_workforce_attendance|' || :'worker_id' || '|' || :'work_date', 0
  )
);
select pg_sleep(30);
commit;
SQL
  task_blocker_pid=$!

  for ((task_attempt = 0; task_attempt < 100; task_attempt += 1)); do
    if [[ "$(task_db_scalar "select count(*) from pg_stat_activity where application_name = '$task_blocker_app' and wait_event = 'PgSleep'")" == "1" ]]; then
      break
    fi
    sleep 0.05
  done
  if [[ "$task_attempt" == "100" ]]; then
    echo "$task_phase race could not establish the local advisory-lock barrier." >&2
    exit 1
  fi

  task_run_writer "$task_writer_a_app" "$task_payload_a" \
    "$task_expected_version" "$task_idempotency_a" \
    "$task_writer_a_output" &
  task_writer_a_pid=$!
  task_run_writer "$task_writer_b_app" "$task_payload_b" \
    "$task_expected_version" "$task_idempotency_b" \
    "$task_writer_b_output" &
  task_writer_b_pid=$!

  for ((task_attempt = 0; task_attempt < 200; task_attempt += 1)); do
    task_waiting_count="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_writer_a_app', '$task_writer_b_app') and wait_event_type = 'Lock' and query like '%v1_save_workforce_attendance_day%'")"
    if [[ "$task_waiting_count" == "2" ]]; then
      break
    fi
    sleep 0.05
  done
  if [[ "$task_waiting_count" != "2" ]]; then
    echo "$task_phase race did not place both writer sessions inside the save RPC." >&2
    exit 1
  fi

  task_db_scalar "select count(*) from (select pg_terminate_backend(pid) from pg_stat_activity where application_name = '$task_blocker_app') terminated" \
    >/dev/null
  task_blocker_app=""
  if wait "$task_blocker_pid"; then
    :
  fi

  if wait "$task_writer_a_pid"; then
    task_writer_a_status=0
  else
    task_writer_a_status=$?
  fi
  if wait "$task_writer_b_pid"; then
    task_writer_b_status=0
  else
    task_writer_b_status=$?
  fi

  if [[ "$task_writer_a_status" == "0" && "$task_writer_b_status" != "0" ]]; then
    task_loser_output="$task_writer_b_output"
  elif [[ "$task_writer_b_status" == "0" && "$task_writer_a_status" != "0" ]]; then
    task_loser_output="$task_writer_a_output"
  else
    echo "$task_phase race expected exactly one success; writer statuses were $task_writer_a_status and $task_writer_b_status." >&2
    exit 1
  fi
  if ! grep -Eq '40001: +V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT' "$task_loser_output"; then
    echo "$task_phase race loser did not return the stable 40001 version conflict." >&2
    sed -n '1,80p' "$task_loser_output" >&2
    exit 1
  fi

  echo "$task_phase race: PASS (two RPC sessions blocked together; one commit, one stable 40001 conflict)"
}

task_run_race \
  "create" \
  "null" \
  "{\"worker_id\":\"$task_worker_id\",\"work_date\":\"$task_work_date\",\"attendance_status\":\"present\",\"regular_minutes\":480,\"overtime_minutes\":0,\"reason\":\"Concurrent create A\"}" \
  "59290000-0000-4000-8000-000000000001" \
  "{\"worker_id\":\"$task_worker_id\",\"work_date\":\"$task_work_date\",\"attendance_status\":\"present\",\"regular_minutes\":420,\"overtime_minutes\":60,\"reason\":\"Concurrent create B\"}" \
  "59290000-0000-4000-8000-000000000002"

task_create_summary="$(task_db_scalar "
  select concat_ws('|',
    (select count(*) from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date'),
    (select record_version from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date'),
    (select count(*) from public.v1_audit_events where event_type = 'workforce_attendance_day_created' and entity_id = (select id from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date')),
    (select count(*) from public.v1_idempotency_keys where command_name = 'v1_save_workforce_attendance_day' and idempotency_key in ('59290000-0000-4000-8000-000000000001', '59290000-0000-4000-8000-000000000002') and completed_at is not null),
    (select count(*) from public.v1_audit_events audit join public.v1_idempotency_keys idem on idem.actor_auth_user_id = audit.actor_auth_user_id and idem.idempotency_key = audit.idempotency_key where audit.event_type = 'workforce_attendance_day_created' and audit.entity_id = (select id from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date') and idem.command_name = 'v1_save_workforce_attendance_day' and idem.completed_at is not null)
  )
")"
if [[ "$task_create_summary" != "1|1|1|1|1" ]]; then
  echo "Create-race authoritative state mismatch: $task_create_summary" >&2
  exit 1
fi
echo "create state: PASS (1 row, version 1, 1 create audit, 1 completed effect)"

task_run_race \
  "correction" \
  "1" \
  "{\"worker_id\":\"$task_worker_id\",\"work_date\":\"$task_work_date\",\"attendance_status\":\"present\",\"regular_minutes\":450,\"overtime_minutes\":30,\"reason\":\"Concurrent correction A\"}" \
  "59290000-0000-4000-8000-000000000003" \
  "{\"worker_id\":\"$task_worker_id\",\"work_date\":\"$task_work_date\",\"attendance_status\":\"absent\",\"regular_minutes\":0,\"overtime_minutes\":0,\"reason\":\"Concurrent correction B\"}" \
  "59290000-0000-4000-8000-000000000004"

task_correction_summary="$(task_db_scalar "
  select concat_ws('|',
    (select count(*) from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date'),
    (select record_version from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date'),
    (select count(*) from public.v1_audit_events where event_type = 'workforce_attendance_day_created' and entity_id = (select id from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date')),
    (select count(*) from public.v1_audit_events where event_type = 'workforce_attendance_day_corrected' and entity_id = (select id from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date')),
    (select count(*) from public.v1_idempotency_keys where command_name = 'v1_save_workforce_attendance_day' and idempotency_key in ('59290000-0000-4000-8000-000000000003', '59290000-0000-4000-8000-000000000004') and completed_at is not null),
    (select count(*) from public.v1_workforce_attendance_days where worker_id = '$task_worker_id' and work_date = '$task_work_date' and ((reason = 'Concurrent correction A' and regular_minutes = 450 and overtime_minutes = 30) or (reason = 'Concurrent correction B' and regular_minutes = 0 and overtime_minutes = 0)))
  )
")"
if [[ "$task_correction_summary" != "1|2|1|1|1|1" ]]; then
  echo "Correction-race authoritative state mismatch: $task_correction_summary" >&2
  exit 1
fi
echo "correction state: PASS (1 row, version 2, 1 correction audit, 1 completed effect, winning payload retained)"
echo "Workforce T03 local concurrency harness: PASS"
