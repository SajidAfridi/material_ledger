-- Yorks V1 Batch 5: Material Request drafts and explicit submission. This is
-- additive and intentionally separate from the retained local material-request
-- store. Drafts are private; submission is the first Procurement-visible event.

create table if not exists public.v1_material_requests (
  id uuid primary key,
  project_id uuid not null references public.v1_projects (id) on delete restrict,
  scope_id uuid not null references public.v1_project_scopes (id) on delete restrict,
  request_number text unique,
  title text,
  timing text not null default 'normal'
    check (timing in ('urgent', 'normal', 'scheduled')),
  scheduled_date date,
  delivery_note text,
  state text not null default 'draft'
    check (state in (
      'draft', 'submitted', 'arranging', 'awaiting_approval', 'approved',
      'partially_dispatched', 'dispatched', 'partially_received', 'received',
      'closed', 'cancelled'
    )),
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  requester_display_name text,
  requester_project_role text check (requester_project_role is null or
    requester_project_role in ('project_engineer', 'site_engineer')),
  current_action_owner_role text not null default 'project_engineer'
    check (current_action_owner_role in (
      'project_engineer', 'site_engineer', 'procurement', 'admin', 'none'
    )),
  current_action_code text not null default 'draft_owner',
  submitted_at timestamptz,
  cancelled_at timestamptz,
  cancelled_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  cancellation_reason text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (timing = 'scheduled' and scheduled_date is not null)
    or (timing in ('urgent', 'normal') and scheduled_date is null)
  ),
  check (
    (state = 'draft' and request_number is null and submitted_at is null)
    or (state <> 'draft' and request_number is not null and submitted_at is not null)
  ),
  check (
    (state = 'cancelled' and cancelled_at is not null
      and cancelled_by_auth_user_id is not null
      and cancellation_reason is not null
      and btrim(cancellation_reason) <> '')
    or (state <> 'cancelled' and cancelled_at is null
      and cancelled_by_auth_user_id is null and cancellation_reason is null)
  )
);

create index if not exists v1_material_requests_project_state_updated_idx
  on public.v1_material_requests (project_id, state, updated_at desc);
create unique index if not exists v1_material_requests_project_number_unique_idx
  on public.v1_material_requests (project_id, request_number)
  where request_number is not null;
create index if not exists v1_material_requests_creator_drafts_idx
  on public.v1_material_requests (created_by_auth_user_id, updated_at desc)
  where state = 'draft';

create table if not exists public.v1_material_request_lines (
  id uuid primary key,
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  display_order integer not null check (display_order > 0),
  source_kind text not null check (source_kind in ('boq', 'excel', 'custom')),
  source_boq_group_id uuid references public.v1_boq_groups (id) on delete restrict,
  source_boq_row_id uuid references public.v1_boq_rows (id) on delete restrict,
  item_description text not null check (btrim(item_description) <> ''),
  brand_origin text,
  requested_qty numeric(18, 4) not null check (requested_qty > 0),
  unit text not null check (btrim(unit) <> ''),
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  unique (request_id, display_order),
  check (
    (source_kind = 'boq' and source_boq_group_id is not null
      and source_boq_row_id is not null)
    or (source_kind in ('excel', 'custom') and source_boq_group_id is null
      and source_boq_row_id is null)
  )
);

create index if not exists v1_material_request_lines_request_idx
  on public.v1_material_request_lines (request_id, display_order);

-- Cost is physically isolated from the operational line. A non-commercial
-- projection has no unit-cost, total-cost or currency key at all.
create table if not exists public.v1_material_request_line_commercials (
  request_line_id uuid primary key references public.v1_material_request_lines (id)
    on delete restrict,
  unit_cost numeric(18, 4) not null check (unit_cost >= 0),
  currency_code text not null default 'AED'
    check (currency_code ~ '^[A-Z]{3}$'),
  updated_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_material_request_reference_counters (
  project_id uuid primary key references public.v1_projects (id) on delete restrict,
  next_request_sequence integer not null default 1 check (next_request_sequence > 0),
  updated_at timestamptz not null default clock_timestamp()
);

-- Notifications contain event codes and entity IDs only. They never cache an
-- operational or commercial request projection.
create table if not exists public.v1_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  event_code text not null check (btrim(event_code) <> ''),
  entity_type text not null check (btrim(entity_type) <> ''),
  entity_id uuid not null,
  project_id uuid references public.v1_projects (id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  seen_at timestamptz
);

create index if not exists v1_notifications_recipient_created_idx
  on public.v1_notifications (recipient_auth_user_id, created_at desc);

alter table public.v1_material_requests enable row level security;
alter table public.v1_material_request_lines enable row level security;
alter table public.v1_material_request_line_commercials enable row level security;
alter table public.v1_material_request_reference_counters enable row level security;
alter table public.v1_notifications enable row level security;

revoke all on table public.v1_material_requests from public, anon, authenticated;
revoke all on table public.v1_material_request_lines from public, anon, authenticated;
revoke all on table public.v1_material_request_line_commercials from public, anon, authenticated;
revoke all on table public.v1_material_request_reference_counters from public, anon, authenticated;
revoke all on table public.v1_notifications from public, anon, authenticated;
grant all on table public.v1_material_requests to service_role;
grant all on table public.v1_material_request_lines to service_role;
grant all on table public.v1_material_request_line_commercials to service_role;
grant all on table public.v1_material_request_reference_counters to service_role;
grant all on table public.v1_notifications to service_role;

create or replace function public.v1_can_create_material_request(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_state text;
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select state into v_state from public.v1_projects where id = p_project_id;
  if v_state not in ('draft', 'active') then return false; end if;
  if v_role = 'admin' then return true; end if;
  return v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(p_project_id, v_actor, null);
end;
$$;

create or replace function public.v1_material_request_readable(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_project_state text;
begin
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found or v_actor is null or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_request.state = 'draft' then
    return v_request.created_by_auth_user_id = v_actor;
  end if;
  if v_role = 'admin' then return true; end if;
  if v_role in ('project_engineer', 'site_engineer') then
    return public.v1_has_active_project_membership(
      v_request.project_id, v_actor, null
    );
  end if;
  if v_role = 'procurement' then
    select state into v_project_state from public.v1_projects
    where id = v_request.project_id;
    return v_project_state in ('active', 'on_hold', 'completed');
  end if;
  return false;
end;
$$;

create or replace function public.v1_material_request_line_projection(
  p_line_id uuid,
  p_include_commercial boolean
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', line_record.id,
    'display_order', line_record.display_order,
    'source_kind', line_record.source_kind,
    'source_boq_group_id', line_record.source_boq_group_id,
    'source_boq_row_id', line_record.source_boq_row_id,
    'item_description', line_record.item_description,
    'brand_origin', line_record.brand_origin,
    'requested_qty', line_record.requested_qty::text,
    'unit', line_record.unit
  ) || case when p_include_commercial then jsonb_strip_nulls(
    jsonb_build_object(
      'unit_cost', commercial.unit_cost::text,
      'total_cost', (line_record.requested_qty * commercial.unit_cost)::text,
      'currency_code', commercial.currency_code
    )
  ) else '{}'::jsonb end
  from public.v1_material_request_lines line_record
  left join public.v1_material_request_line_commercials commercial
    on commercial.request_line_id = line_record.id
  where line_record.id = p_line_id;
$$;

create or replace function public.v1_material_request_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_include_commercial boolean := public.v1_has_capability('view_commercials');
  v_result jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'scope_id', request_record.scope_id,
    'scope_name', scope.name,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'request_number', request_record.request_number,
    'title', request_record.title,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_note', request_record.delivery_note,
    'requester_display_name', request_record.requester_display_name,
    'requester_project_role', request_record.requester_project_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        public.v1_material_request_line_projection(line_record.id, v_include_commercial)
        order by line_record.display_order
      )
      from public.v1_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

create or replace function public.v1_list_material_request_projects()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin') then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_LIST_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', project.id,
      'project_ref', project.project_ref,
      'name', project.name,
      'state', project.state
    ) order by lower(project.project_ref), lower(project.name))
    from public.v1_projects project
    where project.state in ('draft', 'active')
      and (
        v_role = 'admin'
        or public.v1_has_active_project_membership(project.id, v_actor, null)
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_list_material_request_scopes(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_project_id is null or not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_LIST_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', scope.id,
      'project_id', scope.project_id,
      'scope_kind', scope.scope_kind,
      'code', scope.scope_code,
      'name', scope.name,
      'is_active', scope.is_active,
      'delivery_address', scope.delivery_address
    ) order by case when scope.scope_kind = 'common' then 0 else 1 end,
      lower(scope.scope_code))
    from public.v1_project_scopes scope
    where scope.project_id = p_project_id and scope.is_active
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_list_material_requests(
  p_project_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_REQUEST_LIST_DENIED' using errcode = '42501';
  end if;
  if p_project_id is not null and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.v1_material_request_projection(request_record.id)
      order by request_record.updated_at desc)
    from public.v1_material_requests request_record
    join public.v1_projects project on project.id = request_record.project_id
    where (p_project_id is null or request_record.project_id = p_project_id)
      and (
        (request_record.state = 'draft'
          and request_record.created_by_auth_user_id = v_actor)
        or (request_record.state <> 'draft' and v_role = 'admin')
        or (request_record.state <> 'draft'
          and v_role in ('project_engineer', 'site_engineer')
          and public.v1_has_active_project_membership(
            request_record.project_id, v_actor, null
          ))
        or (request_record.state <> 'draft' and v_role = 'procurement'
          and project.state in ('active', 'on_hold', 'completed'))
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_save_material_request_draft(
  p_payload jsonb
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
  v_expected_version integer;
  v_project_id uuid;
  v_scope_id uuid;
  v_title text;
  v_timing text;
  v_scheduled_date date;
  v_delivery_note text;
  v_lines jsonb;
  v_existing public.v1_material_requests%rowtype;
  v_request_exists boolean := false;
  v_line jsonb;
  v_line_id uuid;
  v_line_order integer;
  v_source_kind text;
  v_source_group_id uuid;
  v_source_row_id uuid;
  v_description text;
  v_brand_origin text;
  v_requested_qty numeric(18, 4);
  v_unit text;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'request_id', 'expected_version', 'project_id', 'scope_id', 'title',
      'timing', 'scheduled_date', 'delivery_note', 'lines'
    ],
    'material_request_draft'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_title := nullif(btrim(coalesce(p_payload ->> 'title', '')), '');
  v_timing := coalesce(p_payload ->> 'timing', '');
  v_scheduled_date := nullif(p_payload ->> 'scheduled_date', '')::date;
  v_delivery_note := nullif(btrim(coalesce(p_payload ->> 'delivery_note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 0
    or v_project_id is null or v_scope_id is null
    or v_timing not in ('urgent', 'normal', 'scheduled')
    or jsonb_typeof(v_lines) <> 'array'
    or (v_timing = 'scheduled' and v_scheduled_date is null)
    or (v_timing <> 'scheduled' and v_scheduled_date is not null) then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  if not public.v1_can_create_material_request(v_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = v_scope_id and scope.project_id = v_project_id
      and scope.is_active
  ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;

  select * into v_existing from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  v_request_exists := found;
  if v_request_exists then
    if v_existing.state <> 'draft'
      or v_existing.created_by_auth_user_id <> v_actor then
      raise exception 'V1_MATERIAL_REQUEST_DRAFT_EDIT_DENIED' using errcode = '42501';
    end if;
    if v_existing.record_version <> v_expected_version then
      raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
    end if;
  elsif v_expected_version <> 0 then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;

  -- Validate every submitted line before replacing an editable draft snapshot.
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array[
        'id', 'display_order', 'source_kind', 'source_boq_group_id',
        'source_boq_row_id', 'item_description', 'brand_origin',
        'requested_qty', 'unit'
      ],
      'material_request_line'
    );
    v_line_id := nullif(btrim(coalesce(v_line ->> 'id', '')), '')::uuid;
    v_line_order := nullif(v_line ->> 'display_order', '')::integer;
    v_source_kind := coalesce(v_line ->> 'source_kind', '');
    v_source_group_id := nullif(
      btrim(coalesce(v_line ->> 'source_boq_group_id', '')), ''
    )::uuid;
    v_source_row_id := nullif(
      btrim(coalesce(v_line ->> 'source_boq_row_id', '')), ''
    )::uuid;
    v_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_brand_origin := nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), '');
    v_requested_qty := nullif(v_line ->> 'requested_qty', '')::numeric(18, 4);
    v_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    if v_line_id is null or v_line_order is null or v_line_order < 1
      or v_source_kind not in ('boq', 'excel', 'custom')
      or v_description is null or v_requested_qty is null or v_requested_qty <= 0
      or v_unit is null then
      raise exception 'V1_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end if;
    if v_source_kind = 'boq' then
      if v_source_group_id is null or v_source_row_id is null or not exists (
        select 1
        from public.v1_boq_groups group_record
        join public.v1_boq_rows row_record on row_record.group_id = group_record.id
        where group_record.id = v_source_group_id
          and group_record.project_id = v_project_id
          and row_record.id = v_source_row_id
      ) then
        raise exception 'V1_MATERIAL_REQUEST_BOQ_SOURCE_INVALID' using errcode = '22023';
      end if;
    elsif v_source_group_id is not null or v_source_row_id is not null then
      raise exception 'V1_MATERIAL_REQUEST_SOURCE_INVALID' using errcode = '22023';
    end if;
  end loop;

  if v_request_exists then
    update public.v1_material_requests
       set project_id = v_project_id,
           scope_id = v_scope_id,
           title = v_title,
           timing = v_timing,
           scheduled_date = v_scheduled_date,
           delivery_note = v_delivery_note,
           record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_request_id;
  else
    insert into public.v1_material_requests (
      id, project_id, scope_id, title, timing, scheduled_date, delivery_note,
      state, record_version, created_by_auth_user_id,
      current_action_owner_role, current_action_code, created_at, updated_at
    ) values (
      v_request_id, v_project_id, v_scope_id, v_title, v_timing,
      v_scheduled_date, v_delivery_note, 'draft', 1, v_actor,
      case when v_role = 'admin' then 'admin' else v_role end,
      'draft_owner', clock_timestamp(), clock_timestamp()
    );
  end if;

  delete from public.v1_material_request_lines where request_id = v_request_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.v1_material_request_lines (
      id, request_id, display_order, source_kind, source_boq_group_id,
      source_boq_row_id, item_description, brand_origin, requested_qty, unit,
      created_at, updated_at
    ) values (
      (v_line ->> 'id')::uuid,
      v_request_id,
      (v_line ->> 'display_order')::integer,
      v_line ->> 'source_kind',
      nullif(v_line ->> 'source_boq_group_id', '')::uuid,
      nullif(v_line ->> 'source_boq_row_id', '')::uuid,
      btrim(v_line ->> 'item_description'),
      nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), ''),
      (v_line ->> 'requested_qty')::numeric(18, 4),
      btrim(v_line ->> 'unit'),
      clock_timestamp(), clock_timestamp()
    );
  end loop;
  return public.v1_material_request_projection(v_request_id);
end;
$$;

create or replace function public.v1_delete_material_request_draft(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
begin
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = p_request_id for update;
  if not found then return jsonb_build_object('deleted', false); end if;
  if v_request.state <> 'draft' or v_request.created_by_auth_user_id <> auth.uid() then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_DELETE_DENIED' using errcode = '42501';
  end if;
  delete from public.v1_material_request_lines where request_id = p_request_id;
  delete from public.v1_material_requests where id = p_request_id;
  return jsonb_build_object('deleted', true, 'request_id', p_request_id);
end;
$$;

create or replace function public.v1_submit_material_request(
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
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_project public.v1_projects%rowtype;
  v_project_role text;
  v_sequence integer;
  v_request_number text;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_display_name text;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'submit_material_request'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or v_request.created_by_auth_user_id <> v_actor then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  select * into v_project from public.v1_projects project
  where project.id = v_request.project_id for update;
  if not found or v_project.state <> 'active'
    or not public.v1_can_create_material_request(v_project.id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_SUBMITTABLE' using errcode = '42501';
  end if;
  -- Authenticate the same active creator and project again before returning a
  -- completed retry. The original state may already be submitted by then.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_submit_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state <> 'draft' then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = v_request.scope_id and scope.project_id = v_project.id
      and scope.is_active
  ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.v1_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_LINES_REQUIRED' using errcode = '22023';
  end if;
  if v_request.timing = 'scheduled' and v_request.scheduled_date is null then
    raise exception 'V1_MATERIAL_REQUEST_SCHEDULED_DATE_REQUIRED' using errcode = '22023';
  end if;

  select member.project_role into v_project_role
  from public.v1_project_members member
  where member.project_id = v_project.id and member.member_auth_user_id = v_actor
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
  order by case member.project_role when 'project_engineer' then 0 else 1 end
  limit 1;
  if v_project_role is null and public.v1_current_role() <> 'admin' then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into v_display_name
  from public.v1_profiles profile where profile.auth_user_id = v_actor;

  insert into public.v1_material_request_reference_counters (
    project_id, next_request_sequence, updated_at
  ) values (v_project.id, 2, clock_timestamp())
  on conflict (project_id) do update set
    next_request_sequence = public.v1_material_request_reference_counters.next_request_sequence + 1,
    updated_at = clock_timestamp()
  returning next_request_sequence - 1 into v_sequence;
  v_request_number := v_project.project_ref || '-MR' || lpad(v_sequence::text, 3, '0');
  v_before := public.v1_material_request_projection(v_request.id);

  update public.v1_material_requests
     set request_number = v_request_number,
         state = 'submitted',
         requester_display_name = v_display_name,
         requester_project_role = coalesce(v_project_role, 'project_engineer'),
         current_action_owner_role = 'procurement',
         current_action_code = 'arrangement_required',
         submitted_at = clock_timestamp(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_request.id;
  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_submitted', 'material_request', v_request.id, v_project.id,
    v_before,
    jsonb_build_object(
      'request_number', v_request_number,
      'record_version', v_expected_version + 1,
      'line_count', (select count(*) from public.v1_material_request_lines
        where request_id = v_request.id),
      'state', 'submitted',
      'current_action_owner_role', 'procurement'
    ),
    null, p_idempotency_key
  );
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id, created_at
  )
  select profile.auth_user_id, 'material_request_submitted', 'material_request',
    v_request.id, v_project.id, clock_timestamp()
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  perform public.v1_complete_idempotency(
    'v1_submit_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_cancel_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version', 'reason'],
    'cancel_material_request'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_version is null or v_reason is null then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or v_request.state <> 'submitted' then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_NOT_ELIGIBLE' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if public.v1_current_role() <> 'admin' and not (
    public.v1_current_role() in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      v_request.project_id, auth.uid(), 'project_engineer'
    )
  ) then
    raise exception 'V1_MATERIAL_REQUEST_CANCEL_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_cancel_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  v_before := public.v1_material_request_projection(v_request.id);
  update public.v1_material_requests
     set state = 'cancelled',
         current_action_owner_role = 'none',
         current_action_code = 'cancelled',
         cancelled_at = clock_timestamp(),
         cancelled_by_auth_user_id = auth.uid(),
         cancellation_reason = v_reason,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_request.id;
  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_cancelled', 'material_request', v_request.id,
    v_request.project_id, v_before,
    jsonb_build_object('state', 'cancelled',
      'record_version', v_expected_version + 1),
    v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_cancel_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_create_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_line_projection(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_projection(uuid)
  from public, anon;
revoke all on function public.v1_list_material_request_projects()
  from public, anon;
revoke all on function public.v1_list_material_request_scopes(uuid)
  from public, anon;
revoke all on function public.v1_list_material_requests(uuid)
  from public, anon;
revoke all on function public.v1_save_material_request_draft(jsonb)
  from public, anon;
revoke all on function public.v1_delete_material_request_draft(uuid)
  from public, anon;
revoke all on function public.v1_submit_material_request(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_cancel_material_request(jsonb, uuid)
  from public, anon;

grant execute on function public.v1_material_request_projection(uuid)
  to authenticated;
grant execute on function public.v1_list_material_request_projects()
  to authenticated;
grant execute on function public.v1_list_material_request_scopes(uuid)
  to authenticated;
grant execute on function public.v1_list_material_requests(uuid)
  to authenticated;
grant execute on function public.v1_save_material_request_draft(jsonb)
  to authenticated;
grant execute on function public.v1_delete_material_request_draft(uuid)
  to authenticated;
grant execute on function public.v1_submit_material_request(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_cancel_material_request(jsonb, uuid)
  to authenticated;
