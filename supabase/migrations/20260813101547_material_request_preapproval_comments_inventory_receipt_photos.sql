-- Yorks R35 Material Request flow revision (2026-08-13).
--
-- Data preservation:
-- * additive decision/comment/mention relations only;
-- * submitted requests without Procurement facts move to Engineering review;
-- * arranging/awaiting_approval requests remain on their recorded legacy path;
-- * no reservation, movement, dispatch, receipt, document or audit row is
--   deleted or reinterpreted.
--
-- Rollback is forward-only. Disable the revised client, then ship a corrective
-- migration; never drop the new immutable history relations.

alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_state_check;
alter table public.v1_material_requests
  add constraint v1_material_requests_state_check check (state in (
    'draft', 'submitted', 'awaiting_request_approval', 'changes_requested',
    'approved_for_arrangement', 'arranging', 'awaiting_approval', 'approved',
    'partially_dispatched', 'dispatched', 'partially_received', 'received',
    'closed', 'cancelled'
  ));

create table if not exists public.v1_material_request_decisions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  request_record_version integer not null check (request_record_version > 0),
  decision text not null check (decision in ('approved', 'returned')),
  reason text,
  decided_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  decided_by_role text not null check (decided_by_role in (
    'project_engineer', 'admin'
  )),
  decided_by_exact_role text not null check (decided_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )),
  decided_by_display_name_snapshot text not null
    check (btrim(decided_by_display_name_snapshot) <> ''),
  created_at timestamptz not null default clock_timestamp(),
  check (
    (decision = 'approved' and reason is null)
    or (decision = 'returned' and reason is not null and btrim(reason) <> '')
  )
);

create index if not exists v1_material_request_decisions_request_time_idx
  on public.v1_material_request_decisions (request_id, created_at desc);
create unique index if not exists v1_material_request_one_current_approval_idx
  on public.v1_material_request_decisions (request_id)
  where decision = 'approved';

create table if not exists public.v1_material_request_comments (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  body text not null check (btrim(body) <> '' and length(body) <= 4000),
  author_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  author_role text not null check (author_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  author_exact_role text not null check (author_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )),
  author_display_name_snapshot text not null
    check (btrim(author_display_name_snapshot) <> ''),
  created_at timestamptz not null default clock_timestamp()
);

create index if not exists v1_material_request_comments_request_time_idx
  on public.v1_material_request_comments (request_id, created_at, id);

create table if not exists public.v1_material_request_comment_mentions (
  comment_id uuid not null references public.v1_material_request_comments (id)
    on delete restrict,
  mentioned_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  mentioned_display_name_snapshot text not null
    check (btrim(mentioned_display_name_snapshot) <> ''),
  mentioned_exact_role text not null check (mentioned_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )),
  created_at timestamptz not null default clock_timestamp(),
  primary key (comment_id, mentioned_auth_user_id)
);

alter table public.v1_material_request_decisions enable row level security;
alter table public.v1_material_request_comments enable row level security;
alter table public.v1_material_request_comment_mentions enable row level security;

revoke all on table public.v1_material_request_decisions
  from public, anon, authenticated;
revoke all on table public.v1_material_request_comments
  from public, anon, authenticated;
revoke all on table public.v1_material_request_comment_mentions
  from public, anon, authenticated;
grant select on table public.v1_material_request_decisions to authenticated;
grant select on table public.v1_material_request_comments to authenticated;
grant select on table public.v1_material_request_comment_mentions to authenticated;
grant all on table public.v1_material_request_decisions to service_role;
grant all on table public.v1_material_request_comments to service_role;
grant all on table public.v1_material_request_comment_mentions to service_role;

create or replace function public.v1_material_request_participant(
  p_request_id uuid,
  p_auth_user_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text;
begin
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found or p_auth_user_id is null or not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = p_auth_user_id and profile.is_active
  ) then
    return false;
  end if;

  select coalesce(user_record.raw_app_meta_data ->> 'role', '')
    into v_exact_role
  from auth.users user_record
  where user_record.id = p_auth_user_id;

  if v_exact_role = 'admin' then return true; end if;
  if v_exact_role in ('senior_mechanical_engineer', 'project_manager') then
    return true;
  end if;
  if v_exact_role in ('project_engineer', 'site_engineer') then
    return exists (
      select 1 from public.v1_project_members member
      where member.project_id = v_request.project_id
        and member.member_auth_user_id = p_auth_user_id
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null or member.effective_to > clock_timestamp())
    );
  end if;
  if v_exact_role = 'procurement' then
    return v_request.state in (
      'submitted', 'approved_for_arrangement', 'arranging',
      'awaiting_approval', 'approved',
      'partially_dispatched', 'dispatched', 'partially_received', 'received',
      'closed', 'cancelled'
    );
  end if;
  return false;
end;
$$;

create or replace function public.v1_material_request_readable(
  p_request_id uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and public.v1_material_request_participant(p_request_id, auth.uid());
$$;

drop policy if exists v1_material_request_decisions_select_authorized
  on public.v1_material_request_decisions;
create policy v1_material_request_decisions_select_authorized
on public.v1_material_request_decisions for select to authenticated
using (public.v1_material_request_readable(request_id));

drop policy if exists v1_material_request_comments_select_authorized
  on public.v1_material_request_comments;
create policy v1_material_request_comments_select_authorized
on public.v1_material_request_comments for select to authenticated
using (public.v1_material_request_readable(request_id));

drop policy if exists v1_material_request_comment_mentions_select_authorized
  on public.v1_material_request_comment_mentions;
create policy v1_material_request_comment_mentions_select_authorized
on public.v1_material_request_comment_mentions for select to authenticated
using (exists (
  select 1 from public.v1_material_request_comments comment_record
  where comment_record.id = comment_id
    and public.v1_material_request_readable(comment_record.request_id)
));

create or replace function public.v1_can_decide_material_request(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or v_role not in ('project_engineer', 'admin')
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request from public.v1_material_requests where id = p_request_id;
  if not found then return false; end if;
  return v_role = 'admin' or public.v1_has_active_project_membership(
    v_request.project_id, auth.uid(), 'project_engineer'
  );
end;
$$;

create or replace function public.v1_can_edit_material_request_before_approval(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request from public.v1_material_requests where id = p_request_id;
  if not found or v_request.state not in (
    'awaiting_request_approval', 'changes_requested'
  ) or exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = p_request_id
  ) then
    return false;
  end if;
  if v_request.created_by_auth_user_id = auth.uid() then return true; end if;
  return v_role = 'admin' or (
    v_role = 'project_engineer' and public.v1_has_active_project_membership(
      v_request.project_id, auth.uid(), 'project_engineer'
    )
  );
end;
$$;

create or replace function public.v1_material_request_comment_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', comment_record.id,
    'request_id', comment_record.request_id,
    'body', comment_record.body,
    'author_auth_user_id', comment_record.author_auth_user_id,
    'author_role', comment_record.author_role,
    'author_exact_role', comment_record.author_exact_role,
    'author_display_name', comment_record.author_display_name_snapshot,
    'created_at', comment_record.created_at,
    'mentions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', mention.mentioned_auth_user_id,
        'display_name', mention.mentioned_display_name_snapshot,
        'exact_role', mention.mentioned_exact_role
      ) order by mention.mentioned_display_name_snapshot)
      from public.v1_material_request_comment_mentions mention
      where mention.comment_id = comment_record.id
    ), '[]'::jsonb)
  ) order by comment_record.created_at, comment_record.id), '[]'::jsonb)
  from public.v1_material_request_comments comment_record
  where comment_record.request_id = p_request_id;
$$;

create or replace function public.v1_material_request_projection(
  p_request_id uuid
) returns jsonb
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
    'job_contract_reference', project.job_contract_reference,
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
    'requester_exact_role', request_record.requester_exact_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'can_edit_before_approval',
      public.v1_can_edit_material_request_before_approval(request_record.id),
    'can_decide_request', public.v1_can_decide_material_request(request_record.id)
      and request_record.state = 'awaiting_request_approval',
    'request_decision', (
      select jsonb_build_object(
        'id', decision.id,
        'decision', decision.decision,
        'reason', decision.reason,
        'request_record_version', decision.request_record_version,
        'decided_by_display_name', decision.decided_by_display_name_snapshot,
        'decided_by_role', decision.decided_by_role,
        'decided_by_exact_role', decision.decided_by_exact_role,
        'decided_at', decision.created_at
      )
      from public.v1_material_request_decisions decision
      where decision.request_id = request_record.id
      order by decision.created_at desc, decision.id desc limit 1
    ),
    'comments', public.v1_material_request_comment_projection(request_record.id),
    'lines', coalesce((
      select jsonb_agg(public.v1_material_request_line_projection(
        line_record.id, v_include_commercial
      ) order by line_record.display_order)
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

create or replace function public.v1_list_material_requests(
  p_project_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_REQUEST_LIST_DENIED' using errcode = '42501';
  end if;
  if p_project_id is not null and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.v1_material_request_projection(request_record.id)
      order by request_record.updated_at desc)
    from public.v1_material_requests request_record
    where (p_project_id is null or request_record.project_id = p_project_id)
      and public.v1_material_request_participant(request_record.id, auth.uid())
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_list_material_request_mention_candidates(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_MENTION_DIRECTORY_DENIED'
      using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'auth_user_id', profile.auth_user_id,
      'display_name', public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      ),
      'exact_role', user_record.raw_app_meta_data ->> 'role'
    ) order by lower(profile.display_name), profile.auth_user_id)
    from public.v1_profiles profile
    join auth.users user_record on user_record.id = profile.auth_user_id
    where profile.is_active
      and public.v1_material_request_participant(p_request_id, profile.auth_user_id)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_search_material_request_inventory_items(
  p_project_id uuid,
  p_query text,
  p_limit integer default 12
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := btrim(coalesce(p_query, ''));
  v_limit integer := least(greatest(coalesce(p_limit, 12), 1), 20);
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin')
    or (
      v_role <> 'admin'
      and not public.v1_has_active_project_membership(
        p_project_id, auth.uid(), null
      )
    )
    or length(v_query) < 2 then
    raise exception 'V1_MATERIAL_REQUEST_INVENTORY_SEARCH_DENIED'
      using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', ranked.id,
      'item_code', ranked.item_code,
      'item_description', ranked.item_description,
      'brand_origin', ranked.brand_origin,
      'size', ranked.size_text,
      'model', ranked.model_reference,
      'unit', ranked.unit
    ) order by ranked.match_rank, ranked.item_description, ranked.id)
    from (
      select item.id, item.item_code, item.item_description, item.brand_origin,
        item.size_text, item.model_reference, item.unit,
        case
          when lower(item.item_code) = lower(v_query) then 0
          when lower(item.item_description) = lower(v_query) then 1
          when lower(item.item_description) like lower(v_query) || '%' then 2
          when lower(coalesce(item.item_code, '')) like lower(v_query) || '%' then 3
          else 4
        end as match_rank
      from public.v1_inventory_items item
      where item.is_active and (
        item.item_description ilike '%' || v_query || '%'
        or coalesce(item.item_code, '') ilike '%' || v_query || '%'
        or coalesce(item.brand_origin, '') ilike '%' || v_query || '%'
        or coalesce(item.size_text, '') ilike '%' || v_query || '%'
        or coalesce(item.model_reference, '') ilike '%' || v_query || '%'
      )
      order by match_rank, item.item_description, item.id
      limit v_limit
    ) ranked
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_add_material_request_comment(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_request_id uuid;
  v_body text;
  v_mentions jsonb;
  v_mentioned_user_id uuid;
  v_comment_id uuid := gen_random_uuid();
  v_display_name text;
  v_mentioned_name text;
  v_mentioned_role text;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'body', 'mentioned_auth_user_ids'],
    'material_request_comment'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_body := nullif(btrim(coalesce(p_payload ->> 'body', '')), '');
  v_mentions := coalesce(p_payload -> 'mentioned_auth_user_ids', '[]'::jsonb);
  if v_request_id is null or v_body is null or length(v_body) > 4000
    or jsonb_typeof(v_mentions) <> 'array'
    or not public.v1_material_request_readable(v_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_INVALID' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_add_material_request_comment', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into v_display_name
  from public.v1_profiles profile where profile.auth_user_id = v_actor;
  insert into public.v1_material_request_comments (
    id, request_id, body, author_auth_user_id, author_role, author_exact_role,
    author_display_name_snapshot
  ) values (
    v_comment_id, v_request_id, v_body, v_actor, v_role, v_exact_role,
    v_display_name
  );

  for v_mentioned_user_id in
    select distinct nullif(btrim(value #>> '{}'), '')::uuid
    from jsonb_array_elements(v_mentions)
  loop
    if v_mentioned_user_id = v_actor then continue; end if;
    if not public.v1_material_request_participant(
      v_request_id, v_mentioned_user_id
    ) then
      raise exception 'V1_MATERIAL_REQUEST_MENTION_DENIED' using errcode = '42501';
    end if;
    select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id),
      user_record.raw_app_meta_data ->> 'role'
      into v_mentioned_name, v_mentioned_role
    from public.v1_profiles profile
    join auth.users user_record on user_record.id = profile.auth_user_id
    where profile.auth_user_id = v_mentioned_user_id and profile.is_active;
    insert into public.v1_material_request_comment_mentions (
      comment_id, mentioned_auth_user_id, mentioned_display_name_snapshot,
      mentioned_exact_role
    ) values (
      v_comment_id, v_mentioned_user_id, v_mentioned_name, v_mentioned_role
    );
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) select v_mentioned_user_id, 'material_request_mentioned',
      'material_request', v_request_id, request_record.project_id
    from public.v1_material_requests request_record where request_record.id = v_request_id;
  end loop;

  perform public.v1_write_audit_event(
    'material_request_commented', 'material_request_comment', v_comment_id,
    (select project_id from public.v1_material_requests where id = v_request_id),
    null,
    jsonb_build_object(
      'request_id', v_request_id,
      'mention_count', (select count(*) from public.v1_material_request_comment_mentions
        where comment_id = v_comment_id)
    ), null, p_idempotency_key
  );
  v_response := jsonb_build_object(
    'comment_id', v_comment_id,
    'comments', public.v1_material_request_comment_projection(v_request_id)
  );
  perform public.v1_complete_idempotency(
    'v1_add_material_request_comment', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_update_material_request_for_approval(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_scope_id uuid;
  v_title text;
  v_timing text;
  v_scheduled_date date;
  v_delivery_note text;
  v_lines jsonb;
  v_line jsonb;
  v_line_id uuid;
  v_line_order integer;
  v_source_kind text;
  v_source_group_id uuid;
  v_source_row_id uuid;
  v_description text;
  v_technical_attributes jsonb;
  v_requested_qty numeric(18, 4);
  v_unit text;
  v_before jsonb;
  v_response jsonb;
  v_existing jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'request_id', 'expected_version', 'project_id', 'scope_id', 'title',
      'timing', 'scheduled_date', 'delivery_note', 'lines'
    ],
    'update_material_request_for_approval'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_title := nullif(btrim(coalesce(p_payload ->> 'title', '')), '');
  v_timing := coalesce(p_payload ->> 'timing', '');
  v_scheduled_date := nullif(p_payload ->> 'scheduled_date', '')::date;
  v_delivery_note := nullif(btrim(coalesce(p_payload ->> 'delivery_note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_scope_id is null or v_timing not in ('urgent', 'normal', 'scheduled')
    or jsonb_typeof(v_lines) <> 'array' or jsonb_array_length(v_lines) = 0
    or (v_timing = 'scheduled' and v_scheduled_date is null)
    or (v_timing <> 'scheduled' and v_scheduled_date is not null) then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_EDIT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_edit_material_request_before_approval(
    v_request_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_EDIT_DENIED'
      using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if nullif(p_payload ->> 'project_id', '')::uuid <> v_request.project_id
    or not exists (
      select 1 from public.v1_project_scopes scope
      where scope.id = v_scope_id and scope.project_id = v_request.project_id
        and scope.is_active
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array[
        'id', 'display_order', 'source_kind', 'source_boq_group_id',
        'source_boq_row_id', 'item_description', 'brand_origin',
        'technical_attributes', 'requested_qty', 'unit'
      ],
      'material_request_line'
    );
    v_line_id := nullif(btrim(coalesce(v_line ->> 'id', '')), '')::uuid;
    v_line_order := nullif(v_line ->> 'display_order', '')::integer;
    v_source_kind := coalesce(v_line ->> 'source_kind', '');
    v_source_group_id := nullif(v_line ->> 'source_boq_group_id', '')::uuid;
    v_source_row_id := nullif(v_line ->> 'source_boq_row_id', '')::uuid;
    v_description := nullif(btrim(coalesce(v_line ->> 'item_description', '')), '');
    v_technical_attributes := coalesce(v_line -> 'technical_attributes', '{}'::jsonb);
    v_requested_qty := nullif(v_line ->> 'requested_qty', '')::numeric(18, 4);
    v_unit := nullif(btrim(coalesce(v_line ->> 'unit', '')), '');
    if v_line_id is null or v_line_order is null or v_line_order < 1
      or v_source_kind not in ('boq', 'excel', 'custom')
      or v_description is null or v_requested_qty is null or v_requested_qty <= 0
      or v_unit is null or jsonb_typeof(v_technical_attributes) <> 'object' then
      raise exception 'V1_MATERIAL_REQUEST_LINE_INVALID' using errcode = '22023';
    end if;
    if v_source_kind = 'boq' then
      if v_source_group_id is null or v_source_row_id is null or not exists (
        select 1
        from public.v1_boq_groups group_record
        join public.v1_boq_rows row_record on row_record.group_id = group_record.id
        where group_record.id = v_source_group_id
          and group_record.project_id = v_request.project_id
          and group_record.scope_id = v_scope_id
          and not group_record.is_archived
          and row_record.id = v_source_row_id and not row_record.is_archived
      ) then
        raise exception 'V1_MATERIAL_REQUEST_BOQ_SOURCE_INVALID'
          using errcode = '22023';
      end if;
    elsif v_source_group_id is not null or v_source_row_id is not null then
      raise exception 'V1_MATERIAL_REQUEST_SOURCE_INVALID' using errcode = '22023';
    end if;
  end loop;
  if (select count(distinct (value ->> 'id')) from jsonb_array_elements(v_lines))
      <> jsonb_array_length(v_lines)
    or (select count(distinct (value ->> 'display_order'))
        from jsonb_array_elements(v_lines)) <> jsonb_array_length(v_lines) then
    raise exception 'V1_MATERIAL_REQUEST_LINES_DUPLICATE' using errcode = '22023';
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_update_material_request_for_approval', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_before := public.v1_material_request_projection(v_request_id);

  delete from public.v1_material_request_lines where request_id = v_request_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    insert into public.v1_material_request_lines (
      id, request_id, display_order, source_kind, source_boq_group_id,
      source_boq_row_id, item_description, brand_origin, technical_attributes,
      requested_qty, unit, created_at, updated_at
    ) values (
      (v_line ->> 'id')::uuid, v_request_id,
      (v_line ->> 'display_order')::integer, v_line ->> 'source_kind',
      nullif(v_line ->> 'source_boq_group_id', '')::uuid,
      nullif(v_line ->> 'source_boq_row_id', '')::uuid,
      btrim(v_line ->> 'item_description'),
      nullif(btrim(coalesce(v_line ->> 'brand_origin', '')), ''),
      public.v1_material_request_normalized_technical_attributes(
        coalesce(v_line -> 'technical_attributes', '{}'::jsonb),
        v_line ->> 'source_kind'
      ),
      (v_line ->> 'requested_qty')::numeric(18, 4),
      btrim(v_line ->> 'unit'), clock_timestamp(), clock_timestamp()
    );
  end loop;
  update public.v1_material_requests
  set scope_id = v_scope_id,
      title = v_title,
      timing = v_timing,
      scheduled_date = v_scheduled_date,
      delivery_note = v_delivery_note,
      state = 'awaiting_request_approval',
      current_action_owner_role = 'project_engineer',
      current_action_code = 'request_approval_required',
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_request_id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct member.member_auth_user_id, 'material_request_updated_for_approval',
    'material_request', v_request_id, v_request.project_id
  from public.v1_project_members member
  join public.v1_profiles profile on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = v_request.project_id
    and member.project_role = 'project_engineer'
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
    and profile.is_active and member.member_auth_user_id <> auth.uid();

  v_response := public.v1_material_request_projection(v_request_id);
  perform public.v1_write_audit_event(
    'material_request_updated_for_approval', 'material_request', v_request_id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'record_version', v_expected_version + 1,
      'line_count', jsonb_array_length(v_lines),
      'state', 'awaiting_request_approval'
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_update_material_request_for_approval', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_decide_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_decision text;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_exact_role text := public.v1_current_exact_role();
  v_display_name text;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version', 'decision', 'reason'],
    'decide_material_request'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_decision := coalesce(p_payload ->> 'decision', '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_decision not in ('approved', 'returned')
    or (v_decision = 'returned' and v_reason is null) then
    raise exception 'V1_MATERIAL_REQUEST_DECISION_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_decide_material_request(v_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DECISION_DENIED' using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_decide_material_request', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_request.state <> 'awaiting_request_approval' or exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_NOT_AWAITING_DECISION'
      using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into v_display_name from public.v1_profiles profile
    where profile.auth_user_id = auth.uid();
  v_before := public.v1_material_request_projection(v_request_id);
  insert into public.v1_material_request_decisions (
    request_id, request_record_version, decision, reason,
    decided_by_auth_user_id, decided_by_role, decided_by_exact_role,
    decided_by_display_name_snapshot
  ) values (
    v_request_id, v_expected_version, v_decision, v_reason, auth.uid(),
    public.v1_current_role(), v_exact_role, v_display_name
  );
  update public.v1_material_requests
  set state = case when v_decision = 'approved'
      then 'approved_for_arrangement' else 'changes_requested' end,
      current_action_owner_role = case when v_decision = 'approved'
        then 'procurement' else requester_project_role end,
      current_action_code = case when v_decision = 'approved'
        then 'arrangement_required' else 'request_changes_required' end,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_request_id;

  if v_decision = 'approved' then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    )
    select profile.auth_user_id, 'material_request_approved_for_arrangement',
      'material_request', v_request_id, v_request.project_id
    from public.v1_profiles profile
    where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  else
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_request.created_by_auth_user_id, 'material_request_changes_requested',
      'material_request', v_request_id, v_request.project_id
    );
  end if;
  v_response := public.v1_material_request_projection(v_request_id);
  perform public.v1_write_audit_event(
    case when v_decision = 'approved' then 'material_request_approved'
      else 'material_request_returned' end,
    'material_request', v_request_id, v_request.project_id, v_before,
    jsonb_build_object(
      'decision', v_decision,
      'approved_request_version', v_expected_version,
      'record_version', v_expected_version + 1,
      'state', case when v_decision = 'approved'
        then 'approved_for_arrangement' else 'changes_requested' end,
      'decided_by_exact_role', v_exact_role
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_decide_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_submit_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
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
  v_exact_role text;
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
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_SUBMITTABLE'
      using errcode = '42501';
  end if;
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
  ) or not exists (
    select 1 from public.v1_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_LINES_OR_SCOPE_INVALID'
      using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.v1_material_request_lines line_record
    join public.v1_boq_groups group_record
      on group_record.id = line_record.source_boq_group_id
    where line_record.request_id = v_request.id
      and line_record.source_kind = 'boq'
      and group_record.scope_id is distinct from v_request.scope_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_BOQ_SCOPE_RECONCILIATION_REQUIRED'
      using errcode = '22023';
  end if;
  if v_request.timing = 'scheduled' and v_request.scheduled_date is null then
    raise exception 'V1_MATERIAL_REQUEST_SCHEDULED_DATE_REQUIRED'
      using errcode = '22023';
  end if;

  select member.project_role into v_project_role
  from public.v1_project_members member
  where member.project_id = v_project.id and member.member_auth_user_id = v_actor
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
  order by case member.project_role when 'project_engineer' then 0 else 1 end
  limit 1;
  if v_project_role is null and public.v1_current_role() <> 'admin'
    and not public.v1_has_active_project_membership(v_project.id, v_actor) then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED'
      using errcode = '42501';
  end if;
  v_exact_role := public.v1_current_exact_role();
  if not public.v1_is_valid_role(v_exact_role) then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
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
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || lpad(v_sequence::text, 3, '0');
  v_before := public.v1_material_request_projection(v_request.id);

  update public.v1_material_requests
  set request_number = v_request_number,
      state = 'awaiting_request_approval',
      requester_display_name = v_display_name,
      requester_project_role = coalesce(v_project_role, 'project_engineer'),
      requester_exact_role = v_exact_role,
      current_action_owner_role = 'project_engineer',
      current_action_code = 'request_approval_required',
      submitted_at = clock_timestamp(),
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_request.id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct candidate.auth_user_id, 'material_request_approval_required',
    'material_request', v_request.id, v_project.id
  from (
    select member.member_auth_user_id as auth_user_id
    from public.v1_project_members member
    where member.project_id = v_project.id
      and member.project_role = 'project_engineer'
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
    union
    select profile.auth_user_id
    from public.v1_profiles profile
    join auth.users user_record on user_record.id = profile.auth_user_id
    where profile.is_active and user_record.raw_app_meta_data ->> 'role' in (
      'senior_mechanical_engineer', 'project_manager'
    )
  ) candidate
  join public.v1_profiles profile on profile.auth_user_id = candidate.auth_user_id
  where profile.is_active;

  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_submitted', 'material_request', v_request.id, v_project.id,
    v_before,
    jsonb_build_object(
      'request_number', v_request_number,
      'record_version', v_expected_version + 1,
      'line_count', (select count(*) from public.v1_material_request_lines
        where request_id = v_request.id),
      'state', 'awaiting_request_approval',
      'current_action_owner_role', 'project_engineer'
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_submit_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_begin_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_arrangement_id uuid;
  v_arrangement_version integer;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'begin_arrangement'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_BEGIN_ARRANGEMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_arrange_material_request(v_request_id) then
    raise exception 'V1_BEGIN_ARRANGEMENT_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_begin_arrangement', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state not in (
    'submitted', 'approved_for_arrangement', 'arranging'
  ) then
    raise exception 'V1_BEGIN_ARRANGEMENT_STATE_INVALID' using errcode = '22023';
  end if;
  if v_request.state = 'approved_for_arrangement' and not exists (
    select 1 from public.v1_material_request_decisions decision
    where decision.request_id = v_request.id and decision.decision = 'approved'
  ) then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_REQUIRED' using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request.id and arrangement.status = 'working'
  ) then
    raise exception 'V1_ARRANGEMENT_ALREADY_IN_PROGRESS' using errcode = '40001';
  end if;
  if v_request.state = 'arranging' and not exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request.id
      and arrangement.is_current and arrangement.status = 'returned'
  ) then
    raise exception 'V1_BEGIN_ARRANGEMENT_STATE_INVALID' using errcode = '22023';
  end if;
  select coalesce(max(arrangement_version), 0) + 1 into v_arrangement_version
  from public.v1_procurement_arrangements where request_id = v_request.id;
  v_before := public.v1_material_request_projection(v_request.id);
  insert into public.v1_procurement_arrangements (
    request_id, arrangement_version, status, is_current, started_by_auth_user_id
  ) values (
    v_request.id, v_arrangement_version, 'working', false, auth.uid()
  ) returning id into v_arrangement_id;
  insert into public.v1_procurement_arrangement_lines (
    arrangement_id, request_line_id, source_kind
  )
  select v_arrangement_id, request_line.id, 'warehouse'
  from public.v1_material_request_lines request_line
  where request_line.request_id = v_request.id
  order by request_line.display_order;
  update public.v1_material_requests
  set state = 'arranging', current_action_owner_role = 'procurement',
      current_action_code = 'arrangement_in_progress',
      record_version = record_version + 1, updated_at = clock_timestamp()
  where id = v_request.id;
  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_write_audit_event(
    'arrangement_begun', 'procurement_arrangement', v_arrangement_id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'request_state', 'arranging',
      'arrangement_version', v_arrangement_version,
      'request_record_version', v_expected_version + 1,
      'request_preapproved', exists (
        select 1 from public.v1_material_request_decisions decision
        where decision.request_id = v_request.id
          and decision.decision = 'approved'
      )
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_begin_arrangement', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

do $migration$
begin
  if to_regprocedure(
    'public.v1_save_arrangement_legacy_before_preapproval(jsonb,uuid)'
  ) is null then
    alter function public.v1_save_arrangement(jsonb, uuid)
      rename to v1_save_arrangement_legacy_before_preapproval;
  end if;
end;
$migration$;

revoke all on function
  public.v1_save_arrangement_legacy_before_preapproval(jsonb, uuid)
  from public, anon, authenticated;

create or replace function public.v1_save_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_request public.v1_material_requests%rowtype;
  v_arrangement public.v1_procurement_arrangements%rowtype;
  v_approval public.v1_material_request_decisions%rowtype;
  v_response jsonb;
  v_before jsonb;
  v_positive_count integer;
begin
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  if v_request_id is null then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_approval
  from public.v1_material_request_decisions decision
  where decision.request_id = v_request_id and decision.decision = 'approved'
  order by decision.created_at desc limit 1;
  if not found then
    -- Compatibility lane for arrangements already in progress before this
    -- migration. The preserved implementation retains its old decision path.
    return public.v1_save_arrangement_legacy_before_preapproval(
      p_payload, p_idempotency_key
    );
  end if;

  v_response := public.v1_save_arrangement_legacy_before_preapproval(
    p_payload, p_idempotency_key
  );
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if v_request.state in ('approved', 'closed', 'partially_dispatched',
      'dispatched', 'partially_received', 'received') then
    return public.v1_arrangement_projection(v_request_id);
  end if;
  if v_request.state <> 'awaiting_approval' then
    raise exception 'V1_PREAPPROVED_ARRANGEMENT_FINALIZE_STATE_INVALID'
      using errcode = '22023';
  end if;
  select * into v_arrangement
  from public.v1_procurement_arrangements arrangement
  where arrangement.request_id = v_request_id and arrangement.is_current
    and arrangement.status = 'awaiting_approval'
  order by arrangement.arrangement_version desc limit 1
  for update;
  if not found then
    raise exception 'V1_PREAPPROVED_ARRANGEMENT_NOT_FOUND' using errcode = '22023';
  end if;
  v_before := public.v1_arrangement_projection(v_request_id);
  select count(*) into v_positive_count
  from public.v1_procurement_arrangement_lines arrangement_line
  where arrangement_line.arrangement_id = v_arrangement.id
    and arrangement_line.decision in ('full', 'partial')
    and arrangement_line.arranged_qty > 0;

  if v_positive_count = 0 then
    update public.v1_inventory_reservations
    set state = 'released', released_at = clock_timestamp(),
        released_by_auth_user_id = auth.uid(),
        release_reason = 'all_items_unavailable', updated_at = clock_timestamp()
    where request_id = v_request_id and state in ('active', 'partially_consumed');
    update public.v1_procurement_arrangements
    set status = 'approved', record_version = record_version + 1,
        updated_at = clock_timestamp()
    where id = v_arrangement.id;
    update public.v1_material_requests
    set state = 'closed', current_action_owner_role = 'none',
        current_action_code = 'unavailable_closed',
        record_version = record_version + 1, updated_at = clock_timestamp()
    where id = v_request_id;
  else
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select line_record.id from public.v1_material_request_lines line_record
      where line_record.request_id = v_request_id
    );
    insert into public.v1_material_request_line_approvals (
      request_line_id, arrangement_line_id, arrangement_id, approved_qty,
      approved_by_auth_user_id
    )
    select arrangement_line.request_line_id, arrangement_line.id,
      v_arrangement.id, arrangement_line.arranged_qty,
      v_approval.decided_by_auth_user_id
    from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id;
    update public.v1_procurement_arrangements
    set status = 'approved', record_version = record_version + 1,
        updated_at = clock_timestamp()
    where id = v_arrangement.id;
    update public.v1_material_requests
    set state = 'approved', current_action_owner_role = 'procurement',
        current_action_code = 'dispatch_required',
        record_version = record_version + 1, updated_at = clock_timestamp()
    where id = v_request_id;
  end if;

  -- The legacy implementation inserted this notification in the same, still
  -- uncommitted transaction. Remove it before any recipient can observe a
  -- review task that no longer exists.
  delete from public.v1_notifications notification
  where notification.entity_type = 'procurement_arrangement'
    and notification.entity_id = v_arrangement.id
    and notification.event_code = 'arrangement_review_required';
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id,
    case when v_positive_count = 0 then 'arrangement_completed_unavailable'
      else 'arrangement_ready_for_dispatch' end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';

  perform public.v1_write_audit_event(
    'preapproved_arrangement_finalized', 'procurement_arrangement',
    v_arrangement.id, v_request.project_id, v_before,
    jsonb_build_object(
      'request_state', case when v_positive_count = 0 then 'closed' else 'approved' end,
      'request_approval_id', v_approval.id,
      'approved_engineering_version', v_approval.request_record_version,
      'positive_line_count', v_positive_count
    ), null, p_idempotency_key
  );
  return public.v1_arrangement_projection(v_request_id);
end;
$$;

-- Existing requests that never entered Procurement have no reservation or
-- arrangement provenance to preserve. Move them to the new Engineering review
-- state. This is a migration/system transition; it deliberately does not
-- fabricate a human actor in the append-only user audit ledger.
update public.v1_material_requests request_record
set state = 'awaiting_request_approval',
    current_action_owner_role = 'project_engineer',
    current_action_code = 'request_approval_required',
    record_version = record_version + 1,
    updated_at = clock_timestamp()
where request_record.state = 'submitted'
  and not exists (
    select 1 from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = request_record.id
  );

alter table public.v1_document_links
  drop constraint if exists v1_document_links_entity_type_check;
alter table public.v1_document_links
  add constraint v1_document_links_entity_type_check check (entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
    'material_return', 'delivery_order', 'rental_property'
  ));
alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_target_entity_type_check;
alter table public.v1_document_upload_intents
  add constraint v1_document_upload_intents_target_entity_type_check check (
    target_entity_type in (
      'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
      'material_return', 'delivery_order', 'rental_property'
    )
  );

-- External supplier names are optional in the approved rollout. Preserve the
-- source distinction while allowing the committed dispatch snapshot to carry
-- a null supplier, exactly as the arrangement does.
alter table public.v1_material_dispatch_lines
  drop constraint if exists v1_material_dispatch_lines_check;
alter table public.v1_material_dispatch_lines
  add constraint v1_material_dispatch_lines_check check (
    (source_kind = 'warehouse' and inventory_item_id is not null
      and external_supplier is null)
    or (source_kind = 'external_supplier' and inventory_item_id is null)
  );

create or replace function public.v1_document_target_project_id(
  p_entity_type text,
  p_entity_id uuid
) returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
begin
  case p_entity_type
    when 'project' then
      select project.id into v_project_id
      from public.v1_projects project where project.id = p_entity_id;
    when 'boq_group' then
      select boq_group.project_id into v_project_id
      from public.v1_boq_groups boq_group where boq_group.id = p_entity_id;
    when 'material_request' then
      select request_record.project_id into v_project_id
      from public.v1_material_requests request_record
      where request_record.id = p_entity_id;
    when 'dispatch' then
      select request_record.project_id into v_project_id
      from public.v1_material_dispatches dispatch_record
      join public.v1_material_requests request_record
        on request_record.id = dispatch_record.request_id
      where dispatch_record.id = p_entity_id;
    when 'receipt_review' then
      select request_record.project_id into v_project_id
      from public.v1_receipt_reviews review
      join public.v1_material_requests request_record
        on request_record.id = review.request_id
      where review.id = p_entity_id and review.state = 'confirmed';
    when 'material_return' then
      select material_return.project_id into v_project_id
      from public.v1_material_returns material_return
      where material_return.id = p_entity_id;
    when 'delivery_order' then
      select request_record.project_id into v_project_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = delivery_order.dispatch_id
      join public.v1_material_requests request_record
        on request_record.id = dispatch_record.request_id
      where delivery_order.id = p_entity_id;
    else
      raise exception 'V1_DOCUMENT_TARGET_TYPE_INVALID' using errcode = '22023';
  end case;
  if v_project_id is null then
    raise exception 'V1_DOCUMENT_TARGET_NOT_FOUND' using errcode = '22023';
  end if;
  return v_project_id;
end;
$$;

create or replace function public.v1_document_target_readable(
  p_entity_type text,
  p_entity_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_project_id uuid;
begin
  case p_entity_type
    when 'project' then
      return public.v1_project_readable(p_entity_id);
    when 'boq_group' then
      select project_id into v_project_id from public.v1_boq_groups where id = p_entity_id;
      return v_project_id is not null and public.v1_project_readable(v_project_id);
    when 'material_request' then
      return public.v1_material_request_readable(p_entity_id);
    when 'dispatch' then
      select request_id into v_request_id from public.v1_material_dispatches
      where id = p_entity_id;
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'receipt_review' then
      select request_id into v_request_id from public.v1_receipt_reviews
      where id = p_entity_id and state = 'confirmed';
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'material_return' then
      select request_id into v_request_id from public.v1_material_returns
      where id = p_entity_id;
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'delivery_order' then
      select dispatch_record.request_id into v_request_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = delivery_order.dispatch_id
      where delivery_order.id = p_entity_id;
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'rental_property' then
      return auth.uid() is not null and public.v1_current_actor_is_active()
        and public.v1_current_role() = 'admin' and exists (
          select 1 from public.v1_rental_properties property_record
          where property_record.id = p_entity_id
        );
    else
      return false;
  end case;
end;
$$;

create or replace function public.v1_document_target_writable(
  p_entity_type text,
  p_entity_id uuid,
  p_classification text
) returns boolean
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
  if not public.v1_document_target_readable(p_entity_type, p_entity_id)
    or not public.v1_document_classification_writable(p_classification) then
    return false;
  end if;
  if p_entity_type = 'rental_property' then
    return p_classification = 'commercial' and exists (
      select 1 from public.v1_rental_properties property_record
      where property_record.id = p_entity_id and not property_record.is_archived
    );
  end if;
  if p_entity_type = 'receipt_review' then
    return p_classification = 'operational'
      and v_role in ('project_engineer', 'site_engineer', 'admin')
      and exists (
        select 1 from public.v1_receipt_reviews review
        where review.id = p_entity_id and review.state = 'confirmed'
      );
  end if;
  v_project_id := public.v1_document_target_project_id(p_entity_type, p_entity_id);
  select state into v_project_state from public.v1_projects where id = v_project_id;
  return v_project_state in ('draft', 'active', 'on_hold', 'completed');
end;
$$;

revoke all on function public.v1_material_request_participant(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_decide_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_edit_material_request_before_approval(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_comment_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_requests(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_request_mention_candidates(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_search_material_request_inventory_items(uuid, text, integer)
  from public, anon, authenticated;
revoke all on function public.v1_add_material_request_comment(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_update_material_request_for_approval(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_decide_material_request(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_submit_material_request(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_begin_arrangement(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_target_project_id(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_target_readable(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_target_writable(text, uuid, text)
  from public, anon, authenticated;

grant execute on function public.v1_material_request_readable(uuid)
  to authenticated;
grant execute on function public.v1_material_request_projection(uuid)
  to authenticated;
grant execute on function public.v1_list_material_requests(uuid)
  to authenticated;
grant execute on function public.v1_list_material_request_mention_candidates(uuid)
  to authenticated;
grant execute on function public.v1_search_material_request_inventory_items(uuid, text, integer)
  to authenticated;
grant execute on function public.v1_add_material_request_comment(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_update_material_request_for_approval(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_decide_material_request(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_submit_material_request(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_begin_arrangement(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_save_arrangement(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_document_target_project_id(text, uuid)
  to authenticated;
grant execute on function public.v1_document_target_readable(text, uuid)
  to authenticated;
grant execute on function public.v1_document_target_writable(text, uuid, text)
  to authenticated;

comment on table public.v1_material_request_decisions is
  'Immutable Engineering decisions made before Procurement arrangement.';
comment on table public.v1_material_request_comments is
  'Append-only normalized Material Request discussion; writes use the trusted comment RPC.';
comment on table public.v1_material_request_comment_mentions is
  'Validated request-readable user mentions captured with immutable display/role snapshots.';
comment on function public.v1_search_material_request_inventory_items(uuid, text, integer) is
  'Non-commercial Engineering autocomplete. It never returns costs, balances, reservations, thresholds or locations.';

-- Preserve the established role-safe arrangement response shape while moving
-- only the first-entry gate to the new pre-approved state.
do $migration$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.v1_arrangement_projection(uuid)'::regprocedure
  ) into v_definition;
  v_definition := replace(
    v_definition,
    $find$request_record.state in ('submitted', 'arranging')$find$,
    $replace$request_record.state in (
      'submitted', 'approved_for_arrangement', 'arranging'
    )$replace$
  );
  execute v_definition;
end;
$migration$;

-- Receipt-photo uploads need the already-authorized project identifier, but
-- must not learn it from a client-controlled field. Add it to the trusted
-- logistics projection derived from the request row.
do $logistics_projection$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.v1_logistics_workspace_projection(uuid)'::regprocedure
  ) into v_definition;
  if position($find$'project_id', request_record.project_id,$find$
    in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'request_id', request_record.id,$find$,
      $replace$'request_id', request_record.id,
    'project_id', request_record.project_id,$replace$
    );
  end if;
  execute v_definition;
end;
$logistics_projection$;

-- Cancellation remains an audited escape hatch before any dispatch. Extend
-- the established command to the explicit approval-first pre-dispatch states.
do $cancel_projection$
declare
  v_definition text;
begin
  select pg_get_functiondef(
    'public.v1_cancel_material_request(jsonb,uuid)'::regprocedure
  ) into v_definition;
  v_definition := replace(
    v_definition,
    $find$v_request.state not in ('submitted', 'arranging', 'awaiting_approval', 'approved')$find$,
    $replace$v_request.state not in (
      'submitted', 'awaiting_request_approval', 'changes_requested',
      'approved_for_arrangement', 'arranging', 'awaiting_approval', 'approved'
    )$replace$
  );
  execute v_definition;
end;
$cancel_projection$;
