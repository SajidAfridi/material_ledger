begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

-- Repository-local scale evidence only. All generated rows roll back with this
-- test and therefore never seed, reinterpret or migrate product data.
insert into public.v1_projects(
  id, project_ref, name, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
)
select md5('t13-scale-project-' || sequence)::uuid,
  'WF-T13-P-' || lpad(sequence::text, 2, '0'),
  'T13 Scale Project ' || lpad(sequence::text, 2, '0'),
  'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004'::uuid, 'admin'
from generate_series(1, 30) sequence;

insert into public.v1_project_scopes(
  id, project_id, scope_kind, scope_code, name, is_immutable, is_active
)
select md5('t13-scale-scope-' || sequence)::uuid,
  md5('t13-scale-project-' || sequence)::uuid,
  'building', 't13-building-' || sequence,
  'T13 Building ' || lpad(sequence::text, 2, '0'), false, true
from generate_series(1, 30) sequence;

insert into public.v1_workforce_teams(
  id, team_code, team_name, default_supervisor_auth_user_id,
  default_project_id, default_project_scope_id, valid_from, valid_to,
  is_active, created_by_auth_user_id, updated_by_auth_user_id
)
select md5('t13-scale-team-' || sequence)::uuid,
  'WF-T13-T-' || lpad(sequence::text, 2, '0'),
  'T13 Scale Team ' || lpad(sequence::text, 2, '0'),
  '10000000-0000-4000-8000-000000000004'::uuid,
  md5('t13-scale-project-' || (((sequence - 1) % 30) + 1))::uuid,
  md5('t13-scale-scope-' || (((sequence - 1) % 30) + 1))::uuid,
  '2024-09-01', '2026-08-31', true,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 50) sequence;

insert into public.v1_workforce_calendars(
  id, calendar_code, calendar_name, timezone_name,
  standard_scheduled_minutes, break_minutes, valid_from, valid_to, is_active,
  created_by_auth_user_id, updated_by_auth_user_id
) values (
  md5('t13-scale-calendar')::uuid, 'WF-T13-SCALE',
  'T13 Scale Calendar', 'Asia/Dubai', 480, 60,
  '2024-09-01', '2026-08-31', true,
  '10000000-0000-4000-8000-000000000004',
  '10000000-0000-4000-8000-000000000004'
);

insert into public.v1_workforce_calendar_weekdays(
  calendar_id, iso_weekday, day_type,
  created_by_auth_user_id, updated_by_auth_user_id
)
select md5('t13-scale-calendar')::uuid, weekday,
  'regular_working_day',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 7) weekday;

insert into public.v1_workforce_team_schedule_links(
  id, team_id, calendar_id, valid_from, valid_to, reason,
  created_by_auth_user_id, updated_by_auth_user_id
)
select md5('t13-scale-schedule-' || sequence)::uuid,
  md5('t13-scale-team-' || sequence)::uuid,
  md5('t13-scale-calendar')::uuid,
  '2024-09-01', '2026-08-31', 'T13 scale schedule',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 50) sequence;

insert into public.v1_workforce_workers(
  id, worker_number, full_name, designation, employer_company, worker_type,
  joining_date, current_status,
  created_by_auth_user_id, updated_by_auth_user_id
)
select md5('t13-scale-worker-' || sequence)::uuid,
  'WF-T13-W-' || lpad(sequence::text, 3, '0'),
  'T13 Scale Worker ' || lpad(sequence::text, 3, '0'),
  'Technician', 'Yorks AC & Ref.', 'yorks_employee',
  '2024-09-01', 'active',
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 500) sequence;

insert into public.v1_workforce_worker_assignments(
  id, worker_id, assignment_kind, team_id, supervisor_auth_user_id,
  project_id, project_scope_id, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role, updated_by_auth_user_id
)
select md5('t13-scale-assignment-' || sequence)::uuid,
  md5('t13-scale-worker-' || sequence)::uuid, 'primary',
  md5('t13-scale-team-' || (((sequence - 1) % 50) + 1))::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid,
  md5(
    't13-scale-project-' ||
    (((((sequence - 1) % 50) + 1 - 1) % 30) + 1)
  )::uuid,
  md5(
    't13-scale-scope-' ||
    (((((sequence - 1) % 50) + 1 - 1) % 30) + 1)
  )::uuid,
  '2024-09-01', '2026-08-31', 'T13 scale assignment',
  '10000000-0000-4000-8000-000000000004'::uuid, 'admin',
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 500) sequence;

set constraints all deferred;
insert into public.v1_workforce_monthly_periods(
  id, team_id, period_month, current_validation_run_id,
  current_validation_number, current_status, record_version,
  created_by_auth_user_id, updated_by_auth_user_id
)
select md5('t13-scale-period-' || sequence)::uuid,
  md5('t13-scale-team-1')::uuid,
  ('2024-09-01'::date + (sequence - 1) * interval '1 month')::date,
  md5('t13-scale-run-' || sequence)::uuid, 1,
  'ready_for_review', 1,
  '10000000-0000-4000-8000-000000000004'::uuid,
  '10000000-0000-4000-8000-000000000004'::uuid
from generate_series(1, 24) sequence;

insert into public.v1_workforce_monthly_validation_runs(
  id, period_id, validation_number, validation_status, source_fingerprint,
  worker_count, date_count, authority_snapshot,
  validated_by_auth_user_id, validated_by_exact_role, idempotency_key
)
select md5('t13-scale-run-' || sequence)::uuid,
  md5('t13-scale-period-' || sequence)::uuid,
  1, 'ready_for_review', repeat('a', 64), 10,
  extract(day from (
    date_trunc(
      'month', '2024-09-01'::date + (sequence - 1) * interval '1 month'
    ) + interval '1 month - 1 day'
  ))::integer,
  jsonb_build_object(
    'fixture', 't13-two-year-history',
    'month_number', sequence
  ),
  '10000000-0000-4000-8000-000000000004'::uuid,
  'admin', md5('t13-scale-run-key-' || sequence)::uuid
from generate_series(1, 24) sequence;
set constraints all immediate;

insert into public.v1_workforce_responsibility_assignments(
  id, auth_user_id, scope_kind, valid_from, valid_to, reason,
  assigned_by_auth_user_id, assigned_by_exact_role,
  updated_by_auth_user_id
)
select md5('t13-scale-management-responsibility')::uuid,
  '10000000-0000-4000-8000-000000000010'::uuid,
  'organization', '2024-09-01', '2026-08-31',
  'T13 repository-local organization scale authority',
  '10000000-0000-4000-8000-000000000004'::uuid, 'admin',
  '10000000-0000-4000-8000-000000000004'::uuid
where not exists (
  select 1
  from public.v1_workforce_responsibility_assignments responsibility
  where responsibility.auth_user_id =
    '10000000-0000-4000-8000-000000000010'::uuid
    and responsibility.scope_kind = 'organization'
    and '2026-08-31' between responsibility.valid_from
      and coalesce(responsibility.valid_to, 'infinity'::date)
);

insert into public.v1_permission_assignments(
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, effective_until, reason, changed_by_auth_user_id
)
select md5('t13-scale-management-view')::uuid,
  '10000000-0000-4000-8000-000000000010'::uuid,
  'workforce.view', 'grant', 'organization', 'permission_management',
  '2024-09-01', '2035-12-31',
  'T13 repository-local Management scale view',
  '10000000-0000-4000-8000-000000000004'::uuid
where not exists (
  select 1
  from public.v1_permission_assignments assignment
  where assignment.auth_user_id =
    '10000000-0000-4000-8000-000000000010'::uuid
    and assignment.capability_key = 'workforce.view'
    and assignment.effect = 'grant'
    and assignment.scope_kind = 'organization'
    and '2026-08-31 12:00:00+00'::timestamptz between assignment.effective_from
      and coalesce(assignment.effective_until, 'infinity'::date)
);

select is(
  concat_ws('|',
    (select count(*) from public.v1_projects
      where project_ref like 'WF-T13-P-%'),
    (select count(*) from public.v1_workforce_teams
      where team_code like 'WF-T13-T-%'),
    (select count(*) from public.v1_workforce_workers
      where worker_number like 'WF-T13-W-%'),
    (select count(*) from public.v1_workforce_monthly_periods
      where id in (
        select md5('t13-scale-period-' || sequence)::uuid
        from generate_series(1, 24) sequence
      ))
  ),
  '30|50|500|24',
  'T13 creates the approved 30-project, 50-team, 500-worker and two-year history envelope'
);

select is(
  (
    select concat_ws('|', min(period_month), max(period_month), count(*))
    from public.v1_workforce_monthly_periods
    where id in (
      select md5('t13-scale-period-' || sequence)::uuid
      from generate_series(1, 24) sequence
    )
  ),
  '2024-09-01|2026-08-01|24',
  'The retained history path spans 24 exact monthly periods'
);

create temporary table t13_read_effect_baseline on commit drop as
select (select count(*) from public.v1_audit_events) as audit_count,
  (select count(*) from public.v1_notifications) as notification_count,
  (select count(*) from public.v1_workforce_monthly_transitions)
    as transition_count,
  (select count(*) from public.v1_workforce_report_artifacts) as report_count;

create temporary table t13_scale_results(
  overview jsonb,
  roster jsonb,
  queue jsonb,
  overview_started_at timestamptz,
  overview_finished_at timestamptz,
  roster_started_at timestamptz,
  roster_finished_at timestamptz,
  queue_started_at timestamptz,
  queue_finished_at timestamptz
) on commit drop;
grant select, insert, update on t13_scale_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
insert into t13_scale_results(overview_started_at) values(clock_timestamp());
update t13_scale_results
set overview = public.v1_get_workforce_overview(
  '{"overview_kind":"management"}'
);
update t13_scale_results set overview_finished_at = clock_timestamp();
update t13_scale_results set roster_started_at = clock_timestamp();
update t13_scale_results
set roster = public.v1_get_workforce_daily_roster(
  '2026-08-31', md5('t13-scale-team-1')::uuid,
  null, null, null, null, 500, 0
);
update t13_scale_results set roster_finished_at = clock_timestamp();
update t13_scale_results set queue_started_at = clock_timestamp();
update t13_scale_results
set queue = public.v1_list_workforce_monthly_approval_queue(null, 100, 0);
update t13_scale_results set queue_finished_at = clock_timestamp();

select is(
  concat_ws('|',
    (select overview #>> '{summary,worker_count}'
      from t13_scale_results),
    (select overview #>> '{summary,active_project_count}'
      from t13_scale_results),
    (select jsonb_array_length(overview -> 'projects')
      from t13_scale_results)
  ),
  '500|30|30',
  'The protected Management overview aggregates every scale worker and project without truncating totals'
);

select is(
  concat_ws('|',
    (select roster ->> 'total_count' from t13_scale_results),
    (select jsonb_array_length(roster -> 'rows') from t13_scale_results),
    (select roster #>> '{filters,limit}' from t13_scale_results)
  ),
  '10|10|500',
  'The protected roster returns an exact bounded 500-row page over a 500-worker organization'
);

select cmp_ok(
  (select (queue ->> 'total_count')::integer from t13_scale_results),
  '>=', 24,
  'The protected review queue reads the complete retained two-year period path'
);

select diag(
  'T13 local wall times ms: overview=' ||
  round(extract(epoch from (overview_finished_at - overview_started_at)) * 1000, 2) ||
  ', roster=' ||
  round(extract(epoch from (roster_finished_at - roster_started_at)) * 1000, 2) ||
  ', queue=' ||
  round(extract(epoch from (queue_finished_at - queue_started_at)) * 1000, 2)
)
from t13_scale_results;

reset role;

select is(
  (select row(audit_count, notification_count, transition_count, report_count)::text
    from t13_read_effect_baseline),
  (select row(
    (select count(*) from public.v1_audit_events),
    (select count(*) from public.v1_notifications),
    (select count(*) from public.v1_workforce_monthly_transitions),
    (select count(*) from public.v1_workforce_report_artifacts)
  )::text),
  'Scale reads append no audit, notification, transition or report side effect'
);

select * from finish();
rollback;
