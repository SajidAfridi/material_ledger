-- Yorks R39 Accounts T05: role-safe portfolio and project UI projections.
--
-- This migration adds read-only, server-filtered projections for the
-- normalized Accounts routes. It does not alter any T02-T04 command or any
-- Project, BOQ, Material Request, Inventory, Dispatch, Receipt or Return row.
-- The application feature flag remains default-off until the release gate.
--
-- Rollback: disable YORKS_V1_ACCOUNTS and revoke these two RPCs. Retain all
-- existing commercial records; the projections own no durable business data.

begin;

create or replace function public.v1_accounts_portfolio_role_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_actor_is_active()
    and public.v1_permission_exact_role(auth.uid()) in (
      'admin', 'accountant', 'project_manager',
      'senior_mechanical_engineer'
    );
$$;

create or replace function public.v1_get_accounts_portfolio(
  p_project_id uuid default null,
  p_client text default null,
  p_commercial_state text default null,
  p_due_state text default null,
  p_payment_state text default null,
  p_pdc_state text default null,
  p_supplier_match_state text default null,
  p_search text default null,
  p_before_activity_at timestamptz default null,
  p_before_project_id uuid default null,
  p_limit integer default 25
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_permission_exact_role(auth.uid());
  v_rows jsonb;
  v_totals jsonb;
  v_actions jsonb;
  v_next jsonb;
  v_authorized_count integer;
  v_filtered_count integer;
begin
  if v_actor is null or not public.v1_accounts_portfolio_role_allowed() then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  if p_limit < 1 or p_limit > 100
    or (p_before_activity_at is null) <> (p_before_project_id is null)
    or (p_commercial_state is not null and p_commercial_state not in (
      'active', 'not_initialized', 'action_required'
    ))
    or (p_due_state is not null and p_due_state not in (
      'current', 'due_soon', 'overdue'
    ))
    or (p_payment_state is not null and p_payment_state not in (
      'unpaid', 'partially_paid', 'paid'
    ))
    or (p_pdc_state is not null and p_pdc_state not in (
      'expected', 'received', 'deposited', 'cleared', 'returned',
      'bounced', 'replaced', 'cancelled'
    ))
    or (p_supplier_match_state is not null
      and p_supplier_match_state not in ('blocked', 'review', 'matched')) then
    raise exception 'R39_ACCOUNTS_INVALID_PORTFOLIO_FILTER'
      using errcode = '22023';
  end if;

  with authorized as materialized (
    select project.id, project.project_ref, project.name, project.project_site,
      project.state, project.updated_at as project_updated_at,
      client.party_name as client_name,
      public.v1_current_user_has_capability(
        'view_project_commercial_values', project.id
      ) as can_view_values,
      public.v1_current_user_has_capability(
        'view_supplier_costs', project.id
      ) as can_view_supplier_costs
    from public.v1_projects project
    left join lateral (
      select party.party_name
      from public.v1_project_parties party
      where party.project_id = project.id and party.party_kind = 'client'
      order by party.created_at, party.id
      limit 1
    ) client on true
    where public.v1_current_user_has_capability(
      'view_project_accounts', project.id
    )
      and public.v1_current_user_has_capability(
        'view_project_commercial_values', project.id
      )
      and (p_project_id is null or project.id = p_project_id)
  ), facts as materialized (
    select authorized.*,
      baseline.id as baseline_revision_id,
      baseline.revision_number as baseline_revision_number,
      baseline.currency_code,
      coalesce(baseline.contract_value, 0) as contract_value,
      coalesce(progress.confirmed_eligible, 0) as confirmed_eligible,
      greatest(
        coalesce(progress.confirmed_eligible, 0)
          - coalesce(claims.claimed_reserved, 0), 0
      ) as available_to_claim,
      coalesce(invoices.claimed, 0) as claimed,
      coalesce(invoices.certified, 0) as certified,
      coalesce(invoices.paid, 0) as paid,
      greatest(coalesce(invoices.certified, 0)
        - coalesce(invoices.paid, 0), 0) as still_due,
      coalesce(invoices.pdc_exposure, 0) as pdc_exposure,
      coalesce(progress.confirmed_percent, 0) as confirmed_percent,
      coalesce(invoices.overdue_count, 0) as overdue_count,
      coalesce(invoices.due_soon_count, 0) as due_soon_count,
      coalesce(invoices.open_invoice_count, 0) as open_invoice_count,
      coalesce(invoices.returned_invoice_count, 0)
        + coalesce(claims.returned_claim_count, 0) as returned_count,
      coalesce(pdcs.action_pdc_count, 0) as action_pdc_count,
      coalesce(suppliers.review_count, 0) as supplier_review_count,
      coalesce(suppliers.open_amount, 0) as supplier_open_amount,
      greatest(
        authorized.project_updated_at,
        coalesce(baseline.created_at, '-infinity'::timestamptz),
        coalesce(progress.latest_at, '-infinity'::timestamptz),
        coalesce(claims.latest_at, '-infinity'::timestamptz),
        coalesce(invoices.latest_at, '-infinity'::timestamptz),
        coalesce(pdcs.latest_at, '-infinity'::timestamptz),
        coalesce(suppliers.latest_at, '-infinity'::timestamptz)
      ) as latest_activity_at,
      case
        when coalesce(invoices.overdue_count, 0) > 0 then 'overdue'
        when coalesce(invoices.due_soon_count, 0) > 0 then 'due_soon'
        else 'current'
      end as due_state,
      case
        when coalesce(invoices.certified, 0) > 0
          and coalesce(invoices.paid, 0) >= invoices.certified then 'paid'
        when coalesce(invoices.paid, 0) > 0 then 'partially_paid'
        else 'unpaid'
      end as payment_state
    from authorized
    left join public.v1_accounts_project_commercial_profiles profile
      on profile.project_id = authorized.id
    left join public.v1_accounts_baseline_revisions baseline
      on baseline.id = profile.current_baseline_revision_id
    left join lateral (
      select
        coalesce(sum(round(
          baseline.contract_value
          * building.allocation_percent / 100
          * stage.allocation_percent / 100
          * entry.confirmed_percent / 100, 2
        )), 0) as confirmed_eligible,
        case when coalesce(sum(
          building.allocation_percent * stage.allocation_percent
        ), 0) = 0 then 0 else round(
          sum(building.allocation_percent * stage.allocation_percent
            * entry.confirmed_percent)
          / sum(building.allocation_percent * stage.allocation_percent), 2
        ) end as confirmed_percent,
        max(entry.updated_at) as latest_at
      from public.v1_accounts_billing_progress entry
      join public.v1_accounts_baseline_building_allocations building
        on building.id = entry.building_allocation_id
      join public.v1_accounts_baseline_stage_allocations stage
        on stage.id = entry.stage_allocation_id
      where entry.project_id = authorized.id
        and entry.baseline_revision_id = baseline.id
        and entry.review_status <> 'returned'
    ) progress on true
    left join lateral (
      select coalesce(sum(case when claim.status <> 'cancelled'
          then line.claimed_amount else 0 end), 0) as claimed_reserved,
        count(*) filter (where claim.status = 'draft'
          and claim.is_stale) as returned_claim_count,
        max(claim.updated_at) as latest_at
      from public.v1_accounts_client_claims claim
      left join public.v1_accounts_client_claim_lines line
        on line.claim_id = claim.id
      where claim.project_id = authorized.id
    ) claims on true
    left join lateral (
      select coalesce(sum(case when invoice.status not in (
          'draft', 'returned', 'cancelled'
        ) then invoice.claimed_ex_vat else 0 end), 0) as claimed,
        coalesce(sum(case when invoice.status <> 'cancelled'
          then public.v1_accounts_invoice_certified_incl_vat(invoice.id)
          else 0 end), 0) as certified,
        coalesce(sum(case when invoice.status <> 'cancelled'
          then public.v1_accounts_invoice_paid_amount(invoice.id)
          else 0 end), 0) as paid,
        coalesce(sum(case when invoice.status <> 'cancelled'
          then public.v1_accounts_invoice_pdc_exposure(invoice.id)
          else 0 end), 0) as pdc_exposure,
        count(*) filter (where invoice.due_date < current_date
          and invoice.status not in ('draft','returned','cancelled','paid'))
          as overdue_count,
        count(*) filter (where invoice.due_date >= current_date
          and invoice.due_date <= current_date
            + invoice.reminder_lead_days_snapshot
          and invoice.status not in ('draft','returned','cancelled','paid'))
          as due_soon_count,
        count(*) filter (where invoice.status not in ('cancelled','paid'))
          as open_invoice_count,
        count(*) filter (where invoice.status = 'returned')
          as returned_invoice_count,
        max(invoice.updated_at) as latest_at
      from public.v1_accounts_client_invoices invoice
      where invoice.project_id = authorized.id
    ) invoices on true
    left join lateral (
      select count(*) filter (where pdc.action_required) as action_pdc_count,
        max(pdc.updated_at) as latest_at
      from public.v1_accounts_client_pdcs pdc
      where pdc.project_id = authorized.id
    ) pdcs on true
    left join lateral (
      select count(*) filter (where bill.status <> 'cancelled'
          and public.v1_accounts_supplier_match_status(bill.id) <> 'matched')
          as review_count,
        coalesce(sum(case when bill.status <> 'cancelled' then greatest(
          bill.total_incl_vat
            - public.v1_accounts_supplier_paid_amount(bill.id), 0
        ) else 0 end), 0) as open_amount,
        max(bill.updated_at) as latest_at
      from public.v1_accounts_supplier_bills bill
      where bill.project_id = authorized.id
        and authorized.can_view_supplier_costs
    ) suppliers on true
  ), matched as materialized (
    select facts.* from facts
    where (p_client is null or facts.client_name ilike '%'||btrim(p_client)||'%')
      and (p_search is null or btrim(p_search) = ''
        or facts.project_ref ilike '%'||btrim(p_search)||'%'
        or facts.name ilike '%'||btrim(p_search)||'%'
        or coalesce(facts.client_name, '') ilike '%'||btrim(p_search)||'%')
      and (p_commercial_state is null or case p_commercial_state
        when 'not_initialized' then facts.baseline_revision_id is null
        when 'active' then facts.baseline_revision_id is not null
          and facts.overdue_count + facts.due_soon_count + facts.returned_count
            + facts.action_pdc_count + facts.supplier_review_count = 0
        when 'action_required' then facts.overdue_count + facts.due_soon_count
          + facts.returned_count + facts.action_pdc_count
          + facts.supplier_review_count > 0 end)
      and (p_due_state is null or facts.due_state = p_due_state)
      and (p_payment_state is null or facts.payment_state = p_payment_state)
      and (p_pdc_state is null or exists (
        select 1 from public.v1_accounts_client_pdcs pdc
        where pdc.project_id = facts.id and pdc.status = p_pdc_state
      ))
      and (p_supplier_match_state is null or (
        facts.can_view_supplier_costs and exists (
          select 1 from public.v1_accounts_supplier_bills bill
          where bill.project_id = facts.id and bill.status <> 'cancelled'
            and public.v1_accounts_supplier_match_status(bill.id)
              = p_supplier_match_state
        )
      ))
  ), filtered as materialized (
    select matched.* from matched
    where p_before_activity_at is null
      or (matched.latest_activity_at, matched.id)
        < (p_before_activity_at, p_before_project_id)
  ), page as materialized (
    select * from filtered
    order by latest_activity_at desc, id desc limit p_limit + 1
  )
  select
    (select count(*) from authorized),
    (select count(*) from matched),
    coalesce((select jsonb_agg(
      jsonb_build_object(
        'project_id', page.id,
        'project_reference', page.project_ref,
        'project_name', page.name,
        'project_site', page.project_site,
        'project_state', page.state,
        'client_name', page.client_name,
        'baseline_revision_number', page.baseline_revision_number,
        'currency_code', page.currency_code,
        'contract_baseline', page.contract_value::text,
        'confirmed_eligible', page.confirmed_eligible::text,
        'available_to_claim', page.available_to_claim::text,
        'claimed', page.claimed::text,
        'certified', page.certified::text,
        'amount_paid_till_date', page.paid::text,
        'still_due', page.still_due::text,
        'pdc_exposure', page.pdc_exposure::text,
        'confirmed_percent', page.confirmed_percent::text,
        'due_state', page.due_state,
        'payment_state', page.payment_state,
        'action_count', page.overdue_count + page.due_soon_count
          + page.returned_count + page.action_pdc_count
          + page.supplier_review_count,
        'latest_activity_at', page.latest_activity_at
      ) || case when page.can_view_supplier_costs then jsonb_build_object(
        'supplier_review_count', page.supplier_review_count,
        'supplier_open_amount', page.supplier_open_amount::text
      ) else '{}'::jsonb end
      order by page.latest_activity_at desc, page.id desc
    ) from (select * from page limit p_limit) page), '[]'::jsonb),
    (select jsonb_build_object(
      'project_count', count(*),
      'contract_baseline', coalesce(sum(contract_value),0)::text,
      'confirmed_eligible', coalesce(sum(confirmed_eligible),0)::text,
      'available_to_claim', coalesce(sum(available_to_claim),0)::text,
      'claimed', coalesce(sum(claimed),0)::text,
      'certified', coalesce(sum(certified),0)::text,
      'amount_paid_till_date', coalesce(sum(paid),0)::text,
      'still_due', coalesce(sum(still_due),0)::text,
      'pdc_exposure', coalesce(sum(pdc_exposure),0)::text,
      'action_count', coalesce(sum(overdue_count + due_soon_count
        + returned_count + action_pdc_count + supplier_review_count),0)
    ) from facts),
    (select coalesce(jsonb_agg(action order by
      (action->>'severity_rank')::integer, action->>'occurred_at' desc
    ), '[]'::jsonb) from (
      select jsonb_build_object(
        'project_id', facts.id,
        'project_reference', facts.project_ref,
        'project_name', facts.name,
        'code', case
          when facts.overdue_count > 0 then 'overdue_invoice'
          when facts.action_pdc_count > 0 then 'pdc_action_required'
          when facts.supplier_review_count > 0 then 'supplier_match_review'
          when facts.returned_count > 0 then 'returned_for_correction'
          else 'due_soon_invoice' end,
        'owner_role', case
          when facts.supplier_review_count > 0 then 'procurement'
          when facts.returned_count > 0 then 'project_engineer'
          else 'accountant' end,
        'severity', case when facts.overdue_count > 0
          or facts.action_pdc_count > 0 then 'critical'
          when facts.supplier_review_count > 0
            or facts.returned_count > 0 then 'high' else 'medium' end,
        'severity_rank', case when facts.overdue_count > 0
          or facts.action_pdc_count > 0 then 1
          when facts.supplier_review_count > 0
            or facts.returned_count > 0 then 2 else 3 end,
        'count', greatest(facts.overdue_count, facts.action_pdc_count,
          facts.supplier_review_count, facts.returned_count,
          facts.due_soon_count),
        'occurred_at', facts.latest_activity_at
      ) as action
      from facts
      where facts.overdue_count + facts.due_soon_count + facts.returned_count
        + facts.action_pdc_count + facts.supplier_review_count > 0
      order by case when facts.overdue_count > 0
        or facts.action_pdc_count > 0 then 1
        when facts.supplier_review_count > 0
          or facts.returned_count > 0 then 2 else 3 end,
        facts.latest_activity_at desc
      limit 12
    ) queue),
    (select case when count(*) > p_limit then (
      select jsonb_build_object(
        'before_activity_at', cursor_row.latest_activity_at,
        'before_project_id', cursor_row.id
      )
      from page cursor_row
      order by cursor_row.latest_activity_at desc, cursor_row.id desc
      offset greatest(p_limit - 1, 0) limit 1
    ) else null end from page)
  into v_authorized_count, v_filtered_count, v_rows, v_totals, v_actions, v_next;

  return jsonb_build_object(
    'schema_version', 2,
    'scope', 'portfolio',
    'actor_exact_role', v_exact_role,
    'can_export', public.v1_current_user_has_capability(
      'export_accounts_registers', null
    ),
    'authorized_project_count', v_authorized_count,
    'filtered_project_count', v_filtered_count,
    'totals', v_totals,
    'projects', v_rows,
    'action_queue', v_actions,
    'next_cursor', v_next
  );
end;
$$;

create or replace function public.v1_get_project_accounts_overview(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text := public.v1_permission_exact_role(auth.uid());
  v_can_view boolean;
  v_can_values boolean;
  v_can_supplier boolean;
  v_project public.v1_projects%rowtype;
  v_profile public.v1_accounts_project_commercial_profiles%rowtype;
  v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_progress jsonb;
  v_invoices jsonb;
  v_supplier jsonb;
  v_result jsonb;
begin
  if auth.uid() is null or p_project_id is null
    or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  v_can_view := public.v1_current_user_has_capability(
    'view_project_accounts', p_project_id
  );
  v_can_values := public.v1_current_user_has_capability(
    'view_project_commercial_values', p_project_id
  );
  v_can_supplier := public.v1_current_user_has_capability(
    'view_supplier_costs', p_project_id
  );
  if not v_can_view and not v_can_supplier then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  select * into v_project from public.v1_projects where id = p_project_id;
  if not found then
    raise exception 'R39_ACCOUNTS_PROJECT_NOT_FOUND' using errcode = 'P0002';
  end if;
  select * into v_profile from public.v1_accounts_project_commercial_profiles
    where project_id = p_project_id;
  if found and v_profile.current_baseline_revision_id is not null then
    select * into v_baseline from public.v1_accounts_baseline_revisions
      where id = v_profile.current_baseline_revision_id;
  end if;

  if v_can_view then
    select jsonb_build_object(
      'confirmed_percent', coalesce(case when sum(
        building.allocation_percent * stage.allocation_percent
      ) = 0 then 0 else round(sum(
        building.allocation_percent * stage.allocation_percent
          * entry.confirmed_percent
      ) / sum(building.allocation_percent * stage.allocation_percent),2) end,0)::text,
      'suggested_percent', coalesce(case when sum(
        building.allocation_percent * stage.allocation_percent
      ) = 0 then 0 else round(sum(
        building.allocation_percent * stage.allocation_percent
          * entry.suggested_percent
      ) / sum(building.allocation_percent * stage.allocation_percent),2) end,0)::text,
      'pending_review_count', count(*) filter (
        where entry.review_status = 'pending'
      ),
      'building_position', coalesce(jsonb_agg(jsonb_build_object(
        'building_scope_id', scope.id,
        'building_name', scope.name,
        'confirmed_percent', entry.confirmed_percent::text,
        'suggested_percent', entry.suggested_percent::text,
        'stage_key', entry.stage_key,
        'stage_name', stage.stage_name,
        'review_status', entry.review_status,
        'action_owner', case
          when entry.review_status = 'pending' then 'management'
          when entry.suggested_percent > entry.confirmed_percent
            then 'project_engineer' else 'none' end,
        'updated_at', entry.updated_at
      ) order by scope.scope_code, stage.display_order), '[]'::jsonb)
    ) || case when v_can_values then jsonb_build_object(
      'confirmed_eligible', coalesce(sum(round(
        v_baseline.contract_value
        * building.allocation_percent / 100
        * stage.allocation_percent / 100
        * entry.confirmed_percent / 100, 2
      )),0)::text
    ) else '{}'::jsonb end
    into v_progress
    from public.v1_accounts_billing_progress entry
    join public.v1_accounts_baseline_building_allocations building
      on building.id = entry.building_allocation_id
    join public.v1_accounts_baseline_stage_allocations stage
      on stage.id = entry.stage_allocation_id
    join public.v1_project_scopes scope on scope.id = entry.project_scope_id
    where entry.project_id = p_project_id
      and entry.baseline_revision_id = v_baseline.id
      and entry.review_status <> 'returned';
  end if;

  if v_can_values then
    select jsonb_build_object(
      'claimed', coalesce(sum(case when invoice.status not in (
        'draft','returned','cancelled'
      ) then invoice.claimed_ex_vat else 0 end),0)::text,
      'certified', coalesce(sum(case when invoice.status <> 'cancelled'
        then public.v1_accounts_invoice_certified_incl_vat(invoice.id)
        else 0 end),0)::text,
      'amount_paid_till_date', coalesce(sum(case
        when invoice.status <> 'cancelled'
        then public.v1_accounts_invoice_paid_amount(invoice.id)
        else 0 end),0)::text,
      'still_due', greatest(coalesce(sum(case
        when invoice.status <> 'cancelled'
        then public.v1_accounts_invoice_certified_incl_vat(invoice.id)
          - public.v1_accounts_invoice_paid_amount(invoice.id)
        else 0 end),0),0)::text,
      'pdc_exposure', coalesce(sum(case when invoice.status <> 'cancelled'
        then public.v1_accounts_invoice_pdc_exposure(invoice.id)
        else 0 end),0)::text,
      'recent_invoices', coalesce(jsonb_agg(jsonb_build_object(
        'invoice_id', invoice.id,
        'invoice_reference', invoice.invoice_reference,
        'status', invoice.status,
        'claimed_ex_vat', invoice.claimed_ex_vat::text,
        'certified_incl_vat',
          public.v1_accounts_invoice_certified_incl_vat(invoice.id)::text,
        'amount_paid_till_date',
          public.v1_accounts_invoice_paid_amount(invoice.id)::text,
        'still_due', greatest(
          public.v1_accounts_invoice_certified_incl_vat(invoice.id)
          - public.v1_accounts_invoice_paid_amount(invoice.id),0
        )::text,
        'due_date', invoice.due_date,
        'updated_at', invoice.updated_at
      ) order by invoice.updated_at desc) filter (
        where invoice.id in (select recent.id from (
          select item.id from public.v1_accounts_client_invoices item
          where item.project_id = p_project_id
          order by item.updated_at desc, item.id desc limit 5
        ) recent)
      ), '[]'::jsonb)
    ) into v_invoices
    from public.v1_accounts_client_invoices invoice
    where invoice.project_id = p_project_id;
  end if;

  if v_can_supplier then
    select jsonb_build_object(
      'total_bills', count(*) filter (where bill.status <> 'cancelled'),
      'needs_review', count(*) filter (where bill.status <> 'cancelled'
        and public.v1_accounts_supplier_match_status(bill.id) <> 'matched'),
      'commitments', coalesce(sum(case when bill.status <> 'cancelled'
        then bill.total_incl_vat else 0 end),0)::text,
      'paid', coalesce(sum(case when bill.status <> 'cancelled'
        then public.v1_accounts_supplier_paid_amount(bill.id) else 0 end),0)::text,
      'open_amount', coalesce(sum(case when bill.status <> 'cancelled'
        then greatest(bill.total_incl_vat
          - public.v1_accounts_supplier_paid_amount(bill.id),0)
        else 0 end),0)::text
    ) into v_supplier
    from public.v1_accounts_supplier_bills bill
    where bill.project_id = p_project_id;
  end if;

  v_result := jsonb_build_object(
    'schema_version', 2,
    'project_id', v_project.id,
    'project_reference', v_project.project_ref,
    'project_name', v_project.name,
    'project_site', v_project.project_site,
    'project_state', v_project.state,
    'client_name', (select party.party_name
      from public.v1_project_parties party
      where party.project_id = p_project_id and party.party_kind = 'client'
      limit 1),
    'actor_exact_role', v_exact_role,
    'capabilities', jsonb_build_object(
      'view_project_accounts', v_can_view,
      'view_project_commercial_values', v_can_values,
      'view_supplier_costs', v_can_supplier,
      'suggest_billing_progress', public.v1_current_user_has_capability(
        'suggest_billing_progress', p_project_id
      ),
      'confirm_billing_progress', public.v1_current_user_has_capability(
        'confirm_billing_progress', p_project_id
      ),
      'prepare_client_claim', public.v1_current_user_has_capability(
        'prepare_client_claim', p_project_id
      ),
      'manage_client_invoices', public.v1_current_user_has_capability(
        'manage_client_invoices', p_project_id
      ),
      'manage_supplier_bills', public.v1_current_user_has_capability(
        'manage_supplier_bills', p_project_id
      ),
      'approve_supplier_bill_payment', public.v1_current_user_has_capability(
        'approve_supplier_bill_payment', p_project_id
      ),
      'export_accounts_registers', public.v1_current_user_has_capability(
        'export_accounts_registers', p_project_id
      )
    )
  );
  if v_can_view then
    v_result := v_result || jsonb_build_object(
      'progress', coalesce(v_progress, jsonb_build_object(
        'confirmed_percent','0','suggested_percent','0',
        'pending_review_count',0,'building_position','[]'::jsonb
      ))
    );
    if v_baseline.id is not null then
      v_result := v_result || jsonb_build_object(
        'baseline', jsonb_build_object(
          'revision_id', v_baseline.id,
          'revision_number', v_baseline.revision_number,
          'status', v_baseline.status,
          'effective_at', v_baseline.effective_at
        ) || case when v_can_values then jsonb_build_object(
          'contract_value', v_baseline.contract_value::text,
          'currency_code', v_baseline.currency_code,
          'payment_terms_days', v_baseline.payment_terms_days,
          'reminder_lead_days', v_baseline.reminder_lead_days
        ) else '{}'::jsonb end
      );
    else
      v_result := v_result || jsonb_build_object('baseline', null);
    end if;
  end if;
  if v_can_values then
    v_result := v_result || jsonb_build_object(
      'receivables', coalesce(v_invoices, jsonb_build_object(
        'claimed','0','certified','0','amount_paid_till_date','0',
        'still_due','0','pdc_exposure','0','recent_invoices','[]'::jsonb
      ))
    );
  end if;
  if v_can_supplier then
    v_result := v_result || jsonb_build_object(
      'supplier', coalesce(v_supplier, jsonb_build_object(
        'total_bills',0,'needs_review',0,'commitments','0',
        'paid','0','open_amount','0'
      ))
    );
  end if;
  return v_result;
end;
$$;

revoke all on function public.v1_accounts_portfolio_role_allowed()
  from public, anon, authenticated;
revoke all on function public.v1_get_accounts_portfolio(
  uuid,text,text,text,text,text,text,text,timestamptz,uuid,integer
) from public, anon;
revoke all on function public.v1_get_project_accounts_overview(uuid)
  from public, anon;
grant execute on function public.v1_get_accounts_portfolio(
  uuid,text,text,text,text,text,text,text,timestamptz,uuid,integer
) to authenticated, service_role;
grant execute on function public.v1_get_project_accounts_overview(uuid)
  to authenticated, service_role;

commit;
