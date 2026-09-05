-- Yorks Operational Analytics A03/A04 protected read foundation.
--
-- This migration promotes only analytics.view after installing its sole
-- consumer. The projection is read-only, bounded to 3/6/12 months and returns
-- no commercial, salary, document, worker-detail or inventory-value fields.
-- Every included domain is intersected with its existing authority.
--
-- Data preservation: no operational fact is inserted, updated or deleted.
-- Rollback is forward-only: disable YORKS_V1_ANALYTICS and, if containment is
-- required, revoke authenticated execution in a corrective migration. Retain
-- capability assignments and permission history.

begin;

update public.v1_capability_catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true
where capability_key = 'analytics.view'
  and status = 'planned'
  and authorization_mode = 'shadow'
  and not is_assignable;

update public.v1_permission_role_defaults
set is_granted = (role_name = 'admin'),
    can_delegate = (role_name = 'admin'),
    updated_at = statement_timestamp()
where capability_key = 'analytics.view';

create or replace function public.v1_get_operational_analytics_foundation(
  p_project_id uuid default null,
  p_months integer default 6
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_generated_at timestamptz := statement_timestamp();
  v_month_start date := date_trunc(
    'month', statement_timestamp() at time zone 'UTC'
  )::date;
  v_projects_available boolean;
  v_requests_available boolean;
  v_accounts_available boolean;
  v_workforce_available boolean;
  v_rentals_available boolean;
  v_inventory_available boolean;
  v_audit_available boolean;
  v_projects jsonb;
  v_material_requests jsonb;
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
  v_accounts_available :=
    public.v1_current_user_has_capability('view_project_accounts', null);
  v_workforce_available :=
    public.v1_current_user_has_capability('workforce.view', null);
  v_rentals_available :=
    public.v1_current_user_has_capability('rentals.view', null);
  v_inventory_available :=
    public.v1_current_user_has_capability('inventory.view', null);
  v_audit_available :=
    public.v1_current_user_has_capability('audit.view', null);

  if v_projects_available then
    with readable as materialized (
      select project.id, project.state
      from public.v1_projects project
      where (p_project_id is null or project.id = p_project_id)
        and public.v1_project_readable(project.id)
    )
    select jsonb_build_object(
      'total', count(*),
      'draft', count(*) filter (where state = 'draft'),
      'active', count(*) filter (where state = 'active'),
      'on_hold', count(*) filter (where state = 'on_hold'),
      'completed', count(*) filter (where state = 'completed'),
      'archived', count(*) filter (where state = 'archived')
    )
    into v_projects
    from readable;
  else
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied',
      'domain', 'projects'
    ));
  end if;

  if v_requests_available then
    with readable as materialized (
      select
        request_record.id,
        request_record.project_id,
        request_record.state,
        request_record.submitted_at
      from public.v1_material_requests request_record
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
          where state not in ('closed', 'cancelled')
            and public.v1_material_request_actor_has_current_action(id)
        ),
        'drafts', count(*) filter (where state = 'draft'),
        'awaiting_engineering_approval', count(*) filter (
          where state in ('awaiting_request_approval', 'awaiting_approval')
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
    )
    select current_counts.value || jsonb_build_object(
      'monthly_flow', monthly_flow.value
    )
    into v_material_requests
    from current_counts
    cross join monthly_flow;
  else
    v_warnings := v_warnings || jsonb_build_array(jsonb_build_object(
      'code', 'domain_denied',
      'domain', 'material_requests'
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
      'state', case when v_accounts_available then 'source_only' else 'denied' end,
      'reason', case when v_accounts_available then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    ),
    'workforce', jsonb_build_object(
      'state', case when v_workforce_available then 'source_only' else 'denied' end,
      'reason', case when v_workforce_available then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    ),
    'rentals', jsonb_build_object(
      'state', case when v_rentals_available then 'source_only' else 'denied' end,
      'reason', case when v_rentals_available then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    ),
    'inventory', jsonb_build_object(
      'state', case when v_inventory_available then 'source_only' else 'denied' end,
      'reason', case when v_inventory_available then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    ),
    'audit', jsonb_build_object(
      'state', case when v_audit_available then 'source_only' else 'denied' end,
      'reason', case when v_audit_available then 'separate_protected_workspace'
        else 'missing_domain_capability' end
    )
  );

  v_result := jsonb_build_object(
    'schema_version', 1,
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
      select 1
      from jsonb_each(v_coverage) coverage_entry
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

  return v_result;
end;
$$;

comment on function public.v1_get_operational_analytics_foundation(uuid, integer)
is 'Schema-v1 read-only operational Analytics projection. analytics.view only opens the workspace; each payload is independently intersected with its source-domain authority.';

revoke all on function public.v1_get_operational_analytics_foundation(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.v1_get_operational_analytics_foundation(uuid, integer)
  to authenticated, service_role;

do $$
begin
  if not exists (
    select 1
    from public.v1_capability_catalog capability
    where capability.capability_key = 'analytics.view'
      and capability.status = 'operational'
      and capability.authorization_mode = 'enforced'
      and capability.is_assignable
  ) then
    raise exception 'YORKS_ANALYTICS_VIEW_CUTOVER_MISMATCH';
  end if;

  if not exists (
    select 1
    from public.v1_permission_role_defaults role_default
    where role_default.role_name = 'admin'
      and role_default.capability_key = 'analytics.view'
      and role_default.is_granted
      and role_default.can_delegate
  ) or exists (
    select 1
    from public.v1_permission_role_defaults role_default
    where role_default.role_name <> 'admin'
      and role_default.capability_key = 'analytics.view'
      and (role_default.is_granted or role_default.can_delegate)
  ) then
    raise exception 'YORKS_ANALYTICS_VIEW_ROLE_DEFAULT_MISMATCH';
  end if;

  if exists (
    select 1
    from public.v1_capability_catalog capability
    where capability.capability_key = 'analytics.export'
      and (
        capability.status <> 'planned'
        or capability.authorization_mode <> 'shadow'
        or capability.is_assignable
      )
  ) then
    raise exception 'YORKS_ANALYTICS_EXPORT_MUST_REMAIN_DISABLED';
  end if;
end;
$$;

select pg_notify('pgrst', 'reload schema');

commit;
