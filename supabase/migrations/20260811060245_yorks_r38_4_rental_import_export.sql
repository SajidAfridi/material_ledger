-- Yorks R38.4: preview-confirmed rental workbook import and shaped register
-- exports. This migration is additive and leaves all historical collection
-- data untouched. Authenticated clients still receive no table privileges.

create or replace function public.v1_rental_import_child_key(
  p_parent uuid,
  p_scope text,
  p_index bigint
)
returns uuid
language sql
immutable
strict
set search_path = ''
as $$
  select (
    substr(md5(p_parent::text || ':' || p_scope || ':' || p_index::text), 1, 8)
    || '-' || substr(md5(p_parent::text || ':' || p_scope || ':' || p_index::text), 9, 4)
    || '-4' || substr(md5(p_parent::text || ':' || p_scope || ':' || p_index::text), 14, 3)
    || '-8' || substr(md5(p_parent::text || ':' || p_scope || ':' || p_index::text), 18, 3)
    || '-' || substr(md5(p_parent::text || ':' || p_scope || ':' || p_index::text), 21, 12)
  )::uuid
$$;

create or replace function public.v1_get_rental_export_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := public.v1_rental_assert_admin();
  v_result jsonb;
begin
  with current_leases as (
    select lease_record.*
    from public.v1_rental_leases lease_record
    where lease_record.is_current
  )
  select jsonb_build_object(
    'generated_at', clock_timestamp(),
    'properties', coalesce((
      select jsonb_agg(jsonb_build_object(
        'Unit Code', property_record.unit_code,
        'Property Name', property_record.property_name,
        'Property Type', replace(initcap(replace(property_record.property_type, '_', ' ')), ' ', ' '),
        'Property / Municipality No.', property_record.municipality_number,
        'Location', property_record.location,
        'Occupancy', initcap(property_record.occupancy_state),
        'Tenant / Company', lease_record.tenant_name,
        'Contract No.', lease_record.contract_number,
        'Contract Status', initcap(lease_record.contract_status),
        'Lease Start', lease_record.lease_start,
        'Lease End', lease_record.lease_end,
        'Monthly Rent AED', lease_record.monthly_rent,
        'Security Deposit AED', lease_record.security_deposit,
        'Archived', property_record.is_archived,
        'Last Updated', property_record.updated_at
      ) order by property_record.unit_code)
      from public.v1_rental_properties property_record
      left join current_leases lease_record
        on lease_record.property_id = property_record.id
    ), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(jsonb_build_object(
        'Unit Code', property_record.unit_code,
        'Property Name', property_record.property_name,
        'Tenant / Company', lease_record.tenant_name,
        'Rent Period', period_record.period_month,
        'Due Date', period_record.due_date,
        'Amount Due AED', period_record.amount_due,
        'Amount Paid AED', coalesce(receipt_rollup.amount_paid, 0),
        'Outstanding AED', greatest(period_record.amount_due - coalesce(receipt_rollup.amount_paid, 0), 0),
        'Status', public.v1_rental_period_status(
          period_record.due_date, period_record.amount_due,
          coalesce(receipt_rollup.amount_paid, 0), lease_record.grace_period_days
        )
      ) order by property_record.unit_code, period_record.period_month)
      from public.v1_rental_periods period_record
      join public.v1_rental_leases lease_record on lease_record.id = period_record.lease_id
      join public.v1_rental_properties property_record on property_record.id = lease_record.property_id
      left join lateral (
        select sum(receipt_record.amount_received) amount_paid
        from public.v1_rental_receipts receipt_record
        where receipt_record.period_id = period_record.id
      ) receipt_rollup on true
    ), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'Unit Code', property_record.unit_code,
        'Property Name', property_record.property_name,
        'Tenant / Company', lease_record.tenant_name,
        'Rent Period', period_record.period_month,
        'Amount Received AED', receipt_record.amount_received,
        'Payment Date', receipt_record.payment_date,
        'Payment Method', receipt_record.payment_method,
        'Reference', receipt_record.reference,
        'Note', receipt_record.note,
        'Recorded At', receipt_record.recorded_at,
        'Recorded By', coalesce(profile_record.display_name, 'Unknown user')
      ) order by receipt_record.payment_date desc, receipt_record.recorded_at desc)
      from public.v1_rental_receipts receipt_record
      join public.v1_rental_properties property_record on property_record.id = receipt_record.property_id
      join public.v1_rental_leases lease_record on lease_record.id = receipt_record.lease_id
      join public.v1_rental_periods period_record on period_record.id = receipt_record.period_id
      left join public.v1_profiles profile_record
        on profile_record.auth_user_id = receipt_record.recorded_by_auth_user_id
    ), '[]'::jsonb),
    'cheques', coalesce((
      select jsonb_agg(jsonb_build_object(
        'Unit Code', property_record.unit_code,
        'Property Name', property_record.property_name,
        'Tenant / Company', lease_record.tenant_name,
        'Cheque Type', upper(cheque_record.cheque_type),
        'Cheque Number', cheque_record.cheque_number,
        'Bank', cheque_record.bank_name,
        'Linked Rent Period', period_record.period_month,
        'Cheque Date', cheque_record.cheque_date,
        'Amount AED', cheque_record.amount,
        'Status', initcap(cheque_record.status),
        'Note', cheque_record.note,
        'Last Updated', cheque_record.updated_at
      ) order by cheque_record.cheque_date, property_record.unit_code)
      from public.v1_rental_cheques cheque_record
      join public.v1_rental_properties property_record on property_record.id = cheque_record.property_id
      join public.v1_rental_leases lease_record on lease_record.id = cheque_record.lease_id
      left join public.v1_rental_periods period_record on period_record.id = cheque_record.period_id
    ), '[]'::jsonb),
    'lease_expiry', coalesce((
      select jsonb_agg(jsonb_build_object(
        'Unit Code', property_record.unit_code,
        'Property Name', property_record.property_name,
        'Tenant / Company', lease_record.tenant_name,
        'Contract No.', lease_record.contract_number,
        'Contract Status', initcap(lease_record.contract_status),
        'Lease End', lease_record.lease_end,
        'Days Remaining', lease_record.lease_end - current_date,
        'Renewal Notice Days', lease_record.renewal_notice_days,
        'Renewal Status', case
          when lease_record.lease_end < current_date then 'Expired'
          when lease_record.lease_end <= current_date + lease_record.renewal_notice_days then 'Notice Due'
          else 'Current'
        end
      ) order by lease_record.lease_end, property_record.unit_code)
      from current_leases lease_record
      join public.v1_rental_properties property_record on property_record.id = lease_record.property_id
    ), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

create or replace function public.v1_import_rental_workbook(
  p_payload jsonb,
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
  v_entry jsonb;
  v_index bigint;
  v_action text;
  v_unit_code text;
  v_property public.v1_rental_properties%rowtype;
  v_lease public.v1_rental_leases%rowtype;
  v_period public.v1_rental_periods%rowtype;
  v_property_id uuid;
  v_lease_id uuid;
  v_cheque_id uuid;
  v_status text;
  v_response jsonb;
  v_property_count integer := 0;
  v_payment_count integer := 0;
  v_cheque_count integer := 0;
begin
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_import_rental_workbook', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  if jsonb_typeof(p_payload) <> 'object'
    or jsonb_typeof(coalesce(p_payload -> 'properties', '[]'::jsonb)) <> 'array'
    or jsonb_typeof(coalesce(p_payload -> 'payments', '[]'::jsonb)) <> 'array'
    or jsonb_typeof(coalesce(p_payload -> 'cheques', '[]'::jsonb)) <> 'array' then
    raise exception 'V1_RENTAL_IMPORT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  if jsonb_array_length(coalesce(p_payload -> 'properties', '[]'::jsonb))
       + jsonb_array_length(coalesce(p_payload -> 'payments', '[]'::jsonb))
       + jsonb_array_length(coalesce(p_payload -> 'cheques', '[]'::jsonb)) = 0 then
    raise exception 'V1_RENTAL_IMPORT_EMPTY' using errcode = '22023';
  end if;
  if jsonb_array_length(coalesce(p_payload -> 'properties', '[]'::jsonb)) > 1000
    or jsonb_array_length(coalesce(p_payload -> 'payments', '[]'::jsonb)) > 5000
    or jsonb_array_length(coalesce(p_payload -> 'cheques', '[]'::jsonb)) > 5000 then
    raise exception 'V1_RENTAL_IMPORT_TOO_LARGE' using errcode = '54000';
  end if;

  -- Phase 1: validate the complete workbook before any row is applied.
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'properties', '[]'::jsonb)) row_record
    group by upper(btrim(row_record ->> 'unit_code'))
    having count(*) > 1
  ) then
    raise exception 'V1_RENTAL_IMPORT_DUPLICATE_UNIT_CODE' using errcode = '23505';
  end if;

  for v_entry, v_index in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_payload -> 'properties', '[]'::jsonb))
      with ordinality
  loop
    v_action := lower(btrim(coalesce(v_entry ->> 'action', '')));
    v_unit_code := upper(btrim(coalesce(v_entry ->> 'unit_code', '')));
    if v_action not in ('create', 'update')
      or v_unit_code = ''
      or btrim(coalesce(v_entry ->> 'property_name', '')) = ''
      or btrim(coalesce(v_entry ->> 'location', '')) = ''
      or coalesce(v_entry ->> 'property_type', '') not in
        ('shop', 'warehouse', 'office', 'labour_camp', 'villa', 'other')
      or coalesce((v_entry ->> 'occupied')::boolean, false) is null then
      raise exception 'V1_RENTAL_IMPORT_PROPERTY_INVALID_AT_ROW_%',
        coalesce(v_entry ->> 'source_row', v_index::text) using errcode = '22023';
    end if;
    select * into v_property from public.v1_rental_properties
      where unit_code = v_unit_code for update;
    if v_action = 'create' and found then
      raise exception 'V1_RENTAL_IMPORT_CREATE_UNIT_EXISTS_%', v_unit_code
        using errcode = '23505';
    elsif v_action = 'update' and not found then
      raise exception 'V1_RENTAL_IMPORT_UPDATE_UNIT_NOT_FOUND_%', v_unit_code
        using errcode = 'P0002';
    elsif v_action = 'update' and (
      nullif(v_entry ->> 'property_id', '')::uuid <> v_property.id
      or coalesce((v_entry ->> 'expected_version')::integer, 0) <> v_property.record_version
    ) then
      raise exception 'V1_RENTAL_IMPORT_PROPERTY_VERSION_CONFLICT_%', v_unit_code
        using errcode = '40001';
    end if;
    if coalesce((v_entry ->> 'occupied')::boolean, false) then
      if btrim(coalesce(v_entry ->> 'tenant_name', '')) = ''
        or btrim(coalesce(v_entry ->> 'contract_number', '')) = ''
        or nullif(v_entry ->> 'lease_start', '') is null
        or nullif(v_entry ->> 'lease_end', '') is null
        or (v_entry ->> 'lease_end')::date < (v_entry ->> 'lease_start')::date
        or coalesce((v_entry ->> 'monthly_rent')::numeric, -1) < 0
        or coalesce((v_entry ->> 'security_deposit')::numeric, -1) < 0
        or coalesce((v_entry ->> 'monthly_due_day')::integer, 0) not between 1 and 31
        or coalesce((v_entry ->> 'grace_period_days')::integer, -1) not between 0 and 90
        or coalesce(v_entry ->> 'default_payment_method', '') not in
          ('bank_transfer', 'cash', 'cdc', 'pdc', 'other')
        or coalesce(v_entry ->> 'payment_frequency', '') <> 'monthly' then
        raise exception 'V1_RENTAL_IMPORT_LEASE_INVALID_%', v_unit_code
          using errcode = '22023';
      end if;
    elsif v_action = 'update' and exists (
      select 1 from public.v1_rental_leases lease_record
      where lease_record.property_id = v_property.id and lease_record.is_current
        and lease_record.contract_status in ('draft', 'active', 'notice_due')
    ) then
      raise exception 'V1_RENTAL_END_ACTIVE_LEASE_FIRST'
        using errcode = '23514';
    end if;
  end loop;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    where upper(btrim(coalesce(row_record ->> 'unit_code', ''))) = ''
      or nullif(row_record ->> 'rent_period', '') is null
      or nullif(row_record ->> 'payment_date', '') is null
      or coalesce((row_record ->> 'amount_received')::numeric, 0) <= 0
      or coalesce(row_record ->> 'payment_method', '') not in
        ('bank_transfer', 'cash', 'cdc', 'pdc', 'other')
      or (row_record ->> 'payment_method' in ('cdc', 'pdc')
        and btrim(coalesce(row_record ->> 'reference', '')) = '')
  ) then
    raise exception 'V1_RENTAL_IMPORT_PAYMENT_INVALID' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    where not exists (
      select 1
      from public.v1_rental_properties property_record
      join public.v1_rental_leases lease_record
        on lease_record.property_id = property_record.id and lease_record.is_current
      join public.v1_rental_periods period_record
        on period_record.lease_id = lease_record.id
       and period_record.period_month =
         date_trunc('month', (row_record ->> 'rent_period')::date)::date
      where property_record.unit_code = upper(btrim(row_record ->> 'unit_code'))
    ) and not exists (
      select 1 from jsonb_array_elements(coalesce(p_payload -> 'properties', '[]'::jsonb)) property_json
      where upper(btrim(property_json ->> 'unit_code')) = upper(btrim(row_record ->> 'unit_code'))
        and coalesce((property_json ->> 'occupied')::boolean, false)
        and date_trunc('month', (row_record ->> 'rent_period')::date)::date between
          date_trunc('month', (property_json ->> 'lease_start')::date)::date and
          date_trunc('month', (property_json ->> 'lease_end')::date)::date
    )
  ) then
    raise exception 'V1_RENTAL_IMPORT_PAYMENT_UNIT_OR_PERIOD_UNKNOWN'
      using errcode = 'P0002';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    where nullif(btrim(row_record ->> 'reference'), '') is not null
      and exists (select 1 from public.v1_rental_receipts receipt_record
        where lower(btrim(receipt_record.reference)) = lower(btrim(row_record ->> 'reference')))
  ) or exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    where nullif(btrim(row_record ->> 'reference'), '') is not null
    group by lower(btrim(row_record ->> 'reference')) having count(*) > 1
  ) then
    raise exception 'V1_RENTAL_IMPORT_DUPLICATE_PAYMENT_REFERENCE'
      using errcode = '23505';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    group by upper(btrim(row_record ->> 'unit_code')),
      date_trunc('month', (row_record ->> 'rent_period')::date)::date,
      (row_record ->> 'amount_received')::numeric,
      (row_record ->> 'payment_date')::date,
      row_record ->> 'payment_method',
      lower(btrim(coalesce(row_record ->> 'reference', '')))
    having count(*) > 1
  ) or exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb)) row_record
    join public.v1_rental_properties property_record
      on property_record.unit_code = upper(btrim(row_record ->> 'unit_code'))
    join public.v1_rental_leases lease_record
      on lease_record.property_id = property_record.id and lease_record.is_current
    join public.v1_rental_periods period_record
      on period_record.lease_id = lease_record.id
     and period_record.period_month =
       date_trunc('month', (row_record ->> 'rent_period')::date)::date
    join public.v1_rental_receipts receipt_record
      on receipt_record.period_id = period_record.id
     and receipt_record.amount_received = (row_record ->> 'amount_received')::numeric
     and receipt_record.payment_date = (row_record ->> 'payment_date')::date
     and receipt_record.payment_method = row_record ->> 'payment_method'
     and lower(btrim(coalesce(receipt_record.reference, ''))) =
       lower(btrim(coalesce(row_record ->> 'reference', '')))
  ) then
    raise exception 'V1_RENTAL_IMPORT_DUPLICATE_PAYMENT'
      using errcode = '23505';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'cheques', '[]'::jsonb)) row_record
    where upper(btrim(coalesce(row_record ->> 'unit_code', ''))) = ''
      or coalesce(row_record ->> 'cheque_type', '') not in ('cdc', 'pdc')
      or btrim(coalesce(row_record ->> 'cheque_number', '')) = ''
      or btrim(coalesce(row_record ->> 'bank_name', '')) = ''
      or nullif(row_record ->> 'cheque_date', '') is null
      or coalesce((row_record ->> 'amount')::numeric, 0) <= 0
      or coalesce(row_record ->> 'status', '') not in
        ('scheduled', 'received', 'deposited', 'cleared', 'returned', 'cancelled')
  ) then
    raise exception 'V1_RENTAL_IMPORT_CHEQUE_INVALID' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'cheques', '[]'::jsonb)) row_record
    group by upper(btrim(row_record ->> 'unit_code')),
      lower(btrim(row_record ->> 'bank_name')),
      lower(btrim(row_record ->> 'cheque_number'))
    having count(*) > 1
  ) or exists (
    select 1 from jsonb_array_elements(coalesce(p_payload -> 'cheques', '[]'::jsonb)) row_record
    where exists (select 1
      from public.v1_rental_cheques cheque_record
      join public.v1_rental_properties property_record
        on property_record.id = cheque_record.property_id
      where property_record.unit_code = upper(btrim(row_record ->> 'unit_code'))
        and lower(btrim(cheque_record.bank_name)) = lower(btrim(row_record ->> 'bank_name'))
        and lower(btrim(cheque_record.cheque_number)) = lower(btrim(row_record ->> 'cheque_number')))
  ) then
    raise exception 'V1_RENTAL_IMPORT_DUPLICATE_CHEQUE' using errcode = '23505';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(coalesce(p_payload -> 'cheques', '[]'::jsonb)) row_record
    where not exists (
      select 1
      from public.v1_rental_properties property_record
      join public.v1_rental_leases lease_record
        on lease_record.property_id = property_record.id and lease_record.is_current
      left join public.v1_rental_periods period_record
        on period_record.lease_id = lease_record.id
       and period_record.period_month =
         date_trunc('month', nullif(row_record ->> 'rent_period', '')::date)::date
      where property_record.unit_code = upper(btrim(row_record ->> 'unit_code'))
        and (nullif(row_record ->> 'rent_period', '') is null or period_record.id is not null)
    ) and not exists (
      select 1
      from jsonb_array_elements(coalesce(p_payload -> 'properties', '[]'::jsonb)) property_json
      where upper(btrim(property_json ->> 'unit_code')) =
        upper(btrim(row_record ->> 'unit_code'))
        and coalesce((property_json ->> 'occupied')::boolean, false)
        and (nullif(row_record ->> 'rent_period', '') is null or
          date_trunc('month', (row_record ->> 'rent_period')::date)::date between
            date_trunc('month', (property_json ->> 'lease_start')::date)::date and
            date_trunc('month', (property_json ->> 'lease_end')::date)::date)
    )
  ) then
    raise exception 'V1_RENTAL_IMPORT_CHEQUE_UNIT_OR_PERIOD_UNKNOWN'
      using errcode = 'P0002';
  end if;

  -- Phase 2: apply all rows in the same transaction using deterministic child
  -- command identities. Any failure rolls the whole import back.
  for v_entry, v_index in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_payload -> 'properties', '[]'::jsonb))
      with ordinality
  loop
    v_action := lower(btrim(v_entry ->> 'action'));
    v_unit_code := upper(btrim(v_entry ->> 'unit_code'));
    if v_action = 'create' then
      v_property_id := public.v1_rental_import_child_key(p_idempotency_key, 'property', v_index);
      v_lease_id := public.v1_rental_import_child_key(p_idempotency_key, 'lease', v_index);
      v_entry := v_entry || jsonb_build_object(
        'property_id', v_property_id,
        'lease_id', v_lease_id
      );
    else
      v_property_id := (v_entry ->> 'property_id')::uuid;
    end if;
    perform public.v1_save_rental_property(
      v_entry - 'action' - 'source_row' - 'expected_version',
      case when v_action = 'update' then (v_entry ->> 'expected_version')::integer else null end,
      public.v1_rental_import_child_key(p_idempotency_key, 'save-property', v_index)
    );
    v_property_count := v_property_count + 1;
  end loop;

  for v_entry, v_index in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_payload -> 'payments', '[]'::jsonb))
      with ordinality
  loop
    v_unit_code := upper(btrim(v_entry ->> 'unit_code'));
    select property_record.* into strict v_property
      from public.v1_rental_properties property_record
      where property_record.unit_code = v_unit_code for update;
    select lease_record.* into strict v_lease
      from public.v1_rental_leases lease_record
      where lease_record.property_id = v_property.id and lease_record.is_current
      for update;
    select period_record.* into strict v_period
      from public.v1_rental_periods period_record
      where period_record.lease_id = v_lease.id
        and period_record.period_month = date_trunc('month', (v_entry ->> 'rent_period')::date)::date
      for update;
    perform public.v1_record_rent_payment(
      v_period.id,
      (v_entry ->> 'amount_received')::numeric,
      (v_entry ->> 'payment_date')::date,
      v_entry ->> 'payment_method',
      nullif(btrim(v_entry ->> 'reference'), ''),
      nullif(btrim(v_entry ->> 'note'), ''),
      public.v1_rental_import_child_key(p_idempotency_key, 'payment', v_index)
    );
    v_payment_count := v_payment_count + 1;
  end loop;

  for v_entry, v_index in
    select value, ordinality
    from jsonb_array_elements(coalesce(p_payload -> 'cheques', '[]'::jsonb))
      with ordinality
  loop
    v_unit_code := upper(btrim(v_entry ->> 'unit_code'));
    select property_record.* into strict v_property
      from public.v1_rental_properties property_record
      where property_record.unit_code = v_unit_code for update;
    select lease_record.* into strict v_lease
      from public.v1_rental_leases lease_record
      where lease_record.property_id = v_property.id and lease_record.is_current
      for update;
    v_period.id := null;
    if nullif(v_entry ->> 'rent_period', '') is not null then
      select period_record.* into strict v_period
        from public.v1_rental_periods period_record
        where period_record.lease_id = v_lease.id
          and period_record.period_month = date_trunc('month', (v_entry ->> 'rent_period')::date)::date;
    end if;
    v_cheque_id := public.v1_rental_import_child_key(p_idempotency_key, 'cheque', v_index);
    perform public.v1_save_rental_cheque(
      jsonb_build_object(
        'cheque_id', v_cheque_id, 'property_id', v_property.id,
        'lease_id', v_lease.id,
        'period_id', case when v_period.id is null then null else v_period.id end,
        'cheque_number', v_entry ->> 'cheque_number',
        'cheque_type', v_entry ->> 'cheque_type',
        'bank_name', v_entry ->> 'bank_name',
        'cheque_date', v_entry ->> 'cheque_date',
        'amount', v_entry ->> 'amount', 'note', v_entry ->> 'note'
      ), null,
      public.v1_rental_import_child_key(p_idempotency_key, 'save-cheque', v_index)
    );
    v_status := v_entry ->> 'status';
    if v_status in ('received', 'deposited', 'cleared', 'returned') then
      perform public.v1_transition_rental_cheque(
        v_cheque_id, 1, 'received', null,
        public.v1_rental_import_child_key(p_idempotency_key, 'cheque-received', v_index)
      );
    end if;
    if v_status in ('deposited', 'cleared') then
      perform public.v1_transition_rental_cheque(
        v_cheque_id, 2, 'deposited', null,
        public.v1_rental_import_child_key(p_idempotency_key, 'cheque-deposited', v_index)
      );
    end if;
    if v_status = 'cleared' then
      perform public.v1_transition_rental_cheque(
        v_cheque_id, 3, 'cleared', null,
        public.v1_rental_import_child_key(p_idempotency_key, 'cheque-cleared', v_index)
      );
    elsif v_status = 'returned' then
      perform public.v1_transition_rental_cheque(
        v_cheque_id, 2, 'returned', coalesce(nullif(btrim(v_entry ->> 'note'), ''), 'Imported as returned'),
        public.v1_rental_import_child_key(p_idempotency_key, 'cheque-returned', v_index)
      );
    elsif v_status = 'cancelled' then
      perform public.v1_transition_rental_cheque(
        v_cheque_id, 1, 'cancelled', coalesce(nullif(btrim(v_entry ->> 'note'), ''), 'Imported as cancelled'),
        public.v1_rental_import_child_key(p_idempotency_key, 'cheque-cancelled', v_index)
      );
    end if;
    v_cheque_count := v_cheque_count + 1;
  end loop;

  v_response := jsonb_build_object(
    'properties_applied', v_property_count,
    'payments_applied', v_payment_count,
    'cheques_applied', v_cheque_count,
    'file_name', nullif(btrim(p_payload ->> 'file_name'), '')
  );
  perform public.v1_write_audit_event(
    'rental_workbook_imported', 'rental_import',
    public.v1_rental_import_child_key(p_idempotency_key, 'import-audit', 1),
    null, null, v_response, null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_import_rental_workbook', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_rental_import_child_key(uuid, text, bigint)
  from public, anon, authenticated;
grant execute on function public.v1_rental_import_child_key(uuid, text, bigint)
  to service_role;
revoke all on function public.v1_get_rental_export_data()
  from public, anon;
revoke all on function public.v1_import_rental_workbook(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_get_rental_export_data()
  to authenticated;
grant execute on function public.v1_import_rental_workbook(jsonb, uuid)
  to authenticated;
