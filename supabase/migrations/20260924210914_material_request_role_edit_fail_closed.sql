-- Return an explicit false when a role grant is revoked and no named editor remains.
create or replace function public.v1_can_edit_material_request_post_approval(
  p_request_id uuid
) returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request from public.v1_material_requests
  where id = p_request_id;
  if not found or not v_request.post_approval_edit_enabled
    or (v_request.state <> 'approved_for_arrangement'
      and not (v_request.post_approval_amendment_pending
        and v_request.state in ('awaiting_request_approval', 'changes_requested')))
    or exists (select 1 from public.v1_procurement_arrangements
      where request_id = p_request_id) then return false; end if;
  if public.v1_can_manage_material_request_post_approval_edit(p_request_id) then
    return true;
  end if;
  return public.v1_current_exact_role() = 'procurement'
    and (v_request.procurement_role_edit_enabled
      or coalesce(auth.uid() = v_request.procurement_editor_auth_user_id, false))
    and public.v1_current_user_has_capability(
      'procurement.arrange', v_request.project_id
    );
end;
$$;
