-- Batch 1 prerequisite baseline.
--
-- The production project was originally created from docs/supabase/schema.sql
-- plus manual migrations. The first previously tracked migration therefore
-- assumed these legacy JSON collection tables and JWT helpers already existed.
-- This migration records those prerequisites so a clean local reset can replay
-- the full history. It is deliberately additive and does not create any Yorks
-- V1 normalized workflow tables.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.app_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Authorization claims are accepted only from server-controlled app_metadata.
-- In particular, the top-level JWT `role` is PostgreSQL's API role
-- (`authenticated`) and is never application authority.
create or replace function public.app_role()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '');
$$;

create or replace function public.app_user_id()
returns text
language sql
stable
set search_path = ''
as $$
  select coalesce(
    auth.jwt() -> 'app_metadata' ->> 'app_user_id',
    ''
  );
$$;

-- Legacy V7 capability names remain here until the normalized Yorks V1
-- authorization layer is introduced in Batch 2. The commercial-boundary
-- migration later in this chain replaces this function with the same rules.
create or replace function public.app_has_cap(p_cap text)
returns boolean
language sql
stable
set search_path = ''
as $$
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

revoke all on function public.app_touch_updated_at()
  from public, anon, authenticated;
revoke all on function public.app_role()
  from public, anon, authenticated;
revoke all on function public.app_user_id()
  from public, anon, authenticated;
revoke all on function public.app_has_cap(text)
  from public, anon, authenticated;

grant execute on function public.app_role()
  to authenticated, service_role;
grant execute on function public.app_user_id()
  to authenticated, service_role;
grant execute on function public.app_has_cap(text)
  to authenticated, service_role;

create or replace function public.app_make_legacy_collection(p_name text)
returns void
language plpgsql
set search_path = ''
as $$
declare
  safe_name text := regexp_replace(lower(p_name), '[^a-z0-9]+', '_', 'g');
  index_name text;
  trigger_name text;
begin
  index_name := 'legacy_' || safe_name || '_data_gin';
  trigger_name := 'legacy_' || safe_name || '_touch';

  execute format(
    'create table if not exists public.%I (
       id text primary key,
       data jsonb not null,
       updated_at timestamptz not null default now()
     )',
    p_name
  );
  execute format(
    'create index if not exists %I on public.%I using gin (data)',
    index_name,
    p_name
  );

  -- The later material-master migration owns the trigger names for these two.
  if p_name not in ('materialCategories', 'materialUnits') then
    execute format(
      'drop trigger if exists %I on public.%I',
      trigger_name,
      p_name
    );
    execute format(
      'create trigger %I before insert or update on public.%I
       for each row execute function public.app_touch_updated_at()',
      trigger_name,
      p_name
    );
  end if;

  execute format(
    'alter table public.%I enable row level security',
    p_name
  );
  execute format(
    'alter table public.%I replica identity full',
    p_name
  );
  execute format(
    'revoke all on table public.%I from public, anon, authenticated',
    p_name
  );
  execute format(
    'grant select, insert, update on table public.%I to authenticated',
    p_name
  );
  execute format(
    'grant all on table public.%I to service_role',
    p_name
  );
end;
$$;

select public.app_make_legacy_collection(collection_name)
from (values
  ('projects'),
  ('materialPlans'),
  ('materialRequests'),
  ('materials'),
  ('materialCategories'),
  ('materialUnits'),
  ('stockMovements'),
  ('notifications'),
  ('rentalUnits'),
  ('rentPayments'),
  ('goodsReceipts'),
  ('returns'),
  ('employees'),
  ('attendance'),
  ('leaveRecords'),
  ('config'),
  ('users'),
  ('auditLogs'),
  ('device_tokens')
) as legacy_collections(collection_name);

drop function public.app_make_legacy_collection(text);

-- These two legacy collections are intentionally local-only. A device-token
-- row is visible and mutable only to the app user named in its payload;
-- service_role can enumerate all rows. PostgreSQL UPSERT requires SELECT on the
-- conflicting row as well as INSERT/UPDATE, so owner-scoped SELECT is required
-- by the current Flutter registration path.
revoke all on table public.users from authenticated;
revoke all on table public."auditLogs" from authenticated;
revoke all on table public.device_tokens from authenticated;
grant insert, update, delete on table public.device_tokens to authenticated;
grant select on table public.device_tokens to authenticated;

-- Preserve the existing reporting surface from the manually applied baseline.
alter table public."rentalUnits"
  add column if not exists monthly_rent numeric
    generated always as ((data ->> 'monthlyRentAED')::numeric) stored,
  add column if not exists status text
    generated always as (data ->> 'status') stored;

alter table public."rentPayments"
  add column if not exists unit_id text
    generated always as (data ->> 'unitId') stored,
  add column if not exists period_month text
    generated always as (data ->> 'periodMonth') stored,
  add column if not exists amount_due numeric
    generated always as ((data ->> 'amountDueAED')::numeric) stored,
  add column if not exists amount_paid numeric
    generated always as (
      coalesce((data ->> 'amountPaidAED')::numeric, 0)
    ) stored,
  add column if not exists voided_at text
    generated always as (data ->> 'voidedAt') stored;

alter table public."leaveRecords"
  add column if not exists employee_id text
    generated always as (data ->> 'employeeId') stored,
  add column if not exists leave_type text
    generated always as (data ->> 'type') stored,
  add column if not exists leave_status text
    generated always as (data ->> 'status') stored,
  add column if not exists days integer
    generated always as ((data ->> 'days')::integer) stored;

create index if not exists rent_payments_unit_period_idx
  on public."rentPayments" (unit_id, period_month);
create index if not exists leave_records_employee_idx
  on public."leaveRecords" (employee_id);
create index if not exists material_requests_engineer_idx
  on public."materialRequests" ((data ->> 'engineerId'));
create index if not exists leave_records_owner_idx
  on public."leaveRecords" ((data ->> 'requestedByUserId'));
create index if not exists attendance_employee_idx
  on public.attendance ((data ->> 'employeeId'));
create index if not exists goods_receipts_received_by_idx
  on public."goodsReceipts" ((data ->> 'receivedBy'));

create or replace view public.v_rent_roll
with (security_invoker = true)
as
select
  coalesce(sum(monthly_rent), 0) as monthly_rent_roll,
  count(*) filter (where status = 'active') as occupied,
  count(*) filter (where status <> 'active') as vacant
from public."rentalUnits"
where status = 'active';

create or replace view public.v_rent_outstanding
with (security_invoker = true)
as
select
  unit_id,
  period_month,
  max(amount_due) as amount_due,
  sum(amount_paid) as amount_paid,
  greatest(max(amount_due) - sum(amount_paid), 0) as outstanding
from public."rentPayments"
where voided_at is null
group by unit_id, period_month;

create or replace view public.v_leave_taken
with (security_invoker = true)
as
select
  employee_id,
  left(coalesce(data ->> 'startDate', ''), 4) as year,
  sum(days) filter (
    where leave_status = 'approved' and leave_type = 'annual'
  ) as annual_days_taken
from public."leaveRecords"
group by employee_id, left(coalesce(data ->> 'startDate', ''), 4);

revoke all on table public.v_rent_roll from public, anon;
revoke all on table public.v_rent_outstanding from public, anon;
revoke all on table public.v_leave_taken from public, anon;
grant select on table public.v_rent_roll to authenticated, service_role;
grant select on table public.v_rent_outstanding to authenticated, service_role;
grant select on table public.v_leave_taken to authenticated, service_role;

create or replace function public.app_legacy_project_readable(p_data jsonb)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.app_has_cap('goods')
      or (
        public.app_role() = 'engineer'
        and public.app_user_id() <> ''
        and (
          p_data ->> 'assignedEngineerId' = public.app_user_id()
          or coalesce(
            p_data -> 'designEngineerUserIds',
            '[]'::jsonb
          ) ? public.app_user_id()
          or (
            coalesce(p_data ->> 'assignedEngineerId', '') = ''
            and coalesce(
              p_data -> 'designEngineerUserIds',
              '[]'::jsonb
            ) = '[]'::jsonb
          )
        )
      );
$$;

create or replace function public.app_legacy_project_writable(p_data jsonb)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.app_has_cap('goods')
      or (
        public.app_role() = 'engineer'
        and public.app_user_id() <> ''
        and (
          p_data ->> 'assignedEngineerId' = public.app_user_id()
          or coalesce(
            p_data -> 'designEngineerUserIds',
            '[]'::jsonb
          ) ? public.app_user_id()
        )
      );
$$;

create or replace function public.app_legacy_plan_readable(p_data jsonb)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects project
    where project.id = p_data ->> 'projectId'
      and public.app_legacy_project_readable(project.data)
  );
$$;

create or replace function public.app_legacy_plan_writable(p_data jsonb)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from public.projects project
    where project.id = p_data ->> 'projectId'
      and public.app_legacy_project_writable(project.data)
  );
$$;

create or replace function public.notification_visible_to_caller(p_data jsonb)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.app_role() = 'admin'
      or (
        coalesce(p_data ->> 'userId', '') <> ''
        and p_data ->> 'userId' = public.app_user_id()
      )
      or (
        coalesce(p_data ->> 'userId', '') = ''
        and public.app_user_id() <> ''
        and (
          coalesce(p_data ->> 'audience', '') = ''
          or p_data ->> 'audience' = public.app_role()
        )
      );
$$;

revoke all on function public.app_legacy_project_readable(jsonb)
  from public, anon;
revoke all on function public.app_legacy_project_writable(jsonb)
  from public, anon;
revoke all on function public.app_legacy_plan_readable(jsonb)
  from public, anon;
revoke all on function public.app_legacy_plan_writable(jsonb)
  from public, anon;
revoke all on function public.notification_visible_to_caller(jsonb)
  from public, anon;

grant execute on function public.app_legacy_project_readable(jsonb)
  to authenticated, service_role;
grant execute on function public.app_legacy_project_writable(jsonb)
  to authenticated, service_role;
grant execute on function public.app_legacy_plan_readable(jsonb)
  to authenticated, service_role;
grant execute on function public.app_legacy_plan_writable(jsonb)
  to authenticated, service_role;
grant execute on function public.notification_visible_to_caller(jsonb)
  to authenticated, service_role;

-- Install a policy only when a live database does not already have a policy
-- with that name. This lets the backfilled prerequisite apply without replacing
-- production's already-verified policy definitions.
create or replace function public.app_create_policy_if_missing(
  p_table text,
  p_policy text,
  p_statement text
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = p_table
      and policyname = p_policy
  ) then
    execute p_statement;
  end if;
end;
$$;

select public.app_create_policy_if_missing(
  'materials',
  'materials_read',
  $policy$create policy materials_read on public.materials for select
    to authenticated using (public.app_user_id() <> '')$policy$
);
select public.app_create_policy_if_missing(
  'materials',
  'materials_write',
  $policy$create policy materials_write on public.materials for all
    to authenticated using (public.app_has_cap('goods'))
    with check (public.app_has_cap('goods'))$policy$
);
select public.app_create_policy_if_missing(
  'stockMovements',
  'stock_movements_read',
  $policy$create policy stock_movements_read on public."stockMovements"
    for select to authenticated using (public.app_user_id() <> '')$policy$
);
select public.app_create_policy_if_missing(
  'stockMovements',
  'stock_movements_write',
  $policy$create policy stock_movements_write on public."stockMovements"
    for all to authenticated using (public.app_has_cap('goods'))
    with check (public.app_has_cap('goods'))$policy$
);
select public.app_create_policy_if_missing(
  'projects',
  'projects_read',
  $policy$create policy projects_read on public.projects for select
    to authenticated using (public.app_legacy_project_readable(data))$policy$
);
select public.app_create_policy_if_missing(
  'projects',
  'projects_insert',
  $policy$create policy projects_insert on public.projects for insert
    to authenticated with check (public.app_legacy_project_writable(data))$policy$
);
select public.app_create_policy_if_missing(
  'projects',
  'projects_update',
  $policy$create policy projects_update on public.projects for update
    to authenticated using (public.app_legacy_project_writable(data))
    with check (public.app_legacy_project_writable(data))$policy$
);
select public.app_create_policy_if_missing(
  'materialPlans',
  'material_plans_read',
  $policy$create policy material_plans_read on public."materialPlans" for select
    to authenticated using (public.app_legacy_plan_readable(data))$policy$
);
select public.app_create_policy_if_missing(
  'materialPlans',
  'material_plans_insert',
  $policy$create policy material_plans_insert on public."materialPlans" for insert
    to authenticated with check (public.app_legacy_plan_writable(data))$policy$
);
select public.app_create_policy_if_missing(
  'materialPlans',
  'material_plans_update',
  $policy$create policy material_plans_update on public."materialPlans" for update
    to authenticated using (public.app_legacy_plan_writable(data))
    with check (public.app_legacy_plan_writable(data))$policy$
);
select public.app_create_policy_if_missing(
  'materialRequests',
  'req_owner',
  $policy$create policy req_owner on public."materialRequests" for all
    to authenticated
    using (
      public.app_has_cap('goods')
      or data ->> 'engineerId' = public.app_user_id()
    )
    with check (
      public.app_has_cap('goods')
      or data ->> 'engineerId' = public.app_user_id()
    )$policy$
);
select public.app_create_policy_if_missing(
  'goodsReceipts',
  'receipts_write',
  $policy$create policy receipts_write on public."goodsReceipts" for all
    to authenticated using (public.app_has_cap('goods'))
    with check (public.app_has_cap('goods'))$policy$
);
select public.app_create_policy_if_missing(
  'returns',
  'returns_write',
  $policy$create policy returns_write on public.returns for all
    to authenticated using (public.app_has_cap('goods'))
    with check (public.app_has_cap('goods'))$policy$
);
select public.app_create_policy_if_missing(
  'rentalUnits',
  'rentals_read',
  $policy$create policy rentals_read on public."rentalUnits" for select
    to authenticated using (public.app_has_cap('rentals'))$policy$
);
select public.app_create_policy_if_missing(
  'rentalUnits',
  'rentals_write',
  $policy$create policy rentals_write on public."rentalUnits" for all
    to authenticated using (public.app_has_cap('writeRentals'))
    with check (public.app_has_cap('writeRentals'))$policy$
);
select public.app_create_policy_if_missing(
  'rentPayments',
  'rentpay_read',
  $policy$create policy rentpay_read on public."rentPayments" for select
    to authenticated using (public.app_has_cap('rentals'))$policy$
);
select public.app_create_policy_if_missing(
  'rentPayments',
  'rentpay_write',
  $policy$create policy rentpay_write on public."rentPayments" for all
    to authenticated using (public.app_has_cap('writeRentals'))
    with check (public.app_has_cap('writeRentals'))$policy$
);
select public.app_create_policy_if_missing(
  'employees',
  'people_read',
  $policy$create policy people_read on public.employees for select
    to authenticated using (public.app_has_cap('people'))$policy$
);
select public.app_create_policy_if_missing(
  'employees',
  'people_write',
  $policy$create policy people_write on public.employees for all
    to authenticated using (public.app_has_cap('writePeople'))
    with check (public.app_has_cap('writePeople'))$policy$
);
select public.app_create_policy_if_missing(
  'attendance',
  'attend_read',
  $policy$create policy attend_read on public.attendance for select
    to authenticated using (public.app_has_cap('people'))$policy$
);
select public.app_create_policy_if_missing(
  'attendance',
  'attend_write',
  $policy$create policy attend_write on public.attendance for all
    to authenticated using (public.app_has_cap('writePeople'))
    with check (public.app_has_cap('writePeople'))$policy$
);
select public.app_create_policy_if_missing(
  'leaveRecords',
  'leave_owner',
  $policy$create policy leave_owner on public."leaveRecords" for all
    to authenticated
    using (
      public.app_has_cap('approveLeave')
      or data ->> 'requestedByUserId' = public.app_user_id()
    )
    with check (
      public.app_has_cap('approveLeave')
      or data ->> 'requestedByUserId' = public.app_user_id()
    )$policy$
);
select public.app_create_policy_if_missing(
  'notifications',
  'notifications_read',
  $policy$create policy notifications_read on public.notifications for select
    to authenticated using (public.notification_visible_to_caller(data))$policy$
);
select public.app_create_policy_if_missing(
  'notifications',
  'notifications_insert',
  $policy$create policy notifications_insert on public.notifications for insert
    to authenticated with check (public.app_user_id() <> '')$policy$
);
select public.app_create_policy_if_missing(
  'notifications',
  'notifications_update',
  $policy$create policy notifications_update on public.notifications for update
    to authenticated using (public.app_user_id() <> '')
    with check (public.app_user_id() <> '')$policy$
);
select public.app_create_policy_if_missing(
  'config',
  'config_admin',
  $policy$create policy config_admin on public.config for all
    to authenticated using (public.app_role() = 'admin')
    with check (public.app_role() = 'admin')$policy$
);
select public.app_create_policy_if_missing(
  'device_tokens',
  'device_tokens_select_own',
  $policy$create policy device_tokens_select_own on public.device_tokens
    for select to authenticated
    using (data ->> 'appUserId' = public.app_user_id())$policy$
);
select public.app_create_policy_if_missing(
  'device_tokens',
  'device_tokens_insert',
  $policy$create policy device_tokens_insert on public.device_tokens for insert
    to authenticated
    with check (data ->> 'appUserId' = public.app_user_id())$policy$
);
select public.app_create_policy_if_missing(
  'device_tokens',
  'device_tokens_update',
  $policy$create policy device_tokens_update on public.device_tokens for update
    to authenticated
    using (data ->> 'appUserId' = public.app_user_id())
    with check (data ->> 'appUserId' = public.app_user_id())$policy$
);
select public.app_create_policy_if_missing(
  'device_tokens',
  'device_tokens_delete',
  $policy$create policy device_tokens_delete on public.device_tokens for delete
    to authenticated
    using (data ->> 'appUserId' = public.app_user_id())$policy$
);

drop function public.app_create_policy_if_missing(text, text, text);

-- Every collection subscribed to by the current Flutter realtime adapter is
-- added exactly once. Configuration and private auth/token tables are omitted.
do $$
declare
  table_name text;
begin
  if exists (
    select 1
    from pg_catalog.pg_publication
    where pubname = 'supabase_realtime'
      and not puballtables
  ) then
    foreach table_name in array array[
      'projects',
      'materialPlans',
      'materialRequests',
      'materials',
      'materialCategories',
      'materialUnits',
      'stockMovements',
      'notifications',
      'rentalUnits',
      'rentPayments',
      'goodsReceipts',
      'returns',
      'employees',
      'attendance',
      'leaveRecords'
    ]
    loop
      if not exists (
        select 1
        from pg_catalog.pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = table_name
      ) then
        execute format(
          'alter publication supabase_realtime add table public.%I',
          table_name
        );
      end if;
    end loop;
  end if;
end;
$$;
