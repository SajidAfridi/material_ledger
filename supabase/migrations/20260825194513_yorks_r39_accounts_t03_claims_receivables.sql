-- Yorks R39 Accounts T03: protected client claims and receivables.
--
-- This additive slice activates only the five T03 consumers implemented here:
-- prepare_client_claim, manage_client_invoices,
-- record_client_certification, record_client_payment and manage_pdc.
-- Supplier bills, exports and T06 document policy remain planned and disabled.
--
-- Binding fail-closed T03 policies:
-- * claims are distinct from invoices and reserve capacity while non-cancelled;
-- * only draft deletion or explicit cancellation releases claim capacity;
-- * certification facts are append-only cumulative snapshots and never decrease;
-- * invoices with certification, payment or PDC facts cannot be cancelled;
-- * a cleared PDC requires explicit clearance reference/date and atomically
--   appends exactly one linked payment fact;
-- * payment correction is an exact, one-for-one append-only reversal;
-- * every claimed line needs a nonblank evidence reference before Accounts may
--   create/submit the client invoice;
-- * PDC exposure includes expected/received/deposited only.
-- T06 owns shared notification delivery/deduplication. T03 writes complete
-- transition/audit facts but deliberately creates no parallel notification
-- relation or transport path.
--
-- Data preservation: no T01/T02 or operational row is rewritten. Rollback is
-- feature-flag/capability disablement while retaining all commercial history.

begin;

update public.v1_capability_catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true
where capability_key = any(array[
  'prepare_client_claim',
  'manage_client_invoices',
  'record_client_certification',
  'record_client_payment',
  'manage_pdc'
]::text[]);

-- FR-064/065 explicitly allows Admin to maintain a Project Engineer's draft.
update public.v1_permission_role_defaults
set is_granted = true,
    can_delegate = true,
    updated_at = clock_timestamp()
where role_name = 'admin'
  and capability_key = any(array[
    'prepare_client_claim',
    'manage_client_invoices',
    'record_client_certification',
    'record_client_payment',
    'manage_pdc'
  ]::text[]);

create table public.v1_accounts_client_claims (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  claim_reference text not null check (btrim(claim_reference) <> ''),
  claim_period_start date not null,
  claim_period_end date not null,
  status text not null default 'draft' check (
    status in ('draft', 'ready_for_accounts', 'invoiced', 'cancelled')
  ),
  admin_exception_reason text check (
    admin_exception_reason is null
    or nullif(btrim(admin_exception_reason), '') is not null
  ),
  notes text,
  is_stale boolean not null default false,
  stale_reason text,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  created_by_exact_role text not null check (created_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  ready_for_accounts_at timestamptz,
  ready_for_accounts_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  cancelled_at timestamptz,
  cancelled_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  cancellation_reason text,
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (claim_period_end >= claim_period_start),
  check (
    (not is_stale and stale_reason is null)
    or (is_stale and nullif(btrim(stale_reason), '') is not null)
  ),
  check (
    (status = 'draft' and ready_for_accounts_at is null
      and ready_for_accounts_by_auth_user_id is null
      and cancelled_at is null and cancelled_by_auth_user_id is null
      and cancellation_reason is null)
    or (status in ('ready_for_accounts', 'invoiced')
      and ready_for_accounts_at is not null
      and ready_for_accounts_by_auth_user_id is not null
      and cancelled_at is null and cancelled_by_auth_user_id is null
      and cancellation_reason is null)
    or (status = 'cancelled' and cancelled_at is not null
      and cancelled_by_auth_user_id is not null
      and nullif(btrim(cancellation_reason), '') is not null)
  )
);

create unique index v1_accounts_claim_reference_project_uq
  on public.v1_accounts_client_claims
    (project_id, lower(btrim(claim_reference)));
create index v1_accounts_claim_project_status_idx
  on public.v1_accounts_client_claims
    (project_id, status, updated_at desc, id desc);
create index v1_accounts_claim_baseline_idx
  on public.v1_accounts_client_claims
    (baseline_revision_id, status) where status <> 'cancelled';

create table public.v1_accounts_client_claim_lines (
  id uuid primary key default gen_random_uuid(),
  claim_id uuid not null
    references public.v1_accounts_client_claims (id) on delete cascade,
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  progress_entry_id uuid not null
    references public.v1_accounts_billing_progress (id) on delete restrict,
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  progress_revision_id uuid not null
    references public.v1_accounts_billing_progress_revisions (id)
      on delete restrict,
  progress_record_version integer not null check (progress_record_version > 0),
  project_scope_id uuid not null
    references public.v1_project_scopes (id) on delete restrict,
  stage_key text not null check (stage_key ~ '^[a-z][a-z0-9_]*$'),
  stage_value_snapshot numeric(20,2) not null check (
    stage_value_snapshot::text <> 'NaN' and stage_value_snapshot >= 0
  ),
  confirmed_percent_snapshot numeric(7,4) not null check (
    confirmed_percent_snapshot::text <> 'NaN'
    and confirmed_percent_snapshot between 0 and 100
  ),
  eligible_amount_snapshot numeric(20,2) not null check (
    eligible_amount_snapshot::text <> 'NaN'
    and eligible_amount_snapshot >= 0
  ),
  previously_claimed_amount_snapshot numeric(20,2) not null check (
    previously_claimed_amount_snapshot::text <> 'NaN'
    and previously_claimed_amount_snapshot >= 0
  ),
  claimed_amount numeric(20,2) not null check (
    claimed_amount::text <> 'NaN' and claimed_amount > 0
  ),
  evidence_reference text,
  created_at timestamptz not null default clock_timestamp(),
  unique (claim_id, progress_entry_id)
);

create index v1_accounts_claim_line_progress_idx
  on public.v1_accounts_client_claim_lines
    (progress_entry_id, claim_id);

create table public.v1_accounts_client_invoices (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  claim_id uuid not null unique
    references public.v1_accounts_client_claims (id) on delete restrict,
  invoice_reference text not null check (btrim(invoice_reference) <> ''),
  status text not null default 'draft' check (status in (
    'draft', 'submitted', 'under_certification', 'partially_certified',
    'certified', 'partially_paid', 'paid', 'returned', 'cancelled'
  )),
  claimed_ex_vat numeric(20,2) not null check (
    claimed_ex_vat::text <> 'NaN' and claimed_ex_vat > 0
  ),
  vat_rate_percent_snapshot numeric(7,4) not null check (
    vat_rate_percent_snapshot::text <> 'NaN'
    and vat_rate_percent_snapshot between 0 and 100
  ),
  vat_amount_snapshot numeric(20,2) not null check (
    vat_amount_snapshot::text <> 'NaN' and vat_amount_snapshot >= 0
  ),
  total_incl_vat_snapshot numeric(20,2) not null check (
    total_incl_vat_snapshot::text <> 'NaN'
    and total_incl_vat_snapshot = claimed_ex_vat + vat_amount_snapshot
  ),
  payment_terms_days_snapshot integer not null
    check (payment_terms_days_snapshot > 0),
  reminder_lead_days_snapshot integer not null check (
    reminder_lead_days_snapshot >= 0
    and reminder_lead_days_snapshot <= payment_terms_days_snapshot
  ),
  submission_date date,
  due_date date,
  submitted_at timestamptz,
  submitted_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  returned_at timestamptz,
  returned_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  return_reason text,
  cancelled_at timestamptz,
  cancelled_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  cancellation_reason text,
  admin_exception_reason text,
  notes text,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  created_by_exact_role text not null check (created_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (submission_date is null and due_date is null and submitted_at is null
      and submitted_by_auth_user_id is null)
    or (submission_date is not null
      and due_date = submission_date + payment_terms_days_snapshot
      and submitted_at is not null and submitted_by_auth_user_id is not null)
  ),
  check (
    (status <> 'returned' and returned_at is null
      and returned_by_auth_user_id is null and return_reason is null)
    or (status = 'returned' and returned_at is not null
      and returned_by_auth_user_id is not null
      and nullif(btrim(return_reason), '') is not null)
  ),
  check (
    (status <> 'cancelled' and cancelled_at is null
      and cancelled_by_auth_user_id is null and cancellation_reason is null)
    or (status = 'cancelled' and cancelled_at is not null
      and cancelled_by_auth_user_id is not null
      and nullif(btrim(cancellation_reason), '') is not null)
  )
);

create unique index v1_accounts_invoice_reference_project_uq
  on public.v1_accounts_client_invoices
    (project_id, lower(btrim(invoice_reference)));
create index v1_accounts_invoice_project_status_idx
  on public.v1_accounts_client_invoices
    (project_id, status, updated_at desc, id desc);
create index v1_accounts_invoice_due_idx
  on public.v1_accounts_client_invoices
    (due_date, project_id)
  where status not in ('draft', 'returned', 'cancelled', 'paid');

create table public.v1_accounts_client_certifications (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  invoice_id uuid not null
    references public.v1_accounts_client_invoices (id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  certification_reference text not null
    check (btrim(certification_reference) <> ''),
  certification_date date not null,
  certified_ex_vat numeric(20,2) not null check (
    certified_ex_vat::text <> 'NaN' and certified_ex_vat >= 0
  ),
  certified_vat numeric(20,2) not null check (
    certified_vat::text <> 'NaN' and certified_vat >= 0
  ),
  certified_incl_vat numeric(20,2) not null check (
    certified_incl_vat::text <> 'NaN'
    and certified_incl_vat = certified_ex_vat + certified_vat
  ),
  difference_reason text,
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  actor_exact_role text not null check (actor_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  unique (invoice_id, revision_number),
  check (
    difference_reason is null or nullif(btrim(difference_reason), '') is not null
  )
);

create index v1_accounts_certification_project_idx
  on public.v1_accounts_client_certifications
    (project_id, invoice_id, revision_number desc);

create table public.v1_accounts_client_payments (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  invoice_id uuid not null
    references public.v1_accounts_client_invoices (id) on delete restrict,
  entry_kind text not null check (entry_kind in ('receipt', 'reversal')),
  original_payment_id uuid
    references public.v1_accounts_client_payments (id) on delete restrict,
  pdc_id uuid,
  payment_date date not null,
  payment_method text not null check (btrim(payment_method) <> ''),
  payment_reference text not null check (btrim(payment_reference) <> ''),
  amount numeric(20,2) not null check (
    amount::text <> 'NaN' and amount > 0
  ),
  reason text,
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  actor_exact_role text not null check (actor_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (entry_kind = 'receipt' and original_payment_id is null)
    or (entry_kind = 'reversal' and original_payment_id is not null
      and nullif(btrim(reason), '') is not null)
  )
);

create unique index v1_accounts_payment_reference_project_uq
  on public.v1_accounts_client_payments
    (project_id, lower(btrim(payment_reference)));
create unique index v1_accounts_one_payment_reversal_uq
  on public.v1_accounts_client_payments (original_payment_id)
  where entry_kind = 'reversal';
create unique index v1_accounts_one_pdc_payment_uq
  on public.v1_accounts_client_payments (pdc_id)
  where pdc_id is not null and entry_kind = 'receipt';
create index v1_accounts_payment_invoice_idx
  on public.v1_accounts_client_payments
    (invoice_id, payment_date, created_at, id);

create table public.v1_accounts_client_pdcs (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  invoice_id uuid not null
    references public.v1_accounts_client_invoices (id) on delete restrict,
  cheque_number text not null check (btrim(cheque_number) <> ''),
  cheque_date date not null,
  amount numeric(20,2) not null check (
    amount::text <> 'NaN' and amount > 0
  ),
  bank_name text,
  received_date date,
  status text not null default 'expected' check (status in (
    'expected', 'received', 'deposited', 'cleared', 'replaced',
    'returned', 'bounced', 'cancelled'
  )),
  replaces_pdc_id uuid unique
    references public.v1_accounts_client_pdcs (id) on delete restrict,
  replaced_by_pdc_id uuid unique
    references public.v1_accounts_client_pdcs (id) on delete restrict,
  action_required boolean not null default false,
  last_action_reason text,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  created_by_exact_role text not null check (created_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (status in ('returned', 'bounced') and action_required
      and nullif(btrim(last_action_reason), '') is not null)
    or (status not in ('returned', 'bounced') and not action_required)
  ),
  check (
    (status in ('received', 'deposited', 'cleared')
      and received_date is not null)
    or status not in ('received', 'deposited', 'cleared')
  )
);

alter table public.v1_accounts_client_payments
  add constraint v1_accounts_payment_pdc_fk
  foreign key (pdc_id) references public.v1_accounts_client_pdcs (id)
  on delete restrict deferrable initially deferred;

create unique index v1_accounts_pdc_cheque_project_uq
  on public.v1_accounts_client_pdcs
    (project_id, lower(btrim(cheque_number)));
create index v1_accounts_pdc_invoice_idx
  on public.v1_accounts_client_pdcs
    (invoice_id, cheque_date, created_at, id);
create index v1_accounts_pdc_action_idx
  on public.v1_accounts_client_pdcs
    (project_id, status, updated_at desc)
  where action_required;

create table public.v1_accounts_client_pdc_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  invoice_id uuid not null
    references public.v1_accounts_client_invoices (id) on delete restrict,
  pdc_id uuid not null
    references public.v1_accounts_client_pdcs (id) on delete restrict,
  sequence_number integer not null check (sequence_number > 0),
  from_status text,
  to_status text not null check (to_status in (
    'expected', 'received', 'deposited', 'cleared', 'replaced',
    'returned', 'bounced', 'cancelled'
  )),
  action_date date not null,
  reason text,
  linked_payment_id uuid
    references public.v1_accounts_client_payments (id) on delete restrict,
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  actor_exact_role text not null check (actor_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  occurred_at timestamptz not null default clock_timestamp(),
  unique (pdc_id, sequence_number),
  check (from_status is null or from_status in (
    'expected', 'received', 'deposited', 'cleared', 'replaced',
    'returned', 'bounced', 'cancelled'
  ))
);

create index v1_accounts_pdc_event_invoice_idx
  on public.v1_accounts_client_pdc_events
    (invoice_id, occurred_at desc, id desc);

alter table public.v1_accounts_client_claims enable row level security;
alter table public.v1_accounts_client_claim_lines enable row level security;
alter table public.v1_accounts_client_invoices enable row level security;
alter table public.v1_accounts_client_certifications enable row level security;
alter table public.v1_accounts_client_payments enable row level security;
alter table public.v1_accounts_client_pdcs enable row level security;
alter table public.v1_accounts_client_pdc_events enable row level security;

revoke all on table public.v1_accounts_client_claims
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_claim_lines
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_invoices
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_certifications
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_payments
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_pdcs
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_client_pdc_events
  from public, anon, authenticated, service_role;

grant select on table public.v1_accounts_client_claims to service_role;
grant select on table public.v1_accounts_client_claim_lines to service_role;
grant select on table public.v1_accounts_client_invoices to service_role;
grant select on table public.v1_accounts_client_certifications to service_role;
grant select on table public.v1_accounts_client_payments to service_role;
grant select on table public.v1_accounts_client_pdcs to service_role;
grant select on table public.v1_accounts_client_pdc_events to service_role;

-- Commercial dimensions are intentionally repeated on immutable facts so that
-- operational reporting remains indexable. These triggers make the duplicated
-- dimensions authoritative rather than trusting an RPC caller to correlate
-- them correctly.
create or replace function public.v1_accounts_validate_claim_line_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_claim public.v1_accounts_client_claims%rowtype;
  v_progress public.v1_accounts_billing_progress%rowtype;
  v_revision public.v1_accounts_billing_progress_revisions%rowtype;
begin
  select * into v_claim from public.v1_accounts_client_claims
  where id = new.claim_id;
  select * into v_progress from public.v1_accounts_billing_progress
  where id = new.progress_entry_id;
  select * into v_revision from public.v1_accounts_billing_progress_revisions
  where id = new.progress_revision_id;
  if v_claim.id is null or v_progress.id is null or v_revision.id is null
    or v_claim.project_id <> new.project_id
    or v_claim.baseline_revision_id <> new.baseline_revision_id
    or v_progress.project_id <> new.project_id
    or v_progress.baseline_revision_id <> new.baseline_revision_id
    or v_progress.project_scope_id <> new.project_scope_id
    or v_progress.stage_key <> new.stage_key
    or v_revision.progress_entry_id <> new.progress_entry_id
    or v_revision.project_id <> new.project_id
    or v_revision.new_confirmed_percent <> v_progress.confirmed_percent
    or v_progress.record_version <> new.progress_record_version then
    raise exception 'R39_ACCOUNTS_CLAIM_LINE_DIMENSION_MISMATCH'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_accounts_claim_line_dimension_guard
before insert or update on public.v1_accounts_client_claim_lines
for each row execute function public.v1_accounts_validate_claim_line_row();

create or replace function public.v1_accounts_validate_receivable_child_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice_project uuid;
  v_pdc_project uuid;
  v_pdc_invoice uuid;
  v_original public.v1_accounts_client_payments%rowtype;
begin
  if tg_table_name = 'v1_accounts_client_invoices' then
    select claim.project_id into v_invoice_project
    from public.v1_accounts_client_claims claim where claim.id = new.claim_id;
    if v_invoice_project is null or v_invoice_project <> new.project_id then
      raise exception 'R39_ACCOUNTS_RECEIVABLE_DIMENSION_MISMATCH'
        using errcode = '23514';
    end if;
    return new;
  end if;
  select invoice.project_id into v_invoice_project
  from public.v1_accounts_client_invoices invoice where invoice.id = new.invoice_id;
  if v_invoice_project is null or v_invoice_project <> new.project_id then
    raise exception 'R39_ACCOUNTS_RECEIVABLE_DIMENSION_MISMATCH'
      using errcode = '23514';
  end if;
  if tg_table_name = 'v1_accounts_client_payments' then
    if new.entry_kind = 'reversal' then
      select * into v_original from public.v1_accounts_client_payments
      where id = new.original_payment_id;
      if v_original.id is null or v_original.entry_kind <> 'receipt'
        or v_original.project_id <> new.project_id
        or v_original.invoice_id <> new.invoice_id
        or v_original.amount <> new.amount then
        raise exception 'R39_ACCOUNTS_INVALID_PAYMENT_REVERSAL'
          using errcode = '23514';
      end if;
    end if;
    if new.pdc_id is not null then
      select pdc.project_id, pdc.invoice_id into v_pdc_project, v_pdc_invoice
      from public.v1_accounts_client_pdcs pdc where pdc.id = new.pdc_id;
      if v_pdc_project is null or v_pdc_project <> new.project_id
        or v_pdc_invoice <> new.invoice_id then
        raise exception 'R39_ACCOUNTS_RECEIVABLE_DIMENSION_MISMATCH'
          using errcode = '23514';
      end if;
    end if;
  elsif tg_table_name = 'v1_accounts_client_pdc_events' then
    select pdc.project_id, pdc.invoice_id into v_pdc_project, v_pdc_invoice
    from public.v1_accounts_client_pdcs pdc where pdc.id = new.pdc_id;
    if v_pdc_project is null or v_pdc_project <> new.project_id
      or v_pdc_invoice <> new.invoice_id then
      raise exception 'R39_ACCOUNTS_RECEIVABLE_DIMENSION_MISMATCH'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create trigger v1_accounts_invoice_dimension_guard
before insert or update on public.v1_accounts_client_invoices
for each row execute function public.v1_accounts_validate_receivable_child_row();
create trigger v1_accounts_certification_dimension_guard
before insert or update on public.v1_accounts_client_certifications
for each row execute function public.v1_accounts_validate_receivable_child_row();
create trigger v1_accounts_payment_dimension_guard
before insert or update on public.v1_accounts_client_payments
for each row execute function public.v1_accounts_validate_receivable_child_row();
create trigger v1_accounts_pdc_dimension_guard
before insert or update on public.v1_accounts_client_pdcs
for each row execute function public.v1_accounts_validate_receivable_child_row();
create trigger v1_accounts_pdc_event_dimension_guard
before insert or update on public.v1_accounts_client_pdc_events
for each row execute function public.v1_accounts_validate_receivable_child_row();

create or replace function public.v1_accounts_append_only_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'R39_ACCOUNTS_APPEND_ONLY_FACT' using errcode = '42501';
end;
$$;

create trigger v1_accounts_certification_append_only
before update or delete on public.v1_accounts_client_certifications
for each row execute function public.v1_accounts_append_only_guard();
create trigger v1_accounts_payment_append_only
before update or delete on public.v1_accounts_client_payments
for each row execute function public.v1_accounts_append_only_guard();
create trigger v1_accounts_pdc_event_append_only
before update or delete on public.v1_accounts_client_pdc_events
for each row execute function public.v1_accounts_append_only_guard();

-- Replace the protected T02 seams with real, claim-backed behavior. Cancelled
-- claims release capacity; every other lifecycle state reserves it.
create or replace function public.v1_accounts_consumed_claim_amount(
  p_progress_entry_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(line.claimed_amount), 0)::numeric
  from public.v1_accounts_client_claim_lines line
  join public.v1_accounts_client_claims claim on claim.id = line.claim_id
  where line.progress_entry_id = p_progress_entry_id
    and claim.status <> 'cancelled';
$$;

create or replace function public.v1_accounts_mark_claim_drafts_stale(
  p_old_baseline_revision_id uuid,
  p_new_baseline_revision_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_count integer;
begin
  update public.v1_accounts_client_claims claim
  set is_stale = true,
      stale_reason = 'Commercial baseline revised',
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where claim.baseline_revision_id = p_old_baseline_revision_id
    and claim.status in ('draft', 'ready_for_accounts')
    and not claim.is_stale;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create or replace function public.v1_accounts_invoice_certified_ex_vat(
  p_invoice_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.certified_ex_vat
    from public.v1_accounts_client_certifications c
    where c.invoice_id = p_invoice_id
    order by c.revision_number desc limit 1), 0)::numeric;
$$;

create or replace function public.v1_accounts_invoice_certified_incl_vat(
  p_invoice_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.certified_incl_vat
    from public.v1_accounts_client_certifications c
    where c.invoice_id = p_invoice_id
    order by c.revision_number desc limit 1), 0)::numeric;
$$;

create or replace function public.v1_accounts_invoice_paid_amount(
  p_invoice_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(case when p.entry_kind = 'receipt' then p.amount
    else -p.amount end), 0)::numeric
  from public.v1_accounts_client_payments p where p.invoice_id = p_invoice_id;
$$;

create or replace function public.v1_accounts_invoice_pdc_exposure(
  p_invoice_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(pdc.amount), 0)::numeric
  from public.v1_accounts_client_pdcs pdc
  where pdc.invoice_id = p_invoice_id
    and pdc.status in ('expected', 'received', 'deposited');
$$;

create or replace function public.v1_accounts_refresh_invoice_status(
  p_invoice_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.v1_accounts_client_invoices%rowtype;
  v_certified numeric;
  v_paid numeric;
  v_status text;
begin
  select * into v_invoice from public.v1_accounts_client_invoices
  where id = p_invoice_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND'
    using errcode = 'P0002'; end if;
  if v_invoice.status in ('draft','returned','cancelled') then
    return v_invoice.status;
  end if;
  v_certified := public.v1_accounts_invoice_certified_incl_vat(p_invoice_id);
  v_paid := public.v1_accounts_invoice_paid_amount(p_invoice_id);
  v_status := case
    when v_certified > 0 and v_paid >= v_certified then 'paid'
    when v_paid > 0 then 'partially_paid'
    when v_certified >= v_invoice.total_incl_vat_snapshot then 'certified'
    when v_certified > 0 then 'partially_certified'
    when v_invoice.status = 'under_certification' then 'under_certification'
    else 'submitted' end;
  update public.v1_accounts_client_invoices
  set status = v_status, updated_at = clock_timestamp()
  where id = p_invoice_id;
  return v_status;
end;
$$;

create or replace function public.v1_accounts_receivables_capabilities(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'view_project_commercial_values', public.v1_current_user_has_capability('view_project_commercial_values', p_project_id),
    'prepare_client_claim', public.v1_current_user_has_capability('prepare_client_claim', p_project_id),
    'manage_client_invoices', public.v1_current_user_has_capability('manage_client_invoices', p_project_id),
    'record_client_certification', public.v1_current_user_has_capability('record_client_certification', p_project_id),
    'record_client_payment', public.v1_current_user_has_capability('record_client_payment', p_project_id),
    'manage_pdc', public.v1_current_user_has_capability('manage_pdc', p_project_id)
  );
$$;

create or replace function public.v1_accounts_receivables_commands(
  p_project_id uuid
)
returns jsonb
language sql stable security definer set search_path=''
as $$
  select jsonb_build_object(
    'create_claim_draft', public.v1_current_user_has_capability('prepare_client_claim',p_project_id)
      and public.v1_current_user_has_capability('view_project_commercial_values',p_project_id),
    'edit_claim_draft', public.v1_current_user_has_capability('prepare_client_claim',p_project_id),
    'submit_claim_to_accounts', public.v1_current_user_has_capability('prepare_client_claim',p_project_id),
    'cancel_claim', public.v1_current_user_has_capability('prepare_client_claim',p_project_id)
      or public.v1_current_user_has_capability('manage_client_invoices',p_project_id),
    'create_invoice_draft', public.v1_current_user_has_capability('manage_client_invoices',p_project_id),
    'submit_invoice', public.v1_current_user_has_capability('manage_client_invoices',p_project_id),
    'return_invoice', public.v1_current_user_has_capability('manage_client_invoices',p_project_id),
    'cancel_invoice', public.v1_current_user_has_capability('manage_client_invoices',p_project_id),
    'record_certification', public.v1_current_user_has_capability('record_client_certification',p_project_id),
    'record_payment', public.v1_current_user_has_capability('record_client_payment',p_project_id),
    'reverse_payment', public.v1_current_user_has_capability('record_client_payment',p_project_id),
    'create_pdc', public.v1_current_user_has_capability('manage_pdc',p_project_id),
    'transition_pdc', public.v1_current_user_has_capability('manage_pdc',p_project_id),
    'replace_pdc', public.v1_current_user_has_capability('manage_pdc',p_project_id)
  );
$$;

create or replace function public.v1_accounts_validate_claim_lines(
  p_project_id uuid,
  p_baseline_revision_id uuid,
  p_lines jsonb,
  p_excluded_claim_id uuid default null,
  p_allow_admin_exception boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_line jsonb;
  v_keys text[];
  v_progress public.v1_accounts_billing_progress%rowtype;
  v_progress_revision_id uuid;
  v_stage_value numeric;
  v_eligible numeric;
  v_consumed numeric;
  v_claim numeric;
  v_evidence text;
  v_result jsonb := '[]'::jsonb;
  v_seen uuid[] := '{}';
begin
  if jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'R39_ACCOUNTS_CLAIM_LINES_REQUIRED' using errcode = '22023';
  end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line) <> 'object' then
      raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode = '22023';
    end if;
    select coalesce(array_agg(key order by key), '{}') into v_keys
    from jsonb_object_keys(v_line) key;
    if v_keys <> array['claimed_amount','evidence_reference','progress_entry_id']::text[] then
      raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode = '22023';
    end if;
    begin
      select * into strict v_progress from public.v1_accounts_billing_progress
      where id = (v_line ->> 'progress_entry_id')::uuid for update;
    exception when no_data_found or invalid_text_representation then
      raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode = '22023';
    end;
    if v_progress.id = any(v_seen) or v_progress.project_id <> p_project_id
      or v_progress.baseline_revision_id <> p_baseline_revision_id
      or v_progress.confirmed_percent <= 0
      or v_progress.review_status not in ('not_required','approved') then
      raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode = '22023';
    end if;
    v_seen := array_append(v_seen, v_progress.id);
    v_claim := public.v1_accounts_parse_money_text(v_line ->> 'claimed_amount');
    if v_claim <= 0 then
      raise exception 'R39_ACCOUNTS_INVALID_CLAIM_AMOUNT' using errcode = '22023';
    end if;
    v_stage_value := public.v1_accounts_stage_value(v_progress.id);
    v_eligible := round(v_stage_value * v_progress.confirmed_percent / 100, 2);
    select coalesce(sum(line.claimed_amount), 0) into v_consumed
    from public.v1_accounts_client_claim_lines line
    join public.v1_accounts_client_claims claim on claim.id = line.claim_id
    where line.progress_entry_id = v_progress.id
      and claim.status <> 'cancelled'
      and claim.id is distinct from p_excluded_claim_id;
    if v_claim > greatest(v_eligible - v_consumed, 0)
      and not p_allow_admin_exception then
      raise exception 'R39_ACCOUNTS_CLAIM_CAP_EXCEEDED' using errcode = '23514';
    end if;
    select revision.id into v_progress_revision_id
    from public.v1_accounts_billing_progress_revisions revision
    where revision.progress_entry_id = v_progress.id
    order by revision.revision_number desc
    limit 1;
    if v_progress_revision_id is null then
      raise exception 'R39_ACCOUNTS_PROGRESS_SNAPSHOT_MISSING' using errcode = '55000';
    end if;
    v_evidence := nullif(btrim(v_line ->> 'evidence_reference'), '');
    v_result := v_result || jsonb_build_array(jsonb_build_object(
      'progress_entry_id', v_progress.id,
      'progress_revision_id', v_progress_revision_id,
      'progress_record_version', v_progress.record_version,
      'project_scope_id', v_progress.project_scope_id,
      'stage_key', v_progress.stage_key,
      'stage_value_snapshot', v_stage_value::text,
      'confirmed_percent_snapshot', v_progress.confirmed_percent::text,
      'eligible_amount_snapshot', v_eligible::text,
      'previously_claimed_amount_snapshot', v_consumed::text,
      'claimed_amount', v_claim::text,
      'evidence_reference', v_evidence
    ));
  end loop;
  return v_result;
end;
$$;

create or replace function public.v1_accounts_normalize_claim_input_lines(p_lines jsonb)
returns jsonb language plpgsql immutable security definer set search_path=''
as $$
declare v_line jsonb;v_keys text[];v_result jsonb:='[]'::jsonb;v_progress uuid;v_amount numeric;v_evidence text;
begin
  if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 then raise exception 'R39_ACCOUNTS_CLAIM_LINES_REQUIRED' using errcode='22023';end if;
  for v_line in select value from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_line)<>'object' then raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode='22023';end if;
    select coalesce(array_agg(key order by key),'{}') into v_keys from jsonb_object_keys(v_line) key;
    if v_keys<>array['claimed_amount','evidence_reference','progress_entry_id']::text[] then raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode='22023';end if;
    begin v_progress:=(v_line->>'progress_entry_id')::uuid;
    exception when invalid_text_representation then raise exception 'R39_ACCOUNTS_INVALID_CLAIM_LINE' using errcode='22023';end;
    v_amount:=public.v1_accounts_parse_money_text(v_line->>'claimed_amount');
    if v_amount<=0 then raise exception 'R39_ACCOUNTS_INVALID_CLAIM_AMOUNT' using errcode='22023';end if;
    v_evidence:=nullif(btrim(v_line->>'evidence_reference'),'');
    v_result:=v_result||jsonb_build_array(jsonb_build_object('progress_entry_id',v_progress,'claimed_amount',v_amount::text,'evidence_reference',v_evidence));
  end loop;
  return v_result;
end;
$$;

create or replace function public.v1_accounts_replace_claim_lines(
  p_claim_id uuid,
  p_project_id uuid,
  p_baseline_revision_id uuid,
  p_lines jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.v1_accounts_client_claim_lines where claim_id = p_claim_id;
  insert into public.v1_accounts_client_claim_lines (
    claim_id, project_id, progress_entry_id, baseline_revision_id,
    progress_revision_id, progress_record_version, project_scope_id, stage_key,
    stage_value_snapshot, confirmed_percent_snapshot, eligible_amount_snapshot,
    previously_claimed_amount_snapshot, claimed_amount, evidence_reference
  )
  select p_claim_id, p_project_id,
    (line ->> 'progress_entry_id')::uuid, p_baseline_revision_id,
    (line ->> 'progress_revision_id')::uuid,
    (line ->> 'progress_record_version')::integer,
    (line ->> 'project_scope_id')::uuid, line ->> 'stage_key',
    (line ->> 'stage_value_snapshot')::numeric,
    (line ->> 'confirmed_percent_snapshot')::numeric,
    (line ->> 'eligible_amount_snapshot')::numeric,
    (line ->> 'previously_claimed_amount_snapshot')::numeric,
    (line ->> 'claimed_amount')::numeric,
    nullif(line ->> 'evidence_reference','')
  from jsonb_array_elements(p_lines) line;
end;
$$;

create or replace function public.v1_accounts_claim_snapshot(
  p_claim_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_claim public.v1_accounts_client_claims%rowtype; v_lines jsonb;
begin
  select * into v_claim from public.v1_accounts_client_claims where id=p_claim_id;
  if not found then return null; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'line_id', line.id,
    'progress_entry_id', line.progress_entry_id,
    'progress_revision_id', line.progress_revision_id,
    'progress_record_version', line.progress_record_version,
    'building_scope_id', line.project_scope_id,
    'stage_key', line.stage_key,
    'stage_value_snapshot', line.stage_value_snapshot::text,
    'confirmed_percent_snapshot', line.confirmed_percent_snapshot::text,
    'eligible_amount_snapshot', line.eligible_amount_snapshot::text,
    'previously_claimed_amount_snapshot', line.previously_claimed_amount_snapshot::text,
    'claimed_amount', line.claimed_amount::text,
    'evidence_reference', line.evidence_reference
  ) order by line.created_at,line.id),'[]'::jsonb) into v_lines
  from public.v1_accounts_client_claim_lines line where line.claim_id=p_claim_id;
  return jsonb_build_object(
    'claim_id',v_claim.id,'project_id',v_claim.project_id,
    'baseline_revision_id',v_claim.baseline_revision_id,
    'claim_reference',v_claim.claim_reference,
    'claim_period_start',v_claim.claim_period_start,
    'claim_period_end',v_claim.claim_period_end,'status',v_claim.status,
    'admin_exception_reason',v_claim.admin_exception_reason,
    'notes',v_claim.notes,'is_stale',v_claim.is_stale,
    'stale_reason',v_claim.stale_reason,'record_version',v_claim.record_version,
    'created_by_auth_user_id',v_claim.created_by_auth_user_id,
    'created_by_role',v_claim.created_by_role,
    'created_by_exact_role',v_claim.created_by_exact_role,
    'ready_for_accounts_at',v_claim.ready_for_accounts_at,
    'cancelled_at',v_claim.cancelled_at,'cancellation_reason',v_claim.cancellation_reason,
    'claimed_ex_vat',(select coalesce(sum(claimed_amount),0)::text from public.v1_accounts_client_claim_lines where claim_id=p_claim_id),
    'lines',v_lines,'created_at',v_claim.created_at,'updated_at',v_claim.updated_at
  );
end;
$$;

create or replace function public.v1_accounts_invoice_snapshot(
  p_invoice_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_invoice public.v1_accounts_client_invoices%rowtype;
begin
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id;
  if not found then return null; end if;
  return jsonb_build_object(
    'invoice_id',v_invoice.id,'project_id',v_invoice.project_id,
    'claim_id',v_invoice.claim_id,'invoice_reference',v_invoice.invoice_reference,
    'status',v_invoice.status,'claimed_ex_vat',v_invoice.claimed_ex_vat::text,
    'vat_rate_percent_snapshot',v_invoice.vat_rate_percent_snapshot::text,
    'vat_amount_snapshot',v_invoice.vat_amount_snapshot::text,
    'total_incl_vat_snapshot',v_invoice.total_incl_vat_snapshot::text,
    'payment_terms_days_snapshot',v_invoice.payment_terms_days_snapshot,
    'reminder_lead_days_snapshot',v_invoice.reminder_lead_days_snapshot,
    'submission_date',v_invoice.submission_date,'due_date',v_invoice.due_date,
    'admin_exception_reason',v_invoice.admin_exception_reason,'notes',v_invoice.notes,
    'record_version',v_invoice.record_version,
    'certified_ex_vat',public.v1_accounts_invoice_certified_ex_vat(v_invoice.id)::text,
    'certified_incl_vat',public.v1_accounts_invoice_certified_incl_vat(v_invoice.id)::text,
    'paid_amount',public.v1_accounts_invoice_paid_amount(v_invoice.id)::text,
    'amount_paid_till_date',public.v1_accounts_invoice_paid_amount(v_invoice.id)::text,
    'still_due',greatest(public.v1_accounts_invoice_certified_incl_vat(v_invoice.id)-public.v1_accounts_invoice_paid_amount(v_invoice.id),0)::text,
    'pdc_exposure',public.v1_accounts_invoice_pdc_exposure(v_invoice.id)::text,
    'created_by_auth_user_id',v_invoice.created_by_auth_user_id,
    'created_by_role',v_invoice.created_by_role,
    'created_by_exact_role',v_invoice.created_by_exact_role,
    'created_at',v_invoice.created_at,'updated_at',v_invoice.updated_at
  );
end;
$$;

create or replace function public.v1_create_client_claim_draft(
  p_project_id uuid, p_claim_reference text,
  p_claim_period_start date, p_claim_period_end date,
  p_lines jsonb, p_notes text, p_idempotency_key uuid,
  p_admin_exception_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid(); v_exact text; v_role text:=public.v1_current_role();
  v_baseline uuid; v_lines jsonb; v_payload jsonb; v_existing jsonb;
  v_exception_reason text:=nullif(btrim(p_admin_exception_reason),'');
  v_uses_exception boolean:=false;
  v_claim_id uuid:=gen_random_uuid(); v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'prepare_client_claim');
  if not public.v1_current_user_has_capability('view_project_commercial_values',p_project_id) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if p_claim_reference is null or btrim(p_claim_reference)='' or p_claim_period_start is null
    or p_claim_period_end is null or p_claim_period_end<p_claim_period_start then
    raise exception 'R39_ACCOUNTS_INVALID_CLAIM' using errcode='22023'; end if;
  if v_exception_reason is not null and v_exact <> 'admin' then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_DENIED' using errcode='42501'; end if;
  v_lines:=public.v1_accounts_normalize_claim_input_lines(p_lines);
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_reference',btrim(p_claim_reference),
    'claim_period_start',p_claim_period_start,'claim_period_end',p_claim_period_end,
    'lines',v_lines,'notes',nullif(btrim(p_notes),''),
    'admin_exception_reason',v_exception_reason);
  v_existing:=public.v1_idempotency_get_or_claim('v1_create_client_claim_draft',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select current_baseline_revision_id into v_baseline
  from public.v1_accounts_project_commercial_profiles where project_id=p_project_id;
  if v_baseline is null then raise exception 'R39_ACCOUNTS_BASELINE_NOT_FOUND'
    using errcode='P0002'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('r39_claim|'||p_project_id::text,0));
  v_lines:=public.v1_accounts_validate_claim_lines(
    p_project_id,v_baseline,v_lines,null,v_exception_reason is not null
  );
  select exists(
    select 1 from jsonb_array_elements(v_lines) line
    where (line->>'claimed_amount')::numeric > greatest(
      (line->>'eligible_amount_snapshot')::numeric
        - (line->>'previously_claimed_amount_snapshot')::numeric,
      0
    )
  ) into v_uses_exception;
  if v_uses_exception and v_exception_reason is null then
    raise exception 'R39_ACCOUNTS_CLAIM_CAP_EXCEEDED' using errcode='23514'; end if;
  if not v_uses_exception and v_exception_reason is not null then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_NOT_REQUIRED' using errcode='22023'; end if;
  insert into public.v1_accounts_client_claims(id,project_id,baseline_revision_id,
    claim_reference,claim_period_start,claim_period_end,admin_exception_reason,notes,created_by_auth_user_id,
    created_by_role,created_by_exact_role,idempotency_key,created_at,updated_at)
  values(v_claim_id,p_project_id,v_baseline,btrim(p_claim_reference),p_claim_period_start,
    p_claim_period_end,v_exception_reason,nullif(btrim(p_notes),''),v_actor,v_role,v_exact,
    p_idempotency_key,v_now,v_now);
  perform public.v1_accounts_replace_claim_lines(v_claim_id,p_project_id,v_baseline,v_lines);
  perform public.v1_write_audit_event('accounts.client_claim.created','accounts_client_claim',v_claim_id,
    p_project_id,null,public.v1_accounts_claim_snapshot(v_claim_id),v_exception_reason,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,
    'entity_id',v_claim_id,'claim_id',v_claim_id,'record_version',1,'status','draft','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_create_client_claim_draft',p_idempotency_key,v_response);
  return v_response;
exception when unique_violation then
  raise exception 'R39_ACCOUNTS_DUPLICATE_CLAIM_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_update_client_claim_draft(
  p_project_id uuid, p_claim_id uuid, p_expected_version integer,
  p_claim_reference text, p_claim_period_start date, p_claim_period_end date,
  p_lines jsonb, p_notes text, p_idempotency_key uuid,
  p_admin_exception_reason text default null
)
returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_claim public.v1_accounts_client_claims%rowtype; v_before jsonb; v_exact text;
  v_lines jsonb; v_payload jsonb; v_existing jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
  v_exception_reason text:=nullif(btrim(p_admin_exception_reason),'');
  v_uses_exception boolean:=false;
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'prepare_client_claim');
  if not public.v1_current_user_has_capability('view_project_commercial_values',p_project_id) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if p_claim_reference is null or btrim(p_claim_reference)='' or p_claim_period_start is null
    or p_claim_period_end is null or p_claim_period_end<p_claim_period_start then
    raise exception 'R39_ACCOUNTS_INVALID_CLAIM' using errcode='22023'; end if;
  if v_exception_reason is not null and v_exact <> 'admin' then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_DENIED' using errcode='42501'; end if;
  v_lines:=public.v1_accounts_normalize_claim_input_lines(p_lines);
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_id',p_claim_id,
    'expected_version',p_expected_version,'claim_reference',btrim(p_claim_reference),
    'claim_period_start',p_claim_period_start,'claim_period_end',p_claim_period_end,
    'lines',v_lines,'notes',nullif(btrim(p_notes),''),
    'admin_exception_reason',v_exception_reason);
  v_existing:=public.v1_idempotency_get_or_claim('v1_update_client_claim_draft',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('r39_claim|'||p_project_id::text,0));
  select * into v_claim from public.v1_accounts_client_claims
  where id=p_claim_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002'; end if;
  if v_claim.status<>'draft' or v_claim.is_stale then raise exception 'R39_ACCOUNTS_CLAIM_NOT_EDITABLE'
    using errcode='55000'; end if;
  if v_claim.created_by_auth_user_id <> auth.uid()
    and public.v1_permission_exact_role(auth.uid()) <> 'admin' then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if v_claim.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT'
    using errcode='40001'; end if;
  v_lines:=public.v1_accounts_validate_claim_lines(
    p_project_id,v_claim.baseline_revision_id,v_lines,p_claim_id,
    v_exception_reason is not null
  );
  select exists(
    select 1 from jsonb_array_elements(v_lines) line
    where (line->>'claimed_amount')::numeric > greatest(
      (line->>'eligible_amount_snapshot')::numeric
        - (line->>'previously_claimed_amount_snapshot')::numeric,
      0
    )
  ) into v_uses_exception;
  if v_uses_exception and v_exception_reason is null then
    raise exception 'R39_ACCOUNTS_CLAIM_CAP_EXCEEDED' using errcode='23514'; end if;
  if not v_uses_exception and v_exception_reason is not null then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_NOT_REQUIRED' using errcode='22023'; end if;
  v_before:=public.v1_accounts_claim_snapshot(p_claim_id);
  update public.v1_accounts_client_claims set claim_reference=btrim(p_claim_reference),
    claim_period_start=p_claim_period_start,claim_period_end=p_claim_period_end,
    admin_exception_reason=v_exception_reason,notes=nullif(btrim(p_notes),''),
    record_version=record_version+1,updated_at=v_now where id=p_claim_id;
  perform public.v1_accounts_replace_claim_lines(p_claim_id,p_project_id,v_claim.baseline_revision_id,v_lines);
  perform public.v1_write_audit_event('accounts.client_claim.updated','accounts_client_claim',p_claim_id,
    p_project_id,v_before,public.v1_accounts_claim_snapshot(p_claim_id),v_exception_reason,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,
    'entity_id',p_claim_id,'claim_id',p_claim_id,'record_version',p_expected_version+1,
    'status','draft','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_update_client_claim_draft',p_idempotency_key,v_response);
  return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_CLAIM_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_delete_client_claim_draft(
  p_project_id uuid,p_claim_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_claim public.v1_accounts_client_claims%rowtype; v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb;
begin
  perform public.v1_accounts_require_capability(p_project_id,'prepare_client_claim');
  if nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_id',p_claim_id,'expected_version',p_expected_version,'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim('v1_delete_client_claim_draft',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_claim from public.v1_accounts_client_claims where id=p_claim_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002'; end if;
  if v_claim.status<>'draft' then raise exception 'R39_ACCOUNTS_CLAIM_NOT_DELETABLE' using errcode='55000'; end if;
  if v_claim.created_by_auth_user_id <> auth.uid()
    and public.v1_permission_exact_role(auth.uid()) <> 'admin' then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if v_claim.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  v_before:=public.v1_accounts_claim_snapshot(p_claim_id);
  delete from public.v1_accounts_client_claims where id=p_claim_id;
  perform public.v1_write_audit_event('accounts.client_claim.deleted','accounts_client_claim',p_claim_id,p_project_id,v_before,null,btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_claim_id,'claim_id',p_claim_id,'status','deleted');
  perform public.v1_complete_idempotency('v1_delete_client_claim_draft',p_idempotency_key,v_response); return v_response;
end;
$$;

create or replace function public.v1_submit_client_claim_to_accounts(
  p_project_id uuid,p_claim_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_claim public.v1_accounts_client_claims%rowtype; v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  perform public.v1_accounts_require_capability(p_project_id,'prepare_client_claim');
  if nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_id',p_claim_id,'expected_version',p_expected_version,'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim('v1_submit_client_claim_to_accounts',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_claim from public.v1_accounts_client_claims where id=p_claim_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002'; end if;
  if v_claim.status<>'draft' or v_claim.is_stale then raise exception 'R39_ACCOUNTS_CLAIM_NOT_SUBMITTABLE' using errcode='55000'; end if;
  if v_claim.created_by_auth_user_id <> auth.uid()
    and public.v1_permission_exact_role(auth.uid()) <> 'admin' then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if v_claim.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  if exists(select 1 from public.v1_accounts_client_claim_lines
    where claim_id=p_claim_id and nullif(btrim(evidence_reference),'') is null) then
    raise exception 'R39_ACCOUNTS_CLAIM_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  v_before:=public.v1_accounts_claim_snapshot(p_claim_id);
  update public.v1_accounts_client_claims set status='ready_for_accounts',record_version=record_version+1,
    ready_for_accounts_at=v_now,ready_for_accounts_by_auth_user_id=auth.uid(),updated_at=v_now where id=p_claim_id;
  perform public.v1_write_audit_event('accounts.client_claim.ready_for_accounts','accounts_client_claim',p_claim_id,p_project_id,v_before,public.v1_accounts_claim_snapshot(p_claim_id),btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_claim_id,'claim_id',p_claim_id,'record_version',p_expected_version+1,'status','ready_for_accounts','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_submit_client_claim_to_accounts',p_idempotency_key,v_response); return v_response;
end;
$$;

create or replace function public.v1_cancel_client_claim(
  p_project_id uuid,p_claim_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_claim public.v1_accounts_client_claims%rowtype; v_cap text; v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  if public.v1_current_user_has_capability('manage_client_invoices',p_project_id) then v_cap:='manage_client_invoices'; else v_cap:='prepare_client_claim'; end if;
  perform public.v1_accounts_require_capability(p_project_id,v_cap);
  if nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_id',p_claim_id,'expected_version',p_expected_version,'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim('v1_cancel_client_claim',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_claim from public.v1_accounts_client_claims where id=p_claim_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002'; end if;
  if v_claim.status='cancelled' or exists(select 1 from public.v1_accounts_client_invoices i where i.claim_id=p_claim_id and i.status<>'cancelled') then
    raise exception 'R39_ACCOUNTS_CLAIM_NOT_CANCELLABLE' using errcode='55000'; end if;
  if v_claim.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  v_before:=public.v1_accounts_claim_snapshot(p_claim_id);
  update public.v1_accounts_client_claims set status='cancelled',record_version=record_version+1,
    cancelled_at=v_now,cancelled_by_auth_user_id=auth.uid(),cancellation_reason=btrim(p_reason),updated_at=v_now where id=p_claim_id;
  perform public.v1_write_audit_event('accounts.client_claim.cancelled','accounts_client_claim',p_claim_id,p_project_id,v_before,public.v1_accounts_claim_snapshot(p_claim_id),btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_claim_id,'claim_id',p_claim_id,'record_version',p_expected_version+1,'status','cancelled','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_cancel_client_claim',p_idempotency_key,v_response); return v_response;
end;
$$;

create or replace function public.v1_create_client_invoice_draft(
  p_project_id uuid,p_claim_id uuid,p_invoice_reference text,p_notes text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid(); v_role text:=public.v1_current_role(); v_exact text;
  v_claim public.v1_accounts_client_claims%rowtype; v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_claimed numeric; v_vat numeric; v_total numeric; v_invoice_id uuid:=gen_random_uuid();
  v_payload jsonb; v_existing jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  if p_invoice_reference is null or btrim(p_invoice_reference)='' then
    raise exception 'R39_ACCOUNTS_INVOICE_REFERENCE_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'claim_id',p_claim_id,
    'invoice_reference',btrim(p_invoice_reference),'notes',nullif(btrim(p_notes),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_create_client_invoice_draft',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_claim from public.v1_accounts_client_claims where id=p_claim_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002'; end if;
  if v_claim.status<>'ready_for_accounts' or v_claim.is_stale then
    raise exception 'R39_ACCOUNTS_CLAIM_NOT_INVOICEABLE' using errcode='55000'; end if;
  if exists(select 1 from public.v1_accounts_client_invoices where claim_id=p_claim_id) then
    raise exception 'R39_ACCOUNTS_CLAIM_ALREADY_INVOICED' using errcode='23505'; end if;
  select * into v_baseline from public.v1_accounts_baseline_revisions where id=v_claim.baseline_revision_id;
  select sum(claimed_amount) into v_claimed from public.v1_accounts_client_claim_lines where claim_id=p_claim_id;
  v_vat:=round(v_claimed*v_baseline.vat_rate_percent/100,2); v_total:=v_claimed+v_vat;
  insert into public.v1_accounts_client_invoices(id,project_id,claim_id,invoice_reference,
    claimed_ex_vat,vat_rate_percent_snapshot,vat_amount_snapshot,total_incl_vat_snapshot,
    payment_terms_days_snapshot,reminder_lead_days_snapshot,admin_exception_reason,notes,
    created_by_auth_user_id,
    created_by_role,created_by_exact_role,idempotency_key,created_at,updated_at)
  values(v_invoice_id,p_project_id,p_claim_id,btrim(p_invoice_reference),v_claimed,
    v_baseline.vat_rate_percent,v_vat,v_total,v_baseline.payment_terms_days,
    v_baseline.reminder_lead_days,v_claim.admin_exception_reason,
    nullif(btrim(p_notes),''),v_actor,v_role,v_exact,p_idempotency_key,v_now,v_now);
  perform public.v1_write_audit_event('accounts.client_invoice.draft_created','accounts_client_invoice',v_invoice_id,p_project_id,null,public.v1_accounts_invoice_snapshot(v_invoice_id),null,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_invoice_id,'invoice_id',v_invoice_id,'claim_id',p_claim_id,'record_version',1,'status','draft','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_create_client_invoice_draft',p_idempotency_key,v_response); return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_INVOICE_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_update_client_invoice_draft(
  p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_invoice_reference text,p_notes text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_invoice public.v1_accounts_client_invoices%rowtype; v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  perform public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  if nullif(btrim(p_invoice_reference),'') is null then raise exception 'R39_ACCOUNTS_INVOICE_REFERENCE_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,'invoice_reference',btrim(p_invoice_reference),'notes',nullif(btrim(p_notes),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_update_client_invoice_draft',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002'; end if;
  if v_invoice.status not in ('draft','returned') then raise exception 'R39_ACCOUNTS_INVOICE_NOT_EDITABLE' using errcode='55000'; end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  update public.v1_accounts_client_invoices set invoice_reference=btrim(p_invoice_reference),notes=nullif(btrim(p_notes),''),
    record_version=record_version+1,updated_at=v_now,returned_at=null,returned_by_auth_user_id=null,return_reason=null,status='draft' where id=p_invoice_id;
  perform public.v1_write_audit_event('accounts.client_invoice.draft_updated','accounts_client_invoice',p_invoice_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),null,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_invoice_id,'invoice_id',p_invoice_id,'record_version',p_expected_version+1,'status','draft','updated_at',v_now);
  perform public.v1_complete_idempotency('v1_update_client_invoice_draft',p_idempotency_key,v_response); return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_INVOICE_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_submit_client_invoice(
  p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_submission_date date,p_admin_exception_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_invoice public.v1_accounts_client_invoices%rowtype; v_claim public.v1_accounts_client_claims%rowtype;
  v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp(); v_due date;
begin
  perform public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  if p_submission_date is null then raise exception 'R39_ACCOUNTS_SUBMISSION_DATE_REQUIRED' using errcode='22023'; end if;
  if nullif(btrim(p_admin_exception_reason),'') is not null then
    raise exception 'R39_ACCOUNTS_ADMIN_EXCEPTION_SERVER_DERIVED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,'submission_date',p_submission_date,'admin_exception_reason',nullif(btrim(p_admin_exception_reason),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_submit_client_invoice',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002'; end if;
  if v_invoice.status<>'draft' then raise exception 'R39_ACCOUNTS_INVOICE_NOT_SUBMITTABLE' using errcode='55000'; end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  select * into v_claim from public.v1_accounts_client_claims where id=v_invoice.claim_id for update;
  if v_claim.is_stale or v_claim.status<>'ready_for_accounts' then raise exception 'R39_ACCOUNTS_CLAIM_NOT_INVOICEABLE' using errcode='55000'; end if;
  if exists(select 1 from public.v1_accounts_client_claim_lines where claim_id=v_claim.id and nullif(btrim(evidence_reference),'') is null) then
    raise exception 'R39_ACCOUNTS_CLAIM_EVIDENCE_REQUIRED' using errcode='23514'; end if;
  v_due:=p_submission_date+v_invoice.payment_terms_days_snapshot; v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  update public.v1_accounts_client_invoices set status='submitted',submission_date=p_submission_date,due_date=v_due,
    submitted_at=v_now,submitted_by_auth_user_id=auth.uid(),
    record_version=record_version+1,updated_at=v_now where id=p_invoice_id;
  update public.v1_accounts_client_claims set status='invoiced',record_version=record_version+1,updated_at=v_now where id=v_claim.id;
  perform public.v1_write_audit_event('accounts.client_invoice.submitted','accounts_client_invoice',p_invoice_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),v_invoice.admin_exception_reason,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_invoice_id,'invoice_id',p_invoice_id,'claim_id',v_claim.id,'record_version',p_expected_version+1,'status','submitted','submission_date',p_submission_date,'due_date',v_due,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_submit_client_invoice',p_idempotency_key,v_response); return v_response;
end;
$$;

create or replace function public.v1_accounts_transition_invoice(
  p_command text,p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_target text,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_invoice public.v1_accounts_client_invoices%rowtype; v_payload jsonb; v_existing jsonb; v_before jsonb; v_response jsonb; v_now timestamptz:=clock_timestamp();
begin
  perform public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  if nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023'; end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,'target_status',p_target,'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim(p_command,p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true); end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002'; end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001'; end if;
  if p_target='under_certification' and v_invoice.status<>'submitted' then raise exception 'R39_ACCOUNTS_INVALID_INVOICE_TRANSITION' using errcode='55000'; end if;
  if p_target='returned' and v_invoice.status not in ('submitted','under_certification') then raise exception 'R39_ACCOUNTS_INVALID_INVOICE_TRANSITION' using errcode='55000'; end if;
  if p_target='cancelled' then
    if v_invoice.status in ('cancelled','paid') or exists(select 1 from public.v1_accounts_client_certifications where invoice_id=p_invoice_id)
      or exists(select 1 from public.v1_accounts_client_payments where invoice_id=p_invoice_id)
      or exists(select 1 from public.v1_accounts_client_pdcs where invoice_id=p_invoice_id) then
      raise exception 'R39_ACCOUNTS_INVOICE_HAS_DOWNSTREAM_FACTS' using errcode='55000'; end if;
  end if;
  v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  update public.v1_accounts_client_invoices set status=p_target,record_version=record_version+1,updated_at=v_now,
    returned_at=case when p_target='returned' then v_now else returned_at end,
    returned_by_auth_user_id=case when p_target='returned' then auth.uid() else returned_by_auth_user_id end,
    return_reason=case when p_target='returned' then btrim(p_reason) else return_reason end,
    cancelled_at=case when p_target='cancelled' then v_now else cancelled_at end,
    cancelled_by_auth_user_id=case when p_target='cancelled' then auth.uid() else cancelled_by_auth_user_id end,
    cancellation_reason=case when p_target='cancelled' then btrim(p_reason) else cancellation_reason end where id=p_invoice_id;
  if p_target='cancelled' then
    update public.v1_accounts_client_claims set status='cancelled',record_version=record_version+1,cancelled_at=v_now,
      cancelled_by_auth_user_id=auth.uid(),cancellation_reason=btrim(p_reason),updated_at=v_now where id=v_invoice.claim_id;
  end if;
  perform public.v1_write_audit_event('accounts.client_invoice.'||p_target,'accounts_client_invoice',p_invoice_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_invoice_id,'invoice_id',p_invoice_id,'record_version',p_expected_version+1,'status',p_target,'updated_at',v_now);
  perform public.v1_complete_idempotency(p_command,p_idempotency_key,v_response); return v_response;
end;
$$;

create or replace function public.v1_mark_client_invoice_under_certification(p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid)
returns jsonb language sql security definer set search_path='' as $$ select public.v1_accounts_transition_invoice('v1_mark_client_invoice_under_certification',$1,$2,$3,'under_certification',$4,$5); $$;
create or replace function public.v1_return_client_invoice(p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid)
returns jsonb language sql security definer set search_path='' as $$ select public.v1_accounts_transition_invoice('v1_return_client_invoice',$1,$2,$3,'returned',$4,$5); $$;
create or replace function public.v1_cancel_client_invoice(p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid)
returns jsonb language sql security definer set search_path='' as $$ select public.v1_accounts_transition_invoice('v1_cancel_client_invoice',$1,$2,$3,'cancelled',$4,$5); $$;

create or replace function public.v1_record_client_certification(
  p_project_id uuid,p_invoice_id uuid,p_expected_version integer,
  p_certification_reference text,p_certification_date date,p_certified_ex_vat text,
  p_difference_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;
  v_invoice public.v1_accounts_client_invoices%rowtype;v_amount numeric;v_previous numeric;
  v_vat numeric;v_total numeric;v_revision integer;v_cert_id uuid:=gen_random_uuid();
  v_payload jsonb;v_existing jsonb;v_before jsonb;v_response jsonb;v_status text;v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'record_client_certification');
  if nullif(btrim(p_certification_reference),'') is null or p_certification_date is null then
    raise exception 'R39_ACCOUNTS_CERTIFICATION_IDENTITY_REQUIRED' using errcode='22023';end if;
  v_amount:=public.v1_accounts_parse_money_text(p_certified_ex_vat);
  if v_amount<0 then raise exception 'R39_ACCOUNTS_INVALID_CERTIFICATION_AMOUNT' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,
    'certification_reference',btrim(p_certification_reference),'certification_date',p_certification_date,
    'certified_ex_vat',v_amount::text,'difference_reason',nullif(btrim(p_difference_reason),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_record_client_certification',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  if v_invoice.status in ('draft','returned','cancelled') then raise exception 'R39_ACCOUNTS_INVOICE_NOT_CERTIFIABLE' using errcode='55000';end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  v_previous:=public.v1_accounts_invoice_certified_ex_vat(p_invoice_id);
  if v_amount<v_previous or v_amount>v_invoice.claimed_ex_vat then raise exception 'R39_ACCOUNTS_CERTIFICATION_CAP_INVALID' using errcode='23514';end if;
  if v_amount<>v_invoice.claimed_ex_vat and nullif(btrim(p_difference_reason),'') is null then
    raise exception 'R39_ACCOUNTS_CERTIFICATION_DIFFERENCE_REASON_REQUIRED' using errcode='22023';end if;
  select coalesce(max(revision_number),0)+1 into v_revision from public.v1_accounts_client_certifications where invoice_id=p_invoice_id;
  v_vat:=round(v_amount*v_invoice.vat_rate_percent_snapshot/100,2);v_total:=v_amount+v_vat;
  v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  insert into public.v1_accounts_client_certifications(id,project_id,invoice_id,revision_number,certification_reference,
    certification_date,certified_ex_vat,certified_vat,certified_incl_vat,difference_reason,
    actor_auth_user_id,actor_role,actor_exact_role,idempotency_key,created_at)
  values(v_cert_id,p_project_id,p_invoice_id,v_revision,btrim(p_certification_reference),p_certification_date,
    v_amount,v_vat,v_total,nullif(btrim(p_difference_reason),''),v_actor,v_role,v_exact,p_idempotency_key,v_now);
  update public.v1_accounts_client_invoices set record_version=record_version+1,updated_at=v_now where id=p_invoice_id;
  v_status:=public.v1_accounts_refresh_invoice_status(p_invoice_id);
  perform public.v1_write_audit_event('accounts.client_certification.recorded','accounts_client_certification',v_cert_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),nullif(btrim(p_difference_reason),''),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_cert_id,
    'certification_id',v_cert_id,'invoice_id',p_invoice_id,'revision_number',v_revision,
    'invoice_record_version',p_expected_version+1,'status',v_status,'certified_ex_vat',v_amount::text,'certified_incl_vat',v_total::text,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_record_client_certification',p_idempotency_key,v_response);return v_response;
end;
$$;

create or replace function public.v1_record_client_payment(
  p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_payment_date date,
  p_payment_method text,p_payment_reference text,p_amount text,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;
  v_invoice public.v1_accounts_client_invoices%rowtype;v_amount numeric;v_certified numeric;v_paid numeric;
  v_payment_id uuid:=gen_random_uuid();v_payload jsonb;v_existing jsonb;v_before jsonb;v_response jsonb;v_status text;v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'record_client_payment');
  if p_payment_date is null or nullif(btrim(p_payment_method),'') is null or nullif(btrim(p_payment_reference),'') is null then
    raise exception 'R39_ACCOUNTS_PAYMENT_IDENTITY_REQUIRED' using errcode='22023';end if;
  v_amount:=public.v1_accounts_parse_money_text(p_amount);if v_amount<=0 then raise exception 'R39_ACCOUNTS_INVALID_PAYMENT_AMOUNT' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,
    'payment_date',p_payment_date,'payment_method',btrim(p_payment_method),'payment_reference',btrim(p_payment_reference),
    'amount',v_amount::text,'reason',nullif(btrim(p_reason),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_record_client_payment',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  if v_invoice.status in ('draft','returned','cancelled') then raise exception 'R39_ACCOUNTS_INVOICE_NOT_PAYABLE' using errcode='55000';end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  v_certified:=public.v1_accounts_invoice_certified_incl_vat(p_invoice_id);v_paid:=public.v1_accounts_invoice_paid_amount(p_invoice_id);
  if v_certified<=0 or v_paid+v_amount>v_certified then raise exception 'R39_ACCOUNTS_PAYMENT_CAP_EXCEEDED' using errcode='23514';end if;
  v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  insert into public.v1_accounts_client_payments(id,project_id,invoice_id,entry_kind,payment_date,payment_method,payment_reference,amount,reason,
    actor_auth_user_id,actor_role,actor_exact_role,idempotency_key,created_at)
  values(v_payment_id,p_project_id,p_invoice_id,'receipt',p_payment_date,btrim(p_payment_method),btrim(p_payment_reference),v_amount,
    nullif(btrim(p_reason),''),v_actor,v_role,v_exact,p_idempotency_key,v_now);
  update public.v1_accounts_client_invoices set record_version=record_version+1,updated_at=v_now where id=p_invoice_id;
  v_status:=public.v1_accounts_refresh_invoice_status(p_invoice_id);
  perform public.v1_write_audit_event('accounts.client_payment.recorded','accounts_client_payment',v_payment_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),nullif(btrim(p_reason),''),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_payment_id,'payment_id',v_payment_id,
    'invoice_id',p_invoice_id,'invoice_record_version',p_expected_version+1,'status',v_status,'amount',v_amount::text,
    'amount_paid_till_date',(v_paid+v_amount)::text,'still_due',(v_certified-v_paid-v_amount)::text,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_record_client_payment',p_idempotency_key,v_response);return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_PAYMENT_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_reverse_client_payment(
  p_project_id uuid,p_invoice_id uuid,p_expected_version integer,p_original_payment_id uuid,
  p_reversal_date date,p_reversal_reference text,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;
  v_invoice public.v1_accounts_client_invoices%rowtype;v_original public.v1_accounts_client_payments%rowtype;
  v_payment_id uuid:=gen_random_uuid();v_payload jsonb;v_existing jsonb;v_before jsonb;v_response jsonb;v_status text;v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'record_client_payment');
  if p_reversal_date is null or nullif(btrim(p_reversal_reference),'') is null or nullif(btrim(p_reason),'') is null then
    raise exception 'R39_ACCOUNTS_PAYMENT_REVERSAL_FIELDS_REQUIRED' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_version',p_expected_version,
    'original_payment_id',p_original_payment_id,'reversal_date',p_reversal_date,'reversal_reference',btrim(p_reversal_reference),'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim('v1_reverse_client_payment',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  if v_invoice.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  select * into v_original from public.v1_accounts_client_payments where id=p_original_payment_id and project_id=p_project_id and invoice_id=p_invoice_id and entry_kind='receipt' for update;
  if not found or exists(select 1 from public.v1_accounts_client_payments where original_payment_id=p_original_payment_id) then
    raise exception 'R39_ACCOUNTS_PAYMENT_NOT_REVERSIBLE' using errcode='55000';end if;
  v_before:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  insert into public.v1_accounts_client_payments(id,project_id,invoice_id,entry_kind,original_payment_id,payment_date,payment_method,payment_reference,amount,reason,
    actor_auth_user_id,actor_role,actor_exact_role,idempotency_key,created_at)
  values(v_payment_id,p_project_id,p_invoice_id,'reversal',p_original_payment_id,p_reversal_date,'reversal',btrim(p_reversal_reference),v_original.amount,btrim(p_reason),v_actor,v_role,v_exact,p_idempotency_key,v_now);
  update public.v1_accounts_client_invoices set record_version=record_version+1,updated_at=v_now where id=p_invoice_id;
  v_status:=public.v1_accounts_refresh_invoice_status(p_invoice_id);
  perform public.v1_write_audit_event('accounts.client_payment.reversed','accounts_client_payment',v_payment_id,p_project_id,v_before,public.v1_accounts_invoice_snapshot(p_invoice_id),btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_payment_id,'payment_id',v_payment_id,'original_payment_id',p_original_payment_id,
    'invoice_id',p_invoice_id,'invoice_record_version',p_expected_version+1,'status',v_status,'amount',v_original.amount::text,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_reverse_client_payment',p_idempotency_key,v_response);return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_PAYMENT_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_accounts_append_pdc_event(
  p_pdc_id uuid,p_from_status text,p_to_status text,p_action_date date,
  p_reason text,p_linked_payment_id uuid,p_idempotency_key uuid
)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_pdc public.v1_accounts_client_pdcs%rowtype;v_id uuid:=gen_random_uuid();v_sequence integer;
begin
  select * into v_pdc from public.v1_accounts_client_pdcs where id=p_pdc_id;
  if not found then raise exception 'R39_ACCOUNTS_PDC_NOT_FOUND' using errcode='P0002';end if;
  select coalesce(max(sequence_number),0)+1 into v_sequence from public.v1_accounts_client_pdc_events where pdc_id=p_pdc_id;
  insert into public.v1_accounts_client_pdc_events(id,project_id,invoice_id,pdc_id,sequence_number,from_status,to_status,action_date,reason,linked_payment_id,
    actor_auth_user_id,actor_role,actor_exact_role,idempotency_key)
  values(v_id,v_pdc.project_id,v_pdc.invoice_id,p_pdc_id,v_sequence,p_from_status,p_to_status,p_action_date,nullif(btrim(p_reason),''),p_linked_payment_id,
    auth.uid(),public.v1_current_role(),public.v1_permission_exact_role(auth.uid()),p_idempotency_key);
  return v_id;
end;
$$;

create or replace function public.v1_create_client_pdc(
  p_project_id uuid,p_invoice_id uuid,p_expected_invoice_version integer,p_cheque_number text,
  p_cheque_date date,p_amount text,p_bank_name text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;
  v_invoice public.v1_accounts_client_invoices%rowtype;v_amount numeric;v_certified numeric;v_paid numeric;v_exposure numeric;
  v_pdc_id uuid:=gen_random_uuid();v_event_id uuid;v_payload jsonb;v_existing jsonb;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'manage_pdc');
  if nullif(btrim(p_cheque_number),'') is null or p_cheque_date is null then raise exception 'R39_ACCOUNTS_PDC_IDENTITY_REQUIRED' using errcode='22023';end if;
  v_amount:=public.v1_accounts_parse_money_text(p_amount);if v_amount<=0 then raise exception 'R39_ACCOUNTS_INVALID_PDC_AMOUNT' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'invoice_id',p_invoice_id,'expected_invoice_version',p_expected_invoice_version,
    'cheque_number',btrim(p_cheque_number),'cheque_date',p_cheque_date,'amount',v_amount::text,'bank_name',nullif(btrim(p_bank_name),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_create_client_pdc',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  if v_invoice.status in ('draft','returned','cancelled','paid') then raise exception 'R39_ACCOUNTS_INVOICE_NOT_PDC_ELIGIBLE' using errcode='55000';end if;
  if v_invoice.record_version<>p_expected_invoice_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  v_certified:=public.v1_accounts_invoice_certified_incl_vat(p_invoice_id);v_paid:=public.v1_accounts_invoice_paid_amount(p_invoice_id);v_exposure:=public.v1_accounts_invoice_pdc_exposure(p_invoice_id);
  if v_certified<=0 or v_amount>greatest(v_certified-v_paid-v_exposure,0) then raise exception 'R39_ACCOUNTS_PDC_EXPOSURE_CAP_EXCEEDED' using errcode='23514';end if;
  insert into public.v1_accounts_client_pdcs(id,project_id,invoice_id,cheque_number,cheque_date,amount,bank_name,
    created_by_auth_user_id,created_by_role,created_by_exact_role,idempotency_key,created_at,updated_at)
  values(v_pdc_id,p_project_id,p_invoice_id,btrim(p_cheque_number),p_cheque_date,v_amount,nullif(btrim(p_bank_name),''),v_actor,v_role,v_exact,p_idempotency_key,v_now,v_now);
  v_event_id:=public.v1_accounts_append_pdc_event(v_pdc_id,null,'expected',p_cheque_date,null,null,p_idempotency_key);
  update public.v1_accounts_client_invoices set record_version=record_version+1,updated_at=v_now where id=p_invoice_id;
  perform public.v1_write_audit_event('accounts.client_pdc.created','accounts_client_pdc',v_pdc_id,p_project_id,null,jsonb_build_object('pdc_id',v_pdc_id,'invoice_id',p_invoice_id,'status','expected','amount',v_amount::text,'event_id',v_event_id),null,p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_pdc_id,'pdc_id',v_pdc_id,'invoice_id',p_invoice_id,
    'record_version',1,'invoice_record_version',p_expected_invoice_version+1,'status','expected','amount',v_amount::text,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_create_client_pdc',p_idempotency_key,v_response);return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_PDC_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_transition_client_pdc(
  p_project_id uuid,p_pdc_id uuid,p_expected_version integer,p_new_status text,
  p_action_date date,p_reason text,p_clearance_payment_reference text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;
  v_pdc public.v1_accounts_client_pdcs%rowtype;v_invoice public.v1_accounts_client_invoices%rowtype;
  v_payment_id uuid;v_event_id uuid;v_allowed boolean:=false;v_payload jsonb;v_existing jsonb;v_response jsonb;v_now timestamptz:=clock_timestamp();v_status text;
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'manage_pdc');
  if p_action_date is null or p_new_status not in ('received','deposited','cleared','returned','bounced','cancelled') then
    raise exception 'R39_ACCOUNTS_INVALID_PDC_TRANSITION' using errcode='22023';end if;
  if p_new_status in ('returned','bounced','cancelled') and nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode='22023';end if;
  if p_new_status='cleared' and nullif(btrim(p_clearance_payment_reference),'') is null then raise exception 'R39_ACCOUNTS_CLEARANCE_REFERENCE_REQUIRED' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'pdc_id',p_pdc_id,'expected_version',p_expected_version,'new_status',p_new_status,
    'action_date',p_action_date,'reason',nullif(btrim(p_reason),''),'clearance_payment_reference',nullif(btrim(p_clearance_payment_reference),''));
  v_existing:=public.v1_idempotency_get_or_claim('v1_transition_client_pdc',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_pdc from public.v1_accounts_client_pdcs where id=p_pdc_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_PDC_NOT_FOUND' using errcode='P0002';end if;
  if v_pdc.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  v_allowed:=case v_pdc.status when 'expected' then p_new_status in ('received','cancelled')
    when 'received' then p_new_status in ('deposited','returned','bounced','cancelled')
    when 'deposited' then p_new_status in ('cleared','returned','bounced') else false end;
  if not v_allowed then raise exception 'R39_ACCOUNTS_INVALID_PDC_TRANSITION' using errcode='55000';end if;
  select * into v_invoice from public.v1_accounts_client_invoices where id=v_pdc.invoice_id for update;
  if p_new_status='cleared' then
    if not public.v1_current_user_has_capability('record_client_payment',p_project_id) then raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';end if;
    if public.v1_accounts_invoice_paid_amount(v_invoice.id)+v_pdc.amount>public.v1_accounts_invoice_certified_incl_vat(v_invoice.id) then
      raise exception 'R39_ACCOUNTS_PAYMENT_CAP_EXCEEDED' using errcode='23514';end if;
    v_payment_id:=gen_random_uuid();
    insert into public.v1_accounts_client_payments(id,project_id,invoice_id,entry_kind,pdc_id,payment_date,payment_method,payment_reference,amount,reason,
      actor_auth_user_id,actor_role,actor_exact_role,idempotency_key,created_at)
    values(v_payment_id,p_project_id,v_invoice.id,'receipt',p_pdc_id,p_action_date,'PDC',btrim(p_clearance_payment_reference),v_pdc.amount,
      coalesce(nullif(btrim(p_reason),''),'PDC cleared'),v_actor,v_role,v_exact,p_idempotency_key,v_now);
    update public.v1_accounts_client_invoices set record_version=record_version+1,updated_at=v_now where id=v_invoice.id;
    v_status:=public.v1_accounts_refresh_invoice_status(v_invoice.id);
  else v_status:=v_invoice.status;end if;
  update public.v1_accounts_client_pdcs set status=p_new_status,record_version=record_version+1,updated_at=v_now,
    received_date=case when p_new_status='received' then p_action_date else received_date end,
    action_required=p_new_status in ('returned','bounced'),last_action_reason=case when p_new_status in ('returned','bounced') then btrim(p_reason) else null end where id=p_pdc_id;
  v_event_id:=public.v1_accounts_append_pdc_event(p_pdc_id,v_pdc.status,p_new_status,p_action_date,p_reason,v_payment_id,p_idempotency_key);
  perform public.v1_write_audit_event('accounts.client_pdc.'||p_new_status,'accounts_client_pdc',p_pdc_id,p_project_id,
    jsonb_build_object('status',v_pdc.status,'record_version',v_pdc.record_version),jsonb_build_object('status',p_new_status,'record_version',p_expected_version+1,'event_id',v_event_id,'linked_payment_id',v_payment_id),nullif(btrim(p_reason),''),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',p_pdc_id,'pdc_id',p_pdc_id,'invoice_id',v_invoice.id,
    'record_version',p_expected_version+1,'status',p_new_status,'linked_payment_id',v_payment_id,'invoice_status',v_status,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_transition_client_pdc',p_idempotency_key,v_response);return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_PAYMENT_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_replace_client_pdc(
  p_project_id uuid,p_pdc_id uuid,p_expected_version integer,p_new_cheque_number text,
  p_new_cheque_date date,p_new_amount text,p_new_bank_name text,p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_actor uuid:=auth.uid();v_role text:=public.v1_current_role();v_exact text;v_old public.v1_accounts_client_pdcs%rowtype;
  v_amount numeric;v_new_id uuid:=gen_random_uuid();v_payload jsonb;v_existing jsonb;v_response jsonb;v_now timestamptz:=clock_timestamp();
begin
  v_exact:=public.v1_accounts_require_capability(p_project_id,'manage_pdc');
  if nullif(btrim(p_new_cheque_number),'') is null or p_new_cheque_date is null or nullif(btrim(p_reason),'') is null then raise exception 'R39_ACCOUNTS_PDC_REPLACEMENT_FIELDS_REQUIRED' using errcode='22023';end if;
  v_amount:=public.v1_accounts_parse_money_text(p_new_amount);if v_amount<=0 then raise exception 'R39_ACCOUNTS_INVALID_PDC_AMOUNT' using errcode='22023';end if;
  v_payload:=jsonb_build_object('project_id',p_project_id,'pdc_id',p_pdc_id,'expected_version',p_expected_version,'new_cheque_number',btrim(p_new_cheque_number),
    'new_cheque_date',p_new_cheque_date,'new_amount',v_amount::text,'new_bank_name',nullif(btrim(p_new_bank_name),''),'reason',btrim(p_reason));
  v_existing:=public.v1_idempotency_get_or_claim('v1_replace_client_pdc',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing||jsonb_build_object('replayed',true);end if;
  select * into v_old from public.v1_accounts_client_pdcs where id=p_pdc_id and project_id=p_project_id for update;
  if not found then raise exception 'R39_ACCOUNTS_PDC_NOT_FOUND' using errcode='P0002';end if;
  if v_old.record_version<>p_expected_version then raise exception 'R39_ACCOUNTS_VERSION_CONFLICT' using errcode='40001';end if;
  if v_old.status not in ('received','deposited','returned','bounced') then raise exception 'R39_ACCOUNTS_PDC_NOT_REPLACEABLE' using errcode='55000';end if;
  if v_amount>greatest(public.v1_accounts_invoice_certified_incl_vat(v_old.invoice_id)-public.v1_accounts_invoice_paid_amount(v_old.invoice_id)
      -public.v1_accounts_invoice_pdc_exposure(v_old.invoice_id)+case when v_old.status in ('received','deposited') then v_old.amount else 0 end,0) then
    raise exception 'R39_ACCOUNTS_PDC_EXPOSURE_CAP_EXCEEDED' using errcode='23514';end if;
  insert into public.v1_accounts_client_pdcs(id,project_id,invoice_id,cheque_number,cheque_date,amount,bank_name,replaces_pdc_id,
    created_by_auth_user_id,created_by_role,created_by_exact_role,idempotency_key,created_at,updated_at)
  values(v_new_id,p_project_id,v_old.invoice_id,btrim(p_new_cheque_number),p_new_cheque_date,v_amount,nullif(btrim(p_new_bank_name),''),p_pdc_id,
    v_actor,v_role,v_exact,p_idempotency_key,v_now,v_now);
  update public.v1_accounts_client_pdcs set status='replaced',replaced_by_pdc_id=v_new_id,action_required=false,last_action_reason=null,
    record_version=record_version+1,updated_at=v_now where id=p_pdc_id;
  perform public.v1_accounts_append_pdc_event(p_pdc_id,v_old.status,'replaced',p_new_cheque_date,p_reason,null,p_idempotency_key);
  perform public.v1_accounts_append_pdc_event(v_new_id,null,'expected',p_new_cheque_date,p_reason,null,p_idempotency_key);
  perform public.v1_write_audit_event('accounts.client_pdc.replaced','accounts_client_pdc',p_pdc_id,p_project_id,
    jsonb_build_object('status',v_old.status,'record_version',v_old.record_version),jsonb_build_object('status','replaced','record_version',p_expected_version+1,'replaced_by_pdc_id',v_new_id),btrim(p_reason),p_idempotency_key);
  v_response:=jsonb_build_object('schema_version',3,'replayed',false,'project_id',p_project_id,'entity_id',v_new_id,'pdc_id',v_new_id,'replaced_pdc_id',p_pdc_id,
    'record_version',1,'replaced_record_version',p_expected_version+1,'status','expected','amount',v_amount::text,'updated_at',v_now);
  perform public.v1_complete_idempotency('v1_replace_client_pdc',p_idempotency_key,v_response);return v_response;
exception when unique_violation then raise exception 'R39_ACCOUNTS_DUPLICATE_PDC_REFERENCE' using errcode='23505';
end;
$$;

create or replace function public.v1_accounts_invoice_due_state(
  p_status text,p_due_date date,p_reminder_lead_days integer
)
returns text language sql stable security definer set search_path=''
as $$
  select case when p_status in ('draft','returned','cancelled','paid') or p_due_date is null then null
    when p_due_date < current_date then 'overdue'
    when p_due_date = current_date then 'due_today'
    when p_due_date <= current_date + p_reminder_lead_days then 'due_soon'
    else 'on_track' end;
$$;

create or replace function public.v1_get_client_claim(p_project_id uuid,p_claim_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_result jsonb;
begin
  if not (public.v1_current_user_has_capability('prepare_client_claim',p_project_id)
    and public.v1_current_user_has_capability('view_project_commercial_values',p_project_id))
    and not public.v1_current_user_has_capability('manage_client_invoices',p_project_id) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';end if;
  v_result:=public.v1_accounts_claim_snapshot(p_claim_id);
  if v_result is null or (v_result->>'project_id')::uuid<>p_project_id then raise exception 'R39_ACCOUNTS_CLAIM_NOT_FOUND' using errcode='P0002';end if;
  return jsonb_build_object('schema_version',3,'project_id',p_project_id,'claim',v_result,
    'capabilities',public.v1_accounts_receivables_capabilities(p_project_id),
    'commands',public.v1_accounts_receivables_commands(p_project_id));
end;
$$;

create or replace function public.v1_list_client_claims(
  p_project_id uuid,p_status text default null,p_before_updated_at timestamptz default null,
  p_before_id uuid default null,p_limit integer default 50
)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_rows jsonb;v_next_time timestamptz;v_next_id uuid;v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
begin
  if p_status is not null and p_status not in ('draft','ready_for_accounts','invoiced','cancelled') then raise exception 'R39_ACCOUNTS_INVALID_CLAIM_STATUS' using errcode='22023';end if;
  if not (public.v1_current_user_has_capability('prepare_client_claim',p_project_id)
    and public.v1_current_user_has_capability('view_project_commercial_values',p_project_id))
    and not public.v1_current_user_has_capability('manage_client_invoices',p_project_id) then raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';end if;
  with page as (select claim.*,(select coalesce(sum(line.claimed_amount),0) from public.v1_accounts_client_claim_lines line where line.claim_id=claim.id) claimed
    from public.v1_accounts_client_claims claim where claim.project_id=p_project_id and (p_status is null or claim.status=p_status)
      and (p_before_updated_at is null or (claim.updated_at,claim.id)<(p_before_updated_at,coalesce(p_before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
    order by claim.updated_at desc,claim.id desc limit v_limit)
  select coalesce(jsonb_agg(jsonb_build_object('claim_id',id,'claim_reference',claim_reference,'claim_period_start',claim_period_start,
      'claim_period_end',claim_period_end,'status',status,'claimed_ex_vat',claimed::text,'is_stale',is_stale,'record_version',record_version,
      'created_by_auth_user_id',created_by_auth_user_id,'created_by_exact_role',created_by_exact_role,'created_at',created_at,'updated_at',updated_at)
      order by updated_at desc,id desc),'[]'::jsonb),min(updated_at),
      (array_agg(id order by updated_at asc,id asc))[1] into v_rows,v_next_time,v_next_id from page;
  return jsonb_build_object('schema_version',3,'project_id',p_project_id,'claims',v_rows,
    'next_cursor',case when jsonb_array_length(v_rows)=v_limit then jsonb_build_object('before_updated_at',v_next_time,'before_id',v_next_id) else null end,
    'capabilities',public.v1_accounts_receivables_capabilities(p_project_id),
    'commands',public.v1_accounts_receivables_commands(p_project_id));
end;
$$;

create or replace function public.v1_get_client_invoice(p_project_id uuid,p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_invoice jsonb;v_certifications jsonb;v_payments jsonb;v_pdcs jsonb;
begin
  perform public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  v_invoice:=public.v1_accounts_invoice_snapshot(p_invoice_id);
  if v_invoice is null or (v_invoice->>'project_id')::uuid<>p_project_id then raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  select coalesce(jsonb_agg(jsonb_build_object('certification_id',id,'revision_number',revision_number,'certification_reference',certification_reference,
    'certification_date',certification_date,'certified_ex_vat',certified_ex_vat::text,'certified_vat',certified_vat::text,'certified_incl_vat',certified_incl_vat::text,
    'difference_reason',difference_reason,'actor_auth_user_id',actor_auth_user_id,'actor_exact_role',actor_exact_role,'created_at',created_at) order by revision_number),'[]'::jsonb)
    into v_certifications from public.v1_accounts_client_certifications where invoice_id=p_invoice_id;
  select coalesce(jsonb_agg(jsonb_build_object('payment_id',id,'entry_kind',entry_kind,'original_payment_id',original_payment_id,'pdc_id',pdc_id,
    'payment_date',payment_date,'payment_method',payment_method,'payment_reference',payment_reference,'amount',amount::text,'reason',reason,
    'actor_auth_user_id',actor_auth_user_id,'actor_exact_role',actor_exact_role,'created_at',created_at) order by created_at,id),'[]'::jsonb)
    into v_payments from public.v1_accounts_client_payments where invoice_id=p_invoice_id;
  select coalesce(jsonb_agg(jsonb_build_object('pdc_id',id,'cheque_number',cheque_number,'cheque_date',cheque_date,'amount',amount::text,
    'bank_name',bank_name,'received_date',received_date,'status',status,'replaces_pdc_id',replaces_pdc_id,'replaced_by_pdc_id',replaced_by_pdc_id,
    'action_required',action_required,'last_action_reason',last_action_reason,'record_version',record_version,'created_at',created_at,'updated_at',updated_at)
    order by created_at,id),'[]'::jsonb) into v_pdcs from public.v1_accounts_client_pdcs where invoice_id=p_invoice_id;
  return jsonb_build_object('schema_version',3,'project_id',p_project_id,'invoice',v_invoice,
    'claim',public.v1_accounts_claim_snapshot((v_invoice->>'claim_id')::uuid),'certifications',v_certifications,'payments',v_payments,'pdcs',v_pdcs,
    'due_state',public.v1_accounts_invoice_due_state(v_invoice->>'status',(v_invoice->>'due_date')::date,(v_invoice->>'reminder_lead_days_snapshot')::integer),
    'capabilities',public.v1_accounts_receivables_capabilities(p_project_id),
    'commands',public.v1_accounts_receivables_commands(p_project_id));
end;
$$;

create or replace function public.v1_list_client_invoices(
  p_project_id uuid,p_status text default null,p_due_state text default null,
  p_before_updated_at timestamptz default null,p_before_id uuid default null,p_limit integer default 50
)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_rows jsonb;v_next_time timestamptz;v_next_id uuid;v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
begin
  perform public.v1_accounts_require_capability(p_project_id,'manage_client_invoices');
  if p_status is not null and p_status not in ('draft','submitted','under_certification','partially_certified','certified','partially_paid','paid','returned','cancelled') then raise exception 'R39_ACCOUNTS_INVALID_INVOICE_STATUS' using errcode='22023';end if;
  if p_due_state is not null and p_due_state not in ('on_track','due_soon','due_today','overdue') then raise exception 'R39_ACCOUNTS_INVALID_DUE_STATE' using errcode='22023';end if;
  with derived as (select invoice.*,public.v1_accounts_invoice_certified_ex_vat(invoice.id) certified_ex,
      public.v1_accounts_invoice_certified_incl_vat(invoice.id) certified_total,public.v1_accounts_invoice_paid_amount(invoice.id) paid,
      public.v1_accounts_invoice_pdc_exposure(invoice.id) exposure,
      public.v1_accounts_invoice_due_state(invoice.status,invoice.due_date,invoice.reminder_lead_days_snapshot) due_state
    from public.v1_accounts_client_invoices invoice where invoice.project_id=p_project_id),
  page as (select * from derived where (p_status is null or status=p_status) and (p_due_state is null or due_state=p_due_state)
    and (p_before_updated_at is null or (updated_at,id)<(p_before_updated_at,coalesce(p_before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid)))
    order by updated_at desc,id desc limit v_limit)
  select coalesce(jsonb_agg(jsonb_build_object('invoice_id',id,'claim_id',claim_id,'invoice_reference',invoice_reference,'status',status,
    'claimed_ex_vat',claimed_ex_vat::text,'certified_ex_vat',certified_ex::text,'total_incl_vat',total_incl_vat_snapshot::text,
    'amount_paid_till_date',paid::text,'still_due',greatest(certified_total-paid,0)::text,'pdc_exposure',exposure::text,
    'submission_date',submission_date,'due_date',due_date,'due_state',due_state,'record_version',record_version,'updated_at',updated_at)
    order by updated_at desc,id desc),'[]'::jsonb),min(updated_at),(array_agg(id order by updated_at asc,id asc))[1]
  into v_rows,v_next_time,v_next_id from page;
  return jsonb_build_object('schema_version',3,'project_id',p_project_id,'invoices',v_rows,
    'next_cursor',case when jsonb_array_length(v_rows)=v_limit then jsonb_build_object('before_updated_at',v_next_time,'before_id',v_next_id) else null end,
    'capabilities',public.v1_accounts_receivables_capabilities(p_project_id),
    'commands',public.v1_accounts_receivables_commands(p_project_id));
end;
$$;

create or replace function public.v1_list_client_receipts_pdc(
  p_project_id uuid,p_invoice_id uuid default null,p_before_occurred_at timestamptz default null,
  p_before_id uuid default null,p_limit integer default 50
)
returns jsonb language plpgsql stable security definer set search_path=''
as $$
declare v_rows jsonb;v_next_time timestamptz;v_next_id uuid;v_limit integer:=least(greatest(coalesce(p_limit,50),1),100);
begin
  if not (public.v1_current_user_has_capability('record_client_payment',p_project_id) or public.v1_current_user_has_capability('manage_pdc',p_project_id)) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';end if;
  if p_invoice_id is not null and not exists(select 1 from public.v1_accounts_client_invoices where id=p_invoice_id and project_id=p_project_id) then
    raise exception 'R39_ACCOUNTS_INVOICE_NOT_FOUND' using errcode='P0002';end if;
  with ledger as (
    select payment.id,payment.created_at occurred_at,'payment'::text entry_type,payment.invoice_id,
      jsonb_build_object('payment_id',payment.id,'entry_kind',payment.entry_kind,'payment_date',payment.payment_date,
        'payment_method',payment.payment_method,'payment_reference',payment.payment_reference,'amount',payment.amount::text,
        'original_payment_id',payment.original_payment_id,'pdc_id',payment.pdc_id,'actor_auth_user_id',payment.actor_auth_user_id,'actor_exact_role',payment.actor_exact_role) data
    from public.v1_accounts_client_payments payment where payment.project_id=p_project_id and (p_invoice_id is null or payment.invoice_id=p_invoice_id)
    union all
    select event.id,event.occurred_at,'pdc_event',event.invoice_id,jsonb_build_object('pdc_event_id',event.id,'pdc_id',event.pdc_id,
      'sequence_number',event.sequence_number,'from_status',event.from_status,'to_status',event.to_status,'action_date',event.action_date,
      'reason',event.reason,'linked_payment_id',event.linked_payment_id,'actor_auth_user_id',event.actor_auth_user_id,'actor_exact_role',event.actor_exact_role)
    from public.v1_accounts_client_pdc_events event where event.project_id=p_project_id and (p_invoice_id is null or event.invoice_id=p_invoice_id)),
  page as (select * from ledger where p_before_occurred_at is null or (occurred_at,id)<(p_before_occurred_at,coalesce(p_before_id,'ffffffff-ffff-ffff-ffff-ffffffffffff'::uuid))
    order by occurred_at desc,id desc limit v_limit)
  select coalesce(jsonb_agg(jsonb_build_object('ledger_entry_id',id,'occurred_at',occurred_at,'entry_type',entry_type,'invoice_id',invoice_id,'data',data)
    order by occurred_at desc,id desc),'[]'::jsonb),min(occurred_at),(array_agg(id order by occurred_at asc,id asc))[1]
    into v_rows,v_next_time,v_next_id from page;
  return jsonb_build_object('schema_version',3,'project_id',p_project_id,'invoice_id',p_invoice_id,'entries',v_rows,
    'next_cursor',case when jsonb_array_length(v_rows)=v_limit then jsonb_build_object('before_occurred_at',v_next_time,'before_id',v_next_id) else null end,
    'capabilities',public.v1_accounts_receivables_capabilities(p_project_id),
    'commands',public.v1_accounts_receivables_commands(p_project_id));
end;
$$;

-- Preserve the complete, previously tested T02 command and add the T03
-- claim-basis diagnostic before delegating. Completed idempotent retries are
-- delegated immediately, so a lost-response retry never depends on later
-- mutable claim state.
alter function public.v1_confirm_billing_progress(
  uuid,uuid,integer,text,text,uuid[],text,uuid
) rename to v1_confirm_billing_progress_t02_internal;

create or replace function public.v1_confirm_billing_progress(
  p_project_id uuid,p_progress_entry_id uuid,p_expected_version integer,
  p_confirmed_percent text,p_evidence_summary text,p_evidence_document_ids uuid[],
  p_reason text,p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_percent numeric;v_payload jsonb;v_existing public.v1_idempotency_keys%rowtype;
  v_stage_value numeric;v_consumed numeric;v_refs jsonb;
begin
  perform public.v1_accounts_require_capability(p_project_id,'confirm_billing_progress');
  v_percent:=public.v1_accounts_parse_percent_text(p_confirmed_percent);
  v_payload:=jsonb_build_object('project_id',p_project_id,'progress_entry_id',p_progress_entry_id,
    'expected_version',p_expected_version,'confirmed_percent',v_percent::text,
    'evidence_summary',nullif(btrim(p_evidence_summary),''),
    'evidence_document_ids',to_jsonb(public.v1_accounts_canonical_evidence_ids(p_evidence_document_ids)),
    'reason',nullif(btrim(p_reason),''));
  select * into v_existing from public.v1_idempotency_keys key_record
  where key_record.actor_auth_user_id=auth.uid() and key_record.command_name='v1_confirm_billing_progress'
    and key_record.idempotency_key=p_idempotency_key;
  if found and v_existing.response_json is not null then
    return public.v1_confirm_billing_progress_t02_internal(p_project_id,p_progress_entry_id,p_expected_version,
      p_confirmed_percent,p_evidence_summary,p_evidence_document_ids,p_reason,p_idempotency_key);
  end if;
  if not exists(select 1 from public.v1_accounts_billing_progress where id=p_progress_entry_id and project_id=p_project_id) then
    raise exception 'R39_ACCOUNTS_PROGRESS_NOT_FOUND' using errcode='P0002';end if;
  v_stage_value:=public.v1_accounts_stage_value(p_progress_entry_id);
  v_consumed:=public.v1_accounts_consumed_claim_amount(p_progress_entry_id);
  if round(v_stage_value*v_percent/100,2)<round(v_consumed,2) then
    select coalesce(jsonb_agg(jsonb_build_object('claim_id',claim.id,'claim_reference',claim.claim_reference,'status',claim.status)
      order by claim.claim_reference,claim.id),'[]'::jsonb) into v_refs
    from public.v1_accounts_client_claim_lines line join public.v1_accounts_client_claims claim on claim.id=line.claim_id
    where line.progress_entry_id=p_progress_entry_id and claim.project_id=p_project_id and claim.status<>'cancelled';
    raise exception 'R39_ACCOUNTS_CONFIRMED_BELOW_CLAIMED_BASIS'
      using errcode='23514',detail=jsonb_build_object('blocking_claims',v_refs,'consumed_claim_amount',v_consumed::text)::text;
  end if;
  return public.v1_confirm_billing_progress_t02_internal(p_project_id,p_progress_entry_id,p_expected_version,
    p_confirmed_percent,p_evidence_summary,p_evidence_document_ids,p_reason,p_idempotency_key);
end;
$$;

-- Internal helpers and trigger functions are never Data API surfaces.
revoke all on function public.v1_accounts_validate_claim_line_row() from public,anon,authenticated;
revoke all on function public.v1_accounts_validate_receivable_child_row() from public,anon,authenticated;
revoke all on function public.v1_accounts_append_only_guard() from public,anon,authenticated;
revoke all on function public.v1_accounts_consumed_claim_amount(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_mark_claim_drafts_stale(uuid,uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_certified_ex_vat(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_certified_incl_vat(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_paid_amount(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_pdc_exposure(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_refresh_invoice_status(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_receivables_capabilities(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_receivables_commands(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_validate_claim_lines(uuid,uuid,jsonb,uuid,boolean) from public,anon,authenticated;
revoke all on function public.v1_accounts_normalize_claim_input_lines(jsonb) from public,anon,authenticated;
revoke all on function public.v1_accounts_replace_claim_lines(uuid,uuid,uuid,jsonb) from public,anon,authenticated;
revoke all on function public.v1_accounts_claim_snapshot(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_snapshot(uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_transition_invoice(text,uuid,uuid,integer,text,text,uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_append_pdc_event(uuid,text,text,date,text,uuid,uuid) from public,anon,authenticated;
revoke all on function public.v1_accounts_invoice_due_state(text,date,integer) from public,anon,authenticated;
revoke all on function public.v1_confirm_billing_progress_t02_internal(uuid,uuid,integer,text,text,uuid[],text,uuid) from public,anon,authenticated;

-- T03 authenticated RPC surface.
revoke all on function public.v1_create_client_claim_draft(uuid,text,date,date,jsonb,text,uuid,text) from public,anon;
revoke all on function public.v1_update_client_claim_draft(uuid,uuid,integer,text,date,date,jsonb,text,uuid,text) from public,anon;
revoke all on function public.v1_delete_client_claim_draft(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_submit_client_claim_to_accounts(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_cancel_client_claim(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_create_client_invoice_draft(uuid,uuid,text,text,uuid) from public,anon;
revoke all on function public.v1_update_client_invoice_draft(uuid,uuid,integer,text,text,uuid) from public,anon;
revoke all on function public.v1_submit_client_invoice(uuid,uuid,integer,date,text,uuid) from public,anon;
revoke all on function public.v1_mark_client_invoice_under_certification(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_return_client_invoice(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_cancel_client_invoice(uuid,uuid,integer,text,uuid) from public,anon;
revoke all on function public.v1_record_client_certification(uuid,uuid,integer,text,date,text,text,uuid) from public,anon;
revoke all on function public.v1_record_client_payment(uuid,uuid,integer,date,text,text,text,text,uuid) from public,anon;
revoke all on function public.v1_reverse_client_payment(uuid,uuid,integer,uuid,date,text,text,uuid) from public,anon;
revoke all on function public.v1_create_client_pdc(uuid,uuid,integer,text,date,text,text,uuid) from public,anon;
revoke all on function public.v1_transition_client_pdc(uuid,uuid,integer,text,date,text,text,uuid) from public,anon;
revoke all on function public.v1_replace_client_pdc(uuid,uuid,integer,text,date,text,text,text,uuid) from public,anon;
revoke all on function public.v1_get_client_claim(uuid,uuid) from public,anon;
revoke all on function public.v1_list_client_claims(uuid,text,timestamptz,uuid,integer) from public,anon;
revoke all on function public.v1_get_client_invoice(uuid,uuid) from public,anon;
revoke all on function public.v1_list_client_invoices(uuid,text,text,timestamptz,uuid,integer) from public,anon;
revoke all on function public.v1_list_client_receipts_pdc(uuid,uuid,timestamptz,uuid,integer) from public,anon;
revoke all on function public.v1_confirm_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid) from public,anon;

grant execute on function public.v1_create_client_claim_draft(uuid,text,date,date,jsonb,text,uuid,text) to authenticated,service_role;
grant execute on function public.v1_update_client_claim_draft(uuid,uuid,integer,text,date,date,jsonb,text,uuid,text) to authenticated,service_role;
grant execute on function public.v1_delete_client_claim_draft(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_submit_client_claim_to_accounts(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_cancel_client_claim(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_create_client_invoice_draft(uuid,uuid,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_update_client_invoice_draft(uuid,uuid,integer,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_submit_client_invoice(uuid,uuid,integer,date,text,uuid) to authenticated,service_role;
grant execute on function public.v1_mark_client_invoice_under_certification(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_return_client_invoice(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_cancel_client_invoice(uuid,uuid,integer,text,uuid) to authenticated,service_role;
grant execute on function public.v1_record_client_certification(uuid,uuid,integer,text,date,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_record_client_payment(uuid,uuid,integer,date,text,text,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_reverse_client_payment(uuid,uuid,integer,uuid,date,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_create_client_pdc(uuid,uuid,integer,text,date,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_transition_client_pdc(uuid,uuid,integer,text,date,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_replace_client_pdc(uuid,uuid,integer,text,date,text,text,text,uuid) to authenticated,service_role;
grant execute on function public.v1_get_client_claim(uuid,uuid) to authenticated,service_role;
grant execute on function public.v1_list_client_claims(uuid,text,timestamptz,uuid,integer) to authenticated,service_role;
grant execute on function public.v1_get_client_invoice(uuid,uuid) to authenticated,service_role;
grant execute on function public.v1_list_client_invoices(uuid,text,text,timestamptz,uuid,integer) to authenticated,service_role;
grant execute on function public.v1_list_client_receipts_pdc(uuid,uuid,timestamptz,uuid,integer) to authenticated,service_role;
grant execute on function public.v1_confirm_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid) to authenticated,service_role;

commit;
