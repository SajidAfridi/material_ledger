-- Batch 8 progress hardening. Progress is audited reporting metadata only:
-- Admin controls stage definitions, Engineering updates percentages, and
-- Procurement is read-only. This extends the existing project lifecycle guard.

create or replace function public.project_progress_definitions(p_data jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  with source as (
    select case
      when jsonb_typeof(p_data -> 'progressStages') = 'array'
        then coalesce(p_data -> 'progressStages', '[]'::jsonb)
      else '[]'::jsonb
    end as stages
  ),
  definitions as (
    select jsonb_agg(
      jsonb_build_object(
        'id', stage.value ->> 'id',
        'label', stage.value ->> 'label',
        'weightPercent', stage.value -> 'weightPercent'
      )
      order by stage.ordinality
    ) as value
    from source,
      jsonb_array_elements(source.stages) with ordinality as stage(value, ordinality)
  )
  select coalesce(
    definitions.value,
    '[
      {"id":"cooling-load-design","label":"Cooling Load Design","weightPercent":10},
      {"id":"material-supply","label":"Material Supply","weightPercent":50},
      {"id":"progress-installation","label":"Progress Installation","weightPercent":30},
      {"id":"commissioning-handover","label":"Commissioning & Handover","weightPercent":5},
      {"id":"energizing-substation","label":"Energizing Substation","weightPercent":5}
    ]'::jsonb
  )
  from definitions;
$$;

revoke execute on function public.project_progress_definitions(jsonb)
  from public, anon;
grant execute on function public.project_progress_definitions(jsonb)
  to authenticated, service_role;

create or replace function public.project_require_approved_phase1()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  caller_role text := public.app_role();
  old_status text := case
    when tg_op = 'INSERT' then null
    else old.data ->> 'lifecycleStatus'
  end;
  new_status text := new.data ->> 'lifecycleStatus';
  old_stages jsonb := case
    when tg_op = 'INSERT' then '[]'::jsonb
    else coalesce(old.data -> 'progressStages', '[]'::jsonb)
  end;
  new_stages jsonb := coalesce(new.data -> 'progressStages', '[]'::jsonb);
  total_weight numeric;
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

  if new_stages is distinct from old_stages then
    if jsonb_typeof(new_stages) <> 'array'
       or jsonb_array_length(new_stages) = 0 then
      raise exception using
        errcode = '22023',
        message = 'Project progress stages must be a non-empty array.';
    end if;

    if exists (
      select 1
      from jsonb_array_elements(new_stages) stage
      where jsonb_typeof(stage) <> 'object'
        or btrim(coalesce(stage ->> 'id', '')) = ''
        or btrim(coalesce(stage ->> 'label', '')) = ''
        or jsonb_typeof(stage -> 'weightPercent') <> 'number'
        or (stage ->> 'weightPercent')::numeric <= 0
        or jsonb_typeof(stage -> 'progressPercent') <> 'number'
        or (stage ->> 'progressPercent')::numeric < 0
        or (stage ->> 'progressPercent')::numeric > 100
    ) then
      raise exception using
        errcode = '22023',
        message = 'Project progress stages contain invalid values.';
    end if;

    if exists (
      select 1
      from jsonb_array_elements(new_stages) stage
      group by stage ->> 'id'
      having count(*) > 1
    ) then
      raise exception using
        errcode = '22023',
        message = 'Project progress stage ids must be unique.';
    end if;

    select sum((stage ->> 'weightPercent')::numeric)
    into total_weight
    from jsonb_array_elements(new_stages) stage;
    if abs(total_weight - 100) > 0.01 then
      raise exception using
        errcode = '22023',
        message = 'Project progress weights must total 100.';
    end if;

    if caller_role = 'procurement' then
      raise exception using
        errcode = '42501',
        message = 'Procurement has read-only project progress access.';
    end if;
    if caller_role = 'engineer'
       and public.project_progress_definitions(old.data)
           is distinct from public.project_progress_definitions(new.data) then
      raise exception using
        errcode = '42501',
        message = 'Engineering can update progress but not stage definitions.';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function public.project_require_approved_phase1()
  from public, anon, authenticated;
