-- Yorks Workforce T09: protected report artifacts and export projections.
--
-- Additive and data-preserving. Final monthly output is sourced only from an
-- exact immutable T07 approved snapshot. Current daily/exception reports are
-- explicitly labelled non-approved and retain their source fingerprint/time.

begin;

create table public.v1_workforce_report_artifacts (
  id uuid primary key default gen_random_uuid(),
  report_kind text not null check (report_kind in (
    'daily_attendance_register','worker_monthly_timesheet',
    'supervisor_team_monthly','project_workforce',
    'company_workforce_summary','exception_missing_attendance',
    'exception_high_overtime','exception_returned_timesheets',
    'exception_unsubmitted_periods','exception_workers_without_assignment',
    'exception_overlapping_allocations','exception_reopened_periods'
  )),
  source_kind text not null check (source_kind in (
    'approved_snapshot','current_daily','current_exception'
  )),
  source_status text not null,
  source_version text not null,
  source_hash text not null check (source_hash ~ '^[0-9a-f]{64}$'),
  period_month date,
  work_date date,
  scope_kind text not null check (scope_kind in (
    'worker','team','project','organization'
  )),
  scope_reference text not null,
  request_payload jsonb not null check (jsonb_typeof(request_payload)='object'),
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  authority_payload jsonb not null check (jsonb_typeof(authority_payload)='object'),
  report_payload jsonb not null check (jsonb_typeof(report_payload)='object'),
  report_payload_hash text not null check (report_payload_hash ~ '^[0-9a-f]{64}$'),
  generated_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  generated_by_exact_role text not null,
  generated_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique(generated_by_auth_user_id,idempotency_key)
);

create table public.v1_workforce_report_artifact_snapshots (
  report_artifact_id uuid not null
    references public.v1_workforce_report_artifacts(id) on delete restrict,
  approved_snapshot_id uuid not null
    references public.v1_workforce_monthly_approved_snapshots(id)
    on delete restrict,
  approval_revision_number bigint not null check (approval_revision_number>0),
  snapshot_hash text not null check (snapshot_hash ~ '^[0-9a-f]{64}$'),
  primary key(report_artifact_id,approved_snapshot_id)
);

create index v1_workforce_report_artifacts_actor_page_idx
  on public.v1_workforce_report_artifacts(
    generated_by_auth_user_id,generated_at desc,id desc
  );
create index v1_workforce_report_artifacts_period_idx
  on public.v1_workforce_report_artifacts(period_month,report_kind,generated_at desc);
create index v1_workforce_report_snapshot_reverse_idx
  on public.v1_workforce_report_artifact_snapshots(approved_snapshot_id,report_artifact_id);

alter table public.v1_workforce_report_artifacts enable row level security;
alter table public.v1_workforce_report_artifact_snapshots enable row level security;
revoke all on table public.v1_workforce_report_artifacts,
  public.v1_workforce_report_artifact_snapshots
from public,anon,authenticated;
grant all on table public.v1_workforce_report_artifacts,
  public.v1_workforce_report_artifact_snapshots to service_role;

create trigger v1_workforce_report_artifacts_immutable
before update or delete on public.v1_workforce_report_artifacts
for each row execute function public.v1_workforce_monthly_block_immutable_update();
create trigger v1_workforce_report_snapshots_immutable
before update or delete on public.v1_workforce_report_artifact_snapshots
for each row execute function public.v1_workforce_monthly_block_immutable_update();

create or replace function public.v1_workforce_t09_has_organization_scope(
  p_actor uuid,p_on_date date
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id=p_actor
      and responsibility.scope_kind='organization'
      and responsibility.valid_from<=p_on_date
      and (responsibility.valid_to is null or responsibility.valid_to>=p_on_date));
$$;

create or replace function public.v1_workforce_t09_snapshot_authorized(
  p_snapshot_id uuid
) returns boolean language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid();
  v_snapshot public.v1_workforce_monthly_approved_snapshots%rowtype;
  v_day jsonb;
  v_target jsonb;
  v_project uuid;
  v_period_month date;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_snapshot
  from public.v1_workforce_monthly_approved_snapshots snapshot
  where snapshot.id=p_snapshot_id;
  if not found then return false; end if;
  begin
    v_period_month:=(v_snapshot.snapshot_payload#>>'{period,period_month}')::date;
  exception when others then return false; end;
  if jsonb_typeof(v_snapshot.snapshot_payload->'dates')<>'array' then
    return false;
  end if;
  if jsonb_array_length(v_snapshot.snapshot_payload->'dates')=0 then
    return public.v1_current_user_has_capability('workforce.view',null)
      and public.v1_current_user_has_capability('workforce.reports.export',null)
      and public.v1_workforce_t09_has_organization_scope(v_actor,v_period_month);
  end if;
  for v_day in select value
    from jsonb_array_elements(v_snapshot.snapshot_payload->'dates') loop
    begin
      v_project:=nullif(v_day#>>'{assignment_snapshot,project_id}','')::uuid;
      if not public.v1_current_user_has_capability('workforce.view',v_project)
        or not public.v1_current_user_has_capability('workforce.reports.export',v_project)
        or public.v1_workforce_matching_responsibility(
          v_actor,(v_day->>'worker_id')::uuid,(v_day->>'work_date')::date,
          nullif(v_day#>>'{assignment_snapshot,team_id}','')::uuid,v_project,
          nullif(v_day#>>'{assignment_snapshot,project_scope_id}','')::uuid,
          nullif(v_day#>>'{assignment_snapshot,internal_location_id}','')::uuid
        )='{}'::jsonb
      then return false; end if;
    exception when invalid_text_representation or datetime_field_overflow then
      return false;
    end;
    if v_day#>>'{allocation_snapshot,allocation_state}'='active' then
      for v_target in select value from jsonb_array_elements(
        coalesce(v_day#>'{allocation_snapshot,targets}','[]'::jsonb)) loop
        begin
          v_project:=case when v_target->>'target_kind'='project_work'
            then nullif(v_target->>'project_id','')::uuid else null end;
          if not public.v1_current_user_has_capability('workforce.view',v_project)
            or not public.v1_current_user_has_capability('workforce.reports.export',v_project)
            or not exists(select 1
              from public.v1_workforce_responsibility_assignments responsibility
              where responsibility.auth_user_id=v_actor
                and responsibility.valid_from<=(v_day->>'work_date')::date
                and (responsibility.valid_to is null or
                  responsibility.valid_to>=(v_day->>'work_date')::date)
                and (responsibility.scope_kind='organization' or
                  (v_target->>'target_kind'='project_work' and (
                    (responsibility.scope_kind='project' and
                      responsibility.project_id=v_project) or
                    (responsibility.scope_kind='project_scope' and
                      responsibility.project_id=v_project and
                      responsibility.project_scope_id=
                        nullif(v_target->>'project_scope_id','')::uuid))) or
                  (v_target->>'target_kind'='internal_work' and
                    responsibility.scope_kind='internal_location' and
                    responsibility.internal_location_id=
                      nullif(v_target->>'internal_location_id','')::uuid)))
          then return false; end if;
        exception when invalid_text_representation or datetime_field_overflow then
          return false;
        end;
      end loop;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t09_daily_authorized(
  p_daily jsonb
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_row jsonb; v_target jsonb; v_project uuid;
  v_work_date date;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or jsonb_typeof(p_daily->'rows')<>'array' then return false; end if;
  begin v_work_date:=(p_daily->>'work_date')::date;
  exception when others then return false; end;
  if jsonb_array_length(p_daily->'rows')=0 then
    return public.v1_current_user_has_capability('workforce.view',null)
      and public.v1_current_user_has_capability('workforce.reports.export',null)
      and public.v1_workforce_t09_has_organization_scope(v_actor,v_work_date);
  end if;
  for v_row in select value from jsonb_array_elements(p_daily->'rows') loop
    begin
      v_project:=nullif(v_row#>>'{assignment,project_id}','')::uuid;
      if not public.v1_current_user_has_capability('workforce.view',v_project)
        or not public.v1_current_user_has_capability('workforce.reports.export',v_project)
        or public.v1_workforce_matching_responsibility(
          v_actor,(v_row->>'worker_id')::uuid,v_work_date,
          nullif(v_row#>>'{assignment,team_id}','')::uuid,v_project,
          nullif(v_row#>>'{assignment,project_scope_id}','')::uuid,
          nullif(v_row#>>'{assignment,internal_location_id}','')::uuid
        )='{}'::jsonb
      then return false; end if;
      if coalesce((v_row->>'allocation_details_restricted')::boolean,false) then
        return false;
      end if;
      if v_row->'allocation_set' is not null then
        if jsonb_typeof(v_row#>'{allocation_set,allocations}')<>'array' then
          return false;
        end if;
        for v_target in select value from jsonb_array_elements(
          v_row#>'{allocation_set,allocations}') loop
          v_project:=case when v_target->>'target_kind'='project_work'
            then nullif(v_target#>>'{project,project_id}','')::uuid else null end;
          if not public.v1_current_user_has_capability('workforce.view',v_project)
            or not public.v1_current_user_has_capability('workforce.reports.export',v_project)
            or not exists(select 1
              from public.v1_workforce_responsibility_assignments responsibility
              where responsibility.auth_user_id=v_actor
                and responsibility.valid_from<=v_work_date
                and (responsibility.valid_to is null or
                  responsibility.valid_to>=v_work_date)
                and (responsibility.scope_kind='organization' or
                  (v_target->>'target_kind'='project_work' and (
                    (responsibility.scope_kind='project' and
                      responsibility.project_id=v_project) or
                    (responsibility.scope_kind='project_scope' and
                      responsibility.project_id=v_project and
                      responsibility.project_scope_id=
                        nullif(v_target#>>'{project,project_scope_id}','')::uuid))) or
                  (v_target->>'target_kind'='internal_work' and
                    responsibility.scope_kind='internal_location' and
                    responsibility.internal_location_id=
                      nullif(v_target#>>'{internal_location,internal_location_id}','')::uuid)))
          then return false; end if;
        end loop;
      end if;
    exception when invalid_text_representation or datetime_field_overflow then
      return false;
    end;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t09_columns(p_report_kind text)
returns jsonb language sql immutable set search_path='' as $$
  select case
    when p_report_kind='daily_attendance_register' then
      '[{"key":"worker_number","label":"Worker Number","type":"text"},{"key":"worker_name","label":"Worker","type":"text"},{"key":"trade","label":"Trade","type":"text"},{"key":"attendance_status","label":"Status","type":"text"},{"key":"regular_hours","label":"Regular Hours","type":"decimal"},{"key":"overtime_hours","label":"OT Hours","type":"decimal"},{"key":"project","label":"Project","type":"text"},{"key":"building","label":"Building / Common","type":"text"},{"key":"internal_location","label":"Internal Location","type":"text"},{"key":"supervisor","label":"Supervisor","type":"text"},{"key":"notes","label":"Notes","type":"text"}]'::jsonb
    when p_report_kind='worker_monthly_timesheet' then
      '[{"key":"worker_number","label":"Worker Number","type":"text"},{"key":"worker_name","label":"Worker","type":"text"},{"key":"work_date","label":"Date","type":"date"},{"key":"attendance_status","label":"Status","type":"text"},{"key":"regular_hours","label":"Regular Hours","type":"decimal"},{"key":"overtime_hours","label":"OT Hours","type":"decimal"},{"key":"projects","label":"Projects","type":"text"},{"key":"buildings","label":"Buildings / Common","type":"text"},{"key":"internal_locations","label":"Internal Locations","type":"text"},{"key":"activities","label":"Activities","type":"text"},{"key":"supervisor","label":"Supervisor","type":"text"},{"key":"reviewer","label":"Reviewer","type":"text"},{"key":"approver","label":"Approver","type":"text"},{"key":"approval_dates","label":"Review / Approval Dates","type":"text"}]'::jsonb
    when p_report_kind='supervisor_team_monthly' then
      '[{"key":"team","label":"Team","type":"text"},{"key":"period_month","label":"Period","type":"date"},{"key":"workers_managed","label":"Workers Managed","type":"integer"},{"key":"attendance_summary","label":"Attendance Summary","type":"text"},{"key":"regular_hours","label":"Regular Hours","type":"decimal"},{"key":"overtime_hours","label":"OT Hours","type":"decimal"},{"key":"absences","label":"Absences","type":"integer"},{"key":"projects","label":"Projects","type":"text"},{"key":"exceptions","label":"Exceptions","type":"text"},{"key":"review_approval_status","label":"Review / Approval Status","type":"text"}]'::jsonb
    when p_report_kind='project_workforce' then
      '[{"key":"project","label":"Project","type":"text"},{"key":"buildings","label":"Buildings / Common","type":"text"},{"key":"worker_count","label":"Worker Count","type":"integer"},{"key":"trade_distribution","label":"Trade Distribution","type":"text"},{"key":"man_hours","label":"Man-hours","type":"decimal"},{"key":"man_days","label":"Man-days","type":"decimal"},{"key":"regular_hours","label":"Regular Hours","type":"decimal"},{"key":"overtime_hours","label":"OT Hours","type":"decimal"},{"key":"absences","label":"Absences","type":"integer"},{"key":"supervisors","label":"Supervisors","type":"text"},{"key":"outstanding_periods","label":"Outstanding Periods","type":"integer"}]'::jsonb
    when p_report_kind='company_workforce_summary' then
      '[{"key":"period_month","label":"Period","type":"date"},{"key":"total_active_workforce","label":"Total Active Workforce","type":"integer"},{"key":"attendance_completion","label":"Attendance Completion %","type":"decimal"},{"key":"approved_regular_hours","label":"Approved Regular Hours","type":"decimal"},{"key":"approved_overtime_hours","label":"Approved OT Hours","type":"decimal"},{"key":"absence_position","label":"Absence Position","type":"integer"},{"key":"project_allocation","label":"Project Allocation","type":"text"},{"key":"pending_submissions","label":"Pending Submissions","type":"integer"},{"key":"pending_approvals","label":"Pending Approvals","type":"integer"},{"key":"reopened_periods","label":"Reopened Periods","type":"integer"}]'::jsonb
    else
      '[{"key":"period","label":"Period / Date","type":"text"},{"key":"team","label":"Team","type":"text"},{"key":"worker_number","label":"Worker ID","type":"text"},{"key":"worker_name","label":"Worker Name","type":"text"},{"key":"exception","label":"Exception","type":"text"},{"key":"status","label":"Status","type":"text"}]'::jsonb
  end;
$$;

create or replace function public.v1_workforce_t09_rows(
  p_report_kind text,
  p_snapshot_ids uuid[],
  p_worker_id uuid,
  p_team_id uuid,
  p_project_id uuid,
  p_period_month date,
  p_daily jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_rows jsonb:='[]'::jsonb;
begin
  if p_report_kind='daily_attendance_register' then
    v_rows:=(select coalesce(jsonb_agg(jsonb_build_object(
      'worker_number',row->>'worker_number','worker_name',row->>'worker_name',
      'trade',coalesce(nullif(concat_ws(' / ',row->>'trade_name',row->>'designation'),''),'—'),
      'attendance_status',coalesce(row#>>'{attendance,attendance_status}','not_entered'),
      'regular_hours',round(coalesce((row#>>'{attendance,regular_minutes}')::numeric,0)/60,4),
      'overtime_hours',round(coalesce((row#>>'{attendance,overtime_minutes}')::numeric,0)/60,4),
      'project',coalesce(nullif((select string_agg(distinct nullif(concat_ws(' · ',
        allocation#>>'{project,project_ref}',allocation#>>'{project,project_name}'),''),'; ')
        from jsonb_array_elements(coalesce(row#>'{allocation_set,allocations}','[]'::jsonb)) allocation
        where allocation->>'target_kind'='project_work'),''),
        nullif(concat_ws(' · ',row#>>'{assignment,project_ref}',row#>>'{assignment,project_name}'),''),'—'),
      'building',coalesce(nullif((select string_agg(distinct allocation#>>'{project,project_scope_name}','; ')
        from jsonb_array_elements(coalesce(row#>'{allocation_set,allocations}','[]'::jsonb)) allocation
        where allocation->>'target_kind'='project_work'),''),row#>>'{assignment,project_scope_name}','—'),
      'internal_location',coalesce(nullif((select string_agg(distinct allocation#>>'{internal_location,location_name}','; ')
        from jsonb_array_elements(coalesce(row#>'{allocation_set,allocations}','[]'::jsonb)) allocation
        where allocation->>'target_kind'='internal_work'),''),row#>>'{assignment,internal_location_name}','—'),
      'supervisor',coalesce(row#>>'{assignment,supervisor_name}','—'),
      'notes',coalesce(nullif(concat_ws('; ',row#>>'{attendance,reason}',
        (select string_agg(nullif(allocation->>'notes',''),'; ' order by allocation->>'line_number')
         from jsonb_array_elements(coalesce(row#>'{allocation_set,allocations}','[]'::jsonb)) allocation)),''),'—'))
      order by lower(row->>'worker_name')),'[]'::jsonb)
    from jsonb_array_elements(p_daily->'rows') row);
  elsif p_report_kind='worker_monthly_timesheet' then
    v_rows:=(select coalesce(jsonb_agg(jsonb_build_object(
      'worker_number',day#>>'{worker_snapshot,worker_number}',
      'worker_name',day#>>'{worker_snapshot,worker_name}','work_date',day->>'work_date',
      'attendance_status',coalesce(day#>>'{attendance_snapshot,attendance_status}','not_entered'),
      'regular_hours',round(coalesce((day->>'regular_minutes')::numeric,0)/60,4),
      'overtime_hours',round(coalesce((day->>'overtime_minutes')::numeric,0)/60,4),
      'projects',coalesce((select string_agg(distinct nullif(concat_ws(' · ',target->>'project_ref',target->>'project_name'),''),'; ')
        from jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where target->>'target_kind'='project_work'),'—'),
      'buildings',coalesce((select string_agg(distinct target->>'project_scope_name','; ')
        from jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where target->>'target_kind'='project_work'),'—'),
      'internal_locations',coalesce((select string_agg(distinct target->>'internal_location_name','; ')
        from jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where target->>'target_kind'='internal_work'),'—'),
      'activities',coalesce((select string_agg(nullif(target->>'activity_task',''),'; ' order by target->>'line_number')
        from jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target),'—'),
      'supervisor',coalesce(day#>>'{assignment_snapshot,supervisor_name}','—'),
      'reviewer',coalesce((select string_agg(distinct coalesce(profile.display_name,transition->>'actor_exact_role'),'; ')
        from jsonb_array_elements(coalesce(snapshot.snapshot_payload->'review_chain','[]'::jsonb)) transition
        left join public.v1_profiles profile on profile.auth_user_id=nullif(transition->>'actor_auth_user_id','')::uuid
        where transition->>'action_kind' in ('return_for_correction','reviewer_correction','verify_forward')),'—'),
      'approver',coalesce(approver.display_name,snapshot.approved_by_exact_role),
      'approval_dates',concat_ws('; ',
        (select string_agg(distinct (transition->>'action_kind')||' '||(transition->>'occurred_at'),'; ')
         from jsonb_array_elements(coalesce(snapshot.snapshot_payload->'review_chain','[]'::jsonb)) transition
         where transition->>'action_kind' in ('return_for_correction','reviewer_correction','verify_forward')),
        'approved '||snapshot.approved_at::text))
      order by day->>'work_date'),'[]'::jsonb)
    from public.v1_workforce_monthly_approved_snapshots snapshot
    join public.v1_profiles approver on approver.auth_user_id=snapshot.approved_by_auth_user_id
    cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
    where snapshot.id=any(p_snapshot_ids) and day->>'worker_id'=p_worker_id::text);
  elsif p_report_kind='supervisor_team_monthly' then
    v_rows:=(select coalesce(jsonb_agg(jsonb_build_object(
      'team',coalesce(team.team_name,'—'),'period_month',p_period_month,
      'workers_managed',jsonb_array_length(snapshot.snapshot_payload->'workers'),
      'attendance_summary',format('Present %s · Absent %s · Leave %s · Missing %s',
        coalesce(snapshot.snapshot_payload#>>'{summary,present_day_count}','0'),
        coalesce(snapshot.snapshot_payload#>>'{summary,absent_day_count}','0'),
        coalesce(snapshot.snapshot_payload#>>'{summary,leave_day_count}','0'),
        coalesce(snapshot.snapshot_payload#>>'{summary,missing_day_count}','0')),
      'regular_hours',round(coalesce((snapshot.snapshot_payload#>>'{summary,regular_minutes}')::numeric,0)/60,4),
      'overtime_hours',round(coalesce((snapshot.snapshot_payload#>>'{summary,overtime_minutes}')::numeric,0)/60,4),
      'absences',coalesce((snapshot.snapshot_payload#>>'{summary,absent_day_count}')::integer,0),
      'projects',coalesce((select string_agg(distinct nullif(concat_ws(' · ',target->>'project_ref',target->>'project_name'),''),'; ')
        from jsonb_array_elements(snapshot.snapshot_payload->'dates') day
        cross join lateral jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where target->>'target_kind'='project_work'),'—'),
      'exceptions',format('Blocking %s · Warnings %s',
        coalesce(snapshot.snapshot_payload#>>'{summary,blocking_issue_count}','0'),
        coalesce(snapshot.snapshot_payload#>>'{summary,warning_issue_count}','0')),
      'review_approval_status',format('Approved & locked · R%s · %s (%s) · %s',
        snapshot.approval_revision_number,coalesce(approver.display_name,'—'),
        snapshot.approved_by_exact_role,snapshot.approved_at))
      order by team.team_name),'[]'::jsonb)
    from public.v1_workforce_monthly_approved_snapshots snapshot
    left join public.v1_workforce_teams team
      on team.id=nullif(snapshot.snapshot_payload#>>'{period,team_id}','')::uuid
    left join public.v1_profiles approver on approver.auth_user_id=snapshot.approved_by_auth_user_id
    where snapshot.id=any(p_snapshot_ids)
      and nullif(snapshot.snapshot_payload#>>'{period,team_id}','')::uuid=p_team_id);
  elsif p_report_kind='project_workforce' then
    v_rows:=(select jsonb_build_array(jsonb_build_object(
      'project',coalesce(max(nullif(concat_ws(' · ',target->>'project_ref',target->>'project_name'),'')),'—'),
      'buildings',coalesce(string_agg(distinct target->>'project_scope_name','; '),'—'),
      'worker_count',count(distinct day->>'worker_id')::integer,
      'trade_distribution',coalesce((select string_agg(trade_name||' '||worker_count,'; ' order by trade_name)
        from (select coalesce(trade_day#>>'{worker_snapshot,trade_name}','Unspecified') trade_name,
          count(distinct trade_day->>'worker_id')::text worker_count
          from public.v1_workforce_monthly_approved_snapshots trade_snapshot
          cross join lateral jsonb_array_elements(trade_snapshot.snapshot_payload->'dates') trade_day
          where trade_snapshot.id=any(p_snapshot_ids) and exists(select 1
            from jsonb_array_elements(coalesce(trade_day#>'{allocation_snapshot,targets}','[]'::jsonb)) trade_target
            where trade_target->>'project_id'=p_project_id::text)
          group by coalesce(trade_day#>>'{worker_snapshot,trade_name}','Unspecified')) distribution),'—'),
      'man_hours',round(sum(coalesce((target->>'regular_minutes')::numeric,0)+coalesce((target->>'overtime_minutes')::numeric,0))/60,4),
      'man_days',round(sum(case when coalesce((day->>'scheduled_minutes')::numeric,0)>0 then
        (coalesce((target->>'regular_minutes')::numeric,0)+coalesce((target->>'overtime_minutes')::numeric,0))
          /(day->>'scheduled_minutes')::numeric else 0 end),4),
      'regular_hours',round(sum(coalesce((target->>'regular_minutes')::numeric,0))/60,4),
      'overtime_hours',round(sum(coalesce((target->>'overtime_minutes')::numeric,0))/60,4),
      'absences',(select count(*)::integer
        from public.v1_workforce_monthly_approved_snapshots absence_snapshot
        cross join lateral jsonb_array_elements(absence_snapshot.snapshot_payload->'dates') absence_day
        where absence_snapshot.id=any(p_snapshot_ids)
          and absence_day#>>'{assignment_snapshot,project_id}'=p_project_id::text
          and absence_day#>>'{attendance_snapshot,attendance_status}'='absent'),
      'supervisors',coalesce((select string_agg(distinct supervisor_day#>>'{assignment_snapshot,supervisor_name}','; ')
        from public.v1_workforce_monthly_approved_snapshots supervisor_snapshot
        cross join lateral jsonb_array_elements(supervisor_snapshot.snapshot_payload->'dates') supervisor_day
        where supervisor_snapshot.id=any(p_snapshot_ids)
          and supervisor_day#>>'{assignment_snapshot,project_id}'=p_project_id::text),'—'),
      'outstanding_periods',(select count(*)::integer from public.v1_workforce_monthly_periods period
        where period.period_month=p_period_month and period.current_status<>'locked'
          and exists(select 1 from public.v1_workforce_monthly_approved_snapshots source_snapshot
            cross join lateral jsonb_array_elements(source_snapshot.snapshot_payload->'dates') source_day
            where source_snapshot.id=any(p_snapshot_ids)
              and nullif(source_snapshot.snapshot_payload#>>'{period,team_id}','')::uuid=period.team_id
              and source_day#>>'{assignment_snapshot,project_id}'=p_project_id::text))))
    from public.v1_workforce_monthly_approved_snapshots snapshot
    cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
    cross join lateral jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
    where snapshot.id=any(p_snapshot_ids) and target->>'project_id'=p_project_id::text);
  elsif p_report_kind='company_workforce_summary' then
    v_rows:=(with source_days as materialized (
      select snapshot.id snapshot_id,day
      from public.v1_workforce_monthly_approved_snapshots snapshot
      cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
      where snapshot.id=any(p_snapshot_ids)
    )
    select jsonb_build_array(jsonb_build_object(
      'period_month',p_period_month,
      'total_active_workforce',count(distinct day->>'worker_id')::integer,
      'attendance_completion',case when count(*) filter (where not coalesce((day->>'is_future')::boolean,false))=0 then 0
        else round(100*count(*) filter (where not coalesce((day->>'is_future')::boolean,false)
          and day->'attendance_snapshot' is distinct from 'null'::jsonb)::numeric/
          count(*) filter (where not coalesce((day->>'is_future')::boolean,false)),4) end,
      'approved_regular_hours',round(sum(coalesce((day->>'regular_minutes')::numeric,0))/60,4),
      'approved_overtime_hours',round(sum(coalesce((day->>'overtime_minutes')::numeric,0))/60,4),
      'absence_position',count(*) filter (where day#>>'{attendance_snapshot,attendance_status}'='absent')::integer,
      'project_allocation',coalesce((select string_agg(distinct nullif(concat_ws(' · ',target->>'project_ref',target->>'project_name'),''),'; ')
        from source_days allocation_day
        cross join lateral jsonb_array_elements(coalesce(allocation_day.day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where target->>'target_kind'='project_work'),'—'),
      'pending_submissions',(select count(*)::integer from public.v1_workforce_monthly_periods period
        where period.period_month=p_period_month and period.current_status in ('draft','ready_for_review')),
      'pending_approvals',(select count(*)::integer from public.v1_workforce_monthly_periods period
        where period.period_month=p_period_month and period.current_status in ('submitted','under_review','awaiting_final_approval')),
      'reopened_periods',(select count(distinct transition.period_id)::integer
        from public.v1_workforce_monthly_transitions transition
        join public.v1_workforce_monthly_periods period on period.id=transition.period_id
        where period.period_month=p_period_month and transition.action_kind='reopen_authorized')))
    from source_days);
  elsif p_report_kind='exception_high_overtime' then
    v_rows:=(select coalesce(jsonb_agg(jsonb_build_object('period',period.period_month::text,
      'team',team.team_name,'worker_number',worker.worker_number_snapshot,
      'worker_name',worker.worker_name_snapshot,'exception',issue.issue_code,
      'status',issue.severity) order by team.team_name,worker.worker_name_snapshot,issue.work_date),'[]'::jsonb)
    from public.v1_workforce_monthly_periods period
    join public.v1_workforce_teams team on team.id=period.team_id
    join public.v1_workforce_monthly_validation_issues issue
      on issue.validation_run_id=period.current_validation_run_id
    left join public.v1_workforce_monthly_period_workers worker
      on worker.validation_run_id=period.current_validation_run_id and worker.worker_id=issue.worker_id
    where period.period_month=p_period_month and issue.issue_code='overtime_limit_exceeded');
    if jsonb_array_length(v_rows)=0 then
      v_rows:=jsonb_build_array(jsonb_build_object('period',p_period_month::text,
        'team','—','worker_number','—','worker_name','—',
        'exception','No authoritative overtime threshold configured','status','not_configured'));
    end if;
  end if;
  return v_rows;
end;
$$;

create or replace function public.v1_generate_workforce_report(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_kind text; v_existing jsonb;
  v_artifact_id uuid:=gen_random_uuid(); v_generated_at timestamptz:=clock_timestamp();
  v_request_hash text; v_source_hash text; v_source_kind text; v_source_status text;
  v_source_version text; v_scope_kind text; v_scope_ref text; v_period_month date;
  v_requested_period_month date;
  v_work_date date; v_team_id uuid; v_project_id uuid; v_worker_id uuid;
  v_snapshot_ids uuid[]:='{}'::uuid[]; v_snapshot_id uuid; v_rows jsonb:='[]'::jsonb;
  v_sources jsonb:='[]'::jsonb; v_totals jsonb:='{}'::jsonb; v_report jsonb;
  v_authority_payload jsonb:='{}'::jsonb;
  v_profile_name text; v_company_legal_name text; v_company_secondary_name text;
  v_daily jsonb;
begin
  if v_actor is null or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['report_kind','snapshot_ids',
    'period_month','work_date','team_id','project_id','worker_id'],'generate_workforce_report');
  v_kind:=btrim(coalesce(p_payload->>'report_kind',''));
  if v_kind not in ('daily_attendance_register','worker_monthly_timesheet',
    'supervisor_team_monthly','project_workforce','company_workforce_summary',
    'exception_missing_attendance','exception_high_overtime',
    'exception_returned_timesheets','exception_unsubmitted_periods',
    'exception_workers_without_assignment','exception_overlapping_allocations',
    'exception_reopened_periods') then
    raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  v_role:=public.v1_permission_exact_role(v_actor);
  if v_role='' or not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_REPORT_DENIED' using errcode='42501'; end if;
  begin
    v_period_month:=nullif(p_payload->>'period_month','')::date;
    v_work_date:=nullif(p_payload->>'work_date','')::date;
    v_team_id:=nullif(p_payload->>'team_id','')::uuid;
    v_project_id:=nullif(p_payload->>'project_id','')::uuid;
    v_worker_id:=nullif(p_payload->>'worker_id','')::uuid;
    v_requested_period_month:=v_period_month;
    if p_payload?'snapshot_ids' then
      if jsonb_typeof(p_payload->'snapshot_ids')<>'array'
        or jsonb_array_length(p_payload->'snapshot_ids')>100 then
        raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
      select coalesce(array_agg(value::uuid order by value::uuid),'{}'::uuid[])
        into v_snapshot_ids from jsonb_array_elements_text(p_payload->'snapshot_ids') value;
    end if;
  exception when invalid_text_representation or datetime_field_overflow then
    raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end;
  if v_period_month is not null and v_period_month<>date_trunc('month',v_period_month)::date then
    raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;

  if v_kind in ('worker_monthly_timesheet','supervisor_team_monthly',
      'project_workforce','company_workforce_summary') then
    if cardinality(v_snapshot_ids)=0 or v_work_date is not null
      or (v_kind='worker_monthly_timesheet' and
        (v_worker_id is null or v_team_id is not null or v_project_id is not null))
      or (v_kind='supervisor_team_monthly' and
        (v_team_id is null or v_worker_id is not null or v_project_id is not null))
      or (v_kind='project_workforce' and
        (v_project_id is null or v_team_id is not null or v_worker_id is not null))
      or (v_kind='company_workforce_summary' and
        (v_team_id is not null or v_project_id is not null or v_worker_id is not null)) then
      raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
    foreach v_snapshot_id in array v_snapshot_ids loop
      if not coalesce(public.v1_workforce_t09_snapshot_authorized(v_snapshot_id),false) then
        raise exception 'V1_WORKFORCE_REPORT_DENIED' using errcode='42501'; end if;
    end loop;
    select min((snapshot.snapshot_payload#>>'{period,period_month}')::date),
      max((snapshot.snapshot_payload#>>'{period,period_month}')::date)
      into v_period_month,v_work_date
    from public.v1_workforce_monthly_approved_snapshots snapshot
    where snapshot.id=any(v_snapshot_ids);
    if v_period_month is null or v_period_month<>v_work_date then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514'; end if;
    if v_requested_period_month is not null
      and v_requested_period_month<>v_period_month then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514'; end if;
    v_work_date:=null;
    select coalesce(jsonb_agg(jsonb_build_object('snapshot_id',snapshot.id,
        'period_id',snapshot.period_id,'approval_revision_number',snapshot.approval_revision_number,
        'snapshot_hash',snapshot.snapshot_hash,'approved_at',snapshot.approved_at,
        'approved_by',profile.display_name,'approved_role',snapshot.approved_by_exact_role,
        'review_chain',coalesce((select jsonb_agg(jsonb_build_object(
          'action',transition->>'action_kind','actor',coalesce(chain_profile.display_name,'System'),
          'role',transition->>'actor_exact_role','at',transition->>'occurred_at')
          order by transition->>'occurred_at')
          from jsonb_array_elements(coalesce(
            snapshot.snapshot_payload->'review_chain','[]'::jsonb)) transition
          left join public.v1_profiles chain_profile on chain_profile.auth_user_id=
            nullif(transition->>'actor_auth_user_id','')::uuid),'[]'::jsonb))
      order by snapshot.id),'[]'::jsonb),
      public.v1_hash_json(jsonb_agg(jsonb_build_object('id',snapshot.id,'hash',snapshot.snapshot_hash)
        order by snapshot.id))
      into v_sources,v_source_hash
    from public.v1_workforce_monthly_approved_snapshots snapshot
    join public.v1_profiles profile on profile.auth_user_id=snapshot.approved_by_auth_user_id
    where snapshot.id=any(v_snapshot_ids);
    if jsonb_array_length(v_sources)<>cardinality(v_snapshot_ids) then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514'; end if;
    if v_kind='supervisor_team_monthly' and exists(select 1
        from public.v1_workforce_monthly_approved_snapshots snapshot
        where snapshot.id=any(v_snapshot_ids)
          and nullif(snapshot.snapshot_payload#>>'{period,team_id}','')::uuid
            is distinct from v_team_id) then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514';
    elsif v_kind='worker_monthly_timesheet' and not exists(select 1
        from public.v1_workforce_monthly_approved_snapshots snapshot
        cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
        where snapshot.id=any(v_snapshot_ids) and day->>'worker_id'=v_worker_id::text) then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514';
    elsif v_kind='project_workforce' and not exists(select 1
        from public.v1_workforce_monthly_approved_snapshots snapshot
        cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
        cross join lateral jsonb_array_elements(
          coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
        where snapshot.id=any(v_snapshot_ids) and target->>'project_id'=v_project_id::text) then
      raise exception 'V1_WORKFORCE_REPORT_SOURCE_INVALID' using errcode='23514';
    end if;
    v_source_kind:='approved_snapshot'; v_source_status:='approved_locked';
    v_source_version:=array_to_string(v_snapshot_ids,',');
    if v_kind='worker_monthly_timesheet' then
      v_scope_kind:='worker'; v_scope_ref:=v_worker_id::text;
    elsif v_kind='supervisor_team_monthly' then
      v_scope_kind:='team'; v_scope_ref:=coalesce(v_team_id::text,'approved_snapshot');
    elsif v_kind='project_workforce' then
      v_scope_kind:='project'; v_scope_ref:=v_project_id::text;
    else v_scope_kind:='organization'; v_scope_ref:='organization'; end if;

    if v_kind='company_workforce_summary' then
      select coalesce(jsonb_agg(row_json order by row_json->>'team'),'[]'::jsonb)
      into v_rows from (
        select jsonb_build_object(
          'team',coalesce(team.team_name,'—'),'period_month',v_period_month,
          'workers',jsonb_array_length(snapshot.snapshot_payload->'workers'),
          'regular_minutes',coalesce((snapshot.snapshot_payload#>>'{summary,regular_minutes}')::bigint,0),
          'overtime_minutes',coalesce((snapshot.snapshot_payload#>>'{summary,overtime_minutes}')::bigint,0),
          'man_days',coalesce((select round(sum(
            ((day->>'regular_minutes')::numeric+(day->>'overtime_minutes')::numeric)
              /nullif((day->>'scheduled_minutes')::numeric,0)),4)
            from jsonb_array_elements(snapshot.snapshot_payload->'dates') day
            where (day->>'scheduled_minutes')::integer>0),0),
          'approval_revision',snapshot.approval_revision_number) row_json
        from public.v1_workforce_monthly_approved_snapshots snapshot
        join public.v1_workforce_monthly_periods period on period.id=snapshot.period_id
        left join public.v1_workforce_teams team on team.id=period.team_id
        where snapshot.id=any(v_snapshot_ids)
      ) summary_rows;
    elsif v_kind='project_workforce' then
      select coalesce(jsonb_agg(jsonb_build_object(
        'project',coalesce(target->>'project_ref','')||case when target->>'project_name' is null then '' else ' · '||(target->>'project_name') end,
        'scope',target->>'project_scope_name','worker_number',day#>>'{worker_snapshot,worker_number}',
        'worker_name',day#>>'{worker_snapshot,worker_name}','work_date',day->>'work_date',
        'activity',target->>'activity_task','regular_minutes',(target->>'regular_minutes')::integer,
        'overtime_minutes',(target->>'overtime_minutes')::integer,
        'man_days',case when (day->>'scheduled_minutes')::integer>0 then round(
          ((target->>'regular_minutes')::numeric+(target->>'overtime_minutes')::numeric)
            /(day->>'scheduled_minutes')::numeric,4) else 0 end)
        order by day->>'work_date',day#>>'{worker_snapshot,worker_number}',target->>'line_number'),'[]'::jsonb)
      into v_rows
      from public.v1_workforce_monthly_approved_snapshots snapshot
      cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
      cross join lateral jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target
      where snapshot.id=any(v_snapshot_ids) and target->>'project_id'=v_project_id::text;
    else
      select coalesce(jsonb_agg(jsonb_build_object(
        'worker_number',day#>>'{worker_snapshot,worker_number}',
        'worker_name',day#>>'{worker_snapshot,worker_name}','work_date',day->>'work_date',
        'day_type',day->>'day_type','attendance_status',day#>>'{attendance_snapshot,attendance_status}',
        'scheduled_minutes',(day->>'scheduled_minutes')::integer,
        'regular_minutes',(day->>'regular_minutes')::integer,
        'overtime_minutes',(day->>'overtime_minutes')::integer,
        'activity',coalesce((select string_agg(concat_ws(' · ',target->>'project_ref',
          target->>'project_scope_name',target->>'internal_location_name',target->>'activity_task'),'; ' order by target->>'line_number')
          from jsonb_array_elements(coalesce(day#>'{allocation_snapshot,targets}','[]'::jsonb)) target),'—'))
        order by day#>>'{worker_snapshot,worker_number}',day->>'work_date'),'[]'::jsonb)
      into v_rows from public.v1_workforce_monthly_approved_snapshots snapshot
      cross join lateral jsonb_array_elements(snapshot.snapshot_payload->'dates') day
      where snapshot.id=any(v_snapshot_ids)
        and (v_kind<>'worker_monthly_timesheet' or day->>'worker_id'=v_worker_id::text)
        and (v_team_id is null or day#>>'{assignment_snapshot,team_id}'=v_team_id::text);
    end if;
  elsif v_kind='daily_attendance_register' then
    if v_work_date is null or v_team_id is null or cardinality(v_snapshot_ids)<>0
      or v_period_month is not null or v_project_id is not null or v_worker_id is not null then
      raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
    v_daily:=public.v1_get_workforce_daily_roster(v_work_date,v_team_id,null,null,null,null,500,0);
    if coalesce((v_daily->>'is_future')::boolean,false) then
      raise exception 'V1_WORKFORCE_FUTURE_WORK_DATE_DENIED' using errcode='22023'; end if;
    if (v_daily->>'total_count')::integer>500 then
      raise exception 'V1_WORKFORCE_REPORT_PAGE_LIMIT' using errcode='54000'; end if;
    if not public.v1_workforce_t09_daily_authorized(v_daily) then
      raise exception 'V1_WORKFORCE_REPORT_DENIED' using errcode='42501'; end if;
    v_authority_payload:=v_daily;
    select coalesce(jsonb_agg(jsonb_build_object('worker_number',row->>'worker_number',
      'worker_name',row->>'worker_name','trade',concat_ws(' / ',row->>'trade_name',row->>'designation'),
      'team',row#>>'{assignment,team_name}','project',coalesce(nullif(concat_ws(' · ',
        row#>>'{assignment,project_ref}',row#>>'{assignment,project_name}',row#>>'{assignment,project_scope_name}'),''),
        row#>>'{assignment,internal_location_name}'),'work_date',v_work_date,
      'attendance_status',coalesce(row#>>'{attendance,attendance_status}','not_entered'),
      'regular_minutes',coalesce((row#>>'{attendance,regular_minutes}')::integer,0),
      'overtime_minutes',coalesce((row#>>'{attendance,overtime_minutes}')::integer,0),
      'overtime_reason',row#>>'{attendance,overtime_reason}') order by lower(row->>'worker_name')),'[]'::jsonb)
      into v_rows from jsonb_array_elements(v_daily->'rows') row;
    v_source_kind:='current_daily'; v_source_status:='current_not_approved';
    v_source_version:=coalesce(v_daily->>'server_time',v_generated_at::text);
    v_source_hash:=public.v1_hash_json(v_daily); v_scope_kind:='team'; v_scope_ref:=v_team_id::text;
    v_sources:=jsonb_build_array(jsonb_build_object('work_date',v_work_date,'team_id',v_team_id,
      'server_time',v_daily->>'server_time','status','current_not_approved'));
  else
    if v_period_month is null or cardinality(v_snapshot_ids)<>0
      or v_work_date is not null or v_team_id is not null
      or v_project_id is not null or v_worker_id is not null then
      raise exception 'V1_WORKFORCE_REPORT_INVALID' using errcode='22023'; end if;
    if not public.v1_current_user_has_capability('workforce.view',null)
      or not public.v1_current_user_has_capability('workforce.reports.export',null)
      or not public.v1_workforce_t09_has_organization_scope(v_actor,v_period_month) then
      raise exception 'V1_WORKFORCE_REPORT_DENIED' using errcode='42501'; end if;
    v_source_kind:='current_exception'; v_source_status:='current_not_approved';
    v_source_version:=v_generated_at::text; v_scope_kind:='organization';
    v_scope_ref:='organization';
    if v_kind in ('exception_missing_attendance','exception_overlapping_allocations') then
      select coalesce(jsonb_agg(jsonb_build_object('period',period.period_month::text,
        'team',team.team_name,'worker_number',worker.worker_number_snapshot,
        'worker_name',worker.worker_name_snapshot,'exception',issue.issue_code,
        'status',issue.severity) order by team.team_name,worker.worker_name_snapshot,issue.work_date),'[]'::jsonb)
      into v_rows from public.v1_workforce_monthly_periods period
      join public.v1_workforce_teams team on team.id=period.team_id
      join public.v1_workforce_monthly_validation_issues issue on issue.validation_run_id=period.current_validation_run_id
      left join public.v1_workforce_monthly_period_workers worker
        on worker.validation_run_id=period.current_validation_run_id and worker.worker_id=issue.worker_id
      where period.period_month=v_period_month and issue.issue_code=case
        when v_kind='exception_missing_attendance' then 'required_attendance_missing'
        else 'allocation_interval_overlap' end;
    elsif v_kind='exception_high_overtime' then
      v_rows:='[]'::jsonb;
    elsif v_kind in ('exception_returned_timesheets','exception_reopened_periods') then
      select coalesce(jsonb_agg(jsonb_build_object('period',period.period_month::text,
        'team',team.team_name,'worker_number','','worker_name','',
        'exception',transition.action_kind,'status',transition.to_status)
        order by transition.occurred_at),'[]'::jsonb) into v_rows
      from public.v1_workforce_monthly_transitions transition
      join public.v1_workforce_monthly_periods period on period.id=transition.period_id
      join public.v1_workforce_teams team on team.id=period.team_id
      where period.period_month=v_period_month and transition.action_kind=case
        when v_kind='exception_returned_timesheets' then 'return_for_correction'
        else 'reopen_authorized' end;
    elsif v_kind='exception_unsubmitted_periods' then
      select coalesce(jsonb_agg(jsonb_build_object('period',period.period_month::text,
        'team',team.team_name,'worker_number','','worker_name','',
        'exception','period_not_submitted','status',period.current_status)
        order by team.team_name),'[]'::jsonb) into v_rows
      from public.v1_workforce_monthly_periods period
      join public.v1_workforce_teams team on team.id=period.team_id
      where period.period_month=v_period_month and period.current_status in ('draft','ready_for_review');
    else
      select coalesce(jsonb_agg(jsonb_build_object('period',v_period_month::text,
        'team','','worker_number',worker.worker_number,'worker_name',worker.full_name,
        'exception','worker_without_assignment','status',worker.current_status)
        order by worker.full_name),'[]'::jsonb) into v_rows
      from public.v1_workforce_workers worker where worker.current_status='active'
        and not exists(select 1 from generate_series(v_period_month,
          (v_period_month+interval '1 month - 1 day')::date,'1 day') date_value
          where public.v1_workforce_effective_assignment(worker.id,date_value::date)<>'{}'::jsonb);
    end if;
    v_sources:=jsonb_build_array(jsonb_build_object('period_month',v_period_month,
      'generated_at',v_generated_at,'status','current_not_approved'));
    v_authority_payload:=jsonb_build_object('period_month',v_period_month);
    v_source_hash:=public.v1_hash_json(jsonb_build_object('kind',v_kind,'rows',v_rows,
      'generated_at',v_generated_at));
  end if;

  if v_kind in ('daily_attendance_register','worker_monthly_timesheet',
      'supervisor_team_monthly','project_workforce','company_workforce_summary',
      'exception_high_overtime') then
    v_rows:=public.v1_workforce_t09_rows(v_kind,v_snapshot_ids,v_worker_id,
      v_team_id,v_project_id,v_period_month,v_daily);
  end if;
  v_request_hash:=public.v1_hash_json(p_payload);
  v_existing:=public.v1_idempotency_get_or_claim('v1_generate_workforce_report',
    p_idempotency_key,jsonb_build_object('payload',p_payload));
  if v_existing is not null then return v_existing; end if;
  select profile.display_name into v_profile_name from public.v1_profiles profile
    where profile.auth_user_id=v_actor;
  select coalesce(max(setting.published_value#>>'{}') filter (
      where setting.setting_key='company.legal_name'),
      'Yorks Air Conditioning & Refrigeration LLC-SPC'),
    coalesce(max(setting.published_value#>>'{}') filter (
      where setting.setting_key='company.arabic_name'),
      'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و')
    into v_company_legal_name,v_company_secondary_name
  from public.v1_configuration_settings setting
  where setting.setting_key in ('company.legal_name','company.arabic_name');
  v_totals:=jsonb_build_object('row_count',jsonb_array_length(v_rows),
    'regular_minutes',coalesce((select sum(coalesce((row->>'regular_minutes')::numeric,
        (row->>'regular_hours')::numeric*60,
        (row->>'approved_regular_hours')::numeric*60,0))
      from jsonb_array_elements(v_rows) row),0),
    'overtime_minutes',coalesce((select sum(coalesce((row->>'overtime_minutes')::numeric,
        (row->>'overtime_hours')::numeric*60,
        (row->>'approved_overtime_hours')::numeric*60,0))
      from jsonb_array_elements(v_rows) row),0),
    'man_days',coalesce((select sum(coalesce((row->>'man_days')::numeric,0))
      from jsonb_array_elements(v_rows) row),0));
  v_report:=jsonb_build_object('schema_version',1,'authorization_mode','enforced_t09',
    'artifact_id',v_artifact_id,'report_kind',v_kind,'source_kind',v_source_kind,
    'source_status',v_source_status,'source_version',v_source_version,'source_hash',v_source_hash,
    'period_month',v_period_month,'work_date',v_work_date,'scope_kind',v_scope_kind,
    'scope_reference',v_scope_ref,'generated_at',v_generated_at,
    'generated_by',v_profile_name,'generated_by_role',v_role,
    'company_legal_name',v_company_legal_name,
    'company_secondary_name',v_company_secondary_name,'sources',v_sources,
    'columns',public.v1_workforce_t09_columns(v_kind),'rows',v_rows,'totals',v_totals);
  insert into public.v1_workforce_report_artifacts(id,report_kind,source_kind,
    source_status,source_version,source_hash,period_month,work_date,scope_kind,
    scope_reference,request_payload,request_hash,authority_payload,report_payload,
    report_payload_hash,generated_by_auth_user_id,generated_by_exact_role,
    generated_at,idempotency_key)
  values(v_artifact_id,v_kind,v_source_kind,v_source_status,v_source_version,v_source_hash,
    v_period_month,v_work_date,v_scope_kind,v_scope_ref,p_payload,v_request_hash,
    v_authority_payload,v_report,public.v1_hash_json(v_report),v_actor,v_role,
    v_generated_at,p_idempotency_key);
  insert into public.v1_workforce_report_artifact_snapshots(report_artifact_id,
    approved_snapshot_id,approval_revision_number,snapshot_hash)
  select v_artifact_id,snapshot.id,snapshot.approval_revision_number,snapshot.snapshot_hash
  from public.v1_workforce_monthly_approved_snapshots snapshot
  where snapshot.id=any(v_snapshot_ids);
  perform public.v1_write_audit_event('report_generated',
    'workforce_report_artifact',v_artifact_id,null,null,v_report,
    'Protected Workforce report generated',p_idempotency_key);
  perform public.v1_complete_idempotency('v1_generate_workforce_report',p_idempotency_key,v_report);
  return v_report;
end;
$$;

create or replace function public.v1_workforce_t09_artifact_authorized(
  p_artifact_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1
    from public.v1_workforce_report_artifacts artifact
    where artifact.id=p_artifact_id
      and artifact.generated_by_auth_user_id=auth.uid()
      and public.v1_current_actor_is_active()
      and (
        (artifact.source_kind='approved_snapshot'
          and exists(select 1
            from public.v1_workforce_report_artifact_snapshots link
            where link.report_artifact_id=artifact.id)
          and not exists(select 1
            from public.v1_workforce_report_artifact_snapshots link
            where link.report_artifact_id=artifact.id and not coalesce(
              public.v1_workforce_t09_snapshot_authorized(
                link.approved_snapshot_id),false)))
        or (artifact.source_kind='current_daily'
          and public.v1_workforce_t09_daily_authorized(
            artifact.authority_payload))
        or (artifact.source_kind='current_exception'
          and public.v1_current_user_has_capability('workforce.view',null)
          and public.v1_current_user_has_capability(
            'workforce.reports.export',null)
          and public.v1_workforce_t09_has_organization_scope(
            auth.uid(),artifact.period_month))));
$$;

create or replace function public.v1_issue_workforce_report_export(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_artifact_id uuid;
  v_format text; v_action text; v_existing jsonb; v_issued_at timestamptz;
  v_artifact public.v1_workforce_report_artifacts%rowtype; v_response jsonb;
  v_project_id uuid;
begin
  if v_actor is null or p_idempotency_key is null
    or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_REPORT_ISSUE_INVALID' using errcode='22023';
  end if;
  perform public.v1_assert_object_keys(p_payload,
    array['artifact_id','format','action'],'issue_workforce_report_export');
  begin
    v_artifact_id:=nullif(p_payload->>'artifact_id','')::uuid;
  exception when invalid_text_representation then
    raise exception 'V1_WORKFORCE_REPORT_ISSUE_INVALID' using errcode='22023';
  end;
  v_format:=btrim(coalesce(p_payload->>'format',''));
  v_action:=btrim(coalesce(p_payload->>'action',''));
  if v_artifact_id is null or v_format not in ('xlsx','pdf')
    or v_action not in ('preview','download','share','print')
    or (v_format='xlsx' and v_action<>'download') then
    raise exception 'V1_WORKFORCE_REPORT_ISSUE_INVALID' using errcode='22023';
  end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  v_role:=public.v1_permission_exact_role(v_actor);
  if v_role='' or not public.v1_current_actor_is_active() then
    raise exception 'V1_WORKFORCE_REPORT_ISSUE_DENIED' using errcode='42501';
  end if;
  select * into v_artifact
  from public.v1_workforce_report_artifacts artifact
  where artifact.id=v_artifact_id for share;
  if not found or not coalesce(
      public.v1_workforce_t09_artifact_authorized(v_artifact_id),false) then
    raise exception 'V1_WORKFORCE_REPORT_ISSUE_DENIED' using errcode='42501';
  end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_issue_workforce_report_export',p_idempotency_key,
    jsonb_build_object('payload',p_payload));
  if v_existing is not null then return v_existing; end if;
  v_issued_at:=clock_timestamp();
  if v_artifact.scope_kind='project' then
    begin v_project_id:=v_artifact.scope_reference::uuid;
    exception when invalid_text_representation then v_project_id:=null; end;
  end if;
  v_response:=jsonb_build_object(
    'schema_version',1,'authorization_mode','enforced_t09',
    'artifact_id',v_artifact.id,'format',v_format,'action',v_action,
    'source_hash',v_artifact.source_hash,
    'report_payload_hash',v_artifact.report_payload_hash,
    'issued_at',v_issued_at,'issued_by',v_actor,
    'issued_by_role',v_role,'capability_key','workforce.reports.export',
    'scope_kind',v_artifact.scope_kind,
    'scope_reference',v_artifact.scope_reference,
    'source_authority_hash',public.v1_hash_json(v_artifact.authority_payload));
  perform public.v1_write_audit_event('workforce_export_generated',
    'workforce_report_artifact',v_artifact.id,v_project_id,null,v_response,
    'Protected Workforce export issued',p_idempotency_key);
  perform public.v1_complete_idempotency('v1_issue_workforce_report_export',
    p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_list_workforce_report_artifacts(
  p_limit integer default 25,p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_items jsonb; v_count bigint;
begin
  if v_actor is null or p_limit is null or p_limit<1 or p_limit>100
    or p_offset is null or p_offset<0 or not public.v1_current_actor_is_active()
  then raise exception 'V1_WORKFORCE_REPORT_HISTORY_DENIED' using errcode='42501'; end if;
  select count(*) into v_count
  from public.v1_workforce_report_artifacts artifact
  where artifact.generated_by_auth_user_id=v_actor and (
    (artifact.source_kind='approved_snapshot'
      and exists(select 1 from public.v1_workforce_report_artifact_snapshots link
        where link.report_artifact_id=artifact.id)
      and not exists(select 1 from public.v1_workforce_report_artifact_snapshots link
        where link.report_artifact_id=artifact.id and not coalesce(
          public.v1_workforce_t09_snapshot_authorized(link.approved_snapshot_id),false)))
    or (artifact.source_kind='current_daily'
      and public.v1_workforce_t09_daily_authorized(artifact.authority_payload))
    or (artifact.source_kind='current_exception'
      and public.v1_current_user_has_capability('workforce.view',null)
      and public.v1_current_user_has_capability('workforce.reports.export',null)
      and public.v1_workforce_t09_has_organization_scope(
        v_actor,artifact.period_month)));
  select coalesce(jsonb_agg(artifact.report_payload
      order by artifact.generated_at desc,artifact.id desc),'[]'::jsonb)
    into v_items from (
      select row_value.* from public.v1_workforce_report_artifacts row_value
      where row_value.generated_by_auth_user_id=v_actor and (
        (row_value.source_kind='approved_snapshot'
          and exists(select 1 from public.v1_workforce_report_artifact_snapshots link
            where link.report_artifact_id=row_value.id)
          and not exists(select 1 from public.v1_workforce_report_artifact_snapshots link
            where link.report_artifact_id=row_value.id and not coalesce(
              public.v1_workforce_t09_snapshot_authorized(link.approved_snapshot_id),false)))
        or (row_value.source_kind='current_daily'
          and public.v1_workforce_t09_daily_authorized(row_value.authority_payload))
        or (row_value.source_kind='current_exception'
          and public.v1_current_user_has_capability('workforce.view',null)
          and public.v1_current_user_has_capability('workforce.reports.export',null)
          and public.v1_workforce_t09_has_organization_scope(
            v_actor,row_value.period_month)))
      order by row_value.generated_at desc,row_value.id desc limit p_limit offset p_offset
    ) artifact;
  return jsonb_build_object('schema_version',1,'authorization_mode','enforced_t09',
    'limit',p_limit,'offset',p_offset,'total_count',v_count,'items',v_items);
end;
$$;

update public.v1_capability_catalog
set status='operational',authorization_mode='enforced',is_assignable=true
where capability_key='workforce.reports.export';

revoke all on function public.v1_workforce_t09_has_organization_scope(uuid,date),
  public.v1_workforce_t09_snapshot_authorized(uuid),
  public.v1_workforce_t09_daily_authorized(jsonb),
  public.v1_workforce_t09_columns(text),
  public.v1_workforce_t09_rows(text,uuid[],uuid,uuid,uuid,date,jsonb),
  public.v1_workforce_t09_artifact_authorized(uuid)
from public,anon,authenticated,service_role;
revoke all on function public.v1_generate_workforce_report(jsonb,uuid),
  public.v1_issue_workforce_report_export(jsonb,uuid),
  public.v1_list_workforce_report_artifacts(integer,integer)
from public,anon,authenticated;
grant execute on function public.v1_generate_workforce_report(jsonb,uuid),
  public.v1_issue_workforce_report_export(jsonb,uuid),
  public.v1_list_workforce_report_artifacts(integer,integer)
to authenticated,service_role;

comment on table public.v1_workforce_report_artifacts is
  'T09 immutable protected report payloads; no generated binary or commercial/pay data.';
comment on function public.v1_generate_workforce_report(jsonb,uuid) is
  'T09 online-only idempotent report generation from exact authorized sources.';
comment on function public.v1_issue_workforce_report_export(jsonb,uuid) is
  'T09 online-only idempotent preview/download/share/print issuance audit boundary.';

commit;
