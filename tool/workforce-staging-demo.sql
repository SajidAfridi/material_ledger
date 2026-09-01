-- Yorks Workforce staging demonstration dataset.
--
-- This is an operator fixture, not a migration. It is deliberately guarded by
-- the seven repository technical personas so it cannot run against production.
-- Every visible business record is prefixed with DEMO or STAGING DEMO.

begin;

do $$
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
    )
  then
    raise exception 'WORKFORCE_DEMO_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
end;
$$;

-- Projects and physical scopes used by allocation examples.
insert into public.v1_projects (
  id, project_ref, name, job_contract_reference, project_site,
  start_date, target_completion_date, notes, state,
  current_action_owner_role, created_by_auth_user_id, created_by_role
) values
  (
    '5de01000-0000-4000-8000-000000000001', 'DEMO-YRA-TOWER',
    'STAGING DEMO - Al Raha Tower HVAC Retrofit', 'DEMO/2026/001',
    'Al Raha, Abu Dhabi', '2026-08-01', '2026-12-31',
    'STAGING DEMO DATA - safe to reset; not a real Yorks contract.',
    'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '5de01000-0000-4000-8000-000000000002', 'DEMO-YRA-RETAIL',
    'STAGING DEMO - Marina Retail Fit-out', 'DEMO/2026/002',
    'Marina, Abu Dhabi', '2026-08-01', '2026-11-30',
    'STAGING DEMO DATA - second project for split-allocation testing.',
    'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  )
on conflict do nothing;

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, floors_levels,
  delivery_address, is_active, is_immutable
) values
  ('5de02000-0000-4000-8000-000000000001',
   '5de01000-0000-4000-8000-000000000001',
   'common', 'common', 'Common / All Buildings', '[]',
   'Al Raha, Abu Dhabi', true, true),
  ('5de02000-0000-4000-8000-000000000002',
   '5de01000-0000-4000-8000-000000000001',
   'building', 'tower-a', 'Tower A', '["B2","B1","G","01","02"]',
   'Tower A loading bay, Al Raha', true, false),
  ('5de02000-0000-4000-8000-000000000003',
   '5de01000-0000-4000-8000-000000000001',
   'building', 'tower-b', 'Tower B', '["B1","G","01","02"]',
   'Tower B loading bay, Al Raha', true, false),
  ('5de02000-0000-4000-8000-000000000004',
   '5de01000-0000-4000-8000-000000000002',
   'common', 'common', 'Common / All Buildings', '[]',
   'Marina, Abu Dhabi', true, true),
  ('5de02000-0000-4000-8000-000000000005',
   '5de01000-0000-4000-8000-000000000002',
   'building', 'retail-block', 'Retail Block', '["G","M"]',
   'Retail Block service entrance, Marina', true, false)
on conflict do nothing;

insert into public.v1_project_members (
  id, project_id, member_auth_user_id, project_role, effective_from,
  reason, assigned_by_auth_user_id, assigned_by_role
) values
  ('5de0b000-0000-4000-8000-000000000001',
   '5de01000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   '2026-08-01 00:00:00+00', 'STAGING DEMO project lead',
   '10000000-0000-4000-8000-000000000004', 'admin'),
  ('5de0b000-0000-4000-8000-000000000002',
   '5de01000-0000-4000-8000-000000000001',
   '10000000-0000-4000-8000-000000000002', 'site_engineer',
   '2026-08-01 00:00:00+00', 'STAGING DEMO site supervisor',
   '10000000-0000-4000-8000-000000000004', 'admin'),
  ('5de0b000-0000-4000-8000-000000000003',
   '5de01000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000001', 'project_engineer',
   '2026-08-01 00:00:00+00', 'STAGING DEMO project lead',
   '10000000-0000-4000-8000-000000000004', 'admin'),
  ('5de0b000-0000-4000-8000-000000000004',
   '5de01000-0000-4000-8000-000000000002',
   '10000000-0000-4000-8000-000000000002', 'site_engineer',
   '2026-08-01 00:00:00+00', 'STAGING DEMO site supervisor',
   '10000000-0000-4000-8000-000000000004', 'admin')
on conflict do nothing;

-- Trades, internal work locations and three flexible crews.
insert into public.v1_workforce_trades (
  id, trade_code, trade_name, description, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  ('5de03000-0000-4000-8000-000000000001', 'DEMO-DUCT', 'Duct Technician',
   'STAGING DEMO trade', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de03000-0000-4000-8000-000000000002', 'DEMO-PIPE', 'Pipe Fitter',
   'STAGING DEMO trade', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de03000-0000-4000-8000-000000000003', 'DEMO-ELEC', 'Electrician',
   'STAGING DEMO trade', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de03000-0000-4000-8000-000000000004', 'DEMO-HELP', 'General Helper',
   'STAGING DEMO trade', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004')
on conflict do nothing;

insert into public.v1_workforce_internal_locations (
  id, location_code, location_name, department, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  ('5de03500-0000-4000-8000-000000000001', 'DEMO-WORKSHOP',
   'STAGING DEMO - Main Workshop', 'Workshop / CC-100', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de03500-0000-4000-8000-000000000002', 'DEMO-OFFICE',
   'STAGING DEMO - Head Office', 'Administration / CC-010', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004')
on conflict do nothing;

insert into public.v1_workforce_teams (
  id, team_code, team_name, department, default_supervisor_auth_user_id,
  default_project_id, default_project_scope_id, default_internal_location_id,
  valid_from, is_active, created_by_auth_user_id, updated_by_auth_user_id
) values
  ('5de04000-0000-4000-8000-000000000001', 'DEMO-SITE-A',
   'STAGING DEMO - Tower A Installation Crew', 'Projects',
   '10000000-0000-4000-8000-000000000002',
   '5de01000-0000-4000-8000-000000000001',
   '5de02000-0000-4000-8000-000000000002', null,
   '2026-08-01', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de04000-0000-4000-8000-000000000002', 'DEMO-WORKSHOP',
   'STAGING DEMO - Workshop Fabrication Crew', 'Workshop',
   '10000000-0000-4000-8000-000000000001',
   null, null, '5de03500-0000-4000-8000-000000000001',
   '2026-08-01', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de04000-0000-4000-8000-000000000003', 'DEMO-RETAIL',
   'STAGING DEMO - Retail Fit-out Crew', 'Projects',
   '10000000-0000-4000-8000-000000000002',
   '5de01000-0000-4000-8000-000000000002',
   '5de02000-0000-4000-8000-000000000005', null,
   '2026-08-01', true,
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004')
on conflict do nothing;

-- A mixture of Yorks employees, hourly temporary workers and subcontractors.
insert into public.v1_workforce_workers (
  id, worker_number, full_name, preferred_display_name, designation, trade_id,
  department, employer_company, worker_type, joining_date, current_status,
  notes, created_by_auth_user_id, updated_by_auth_user_id
) values
  ('5de05000-0000-4000-8000-000000000001', 'DEMO-W001', 'Shabir Allah', 'Shabir',
   'Senior Duct Technician', '5de03000-0000-4000-8000-000000000001',
   'Projects', 'Yorks AC & Ref.', 'yorks_employee', '2026-01-01', 'active',
   'STAGING DEMO worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000002', 'DEMO-W002', 'Imran Khan', 'Imran',
   'Pipe Fitter', '5de03000-0000-4000-8000-000000000002',
   'Projects', 'Yorks AC & Ref.', 'yorks_employee', '2026-02-01', 'active',
   'STAGING DEMO worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000003', 'DEMO-W003', 'Rashid Ali', 'Rashid',
   'Electrician', '5de03000-0000-4000-8000-000000000003',
   'Projects', 'Yorks AC & Ref.', 'yorks_employee', '2026-03-01', 'active',
   'STAGING DEMO worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000004', 'DEMO-W004', 'Aslam Noor', 'Aslam',
   'General Helper', '5de03000-0000-4000-8000-000000000004',
   'Projects', 'Hourly Demo Labour Supply', 'temporary_worker', '2026-08-01', 'active',
   'STAGING DEMO hourly/temporary worker; no payroll calculation.',
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000005', 'DEMO-W005', 'Naveed Ahmad', 'Naveed',
   'Workshop Fabricator', '5de03000-0000-4000-8000-000000000001',
   'Workshop', 'Yorks AC & Ref.', 'yorks_employee', '2026-01-15', 'active',
   'STAGING DEMO worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000006', 'DEMO-W006', 'Bilal Hussain', 'Bilal',
   'Workshop Helper', '5de03000-0000-4000-8000-000000000004',
   'Workshop', 'Hourly Demo Labour Supply', 'temporary_worker', '2026-08-01', 'active',
   'STAGING DEMO hourly/temporary worker; no payroll calculation.',
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000007', 'DEMO-W007', 'Faisal Karim', 'Faisal',
   'Duct Technician', '5de03000-0000-4000-8000-000000000001',
   'Projects', 'Demo MEP Subcontractor LLC', 'subcontractor_worker', '2026-08-01', 'active',
   'STAGING DEMO subcontractor worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000008', 'DEMO-W008', 'Salman Raza', 'Salman',
   'Pipe Fitter', '5de03000-0000-4000-8000-000000000002',
   'Projects', 'Demo MEP Subcontractor LLC', 'subcontractor_worker', '2026-08-01', 'active',
   'STAGING DEMO subcontractor worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000009', 'DEMO-W009', 'Tariq Mahmood', 'Tariq',
   'Electrician', '5de03000-0000-4000-8000-000000000003',
   'Projects', 'Yorks AC & Ref.', 'yorks_employee', '2026-04-01', 'active',
   'STAGING DEMO worker', '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004'),
  ('5de05000-0000-4000-8000-000000000010', 'DEMO-W010', 'Waqas Ahmed', 'Waqas',
   'General Helper', '5de03000-0000-4000-8000-000000000004',
   'Projects', 'Hourly Demo Labour Supply', 'agency_worker', '2026-08-01', 'active',
   'STAGING DEMO agency worker; no payroll calculation.',
   '10000000-0000-4000-8000-000000000004',
   '10000000-0000-4000-8000-000000000004')
on conflict do nothing;

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, internal_location_id, valid_from, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
)
select
  ('5de06000-0000-4000-8000-' || lpad(worker_index::text, 12, '0'))::uuid,
  ('5de05000-0000-4000-8000-' || lpad(worker_index::text, 12, '0'))::uuid,
  'primary',
  case
    when worker_index <= 4 then '5de04000-0000-4000-8000-000000000001'::uuid
    when worker_index <= 6 then '5de04000-0000-4000-8000-000000000002'::uuid
    else '5de04000-0000-4000-8000-000000000003'::uuid
  end,
  case when worker_index between 5 and 6
    then '10000000-0000-4000-8000-000000000001'::uuid
    else '10000000-0000-4000-8000-000000000002'::uuid end,
  case
    when worker_index <= 4 then '5de01000-0000-4000-8000-000000000001'::uuid
    when worker_index >= 7 then '5de01000-0000-4000-8000-000000000002'::uuid
  end,
  case
    when worker_index <= 4 then '5de02000-0000-4000-8000-000000000002'::uuid
    when worker_index >= 7 then '5de02000-0000-4000-8000-000000000005'::uuid
  end,
  case when worker_index between 5 and 6
    then '5de03500-0000-4000-8000-000000000001'::uuid end,
  '2026-08-01', 'STAGING DEMO primary crew assignment',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1, 10) worker_index
on conflict do nothing;

-- One UAE calendar and a normal day shift for all demo teams.
insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '5de07000-0000-4000-8000-000000000001', 'DEMO-UAE-6DAY',
  'STAGING DEMO - UAE Six-day Calendar', 'Asia/Dubai',
  480, 60, '2026-08-01', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
)
on conflict do nothing;

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type,
  created_by_auth_user_id, updated_by_auth_user_id
)
select '5de07000-0000-4000-8000-000000000001'::uuid,
  weekday,
  case when weekday = 7 then 'weekly_off' else 'regular_working_day' end,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday
on conflict do nothing;

insert into public.v1_workforce_shift_templates (
  id, shift_code, shift_name, shift_kind, start_time, end_time,
  scheduled_minutes, break_minutes, work_date_basis, valid_from, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '5de08000-0000-4000-8000-000000000001', 'DEMO-DAY-0630',
  'STAGING DEMO - 06:30 Site/Workshop Shift', 'normal_site',
  '06:30', '15:30', 480, 60, 'shift_start_date', '2026-08-01', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
)
on conflict do nothing;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, shift_template_id, valid_from, reason,
  created_by_auth_user_id, updated_by_auth_user_id
)
select
  ('5de09000-0000-4000-8000-' || lpad(team_index::text, 12, '0'))::uuid,
  ('5de04000-0000-4000-8000-' || lpad(team_index::text, 12, '0'))::uuid,
  '5de07000-0000-4000-8000-000000000001',
  '5de08000-0000-4000-8000-000000000001',
  '2026-08-01', 'STAGING DEMO default calendar and shift',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1, 3) team_index
on conflict do nothing;

-- Grant the technical staging personas enough explicit capability for a real
-- multi-person workflow. The operator reads the protected catalogue while the
-- trusted commands still authorize against the exact Admin JWT claims below.
-- Admin remains the master-data administrator.
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

do $$
declare
  v_target record;
  v_changes jsonb;
begin
  for v_target in
    select profile.legacy_app_user_id, revision.revision
    from public.v1_profiles profile
    join public.v1_permission_revisions revision
      on revision.auth_user_id = profile.auth_user_id
    where profile.auth_user_id in (
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000010'
    )
  loop
    if (
      select count(*)
      from public.v1_permission_assignments assignment
      where assignment.auth_user_id = (
        select profile.auth_user_id
        from public.v1_profiles profile
        where profile.legacy_app_user_id = v_target.legacy_app_user_id
      )
        and assignment.capability_key like 'workforce.%'
        and assignment.effect = 'grant'
        and assignment.scope_kind = 'organization'
        and assignment.effective_from <= statement_timestamp()
        and (
          assignment.effective_until is null
          or assignment.effective_until >= statement_timestamp()
        )
    ) = (
      select count(*)
      from public.v1_capability_catalog catalog
      where catalog.capability_key like 'workforce.%'
        and catalog.status = 'operational'
        and catalog.is_assignable
        and 'organization' = any(catalog.allowed_scope_kinds)
    ) and exists (
      select 1
      from public.v1_workforce_responsibility_assignments responsibility
      join public.v1_profiles profile
        on profile.auth_user_id = responsibility.auth_user_id
      where profile.legacy_app_user_id = v_target.legacy_app_user_id
        and responsibility.scope_kind = 'organization'
        and responsibility.valid_from <= '2026-09-01'
        and (
          responsibility.valid_to is null
          or responsibility.valid_to >= '2026-09-01'
        )
    ) then
      continue;
    end if;

    select jsonb_agg(
      jsonb_build_object(
        'operation', 'set',
        'capability_key', catalog.capability_key,
        'effect', 'grant',
        'scope_kind', 'organization',
        'project_ids', '[]'::jsonb,
        'effective_from', '2026-08-01T00:00:00Z',
        'effective_until', null
      ) order by catalog.display_order
    )
    into v_changes
    from public.v1_capability_catalog catalog
    where catalog.capability_key like 'workforce.%'
      and catalog.status = 'operational'
      and catalog.is_assignable
      and 'organization' = any(catalog.allowed_scope_kinds);

    perform public.v1_apply_user_permission_changes_with_workforce(
      v_target.legacy_app_user_id,
      v_changes,
      'STAGING DEMO access for end-to-end Workforce testing',
      v_target.revision,
      true,
      md5('workforce-demo-permissions:' || v_target.legacy_app_user_id)::uuid
    );
  end loop;
end;
$$;

-- Retained, server-authored attendance and allocation snapshots for August
-- plus the current demonstration day. Sunday is the configured weekly off.
do $$
declare
  v_worker record;
  v_date date;
  v_status text;
  v_regular integer;
  v_overtime integer;
  v_attendance_id uuid;
  v_allocation jsonb;
begin
  for v_worker in
    select worker.id, worker.worker_number,
      substring(worker.worker_number from '[0-9]+$')::integer as worker_index
    from public.v1_workforce_workers worker
    where worker.worker_number like 'DEMO-W%'
    order by worker.worker_number
  loop
    for v_date in
      select day_value::date
      from generate_series('2026-08-01'::date, '2026-08-31'::date, interval '1 day') day_value
      where extract(isodow from day_value) <> 7
      union all select '2026-09-01'::date
    loop
      v_status := case
        when v_worker.worker_index = 2 and v_date = '2026-08-12' then 'absent'
        when v_worker.worker_index = 3 and v_date = '2026-08-19' then 'sick_leave'
        when v_worker.worker_index = 4 and v_date = '2026-08-20' then 'annual_leave'
        when v_worker.worker_index = 8 and v_date = '2026-09-01' then 'official_leave'
        else 'present'
      end;
      v_regular := case when v_status = 'present' then 480 else 0 end;
      v_overtime := case
        when v_status = 'present' and (
          extract(isodow from v_date) = 6
          or (v_worker.worker_index = 1 and v_date = '2026-08-07')
        ) then 60
        else 0
      end;

      perform public.v1_save_workforce_attendance_day(
        jsonb_build_object(
          'worker_id', v_worker.id,
          'work_date', v_date,
          'attendance_status', v_status,
          'regular_minutes', v_regular,
          'overtime_minutes', v_overtime,
          'reason', case
            when v_status = 'present' then 'STAGING DEMO confirmed shift'
            when v_status = 'absent' then 'STAGING DEMO unplanned absence'
            when v_status = 'sick_leave' then 'STAGING DEMO sick leave'
            when v_status = 'annual_leave' then 'STAGING DEMO annual leave'
            else 'STAGING DEMO official leave'
          end
        ),
        null,
        md5('workforce-demo-attendance:' || v_worker.id || ':' || v_date)::uuid
      );

      if v_status = 'present' then
        select attendance.id into v_attendance_id
        from public.v1_workforce_attendance_days attendance
        where attendance.worker_id = v_worker.id
          and attendance.work_date = v_date;

        if v_worker.worker_index = 1 and v_date = '2026-08-07' then
          v_allocation := jsonb_build_array(
            jsonb_build_object(
              'target_kind', 'project_work',
              'project_id', '5de01000-0000-4000-8000-000000000001',
              'project_scope_id', '5de02000-0000-4000-8000-000000000002',
              'activity_task', 'Tower A duct installation',
              'regular_minutes', 300,
              'overtime_minutes', v_overtime / 2
            ),
            jsonb_build_object(
              'target_kind', 'internal_work',
              'internal_location_id', '5de03500-0000-4000-8000-000000000001',
              'activity_task', 'Workshop duct fabrication',
              'regular_minutes', 180,
              'overtime_minutes', v_overtime - (v_overtime / 2)
            )
          );
        elsif v_worker.worker_index between 1 and 4 then
          v_allocation := jsonb_build_array(jsonb_build_object(
            'target_kind', 'project_work',
            'project_id', '5de01000-0000-4000-8000-000000000001',
            'project_scope_id', case when v_date >= '2026-08-24'
              then '5de02000-0000-4000-8000-000000000003'
              else '5de02000-0000-4000-8000-000000000002' end,
            'activity_task', case when v_date >= '2026-08-24'
              then 'Tower B HVAC installation support'
              else 'Tower A HVAC installation' end,
            'regular_minutes', v_regular,
            'overtime_minutes', v_overtime
          ));
        elsif v_worker.worker_index between 5 and 6 then
          v_allocation := jsonb_build_array(jsonb_build_object(
            'target_kind', 'internal_work',
            'internal_location_id', '5de03500-0000-4000-8000-000000000001',
            'activity_task', 'Workshop fabrication and preparation',
            'regular_minutes', v_regular,
            'overtime_minutes', v_overtime
          ));
        else
          v_allocation := jsonb_build_array(jsonb_build_object(
            'target_kind', 'project_work',
            'project_id', '5de01000-0000-4000-8000-000000000002',
            'project_scope_id', '5de02000-0000-4000-8000-000000000005',
            'activity_task', 'Retail Block HVAC fit-out',
            'regular_minutes', v_regular,
            'overtime_minutes', v_overtime
          ));
        end if;

        perform public.v1_save_workforce_timesheet_allocations(
          jsonb_build_object(
            'attendance_day_id', v_attendance_id,
            'attendance_record_version', 1,
            'reason', 'STAGING DEMO reviewed daily allocation',
            'allocations', v_allocation
          ),
          null,
          md5('workforce-demo-allocation:' || v_worker.id || ':' || v_date)::uuid
        );
      end if;
    end loop;
  end loop;
end;
$$;

-- Initialize immutable monthly validation runs so Monthly and review surfaces
-- show real totals, warnings and lifecycle actions immediately.
do $$
declare
  v_period record;
begin
  for v_period in
    select team.id as team_id, month_value
    from public.v1_workforce_teams team
    cross join (values ('2026-08-01'::date), ('2026-09-01'::date))
      month_row(month_value)
    where team.team_code like 'DEMO-%'
  loop
    perform public.v1_validate_workforce_monthly_period(
      jsonb_build_object(
        'team_id', v_period.team_id,
        'period_month', v_period.month_value
      ),
      null,
      md5(
        'workforce-demo-month:' || v_period.team_id || ':' ||
        v_period.month_value
      )::uuid
    );
  end loop;
end;
$$;

reset role;
commit;
