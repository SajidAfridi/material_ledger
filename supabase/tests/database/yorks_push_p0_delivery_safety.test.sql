begin;
-- Isolate transport behavior for synthetic entity IDs. Real entity access,
-- revocation and action-state checks run in yorks_push_entity_access.test.sql.
create or replace function public.v1_push_notification_entity_allowed(n public.v1_notifications)
returns boolean language sql stable security definer set search_path='' as $$select true$$;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(42);

select ok((select operator_paused from public.v1_push_transport_control where id),
  'Transport defaults paused after migration');
select ok(not has_function_privilege('authenticated',
  'public.v1_push_backend_health()','execute')
  and not has_function_privilege('anon',
  'public.v1_push_backend_health()','execute')
  and has_function_privilege('service_role',
  'public.v1_push_backend_health()','execute'),
  'Only trusted service can read health projection');
select ok(not has_function_privilege('service_role',
  'public.v1_finish_notification_push(uuid,text,integer,text)','execute')
  and has_function_privilege('service_role',
  'public.v1_finish_notification_push(uuid,uuid,text,integer,text,integer)',
  'execute'), 'Unfenced finish is unavailable to the sender');
select is((public.v1_push_backend_health() ->> 'operatorPaused'),
  'true', 'Health reports pause state');

insert into public.v1_notifications
  (id,recipient_auth_user_id,event_code,entity_type,entity_id)
values
 ('9c000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000001'),
 ('9c000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000002'),
 ('9c000000-0000-4000-8000-000000000003',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000003');

select is((select count(*) from public.v1_notification_push_outbox
  where notification_id in (
    '9c000000-0000-4000-8000-000000000001',
    '9c000000-0000-4000-8000-000000000002',
    '9c000000-0000-4000-8000-000000000003')),
  3::bigint, 'Paused transport retains all in-app and outbox history');
select is(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000001'), null::jsonb,
  'Paused transport cannot claim');
update public.v1_push_transport_control set operator_paused=false where id;

-- A dispatcher reservation is required. One claim consumes it atomically.
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
  where notification_id='9c000000-0000-4000-8000-000000000001';
select ok((public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000001') ->> 'claimId') is not null,
  'One worker receives a server-generated claim');
select is(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000001'), null::jsonb,
  'Competing worker cannot claim an active lease');

create temporary table push_claim_a as
select claim_id from public.v1_notification_push_outbox
where notification_id='9c000000-0000-4000-8000-000000000001';
update public.v1_notification_push_outbox set
  lease_until=clock_timestamp()-interval '1 second'
where notification_id='9c000000-0000-4000-8000-000000000001';
select lives_ok($$select public.v1_dispatch_pending_pushes()$$,
  'Expired pre-send lease is recovered by the dispatcher');
select is((select status from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000001'),
  'retry_wait','Pre-send timeout returns to the finite retry queue');
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id='9c000000-0000-4000-8000-000000000001';
select ok((public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000001') ->> 'claimId') is not null,
  'A replacement worker receives a different claim');
select ok((select claim_id from push_claim_a) is distinct from
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000001'),
  'Claim generations differ');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000001',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000001'),
  'sent',1,null,null),true,
  'Replacement worker records success');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000001',
  (select claim_id from push_claim_a),
  'retryable',0,'FCM_UNAVAILABLE',null),false,
  'Stalled worker cannot overwrite replacement success');
select is((select status from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000001'),
  'sent','Successful terminal state survives a stale failure');

-- Transient backoff and maximum attempts are owned by SQL, not HTTP status.
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
  where notification_id='9c000000-0000-4000-8000-000000000002';
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000002') is not null,
  'Transient fixture claims once');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000002',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000002'),
  'retryable',0,'QUOTA_EXCEEDED',120),true,
  'Rate limit schedules a server-owned retry');
select ok((select status='retry_wait' and
  next_attempt_at>=clock_timestamp()+interval '119 seconds'
  from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000002'),
  'Retry-After is honored with nonnegative jitter');
update public.v1_notification_push_outbox set
  attempt_count=5,next_attempt_at=clock_timestamp(),
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
  where notification_id='9c000000-0000-4000-8000-000000000002';
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000002') is not null,
  'Sixth and final attempt is allowed');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000002',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000002'),
  'retryable',0,'FCM_UNAVAILABLE',null),true,
  'Exhausted attempt finalizes');
select ok((select status='dead_letter' and attempt_count=6 and
  terminal_at is not null from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000002'),
  'Sixth failure is terminal without rewriting attempt history');
select is(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000002'),null::jsonb,
  'Dead-letter delivery cannot be reclaimed');

insert into public.v1_notifications
  (id,recipient_auth_user_id,event_code,entity_type,entity_id)
values
 ('9c000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000004'),
 ('9c000000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000005'),
 ('9c000000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000006');
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id in (
  '9c000000-0000-4000-8000-000000000004',
  '9c000000-0000-4000-8000-000000000005',
  '9c000000-0000-4000-8000-000000000006');
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000004') is not null,
  'No-device fixture claims');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000004',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000004'),
  'no_devices',0,null,null),true,'No-device state completes once');
select ok((select status='no_devices' and last_error_code is null
  from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000004'),
  'No-device completion has no fabricated error');
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000005') is not null,
  'Permanent failure fixture claims');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000005',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000005'),
  'terminal',0,'MALFORMED_REQUEST',null),true,
  'Permanent malformed request finishes terminal');
select ok((select status='dead_letter' and attempt_count=1
  from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000005'),
  'Permanent error never enters retry queue');
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000006') is not null,
  'Global configuration failure fixture claims');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000006',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000006'),
  'terminal',0,'AUTH_CONFIGURATION',null),true,
  'Configuration failure finishes without per-job retry');
select ok((select circuit_open_until>clock_timestamp()
  and last_global_error_code='AUTH_CONFIGURATION'
  from public.v1_push_transport_control where id),
  'Global configuration failure opens transport circuit');
select is(public.v1_dispatch_push_notification(
  '9c000000-0000-4000-8000-000000000003'),false,
  'Open circuit suppresses another outbound invocation');

update public.v1_push_transport_control set
  circuit_open_until=null,probe_notification_id=null,
  last_global_error_code=null where id;
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id='9c000000-0000-4000-8000-000000000003';
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000003') is not null,
  'Started-send ambiguity fixture claims');
select is(public.v1_mark_push_send_started(
  '9c000000-0000-4000-8000-000000000003',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000003')),true,
  'Worker records the start of external delivery');
update public.v1_notification_push_outbox set
  lease_until=clock_timestamp()-interval '1 second'
where notification_id='9c000000-0000-4000-8000-000000000003';
select lives_ok($$select public.v1_dispatch_pending_pushes()$$,
  'Ambiguous expired lease is processed safely');
select is((select status from public.v1_notification_push_outbox where
  notification_id='9c000000-0000-4000-8000-000000000003'),
  'dead_letter','Possibly accepted push is not resent');

insert into public.v1_notifications
  (id,recipient_auth_user_id,event_code,entity_type,entity_id)
values ('9c000000-0000-4000-8000-000000000007',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000007'),
 ('9c000000-0000-4000-8000-000000000008',
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  '9d000000-0000-4000-8000-000000000008');
update public.v1_push_transport_control set
  circuit_open_until=clock_timestamp()+interval '15 minutes',
  probe_notification_id='9c000000-0000-4000-8000-000000000007'
where id;
update public.v1_notification_push_outbox set
  dispatch_lease_until=clock_timestamp()+interval '2 minutes'
where notification_id in (
  '9c000000-0000-4000-8000-000000000007',
  '9c000000-0000-4000-8000-000000000008');
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000007') is not null,
  'Only designated recovery probe can claim while circuit is open');
select ok(public.v1_claim_notification_push(
  '9c000000-0000-4000-8000-000000000008') is null,
  'Other work remains blocked by the open circuit');
select is(public.v1_finish_notification_push(
  '9c000000-0000-4000-8000-000000000007',
  (select claim_id from public.v1_notification_push_outbox where
   notification_id='9c000000-0000-4000-8000-000000000007'),
  'sent',1,null,null),true,
  'Successful recovery probe completes');
select ok((select circuit_open_until is null and
  probe_notification_id is null from public.v1_push_transport_control where id),
  'Transport resumes automatically only after successful probe');

insert into public.v1_notifications
  (id,recipient_auth_user_id,event_code,entity_type,entity_id)
select ('9c000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
  '10000000-0000-4000-8000-000000000003',
  'material_request_submitted','material_request',
  ('9d000000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid
from generate_series(9,11) n;
update public.v1_notification_push_outbox set
  dispatch_count=1,
  dispatch_lease_until=clock_timestamp()-interval '1 second'
where notification_id in (
  '9c000000-0000-4000-8000-000000000009',
  '9c000000-0000-4000-8000-000000000010',
  '9c000000-0000-4000-8000-000000000011');
update public.v1_push_transport_control set unclaimed_window_started_at=clock_timestamp()-interval '5 minutes';
select lives_ok($$select public.v1_dispatch_pending_pushes()$$,
  'Unclaimed Edge requests are detected from durable dispatch leases');
select ok((select circuit_open_until>clock_timestamp() and
  last_global_error_code='EDGE_UNCLAIMED'
  from public.v1_push_transport_control where id),
  'Three unclaimed requests open the circuit before a bulk storm');

select * from finish();
rollback;
