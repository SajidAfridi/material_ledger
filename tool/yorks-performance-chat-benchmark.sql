-- Read-only, rollback-scoped benchmark for the staging Project Manager.
-- Run only on local/dedicated staging. Emits timings/counts, never chat bodies.
-- The baseline repeats the protected helper as the pre-review list did; both
-- sides use the current helper so response equality is directly comparable.
-- Run as the database owner: the inline baseline must have the same definer
-- privileges as the production RPC, not an extra outer-table RLS evaluation.
begin read only;
set local statement_timeout = '30s';
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);

do $benchmark$
declare
  v_actor uuid := auth.uid();
  v_baseline jsonb;
  v_candidate jsonb;
  v_started timestamptz;
  v_baseline_ms numeric[] := '{}';
  v_candidate_ms numeric[] := '{}';
begin
  -- Alternate baseline and candidate after one unrecorded warm-up per side.
  for run in 0..5 loop
    v_started := clock_timestamp();
    select coalesce(jsonb_agg(
      public.v1_chat_conversation_json(conversation.id, v_actor)
      order by member.is_pinned desc,
        ((public.v1_chat_conversation_json(conversation.id, v_actor)
          ->> 'unread_count')::integer > 0) desc,
        coalesce(conversation.last_message_at, conversation.created_at) desc,
        conversation.id desc
    ), '[]'::jsonb)
    into v_baseline
    from public.v1_chat_conversations conversation
    join public.v1_chat_members member
      on member.conversation_id = conversation.id
     and member.auth_user_id = v_actor
     and member.left_at is null
    where public.v1_chat_is_active_member(conversation.id, v_actor);
    if run > 0 then
      v_baseline_ms := array_append(v_baseline_ms,
        round(extract(epoch from (clock_timestamp() - v_started)) * 1000, 2));
    end if;

    v_started := clock_timestamp();
    v_candidate := public.v1_list_chat_conversations();
    if run > 0 then
      v_candidate_ms := array_append(v_candidate_ms,
        round(extract(epoch from (clock_timestamp() - v_started)) * 1000, 2));
    end if;
    if v_baseline is distinct from v_candidate then
      raise exception 'CHAT_PERFORMANCE_RESPONSE_PARITY_FAILED';
    end if;
  end loop;
  raise notice 'chat_benchmark conversation_count=% baseline_ms=% candidate_ms=% response_parity=true',
    jsonb_array_length(v_candidate), v_baseline_ms, v_candidate_ms;
end;
$benchmark$;

rollback;
