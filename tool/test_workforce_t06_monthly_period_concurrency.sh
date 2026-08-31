#!/usr/bin/env bash

set -euo pipefail

task_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
task_workspace_root="$(cd "$task_script_dir/.." && pwd)"
task_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yorks-t06-monthly-concurrency.XXXXXX")"
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

task_team_id="59830000-0000-4000-8000-000000000001"
task_period_month="2025-02-01"
task_admin_claims='{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}'

docker exec -i "$task_db_container" psql -X -v ON_ERROR_STOP=1 \
  -U postgres -d postgres >/dev/null <<'SQL'
begin;

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59810000-0000-4000-8000-000000000001','WF-T06-CONCURRENCY',
  'T06 Monthly Concurrency Project','active','project_engineer',
  '10000000-0000-4000-8000-000000000004','admin'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values (
  '59820000-0000-4000-8000-000000000001',
  '59810000-0000-4000-8000-000000000001',
  'common','common','Common / All Buildings',true,true
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59830000-0000-4000-8000-000000000001','WF-T06-CONCURRENCY',
  'T06 Monthly Concurrency Team',
  '59810000-0000-4000-8000-000000000001',
  '59820000-0000-4000-8000-000000000001',
  '2025-02-01','2025-02-28',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59840000-0000-4000-8000-000000000001','WF-T06-CONCURRENT-WORKER',
  'T06 Concurrent Monthly Worker','Ductman','Yorks AC & Ref.',
  'yorks_employee','2020-01-01','active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59850000-0000-4000-8000-000000000001',
  '59840000-0000-4000-8000-000000000001','primary',
  '59830000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '59810000-0000-4000-8000-000000000001',
  '59820000-0000-4000-8000-000000000001',
  '2025-02-01','2025-02-28','T06 concurrency assignment',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59860000-0000-4000-8000-000000000001','WF-T06-CONCURRENCY',
  'T06 Monthly Concurrency Calendar','Asia/Dubai',480,60,
  '2025-02-01','2025-02-28',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select '59860000-0000-4000-8000-000000000001'::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1,7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59870000-0000-4000-8000-000000000001',
  '59830000-0000-4000-8000-000000000001',
  '59860000-0000-4000-8000-000000000001',
  '2025-02-01','2025-02-28','T06 concurrency schedule',
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
  local task_idempotency_key="$2"
  local task_output_file="$3"

  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 --set=VERBOSITY=verbose \
    -v "claims=$task_admin_claims" \
    -v "team_id=$task_team_id" \
    -v "period_month=$task_period_month" \
    -v "idempotency_key=$task_idempotency_key" \
    -U postgres -d postgres >"$task_output_file" 2>&1 <<'SQL'
set statement_timeout = '30s';
set role authenticated;
select set_config('request.jwt.claims', :'claims', false);
select public.v1_validate_workforce_monthly_period(
  jsonb_build_object(
    'team_id', :'team_id',
    'period_month', :'period_month'
  ),
  null,
  :'idempotency_key'::uuid
);
SQL
}

task_writer_a_app="yorks_t06_monthly_writer_a"
task_writer_b_app="yorks_t06_monthly_writer_b"
task_writer_a_output="$task_tmp_dir/writer_a.log"
task_writer_b_output="$task_tmp_dir/writer_b.log"
task_blocker_output="$task_tmp_dir/blocker.log"
task_blocker_app="yorks_t06_monthly_blocker"

docker exec -i -e "PGAPPNAME=$task_blocker_app" "$task_db_container" \
  psql -X -Atq -v ON_ERROR_STOP=1 \
  -v "team_id=$task_team_id" -v "period_month=$task_period_month" \
  -U postgres -d postgres >"$task_blocker_output" 2>&1 <<'SQL' &
begin;
select pg_advisory_xact_lock(
  pg_catalog.hashtextextended(
    'v1_workforce_monthly_period|' || :'team_id' || '|' || :'period_month', 0
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
  echo "Could not establish the local T06 advisory-lock barrier." >&2
  exit 1
fi

task_run_writer "$task_writer_a_app" \
  "59890000-0000-4000-8000-000000000001" "$task_writer_a_output" &
task_writer_a_pid=$!
task_run_writer "$task_writer_b_app" \
  "59890000-0000-4000-8000-000000000002" "$task_writer_b_output" &
task_writer_b_pid=$!

task_waiting_count="0"
for ((task_attempt = 0; task_attempt < 200; task_attempt += 1)); do
  task_waiting_count="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_writer_a_app','$task_writer_b_app') and wait_event_type = 'Lock' and query like '%v1_validate_workforce_monthly_period%'")"
  if [[ "$task_waiting_count" == "2" ]]; then
    break
  fi
  sleep 0.05
done
if [[ "$task_waiting_count" != "2" ]]; then
  echo "The race did not place both T06 writer sessions inside the RPC." >&2
  exit 1
fi

task_db_scalar "select count(*) from (select pg_terminate_backend(pid) from pg_stat_activity where application_name = '$task_blocker_app') terminated" >/dev/null
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
  echo "Expected exactly one T06 winner; writer statuses were $task_writer_a_status and $task_writer_b_status." >&2
  exit 1
fi
if ! rg -q '40001: +V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' "$task_loser_output"; then
  echo "The T06 race loser did not return the stable 40001 conflict." >&2
  sed -n '1,100p' "$task_loser_output" >&2
  exit 1
fi

task_summary="$(task_db_scalar "
  select concat_ws('|',
    (select count(*) from public.v1_workforce_monthly_periods where team_id = '$task_team_id' and period_month = '$task_period_month'),
    (select concat_ws(':',record_version,current_validation_number,current_status) from public.v1_workforce_monthly_periods where team_id = '$task_team_id' and period_month = '$task_period_month'),
    (select count(*) from public.v1_workforce_monthly_validation_runs run join public.v1_workforce_monthly_periods period on period.id = run.period_id where period.team_id = '$task_team_id' and period.period_month = '$task_period_month'),
    (select count(*) from public.v1_workforce_monthly_period_workers worker join public.v1_workforce_monthly_validation_runs run on run.id = worker.validation_run_id join public.v1_workforce_monthly_periods period on period.id = run.period_id where period.team_id = '$task_team_id' and period.period_month = '$task_period_month'),
    (select count(*) from public.v1_workforce_monthly_period_dates date_row join public.v1_workforce_monthly_validation_runs run on run.id = date_row.validation_run_id join public.v1_workforce_monthly_periods period on period.id = run.period_id where period.team_id = '$task_team_id' and period.period_month = '$task_period_month'),
    (select count(*) from public.v1_workforce_monthly_validation_issues issue join public.v1_workforce_monthly_validation_runs run on run.id = issue.validation_run_id join public.v1_workforce_monthly_periods period on period.id = run.period_id where period.team_id = '$task_team_id' and period.period_month = '$task_period_month'),
    (select count(*) from public.v1_audit_events audit where audit.event_type = 'workforce_monthly_period_validated' and audit.idempotency_key in ('59890000-0000-4000-8000-000000000001','59890000-0000-4000-8000-000000000002')),
    (select count(*) from public.v1_idempotency_keys where command_name = 'v1_validate_workforce_monthly_period' and idempotency_key in ('59890000-0000-4000-8000-000000000001','59890000-0000-4000-8000-000000000002') and completed_at is not null),
    (select count(*) from public.v1_workforce_monthly_period_dates date_row left join public.v1_workforce_monthly_validation_runs run on run.id = date_row.validation_run_id where run.id is null)
  )
")"
if [[ "$task_summary" != "1|1:1:draft|1|1|28|28|1|1|0" ]]; then
  echo "T06 concurrency authoritative state mismatch: $task_summary" >&2
  exit 1
fi

echo "T06 race: PASS (two RPC sessions blocked together; one commit, one stable 40001 conflict)"
echo "T06 state: PASS (one version-1 period, one immutable run, 28 dates/issues, one audit/idempotency effect)"
echo "Workforce T06 local monthly-period concurrency harness: PASS"
