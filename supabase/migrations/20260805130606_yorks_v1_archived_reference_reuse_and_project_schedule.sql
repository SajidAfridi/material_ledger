-- Yorks V1 R35 project reference reuse and calendar-date guard.
--
-- Archived projects are immutable historical records.  Their reference must
-- remain visible to audit/search, but it must not block a replacement project
-- from using the same operational reference.  The previous global UNIQUE
-- constraint was therefore too restrictive: it produced a 409 on legitimate
-- re-creation after a safe archive.  A partial unique index preserves one
-- current (draft/active/on-hold/completed) project per reference while keeping
-- archived records fully intact.
--
-- Rollback: archive or rename any replacement project first, then drop
-- v1_projects_current_project_ref_unique and restore the old global UNIQUE
-- constraint only after no duplicate archived/current references remain.

alter table public.v1_projects
  drop constraint if exists v1_projects_project_ref_key;

create unique index if not exists v1_projects_current_project_ref_unique
  on public.v1_projects (project_ref)
  where state <> 'archived';

-- Calendar dates are deliberately bounded to a generous operational window,
-- rather than accepting accidental century-scale entries.  The trigger covers
-- trusted create/update commands and rejects direct writes too; it does not
-- mutate any existing historical project.
create or replace function public.v1_validate_project_schedule()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_minimum_date date := (current_date - interval '50 years')::date;
  v_maximum_date date := (current_date + interval '50 years')::date;
begin
  if new.start_date is not null
    and (new.start_date < v_minimum_date or new.start_date > v_maximum_date) then
    raise exception 'V1_PROJECT_START_DATE_OUT_OF_SUPPORTED_RANGE'
      using errcode = '22023';
  end if;
  if new.target_completion_date is not null
    and (
      new.target_completion_date < v_minimum_date
      or new.target_completion_date > v_maximum_date
    ) then
    raise exception 'V1_PROJECT_END_DATE_OUT_OF_SUPPORTED_RANGE'
      using errcode = '22023';
  end if;
  if new.start_date is not null
    and new.target_completion_date is not null
    and new.target_completion_date < new.start_date then
    raise exception 'V1_PROJECT_END_DATE_BEFORE_START_DATE'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_project_schedule_guard on public.v1_projects;
create trigger v1_project_schedule_guard
before insert or update of start_date, target_completion_date
on public.v1_projects
for each row execute function public.v1_validate_project_schedule();

revoke all on function public.v1_validate_project_schedule() from public, anon, authenticated;
