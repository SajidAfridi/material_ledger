-- Restore the subscription contract declared by legacy_collection_prerequisites.
-- Production drift omitted these two tables while every signed-in client still
-- requests them. No row, RLS policy, grant, trigger or replica identity changes.
-- Rollback (transport only): remove these exact tables from supabase_realtime;
-- that restores the prior broken transport and must not delete master data.
do $$
declare
  v_table text;
begin
  perform set_config('lock_timeout', '3s', true);
  if not exists (
    select 1 from pg_catalog.pg_publication
    where pubname = 'supabase_realtime'
  ) then
    raise exception 'YORKS_REALTIME_PUBLICATION_REQUIRED';
  end if;

  foreach v_table in array array['materialCategories', 'materialUnits'] loop
    if not exists (
      select 1 from pg_catalog.pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', v_table
      );
    end if;
  end loop;
end;
$$;
