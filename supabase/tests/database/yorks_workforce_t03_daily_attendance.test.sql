begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  (select relrowsecurity
   from pg_catalog.pg_class
   where oid = 'public.v1_workforce_attendance_days'::regclass)
  and not exists (
    select 1
    from (values ('select'), ('insert'), ('update'), ('delete'))
      as privilege(privilege_name)
    where has_table_privilege(
      'authenticated', 'public.v1_workforce_attendance_days',
      privilege.privilege_name
    )
  ),
  'The T03 attendance relation uses RLS and exposes no authenticated CRUD'
);

select ok(
  has_table_privilege(
    'service_role', 'public.v1_workforce_attendance_days', 'select'
  ) and has_table_privilege(
    'service_role', 'public.v1_workforce_attendance_days', 'insert'
  ) and has_table_privilege(
    'service_role', 'public.v1_workforce_attendance_days', 'update'
  ) and has_table_privilege(
    'service_role', 'public.v1_workforce_attendance_days', 'delete'
  ),
  'Only the service role retains direct attendance-table administration'
);

select is(
  (select count(*) from public.v1_capability_catalog catalog
   where public.v1_workforce_is_capability_key(catalog.capability_key)
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable),
  9::bigint,
  'Exactly nine Workforce capabilities are operational in the final T09 chain'
);

select ok(
  (select bool_and(
    catalog.status = 'planned'
    and catalog.authorization_mode = 'shadow'
    and not catalog.is_assignable
  ) from public.v1_capability_catalog catalog
  where public.v1_workforce_is_capability_key(catalog.capability_key)
    and catalog.capability_key not in (
      'workforce.view', 'workforce.attendance.maintain',
      'workforce.timesheets.maintain', 'workforce.timesheets.review',
      'workforce.timesheets.correct_during_review',
      'workforce.timesheets.verify', 'workforce.timesheets.final_approve',
      'workforce.periods.reopen', 'workforce.reports.export'
    )),
  'The other three Workforce capabilities remain planned and nonassignable'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_attendance(date,uuid)', 'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_save_workforce_attendance_day(jsonb,bigint,uuid)', 'execute'
  ) and not has_function_privilege(
    'anon', 'public.v1_get_workforce_attendance(date,uuid)', 'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_attendance_authority_context(text,uuid,date,uuid,uuid,uuid,uuid)',
    'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_guard_future_attendance()', 'execute'
  ),
  'Only the two protected T03 RPCs are exposed; future-date guard is internal'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values
  (
    '59010000-0000-4000-8000-000000000001', 'WF-T03-A',
    'Workforce T03 authorized project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '59010000-0000-4000-8000-000000000002', 'WF-T03-B',
    'Workforce T03 outside project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable
) values
  (
    '59020000-0000-4000-8000-000000000001',
    '59010000-0000-4000-8000-000000000001',
    'common', 'common', 'Common / All Buildings', true
  ),
  (
    '59020000-0000-4000-8000-000000000002',
    '59010000-0000-4000-8000-000000000002',
    'common', 'common', 'Common / All Buildings', true
  );

-- Technical membership in project B is deliberately insufficient because the
-- maintainer receives permission/responsibility only for project A.
insert into public.v1_project_members (
  id, project_id, member_auth_user_id, project_role, reason,
  assigned_by_auth_user_id, assigned_by_role
) values (
  '59021000-0000-4000-8000-000000000001',
  '59010000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001', 'project_engineer',
  'Prove technical membership is not Workforce authority',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59030000-0000-4000-8000-000000000001', 'WF-T03-TEAM-A',
    'T03 Authorized Team', '59010000-0000-4000-8000-000000000001',
    '59020000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59030000-0000-4000-8000-000000000002', 'WF-T03-TEAM-B',
    'T03 Outside Team', '59010000-0000-4000-8000-000000000002',
    '59020000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, leaving_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59040000-0000-4000-8000-000000000001', 'WF-T03-WORKER-A',
    'T03 Authorized Worker', 'Ductman', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', null, 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59040000-0000-4000-8000-000000000002', 'WF-T03-WORKER-B',
    'T03 Outside Worker', 'Electrician', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', null, 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59040000-0000-4000-8000-000000000003', 'WF-T03-INACTIVE',
    'T03 Inactive Worker', 'Helper', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', null, 'inactive',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59040000-0000-4000-8000-000000000004', 'WF-T03-BOUNDED',
    'T03 Bounded Worker', 'Helper', 'Yorks AC & Ref.',
    'yorks_employee', '2026-08-01', '2026-08-31', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59050000-0000-4000-8000-000000000001',
    '59040000-0000-4000-8000-000000000001', 'primary',
    '59030000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59010000-0000-4000-8000-000000000001',
    '59020000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 authoritative assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59050000-0000-4000-8000-000000000002',
    '59040000-0000-4000-8000-000000000002', 'primary',
    '59030000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '59010000-0000-4000-8000-000000000002',
    '59020000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', 'T03 outside assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59050000-0000-4000-8000-000000000003',
    '59040000-0000-4000-8000-000000000003', 'primary',
    '59030000-0000-4000-8000-000000000001', null,
    '59010000-0000-4000-8000-000000000001',
    '59020000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 inactive worker assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59050000-0000-4000-8000-000000000004',
    '59040000-0000-4000-8000-000000000004', 'primary',
    '59030000-0000-4000-8000-000000000001', null,
    '59010000-0000-4000-8000-000000000001',
    '59020000-0000-4000-8000-000000000001',
    '2026-08-01', '2026-08-31', 'T03 bounded worker assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59050000-0000-4000-8000-000000000005',
    '59040000-0000-4000-8000-000000000001', 'temporary',
    '59030000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000004',
    '59010000-0000-4000-8000-000000000001',
    '59020000-0000-4000-8000-000000000001',
    '2026-08-29', '2026-08-29',
    'T03 temporary assignment must take precedence for this work date',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59060000-0000-4000-8000-000000000001', 'WF-T03-CAL',
  'T03 Dubai Calendar', 'Asia/Dubai', 480, 60,
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select
  '59060000-0000-4000-8000-000000000001'::uuid,
  weekday,
  case when weekday = 7 then 'weekly_off' else 'regular_working_day' end,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_shift_templates (
  id, shift_code, shift_name, shift_kind, start_time, end_time,
  scheduled_minutes, break_minutes, work_date_basis, valid_from, valid_to,
  is_active, created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59070000-0000-4000-8000-000000000001', 'WF-T03-NIGHT',
  'T03 Night Shift', 'night', '20:00', '04:00', 480, 60,
  'shift_start_date', '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, shift_template_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59080000-0000-4000-8000-000000000001',
    '59030000-0000-4000-8000-000000000001',
    '59060000-0000-4000-8000-000000000001',
    '59070000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 team A schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59080000-0000-4000-8000-000000000002',
    '59030000-0000-4000-8000-000000000002',
    '59060000-0000-4000-8000-000000000001',
    '59070000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 team B schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendar_dates (
  id, calendar_id, calendar_date, override_kind, day_type, exception_name,
  scheduled_minutes, break_minutes, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59090000-0000-4000-8000-000000000001',
  '59060000-0000-4000-8000-000000000001', '2026-08-29',
  'public_holiday', 'public_holiday', 'T03 retained public holiday',
  0, 0, true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

-- Project Engineer receives both enforced capabilities only in project A and
-- a dated project-A responsibility. Site Engineer receives capability without
-- responsibility; Procurement receives responsibility without capability.
insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '59100000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', 'workforce.view',
    'grant', 'project', 'permission_management', '2026-01-01',
    'T03 project-A view grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59100000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'workforce.attendance.maintain', 'grant', 'project',
    'permission_management', '2026-01-01', 'T03 project-A maintain grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59100000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002', 'workforce.view',
    'grant', 'organization', 'permission_management', '2026-01-01',
    'T03 capability without responsibility',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59100000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002',
    'workforce.attendance.maintain', 'grant', 'organization',
    'permission_management', '2026-01-01',
    'T03 capability without responsibility',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59100000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000009', 'workforce.view',
    'grant', 'organization', 'permission_management', '2026-01-01',
    'T03 expired view grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59100000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000009',
    'workforce.attendance.maintain', 'grant', 'organization',
    'permission_management', '2026-01-01', 'T03 expired maintain grant',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_permission_assignment_projects (
  assignment_id, project_id
) values
  (
    '59100000-0000-4000-8000-000000000001',
    '59010000-0000-4000-8000-000000000001'
  ),
  (
    '59100000-0000-4000-8000-000000000002',
    '59010000-0000-4000-8000-000000000001'
  );

update public.v1_permission_assignments
set effective_until = '2026-08-01'
where id in (
  '59100000-0000-4000-8000-000000000005',
  '59100000-0000-4000-8000-000000000006'
);

insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, project_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59110000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', 'project',
    '59010000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 project-A responsibility',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59110000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000003', 'project',
    '59010000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T03 responsibility without capability',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59110000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000009', 'organization',
    null, '2026-01-01', '2027-12-31', 'T03 expired actor responsibility',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $sql$select * from public.v1_workforce_attendance_days$sql$,
  '42501', 'permission denied for table v1_workforce_attendance_days',
  'Authenticated callers cannot read the private attendance table'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"Explicit holiday work","unexpected":true}'::jsonb,
    null, '59120000-0000-4000-8000-000000000090'
  )$sql$,
  '22023',
  'V1_UNKNOWN_SAVE_WORKFORCE_ATTENDANCE_DAY_PAYLOAD_FIELDS: unexpected',
  'Unknown client payload keys fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":0,"overtime_minutes":0,"reason":"Invalid present"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000091'
  )$sql$,
  '22023', 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID',
  'Present requires positive total minutes'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"absent","regular_minutes":1,"overtime_minutes":0,"reason":"Invalid absence"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000092'
  )$sql$,
  '22023', 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID',
  'Absent and leave-like statuses require zero minutes'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":1000,"overtime_minutes":500,"reason":"Too many minutes"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000093'
  )$sql$,
  '22023', 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID',
  'A daily attendance total cannot exceed 1440 integer minutes'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":1.5,"overtime_minutes":0,"reason":"Fractional minutes"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000094'
  )$sql$,
  '22023', 'V1_WORKFORCE_ATTENDANCE_INPUT_INVALID',
  'Attendance minutes must be integers'
);

select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"Explicit holiday work"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000001'
  )$sql$,
  'Admin can record explicit present work on a retained public holiday'
);

select is(
  (public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"Explicit holiday work"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000001'
  ) ->> 'record_version')::bigint,
  1::bigint,
  'An identical retry returns the original committed result'
);

reset role;
select is(
  (select count(*) from public.v1_workforce_attendance_days day
   where day.worker_id = '59040000-0000-4000-8000-000000000001'
     and day.work_date = '2026-08-29'),
  1::bigint,
  'Exactly one daily row exists per worker and work date'
);

select is(
  (select count(*) from public.v1_audit_events event
   where event.event_type = 'workforce_attendance_day_created'
     and event.idempotency_key =
       '59120000-0000-4000-8000-000000000001'),
  1::bigint,
  'An identical retry creates one attendance audit effect'
);

set local role authenticated;
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"present","regular_minutes":480,"overtime_minutes":61,"reason":"Different payload"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000001'
  )$sql$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same idempotency key rejects a different payload'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"absent","regular_minutes":0,"overtime_minutes":0,"reason":"Competing create"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000002'
  )$sql$,
  '40001', 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT',
  'A later null-version create attempt cannot replace the authoritative row'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"absent","regular_minutes":0,"overtime_minutes":0,"reason":"Stale correction"}'::jsonb,
    99, '59120000-0000-4000-8000-000000000003'
  )$sql$,
  '40001', 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT',
  'A stale attendance correction cannot overwrite the current row'
);

set local timezone = 'Pacific/Kiritimati';
select throws_ok(
  format(
    $sql$select public.v1_save_workforce_attendance_day(
      jsonb_build_object(
        'worker_id','59040000-0000-4000-8000-000000000001',
        'work_date',%L,'attendance_status','present',
        'regular_minutes',480,'overtime_minutes',0,
        'reason','Future creation must fail'
      ),null,'59120000-0000-4000-8000-000000000030'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  '22023', 'V1_WORKFORCE_ATTENDANCE_FUTURE_DATE_FORBIDDEN',
  'A future day is rejected from the retained calendar date even when the session date differs'
);

-- Simulate a retained row created before the corrective guard. The new policy
-- preserves that evidence but makes it read-only while its calendar date is
-- still future.
reset role;
alter table public.v1_workforce_attendance_days
  disable trigger v1_workforce_attendance_future_date_guard;
set local role authenticated;
select lives_ok(
  format(
    $sql$select public.v1_save_workforce_attendance_day(
      jsonb_build_object(
        'worker_id','59040000-0000-4000-8000-000000000001',
        'work_date',%L,'attendance_status','present',
        'regular_minutes',480,'overtime_minutes',0,
        'reason','Retained pre-policy future evidence'
      ),null,'59120000-0000-4000-8000-000000000031'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  'A pre-policy future row can be represented without deleting history'
);
reset role;
alter table public.v1_workforce_attendance_days
  enable trigger v1_workforce_attendance_future_date_guard;
set local role authenticated;
select throws_ok(
  format(
    $sql$select public.v1_save_workforce_attendance_day(
      jsonb_build_object(
        'worker_id','59040000-0000-4000-8000-000000000001',
        'work_date',%L,'attendance_status','absent',
        'regular_minutes',0,'overtime_minutes',0,
        'reason','Future correction must fail'
      ),1,'59120000-0000-4000-8000-000000000032'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  '22023', 'V1_WORKFORCE_ATTENDANCE_FUTURE_DATE_FORBIDDEN',
  'A retained future row cannot be corrected before its calendar-local date'
);
reset role;
select is(
  (select concat_ws('|', day.attendance_status, day.record_version, day.reason)
   from public.v1_workforce_attendance_days day
   where day.worker_id = '59040000-0000-4000-8000-000000000001'
     and day.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date + 1),
  'present|1|Retained pre-policy future evidence',
  'Rejected correction leaves retained future evidence unchanged'
);

reset role;
update public.v1_workforce_teams
set team_name = 'Renamed parent team', record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59030000-0000-4000-8000-000000000001';
update public.v1_workforce_calendars
set calendar_name = 'Renamed parent calendar',
    record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59060000-0000-4000-8000-000000000001';
update public.v1_workforce_workers
set current_status = 'inactive', record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59040000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-29","attendance_status":"absent","regular_minutes":0,"overtime_minutes":0,"reason":"Controlled historical correction"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000004'
  )$sql$,
  'A later worker deactivation does not block a controlled historical correction'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,assignment,team_name}',
  'T03 Authorized Team',
  'The retained assignment name does not drift with its parent'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,assignment,assignment_kind}',
  'temporary',
  'The server retains temporary-assignment precedence for the work date'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,initial_authority,authority_kind}',
  'admin_organization',
  'Admin creation retains its audited organization-authority basis'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,schedule,calendar_name}',
  'T03 Dubai Calendar',
  'The retained calendar name does not drift with its parent'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,schedule,day_type}',
  'public_holiday',
  'Attendance retains the separate authoritative day type'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-29', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,schedule,shift_work_date_basis}',
  'shift_start_date',
  'A retained cross-midnight shift keeps shift-start work-date semantics'
);

reset role;
select throws_ok(
  $sql$update public.v1_workforce_attendance_days
    set assignment_team_name_snapshot = 'Drifted',
        record_version = record_version + 1,
        updated_at = clock_timestamp()
    where worker_id = '59040000-0000-4000-8000-000000000001'
      and work_date = '2026-08-29'$sql$,
  '23514', 'V1_WORKFORCE_ATTENDANCE_CONTEXT_IMMUTABLE',
  'Even a direct privileged update cannot rewrite retained attendance context'
);

select throws_ok(
  $sql$delete from public.v1_workforce_attendance_days
    where worker_id = '59040000-0000-4000-8000-000000000001'
      and work_date = '2026-08-29'$sql$,
  '42501', 'V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Attendance history cannot be hard-deleted'
);

-- Restore the worker so the scoped maintainer can create a second day.
update public.v1_workforce_workers
set current_status = 'active', record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59040000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Scoped maintainer entry"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000005'
  )$sql$,
  'A capability-plus-responsibility scoped maintainer can create in scope'
);

select is(
  jsonb_array_length(public.v1_get_workforce_attendance(
    '2026-08-30', '59040000-0000-4000-8000-000000000001'
  ) -> 'days'),
  1,
  'The scoped maintainer can read the covered worker/date projection'
);

select is(
  public.v1_get_workforce_attendance(
    '2026-08-30', '59040000-0000-4000-8000-000000000001'
  ) #>> '{days,0,initial_authority,authority_kind}',
  'responsibility',
  'A scoped maintainer retains the exact responsibility authority used'
);

select throws_ok(
  $sql$select public.v1_get_workforce_attendance('2026-08-30', null)$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_READ_SCOPE_REQUIRED',
  'A non-Admin caller must identify the scoped worker being read'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000002","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Outside scope"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000006'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'Project membership alone cannot authorize a different Workforce scope'
);

reset role;
update auth.users set banned_until = '2099-01-01 00:00:00+00'
where id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":470,"overtime_minutes":10,"reason":"Inactive actor"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000007'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'An inactive actor immediately loses attendance mutation authority'
);

reset role;
update auth.users set banned_until = null
where id = '10000000-0000-4000-8000-000000000001';
update public.v1_permission_assignments
set effective_until = clock_timestamp() - interval '1 second'
where id in (
  '59100000-0000-4000-8000-000000000001',
  '59100000-0000-4000-8000-000000000002'
);
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":470,"overtime_minutes":10,"reason":"Revoked actor"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000008'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'A revoked capability immediately removes attendance authority'
);

reset role;
update public.v1_permission_assignments set effective_until = null
where id in (
  '59100000-0000-4000-8000-000000000001',
  '59100000-0000-4000-8000-000000000002'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":470,"overtime_minutes":10,"reason":"No responsibility"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000009'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'Site Engineer capability without responsibility fails closed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":470,"overtime_minutes":10,"reason":"No capability"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000010'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'Procurement responsibility without capability fails closed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":470,"overtime_minutes":10,"reason":"Expired capability"}'::jsonb,
    1, '59120000-0000-4000-8000-000000000011'
  )$sql$,
  '42501', 'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'An expired capability assignment fails closed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000004","work_date":"2026-07-31","attendance_status":"not_entered","regular_minutes":0,"overtime_minutes":0,"reason":"Before joining"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000012'
  )$sql$,
  '23514', 'V1_WORKFORCE_ATTENDANCE_ACTIVE_EMPLOYMENT_REQUIRED',
  'A new day before joining is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000004","work_date":"2026-09-01","attendance_status":"not_entered","regular_minutes":0,"overtime_minutes":0,"reason":"After leaving"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000013'
  )$sql$,
  '23514', 'V1_WORKFORCE_ATTENDANCE_ACTIVE_EMPLOYMENT_REQUIRED',
  'A new day after leaving is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59040000-0000-4000-8000-000000000003","work_date":"2026-08-30","attendance_status":"not_entered","regular_minutes":0,"overtime_minutes":0,"reason":"Inactive worker"}'::jsonb,
    null, '59120000-0000-4000-8000-000000000014'
  )$sql$,
  '23514', 'V1_WORKFORCE_ATTENDANCE_ACTIVE_EMPLOYMENT_REQUIRED',
  'A new day for an inactive worker is rejected'
);

select * from finish();
rollback;
