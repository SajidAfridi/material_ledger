-- Yorks R39 Accounts: source-grounded YRA-322 master-workbook import.
--
-- This migration records the immutable workbook reconciliation before applying
-- only facts supported by the workbook. It does not manufacture a claim,
-- invoice, certification, PDC or payment from zero-value placeholders.

create table if not exists public.v1_accounts_source_imports (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  source_type text not null check (source_type = 'excel_project_master'),
  original_file_name text not null check (btrim(original_file_name) <> ''),
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  source_byte_size bigint not null check (source_byte_size > 0),
  source_snapshot jsonb not null check (jsonb_typeof(source_snapshot) = 'object'),
  excluded_snapshot jsonb not null check (jsonb_typeof(excluded_snapshot) = 'object'),
  application_summary jsonb not null check (jsonb_typeof(application_summary) = 'object'),
  imported_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  imported_by_exact_role text not null check (imported_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  imported_at timestamptz not null default clock_timestamp(),
  unique (project_id, source_sha256)
);

alter table public.v1_accounts_source_imports enable row level security;
revoke all on table public.v1_accounts_source_imports
  from public, anon, authenticated;
grant select on table public.v1_accounts_source_imports to service_role;

drop trigger if exists v1_accounts_source_imports_append_only
  on public.v1_accounts_source_imports;
create trigger v1_accounts_source_imports_append_only
before update or delete on public.v1_accounts_source_imports
for each row execute function public.v1_accounts_append_only_guard();

alter table public.v1_accounts_billing_progress
  add column if not exists confirmed_source_import_id uuid
    references public.v1_accounts_source_imports (id) on delete restrict;

alter table public.v1_accounts_billing_progress_revisions
  add column if not exists source_import_id uuid
    references public.v1_accounts_source_imports (id) on delete restrict;

comment on table public.v1_accounts_source_imports is
  'Immutable source reconciliation for approved historical Accounts imports. The source snapshot stores extracted facts and workbook cell provenance; excluded_snapshot records ambiguous or zero-value facts that were deliberately not posted.';
comment on column public.v1_accounts_billing_progress.confirmed_source_import_id is
  'Immutable source reconciliation used when an approved historical import, rather than a controlled document upload, established the current confirmed value. Normal commands continue to enforce evidence on increases while allowing controlled decreases.';
comment on column public.v1_accounts_billing_progress_revisions.source_import_id is
  'Historical source reconciliation for this exact confirmed-progress revision.';

do $$
declare
  v_project_id uuid;
  v_baseline_id uuid;
  v_actor_id uuid;
  v_actor_exact_role text;
  v_source_import_id uuid;
  v_source_snapshot jsonb := jsonb_build_object(
    'workbook_project_ref', 'YRA-322',
    'contract_reference', 'N-19957.2',
    'contract_value_aed', '17192000.00',
    'source_sheet', 'Summery (Option)',
    'source_cells', jsonb_build_object(
      'project_ref', 'K2',
      'contract_value', 'F52',
      'overall_progress_percent', 'W58',
      'overall_progress_value', 'X58',
      'invoice_reference', 'H60',
      'invoice_amount_ex_vat', 'H61',
      'invoice_submission_date', 'H62',
      'invoice_approved_date', 'H63',
      'invoice_due_date', 'H64',
      'invoice_paid_date', 'H65'
    ),
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
  );
  v_excluded_snapshot jsonb := jsonb_build_object(
    'project_details_sheet', jsonb_build_object(
      'result', 'excluded_conflicting_copy',
      'reported_project_ref', 'YRA-315',
      'reason', 'The dominant commercial sheets identify YRA-322 and N-19957.2.'
    ),
    'contract_reference_cell_d2', jsonb_build_object(
      'reported_value', 'N-1957.2',
      'result', 'normalized_from_dominant_workbook_references',
      'normalized_value', 'N-19957.2'
    ),
    'invoice_placeholder', jsonb_build_object(
      'reference', 'YRA32201',
      'amount_ex_vat_aed', '0.00',
      'submission_date', '2026-01-19',
      'approved_date', null,
      'due_date', null,
      'paid_date', null,
      'result', 'excluded_zero_value_no_receivable_transaction'
    ),
    'future_invoice_placeholders', jsonb_build_array('YRA3220X', 'YRA3220X', 'YRA3220X', 'YRA3220X'),
    'pdc_note', jsonb_build_object(
      'text', '45 days PDC',
      'result', 'excluded_policy_note_without_instrument_or amount'
    ),
    'certification_and_payments', jsonb_build_object(
      'certified_aed', '0.00',
      'paid_aed', '0.00',
      'result', 'no_records_created'
    ),
    'material_and_installation_progress', jsonb_build_object(
      'material_supply_percent', '0.0000',
      'installation_percent', '0.0000',
      'result', 'preserved_as_zero'
    ),
    'date_header_anomaly', jsonb_build_object(
      'cell', 'H5',
      'value', '2026-01-02',
      'other_building_first_period', '2025-02-01',
      'result', 'not_used_as_historical_confirmation_timestamp'
    )
  );
  v_fact jsonb;
  v_progress public.v1_accounts_billing_progress%rowtype;
  v_revision_number integer;
  v_idempotency_key uuid;
  v_existing_source public.v1_accounts_source_imports%rowtype;
begin
  select project.id into v_project_id
  from public.v1_projects project
  where project.project_ref = 'YRA-322';

  -- Development/test databases without the production project retain only the
  -- reusable schema. Production applies the guarded reconciliation below.
  if v_project_id is null then
    return;
  end if;

  select profile.current_baseline_revision_id,
         baseline.approved_by_auth_user_id,
         actor.canonical_role_snapshot
  into v_baseline_id, v_actor_id, v_actor_exact_role
  from public.v1_accounts_project_commercial_profiles profile
  join public.v1_accounts_baseline_revisions baseline
    on baseline.id = profile.current_baseline_revision_id
   and baseline.status = 'current'
  join public.v1_profiles actor
    on actor.auth_user_id = baseline.approved_by_auth_user_id
   and actor.is_active
  where profile.project_id = v_project_id
    and profile.status = 'active';

  if v_baseline_id is null or v_actor_exact_role <> 'admin' then
    raise exception 'R39_ACCOUNTS_YRA322_BASELINE_OR_ACTOR_INVALID'
      using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.v1_accounts_baseline_revisions baseline
    where baseline.id = v_baseline_id
      and baseline.contract_value = 17192000.00
      and baseline.currency_code = 'AED'
  ) or (
    select count(*) = 4 and sum(allocation.allocation_percent) = 100
      and bool_and(allocation.allocation_percent = 25)
    from public.v1_accounts_baseline_building_allocations allocation
    where allocation.baseline_revision_id = v_baseline_id
  ) is not true or (
    select count(*) = 5 and sum(stage.allocation_percent) = 100
      and bool_and(
        (stage.stage_key = 'design' and stage.allocation_percent = 10)
        or (stage.stage_key = 'material_supply' and stage.allocation_percent = 50)
        or (stage.stage_key = 'installation' and stage.allocation_percent = 30)
        or (stage.stage_key = 'commissioning_handover' and stage.allocation_percent = 5)
        or (stage.stage_key = 'energizing' and stage.allocation_percent = 5)
      )
    from public.v1_accounts_baseline_stage_allocations stage
    where stage.baseline_revision_id = v_baseline_id
  ) is not true then
    raise exception 'R39_ACCOUNTS_YRA322_BASELINE_MISMATCH'
      using errcode = '23514';
  end if;

  insert into public.v1_accounts_source_imports (
    project_id, source_type, original_file_name, source_sha256,
    source_byte_size, source_snapshot, excluded_snapshot,
    application_summary, imported_by_auth_user_id, imported_by_exact_role
  ) values (
    v_project_id, 'excel_project_master',
    'Project Master File - Nexus 4 Station.xlsx',
    '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c',
    1961340, v_source_snapshot, v_excluded_snapshot,
    jsonb_build_object(
      'baseline_action', 'verified_existing',
      'progress_rows_confirmed', 4,
      'claims_created', 0,
      'invoices_created', 0,
      'certifications_created', 0,
      'pdcs_created', 0,
      'payments_created', 0
    ),
    v_actor_id, v_actor_exact_role
  )
  on conflict (project_id, source_sha256) do nothing
  returning id into v_source_import_id;

  if v_source_import_id is null then
    select * into v_existing_source
    from public.v1_accounts_source_imports source_import
    where source_import.project_id = v_project_id
      and source_import.source_sha256 = '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c';
    if v_existing_source.source_snapshot <> v_source_snapshot
      or v_existing_source.excluded_snapshot <> v_excluded_snapshot then
      raise exception 'R39_ACCOUNTS_YRA322_SOURCE_HASH_CONFLICT'
        using errcode = '23505';
    end if;
    v_source_import_id := v_existing_source.id;
  end if;

  for v_fact in
    select value from jsonb_array_elements(v_source_snapshot->'confirmed_progress')
  loop
    select progress.* into v_progress
    from public.v1_accounts_billing_progress progress
    join public.v1_project_scopes scope
      on scope.id = progress.project_scope_id
    where progress.project_id = v_project_id
      and progress.baseline_revision_id = v_baseline_id
      and scope.scope_code = v_fact->>'scope_code'
      and progress.stage_key = v_fact->>'stage_key'
    for update of progress;

    if not found then
      raise exception 'R39_ACCOUNTS_YRA322_PROGRESS_ROW_MISSING: %/%',
        v_fact->>'scope_code', v_fact->>'stage_key'
        using errcode = 'P0002';
    end if;
    if v_progress.suggested_percent <> (v_fact->>'stage_percent')::numeric then
      raise exception 'R39_ACCOUNTS_YRA322_SUGGESTED_PROGRESS_MISMATCH: %/%',
        v_fact->>'scope_code', v_fact->>'stage_key'
        using errcode = '23514';
    end if;
    if v_progress.confirmed_percent = (v_fact->>'stage_percent')::numeric
      and v_progress.confirmed_source_import_id = v_source_import_id then
      continue;
    end if;
    if v_progress.confirmed_percent <> 0 then
      raise exception 'R39_ACCOUNTS_YRA322_EXISTING_CONFIRMATION_CONFLICT: %/%',
        v_fact->>'scope_code', v_fact->>'stage_key'
        using errcode = '40001';
    end if;

    v_idempotency_key := case v_fact->>'scope_code'
      when 'a-df3w' then '32200000-0000-4000-8000-000000000101'::uuid
      when 'b-df4w' then '32200000-0000-4000-8000-000000000102'::uuid
      when 'c-df6w' then '32200000-0000-4000-8000-000000000103'::uuid
      when 'd-df7w' then '32200000-0000-4000-8000-000000000104'::uuid
    end;
    select coalesce(max(revision.revision_number), 0) + 1
    into v_revision_number
    from public.v1_accounts_billing_progress_revisions revision
    where revision.progress_entry_id = v_progress.id;

    update public.v1_accounts_billing_progress
    set confirmed_percent = (v_fact->>'stage_percent')::numeric,
        confirmed_evidence_summary = concat(
          'Approved historical master-workbook import ',
          '(Summery (Option) cells ',
          array_to_string(array(select jsonb_array_elements_text(v_fact->'cells')), ', '),
          '; SHA-256 ', left('1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c', 12),
          '…).'
        ),
        confirmed_evidence_document_ids = '{}',
        confirmed_source_import_id = v_source_import_id,
        confirmed_by_auth_user_id = v_actor_id,
        confirmed_by_exact_role = v_actor_exact_role,
        confirmed_at = clock_timestamp(),
        review_status = 'not_required',
        reviewed_by_auth_user_id = null,
        reviewed_by_exact_role = null,
        reviewed_at = null,
        review_reason = null,
        record_version = record_version + 1,
        updated_at = clock_timestamp()
    where id = v_progress.id;

    insert into public.v1_accounts_billing_progress_revisions (
      project_id, progress_entry_id, baseline_revision_id, revision_number,
      action, previous_suggested_percent, new_suggested_percent,
      previous_confirmed_percent, new_confirmed_percent,
      previous_review_status, new_review_status, evidence_summary,
      evidence_document_ids, reason, actor_auth_user_id, actor_role,
      actor_exact_role, idempotency_key, occurred_at, source_import_id
    ) values (
      v_project_id, v_progress.id, v_baseline_id, v_revision_number,
      'confirmed', v_progress.suggested_percent, v_progress.suggested_percent,
      v_progress.confirmed_percent, (v_fact->>'stage_percent')::numeric,
      v_progress.review_status, 'not_required',
      'Source-grounded YRA-322 project master-workbook reconciliation.',
      '{}', 'Approved historical import; only non-zero workbook progress applied.',
      v_actor_id, 'admin', v_actor_exact_role, v_idempotency_key,
      greatest(
        clock_timestamp(),
        coalesce((
          select max(revision.occurred_at) + interval '1 microsecond'
          from public.v1_accounts_billing_progress_revisions revision
          where revision.progress_entry_id = v_progress.id
        ), '-infinity'::timestamptz)
      ),
      v_source_import_id
    );

    insert into public.v1_audit_events (
      event_type, entity_type, entity_id, project_id, actor_auth_user_id,
      actor_role, actor_exact_role, occurred_at, idempotency_key,
      before_data, after_data, reason, request_hash
    ) values (
      'accounts.progress.imported', 'accounts_progress', v_progress.id,
      v_project_id, v_actor_id, 'admin', v_actor_exact_role,
      clock_timestamp(), v_idempotency_key,
      jsonb_build_object(
        'record_version', v_progress.record_version,
        'confirmed_percent', v_progress.confirmed_percent::text
      ),
      jsonb_build_object(
        'record_version', v_progress.record_version + 1,
        'confirmed_percent', v_fact->>'stage_percent',
        'confirmed_value_aed', v_fact->>'value_aed',
        'source_import_id', v_source_import_id,
        'source_sha256', '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c',
        'source_cells', v_fact->'cells'
      ),
      'Approved YRA-322 historical project master-workbook import.',
      encode(digest(v_source_snapshot::text, 'sha256'), 'hex')
    )
    on conflict (actor_auth_user_id, idempotency_key, event_type) do nothing;
  end loop;

  insert into public.v1_audit_events (
    event_type, entity_type, entity_id, project_id, actor_auth_user_id,
    actor_role, actor_exact_role, occurred_at, idempotency_key,
    after_data, reason, request_hash
  ) values (
    'accounts.source_import.applied', 'accounts_source_import',
    v_source_import_id, v_project_id, v_actor_id, 'admin', v_actor_exact_role,
    clock_timestamp(), '32200000-0000-4000-8000-000000000100'::uuid,
    jsonb_build_object(
      'source_import_id', v_source_import_id,
      'original_file_name', 'Project Master File - Nexus 4 Station.xlsx',
      'source_sha256', '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c',
      'confirmed_progress_percent', '10.0000',
      'confirmed_progress_value_aed', '1719200.00',
      'excluded_zero_value_transactions', jsonb_build_array(
        'claim', 'invoice', 'certification', 'pdc', 'payment'
      )
    ),
    'Source-grounded import completed without manufacturing excluded facts.',
    encode(digest(v_source_snapshot::text, 'sha256'), 'hex')
  )
  on conflict (actor_auth_user_id, idempotency_key, event_type) do nothing;
end;
$$;
