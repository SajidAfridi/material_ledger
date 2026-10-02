begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

insert into public.v1_workforce_teams(id,team_code,team_name,valid_from,is_active,
 created_by_auth_user_id,updated_by_auth_user_id)
values('af420000-0000-4000-8000-000000000001','PUSH-ROUTE','Digest route team',
 '2026-08-01',true,'10000000-0000-4000-8000-000000000004',
 '10000000-0000-4000-8000-000000000004');
set constraints all deferred;
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id)
select ('af430000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 '10000000-0000-4000-8000-000000000004','workforce_daily_attendance_missing',
 'workforce_daily_roster',case when i=3 then 'af420000-0000-4000-8000-000000000099'::uuid
 else 'af420000-0000-4000-8000-000000000001'::uuid end
from generate_series(1,4) i;
insert into public.v1_workforce_notification_digests(digest_kind,team_id,work_date,
 recipient_auth_user_id,item_count,notification_id,idempotency_key)
values
 ('daily_attendance_missing','af420000-0000-4000-8000-000000000001','2026-08-15',
 '10000000-0000-4000-8000-000000000004',1,'af430000-0000-4000-8000-000000000001',gen_random_uuid()),
 ('daily_attendance_missing','af420000-0000-4000-8000-000000000001','2026-08-16',
 '10000000-0000-4000-8000-000000000004',1,'af430000-0000-4000-8000-000000000003',gen_random_uuid()),
 ('daily_attendance_missing','af420000-0000-4000-8000-000000000001','2026-08-17',
 '10000000-0000-4000-8000-000000000001',1,'af430000-0000-4000-8000-000000000004',gen_random_uuid());
select is(public.v1_notification_module_route(n),
 '/yorks/workforce/attendance?team_id=af420000-0000-4000-8000-000000000001&date=2026-08-15',
 'Daily digest resolves its exact protected team and date')
from public.v1_notifications n where id='af430000-0000-4000-8000-000000000001';
select is(public.v1_notification_module_route(n),null,
 'Daily alert without protected digest metadata has no invented target')
from public.v1_notifications n where id='af430000-0000-4000-8000-000000000002';
select is(public.v1_notification_module_route(n),null,
 'Digest team must match the notification entity')
from public.v1_notifications n where id='af430000-0000-4000-8000-000000000003';
select is(public.v1_notification_module_route(n),null,
 'Digest recipient must match the notification recipient')
from public.v1_notifications n where id='af430000-0000-4000-8000-000000000004';
select ok(not has_function_privilege('authenticated',
 'public.v1_notification_module_route(public.v1_notifications)','EXECUTE'),
 'Authenticated users cannot invoke the private route resolver');
select ok(not has_function_privilege('anon',
 'public.v1_notification_module_route(public.v1_notifications)','EXECUTE'),
 'Anonymous users cannot invoke the private route resolver');
set local role authenticated;
select set_config('request.jwt.claims',
 '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select is((select r->>'module_route' from jsonb_array_elements(public.v1_notification_page()->'records') r
 where r->>'notification_id'='af430000-0000-4000-8000-000000000001'),
 '/yorks/workforce/attendance?team_id=af420000-0000-4000-8000-000000000001&date=2026-08-15',
 'The recipient inbox carries the exact daily destination');
reset role;
select * from finish();
rollback;
