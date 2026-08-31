begin;

create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select is((select count(*) from public.v1_capability_catalog catalog
  where catalog.capability_key in ('workforce.view','workforce.attendance.maintain',
    'workforce.timesheets.maintain','workforce.timesheets.review',
    'workforce.timesheets.correct_during_review','workforce.timesheets.verify',
    'workforce.timesheets.final_approve','workforce.periods.reopen')
    and catalog.status='operational' and catalog.authorization_mode='enforced'
    and catalog.is_assignable),8::bigint,
  'T07 activates exactly the eight dependency-accepted lifecycle capabilities');

select ok(not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_approval_revisions','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_transitions','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_edit_scopes','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_edit_scope_entries','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_reviewer_corrections','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_reopen_requests','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_monthly_approved_snapshots','select,insert,update,delete'),
  'Authenticated direct CRUD is denied across every retained T07 relation');

select ok(has_function_privilege('authenticated',
    'public.v1_get_workforce_monthly_lifecycle(uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_submit_workforce_monthly_period(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_return_workforce_monthly_period(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_correct_workforce_monthly_entry_during_review(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_verify_workforce_monthly_period(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_approve_lock_workforce_monthly_period(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_request_workforce_monthly_reopen(jsonb,bigint,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_authorize_workforce_monthly_reopen(jsonb,bigint,uuid)','execute'),
  'Authenticated callers receive only the intended trusted T07 boundary');

select ok(not has_function_privilege('authenticated',
    'public.v1_workforce_t07_period_authorized(text,uuid,boolean)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_monthly_lifecycle_json(uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t07_snapshot_payload(uuid,uuid,text,timestamptz)','execute'),
  'Internal T07 SECURITY DEFINER helpers remain non-callable');

insert into public.v1_projects(id,project_ref,name,state,current_action_owner_role,
  created_by_auth_user_id,created_by_role) values(
  '59710000-0000-4000-8000-000000000001','WF-T07','Workforce T07 Project',
  'active','project_engineer','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,
  is_immutable,is_active) values('59720000-0000-4000-8000-000000000001',
  '59710000-0000-4000-8000-000000000001','common','common',
  'Common / All Buildings',true,true);
insert into public.v1_workforce_teams(id,team_code,team_name,default_project_id,
  default_project_scope_id,valid_from,valid_to,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values('59730000-0000-4000-8000-000000000001',
  'WF-T07','T07 Review Team','59710000-0000-4000-8000-000000000001',
  '59720000-0000-4000-8000-000000000001','2026-08-01','2026-08-31',true,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,current_status,created_by_auth_user_id,
  updated_by_auth_user_id) values('59740000-0000-4000-8000-000000000001',
  'WF-T07-W1','T07 Worker','Technician','Yorks AC & Ref.','yorks_employee',
  '2026-01-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_worker_assignments(id,worker_id,assignment_kind,
  team_id,supervisor_auth_user_id,project_id,project_scope_id,valid_from,valid_to,
  reason,assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
values('59750000-0000-4000-8000-000000000001',
  '59740000-0000-4000-8000-000000000001','primary',
  '59730000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004',
  '59710000-0000-4000-8000-000000000001','59720000-0000-4000-8000-000000000001',
  '2026-08-01','2026-08-01','T07 retained assignment',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendars(id,calendar_code,calendar_name,timezone_name,
  standard_scheduled_minutes,break_minutes,valid_from,valid_to,is_active,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '59760000-0000-4000-8000-000000000001','WF-T07-DXB','T07 Dubai Calendar',
  'Asia/Dubai',480,60,'2026-08-01','2026-08-31',true,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendar_weekdays(calendar_id,iso_weekday,day_type,
  created_by_auth_user_id,updated_by_auth_user_id)
select '59760000-0000-4000-8000-000000000001',weekday,'regular_working_day',
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004'
from generate_series(1,7) weekday;
insert into public.v1_workforce_team_schedule_links(id,team_id,calendar_id,
  valid_from,valid_to,reason,created_by_auth_user_id,updated_by_auth_user_id)
values('59770000-0000-4000-8000-000000000001',
  '59730000-0000-4000-8000-000000000001','59760000-0000-4000-8000-000000000001',
  '2026-08-01','2026-08-31','T07 retained schedule',
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');

-- The accepted T03 writer creates the authoritative fact before T07 freezes it.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok($$select public.v1_save_workforce_attendance_day(
  '{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"T07 initial accepted day"}',
  null,'59790000-0000-4000-8000-000000000001')$$,
  'Accepted T03 authority creates the fact used by the T07 period');
reset role;
create temporary table t07_attendance_id(value uuid) on commit drop;
insert into t07_attendance_id select id from public.v1_workforce_attendance_days
where worker_id='59740000-0000-4000-8000-000000000001' and work_date='2026-08-01';
grant select on t07_attendance_id to authenticated;

insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,record_version,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '59780000-0000-4000-8000-000000000001','59730000-0000-4000-8000-000000000001',
  '2026-08-01','59781000-0000-4000-8000-000000000001',1,'ready_for_review',1,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
  validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
  present_day_count,regular_minutes,warning_issue_count,authority_snapshot,
  validated_by_auth_user_id,validated_by_exact_role,idempotency_key) values(
  '59781000-0000-4000-8000-000000000001','59780000-0000-4000-8000-000000000001',
  1,'ready_for_review',public.v1_workforce_monthly_source_fingerprint(
    '59730000-0000-4000-8000-000000000001','2026-08-01'),1,1,1,1,480,1,
  '{"fixture":"t07"}','10000000-0000-4000-8000-000000000004','admin',
  '59790000-0000-4000-8000-000000000002');
insert into public.v1_workforce_monthly_period_workers(validation_run_id,worker_id,
  worker_number_snapshot,worker_name_snapshot,employer_name_snapshot,
  first_applicable_date,last_applicable_date,scheduled_day_count,present_day_count,
  regular_minutes,warning_issue_count,worker_status) values(
  '59781000-0000-4000-8000-000000000001','59740000-0000-4000-8000-000000000001',
  'WF-T07-W1','T07 Worker','Yorks AC & Ref.','2026-08-01','2026-08-01',1,1,480,1,
  'has_warnings');
insert into public.v1_workforce_monthly_period_dates(validation_run_id,worker_id,
  work_date,is_future,is_required,day_type,daily_status,worker_snapshot,
  assignment_snapshot,schedule_snapshot,attendance_snapshot,scheduled_minutes,
  regular_minutes,overtime_minutes,allocation_minutes,warning_issue_count) values(
  '59781000-0000-4000-8000-000000000001','59740000-0000-4000-8000-000000000001',
  '2026-08-01',false,true,'regular_working_day','has_warnings',
  '{"worker_number":"WF-T07-W1","worker_name":"T07 Worker"}',
  '{"team_id":"59730000-0000-4000-8000-000000000001","project_id":"59710000-0000-4000-8000-000000000001","project_scope_id":"59720000-0000-4000-8000-000000000001"}',
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":480,"day_type":"regular_working_day"}',
  '{"attendance_status":"present","regular_minutes":480,"overtime_minutes":0}',
  480,480,0,0,1);
insert into public.v1_workforce_monthly_validation_issues(id,validation_run_id,
  worker_id,work_date,severity,issue_code,message_key,issue_context,sort_order)
values('59782000-0000-4000-8000-000000000001',
  '59781000-0000-4000-8000-000000000001','59740000-0000-4000-8000-000000000001',
  '2026-08-01','warning','attendance_backdated',
  'workforce.monthly.issue.attendance_backdated','{}',270);

-- T13 removed the historical T07 Admin role shortcut. Admin lifecycle proofs
-- now declare the same complete dated organization responsibility required of
-- every exact role instead of relying on app_metadata.role alone.
insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
) values (
  '597b0000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004', 'organization',
  '2026-06-01', '2026-08-31', 'T07 Admin full-period lifecycle scope',
  '10000000-0000-4000-8000-000000000004', 'admin',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_get_workforce_monthly_lifecycle(
  '59780000-0000-4000-8000-000000000001')$$,'42501',
  'V1_WORKFORCE_T07_READ_DENIED',
  'An exact Procurement role without an effective capability and responsibility cannot read T07');
reset role;

insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,record_version,
  created_by_auth_user_id,updated_by_auth_user_id) values
  ('59780000-0000-4000-8000-000000000002','59730000-0000-4000-8000-000000000001',
    '2026-06-01','59781000-0000-4000-8000-000000000002',1,'ready_for_review',1,
    '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004'),
  ('59780000-0000-4000-8000-000000000003','59730000-0000-4000-8000-000000000001',
    '2026-07-01','59781000-0000-4000-8000-000000000003',1,'ready_for_review',1,
    '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
  validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
  present_day_count,regular_minutes,blocking_issue_count,warning_issue_count,
  authority_snapshot,validated_by_auth_user_id,validated_by_exact_role,idempotency_key)
values
  ('59781000-0000-4000-8000-000000000002','59780000-0000-4000-8000-000000000002',
    1,'ready_for_review',public.v1_workforce_monthly_source_fingerprint(
      '59730000-0000-4000-8000-000000000001','2026-06-01'),0,0,0,0,0,1,0,
    '{"fixture":"t07-blocking"}','10000000-0000-4000-8000-000000000004','admin',
    '59790000-0000-4000-8000-000000000028'),
  ('59781000-0000-4000-8000-000000000003','59780000-0000-4000-8000-000000000003',
    1,'ready_for_review',repeat('0',64),0,0,0,0,0,0,0,
    '{"fixture":"t07-stale"}','10000000-0000-4000-8000-000000000004','admin',
    '59790000-0000-4000-8000-000000000029');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000002","warning_issue_ids":[],"reason":"Blocked submission"}',1,
  '59790000-0000-4000-8000-000000000020')$$,'23514',
  'V1_WORKFORCE_T07_PERIOD_NOT_READY',
  'A blocking validation issue prevents submission even for Admin');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000003","warning_issue_ids":[],"reason":"Stale submission"}',1,
  '59790000-0000-4000-8000-000000000021')$$,'23514',
  'V1_WORKFORCE_T07_PERIOD_NOT_READY',
  'A stale validation fingerprint prevents submission even for Admin');
reset role;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
  ('597a0000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
    'workforce.view','grant','project','permission_management','2026-01-01','T07 maintainer view','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',
    'workforce.timesheets.maintain','grant','project','permission_management','2026-01-01','T07 maintainer','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002',
    'workforce.view','grant','project','permission_management','2026-01-01','T07 reviewer view','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.review','grant','project','permission_management','2026-01-01','T07 reviewer','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.correct_during_review','grant','project','permission_management','2026-01-01','T07 correction','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.verify','grant','project','permission_management','2026-01-01','T07 verify','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000003',
    'workforce.view','grant','project','permission_management','2026-01-01','T07 approver view','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000003',
    'workforce.timesheets.final_approve','grant','project','permission_management','2026-01-01','T07 final approval','10000000-0000-4000-8000-000000000004')
on conflict (auth_user_id,capability_key,scope_kind,effect) do nothing;
insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
  ('597a0000-0000-4000-8000-000000000009','10000000-0000-4000-8000-000000000001',
    'workforce.timesheets.review','grant','project','permission_management','2026-01-01',
    'T07 self-action negative only','10000000-0000-4000-8000-000000000004'),
  ('597a0000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000003',
    'workforce.timesheets.review','grant','project','permission_management','2026-01-01',
    'T07 returner separation proof','10000000-0000-4000-8000-000000000004')
on conflict (auth_user_id,capability_key,scope_kind,effect) do nothing;
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select assignment.id,'59710000-0000-4000-8000-000000000001'
from public.v1_permission_assignments assignment
join (values
  ('10000000-0000-4000-8000-000000000001'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000001'::uuid,'workforce.timesheets.maintain'),
  ('10000000-0000-4000-8000-000000000001'::uuid,'workforce.timesheets.review'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.timesheets.review'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.timesheets.correct_during_review'),
  ('10000000-0000-4000-8000-000000000002'::uuid,'workforce.timesheets.verify'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.view'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.timesheets.review'),
  ('10000000-0000-4000-8000-000000000003'::uuid,'workforce.timesheets.final_approve')
) required(auth_user_id,capability_key)
  on required.auth_user_id=assignment.auth_user_id
 and required.capability_key=assignment.capability_key
where assignment.scope_kind='project' and assignment.effect='grant'
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_get_workforce_monthly_lifecycle(
  '59780000-0000-4000-8000-000000000001')$$,'42501',
  'V1_WORKFORCE_T07_READ_DENIED',
  'A project capability without dated Workforce responsibility cannot read T07');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,scope_kind,
  project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values
  ('597b0000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
    'project','59710000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
    'T07 maintainer scope','10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004'),
  ('597b0000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002',
    'project','59710000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
    'T07 reviewer scope','10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004'),
  ('597b0000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003',
    'project','59710000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
    'T07 approver scope','10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":["59782000-0000-4000-8000-000000000001"],"reason":"Stale version"}',99,
  '59790000-0000-4000-8000-000000000022')$$,'40001',
  'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT',
  'A stale expected period version cannot overwrite the authoritative lifecycle');
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":[],"reason":"Malformed","unexpected":true}',1,
  '59790000-0000-4000-8000-000000000023')$$,'22023',
  'V1_UNKNOWN_SUBMIT_WORKFORCE_MONTHLY_PERIOD_FIELDS: unexpected',
  'Unknown submit payload fields fail closed');
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":[],"reason":"Submit August"}',1,
  '59790000-0000-4000-8000-000000000010')$$,'23514',
  'V1_WORKFORCE_T07_WARNING_ACK_REQUIRED','Submission rejects an incomplete warning acknowledgement set');
select is(public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":["59782000-0000-4000-8000-000000000001"],"reason":"Submit August"}',1,
  '59790000-0000-4000-8000-000000000011')->>'status','submitted',
  'A fully scoped maintainer submits the exact ready validation run');
select is(public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":["59782000-0000-4000-8000-000000000001"],"reason":"Submit August"}',1,
  '59790000-0000-4000-8000-000000000011')->>'status','submitted',
  'Same-key same-payload submit retry returns the original effect');
select throws_ok($$select public.v1_submit_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","warning_issue_ids":["59782000-0000-4000-8000-000000000001"],"reason":"Changed retry payload"}',1,
  '59790000-0000-4000-8000-000000000011')$$,'22023',
  'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Same-key different-payload submit retry fails closed');
reset role;
select is((select count(*) from public.v1_workforce_monthly_transitions
  where period_id='59780000-0000-4000-8000-000000000001' and action_kind='submit'),
  1::bigint,'Submit retry creates one transition');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_save_workforce_attendance_day(
  '{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Ordinary update while submitted"}',
  1,'59790000-0000-4000-8000-000000000024')$$,'42501',
  'V1_WORKFORCE_ATTENDANCE_MAINTAIN_DENIED',
  'The ordinary T03 attendance writer cannot bypass a submitted T07 period');
select throws_ok($$select public.v1_save_workforce_timesheet_allocations(
  jsonb_build_object('attendance_day_id',(select value from t07_attendance_id),
    'attendance_record_version',1,'reason','Ordinary allocation while submitted',
    'allocations',jsonb_build_array(jsonb_build_object('target_kind','project_work',
      'project_id','59710000-0000-4000-8000-000000000001',
      'project_scope_id','59720000-0000-4000-8000-000000000001',
      'regular_minutes',480,'overtime_minutes',0))),null,
  '59790000-0000-4000-8000-000000000025')$$,'42501',
  'V1_WORKFORCE_TIMESHEET_MAINTAIN_DENIED',
  'The ordinary T04 allocation writer cannot bypass a submitted T07 period');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_return_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Self return","affected_entries":[{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01"}]}',2,
  '59790000-0000-4000-8000-000000000019')$$,'42501',
  'V1_WORKFORCE_T07_SELF_ACTION_DENIED',
  'Submitter cannot review or return the same approval revision');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Wrong stage"}',2,
  '59790000-0000-4000-8000-000000000012')$$,'42501','V1_WORKFORCE_T07_APPROVE_DENIED',
  'Reviewer capability does not imply final approval authority');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Premature approval"}',2,
  '59790000-0000-4000-8000-000000000026')$$,'23514',
  'V1_WORKFORCE_T07_APPROVE_STATE_INVALID',
  'An authorized final approver cannot skip verification or approve an illegal state');
reset role;

-- A reviewer who returns this approval revision is permanently separated from
-- final approval for that revision, even after correction and resubmission.
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select is(public.v1_return_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Return for retained correction","affected_entries":[{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01"}]}',2,
  '59790000-0000-4000-8000-000000000030')->>'status','returned_for_correction',
  'A fully scoped reviewer with final-approval capability can return the revision');
select is(public.v1_return_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Return for retained correction","affected_entries":[{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01"}]}',2,
  '59790000-0000-4000-8000-000000000030')->>'status','returned_for_correction',
  'Same-key same-payload return retry replays one authoritative effect');
reset role;
select is((select count(*) from public.v1_workforce_monthly_transitions
  where period_id='59780000-0000-4000-8000-000000000001'
    and approval_revision_number=1 and action_kind='return_for_correction'
    and actor_auth_user_id='10000000-0000-4000-8000-000000000003'),1::bigint,
  'Return retry retains exactly one return transition');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok($$select public.v1_save_workforce_attendance_day(
  '{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Apply returned retained correction"}',
  1,'59790000-0000-4000-8000-000000000031')$$,
  'The exact returned edit scope permits its retained attendance correction');
select lives_ok($$select public.v1_validate_workforce_monthly_period(
  '{"team_id":"59730000-0000-4000-8000-000000000001","period_month":"2026-08-01"}',3,
  '59790000-0000-4000-8000-000000000032')$$,
  'Explicit validation accepts the corrected returned period');
reset role;
select is((select current_status from public.v1_workforce_monthly_periods
  where id='59780000-0000-4000-8000-000000000001'),'ready_for_review',
  'Explicit validation returns the corrected period to ready');

create temporary table t07_return_warning_ids(value jsonb) on commit drop;
insert into t07_return_warning_ids select coalesce(jsonb_agg(to_jsonb(issue.id)
  order by issue.id),'[]') from public.v1_workforce_monthly_validation_issues issue
where issue.validation_run_id=(select current_validation_run_id
  from public.v1_workforce_monthly_periods
  where id='59780000-0000-4000-8000-000000000001') and issue.severity='warning';
grant select on t07_return_warning_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select is(public.v1_submit_workforce_monthly_period(
  jsonb_build_object('period_id','59780000-0000-4000-8000-000000000001',
    'warning_issue_ids',(select value from t07_return_warning_ids),
    'reason','Resubmit returned August'),4,
  '59790000-0000-4000-8000-000000000033')->>'status','submitted',
  'Maintainer explicitly resubmits after the returned correction');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select is(public.v1_correct_workforce_monthly_entry_during_review(
  jsonb_build_object('period_id','59780000-0000-4000-8000-000000000001',
    'reason','Correct retained reason before final review','row',jsonb_build_object(
      'worker_id','59740000-0000-4000-8000-000000000001','work_date','2026-08-01',
      'expected_attendance_version',2,'attendance_status','present','regular_minutes',480,
      'overtime_minutes',0,'overtime_reason',null,'reason','Reviewer corrected evidence',
      'allocation_action','preserve','expected_allocation_version',null,'allocations',null)),
  5,'59790000-0000-4000-8000-000000000013')->>'status','ready_for_review',
  'Controlled reviewer correction records before/after and returns to explicit resubmission');
reset role;
select is((select count(*) from public.v1_workforce_monthly_reviewer_corrections
  where period_id='59780000-0000-4000-8000-000000000001'),1::bigint,
  'Reviewer correction creates one immutable marker');

-- New validation warning IDs are acknowledged by the maintainer on resubmit.
create temporary table t07_current_warning_ids(value jsonb) on commit drop;
insert into t07_current_warning_ids select coalesce(jsonb_agg(to_jsonb(issue.id)
  order by issue.id),'[]') from public.v1_workforce_monthly_validation_issues issue
where issue.validation_run_id=(select current_validation_run_id
  from public.v1_workforce_monthly_periods
  where id='59780000-0000-4000-8000-000000000001') and issue.severity='warning';
grant select on t07_current_warning_ids to authenticated;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
create temporary table t07_resubmit(value jsonb) on commit drop;
insert into t07_resubmit select public.v1_submit_workforce_monthly_period(
  jsonb_build_object('period_id','59780000-0000-4000-8000-000000000001',
    'warning_issue_ids',(select value from t07_current_warning_ids),
    'reason','Resubmit corrected August'),7,
  '59790000-0000-4000-8000-000000000014');
select is(value->>'status','submitted','Maintainer explicitly resubmits the corrected revision')
from t07_resubmit;
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select is(public.v1_verify_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Reviewed and verified"}',
  8,
  '59790000-0000-4000-8000-000000000015')->>'status','awaiting_final_approval',
  'A distinct scoped reviewer verifies and forwards');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select is(public.v1_get_workforce_monthly_lifecycle(
  '59780000-0000-4000-8000-000000000001')->>'can_final_approve','false',
  'The returner action flag remains false after independent verification');
select throws_ok($$select public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Returner final approval"}',
  9,'59790000-0000-4000-8000-000000000034')$$,'42501',
  'V1_WORKFORCE_T07_SELF_ACTION_DENIED',
  'A returner cannot final approve the same approval revision');
reset role;
select is((select count(*) from public.v1_workforce_monthly_approved_snapshots
  where period_id='59780000-0000-4000-8000-000000000001'),0::bigint,
  'Denied returner approval creates no snapshot');
select is((select count(*) from public.v1_idempotency_keys
  where actor_auth_user_id='10000000-0000-4000-8000-000000000003'
    and command_name='v1_approve_lock_workforce_monthly_period'
    and idempotency_key='59790000-0000-4000-8000-000000000034'),0::bigint,
  'Denied returner approval leaves no claimed idempotency effect');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is(public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Independent final approval"}',
  9,'59790000-0000-4000-8000-000000000016')->>'status','locked',
  'An independent eligible approver atomically approves and locks');
select is(public.v1_approve_lock_workforce_monthly_period(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Independent final approval"}',
  9,'59790000-0000-4000-8000-000000000016')->>'status','locked',
  'Same-key same-payload independent approval retry returns the original effect');
reset role;
select is((select count(*) from public.v1_workforce_monthly_approved_snapshots
  where period_id='59780000-0000-4000-8000-000000000001'),1::bigint,
  'Final approval creates exactly one immutable snapshot');
select is((select count(*) from public.v1_workforce_monthly_transitions
  where period_id='59780000-0000-4000-8000-000000000001'
    and approval_revision_number=1 and action_kind='approve_lock'
    and actor_auth_user_id='10000000-0000-4000-8000-000000000004'),1::bigint,
  'Independent approval retry retains exactly one approve transition');
select is((select count(*) from public.v1_audit_events
  where event_type='workforce_monthly_period_approved_and_locked'
    and entity_id='59780000-0000-4000-8000-000000000001'
    and idempotency_key='59790000-0000-4000-8000-000000000016'),1::bigint,
  'Independent approval retry retains exactly one audit effect');
select is((select count(*) from public.v1_idempotency_keys
  where actor_auth_user_id='10000000-0000-4000-8000-000000000004'
    and command_name='v1_approve_lock_workforce_monthly_period'
    and idempotency_key='59790000-0000-4000-8000-000000000016'
    and completed_at is not null),1::bigint,
  'Independent approval retry retains one completed idempotency effect');
select matches((select snapshot_hash from public.v1_workforce_monthly_approved_snapshots
  where period_id='59780000-0000-4000-8000-000000000001'),'^[0-9a-f]{64}$',
  'Approved snapshot exposes a deterministic SHA-256 hash');

select throws_ok($$update public.v1_workforce_monthly_approved_snapshots
  set snapshot_payload='{}' where period_id='59780000-0000-4000-8000-000000000001'$$,
  '23514','V1_WORKFORCE_T07_HISTORY_IMMUTABLE','Approved snapshot cannot be rewritten');

create temporary table t07_locked_snapshot(value text) on commit drop;
insert into t07_locked_snapshot select snapshot_hash
from public.v1_workforce_monthly_approved_snapshots
where period_id='59780000-0000-4000-8000-000000000001';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
create temporary table t07_reopen(value jsonb) on commit drop;
insert into t07_reopen select public.v1_request_workforce_monthly_reopen(
  '{"period_id":"59780000-0000-4000-8000-000000000001","reason":"Correct one retained day","affected_entries":[{"worker_id":"59740000-0000-4000-8000-000000000001","work_date":"2026-08-01"}]}',
  10,
  '59790000-0000-4000-8000-000000000017');
select ok(value#>>'{reopen_requests,0,request_id}' is not null,
  'A scoped maintainer requests reopen without unlocking the month') from t07_reopen;
reset role;
select is((select current_status from public.v1_workforce_monthly_periods
  where id='59780000-0000-4000-8000-000000000001'),'locked',
  'Reopen request alone leaves the approved month locked');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_authorize_workforce_monthly_reopen(jsonb_build_object(
  'period_id','59780000-0000-4000-8000-000000000001','request_id',
  (select value#>>'{reopen_requests,0,request_id}' from t07_reopen),
  'reason','Unauthorized reopen'),10,
  '59790000-0000-4000-8000-000000000027')$$,'42501',
  'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_DENIED',
  'Dated responsibility without the reopen capability cannot authorize a reopen');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is(public.v1_authorize_workforce_monthly_reopen(jsonb_build_object(
  'period_id','59780000-0000-4000-8000-000000000001','request_id',
  (select value#>>'{reopen_requests,0,request_id}' from t07_reopen),
  'reason','Authorized controlled correction'),
  10,
  '59790000-0000-4000-8000-000000000018')->>'status','reopened',
  'A separate reopen authority opens a new controlled approval revision');
reset role;
select is((select current_approval_revision_number from public.v1_workforce_monthly_periods
  where id='59780000-0000-4000-8000-000000000001'),2::bigint,
  'Authorized reopen advances to revision 2 without rewriting revision 1');
select is((select count(*) from public.v1_workforce_monthly_approved_snapshots
  where period_id='59780000-0000-4000-8000-000000000001'),1::bigint,
  'Authorized reopen preserves the original approved snapshot');
select is((select snapshot_hash from public.v1_workforce_monthly_approved_snapshots
    where period_id='59780000-0000-4000-8000-000000000001'),
  (select value from t07_locked_snapshot),
  'Authorized reopen preserves the exact approved snapshot bytes and hash');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is((public.v1_list_workforce_monthly_approval_queue('reopened',50,0)->>'total_count')::bigint,
  1::bigint,'Authorized queue returns the retained period with server action flags');
reset role;

select throws_ok($$delete from public.v1_workforce_monthly_transitions
  where period_id='59780000-0000-4000-8000-000000000001'$$,
  '23514','V1_WORKFORCE_T07_HISTORY_IMMUTABLE','Lifecycle transitions cannot be hard-deleted');

select * from finish();
rollback;
