begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(11);

select has_function(
  'public',
  'v1_accounts_reconcile_yra322_source_progress',
  array[]::text[],
  'The YRA-322 correction has an owner-only deterministic test seam'
);

select ok(
  not has_function_privilege(
    'public',
    'public.v1_accounts_reconcile_yra322_source_progress()',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_accounts_reconcile_yra322_source_progress()',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_accounts_reconcile_yra322_source_progress()',
    'execute'
  )
  and not has_function_privilege(
    'service_role',
    'public.v1_accounts_reconcile_yra322_source_progress()',
    'execute'
  ),
  'No API role can invoke the production-specific correction seam'
);

insert into public.v1_projects (
  id, project_ref, name, job_contract_reference, project_site, state,
  current_action_owner_role, created_by_auth_user_id, created_by_role
) values (
  '39930000-0000-4000-8000-000000000001',
  'YRA-322',
  'Nexus Station reconciliation fixture',
  'N-19957.2',
  'Al Dhafra',
  'active',
  'project_engineer',
  '10000000-0000-4000-8000-000000000004',
  'admin'
);

insert into public.v1_project_scopes (
  id, project_id, scope_kind, scope_code, name
) values
  (
    '39931000-0000-4000-8000-000000000001',
    '39930000-0000-4000-8000-000000000001',
    'building', 'a-df3w', 'DF3W'
  ),
  (
    '39931000-0000-4000-8000-000000000002',
    '39930000-0000-4000-8000-000000000001',
    'building', 'b-df4w', 'DF4W'
  ),
  (
    '39931000-0000-4000-8000-000000000003',
    '39930000-0000-4000-8000-000000000001',
    'building', 'c-df6w', 'DF6W'
  ),
  (
    '39931000-0000-4000-8000-000000000004',
    '39930000-0000-4000-8000-000000000001',
    'building', 'd-df7w', 'DF7W'
  );

insert into public.v1_accounts_baseline_revisions (
  id, project_id, revision_number, status, contract_value, currency_code,
  vat_rate_percent, payment_terms_days, reminder_lead_days,
  management_review_policy, reason, approved_by_auth_user_id,
  approved_by_role, approved_by_exact_role, idempotency_key,
  superseded_at, superseded_by_revision_id
) values
  (
    '39932000-0000-4000-8000-000000000001',
    '39930000-0000-4000-8000-000000000001',
    1, 'superseded', 17192000.00, 'AED', 0, 90, 10,
    '{"always_required":false,"threshold_amount":null,"confirming_exact_roles":[]}'::jsonb,
    'Original source-grounded baseline',
    '10000000-0000-4000-8000-000000000004', 'admin', 'admin',
    '39932000-0000-4000-8000-000000000101',
    clock_timestamp(),
    '39932000-0000-4000-8000-000000000002'
  ),
  (
    '39932000-0000-4000-8000-000000000002',
    '39930000-0000-4000-8000-000000000001',
    2, 'current', 17192000.00, 'AED', 0, 90, 10,
    '{"always_required":false,"threshold_amount":null,"confirming_exact_roles":["project_engineer","project_manager","senior_mechanical_engineer"]}'::jsonb,
    'Equivalent dimensions with updated review policy',
    '10000000-0000-4000-8000-000000000004', 'admin', 'admin',
    '39932000-0000-4000-8000-000000000102',
    null, null
  );

insert into public.v1_accounts_project_commercial_profiles (
  project_id, current_baseline_revision_id, status, record_version,
  created_by_auth_user_id, created_by_role, created_by_exact_role
) values (
  '39930000-0000-4000-8000-000000000001',
  '39932000-0000-4000-8000-000000000002',
  'active', 2,
  '10000000-0000-4000-8000-000000000004', 'admin', 'admin'
);

select public.v1_accounts_materialize_baseline_dimensions(
  '39930000-0000-4000-8000-000000000001',
  '39932000-0000-4000-8000-000000000001',
  jsonb_build_array(
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000001', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000002', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000003', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000004', 'allocation_percent', '25.0000')
  ),
  jsonb_build_array(
    jsonb_build_object('stage_key', 'design', 'stage_label', 'Design', 'allocation_percent', '10.0000', 'position', 1),
    jsonb_build_object('stage_key', 'material_supply', 'stage_label', 'Material Supply', 'allocation_percent', '50.0000', 'position', 2),
    jsonb_build_object('stage_key', 'installation', 'stage_label', 'Installation', 'allocation_percent', '30.0000', 'position', 3),
    jsonb_build_object('stage_key', 'commissioning_handover', 'stage_label', 'Commissioning & Handover', 'allocation_percent', '5.0000', 'position', 4),
    jsonb_build_object('stage_key', 'energizing', 'stage_label', 'Energizing', 'allocation_percent', '5.0000', 'position', 5)
  )
);

select public.v1_accounts_materialize_baseline_dimensions(
  '39930000-0000-4000-8000-000000000001',
  '39932000-0000-4000-8000-000000000002',
  jsonb_build_array(
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000001', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000002', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000003', 'allocation_percent', '25.0000'),
    jsonb_build_object('building_scope_id', '39931000-0000-4000-8000-000000000004', 'allocation_percent', '25.0000')
  ),
  jsonb_build_array(
    jsonb_build_object('stage_key', 'design', 'stage_label', 'Design', 'allocation_percent', '10.0000', 'position', 1),
    jsonb_build_object('stage_key', 'material_supply', 'stage_label', 'Material Supply', 'allocation_percent', '50.0000', 'position', 2),
    jsonb_build_object('stage_key', 'installation', 'stage_label', 'Installation', 'allocation_percent', '30.0000', 'position', 3),
    jsonb_build_object('stage_key', 'commissioning_handover', 'stage_label', 'Commissioning & Handover', 'allocation_percent', '5.0000', 'position', 4),
    jsonb_build_object('stage_key', 'energizing', 'stage_label', 'Energizing', 'allocation_percent', '5.0000', 'position', 5)
  )
);

insert into public.v1_accounts_source_imports (
  id, project_id, source_type, original_file_name, source_sha256,
  source_byte_size, source_snapshot, excluded_snapshot,
  application_summary, imported_by_auth_user_id, imported_by_exact_role
) values (
  '39933000-0000-4000-8000-000000000001',
  '39930000-0000-4000-8000-000000000001',
  'excel_project_master',
  'Project Master File - Nexus 4 Station.xlsx',
  '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c',
  1961340,
  jsonb_build_object(
    'workbook_project_ref', 'YRA-322',
    'contract_reference', 'N-19957.2',
    'contract_value_aed', '17192000.00',
    'source_sheet', 'Summery (Option)',
    'building_allocations', jsonb_build_array(
      jsonb_build_object('scope_code', 'a-df3w', 'percent', '25.0000'),
      jsonb_build_object('scope_code', 'b-df4w', 'percent', '25.0000'),
      jsonb_build_object('scope_code', 'c-df6w', 'percent', '25.0000'),
      jsonb_build_object('scope_code', 'd-df7w', 'percent', '25.0000')
    ),
    'stage_allocations', jsonb_build_array(
      jsonb_build_object('stage_key', 'design', 'percent', '10.0000'),
      jsonb_build_object('stage_key', 'material_supply', 'percent', '50.0000'),
      jsonb_build_object('stage_key', 'installation', 'percent', '30.0000'),
      jsonb_build_object('stage_key', 'commissioning_handover', 'percent', '5.0000'),
      jsonb_build_object('stage_key', 'energizing', 'percent', '5.0000')
    ),
    'confirmed_progress', jsonb_build_array(
      jsonb_build_object('scope_code', 'a-df3w', 'stage_key', 'design', 'stage_percent', '100.0000', 'contract_percent', '2.5000', 'value_aed', '429800.00', 'cells', jsonb_build_array('H9', 'I9', 'W9', 'X9')),
      jsonb_build_object('scope_code', 'b-df4w', 'stage_key', 'design', 'stage_percent', '100.0000', 'contract_percent', '2.5000', 'value_aed', '429800.00', 'cells', jsonb_build_array('H20', 'I20', 'W20', 'X20')),
      jsonb_build_object('scope_code', 'c-df6w', 'stage_key', 'design', 'stage_percent', '100.0000', 'contract_percent', '2.5000', 'value_aed', '429800.00', 'cells', jsonb_build_array('H31', 'I31', 'W31', 'X31')),
      jsonb_build_object('scope_code', 'd-df7w', 'stage_key', 'design', 'stage_percent', '100.0000', 'contract_percent', '2.5000', 'value_aed', '429800.00', 'cells', jsonb_build_array('H42', 'I42', 'W42', 'X42'))
    ),
    'overall_confirmed_percent', '10.0000',
    'overall_confirmed_value_aed', '1719200.00'
  ),
  '{"project_details_sheet":{"result":"excluded_conflicting_copy","reported_project_ref":"YRA-315"}}'::jsonb,
  '{"progress_rows_confirmed":4,"transactions_created":0}'::jsonb,
  '10000000-0000-4000-8000-000000000004',
  'admin'
);

update public.v1_accounts_billing_progress progress
set suggested_percent = 100,
    suggested_evidence_summary = 'Historical workbook suggestion',
    suggested_by_auth_user_id = '10000000-0000-4000-8000-000000000002',
    suggested_by_exact_role = 'site_engineer',
    suggested_at = clock_timestamp(),
    confirmed_percent = 100,
    confirmed_evidence_summary = 'Approved historical workbook import',
    confirmed_source_import_id = '39933000-0000-4000-8000-000000000001',
    confirmed_by_auth_user_id = '10000000-0000-4000-8000-000000000004',
    confirmed_by_exact_role = 'admin',
    confirmed_at = clock_timestamp(),
    record_version = 3,
    updated_at = clock_timestamp()
from public.v1_project_scopes scope
where scope.id = progress.project_scope_id
  and progress.baseline_revision_id =
    '39932000-0000-4000-8000-000000000001'
  and progress.stage_key = 'design'
  and scope.scope_code = any(array[
    'a-df3w', 'b-df4w', 'c-df6w', 'd-df7w'
  ]::text[]);

update public.v1_accounts_billing_progress
set record_version = 2
where baseline_revision_id = '39932000-0000-4000-8000-000000000002'
  and stage_key = 'material_supply'
  and project_scope_id = '39931000-0000-4000-8000-000000000001';

select throws_ok(
  'select public.v1_accounts_reconcile_yra322_source_progress()',
  '40001',
  'R39_ACCOUNTS_YRA322_CURRENT_PROGRESS_CONFLICT',
  'A touched current-baseline row fails closed before source progress is applied'
);

update public.v1_accounts_billing_progress
set record_version = 1
where baseline_revision_id = '39932000-0000-4000-8000-000000000002'
  and stage_key = 'material_supply'
  and project_scope_id = '39931000-0000-4000-8000-000000000001';

create temporary table v1_yra322_reconciliation_results (
  result_key text primary key,
  payload jsonb not null
);

insert into v1_yra322_reconciliation_results (result_key, payload)
values (
  'applied',
  public.v1_accounts_reconcile_yra322_source_progress()
);

select is(
  (
    select payload ->> 'status'
    from v1_yra322_reconciliation_results
    where result_key = 'applied'
  ),
  'reconciled',
  'The guarded correction reports a completed reconciliation'
);

select is(
  (
    select count(*)
    from public.v1_accounts_billing_progress progress
    where progress.baseline_revision_id =
      '39932000-0000-4000-8000-000000000002'
      and progress.stage_key = 'design'
      and progress.suggested_percent = 0
      and progress.confirmed_percent = 100
      and progress.confirmed_source_import_id =
        '39933000-0000-4000-8000-000000000001'
      and progress.record_version = 2
  ),
  4::bigint,
  'Exactly four active Design rows carry the immutable confirmation'
);

select is(
  (
    select count(*)
    from public.v1_accounts_billing_progress progress
    where progress.baseline_revision_id =
      '39932000-0000-4000-8000-000000000002'
      and not (
        progress.stage_key = 'design'
        and progress.confirmed_percent = 100
      )
      and (
        progress.suggested_percent <> 0
        or progress.confirmed_percent <> 0
        or progress.confirmed_source_import_id is not null
        or progress.record_version <> 1
      )
  ),
  0::bigint,
  'All sixteen non-Design cells remain pristine zero facts'
);

select is(
  (
    select round(sum(
      baseline.contract_value
        * building.allocation_percent / 100
        * stage.allocation_percent / 100
        * progress.confirmed_percent / 100
    ), 2)
    from public.v1_accounts_billing_progress progress
    join public.v1_accounts_baseline_revisions baseline
      on baseline.id = progress.baseline_revision_id
    join public.v1_accounts_baseline_building_allocations building
      on building.id = progress.building_allocation_id
    join public.v1_accounts_baseline_stage_allocations stage
      on stage.id = progress.stage_allocation_id
    where progress.baseline_revision_id =
      '39932000-0000-4000-8000-000000000002'
  ),
  1719200.00::numeric,
  'Current confirmed eligible value is exactly AED 1,719,200.00'
);

select is(
  (
    select count(*)
    from public.v1_accounts_billing_progress_revisions revision
    where revision.baseline_revision_id =
      '39932000-0000-4000-8000-000000000002'
      and revision.source_import_id =
        '39933000-0000-4000-8000-000000000001'
  ),
  4::bigint,
  'Every reapplied confirmation has an append-only source-linked revision'
);

select is(
  (
    select count(*)
    from public.v1_audit_events audit
    where audit.project_id = '39930000-0000-4000-8000-000000000001'
      and audit.idempotency_key = any(array[
        '32200000-0000-4000-8000-000000000200'::uuid,
        '32200000-0000-4000-8000-000000000201'::uuid,
        '32200000-0000-4000-8000-000000000202'::uuid,
        '32200000-0000-4000-8000-000000000203'::uuid,
        '32200000-0000-4000-8000-000000000204'::uuid
      ])
  ),
  5::bigint,
  'Four progress events and one source reconciliation event are audited'
);

insert into v1_yra322_reconciliation_results (result_key, payload)
values (
  'replayed',
  public.v1_accounts_reconcile_yra322_source_progress()
);

select is(
  (
    select payload ->> 'status'
    from v1_yra322_reconciliation_results
    where result_key = 'replayed'
  ),
  'already_reconciled',
  'A replay returns the existing exact result'
);

select ok(
  (
    select count(*)
    from public.v1_accounts_billing_progress_revisions revision
    where revision.baseline_revision_id =
      '39932000-0000-4000-8000-000000000002'
      and revision.source_import_id =
        '39933000-0000-4000-8000-000000000001'
  ) = 4
  and (
    select count(*)
    from public.v1_audit_events audit
    where audit.project_id = '39930000-0000-4000-8000-000000000001'
      and audit.idempotency_key = any(array[
        '32200000-0000-4000-8000-000000000200'::uuid,
        '32200000-0000-4000-8000-000000000201'::uuid,
        '32200000-0000-4000-8000-000000000202'::uuid,
        '32200000-0000-4000-8000-000000000203'::uuid,
        '32200000-0000-4000-8000-000000000204'::uuid
      ])
  ) = 5,
  'A replay cannot duplicate revisions or audit events'
);

select * from finish();
rollback;
