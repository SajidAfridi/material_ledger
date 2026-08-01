-- Yorks V1 Batch 7: one protected warehouse workspace plus the first
-- committed logistics events. This extends, rather than replaces, Batch 6
-- reservations. Dispatch and receipt review are server transactions; no client
-- quantity or workflow mutation is authoritative.

alter table public.v1_inventory_reservations
  add column if not exists consumed_qty numeric(18, 4) not null default 0;

alter table public.v1_inventory_reservations
  drop constraint if exists v1_inventory_reservations_consumed_qty_check;
alter table public.v1_inventory_reservations
  add constraint v1_inventory_reservations_consumed_qty_check
  check (consumed_qty >= 0 and consumed_qty <= reserved_qty);

-- Batch 6 used one movement per adjustment. A dispatch can validly affect
-- several inventory items under one command, so its source line is part of the
-- uniqueness scope. The RPC idempotency response remains the primary retry
-- authority.
do $$
declare
  v_constraint_name text;
begin
  select constraint_name into v_constraint_name
  from information_schema.table_constraints
  where table_schema = 'public'
    and table_name = 'v1_inventory_movements'
    and constraint_type = 'UNIQUE'
    and constraint_name <> 'v1_inventory_movements_pkey'
  order by constraint_name
  limit 1;
  if v_constraint_name is not null then
    execute format(
      'alter table public.v1_inventory_movements drop constraint %I',
      v_constraint_name
    );
  end if;
end;
$$;

create unique index if not exists v1_inventory_movements_command_effect_idx
  on public.v1_inventory_movements (
    actor_auth_user_id,
    idempotency_key,
    movement_type,
    coalesce(source_entity_id, '00000000-0000-0000-0000-000000000000'::uuid)
  ) where idempotency_key is not null;

create table if not exists public.v1_dispatch_reference_counters (
  project_id uuid primary key references public.v1_projects (id) on delete restrict,
  next_dispatch_sequence integer not null default 1 check (next_dispatch_sequence > 0),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_material_dispatches (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  dispatch_number text not null unique check (btrim(dispatch_number) <> ''),
  dispatch_date date not null,
  driver_name text,
  vehicle_reference text,
  state text not null default 'receipt_pending' check (state in (
    'created', 'dispatched', 'receipt_pending', 'partially_received', 'received'
  )),
  record_version integer not null default 1 check (record_version > 0),
  dispatched_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  dispatched_by_role text not null check (dispatched_by_role in ('procurement', 'admin')),
  dispatched_at timestamptz not null default clock_timestamp(),
  receipt_reviewed_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create index if not exists v1_material_dispatches_request_created_idx
  on public.v1_material_dispatches (request_id, created_at desc);

create table if not exists public.v1_material_dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null references public.v1_material_dispatches (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_material_request_lines (id)
    on delete restrict,
  arrangement_line_id uuid not null
    references public.v1_procurement_arrangement_lines (id) on delete restrict,
  source_kind text not null check (source_kind in ('warehouse', 'external_supplier')),
  inventory_item_id uuid references public.v1_inventory_items (id) on delete restrict,
  external_supplier text,
  item_description text not null check (btrim(item_description) <> ''),
  brand_origin text,
  unit text not null check (btrim(unit) <> ''),
  approved_qty_snapshot numeric(18, 4) not null check (approved_qty_snapshot >= 0),
  dispatched_qty numeric(18, 4) not null check (dispatched_qty > 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (dispatch_id, request_line_id),
  check (
    (source_kind = 'warehouse' and inventory_item_id is not null
      and external_supplier is null)
    or (source_kind = 'external_supplier' and inventory_item_id is null
      and external_supplier is not null and btrim(external_supplier) <> '')
  )
);

create index if not exists v1_material_dispatch_lines_request_idx
  on public.v1_material_dispatch_lines (request_line_id, dispatch_id);
create index if not exists v1_material_dispatch_lines_inventory_idx
  on public.v1_material_dispatch_lines (inventory_item_id)
  where inventory_item_id is not null;

create table if not exists public.v1_receipt_reviews (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null unique references public.v1_material_dispatches (id)
    on delete restrict,
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  state text not null default 'confirmed' check (state = 'confirmed'),
  record_version integer not null default 1 check (record_version > 0),
  reviewed_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  reviewed_by_role text not null check (reviewed_by_role in (
    'project_engineer', 'site_engineer', 'admin'
  )),
  reviewed_at timestamptz not null default clock_timestamp(),
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_receipt_review_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_review_id uuid not null references public.v1_receipt_reviews (id)
    on delete restrict,
  dispatch_line_id uuid not null references public.v1_material_dispatch_lines (id)
    on delete restrict,
  outcome text not null check (outcome in ('received', 'missing', 'damaged')),
  dispatched_qty_snapshot numeric(18, 4) not null check (dispatched_qty_snapshot > 0),
  good_qty numeric(18, 4) not null check (good_qty >= 0),
  exception_qty numeric(18, 4) not null check (exception_qty >= 0),
  note text,
  created_at timestamptz not null default clock_timestamp(),
  unique (receipt_review_id, dispatch_line_id),
  check (good_qty + exception_qty = dispatched_qty_snapshot),
  check (
    (outcome = 'received' and good_qty = dispatched_qty_snapshot
      and exception_qty = 0 and note is null)
    or (outcome in ('missing', 'damaged') and good_qty < dispatched_qty_snapshot
      and exception_qty > 0 and note is not null and btrim(note) <> '')
  )
);

create index if not exists v1_receipt_review_lines_dispatch_line_idx
  on public.v1_receipt_review_lines (dispatch_line_id);

alter table public.v1_dispatch_reference_counters enable row level security;
alter table public.v1_material_dispatches enable row level security;
alter table public.v1_material_dispatch_lines enable row level security;
alter table public.v1_receipt_reviews enable row level security;
alter table public.v1_receipt_review_lines enable row level security;

revoke all on table public.v1_dispatch_reference_counters from public, anon, authenticated;
revoke all on table public.v1_material_dispatches from public, anon, authenticated;
revoke all on table public.v1_material_dispatch_lines from public, anon, authenticated;
revoke all on table public.v1_receipt_reviews from public, anon, authenticated;
revoke all on table public.v1_receipt_review_lines from public, anon, authenticated;
grant all on table public.v1_dispatch_reference_counters to service_role;
grant all on table public.v1_material_dispatches to service_role;
grant all on table public.v1_material_dispatch_lines to service_role;
grant all on table public.v1_receipt_reviews to service_role;
grant all on table public.v1_receipt_review_lines to service_role;

create or replace function public.v1_can_manage_inventory()
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

create or replace function public.v1_can_dispatch_material_request(
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
  return v_project_state = 'active';
end;
$$;

create or replace function public.v1_can_confirm_material_receipt(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_project_id uuid;
  v_project_state text;
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
  return v_role = 'admin' or (
    v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(v_project_id, auth.uid(), null)
  );
end;
$$;

-- Reservations now retain their original committed amount and separately track
-- consumption. This prevents inventory availability from counting stock that
-- has already left the warehouse while preserving the reservation history.
create or replace function public.v1_inventory_item_projection(
  p_inventory_item_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', item.id,
    'item_description', item.item_description,
    'brand_origin', item.brand_origin,
    'unit', item.unit,
    'is_active', item.is_active,
    'on_hand_qty', balance.on_hand_qty::text,
    'reserved_qty', coalesce((
      select sum(reservation.reserved_qty - reservation.consumed_qty)
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = item.id
        and reservation.state in ('active', 'partially_consumed')
    ), 0)::text,
    'available_qty', (
      balance.on_hand_qty - coalesce((
        select sum(reservation.reserved_qty - reservation.consumed_qty)
        from public.v1_inventory_reservations reservation
        where reservation.inventory_item_id = item.id
          and reservation.state in ('active', 'partially_consumed')
      ), 0)
    )::text,
    'record_version', balance.record_version
  )
  from public.v1_inventory_items item
  join public.v1_inventory_balances balance
    on balance.inventory_item_id = item.id
  where item.id = p_inventory_item_id;
$$;

create or replace function public.v1_inventory_workspace_projection(
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(lower(btrim(coalesce(p_search, ''))), '');
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_WORKSPACE_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(
        public.v1_inventory_item_projection(item.id)
        || jsonb_build_object(
          'movement_count', (
            select count(*) from public.v1_inventory_movements movement
            where movement.inventory_item_id = item.id
          ),
          'last_movement_at', (
            select max(movement.created_at) from public.v1_inventory_movements movement
            where movement.inventory_item_id = item.id
          )
        )
        order by lower(item.item_description), lower(coalesce(item.brand_origin, ''))
      )
      from public.v1_inventory_items item
      where v_search is null
        or lower(item.item_description) like '%' || v_search || '%'
        or lower(coalesce(item.brand_origin, '')) like '%' || v_search || '%'
        or lower(item.unit) like '%' || v_search || '%'
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_inventory_item_workspace_projection(
  p_inventory_item_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_WORKSPACE_DENIED' using errcode = '42501';
  end if;
  v_item := public.v1_inventory_item_projection(p_inventory_item_id);
  if v_item is null then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'item', v_item,
    'movements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', movement.id,
        'movement_type', movement.movement_type,
        'quantity_delta', movement.quantity_delta::text,
        'on_hand_after_qty', movement.on_hand_after_qty::text,
        'source_entity_type', movement.source_entity_type,
        'source_entity_id', movement.source_entity_id,
        'reason', movement.reason,
        'actor_display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'created_at', movement.created_at
      ) order by movement.created_at desc)
      from public.v1_inventory_movements movement
      join public.v1_profiles profile on profile.auth_user_id = movement.actor_auth_user_id
      where movement.inventory_item_id = p_inventory_item_id
    ), '[]'::jsonb)
  );
end;
$$;

-- A stock adjustment may not take the warehouse below the unconsumed
-- commitments of active requests. This redefines the Batch 6 command without
-- changing its payload or its historical movements.
create or replace function public.v1_adjust_inventory(
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
  v_role text := public.v1_current_role();
  v_item_id uuid;
  v_description text;
  v_brand_origin text;
  v_unit text;
  v_delta numeric(18, 4);
  v_reason text;
  v_balance public.v1_inventory_balances%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
  v_reserved_remaining numeric(18, 4);
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['inventory_item_id', 'item_description', 'brand_origin', 'unit',
      'quantity_delta', 'reason'],
    'adjust_inventory'
  );
  if v_actor is null or v_role not in ('procurement', 'admin')
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_INVENTORY_ADJUST_DENIED' using errcode = '42501';
  end if;
  v_item_id := nullif(btrim(coalesce(p_payload ->> 'inventory_item_id', '')), '')::uuid;
  v_description := nullif(btrim(coalesce(p_payload ->> 'item_description', '')), '');
  v_brand_origin := nullif(btrim(coalesce(p_payload ->> 'brand_origin', '')), '');
  v_unit := nullif(btrim(coalesce(p_payload ->> 'unit', '')), '');
  v_delta := nullif(p_payload ->> 'quantity_delta', '')::numeric(18, 4);
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_delta is null or v_delta = 0 or v_reason is null
    or (v_item_id is null and (v_description is null or v_unit is null))
    or (v_item_id is not null and (
      v_description is not null or v_brand_origin is not null or v_unit is not null
    )) then
    raise exception 'V1_INVENTORY_ADJUST_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_adjust_inventory', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_item_id is null then
    insert into public.v1_inventory_items (
      item_description, brand_origin, unit, created_by_auth_user_id
    ) values (v_description, v_brand_origin, v_unit, v_actor)
    returning id into v_item_id;
    insert into public.v1_inventory_balances (inventory_item_id)
    values (v_item_id);
  end if;
  select balance.* into v_balance
  from public.v1_inventory_balances balance
  join public.v1_inventory_items item on item.id = balance.inventory_item_id
  where balance.inventory_item_id = v_item_id and item.is_active
  for update of balance;
  if not found then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
    into v_reserved_remaining
  from public.v1_inventory_reservations reservation
  where reservation.inventory_item_id = v_item_id
    and reservation.state in ('active', 'partially_consumed');
  if v_balance.on_hand_qty + v_delta < v_reserved_remaining then
    raise exception 'V1_INVENTORY_ADJUSTMENT_BELOW_RESERVED' using errcode = '22023';
  end if;
  update public.v1_inventory_balances
     set on_hand_qty = on_hand_qty + v_delta,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where inventory_item_id = v_item_id;
  insert into public.v1_inventory_movements (
    inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
    reason, actor_auth_user_id, idempotency_key
  ) values (
    v_item_id, 'adjustment', v_delta, v_balance.on_hand_qty + v_delta,
    v_reason, v_actor, p_idempotency_key
  );
  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    'inventory_adjusted', 'inventory_item', v_item_id, null,
    null, jsonb_build_object('quantity_delta', v_delta::text), v_reason,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_adjust_inventory', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_set_inventory_item_active(
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
  v_item_id uuid;
  v_expected_version integer;
  v_is_active boolean;
  v_reason text;
  v_item public.v1_inventory_items%rowtype;
  v_balance public.v1_inventory_balances%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['inventory_item_id', 'expected_version', 'is_active', 'reason'],
    'set_inventory_item_active'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_MANAGE_DENIED' using errcode = '42501';
  end if;
  v_item_id := nullif(btrim(coalesce(p_payload ->> 'inventory_item_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_is_active := case
    when p_payload ? 'is_active' and jsonb_typeof(p_payload -> 'is_active') = 'boolean'
      then (p_payload ->> 'is_active')::boolean
    else null
  end;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_item_id is null or v_expected_version is null or v_expected_version < 1
    or v_is_active is null or v_reason is null then
    raise exception 'V1_INVENTORY_ITEM_STATE_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_item from public.v1_inventory_items where id = v_item_id for update;
  select * into v_balance from public.v1_inventory_balances
  where inventory_item_id = v_item_id for update;
  if not found then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_set_inventory_item_active', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_balance.record_version <> v_expected_version then
    raise exception 'V1_INVENTORY_ITEM_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if not v_is_active and exists (
    select 1 from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.state in ('active', 'partially_consumed')
  ) then
    raise exception 'V1_INVENTORY_ITEM_RESERVED' using errcode = '22023';
  end if;
  update public.v1_inventory_items
     set is_active = v_is_active, updated_at = clock_timestamp()
   where id = v_item_id;
  update public.v1_inventory_balances
     set record_version = record_version + 1, updated_at = clock_timestamp()
   where inventory_item_id = v_item_id;
  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    case when v_is_active then 'inventory_item_reactivated'
      else 'inventory_item_archived' end,
    'inventory_item', v_item_id, null,
    jsonb_build_object('is_active', v_item.is_active),
    jsonb_build_object('is_active', v_is_active), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_set_inventory_item_active', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Called only while the Material Request row is locked by a trusted command.
-- It derives, rather than accepts, the aggregate request state and next owner
-- from immutable approvals, dispatch snapshots and receipt-review facts.
create or replace function public.v1_refresh_material_request_logistics_state(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approved_qty numeric(18, 4);
  v_good_qty numeric(18, 4);
  v_in_transit_qty numeric(18, 4);
  v_has_review boolean;
  v_state text;
  v_owner text;
  v_action text;
begin
  select coalesce(sum(approval.approved_qty), 0) into v_approved_qty
  from public.v1_material_request_line_approvals approval
  join public.v1_material_request_lines request_line
    on request_line.id = approval.request_line_id
  where request_line.request_id = p_request_id;
  select coalesce(sum(review_line.good_qty), 0) > 0,
      coalesce(sum(review_line.good_qty), 0)
    into v_has_review, v_good_qty
  from public.v1_receipt_review_lines review_line
  join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
  where review.request_id = p_request_id and review.state = 'confirmed';
  v_has_review := coalesce(v_has_review, false) or exists (
    select 1 from public.v1_receipt_reviews review
    where review.request_id = p_request_id and review.state = 'confirmed'
  );
  select coalesce(sum(dispatch_line.dispatched_qty), 0) into v_in_transit_qty
  from public.v1_material_dispatch_lines dispatch_line
  join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
  where dispatch.request_id = p_request_id and dispatch.state = 'receipt_pending';
  if v_good_qty >= v_approved_qty and v_in_transit_qty = 0 then
    v_state := 'received';
    v_owner := 'project_engineer';
    v_action := 'material_request_close_review';
  elsif v_has_review then
    v_state := 'partially_received';
    if v_in_transit_qty > 0 then
      v_owner := 'site_engineer';
      v_action := 'receipt_review_required';
    else
      v_owner := 'procurement';
      v_action := 'replacement_dispatch_required';
    end if;
  elsif v_in_transit_qty >= v_approved_qty then
    v_state := 'dispatched';
    v_owner := 'site_engineer';
    v_action := 'receipt_review_required';
  else
    v_state := 'partially_dispatched';
    v_owner := 'site_engineer';
    v_action := 'receipt_review_required';
  end if;
  update public.v1_material_requests
     set state = v_state,
         current_action_owner_role = v_owner,
         current_action_code = v_action,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = p_request_id;
  return jsonb_build_object(
    'state', v_state,
    'current_action_owner_role', v_owner,
    'current_action_code', v_action,
    'approved_qty', v_approved_qty::text,
    'good_received_qty', v_good_qty::text,
    'in_transit_qty', v_in_transit_qty::text
  );
end;
$$;

create or replace function public.v1_logistics_workspace_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_can_dispatch boolean := public.v1_can_dispatch_material_request(p_request_id);
  v_can_confirm boolean := public.v1_can_confirm_material_receipt(p_request_id);
  v_result jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_LOGISTICS_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'request_id', request_record.id,
    'request_number', request_record.request_number,
    'request_state', request_record.state,
    'request_record_version', request_record.record_version,
    'project_name', project.name,
    'scope_name', scope.name,
    'can_dispatch', v_can_dispatch and request_record.state in (
      'approved', 'partially_dispatched', 'partially_received'
    ),
    'can_confirm_receipt', v_can_confirm,
    'dispatch_candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_line_id', request_line.id,
        'display_order', request_line.display_order,
        'item_description', request_line.item_description,
        'brand_origin', request_line.brand_origin,
        'unit', request_line.unit,
        'approved_qty', approval.approved_qty::text,
        'good_received_qty', coalesce((
          select sum(review_line.good_qty)
          from public.v1_receipt_review_lines review_line
          join public.v1_receipt_reviews review
            on review.id = review_line.receipt_review_id
          join public.v1_material_dispatch_lines dispatch_line
            on dispatch_line.id = review_line.dispatch_line_id
          where review.state = 'confirmed'
            and dispatch_line.request_line_id = request_line.id
        ), 0)::text,
        'in_transit_qty', coalesce((
          select sum(dispatch_line.dispatched_qty)
          from public.v1_material_dispatch_lines dispatch_line
          join public.v1_material_dispatches dispatch
            on dispatch.id = dispatch_line.dispatch_id
          where dispatch.state = 'receipt_pending'
            and dispatch_line.request_line_id = request_line.id
        ), 0)::text,
        'still_needed_qty', greatest(0, approval.approved_qty
          - coalesce((
            select sum(review_line.good_qty)
            from public.v1_receipt_review_lines review_line
            join public.v1_receipt_reviews review
              on review.id = review_line.receipt_review_id
            join public.v1_material_dispatch_lines dispatch_line
              on dispatch_line.id = review_line.dispatch_line_id
            where review.state = 'confirmed'
              and dispatch_line.request_line_id = request_line.id
          ), 0)
          - coalesce((
            select sum(dispatch_line.dispatched_qty)
            from public.v1_material_dispatch_lines dispatch_line
            join public.v1_material_dispatches dispatch
              on dispatch.id = dispatch_line.dispatch_id
            where dispatch.state = 'receipt_pending'
              and dispatch_line.request_line_id = request_line.id
          ), 0))::text,
        'source_kind', arrangement_line.source_kind,
        'external_supplier', arrangement_line.external_supplier,
        'inventory_item_id', case when v_can_dispatch then arrangement_line.inventory_item_id
          else null end,
        'reserved_remaining_qty', case when v_can_dispatch then coalesce(
          reservation.reserved_qty - reservation.consumed_qty, 0
        )::text else null end,
        'warehouse_available_qty', case when v_can_dispatch then (
          balance.on_hand_qty - coalesce((
            select sum(other_reservation.reserved_qty - other_reservation.consumed_qty)
            from public.v1_inventory_reservations other_reservation
            where other_reservation.inventory_item_id = arrangement_line.inventory_item_id
              and other_reservation.request_id <> request_record.id
              and other_reservation.state in ('active', 'partially_consumed')
          ), 0)
        )::text else null end
      ) order by request_line.display_order)
      from public.v1_material_request_line_approvals approval
      join public.v1_material_request_lines request_line
        on request_line.id = approval.request_line_id
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.id = approval.arrangement_line_id
      left join public.v1_inventory_reservations reservation
        on reservation.arrangement_line_id = arrangement_line.id
      left join public.v1_inventory_balances balance
        on balance.inventory_item_id = arrangement_line.inventory_item_id
      where request_line.request_id = request_record.id
    ), '[]'::jsonb),
    'dispatches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dispatch.id,
        'dispatch_number', dispatch.dispatch_number,
        'dispatch_date', dispatch.dispatch_date,
        'driver_name', dispatch.driver_name,
        'vehicle_reference', dispatch.vehicle_reference,
        'state', dispatch.state,
        'record_version', dispatch.record_version,
        'dispatched_by_display_name', public.v1_safe_profile_display_name(
          dispatcher.display_name, dispatcher.auth_user_id
        ),
        'dispatched_at', dispatch.dispatched_at,
        'can_confirm_receipt', v_can_confirm and dispatch.state = 'receipt_pending',
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', dispatch_line.id,
            'request_line_id', dispatch_line.request_line_id,
            'item_description', dispatch_line.item_description,
            'brand_origin', dispatch_line.brand_origin,
            'unit', dispatch_line.unit,
            'source_kind', dispatch_line.source_kind,
            'external_supplier', dispatch_line.external_supplier,
            'dispatched_qty', dispatch_line.dispatched_qty::text,
            'approved_qty_snapshot', dispatch_line.approved_qty_snapshot::text,
            'receipt_outcome', review_line.outcome,
            'good_qty', case when review_line.good_qty is null then null
              else review_line.good_qty::text end,
            'exception_qty', case when review_line.exception_qty is null then null
              else review_line.exception_qty::text end,
            'receipt_note', review_line.note
          ) order by dispatch_line.created_at)
          from public.v1_material_dispatch_lines dispatch_line
          left join public.v1_receipt_reviews review
            on review.dispatch_id = dispatch.id and review.state = 'confirmed'
          left join public.v1_receipt_review_lines review_line
            on review_line.receipt_review_id = review.id
              and review_line.dispatch_line_id = dispatch_line.id
          where dispatch_line.dispatch_id = dispatch.id
        ), '[]'::jsonb),
        'receipt_review', (
          select jsonb_build_object(
            'id', review.id,
            'reviewed_at', review.reviewed_at,
            'reviewed_by_display_name', public.v1_safe_profile_display_name(
              reviewer.display_name, reviewer.auth_user_id
            )
          )
          from public.v1_receipt_reviews review
          join public.v1_profiles reviewer
            on reviewer.auth_user_id = review.reviewed_by_auth_user_id
          where review.dispatch_id = dispatch.id and review.state = 'confirmed'
        )
      ) order by dispatch.dispatched_at desc)
      from public.v1_material_dispatches dispatch
      join public.v1_profiles dispatcher
        on dispatcher.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

create or replace function public.v1_dispatch_materials(
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
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_expected_version integer;
  v_dispatch_date date;
  v_driver_name text;
  v_vehicle_reference text;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_state_summary jsonb;
  v_dispatch_id uuid;
  v_dispatch_number text;
  v_sequence integer;
  v_line jsonb;
  v_request_line_id uuid;
  v_dispatch_qty numeric(18, 4);
  v_line_count integer;
  v_item_id uuid;
  v_approved_qty numeric(18, 4);
  v_good_qty numeric(18, 4);
  v_in_transit_qty numeric(18, 4);
  v_source_kind text;
  v_arrangement_line_id uuid;
  v_external_supplier text;
  v_item_description text;
  v_brand_origin text;
  v_unit text;
  v_on_hand_qty numeric(18, 4);
  v_other_reserved_qty numeric(18, 4);
  v_reservation public.v1_inventory_reservations%rowtype;
  v_reservation_remaining numeric(18, 4);
  v_consume_qty numeric(18, 4);
  v_dispatch_line_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'expected_version', 'dispatch_date', 'driver_name',
      'vehicle_reference', 'lines'],
    'dispatch_materials'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_dispatch_date := nullif(p_payload ->> 'dispatch_date', '')::date;
  v_driver_name := nullif(btrim(coalesce(p_payload ->> 'driver_name', '')), '');
  v_vehicle_reference := nullif(btrim(coalesce(p_payload ->> 'vehicle_reference', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_dispatch_date is null or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_DISPATCH_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_dispatch_material_request(v_request_id) then
    raise exception 'V1_DISPATCH_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_dispatch_materials', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state not in ('approved', 'partially_dispatched', 'partially_received')
    or v_request.record_version <> v_expected_version then
    raise exception 'V1_DISPATCH_STATE_OR_VERSION_INVALID' using errcode = '40001';
  end if;
  select count(*) into v_line_count from jsonb_array_elements(v_lines);
  if v_line_count = 0 or (
    select count(distinct nullif(btrim(coalesce(value ->> 'request_line_id', '')), '')::uuid)
    from jsonb_array_elements(v_lines)
  ) <> v_line_count then
    raise exception 'V1_DISPATCH_LINES_INVALID' using errcode = '22023';
  end if;

  -- All item locks use a deterministic ordering so competing dispatches on
  -- different requests cannot over-supply or deadlock each other.
  for v_item_id in
    select distinct arrangement_line.inventory_item_id
    from jsonb_array_elements(v_lines) line_json
    join public.v1_material_request_line_approvals approval
      on approval.request_line_id = nullif(
        btrim(coalesce(line_json.value ->> 'request_line_id', '')), ''
      )::uuid
    join public.v1_procurement_arrangement_lines arrangement_line
      on arrangement_line.id = approval.arrangement_line_id
    where arrangement_line.source_kind = 'warehouse'
    order by arrangement_line.inventory_item_id
  loop
    perform 1 from public.v1_inventory_balances balance
    join public.v1_inventory_items item on item.id = balance.inventory_item_id
    where balance.inventory_item_id = v_item_id and item.is_active
    for update of balance;
    if not found then
      raise exception 'V1_DISPATCH_INVENTORY_ITEM_INVALID' using errcode = '22023';
    end if;
    perform 1 from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.request_id = v_request.id
    order by reservation.id for update;
  end loop;

  -- Validate the complete payload before generating a document number or
  -- moving any stock.
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line, array['request_line_id', 'dispatch_qty'], 'dispatch_line'
    );
    v_request_line_id := nullif(btrim(coalesce(
      v_line ->> 'request_line_id', ''
    )), '')::uuid;
    v_dispatch_qty := nullif(v_line ->> 'dispatch_qty', '')::numeric(18, 4);
    if v_request_line_id is null or v_dispatch_qty is null or v_dispatch_qty <= 0 then
      raise exception 'V1_DISPATCH_LINE_INVALID' using errcode = '22023';
    end if;
    select approval.approved_qty, arrangement_line.source_kind,
        arrangement_line.id, arrangement_line.inventory_item_id,
        arrangement_line.external_supplier, request_line.item_description,
        request_line.brand_origin, request_line.unit
      into v_approved_qty, v_source_kind, v_arrangement_line_id, v_item_id,
        v_external_supplier, v_item_description, v_brand_origin, v_unit
    from public.v1_material_request_line_approvals approval
    join public.v1_procurement_arrangement_lines arrangement_line
      on arrangement_line.id = approval.arrangement_line_id
    join public.v1_material_request_lines request_line
      on request_line.id = approval.request_line_id
    where approval.request_line_id = v_request_line_id
      and request_line.request_id = v_request.id;
    if not found or v_approved_qty <= 0 then
      raise exception 'V1_DISPATCH_LINE_NOT_APPROVED' using errcode = '22023';
    end if;
    select coalesce(sum(review_line.good_qty), 0) into v_good_qty
    from public.v1_receipt_review_lines review_line
    join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
    join public.v1_material_dispatch_lines prior_dispatch_line
      on prior_dispatch_line.id = review_line.dispatch_line_id
    where review.state = 'confirmed'
      and prior_dispatch_line.request_line_id = v_request_line_id;
    select coalesce(sum(prior_dispatch_line.dispatched_qty), 0) into v_in_transit_qty
    from public.v1_material_dispatch_lines prior_dispatch_line
    join public.v1_material_dispatches prior_dispatch
      on prior_dispatch.id = prior_dispatch_line.dispatch_id
    where prior_dispatch.state = 'receipt_pending'
      and prior_dispatch_line.request_line_id = v_request_line_id;
    if v_dispatch_qty > v_approved_qty - v_good_qty - v_in_transit_qty then
      raise exception 'V1_DISPATCH_APPROVED_CAP_EXCEEDED' using errcode = '22023';
    end if;
    if v_source_kind = 'warehouse' then
      select balance.on_hand_qty into v_on_hand_qty
      from public.v1_inventory_balances balance
      where balance.inventory_item_id = v_item_id;
      select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
        into v_other_reserved_qty
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = v_item_id
        and reservation.request_id <> v_request.id
        and reservation.state in ('active', 'partially_consumed');
      if v_on_hand_qty - v_other_reserved_qty < v_dispatch_qty then
        raise exception 'V1_DISPATCH_STOCK_CAP_EXCEEDED' using errcode = '22023';
      end if;
    end if;
  end loop;

  v_before := public.v1_logistics_workspace_projection(v_request.id);
  insert into public.v1_dispatch_reference_counters (
    project_id, next_dispatch_sequence, updated_at
  ) values (v_request.project_id, 2, clock_timestamp())
  on conflict (project_id) do update set
    next_dispatch_sequence = public.v1_dispatch_reference_counters.next_dispatch_sequence + 1,
    updated_at = clock_timestamp()
  returning next_dispatch_sequence - 1 into v_sequence;
  select project_ref || '-DSP' || lpad(v_sequence::text, 3, '0')
    into v_dispatch_number
  from public.v1_projects where id = v_request.project_id;
  insert into public.v1_material_dispatches (
    request_id, project_id, dispatch_number, dispatch_date, driver_name,
    vehicle_reference, state, dispatched_by_auth_user_id, dispatched_by_role
  ) values (
    v_request.id, v_request.project_id, v_dispatch_number, v_dispatch_date,
    v_driver_name, v_vehicle_reference, 'receipt_pending', v_actor, v_role
  ) returning id into v_dispatch_id;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_request_line_id := (v_line ->> 'request_line_id')::uuid;
    v_dispatch_qty := (v_line ->> 'dispatch_qty')::numeric(18, 4);
    select approval.approved_qty, arrangement_line.source_kind,
        arrangement_line.id, arrangement_line.inventory_item_id,
        arrangement_line.external_supplier, request_line.item_description,
        request_line.brand_origin, request_line.unit
      into v_approved_qty, v_source_kind, v_arrangement_line_id, v_item_id,
        v_external_supplier, v_item_description, v_brand_origin, v_unit
    from public.v1_material_request_line_approvals approval
    join public.v1_procurement_arrangement_lines arrangement_line
      on arrangement_line.id = approval.arrangement_line_id
    join public.v1_material_request_lines request_line
      on request_line.id = approval.request_line_id
    where approval.request_line_id = v_request_line_id;
    insert into public.v1_material_dispatch_lines (
      dispatch_id, request_line_id, arrangement_line_id, source_kind,
      inventory_item_id, external_supplier, item_description, brand_origin,
      unit, approved_qty_snapshot, dispatched_qty
    ) values (
      v_dispatch_id, v_request_line_id, v_arrangement_line_id, v_source_kind,
      v_item_id, v_external_supplier, v_item_description, v_brand_origin,
      v_unit, v_approved_qty, v_dispatch_qty
    ) returning id into v_dispatch_line_id;
    if v_source_kind = 'warehouse' then
      select * into v_reservation from public.v1_inventory_reservations reservation
      where reservation.arrangement_line_id = v_arrangement_line_id
      for update;
      if not found then
        raise exception 'V1_DISPATCH_RESERVATION_NOT_FOUND' using errcode = '22023';
      end if;
      v_reservation_remaining := v_reservation.reserved_qty - v_reservation.consumed_qty;
      v_consume_qty := least(v_dispatch_qty, greatest(v_reservation_remaining, 0));
      if v_consume_qty > 0 then
        update public.v1_inventory_reservations
           set consumed_qty = consumed_qty + v_consume_qty,
               state = case
                 when consumed_qty + v_consume_qty >= reserved_qty then 'consumed'
                 else 'partially_consumed'
               end,
               updated_at = clock_timestamp()
         where id = v_reservation.id;
      end if;
      select on_hand_qty into v_on_hand_qty from public.v1_inventory_balances
      where inventory_item_id = v_item_id;
      update public.v1_inventory_balances
         set on_hand_qty = on_hand_qty - v_dispatch_qty,
             record_version = record_version + 1,
             updated_at = clock_timestamp()
       where inventory_item_id = v_item_id;
      insert into public.v1_inventory_movements (
        inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
        source_entity_type, source_entity_id, reason, actor_auth_user_id,
        idempotency_key
      ) values (
        v_item_id, 'dispatch', -v_dispatch_qty, v_on_hand_qty - v_dispatch_qty,
        'material_dispatch_line', v_dispatch_line_id,
        'Dispatch ' || v_dispatch_number, v_actor, p_idempotency_key
      );
    end if;
  end loop;
  v_state_summary := public.v1_refresh_material_request_logistics_state(v_request.id);
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct member.member_auth_user_id, 'receipt_review_required',
    'material_dispatch', v_dispatch_id, v_request.project_id
  from public.v1_project_members member
  join public.v1_profiles profile on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = v_request.project_id
    and member.project_role in ('project_engineer', 'site_engineer')
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
    and profile.is_active;
  v_response := public.v1_logistics_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'materials_dispatched', 'material_dispatch', v_dispatch_id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'dispatch_number', v_dispatch_number,
      'line_count', v_line_count,
      'request_state', v_state_summary ->> 'state',
      'request_record_version', v_expected_version + 1
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_dispatch_materials', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_confirm_receipt(
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
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_dispatch_id uuid;
  v_expected_request_version integer;
  v_expected_dispatch_version integer;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_dispatch public.v1_material_dispatches%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_state_summary jsonb;
  v_line jsonb;
  v_dispatch_line_id uuid;
  v_outcome text;
  v_good_qty numeric(18, 4);
  v_note text;
  v_dispatched_qty numeric(18, 4);
  v_line_count integer;
  v_review_id uuid;
  v_good_total numeric(18, 4) := 0;
  v_dispatched_total numeric(18, 4) := 0;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'dispatch_id', 'expected_request_version',
      'expected_dispatch_version', 'lines'],
    'confirm_receipt'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_dispatch_id := nullif(btrim(coalesce(p_payload ->> 'dispatch_id', '')), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_expected_dispatch_version := nullif(
    p_payload ->> 'expected_dispatch_version', ''
  )::integer;
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_dispatch_id is null
    or v_expected_request_version is null or v_expected_dispatch_version is null
    or v_expected_request_version < 1 or v_expected_dispatch_version < 1
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_RECEIPT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_confirm_material_receipt(v_request_id) then
    raise exception 'V1_RECEIPT_CONFIRM_DENIED' using errcode = '42501';
  end if;
  select * into v_dispatch from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id and dispatch.request_id = v_request.id
  for update;
  if not found then
    raise exception 'V1_RECEIPT_DISPATCH_NOT_FOUND' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_confirm_receipt', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version
    or v_dispatch.state <> 'receipt_pending'
    or v_request.state not in ('partially_dispatched', 'dispatched', 'partially_received') then
    raise exception 'V1_RECEIPT_STATE_OR_VERSION_INVALID' using errcode = '40001';
  end if;
  select count(*) into v_line_count from public.v1_material_dispatch_lines
  where dispatch_id = v_dispatch.id;
  if jsonb_array_length(v_lines) <> v_line_count or v_line_count = 0
    or (select count(distinct nullif(btrim(coalesce(
      value ->> 'dispatch_line_id', ''
    )), '')::uuid) from jsonb_array_elements(v_lines)) <> v_line_count then
    raise exception 'V1_RECEIPT_LINES_INCOMPLETE' using errcode = '22023';
  end if;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line, array['dispatch_line_id', 'outcome', 'good_qty', 'note'],
      'receipt_line'
    );
    v_dispatch_line_id := nullif(btrim(coalesce(
      v_line ->> 'dispatch_line_id', ''
    )), '')::uuid;
    v_outcome := coalesce(v_line ->> 'outcome', '');
    v_good_qty := nullif(v_line ->> 'good_qty', '')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines
    where id = v_dispatch_line_id and dispatch_id = v_dispatch.id;
    if v_dispatched_qty is null or v_good_qty is null or v_good_qty < 0
      or v_outcome not in ('received', 'missing', 'damaged')
      or (v_outcome = 'received' and (
        v_good_qty <> v_dispatched_qty or v_note is not null
      ))
      or (v_outcome in ('missing', 'damaged') and (
        v_good_qty >= v_dispatched_qty or v_note is null
      )) then
      raise exception 'V1_RECEIPT_LINE_INVALID' using errcode = '22023';
    end if;
    v_good_total := v_good_total + v_good_qty;
    v_dispatched_total := v_dispatched_total + v_dispatched_qty;
  end loop;
  v_before := public.v1_logistics_workspace_projection(v_request.id);
  insert into public.v1_receipt_reviews (
    dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
  ) values (v_dispatch.id, v_request.id, v_actor, v_role)
  returning id into v_review_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_dispatch_line_id := (v_line ->> 'dispatch_line_id')::uuid;
    v_outcome := v_line ->> 'outcome';
    v_good_qty := (v_line ->> 'good_qty')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines where id = v_dispatch_line_id;
    insert into public.v1_receipt_review_lines (
      receipt_review_id, dispatch_line_id, outcome, dispatched_qty_snapshot,
      good_qty, exception_qty, note
    ) values (
      v_review_id, v_dispatch_line_id, v_outcome, v_dispatched_qty,
      v_good_qty, v_dispatched_qty - v_good_qty, v_note
    );
  end loop;
  update public.v1_material_dispatches
     set state = case when v_good_total = v_dispatched_total then 'received'
       else 'partially_received' end,
         receipt_reviewed_at = clock_timestamp(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_dispatch.id;
  v_state_summary := public.v1_refresh_material_request_logistics_state(v_request.id);
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id, 'receipt_review_confirmed', 'receipt_review',
    v_review_id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  v_response := public.v1_logistics_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'receipt_review_confirmed', 'receipt_review', v_review_id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'dispatch_id', v_dispatch.id,
      'dispatch_number', v_dispatch.dispatch_number,
      'good_qty', v_good_total::text,
      'exception_qty', (v_dispatched_total - v_good_total)::text,
      'request_state', v_state_summary ->> 'state',
      'request_record_version', v_expected_request_version + 1
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_receipt', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_manage_inventory()
  from public, anon, authenticated;
revoke all on function public.v1_can_dispatch_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_confirm_material_receipt(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_workspace_projection(text)
  from public, anon;
revoke all on function public.v1_inventory_item_workspace_projection(uuid)
  from public, anon;
revoke all on function public.v1_set_inventory_item_active(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_logistics_workspace_projection(uuid)
  from public, anon;
revoke all on function public.v1_dispatch_materials(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_confirm_receipt(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_refresh_material_request_logistics_state(uuid)
  from public, anon, authenticated;

grant execute on function public.v1_inventory_workspace_projection(text)
  to authenticated;
grant execute on function public.v1_inventory_item_workspace_projection(uuid)
  to authenticated;
grant execute on function public.v1_set_inventory_item_active(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_logistics_workspace_projection(uuid)
  to authenticated;
grant execute on function public.v1_dispatch_materials(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_confirm_receipt(jsonb, uuid)
  to authenticated;
