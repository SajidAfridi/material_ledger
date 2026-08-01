-- Yorks V1 Batch 6: the minimum single-warehouse kernel plus the only
-- authoritative route from a submitted Material Request to an approved
-- arrangement. This migration is additive. Turning the arrangement rollout
-- flag off removes its routes; it never rewrites legacy inventory data.

create table if not exists public.v1_inventory_items (
  id uuid primary key default gen_random_uuid(),
  item_description text not null check (btrim(item_description) <> ''),
  brand_origin text,
  unit text not null check (btrim(unit) <> ''),
  is_active boolean not null default true,
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists v1_inventory_items_identity_unique_idx
  on public.v1_inventory_items (
    lower(btrim(item_description)),
    lower(coalesce(btrim(brand_origin), '')),
    lower(btrim(unit))
  );

create table if not exists public.v1_inventory_balances (
  inventory_item_id uuid primary key references public.v1_inventory_items (id)
    on delete restrict,
  on_hand_qty numeric(18, 4) not null default 0 check (on_hand_qty >= 0),
  record_version integer not null default 1 check (record_version > 0),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_inventory_movements (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.v1_inventory_items (id)
    on delete restrict,
  movement_type text not null check (movement_type in (
    'opening_balance', 'adjustment', 'dispatch', 'return', 'correction'
  )),
  quantity_delta numeric(18, 4) not null check (quantity_delta <> 0),
  on_hand_after_qty numeric(18, 4) not null check (on_hand_after_qty >= 0),
  source_entity_type text,
  source_entity_id uuid,
  reason text not null check (btrim(reason) <> ''),
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  idempotency_key uuid,
  created_at timestamptz not null default clock_timestamp(),
  unique (actor_auth_user_id, idempotency_key, movement_type)
);

create index if not exists v1_inventory_movements_item_created_idx
  on public.v1_inventory_movements (inventory_item_id, created_at desc);

create table if not exists public.v1_procurement_arrangements (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  arrangement_version integer not null check (arrangement_version > 0),
  status text not null check (status in (
    'working', 'awaiting_approval', 'approved', 'returned', 'superseded',
    'cancelled'
  )),
  is_current boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  started_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  started_at timestamptz not null default clock_timestamp(),
  saved_at timestamptz,
  saved_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  superseded_at timestamptz,
  superseded_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (request_id, arrangement_version),
  check (
    (status = 'working' and saved_at is null and saved_by_auth_user_id is null)
    or (status <> 'working' and saved_at is not null and saved_by_auth_user_id is not null)
  )
);

create unique index if not exists v1_procurement_arrangements_one_working_idx
  on public.v1_procurement_arrangements (request_id) where status = 'working';
create unique index if not exists v1_procurement_arrangements_one_current_idx
  on public.v1_procurement_arrangements (request_id) where is_current;
create index if not exists v1_procurement_arrangements_request_version_idx
  on public.v1_procurement_arrangements (request_id, arrangement_version desc);

create table if not exists public.v1_procurement_arrangement_lines (
  id uuid primary key default gen_random_uuid(),
  arrangement_id uuid not null references public.v1_procurement_arrangements (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_material_request_lines (id)
    on delete restrict,
  source_kind text not null default 'warehouse'
    check (source_kind in ('warehouse', 'external_supplier')),
  external_supplier text,
  decision text check (decision in ('full', 'partial', 'unavailable')),
  arranged_qty numeric(18, 4),
  reason text,
  inventory_item_id uuid references public.v1_inventory_items (id)
    on delete restrict,
  warehouse_available_at_save numeric(18, 4),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (arrangement_id, request_line_id)
);

create index if not exists v1_procurement_arrangement_lines_arrangement_idx
  on public.v1_procurement_arrangement_lines (arrangement_id, request_line_id);

create table if not exists public.v1_inventory_reservations (
  id uuid primary key default gen_random_uuid(),
  inventory_item_id uuid not null references public.v1_inventory_items (id)
    on delete restrict,
  arrangement_line_id uuid not null
    references public.v1_procurement_arrangement_lines (id) on delete restrict,
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  reserved_qty numeric(18, 4) not null check (reserved_qty > 0),
  state text not null default 'active' check (state in (
    'active', 'partially_consumed', 'consumed', 'released'
  )),
  released_at timestamptz,
  released_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  release_reason text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (arrangement_line_id),
  check (
    (state = 'released' and released_at is not null
      and released_by_auth_user_id is not null
      and release_reason is not null and btrim(release_reason) <> '')
    or (state <> 'released' and released_at is null
      and released_by_auth_user_id is null and release_reason is null)
  )
);

create index if not exists v1_inventory_reservations_item_state_idx
  on public.v1_inventory_reservations (inventory_item_id, state);
create index if not exists v1_inventory_reservations_request_state_idx
  on public.v1_inventory_reservations (request_id, state);

create table if not exists public.v1_arrangement_decisions (
  id uuid primary key default gen_random_uuid(),
  arrangement_id uuid not null references public.v1_procurement_arrangements (id)
    on delete restrict,
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  decision text not null check (decision in ('approved', 'returned')),
  reason text,
  decided_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  decided_by_role text not null check (decided_by_role in (
    'project_engineer', 'site_engineer', 'admin'
  )),
  created_at timestamptz not null default clock_timestamp(),
  check (
    (decision = 'returned' and reason is not null and btrim(reason) <> '')
    or decision = 'approved'
  )
);

create index if not exists v1_arrangement_decisions_arrangement_idx
  on public.v1_arrangement_decisions (arrangement_id, created_at desc);

create table if not exists public.v1_material_request_line_approvals (
  request_line_id uuid primary key references public.v1_material_request_lines (id)
    on delete restrict,
  arrangement_line_id uuid not null
    references public.v1_procurement_arrangement_lines (id) on delete restrict,
  arrangement_id uuid not null references public.v1_procurement_arrangements (id)
    on delete restrict,
  approved_qty numeric(18, 4) not null check (approved_qty >= 0),
  approved_at timestamptz not null default clock_timestamp(),
  approved_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict
);

alter table public.v1_inventory_items enable row level security;
alter table public.v1_inventory_balances enable row level security;
alter table public.v1_inventory_movements enable row level security;
alter table public.v1_procurement_arrangements enable row level security;
alter table public.v1_procurement_arrangement_lines enable row level security;
alter table public.v1_inventory_reservations enable row level security;
alter table public.v1_arrangement_decisions enable row level security;
alter table public.v1_material_request_line_approvals enable row level security;

revoke all on table public.v1_inventory_items from public, anon, authenticated;
revoke all on table public.v1_inventory_balances from public, anon, authenticated;
revoke all on table public.v1_inventory_movements from public, anon, authenticated;
revoke all on table public.v1_procurement_arrangements from public, anon, authenticated;
revoke all on table public.v1_procurement_arrangement_lines from public, anon, authenticated;
revoke all on table public.v1_inventory_reservations from public, anon, authenticated;
revoke all on table public.v1_arrangement_decisions from public, anon, authenticated;
revoke all on table public.v1_material_request_line_approvals from public, anon, authenticated;
grant all on table public.v1_inventory_items to service_role;
grant all on table public.v1_inventory_balances to service_role;
grant all on table public.v1_inventory_movements to service_role;
grant all on table public.v1_procurement_arrangements to service_role;
grant all on table public.v1_procurement_arrangement_lines to service_role;
grant all on table public.v1_inventory_reservations to service_role;
grant all on table public.v1_arrangement_decisions to service_role;
grant all on table public.v1_material_request_line_approvals to service_role;

create or replace function public.v1_can_arrange_material_request(
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
  v_project_state text;
begin
  if auth.uid() is null or v_role not in ('procurement', 'admin')
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select project.state into v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_state in ('active', 'on_hold');
end;
$$;

create or replace function public.v1_can_decide_arrangement(
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
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or v_role = '' or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_role = 'admin' then return true; end if;
  select project_id into v_project_id from public.v1_material_requests
  where id = p_request_id;
  return v_project_id is not null
    and v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
end;
$$;

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
    'on_hand_qty', balance.on_hand_qty::text,
    'reserved_qty', coalesce((
      select sum(reservation.reserved_qty)
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = item.id
        and reservation.state in ('active', 'partially_consumed')
    ), 0)::text,
    'available_qty', (
      balance.on_hand_qty - coalesce((
        select sum(reservation.reserved_qty)
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

create or replace function public.v1_list_arrangement_inventory_items()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or v_role not in ('procurement', 'admin')
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_INVENTORY_LIST_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.v1_inventory_item_projection(item.id)
      order by lower(item.item_description), lower(coalesce(item.brand_origin, '')))
    from public.v1_inventory_items item
    where item.is_active
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_arrangement_projection(
  p_request_id uuid
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
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_ARRANGEMENT_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'request_id', request_record.id,
    'request_number', request_record.request_number,
    'request_state', request_record.state,
    'request_record_version', request_record.record_version,
    'can_begin', request_record.state in ('submitted', 'arranging')
      and public.v1_can_arrange_material_request(request_record.id),
    'can_save', request_record.state = 'arranging'
      and public.v1_can_arrange_material_request(request_record.id),
    'can_decide', request_record.state = 'awaiting_approval'
      and public.v1_can_decide_arrangement(request_record.id),
    'arrangements', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', arrangement.id,
        'arrangement_version', arrangement.arrangement_version,
        'status', arrangement.status,
        'is_current', arrangement.is_current,
        'record_version', arrangement.record_version,
        'started_by_display_name', public.v1_safe_profile_display_name(
          starter.display_name, starter.auth_user_id
        ),
        'started_at', arrangement.started_at,
        'saved_at', arrangement.saved_at,
        'saved_by_display_name', case when saver.auth_user_id is null then null
          else public.v1_safe_profile_display_name(saver.display_name, saver.auth_user_id)
        end,
        'decision', (
          select decision_record.decision
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'decision_reason', (
          select decision_record.reason
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', arrangement_line.id,
            'request_line_id', request_line.id,
            'display_order', request_line.display_order,
            'item_description', request_line.item_description,
            'brand_origin', request_line.brand_origin,
            'requested_qty', request_line.requested_qty::text,
            'unit', request_line.unit,
            'source_kind', arrangement_line.source_kind,
            'external_supplier', arrangement_line.external_supplier,
            'decision', arrangement_line.decision,
            'arranged_qty', case when arrangement_line.arranged_qty is null then null
              else arrangement_line.arranged_qty::text end,
            'reason', arrangement_line.reason,
            'inventory_item_id', arrangement_line.inventory_item_id,
            'inventory_item_description', inventory_item.item_description,
            'warehouse_available_at_save', case when arrangement_line.warehouse_available_at_save is null then null
              else arrangement_line.warehouse_available_at_save::text end,
            'reservation_state', reservation.state,
            'reserved_qty', case when reservation.reserved_qty is null then null
              else reservation.reserved_qty::text end
          ) order by request_line.display_order)
          from public.v1_procurement_arrangement_lines arrangement_line
          join public.v1_material_request_lines request_line
            on request_line.id = arrangement_line.request_line_id
          left join public.v1_inventory_items inventory_item
            on inventory_item.id = arrangement_line.inventory_item_id
          left join public.v1_inventory_reservations reservation
            on reservation.arrangement_line_id = arrangement_line.id
          where arrangement_line.arrangement_id = arrangement.id
        ), '[]'::jsonb)
      ) order by arrangement.arrangement_version desc)
      from public.v1_procurement_arrangements arrangement
      join public.v1_profiles starter
        on starter.auth_user_id = arrangement.started_by_auth_user_id
      left join public.v1_profiles saver
        on saver.auth_user_id = arrangement.saved_by_auth_user_id
      where arrangement.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

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
    or (v_item_id is not null and (v_description is not null or v_brand_origin is not null or v_unit is not null)) then
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
  select * into v_balance from public.v1_inventory_balances
  where inventory_item_id = v_item_id for update;
  if not found then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  if v_balance.on_hand_qty + v_delta < 0 then
    raise exception 'V1_INVENTORY_ON_HAND_NEGATIVE' using errcode = '22023';
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

create or replace function public.v1_begin_arrangement(
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
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_arrangement_id uuid;
  v_arrangement_version integer;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'begin_arrangement'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_BEGIN_ARRANGEMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_arrange_material_request(v_request_id) then
    raise exception 'V1_BEGIN_ARRANGEMENT_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_begin_arrangement', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state not in ('submitted', 'arranging') then
    raise exception 'V1_BEGIN_ARRANGEMENT_STATE_INVALID' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request.id and arrangement.status = 'working'
  ) then
    raise exception 'V1_ARRANGEMENT_ALREADY_IN_PROGRESS' using errcode = '40001';
  end if;
  if v_request.state = 'arranging' and not exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request.id
      and arrangement.is_current and arrangement.status = 'returned'
  ) then
    raise exception 'V1_BEGIN_ARRANGEMENT_STATE_INVALID' using errcode = '22023';
  end if;
  select coalesce(max(arrangement_version), 0) + 1 into v_arrangement_version
  from public.v1_procurement_arrangements where request_id = v_request.id;
  v_before := public.v1_arrangement_projection(v_request.id);
  insert into public.v1_procurement_arrangements (
    request_id, arrangement_version, status, is_current, started_by_auth_user_id
  ) values (
    v_request.id, v_arrangement_version, 'working', false, v_actor
  ) returning id into v_arrangement_id;
  insert into public.v1_procurement_arrangement_lines (
    arrangement_id, request_line_id, source_kind
  )
  select v_arrangement_id, request_line.id, 'warehouse'
  from public.v1_material_request_lines request_line
  where request_line.request_id = v_request.id
  order by request_line.display_order;
  update public.v1_material_requests
     set state = 'arranging',
         current_action_owner_role = 'procurement',
         current_action_code = 'arrangement_in_progress',
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_request.id;
  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_write_audit_event(
    'arrangement_begun', 'procurement_arrangement', v_arrangement_id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'request_state', 'arranging',
      'arrangement_version', v_arrangement_version,
      'request_record_version', v_expected_version + 1
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_begin_arrangement', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_arrangement(
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
  v_request_id uuid;
  v_arrangement_id uuid;
  v_expected_request_version integer;
  v_expected_arrangement_version integer;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_arrangement public.v1_procurement_arrangements%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_line jsonb;
  v_line_id uuid;
  v_decision text;
  v_source_kind text;
  v_inventory_item_id uuid;
  v_external_supplier text;
  v_arranged_qty numeric(18, 4);
  v_reason text;
  v_requested_qty numeric(18, 4);
  v_item_id uuid;
  v_on_hand numeric(18, 4);
  v_other_reserved numeric(18, 4);
  v_new_reserved numeric(18, 4);
  v_line_count integer;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'arrangement_id', 'expected_request_version',
      'expected_arrangement_version', 'lines'],
    'save_arrangement'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_arrangement_id := nullif(btrim(coalesce(p_payload ->> 'arrangement_id', '')), '')::uuid;
  v_expected_request_version := nullif(p_payload ->> 'expected_request_version', '')::integer;
  v_expected_arrangement_version := nullif(p_payload ->> 'expected_arrangement_version', '')::integer;
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_arrangement_id is null
    or v_expected_request_version is null or v_expected_arrangement_version is null
    or v_expected_request_version < 1 or v_expected_arrangement_version < 1
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_arrange_material_request(v_request_id) then
    raise exception 'V1_SAVE_ARRANGEMENT_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_arrangement', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  select * into v_arrangement from public.v1_procurement_arrangements arrangement
  where arrangement.id = v_arrangement_id and arrangement.request_id = v_request.id
  for update;
  if not found or v_arrangement.status <> 'working' then
    raise exception 'V1_ARRANGEMENT_NOT_WORKING' using errcode = '22023';
  end if;
  if v_request.state <> 'arranging' then
    raise exception 'V1_SAVE_ARRANGEMENT_STATE_INVALID' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_request_version
    or v_arrangement.record_version <> v_expected_arrangement_version then
    raise exception 'V1_ARRANGEMENT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select count(*) into v_line_count from public.v1_procurement_arrangement_lines
  where arrangement_id = v_arrangement.id;
  if jsonb_array_length(v_lines) <> v_line_count
    or (select count(distinct nullif(btrim(coalesce(value ->> 'arrangement_line_id', '')), '')::uuid)
        from jsonb_array_elements(v_lines)) <> v_line_count then
    raise exception 'V1_ARRANGEMENT_LINES_INCOMPLETE' using errcode = '22023';
  end if;

  -- Validate each line before releasing or creating any reservation. The
  -- function is the quantity authority; direct line writes have no grant.
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array['arrangement_line_id', 'source_kind', 'external_supplier',
        'inventory_item_id', 'decision', 'arranged_qty', 'reason'],
      'arrangement_line'
    );
    v_line_id := nullif(btrim(coalesce(v_line ->> 'arrangement_line_id', '')), '')::uuid;
    v_source_kind := coalesce(v_line ->> 'source_kind', '');
    v_external_supplier := nullif(btrim(coalesce(v_line ->> 'external_supplier', '')), '');
    v_inventory_item_id := nullif(btrim(coalesce(v_line ->> 'inventory_item_id', '')), '')::uuid;
    v_decision := coalesce(v_line ->> 'decision', '');
    v_arranged_qty := nullif(v_line ->> 'arranged_qty', '')::numeric(18, 4);
    v_reason := nullif(btrim(coalesce(v_line ->> 'reason', '')), '');
    select request_line.requested_qty into v_requested_qty
    from public.v1_procurement_arrangement_lines arrangement_line
    join public.v1_material_request_lines request_line
      on request_line.id = arrangement_line.request_line_id
    where arrangement_line.id = v_line_id
      and arrangement_line.arrangement_id = v_arrangement.id;
    if v_requested_qty is null or v_source_kind not in ('warehouse', 'external_supplier')
      or v_decision not in ('full', 'partial', 'unavailable')
      or v_arranged_qty is null or v_arranged_qty < 0
      or (v_source_kind = 'warehouse' and v_inventory_item_id is null)
      or (v_source_kind = 'warehouse' and v_external_supplier is not null)
      or (v_source_kind = 'external_supplier' and (
        v_external_supplier is null or v_inventory_item_id is not null
      ))
      or (v_decision = 'full' and v_arranged_qty <> v_requested_qty)
      or (v_decision = 'partial' and (
        v_arranged_qty <= 0 or v_arranged_qty >= v_requested_qty or v_reason is null
      ))
      or (v_decision = 'unavailable' and (
        v_arranged_qty <> 0 or v_reason is null
      )) then
      raise exception 'V1_ARRANGEMENT_LINE_INVALID' using errcode = '22023';
    end if;
  end loop;
  if (select count(*) from jsonb_array_elements(v_lines) line_json
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.id = nullif(
          btrim(coalesce(line_json.value ->> 'arrangement_line_id', '')), ''
        )::uuid
      where arrangement_line.arrangement_id = v_arrangement.id) <> v_line_count then
    raise exception 'V1_ARRANGEMENT_LINE_NOT_FOUND' using errcode = '22023';
  end if;

  -- Locks follow inventory-item UUID order. Existing reservations for this MR
  -- are included so a replacement releases only under the same transaction.
  for v_item_id in
    select inventory_item_id from public.v1_inventory_reservations
      where request_id = v_request.id and state in ('active', 'partially_consumed')
    union
    select nullif(btrim(coalesce(value ->> 'inventory_item_id', '')), '')::uuid
      from jsonb_array_elements(v_lines)
      where value ->> 'source_kind' = 'warehouse'
    order by 1
  loop
    select balance.on_hand_qty into v_on_hand
    from public.v1_inventory_balances balance
    join public.v1_inventory_items item on item.id = balance.inventory_item_id
    where balance.inventory_item_id = v_item_id and item.is_active
    for update;
    if not found then
      raise exception 'V1_ARRANGEMENT_INVENTORY_ITEM_INVALID' using errcode = '22023';
    end if;
    select coalesce(sum(reservation.reserved_qty), 0) into v_other_reserved
    from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.request_id <> v_request.id
      and reservation.state in ('active', 'partially_consumed');
    select coalesce(sum(nullif(value ->> 'arranged_qty', '')::numeric(18, 4)), 0)
      into v_new_reserved
    from jsonb_array_elements(v_lines)
    where value ->> 'source_kind' = 'warehouse'
      and nullif(btrim(coalesce(value ->> 'inventory_item_id', '')), '')::uuid = v_item_id;
    if v_on_hand - v_other_reserved < v_new_reserved then
      raise exception 'V1_INVENTORY_RESERVATION_EXCEEDS_AVAILABLE' using errcode = '22023';
    end if;
  end loop;

  v_before := public.v1_arrangement_projection(v_request.id);
  update public.v1_inventory_reservations
     set state = 'released', released_at = clock_timestamp(),
         released_by_auth_user_id = v_actor,
         release_reason = 'arrangement_replaced', updated_at = clock_timestamp()
   where request_id = v_request.id and state in ('active', 'partially_consumed');
  update public.v1_procurement_arrangements
     set status = 'superseded', is_current = false,
         superseded_at = clock_timestamp(), superseded_by_auth_user_id = v_actor,
         updated_at = clock_timestamp()
   where request_id = v_request.id and is_current;
  update public.v1_procurement_arrangement_lines arrangement_line
     set source_kind = line_json.value ->> 'source_kind',
         external_supplier = nullif(btrim(coalesce(
           line_json.value ->> 'external_supplier', ''
         )), ''),
         inventory_item_id = nullif(btrim(coalesce(
           line_json.value ->> 'inventory_item_id', ''
         )), '')::uuid,
         decision = line_json.value ->> 'decision',
         arranged_qty = nullif(line_json.value ->> 'arranged_qty', '')::numeric(18, 4),
         reason = nullif(btrim(coalesce(line_json.value ->> 'reason', '')), ''),
         warehouse_available_at_save = case
           when line_json.value ->> 'source_kind' <> 'warehouse' then null
           else (
             select balance.on_hand_qty - coalesce(sum(reservation.reserved_qty), 0)
             from public.v1_inventory_balances balance
             left join public.v1_inventory_reservations reservation
               on reservation.inventory_item_id = balance.inventory_item_id
              and reservation.request_id <> v_request.id
              and reservation.state in ('active', 'partially_consumed')
             where balance.inventory_item_id = nullif(btrim(coalesce(
               line_json.value ->> 'inventory_item_id', ''
             )), '')::uuid
             group by balance.on_hand_qty
           )
         end,
         updated_at = clock_timestamp()
    from jsonb_array_elements(v_lines) line_json
   where arrangement_line.id = nullif(btrim(coalesce(
     line_json.value ->> 'arrangement_line_id', ''
   )), '')::uuid
     and arrangement_line.arrangement_id = v_arrangement.id;
  insert into public.v1_inventory_reservations (
    inventory_item_id, arrangement_line_id, request_id, reserved_qty
  )
  select arrangement_line.inventory_item_id, arrangement_line.id,
    v_request.id, arrangement_line.arranged_qty
  from public.v1_procurement_arrangement_lines arrangement_line
  where arrangement_line.arrangement_id = v_arrangement.id
    and arrangement_line.source_kind = 'warehouse'
    and arrangement_line.arranged_qty > 0;
  update public.v1_procurement_arrangements
     set status = 'awaiting_approval', is_current = true,
         saved_at = clock_timestamp(), saved_by_auth_user_id = v_actor,
         record_version = record_version + 1, updated_at = clock_timestamp()
   where id = v_arrangement.id;
  update public.v1_material_requests
     set state = 'awaiting_approval',
         current_action_owner_role = 'project_engineer',
         current_action_code = 'arrangement_review_required',
         record_version = record_version + 1, updated_at = clock_timestamp()
   where id = v_request.id;
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct member.member_auth_user_id, 'arrangement_review_required',
    'procurement_arrangement', v_arrangement.id, v_request.project_id
  from public.v1_project_members member
  join public.v1_profiles profile on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = v_request.project_id
    and member.project_role = 'project_engineer'
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
    and profile.is_active;
  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_write_audit_event(
    'arrangement_saved', 'procurement_arrangement', v_arrangement.id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'request_state', 'awaiting_approval',
      'request_record_version', v_expected_request_version + 1,
      'arrangement_record_version', v_expected_arrangement_version + 1,
      'reserved_line_count', (select count(*) from public.v1_inventory_reservations
        where request_id = v_request.id and state = 'active')
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_arrangement', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_decide_arrangement(
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
  v_arrangement_id uuid;
  v_expected_request_version integer;
  v_expected_arrangement_version integer;
  v_decision text;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_arrangement public.v1_procurement_arrangements%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'arrangement_id', 'expected_request_version',
      'expected_arrangement_version', 'decision', 'reason'],
    'decide_arrangement'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_arrangement_id := nullif(btrim(coalesce(p_payload ->> 'arrangement_id', '')), '')::uuid;
  v_expected_request_version := nullif(p_payload ->> 'expected_request_version', '')::integer;
  v_expected_arrangement_version := nullif(p_payload ->> 'expected_arrangement_version', '')::integer;
  v_decision := coalesce(p_payload ->> 'decision', '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_arrangement_id is null
    or v_expected_request_version is null or v_expected_arrangement_version is null
    or v_expected_request_version < 1 or v_expected_arrangement_version < 1
    or v_decision not in ('approved', 'returned')
    or (v_decision = 'returned' and v_reason is null) then
    raise exception 'V1_ARRANGEMENT_DECISION_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_decide_arrangement(v_request_id) then
    raise exception 'V1_ARRANGEMENT_DECISION_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_decide_arrangement', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  select * into v_arrangement from public.v1_procurement_arrangements arrangement
  where arrangement.id = v_arrangement_id and arrangement.request_id = v_request.id
  for update;
  if not found or not v_arrangement.is_current
    or v_arrangement.status <> 'awaiting_approval'
    or v_request.state <> 'awaiting_approval' then
    raise exception 'V1_ARRANGEMENT_NOT_AWAITING_DECISION' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_request_version
    or v_arrangement.record_version <> v_expected_arrangement_version then
    raise exception 'V1_ARRANGEMENT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  v_before := public.v1_arrangement_projection(v_request.id);
  insert into public.v1_arrangement_decisions (
    arrangement_id, request_id, decision, reason,
    decided_by_auth_user_id, decided_by_role
  ) values (
    v_arrangement.id, v_request.id, v_decision, v_reason, v_actor, v_role
  );
  if v_decision = 'approved' then
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select request_line_id from public.v1_procurement_arrangement_lines
      where arrangement_id = v_arrangement.id
    );
    insert into public.v1_material_request_line_approvals (
      request_line_id, arrangement_line_id, arrangement_id, approved_qty,
      approved_by_auth_user_id
    )
    select arrangement_line.request_line_id, arrangement_line.id,
      v_arrangement.id, arrangement_line.arranged_qty, v_actor
    from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id;
    update public.v1_procurement_arrangements
       set status = 'approved', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'approved', current_action_owner_role = 'procurement',
           current_action_code = 'dispatch_required',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  else
    -- The active reservation intentionally remains. It is released only when
    -- Procurement saves a replacement or an eligible request is cancelled.
    update public.v1_procurement_arrangements
       set status = 'returned', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'arranging', current_action_owner_role = 'procurement',
           current_action_code = 'arrangement_returned',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  end if;
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id,
    case when v_decision = 'approved' then 'arrangement_approved'
      else 'arrangement_returned' end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_write_audit_event(
    case when v_decision = 'approved' then 'arrangement_approved'
      else 'arrangement_returned' end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'decision', v_decision,
      'request_state', case when v_decision = 'approved' then 'approved'
        else 'arranging' end,
      'request_record_version', v_expected_request_version + 1,
      'arrangement_record_version', v_expected_arrangement_version + 1
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_decide_arrangement', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Batch 5 allowed cancellation while Submitted. Batch 6 extends that same
-- controlled command through approved-but-undispatched work and releases only
-- the request's live warehouse commitment under the inventory locks.
create or replace function public.v1_cancel_material_request(
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
  v_request_id uuid;
  v_expected_version integer;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_item_id uuid;
  v_release_count integer;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version', 'reason'],
    'cancel_material_request'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_version is null or v_reason is null then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_NOT_ELIGIBLE' using errcode = '22023';
  end if;
  if public.v1_current_role() <> 'admin' and not (
    public.v1_current_role() in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      v_request.project_id, v_actor, 'project_engineer'
    )
  ) then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_cancel_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state not in ('submitted', 'arranging', 'awaiting_approval', 'approved') then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_NOT_ELIGIBLE' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  for v_item_id in
    select distinct inventory_item_id from public.v1_inventory_reservations
    where request_id = v_request.id and state in ('active', 'partially_consumed')
    order by inventory_item_id
  loop
    perform 1 from public.v1_inventory_balances
    where inventory_item_id = v_item_id for update;
  end loop;
  v_before := public.v1_material_request_projection(v_request.id);
  update public.v1_inventory_reservations
     set state = 'released', released_at = clock_timestamp(),
         released_by_auth_user_id = v_actor, release_reason = 'request_cancelled',
         updated_at = clock_timestamp()
   where request_id = v_request.id and state in ('active', 'partially_consumed');
  get diagnostics v_release_count = row_count;
  update public.v1_procurement_arrangements
     set status = 'cancelled', is_current = false,
         saved_at = coalesce(saved_at, clock_timestamp()),
         saved_by_auth_user_id = coalesce(saved_by_auth_user_id, v_actor),
         updated_at = clock_timestamp()
   where request_id = v_request.id and status in (
     'working', 'awaiting_approval', 'returned', 'approved'
   );
  update public.v1_material_requests
     set state = 'cancelled', current_action_owner_role = 'none',
         current_action_code = 'cancelled', cancelled_at = clock_timestamp(),
         cancelled_by_auth_user_id = v_actor, cancellation_reason = v_reason,
         record_version = record_version + 1, updated_at = clock_timestamp()
   where id = v_request.id;
  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_cancelled', 'material_request', v_request.id,
    v_request.project_id, v_before,
    jsonb_build_object('state', 'cancelled',
      'record_version', v_expected_version + 1,
      'released_reservation_count', v_release_count),
    v_reason, p_idempotency_key
  );
  if v_release_count > 0 then
    perform public.v1_write_audit_event(
      'arrangement_reservations_released', 'material_request', v_request.id,
      v_request.project_id, null,
      jsonb_build_object('released_reservation_count', v_release_count),
      'request_cancelled', null
    );
  end if;
  perform public.v1_complete_idempotency(
    'v1_cancel_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_arrange_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_decide_arrangement(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_item_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_arrangement_projection(uuid)
  from public, anon;
revoke all on function public.v1_list_arrangement_inventory_items()
  from public, anon;
revoke all on function public.v1_adjust_inventory(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_begin_arrangement(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_decide_arrangement(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_cancel_material_request(jsonb, uuid)
  from public, anon;

grant execute on function public.v1_arrangement_projection(uuid) to authenticated;
grant execute on function public.v1_list_arrangement_inventory_items() to authenticated;
grant execute on function public.v1_adjust_inventory(jsonb, uuid) to authenticated;
grant execute on function public.v1_begin_arrangement(jsonb, uuid) to authenticated;
grant execute on function public.v1_save_arrangement(jsonb, uuid) to authenticated;
grant execute on function public.v1_decide_arrangement(jsonb, uuid) to authenticated;
grant execute on function public.v1_cancel_material_request(jsonb, uuid) to authenticated;
