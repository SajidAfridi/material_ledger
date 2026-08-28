begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(8);

select has_table(
  'public',
  'v1_accounts_source_imports',
  'Accounts historical source imports have a protected immutable ledger'
);

select has_column(
  'public',
  'v1_accounts_billing_progress',
  'confirmed_source_import_id',
  'Current progress can retain its approved historical source reconciliation'
);

select has_column(
  'public',
  'v1_accounts_billing_progress_revisions',
  'source_import_id',
  'Each imported progress revision can retain exact source provenance'
);

select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.v1_accounts_source_imports'::regclass
  ),
  'Source-import rows are protected by RLS'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.v1_accounts_source_imports',
    'select'
  ) and not has_table_privilege(
    'authenticated',
    'public.v1_accounts_source_imports',
    'insert'
  ) and not has_table_privilege(
    'authenticated',
    'public.v1_accounts_source_imports',
    'update'
  ) and not has_table_privilege(
    'authenticated',
    'public.v1_accounts_source_imports',
    'delete'
  ),
  'Authenticated clients cannot bypass the Accounts projections and commands'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conrelid =
      'public.v1_accounts_billing_progress'::regclass
      and constraint_record.contype = 'f'
      and pg_catalog.pg_get_constraintdef(constraint_record.oid) like
        '%confirmed_source_import_id%v1_accounts_source_imports%'
  ),
  'Current imported progress retains a restrictive source-ledger foreign key'
);

insert into public.v1_projects (
  id, project_ref, name, project_site, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values (
  '39910000-0000-4000-8000-000000000001',
  'R39-SOURCE-IMPORT-001',
  'Source import fixture',
  'Abu Dhabi',
  'active',
  'project_engineer',
  '10000000-0000-4000-8000-000000000004',
  'admin'
);

insert into public.v1_accounts_source_imports (
  id, project_id, source_type, original_file_name, source_sha256,
  source_byte_size, source_snapshot, excluded_snapshot,
  application_summary, imported_by_auth_user_id, imported_by_exact_role
) values (
  '39920000-0000-4000-8000-000000000001',
  '39910000-0000-4000-8000-000000000001',
  'excel_project_master',
  'Project Master File.xlsx',
  repeat('a', 64),
  1024,
  '{"contract_value_aed":"100.00"}'::jsonb,
  '{"invoice":"excluded_zero_value"}'::jsonb,
  '{"progress_rows_confirmed":1}'::jsonb,
  '10000000-0000-4000-8000-000000000004',
  'admin'
);

select is(
  (
    select source_snapshot->>'contract_value_aed'
    from public.v1_accounts_source_imports
    where id = '39920000-0000-4000-8000-000000000001'
  ),
  '100.00',
  'Lossless decimal source facts remain available for audit'
);

select throws_ok(
  $$
    update public.v1_accounts_source_imports
    set original_file_name = 'Changed.xlsx'
    where id = '39920000-0000-4000-8000-000000000001'
  $$,
  '42501',
  'R39_ACCOUNTS_APPEND_ONLY_FACT',
  'Source reconciliation cannot be edited after it is applied'
);

select * from finish();
rollback;
