-- Yorks R39 Accounts: reconcile the immutable YRA-322 workbook confirmation
-- onto the active commercial baseline after an equivalent dimension revision.
--
-- Baseline revisions intentionally materialize a fresh progress grid. Revision
-- 2 changed the management-review policy but retained the source-relevant
-- contract, building and stage dimensions. This forward-only correction reuses
-- the already approved immutable source import; it never rewrites revision 1,
-- creates receivable/payable transactions, or touches technical project data.
--
-- Rollback is corrective: submit four new confirmed-progress revisions on the
-- active baseline, retain this source attribution and every audit event, and
-- record the approved correction reason. Never delete imported history.

begin;

create or replace function public.v1_accounts_reconcile_yra322_source_progress()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_profile public.v1_accounts_project_commercial_profiles%rowtype;
  v_current_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_source_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_source_import public.v1_accounts_source_imports%rowtype;
  v_source_baseline_id uuid;
  v_source_baseline_count integer;
  v_source_progress_count integer;
  v_source_scope_count integer;
  v_source_buildings jsonb;
  v_current_buildings jsonb;
  v_source_stages jsonb;
  v_current_stages jsonb;
  v_progress_count integer;
  v_progress_pristine boolean;
  v_exact_applied_count integer;
  v_non_target_dirty_count integer;
  v_fact jsonb;
  v_progress public.v1_accounts_billing_progress%rowtype;
  v_revision_number integer;
  v_idempotency_key uuid;
  v_evidence_summary text;
  v_applied_at timestamptz := clock_timestamp();
  v_applied_count integer := 0;
  v_confirmed_value numeric(20,2);
  v_confirmed_percent numeric(12,4);
begin
  select project.id
  into v_project_id
  from public.v1_projects project
  where project.project_ref = 'YRA-322';

  -- Fresh development databases intentionally have no production project.
  if v_project_id is null then
    return jsonb_build_object(
      'status', 'not_applicable',
      'reason', 'YRA-322 project is absent'
    );
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_yra322_source_reconcile|' || v_project_id::text,
      0
    )
  );

  select profile.*
  into v_profile
  from public.v1_accounts_project_commercial_profiles profile
  where profile.project_id = v_project_id
    and profile.status = 'active'
  for update;

  if not found or v_profile.current_baseline_revision_id is null then
    raise exception 'R39_ACCOUNTS_YRA322_CURRENT_BASELINE_MISSING'
      using errcode = 'P0002';
  end if;

  select baseline.*
  into v_current_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_profile.current_baseline_revision_id
    and baseline.project_id = v_project_id
    and baseline.status = 'current'
  for update;

  if not found then
    raise exception 'R39_ACCOUNTS_YRA322_CURRENT_BASELINE_INVALID'
      using errcode = '23514';
  end if;

  select source_import.*
  into v_source_import
  from public.v1_accounts_source_imports source_import
  where source_import.project_id = v_project_id
    and source_import.source_sha256 =
      '1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c';

  if not found
    or v_source_import.source_type <> 'excel_project_master'
    or v_source_import.original_file_name <>
      'Project Master File - Nexus 4 Station.xlsx'
    or v_source_import.source_byte_size <> 1961340
    or v_source_import.imported_by_exact_role <> 'admin'
    or v_source_import.source_snapshot ->> 'workbook_project_ref' <> 'YRA-322'
    or v_source_import.source_snapshot ->> 'contract_reference' <> 'N-19957.2'
    or v_source_import.source_snapshot ->> 'contract_value_aed' <> '17192000.00'
    or v_source_import.source_snapshot ->> 'overall_confirmed_percent' <> '10.0000'
    or v_source_import.source_snapshot ->> 'overall_confirmed_value_aed' <> '1719200.00'
    or coalesce(jsonb_array_length(
      v_source_import.source_snapshot -> 'confirmed_progress'
    ), -1) <> 4
    or v_source_import.excluded_snapshot #>>
      '{project_details_sheet,result}' <> 'excluded_conflicting_copy'
  then
    raise exception 'R39_ACCOUNTS_YRA322_SOURCE_IMPORT_INVALID'
      using errcode = '23514';
  end if;

  select
    (array_agg(distinct progress.baseline_revision_id))[1],
    count(distinct progress.baseline_revision_id),
    count(*),
    count(distinct scope.scope_code)
  into
    v_source_baseline_id,
    v_source_baseline_count,
    v_source_progress_count,
    v_source_scope_count
  from public.v1_accounts_billing_progress progress
  join public.v1_project_scopes scope
    on scope.id = progress.project_scope_id
  join public.v1_accounts_baseline_revisions baseline
    on baseline.id = progress.baseline_revision_id
   and baseline.status = 'superseded'
  where progress.project_id = v_project_id
    and progress.confirmed_source_import_id = v_source_import.id
    and progress.stage_key = 'design'
    and progress.confirmed_percent = 100.0000
    and progress.suggested_percent = 100.0000
    and scope.scope_code = any(array[
      'a-df3w', 'b-df4w', 'c-df6w', 'd-df7w'
    ]::text[]);

  if v_source_baseline_count <> 1
    or v_source_progress_count <> 4
    or v_source_scope_count <> 4
    or (
      select count(*)
      from public.v1_accounts_billing_progress progress
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = progress.baseline_revision_id
       and baseline.status = 'superseded'
      where progress.project_id = v_project_id
        and progress.confirmed_source_import_id = v_source_import.id
    ) <> 4
  then
    raise exception 'R39_ACCOUNTS_YRA322_SOURCE_PROGRESS_INVALID'
      using errcode = '23514';
  end if;

  select baseline.*
  into v_source_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_source_baseline_id
    and baseline.project_id = v_project_id
    and baseline.status = 'superseded';

  if not found
    or v_source_baseline.revision_number <> 1
    or v_current_baseline.revision_number <> 2
    or v_current_baseline.revision_number <>
      v_source_baseline.revision_number + 1
    or v_current_baseline.contract_value <> v_source_baseline.contract_value
    or v_current_baseline.currency_code <> v_source_baseline.currency_code
    or v_current_baseline.vat_rate_percent <>
      v_source_baseline.vat_rate_percent
    or v_current_baseline.payment_terms_days <>
      v_source_baseline.payment_terms_days
    or v_current_baseline.reminder_lead_days <>
      v_source_baseline.reminder_lead_days
    or v_current_baseline.contract_value <> 17192000.00
    or v_current_baseline.currency_code <> 'AED'
  then
    raise exception 'R39_ACCOUNTS_YRA322_BASELINE_VALUE_MISMATCH'
      using errcode = '23514';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'scope_code', scope.scope_code,
    'percent', allocation.allocation_percent::text
  ) order by scope.scope_code), '[]'::jsonb)
  into v_source_buildings
  from public.v1_accounts_baseline_building_allocations allocation
  join public.v1_project_scopes scope
    on scope.id = allocation.project_scope_id
  where allocation.baseline_revision_id = v_source_baseline.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'scope_code', scope.scope_code,
    'percent', allocation.allocation_percent::text
  ) order by scope.scope_code), '[]'::jsonb)
  into v_current_buildings
  from public.v1_accounts_baseline_building_allocations allocation
  join public.v1_project_scopes scope
    on scope.id = allocation.project_scope_id
  where allocation.baseline_revision_id = v_current_baseline.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'stage_key', allocation.stage_key,
    'percent', allocation.allocation_percent::text
  ) order by allocation.display_order), '[]'::jsonb)
  into v_source_stages
  from public.v1_accounts_baseline_stage_allocations allocation
  where allocation.baseline_revision_id = v_source_baseline.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'stage_key', allocation.stage_key,
    'percent', allocation.allocation_percent::text
  ) order by allocation.display_order), '[]'::jsonb)
  into v_current_stages
  from public.v1_accounts_baseline_stage_allocations allocation
  where allocation.baseline_revision_id = v_current_baseline.id;

  if v_source_buildings <> v_current_buildings
    or v_source_buildings <>
      v_source_import.source_snapshot -> 'building_allocations'
    or v_source_stages <> v_current_stages
    or v_source_stages <> v_source_import.source_snapshot -> 'stage_allocations'
  then
    raise exception 'R39_ACCOUNTS_YRA322_BASELINE_DIMENSION_MISMATCH'
      using errcode = '23514';
  end if;

  if exists (
    select 1 from public.v1_accounts_client_claims row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_client_invoices row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_client_certifications row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_client_payments row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_client_pdcs row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_client_pdc_events row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_supplier_bills row
    where row.project_id = v_project_id
    union all
    select 1 from public.v1_accounts_supplier_payments row
    where row.project_id = v_project_id
  ) then
    raise exception 'R39_ACCOUNTS_YRA322_TRANSACTION_CONFLICT'
      using errcode = '40001';
  end if;

  -- Lock the complete current grid in a stable order before inspecting or
  -- updating any individual row.
  perform progress.id
  from public.v1_accounts_billing_progress progress
  where progress.project_id = v_project_id
    and progress.baseline_revision_id = v_current_baseline.id
  order by progress.id
  for update;

  select
    count(*),
    count(*) filter (where
      progress.stage_key = 'design'
      and scope.scope_code = any(array[
        'a-df3w', 'b-df4w', 'c-df6w', 'd-df7w'
      ]::text[])
      and progress.suggested_percent = 0
      and progress.confirmed_percent = 100.0000
      and progress.confirmed_source_import_id = v_source_import.id
      and progress.record_version = 2
    ),
    count(*) filter (where
      not (
        progress.stage_key = 'design'
        and scope.scope_code = any(array[
          'a-df3w', 'b-df4w', 'c-df6w', 'd-df7w'
        ]::text[])
      )
      and (
        progress.suggested_percent <> 0
        or progress.confirmed_percent <> 0
        or progress.confirmed_source_import_id is not null
        or progress.record_version <> 1
      )
    )
  into v_progress_count, v_exact_applied_count, v_non_target_dirty_count
  from public.v1_accounts_billing_progress progress
  join public.v1_project_scopes scope
    on scope.id = progress.project_scope_id
  where progress.project_id = v_project_id
    and progress.baseline_revision_id = v_current_baseline.id;

  if v_progress_count = 20
    and v_exact_applied_count = 4
    and v_non_target_dirty_count = 0
    and (
      select count(*) = 4
      from public.v1_accounts_billing_progress_revisions revision
      where revision.project_id = v_project_id
        and revision.baseline_revision_id = v_current_baseline.id
        and revision.source_import_id = v_source_import.id
    )
    and exists (
      select 1
      from public.v1_audit_events audit
      where audit.project_id = v_project_id
        and audit.actor_auth_user_id =
          v_source_import.imported_by_auth_user_id
        and audit.event_type = 'accounts.source_import.applied'
        and audit.idempotency_key =
          '32200000-0000-4000-8000-000000000200'::uuid
    )
  then
    return jsonb_build_object(
      'status', 'already_reconciled',
      'project_id', v_project_id,
      'baseline_revision_id', v_current_baseline.id,
      'baseline_revision_number', v_current_baseline.revision_number,
      'source_import_id', v_source_import.id,
      'progress_rows_confirmed', 4,
      'confirmed_progress_percent', '10.0000',
      'confirmed_progress_value_aed', '1719200.00'
    );
  end if;

  select count(*), coalesce(bool_and(
    progress.suggested_percent = 0
    and progress.suggested_evidence_summary is null
    and cardinality(progress.suggested_evidence_document_ids) = 0
    and progress.suggested_by_auth_user_id is null
    and progress.suggested_by_exact_role is null
    and progress.suggested_at is null
    and progress.confirmed_percent = 0
    and progress.confirmed_evidence_summary is null
    and cardinality(progress.confirmed_evidence_document_ids) = 0
    and progress.confirmed_source_import_id is null
    and progress.confirmed_by_auth_user_id is null
    and progress.confirmed_by_exact_role is null
    and progress.confirmed_at is null
    and progress.review_status = 'not_required'
    and progress.reviewed_by_auth_user_id is null
    and progress.reviewed_by_exact_role is null
    and progress.reviewed_at is null
    and progress.review_reason is null
    and progress.record_version = 1
    and not exists (
      select 1
      from public.v1_accounts_billing_progress_revisions revision
      where revision.progress_entry_id = progress.id
    )
  ), false)
  into v_progress_count, v_progress_pristine
  from public.v1_accounts_billing_progress progress
  where progress.project_id = v_project_id
    and progress.baseline_revision_id = v_current_baseline.id;

  if v_progress_count <> 20 or not v_progress_pristine then
    raise exception 'R39_ACCOUNTS_YRA322_CURRENT_PROGRESS_CONFLICT'
      using errcode = '40001';
  end if;

  if exists (
    select 1
    from public.v1_audit_events audit
    where audit.actor_auth_user_id = v_source_import.imported_by_auth_user_id
      and (
        audit.event_type = 'accounts.source_import.applied'
        and audit.idempotency_key =
          '32200000-0000-4000-8000-000000000200'::uuid
        or audit.event_type = 'accounts.progress.imported'
        and audit.idempotency_key = any(array[
          '32200000-0000-4000-8000-000000000201'::uuid,
          '32200000-0000-4000-8000-000000000202'::uuid,
          '32200000-0000-4000-8000-000000000203'::uuid,
          '32200000-0000-4000-8000-000000000204'::uuid
        ])
      )
  ) then
    raise exception 'R39_ACCOUNTS_YRA322_RECONCILIATION_KEY_CONFLICT'
      using errcode = '23505';
  end if;

  for v_fact in
    select fact.value
    from jsonb_array_elements(
      v_source_import.source_snapshot -> 'confirmed_progress'
    ) fact(value)
    order by fact.value ->> 'scope_code'
  loop
    select progress.*
    into v_progress
    from public.v1_accounts_billing_progress progress
    join public.v1_project_scopes scope
      on scope.id = progress.project_scope_id
    where progress.project_id = v_project_id
      and progress.baseline_revision_id = v_current_baseline.id
      and scope.scope_code = v_fact ->> 'scope_code'
      and progress.stage_key = v_fact ->> 'stage_key';

    if not found then
      raise exception 'R39_ACCOUNTS_YRA322_PROGRESS_ROW_MISSING: %/%',
        v_fact ->> 'scope_code', v_fact ->> 'stage_key'
        using errcode = 'P0002';
    end if;

    if round(
      public.v1_accounts_stage_value(v_progress.id)
        * (v_fact ->> 'stage_percent')::numeric / 100,
      2
    ) <> (v_fact ->> 'value_aed')::numeric
    then
      raise exception 'R39_ACCOUNTS_YRA322_PROGRESS_VALUE_MISMATCH: %/%',
        v_fact ->> 'scope_code', v_fact ->> 'stage_key'
        using errcode = '23514';
    end if;

    if public.v1_accounts_review_required(
      v_current_baseline.management_review_policy,
      (v_fact ->> 'value_aed')::numeric,
      v_source_import.imported_by_exact_role
    ) then
      raise exception 'R39_ACCOUNTS_YRA322_REVIEW_POLICY_CONFLICT'
        using errcode = '23514';
    end if;

    v_idempotency_key := case v_fact ->> 'scope_code'
      when 'a-df3w' then
        '32200000-0000-4000-8000-000000000201'::uuid
      when 'b-df4w' then
        '32200000-0000-4000-8000-000000000202'::uuid
      when 'c-df6w' then
        '32200000-0000-4000-8000-000000000203'::uuid
      when 'd-df7w' then
        '32200000-0000-4000-8000-000000000204'::uuid
      else null
    end;

    if v_idempotency_key is null then
      raise exception 'R39_ACCOUNTS_YRA322_SOURCE_SCOPE_INVALID'
        using errcode = '23514';
    end if;

    v_evidence_summary := concat(
      'Reapplied approved historical master-workbook confirmation to ',
      'equivalent active baseline revision 2 (Summery (Option) cells ',
      array_to_string(array(
        select jsonb_array_elements_text(v_fact -> 'cells')
      ), ', '),
      '; SHA-256 ', left(v_source_import.source_sha256, 12), '…).'
    );

    select coalesce(max(revision.revision_number), 0) + 1
    into v_revision_number
    from public.v1_accounts_billing_progress_revisions revision
    where revision.progress_entry_id = v_progress.id;

    update public.v1_accounts_billing_progress
    set confirmed_percent = (v_fact ->> 'stage_percent')::numeric,
        confirmed_evidence_summary = v_evidence_summary,
        confirmed_evidence_document_ids = '{}',
        confirmed_source_import_id = v_source_import.id,
        confirmed_by_auth_user_id =
          v_source_import.imported_by_auth_user_id,
        confirmed_by_exact_role = v_source_import.imported_by_exact_role,
        confirmed_at = v_applied_at,
        review_status = 'not_required',
        reviewed_by_auth_user_id = null,
        reviewed_by_exact_role = null,
        reviewed_at = null,
        review_reason = null,
        record_version = record_version + 1,
        updated_at = v_applied_at
    where id = v_progress.id;

    insert into public.v1_accounts_billing_progress_revisions (
      project_id, progress_entry_id, baseline_revision_id, revision_number,
      action, previous_suggested_percent, new_suggested_percent,
      previous_confirmed_percent, new_confirmed_percent,
      previous_review_status, new_review_status, evidence_summary,
      evidence_document_ids, reason, actor_auth_user_id, actor_role,
      actor_exact_role, idempotency_key, occurred_at, source_import_id
    ) values (
      v_project_id, v_progress.id, v_current_baseline.id, v_revision_number,
      'confirmed', 0, 0, 0, (v_fact ->> 'stage_percent')::numeric,
      'not_required', 'not_required', v_evidence_summary, '{}',
      'Previously approved immutable YRA-322 source fact reconciled to '
        || 'equivalent active baseline revision 2.',
      v_source_import.imported_by_auth_user_id,
      public.v1_canonical_role_from_exact_role(
        v_source_import.imported_by_exact_role
      ),
      v_source_import.imported_by_exact_role, v_idempotency_key,
      v_applied_at + (v_applied_count * interval '1 microsecond'),
      v_source_import.id
    );

    insert into public.v1_audit_events (
      event_type, entity_type, entity_id, project_id, actor_auth_user_id,
      actor_role, actor_exact_role, occurred_at, idempotency_key,
      before_data, after_data, reason, request_hash
    ) values (
      'accounts.progress.imported', 'accounts_progress', v_progress.id,
      v_project_id, v_source_import.imported_by_auth_user_id,
      public.v1_canonical_role_from_exact_role(
        v_source_import.imported_by_exact_role
      ),
      v_source_import.imported_by_exact_role,
      v_applied_at + (v_applied_count * interval '1 microsecond'),
      v_idempotency_key,
      jsonb_build_object(
        'baseline_revision_id', v_source_baseline.id,
        'record_version', v_progress.record_version,
        'confirmed_percent', v_progress.confirmed_percent::text
      ),
      jsonb_build_object(
        'baseline_revision_id', v_current_baseline.id,
        'baseline_revision_number', v_current_baseline.revision_number,
        'record_version', v_progress.record_version + 1,
        'confirmed_percent', v_fact ->> 'stage_percent',
        'confirmed_value_aed', v_fact ->> 'value_aed',
        'source_import_id', v_source_import.id,
        'source_sha256', v_source_import.source_sha256,
        'source_cells', v_fact -> 'cells',
        'reapplied', true
      ),
      'Equivalent-baseline source reconciliation; no transaction was inferred.',
      encode(extensions.digest(
        v_source_import.source_snapshot::text
          || '|' || v_current_baseline.id::text,
        'sha256'
      ), 'hex')
    );

    v_applied_count := v_applied_count + 1;
  end loop;

  if v_applied_count <> 4 then
    raise exception 'R39_ACCOUNTS_YRA322_RECONCILIATION_COUNT_INVALID'
      using errcode = '23514';
  end if;

  select
    round(sum(
      v_current_baseline.contract_value
        * building.allocation_percent / 100
        * stage.allocation_percent / 100
        * progress.confirmed_percent / 100
    ), 2),
    round(sum(
      building.allocation_percent
        * stage.allocation_percent
        * progress.confirmed_percent / 10000
    ), 4)
  into v_confirmed_value, v_confirmed_percent
  from public.v1_accounts_billing_progress progress
  join public.v1_accounts_baseline_building_allocations building
    on building.id = progress.building_allocation_id
  join public.v1_accounts_baseline_stage_allocations stage
    on stage.id = progress.stage_allocation_id
  where progress.project_id = v_project_id
    and progress.baseline_revision_id = v_current_baseline.id;

  if v_confirmed_value <> 1719200.00
    or v_confirmed_percent <> 10.0000
  then
    raise exception 'R39_ACCOUNTS_YRA322_RECONCILIATION_TOTAL_INVALID'
      using errcode = '23514';
  end if;

  insert into public.v1_audit_events (
    event_type, entity_type, entity_id, project_id, actor_auth_user_id,
    actor_role, actor_exact_role, occurred_at, idempotency_key,
    before_data, after_data, reason, request_hash
  ) values (
    'accounts.source_import.applied', 'accounts_source_import',
    v_source_import.id, v_project_id,
    v_source_import.imported_by_auth_user_id,
    public.v1_canonical_role_from_exact_role(
      v_source_import.imported_by_exact_role
    ),
    v_source_import.imported_by_exact_role,
    v_applied_at + (v_applied_count * interval '1 microsecond'),
    '32200000-0000-4000-8000-000000000200'::uuid,
    jsonb_build_object(
      'baseline_revision_id', v_source_baseline.id,
      'baseline_revision_number', v_source_baseline.revision_number,
      'confirmed_progress_percent', '10.0000',
      'confirmed_progress_value_aed', '1719200.00'
    ),
    jsonb_build_object(
      'baseline_revision_id', v_current_baseline.id,
      'baseline_revision_number', v_current_baseline.revision_number,
      'source_import_id', v_source_import.id,
      'source_sha256', v_source_import.source_sha256,
      'confirmed_progress_percent', v_confirmed_percent::text,
      'confirmed_progress_value_aed', v_confirmed_value::text,
      'progress_rows_confirmed', v_applied_count,
      'reapplied', true,
      'transactions_created', 0
    ),
    'Immutable YRA-322 workbook progress reconciled to equivalent baseline '
      || 'revision 2 without creating receivable or payable facts.',
    encode(extensions.digest(
      v_source_import.source_snapshot::text
        || '|' || v_current_baseline.id::text,
      'sha256'
    ), 'hex')
  );

  return jsonb_build_object(
    'status', 'reconciled',
    'project_id', v_project_id,
    'baseline_revision_id', v_current_baseline.id,
    'baseline_revision_number', v_current_baseline.revision_number,
    'source_import_id', v_source_import.id,
    'progress_rows_confirmed', v_applied_count,
    'confirmed_progress_percent', v_confirmed_percent::text,
    'confirmed_progress_value_aed', v_confirmed_value::text,
    'transactions_created', 0
  );
end;
$$;

comment on function public.v1_accounts_reconcile_yra322_source_progress() is
  'Owner-only corrective seam for the guarded YRA-322 revision-1 to revision-2 immutable workbook progress reconciliation. It is not an application RPC.';

revoke all on function public.v1_accounts_reconcile_yra322_source_progress()
  from public, anon, authenticated, service_role;

select public.v1_accounts_reconcile_yra322_source_progress();

commit;
