-- Yorks R38.4: authoritative rental property, lease, rent, receipt and cheque
-- registers.  This is intentionally additive: the historical rentalUnits and
-- rentPayments collections remain untouched and readable during rollout.

create table if not exists public.v1_rental_properties (
  id uuid primary key,
  unit_code text not null unique check (
    btrim(unit_code) <> '' and length(unit_code) <= 40
  ),
  property_name text not null check (
    btrim(property_name) <> '' and length(property_name) <= 180
  ),
  property_type text not null check (property_type in (
    'shop', 'warehouse', 'office', 'labour_camp', 'villa', 'other'
  )),
  municipality_number text,
  location text not null check (
    btrim(location) <> '' and length(location) <= 300
  ),
  description text,
  occupancy_state text not null default 'vacant' check (
    occupancy_state in ('vacant', 'occupied')
  ),
  is_archived boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  archived_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  archived_at timestamptz,
  archive_reason text,
  check (
    (is_archived = false and archived_by_auth_user_id is null
      and archived_at is null and archive_reason is null)
    or
    (is_archived = true and archived_by_auth_user_id is not null
      and archived_at is not null and btrim(archive_reason) <> '')
  )
);

create table if not exists public.v1_rental_leases (
  id uuid primary key,
  property_id uuid not null references public.v1_rental_properties (id)
    on delete restrict,
  contract_number text not null unique check (
    btrim(contract_number) <> '' and length(contract_number) <= 80
  ),
  contract_type text not null check (contract_type in (
    'tenancy_contract', 'lease', 'licence', 'other'
  )),
  contract_status text not null check (contract_status in (
    'draft', 'active', 'notice_due', 'expired', 'renewed', 'terminated'
  )),
  tenant_name text not null check (
    btrim(tenant_name) <> '' and length(tenant_name) <= 180
  ),
  trade_licence_number text,
  contact_number text,
  email text,
  signed_date date,
  lease_start date not null,
  lease_end date not null check (lease_end >= lease_start),
  monthly_rent numeric(16,2) not null check (monthly_rent >= 0),
  security_deposit numeric(16,2) not null default 0 check (
    security_deposit >= 0
  ),
  monthly_due_day integer not null default 1 check (
    monthly_due_day between 1 and 31
  ),
  grace_period_days integer not null default 5 check (
    grace_period_days between 0 and 90
  ),
  default_payment_method text not null default 'bank_transfer' check (
    default_payment_method in ('bank_transfer', 'cash', 'cdc', 'pdc', 'other')
  ),
  payment_frequency text not null default 'monthly' check (
    payment_frequency in ('monthly')
  ),
  contract_cheque_count integer not null default 0 check (
    contract_cheque_count between 0 and 240
  ),
  annual_escalation_percent numeric(7,4) not null default 0 check (
    annual_escalation_percent between 0 and 100
  ),
  renewal_notice_days integer not null default 90 check (
    renewal_notice_days between 0 and 730
  ),
  notes text,
  is_current boolean not null default true,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists v1_rental_leases_one_current_idx
  on public.v1_rental_leases (property_id) where is_current;
create index if not exists v1_rental_leases_expiry_idx
  on public.v1_rental_leases (lease_end, renewal_notice_days)
  where is_current and contract_status not in ('renewed', 'terminated');

create table if not exists public.v1_rental_periods (
  id uuid primary key,
  lease_id uuid not null references public.v1_rental_leases (id)
    on delete restrict,
  period_month date not null check (
    period_month = date_trunc('month', period_month)::date
  ),
  due_date date not null,
  amount_due numeric(16,2) not null check (amount_due >= 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (lease_id, period_month)
);

create index if not exists v1_rental_periods_due_idx
  on public.v1_rental_periods (due_date, lease_id);

create table if not exists public.v1_rental_receipts (
  id uuid primary key,
  property_id uuid not null references public.v1_rental_properties (id)
    on delete restrict,
  lease_id uuid not null references public.v1_rental_leases (id)
    on delete restrict,
  period_id uuid not null references public.v1_rental_periods (id)
    on delete restrict,
  amount_received numeric(16,2) not null check (amount_received > 0),
  payment_date date not null,
  payment_method text not null check (payment_method in (
    'bank_transfer', 'cash', 'cdc', 'pdc', 'other'
  )),
  reference text,
  note text,
  recorded_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  recorded_by_role text not null check (recorded_by_role = 'admin'),
  recorded_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (recorded_by_auth_user_id, idempotency_key)
);

create unique index if not exists v1_rental_receipts_reference_idx
  on public.v1_rental_receipts (lower(btrim(reference)))
  where reference is not null and btrim(reference) <> '';
create index if not exists v1_rental_receipts_period_idx
  on public.v1_rental_receipts (period_id, recorded_at);

create table if not exists public.v1_rental_cheques (
  id uuid primary key,
  property_id uuid not null references public.v1_rental_properties (id)
    on delete restrict,
  lease_id uuid not null references public.v1_rental_leases (id)
    on delete restrict,
  period_id uuid references public.v1_rental_periods (id) on delete restrict,
  cheque_number text not null check (
    btrim(cheque_number) <> '' and length(cheque_number) <= 100
  ),
  cheque_type text not null check (cheque_type in ('cdc', 'pdc')),
  bank_name text not null check (btrim(bank_name) <> ''),
  cheque_date date not null,
  amount numeric(16,2) not null check (amount > 0),
  status text not null default 'scheduled' check (status in (
    'scheduled', 'received', 'deposited', 'cleared', 'returned', 'cancelled'
  )),
  note text,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  updated_at timestamptz not null default clock_timestamp(),
  unique (property_id, bank_name, cheque_number)
);

create index if not exists v1_rental_cheques_attention_idx
  on public.v1_rental_cheques (cheque_date, status)
  where status in ('scheduled', 'received', 'deposited', 'returned');

alter table public.v1_rental_properties enable row level security;
alter table public.v1_rental_leases enable row level security;
alter table public.v1_rental_periods enable row level security;
alter table public.v1_rental_receipts enable row level security;
alter table public.v1_rental_cheques enable row level security;

revoke all on table public.v1_rental_properties from public, anon, authenticated;
revoke all on table public.v1_rental_leases from public, anon, authenticated;
revoke all on table public.v1_rental_periods from public, anon, authenticated;
revoke all on table public.v1_rental_receipts from public, anon, authenticated;
revoke all on table public.v1_rental_cheques from public, anon, authenticated;
grant all on table public.v1_rental_properties to service_role;
grant all on table public.v1_rental_leases to service_role;
grant all on table public.v1_rental_periods to service_role;
grant all on table public.v1_rental_receipts to service_role;
grant all on table public.v1_rental_cheques to service_role;

-- Authenticated clients intentionally receive no direct table grants. Rental
-- records contain commercial and tenant data, so all reads and writes cross
-- the role-checking, shape-controlled RPC boundary below.

create or replace function public.v1_rental_assert_admin()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or public.v1_current_role() <> 'admin' then
    raise exception 'V1_RENTAL_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  return v_actor;
end;
$$;

create or replace function public.v1_rental_period_status(
  p_due_date date,
  p_amount_due numeric,
  p_amount_paid numeric,
  p_grace_days integer
)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_amount_paid >= p_amount_due then 'paid'
    when p_amount_paid > 0 then 'partially_paid'
    when current_date > p_due_date + p_grace_days then 'overdue'
    when current_date >= p_due_date then 'due'
    else 'upcoming'
  end
$$;

create or replace function public.v1_rental_replace_unpaid_schedule(
  p_lease_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lease public.v1_rental_leases%rowtype;
begin
  select * into strict v_lease
  from public.v1_rental_leases where id = p_lease_id for update;

  if exists (
    select 1 from public.v1_rental_receipts receipt_record
    where receipt_record.lease_id = p_lease_id
  ) then
    raise exception 'V1_RENTAL_PAID_SCHEDULE_CANNOT_BE_REBUILT'
      using errcode = '23514';
  end if;

  delete from public.v1_rental_periods where lease_id = p_lease_id;
  insert into public.v1_rental_periods (
    id, lease_id, period_month, due_date, amount_due
  )
  select
    gen_random_uuid(),
    p_lease_id,
    month_value::date,
    (
      month_value::date
      + (least(
          v_lease.monthly_due_day,
          extract(day from (
            month_value + interval '1 month - 1 day'
          ))::integer
        ) - 1)
    )::date,
    v_lease.monthly_rent
  from generate_series(
    date_trunc('month', v_lease.lease_start)::date,
    date_trunc('month', v_lease.lease_end)::date,
    interval '1 month'
  ) month_value;
end;
$$;

create or replace function public.v1_save_rental_property(
  p_payload jsonb,
  p_expected_version integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_existing jsonb;
  v_property_id uuid := coalesce(
    nullif(p_payload ->> 'property_id', '')::uuid, gen_random_uuid()
  );
  v_lease_id uuid := coalesce(
    nullif(p_payload ->> 'lease_id', '')::uuid, gen_random_uuid()
  );
  v_occupied boolean := coalesce((p_payload ->> 'occupied')::boolean, false);
  v_before jsonb;
  v_property public.v1_rental_properties%rowtype;
  v_response jsonb;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_rental_property', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;

  if btrim(coalesce(p_payload ->> 'unit_code', '')) = ''
    or btrim(coalesce(p_payload ->> 'property_name', '')) = ''
    or btrim(coalesce(p_payload ->> 'location', '')) = '' then
    raise exception 'V1_RENTAL_PROPERTY_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;

  select property_record.*
  into v_property
  from public.v1_rental_properties property_record
  where property_record.id = v_property_id
  for update;

  if found then
    v_before := to_jsonb(v_property);
    if p_expected_version is null or p_expected_version <> v_property.record_version then
      raise exception 'V1_RENTAL_PROPERTY_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    if v_property.is_archived then
      raise exception 'V1_RENTAL_ARCHIVED_PROPERTY_READ_ONLY'
        using errcode = '23514';
    end if;
    update public.v1_rental_properties set
      unit_code = upper(btrim(p_payload ->> 'unit_code')),
      property_name = btrim(p_payload ->> 'property_name'),
      property_type = p_payload ->> 'property_type',
      municipality_number = nullif(btrim(p_payload ->> 'municipality_number'), ''),
      location = btrim(p_payload ->> 'location'),
      description = nullif(btrim(p_payload ->> 'description'), ''),
      occupancy_state = case when v_occupied then 'occupied' else 'vacant' end,
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor,
      updated_at = clock_timestamp()
    where id = v_property_id
    returning * into v_property;
  else
    if p_expected_version is not null then
      raise exception 'V1_RENTAL_PROPERTY_NOT_FOUND' using errcode = 'P0002';
    end if;
    insert into public.v1_rental_properties (
      id, unit_code, property_name, property_type, municipality_number,
      location, description, occupancy_state, created_by_auth_user_id,
      updated_by_auth_user_id
    ) values (
      v_property_id, upper(btrim(p_payload ->> 'unit_code')),
      btrim(p_payload ->> 'property_name'), p_payload ->> 'property_type',
      nullif(btrim(p_payload ->> 'municipality_number'), ''),
      btrim(p_payload ->> 'location'),
      nullif(btrim(p_payload ->> 'description'), ''),
      case when v_occupied then 'occupied' else 'vacant' end,
      v_actor, v_actor
    ) returning * into v_property;
  end if;

  if v_occupied then
    if btrim(coalesce(p_payload ->> 'tenant_name', '')) = ''
      or btrim(coalesce(p_payload ->> 'contract_number', '')) = ''
      or nullif(p_payload ->> 'lease_start', '') is null
      or nullif(p_payload ->> 'lease_end', '') is null then
      raise exception 'V1_RENTAL_OCCUPIED_LEASE_REQUIRED'
        using errcode = '22023';
    end if;

    update public.v1_rental_leases
    set is_current = false, updated_by_auth_user_id = v_actor,
        updated_at = clock_timestamp()
    where property_id = v_property_id and is_current and id <> v_lease_id;

    insert into public.v1_rental_leases (
      id, property_id, contract_number, contract_type, contract_status,
      tenant_name, trade_licence_number, contact_number, email, signed_date,
      lease_start, lease_end, monthly_rent, security_deposit,
      monthly_due_day, grace_period_days, default_payment_method,
      payment_frequency, contract_cheque_count, annual_escalation_percent,
      renewal_notice_days, notes, created_by_auth_user_id,
      updated_by_auth_user_id
    ) values (
      v_lease_id, v_property_id, btrim(p_payload ->> 'contract_number'),
      coalesce(nullif(p_payload ->> 'contract_type', ''), 'tenancy_contract'),
      coalesce(nullif(p_payload ->> 'contract_status', ''), 'draft'),
      btrim(p_payload ->> 'tenant_name'),
      nullif(btrim(p_payload ->> 'trade_licence_number'), ''),
      nullif(btrim(p_payload ->> 'contact_number'), ''),
      nullif(btrim(p_payload ->> 'email'), ''),
      nullif(p_payload ->> 'signed_date', '')::date,
      (p_payload ->> 'lease_start')::date,
      (p_payload ->> 'lease_end')::date,
      coalesce((p_payload ->> 'monthly_rent')::numeric, 0),
      coalesce((p_payload ->> 'security_deposit')::numeric, 0),
      coalesce((p_payload ->> 'monthly_due_day')::integer, 1),
      coalesce((p_payload ->> 'grace_period_days')::integer, 5),
      coalesce(nullif(p_payload ->> 'default_payment_method', ''), 'bank_transfer'),
      coalesce(nullif(p_payload ->> 'payment_frequency', ''), 'monthly'),
      coalesce((p_payload ->> 'contract_cheque_count')::integer, 0),
      coalesce((p_payload ->> 'annual_escalation_percent')::numeric, 0),
      coalesce((p_payload ->> 'renewal_notice_days')::integer, 90),
      nullif(btrim(p_payload ->> 'lease_notes'), ''), v_actor, v_actor
    )
    on conflict (id) do update set
      contract_number = excluded.contract_number,
      contract_type = excluded.contract_type,
      contract_status = excluded.contract_status,
      tenant_name = excluded.tenant_name,
      trade_licence_number = excluded.trade_licence_number,
      contact_number = excluded.contact_number,
      email = excluded.email,
      signed_date = excluded.signed_date,
      lease_start = excluded.lease_start,
      lease_end = excluded.lease_end,
      monthly_rent = excluded.monthly_rent,
      security_deposit = excluded.security_deposit,
      monthly_due_day = excluded.monthly_due_day,
      grace_period_days = excluded.grace_period_days,
      default_payment_method = excluded.default_payment_method,
      payment_frequency = excluded.payment_frequency,
      contract_cheque_count = excluded.contract_cheque_count,
      annual_escalation_percent = excluded.annual_escalation_percent,
      renewal_notice_days = excluded.renewal_notice_days,
      notes = excluded.notes,
      is_current = true,
      record_version = public.v1_rental_leases.record_version + 1,
      updated_by_auth_user_id = excluded.updated_by_auth_user_id,
      updated_at = clock_timestamp();

    perform public.v1_rental_replace_unpaid_schedule(v_lease_id);
  elsif exists (
    select 1 from public.v1_rental_leases lease_record
    where lease_record.property_id = v_property_id and lease_record.is_current
      and lease_record.contract_status not in ('terminated', 'expired', 'renewed')
  ) then
    raise exception 'V1_RENTAL_END_ACTIVE_LEASE_FIRST'
      using errcode = '23514';
  end if;

  v_response := jsonb_build_object(
    'property_id', v_property_id,
    'lease_id', case when v_occupied then v_lease_id else null end,
    'record_version', v_property.record_version
  );
  perform public.v1_write_audit_event(
    case when v_before is null then 'rental_property_created'
      else 'rental_property_updated' end,
    'rental_property', v_property_id, null, v_before,
    (select to_jsonb(p) from public.v1_rental_properties p where p.id = v_property_id),
    null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_rental_property', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_record_rent_payment(
  p_period_id uuid,
  p_amount numeric,
  p_payment_date date,
  p_payment_method text,
  p_reference text,
  p_note text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_role text := public.v1_current_role();
  v_existing jsonb;
  v_period public.v1_rental_periods%rowtype;
  v_lease public.v1_rental_leases%rowtype;
  v_paid numeric(16,2);
  v_receipt_id uuid := gen_random_uuid();
  v_response jsonb;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_record_rent_payment', p_idempotency_key,
    jsonb_build_object('period_id', p_period_id, 'amount', p_amount,
      'payment_date', p_payment_date, 'payment_method', p_payment_method,
      'reference', p_reference, 'note', p_note)
  );
  if v_existing is not null then return v_existing; end if;
  if p_amount is null or p_amount <= 0 or p_payment_date is null then
    raise exception 'V1_RENTAL_PAYMENT_INVALID' using errcode = '22023';
  end if;
  if p_payment_method not in ('bank_transfer', 'cash', 'cdc', 'pdc', 'other') then
    raise exception 'V1_RENTAL_PAYMENT_METHOD_INVALID' using errcode = '22023';
  end if;
  if p_payment_method in ('cdc', 'pdc')
    and btrim(coalesce(p_reference, '')) = '' then
    raise exception 'V1_RENTAL_PAYMENT_REFERENCE_REQUIRED'
      using errcode = '22023';
  end if;

  select * into strict v_period from public.v1_rental_periods
  where id = p_period_id for update;
  select * into strict v_lease from public.v1_rental_leases
  where id = v_period.lease_id;
  select coalesce(sum(amount_received), 0) into v_paid
  from public.v1_rental_receipts where period_id = p_period_id;
  if v_paid + p_amount > v_period.amount_due then
    raise exception 'V1_RENTAL_PAYMENT_EXCEEDS_BALANCE'
      using errcode = '23514';
  end if;

  insert into public.v1_rental_receipts (
    id, property_id, lease_id, period_id, amount_received, payment_date,
    payment_method, reference, note, recorded_by_auth_user_id,
    recorded_by_role, idempotency_key
  ) values (
    v_receipt_id, v_lease.property_id, v_lease.id, p_period_id, p_amount,
    p_payment_date, p_payment_method, nullif(btrim(p_reference), ''),
    nullif(btrim(p_note), ''), v_actor, v_role, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'receipt_id', v_receipt_id, 'period_id', p_period_id,
    'amount_paid', v_paid + p_amount,
    'balance', v_period.amount_due - v_paid - p_amount
  );
  perform public.v1_write_audit_event(
    'rent_payment_recorded', 'rental_receipt', v_receipt_id, null, null,
    v_response, null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_record_rent_payment', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_rental_cheque(
  p_payload jsonb,
  p_expected_version integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_existing jsonb;
  v_id uuid := coalesce(nullif(p_payload ->> 'cheque_id', '')::uuid, gen_random_uuid());
  v_cheque public.v1_rental_cheques%rowtype;
  v_property_id uuid := nullif(p_payload ->> 'property_id', '')::uuid;
  v_lease_id uuid := nullif(p_payload ->> 'lease_id', '')::uuid;
  v_period_id uuid := nullif(p_payload ->> 'period_id', '')::uuid;
  v_response jsonb;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_rental_cheque', p_idempotency_key,
    jsonb_build_object('payload', p_payload, 'expected_version', p_expected_version)
  );
  if v_existing is not null then return v_existing; end if;
  if btrim(coalesce(p_payload ->> 'cheque_number', '')) = ''
    or btrim(coalesce(p_payload ->> 'bank_name', '')) = ''
    or v_property_id is null or v_lease_id is null
    or nullif(p_payload ->> 'cheque_date', '') is null
    or coalesce(p_payload ->> 'cheque_type', '') not in ('cdc', 'pdc')
    or coalesce((p_payload ->> 'amount')::numeric, 0) <= 0 then
    raise exception 'V1_RENTAL_CHEQUE_REQUIRED_FIELDS'
      using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.v1_rental_leases lease_record
    where lease_record.id = v_lease_id
      and lease_record.property_id = v_property_id
  ) then
    raise exception 'V1_RENTAL_CHEQUE_LEASE_MISMATCH'
      using errcode = '23514';
  end if;
  if v_period_id is not null and not exists (
    select 1 from public.v1_rental_periods period_record
    where period_record.id = v_period_id
      and period_record.lease_id = v_lease_id
  ) then
    raise exception 'V1_RENTAL_CHEQUE_PERIOD_MISMATCH'
      using errcode = '23514';
  end if;
  select * into v_cheque from public.v1_rental_cheques where id = v_id for update;
  if found then
    if p_expected_version is null or p_expected_version <> v_cheque.record_version then
      raise exception 'V1_RENTAL_CHEQUE_VERSION_CONFLICT' using errcode = '40001';
    end if;
    if v_cheque.property_id <> v_property_id
      or v_cheque.lease_id <> v_lease_id then
      raise exception 'V1_RENTAL_CHEQUE_IDENTITY_IMMUTABLE'
        using errcode = '23514';
    end if;
    update public.v1_rental_cheques set
      period_id = v_period_id,
      cheque_number = btrim(p_payload ->> 'cheque_number'),
      cheque_type = p_payload ->> 'cheque_type',
      bank_name = btrim(p_payload ->> 'bank_name'),
      cheque_date = (p_payload ->> 'cheque_date')::date,
      amount = (p_payload ->> 'amount')::numeric,
      note = nullif(btrim(p_payload ->> 'note'), ''),
      record_version = record_version + 1,
      updated_by_auth_user_id = v_actor, updated_at = clock_timestamp()
    where id = v_id returning * into v_cheque;
  else
    insert into public.v1_rental_cheques (
      id, property_id, lease_id, period_id, cheque_number, cheque_type,
      bank_name, cheque_date, amount, note, created_by_auth_user_id,
      updated_by_auth_user_id
    ) values (
      v_id, v_property_id, v_lease_id, v_period_id,
      btrim(p_payload ->> 'cheque_number'), p_payload ->> 'cheque_type',
      btrim(p_payload ->> 'bank_name'), (p_payload ->> 'cheque_date')::date,
      (p_payload ->> 'amount')::numeric, nullif(btrim(p_payload ->> 'note'), ''),
      v_actor, v_actor
    ) returning * into v_cheque;
  end if;
  v_response := jsonb_build_object(
    'cheque_id', v_id, 'record_version', v_cheque.record_version,
    'status', v_cheque.status
  );
  perform public.v1_write_audit_event(
    'rental_cheque_saved', 'rental_cheque', v_id, null, null,
    v_response, null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_rental_cheque', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_transition_rental_cheque(
  p_cheque_id uuid,
  p_expected_version integer,
  p_next_status text,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_existing jsonb;
  v_cheque public.v1_rental_cheques%rowtype;
  v_allowed boolean := false;
  v_response jsonb;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_transition_rental_cheque', p_idempotency_key,
    jsonb_build_object('cheque_id', p_cheque_id,
      'expected_version', p_expected_version, 'next_status', p_next_status,
      'reason', p_reason)
  );
  if v_existing is not null then return v_existing; end if;
  select * into strict v_cheque from public.v1_rental_cheques
  where id = p_cheque_id for update;
  if p_expected_version <> v_cheque.record_version then
    raise exception 'V1_RENTAL_CHEQUE_VERSION_CONFLICT' using errcode = '40001';
  end if;
  v_allowed := case v_cheque.status
    when 'scheduled' then p_next_status in ('received', 'cancelled')
    when 'received' then p_next_status in ('deposited', 'returned', 'cancelled')
    when 'deposited' then p_next_status in ('cleared', 'returned')
    when 'returned' then p_next_status in ('received', 'cancelled')
    else false end;
  if not v_allowed then
    raise exception 'V1_RENTAL_CHEQUE_TRANSITION_INVALID' using errcode = '23514';
  end if;
  if p_next_status in ('returned', 'cancelled')
    and btrim(coalesce(p_reason, '')) = '' then
    raise exception 'V1_RENTAL_CHEQUE_REASON_REQUIRED' using errcode = '22023';
  end if;
  update public.v1_rental_cheques set
    status = p_next_status, note = coalesce(nullif(btrim(p_reason), ''), note),
    record_version = record_version + 1,
    updated_by_auth_user_id = v_actor, updated_at = clock_timestamp()
  where id = p_cheque_id returning * into v_cheque;
  v_response := jsonb_build_object(
    'cheque_id', p_cheque_id, 'status', v_cheque.status,
    'record_version', v_cheque.record_version
  );
  perform public.v1_write_audit_event(
    'rental_cheque_status_changed', 'rental_cheque', p_cheque_id,
    null, null, v_response, p_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_transition_rental_cheque', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_archive_rental_property(
  p_property_id uuid,
  p_expected_version integer,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_existing jsonb;
  v_property public.v1_rental_properties%rowtype;
  v_outstanding numeric(16,2);
  v_response jsonb;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_archive_rental_property', p_idempotency_key,
    jsonb_build_object('property_id', p_property_id,
      'expected_version', p_expected_version, 'reason', p_reason)
  );
  if v_existing is not null then return v_existing; end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception 'V1_RENTAL_ARCHIVE_REASON_REQUIRED' using errcode = '22023';
  end if;
  select * into strict v_property from public.v1_rental_properties
  where id = p_property_id for update;
  if p_expected_version <> v_property.record_version then
    raise exception 'V1_RENTAL_PROPERTY_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select coalesce(sum(period_record.amount_due), 0)
    - coalesce((select sum(receipt_record.amount_received)
      from public.v1_rental_receipts receipt_record
      where receipt_record.property_id = p_property_id), 0)
  into v_outstanding
  from public.v1_rental_periods period_record
  join public.v1_rental_leases lease_record on lease_record.id = period_record.lease_id
  where lease_record.property_id = p_property_id
    and period_record.due_date <= current_date;
  if v_outstanding > 0
    or exists (select 1 from public.v1_rental_leases l
      where l.property_id = p_property_id and l.is_current
        and l.contract_status in ('draft', 'active', 'notice_due'))
    or exists (select 1 from public.v1_rental_cheques c
      where c.property_id = p_property_id
        and c.status in ('scheduled', 'received', 'deposited', 'returned')) then
    raise exception 'V1_RENTAL_ARCHIVE_BLOCKED_BY_OPEN_OBLIGATION'
      using errcode = '23514';
  end if;
  update public.v1_rental_properties set
    is_archived = true, record_version = record_version + 1,
    archived_by_auth_user_id = v_actor, archived_at = clock_timestamp(),
    archive_reason = btrim(p_reason), updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where id = p_property_id returning * into v_property;
  v_response := jsonb_build_object(
    'property_id', p_property_id, 'record_version', v_property.record_version,
    'archived', true
  );
  perform public.v1_write_audit_event(
    'rental_property_archived', 'rental_property', p_property_id,
    null, null, v_response, p_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_archive_rental_property', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_get_rental_portfolio()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_result jsonb;
begin
  with current_lease as (
    select * from public.v1_rental_leases where is_current
  ), property_rollup as (
    select p.id, p.unit_code, p.property_name, p.property_type,
      p.municipality_number, p.location, p.description,
      p.occupancy_state, p.is_archived, p.record_version, p.updated_at,
      l.id lease_id, l.contract_number, l.contract_type, l.contract_status,
      l.tenant_name, l.contact_number, l.email, l.trade_licence_number,
      l.lease_start, l.lease_end, l.monthly_rent, l.security_deposit,
      l.monthly_due_day, l.grace_period_days, l.default_payment_method,
      l.annual_escalation_percent, l.renewal_notice_days,
      coalesce(period_rollup.outstanding, 0) outstanding,
      coalesce(period_rollup.current_paid, 0) current_paid,
      coalesce(period_rollup.current_due, 0) current_due,
      cheque_rollup.next_cheque_date,
      cheque_rollup.next_cheque_number
    from public.v1_rental_properties p
    left join current_lease l on l.property_id = p.id
    left join lateral (
      select
        coalesce(sum(case when period_record.due_date <= current_date
          then greatest(period_record.amount_due - coalesce(receipt_rollup.amount_paid, 0), 0)
          else 0 end), 0) outstanding,
        coalesce(sum(case when period_record.period_month = date_trunc('month', current_date)::date
          then coalesce(receipt_rollup.amount_paid, 0) else 0 end), 0) current_paid,
        coalesce(sum(case when period_record.period_month = date_trunc('month', current_date)::date
          then period_record.amount_due else 0 end), 0) current_due
      from public.v1_rental_periods period_record
      left join lateral (
        select coalesce(sum(receipt_record.amount_received), 0) amount_paid
        from public.v1_rental_receipts receipt_record
        where receipt_record.period_id = period_record.id
      ) receipt_rollup on true
      where period_record.lease_id = l.id
    ) period_rollup on true
    left join lateral (
      select cheque_record.cheque_date next_cheque_date,
        cheque_record.cheque_number next_cheque_number
      from public.v1_rental_cheques cheque_record
      where cheque_record.lease_id = l.id
        and cheque_record.status in ('scheduled', 'received', 'deposited')
      order by cheque_record.cheque_date, cheque_record.id
      limit 1
    ) cheque_rollup on true
  ), summary as (
    select
      count(*) filter (where not is_archived) total_properties,
      count(*) filter (where not is_archived and occupancy_state = 'occupied') occupied,
      coalesce(sum(monthly_rent) filter (where not is_archived and occupancy_state = 'occupied'), 0) monthly_rent_roll,
      coalesce((select sum(r.amount_received) from public.v1_rental_receipts r
        where date_trunc('month', r.payment_date) = date_trunc('month', current_date)), 0) collected_this_month,
      coalesce(sum(outstanding) filter (where not is_archived), 0) outstanding,
      coalesce(sum(security_deposit) filter (where not is_archived), 0) security_deposits,
      count(*) filter (where not is_archived and lease_end between current_date
        and current_date + interval '90 days') expiring_within_90,
      (select count(*) from public.v1_rental_cheques c where c.status in
        ('scheduled','received','deposited','returned') and c.cheque_date <= current_date + 30) cheque_attention
    from property_rollup
  )
  select jsonb_build_object(
    'as_of', clock_timestamp(),
    'summary', (select to_jsonb(s) from summary s),
    'properties', coalesce((select jsonb_agg(to_jsonb(pr) order by unit_code)
      from property_rollup pr), '[]'::jsonb),
    'recent_payments', coalesce((select jsonb_agg(to_jsonb(x) order by x.recorded_at desc)
      from (select r.id, r.property_id, p.unit_code, p.property_name,
        r.amount_received, r.payment_date, r.payment_method, r.reference,
        r.recorded_at, coalesce(profile.display_name, 'Unknown user') recorded_by
        from public.v1_rental_receipts r
        join public.v1_rental_properties p on p.id = r.property_id
        left join public.v1_profiles profile on profile.auth_user_id = r.recorded_by_auth_user_id
        order by r.recorded_at desc limit 8) x), '[]'::jsonb),
    'cheques', coalesce((select jsonb_agg(to_jsonb(x) order by x.cheque_date)
      from (select c.*, p.unit_code, p.property_name, l.tenant_name
        from public.v1_rental_cheques c
        join public.v1_rental_properties p on p.id = c.property_id
        join public.v1_rental_leases l on l.id = c.lease_id) x), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.v1_get_rental_property(p_property_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_result jsonb;
begin
  select jsonb_build_object(
    'property', to_jsonb(p),
    'lease', (select to_jsonb(l) from public.v1_rental_leases l
      where l.property_id = p.id and l.is_current limit 1),
    'periods', coalesce((select jsonb_agg(to_jsonb(x) order by x.period_month)
      from (select rp.*, coalesce(sum(r.amount_received), 0) amount_paid,
        rp.amount_due - coalesce(sum(r.amount_received), 0) balance,
        public.v1_rental_period_status(rp.due_date, rp.amount_due,
          coalesce(sum(r.amount_received), 0), coalesce(l.grace_period_days, 0)) status
        from public.v1_rental_periods rp
        join public.v1_rental_leases l on l.id = rp.lease_id
        left join public.v1_rental_receipts r on r.period_id = rp.id
        where l.property_id = p.id group by rp.id, l.grace_period_days) x), '[]'::jsonb),
    'receipts', coalesce((select jsonb_agg(to_jsonb(x) order by x.recorded_at desc)
      from (select r.*, rp.period_month,
        coalesce(profile.display_name, 'Unknown user') recorded_by
        from public.v1_rental_receipts r
        join public.v1_rental_periods rp on rp.id = r.period_id
        left join public.v1_profiles profile on profile.auth_user_id = r.recorded_by_auth_user_id
        where r.property_id = p.id) x), '[]'::jsonb),
    'cheques', coalesce((select jsonb_agg(to_jsonb(c) order by c.cheque_date)
      from public.v1_rental_cheques c where c.property_id = p.id), '[]'::jsonb),
    'activity', coalesce((select jsonb_agg(to_jsonb(x) order by x.occurred_at desc)
      from (select a.id, a.event_type, a.actor_role, a.occurred_at,
        a.reason, a.after_data,
        coalesce(profile.display_name, 'Unknown user') actor_name
        from public.v1_audit_events a
        left join public.v1_profiles profile on profile.auth_user_id = a.actor_auth_user_id
        where (a.entity_type = 'rental_property' and a.entity_id = p.id)
          or (a.entity_type = 'rental_receipt' and exists
            (select 1 from public.v1_rental_receipts r where r.id = a.entity_id and r.property_id = p.id))
          or (a.entity_type = 'rental_cheque' and exists
            (select 1 from public.v1_rental_cheques c where c.id = a.entity_id and c.property_id = p.id))
        order by a.occurred_at desc) x), '[]'::jsonb)
  ) into v_result
  from public.v1_rental_properties p where p.id = p_property_id;
  if v_result is null then
    raise exception 'V1_RENTAL_PROPERTY_NOT_FOUND' using errcode = 'P0002';
  end if;
  return v_result;
end;
$$;

revoke all on function public.v1_rental_assert_admin() from public, anon, authenticated;
revoke all on function public.v1_rental_replace_unpaid_schedule(uuid) from public, anon, authenticated;
revoke all on function public.v1_rental_period_status(date, numeric, numeric, integer) from public, anon;
grant execute on function public.v1_rental_period_status(date, numeric, numeric, integer) to authenticated;

revoke all on function public.v1_save_rental_property(jsonb, integer, uuid) from public, anon;
revoke all on function public.v1_record_rent_payment(uuid, numeric, date, text, text, text, uuid) from public, anon;
revoke all on function public.v1_save_rental_cheque(jsonb, integer, uuid) from public, anon;
revoke all on function public.v1_transition_rental_cheque(uuid, integer, text, text, uuid) from public, anon;
revoke all on function public.v1_archive_rental_property(uuid, integer, text, uuid) from public, anon;
revoke all on function public.v1_get_rental_portfolio() from public, anon;
revoke all on function public.v1_get_rental_property(uuid) from public, anon;
grant execute on function public.v1_save_rental_property(jsonb, integer, uuid) to authenticated;
grant execute on function public.v1_record_rent_payment(uuid, numeric, date, text, text, text, uuid) to authenticated;
grant execute on function public.v1_save_rental_cheque(jsonb, integer, uuid) to authenticated;
grant execute on function public.v1_transition_rental_cheque(uuid, integer, text, text, uuid) to authenticated;
grant execute on function public.v1_archive_rental_property(uuid, integer, text, uuid) to authenticated;
grant execute on function public.v1_get_rental_portfolio() to authenticated;
grant execute on function public.v1_get_rental_property(uuid) to authenticated;
grant execute on function public.v1_rental_assert_admin() to service_role;
grant execute on function public.v1_rental_replace_unpaid_schedule(uuid) to service_role;
