begin;

-- Product-owner approved creation-form fast path. This wrapper keeps the
-- canonical Draft -> awaiting_request_approval -> approved_for_arrangement
-- transitions, audits and notifications intact, but executes them in one
-- transaction so a failed decision cannot expose a partially submitted MR.
create or replace function public.v1_save_submit_and_approve_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_existing_response jsonb;
  v_submitted jsonb;
  v_approved jsonb;
begin
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  if v_request_id is null then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  -- A retry after an ambiguous client response returns the already approved
  -- projection and never attempts to re-save an immutable request.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_submit_and_approve_material_request',
    p_idempotency_key,
    p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  v_submitted := public.v1_save_and_submit_material_request(
    p_payload,
    p_idempotency_key
  );
  v_approved := public.v1_decide_material_request(
    jsonb_build_object(
      'request_id', v_request_id,
      'expected_version', (v_submitted ->> 'record_version')::integer,
      'decision', 'approved',
      'reason', null
    ),
    p_idempotency_key
  );

  perform public.v1_complete_idempotency(
    'v1_save_submit_and_approve_material_request',
    p_idempotency_key,
    v_approved
  );
  return v_approved;
end;
$$;

revoke all on function public.v1_save_submit_and_approve_material_request(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_save_submit_and_approve_material_request(jsonb, uuid)
  to authenticated, service_role;

-- An exact Site Engineer may create and submit a request but can never grant
-- its Engineering approval. This restores the approved role boundary even if
-- a legacy project-members row incorrectly labels that account as a Project
-- Engineer. The decision command still separately checks the action-specific
-- capability and current published self-approval policy.
create or replace function public.v1_can_decide_material_request(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text := public.v1_current_exact_role();
  v_allow_self boolean := public.v1_material_request_published_policy_boolean(
    'requests.allow_authorized_creator_self_approval', true
  );
  v_legacy_allowed boolean;
begin
  if auth.uid() is null
    or v_exact_role not in (
      'project_engineer',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller', 'admin'
    )
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found then
    return false;
  end if;
  if not v_allow_self and v_request.created_by_auth_user_id = auth.uid() then
    return false;
  end if;

  v_legacy_allowed := v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or (
      v_exact_role = 'project_engineer'
      and public.v1_has_active_project_membership(
        v_request.project_id, auth.uid(), 'project_engineer'
      )
    );

  return v_legacy_allowed and (
    public.v1_current_user_has_capability(
      'material_requests.approve', v_request.project_id
    )
    or public.v1_current_user_has_capability(
      'material_requests.return_for_changes', v_request.project_id
    )
  );
end;
$$;

revoke all on function public.v1_can_decide_material_request(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_can_decide_material_request(uuid)
  to service_role;

commit;
