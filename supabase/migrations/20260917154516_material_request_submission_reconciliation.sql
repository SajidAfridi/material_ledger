begin;

-- Read-only reconciliation of one caller-owned logical submission. Absence is
-- NOT evidence of rollback: a transport-delayed transaction may still commit.
-- No new table, key claim, workflow transition, stock or notification effect.
create or replace function public.v1_get_material_request_submission_result(
  p_payload jsonb,
  p_idempotency_key uuid,
  p_approve_immediately boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_project_id uuid := nullif(p_payload ->> 'project_id', '')::uuid;
  v_request_id uuid := nullif(p_payload ->> 'request_id', '')::uuid;
  v_command text := case when p_approve_immediately
    then 'v1_save_submit_and_approve_material_request'
    else 'v1_save_and_submit_material_request' end;
  v_key public.v1_idempotency_keys%rowtype;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or not public.v1_material_request_engineering_project_access(v_project_id)
    or not public.v1_current_user_has_capability(
      'material_requests.submit', v_project_id
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SUBMISSION_RESULT_DENIED'
      using errcode = '42501';
  end if;
  if v_request_id is null or v_project_id is null
    or p_idempotency_key is null or p_approve_immediately is null then
    raise exception 'V1_MATERIAL_REQUEST_SUBMISSION_RESULT_INPUT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_key from public.v1_idempotency_keys
  where actor_auth_user_id = v_actor and command_name = v_command
    and idempotency_key = p_idempotency_key;
  if not found then return null; end if;
  if v_key.request_hash <> public.v1_hash_json(p_payload) then
    raise exception 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD'
      using errcode = '22023';
  end if;
  if v_key.response_json is null then return null; end if;
  if v_key.response_json ->> 'id' is distinct from v_request_id::text
    or not exists (
      select 1 from public.v1_material_requests
      where id = v_request_id and project_id = v_project_id
        and created_by_auth_user_id = v_actor
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SUBMISSION_RESULT_DENIED'
      using errcode = '42501';
  end if;
  if p_approve_immediately and (
    not public.v1_can_decide_material_request(v_request_id)
    or not public.v1_current_user_has_capability(
      'material_requests.approve', v_project_id
    )
  ) then
    raise exception 'V1_MATERIAL_REQUEST_SUBMISSION_RESULT_DENIED'
      using errcode = '42501';
  end if;
  -- Reproject under CURRENT record/commercial access, never expose a cached
  -- privileged response after membership, role or capability changes.
  return public.v1_material_request_projection(v_request_id);
end;
$$;

revoke all on function public.v1_get_material_request_submission_result(jsonb,uuid,boolean)
  from public, anon, authenticated;
grant execute on function public.v1_get_material_request_submission_result(jsonb,uuid,boolean)
  to authenticated;

-- Keep existing transactional write bodies and advisory-lock deduplication.
-- Change only the replay return, with strict anchors to fail closed on drift.
do $replay_guard$
declare
  v_name text;
  v_definition text;
  v_anchor text;
  v_replacement text;
begin
  foreach v_name in array array[
    'v1_save_and_submit_material_request',
    'v1_save_submit_and_approve_material_request'
  ] loop
    v_definition := pg_get_functiondef(
      format('public.%I(jsonb,uuid)', v_name)::regprocedure
    );
    if position('v1_get_material_request_submission_result' in v_definition) > 0 then
      continue;
    end if;
    v_anchor := case when v_name = 'v1_save_and_submit_material_request'
      then 'if v_existing_response is not null then return v_existing_response; end if;'
      else E'if v_existing_response is not null then\n    return v_existing_response;\n  end if;' end;
    v_replacement := format(
      'if v_existing_response is not null then return public.v1_get_material_request_submission_result(p_payload, p_idempotency_key, %s); end if;',
      case when v_name = 'v1_save_submit_and_approve_material_request' then 'true' else 'false' end
    );
    if position(v_anchor in v_definition) = 0 then
      raise exception 'V1_SUBMISSION_REPLAY_GUARD_ANCHOR_MISSING';
    end if;
    execute replace(v_definition, v_anchor, v_replacement);
  end loop;
end;
$replay_guard$;

-- Forward fix is preferred. Application rollback leaves this additive read
-- function/stricter replay guard installed; it is compatible with old clients.
-- Never delete idempotency, audit or operational history during rollback.
commit;
