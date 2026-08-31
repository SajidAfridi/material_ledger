begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  (select bool_and(relrowsecurity)
   from pg_catalog.pg_class
   where oid in (
     'public.v1_workforce_timesheet_allocation_sets'::regclass,
     'public.v1_workforce_timesheet_allocation_revisions'::regclass,
     'public.v1_workforce_timesheet_allocations'::regclass
   ))
  and not exists (
    select 1
    from (values
      ('v1_workforce_timesheet_allocation_sets'),
      ('v1_workforce_timesheet_allocation_revisions'),
      ('v1_workforce_timesheet_allocations')
    ) relation(relation_name)
    cross join (values ('select'), ('insert'), ('update'), ('delete'))
      privilege(privilege_name)
    where has_table_privilege(
      'authenticated', 'public.' || relation.relation_name,
      privilege.privilege_name
    )
  ),
  'All T04 relations use RLS and expose no authenticated CRUD'
);

select ok(
  (select bool_and(
    has_table_privilege('service_role', 'public.' || relation_name, 'select')
    and has_table_privilege('service_role', 'public.' || relation_name, 'insert')
    and has_table_privilege('service_role', 'public.' || relation_name, 'update')
    and has_table_privilege('service_role', 'public.' || relation_name, 'delete')
  ) from (values
    ('v1_workforce_timesheet_allocation_sets'),
    ('v1_workforce_timesheet_allocation_revisions'),
    ('v1_workforce_timesheet_allocations')
  ) relation(relation_name)),
  'Service role retains direct administration of all T04 relations'
);

select is(
  (select count(*) from public.v1_capability_catalog catalog
   where public.v1_workforce_is_capability_key(catalog.capability_key)
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable),
  12::bigint,
  'All twelve reviewed Workforce consumers are operational'
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
    'public.v1_get_workforce_timesheet_allocations(date,uuid)', 'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_save_workforce_timesheet_allocations(jsonb,bigint,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_withdraw_workforce_timesheet_allocations(uuid,text,bigint,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_target_authority(text,date,text,uuid,uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_save_workforce_timesheet_allocations(jsonb,bigint,uuid)',
    'execute'
  ),
  'Only the intended T04 RPCs are callable by authenticated clients'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_block_immutable_update()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_guard_set_update()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_guard_attendance_allocations()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_worker_authority(text,v1_workforce_attendance_days)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_set_json(uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timesheet_current_targets_authorized(text,uuid)',
    'execute'
  ),
  'Every internal T04 helper and trigger function is non-callable by authenticated clients'
);

insert into public.v1_projects (
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values
  (
    '59210000-0000-4000-8000-000000000001', 'WF-T04-A',
    'Workforce T04 authorized project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '59210000-0000-4000-8000-000000000002', 'WF-T04-B',
    'Workforce T04 outside project', 'active', 'project_engineer',
    '10000000-0000-4000-8000-000000000004', 'admin'
  ),
  (
    '59210000-0000-4000-8000-000000000003', 'WF-T04-INACTIVE',
    'Workforce T04 inactive project', 'completed', 'none',
    '10000000-0000-4000-8000-000000000004', 'admin'
  );

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
) values
  (
    '59220000-0000-4000-8000-000000000001',
    '59210000-0000-4000-8000-000000000001',
    'common', 'common', 'Common / All Buildings', true, true
  ),
  (
    '59220000-0000-4000-8000-000000000002',
    '59210000-0000-4000-8000-000000000002',
    'common', 'common', 'Common / All Buildings', true, true
  ),
  (
    '59220000-0000-4000-8000-000000000003',
    '59210000-0000-4000-8000-000000000001',
    'building', 'b1', 'Building 1', false, false
  ),
  (
    '59220000-0000-4000-8000-000000000004',
    '59210000-0000-4000-8000-000000000003',
    'common', 'common', 'Common / All Buildings', true, true
  );

insert into public.v1_workforce_internal_locations (
  id, location_code, location_name, department, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values
  (
    '59225000-0000-4000-8000-000000000001', 'T04-WORKSHOP',
    'Main Workshop', 'Workshop / CC-100', true,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59225000-0000-4000-8000-000000000002', 'T04-OLD-STORE',
    'Old Store', 'Stores / CC-200', false,
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_project_members (
  id, project_id, member_auth_user_id, project_role, reason,
  assigned_by_auth_user_id, assigned_by_role
) values (
  '59226000-0000-4000-8000-000000000001',
  '59210000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002', 'site_engineer',
  'Technical membership is not Workforce timesheet authority',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, default_project_id, default_project_scope_id,
  valid_from, valid_to, is_active, created_by_auth_user_id,
  updated_by_auth_user_id
) values (
  '59230000-0000-4000-8000-000000000001', 'WF-T04-TEAM-A',
  'T04 Authorized Team', '59210000-0000-4000-8000-000000000001',
  '59220000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_workers (
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status, created_by_auth_user_id,
  updated_by_auth_user_id
) values
  (
    '59240000-0000-4000-8000-000000000001', 'WF-T04-WORKER-A',
    'T04 Authorized Worker', 'Ductman', 'Yorks AC & Ref.',
    'yorks_employee', '2026-01-01', 'active',
    '10000000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59240000-0000-4000-8000-000000000002', 'WF-T04-WORKER-ZERO',
    'T04 Absent Worker', 'Helper', 'Yorks AC & Ref.',
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
    '59250000-0000-4000-8000-000000000001',
    '59240000-0000-4000-8000-000000000001', 'primary',
    '59230000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59210000-0000-4000-8000-000000000001',
    '59220000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T04 retained assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '59250000-0000-4000-8000-000000000002',
    '59240000-0000-4000-8000-000000000002', 'primary',
    '59230000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001',
    '59210000-0000-4000-8000-000000000001',
    '59220000-0000-4000-8000-000000000001',
    '2026-01-01', '2027-12-31', 'T04 absent assignment',
    '10000000-0000-4000-8000-000000000004', 'admin',
    '10000000-0000-4000-8000-000000000004'
  );

insert into public.v1_workforce_calendars (
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59260000-0000-4000-8000-000000000001', 'WF-T04-CAL',
  'T04 Dubai Calendar', 'Asia/Dubai', 480, 60,
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays (
  calendar_id, iso_weekday, day_type, created_by_auth_user_id,
  updated_by_auth_user_id
)
select
  '59260000-0000-4000-8000-000000000001'::uuid, weekday,
  case when weekday = 7 then 'weekly_off' else 'regular_working_day' end,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_shift_templates (
  id, shift_code, shift_name, shift_kind, start_time, end_time,
  scheduled_minutes, break_minutes, work_date_basis, valid_from, valid_to,
  is_active, created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59270000-0000-4000-8000-000000000001', 'WF-T04-NIGHT',
  'T04 Night Shift', 'night', '20:00', '04:00', 480, 60,
  'shift_start_date', '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_team_schedule_links (
  id, team_id, calendar_id, shift_template_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '59280000-0000-4000-8000-000000000001',
  '59230000-0000-4000-8000-000000000001',
  '59260000-0000-4000-8000-000000000001',
  '59270000-0000-4000-8000-000000000001',
  '2026-01-01', '2027-12-31', 'T04 retained schedule',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59240000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"T04 parent present day"}'::jsonb,
    null, '59290000-0000-4000-8000-000000000001'
  )$sql$,
  'Admin creates the exact present parent attendance day'
);
select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59240000-0000-4000-8000-000000000002","work_date":"2026-08-30","attendance_status":"absent","regular_minutes":0,"overtime_minutes":0,"reason":"T04 zero-time parent day"}'::jsonb,
    null, '59290000-0000-4000-8000-000000000002'
  )$sql$,
  'Admin creates the zero-time parent used for rejection proof'
);

reset role;
create temporary table t04_attendance_ids (
  fixture_key text primary key,
  day_id uuid not null
) on commit drop;
grant select on pg_temp.t04_attendance_ids to authenticated;
insert into pg_temp.t04_attendance_ids (fixture_key, day_id)
select 'a', id from public.v1_workforce_attendance_days
where worker_id = '59240000-0000-4000-8000-000000000001'
union all
select 'z', id from public.v1_workforce_attendance_days
where worker_id = '59240000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $sql$select * from public.v1_workforce_timesheet_allocations$sql$,
  '42501', 'permission denied for table v1_workforce_timesheet_allocations',
  'Authenticated callers cannot read private allocation rows'
);
select throws_ok(
  $sql$select public.v1_workforce_timesheet_target_authority(
    'workforce.view','2026-08-30','project_work',
    '59210000-0000-4000-8000-000000000001',
    '59220000-0000-4000-8000-000000000001',null
  )$sql$,
  '42501', 'permission denied for function v1_workforce_timesheet_target_authority',
  'Authenticated callers cannot invoke the internal target helper'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Unknown payload',
      'allocations','[]'::jsonb,'unexpected',true
    ),null,'59291000-0000-4000-8000-000000000090'
  )$sql$,
  '22023',
  'V1_UNKNOWN_SAVE_WORKFORCE_TIMESHEET_ALLOCATIONS_PAYLOAD_FIELDS: unexpected',
  'Unknown top-level payload keys fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Unknown line payload',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60,'unexpected',true
      ))
    ),null,'59291000-0000-4000-8000-000000000087'
  )$sql$,
  '22023',
  'V1_UNKNOWN_SAVE_WORKFORCE_TIMESHEET_ALLOCATION_ITEM_FIELDS: unexpected',
  'Unknown allocation-row payload keys fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='z'),
      'attendance_record_version',1,'reason','Absent allocation invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',1,'overtime_minutes',0
      ))
    ),null,'59291000-0000-4000-8000-000000000091'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_PRESENT_ATTENDANCE_REQUIRED',
  'Absent and leave-like zero-time days cannot carry work allocations'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Mixed target invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'internal_location_id','59225000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000092'
  )$sql$,
  '22023','V1_WORKFORCE_TIMESHEET_INPUT_INVALID',
  'Project and internal target shapes are mutually exclusive'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Cross project invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000002',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000093'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED',
  'A Building/Common scope from another project is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Inactive target invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000003',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000094'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED',
  'An inactive project scope is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Inactive project invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000003',
        'project_scope_id','59220000-0000-4000-8000-000000000004',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000099'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED',
  'An inactive project is rejected even when its scope remains active'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Inactive internal target invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000002',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000089'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED',
  'An inactive internal Yorks location is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Missing target invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000099',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000088'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_ACTIVE_TARGET_REQUIRED',
  'A missing allocation target is rejected'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Fraction invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',479.5,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000095'
  )$sql$,
  '22023','V1_WORKFORCE_TIMESHEET_INPUT_INVALID',
  'Fractional allocation minutes fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Negative minutes invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',-1,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000086'
  )$sql$,
  '22023','V1_WORKFORCE_TIMESHEET_INPUT_INVALID',
  'Negative allocation minutes fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Daily bound invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',1441,'overtime_minutes',0
      ))
    ),null,'59291000-0000-4000-8000-000000000085'
  )$sql$,
  '22023','V1_WORKFORCE_TIMESHEET_INPUT_INVALID',
  'Allocation minutes above the 1,440-minute day bound fail closed'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Mismatch invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',479,'overtime_minutes',60
      ))
    ),null,'59291000-0000-4000-8000-000000000096'
  )$sql$,
  '23514','V1_WORKFORCE_TIMESHEET_MINUTES_MISMATCH',
  'Regular and overtime sums reconcile separately to the parent'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Partial range invalid',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60,'start_time','20:00'
      ))
    ),null,'59291000-0000-4000-8000-000000000097'
  )$sql$,
  '22023','V1_WORKFORCE_TIMESHEET_TIME_RANGE_INVALID',
  'A supporting time range must be a complete pair'
);

select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Overlap invalid',
      'allocations',jsonb_build_array(
        jsonb_build_object(
          'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
          'project_scope_id','59220000-0000-4000-8000-000000000001',
          'regular_minutes',240,'overtime_minutes',30,'start_time','20:00','end_time','01:00'
        ),
        jsonb_build_object(
          'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000001',
          'regular_minutes',240,'overtime_minutes',30,'start_time','00:30','end_time','04:00'
        )
      )
    ),null,'59291000-0000-4000-8000-000000000098'
  )$sql$,
  '23P01','V1_WORKFORCE_TIMESHEET_TIME_OVERLAP',
  'Calendar-local cross-midnight ranges cannot overlap'
);

select lives_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Initial reviewed allocation set',
      'allocations',jsonb_build_array(
        jsonb_build_object(
          'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
          'project_scope_id','59220000-0000-4000-8000-000000000001',
          'activity_task','Duct installation','regular_minutes',300,'overtime_minutes',30,
          'start_time','20:00','end_time','01:00'
        ),
        jsonb_build_object(
          'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000001',
          'activity_task','Workshop fabrication','regular_minutes',180,'overtime_minutes',30,
          'start_time','01:00','end_time','04:00'
        )
      )
    ),null,'59291000-0000-4000-8000-000000000001'
  )$sql$,
  'Admin can save mixed explicit project and internal allocations with adjacent ranges'
);

select is(
  public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Initial reviewed allocation set',
      'allocations',jsonb_build_array(
        jsonb_build_object(
          'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
          'project_scope_id','59220000-0000-4000-8000-000000000001',
          'activity_task','Duct installation','regular_minutes',300,'overtime_minutes',30,
          'start_time','20:00','end_time','01:00'
        ),
        jsonb_build_object(
          'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000001',
          'activity_task','Workshop fabrication','regular_minutes',180,'overtime_minutes',30,
          'start_time','01:00','end_time','04:00'
        )
      )
    ),null,'59291000-0000-4000-8000-000000000001'
  ),
  public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Initial reviewed allocation set',
      'allocations',jsonb_build_array(
        jsonb_build_object(
          'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
          'project_scope_id','59220000-0000-4000-8000-000000000001',
          'activity_task','Duct installation','regular_minutes',300,'overtime_minutes',30,
          'start_time','20:00','end_time','01:00'
        ),
        jsonb_build_object(
          'target_kind','internal_work','internal_location_id','59225000-0000-4000-8000-000000000001',
          'activity_task','Workshop fabrication','regular_minutes',180,'overtime_minutes',30,
          'start_time','01:00','end_time','04:00'
        )
      )
    ),null,'59291000-0000-4000-8000-000000000001'
  ),
  'An identical idempotent retry returns the exact authoritative response'
);

reset role;
create temporary table t04_allocation_set_ids (
  fixture_key text primary key,
  allocation_set_id uuid not null
) on commit drop;
insert into pg_temp.t04_allocation_set_ids (
  fixture_key, allocation_set_id
)
select 'a', allocation_set.id
from public.v1_workforce_timesheet_allocation_sets allocation_set
where allocation_set.attendance_day_id = (
  select day_id from pg_temp.t04_attendance_ids where fixture_key = 'a'
);
grant select on pg_temp.t04_allocation_set_ids to authenticated;

select is(
  (select count(*)
   from public.v1_workforce_timesheet_allocation_revisions revision
   where revision.allocation_set_id = (
     select allocation_set_id
     from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
   )),
  1::bigint,
  'Initial save and retry create one immutable allocation revision'
);
select is(
  (select count(*)
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
     select allocation_set_id
     from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
   )),
  2::bigint,
  'The authoritative active revision contains both reviewed allocations'
);
select is(
  (select count(*) from public.v1_audit_events event
   where event.event_type = 'workforce_timesheet_allocations_saved'
     and event.entity_id = (
       select allocation_set_id
       from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
     )
     and event.idempotency_key = '59291000-0000-4000-8000-000000000001'),
  1::bigint,
  'Initial save and retry emit one audit effect'
);
select ok(
  (select bool_and(
    allocation.interval_end_at > allocation.interval_start_at
    and allocation.crosses_midnight =
      (allocation.end_time_local < allocation.start_time_local)
  )
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
     select allocation_set_id
     from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
   )),
  'Intervals resolve in the retained timezone and preserve cross-midnight meaning'
);
select is(
  (select department_cost_centre_snapshot
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
       select allocation_set_id
       from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
     )
     and allocation.target_kind = 'internal_work'),
  'Workshop / CC-100',
  'Internal allocation retains Department and Cost Centre meaning'
);

set local role authenticated;
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59240000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":50,"reason":"Must be blocked by active allocations"}'::jsonb,
    1,'59291000-0000-4000-8000-000000000010'
  )$sql$,
  '40001','V1_WORKFORCE_ATTENDANCE_ACTIVE_ALLOCATIONS',
  'An active allocation set blocks attendance correction'
);
select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Different payload',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),2,'59291000-0000-4000-8000-000000000001'
  )$sql$,
  '22023','V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same idempotency key rejects a different allocation payload'
);
select throws_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',1,'reason','Stale set version',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),99,'59291000-0000-4000-8000-000000000011'
  )$sql$,
  '40001','V1_WORKFORCE_TIMESHEET_VERSION_CONFLICT',
  'A stale set version cannot append a revision'
);

reset role;
update public.v1_projects
set name = 'Renamed mutable project parent', record_version = record_version + 1
where id = '59210000-0000-4000-8000-000000000001';
update public.v1_workforce_internal_locations
set location_name = 'Renamed mutable workshop', department = 'Changed / CC-999',
    record_version = record_version + 1
where id = '59225000-0000-4000-8000-000000000001';
select is(
  (select allocation.project_name_snapshot
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
       select allocation_set_id
       from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
     )
     and allocation.target_kind = 'project_work'),
  'Workforce T04 authorized project',
  'Project target snapshot does not drift when its parent changes'
);
select is(
  (select allocation.department_cost_centre_snapshot
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
       select allocation_set_id
       from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
     )
     and allocation.target_kind = 'internal_work'),
  'Workshop / CC-100',
  'Internal target snapshot does not drift when its parent changes'
);

select throws_ok(
  $sql$delete from public.v1_workforce_timesheet_allocations allocation
       where allocation.id = (
         select candidate.id
         from public.v1_workforce_timesheet_allocations candidate
         join public.v1_workforce_timesheet_allocation_revisions revision
           on revision.id = candidate.allocation_revision_id
         where revision.allocation_set_id = (
           select allocation_set_id
           from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
         )
         order by candidate.id
         limit 1
       )$sql$,
  '42501','V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Allocation rows cannot be hard-deleted'
);
select throws_ok(
  $sql$update public.v1_workforce_timesheet_allocation_revisions
       set reason = 'rewrite'
       where allocation_set_id = (
         select allocation_set_id
         from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
       )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_HISTORY_IMMUTABLE',
  'Allocation revisions cannot be rewritten'
);
select throws_ok(
  $sql$delete from public.v1_workforce_timesheet_allocation_sets
       where id = (
         select allocation_set_id
         from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
       )$sql$,
  '42501','V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Allocation sets cannot be hard-deleted'
);

-- Project Engineer starts role-only, then receives explicit project permission
-- plus separate worker and target responsibility assignments.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Role is not authority',2,'59291000-0000-4000-8000-000000000020'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'Exact Project Engineer role alone cannot maintain timesheets'
);

reset role;
insert into public.v1_permission_assignments (
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values
  (
    '592a0000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001','workforce.view',
    'grant','project','permission_management','2026-01-01',
    'T04 project view grant','10000000-0000-4000-8000-000000000004'
  ),
  (
    '592a0000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001','workforce.timesheets.maintain',
    'grant','project','permission_management','2026-01-01',
    'T04 project timesheet grant','10000000-0000-4000-8000-000000000004'
  ),
  (
    '592a0000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000002','workforce.view',
    'grant','organization','permission_management','2026-01-01',
    'Capability without responsibility','10000000-0000-4000-8000-000000000004'
  ),
  (
    '592a0000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000002','workforce.timesheets.maintain',
    'grant','organization','permission_management','2026-01-01',
    'Capability without responsibility','10000000-0000-4000-8000-000000000004'
  ),
  (
    '592a0000-0000-4000-8000-000000000005',
    '10000000-0000-4000-8000-000000000009','workforce.view',
    'grant','organization','permission_management','2026-01-01',
    'Expired capability','10000000-0000-4000-8000-000000000004'
  ),
  (
    '592a0000-0000-4000-8000-000000000006',
    '10000000-0000-4000-8000-000000000009','workforce.timesheets.maintain',
    'grant','organization','permission_management','2026-01-01',
    'Expired capability','10000000-0000-4000-8000-000000000004'
  );
insert into public.v1_permission_assignment_projects (assignment_id, project_id)
values
  ('592a0000-0000-4000-8000-000000000001','59210000-0000-4000-8000-000000000001'),
  ('592a0000-0000-4000-8000-000000000002','59210000-0000-4000-8000-000000000001');
update public.v1_permission_assignments
set effective_until = '2026-08-01'
where id in (
  '592a0000-0000-4000-8000-000000000005',
  '592a0000-0000-4000-8000-000000000006'
);

insert into public.v1_workforce_responsibility_assignments (
  id, auth_user_id, scope_kind, worker_id, project_id, project_scope_id,
  valid_from, valid_to, reason, assigned_by_auth_user_id,
  assigned_by_exact_role, updated_by_auth_user_id
) values
  (
    '592b0000-0000-4000-8000-000000000001',
    '10000000-0000-4000-8000-000000000001','worker',
    '59240000-0000-4000-8000-000000000001',null,null,
    '2026-01-01','2027-12-31','T04 retained-worker responsibility',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '592b0000-0000-4000-8000-000000000002',
    '10000000-0000-4000-8000-000000000001','project_scope',null,
    '59210000-0000-4000-8000-000000000001',
    '59220000-0000-4000-8000-000000000001',
    '2026-01-01','2027-12-31','T04 explicit target responsibility',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '592b0000-0000-4000-8000-000000000003',
    '10000000-0000-4000-8000-000000000003','organization',null,null,null,
    '2026-01-01','2027-12-31','Responsibility without capability',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004'
  ),
  (
    '592b0000-0000-4000-8000-000000000004',
    '10000000-0000-4000-8000-000000000009','organization',null,null,null,
    '2026-01-01','2027-12-31','Expired capability responsibility',
    '10000000-0000-4000-8000-000000000004','admin',
    '10000000-0000-4000-8000-000000000004'
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Capability without responsibility',2,'59291000-0000-4000-8000-000000000021'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'Site Engineer capability and technical membership without responsibility fail closed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Responsibility without capability',2,'59291000-0000-4000-8000-000000000022'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'Procurement responsibility without capability fails closed'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Expired capability',2,'59291000-0000-4000-8000-000000000023'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'An expired capability fails closed despite organization responsibility'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $sql$select public.v1_get_workforce_timesheet_allocations(
    '2026-08-30','59240000-0000-4000-8000-000000000001'
  )$sql$,
  'A capability-plus-worker-plus-target-responsibility maintainer can read in scope'
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
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Inactive actor',2,'59291000-0000-4000-8000-000000000026'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'An inactive actor immediately loses timesheet mutation authority'
);

reset role;
update auth.users set banned_until = null
where id = '10000000-0000-4000-8000-000000000001';
update public.v1_permission_assignments
set effective_until = clock_timestamp() - interval '1 second'
where id = '592a0000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Revoked capability',2,'59291000-0000-4000-8000-000000000027'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'A revoked timesheet capability immediately removes mutation authority'
);

reset role;
update public.v1_permission_assignments set effective_until = null
where id = '592a0000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Internal target remains unauthorized',2,'59291000-0000-4000-8000-000000000024'
  )$sql$,
  '42501','V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'Worker and project target scope do not authorize an internal target'
);

-- Admin withdraws the mixed set, then the scoped Project Engineer saves an
-- exact project-only revision. This also proves timesheet withdrawal does not
-- change attendance and releases the active-child correction guard.
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $sql$select public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Withdraw before attendance correction',2,
    '59291000-0000-4000-8000-000000000002'
  )$sql$,
  'Admin can append a zero-line withdrawal revision'
);
select is(
  public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Withdraw before attendance correction',2,
    '59291000-0000-4000-8000-000000000002'
  ),
  public.v1_withdraw_workforce_timesheet_allocations(
    (select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
    'Withdraw before attendance correction',2,
    '59291000-0000-4000-8000-000000000002'
  ),
  'Withdrawal retry is idempotent'
);
select lives_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59240000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"Correction after explicit withdrawal"}'::jsonb,
    1,'59291000-0000-4000-8000-000000000025'
  )$sql$,
  'Attendance correction is released only after explicit withdrawal'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $sql$select public.v1_save_workforce_timesheet_allocations(
    jsonb_build_object(
      'attendance_day_id',(select day_id from pg_temp.t04_attendance_ids where fixture_key='a'),
      'attendance_record_version',2,'reason','Scoped project-only revision',
      'allocations',jsonb_build_array(jsonb_build_object(
        'target_kind','project_work','project_id','59210000-0000-4000-8000-000000000001',
        'project_scope_id','59220000-0000-4000-8000-000000000001',
        'regular_minutes',480,'overtime_minutes',60
      ))
    ),3,'59291000-0000-4000-8000-000000000003'
  )$sql$,
  'A fully scoped maintainer can append the next project-only revision'
);
select is(
  jsonb_array_length(
    public.v1_get_workforce_timesheet_allocations(
      '2026-08-30','59240000-0000-4000-8000-000000000001'
    ) -> 'timesheet_days'
  ),
  1,
  'The scoped maintainer reads the authoritative project-only allocation set'
);
select throws_ok(
  $sql$select public.v1_save_workforce_attendance_day(
    '{"worker_id":"59240000-0000-4000-8000-000000000001","work_date":"2026-08-30","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"Timesheet authority is not attendance authority"}'::jsonb,
    2,'59291000-0000-4000-8000-000000000028'
  )$sql$,
  '42501','V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'Timesheet-only authority cannot correct the parent attendance day'
);

reset role;
select is(
  (select count(*)
   from public.v1_workforce_timesheet_allocation_revisions revision
   where revision.allocation_set_id = (
     select allocation_set_id
     from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
   )),
  3::bigint,
  'Save, withdrawal and re-save preserve three immutable revisions'
);
select is(
  (select count(*)
   from public.v1_workforce_timesheet_allocations allocation
   join public.v1_workforce_timesheet_allocation_revisions revision
     on revision.id = allocation.allocation_revision_id
   where revision.allocation_set_id = (
     select allocation_set_id
     from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
   )),
  3::bigint,
  'Withdrawal sheds no historical allocation rows and re-save appends one row'
);
select is(
  (select count(*) from public.v1_audit_events event
   where event.entity_type = 'workforce_timesheet_allocation_set'
     and event.entity_id = (
       select allocation_set_id
       from pg_temp.t04_allocation_set_ids where fixture_key = 'a'
     )),
  3::bigint,
  'Each committed allocation transition emits exactly one audit event'
);
select is(
  (select count(*) from public.v1_idempotency_keys key
   where key.command_name in (
     'v1_save_workforce_timesheet_allocations',
     'v1_withdraw_workforce_timesheet_allocations'
   )
     and key.idempotency_key = any(array[
       '59291000-0000-4000-8000-000000000001'::uuid,
       '59291000-0000-4000-8000-000000000002'::uuid,
       '59291000-0000-4000-8000-000000000003'::uuid
     ])
     and key.completed_at is not null),
  3::bigint,
  'Each committed T04 transition has one completed idempotency effect'
);

select * from finish();
rollback;
