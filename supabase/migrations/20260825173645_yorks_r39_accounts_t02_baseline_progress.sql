-- Yorks R39 Accounts T02: protected commercial baseline and Billing Progress.
--
-- This slice activates only the six capability consumers implemented below.
-- Claims, invoices, payments, PDCs, supplier bills, exports and routes remain
-- planned and fail closed. Commercial state is additive, project-scoped and
-- cannot rewrite Projects, BOQ, Material Requests or logistics facts.
--
-- VAT has no approved platform default. Every baseline command therefore
-- requires an explicit, validated VAT-rate snapshot. Payment/reminder defaults
-- and stage templates continue to come from the protected T01 foundation.
--
-- Rollback: disable YORKS_V1_ACCOUNTS/T02 consumers and retain all baseline,
-- progress, revision and audit rows. Never drop or reinterpret committed data.

begin;

-- Cut over only consumers that exist in this migration. Export and all T03+
-- capabilities deliberately remain planned/shadow/nonassignable.
update public.v1_capability_catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true
where capability_key = any(array[
  'view_project_accounts',
  'view_project_commercial_values',
  'suggest_billing_progress',
  'confirm_billing_progress',
  'configure_project_commercials',
  'review_commercial_progress'
]::text[]);

-- Confirm authority is independent from value visibility (FR-059). A Project
-- Engineer may confirm a percentage while the projection still omits money.
update public.v1_capability_catalog
set dependencies = array['view_project_accounts']::text[]
where capability_key = 'confirm_billing_progress';

-- Admin may delegate the tested T02 capabilities without inheriting the
-- separated Site/Project Engineer commands itself.
update public.v1_permission_role_defaults
set can_delegate = true,
    updated_at = clock_timestamp()
where role_name = 'admin'
  and capability_key = any(array[
    'view_project_accounts',
    'view_project_commercial_values',
    'suggest_billing_progress',
    'confirm_billing_progress',
    'configure_project_commercials',
    'review_commercial_progress'
  ]::text[]);

create table public.v1_accounts_project_commercial_profiles (
  project_id uuid primary key
    references public.v1_projects (id) on delete restrict,
  current_baseline_revision_id uuid,
  status text not null default 'active'
    check (status in ('active', 'suspended')),
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
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table public.v1_accounts_baseline_revisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  status text not null check (status in ('current', 'superseded')),
  contract_value numeric(20,2) not null check (
    contract_value::text <> 'NaN' and contract_value > 0
  ),
  currency_code text not null check (currency_code ~ '^[A-Z]{3}$'),
  vat_rate_percent numeric(7,4) not null check (
    vat_rate_percent::text <> 'NaN'
    and vat_rate_percent between 0 and 100
  ),
  payment_terms_days integer not null check (payment_terms_days > 0),
  reminder_lead_days integer not null check (
    reminder_lead_days >= 0 and reminder_lead_days <= payment_terms_days
  ),
  management_review_policy jsonb not null
    check (jsonb_typeof(management_review_policy) = 'object'),
  effective_at timestamptz not null default clock_timestamp(),
  reason text not null check (btrim(reason) <> ''),
  approved_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  approved_by_role text not null check (approved_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'accountant', 'admin'
  )),
  approved_by_exact_role text not null check (approved_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'workshop_in_charge', 'document_controller',
    'procurement', 'accountant', 'admin'
  )),
  idempotency_key uuid not null,
  superseded_at timestamptz,
  superseded_by_revision_id uuid
    references public.v1_accounts_baseline_revisions (id) on delete restrict
    deferrable initially deferred,
  created_at timestamptz not null default clock_timestamp(),
  unique (project_id, revision_number),
  check (
    (status = 'current' and superseded_at is null
      and superseded_by_revision_id is null)
    or
    (status = 'superseded' and superseded_at is not null
      and superseded_by_revision_id is not null)
  )
);

create unique index v1_accounts_one_current_baseline_idx
  on public.v1_accounts_baseline_revisions (project_id)
  where status = 'current';
create index v1_accounts_baseline_project_revision_idx
  on public.v1_accounts_baseline_revisions
    (project_id, revision_number desc);

alter table public.v1_accounts_project_commercial_profiles
  add constraint v1_accounts_profile_current_baseline_fk
  foreign key (current_baseline_revision_id)
  references public.v1_accounts_baseline_revisions (id)
  on delete restrict
  deferrable initially deferred;

create table public.v1_accounts_baseline_building_allocations (
  id uuid primary key default gen_random_uuid(),
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  project_scope_id uuid not null
    references public.v1_project_scopes (id) on delete restrict,
  allocation_percent numeric(7,4) not null check (
    allocation_percent::text <> 'NaN'
    and allocation_percent > 0 and allocation_percent <= 100
  ),
  created_at timestamptz not null default clock_timestamp(),
  unique (baseline_revision_id, project_scope_id)
);

create index v1_accounts_building_allocations_project_idx
  on public.v1_accounts_baseline_building_allocations
    (project_id, baseline_revision_id);

create table public.v1_accounts_baseline_stage_allocations (
  id uuid primary key default gen_random_uuid(),
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  stage_key text not null check (stage_key ~ '^[a-z][a-z0-9_]*$'),
  stage_name text not null check (btrim(stage_name) <> ''),
  display_order integer not null check (display_order > 0),
  allocation_percent numeric(7,4) not null check (
    allocation_percent::text <> 'NaN'
    and allocation_percent > 0 and allocation_percent <= 100
  ),
  created_at timestamptz not null default clock_timestamp(),
  unique (baseline_revision_id, stage_key),
  unique (baseline_revision_id, display_order)
);

create index v1_accounts_stage_allocations_project_idx
  on public.v1_accounts_baseline_stage_allocations
    (project_id, baseline_revision_id, display_order);

create table public.v1_accounts_billing_progress (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  building_allocation_id uuid not null
    references public.v1_accounts_baseline_building_allocations (id)
      on delete restrict,
  stage_allocation_id uuid not null
    references public.v1_accounts_baseline_stage_allocations (id)
      on delete restrict,
  project_scope_id uuid not null
    references public.v1_project_scopes (id) on delete restrict,
  stage_key text not null check (stage_key ~ '^[a-z][a-z0-9_]*$'),
  suggested_percent numeric(7,4) not null default 0 check (
    suggested_percent::text <> 'NaN'
    and suggested_percent between 0 and 100
  ),
  suggested_evidence_summary text,
  suggested_evidence_document_ids uuid[] not null default '{}',
  suggested_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  suggested_by_exact_role text check (
    suggested_by_exact_role is null or suggested_by_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin'
    )
  ),
  suggested_at timestamptz,
  confirmed_percent numeric(7,4) not null default 0 check (
    confirmed_percent::text <> 'NaN'
    and confirmed_percent between 0 and 100
  ),
  confirmed_evidence_summary text,
  confirmed_evidence_document_ids uuid[] not null default '{}',
  confirmed_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  confirmed_by_exact_role text check (
    confirmed_by_exact_role is null or confirmed_by_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin'
    )
  ),
  confirmed_at timestamptz,
  review_status text not null default 'not_required' check (
    review_status in ('not_required', 'pending', 'approved', 'returned')
  ),
  reviewed_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  reviewed_by_exact_role text check (
    reviewed_by_exact_role is null or reviewed_by_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'workshop_in_charge', 'document_controller',
      'procurement', 'accountant', 'admin'
    )
  ),
  reviewed_at timestamptz,
  review_reason text,
  record_version integer not null default 1 check (record_version > 0),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (baseline_revision_id, project_scope_id, stage_key),
  check (
    (suggested_by_auth_user_id is null and suggested_by_exact_role is null
      and suggested_at is null and suggested_percent = 0)
    or
    (suggested_by_auth_user_id is not null and suggested_by_exact_role is not null
      and suggested_at is not null)
  ),
  check (
    (confirmed_by_auth_user_id is null and confirmed_by_exact_role is null
      and confirmed_at is null and confirmed_percent = 0)
    or
    (confirmed_by_auth_user_id is not null and confirmed_by_exact_role is not null
      and confirmed_at is not null)
  ),
  check (
    (review_status in ('not_required', 'pending')
      and reviewed_by_auth_user_id is null and reviewed_by_exact_role is null
      and reviewed_at is null and review_reason is null)
    or
    (review_status in ('approved', 'returned')
      and reviewed_by_auth_user_id is not null
      and reviewed_by_exact_role is not null
      and reviewed_at is not null
      and review_reason is not null and btrim(review_reason) <> '')
  )
);

create index v1_accounts_progress_project_active_idx
  on public.v1_accounts_billing_progress
    (project_id, baseline_revision_id, project_scope_id, stage_key);
create index v1_accounts_progress_review_idx
  on public.v1_accounts_billing_progress
    (project_id, review_status, updated_at desc);

create table public.v1_accounts_billing_progress_revisions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null
    references public.v1_projects (id) on delete restrict,
  progress_entry_id uuid not null
    references public.v1_accounts_billing_progress (id) on delete restrict,
  baseline_revision_id uuid not null
    references public.v1_accounts_baseline_revisions (id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  action text not null check (action in ('suggested', 'confirmed', 'reviewed')),
  previous_suggested_percent numeric(7,4) not null check (
    previous_suggested_percent::text <> 'NaN'
    and previous_suggested_percent between 0 and 100
  ),
  new_suggested_percent numeric(7,4) not null check (
    new_suggested_percent::text <> 'NaN'
    and new_suggested_percent between 0 and 100
  ),
  previous_confirmed_percent numeric(7,4) not null check (
    previous_confirmed_percent::text <> 'NaN'
    and previous_confirmed_percent between 0 and 100
  ),
  new_confirmed_percent numeric(7,4) not null check (
    new_confirmed_percent::text <> 'NaN'
    and new_confirmed_percent between 0 and 100
  ),
  previous_review_status text not null check (
    previous_review_status in ('not_required', 'pending', 'approved', 'returned')
  ),
  new_review_status text not null check (
    new_review_status in ('not_required', 'pending', 'approved', 'returned')
  ),
  evidence_summary text,
  evidence_document_ids uuid[] not null default '{}',
  reason text not null check (btrim(reason) <> ''),
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
  unique (progress_entry_id, revision_number),
  unique (progress_entry_id, occurred_at)
);

create index v1_accounts_progress_revisions_project_idx
  on public.v1_accounts_billing_progress_revisions
    (project_id, occurred_at desc);

-- Direct Data API access is denied. Reads and writes are only through the
-- role-shaped projections and transactional commands below.
alter table public.v1_accounts_project_commercial_profiles enable row level security;
alter table public.v1_accounts_baseline_revisions enable row level security;
alter table public.v1_accounts_baseline_building_allocations enable row level security;
alter table public.v1_accounts_baseline_stage_allocations enable row level security;
alter table public.v1_accounts_billing_progress enable row level security;
alter table public.v1_accounts_billing_progress_revisions enable row level security;

revoke all on table public.v1_accounts_project_commercial_profiles
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_baseline_revisions
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_baseline_building_allocations
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_baseline_stage_allocations
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_billing_progress
  from public, anon, authenticated, service_role;
revoke all on table public.v1_accounts_billing_progress_revisions
  from public, anon, authenticated, service_role;

grant select on table public.v1_accounts_project_commercial_profiles to service_role;
grant select on table public.v1_accounts_baseline_revisions to service_role;
grant select on table public.v1_accounts_baseline_building_allocations to service_role;
grant select on table public.v1_accounts_baseline_stage_allocations to service_role;
grant select on table public.v1_accounts_billing_progress to service_role;
grant select on table public.v1_accounts_billing_progress_revisions to service_role;

create or replace function public.v1_accounts_parse_money_text(p_value text)
returns numeric
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  v_value numeric;
begin
  if p_value is null
    or btrim(p_value) !~ '^[+-]?[0-9]+([.][0-9]{1,2})?$' then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
  end if;
  v_value := btrim(p_value)::numeric;
  if v_value::text = 'NaN' or v_value <> round(v_value, 2) then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
  end if;
  return v_value;
exception when invalid_text_representation or numeric_value_out_of_range then
  raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
end;
$$;

create or replace function public.v1_accounts_parse_percent_text(p_value text)
returns numeric
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  v_value numeric;
begin
  if p_value is null
    or btrim(p_value) !~ '^[+-]?[0-9]+([.][0-9]{1,4})?$' then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
  end if;
  v_value := btrim(p_value)::numeric;
  if v_value::text = 'NaN' or v_value <> round(v_value, 4) then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
  end if;
  return v_value;
exception when invalid_text_representation or numeric_value_out_of_range then
  raise exception 'R39_ACCOUNTS_INVALID_NUMERIC' using errcode = '22023';
end;
$$;

create or replace function public.v1_accounts_normalize_review_policy(
  p_policy jsonb
)
returns jsonb
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  v_policy jsonb := coalesce(p_policy, '{}'::jsonb);
  v_always boolean := false;
  -- Keep the parsed value unconstrained until scale validation has passed;
  -- assigning directly to numeric(20,2) would silently round first.
  v_threshold numeric;
  v_roles text[] := '{}'::text[];
begin
  if jsonb_typeof(v_policy) <> 'object' then
    raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
      using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_object_keys(v_policy) policy_key
    where policy_key not in (
      'always_required', 'threshold_amount', 'confirming_exact_roles'
    )
  ) then
    raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
      using errcode = '22023';
  end if;
  if v_policy ? 'always_required' then
    if jsonb_typeof(v_policy -> 'always_required') <> 'boolean' then
      raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
        using errcode = '22023';
    end if;
    v_always := (v_policy ->> 'always_required')::boolean;
  end if;
  if v_policy ? 'threshold_amount'
    and jsonb_typeof(v_policy -> 'threshold_amount') <> 'null' then
    if jsonb_typeof(v_policy -> 'threshold_amount')
      not in ('number', 'string') then
      raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
        using errcode = '22023';
    end if;
    v_threshold := (v_policy ->> 'threshold_amount')::numeric;
    if v_threshold::text = 'NaN' or v_threshold <= 0
      or v_threshold <> round(v_threshold, 2) then
      raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
        using errcode = '22023';
    end if;
  end if;
  if v_policy ? 'confirming_exact_roles' then
    if jsonb_typeof(v_policy -> 'confirming_exact_roles') <> 'array' then
      raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
        using errcode = '22023';
    end if;
    select coalesce(array_agg(value order by value), '{}'::text[])
    into v_roles
    from (
      select distinct jsonb_array_elements_text(
        v_policy -> 'confirming_exact_roles'
      ) as value
    ) role_value;
    if exists (
      select 1 from unnest(v_roles) role_name
      where role_name not in (
        'project_engineer', 'senior_mechanical_engineer', 'project_manager',
        'workshop_in_charge', 'document_controller'
      )
    ) then
      raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
        using errcode = '22023';
    end if;
  end if;
  return jsonb_build_object(
    'always_required', v_always,
    'threshold_amount', case when v_threshold is null then null
      else to_jsonb(v_threshold::text) end,
    'confirming_exact_roles', to_jsonb(v_roles)
  );
exception when invalid_text_representation or numeric_value_out_of_range then
  raise exception 'R39_ACCOUNTS_REVIEW_POLICY_INVALID'
    using errcode = '22023';
end;
$$;

create or replace function public.v1_accounts_canonical_building_allocations(
  p_allocations jsonb
)
returns jsonb
language plpgsql
immutable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_count integer;
  v_distinct_count integer;
begin
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array'
    or jsonb_array_length(p_allocations) = 0 then
    raise exception 'R39_ACCOUNTS_INVALID_BUILDING_ALLOCATIONS'
      using errcode = '22023';
  end if;
  select count(*), count(distinct (item ->> 'building_scope_id')::uuid)
  into v_count, v_distinct_count
  from jsonb_array_elements(p_allocations) item;
  if v_count <> v_distinct_count then
    raise exception 'R39_ACCOUNTS_INVALID_BUILDING_ALLOCATIONS'
      using errcode = '22023';
  end if;
  with parsed as (
    select
      (item ->> 'building_scope_id')::uuid as project_scope_id,
      public.v1_accounts_parse_percent_text(
        item ->> 'allocation_percent'
      )::numeric(7,4) as allocation_percent
    from jsonb_array_elements(p_allocations) item
  )
  select jsonb_agg(jsonb_build_object(
    'building_scope_id', project_scope_id,
    'allocation_percent', allocation_percent::text
  ) order by project_scope_id)
  into v_result
  from parsed;
  return v_result;
exception when invalid_text_representation or numeric_value_out_of_range
  or not_null_violation then
  raise exception 'R39_ACCOUNTS_INVALID_BUILDING_ALLOCATIONS'
    using errcode = '22023';
end;
$$;

create or replace function public.v1_accounts_canonical_stage_allocations(
  p_allocations jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_count integer;
  v_distinct_keys integer;
  v_distinct_positions integer;
begin
  if p_allocations is null then
    select jsonb_agg(jsonb_build_object(
      'stage_key', stage.stage_key,
      'stage_label', stage.stage_name,
      'allocation_percent', stage.allocation_percent::text,
      'position', stage.display_order
    ) order by stage.display_order)
    into v_result
    from public.v1_accounts_billing_stage_templates stage
    where stage.is_active;
    return v_result;
  end if;
  if jsonb_typeof(p_allocations) <> 'array'
    or jsonb_array_length(p_allocations) = 0 then
    raise exception 'R39_ACCOUNTS_INVALID_STAGE_ALLOCATIONS'
      using errcode = '22023';
  end if;
  select count(*), count(distinct btrim(item ->> 'stage_key')),
         count(distinct (item ->> 'position')::integer)
  into v_count, v_distinct_keys, v_distinct_positions
  from jsonb_array_elements(p_allocations) item;
  if v_count <> v_distinct_keys or v_count <> v_distinct_positions then
    raise exception 'R39_ACCOUNTS_INVALID_STAGE_ALLOCATIONS'
      using errcode = '22023';
  end if;
  with parsed as (
    select
      btrim(item ->> 'stage_key') as stage_key,
      btrim(item ->> 'stage_label') as stage_name,
      public.v1_accounts_parse_percent_text(
        item ->> 'allocation_percent'
      )::numeric(7,4) as allocation_percent,
      (item ->> 'position')::integer as display_order
    from jsonb_array_elements(p_allocations) item
  )
  select jsonb_agg(jsonb_build_object(
    'stage_key', stage_key,
    'stage_label', stage_name,
    'allocation_percent', allocation_percent::text,
    'position', display_order
  ) order by display_order, stage_key)
  into v_result
  from parsed;
  return v_result;
exception when invalid_text_representation or numeric_value_out_of_range
  or not_null_violation then
  raise exception 'R39_ACCOUNTS_INVALID_STAGE_ALLOCATIONS'
    using errcode = '22023';
end;
$$;

create or replace function public.v1_accounts_canonical_evidence_ids(
  p_document_ids uuid[]
)
returns uuid[]
language sql
immutable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct document_id order by document_id), '{}')
  from unnest(coalesce(p_document_ids, '{}'::uuid[])) document_id;
$$;

create or replace function public.v1_accounts_require_capability(
  p_project_id uuid,
  p_capability_key text
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
begin
  if v_actor is null or p_project_id is null
    or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  v_exact_role := public.v1_permission_exact_role(v_actor);
  if v_exact_role = ''
    or not public.v1_current_user_has_capability(
      p_capability_key, p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode = '42501';
  end if;
  return v_exact_role;
end;
$$;

create or replace function public.v1_accounts_validate_evidence_documents(
  p_project_id uuid,
  p_document_ids uuid[]
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[] := public.v1_accounts_canonical_evidence_ids(p_document_ids);
begin
  if cardinality(v_ids) = 0 then return; end if;
  if (
    select count(*)
    from public.v1_documents document
    where document.id = any(v_ids)
      and document.current_version_id is not null
      and document.classification = 'operational'
      and exists (
        select 1 from public.v1_document_links link
        where link.document_id = document.id
          and link.project_id = p_project_id
          and link.removed_at is null
      )
  ) <> cardinality(v_ids) then
    raise exception 'R39_ACCOUNTS_EVIDENCE_DOCUMENT_INVALID'
      using errcode = '22023';
  end if;
end;
$$;

create or replace function public.v1_accounts_review_required(
  p_policy jsonb,
  p_confirmed_eligible numeric,
  p_confirming_exact_role text
)
returns boolean
language sql
immutable
security definer
set search_path = ''
as $$
  select coalesce((p_policy ->> 'always_required')::boolean, false)
    or (
      nullif(p_policy ->> 'threshold_amount', '') is not null
      and p_confirmed_eligible >= (p_policy ->> 'threshold_amount')::numeric
    )
    or exists (
      select 1
      from jsonb_array_elements_text(
        coalesce(p_policy -> 'confirming_exact_roles', '[]'::jsonb)
      ) configured_role
      where configured_role = p_confirming_exact_role
    );
$$;

-- T03 replaces these protected seams atomically with claim-backed logic. T02
-- creates no fake claim rows and therefore has zero consumed claim basis.
create or replace function public.v1_accounts_consumed_claim_amount(
  p_progress_entry_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$ select 0::numeric; $$;

create or replace function public.v1_accounts_mark_claim_drafts_stale(
  p_old_baseline_revision_id uuid,
  p_new_baseline_revision_id uuid
)
returns integer
language sql
security definer
set search_path = ''
as $$ select 0; $$;

create or replace function public.v1_accounts_validate_building_allocation_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope public.v1_project_scopes%rowtype;
  v_baseline_project uuid;
begin
  select * into v_scope from public.v1_project_scopes scope
  where scope.id = new.project_scope_id;
  select baseline.project_id into v_baseline_project
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = new.baseline_revision_id;
  if not found or v_scope.id is null
    or v_scope.project_id <> new.project_id
    or v_baseline_project <> new.project_id then
    raise exception 'R39_ACCOUNTS_BUILDING_PROJECT_MISMATCH'
      using errcode = '23514';
  end if;
  if v_scope.scope_kind <> 'building' or not v_scope.is_active then
    raise exception 'R39_ACCOUNTS_COMMON_SCOPE_FORBIDDEN'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_accounts_validate_building_allocation_row
before insert or update on public.v1_accounts_baseline_building_allocations
for each row execute function public.v1_accounts_validate_building_allocation_row();

create or replace function public.v1_accounts_validate_stage_allocation_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.v1_accounts_baseline_revisions baseline
    where baseline.id = new.baseline_revision_id
      and baseline.project_id = new.project_id
  ) then
    raise exception 'R39_ACCOUNTS_STAGE_PROJECT_MISMATCH'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_accounts_validate_stage_allocation_row
before insert or update on public.v1_accounts_baseline_stage_allocations
for each row execute function public.v1_accounts_validate_stage_allocation_row();

create or replace function public.v1_accounts_validate_progress_dimension_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.v1_accounts_baseline_revisions baseline
    join public.v1_accounts_baseline_building_allocations building
      on building.id = new.building_allocation_id
     and building.baseline_revision_id = baseline.id
     and building.project_id = baseline.project_id
     and building.project_scope_id = new.project_scope_id
    join public.v1_accounts_baseline_stage_allocations stage
      on stage.id = new.stage_allocation_id
     and stage.baseline_revision_id = baseline.id
     and stage.project_id = baseline.project_id
     and stage.stage_key = new.stage_key
    where baseline.id = new.baseline_revision_id
      and baseline.project_id = new.project_id
  ) then
    raise exception 'R39_ACCOUNTS_PROGRESS_DIMENSION_MISMATCH'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger v1_accounts_validate_progress_dimension_row
before insert or update on public.v1_accounts_billing_progress
for each row execute function public.v1_accounts_validate_progress_dimension_row();

create or replace function public.v1_accounts_validate_baseline_totals()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_baseline_id uuid;
  v_building_total numeric(12,4);
  v_stage_total numeric(12,4);
begin
  v_baseline_id := case when tg_op = 'DELETE'
    then old.baseline_revision_id
    else new.baseline_revision_id
  end;
  select coalesce(sum(allocation.allocation_percent), 0)
  into v_building_total
  from public.v1_accounts_baseline_building_allocations allocation
  where allocation.baseline_revision_id = v_baseline_id;
  select coalesce(sum(stage.allocation_percent), 0)
  into v_stage_total
  from public.v1_accounts_baseline_stage_allocations stage
  where stage.baseline_revision_id = v_baseline_id;
  if abs(v_building_total - 100.0000) > 0.00005 then
    raise exception 'R39_ACCOUNTS_INVALID_BUILDING_ALLOCATIONS'
      using errcode = '23514';
  end if;
  if abs(v_stage_total - 100.0000) > 0.00005 then
    raise exception 'R39_ACCOUNTS_INVALID_STAGE_ALLOCATIONS'
      using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger v1_accounts_validate_building_totals
after insert or update or delete
on public.v1_accounts_baseline_building_allocations
deferrable initially deferred
for each row execute function public.v1_accounts_validate_baseline_totals();
create constraint trigger v1_accounts_validate_stage_totals
after insert or update or delete
on public.v1_accounts_baseline_stage_allocations
deferrable initially deferred
for each row execute function public.v1_accounts_validate_baseline_totals();

create or replace function public.v1_accounts_materialize_baseline_dimensions(
  p_project_id uuid,
  p_baseline_revision_id uuid,
  p_building_allocations jsonb,
  p_stage_allocations jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_building_count integer;
  v_building_distinct integer;
  v_building_total numeric(12,4);
  v_stage_count integer;
  v_stage_distinct integer;
  v_order_distinct integer;
  v_stage_total numeric(12,4);
begin
  with parsed as (
    select
      (item ->> 'building_scope_id')::uuid as project_scope_id,
      public.v1_accounts_parse_percent_text(
        item ->> 'allocation_percent'
      )::numeric(7,4) as allocation_percent
    from jsonb_array_elements(p_building_allocations) item
  )
  select count(*), count(distinct project_scope_id),
         coalesce(sum(allocation_percent), 0)
  into v_building_count, v_building_distinct, v_building_total
  from parsed;
  if v_building_count = 0 or v_building_count <> v_building_distinct
    or abs(v_building_total - 100.0000) > 0.00005 then
    raise exception 'R39_ACCOUNTS_INVALID_BUILDING_ALLOCATIONS'
      using errcode = '23514';
  end if;

  insert into public.v1_accounts_baseline_building_allocations (
    baseline_revision_id, project_id, project_scope_id, allocation_percent
  )
  select p_baseline_revision_id, p_project_id,
         (item ->> 'building_scope_id')::uuid,
         public.v1_accounts_parse_percent_text(
           item ->> 'allocation_percent'
         )::numeric(7,4)
  from jsonb_array_elements(p_building_allocations) item;

  with parsed as (
    select
      btrim(item ->> 'stage_key') as stage_key,
      btrim(item ->> 'stage_label') as stage_name,
      public.v1_accounts_parse_percent_text(
        item ->> 'allocation_percent'
      )::numeric(7,4) as allocation_percent,
      (item ->> 'position')::integer as display_order
    from jsonb_array_elements(p_stage_allocations) item
  )
  select count(*), count(distinct stage_key), count(distinct display_order),
         coalesce(sum(allocation_percent), 0)
  into v_stage_count, v_stage_distinct, v_order_distinct, v_stage_total
  from parsed
  where stage_key ~ '^[a-z][a-z0-9_]*$'
    and stage_name <> ''
    and display_order > 0
    and allocation_percent > 0 and allocation_percent <= 100;
  if v_stage_count = 0 or v_stage_count <> v_stage_distinct
    or v_stage_count <> v_order_distinct
    or v_stage_count <> jsonb_array_length(p_stage_allocations)
    or abs(v_stage_total - 100.0000) > 0.00005 then
    raise exception 'R39_ACCOUNTS_INVALID_STAGE_ALLOCATIONS'
      using errcode = '23514';
  end if;

  insert into public.v1_accounts_baseline_stage_allocations (
    baseline_revision_id, project_id, stage_key, stage_name,
    display_order, allocation_percent
  )
  select p_baseline_revision_id, p_project_id,
         btrim(item ->> 'stage_key'), btrim(item ->> 'stage_label'),
         (item ->> 'position')::integer,
         public.v1_accounts_parse_percent_text(
           item ->> 'allocation_percent'
         )::numeric(7,4)
  from jsonb_array_elements(p_stage_allocations) item;

  insert into public.v1_accounts_billing_progress (
    project_id, baseline_revision_id, building_allocation_id,
    stage_allocation_id, project_scope_id, stage_key
  )
  select p_project_id, p_baseline_revision_id, building.id, stage.id,
         building.project_scope_id, stage.stage_key
  from public.v1_accounts_baseline_building_allocations building
  cross join public.v1_accounts_baseline_stage_allocations stage
  where building.baseline_revision_id = p_baseline_revision_id
    and stage.baseline_revision_id = p_baseline_revision_id;
exception when invalid_text_representation or numeric_value_out_of_range
  or not_null_violation then
  raise exception 'R39_ACCOUNTS_BASELINE_DIMENSIONS_INVALID'
    using errcode = '22023';
end;
$$;

-- Resolve fixed-precision Building x Stage values with a deterministic
-- largest-remainder policy. Each raw formula remains authoritative; values are
-- floored to cents and the remaining baseline cents are awarded by descending
-- fractional remainder, with physical scope and stage order as stable ties.
-- This prevents independent display rounding from drifting away from the
-- two-decimal contract baseline while never creating or losing a cent.
create or replace function public.v1_accounts_stage_value(
  p_progress_entry_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select progress.baseline_revision_id
    from public.v1_accounts_billing_progress progress
    where progress.id = p_progress_entry_id
  ), cells as (
    select
      progress.id,
      baseline.contract_value,
      pg_catalog.floor(
        baseline.contract_value * building.allocation_percent
          * stage.allocation_percent / 10000 * 100
      )::bigint as base_cents,
      (
        baseline.contract_value * building.allocation_percent
          * stage.allocation_percent / 10000 * 100
      ) - pg_catalog.floor(
        baseline.contract_value * building.allocation_percent
          * stage.allocation_percent / 10000 * 100
      ) as fractional_cent,
      scope.scope_code,
      stage.display_order
    from target
    join public.v1_accounts_baseline_revisions baseline
      on baseline.id = target.baseline_revision_id
    join public.v1_accounts_billing_progress progress
      on progress.baseline_revision_id = baseline.id
    join public.v1_accounts_baseline_building_allocations building
      on building.id = progress.building_allocation_id
    join public.v1_accounts_baseline_stage_allocations stage
      on stage.id = progress.stage_allocation_id
    join public.v1_project_scopes scope
      on scope.id = progress.project_scope_id
  ), ranked as (
    select cells.*,
      pg_catalog.row_number() over (
        order by fractional_cent desc, scope_code, display_order, id
      ) as residual_rank,
      pg_catalog.round(pg_catalog.max(contract_value) over () * 100)::bigint
        - pg_catalog.sum(base_cents) over ()::bigint as residual_cents
    from cells
  )
  select (
    base_cents + case when residual_rank <= residual_cents then 1 else 0 end
  )::numeric / 100
  from ranked
  where id = p_progress_entry_id;
$$;

create or replace function public.v1_initialize_project_commercial_baseline(
  p_project_id uuid,
  p_contract_value text,
  p_currency_code text,
  p_vat_rate text,
  p_payment_terms_days integer,
  p_reminder_lead_days integer,
  p_building_allocations jsonb,
  p_stage_allocations jsonb,
  p_management_review_policy jsonb,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_actor_role text;
  v_terms integer;
  v_reminder integer;
  v_contract_value numeric(20,2);
  v_vat_rate numeric(7,4);
  v_buildings jsonb;
  v_stages jsonb;
  v_review_policy jsonb;
  v_payload jsonb;
  v_existing_response jsonb;
  v_baseline_id uuid;
  v_response jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'configure_project_commercials'
  );
  v_actor_role := public.v1_current_role();
  if not exists (
    select 1 from public.v1_projects project where project.id = p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_PROJECT_NOT_FOUND' using errcode = 'P0002';
  end if;
  begin
    v_contract_value := public.v1_accounts_parse_money_text(
      p_contract_value
    )::numeric(20,2);
    v_vat_rate := public.v1_accounts_parse_percent_text(
      p_vat_rate
    )::numeric(7,4);
  exception when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC'
      using errcode = '22023';
  end;
  if v_contract_value is null or v_contract_value::text = 'NaN'
    or v_contract_value <= 0 then
    raise exception 'R39_ACCOUNTS_INVALID_CONTRACT_VALUE'
      using errcode = '22023';
  end if;
  if p_currency_code is null
    or upper(btrim(p_currency_code)) !~ '^[A-Z]{3}$' then
    raise exception 'R39_ACCOUNTS_INVALID_CURRENCY_CODE'
      using errcode = '22023';
  end if;
  if v_vat_rate is null or v_vat_rate::text = 'NaN'
    or v_vat_rate < 0 or v_vat_rate > 100 then
    raise exception 'R39_ACCOUNTS_INVALID_VAT_RATE'
      using errcode = '22023';
  end if;
  if nullif(btrim(p_reason), '') is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode = '22023';
  end if;

  select coalesce(p_payment_terms_days, settings.default_payment_terms_days),
         coalesce(p_reminder_lead_days, settings.default_reminder_lead_days)
  into v_terms, v_reminder
  from public.v1_accounts_foundation_settings settings
  where settings.singleton;
  if v_terms is null or v_terms <= 0 or v_reminder is null
    or v_reminder < 0 or v_reminder > v_terms then
    raise exception 'R39_ACCOUNTS_INVALID_TERMS' using errcode = '22023';
  end if;

  v_buildings := public.v1_accounts_canonical_building_allocations(
    p_building_allocations
  );
  v_stages := public.v1_accounts_canonical_stage_allocations(
    p_stage_allocations
  );
  v_review_policy := public.v1_accounts_normalize_review_policy(
    p_management_review_policy
  );
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'contract_value', v_contract_value::text,
    'currency_code', upper(btrim(p_currency_code)),
    'vat_rate_percent', v_vat_rate::text,
    'payment_terms_days', v_terms,
    'reminder_lead_days', v_reminder,
    'building_allocations', v_buildings,
    'stage_allocations', v_stages,
    'management_review_policy', v_review_policy,
    'reason', btrim(p_reason)
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_initialize_project_commercial_baseline',
    p_idempotency_key, v_payload
  );
  if v_existing_response is not null then
    return v_existing_response || jsonb_build_object('replayed', true);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_baseline|' || p_project_id::text, 0
    )
  );
  if exists (
    select 1 from public.v1_accounts_project_commercial_profiles profile
    where profile.project_id = p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_BASELINE_ALREADY_INITIALIZED'
      using errcode = '23505';
  end if;

  insert into public.v1_accounts_project_commercial_profiles (
    project_id, created_by_auth_user_id, created_by_role,
    created_by_exact_role
  ) values (p_project_id, v_actor, v_actor_role, v_exact_role);

  insert into public.v1_accounts_baseline_revisions (
    project_id, revision_number, status, contract_value, currency_code,
    vat_rate_percent, payment_terms_days, reminder_lead_days,
    management_review_policy, reason, approved_by_auth_user_id,
    approved_by_role, approved_by_exact_role, idempotency_key
  ) values (
    p_project_id, 1, 'current', v_contract_value,
    upper(btrim(p_currency_code)), v_vat_rate,
    v_terms, v_reminder, v_review_policy, btrim(p_reason), v_actor,
    v_actor_role, v_exact_role, p_idempotency_key
  ) returning id into v_baseline_id;

  perform public.v1_accounts_materialize_baseline_dimensions(
    p_project_id, v_baseline_id, v_buildings, v_stages
  );
  update public.v1_accounts_project_commercial_profiles
  set current_baseline_revision_id = v_baseline_id,
      updated_at = clock_timestamp()
  where project_id = p_project_id;

  perform public.v1_write_audit_event(
    'accounts_baseline_initialized', 'accounts_baseline', v_baseline_id,
    p_project_id, null,
    jsonb_build_object(
      'revision_number', 1,
      'contract_value', v_contract_value::text,
      'currency_code', upper(btrim(p_currency_code)),
      'vat_rate_percent', v_vat_rate::text,
      'payment_terms_days', v_terms,
      'reminder_lead_days', v_reminder,
      'building_allocations', v_buildings,
      'stage_allocations', v_stages,
      'management_review_policy', v_review_policy
    ), btrim(p_reason), p_idempotency_key
  );

  v_response := jsonb_build_object(
    'replayed', false,
    'project_id', p_project_id,
    'entity_id', v_baseline_id,
    'baseline_revision_id', v_baseline_id,
    'baseline_revision_number', 1,
    'record_version', 1,
    'status', 'current',
    'updated_at', clock_timestamp()
  );
  perform public.v1_complete_idempotency(
    'v1_initialize_project_commercial_baseline',
    p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_revise_project_commercial_baseline(
  p_project_id uuid,
  p_expected_baseline_version integer,
  p_contract_value text,
  p_currency_code text,
  p_vat_rate text,
  p_payment_terms_days integer,
  p_reminder_lead_days integer,
  p_building_allocations jsonb,
  p_stage_allocations jsonb,
  p_management_review_policy jsonb,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_actor_role text;
  v_profile public.v1_accounts_project_commercial_profiles%rowtype;
  v_old public.v1_accounts_baseline_revisions%rowtype;
  v_terms integer;
  v_reminder integer;
  v_contract_value numeric(20,2);
  v_vat_rate numeric(7,4);
  v_buildings jsonb;
  v_stages jsonb;
  v_old_buildings jsonb;
  v_old_stages jsonb;
  v_review_policy jsonb;
  v_payload jsonb;
  v_existing_response jsonb;
  v_new_baseline_id uuid;
  v_new_revision integer;
  v_response jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'configure_project_commercials'
  );
  v_actor_role := public.v1_current_role();
  if p_expected_baseline_version is null or p_expected_baseline_version <= 0 then
    raise exception 'R39_ACCOUNTS_EXPECTED_VERSION_REQUIRED'
      using errcode = '22023';
  end if;
  begin
    v_contract_value := public.v1_accounts_parse_money_text(
      p_contract_value
    )::numeric(20,2);
    v_vat_rate := public.v1_accounts_parse_percent_text(
      p_vat_rate
    )::numeric(7,4);
  exception when invalid_text_representation or numeric_value_out_of_range then
    raise exception 'R39_ACCOUNTS_INVALID_NUMERIC'
      using errcode = '22023';
  end;
  if v_contract_value is null or v_contract_value::text = 'NaN'
    or v_contract_value <= 0 then
    raise exception 'R39_ACCOUNTS_INVALID_CONTRACT_VALUE'
      using errcode = '22023';
  end if;
  if p_currency_code is null
    or upper(btrim(p_currency_code)) !~ '^[A-Z]{3}$' then
    raise exception 'R39_ACCOUNTS_INVALID_CURRENCY_CODE'
      using errcode = '22023';
  end if;
  if v_vat_rate is null or v_vat_rate::text = 'NaN'
    or v_vat_rate < 0 or v_vat_rate > 100 then
    raise exception 'R39_ACCOUNTS_INVALID_VAT_RATE'
      using errcode = '22023';
  end if;
  if nullif(btrim(p_reason), '') is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode = '22023';
  end if;
  select coalesce(p_payment_terms_days, settings.default_payment_terms_days),
         coalesce(p_reminder_lead_days, settings.default_reminder_lead_days)
  into v_terms, v_reminder
  from public.v1_accounts_foundation_settings settings
  where settings.singleton;
  if v_terms is null or v_terms <= 0 or v_reminder is null
    or v_reminder < 0 or v_reminder > v_terms then
    raise exception 'R39_ACCOUNTS_INVALID_TERMS' using errcode = '22023';
  end if;
  v_buildings := public.v1_accounts_canonical_building_allocations(
    p_building_allocations
  );
  v_stages := public.v1_accounts_canonical_stage_allocations(
    p_stage_allocations
  );
  v_review_policy := public.v1_accounts_normalize_review_policy(
    p_management_review_policy
  );
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'expected_baseline_version', p_expected_baseline_version,
    'contract_value', v_contract_value::text,
    'currency_code', upper(btrim(p_currency_code)),
    'vat_rate_percent', v_vat_rate::text,
    'payment_terms_days', v_terms,
    'reminder_lead_days', v_reminder,
    'building_allocations', v_buildings,
    'stage_allocations', v_stages,
    'management_review_policy', v_review_policy,
    'reason', btrim(p_reason)
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_revise_project_commercial_baseline',
    p_idempotency_key, v_payload
  );
  if v_existing_response is not null then
    return v_existing_response || jsonb_build_object('replayed', true);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_baseline|' || p_project_id::text, 0
    )
  );
  select * into v_profile
  from public.v1_accounts_project_commercial_profiles profile
  where profile.project_id = p_project_id
  for update;
  if not found then
    raise exception 'R39_ACCOUNTS_BASELINE_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_profile.record_version <> p_expected_baseline_version then
    raise exception 'R39_ACCOUNTS_STALE_VERSION' using errcode = '40001';
  end if;
  select * into v_old
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_profile.current_baseline_revision_id
  for update;
  if not found or v_old.status <> 'current' then
    raise exception 'R39_ACCOUNTS_BASELINE_NOT_FOUND' using errcode = 'P0002';
  end if;
  v_new_revision := v_old.revision_number + 1;

  select coalesce(jsonb_agg(jsonb_build_object(
           'building_scope_id', allocation.project_scope_id,
           'allocation_percent', allocation.allocation_percent::text
         ) order by allocation.project_scope_id), '[]'::jsonb)
  into v_old_buildings
  from public.v1_accounts_baseline_building_allocations allocation
  where allocation.baseline_revision_id = v_old.id;
  select coalesce(jsonb_agg(jsonb_build_object(
           'stage_key', allocation.stage_key,
           'stage_label', allocation.stage_name,
           'allocation_percent', allocation.allocation_percent::text,
           'position', allocation.display_order
         ) order by allocation.display_order), '[]'::jsonb)
  into v_old_stages
  from public.v1_accounts_baseline_stage_allocations allocation
  where allocation.baseline_revision_id = v_old.id;

  v_new_baseline_id := gen_random_uuid();
  update public.v1_accounts_baseline_revisions
  set status = 'superseded',
      superseded_at = clock_timestamp(),
      superseded_by_revision_id = v_new_baseline_id
  where id = v_old.id;

  insert into public.v1_accounts_baseline_revisions (
    id, project_id, revision_number, status, contract_value, currency_code,
    vat_rate_percent, payment_terms_days, reminder_lead_days,
    management_review_policy, reason, approved_by_auth_user_id,
    approved_by_role, approved_by_exact_role, idempotency_key
  ) values (
    v_new_baseline_id, p_project_id, v_new_revision, 'current',
    v_contract_value, upper(btrim(p_currency_code)), v_vat_rate,
    v_terms, v_reminder, v_review_policy, btrim(p_reason), v_actor,
    v_actor_role, v_exact_role, p_idempotency_key
  );

  perform public.v1_accounts_materialize_baseline_dimensions(
    p_project_id, v_new_baseline_id, v_buildings, v_stages
  );
  update public.v1_accounts_project_commercial_profiles
  set current_baseline_revision_id = v_new_baseline_id,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where project_id = p_project_id;

  perform public.v1_accounts_mark_claim_drafts_stale(
    v_old.id, v_new_baseline_id
  );
  perform public.v1_write_audit_event(
    'accounts_baseline_revised', 'accounts_baseline', v_new_baseline_id,
    p_project_id,
    jsonb_build_object(
      'baseline_revision_id', v_old.id,
      'revision_number', v_old.revision_number,
      'contract_value', v_old.contract_value::text,
      'currency_code', v_old.currency_code,
      'vat_rate_percent', v_old.vat_rate_percent::text,
      'payment_terms_days', v_old.payment_terms_days,
      'reminder_lead_days', v_old.reminder_lead_days,
      'management_review_policy', v_old.management_review_policy,
      'building_allocations', v_old_buildings,
      'stage_allocations', v_old_stages
    ),
    jsonb_build_object(
      'baseline_revision_id', v_new_baseline_id,
      'revision_number', v_new_revision,
      'contract_value', v_contract_value::text,
      'currency_code', upper(btrim(p_currency_code)),
      'vat_rate_percent', v_vat_rate::text,
      'payment_terms_days', v_terms,
      'reminder_lead_days', v_reminder,
      'building_allocations', v_buildings,
      'stage_allocations', v_stages,
      'management_review_policy', v_review_policy
    ),
    btrim(p_reason), p_idempotency_key
  );

  v_response := jsonb_build_object(
    'replayed', false,
    'project_id', p_project_id,
    'entity_id', v_new_baseline_id,
    'baseline_revision_id', v_new_baseline_id,
    'baseline_revision_number', v_new_revision,
    'record_version', v_profile.record_version + 1,
    'status', 'current',
    'updated_at', clock_timestamp()
  );
  perform public.v1_complete_idempotency(
    'v1_revise_project_commercial_baseline',
    p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_suggest_billing_progress(
  p_project_id uuid,
  p_progress_entry_id uuid,
  p_expected_version integer,
  p_suggested_percent text,
  p_evidence_summary text,
  p_evidence_document_ids uuid[],
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_actor_role text;
  v_entry public.v1_accounts_billing_progress%rowtype;
  v_percent numeric(7,4);
  v_evidence_ids uuid[];
  v_reason text;
  v_payload jsonb;
  v_existing_response jsonb;
  v_revision_number integer;
  v_updated_at timestamptz;
  v_response jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'suggest_billing_progress'
  );
  v_actor_role := public.v1_current_role();
  if p_expected_version is null or p_expected_version <= 0 then
    raise exception 'R39_ACCOUNTS_EXPECTED_VERSION_REQUIRED'
      using errcode = '22023';
  end if;
  v_percent := public.v1_accounts_parse_percent_text(
    p_suggested_percent
  )::numeric(7,4);
  if v_percent < 0 or v_percent > 100 then
    raise exception 'R39_ACCOUNTS_INVALID_PROGRESS_PERCENT'
      using errcode = '22023';
  end if;
  v_evidence_ids := public.v1_accounts_canonical_evidence_ids(
    p_evidence_document_ids
  );
  if cardinality(v_evidence_ids) = 0
    and nullif(btrim(p_evidence_summary), '') is null then
    raise exception 'R39_ACCOUNTS_EVIDENCE_REQUIRED'
      using errcode = '22023';
  end if;
  v_reason := nullif(btrim(p_reason), '');
  if v_reason is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode = '22023';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'progress_entry_id', p_progress_entry_id,
    'expected_version', p_expected_version,
    'suggested_percent', v_percent::text,
    'evidence_summary', nullif(btrim(p_evidence_summary), ''),
    'evidence_document_ids', to_jsonb(v_evidence_ids),
    'reason', v_reason
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_suggest_billing_progress', p_idempotency_key, v_payload
  );
  if v_existing_response is not null then
    return v_existing_response || jsonb_build_object('replayed', true);
  end if;
  perform public.v1_accounts_validate_evidence_documents(
    p_project_id, v_evidence_ids
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_progress|' || p_progress_entry_id::text, 0
    )
  );
  select progress.* into v_entry
  from public.v1_accounts_billing_progress progress
  join public.v1_accounts_project_commercial_profiles profile
    on profile.project_id = progress.project_id
   and profile.current_baseline_revision_id = progress.baseline_revision_id
   and profile.status = 'active'
  where progress.id = p_progress_entry_id
    and progress.project_id = p_project_id
  for update of progress;
  if not found then
    raise exception 'R39_ACCOUNTS_PROGRESS_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_entry.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_STALE_VERSION' using errcode = '40001';
  end if;

  select coalesce(max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.v1_accounts_billing_progress_revisions revision
  where revision.progress_entry_id = v_entry.id;

  update public.v1_accounts_billing_progress
  set suggested_percent = v_percent,
      suggested_evidence_summary = nullif(btrim(p_evidence_summary), ''),
      suggested_evidence_document_ids = v_evidence_ids,
      suggested_by_auth_user_id = v_actor,
      suggested_by_exact_role = v_exact_role,
      suggested_at = clock_timestamp(),
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_entry.id
  returning updated_at into v_updated_at;

  insert into public.v1_accounts_billing_progress_revisions (
    project_id, progress_entry_id, baseline_revision_id, revision_number,
    action, previous_suggested_percent, new_suggested_percent,
    previous_confirmed_percent, new_confirmed_percent,
    previous_review_status, new_review_status, evidence_summary,
    evidence_document_ids, reason, actor_auth_user_id, actor_role,
    actor_exact_role, idempotency_key, occurred_at
  ) values (
    p_project_id, v_entry.id, v_entry.baseline_revision_id,
    v_revision_number, 'suggested', v_entry.suggested_percent, v_percent,
    v_entry.confirmed_percent, v_entry.confirmed_percent,
    v_entry.review_status, v_entry.review_status,
    nullif(btrim(p_evidence_summary), ''), v_evidence_ids, v_reason,
    v_actor, v_actor_role, v_exact_role, p_idempotency_key,
    greatest(
      clock_timestamp(),
      coalesce((
        select max(revision.occurred_at) + interval '1 microsecond'
        from public.v1_accounts_billing_progress_revisions revision
        where revision.progress_entry_id = v_entry.id
      ), '-infinity'::timestamptz)
    )
  );

  perform public.v1_write_audit_event(
    'accounts_progress_suggested', 'accounts_progress', v_entry.id,
    p_project_id,
    jsonb_build_object(
      'record_version', v_entry.record_version,
      'suggested_percent', v_entry.suggested_percent::text
    ),
    jsonb_build_object(
      'record_version', v_entry.record_version + 1,
      'suggested_percent', v_percent::text,
      'evidence_document_ids', to_jsonb(v_evidence_ids)
    ),
    v_reason, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'replayed', false,
    'project_id', p_project_id,
    'entity_id', v_entry.id,
    'record_version', v_entry.record_version + 1,
    'status', v_entry.review_status,
    'updated_at', v_updated_at
  );
  perform public.v1_complete_idempotency(
    'v1_suggest_billing_progress', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_confirm_billing_progress(
  p_project_id uuid,
  p_progress_entry_id uuid,
  p_expected_version integer,
  p_confirmed_percent text,
  p_evidence_summary text,
  p_evidence_document_ids uuid[],
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_actor_role text;
  v_entry public.v1_accounts_billing_progress%rowtype;
  v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_building_percent numeric(7,4);
  v_stage_percent numeric(7,4);
  v_percent numeric(7,4);
  v_stage_value numeric(20,2);
  v_confirmed_eligible numeric(20,2);
  v_consumed numeric(20,2);
  v_review_status text;
  v_evidence_ids uuid[];
  v_reason text;
  v_payload jsonb;
  v_existing_response jsonb;
  v_revision_number integer;
  v_updated_at timestamptz;
  v_response jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'confirm_billing_progress'
  );
  v_actor_role := public.v1_current_role();
  if p_expected_version is null or p_expected_version <= 0 then
    raise exception 'R39_ACCOUNTS_EXPECTED_VERSION_REQUIRED'
      using errcode = '22023';
  end if;
  v_percent := public.v1_accounts_parse_percent_text(
    p_confirmed_percent
  )::numeric(7,4);
  if v_percent < 0 or v_percent > 100 then
    raise exception 'R39_ACCOUNTS_INVALID_PROGRESS_PERCENT'
      using errcode = '22023';
  end if;
  v_evidence_ids := public.v1_accounts_canonical_evidence_ids(
    p_evidence_document_ids
  );
  v_reason := nullif(btrim(p_reason), '');
  if v_reason is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode = '22023';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'progress_entry_id', p_progress_entry_id,
    'expected_version', p_expected_version,
    'confirmed_percent', v_percent::text,
    'evidence_summary', nullif(btrim(p_evidence_summary), ''),
    'evidence_document_ids', to_jsonb(v_evidence_ids),
    'reason', v_reason
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_confirm_billing_progress', p_idempotency_key, v_payload
  );
  if v_existing_response is not null then
    return v_existing_response || jsonb_build_object('replayed', true);
  end if;
  perform public.v1_accounts_validate_evidence_documents(
    p_project_id, v_evidence_ids
  );

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_progress|' || p_progress_entry_id::text, 0
    )
  );
  select progress.*
  into v_entry
  from public.v1_accounts_billing_progress progress
  join public.v1_accounts_project_commercial_profiles profile
    on profile.project_id = progress.project_id
   and profile.current_baseline_revision_id = progress.baseline_revision_id
   and profile.status = 'active'
  join public.v1_accounts_baseline_revisions baseline
    on baseline.id = progress.baseline_revision_id
   and baseline.status = 'current'
  join public.v1_accounts_baseline_building_allocations building
    on building.id = progress.building_allocation_id
  join public.v1_accounts_baseline_stage_allocations stage
    on stage.id = progress.stage_allocation_id
  where progress.id = p_progress_entry_id
    and progress.project_id = p_project_id
  for update of progress;
  if not found then
    raise exception 'R39_ACCOUNTS_PROGRESS_NOT_FOUND' using errcode = 'P0002';
  end if;
  select baseline.* into v_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_entry.baseline_revision_id;
  select building.allocation_percent into v_building_percent
  from public.v1_accounts_baseline_building_allocations building
  where building.id = v_entry.building_allocation_id;
  select stage.allocation_percent into v_stage_percent
  from public.v1_accounts_baseline_stage_allocations stage
  where stage.id = v_entry.stage_allocation_id;
  if v_entry.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_STALE_VERSION' using errcode = '40001';
  end if;
  if v_percent > v_entry.confirmed_percent
    and cardinality(v_evidence_ids) = 0 then
    raise exception 'R39_ACCOUNTS_CONFIRMATION_EVIDENCE_REQUIRED'
      using errcode = '22023';
  end if;

  v_stage_value := public.v1_accounts_stage_value(v_entry.id);
  v_confirmed_eligible := round(v_stage_value * v_percent / 100, 2);
  v_consumed := round(
    public.v1_accounts_consumed_claim_amount(v_entry.id), 2
  );
  if v_confirmed_eligible < v_consumed then
    raise exception 'R39_ACCOUNTS_CONFIRMED_BELOW_CLAIMED_BASIS'
      using errcode = '23514';
  end if;
  v_review_status := case
    when public.v1_accounts_review_required(
      v_baseline.management_review_policy,
      v_confirmed_eligible,
      v_exact_role
    ) then 'pending'
    else 'not_required'
  end;

  select coalesce(max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.v1_accounts_billing_progress_revisions revision
  where revision.progress_entry_id = v_entry.id;

  update public.v1_accounts_billing_progress
  set confirmed_percent = v_percent,
      confirmed_evidence_summary = nullif(btrim(p_evidence_summary), ''),
      confirmed_evidence_document_ids = v_evidence_ids,
      confirmed_by_auth_user_id = v_actor,
      confirmed_by_exact_role = v_exact_role,
      confirmed_at = clock_timestamp(),
      review_status = v_review_status,
      reviewed_by_auth_user_id = null,
      reviewed_by_exact_role = null,
      reviewed_at = null,
      review_reason = null,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_entry.id
  returning updated_at into v_updated_at;

  insert into public.v1_accounts_billing_progress_revisions (
    project_id, progress_entry_id, baseline_revision_id, revision_number,
    action, previous_suggested_percent, new_suggested_percent,
    previous_confirmed_percent, new_confirmed_percent,
    previous_review_status, new_review_status, evidence_summary,
    evidence_document_ids, reason, actor_auth_user_id, actor_role,
    actor_exact_role, idempotency_key, occurred_at
  ) values (
    p_project_id, v_entry.id, v_entry.baseline_revision_id,
    v_revision_number, 'confirmed', v_entry.suggested_percent,
    v_entry.suggested_percent, v_entry.confirmed_percent, v_percent,
    v_entry.review_status, v_review_status,
    nullif(btrim(p_evidence_summary), ''), v_evidence_ids, v_reason,
    v_actor, v_actor_role, v_exact_role, p_idempotency_key,
    greatest(
      clock_timestamp(),
      coalesce((
        select max(revision.occurred_at) + interval '1 microsecond'
        from public.v1_accounts_billing_progress_revisions revision
        where revision.progress_entry_id = v_entry.id
      ), '-infinity'::timestamptz)
    )
  );

  perform public.v1_write_audit_event(
    'accounts_progress_confirmed', 'accounts_progress', v_entry.id,
    p_project_id,
    jsonb_build_object(
      'record_version', v_entry.record_version,
      'confirmed_percent', v_entry.confirmed_percent::text,
      'confirmed_eligible', round(
        v_stage_value * v_entry.confirmed_percent / 100, 2
      )::text,
      'review_status', v_entry.review_status
    ),
    jsonb_build_object(
      'record_version', v_entry.record_version + 1,
      'confirmed_percent', v_percent::text,
      'confirmed_eligible', v_confirmed_eligible::text,
      'review_status', v_review_status,
      'evidence_document_ids', to_jsonb(v_evidence_ids)
    ),
    v_reason, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'replayed', false,
    'project_id', p_project_id,
    'entity_id', v_entry.id,
    'record_version', v_entry.record_version + 1,
    'status', v_review_status,
    'updated_at', v_updated_at
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_billing_progress', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_review_commercial_progress(
  p_project_id uuid,
  p_progress_entry_id uuid,
  p_expected_version integer,
  p_decision text,
  p_reason text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_actor_role text;
  v_entry public.v1_accounts_billing_progress%rowtype;
  v_decision text := lower(btrim(p_decision));
  v_reason text;
  v_payload jsonb;
  v_existing_response jsonb;
  v_revision_number integer;
  v_updated_at timestamptz;
  v_response jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'review_commercial_progress'
  );
  v_actor_role := public.v1_current_role();
  if p_expected_version is null or p_expected_version <= 0 then
    raise exception 'R39_ACCOUNTS_EXPECTED_VERSION_REQUIRED'
      using errcode = '22023';
  end if;
  if v_decision not in ('approved', 'returned') then
    raise exception 'R39_ACCOUNTS_REVIEW_DECISION_INVALID'
      using errcode = '22023';
  end if;
  v_reason := nullif(btrim(p_reason), '');
  if v_reason is null then
    raise exception 'R39_ACCOUNTS_REASON_REQUIRED' using errcode = '22023';
  end if;
  v_payload := jsonb_build_object(
    'project_id', p_project_id,
    'progress_entry_id', p_progress_entry_id,
    'expected_version', p_expected_version,
    'decision', v_decision,
    'reason', v_reason
  );
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_review_commercial_progress', p_idempotency_key, v_payload
  );
  if v_existing_response is not null then
    return v_existing_response || jsonb_build_object('replayed', true);
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'r39_accounts_progress|' || p_progress_entry_id::text, 0
    )
  );
  select progress.* into v_entry
  from public.v1_accounts_billing_progress progress
  join public.v1_accounts_project_commercial_profiles profile
    on profile.project_id = progress.project_id
   and profile.current_baseline_revision_id = progress.baseline_revision_id
   and profile.status = 'active'
  where progress.id = p_progress_entry_id
    and progress.project_id = p_project_id
  for update of progress;
  if not found then
    raise exception 'R39_ACCOUNTS_PROGRESS_NOT_FOUND' using errcode = 'P0002';
  end if;
  if v_entry.record_version <> p_expected_version then
    raise exception 'R39_ACCOUNTS_STALE_VERSION' using errcode = '40001';
  end if;
  if v_entry.review_status <> 'pending' then
    raise exception 'R39_ACCOUNTS_REVIEW_NOT_PENDING'
      using errcode = '23514';
  end if;

  select coalesce(max(revision.revision_number), 0) + 1
  into v_revision_number
  from public.v1_accounts_billing_progress_revisions revision
  where revision.progress_entry_id = v_entry.id;

  update public.v1_accounts_billing_progress
  set review_status = v_decision,
      reviewed_by_auth_user_id = v_actor,
      reviewed_by_exact_role = v_exact_role,
      reviewed_at = clock_timestamp(),
      review_reason = v_reason,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_entry.id
  returning updated_at into v_updated_at;

  insert into public.v1_accounts_billing_progress_revisions (
    project_id, progress_entry_id, baseline_revision_id, revision_number,
    action, previous_suggested_percent, new_suggested_percent,
    previous_confirmed_percent, new_confirmed_percent,
    previous_review_status, new_review_status, evidence_summary,
    evidence_document_ids, reason, actor_auth_user_id, actor_role,
    actor_exact_role, idempotency_key, occurred_at
  ) values (
    p_project_id, v_entry.id, v_entry.baseline_revision_id,
    v_revision_number, 'reviewed', v_entry.suggested_percent,
    v_entry.suggested_percent, v_entry.confirmed_percent,
    v_entry.confirmed_percent, v_entry.review_status, v_decision,
    null, '{}'::uuid[], v_reason, v_actor, v_actor_role, v_exact_role,
    p_idempotency_key,
    greatest(
      clock_timestamp(),
      coalesce((
        select max(revision.occurred_at) + interval '1 microsecond'
        from public.v1_accounts_billing_progress_revisions revision
        where revision.progress_entry_id = v_entry.id
      ), '-infinity'::timestamptz)
    )
  );

  perform public.v1_write_audit_event(
    'accounts_progress_reviewed', 'accounts_progress', v_entry.id,
    p_project_id,
    jsonb_build_object(
      'record_version', v_entry.record_version,
      'review_status', v_entry.review_status
    ),
    jsonb_build_object(
      'record_version', v_entry.record_version + 1,
      'review_status', v_decision,
      'reviewed_by_exact_role', v_exact_role
    ),
    v_reason, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'replayed', false,
    'project_id', p_project_id,
    'entity_id', v_entry.id,
    'record_version', v_entry.record_version + 1,
    'status', v_decision,
    'updated_at', v_updated_at
  );
  perform public.v1_complete_idempotency(
    'v1_review_commercial_progress', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_accounts_capability_envelope(
  p_project_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'can_view', public.v1_current_user_has_capability(
      'view_project_accounts', p_project_id
    ),
    'can_view_values', public.v1_current_user_has_capability(
      'view_project_commercial_values', p_project_id
    ),
    'can_configure', public.v1_current_user_has_capability(
      'configure_project_commercials', p_project_id
    ),
    'can_suggest', public.v1_current_user_has_capability(
      'suggest_billing_progress', p_project_id
    ),
    'can_confirm', public.v1_current_user_has_capability(
      'confirm_billing_progress', p_project_id
    ),
    'can_review', public.v1_current_user_has_capability(
      'review_commercial_progress', p_project_id
    )
  );
$$;

create or replace function public.v1_accounts_baseline_snapshot(
  p_baseline_revision_id uuid,
  p_include_values boolean
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_snapshot jsonb;
  v_buildings jsonb;
  v_stages jsonb;
begin
  select baseline.* into v_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = p_baseline_revision_id;
  if not found then return null; end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'allocation_id', allocation.id,
      'building_scope_id', allocation.project_scope_id,
      'building_name', scope.name,
      'allocation_percent', allocation.allocation_percent::text
    ) || case when p_include_values then jsonb_build_object(
      'allocated_value', round(
        v_baseline.contract_value * allocation.allocation_percent / 100, 2
      )::text
    ) else '{}'::jsonb end
    order by scope.scope_code, allocation.id
  ), '[]'::jsonb)
  into v_buildings
  from public.v1_accounts_baseline_building_allocations allocation
  join public.v1_project_scopes scope
    on scope.id = allocation.project_scope_id
  where allocation.baseline_revision_id = v_baseline.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'allocation_id', allocation.id,
      'stage_key', allocation.stage_key,
      'stage_label', allocation.stage_name,
      'position', allocation.display_order,
      'allocation_percent', allocation.allocation_percent::text
    ) || case when p_include_values then jsonb_build_object(
      'stage_value', round(
        v_baseline.contract_value * allocation.allocation_percent / 100, 2
      )::text
    ) else '{}'::jsonb end
    order by allocation.display_order
  ), '[]'::jsonb)
  into v_stages
  from public.v1_accounts_baseline_stage_allocations allocation
  where allocation.baseline_revision_id = v_baseline.id;

  v_snapshot := jsonb_build_object(
    'revision_id', v_baseline.id,
    'revision_number', v_baseline.revision_number,
    'record_version', v_baseline.revision_number,
    'status', v_baseline.status,
    'reason', v_baseline.reason,
    'created_at', v_baseline.effective_at,
    'created_by', v_baseline.approved_by_auth_user_id::text,
    'approved_by_auth_user_id', v_baseline.approved_by_auth_user_id::text,
    'approved_by_role', v_baseline.approved_by_role,
    'approved_by_exact_role', v_baseline.approved_by_exact_role,
    'building_allocations', v_buildings,
    'stage_allocations', v_stages
  );
  if p_include_values then
    v_snapshot := v_snapshot || jsonb_build_object(
      'contract_value', v_baseline.contract_value::text,
      'currency_code', v_baseline.currency_code,
      'vat_rate', v_baseline.vat_rate_percent::text,
      'payment_terms_days', v_baseline.payment_terms_days,
      'reminder_lead_days', v_baseline.reminder_lead_days,
      'management_review_policy', v_baseline.management_review_policy
    );
  end if;
  return v_snapshot;
end;
$$;

create or replace function public.v1_get_project_commercial_baseline(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text;
  v_capabilities jsonb;
  v_can_values boolean;
  v_can_configure boolean;
  v_profile public.v1_accounts_project_commercial_profiles%rowtype;
  v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_baseline_json jsonb;
  v_physical_buildings jsonb := '[]'::jsonb;
  v_stage_templates jsonb := '[]'::jsonb;
  v_buildings jsonb := '[]'::jsonb;
  v_stages jsonb := '[]'::jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'view_project_accounts'
  );
  v_capabilities := public.v1_accounts_capability_envelope(p_project_id);
  v_can_values := (v_capabilities ->> 'can_view_values')::boolean;
  v_can_configure := (v_capabilities ->> 'can_configure')::boolean;

  select coalesce(jsonb_agg(jsonb_build_object(
    'building_scope_id', scope.id,
    'building_name', scope.name,
    'scope_code', scope.scope_code
  ) order by scope.scope_code, scope.name), '[]'::jsonb)
  into v_physical_buildings
  from public.v1_project_scopes scope
  where scope.project_id = p_project_id
    and scope.scope_kind = 'building'
    and scope.is_active;

  select coalesce(jsonb_agg(jsonb_build_object(
    'stage_key', stage.stage_key,
    'stage_label', stage.stage_name,
    'allocation_percent', stage.allocation_percent::text,
    'position', stage.display_order
  ) order by stage.display_order), '[]'::jsonb)
  into v_stage_templates
  from public.v1_accounts_billing_stage_templates stage
  where stage.is_active;

  select profile.* into v_profile
  from public.v1_accounts_project_commercial_profiles profile
  where profile.project_id = p_project_id;
  if not found then
    return jsonb_build_object(
      'schema_version', 2,
      'project_id', p_project_id,
      'baseline', null,
      'physical_buildings', v_physical_buildings,
      'stage_templates', v_stage_templates,
      'building_allocations', '[]'::jsonb,
      'stage_allocations', '[]'::jsonb,
      'capabilities', v_capabilities,
      'commands', jsonb_build_object(
        'initialize_baseline', v_can_configure,
        'revise_baseline', false,
        'suggest_progress', false,
        'confirm_progress', false,
        'review_progress', false
      )
    );
  end if;

  select baseline.* into strict v_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_profile.current_baseline_revision_id
    and baseline.status = 'current';
  v_baseline_json := jsonb_build_object(
    'revision_id', v_baseline.id,
    'revision_number', v_baseline.revision_number,
    'record_version', v_profile.record_version,
    'status', v_baseline.status,
    'reason', v_baseline.reason,
    'created_at', v_baseline.effective_at,
    'created_by', v_baseline.approved_by_auth_user_id::text,
    'approved_by_auth_user_id', v_baseline.approved_by_auth_user_id::text,
    'approved_by_role', v_baseline.approved_by_role,
    'approved_by_exact_role', v_baseline.approved_by_exact_role
  );
  if v_can_values then
    v_baseline_json := v_baseline_json || jsonb_build_object(
      'contract_value', v_baseline.contract_value::text,
      'currency_code', v_baseline.currency_code,
      'vat_rate', v_baseline.vat_rate_percent::text,
      'payment_terms_days', v_baseline.payment_terms_days,
      'reminder_lead_days', v_baseline.reminder_lead_days,
      'management_review_policy', v_baseline.management_review_policy
    );
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'allocation_id', allocation.id,
      'building_scope_id', allocation.project_scope_id,
      'building_name', scope.name,
      'allocation_percent', allocation.allocation_percent::text
    ) || case when v_can_values then jsonb_build_object(
      'allocated_value', round(
        v_baseline.contract_value * allocation.allocation_percent / 100, 2
      )::text
    ) else '{}'::jsonb end
    order by scope.scope_code, scope.name
  ), '[]'::jsonb)
  into v_buildings
  from public.v1_accounts_baseline_building_allocations allocation
  join public.v1_project_scopes scope on scope.id = allocation.project_scope_id
  where allocation.baseline_revision_id = v_baseline.id;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'allocation_id', allocation.id,
      'stage_key', allocation.stage_key,
      'stage_label', allocation.stage_name,
      'position', allocation.display_order,
      'allocation_percent', allocation.allocation_percent::text
    ) || case when v_can_values then jsonb_build_object(
      'stage_value', round(
        v_baseline.contract_value * allocation.allocation_percent / 100, 2
      )::text
    ) else '{}'::jsonb end
    order by allocation.display_order
  ), '[]'::jsonb)
  into v_stages
  from public.v1_accounts_baseline_stage_allocations allocation
  where allocation.baseline_revision_id = v_baseline.id;

  return jsonb_build_object(
    'schema_version', 2,
    'project_id', p_project_id,
    'baseline', v_baseline_json,
    'physical_buildings', v_physical_buildings,
    'stage_templates', v_stage_templates,
    'building_allocations', v_buildings,
    'stage_allocations', v_stages,
    'capabilities', v_capabilities,
    'commands', jsonb_build_object(
      'initialize_baseline', false,
      'revise_baseline', v_can_configure,
      'suggest_progress', (v_capabilities ->> 'can_suggest')::boolean,
      'confirm_progress', (v_capabilities ->> 'can_confirm')::boolean,
      'review_progress', (v_capabilities ->> 'can_review')::boolean
    )
  );
exception when no_data_found then
  raise exception 'R39_ACCOUNTS_BASELINE_NOT_FOUND' using errcode = 'P0002';
end;
$$;

create or replace function public.v1_get_accounts_foundation(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
  v_result jsonb;
begin
  if v_actor is null or p_project_id is null
    or not public.v1_current_actor_is_active() then
    raise exception 'R39_ACCOUNTS_FOUNDATION_ACCESS_DENIED'
      using errcode = '42501';
  end if;
  v_exact_role := public.v1_permission_exact_role(v_actor);
  if v_exact_role = '' or not public.v1_current_user_has_capability(
    'view_project_accounts', p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_FOUNDATION_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  select jsonb_build_object(
    'schema_version', 2,
    'foundation_ready', true,
    'consumers_enabled', true,
    'enabled_consumers', to_jsonb(array[
      'view_project_accounts', 'view_project_commercial_values',
      'suggest_billing_progress', 'confirm_billing_progress',
      'configure_project_commercials', 'review_commercial_progress'
    ]::text[]),
    'project_id', p_project_id,
    'defaults', jsonb_build_object(
      'payment_terms_days', settings.default_payment_terms_days,
      'reminder_lead_days', settings.default_reminder_lead_days,
      'common_scope_is_physical', settings.common_scope_is_physical
    ),
    'billing_stages', (
      select jsonb_agg(jsonb_build_object(
        'stage_key', stage.stage_key,
        'stage_label', stage.stage_name,
        'allocation_percent', stage.allocation_percent::text,
        'position', stage.display_order
      ) order by stage.display_order)
      from public.v1_accounts_billing_stage_templates stage
      where stage.is_active
    ),
    'capabilities', (
      select jsonb_object_agg(
        catalog.capability_key,
        jsonb_build_object(
          'template_granted', coalesce(role_default.is_granted, false),
          'has_project_scope', public.v1_accounts_has_project_scope(
            v_actor, p_project_id, catalog.capability_key
          ),
          'command_enabled', catalog.status = 'operational'
            and catalog.authorization_mode = 'enforced'
            and catalog.is_assignable
            and public.v1_current_user_has_capability(
              catalog.capability_key, p_project_id
            ),
          'runtime_status', catalog.status
        ) order by catalog.display_order
      )
      from public.v1_capability_catalog catalog
      left join public.v1_permission_role_defaults role_default
        on role_default.role_name = v_exact_role
       and role_default.capability_key = catalog.capability_key
      where public.v1_accounts_is_capability_key(catalog.capability_key)
    )
  ) into v_result
  from public.v1_accounts_foundation_settings settings
  where settings.singleton;
  return v_result;
end;
$$;

-- Internal helpers and extension seams are never callable through PostgREST.
revoke all on function public.v1_accounts_parse_money_text(text)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_parse_percent_text(text)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_normalize_review_policy(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_canonical_building_allocations(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_canonical_stage_allocations(jsonb)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_canonical_evidence_ids(uuid[])
  from public, anon, authenticated;
revoke all on function public.v1_accounts_require_capability(uuid,text)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_evidence_documents(uuid,uuid[])
  from public, anon, authenticated;
revoke all on function public.v1_accounts_review_required(jsonb,numeric,text)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_consumed_claim_amount(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_mark_claim_drafts_stale(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_building_allocation_row()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_stage_allocation_row()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_progress_dimension_row()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_validate_baseline_totals()
  from public, anon, authenticated;
revoke all on function public.v1_accounts_materialize_baseline_dimensions(
  uuid,uuid,jsonb,jsonb
) from public, anon, authenticated;
revoke all on function public.v1_accounts_stage_value(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_capability_envelope(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_accounts_baseline_snapshot(uuid,boolean)
  from public, anon, authenticated;

revoke all on function public.v1_initialize_project_commercial_baseline(
  uuid,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid
) from public, anon;
grant execute on function public.v1_initialize_project_commercial_baseline(
  uuid,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid
) to authenticated, service_role;
revoke all on function public.v1_revise_project_commercial_baseline(
  uuid,integer,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid
) from public, anon;
grant execute on function public.v1_revise_project_commercial_baseline(
  uuid,integer,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid
) to authenticated, service_role;
revoke all on function public.v1_suggest_billing_progress(
  uuid,uuid,integer,text,text,uuid[],text,uuid
) from public, anon;
grant execute on function public.v1_suggest_billing_progress(
  uuid,uuid,integer,text,text,uuid[],text,uuid
) to authenticated, service_role;
revoke all on function public.v1_confirm_billing_progress(
  uuid,uuid,integer,text,text,uuid[],text,uuid
) from public, anon;
grant execute on function public.v1_confirm_billing_progress(
  uuid,uuid,integer,text,text,uuid[],text,uuid
) to authenticated, service_role;
revoke all on function public.v1_review_commercial_progress(
  uuid,uuid,integer,text,text,uuid
) from public, anon;
grant execute on function public.v1_review_commercial_progress(
  uuid,uuid,integer,text,text,uuid
) to authenticated, service_role;

revoke all on function public.v1_get_project_commercial_baseline(uuid)
  from public, anon;
grant execute on function public.v1_get_project_commercial_baseline(uuid)
  to authenticated, service_role;
revoke all on function public.v1_get_accounts_foundation(uuid)
  from public, anon;
grant execute on function public.v1_get_accounts_foundation(uuid)
  to authenticated, service_role;

create or replace function public.v1_list_project_commercial_baseline_revisions(
  p_project_id uuid,
  p_before_revision_number integer,
  p_limit integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text;
  v_capabilities jsonb;
  v_can_values boolean;
  v_revisions jsonb;
  v_has_more boolean;
  v_next_cursor integer;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'view_project_accounts'
  );
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'R39_ACCOUNTS_LIMIT_INVALID' using errcode = '22023';
  end if;
  if p_before_revision_number is not null
    and p_before_revision_number <= 0 then
    raise exception 'R39_ACCOUNTS_CURSOR_INVALID' using errcode = '22023';
  end if;
  v_capabilities := public.v1_accounts_capability_envelope(p_project_id);
  v_can_values := (v_capabilities ->> 'can_view_values')::boolean;
  with bounded as (
    select baseline.revision_number,
      public.v1_accounts_baseline_snapshot(
        baseline.id, v_can_values
      ) || jsonb_build_object(
        'superseded_at', baseline.superseded_at,
        'superseded_by_revision_id', baseline.superseded_by_revision_id,
        'before', case when previous.id is null then null
          else public.v1_accounts_baseline_snapshot(
            previous.id, v_can_values
          ) end,
        'after', public.v1_accounts_baseline_snapshot(
          baseline.id, v_can_values
        )
      ) as revision_json
    from public.v1_accounts_baseline_revisions baseline
    left join public.v1_accounts_baseline_revisions previous
      on previous.project_id = baseline.project_id
     and previous.revision_number = baseline.revision_number - 1
    where baseline.project_id = p_project_id
      and (p_before_revision_number is null
        or baseline.revision_number < p_before_revision_number)
    order by baseline.revision_number desc
    limit p_limit + 1
  ), marked as (
    select bounded.*,
      row_number() over (order by revision_number desc) as page_row,
      count(*) over () as bounded_count
    from bounded
  )
  select coalesce(jsonb_agg(
           revision_json order by revision_number desc
         ) filter (where page_row <= p_limit), '[]'::jsonb),
         coalesce(max(bounded_count), 0) > p_limit,
         min(revision_number) filter (where page_row <= p_limit)
  into v_revisions, v_has_more, v_next_cursor
  from marked;
  if not v_has_more then v_next_cursor := null; end if;
  return jsonb_build_object(
    'schema_version', 2,
    'project_id', p_project_id,
    'revisions', v_revisions,
    'next_cursor', v_next_cursor,
    'capabilities', v_capabilities
  );
end;
$$;

-- Compatibility first-page seam. New consumers use the three-argument cursor
-- form; existing T02 callers continue to receive the first bounded page.
create or replace function public.v1_list_project_commercial_baseline_revisions(
  p_project_id uuid,
  p_limit integer default 50
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_list_project_commercial_baseline_revisions(
    p_project_id, null, p_limit
  );
$$;

create or replace function public.v1_list_billing_progress_revisions(
  p_project_id uuid,
  p_progress_entry_id uuid,
  p_before_revision_number integer default null,
  p_limit integer default 50
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text;
  v_capabilities jsonb;
  v_revisions jsonb;
  v_next_cursor integer;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'view_project_accounts'
  );
  if p_limit is null or p_limit < 1 or p_limit > 100 then
    raise exception 'R39_ACCOUNTS_LIMIT_INVALID' using errcode = '22023';
  end if;
  if p_before_revision_number is not null
    and p_before_revision_number <= 0 then
    raise exception 'R39_ACCOUNTS_CURSOR_INVALID' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.v1_accounts_billing_progress progress
    where progress.id = p_progress_entry_id
      and progress.project_id = p_project_id
  ) then
    raise exception 'R39_ACCOUNTS_PROGRESS_NOT_FOUND' using errcode = 'P0002';
  end if;
  v_capabilities := public.v1_accounts_capability_envelope(p_project_id);
  with bounded as (
    select revision.*
    from public.v1_accounts_billing_progress_revisions revision
    where revision.project_id = p_project_id
      and revision.progress_entry_id = p_progress_entry_id
      and (p_before_revision_number is null
        or revision.revision_number < p_before_revision_number)
    order by revision.revision_number desc
    limit p_limit + 1
  ), page as (
    select * from bounded
    order by revision_number desc
    limit p_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'revision_id', page.id,
           'revision_number', page.revision_number,
           'action', page.action,
           'previous_suggested_percent', page.previous_suggested_percent::text,
           'new_suggested_percent', page.new_suggested_percent::text,
           'previous_confirmed_percent', page.previous_confirmed_percent::text,
           'new_confirmed_percent', page.new_confirmed_percent::text,
           'previous_review_status', page.previous_review_status,
           'new_review_status', page.new_review_status,
           'evidence_summary', page.evidence_summary,
           'evidence_document_ids', to_jsonb(page.evidence_document_ids),
           'reason', page.reason,
           'actor_auth_user_id', page.actor_auth_user_id::text,
           'actor_role', page.actor_role,
           'actor_exact_role', page.actor_exact_role,
           'occurred_at', page.occurred_at
         ) order by page.revision_number desc), '[]'::jsonb),
         case when (select count(*) from bounded) > p_limit
           then min(page.revision_number) else null end
  into v_revisions, v_next_cursor
  from page;
  return jsonb_build_object(
    'schema_version', 2,
    'project_id', p_project_id,
    'progress_entry_id', p_progress_entry_id,
    'revisions', v_revisions,
    'next_cursor', v_next_cursor,
    'capabilities', v_capabilities
  );
end;
$$;

create or replace function public.v1_list_billing_progress(
  p_project_id uuid,
  p_building_scope_id uuid default null,
  p_stage_key text default null,
  p_action_owner text default null,
  p_has_evidence boolean default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text;
  v_capabilities jsonb;
  v_can_values boolean;
  v_can_suggest boolean;
  v_can_confirm boolean;
  v_can_review boolean;
  v_profile public.v1_accounts_project_commercial_profiles%rowtype;
  v_baseline public.v1_accounts_baseline_revisions%rowtype;
  v_row record;
  v_rows jsonb := '[]'::jsonb;
  v_revisions jsonb;
  v_row_actions jsonb;
  v_top_actions jsonb := '[]'::jsonb;
  v_row_json jsonb;
  v_evidence_summary text;
  v_evidence_ids uuid[];
  v_action_owner text;
  v_stage_value numeric(20,2);
  v_confirmed_eligible numeric(20,2);
  v_consumed numeric(20,2);
  v_total_confirmed_eligible numeric(20,2) := 0;
  v_total_consumed numeric(20,2) := 0;
  v_commercial_progress numeric(9,4) := 0;
  v_totals jsonb;
begin
  v_exact_role := public.v1_accounts_require_capability(
    p_project_id, 'view_project_accounts'
  );
  if p_action_owner is not null and p_action_owner not in (
    'site_engineer', 'project_engineer', 'management'
  ) then
    raise exception 'R39_ACCOUNTS_ACTION_OWNER_FILTER_INVALID'
      using errcode = '22023';
  end if;
  v_capabilities := public.v1_accounts_capability_envelope(p_project_id);
  v_can_values := (v_capabilities ->> 'can_view_values')::boolean;
  v_can_suggest := (v_capabilities ->> 'can_suggest')::boolean;
  v_can_confirm := (v_capabilities ->> 'can_confirm')::boolean;
  v_can_review := (v_capabilities ->> 'can_review')::boolean;

  select profile.* into v_profile
  from public.v1_accounts_project_commercial_profiles profile
  where profile.project_id = p_project_id
    and profile.status = 'active';
  if not found then
    return jsonb_build_object(
      'schema_version', 2,
      'project_id', p_project_id,
      'baseline_revision_id', null,
      'baseline_revision_number', null,
      'progress', '[]'::jsonb,
      'totals', null,
      'capabilities', v_capabilities,
      'commands', jsonb_build_object(
        'suggest_progress', false,
        'confirm_progress', false,
        'review_progress', false
      ),
      'next_actions', '[]'::jsonb
    );
  end if;
  select baseline.* into strict v_baseline
  from public.v1_accounts_baseline_revisions baseline
  where baseline.id = v_profile.current_baseline_revision_id
    and baseline.status = 'current';

  for v_row in
    select progress.*, scope.name as building_name,
           building.allocation_percent as building_percent,
           stage.stage_name as stage_label,
           stage.display_order as stage_position,
           stage.allocation_percent as stage_percent
    from public.v1_accounts_billing_progress progress
    join public.v1_project_scopes scope
      on scope.id = progress.project_scope_id
    join public.v1_accounts_baseline_building_allocations building
      on building.id = progress.building_allocation_id
    join public.v1_accounts_baseline_stage_allocations stage
      on stage.id = progress.stage_allocation_id
    where progress.project_id = p_project_id
      and progress.baseline_revision_id = v_baseline.id
      and (p_building_scope_id is null
        or progress.project_scope_id = p_building_scope_id)
      and (nullif(btrim(p_stage_key), '') is null
        or progress.stage_key = btrim(p_stage_key))
    order by scope.scope_code, stage.display_order
  loop
    -- Evidence context is atomic. Once a confirmation exists, its summary and
    -- IDs are the only current evidence set; never synthesize a display record
    -- from a confirmation summary and an older suggestion's document IDs.
    if v_row.confirmed_by_auth_user_id is not null then
      v_evidence_summary := v_row.confirmed_evidence_summary;
      v_evidence_ids := v_row.confirmed_evidence_document_ids;
    else
      v_evidence_summary := v_row.suggested_evidence_summary;
      v_evidence_ids := v_row.suggested_evidence_document_ids;
    end if;
    v_action_owner := case
      when v_row.review_status = 'pending' then 'management'
      when v_row.review_status = 'returned' then 'project_engineer'
      when v_row.suggested_percent <> v_row.confirmed_percent
        then 'project_engineer'
      else 'site_engineer'
    end;
    if p_action_owner is not null and v_action_owner <> p_action_owner then
      continue;
    end if;
    if p_has_evidence is not null and p_has_evidence <>
      (cardinality(v_evidence_ids) > 0
        or nullif(btrim(v_evidence_summary), '') is not null) then
      continue;
    end if;

    select coalesce(jsonb_agg(jsonb_build_object(
      'revision_number', revision.revision_number,
      'action', revision.action,
      'suggested_percent', revision.new_suggested_percent::text,
      'confirmed_percent', revision.new_confirmed_percent::text,
      'reason', revision.reason,
      'actor_auth_user_id', revision.actor_auth_user_id::text,
      'created_at', revision.occurred_at
    ) order by revision.revision_number), '[]'::jsonb)
    into v_revisions
    from public.v1_accounts_billing_progress_revisions revision
    where revision.progress_entry_id = v_row.id;

    v_row_actions := '[]'::jsonb;
    if v_can_suggest then
      v_row_actions := v_row_actions || jsonb_build_array(
        jsonb_build_object(
          'code', 'suggest_progress', 'entity_id', v_row.id,
          'owner_role', 'site_engineer', 'blocking_reason_code', null,
          'is_available', true
        )
      );
    end if;
    if v_can_confirm then
      v_row_actions := v_row_actions || jsonb_build_array(
        jsonb_build_object(
          'code', 'confirm_progress', 'entity_id', v_row.id,
          'owner_role', 'project_engineer',
          'blocking_reason_code', case
            when v_row.suggested_percent > v_row.confirmed_percent
              and cardinality(v_row.suggested_evidence_document_ids) = 0
              then 'authorized_evidence_required_for_increase'
            else null
          end,
          'is_available', true
        )
      );
    end if;
    if v_row.review_status = 'pending' then
      v_row_actions := v_row_actions || jsonb_build_array(
        jsonb_build_object(
          'code', 'review_progress', 'entity_id', v_row.id,
          'owner_role', 'management',
          'blocking_reason_code', case when v_can_review then null
            else 'authorized_management_review_required' end,
          'is_available', v_can_review
        )
      );
    end if;

    v_stage_value := public.v1_accounts_stage_value(v_row.id);
    v_confirmed_eligible := round(
      v_stage_value * v_row.confirmed_percent / 100, 2
    );
    v_consumed := round(
      public.v1_accounts_consumed_claim_amount(v_row.id), 2
    );
    v_row_json := jsonb_build_object(
      'progress_entry_id', v_row.id,
      'project_id', p_project_id,
      'baseline_revision_id', v_baseline.id,
      'building_scope_id', v_row.project_scope_id,
      'building_name', v_row.building_name,
      'stage_key', v_row.stage_key,
      'stage_label', v_row.stage_label,
      'stage_position', v_row.stage_position,
      'record_version', v_row.record_version,
      'suggested_percent', v_row.suggested_percent::text,
      'confirmed_percent', v_row.confirmed_percent::text,
      'review_status', v_row.review_status,
      'evidence_summary', v_evidence_summary,
      'evidence_document_ids', to_jsonb(v_evidence_ids),
      'action_owner', v_action_owner,
      'revisions', v_revisions,
      'next_actions', v_row_actions,
      'updated_at', v_row.updated_at
    );
    if v_can_values then
      v_row_json := v_row_json || jsonb_build_object(
        'stage_value', v_stage_value::text,
        'confirmed_eligible', v_confirmed_eligible::text,
        'previously_claimed_amount', v_consumed::text,
        'available_to_claim', greatest(
          v_confirmed_eligible - v_consumed, 0
        )::text
      );
    end if;
    v_rows := v_rows || jsonb_build_array(v_row_json);
  end loop;

  -- Totals always describe the whole active baseline. Register filters only
  -- shape the returned rows and never change commercial calculations.
  select coalesce(sum(round(
           public.v1_accounts_stage_value(progress.id)
             * progress.confirmed_percent / 100,
           2
         )), 0),
         coalesce(sum(public.v1_accounts_consumed_claim_amount(progress.id)), 0)
  into v_total_confirmed_eligible, v_total_consumed
  from public.v1_accounts_billing_progress progress
  join public.v1_accounts_baseline_building_allocations building
    on building.id = progress.building_allocation_id
  join public.v1_accounts_baseline_stage_allocations stage
    on stage.id = progress.stage_allocation_id
  where progress.project_id = p_project_id
    and progress.baseline_revision_id = v_baseline.id;

  v_commercial_progress := case when v_baseline.contract_value = 0 then 0
    else round(v_total_confirmed_eligible / v_baseline.contract_value * 100, 4)
  end;
  v_totals := jsonb_build_object(
    'confirmed_percent', v_commercial_progress::text
  );
  if v_can_values then
    v_totals := v_totals || jsonb_build_object(
      'contract_value', v_baseline.contract_value::text,
      'confirmed_eligible', v_total_confirmed_eligible::text,
      'available_to_claim', greatest(
        v_total_confirmed_eligible - v_total_consumed, 0
      )::text
    );
  end if;
  if v_can_suggest then
    v_top_actions := v_top_actions || jsonb_build_array(jsonb_build_object(
      'code', 'suggest_progress', 'entity_id', null,
      'owner_role', 'site_engineer', 'blocking_reason_code', null,
      'is_available', true
    ));
  end if;
  if v_can_confirm then
    v_top_actions := v_top_actions || jsonb_build_array(jsonb_build_object(
      'code', 'confirm_progress', 'entity_id', null,
      'owner_role', 'project_engineer', 'blocking_reason_code', null,
      'is_available', true
    ));
  end if;
  if exists (
    select 1 from public.v1_accounts_billing_progress pending
    where pending.project_id = p_project_id
      and pending.baseline_revision_id = v_baseline.id
      and pending.review_status = 'pending'
  ) then
    v_top_actions := v_top_actions || jsonb_build_array(jsonb_build_object(
      'code', 'review_progress', 'entity_id', null,
      'owner_role', 'management',
      'blocking_reason_code', case when v_can_review then null
        else 'authorized_management_review_required' end,
      'is_available', v_can_review
    ));
  end if;

  return jsonb_build_object(
    'schema_version', 2,
    'project_id', p_project_id,
    'baseline_revision_id', v_baseline.id,
    'baseline_revision_number', v_baseline.revision_number,
    'progress', v_rows,
    'totals', v_totals,
    'capabilities', v_capabilities,
    'commands', jsonb_build_object(
      'suggest_progress', v_can_suggest,
      'confirm_progress', v_can_confirm,
      'review_progress', v_can_review
    ),
    'next_actions', v_top_actions
  );
exception when no_data_found then
  raise exception 'R39_ACCOUNTS_BASELINE_NOT_FOUND' using errcode = 'P0002';
end;
$$;

-- Projection grants are applied only after every overload exists.
revoke all on function public.v1_list_project_commercial_baseline_revisions(
  uuid,integer
) from public, anon;
grant execute on function public.v1_list_project_commercial_baseline_revisions(
  uuid,integer
) to authenticated, service_role;
revoke all on function public.v1_list_project_commercial_baseline_revisions(
  uuid,integer,integer
) from public, anon;
grant execute on function public.v1_list_project_commercial_baseline_revisions(
  uuid,integer,integer
) to authenticated, service_role;
revoke all on function public.v1_list_billing_progress(
  uuid,uuid,text,text,boolean
) from public, anon;
grant execute on function public.v1_list_billing_progress(
  uuid,uuid,text,text,boolean
) to authenticated, service_role;
revoke all on function public.v1_list_billing_progress_revisions(
  uuid,uuid,integer,integer
) from public, anon;
grant execute on function public.v1_list_billing_progress_revisions(
  uuid,uuid,integer,integer
) to authenticated, service_role;

commit;
