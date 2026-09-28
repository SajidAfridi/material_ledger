-- Rollback-scoped benchmark for the synchronous arrangement-begun path on
-- dedicated Yorks technical staging. It executes the real trusted command as
-- Procurement, then rolls back the arrangement, audit and chat projection.

begin;
set local statement_timeout = '90s';
set local lock_timeout = '5s';

do $target_guard$
begin
  if (select count(*) from auth.users) <> 7
    or exists (
      select 1
      from auth.users auth_user
      where auth_user.email not like '%@yorks.local.test'
    ) then
    raise exception
      'ARRANGEMENT_CHAT_PROFILE_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
end;
$target_guard$;

create temporary table arrangement_chat_profile_target on commit drop as
select request.id, request.record_version
from public.v1_material_requests request
where request.state = 'approved_for_arrangement'
  and exists (
    select 1
    from public.v1_material_request_decisions decision
    where decision.request_id = request.id
      and decision.decision = 'approved'
  )
  and not exists (
    select 1
    from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = request.id
      and arrangement.status = 'working'
  )
order by request.created_at, request.id
limit 1;

do $target_exists$
begin
  if not exists (select 1 from arrangement_chat_profile_target) then
    raise exception 'ARRANGEMENT_CHAT_PROFILE_HAS_NO_SAFE_TARGET';
  end if;
end;
$target_exists$;

-- Normalize any pre-existing staging-only membership drift before measuring
-- the steady-state arrangement path. This reconciliation is inside the same
-- transaction and is rolled back with the profiled arrangement command.
do $normalize_members$
declare
  v_conversation_id uuid;
begin
  select conversation.id into v_conversation_id
  from public.v1_chat_conversations conversation
  join arrangement_chat_profile_target target
    on target.id = conversation.material_request_id
  where conversation.kind = 'material_request';

  if v_conversation_id is not null then
    perform public.v1_sync_chat_context_members(v_conversation_id);
  end if;
end;
$normalize_members$;

grant select on table arrangement_chat_profile_target to authenticated;
select set_config(
  'request.jwt.claims',
  (
    select jsonb_build_object(
      'sub', auth_user.id,
      'role', 'authenticated',
      'app_metadata', jsonb_build_object(
        'role', 'procurement',
        'app_user_id', auth_user.raw_app_meta_data ->> 'app_user_id'
      )
    )::text
    from auth.users auth_user
    join public.v1_profiles profile
      on profile.auth_user_id = auth_user.id
    where profile.is_active
      and auth_user.raw_app_meta_data ->> 'role' = 'procurement'
      and (auth_user.banned_until is null
        or auth_user.banned_until <= clock_timestamp())
    order by profile.created_at
    limit 1
  ),
  true
);
set local role authenticated;

explain (analyze, buffers, verbose, settings, summary)
select public.v1_begin_arrangement(
  jsonb_build_object(
    'request_id', target.id::text,
    'expected_version', target.record_version
  ),
  gen_random_uuid()
)
from arrangement_chat_profile_target target;

rollback;
