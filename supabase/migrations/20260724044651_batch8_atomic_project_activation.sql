-- Batch 8 hardening: keep final Phase 1 approval and project activation in
-- one database transaction. The Flutter client still updates its local project
-- immediately for offline responsiveness, but the server is authoritative if a
-- browser closes between outbox writes.

create or replace function public.phase1_activate_approved_project()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  approved_by text := coalesce(new.updated_by_user_id, '');
  active_phase jsonb := jsonb_build_object(
    'number', 2,
    'name', 'Active',
    'nameSecondary', 'فعال',
    'state', 'Active'
  );
begin
  if new.status <> 'approved'
     or (tg_op = 'UPDATE' and old.status = 'approved') then
    return new;
  end if;

  update public.projects
  set data = jsonb_set(
        jsonb_set(
          jsonb_set(
            jsonb_set(
              jsonb_set(
                data,
                '{lifecycleStatus}',
                '"active"'::jsonb,
                true
              ),
              '{awaitingApproval}',
              'false'::jsonb,
              true
            ),
            '{phase}',
            active_phase,
            true
          ),
          '{updatedAt}',
          to_jsonb(now()::text),
          true
        ),
        '{updatedByUserId}',
        to_jsonb(approved_by),
        true
      )
  where id = new.project_id;

  return new;
end;
$$;

revoke execute on function public.phase1_activate_approved_project()
  from public, anon, authenticated;

drop trigger if exists phase1_activate_approved_project
  on public.phase1_plans;
create trigger phase1_activate_approved_project
after insert or update of status on public.phase1_plans
for each row execute function public.phase1_activate_approved_project();

create or replace function public.project_require_approved_phase1()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  old_status text := case
    when tg_op = 'INSERT' then null
    else old.data ->> 'lifecycleStatus'
  end;
  new_status text := new.data ->> 'lifecycleStatus';
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;

  if new_status = 'active'
     and old_status is distinct from 'active'
     and not exists (
       select 1
       from public.phase1_plans plan
       where plan.project_id = new.id
         and plan.status = 'approved'
     ) then
    raise exception using
      errcode = '55000',
      message = 'A project requires an approved Phase 1 plan before activation.';
  end if;
  return new;
end;
$$;

revoke execute on function public.project_require_approved_phase1()
  from public, anon, authenticated;

drop trigger if exists project_require_approved_phase1 on public.projects;
create trigger project_require_approved_phase1
before insert or update of data on public.projects
for each row execute function public.project_require_approved_phase1();

-- Idempotent backstop for plans approved before this hardening migration.
update public.projects project
set data = jsonb_set(
      jsonb_set(
        jsonb_set(
          project.data,
          '{lifecycleStatus}',
          '"active"'::jsonb,
          true
        ),
        '{awaitingApproval}',
        'false'::jsonb,
        true
      ),
      '{phase}',
      jsonb_build_object(
        'number', 2,
        'name', 'Active',
        'nameSecondary', 'فعال',
        'state', 'Active'
      ),
      true
    )
from public.phase1_plans plan
where plan.project_id = project.id
  and plan.status = 'approved';
