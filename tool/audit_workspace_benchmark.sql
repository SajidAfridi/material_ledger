-- Local disposable database only. Every fixture and measurement rolls back.
-- Run after migrations and seed; never run against staging or production.
\set ON_ERROR_STOP on
begin;
set local statement_timeout='0';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
create temporary table audit_bench(samples integer, scenario text, elapsed_ms numeric, payload_bytes integer);
do $$
declare n integer; previous integer:=0; i integer; started timestamptz; result jsonb;
begin
  foreach n in array array[10000,100000,1000000] loop
    -- Read-path benchmark: seed explicit synthetic attribution without timing
    -- per-event capture triggers. Re-enable them before measuring. All rolls back.
    alter table public.v1_audit_events disable trigger user;
    insert into public.v1_audit_events(event_type,entity_type,entity_id,actor_auth_user_id,actor_role,actor_exact_role,actor_display_name_snapshot,occurred_at,after_data,reason)
    select 'material_request_submitted','material_request',
      md5('audit-benchmark-'||(g%10000)::text)::uuid,
      '10000000-0000-4000-8000-000000000004','admin','admin','Audit benchmark actor',
      statement_timestamp()-(g%730)*interval '1 day',
      jsonb_build_object('request_number','BENCH-'||(g%10000)::text,'state','submitted'),
      'Audit scale fixture' from generate_series(previous+1,n) g;
    alter table public.v1_audit_events enable trigger user;
    analyze public.v1_audit_events;
    for i in 1..5 loop
      started:=clock_timestamp();
      result:=public.v1_get_audit_workspace_v2(p_from=>statement_timestamp()-interval '30 days');
      insert into audit_bench values(n,'30-day feed',extract(epoch from clock_timestamp()-started)*1000,octet_length(result::text));
      started:=clock_timestamp();
      result:=public.v1_get_audit_workspace_v2(p_entity_type=>'material_request',p_entity_id=>md5('audit-benchmark-42')::uuid);
      insert into audit_bench values(n,'record history',extract(epoch from clock_timestamp()-started)*1000,octet_length(result::text));
    end loop;
    raise notice 'Completed % events',n;
    previous:=n;
  end loop;
end $$;
select samples,scenario,round(percentile_cont(.5) within group(order by elapsed_ms)::numeric,2) as p50_ms,
  round(percentile_cont(.95) within group(order by elapsed_ms)::numeric,2) as p95_ms,max(payload_bytes) as payload_bytes
from audit_bench group by samples,scenario order by samples,scenario;
explain (analyze,buffers) select id from public.v1_audit_events
where entity_type='material_request' and entity_id=md5('audit-benchmark-42')::uuid
order by occurred_at desc,id desc limit 12;
rollback;
