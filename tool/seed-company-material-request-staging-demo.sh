#!/usr/bin/env bash
set -euo pipefail

# Applies the guarded Company Material Request T01 demonstration policy to the
# dedicated technical-persona staging project. It is intentionally not a
# migration and refuses production or a non-fixture target.

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
  echo 'Refusing an unknown target; the dedicated technical staging ref is required.' >&2
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
if [[ "${R35_STAGING_COMPANY_MATERIAL_REQUEST_DEMO_CONFIRM:-}" != "$expected_staging_ref" ]]; then
  echo 'Set R35_STAGING_COMPANY_MATERIAL_REQUEST_DEMO_CONFIRM to the staging ref.' >&2
  exit 64
fi

npx supabase link \
  --project-ref "$R35_STAGING_PROJECT_REF" \
  --password "$R35_STAGING_DB_PASSWORD"
npx supabase db query --linked --file tool/company-material-request-staging-demo.sql
npx supabase db query --linked \
  "select
    (select count(*) from public.v1_company_material_request_categories where category_code = 'staging_demo_ppe' and is_active) as active_demo_categories,
    (select count(*) from public.v1_company_material_request_units where unit_code = 'DEMO-WORKSHOP' and is_active) as active_demo_units,
    (select count(*) from public.v1_company_material_request_authorizations authorization_record join public.v1_company_material_request_categories category on category.id = authorization_record.category_id where category.category_code = 'staging_demo_ppe' and authorization_record.authority = 'requester' and authorization_record.effective_from <= current_date and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)) as effective_requesters,
    (select count(*) from public.v1_company_material_request_authorizations authorization_record join public.v1_company_material_request_categories category on category.id = authorization_record.category_id where category.category_code = 'staging_demo_ppe' and authorization_record.authority = 'beneficiary' and authorization_record.effective_from <= current_date and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)) as effective_beneficiaries,
    (select count(*) from public.v1_company_material_request_authorizations authorization_record join public.v1_company_material_request_categories category on category.id = authorization_record.category_id where category.category_code = 'staging_demo_ppe' and authorization_record.authority = 'receiver' and authorization_record.effective_from <= current_date and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)) as effective_receivers,
    (select count(*) from public.v1_company_material_request_authorizations authorization_record join public.v1_company_material_request_categories category on category.id = authorization_record.category_id where category.category_code = 'staging_demo_ppe' and authorization_record.authority = 'approver' and authorization_record.effective_from <= current_date and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)) as effective_approvers,
    (select count(*) from public.v1_company_material_request_approval_routes route_record join public.v1_company_material_request_categories category on category.id = route_record.category_id where category.category_code = 'staging_demo_ppe' and route_record.effective_from <= current_date and (route_record.effective_to is null or route_record.effective_to >= current_date)) as effective_routes;"
