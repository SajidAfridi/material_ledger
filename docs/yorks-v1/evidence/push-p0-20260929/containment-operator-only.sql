-- PREPARED ONLY. Requires explicit production approval. NOT a migration.
-- Target: czykuksmlwswjsgotrpo. Review current grants/secret names first.
-- Does not delete notifications, tokens, outbox rows or secrets.
-- Already claimed/in-flight FCM work may finish; wait for it to drain.
begin;
do $$
declare v_secret_id uuid;
begin
  select id into v_secret_id from vault.secrets
    where name = 'yorks_push_edge_url';
  if v_secret_id is null or exists (select 1 from vault.secrets
      where name = 'yorks_push_edge_url_p0_paused')
     or (select count(*) from cron.job
       where jobname = 'yorks-v1-push-outbox') <> 1
     or not has_function_privilege('service_role',
       'public.v1_claim_notification_push(uuid)', 'EXECUTE') then
    raise exception 'P0 containment precondition failed';
  end if;
  -- Supported Vault function retains the encrypted value and stable ID.
  perform vault.update_secret(v_secret_id,
    new_name := 'yorks_push_edge_url_p0_paused');
end;
$$;
select cron.alter_job(jobid, active := false)
from cron.job where jobname = 'yorks-v1-push-outbox';
revoke execute on function public.v1_claim_notification_push(uuid)
  from service_role;
do $$ begin
  if has_function_privilege('service_role',
    'public.v1_claim_notification_push(uuid)','EXECUTE') then
    raise exception 'Inherited claim privilege remains; containment rolled back';
  end if;
end $$;
commit;

-- Read-only verification. Never SELECT decrypted_secret.
select name from vault.secrets
where name in ('yorks_push_edge_url', 'yorks_push_edge_url_p0_paused');
select jobname, active from cron.job where jobname = 'yorks-v1-push-outbox';
select has_function_privilege(
  'service_role', 'public.v1_claim_notification_push(uuid)', 'EXECUTE'
) as sender_can_claim;

-- RESTORE IS DELIBERATELY NOT EXECUTABLE HERE. The rename/grant/job state
-- can each be reversed, but reversing against the old code would replay
-- thousands of stale jobs. Re-enable only after the P0 migration has
-- terminalized old jobs and deployed the fenced sender.
-- After approved migration + compatible Edge deployment + poison quarantine
-- + successful staging and designated recovery probe:
-- 1. Restore the reviewed new worker's claim grants (not obsolete entrypoints).
-- 2. Rename yorks_push_edge_url_p0_paused back to yorks_push_edge_url.
-- 3. Enable yorks-v1-push-outbox only with bounded dispatcher/circuit installed.
-- Do NOT simply reverse these steps against the old retry implementation.
