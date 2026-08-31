begin;

create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select ok(has_function_privilege('authenticated',
    'public.v1_get_workforce_overview(jsonb)','execute'),
  'Authenticated callers receive the intended T10 read boundary');
select ok(not has_function_privilege('authenticated',
    'public.v1_workforce_t10_team_contexts()','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_team_authorized(jsonb,text)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_organization_authorized(text)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_period_authorized(text,uuid,boolean)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_period_matches_project(uuid,uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_team_matches_project(jsonb,uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_team_metrics(jsonb)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t10_review_queue_item(uuid)','execute'),
  'T10 SECURITY DEFINER helpers are non-callable');

insert into public.v1_projects(id,project_ref,name,state,current_action_owner_role,
  created_by_auth_user_id,created_by_role) values(
  '59d10000-0000-4000-8000-000000000001','WF-T10','T10 Dashboard Project',
  'active','project_engineer','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,
  is_immutable,is_active) values('59d20000-0000-4000-8000-000000000001',
  '59d10000-0000-4000-8000-000000000001','common','common',
  'Common / All Buildings',true,true);

insert into public.v1_workforce_teams(id,team_code,team_name,
  default_supervisor_auth_user_id,default_project_id,default_project_scope_id,
  valid_from,valid_to,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values
('59d30000-0000-4000-8000-000000000001','WF-T10-DXB','T10 Dubai Team',
  '10000000-0000-4000-8000-000000000004',
  '59d10000-0000-4000-8000-000000000001',
  '59d20000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),
('59d30000-0000-4000-8000-000000000002','WF-T10-KIR','T10 Kiritimati Team',
  null,'59d10000-0000-4000-8000-000000000001',
  '59d20000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

insert into public.v1_workforce_calendars(id,calendar_code,calendar_name,
  timezone_name,standard_scheduled_minutes,break_minutes,valid_from,valid_to,
  is_active,created_by_auth_user_id,updated_by_auth_user_id) values
('59d60000-0000-4000-8000-000000000001','WF-T10-DXB','T10 Dubai Calendar',
  'Asia/Dubai',480,60,'2026-01-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),
('59d60000-0000-4000-8000-000000000002','WF-T10-KIR',
  'T10 Kiritimati Calendar','Pacific/Kiritimati',480,60,
  '2026-01-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendar_weekdays(calendar_id,iso_weekday,
  day_type,created_by_auth_user_id,updated_by_auth_user_id)
select calendar_id,weekday,'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from unnest(array[
  '59d60000-0000-4000-8000-000000000001'::uuid,
  '59d60000-0000-4000-8000-000000000002'::uuid
]) calendar_id cross join generate_series(1,7) weekday;
insert into public.v1_workforce_team_schedule_links(id,team_id,calendar_id,
  valid_from,valid_to,reason,created_by_auth_user_id,updated_by_auth_user_id)
values
('59d70000-0000-4000-8000-000000000001',
  '59d30000-0000-4000-8000-000000000001',
  '59d60000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 Dubai schedule','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),
('59d70000-0000-4000-8000-000000000002',
  '59d30000-0000-4000-8000-000000000002',
  '59d60000-0000-4000-8000-000000000002','2026-01-01','2027-12-31',
  'T10 Kiritimati schedule','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,current_status,
  created_by_auth_user_id,updated_by_auth_user_id)
select md5('t10-worker-'||number)::uuid, 'T10-'||lpad(number::text,4,'0'),
  'T10 Worker '||number,'Technician','Yorks AC & Ref.','yorks_employee',
  '2026-01-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1,502) number;
insert into public.v1_workforce_worker_assignments(id,worker_id,assignment_kind,
  team_id,supervisor_auth_user_id,project_id,project_scope_id,valid_from,valid_to,
  reason,assigned_by_auth_user_id,assigned_by_exact_role,
  updated_by_auth_user_id)
select md5('t10-assignment-'||number)::uuid,
  md5('t10-worker-'||number)::uuid,'primary',
  '59d30000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004',
  '59d10000-0000-4000-8000-000000000001',
  '59d20000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 effective assignment','10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1,502) number;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"admin"}')$$,'42501','V1_WORKFORCE_T10_READ_DENIED',
  'Exact Admin role and capability without organization responsibility is denied');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management"}')$$,'42501',
  'V1_WORKFORCE_T10_READ_DENIED',
  'Exact Project Manager role alone grants no Management data');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management"}')$$,'42501',
  'V1_WORKFORCE_T10_READ_DENIED',
  'Exact Senior Mechanical Engineer role alone grants no Management data');
reset role;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,
  effect,scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
('59da0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001','workforce.view','grant','project',
  'permission_management','2026-01-01','T10 Project Engineer view',
  '10000000-0000-4000-8000-000000000004'),
('59da0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000001',
  'workforce.attendance.maintain','grant','project','permission_management',
  '2026-01-01','T10 Project Engineer attendance',
  '10000000-0000-4000-8000-000000000004'),
('59da0000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000010','workforce.view','grant','project',
  'permission_management','2026-01-01','T10 Project Manager view',
  '10000000-0000-4000-8000-000000000004'),
('59da0000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000009','workforce.view','grant','project',
  'permission_management','2026-01-01','T10 SME view',
  '10000000-0000-4000-8000-000000000004'),
('59da0000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000002','workforce.view','grant','project',
  'permission_management','2026-01-01','T10 capability-only Site Engineer',
  '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update
set effective_from=excluded.effective_from,
  effective_until=null,
  reason=excluded.reason,
  version=public.v1_permission_assignments.version+1,
  changed_by_auth_user_id=excluded.changed_by_auth_user_id,
  updated_at=clock_timestamp();
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select assignment.id,'59d10000-0000-4000-8000-000000000001'
from public.v1_permission_assignments assignment
join (values
  ('10000000-0000-4000-8000-000000000001'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000001'::uuid,
    'workforce.attendance.maintain'),
  ('10000000-0000-4000-8000-000000000010'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000009'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.view')
) required(auth_user_id,capability_key)
  on required.auth_user_id=assignment.auth_user_id
 and required.capability_key=assignment.capability_key
where assignment.scope_kind='project' and assignment.effect='grant'
on conflict do nothing;

-- Retained concurrency fixtures may already carry non-overlapping Admin
-- organization windows. Move those fixtures into deterministic historical
-- one-day slots inside this transaction before creating the T10 controlled
-- window; rollback restores their original evidence.
with existing as (
  select responsibility.id,
    row_number() over(order by responsibility.id)::integer as ordinal
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.auth_user_id=
      '10000000-0000-4000-8000-000000000004'
    and responsibility.scope_kind='organization'
)
update public.v1_workforce_responsibility_assignments responsibility
set valid_from=date '1800-01-01'+(existing.ordinal*2),
  valid_to=date '1800-01-01'+(existing.ordinal*2),
  record_version=responsibility.record_version+1,
  updated_by_auth_user_id='10000000-0000-4000-8000-000000000004',
  updated_at=clock_timestamp()
from existing
where responsibility.id=existing.id;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values
('59db0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001','project',
  '59d10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 Project Engineer responsibility',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'),
('59db0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000010','project',
  '59d10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 Project Manager responsibility',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'),
('59db0000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000009','project',
  '59d10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 SME responsibility','10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'),
('59db0000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000003','project',
  '59d10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T10 Procurement responsibility-only negative',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'),
('59db0000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000004','organization',null,
  '2020-01-01','2035-12-31','T10 Admin organization responsibility',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok(format($query$select public.v1_save_workforce_attendance_day(
  jsonb_build_object('worker_id','%s','work_date','%s','attendance_status','present',
    'regular_minutes',480,'overtime_minutes',0,'reason','T10 accepted today'),
  null,'59dc0000-0000-4000-8000-000000000001')$query$,
  md5('t10-worker-1')::uuid,
  (statement_timestamp() at time zone 'Asia/Dubai')::date),
  'Accepted T03 command creates one local-today attendance fact');
reset role;
create temp table t10_read_effect_baseline as
select
  (select count(*) from public.v1_audit_events) as audit_count,
  (select count(*) from public.v1_notifications) as notification_count,
  (select count(*) from public.v1_workforce_notification_deliveries)
    as delivery_count,
  (select count(*) from public.v1_workforce_monthly_transitions)
    as transition_count,
  (select count(*) from public.v1_workforce_report_artifacts) as report_count;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,
  effect,scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
values('59da0000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000004','workforce.view','deny',
  'organization','permission_management','2026-01-01',
  'T10 Admin responsibility without capability',
  '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update
set effective_from=excluded.effective_from,
  effective_until=null,
  reason=excluded.reason,
  version=public.v1_permission_assignments.version+1,
  changed_by_auth_user_id=excluded.changed_by_auth_user_id,
  updated_at=clock_timestamp();
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"admin"}')$$,'42501','V1_WORKFORCE_T10_READ_DENIED',
  'Admin organization responsibility without effective Workforce view is denied');
reset role;
update public.v1_permission_assignments
set effective_until='2026-01-02'
where auth_user_id='10000000-0000-4000-8000-000000000004'
  and capability_key='workforce.view' and scope_kind='organization'
  and effect='deny';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is(public.v1_get_workforce_overview('{"overview_kind":"admin"}')
  ->> 'authorization_mode','enforced_t10',
  'Admin receives the fixed T10 authorization contract');
select is(public.v1_get_workforce_overview('{"overview_kind":"admin"}')
  ->> 'as_of_mode','calendar_local_by_team',
  'Admin response declares calendar-local team dates');
select is(jsonb_array_length(public.v1_get_workforce_overview(
    '{"overview_kind":"admin"}') -> 'as_of_groups'),2,
  'Extreme calendar timezones remain explicit as two as-of groups');
select is((public.v1_get_workforce_overview('{"overview_kind":"admin"}')
    #>> '{summary,missing_today_count}')::integer,501,
  'Admin missing-today aggregation covers all 502 workers beyond one page');
select cmp_ok((public.v1_get_workforce_overview('{"overview_kind":"admin"}')
    #>> '{summary,configuration_issue_count}')::integer,'>=',1,
  'Admin surfaces the missing-supervisor configuration issue');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select is((public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor","team_id":"59d30000-0000-4000-8000-000000000001"}')
    #>> '{summary,worker_count}')::integer,502,
  'Scoped Project Engineer receives the complete Supervisor team population');
select is(public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor","team_id":"59d30000-0000-4000-8000-000000000001"}')
    #>> '{summary,today_completion_percent}','0.2',
  'Today completion is entered attendance over the complete roster');
select is(public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor","team_id":"59d30000-0000-4000-8000-000000000001"}')
    #>> '{action_flags,can_complete_today_attendance}','true',
  'Attendance action requires and reflects exact maintain capability and scope');
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor","team_id":"59d30000-0000-4000-8000-000000000099"}')$$,
  '42501','V1_WORKFORCE_T10_READ_DENIED',
  'A guessed or unauthorized team ID discloses no Supervisor summary');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select is(jsonb_array_length(public.v1_get_workforce_overview(
    '{"overview_kind":"management"}') -> 'projects'),1,
  'Scoped Project Manager receives one active authorized project summary');
select is((public.v1_get_workforce_overview('{"overview_kind":"management"}')
    #>> '{summary,worker_count}')::integer,502,
  'Management summary deduplicates and counts the complete project workforce');
select is(public.v1_get_workforce_overview('{"overview_kind":"management"}')
    #>> '{policies,overtime_limit}','not_configured',
  'Management does not invent an overtime exception threshold');
select is(public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor"}')
    #>> '{action_flags,can_complete_today_attendance}','false',
  'Workforce view responsibility alone never advertises attendance mutation');
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000099"}')$$,
  '42501','V1_WORKFORCE_T10_READ_DENIED',
  'A guessed or unauthorized project ID discloses no Management summary');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',true);
select lives_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000001"}')$$,
  'Scoped SME receives the Management shape without role-derived data access');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')$$,'42501','V1_WORKFORCE_T10_READ_DENIED',
  'A Site Engineer capability without responsibility receives no dashboard');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')$$,'42501','V1_WORKFORCE_T10_READ_DENIED',
  'Procurement responsibility without Workforce view capability is denied');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values(
  '59db0000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000002','project',
  '59d10000-0000-4000-8000-000000000001','2020-01-01','2035-12-31',
  'T10 Site Engineer complete project responsibility',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select is((public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')#>>'{summary,worker_count}')::integer,502,
  'Site Engineer capability plus complete dated responsibility is positive');
reset role;
update public.v1_profiles set is_active=false
where auth_user_id='10000000-0000-4000-8000-000000000002';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')$$,'42501',
  'V1_WORKFORCE_T10_READ_DENIED','Inactive actor is denied');
reset role;
update public.v1_profiles set is_active=true
where auth_user_id='10000000-0000-4000-8000-000000000002';

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,
  effect,scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
values('59da0000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000003','workforce.view','grant',
  'project','permission_management','2026-01-01',
  'T10 Procurement complete view capability',
  '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update
set effective_from=excluded.effective_from,
  effective_until=null,
  reason=excluded.reason,
  version=public.v1_permission_assignments.version+1,
  changed_by_auth_user_id=excluded.changed_by_auth_user_id,
  updated_at=clock_timestamp();
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select assignment.id,'59d10000-0000-4000-8000-000000000001'
from public.v1_permission_assignments assignment
where assignment.auth_user_id='10000000-0000-4000-8000-000000000003'
  and assignment.capability_key='workforce.view'
  and assignment.scope_kind='project' and assignment.effect='grant'
on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select is((public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')#>>'{summary,worker_count}')::integer,502,
  'Procurement capability plus complete dated responsibility is positive');
reset role;
update public.v1_permission_assignments set effective_until='2026-01-02'
where auth_user_id='10000000-0000-4000-8000-000000000003'
  and capability_key='workforce.view' and scope_kind='project'
  and effect='grant';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')$$,'42501',
  'V1_WORKFORCE_T10_READ_DENIED','Revoked capability removes overview data');
reset role;

create temporary table t10_configuration_before(value integer) on commit drop;
insert into t10_configuration_before
select (public.v1_get_workforce_overview('{"overview_kind":"admin"}')
  #>>'{summary,configuration_issue_count}')::integer
from (select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true)) claims;
grant select on t10_configuration_before to authenticated;

insert into public.v1_projects(id,project_ref,name,state,
  current_action_owner_role,created_by_auth_user_id,created_by_role)
values('59d10000-0000-4000-8000-000000000002','WF-T10-HISTORY',
  'T10 Retained Closed Project','active','project_engineer',
  '10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,
  is_immutable,is_active) values
('59d20000-0000-4000-8000-000000000002',
  '59d10000-0000-4000-8000-000000000002','building','t10-retained-scope',
  'T10 Retained Building',false,true),
('59d20000-0000-4000-8000-000000000003',
  '59d10000-0000-4000-8000-000000000002','building','wrong-scope',
  'Wrong Scope',false,true);
insert into public.v1_workforce_internal_locations(id,location_code,
  location_name,department,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values(
  '59d25000-0000-4000-8000-000000000001','WF-T10-INTERNAL',
  'T10 Retained Internal Location','Operations / CC-T10',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,leaving_date,current_status,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '59d40000-0000-4000-8000-000000000001','T10-LEAVER',
  'T10 Retained Leaver','Technician','Yorks AC & Ref.','yorks_employee',
  '2025-01-01','2026-07-31','left_company',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

insert into public.v1_workforce_teams(id,team_code,team_name,valid_from,
  valid_to,is_active,created_by_auth_user_id,updated_by_auth_user_id)
select md5('t10-queue-team-'||number)::uuid,
  'WF-T10-Q-'||lpad(number::text,2,'0'),
  'T10 Retained Queue Team '||lpad(number::text,2,'0'),
  '2025-01-01','2026-07-31',case when number=2 then true else false end,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
from generate_series(2,55) number;

set constraints all deferred;
insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,
  record_version,created_by_auth_user_id,updated_by_auth_user_id,updated_at,
  current_approval_revision_number)
select md5('t10-queue-period-'||number)::uuid,
  case when number=1
    then '59d30000-0000-4000-8000-000000000002'::uuid
    else md5('t10-queue-team-'||number)::uuid end,
  '2026-07-01',md5('t10-queue-run-'||number)::uuid,1,
  case when number=55 then 'awaiting_final_approval' else 'submitted' end,
  2,'10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004',
  case when number=1 then '2025-01-01 00:00:00+00'::timestamptz
    else '2026-08-31 00:00:00+00'::timestamptz
      + number * interval '1 minute' end,
  1
from generate_series(1,55) number;
insert into public.v1_workforce_monthly_validation_runs(id,period_id,
  validation_number,validation_status,source_fingerprint,worker_count,
  date_count,warning_issue_count,authority_snapshot,
  validated_by_auth_user_id,validated_by_exact_role,idempotency_key)
select md5('t10-queue-run-'||number)::uuid,
  md5('t10-queue-period-'||number)::uuid,1,'ready_for_review',
  case when number in (1,55) then
    public.v1_workforce_monthly_source_fingerprint(
      case when number=1
        then '59d30000-0000-4000-8000-000000000002'::uuid
        else md5('t10-queue-team-'||number)::uuid end,
      '2026-07-01'
    ) else repeat('a',64) end,
  1,1,case when number=1 then 3 else 0 end,
  jsonb_build_object('fixture','t10-retained-queue','number',number),
  '10000000-0000-4000-8000-000000000004','admin',
  md5('t10-queue-idempotency-'||number)::uuid
from generate_series(1,55) number;
insert into public.v1_workforce_monthly_period_dates(id,validation_run_id,
  worker_id,work_date,is_future,is_required,day_type,daily_status,
  worker_snapshot,assignment_snapshot,allocation_snapshot,
  scheduled_minutes,regular_minutes,overtime_minutes,allocation_minutes,
  warning_issue_count)
select md5('t10-queue-date-'||number)::uuid,
  md5('t10-queue-run-'||number)::uuid,
  '59d40000-0000-4000-8000-000000000001','2026-07-15',false,true,
  'regular_working_day','has_warnings',
  jsonb_build_object('worker_id','59d40000-0000-4000-8000-000000000001',
    'worker_number','T10-LEAVER','worker_name','T10 Retained Leaver'),
  jsonb_build_object('team_id',case when number=1
      then '59d30000-0000-4000-8000-000000000002'::uuid
      else md5('t10-queue-team-'||number)::uuid end,
    'valid_from','2025-01-01','valid_to','2026-07-31',
    'supervisor_auth_user_id','10000000-0000-4000-8000-000000000004',
    'project_id','59d10000-0000-4000-8000-000000000002',
    'project_scope_id','59d20000-0000-4000-8000-000000000002',
    'internal_location_id',null),
  jsonb_build_object('allocation_state','active','targets',jsonb_build_array(
    jsonb_build_object('target_kind','project_work',
      'project_id','59d10000-0000-4000-8000-000000000002',
      'project_scope_id','59d20000-0000-4000-8000-000000000002'),
    jsonb_build_object('target_kind','internal_work',
      'internal_location_id','59d25000-0000-4000-8000-000000000001')
  )),480,480,0,480,case when number=1 then 3 else 0 end
from generate_series(1,55) number;
insert into public.v1_workforce_monthly_validation_issues(id,
  validation_run_id,worker_id,work_date,severity,issue_code,message_key,
  issue_context,sort_order) values
('59df0000-0000-4000-8000-000000000001',
  md5('t10-queue-run-1')::uuid,
  '59d40000-0000-4000-8000-000000000001','2026-07-15','warning',
  'overtime_limit_exceeded','workforce.monthly.issue.overtime_limit_exceeded',
  '{"configured_policy":"accepted-fixture"}',1),
('59df0000-0000-4000-8000-000000000002',
  md5('t10-queue-run-1')::uuid,
  '59d40000-0000-4000-8000-000000000001','2026-07-15','warning',
  'supporting_evidence_missing',
  'workforce.monthly.issue.supporting_evidence_missing',
  '{"configured_policy":"accepted-fixture"}',2),
('59df0000-0000-4000-8000-000000000003',
  md5('t10-queue-run-1')::uuid,null,null,'warning',
  'supervisor_invalid','workforce.monthly.issue.supervisor_invalid',
  '{"team_issue":"59d30000-0000-4000-8000-000000000002"}',3);
set constraints all immediate;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,
  effect,scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
values('59da0000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000010','workforce.view','grant',
  'organization','permission_management','2020-01-01',
  'T10 Project Manager organization capability with scoped responsibility',
  '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update
set effective_from=excluded.effective_from,
  effective_until=null,
  reason=excluded.reason,
  version=public.v1_permission_assignments.version+1,
  changed_by_auth_user_id=excluded.changed_by_auth_user_id,
  updated_at=clock_timestamp();
insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,team_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values(
  '59db0000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000010','team',
  md5('t10-queue-team-2')::uuid,'2020-01-01','2035-12-31',
  'T10 wrong retained team only',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}')$$,
  '42501','V1_WORKFORCE_T10_READ_DENIED',
  'Wrong retained team and project responsibility disclose no queue');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,project_scope_id,valid_from,valid_to,reason,
  assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
values('59db0000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000010','project_scope',
  '59d10000-0000-4000-8000-000000000002',
  '59d20000-0000-4000-8000-000000000003','2020-01-01','2035-12-31',
  'T10 wrong project scope only',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}')$$,
  '42501','V1_WORKFORCE_T10_READ_DENIED',
  'Wrong retained project scope remains denied');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,project_scope_id,valid_from,valid_to,reason,
  assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
values('59db0000-0000-4000-8000-000000000009',
  '10000000-0000-4000-8000-000000000010','project_scope',
  '59d10000-0000-4000-8000-000000000002',
  '59d20000-0000-4000-8000-000000000002','2020-01-01','2035-12-31',
  'T10 exact retained project scope',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}')$$,
  '42501','V1_WORKFORCE_T10_READ_DENIED',
  'Missing retained internal-location target responsibility remains denied');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,internal_location_id,valid_from,valid_to,reason,
  assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
values('59db0000-0000-4000-8000-000000000010',
  '10000000-0000-4000-8000-000000000010','internal_location',
  '59d25000-0000-4000-8000-000000000001','2020-01-01','2035-12-31',
  'T10 exact retained internal location',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
create temporary table t10_management_view_only(value jsonb) on commit drop;
insert into t10_management_view_only
select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}');
select is(jsonb_array_length((select value from t10_management_view_only)
  ->'review_queue'),50,
  'Compact Management queue is limited only after 55 authorized candidates');
select is(((select value from t10_management_view_only)
  #>>'{summary,review_queue_count}')::integer,54,
  'Full Management review count is not truncated to the compact page');
select is(((select value from t10_management_view_only)
  #>>'{summary,approval_queue_count}')::integer,1,
  'Full Management approval count is independent from the compact page');
select is((select value from t10_management_view_only)
  #>>'{review_queue,0,period_id}',md5('t10-queue-period-1')::uuid::text,
  'Older higher-priority typed exception precedes newer normal queue rows');
select is((select value from t10_management_view_only)
  #>>'{policies,overtime_limit}','typed_validation_issue',
  'Accepted typed overtime issue replaces the unconfigured zero state');
select is((select value from t10_management_view_only)
  #>>'{policies,supporting_evidence_requirement}','typed_validation_issue',
  'Accepted typed supporting-evidence issue replaces the unconfigured zero state');
select is(((select value from t10_management_view_only)
  #>>'{summary,overtime_exception_count}')::integer,1,
  'Typed overtime issues are counted across the full authorized queue');
select is((select value from t10_management_view_only)
  #>>'{action_flags,can_open_review_queue}','false',
  'View authority alone never advertises a review mutation');
reset role;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,
  effect,scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
('59da0000-0000-4000-8000-000000000009',
  '10000000-0000-4000-8000-000000000010',
  'workforce.timesheets.review','grant','organization',
  'permission_management','2020-01-01','T10 review queue command capability',
  '10000000-0000-4000-8000-000000000004'),
('59da0000-0000-4000-8000-000000000010',
  '10000000-0000-4000-8000-000000000010',
  'workforce.timesheets.final_approve','grant','organization',
  'permission_management','2020-01-01','T10 final queue command capability',
  '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update
set effective_from=excluded.effective_from,
  effective_until=null,
  reason=excluded.reason,
  version=public.v1_permission_assignments.version+1,
  changed_by_auth_user_id=excluded.changed_by_auth_user_id,
  updated_at=clock_timestamp();
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
create temporary table t10_management_mutation(value jsonb) on commit drop;
insert into t10_management_mutation
select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}');
select is((select value from t10_management_mutation)
  #>>'{action_flags,can_open_review_queue}','true',
  'Review action requires its exact capability and complete retained scope');
select is((select value from t10_management_mutation)
  #>>'{action_flags,can_open_final_approval_queue}','true',
  'Final action requires its exact capability and complete retained scope');
reset role;

update public.v1_workforce_teams set is_active=false
where id=md5('t10-queue-team-2')::uuid;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
create temporary table t10_admin_retained(value jsonb) on commit drop;
insert into t10_admin_retained
select public.v1_get_workforce_overview('{"overview_kind":"admin"}');
reset role;
select is(((select value from t10_admin_retained)
  #>>'{summary,configuration_issue_count}')::integer,
  (select value from t10_configuration_before),
  'Overlapping current and retained supervisor issue has one stable identity');
select is(jsonb_array_length((select value from t10_admin_retained)
  ->'review_queue'),12,
  'Admin queue applies its compact limit after full authorization and ordering');
select is((select value from t10_admin_retained)
  #>>'{review_queue,0,period_id}',md5('t10-queue-period-1')::uuid::text,
  'Admin retains the older higher-priority exception before recent normal rows');
select is(((select value from t10_admin_retained)
  #>>'{summary,monthly_pending_count}')::integer,
  (select count(*)::integer
    from public.v1_workforce_monthly_periods period
    where period.current_status in (
      'draft','ready_for_review','submitted','under_review','reopened'
    )),
  'Admin pending aggregate counts every authorized period, including valid retained fixtures, before compacting');
select is(((select value from t10_admin_retained)
  #>>'{summary,awaiting_final_count}')::integer,
  (select count(*)::integer
    from public.v1_workforce_monthly_periods period
    where period.current_status='awaiting_final_approval'),
  'Admin final aggregate counts the complete retained authorized candidate set');
select is((select value from t10_admin_retained)
  #>>'{policies,overtime_limit}','typed_validation_issue',
  'Admin policy state reflects retained typed overtime evidence');
select is((select value from t10_admin_retained)
  #>>'{action_flags,can_open_final_approval_queue}','true',
  'Admin final action still requires exact capability and retained scope');

update public.v1_workforce_teams
set default_project_id='59d10000-0000-4000-8000-000000000002',
  default_project_scope_id='59d20000-0000-4000-8000-000000000002'
where id='59d30000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
select is(public.v1_get_workforce_overview('{"overview_kind":"management"}')
  #>>'{projects,0,project_id}','59d10000-0000-4000-8000-000000000001',
  'Active project summary follows actual assignments, not the team default');
reset role;

update public.v1_projects set state='archived'
where id='59d10000-0000-4000-8000-000000000002';
update public.v1_project_scopes set is_active=false
where project_id='59d10000-0000-4000-8000-000000000002';
update public.v1_workforce_internal_locations set is_active=false
where id='59d25000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',true);
create temporary table t10_management_closed(value jsonb) on commit drop;
insert into t10_management_closed
select public.v1_get_workforce_overview(
  '{"overview_kind":"management","project_id":"59d10000-0000-4000-8000-000000000002"}');
select is(((select value from t10_management_closed)
  #>>'{summary,review_queue_count}')::integer,54,
  'Retained leaver and closed team/project/scope/location queue remains visible');
select is(jsonb_array_length((select value from t10_management_closed)
  ->'projects'),0,
  'Closed retained project is excluded only from current Active Projects');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"admin","unknown":true}')$$,'22023',
  'V1_WORKFORCE_T10_READ_INVALID','Unknown request keys fail closed');
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"management"}')$$,'42501','V1_WORKFORCE_T10_READ_DENIED',
  'Admin cannot relabel the organization projection as Management');
select ok(not has_table_privilege('authenticated','public.v1_workforce_workers',
    'select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_periods','select,insert,update,delete'),
  'T10 changes no protected Workforce table ACL');
reset role;

update public.v1_workforce_responsibility_assignments
set valid_to='2026-01-02'
where id='59db0000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_get_workforce_overview(
  '{"overview_kind":"supervisor"}')$$,'42501',
  'V1_WORKFORCE_T10_READ_DENIED',
  'An expired responsibility immediately removes protected overview data');
reset role;

select is(
  (select row(audit_count,notification_count,delivery_count,transition_count,
      report_count)::text from t10_read_effect_baseline),
  (select row(
      (select count(*) from public.v1_audit_events),
      (select count(*) from public.v1_notifications),
      (select count(*) from public.v1_workforce_notification_deliveries),
      (select count(*) from public.v1_workforce_monthly_transitions),
      (select count(*) from public.v1_workforce_report_artifacts)
    )::text),
  'T10 reads append no audit, notification, transition or report side effect');

select * from finish();
rollback;
