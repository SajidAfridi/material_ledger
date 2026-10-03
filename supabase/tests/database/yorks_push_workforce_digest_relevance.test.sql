begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

-- A real dated team, schedule, worker and assignment. No helper is stubbed:
-- the same attendance command and permission resolver used by the app run here.
insert into public.v1_workforce_internal_locations(id,location_code,location_name,
 department,is_active,created_by_auth_user_id,updated_by_auth_user_id)
values('af310000-0000-4000-8000-000000000001','PUSH-DIGEST','Digest workshop',
 'Workshop',true,'10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_teams(id,team_code,team_name,valid_from,valid_to,
 is_active,created_by_auth_user_id,updated_by_auth_user_id)
values('af320000-0000-4000-8000-000000000001','PUSH-DIGEST','Digest team',
 '2026-08-01','2026-08-31',true,'10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendars(id,calendar_code,calendar_name,timezone_name,
 standard_scheduled_minutes,break_minutes,valid_from,valid_to,is_active,
 created_by_auth_user_id,updated_by_auth_user_id)
values('af330000-0000-4000-8000-000000000001','PUSH-DIGEST','Digest calendar','Asia/Dubai',
 480,0,'2026-08-01','2026-08-31',true,'10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_calendar_weekdays(calendar_id,iso_weekday,day_type,
 created_by_auth_user_id,updated_by_auth_user_id)
select 'af330000-0000-4000-8000-000000000001',i,'regular_working_day',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004'
from generate_series(1,7) i;
insert into public.v1_workforce_team_schedule_links(id,team_id,calendar_id,
 valid_from,valid_to,reason,created_by_auth_user_id,updated_by_auth_user_id)
values('af340000-0000-4000-8000-000000000001','af320000-0000-4000-8000-000000000001',
 'af330000-0000-4000-8000-000000000001','2026-08-01','2026-08-31','Digest schedule',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_workers(id,worker_number,full_name,designation,
 employer_company,worker_type,joining_date,current_status,
 created_by_auth_user_id,updated_by_auth_user_id)
values('af350000-0000-4000-8000-000000000001','PUSH-DIGEST-1','Digest worker','Technician',
 'Yorks AC & Ref.','yorks_employee','2026-08-01','active',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004'),
 ('af350000-0000-4000-8000-000000000002','PUSH-DIGEST-2','Second digest worker','Technician',
 'Yorks AC & Ref.','yorks_employee','2026-08-01','active',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_worker_assignments(id,worker_id,assignment_kind,
 team_id,internal_location_id,valid_from,valid_to,reason,assigned_by_auth_user_id,
 assigned_by_exact_role,updated_by_auth_user_id)
values('af360000-0000-4000-8000-000000000001','af350000-0000-4000-8000-000000000001',
 'primary','af320000-0000-4000-8000-000000000001','af310000-0000-4000-8000-000000000001',
 '2026-08-01','2026-08-31','Digest assignment','10000000-0000-4000-8000-000000000004',
 'admin','10000000-0000-4000-8000-000000000004'),
 ('af360000-0000-4000-8000-000000000002','af350000-0000-4000-8000-000000000002',
 'primary','af320000-0000-4000-8000-000000000001','af310000-0000-4000-8000-000000000001',
 '2026-08-01','2026-08-31','Second digest assignment','10000000-0000-4000-8000-000000000004',
 'admin','10000000-0000-4000-8000-000000000004');

-- Exact roles alone are not Workforce authority. Give each non-Admin persona
-- the same explicit capability and dated responsibility for this fixture.
insert into public.v1_permission_assignments(auth_user_id,capability_key,effect,
 scope_kind,origin,effective_from,reason,changed_by_auth_user_id)
select ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,c,'grant',
 'organization','permission_management','2026-01-01','Digest scope matrix',
 '10000000-0000-4000-8000-000000000004'
from generate_series(1,3) i cross join unnest(array['workforce.view',
 'workforce.attendance.maintain','workforce.timesheets.maintain']) c
on conflict(auth_user_id,capability_key,scope_kind,effect) do nothing;
insert into public.v1_workforce_responsibility_assignments(auth_user_id,scope_kind,
 valid_from,valid_to,reason,assigned_by_auth_user_id,assigned_by_exact_role,updated_by_auth_user_id)
select ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'organization',
 '2026-08-01','2026-08-31','Digest responsibility matrix',
 '10000000-0000-4000-8000-000000000004','admin','10000000-0000-4000-8000-000000000004'
from generate_series(1,4) i;

set constraints all deferred;
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id)
select ('af370000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'workforce_daily_attendance_missing','workforce_daily_roster','af320000-0000-4000-8000-000000000001'
from generate_series(1,4) i;
insert into public.v1_workforce_notification_digests(digest_kind,team_id,work_date,
 recipient_auth_user_id,item_count,notification_id,idempotency_key)
select 'daily_attendance_missing','af320000-0000-4000-8000-000000000001','2026-08-15',
 recipient_auth_user_id,2,id,gen_random_uuid()
from public.v1_notifications where id::text like 'af370000%';
select ok(public.v1_push_notification_entity_allowed(n),
 'Missing daily attendance is actionable for scoped '||public.v1_permission_exact_role(n.recipient_auth_user_id))
from public.v1_notifications n where id::text like 'af370000%';

set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select lives_ok($$select public.v1_save_workforce_attendance_day(
 '{"worker_id":"af350000-0000-4000-8000-000000000001","work_date":"2026-08-15","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Attendance completed after digest"}',
 null,'af380000-0000-4000-8000-000000000001')$$,'Trusted attendance command resolves the queued missing-day fact');
reset role;
select ok(public.v1_push_notification_entity_allowed(n),
 'Partial completion keeps the remaining missing attendance actionable for '||public.v1_permission_exact_role(n.recipient_auth_user_id))
from public.v1_notifications n where id::text like 'af370000%';
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select lives_ok($$select public.v1_save_workforce_attendance_day(
 '{"worker_id":"af350000-0000-4000-8000-000000000002","work_date":"2026-08-15","attendance_status":"present","regular_minutes":480,"overtime_minutes":0,"reason":"Remaining attendance completed after digest"}',
 null,'af380000-0000-4000-8000-000000000002')$$,'Completing the remaining worker resolves the digest');
reset role;
select ok(not public.v1_push_notification_entity_allowed(n),
 'Completed daily attendance suppresses queued attention for '||public.v1_permission_exact_role(n.recipient_auth_user_id))
from public.v1_notifications n where id::text like 'af370000%';
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='af370000-0000-4000-8000-000000000001'),
 'Resolved daily digest is absent from fresh foreground attention');
select ok(exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'records') r
 where r->>'notification_id'='af370000-0000-4000-8000-000000000001'),
 'Resolved daily digest keeps its authoritative inbox history');
reset role;

-- A complete new validation and a submitted review both resolve the previous
-- incomplete-period prompt, without deleting that original digest.
insert into public.v1_workforce_monthly_periods(id,team_id,period_month,
 current_validation_run_id,current_validation_number,current_status,
 created_by_auth_user_id,updated_by_auth_user_id)
values('af390000-0000-4000-8000-000000000001','af320000-0000-4000-8000-000000000001',
 '2026-08-01','af3a0000-0000-4000-8000-000000000001',1,'draft',
 '10000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000004');
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
 validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
 missing_day_count,blocking_issue_count,authority_snapshot,validated_by_auth_user_id,
 validated_by_exact_role,idempotency_key)
values('af3a0000-0000-4000-8000-000000000001','af390000-0000-4000-8000-000000000001',
 1,'draft',repeat('a',64),1,1,1,1,1,'{}',
 '10000000-0000-4000-8000-000000000004','admin','af3b0000-0000-4000-8000-000000000001');
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id)
values('af3c0000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004',
 'workforce_monthly_period_incomplete','workforce_monthly_period','af390000-0000-4000-8000-000000000001');
select ok(public.v1_push_notification_entity_allowed(n),'Incomplete draft period remains actionable')
from public.v1_notifications n where id='af3c0000-0000-4000-8000-000000000001';
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
 validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
 missing_day_count,blocking_issue_count,authority_snapshot,validated_by_auth_user_id,
 validated_by_exact_role,idempotency_key)
values('af3a0000-0000-4000-8000-000000000002','af390000-0000-4000-8000-000000000001',
 2,'ready_for_review',repeat('b',64),1,1,1,0,0,'{}',
 '10000000-0000-4000-8000-000000000004','admin','af3b0000-0000-4000-8000-000000000002');
update public.v1_workforce_monthly_periods set current_validation_run_id='af3a0000-0000-4000-8000-000000000002',
 current_validation_number=2,current_status='ready_for_review',record_version=record_version+1
 where id='af390000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'A complete new validation suppresses the old incomplete digest')
from public.v1_notifications n where id='af3c0000-0000-4000-8000-000000000001';
insert into public.v1_workforce_monthly_validation_runs(id,period_id,validation_number,
 validation_status,source_fingerprint,worker_count,date_count,scheduled_day_count,
 warning_issue_count,authority_snapshot,validated_by_auth_user_id,
 validated_by_exact_role,idempotency_key)
values('af3a0000-0000-4000-8000-000000000003','af390000-0000-4000-8000-000000000001',
 3,'ready_for_review',repeat('c',64),1,1,1,1,'{}',
 '10000000-0000-4000-8000-000000000004','admin','af3b0000-0000-4000-8000-000000000003');
update public.v1_workforce_monthly_periods set current_validation_run_id='af3a0000-0000-4000-8000-000000000003',
 current_validation_number=3,record_version=record_version+1 where id='af390000-0000-4000-8000-000000000001';
select ok(public.v1_push_notification_entity_allowed(n),'Current unacknowledged validation warnings remain actionable')
from public.v1_notifications n where id='af3c0000-0000-4000-8000-000000000001';
insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
 action_kind,from_status,to_status,from_record_version,to_record_version,validation_run_id,
 source_fingerprint,actor_auth_user_id,actor_exact_role,capability_key,reason,idempotency_key)
values('af390000-0000-4000-8000-000000000001',1,'submit','ready_for_review','submitted',3,4,
 'af3a0000-0000-4000-8000-000000000003',repeat('c',64),'10000000-0000-4000-8000-000000000004',
 'admin','workforce.timesheets.maintain','Warnings acknowledged at submission','af3b0000-0000-4000-8000-000000000004');
update public.v1_workforce_monthly_periods set current_status='submitted',record_version=record_version+1,
 current_approval_revision_number=1 where id='af390000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Submission suppresses the previous correction prompt even with retained issue evidence')
from public.v1_notifications n where id='af3c0000-0000-4000-8000-000000000001';
insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
 action_kind,from_status,to_status,from_record_version,to_record_version,validation_run_id,
 source_fingerprint,actor_auth_user_id,actor_exact_role,capability_key,reason,idempotency_key)
values('af390000-0000-4000-8000-000000000001',1,'reviewer_correction','submitted','under_review',4,5,
 'af3a0000-0000-4000-8000-000000000003',repeat('c',64),'10000000-0000-4000-8000-000000000002',
 'site_engineer','workforce.timesheets.correct_during_review','Review began','af3b0000-0000-4000-8000-000000000005');
update public.v1_workforce_monthly_periods set current_status='under_review',record_version=record_version+1
 where id='af390000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'A period already in review receives no incomplete digest')
from public.v1_notifications n where id='af3c0000-0000-4000-8000-000000000001';

select * from finish();
rollback;
