-- Yorks R39 Accounts T05-T07 emergency forward-disable gate.
-- REVIEWED ARTIFACT ONLY. Copy into a new forward migration after the
-- application has YORKS_V1_ACCOUNTS=false. This preserves all business,
-- document, audit, notification, metric and job evidence.

begin;

update public.v1_capability_catalog
set status = 'planned', authorization_mode = 'shadow', is_assignable = false
where capability_key = 'export_accounts_registers';

do $forward_disable$
declare
  v_signature text;
  v_function regprocedure;
begin
  foreach v_signature in array array[
    'public.v1_prepare_accounts_document_upload(jsonb,uuid)',
    'public.v1_get_accounts_documents(uuid,text,text,boolean)',
    'public.v1_get_accounts_activity(uuid,text,text,uuid,timestamp with time zone,timestamp with time zone,integer,integer)',
    'public.v1_get_accounts_export(text,uuid,uuid)',
    'public.v1_refresh_accounts_due_notifications()',
    'public.v1_run_accounts_due_reminders(uuid)',
    'public.v1_get_accounts_release_readiness()',
    'public.v1_get_accounts_operational_health(timestamp with time zone)'
  ]::text[] loop
    v_function := to_regprocedure(v_signature);
    if v_function is not null then
      execute format(
        'revoke all on function %s from public, anon, authenticated, service_role',
        v_function
      );
    end if;
  end loop;
end;
$forward_disable$;

do $verify$
declare
  v_exposed integer;
begin
  if not exists (
    select 1 from public.v1_capability_catalog
    where capability_key = 'export_accounts_registers'
      and status = 'planned'
      and authorization_mode = 'shadow'
      and not is_assignable
  ) then
    raise exception 'R39_ACCOUNTS_T05_T07_DISABLE_CAPABILITY_CHECK_FAILED'
      using errcode = '23514';
  end if;

  select count(*) into v_exposed
  from pg_proc function
  join pg_namespace namespace on namespace.oid = function.pronamespace
  where namespace.nspname = 'public'
    and function.proname = any(array[
      'v1_prepare_accounts_document_upload',
      'v1_get_accounts_documents',
      'v1_get_accounts_activity',
      'v1_get_accounts_export',
      'v1_refresh_accounts_due_notifications',
      'v1_run_accounts_due_reminders',
      'v1_get_accounts_release_readiness',
      'v1_get_accounts_operational_health'
    ]::text[])
    and (
      has_function_privilege('anon', function.oid, 'execute')
      or has_function_privilege('authenticated', function.oid, 'execute')
      or has_function_privilege('service_role', function.oid, 'execute')
    );
  if v_exposed <> 0 then
    raise exception 'R39_ACCOUNTS_T05_T07_DISABLE_EXECUTE_CHECK_FAILED'
      using errcode = '42501';
  end if;
end;
$verify$;

commit;
