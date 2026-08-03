#!/usr/bin/env bash
set -euo pipefail

# Controlled deployment for a fresh, dedicated Yorks R35 staging project.
# This script deliberately refuses the historic shared project reference and
# never has a fallback target. It requires an operator-owned ignored config
# file; credentials are not written to this repository or command output.

usage() {
  cat <<'USAGE'
Usage: R35_STAGING_CONFIG_FILE=.r35.staging.env ./tool/r35-staging.sh <preflight|deploy|verify>

preflight  Link only to the explicit staging target and show its migration state.
deploy     Apply tracked migrations, deploy finalize-document-upload, then run verify.
verify     Confirm the R35 header-hierarchy RPC and Edge Function are present.
USAGE
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 64
fi

config_file="${R35_STAGING_CONFIG_FILE:-.r35.staging.env}"
if [[ ! -f "$config_file" ]]; then
  echo "Missing staging configuration: $config_file" >&2
  echo "Copy tool/r35.staging.env.example and fill it for the dedicated staging project." >&2
  exit 64
fi

# shellcheck disable=SC1090
source "$config_file"

staging_ref="${R35_STAGING_PROJECT_REF:-}"
staging_password="${R35_STAGING_DB_PASSWORD:-}"
staging_environment="${R35_ENVIRONMENT:-}"
deploy_confirmation="${R35_STAGING_DEPLOY_CONFIRM:-}"
shared_ref='czykuksmlwswjsgotrpo'

if [[ "$staging_environment" != 'staging' ]]; then
  echo "R35_ENVIRONMENT=staging is required for this command." >&2
  exit 64
fi
if [[ -z "$staging_ref" || -z "$staging_password" ]]; then
  echo "R35_STAGING_PROJECT_REF and R35_STAGING_DB_PASSWORD are required." >&2
  exit 64
fi
if [[ "$staging_ref" == "$shared_ref" ]]; then
  echo "Refusing the historic shared project. Use a dedicated staging project." >&2
  exit 64
fi
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_URL and SUPABASE_ANON_KEY must be explicit in staging config." >&2
  exit 64
fi

link_staging() {
  npx supabase link --project-ref "$staging_ref" --password "$staging_password"
}

verify_staging() {
  npx supabase migration list --linked
  npx supabase db query --linked \
    "select position('header_row_numbers' in pg_get_functiondef('public.v1_import_boq_worksheet(jsonb,uuid)'::regprocedure)) > 0 as header_hierarchy_supported;"
  npx supabase functions list --project-ref "$staging_ref"
}

preflight_staging() {
  link_staging
  npx supabase migration list --linked
  # This prints the exact tracked migrations that the dedicated target would
  # receive without mutating it. An operator must review this before deploy.
  npx supabase db push --linked --dry-run
}

require_deploy_confirmation() {
  if [[ "$deploy_confirmation" != "$staging_ref" ]]; then
    echo "Set R35_STAGING_DEPLOY_CONFIRM to the dedicated staging project ref before deploy." >&2
    exit 64
  fi
}

case "$1" in
  preflight)
    preflight_staging
    ;;
  deploy)
    require_deploy_confirmation
    preflight_staging
    # A dedicated staging project begins with no application migrations. Do
    # not use this against an existing or shared environment with divergent
    # migration history.
    npx supabase db push --linked
    npx supabase functions deploy finalize-document-upload --project-ref "$staging_ref"
    verify_staging
    ;;
  verify)
    link_staging
    verify_staging
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac
