-- Supabase Management API unified logs: ClickHouse SQL, not PostgreSQL.
-- Supply an explicit <=24h UTC start/end to /analytics/endpoints/logs.
-- Query metadata only; never return event payloads or request headers.
select
  toStartOfFiveMinutes(timestamp) as window_utc,
  count() as postgres_events,
  countIf(log_attributes['parsed.sql_state_code'] = '40001') as serialization_errors,
  countIf(log_attributes['parsed.query_id'] = '6525452760638922684') as private_draft_delete_events,
  countIf(log_attributes['parsed.query_id'] = '1953820537554227456') as approval_edit_events,
  countIf(log_attributes['parsed.query_id'] = '-3852831241267293106') as private_draft_save_events
from logs
where source = 'postgres_logs'
group by window_utc
order by window_utc;
