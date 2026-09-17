-- Additive Admin-only audit investigation and bounded immutable exports.
-- Preserves all source events and the V1 read RPC. No historical rewrites.
-- Rollback: revoke new RPCs; retain export receipts and original ledger.
begin;
-- Versioned presentation catalogue; preserves prior classifications for known
-- emitted event names. New event names remain explicitly unclassified.
create table if not exists public.v1_audit_event_catalogue (
  event_type text primary key,
  severity text not null check (severity in ('normal','warning','critical'))
);
alter table public.v1_audit_event_catalogue enable row level security;
revoke all on public.v1_audit_event_catalogue from public,anon,authenticated;
insert into public.v1_audit_event_catalogue(event_type,severity) values
  ('accounts.client_certification.recorded', 'normal'),
  ('accounts.client_claim.cancelled', 'critical'),
  ('accounts.client_claim.created', 'normal'),
  ('accounts.client_claim.deleted', 'critical'),
  ('accounts.client_claim.ready_for_accounts', 'normal'),
  ('accounts.client_claim.updated', 'normal'),
  ('accounts.client_invoice.', 'normal'),
  ('accounts.client_invoice.draft_created', 'normal'),
  ('accounts.client_invoice.draft_updated', 'normal'),
  ('accounts.client_invoice.submitted', 'normal'),
  ('accounts.client_payment.recorded', 'normal'),
  ('accounts.client_payment.reversed', 'normal'),
  ('accounts.client_pdc.', 'normal'),
  ('accounts.client_pdc.created', 'normal'),
  ('accounts.client_pdc.replaced', 'normal'),
  ('accounts.export.generated', 'normal'),
  ('accounts.supplier_bill.approved', 'normal'),
  ('accounts.supplier_bill.cancelled', 'critical'),
  ('accounts.supplier_bill.created', 'normal'),
  ('accounts.supplier_bill.updated', 'normal'),
  ('accounts.supplier_payment.recorded', 'normal'),
  ('accounts.supplier_payment.reversed', 'normal'),
  ('accounts_baseline_initialized', 'normal'),
  ('accounts_baseline_revised', 'normal'),
  ('accounts_progress_confirmed', 'normal'),
  ('accounts_progress_reviewed', 'normal'),
  ('accounts_progress_suggested', 'normal'),
  ('arrangement_begun', 'normal'),
  ('arrangement_reservations_released', 'warning'),
  ('arrangement_saved', 'normal'),
  ('audit_export_generated', 'normal'),
  ('boq_group_archived', 'critical'),
  ('boq_group_created', 'normal'),
  ('boq_group_renamed', 'normal'),
  ('boq_group_restored', 'normal'),
  ('boq_group_scope_assigned', 'normal'),
  ('boq_group_scope_placeholder_superseded', 'warning'),
  ('boq_import_committed', 'normal'),
  ('boq_worksheet_saved', 'normal'),
  ('chat_conversation_created', 'normal'),
  ('chat_group_updated', 'normal'),
  ('chat_message_deleted', 'critical'),
  ('chat_message_edited', 'normal'),
  ('chat_message_sent', 'normal'),
  ('commercial_capability_changed', 'normal'),
  ('company_request_submitted', 'normal'),
  ('configuration_published', 'normal'),
  ('document_link_removed', 'critical'),
  ('document_linked', 'normal'),
  ('external_source_readiness_saved', 'normal'),
  ('inventory_adjusted', 'warning'),
  ('inventory_category_alias_created', 'normal'),
  ('inventory_category_created', 'normal'),
  ('inventory_imported', 'normal'),
  ('inventory_item_created', 'normal'),
  ('inventory_item_metadata_updated', 'normal'),
  ('inventory_supplier_imported', 'normal'),
  ('material_request_approved', 'normal'),
  ('material_request_cancelled', 'critical'),
  ('material_request_closed', 'normal'),
  ('material_request_commented', 'normal'),
  ('material_request_replacement_draft_created', 'normal'),
  ('material_request_submitted', 'normal'),
  ('material_request_updated_for_approval', 'normal'),
  ('material_return_', 'normal'),
  ('material_return_cancelled', 'critical'),
  ('material_return_confirmed', 'normal'),
  ('material_return_dispatched', 'normal'),
  ('material_return_draft_saved', 'normal'),
  ('material_return_rejected', 'critical'),
  ('material_return_submitted', 'normal'),
  ('material_return_submitted_for_approval', 'normal'),
  ('materials_dispatched', 'normal'),
  ('permission_assignments_changed', 'normal'),
  ('preapproved_arrangement_finalized', 'normal'),
  ('procurement_item_clarified', 'normal'),
  ('project_archived', 'critical'),
  ('project_created', 'normal'),
  ('project_member_assigned', 'normal'),
  ('project_member_revoked', 'normal'),
  ('project_state_changed', 'normal'),
  ('project_updated', 'normal'),
  ('receipt_review_confirmed', 'normal'),
  ('rent_payment_recorded', 'normal'),
  ('rental_cheque_saved', 'normal'),
  ('rental_cheque_status_changed', 'normal'),
  ('rental_property_archived', 'critical'),
  ('rental_workbook_imported', 'normal'),
  ('report_generated', 'normal'),
  ('supplier_created', 'normal'),
  ('supplier_mapping_accepted', 'normal'),
  ('supplier_receipt_committed', 'normal'),
  ('workforce_attendance_overtime_reason_updated', 'normal'),
  ('workforce_daily_roster_saved', 'normal'),
  ('workforce_export_generated', 'normal'),
  ('workforce_monthly_period_approved_and_locked', 'normal'),
  ('workforce_monthly_period_returned', 'warning'),
  ('workforce_monthly_period_submitted', 'normal'),
  ('workforce_monthly_period_validated', 'normal'),
  ('workforce_monthly_period_verified', 'normal'),
  ('workforce_monthly_reopen_authorized', 'normal'),
  ('workforce_monthly_reopen_requested', 'normal'),
  ('workforce_monthly_reviewer_correction', 'normal'),
  ('workforce_timesheet_allocations_saved', 'normal'),
  ('workforce_timesheet_allocations_withdrawn', 'normal'),
  ('workforce_worker_assignment_transferred', 'normal')
on conflict (event_type) do nothing;
create index if not exists v1_audit_entity_time_idx on public.v1_audit_events(entity_type,entity_id,occurred_at desc,id desc);
create or replace function public.v1_get_audit_workspace_v2(
  p_search text default null,
  p_module text default null,
  p_quick_filter text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 12,
  p_offset integer default 0,
  p_actor uuid default null,
  p_project uuid default null,
  p_event_type text default null,
  p_severity text default null,
  p_entity_id uuid default null,
  p_entity_type text default null,
  p_scope text default null,
  p_as_of timestamptz default null,
  p_cursor_at timestamptz default null,
  p_cursor_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_module text := nullif(btrim(coalesce(p_module, '')), '');
  v_quick_filter text := nullif(btrim(coalesce(p_quick_filter, '')), '');
  v_limit integer := least(greatest(coalesce(p_limit, 12), 1), 5001);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_result jsonb;
begin
  if auth.uid() is null
    or public.v1_current_exact_role() <> 'admin'
    or not public.v1_current_actor_is_active()
  then
    raise exception 'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  if v_module is not null and v_module not in (
    'projects', 'material_requests', 'logistics', 'inventory', 'rentals',
    'users', 'documents', 'system', 'accounts', 'workforce', 'configuration'
  ) then
    raise exception 'V1_AUDIT_WORKSPACE_MODULE_INVALID'
      using errcode = '22023';
  end if;
  if v_quick_filter is not null and v_quick_filter not in (
    'critical', 'exceptions', 'data_changes', 'approvals', 'access'
  ) then
    raise exception 'V1_AUDIT_WORKSPACE_FILTER_INVALID'
      using errcode = '22023';
  end if;
  if p_from is not null and p_to is not null and p_to < p_from then
    raise exception 'V1_AUDIT_WORKSPACE_DATE_RANGE_INVALID'
      using errcode = '22023';
  end if;

  if p_severity is not null and p_severity not in ('normal','warning','critical','unclassified') then
    raise exception 'V1_AUDIT_FILTER_INVALID' using errcode = '22023';
  end if;
  if p_scope is not null and p_scope not in ('project','company','organization') then
    raise exception 'V1_AUDIT_FILTER_INVALID' using errcode = '22023';
  end if;
  if length(coalesce(p_search,'')) > 200 or p_offset < 0
    or (p_cursor_at is null) <> (p_cursor_id is null) then
    raise exception 'V1_AUDIT_FILTER_INVALID' using errcode = '22023';
  end if;
  with base as materialized (
    select
      audit.id,
      audit.event_type,
      audit.entity_type,
      audit.entity_id,
      audit.project_id,
      audit.actor_auth_user_id,
      coalesce(
        audit.actor_display_name_snapshot,
        public.v1_safe_profile_display_name(
          profile.display_name,
          profile.auth_user_id
        ),
        upper(left(audit.actor_auth_user_id::text, 8))
      ) as actor_display_name,
      coalesce(audit.actor_exact_role, audit.actor_role) as actor_exact_role,
      audit.occurred_at,
      audit.reason,
      case when audit.entity_type like 'company_%' then 'company'
        when audit.project_id is not null then 'project' else 'organization' end as scope,
      coalesce(
        audit.project_ref_snapshot,
        nullif(audit.after_data ->> 'project_ref', ''),
        project.project_ref
      ) as project_ref,
      coalesce(
        audit.project_name_snapshot,
        nullif(audit.after_data ->> 'project_name', ''),
        project.name
      ) as project_name,
      case
        when audit.entity_type like 'company_%' then 'material_requests'
        when audit.entity_type like 'workforce_%' or audit.event_type like 'workforce_%' then 'workforce'
        when audit.entity_type like 'account%' or audit.event_type like 'account%' then 'accounts'
        when audit.entity_type like 'configuration%' then 'configuration'
        when audit.entity_type in (
          'project', 'project_scope', 'project_member', 'boq_group',
          'boq_import', 'boq_row', 'boq_column'
        ) then 'projects'
        when audit.entity_type in (
          'material_request', 'material_request_line', 'procurement_arrangement',
          'procurement_arrangement_line', 'arrangement_decision'
        ) then 'material_requests'
        when audit.entity_type in (
          'material_dispatch', 'receipt_review', 'delivery_order',
          'delivery_order_revision', 'material_return'
        ) then 'logistics'
        when audit.entity_type like 'inventory_%' then 'inventory'
        when audit.entity_type like 'rental_%' then 'rentals'
        when audit.entity_type in (
          'auth_user', 'profile', 'user_capability', 'role_capability'
        ) then 'users'
        when audit.entity_type like 'document%' then 'documents'
        else 'system'
      end as module,
      coalesce(catalogue.severity,'unclassified') as severity,
      coalesce(
        nullif(audit.after_data ->> 'request_number', ''),
        nullif(audit.after_data ->> 'dispatch_number', ''),
        nullif(audit.after_data ->> 'return_number', ''),
        nullif(audit.after_data ->> 'delivery_order_reference', ''),
        nullif(audit.after_data ->> 'project_ref', ''),
        nullif(audit.after_data ->> 'property_code', ''),
        nullif(audit.after_data ->> 'item_code', ''),
        nullif(audit.after_data ->> 'reference', ''),
        project.project_ref,
        upper(left(audit.entity_id::text, 8))
      ) as reference,
      (select coalesce(jsonb_object_agg(k, audit.before_data ->> k), '{}'::jsonb)
        from unnest(array['state','decision','action','record_version','quantity_delta','is_active',
          'request_clarification_revision','approved_clarification_revision']) k
        where audit.before_data ? k) as before_facts,
      jsonb_strip_nulls(jsonb_build_object(
        'request_clarification_revision', audit.after_data ->> 'request_clarification_revision',
        'approved_clarification_revision', audit.after_data ->> 'approved_clarification_revision',
        'state', audit.after_data ->> 'state',
        'decision', audit.after_data ->> 'decision',
        'action', audit.after_data ->> 'action',
        'line_count', audit.after_data ->> 'line_count',
        'record_version', audit.after_data ->> 'record_version',
        'snapshot_source', audit.after_data ->> 'snapshot_source',
        'quantity_delta', audit.after_data ->> 'quantity_delta',
        'created_count', audit.after_data ->> 'created_count',
        'is_active', audit.after_data ->> 'is_active'
      )) as safe_facts,
      (
        audit.actor_exact_role is not null
        and audit.actor_display_name_snapshot is not null
        and btrim(audit.event_type) <> ''
        and btrim(audit.entity_type) <> ''
      ) as attribution_verified
    from public.v1_audit_events audit
    left join public.v1_audit_event_catalogue catalogue on catalogue.event_type=audit.event_type
    left join public.v1_profiles profile
      on profile.auth_user_id = audit.actor_auth_user_id
    left join public.v1_projects project on project.id = audit.project_id
    where audit.occurred_at <= least(coalesce(p_as_of, statement_timestamp()), statement_timestamp())
      and (p_from is null or audit.occurred_at >= p_from)
      and (p_to is null or audit.occurred_at < p_to)
      and (p_entity_id is null or audit.entity_id = p_entity_id)
      and (p_entity_type is null or audit.entity_type = p_entity_type)
  ), filtered as materialized (
    select base.*
    from base
    where (p_actor is null or base.actor_auth_user_id = p_actor)
      and (p_project is null or base.project_id = p_project)
      and (p_event_type is null or base.event_type = p_event_type)
      and (p_severity is null or base.severity = p_severity)
      and (p_entity_id is null or base.entity_id = p_entity_id)
      and (p_entity_type is null or base.entity_type = p_entity_type)
      and (p_scope is null or base.scope = p_scope)
      and (p_from is null or base.occurred_at >= p_from)
      and (p_to is null or base.occurred_at < p_to)
      and (v_module is null or base.module = v_module)
      and (
        v_quick_filter is null
        or (v_quick_filter = 'critical' and base.severity = 'critical')
        or (v_quick_filter = 'exceptions' and base.event_type ~* (
          'returned|reject|cancel|archive|void|damaged|missing'
        ))
        or (v_quick_filter = 'data_changes' and base.event_type ~* (
          'created|updated|adjusted|imported|linked|removed|assigned|archived|'
          'submitted|saved|confirmed|dispatched|generated'
        ))
        or (v_quick_filter = 'approvals' and base.event_type ~* (
          'approved|returned|decision'
        ))
        or (v_quick_filter = 'access' and (
          base.module = 'users' or base.entity_type = 'project_member'
        ))
      )
      and (
        v_search is null
        or base.actor_display_name ilike '%' || v_search || '%'
        or base.event_type ilike '%' || v_search || '%'
        or base.entity_type ilike '%' || v_search || '%'
        or base.reference ilike '%' || v_search || '%'
        or coalesce(base.project_ref, '') ilike '%' || v_search || '%'
        or coalesce(base.project_name, '') ilike '%' || v_search || '%'
        or coalesce(base.reason, '') ilike '%' || v_search || '%'
      )
  ), page_events as (
    select filtered.*
    from filtered
    where p_cursor_at is null or (filtered.occurred_at,filtered.id) < (p_cursor_at,p_cursor_id)
    order by filtered.occurred_at desc, filtered.id desc
    limit v_limit offset case when p_cursor_at is null then v_offset else 0 end
  )
  select jsonb_build_object(
    'generated_at', statement_timestamp(),
    'summary', jsonb_build_object(
      'total_activities', (select count(*) from filtered),
      'critical_activities', (select count(*) from filtered where severity = 'critical'),
      'active_users', (select count(distinct actor_auth_user_id) from filtered),
      'entities_monitored', (select count(distinct (entity_type,entity_id)) from filtered),
      'audit_alerts', (select count(*) from filtered where severity in ('critical','warning')),
      'data_integrity_percent', (select coalesce(round(100.0 * count(*) filter
        (where attribution_verified) / nullif(count(*),0),1),0) from filtered),
      'current_period_activities', 0, 'previous_period_activities', 0
    ),
    'as_of', least(coalesce(p_as_of, statement_timestamp()), statement_timestamp()),
    'filter_options', jsonb_build_object(
      'actors', (select coalesce(jsonb_agg(x order by x.label), '[]') from
        (select actor_auth_user_id::text as id, max(actor_display_name) as label from base group by actor_auth_user_id) x),
      'projects', (select coalesce(jsonb_agg(x order by x.label), '[]') from
        (select project_id::text as id, max(project_ref) as label from base where project_id is not null group by project_id) x),
      'events', (select coalesce(jsonb_agg(x order by x.id),'[]') from
        (select distinct event_type as id, event_type as label from base) x)
    ),
    'filtered_count', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset,
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', event.id,
        'event_type', event.event_type,
        'entity_type', event.entity_type,
        'entity_id', event.entity_id,
        'project_id', event.project_id,
        'module', event.module,
        'severity', event.severity,
        'actor_auth_user_id', event.actor_auth_user_id,
        'actor_display_name', event.actor_display_name,
        'actor_exact_role', event.actor_exact_role,
        'occurred_at', event.occurred_at,
        'reference', event.reference,
        'project_ref', event.project_ref,
        'project_name', event.project_name,
        'reason', event.reason,
        'facts', event.safe_facts,
        'before_facts', event.before_facts,
        'scope', event.scope,
        'attribution_verified', event.attribution_verified
      ) order by event.occurred_at desc, event.id desc)
      from page_events event
    ), '[]'::jsonb),
    'top_entities', coalesce((
      select jsonb_agg(jsonb_build_object(
        'entity_type', ranked.entity_type,
        'activity_count', ranked.activity_count,
        'percent', ranked.percent
      ) order by ranked.activity_count desc, ranked.entity_type)
      from (
        select entity_type,
          count(*) as activity_count,
          round(100.0 * count(*) / nullif((select count(*) from filtered), 0), 1)
            as percent
        from filtered
        group by entity_type
        order by count(*) desc, entity_type
        limit 5
      ) ranked
    ), '[]'::jsonb),
    'module_activity', coalesce((
      select jsonb_agg(jsonb_build_object(
        'module', grouped.module,
        'activity_count', grouped.activity_count,
        'percent', grouped.percent
      ) order by grouped.activity_count desc, grouped.module)
      from (
        select module,
          count(*) as activity_count,
          round(100.0 * count(*) / nullif((select count(*) from filtered), 0), 1)
            as percent
        from filtered
        group by module
      ) grouped
    ), '[]'::jsonb),
    'trend', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', day.day::date,
        'activity_count', (
          select count(*) from filtered
          where occurred_at >= day.day
            and occurred_at < day.day + interval '1 day'
        )
      ) order by day.day)
      from generate_series(
        date_trunc('day', least(coalesce(p_to - interval '1 microsecond', statement_timestamp()), statement_timestamp()) at time zone 'UTC') at time zone 'UTC' - interval '6 days',
        date_trunc('day', least(coalesce(p_to - interval '1 microsecond', statement_timestamp()), statement_timestamp()) at time zone 'UTC') at time zone 'UTC',
        interval '1 day'
      ) day(day)
    ), '[]'::jsonb),
    'quick_filters', jsonb_build_object(
      'critical', (select count(*) from filtered where severity = 'critical'),
      'exceptions', (select count(*) from filtered where event_type ~* (
        'returned|reject|cancel|archive|void|damaged|missing'
      )),
      'data_changes', (select count(*) from filtered where event_type ~* (
        'created|updated|adjusted|imported|linked|removed|assigned|archived|'
        'submitted|saved|confirmed|dispatched|generated'
      )),
      'approvals', (select count(*) from filtered where event_type ~* (
        'approved|returned|decision'
      )),
      'access', (select count(*) from filtered
        where module = 'users' or entity_type = 'project_member')
    ),
    'alerts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', alert.id,
        'event_type', alert.event_type,
        'entity_type', alert.entity_type,
        'severity', alert.severity,
        'reference', alert.reference,
        'reason', alert.reason,
        'occurred_at', alert.occurred_at
      ) order by alert.occurred_at desc, alert.id desc)
      from (
        select filtered.* from filtered
        where filtered.severity in ('critical', 'warning')
        order by filtered.occurred_at desc, filtered.id desc
        limit 5
      ) alert
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.v1_get_audit_workspace_v2(
  text, text, text, timestamptz, timestamptz, integer, integer,
  uuid, uuid, text, text, uuid, text, text, timestamptz, timestamptz, uuid
) from public, anon, authenticated;
grant execute on function public.v1_get_audit_workspace_v2(
  text, text, text, timestamptz, timestamptz, integer, integer,
  uuid, uuid, text, text, uuid, text, text, timestamptz, timestamptz, uuid
) to authenticated;



create table if not exists public.v1_audit_export_receipts (
  actor_id uuid not null,
  id uuid not null,
  filters jsonb not null,
  payload jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,id)
);
alter table public.v1_audit_export_receipts enable row level security;
revoke all on public.v1_audit_export_receipts from public, anon, authenticated;
drop trigger if exists v1_audit_export_receipts_append_only on public.v1_audit_export_receipts;
create trigger v1_audit_export_receipts_append_only before update or delete
  on public.v1_audit_export_receipts for each row execute function public.v1_prevent_audit_mutation();

create or replace function public.v1_export_audit_workspace(p_filters jsonb, p_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_payload jsonb; v_filters jsonb;
begin
  if auth.uid() is null or public.v1_current_exact_role() <> 'admin'
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_AUDIT_WORKSPACE_ADMIN_REQUIRED' using errcode='42501';
  end if;
  if p_id is null or p_filters is null or jsonb_typeof(p_filters) <> 'object' then
    raise exception 'V1_AUDIT_FILTER_INVALID' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_id::text,0));
  select filters,payload into v_filters,v_payload from public.v1_audit_export_receipts
    where actor_id=auth.uid() and id=p_id;
  if found then
    if v_filters <> p_filters then
      raise exception 'V1_AUDIT_EXPORT_CONFLICT' using errcode='22023';
    end if;
    return v_payload;
  end if;
  v_payload := public.v1_get_audit_workspace_v2(
    p_search=>p_filters->>'p_search', p_module=>p_filters->>'p_module',
    p_quick_filter=>p_filters->>'p_quick_filter',
    p_from=>(p_filters->>'p_from')::timestamptz, p_to=>(p_filters->>'p_to')::timestamptz,
    p_limit=>5001, p_offset=>0, p_actor=>(p_filters->>'p_actor')::uuid,
    p_project=>(p_filters->>'p_project')::uuid, p_event_type=>p_filters->>'p_event_type',
    p_severity=>p_filters->>'p_severity', p_entity_id=>(p_filters->>'p_entity_id')::uuid,
    p_entity_type=>p_filters->>'p_entity_type', p_scope=>p_filters->>'p_scope',
    p_as_of=>(p_filters->>'p_as_of')::timestamptz
  );
  if (v_payload->>'filtered_count')::integer > 5000 then
    raise exception 'V1_AUDIT_EXPORT_NARROW_RANGE' using errcode='22023';
  end if;
  v_payload := v_payload || jsonb_build_object('export_id',p_id,'filters',p_filters);
  insert into public.v1_audit_export_receipts(actor_id,id,filters,payload)
    values(auth.uid(),p_id,p_filters,v_payload);
  perform public.v1_write_audit_event('audit_export_generated','audit_export',p_id,null,
    null,jsonb_build_object('line_count',v_payload->'filtered_count'),null,p_id);
  return v_payload;
end;
$$;
revoke all on function public.v1_export_audit_workspace(jsonb,uuid) from public,anon,authenticated;
grant execute on function public.v1_export_audit_workspace(jsonb,uuid) to authenticated;

commit;
