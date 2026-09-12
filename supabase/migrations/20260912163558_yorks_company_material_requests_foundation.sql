-- Yorks V1 Company Material Requests T01: protected draft and submission lane.
--
-- This is deliberately separate from v1_material_requests. A company need is
-- not a project Common scope, has no BOQ source, and must never acquire
-- project access through a nullable project_id. This first vertical slice
-- records only private drafts and the independently-routed company approval
-- handoff. Supply, dispatch, receipt, issue and return remain later slices.
--
-- Data preservation: no existing project request, stock, document, workforce
-- or permission row is modified. The policy catalog is empty on install, so
-- direct calls fail closed until an owner publishes a reviewed configuration.
-- Rollback: keep the additive rows; disable YORKS_V1_COMPANY_MATERIAL_REQUESTS
-- and revoke public RPC execute grants. Do not drop submitted evidence.

begin;

create table if not exists public.v1_company_material_request_categories (
  id uuid primary key default gen_random_uuid(),
  category_code text not null check (
    category_code ~ '^[a-z][a-z0-9_]{1,47}$'
  ),
  display_name text not null check (
    btrim(display_name) <> '' and char_length(display_name) <= 120
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (category_code)
);

create table if not exists public.v1_company_material_request_units (
  id uuid primary key default gen_random_uuid(),
  unit_code text not null check (unit_code ~ '^[A-Z0-9_-]{2,32}$'),
  display_name text not null check (
    btrim(display_name) <> '' and char_length(display_name) <= 120
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (unit_code)
);

-- The policy relation has no role-derived fallback. Requesting, named
-- beneficiary, receiving and approving authority are independently granted
-- per company category and responsible unit with an effective period.
create table if not exists public.v1_company_material_request_authorizations (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  category_id uuid not null references public.v1_company_material_request_categories (id)
    on delete restrict,
  responsible_unit_id uuid not null references public.v1_company_material_request_units (id)
    on delete restrict,
  authority text not null check (authority in (
    'requester', 'beneficiary', 'receiver', 'approver'
  )),
  effective_from date not null default current_date,
  effective_to date,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (effective_to is null or effective_to >= effective_from),
  unique (auth_user_id, category_id, responsible_unit_id, authority, effective_from)
);

-- A route names a primary and optional alternate, but both must separately
-- retain active approver authorization. Overlaps intentionally fail closed in
-- the resolver rather than letting a query order choose an approver.
create table if not exists public.v1_company_material_request_approval_routes (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.v1_company_material_request_categories (id)
    on delete restrict,
  responsible_unit_id uuid not null references public.v1_company_material_request_units (id)
    on delete restrict,
  primary_approver_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  alternate_approver_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  policy_version text not null check (
    btrim(policy_version) <> '' and char_length(policy_version) <= 80
  ),
  effective_from date not null default current_date,
  effective_to date,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (effective_to is null or effective_to >= effective_from),
  check (
    alternate_approver_auth_user_id is null
    or alternate_approver_auth_user_id <> primary_approver_auth_user_id
  ),
  unique (category_id, responsible_unit_id, effective_from)
);

create table if not exists public.v1_company_material_request_reference_counter (
  singleton boolean primary key default true check (singleton),
  next_sequence integer not null default 1 check (next_sequence > 0),
  updated_at timestamptz not null default clock_timestamp()
);
insert into public.v1_company_material_request_reference_counter (singleton)
values (true)
on conflict (singleton) do nothing;

create table if not exists public.v1_company_material_requests (
  id uuid primary key,
  request_number text unique,
  state text not null default 'draft' check (
    state in ('draft', 'awaiting_company_approval')
  ),
  record_version integer not null default 1 check (record_version > 0),
  category_id uuid not null references public.v1_company_material_request_categories (id)
    on delete restrict,
  responsible_unit_id uuid not null references public.v1_company_material_request_units (id)
    on delete restrict,
  purpose text not null check (
    btrim(purpose) <> '' and char_length(purpose) <= 1000
  ),
  timing text not null default 'normal' check (
    timing in ('urgent', 'normal', 'scheduled')
  ),
  scheduled_date date,
  delivery_collection_point text not null check (
    btrim(delivery_collection_point) <> ''
    and char_length(delivery_collection_point) <= 500
  ),
  beneficiary_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  beneficiary_display_name text not null check (btrim(beneficiary_display_name) <> ''),
  authorized_receiver_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  authorized_receiver_display_name text not null check (
    btrim(authorized_receiver_display_name) <> ''
  ),
  created_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  requester_display_name text not null check (btrim(requester_display_name) <> ''),
  requester_exact_role text not null,
  approval_route_id uuid references public.v1_company_material_request_approval_routes (id)
    on delete restrict,
  approval_policy_version text,
  approver_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  approver_display_name text,
  submitted_at timestamptz,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (timing = 'scheduled' and scheduled_date is not null)
    or (timing in ('urgent', 'normal') and scheduled_date is null)
  ),
  check (
    (state = 'draft' and request_number is null and submitted_at is null
      and approval_route_id is null and approval_policy_version is null
      and approver_auth_user_id is null and approver_display_name is null)
    or (state = 'awaiting_company_approval' and request_number is not null
      and submitted_at is not null and approval_route_id is not null
      and approval_policy_version is not null and approver_auth_user_id is not null
      and approver_display_name is not null)
  )
);
create index if not exists v1_company_material_requests_creator_draft_idx
  on public.v1_company_material_requests (created_by_auth_user_id, updated_at desc)
  where state = 'draft';
create index if not exists v1_company_material_requests_approver_idx
  on public.v1_company_material_requests (approver_auth_user_id, updated_at desc)
  where state = 'awaiting_company_approval';

create table if not exists public.v1_company_material_request_lines (
  id uuid primary key,
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  display_order integer not null check (display_order > 0),
  item_description text not null check (
    btrim(item_description) <> '' and char_length(item_description) <= 1000
  ),
  brand_origin text check (brand_origin is null or char_length(brand_origin) <= 300),
  requested_qty numeric(18, 4) not null check (requested_qty > 0),
  unit text not null check (btrim(unit) <> '' and char_length(unit) <= 40),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (request_id, display_order)
);

create table if not exists public.v1_company_material_request_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  event_type text not null check (event_type in (
    'company_request_draft_created', 'company_request_submitted'
  )),
  actor_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  actor_exact_role text not null,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  idempotency_key uuid,
  occurred_at timestamptz not null default clock_timestamp(),
  unique nulls not distinct (request_id, event_type, idempotency_key)
);

alter table public.v1_company_material_request_categories enable row level security;
alter table public.v1_company_material_request_units enable row level security;
alter table public.v1_company_material_request_authorizations enable row level security;
alter table public.v1_company_material_request_approval_routes enable row level security;
alter table public.v1_company_material_request_reference_counter enable row level security;
alter table public.v1_company_material_requests enable row level security;
alter table public.v1_company_material_request_lines enable row level security;
alter table public.v1_company_material_request_events enable row level security;

revoke all on table public.v1_company_material_request_categories,
  public.v1_company_material_request_units,
  public.v1_company_material_request_authorizations,
  public.v1_company_material_request_approval_routes,
  public.v1_company_material_request_reference_counter,
  public.v1_company_material_requests,
  public.v1_company_material_request_lines,
  public.v1_company_material_request_events
from public, anon, authenticated;
grant all on table public.v1_company_material_request_categories,
  public.v1_company_material_request_units,
  public.v1_company_material_request_authorizations,
  public.v1_company_material_request_approval_routes,
  public.v1_company_material_request_reference_counter,
  public.v1_company_material_requests,
  public.v1_company_material_request_lines,
  public.v1_company_material_request_events
to service_role;

create or replace function public.v1_company_material_request_active_authorization(
  p_auth_user_id uuid,
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_authority text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_auth_user_id is not null
    and exists (
      select 1
      from public.v1_company_material_request_authorizations authorization_record
      join public.v1_profiles profile
        on profile.auth_user_id = authorization_record.auth_user_id
       and profile.is_active
      join public.v1_company_material_request_categories category
        on category.id = authorization_record.category_id and category.is_active
      join public.v1_company_material_request_units unit_record
        on unit_record.id = authorization_record.responsible_unit_id and unit_record.is_active
      where authorization_record.auth_user_id = p_auth_user_id
        and authorization_record.category_id = p_category_id
        and authorization_record.responsible_unit_id = p_responsible_unit_id
        and authorization_record.authority = p_authority
        and authorization_record.effective_from <= current_date
        and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
    );
$$;

create or replace function public.v1_resolve_company_material_request_approver(
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_disallowed_auth_user_ids uuid[] default array[]::uuid[]
)
returns table (
  route_id uuid,
  policy_version text,
  approver_auth_user_id uuid,
  approver_display_name text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_route public.v1_company_material_request_approval_routes%rowtype;
  v_route_count integer;
  v_candidate uuid;
begin
  select count(*) into v_route_count
  from public.v1_company_material_request_approval_routes route_record
  join public.v1_company_material_request_categories category
    on category.id = route_record.category_id and category.is_active
  join public.v1_company_material_request_units unit_record
    on unit_record.id = route_record.responsible_unit_id and unit_record.is_active
  where route_record.category_id = p_category_id
    and route_record.responsible_unit_id = p_responsible_unit_id
    and route_record.effective_from <= current_date
    and (route_record.effective_to is null or route_record.effective_to >= current_date);
  if v_route_count <> 1 then return; end if;

  select * into v_route
  from public.v1_company_material_request_approval_routes route_record
  where route_record.category_id = p_category_id
    and route_record.responsible_unit_id = p_responsible_unit_id
    and route_record.effective_from <= current_date
    and (route_record.effective_to is null or route_record.effective_to >= current_date);

  foreach v_candidate in array array[
    v_route.primary_approver_auth_user_id,
    v_route.alternate_approver_auth_user_id
  ] loop
    if v_candidate is null
      or v_candidate = any(coalesce(p_disallowed_auth_user_ids, array[]::uuid[]))
      or not public.v1_company_material_request_active_authorization(
        v_candidate, p_category_id, p_responsible_unit_id, 'approver'
      ) then
      continue;
    end if;
    select profile.display_name into approver_display_name
    from public.v1_profiles profile
    where profile.auth_user_id = v_candidate and profile.is_active;
    if approver_display_name is null or btrim(approver_display_name) = '' then
      continue;
    end if;
    route_id := v_route.id;
    policy_version := v_route.policy_version;
    approver_auth_user_id := v_candidate;
    return next;
    return;
  end loop;
end;
$$;

create or replace function public.v1_list_company_material_request_draft_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_OPTIONS_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'category_id', category.id,
      'category_code', category.category_code,
      'category_name', category.display_name,
      'responsible_unit_id', unit_record.id,
      'responsible_unit_code', unit_record.unit_code,
      'responsible_unit_name', unit_record.display_name,
      'beneficiaries', coalesce((
        select jsonb_agg(jsonb_build_object(
          'auth_user_id', profile.auth_user_id,
          'display_name', profile.display_name
        ) order by lower(profile.display_name), profile.auth_user_id)
        from public.v1_company_material_request_authorizations authorization_record
        join public.v1_profiles profile
          on profile.auth_user_id = authorization_record.auth_user_id and profile.is_active
        where authorization_record.category_id = category.id
          and authorization_record.responsible_unit_id = unit_record.id
          and authorization_record.authority = 'beneficiary'
          and authorization_record.effective_from <= current_date
          and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
      ), '[]'::jsonb),
      'receivers', coalesce((
        select jsonb_agg(jsonb_build_object(
          'auth_user_id', profile.auth_user_id,
          'display_name', profile.display_name
        ) order by lower(profile.display_name), profile.auth_user_id)
        from public.v1_company_material_request_authorizations authorization_record
        join public.v1_profiles profile
          on profile.auth_user_id = authorization_record.auth_user_id and profile.is_active
        where authorization_record.category_id = category.id
          and authorization_record.responsible_unit_id = unit_record.id
          and authorization_record.authority = 'receiver'
          and authorization_record.effective_from <= current_date
          and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
      ), '[]'::jsonb)
    ) order by lower(category.display_name), lower(unit_record.display_name))
    from public.v1_company_material_request_authorizations authorization_record
    join public.v1_company_material_request_categories category
      on category.id = authorization_record.category_id and category.is_active
    join public.v1_company_material_request_units unit_record
      on unit_record.id = authorization_record.responsible_unit_id and unit_record.is_active
    where authorization_record.auth_user_id = v_actor
      and authorization_record.authority = 'requester'
      and authorization_record.effective_from <= current_date
      and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_company_material_request_approval_preflight(
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_beneficiary_auth_user_id uuid,
  p_authorized_receiver_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_route record;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_active_authorization(
      v_actor, p_category_id, p_responsible_unit_id, 'requester'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PREFLIGHT_DENIED' using errcode = '42501';
  end if;
  select * into v_route
  from public.v1_resolve_company_material_request_approver(
    p_category_id,
    p_responsible_unit_id,
    array[v_actor, p_beneficiary_auth_user_id, p_authorized_receiver_auth_user_id]
  );
  if not found then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED'
      using errcode = '22023';
  end if;
  return jsonb_build_object(
    'approval_route_id', v_route.route_id,
    'policy_version', v_route.policy_version,
    'approver_auth_user_id', v_route.approver_auth_user_id,
    'approver_display_name', v_route.approver_display_name
  );
end;
$$;

create or replace function public.v1_company_material_request_readable(
  p_request_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and exists (
      select 1
      from public.v1_company_material_requests request_record
      where request_record.id = p_request_id
        and (
          request_record.created_by_auth_user_id = auth.uid()
          or (request_record.state <> 'draft' and (
            request_record.beneficiary_auth_user_id = auth.uid()
            or request_record.authorized_receiver_auth_user_id = auth.uid()
            or request_record.approver_auth_user_id = auth.uid()
          ))
        )
    );
$$;

create or replace function public.v1_company_material_request_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.v1_company_material_request_readable(p_request_id) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'request_number', request_record.request_number,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'category_id', category.id,
    'category_code', category.category_code,
    'category_name', category.display_name,
    'responsible_unit_id', unit_record.id,
    'responsible_unit_code', unit_record.unit_code,
    'responsible_unit_name', unit_record.display_name,
    'purpose', request_record.purpose,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_collection_point', request_record.delivery_collection_point,
    'beneficiary_auth_user_id', request_record.beneficiary_auth_user_id,
    'beneficiary_display_name', request_record.beneficiary_display_name,
    'authorized_receiver_auth_user_id', request_record.authorized_receiver_auth_user_id,
    'authorized_receiver_display_name', request_record.authorized_receiver_display_name,
    'requester_display_name', request_record.requester_display_name,
    'requester_exact_role', request_record.requester_exact_role,
    'approver_auth_user_id', request_record.approver_auth_user_id,
    'approver_display_name', request_record.approver_display_name,
    'approval_policy_version', request_record.approval_policy_version,
    'submitted_at', request_record.submitted_at,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', line_record.id,
        'display_order', line_record.display_order,
        'item_description', line_record.item_description,
        'brand_origin', line_record.brand_origin,
        'requested_qty', line_record.requested_qty::text,
        'unit', line_record.unit
      ) order by line_record.display_order)
      from public.v1_company_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_company_material_requests request_record
  join public.v1_company_material_request_categories category
    on category.id = request_record.category_id
  join public.v1_company_material_request_units unit_record
    on unit_record.id = request_record.responsible_unit_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

create or replace function public.v1_save_company_material_request_draft(
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_role();
  v_request_id uuid;
  v_expected_version integer;
  v_category_id uuid;
  v_unit_id uuid;
  v_beneficiary_id uuid;
  v_receiver_id uuid;
  v_purpose text;
  v_timing text;
  v_scheduled_date date;
  v_delivery_point text;
  v_lines jsonb;
  v_existing public.v1_company_material_requests%rowtype;
  v_beneficiary_name text;
  v_receiver_name text;
  v_requester_name text;
  v_line jsonb;
  v_line_id uuid;
  v_line_order integer;
  v_line_description text;
  v_line_brand_origin text;
  v_line_quantity numeric;
  v_line_unit text;
begin
  if v_actor is null or v_exact_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(p_payload, array[
    'request_id', 'expected_version', 'category_id', 'responsible_unit_id',
    'purpose', 'timing', 'scheduled_date', 'delivery_collection_point',
    'beneficiary_auth_user_id', 'authorized_receiver_auth_user_id', 'lines'
  ], 'company_material_request_draft_payload');
  begin
    v_request_id := (p_payload ->> 'request_id')::uuid;
    v_expected_version := (p_payload ->> 'expected_version')::integer;
    v_category_id := (p_payload ->> 'category_id')::uuid;
    v_unit_id := (p_payload ->> 'responsible_unit_id')::uuid;
    v_beneficiary_id := (p_payload ->> 'beneficiary_auth_user_id')::uuid;
    v_receiver_id := (p_payload ->> 'authorized_receiver_auth_user_id')::uuid;
    v_scheduled_date := nullif(btrim(coalesce(p_payload ->> 'scheduled_date', '')), '')::date;
  exception when others then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end;
  v_purpose := nullif(btrim(coalesce(p_payload ->> 'purpose', '')), '');
  v_timing := nullif(btrim(coalesce(p_payload ->> 'timing', '')), '');
  v_delivery_point := nullif(btrim(coalesce(p_payload ->> 'delivery_collection_point', '')), '');
  v_lines := p_payload -> 'lines';
  if v_request_id is null or v_expected_version is null or v_expected_version < 0
    or v_category_id is null or v_unit_id is null or v_beneficiary_id is null
    or v_receiver_id is null or v_purpose is null or v_delivery_point is null
    or v_timing not in ('urgent', 'normal', 'scheduled')
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  if (v_timing = 'scheduled' and v_scheduled_date is null)
    or (v_timing <> 'scheduled' and v_scheduled_date is not null) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_TIMING_INVALID' using errcode = '22023';
  end if;
  if not public.v1_company_material_request_active_authorization(
      v_actor, v_category_id, v_unit_id, 'requester'
    )
    or not public.v1_company_material_request_active_authorization(
      v_beneficiary_id, v_category_id, v_unit_id, 'beneficiary'
    )
    or not public.v1_company_material_request_active_authorization(
      v_receiver_id, v_category_id, v_unit_id, 'receiver'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PARTICIPANT_DENIED' using errcode = '42501';
  end if;
  select display_name into v_beneficiary_name from public.v1_profiles
  where auth_user_id = v_beneficiary_id and is_active;
  select display_name into v_receiver_name from public.v1_profiles
  where auth_user_id = v_receiver_id and is_active;
  select display_name into v_requester_name from public.v1_profiles
  where auth_user_id = v_actor and is_active;
  if nullif(btrim(coalesce(v_beneficiary_name, '')), '') is null
    or nullif(btrim(coalesce(v_receiver_name, '')), '') is null
    or nullif(btrim(coalesce(v_requester_name, '')), '') is null then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PARTICIPANT_INACTIVE' using errcode = '42501';
  end if;
  if jsonb_array_length(v_lines) = 0 then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINES_REQUIRED' using errcode = '22023';
  end if;

  select * into v_existing from public.v1_company_material_requests request_record
  where request_record.id = v_request_id for update;
  if found then
    if v_existing.created_by_auth_user_id <> v_actor or v_existing.state <> 'draft' then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_DRAFT_WRITE_DENIED' using errcode = '42501';
    end if;
    if v_existing.record_version <> v_expected_version then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode = '40001';
    end if;
    update public.v1_company_material_requests request_record
    set category_id = v_category_id,
        responsible_unit_id = v_unit_id,
        purpose = v_purpose,
        timing = v_timing,
        scheduled_date = v_scheduled_date,
        delivery_collection_point = v_delivery_point,
        beneficiary_auth_user_id = v_beneficiary_id,
        beneficiary_display_name = v_beneficiary_name,
        authorized_receiver_auth_user_id = v_receiver_id,
        authorized_receiver_display_name = v_receiver_name,
        record_version = request_record.record_version + 1,
        updated_at = clock_timestamp()
    where request_record.id = v_request_id;
    delete from public.v1_company_material_request_lines where request_id = v_request_id;
  else
    if v_expected_version <> 0 then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode = '40001';
    end if;
    insert into public.v1_company_material_requests (
      id, category_id, responsible_unit_id, purpose, timing, scheduled_date,
      delivery_collection_point, beneficiary_auth_user_id, beneficiary_display_name,
      authorized_receiver_auth_user_id, authorized_receiver_display_name,
      created_by_auth_user_id, requester_display_name, requester_exact_role
    ) values (
      v_request_id, v_category_id, v_unit_id, v_purpose, v_timing, v_scheduled_date,
      v_delivery_point, v_beneficiary_id, v_beneficiary_name,
      v_receiver_id, v_receiver_name, v_actor, v_requester_name, v_exact_role
    );
    insert into public.v1_company_material_request_events (
      request_id, event_type, actor_auth_user_id, actor_exact_role, data
    ) values (
      v_request_id, 'company_request_draft_created', v_actor, v_exact_role,
      jsonb_build_object('category_id', v_category_id, 'responsible_unit_id', v_unit_id)
    );
  end if;

  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line, array[
      'id', 'display_order', 'item_description', 'brand_origin', 'requested_qty', 'unit'
    ], 'company_material_request_line');
    begin
      v_line_id := (v_line ->> 'id')::uuid;
      v_line_order := (v_line ->> 'display_order')::integer;
      v_line_quantity := (v_line ->> 'requested_qty')::numeric;
    exception when others then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end;
    v_line_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_line_brand_origin := nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), '');
    v_line_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    if v_line_id is null or v_line_order is null or v_line_order <= 0
      or v_line_quantity is null or v_line_quantity <= 0
      or v_line_description is null or v_line_unit is null then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end if;
    insert into public.v1_company_material_request_lines (
      id, request_id, display_order, item_description, brand_origin, requested_qty, unit
    ) values (
      v_line_id, v_request_id, v_line_order, v_line_description,
      v_line_brand_origin, v_line_quantity, v_line_unit
    );
  end loop;
  return public.v1_company_material_request_projection(v_request_id);
end;
$$;

create or replace function public.v1_submit_company_material_request(
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
  v_exact_role text := public.v1_current_role();
  v_request_id uuid;
  v_expected_version integer;
  v_existing_response jsonb;
  v_request public.v1_company_material_requests%rowtype;
  v_route record;
  v_sequence integer;
  v_response jsonb;
begin
  if v_actor is null or v_exact_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'company_material_request_submit_payload'
  );
  begin
    v_request_id := (p_payload ->> 'request_id')::uuid;
    v_expected_version := (p_payload ->> 'expected_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_submit_company_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  select * into v_request from public.v1_company_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or v_request.created_by_auth_user_id <> v_actor then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  if v_request.state <> 'draft' then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_ALREADY_SUBMITTED' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode = '40001';
  end if;
  if not public.v1_company_material_request_active_authorization(
      v_actor, v_request.category_id, v_request.responsible_unit_id, 'requester'
    )
    or not public.v1_company_material_request_active_authorization(
      v_request.beneficiary_auth_user_id, v_request.category_id,
      v_request.responsible_unit_id, 'beneficiary'
    )
    or not public.v1_company_material_request_active_authorization(
      v_request.authorized_receiver_auth_user_id, v_request.category_id,
      v_request.responsible_unit_id, 'receiver'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PARTICIPANT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_company_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINES_REQUIRED' using errcode = '22023';
  end if;
  select * into v_route from public.v1_resolve_company_material_request_approver(
    v_request.category_id,
    v_request.responsible_unit_id,
    array[v_actor, v_request.beneficiary_auth_user_id, v_request.authorized_receiver_auth_user_id]
  );
  if not found then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED'
      using errcode = '22023';
  end if;
  update public.v1_company_material_request_reference_counter
  set next_sequence = next_sequence + 1, updated_at = clock_timestamp()
  where singleton
  returning next_sequence - 1 into v_sequence;

  update public.v1_company_material_requests request_record
  set request_number = 'CMR-' || lpad(v_sequence::text, 6, '0'),
      state = 'awaiting_company_approval',
      approval_route_id = v_route.route_id,
      approval_policy_version = v_route.policy_version,
      approver_auth_user_id = v_route.approver_auth_user_id,
      approver_display_name = v_route.approver_display_name,
      submitted_at = clock_timestamp(),
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request.id;
  insert into public.v1_company_material_request_events (
    request_id, event_type, actor_auth_user_id, actor_exact_role, data, idempotency_key
  ) values (
    v_request.id, 'company_request_submitted', v_actor, v_exact_role,
    jsonb_build_object(
      'approval_route_id', v_route.route_id,
      'approval_policy_version', v_route.policy_version,
      'approver_auth_user_id', v_route.approver_auth_user_id,
      'beneficiary_auth_user_id', v_request.beneficiary_auth_user_id,
      'authorized_receiver_auth_user_id', v_request.authorized_receiver_auth_user_id
    ), p_idempotency_key
  );
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  ) values (
    v_route.approver_auth_user_id,
    'company_material_request_approval_requested',
    'company_material_request',
    v_request.id,
    null
  );
  v_response := public.v1_company_material_request_projection(v_request.id);
  perform public.v1_complete_idempotency(
    'v1_submit_company_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Mirrors the project composer’s single connected submit action. The draft
-- replacement and company-approval handoff share one database transaction;
-- a failed route or stale version leaves neither a partially saved request nor
-- an idempotency response behind.
create or replace function public.v1_save_and_submit_company_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing_response jsonb;
  v_saved jsonb;
  v_request_id uuid;
  v_version integer;
  v_response jsonb;
begin
  -- The outer command owns the client retry contract. Claim before saving so
  -- a lost response cannot attempt to mutate an already submitted draft.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_and_submit_company_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  v_saved := public.v1_save_company_material_request_draft(p_payload);
  begin
    v_request_id := (v_saved ->> 'id')::uuid;
    v_version := (v_saved ->> 'record_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SAVE_RESPONSE_INVALID'
      using errcode = '22023';
  end;
  v_response := public.v1_submit_company_material_request(
    jsonb_build_object('request_id', v_request_id, 'expected_version', v_version),
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_and_submit_company_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_company_material_request_active_authorization(uuid,uuid,uuid,text),
  public.v1_resolve_company_material_request_approver(uuid,uuid,uuid[]),
  public.v1_company_material_request_readable(uuid)
from public, anon, authenticated;
grant execute on function public.v1_company_material_request_active_authorization(uuid,uuid,uuid,text),
  public.v1_resolve_company_material_request_approver(uuid,uuid,uuid[]),
  public.v1_company_material_request_readable(uuid)
to service_role;

revoke all on function public.v1_list_company_material_request_draft_options(),
  public.v1_company_material_request_approval_preflight(uuid,uuid,uuid,uuid),
  public.v1_company_material_request_projection(uuid),
  public.v1_save_company_material_request_draft(jsonb),
  public.v1_submit_company_material_request(jsonb,uuid),
  public.v1_save_and_submit_company_material_request(jsonb,uuid)
from public, anon, authenticated;
grant execute on function public.v1_list_company_material_request_draft_options(),
  public.v1_company_material_request_approval_preflight(uuid,uuid,uuid,uuid),
  public.v1_company_material_request_projection(uuid),
  public.v1_save_company_material_request_draft(jsonb),
  public.v1_submit_company_material_request(jsonb,uuid),
  public.v1_save_and_submit_company_material_request(jsonb,uuid)
to authenticated;

commit;
