-- Yorks Workforce T02 correction: retain exact effective calendar, weekday,
-- shift, dated-override and team-schedule meanings. This is an additive,
-- route-less correction; it creates no attendance or timesheet facts.

create index if not exists v1_workforce_team_schedule_links_calendar_guard_idx
  on public.v1_workforce_team_schedule_links (calendar_id, valid_to);

create index if not exists v1_workforce_team_schedule_links_shift_guard_idx
  on public.v1_workforce_team_schedule_links (shift_template_id, valid_to)
  where shift_template_id is not null;

create index if not exists v1_workforce_calendar_dates_calendar_guard_idx
  on public.v1_workforce_calendar_dates (calendar_id, calendar_date)
  where is_active;

create index if not exists v1_workforce_calendar_dates_shift_guard_idx
  on public.v1_workforce_calendar_dates (shift_template_id, calendar_date)
  where shift_template_id is not null and is_active;

create or replace function public.v1_workforce_calendar_is_retained(
  p_calendar_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_workforce_team_schedule_links link
    where link.calendar_id = p_calendar_id
  ) or exists (
    select 1
    from public.v1_workforce_calendar_dates calendar_date
    where calendar_date.calendar_id = p_calendar_id
  );
$$;

create or replace function public.v1_workforce_shift_is_retained(
  p_shift_template_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_workforce_team_schedule_links link
    where link.shift_template_id = p_shift_template_id
  ) or exists (
    select 1
    from public.v1_workforce_calendar_dates calendar_date
    where calendar_date.shift_template_id = p_shift_template_id
  );
$$;

create or replace function public.v1_workforce_guard_calendar_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.v1_workforce_calendar_is_retained(old.id) and (
    new.calendar_code is distinct from old.calendar_code
    or new.timezone_name is distinct from old.timezone_name
    or new.standard_scheduled_minutes
      is distinct from old.standard_scheduled_minutes
    or new.break_minutes is distinct from old.break_minutes
    or new.valid_from is distinct from old.valid_from
    or new.valid_to is distinct from old.valid_to
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  if old.is_active and not new.is_active and (
    exists (
      select 1
      from public.v1_workforce_team_schedule_links link
      where link.calendar_id = old.id
        and (link.valid_to is null or link.valid_to >= current_date)
    )
    or exists (
      select 1
      from public.v1_workforce_calendar_dates calendar_date
      where calendar_date.calendar_id = old.id
        and calendar_date.is_active
        and calendar_date.calendar_date >= current_date
    )
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_ACTIVE_USE'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.v1_workforce_guard_calendar_weekday_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.v1_workforce_calendar_is_retained(old.calendar_id) and (
    new.calendar_id is distinct from old.calendar_id
    or new.iso_weekday is distinct from old.iso_weekday
    or new.day_type is distinct from old.day_type
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists v1_workforce_calendar_weekdays_history_guard
  on public.v1_workforce_calendar_weekdays;
create trigger v1_workforce_calendar_weekdays_history_guard
before update on public.v1_workforce_calendar_weekdays
for each row execute function public.v1_workforce_guard_calendar_weekday_history();

create or replace function public.v1_workforce_guard_shift_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.v1_workforce_shift_is_retained(old.id) and (
    new.shift_code is distinct from old.shift_code
    or new.shift_kind is distinct from old.shift_kind
    or new.start_time is distinct from old.start_time
    or new.end_time is distinct from old.end_time
    or new.scheduled_minutes is distinct from old.scheduled_minutes
    or new.break_minutes is distinct from old.break_minutes
    or new.valid_from is distinct from old.valid_from
    or new.valid_to is distinct from old.valid_to
  ) then
    raise exception 'V1_WORKFORCE_SHIFT_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  if old.is_active and not new.is_active and (
    exists (
      select 1
      from public.v1_workforce_team_schedule_links link
      where link.shift_template_id = old.id
        and (link.valid_to is null or link.valid_to >= current_date)
    )
    or exists (
      select 1
      from public.v1_workforce_calendar_dates calendar_date
      where calendar_date.shift_template_id = old.id
        and calendar_date.is_active
        and calendar_date.calendar_date >= current_date
    )
  ) then
    raise exception 'V1_WORKFORCE_SHIFT_ACTIVE_USE'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.v1_workforce_guard_calendar_date_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.calendar_date <= current_date or new.calendar_date <= current_date)
    and (
      new.calendar_id is distinct from old.calendar_id
      or new.calendar_date is distinct from old.calendar_date
      or new.override_kind is distinct from old.override_kind
      or new.day_type is distinct from old.day_type
      or new.exception_name is distinct from old.exception_name
      or new.scheduled_minutes is distinct from old.scheduled_minutes
      or new.break_minutes is distinct from old.break_minutes
      or new.shift_template_id is distinct from old.shift_template_id
      or new.notes is distinct from old.notes
    )
  then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  if old.calendar_date = current_date
    and old.is_active
    and not new.is_active
  then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_ACTIVE_USE'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists v1_workforce_calendar_dates_history_guard
  on public.v1_workforce_calendar_dates;
create trigger v1_workforce_calendar_dates_history_guard
before update on public.v1_workforce_calendar_dates
for each row execute function public.v1_workforce_guard_calendar_date_history();

create or replace function public.v1_workforce_guard_team_schedule_link_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (old.valid_from <= current_date or new.valid_from <= current_date) and (
    new.team_id is distinct from old.team_id
    or new.calendar_id is distinct from old.calendar_id
    or new.shift_template_id is distinct from old.shift_template_id
    or new.valid_from is distinct from old.valid_from
    or new.valid_to is distinct from old.valid_to
    or new.reason is distinct from old.reason
  ) then
    raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

drop trigger if exists v1_workforce_team_schedule_links_history_guard
  on public.v1_workforce_team_schedule_links;
create trigger v1_workforce_team_schedule_links_history_guard
before update on public.v1_workforce_team_schedule_links
for each row execute function public.v1_workforce_guard_team_schedule_link_history();

revoke all on function public.v1_workforce_calendar_is_retained(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_shift_is_retained(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_calendar_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_calendar_weekday_history()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_shift_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_calendar_date_history()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_team_schedule_link_history()
  from public, anon, authenticated;
