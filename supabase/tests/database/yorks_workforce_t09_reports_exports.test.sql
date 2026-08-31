begin;

create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select is((select count(*) from public.v1_capability_catalog catalog
  where public.v1_workforce_is_capability_key(catalog.capability_key)
    and catalog.status='operational' and catalog.authorization_mode='enforced'
    and catalog.is_assignable),12::bigint,
  'The completed chain includes reports and the three reviewed Administration consumers');
select ok(not has_table_privilege('authenticated',
    'public.v1_workforce_report_artifacts','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_report_artifact_snapshots','select,insert,update,delete'),
  'Authenticated direct CRUD is denied across the T09 ledger');
select ok(has_function_privilege('authenticated',
    'public.v1_generate_workforce_report(jsonb,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_issue_workforce_report_export(jsonb,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_list_workforce_report_artifacts(integer,integer)','execute'),
  'Authenticated callers receive only the intended public T09 boundary');
select ok(not has_function_privilege('authenticated',
    'public.v1_workforce_t09_snapshot_authorized(uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t09_daily_authorized(jsonb)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t09_artifact_authorized(uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t09_rows(text,uuid[],uuid,uuid,uuid,date,jsonb)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t09_columns(text)','execute'),
  'Internal SECURITY DEFINER report helpers are non-callable');

insert into public.v1_projects(id,project_ref,name,state,current_action_owner_role,
  created_by_auth_user_id,created_by_role) values(
  '59c10000-0000-4000-8000-000000000001','WF-T09','T09 Export Project',
  'active','project_engineer','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,
  is_immutable,is_active) values('59c20000-0000-4000-8000-000000000001',
  '59c10000-0000-4000-8000-000000000001','common','common',
  'Common / All Buildings',true,true);
insert into public.v1_workforce_teams(id,team_code,team_name,default_project_id,
  default_project_scope_id,valid_from,valid_to,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values('59c30000-0000-4000-8000-000000000001',
  'WF-T09','T09 Reports Team','59c10000-0000-4000-8000-000000000001',
  '59c20000-0000-4000-8000-000000000001','2026-08-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,current_status,created_by_auth_user_id,
  updated_by_auth_user_id) values('59c40000-0000-4000-8000-000000000001',
  '000599','=SUM(1,1) Report Worker','Technician','Yorks AC & Ref.','yorks_employee',
  '2026-01-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_worker_assignments(id,worker_id,assignment_kind,
  team_id,supervisor_auth_user_id,project_id,project_scope_id,valid_from,valid_to,
  reason,assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
values('59c50000-0000-4000-8000-000000000001',
  '59c40000-0000-4000-8000-000000000001','primary',
  '59c30000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004',
  '59c10000-0000-4000-8000-000000000001','59c20000-0000-4000-8000-000000000001',
  '2026-08-01','2026-08-01','T09 retained assignment',
  '10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendars(id,calendar_code,calendar_name,timezone_name,
  standard_scheduled_minutes,break_minutes,valid_from,valid_to,is_active,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '59c60000-0000-4000-8000-000000000001','WF-T09-DXB','T09 Dubai Calendar',
  'Asia/Dubai',480,60,'2026-08-01','2027-12-31',true,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendar_weekdays(calendar_id,iso_weekday,day_type,
  created_by_auth_user_id,updated_by_auth_user_id)
select '59c60000-0000-4000-8000-000000000001',weekday,'regular_working_day',
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004'
from generate_series(1,7) weekday;
insert into public.v1_workforce_team_schedule_links(id,team_id,calendar_id,
  valid_from,valid_to,reason,created_by_auth_user_id,updated_by_auth_user_id)
values('59c70000-0000-4000-8000-000000000001',
  '59c30000-0000-4000-8000-000000000001','59c60000-0000-4000-8000-000000000001',
  '2026-08-01','2027-12-31','T09 retained schedule',
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok($$select public.v1_save_workforce_attendance_day(
  '{"worker_id":"59c40000-0000-4000-8000-000000000001","work_date":"2026-08-01","attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"reason":"T09 accepted day"}',
  null,'59c90000-0000-4000-8000-000000000001')$$,
  'Accepted T03 writer creates the daily report source');
reset role;

insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,record_version,
  current_approval_revision_number,created_by_auth_user_id,updated_by_auth_user_id)
values('59c80000-0000-4000-8000-000000000001',
  '59c30000-0000-4000-8000-000000000001','2026-08-01',
  '59c81000-0000-4000-8000-000000000001',1,'locked',2,1,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
  validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
  present_day_count,regular_minutes,overtime_minutes,authority_snapshot,
  validated_by_auth_user_id,validated_by_exact_role,idempotency_key)
values('59c81000-0000-4000-8000-000000000001',
  '59c80000-0000-4000-8000-000000000001',1,'ready_for_review',repeat('a',64),
  1,1,1,1,480,60,'{"fixture":"t09"}',
  '10000000-0000-4000-8000-000000000004','admin',
  '59c90000-0000-4000-8000-000000000002');
insert into public.v1_workforce_monthly_period_workers(validation_run_id,worker_id,
  worker_number_snapshot,worker_name_snapshot,employer_name_snapshot,
  first_applicable_date,last_applicable_date,scheduled_day_count,present_day_count,
  regular_minutes,overtime_minutes,worker_status)
values('59c81000-0000-4000-8000-000000000001',
  '59c40000-0000-4000-8000-000000000001','000599','=SUM(1,1) Report Worker',
  'Yorks AC & Ref.','2026-08-01','2026-08-01',1,1,480,60,'complete');
insert into public.v1_workforce_monthly_period_dates(validation_run_id,worker_id,
  work_date,is_future,is_required,day_type,daily_status,worker_snapshot,
  assignment_snapshot,schedule_snapshot,attendance_snapshot,allocation_snapshot,
  scheduled_minutes,regular_minutes,overtime_minutes,allocation_minutes)
values('59c81000-0000-4000-8000-000000000001',
  '59c40000-0000-4000-8000-000000000001','2026-08-01',false,true,
  'regular_working_day','complete',
  '{"worker_number":"000599","worker_name":"=SUM(1,1) Report Worker","trade_name":"HVAC Technician"}',
  '{"team_id":"59c30000-0000-4000-8000-000000000001","team_name":"T09 Reports Team","supervisor_auth_user_id":"10000000-0000-4000-8000-000000000004","supervisor_name":"Local Admin","project_id":"59c10000-0000-4000-8000-000000000001","project_ref":"WF-T09","project_name":"T09 Export Project","project_scope_id":"59c20000-0000-4000-8000-000000000001","project_scope_name":"Common / All Buildings"}',
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":480,"day_type":"regular_working_day"}',
  '{"attendance_status":"present","regular_minutes":480,"overtime_minutes":60,"overtime_reason":"Approved test overtime"}',
  '{"allocation_state":"active","targets":[{"line_number":1,"target_kind":"project_work","project_id":"59c10000-0000-4000-8000-000000000001","project_ref":"WF-T09","project_name":"T09 Export Project","project_scope_id":"59c20000-0000-4000-8000-000000000001","project_scope_name":"Common / All Buildings","activity_task":"Duct installation","notes":"North riser","regular_minutes":480,"overtime_minutes":60}]}',
  480,480,60,540);
insert into public.v1_workforce_monthly_approval_revisions(id,period_id,
  revision_number,opened_reason,opened_by_auth_user_id,opened_by_exact_role)
values('59c82000-0000-4000-8000-000000000001',
  '59c80000-0000-4000-8000-000000000001',1,'T09 approved revision',
  '10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_workforce_monthly_transitions(id,period_id,
  approval_revision_number,action_kind,from_status,to_status,from_record_version,
  to_record_version,validation_run_id,source_fingerprint,actor_auth_user_id,
  actor_exact_role,capability_key,reason,idempotency_key,occurred_at)
values('59c82500-0000-4000-8000-000000000001',
  '59c80000-0000-4000-8000-000000000001',1,'verify_forward','under_review',
  'awaiting_final_approval',1,2,'59c81000-0000-4000-8000-000000000001',
  repeat('a',64),'10000000-0000-4000-8000-000000000004','admin',
  'workforce.timesheets.verify','T09 retained reviewer evidence',
  '59c90000-0000-4000-8000-000000000009','2026-08-30T20:00:00Z');
insert into public.v1_workforce_monthly_approved_snapshots(id,period_id,
  approval_revision_number,validation_run_id,snapshot_payload,snapshot_hash,
  approved_by_auth_user_id,approved_by_exact_role)
select '59c83000-0000-4000-8000-000000000001',
  '59c80000-0000-4000-8000-000000000001',1,
  '59c81000-0000-4000-8000-000000000001',payload,
  public.v1_hash_json(payload),'10000000-0000-4000-8000-000000000004','admin'
from (select public.v1_workforce_t07_snapshot_payload(
  '59c80000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004','admin',clock_timestamp()) payload) source;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000010')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Exact Admin role is not an export-capability bypass');
reset role;

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
  ('59ca0000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004',
    'workforce.view','grant','organization','permission_management','2026-01-01',
    'T09 Admin view','10000000-0000-4000-8000-000000000004'),
  ('59ca0000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000004',
    'workforce.reports.export','grant','organization','permission_management','2026-01-01',
    'T09 Admin export','10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do update set effective_until=null;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000011')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Capability without exact dated Workforce responsibility is denied');
reset role;

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,scope_kind,
  valid_from,valid_to,reason,assigned_by_auth_user_id,assigned_by_exact_role,
  updated_by_auth_user_id) values('59cb0000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004','organization','2026-01-01','2027-12-31',
  'T09 exact organization responsibility','10000000-0000-4000-8000-000000000004',
  'admin','10000000-0000-4000-8000-000000000004');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
create temporary table t09_team_report(value jsonb) on commit drop;
insert into t09_team_report select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000012');
select is(value->>'source_kind','approved_snapshot',
  'Team report identifies its immutable approved source') from t09_team_report;
select matches(value#>>'{sources,0,snapshot_hash}','^[0-9a-f]{64}$',
  'Report retains the exact T07 snapshot hash shape') from t09_team_report;
select is(value->>'company_legal_name',
  'Yorks Air Conditioning & Refrigeration LLC-SPC',
  'Report freezes the published legal company identity') from t09_team_report;
select is(value->>'company_secondary_name',
  'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و',
  'Report freezes the published secondary company identity') from t09_team_report;
select is(jsonb_typeof(value#>'{sources,0,review_chain}'),'array',
  'Approved source carries a typed immutable review chain') from t09_team_report;
select is(value#>>'{rows,0,regular_hours}','8.0000',
  'Team summary derives approved regular hours from the snapshot') from t09_team_report;
select is(value#>>'{rows,0,overtime_hours}','1.0000',
  'Team summary retains approved overtime separately') from t09_team_report;
select is((select string_agg(column_value->>'key',',' order by ordinal)
    from jsonb_array_elements(value->'columns') with ordinality columns(column_value,ordinal)),
  'team,period_month,workers_managed,attendance_summary,regular_hours,overtime_hours,absences,projects,exceptions,review_approval_status',
  'Team export exposes the exact controlled summary field set') from t09_team_report;
select matches(value#>>'{rows,0,review_approval_status}',
  '^Approved & locked · R1 · Local Admin \(admin\) · ',
  'Team summary retains review and approval status evidence') from t09_team_report;
select is((value#>>'{totals,row_count}')::integer,1,
  'Team report exposes one deterministic row') from t09_team_report;
select is(value->>'work_date',null,
  'Approved monthly reports do not masquerade as a daily report') from t09_team_report;
select is(public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000012')->>'artifact_id',
  (select value->>'artifact_id' from t09_team_report),
  'Same-key same-payload retry returns the exact artifact');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"company_workforce_summary","snapshot_ids":["59c83000-0000-4000-8000-000000000001"]}',
  '59c90000-0000-4000-8000-000000000012')$$,'22023',
  'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Same key with a different report request is denied');

create temporary table t09_worker_report(value jsonb) on commit drop;
insert into t09_worker_report select public.v1_generate_workforce_report(
  '{"report_kind":"worker_monthly_timesheet","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"worker_id":"59c40000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000013');
select is(value->>'scope_kind','worker',
  'Worker Monthly report is generated from the same accepted snapshot')
from t09_worker_report;
select is((select string_agg(column_value->>'key',',' order by ordinal)
  from t09_worker_report report
  cross join lateral jsonb_array_elements(report.value->'columns')
    with ordinality columns(column_value,ordinal)
  ),
  'worker_number,worker_name,work_date,attendance_status,regular_hours,overtime_hours,projects,buildings,internal_locations,activities,supervisor,reviewer,approver,approval_dates',
  'Worker Monthly export exposes status, work, context and approval fields');
select ok((select value#>>'{rows,0,supervisor}'='Local Admin'
    and value#>>'{rows,0,reviewer}'='Local Admin'
    and value#>>'{rows,0,approver}'='Local Admin'
    and value#>>'{rows,0,activities}'='Duct installation'
  from t09_worker_report),
  'Worker Monthly rows retain supervisor, activity, reviewer and approver evidence');
create temporary table t09_project_report(value jsonb) on commit drop;
insert into t09_project_report select public.v1_generate_workforce_report(
  '{"report_kind":"project_workforce","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"project_id":"59c10000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000014');
select is(value#>>'{rows,0,man_days}','1.1250',
  'Project man-days use approved work minutes and retained standard minutes')
from t09_project_report;
select is((select string_agg(column_value->>'key',',' order by ordinal)
  from t09_project_report report
  cross join lateral jsonb_array_elements(report.value->'columns')
    with ordinality columns(column_value,ordinal)
  ),
  'project,buildings,worker_count,trade_distribution,man_hours,man_days,regular_hours,overtime_hours,absences,supervisors,outstanding_periods',
  'Project Workforce export exposes the exact project summary field set');
create temporary table t09_company_report(value jsonb) on commit drop;
insert into t09_company_report select public.v1_generate_workforce_report(
  '{"report_kind":"company_workforce_summary","snapshot_ids":["59c83000-0000-4000-8000-000000000001"]}',
  '59c90000-0000-4000-8000-000000000015');
select is(value#>>'{rows,0,total_active_workforce}','1',
  'Company summary derives total represented active workforce')
from t09_company_report;
select is((select string_agg(column_value->>'key',',' order by ordinal)
  from t09_company_report report
  cross join lateral jsonb_array_elements(report.value->'columns')
    with ordinality columns(column_value,ordinal)
  ),
  'period_month,total_active_workforce,attendance_completion,approved_regular_hours,approved_overtime_hours,absence_position,project_allocation,pending_submissions,pending_approvals,reopened_periods',
  'Company Workforce export exposes the exact company summary field set');
create temporary table t09_daily_report(value jsonb) on commit drop;
insert into t09_daily_report select public.v1_generate_workforce_report(
  '{"report_kind":"daily_attendance_register","work_date":"2026-08-01","team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000016');
select is(value->>'source_status','current_not_approved',
  'Daily register is explicitly current and never mislabelled approved')
from t09_daily_report;
select is((select string_agg(column_value->>'key',',' order by ordinal)
  from t09_daily_report report
  cross join lateral jsonb_array_elements(report.value->'columns')
    with ordinality columns(column_value,ordinal)
  ),
  'worker_number,worker_name,trade,attendance_status,regular_hours,overtime_hours,project,building,internal_location,supervisor,notes',
  'Daily Attendance export exposes every required source field separately');
select ok((select value#>>'{rows,0,project}' like 'WF-T09%'
    and value#>>'{rows,0,building}'='Common / All Buildings'
    and value#>>'{rows,0,internal_location}'='—'
    and value#>>'{rows,0,supervisor}'='Local Admin'
    and value#>>'{rows,0,notes}'='T09 accepted day'
  from t09_daily_report),
  'Daily Attendance retains project, Building/Common, location, supervisor and notes without conflation');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"daily_attendance_register","work_date":"2027-01-01","team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000024')$$,'22023',
  'V1_WORKFORCE_FUTURE_WORK_DATE_DENIED','Future daily attendance reports are denied');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000999"}',
  '59c90000-0000-4000-8000-000000000025')$$,'23514',
  'V1_WORKFORCE_REPORT_SOURCE_INVALID','A forged team cannot relabel an approved source');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"worker_monthly_timesheet","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"worker_id":"59c40000-0000-4000-8000-000000000999"}',
  '59c90000-0000-4000-8000-000000000026')$$,'23514',
  'V1_WORKFORCE_REPORT_SOURCE_INVALID','A worker report requires that exact retained worker');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"project_workforce","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"project_id":"59c10000-0000-4000-8000-000000000999"}',
  '59c90000-0000-4000-8000-000000000027')$$,'23514',
  'V1_WORKFORCE_REPORT_SOURCE_INVALID','A project report requires an exact retained target');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"exception_missing_attendance","period_month":"2026-08-01","project_id":"59c10000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000028')$$,'22023',
  'V1_WORKFORCE_REPORT_INVALID','Exception reports cannot smuggle an ignored project scope');
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"exception_missing_attendance","period_month":"2026-08-01","unexpected":true}',
  '59c90000-0000-4000-8000-000000000029')$$,'22023',
  'V1_UNKNOWN_GENERATE_WORKFORCE_REPORT_FIELDS: unexpected',
  'Unknown report request fields fail closed');

select is((public.v1_generate_workforce_report(
  '{"report_kind":"exception_high_overtime","period_month":"2026-08-01"}',
  '59c90000-0000-4000-8000-000000000017')#>>'{rows,0,status}'),'not_configured',
  'High Overtime explicitly reports that no authoritative threshold is configured');
select lives_ok($$select public.v1_generate_workforce_report(
  jsonb_build_object('report_kind',kind,'period_month','2026-08-01'),key)
  from (values
    ('exception_missing_attendance','59c90000-0000-4000-8000-000000000018'::uuid),
    ('exception_returned_timesheets','59c90000-0000-4000-8000-000000000019'::uuid),
    ('exception_unsubmitted_periods','59c90000-0000-4000-8000-000000000020'::uuid),
    ('exception_workers_without_assignment','59c90000-0000-4000-8000-000000000021'::uuid),
    ('exception_overlapping_allocations','59c90000-0000-4000-8000-000000000022'::uuid),
    ('exception_reopened_periods','59c90000-0000-4000-8000-000000000023'::uuid)
  ) request(kind,key)$$,'All remaining typed exception report families generate');
select ok(position('salary' in lower((select value::text from t09_team_report)))=0
  and position('wage' in lower((select value::text from t09_team_report)))=0
  and position('bank' in lower((select value::text from t09_team_report)))=0,
  'Protected report payload contains no prohibited payroll/bank fields');
select ok(not exists(select 1 from jsonb_array_elements(
    (select value->'columns' from t09_team_report)) column_value
    where column_value->>'key' like '%_id'),
  'No internal identifier is exported as a visible column');
select is((public.v1_list_workforce_report_artifacts(100,0)->>'total_count')::bigint,
  12::bigint,'Report history returns the current actor immutable artifacts');
select is((public.v1_list_workforce_report_artifacts(5,5)->>'total_count')::bigint,
  12::bigint,'Report history total remains independent of the selected page');
create temporary table t09_pdf_preview_issue(value jsonb) on commit drop;
insert into t09_pdf_preview_issue select public.v1_issue_workforce_report_export(
  jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
    'format','pdf','action','preview'),
  '59c90000-0000-4000-8000-000000000040');
select ok(value->>'source_hash'=(select value->>'source_hash' from t09_team_report)
    and value->>'report_payload_hash' ~ '^[0-9a-f]{64}$'
    and value->>'capability_key'='workforce.reports.export'
    and value->>'scope_kind'='team'
    and value->>'scope_reference'='59c30000-0000-4000-8000-000000000001',
  'Issuance receipt freezes format/action hashes and exact capability/scope')
from t09_pdf_preview_issue;
select is(public.v1_issue_workforce_report_export(
    jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
      'format','pdf','action','preview'),
    '59c90000-0000-4000-8000-000000000040')->>'issued_at',
  (select value->>'issued_at' from t09_pdf_preview_issue),
  'Same issuance key and payload returns the exact stable server receipt');
select throws_ok($$select public.v1_issue_workforce_report_export(
  jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
    'format','pdf','action','download'),
  '59c90000-0000-4000-8000-000000000040')$$,'22023',
  'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Issuance key reuse with a different action fails closed');
select throws_ok($$select public.v1_issue_workforce_report_export(
  jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
    'format','xlsx','action','preview'),
  '59c90000-0000-4000-8000-000000000041')$$,'22023',
  'V1_WORKFORCE_REPORT_ISSUE_INVALID','XLSX preview is not an authorized action');
select throws_ok($$select public.v1_issue_workforce_report_export(
  jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
    'format','pdf','action','print','unexpected',true),
  '59c90000-0000-4000-8000-000000000042')$$,'22023',
  'V1_UNKNOWN_ISSUE_WORKFORCE_REPORT_EXPORT_FIELDS: unexpected',
  'Unknown issuance fields fail closed');
reset role;
select is((select value->>'report_payload_hash' from t09_pdf_preview_issue),
  (select artifact.report_payload_hash
    from public.v1_workforce_report_artifacts artifact
    where artifact.id=(select (value->>'artifact_id')::uuid from t09_team_report)),
  'Issuance receipt retains the exact cached report payload hash');
select is((select count(*) from public.v1_audit_events
    where event_type='workforce_export_generated'
      and entity_id=(select (value->>'artifact_id')::uuid from t09_team_report)
      and idempotency_key='59c90000-0000-4000-8000-000000000040'),1::bigint,
  'One explicit preview issuance writes exactly one export audit effect');

insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,scope_kind,
  project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values(
  '59cb0000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000004','project',
  '59c10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T09 retained daily target regression','10000000-0000-4000-8000-000000000004',
  'admin','10000000-0000-4000-8000-000000000004');
update public.v1_workforce_responsibility_assignments set valid_to='2026-07-31'
where id='59cb0000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select ok(not public.v1_workforce_t09_daily_authorized(
  '{"work_date":"2026-08-01","rows":[{"worker_id":"59c40000-0000-4000-8000-000000000001","assignment":{"team_id":"59c30000-0000-4000-8000-000000000001","project_id":"59c10000-0000-4000-8000-000000000001","project_scope_id":"59c20000-0000-4000-8000-000000000001","internal_location_id":null},"allocation_details_restricted":false,"allocation_set":{"allocation_set_id":"59cf0000-0000-4000-8000-000000000001","allocations":[{"target_kind":"project_work","project":{"project_id":"59cf0000-0000-4000-8000-000000000002","project_scope_id":"59cf0000-0000-4000-8000-000000000003"},"internal_location":null}]}}]}'::jsonb),
  'Daily history reauthorization uses the retained allocation targets, not a mutable current set');
update public.v1_workforce_responsibility_assignments set valid_to='2026-07-31'
where id='59cb0000-0000-4000-8000-000000000002';
update public.v1_workforce_responsibility_assignments set valid_to='2027-12-31'
where id='59cb0000-0000-4000-8000-000000000001';

update public.v1_workforce_responsibility_assignments set valid_to='2026-07-31'
where id='59cb0000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000035')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Expired Workforce responsibility denies an otherwise capable actor');
select is((public.v1_list_workforce_report_artifacts(100,0)->>'total_count')::bigint,
  0::bigint,'Authority loss hides approved, daily and exception report history');
select throws_ok($$select public.v1_issue_workforce_report_export(
  jsonb_build_object('artifact_id',(select value->>'artifact_id' from t09_team_report),
    'format','pdf','action','download'),
  '59c90000-0000-4000-8000-000000000043')$$,'42501',
  'V1_WORKFORCE_REPORT_ISSUE_DENIED',
  'Authority loss denies issuance of a previously generated artifact');
reset role;
update public.v1_workforce_responsibility_assignments set valid_to='2027-12-31'
where id='59cb0000-0000-4000-8000-000000000001';

select is((select count(*) from public.v1_workforce_report_artifacts
  where generated_by_auth_user_id='10000000-0000-4000-8000-000000000004'
    and idempotency_key='59c90000-0000-4000-8000-000000000012'),1::bigint,
  'Idempotent retry creates exactly one artifact');
select is((select count(*) from public.v1_audit_events where
  event_type='report_generated' and
  entity_id=(select id from public.v1_workforce_report_artifacts where
    idempotency_key='59c90000-0000-4000-8000-000000000012')),1::bigint,
  'Idempotent report retry creates exactly one generation audit effect');
select throws_ok($$update public.v1_workforce_report_artifacts set source_status='changed'
  where idempotency_key='59c90000-0000-4000-8000-000000000012'$$,'23514',
  'V1_WORKFORCE_MONTHLY_HISTORY_IMMUTABLE','Issued artifact cannot be rewritten');
select throws_ok($$delete from public.v1_workforce_report_artifact_snapshots
  where report_artifact_id=(select id from public.v1_workforce_report_artifacts
    where idempotency_key='59c90000-0000-4000-8000-000000000012')$$,'23514',
  'V1_WORKFORCE_MONTHLY_HISTORY_IMMUTABLE','Artifact snapshot links cannot be deleted');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000030')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Project Engineer role alone cannot export');
reset role;
insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
  ('59ca0000-0000-4000-8000-000000000011','10000000-0000-4000-8000-000000000001',
    'workforce.view','grant','project',
    'permission_management','2026-01-01','T09 scoped PE view',
    '10000000-0000-4000-8000-000000000004'),
  ('59ca0000-0000-4000-8000-000000000012','10000000-0000-4000-8000-000000000001',
    'workforce.reports.export','grant','project',
    'permission_management','2026-01-01','T09 scoped PE export',
    '10000000-0000-4000-8000-000000000004')
on conflict do nothing;
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select assignment.id,'59c10000-0000-4000-8000-000000000001'
from public.v1_permission_assignments assignment
where assignment.auth_user_id='10000000-0000-4000-8000-000000000001'
  and assignment.capability_key in ('workforce.view','workforce.reports.export')
  and assignment.scope_kind='project' and assignment.effect='grant'
on conflict do nothing;
insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values(
  '59cb0000-0000-4000-8000-000000000011',
  '10000000-0000-4000-8000-000000000001','project',
  '59c10000-0000-4000-8000-000000000001','2026-01-01','2027-12-31',
  'T09 exact scoped PE responsibility','10000000-0000-4000-8000-000000000004',
  'admin','10000000-0000-4000-8000-000000000004');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select is((public.v1_generate_workforce_report(
  '{"report_kind":"project_workforce","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"project_id":"59c10000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000033')->>'scope_kind'),'project',
  'Capability plus exact dated project responsibility permits scoped export');
select ok(exists(select 1 from jsonb_array_elements(
    public.v1_list_workforce_report_artifacts(100,0)->'items') artifact
    where artifact->>'report_kind'='project_workforce'
      and artifact->>'scope_reference'='59c10000-0000-4000-8000-000000000001'),
  'Scoped actor can revisit its authorized immutable report');
reset role;
update public.v1_permission_assignments set effective_until='2026-07-31'
where auth_user_id='10000000-0000-4000-8000-000000000001'
  and capability_key='workforce.reports.export' and scope_kind='project'
  and effect='grant';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000034')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Expired report capability denies an otherwise authorized scoped actor');
reset role;
update public.v1_permission_assignments set effective_until=null
where auth_user_id='10000000-0000-4000-8000-000000000001'
  and capability_key='workforce.reports.export' and scope_kind='project'
  and effect='grant';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000031')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Site Engineer role alone cannot export');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_generate_workforce_report(
  '{"report_kind":"supervisor_team_monthly","snapshot_ids":["59c83000-0000-4000-8000-000000000001"],"team_id":"59c30000-0000-4000-8000-000000000001"}',
  '59c90000-0000-4000-8000-000000000032')$$,'42501','V1_WORKFORCE_REPORT_DENIED',
  'Procurement role alone cannot export');
reset role;

select * from finish();
rollback;
