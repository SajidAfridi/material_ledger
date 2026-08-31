begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  (select bool_and(class.relrowsecurity)
   from pg_catalog.pg_class class
   where class.oid = any(array[
     'public.v1_workforce_calendars'::regclass,
     'public.v1_workforce_calendar_weekdays'::regclass,
     'public.v1_workforce_shift_templates'::regclass,
     'public.v1_workforce_calendar_dates'::regclass,
     'public.v1_workforce_team_schedule_links'::regclass
   ]))
  and not exists (
    select 1
    from (values
      ('public.v1_workforce_calendars'),
      ('public.v1_workforce_calendar_weekdays'),
      ('public.v1_workforce_shift_templates'),
      ('public.v1_workforce_calendar_dates'),
      ('public.v1_workforce_team_schedule_links')
    ) as relation(relation_name)
    cross join (values
      ('select'), ('insert'), ('update'), ('delete')
    ) as privilege(privilege_name)
    where has_table_privilege(
      'authenticated', relation.relation_name, privilege.privilege_name
    )
  ),
  'All five T02 relations use RLS and expose no authenticated CRUD privilege'
);

select ok(
  (select count(*)
   from public.v1_capability_catalog catalog
   where public.v1_workforce_is_capability_key(catalog.capability_key)
     and catalog.status = 'operational'
     and catalog.authorization_mode = 'enforced'
     and catalog.is_assignable) = 12,
  'The completed Workforce chain enables all twelve reviewed capabilities'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_configuration(date)', 'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_save_workforce_calendar(jsonb,bigint,uuid)', 'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_get_workforce_configuration(date)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_timezone_is_valid(text)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_calendar_is_retained(uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_shift_is_retained(uuid)', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_guard_calendar_date_history()', 'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_workforce_guard_team_schedule_link_history()', 'execute'
  ),
  'Only the protected T02 public RPC boundary is exposed to authenticated users'
);

select ok(
  (select bool_and(
    has_table_privilege('service_role', relation_name, 'select')
    and has_table_privilege('service_role', relation_name, 'insert')
    and has_table_privilege('service_role', relation_name, 'update')
    and has_table_privilege('service_role', relation_name, 'delete')
  ) from (values
    ('public.v1_workforce_calendars'),
    ('public.v1_workforce_calendar_weekdays'),
    ('public.v1_workforce_shift_templates'),
    ('public.v1_workforce_calendar_dates'),
    ('public.v1_workforce_team_schedule_links')
  ) as relation(relation_name)),
  'The service role alone retains direct T02 table administration access'
);

insert into public.v1_workforce_teams (
  id, team_code, team_name, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  '58010000-0000-4000-8000-000000000001',
  'WF-T02-TEAM', 'Workforce T02 schedule team',
  '2026-01-01', '2027-12-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000090",
      "calendar_code":"INVALID-TZ",
      "calendar_name":"Invalid timezone",
      "timezone_name":"Mars/Yorks",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000090'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_INPUT_INVALID',
  'Calendar timezone must be a real IANA timezone name'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_code":"BAD-MINUTES",
      "calendar_name":"Invalid minutes",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":1400,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000091'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_INPUT_INVALID',
  'Calendar work and break minutes cannot exceed one day'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_code":"BAD-RANGE",
      "calendar_name":"Invalid date range",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-12-31",
      "valid_to":"2026-01-01",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000092'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_INPUT_INVALID',
  'Calendar effective dates must be ordered'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_code":"DUP-WEEKDAY",
      "calendar_name":"Duplicate weekday",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000093'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_WEEKDAYS_INVALID',
  'A calendar rejects duplicate ISO weekdays even when seven rows are supplied'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_code":"NO-WORKING-DAY",
      "calendar_name":"No working day",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "weekdays":[
        {"iso_weekday":1,"day_type":"weekly_off"},
        {"iso_weekday":2,"day_type":"weekly_off"},
        {"iso_weekday":3,"day_type":"weekly_off"},
        {"iso_weekday":4,"day_type":"weekly_off"},
        {"iso_weekday":5,"day_type":"weekly_off"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000094'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_WEEKDAYS_INVALID',
  'A calendar must retain at least one regular working weekday'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000001'::uuid
  )$sql$,
  'Exact Admin can create an effective calendar with seven ISO weekdays'
);

select is(
  (public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000001'::uuid
  ) ->> 'record_version')::integer,
  1,
  'An identical calendar retry returns the completed version'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"Changed payload",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000001'::uuid
  )$sql$,
  '22023', 'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'The same idempotency key rejects a different calendar payload'
);

select is(
  jsonb_array_length(
    public.v1_get_workforce_configuration('2026-06-01')
      #> '{calendars,0,weekdays}'
  ),
  7,
  'The calendar owns exactly seven unique ISO weekday rows'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{"calendar_id":"58020000-0000-4000-8000-000000000001"}'::jsonb,
    99, '58090000-0000-4000-8000-000000000002'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_INPUT_INVALID',
  'Malformed calendar update fails closed before a stale write can occur'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 99, '58090000-0000-4000-8000-000000000003'::uuid
  )$sql$,
  '40001', 'V1_WORKFORCE_CALENDAR_VERSION_CONFLICT',
  'A well-formed calendar update rejects a stale optimistic version'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000002",
      "calendar_code":"UAE-SITE",
      "calendar_name":"Overlapping UAE Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2027-01-01",
      "valid_to":"2028-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000004'::uuid
  )$sql$,
  '23P01', null,
  'Effective versions of the same calendar code cannot overlap'
);

select lives_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "shift_code":"NIGHT",
      "shift_name":"Night Shift",
      "shift_kind":"night",
      "start_time":"22:00",
      "end_time":"06:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000010'::uuid
  )$sql$,
  'Exact Admin can create a reusable cross-midnight shift'
);

select ok(
  public.v1_get_workforce_configuration('2026-06-01')
    #>> '{shift_templates,0,crosses_midnight}' = 'true'
  and public.v1_get_workforce_configuration('2026-06-01')
    #>> '{shift_templates,0,work_date_basis}' = 'shift_start_date',
  'Night-shift work_date is explicitly based on its start date'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_code":"BAD-SHIFT",
      "shift_name":"Invalid Shift",
      "shift_kind":"normal_site",
      "start_time":"07:00",
      "scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000011'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_SHIFT_INPUT_INVALID',
  'Shift start and end supporting values must be supplied together'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_code":"BAD-SHIFT-MINUTES",
      "shift_name":"Invalid Shift Minutes",
      "shift_kind":"normal_site",
      "scheduled_minutes":1440,
      "break_minutes":1,
      "valid_from":"2026-01-01"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000013'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_SHIFT_INPUT_INVALID',
  'Shift work and break minutes cannot exceed one day'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_code":"NIGHT",
      "shift_name":"Overlapping Night Shift",
      "shift_kind":"night",
      "start_time":"21:00",
      "end_time":"05:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2027-01-01",
      "valid_to":"2028-12-31"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000012'::uuid
  )$sql$,
  '23P01', null,
  'Effective versions of the same shift code cannot overlap'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-12-02",
      "override_kind":"public_holiday",
      "day_type":"public_holiday",
      "exception_name":"UAE National Day"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000020'::uuid
  )$sql$,
  'Exact Admin can create a dated public-holiday exception'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000002",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2027-03-01",
      "override_kind":"ramadan",
      "day_type":"regular_working_day",
      "exception_name":"Ramadan schedule",
      "scheduled_minutes":360,
      "break_minutes":0,
      "shift_template_id":"58030000-0000-4000-8000-000000000001"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000021'::uuid
  )$sql$,
  'A dated Ramadan override can retain a working day with reduced minutes'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000003",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-12-02",
      "override_kind":"public_holiday",
      "day_type":"public_holiday",
      "exception_name":"Duplicate holiday"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000022'::uuid
  )$sql$,
  '23505', null,
  'A calendar cannot contain duplicate dated exceptions'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-12-03",
      "override_kind":"public_holiday",
      "day_type":"public_holiday",
      "exception_name":"Invalid worked holiday",
      "scheduled_minutes":60
    }'::jsonb, null, '58090000-0000-4000-8000-000000000023'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_DATE_INPUT_INVALID',
  'A non-working day type cannot carry scheduled minutes'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-12-04",
      "override_kind":"other",
      "day_type":"public_holiday",
      "exception_name":"Mislabeled public holiday"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000025'::uuid
  )$sql$,
  '22023', 'V1_WORKFORCE_CALENDAR_DATE_INPUT_INVALID',
  'Public-holiday and site-closure day types require matching override kinds'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2028-01-01",
      "override_kind":"other",
      "day_type":"not_scheduled",
      "exception_name":"Outside calendar"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000024'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_DATE_OUTSIDE_CALENDAR',
  'A dated exception cannot exist outside its calendar version'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000001",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "valid_from":"2026-03-01",
      "valid_to":"2027-09-30",
      "reason":"Default site calendar and night shift"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000030'::uuid
  )$sql$,
  'Exact Admin can link a team to exact effective calendar and shift versions'
);

select throws_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000003",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "valid_from":"2025-01-01",
      "valid_to":"2025-12-31",
      "reason":"Outside all parent windows"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000035'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_TEAM_SCHEDULE_OUTSIDE_PARENT_WINDOW',
  'A team default must fit inside its team and calendar versions'
);

select throws_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000002",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "valid_from":"2027-01-01",
      "valid_to":"2027-12-31",
      "reason":"Conflicting team default"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000031'::uuid
  )$sql$,
  '23P01', null,
  'A team cannot have overlapping effective schedule defaults'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-04-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000032'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_VERSION_RETAINED',
  'A retained calendar version cannot change its effective date window'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "is_active":false,
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000037'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_ACTIVE_USE',
  'A linked calendar cannot be deactivated while current or future use references it'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "shift_code":"NIGHT",
      "shift_name":"Night Shift",
      "shift_kind":"night",
      "start_time":"22:00",
      "end_time":"06:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-02-28"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000033'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_SHIFT_VERSION_RETAINED',
  'A retained shift version cannot change its effective date window'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "shift_code":"NIGHT",
      "shift_name":"Night Shift",
      "shift_kind":"night",
      "start_time":"22:00",
      "end_time":"06:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "is_active":false
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000036'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_SHIFT_ACTIVE_USE',
  'A linked shift cannot be deactivated while current or future use references it'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":450,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000050'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_VERSION_RETAINED',
  'A linked calendar cannot rewrite timezone or scheduled-minute semantics'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"weekly_off"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000051'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_VERSION_RETAINED',
  'A linked calendar cannot rewrite its retained weekday meanings'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "shift_code":"NIGHT",
      "shift_name":"Night Shift",
      "shift_kind":"night",
      "start_time":"21:00",
      "end_time":"05:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000052'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_SHIFT_VERSION_RETAINED',
  'A linked shift cannot rewrite retained cross-midnight time semantics'
);

select throws_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000001",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "valid_from":"2026-03-01",
      "valid_to":"2027-09-30",
      "reason":"Rewritten historical default"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000053'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_TEAM_SCHEDULE_VERSION_RETAINED',
  'An already-effective team schedule cannot rewrite retained meaning'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000004",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-06-01",
      "override_kind":"site_closure",
      "day_type":"site_closed",
      "exception_name":"Retained past site closure",
      "notes":"Historical T02 proof"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000054'::uuid
  )$sql$,
  'Admin can record a past dated override before it becomes immutable history'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000004",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-06-01",
      "override_kind":"site_closure",
      "day_type":"site_closed",
      "exception_name":"Rewritten past site closure",
      "notes":"Historical T02 proof"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000055'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED',
  'A past dated override cannot be rewritten into a different historical fact'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000004",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2026-06-01",
      "override_kind":"site_closure",
      "day_type":"site_closed",
      "exception_name":"Retained past site closure",
      "notes":"Historical T02 proof",
      "is_active":false
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000056'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED',
  'A past dated override cannot toggle active state under the retained ID'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_configuration('2026-06-01')
        #> '{calendars,0,date_overrides}'
    ) override_row
    where override_row ->> 'calendar_date_id'
      = '58040000-0000-4000-8000-000000000004'
      and override_row ->> 'exception_name' = 'Retained past site closure'
      and override_row ->> 'is_active' = 'true'
      and override_row ->> 'record_version' = '1'
  ),
  'A rejected past active-state change leaves retained history unchanged'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58040000-0000-4000-8000-000000000005',
      'calendar_id', '58020000-0000-4000-8000-000000000001',
      'calendar_date', current_date,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Current effective closure'
    ), null, '58090000-0000-4000-8000-000000000057'::uuid
  )$sql$,
  'Admin can create a current dated override that freezes on insert'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58040000-0000-4000-8000-000000000005',
      'calendar_id', '58020000-0000-4000-8000-000000000001',
      'calendar_date', current_date,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Current effective closure',
      'is_active', false
    ), 1, '58090000-0000-4000-8000-000000000058'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED',
  'A current effective dated override cannot toggle active state in place'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    '{
      "calendar_date_id":"58040000-0000-4000-8000-000000000002",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_date":"2027-03-01",
      "override_kind":"ramadan",
      "day_type":"regular_working_day",
      "exception_name":"Ramadan schedule reviewed",
      "scheduled_minutes":330,
      "break_minutes":0,
      "shift_template_id":"58030000-0000-4000-8000-000000000001"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000059'::uuid
  )$sql$,
  'A future dated override remains optimistic-version correctable before use'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000004",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "valid_from":"2027-10-01",
      "valid_to":"2027-12-31",
      "reason":"Future schedule draft"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000060'::uuid
  )$sql$,
  'Admin can create a non-overlapping future team schedule draft'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000004",
      "team_id":"58010000-0000-4000-8000-000000000001",
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "shift_template_id":"58030000-0000-4000-8000-000000000001",
      "valid_from":"2027-10-01",
      "valid_to":"2027-12-31",
      "reason":"Future schedule draft reviewed"
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000061'::uuid
  )$sql$,
  'A future unused team schedule remains optimistic-version correctable'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000003",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar 2028",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":450,
      "break_minutes":45,
      "valid_from":"2028-01-01",
      "valid_to":"2028-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000062'::uuid
  )$sql$,
  'A new non-overlapping calendar version can carry future semantic changes'
);

select lives_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000003",
      "shift_code":"NIGHT",
      "shift_name":"Night Shift 2028",
      "shift_kind":"night",
      "start_time":"21:00",
      "end_time":"05:00",
      "scheduled_minutes":420,
      "break_minutes":60,
      "valid_from":"2028-01-01",
      "valid_to":"2028-12-31"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000063'::uuid
  )$sql$,
  'A new non-overlapping shift version can carry future semantic changes'
);

select ok(
  public.v1_get_workforce_configuration('2026-09-01')
    #>> '{team_schedule_links,0,calendar_code}' = 'UAE-SITE'
  and public.v1_get_workforce_configuration('2026-09-01')
    #>> '{team_schedule_links,0,timezone_name}' = 'Asia/Dubai'
  and public.v1_get_workforce_configuration('2026-09-01')
    #>> '{team_schedule_links,0,shift_code}' = 'NIGHT',
  'Rejected drift attempts leave the exact linked projection unchanged'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000001",
      "calendar_code":"UAE-SITE",
      "calendar_name":"UAE Site Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2026-01-01",
      "valid_to":"2027-12-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 0, '58090000-0000-4000-8000-000000000064'::uuid
  )$sql$,
  '40001', 'V1_WORKFORCE_CALENDAR_VERSION_CONFLICT',
  'Retained calendar saves still fail closed on stale optimistic versions'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team(
    '{
      "team_id":"58010000-0000-4000-8000-000000000002",
      "team_code":"WF-T02-EXPIRED",
      "team_name":"Expired schedule history team",
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31",
      "is_active":true
    }'::jsonb, null, '58090000-0000-4000-8000-000000000065'::uuid
  )$sql$,
  'Admin can create the bounded team used for expired-history proof'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000004",
      "calendar_code":"WF-EXPIRED",
      "calendar_name":"Expired Workforce Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31",
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, null, '58090000-0000-4000-8000-000000000066'::uuid
  )$sql$,
  'Admin can create a finite calendar version for expired-history proof'
);

select lives_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000004",
      "shift_code":"WF-EXPIRED",
      "shift_name":"Expired Workforce Shift",
      "shift_kind":"normal_site",
      "start_time":"07:00",
      "end_time":"16:00",
      "scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000067'::uuid
  )$sql$,
  'Admin can create a finite shift version for expired-history proof'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    '{
      "team_schedule_link_id":"58050000-0000-4000-8000-000000000005",
      "team_id":"58010000-0000-4000-8000-000000000002",
      "calendar_id":"58020000-0000-4000-8000-000000000004",
      "shift_template_id":"58030000-0000-4000-8000-000000000004",
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31",
      "reason":"Retained expired team schedule"
    }'::jsonb, null, '58090000-0000-4000-8000-000000000068'::uuid
  )$sql$,
  'Admin can create retained schedule history with a finite past window'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    '{
      "calendar_id":"58020000-0000-4000-8000-000000000004",
      "calendar_code":"WF-EXPIRED",
      "calendar_name":"Expired Workforce Calendar",
      "timezone_name":"Asia/Dubai",
      "standard_scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31",
      "is_active":false,
      "weekdays":[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000069'::uuid
  )$sql$,
  'A calendar with only expired references can be retired without deletion'
);

select lives_ok(
  $sql$select public.v1_save_workforce_shift_template(
    '{
      "shift_template_id":"58030000-0000-4000-8000-000000000004",
      "shift_code":"WF-EXPIRED",
      "shift_name":"Expired Workforce Shift",
      "shift_kind":"normal_site",
      "start_time":"07:00",
      "end_time":"16:00",
      "scheduled_minutes":480,
      "break_minutes":60,
      "valid_from":"2025-01-01",
      "valid_to":"2026-07-31",
      "is_active":false
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000070'::uuid
  )$sql$,
  'A shift with only expired references can be retired without deletion'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_configuration('2026-07-01') -> 'calendars'
    ) calendar
    where calendar ->> 'calendar_id'
      = '58020000-0000-4000-8000-000000000004'
      and calendar ->> 'is_active' = 'false'
  )
  and exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_configuration('2026-07-01') -> 'shift_templates'
    ) shift
    where shift ->> 'shift_template_id'
      = '58030000-0000-4000-8000-000000000004'
      and shift ->> 'is_active' = 'false'
  )
  and exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_configuration('2026-07-01')
        -> 'team_schedule_links'
    ) link
    where link ->> 'team_schedule_link_id'
      = '58050000-0000-4000-8000-000000000005'
  ),
  'Retired parents and their exact expired schedule history remain readable'
);

select set_config('TimeZone', 'Etc/GMT+12', true);

select ok(
  current_date < (
    clock_timestamp() at time zone 'Pacific/Kiritimati'
  )::date,
  'Boundary fixture places the session date behind the calendar-local date'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team(
    jsonb_build_object(
      'team_id', '58110000-0000-4000-8000-000000000001',
      'team_code', 'WF-TZ-AHEAD',
      'team_name', 'Calendar ahead boundary team',
      'valid_from', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 30,
      'is_active', true
    ), null, '58190000-0000-4000-8000-000000000001'::uuid
  )$sql$,
  'Admin can create the calendar-ahead boundary team'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    jsonb_build_object(
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'calendar_code', 'TZ-AHEAD',
      'calendar_name', 'Kiritimati boundary calendar',
      'timezone_name', 'Pacific/Kiritimati',
      'standard_scheduled_minutes', 480,
      'break_minutes', 60,
      'valid_from', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 30,
      'weekdays', '[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]'::jsonb
    ), null, '58190000-0000-4000-8000-000000000002'::uuid
  )$sql$,
  'Admin can create the calendar-ahead boundary calendar'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58140000-0000-4000-8000-000000000001',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'calendar_date', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Calendar-local current closure'
    ), null, '58190000-0000-4000-8000-000000000003'::uuid
  )$sql$,
  'Admin can create an override effective today in its calendar timezone'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58140000-0000-4000-8000-000000000001',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'calendar_date', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Calendar-local current closure',
      'is_active', false
    ), 1, '58190000-0000-4000-8000-000000000004'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_DATE_VERSION_RETAINED',
  'Session date cannot make a calendar-local current override editable'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58140000-0000-4000-8000-000000000002',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'calendar_date', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 1,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Future calendar-local draft'
    ), null, '58190000-0000-4000-8000-000000000005'::uuid
  )$sql$,
  'Admin can create a future unused override in calendar-local time'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar_date(
    jsonb_build_object(
      'calendar_date_id', '58140000-0000-4000-8000-000000000002',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'calendar_date', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 1,
      'override_kind', 'other',
      'day_type', 'not_scheduled',
      'exception_name', 'Future calendar-local draft reviewed'
    ), 1, '58190000-0000-4000-8000-000000000006'::uuid
  )$sql$,
  'A future unused override remains correctable by its calendar-local date'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    jsonb_build_object(
      'team_schedule_link_id', '58150000-0000-4000-8000-000000000001',
      'team_id', '58110000-0000-4000-8000-000000000001',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'valid_from', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date,
      'valid_to', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 10,
      'reason', 'Calendar-local current team default'
    ), null, '58190000-0000-4000-8000-000000000007'::uuid
  )$sql$,
  'Admin can create a team default effective today in its calendar timezone'
);

select throws_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    jsonb_build_object(
      'team_schedule_link_id', '58150000-0000-4000-8000-000000000001',
      'team_id', '58110000-0000-4000-8000-000000000001',
      'calendar_id', '58120000-0000-4000-8000-000000000001',
      'valid_from', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date,
      'valid_to', (
        clock_timestamp() at time zone 'Pacific/Kiritimati'
      )::date + 10,
      'reason', 'Rewritten by the session date'
    ), 1, '58190000-0000-4000-8000-000000000008'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_TEAM_SCHEDULE_VERSION_RETAINED',
  'Session date cannot make a calendar-local effective team link editable'
);

select set_config('TimeZone', 'Pacific/Kiritimati', true);

select ok(
  current_date > (
    clock_timestamp() at time zone 'Etc/GMT+12'
  )::date,
  'Boundary fixture places the session date ahead of the calendar-local date'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team(
    jsonb_build_object(
      'team_id', '58110000-0000-4000-8000-000000000002',
      'team_code', 'WF-TZ-BEHIND',
      'team_name', 'Calendar behind boundary team',
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date + 30,
      'is_active', true
    ), null, '58190000-0000-4000-8000-000000000009'::uuid
  )$sql$,
  'Admin can create the calendar-behind boundary team'
);

select lives_ok(
  $sql$select public.v1_save_workforce_calendar(
    jsonb_build_object(
      'calendar_id', '58120000-0000-4000-8000-000000000002',
      'calendar_code', 'TZ-BEHIND',
      'calendar_name', 'GMT minus twelve boundary calendar',
      'timezone_name', 'Etc/GMT+12',
      'standard_scheduled_minutes', 480,
      'break_minutes', 60,
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date + 30,
      'weekdays', '[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]'::jsonb
    ), null, '58190000-0000-4000-8000-000000000010'::uuid
  )$sql$,
  'Admin can create the calendar-behind boundary calendar'
);

select lives_ok(
  $sql$select public.v1_save_workforce_shift_template(
    jsonb_build_object(
      'shift_template_id', '58130000-0000-4000-8000-000000000002',
      'shift_code', 'TZ-BEHIND',
      'shift_name', 'Calendar behind boundary shift',
      'shift_kind', 'normal_site',
      'start_time', '07:00',
      'end_time', '16:00',
      'scheduled_minutes', 480,
      'break_minutes', 60,
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date + 30
    ), null, '58190000-0000-4000-8000-000000000011'::uuid
  )$sql$,
  'Admin can create the calendar-behind boundary shift'
);

select lives_ok(
  $sql$select public.v1_save_workforce_team_schedule(
    jsonb_build_object(
      'team_schedule_link_id', '58150000-0000-4000-8000-000000000002',
      'team_id', '58110000-0000-4000-8000-000000000002',
      'calendar_id', '58120000-0000-4000-8000-000000000002',
      'shift_template_id', '58130000-0000-4000-8000-000000000002',
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 1,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date,
      'reason', 'Calendar-local current retirement blocker'
    ), null, '58190000-0000-4000-8000-000000000012'::uuid
  )$sql$,
  'Admin can create a link current only in its calendar timezone'
);

select throws_ok(
  $sql$select public.v1_save_workforce_calendar(
    jsonb_build_object(
      'calendar_id', '58120000-0000-4000-8000-000000000002',
      'calendar_code', 'TZ-BEHIND',
      'calendar_name', 'GMT minus twelve boundary calendar',
      'timezone_name', 'Etc/GMT+12',
      'standard_scheduled_minutes', 480,
      'break_minutes', 60,
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date + 30,
      'is_active', false,
      'weekdays', '[
        {"iso_weekday":1,"day_type":"regular_working_day"},
        {"iso_weekday":2,"day_type":"regular_working_day"},
        {"iso_weekday":3,"day_type":"regular_working_day"},
        {"iso_weekday":4,"day_type":"regular_working_day"},
        {"iso_weekday":5,"day_type":"regular_working_day"},
        {"iso_weekday":6,"day_type":"weekly_off"},
        {"iso_weekday":7,"day_type":"weekly_off"}
      ]'::jsonb
    ), 1, '58190000-0000-4000-8000-000000000013'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_CALENDAR_ACTIVE_USE',
  'Session date cannot retire a calendar with calendar-local current use'
);

select throws_ok(
  $sql$select public.v1_save_workforce_shift_template(
    jsonb_build_object(
      'shift_template_id', '58130000-0000-4000-8000-000000000002',
      'shift_code', 'TZ-BEHIND',
      'shift_name', 'Calendar behind boundary shift',
      'shift_kind', 'normal_site',
      'start_time', '07:00',
      'end_time', '16:00',
      'scheduled_minutes', 480,
      'break_minutes', 60,
      'valid_from', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date - 30,
      'valid_to', (
        clock_timestamp() at time zone 'Etc/GMT+12'
      )::date + 30,
      'is_active', false
    ), 1, '58190000-0000-4000-8000-000000000014'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_SHIFT_ACTIVE_USE',
  'Session date cannot retire a shift with calendar-local current use'
);

select set_config('TimeZone', 'UTC', true);

select throws_ok(
  $sql$select public.v1_save_workforce_team(
    '{
      "team_id":"58010000-0000-4000-8000-000000000001",
      "team_code":"WF-T02-TEAM",
      "team_name":"Workforce T02 schedule team",
      "valid_from":"2026-04-01",
      "valid_to":"2027-12-31",
      "is_active":true
    }'::jsonb, 1, '58090000-0000-4000-8000-000000000034'::uuid
  )$sql$,
  '23514', 'V1_WORKFORCE_TEAM_DATES_CONFLICT_WITH_SCHEDULES',
  'A team update cannot strand retained schedule history'
);

select is(
  public.v1_get_workforce_configuration('2027-03-01')
    #>> '{shift_templates,0,work_date_basis}',
  'shift_start_date',
  'The protected projection carries the cross-midnight work-date rule'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_workforce_configuration('2027-03-01')
        -> 'team_schedule_links'
    ) link
    where link ->> 'team_schedule_link_id'
      = '58050000-0000-4000-8000-000000000001'
      and link ->> 'is_effective' = 'true'
  ),
  'The protected projection returns the effective-dated team default'
);

reset role;
select is(
  (select count(*) from public.v1_audit_events audit
   where audit.entity_id = '58020000-0000-4000-8000-000000000001'
     and audit.event_type = 'workforce_calendar_created'),
  1::bigint,
  'An identical calendar retry produces one append-only audit event'
);

select throws_ok(
  $$delete from public.v1_workforce_calendars
    where id = '58020000-0000-4000-8000-000000000001'$$,
  '42501', 'V1_WORKFORCE_HISTORY_DELETE_FORBIDDEN',
  'Calendar history cannot be hard-deleted by a database owner path'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_configuration(current_date)$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'Project Engineer receives no configuration authority without an explicit capability'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_save_workforce_calendar(
    '{}'::jsonb, null, '58090000-0000-4000-8000-000000000040'::uuid
  )$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'Site Engineer receives no configuration mutation authority without an explicit capability'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_configuration(current_date)$$,
  '42501', 'V1_WORKFORCE_MANAGEMENT_REQUIRED',
  'Procurement receives no configuration authority without an explicit capability'
);

reset role;
select * from finish();
rollback;
