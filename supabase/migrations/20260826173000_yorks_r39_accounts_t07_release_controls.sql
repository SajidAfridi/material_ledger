-- Yorks R39 Accounts T07: additive observability, reconciliation and release
-- controls. This does not enable the application feature flag and it never
-- rewrites Projects, BOQ, Material Requests, stock, logistics or returns.

create table if not exists public.v1_accounts_operation_metrics (
  id uuid primary key default gen_random_uuid(),
  support_reference text not null unique
    check (support_reference ~ '^ACC-[A-F0-9]{12}$'),
  audit_event_id uuid unique
    references public.v1_audit_events (id) on delete restrict,
  operation_name text not null check (btrim(operation_name) <> ''),
  outcome text not null check (outcome in (
    'success', 'rejection', 'conflict', 'infrastructure_failure', 'job_failure'
  )),
  latency_ms numeric(14,3) not null default 0 check (latency_ms >= 0),
  project_id uuid references public.v1_projects (id) on delete restrict,
  actor_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_exact_role text,
  correlation_id uuid,
  occurred_at timestamptz not null default clock_timestamp(),
  safe_error_code text,
  check (
    (outcome = 'success' and safe_error_code is null)
    or (outcome <> 'success' and nullif(btrim(safe_error_code), '') is not null)
  )
);

create table if not exists public.v1_accounts_job_runs (
  id uuid primary key default gen_random_uuid(),
  job_name text not null check (job_name in ('due_reminders')),
  run_key uuid not null,
  support_reference text not null unique
    check (support_reference ~ '^ACC-[A-F0-9]{12}$'),
  status text not null check (status in ('running', 'succeeded', 'failed')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  affected_rows integer check (affected_rows is null or affected_rows >= 0),
  safe_error_code text,
  started_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  unique (job_name, run_key),
  check (
    (status = 'running' and completed_at is null and safe_error_code is null)
    or (status = 'succeeded' and completed_at is not null
      and safe_error_code is null and affected_rows is not null)
    or (status = 'failed' and completed_at is not null
      and nullif(btrim(safe_error_code), '') is not null)
  )
);

alter table public.v1_accounts_operation_metrics enable row level security;
alter table public.v1_accounts_job_runs enable row level security;
revoke all on table public.v1_accounts_operation_metrics
  from public, anon, authenticated;
revoke all on table public.v1_accounts_job_runs
  from public, anon, authenticated;
grant all on table public.v1_accounts_operation_metrics to service_role;
grant all on table public.v1_accounts_job_runs to service_role;

create index if not exists v1_accounts_operation_metrics_time_idx
  on public.v1_accounts_operation_metrics (occurred_at desc, outcome);
create index if not exists v1_accounts_operation_metrics_project_idx
  on public.v1_accounts_operation_metrics (project_id, occurred_at desc)
  where project_id is not null;
create index if not exists v1_accounts_job_runs_status_idx
  on public.v1_accounts_job_runs (status, updated_at desc);
create index if not exists v1_accounts_document_metadata_type_idx
  on public.v1_accounts_document_metadata (document_type, created_at desc);
create index if not exists v1_audit_events_accounts_project_idx
  on public.v1_audit_events (project_id, occurred_at desc, event_type)
  where event_type like 'accounts.%';

create or replace function public.v1_accounts_support_reference(p_id uuid)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select 'ACC-' || upper(substr(replace(p_id::text, '-', ''), 1, 12));
$$;

create or replace function public.v1_accounts_capture_operation_metric()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.event_type like 'accounts.%' then
    insert into public.v1_accounts_operation_metrics (
      support_reference, audit_event_id, operation_name, outcome, latency_ms,
      project_id, actor_auth_user_id, actor_exact_role, correlation_id,
      occurred_at
    ) values (
      public.v1_accounts_support_reference(new.id), new.id, new.event_type,
      'success', greatest(
        extract(epoch from (clock_timestamp() - statement_timestamp())) * 1000,
        0
      ), new.project_id, new.actor_auth_user_id, new.actor_exact_role,
      new.idempotency_key, new.occurred_at
    ) on conflict (audit_event_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_accounts_operation_metric_after_audit
  on public.v1_audit_events;
create trigger v1_accounts_operation_metric_after_audit
after insert on public.v1_audit_events
for each row execute function public.v1_accounts_capture_operation_metric();

create or replace function public.v1_run_accounts_due_reminders(p_run_key uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_run public.v1_accounts_job_runs%rowtype;
  v_rows integer;
  v_sqlstate text;
  v_reference text;
begin
  if p_run_key is null then
    raise exception 'R39_ACCOUNTS_RUN_KEY_REQUIRED' using errcode = '22023';
  end if;
  v_reference := public.v1_accounts_support_reference(p_run_key);
  insert into public.v1_accounts_job_runs (
    job_name, run_key, support_reference, status
  ) values ('due_reminders', p_run_key, v_reference, 'running')
  on conflict (job_name, run_key) do nothing;

  select * into v_run from public.v1_accounts_job_runs
  where job_name = 'due_reminders' and run_key = p_run_key
  for update;
  if v_run.status = 'succeeded' then
    return jsonb_build_object(
      'status', 'succeeded', 'replayed', true,
      'support_reference', v_run.support_reference,
      'affected_rows', v_run.affected_rows,
      'attempt_count', v_run.attempt_count
    );
  end if;

  update public.v1_accounts_job_runs set
    status = 'running', attempt_count = attempt_count + 1,
    affected_rows = null, safe_error_code = null,
    completed_at = null, started_at = clock_timestamp(),
    updated_at = clock_timestamp()
  where id = v_run.id
  returning * into v_run;

  begin
    v_rows := public.v1_refresh_accounts_due_notifications();
    update public.v1_accounts_job_runs set
      status = 'succeeded', affected_rows = v_rows,
      completed_at = clock_timestamp(), updated_at = clock_timestamp()
    where id = v_run.id
    returning * into v_run;
    return jsonb_build_object(
      'status', 'succeeded', 'replayed', false,
      'support_reference', v_run.support_reference,
      'affected_rows', v_run.affected_rows,
      'attempt_count', v_run.attempt_count
    );
  exception when others then
    get stacked diagnostics v_sqlstate = returned_sqlstate;
    update public.v1_accounts_job_runs set
      status = 'failed', safe_error_code = coalesce(v_sqlstate, 'XX000'),
      completed_at = clock_timestamp(), updated_at = clock_timestamp()
    where id = v_run.id
    returning * into v_run;
    raise log 'accounts_job outcome=failed job=due_reminders support_reference=% sqlstate=%',
      v_run.support_reference, v_run.safe_error_code;
    return jsonb_build_object(
      'status', 'failed', 'replayed', false,
      'support_reference', v_run.support_reference,
      'safe_error_code', v_run.safe_error_code,
      'attempt_count', v_run.attempt_count
    );
  end;
end;
$$;

create or replace function public.v1_get_accounts_release_readiness()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_permission_exact_role(auth.uid());
  v_catalog integer;
  v_stage_template integer;
  v_profile_without_baseline integer;
  v_bad_building_totals integer;
  v_bad_stage_totals integer;
  v_unclassified_documents integer;
  v_audit_without_role integer;
  v_failed_jobs integer;
  v_supplier_review integer;
  v_overdue integer;
  v_blockers integer;
  v_warnings integer;
begin
  if v_role <> 'admin' or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;

  select count(*) into v_catalog from public.v1_capability_catalog catalog
  where public.v1_accounts_is_capability_key(catalog.capability_key)
    and catalog.status = 'operational'
    and catalog.authorization_mode = 'enforced'
    and catalog.is_assignable;
  select count(*) into v_stage_template
  from public.v1_accounts_billing_stage_templates stage
  where stage.is_active;
  select count(*) into v_profile_without_baseline
  from public.v1_accounts_project_commercial_profiles profile
  left join public.v1_accounts_baseline_revisions baseline
    on baseline.id = profile.current_baseline_revision_id
  where baseline.id is null;
  select count(*) into v_bad_building_totals from (
    select allocation.baseline_revision_id
    from public.v1_accounts_baseline_building_allocations allocation
    group by allocation.baseline_revision_id
    having abs(sum(allocation.allocation_percent) - 100) > 0.00005
  ) invalid;
  select count(*) into v_bad_stage_totals from (
    select allocation.baseline_revision_id
    from public.v1_accounts_baseline_stage_allocations allocation
    group by allocation.baseline_revision_id
    having abs(sum(allocation.allocation_percent) - 100) > 0.00005
  ) invalid;
  select count(distinct link.document_id) into v_unclassified_documents
  from public.v1_document_links link
  left join public.v1_accounts_document_metadata metadata
    on metadata.document_id = link.document_id
  where link.entity_type like 'accounts_%' and metadata.document_id is null;
  select count(*) into v_audit_without_role
  from public.v1_audit_events audit
  where audit.event_type like 'accounts.%'
    and nullif(btrim(audit.actor_exact_role), '') is null;
  select count(*) into v_failed_jobs
  from public.v1_accounts_job_runs run
  where run.status = 'failed' and run.updated_at >= clock_timestamp() - interval '7 days';
  select count(*) into v_supplier_review
  from public.v1_accounts_supplier_bills bill
  where bill.status <> 'cancelled'
    and public.v1_accounts_supplier_match_status(bill.id) <> 'matched';
  select count(*) into v_overdue
  from public.v1_accounts_client_invoices invoice
  where invoice.status not in ('draft', 'returned', 'cancelled', 'paid')
    and invoice.due_date < current_date;

  v_blockers := (case when v_catalog = 15 then 0 else 1 end)
    + (case when v_stage_template = 5 and (
        select abs(sum(stage.allocation_percent) - 100) <= 0.00005
        from public.v1_accounts_billing_stage_templates stage
        where stage.is_active
      ) then 0 else 1 end)
    + v_profile_without_baseline + v_bad_building_totals + v_bad_stage_totals
    + v_unclassified_documents + v_audit_without_role;
  v_warnings := v_failed_jobs + v_supplier_review + v_overdue;

  return jsonb_build_object(
    'schema_version', 7,
    'generated_at', clock_timestamp(),
    'actor_exact_role', v_role,
    'backend_ready', v_blockers = 0,
    'blocking_issue_count', v_blockers,
    'warning_count', v_warnings,
    'feature_flag_must_remain_off_until_uat', true,
    'checks', jsonb_build_array(
      jsonb_build_object('key','capability_catalog','status',case when v_catalog=15 then 'pass' else 'fail' end,'count',v_catalog),
      jsonb_build_object('key','stage_template','status',case when v_stage_template=5 then 'pass' else 'fail' end,'count',v_stage_template),
      jsonb_build_object('key','profiles_without_baseline','status',case when v_profile_without_baseline=0 then 'pass' else 'fail' end,'count',v_profile_without_baseline),
      jsonb_build_object('key','invalid_building_allocations','status',case when v_bad_building_totals=0 then 'pass' else 'fail' end,'count',v_bad_building_totals),
      jsonb_build_object('key','invalid_stage_allocations','status',case when v_bad_stage_totals=0 then 'pass' else 'fail' end,'count',v_bad_stage_totals),
      jsonb_build_object('key','unclassified_accounts_documents','status',case when v_unclassified_documents=0 then 'pass' else 'fail' end,'count',v_unclassified_documents),
      jsonb_build_object('key','audit_without_exact_role','status',case when v_audit_without_role=0 then 'pass' else 'fail' end,'count',v_audit_without_role),
      jsonb_build_object('key','failed_jobs_7d','status',case when v_failed_jobs=0 then 'pass' else 'warn' end,'count',v_failed_jobs),
      jsonb_build_object('key','supplier_match_queue','status',case when v_supplier_review=0 then 'pass' else 'warn' end,'count',v_supplier_review),
      jsonb_build_object('key','overdue_client_invoices','status',case when v_overdue=0 then 'pass' else 'warn' end,'count',v_overdue)
    )
  );
end;
$$;

create or replace function public.v1_get_accounts_operational_health(
  p_since timestamptz default clock_timestamp() - interval '24 hours'
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_permission_exact_role(auth.uid());
begin
  if v_role <> 'admin' or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  if p_since is null or p_since < clock_timestamp() - interval '90 days'
    or p_since > clock_timestamp() then
    raise exception 'R39_ACCOUNTS_OBSERVABILITY_RANGE_INVALID'
      using errcode = '22023';
  end if;
  return jsonb_build_object(
    'schema_version', 7,
    'since', p_since,
    'generated_at', clock_timestamp(),
    'metrics', coalesce((
      select jsonb_agg(jsonb_build_object(
        'operation_name', metric.operation_name,
        'outcome', metric.outcome,
        'count', metric.count,
        'p95_latency_ms', metric.p95_latency_ms
      ) order by metric.operation_name, metric.outcome)
      from (
        select operation_name, outcome, count(*) count,
          round(percentile_cont(0.95) within group (order by latency_ms)::numeric,3)
            p95_latency_ms
        from public.v1_accounts_operation_metrics
        where occurred_at >= p_since
        group by operation_name, outcome
      ) metric
    ), '[]'::jsonb),
    'jobs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'job_name', run.job_name, 'status', run.status,
        'attempt_count', run.attempt_count,
        'affected_rows', run.affected_rows,
        'support_reference', run.support_reference,
        'safe_error_code', run.safe_error_code,
        'updated_at', run.updated_at
      ) order by run.updated_at desc)
      from (
        select * from public.v1_accounts_job_runs
        where updated_at >= p_since order by updated_at desc limit 50
      ) run
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_accounts_support_reference(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_capture_operation_metric()
  from public, anon, authenticated;
revoke all on function public.v1_refresh_accounts_due_notifications()
  from service_role;
revoke all on function public.v1_run_accounts_due_reminders(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_accounts_release_readiness()
  from public, anon;
revoke all on function public.v1_get_accounts_operational_health(timestamptz)
  from public, anon;
grant execute on function public.v1_run_accounts_due_reminders(uuid)
  to service_role;
grant execute on function public.v1_get_accounts_release_readiness()
  to authenticated;
grant execute on function public.v1_get_accounts_operational_health(timestamptz)
  to authenticated;

comment on table public.v1_accounts_operation_metrics is
  'Safe transactional Accounts success metrics derived from immutable audit facts; privacy-safe client/server logs carry rejected/conflict support references.';
comment on table public.v1_accounts_job_runs is
  'Retryable, idempotent operational record for Accounts scheduled jobs.';
comment on function public.v1_get_accounts_release_readiness() is
  'Admin-only reconciliation gate. Application flag remains off until five-persona staging UAT.';
