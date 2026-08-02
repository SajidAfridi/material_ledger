-- Yorks V1 Batch 8: immutable Delivery Order revisions and the controlled
-- material-return loop.  All writes are server-side commands; no client table
-- policy can manufacture a document or change warehouse stock.

create table if not exists public.v1_delivery_orders (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  dispatch_id uuid not null unique references public.v1_material_dispatches (id)
    on delete restrict,
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  delivery_order_reference text not null unique
    check (delivery_order_reference = upper(regexp_replace(
      btrim(delivery_order_reference), '\\s+', ' ', 'g'
    ))),
  current_revision_id uuid,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in ('procurement', 'admin')),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_delivery_order_revisions (
  id uuid primary key default gen_random_uuid(),
  delivery_order_id uuid not null references public.v1_delivery_orders (id)
    on delete restrict,
  receipt_review_id uuid not null references public.v1_receipt_reviews (id)
    on delete restrict,
  revision_number integer not null check (revision_number > 0),
  generated_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  generated_by_role text not null check (generated_by_role in ('procurement', 'admin')),
  generated_at timestamptz not null default clock_timestamp(),
  unique (delivery_order_id, revision_number)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_delivery_orders_current_revision_fk'
      and conrelid = 'public.v1_delivery_orders'::regclass
  ) then
    alter table public.v1_delivery_orders
      add constraint v1_delivery_orders_current_revision_fk
      foreign key (current_revision_id)
      references public.v1_delivery_order_revisions (id) on delete restrict;
  end if;
end;
$$;

create table if not exists public.v1_delivery_order_revision_lines (
  id uuid primary key default gen_random_uuid(),
  delivery_order_revision_id uuid not null
    references public.v1_delivery_order_revisions (id) on delete restrict,
  receipt_review_line_id uuid not null
    references public.v1_receipt_review_lines (id) on delete restrict,
  display_order integer not null check (display_order > 0),
  item_description text not null check (btrim(item_description) <> ''),
  good_quantity numeric(18, 4) not null check (good_quantity > 0),
  unit text not null check (btrim(unit) <> ''),
  unique (delivery_order_revision_id, receipt_review_line_id),
  unique (delivery_order_revision_id, display_order)
);

create index if not exists v1_delivery_orders_request_created_idx
  on public.v1_delivery_orders (request_id, created_at desc);
create index if not exists v1_delivery_order_revisions_order_number_idx
  on public.v1_delivery_order_revisions (delivery_order_id, revision_number desc);

create table if not exists public.v1_return_reference_counters (
  project_id uuid primary key references public.v1_projects (id) on delete restrict,
  next_return_sequence integer not null default 1 check (next_return_sequence > 0),
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_material_returns (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  scope_id uuid not null references public.v1_project_scopes (id) on delete restrict,
  return_number text unique,
  state text not null default 'draft' check (state in (
    'draft', 'submitted', 'confirmed', 'rejected'
  )),
  note text,
  record_version integer not null default 1 check (record_version > 0),
  drafted_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  drafted_by_role text not null check (drafted_by_role in (
    'project_engineer', 'site_engineer', 'admin'
  )),
  drafted_at timestamptz not null default clock_timestamp(),
  submitted_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  submitted_by_role text check (submitted_by_role in (
    'project_engineer', 'site_engineer', 'admin'
  )),
  submitted_at timestamptz,
  decided_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  decided_by_role text check (decided_by_role in ('procurement', 'admin')),
  decided_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (state = 'draft' and return_number is null and submitted_at is null
      and submitted_by_auth_user_id is null and submitted_by_role is null
      and decided_at is null and decided_by_auth_user_id is null
      and decided_by_role is null and rejection_reason is null)
    or (state = 'submitted' and return_number is not null and submitted_at is not null
      and submitted_by_auth_user_id is not null and submitted_by_role is not null
      and decided_at is null and decided_by_auth_user_id is null
      and decided_by_role is null and rejection_reason is null)
    or (state = 'confirmed' and return_number is not null and submitted_at is not null
      and submitted_by_auth_user_id is not null and submitted_by_role is not null
      and decided_at is not null and decided_by_auth_user_id is not null
      and decided_by_role is not null and rejection_reason is null)
    or (state = 'rejected' and return_number is not null and submitted_at is not null
      and submitted_by_auth_user_id is not null and submitted_by_role is not null
      and decided_at is not null and decided_by_auth_user_id is not null
      and decided_by_role is not null and rejection_reason is not null
      and btrim(rejection_reason) <> '')
  )
);

create table if not exists public.v1_material_return_lines (
  id uuid primary key default gen_random_uuid(),
  material_return_id uuid not null references public.v1_material_returns (id)
    on delete restrict,
  receipt_review_line_id uuid not null
    references public.v1_receipt_review_lines (id) on delete restrict,
  dispatch_line_id uuid not null references public.v1_material_dispatch_lines (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_material_request_lines (id)
    on delete restrict,
  source_kind text not null check (source_kind in ('warehouse', 'external_supplier')),
  source_inventory_item_id uuid references public.v1_inventory_items (id)
    on delete restrict,
  item_description text not null check (btrim(item_description) <> ''),
  brand_origin text,
  unit text not null check (btrim(unit) <> ''),
  good_quantity_snapshot numeric(18, 4) not null check (good_quantity_snapshot > 0),
  eligible_quantity_at_submit numeric(18, 4),
  return_quantity numeric(18, 4) not null check (return_quantity > 0),
  target_inventory_item_id uuid references public.v1_inventory_items (id)
    on delete restrict,
  display_order integer not null check (display_order > 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (material_return_id, receipt_review_line_id),
  unique (material_return_id, display_order),
  check (
    (source_kind = 'warehouse' and source_inventory_item_id is not null)
    or source_kind = 'external_supplier'
  ),
  check (eligible_quantity_at_submit is null or eligible_quantity_at_submit > 0)
);

create index if not exists v1_material_returns_request_created_idx
  on public.v1_material_returns (request_id, created_at desc);
create index if not exists v1_material_returns_project_state_idx
  on public.v1_material_returns (project_id, state);
create index if not exists v1_material_return_lines_review_line_idx
  on public.v1_material_return_lines (receipt_review_line_id);

alter table public.v1_delivery_orders enable row level security;
alter table public.v1_delivery_order_revisions enable row level security;
alter table public.v1_delivery_order_revision_lines enable row level security;
alter table public.v1_return_reference_counters enable row level security;
alter table public.v1_material_returns enable row level security;
alter table public.v1_material_return_lines enable row level security;

revoke all on table public.v1_delivery_orders from public, anon, authenticated;
revoke all on table public.v1_delivery_order_revisions from public, anon, authenticated;
revoke all on table public.v1_delivery_order_revision_lines from public, anon, authenticated;
revoke all on table public.v1_return_reference_counters from public, anon, authenticated;
revoke all on table public.v1_material_returns from public, anon, authenticated;
revoke all on table public.v1_material_return_lines from public, anon, authenticated;
grant all on table public.v1_delivery_orders to service_role;
grant all on table public.v1_delivery_order_revisions to service_role;
grant all on table public.v1_delivery_order_revision_lines to service_role;
grant all on table public.v1_return_reference_counters to service_role;
grant all on table public.v1_material_returns to service_role;
grant all on table public.v1_material_return_lines to service_role;

create or replace function public.v1_can_generate_delivery_order(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_state text;
begin
  if not public.v1_can_manage_inventory() then return false; end if;
  select project.state into v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_state in ('active', 'on_hold', 'completed');
end;
$$;

create or replace function public.v1_can_submit_material_return(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin') then
    return false;
  end if;
  select request_record.project_id, project.state into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_id is not null and v_project_state in ('active', 'on_hold', 'completed')
    and (v_role = 'admin' or public.v1_has_active_project_membership(
      v_project_id, auth.uid(), null
    ));
end;
$$;

create or replace function public.v1_can_confirm_material_return(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return public.v1_can_generate_delivery_order(p_request_id);
end;
$$;

create or replace function public.v1_returns_documents_readable(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id, project.state into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  if v_project_id is null then return false; end if;
  if v_role = 'admin' then return true; end if;
  if v_role in ('project_engineer', 'site_engineer') then
    return public.v1_has_active_project_membership(v_project_id, auth.uid(), null);
  end if;
  return v_role = 'procurement' and v_project_state in ('active', 'on_hold', 'completed');
end;
$$;

create or replace function public.v1_delivery_order_projection(
  p_delivery_order_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', delivery_order.id,
    'dispatch_id', delivery_order.dispatch_id,
    'delivery_order_reference', delivery_order.delivery_order_reference,
    'record_version', delivery_order.record_version,
    'current_revision_id', delivery_order.current_revision_id,
    'revisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', revision.id,
        'revision_number', revision.revision_number,
        'is_current', revision.id = delivery_order.current_revision_id,
        'generated_at', revision.generated_at,
        'generated_by_display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            's_no', line.display_order,
            'item_description', line.item_description,
            'quantity', line.good_quantity::text,
            'unit', line.unit
          ) order by line.display_order)
          from public.v1_delivery_order_revision_lines line
          where line.delivery_order_revision_id = revision.id
        ), '[]'::jsonb)
      ) order by revision.revision_number desc)
      from public.v1_delivery_order_revisions revision
      join public.v1_profiles profile
        on profile.auth_user_id = revision.generated_by_auth_user_id
      where revision.delivery_order_id = delivery_order.id
    ), '[]'::jsonb)
  )
  from public.v1_delivery_orders delivery_order
  where delivery_order.id = p_delivery_order_id;
$$;

create or replace function public.v1_returns_documents_workspace_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_can_generate boolean := public.v1_can_generate_delivery_order(p_request_id);
  v_can_submit boolean := public.v1_can_submit_material_return(p_request_id);
  v_can_confirm boolean := public.v1_can_confirm_material_return(p_request_id);
  v_result jsonb;
begin
  if not public.v1_returns_documents_readable(p_request_id) then
    raise exception 'V1_RETURNS_DOCUMENTS_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'request_id', request_record.id,
    'project_id', request_record.project_id,
    'request_number', request_record.request_number,
    'request_state', request_record.state,
    'request_record_version', request_record.record_version,
    'project_name', project.name,
    'scope_name', scope.name,
    'can_generate_delivery_order', v_can_generate,
    'can_submit_material_return', v_can_submit,
    'can_confirm_material_return', v_can_confirm,
    'delivery_orders', coalesce((
      select jsonb_agg(jsonb_build_object(
        'dispatch_id', dispatch.id,
        'dispatch_number', dispatch.dispatch_number,
        'dispatch_date', dispatch.dispatch_date,
        'dispatch_record_version', dispatch.record_version,
        'receipt_reviewed_at', review.reviewed_at,
        'can_generate', v_can_generate and review.id is not null,
        'delivery_order', case when delivery_order.id is null then null
          else public.v1_delivery_order_projection(delivery_order.id) end
      ) order by dispatch.dispatched_at desc)
      from public.v1_material_dispatches dispatch
      left join public.v1_receipt_reviews review
        on review.dispatch_id = dispatch.id and review.state = 'confirmed'
      left join public.v1_delivery_orders delivery_order
        on delivery_order.dispatch_id = dispatch.id
      where dispatch.request_id = request_record.id
    ), '[]'::jsonb),
    'return_candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'receipt_review_line_id', review_line.id,
        'dispatch_number', dispatch.dispatch_number,
        'display_order', request_line.display_order,
        'item_description', dispatch_line.item_description,
        'brand_origin', dispatch_line.brand_origin,
        'unit', dispatch_line.unit,
        'source_kind', dispatch_line.source_kind,
        'good_received_qty', review_line.good_qty::text,
        'confirmed_return_qty', coalesce((
          select sum(return_line.return_quantity)
          from public.v1_material_return_lines return_line
          join public.v1_material_returns material_return
            on material_return.id = return_line.material_return_id
          where return_line.receipt_review_line_id = review_line.id
            and material_return.state = 'confirmed'
        ), 0)::text,
        'eligible_return_qty', greatest(0, review_line.good_qty - coalesce((
          select sum(return_line.return_quantity)
          from public.v1_material_return_lines return_line
          join public.v1_material_returns material_return
            on material_return.id = return_line.material_return_id
          where return_line.receipt_review_line_id = review_line.id
            and material_return.state = 'confirmed'
        ), 0))::text,
        'source_inventory_item_id', case when v_can_confirm
          then dispatch_line.inventory_item_id else null end
      ) order by dispatch.dispatched_at desc, dispatch_line.created_at)
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      join public.v1_material_request_lines request_line
        on request_line.id = dispatch_line.request_line_id
      join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
      where review.request_id = request_record.id
        and review.state = 'confirmed'
        and review_line.good_qty > 0
    ), '[]'::jsonb),
    'returns', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', material_return.id,
        'return_number', material_return.return_number,
        'state', material_return.state,
        'note', material_return.note,
        'record_version', material_return.record_version,
        'drafted_at', material_return.drafted_at,
        'drafted_by_display_name', public.v1_safe_profile_display_name(
          drafter.display_name, drafter.auth_user_id
        ),
        'submitted_at', material_return.submitted_at,
        'submitted_by_display_name', case when submitter.auth_user_id is null then null
          else public.v1_safe_profile_display_name(
            submitter.display_name, submitter.auth_user_id
          ) end,
        'decided_at', material_return.decided_at,
        'decided_by_display_name', case when decider.auth_user_id is null then null
          else public.v1_safe_profile_display_name(
            decider.display_name, decider.auth_user_id
          ) end,
        'rejection_reason', material_return.rejection_reason,
        'can_edit_draft', v_can_submit and material_return.state = 'draft'
          and (material_return.drafted_by_auth_user_id = auth.uid()
            or public.v1_current_role() = 'admin'),
        'can_submit', v_can_submit and material_return.state = 'draft'
          and (material_return.drafted_by_auth_user_id = auth.uid()
            or public.v1_current_role() = 'admin'),
        'can_confirm', v_can_confirm and material_return.state = 'submitted',
        'can_reject', v_can_confirm and material_return.state = 'submitted',
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', return_line.id,
            'receipt_review_line_id', return_line.receipt_review_line_id,
            'dispatch_number', dispatch.dispatch_number,
            'display_order', return_line.display_order,
            'item_description', return_line.item_description,
            'brand_origin', return_line.brand_origin,
            'unit', return_line.unit,
            'source_kind', return_line.source_kind,
            'good_quantity_snapshot', return_line.good_quantity_snapshot::text,
            'eligible_quantity_at_submit', case
              when return_line.eligible_quantity_at_submit is null then null
              else return_line.eligible_quantity_at_submit::text end,
            'return_quantity', return_line.return_quantity::text,
            'target_inventory_item_id', case when v_can_confirm
              then return_line.target_inventory_item_id else null end
          ) order by return_line.display_order)
          from public.v1_material_return_lines return_line
          join public.v1_material_dispatch_lines dispatch_line
            on dispatch_line.id = return_line.dispatch_line_id
          join public.v1_material_dispatches dispatch
            on dispatch.id = dispatch_line.dispatch_id
          where return_line.material_return_id = material_return.id
        ), '[]'::jsonb)
      ) order by material_return.created_at desc)
      from public.v1_material_returns material_return
      join public.v1_profiles drafter
        on drafter.auth_user_id = material_return.drafted_by_auth_user_id
      left join public.v1_profiles submitter
        on submitter.auth_user_id = material_return.submitted_by_auth_user_id
      left join public.v1_profiles decider
        on decider.auth_user_id = material_return.decided_by_auth_user_id
      where material_return.request_id = request_record.id
    ), '[]'::jsonb),
    'return_inventory_items', case when v_can_confirm then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id, 'item_description', item.item_description,
        'brand_origin', item.brand_origin, 'unit', item.unit
      ) order by lower(item.item_description), lower(coalesce(item.brand_origin, '')))
      from public.v1_inventory_items item where item.is_active
    ), '[]'::jsonb) else '[]'::jsonb end
  ) into v_result
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

create or replace function public.v1_generate_delivery_order(
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
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_dispatch_id uuid;
  v_expected_request_version integer;
  v_expected_dispatch_version integer;
  v_reference text;
  v_request public.v1_material_requests%rowtype;
  v_dispatch public.v1_material_dispatches%rowtype;
  v_review public.v1_receipt_reviews%rowtype;
  v_delivery_order public.v1_delivery_orders%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_revision_id uuid;
  v_revision_number integer;
  v_good_line_count integer;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'dispatch_id', 'expected_request_version',
      'expected_dispatch_version', 'delivery_order_reference'],
    'generate_delivery_order'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_dispatch_id := nullif(btrim(coalesce(p_payload ->> 'dispatch_id', '')), '')::uuid;
  v_expected_request_version := nullif(p_payload ->> 'expected_request_version', '')::integer;
  v_expected_dispatch_version := nullif(p_payload ->> 'expected_dispatch_version', '')::integer;
  v_reference := nullif(upper(regexp_replace(btrim(coalesce(
    p_payload ->> 'delivery_order_reference', ''
  )), '\\s+', ' ', 'g')), '');
  if v_request_id is null or v_dispatch_id is null
    or v_expected_request_version is null or v_expected_dispatch_version is null
    or v_expected_request_version < 1 or v_expected_dispatch_version < 1
    or v_reference is null then
    raise exception 'V1_DELIVERY_ORDER_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_generate_delivery_order(v_request_id) then
    raise exception 'V1_DELIVERY_ORDER_GENERATE_DENIED' using errcode = '42501';
  end if;
  select * into v_dispatch from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id and dispatch.request_id = v_request.id
  for update;
  select * into v_review from public.v1_receipt_reviews review
  where review.dispatch_id = v_dispatch.id and review.state = 'confirmed'
  for update;
  if not found then
    raise exception 'V1_DELIVERY_ORDER_RECEIPT_REVIEW_REQUIRED' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_generate_delivery_order', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version then
    raise exception 'V1_DELIVERY_ORDER_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select count(*) into v_good_line_count
  from public.v1_receipt_review_lines review_line
  where review_line.receipt_review_id = v_review.id and review_line.good_qty > 0;
  if v_good_line_count = 0 then
    raise exception 'V1_DELIVERY_ORDER_NO_GOOD_LINES' using errcode = '22023';
  end if;
  v_before := public.v1_returns_documents_workspace_projection(v_request.id);
  select * into v_delivery_order from public.v1_delivery_orders delivery_order
  where delivery_order.dispatch_id = v_dispatch.id for update;
  if not found then
    insert into public.v1_delivery_orders (
      request_id, dispatch_id, project_id, delivery_order_reference,
      created_by_auth_user_id, created_by_role
    ) values (
      v_request.id, v_dispatch.id, v_request.project_id, v_reference, v_actor, v_role
    ) returning * into v_delivery_order;
    v_revision_number := 1;
  elsif v_delivery_order.delivery_order_reference <> v_reference then
    raise exception 'V1_DELIVERY_ORDER_REFERENCE_IMMUTABLE' using errcode = '22023';
  else
    select coalesce(max(revision.revision_number), 0) + 1 into v_revision_number
    from public.v1_delivery_order_revisions revision
    where revision.delivery_order_id = v_delivery_order.id;
  end if;
  insert into public.v1_delivery_order_revisions (
    delivery_order_id, receipt_review_id, revision_number,
    generated_by_auth_user_id, generated_by_role
  ) values (
    v_delivery_order.id, v_review.id, v_revision_number, v_actor, v_role
  ) returning id into v_revision_id;
  insert into public.v1_delivery_order_revision_lines (
    delivery_order_revision_id, receipt_review_line_id, display_order,
    item_description, good_quantity, unit
  )
  select v_revision_id, review_line.id,
      row_number() over (order by dispatch_line.created_at)::integer,
      dispatch_line.item_description, review_line.good_qty, dispatch_line.unit
  from public.v1_receipt_review_lines review_line
  join public.v1_material_dispatch_lines dispatch_line
    on dispatch_line.id = review_line.dispatch_line_id
  where review_line.receipt_review_id = v_review.id and review_line.good_qty > 0
  order by dispatch_line.created_at;
  update public.v1_delivery_orders
     set current_revision_id = v_revision_id,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_delivery_order.id;
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    case when v_revision_number = 1 then 'delivery_order_generated'
      else 'delivery_order_superseded' end,
    'delivery_order_revision', v_revision_id, v_request.project_id, v_before,
    jsonb_build_object(
      'delivery_order_reference', v_reference,
      'revision_number', v_revision_number,
      'good_line_count', v_good_line_count
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_generate_delivery_order', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_save_material_return_draft(
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
  v_role text := public.v1_current_role();
  v_return_id uuid;
  v_request_id uuid;
  v_expected_version integer;
  v_note text;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_return public.v1_material_returns%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
  v_line jsonb;
  v_review_line_id uuid;
  v_return_qty numeric(18, 4);
  v_good_qty numeric(18, 4);
  v_dispatch_line public.v1_material_dispatch_lines%rowtype;
  v_display_order integer := 0;
  v_line_count integer;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'request_id', 'expected_version', 'note', 'lines'],
    'save_material_return_draft'
  );
  v_return_id := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_note := nullif(btrim(coalesce(p_payload ->> 'note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 0
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_RETURN_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_submit_material_return(v_request_id) then
    raise exception 'V1_RETURN_DRAFT_DENIED' using errcode = '42501';
  end if;
  if v_return_id is null then
    if v_expected_version <> 0 then
      raise exception 'V1_RETURN_DRAFT_VERSION_INVALID' using errcode = '40001';
    end if;
  else
    select * into v_return from public.v1_material_returns material_return
    where material_return.id = v_return_id and material_return.request_id = v_request.id
    for update;
    if not found or v_return.state <> 'draft'
      or (v_return.drafted_by_auth_user_id <> v_actor and v_role <> 'admin') then
      raise exception 'V1_RETURN_DRAFT_NOT_EDITABLE' using errcode = '42501';
    end if;
    if v_return.record_version <> v_expected_version then
      raise exception 'V1_RETURN_DRAFT_VERSION_INVALID' using errcode = '40001';
    end if;
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_material_return_draft', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  select count(*) into v_line_count from jsonb_array_elements(v_lines);
  if v_line_count = 0 or (
    select count(distinct nullif(btrim(coalesce(
      value ->> 'receipt_review_line_id', ''
    )), '')::uuid) from jsonb_array_elements(v_lines)
  ) <> v_line_count then
    raise exception 'V1_RETURN_DRAFT_LINES_INVALID' using errcode = '22023';
  end if;
  if v_return_id is null then
    insert into public.v1_material_returns (
      request_id, project_id, scope_id, note, drafted_by_auth_user_id, drafted_by_role
    ) values (
      v_request.id, v_request.project_id, v_request.scope_id, v_note, v_actor, v_role
    ) returning * into v_return;
    v_return_id := v_return.id;
  else
    update public.v1_material_returns
       set note = v_note, record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_return_id
     returning * into v_return;
    delete from public.v1_material_return_lines where material_return_id = v_return_id;
  end if;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line, array['receipt_review_line_id', 'return_qty'], 'material_return_draft_line'
    );
    v_review_line_id := nullif(btrim(coalesce(
      v_line ->> 'receipt_review_line_id', ''
    )), '')::uuid;
    v_return_qty := nullif(v_line ->> 'return_qty', '')::numeric(18, 4);
    if v_review_line_id is null or v_return_qty is null or v_return_qty <= 0 then
      raise exception 'V1_RETURN_DRAFT_LINE_INVALID' using errcode = '22023';
    end if;
    select review_line.good_qty into v_good_qty
    from public.v1_receipt_review_lines review_line
    join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
    where review_line.id = v_review_line_id and review.request_id = v_request.id
      and review.state = 'confirmed';
    select dispatch_line.* into v_dispatch_line
    from public.v1_material_dispatch_lines dispatch_line
    join public.v1_receipt_review_lines review_line
      on review_line.dispatch_line_id = dispatch_line.id
    where review_line.id = v_review_line_id;
    if v_good_qty is null or v_dispatch_line.id is null or v_good_qty <= 0
      or v_return_qty > v_good_qty then
      raise exception 'V1_RETURN_DRAFT_SOURCE_INVALID' using errcode = '22023';
    end if;
    v_display_order := v_display_order + 1;
    insert into public.v1_material_return_lines (
      material_return_id, receipt_review_line_id, dispatch_line_id, request_line_id,
      source_kind, source_inventory_item_id, item_description, brand_origin, unit,
      good_quantity_snapshot, return_quantity, display_order
    ) values (
      v_return_id, v_review_line_id, v_dispatch_line.id, v_dispatch_line.request_line_id,
      v_dispatch_line.source_kind, v_dispatch_line.inventory_item_id,
      v_dispatch_line.item_description, v_dispatch_line.brand_origin, v_dispatch_line.unit,
      v_good_qty, v_return_qty, v_display_order
    );
  end loop;
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_return_draft_saved', 'material_return', v_return_id, v_request.project_id,
    null, jsonb_build_object('line_count', v_line_count), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_material_return_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_submit_material_return(
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
  v_role text := public.v1_current_role();
  v_return_id uuid;
  v_expected_version integer;
  v_return public.v1_material_returns%rowtype;
  v_request public.v1_material_requests%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
  v_line public.v1_material_return_lines%rowtype;
  v_good_qty numeric(18, 4);
  v_confirmed_qty numeric(18, 4);
  v_sequence integer;
  v_number text;
  v_line_count integer := 0;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version'], 'submit_material_return'
  );
  v_return_id := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_return_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_RETURN_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_return.request_id for update;
  if not found or not public.v1_can_submit_material_return(v_return.request_id)
    or (v_return.drafted_by_auth_user_id <> v_actor and v_role <> 'admin') then
    raise exception 'V1_RETURN_SUBMIT_DENIED' using errcode = '42501';
  end if;
  for v_line in
    select return_line.* from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.receipt_review_line_id for update
  loop
    perform 1 from public.v1_receipt_review_lines review_line
    where review_line.id = v_line.receipt_review_line_id for update;
  end loop;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_submit_material_return', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_return.state <> 'draft' or v_return.record_version <> v_expected_version then
    raise exception 'V1_RETURN_SUBMIT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  for v_line in
    select return_line.* from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.receipt_review_line_id
  loop
    v_line_count := v_line_count + 1;
    select review_line.good_qty into v_good_qty
    from public.v1_receipt_review_lines review_line
    join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
    where review_line.id = v_line.receipt_review_line_id
      and review.request_id = v_request.id and review.state = 'confirmed';
    select coalesce(sum(other_line.return_quantity), 0) into v_confirmed_qty
    from public.v1_material_return_lines other_line
    join public.v1_material_returns other_return
      on other_return.id = other_line.material_return_id
    where other_line.receipt_review_line_id = v_line.receipt_review_line_id
      and other_return.state = 'confirmed';
    if v_good_qty is null or v_line.return_quantity > v_good_qty - v_confirmed_qty then
      raise exception 'V1_RETURN_ELIGIBLE_QTY_EXCEEDED' using errcode = '22023';
    end if;
    update public.v1_material_return_lines
       set eligible_quantity_at_submit = v_good_qty - v_confirmed_qty
     where id = v_line.id;
  end loop;
  if v_line_count = 0 then
    raise exception 'V1_RETURN_SUBMIT_LINES_REQUIRED' using errcode = '22023';
  end if;
  insert into public.v1_return_reference_counters (
    project_id, next_return_sequence, updated_at
  ) values (v_return.project_id, 2, clock_timestamp())
  on conflict (project_id) do update set
    next_return_sequence = public.v1_return_reference_counters.next_return_sequence + 1,
    updated_at = clock_timestamp()
  returning next_return_sequence - 1 into v_sequence;
  select project_ref || '-RTN' || lpad(v_sequence::text, 3, '0') into v_number
  from public.v1_projects where id = v_return.project_id;
  update public.v1_material_returns
     set state = 'submitted', return_number = v_number,
         submitted_by_auth_user_id = v_actor, submitted_by_role = v_role,
         submitted_at = clock_timestamp(), record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_return.id;
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id, 'material_return_submitted', 'material_return',
    v_return.id, v_return.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_return_submitted', 'material_return', v_return.id, v_return.project_id,
    null, jsonb_build_object('return_number', v_number, 'line_count', v_line_count),
    null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_submit_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_confirm_material_return(
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
  v_role text := public.v1_current_role();
  v_return_id uuid;
  v_expected_version integer;
  v_mappings jsonb;
  v_return public.v1_material_returns%rowtype;
  v_request public.v1_material_requests%rowtype;
  v_line public.v1_material_return_lines%rowtype;
  v_mapping jsonb;
  v_target_item_id uuid;
  v_new_item jsonb;
  v_existing_response jsonb;
  v_response jsonb;
  v_mapping_count integer;
  v_external_line_count integer;
  v_unit text;
  v_on_hand numeric(18, 4);
  v_item_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version', 'line_mappings'],
    'confirm_material_return'
  );
  v_return_id := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_mappings := coalesce(p_payload -> 'line_mappings', '[]'::jsonb);
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or jsonb_typeof(v_mappings) <> 'array' then
    raise exception 'V1_RETURN_CONFIRM_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_return.request_id for update;
  if not found or not public.v1_can_confirm_material_return(v_return.request_id) then
    raise exception 'V1_RETURN_CONFIRM_DENIED' using errcode = '42501';
  end if;
  for v_line in
    select return_line.* from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.receipt_review_line_id for update
  loop
    perform 1 from public.v1_receipt_review_lines review_line
    where review_line.id = v_line.receipt_review_line_id for update;
  end loop;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_confirm_material_return', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_return.state <> 'submitted' or v_return.record_version <> v_expected_version then
    raise exception 'V1_RETURN_CONFIRM_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select count(*) into v_external_line_count
  from public.v1_material_return_lines
  where material_return_id = v_return.id and source_kind = 'external_supplier';
  select count(*) into v_mapping_count from jsonb_array_elements(v_mappings);
  if v_mapping_count <> v_external_line_count or (
    select count(distinct nullif(btrim(coalesce(
      value ->> 'return_line_id', ''
    )), '')::uuid) from jsonb_array_elements(v_mappings)
  ) <> v_mapping_count then
    raise exception 'V1_RETURN_CONFIRM_MAPPINGS_INVALID' using errcode = '22023';
  end if;
  for v_line in
    select return_line.* from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.id
  loop
    if v_line.source_kind = 'warehouse' then
      update public.v1_material_return_lines
         set target_inventory_item_id = v_line.source_inventory_item_id
       where id = v_line.id;
    else
      select value into v_mapping from jsonb_array_elements(v_mappings)
      where nullif(btrim(coalesce(value ->> 'return_line_id', '')), '')::uuid = v_line.id;
      perform public.v1_assert_object_keys(
        v_mapping, array['return_line_id', 'inventory_item_id', 'new_inventory_item'],
        'material_return_mapping'
      );
      v_target_item_id := nullif(btrim(coalesce(
        v_mapping ->> 'inventory_item_id', ''
      )), '')::uuid;
      v_new_item := coalesce(v_mapping -> 'new_inventory_item', 'null'::jsonb);
      if (v_target_item_id is null and jsonb_typeof(v_new_item) <> 'object')
        or (v_target_item_id is not null and jsonb_typeof(v_new_item) <> 'null') then
        raise exception 'V1_RETURN_CONFIRM_MAPPING_REQUIRED' using errcode = '22023';
      end if;
      if v_target_item_id is not null then
        select item.unit into v_unit from public.v1_inventory_items item
        where item.id = v_target_item_id and item.is_active;
        if not found or lower(btrim(v_unit)) <> lower(btrim(v_line.unit)) then
          raise exception 'V1_RETURN_CONFIRM_TARGET_INVALID' using errcode = '22023';
        end if;
      else
        perform public.v1_assert_object_keys(
          v_new_item, array['item_description', 'brand_origin', 'unit'],
          'new_return_inventory_item'
        );
        if nullif(btrim(coalesce(v_new_item ->> 'item_description', '')), '') is null
          or nullif(btrim(coalesce(v_new_item ->> 'unit', '')), '') is null
          or lower(btrim(v_new_item ->> 'unit')) <> lower(btrim(v_line.unit)) then
          raise exception 'V1_RETURN_CONFIRM_NEW_TARGET_INVALID' using errcode = '22023';
        end if;
        select item.id into v_target_item_id
        from public.v1_inventory_items item
        where lower(btrim(item.item_description)) = lower(btrim(v_new_item ->> 'item_description'))
          and lower(coalesce(btrim(item.brand_origin), '')) = lower(coalesce(
            btrim(nullif(v_new_item ->> 'brand_origin', '')), ''
          ))
          and lower(btrim(item.unit)) = lower(btrim(v_new_item ->> 'unit'))
          and item.is_active;
        if not found then
          insert into public.v1_inventory_items (
            item_description, brand_origin, unit, created_by_auth_user_id
          ) values (
            btrim(v_new_item ->> 'item_description'),
            nullif(btrim(coalesce(v_new_item ->> 'brand_origin', '')), ''),
            btrim(v_new_item ->> 'unit'), v_actor
          ) returning id into v_target_item_id;
          insert into public.v1_inventory_balances (inventory_item_id)
          values (v_target_item_id);
        end if;
      end if;
      update public.v1_material_return_lines
         set target_inventory_item_id = v_target_item_id
       where id = v_line.id;
    end if;
  end loop;
  for v_item_id in
    select distinct return_line.target_inventory_item_id
    from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id
    order by return_line.target_inventory_item_id
  loop
    perform 1 from public.v1_inventory_balances balance
    join public.v1_inventory_items item on item.id = balance.inventory_item_id
    where balance.inventory_item_id = v_item_id and item.is_active
    for update of balance;
    if not found then
      raise exception 'V1_RETURN_CONFIRM_TARGET_INACTIVE' using errcode = '22023';
    end if;
  end loop;
  for v_line in
    select return_line.* from public.v1_material_return_lines return_line
    where return_line.material_return_id = v_return.id order by return_line.id
  loop
    select balance.on_hand_qty into v_on_hand
    from public.v1_inventory_balances balance
    where balance.inventory_item_id = v_line.target_inventory_item_id;
    update public.v1_inventory_balances
       set on_hand_qty = on_hand_qty + v_line.return_quantity,
           record_version = record_version + 1, updated_at = clock_timestamp()
     where inventory_item_id = v_line.target_inventory_item_id;
    insert into public.v1_inventory_movements (
      inventory_item_id, movement_type, quantity_delta, on_hand_after_qty,
      source_entity_type, source_entity_id, reason, actor_auth_user_id,
      idempotency_key
    ) values (
      v_line.target_inventory_item_id, 'return', v_line.return_quantity,
      v_on_hand + v_line.return_quantity, 'material_return_line', v_line.id,
      'Confirmed return ' || v_return.return_number, v_actor, p_idempotency_key
    );
  end loop;
  update public.v1_material_returns
     set state = 'confirmed', decided_by_auth_user_id = v_actor,
         decided_by_role = v_role, decided_at = clock_timestamp(),
         record_version = record_version + 1, updated_at = clock_timestamp()
   where id = v_return.id;
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_return_confirmed', 'material_return', v_return.id, v_return.project_id,
    null, jsonb_build_object('return_number', v_return.return_number), null,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_reject_material_return(
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
  v_role text := public.v1_current_role();
  v_return_id uuid;
  v_expected_version integer;
  v_reason text;
  v_return public.v1_material_returns%rowtype;
  v_request public.v1_material_requests%rowtype;
  v_existing_response jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['return_id', 'expected_version', 'reason'],
    'reject_material_return'
  );
  v_return_id := nullif(btrim(coalesce(p_payload ->> 'return_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_return_id is null or v_expected_version is null or v_expected_version < 1
    or v_reason is null then
    raise exception 'V1_RETURN_REJECT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_return from public.v1_material_returns material_return
  where material_return.id = v_return_id for update;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_return.request_id for update;
  if not found or not public.v1_can_confirm_material_return(v_return.request_id) then
    raise exception 'V1_RETURN_REJECT_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_reject_material_return', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_return.state <> 'submitted' or v_return.record_version <> v_expected_version then
    raise exception 'V1_RETURN_REJECT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  update public.v1_material_returns
     set state = 'rejected', decided_by_auth_user_id = v_actor,
         decided_by_role = v_role, decided_at = clock_timestamp(),
         rejection_reason = v_reason, record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_return.id;
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_return_rejected', 'material_return', v_return.id, v_return.project_id,
    null, jsonb_build_object('return_number', v_return.return_number), v_reason,
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_reject_material_return', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_generate_delivery_order(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_submit_material_return(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_confirm_material_return(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_returns_documents_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_delivery_order_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_returns_documents_workspace_projection(uuid)
  from public, anon;
revoke all on function public.v1_generate_delivery_order(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_save_material_return_draft(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_submit_material_return(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_confirm_material_return(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_reject_material_return(jsonb, uuid)
  from public, anon;

grant execute on function public.v1_returns_documents_workspace_projection(uuid)
  to authenticated;
grant execute on function public.v1_generate_delivery_order(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_save_material_return_draft(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_submit_material_return(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_confirm_material_return(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_reject_material_return(jsonb, uuid)
  to authenticated;
