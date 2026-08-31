#!/usr/bin/env bash

set -euo pipefail

task_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
task_workspace_root="$(cd "$task_script_dir/.." && pwd)"
task_tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/yorks-t10-concurrent-read.XXXXXX")"
trap 'rm -R -- "$task_tmp_dir"' EXIT INT TERM

cd "$task_workspace_root"

task_status_json="$(npx --yes supabase status --output json 2>/dev/null)"
task_db_url="$(printf '%s' "$task_status_json" | jq -er '.DB_URL')"
case "$task_db_url" in
  postgresql://postgres:*@127.0.0.1:*/* | postgresql://postgres:*@localhost:*/*) ;;
  *)
    echo "Refusing to run against a non-local database: $task_db_url" >&2
    exit 1
    ;;
esac

task_db_container="$(
  docker ps \
    --filter "label=com.supabase.cli.workdir=$task_workspace_root" \
    --filter "name=supabase_db_" \
    --format '{{.Names}}'
)"
if [[ -z "$task_db_container" || "$(printf '%s\n' "$task_db_container" | wc -l | tr -d ' ')" != "1" ]]; then
  echo "Expected exactly one repository-local Supabase database container." >&2
  exit 1
fi

task_admin_claims='{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}'
task_db_scalar() {
  docker exec -i "$task_db_container" psql -X -Atq -U postgres -d postgres \
    -c "$1"
}

task_fixture_id="59de0000-0000-4000-8000-000000000010"
task_cleanup() {
  task_db_scalar "update public.v1_workforce_responsibility_assignments
    set valid_from='1900-01-01', valid_to='1900-01-01',
      record_version=record_version+1,
      updated_by_auth_user_id='10000000-0000-4000-8000-000000000004',
      updated_at=clock_timestamp()
    where id='$task_fixture_id'" \
    >/dev/null 2>&1 || true
  rm -R -- "$task_tmp_dir"
}
trap task_cleanup EXIT INT TERM

task_db_scalar "insert into public.v1_workforce_responsibility_assignments(
    id,auth_user_id,scope_kind,valid_from,valid_to,reason,
    assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
  values('$task_fixture_id','10000000-0000-4000-8000-000000000004',
    'organization','2025-04-01','2099-12-31',
    'Repository-local T10 concurrent-read fixture',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004')
  on conflict(id) do update set valid_from='2025-04-01',
    valid_to='2099-12-31',
    record_version=public.v1_workforce_responsibility_assignments.record_version+1,
    updated_by_auth_user_id='10000000-0000-4000-8000-000000000004',
    updated_at=clock_timestamp()" >/dev/null

task_effect_counts() {
  task_db_scalar "select concat_ws('|',
    (select count(*) from public.v1_audit_events),
    (select count(*) from public.v1_notifications),
    (select count(*) from public.v1_workforce_notification_deliveries),
    (select count(*) from public.v1_workforce_monthly_transitions),
    (select count(*) from public.v1_workforce_report_artifacts))"
}

task_run_reader() {
  local task_app_name="$1" task_output="$2"
  docker exec -i -e "PGAPPNAME=$task_app_name" "$task_db_container" \
    psql -X -Atq -v ON_ERROR_STOP=1 \
    -v "claims=$task_admin_claims" -U postgres -d postgres \
    >"$task_output" 2>&1 <<'SQL'
set statement_timeout='30s';
set role authenticated;
select set_config('request.jwt.claims', :'claims', false);
select (public.v1_get_workforce_overview(
  '{"overview_kind":"admin"}'::jsonb
) - 'generated_at')::text
from (select pg_sleep(1)) synchronized_start;
SQL
}

task_before="$(task_effect_counts)"
task_reader_a_app="yorks_t10_reader_a"
task_reader_b_app="yorks_t10_reader_b"
task_reader_a_output="$task_tmp_dir/reader-a.log"
task_reader_b_output="$task_tmp_dir/reader-b.log"

task_run_reader "$task_reader_a_app" "$task_reader_a_output" &
task_reader_a_pid=$!
task_run_reader "$task_reader_b_app" "$task_reader_b_output" &
task_reader_b_pid=$!

task_seen=0
for ((task_attempt=0; task_attempt<100; task_attempt+=1)); do
  task_seen="$(task_db_scalar "select count(*) from pg_stat_activity where application_name in ('$task_reader_a_app','$task_reader_b_app') and state='active' and query like '%v1_get_workforce_overview%'")"
  [[ "$task_seen" == "2" ]] && break
  sleep 0.02
done
if [[ "$task_seen" != "2" ]]; then
  echo "Both independent T10 read sessions were not observed concurrently." >&2
  exit 1
fi

wait "$task_reader_a_pid"
wait "$task_reader_b_pid"

task_response_a="$(tail -n 1 "$task_reader_a_output" | jq -Sc .)"
task_response_b="$(tail -n 1 "$task_reader_b_output" | jq -Sc .)"
if [[ "$task_response_a" != "$task_response_b" ]]; then
  echo "Concurrent T10 reads returned different authoritative projections." >&2
  exit 1
fi

task_after="$(task_effect_counts)"
if [[ "$task_before" != "$task_after" ]]; then
  echo "T10 read created a forbidden side effect: $task_before -> $task_after" >&2
  exit 1
fi

echo "T10 concurrent reads: PASS (two independent active RPC sessions)"
echo "T10 stable projection: PASS (responses match excluding generated_at)"
echo "T10 read-only boundary: PASS (audit/notification/transition/report counts unchanged: $task_after)"
