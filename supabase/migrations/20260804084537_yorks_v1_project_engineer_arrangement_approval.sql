-- Yorks R35: an MR created by a Site Engineer is reviewed by the project's
-- Project Engineer. Historic membership labels must not elevate a Site
-- Engineer account into the approval role.
--
-- This is additive/repeatable function hardening. It preserves all existing
-- membership and decision history; only future authorization is narrowed.

create or replace function public.v1_can_decide_arrangement(
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
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null
    or v_role not in ('project_engineer', 'admin')
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_role = 'admin' then
    return true;
  end if;
  select project_id into v_project_id
  from public.v1_material_requests
  where id = p_request_id;
  return v_project_id is not null
    and public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
end;
$$;

revoke all on function public.v1_can_decide_arrangement(uuid)
  from public, anon;
grant execute on function public.v1_can_decide_arrangement(uuid)
  to authenticated;
