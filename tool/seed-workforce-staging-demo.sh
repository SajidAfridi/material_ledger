#!/usr/bin/env bash
set -euo pipefail

config_file="${R35_STAGING_CONFIG_FILE:-.r35.staging.env}"
expected_staging_ref='iqltcyimlqtcwyzlemwx'
production_ref='czykuksmlwswjsgotrpo'

if [[ ! -f "$config_file" ]]; then
  echo "Missing staging configuration: $config_file" >&2
  exit 64
fi

# shellcheck disable=SC1090
source "$config_file"

if [[ "${R35_ENVIRONMENT:-}" != 'staging' ]]; then
  echo 'R35_ENVIRONMENT=staging is required.' >&2
  exit 64
fi
if [[ "${R35_STAGING_PROJECT_REF:-}" != "$expected_staging_ref" ]]; then
  echo 'Refusing an unknown target; the dedicated Workforce staging ref is required.' >&2
  exit 64
fi
if [[ "${R35_STAGING_PROJECT_REF:-}" == "$production_ref" ]]; then
  echo 'Refusing the production project.' >&2
  exit 64
fi
if [[ -z "${R35_STAGING_DB_PASSWORD:-}" ]]; then
  echo 'R35_STAGING_DB_PASSWORD is required.' >&2
  exit 64
fi

npx supabase link \
  --project-ref "$R35_STAGING_PROJECT_REF" \
  --password "$R35_STAGING_DB_PASSWORD"
npx supabase db query --linked --file tool/workforce-staging-demo.sql
npx supabase db query --linked \
  "select (select count(*) from public.v1_projects where project_ref like 'DEMO-%') as demo_projects, (select count(*) from public.v1_workforce_teams where team_code like 'DEMO-%') as demo_teams, (select count(*) from public.v1_workforce_workers where worker_number like 'DEMO-%') as demo_workers, (select count(*) from public.v1_workforce_attendance_days where worker_number_snapshot like 'DEMO-%') as demo_attendance_days, (select count(*) from public.v1_workforce_timesheet_allocation_sets allocation_set join public.v1_workforce_attendance_days attendance on attendance.id=allocation_set.attendance_day_id where attendance.worker_number_snapshot like 'DEMO-%') as demo_allocation_sets, (select count(*) from public.v1_workforce_monthly_periods period join public.v1_workforce_teams team on team.id=period.team_id where team.team_code like 'DEMO-%') as demo_monthly_periods;"
