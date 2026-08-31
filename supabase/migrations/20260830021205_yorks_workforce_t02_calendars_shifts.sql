-- Yorks Workforce T02: effective working calendars, dated exceptions,
-- reusable shifts and team schedule defaults. This slice remains route-less,
-- default-off and exact-Admin-only; it creates no attendance or timesheet fact.

create table public.v1_workforce_calendars (
  id uuid primary key default gen_random_uuid(),
  calendar_code text not null check (
    btrim(calendar_code) <> '' and char_length(calendar_code) <= 40
  ),
  calendar_name text not null check (
    btrim(calendar_name) <> '' and char_length(calendar_name) <= 160
  ),
  timezone_name text not null check (
    btrim(timezone_name) <> '' and char_length(timezone_name) <= 120
  ),
  standard_scheduled_minutes integer not null check (
    standard_scheduled_minutes between 1 and 1440
  ),
  break_minutes integer not null default 0 check (
    break_minutes between 0 and 1440
  ),
  valid_from date not null,
  valid_to date,
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (valid_to is null or valid_to >= valid_from),
  check (standard_scheduled_minutes + break_minutes <= 1440),
  exclude using gist (
    (lower(btrim(calendar_code))) with =,
    daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    ) with &&
  )
);

create table public.v1_workforce_calendar_weekdays (
  calendar_id uuid not null
    references public.v1_workforce_calendars (id) on delete restrict,
  iso_weekday smallint not null check (iso_weekday between 1 and 7),
  day_type text not null check (
    day_type in ('regular_working_day', 'weekly_off')
  ),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (calendar_id, iso_weekday)
);

create table public.v1_workforce_shift_templates (
  id uuid primary key default gen_random_uuid(),
  shift_code text not null check (
    btrim(shift_code) <> '' and char_length(shift_code) <= 40
  ),
  shift_name text not null check (
    btrim(shift_name) <> '' and char_length(shift_name) <= 160
  ),
  shift_kind text not null check (
    shift_kind in (
      'normal_site', 'warehouse', 'workshop', 'ramadan', 'night', 'other'
    )
  ),
  start_time time,
  end_time time,
  scheduled_minutes integer not null check (
    scheduled_minutes between 1 and 1440
  ),
  break_minutes integer not null default 0 check (
    break_minutes between 0 and 1440
  ),
  crosses_midnight boolean generated always as (
    start_time is not null and end_time < start_time
  ) stored,
  work_date_basis text not null default 'shift_start_date' check (
    work_date_basis = 'shift_start_date'
  ),
  valid_from date not null,
  valid_to date,
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check ((start_time is null) = (end_time is null)),
  check (start_time is null or start_time <> end_time),
  check (scheduled_minutes + break_minutes <= 1440),
  check (valid_to is null or valid_to >= valid_from),
  exclude using gist (
    (lower(btrim(shift_code))) with =,
    daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    ) with &&
  )
);

create table public.v1_workforce_calendar_dates (
  id uuid primary key default gen_random_uuid(),
  calendar_id uuid not null
    references public.v1_workforce_calendars (id) on delete restrict,
  calendar_date date not null,
  override_kind text not null check (
    override_kind in ('public_holiday', 'site_closure', 'ramadan', 'other')
  ),
  day_type text not null check (
    day_type in (
      'regular_working_day', 'weekly_off', 'public_holiday', 'site_closed',
      'not_scheduled'
    )
  ),
  exception_name text not null check (
    btrim(exception_name) <> '' and char_length(exception_name) <= 180
  ),
  scheduled_minutes integer not null check (
    scheduled_minutes between 0 and 1440
  ),
  break_minutes integer not null default 0 check (
    break_minutes between 0 and 1440
  ),
  shift_template_id uuid
    references public.v1_workforce_shift_templates (id) on delete restrict,
  notes text check (notes is null or char_length(notes) <= 1000),
  is_active boolean not null default true,
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  unique (calendar_id, calendar_date),
  check (scheduled_minutes + break_minutes <= 1440),
  check (
    (day_type = 'regular_working_day' and scheduled_minutes > 0)
    or (day_type <> 'regular_working_day'
      and scheduled_minutes = 0 and break_minutes = 0)
  ),
  check (
    (override_kind = 'public_holiday' and day_type = 'public_holiday')
    or (override_kind = 'site_closure' and day_type = 'site_closed')
    or (override_kind = 'ramadan' and day_type = 'regular_working_day')
    or (override_kind = 'other' and day_type in (
      'regular_working_day', 'weekly_off', 'not_scheduled'
    ))
  )
);

create table public.v1_workforce_team_schedule_links (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null
    references public.v1_workforce_teams (id) on delete restrict,
  calendar_id uuid not null
    references public.v1_workforce_calendars (id) on delete restrict,
  shift_template_id uuid
    references public.v1_workforce_shift_templates (id) on delete restrict,
  valid_from date not null,
  valid_to date,
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 500
  ),
  record_version bigint not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  check (valid_to is null or valid_to >= valid_from),
  exclude using gist (
    team_id with =,
    daterange(
      valid_from,
      coalesce(valid_to + 1, 'infinity'::date),
      '[)'
    ) with &&
  )
);

create index v1_workforce_calendar_dates_date_idx
  on public.v1_workforce_calendar_dates (calendar_date, calendar_id);
create index v1_workforce_team_schedule_links_effective_idx
  on public.v1_workforce_team_schedule_links (team_id, valid_from, valid_to);

alter table public.v1_workforce_calendars enable row level security;
alter table public.v1_workforce_calendar_weekdays enable row level security;
alter table public.v1_workforce_shift_templates enable row level security;
alter table public.v1_workforce_calendar_dates enable row level security;
alter table public.v1_workforce_team_schedule_links enable row level security;

revoke all on table public.v1_workforce_calendars
  from public, anon, authenticated;
revoke all on table public.v1_workforce_calendar_weekdays
  from public, anon, authenticated;
revoke all on table public.v1_workforce_shift_templates
  from public, anon, authenticated;
revoke all on table public.v1_workforce_calendar_dates
  from public, anon, authenticated;
revoke all on table public.v1_workforce_team_schedule_links
  from public, anon, authenticated;

grant all on table public.v1_workforce_calendars to service_role;
grant all on table public.v1_workforce_calendar_weekdays to service_role;
grant all on table public.v1_workforce_shift_templates to service_role;
grant all on table public.v1_workforce_calendar_dates to service_role;
grant all on table public.v1_workforce_team_schedule_links to service_role;

create trigger v1_workforce_calendars_no_delete
before delete on public.v1_workforce_calendars
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_calendar_weekdays_no_delete
before delete on public.v1_workforce_calendar_weekdays
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_shift_templates_no_delete
before delete on public.v1_workforce_shift_templates
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_calendar_dates_no_delete
before delete on public.v1_workforce_calendar_dates
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_team_schedule_links_no_delete
before delete on public.v1_workforce_team_schedule_links
for each row execute function public.v1_workforce_block_delete();

create or replace function public.v1_workforce_timezone_is_valid(
  p_timezone_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from pg_catalog.pg_timezone_names timezone
    where timezone.name = p_timezone_name
  );
$$;

create or replace function public.v1_workforce_validate_calendar_date()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_calendar public.v1_workforce_calendars%rowtype;
  v_shift public.v1_workforce_shift_templates%rowtype;
begin
  select calendar.* into strict v_calendar
  from public.v1_workforce_calendars calendar
  where calendar.id = new.calendar_id;

  if new.calendar_date < v_calendar.valid_from
    or (v_calendar.valid_to is not null
      and new.calendar_date > v_calendar.valid_to)
  then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_OUTSIDE_CALENDAR'
      using errcode = '23514';
  end if;

  if new.shift_template_id is not null then
    select shift.* into strict v_shift
    from public.v1_workforce_shift_templates shift
    where shift.id = new.shift_template_id;
    if not v_shift.is_active
      or new.calendar_date < v_shift.valid_from
      or (v_shift.valid_to is not null
        and new.calendar_date > v_shift.valid_to)
    then
      raise exception 'V1_WORKFORCE_CALENDAR_DATE_OUTSIDE_SHIFT'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger v1_workforce_calendar_dates_validate
before insert or update on public.v1_workforce_calendar_dates
for each row execute function public.v1_workforce_validate_calendar_date();

create or replace function public.v1_workforce_validate_team_schedule_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_team public.v1_workforce_teams%rowtype;
  v_calendar public.v1_workforce_calendars%rowtype;
  v_shift public.v1_workforce_shift_templates%rowtype;
begin
  select team.* into strict v_team
  from public.v1_workforce_teams team where team.id = new.team_id;
  select calendar.* into strict v_calendar
  from public.v1_workforce_calendars calendar where calendar.id = new.calendar_id;

  if not v_team.is_active
    or not v_calendar.is_active
    or new.valid_from < v_team.valid_from
    or (v_team.valid_to is not null
      and (new.valid_to is null or new.valid_to > v_team.valid_to))
    or new.valid_from < v_calendar.valid_from
    or (v_calendar.valid_to is not null
      and (new.valid_to is null or new.valid_to > v_calendar.valid_to))
  then
    raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_OUTSIDE_PARENT_WINDOW'
      using errcode = '23514';
  end if;

  if new.shift_template_id is not null then
    select shift.* into strict v_shift
    from public.v1_workforce_shift_templates shift
    where shift.id = new.shift_template_id;
    if not v_shift.is_active
      or new.valid_from < v_shift.valid_from
      or (v_shift.valid_to is not null
        and (new.valid_to is null or new.valid_to > v_shift.valid_to))
    then
      raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_OUTSIDE_SHIFT_WINDOW'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger v1_workforce_team_schedule_links_validate
before insert or update on public.v1_workforce_team_schedule_links
for each row execute function public.v1_workforce_validate_team_schedule_link();

create or replace function public.v1_workforce_guard_calendar_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (not new.is_active and exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.calendar_id = old.id
  )) or exists (
    select 1 from public.v1_workforce_calendar_dates calendar_date
    where calendar_date.calendar_id = old.id
      and (
        calendar_date.calendar_date < new.valid_from
        or (new.valid_to is not null
          and calendar_date.calendar_date > new.valid_to)
      )
  ) or exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.calendar_id = old.id
      and (
        link.valid_from < new.valid_from
        or (new.valid_to is not null
          and (link.valid_to is null or link.valid_to > new.valid_to))
      )
  ) then
    raise exception 'V1_WORKFORCE_CALENDAR_DATES_CONFLICT_WITH_HISTORY'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_calendars_parent_guard
before update on public.v1_workforce_calendars
for each row execute function public.v1_workforce_guard_calendar_parent_update();

create or replace function public.v1_workforce_guard_shift_parent_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (not new.is_active and exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.shift_template_id = old.id
  )) or exists (
    select 1 from public.v1_workforce_calendar_dates calendar_date
    where calendar_date.shift_template_id = old.id
      and (
        calendar_date.calendar_date < new.valid_from
        or (new.valid_to is not null
          and calendar_date.calendar_date > new.valid_to)
      )
  ) or exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.shift_template_id = old.id
      and (
        link.valid_from < new.valid_from
        or (new.valid_to is not null
          and (link.valid_to is null or link.valid_to > new.valid_to))
      )
  ) then
    raise exception 'V1_WORKFORCE_SHIFT_DATES_CONFLICT_WITH_HISTORY'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_shift_templates_parent_guard
before update on public.v1_workforce_shift_templates
for each row execute function public.v1_workforce_guard_shift_parent_update();

create or replace function public.v1_workforce_guard_team_schedule_history()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (not new.is_active and exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.team_id = old.id
  )) or exists (
    select 1 from public.v1_workforce_team_schedule_links link
    where link.team_id = old.id
      and (
        link.valid_from < new.valid_from
        or (new.valid_to is not null
          and (link.valid_to is null or link.valid_to > new.valid_to))
      )
  ) then
    raise exception 'V1_WORKFORCE_TEAM_DATES_CONFLICT_WITH_SCHEDULES'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_teams_schedule_history_guard
before update on public.v1_workforce_teams
for each row execute function public.v1_workforce_guard_team_schedule_history();

create or replace function public.v1_get_workforce_configuration(
  p_on_date date default current_date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_on_date date := coalesce(p_on_date, current_date);
begin
  return jsonb_build_object(
    'schema_version', 1,
    'authorization_mode', 'admin_legacy_t02',
    'actor_auth_user_id', v_actor,
    'on_date', v_on_date,
    'server_time', clock_timestamp(),
    'calendars', coalesce((
      select jsonb_agg(jsonb_build_object(
        'calendar_id', calendar.id,
        'calendar_code', calendar.calendar_code,
        'calendar_name', calendar.calendar_name,
        'timezone_name', calendar.timezone_name,
        'standard_scheduled_minutes', calendar.standard_scheduled_minutes,
        'break_minutes', calendar.break_minutes,
        'valid_from', calendar.valid_from,
        'valid_to', calendar.valid_to,
        'is_active', calendar.is_active,
        'is_effective', v_on_date >= calendar.valid_from and (
          calendar.valid_to is null or v_on_date <= calendar.valid_to
        ),
        'record_version', calendar.record_version,
        'weekdays', coalesce((
          select jsonb_agg(jsonb_build_object(
            'iso_weekday', weekday.iso_weekday,
            'day_type', weekday.day_type
          ) order by weekday.iso_weekday)
          from public.v1_workforce_calendar_weekdays weekday
          where weekday.calendar_id = calendar.id
        ), '[]'::jsonb),
        'date_overrides', coalesce((
          select jsonb_agg(jsonb_build_object(
            'calendar_date_id', calendar_date.id,
            'calendar_date', calendar_date.calendar_date,
            'override_kind', calendar_date.override_kind,
            'day_type', calendar_date.day_type,
            'exception_name', calendar_date.exception_name,
            'scheduled_minutes', calendar_date.scheduled_minutes,
            'break_minutes', calendar_date.break_minutes,
            'shift_template_id', calendar_date.shift_template_id,
            'notes', calendar_date.notes,
            'is_active', calendar_date.is_active,
            'record_version', calendar_date.record_version
          ) order by calendar_date.calendar_date, calendar_date.id)
          from public.v1_workforce_calendar_dates calendar_date
          where calendar_date.calendar_id = calendar.id
        ), '[]'::jsonb)
      ) order by calendar.calendar_code, calendar.valid_from, calendar.id)
      from public.v1_workforce_calendars calendar
    ), '[]'::jsonb),
    'shift_templates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'shift_template_id', shift.id,
        'shift_code', shift.shift_code,
        'shift_name', shift.shift_name,
        'shift_kind', shift.shift_kind,
        'start_time', shift.start_time,
        'end_time', shift.end_time,
        'scheduled_minutes', shift.scheduled_minutes,
        'break_minutes', shift.break_minutes,
        'crosses_midnight', shift.crosses_midnight,
        'work_date_basis', shift.work_date_basis,
        'valid_from', shift.valid_from,
        'valid_to', shift.valid_to,
        'is_active', shift.is_active,
        'is_effective', v_on_date >= shift.valid_from and (
          shift.valid_to is null or v_on_date <= shift.valid_to
        ),
        'record_version', shift.record_version
      ) order by shift.shift_code, shift.valid_from, shift.id)
      from public.v1_workforce_shift_templates shift
    ), '[]'::jsonb),
    'team_schedule_links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'team_schedule_link_id', link.id,
        'team_id', link.team_id,
        'team_code', team.team_code,
        'team_name', team.team_name,
        'calendar_id', link.calendar_id,
        'calendar_code', calendar.calendar_code,
        'calendar_name', calendar.calendar_name,
        'timezone_name', calendar.timezone_name,
        'shift_template_id', link.shift_template_id,
        'shift_code', shift.shift_code,
        'shift_name', shift.shift_name,
        'valid_from', link.valid_from,
        'valid_to', link.valid_to,
        'reason', link.reason,
        'is_effective', v_on_date >= link.valid_from and (
          link.valid_to is null or v_on_date <= link.valid_to
        ),
        'record_version', link.record_version
      ) order by team.team_code, link.valid_from, link.id)
      from public.v1_workforce_team_schedule_links link
      join public.v1_workforce_teams team on team.id = link.team_id
      join public.v1_workforce_calendars calendar on calendar.id = link.calendar_id
      left join public.v1_workforce_shift_templates shift
        on shift.id = link.shift_template_id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_save_workforce_calendar(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_valid_from date;
  v_valid_to date;
  v_standard_minutes integer;
  v_break_minutes integer;
  v_weekday jsonb;
  v_before jsonb;
  v_calendar public.v1_workforce_calendars%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'calendar_id','calendar_code','calendar_name','timezone_name',
      'standard_scheduled_minutes','break_minutes','valid_from','valid_to',
      'is_active','weekdays'
    ],
    'save_workforce_calendar_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_calendar', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'calendar_id', '')), '')::uuid;
    v_valid_from := nullif(btrim(coalesce(p_payload ->> 'valid_from', '')), '')::date;
    v_valid_to := nullif(btrim(coalesce(p_payload ->> 'valid_to', '')), '')::date;
    v_standard_minutes := (p_payload ->> 'standard_scheduled_minutes')::integer;
    v_break_minutes := coalesce((p_payload ->> 'break_minutes')::integer, 0);
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_CALENDAR_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if btrim(coalesce(p_payload ->> 'calendar_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'calendar_name', '')) = ''
    or btrim(coalesce(p_payload ->> 'timezone_name', '')) = ''
    or v_valid_from is null
    or v_standard_minutes is null
    or v_standard_minutes < 1 or v_standard_minutes > 1440
    or v_break_minutes < 0
    or v_standard_minutes + v_break_minutes > 1440
    or (v_valid_to is not null and v_valid_to < v_valid_from)
    or not public.v1_workforce_timezone_is_valid(
      btrim(p_payload ->> 'timezone_name')
    )
  then
    raise exception 'V1_WORKFORCE_CALENDAR_INPUT_INVALID'
      using errcode = '22023';
  end if;
  if jsonb_typeof(p_payload -> 'weekdays') <> 'array'
    or jsonb_array_length(p_payload -> 'weekdays') <> 7
    or exists (
      select 1
      from jsonb_array_elements(p_payload -> 'weekdays') item
      where jsonb_typeof(item) <> 'object'
        or coalesce(item ->> 'iso_weekday', '') !~ '^[1-7]$'
        or coalesce(item ->> 'day_type', '') not in (
          'regular_working_day', 'weekly_off'
        )
    )
    or exists (
      select 1
      from jsonb_array_elements(p_payload -> 'weekdays') item
      group by item ->> 'iso_weekday'
      having count(*) > 1
    )
    or not exists (
      select 1
      from jsonb_array_elements(p_payload -> 'weekdays') item
      where item ->> 'day_type' = 'regular_working_day'
    )
  then
    raise exception 'V1_WORKFORCE_CALENDAR_WEEKDAYS_INVALID'
      using errcode = '22023';
  end if;

  select calendar.* into v_calendar
  from public.v1_workforce_calendars calendar
  where calendar.id = v_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> v_calendar.record_version then
      raise exception 'V1_WORKFORCE_CALENDAR_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_before := to_jsonb(v_calendar) || jsonb_build_object(
      'weekdays', (
        select coalesce(jsonb_agg(jsonb_build_object(
          'iso_weekday', weekday.iso_weekday,
          'day_type', weekday.day_type
        ) order by weekday.iso_weekday), '[]'::jsonb)
        from public.v1_workforce_calendar_weekdays weekday
        where weekday.calendar_id = v_id
      )
    );
    update public.v1_workforce_calendars set
      calendar_code = upper(btrim(p_payload ->> 'calendar_code')),
      calendar_name = btrim(p_payload ->> 'calendar_name'),
      timezone_name = btrim(p_payload ->> 'timezone_name'),
      standard_scheduled_minutes = v_standard_minutes,
      break_minutes = v_break_minutes,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_calendar;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_CALENDAR_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_calendars (
      id, calendar_code, calendar_name, timezone_name,
      standard_scheduled_minutes, break_minutes, valid_from, valid_to,
      is_active, created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'calendar_code')),
      btrim(p_payload ->> 'calendar_name'),
      btrim(p_payload ->> 'timezone_name'),
      v_standard_minutes, v_break_minutes, v_valid_from, v_valid_to,
      coalesce((p_payload ->> 'is_active')::boolean, true), v_actor, v_actor
    ) returning * into v_calendar;
  end if;

  for v_weekday in select value from jsonb_array_elements(p_payload -> 'weekdays')
  loop
    insert into public.v1_workforce_calendar_weekdays (
      calendar_id, iso_weekday, day_type,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_calendar.id, (v_weekday ->> 'iso_weekday')::smallint,
      v_weekday ->> 'day_type', v_actor, v_actor
    ) on conflict (calendar_id, iso_weekday) do update set
      day_type = excluded.day_type,
      updated_by_auth_user_id = excluded.updated_by_auth_user_id,
      updated_at = clock_timestamp();
  end loop;

  v_response := jsonb_build_object(
    'schema_version', 1,
    'calendar_id', v_calendar.id,
    'record_version', v_calendar.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_calendar_created'
      else 'workforce_calendar_updated' end,
    'workforce_calendar', v_calendar.id, null, v_before,
    to_jsonb(v_calendar) || jsonb_build_object('weekdays', p_payload -> 'weekdays'),
    'Workforce calendar saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_calendar', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_shift_template(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_start_time time;
  v_end_time time;
  v_scheduled_minutes integer;
  v_break_minutes integer;
  v_valid_from date;
  v_valid_to date;
  v_before jsonb;
  v_shift public.v1_workforce_shift_templates%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'shift_template_id','shift_code','shift_name','shift_kind','start_time',
      'end_time','scheduled_minutes','break_minutes','valid_from','valid_to',
      'is_active'
    ],
    'save_workforce_shift_template_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_shift_template', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;
  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'shift_template_id', '')), '')::uuid;
    v_start_time := nullif(btrim(coalesce(p_payload ->> 'start_time', '')), '')::time;
    v_end_time := nullif(btrim(coalesce(p_payload ->> 'end_time', '')), '')::time;
    v_scheduled_minutes := (p_payload ->> 'scheduled_minutes')::integer;
    v_break_minutes := coalesce((p_payload ->> 'break_minutes')::integer, 0);
    v_valid_from := nullif(btrim(coalesce(p_payload ->> 'valid_from', '')), '')::date;
    v_valid_to := nullif(btrim(coalesce(p_payload ->> 'valid_to', '')), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_SHIFT_INPUT_INVALID' using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if btrim(coalesce(p_payload ->> 'shift_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'shift_name', '')) = ''
    or coalesce(p_payload ->> 'shift_kind', '') not in (
      'normal_site', 'warehouse', 'workshop', 'ramadan', 'night', 'other'
    )
    or (v_start_time is null) <> (v_end_time is null)
    or (v_start_time is not null and v_start_time = v_end_time)
    or v_scheduled_minutes is null or v_scheduled_minutes < 1
    or v_scheduled_minutes > 1440 or v_break_minutes < 0
    or v_scheduled_minutes + v_break_minutes > 1440
    or v_valid_from is null
    or (v_valid_to is not null and v_valid_to < v_valid_from)
  then
    raise exception 'V1_WORKFORCE_SHIFT_INPUT_INVALID' using errcode = '22023';
  end if;

  select shift.* into v_shift
  from public.v1_workforce_shift_templates shift
  where shift.id = v_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> v_shift.record_version then
      raise exception 'V1_WORKFORCE_SHIFT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_before := to_jsonb(v_shift);
    update public.v1_workforce_shift_templates set
      shift_code = upper(btrim(p_payload ->> 'shift_code')),
      shift_name = btrim(p_payload ->> 'shift_name'),
      shift_kind = p_payload ->> 'shift_kind',
      start_time = v_start_time,
      end_time = v_end_time,
      scheduled_minutes = v_scheduled_minutes,
      break_minutes = v_break_minutes,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_shift;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_SHIFT_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_shift_templates (
      id, shift_code, shift_name, shift_kind, start_time, end_time,
      scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
      created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, upper(btrim(p_payload ->> 'shift_code')),
      btrim(p_payload ->> 'shift_name'), p_payload ->> 'shift_kind',
      v_start_time, v_end_time, v_scheduled_minutes, v_break_minutes,
      v_valid_from, v_valid_to,
      coalesce((p_payload ->> 'is_active')::boolean, true), v_actor, v_actor
    ) returning * into v_shift;
  end if;
  v_response := jsonb_build_object(
    'schema_version', 1,
    'shift_template_id', v_shift.id,
    'record_version', v_shift.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_shift_template_created'
      else 'workforce_shift_template_updated' end,
    'workforce_shift_template', v_shift.id, null, v_before,
    to_jsonb(v_shift), 'Workforce shift template saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_shift_template', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_calendar_date(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_calendar_id uuid;
  v_shift_id uuid;
  v_calendar_date date;
  v_scheduled_minutes integer;
  v_break_minutes integer;
  v_day_type text;
  v_override_kind text;
  v_calendar public.v1_workforce_calendars%rowtype;
  v_before jsonb;
  v_date public.v1_workforce_calendar_dates%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'calendar_date_id','calendar_id','calendar_date','override_kind',
      'day_type','exception_name','scheduled_minutes','break_minutes',
      'shift_template_id','notes','is_active'
    ],
    'save_workforce_calendar_date_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_calendar_date', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;
  begin
    v_id := nullif(btrim(coalesce(p_payload ->> 'calendar_date_id', '')), '')::uuid;
    v_calendar_id := nullif(btrim(coalesce(p_payload ->> 'calendar_id', '')), '')::uuid;
    v_shift_id := nullif(btrim(coalesce(p_payload ->> 'shift_template_id', '')), '')::uuid;
    v_calendar_date := nullif(btrim(coalesce(p_payload ->> 'calendar_date', '')), '')::date;
    v_scheduled_minutes := nullif(btrim(coalesce(
      p_payload ->> 'scheduled_minutes', ''
    )), '')::integer;
    v_break_minutes := nullif(btrim(coalesce(
      p_payload ->> 'break_minutes', ''
    )), '')::integer;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  v_day_type := coalesce(p_payload ->> 'day_type', '');
  v_override_kind := coalesce(p_payload ->> 'override_kind', '');
  if v_calendar_id is null or v_calendar_date is null
    or btrim(coalesce(p_payload ->> 'exception_name', '')) = ''
    or v_day_type not in (
      'regular_working_day', 'weekly_off', 'public_holiday', 'site_closed',
      'not_scheduled'
    )
    or v_override_kind not in (
      'public_holiday', 'site_closure', 'ramadan', 'other'
    )
  then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_INPUT_INVALID'
      using errcode = '22023';
  end if;
  select calendar.* into strict v_calendar
  from public.v1_workforce_calendars calendar
  where calendar.id = v_calendar_id;
  if v_day_type = 'regular_working_day' then
    v_scheduled_minutes := coalesce(
      v_scheduled_minutes, v_calendar.standard_scheduled_minutes
    );
    v_break_minutes := coalesce(v_break_minutes, v_calendar.break_minutes);
  else
    v_scheduled_minutes := coalesce(v_scheduled_minutes, 0);
    v_break_minutes := coalesce(v_break_minutes, 0);
  end if;
  if v_scheduled_minutes < 0 or v_scheduled_minutes > 1440
    or v_break_minutes < 0
    or v_scheduled_minutes + v_break_minutes > 1440
    or (v_day_type = 'regular_working_day' and v_scheduled_minutes = 0)
    or (v_day_type <> 'regular_working_day'
      and (v_scheduled_minutes <> 0 or v_break_minutes <> 0))
    or (v_override_kind = 'public_holiday' and v_day_type <> 'public_holiday')
    or (v_override_kind = 'site_closure' and v_day_type <> 'site_closed')
    or (v_override_kind = 'ramadan' and v_day_type <> 'regular_working_day')
    or (v_override_kind = 'other' and v_day_type not in (
      'regular_working_day', 'weekly_off', 'not_scheduled'
    ))
  then
    raise exception 'V1_WORKFORCE_CALENDAR_DATE_INPUT_INVALID'
      using errcode = '22023';
  end if;

  select calendar_date.* into v_date
  from public.v1_workforce_calendar_dates calendar_date
  where calendar_date.id = v_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> v_date.record_version then
      raise exception 'V1_WORKFORCE_CALENDAR_DATE_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_before := to_jsonb(v_date);
    update public.v1_workforce_calendar_dates set
      calendar_id = v_calendar_id,
      calendar_date = v_calendar_date,
      override_kind = v_override_kind,
      day_type = v_day_type,
      exception_name = btrim(p_payload ->> 'exception_name'),
      scheduled_minutes = v_scheduled_minutes,
      break_minutes = v_break_minutes,
      shift_template_id = v_shift_id,
      notes = nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
      is_active = coalesce((p_payload ->> 'is_active')::boolean, true),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_date;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_CALENDAR_DATE_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_calendar_dates (
      id, calendar_id, calendar_date, override_kind, day_type,
      exception_name, scheduled_minutes, break_minutes, shift_template_id,
      notes, is_active, created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, v_calendar_id, v_calendar_date, v_override_kind, v_day_type,
      btrim(p_payload ->> 'exception_name'), v_scheduled_minutes,
      v_break_minutes, v_shift_id,
      nullif(btrim(coalesce(p_payload ->> 'notes', '')), ''),
      coalesce((p_payload ->> 'is_active')::boolean, true), v_actor, v_actor
    ) returning * into v_date;
  end if;
  v_response := jsonb_build_object(
    'schema_version', 1,
    'calendar_date_id', v_date.id,
    'record_version', v_date.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_calendar_date_created'
      else 'workforce_calendar_date_updated' end,
    'workforce_calendar_date', v_date.id, null, v_before,
    to_jsonb(v_date), 'Workforce calendar date saved', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_calendar_date', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_workforce_team_schedule(
  p_payload jsonb,
  p_expected_version bigint,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_workforce_assert_admin();
  v_existing jsonb;
  v_id uuid;
  v_team_id uuid;
  v_calendar_id uuid;
  v_shift_id uuid;
  v_valid_from date;
  v_valid_to date;
  v_project_id uuid;
  v_before jsonb;
  v_link public.v1_workforce_team_schedule_links%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'team_schedule_link_id','team_id','calendar_id','shift_template_id',
      'valid_from','valid_to','reason'
    ],
    'save_workforce_team_schedule_payload'
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_workforce_team_schedule', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;
  begin
    v_id := nullif(btrim(coalesce(
      p_payload ->> 'team_schedule_link_id', ''
    )), '')::uuid;
    v_team_id := nullif(btrim(coalesce(p_payload ->> 'team_id', '')), '')::uuid;
    v_calendar_id := nullif(btrim(coalesce(
      p_payload ->> 'calendar_id', ''
    )), '')::uuid;
    v_shift_id := nullif(btrim(coalesce(
      p_payload ->> 'shift_template_id', ''
    )), '')::uuid;
    v_valid_from := nullif(btrim(coalesce(p_payload ->> 'valid_from', '')), '')::date;
    v_valid_to := nullif(btrim(coalesce(p_payload ->> 'valid_to', '')), '')::date;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_INPUT_INVALID'
      using errcode = '22023';
  end;
  v_id := coalesce(v_id, gen_random_uuid());
  if v_team_id is null or v_calendar_id is null or v_valid_from is null
    or (v_valid_to is not null and v_valid_to < v_valid_from)
    or btrim(coalesce(p_payload ->> 'reason', '')) = ''
  then
    raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_INPUT_INVALID'
      using errcode = '22023';
  end if;
  select team.default_project_id into v_project_id
  from public.v1_workforce_teams team where team.id = v_team_id;
  if not found then
    raise exception 'V1_WORKFORCE_TEAM_NOT_FOUND' using errcode = 'P0002';
  end if;

  select link.* into v_link
  from public.v1_workforce_team_schedule_links link
  where link.id = v_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> v_link.record_version then
      raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    v_before := to_jsonb(v_link);
    update public.v1_workforce_team_schedule_links set
      team_id = v_team_id,
      calendar_id = v_calendar_id,
      shift_template_id = v_shift_id,
      valid_from = v_valid_from,
      valid_to = v_valid_to,
      reason = btrim(p_payload ->> 'reason'),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_id returning * into v_link;
  else
    if p_expected_version is not null then
      raise exception 'V1_WORKFORCE_TEAM_SCHEDULE_NOT_FOUND'
        using errcode = 'P0002';
    end if;
    insert into public.v1_workforce_team_schedule_links (
      id, team_id, calendar_id, shift_template_id, valid_from, valid_to,
      reason, created_by_auth_user_id, updated_by_auth_user_id
    ) values (
      v_id, v_team_id, v_calendar_id, v_shift_id, v_valid_from, v_valid_to,
      btrim(p_payload ->> 'reason'), v_actor, v_actor
    ) returning * into v_link;
  end if;
  v_response := jsonb_build_object(
    'schema_version', 1,
    'team_schedule_link_id', v_link.id,
    'record_version', v_link.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'workforce_team_schedule_created'
      else 'workforce_team_schedule_updated' end,
    'workforce_team_schedule', v_link.id, v_project_id, v_before,
    to_jsonb(v_link), v_link.reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_workforce_team_schedule', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_workforce_timezone_is_valid(text)
  from public, anon, authenticated;
revoke all on function public.v1_workforce_validate_calendar_date()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_validate_team_schedule_link()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_calendar_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_shift_parent_update()
  from public, anon, authenticated;
revoke all on function public.v1_workforce_guard_team_schedule_history()
  from public, anon, authenticated;

revoke all on function public.v1_get_workforce_configuration(date)
  from public, anon;
revoke all on function public.v1_save_workforce_calendar(jsonb,bigint,uuid)
  from public, anon;
revoke all on function public.v1_save_workforce_shift_template(jsonb,bigint,uuid)
  from public, anon;
revoke all on function public.v1_save_workforce_calendar_date(jsonb,bigint,uuid)
  from public, anon;
revoke all on function public.v1_save_workforce_team_schedule(jsonb,bigint,uuid)
  from public, anon;

grant execute on function public.v1_get_workforce_configuration(date)
  to authenticated;
grant execute on function public.v1_save_workforce_calendar(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_save_workforce_shift_template(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_save_workforce_calendar_date(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_save_workforce_team_schedule(jsonb,bigint,uuid)
  to authenticated;
