-- Complete project Accounts exports for the overview Print / Excel actions.
--
-- This is a projection-only replacement. It does not mutate commercial facts.
-- Every detailed register remains behind export_accounts_registers plus its
-- existing commercial-value or supplier-cost capability. Direct table access
-- remains revoked and every generated register remains attributable in audit.

create or replace function public.v1_get_accounts_export(
  p_export_kind text,
  p_project_id uuid default null,
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_permission_exact_role(auth.uid());
  v_project public.v1_projects%rowtype;
  v_columns jsonb;
  v_rows jsonb;
  v_result jsonb;
  v_existing jsonb;
  v_payload jsonb;
begin
  if p_export_kind not in (
    'portfolio', 'project_summary', 'commercial_baseline',
    'building_allocations', 'stage_allocations', 'billing_progress',
    'progress_history', 'client_claims', 'claim_lines', 'client_invoices',
    'certifications', 'client_receipts', 'pdc_register', 'pdc_events',
    'supplier_bills', 'supplier_payments', 'accounts_documents',
    'accounts_activity'
  ) then
    raise exception 'R39_ACCOUNTS_EXPORT_KIND_INVALID' using errcode = '22023';
  end if;

  if p_export_kind = 'portfolio' then
    if v_role not in (
      'accountant', 'admin', 'senior_mechanical_engineer', 'project_manager'
    ) then
      raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
    end if;
  elsif p_project_id is null or not public.v1_current_user_has_capability(
    'export_accounts_registers', p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;

  if p_export_kind in (
    'project_summary', 'commercial_baseline', 'building_allocations',
    'stage_allocations', 'progress_history', 'client_claims', 'claim_lines',
    'client_invoices', 'certifications', 'client_receipts', 'pdc_register',
    'pdc_events', 'accounts_documents', 'accounts_activity'
  ) and not public.v1_current_user_has_capability(
    'view_project_commercial_values', p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;

  if p_export_kind in ('supplier_bills', 'supplier_payments')
    and not public.v1_current_user_has_capability(
      'view_supplier_costs', p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;

  v_payload := jsonb_build_object(
    'export_kind', p_export_kind,
    'project_id', p_project_id
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_get_accounts_export', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing;
  end if;

  if p_project_id is not null then
    select * into v_project
    from public.v1_projects
    where id = p_project_id;
    if not found then
      raise exception 'R39_ACCOUNTS_PROJECT_NOT_FOUND' using errcode = 'P0002';
    end if;
  end if;

  case p_export_kind
    when 'portfolio' then
      v_columns := '["Project","Client","Contract","Confirmed work","Claimed","Certified","Paid","Still due","Progress %"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        project.project_ref,
        coalesce(client.party_name, ''),
        baseline.contract_value::text,
        coalesce(progress.confirmed, 0)::text,
        coalesce(invoice.claimed, 0)::text,
        coalesce(invoice.certified, 0)::text,
        coalesce(invoice.paid, 0)::text,
        greatest(
          coalesce(invoice.certified, 0) - coalesce(invoice.paid, 0), 0
        )::text,
        coalesce(progress.percent, 0)::text
      ) order by project.project_ref), '[]'::jsonb)
      into v_rows
      from public.v1_projects project
      join public.v1_accounts_project_commercial_profiles profile
        on profile.project_id = project.id
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = profile.current_baseline_revision_id
      left join lateral (
        select party_name
        from public.v1_project_parties
        where project_id = project.id and party_kind = 'client'
        order by created_at, id
        limit 1
      ) client on true
      left join lateral (
        select
          coalesce(sum(round(
            baseline.contract_value * building.allocation_percent / 100
            * stage.allocation_percent / 100
            * progress_entry.confirmed_percent / 100, 2
          )), 0) confirmed,
          case
            when coalesce(sum(
              building.allocation_percent * stage.allocation_percent
            ), 0) = 0 then 0
            else round(sum(
              building.allocation_percent * stage.allocation_percent
              * progress_entry.confirmed_percent
            ) / sum(
              building.allocation_percent * stage.allocation_percent
            ), 2)
          end percent
        from public.v1_accounts_billing_progress progress_entry
        join public.v1_accounts_baseline_building_allocations building
          on building.id = progress_entry.building_allocation_id
        join public.v1_accounts_baseline_stage_allocations stage
          on stage.id = progress_entry.stage_allocation_id
        where progress_entry.project_id = project.id
          and progress_entry.review_status <> 'returned'
      ) progress on true
      left join lateral (
        select
          coalesce(sum(invoice_record.claimed_ex_vat), 0) claimed,
          coalesce(sum(
            public.v1_accounts_invoice_certified_incl_vat(invoice_record.id)
          ), 0) certified,
          coalesce(sum(
            public.v1_accounts_invoice_paid_amount(invoice_record.id)
          ), 0) paid
        from public.v1_accounts_client_invoices invoice_record
        where invoice_record.project_id = project.id
          and invoice_record.status <> 'cancelled'
      ) invoice on true
      where public.v1_current_user_has_capability(
        'export_accounts_registers', project.id
      ) and public.v1_current_user_has_capability(
        'view_project_commercial_values', project.id
      );

    when 'project_summary' then
      v_columns := '["Project Reference","Project Name","Site","Client","Contract Value","Confirmed Eligible","Available to Claim","Claimed","Certified","Paid","Still Due","Active PDC","Commercial Progress %"]'::jsonb;
      select jsonb_agg(jsonb_build_array(
        v_project.project_ref,
        v_project.name,
        v_project.project_site,
        coalesce(client.party_name, ''),
        baseline.contract_value::text,
        coalesce(progress.confirmed, 0)::text,
        greatest(
          coalesce(progress.confirmed, 0) - coalesce(claims.claimed, 0), 0
        )::text,
        coalesce(invoice.claimed, 0)::text,
        coalesce(invoice.certified, 0)::text,
        coalesce(invoice.paid, 0)::text,
        greatest(
          coalesce(invoice.certified, 0) - coalesce(invoice.paid, 0), 0
        )::text,
        coalesce(pdc.exposure, 0)::text,
        coalesce(progress.percent, 0)::text
      ))
      into v_rows
      from public.v1_accounts_project_commercial_profiles profile
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = profile.current_baseline_revision_id
      left join lateral (
        select party_name
        from public.v1_project_parties
        where project_id = p_project_id and party_kind = 'client'
        order by created_at, id
        limit 1
      ) client on true
      left join lateral (
        select
          coalesce(sum(round(
            baseline.contract_value * building.allocation_percent / 100
            * stage.allocation_percent / 100
            * progress_entry.confirmed_percent / 100, 2
          )), 0) confirmed,
          case
            when coalesce(sum(
              building.allocation_percent * stage.allocation_percent
            ), 0) = 0 then 0
            else round(sum(
              building.allocation_percent * stage.allocation_percent
              * progress_entry.confirmed_percent
            ) / sum(
              building.allocation_percent * stage.allocation_percent
            ), 2)
          end percent
        from public.v1_accounts_billing_progress progress_entry
        join public.v1_accounts_baseline_building_allocations building
          on building.id = progress_entry.building_allocation_id
        join public.v1_accounts_baseline_stage_allocations stage
          on stage.id = progress_entry.stage_allocation_id
        where progress_entry.project_id = p_project_id
          and progress_entry.review_status <> 'returned'
      ) progress on true
      left join lateral (
        select coalesce(sum(line.claimed_amount), 0) claimed
        from public.v1_accounts_client_claim_lines line
        join public.v1_accounts_client_claims claim on claim.id = line.claim_id
        where claim.project_id = p_project_id and claim.status <> 'cancelled'
      ) claims on true
      left join lateral (
        select
          coalesce(sum(invoice_record.claimed_ex_vat), 0) claimed,
          coalesce(sum(
            public.v1_accounts_invoice_certified_incl_vat(invoice_record.id)
          ), 0) certified,
          coalesce(sum(
            public.v1_accounts_invoice_paid_amount(invoice_record.id)
          ), 0) paid
        from public.v1_accounts_client_invoices invoice_record
        where invoice_record.project_id = p_project_id
          and invoice_record.status <> 'cancelled'
      ) invoice on true
      left join lateral (
        select coalesce(sum(pdc_record.amount), 0) exposure
        from public.v1_accounts_client_pdcs pdc_record
        where pdc_record.project_id = p_project_id
          and pdc_record.status in ('expected', 'received', 'deposited')
      ) pdc on true
      where profile.project_id = p_project_id;

    when 'commercial_baseline' then
      v_columns := '["Revision","Status","Contract Value","Currency","VAT %","Payment Terms Days","Reminder Lead Days","Effective At","Reason","Approved By","Approved Role"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        baseline.revision_number::text,
        baseline.status,
        baseline.contract_value::text,
        baseline.currency_code,
        baseline.vat_rate_percent::text,
        baseline.payment_terms_days::text,
        baseline.reminder_lead_days::text,
        baseline.effective_at::text,
        baseline.reason,
        public.v1_safe_profile_display_name(
          approver.display_name, approver.auth_user_id
        ),
        baseline.approved_by_exact_role
      ) order by baseline.revision_number desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_baseline_revisions baseline
      join public.v1_profiles approver
        on approver.auth_user_id = baseline.approved_by_auth_user_id
      where baseline.project_id = p_project_id;

    when 'building_allocations' then
      v_columns := '["Baseline Revision","Baseline Status","Building Code","Building","Allocation %","Allocated Value"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        baseline.revision_number::text,
        baseline.status,
        scope.scope_code,
        scope.name,
        allocation.allocation_percent::text,
        round(
          baseline.contract_value * allocation.allocation_percent / 100, 2
        )::text
      ) order by baseline.revision_number desc, scope.scope_code), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_baseline_building_allocations allocation
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = allocation.baseline_revision_id
      join public.v1_project_scopes scope
        on scope.id = allocation.project_scope_id
      where allocation.project_id = p_project_id;

    when 'stage_allocations' then
      v_columns := '["Baseline Revision","Baseline Status","Stage Key","Stage","Display Order","Contract %","Contract Value"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        baseline.revision_number::text,
        baseline.status,
        stage.stage_key,
        stage.stage_name,
        stage.display_order::text,
        stage.allocation_percent::text,
        round(
          baseline.contract_value * stage.allocation_percent / 100, 2
        )::text
      ) order by baseline.revision_number desc, stage.display_order), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_baseline_stage_allocations stage
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = stage.baseline_revision_id
      where stage.project_id = p_project_id;

    when 'billing_progress' then
      v_columns := '["Building","Stage","Building Allocation %","Stage Allocation %","Stage Value","Suggested %","Confirmed %","Eligible Amount","Review Status","Suggested Evidence","Confirmed Evidence","Evidence Files","Suggested By","Suggested At","Confirmed By","Confirmed At","Reviewed By","Reviewed At","Updated At","Version"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        scope.name,
        stage.stage_name,
        building.allocation_percent::text,
        stage.allocation_percent::text,
        round(
          baseline.contract_value * building.allocation_percent / 100
          * stage.allocation_percent / 100, 2
        )::text,
        entry.suggested_percent::text,
        entry.confirmed_percent::text,
        round(
          baseline.contract_value * building.allocation_percent / 100
          * stage.allocation_percent / 100
          * entry.confirmed_percent / 100, 2
        )::text,
        entry.review_status,
        coalesce(entry.suggested_evidence_summary, ''),
        coalesce(entry.confirmed_evidence_summary, ''),
        (
          cardinality(entry.suggested_evidence_document_ids)
          + cardinality(entry.confirmed_evidence_document_ids)
        )::text,
        case when suggested.auth_user_id is null then '' else
          public.v1_safe_profile_display_name(
            suggested.display_name, suggested.auth_user_id
          ) end,
        coalesce(entry.suggested_at::text, ''),
        case when confirmed.auth_user_id is null then '' else
          public.v1_safe_profile_display_name(
            confirmed.display_name, confirmed.auth_user_id
          ) end,
        coalesce(entry.confirmed_at::text, ''),
        case when reviewed.auth_user_id is null then '' else
          public.v1_safe_profile_display_name(
            reviewed.display_name, reviewed.auth_user_id
          ) end,
        coalesce(entry.reviewed_at::text, ''),
        entry.updated_at::text,
        entry.record_version::text
      ) order by scope.scope_kind, scope.scope_code, stage.display_order), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_billing_progress entry
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = entry.baseline_revision_id
      join public.v1_accounts_baseline_building_allocations building
        on building.id = entry.building_allocation_id
      join public.v1_project_scopes scope on scope.id = entry.project_scope_id
      join public.v1_accounts_baseline_stage_allocations stage
        on stage.id = entry.stage_allocation_id
      left join public.v1_profiles suggested
        on suggested.auth_user_id = entry.suggested_by_auth_user_id
      left join public.v1_profiles confirmed
        on confirmed.auth_user_id = entry.confirmed_by_auth_user_id
      left join public.v1_profiles reviewed
        on reviewed.auth_user_id = entry.reviewed_by_auth_user_id
      where entry.project_id = p_project_id;

    when 'progress_history' then
      v_columns := '["Building","Stage","Revision","Action","Previous Suggested %","New Suggested %","Previous Confirmed %","New Confirmed %","Previous Review","New Review","Evidence","Evidence Files","Reason","Actor","Role","Occurred At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        scope.name,
        stage.stage_name,
        revision.revision_number::text,
        revision.action,
        revision.previous_suggested_percent::text,
        revision.new_suggested_percent::text,
        revision.previous_confirmed_percent::text,
        revision.new_confirmed_percent::text,
        revision.previous_review_status,
        revision.new_review_status,
        coalesce(revision.evidence_summary, ''),
        cardinality(revision.evidence_document_ids)::text,
        revision.reason,
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        revision.actor_exact_role,
        revision.occurred_at::text
      ) order by revision.occurred_at desc, revision.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_billing_progress_revisions revision
      join public.v1_accounts_billing_progress progress
        on progress.id = revision.progress_entry_id
      join public.v1_project_scopes scope
        on scope.id = progress.project_scope_id
      join public.v1_accounts_baseline_stage_allocations stage
        on stage.id = progress.stage_allocation_id
      join public.v1_profiles actor
        on actor.auth_user_id = revision.actor_auth_user_id
      where revision.project_id = p_project_id;

    when 'client_claims' then
      v_columns := '["Claim","Status","Period Start","Period End","Baseline Revision","Claimed Amount","Line Count","Stale","Stale Reason","Notes","Created By","Created Role","Created At","Ready For Accounts At","Cancelled At","Cancellation Reason","Version"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        claim.claim_reference,
        claim.status,
        claim.claim_period_start::text,
        claim.claim_period_end::text,
        baseline.revision_number::text,
        coalesce(lines.amount, 0)::text,
        coalesce(lines.line_count, 0)::text,
        claim.is_stale::text,
        coalesce(claim.stale_reason, ''),
        coalesce(claim.notes, ''),
        public.v1_safe_profile_display_name(
          creator.display_name, creator.auth_user_id
        ),
        claim.created_by_exact_role,
        claim.created_at::text,
        coalesce(claim.ready_for_accounts_at::text, ''),
        coalesce(claim.cancelled_at::text, ''),
        coalesce(claim.cancellation_reason, ''),
        claim.record_version::text
      ) order by claim.updated_at desc, claim.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_claims claim
      join public.v1_accounts_baseline_revisions baseline
        on baseline.id = claim.baseline_revision_id
      join public.v1_profiles creator
        on creator.auth_user_id = claim.created_by_auth_user_id
      left join lateral (
        select sum(line.claimed_amount) amount, count(*) line_count
        from public.v1_accounts_client_claim_lines line
        where line.claim_id = claim.id
      ) lines on true
      where claim.project_id = p_project_id;

    when 'claim_lines' then
      v_columns := '["Claim","Claim Status","Building","Stage","Stage Value","Confirmed %","Eligible Amount","Previously Claimed","This Claim","Evidence Reference","Progress Revision","Progress Version","Created At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        claim.claim_reference,
        claim.status,
        scope.name,
        stage.stage_name,
        line.stage_value_snapshot::text,
        line.confirmed_percent_snapshot::text,
        line.eligible_amount_snapshot::text,
        line.previously_claimed_amount_snapshot::text,
        line.claimed_amount::text,
        coalesce(line.evidence_reference, ''),
        progress_revision.revision_number::text,
        line.progress_record_version::text,
        line.created_at::text
      ) order by claim.claim_reference, scope.scope_code, stage.display_order), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_claim_lines line
      join public.v1_accounts_client_claims claim on claim.id = line.claim_id
      join public.v1_project_scopes scope on scope.id = line.project_scope_id
      join public.v1_accounts_baseline_stage_allocations stage
        on stage.baseline_revision_id = line.baseline_revision_id
        and stage.stage_key = line.stage_key
      join public.v1_accounts_billing_progress_revisions progress_revision
        on progress_revision.id = line.progress_revision_id
      where line.project_id = p_project_id;

    when 'client_invoices' then
      v_columns := '["Invoice","Claim","Status","Claimed ex VAT","VAT %","VAT Amount","Total incl VAT","Certified incl VAT","Paid","Still Due","Payment Terms Days","Reminder Lead Days","Submitted","Due","Returned At","Return Reason","Cancelled At","Cancellation Reason","Notes","Created By","Created At","Updated At","Version"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        invoice.invoice_reference,
        claim.claim_reference,
        invoice.status,
        invoice.claimed_ex_vat::text,
        invoice.vat_rate_percent_snapshot::text,
        invoice.vat_amount_snapshot::text,
        invoice.total_incl_vat_snapshot::text,
        public.v1_accounts_invoice_certified_incl_vat(invoice.id)::text,
        public.v1_accounts_invoice_paid_amount(invoice.id)::text,
        greatest(
          public.v1_accounts_invoice_certified_incl_vat(invoice.id)
          - public.v1_accounts_invoice_paid_amount(invoice.id), 0
        )::text,
        invoice.payment_terms_days_snapshot::text,
        invoice.reminder_lead_days_snapshot::text,
        coalesce(invoice.submission_date::text, ''),
        coalesce(invoice.due_date::text, ''),
        coalesce(invoice.returned_at::text, ''),
        coalesce(invoice.return_reason, ''),
        coalesce(invoice.cancelled_at::text, ''),
        coalesce(invoice.cancellation_reason, ''),
        coalesce(invoice.notes, ''),
        public.v1_safe_profile_display_name(
          creator.display_name, creator.auth_user_id
        ),
        invoice.created_at::text,
        invoice.updated_at::text,
        invoice.record_version::text
      ) order by invoice.updated_at desc, invoice.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_invoices invoice
      join public.v1_accounts_client_claims claim on claim.id = invoice.claim_id
      join public.v1_profiles creator
        on creator.auth_user_id = invoice.created_by_auth_user_id
      where invoice.project_id = p_project_id;

    when 'certifications' then
      v_columns := '["Certification","Invoice","Revision","Certification Date","Certified ex VAT","Certified VAT","Certified incl VAT","Difference Reason","Actor","Role","Created At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        certification.certification_reference,
        invoice.invoice_reference,
        certification.revision_number::text,
        certification.certification_date::text,
        certification.certified_ex_vat::text,
        certification.certified_vat::text,
        certification.certified_incl_vat::text,
        coalesce(certification.difference_reason, ''),
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        certification.actor_exact_role,
        certification.created_at::text
      ) order by certification.certification_date desc,
          certification.created_at desc, certification.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_certifications certification
      join public.v1_accounts_client_invoices invoice
        on invoice.id = certification.invoice_id
      join public.v1_profiles actor
        on actor.auth_user_id = certification.actor_auth_user_id
      where certification.project_id = p_project_id;

    when 'client_receipts' then
      v_columns := '["Payment Reference","Invoice","Entry Kind","Original Reference","PDC Cheque","Payment Date","Payment Method","Amount","Reason","Actor","Role","Created At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        payment.payment_reference,
        invoice.invoice_reference,
        payment.entry_kind,
        coalesce(original.payment_reference, ''),
        coalesce(pdc.cheque_number, ''),
        payment.payment_date::text,
        payment.payment_method,
        payment.amount::text,
        coalesce(payment.reason, ''),
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        payment.actor_exact_role,
        payment.created_at::text
      ) order by payment.payment_date desc, payment.created_at desc,
          payment.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_payments payment
      join public.v1_accounts_client_invoices invoice
        on invoice.id = payment.invoice_id
      left join public.v1_accounts_client_payments original
        on original.id = payment.original_payment_id
      left join public.v1_accounts_client_pdcs pdc on pdc.id = payment.pdc_id
      join public.v1_profiles actor
        on actor.auth_user_id = payment.actor_auth_user_id
      where payment.project_id = p_project_id;

    when 'pdc_register' then
      v_columns := '["Cheque","Invoice","Bank","Cheque Date","Received Date","Amount","Status","Replaces Cheque","Replaced By Cheque","Action Required","Last Action Reason","Created By","Created Role","Created At","Updated At","Version"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        pdc.cheque_number,
        invoice.invoice_reference,
        coalesce(pdc.bank_name, ''),
        pdc.cheque_date::text,
        coalesce(pdc.received_date::text, ''),
        pdc.amount::text,
        pdc.status,
        coalesce(replaces.cheque_number, ''),
        coalesce(replaced_by.cheque_number, ''),
        pdc.action_required::text,
        coalesce(pdc.last_action_reason, ''),
        public.v1_safe_profile_display_name(
          creator.display_name, creator.auth_user_id
        ),
        pdc.created_by_exact_role,
        pdc.created_at::text,
        pdc.updated_at::text,
        pdc.record_version::text
      ) order by pdc.cheque_date, pdc.id), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_pdcs pdc
      join public.v1_accounts_client_invoices invoice
        on invoice.id = pdc.invoice_id
      left join public.v1_accounts_client_pdcs replaces
        on replaces.id = pdc.replaces_pdc_id
      left join public.v1_accounts_client_pdcs replaced_by
        on replaced_by.id = pdc.replaced_by_pdc_id
      join public.v1_profiles creator
        on creator.auth_user_id = pdc.created_by_auth_user_id
      where pdc.project_id = p_project_id;

    when 'pdc_events' then
      v_columns := '["Cheque","Invoice","Sequence","From Status","To Status","Action Date","Linked Receipt","Reason","Actor","Role","Occurred At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        pdc.cheque_number,
        invoice.invoice_reference,
        event.sequence_number::text,
        coalesce(event.from_status, ''),
        event.to_status,
        event.action_date::text,
        coalesce(payment.payment_reference, ''),
        coalesce(event.reason, ''),
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        event.actor_exact_role,
        event.occurred_at::text
      ) order by event.occurred_at desc, event.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_client_pdc_events event
      join public.v1_accounts_client_pdcs pdc on pdc.id = event.pdc_id
      join public.v1_accounts_client_invoices invoice
        on invoice.id = event.invoice_id
      left join public.v1_accounts_client_payments payment
        on payment.id = event.linked_payment_id
      join public.v1_profiles actor
        on actor.auth_user_id = event.actor_auth_user_id
      where event.project_id = p_project_id;

    when 'supplier_bills' then
      v_columns := '["Supplier Invoice","Supplier","Bill Status","Match Status","Payment Status","PO/LPO","Invoice Date","Due Date","Ex VAT","VAT %","VAT Amount","Total incl VAT","Paid","Outstanding","Delivery Reference","Mismatch Reason","Admin Approval Reason","Notes","Approved At","Approved By","Cancelled At","Cancellation Reason","Created By","Created Role","Created At","Updated At","Version"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        bill.supplier_invoice_reference,
        bill.supplier_name_snapshot,
        bill.status,
        public.v1_accounts_supplier_match_status(bill.id),
        public.v1_accounts_supplier_payment_status(bill.id),
        coalesce(bill.po_lpo_reference, ''),
        bill.invoice_date::text,
        bill.due_date::text,
        bill.ex_vat_amount::text,
        bill.vat_rate_percent::text,
        bill.vat_amount::text,
        bill.total_incl_vat::text,
        public.v1_accounts_supplier_paid_amount(bill.id)::text,
        greatest(
          bill.total_incl_vat
          - public.v1_accounts_supplier_paid_amount(bill.id), 0
        )::text,
        coalesce(bill.accepted_delivery_reference, ''),
        coalesce(bill.explicit_mismatch_reason, ''),
        coalesce(bill.approval_admin_exception_reason, ''),
        coalesce(bill.notes, ''),
        coalesce(bill.approved_at::text, ''),
        case when approver.auth_user_id is null then '' else
          public.v1_safe_profile_display_name(
            approver.display_name, approver.auth_user_id
          ) end,
        coalesce(bill.cancelled_at::text, ''),
        coalesce(bill.cancellation_reason, ''),
        public.v1_safe_profile_display_name(
          creator.display_name, creator.auth_user_id
        ),
        bill.created_by_exact_role,
        bill.created_at::text,
        bill.updated_at::text,
        bill.record_version::text
      ) order by bill.updated_at desc, bill.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_supplier_bills bill
      join public.v1_profiles creator
        on creator.auth_user_id = bill.created_by_auth_user_id
      left join public.v1_profiles approver
        on approver.auth_user_id = bill.approved_by_auth_user_id
      where bill.project_id = p_project_id;

    when 'supplier_payments' then
      v_columns := '["Payment Reference","Supplier Invoice","Supplier","Entry Kind","Original Reference","Payment Date","Payment Method","Amount","Reason","Admin Exception Reason","Actor","Role","Created At"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        payment.payment_reference,
        bill.supplier_invoice_reference,
        bill.supplier_name_snapshot,
        payment.entry_kind,
        coalesce(original.payment_reference, ''),
        payment.payment_date::text,
        payment.payment_method,
        payment.amount::text,
        coalesce(payment.reason, ''),
        coalesce(payment.admin_exception_reason, ''),
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        payment.actor_exact_role,
        payment.created_at::text
      ) order by payment.payment_date desc, payment.created_at desc,
          payment.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_supplier_payments payment
      join public.v1_accounts_supplier_bills bill
        on bill.id = payment.supplier_bill_id
      left join public.v1_accounts_supplier_payments original
        on original.id = payment.original_payment_id
      join public.v1_profiles actor
        on actor.auth_user_id = payment.actor_auth_user_id
      where payment.project_id = p_project_id;

    when 'accounts_documents' then
      v_columns := '["Document Type","File Name","Classification","Revision","MIME Type","Size Bytes","SHA256","Origin","Source Entity Type","Source Entity ID","Linked Records","Archived","Created At","Uploaded At","Uploaded By","Uploaded Role"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        metadata.document_type,
        version_record.original_file_name,
        document_record.classification,
        version_record.revision_number::text,
        version_record.mime_type,
        version_record.byte_size::text,
        version_record.sha256,
        version_record.origin,
        coalesce(version_record.source_entity_type, ''),
        coalesce(version_record.source_entity_id::text, ''),
        coalesce(links.targets, ''),
        (metadata.archived_at is not null)::text,
        document_record.created_at::text,
        version_record.uploaded_at::text,
        public.v1_safe_profile_display_name(
          uploader.display_name, uploader.auth_user_id
        ),
        version_record.uploaded_by_role
      ) order by version_record.uploaded_at desc, document_record.id), '[]'::jsonb)
      into v_rows
      from public.v1_accounts_document_metadata metadata
      join public.v1_documents document_record
        on document_record.id = metadata.document_id
      join public.v1_document_versions version_record
        on version_record.document_id = document_record.id
      join public.v1_profiles uploader
        on uploader.auth_user_id = version_record.uploaded_by_auth_user_id
      left join lateral (
        select string_agg(
          link.entity_type || ':' || link.entity_id::text, ', '
          order by link.linked_at, link.id
        ) targets
        from public.v1_document_links link
        where link.document_id = document_record.id
          and link.project_id = p_project_id
          and link.removed_at is null
      ) links on true
      where exists (
        select 1
        from public.v1_document_links project_link
        where project_link.document_id = document_record.id
          and project_link.project_id = p_project_id
          and project_link.removed_at is null
      ) and public.v1_document_readable(document_record.id);

    when 'accounts_activity' then
      v_columns := '["Occurred At","Event","Entity Type","Entity ID","Actor","Role","Reason","Idempotency Key","Before","After"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(
        audit.occurred_at::text,
        audit.event_type,
        audit.entity_type,
        audit.entity_id::text,
        public.v1_safe_profile_display_name(
          actor.display_name, actor.auth_user_id
        ),
        coalesce(audit.actor_exact_role, audit.actor_role),
        coalesce(audit.reason, ''),
        coalesce(audit.idempotency_key::text, ''),
        coalesce(audit.before_data::text, ''),
        coalesce(audit.after_data::text, '')
      ) order by audit.occurred_at desc, audit.id desc), '[]'::jsonb)
      into v_rows
      from public.v1_audit_events audit
      join public.v1_profiles actor
        on actor.auth_user_id = audit.actor_auth_user_id
      where audit.project_id = p_project_id
        and (
          audit.event_type like 'accounts.%'
          or audit.entity_type like 'accounts_%'
        );
  end case;

  v_result := jsonb_build_object(
    'schema_version', 7,
    'report_kind', p_export_kind,
    'project_id', p_project_id,
    'project_reference', v_project.project_ref,
    'project_name', v_project.name,
    'currency', 'AED',
    'access_context', v_role,
    'generated_at', clock_timestamp(),
    'generated_by_auth_user_id', v_actor,
    'generated_by_display_name', (
      select public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      )
      from public.v1_profiles profile
      where profile.auth_user_id = v_actor
    ),
    'columns', v_columns,
    'rows', coalesce(v_rows, '[]'::jsonb)
  );

  perform public.v1_write_audit_event(
    'accounts.export.generated',
    'accounts_export',
    p_idempotency_key,
    p_project_id,
    null,
    jsonb_build_object(
      'report_kind', p_export_kind,
      'row_count', jsonb_array_length(coalesce(v_rows, '[]'::jsonb))
    ),
    null,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_get_accounts_export', p_idempotency_key, v_result
  );
  return v_result;
end;
$$;

revoke all on function public.v1_get_accounts_export(text, uuid, uuid)
  from public, anon;
grant execute on function public.v1_get_accounts_export(text, uuid, uuid)
  to authenticated;

comment on function public.v1_get_accounts_export(text, uuid, uuid) is
  'Returns a capability-shaped project Accounts register for clean XLSX/PDF backup output and appends an attributable audit event.';
