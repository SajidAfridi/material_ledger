-- Yorks Workforce T02 correction: effective and retained dates are evaluated
-- in the exact linked calendar IANA timezone, never the database session
-- timezone. Past/current dated override active state is immutable.

create or replace function public.v1_workforce_guard_calendar_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_instant timestamptz := clock_timestamp();
  v_calendar_date date;
begin
  v_calendar_date := (v_instant at time zone old.timezone_name)::date;

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
        and (link.valid_to is null or link.valid_to >= v_calendar_date)
    )
    or exists (
      select 1
      from public.v1_workforce_calendar_dates calendar_date
      where calendar_date.calendar_id = old.id
        and calendar_date.is_active
        and calendar_date.calendar_date >= v_calendar_date
    )
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_ACTIVE_USE'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.v1_workforce_guard_shift_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_instant timestamptz := clock_timestamp();
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
      join public.v1_workforce_calendars calendar
        on calendar.id = link.calendar_id
      where link.shift_template_id = old.id
        and (
          link.valid_to is null
          or link.valid_to >= (
            v_instant at time zone calendar.timezone_name
          )::date
        )
    )
    or exists (
      select 1
      from public.v1_workforce_calendar_dates calendar_date
      join public.v1_workforce_calendars calendar
        on calendar.id = calendar_date.calendar_id
      where calendar_date.shift_template_id = old.id
        and calendar_date.is_active
        and calendar_date.calendar_date >= (
          v_instant at time zone calendar.timezone_name
        )::date
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
declare
  v_instant timestamptz := clock_timestamp();
  v_old_timezone text;
  v_new_timezone text;
  v_old_calendar_date date;
  v_new_calendar_date date;
begin
  select calendar.timezone_name into strict v_old_timezone
  from public.v1_workforce_calendars calendar
  where calendar.id = old.calendar_id;

  if new.calendar_id = old.calendar_id then
    v_new_timezone := v_old_timezone;
  else
    select calendar.timezone_name into strict v_new_timezone
    from public.v1_workforce_calendars calendar
    where calendar.id = new.calendar_id;
  end if;

  v_old_calendar_date := (v_instant at time zone v_old_timezone)::date;
  v_new_calendar_date := (v_instant at time zone v_new_timezone)::date;

  if (
    old.calendar_date <= v_old_calendar_date
    or new.calendar_date <= v_new_calendar_date
  ) and (
    new.calendar_id is distinct from old.calendar_id
    or new.calendar_date is distinct from old.calendar_date
    or new.override_kind is distinct from old.override_kind
    or new.day_type is distinct from old.day_type
    or new.exception_name is distinct from old.exception_name
    or new.scheduled_minutes is distinct from old.scheduled_minutes
    or new.break_minutes is distinct from old.break_minutes
    or new.shift_template_id is distinct from old.shift_template_id
    or new.notes is distinct from old.notes
    or new.is_active is distinct from old.is_active
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.v1_workforce_guard_team_schedule_link_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_instant timestamptz := clock_timestamp();
  v_old_timezone text;
  v_new_timezone text;
  v_old_calendar_date date;
  v_new_calendar_date date;
begin
  select calendar.timezone_name into strict v_old_timezone
  from public.v1_workforce_calendars calendar
  where calendar.id = old.calendar_id;

  if new.calendar_id = old.calendar_id then
    v_new_timezone := v_old_timezone;
  else
    select calendar.timezone_name into strict v_new_timezone
    from public.v1_workforce_calendars calendar
    where calendar.id = new.calendar_id;
  end if;

  v_old_calendar_date := (v_instant at time zone v_old_timezone)::date;
  v_new_calendar_date := (v_instant at time zone v_new_timezone)::date;

  if (
    old.valid_from <= v_old_calendar_date
    or new.valid_from <= v_new_calendar_date
  ) and (
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

revoke all on function public.v1_workforce_guard_calendar_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_shift_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_calendar_date_history()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_team_schedule_link_history()
  from public, anon, authenticated;
