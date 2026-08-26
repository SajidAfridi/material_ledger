begin;

create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();

select ok(
  (select relrowsecurity from pg_class
    where oid='public.v1_accounts_operation_metrics'::regclass)
  and (select relrowsecurity from pg_class
    where oid='public.v1_accounts_job_runs'::regclass)
  and not has_table_privilege(
    'authenticated','public.v1_accounts_operation_metrics','select'
  )
  and not has_table_privilege(
    'authenticated','public.v1_accounts_job_runs','insert'
  )
  and has_function_privilege(
    'service_role','public.v1_run_accounts_due_reminders(uuid)','execute'
  )
  and not has_function_privilege(
    'authenticated','public.v1_run_accounts_due_reminders(uuid)','execute'
  ),
  'T07 observability tables stay private and the retryable job is service-only'
);

insert into public.v1_audit_events(
  id,event_type,entity_type,entity_id,project_id,actor_auth_user_id,
  actor_role,actor_exact_role,idempotency_key,after_data
) values(
  '39700000-0000-4000-8000-000000000001',
  'accounts.release.tested','accounts_release',
  '39700000-0000-4000-8000-000000000002',null,
  '10000000-0000-4000-8000-000000000004','admin','admin',
  '39700000-0000-4000-8000-000000000003','{"gate":"t07"}'::jsonb
),(
  '39700000-0000-4000-8000-000000000004',
  'project.updated','project',
  '39700000-0000-4000-8000-000000000005',null,
  '10000000-0000-4000-8000-000000000004','admin','admin',
  '39700000-0000-4000-8000-000000000006','{}'::jsonb
);

select ok(
  (select count(*)=1 from public.v1_accounts_operation_metrics)
  and exists(
    select 1 from public.v1_accounts_operation_metrics metric
    where metric.audit_event_id='39700000-0000-4000-8000-000000000001'
      and metric.operation_name='accounts.release.tested'
      and metric.outcome='success'
      and metric.support_reference='ACC-397000000000'
      and metric.latency_ms>=0
      and metric.actor_exact_role='admin'
  ),
  'Only immutable Accounts audit facts derive safe structured success metrics'
);

set local role service_role;
select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
create temporary table v1_r39_t07_results(
  result_key text primary key,
  payload jsonb not null
);
grant select,insert on v1_r39_t07_results to authenticated,service_role;
insert into v1_r39_t07_results values(
  'job_first',public.v1_run_accounts_due_reminders(
    '39710000-0000-4000-8000-000000000001'
  )
),(
  'job_replay',public.v1_run_accounts_due_reminders(
    '39710000-0000-4000-8000-000000000001'
  )
);
select ok(
  (select payload->>'status'='succeeded'
      and not (payload->>'replayed')::boolean
      and payload->>'support_reference'='ACC-397100000000'
    from v1_r39_t07_results where result_key='job_first')
  and (select payload->>'status'='succeeded'
      and (payload->>'replayed')::boolean
      and (payload->>'attempt_count')::integer=1
    from v1_r39_t07_results where result_key='job_replay')
  and (select count(*)=1 from public.v1_accounts_job_runs
    where job_name='due_reminders'),
  'Due reminders are observable, idempotent and replay the same completed run'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
insert into v1_r39_t07_results values(
  'readiness',public.v1_get_accounts_release_readiness()
),(
  'health',public.v1_get_accounts_operational_health(
    clock_timestamp()-interval '1 day'
  )
);
select ok(
  (select payload->>'schema_version'='7'
      and (payload->>'backend_ready')::boolean
      and (payload->>'blocking_issue_count')::integer=0
      and (payload->>'feature_flag_must_remain_off_until_uat')::boolean
    from v1_r39_t07_results where result_key='readiness'),
  'Admin reconciliation proves the clean backend while preserving the UAT flag gate'
);
select ok(
  (select payload->>'schema_version'='7'
      and jsonb_array_length(payload->'metrics')>=1
      and jsonb_array_length(payload->'jobs')=1
    from v1_r39_t07_results where result_key='health'),
  'Admin operational health exposes safe metrics and retryable job status'
);

select throws_ok(
  $$select public.v1_get_accounts_operational_health(
    clock_timestamp()-interval '91 days'
  )$$,
  '22023','R39_ACCOUNTS_OBSERVABILITY_RANGE_INVALID',
  'Operational health rejects unbounded history scans'
);

select throws_ok(
  $$select public.v1_run_accounts_due_reminders(
    '39710000-0000-4000-8000-000000000002'
  )$$,
  '42501',null,
  'Authenticated clients cannot invoke the service reminder runner'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site"}}',
  true
);
select throws_ok(
  $$select public.v1_get_accounts_release_readiness()$$,
  '42501','R39_ACCOUNTS_ACCESS_DENIED',
  'Site Engineers cannot read release reconciliation or commercial health'
);

select ok(
  not has_table_privilege(
    'authenticated','public.v1_accounts_operation_metrics','insert'
  )
  and not has_table_privilege(
    'authenticated','public.v1_accounts_job_runs','update'
  ),
  'Direct clients cannot manufacture metrics or rewrite job outcomes'
);

reset role;
select * from finish();
rollback;
