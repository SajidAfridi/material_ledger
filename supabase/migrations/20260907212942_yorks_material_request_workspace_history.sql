-- Request-scoped, role-safe history for the Material Request workspace.
--
-- This is deliberately not a client-filtered copy of the organization audit
-- workspace. Each page proves current request readability, only follows
-- verified relationships back to one request, and exposes a small allowlist
-- of operational facts rather than the raw audit JSON.

create index if not exists v1_audit_events_entity_occurred_idx
  on public.v1_audit_events (entity_type, entity_id, occurred_at desc, id desc);

create or replace function public.v1_get_material_request_history(
  p_request_id uuid,
  p_before_occurred_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 5
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_limit integer := greatest(1, least(coalesce(p_limit, 5), 20));
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  if p_request_id is null
    or (p_before_occurred_at is null) <> (p_before_id is null) then
    raise exception 'V1_MATERIAL_REQUEST_HISTORY_INPUT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found or not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_HISTORY_NOT_READABLE'
      using errcode = '42501';
  end if;

  with eligible as (
    select
      audit.id,
      audit.event_type,
      audit.entity_type,
      audit.occurred_at,
      audit.actor_display_name_snapshot,
      audit.actor_exact_role,
      audit.actor_role,
      audit.after_data
    from public.v1_audit_events audit
    where audit.project_id = v_request.project_id
      and (
        (audit.entity_type = 'material_request'
          and audit.entity_id = p_request_id)
        or (audit.entity_type = 'material_request_line'
          and exists (
            select 1
            from public.v1_material_request_lines request_line
            where request_line.id = audit.entity_id
              and request_line.request_id = p_request_id
          ))
        or (audit.entity_type = 'material_request_decision'
          and exists (
            select 1
            from public.v1_material_request_decisions decision
            where decision.id = audit.entity_id
              and decision.request_id = p_request_id
          ))
        or (audit.entity_type = 'material_request_revision_snapshot'
          and exists (
            select 1
            from public.v1_material_request_revision_snapshots revision
            where revision.id = audit.entity_id
              and revision.request_id = p_request_id
          ))
        or (audit.entity_type = 'procurement_arrangement'
          and exists (
            select 1
            from public.v1_procurement_arrangements arrangement
            where arrangement.id = audit.entity_id
              and arrangement.request_id = p_request_id
          ))
        or (audit.entity_type = 'procurement_arrangement_line'
          and exists (
            select 1
            from public.v1_procurement_arrangement_lines arrangement_line
            join public.v1_procurement_arrangements arrangement
              on arrangement.id = arrangement_line.arrangement_id
            where arrangement_line.id = audit.entity_id
              and arrangement.request_id = p_request_id
          ))
        or (audit.entity_type in ('dispatch', 'material_dispatch')
          and exists (
            select 1
            from public.v1_material_dispatches dispatch
            where dispatch.id = audit.entity_id
              and dispatch.request_id = p_request_id
          ))
        or (audit.entity_type = 'receipt_review'
          and exists (
            select 1
            from public.v1_receipt_reviews receipt
            where receipt.id = audit.entity_id
              and receipt.request_id = p_request_id
          ))
        or (audit.entity_type = 'delivery_order'
          and exists (
            select 1
            from public.v1_delivery_orders delivery_order
            where delivery_order.id = audit.entity_id
              and delivery_order.request_id = p_request_id
          ))
        or (audit.entity_type = 'delivery_order_revision'
          and exists (
            select 1
            from public.v1_delivery_order_revisions revision
            join public.v1_delivery_orders delivery_order
              on delivery_order.id = revision.delivery_order_id
            where revision.id = audit.entity_id
              and delivery_order.request_id = p_request_id
          ))
        or (audit.entity_type = 'material_return'
          and exists (
            select 1
            from public.v1_material_returns material_return
            where material_return.id = audit.entity_id
              and material_return.request_id = p_request_id
          ))
        or (audit.entity_type = 'document_version'
          and exists (
            select 1
            from public.v1_document_versions document_version
            join public.v1_document_links document_link
              on document_link.document_id = document_version.document_id
            where document_version.id = audit.entity_id
              and document_link.entity_type = 'material_request'
              and document_link.entity_id = p_request_id
              and document_link.removed_at is null
          ))
        or (audit.entity_type = 'document'
          and exists (
            select 1
            from public.v1_document_links document_link
            where document_link.document_id = audit.entity_id
              and document_link.entity_type = 'material_request'
              and document_link.entity_id = p_request_id
              and document_link.removed_at is null
          ))
      )
      and (
        p_before_occurred_at is null
        or audit.occurred_at < p_before_occurred_at
        or (
          audit.occurred_at = p_before_occurred_at
          and audit.id < p_before_id
        )
      )
    union all
    -- Draft creation predates this workspace and was not emitted as an audit
    -- event. The request row itself is authoritative for who created it and
    -- when, so include that durable fact without installing a trigger that
    -- could obstruct controlled maintenance or migration inserts.
    select
      v_request.id,
      'material_request_created'::text,
      'material_request'::text,
      v_request.created_at,
      nullif(btrim(v_request.requester_display_name), ''),
      nullif(btrim(v_request.requester_exact_role), ''),
      nullif(btrim(v_request.requester_project_role), ''),
      '{}'::jsonb
    where not exists (
      select 1
      from public.v1_audit_events creation_event
      where creation_event.entity_type = 'material_request'
        and creation_event.entity_id = p_request_id
        and creation_event.event_type = 'material_request_created'
    )
      and (
        p_before_occurred_at is null
        or v_request.created_at < p_before_occurred_at
        or (
          v_request.created_at = p_before_occurred_at
          and v_request.id < p_before_id
        )
      )
  ),
  page as (
    select *
    from eligible
    order by occurred_at desc, id desc
    limit v_limit + 1
  ),
  visible as (
    select *
    from page
    order by occurred_at desc, id desc
    limit v_limit
  ),
  metadata as (
    select count(*) > v_limit as has_more from page
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', visible.id,
          'event_type', visible.event_type,
          'entity_type', visible.entity_type,
          'occurred_at', visible.occurred_at,
          'actor_display_name', nullif(
            btrim(visible.actor_display_name_snapshot), ''
          ),
          'actor_exact_role', coalesce(
            nullif(btrim(visible.actor_exact_role), ''),
            nullif(btrim(visible.actor_role), '')
          ),
          'reference', v_request.request_number,
          'facts', jsonb_strip_nulls(jsonb_build_object(
            'state', coalesce(
              visible.after_data ->> 'request_state',
              visible.after_data ->> 'state'
            ),
            'decision', visible.after_data ->> 'decision',
            'record_version', visible.after_data ->> 'record_version',
            'line_count', visible.after_data ->> 'line_count',
            'arrangement_version', visible.after_data ->> 'arrangement_version',
            'dispatch_number', visible.after_data ->> 'dispatch_number',
            'delivery_order_reference', coalesce(
              visible.after_data ->> 'delivery_order_reference',
              visible.after_data ->> 'delivery_order_number'
            ),
            'return_number', visible.after_data ->> 'return_number'
          ))
        )
        order by visible.occurred_at desc, visible.id desc
      )
      from visible
    ), '[]'::jsonb),
    'has_more', (select has_more from metadata),
    'next_before_occurred_at', case
      when (select has_more from metadata) then (
        select visible.occurred_at
        from visible
        order by visible.occurred_at asc, visible.id asc
        limit 1
      )
      else null
    end,
    'next_before_id', case
      when (select has_more from metadata) then (
        select visible.id
        from visible
        order by visible.occurred_at asc, visible.id asc
        limit 1
      )
      else null
    end
  ) into v_result;

  return v_result;
end;
$$;

comment on function public.v1_get_material_request_history(
  uuid, timestamptz, uuid, integer
) is
  'Returns a bounded, request-authorized, allowlisted audit history without exposing project-wide audit data.';

revoke all on function public.v1_get_material_request_history(
  uuid, timestamptz, uuid, integer
) from public, anon, authenticated;
grant execute on function public.v1_get_material_request_history(
  uuid, timestamptz, uuid, integer
) to authenticated;
