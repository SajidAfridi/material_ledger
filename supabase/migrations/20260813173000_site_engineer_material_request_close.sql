-- Allow an actively assigned Site Engineer to close a fully resolved Material
-- Request through the existing trusted, versioned and idempotent command.
--
-- Data preservation: this migration changes only the private authorization
-- helper. It rewrites no request, logistics, stock, document or audit rows.
-- Rollback is forward-only: restore the prior Project Engineer/Admin predicate
-- in a corrective migration; already-recorded closure history remains valid.

begin;

create or replace function public.v1_can_close_material_request(
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
  v_exact_role text := public.v1_current_exact_role();
begin
  if auth.uid() is null or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_exact_role = 'admin' then
    return exists (
      select 1 from public.v1_material_requests request_record
      where request_record.id = p_request_id
    );
  end if;
  select request_record.project_id into v_project_id
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if v_project_id is null then return false; end if;
  if v_exact_role in ('senior_mechanical_engineer', 'project_manager') then
    return true;
  end if;
  if v_exact_role = 'project_engineer' then
    return public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
  end if;
  if v_exact_role = 'site_engineer' then
    return public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'site_engineer'
    );
  end if;
  return false;
end;
$$;

revoke all on function public.v1_can_close_material_request(uuid)
  from public, anon, authenticated;

commit;
