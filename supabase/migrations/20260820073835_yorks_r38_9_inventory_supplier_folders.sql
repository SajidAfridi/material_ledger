-- Yorks R38.9: supplier folders and supplier-receipt provenance inside the
-- single Warehouse Inventory boundary.
--
-- This migration is additive. It does not replace v1_import_inventory or
-- reinterpret an existing inventory movement. The R38.9 command writes the
-- same authoritative item/balance/movement kernel while also recording the
-- supplier, receipt batch, condition quantities, import result and immutable
-- display snapshots needed to explain where stock came from.

create or replace function public.v1_supplier_name_key(p_value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.regexp_replace(
    pg_catalog.lower(pg_catalog.btrim(p_value)), '[^[:alnum:]]+', '', 'g'
  );
$$;

create or replace function public.v1_supplier_reference_key(p_value text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select pg_catalog.lower(
    pg_catalog.regexp_replace(pg_catalog.btrim(p_value), '[[:space:]]+', ' ', 'g')
  );
$$;

-- Supplier receipts are distinct from a manual adjustment. Existing values
-- remain valid and no historical row is rewritten.
alter table public.v1_inventory_movements
  drop constraint if exists v1_inventory_movements_movement_type_check;
alter table public.v1_inventory_movements
  add constraint v1_inventory_movements_movement_type_check
  check (movement_type in (
    'opening_balance', 'adjustment', 'supplier_receipt', 'dispatch', 'return',
    'correction'
  ));

create table if not exists public.v1_suppliers (
  id uuid primary key default gen_random_uuid(),
  supplier_code text not null check (
    btrim(supplier_code) <> '' and char_length(supplier_code) <= 40
  ),
  name text not null check (btrim(name) <> '' and char_length(name) <= 180),
  normalized_name text not null check (btrim(normalized_name) <> ''),
  status text not null default 'active' check (status in (
    'active', 'review', 'inactive'
  )),
  is_system boolean not null default false,
  contact_name text check (
    contact_name is null or (btrim(contact_name) <> '' and char_length(contact_name) <= 180)
  ),
  phone text check (
    phone is null or (btrim(phone) <> '' and char_length(phone) <= 60)
  ),
  email text check (
    email is null or (
      btrim(email) <> '' and char_length(email) <= 254
      and email ~* '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$'
    )
  ),
  address text check (address is null or char_length(address) <= 1000),
  notes text check (notes is null or char_length(notes) <= 2000),
  created_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  updated_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  record_version integer not null default 1 check (record_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (id = '00000000-0000-4000-8000-000000000389'::uuid
      and supplier_code = 'SUP-UNKNOWN'
      and name = 'Unknown Supplier'
      and normalized_name = 'unknownsupplier'
      and status = 'active'
      and is_system)
    or
    (id <> '00000000-0000-4000-8000-000000000389'::uuid and not is_system)
  )
);

create unique index if not exists v1_suppliers_code_unique_idx
  on public.v1_suppliers (lower(btrim(supplier_code)));
create unique index if not exists v1_suppliers_name_unique_idx
  on public.v1_suppliers (normalized_name);
create index if not exists v1_suppliers_status_name_idx
  on public.v1_suppliers (status, name, id);

create table if not exists public.v1_supplier_aliases (
  id uuid primary key default gen_random_uuid(),
  supplier_id uuid not null references public.v1_suppliers (id)
    on delete restrict,
  alias_name text not null check (
    btrim(alias_name) <> '' and char_length(alias_name) <= 180
  ),
  normalized_alias text not null check (btrim(normalized_alias) <> ''),
  created_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (normalized_alias)
);

create index if not exists v1_supplier_aliases_supplier_idx
  on public.v1_supplier_aliases (supplier_id, alias_name, id);

create table if not exists public.v1_supplier_receipt_batches (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid not null references public.v1_inventory_import_batches (id)
    on delete restrict,
  supplier_id uuid not null references public.v1_suppliers (id)
    on delete restrict,
  supplier_code_snapshot text not null check (btrim(supplier_code_snapshot) <> ''),
  supplier_name_snapshot text not null check (btrim(supplier_name_snapshot) <> ''),
  source_type text not null check (source_type in (
    'opening_balance', 'external_supplier'
  )),
  supplier_reference text not null check (
    btrim(supplier_reference) <> '' and char_length(supplier_reference) <= 180
  ),
  normalized_reference text not null check (btrim(normalized_reference) <> ''),
  received_date date not null,
  location_bin text,
  state text not null default 'committed' check (state in (
    'committed', 'reversed'
  )),
  created_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  reversed_at timestamptz,
  reversed_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  reversal_reason text,
  check (
    (state = 'committed' and reversed_at is null
      and reversed_by_auth_user_id is null and reversal_reason is null)
    or
    (state = 'reversed' and reversed_at is not null
      and reversed_by_auth_user_id is not null
      and reversal_reason is not null and btrim(reversal_reason) <> '')
  )
);

create unique index if not exists v1_supplier_receipt_batches_reference_unique_idx
  on public.v1_supplier_receipt_batches (
    supplier_id, source_type, normalized_reference, received_date,
    coalesce(lower(btrim(location_bin)), '')
  ) where state = 'committed';
create index if not exists v1_supplier_receipt_batches_supplier_received_idx
  on public.v1_supplier_receipt_batches (supplier_id, received_date desc, id);
create index if not exists v1_supplier_receipt_batches_import_idx
  on public.v1_supplier_receipt_batches (import_batch_id, id);

create table if not exists public.v1_supplier_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_batch_id uuid not null references public.v1_supplier_receipt_batches (id)
    on delete restrict,
  inventory_item_id uuid not null references public.v1_inventory_items (id)
    on delete restrict,
  source_row_number integer not null check (source_row_number > 0),
  item_code_snapshot text,
  item_description_snapshot text not null check (btrim(item_description_snapshot) <> ''),
  category_name_snapshot text,
  size_snapshot text,
  model_tag_snapshot text,
  brand_origin_snapshot text,
  ral_colour_snapshot text,
  unit_snapshot text not null check (btrim(unit_snapshot) <> ''),
  accepted_qty numeric(18, 4) not null check (accepted_qty >= 0),
  damaged_qty numeric(18, 4) not null default 0 check (damaged_qty >= 0),
  rejected_qty numeric(18, 4) not null default 0 check (rejected_qty >= 0),
  delivered_qty numeric(18, 4) generated always as (
    accepted_qty + damaged_qty + rejected_qty
  ) stored,
  tracking_mode text not null default 'bulk' check (tracking_mode in (
    'bulk', 'batch', 'serialized'
  )),
  serial_number text,
  batch_lot_number text,
  location_bin_snapshot text,
  notes_snapshot text,
  created_at timestamptz not null default clock_timestamp(),
  unique (receipt_batch_id, source_row_number),
  check (accepted_qty + damaged_qty + rejected_qty > 0),
  check (
    (tracking_mode = 'bulk' and serial_number is null and batch_lot_number is null)
    or
    (tracking_mode = 'batch' and serial_number is null
      and batch_lot_number is not null and btrim(batch_lot_number) <> '')
    or
    (tracking_mode = 'serialized' and serial_number is not null
      and btrim(serial_number) <> '' and batch_lot_number is null
      and accepted_qty + damaged_qty + rejected_qty = 1)
  )
);

create unique index if not exists v1_supplier_receipt_lines_serial_unique_idx
  on public.v1_supplier_receipt_lines (lower(btrim(serial_number)))
  where serial_number is not null;
create index if not exists v1_supplier_receipt_lines_item_created_idx
  on public.v1_supplier_receipt_lines (inventory_item_id, created_at desc, id);

-- Commercial fields live outside the role-safe receipt relation. They can be
-- added to a projection only after a live capability check.
create table if not exists public.v1_supplier_receipt_line_commercials (
  receipt_line_id uuid primary key references public.v1_supplier_receipt_lines (id)
    on delete restrict,
  currency_code text not null default 'AED' check (
    currency_code ~ '^[A-Z]{3}$'
  ),
  unit_price numeric(18, 4) not null check (unit_price >= 0),
  created_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_inventory_import_results (
  import_batch_id uuid primary key references public.v1_inventory_import_batches (id)
    on delete restrict,
  file_sha256 text not null unique check (file_sha256 ~ '^[a-f0-9]{64}$'),
  import_mode text not null default 'strict' check (import_mode = 'strict'),
  response_json jsonb not null check (jsonb_typeof(response_json) = 'object'),
  warning_count integer not null default 0 check (warning_count >= 0),
  completed_at timestamptz not null default clock_timestamp()
);

-- Opening Balance is a one-time controlled cut-off, not an ordinary receipt.
-- A date claim prevents two alternative master workbooks for the same stock
-- cut-off from both becoming authoritative. The import-wide advisory lock
-- makes the friendly pre-check deterministic; this primary key remains the
-- database-level competing-writer guard.
create table if not exists public.v1_inventory_opening_balance_cutoffs (
  as_of_date date primary key,
  import_batch_id uuid not null unique
    references public.v1_inventory_import_batches (id) on delete restrict,
  file_sha256 text not null unique check (file_sha256 ~ '^[a-f0-9]{64}$'),
  claimed_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  claimed_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_inventory_import_row_results (
  id uuid primary key default gen_random_uuid(),
  import_batch_id uuid not null references public.v1_inventory_import_batches (id)
    on delete restrict,
  import_row_id uuid not null references public.v1_inventory_import_rows (id)
    on delete restrict,
  source_row_number integer not null check (source_row_number > 0),
  supplier_id uuid references public.v1_suppliers (id) on delete restrict,
  receipt_batch_id uuid references public.v1_supplier_receipt_batches (id)
    on delete restrict,
  receipt_line_id uuid references public.v1_supplier_receipt_lines (id)
    on delete restrict,
  source_supplier_text text,
  source_type_snapshot text,
  supplier_name_snapshot text,
  supplier_resolution_snapshot text,
  accepted_qty numeric(18, 4) not null default 0 check (accepted_qty >= 0),
  damaged_qty numeric(18, 4) not null default 0 check (damaged_qty >= 0),
  rejected_qty numeric(18, 4) not null default 0 check (rejected_qty >= 0),
  warning_codes text[] not null default '{}'::text[],
  raw_source_values jsonb not null default '{}'::jsonb
    check (jsonb_typeof(raw_source_values) = 'object'),
  created_at timestamptz not null default clock_timestamp(),
  unique (import_batch_id, source_row_number),
  unique (import_row_id),
  unique (receipt_line_id)
);

create index if not exists v1_inventory_import_row_results_supplier_idx
  on public.v1_inventory_import_row_results (supplier_id, created_at desc, id);

-- Allocation records provide the normalized bridge from a warehouse dispatch
-- to the exact committed supplier receipt lines that can prove its origin.
create table if not exists public.v1_dispatch_batch_allocations (
  id uuid primary key default gen_random_uuid(),
  dispatch_line_id uuid not null references public.v1_material_dispatch_lines (id)
    on delete restrict,
  receipt_line_id uuid not null references public.v1_supplier_receipt_lines (id)
    on delete restrict,
  allocated_qty numeric(18, 4) not null check (allocated_qty > 0),
  allocation_method text not null default 'fifo' check (allocation_method in (
    'fifo', 'manual'
  )),
  override_reason text,
  allocated_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (dispatch_line_id, receipt_line_id),
  check (
    (allocation_method = 'fifo' and override_reason is null)
    or
    (allocation_method = 'manual' and override_reason is not null
      and btrim(override_reason) <> '')
  )
);

create index if not exists v1_dispatch_batch_allocations_receipt_idx
  on public.v1_dispatch_batch_allocations (receipt_line_id, created_at, id);

-- Legacy stock can pre-date R38.9 receipt provenance. It must remain
-- dispatchable, but the system records the unprovable remainder explicitly
-- instead of fabricating a supplier or receipt batch.
create table if not exists public.v1_dispatch_batch_allocation_gaps (
  dispatch_line_id uuid primary key
    references public.v1_material_dispatch_lines (id) on delete restrict,
  unallocated_qty numeric(18, 4) not null check (unallocated_qty > 0),
  reason_code text not null default 'legacy_or_unproven_stock'
    check (reason_code = 'legacy_or_unproven_stock'),
  recorded_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

-- Receipt review quantities are dispatch-line facts. Persisting their
-- deterministic apportionment prevents a multi-batch dispatch from repeating
-- the whole good/exception quantity on every supplier allocation.
create table if not exists public.v1_dispatch_batch_receipt_allocations (
  id uuid primary key default gen_random_uuid(),
  receipt_review_line_id uuid not null
    references public.v1_receipt_review_lines (id) on delete restrict,
  dispatch_allocation_id uuid not null
    references public.v1_dispatch_batch_allocations (id) on delete restrict,
  good_qty numeric(18, 4) not null default 0 check (good_qty >= 0),
  exception_qty numeric(18, 4) not null default 0 check (exception_qty >= 0),
  attribution_method text not null default 'deterministic_fifo'
    check (attribution_method = 'deterministic_fifo'),
  created_at timestamptz not null default clock_timestamp(),
  unique (receipt_review_line_id, dispatch_allocation_id),
  check (good_qty + exception_qty > 0)
);

-- Any reviewed quantity whose source cannot be proven remains an explicit
-- line-level gap. It is never assigned to a supplier or receipt batch.
create table if not exists public.v1_dispatch_batch_receipt_gaps (
  id uuid primary key default gen_random_uuid(),
  receipt_review_line_id uuid not null unique
    references public.v1_receipt_review_lines (id) on delete restrict,
  dispatch_line_id uuid not null
    references public.v1_material_dispatch_lines (id) on delete restrict,
  good_qty numeric(18, 4) not null default 0 check (good_qty >= 0),
  exception_qty numeric(18, 4) not null default 0 check (exception_qty >= 0),
  reason_code text not null default 'legacy_or_unproven_stock'
    check (reason_code = 'legacy_or_unproven_stock'),
  created_at timestamptz not null default clock_timestamp(),
  check (good_qty + exception_qty > 0)
);

-- Confirmed returns are attributed exactly once to the good-received source
-- allocations. Reverse FIFO mirrors the physical return path while retaining
-- every immutable allocation fact for audit and future re-dispatch.
create table if not exists public.v1_material_return_batch_allocations (
  id uuid primary key default gen_random_uuid(),
  material_return_line_id uuid not null
    references public.v1_material_return_lines (id) on delete restrict,
  receipt_attribution_id uuid not null
    references public.v1_dispatch_batch_receipt_allocations (id)
    on delete restrict,
  returned_qty numeric(18, 4) not null check (returned_qty > 0),
  attribution_method text not null default 'reverse_fifo'
    check (attribution_method = 'reverse_fifo'),
  confirmed_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique (material_return_line_id, receipt_attribution_id)
);

-- A returned quantity that originated in an unproven dispatch gap stays
-- unproven after warehouse receipt. It can increase stock through the existing
-- return command, but cannot manufacture supplier provenance.
create table if not exists public.v1_material_return_batch_allocation_gaps (
  id uuid primary key default gen_random_uuid(),
  material_return_line_id uuid not null unique
    references public.v1_material_return_lines (id) on delete restrict,
  receipt_gap_id uuid not null
    references public.v1_dispatch_batch_receipt_gaps (id) on delete restrict,
  returned_qty numeric(18, 4) not null check (returned_qty > 0),
  reason_code text not null default 'legacy_or_unproven_stock'
    check (reason_code = 'legacy_or_unproven_stock'),
  confirmed_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists v1_dispatch_batch_receipt_allocations_dispatch_idx
  on public.v1_dispatch_batch_receipt_allocations (
    dispatch_allocation_id, receipt_review_line_id, id
  );
create index if not exists v1_material_return_batch_allocations_receipt_idx
  on public.v1_material_return_batch_allocations (
    receipt_attribution_id, material_return_line_id, id
  );

alter table public.v1_suppliers enable row level security;
alter table public.v1_supplier_aliases enable row level security;
alter table public.v1_supplier_receipt_batches enable row level security;
alter table public.v1_supplier_receipt_lines enable row level security;
alter table public.v1_supplier_receipt_line_commercials enable row level security;
alter table public.v1_inventory_import_results enable row level security;
alter table public.v1_inventory_opening_balance_cutoffs enable row level security;
alter table public.v1_inventory_import_row_results enable row level security;
alter table public.v1_dispatch_batch_allocations enable row level security;
alter table public.v1_dispatch_batch_allocation_gaps enable row level security;
alter table public.v1_dispatch_batch_receipt_allocations enable row level security;
alter table public.v1_dispatch_batch_receipt_gaps enable row level security;
alter table public.v1_material_return_batch_allocations enable row level security;
alter table public.v1_material_return_batch_allocation_gaps enable row level security;

revoke all on table public.v1_suppliers from public, anon, authenticated;
revoke all on table public.v1_supplier_aliases from public, anon, authenticated;
revoke all on table public.v1_supplier_receipt_batches from public, anon, authenticated;
revoke all on table public.v1_supplier_receipt_lines from public, anon, authenticated;
revoke all on table public.v1_supplier_receipt_line_commercials from public, anon, authenticated;
revoke all on table public.v1_inventory_import_results from public, anon, authenticated;
revoke all on table public.v1_inventory_opening_balance_cutoffs from public, anon, authenticated;
revoke all on table public.v1_inventory_import_row_results from public, anon, authenticated;
revoke all on table public.v1_dispatch_batch_allocations from public, anon, authenticated;
revoke all on table public.v1_dispatch_batch_allocation_gaps from public, anon, authenticated;
revoke all on table public.v1_dispatch_batch_receipt_allocations
  from public, anon, authenticated;
revoke all on table public.v1_dispatch_batch_receipt_gaps
  from public, anon, authenticated;
revoke all on table public.v1_material_return_batch_allocations
  from public, anon, authenticated;
revoke all on table public.v1_material_return_batch_allocation_gaps
  from public, anon, authenticated;

grant all on table public.v1_suppliers to service_role;
grant all on table public.v1_supplier_aliases to service_role;
grant all on table public.v1_supplier_receipt_batches to service_role;
grant all on table public.v1_supplier_receipt_lines to service_role;
grant all on table public.v1_supplier_receipt_line_commercials to service_role;
grant all on table public.v1_inventory_import_results to service_role;
grant all on table public.v1_inventory_opening_balance_cutoffs to service_role;
grant all on table public.v1_inventory_import_row_results to service_role;
grant all on table public.v1_dispatch_batch_allocations to service_role;
grant all on table public.v1_dispatch_batch_allocation_gaps to service_role;
grant all on table public.v1_dispatch_batch_receipt_allocations to service_role;
grant all on table public.v1_dispatch_batch_receipt_gaps to service_role;
grant all on table public.v1_material_return_batch_allocations to service_role;
grant all on table public.v1_material_return_batch_allocation_gaps to service_role;

create or replace function public.v1_allocate_dispatch_line_fifo_r38_9()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
  v_remaining numeric(18, 4) := new.dispatched_qty;
  v_already_allocated numeric(18, 4);
  v_available numeric(18, 4);
  v_take numeric(18, 4);
  v_receipt record;
begin
  if new.source_kind <> 'warehouse' or new.inventory_item_id is null then
    return new;
  end if;

  select dispatch.dispatched_by_auth_user_id
    into v_actor
  from public.v1_material_dispatches dispatch
  where dispatch.id = new.dispatch_id;

  if v_actor is null then
    raise exception 'V1_DISPATCH_ALLOCATION_ACTOR_MISSING'
      using errcode = '23503';
  end if;

  -- Receipt-line locks are acquired in one stable order. After each lock, the
  -- allocated total is re-read in a separate statement so a waiting dispatcher
  -- observes the allocation committed by the transaction that held the lock.
  for v_receipt in
    select receipt_line.id, receipt_line.accepted_qty
    from public.v1_supplier_receipt_lines receipt_line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where receipt_line.inventory_item_id = new.inventory_item_id
      and receipt_line.accepted_qty > 0
      and receipt_batch.state = 'committed'
    order by receipt_batch.received_date, receipt_batch.created_at,
      receipt_batch.id, receipt_line.created_at, receipt_line.id
    for update of receipt_line
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(
      allocation.allocated_qty - coalesce(returned.returned_qty, 0)
    ), 0)
      into v_already_allocated
    from public.v1_dispatch_batch_allocations allocation
    left join lateral (
      select sum(return_allocation.returned_qty) returned_qty
      from public.v1_material_return_batch_allocations return_allocation
      join public.v1_dispatch_batch_receipt_allocations receipt_attribution
        on receipt_attribution.id = return_allocation.receipt_attribution_id
      where receipt_attribution.dispatch_allocation_id = allocation.id
    ) returned on true
    where allocation.receipt_line_id = v_receipt.id;

    v_available := greatest(
      v_receipt.accepted_qty - v_already_allocated, 0
    );
    v_take := least(v_remaining, v_available);
    if v_take > 0 then
      insert into public.v1_dispatch_batch_allocations (
        dispatch_line_id, receipt_line_id, allocated_qty,
        allocation_method, allocated_by_auth_user_id
      ) values (
        new.id, v_receipt.id, v_take, 'fifo', v_actor
      );
      v_remaining := v_remaining - v_take;
    end if;
  end loop;

  if v_remaining > 0 then
    insert into public.v1_dispatch_batch_allocation_gaps (
      dispatch_line_id, unallocated_qty, reason_code,
      recorded_by_auth_user_id
    ) values (
      new.id, v_remaining, 'legacy_or_unproven_stock', v_actor
    );
  end if;
  return new;
end;
$$;

revoke all on function public.v1_allocate_dispatch_line_fifo_r38_9()
  from public, anon, authenticated;

drop trigger if exists v1_allocate_dispatch_line_fifo_r38_9
  on public.v1_material_dispatch_lines;
create trigger v1_allocate_dispatch_line_fifo_r38_9
  after insert on public.v1_material_dispatch_lines
  for each row execute function public.v1_allocate_dispatch_line_fifo_r38_9();

-- Persist one deterministic good/exception split for a confirmed review line.
-- Existing command and row locks remain authoritative; this helper is internal
-- and can only be reached through the trigger/backfill below.
create or replace function public.v1_attribute_receipt_review_line_r38_9(
  p_receipt_review_line_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review_line public.v1_receipt_review_lines%rowtype;
  v_dispatch_line public.v1_material_dispatch_lines%rowtype;
  v_allocation record;
  v_good_remaining numeric(18, 4);
  v_exception_remaining numeric(18, 4);
  v_good_take numeric(18, 4);
  v_exception_take numeric(18, 4);
  v_capacity numeric(18, 4);
  v_existing_total numeric(18, 4);
begin
  if p_receipt_review_line_id is null then
    raise exception 'V1_RECEIPT_PROVENANCE_ARGUMENT_INVALID'
      using errcode = '22023';
  end if;

  select receipt_review_line.* into v_review_line
  from public.v1_receipt_review_lines receipt_review_line
  where receipt_review_line.id = p_receipt_review_line_id
  for update;
  if not found then
    raise exception 'V1_RECEIPT_PROVENANCE_REVIEW_LINE_NOT_FOUND'
      using errcode = '22023';
  end if;

  select dispatch_line.* into v_dispatch_line
  from public.v1_material_dispatch_lines dispatch_line
  where dispatch_line.id = v_review_line.dispatch_line_id;
  if not found then
    raise exception 'V1_RECEIPT_PROVENANCE_DISPATCH_LINE_NOT_FOUND'
      using errcode = '22023';
  end if;
  if v_dispatch_line.source_kind <> 'warehouse'
    or v_dispatch_line.inventory_item_id is null then
    return;
  end if;

  select coalesce(sum(receipt_attribution.good_qty
      + receipt_attribution.exception_qty), 0)
      + coalesce((
        select receipt_gap.good_qty + receipt_gap.exception_qty
        from public.v1_dispatch_batch_receipt_gaps receipt_gap
        where receipt_gap.receipt_review_line_id = v_review_line.id
      ), 0)
    into v_existing_total
  from public.v1_dispatch_batch_receipt_allocations receipt_attribution
  where receipt_attribution.receipt_review_line_id = v_review_line.id;
  if v_existing_total > 0 then
    if v_existing_total <> v_review_line.dispatched_qty_snapshot then
      raise exception 'V1_RECEIPT_PROVENANCE_FACTS_INCONSISTENT'
        using errcode = '23514';
    end if;
    return;
  end if;

  v_good_remaining := v_review_line.good_qty;
  v_exception_remaining := v_review_line.exception_qty;
  for v_allocation in
    select allocation.id, allocation.allocated_qty
    from public.v1_dispatch_batch_allocations allocation
    where allocation.dispatch_line_id = v_review_line.dispatch_line_id
    order by allocation.created_at, allocation.id
    for update
  loop
    v_good_take := least(v_good_remaining, v_allocation.allocated_qty);
    v_capacity := v_allocation.allocated_qty - v_good_take;
    v_exception_take := least(v_exception_remaining, v_capacity);
    if v_good_take + v_exception_take > 0 then
      insert into public.v1_dispatch_batch_receipt_allocations (
        receipt_review_line_id, dispatch_allocation_id, good_qty,
        exception_qty, attribution_method
      ) values (
        v_review_line.id, v_allocation.id, v_good_take,
        v_exception_take, 'deterministic_fifo'
      );
    end if;
    v_good_remaining := v_good_remaining - v_good_take;
    v_exception_remaining := v_exception_remaining - v_exception_take;
  end loop;

  if v_good_remaining + v_exception_remaining > 0 then
    insert into public.v1_dispatch_batch_receipt_gaps (
      receipt_review_line_id, dispatch_line_id, good_qty, exception_qty,
      reason_code
    ) values (
      v_review_line.id, v_review_line.dispatch_line_id, v_good_remaining,
      v_exception_remaining, 'legacy_or_unproven_stock'
    );
  end if;

  select coalesce(sum(receipt_attribution.good_qty
      + receipt_attribution.exception_qty), 0)
      + coalesce((
        select receipt_gap.good_qty + receipt_gap.exception_qty
        from public.v1_dispatch_batch_receipt_gaps receipt_gap
        where receipt_gap.receipt_review_line_id = v_review_line.id
      ), 0)
    into v_existing_total
  from public.v1_dispatch_batch_receipt_allocations receipt_attribution
  where receipt_attribution.receipt_review_line_id = v_review_line.id;
  if v_existing_total <> v_review_line.dispatched_qty_snapshot then
    raise exception 'V1_RECEIPT_PROVENANCE_QTY_MISMATCH'
      using errcode = '23514';
  end if;
end;
$$;

create or replace function public.v1_attribute_receipt_review_line_trigger_r38_9()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_attribute_receipt_review_line_r38_9(new.id);
  return new;
end;
$$;

revoke all on function public.v1_attribute_receipt_review_line_r38_9(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_attribute_receipt_review_line_trigger_r38_9()
  from public, anon, authenticated;

drop trigger if exists v1_attribute_receipt_review_line_r38_9
  on public.v1_receipt_review_lines;
create trigger v1_attribute_receipt_review_line_r38_9
  after insert on public.v1_receipt_review_lines
  for each row execute function
    public.v1_attribute_receipt_review_line_trigger_r38_9();

-- Attribute a confirmed warehouse return against only the apportioned good
-- receipt quantity. The newest source allocation is consumed first. Any
-- remaining provable-good legacy gap stays explicit and supplier-free.
create or replace function public.v1_attribute_material_return_r38_9(
  p_material_return_id uuid,
  p_actor_auth_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_return public.v1_material_returns%rowtype;
  v_return_line public.v1_material_return_lines%rowtype;
  v_receipt_attribution record;
  v_receipt_gap public.v1_dispatch_batch_receipt_gaps%rowtype;
  v_remaining numeric(18, 4);
  v_previously_returned numeric(18, 4);
  v_available numeric(18, 4);
  v_take numeric(18, 4);
  v_existing_total numeric(18, 4);
begin
  if p_material_return_id is null or p_actor_auth_user_id is null then
    raise exception 'V1_RETURN_PROVENANCE_ARGUMENT_INVALID'
      using errcode = '22023';
  end if;
  select material_return.* into v_return
  from public.v1_material_returns material_return
  where material_return.id = p_material_return_id
  for update;
  if not found or v_return.state not in ('submitted', 'confirmed') then
    raise exception 'V1_RETURN_PROVENANCE_STATE_INVALID'
      using errcode = '22023';
  end if;

  for v_return_line in
    select return_line.*
    from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.id
    for update
  loop
    if v_return_line.source_kind <> 'warehouse' then
      continue;
    end if;

    perform public.v1_attribute_receipt_review_line_r38_9(
      v_return_line.receipt_review_line_id
    );
    select coalesce(sum(return_attribution.returned_qty), 0)
        + coalesce((
          select return_gap.returned_qty
          from public.v1_material_return_batch_allocation_gaps return_gap
          where return_gap.material_return_line_id = v_return_line.id
        ), 0)
      into v_existing_total
    from public.v1_material_return_batch_allocations return_attribution
    where return_attribution.material_return_line_id = v_return_line.id;
    if v_existing_total > 0 then
      if v_existing_total <> v_return_line.return_quantity then
        raise exception 'V1_RETURN_PROVENANCE_FACTS_INCONSISTENT'
          using errcode = '23514';
      end if;
      continue;
    end if;

    v_remaining := v_return_line.return_quantity;
    for v_receipt_attribution in
      select receipt_attribution.id, receipt_attribution.good_qty,
        allocation.created_at allocation_created_at, allocation.id allocation_id
      from public.v1_dispatch_batch_receipt_allocations receipt_attribution
      join public.v1_dispatch_batch_allocations allocation
        on allocation.id = receipt_attribution.dispatch_allocation_id
      where receipt_attribution.receipt_review_line_id =
        v_return_line.receipt_review_line_id
      order by allocation.created_at desc, allocation.id desc
      for update of receipt_attribution
    loop
      exit when v_remaining <= 0;
      select coalesce(sum(return_attribution.returned_qty), 0)
        into v_previously_returned
      from public.v1_material_return_batch_allocations return_attribution
      where return_attribution.receipt_attribution_id =
        v_receipt_attribution.id;
      v_available := greatest(
        v_receipt_attribution.good_qty - v_previously_returned, 0
      );
      v_take := least(v_remaining, v_available);
      if v_take > 0 then
        insert into public.v1_material_return_batch_allocations (
          material_return_line_id, receipt_attribution_id, returned_qty,
          attribution_method, confirmed_by_auth_user_id
        ) values (
          v_return_line.id, v_receipt_attribution.id, v_take,
          'reverse_fifo', p_actor_auth_user_id
        );
        v_remaining := v_remaining - v_take;
      end if;
    end loop;

    if v_remaining > 0 then
      select receipt_gap.* into v_receipt_gap
      from public.v1_dispatch_batch_receipt_gaps receipt_gap
      where receipt_gap.receipt_review_line_id =
        v_return_line.receipt_review_line_id
      for update;
      if found then
        select coalesce(sum(return_gap.returned_qty), 0)
          into v_previously_returned
        from public.v1_material_return_batch_allocation_gaps return_gap
        where return_gap.receipt_gap_id = v_receipt_gap.id;
        v_available := greatest(
          v_receipt_gap.good_qty - v_previously_returned, 0
        );
        v_take := least(v_remaining, v_available);
        if v_take > 0 then
          insert into public.v1_material_return_batch_allocation_gaps (
            material_return_line_id, receipt_gap_id, returned_qty,
            reason_code, confirmed_by_auth_user_id
          ) values (
            v_return_line.id, v_receipt_gap.id, v_take,
            'legacy_or_unproven_stock', p_actor_auth_user_id
          );
          v_remaining := v_remaining - v_take;
        end if;
      end if;
    end if;

    if v_remaining > 0 then
      raise exception 'V1_RETURN_PROVENANCE_GOOD_QTY_EXCEEDED'
        using errcode = '22023';
    end if;
  end loop;
end;
$$;

create or replace function public.v1_attribute_material_return_trigger_r38_9()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state = 'submitted' and new.state = 'confirmed' then
    perform public.v1_attribute_material_return_r38_9(
      new.id, new.decided_by_auth_user_id
    );
  end if;
  return new;
end;
$$;

revoke all on function public.v1_attribute_material_return_r38_9(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_attribute_material_return_trigger_r38_9()
  from public, anon, authenticated;

drop trigger if exists v1_attribute_material_return_r38_9
  on public.v1_material_returns;
create trigger v1_attribute_material_return_r38_9
  before update of state on public.v1_material_returns
  for each row execute function public.v1_attribute_material_return_trigger_r38_9();

-- Conservative backfill: rows without R38.9 dispatch provenance remain gap
-- facts. No historical supplier identity is inferred.
do $r38_9_provenance_backfill$
declare
  v_review_line_id uuid;
  v_return record;
begin
  for v_review_line_id in
    select receipt_review_line.id
    from public.v1_receipt_review_lines receipt_review_line
    join public.v1_material_dispatch_lines dispatch_line
      on dispatch_line.id = receipt_review_line.dispatch_line_id
    where dispatch_line.source_kind = 'warehouse'
    order by receipt_review_line.id
  loop
    perform public.v1_attribute_receipt_review_line_r38_9(v_review_line_id);
  end loop;
  for v_return in
    select material_return.id, material_return.decided_by_auth_user_id
    from public.v1_material_returns material_return
    where material_return.state = 'confirmed'
    order by material_return.id
  loop
    perform public.v1_attribute_material_return_r38_9(
      v_return.id, v_return.decided_by_auth_user_id
    );
  end loop;
end;
$r38_9_provenance_backfill$;

insert into public.v1_suppliers (
  id, supplier_code, name, normalized_name, status, is_system,
  created_by_auth_user_id, updated_by_auth_user_id
)
values (
  '00000000-0000-4000-8000-000000000389',
  'SUP-UNKNOWN',
  'Unknown Supplier',
  'unknownsupplier',
  'active',
  true,
  null,
  null
)
on conflict (id) do nothing;

create or replace function public.v1_protect_unknown_supplier()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.id = '00000000-0000-4000-8000-000000000389'::uuid then
    raise exception 'V1_UNKNOWN_SUPPLIER_IMMUTABLE' using errcode = '42501';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists v1_suppliers_protect_unknown_trigger on public.v1_suppliers;
create trigger v1_suppliers_protect_unknown_trigger
before update or delete on public.v1_suppliers
for each row execute function public.v1_protect_unknown_supplier();

-- Internal exact-resolution helper. A missing supplier is intentionally mapped
-- to the one system folder. A nonblank name must be an exact canonical/alias
-- match or accompany an explicit new-supplier decision; similarity never
-- becomes transaction authority.
create or replace function public.v1_resolve_inventory_supplier_r38_9(
  p_supplier_id uuid,
  p_new_supplier_name text,
  p_source_supplier_text text,
  p_import_batch_id uuid default null,
  p_source_row_number integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_supplier public.v1_suppliers%rowtype;
  v_name text := nullif(btrim(coalesce(p_new_supplier_name, '')), '');
  v_source text := nullif(btrim(coalesce(p_source_supplier_text, '')), '');
  v_key text;
  v_source_key text;
  v_created boolean := false;
  v_alias_added boolean := false;
  v_conflicting_supplier_id uuid;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_RESOLUTION_DENIED' using errcode = '42501';
  end if;
  if p_supplier_id is not null and v_name is not null then
    raise exception 'V1_SUPPLIER_DECISION_AMBIGUOUS' using errcode = '22023';
  end if;
  if v_source is not null then
    v_source_key := public.v1_supplier_name_key(v_source);
  end if;

  if p_supplier_id is not null then
    select * into v_supplier from public.v1_suppliers
    where id = p_supplier_id and status = 'active'
    for update;
    if not found then
      raise exception 'V1_SUPPLIER_NOT_FOUND_OR_INACTIVE' using errcode = '22023';
    end if;
  elsif v_name is not null then
    if char_length(v_name) > 180 then
      raise exception 'V1_SUPPLIER_NAME_INVALID' using errcode = '22023';
    end if;
    v_key := public.v1_supplier_name_key(v_name);
    if v_key = '' or v_key in ('unknown', 'unknownsupplier', 'na') then
      raise exception 'V1_SUPPLIER_NAME_RESERVED' using errcode = '22023';
    end if;
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('v1_supplier:' || v_key, 0)
    );
    select * into v_supplier from public.v1_suppliers
    where normalized_name = v_key and status = 'active'
    for update;
    if not found then
      select alias.supplier_id into v_conflicting_supplier_id
      from public.v1_supplier_aliases alias
      where alias.normalized_alias = v_key;
      if found then
        raise exception 'V1_SUPPLIER_NEW_NAME_MATCHES_EXISTING_ALIAS'
          using errcode = '22023';
      end if;
      v_supplier.id := gen_random_uuid();
      v_supplier.supplier_code :=
        'SUP-' || upper(substr(replace(v_supplier.id::text, '-', ''), 1, 8));
      v_supplier.name := v_name;
      v_supplier.normalized_name := v_key;
      v_supplier.status := 'active';
      v_supplier.is_system := false;
      insert into public.v1_suppliers (
        id, supplier_code, name, normalized_name, status, is_system,
        created_by_auth_user_id, updated_by_auth_user_id
      ) values (
        v_supplier.id, v_supplier.supplier_code, v_supplier.name,
        v_supplier.normalized_name, 'active', false, v_actor, v_actor
      );
      v_created := true;
    end if;
  elsif v_source is null
    or v_source_key in ('unknown', 'unknownsupplier', 'na') then
    select * into v_supplier from public.v1_suppliers
    where id = '00000000-0000-4000-8000-000000000389'::uuid;
  else
    select supplier_record.* into v_supplier
    from public.v1_suppliers supplier_record
    where supplier_record.normalized_name = v_source_key
      and supplier_record.status = 'active';
    if not found then
      select supplier_record.* into v_supplier
      from public.v1_supplier_aliases alias
      join public.v1_suppliers supplier_record
        on supplier_record.id = alias.supplier_id
      where alias.normalized_alias = v_source_key
        and supplier_record.status = 'active';
    end if;
    if not found then
      raise exception 'V1_SUPPLIER_DECISION_REQUIRED:%', left(v_source, 120)
        using errcode = '22023';
    end if;
  end if;

  -- An explicit supplier decision also explicitly approves the workbook text
  -- as an alias, provided it cannot collide with another canonical identity.
  if v_source is not null
    and v_source_key not in ('unknown', 'unknownsupplier', 'na')
    and (p_supplier_id is not null or v_name is not null) then
    if v_source_key <> v_supplier.normalized_name then
      select id into v_conflicting_supplier_id from public.v1_suppliers
      where normalized_name = v_source_key and id <> v_supplier.id;
      if found then
        raise exception 'V1_SUPPLIER_ALIAS_CONFLICTS_WITH_CANONICAL_NAME'
          using errcode = '22023';
      end if;
      select supplier_id into v_conflicting_supplier_id
      from public.v1_supplier_aliases
      where normalized_alias = v_source_key;
      if found and v_conflicting_supplier_id <> v_supplier.id then
        raise exception 'V1_SUPPLIER_ALIAS_CONFLICT'
          using errcode = '22023';
      elsif not found then
        insert into public.v1_supplier_aliases (
          supplier_id, alias_name, normalized_alias, created_by_auth_user_id
        ) values (v_supplier.id, v_source, v_source_key, v_actor);
        v_alias_added := true;
      end if;
    end if;
  end if;

  if v_created then
    perform public.v1_write_audit_event(
      'supplier_created', 'supplier', v_supplier.id, null, null,
      jsonb_build_object(
        'supplier_code', v_supplier.supplier_code,
        'canonical_name', v_supplier.name,
        'import_batch_id', p_import_batch_id,
        'source_row_number', p_source_row_number,
        'creation_source', 'inventory_import'
      ), 'Supplier created from reviewed Inventory import', gen_random_uuid()
    );
  end if;
  if v_source is not null
    and (p_supplier_id is not null or v_name is not null) then
    perform public.v1_write_audit_event(
      'supplier_mapping_accepted', 'supplier', v_supplier.id, null, null,
      jsonb_build_object(
        'source_supplier_text', v_source,
        'normalized_source_supplier_text', v_source_key,
        'canonical_supplier_name', v_supplier.name,
        'alias_added', v_alias_added,
        'import_batch_id', p_import_batch_id,
        'source_row_number', p_source_row_number
      ), 'Supplier mapping accepted during reviewed Inventory import',
      gen_random_uuid()
    );
  end if;

  return jsonb_build_object(
    'id', v_supplier.id,
    'supplier_code', v_supplier.supplier_code,
    'name', v_supplier.name,
    'created', v_created,
    'alias_added', v_alias_added,
    'used_unknown',
      v_supplier.id = '00000000-0000-4000-8000-000000000389'::uuid
  );
end;
$$;

create or replace function public.v1_create_supplier(
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
  v_name text;
  v_key text;
  v_code text;
  v_contact_name text;
  v_phone text;
  v_email text;
  v_address text;
  v_notes text;
  v_aliases jsonb;
  v_alias jsonb;
  v_alias_name text;
  v_alias_key text;
  v_supplier_id uuid := gen_random_uuid();
  v_conflict uuid;
  v_response jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_CREATE_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array['canonical_name', 'description', 'aliases'],
    'create_supplier'
  );
  v_name := nullif(btrim(coalesce(p_payload ->> 'canonical_name', '')), '');
  v_notes := nullif(btrim(coalesce(p_payload ->> 'description', '')), '');
  v_aliases := coalesce(p_payload -> 'aliases', '[]'::jsonb);
  if v_name is null or char_length(v_name) > 180
    or (v_notes is not null and char_length(v_notes) > 2000)
    or jsonb_typeof(v_aliases) <> 'array'
    or jsonb_array_length(v_aliases) > 50 then
    raise exception 'V1_SUPPLIER_CREATE_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_key := public.v1_supplier_name_key(v_name);
  if v_key = '' or v_key in ('unknown', 'unknownsupplier', 'na') then
    raise exception 'V1_SUPPLIER_NAME_RESERVED' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_supplier', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('v1_supplier:' || v_key, 0)
  );
  if exists(select 1 from public.v1_suppliers where normalized_name = v_key)
    or exists(select 1 from public.v1_supplier_aliases where normalized_alias = v_key) then
    raise exception 'V1_SUPPLIER_ALREADY_EXISTS' using errcode = '23505';
  end if;
  v_code := 'SUP-' || upper(substr(replace(v_supplier_id::text, '-', ''), 1, 8));

  insert into public.v1_suppliers (
    id, supplier_code, name, normalized_name, contact_name, phone, email,
    address, notes, created_by_auth_user_id, updated_by_auth_user_id
  ) values (
    v_supplier_id, v_code, v_name, v_key, v_contact_name, v_phone, v_email,
    v_address, v_notes, v_actor, v_actor
  );

  for v_alias in select value from jsonb_array_elements(v_aliases)
  loop
    if jsonb_typeof(v_alias) <> 'string' then
      raise exception 'V1_SUPPLIER_ALIAS_INVALID' using errcode = '22023';
    end if;
    v_alias_name := nullif(btrim(v_alias #>> '{}'), '');
    if v_alias_name is null or char_length(v_alias_name) > 180 then
      raise exception 'V1_SUPPLIER_ALIAS_INVALID' using errcode = '22023';
    end if;
    v_alias_key := public.v1_supplier_name_key(v_alias_name);
    if v_alias_key = '' or v_alias_key in ('unknown', 'unknownsupplier', 'na')
      or v_alias_key = v_key
      or exists(select 1 from public.v1_suppliers where normalized_name = v_alias_key) then
      raise exception 'V1_SUPPLIER_ALIAS_CONFLICT' using errcode = '22023';
    end if;
    select supplier_id into v_conflict from public.v1_supplier_aliases
    where normalized_alias = v_alias_key;
    if found and v_conflict <> v_supplier_id then
      raise exception 'V1_SUPPLIER_ALIAS_CONFLICT' using errcode = '22023';
    elsif not found then
      insert into public.v1_supplier_aliases (
        supplier_id, alias_name, normalized_alias, created_by_auth_user_id
      ) values (v_supplier_id, v_alias_name, v_alias_key, v_actor);
    end if;
  end loop;

  select jsonb_build_object(
    'id', supplier_record.id,
    'supplier_code', supplier_record.supplier_code,
    'canonical_name', supplier_record.name,
    'description', supplier_record.notes,
    'status', supplier_record.status,
    'is_system_unknown', false,
    'receipt_batch_count', '0',
    'distinct_item_count', '0',
    'missing_document_count', '0',
    'reconciliation_count', '0',
    'last_receipt_at', null,
    'aliases', coalesce((
      select jsonb_agg(alias.alias_name order by alias.alias_name, alias.id)
      from public.v1_supplier_aliases alias
      where alias.supplier_id = supplier_record.id
    ), '[]'::jsonb),
    'record_version', supplier_record.record_version::text
  ) into v_response
  from public.v1_suppliers supplier_record
  where supplier_record.id = v_supplier_id;

  perform public.v1_write_audit_event(
    'supplier_created', 'supplier', v_supplier_id, null, null,
    v_response, 'Supplier master created', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_supplier', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Reconciliation is a row/evidence count, never a receipt-batch count. One
-- Opening Balance batch can contain thousands of unresolved source rows.
create or replace function public.v1_supplier_reconciliation_count_r38_9(
  p_supplier_id uuid
)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from (
    select 'row:' || row_result.id::text evidence_key
    from public.v1_inventory_import_row_results row_result
    where row_result.supplier_id = p_supplier_id
    union all
    select 'line:' || receipt_line.id::text
    from public.v1_supplier_receipt_lines receipt_line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where receipt_batch.supplier_id = p_supplier_id
      and not exists(
        select 1
        from public.v1_inventory_import_row_results row_result
        where row_result.receipt_line_id = receipt_line.id
      )
  ) evidence;
$$;

revoke all on function public.v1_supplier_reconciliation_count_r38_9(uuid)
  from public, anon, authenticated;

create or replace function public.v1_supplier_directory_projection(
  p_search text,
  p_status text,
  p_limit integer,
  p_offset integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_status text := lower(coalesce(nullif(btrim(p_status), ''), 'all'));
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_total integer;
  v_suppliers jsonb;
  v_summary jsonb;
  v_unit_totals jsonb := '[]'::jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_DIRECTORY_DENIED' using errcode = '42501';
  end if;
  if v_status not in ('all', 'active', 'review', 'inactive', 'identity_missing')
    or v_limit < 1 or v_limit > 100
    or v_offset < 0 or v_offset > 100000
    or (v_search is not null and char_length(v_search) > 120) then
    raise exception 'V1_SUPPLIER_DIRECTORY_ARGUMENT_INVALID'
      using errcode = '22023';
  end if;

  select count(*)::integer into v_total
  from public.v1_suppliers supplier
  where (
      v_status = 'all'
      or (v_status = 'identity_missing' and supplier.is_system)
      or (v_status <> 'identity_missing' and not supplier.is_system
        and supplier.status = v_status)
    )
    and (
      v_search is null
      or supplier.name ilike '%' || v_search || '%'
      or supplier.supplier_code ilike '%' || v_search || '%'
      or exists(
        select 1 from public.v1_supplier_aliases alias
        where alias.supplier_id = supplier.id
          and alias.alias_name ilike '%' || v_search || '%'
      )
      or exists(
        select 1 from public.v1_supplier_receipt_batches receipt_batch
        where receipt_batch.supplier_id = supplier.id
          and receipt_batch.supplier_reference ilike '%' || v_search || '%'
      )
    );

  select jsonb_build_object(
    'active_suppliers', count(*) filter (
      where status = 'active' and not is_system
    )::text,
    'receipt_batches', (
      select count(*)::text from public.v1_supplier_receipt_batches batch
      where batch.state = 'committed'
    ),
    'distinct_items', (
      select count(distinct line.inventory_item_id)::text
      from public.v1_supplier_receipt_lines line
      join public.v1_supplier_receipt_batches batch
        on batch.id = line.receipt_batch_id
      where batch.state = 'committed'
    ),
    'documents_missing', (
      select count(*)::text from public.v1_supplier_receipt_batches batch
      where batch.state = 'committed'
        and not exists(
          select 1 from public.v1_document_links link
          where link.entity_type = 'supplier_receipt_batch'
            and link.entity_id = batch.id and link.removed_at is null
            and public.v1_document_readable(link.document_id)
        )
    ),
    'inactive_or_review', count(*) filter (
      where status in ('inactive', 'review') and not is_system
    )::text,
    'identity_missing', public.v1_supplier_reconciliation_count_r38_9(
      '00000000-0000-4000-8000-000000000389'::uuid
    )::text
  ) into v_summary
  from public.v1_suppliers;

  -- Directory totals stay unit-safe and follow the active search/status
  -- filter. They support exports without loading every supplier folder or
  -- adding unlike units into one misleading quantity.
  select coalesce(jsonb_agg(jsonb_build_object(
    'unit', totals.unit_snapshot,
    'accepted_quantity', totals.accepted_qty::text,
    'damaged_quantity', totals.damaged_qty::text,
    'rejected_quantity', totals.rejected_qty::text
  ) order by totals.unit_snapshot), '[]'::jsonb)
  into v_unit_totals
  from (
    select receipt_line.unit_snapshot,
      sum(receipt_line.accepted_qty) accepted_qty,
      sum(receipt_line.damaged_qty) damaged_qty,
      sum(receipt_line.rejected_qty) rejected_qty
    from public.v1_supplier_receipt_lines receipt_line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    join public.v1_suppliers supplier
      on supplier.id = receipt_batch.supplier_id
    where receipt_batch.state = 'committed'
      and (
        v_status = 'all'
        or (v_status = 'identity_missing' and supplier.is_system)
        or (v_status <> 'identity_missing' and not supplier.is_system
          and supplier.status = v_status)
      )
      and (
        v_search is null
        or supplier.name ilike '%' || v_search || '%'
        or supplier.supplier_code ilike '%' || v_search || '%'
        or exists(
          select 1 from public.v1_supplier_aliases alias
          where alias.supplier_id = supplier.id
            and alias.alias_name ilike '%' || v_search || '%'
        )
        or receipt_batch.supplier_reference ilike '%' || v_search || '%'
      )
    group by receipt_line.unit_snapshot
  ) totals;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', page.id,
      'supplier_code', page.supplier_code,
      'canonical_name', page.name,
      'description', page.notes,
      'status', case when page.is_system then 'identity_missing'
        else page.status end,
      'is_system_unknown', page.is_system,
      'distinct_item_count', (
        select count(distinct line.inventory_item_id)::text
        from public.v1_supplier_receipt_lines line
        join public.v1_supplier_receipt_batches batch
          on batch.id = line.receipt_batch_id
        where batch.supplier_id = page.id and batch.state = 'committed'
      ),
      'receipt_batch_count', (
        select count(*)::text from public.v1_supplier_receipt_batches batch
        where batch.supplier_id = page.id and batch.state = 'committed'
      ),
      'missing_document_count', (
        select count(*)::text from public.v1_supplier_receipt_batches batch
        where batch.supplier_id = page.id and batch.state = 'committed'
          and not exists(
            select 1 from public.v1_document_links link
            where link.entity_type = 'supplier_receipt_batch'
              and link.entity_id = batch.id and link.removed_at is null
              and public.v1_document_readable(link.document_id)
          )
      ),
      'reconciliation_count', case when page.is_system then
        public.v1_supplier_reconciliation_count_r38_9(page.id)::text
        else '0' end,
      'last_receipt_at', (
        select max(batch.created_at)::text
        from public.v1_supplier_receipt_batches batch
        where batch.supplier_id = page.id and batch.state = 'committed'
      ),
      'aliases', coalesce((
        select jsonb_agg(alias.alias_name order by alias.alias_name, alias.id)
        from public.v1_supplier_aliases alias
        where alias.supplier_id = page.id
      ), '[]'::jsonb),
      'record_version', page.record_version::text
    ) order by page.is_system desc, page.name, page.id
  ), '[]'::jsonb) into v_suppliers
  from (
    select supplier.*
    from public.v1_suppliers supplier
    where (
        v_status = 'all'
        or (v_status = 'identity_missing' and supplier.is_system)
        or (v_status <> 'identity_missing' and not supplier.is_system
          and supplier.status = v_status)
      )
      and (
        v_search is null
        or supplier.name ilike '%' || v_search || '%'
        or supplier.supplier_code ilike '%' || v_search || '%'
        or exists(
          select 1 from public.v1_supplier_aliases alias
          where alias.supplier_id = supplier.id
            and alias.alias_name ilike '%' || v_search || '%'
        )
        or exists(
          select 1 from public.v1_supplier_receipt_batches receipt_batch
          where receipt_batch.supplier_id = supplier.id
            and receipt_batch.supplier_reference ilike '%' || v_search || '%'
        )
      )
    order by supplier.is_system desc, supplier.name, supplier.id
    limit v_limit offset v_offset
  ) page;

  return jsonb_build_object(
    'summary', v_summary,
    'unit_totals', v_unit_totals,
    'suppliers', v_suppliers,
    'limit', v_limit::text,
    'offset', v_offset::text,
    'total_count', v_total::text
  );
end;
$$;

create or replace function public.v1_supplier_folder_projection(
  p_supplier_id uuid,
  p_section text,
  p_limit integer,
  p_offset integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_section text := lower(coalesce(nullif(btrim(p_section), ''), 'overview'));
  v_limit integer := coalesce(p_limit, 25);
  v_offset integer := coalesce(p_offset, 0);
  v_supplier public.v1_suppliers%rowtype;
  v_header jsonb;
  v_aliases jsonb := '[]'::jsonb;
  v_unit_totals jsonb := '[]'::jsonb;
  v_items jsonb := '[]'::jsonb;
  v_batches jsonb := '[]'::jsonb;
  v_documents jsonb := '[]'::jsonb;
  v_destinations jsonb := '[]'::jsonb;
  v_activity jsonb := '[]'::jsonb;
  v_total integer := 0;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_FOLDER_DENIED' using errcode = '42501';
  end if;
  if p_supplier_id is null
    or v_section not in (
      'overview', 'items_received', 'receipt_batches', 'documents',
      'destinations', 'activity_audit'
    )
    or v_limit < 1 or v_limit > 100
    or v_offset < 0 or v_offset > 100000 then
    raise exception 'V1_SUPPLIER_FOLDER_ARGUMENT_INVALID' using errcode = '22023';
  end if;
  select * into v_supplier from public.v1_suppliers
  where id = p_supplier_id;
  if not found then
    raise exception 'V1_SUPPLIER_NOT_FOUND' using errcode = '22023';
  end if;
  v_header := jsonb_build_object(
    'id', v_supplier.id,
    'supplier_code', v_supplier.supplier_code,
    'canonical_name', v_supplier.name,
    'description', v_supplier.notes,
    'status', case when v_supplier.is_system then 'identity_missing'
      else v_supplier.status end,
    'is_system_unknown', v_supplier.is_system,
    'receipt_batch_count', (
      select count(*)::text from public.v1_supplier_receipt_batches batch
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
    ),
    'distinct_item_count', (
      select count(distinct line.inventory_item_id)::text
      from public.v1_supplier_receipt_lines line
      join public.v1_supplier_receipt_batches batch
        on batch.id = line.receipt_batch_id
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
    ),
    'missing_document_count', (
      select count(*)::text from public.v1_supplier_receipt_batches batch
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
        and not exists(
          select 1 from public.v1_document_links link
          where link.entity_type = 'supplier_receipt_batch'
            and link.entity_id = batch.id and link.removed_at is null
            and public.v1_document_readable(link.document_id)
        )
    ),
    'reconciliation_count', case when v_supplier.is_system then
      public.v1_supplier_reconciliation_count_r38_9(p_supplier_id)::text
      else '0' end,
    'last_receipt_at', (
      select max(batch.created_at)::text
      from public.v1_supplier_receipt_batches batch
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
    ),
    'aliases', '[]'::jsonb,
    'record_version', v_supplier.record_version::text
  );
  select coalesce(jsonb_agg(alias.alias_name
    order by alias.alias_name, alias.id), '[]'::jsonb)
  into v_aliases
  from public.v1_supplier_aliases alias
  where alias.supplier_id = p_supplier_id;
  v_header := jsonb_set(v_header, '{aliases}', v_aliases, true);

  select coalesce(jsonb_agg(jsonb_build_object(
    'unit', totals.unit_snapshot,
    'accepted_quantity', totals.accepted_qty::text,
    'damaged_quantity', totals.damaged_qty::text,
    'rejected_quantity', totals.rejected_qty::text
  ) order by totals.unit_snapshot), '[]'::jsonb)
  into v_unit_totals
  from (
    select line.unit_snapshot,
      sum(line.accepted_qty) accepted_qty,
      sum(line.damaged_qty) damaged_qty,
      sum(line.rejected_qty) rejected_qty
    from public.v1_supplier_receipt_lines line
    join public.v1_supplier_receipt_batches batch
      on batch.id = line.receipt_batch_id
    where batch.supplier_id = p_supplier_id and batch.state = 'committed'
    group by line.unit_snapshot
  ) totals;

  if v_section in ('overview', 'items_received') then
    select count(distinct line.inventory_item_id)::integer into v_total
    from public.v1_supplier_receipt_lines line
    join public.v1_supplier_receipt_batches batch
      on batch.id = line.receipt_batch_id
    where batch.supplier_id = p_supplier_id and batch.state = 'committed';
    select coalesce(jsonb_agg(jsonb_build_object(
      'inventory_item_id', item_page.inventory_item_id,
      'item_code', coalesce(item_page.item_code,
        'INV-' || upper(substr(replace(item_page.inventory_item_id::text, '-', ''), 1, 8))),
      'item_description', item_page.item_description,
      'size', item_page.size_snapshot,
      'model_tag', item_page.model_tag_snapshot,
      'unit', item_page.unit,
      'accepted_quantity', item_page.accepted_qty::text,
      'current_on_hand', item_page.current_on_hand::text,
      'receipt_batch_count', item_page.receipt_batch_count::text,
      'last_receipt_at', item_page.last_receipt_at::text
    ) order by item_page.item_description, item_page.inventory_item_id), '[]'::jsonb)
    into v_items
    from (
      select line.inventory_item_id,
        max(line.item_code_snapshot) item_code,
        max(line.item_description_snapshot) item_description,
        max(line.size_snapshot) size_snapshot,
        max(line.model_tag_snapshot) model_tag_snapshot,
        line.unit_snapshot unit,
        sum(line.accepted_qty) accepted_qty,
        max(balance.on_hand_qty) current_on_hand,
        count(distinct batch.id) receipt_batch_count,
        max(batch.created_at) last_receipt_at
      from public.v1_supplier_receipt_lines line
      join public.v1_supplier_receipt_batches batch
        on batch.id = line.receipt_batch_id
      join public.v1_inventory_balances balance
        on balance.inventory_item_id = line.inventory_item_id
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
      group by line.inventory_item_id, line.unit_snapshot
      order by max(line.item_description_snapshot), line.inventory_item_id
      limit case when v_section = 'overview' then least(v_limit, 5) else v_limit end
      offset case when v_section = 'overview' then 0 else v_offset end
    ) item_page;
  end if;

  if v_section in ('overview', 'receipt_batches') then
    select count(*)::integer into v_total
    from public.v1_supplier_receipt_batches batch
    where batch.supplier_id = p_supplier_id and batch.state = 'committed';
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', batch_page.id,
      'receipt_number', 'RCV-' || upper(substr(replace(batch_page.id::text, '-', ''), 1, 8)),
      'source_type', batch_page.source_type,
      'supplier_reference', batch_page.supplier_reference,
      'received_date', batch_page.received_date,
      'warehouse_location', coalesce(batch_page.location_bin, 'Warehouse'),
      'status', batch_page.state,
      'line_count', batch_page.line_count::text,
      'document_count', (
        select count(distinct link.document_id)::text
        from public.v1_document_links link
        where link.entity_type = 'supplier_receipt_batch'
          and link.entity_id = batch_page.id and link.removed_at is null
          and public.v1_document_readable(link.document_id)
      ),
      'unit_totals', batch_page.unit_totals,
      'received_by_display_name', public.v1_safe_profile_display_name(
        batch_page.display_name, batch_page.created_by_auth_user_id
      ),
      'created_at', batch_page.created_at
    ) order by batch_page.received_date desc, batch_page.created_at desc,
      batch_page.id), '[]'::jsonb)
    into v_batches
    from (
      select batch.id, batch.source_type, batch.supplier_reference,
        batch.received_date, batch.location_bin, batch.state,
        batch.created_by_auth_user_id, batch.created_at,
        profile.display_name,
        (select count(*)::integer
          from public.v1_supplier_receipt_lines receipt_line
          where receipt_line.receipt_batch_id = batch.id) line_count,
        (select coalesce(jsonb_agg(jsonb_build_object(
            'unit', unit_total.unit_snapshot,
            'delivered_quantity', unit_total.delivered_qty::text,
            'accepted_quantity', unit_total.accepted_qty::text,
            'damaged_quantity', unit_total.damaged_qty::text,
            'rejected_quantity', unit_total.rejected_qty::text
          ) order by unit_total.unit_snapshot), '[]'::jsonb)
          from (
            select receipt_line.unit_snapshot,
              sum(receipt_line.delivered_qty) delivered_qty,
              sum(receipt_line.accepted_qty) accepted_qty,
              sum(receipt_line.damaged_qty) damaged_qty,
              sum(receipt_line.rejected_qty) rejected_qty
            from public.v1_supplier_receipt_lines receipt_line
            where receipt_line.receipt_batch_id = batch.id
            group by receipt_line.unit_snapshot
          ) unit_total) unit_totals
      from public.v1_supplier_receipt_batches batch
      join public.v1_profiles profile
        on profile.auth_user_id = batch.created_by_auth_user_id
      where batch.supplier_id = p_supplier_id and batch.state = 'committed'
      order by batch.received_date desc, batch.created_at desc, batch.id
      limit case when v_section = 'overview' then least(v_limit, 5) else v_limit end
      offset case when v_section = 'overview' then 0 else v_offset end
    ) batch_page;
  end if;

  if v_section in ('overview', 'documents') then
    select count(distinct document_record.id)::integer into v_total
    from public.v1_documents document_record
    join public.v1_document_links link
      on link.document_id = document_record.id and link.removed_at is null
    where public.v1_document_readable(document_record.id)
      and (
        (link.entity_type = 'supplier' and link.entity_id = p_supplier_id)
        or
        (link.entity_type = 'supplier_receipt_batch' and exists(
          select 1 from public.v1_supplier_receipt_batches receipt_batch
          where receipt_batch.id = link.entity_id
            and receipt_batch.supplier_id = p_supplier_id
        ))
      );
    select coalesce(jsonb_agg(jsonb_build_object(
      'document_id', document_page.document_id,
      'version_id', document_page.version_id,
      'file_name', document_page.file_name,
      'mime_type', document_page.mime_type,
      'byte_size', document_page.byte_size::text,
      'revision_number', document_page.revision_number::text,
      'classification', document_page.classification,
      'uploaded_at', document_page.uploaded_at,
      'uploaded_by_display_name', public.v1_safe_profile_display_name(
        document_page.display_name, document_page.uploaded_by_auth_user_id
      ),
      'receipt_batch_id', document_page.receipt_batch_id
    ) order by document_page.uploaded_at desc, document_page.document_id), '[]'::jsonb)
    into v_documents
    from (
      select distinct on (document_record.id)
        document_record.id document_id,
        version_record.id version_id,
        version_record.original_file_name file_name,
        version_record.mime_type,
        version_record.byte_size,
        version_record.revision_number,
        document_record.classification,
        version_record.uploaded_at,
        version_record.uploaded_by_auth_user_id,
        profile.display_name,
        case when link.entity_type = 'supplier_receipt_batch'
          then link.entity_id else null end receipt_batch_id
      from public.v1_documents document_record
      join public.v1_document_versions version_record
        on version_record.id = document_record.current_version_id
      join public.v1_profiles profile
        on profile.auth_user_id = version_record.uploaded_by_auth_user_id
      join public.v1_document_links link
        on link.document_id = document_record.id and link.removed_at is null
      where public.v1_document_readable(document_record.id)
        and (
          (link.entity_type = 'supplier' and link.entity_id = p_supplier_id)
          or
          (link.entity_type = 'supplier_receipt_batch' and exists(
            select 1 from public.v1_supplier_receipt_batches receipt_batch
            where receipt_batch.id = link.entity_id
              and receipt_batch.supplier_id = p_supplier_id
          ))
        )
      order by document_record.id, version_record.uploaded_at desc
      limit case when v_section = 'overview' then least(v_limit, 5) else v_limit end
      offset case when v_section = 'overview' then 0 else v_offset end
    ) document_page;
  end if;

  if v_section = 'destinations' then
    select count(*)::integer into v_total
    from public.v1_dispatch_batch_allocations allocation
    join public.v1_supplier_receipt_lines receipt_line
      on receipt_line.id = allocation.receipt_line_id
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where receipt_batch.supplier_id = p_supplier_id;
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', destination.id,
      'supplier_id', p_supplier_id,
      'inventory_item_id', destination.inventory_item_id,
      'receipt_line_id', destination.receipt_line_id,
      'receipt_batch_id', destination.receipt_batch_id,
      'dispatch_line_id', destination.dispatch_line_id,
      'dispatch_id', destination.dispatch_id,
      'request_id', destination.request_id,
      'project_id', destination.project_id,
      'scope_id', destination.scope_id,
      'receipt_review_id', destination.receipt_review_id,
      'item_description', destination.item_description,
      'quantity', destination.allocated_qty::text,
      'unit', destination.unit,
      'project_reference', destination.project_ref,
      'project_name', destination.project_name,
      'scope_name', destination.scope_name,
      'request_number', destination.request_number,
      'dispatch_number', destination.dispatch_number,
      'state', destination.state,
      'receipt_outcome', destination.receipt_outcome,
      'good_received_quantity', destination.good_received_qty::text,
      'exception_quantity', destination.exception_qty::text,
      'confirmed_return_quantity', destination.returned_qty::text,
      'material_return_ids', destination.material_return_ids,
      'provenance_state', case
        when destination.receipt_outcome is null then 'receipt_pending'
        when destination.receipt_attribution_id is null then 'unproven'
        when destination.dispatch_gap_qty > 0 then 'attributed_with_legacy_gap'
        when destination.exception_qty > 0 then 'attributed_with_exception'
        when destination.returned_qty >= destination.good_received_qty
          and destination.good_received_qty > 0 then 'fully_returned'
        when destination.returned_qty > 0 then 'partially_returned'
        else 'attributed'
      end,
      'provenance_reason', case
        when destination.receipt_outcome is null then 'receipt_not_confirmed'
        when destination.receipt_attribution_id is null
          then 'legacy_or_unproven_stock'
        when destination.dispatch_gap_qty > 0
          then 'legacy_or_unproven_stock'
        when destination.exception_qty > 0 then destination.receipt_outcome
        when destination.returned_qty > 0 then 'confirmed_material_return'
        else null
      end,
      'dispatch_gap_quantity', destination.dispatch_gap_qty::text,
      'unproven_good_quantity', destination.unproven_good_qty::text,
      'unproven_exception_quantity', destination.unproven_exception_qty::text,
      'unproven_return_quantity', destination.unproven_return_qty::text,
      'dispatched_at', destination.dispatched_at
    ) order by destination.dispatched_at desc, destination.id), '[]'::jsonb)
    into v_destinations
    from (
      select allocation.id, allocation.dispatch_line_id,
        allocation.receipt_line_id, receipt_batch.id receipt_batch_id,
        dispatch.id dispatch_id, request_record.id request_id,
        dispatch.dispatch_number, dispatch.dispatch_date,
        dispatch.state, dispatch.dispatched_at,
        project.id project_id, project.project_ref, project.name project_name,
        scope.id scope_id, scope.name scope_name,
        request_record.request_number,
        receipt_line.inventory_item_id,
        dispatch_line.item_description, dispatch_line.unit,
        allocation.allocated_qty, allocation.allocation_method,
        allocation.override_reason,
        receipt_review_line.outcome receipt_outcome,
        receipt_review_line.id receipt_review_id,
        receipt_attribution.id receipt_attribution_id,
        coalesce(receipt_attribution.good_qty, 0) good_received_qty,
        coalesce(receipt_attribution.exception_qty, 0) exception_qty,
        coalesce((
          select sum(return_attribution.returned_qty)
          from public.v1_material_return_batch_allocations return_attribution
          where return_attribution.receipt_attribution_id =
            receipt_attribution.id
        ), 0) returned_qty,
        coalesce((
          select jsonb_agg(distinct return_line.material_return_id)
          from public.v1_material_return_batch_allocations return_attribution
          join public.v1_material_return_lines return_line
            on return_line.id = return_attribution.material_return_line_id
          where return_attribution.receipt_attribution_id =
            receipt_attribution.id
        ), '[]'::jsonb) material_return_ids,
        coalesce(dispatch_gap.unallocated_qty, 0) dispatch_gap_qty,
        coalesce(receipt_gap.good_qty, 0) unproven_good_qty,
        coalesce(receipt_gap.exception_qty, 0) unproven_exception_qty,
        coalesce((
          select sum(return_gap.returned_qty)
          from public.v1_material_return_batch_allocation_gaps return_gap
          where return_gap.receipt_gap_id = receipt_gap.id
        ), 0) unproven_return_qty
      from public.v1_dispatch_batch_allocations allocation
      join public.v1_supplier_receipt_lines receipt_line
        on receipt_line.id = allocation.receipt_line_id
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = allocation.dispatch_line_id
      join public.v1_material_dispatches dispatch
        on dispatch.id = dispatch_line.dispatch_id
      join public.v1_material_requests request_record
        on request_record.id = dispatch.request_id
      join public.v1_projects project on project.id = request_record.project_id
      join public.v1_project_scopes scope on scope.id = request_record.scope_id
      left join public.v1_receipt_review_lines receipt_review_line
        on receipt_review_line.dispatch_line_id = dispatch_line.id
      left join public.v1_dispatch_batch_receipt_allocations receipt_attribution
        on receipt_attribution.receipt_review_line_id = receipt_review_line.id
          and receipt_attribution.dispatch_allocation_id = allocation.id
      left join public.v1_dispatch_batch_allocation_gaps dispatch_gap
        on dispatch_gap.dispatch_line_id = dispatch_line.id
      left join public.v1_dispatch_batch_receipt_gaps receipt_gap
        on receipt_gap.receipt_review_line_id = receipt_review_line.id
      where receipt_batch.supplier_id = p_supplier_id
      order by dispatch.dispatched_at desc, allocation.id
      limit v_limit offset v_offset
    ) destination;
  end if;

  if v_section = 'activity_audit' then
    select count(*)::integer into v_total
    from public.v1_audit_events audit
    where (audit.entity_type = 'supplier' and audit.entity_id = p_supplier_id)
      or (audit.entity_type = 'supplier_receipt_batch' and exists(
        select 1 from public.v1_supplier_receipt_batches batch
        where batch.id = audit.entity_id and batch.supplier_id = p_supplier_id
      ));
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', activity.id,
      'event_type', activity.event_type,
      'entity_type', activity.entity_type,
      'entity_id', activity.entity_id,
      'actor_display_name', public.v1_safe_profile_display_name(
        activity.display_name, activity.actor_auth_user_id
      ),
      'actor_role', coalesce(activity.actor_exact_role, activity.actor_role),
      'occurred_at', activity.occurred_at,
      'reason', activity.reason
    ) order by activity.occurred_at desc, activity.id), '[]'::jsonb)
    into v_activity
    from (
      select audit.*, profile.display_name
      from public.v1_audit_events audit
      join public.v1_profiles profile
        on profile.auth_user_id = audit.actor_auth_user_id
      where (audit.entity_type = 'supplier' and audit.entity_id = p_supplier_id)
        or (audit.entity_type = 'supplier_receipt_batch' and exists(
          select 1 from public.v1_supplier_receipt_batches batch
          where batch.id = audit.entity_id and batch.supplier_id = p_supplier_id
        ))
      order by audit.occurred_at desc, audit.id
      limit v_limit offset v_offset
    ) activity;
  end if;

  return jsonb_build_object(
    'supplier', v_header,
    'aliases', v_aliases,
    'unit_totals', v_unit_totals,
    'items', v_items,
    'batches', v_batches,
    'documents', v_documents,
    'documents_supported', true,
    'destinations', v_destinations,
    'activity', v_activity,
    'total_count', v_total::text,
    'limit', v_limit::text,
    'offset', case when v_section = 'overview' then '0'
      else v_offset::text end
  );
end;
$$;

create or replace function public.v1_import_inventory_r38_9(
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
  v_file_sha256 text;
  v_import_mode text;
  v_opening_balance_as_of_date date;
  v_has_opening_balance boolean := false;
  v_rows jsonb;
  v_row jsonb;
  v_batch_id uuid := gen_random_uuid();
  v_row_number integer;
  v_import_row_id uuid;
  v_item_id uuid;
  v_explicit_item_id uuid;
  v_item_code text;
  v_description text;
  v_size_snapshot text;
  v_model_tag_snapshot text;
  v_brand_origin text;
  v_ral_colour_snapshot text;
  v_unit text;
  v_action text;
  v_source_type text;
  v_quantity numeric(18, 4);
  v_accepted numeric(18, 4);
  v_damaged numeric(18, 4);
  v_rejected numeric(18, 4);
  v_delta numeric(18, 4);
  v_reason text;
  v_category_id uuid;
  v_new_category_name text;
  v_source_category text;
  v_category_resolution jsonb;
  v_resolved_category_id uuid;
  v_category_name text;
  v_minimum_stock numeric(18, 4);
  v_location_bin text;
  v_notes text;
  v_supplier_id uuid;
  v_new_supplier_name text;
  v_source_supplier_text text;
  v_supplier_name_snapshot text;
  v_supplier_resolution_snapshot text;
  v_supplier_resolution jsonb;
  v_supplier_code text;
  v_supplier_name text;
  v_supplier_reference text;
  v_normalized_reference text;
  v_received_date date;
  v_reference_generated boolean;
  v_date_generated boolean;
  v_receipt_batch_id uuid;
  v_receipt_line_id uuid;
  v_tracking_mode text;
  v_serial_number text;
  v_batch_lot_number text;
  v_unit_price numeric(18, 4);
  v_total_price numeric(18, 4);
  v_imported_total_price numeric(18, 4);
  v_calculated_total_price numeric(18, 4);
  v_currency_code text;
  v_raw_source_values jsonb;
  v_balance public.v1_inventory_balances%rowtype;
  v_reserved numeric(18, 4);
  v_created_item boolean;
  v_created_receipt_batch boolean;
  v_warnings text[];
  v_created_items integer := 0;
  v_updated_items integer := 0;
  v_created_categories integer := 0;
  v_created_suppliers integer := 0;
  v_created_receipt_batches integer := 0;
  v_unknown_supplier_rows integer := 0;
  v_warning_count integer := 0;
  v_movement_count integer := 0;
  v_movement_type text;
  v_response jsonb;
  v_unit_totals jsonb;
  v_batch_record record;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_IMPORT_R38_9_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array['file_name', 'file_sha256', 'import_mode',
      'opening_balance_as_of_date', 'rows'],
    'import_inventory_r38_9'
  );
  v_file_name := nullif(btrim(coalesce(p_payload ->> 'file_name', '')), '');
  v_file_sha256 := lower(nullif(btrim(coalesce(p_payload ->> 'file_sha256', '')), ''));
  v_import_mode := lower(coalesce(nullif(btrim(p_payload ->> 'import_mode'), ''), 'strict'));
  v_rows := p_payload -> 'rows';
  if nullif(btrim(coalesce(p_payload ->> 'opening_balance_as_of_date', '')), '') is not null then
    begin
      v_opening_balance_as_of_date :=
        (p_payload ->> 'opening_balance_as_of_date')::date;
    exception when others then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_DATE_INVALID'
        using errcode = '22023';
    end;
  end if;
  if p_idempotency_key is null
    or v_file_name is null or char_length(v_file_name) > 255
    or v_file_sha256 is null or v_file_sha256 !~ '^[a-f0-9]{64}$'
    or v_import_mode <> 'strict'
    or jsonb_typeof(v_rows) <> 'array'
    or jsonb_array_length(v_rows) < 1
    or jsonb_array_length(v_rows) > 20000 then
    raise exception 'V1_INVENTORY_IMPORT_R38_9_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select exists(
    select 1
    from jsonb_array_elements(v_rows) row_value
    where lower(btrim(coalesce(row_value ->> 'source_type', ''))) =
        'opening_balance'
      or lower(btrim(coalesce(row_value ->> 'stock_action', ''))) =
        'opening_balance'
  ) into v_has_opening_balance;
  if v_has_opening_balance and v_opening_balance_as_of_date is null then
    raise exception 'V1_INVENTORY_IMPORT_R38_9_OPENING_DATE_REQUIRED'
      using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_import_inventory_r38_9', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  -- Imports are intentionally serialized. They are infrequent administrative
  -- commands, and this deterministic lock avoids cross-file balance/supplier
  -- deadlocks while each workbook is committed atomically.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('v1_import_inventory_r38_9', 0)
  );
  if exists(
    select 1 from public.v1_inventory_import_results result
    where result.file_sha256 = v_file_sha256
  ) then
    raise exception 'V1_INVENTORY_IMPORT_FILE_ALREADY_COMMITTED'
      using errcode = '23505';
  end if;
  if v_has_opening_balance and exists(
    select 1
    from public.v1_inventory_opening_balance_cutoffs cutoff
    where cutoff.as_of_date = v_opening_balance_as_of_date
  ) then
    raise exception 'V1_INVENTORY_OPENING_BALANCE_CUTOFF_ALREADY_CLAIMED:%',
      v_opening_balance_as_of_date using errcode = '23505';
  end if;

  insert into public.v1_inventory_import_batches (
    id, file_name, row_count, actor_auth_user_id, idempotency_key
  ) values (
    v_batch_id, v_file_name, jsonb_array_length(v_rows), v_actor,
    p_idempotency_key
  );
  if v_has_opening_balance then
    insert into public.v1_inventory_opening_balance_cutoffs (
      as_of_date, import_batch_id, file_sha256, claimed_by_auth_user_id
    ) values (
      v_opening_balance_as_of_date, v_batch_id, v_file_sha256, v_actor
    );
  end if;

  for v_row in select value from jsonb_array_elements(v_rows)
  loop
    perform public.v1_assert_object_keys(
      v_row,
      array['source_row_number', 'inventory_item_id', 'item_code',
        'item_description', 'category_id', 'new_category_name',
        'source_category_text', 'brand_origin', 'unit', 'stock_action',
        'quantity', 'reason', 'minimum_stock', 'location_bin', 'notes',
        'source_type', 'supplier_id', 'new_supplier_name',
        'external_supplier_name', 'supplier_reference', 'received_date',
        'accepted_quantity', 'damaged_quantity', 'rejected_quantity',
        'tracking_mode', 'serial_number', 'batch_lot_number', 'unit_price',
        'total_price', 'currency_code', 'source_type_text', 'size_text',
        'model_tag', 'ral_colour', 'supplier_name_snapshot',
        'source_supplier_text', 'supplier_resolution', 'delivered_quantity',
        'calculated_total_price', 'imported_total_price',
        'raw_source_values'],
      'import_inventory_r38_9_row'
    );
    v_row_number := null;
    v_explicit_item_id := null;
    v_item_id := null;
    v_category_id := null;
    v_resolved_category_id := null;
    v_supplier_id := null;
    v_receipt_batch_id := null;
    v_receipt_line_id := null;
    v_unit_price := null;
    v_total_price := null;
    v_imported_total_price := null;
    v_calculated_total_price := null;
    v_warnings := '{}'::text[];
    v_reference_generated := false;
    v_date_generated := false;
    begin
      v_row_number := nullif(v_row ->> 'source_row_number', '')::integer;
      v_explicit_item_id := nullif(btrim(coalesce(v_row ->> 'inventory_item_id', '')), '')::uuid;
      v_category_id := nullif(btrim(coalesce(v_row ->> 'category_id', '')), '')::uuid;
      v_supplier_id := nullif(btrim(coalesce(v_row ->> 'supplier_id', '')), '')::uuid;
      v_quantity := coalesce(
        nullif(v_row ->> 'delivered_quantity', '')::numeric(18, 4),
        nullif(v_row ->> 'quantity', '')::numeric(18, 4)
      );
      v_minimum_stock := nullif(v_row ->> 'minimum_stock', '')::numeric(18, 4);
      v_damaged := coalesce(nullif(v_row ->> 'damaged_quantity', '')::numeric(18, 4), 0);
      v_rejected := coalesce(nullif(v_row ->> 'rejected_quantity', '')::numeric(18, 4), 0);
      v_accepted := nullif(v_row ->> 'accepted_quantity', '')::numeric(18, 4);
      v_unit_price := nullif(v_row ->> 'unit_price', '')::numeric(18, 4);
      v_total_price := nullif(v_row ->> 'total_price', '')::numeric(18, 4);
      v_calculated_total_price :=
        nullif(v_row ->> 'calculated_total_price', '')::numeric(18, 4);
      v_imported_total_price :=
        nullif(v_row ->> 'imported_total_price', '')::numeric(18, 4);
    exception when others then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_ROW_TYPE_INVALID:%',
        coalesce(v_row ->> 'source_row_number', '?') using errcode = '22023';
    end;
    v_item_code := nullif(btrim(coalesce(v_row ->> 'item_code', '')), '');
    v_description := nullif(btrim(coalesce(v_row ->> 'item_description', '')), '');
    v_size_snapshot := nullif(btrim(coalesce(v_row ->> 'size_text', '')), '');
    v_model_tag_snapshot := nullif(btrim(coalesce(v_row ->> 'model_tag', '')), '');
    v_brand_origin := nullif(btrim(coalesce(v_row ->> 'brand_origin', '')), '');
    v_ral_colour_snapshot := nullif(btrim(coalesce(v_row ->> 'ral_colour', '')), '');
    v_unit := nullif(btrim(coalesce(v_row ->> 'unit', '')), '');
    v_action := lower(nullif(btrim(coalesce(v_row ->> 'stock_action', '')), ''));
    v_source_type := lower(nullif(btrim(coalesce(v_row ->> 'source_type', '')), ''));
    v_reason := nullif(btrim(coalesce(v_row ->> 'reason', '')), '');
    v_new_category_name := nullif(btrim(coalesce(v_row ->> 'new_category_name', '')), '');
    v_source_category := nullif(btrim(coalesce(v_row ->> 'source_category_text', '')), '');
    v_location_bin := nullif(btrim(coalesce(v_row ->> 'location_bin', '')), '');
    v_notes := nullif(btrim(coalesce(v_row ->> 'notes', '')), '');
    v_new_supplier_name := nullif(btrim(coalesce(v_row ->> 'new_supplier_name', '')), '');
    v_source_supplier_text := nullif(btrim(coalesce(
      v_row ->> 'external_supplier_name', v_row ->> 'source_supplier_text', ''
    )), '');
    v_supplier_name_snapshot := nullif(btrim(coalesce(
      v_row ->> 'supplier_name_snapshot', ''
    )), '');
    v_supplier_resolution_snapshot := nullif(btrim(coalesce(
      v_row ->> 'supplier_resolution', ''
    )), '');
    v_supplier_reference := nullif(btrim(coalesce(v_row ->> 'supplier_reference', '')), '');
    v_serial_number := nullif(btrim(coalesce(v_row ->> 'serial_number', '')), '');
    v_batch_lot_number := nullif(btrim(coalesce(v_row ->> 'batch_lot_number', '')), '');
    v_tracking_mode := lower(coalesce(
      nullif(btrim(v_row ->> 'tracking_mode'), ''),
      case when v_serial_number is not null then 'serialized'
        when v_batch_lot_number is not null then 'batch' else 'bulk' end
    ));
    v_currency_code := upper(coalesce(
      nullif(btrim(v_row ->> 'currency_code'), ''), 'AED'
    ));
    v_raw_source_values := coalesce(v_row -> 'raw_source_values', '{}'::jsonb);
    if nullif(btrim(coalesce(v_row ->> 'received_date', '')), '') is not null then
      begin
        v_received_date := (v_row ->> 'received_date')::date;
      exception when others then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_RECEIVED_DATE_INVALID:%',
          coalesce(v_row_number::text, '?') using errcode = '22023';
      end;
    else
      v_received_date := null;
    end if;

    if v_row_number is null or v_row_number < 1
      or v_description is null or char_length(v_description) > 500
      or v_unit is null or char_length(v_unit) > 40
      or v_reason is null or char_length(v_reason) > 1000
      or v_action not in ('opening_balance', 'add_stock')
      or v_source_type not in ('opening_balance', 'external_supplier')
      or v_quantity is null or v_quantity < 0
      or (v_minimum_stock is not null and v_minimum_stock < 0)
      or v_quantity <= 0
      or (v_action = 'opening_balance' and v_source_type <> 'opening_balance')
      or (v_action = 'add_stock' and v_source_type <> 'external_supplier')
      or (v_category_id is not null and v_new_category_name is not null)
      or (v_supplier_id is not null and v_new_supplier_name is not null)
      or (v_item_code is not null and char_length(v_item_code) > 80)
      or lower(v_unit) not in (
        'nos', 'meter', 'cm', 'length', 'set', 'pairs', 'roll', 'box',
        'ton', 'boxes'
      )
      or v_tracking_mode not in ('bulk', 'batch', 'serialized')
      or v_currency_code !~ '^[A-Z]{3}$'
      or jsonb_typeof(v_raw_source_values) <> 'object' then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_ROW_INVALID:%', v_row_number
        using errcode = '22023';
    end if;

    if v_action in ('opening_balance', 'add_stock') then
      v_accepted := coalesce(v_accepted, v_quantity - v_damaged - v_rejected);
      if v_accepted < 0 or v_damaged < 0 or v_rejected < 0
        or v_accepted + v_damaged + v_rejected <> v_quantity
        or (v_tracking_mode = 'serialized' and (
          v_serial_number is null or v_batch_lot_number is not null or v_quantity <> 1
        ))
        or (v_tracking_mode = 'batch' and (
          v_batch_lot_number is null or v_serial_number is not null
        ))
        or (v_tracking_mode = 'bulk' and (
          v_serial_number is not null or v_batch_lot_number is not null
        )) then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_CONDITION_INVALID:%', v_row_number
          using errcode = '22023';
      end if;
    else
      v_accepted := coalesce(v_accepted, 0);
      if v_accepted <> 0 or v_damaged <> 0 or v_rejected <> 0
        or v_serial_number is not null or v_batch_lot_number is not null then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_NON_RECEIPT_CONDITION_INVALID:%',
          v_row_number using errcode = '22023';
      end if;
    end if;
    if v_unit_price is not null then
      if v_unit_price < 0 or not public.v1_has_capability('manage_commercials') then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_COMMERCIAL_DENIED'
          using errcode = '42501';
      end if;
      if v_total_price is not null and v_total_price <> v_quantity * v_unit_price then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_calculated_total_price is not null
        and v_calculated_total_price <> v_quantity * v_unit_price then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_TOTAL_PRICE_MISMATCH:%', v_row_number
          using errcode = '22023';
      end if;
      if v_imported_total_price is not null
        and v_imported_total_price <> v_quantity * v_unit_price then
        v_warnings := array_append(v_warnings, 'imported_total_recalculated');
      end if;
    elsif v_total_price is not null or v_calculated_total_price is not null
      or v_imported_total_price is not null then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_UNIT_PRICE_REQUIRED:%', v_row_number
        using errcode = '22023';
    end if;

    if v_source_type = 'external_supplier' then
      if v_supplier_reference is null or v_received_date is null then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_EXTERNAL_RECEIPT_REQUIRED:%',
          v_row_number using errcode = '22023';
      end if;
    else
      if v_received_date is not null
        and v_received_date <> v_opening_balance_as_of_date then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_OPENING_DATE_MISMATCH:%',
          v_row_number using errcode = '22023';
      end if;
      if v_supplier_reference is null then
        v_supplier_reference :=
          'OPENING-' || upper(substr(v_file_sha256, 1, 12));
        v_reference_generated := true;
        v_warnings := array_append(v_warnings, 'opening_reference_generated');
      end if;
      if v_received_date is null then
        v_received_date := v_opening_balance_as_of_date;
        v_date_generated := true;
        v_warnings := array_append(v_warnings, 'opening_received_date_generated');
      end if;
    end if;
    if char_length(v_supplier_reference) > 180 then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_REFERENCE_INVALID:%', v_row_number
        using errcode = '22023';
    end if;

    v_supplier_resolution := public.v1_resolve_inventory_supplier_r38_9(
      v_supplier_id, v_new_supplier_name, v_source_supplier_text,
      v_batch_id, v_row_number
    );
    v_supplier_id := (v_supplier_resolution ->> 'id')::uuid;
    v_supplier_code := v_supplier_resolution ->> 'supplier_code';
    v_supplier_name := v_supplier_resolution ->> 'name';
    if (v_supplier_resolution ->> 'created')::boolean then
      v_created_suppliers := v_created_suppliers + 1;
    end if;
    if (v_supplier_resolution ->> 'used_unknown')::boolean then
      v_unknown_supplier_rows := v_unknown_supplier_rows + 1;
      v_warnings := array_append(v_warnings, 'unknown_supplier');
    end if;

    v_item_id := v_explicit_item_id;
    if v_item_id is null and v_item_code is not null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_code)) = lower(btrim(v_item_code));
    end if;
    if v_item_id is null then
      select id into v_item_id from public.v1_inventory_items
      where lower(btrim(item_description)) = lower(btrim(v_description))
        and lower(coalesce(btrim(brand_origin), '')) =
          lower(coalesce(btrim(v_brand_origin), ''))
        and lower(btrim(unit)) = lower(btrim(v_unit));
    end if;

    v_created_item := false;
    if v_item_id is null then
      if v_category_id is null and v_new_category_name is null then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_CATEGORY_REQUIRED:%',
          v_row_number using errcode = '22023';
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
        raise exception 'V1_INVENTORY_IMPORT_R38_9_ITEM_NOT_FOUND:%', v_row_number
          using errcode = '22023';
      end if;
      if lower(v_unit) <>
          lower((select unit from public.v1_inventory_items where id = v_item_id))
        or lower(v_description) <>
          lower((select item_description from public.v1_inventory_items where id = v_item_id))
        or lower(coalesce(v_brand_origin, '')) <>
          lower(coalesce((select brand_origin from public.v1_inventory_items
            where id = v_item_id), ''))
        or (v_item_code is not null
          and (select item_code from public.v1_inventory_items where id = v_item_id) is not null
          and lower(v_item_code) <> lower((select item_code
            from public.v1_inventory_items where id = v_item_id))) then
        raise exception 'V1_INVENTORY_IMPORT_R38_9_ITEM_MISMATCH:%', v_row_number
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

    select category.name into v_category_name
    from public.v1_inventory_categories category
    where category.id = v_resolved_category_id;

    if v_action in ('opening_balance', 'add_stock') then
      v_normalized_reference :=
        public.v1_supplier_reference_key(v_supplier_reference);
      perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
        'v1_supplier_receipt:' || v_supplier_id::text || ':' ||
        v_source_type || ':' || v_normalized_reference || ':' ||
        v_received_date::text || ':' || lower(coalesce(v_location_bin, '')), 0
      ));
      select id, import_batch_id = v_batch_id into
        v_receipt_batch_id, v_created_receipt_batch
      from public.v1_supplier_receipt_batches
      where supplier_id = v_supplier_id
        and source_type = v_source_type
        and normalized_reference = v_normalized_reference
        and received_date = v_received_date
        and coalesce(lower(btrim(location_bin)), '') =
          coalesce(lower(btrim(v_location_bin)), '')
        and state = 'committed'
      for update;
      if found and not v_created_receipt_batch then
        raise exception 'V1_SUPPLIER_RECEIPT_REFERENCE_ALREADY_COMMITTED:%',
          v_row_number using errcode = '23505';
      elsif not found then
        v_receipt_batch_id := gen_random_uuid();
        insert into public.v1_supplier_receipt_batches (
          id, import_batch_id, supplier_id, supplier_code_snapshot,
          supplier_name_snapshot, source_type, supplier_reference,
          normalized_reference, received_date, location_bin,
          created_by_auth_user_id
        ) values (
          v_receipt_batch_id, v_batch_id, v_supplier_id, v_supplier_code,
          v_supplier_name, v_source_type, v_supplier_reference,
          v_normalized_reference, v_received_date, v_location_bin, v_actor
        );
        v_created_receipt_batches := v_created_receipt_batches + 1;
      end if;
    end if;

    v_import_row_id := gen_random_uuid();
    insert into public.v1_inventory_import_rows (
      id, import_batch_id, source_row_number, inventory_item_id, category_id,
      source_category_text, stock_action, quantity, reason, created_item
    ) values (
      v_import_row_id, v_batch_id, v_row_number, v_item_id,
      v_resolved_category_id, v_source_category, v_action, v_quantity,
      v_reason, v_created_item
    );

    if v_receipt_batch_id is not null then
      v_receipt_line_id := gen_random_uuid();
      insert into public.v1_supplier_receipt_lines (
        id, receipt_batch_id, inventory_item_id, source_row_number,
        item_code_snapshot, item_description_snapshot, category_name_snapshot,
        size_snapshot, model_tag_snapshot, brand_origin_snapshot,
        ral_colour_snapshot, unit_snapshot, accepted_qty, damaged_qty,
        rejected_qty, tracking_mode, serial_number, batch_lot_number,
        location_bin_snapshot, notes_snapshot
      ) values (
        v_receipt_line_id, v_receipt_batch_id, v_item_id, v_row_number,
        v_item_code, v_description, v_category_name, v_size_snapshot,
        v_model_tag_snapshot, v_brand_origin, v_ral_colour_snapshot, v_unit,
        v_accepted, v_damaged, v_rejected, v_tracking_mode, v_serial_number,
        v_batch_lot_number, v_location_bin, v_notes
      );
      if v_unit_price is not null then
        insert into public.v1_supplier_receipt_line_commercials (
          receipt_line_id, currency_code, unit_price, created_by_auth_user_id
        ) values (v_receipt_line_id, v_currency_code, v_unit_price, v_actor);
      end if;
    end if;

    select * into v_balance from public.v1_inventory_balances
    where inventory_item_id = v_item_id for update;
    select coalesce(sum(reservation.reserved_qty - reservation.consumed_qty), 0)
      into v_reserved
    from public.v1_inventory_reservations reservation
    where reservation.inventory_item_id = v_item_id
      and reservation.state in ('active', 'partially_consumed');
    -- Stable R38.9 imports only receive stock. Stock removal remains an
    -- explicit inventory command and cannot be expressed by an import row.
    v_delta := v_accepted;
    if v_action = 'opening_balance' and v_balance.on_hand_qty <> 0 then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_OPENING_BALANCE_CONFLICT:%',
        v_row_number using errcode = '40001';
    end if;
    if v_balance.on_hand_qty + v_delta < v_reserved then
      raise exception 'V1_INVENTORY_IMPORT_R38_9_BELOW_RESERVED:%', v_row_number
        using errcode = '22023';
    end if;
    if v_delta <> 0 then
      update public.v1_inventory_balances
      set on_hand_qty = on_hand_qty + v_delta,
          record_version = record_version + 1,
          updated_at = clock_timestamp()
      where inventory_item_id = v_item_id;
      v_movement_type := case v_action
        when 'opening_balance' then 'opening_balance'
        when 'add_stock' then 'supplier_receipt'
        else 'adjustment'
      end;
      insert into public.v1_inventory_movements (
        inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
        source_entity_type, source_entity_id, reason, actor_auth_user_id,
        idempotency_key
      ) values (
        v_item_id, v_movement_type, v_delta, v_balance.on_hand_qty + v_delta,
        case when v_receipt_line_id is not null then 'supplier_receipt_line'
          else 'inventory_import' end,
        coalesce(v_receipt_line_id, v_batch_id), v_reason, v_actor,
        gen_random_uuid()
      );
      v_movement_count := v_movement_count + 1;
    end if;

    insert into public.v1_inventory_import_row_results (
      import_batch_id, import_row_id, source_row_number, supplier_id,
      receipt_batch_id, receipt_line_id, source_supplier_text, accepted_qty,
      damaged_qty, rejected_qty, warning_codes, supplier_name_snapshot,
      supplier_resolution_snapshot, source_type_snapshot, raw_source_values
    ) values (
      v_batch_id, v_import_row_id, v_row_number, v_supplier_id,
      v_receipt_batch_id, v_receipt_line_id, v_source_supplier_text,
      v_accepted, v_damaged, v_rejected, v_warnings,
      coalesce(v_supplier_name_snapshot, v_supplier_name),
      v_supplier_resolution_snapshot,
      coalesce(nullif(btrim(v_row ->> 'source_type_text'), ''), v_source_type),
      v_raw_source_values
    );
    v_warning_count := v_warning_count + cardinality(v_warnings);
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object(
    'unit', totals.unit_snapshot,
    'accepted_qty', totals.accepted_qty::text,
    'damaged_qty', totals.damaged_qty::text,
    'rejected_qty', totals.rejected_qty::text
  ) order by totals.unit_snapshot), '[]'::jsonb)
  into v_unit_totals
  from (
    select line.unit_snapshot,
      sum(line.accepted_qty) accepted_qty,
      sum(line.damaged_qty) damaged_qty,
      sum(line.rejected_qty) rejected_qty
    from public.v1_supplier_receipt_lines line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = line.receipt_batch_id
    where receipt_batch.import_batch_id = v_batch_id
    group by line.unit_snapshot
  ) totals;

  v_response := jsonb_build_object(
    'import_batch_id', v_batch_id,
    'file_name', v_file_name,
    'file_sha256', v_file_sha256,
    'import_mode', v_import_mode,
    'opening_balance_as_of_date', v_opening_balance_as_of_date,
    'row_count', jsonb_array_length(v_rows)::text,
    'created_items', v_created_items::text,
    'updated_items', v_updated_items::text,
    'created_categories', v_created_categories::text,
    'created_suppliers', v_created_suppliers::text,
    'receipt_batches', v_created_receipt_batches::text,
    'movements', v_movement_count::text,
    'unknown_supplier_rows', v_unknown_supplier_rows::text,
    'warning_count', v_warning_count::text,
    'excluded_count', '0',
    'unit_totals', v_unit_totals,
    'committed', true
  );
  insert into public.v1_inventory_import_results (
    import_batch_id, file_sha256, import_mode, response_json, warning_count
  ) values (
    v_batch_id, v_file_sha256, v_import_mode, v_response, v_warning_count
  );

  for v_batch_record in
    select receipt_batch.id, receipt_batch.supplier_id,
      receipt_batch.supplier_reference, receipt_batch.received_date,
      receipt_batch.location_bin
    from public.v1_supplier_receipt_batches receipt_batch
    where receipt_batch.import_batch_id = v_batch_id
    order by receipt_batch.id
  loop
    perform public.v1_write_audit_event(
      'supplier_receipt_committed', 'supplier_receipt_batch',
      v_batch_record.id, null, null,
      jsonb_build_object(
        'supplier_id', v_batch_record.supplier_id,
        'supplier_reference', v_batch_record.supplier_reference,
        'received_date', v_batch_record.received_date,
        'location_bin', v_batch_record.location_bin,
        'import_batch_id', v_batch_id
      ), 'Supplier receipt committed by reviewed inventory import',
      gen_random_uuid()
    );
  end loop;
  perform public.v1_write_audit_event(
    'inventory_supplier_imported', 'inventory_import', v_batch_id, null,
    null, v_response, v_file_name, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_import_inventory_r38_9', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_supplier_name_key(text)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_reference_key(text)
  from public, anon, authenticated;
revoke all on function public.v1_protect_unknown_supplier()
  from public, anon, authenticated;
revoke all on function public.v1_resolve_inventory_supplier_r38_9(
  uuid,text,text,uuid,integer
)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_directory_projection(text,text,integer,integer)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_folder_projection(uuid,text,integer,integer)
  from public, anon, authenticated;
revoke all on function public.v1_create_supplier(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_import_inventory_r38_9(jsonb,uuid)
  from public, anon, authenticated;

grant execute on function public.v1_supplier_directory_projection(text,text,integer,integer)
  to authenticated, service_role;
grant execute on function public.v1_supplier_folder_projection(uuid,text,integer,integer)
  to authenticated, service_role;
grant execute on function public.v1_create_supplier(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_import_inventory_r38_9(jsonb,uuid)
  to authenticated, service_role;

alter table public.v1_document_links
  drop constraint if exists v1_document_links_entity_type_check;
alter table public.v1_document_links
  add constraint v1_document_links_entity_type_check check (entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
    'material_return', 'delivery_order', 'rental_property', 'supplier',
    'supplier_receipt_batch'
  ));
alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_target_entity_type_check;
alter table public.v1_document_upload_intents
  add constraint v1_document_upload_intents_target_entity_type_check check (
    target_entity_type in (
      'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
      'material_return', 'delivery_order', 'rental_property', 'supplier',
      'supplier_receipt_batch'
    )
  );

create index if not exists v1_document_links_supplier_current_idx
  on public.v1_document_links (entity_type, entity_id, linked_at desc)
  where entity_type in ('supplier', 'supplier_receipt_batch')
    and removed_at is null;

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
      return v_project_id is not null and public.v1_project_readable(v_project_id);
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
      select request_id into v_request_id from public.v1_material_returns
      where id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
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

create or replace function public.v1_document_target_writable(
  p_entity_type text,
  p_entity_id uuid,
  p_classification text
) returns boolean
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
  if not public.v1_document_target_readable(p_entity_type, p_entity_id)
    or not public.v1_document_classification_writable(p_classification) then
    return false;
  end if;
  if p_entity_type = 'rental_property' then
    return p_classification = 'commercial' and exists (
      select 1 from public.v1_rental_properties property_record
      where property_record.id = p_entity_id and not property_record.is_archived
    );
  end if;
  if p_entity_type = 'receipt_review' then
    return p_classification = 'operational'
      and v_role in ('project_engineer', 'site_engineer', 'admin')
      and exists (
        select 1 from public.v1_receipt_reviews review
        where review.id = p_entity_id and review.state = 'confirmed'
      );
  end if;
  if p_entity_type = 'supplier' then
    return (
        p_classification = 'operational'
        or (p_classification = 'commercial'
          and public.v1_has_capability('manage_commercials'))
        or (p_classification = 'admin_restricted' and v_role = 'admin')
      )
      and public.v1_can_manage_inventory()
      and exists (
        select 1 from public.v1_suppliers supplier
        where supplier.id = p_entity_id
      );
  end if;
  if p_entity_type = 'supplier_receipt_batch' then
    return (
        p_classification = 'operational'
        or (p_classification = 'commercial'
          and public.v1_has_capability('manage_commercials'))
        or (p_classification = 'admin_restricted' and v_role = 'admin')
      )
      and public.v1_can_manage_inventory()
      and exists (
        select 1 from public.v1_supplier_receipt_batches receipt_batch
        where receipt_batch.id = p_entity_id and receipt_batch.state = 'committed'
      );
  end if;
  v_project_id := public.v1_document_target_project_id(p_entity_type, p_entity_id);
  select state into v_project_state from public.v1_projects where id = v_project_id;
  return v_project_state in ('draft', 'active', 'on_hold', 'completed');
end;
$$;

create or replace function public.v1_prepare_supplier_document_upload(
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
  v_supplier_id uuid;
  v_entity_type text;
  v_entity_id uuid;
  v_document_id uuid;
  v_document public.v1_documents%rowtype;
  v_revision integer;
  v_classification text;
  v_file_name text;
  v_mime_type text;
  v_byte_size bigint;
  v_sha256 text;
  v_origin text;
  v_source_entity_type text;
  v_source_entity_id uuid;
  v_source_revision text;
  v_intent_id uuid := gen_random_uuid();
  v_expires_at timestamptz := clock_timestamp() + interval '15 minutes';
  v_object_path text;
  v_response jsonb;
  v_existing jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'entity_type', 'entity_id', 'document_id',
      'classification', 'file_name', 'mime_type', 'byte_size', 'sha256',
      'origin', 'source_entity_type', 'source_entity_id', 'source_revision'
    ],
    'supplier_document_upload'
  );
  begin
    v_supplier_id := nullif(p_payload ->> 'project_id', '')::uuid;
    v_entity_id := nullif(p_payload ->> 'entity_id', '')::uuid;
    v_document_id := nullif(p_payload ->> 'document_id', '')::uuid;
    v_byte_size := nullif(p_payload ->> 'byte_size', '')::bigint;
    v_source_entity_id := nullif(p_payload ->> 'source_entity_id', '')::uuid;
  exception when others then
    raise exception 'V1_SUPPLIER_DOCUMENT_UPLOAD_PAYLOAD_INVALID'
      using errcode = '22023';
  end;
  v_entity_type := nullif(btrim(p_payload ->> 'entity_type'), '');
  v_classification := nullif(btrim(p_payload ->> 'classification'), '');
  v_file_name := nullif(btrim(p_payload ->> 'file_name'), '');
  v_mime_type := nullif(btrim(p_payload ->> 'mime_type'), '');
  v_sha256 := lower(nullif(btrim(p_payload ->> 'sha256'), ''));
  v_origin := nullif(btrim(p_payload ->> 'origin'), '');
  v_source_entity_type := nullif(btrim(p_payload ->> 'source_entity_type'), '');
  v_source_revision := nullif(btrim(p_payload ->> 'source_revision'), '');

  if v_supplier_id is null
    or v_entity_type not in ('supplier', 'supplier_receipt_batch')
    or v_entity_id is null
    or v_classification not in (
      'operational', 'commercial', 'admin_restricted'
    )
    or v_file_name is null or length(v_file_name) > 180
    or position('/' in v_file_name) > 0 or position(chr(92) in v_file_name) > 0
    or v_mime_type not in (
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg', 'image/png'
    )
    or v_byte_size is null or v_byte_size <= 0 or v_byte_size > 20971520
    or v_sha256 is null or v_sha256 !~ '^[a-f0-9]{64}$'
    or v_origin <> 'uploaded'
    or v_source_entity_type is not null or v_source_entity_id is not null
    or v_source_revision is not null
    or not exists(
      select 1 from public.v1_suppliers supplier
      where supplier.id = v_supplier_id
    )
    or (v_entity_type = 'supplier' and v_entity_id <> v_supplier_id)
    or (v_entity_type = 'supplier_receipt_batch' and not exists(
      select 1 from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.id = v_entity_id
        and receipt_batch.supplier_id = v_supplier_id
        and receipt_batch.state = 'committed'
    )) then
    raise exception 'V1_SUPPLIER_DOCUMENT_UPLOAD_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  if not public.v1_document_target_writable(
    v_entity_type, v_entity_id, v_classification
  ) then
    raise exception 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED' using errcode = '42501';
  end if;

  if v_document_id is not null then
    select * into v_document from public.v1_documents
    where id = v_document_id for update;
    if not found or v_document.classification <> v_classification
      or not public.v1_document_writable(v_document_id)
      or not exists (
        select 1 from public.v1_document_links link
        where link.document_id = v_document_id
          and link.entity_type = v_entity_type
          and link.entity_id = v_entity_id
          and link.removed_at is null
      ) then
      raise exception 'V1_SUPPLIER_DOCUMENT_VERSION_WRITE_DENIED'
        using errcode = '42501';
    end if;
    select coalesce(max(revision_number), 0) + 1 into v_revision
    from public.v1_document_versions where document_id = v_document_id;
  else
    v_revision := 1;
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_prepare_document_upload', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_object_path := 'documents/suppliers/' || v_supplier_id::text || '/'
    || v_intent_id::text || '/content';
  insert into public.v1_document_upload_intents (
    id, project_id, target_entity_type, target_entity_id, document_id,
    planned_revision_number, classification, original_file_name, mime_type,
    byte_size, expected_sha256, origin, source_entity_type, source_entity_id,
    source_revision, object_path, actor_auth_user_id, actor_role,
    idempotency_key, expires_at
  ) values (
    v_intent_id, null, v_entity_type, v_entity_id, v_document_id,
    v_revision, v_classification, v_file_name, v_mime_type, v_byte_size,
    v_sha256, 'uploaded', null, null, null, v_object_path,
    v_actor, v_role, p_idempotency_key, v_expires_at
  );
  v_response := jsonb_build_object(
    'upload_intent_id', v_intent_id,
    'bucket_id', 'yorks-documents',
    'object_path', v_object_path,
    'mime_type', v_mime_type,
    'byte_size', v_byte_size,
    'expires_at', v_expires_at,
    'planned_revision_number', v_revision
  );
  perform public.v1_complete_idempotency(
    'v1_prepare_document_upload', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_supplier_document_workspace_projection(
  p_supplier_id uuid,
  p_receipt_batch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_document_target_readable('supplier', p_supplier_id)
    or (p_receipt_batch_id is not null and not exists(
      select 1 from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.id = p_receipt_batch_id
        and receipt_batch.supplier_id = p_supplier_id
    )) then
    raise exception 'V1_SUPPLIER_DOCUMENT_WORKSPACE_DENIED'
      using errcode = '42501';
  end if;
  return jsonb_build_object(
    -- The shared client calls this routing value project_id. It identifies the
    -- supplier workspace only; document links/intents persist project_id null.
    'project_id', p_supplier_id,
    'documents', coalesce((
      select jsonb_agg(document_projection order by document_uploaded_at desc)
      from (
        select jsonb_build_object(
          'id', document_record.id,
          'classification', document_record.classification,
          'created_at', document_record.created_at,
          'current_version', jsonb_build_object(
            'id', version_record.id,
            'revision_number', version_record.revision_number,
            'bucket_id', version_record.bucket_id,
            'object_path', version_record.object_path,
            'original_file_name', version_record.original_file_name,
            'mime_type', version_record.mime_type,
            'byte_size', version_record.byte_size,
            'sha256', version_record.sha256,
            'origin', version_record.origin,
            'source_entity_type', version_record.source_entity_type,
            'source_entity_id', version_record.source_entity_id,
            'source_revision', version_record.source_revision,
            'uploaded_at', version_record.uploaded_at,
            'uploaded_by_auth_user_id', version_record.uploaded_by_auth_user_id,
            'uploaded_by_role', version_record.uploaded_by_role,
            'uploaded_by_display_name', public.v1_safe_profile_display_name(
              profile.display_name, profile.auth_user_id
            )
          ),
          'links', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', link.id,
              'project_id', p_supplier_id,
              'entity_type', link.entity_type,
              'entity_id', link.entity_id,
              'linked_at', link.linked_at,
              'cross_project_reason', link.cross_project_reason
            ) order by link.linked_at, link.id)
            from public.v1_document_links link
            where link.document_id = document_record.id
              and link.removed_at is null
              and (
                (link.entity_type = 'supplier'
                  and link.entity_id = p_supplier_id)
                or
                (link.entity_type = 'supplier_receipt_batch' and exists(
                  select 1
                  from public.v1_supplier_receipt_batches receipt_batch
                  where receipt_batch.id = link.entity_id
                    and receipt_batch.supplier_id = p_supplier_id
                ))
              )
          ), '[]'::jsonb)
        ) document_projection,
        version_record.uploaded_at document_uploaded_at
        from public.v1_documents document_record
        join public.v1_document_versions version_record
          on version_record.id = document_record.current_version_id
        join public.v1_profiles profile
          on profile.auth_user_id = version_record.uploaded_by_auth_user_id
        where public.v1_document_readable(document_record.id)
          and exists(
            select 1 from public.v1_document_links target_link
            where target_link.document_id = document_record.id
              and target_link.removed_at is null
              and (
                (p_receipt_batch_id is null
                  and target_link.entity_type = 'supplier'
                  and target_link.entity_id = p_supplier_id)
                or
                (target_link.entity_type = 'supplier_receipt_batch'
                  and (p_receipt_batch_id is null
                    or target_link.entity_id = p_receipt_batch_id)
                  and exists(
                    select 1
                    from public.v1_supplier_receipt_batches receipt_batch
                    where receipt_batch.id = target_link.entity_id
                      and receipt_batch.supplier_id = p_supplier_id
                  ))
              )
          )
      ) documents
    ), '[]'::jsonb),
    'audit_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', audit.id,
        'event_type', audit.event_type,
        'entity_type', audit.entity_type,
        'entity_id', audit.entity_id,
        'occurred_at', audit.occurred_at,
        'actor_auth_user_id', audit.actor_auth_user_id,
        'actor_display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'actor_role', audit.actor_role,
        'reason', audit.reason
      ) order by audit.occurred_at desc, audit.id desc)
      from public.v1_audit_events audit
      join public.v1_profiles profile
        on profile.auth_user_id = audit.actor_auth_user_id
      where audit.after_data ->> 'document_id' in (
        select document_record.id::text
        from public.v1_documents document_record
        where public.v1_document_readable(document_record.id)
          and exists(
            select 1 from public.v1_document_links target_link
            where target_link.document_id = document_record.id
              and target_link.removed_at is null
              and (
                (p_receipt_batch_id is null
                  and target_link.entity_type = 'supplier'
                  and target_link.entity_id = p_supplier_id)
                or
                (target_link.entity_type = 'supplier_receipt_batch'
                  and (p_receipt_batch_id is null
                    or target_link.entity_id = p_receipt_batch_id)
                  and exists(
                    select 1
                    from public.v1_supplier_receipt_batches receipt_batch
                    where receipt_batch.id = target_link.entity_id
                      and receipt_batch.supplier_id = p_supplier_id
                  ))
              )
          )
      )
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_prepare_supplier_document_upload(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_document_workspace_projection(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.v1_prepare_supplier_document_upload(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_supplier_document_workspace_projection(uuid,uuid)
  to authenticated, service_role;

-- Shared operational supplier identity used by the two traceability
-- projections below. It deliberately contains no contact, invoice, price or
-- other commercial field and is not directly callable by application roles.
create or replace function public.v1_supplier_trace_header_r38_9(
  p_supplier_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', supplier.id,
    'supplier_code', supplier.supplier_code,
    'canonical_name', supplier.name,
    'description', supplier.notes,
    'status', case when supplier.is_system then 'identity_missing'
      else supplier.status end,
    'is_system_unknown', supplier.is_system,
    'receipt_batch_count', (
      select count(*)::text
      from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.supplier_id = supplier.id
        and receipt_batch.state = 'committed'
    ),
    'distinct_item_count', (
      select count(distinct receipt_line.inventory_item_id)::text
      from public.v1_supplier_receipt_lines receipt_line
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      where receipt_batch.supplier_id = supplier.id
        and receipt_batch.state = 'committed'
    ),
    'missing_document_count', (
      select count(*)::text
      from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.supplier_id = supplier.id
        and receipt_batch.state = 'committed'
        and not exists(
          select 1
          from public.v1_document_links document_link
          where document_link.entity_type = 'supplier_receipt_batch'
            and document_link.entity_id = receipt_batch.id
            and document_link.removed_at is null
            and public.v1_document_readable(document_link.document_id)
        )
    ),
    'reconciliation_count', case when supplier.is_system then
      public.v1_supplier_reconciliation_count_r38_9(supplier.id)::text
      else '0' end,
    'last_receipt_at', (
      select max(receipt_batch.created_at)::text
      from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.supplier_id = supplier.id
        and receipt_batch.state = 'committed'
    ),
    'aliases', coalesce((
      select jsonb_agg(supplier_alias.alias_name
        order by supplier_alias.alias_name, supplier_alias.id)
      from public.v1_supplier_aliases supplier_alias
      where supplier_alias.supplier_id = supplier.id
    ), '[]'::jsonb),
    'record_version', supplier.record_version::text
  )
  from public.v1_suppliers supplier
  where supplier.id = p_supplier_id;
$$;

create or replace function public.v1_supplier_item_trail_projection(
  p_supplier_id uuid,
  p_inventory_item_id uuid,
  p_section text default 'receipt_lines',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_supplier jsonb;
  v_item jsonb;
  v_section text := lower(coalesce(nullif(btrim(p_section), ''), 'receipt_lines'));
  v_limit integer := coalesce(p_limit, 50);
  v_offset integer := coalesce(p_offset, 0);
  v_total integer := 0;
  v_receipt_lines jsonb := '[]'::jsonb;
  v_movements jsonb := '[]'::jsonb;
  v_reservations jsonb := '[]'::jsonb;
  v_destinations jsonb := '[]'::jsonb;
  v_provenance_gaps jsonb := '[]'::jsonb;
  v_activity jsonb := '[]'::jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_ITEM_TRAIL_DENIED' using errcode = '42501';
  end if;
  if p_supplier_id is null or p_inventory_item_id is null
    or v_section not in (
      'receipt_lines', 'movements', 'reservations', 'destinations',
      'provenance_gaps', 'activity'
    )
    or v_limit < 1 or v_limit > 100
    or v_offset < 0 or v_offset > 100000 then
    raise exception 'V1_SUPPLIER_ITEM_TRAIL_ARGUMENT_INVALID'
      using errcode = '22023';
  end if;
  if not exists(
    select 1
    from public.v1_supplier_receipt_lines receipt_line
    join public.v1_supplier_receipt_batches receipt_batch
      on receipt_batch.id = receipt_line.receipt_batch_id
    where receipt_batch.supplier_id = p_supplier_id
      and receipt_line.inventory_item_id = p_inventory_item_id
  ) then
    raise exception 'V1_SUPPLIER_ITEM_TRAIL_NOT_FOUND' using errcode = '22023';
  end if;

  v_supplier := public.v1_supplier_trace_header_r38_9(p_supplier_id);
  select jsonb_build_object(
    'id', inventory_item.id,
    'item_code', coalesce(inventory_item.item_code,
      'INV-' || upper(substr(replace(inventory_item.id::text, '-', ''), 1, 8))),
    'item_description', inventory_item.item_description,
    'brand_origin', inventory_item.brand_origin,
    'size', inventory_item.size_text,
    'model_tag', inventory_item.model_reference,
    'unit', inventory_item.unit,
    'current_on_hand', inventory_balance.on_hand_qty::text,
    'reserved_quantity', coalesce((
      select sum(reservation.reserved_qty - reservation.consumed_qty)
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = inventory_item.id
        and reservation.state in ('active', 'partially_consumed')
    ), 0)::text,
    'available_quantity', (
      inventory_balance.on_hand_qty - coalesce((
        select sum(reservation.reserved_qty - reservation.consumed_qty)
        from public.v1_inventory_reservations reservation
        where reservation.inventory_item_id = inventory_item.id
          and reservation.state in ('active', 'partially_consumed')
      ), 0)
    )::text
  ) into v_item
  from public.v1_inventory_items inventory_item
  join public.v1_inventory_balances inventory_balance
    on inventory_balance.inventory_item_id = inventory_item.id
  where inventory_item.id = p_inventory_item_id;

  v_total := case v_section
    when 'receipt_lines' then (
      select count(*)::integer
      from public.v1_supplier_receipt_lines receipt_line
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      where receipt_batch.supplier_id = p_supplier_id
        and receipt_line.inventory_item_id = p_inventory_item_id
    )
    when 'movements' then (
      select count(*)::integer from public.v1_inventory_movements movement
      where movement.inventory_item_id = p_inventory_item_id
    )
    when 'reservations' then (
      select count(*)::integer from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = p_inventory_item_id
    )
    when 'destinations' then (
      select count(*)::integer
      from public.v1_dispatch_batch_allocations allocation
      join public.v1_supplier_receipt_lines receipt_line
        on receipt_line.id = allocation.receipt_line_id
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      where receipt_batch.supplier_id = p_supplier_id
        and receipt_line.inventory_item_id = p_inventory_item_id
    )
    when 'provenance_gaps' then (
      select count(*)::integer
      from public.v1_dispatch_batch_allocation_gaps provenance_gap
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = provenance_gap.dispatch_line_id
      where dispatch_line.inventory_item_id = p_inventory_item_id
    )
    when 'activity' then (
      select count(*)::integer
      from public.v1_audit_events audit_event
      where (audit_event.entity_type = 'inventory_item'
          and audit_event.entity_id = p_inventory_item_id)
        or (audit_event.entity_type = 'supplier_receipt_batch'
          and audit_event.entity_id in (
            select receipt_batch.id
            from public.v1_supplier_receipt_batches receipt_batch
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.receipt_batch_id = receipt_batch.id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          ))
        or (audit_event.entity_type = 'inventory_import'
          and audit_event.entity_id in (
            select receipt_batch.import_batch_id
            from public.v1_supplier_receipt_batches receipt_batch
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.receipt_batch_id = receipt_batch.id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          ))
        or (audit_event.entity_type in ('dispatch', 'material_dispatch')
          and audit_event.entity_id in (
            select dispatch_line.dispatch_id
            from public.v1_dispatch_batch_allocations allocation
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.id = allocation.receipt_line_id
            join public.v1_supplier_receipt_batches receipt_batch
              on receipt_batch.id = receipt_line.receipt_batch_id
            join public.v1_material_dispatch_lines dispatch_line
              on dispatch_line.id = allocation.dispatch_line_id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          ))
    )
  end;

  return jsonb_build_object(
    'supplier', v_supplier,
    'item', v_item,
    'section', v_section,
    'total_count', v_total::text,
    'limit', v_limit::text,
    'offset', v_offset::text,
    'receipt_lines', case when v_section = 'receipt_lines' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', receipt_line.id,
        'receipt_batch_id', receipt_batch.id,
        'receipt_number', 'RCV-' || upper(substr(
          replace(receipt_batch.id::text, '-', ''), 1, 8
        )),
        'source_type', receipt_batch.source_type,
        'supplier_reference', receipt_batch.supplier_reference,
        'received_date', receipt_batch.received_date,
        'warehouse_location', coalesce(receipt_batch.location_bin, 'Warehouse'),
        'source_row_number', receipt_line.source_row_number::text,
        'delivered_quantity', receipt_line.delivered_qty::text,
        'accepted_quantity', receipt_line.accepted_qty::text,
        'damaged_quantity', receipt_line.damaged_qty::text,
        'rejected_quantity', receipt_line.rejected_qty::text,
        'allocated_quantity', coalesce((
          select sum(allocation.allocated_qty)
          from public.v1_dispatch_batch_allocations allocation
          where allocation.receipt_line_id = receipt_line.id
        ), 0)::text,
        'returned_quantity', coalesce((
          select sum(return_attribution.returned_qty)
          from public.v1_material_return_batch_allocations return_attribution
          join public.v1_dispatch_batch_receipt_allocations receipt_attribution
            on receipt_attribution.id = return_attribution.receipt_attribution_id
          join public.v1_dispatch_batch_allocations allocation
            on allocation.id = receipt_attribution.dispatch_allocation_id
          where allocation.receipt_line_id = receipt_line.id
        ), 0)::text,
        'remaining_accepted_quantity', greatest(
          receipt_line.accepted_qty - coalesce((
            select sum(allocation.allocated_qty)
            from public.v1_dispatch_batch_allocations allocation
            where allocation.receipt_line_id = receipt_line.id
          ), 0) + coalesce((
            select sum(return_attribution.returned_qty)
            from public.v1_material_return_batch_allocations return_attribution
            join public.v1_dispatch_batch_receipt_allocations receipt_attribution
              on receipt_attribution.id = return_attribution.receipt_attribution_id
            join public.v1_dispatch_batch_allocations allocation
              on allocation.id = receipt_attribution.dispatch_allocation_id
            where allocation.receipt_line_id = receipt_line.id
          ), 0), 0
        )::text,
        'unit', receipt_line.unit_snapshot,
        'tracking_mode', receipt_line.tracking_mode,
        'serial_number', receipt_line.serial_number,
        'batch_lot_number', receipt_line.batch_lot_number
      ) order by receipt_batch.received_date, receipt_batch.created_at,
        receipt_batch.id, receipt_line.source_row_number, receipt_line.id)
      from public.v1_supplier_receipt_lines receipt_line
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      where receipt_batch.supplier_id = p_supplier_id
        and receipt_line.inventory_item_id = p_inventory_item_id
        and receipt_line.id in (
          select receipt_line_page.id
          from public.v1_supplier_receipt_lines receipt_line_page
          join public.v1_supplier_receipt_batches receipt_batch_page
            on receipt_batch_page.id = receipt_line_page.receipt_batch_id
          where receipt_batch_page.supplier_id = p_supplier_id
            and receipt_line_page.inventory_item_id = p_inventory_item_id
          order by receipt_batch_page.received_date,
            receipt_batch_page.created_at, receipt_batch_page.id,
            receipt_line_page.source_row_number, receipt_line_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'movements', case when v_section = 'movements' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', movement.id,
        'movement_type', movement.movement_type,
        'quantity_delta', movement.quantity_delta::text,
        'on_hand_after_quantity', movement.on_hand_after_qty::text,
        'source_entity_type', movement.source_entity_type,
        'source_entity_id', movement.source_entity_id,
        'reason', movement.reason,
        'actor_display_name', public.v1_safe_profile_display_name(
          actor_profile.display_name, movement.actor_auth_user_id
        ),
        'created_at', movement.created_at
      ) order by movement.created_at, movement.id)
      from public.v1_inventory_movements movement
      left join public.v1_profiles actor_profile
        on actor_profile.auth_user_id = movement.actor_auth_user_id
      where movement.inventory_item_id = p_inventory_item_id
        and movement.id in (
          select movement_page.id
          from public.v1_inventory_movements movement_page
          where movement_page.inventory_item_id = p_inventory_item_id
          order by movement_page.created_at, movement_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'reservations', case when v_section = 'reservations' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', reservation.id,
        'request_id', material_request.id,
        'request_number', coalesce(material_request.request_number,
          'Request pending number'),
        'project_id', project.id,
        'project_reference', project.project_ref,
        'project_name', project.name,
        'scope_id', project_scope.id,
        'scope_name', project_scope.name,
        'reserved_quantity', reservation.reserved_qty::text,
        'consumed_quantity', reservation.consumed_qty::text,
        'remaining_quantity', greatest(
          reservation.reserved_qty - reservation.consumed_qty, 0
        )::text,
        'unit', inventory_item.unit,
        'state', reservation.state,
        'created_at', reservation.created_at
      ) order by reservation.created_at, reservation.id)
      from public.v1_inventory_reservations reservation
      join public.v1_inventory_items inventory_item
        on inventory_item.id = reservation.inventory_item_id
      join public.v1_material_requests material_request
        on material_request.id = reservation.request_id
      join public.v1_projects project on project.id = material_request.project_id
      join public.v1_project_scopes project_scope
        on project_scope.id = material_request.scope_id
      where reservation.inventory_item_id = p_inventory_item_id
        and reservation.id in (
          select reservation_page.id
          from public.v1_inventory_reservations reservation_page
          where reservation_page.inventory_item_id = p_inventory_item_id
          order by reservation_page.created_at, reservation_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'destinations', case when v_section = 'destinations' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'allocation_id', allocation.id,
        'receipt_line_id', receipt_line.id,
        'receipt_batch_id', receipt_batch.id,
        'dispatch_line_id', dispatch_line.id,
        'dispatch_id', dispatch_record.id,
        'dispatch_number', dispatch_record.dispatch_number,
        'request_id', material_request.id,
        'request_number', material_request.request_number,
        'project_id', project.id,
        'project_reference', project.project_ref,
        'project_name', project.name,
        'scope_id', project_scope.id,
        'scope_name', project_scope.name,
        'allocated_quantity', allocation.allocated_qty::text,
        'unit', receipt_line.unit_snapshot,
        'allocation_method', allocation.allocation_method,
        'override_reason', allocation.override_reason,
        'dispatch_state', dispatch_record.state,
        'dispatched_at', dispatch_record.dispatched_at,
        'site_receipt_outcome', receipt_review_line.outcome,
        'good_received_quantity', coalesce(
          receipt_attribution.good_qty, 0
        )::text,
        'exception_quantity', coalesce(
          receipt_attribution.exception_qty, 0
        )::text,
        'confirmed_return_quantity', coalesce((
          select sum(return_attribution.returned_qty)
          from public.v1_material_return_batch_allocations return_attribution
          where return_attribution.receipt_attribution_id =
            receipt_attribution.id
        ), 0)::text,
        'material_return_ids', coalesce((
          select jsonb_agg(distinct return_line.material_return_id)
          from public.v1_material_return_batch_allocations return_attribution
          join public.v1_material_return_lines return_line
            on return_line.id = return_attribution.material_return_line_id
          where return_attribution.receipt_attribution_id =
            receipt_attribution.id
        ), '[]'::jsonb),
        'provenance_state', case
          when receipt_review_line.id is null then 'receipt_pending'
          when receipt_attribution.id is null then 'unproven'
          when dispatch_gap.unallocated_qty is not null
            then 'attributed_with_legacy_gap'
          when receipt_attribution.exception_qty > 0
            then 'attributed_with_exception'
          when coalesce((
            select sum(return_attribution.returned_qty)
            from public.v1_material_return_batch_allocations return_attribution
            where return_attribution.receipt_attribution_id =
              receipt_attribution.id
          ), 0) >= receipt_attribution.good_qty
            and receipt_attribution.good_qty > 0 then 'fully_returned'
          when exists(
            select 1
            from public.v1_material_return_batch_allocations return_attribution
            where return_attribution.receipt_attribution_id =
              receipt_attribution.id
          ) then 'partially_returned'
          else 'attributed'
        end,
        'provenance_reason', case
          when receipt_review_line.id is null then 'receipt_not_confirmed'
          when receipt_attribution.id is null then 'legacy_or_unproven_stock'
          when dispatch_gap.unallocated_qty is not null
            then 'legacy_or_unproven_stock'
          when receipt_attribution.exception_qty > 0
            then receipt_review_line.outcome
          when exists(
            select 1
            from public.v1_material_return_batch_allocations return_attribution
            where return_attribution.receipt_attribution_id =
              receipt_attribution.id
          ) then 'confirmed_material_return'
          else null
        end,
        'dispatch_gap_quantity', coalesce(
          dispatch_gap.unallocated_qty, 0
        )::text,
        'unproven_good_quantity', coalesce(receipt_gap.good_qty, 0)::text,
        'unproven_exception_quantity', coalesce(
          receipt_gap.exception_qty, 0
        )::text,
        'unproven_return_quantity', coalesce((
          select sum(return_gap.returned_qty)
          from public.v1_material_return_batch_allocation_gaps return_gap
          where return_gap.receipt_gap_id = receipt_gap.id
        ), 0)::text
      ) order by dispatch_record.dispatched_at, allocation.id)
      from public.v1_dispatch_batch_allocations allocation
      join public.v1_supplier_receipt_lines receipt_line
        on receipt_line.id = allocation.receipt_line_id
      join public.v1_supplier_receipt_batches receipt_batch
        on receipt_batch.id = receipt_line.receipt_batch_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = allocation.dispatch_line_id
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = dispatch_line.dispatch_id
      join public.v1_material_requests material_request
        on material_request.id = dispatch_record.request_id
      join public.v1_projects project on project.id = material_request.project_id
      join public.v1_project_scopes project_scope
        on project_scope.id = material_request.scope_id
      left join public.v1_receipt_review_lines receipt_review_line
        on receipt_review_line.dispatch_line_id = dispatch_line.id
      left join public.v1_dispatch_batch_receipt_allocations receipt_attribution
        on receipt_attribution.receipt_review_line_id = receipt_review_line.id
          and receipt_attribution.dispatch_allocation_id = allocation.id
      left join public.v1_dispatch_batch_allocation_gaps dispatch_gap
        on dispatch_gap.dispatch_line_id = dispatch_line.id
      left join public.v1_dispatch_batch_receipt_gaps receipt_gap
        on receipt_gap.receipt_review_line_id = receipt_review_line.id
      where receipt_batch.supplier_id = p_supplier_id
        and receipt_line.inventory_item_id = p_inventory_item_id
        and allocation.id in (
          select allocation_page.id
          from public.v1_dispatch_batch_allocations allocation_page
          join public.v1_supplier_receipt_lines receipt_line_page
            on receipt_line_page.id = allocation_page.receipt_line_id
          join public.v1_supplier_receipt_batches receipt_batch_page
            on receipt_batch_page.id = receipt_line_page.receipt_batch_id
          join public.v1_material_dispatch_lines dispatch_line_page
            on dispatch_line_page.id = allocation_page.dispatch_line_id
          join public.v1_material_dispatches dispatch_page
            on dispatch_page.id = dispatch_line_page.dispatch_id
          where receipt_batch_page.supplier_id = p_supplier_id
            and receipt_line_page.inventory_item_id = p_inventory_item_id
          order by dispatch_page.dispatched_at, allocation_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    -- A gap is item-level evidence that cannot truthfully be assigned to this
    -- or any other supplier. Returning it beside the selected supplier trail
    -- makes that uncertainty explicit instead of fabricating attribution.
    'provenance_gaps', case when v_section = 'provenance_gaps' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'dispatch_line_id', dispatch_line.id,
        'dispatch_id', dispatch_record.id,
        'dispatch_number', dispatch_record.dispatch_number,
        'request_number', material_request.request_number,
        'project_reference', project.project_ref,
        'project_name', project.name,
        'scope_name', project_scope.name,
        'unallocated_quantity', provenance_gap.unallocated_qty::text,
        'unit', dispatch_line.unit,
        'reason_code', provenance_gap.reason_code,
        'site_receipt_outcome', receipt_review_line.outcome,
        'good_received_quantity', coalesce(receipt_gap.good_qty, 0)::text,
        'exception_quantity', coalesce(receipt_gap.exception_qty, 0)::text,
        'confirmed_return_quantity', coalesce((
          select sum(return_gap.returned_qty)
          from public.v1_material_return_batch_allocation_gaps return_gap
          where return_gap.receipt_gap_id = receipt_gap.id
        ), 0)::text,
        'provenance_state', case
          when receipt_review_line.id is null then 'receipt_pending_unproven'
          when receipt_gap.id is null then 'unproven'
          when receipt_gap.exception_qty > 0 then 'unproven_with_exception'
          when exists(
            select 1
            from public.v1_material_return_batch_allocation_gaps return_gap
            where return_gap.receipt_gap_id = receipt_gap.id
          ) then 'unproven_partially_returned'
          else 'unproven_received'
        end,
        'recorded_at', provenance_gap.created_at
      ) order by provenance_gap.created_at, dispatch_line.id)
      from public.v1_dispatch_batch_allocation_gaps provenance_gap
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = provenance_gap.dispatch_line_id
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = dispatch_line.dispatch_id
      join public.v1_material_requests material_request
        on material_request.id = dispatch_record.request_id
      join public.v1_projects project on project.id = material_request.project_id
      join public.v1_project_scopes project_scope
        on project_scope.id = material_request.scope_id
      left join public.v1_receipt_review_lines receipt_review_line
        on receipt_review_line.dispatch_line_id = dispatch_line.id
      left join public.v1_dispatch_batch_receipt_gaps receipt_gap
        on receipt_gap.receipt_review_line_id = receipt_review_line.id
      where dispatch_line.inventory_item_id = p_inventory_item_id
        and provenance_gap.dispatch_line_id in (
          select provenance_gap_page.dispatch_line_id
          from public.v1_dispatch_batch_allocation_gaps provenance_gap_page
          join public.v1_material_dispatch_lines dispatch_line_page
            on dispatch_line_page.id = provenance_gap_page.dispatch_line_id
          where dispatch_line_page.inventory_item_id = p_inventory_item_id
          order by provenance_gap_page.created_at,
            provenance_gap_page.dispatch_line_id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'activity', case when v_section = 'activity' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', audit_event.id,
        'event_type', audit_event.event_type,
        'entity_type', audit_event.entity_type,
        'entity_id', audit_event.entity_id,
        'actor_display_name', public.v1_safe_profile_display_name(
          actor_profile.display_name, audit_event.actor_auth_user_id
        ),
        'actor_role', coalesce(
          audit_event.actor_exact_role, audit_event.actor_role
        ),
        'reason', audit_event.reason,
        'occurred_at', audit_event.occurred_at
      ) order by audit_event.occurred_at desc, audit_event.id desc)
      from public.v1_audit_events audit_event
      left join public.v1_profiles actor_profile
        on actor_profile.auth_user_id = audit_event.actor_auth_user_id
      where ((audit_event.entity_type = 'inventory_item'
          and audit_event.entity_id = p_inventory_item_id)
        or (audit_event.entity_type = 'supplier_receipt_batch'
          and audit_event.entity_id in (
            select receipt_batch.id
            from public.v1_supplier_receipt_batches receipt_batch
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.receipt_batch_id = receipt_batch.id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          ))
        or (audit_event.entity_type = 'inventory_import'
          and audit_event.entity_id in (
            select receipt_batch.import_batch_id
            from public.v1_supplier_receipt_batches receipt_batch
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.receipt_batch_id = receipt_batch.id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          ))
        or (audit_event.entity_type in ('dispatch', 'material_dispatch')
          and audit_event.entity_id in (
            select dispatch_line.dispatch_id
            from public.v1_dispatch_batch_allocations allocation
            join public.v1_supplier_receipt_lines receipt_line
              on receipt_line.id = allocation.receipt_line_id
            join public.v1_supplier_receipt_batches receipt_batch
              on receipt_batch.id = receipt_line.receipt_batch_id
            join public.v1_material_dispatch_lines dispatch_line
              on dispatch_line.id = allocation.dispatch_line_id
            where receipt_batch.supplier_id = p_supplier_id
              and receipt_line.inventory_item_id = p_inventory_item_id
          )))
        and audit_event.id in (
          select audit_page.id
          from public.v1_audit_events audit_page
          where (audit_page.entity_type = 'inventory_item'
              and audit_page.entity_id = p_inventory_item_id)
            or (audit_page.entity_type = 'supplier_receipt_batch'
              and audit_page.entity_id in (
                select receipt_batch_page.id
                from public.v1_supplier_receipt_batches receipt_batch_page
                join public.v1_supplier_receipt_lines receipt_line_page
                  on receipt_line_page.receipt_batch_id = receipt_batch_page.id
                where receipt_batch_page.supplier_id = p_supplier_id
                  and receipt_line_page.inventory_item_id = p_inventory_item_id
              ))
            or (audit_page.entity_type = 'inventory_import'
              and audit_page.entity_id in (
                select receipt_batch_page.import_batch_id
                from public.v1_supplier_receipt_batches receipt_batch_page
                join public.v1_supplier_receipt_lines receipt_line_page
                  on receipt_line_page.receipt_batch_id = receipt_batch_page.id
                where receipt_batch_page.supplier_id = p_supplier_id
                  and receipt_line_page.inventory_item_id = p_inventory_item_id
              ))
            or (audit_page.entity_type in ('dispatch', 'material_dispatch')
              and audit_page.entity_id in (
                select dispatch_line_page.dispatch_id
                from public.v1_dispatch_batch_allocations allocation_page
                join public.v1_supplier_receipt_lines receipt_line_page
                  on receipt_line_page.id = allocation_page.receipt_line_id
                join public.v1_supplier_receipt_batches receipt_batch_page
                  on receipt_batch_page.id = receipt_line_page.receipt_batch_id
                join public.v1_material_dispatch_lines dispatch_line_page
                  on dispatch_line_page.id = allocation_page.dispatch_line_id
                where receipt_batch_page.supplier_id = p_supplier_id
                  and receipt_line_page.inventory_item_id = p_inventory_item_id
              ))
          order by audit_page.occurred_at desc, audit_page.id desc
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

revoke all on function public.v1_supplier_trace_header_r38_9(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_item_trail_projection(
  uuid,uuid,text,integer,integer
)
  from public, anon, authenticated;
grant execute on function public.v1_supplier_item_trail_projection(
  uuid,uuid,text,integer,integer
)
  to authenticated, service_role;

create or replace function public.v1_supplier_receipt_batch_detail_projection(
  p_supplier_id uuid,
  p_receipt_batch_id uuid,
  p_section text default 'lines',
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_supplier jsonb;
  v_batch jsonb;
  v_section text := lower(coalesce(nullif(btrim(p_section), ''), 'lines'));
  v_limit integer := coalesce(p_limit, 50);
  v_offset integer := coalesce(p_offset, 0);
  v_total integer := 0;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_RECEIPT_BATCH_DETAIL_DENIED'
      using errcode = '42501';
  end if;
  if p_supplier_id is null or p_receipt_batch_id is null
    or v_section not in ('lines', 'documents', 'activity')
    or v_limit < 1 or v_limit > 100
    or v_offset < 0 or v_offset > 100000 then
    raise exception 'V1_SUPPLIER_RECEIPT_BATCH_DETAIL_ARGUMENT_INVALID'
      using errcode = '22023';
  end if;
  if not exists(
    select 1
    from public.v1_supplier_receipt_batches receipt_batch
    where receipt_batch.id = p_receipt_batch_id
      and receipt_batch.supplier_id = p_supplier_id
  ) then
    raise exception 'V1_SUPPLIER_RECEIPT_BATCH_DETAIL_NOT_FOUND'
      using errcode = '22023';
  end if;

  v_supplier := public.v1_supplier_trace_header_r38_9(p_supplier_id);
  select jsonb_build_object(
    'id', receipt_batch.id,
    'receipt_number', 'RCV-' || upper(substr(
      replace(receipt_batch.id::text, '-', ''), 1, 8
    )),
    'source_type', receipt_batch.source_type,
    'supplier_reference', receipt_batch.supplier_reference,
    'received_date', receipt_batch.received_date,
    'warehouse_location', coalesce(receipt_batch.location_bin, 'Warehouse'),
    'status', receipt_batch.state,
    'line_count', (
      select count(*)::text
      from public.v1_supplier_receipt_lines receipt_line
      where receipt_line.receipt_batch_id = receipt_batch.id
    ),
    'document_count', (
      select count(distinct document_link.document_id)::text
      from public.v1_document_links document_link
      where document_link.entity_type = 'supplier_receipt_batch'
        and document_link.entity_id = receipt_batch.id
        and document_link.removed_at is null
        and public.v1_document_readable(document_link.document_id)
    ),
    'received_by_auth_user_id', receipt_batch.created_by_auth_user_id,
    'received_by_display_name', public.v1_safe_profile_display_name(
      actor_profile.display_name, receipt_batch.created_by_auth_user_id
    ),
    'received_by_role', coalesce((
      select coalesce(audit_event.actor_exact_role, audit_event.actor_role)
      from public.v1_audit_events audit_event
      where audit_event.entity_type = 'supplier_receipt_batch'
        and audit_event.entity_id = receipt_batch.id
      order by audit_event.occurred_at, audit_event.id
      limit 1
    ), 'unknown'),
    'created_at', receipt_batch.created_at,
    'unit_totals', coalesce((
      select jsonb_agg(jsonb_build_object(
        'unit', line_totals.unit_snapshot,
        'delivered_quantity', line_totals.delivered_qty::text,
        'accepted_quantity', line_totals.accepted_qty::text,
        'damaged_quantity', line_totals.damaged_qty::text,
        'rejected_quantity', line_totals.rejected_qty::text
      ) order by line_totals.unit_snapshot)
      from (
        select receipt_line.unit_snapshot,
          sum(receipt_line.delivered_qty) delivered_qty,
          sum(receipt_line.accepted_qty) accepted_qty,
          sum(receipt_line.damaged_qty) damaged_qty,
          sum(receipt_line.rejected_qty) rejected_qty
        from public.v1_supplier_receipt_lines receipt_line
        where receipt_line.receipt_batch_id = receipt_batch.id
        group by receipt_line.unit_snapshot
      ) line_totals
    ), '[]'::jsonb)
  ) into v_batch
  from public.v1_supplier_receipt_batches receipt_batch
  left join public.v1_profiles actor_profile
    on actor_profile.auth_user_id = receipt_batch.created_by_auth_user_id
  where receipt_batch.id = p_receipt_batch_id;

  v_total := case v_section
    when 'lines' then (
      select count(*)::integer
      from public.v1_supplier_receipt_lines receipt_line
      where receipt_line.receipt_batch_id = p_receipt_batch_id
    )
    when 'documents' then (
      select count(distinct document_record.id)::integer
      from public.v1_documents document_record
      where public.v1_document_readable(document_record.id)
        and exists(
          select 1
          from public.v1_document_links document_link
          where document_link.document_id = document_record.id
            and document_link.entity_type = 'supplier_receipt_batch'
            and document_link.entity_id = p_receipt_batch_id
            and document_link.removed_at is null
        )
    )
    when 'activity' then (
      select count(*)::integer
      from public.v1_audit_events audit_event
      where (audit_event.entity_type = 'supplier_receipt_batch'
          and audit_event.entity_id = p_receipt_batch_id)
        or (audit_event.entity_type = 'inventory_import'
          and audit_event.entity_id = (
            select receipt_batch.import_batch_id
            from public.v1_supplier_receipt_batches receipt_batch
            where receipt_batch.id = p_receipt_batch_id
          ))
        or (audit_event.after_data ->> 'document_id') in (
          select document_link.document_id::text
          from public.v1_document_links document_link
          where document_link.entity_type = 'supplier_receipt_batch'
            and document_link.entity_id = p_receipt_batch_id
            and document_link.removed_at is null
        )
    )
  end;

  return jsonb_build_object(
    'supplier', v_supplier,
    'batch', v_batch,
    'section', v_section,
    'total_count', v_total::text,
    'limit', v_limit::text,
    'offset', v_offset::text,
    'lines', case when v_section = 'lines' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', receipt_line.id,
        'inventory_item_id', receipt_line.inventory_item_id,
        'source_row_number', receipt_line.source_row_number::text,
        'item_code', coalesce(receipt_line.item_code_snapshot,
          inventory_item.item_code,
          'INV-' || upper(substr(
            replace(receipt_line.inventory_item_id::text, '-', ''), 1, 8
          ))),
        'item_description', receipt_line.item_description_snapshot,
        'category_name', receipt_line.category_name_snapshot,
        'brand_origin', receipt_line.brand_origin_snapshot,
        'size', receipt_line.size_snapshot,
        'model_tag', receipt_line.model_tag_snapshot,
        'unit', receipt_line.unit_snapshot,
        'delivered_quantity', receipt_line.delivered_qty::text,
        'accepted_quantity', receipt_line.accepted_qty::text,
        'damaged_quantity', receipt_line.damaged_qty::text,
        'rejected_quantity', receipt_line.rejected_qty::text,
        'current_on_hand', inventory_balance.on_hand_qty::text,
        'allocated_quantity', coalesce((
          select sum(allocation.allocated_qty)
          from public.v1_dispatch_batch_allocations allocation
          where allocation.receipt_line_id = receipt_line.id
        ), 0)::text,
        'tracking_mode', receipt_line.tracking_mode,
        'serial_number', receipt_line.serial_number,
        'batch_lot_number', receipt_line.batch_lot_number,
        'location', receipt_line.location_bin_snapshot,
        'notes', receipt_line.notes_snapshot
      ) order by receipt_line.source_row_number, receipt_line.id)
      from public.v1_supplier_receipt_lines receipt_line
      join public.v1_inventory_items inventory_item
        on inventory_item.id = receipt_line.inventory_item_id
      join public.v1_inventory_balances inventory_balance
        on inventory_balance.inventory_item_id = receipt_line.inventory_item_id
      where receipt_line.receipt_batch_id = p_receipt_batch_id
        and receipt_line.id in (
          select receipt_line_page.id
          from public.v1_supplier_receipt_lines receipt_line_page
          where receipt_line_page.receipt_batch_id = p_receipt_batch_id
          order by receipt_line_page.source_row_number, receipt_line_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'documents', case when v_section = 'documents' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'document_id', document_record.id,
        'version_id', document_version.id,
        'file_name', document_version.original_file_name,
        'mime_type', document_version.mime_type,
        'byte_size', document_version.byte_size::text,
        'revision_number', document_version.revision_number::text,
        'classification', document_record.classification,
        'uploaded_at', document_version.uploaded_at,
        'uploaded_by_display_name', public.v1_safe_profile_display_name(
          uploader_profile.display_name,
          document_version.uploaded_by_auth_user_id
        ),
        'receipt_batch_id', p_receipt_batch_id
      ) order by document_version.uploaded_at desc, document_record.id)
      from public.v1_documents document_record
      join public.v1_document_versions document_version
        on document_version.id = document_record.current_version_id
      left join public.v1_profiles uploader_profile
        on uploader_profile.auth_user_id = document_version.uploaded_by_auth_user_id
      where public.v1_document_readable(document_record.id)
        and exists(
          select 1
          from public.v1_document_links document_link
          where document_link.document_id = document_record.id
            and document_link.entity_type = 'supplier_receipt_batch'
            and document_link.entity_id = p_receipt_batch_id
            and document_link.removed_at is null
        )
        and document_record.id in (
          select document_page.id
          from public.v1_documents document_page
          join public.v1_document_versions version_page
            on version_page.id = document_page.current_version_id
          where public.v1_document_readable(document_page.id)
            and exists(
              select 1
              from public.v1_document_links link_page
              where link_page.document_id = document_page.id
                and link_page.entity_type = 'supplier_receipt_batch'
                and link_page.entity_id = p_receipt_batch_id
                and link_page.removed_at is null
            )
          order by version_page.uploaded_at desc, document_page.id
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end,
    'activity', case when v_section = 'activity' then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', audit_event.id,
        'event_type', audit_event.event_type,
        'entity_type', audit_event.entity_type,
        'entity_id', audit_event.entity_id,
        'actor_display_name', public.v1_safe_profile_display_name(
          actor_profile.display_name, audit_event.actor_auth_user_id
        ),
        'actor_role', coalesce(
          audit_event.actor_exact_role, audit_event.actor_role
        ),
        'reason', audit_event.reason,
        'occurred_at', audit_event.occurred_at
      ) order by audit_event.occurred_at desc, audit_event.id desc)
      from public.v1_audit_events audit_event
      left join public.v1_profiles actor_profile
        on actor_profile.auth_user_id = audit_event.actor_auth_user_id
      where ((audit_event.entity_type = 'supplier_receipt_batch'
          and audit_event.entity_id = p_receipt_batch_id)
        or (audit_event.entity_type = 'inventory_import'
          and audit_event.entity_id = (
            select receipt_batch.import_batch_id
            from public.v1_supplier_receipt_batches receipt_batch
            where receipt_batch.id = p_receipt_batch_id
          ))
        or (audit_event.after_data ->> 'document_id') in (
          select document_link.document_id::text
          from public.v1_document_links document_link
          where document_link.entity_type = 'supplier_receipt_batch'
            and document_link.entity_id = p_receipt_batch_id
            and document_link.removed_at is null
        ))
        and audit_event.id in (
          select audit_page.id
          from public.v1_audit_events audit_page
          where (audit_page.entity_type = 'supplier_receipt_batch'
              and audit_page.entity_id = p_receipt_batch_id)
            or (audit_page.entity_type = 'inventory_import'
              and audit_page.entity_id = (
                select receipt_batch_page.import_batch_id
                from public.v1_supplier_receipt_batches receipt_batch_page
                where receipt_batch_page.id = p_receipt_batch_id
              ))
            or (audit_page.after_data ->> 'document_id') in (
              select document_link_page.document_id::text
              from public.v1_document_links document_link_page
              where document_link_page.entity_type = 'supplier_receipt_batch'
                and document_link_page.entity_id = p_receipt_batch_id
                and document_link_page.removed_at is null
            )
          order by audit_page.occurred_at desc, audit_page.id desc
          limit v_limit offset v_offset
        )
    ), '[]'::jsonb) else '[]'::jsonb end
  );
end;
$$;

revoke all on function public.v1_supplier_receipt_batch_detail_projection(
  uuid,uuid,text,integer,integer
)
  from public, anon, authenticated;
grant execute on function public.v1_supplier_receipt_batch_detail_projection(
  uuid,uuid,text,integer,integer
)
  to authenticated, service_role;

-- Supplier documents share the existing private bucket, object verification,
-- immutable version and append-only link finalizer. Their database project_id
-- remains null; the client workspace ID is only a supplier routing value.
--
-- Rollback: revoke the R38.9 RPC grants and disable the client feature.
-- Do not drop supplier, receipt, import-result or allocation relations after
-- activity: they are provenance and append-only audit evidence. Existing
-- v1_import_inventory remains independently available throughout rollback.
