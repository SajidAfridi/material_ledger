-- Yorks V1 read-only project Material Movement register.
--
-- Data preservation: no logistics fact is rewritten. The RPC projects
-- committed dispatch lines and confirmed return lines exactly as recorded.
-- Rollback is forward-only: revoke this projection in a corrective migration.

create or replace function public.v1_project_material_movements(
  p_project_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or p_project_id is null
    or not public.v1_project_readable(p_project_id) then
    raise exception 'V1_PROJECT_MATERIAL_MOVEMENT_DENIED'
      using errcode = '42501';
  end if;

  with movements as (
    select
      dispatch_line.id,
      'dispatched'::text as movement_kind,
      dispatch.dispatch_number as reference,
      request.id as request_id,
      coalesce(request.request_number, project.project_ref) as request_number,
      dispatch_line.item_description,
      dispatch_line.brand_origin,
      dispatch_line.unit,
      dispatch_line.dispatched_qty as quantity,
      public.v1_safe_profile_display_name(
        profile.display_name, dispatch.dispatched_by_auth_user_id
      ) as actor_display_name,
      dispatch.dispatched_at as occurred_at
    from public.v1_material_dispatches dispatch
    join public.v1_material_dispatch_lines dispatch_line
      on dispatch_line.dispatch_id = dispatch.id
    join public.v1_material_requests request on request.id = dispatch.request_id
    join public.v1_projects project on project.id = dispatch.project_id
    left join public.v1_profiles profile
      on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
    where dispatch.project_id = p_project_id

    union all

    select
      return_line.id,
      'returned'::text as movement_kind,
      material_return.return_number as reference,
      request.id as request_id,
      coalesce(request.request_number, project.project_ref) as request_number,
      return_line.item_description,
      return_line.brand_origin,
      return_line.unit,
      return_line.return_quantity as quantity,
      public.v1_safe_profile_display_name(
        profile.display_name, material_return.decided_by_auth_user_id
      ) as actor_display_name,
      material_return.decided_at as occurred_at
    from public.v1_material_returns material_return
    join public.v1_material_return_lines return_line
      on return_line.material_return_id = material_return.id
    join public.v1_material_requests request
      on request.id = material_return.request_id
    join public.v1_projects project on project.id = material_return.project_id
    left join public.v1_profiles profile
      on profile.auth_user_id = material_return.decided_by_auth_user_id
    where material_return.project_id = p_project_id
      and material_return.state = 'confirmed'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', movement.id,
    'movement_kind', movement.movement_kind,
    'reference', movement.reference,
    'request_id', movement.request_id,
    'request_number', movement.request_number,
    'item_description', movement.item_description,
    'brand_origin', movement.brand_origin,
    'unit', movement.unit,
    'quantity', movement.quantity,
    'actor_display_name', movement.actor_display_name,
    'occurred_at', movement.occurred_at
  ) order by movement.occurred_at desc, movement.id), '[]'::jsonb)
  into v_result
  from movements movement;

  return v_result;
end;
$$;

revoke all on function public.v1_project_material_movements(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_project_material_movements(uuid)
  to authenticated, service_role;

comment on function public.v1_project_material_movements(uuid) is
  'Authorized non-commercial project register of dispatch and confirmed-return line facts.';

notify pgrst, 'reload schema';
