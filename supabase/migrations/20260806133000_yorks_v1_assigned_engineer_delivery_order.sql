-- Reconcile Delivery Order generation with project assignment semantics.
--
-- Project/Site Engineer remains a server-controlled platform role. For this
-- document-only action, either engineering role may generate the Delivery
-- Order when the actor has any active membership on the request's project and
-- the receipt review is confirmed. Approval, arrangement, dispatch, inventory
-- and return-confirmation authority are unchanged.
--
-- This follow-up is additive and repeatable. Existing Delivery Orders and
-- immutable revisions are preserved. Rollback restores the preceding function
-- definition; it never deletes a generated document or audit history.

begin;

create or replace function public.v1_can_generate_delivery_order(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;

  if v_project_id is null
    or v_project_state not in ('active', 'on_hold', 'completed') then
    return false;
  end if;

  if not exists (
    select 1
    from public.v1_receipt_reviews review
    where review.request_id = p_request_id
      and review.state = 'confirmed'
  ) then
    return false;
  end if;

  return v_role in ('procurement', 'admin')
    or (
      v_role in ('project_engineer', 'site_engineer')
      and public.v1_has_active_project_membership(
        v_project_id,
        auth.uid(),
        null
      )
    );
end;
$$;

revoke all on function public.v1_can_generate_delivery_order(uuid)
  from public, anon;
grant execute on function public.v1_can_generate_delivery_order(uuid)
  to authenticated;

commit;
