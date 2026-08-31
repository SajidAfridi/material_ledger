-- Workforce T06 correction: a mutable current team window cannot hide or
-- reject a month that is still owned by retained T03 attendance evidence.
--
-- This migration changes only trusted function definitions. It creates no
-- period, attendance, allocation or audit fact and updates no retained row.

begin;

create or replace function public.v1_workforce_monthly_team_applicable(
  p_team_id uuid,
  p_period_month date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_team_id is not null
    and p_period_month is not null
    and exists (
      select 1
      from public.v1_workforce_teams team
      where team.id = p_team_id
        and (
          (
            team.valid_from < p_period_month + interval '1 month'
            and (team.valid_to is null or team.valid_to >= p_period_month)
          )
          or exists (
            select 1
            from public.v1_workforce_attendance_days attendance
            where attendance.assignment_team_id_snapshot = p_team_id
              and attendance.work_date >= p_period_month
              and attendance.work_date < p_period_month + interval '1 month'
          )
          or exists (
            select 1
            from public.v1_workforce_monthly_periods period
            where period.team_id = p_team_id
              and period.period_month = p_period_month
          )
        )
    );
$$;

revoke all on function public.v1_workforce_monthly_team_applicable(uuid, date)
  from public, anon, authenticated;
grant execute on function public.v1_workforce_monthly_team_applicable(uuid, date)
  to service_role;

-- Keep the three public boundaries on exactly one applicability predicate.
-- Function-definition patching avoids duplicating the complete accepted T06
-- RPC bodies. Every replacement is fail-closed and safe on reapplication.
do $patch_t06_applicability$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  select pg_get_functiondef(
    'public.v1_get_workforce_monthly_period(uuid,date,text,text,text,integer,integer)'::regprocedure
  ) into v_definition;
  v_old := E'if v_period.id is null and not exists (\n    select 1\n    from public.v1_workforce_teams team\n    where team.id = p_team_id\n      and team.valid_from < p_period_month + interval ''1 month''\n      and (team.valid_to is null or team.valid_to >= p_period_month)\n  ) then';
  v_new := E'if not public.v1_workforce_monthly_team_applicable(\n    p_team_id, p_period_month\n  ) then';
  if strpos(v_definition, v_new) > 0 and strpos(v_definition, v_old) = 0 then
    null;
  elsif strpos(v_definition, v_old) > 0 and strpos(v_definition, v_new) = 0 then
    v_definition := replace(v_definition, v_old, v_new);
    execute v_definition;
  else
    raise exception 'V1_WORKFORCE_T06_READ_APPLICABILITY_PATCH_MISMATCH';
  end if;

  select pg_get_functiondef(
    'public.v1_list_workforce_monthly_teams(date,text,integer,integer)'::regprocedure
  ) into v_definition;
  v_old := E'where team.valid_from < p_period_month + interval ''1 month''\n      and (team.valid_to is null or team.valid_to >= p_period_month)\n      and (v_query is null or lower(';
  v_new := E'where public.v1_workforce_monthly_team_applicable(\n        team.id, p_period_month\n      )\n      and (v_query is null or lower(';
  if strpos(v_definition, v_new) > 0 and strpos(v_definition, v_old) = 0 then
    null;
  elsif strpos(v_definition, v_old) > 0 and strpos(v_definition, v_new) = 0 then
    v_definition := replace(v_definition, v_old, v_new);
    execute v_definition;
  else
    raise exception 'V1_WORKFORCE_T06_SELECTOR_APPLICABILITY_PATCH_MISMATCH';
  end if;

  select pg_get_functiondef(
    'public.v1_validate_workforce_monthly_period(jsonb,bigint,uuid)'::regprocedure
  ) into v_definition;
  v_old := E'if v_period.id is null and not exists (\n    select 1\n    from public.v1_workforce_teams team\n    where team.id = v_team_id\n      and team.valid_from < v_period_month + interval ''1 month''\n      and (team.valid_to is null or team.valid_to >= v_period_month)\n  ) then';
  v_new := E'if not public.v1_workforce_monthly_team_applicable(\n    v_team_id, v_period_month\n  ) then';
  if strpos(v_definition, v_new) > 0 and strpos(v_definition, v_old) = 0 then
    null;
  elsif strpos(v_definition, v_old) > 0 and strpos(v_definition, v_new) = 0 then
    v_definition := replace(v_definition, v_old, v_new);
    execute v_definition;
  else
    raise exception 'V1_WORKFORCE_T06_VALIDATE_APPLICABILITY_PATCH_MISMATCH';
  end if;
end;
$patch_t06_applicability$;

commit;
