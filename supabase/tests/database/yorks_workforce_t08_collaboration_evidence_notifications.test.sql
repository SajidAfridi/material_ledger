begin;

create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select is((select count(*) from public.v1_capability_catalog c
  where c.capability_key like 'workforce.%' and c.status='operational'
    and c.authorization_mode='enforced' and c.is_assignable),9::bigint,
  'The final T09 chain adds only reports.export beyond the eight T07 consumers');
select ok(not has_table_privilege('authenticated',
    'public.v1_workforce_timesheet_discussions','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_document_upload_metadata','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_document_version_metadata','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_notification_deliveries','select,insert,update,delete')
  and not has_table_privilege('authenticated',
    'public.v1_workforce_notification_digests','select,insert,update,delete'),
  'Authenticated direct CRUD is denied for every T08 relation');
select ok(not has_function_privilege('authenticated',
    'public.v1_workforce_t08_period_actor_authorized(uuid,text,uuid,boolean)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t08_sync_discussion_members(uuid)','execute')
  and not has_function_privilege('authenticated',
    'public.v1_workforce_t08_audit_bridge()','execute'),
  'T08 internal authority and bridge helpers are not callable');
select ok(has_function_privilege('authenticated',
    'public.v1_open_workforce_timesheet_discussion(uuid,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_send_workforce_timesheet_message(jsonb,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_prepare_workforce_document_upload(jsonb,uuid)','execute')
  and has_function_privilege('authenticated',
    'public.v1_get_workforce_collaboration(uuid)','execute'),
  'Authenticated callers receive only the intended trusted T08 boundary');

insert into public.v1_projects(id,project_ref,name,state,current_action_owner_role,
  created_by_auth_user_id,created_by_role) values(
  '5a810000-0000-4000-8000-000000000001','WF-T08','Workforce T08 Project',
  'active','project_engineer','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,
  is_immutable,is_active) values('5a820000-0000-4000-8000-000000000001',
  '5a810000-0000-4000-8000-000000000001','common','common',
  'Common / All Buildings',true,true);
insert into public.v1_workforce_teams(id,team_code,team_name,default_project_id,
  default_project_scope_id,valid_from,valid_to,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values('5a830000-0000-4000-8000-000000000001',
  'WF-T08','T08 Collaboration Team','5a810000-0000-4000-8000-000000000001',
  '5a820000-0000-4000-8000-000000000001','2026-08-01','2026-08-31',true,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,current_status,created_by_auth_user_id,
  updated_by_auth_user_id) values('5a840000-0000-4000-8000-000000000001',
  'WF-T08-W1','T08 Worker','Technician','Yorks AC & Ref.','yorks_employee',
  '2026-01-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),(
  '5a840000-0000-4000-8000-000000000002','WF-T08-W2',
  'T08 Internal Worker','Workshop Technician','Yorks AC & Ref.',
  'yorks_employee','2026-01-01','active',
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),(
  '5a840000-0000-4000-8000-000000000003','WF-T08-W3',
  'T08 Other Period Worker','Helper','Yorks AC & Ref.','yorks_employee',
  '2026-01-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

insert into public.v1_workforce_internal_locations(id,location_code,
  location_name,department,is_active,created_by_auth_user_id,
  updated_by_auth_user_id) values(
  '5a822000-0000-4000-8000-000000000001','WF-T08-INTERNAL',
  'T08 Internal Workshop','Workshop',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_teams(id,team_code,team_name,valid_from,valid_to,
  is_active,created_by_auth_user_id,updated_by_auth_user_id) values(
  '5a830000-0000-4000-8000-000000000002','WF-T08-INTERNAL',
  'T08 Internal Team','2026-08-01','2026-08-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

insert into public.v1_workforce_calendars(id,calendar_code,calendar_name,
  timezone_name,standard_scheduled_minutes,break_minutes,valid_from,valid_to,
  is_active,created_by_auth_user_id,updated_by_auth_user_id) values(
  '5a849000-0000-4000-8000-000000000001','WF-T08-DIGEST',
  'T08 Digest Calendar','Asia/Dubai',480,0,'2026-08-01','2026-08-31',true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendar_weekdays(calendar_id,iso_weekday,
  day_type,created_by_auth_user_id,updated_by_auth_user_id)
select '5a849000-0000-4000-8000-000000000001',weekday,
  'regular_working_day','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1,7) weekday;
insert into public.v1_workforce_team_schedule_links(id,team_id,calendar_id,
  valid_from,valid_to,reason,created_by_auth_user_id,updated_by_auth_user_id)
values('5a849000-0000-4000-8000-000000000002',
  '5a830000-0000-4000-8000-000000000001',
  '5a849000-0000-4000-8000-000000000001','2026-08-01','2026-08-31',
  'T08 digest schedule','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
  employer_company,worker_type,joining_date,current_status,
  created_by_auth_user_id,updated_by_auth_user_id)
select md5('t08-digest-worker-'||g)::uuid,'WF-T08-D-'||lpad(g::text,3,'0'),
  'T08 Digest Worker '||g,'Technician','Yorks AC & Ref.','yorks_employee',
  '2026-08-01','active','10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1,501) g;
insert into public.v1_workforce_worker_assignments(id,worker_id,
  assignment_kind,team_id,supervisor_auth_user_id,project_id,project_scope_id,
  valid_from,valid_to,reason,assigned_by_auth_user_id,assigned_by_exact_role,
  updated_by_auth_user_id)
select md5('t08-digest-assignment-'||g)::uuid,
  md5('t08-digest-worker-'||g)::uuid,'primary',
  '5a830000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  '5a810000-0000-4000-8000-000000000001',
  '5a820000-0000-4000-8000-000000000001','2026-08-01','2026-08-31',
  'T08 digest assignment','10000000-0000-4000-8000-000000000004','admin',
  '10000000-0000-4000-8000-000000000004'
from generate_series(1,501) g;

insert into public.v1_workforce_attendance_days(id,worker_id,work_date,
  attendance_status,regular_minutes,overtime_minutes,reason,
  worker_number_snapshot,worker_name_snapshot,worker_joining_date_snapshot,
  worker_status_snapshot,assignment_id_snapshot,assignment_kind_snapshot,
  assignment_team_id_snapshot,assignment_team_name_snapshot,
  assignment_project_id_snapshot,assignment_project_ref_snapshot,
  assignment_project_name_snapshot,assignment_project_scope_id_snapshot,
  assignment_project_scope_name_snapshot,assignment_internal_location_id_snapshot,
  assignment_internal_location_name_snapshot,assignment_valid_from_snapshot,
  assignment_valid_to_snapshot,assignment_record_version_snapshot,
  initial_authority_kind,initial_responsibility_scope_kind,
  initial_responsibility_scope_reference,team_schedule_link_id_snapshot,
  team_schedule_record_version_snapshot,calendar_id_snapshot,
  calendar_code_snapshot,calendar_name_snapshot,calendar_timezone_snapshot,
  calendar_record_version_snapshot,day_type_source_snapshot,
  iso_weekday_snapshot,day_type_snapshot,scheduled_minutes_snapshot,
  break_minutes_snapshot,created_by_auth_user_id,updated_by_auth_user_id)
values(
  '5a845000-0000-4000-8000-000000000001',
  '5a840000-0000-4000-8000-000000000001','2026-08-01','present',480,0,
  'T08 retained attendance','WF-T08-W1','T08 Worker','2026-01-01','active',
  '5a846000-0000-4000-8000-000000000001','primary',
  '5a830000-0000-4000-8000-000000000001','T08 Collaboration Team',
  '5a810000-0000-4000-8000-000000000001','WF-T08',
  'Workforce T08 Project','5a820000-0000-4000-8000-000000000001',
  'Common / All Buildings',null,null,'2026-08-01','2026-08-31',1,
  'admin_organization','organization','organization',
  '5a847000-0000-4000-8000-000000000001',1,
  '5a848000-0000-4000-8000-000000000001','WF-T08-CAL',
  'T08 Calendar','Asia/Dubai',1,'weekday',6,'regular_working_day',480,0,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'),(
  '5a845000-0000-4000-8000-000000000002',
  '5a840000-0000-4000-8000-000000000002','2026-08-01','present',480,0,
  'T08 retained internal attendance','WF-T08-W2','T08 Internal Worker',
  '2026-01-01','active','5a846000-0000-4000-8000-000000000002','primary',
  '5a830000-0000-4000-8000-000000000002','T08 Internal Team',
  null,null,null,null,null,'5a822000-0000-4000-8000-000000000001',
  'T08 Internal Workshop','2026-08-01','2026-08-31',1,
  'admin_organization','organization','organization',
  '5a847000-0000-4000-8000-000000000002',1,
  '5a848000-0000-4000-8000-000000000002','WF-T08-INTERNAL-CAL',
  'T08 Internal Calendar','Asia/Dubai',1,'weekday',6,
  'regular_working_day',480,0,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004');

set constraints all deferred;
insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
  current_validation_run_id,current_validation_number,current_status,record_version,
  created_by_auth_user_id,updated_by_auth_user_id) values(
  '5a850000-0000-4000-8000-000000000001','5a830000-0000-4000-8000-000000000001',
  '2026-08-01','5a851000-0000-4000-8000-000000000001',1,'ready_for_review',1,
  '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
  validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
  missing_day_count,blocking_issue_count,authority_snapshot,
  validated_by_auth_user_id,validated_by_exact_role,idempotency_key) values(
  '5a851000-0000-4000-8000-000000000001','5a850000-0000-4000-8000-000000000001',
  1,'ready_for_review',repeat('8',64),1,1,1,1,1,'{"fixture":"t08"}',
  '10000000-0000-4000-8000-000000000004','admin',
  '5a890000-0000-4000-8000-000000000001');
insert into public.v1_workforce_monthly_period_dates(validation_run_id,worker_id,
  work_date,is_future,is_required,day_type,daily_status,worker_snapshot,
  assignment_snapshot,schedule_snapshot,attendance_snapshot,scheduled_minutes,
  blocking_issue_count)
values('5a851000-0000-4000-8000-000000000001',
  '5a840000-0000-4000-8000-000000000001','2026-08-01',false,true,
  'regular_working_day','has_errors','{"worker_name":"T08 Worker"}',
  '{"team_id":"5a830000-0000-4000-8000-000000000001","project_id":"5a810000-0000-4000-8000-000000000001","project_scope_id":"5a820000-0000-4000-8000-000000000001"}',
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":480}',
  '{"attendance_day_id":"5a845000-0000-4000-8000-000000000001","attendance_status":"present"}',
  480,1);
insert into public.v1_workforce_monthly_period_dates(validation_run_id,worker_id,
  work_date,is_future,is_required,day_type,daily_status,worker_snapshot,
  assignment_snapshot,schedule_snapshot,scheduled_minutes,blocking_issue_count)
values('5a851000-0000-4000-8000-000000000001',
  '5a840000-0000-4000-8000-000000000003','2026-08-02',false,true,
  'regular_working_day','has_errors','{"worker_name":"T08 Other Period Worker"}',
  '{"team_id":"5a830000-0000-4000-8000-000000000001","project_id":"5a810000-0000-4000-8000-000000000001","project_scope_id":"5a820000-0000-4000-8000-000000000001"}',
  '{"calendar_timezone":"Asia/Dubai","scheduled_minutes":480}',480,1);

insert into public.v1_permission_assignments(id,auth_user_id,capability_key,effect,
  scope_kind,origin,effective_from,reason,changed_by_auth_user_id) values
  ('5a860000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
    'workforce.view','grant','project','permission_management','2026-01-01',
    'T08 view','10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',
    'workforce.timesheets.maintain','grant','project','permission_management','2026-01-01',
    'T08 maintain','10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002',
    'workforce.view','grant','project','permission_management','2026-01-01',
    'T08 reviewer view','10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002',
    'workforce.timesheets.review','grant','project','permission_management','2026-01-01',
    'T08 reviewer','10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000003',
    'workforce.view','grant','organization','permission_management','2026-01-01',
    'T08 forged-secondary negative','10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000009',
    'workforce.timesheets.review','grant','organization','permission_management',
    '2026-01-01','T08 inactive recipient negative',
    '10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000007','10000000-0000-4000-8000-000000000010',
    'workforce.timesheets.review','grant','organization','permission_management',
    '2026-01-01','T08 out-of-scope recipient negative',
    '10000000-0000-4000-8000-000000000004'),
  ('5a860000-0000-4000-8000-000000000008','10000000-0000-4000-8000-000000000001',
    'workforce.attendance.maintain','grant','project','permission_management',
    '2026-01-01','T08 daily digest maintainer',
    '10000000-0000-4000-8000-000000000004')
on conflict(auth_user_id,capability_key,scope_kind,effect) do nothing;
insert into public.v1_permission_assignment_projects(assignment_id,project_id)
select a.id,'5a810000-0000-4000-8000-000000000001'
from public.v1_permission_assignments a
where a.effect='grant'
  and a.scope_kind='project'
  and (
    (a.auth_user_id='10000000-0000-4000-8000-000000000001'
      and a.capability_key in (
        'workforce.view',
        'workforce.timesheets.maintain',
        'workforce.attendance.maintain'
      ))
    or
    (a.auth_user_id='10000000-0000-4000-8000-000000000002'
      and a.capability_key in (
        'workforce.view',
        'workforce.timesheets.review'
      ))
  )
on conflict do nothing;
insert into public.v1_workforce_responsibility_assignments(id,auth_user_id,
  scope_kind,worker_id,project_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
  assigned_by_exact_role,updated_by_auth_user_id) values
  ('5a870000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',
   'project',null,'5a810000-0000-4000-8000-000000000001','2026-01-01','2026-12-31',
   'T08 maintainer scope','10000000-0000-4000-8000-000000000004','admin',
   '10000000-0000-4000-8000-000000000004'),
  ('5a870000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002',
   'project',null,'5a810000-0000-4000-8000-000000000001','2026-01-01','2026-12-31',
   'T08 reviewer scope','10000000-0000-4000-8000-000000000004','admin',
   '10000000-0000-4000-8000-000000000004'),
  ('5a870000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003',
   'worker','5a840000-0000-4000-8000-000000000001',null,
   '2026-01-01','2026-12-31',
   'T08 worker-only secondary scope','10000000-0000-4000-8000-000000000004',
   'admin','10000000-0000-4000-8000-000000000004'),
  ('5a870000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000009',
   'project',null,'5a810000-0000-4000-8000-000000000001',
   '2026-01-01','2026-12-31','T08 inactive recipient scope',
   '10000000-0000-4000-8000-000000000004','admin',
   '10000000-0000-4000-8000-000000000004'),
  ('5a870000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000010',
   'worker','5a840000-0000-4000-8000-000000000002',null,
   '2026-01-01','2026-12-31','T08 out-of-scope recipient scope',
   '10000000-0000-4000-8000-000000000004','admin',
   '10000000-0000-4000-8000-000000000004');
update public.v1_profiles set is_active=false
  where auth_user_id='10000000-0000-4000-8000-000000000009';

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select throws_ok($$select public.v1_open_workforce_timesheet_discussion(
  '5a850000-0000-4000-8000-000000000001',
  '5a890000-0000-4000-8000-000000000002')$$,'42501',
  'V1_WORKFORCE_T08_DISCUSSION_OPEN_DENIED',
  'Role-only Procurement cannot open a Workforce discussion');
select throws_ok($$select public.v1_get_workforce_collaboration(
  '5a850000-0000-4000-8000-000000000001')$$,'42501',
  'V1_WORKFORCE_T08_COLLABORATION_DENIED',
  'A guessed period UUID does not grant collaboration access');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
create temporary table t08_discussion(value jsonb) on commit drop;
insert into t08_discussion select public.v1_open_workforce_timesheet_discussion(
  '5a850000-0000-4000-8000-000000000001',
  '5a890000-0000-4000-8000-000000000003');
select is(value->>'schema_version','yorks.workforce.discussion.v1',
  'A fully scoped maintainer opens the canonical discussion') from t08_discussion;
select is(public.v1_open_workforce_timesheet_discussion(
  '5a850000-0000-4000-8000-000000000001',
  '5a890000-0000-4000-8000-000000000003')->>'period_id',
  '5a850000-0000-4000-8000-000000000001',
  'Discussion open retry replays the original result');
create temporary table t08_message(value jsonb) on commit drop;
insert into t08_message select public.v1_send_workforce_timesheet_message(
  '{"period_id":"5a850000-0000-4000-8000-000000000001","body":"Approved - discussion text only","linked_entity_type":"workforce_monthly_period","linked_entity_id":"5a850000-0000-4000-8000-000000000001","mentioned_auth_user_ids":["10000000-0000-4000-8000-000000000002"]}',
  '5a890000-0000-4000-8000-000000000004');
select is(value->>'schema_version','yorks.workforce.discussion.message.v1',
  'Comments, mentions and record links use canonical Team Chat') from t08_message;
select is(public.v1_send_workforce_timesheet_message(
  '{"period_id":"5a850000-0000-4000-8000-000000000001","body":"Approved - discussion text only","linked_entity_type":"workforce_monthly_period","linked_entity_id":"5a850000-0000-4000-8000-000000000001","mentioned_auth_user_ids":["10000000-0000-4000-8000-000000000002"]}',
  '5a890000-0000-4000-8000-000000000004')#>>'{message,body}',
  'Approved - discussion text only','Message retry returns one canonical result');
select throws_ok($$select public.v1_send_workforce_timesheet_message(
  '{"period_id":"5a850000-0000-4000-8000-000000000001","body":"Changed retry"}',
  '5a890000-0000-4000-8000-000000000004')$$,'22023',
  'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Message same-key different-payload retry fails closed');
create temporary table t08_chat_upload(value jsonb) on commit drop;
insert into t08_chat_upload select public.v1_prepare_chat_attachment(
  jsonb_build_object('conversation_id',(select value#>>'{conversation,id}'
    from t08_discussion),'file_name','review-note.pdf','mime_type',
    'application/pdf','byte_size',11,'sha256',repeat('9',64)),
  '5a890000-0000-4000-8000-000000000008');
select is((select value->>'file_name' from t08_chat_upload),'review-note.pdf',
  'A dynamic Workforce member prepares a canonical Team Chat attachment');
grant select on t08_chat_upload to service_role;
reset role;
insert into storage.objects(id,bucket_id,name,owner_id,metadata)
select gen_random_uuid(),'yorks-chat-attachments',value->>'object_path',
  '10000000-0000-4000-8000-000000000001',
  '{"size":11,"mimetype":"application/pdf"}'::jsonb from t08_chat_upload;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select is(public.v1_verify_chat_attachment_upload(
  (select (value->>'attachment_id')::uuid from t08_chat_upload),repeat('9',64),
  11,'application/pdf')->>'attachment_id',
  (select value->>'attachment_id' from t08_chat_upload),
  'Service verification confirms the uploaded canonical Chat object');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
create temporary table t08_reply(value jsonb) on commit drop;
insert into t08_reply select public.v1_send_workforce_timesheet_message(
  jsonb_build_object('period_id','5a850000-0000-4000-8000-000000000001',
    'body','Reply with evidence','reply_to_message_id',
    (select value#>>'{message,id}' from t08_message),'attachment_ids',
    jsonb_build_array((select value->>'attachment_id' from t08_chat_upload))),
  '5a890000-0000-4000-8000-000000000009');
select is((select value#>>'{message,reply_preview,body}' from t08_reply),
  'Approved - discussion text only',
  'Canonical reply preview retains the replied Workforce message');
select is(jsonb_array_length((select value#>'{message,attachments}' from t08_reply)),1,
  'The finalized canonical attachment is linked to the Workforce reply');
select is(public.v1_send_workforce_timesheet_message(
  jsonb_build_object('period_id','5a850000-0000-4000-8000-000000000001',
    'body','Reply with evidence','reply_to_message_id',
    (select value#>>'{message,id}' from t08_message),'attachment_ids',
    jsonb_build_array((select value->>'attachment_id' from t08_chat_upload))),
  '5a890000-0000-4000-8000-000000000009')#>>'{message,id}',
  (select value#>>'{message,id}' from t08_reply),
  'Reply retry returns one canonical message and attachment effect');
select is(public.v1_download_chat_attachment(
  (select (value->>'attachment_id')::uuid from t08_chat_upload))->>'file_name',
  'review-note.pdf','An active dynamic member can download the attachment');
select is(public.v1_edit_chat_message(jsonb_build_object('message_id',
    (select value#>>'{message,id}' from t08_message),'body',
    'Edited discussion text','expected_version',1),
    '5a890000-0000-4000-8000-000000000010')->>'body',
  'Edited discussion text','Canonical message editing remains available');
reset role;
select is((select count(*) from public.v1_chat_message_revisions r
  where r.message_id=(select (value#>>'{message,id}')::uuid from t08_message)
    and r.operation='edit'),1::bigint,
  'The Workforce edit retains exactly one immutable prior revision');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
create temporary table t08_disposable(value jsonb) on commit drop;
insert into t08_disposable select public.v1_send_workforce_timesheet_message(
  '{"period_id":"5a850000-0000-4000-8000-000000000001","body":"Delete me"}',
  '5a890000-0000-4000-8000-000000000011');
select ok(public.v1_delete_chat_message(jsonb_build_object('message_id',
    (select value#>>'{message,id}' from t08_disposable),'expected_version',1),
    '5a890000-0000-4000-8000-000000000012')->>'deleted_at' is not null,
  'Canonical soft-delete retains a Workforce tombstone');
reset role;
select is((select current_status from public.v1_workforce_monthly_periods
  where id='5a850000-0000-4000-8000-000000000001'),'ready_for_review',
  'User-authored Approved text cannot mutate lifecycle state');
select is((select count(*) from public.v1_chat_messages m
  join public.v1_workforce_timesheet_discussions d
    on d.conversation_id=m.conversation_id
  where d.period_id='5a850000-0000-4000-8000-000000000001'
    and m.kind='message'),3::bigint,
  'Replies and soft-deleted messages retain exactly three canonical rows');
select is((select count(*) from public.v1_chat_attachments a
  join public.v1_workforce_timesheet_discussions d
    on d.conversation_id=a.conversation_id
  where d.period_id='5a850000-0000-4000-8000-000000000001'),1::bigint,
  'Attachment retry creates one retained attachment row');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);
select is(public.v1_mark_chat_delivered(array[(select
  (value#>>'{conversation,id}')::uuid from t08_discussion)]),1,
  'The scoped Site Engineer records canonical delivered state');
select ok(public.v1_mark_chat_read((select
  (value#>>'{conversation,id}')::uuid from t08_discussion)),
  'The scoped Site Engineer records canonical read state');
reset role;

-- Revoking dated responsibility makes static membership immediately powerless.
update public.v1_workforce_responsibility_assignments set valid_to='2026-07-31'
where id='5a870000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_get_workforce_collaboration(
  '5a850000-0000-4000-8000-000000000001')$$,'42501',
  'V1_WORKFORCE_T08_COLLABORATION_DENIED',
  'Stale static chat membership never retains Workforce access');
select throws_ok($$select public.v1_send_workforce_timesheet_message(
  '{"period_id":"5a850000-0000-4000-8000-000000000001","body":"Revoked reply"}',
  '5a890000-0000-4000-8000-000000000013')$$,'42501',
  'V1_WORKFORCE_T08_MESSAGE_DENIED',
  'A revoked static member cannot reply');
select throws_ok($$select public.v1_prepare_chat_attachment(
  jsonb_build_object('conversation_id',(select value#>>'{conversation,id}'
    from t08_discussion),'file_name','revoked.pdf','mime_type',
    'application/pdf','byte_size',1,'sha256',repeat('7',64)),
  '5a890000-0000-4000-8000-000000000014')$$,'42501',
  'V1_CHAT_ATTACHMENT_DENIED','A revoked static member cannot attach');
select throws_ok($$select public.v1_download_chat_attachment(
  (select (value->>'attachment_id')::uuid from t08_chat_upload))$$,'42501',
  'V1_CHAT_ATTACHMENT_READ_DENIED','A revoked static member cannot download');
select ok(not public.v1_chat_attachment_readable('yorks-chat-attachments',
  (select value->>'object_path' from t08_chat_upload)),
  'Storage readability also fails closed after responsibility revocation');
select is((select count(*) from jsonb_array_elements(
  public.v1_list_chat_conversations()) c where c->>'id'=(
    select value#>>'{conversation,id}' from t08_discussion)),0::bigint,
  'Revoked discussions disappear from the canonical chat list');
reset role;
update public.v1_workforce_responsibility_assignments set valid_to='2026-12-31'
where id='5a870000-0000-4000-8000-000000000001';

-- An authoritative event appends one immutable system event and sends only to
-- currently capability-and-responsibility-authorized recipients.
insert into public.v1_audit_events(id,event_type,entity_type,entity_id,project_id,
  actor_auth_user_id,actor_role,idempotency_key,after_data,request_hash)
values('5a880000-0000-4000-8000-000000000001',
  'workforce_monthly_period_submitted','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000001','project_engineer',
  '5a890000-0000-4000-8000-000000000005','{}',repeat('a',64));
select is((select count(*) from public.v1_chat_messages m where
  m.source_audit_event_id='5a880000-0000-4000-8000-000000000001'),1::bigint,
  'An authoritative audit event creates one non-editable system event');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000001'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000002'),
  1::bigint,'A currently scoped reviewer receives the submitted notification');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000001'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000003'),
  0::bigint,'Role-only Procurement receives no Workforce notification');
select is((select count(*) from public.v1_notification_push_outbox o
  join public.v1_workforce_notification_deliveries d
    on d.notification_id=o.notification_id
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000001'),
  (select count(*) from public.v1_workforce_notification_deliveries d
    where d.source_audit_event_id='5a880000-0000-4000-8000-000000000001'),
  'Each authorized lifecycle recipient reuses exactly one trusted push-outbox row');
create temporary table t08_system(value uuid) on commit drop;
insert into t08_system select m.id from public.v1_chat_messages m
  where m.source_audit_event_id='5a880000-0000-4000-8000-000000000001';
grant select on t08_system to authenticated;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok($$select public.v1_edit_chat_message(jsonb_build_object(
  'message_id',(select value from t08_system),
  'body','Forge lifecycle','expected_version',1),
  '5a890000-0000-4000-8000-000000000015')$$,'42501',
  'V1_CHAT_MESSAGE_EDIT_DENIED','Workforce system events cannot be edited');
select throws_ok($$select public.v1_delete_chat_message(jsonb_build_object(
  'message_id',(select value from t08_system),
  'expected_version',1),
  '5a890000-0000-4000-8000-000000000016')$$,'42501',
  'V1_CHAT_MESSAGE_DELETE_DENIED','Workforce system events cannot be deleted');
reset role;

insert into public.v1_audit_events(id,event_type,entity_type,entity_id,project_id,
  actor_auth_user_id,actor_role,idempotency_key,after_data,request_hash) values
('5a880000-0000-4000-8000-000000000002',
  'workforce_monthly_period_returned','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000002','site_engineer',
  '5a890000-0000-4000-8000-000000000030','{}',repeat('b',64)),
('5a880000-0000-4000-8000-000000000003',
  'workforce_monthly_reviewer_correction','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000002','site_engineer',
  '5a890000-0000-4000-8000-000000000031','{}',repeat('c',64)),
('5a880000-0000-4000-8000-000000000004',
  'workforce_monthly_period_verified','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000002','site_engineer',
  '5a890000-0000-4000-8000-000000000032','{}',repeat('d',64)),
('5a880000-0000-4000-8000-000000000005',
  'workforce_monthly_period_approved_and_locked','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000004','admin',
  '5a890000-0000-4000-8000-000000000033','{}',repeat('e',64)),
('5a880000-0000-4000-8000-000000000006',
  'workforce_monthly_reopen_requested','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000001','project_engineer',
  '5a890000-0000-4000-8000-000000000034','{}',repeat('f',64));

update public.v1_configuration_settings set published_value='false'::jsonb
  where setting_key='notifications.push_enabled';
insert into public.v1_audit_events(id,event_type,entity_type,entity_id,project_id,
  actor_auth_user_id,actor_role,idempotency_key,after_data,request_hash)
values('5a880000-0000-4000-8000-000000000007',
  'workforce_monthly_reopen_authorized','workforce_monthly_period',
  '5a850000-0000-4000-8000-000000000001',null,
  '10000000-0000-4000-8000-000000000004','admin',
  '5a890000-0000-4000-8000-000000000035','{}',repeat('1',64));
update public.v1_configuration_settings set published_value='true'::jsonb
  where setting_key='notifications.push_enabled';

select is((select count(*) from public.v1_chat_messages m where
  m.source_audit_event_id between
    '5a880000-0000-4000-8000-000000000001'::uuid and
    '5a880000-0000-4000-8000-000000000007'::uuid),7::bigint,
  'Every T07 lifecycle event produces exactly one immutable system event');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000002'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.event_code='workforce_period_returned'),1::bigint,
  'Returned notifies the exact scoped Project Engineer maintainer');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000003'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.event_code='workforce_correction_completed'),1::bigint,
  'Reviewer correction completion notifies the scoped maintainer');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000004'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.event_code='workforce_period_verified'),1::bigint,
  'Verify and Forward notifies the scoped maintainer');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000004'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000004'
    and d.event_code='workforce_final_approval_required'),1::bigint,
  'Verify and Forward separately notifies exact final approval authority');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000005'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.event_code='workforce_period_approved_locked'),1::bigint,
  'Approval and lock notifies the scoped maintainer');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000006'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000004'
    and d.event_code='workforce_reopen_requested'),1::bigint,
  'Reopen request notifies exact reopen authority');
select is((select count(*) from public.v1_workforce_notification_deliveries d
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000007'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.event_code='workforce_reopen_approved'),1::bigint,
  'Reopen approval retains one in-app notification while Push is disabled');
select is((select count(*) from public.v1_notification_push_outbox o
  join public.v1_workforce_notification_deliveries d
    on d.notification_id=o.notification_id
  where d.source_audit_event_id='5a880000-0000-4000-8000-000000000007'),
  0::bigint,'Push-disabled lifecycle delivery creates no Push job');
select ok(not exists(select 1 from public.v1_workforce_notification_deliveries d
  join public.v1_audit_events a on a.id=d.source_audit_event_id
  where a.id between '5a880000-0000-4000-8000-000000000001'::uuid and
      '5a880000-0000-4000-8000-000000000007'::uuid
    and (d.recipient_auth_user_id=a.actor_auth_user_id
      or d.recipient_auth_user_id in (
        '10000000-0000-4000-8000-000000000003',
        '10000000-0000-4000-8000-000000000009',
        '10000000-0000-4000-8000-000000000010'))),
  'Self, role-only, inactive and out-of-scope recipients receive nothing');
select ok(not exists(select 1 from public.v1_workforce_notification_deliveries d
  join public.v1_notification_push_outbox o on o.notification_id=d.notification_id
  where d.source_audit_event_id between
      '5a880000-0000-4000-8000-000000000001'::uuid and
      '5a880000-0000-4000-8000-000000000007'::uuid
  group by d.notification_id having count(*)>1),
  'Every lifecycle in-app notification has at most one Push transport job');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_worker","entity_id":"5a840000-0000-4000-8000-000000000002","classification":"operational","file_name":"transfer.pdf","mime_type":"application/pdf","byte_size":9,"sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","evidence_type":"worker_transfer_note"}',
  '5a890000-0000-4000-8000-000000000020')$$,
  'A canonical worker target does not require a duplicate worker_id');
select lives_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_attendance_day","entity_id":"5a845000-0000-4000-8000-000000000002","classification":"operational","file_name":"internal-day.png","mime_type":"image/png","byte_size":9,"sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","evidence_type":"daily_supporting_photo","worker_id":"5a840000-0000-4000-8000-000000000002"}',
  '5a890000-0000-4000-8000-000000000021')$$,
  'A projectless internal attendance target derives its retained worker');
select lives_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_monthly_period","entity_id":"5a850000-0000-4000-8000-000000000001","classification":"operational","file_name":"coherent.pdf","mime_type":"application/pdf","byte_size":9,"sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","evidence_type":"monthly_timesheet_attachment","worker_id":"5a840000-0000-4000-8000-000000000001","attendance_day_id":"5a845000-0000-4000-8000-000000000001"}',
  '5a890000-0000-4000-8000-000000000022')$$,
  'A coherent day, worker and period link resolves from the exact retained run');
select throws_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_monthly_period","entity_id":"5a850000-0000-4000-8000-000000000001","classification":"operational","file_name":"forged-worker.pdf","mime_type":"application/pdf","byte_size":9,"sha256":"eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee","evidence_type":"monthly_timesheet_attachment","worker_id":"5a840000-0000-4000-8000-000000000002"}',
  '5a890000-0000-4000-8000-000000000023')$$,'22023',
  'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH',
  'A worker outside the period current retained source is rejected');
select throws_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_monthly_period","entity_id":"5a850000-0000-4000-8000-000000000001","classification":"operational","file_name":"forged-day.pdf","mime_type":"application/pdf","byte_size":9,"sha256":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","evidence_type":"monthly_timesheet_attachment","worker_id":"5a840000-0000-4000-8000-000000000002","attendance_day_id":"5a845000-0000-4000-8000-000000000002"}',
  '5a890000-0000-4000-8000-000000000024')$$,'22023',
  'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH',
  'A day outside the period exact retained source is rejected');
select throws_ok($$select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_worker","entity_id":"5a840000-0000-4000-8000-000000000001","classification":"operational","file_name":"wrong-primary.pdf","mime_type":"application/pdf","byte_size":9,"sha256":"abababababababababababababababababababababababababababababababab","evidence_type":"worker_transfer_note","worker_id":"5a840000-0000-4000-8000-000000000002"}',
  '5a890000-0000-4000-8000-000000000025')$$,'22023',
  'V1_WORKFORCE_DOCUMENT_TARGET_INVALID',
  'A supplied primary identity cannot contradict the canonical target');
reset role;
select is((select count(*) from public.v1_document_upload_intents i
  where i.idempotency_key in (
    '5a890000-0000-4000-8000-000000000023',
    '5a890000-0000-4000-8000-000000000024',
    '5a890000-0000-4000-8000-000000000025')),0::bigint,
  'Context mismatches create no upload intent or storage authority side effect');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
create temporary table t08_upload(value jsonb) on commit drop;
insert into t08_upload select public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_monthly_period","entity_id":"5a850000-0000-4000-8000-000000000001","classification":"operational","file_name":"timesheet.pdf","mime_type":"application/pdf","byte_size":10,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","evidence_type":"monthly_timesheet_attachment","worker_id":"5a840000-0000-4000-8000-000000000001","attendance_day_id":"5a845000-0000-4000-8000-000000000001"}',
  '5a890000-0000-4000-8000-000000000006');
select is(value->>'schema_version','yorks.workforce.document-upload.v1',
  'Authorized evidence preparation reuses the canonical Documents intent')
from t08_upload;
select is(public.v1_prepare_workforce_document_upload(
  '{"entity_type":"workforce_monthly_period","entity_id":"5a850000-0000-4000-8000-000000000001","classification":"operational","file_name":"timesheet.pdf","mime_type":"application/pdf","byte_size":10,"sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","evidence_type":"monthly_timesheet_attachment","worker_id":"5a840000-0000-4000-8000-000000000001","attendance_day_id":"5a845000-0000-4000-8000-000000000001"}',
  '5a890000-0000-4000-8000-000000000006')->>'upload_intent_id',
  (select value->>'upload_intent_id' from t08_upload),
  'Evidence intent retry returns one upload target');
grant select on t08_upload to service_role;
reset role;

insert into storage.objects(id,bucket_id,name,owner_id,metadata)
select gen_random_uuid(),'yorks-documents',value->>'object_path',
  '10000000-0000-4000-8000-000000000004',
  '{"size":10,"mimetype":"application/pdf"}'::jsonb from t08_upload;
set local role service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create temporary table t08_finalized(value jsonb) on commit drop;
insert into t08_finalized select public.v1_create_document_version(
  (select (value->>'upload_intent_id')::uuid from t08_upload),
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',10,
  'application/pdf');
select is(value->>'revision_number','1',
  'Service finalization creates canonical immutable version one')
from t08_finalized;
reset role;
select is((select count(*) from public.v1_workforce_document_version_metadata m
  where m.period_id='5a850000-0000-4000-8000-000000000001'),1::bigint,
  'Finalization retains the exact Workforce evidence type and entity links');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select is(jsonb_array_length(public.v1_list_workforce_documents(
  '5a850000-0000-4000-8000-000000000001',null,null)->'documents'),1,
  'An authorized maintainer reads evidence with immutable version history');
select ok(public.v1_storage_document_readable('yorks-documents',
  (select value->>'object_path' from t08_upload)),
  'Authorized download is granted only through entity-aware document policy');
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',true);
select is(jsonb_array_length(public.v1_list_workforce_documents(
  '5a850000-0000-4000-8000-000000000001',null,null)->'documents'),0,
  'Unauthorized document projection leaks no evidence metadata');
select ok(not public.v1_storage_document_readable('yorks-documents',
  (select value->>'object_path' from t08_upload)),
  'Knowing a private object path does not authorize download');
reset role;

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select lives_ok($$select public.v1_dispatch_workforce_notification_digest(
  '{"digest_kind":"monthly_period_incomplete","team_id":"5a830000-0000-4000-8000-000000000001","period_id":"5a850000-0000-4000-8000-000000000001"}',
  '5a890000-0000-4000-8000-000000000007')$$,
  'Admin explicitly dispatches one aggregate incomplete-period digest');
select lives_ok($$select public.v1_dispatch_workforce_notification_digest(
  '{"digest_kind":"monthly_period_incomplete","team_id":"5a830000-0000-4000-8000-000000000001","period_id":"5a850000-0000-4000-8000-000000000001"}',
  '5a890000-0000-4000-8000-000000000007')$$,
  'Digest same-key retry is stable');
reset role;
select is((select count(*) from public.v1_workforce_notification_digests d
  where d.period_id='5a850000-0000-4000-8000-000000000001'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'),
  1::bigint,'Aggregate digest creates one recipient/window effect, not worker spam');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',true);
select is(public.v1_dispatch_workforce_notification_digest(
  '{"digest_kind":"daily_attendance_missing","team_id":"5a830000-0000-4000-8000-000000000001","work_date":"2026-08-15"}',
  '5a890000-0000-4000-8000-000000000050')->>'item_count','501',
  'Daily missing digest counts every eligible worker beyond the first page');
select is(public.v1_dispatch_workforce_notification_digest(
  '{"digest_kind":"daily_attendance_missing","team_id":"5a830000-0000-4000-8000-000000000001","work_date":"2026-08-15"}',
  '5a890000-0000-4000-8000-000000000050')->>'item_count','501',
  'Daily digest same-key retry retains the complete count');
reset role;
select is((select count(*) from public.v1_workforce_notification_digests d
  where d.digest_kind='daily_attendance_missing'
    and d.team_id='5a830000-0000-4000-8000-000000000001'
    and d.work_date='2026-08-15'
    and d.recipient_auth_user_id='10000000-0000-4000-8000-000000000001'
    and d.item_count=501),1::bigint,
  'The complete daily window creates one aggregate recipient effect');

select throws_ok($$delete from public.v1_workforce_notification_deliveries
  where source_audit_event_id='5a880000-0000-4000-8000-000000000001'$$,
  '42501','V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Notification delivery history cannot be hard-deleted');

select * from finish();
rollback;
