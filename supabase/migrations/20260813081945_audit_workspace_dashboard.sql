-- Yorks V1 trusted Audit Workspace read projection.
--
-- Data preservation: this migration does not mutate or reinterpret an audit
-- event. It adds a read index and an Admin-only, metadata-safe RPC over the
-- existing append-only event ledger. before_data/after_data are never returned;
-- only a small allow-list of non-commercial operational facts is projected.
-- Rollback: revoke/drop v1_get_audit_workspace and drop the read index. The
-- underlying audit ledger and every historical event remain untouched.

begin;

alter table public.v1_audit_events
  add column if not exists project_ref_snapshot text,
  add column if not exists project_name_snapshot text;

create or replace function public.v1_capture_audit_project_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.project_id is not null then
    select project.project_ref, project.name
      into new.project_ref_snapshot, new.project_name_snapshot
    from public.v1_projects project
    where project.id = new.project_id;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_audit_capture_project_identity
  on public.v1_audit_events;
create trigger v1_audit_capture_project_identity
before insert on public.v1_audit_events
for each row execute function public.v1_capture_audit_project_identity();

create index if not exists v1_audit_events_occurred_id_idx
  on public.v1_audit_events (occurred_at desc, id desc);

create or replace function public.v1_get_audit_workspace(
  p_search text default null,
  p_module text default null,
  p_quick_filter text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 12,
  p_offset integer default 0
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
  v_limit integer := least(greatest(coalesce(p_limit, 12), 1), 50);
  v_offset integer := least(greatest(coalesce(p_offset, 0), 0), 100000);
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
    'users', 'documents', 'system'
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
        when audit.entity_type in (
          'project', 'project_scope', 'project_member', 'boq_group',
          'boq_import', 'boq_row', 'boq_column'
        ) then 'projects'
        when audit.entity_type in (
          'material_request', 'procurement_arrangement',
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
      case
        when audit.event_type ~* (
          'cancel|archive|reject|void|deactivat|role_changed|active_changed|'
          'capability_revoked|removed|deleted'
        ) then 'critical'
        when audit.event_type ~* (
          'returned|partial|override|adjust|superseded|damaged|missing|release'
        ) then 'warning'
        else 'normal'
      end as severity,
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
      jsonb_strip_nulls(jsonb_build_object(
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
    left join public.v1_profiles profile
      on profile.auth_user_id = audit.actor_auth_user_id
    left join public.v1_projects project on project.id = audit.project_id
  ), filtered as materialized (
    select base.*
    from base
    where (p_from is null or base.occurred_at >= p_from)
      and (p_to is null or base.occurred_at <= p_to)
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
    order by filtered.occurred_at desc, filtered.id desc
    limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'generated_at', statement_timestamp(),
    'summary', jsonb_build_object(
      'total_activities', (select count(*) from base),
      'critical_activities', (
        select count(*) from base where severity = 'critical'
      ),
      'active_users', (
        select count(distinct actor_auth_user_id)
        from base where occurred_at >= statement_timestamp() - interval '30 days'
      ),
      'entities_monitored', (
        select count(*) from (
          select entity_type, entity_id from base group by entity_type, entity_id
        ) distinct_entities
      ),
      'audit_alerts', (
        select count(*) from base
        where severity in ('critical', 'warning')
          and occurred_at >= statement_timestamp() - interval '7 days'
      ),
      'data_integrity_percent', coalesce((
        select round(
          100.0 * count(*) filter (where attribution_verified)
          / nullif(count(*), 0),
          1
        ) from base
      ), 100.0),
      'current_period_activities', (
        select count(*) from base
        where occurred_at >= statement_timestamp() - interval '7 days'
      ),
      'previous_period_activities', (
        select count(*) from base
        where occurred_at >= statement_timestamp() - interval '14 days'
          and occurred_at < statement_timestamp() - interval '7 days'
      )
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
          round(100.0 * count(*) / nullif((select count(*) from base), 0), 1)
            as percent
        from base
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
          round(100.0 * count(*) / nullif((select count(*) from base), 0), 1)
            as percent
        from base
        group by module
      ) grouped
    ), '[]'::jsonb),
    'trend', coalesce((
      select jsonb_agg(jsonb_build_object(
        'date', day.day::date,
        'activity_count', (
          select count(*) from base
          where occurred_at >= day.day
            and occurred_at < day.day + interval '1 day'
        )
      ) order by day.day)
      from generate_series(
        date_trunc('day', statement_timestamp()) - interval '6 days',
        date_trunc('day', statement_timestamp()),
        interval '1 day'
      ) day(day)
    ), '[]'::jsonb),
    'quick_filters', jsonb_build_object(
      'critical', (select count(*) from base where severity = 'critical'),
      'exceptions', (select count(*) from base where event_type ~* (
        'returned|reject|cancel|archive|void|damaged|missing'
      )),
      'data_changes', (select count(*) from base where event_type ~* (
        'created|updated|adjusted|imported|linked|removed|assigned|archived|'
        'submitted|saved|confirmed|dispatched|generated'
      )),
      'approvals', (select count(*) from base where event_type ~* (
        'approved|returned|decision'
      )),
      'access', (select count(*) from base
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
        select base.* from base
        where base.severity in ('critical', 'warning')
        order by base.occurred_at desc, base.id desc
        limit 5
      ) alert
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.v1_get_audit_workspace(
  text, text, text, timestamptz, timestamptz, integer, integer
) from public, anon, authenticated;
grant execute on function public.v1_get_audit_workspace(
  text, text, text, timestamptz, timestamptz, integer, integer
) to authenticated;

commit;
