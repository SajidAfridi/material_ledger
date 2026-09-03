-- Read-only snapshot. Compare timestamped deltas; never treat cumulative means
-- as an after-deployment latency window. No query text or user data is emitted.
with rpc as (
  select substring(query from '"public"\."(v1_[a-z_]+)"') as name,
    calls, total_exec_time
  from pg_stat_statements
  where query like '%pgrst_source%'
    and query not like '%pg_stat_statements%'
), rpc_totals as (
  select name, sum(calls) as calls,
    round(sum(total_exec_time)::numeric, 3) as total_ms
  from rpc
  where name in ('v1_list_chat_conversations', 'v1_mark_chat_delivered',
    'v1_get_current_permission_snapshot', 'v1_get_current_commercial_capabilities',
    'v1_list_my_notifications', 'v1_list_material_requests',
    'v1_list_material_request_summaries')
  group by name
)
select jsonb_build_object(
  'observed_at', clock_timestamp(),
  'postmaster_started_at', pg_postmaster_start_time(),
  'rpc', (select jsonb_agg(rpc_totals order by name) from rpc_totals),
  'realtime', (select jsonb_build_object('calls', sum(calls),
    'total_ms', round(sum(total_exec_time)::numeric, 3))
    from pg_stat_statements where query like '%list_changes%'
      and query not like '%pg_stat_statements%'),
  'subscription_registration', (select jsonb_build_object('calls', sum(calls),
    'total_ms', round(sum(total_exec_time)::numeric, 3))
    from pg_stat_statements where query ilike '%insert into realtime.subscription%'
      and query not like '%pg_stat_statements%'),
  'live_subscriptions', (select count(*) from realtime.subscription),
  'table_writes', (select jsonb_agg(x order by x.relation) from (
    select schemaname || '.' || relname as relation,
      n_tup_ins + n_tup_upd + n_tup_del as writes
    from pg_stat_user_tables
    where (schemaname = 'public' and relname in
      ('v1_chat_members', 'v1_profiles', 'v1_idempotency_keys'))
      or (schemaname = 'realtime' and relname = 'subscription')
  ) x),
  'database', (select jsonb_build_object('stats_reset', stats_reset,
    'committed_transactions', xact_commit, 'rolled_back_transactions', xact_rollback,
    'blocks_read', blks_read, 'blocks_hit', blks_hit,
    'temp_bytes', temp_bytes, 'deadlocks', deadlocks)
    from pg_stat_database where datname = current_database())
) as performance_snapshot;
