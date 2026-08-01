-- Batch 2 / PR-02: isolate commercial values from shared operational JSON.

create or replace function public.app_has_cap(p_cap text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select public.app_role() = 'admin'
      or coalesce((auth.jwt() -> 'app_metadata' -> 'caps') ? p_cap, false)
      or (
        p_cap = 'viewCommercials'
        and coalesce(
          (auth.jwt() -> 'app_metadata' -> 'caps') ? 'cost',
          false
        )
      );
$$;

create table public.commercial_records (
  subject_type text not null
    check (subject_type in ('material', 'goods_receipt', 'project')),
  subject_id text not null check (btrim(subject_id) <> ''),
  unit_cost_aed numeric(18, 4) check (unit_cost_aed >= 0),
  total_cost_aed numeric(18, 2) check (total_cost_aed >= 0),
  currency_code text not null default 'AED'
    check (currency_code ~ '^[A-Z]{3}$'),
  updated_at timestamptz not null default now(),
  updated_by_app_user_id text,
  primary key (subject_type, subject_id),
  check (unit_cost_aed is not null or total_cost_aed is not null)
);

comment on table public.commercial_records is
  'RLS-protected commercial values separated from shared operational documents.';
comment on column public.commercial_records.updated_by_app_user_id is
  'Stable Yorks AppUser id from app_metadata.app_user_id; nullable for migrated rows.';

create index commercial_records_updated_at_idx
  on public.commercial_records (updated_at desc);

alter table public.commercial_records enable row level security;

revoke all on table public.commercial_records from anon;
revoke all on table public.commercial_records from authenticated;
grant select, insert, update on table public.commercial_records
  to authenticated;
grant all on table public.commercial_records to service_role;

create policy commercial_records_select
on public.commercial_records
for select
to authenticated
using (public.app_has_cap('viewCommercials'));

create policy commercial_records_insert
on public.commercial_records
for insert
to authenticated
with check (
  public.app_has_cap('viewCommercials')
  and (public.app_role() = 'admin' or public.app_has_cap('goods'))
);

create policy commercial_records_update
on public.commercial_records
for update
to authenticated
using (
  public.app_has_cap('viewCommercials')
  and (public.app_role() = 'admin' or public.app_has_cap('goods'))
)
with check (
  public.app_has_cap('viewCommercials')
  and (public.app_role() = 'admin' or public.app_has_cap('goods'))
);

create or replace function public.app_touch_commercial_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger commercial_records_touch
before insert or update on public.commercial_records
for each row execute function public.app_touch_commercial_updated_at();

create or replace function public.app_strip_commercial_jsonb(p_value jsonb)
returns jsonb
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if jsonb_typeof(p_value) = 'object' then
    select coalesce(
      jsonb_object_agg(
        entry.key,
        public.app_strip_commercial_jsonb(entry.value)
      ),
      '{}'::jsonb
    )
    into v_result
    from jsonb_each(p_value) as entry
    where entry.key <> all (array[
      'unitPrice',
      'unitCost',
      'unitCostAED',
      'unit_cost',
      'unit_cost_aed',
      'totalCost',
      'totalCostAED',
      'total_cost',
      'total_cost_aed',
      'contractValueAED'
    ]::text[]);
    return v_result;
  end if;

  if jsonb_typeof(p_value) = 'array' then
    select coalesce(
      jsonb_agg(
        public.app_strip_commercial_jsonb(entry.value)
        order by entry.ordinal
      ),
      '[]'::jsonb
    )
    into v_result
    from jsonb_array_elements(p_value) with ordinality
      as entry(value, ordinal);
    return v_result;
  end if;

  return p_value;
end;
$$;

create or replace function public.app_enforce_cost_free_payload()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.data := public.app_strip_commercial_jsonb(new.data);
  return new;
end;
$$;

-- Move existing top-level values into the protected relation before scrubbing.
insert into public.commercial_records (
  subject_type,
  subject_id,
  unit_cost_aed,
  total_cost_aed,
  currency_code,
  updated_at
)
select
  'material',
  id,
  (data ->> 'unitPrice')::numeric,
  null,
  'AED',
  updated_at
from public.materials
where jsonb_typeof(data -> 'unitPrice') = 'number'
  and (data ->> 'unitPrice')::numeric >= 0
on conflict (subject_type, subject_id) do update
set unit_cost_aed = excluded.unit_cost_aed,
    currency_code = excluded.currency_code,
    updated_at = greatest(
      public.commercial_records.updated_at,
      excluded.updated_at
    );

insert into public.commercial_records (
  subject_type,
  subject_id,
  unit_cost_aed,
  total_cost_aed,
  currency_code,
  updated_at
)
select
  'project',
  id,
  null,
  (data ->> 'contractValueAED')::numeric,
  'AED',
  updated_at
from public.projects
where jsonb_typeof(data -> 'contractValueAED') = 'number'
  and (data ->> 'contractValueAED')::numeric >= 0
on conflict (subject_type, subject_id) do update
set total_cost_aed = excluded.total_cost_aed,
    currency_code = excluded.currency_code,
    updated_at = greatest(
      public.commercial_records.updated_at,
      excluded.updated_at
    );

insert into public.commercial_records (
  subject_type,
  subject_id,
  unit_cost_aed,
  total_cost_aed,
  currency_code,
  updated_at
)
select
  'goods_receipt',
  id,
  (data ->> 'unitCostAED')::numeric,
  case
    when jsonb_typeof(data -> 'quantity') = 'number'
      then (data ->> 'unitCostAED')::numeric
         * (data ->> 'quantity')::numeric
    else null
  end,
  'AED',
  updated_at
from public."goodsReceipts"
where jsonb_typeof(data -> 'unitCostAED') = 'number'
  and (data ->> 'unitCostAED')::numeric >= 0
on conflict (subject_type, subject_id) do update
set unit_cost_aed = excluded.unit_cost_aed,
    total_cost_aed = excluded.total_cost_aed,
    currency_code = excluded.currency_code,
    updated_at = greatest(
      public.commercial_records.updated_at,
      excluded.updated_at
    );

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'materials',
    'projects',
    'goodsReceipts',
    'materialRequests',
    'materialPlans'
  ]
  loop
    execute format(
      'update public.%I set data = public.app_strip_commercial_jsonb(data) where data is distinct from public.app_strip_commercial_jsonb(data)',
      table_name
    );
    execute format(
      'create trigger %I before insert or update of data on public.%I for each row execute function public.app_enforce_cost_free_payload()',
      table_name || '_cost_free_payload',
      table_name
    );
  end loop;
end;
$$;

revoke all on function public.app_strip_commercial_jsonb(jsonb)
  from public, anon, authenticated;
revoke all on function public.app_enforce_cost_free_payload()
  from public, anon, authenticated;
revoke all on function public.app_touch_commercial_updated_at()
  from public, anon, authenticated;
