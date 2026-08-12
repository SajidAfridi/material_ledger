-- Focused workflow correction:
-- 1. Procurement may create an uncategorized inventory item while arranging
--    an MR. Category enforcement will be introduced separately only after the
--    warehouse catalogue has been reconciled.
-- 2. The controlled MR projection exposes server-derived fulfillment progress
--    after the first committed dispatch. Missing and damaged quantities never
--    count as fulfilled; confirmed good plus current in-transit quantity does.

begin;

create or replace function public.v1_create_inventory_item(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_existing jsonb;
  v_item_id uuid := gen_random_uuid();
  v_code text := nullif(btrim(coalesce(p_payload ->> 'item_code', '')), '');
  v_description text := nullif(btrim(coalesce(p_payload ->> 'item_description', '')), '');
  v_unit text := nullif(btrim(coalesce(p_payload ->> 'unit', '')), '');
  v_category jsonb;
  v_category_id uuid;
  v_opening numeric(18,4) := coalesce(nullif(p_payload ->> 'opening_quantity', '')::numeric, 0);
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'item_code','item_description','category_id','new_category_name',
    'new_category_parent_id','source_category_text','brand_origin','size_text',
    'model_reference','unit','minimum_stock','location_bin','notes',
    'opening_quantity','opening_reference','reason'
  ], 'create_inventory_item');
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_ITEM_CREATE_DENIED' using errcode = '42501';
  end if;
  if v_description is null or v_unit is null or v_opening < 0
    or (v_opening > 0 and v_reason is null) then
    raise exception 'V1_INVENTORY_ITEM_CREATE_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_inventory_item', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  -- A category is optional during the current reconciliation window. When a
  -- selection or an explicitly confirmed new name is supplied, the same
  -- canonical resolver, alias checks and audited category creation still run.
  if nullif(p_payload ->> 'category_id','') is not null
    or nullif(btrim(coalesce(p_payload ->> 'new_category_name', '')), '') is not null then
    v_category := public.v1_resolve_inventory_category_v2(
      nullif(p_payload ->> 'category_id','')::uuid,
      p_payload ->> 'new_category_name',
      nullif(p_payload ->> 'new_category_parent_id','')::uuid,
      p_payload ->> 'source_category_text'
    );
    v_category_id := (v_category ->> 'id')::uuid;
  end if;

  if v_code is null then
    v_code := 'INV-' || upper(substr(replace(v_item_id::text, '-', ''), 1, 8));
  end if;
  insert into public.v1_inventory_items (
    id,item_code,item_description,category_id,brand_origin,size_text,
    model_reference,unit,minimum_stock,location_bin,notes,created_by_auth_user_id
  ) values (
    v_item_id,v_code,v_description,v_category_id,
    nullif(btrim(coalesce(p_payload->>'brand_origin','')),''),
    nullif(btrim(coalesce(p_payload->>'size_text','')),''),
    nullif(btrim(coalesce(p_payload->>'model_reference','')),''),v_unit,
    nullif(p_payload->>'minimum_stock','')::numeric,
    nullif(btrim(coalesce(p_payload->>'location_bin','')),''),
    nullif(btrim(coalesce(p_payload->>'notes','')),''),v_actor
  );
  insert into public.v1_inventory_balances (inventory_item_id,on_hand_qty)
    values (v_item_id,v_opening);
  if v_opening > 0 then
    insert into public.v1_inventory_movements (
      inventory_item_id,movement_type,quantity_delta,on_hand_after_qty,
      source_entity_type,reason,actor_auth_user_id,idempotency_key
    ) values (
      v_item_id,'opening_balance',v_opening,v_opening,'inventory_opening_balance',
      concat(v_reason, case when nullif(btrim(coalesce(p_payload->>'opening_reference','')),'') is null
        then '' else ' · ' || btrim(p_payload->>'opening_reference') end),
      v_actor,p_idempotency_key
    );
  end if;
  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    'inventory_item_created','inventory_item',v_item_id,null,null,v_response,
    coalesce(v_reason,'Inventory item master created'),p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_inventory_item',p_idempotency_key,v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_material_request_document_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DOCUMENT_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'job_contract_reference', project.job_contract_reference,
    'scope_id', request_record.scope_id,
    'scope_name', scope.name,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'request_number', request_record.request_number,
    'title', request_record.title,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_note', request_record.delivery_note,
    'requester_display_name', request_record.requester_display_name,
    'requester_project_role', request_record.requester_project_role,
    'requester_exact_role', request_record.requester_exact_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(public.v1_material_request_line_projection(line_record.id, false)
        order by line_record.display_order)
      from public.v1_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_request
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;

  return jsonb_build_object(
    'request', v_request,
    'project_engineers', (
      select request_record.project_engineer_snapshot
      from public.v1_material_requests request_record where request_record.id = p_request_id
    ),
    'approval', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id),
        'role', decision.decided_by_role,
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', decision.created_at
      )
      from public.v1_arrangement_decisions decision
      join public.v1_procurement_arrangements arrangement on arrangement.id = decision.arrangement_id
      join public.v1_profiles profile on profile.auth_user_id = decision.decided_by_auth_user_id
      where decision.request_id = p_request_id and decision.decision = 'approved'
      order by decision.created_at desc limit 1
    ),
    'dispatch', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id),
        'role', dispatch.dispatched_by_role,
        'reference', dispatch.delivery_reference,
        'acted_at', dispatch.dispatched_at
      )
      from public.v1_material_dispatches dispatch
      join public.v1_profiles profile on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = p_request_id
      order by case when dispatch.state in ('partially_received', 'received')
          then 0 else 1 end,
        dispatch.dispatched_at desc, dispatch.id desc limit 1
    ),
    'show_line_status', exists (
      select 1
      from public.v1_material_dispatches dispatch
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.dispatch_id = dispatch.id
      where dispatch.request_id = p_request_id
        and dispatch_line.dispatched_qty > 0
    ),
    'receipt_statuses', coalesce((
      with line_totals as (
        select
          request_line.id as request_line_id,
          request_line.requested_qty,
          coalesce(approval.approved_qty, 0) as approved_qty,
          coalesce(sum(review_line.good_qty)
            filter (where review.state = 'confirmed'), 0) as good_qty,
          coalesce(sum(review_line.exception_qty)
            filter (where review.state = 'confirmed'
              and review_line.outcome = 'missing'), 0) as missing_qty,
          coalesce(sum(review_line.exception_qty)
            filter (where review.state = 'confirmed'
              and review_line.outcome = 'damaged'), 0) as damaged_qty,
          coalesce(sum(dispatch_line.dispatched_qty)
            filter (where dispatch.state = 'receipt_pending'), 0) as in_transit_qty
        from public.v1_material_request_lines request_line
        left join public.v1_material_request_line_approvals approval
          on approval.request_line_id = request_line.id
        left join public.v1_material_dispatch_lines dispatch_line
          on dispatch_line.request_line_id = request_line.id
        left join public.v1_material_dispatches dispatch
          on dispatch.id = dispatch_line.dispatch_id
        left join public.v1_receipt_review_lines review_line
          on review_line.dispatch_line_id = dispatch_line.id
        left join public.v1_receipt_reviews review
          on review.id = review_line.receipt_review_id
        where request_line.request_id = p_request_id
        group by request_line.id, request_line.requested_qty, approval.approved_qty
      ), progress as (
        select *, good_qty + in_transit_qty as fulfilled_qty
        from line_totals
      )
      select jsonb_agg(jsonb_build_object(
        'request_line_id', request_line_id,
        'requested_qty', requested_qty::text,
        'approved_qty', approved_qty::text,
        'good_qty', good_qty::text,
        'missing_qty', missing_qty::text,
        'damaged_qty', damaged_qty::text,
        'in_transit_qty', in_transit_qty::text,
        'fulfilled_qty', fulfilled_qty::text,
        'status', case
          when approved_qty = 0 then 'Cannot Provide Now'
          when fulfilled_qty >= requested_qty then 'Complete'
          when fulfilled_qty > 0 then 'Partial'
          when missing_qty > 0 or damaged_qty > 0 then 'Replacement required'
          else 'Pending'
        end
      ) order by request_line_id)
      from progress
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_create_inventory_item(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_create_inventory_item(jsonb, uuid)
  to authenticated;

revoke all on function public.v1_material_request_document_projection(uuid)
  from public, anon;
grant execute on function public.v1_material_request_document_projection(uuid)
  to authenticated;

commit;
