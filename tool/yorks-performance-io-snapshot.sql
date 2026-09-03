-- Read-only I/O attribution. No query text, identity, tokens, or domain rows.
-- Run serially and compare equal timestamped windows without resetting stats.
select jsonb_build_object(
  'observed_at', clock_timestamp(),
  'database', (select jsonb_build_object(
    'temp_files', temp_files, 'temp_bytes', temp_bytes,
    'blocks_read', blks_read, 'blocks_hit', blks_hit,
    'read_ms', blk_read_time, 'write_ms', blk_write_time,
    'deadlocks', deadlocks
  ) from pg_stat_database where datname = current_database()),
  'statements_info', (select to_jsonb(info) from pg_stat_statements_info info),
  'top_temp_statements', (select jsonb_agg(row order by row.temp_written desc)
    from (
      select queryid::text as query_id,
        coalesce(substring(query from '"public"\."(v1_[a-z_]+)"'),
          case when query like '%realtime.list_changes%' then 'realtime.list_changes'
               when query ilike '%insert into realtime.subscription%' then 'realtime.subscription'
               else 'other' end) as operation,
        calls, round(total_exec_time::numeric, 3) as total_ms,
        temp_blks_read as temp_read, temp_blks_written as temp_written,
        shared_blks_read as shared_read, shared_blks_hit as shared_hit
      from pg_stat_statements
      where temp_blks_written > 0
        and query not like '%pg_stat_statements%'
      order by temp_blks_written desc limit 12
    ) row),
  'activity', (select jsonb_agg(row) from (
    select backend_type, state, wait_event_type, wait_event, count(*) as connections
    from pg_stat_activity group by backend_type, state, wait_event_type, wait_event
  ) row),
  'logical_slots', (select jsonb_agg(jsonb_build_object(
    'active', slot.active,
    'retained_wal_bytes', pg_wal_lsn_diff(pg_current_wal_lsn(), slot.restart_lsn),
    'unconfirmed_bytes', pg_wal_lsn_diff(pg_current_wal_lsn(), slot.confirmed_flush_lsn),
    'spill_bytes', stats.spill_bytes, 'spill_count', stats.spill_count
  )) from pg_replication_slots slot
    left join pg_stat_replication_slots stats using (slot_name)
    where slot.slot_type = 'logical')
) as io_snapshot;
