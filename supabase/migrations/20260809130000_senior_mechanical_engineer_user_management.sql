-- Product-owner approval: Senior Mechanical Engineer may administer Yorks
-- users. Project Manager and the other engineering roles remain denied.
-- This is additive authorization only; no user, role, capability or audit
-- history is rewritten. Rollback restores the former exact-Admin checks after
-- confirming no Senior-authored user command is in flight.

create or replace function public.v1_user_configuration_actor()
returns boolean
language sql
volatile
security definer
set search_path = ''
as $$
  select public.v1_current_exact_role() in (
    'admin', 'senior_mechanical_engineer'
  );
$$;

revoke all on function public.v1_user_configuration_actor() from public;
revoke all on function public.v1_user_configuration_actor() from anon;
revoke all on function public.v1_user_configuration_actor() from authenticated;

do $$
declare
  v_definition text;
  v_updated text;
  v_signature regprocedure;
begin
  -- Preserve the established audited Auth transaction, but allow the exact
  -- Senior role as an actor and retain both normalized and exact attribution.
  v_signature := 'public.v1_auth_users_admin_audit_trigger()'::regprocedure;
  select pg_get_functiondef(v_signature) into v_definition;
  v_updated := v_definition;
  v_updated := replace(
    v_updated,
    'v_actor_auth auth.users%rowtype;',
    'v_actor_auth auth.users%rowtype;' || chr(10) || '  v_actor_exact_role text;'
  );
  v_updated := replace(
    v_updated,
    'if not found' || chr(10) ||
      '    or coalesce(v_actor_auth.raw_app_meta_data ->> ''role'', '''') <> ''admin''',
    'v_actor_exact_role := coalesce(' ||
      'v_actor_auth.raw_app_meta_data ->> ''role'', '''');' || chr(10) ||
      '  if not found' || chr(10) ||
      '    or v_actor_exact_role not in (' ||
      '''admin'', ''senior_mechanical_engineer'')'
  );
  v_updated := replace(
    v_updated,
    'and profile.canonical_role_snapshot = ''admin''',
    'and profile.canonical_role_snapshot = case v_actor_exact_role' || chr(10) ||
      '        when ''admin'' then ''admin''' || chr(10) ||
      '        else ''project_engineer''' || chr(10) ||
      '      end'
  );
  v_updated := replace(
    v_updated,
    'actor_role,' || chr(10) || '      occurred_at,',
    'actor_role,' || chr(10) || '      actor_exact_role,' || chr(10) ||
      '      occurred_at,'
  );
  v_updated := replace(
    v_updated,
    '''admin'',' || chr(10) || '      clock_timestamp(),',
    'case v_actor_exact_role' || chr(10) ||
      '        when ''admin'' then ''admin''' || chr(10) ||
      '        else ''project_engineer''' || chr(10) ||
      '      end,' || chr(10) ||
      '      v_actor_exact_role,' || chr(10) ||
      '      clock_timestamp(),'
  );

  if v_updated = v_definition
    or position('senior_mechanical_engineer' in v_updated) = 0
    or position('actor_exact_role' in v_updated) = 0 then
    raise exception 'V1_USER_CONFIGURATION_AUDIT_MIGRATION_SOURCE_MISMATCH';
  end if;
  execute v_updated;

  -- Capability controls live inside User Management. Widen only the actor
  -- predicate; target rules, reasons, idempotency and audit remain unchanged.
  foreach v_signature in array array[
    'public.v1_get_user_commercial_capabilities(uuid)'::regprocedure,
    'public.v1_set_user_commercial_capability(jsonb,uuid)'::regprocedure
  ] loop
    select pg_get_functiondef(v_signature) into v_definition;
    v_updated := replace(
      v_definition,
      'public.v1_current_role() <> ''admin''',
      'not public.v1_user_configuration_actor()'
    );
    if v_updated = v_definition
      and position('v1_user_configuration_actor()' in v_definition) = 0 then
      raise exception
        'V1_USER_CONFIGURATION_CAPABILITY_MIGRATION_SOURCE_MISMATCH';
    end if;
    execute v_updated;
  end loop;
end;
$$;
