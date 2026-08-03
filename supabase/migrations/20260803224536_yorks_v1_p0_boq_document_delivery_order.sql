-- R35 P0 corrective migration. This is additive and repeatable: it extends
-- non-commercial BOQ/MR mappings, adds one role-safe MR document projection,
-- and lets the assigned receiving engineer generate a post-review DO. It does
-- not alter historical rows, stock, reservations, document revisions or audit.

begin;

alter table public.v1_boq_columns
  drop constraint if exists v1_boq_columns_canonical_field_check;
alter table public.v1_boq_columns
  add constraint v1_boq_columns_canonical_field_check check (canonical_field in (
    'description', 'size', 'model', 'equipment_tag', 'brand_origin',
    'quantity', 'unit', 'planning_model_tag'
  ));

-- The established worksheet commands validate their accepted canonical set in
-- the function body. Replace only that allow-list, retaining all existing
-- optimistic-lock, archive, commercial-capability and audit behaviour.
do $$
declare
  v_definition text;
  v_old text := '''description'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
  v_new text := '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
begin
  foreach v_definition in array array[
    pg_get_functiondef('public.v1_save_boq_worksheet(jsonb,uuid)'::regprocedure),
    pg_get_functiondef('public.v1_import_boq_worksheet(jsonb,uuid)'::regprocedure)
  ] loop
    if position(v_old in v_definition) = 0 then
      raise exception 'V1_P0_BOQ_CANONICAL_ALLOWLIST_NOT_FOUND';
    end if;
    execute replace(v_definition, v_old, v_new);
  end loop;
end;
$$;

-- Existing MR save semantics are retained; only additive, non-commercial
-- technical keys are accepted. This avoids a mixed-client 400 while the
-- controlled projection remains cost-safe.
do $$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_material_request_draft(jsonb)'::regprocedure
  );
  if position('''size'', ''planning_model_tag''' in v_definition) = 0 then
    raise exception 'V1_P0_MR_TECHNICAL_ALLOWLIST_NOT_FOUND';
  end if;
  execute replace(
    v_definition,
    '''size'', ''planning_model_tag''',
    '''size'', ''model'', ''equipment_tag'', ''planning_model_tag'', ''quantity_suggested'''
  );
end;
$$;

create or replace function public.v1_material_request_line_projection(
  p_line_id uuid,
  p_include_commercial boolean
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', line_record.id,
    'display_order', line_record.display_order,
    'source_kind', line_record.source_kind,
    'source_boq_group_id', line_record.source_boq_group_id,
    'source_boq_row_id', line_record.source_boq_row_id,
    'item_description', line_record.item_description,
    'brand_origin', line_record.brand_origin,
    'technical_attributes', jsonb_strip_nulls(jsonb_build_object(
      'size', line_record.technical_attributes ->> 'size',
      'model', line_record.technical_attributes ->> 'model',
      'equipment_tag', line_record.technical_attributes ->> 'equipment_tag',
      'planning_model_tag', line_record.technical_attributes ->> 'planning_model_tag',
      'quantity_suggested', line_record.technical_attributes ->> 'quantity_suggested'
    )),
    'requested_qty', line_record.requested_qty::text,
    'unit', line_record.unit
  ) || case when p_include_commercial then jsonb_strip_nulls(
    jsonb_build_object(
      'unit_cost', commercial.unit_cost::text,
      'total_cost', (line_record.requested_qty * commercial.unit_cost)::text,
      'currency_code', commercial.currency_code
    )
  ) else '{}'::jsonb end
  from public.v1_material_request_lines line_record
  left join public.v1_material_request_line_commercials commercial
    on commercial.request_line_id = line_record.id
  where line_record.id = p_line_id;
$$;

-- One role-safe aggregation is the source for MR preview, download, print and
-- any stored controlled document. It never exposes commercial fields beyond
-- the request projection already authorized for the caller.
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
  v_request := public.v1_material_request_projection(p_request_id);
  return jsonb_build_object(
    'request', v_request,
    'project_engineers', coalesce((
      select jsonb_agg(jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        )
      ) order by lower(profile.display_name), profile.auth_user_id)
      from public.v1_project_members member
      join public.v1_profiles profile
        on profile.auth_user_id = member.member_auth_user_id
      where member.project_id = (v_request ->> 'project_id')::uuid
        and member.project_role = 'project_engineer'
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null or member.effective_to > clock_timestamp())
        and profile.is_active
    ), '[]'::jsonb),
    'approval', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'role', decision.decided_by_role,
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', decision.created_at
      )
      from public.v1_arrangement_decisions decision
      join public.v1_procurement_arrangements arrangement
        on arrangement.id = decision.arrangement_id
      join public.v1_profiles profile
        on profile.auth_user_id = decision.decided_by_auth_user_id
      where decision.request_id = p_request_id and decision.decision = 'approved'
      order by decision.created_at desc
      limit 1
    ),
    'dispatch', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'role', dispatch.dispatched_by_role,
        'reference', dispatch.dispatch_number,
        'acted_at', dispatch.dispatched_at
      )
      from public.v1_material_dispatches dispatch
      join public.v1_profiles profile
        on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = p_request_id
      -- Prefer the most recent dispatch which has a confirmed receipt review:
      -- it is the delivery actually represented by a post-receipt document.
      -- A still-pending later dispatch is retained only as a fallback.
      order by exists (
        select 1 from public.v1_receipt_reviews review
        where review.dispatch_id = dispatch.id and review.state = 'confirmed'
      ) desc, dispatch.dispatched_at desc
      limit 1
    ),
    'receipt_statuses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_line_id', dispatch_line.request_line_id,
        'status', initcap(review_line.outcome)
      ) order by review.reviewed_at desc)
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      where review.request_id = p_request_id and review.state = 'confirmed'
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_material_request_document_projection(uuid)
  from public, anon;
grant execute on function public.v1_material_request_document_projection(uuid)
  to authenticated;

-- Receipt confirmation already requires an assigned Project/Site Engineer.
-- That same role can now generate the post-review controlled DO. Dispatch and
-- stock stay restricted to Procurement/Admin; DO generation has no stock side
-- effect and remains idempotent/audited.
alter table public.v1_delivery_orders
  drop constraint if exists v1_delivery_orders_created_by_role_check;
alter table public.v1_delivery_orders
  add constraint v1_delivery_orders_created_by_role_check check (
    created_by_role in ('project_engineer', 'site_engineer', 'procurement', 'admin')
  );
alter table public.v1_delivery_order_revisions
  drop constraint if exists v1_delivery_order_revisions_generated_by_role_check;
alter table public.v1_delivery_order_revisions
  add constraint v1_delivery_order_revisions_generated_by_role_check check (
    generated_by_role in ('project_engineer', 'site_engineer', 'procurement', 'admin')
  );

create or replace function public.v1_can_generate_delivery_order(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id, project.state into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  if v_project_id is null or v_project_state not in ('active', 'on_hold', 'completed') then
    return false;
  end if;
  return v_role in ('procurement', 'admin')
    or (v_role in ('project_engineer', 'site_engineer')
      and public.v1_has_active_project_membership(v_project_id, auth.uid(), null));
end;
$$;

-- Return confirmation remains a warehouse command. It must not inherit the
-- broader document-generation capability granted above.
create or replace function public.v1_can_confirm_material_return(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_state text;
begin
  if not public.v1_can_manage_inventory() then return false; end if;
  select project.state into v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_state in ('active', 'on_hold', 'completed');
end;
$$;

revoke all on function public.v1_can_generate_delivery_order(uuid) from public, anon;
grant execute on function public.v1_can_generate_delivery_order(uuid) to authenticated;

commit;
