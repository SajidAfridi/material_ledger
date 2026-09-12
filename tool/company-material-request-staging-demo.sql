-- Yorks Company Material Request T01 staging demonstration policy.
--
-- This is an operator fixture, not a migration or a production authorization
-- matrix. It can run only against the dedicated technical-persona staging
-- project. It makes the accepted T01 create-and-submit path demonstrable while
-- preserving an independent approver and leaving later approval, fulfilment,
-- dispatch, receipt, issue and return work out of scope.

do $fixture$
declare
  v_expected_ids uuid[] := array[
    '10000000-0000-4000-8000-000000000001'::uuid,
    '10000000-0000-4000-8000-000000000002'::uuid,
    '10000000-0000-4000-8000-000000000003'::uuid,
    '10000000-0000-4000-8000-000000000004'::uuid,
    '10000000-0000-4000-8000-000000000009'::uuid,
    '10000000-0000-4000-8000-000000000010'::uuid,
    '10000000-0000-4000-8000-000000000013'::uuid
  ];
begin
  if (select count(*) from auth.users) <> 7
    or exists (
      select 1
      from auth.users user_row
      where user_row.id <> all(v_expected_ids)
        or user_row.email not like '%@yorks.local.test'
    ) then
    raise exception 'COMPANY_MATERIAL_REQUEST_DEMO_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
insert into public.v1_company_material_request_categories (
  id, category_code, display_name, is_active
) values (
  '5dc10000-0000-4000-8000-000000000001',
  'staging_demo_ppe',
  'STAGING DEMO — Safety & PPE',
  true
)
on conflict (category_code) do update
set display_name = excluded.display_name,
    is_active = true,
    updated_at = clock_timestamp();

insert into public.v1_company_material_request_units (
  id, unit_code, display_name, is_active
) values (
  '5dc11000-0000-4000-8000-000000000001',
  'DEMO-WORKSHOP',
  'STAGING DEMO — Workshop Operations',
  true
)
on conflict (unit_code) do update
set display_name = excluded.display_name,
    is_active = true,
    updated_at = clock_timestamp();

-- Requesting authority is explicitly granted to named staging personas. The
-- beneficiary and receiver catalogue deliberately excludes the approvers, so
-- the standard selection has an independent route instead of a hidden
-- self-approval path.
insert into public.v1_company_material_request_authorizations (
  auth_user_id, category_id, responsible_unit_id, authority, effective_from
) values
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000004', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000009', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'requester', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'beneficiary', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000001', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000002', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000003', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'receiver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000004', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'approver', date '2026-01-01'),
  ('10000000-0000-4000-8000-000000000009', '5dc10000-0000-4000-8000-000000000001', '5dc11000-0000-4000-8000-000000000001', 'approver', date '2026-01-01')
on conflict (
  auth_user_id, category_id, responsible_unit_id, authority, effective_from
) do update
set effective_to = null,
    updated_at = clock_timestamp();

insert into public.v1_company_material_request_approval_routes (
  id,
  category_id,
  responsible_unit_id,
  primary_approver_auth_user_id,
  alternate_approver_auth_user_id,
  policy_version,
  effective_from
) values (
  '5dc12000-0000-4000-8000-000000000001',
  '5dc10000-0000-4000-8000-000000000001',
  '5dc11000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000009',
  'STAGING-DEMO-T01-20260913',
  date '2026-01-01'
)
on conflict (category_id, responsible_unit_id, effective_from) do update
set primary_approver_auth_user_id = excluded.primary_approver_auth_user_id,
    alternate_approver_auth_user_id = excluded.alternate_approver_auth_user_id,
    policy_version = excluded.policy_version,
    effective_to = null,
    updated_at = clock_timestamp();

end;
$fixture$;
