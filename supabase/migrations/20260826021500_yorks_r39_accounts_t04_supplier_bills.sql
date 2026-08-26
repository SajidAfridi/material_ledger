-- Yorks R39 Accounts T04: protected supplier bills, trusted three-way match,
-- approval and append-only supplier payments.
--
-- This slice is additive and route-less. It activates only the three T04
-- capability consumers; YORKS_V1_ACCOUNTS remains default-off until T05/T07.
-- Existing Projects, BOQ, Material Request, Receipt, Inventory and document
-- facts are read as trusted evidence and are never rewritten here.

update public.v1_capability_catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true
where capability_key = any(array[
  'manage_supplier_bills',
  'approve_supplier_bill_payment',
  'view_supplier_costs'
]::text[]);

create table public.v1_accounts_supplier_bills (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  supplier_id uuid references public.v1_suppliers (id) on delete restrict,
  supplier_name_snapshot text not null check (
    nullif(btrim(supplier_name_snapshot), '') is not null
    and char_length(supplier_name_snapshot) <= 180
  ),
  supplier_invoice_reference text not null check (
    nullif(btrim(supplier_invoice_reference), '') is not null
    and char_length(supplier_invoice_reference) <= 180
  ),
  invoice_date date not null,
  due_date date not null,
  ex_vat_amount numeric(20,2) not null check (
    ex_vat_amount::text <> 'NaN' and ex_vat_amount > 0
  ),
  vat_rate_percent numeric(7,4) not null check (
    vat_rate_percent::text <> 'NaN'
    and vat_rate_percent between 0 and 100
  ),
  vat_amount numeric(20,2) not null check (
    vat_amount::text <> 'NaN' and vat_amount >= 0
  ),
  total_incl_vat numeric(20,2) not null check (
    total_incl_vat::text <> 'NaN'
    and total_incl_vat = ex_vat_amount + vat_amount
  ),
  po_lpo_reference text check (
    po_lpo_reference is null
    or (nullif(btrim(po_lpo_reference), '') is not null
      and char_length(po_lpo_reference) <= 180)
  ),
  po_lpo_document_id uuid
    references public.v1_documents (id) on delete restrict,
  accepted_receipt_review_id uuid
    references public.v1_receipt_reviews (id) on delete restrict,
  accepted_delivery_reference text check (
    accepted_delivery_reference is null
    or nullif(btrim(accepted_delivery_reference), '') is not null
  ),
  supplier_invoice_document_id uuid
    references public.v1_documents (id) on delete restrict,
  explicit_mismatch_reason text check (
    explicit_mismatch_reason is null
    or nullif(btrim(explicit_mismatch_reason), '') is not null
  ),
  status text not null default 'draft' check (
    status in ('draft', 'approved', 'cancelled')
  ),
  approved_at timestamptz,
  approved_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  approved_by_exact_role text check (
    approved_by_exact_role is null
    or approved_by_exact_role in ('accountant', 'admin')
  ),
  approval_admin_exception_reason text check (
    approval_admin_exception_reason is null
    or nullif(btrim(approval_admin_exception_reason), '') is not null
  ),
  cancelled_at timestamptz,
  cancelled_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  cancellation_reason text check (
    cancellation_reason is null
    or nullif(btrim(cancellation_reason), '') is not null
  ),
  notes text,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (
    created_by_role in ('procurement', 'accountant', 'admin')
  ),
  created_by_exact_role text not null check (
    created_by_exact_role in ('procurement', 'accountant', 'admin')
  ),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (due_date >= invoice_date),
  check (
    (accepted_receipt_review_id is null
      and accepted_delivery_reference is null)
    or (accepted_receipt_review_id is not null
      and accepted_delivery_reference is not null)
  ),
  check (
    (status = 'draft' and approved_at is null
      and approved_by_auth_user_id is null
      and approved_by_exact_role is null
      and approval_admin_exception_reason is null
      and cancelled_at is null and cancelled_by_auth_user_id is null
      and cancellation_reason is null)
    or (status = 'approved' and approved_at is not null
      and approved_by_auth_user_id is not null
      and approved_by_exact_role is not null
      and cancelled_at is null and cancelled_by_auth_user_id is null
      and cancellation_reason is null)
    or (status = 'cancelled' and cancelled_at is not null
      and cancelled_by_auth_user_id is not null
      and cancellation_reason is not null)
  )
);

create unique index v1_accounts_supplier_bill_reference_uq
  on public.v1_accounts_supplier_bills (
    project_id,
    lower(btrim(supplier_name_snapshot)),
    lower(btrim(supplier_invoice_reference))
  );
create index v1_accounts_supplier_bill_project_updated_idx
  on public.v1_accounts_supplier_bills
    (project_id, updated_at desc, id desc);
create index v1_accounts_supplier_bill_receipt_idx
  on public.v1_accounts_supplier_bills (accepted_receipt_review_id)
  where accepted_receipt_review_id is not null;

create table public.v1_accounts_supplier_payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  supplier_bill_id uuid not null
    references public.v1_accounts_supplier_bills (id) on delete restrict,
  entry_kind text not null check (entry_kind in ('payment', 'reversal')),
  original_payment_id uuid
    references public.v1_accounts_supplier_payments (id) on delete restrict,
  payment_date date not null,
  payment_method text not null check (nullif(btrim(payment_method), '') is not null),
  payment_reference text not null check (
    nullif(btrim(payment_reference), '') is not null
    and char_length(payment_reference) <= 180
  ),
  amount numeric(20,2) not null check (
    amount::text <> 'NaN' and amount > 0
  ),
  reason text check (
    reason is null or nullif(btrim(reason), '') is not null
  ),
  admin_exception_reason text check (
    admin_exception_reason is null
    or nullif(btrim(admin_exception_reason), '') is not null
  ),
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in ('accountant', 'admin')),
  actor_exact_role text not null check (
    actor_exact_role in ('accountant', 'admin')
  ),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (entry_kind = 'payment' and original_payment_id is null)
    or (entry_kind = 'reversal' and original_payment_id is not null
      and reason is not null)
  )
);

create unique index v1_accounts_supplier_payment_reference_uq
  on public.v1_accounts_supplier_payments (
    project_id, lower(btrim(payment_reference))
  );
create unique index v1_accounts_supplier_payment_reversal_uq
  on public.v1_accounts_supplier_payments (original_payment_id)
  where entry_kind = 'reversal';
create index v1_accounts_supplier_payment_bill_idx
  on public.v1_accounts_supplier_payments
    (supplier_bill_id, created_at, id);

alter table public.v1_accounts_supplier_bills enable row level security;
alter table public.v1_accounts_supplier_payments enable row level security;

revoke all on table public.v1_accounts_supplier_bills
  from public, anon, authenticated;
revoke all on table public.v1_accounts_supplier_payments
  from public, anon, authenticated;
grant all on table public.v1_accounts_supplier_bills to service_role;
grant all on table public.v1_accounts_supplier_payments to service_role;

create trigger v1_accounts_supplier_payments_append_only
before update or delete on public.v1_accounts_supplier_payments
for each row execute function public.v1_accounts_append_only_guard();

create or replace function public.v1_accounts_supplier_document_valid(
  p_project_id uuid,
  p_document_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_document_id is not null and exists (
    select 1
    from public.v1_documents document
    where document.id = p_document_id
      and document.current_version_id is not null
      and document.classification = 'commercial'
      and exists (
        select 1
        from public.v1_document_links link
        where link.document_id = document.id
          and link.project_id = p_project_id
          and link.removed_at is null
      )
  );
$$;

create or replace function public.v1_accounts_supplier_delivery_snapshot(
  p_project_id uuid,
  p_receipt_review_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'receipt_review_id', review.id,
    'delivery_reference', dispatch.delivery_reference,
    'dispatch_id', dispatch.id,
    'dispatch_number', dispatch.dispatch_number,
    'reviewed_at', review.reviewed_at,
    'accepted_good_quantity', coalesce(sum(line.good_qty), 0)::text
  )
  from public.v1_receipt_reviews review
  join public.v1_material_dispatches dispatch
    on dispatch.id = review.dispatch_id
  join public.v1_receipt_review_lines line
    on line.receipt_review_id = review.id
  where review.id = p_receipt_review_id
    and dispatch.project_id = p_project_id
    and review.state = 'confirmed'
  group by review.id, dispatch.id, dispatch.delivery_reference,
    dispatch.dispatch_number, review.reviewed_at
  having coalesce(sum(line.good_qty), 0) > 0;
$$;

create or replace function public.v1_accounts_supplier_paid_amount(
  p_supplier_bill_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(
    case payment.entry_kind
      when 'payment' then payment.amount
      when 'reversal' then -payment.amount
    end
  ), 0)
  from public.v1_accounts_supplier_payments payment
  where payment.supplier_bill_id = p_supplier_bill_id;
$$;

create or replace function public.v1_accounts_supplier_match_status(
  p_supplier_bill_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_present integer := 0;
begin
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id;
  if not found then return null; end if;
  if v_bill.explicit_mismatch_reason is not null then return 'blocked'; end if;
  if v_bill.po_lpo_reference is not null
    and public.v1_accounts_supplier_document_valid(
      v_bill.project_id, v_bill.po_lpo_document_id
    ) then
    v_present := v_present + 1;
  end if;
  if public.v1_accounts_supplier_delivery_snapshot(
    v_bill.project_id, v_bill.accepted_receipt_review_id
  ) is not null then
    v_present := v_present + 1;
  end if;
  if public.v1_accounts_supplier_document_valid(
    v_bill.project_id, v_bill.supplier_invoice_document_id
  ) then
    v_present := v_present + 1;
  end if;
  return case when v_present = 3 then 'matched'
    when v_present = 2 then 'review' else 'blocked' end;
end;
$$;

create or replace function public.v1_approve_supplier_bill(
  p_project_id uuid,
  p_supplier_bill_id uuid,
  p_expected_version integer,
  p_admin_exception_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exact text;
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_match text;
  v_exception_reason text := nullif(btrim(p_admin_exception_reason), '');
  v_payload jsonb;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  v_exact := public.v1_accounts_require_capability(
    p_project_id, 'approve_supplier_bill_payment'
  );
  if v_exact not in ('accountant', 'admin')
    or not public.v1_current_user_has_capability(
      'view_supplier_costs', p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'supplier_bill_id', p_supplier_bill_id,
    'expected_version', p_expected_version,
    'admin_exception_reason', v_exception_reason
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_approve_supplier_bill', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_supplier_bill|' || p_supplier_bill_id::text, 0
    )
  );
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id and project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND'
      using errcode='P0002';
  end if;
  if v_bill.status <> 'draft' then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_APPROVABLE'
      using errcode='55000';
  end if;
  if v_bill.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';
  end if;
  if not public.v1_accounts_supplier_document_valid(
    p_project_id, v_bill.supplier_invoice_document_id
  ) then
    raise exception 'R39_ACCOUNTS_SUPPLIER_INVOICE_DOCUMENT_REQUIRED'
      using errcode='23514';
  end if;
  perform public.v1_accounts_validate_supplier_evidence(
    p_project_id, v_bill.po_lpo_document_id,
    v_bill.accepted_receipt_review_id, v_bill.supplier_invoice_document_id
  );
  v_match := public.v1_accounts_supplier_match_status(p_supplier_bill_id);
  if v_match <> 'matched' then
    if v_exact <> 'admin' then
      raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_MATCHED'
        using errcode='23514';
    end if;
    if v_exception_reason is null then
      raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_REASON_REQUIRED'
        using errcode='22023';
    end if;
  elsif v_exception_reason is not null then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_NOT_REQUIRED'
      using errcode='22023';
  end if;
  v_before := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  update public.v1_accounts_supplier_bills
  set status = 'approved', approved_at = v_now,
      approved_by_auth_user_id = auth.uid(),
      approved_by_exact_role = v_exact,
      approval_admin_exception_reason = v_exception_reason,
      record_version = record_version + 1, updated_at = v_now
  where id = p_supplier_bill_id;
  perform public.v1_write_audit_event(
    'accounts.supplier_bill.approved', 'accounts_supplier_bill',
    p_supplier_bill_id, p_project_id, v_before,
    public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id),
    v_exception_reason, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false,
    'project_id', p_project_id, 'entity_id', p_supplier_bill_id,
    'supplier_bill_id', p_supplier_bill_id,
    'record_version', p_expected_version + 1,
    'status', 'approved', 'match_status', v_match,
    'payment_status', public.v1_accounts_supplier_payment_status(
      p_supplier_bill_id
    ), 'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_approve_supplier_bill', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_record_supplier_payment(
  p_project_id uuid,
  p_supplier_bill_id uuid,
  p_expected_version integer,
  p_payment_date date,
  p_payment_method text,
  p_payment_reference text,
  p_amount text,
  p_reason text,
  p_admin_exception_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exact text;
  v_role text := public.v1_current_role();
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_amount numeric;
  v_paid numeric;
  v_match text;
  v_exception_reason text := nullif(btrim(p_admin_exception_reason), '');
  v_payment_id uuid := gen_random_uuid();
  v_payload jsonb;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  v_exact := public.v1_accounts_require_capability(
    p_project_id, 'approve_supplier_bill_payment'
  );
  if v_exact not in ('accountant', 'admin')
    or not public.v1_current_user_has_capability(
      'view_supplier_costs', p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if p_payment_date is null
    or nullif(btrim(p_payment_method), '') is null
    or nullif(btrim(p_payment_reference), '') is null then
    raise exception 'R39_ACCOUNTS_PAYMENT_IDENTITY_REQUIRED'
      using errcode='22023';
  end if;
  v_amount := public.v1_accounts_parse_money_text(p_amount);
  if v_amount <= 0 then
    raise exception 'R39_ACCOUNTS_INVALID_PAYMENT_AMOUNT'
      using errcode='22023';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'supplier_bill_id', p_supplier_bill_id,
    'expected_version', p_expected_version,
    'payment_date', p_payment_date,
    'payment_method', btrim(p_payment_method),
    'payment_reference', btrim(p_payment_reference),
    'amount', v_amount::text,
    'reason', nullif(btrim(p_reason), ''),
    'admin_exception_reason', v_exception_reason
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_record_supplier_payment', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_supplier_bill|' || p_supplier_bill_id::text, 0
    )
  );
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id and project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND'
      using errcode='P0002';
  end if;
  if v_bill.status <> 'approved' then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_PAYABLE'
      using errcode='55000';
  end if;
  if v_bill.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';
  end if;
  if not public.v1_accounts_supplier_document_valid(
    p_project_id, v_bill.supplier_invoice_document_id
  ) then
    raise exception 'R39_ACCOUNTS_SUPPLIER_INVOICE_DOCUMENT_REQUIRED'
      using errcode='23514';
  end if;
  perform public.v1_accounts_validate_supplier_evidence(
    p_project_id, v_bill.po_lpo_document_id,
    v_bill.accepted_receipt_review_id, v_bill.supplier_invoice_document_id
  );
  v_match := public.v1_accounts_supplier_match_status(p_supplier_bill_id);
  if v_match <> 'matched' then
    if v_exact <> 'admin' then
      raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_MATCHED'
        using errcode='23514';
    end if;
    if v_exception_reason is null then
      raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_REASON_REQUIRED'
        using errcode='22023';
    end if;
  elsif v_exception_reason is not null then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_NOT_REQUIRED'
      using errcode='22023';
  end if;
  v_paid := public.v1_accounts_supplier_paid_amount(p_supplier_bill_id);
  if v_amount > v_bill.total_incl_vat - v_paid then
    raise exception 'R39_ACCOUNTS_SUPPLIER_PAYMENT_CAP_EXCEEDED'
      using errcode='23514';
  end if;
  v_before := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  insert into public.v1_accounts_supplier_payments (
    id, project_id, supplier_bill_id, entry_kind, payment_date,
    payment_method, payment_reference, amount, reason,
    admin_exception_reason, actor_auth_user_id, actor_role,
    actor_exact_role, idempotency_key, created_at
  ) values (
    v_payment_id, p_project_id, p_supplier_bill_id, 'payment',
    p_payment_date, btrim(p_payment_method), btrim(p_payment_reference),
    v_amount, nullif(btrim(p_reason), ''), v_exception_reason,
    auth.uid(), v_role, v_exact, p_idempotency_key, v_now
  );
  update public.v1_accounts_supplier_bills
  set record_version = record_version + 1, updated_at = v_now
  where id = p_supplier_bill_id;
  perform public.v1_write_audit_event(
    'accounts.supplier_payment.recorded', 'accounts_supplier_payment',
    v_payment_id, p_project_id, v_before,
    public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id),
    coalesce(v_exception_reason, nullif(btrim(p_reason), '')),
    p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false,
    'project_id', p_project_id, 'entity_id', v_payment_id,
    'payment_id', v_payment_id, 'supplier_bill_id', p_supplier_bill_id,
    'supplier_bill_record_version', p_expected_version + 1,
    'amount', v_amount::text,
    'payment_status', public.v1_accounts_supplier_payment_status(
      p_supplier_bill_id
    ), 'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_record_supplier_payment', p_idempotency_key, v_response
  );
  return v_response;
exception when unique_violation then
  raise exception 'R39_ACCOUNTS_DUPLICATE_PAYMENT_REFERENCE'
    using errcode='23505';
end;
$$;

create or replace function public.v1_reverse_supplier_payment(
  p_project_id uuid,
  p_supplier_bill_id uuid,
  p_expected_version integer,
  p_original_payment_id uuid,
  p_reversal_date date,
  p_reversal_reference text,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exact text;
  v_role text := public.v1_current_role();
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_original public.v1_accounts_supplier_payments%rowtype;
  v_reversal_id uuid := gen_random_uuid();
  v_payload jsonb;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  v_exact := public.v1_accounts_require_capability(
    p_project_id, 'approve_supplier_bill_payment'
  );
  if v_exact not in ('accountant', 'admin')
    or not public.v1_current_user_has_capability(
      'view_supplier_costs', p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if p_reversal_date is null
    or nullif(btrim(p_reversal_reference), '') is null
    or nullif(btrim(p_reason), '') is null then
    raise exception 'R39_ACCOUNTS_REVERSAL_IDENTITY_REQUIRED'
      using errcode='22023';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'supplier_bill_id', p_supplier_bill_id,
    'expected_version', p_expected_version,
    'original_payment_id', p_original_payment_id,
    'reversal_date', p_reversal_date,
    'reversal_reference', btrim(p_reversal_reference),
    'reason', btrim(p_reason)
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_reverse_supplier_payment', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_supplier_bill|' || p_supplier_bill_id::text, 0
    )
  );
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id and project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND'
      using errcode='P0002';
  end if;
  if v_bill.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';
  end if;
  select * into v_original
  from public.v1_accounts_supplier_payments
  where id = p_original_payment_id
    and project_id = p_project_id
    and supplier_bill_id = p_supplier_bill_id
    and entry_kind = 'payment'
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_PAYMENT_NOT_FOUND'
      using errcode='P0002';
  end if;
  if exists (
    select 1 from public.v1_accounts_supplier_payments reversal
    where reversal.original_payment_id = p_original_payment_id
      and reversal.entry_kind = 'reversal'
  ) then
    raise exception 'R39_ACCOUNTS_SUPPLIER_PAYMENT_ALREADY_REVERSED'
      using errcode='55000';
  end if;
  v_before := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  insert into public.v1_accounts_supplier_payments (
    id, project_id, supplier_bill_id, entry_kind, original_payment_id,
    payment_date, payment_method, payment_reference, amount, reason,
    actor_auth_user_id, actor_role, actor_exact_role,
    idempotency_key, created_at
  ) values (
    v_reversal_id, p_project_id, p_supplier_bill_id, 'reversal',
    p_original_payment_id, p_reversal_date, 'reversal',
    btrim(p_reversal_reference), v_original.amount, btrim(p_reason),
    auth.uid(), v_role, v_exact, p_idempotency_key, v_now
  );
  update public.v1_accounts_supplier_bills
  set record_version = record_version + 1, updated_at = v_now
  where id = p_supplier_bill_id;
  perform public.v1_write_audit_event(
    'accounts.supplier_payment.reversed', 'accounts_supplier_payment',
    v_reversal_id, p_project_id, v_before,
    public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id),
    btrim(p_reason), p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false,
    'project_id', p_project_id, 'entity_id', v_reversal_id,
    'reversal_id', v_reversal_id,
    'original_payment_id', p_original_payment_id,
    'supplier_bill_id', p_supplier_bill_id,
    'supplier_bill_record_version', p_expected_version + 1,
    'amount', v_original.amount::text,
    'payment_status', public.v1_accounts_supplier_payment_status(
      p_supplier_bill_id
    ), 'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_reverse_supplier_payment', p_idempotency_key, v_response
  );
  return v_response;
exception when unique_violation then
  raise exception 'R39_ACCOUNTS_DUPLICATE_PAYMENT_REFERENCE'
    using errcode='23505';
end;
$$;

create or replace function public.v1_cancel_supplier_bill(
  p_project_id uuid,
  p_supplier_bill_id uuid,
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
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_exact text := public.v1_permission_exact_role(auth.uid());
  v_payload jsonb;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  if nullif(btrim(p_reason), '') is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023';
  end if;
  if not public.v1_current_user_has_capability(
    'view_supplier_costs', p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'supplier_bill_id', p_supplier_bill_id,
    'expected_version', p_expected_version,
    'reason', btrim(p_reason)
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_cancel_supplier_bill', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_supplier_bill|' || p_supplier_bill_id::text, 0
    )
  );
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id and project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND'
      using errcode='P0002';
  end if;
  if v_bill.status = 'cancelled' then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_CANCELLABLE'
      using errcode='55000';
  end if;
  if v_bill.status = 'draft' then
    perform public.v1_accounts_require_capability(
      p_project_id, 'manage_supplier_bills'
    );
  else
    perform public.v1_accounts_require_capability(
      p_project_id, 'approve_supplier_bill_payment'
    );
  end if;
  if v_exact not in ('procurement', 'accountant', 'admin') then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if v_bill.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';
  end if;
  if public.v1_accounts_supplier_paid_amount(p_supplier_bill_id) <> 0 then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_HAS_PAYMENTS'
      using errcode='55000';
  end if;
  v_before := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  update public.v1_accounts_supplier_bills
  set status = 'cancelled', cancelled_at = v_now,
      cancelled_by_auth_user_id = auth.uid(),
      cancellation_reason = btrim(p_reason),
      record_version = record_version + 1, updated_at = v_now
  where id = p_supplier_bill_id;
  perform public.v1_write_audit_event(
    'accounts.supplier_bill.cancelled', 'accounts_supplier_bill',
    p_supplier_bill_id, p_project_id, v_before,
    public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id),
    btrim(p_reason), p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false,
    'project_id', p_project_id, 'entity_id', p_supplier_bill_id,
    'supplier_bill_id', p_supplier_bill_id,
    'record_version', p_expected_version + 1,
    'status', 'cancelled', 'payment_status', 'cancelled',
    'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_cancel_supplier_bill', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_get_supplier_bill(
  p_project_id uuid,
  p_supplier_bill_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bill jsonb;
  v_payments jsonb;
begin
  perform public.v1_accounts_require_capability(
    p_project_id, 'view_supplier_costs'
  );
  v_bill := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  if v_bill is null or (v_bill->>'project_id')::uuid <> p_project_id then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND'
      using errcode='P0002';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'payment_id', payment.id,
    'entry_kind', payment.entry_kind,
    'original_payment_id', payment.original_payment_id,
    'payment_date', payment.payment_date,
    'payment_method', payment.payment_method,
    'payment_reference', payment.payment_reference,
    'amount', payment.amount::text,
    'reason', payment.reason,
    'admin_exception_reason', payment.admin_exception_reason,
    'actor_auth_user_id', payment.actor_auth_user_id,
    'actor_exact_role', payment.actor_exact_role,
    'created_at', payment.created_at
  ) order by payment.created_at, payment.id), '[]'::jsonb)
  into v_payments
  from public.v1_accounts_supplier_payments payment
  where payment.supplier_bill_id = p_supplier_bill_id;
  return jsonb_build_object(
    'schema_version', 4,
    'project_id', p_project_id,
    'supplier_bill', v_bill,
    'payments', v_payments,
    'capabilities', public.v1_accounts_supplier_capabilities(p_project_id),
    'commands', public.v1_accounts_supplier_commands(
      p_project_id, p_supplier_bill_id
    )
  );
end;
$$;

create or replace function public.v1_list_supplier_bills(
  p_project_id uuid,
  p_search text default null,
  p_match_status text default null,
  p_payment_status text default null,
  p_cursor_updated_at timestamptz default null,
  p_cursor_id uuid default null,
  p_limit integer default 25
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 25), 1), 100);
  v_search text := nullif(btrim(p_search), '');
  v_items jsonb;
  v_next_updated_at timestamptz;
  v_next_id uuid;
  v_has_more boolean := false;
begin
  perform public.v1_accounts_require_capability(
    p_project_id, 'view_supplier_costs'
  );
  if p_match_status is not null
    and p_match_status not in ('matched', 'review', 'blocked') then
    raise exception 'R39_ACCOUNTS_INVALID_MATCH_STATUS' using errcode='22023';
  end if;
  if p_payment_status is not null and p_payment_status not in (
    'pending', 'approved', 'partially_paid', 'paid', 'blocked', 'cancelled'
  ) then
    raise exception 'R39_ACCOUNTS_INVALID_PAYMENT_STATUS'
      using errcode='22023';
  end if;
  if (p_cursor_updated_at is null) <> (p_cursor_id is null) then
    raise exception 'R39_ACCOUNTS_INVALID_CURSOR' using errcode='22023';
  end if;
  with candidates as (
    select bill.*,
      public.v1_accounts_supplier_match_status(bill.id) as match_status,
      public.v1_accounts_supplier_payment_status(bill.id) as payment_status
    from public.v1_accounts_supplier_bills bill
    where bill.project_id = p_project_id
      and (v_search is null
        or bill.supplier_name_snapshot ilike '%' || v_search || '%'
        or bill.supplier_invoice_reference ilike '%' || v_search || '%'
        or coalesce(bill.po_lpo_reference, '') ilike '%' || v_search || '%'
        or coalesce(bill.accepted_delivery_reference, '')
          ilike '%' || v_search || '%')
      and (p_cursor_updated_at is null
        or (bill.updated_at, bill.id) < (p_cursor_updated_at, p_cursor_id))
  ), filtered as (
    select * from candidates
    where (p_match_status is null or match_status = p_match_status)
      and (p_payment_status is null or payment_status = p_payment_status)
    order by updated_at desc, id desc
    limit v_limit + 1
  ), page as (
    select * from filtered order by updated_at desc, id desc limit v_limit
  )
  select coalesce(jsonb_agg(
      public.v1_accounts_supplier_bill_snapshot(page.id)
      order by page.updated_at desc, page.id desc
    ), '[]'::jsonb),
    (select page.updated_at from page order by page.updated_at, page.id limit 1),
    (select page.id from page order by page.updated_at, page.id limit 1),
    (select count(*) > v_limit from filtered)
  into v_items, v_next_updated_at, v_next_id, v_has_more
  from page;
  if not v_has_more then
    v_next_updated_at := null;
    v_next_id := null;
  end if;
  return jsonb_build_object(
    'schema_version', 4,
    'project_id', p_project_id,
    'items', v_items,
    'next_cursor', case when v_next_id is null then null else
      jsonb_build_object(
        'updated_at', v_next_updated_at, 'supplier_bill_id', v_next_id
      ) end,
    'capabilities', public.v1_accounts_supplier_capabilities(p_project_id),
    'commands', public.v1_accounts_supplier_commands(p_project_id, null)
  );
end;
$$;

create or replace function public.v1_accounts_supplier_payment_status(
  p_supplier_bill_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_match text;
  v_paid numeric;
begin
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id;
  if not found then return null; end if;
  if v_bill.status = 'cancelled' then return 'cancelled'; end if;
  v_match := public.v1_accounts_supplier_match_status(v_bill.id);
  v_paid := public.v1_accounts_supplier_paid_amount(v_bill.id);
  if v_paid >= v_bill.total_incl_vat then return 'paid'; end if;
  if v_paid > 0 then return 'partially_paid'; end if;
  if v_match = 'blocked' then return 'blocked'; end if;
  if v_bill.status = 'approved' then return 'approved'; end if;
  return 'pending';
end;
$$;

create or replace function public.v1_accounts_supplier_capabilities(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'manage_supplier_bills',
      public.v1_current_user_has_capability('manage_supplier_bills', p_project_id),
    'approve_supplier_bill_payment',
      public.v1_current_user_has_capability('approve_supplier_bill_payment', p_project_id),
    'view_supplier_costs',
      public.v1_current_user_has_capability('view_supplier_costs', p_project_id)
  );
$$;

create or replace function public.v1_accounts_supplier_commands(
  p_project_id uuid,
  p_supplier_bill_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'create_bill', public.v1_current_user_has_capability(
      'manage_supplier_bills', p_project_id
    ),
    'edit_bill', public.v1_current_user_has_capability(
      'manage_supplier_bills', p_project_id
    ) and (
      p_supplier_bill_id is null or exists (
        select 1 from public.v1_accounts_supplier_bills bill
        where bill.id = p_supplier_bill_id
          and bill.project_id = p_project_id and bill.status = 'draft'
      )
    ),
    'approve_bill', public.v1_current_user_has_capability(
      'approve_supplier_bill_payment', p_project_id
    ),
    'record_payment', public.v1_current_user_has_capability(
      'approve_supplier_bill_payment', p_project_id
    ),
    'reverse_payment', public.v1_current_user_has_capability(
      'approve_supplier_bill_payment', p_project_id
    ),
    'cancel_bill', public.v1_current_user_has_capability(
      'manage_supplier_bills', p_project_id
    ) or public.v1_current_user_has_capability(
      'approve_supplier_bill_payment', p_project_id
    )
  );
$$;

create or replace function public.v1_accounts_supplier_bill_snapshot(
  p_supplier_bill_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_delivery jsonb;
begin
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id;
  if not found then return null; end if;
  v_delivery := public.v1_accounts_supplier_delivery_snapshot(
    v_bill.project_id, v_bill.accepted_receipt_review_id
  );
  return jsonb_build_object(
    'supplier_bill_id', v_bill.id,
    'project_id', v_bill.project_id,
    'supplier_id', v_bill.supplier_id,
    'supplier_name', v_bill.supplier_name_snapshot,
    'supplier_invoice_reference', v_bill.supplier_invoice_reference,
    'invoice_date', v_bill.invoice_date,
    'due_date', v_bill.due_date,
    'ex_vat_amount', v_bill.ex_vat_amount::text,
    'vat_rate_percent', v_bill.vat_rate_percent::text,
    'vat_amount', v_bill.vat_amount::text,
    'total_incl_vat', v_bill.total_incl_vat::text,
    'po_lpo_reference', v_bill.po_lpo_reference,
    'po_lpo_document_id', v_bill.po_lpo_document_id,
    'accepted_receipt_review_id', v_bill.accepted_receipt_review_id,
    'accepted_delivery_reference', v_bill.accepted_delivery_reference,
    'accepted_delivery', v_delivery,
    'supplier_invoice_document_id', v_bill.supplier_invoice_document_id,
    'explicit_mismatch_reason', v_bill.explicit_mismatch_reason,
    'match_status', public.v1_accounts_supplier_match_status(v_bill.id),
    'status', v_bill.status,
    'payment_status', public.v1_accounts_supplier_payment_status(v_bill.id),
    'paid_amount', public.v1_accounts_supplier_paid_amount(v_bill.id)::text,
    'outstanding_amount', greatest(
      v_bill.total_incl_vat
        - public.v1_accounts_supplier_paid_amount(v_bill.id), 0
    )::text,
    'approval_admin_exception_reason',
      v_bill.approval_admin_exception_reason,
    'approved_at', v_bill.approved_at,
    'approved_by_auth_user_id', v_bill.approved_by_auth_user_id,
    'approved_by_exact_role', v_bill.approved_by_exact_role,
    'cancelled_at', v_bill.cancelled_at,
    'cancellation_reason', v_bill.cancellation_reason,
    'notes', v_bill.notes,
    'record_version', v_bill.record_version,
    'created_by_auth_user_id', v_bill.created_by_auth_user_id,
    'created_by_exact_role', v_bill.created_by_exact_role,
    'created_at', v_bill.created_at,
    'updated_at', v_bill.updated_at
  );
end;
$$;

create or replace function public.v1_accounts_resolve_supplier_name(
  p_supplier_id uuid,
  p_supplier_name text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_supplier public.v1_suppliers%rowtype;
  v_name text := nullif(btrim(p_supplier_name), '');
begin
  if p_supplier_id is not null then
    select * into v_supplier
    from public.v1_suppliers
    where id = p_supplier_id and status <> 'inactive';
    if not found then
      raise exception 'R39_ACCOUNTS_SUPPLIER_INVALID' using errcode='22023';
    end if;
    return jsonb_build_object('supplier_id', v_supplier.id, 'name', v_supplier.name);
  end if;
  if v_name is null or char_length(v_name) > 180 then
    raise exception 'R39_ACCOUNTS_SUPPLIER_REQUIRED' using errcode='22023';
  end if;
  return jsonb_build_object('supplier_id', null, 'name', v_name);
end;
$$;

create or replace function public.v1_accounts_validate_supplier_evidence(
  p_project_id uuid,
  p_po_document_id uuid,
  p_receipt_review_id uuid,
  p_invoice_document_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_delivery jsonb;
begin
  if p_po_document_id is not null
    and not public.v1_accounts_supplier_document_valid(
      p_project_id, p_po_document_id
    ) then
    raise exception 'R39_ACCOUNTS_SUPPLIER_DOCUMENT_INVALID'
      using errcode='22023';
  end if;
  if p_invoice_document_id is not null
    and not public.v1_accounts_supplier_document_valid(
      p_project_id, p_invoice_document_id
    ) then
    raise exception 'R39_ACCOUNTS_SUPPLIER_DOCUMENT_INVALID'
      using errcode='22023';
  end if;
  if p_receipt_review_id is not null then
    v_delivery := public.v1_accounts_supplier_delivery_snapshot(
      p_project_id, p_receipt_review_id
    );
    if v_delivery is null then
      raise exception 'R39_ACCOUNTS_ACCEPTED_DELIVERY_INVALID'
        using errcode='22023';
    end if;
  end if;
  return v_delivery;
end;
$$;

create or replace function public.v1_create_supplier_bill_draft(
  p_project_id uuid,
  p_supplier_id uuid,
  p_supplier_name text,
  p_supplier_invoice_reference text,
  p_invoice_date date,
  p_due_date date,
  p_ex_vat_amount text,
  p_vat_rate_percent text,
  p_po_lpo_reference text,
  p_po_lpo_document_id uuid,
  p_accepted_receipt_review_id uuid,
  p_supplier_invoice_document_id uuid,
  p_explicit_mismatch_reason text,
  p_notes text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exact text;
  v_role text := public.v1_current_role();
  v_supplier jsonb;
  v_delivery jsonb;
  v_ex_vat numeric;
  v_vat_rate numeric;
  v_vat numeric;
  v_total numeric;
  v_bill_id uuid := gen_random_uuid();
  v_payload jsonb;
  v_existing jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  v_exact := public.v1_accounts_require_capability(
    p_project_id, 'manage_supplier_bills'
  );
  if not public.v1_current_user_has_capability(
    'view_supplier_costs', p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if v_exact not in ('procurement', 'accountant', 'admin') then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if nullif(btrim(p_supplier_invoice_reference), '') is null
    or p_invoice_date is null or p_due_date is null
    or p_due_date < p_invoice_date then
    raise exception 'R39_ACCOUNTS_INVALID_SUPPLIER_BILL' using errcode='22023';
  end if;
  v_supplier := public.v1_accounts_resolve_supplier_name(
    p_supplier_id, p_supplier_name
  );
  v_ex_vat := public.v1_accounts_parse_money_text(p_ex_vat_amount);
  v_vat_rate := public.v1_accounts_parse_percent_text(p_vat_rate_percent);
  if v_ex_vat <= 0 then
    raise exception 'R39_ACCOUNTS_INVALID_SUPPLIER_BILL_AMOUNT'
      using errcode='22023';
  end if;
  v_vat := round(v_ex_vat * v_vat_rate / 100, 2);
  v_total := v_ex_vat + v_vat;
  v_delivery := public.v1_accounts_validate_supplier_evidence(
    p_project_id, p_po_lpo_document_id, p_accepted_receipt_review_id,
    p_supplier_invoice_document_id
  );
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'supplier_id', v_supplier->>'supplier_id',
    'supplier_name', v_supplier->>'name',
    'supplier_invoice_reference', btrim(p_supplier_invoice_reference),
    'invoice_date', p_invoice_date,
    'due_date', p_due_date,
    'ex_vat_amount', v_ex_vat::text,
    'vat_rate_percent', v_vat_rate::text,
    'po_lpo_reference', nullif(btrim(p_po_lpo_reference), ''),
    'po_lpo_document_id', p_po_lpo_document_id,
    'accepted_receipt_review_id', p_accepted_receipt_review_id,
    'supplier_invoice_document_id', p_supplier_invoice_document_id,
    'explicit_mismatch_reason', nullif(btrim(p_explicit_mismatch_reason), ''),
    'notes', nullif(btrim(p_notes), '')
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_supplier_bill_draft', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  insert into public.v1_accounts_supplier_bills (
    id, project_id, supplier_id, supplier_name_snapshot,
    supplier_invoice_reference, invoice_date, due_date, ex_vat_amount,
    vat_rate_percent, vat_amount, total_incl_vat, po_lpo_reference,
    po_lpo_document_id, accepted_receipt_review_id,
    accepted_delivery_reference, supplier_invoice_document_id,
    explicit_mismatch_reason, notes, created_by_auth_user_id,
    created_by_role, created_by_exact_role, idempotency_key,
    created_at, updated_at
  ) values (
    v_bill_id, p_project_id, nullif(v_supplier->>'supplier_id', '')::uuid,
    v_supplier->>'name', btrim(p_supplier_invoice_reference), p_invoice_date,
    p_due_date, v_ex_vat, v_vat_rate, v_vat, v_total,
    nullif(btrim(p_po_lpo_reference), ''), p_po_lpo_document_id,
    p_accepted_receipt_review_id, v_delivery->>'delivery_reference',
    p_supplier_invoice_document_id,
    nullif(btrim(p_explicit_mismatch_reason), ''), nullif(btrim(p_notes), ''),
    auth.uid(), v_role, v_exact, p_idempotency_key, v_now, v_now
  );
  perform public.v1_write_audit_event(
    'accounts.supplier_bill.created', 'accounts_supplier_bill', v_bill_id,
    p_project_id, null,
    public.v1_accounts_supplier_bill_snapshot(v_bill_id), null,
    p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false, 'project_id', p_project_id,
    'entity_id', v_bill_id, 'supplier_bill_id', v_bill_id,
    'record_version', 1, 'status', 'draft',
    'match_status', public.v1_accounts_supplier_match_status(v_bill_id),
    'payment_status', public.v1_accounts_supplier_payment_status(v_bill_id),
    'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_create_supplier_bill_draft', p_idempotency_key, v_response
  );
  return v_response;
exception when unique_violation then
  raise exception 'R39_ACCOUNTS_DUPLICATE_SUPPLIER_BILL'
    using errcode='23505';
end;
$$;

create or replace function public.v1_update_supplier_bill_draft(
  p_project_id uuid,
  p_supplier_bill_id uuid,
  p_expected_version integer,
  p_supplier_id uuid,
  p_supplier_name text,
  p_supplier_invoice_reference text,
  p_invoice_date date,
  p_due_date date,
  p_ex_vat_amount text,
  p_vat_rate_percent text,
  p_po_lpo_reference text,
  p_po_lpo_document_id uuid,
  p_accepted_receipt_review_id uuid,
  p_supplier_invoice_document_id uuid,
  p_explicit_mismatch_reason text,
  p_notes text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exact text;
  v_bill public.v1_accounts_supplier_bills%rowtype;
  v_supplier jsonb;
  v_delivery jsonb;
  v_ex_vat numeric;
  v_vat_rate numeric;
  v_vat numeric;
  v_payload jsonb;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_now timestamptz := clock_timestamp();
begin
  v_exact := public.v1_accounts_require_capability(
    p_project_id, 'manage_supplier_bills'
  );
  if not public.v1_current_user_has_capability(
    'view_supplier_costs', p_project_id
  ) or v_exact not in ('procurement', 'accountant', 'admin') then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if nullif(btrim(p_supplier_invoice_reference), '') is null
    or p_invoice_date is null or p_due_date is null
    or p_due_date < p_invoice_date then
    raise exception 'R39_ACCOUNTS_INVALID_SUPPLIER_BILL' using errcode='22023';
  end if;
  v_supplier := public.v1_accounts_resolve_supplier_name(
    p_supplier_id, p_supplier_name
  );
  v_ex_vat := public.v1_accounts_parse_money_text(p_ex_vat_amount);
  v_vat_rate := public.v1_accounts_parse_percent_text(p_vat_rate_percent);
  if v_ex_vat <= 0 then
    raise exception 'R39_ACCOUNTS_INVALID_SUPPLIER_BILL_AMOUNT'
      using errcode='22023';
  end if;
  v_vat := round(v_ex_vat * v_vat_rate / 100, 2);
  v_delivery := public.v1_accounts_validate_supplier_evidence(
    p_project_id, p_po_lpo_document_id, p_accepted_receipt_review_id,
    p_supplier_invoice_document_id
  );
  v_payload := jsonb_build_object(
    'project_id', p_project_id, 'supplier_bill_id', p_supplier_bill_id,
    'expected_version', p_expected_version,
    'supplier_id', v_supplier->>'supplier_id',
    'supplier_name', v_supplier->>'name',
    'supplier_invoice_reference', btrim(p_supplier_invoice_reference),
    'invoice_date', p_invoice_date, 'due_date', p_due_date,
    'ex_vat_amount', v_ex_vat::text, 'vat_rate_percent', v_vat_rate::text,
    'po_lpo_reference', nullif(btrim(p_po_lpo_reference), ''),
    'po_lpo_document_id', p_po_lpo_document_id,
    'accepted_receipt_review_id', p_accepted_receipt_review_id,
    'supplier_invoice_document_id', p_supplier_invoice_document_id,
    'explicit_mismatch_reason', nullif(btrim(p_explicit_mismatch_reason), ''),
    'notes', nullif(btrim(p_notes), '')
  );
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_update_supplier_bill_draft', p_idempotency_key, v_payload
  );
  if v_existing is not null then
    return v_existing || jsonb_build_object('replayed', true);
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('r39_supplier_bill|' || p_supplier_bill_id::text, 0)
  );
  select * into v_bill
  from public.v1_accounts_supplier_bills
  where id = p_supplier_bill_id and project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_FOUND' using errcode='P0002';
  end if;
  if v_bill.status <> 'draft' then
    raise exception 'R39_ACCOUNTS_SUPPLIER_BILL_NOT_EDITABLE' using errcode='55000';
  end if;
  if v_bill.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';
  end if;
  v_before := public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id);
  update public.v1_accounts_supplier_bills
  set supplier_id = nullif(v_supplier->>'supplier_id', '')::uuid,
      supplier_name_snapshot = v_supplier->>'name',
      supplier_invoice_reference = btrim(p_supplier_invoice_reference),
      invoice_date = p_invoice_date,
      due_date = p_due_date,
      ex_vat_amount = v_ex_vat,
      vat_rate_percent = v_vat_rate,
      vat_amount = v_vat,
      total_incl_vat = v_ex_vat + v_vat,
      po_lpo_reference = nullif(btrim(p_po_lpo_reference), ''),
      po_lpo_document_id = p_po_lpo_document_id,
      accepted_receipt_review_id = p_accepted_receipt_review_id,
      accepted_delivery_reference = v_delivery->>'delivery_reference',
      supplier_invoice_document_id = p_supplier_invoice_document_id,
      explicit_mismatch_reason = nullif(btrim(p_explicit_mismatch_reason), ''),
      notes = nullif(btrim(p_notes), ''),
      record_version = record_version + 1,
      updated_at = v_now
  where id = p_supplier_bill_id;
  perform public.v1_write_audit_event(
    'accounts.supplier_bill.updated', 'accounts_supplier_bill',
    p_supplier_bill_id, p_project_id, v_before,
    public.v1_accounts_supplier_bill_snapshot(p_supplier_bill_id), null,
    p_idempotency_key
  );
  v_response := jsonb_build_object(
    'schema_version', 4, 'replayed', false, 'project_id', p_project_id,
    'entity_id', p_supplier_bill_id,
    'supplier_bill_id', p_supplier_bill_id,
    'record_version', p_expected_version + 1, 'status', 'draft',
    'match_status', public.v1_accounts_supplier_match_status(p_supplier_bill_id),
    'payment_status', public.v1_accounts_supplier_payment_status(p_supplier_bill_id),
    'updated_at', v_now
  );
  perform public.v1_complete_idempotency(
    'v1_update_supplier_bill_draft', p_idempotency_key, v_response
  );
  return v_response;
exception when unique_violation then
  raise exception 'R39_ACCOUNTS_DUPLICATE_SUPPLIER_BILL'
    using errcode='23505';
end;
$$;

revoke all on function public.v1_accounts_supplier_document_valid(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_delivery_snapshot(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_paid_amount(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_match_status(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_payment_status(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_capabilities(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_commands(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_supplier_bill_snapshot(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_resolve_supplier_name(uuid,text)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_supplier_evidence(uuid,uuid,uuid,uuid)
  from public, anon, authenticated;

revoke all on function public.v1_create_supplier_bill_draft(
  uuid,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid
) from public, anon;
revoke all on function public.v1_update_supplier_bill_draft(
  uuid,uuid,integer,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid
) from public, anon;
revoke all on function public.v1_approve_supplier_bill(
  uuid,uuid,integer,text,uuid
) from public, anon;
revoke all on function public.v1_record_supplier_payment(
  uuid,uuid,integer,date,text,text,text,text,text,uuid
) from public, anon;
revoke all on function public.v1_reverse_supplier_payment(
  uuid,uuid,integer,uuid,date,text,text,uuid
) from public, anon;
revoke all on function public.v1_cancel_supplier_bill(
  uuid,uuid,integer,text,uuid
) from public, anon;
revoke all on function public.v1_get_supplier_bill(uuid,uuid)
  from public, anon;
revoke all on function public.v1_list_supplier_bills(
  uuid,text,text,text,timestamptz,uuid,integer
) from public, anon;

grant execute on function public.v1_create_supplier_bill_draft(
  uuid,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_update_supplier_bill_draft(
  uuid,uuid,integer,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_approve_supplier_bill(
  uuid,uuid,integer,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_record_supplier_payment(
  uuid,uuid,integer,date,text,text,text,text,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_reverse_supplier_payment(
  uuid,uuid,integer,uuid,date,text,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_cancel_supplier_bill(
  uuid,uuid,integer,text,uuid
) to authenticated, service_role;
grant execute on function public.v1_get_supplier_bill(uuid,uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_supplier_bills(
  uuid,text,text,text,timestamptz,uuid,integer
) to authenticated, service_role;

-- Accounts role defaults are inherent job authority, not person-specific User
-- Management grants. Activating them must not silently revoke an established
-- password-reset or activation capability merely because the target's exact
-- role now carries a non-delegable Accounts default. Preserve the complete
-- pre-T04 ceiling for exact-role creation/change in a dedicated strict helper,
-- while the action-only hierarchy ignores the Accounts module. A companion
-- Auth trigger applies the strict helper to every role-bearing mutation before
-- the existing durable audit trigger runs, so this compatibility boundary
-- cannot be bypassed by calling GoTrue/service_role directly.
create or replace function public.v1_auth_admin_actor_can_manage_role_strict(
  p_actor_auth_user_id uuid,
  p_target_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_exact_role text := public.v1_permission_exact_role(
    p_actor_auth_user_id
  );
begin
  if v_actor_exact_role = ''
    or not coalesce(public.v1_is_valid_role(p_target_exact_role), false) then
    return false;
  end if;
  if v_actor_exact_role in ('admin', 'senior_mechanical_engineer') then
    return true;
  end if;
  if p_target_exact_role in ('admin', 'senior_mechanical_engineer') then
    return false;
  end if;
  return not exists (
    select 1
    from public.v1_permission_role_defaults target_default
    join public.v1_capability_catalog catalog
      on catalog.capability_key = target_default.capability_key
    where target_default.role_name = p_target_exact_role
      and target_default.is_granted
      and catalog.status = 'operational'
      and not exists (
        select 1
        from public.v1_permission_role_defaults actor_ceiling
        where actor_ceiling.role_name = v_actor_exact_role
          and actor_ceiling.capability_key = target_default.capability_key
          and actor_ceiling.can_delegate
      )
  );
end;
$$;

create or replace function public.v1_auth_admin_actor_can_manage_role(
  p_actor_auth_user_id uuid,
  p_target_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_exact_role text := public.v1_permission_exact_role(
    p_actor_auth_user_id
  );
begin
  if v_actor_exact_role = ''
    or not coalesce(public.v1_is_valid_role(p_target_exact_role), false) then
    return false;
  end if;
  if v_actor_exact_role in ('admin', 'senior_mechanical_engineer') then
    return true;
  end if;
  if p_target_exact_role in ('admin', 'senior_mechanical_engineer') then
    return false;
  end if;
  return not exists (
    select 1
    from public.v1_permission_role_defaults target_default
    join public.v1_capability_catalog catalog
      on catalog.capability_key = target_default.capability_key
    where target_default.role_name = p_target_exact_role
      and target_default.is_granted
      and catalog.status = 'operational'
      and catalog.module_key <> 'accounts'
      and not exists (
        select 1
        from public.v1_permission_role_defaults actor_ceiling
        where actor_ceiling.role_name = v_actor_exact_role
          and actor_ceiling.capability_key = target_default.capability_key
          and actor_ceiling.can_delegate
      )
  );
end;
$$;

create or replace function public.v1_accounts_auth_role_ceiling_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_context jsonb := coalesce(new.raw_app_meta_data, '{}'::jsonb)
    -> '_v1_admin_audit_context';
  v_action text := coalesce(v_context ->> 'action', '');
  v_actor_text text := coalesce(v_context ->> 'actor_auth_user_id', '');
  v_actor_auth_user_id uuid;
  v_old_role text := case when tg_op = 'UPDATE'
    then coalesce(old.raw_app_meta_data ->> 'role', '') else '' end;
  v_new_role text := coalesce(new.raw_app_meta_data ->> 'role', '');
begin
  if v_context is null
    or v_action not in (
      'created', 'provisioned', 'provisioning_recovered', 'role_changed'
    )
    or v_actor_text !~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  then
    return new;
  end if;

  v_actor_auth_user_id := v_actor_text::uuid;
  if v_action in ('created', 'provisioned', 'provisioning_recovered')
    and coalesce(public.v1_is_valid_role(v_new_role), false)
    and not public.v1_auth_admin_actor_can_manage_role_strict(
      v_actor_auth_user_id, v_new_role
    )
  then
    raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
      using errcode = '42501';
  end if;

  if v_action = 'role_changed'
    and coalesce(public.v1_is_valid_role(v_old_role), false)
    and (
      not public.v1_auth_admin_actor_can_manage_role_strict(
        v_actor_auth_user_id, v_old_role
      )
      or not public.v1_auth_admin_actor_can_manage_role_strict(
        v_actor_auth_user_id, v_new_role
      )
    )
  then
    raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_auth_users_00_accounts_role_ceiling on auth.users;
create trigger v1_auth_users_00_accounts_role_ceiling
before insert or update of raw_app_meta_data, raw_user_meta_data, banned_until
on auth.users
for each row execute function public.v1_accounts_auth_role_ceiling_guard();

revoke all on function public.v1_auth_admin_actor_can_manage_role_strict(
  uuid, text
) from public, anon, authenticated;
revoke all on function public.v1_accounts_auth_role_ceiling_guard()
  from public, anon, authenticated;
