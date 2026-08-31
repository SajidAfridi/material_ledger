begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select is(
  (select count(*) from public.v1_capability_catalog catalog
   where public.v1_workforce_is_capability_key(catalog.capability_key)
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable),
  12::bigint,
  'The completed chain exposes all twelve accepted Workforce consumers'
);

select ok(
  not exists (
    select 1 from public.v1_capability_catalog catalog
    where public.v1_workforce_is_capability_key(catalog.capability_key)
      and (catalog.status <> 'operational'
        or catalog.authorization_mode <> 'enforced'
        or not catalog.is_assignable)
  ),
  'No reviewed Workforce capability remains shadow after Administration enablement'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_daily_roster(date,uuid,uuid,uuid,uuid,text,integer,integer)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_save_workforce_daily_roster(date,jsonb,text,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_workforce_daily_roster(date,uuid,uuid,uuid,uuid,text,integer,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_save_workforce_daily_roster(date,jsonb,text,uuid)',
    'execute'
  ),
  'Only authenticated callers receive the two T05 roster RPC grants'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_workforce_daily_roster_row_json(uuid,date)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_roster_authority_context(text,uuid,date,uuid,uuid,uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_set_overtime_reason(uuid,text,bigint,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_guard_future_timesheet_revision()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_daily_roster_allocation_targets(date)', 'execute'
  ),
  'Every T05 SECURITY DEFINER helper remains internal'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values
  (
    '59410000-0000-4000-8000-000000000001', 'WF-T05-A',
    'Workforce T05 authorized project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '59410000-0000-4000-8000-000000000002', 'WF-T05-B',
    'Workforce T05 outside project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values
  (
    '59420000-0000-4000-8000-000000000001',
    '59410000-0000-4000-8000-000000000001',
    'common', 'common', 'Common / All Buildings', true, true
  ),
  (
    '59420000-0000-4000-8000-000000000002',
    '59410000-0000-4000-8000-000000000002',
    'common', 'common', 'Common / All Buildings', true, true
  );

insert into public.v1_workforce_trades (
  id, trade_code, trade_name, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59424000-0000-4000-8000-000000000001', 'WF-T05-DUCT',
  'T05 Ductman', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59430000-0000-4000-8000-000000000001', 'WF-T05-TEAM-A',
    'T05 Authorized Team', '59410000-0000-4000-8000-000000000001',
    '59420000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59430000-0000-4000-8000-000000000002', 'WF-T05-TEAM-B',
    'T05 Outside Team', '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, trade_id, department,
  employer_company, worker_type, joining_date, current_status,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59440000-0000-4000-8000-000000000001', 'WF-T05-A1',
    'T05 Authorized Worker One', 'Ductman',
    '59424000-0000-4000-8000-000000000001', 'Projects',
    'Yorks AC & Ref.', 'yorks_employee', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59440000-0000-4000-8000-000000000002', 'WF-T05-A2',
    'T05 Authorized Worker Two', 'Helper', null, 'Projects',
    'Yorks AC & Ref.', 'temporary_worker', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59440000-0000-4000-8000-000000000003', 'WF-T05-B1',
    'T05 Outside Worker', 'Electrician', null, 'Projects',
    'Yorks AC & Ref.', 'subcontractor_worker', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59450000-0000-4000-8000-000000000001',
    '59440000-0000-4000-8000-000000000001', 'primary',
    '59430000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59410000-0000-4000-8000-000000000001',
    '59420000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T05 A1 assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59450000-0000-4000-8000-000000000002',
    '59440000-0000-4000-8000-000000000002', 'primary',
    '59430000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59410000-0000-4000-8000-000000000001',
    '59420000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T05 A2 assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59450000-0000-4000-8000-000000000003',
    '59440000-0000-4000-8000-000000000003', 'primary',
    '59430000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', 'T05 B1 assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59460000-0000-4000-8000-000000000001', 'WF-T05-CAL',
  'T05 Dubai Calendar', 'Asia/Dubai', 480, 60,
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select
  '59460000-0000-4000-8000-000000000001'::uuid,
  weekday, 'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59480000-0000-4000-8000-000000000001',
    '59430000-0000-4000-8000-000000000001',
    '59460000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T05 team A schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59480000-0000-4000-8000-000000000002',
    '59430000-0000-4000-8000-000000000002',
    '59460000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T05 team B schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

-- Two additional fixture teams retain opposite calendar-local dates at every
-- instant. They prove that the top-level future marker describes the complete
-- result instead of contradicting the row-level command flags.
insert into public.v1_workforce_internal_locations (
  id, location_code, location_name, department, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59423000-0000-4000-8000-000000000001', 'WF-T05-WORKSHOP',
  'T05 Workshop', 'Workshop Cost Centre', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59430000-0000-4000-8000-000000000003', 'WF-T05-TZ-EAST',
    'T05 Timezone East Team', '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59430000-0000-4000-8000-000000000004', 'WF-T05-TZ-WEST',
    'T05 Timezone West Team', '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, department, employer_company,
  worker_type, joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59440000-0000-4000-8000-000000000004', 'WF-T05-TZ-EAST',
    'T05 Timezone East Worker', 'Tester', 'Projects', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59440000-0000-4000-8000-000000000005', 'WF-T05-TZ-WEST',
    'T05 Timezone West Worker', 'Tester', 'Projects', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_worker_assignments (
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59450000-0000-4000-8000-000000000004',
    '59440000-0000-4000-8000-000000000004', 'primary',
    '59430000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000004',
    '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', 'T05 timezone east assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59450000-0000-4000-8000-000000000005',
    '59440000-0000-4000-8000-000000000005', 'primary',
    '59430000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004',
    '59410000-0000-4000-8000-000000000002',
    '59420000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', 'T05 timezone west assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59460000-0000-4000-8000-000000000002', 'WF-T05-CAL-EAST',
    'T05 Kiritimati Calendar', 'Pacific/Kiritimati', 480, 60,
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59460000-0000-4000-8000-000000000003', 'WF-T05-CAL-WEST',
    'T05 Pago Pago Calendar', 'Pacific/Pago_Pago', 480, 60,
    '2026-01-01', '2027-12-31', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select calendar_id, weekday, 'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from unnest(array[
  '59460000-0000-4000-8000-000000000002'::uuid,
  '59460000-0000-4000-8000-000000000003'::uuid
]) calendar_id
cross join generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59480000-0000-4000-8000-000000000003',
    '59430000-0000-4000-8000-000000000003',
    '59460000-0000-4000-8000-000000000002',
    '2026-01-01', '2027-12-31', 'T05 east timezone schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59480000-0000-4000-8000-000000000004',
    '59430000-0000-4000-8000-000000000004',
    '59460000-0000-4000-8000-000000000003',
    '2026-01-01', '2027-12-31', 'T05 west timezone schedule',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

-- Exact roles are not Workforce authority. Before any fixture capability or
-- responsibility exists, every representative operational role receives an
-- empty, non-actionable projection with no selector leakage.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
with roster as (
  select public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) as value
)
select is(
  (select concat_ws('|',
    value ->> 'total_count',
    jsonb_array_length(value #> '{selectors,teams}'),
    jsonb_array_length(value #> '{selectors,projects}'),
    jsonb_array_length(value #> '{selectors,project_scopes}'),
    jsonb_array_length(value #> '{selectors,internal_locations}'),
    jsonb_array_length(value #> '{allocation_targets,projects}'),
    jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
    jsonb_array_length(value #> '{allocation_targets,internal_locations}'),
    value #>> '{capabilities,can_maintain_attendance}',
    value #>> '{capabilities,can_maintain_timesheet}'
  ) from roster),
  '0|0|0|0|0|0|0|0|false|false',
  'An unscoped Project Engineer role leaks no roster, selector or action flag'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
with roster as (
  select public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) as value
)
select is(
  (select concat_ws('|',
    value ->> 'total_count',
    jsonb_array_length(value #> '{selectors,teams}'),
    jsonb_array_length(value #> '{selectors,projects}'),
    jsonb_array_length(value #> '{selectors,project_scopes}'),
    jsonb_array_length(value #> '{selectors,internal_locations}'),
    jsonb_array_length(value #> '{allocation_targets,projects}'),
    jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
    jsonb_array_length(value #> '{allocation_targets,internal_locations}'),
    value #>> '{capabilities,can_maintain_attendance}',
    value #>> '{capabilities,can_maintain_timesheet}'
  ) from roster),
  '0|0|0|0|0|0|0|0|false|false',
  'An unscoped Site Engineer role leaks no roster, selector or action flag'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
with roster as (
  select public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) as value
)
select is(
  (select concat_ws('|',
    value ->> 'total_count',
    jsonb_array_length(value #> '{selectors,teams}'),
    jsonb_array_length(value #> '{selectors,projects}'),
    jsonb_array_length(value #> '{selectors,project_scopes}'),
    jsonb_array_length(value #> '{selectors,internal_locations}'),
    jsonb_array_length(value #> '{allocation_targets,projects}'),
    jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
    jsonb_array_length(value #> '{allocation_targets,internal_locations}'),
    value #>> '{capabilities,can_maintain_attendance}',
    value #>> '{capabilities,can_maintain_timesheet}'
  ) from roster),
  '0|0|0|0|0|0|0|0|false|false',
  'A Procurement role leaks no roster, selector or action flag'
);
reset role;

insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '59490000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001', 'workforce.view',
    'grant', 'project', 'permission_management', '2026-01-01',
    'T05 project A view grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59490000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001',
    'workforce.attendance.maintain', 'grant', 'project',
    'permission_management', '2026-01-01',
    'T05 project A attendance grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59490000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000001',
    'workforce.timesheets.maintain', 'grant', 'project',
    'permission_management', '2026-01-01',
    'T05 project A timesheet grant',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59490000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002', 'workforce.view',
    'grant', 'organization', 'permission_management', '2026-01-01',
    'T05 capability-only negative actor',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_permission_assignment_projects (
  assignment_id, project_id
) values
  ('59490000-0000-4000-8000-000000000001',
   '59410000-0000-4000-8000-000000000001'),
  ('59490000-0000-4000-8000-000000000002',
   '59410000-0000-4000-8000-000000000001'),
  ('59490000-0000-4000-8000-000000000003',
   '59410000-0000-4000-8000-000000000001');

insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, project_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59491000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001', 'project',
  '59410000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', 'T05 project A responsibility',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) ->> 'authorization_mode',
  'enforced_t05',
  'The roster projection returns the fixed T05 authorization contract'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date
      ) as value
    )
    select concat_ws('|',
      (select count(*) from jsonb_array_elements(
        value #> '{allocation_targets,projects}'
      ) target where target ->> 'project_id' like '5941%'),
      (select count(*) from jsonb_array_elements(
        value #> '{allocation_targets,project_scopes}'
      ) target where target ->> 'project_scope_id' like '5942%'),
      (select count(*) from jsonb_array_elements(
        value #> '{allocation_targets,internal_locations}'
      ) target where target ->> 'internal_location_id' like '5942%'),
      (select target ->> 'project_scope_kind'
       from jsonb_array_elements(
         value #> '{allocation_targets,project_scopes}'
       ) target
       where target ->> 'project_scope_id' =
         '59420000-0000-4000-8000-000000000001'),
      (select target ->> 'location_code'
       from jsonb_array_elements(
         value #> '{allocation_targets,internal_locations}'
       ) target
       where target ->> 'internal_location_id' =
         '59423000-0000-4000-8000-000000000001')
    ) from roster
  ),
  '2|2|1|common|WF-T05-WORKSHOP',
  'Admin receives mandatory active project-scope and internal command targets'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Pacific/Kiritimati')::date,
        null, null, null, null, 'WF-T05-TZ-'
      ) as value
    )
    select concat_ws('|',
      value ->> 'is_future',
      value #>> '{capabilities,can_maintain_attendance}',
      (select count(*) from jsonb_array_elements(value -> 'rows') row_value
       where (row_value ->> 'can_maintain_attendance')::boolean),
      (select count(*) from jsonb_array_elements(value -> 'rows') row_value
       where not (row_value ->> 'can_maintain_attendance')::boolean)
    ) from roster
  ),
  'false|true|1|1',
  'Mixed calendar timezones expose one coherent all-rows future marker'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Pacific/Kiritimati')::date,
        null, null, null, null, 'WF-T05-TZ-', 1, 1
      ) as value
    )
    select concat_ws('|',
      value ->> 'total_count',
      jsonb_array_length(value -> 'rows'),
      value ->> 'is_future',
      value #>> '{capabilities,can_maintain_attendance}',
      value #>> '{filters,limit}',
      value #>> '{filters,offset}'
    ) from roster
  ),
  '2|1|true|false|1|1',
  'Future and command aggregates describe the returned page, not hidden pages'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    null, null, null, null, null, 500, 0
  ) #>> '{filters,limit}',
  '500',
  'The roster read accepts and echoes the 500-row performance ceiling'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    null, null, null, null, null, 1, 2
  ) #>> '{filters,offset}',
  '2',
  'The roster response echoes the exact page offset'
);

select throws_ok(
  format(
    $sql$select public.v1_get_workforce_daily_roster(
      %L::date,null,null,null,null,null,501,0
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '22023', 'V1_WORKFORCE_ROSTER_READ_INVALID',
  'The roster read rejects a page above 500 rows'
);

select is(
  (
    (public.v1_get_workforce_daily_roster(
      (clock_timestamp() at time zone 'Asia/Dubai')::date,
      '59430000-0000-4000-8000-000000000001'
    ) ->> 'total_count')::bigint
    +
    (public.v1_get_workforce_daily_roster(
      (clock_timestamp() at time zone 'Asia/Dubai')::date,
      '59430000-0000-4000-8000-000000000002'
    ) ->> 'total_count')::bigint
  ),
  3::bigint,
  'Admin sees all three fixture workers across the two exact fixture teams'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    '59430000-0000-4000-8000-000000000001'
  ) #>> '{rows,0,attendance}',
  null,
  'A missing roster row projects null attendance without creating a fact'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    '59430000-0000-4000-8000-000000000001'
  ) #>> '{rows,0,schedule_suggestion,suggested_regular_minutes}',
  '480',
  'A missing row receives a schedule-only standard-minutes suggestion'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    null, null, null, null, 'authorized worker two'
  ) #>> '{rows,0,worker_type}',
  'temporary_worker',
  'Roster search returns the authoritative T01 worker-type enum'
);

reset role;
select is(
  (select count(*) from public.v1_workforce_attendance_days day
   where day.worker_id::text like '5944%'),
  0::bigint,
  'Reading missing roster rows creates no attendance records'
);
select is(
  (select count(*) from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id::text like '5944%'),
  0::bigint,
  'Reading missing roster rows creates no allocation records'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  (public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) ->> 'total_count')::bigint,
  2::bigint,
  'A capability-plus-responsibility actor sees only covered workers'
);
select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) #>> '{capabilities,can_maintain_timesheet}',
  'true',
  'Scoped roster command flags reflect the existing T04 capability'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date
      ) as value
    )
    select concat_ws('|',
      jsonb_array_length(value #> '{selectors,projects}'),
      jsonb_array_length(value #> '{allocation_targets,projects}'),
      jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
      value #>> '{allocation_targets,projects,0,project_id}',
      value #>> '{allocation_targets,project_scopes,0,project_scope_id}'
    ) from roster
  ),
  '1|1|1|59410000-0000-4000-8000-000000000001|59420000-0000-4000-8000-000000000001',
  'Project responsibility yields only its exact active allocation targets'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(
        jsonb_build_object(
          'worker_id','59440000-0000-4000-8000-000000000001',
          'expected_attendance_version',null,
          'attendance_status','present','regular_minutes',480,
          'overtime_minutes',0,'overtime_reason',null,
          'reason','Atomic covered row','allocation_action','preserve',
          'expected_allocation_version',null,'allocations',jsonb_build_array()
        ),
        jsonb_build_object(
          'worker_id','59440000-0000-4000-8000-000000000003',
          'expected_attendance_version',null,
          'attendance_status','present','regular_minutes',480,
          'overtime_minutes',0,'overtime_reason',null,
          'reason','Atomic outside row','allocation_action','preserve',
          'expected_allocation_version',null,'allocations',jsonb_build_array()
        )
      ),'Atomic scope denial','59492000-0000-4000-8000-000000000001'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '42501', 'V1_WORKFORCE_ROSTER_SAVE_DENIED',
  'One unauthorized row rejects the whole multi-row command'
);

reset role;
select is(
  (select count(*) from public.v1_workforce_attendance_days day
   where day.worker_id::text like '5944%'),
  0::bigint,
  'The rejected mixed-scope command leaves no partial attendance row'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date
      ) as value
    )
    select concat_ws('|',
      value ->> 'total_count',
      jsonb_array_length(value #> '{selectors,teams}'),
      jsonb_array_length(value #> '{selectors,projects}'),
      jsonb_array_length(value #> '{selectors,project_scopes}'),
      jsonb_array_length(value #> '{selectors,internal_locations}'),
      jsonb_array_length(value #> '{allocation_targets,projects}'),
      jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
      jsonb_array_length(value #> '{allocation_targets,internal_locations}'),
      value #>> '{capabilities,can_maintain_attendance}',
      value #>> '{capabilities,can_maintain_timesheet}'
    ) from roster
  ),
  '0|0|0|0|0|0|0|0|false|false',
  'Capability without responsibility leaks no row, selector or action flag'
);

reset role;
insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '59490000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000002',
    'workforce.attendance.maintain', 'grant', 'organization',
    'permission_management', '2026-01-01',
    'T05 worker-only attendance capability',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59490000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.maintain', 'grant', 'organization',
    'permission_management', '2026-01-01',
    'T05 worker-only timesheet capability',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, worker_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '59491000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000002', 'worker',
  '59440000-0000-4000-8000-000000000002',
  '2026-01-01', '2027-12-31', 'T05 worker-only responsibility',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date
      ) as value
    )
    select concat_ws('|',
      value ->> 'total_count',
      jsonb_array_length(value #> '{selectors,projects}'),
      jsonb_array_length(value #> '{selectors,project_scopes}'),
      jsonb_array_length(value #> '{allocation_targets,projects}'),
      jsonb_array_length(value #> '{allocation_targets,project_scopes}'),
      jsonb_array_length(value #> '{allocation_targets,internal_locations}')
    ) from roster
  ),
  '1|1|1|0|0|0',
  'Worker-only responsibility separates roster filters from command targets'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000002',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Worker-only target denial','allocation_action','replace',
        'expected_allocation_version',null,
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','project_work',
          'project_id','59410000-0000-4000-8000-000000000001',
          'project_scope_id','59420000-0000-4000-8000-000000000001',
          'regular_minutes',480,'overtime_minutes',0
        ))
      )),'Worker-only target denial','59492000-0000-4000-8000-000000000017'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '42501', 'V1_WORKFORCE_TIMESHEET_TARGET_DENIED',
  'Worker-only responsibility cannot allocate to its assignment project'
);

reset role;
select is(
  (select count(*) from public.v1_workforce_attendance_days day
   where day.worker_id = '59440000-0000-4000-8000-000000000002'),
  0::bigint,
  'Worker-only target denial rolls back the composed attendance write'
);

-- Revocation and expiry are evaluated from the protected capability tables on
-- every call; prior successful projections do not become continuing authority.
reset role;
update public.v1_permission_assignments
set effective_until = clock_timestamp() - interval '1 second',
    updated_at = clock_timestamp()
where id = '59490000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  (public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) ->> 'total_count')::bigint,
  0::bigint,
  'A revoked Workforce view grant immediately removes roster rows'
);
reset role;
update public.v1_permission_assignments
set effective_until = null, updated_at = clock_timestamp()
where id = '59490000-0000-4000-8000-000000000001';
update public.v1_workforce_responsibility_assignments
set valid_to = (clock_timestamp() at time zone 'Asia/Dubai')::date - 1,
    record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59491000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  (public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date
  ) ->> 'total_count')::bigint,
  0::bigint,
  'An expired dated responsibility immediately removes roster rows'
);
reset role;
update public.v1_workforce_responsibility_assignments
set valid_to = '2027-12-31',
    record_version = record_version + 1,
    updated_at = clock_timestamp()
where id = '59491000-0000-4000-8000-000000000001';

-- Auth revocation is synchronized before authorization, so a cached JWT for a
-- banned actor cannot continue to read the roster.
update auth.users
set banned_until = clock_timestamp() + interval '1 day'
where id = '10000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  format(
    $sql$select public.v1_get_workforce_daily_roster(%L::date)$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '42501', 'V1_WORKFORCE_ROSTER_READ_DENIED',
  'An inactive Auth identity is denied despite a cached role claim'
);
reset role;
update auth.users
set banned_until = null
where id = '10000000-0000-4000-8000-000000000001';

-- A worker-context responsibility does not grant authority over an unrelated
-- allocation target. The nested T04 command aborts the complete roster save.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Unauthorized target','allocation_action','replace',
        'expected_allocation_version',null,
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','project_work',
          'project_id','59410000-0000-4000-8000-000000000002',
          'project_scope_id','59420000-0000-4000-8000-000000000002',
          'regular_minutes',480,'overtime_minutes',0
        ))
      )),'Unauthorized target','59492000-0000-4000-8000-000000000004'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '42501', 'V1_WORKFORCE_TIMESHEET_TARGET_DENIED',
  'A scoped maintainer cannot allocate roster time to an uncovered target'
);
reset role;
select is(
  (select count(*) from public.v1_workforce_attendance_days day
   where day.worker_id::text like '5944%'),
  0::bigint,
  'Unauthorized target rejection rolls back the composed attendance write'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Future roster','allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )),'Future roster denial','59492000-0000-4000-8000-000000000002'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  '22023', 'V1_WORKFORCE_ROSTER_FUTURE_DATE_FORBIDDEN',
  'The roster command rejects the retained calendar-local future date'
);

select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date + 1,
    '59430000-0000-4000-8000-000000000001'
  ) #>> '{rows,0,can_maintain_attendance}',
  'false',
  'Future roster projection remains readable but has no attendance command flag'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date + 1,
        '59430000-0000-4000-8000-000000000001'
      ) as value
    )
    select concat_ws('|',
      value ->> 'is_future',
      value #>> '{capabilities,can_maintain_attendance}',
      value #>> '{capabilities,can_maintain_timesheet}'
    ) from roster
  ),
  'true|false|false',
  'An all-future result is conservatively non-actionable at the top level'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      (select jsonb_agg(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','At five-hundred boundary',
        'allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )) from generate_series(1,500)),
      'At five-hundred boundary',
      '59492000-0000-4000-8000-000000000018'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '22023', 'V1_WORKFORCE_ROSTER_ROW_INVALID',
  'A 500-row save reaches per-row validation at the accepted envelope cap'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      (select jsonb_agg(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Above five-hundred boundary',
        'allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )) from generate_series(1,501)),
      'Above five-hundred boundary',
      '59492000-0000-4000-8000-000000000019'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '22023', 'V1_WORKFORCE_ROSTER_SAVE_INVALID',
  'A roster save rejects an atomic batch above 500 rows'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Unknown key','allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array(),
        'unexpected',true
      )),'Strict input','59492000-0000-4000-8000-000000000003'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '22023',
  'V1_UNKNOWN_SAVE_WORKFORCE_DAILY_ROSTER_ROW_FIELDS: unexpected',
  'Unknown roster row keys fail closed'
);

select lives_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(
        jsonb_build_object(
          'worker_id','59440000-0000-4000-8000-000000000001',
          'expected_attendance_version',null,
          'attendance_status','present','regular_minutes',480,
          'overtime_minutes',60,'overtime_reason',null,
          'reason','Roster present with optional OT evidence',
          'allocation_action','replace',
          'expected_allocation_version',null,
          'allocations',jsonb_build_array(jsonb_build_object(
            'target_kind','project_work',
            'project_id','59410000-0000-4000-8000-000000000002',
            'project_scope_id','59420000-0000-4000-8000-000000000002',
            'internal_location_id',null,
            'activity_task','External target visibility test','notes',null,
            'regular_minutes',480,'overtime_minutes',60
          ))
        ),
        jsonb_build_object(
          'worker_id','59440000-0000-4000-8000-000000000002',
          'expected_attendance_version',null,
          'attendance_status','absent','regular_minutes',0,
          'overtime_minutes',0,'overtime_reason',null,
          'reason','Roster absence','allocation_action','preserve',
          'expected_allocation_version',null,'allocations',jsonb_build_array()
        )
      ),'T05 initial roster save','59492000-0000-4000-8000-000000000010'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  'Admin can atomically create attendance and a full allocation replacement'
);

reset role;
select is(
  (select concat_ws('|', day.attendance_status, day.regular_minutes,
    day.overtime_minutes, coalesce(day.overtime_reason, '<null>'),
    day.record_version)
   from public.v1_workforce_attendance_days day
   where day.worker_id = '59440000-0000-4000-8000-000000000001'
     and day.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'present|480|60|<null>|1',
  'Positive overtime accepts absent optional evidence and retains integer minutes'
);
select is(
  (select concat_ws('|', allocation_set.current_state,
    allocation_set.record_version,
    (select count(*)
     from public.v1_workforce_timesheet_allocation_revisions revision
     where revision.allocation_set_id = allocation_set.id),
    (select count(*)
     from public.v1_workforce_timesheet_allocations allocation
     where allocation.allocation_revision_id =
       allocation_set.current_revision_id))
   from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id =
     '59440000-0000-4000-8000-000000000001'
     and allocation_set.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'active|2|1|1',
  'The initial replacement commits one complete active allocation revision'
);
select is(
  (select count(*) from public.v1_audit_events event
   where event.event_type = 'workforce_daily_roster_saved'
     and event.idempotency_key =
       '59492000-0000-4000-8000-000000000010'),
  1::bigint,
  'The multi-row roster save writes one root audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  (public.v1_save_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    jsonb_build_array(
      jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',60,'overtime_reason',null,
        'reason','Roster present with optional OT evidence',
        'allocation_action','replace',
        'expected_allocation_version',null,
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','project_work',
          'project_id','59410000-0000-4000-8000-000000000002',
          'project_scope_id','59420000-0000-4000-8000-000000000002',
          'internal_location_id',null,
          'activity_task','External target visibility test','notes',null,
          'regular_minutes',480,'overtime_minutes',60
        ))
      ),
      jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000002',
        'expected_attendance_version',null,
        'attendance_status','absent','regular_minutes',0,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Roster absence','allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )
    ), 'T05 initial roster save',
    '59492000-0000-4000-8000-000000000010'
  ) ->> 'row_count')::integer,
  2,
  'An identical root idempotency retry returns the original response'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000002',
        'expected_attendance_version',1,
        'attendance_status','absent','regular_minutes',0,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Different payload','allocation_action','preserve',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )),'Different payload','59492000-0000-4000-8000-000000000010'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same root key rejects a different roster payload'
);

select lives_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',1,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',60,'overtime_reason','Urgent fabrication evidence',
        'reason','Roster present with optional OT evidence',
        'allocation_action','preserve',
        'expected_allocation_version',2,'allocations',jsonb_build_array()
      )),'Add optional OT evidence','59492000-0000-4000-8000-000000000011'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  'Optional overtime evidence can be added without replacing allocations'
);

reset role;
select is(
  (select concat_ws('|', day.overtime_reason, day.record_version)
   from public.v1_workforce_attendance_days day
   where day.worker_id = '59440000-0000-4000-8000-000000000001'
     and day.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'Urgent fabrication evidence|2',
  'Overtime evidence round-trips as a separately versioned attendance fact'
);
select is(
  (select concat_ws('|', allocation_set.current_state,
    allocation_set.record_version,
    (select count(*)
     from public.v1_workforce_timesheet_allocation_revisions revision
     where revision.allocation_set_id = allocation_set.id),
    (select count(*)
     from public.v1_workforce_timesheet_allocations allocation
     where allocation.allocation_revision_id =
       allocation_set.current_revision_id))
   from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id =
     '59440000-0000-4000-8000-000000000001'
     and allocation_set.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'active|2|1|1',
  'Preserve keeps the active allocation revision intact with no silent loss'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',2,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',30,'overtime_reason','Changed total',
        'reason','Changed total','allocation_action','preserve',
        'expected_allocation_version',2,'allocations',jsonb_build_array()
      )),'Unsafe preserve','59492000-0000-4000-8000-000000000012'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '23514', 'V1_WORKFORCE_ROSTER_ACTIVE_ALLOCATIONS_REQUIRE_ACTION',
  'Changing attendance totals cannot silently preserve incompatible allocations'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',1,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',60,'overtime_reason','Stale',
        'reason','Stale version','allocation_action','preserve',
        'expected_allocation_version',2,'allocations',jsonb_build_array()
      )),'Stale row','59492000-0000-4000-8000-000000000013'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '40001', 'V1_WORKFORCE_ATTENDANCE_VERSION_CONFLICT',
  'A stale per-row attendance version cannot overwrite the roster'
);

select throws_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',2,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',60,'overtime_reason','Urgent fabrication evidence',
        'reason','Missing allocation version','allocation_action','withdraw',
        'expected_allocation_version',null,'allocations',jsonb_build_array()
      )),'Missing set version','59492000-0000-4000-8000-000000000014'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  '40001', 'V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT',
  'Replace and withdraw require the exact existing allocation-set version'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    null, null, null, null, 'WF-T05-A1'
  ) #>> '{rows,0,allocation_set}',
  null,
  'A covered worker row does not leak an allocation target outside capability scope'
);
select is(
  public.v1_get_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    null, null, null, null, 'WF-T05-A1'
  ) #>> '{rows,0,allocation_details_restricted}',
  'true',
  'Restricted allocation details retain an explicit nonleaking lock indicator'
);

select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Asia/Dubai')::date,
        null, null, null, null, 'WF-T05-A1'
      ) as value
    )
    select concat_ws('|',
      value #>> '{rows,0,can_maintain_timesheet}',
      value #>> '{capabilities,can_maintain_timesheet}',
      jsonb_array_length(value #> '{allocation_targets,projects}'),
      value #>> '{allocation_targets,projects,0,project_id}'
    ) from roster
  ),
  'false|false|1|59410000-0000-4000-8000-000000000001',
  'An active uncovered allocation target removes row and aggregate command authority'
);

with saved as (
  select public.v1_save_workforce_daily_roster(
    (clock_timestamp() at time zone 'Asia/Dubai')::date,
    jsonb_build_array(jsonb_build_object(
      'worker_id','59440000-0000-4000-8000-000000000001',
      'expected_attendance_version',2,
      'attendance_status','present','regular_minutes',480,
      'overtime_minutes',60,
      'overtime_reason','Scoped evidence-only correction',
      'reason','Roster present with optional OT evidence',
      'allocation_action','preserve',
      'expected_allocation_version',null,'allocations',jsonb_build_array()
    )), 'Restricted evidence-only correction',
    '59492000-0000-4000-8000-000000000016'
  ) as value
)
select is(
  (select jsonb_build_array(
    value #> '{rows,0,allocation_set}',
    value #> '{rows,0,allocation_set_id}',
    value #> '{rows,0,allocation_set_record_version}',
    value #> '{rows,0,allocation_state}'
  ) from saved),
  '[null,null,null,null]'::jsonb,
  'Restricted evidence-only save returns no partial allocation identifiers'
);

reset role;
select is(
  (select concat_ws('|', day.overtime_reason, day.record_version)
   from public.v1_workforce_attendance_days day
   where day.worker_id = '59440000-0000-4000-8000-000000000001'
     and day.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'Scoped evidence-only correction|3',
  'A restricted attendance maintainer can preserve a hidden allocation lock'
);
select is(
  (select concat_ws('|', allocation_set.current_state,
    allocation_set.record_version,
    (select count(*)
     from public.v1_workforce_timesheet_allocation_revisions revision
     where revision.allocation_set_id = allocation_set.id),
    (select count(*)
     from public.v1_workforce_timesheet_allocations allocation
     where allocation.allocation_revision_id =
       allocation_set.current_revision_id))
   from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id =
     '59440000-0000-4000-8000-000000000001'
     and allocation_set.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'active|2|1|1',
  'Evidence-only preserve leaves hidden allocation revision/history unchanged'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000001',
        'expected_attendance_version',3,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',60,
        'overtime_reason','Urgent fabrication evidence',
        'reason','Roster present with optional OT evidence',
        'allocation_action','withdraw',
        'expected_allocation_version',2,'allocations',jsonb_build_array()
      )),'Explicit roster withdrawal','59492000-0000-4000-8000-000000000015'
    )$sql$,
    (clock_timestamp() at time zone 'Asia/Dubai')::date::text
  ),
  'An explicit withdraw action preserves attendance and supersedes allocations'
);

reset role;
select is(
  (select concat_ws('|', allocation_set.current_state,
    allocation_set.record_version,
    allocation_set.current_revision_number)
   from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id =
     '59440000-0000-4000-8000-000000000001'
     and allocation_set.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date),
  'withdrawn|3|2',
  'Withdrawal retains immutable history and advances the set version once'
);

-- Represent one retained future row/set created before the T03/T05 guards.
-- The row is fixture-scoped, preserved, and both accepted T04 mutation RPCs
-- must now reject it through the shared revision boundary.
alter table public.v1_workforce_attendance_days
  disable trigger v1_workforce_attendance_future_date_guard;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  format(
    $sql$select public.v1_save_workforce_attendance_day(
      jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000003',
        'work_date',%L,'attendance_status','present',
        'regular_minutes',480,'overtime_minutes',0,
        'reason','Retained future T05/T04 fixture'
      ),null,'59493000-0000-4000-8000-000000000001'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  'A retained pre-policy future attendance fixture is representable'
);
reset role;
alter table public.v1_workforce_attendance_days
  enable trigger v1_workforce_attendance_future_date_guard;
select set_config(
  'test.t05_future_attendance_day_id',
  (select day.id::text
   from public.v1_workforce_attendance_days day
   where day.worker_id = '59440000-0000-4000-8000-000000000003'
     and day.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date + 1),
  true
);
alter table public.v1_workforce_timesheet_allocation_revisions
  disable trigger v1_workforce_timesheet_revision_future_date_guard;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  format(
    $sql$select public.v1_save_workforce_timesheet_allocations(
      jsonb_build_object(
        'attendance_day_id',
          current_setting('test.t05_future_attendance_day_id')::uuid,
        'attendance_record_version',1,
        'reason','Retained future allocation fixture',
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','project_work',
          'project_id','59410000-0000-4000-8000-000000000001',
          'project_scope_id','59420000-0000-4000-8000-000000000001',
          'regular_minutes',480,'overtime_minutes',0
        ))
      ),null,'59493000-0000-4000-8000-000000000002'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  'A retained pre-policy future allocation fixture is representable'
);
reset role;
alter table public.v1_workforce_timesheet_allocation_revisions
  enable trigger v1_workforce_timesheet_revision_future_date_guard;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  format(
    $sql$select public.v1_save_workforce_timesheet_allocations(
      jsonb_build_object(
        'attendance_day_id',
          current_setting('test.t05_future_attendance_day_id')::uuid,
        'attendance_record_version',1,
        'reason','Future T04 save rejection',
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','project_work',
          'project_id','59410000-0000-4000-8000-000000000001',
          'project_scope_id','59420000-0000-4000-8000-000000000001',
          'regular_minutes',480,'overtime_minutes',0
        ))
      ),2,'59493000-0000-4000-8000-000000000003'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  '22023', 'V1_WORKFORCE_TIMESHEET_FUTURE_DATE_FORBIDDEN',
  'T04 save explicitly rejects a retained future row'
);

select throws_ok(
  format(
    $sql$select public.v1_withdraw_workforce_timesheet_allocations(
      current_setting('test.t05_future_attendance_day_id')::uuid,
      'Future T04 withdraw rejection',2,
      '59493000-0000-4000-8000-000000000004'
    )$sql$,
    ((clock_timestamp() at time zone 'Asia/Dubai')::date + 1)::text
  ),
  '22023', 'V1_WORKFORCE_TIMESHEET_FUTURE_DATE_FORBIDDEN',
  'T04 withdraw explicitly rejects a retained future row'
);

reset role;
select is(
  (select concat_ws('|', allocation_set.current_state,
    allocation_set.record_version,
    (select count(*)
     from public.v1_workforce_timesheet_allocation_revisions revision
     where revision.allocation_set_id = allocation_set.id))
   from public.v1_workforce_timesheet_allocation_sets allocation_set
   where allocation_set.worker_id =
     '59440000-0000-4000-8000-000000000003'
     and allocation_set.work_date =
       (clock_timestamp() at time zone 'Asia/Dubai')::date + 1),
  'active|2|1',
  'Rejected future T04 commands leave the retained fixture unchanged'
);

-- A restricted worker row gains exactly one internal command target only
-- after an explicit target responsibility is added. This proves both halves
-- of the worker-plus-target authority contract without reusing read filters.
insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, worker_id, internal_location_id,
  valid_from, valid_to, reason, assigned_by_auth_user_id,
  assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '59491000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002', 'worker',
    '59440000-0000-4000-8000-000000000004', null,
    '2026-01-01', '2027-12-31', 'T05 exact worker responsibility',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59491000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002', 'internal_location',
    null, '59423000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T05 exact internal target responsibility',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select is(
  (
    with roster as (
      select public.v1_get_workforce_daily_roster(
        (clock_timestamp() at time zone 'Pacific/Kiritimati')::date,
        null, null, null, null, 'WF-T05-TZ-EAST'
      ) as value
    )
    select concat_ws('|',
      value ->> 'total_count',
      jsonb_array_length(value #> '{selectors,projects}'),
      jsonb_array_length(value #> '{allocation_targets,projects}'),
      jsonb_array_length(value #> '{allocation_targets,internal_locations}'),
      value #>> '{allocation_targets,internal_locations,0,internal_location_id}',
      value #>> '{rows,0,can_maintain_timesheet}'
    ) from roster
  ),
  '1|2|0|1|59423000-0000-4000-8000-000000000001|true',
  'Exact worker plus internal responsibility exposes only that command target'
);

select lives_ok(
  format(
    $sql$select public.v1_save_workforce_daily_roster(
      %L::date,
      jsonb_build_array(jsonb_build_object(
        'worker_id','59440000-0000-4000-8000-000000000004',
        'expected_attendance_version',null,
        'attendance_status','present','regular_minutes',480,
        'overtime_minutes',0,'overtime_reason',null,
        'reason','Exact internal target path','allocation_action','replace',
        'expected_allocation_version',null,
        'allocations',jsonb_build_array(jsonb_build_object(
          'target_kind','internal_work',
          'project_id',null,'project_scope_id',null,
          'internal_location_id','59423000-0000-4000-8000-000000000001',
          'activity_task','Workshop fabrication','notes',null,
          'regular_minutes',480,'overtime_minutes',0
        ))
      )),'Exact internal target path',
      '59492000-0000-4000-8000-000000000020'
    )$sql$,
    (clock_timestamp() at time zone 'Pacific/Kiritimati')::date::text
  ),
  'Explicit worker and internal responsibilities authorize the exact save path'
);

reset role;
select is(
  (select allocation.project_snapshot
   from (
     select jsonb_build_object(
       'kind', allocation.target_kind,
       'target', allocation.internal_location_id,
       'department', allocation.department_cost_centre_snapshot
     ) as project_snapshot
     from public.v1_workforce_timesheet_allocation_sets allocation_set
     join public.v1_workforce_timesheet_allocations allocation
       on allocation.allocation_revision_id =
         allocation_set.current_revision_id
     where allocation_set.worker_id =
       '59440000-0000-4000-8000-000000000004'
       and allocation_set.work_date =
         (clock_timestamp() at time zone 'Pacific/Kiritimati')::date
   ) allocation),
  jsonb_build_object(
    'kind', 'internal_work',
    'target', '59423000-0000-4000-8000-000000000001'::uuid,
    'department', 'Workshop Cost Centre'
  ),
  'The exact internal target save retains its authoritative target snapshot'
);

select * from finish();
rollback;
