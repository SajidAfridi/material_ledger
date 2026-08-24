-- Yorks R35 controlled, project-wide Material Return workflow.
--
-- Data preservation:
--   * confirmed/rejected return facts and their stock movements are untouched;
--   * legacy submitted returns become awaiting_approval so no historical row
--     can bypass the newly required Engineering decision;
--   * request/dispatch/receipt links remain immutable where they exist;
--   * new custom rows carry an explicit unverified origin and cannot increase
--     warehouse stock until Procurement maps and physically accepts them.
-- Rollback is forward-only: restore the previous RPC surfaces in a corrective
-- migration. Never delete return, line, movement, notification or audit rows.

alter table public.v1_material_returns
  alter column request_id drop not null;

alter table public.v1_material_returns
  add column if not exists purpose text,
  add column if not exists requested_return_date date,
  add column if not exists approved_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  add column if not exists approved_by_exact_role text,
  add column if not exists approved_at timestamptz,
  add column if not exists approval_note text,
  add column if not exists returned_for_changes_reason text,
  add column if not exists dispatched_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  add column if not exists dispatched_by_exact_role text,
  add column if not exists dispatched_at timestamptz,
  add column if not exists driver_name text,
  add column if not exists vehicle_reference text,
  add column if not exists delivery_note_reference text,
  add column if not exists warehouse_receipt_note text,
  add column if not exists cancelled_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  add column if not exists cancelled_by_exact_role text,
  add column if not exists cancelled_at timestamptz,
  add column if not exists cancellation_reason text;

alter table public.v1_material_returns
  drop constraint if exists v1_material_returns_state_check,
  drop constraint if exists v1_material_returns_check,
  drop constraint if exists v1_material_returns_drafted_by_role_check,
  drop constraint if exists v1_material_returns_submitted_by_role_check,
  drop constraint if exists v1_material_returns_decided_by_role_check;

update public.v1_material_returns
set state = 'awaiting_approval',
    updated_at = clock_timestamp(),
    record_version = record_version + 1
where state = 'submitted';

alter table public.v1_material_returns
  add constraint v1_material_returns_state_check check (state in (
    'draft', 'submitted', 'awaiting_approval', 'returned_for_changes', 'approved',
    'dispatched', 'confirmed', 'rejected', 'cancelled'
  )),
  add constraint v1_material_returns_drafted_by_exact_role_check check (
    drafted_by_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller', 'admin'
    )
  ),
  add constraint v1_material_returns_submitted_by_exact_role_check check (
    submitted_by_role is null or submitted_by_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller', 'admin'
    )
  ),
  add constraint v1_material_returns_approved_by_exact_role_check check (
    approved_by_exact_role is null or approved_by_exact_role in (
      'project_engineer', 'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller', 'admin'
    )
  ),
  add constraint v1_material_returns_dispatched_by_exact_role_check check (
    dispatched_by_exact_role is null or dispatched_by_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller', 'admin'
    )
  ),
  add constraint v1_material_returns_decided_by_exact_role_check check (
    decided_by_role is null or decided_by_role in ('procurement', 'admin')
  ),
  add constraint v1_material_returns_cancelled_by_exact_role_check check (
    cancelled_by_exact_role is null or cancelled_by_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller', 'admin'
    )
  );

alter table public.v1_material_return_lines
  alter column receipt_review_line_id drop not null,
  alter column dispatch_line_id drop not null,
  alter column request_line_id drop not null,
  alter column good_quantity_snapshot drop not null;

alter table public.v1_material_return_lines
  add column if not exists origin_kind text not null default 'delivered',
  add column if not exists source_request_id uuid
    references public.v1_material_requests (id) on delete restrict,
  add column if not exists source_dispatch_id uuid
    references public.v1_material_dispatches (id) on delete restrict,
  add column if not exists line_note text,
  add column if not exists received_good_quantity numeric(18, 4),
  add column if not exists received_damaged_quantity numeric(18, 4),
  add column if not exists not_received_quantity numeric(18, 4),
  add column if not exists receipt_note text;

update public.v1_material_return_lines return_line
set source_request_id = dispatch.request_id,
    source_dispatch_id = dispatch.id,
    origin_kind = 'delivered'
from public.v1_material_dispatch_lines dispatch_line
join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
where dispatch_line.id = return_line.dispatch_line_id
  and (return_line.source_request_id is null
    or return_line.source_dispatch_id is null);

alter table public.v1_material_return_lines
  drop constraint if exists v1_material_return_lines_source_kind_check,
  drop constraint if exists v1_material_return_lines_check,
  drop constraint if exists v1_material_return_lines_good_quantity_snapshot_check;

alter table public.v1_material_return_lines
  add constraint v1_material_return_lines_origin_kind_check
    check (origin_kind in ('delivered', 'custom')),
  add constraint v1_material_return_lines_source_kind_check
    check (source_kind in ('warehouse', 'external_supplier', 'custom')),
  add constraint v1_material_return_lines_source_shape_check check (
    (origin_kind = 'delivered'
      and receipt_review_line_id is not null
      and dispatch_line_id is not null
      and request_line_id is not null
      and good_quantity_snapshot is not null
      and good_quantity_snapshot > 0
      and source_kind in ('warehouse', 'external_supplier'))
    or
    (origin_kind = 'custom'
      and receipt_review_line_id is null
      and dispatch_line_id is null
      and request_line_id is null
      and source_request_id is null
      and source_dispatch_id is null
      and good_quantity_snapshot is null
      and source_kind = 'custom')
  ),
  add constraint v1_material_return_lines_receipt_quantities_check check (
    (received_good_quantity is null or received_good_quantity >= 0)
    and (received_damaged_quantity is null or received_damaged_quantity >= 0)
    and (not_received_quantity is null or not_received_quantity >= 0)
  );

create index if not exists v1_material_returns_project_updated_idx
  on public.v1_material_returns (project_id, updated_at desc, id);
create index if not exists v1_material_return_lines_source_request_idx
  on public.v1_material_return_lines (source_request_id, material_return_id);

create or replace function public.v1_can_create_project_material_return(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_state text;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin') then
    return false;
  end if;
  select project.state into v_state
  from public.v1_projects project where project.id = p_project_id;
  return v_state in ('active', 'on_hold', 'completed')
    and (
      v_role = 'admin'
      or v_exact_role in (
        'senior_mechanical_engineer', 'project_manager',
        'workshop_in_charge', 'document_controller'
      )
      or public.v1_has_active_project_membership(
        p_project_id, auth.uid(), null
      )
    );
end;
$$;

create or replace function public.v1_can_approve_project_material_return(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'admin') then
    return false;
  end if;
  return v_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or public.v1_has_active_project_membership(
      p_project_id, auth.uid(), null
    );
end;
$$;

create or replace function public.v1_can_receive_project_material_return()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and public.v1_current_role() in ('procurement', 'admin');
$$;

create or replace function public.v1_material_return_readable(
  p_return_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.v1_material_returns material_return
    where material_return.id = p_return_id
      and public.v1_project_readable(material_return.project_id)
  );
$$;

create or replace function public.v1_material_return_line_projection(
  p_return_id uuid,
  p_include_inventory boolean default false
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', return_line.id,
    'origin_kind', return_line.origin_kind,
    'receipt_review_line_id', return_line.receipt_review_line_id,
    'source_request_id', return_line.source_request_id,
    'source_request_number', source_request.request_number,
    'source_dispatch_id', return_line.source_dispatch_id,
    'source_dispatch_number', source_dispatch.dispatch_number,
    'display_order', return_line.display_order,
    'item_description', return_line.item_description,
    'brand_origin', return_line.brand_origin,
    'unit', return_line.unit,
    'source_kind', return_line.source_kind,
    'good_quantity_snapshot', return_line.good_quantity_snapshot,
    'eligible_quantity_at_submit', return_line.eligible_quantity_at_submit,
    'return_quantity', return_line.return_quantity,
    'line_note', return_line.line_note,
    'received_good_quantity', return_line.received_good_quantity,
    'received_damaged_quantity', return_line.received_damaged_quantity,
    'not_received_quantity', return_line.not_received_quantity,
    'receipt_note', return_line.receipt_note,
    'source_inventory_item_id', case when p_include_inventory
      then return_line.source_inventory_item_id else null end,
    'target_inventory_item_id', case when p_include_inventory
      then return_line.target_inventory_item_id else null end
  ) order by return_line.display_order), '[]'::jsonb)
  from public.v1_material_return_lines return_line
  left join public.v1_material_requests source_request
    on source_request.id = return_line.source_request_id
  left join public.v1_material_dispatches source_dispatch
    on source_dispatch.id = return_line.source_dispatch_id
  where return_line.material_return_id = p_return_id;
$$;

create or replace function public.v1_material_return_detail_projection(
  p_return_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_return public.v1_material_returns%rowtype;
  v_can_create boolean;
  v_can_approve boolean;
  v_can_receive boolean := public.v1_can_receive_project_material_return();
  v_result jsonb;
begin
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = p_return_id;
  if not found or not public.v1_material_return_readable(p_return_id) then
    raise exception 'V1_MATERIAL_RETURN_NOT_READABLE' using errcode = '42501';
  end if;
  v_can_create := public.v1_can_create_project_material_return(v_return.project_id);
  v_can_approve := public.v1_can_approve_project_material_return(v_return.project_id);

  select jsonb_build_object(
    'id', material_return.id,
    'return_number', material_return.return_number,
    'state', material_return.state,
    'record_version', material_return.record_version,
    'project_id', material_return.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'scope_id', material_return.scope_id,
    'scope_name', scope.name,
    'purpose', material_return.purpose,
    'note', material_return.note,
    'requested_return_date', material_return.requested_return_date,
    'drafted_at', material_return.drafted_at,
    'drafted_by_auth_user_id', material_return.drafted_by_auth_user_id,
    'drafted_by_display_name', public.v1_safe_profile_display_name(
      drafter.display_name, drafter.auth_user_id
    ),
    'drafted_by_role', material_return.drafted_by_role,
    'submitted_at', material_return.submitted_at,
    'submitted_by_display_name', case when submitter.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        submitter.display_name, submitter.auth_user_id
      ) end,
    'approved_at', material_return.approved_at,
    'approved_by_display_name', case when approver.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        approver.display_name, approver.auth_user_id
      ) end,
    'approved_by_exact_role', material_return.approved_by_exact_role,
    'approval_note', material_return.approval_note,
    'returned_for_changes_reason', material_return.returned_for_changes_reason,
    'dispatched_at', material_return.dispatched_at,
    'dispatched_by_display_name', case when dispatcher.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        dispatcher.display_name, dispatcher.auth_user_id
      ) end,
    'driver_name', material_return.driver_name,
    'vehicle_reference', material_return.vehicle_reference,
    'delivery_note_reference', material_return.delivery_note_reference,
    'confirmed_at', material_return.decided_at,
    'confirmed_by_display_name', case when receiver.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        receiver.display_name, receiver.auth_user_id
      ) end,
    'warehouse_receipt_note', material_return.warehouse_receipt_note,
    'rejection_reason', material_return.rejection_reason,
    'cancelled_at', material_return.cancelled_at,
    'cancelled_by_display_name', case when canceller.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        canceller.display_name, canceller.auth_user_id
      ) end,
    'cancellation_reason', material_return.cancellation_reason,
    'can_edit', v_can_create
      and material_return.state in ('draft', 'returned_for_changes')
      and (material_return.drafted_by_auth_user_id = auth.uid()
        or public.v1_current_role() = 'admin'),
    'can_submit', v_can_create
      and material_return.state in ('draft', 'returned_for_changes')
      and (material_return.drafted_by_auth_user_id = auth.uid()
        or public.v1_current_role() = 'admin'),
    'can_approve', v_can_approve and material_return.state = 'awaiting_approval',
    'can_return_for_changes', v_can_approve
      and material_return.state = 'awaiting_approval',
    'can_dispatch', v_can_create and material_return.state = 'approved',
    'can_confirm', v_can_receive and material_return.state = 'dispatched',
    'can_cancel', (v_can_create or v_can_approve)
      and material_return.state in (
        'draft', 'returned_for_changes', 'awaiting_approval', 'approved'
      ),
    'lines', public.v1_material_return_line_projection(
      material_return.id, v_can_receive
    ),
    'inventory_items', case when v_can_receive then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'item_description', item.item_description,
        'brand_origin', item.brand_origin,
        'unit', item.unit
      ) order by lower(item.item_description), item.id)
      from public.v1_inventory_items item where item.is_active
    ), '[]'::jsonb) else '[]'::jsonb end
  ) into v_result
  from public.v1_material_returns material_return
  join public.v1_projects project on project.id = material_return.project_id
  join public.v1_project_scopes scope on scope.id = material_return.scope_id
  join public.v1_profiles drafter
    on drafter.auth_user_id = material_return.drafted_by_auth_user_id
  left join public.v1_profiles submitter
    on submitter.auth_user_id = material_return.submitted_by_auth_user_id
  left join public.v1_profiles approver
    on approver.auth_user_id = material_return.approved_by_auth_user_id
  left join public.v1_profiles dispatcher
    on dispatcher.auth_user_id = material_return.dispatched_by_auth_user_id
  left join public.v1_profiles receiver
    on receiver.auth_user_id = material_return.decided_by_auth_user_id
  left join public.v1_profiles canceller
    on canceller.auth_user_id = material_return.cancelled_by_auth_user_id
  where material_return.id = p_return_id;
  return v_result;
end;
$$;

create or replace function public.v1_list_material_returns(
  p_project_id uuid default null,
  p_state text default null,
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_RETURN_REGISTER_DENIED' using errcode = '42501';
  end if;
  if p_project_id is not null and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_RETURN_REGISTER_DENIED' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', material_return.id,
    'return_number', material_return.return_number,
    'state', material_return.state,
    'record_version', material_return.record_version,
    'project_id', material_return.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'scope_id', material_return.scope_id,
    'scope_name', scope.name,
    'purpose', material_return.purpose,
    'drafted_by_display_name', public.v1_safe_profile_display_name(
      drafter.display_name, drafter.auth_user_id
    ),
    'line_count', (select count(*) from public.v1_material_return_lines line
      where line.material_return_id = material_return.id),
    'total_quantity', (select coalesce(sum(line.return_quantity), 0)
      from public.v1_material_return_lines line
      where line.material_return_id = material_return.id),
    'updated_at', material_return.updated_at,
    'attention_owner', case material_return.state
      when 'awaiting_approval' then 'engineering'
      when 'approved' then 'project_team'
      when 'dispatched' then 'procurement'
      when 'returned_for_changes' then 'creator'
      else null end
  ) order by material_return.updated_at desc, material_return.id), '[]'::jsonb)
  into v_result
  from public.v1_material_returns material_return
  join public.v1_projects project on project.id = material_return.project_id
  join public.v1_project_scopes scope on scope.id = material_return.scope_id
  join public.v1_profiles drafter
    on drafter.auth_user_id = material_return.drafted_by_auth_user_id
  where public.v1_project_readable(material_return.project_id)
    and (p_project_id is null or material_return.project_id = p_project_id)
    and (p_state is null or p_state = '' or material_return.state = p_state)
    and (v_search is null
      or material_return.return_number ilike '%' || v_search || '%'
      or project.project_ref ilike '%' || v_search || '%'
      or project.name ilike '%' || v_search || '%'
      or scope.name ilike '%' || v_search || '%'
      or coalesce(material_return.purpose, '') ilike '%' || v_search || '%'
      or exists (
        select 1 from public.v1_material_return_lines line
        where line.material_return_id = material_return.id
          and line.item_description ilike '%' || v_search || '%'
      ));
  return v_result;
end;
$$;

create or replace function public.v1_material_return_creation_workspace(
  p_project_id uuid,
  p_return_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.v1_can_create_project_material_return(p_project_id) then
    raise exception 'V1_MATERIAL_RETURN_CREATE_DENIED' using errcode = '42501';
  end if;
  if p_return_id is not null and not exists (
    select 1 from public.v1_material_returns material_return
    where material_return.id = p_return_id
      and material_return.project_id = p_project_id
      and material_return.state in ('draft', 'returned_for_changes')
      and (material_return.drafted_by_auth_user_id = auth.uid()
        or public.v1_current_role() = 'admin')
  ) then
    raise exception 'V1_MATERIAL_RETURN_DRAFT_NOT_EDITABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'scopes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', scope.id, 'name', scope.name, 'scope_kind', scope.scope_kind
    ) order by case when scope.scope_kind = 'common' then 0 else 1 end,
      scope.name)
      from public.v1_project_scopes scope
      where scope.project_id = project.id and scope.is_active), '[]'::jsonb),
    'units', coalesce((select jsonb_agg(unit_record.short_code order by
      unit_record.unit_type, unit_record.name, unit_record.id)
      from public.v1_configuration_units unit_record
      where unit_record.is_active), '[]'::jsonb),
    'candidates', coalesce((select jsonb_agg(jsonb_build_object(
      'receipt_review_line_id', review_line.id,
      'request_id', request.id,
      'request_number', request.request_number,
      'dispatch_id', dispatch.id,
      'dispatch_number', dispatch.dispatch_number,
      'scope_id', request.scope_id,
      'scope_name', scope.name,
      'item_description', dispatch_line.item_description,
      'brand_origin', dispatch_line.brand_origin,
      'unit', dispatch_line.unit,
      'source_kind', dispatch_line.source_kind,
      'good_received_qty', review_line.good_qty,
      'committed_return_qty', coalesce((
        select sum(other_line.return_quantity)
        from public.v1_material_return_lines other_line
        join public.v1_material_returns other_return
          on other_return.id = other_line.material_return_id
        where other_line.receipt_review_line_id = review_line.id
          and other_return.id is distinct from p_return_id
          and other_return.state in (
            'awaiting_approval', 'approved', 'dispatched', 'confirmed'
          )
      ), 0),
      'eligible_return_qty', greatest(0, review_line.good_qty - coalesce((
        select sum(other_line.return_quantity)
        from public.v1_material_return_lines other_line
        join public.v1_material_returns other_return
          on other_return.id = other_line.material_return_id
        where other_line.receipt_review_line_id = review_line.id
          and other_return.id is distinct from p_return_id
          and other_return.state in (
            'awaiting_approval', 'approved', 'dispatched', 'confirmed'
          )
      ), 0))
    ) order by review.reviewed_at desc, dispatch_line.created_at)
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
      join public.v1_material_requests request on request.id = dispatch.request_id
      join public.v1_project_scopes scope on scope.id = request.scope_id
      where request.project_id = project.id and review.state = 'confirmed'
        and review_line.good_qty > 0), '[]'::jsonb),
    'draft', case when p_return_id is null then null
      else public.v1_material_return_detail_projection(p_return_id) end
  ) into v_result
  from public.v1_projects project where project.id = p_project_id;
  return v_result;
end;
$$;

create or replace function public.v1_save_project_material_return_draft(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_project_id uuid := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_scope_id uuid := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_purpose text := nullif(btrim(coalesce(p_payload ->> 'purpose', '')), '');
  v_note text := nullif(btrim(coalesce(p_payload ->> 'note', '')), '');
  v_requested_date date := nullif(p_payload ->> 'requested_return_date', '')::date;
  v_lines jsonb := coalesce(p_payload -> 'lines', '[]'::jsonb);
  v_return public.v1_material_returns%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_line jsonb;
  v_origin text;
  v_review_line_id uuid;
  v_qty numeric(18, 4);
  v_source record;
  v_description text;
  v_brand text;
  v_unit text;
  v_line_note text;
  v_order integer := 0;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'return_id', 'project_id', 'scope_id', 'expected_version', 'purpose',
    'note', 'requested_return_date', 'lines'
  ], 'save_project_material_return_draft');
  if v_project_id is null or v_scope_id is null or v_expected_version is null
    or v_expected_version < 0 or v_purpose is null
    or jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) = 0
    or not public.v1_can_create_project_material_return(v_project_id)
    or not exists (select 1 from public.v1_project_scopes scope
      where scope.id = v_scope_id and scope.project_id = v_project_id
        and scope.is_active) then
    raise exception 'V1_MATERIAL_RETURN_DRAFT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_project_material_return_draft', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  perform 1 from public.v1_projects project where project.id = v_project_id for update;
  if v_return_id is null then
    if v_expected_version <> 0 then
      raise exception 'V1_MATERIAL_RETURN_DRAFT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
  else
    select * into v_return from public.v1_material_returns material_return
    where material_return.id = v_return_id and material_return.project_id = v_project_id
    for update;
    if not found or v_return.state not in ('draft', 'returned_for_changes')
      or (v_return.drafted_by_auth_user_id <> v_actor
        and public.v1_current_role() <> 'admin') then
      raise exception 'V1_MATERIAL_RETURN_DRAFT_NOT_EDITABLE'
        using errcode = '42501';
    end if;
    if v_return.record_version <> v_expected_version then
      raise exception 'V1_MATERIAL_RETURN_DRAFT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
  end if;
  if v_return_id is null then
    insert into public.v1_material_returns (
      request_id, project_id, scope_id, state, purpose, note,
      requested_return_date, drafted_by_auth_user_id, drafted_by_role
    ) values (
      null, v_project_id, v_scope_id, 'draft', v_purpose, v_note,
      v_requested_date, v_actor, v_exact_role
    ) returning * into v_return;
    v_return_id := v_return.id;
  else
    delete from public.v1_material_return_lines
    where material_return_id = v_return_id;
    update public.v1_material_returns
    set scope_id = v_scope_id, state = 'draft', purpose = v_purpose,
        note = v_note, requested_return_date = v_requested_date,
        returned_for_changes_reason = null,
        record_version = record_version + 1, updated_at = clock_timestamp()
    where id = v_return_id returning * into v_return;
  end if;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(v_line, array[
      'origin_kind', 'receipt_review_line_id', 'item_description',
      'brand_origin', 'unit', 'return_qty', 'note'
    ], 'project_material_return_line');
    v_origin := coalesce(v_line ->> 'origin_kind', '');
    v_review_line_id := nullif(btrim(coalesce(
      v_line ->> 'receipt_review_line_id', ''
    )), '')::uuid;
    v_qty := nullif(v_line ->> 'return_qty', '')::numeric(18, 4);
    v_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_brand := nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), '');
    v_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    v_line_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    if v_origin not in ('delivered', 'custom') or v_qty is null or v_qty <= 0 then
      raise exception 'V1_MATERIAL_RETURN_LINE_INVALID' using errcode = '22023';
    end if;
    v_order := v_order + 1;
    if v_origin = 'delivered' then
      select review_line.good_qty, dispatch_line.id dispatch_line_id,
        dispatch_line.request_line_id, dispatch_line.source_kind,
        dispatch_line.inventory_item_id, dispatch_line.item_description,
        dispatch_line.brand_origin, dispatch_line.unit,
        dispatch.id dispatch_id, request.id request_id
      into v_source
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
      join public.v1_material_requests request on request.id = dispatch.request_id
      where review_line.id = v_review_line_id and review.state = 'confirmed'
        and request.project_id = v_project_id
        and request.scope_id = v_scope_id;
      if not found or v_qty > v_source.good_qty then
        raise exception 'V1_MATERIAL_RETURN_SOURCE_INVALID' using errcode = '22023';
      end if;
      insert into public.v1_material_return_lines (
        material_return_id, receipt_review_line_id, dispatch_line_id,
        request_line_id, origin_kind, source_request_id, source_dispatch_id,
        source_kind, source_inventory_item_id, item_description, brand_origin,
        unit, good_quantity_snapshot, return_quantity, line_note, display_order
      ) values (
        v_return_id, v_review_line_id, v_source.dispatch_line_id,
        v_source.request_line_id, 'delivered', v_source.request_id,
        v_source.dispatch_id, v_source.source_kind,
        v_source.inventory_item_id, v_source.item_description,
        v_source.brand_origin, v_source.unit, v_source.good_qty, v_qty,
        v_line_note, v_order
      );
    else
      if v_description is null or v_unit is null or not exists (
        select 1 from public.v1_configuration_units controlled_unit
        where controlled_unit.is_active
          and lower(btrim(controlled_unit.short_code)) = lower(btrim(v_unit))
      ) then
        raise exception 'V1_MATERIAL_RETURN_CUSTOM_LINE_INVALID'
          using errcode = '22023';
      end if;
      insert into public.v1_material_return_lines (
        material_return_id, origin_kind, source_kind, item_description,
        brand_origin, unit, return_quantity, line_note, display_order
      ) values (
        v_return_id, 'custom', 'custom', v_description, v_brand, v_unit,
        v_qty, v_line_note, v_order
      );
    end if;
  end loop;

  v_response := public.v1_material_return_detail_projection(v_return_id);
  perform public.v1_write_audit_event(
    'material_return_draft_saved', 'material_return', v_return_id, v_project_id,
    null, jsonb_build_object('line_count', v_order, 'source', 'project_wide'),
    null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_project_material_return_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_submit_project_material_return(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_return public.v1_material_returns%rowtype;
  v_line public.v1_material_return_lines%rowtype;
  v_good numeric(18, 4);
  v_committed numeric(18, 4);
  v_sequence integer;
  v_number text;
  v_default_purpose text;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload,
    array['return_id', 'expected_version'], 'submit_project_material_return');
  if v_return_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_MATERIAL_RETURN_SUBMIT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  if not found or not public.v1_can_create_project_material_return(v_return.project_id)
    or (v_return.drafted_by_auth_user_id <> v_actor
      and public.v1_current_role() <> 'admin') then
    raise exception 'V1_MATERIAL_RETURN_SUBMIT_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_submit_project_material_return', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_return.state not in ('draft', 'returned_for_changes')
    or v_return.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_RETURN_SUBMIT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if not exists (select 1 from public.v1_material_return_lines line
    where line.material_return_id = v_return.id) then
    raise exception 'V1_MATERIAL_RETURN_LINES_REQUIRED' using errcode = '22023';
  end if;
  if v_return.purpose is null then
    select 'Return from material request ' || request.request_number
      into v_default_purpose
    from public.v1_material_requests request
    where request.id = v_return.request_id;
    if v_default_purpose is null then
      raise exception 'V1_MATERIAL_RETURN_PURPOSE_REQUIRED'
        using errcode = '22023';
    end if;
  end if;
  for v_line in select line.* from public.v1_material_return_lines line
    where line.material_return_id = v_return.id order by line.id for update
  loop
    if v_line.origin_kind = 'delivered' then
      perform 1 from public.v1_receipt_review_lines review_line
      where review_line.id = v_line.receipt_review_line_id for update;
      select review_line.good_qty into v_good
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
      where review_line.id = v_line.receipt_review_line_id and review.state = 'confirmed';
      select coalesce(sum(other_line.return_quantity), 0) into v_committed
      from public.v1_material_return_lines other_line
      join public.v1_material_returns other_return
        on other_return.id = other_line.material_return_id
      where other_line.receipt_review_line_id = v_line.receipt_review_line_id
        and other_return.id <> v_return.id
        and other_return.state in (
          'awaiting_approval', 'approved', 'dispatched', 'confirmed'
        );
      if v_good is null or v_line.return_quantity > v_good - v_committed then
        raise exception 'V1_MATERIAL_RETURN_ELIGIBLE_QTY_EXCEEDED'
          using errcode = '22023';
      end if;
      update public.v1_material_return_lines
      set eligible_quantity_at_submit = v_good - v_committed
      where id = v_line.id;
    end if;
  end loop;
  if v_return.return_number is null then
    insert into public.v1_return_reference_counters (
      project_id, next_return_sequence, updated_at
    ) values (v_return.project_id, 2, clock_timestamp())
    on conflict (project_id) do update set
      next_return_sequence = public.v1_return_reference_counters.next_return_sequence + 1,
      updated_at = clock_timestamp()
    returning next_return_sequence - 1 into v_sequence;
    select project.project_ref || '-RTN' || lpad(v_sequence::text, 3, '0')
      into v_number from public.v1_projects project
      where project.id = v_return.project_id;
  else
    v_number := v_return.return_number;
  end if;
  update public.v1_material_returns
  set state = 'awaiting_approval', return_number = v_number,
      purpose = coalesce(purpose, v_default_purpose),
      submitted_by_auth_user_id = v_actor, submitted_by_role = v_exact_role,
      submitted_at = clock_timestamp(), returned_for_changes_reason = null,
      record_version = record_version + 1, updated_at = clock_timestamp()
  where id = v_return.id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select candidate.auth_user_id, 'material_return_approval_required',
    'material_return', v_return.id, v_return.project_id
  from (
    select member.member_auth_user_id auth_user_id
    from public.v1_project_members member
    where member.project_id = v_return.project_id
      and member.project_role = 'project_engineer'
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
    union
    select profile.auth_user_id
    from public.v1_profiles profile
    join auth.users auth_user on auth_user.id = profile.auth_user_id
    where profile.is_active and coalesce(
      auth_user.raw_app_meta_data ->> 'role', ''
    ) in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller', 'admin'
    )
  ) candidate
  where candidate.auth_user_id <> v_actor
  on conflict do nothing;

  v_response := public.v1_material_return_detail_projection(v_return.id);
  perform public.v1_write_audit_event(
    'material_return_submitted_for_approval', 'material_return', v_return.id,
    v_return.project_id, null, jsonb_build_object('return_number', v_number),
    null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_submit_project_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Compatibility adapters keep preserved request-scoped drafts readable while
-- forcing them through the same Engineering approval, site dispatch and
-- Procurement receipt controls. They must never retain the retired
-- submitted-directly-to-Procurement shortcut.
create or replace function public.v1_submit_material_return(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_return_id uuid := nullif(btrim(coalesce(
    p_payload ->> 'return_id', ''
  )), '')::uuid;
  v_request_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version'], 'submit_material_return'
  );
  select material_return.request_id into v_request_id
  from public.v1_material_returns material_return
  where material_return.id = v_return_id;
  if v_request_id is null then
    raise exception 'V1_RETURN_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  perform public.v1_submit_project_material_return(p_payload, p_idempotency_key);
  return public.v1_returns_documents_workspace_projection(v_request_id);
end;
$$;

create or replace function public.v1_confirm_material_return(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_return_id uuid := nullif(btrim(coalesce(
    p_payload ->> 'return_id', ''
  )), '')::uuid;
  v_expected_version integer := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_mappings jsonb := coalesce(p_payload -> 'line_mappings', '[]'::jsonb);
  v_request_id uuid;
  v_receipts jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version', 'line_mappings'],
    'confirm_material_return'
  );
  if v_return_id is null or v_expected_version is null
    or jsonb_typeof(v_mappings) <> 'array' then
    raise exception 'V1_RETURN_CONFIRM_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select material_return.request_id into v_request_id
  from public.v1_material_returns material_return
  where material_return.id = v_return_id;
  if v_request_id is null then
    raise exception 'V1_RETURN_CONFIRM_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'return_line_id', return_line.id,
    'received_good_qty', return_line.return_quantity,
    'damaged_qty', 0,
    'not_received_qty', 0,
    'inventory_item_id', case
      when return_line.source_kind = 'warehouse' then null
      else mapping.value ->> 'inventory_item_id' end,
    'new_inventory_item', case
      when return_line.source_kind = 'warehouse' then null
      else coalesce(mapping.value -> 'new_inventory_item', 'null'::jsonb) end,
    'note', null
  ) order by return_line.display_order, return_line.id), '[]'::jsonb)
  into v_receipts
  from public.v1_material_return_lines return_line
  left join lateral (
    select value
    from jsonb_array_elements(v_mappings) value
    where nullif(btrim(coalesce(
      value ->> 'return_line_id', ''
    )), '')::uuid = return_line.id
    limit 1
  ) mapping on true
  where return_line.material_return_id = v_return_id;
  perform public.v1_confirm_project_material_return(
    jsonb_build_object(
      'return_id', v_return_id,
      'expected_version', v_expected_version,
      'receipt_note', null,
      'line_receipts', v_receipts
    ),
    p_idempotency_key
  );
  return public.v1_returns_documents_workspace_projection(v_request_id);
end;
$$;

create or replace function public.v1_reject_material_return(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_return_id uuid := nullif(btrim(coalesce(
    p_payload ->> 'return_id', ''
  )), '')::uuid;
  v_request_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version', 'reason'],
    'reject_material_return'
  );
  select material_return.request_id into v_request_id
  from public.v1_material_returns material_return
  where material_return.id = v_return_id;
  if v_request_id is null then
    raise exception 'V1_RETURN_REJECT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  perform public.v1_decide_project_material_return(
    jsonb_build_object(
      'return_id', v_return_id,
      'expected_version', p_payload ->> 'expected_version',
      'decision', 'rejected',
      'reason', p_payload ->> 'reason'
    ),
    p_idempotency_key
  );
  return public.v1_returns_documents_workspace_projection(v_request_id);
end;
$$;

create or replace function public.v1_decide_project_material_return(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_decision text := coalesce(p_payload ->> 'decision', '');
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_return public.v1_material_returns%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload,
    array['return_id', 'expected_version', 'decision', 'reason'],
    'decide_project_material_return');
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or v_decision not in ('approved', 'returned_for_changes', 'rejected')
    or (v_decision <> 'approved' and v_reason is null) then
    raise exception 'V1_MATERIAL_RETURN_DECISION_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  if not found or not public.v1_can_approve_project_material_return(
    v_return.project_id
  ) then
    raise exception 'V1_MATERIAL_RETURN_DECISION_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_decide_project_material_return', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_return.state <> 'awaiting_approval'
    or v_return.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_RETURN_DECISION_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  update public.v1_material_returns
  set state = v_decision,
      approved_by_auth_user_id = case when v_decision = 'approved'
        then v_actor else null end,
      approved_by_exact_role = case when v_decision = 'approved'
        then v_exact_role else null end,
      approved_at = case when v_decision = 'approved'
        then clock_timestamp() else null end,
      approval_note = case when v_decision = 'approved' then v_reason else null end,
      returned_for_changes_reason = case when v_decision = 'returned_for_changes'
        then v_reason else null end,
      rejection_reason = case when v_decision = 'rejected' then v_reason else null end,
      record_version = record_version + 1, updated_at = clock_timestamp()
  where id = v_return.id;
  if v_return.submitted_by_auth_user_id <> v_actor then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_return.submitted_by_auth_user_id,
      case v_decision
        when 'approved' then 'material_return_approved'
        when 'returned_for_changes' then 'material_return_returned_for_changes'
        else 'material_return_rejected' end,
      'material_return', v_return.id, v_return.project_id
    );
  end if;
  v_response := public.v1_material_return_detail_projection(v_return.id);
  perform public.v1_write_audit_event(
    'material_return_' || v_decision, 'material_return', v_return.id,
    v_return.project_id, jsonb_build_object('state', v_return.state),
    jsonb_build_object('state', v_decision), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_decide_project_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_dispatch_project_material_return(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_driver text := nullif(btrim(coalesce(p_payload ->> 'driver_name', '')), '');
  v_vehicle text := nullif(btrim(coalesce(p_payload ->> 'vehicle_reference', '')), '');
  v_delivery_note text := nullif(btrim(coalesce(
    p_payload ->> 'delivery_note_reference', ''
  )), '');
  v_return public.v1_material_returns%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'return_id', 'expected_version', 'driver_name', 'vehicle_reference',
    'delivery_note_reference'
  ], 'dispatch_project_material_return');
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or v_driver is null or v_delivery_note is null then
    raise exception 'V1_MATERIAL_RETURN_DISPATCH_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  if not found or not public.v1_can_create_project_material_return(v_return.project_id) then
    raise exception 'V1_MATERIAL_RETURN_DISPATCH_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_dispatch_project_material_return', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_return.state <> 'approved' or v_return.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_RETURN_DISPATCH_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  update public.v1_material_returns
  set state = 'dispatched', dispatched_by_auth_user_id = v_actor,
      dispatched_by_exact_role = v_exact_role, dispatched_at = clock_timestamp(),
      driver_name = v_driver, vehicle_reference = v_vehicle,
      delivery_note_reference = v_delivery_note,
      record_version = record_version + 1, updated_at = clock_timestamp()
  where id = v_return.id;
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id, 'material_return_receipt_required',
    'material_return', v_return.id, v_return.project_id
  from public.v1_profiles profile
  join auth.users auth_user on auth_user.id = profile.auth_user_id
  where profile.is_active and coalesce(
    auth_user.raw_app_meta_data ->> 'role', ''
  ) in ('procurement', 'admin') and profile.auth_user_id <> v_actor
  on conflict do nothing;
  v_response := public.v1_material_return_detail_projection(v_return.id);
  perform public.v1_write_audit_event(
    'material_return_dispatched', 'material_return', v_return.id,
    v_return.project_id, null, jsonb_build_object(
      'driver_name', v_driver, 'delivery_note_reference', v_delivery_note
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_dispatch_project_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_confirm_project_material_return(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_receipt_note text := nullif(btrim(coalesce(p_payload ->> 'receipt_note', '')), '');
  v_receipts jsonb := coalesce(p_payload -> 'line_receipts', '[]'::jsonb);
  v_return public.v1_material_returns%rowtype;
  v_line public.v1_material_return_lines%rowtype;
  v_receipt jsonb;
  v_good numeric(18, 4);
  v_damaged numeric(18, 4);
  v_missing numeric(18, 4);
  v_target uuid;
  v_new_item jsonb;
  v_target_unit text;
  v_on_hand numeric(18, 4);
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'return_id', 'expected_version', 'receipt_note', 'line_receipts'
  ], 'confirm_project_material_return');
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or jsonb_typeof(v_receipts) <> 'array' then
    raise exception 'V1_MATERIAL_RETURN_RECEIPT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  if not found or not public.v1_can_receive_project_material_return() then
    raise exception 'V1_MATERIAL_RETURN_RECEIPT_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_confirm_project_material_return', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_return.state <> 'dispatched' or v_return.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_RETURN_RECEIPT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if jsonb_array_length(v_receipts) <> (
    select count(*) from public.v1_material_return_lines line
    where line.material_return_id = v_return.id
  ) or (select count(distinct nullif(btrim(coalesce(
    value ->> 'return_line_id', ''
  )), '')::uuid) from jsonb_array_elements(v_receipts)) <>
    jsonb_array_length(v_receipts) then
    raise exception 'V1_MATERIAL_RETURN_RECEIPT_LINES_INVALID'
      using errcode = '22023';
  end if;
  for v_line in select line.* from public.v1_material_return_lines line
    where line.material_return_id = v_return.id order by line.id for update
  loop
    select value into v_receipt from jsonb_array_elements(v_receipts)
    where nullif(btrim(coalesce(value ->> 'return_line_id', '')), '')::uuid = v_line.id;
    perform public.v1_assert_object_keys(v_receipt, array[
      'return_line_id', 'received_good_qty', 'damaged_qty', 'not_received_qty',
      'inventory_item_id', 'new_inventory_item', 'note'
    ], 'project_material_return_receipt_line');
    v_good := coalesce(nullif(v_receipt ->> 'received_good_qty', '')::numeric(18, 4), 0);
    v_damaged := coalesce(nullif(v_receipt ->> 'damaged_qty', '')::numeric(18, 4), 0);
    v_missing := coalesce(nullif(v_receipt ->> 'not_received_qty', '')::numeric(18, 4), 0);
    if v_good < 0 or v_damaged < 0 or v_missing < 0
      or v_good + v_damaged + v_missing <> v_line.return_quantity then
      raise exception 'V1_MATERIAL_RETURN_RECEIPT_QTY_INVALID'
        using errcode = '22023';
    end if;
    v_target := nullif(btrim(coalesce(v_receipt ->> 'inventory_item_id', '')), '')::uuid;
    v_new_item := coalesce(v_receipt -> 'new_inventory_item', 'null'::jsonb);
    if v_good > 0 then
      if v_line.source_kind = 'warehouse' then
        v_target := v_line.source_inventory_item_id;
      elsif v_target is null and jsonb_typeof(v_new_item) = 'object' then
        perform public.v1_assert_object_keys(v_new_item,
          array['item_description', 'brand_origin', 'unit'],
          'new_return_inventory_item');
        if nullif(btrim(coalesce(v_new_item ->> 'item_description', '')), '') is null
          or lower(btrim(coalesce(v_new_item ->> 'unit', ''))) <>
            lower(btrim(v_line.unit)) then
          raise exception 'V1_MATERIAL_RETURN_NEW_ITEM_INVALID'
            using errcode = '22023';
        end if;
        select item.id into v_target from public.v1_inventory_items item
        where item.is_active
          and lower(btrim(item.item_description)) = lower(btrim(
            v_new_item ->> 'item_description'
          ))
          and lower(coalesce(btrim(item.brand_origin), '')) = lower(coalesce(
            nullif(btrim(v_new_item ->> 'brand_origin'), ''), ''
          ))
          and lower(btrim(item.unit)) = lower(btrim(v_line.unit))
        limit 1;
        if v_target is null then
          insert into public.v1_inventory_items (
            item_description, brand_origin, unit, created_by_auth_user_id
          ) values (
            btrim(v_new_item ->> 'item_description'),
            nullif(btrim(coalesce(v_new_item ->> 'brand_origin', '')), ''),
            btrim(v_line.unit), v_actor
          ) returning id into v_target;
          insert into public.v1_inventory_balances (inventory_item_id)
          values (v_target);
        end if;
      end if;
      select item.unit into v_target_unit from public.v1_inventory_items item
      where item.id = v_target and item.is_active;
      if not found or lower(btrim(v_target_unit)) <> lower(btrim(v_line.unit)) then
        raise exception 'V1_MATERIAL_RETURN_TARGET_ITEM_INVALID'
          using errcode = '22023';
      end if;
      perform 1 from public.v1_inventory_balances balance
      where balance.inventory_item_id = v_target for update;
      select balance.on_hand_qty into v_on_hand
      from public.v1_inventory_balances balance
      where balance.inventory_item_id = v_target;
      update public.v1_inventory_balances
      set on_hand_qty = on_hand_qty + v_good,
          record_version = record_version + 1,
          updated_at = clock_timestamp()
      where inventory_item_id = v_target;
      insert into public.v1_inventory_movements (
        inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
        source_entity_type, source_entity_id, reason, actor_auth_user_id,
        idempotency_key
      ) values (
        v_target, 'return', v_good, v_on_hand + v_good,
        'material_return_line', v_line.id,
        'Confirmed project return ' || v_return.return_number,
        v_actor,
        (substr(md5(p_idempotency_key::text || ':' || v_line.id::text), 1, 8)
          || '-' || substr(md5(p_idempotency_key::text || ':' || v_line.id::text), 9, 4)
          || '-' || substr(md5(p_idempotency_key::text || ':' || v_line.id::text), 13, 4)
          || '-' || substr(md5(p_idempotency_key::text || ':' || v_line.id::text), 17, 4)
          || '-' || substr(md5(p_idempotency_key::text || ':' || v_line.id::text), 21, 12))::uuid
      );
    else
      v_target := null;
    end if;
    update public.v1_material_return_lines
    set received_good_quantity = v_good,
        received_damaged_quantity = v_damaged,
        not_received_quantity = v_missing,
        target_inventory_item_id = v_target,
        receipt_note = nullif(btrim(coalesce(v_receipt ->> 'note', '')), '')
    where id = v_line.id;
  end loop;
  update public.v1_material_returns
  set state = 'confirmed', decided_by_auth_user_id = v_actor,
      decided_by_role = v_exact_role, decided_at = clock_timestamp(),
      warehouse_receipt_note = v_receipt_note,
      record_version = record_version + 1, updated_at = clock_timestamp()
  where id = v_return.id;
  if v_return.submitted_by_auth_user_id is not null
    and v_return.submitted_by_auth_user_id <> v_actor then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_return.submitted_by_auth_user_id, 'material_return_confirmed',
      'material_return', v_return.id, v_return.project_id
    );
  end if;
  v_response := public.v1_material_return_detail_projection(v_return.id);
  perform public.v1_write_audit_event(
    'material_return_confirmed', 'material_return', v_return.id,
    v_return.project_id, null, jsonb_build_object(
      'return_number', v_return.return_number, 'receipt_note', v_receipt_note
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_project_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_cancel_project_material_return(
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
  v_exact_role text := public.v1_current_exact_role();
  v_return_id uuid := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version integer := nullif(p_payload ->> 'expected_version', '')::integer;
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_return public.v1_material_returns%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version', 'reason'],
    'cancel_project_material_return'
  );
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or v_reason is null then
    raise exception 'V1_MATERIAL_RETURN_CANCEL_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  if not found or not (
    public.v1_can_approve_project_material_return(v_return.project_id)
    or (
      public.v1_can_create_project_material_return(v_return.project_id)
      and v_return.drafted_by_auth_user_id = v_actor
    )
  ) then
    raise exception 'V1_MATERIAL_RETURN_CANCEL_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_cancel_project_material_return', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_return.state not in (
      'draft', 'returned_for_changes', 'awaiting_approval', 'approved'
    ) or v_return.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_RETURN_CANCEL_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  update public.v1_material_returns
  set state = 'cancelled', cancelled_by_auth_user_id = v_actor,
      cancelled_by_exact_role = v_exact_role, cancelled_at = clock_timestamp(),
      cancellation_reason = v_reason, record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_return.id;
  if v_return.submitted_by_auth_user_id is not null
    and v_return.submitted_by_auth_user_id <> v_actor then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_return.submitted_by_auth_user_id, 'material_return_cancelled',
      'material_return', v_return.id, v_return.project_id
    );
  end if;
  v_response := public.v1_material_return_detail_projection(v_return.id);
  perform public.v1_write_audit_event(
    'material_return_cancelled', 'material_return', v_return.id,
    v_return.project_id, jsonb_build_object('state', v_return.state),
    jsonb_build_object('state', 'cancelled'), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_cancel_project_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_attribute_material_return_trigger_r38_9()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state in ('submitted', 'dispatched') and new.state = 'confirmed' then
    perform public.v1_attribute_material_return_r38_9(
      new.id, new.decided_by_auth_user_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists v1_attribute_material_return_r38_9
  on public.v1_material_returns;
create trigger v1_attribute_material_return_r38_9
  after update of state on public.v1_material_returns
  for each row execute function public.v1_attribute_material_return_trigger_r38_9();

create or replace function public.v1_notify_material_return_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Command RPCs append the targeted workflow notifications. This trigger is
  -- retained as a no-op compatibility hook so older migrations do not create
  -- duplicate alerts for the expanded state graph.
  return new;
end;
$$;

-- Project-wide returns may not have a request_id. Authorize return documents
-- from the return's project instead of requiring a historical MR link.
create or replace function public.v1_document_target_readable(
  p_entity_type text,
  p_entity_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_project_id uuid;
begin
  case p_entity_type
    when 'project' then
      return public.v1_project_readable(p_entity_id);
    when 'boq_group' then
      select project_id into v_project_id from public.v1_boq_groups
      where id = p_entity_id;
      return v_project_id is not null
        and public.v1_project_readable(v_project_id);
    when 'material_request' then
      return public.v1_material_request_readable(p_entity_id);
    when 'dispatch' then
      select request_id into v_request_id from public.v1_material_dispatches
      where id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    when 'receipt_review' then
      select request_id into v_request_id from public.v1_receipt_reviews
      where id = p_entity_id and state = 'confirmed';
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    when 'material_return' then
      return public.v1_material_return_readable(p_entity_id);
    when 'delivery_order' then
      select dispatch_record.request_id into v_request_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = delivery_order.dispatch_id
      where delivery_order.id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    when 'rental_property' then
      return auth.uid() is not null and public.v1_current_actor_is_active()
        and public.v1_current_role() = 'admin' and exists (
          select 1 from public.v1_rental_properties property_record
          where property_record.id = p_entity_id
        );
    when 'supplier' then
      return public.v1_can_manage_inventory() and exists (
        select 1 from public.v1_suppliers supplier where supplier.id = p_entity_id
      );
    when 'supplier_receipt_batch' then
      return public.v1_can_manage_inventory() and exists (
        select 1 from public.v1_supplier_receipt_batches receipt_batch
        where receipt_batch.id = p_entity_id
      );
    else
      return false;
  end case;
end;
$$;

create or replace function public.v1_project_material_movements(
  p_project_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or p_project_id is null or not public.v1_project_readable(p_project_id) then
    raise exception 'V1_PROJECT_MATERIAL_MOVEMENT_DENIED' using errcode = '42501';
  end if;
  with movements as (
    select dispatch_line.id, 'dispatched'::text movement_kind,
      dispatch.dispatch_number reference, request.id request_id,
      coalesce(request.request_number, project.project_ref) request_number,
      dispatch_line.item_description, dispatch_line.brand_origin,
      dispatch_line.unit, dispatch_line.dispatched_qty quantity,
      public.v1_safe_profile_display_name(
        profile.display_name, dispatch.dispatched_by_auth_user_id
      ) actor_display_name, dispatch.dispatched_at occurred_at
    from public.v1_material_dispatches dispatch
    join public.v1_material_dispatch_lines dispatch_line
      on dispatch_line.dispatch_id = dispatch.id
    join public.v1_material_requests request on request.id = dispatch.request_id
    join public.v1_projects project on project.id = dispatch.project_id
    left join public.v1_profiles profile
      on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
    where dispatch.project_id = p_project_id
    union all
    select return_line.id, 'returned'::text, material_return.return_number,
      source_request.id,
      coalesce(source_request.request_number, project.project_ref),
      return_line.item_description, return_line.brand_origin,
      return_line.unit,
      coalesce(return_line.received_good_quantity, return_line.return_quantity),
      public.v1_safe_profile_display_name(
        profile.display_name, material_return.decided_by_auth_user_id
      ), material_return.decided_at
    from public.v1_material_returns material_return
    join public.v1_material_return_lines return_line
      on return_line.material_return_id = material_return.id
    left join public.v1_material_requests source_request
      on source_request.id = return_line.source_request_id
    join public.v1_projects project on project.id = material_return.project_id
    left join public.v1_profiles profile
      on profile.auth_user_id = material_return.decided_by_auth_user_id
    where material_return.project_id = p_project_id
      and material_return.state = 'confirmed'
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', movement.id, 'movement_kind', movement.movement_kind,
    'reference', movement.reference, 'request_id', movement.request_id,
    'request_number', movement.request_number,
    'item_description', movement.item_description,
    'brand_origin', movement.brand_origin, 'unit', movement.unit,
    'quantity', movement.quantity,
    'actor_display_name', movement.actor_display_name,
    'occurred_at', movement.occurred_at
  ) order by movement.occurred_at desc, movement.id), '[]'::jsonb)
  into v_result from movements movement;
  return v_result;
end;
$$;

create or replace function public.v1_list_material_return_projects()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', project.id,
    'project_ref', project.project_ref,
    'name', project.name,
    'state', project.state
  ) order by project.project_ref asc, project.id), '[]'::jsonb)
  from public.v1_projects project
  where project.state in ('active', 'on_hold', 'completed')
    and public.v1_can_create_project_material_return(project.id);
$$;

revoke all on function public.v1_can_create_project_material_return(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_approve_project_material_return(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_receive_project_material_return()
  from public, anon, authenticated;
revoke all on function public.v1_material_return_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_return_line_projection(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.v1_material_return_detail_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_returns(uuid,text,text)
  from public, anon, authenticated;
revoke all on function public.v1_material_return_creation_workspace(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_save_project_material_return_draft(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_submit_project_material_return(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_decide_project_material_return(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_dispatch_project_material_return(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_confirm_project_material_return(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_cancel_project_material_return(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_return_projects()
  from public, anon, authenticated;

grant execute on function public.v1_can_create_project_material_return(uuid)
  to authenticated, service_role;
grant execute on function public.v1_can_approve_project_material_return(uuid)
  to authenticated, service_role;
grant execute on function public.v1_can_receive_project_material_return()
  to authenticated, service_role;
grant execute on function public.v1_material_return_detail_projection(uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_material_returns(uuid,text,text)
  to authenticated, service_role;
grant execute on function public.v1_material_return_creation_workspace(uuid,uuid)
  to authenticated, service_role;
grant execute on function public.v1_save_project_material_return_draft(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_submit_project_material_return(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_decide_project_material_return(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_dispatch_project_material_return(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_confirm_project_material_return(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_cancel_project_material_return(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_material_return_projects()
  to authenticated, service_role;

notify pgrst, 'reload schema';
