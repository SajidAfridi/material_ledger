-- Yorks V1 Material Request Phase 2 collaboration and scale hardening.
--
-- Data preservation:
-- * all relations are additive and existing request, line, comment and audit
--   facts remain unchanged;
-- * private draft sync is owner-scoped working data, never workflow authority;
-- * work assignment is a lightweight responsibility marker and never changes
--   the canonical request state or role owner;
-- * revision snapshots are append-only evidence used only to explain changes
--   after a returned request is resubmitted.
--
-- Rollback is forward-only: disable the Phase 2 client and revoke the new RPCs
-- in a corrective migration. Do not drop evidence or rewrite request history.

create table if not exists public.v1_material_request_private_drafts (
  draft_id uuid not null,
  owner_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  sync_version integer not null default 1 check (sync_version > 0),
  draft_data jsonb not null check (jsonb_typeof(draft_data) = 'object'),
  client_updated_at timestamptz not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  primary key (draft_id, owner_auth_user_id)
);

create index if not exists v1_material_request_private_drafts_owner_updated_idx
  on public.v1_material_request_private_drafts (
    owner_auth_user_id, updated_at desc, draft_id
  );

create table if not exists public.v1_material_request_work_assignments (
  request_id uuid primary key references public.v1_material_requests (id)
    on delete restrict,
  assignee_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  assignee_display_name_snapshot text,
  assignee_exact_role text,
  assignment_version integer not null default 1
    check (assignment_version > 0),
  assigned_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  assigned_by_exact_role text not null,
  reason text,
  assigned_at timestamptz,
  updated_at timestamptz not null default clock_timestamp(),
  check (
    (assignee_auth_user_id is null and assignee_display_name_snapshot is null
      and assignee_exact_role is null and assigned_at is null)
    or (assignee_auth_user_id is not null
      and assignee_display_name_snapshot is not null
      and btrim(assignee_display_name_snapshot) <> ''
      and assignee_exact_role is not null and btrim(assignee_exact_role) <> ''
      and assigned_at is not null)
  )
);

create index if not exists v1_material_request_work_assignments_assignee_idx
  on public.v1_material_request_work_assignments (
    assignee_auth_user_id, updated_at desc
  ) where assignee_auth_user_id is not null;

create table if not exists public.v1_material_request_revision_snapshots (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_material_requests (id)
    on delete restrict,
  request_record_version integer not null check (request_record_version > 0),
  snapshot_reason text not null check (snapshot_reason in (
    'submitted_for_approval', 'legacy_baseline'
  )),
  title text,
  timing text not null check (timing in ('urgent', 'normal', 'scheduled')),
  scheduled_date date,
  delivery_note text,
  lines jsonb not null check (jsonb_typeof(lines) = 'array'),
  captured_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  captured_by_exact_role text,
  captured_at timestamptz not null default clock_timestamp(),
  unique (request_id, request_record_version)
);

create index if not exists v1_material_request_revision_request_version_idx
  on public.v1_material_request_revision_snapshots (
    request_id, request_record_version desc
  );

alter table public.v1_material_request_private_drafts enable row level security;
alter table public.v1_material_request_work_assignments enable row level security;
alter table public.v1_material_request_revision_snapshots enable row level security;

revoke all on table public.v1_material_request_private_drafts
  from public, anon, authenticated;
revoke all on table public.v1_material_request_work_assignments
  from public, anon, authenticated;
revoke all on table public.v1_material_request_revision_snapshots
  from public, anon, authenticated;
grant all on table public.v1_material_request_private_drafts to service_role;
grant all on table public.v1_material_request_work_assignments to service_role;
grant all on table public.v1_material_request_revision_snapshots to service_role;

comment on table public.v1_material_request_private_drafts is
  'Owner-only, versioned cross-device recovery input. It is not workflow state.';
comment on table public.v1_material_request_work_assignments is
  'Optional current responsibility marker. Canonical role ownership remains on the request.';
comment on table public.v1_material_request_revision_snapshots is
  'Append-only operational snapshots used to explain returned-request changes.';

create or replace function public.v1_material_request_capture_revision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text;
begin
  if new.state <> 'awaiting_request_approval'
    or (tg_op = 'UPDATE'
      and old.record_version = new.record_version
      and old.state = new.state) then
    return new;
  end if;

  if v_actor is not null then
    v_exact_role := public.v1_current_exact_role();
  end if;

  insert into public.v1_material_request_revision_snapshots (
    request_id, request_record_version, snapshot_reason, title, timing,
    scheduled_date, delivery_note, lines, captured_by_auth_user_id,
    captured_by_exact_role, captured_at
  ) values (
    new.id, new.record_version, 'submitted_for_approval', new.title, new.timing,
    new.scheduled_date, new.delivery_note,
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', line.id,
        'display_order', line.display_order,
        'source_kind', line.source_kind,
        'source_boq_group_id', line.source_boq_group_id,
        'source_boq_row_id', line.source_boq_row_id,
        'item_description', line.item_description,
        'brand_origin', line.brand_origin,
        'technical_attributes', coalesce(line.technical_attributes, '{}'::jsonb),
        'requested_qty', line.requested_qty,
        'unit', line.unit
      ) order by line.display_order, line.id)
      from public.v1_material_request_lines line
      where line.request_id = new.id
    ), '[]'::jsonb),
    v_actor, v_exact_role, clock_timestamp()
  ) on conflict (request_id, request_record_version) do nothing;

  return new;
end;
$$;

drop trigger if exists v1_material_request_capture_revision_trigger
  on public.v1_material_requests;
create trigger v1_material_request_capture_revision_trigger
after insert or update of state, record_version
on public.v1_material_requests
for each row execute function public.v1_material_request_capture_revision();

insert into public.v1_material_request_revision_snapshots (
  request_id, request_record_version, snapshot_reason, title, timing,
  scheduled_date, delivery_note, lines, captured_at
)
select request.id, request.record_version, 'legacy_baseline', request.title,
  request.timing, request.scheduled_date, request.delivery_note,
  coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', line.id,
      'display_order', line.display_order,
      'source_kind', line.source_kind,
      'source_boq_group_id', line.source_boq_group_id,
      'source_boq_row_id', line.source_boq_row_id,
      'item_description', line.item_description,
      'brand_origin', line.brand_origin,
      'technical_attributes', coalesce(line.technical_attributes, '{}'::jsonb),
      'requested_qty', line.requested_qty,
      'unit', line.unit
    ) order by line.display_order, line.id)
    from public.v1_material_request_lines line
    where line.request_id = request.id
  ), '[]'::jsonb),
  request.updated_at
from public.v1_material_requests request
where request.state = 'awaiting_request_approval'
on conflict (request_id, request_record_version) do nothing;

create or replace function public.v1_material_request_change_summary(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_returned public.v1_material_request_decisions%rowtype;
  v_before public.v1_material_request_revision_snapshots%rowtype;
  v_after public.v1_material_request_revision_snapshots%rowtype;
  v_added integer;
  v_removed integer;
  v_quantity integer;
  v_description integer;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_CHANGE_SUMMARY_DENIED'
      using errcode = '42501';
  end if;

  select * into v_returned
  from public.v1_material_request_decisions decision
  where decision.request_id = p_request_id and decision.decision = 'returned'
  order by decision.created_at desc, decision.id desc limit 1;
  if not found then return null; end if;

  select * into v_after
  from public.v1_material_request_revision_snapshots revision
  where revision.request_id = p_request_id
    and revision.request_record_version > v_returned.request_record_version
  order by revision.request_record_version desc limit 1;
  if not found then return null; end if;

  select * into v_before
  from public.v1_material_request_revision_snapshots revision
  where revision.request_id = p_request_id
    and revision.request_record_version <= v_returned.request_record_version
  order by revision.request_record_version desc limit 1;
  if not found then return null; end if;

  select count(*) into v_added
  from jsonb_array_elements(v_after.lines) after_line
  where not exists (
    select 1 from jsonb_array_elements(v_before.lines) before_line
    where before_line ->> 'id' = after_line ->> 'id'
  );
  select count(*) into v_removed
  from jsonb_array_elements(v_before.lines) before_line
  where not exists (
    select 1 from jsonb_array_elements(v_after.lines) after_line
    where after_line ->> 'id' = before_line ->> 'id'
  );
  select count(*) into v_quantity
  from jsonb_array_elements(v_after.lines) after_line
  join jsonb_array_elements(v_before.lines) before_line
    on before_line ->> 'id' = after_line ->> 'id'
  where (before_line ->> 'requested_qty')::numeric
    is distinct from (after_line ->> 'requested_qty')::numeric
    or before_line ->> 'unit' is distinct from after_line ->> 'unit';
  select count(*) into v_description
  from jsonb_array_elements(v_after.lines) after_line
  join jsonb_array_elements(v_before.lines) before_line
    on before_line ->> 'id' = after_line ->> 'id'
  where before_line ->> 'item_description'
      is distinct from after_line ->> 'item_description'
    or before_line ->> 'brand_origin'
      is distinct from after_line ->> 'brand_origin'
    or before_line -> 'technical_attributes'
      is distinct from after_line -> 'technical_attributes';

  return jsonb_build_object(
    'from_request_version', v_before.request_record_version,
    'to_request_version', v_after.request_record_version,
    'items_added', v_added,
    'items_removed', v_removed,
    'quantity_or_unit_changed', v_quantity,
    'description_changed', v_description,
    'title_changed', v_before.title is distinct from v_after.title,
    'timing_changed', v_before.timing is distinct from v_after.timing
      or v_before.scheduled_date is distinct from v_after.scheduled_date,
    'delivery_note_changed',
      v_before.delivery_note is distinct from v_after.delivery_note
  );
end;
$$;

create or replace function public.v1_list_material_request_comments(
  p_request_id uuid,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null,
  p_limit integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
  v_items jsonb;
  v_has_more boolean;
  v_oldest_created_at timestamptz;
  v_oldest_id uuid;
begin
  if not public.v1_material_request_readable(p_request_id)
    or (p_before_created_at is null) <> (p_before_id is null) then
    raise exception 'V1_MATERIAL_REQUEST_COMMENT_PAGE_DENIED'
      using errcode = '42501';
  end if;

  with page as (
    select comment_record.*
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
      and (p_before_created_at is null or
        (comment_record.created_at, comment_record.id)
          < (p_before_created_at, p_before_id))
    order by comment_record.created_at desc, comment_record.id desc
    limit v_limit + 1
  ), kept as (
    select * from page
    order by created_at desc, id desc
    limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', kept.id,
      'request_id', kept.request_id,
      'body', kept.body,
      'author_auth_user_id', kept.author_auth_user_id,
      'author_role', kept.author_role,
      'author_exact_role', kept.author_exact_role,
      'author_display_name', kept.author_display_name_snapshot,
      'created_at', kept.created_at,
      'mentions', coalesce((
        select jsonb_agg(jsonb_build_object(
          'auth_user_id', mention.mentioned_auth_user_id,
          'display_name', mention.mentioned_display_name_snapshot,
          'exact_role', mention.mentioned_exact_role
        ) order by mention.mentioned_display_name_snapshot,
          mention.mentioned_auth_user_id)
        from public.v1_material_request_comment_mentions mention
        where mention.comment_id = kept.id
      ), '[]'::jsonb)
    ) order by kept.created_at, kept.id), '[]'::jsonb),
    count(*) = v_limit and exists (
      select 1 from page offset v_limit
    ),
    min(kept.created_at)
  into v_items, v_has_more, v_oldest_created_at
  from kept;

  if v_oldest_created_at is not null then
    select kept.id into v_oldest_id
    from (
      select comment_record.id, comment_record.created_at
      from public.v1_material_request_comments comment_record
      where comment_record.request_id = p_request_id
        and (p_before_created_at is null or
          (comment_record.created_at, comment_record.id)
            < (p_before_created_at, p_before_id))
      order by comment_record.created_at desc, comment_record.id desc
      limit v_limit
    ) kept
    order by kept.created_at, kept.id limit 1;
  end if;

  return jsonb_build_object(
    'items', v_items,
    'has_more', coalesce(v_has_more, false),
    'next_before_created_at', case when v_has_more then v_oldest_created_at end,
    'next_before_id', case when v_has_more then v_oldest_id end
  );
end;
$$;

-- Preserve old clients while bounding the comments embedded in a full detail
-- projection. Phase 2 clients page older comments through the RPC above.
create or replace function public.v1_material_request_comment_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with recent as (
    select comment_record.*
    from public.v1_material_request_comments comment_record
    where comment_record.request_id = p_request_id
    order by comment_record.created_at desc, comment_record.id desc
    limit 20
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', recent.id,
    'request_id', recent.request_id,
    'body', recent.body,
    'author_auth_user_id', recent.author_auth_user_id,
    'author_role', recent.author_role,
    'author_exact_role', recent.author_exact_role,
    'author_display_name', recent.author_display_name_snapshot,
    'created_at', recent.created_at,
    'mentions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'auth_user_id', mention.mentioned_auth_user_id,
        'display_name', mention.mentioned_display_name_snapshot,
        'exact_role', mention.mentioned_exact_role
      ) order by mention.mentioned_display_name_snapshot)
      from public.v1_material_request_comment_mentions mention
      where mention.comment_id = recent.id
    ), '[]'::jsonb)
  ) order by recent.created_at, recent.id), '[]'::jsonb)
  from recent;
$$;

create or replace function public.v1_material_request_action_assignee_eligible(
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
  v_role text;
begin
  select * into v_request
  from public.v1_material_requests request where request.id = p_request_id;
  if not found or p_auth_user_id is null or v_request.state in (
    'draft', 'closed', 'cancelled'
  ) or not public.v1_material_request_participant(
    p_request_id, p_auth_user_id
  ) then
    return false;
  end if;

  select case coalesce(user_record.raw_app_meta_data ->> 'role', '')
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'workshop_in_charge' then 'project_engineer'
    when 'document_controller' then 'project_engineer'
    else coalesce(user_record.raw_app_meta_data ->> 'role', '')
  end into v_role
  from auth.users user_record where user_record.id = p_auth_user_id;

  if v_role = 'admin' then return true; end if;
  return case v_request.current_action_owner_role
    when 'project_engineer' then v_role = 'project_engineer'
    when 'site_engineer' then v_role in ('site_engineer', 'project_engineer')
    when 'procurement' then v_role = 'procurement'
    when 'admin' then false
    else false
  end;
end;
$$;

create or replace function public.v1_material_request_work_assignment_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case when assignment.request_id is null then jsonb_build_object(
    'request_id', p_request_id,
    'assignment_version', 0,
    'assignee_auth_user_id', null,
    'assignee_display_name', null,
    'assignee_exact_role', null,
    'assigned_at', null,
    'can_manage', public.v1_material_request_action_assignee_eligible(
      p_request_id, auth.uid()
    )
  ) else jsonb_build_object(
    'request_id', assignment.request_id,
    'assignment_version', assignment.assignment_version,
    'assignee_auth_user_id', assignment.assignee_auth_user_id,
    'assignee_display_name', assignment.assignee_display_name_snapshot,
    'assignee_exact_role', assignment.assignee_exact_role,
    'assigned_at', assignment.assigned_at,
    'can_manage', public.v1_material_request_action_assignee_eligible(
      p_request_id, auth.uid()
    )
  ) end
  from (select p_request_id as request_id) seed
  left join public.v1_material_request_work_assignments assignment
    on assignment.request_id = seed.request_id;
$$;

create or replace function public.v1_list_material_request_work_candidates(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_material_request_action_assignee_eligible(
    p_request_id, auth.uid()
  ) then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNMENT_DENIED'
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
      and public.v1_material_request_action_assignee_eligible(
        p_request_id, profile.auth_user_id
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_get_material_request_work_assignment(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNMENT_DENIED'
      using errcode = '42501';
  end if;
  return public.v1_material_request_work_assignment_projection(p_request_id);
end;
$$;

create or replace function public.v1_assign_material_request_work(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_request_version integer;
  v_expected_assignment_version integer;
  v_assignee uuid;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_current public.v1_material_request_work_assignments%rowtype;
  v_display_name text;
  v_exact_role text;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array[
      'request_id', 'expected_request_version',
      'expected_assignment_version', 'assignee_auth_user_id', 'reason'
    ], 'assign_material_request_work'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_expected_assignment_version := nullif(
    p_payload ->> 'expected_assignment_version', ''
  )::integer;
  v_assignee := nullif(
    btrim(coalesce(p_payload ->> 'assignee_auth_user_id', '')), ''
  )::uuid;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_request_version is null
    or v_expected_request_version < 1
    or v_expected_assignment_version is null
    or v_expected_assignment_version < 0 then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNMENT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request where request.id = v_request_id
  for update;
  if not found or not public.v1_material_request_action_assignee_eligible(
    v_request_id, auth.uid()
  ) then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNMENT_DENIED'
      using errcode = '42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_assign_material_request_work', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_request.record_version <> v_expected_request_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  select * into v_current
  from public.v1_material_request_work_assignments assignment
  where assignment.request_id = v_request_id for update;
  if (not found and v_expected_assignment_version <> 0)
    or (found and v_current.assignment_version
      <> v_expected_assignment_version) then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNMENT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if found and v_current.assignee_auth_user_id is not null
    and v_current.assignee_auth_user_id is distinct from v_assignee
    and v_reason is null then
    raise exception 'V1_MATERIAL_REQUEST_REASSIGN_REASON_REQUIRED'
      using errcode = '22023';
  end if;
  if v_assignee is not null and not
    public.v1_material_request_action_assignee_eligible(
      v_request_id, v_assignee
    ) then
    raise exception 'V1_MATERIAL_REQUEST_ASSIGNEE_INELIGIBLE'
      using errcode = '42501';
  end if;

  if v_assignee is not null then
    select public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      ), user_record.raw_app_meta_data ->> 'role'
    into v_display_name, v_exact_role
    from public.v1_profiles profile
    join auth.users user_record on user_record.id = profile.auth_user_id
    where profile.auth_user_id = v_assignee and profile.is_active;
  end if;

  insert into public.v1_material_request_work_assignments (
    request_id, assignee_auth_user_id, assignee_display_name_snapshot,
    assignee_exact_role, assignment_version, assigned_by_auth_user_id,
    assigned_by_exact_role, reason, assigned_at, updated_at
  ) values (
    v_request_id, v_assignee, v_display_name, v_exact_role, 1, auth.uid(),
    public.v1_current_exact_role(), v_reason,
    case when v_assignee is null then null else clock_timestamp() end,
    clock_timestamp()
  ) on conflict (request_id) do update set
    assignee_auth_user_id = excluded.assignee_auth_user_id,
    assignee_display_name_snapshot = excluded.assignee_display_name_snapshot,
    assignee_exact_role = excluded.assignee_exact_role,
    assignment_version =
      public.v1_material_request_work_assignments.assignment_version + 1,
    assigned_by_auth_user_id = excluded.assigned_by_auth_user_id,
    assigned_by_exact_role = excluded.assigned_by_exact_role,
    reason = excluded.reason,
    assigned_at = excluded.assigned_at,
    updated_at = excluded.updated_at;

  if v_assignee is not null and v_assignee <> auth.uid() then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_assignee, 'material_request_work_assigned', 'material_request',
      v_request_id, v_request.project_id
    );
  end if;

  v_response := public.v1_material_request_work_assignment_projection(
    v_request_id
  );
  perform public.v1_write_audit_event(
    case when v_assignee is null then 'material_request_work_unassigned'
      when v_assignee = auth.uid() then 'material_request_work_claimed'
      else 'material_request_work_reassigned' end,
    'material_request', v_request_id, v_request.project_id,
    case when v_expected_assignment_version = 0 then null else jsonb_build_object(
      'assignee_auth_user_id', v_current.assignee_auth_user_id,
      'assignment_version', v_current.assignment_version
    ) end,
    v_response, v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_assign_material_request_work', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_sync_material_request_private_draft(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_draft_id uuid;
  v_expected integer;
  v_client_updated_at timestamptz;
  v_data jsonb;
  v_line jsonb;
  v_current public.v1_material_request_private_drafts%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array[
      'draft_id', 'expected_sync_version', 'client_updated_at', 'draft_data'
    ], 'sync_material_request_private_draft'
  );
  v_draft_id := nullif(btrim(coalesce(p_payload ->> 'draft_id', '')), '')::uuid;
  v_expected := nullif(p_payload ->> 'expected_sync_version', '')::integer;
  v_client_updated_at := nullif(
    p_payload ->> 'client_updated_at', ''
  )::timestamptz;
  v_data := p_payload -> 'draft_data';
  if v_actor is null or not public.v1_current_actor_is_active()
    or v_draft_id is null or v_expected is null or v_expected < 0
    or v_client_updated_at is null or jsonb_typeof(v_data) <> 'object'
    or octet_length(v_data::text) > 1048576 then
    raise exception 'V1_PRIVATE_DRAFT_INVALID' using errcode = '22023';
  end if;
  perform public.v1_assert_object_keys(
    v_data, array[
      'project_id', 'scope_id', 'title', 'timing', 'scheduled_date',
      'delivery_note', 'lines'
    ], 'private_material_request_draft_data'
  );
  if jsonb_typeof(coalesce(v_data -> 'lines', '[]'::jsonb)) <> 'array'
    or jsonb_array_length(coalesce(v_data -> 'lines', '[]'::jsonb)) > 1000
    or coalesce(v_data ->> 'timing', 'normal') not in (
      'urgent', 'normal', 'scheduled'
    ) or length(coalesce(v_data ->> 'title', '')) > 500
    or length(coalesce(v_data ->> 'delivery_note', '')) > 2000 then
    raise exception 'V1_PRIVATE_DRAFT_INVALID' using errcode = '22023';
  end if;
  if nullif(v_data ->> 'project_id', '') is not null
    and not public.v1_project_readable((v_data ->> 'project_id')::uuid) then
    raise exception 'V1_PRIVATE_DRAFT_PROJECT_DENIED' using errcode = '42501';
  end if;
  if nullif(v_data ->> 'scope_id', '') is not null and not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = (v_data ->> 'scope_id')::uuid
      and scope.project_id = (v_data ->> 'project_id')::uuid
      and scope.is_active
  ) then
    raise exception 'V1_PRIVATE_DRAFT_SCOPE_INVALID' using errcode = '22023';
  end if;
  for v_line in select value
    from jsonb_array_elements(coalesce(v_data -> 'lines', '[]'::jsonb))
  loop
    perform public.v1_assert_object_keys(
      v_line, array[
        'id', 'display_order', 'source_kind', 'source_boq_group_id',
        'source_boq_row_id', 'item_description', 'brand_origin',
        'technical_attributes', 'requested_qty', 'unit'
      ], 'private_material_request_draft_line'
    );
    if length(coalesce(v_line ->> 'item_description', '')) > 4000
      or length(coalesce(v_line ->> 'unit', '')) > 120
      or jsonb_typeof(coalesce(
        v_line -> 'technical_attributes', '{}'::jsonb
      )) <> 'object' then
      raise exception 'V1_PRIVATE_DRAFT_LINE_INVALID' using errcode = '22023';
    end if;
  end loop;
  if exists (
    select 1 from public.v1_material_requests request
    where request.id = v_draft_id and request.state <> 'draft'
  ) then
    raise exception 'V1_PRIVATE_DRAFT_ALREADY_SUBMITTED' using errcode = '22023';
  end if;

  select * into v_current
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = v_actor
  for update;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_sync_material_request_private_draft', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if (not found and v_expected <> 0)
    or (found and v_current.sync_version <> v_expected) then
    raise exception 'V1_PRIVATE_DRAFT_VERSION_CONFLICT' using errcode = '40001';
  end if;

  insert into public.v1_material_request_private_drafts (
    draft_id, owner_auth_user_id, sync_version, draft_data,
    client_updated_at, created_at, updated_at
  ) values (
    v_draft_id, v_actor, 1, v_data, v_client_updated_at,
    clock_timestamp(), clock_timestamp()
  ) on conflict (draft_id, owner_auth_user_id) do update set
    sync_version = public.v1_material_request_private_drafts.sync_version + 1,
    draft_data = excluded.draft_data,
    client_updated_at = excluded.client_updated_at,
    updated_at = clock_timestamp();

  select jsonb_build_object(
    'draft_id', draft.draft_id,
    'sync_version', draft.sync_version,
    'draft_data', draft.draft_data,
    'client_updated_at', draft.client_updated_at,
    'server_updated_at', draft.updated_at
  ) into v_response
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = v_actor;

  perform public.v1_complete_idempotency(
    'v1_sync_material_request_private_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_get_my_material_request_private_draft(
  p_draft_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PRIVATE_DRAFT_DENIED' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'draft_id', draft.draft_id,
      'sync_version', draft.sync_version,
      'draft_data', draft.draft_data,
      'client_updated_at', draft.client_updated_at,
      'server_updated_at', draft.updated_at
    )
    from public.v1_material_request_private_drafts draft
    where draft.draft_id = p_draft_id
      and draft.owner_auth_user_id = auth.uid()
  );
end;
$$;

create or replace function public.v1_list_my_material_request_private_drafts(
  p_limit integer default 50
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PRIVATE_DRAFT_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'draft_id', draft.draft_id,
      'sync_version', draft.sync_version,
      'draft_data', draft.draft_data,
      'client_updated_at', draft.client_updated_at,
      'server_updated_at', draft.updated_at
    ) order by draft.updated_at desc, draft.draft_id)
    from (
      select * from public.v1_material_request_private_drafts private_draft
      where private_draft.owner_auth_user_id = auth.uid()
      order by private_draft.updated_at desc, private_draft.draft_id
      limit least(greatest(coalesce(p_limit, 50), 1), 100)
    ) draft
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_delete_my_material_request_private_draft(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_draft_id uuid;
  v_expected integer;
  v_current public.v1_material_request_private_drafts%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['draft_id', 'expected_sync_version'],
    'delete_private_material_request_draft'
  );
  v_draft_id := nullif(btrim(coalesce(p_payload ->> 'draft_id', '')), '')::uuid;
  v_expected := nullif(p_payload ->> 'expected_sync_version', '')::integer;
  if v_draft_id is null or v_expected is null or v_expected < 1
    or auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PRIVATE_DRAFT_DELETE_INVALID' using errcode = '22023';
  end if;
  select * into v_current
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = auth.uid()
  for update;
  if not found then
    return jsonb_build_object('draft_id', v_draft_id, 'deleted', true);
  end if;
  if v_current.sync_version <> v_expected then
    raise exception 'V1_PRIVATE_DRAFT_VERSION_CONFLICT' using errcode = '40001';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_delete_my_material_request_private_draft', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  delete from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = auth.uid();
  v_response := jsonb_build_object('draft_id', v_draft_id, 'deleted', true);
  perform public.v1_complete_idempotency(
    'v1_delete_my_material_request_private_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_list_material_request_summaries(
  p_project_id uuid default null,
  p_search text default null,
  p_states text[] default null,
  p_scope_id uuid default null,
  p_requester text default null,
  p_updated_after timestamptz default null,
  p_attention_only boolean default false,
  p_metric text default 'all',
  p_sort text default 'updated_desc',
  p_limit integer default 15,
  p_offset integer default 0
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 15), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_items jsonb;
  v_total bigint;
  v_metrics jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or p_sort not in ('updated_desc', 'updated_asc')
    or p_metric not in (
      'all', 'open', 'in_progress', 'dispatched', 'received', 'closed'
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SUMMARY_LIST_DENIED'
      using errcode = '42501';
  end if;
  if p_project_id is not null and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE'
      using errcode = '42501';
  end if;

  with authorized as materialized (
    select request.*, project.project_ref, project.name as project_name,
      project.job_contract_reference, scope.name as scope_name,
      (select count(*)::integer
       from public.v1_material_request_lines line
       where line.request_id = request.id) as item_count,
      public.v1_material_request_work_assignment_projection(
        request.id
      ) as work_assignment,
      public.v1_material_request_change_summary(request.id) as change_summary
    from public.v1_material_requests request
    join public.v1_projects project on project.id = request.project_id
    join public.v1_project_scopes scope on scope.id = request.scope_id
    where public.v1_material_request_participant(request.id, auth.uid())
      and (p_project_id is null or request.project_id = p_project_id)
  ), filtered as materialized (
    select * from authorized request
    where (p_states is null or request.state = any(p_states))
      and (p_scope_id is null or request.scope_id = p_scope_id)
      and (p_requester is null
        or request.requester_display_name = p_requester)
      and (p_updated_after is null or request.updated_at >= p_updated_after)
      and (not p_attention_only or (
        request.state not in ('draft', 'closed', 'cancelled') and (
          coalesce(request.current_action_code, '') <> ''
          or request.state in (
            'awaiting_request_approval', 'changes_requested', 'arranging',
            'dispatched', 'partially_dispatched', 'partially_received',
            'received'
          )
        )
      ))
      and (p_metric = 'all'
        or (p_metric = 'open' and request.state in (
          'draft', 'submitted', 'awaiting_request_approval', 'changes_requested'
        ))
        or (p_metric = 'in_progress' and request.state not in (
          'draft', 'submitted', 'awaiting_request_approval',
          'changes_requested', 'partially_dispatched', 'dispatched',
          'partially_received', 'received', 'closed', 'cancelled'
        ))
        or (p_metric = 'dispatched' and request.state in (
          'partially_dispatched', 'dispatched'
        ))
        or (p_metric = 'received' and request.state in (
          'partially_received', 'received'
        ))
        or (p_metric = 'closed' and request.state in ('closed', 'cancelled'))
      )
      and (v_search is null or request.request_number ilike '%' || v_search || '%'
        or coalesce(request.title, '') ilike '%' || v_search || '%'
        or request.project_ref ilike '%' || v_search || '%'
        or request.project_name ilike '%' || v_search || '%'
        or request.scope_name ilike '%' || v_search || '%'
        or coalesce(request.requester_display_name, '') ilike '%' || v_search || '%'
        or exists (
          select 1 from public.v1_material_request_lines line
          where line.request_id = request.id
            and line.item_description ilike '%' || v_search || '%'
        )
      )
  ), page as (
    select * from filtered request
    order by
      case when p_sort = 'updated_desc' then request.updated_at end desc,
      case when p_sort = 'updated_asc' then request.updated_at end asc,
      request.id
    limit v_limit offset v_offset
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', page.id,
    'project_id', page.project_id,
    'project_ref', page.project_ref,
    'project_name', page.project_name,
    'job_contract_reference', page.job_contract_reference,
    'scope_id', page.scope_id,
    'scope_name', page.scope_name,
    'state', page.state,
    'record_version', page.record_version,
    'request_number', page.request_number,
    'title', page.title,
    'timing', page.timing,
    'scheduled_date', page.scheduled_date,
    'delivery_note', page.delivery_note,
    'requester_display_name', page.requester_display_name,
    'requester_project_role', page.requester_project_role,
    'requester_exact_role', page.requester_exact_role,
    'current_action_owner_role', page.current_action_owner_role,
    'current_action_code', page.current_action_code,
    'item_count', page.item_count,
    'work_assignment', page.work_assignment,
    'change_summary', page.change_summary,
    'submitted_at', page.submitted_at,
    'created_at', page.created_at,
    'updated_at', page.updated_at
  ) order by
    case when p_sort = 'updated_desc' then page.updated_at end desc,
    case when p_sort = 'updated_asc' then page.updated_at end asc,
    page.id), '[]'::jsonb)
  into v_items from page;

  with authorized as materialized (
    select request.*
    from public.v1_material_requests request
    where public.v1_material_request_participant(request.id, auth.uid())
      and (p_project_id is null or request.project_id = p_project_id)
  )
  select jsonb_build_object(
    'total', count(*),
    'open', count(*) filter (where state in (
      'draft', 'submitted', 'awaiting_request_approval', 'changes_requested'
    )),
    'in_progress', count(*) filter (where state not in (
      'draft', 'submitted', 'awaiting_request_approval', 'changes_requested',
      'partially_dispatched', 'dispatched', 'partially_received', 'received',
      'closed', 'cancelled'
    )),
    'dispatched', count(*) filter (where state in (
      'partially_dispatched', 'dispatched'
    )),
    'received', count(*) filter (where state in (
      'partially_received', 'received'
    )),
    'closed', count(*) filter (where state in ('closed', 'cancelled'))
  ) into v_metrics from authorized;

  -- The count uses the same filter contract without materializing line or
  -- comment projections. The page remains bounded even when the register grows.
  select count(*) into v_total
  from public.v1_material_requests request
  join public.v1_projects project on project.id = request.project_id
  join public.v1_project_scopes scope on scope.id = request.scope_id
  where public.v1_material_request_participant(request.id, auth.uid())
    and (p_project_id is null or request.project_id = p_project_id)
    and (p_states is null or request.state = any(p_states))
    and (p_scope_id is null or request.scope_id = p_scope_id)
    and (p_requester is null or request.requester_display_name = p_requester)
    and (p_updated_after is null or request.updated_at >= p_updated_after)
    and (not p_attention_only or (
      request.state not in ('draft', 'closed', 'cancelled') and (
        coalesce(request.current_action_code, '') <> ''
        or request.state in (
          'awaiting_request_approval', 'changes_requested', 'arranging',
          'dispatched', 'partially_dispatched', 'partially_received', 'received'
        )
      )
    ))
    and (p_metric = 'all'
      or (p_metric = 'open' and request.state in (
        'draft', 'submitted', 'awaiting_request_approval', 'changes_requested'
      ))
      or (p_metric = 'in_progress' and request.state not in (
        'draft', 'submitted', 'awaiting_request_approval', 'changes_requested',
        'partially_dispatched', 'dispatched', 'partially_received', 'received',
        'closed', 'cancelled'
      ))
      or (p_metric = 'dispatched' and request.state in (
        'partially_dispatched', 'dispatched'
      ))
      or (p_metric = 'received' and request.state in (
        'partially_received', 'received'
      ))
      or (p_metric = 'closed' and request.state in ('closed', 'cancelled'))
    )
    and (v_search is null or request.request_number ilike '%' || v_search || '%'
      or coalesce(request.title, '') ilike '%' || v_search || '%'
      or project.project_ref ilike '%' || v_search || '%'
      or project.name ilike '%' || v_search || '%'
      or scope.name ilike '%' || v_search || '%'
      or coalesce(request.requester_display_name, '') ilike '%' || v_search || '%'
      or exists (
        select 1 from public.v1_material_request_lines line
        where line.request_id = request.id
          and line.item_description ilike '%' || v_search || '%'
      )
    );

  return jsonb_build_object(
    'items', v_items,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', v_offset + jsonb_array_length(v_items) < v_total,
    'metrics', v_metrics
  );
end;
$$;

revoke all on function public.v1_material_request_capture_revision()
  from public, anon, authenticated;
revoke all on function public.v1_material_request_change_summary(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_action_assignee_eligible(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_work_assignment_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_request_comments(uuid, timestamptz, uuid, integer)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_request_work_candidates(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_material_request_work_assignment(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_assign_material_request_work(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_sync_material_request_private_draft(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_my_material_request_private_draft(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_my_material_request_private_drafts(integer)
  from public, anon, authenticated;
revoke all on function public.v1_delete_my_material_request_private_draft(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer, integer
) from public, anon, authenticated;

grant execute on function public.v1_list_material_request_comments(
  uuid, timestamptz, uuid, integer
) to authenticated, service_role;
grant execute on function public.v1_material_request_change_summary(uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_material_request_work_candidates(uuid)
  to authenticated, service_role;
grant execute on function public.v1_get_material_request_work_assignment(uuid)
  to authenticated, service_role;
grant execute on function public.v1_assign_material_request_work(jsonb, uuid)
  to authenticated, service_role;
grant execute on function public.v1_sync_material_request_private_draft(jsonb, uuid)
  to authenticated, service_role;
grant execute on function public.v1_get_my_material_request_private_draft(uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_my_material_request_private_drafts(integer)
  to authenticated, service_role;
grant execute on function public.v1_delete_my_material_request_private_draft(jsonb, uuid)
  to authenticated, service_role;
grant execute on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer, integer
) to authenticated, service_role;

comment on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer, integer
) is 'Authorized lightweight server-filtered and paginated MR register.';
comment on function public.v1_assign_material_request_work(jsonb, uuid) is
  'Versioned optional claim/reassign marker; never changes workflow state.';
comment on function public.v1_sync_material_request_private_draft(jsonb, uuid) is
  'Owner-only versioned recovery sync. Submission remains a separate command.';
