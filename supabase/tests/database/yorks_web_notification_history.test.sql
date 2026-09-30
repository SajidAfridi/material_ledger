begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id,created_at)
select ('a3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 '10000000-0000-4000-8000-000000000003','material_request_submitted','material_request',
 'a4000000-0000-4000-8000-000000000001',now() from generate_series(1,10000) i;
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id,created_at)
values('a3000000-0000-4000-8000-000000010001','10000000-0000-4000-8000-000000000003',
 'team_chat_message','chat_message','a4000000-0000-4000-8000-000000000001',now());
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select is(jsonb_array_length(public.v1_notification_page()->'records'),101,'page has one lookahead row at 10k scale');
select ok((public.v1_notification_page()->>'unreadCount')::int >= 10000,'unread count includes history outside page');
select ok(exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r where r->>'event_code'='team_chat_message'),'Chat attention comes from real protected RPC');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'records') r where r->>'event_code'='team_chat_message'),'workflow history excludes Chat');
select is(public.v1_notification_page()->'records'->0->>'notification_id','a3000000-0000-4000-8000-000000010000','equal timestamps have stable descending ID order');
select is(public.v1_notification_page(100,now(),'a3000000-0000-4000-8000-000000009901')->'records'->0->>'notification_id','a3000000-0000-4000-8000-000000009900','cursor has no repeats or gaps');
select throws_ok($$select public.v1_notification_page(100,now(),null)$$,'22023','V1_NOTIFICATION_CURSOR_INVALID','partial cursor rejected');
select public.v1_mark_all_notifications_seen();
select is(jsonb_array_length(public.v1_notification_page(p_unread_only=>true)->'records'),0,'mark all covers workflow history beyond page');
select is(jsonb_array_length(public.v1_notification_page()->'attention'),1,'mark all never consumes Chat cursor');
select is(public.v1_notification_page()->>'servicePaused','true','service pause is visible without exposing credentials');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'records') r where r->>'notification_id' like 'a300%'),'Admin cannot read another recipient inbox');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select lives_ok($$select public.v1_notification_page()$$,'Project Engineer reads own inbox');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer"}}',true);
select lives_ok($$select public.v1_notification_page()$$,'Site Engineer reads own inbox');
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'records') r where r->>'notification_id' like 'a300%'),'Site Engineer cannot see another recipient');
set local role anon;
select throws_ok($$select public.v1_notification_page()$$,'42501',null,'anonymous reads denied');
set local role postgres;
update public.v1_profiles set is_active=false where auth_user_id='10000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement"}}',true);
select throws_ok($$select public.v1_notification_page()$$,'42501','V1_NOTIFICATION_LIST_DENIED','inactive recipient denied');
select * from finish();
rollback;
