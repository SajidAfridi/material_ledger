-- =====================================================================

-- LEGACY — NOT CURRENT PRODUCT AUTHORITY.
-- This generic JSONB schema is retained for migration evidence only. Current
-- Yorks V1 schema and workflow authority lives in supabase/migrations/ and
-- docs/yorks-v1/.

-- V7 note: after this baseline, apply every tracked file in
-- `supabase/migrations/` in timestamp order. Batch 8's normalized Phase 1
-- tables and workflow/activation triggers intentionally live in migrations,
-- not in this legacy generic-collection baseline.
-- Yorks GodownPro — Supabase / Postgres schema (self-hosted, UAE region)
-- Phase 1 backend behind the existing sync seam.
--
-- Model: each app "collection" is a table <collection> with
--   id          text  primary key   -- the client-generated MutationOp.docId
--   data        jsonb not null        -- the document snapshot (toJson payload)
--   updated_at  timestamptz           -- set by the app on every upsert
-- Writes are idempotent UPSERTs on id (a resend overwrites the same row), which
-- matches the outbox's exactly-once promise. Payloads are ABSOLUTE snapshots
-- (not deltas), so re-applying is always safe.
--
-- Reporting uses generated columns + views that read from `data` — the
-- relational payoff (rent-roll / overdue / leave-balance as SQL, not N+1 Dart).
--
-- RUN ORDER: this file is idempotent-ish; run it once on a fresh DB. Review the
-- RLS section before production. RLS REQUIRES Phase 2 (Auth + role/caps claims):
-- until signed-in users carry an app_metadata.role (+ caps), authenticated
-- writes are denied by design — keep SUPABASE_URL unset in the app until then,
-- and do the one-time data import below with the service_role key server-side.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- updated_at touch trigger (defensive — the app also sets it)
-- ---------------------------------------------------------------------
create or replace function app_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------------
-- Helper: create a collection table with the standard shape + trigger.
-- ---------------------------------------------------------------------
create or replace function app_make_collection(p_name text)
returns void language plpgsql as $$
begin
  execute format($f$
    create table if not exists %I (
      id          text primary key,
      data        jsonb not null,
      updated_at  timestamptz not null default now()
    );
  $f$, p_name);
  execute format('create index if not exists %I on %I using gin (data);',
                 p_name || '_data_gin', p_name);
  execute format('drop trigger if exists %I on %I;',
                 p_name || '_touch', p_name);
  execute format($f$
    create trigger %I before insert or update on %I
    for each row execute function app_touch_updated_at();
  $f$, p_name || '_touch', p_name);
end $$;

-- Core synced collections (matches MutationOp.collection values in the app).
select app_make_collection(c) from (values
  ('materialRequests'),
  ('materialCategories'),
  ('materialUnits'),
  ('goodsReceipts'),
  ('returns'),
  ('rentalUnits'),
  ('rentPayments'),
  ('employees'),
  ('attendance'),
  ('leaveRecords'),
  ('config')
) as t(c);

-- ---------------------------------------------------------------------
-- Reporting columns + views (the relational advantage of choosing Postgres)
-- Generated columns are computed by Postgres from `data` — the app keeps
-- upserting {id, data}; nothing app-side changes.
-- ---------------------------------------------------------------------

-- Rental units: extract rent + occupancy for the rent roll.
alter table rentalUnits
  add column if not exists monthly_rent numeric
    generated always as ((data->>'monthlyRentAED')::numeric) stored,
  add column if not exists status text
    generated always as (data->>'status') stored;

-- Rent payments: extract period/amounts/void for collected + overdue.
alter table rentPayments
  add column if not exists unit_id text
    generated always as (data->>'unitId') stored,
  add column if not exists period_month text
    generated always as (data->>'periodMonth') stored,
  add column if not exists amount_due numeric
    generated always as ((data->>'amountDueAED')::numeric) stored,
  add column if not exists amount_paid numeric
    generated always as (coalesce((data->>'amountPaidAED')::numeric, 0)) stored,
  -- kept as text (a ::timestamptz cast is not IMMUTABLE, so a STORED generated
  -- column rejects it); only ever null-checked, so text is sufficient.
  add column if not exists voided_at text
    generated always as (data->>'voidedAt') stored;
create index if not exists rentpayments_unit_period
  on rentPayments (unit_id, period_month);

-- Leave records: extract employee/type/status/days for balances.
alter table leaveRecords
  add column if not exists employee_id text
    generated always as (data->>'employeeId') stored,
  add column if not exists leave_type text
    generated always as (data->>'type') stored,
  add column if not exists leave_status text
    generated always as (data->>'status') stored,
  add column if not exists days int
    generated always as ((data->>'days')::int) stored;
create index if not exists leaverecords_employee on leaveRecords (employee_id);

-- Owner / lookup indexes for the RLS owner-checks + Phase-2 "my …" reads.
create index if not exists materialrequests_engineer
  on materialRequests ((data->>'engineerId'));
create index if not exists leaverecords_owner
  on leaveRecords ((data->>'requestedByUserId'));
create index if not exists attendance_employee
  on attendance ((data->>'employeeId'));
create index if not exists goodsreceipts_receivedby
  on goodsReceipts ((data->>'receivedBy'));

-- Monthly rent roll = sum of rent for occupied units.
create or replace view v_rent_roll as
  select coalesce(sum(monthly_rent), 0) as monthly_rent_roll,
         count(*) filter (where status = 'active') as occupied,
         count(*) filter (where status <> 'active') as vacant
  from rentalUnits
  where status = 'active';

-- Outstanding per (unit, month), excluding voided rows.
create or replace view v_rent_outstanding as
  select unit_id, period_month,
         max(amount_due) as amount_due,
         sum(amount_paid) as amount_paid,
         greatest(max(amount_due) - sum(amount_paid), 0) as outstanding
  from rentPayments
  where voided_at is null
  group by unit_id, period_month;

-- Approved-leave days taken per employee per year (drives remaining balance).
create or replace view v_leave_taken as
  select employee_id,
         left(coalesce(data->>'startDate', ''), 4) as year,
         sum(days) filter (where leave_status = 'approved'
                           and leave_type = 'annual') as annual_days_taken
  from leaveRecords
  group by employee_id, left(coalesce(data->>'startDate', ''), 4);

-- =====================================================================
-- ROW-LEVEL SECURITY  (mirrors the app's role × capability model)
-- Requires Phase 2: signed-in users carry app_metadata.role and
-- app_metadata.caps (a text[] of granted capabilities, computed by the
-- claim-provisioning function using the SAME resolveCapability logic:
-- per-user override → editable role default → built-in baseline).
-- =====================================================================

-- role from the JWT (custom claim lives under app_metadata).
create or replace function app_role()
returns text language sql stable as $$
  select coalesce(
    auth.jwt() -> 'app_metadata' ->> 'role',
    auth.jwt() ->> 'role',
    ''
  );
$$;

-- Stable AppUser id from the JWT. Owner-checks key off THIS, not auth.uid():
-- the app's identity is 'usr-*' (carried in app_metadata.app_user_id), which is
-- what `engineerId` / `requestedByUserId` store — NOT the Supabase auth UUID.
create or replace function app_user_id()
returns text language sql stable as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'app_user_id', '');
$$;

-- capability check: admin has everything; others check their caps[] claim.
-- Valid caps (must match RoleCapability enum names in the app exactly):
--   viewCommercials, salary, finance, rentals, writeRentals, people,
--   writePeople, goods, approveLeave. The legacy `cost` claim remains a
--   temporary read alias. Commercial values are also enforced by the
--   `commercial_records` RLS boundary in the tracked Batch 2 migrations.
create or replace function app_has_cap(p_cap text)
returns boolean language sql stable set search_path to '' as $$
  select public.app_role() = 'admin'
      or coalesce(
        (auth.jwt() -> 'app_metadata' -> 'caps') ? p_cap,
        false
      )
      or (
        p_cap = 'viewCommercials'
        and coalesce(
          (auth.jwt() -> 'app_metadata' -> 'caps') ? 'cost',
          false
        )
      );
$$;

-- The canonical commercial table, migration and recursive operational-payload
-- triggers are tracked in:
--   supabase/migrations/20260724015401_secure_commercial_boundary.sql
--   supabase/migrations/20260724015517_fix_cost_free_trigger_execution.sql
--   supabase/migrations/20260724015856_drop_unused_commercial_updated_at_index.sql

-- Turn RLS on for every collection.
do $$ declare t text;
begin
  foreach t in array array[
    'materialRequests','goodsReceipts','returns','rentalUnits','rentPayments',
    'employees','attendance','leaveRecords','config','notifications',
    'materialCategories','materialUnits'
  ] loop
    execute format('alter table %I enable row level security;', t);
  end loop;
end $$;

-- Rentals: read with 'rentals'; write with 'writeRentals' (matches canWriteRentals).
create policy rentals_read   on rentalUnits for select using (app_has_cap('rentals'));
create policy rentals_write  on rentalUnits for all
  using (app_has_cap('writeRentals')) with check (app_has_cap('writeRentals'));
create policy rentpay_read   on rentPayments for select using (app_has_cap('rentals'));
create policy rentpay_write  on rentPayments for all
  using (app_has_cap('writeRentals')) with check (app_has_cap('writeRentals'));

-- People / HR + attendance: 'people' to read, 'writePeople' to write.
create policy people_read    on employees for select using (app_has_cap('people'));
create policy people_write   on employees for all
  using (app_has_cap('writePeople')) with check (app_has_cap('writePeople'));
create policy attend_read    on attendance for select using (app_has_cap('people'));
create policy attend_write   on attendance for all
  using (app_has_cap('writePeople')) with check (app_has_cap('writePeople'));

-- Leave: an engineer manages their OWN requests; approvers (approveLeave) see/act on all.
create policy leave_owner on leaveRecords for all
  using  (app_has_cap('approveLeave') or data->>'requestedByUserId' = app_user_id())
  with check (app_has_cap('approveLeave') or data->>'requestedByUserId' = app_user_id());

-- Materials flows: engineers create/see their own requests; office (goods cap) sees all.
create policy req_owner on materialRequests for all
  using  (app_has_cap('goods') or data->>'engineerId' = app_user_id())
  with check (app_has_cap('goods') or data->>'engineerId' = app_user_id());
-- `for all` covers SELECT too, so these single policies gate both read + write
-- under 'goods' (no separate read policy needed).
create policy receipts_write on goodsReceipts for all
  using (app_has_cap('goods')) with check (app_has_cap('goods'));
create policy returns_write on returns for all
  using (app_has_cap('goods')) with check (app_has_cap('goods'));

-- Notifications: admin sees all; a personally-targeted notification (userId
-- set) is visible only to that user or admin; a role-audience one (userId
-- empty, audience set) is visible to admin or that role only; a pure
-- broadcast (both empty) is visible to anyone signed in. Mirrors
-- notificationVisibleTo() in notification_provider.dart exactly. IMPORTANT:
-- this MUST be split into separate insert/update policies, not `for all` — a
-- permissive `for all using(true)` policy also grants blanket SELECT
-- (Postgres ORs permissive policies together for the same command), silently
-- defeating this restriction.
--
-- (Earlier version of this policy only checked whether userId was empty and
-- never checked audience, so a role-audience notification was readable by
-- ANY signed-in user regardless of role — verified and fixed live via the
-- `tighten_notifications_rls` migration; this file reflects that fix.)
create or replace function notification_visible_to_caller(p_data jsonb)
returns boolean language sql stable set search_path to '' as $$
  select
    public.app_role() = 'admin'
    or (
      coalesce(p_data->>'userId', '') <> ''
      and p_data->>'userId' = public.app_user_id()
    )
    or (
      coalesce(p_data->>'userId', '') = ''
      and (
        coalesce(p_data->>'audience', '') = ''
        or p_data->>'audience' = public.app_role()
      )
    );
$$;

create policy notifications_read on notifications for select
  using (notification_visible_to_caller(data));
-- INSERT/UPDATE have no sender-identity field to check ownership against (any
-- role legitimately notifies any other role/user, and the upsert-only sync
-- re-applies a sender's write of a row it cannot itself see), so these only
-- require a genuinely provisioned app identity. Writes deliberately do NOT use
-- notification_visible_to_caller — that rejected a sender re-applying a
-- notification addressed to someone else ("new row violates RLS"; fixed live
-- via the `fix_notifications_update_sender_writes` migration). Read visibility
-- is what matters and is gated above. Residual, accepted: a provisioned user
-- could tamper with another user's notification row — low severity, inherent to
-- upsert-only sync with no tracked sender field.
create policy notifications_insert on notifications for insert
  with check (app_user_id() <> '');
create policy notifications_update on notifications for update
  using (app_user_id() <> '')
  with check (app_user_id() <> '');

-- Config (editable role-permission matrix etc.): admin only.
create policy config_admin on config for all
  using (app_role() = 'admin') with check (app_role() = 'admin');

-- =====================================================================
-- ONE-TIME DATA IMPORT (server-side, service_role — never from the app)
-- For each existing local collection, upsert the JSON snapshots:
--   insert into <collection> (id, data)
--   select x->>'id', x from jsonb_array_elements(:payload::jsonb) as x
--   on conflict (id) do update set data = excluded.data, updated_at = now();
-- =====================================================================
