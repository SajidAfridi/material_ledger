-- Company Material Requests T01 follow-up: preflight must not disclose a
-- route for a beneficiary or receiver the caller cannot select. Submission
-- already checks this; keeping preflight equivalent closes the client/RPC
-- consistency and information boundary without changing request data.

begin;

create or replace function public.v1_company_material_request_approval_preflight(
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_beneficiary_auth_user_id uuid,
  p_authorized_receiver_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_route record;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_active_authorization(
      v_actor, p_category_id, p_responsible_unit_id, 'requester'
    )
    or not public.v1_company_material_request_active_authorization(
      p_beneficiary_auth_user_id, p_category_id, p_responsible_unit_id, 'beneficiary'
    )
    or not public.v1_company_material_request_active_authorization(
      p_authorized_receiver_auth_user_id, p_category_id, p_responsible_unit_id, 'receiver'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PREFLIGHT_DENIED' using errcode = '42501';
  end if;

  select * into v_route
  from public.v1_resolve_company_material_request_approver(
    p_category_id,
    p_responsible_unit_id,
    array[v_actor, p_beneficiary_auth_user_id, p_authorized_receiver_auth_user_id]
  );
  if not found then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED'
      using errcode = '22023';
  end if;

  return jsonb_build_object(
    'approval_route_id', v_route.route_id,
    'policy_version', v_route.policy_version,
    'approver_auth_user_id', v_route.approver_auth_user_id,
    'approver_display_name', v_route.approver_display_name
  );
end;
$$;

commit;
