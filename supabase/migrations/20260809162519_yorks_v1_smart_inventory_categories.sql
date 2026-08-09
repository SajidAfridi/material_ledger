-- Yorks R38.3: smart, reusable warehouse categories plus a transactional
-- inventory-import boundary. This migration is additive and preserves every
-- existing inventory item, balance, reservation and movement. Existing items
-- remain honestly uncategorized until Procurement confirms a mapping.

create or replace function public.v1_inventory_category_key(p_value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.regexp_replace(
    pg_catalog.lower(pg_catalog.btrim(p_value)), '[^a-z0-9]+', '', 'g'
  );
$$;

create or replace function public.v1_inventory_category_display_name(p_value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.regexp_replace(
    pg_catalog.regexp_replace(
      pg_catalog.regexp_replace(
        pg_catalog.regexp_replace(
          pg_catalog.regexp_replace(
            pg_catalog.regexp_replace(
              pg_catalog.initcap(
                pg_catalog.regexp_replace(
                  pg_catalog.lower(pg_catalog.btrim(p_value)),
                  '[[:space:]]+', ' ', 'g'
                )
              ),
              '\mAc\M', 'AC', 'g'
            ),
            '\mHvac\M', 'HVAC', 'g'
          ),
          '\mGi\M', 'GI', 'g'
        ),
        '\mPvc\M', 'PVC', 'g'
      ),
      '\mSed\M', 'SED', 'g'
    ),
    '\mRed\M', 'RED', 'g'
  );
$$;

create table if not exists public.v1_inventory_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  normalized_name text not null check (btrim(normalized_name) <> ''),
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  record_version integer not null default 1 check (record_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (normalized_name)
);

create table if not exists public.v1_inventory_category_aliases (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.v1_inventory_categories (id)
    on delete restrict,
  alias_name text not null check (btrim(alias_name) <> ''),
  normalized_alias text not null check (btrim(normalized_alias) <> ''),
  created_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (normalized_alias)
);

create index if not exists v1_inventory_category_aliases_category_idx
  on public.v1_inventory_category_aliases (category_id, alias_name);

alter table public.v1_inventory_items
  add column if not exists item_code text,
  add column if not exists category_id uuid
    references public.v1_inventory_categories (id) on delete restrict,
  add column if not exists minimum_stock numeric(18, 4),
  add column if not exists location_bin text,
  add column if not exists notes text;

create unique index if not exists v1_inventory_items_code_unique_idx
  on public.v1_inventory_items (lower(btrim(item_code)))
  where item_code is not null;
create index if not exists v1_inventory_items_category_active_idx
  on public.v1_inventory_items (category_id, is_active);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_inventory_items_code_nonblank_check'
      and conrelid = 'public.v1_inventory_items'::regclass
  ) then
    alter table public.v1_inventory_items
      add constraint v1_inventory_items_code_nonblank_check
      check (item_code is null or btrim(item_code) <> '');
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_inventory_items_minimum_stock_check'
      and conrelid = 'public.v1_inventory_items'::regclass
  ) then
    alter table public.v1_inventory_items
      add constraint v1_inventory_items_minimum_stock_check
      check (minimum_stock is null or minimum_stock >= 0);
  end if;
end;
$$;

create table if not exists public.v1_inventory_import_batches (
  id uuid primary key default gen_random_uuid(),
  file_name text not null check (btrim(file_name) <> ''),
  row_count integer not null check (row_count > 0),
  actor_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (actor_auth_user_id, idempotency_key)
);

create table if not exists public.v1_inventory_import_rows (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid not null references public.v1_inventory_import_batches (id)
    on delete restrict,
  source_row_number integer not null check (source_row_number > 0),
  inventory_item_id uuid not null references public.v1_inventory_items (id)
    on delete restrict,
  category_id uuid references public.v1_inventory_categories (id)
    on delete restrict,
  source_category_text text,
  stock_action text not null check (stock_action in (
    'opening_balance', 'add_stock', 'remove_stock', 'no_stock_change'
  )),
  quantity numeric(18, 4) not null check (quantity >= 0),
  reason text not null check (btrim(reason) <> ''),
  created_item boolean not null default false,
  created_at timestamptz not null default clock_timestamp(),
  unique (import_batch_id, source_row_number)
);

create index if not exists v1_inventory_import_rows_item_idx
  on public.v1_inventory_import_rows (inventory_item_id, created_at desc);

alter table public.v1_inventory_categories enable row level security;
alter table public.v1_inventory_category_aliases enable row level security;
alter table public.v1_inventory_import_batches enable row level security;
alter table public.v1_inventory_import_rows enable row level security;

revoke all on table public.v1_inventory_categories
  from public, anon, authenticated;
revoke all on table public.v1_inventory_category_aliases
  from public, anon, authenticated;
revoke all on table public.v1_inventory_import_batches
  from public, anon, authenticated;
revoke all on table public.v1_inventory_import_rows
  from public, anon, authenticated;
grant all on table public.v1_inventory_categories to service_role;
grant all on table public.v1_inventory_category_aliases to service_role;
grant all on table public.v1_inventory_import_batches to service_role;
grant all on table public.v1_inventory_import_rows to service_role;

insert into public.v1_inventory_categories (
  id, name, normalized_name, is_system, created_by_auth_user_id
)
values
  ('41000000-0000-4000-8000-000000000001', 'Air Terminals', 'airterminals', true, null),
  ('41000000-0000-4000-8000-000000000002', 'Air Terminals - Round', 'airterminalsround', true, null),
  ('41000000-0000-4000-8000-000000000003', 'Air Terminals - Linear Grille', 'airterminalslineargrille', true, null),
  ('41000000-0000-4000-8000-000000000004', 'Air Terminals - SED', 'airterminalssed', true, null),
  ('41000000-0000-4000-8000-000000000005', 'Air Terminals - RED', 'airterminalsred', true, null),
  ('41000000-0000-4000-8000-000000000006', 'Dampers & Fire Control', 'dampersfirecontrol', true, null),
  ('41000000-0000-4000-8000-000000000007', 'Fans & Equipment', 'fansequipment', true, null),
  ('41000000-0000-4000-8000-000000000008', 'Ductwork & Accessories', 'ductworkaccessories', true, null),
  ('41000000-0000-4000-8000-000000000009', 'Piping & Drain', 'pipingdrain', true, null),
  ('41000000-0000-4000-8000-000000000010', 'Electrical & Controls', 'electricalcontrols', true, null),
  ('41000000-0000-4000-8000-000000000011', 'Supports & Insulation', 'supportsinsulation', true, null),
  ('41000000-0000-4000-8000-000000000012', 'General & Custom', 'generalcustom', true, null)
on conflict (normalized_name) do nothing;

insert into public.v1_inventory_category_aliases (
  category_id, alias_name, normalized_alias, created_by_auth_user_id
)
values
  ('41000000-0000-4000-8000-000000000001', 'Air Terminal', 'airterminal', null),
  ('41000000-0000-4000-8000-000000000002', 'Round AC Terminal', 'roundacterminal', null),
  ('41000000-0000-4000-8000-000000000002', 'Round Air Terminal', 'roundairterminal', null),
  ('41000000-0000-4000-8000-000000000002', 'Circular Air Terminal', 'circularairterminal', null),
  ('41000000-0000-4000-8000-000000000003', 'Linear Grill', 'lineargrill', null),
  ('41000000-0000-4000-8000-000000000003', 'Linear Grille', 'lineargrille', null),
  ('41000000-0000-4000-8000-000000000003', 'Air Terminal Linear', 'airterminallinear', null),
  ('41000000-0000-4000-8000-000000000004', 'SED', 'sed', null),
  ('41000000-0000-4000-8000-000000000005', 'RED', 'red', null),
  ('41000000-0000-4000-8000-000000000006', 'Damper', 'damper', null),
  ('41000000-0000-4000-8000-000000000006', 'Fire Damper', 'firedamper', null),
  ('41000000-0000-4000-8000-000000000007', 'Fan', 'fan', null),
  ('41000000-0000-4000-8000-000000000007', 'Ventilation Fan', 'ventilationfan', null),
  ('41000000-0000-4000-8000-000000000008', 'Duct', 'duct', null),
  ('41000000-0000-4000-8000-000000000008', 'Duct Accessories', 'ductaccessories', null),
  ('41000000-0000-4000-8000-000000000009', 'Pipe', 'pipe', null),
  ('41000000-0000-4000-8000-000000000009', 'Piping', 'piping', null),
  ('41000000-0000-4000-8000-000000000009', 'Drain', 'drain', null),
  ('41000000-0000-4000-8000-000000000010', 'Electrical', 'electrical', null),
  ('41000000-0000-4000-8000-000000000010', 'Controls', 'controls', null),
  ('41000000-0000-4000-8000-000000000011', 'Support', 'support', null),
  ('41000000-0000-4000-8000-000000000011', 'Insulation', 'insulation', null),
  ('41000000-0000-4000-8000-000000000012', 'General', 'general', null),
  ('41000000-0000-4000-8000-000000000012', 'Other', 'other', null)
on conflict (normalized_alias) do nothing;

create or replace function public.v1_inventory_category_projection(
  p_category_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', category.id,
    'name', category.name,
    'is_system', category.is_system,
    'is_active', category.is_active,
    'record_version', category.record_version,
    'item_count', (
      select count(*) from public.v1_inventory_items item
      where item.category_id = category.id and item.is_active
    ),
    'aliases', coalesce((
      select jsonb_agg(alias.alias_name order by lower(alias.alias_name))
      from public.v1_inventory_category_aliases alias
      where alias.category_id = category.id
    ), '[]'::jsonb),
    'created_by_display_name', case
      when category.created_by_auth_user_id is null then 'Yorks standard'
      else public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      )
    end,
    'created_at', category.created_at
  )
  from public.v1_inventory_categories category
  left join public.v1_profiles profile
    on profile.auth_user_id = category.created_by_auth_user_id
  where category.id = p_category_id;
$$;

create or replace function public.v1_resolve_inventory_category(
  p_category_id uuid,
  p_new_category_name text,
  p_source_alias text,
  p_default_general boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_category public.v1_inventory_categories%rowtype;
  v_name text;
  v_key text;
  v_alias text := nullif(btrim(coalesce(p_source_alias, '')), '');
  v_alias_key text;
  v_alias_category_id uuid;
  v_created boolean := false;
begin
  if p_category_id is not null then
    select * into v_category from public.v1_inventory_categories
    where id = p_category_id and is_active;
    if not found then
      raise exception 'V1_INVENTORY_CATEGORY_NOT_FOUND' using errcode = '22023';
    end if;
  elsif nullif(btrim(coalesce(p_new_category_name, '')), '') is not null then
    v_name := public.v1_inventory_category_display_name(p_new_category_name);
    v_key := public.v1_inventory_category_key(v_name);
    if v_key = '' or char_length(v_name) > 120 then
      raise exception 'V1_INVENTORY_CATEGORY_NAME_INVALID' using errcode = '22023';
    end if;
    select * into v_category from public.v1_inventory_categories
    where normalized_name = v_key;
    if not found then
      select category.* into v_category
      from public.v1_inventory_category_aliases alias
      join public.v1_inventory_categories category on category.id = alias.category_id
      where alias.normalized_alias = v_key and category.is_active;
    end if;
    if not found then
      insert into public.v1_inventory_categories (
        name, normalized_name, is_system, created_by_auth_user_id
      ) values (v_name, v_key, false, v_actor)
      returning * into v_category;
      v_created := true;
    elsif not v_category.is_active then
      raise exception 'V1_INVENTORY_CATEGORY_INACTIVE' using errcode = '22023';
    end if;
  elsif p_default_general then
    select * into v_category from public.v1_inventory_categories
    where normalized_name = 'generalcustom' and is_active;
  else
    return null;
  end if;

  if v_alias is not null then
    v_alias_key := public.v1_inventory_category_key(v_alias);
    if v_alias_key <> '' and v_alias_key <> v_category.normalized_name then
      select id into v_alias_category_id
      from public.v1_inventory_categories
      where normalized_name = v_alias_key;
      if v_alias_category_id is not null and v_alias_category_id <> v_category.id then
        raise exception 'V1_INVENTORY_CATEGORY_ALIAS_CONFLICT'
          using errcode = '40001';
      end if;
      select category_id into v_alias_category_id
      from public.v1_inventory_category_aliases
      where normalized_alias = v_alias_key;
      if v_alias_category_id is not null and v_alias_category_id <> v_category.id then
        raise exception 'V1_INVENTORY_CATEGORY_ALIAS_CONFLICT'
          using errcode = '40001';
      end if;
      insert into public.v1_inventory_category_aliases (
        category_id, alias_name, normalized_alias, created_by_auth_user_id
      ) values (
        v_category.id,
        public.v1_inventory_category_display_name(v_alias),
        v_alias_key,
        v_actor
      ) on conflict (normalized_alias) do nothing;
    end if;
  end if;
  return jsonb_build_object(
    'id', v_category.id, 'name', v_category.name, 'created', v_created
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
    'item_code', item.item_code,
    'item_description', item.item_description,
    'category_id', item.category_id,
    'category_name', category.name,
    'brand_origin', item.brand_origin,
    'unit', item.unit,
    'minimum_stock', item.minimum_stock::text,
    'location_bin', item.location_bin,
    'notes', item.notes,
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
    'record_version', balance.record_version,
    'created_at', item.created_at,
    'updated_at', item.updated_at
  )
  from public.v1_inventory_items item
  join public.v1_inventory_balances balance
    on balance.inventory_item_id = item.id
  left join public.v1_inventory_categories category
    on category.id = item.category_id
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
  return (
    with projected_items as (
      select
        item.id,
        item.is_active,
        item.category_id,
        lower(item.item_description) as description_order,
        lower(coalesce(item.brand_origin, '')) as brand_order,
        public.v1_inventory_item_projection(item.id) as item_projection
      from public.v1_inventory_items item
      left join public.v1_inventory_categories category
        on category.id = item.category_id
      where v_search is null
        or lower(coalesce(item.item_code, '')) like '%' || v_search || '%'
        or lower(item.item_description) like '%' || v_search || '%'
        or lower(coalesce(item.brand_origin, '')) like '%' || v_search || '%'
        or lower(item.unit) like '%' || v_search || '%'
        or lower(coalesce(item.location_bin, '')) like '%' || v_search || '%'
        or lower(coalesce(category.name, '')) like '%' || v_search || '%'
    ), enriched_items as (
      select
        projected_items.*,
        projected_items.item_projection || jsonb_build_object(
          'movement_count', (
            select count(*) from public.v1_inventory_movements movement
            where movement.inventory_item_id = projected_items.id
          ),
          'last_movement_at', (
            select max(movement.created_at) from public.v1_inventory_movements movement
            where movement.inventory_item_id = projected_items.id
          )
        ) as item
      from projected_items
    )
    select jsonb_build_object(
      'items', coalesce((
        select jsonb_agg(item order by description_order, brand_order)
        from enriched_items
      ), '[]'::jsonb),
      'categories', coalesce((
        select jsonb_agg(
          public.v1_inventory_category_projection(category.id)
          order by lower(category.name)
        )
        from public.v1_inventory_categories category
        where category.is_active
      ), '[]'::jsonb),
      'recent_movements', coalesce((
        select jsonb_agg(movement_record order by created_at desc)
        from (
          select
            movement.created_at,
            jsonb_build_object(
              'id', movement.id,
              'inventory_item_id', movement.inventory_item_id,
              'item_code', item.item_code,
              'item_description', item.item_description,
              'unit', item.unit,
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
            ) as movement_record
          from public.v1_inventory_movements movement
          join public.v1_inventory_items item on item.id = movement.inventory_item_id
          join public.v1_profiles profile on profile.auth_user_id = movement.actor_auth_user_id
          order by movement.created_at desc
          limit 100
        ) recent
      ), '[]'::jsonb),
      'reservations', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', reservation.id,
          'inventory_item_id', reservation.inventory_item_id,
          'item_code', item.item_code,
          'item_description', item.item_description,
          'unit', item.unit,
          'request_id', request_record.id,
          'request_number', request_record.request_number,
          'project_name', project.name,
          'scope_name', scope.name,
          'reserved_qty', reservation.reserved_qty::text,
          'remaining_qty', (reservation.reserved_qty - reservation.consumed_qty)::text,
          'state', reservation.state,
          'created_at', reservation.created_at
        ) order by reservation.created_at desc)
        from public.v1_inventory_reservations reservation
        join public.v1_inventory_items item on item.id = reservation.inventory_item_id
        join public.v1_material_requests request_record on request_record.id = reservation.request_id
        join public.v1_projects project on project.id = request_record.project_id
        join public.v1_project_scopes scope on scope.id = request_record.scope_id
        where reservation.state in ('active', 'partially_consumed')
      ), '[]'::jsonb),
      'summary', jsonb_build_object(
        'total_active_items', (
          select count(*) from enriched_items where is_active
        ),
        'low_stock_count', (
          select count(*) from enriched_items
          where is_active
            and nullif(item_projection ->> 'minimum_stock', '') is not null
            and (item_projection ->> 'available_qty')::numeric > 0
            and (item_projection ->> 'available_qty')::numeric
              <= (item_projection ->> 'minimum_stock')::numeric
        ),
        'out_of_stock_count', (
          select count(*) from enriched_items
          where is_active and (item_projection ->> 'available_qty')::numeric <= 0
        ),
        'reserved_count', (
          select count(*) from enriched_items
          where is_active and (item_projection ->> 'reserved_qty')::numeric > 0
        ),
        'incoming_count', 0
      )
    )
  );
end;
$$;

create or replace function public.v1_create_inventory_category(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing jsonb;
  v_resolution jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['name'], 'create_inventory_category'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_CATEGORY_CREATE_DENIED' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_payload ->> 'name', '')), '') is null then
    raise exception 'V1_INVENTORY_CATEGORY_NAME_REQUIRED' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_inventory_category', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_resolution := public.v1_resolve_inventory_category(
    null, p_payload ->> 'name', null, false
  );
  v_response := public.v1_inventory_category_projection(
    (v_resolution ->> 'id')::uuid
  );
  perform public.v1_write_audit_event(
    'inventory_category_created', 'inventory_category',
    (v_resolution ->> 'id')::uuid, null, null, v_response,
    'Warehouse category created', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_inventory_category', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Backward-compatible stock command. Legacy callers remain valid and new
-- callers may atomically attach the smart category and operational metadata.
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
  v_item_id uuid;
  v_item_code text;
  v_description text;
  v_brand_origin text;
  v_unit text;
  v_delta numeric(18, 4);
  v_reason text;
  v_category_id uuid;
  v_new_category_name text;
  v_source_category text;
  v_category_resolution jsonb;
  v_minimum_stock numeric(18, 4);
  v_location_bin text;
  v_notes text;
  v_balance public.v1_inventory_balances%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
  v_reserved_remaining numeric(18, 4);
  v_created_item boolean := false;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['inventory_item_id', 'item_code', 'item_description', 'category_id',
      'new_category_name', 'source_category_text', 'brand_origin', 'unit',
      'minimum_stock', 'location_bin', 'notes', 'quantity_delta', 'reason'],
    'adjust_inventory'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_ADJUST_DENIED' using errcode = '42501';
  end if;
  v_item_id := nullif(btrim(coalesce(p_payload ->> 'inventory_item_id', '')), '')::uuid;
  v_item_code := nullif(btrim(coalesce(p_payload ->> 'item_code', '')), '');
  v_description := nullif(btrim(coalesce(p_payload ->> 'item_description', '')), '');
  v_brand_origin := nullif(btrim(coalesce(p_payload ->> 'brand_origin', '')), '');
  v_unit := nullif(btrim(coalesce(p_payload ->> 'unit', '')), '');
  v_delta := nullif(p_payload ->> 'quantity_delta', '')::numeric(18, 4);
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_category_id := nullif(btrim(coalesce(p_payload ->> 'category_id', '')), '')::uuid;
  v_new_category_name := nullif(btrim(coalesce(p_payload ->> 'new_category_name', '')), '');
  v_source_category := nullif(btrim(coalesce(p_payload ->> 'source_category_text', '')), '');
  v_minimum_stock := nullif(p_payload ->> 'minimum_stock', '')::numeric(18, 4);
  v_location_bin := nullif(btrim(coalesce(p_payload ->> 'location_bin', '')), '');
  v_notes := nullif(btrim(coalesce(p_payload ->> 'notes', '')), '');
  if v_delta is null or v_delta = 0 or v_reason is null
    or (v_minimum_stock is not null and v_minimum_stock < 0)
    or (v_category_id is not null and v_new_category_name is not null)
    or (v_item_id is null and (v_description is null or v_unit is null))
    or (v_item_id is not null and (
      v_item_code is not null or v_description is not null
      or v_brand_origin is not null or v_unit is not null
    )) then
    raise exception 'V1_INVENTORY_ADJUST_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_adjust_inventory', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_item_id is null then
    v_category_resolution := public.v1_resolve_inventory_category(
      v_category_id, v_new_category_name, v_source_category, true
    );
    v_item_id := gen_random_uuid();
    if v_item_code is null then
      v_item_code := 'INV-' || upper(substr(replace(v_item_id::text, '-', ''), 1, 8));
    end if;
    insert into public.v1_inventory_items (
      id, item_code, item_description, category_id, brand_origin, unit,
      minimum_stock, location_bin, notes, created_by_auth_user_id
    ) values (
      v_item_id, v_item_code, v_description,
      (v_category_resolution ->> 'id')::uuid,
      v_brand_origin, v_unit, v_minimum_stock, v_location_bin, v_notes, v_actor
    );
    insert into public.v1_inventory_balances (inventory_item_id)
    values (v_item_id);
    v_created_item := true;
  end if;
  select balance.* into v_balance
  from public.v1_inventory_balances balance
  join public.v1_inventory_items item on item.id = balance.inventory_item_id
  where balance.inventory_item_id = v_item_id and item.is_active
  for update of balance;
  if not found then
    raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode = '22023';
  end if;
  if not v_created_item and (
    v_category_id is not null or v_new_category_name is not null
    or v_minimum_stock is not null or v_location_bin is not null
    or v_notes is not null
  ) then
    if v_category_id is not null or v_new_category_name is not null then
      v_category_resolution := public.v1_resolve_inventory_category(
        v_category_id, v_new_category_name, v_source_category, false
      );
    end if;
    update public.v1_inventory_items
    set category_id = coalesce(
          (v_category_resolution ->> 'id')::uuid, category_id
        ),
        minimum_stock = coalesce(v_minimum_stock, minimum_stock),
        location_bin = coalesce(v_location_bin, location_bin),
        notes = coalesce(v_notes, notes),
        updated_at = clock_timestamp()
    where id = v_item_id;
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

create or replace function public.v1_import_inventory(
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
  v_file_name text;
  v_rows jsonb;
  v_row jsonb;
  v_row_number integer;
  v_item_id uuid;
  v_explicit_item_id uuid;
  v_item_code text;
  v_description text;
  v_brand_origin text;
  v_unit text;
  v_action text;
  v_quantity numeric(18, 4);
  v_delta numeric(18, 4);
  v_reason text;
  v_category_id uuid;
  v_new_category_name text;
  v_source_category text;
  v_category_resolution jsonb;
  v_resolved_category_id uuid;
  v_minimum_stock numeric(18, 4);
  v_location_bin text;
  v_notes text;
  v_batch_id uuid := gen_random_uuid();
  v_balance public.v1_inventory_balances%rowtype;
  v_reserved numeric(18, 4);
  v_created_item boolean;
  v_created_items integer := 0;
  v_updated_items integer := 0;
  v_created_categories integer := 0;
  v_movement_type text;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['file_name', 'rows'], 'import_inventory'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_IMPORT_DENIED' using errcode = '42501';
  end if;
  v_file_name := nullif(btrim(coalesce(p_payload ->> 'file_name', '')), '');
  v_rows := p_payload -> 'rows';
  if v_file_name is null or char_length(v_file_name) > 255
    or jsonb_typeof(v_rows) <> 'array'
    or jsonb_array_length(v_rows) < 1
    or jsonb_array_length(v_rows) > 5000 then
    raise exception 'V1_INVENTORY_IMPORT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_import_inventory', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  insert into public.v1_inventory_import_batches (
    id, file_name, row_count, actor_auth_user_id, idempotency_key
  ) values (
    v_batch_id, v_file_name, jsonb_array_length(v_rows), v_actor,
    p_idempotency_key
  );

  for v_row in select value from jsonb_array_elements(v_rows)
  loop
    perform public.v1_assert_object_keys(
      v_row,
      array['source_row_number', 'inventory_item_id', 'item_code',
        'item_description', 'category_id', 'new_category_name',
        'source_category_text', 'brand_origin', 'unit', 'stock_action',
        'quantity', 'reason', 'minimum_stock', 'location_bin', 'notes'],
      'import_inventory_row'
    );
    v_row_number := nullif(v_row ->> 'source_row_number', '')::integer;
    v_explicit_item_id := nullif(btrim(coalesce(v_row ->> 'inventory_item_id', '')), '')::uuid;
    v_item_code := nullif(btrim(coalesce(v_row ->> 'item_code', '')), '');
    v_description := nullif(btrim(coalesce(v_row ->> 'item_description', '')), '');
    v_brand_origin := nullif(btrim(coalesce(v_row ->> 'brand_origin', '')), '');
    v_unit := nullif(btrim(coalesce(v_row ->> 'unit', '')), '');
    v_action := lower(nullif(btrim(coalesce(v_row ->> 'stock_action', '')), ''));
    v_quantity := nullif(v_row ->> 'quantity', '')::numeric(18, 4);
    v_reason := nullif(btrim(coalesce(v_row ->> 'reason', '')), '');
    v_category_id := nullif(btrim(coalesce(v_row ->> 'category_id', '')), '')::uuid;
    v_new_category_name := nullif(btrim(coalesce(v_row ->> 'new_category_name', '')), '');
    v_source_category := nullif(btrim(coalesce(v_row ->> 'source_category_text', '')), '');
    v_minimum_stock := nullif(v_row ->> 'minimum_stock', '')::numeric(18, 4);
    v_location_bin := nullif(btrim(coalesce(v_row ->> 'location_bin', '')), '');
    v_notes := nullif(btrim(coalesce(v_row ->> 'notes', '')), '');
    if v_row_number is null or v_row_number < 1
      or v_description is null or v_unit is null or v_reason is null
      or v_action not in ('opening_balance', 'add_stock', 'remove_stock', 'no_stock_change')
      or v_quantity is null or v_quantity < 0
      or (v_minimum_stock is not null and v_minimum_stock < 0)
      or (v_action <> 'no_stock_change' and v_quantity <= 0)
      or (v_action = 'no_stock_change' and v_quantity <> 0)
      or (v_category_id is not null and v_new_category_name is not null)
      or lower(v_unit) not in (
        'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box'
      ) then
      raise exception 'V1_INVENTORY_IMPORT_ROW_INVALID:%', v_row_number
        using errcode = '22023';
    end if;

    v_item_id := v_explicit_item_id;
    if v_item_id is null and v_item_code is not null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_code)) = lower(btrim(v_item_code));
    end if;
    if v_item_id is null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_description)) = lower(btrim(v_description))
        and lower(coalesce(btrim(brand_origin), '')) = lower(coalesce(btrim(v_brand_origin), ''))
        and lower(btrim(unit)) = lower(btrim(v_unit));
    end if;

    v_created_item := false;
    if v_item_id is null then
      if v_action = 'remove_stock' then
        raise exception 'V1_INVENTORY_IMPORT_REMOVE_REQUIRES_ITEM:%', v_row_number
          using errcode = '22023';
      end if;
      if v_category_id is null and v_new_category_name is null then
        raise exception 'V1_INVENTORY_IMPORT_CATEGORY_REQUIRED:%', v_row_number
          using errcode = '22023';
      end if;
      v_category_resolution := public.v1_resolve_inventory_category(
        v_category_id, v_new_category_name, v_source_category, false
      );
      v_resolved_category_id := (v_category_resolution ->> 'id')::uuid;
      if (v_category_resolution ->> 'created')::boolean then
        v_created_categories := v_created_categories + 1;
      end if;
      v_item_id := gen_random_uuid();
      if v_item_code is null then
        v_item_code := 'INV-' || upper(substr(replace(v_item_id::text, '-', ''), 1, 8));
      end if;
      insert into public.v1_inventory_items (
        id, item_code, item_description, category_id, brand_origin, unit,
        minimum_stock, location_bin, notes, created_by_auth_user_id
      ) values (
        v_item_id, v_item_code, v_description, v_resolved_category_id,
        v_brand_origin, v_unit, v_minimum_stock, v_location_bin, v_notes, v_actor
      );
      insert into public.v1_inventory_balances (inventory_item_id)
      values (v_item_id);
      v_created_item := true;
      v_created_items := v_created_items + 1;
    else
      select balance.* into v_balance
      from public.v1_inventory_balances balance
      join public.v1_inventory_items item on item.id = balance.inventory_item_id
      where balance.inventory_item_id = v_item_id and item.is_active
      for update of balance;
      if not found then
        raise exception 'V1_INVENTORY_IMPORT_ITEM_NOT_FOUND:%', v_row_number
          using errcode = '22023';
      end if;
      if lower(v_unit) <> lower((select unit from public.v1_inventory_items where id = v_item_id))
        or lower(v_description) <> lower((select item_description from public.v1_inventory_items where id = v_item_id))
        or lower(coalesce(v_brand_origin, '')) <>
          lower(coalesce((select brand_origin from public.v1_inventory_items where id = v_item_id), ''))
        or (v_item_code is not null
          and (select item_code from public.v1_inventory_items where id = v_item_id) is not null
          and lower(v_item_code) <>
            lower((select item_code from public.v1_inventory_items where id = v_item_id))) then
        raise exception 'V1_INVENTORY_IMPORT_ITEM_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_category_id is not null or v_new_category_name is not null then
        v_category_resolution := public.v1_resolve_inventory_category(
          v_category_id, v_new_category_name, v_source_category, false
        );
        v_resolved_category_id := (v_category_resolution ->> 'id')::uuid;
        if (v_category_resolution ->> 'created')::boolean then
          v_created_categories := v_created_categories + 1;
        end if;
      else
        select category_id into v_resolved_category_id
        from public.v1_inventory_items where id = v_item_id;
      end if;
      update public.v1_inventory_items
      set item_code = coalesce(item_code, v_item_code),
          category_id = coalesce(v_resolved_category_id, category_id),
          minimum_stock = coalesce(v_minimum_stock, minimum_stock),
          location_bin = coalesce(v_location_bin, location_bin),
          notes = coalesce(v_notes, notes),
          updated_at = clock_timestamp()
      where id = v_item_id;
      v_updated_items := v_updated_items + 1;
    end if;

    select * into v_balance from public.v1_inventory_balances
    where inventory_item_id = v_item_id for update;
    select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
      into v_reserved
    from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.state in ('active', 'partially_consumed');

    v_delta := case v_action
      when 'remove_stock' then -v_quantity
      when 'no_stock_change' then 0
      else v_quantity
    end;
    if v_action = 'opening_balance' and v_balance.on_hand_qty <> 0 then
      raise exception 'V1_INVENTORY_IMPORT_OPENING_BALANCE_CONFLICT:%', v_row_number
        using errcode = '40001';
    end if;
    if v_balance.on_hand_qty + v_delta < v_reserved then
      raise exception 'V1_INVENTORY_IMPORT_BELOW_RESERVED:%', v_row_number
        using errcode = '22023';
    end if;
    if v_delta <> 0 then
      update public.v1_inventory_balances
      set on_hand_qty = on_hand_qty + v_delta,
          record_version = record_version + 1,
          updated_at = clock_timestamp()
      where inventory_item_id = v_item_id;
      v_movement_type := case when v_action = 'opening_balance'
        then 'opening_balance' else 'adjustment' end;
      insert into public.v1_inventory_movements (
        inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
        source_entity_type, source_entity_id, reason, actor_auth_user_id,
        idempotency_key
      ) values (
        v_item_id, v_movement_type, v_delta, v_balance.on_hand_qty + v_delta,
        'inventory_import', v_batch_id, v_reason, v_actor,
        gen_random_uuid()
      );
    end if;

    insert into public.v1_inventory_import_rows (
      import_batch_id, source_row_number, inventory_item_id, category_id,
      source_category_text, stock_action, quantity, reason, created_item
    ) values (
      v_batch_id, v_row_number, v_item_id, v_resolved_category_id,
      v_source_category, v_action, v_quantity, v_reason, v_created_item
    );
  end loop;

  v_response := jsonb_build_object(
    'import_batch_id', v_batch_id,
    'row_count', jsonb_array_length(v_rows),
    'created_items', v_created_items,
    'updated_items', v_updated_items,
    'created_categories', v_created_categories
  );
  perform public.v1_write_audit_event(
    'inventory_imported', 'inventory_import', v_batch_id, null, null,
    v_response, v_file_name, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_import_inventory', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_inventory_category_key(text)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_category_display_name(text)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_category_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_resolve_inventory_category(uuid,text,text,boolean)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_item_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_inventory_workspace_projection(text)
  from public, anon;
revoke all on function public.v1_create_inventory_category(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_import_inventory(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_adjust_inventory(jsonb,uuid)
  from public, anon;

grant execute on function public.v1_inventory_workspace_projection(text)
  to authenticated;
grant execute on function public.v1_create_inventory_category(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_import_inventory(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_adjust_inventory(jsonb,uuid)
  to authenticated;

-- Rollback: disable the R38.3 inventory presentation and revoke the three new
-- command/projection grants. Do not drop category/import relations or columns
-- after activity; aliases, item mappings and import rows are audit evidence.
