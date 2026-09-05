-- Yorks Operational Analytics company view.
--
-- This forward-only, read-only slice extends the accepted Analytics foundation
-- with bounded, server-authoritative Accounts, Workforce and Rentals summaries,
-- an actionable Material Request queue and a Project review register.  It never
-- grants source-domain authority: every payload remains the intersection of
-- analytics.view and the source module's existing protected authority.
--
-- Money is returned as decimal text and grouped by ISO currency.  Workforce
-- time comes only from the latest approved snapshot for each monthly period.
-- Rental output is aggregate-only and contains no tenant, cheque or contact
-- detail.  No operational row is inserted, updated or deleted.
--
-- Rollback: disable YORKS_V1_ANALYTICS and restore the schema-v1 projection in
-- a corrective migration.  Retain all capabilities and operational history.

begin;

create or replace function public.v1_get_operational_analytics_foundation(
  p_project_id uuid default null,
  p_months integer default 6
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_permission_exact_role(auth.uid());
  v_generated_at timestamptz := statement_timestamp();
  v_as_of_date date := (statement_timestamp() at time zone 'UTC')::date;
  v_month_start date := date_trunc(
    'month', statement_timestamp() at time zone 'UTC'
  )::date;
  v_projects_available boolean;
  v_requests_available boolean;
  v_accounts_available boolean;
  v_workforce_source_available boolean;
  v_workforce_available boolean;
  v_rentals_source_available boolean;
  v_rentals_available boolean;
  v_inventory_available boolean;
  v_audit_available boolean;
  v_projects jsonb;
  v_material_requests jsonb;
  v_accounts jsonb;
  v_workforce jsonb;
  v_rentals jsonb;
  v_workforce_overview jsonb;
  v_rental_portfolio jsonb;
  v_coverage jsonb;
  v_warnings jsonb := '[]'::jsonb;
  v_result jsonb;
begin
  if v_actor is null
    or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability('analytics.view', null) then
    raise exception 'YORKS_OPERATIONAL_ANALYTICS_DENIED'
      using errcode = '42501';
  end if;

  if p_months is null or p_months not in (3, 6, 12) then
    raise exception 'YORKS_OPERATIONAL_ANALYTICS_MONTHS_INVALID'
      using errcode = '22023';
  end if;

  if p_project_id is not null and not public.v1_project_readable(p_project_id)
  then
    raise exception 'YORKS_OPERATIONAL_ANALYTICS_PROJECT_DENIED'
      using errcode = '42501';
  end if;

  v_projects_available :=
    public.v1_current_user_has_capability('projects.view', null);
  v_requests_available :=
    public.v1_current_user_has_capability('material_requests.view', null);
  v_accounts_available := public.v1_accounts_portfolio_role_allowed()
    and (
      p_project_id is null
      or (
        public.v1_current_user_has_capability(
          'view_project_accounts', p_project_id
        )
        and public.v1_current_user_has_capability(
          'view_project_commercial_values', p_project_id
        )
      )
    );
  v_workforce_source_available :=
    public.v1_workforce_t10_organization_authorized('workforce.view');
  v_workforce_available := v_role = 'admin'
    and p_project_id is null
    and v_workforce_source_available;
  v_rentals_source_available := v_role = 'admin';
  v_rentals_available := v_rentals_source_available
    and p_project_id is null;
  v_inventory_available :=
    public.v1_current_user_has_capability('inventory.view', null);
  v_audit_available :=
    public.v1_current_user_has_capability('audit.view', null);

  if v_projects_available then
    with readable as materialized (
      select
        project.id,
        project.project_ref,
        project.name,
        project.project_site,
        project.state,
        project.current_action_owner_role,
        project.start_date,
        project.target_completion_date,
        project.updated_at
      from public.v1_projects project
      where (p_project_id is null or project.id = p_project_id)
        and public.v1_project_readable(project.id)
    ), facts as materialized (
      select readable.*,
        coalesce(requests.open_count, 0) as open_request_count,
        coalesce(requests.action_count, 0) as request_action_count,
        greatest(
          readable.updated_at,
          coalesce(requests.latest_at, '-infinity'::timestamptz)
        ) as latest_activity_at
      from readable
      left join lateral (
        select
          count(*) filter (
            where request.state <> 'draft'
              and request.state not in ('received', 'closed', 'cancelled')
          ) as open_count,
          count(*) filter (
            where request.state not in ('closed', 'cancelled')
              and public.v1_material_request_actor_has_current_action(
                request.id
              )
          ) as action_count,
          max(request.updated_at) as latest_at
        from public.v1_material_requests request
        where request.project_id = readable.id
          and public.v1_material_request_participant(request.id, v_actor)
      ) requests on true
    )
    select jsonb_build_object(
      'total', count(*),
      'draft', count(*) filter (where state = 'draft'),
      'active', count(*) filter (where state = 'active'),
      'on_hold', count(*) filter (where state = 'on_hold'),
      'completed', count(*) filter (where state = 'completed'),
      'archived', count(*) filter (where state = 'archived'),
      'register', coalesce((
        select jsonb_agg(jsonb_build_object(
          'project_id', facts.id,
          'project_reference', facts.project_ref,
          'project_name', facts.name,
          'project_site', facts.project_site,
          'state', facts.state,
          'current_owner_role', facts.current_action_owner_role,
          'start_date', facts.start_date,
          'target_completion_date', facts.target_completion_date,
          'open_request_count', facts.open_request_count,
          'request_action_count', facts.request_action_count,
          'latest_activity_at', facts.latest_activity_at
        ) order by
          facts.request_action_count desc,
          facts.open_request_count desc,
          facts.latest_activity_at desc,
          facts.id
        ) from (select * from facts limit 100) facts
      ), '[]'::jsonb)
    )
    into v_projects
    from readable;
  else
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied', 'domain', 'projects'
    ));
  end if;

  if v_requests_available then
    with readable as materialized (
      select
        request_record.id,
        request_record.project_id,
        request_record.state,
        request_record.request_number,
        request_record.title,
        request_record.timing,
        request_record.scheduled_date,
        request_record.current_action_owner_role,
        request_record.current_action_code,
        request_record.submitted_at,
        request_record.updated_at,
        project.project_ref,
        project.name as project_name,
        public.v1_material_request_actor_has_current_action(
          request_record.id
        ) as actor_can_act,
        public.v1_material_request_exception_codes(
          request_record.id
        ) as exception_codes
      from public.v1_material_requests request_record
      join public.v1_projects project on project.id = request_record.project_id
      where (p_project_id is null or request_record.project_id = p_project_id)
        and public.v1_material_request_participant(
          request_record.id, v_actor
        )
    ), current_counts as (
      select jsonb_build_object(
        'total', count(*),
        'open', count(*) filter (
          where state <> 'draft'
            and state not in ('received', 'closed', 'cancelled')
        ),
        'needs_action', count(*) filter (
          where state not in ('closed', 'cancelled') and actor_can_act
        ),
        'drafts', count(*) filter (where state = 'draft'),
        'awaiting_engineering_approval', count(*) filter (
          where state in (
            'submitted', 'awaiting_request_approval', 'awaiting_approval'
          )
        ),
        'to_arrange', count(*) filter (
          where state in ('approved_for_arrangement', 'arranging')
        ),
        'changes_requested', count(*) filter (
          where state = 'changes_requested'
        ),
        'dispatch_ready', count(*) filter (
          where state in ('approved', 'partially_dispatched')
        ),
        'receipt_pending', count(*) filter (
          where state in ('dispatched', 'partially_received')
        ),
        'delivery_exceptions', count(*) filter (
          where state in (
            'changes_requested', 'partially_dispatched',
            'partially_received'
          )
        ),
        'received', count(*) filter (where state = 'received'),
        'closed', count(*) filter (where state = 'closed'),
        'cancelled', count(*) filter (where state = 'cancelled')
      ) as value
      from readable
    ), month_bucket as (
      select (
        v_month_start - make_interval(months => month_offset)
      )::date as starts_on
      from generate_series(0, p_months - 1) month_offset
    ), monthly_flow as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'month', to_char(month_bucket.starts_on, 'YYYY-MM'),
        'submitted', (
          select count(*)
          from readable request_record
          where request_record.submitted_at >=
              (month_bucket.starts_on::timestamp at time zone 'UTC')
            and request_record.submitted_at <
              ((month_bucket.starts_on + interval '1 month')::timestamp
                at time zone 'UTC')
        ),
        'closed', (
          select count(distinct request_record.id)
          from readable request_record
          join public.v1_audit_events audit
            on audit.entity_type = 'material_request'
           and audit.entity_id = request_record.id
           and audit.event_type = 'material_request_closed'
          where audit.occurred_at >=
              (month_bucket.starts_on::timestamp at time zone 'UTC')
            and audit.occurred_at <
              ((month_bucket.starts_on + interval '1 month')::timestamp
                at time zone 'UTC')
        )
      ) order by month_bucket.starts_on), '[]'::jsonb) as value
      from month_bucket
    ), attention as (
      select coalesce(jsonb_agg(jsonb_build_object(
        'request_id', item.id,
        'request_number', item.request_number,
        'title', item.title,
        'project_id', item.project_id,
        'project_reference', item.project_ref,
        'project_name', item.project_name,
        'state', item.state,
        'timing', item.timing,
        'scheduled_date', item.scheduled_date,
        'current_owner_role', item.current_action_owner_role,
        'next_action_code', item.current_action_code,
        'actor_can_act', item.actor_can_act,
        'exception_codes', to_jsonb(item.exception_codes),
        'age_hours', greatest(
          extract(epoch from (v_generated_at - item.updated_at)) / 3600,
          0
        ),
        'updated_at', item.updated_at
      ) order by
        item.actor_can_act desc,
        (item.timing = 'urgent') desc,
        (item.timing = 'scheduled'
          and item.scheduled_date < v_as_of_date) desc,
        item.updated_at,
        item.id), '[]'::jsonb) as value
      from (
        select *
        from readable
        where state not in ('closed', 'cancelled')
          and (actor_can_act or cardinality(exception_codes) > 0)
        order by
          actor_can_act desc,
          (timing = 'urgent') desc,
          (timing = 'scheduled' and scheduled_date < v_as_of_date) desc,
          updated_at,
          id
        limit 12
      ) item
    )
    select current_counts.value || jsonb_build_object(
      'monthly_flow', monthly_flow.value,
      'attention', attention.value
    )
    into v_material_requests
    from current_counts
    cross join monthly_flow
    cross join attention;
  else
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied', 'domain', 'material_requests'
    ));
  end if;

  if v_accounts_available then
    with authorized as materialized (
      select
        project.id,
        baseline.currency_code,
        baseline.contract_value
      from public.v1_projects project
      left join public.v1_accounts_project_commercial_profiles profile
        on profile.project_id = project.id
      left join public.v1_accounts_baseline_revisions baseline
        on baseline.id = profile.current_baseline_revision_id
      where (p_project_id is null or project.id = p_project_id)
        and public.v1_current_user_has_capability(
          'view_project_accounts', project.id
        )
        and public.v1_current_user_has_capability(
          'view_project_commercial_values', project.id
        )
    ), project_facts as materialized (
      select authorized.*,
        coalesce(invoice.claimed, 0::numeric) as claimed,
        coalesce(invoice.certified, 0::numeric) as certified,
        coalesce(invoice.received, 0::numeric) as received,
        coalesce(invoice.overdue_count, 0) as overdue_count,
        coalesce(invoice.due_soon_count, 0) as due_soon_count,
        coalesce(invoice.returned_count, 0) as returned_count,
        coalesce(pdc.attention_count, 0) as pdc_attention_count
      from authorized
      left join lateral (
        select
          coalesce(sum(case when source.status not in (
            'draft', 'returned', 'cancelled'
          ) then source.claimed_ex_vat else 0 end), 0) as claimed,
          coalesce(sum(case when source.status <> 'cancelled'
            then public.v1_accounts_invoice_certified_incl_vat(source.id)
            else 0 end), 0) as certified,
          coalesce(sum(case when source.status <> 'cancelled'
            then public.v1_accounts_invoice_paid_amount(source.id)
            else 0 end), 0) as received,
          count(*) filter (
            where source.due_date < v_as_of_date
              and source.status not in (
                'draft', 'returned', 'cancelled', 'paid'
              )
          ) as overdue_count,
          count(*) filter (
            where source.due_date >= v_as_of_date
              and source.due_date <= v_as_of_date
                + source.reminder_lead_days_snapshot
              and source.status not in (
                'draft', 'returned', 'cancelled', 'paid'
              )
          ) as due_soon_count,
          count(*) filter (where source.status = 'returned') as returned_count
        from public.v1_accounts_client_invoices source
        where source.project_id = authorized.id
      ) invoice on true
      left join lateral (
        select count(*) filter (where source.action_required) as attention_count
        from public.v1_accounts_client_pdcs source
        where source.project_id = authorized.id
      ) pdc on true
    ), currency_totals as materialized (
      select
        currency_code,
        count(*) as project_count,
        sum(contract_value) as contract_value,
        sum(claimed) as claimed,
        sum(certified) as certified,
        sum(received) as received,
        sum(greatest(certified - received, 0::numeric)) as outstanding,
        sum(overdue_count) as overdue_count,
        sum(due_soon_count) as due_soon_count,
        sum(returned_count) as returned_count,
        sum(pdc_attention_count) as pdc_attention_count
      from project_facts
      where currency_code is not null
      group by currency_code
    ), month_bucket as (
      select (
        v_month_start - make_interval(months => month_offset)
      )::date as starts_on
      from generate_series(0, p_months - 1) month_offset
    ), currency_rows as (
      select currency_totals.*,
        coalesce((select jsonb_agg(jsonb_build_object(
          'month', to_char(month_bucket.starts_on, 'YYYY-MM'),
          'claimed', (
            select coalesce(sum(invoice.claimed_ex_vat), 0)::text
            from public.v1_accounts_client_invoices invoice
            join authorized project on project.id = invoice.project_id
            where project.currency_code = currency_totals.currency_code
              and invoice.status not in ('draft', 'returned', 'cancelled')
              and invoice.submitted_at >=
                (month_bucket.starts_on::timestamp at time zone 'UTC')
              and invoice.submitted_at <
                ((month_bucket.starts_on + interval '1 month')::timestamp
                  at time zone 'UTC')
          ),
          'certified', (
            select coalesce(sum(latest.certified_incl_vat), 0)::text
            from (
              select distinct on (certification.invoice_id)
                certification.invoice_id,
                certification.certification_date,
                certification.certified_incl_vat
              from public.v1_accounts_client_certifications certification
              join public.v1_accounts_client_invoices invoice
                on invoice.id = certification.invoice_id
               and invoice.status <> 'cancelled'
              join authorized project on project.id = invoice.project_id
              where project.currency_code = currency_totals.currency_code
              order by certification.invoice_id,
                certification.revision_number desc
            ) latest
            where latest.certification_date >= month_bucket.starts_on
              and latest.certification_date <
                month_bucket.starts_on + interval '1 month'
          ),
          'received', (
            select coalesce(sum(case when payment.entry_kind = 'receipt'
              then payment.amount else -payment.amount end), 0)::text
            from public.v1_accounts_client_payments payment
            join public.v1_accounts_client_invoices invoice
              on invoice.id = payment.invoice_id
             and invoice.status <> 'cancelled'
            join authorized project on project.id = payment.project_id
            where project.currency_code = currency_totals.currency_code
              and payment.payment_date >= month_bucket.starts_on
              and payment.payment_date <
                month_bucket.starts_on + interval '1 month'
          )
        ) order by month_bucket.starts_on) from month_bucket), '[]'::jsonb)
          as monthly_flow
      from currency_totals
    )
    select jsonb_build_object(
      'currency_groups', coalesce((select jsonb_agg(jsonb_build_object(
        'currency_code', currency_rows.currency_code,
        'project_count', currency_rows.project_count,
        'contract_value', currency_rows.contract_value::text,
        'claimed', currency_rows.claimed::text,
        'certified', currency_rows.certified::text,
        'received', currency_rows.received::text,
        'outstanding', currency_rows.outstanding::text,
        'overdue_count', currency_rows.overdue_count,
        'due_soon_count', currency_rows.due_soon_count,
        'returned_count', currency_rows.returned_count,
        'pdc_attention_count', currency_rows.pdc_attention_count,
        'monthly_flow', currency_rows.monthly_flow
      ) order by currency_rows.currency_code) from currency_rows), '[]'::jsonb),
      'authorized_project_count', (select count(*) from authorized),
      'unconfigured_project_count', (
        select count(*) from authorized where currency_code is null
      ),
      'attention_count', coalesce((select sum(
        overdue_count + due_soon_count + returned_count + pdc_attention_count
      ) from project_facts), 0)
    ) into v_accounts;
  else
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied', 'domain', 'accounts'
    ));
  end if;

  if v_workforce_available then
    v_workforce_overview := public.v1_get_workforce_overview(
      jsonb_build_object('overview_kind', 'admin')
    );
    with latest_snapshot as materialized (
      select distinct on (snapshot.period_id)
        snapshot.period_id,
        snapshot.validation_run_id,
        snapshot.approval_revision_number
      from public.v1_workforce_monthly_approved_snapshots snapshot
      order by snapshot.period_id, snapshot.approval_revision_number desc
    ), confirmed as materialized (
      select period.period_month,
        validation.regular_minutes,
        validation.overtime_minutes
      from latest_snapshot snapshot
      join public.v1_workforce_monthly_periods period
        on period.id = snapshot.period_id
      join public.v1_workforce_monthly_validation_runs validation
        on validation.id = snapshot.validation_run_id
      where period.period_month >=
        (v_month_start - make_interval(months => p_months - 1))::date
        and period.period_month <
          (v_month_start + interval '1 month')::date
    ), month_bucket as (
      select (
        v_month_start - make_interval(months => month_offset)
      )::date as starts_on
      from generate_series(0, p_months - 1) month_offset
    )
    select jsonb_build_object(
      'active_worker_count',
        (v_workforce_overview #>> '{summary,active_worker_count}')::integer,
      'active_supervisor_count',
        (v_workforce_overview #>> '{summary,active_supervisor_count}')::integer,
      'missing_today_count',
        (v_workforce_overview #>> '{summary,missing_today_count}')::integer,
      'monthly_pending_count',
        (v_workforce_overview #>> '{summary,monthly_pending_count}')::integer,
      'returned_count',
        (v_workforce_overview #>> '{summary,returned_count}')::integer,
      'awaiting_final_count',
        (v_workforce_overview #>> '{summary,awaiting_final_count}')::integer,
      'locked_count',
        (v_workforce_overview #>> '{summary,locked_count}')::integer,
      'reopen_request_count',
        (v_workforce_overview #>> '{summary,reopen_request_count}')::integer,
      'configuration_issue_count',
        (v_workforce_overview #>> '{summary,configuration_issue_count}')::integer,
      'confirmed_period_count', (select count(*) from confirmed),
      'confirmed_regular_minutes',
        (select coalesce(sum(regular_minutes), 0) from confirmed),
      'confirmed_overtime_minutes',
        (select coalesce(sum(overtime_minutes), 0) from confirmed),
      'monthly_flow', coalesce((select jsonb_agg(jsonb_build_object(
        'month', to_char(month_bucket.starts_on, 'YYYY-MM'),
        'regular_minutes', coalesce((select sum(regular_minutes)
          from confirmed
          where period_month = month_bucket.starts_on), 0),
        'overtime_minutes', coalesce((select sum(overtime_minutes)
          from confirmed
          where period_month = month_bucket.starts_on), 0)
      ) order by month_bucket.starts_on) from month_bucket), '[]'::jsonb)
    ) into v_workforce;
  elsif not v_workforce_source_available then
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied', 'domain', 'workforce'
    ));
  end if;

  if v_rentals_available then
    v_rental_portfolio := public.v1_get_rental_portfolio();
    with month_bucket as (
      select (
        v_month_start - make_interval(months => month_offset)
      )::date as starts_on
      from generate_series(0, p_months - 1) month_offset
    )
    select jsonb_build_object(
      'currency_code', 'AED',
      'total_properties',
        (v_rental_portfolio #>> '{summary,total_properties}')::integer,
      'occupied',
        (v_rental_portfolio #>> '{summary,occupied}')::integer,
      'monthly_rent_roll',
        v_rental_portfolio #>> '{summary,monthly_rent_roll}',
      'collected_this_month',
        v_rental_portfolio #>> '{summary,collected_this_month}',
      'outstanding', v_rental_portfolio #>> '{summary,outstanding}',
      'security_deposits',
        v_rental_portfolio #>> '{summary,security_deposits}',
      'expiring_within_90',
        (v_rental_portfolio #>> '{summary,expiring_within_90}')::integer,
      'cheque_attention',
        (v_rental_portfolio #>> '{summary,cheque_attention}')::integer,
      'monthly_flow', coalesce((select jsonb_agg(jsonb_build_object(
        'month', to_char(month_bucket.starts_on, 'YYYY-MM'),
        'collected', (select coalesce(sum(receipt.amount_received), 0)::text
          from public.v1_rental_receipts receipt
          where receipt.payment_date >= month_bucket.starts_on
            and receipt.payment_date <
              month_bucket.starts_on + interval '1 month')
      ) order by month_bucket.starts_on) from month_bucket), '[]'::jsonb)
    ) into v_rentals;
  elsif not v_rentals_source_available then
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied', 'domain', 'rentals'
    ));
  end if;

  v_coverage := jsonb_build_object(
    'projects', jsonb_build_object(
      'state', case when v_projects_available then 'available' else 'denied' end,
      'reason', case when v_projects_available then null
        else 'missing_domain_capability' end
    ),
    'material_requests', jsonb_build_object(
      'state', case when v_requests_available then 'available' else 'denied' end,
      'reason', case when v_requests_available then null
        else 'missing_domain_capability' end
    ),
    'accounts', jsonb_build_object(
      'state', case when v_accounts_available then 'available' else 'denied' end,
      'reason', case when v_accounts_available then null
        else 'missing_source_authority' end
    ),
    'workforce', jsonb_build_object(
      'state', case when v_workforce_available then 'available'
        when v_workforce_source_available then 'source_only' else 'denied' end,
      'reason', case when v_workforce_available then null
        when v_workforce_source_available and p_project_id is not null
          then 'not_project_scoped'
        when v_workforce_source_available then 'source_workspace_required'
        else 'missing_source_authority' end
    ),
    'rentals', jsonb_build_object(
      'state', case when v_rentals_available then 'available'
        when v_rentals_source_available then 'source_only' else 'denied' end,
      'reason', case when v_rentals_available then null
        when v_rentals_source_available then 'not_project_scoped'
        else 'missing_source_authority' end
    ),
    'inventory', jsonb_build_object(
      'state', case when v_inventory_available then 'source_only'
        else 'denied' end,
      'reason', case when v_inventory_available
        then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    ),
    'audit', jsonb_build_object(
      'state', case when v_audit_available then 'source_only'
        else 'denied' end,
      'reason', case when v_audit_available
        then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    )
  );

  v_result := jsonb_build_object(
    'schema_version', 2,
    'generated_at', v_generated_at,
    'requested_filters', jsonb_build_object(
      'project_id', p_project_id,
      'months', p_months
    ),
    'effective_filters', jsonb_build_object(
      'project_id', p_project_id,
      'months', p_months,
      'timezone', 'UTC'
    ),
    'as_of', jsonb_build_object(
      'timezone', 'UTC',
      'local_date', (v_generated_at at time zone 'UTC')::date,
      'month_count', p_months
    ),
    'coverage', v_coverage,
    'is_partial', exists (
      select 1 from jsonb_each(v_coverage) coverage_entry
      where coverage_entry.value ->> 'state' <> 'available'
    ),
    'warnings', v_warnings
  );

  if v_projects_available then
    v_result := v_result || jsonb_build_object('projects', v_projects);
  end if;
  if v_requests_available then
    v_result := v_result || jsonb_build_object(
      'material_requests', v_material_requests
    );
  end if;
  if v_accounts_available then
    v_result := v_result || jsonb_build_object('accounts', v_accounts);
  end if;
  if v_workforce_available then
    v_result := v_result || jsonb_build_object('workforce', v_workforce);
  end if;
  if v_rentals_available then
    v_result := v_result || jsonb_build_object('rentals', v_rentals);
  end if;

  return v_result;
end;
$$;

comment on function public.v1_get_operational_analytics_foundation(uuid, integer)
is 'Schema-v2 read-only company Analytics projection. Source capability, record scope, currency boundaries and approved Workforce evidence remain authoritative.';

revoke all on function public.v1_get_operational_analytics_foundation(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.v1_get_operational_analytics_foundation(uuid, integer)
  to authenticated, service_role;

select pg_notify('pgrst', 'reload schema');

commit;
