begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

-- T13 closes the T07 Admin capability-only shortcut without weakening the
-- accepted T07/T10 dated responsibility and retained-target rules.
insert into public.v1_projects(
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '59e10000-0000-4000-8000-000000000001', 'WF-T13-AUTH',
  'T13 Period Authority Project', 'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_project_scopes(
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values (
  '59e20000-0000-4000-8000-000000000001',
  '59e10000-0000-4000-8000-000000000001',
  'common', 'common', 'Common / All Buildings', true, true
);

insert into public.v1_workforce_teams(
  id, team_code, team_name, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59e30000-0000-4000-8000-000000000001',
  'WF-T13-AUTH', 'T13 Period Authority Team',
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_workers(
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59e40000-0000-4000-8000-000000000001', 'T13-AUTH-001',
  'T13 Authority Worker', 'Technician', 'Yorks AC & Ref.',
  'yorks_employee', '2026-01-01', 'active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_internal_locations(
  id, location_code, location_name, department, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59e25000-0000-4000-8000-000000000001', 'WF-T13-INTERNAL',
  'T13 Internal Workshop', 'Operations / CC-T13', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

set constraints all deferred;
insert into public.v1_workforce_monthly_periods(
  id, team_id, period_month, current_validation_run_id,
  current_validation_number, current_status, record_version,
  created_by_auth_user_id, updated_by_auth_user_id
) values
(
  '59e60000-0000-4000-8000-000000000001',
  '59e30000-0000-4000-8000-000000000001', '2026-07-01',
  '59e70000-0000-4000-8000-000000000001', 1,
  'ready_for_review', 1,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59e60000-0000-4000-8000-000000000002',
  '59e30000-0000-4000-8000-000000000001', '2026-08-01',
  '59e70000-0000-4000-8000-000000000002', 1,
  'ready_for_review', 1,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_monthly_validation_runs(
  id, period_id, validation_number, validation_status,
  source_fingerprint, worker_count, date_count, authority_snapshot,
  validated_by_auth_user_id, validated_by_exact_role, idempotency_key
) values
(
  '59e70000-0000-4000-8000-000000000001',
  '59e60000-0000-4000-8000-000000000001', 1, 'ready_for_review',
  repeat('a', 64), 1, 1, '{"fixture":"t13-period-authority"}',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '59ec0000-0000-4000-8000-000000000001'
),
(
  '59e70000-0000-4000-8000-000000000002',
  '59e60000-0000-4000-8000-000000000002', 1, 'ready_for_review',
  repeat('b', 64), 0, 0, '{"fixture":"t13-empty-period-authority"}',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '59ec0000-0000-4000-8000-000000000002'
);

insert into public.v1_workforce_monthly_period_dates(
  id, validation_run_id, worker_id, work_date, is_future, is_required,
  day_type, daily_status, worker_snapshot, assignment_snapshot,
  schedule_snapshot, attendance_snapshot, allocation_snapshot,
  scheduled_minutes, regular_minutes, overtime_minutes, allocation_minutes
) values (
  '59e80000-0000-4000-8000-000000000001',
  '59e70000-0000-4000-8000-000000000001',
  '59e40000-0000-4000-8000-000000000001', '2026-07-15',
  false, true, 'regular_working_day', 'complete',
  jsonb_build_object(
    'worker_id', '59e40000-0000-4000-8000-000000000001',
    'worker_number', 'T13-AUTH-001', 'worker_name', 'T13 Authority Worker'
  ),
  jsonb_build_object(
    'team_id', '59e30000-0000-4000-8000-000000000001',
    'project_id', '59e10000-0000-4000-8000-000000000001',
    'project_scope_id', '59e20000-0000-4000-8000-000000000001',
    'internal_location_id', null,
    'supervisor_auth_user_id',
      '10000000-0000-4000-8000-000000000004',
    'valid_from', '2026-01-01', 'valid_to', '2027-12-31'
  ),
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":480}',
  '{"attendance_status":"present","regular_minutes":480,"overtime_minutes":0}',
  jsonb_build_object(
    'allocation_state', 'active',
    'targets', jsonb_build_array(
      jsonb_build_object(
        'target_kind', 'project_work',
        'project_id', '59e10000-0000-4000-8000-000000000001',
        'project_scope_id', '59e20000-0000-4000-8000-000000000001'
      ),
      jsonb_build_object(
        'target_kind', 'internal_work',
        'internal_location_id', '59e25000-0000-4000-8000-000000000001'
      )
    )
  ),
  480, 480, 0, 480
);
set constraints all immediate;

-- Project Manager and SME receive the same exact organization capability;
-- responsibility, including every active allocation target, remains authority.
insert into public.v1_permission_assignments(
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
(
  '59ea0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000010', 'workforce.view',
  'grant', 'organization', 'permission_management', '2026-01-01',
  'T13 Project Manager view capability',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59ea0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000009', 'workforce.view',
  'grant', 'organization', 'permission_management', '2026-01-01',
  'T13 SME view capability',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, project_id, project_scope_id,
  valid_from, valid_to, reason, assigned_by_auth_user_id,
  assigned_by_exact_role, updated_by_auth_user_id
) values
(
  '59eb0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000010', 'project_scope',
  '59e10000-0000-4000-8000-000000000001',
  '59e20000-0000-4000-8000-000000000001',
  '2026-07-01', '2026-08-31', 'T13 Project Manager project scope',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59eb0000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000009', 'project_scope',
  '59e10000-0000-4000-8000-000000000001',
  '59e20000-0000-4000-8000-000000000001',
  '2026-07-01', '2026-08-31', 'T13 SME project scope',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, internal_location_id,
  valid_from, valid_to, reason, assigned_by_auth_user_id,
  assigned_by_exact_role, updated_by_auth_user_id
) values
(
  '59eb0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000010', 'internal_location',
  '59e25000-0000-4000-8000-000000000001',
  '2026-07-01', '2026-08-31', 'T13 Project Manager internal target',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59eb0000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000009', 'internal_location',
  '59e25000-0000-4000-8000-000000000001',
  '2026-07-01', '2026-08-31', 'T13 SME internal target',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59eb0000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000004', 'internal_location',
  '59e25000-0000-4000-8000-000000000001',
  '2026-07-01', '2026-08-31', 'T13 unused Admin target fixture',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

-- The Admin authority under test is organization responsibility, never role.
-- Arbitrary valid retained fixtures may already contain non-overlapping Admin
-- organization windows. Re-home them temporarily so this transaction owns the
-- exact mutable window under test; rollback restores their retained evidence.
with existing as (
  select responsibility.id,
    row_number() over(order by responsibility.id)::integer as ordinal
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.auth_user_id=
      '10000000-0000-4000-8000-000000000004'
    and responsibility.scope_kind='organization'
)
update public.v1_workforce_responsibility_assignments responsibility
set valid_from=date '1700-01-01'+(existing.ordinal*2),
  valid_to=date '1700-01-01'+(existing.ordinal*2),
  record_version=responsibility.record_version+1,
  updated_by_auth_user_id='10000000-0000-4000-8000-000000000004',
  updated_at=clock_timestamp()
from existing
where responsibility.id=existing.id;

insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59eb0000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000004', 'organization',
  '2026-07-01', '2026-08-31', 'T13 Admin complete organization period',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true);
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 't|t',
  'T07 and T10 accept Admin only with full-month organization responsibility');

update public.v1_workforce_responsibility_assignments
set valid_from = '2026-09-01', valid_to = '2027-12-31'
where id = '59eb0000-0000-4000-8000-000000000006';
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 'f|f',
  'Admin capability without an effective responsibility is denied by T07 and T10');

update public.v1_workforce_responsibility_assignments
set valid_from = '2025-01-01', valid_to = '2026-06-30'
where id = '59eb0000-0000-4000-8000-000000000006';
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 'f|f',
  'Expired Admin responsibility is denied by T07 and T10');

update public.v1_workforce_responsibility_assignments
set valid_from = '2026-07-02', valid_to = '2026-07-31'
where id = '59eb0000-0000-4000-8000-000000000006';
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 'f|f',
  'Partial-month Admin organization responsibility is denied by T07 and T10');

update public.v1_workforce_responsibility_assignments
set valid_from = '2026-07-01', valid_to = '2026-08-31'
where id = '59eb0000-0000-4000-8000-000000000006';

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true);
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 't|t',
  'Project Manager exact assignment and active target scope is accepted equally');

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true);
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 't|t',
  'Senior Mechanical Engineer receives the same exact scoped authority');

update public.v1_workforce_responsibility_assignments
set valid_to = '2026-07-14'
where id = '59eb0000-0000-4000-8000-000000000004';
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 'f|f',
  'Both helpers deny SME when one active internal allocation target is uncovered');
update public.v1_workforce_responsibility_assignments
set valid_to = '2026-08-31'
where id = '59eb0000-0000-4000-8000-000000000004';

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true);
update public.v1_workforce_responsibility_assignments
set valid_to = '2026-07-14'
where id = '59eb0000-0000-4000-8000-000000000001';
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000001', true)
  ), 'f|f',
  'Both helpers deny Project Manager when retained project scope is uncovered');
update public.v1_workforce_responsibility_assignments
set valid_to = '2026-08-31'
where id = '59eb0000-0000-4000-8000-000000000001';

-- No dates means there is no worker/target context to inspect. Accepted T06
-- semantics remain organization or exact team responsibility for the month.
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true)
  ), 'f|f',
  'Project-target responsibility alone does not authorize an empty period');

insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, team_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
(
  '59eb0000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000010', 'team',
  '59e30000-0000-4000-8000-000000000001',
  '2026-08-01', '2026-08-31', 'T13 PM empty-period team authority',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
),
(
  '59eb0000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000009', 'team',
  '59e30000-0000-4000-8000-000000000001',
  '2026-08-01', '2026-08-31', 'T13 SME empty-period team authority',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true)
  ), 't|t',
  'Project Manager exact team responsibility authorizes an empty period');

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true);
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true)
  ), 't|t',
  'SME exact team responsibility preserves the same empty-period semantics');

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true);
select is(concat_ws('|',
    public.v1_workforce_t07_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true),
    public.v1_workforce_t10_period_authorized(
      'workforce.view', '59e60000-0000-4000-8000-000000000002', true)
  ), 't|t',
  'Admin complete organization responsibility preserves empty-period access');

select * from finish();
rollback;
