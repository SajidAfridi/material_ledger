-- Reconcile Delivery Order generation with the canonical R35 receipt flow.
--
-- A confirmed site receipt transfers the controlled-document action to the
-- assigned Project/Site Engineer. Procurement and Admin retain the capability,
-- but dispatch and inventory commands remain unchanged. Reapplying this
-- migration is safe: constraints and the capability function are replaced in
-- place, while existing Delivery Orders and revisions are preserved.

begin;

alter table public.v1_delivery_orders
  drop constraint if exists v1_delivery_orders_created_by_role_check;
alter table public.v1_delivery_orders
  add constraint v1_delivery_orders_created_by_role_check check (
    created_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'admin'
    )
  );

alter table public.v1_delivery_order_revisions
  drop constraint if exists v1_delivery_order_revisions_generated_by_role_check;
alter table public.v1_delivery_order_revisions
  add constraint v1_delivery_order_revisions_generated_by_role_check check (
    generated_by_role in (
      'project_engineer', 'site_engineer', 'procurement', 'admin'
    )
  );

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
      v_role = 'project_engineer'
      and public.v1_has_active_project_membership(
        v_project_id,
        auth.uid(),
        'project_engineer'
      )
    )
    or (
      v_role = 'site_engineer'
      and public.v1_has_active_project_membership(
        v_project_id,
        auth.uid(),
        'site_engineer'
      )
    );
end;
$$;

revoke all on function public.v1_can_generate_delivery_order(uuid)
  from public, anon;
grant execute on function public.v1_can_generate_delivery_order(uuid)
  to authenticated;

commit;
