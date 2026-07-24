-- Batch 6 / PR-06: Admin-managed material categories and units.
-- Explicit grants are included because newly created tables are not assumed to
-- be exposed to PostgREST automatically.

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

create table if not exists public."materialCategories" (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public."materialUnits" (
  id text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create index if not exists material_categories_data_gin
  on public."materialCategories" using gin (data);
create index if not exists material_units_data_gin
  on public."materialUnits" using gin (data);

drop trigger if exists material_categories_touch
  on public."materialCategories";
create trigger material_categories_touch
before insert or update on public."materialCategories"
for each row execute function public.app_touch_updated_at();

drop trigger if exists material_units_touch on public."materialUnits";
create trigger material_units_touch
before insert or update on public."materialUnits"
for each row execute function public.app_touch_updated_at();

alter table public."materialCategories" enable row level security;
alter table public."materialUnits" enable row level security;

grant select, insert, update on table public."materialCategories"
  to authenticated;
grant select, insert, update on table public."materialUnits"
  to authenticated;
grant all on table public."materialCategories" to service_role;
grant all on table public."materialUnits" to service_role;

create policy material_categories_read
on public."materialCategories" for select
using (public.app_user_id() <> '');

create policy material_categories_admin_insert
on public."materialCategories" for insert
with check (public.app_role() = 'admin');

create policy material_categories_admin_update
on public."materialCategories" for update
using (public.app_role() = 'admin')
with check (public.app_role() = 'admin');

create policy material_units_read
on public."materialUnits" for select
using (public.app_user_id() <> '');

-- Procurement can propose a unit, but cannot approve/archive it. The payload
-- must be custom and pendingReview; Admin can create approved defaults.
create policy material_units_insert
on public."materialUnits" for insert
with check (
  public.app_role() = 'admin'
  or (
    public.app_role() = 'procurement'
    and coalesce((data->>'isCustom')::boolean, false)
    and data->>'status' = 'pendingReview'
  )
);

create policy material_units_admin_update
on public."materialUnits" for update
using (public.app_role() = 'admin')
with check (public.app_role() = 'admin');

create policy material_units_procurement_pending_update
on public."materialUnits" for update
using (
  public.app_role() = 'procurement'
  and coalesce((data->>'isCustom')::boolean, false)
  and data->>'status' = 'pendingReview'
)
with check (
  public.app_role() = 'procurement'
  and coalesce((data->>'isCustom')::boolean, false)
  and data->>'status' = 'pendingReview'
);

alter table public."materialCategories" replica identity full;
alter table public."materialUnits" replica identity full;
