-- Yorks R35 controlled-document and global engineering role follow-up.
--
-- Senior Mechanical Engineer and Project Manager are exact server-owned Auth
-- claims which execute with Project Engineer workflow authority across every
-- project. They do not inherit Admin, Procurement, inventory, commercial or
-- user-administration capabilities. Delivery Orders become dispatch documents:
-- their immutable quantity snapshot is sourced from dispatch lines and may be
-- generated before receipt review. Existing orders, receipt-based revisions,
-- stock, receipts, returns and audit rows are preserved.

begin;

-- Authorization always begins with one of the six exact, server-controlled
-- Auth roles.  The workflow role is intentionally a separate normalized
-- value: the two organization-wide engineering roles execute Project Engineer
-- commands, but their exact role remains available to server audit.
create or replace function public.v1_canonical_role_from_exact_role(p_role text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case p_role
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end;
$$;

create or replace function public.v1_is_valid_role(p_role text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select public.v1_canonical_role_from_exact_role(p_role) <> '';
$$;

-- app_metadata is authoritative only when the presented JWT still agrees with
-- the current protected Auth row.  This fail-closed comparison covers role
-- changes that normalize to the same workflow role (for example, Senior
-- Mechanical Engineer -> Project Engineer), which a profile-only check cannot
-- distinguish.  It also denies a banned account before any command can claim
-- an idempotency key or mutate a workflow record.
create or replace function public.v1_current_exact_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is not null
      and public.v1_is_valid_role(
        coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
      )
      and exists (
        select 1
        from auth.users auth_user
        where auth_user.id = auth.uid()
          and coalesce(auth_user.raw_app_meta_data ->> 'role', '') =
            coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
          and (
            auth_user.banned_until is null
            or auth_user.banned_until <= clock_timestamp()
          )
      )
      then coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
    else ''
  end;
$$;

create or replace function public.v1_current_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_canonical_role_from_exact_role(
    coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
  );
$$;

-- Keep the workflow-role helper useful to callers that need to report a
-- consistent authorization error, while making the active-actor predicate the
-- mandatory live-Auth boundary.  All trusted commands and RLS wrappers call
-- this predicate before returning an authorized result or mutating state.
create or replace function public.v1_current_actor_is_active()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_exact_role() <> ''
    and exists (
      select 1
      from public.v1_profiles profile
      where profile.auth_user_id = auth.uid()
        and profile.is_active
        and profile.canonical_role_snapshot = public.v1_current_role()
    );
$$;

-- The profile remains an operational-role mirror. The exact job role stays in
-- protected Auth app_metadata and is still visible to the user-management API.
do $profile_sync$
declare
  v_definition text;
  v_anchor text := $anchor$when 'site_engineer' then 'site_engineer'
    when 'procurement' then 'procurement'$anchor$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_sync_profile_from_auth(uuid)'::regprocedure
  );
  if position('senior_mechanical_engineer' in v_definition) = 0 then
    if position(v_anchor in v_definition) = 0 then
      raise exception 'V1_GLOBAL_ENGINEER_PROFILE_SYNC_ANCHOR_MISSING';
    end if;
    execute replace(
      v_definition,
      v_anchor,
      $replacement$when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'procurement' then 'procurement'$replacement$
    );
  end if;
end;
$profile_sync$;

create or replace function public.v1_safe_auth_audit_role(
  p_raw_app_meta_data jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case coalesce(p_raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'senior_mechanical_engineer'
    when 'project_manager' then 'project_manager'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    when 'engineer' then 'engineer'
    else 'unrecognized'
  end;
$$;

create or replace function public.v1_has_active_project_membership(
  p_project_id uuid,
  p_auth_user_id uuid,
  p_required_project_role text default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
    p_auth_user_id = auth.uid()
    and coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in (
      'senior_mechanical_engineer', 'project_manager'
    )
    and public.v1_current_actor_is_active()
    and exists (
      select 1 from public.v1_projects project where project.id = p_project_id
    )
  ) or exists (
    select 1
    from public.v1_project_members member
    join public.v1_profiles profile
      on profile.auth_user_id = member.member_auth_user_id
    where member.project_id = p_project_id
      and member.member_auth_user_id = p_auth_user_id
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
      and profile.is_active
      and (
        p_required_project_role is null
        or member.project_role = p_required_project_role
      )
  );
$$;

-- Existing receipt-linked revisions remain valid. New dispatch-time revisions
-- point directly at the immutable dispatch lines and do not fabricate receipt
-- facts before the site review occurs.
alter table public.v1_delivery_order_revisions
  alter column receipt_review_id drop not null;

alter table public.v1_delivery_order_revision_lines
  add column if not exists dispatch_line_id uuid
    references public.v1_material_dispatch_lines (id) on delete restrict;
update public.v1_delivery_order_revision_lines revision_line
   set dispatch_line_id = review_line.dispatch_line_id
  from public.v1_receipt_review_lines review_line
 where review_line.id = revision_line.receipt_review_line_id
   and revision_line.dispatch_line_id is null;
alter table public.v1_delivery_order_revision_lines
  alter column dispatch_line_id set not null;

alter table public.v1_delivery_order_revision_lines
  alter column receipt_review_line_id drop not null;

alter table public.v1_delivery_order_revision_lines
  add column if not exists delivery_quantity numeric(18, 4);
update public.v1_delivery_order_revision_lines
   set delivery_quantity = good_quantity
 where delivery_quantity is null;
alter table public.v1_delivery_order_revision_lines
  alter column delivery_quantity set not null;
alter table public.v1_delivery_order_revision_lines
  drop constraint if exists v1_delivery_order_revision_lines_delivery_quantity_check;
alter table public.v1_delivery_order_revision_lines
  add constraint v1_delivery_order_revision_lines_delivery_quantity_check
  check (delivery_quantity > 0);

create unique index if not exists v1_delivery_order_revision_dispatch_line_once_idx
  on public.v1_delivery_order_revision_lines (
    delivery_order_revision_id, dispatch_line_id
  );

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
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;

  if v_project_id is null
    or v_project_state not in ('active', 'on_hold', 'completed')
    or not exists (
      select 1
      from public.v1_material_dispatches dispatch
      where dispatch.request_id = p_request_id
        and dispatch.state in (
          'dispatched', 'receipt_pending', 'partially_received', 'received'
        )
    ) then
    return false;
  end if;

  return v_role in ('procurement', 'admin')
    or (
      v_role in ('project_engineer', 'site_engineer')
      and public.v1_has_active_project_membership(
        v_project_id,
        auth.uid(),
        null
      )
    );
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
            'quantity', line.delivery_quantity::text,
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

-- Historical workflow records retain their existing canonical role values.
-- New trusted audit events additionally preserve the exact live Auth role, so
-- a global Project Engineer is not indistinguishable from a project-assigned
-- Project Engineer in the server audit trail.
alter table public.v1_audit_events
  add column if not exists actor_exact_role text
    check (actor_exact_role is null or actor_exact_role in (
      'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
      'project_manager', 'procurement', 'admin'
    ));

create or replace function public.v1_write_audit_event(
  p_event_type text,
  p_entity_type text,
  p_entity_id uuid,
  p_project_id uuid,
  p_before_data jsonb,
  p_after_data jsonb,
  p_reason text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_id uuid;
begin
  if v_actor is null or v_role = '' or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;

  insert into public.v1_audit_events (
    event_type,
    entity_type,
    entity_id,
    project_id,
    actor_auth_user_id,
    actor_role,
    actor_exact_role,
    occurred_at,
    idempotency_key,
    before_data,
    after_data,
    reason,
    request_hash
  )
  values (
    p_event_type,
    p_entity_type,
    p_entity_id,
    p_project_id,
    v_actor,
    v_role,
    v_exact_role,
    clock_timestamp(),
    p_idempotency_key,
    p_before_data,
    p_after_data,
    p_reason,
    (
      select key_record.request_hash
      from public.v1_idempotency_keys key_record
      where key_record.actor_auth_user_id = v_actor
        and key_record.idempotency_key = p_idempotency_key
      order by key_record.created_at desc
      limit 1
    )
  )
  returning id into v_id;

  return v_id;
end;
$$;

-- Extend the existing role-safe projections without changing their commercial
-- response shapes or return eligibility calculations.
do $document_identity$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_material_request_document_projection(uuid)'::regprocedure
  );
  if position('job_contract_reference' in v_definition) = 0 then
    if position($find$'project_name', project.name,$find$ in v_definition) = 0 then
      raise exception 'V1_MR_DOCUMENT_PROJECT_IDENTITY_ANCHOR_MISSING';
    end if;
    execute replace(
      v_definition,
      $find$'project_name', project.name,$find$,
      $replacement$'project_name', project.name,
    'job_contract_reference', project.job_contract_reference,$replacement$
    );
  end if;

  v_definition := pg_get_functiondef(
    'public.v1_returns_documents_workspace_projection(uuid)'::regprocedure
  );
  if position('job_contract_reference' in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'project_name', project.name,$find$,
      $replacement$'project_name', project.name,
    'job_contract_reference', project.job_contract_reference,$replacement$
    );
  end if;
  if position($find$'scope_code', scope.scope_code,$find$ in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'scope_name', scope.name,$find$,
      $replacement$'scope_name', scope.name,
    'scope_code', scope.scope_code,$replacement$
    );
  end if;
  v_definition := replace(
    v_definition,
    'v_can_generate and review.id is not null',
    $replacement$v_can_generate and dispatch.state in (
          'dispatched', 'receipt_pending', 'partially_received', 'received'
        )$replacement$
  );
  execute v_definition;
end;
$document_identity$;

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
  v_delivery_line_count integer;
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

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_generate_delivery_order(v_request_id) then
    raise exception 'V1_DELIVERY_ORDER_GENERATE_DENIED' using errcode = '42501';
  end if;

  select * into v_dispatch
  from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id
    and dispatch.request_id = v_request.id
    and dispatch.state in (
      'dispatched', 'receipt_pending', 'partially_received', 'received'
    )
  for update;
  if not found then
    raise exception 'V1_DELIVERY_ORDER_DISPATCH_REQUIRED' using errcode = '22023';
  end if;

  select * into v_review
  from public.v1_receipt_reviews review
  where review.dispatch_id = v_dispatch.id and review.state = 'confirmed'
  for update;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_generate_delivery_order', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version then
    raise exception 'V1_DELIVERY_ORDER_VERSION_CONFLICT' using errcode = '40001';
  end if;

  select count(*) into v_delivery_line_count
  from public.v1_material_dispatch_lines dispatch_line
  where dispatch_line.dispatch_id = v_dispatch.id
    and dispatch_line.dispatched_qty > 0;
  if v_delivery_line_count = 0 then
    raise exception 'V1_DELIVERY_ORDER_NO_DISPATCH_LINES' using errcode = '22023';
  end if;

  v_before := public.v1_returns_documents_workspace_projection(v_request.id);
  select * into v_delivery_order
  from public.v1_delivery_orders delivery_order
  where delivery_order.dispatch_id = v_dispatch.id for update;
  if not found then
    insert into public.v1_delivery_orders (
      request_id, dispatch_id, project_id, delivery_order_reference,
      created_by_auth_user_id, created_by_role
    ) values (
      v_request.id, v_dispatch.id, v_request.project_id, v_reference,
      v_actor, v_role
    ) returning * into v_delivery_order;
    v_revision_number := 1;
  elsif v_delivery_order.delivery_order_reference <> v_reference then
    raise exception 'V1_DELIVERY_ORDER_REFERENCE_IMMUTABLE' using errcode = '22023';
  else
    select coalesce(max(revision.revision_number), 0) + 1
      into v_revision_number
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
    delivery_order_revision_id, receipt_review_line_id, dispatch_line_id,
    display_order, item_description, good_quantity, delivery_quantity, unit
  )
  select
    v_revision_id,
    review_line.id,
    dispatch_line.id,
    row_number() over (order by request_line.display_order, dispatch_line.created_at)::integer,
    dispatch_line.item_description,
    dispatch_line.dispatched_qty,
    dispatch_line.dispatched_qty,
    dispatch_line.unit
  from public.v1_material_dispatch_lines dispatch_line
  join public.v1_material_request_lines request_line
    on request_line.id = dispatch_line.request_line_id
  left join public.v1_receipt_review_lines review_line
    on review_line.dispatch_line_id = dispatch_line.id
      and review_line.receipt_review_id = v_review.id
  where dispatch_line.dispatch_id = v_dispatch.id
    and dispatch_line.dispatched_qty > 0
  order by request_line.display_order, dispatch_line.created_at;

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
      'dispatch_line_count', v_delivery_line_count,
      'snapshot_source', 'dispatch'
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_generate_delivery_order', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_generate_delivery_order(uuid)
  from public, anon;
grant execute on function public.v1_can_generate_delivery_order(uuid)
  to authenticated;

-- RLS still runs as the querying role, so keep the raw six-role list explicit
-- here while the callable active-actor predicate above validates it against
-- the protected current Auth row.
drop policy if exists v1_boq_group_templates_select_authenticated
  on public.v1_boq_group_templates;
create policy v1_boq_group_templates_select_authenticated
on public.v1_boq_group_templates
for select
to authenticated
using (
  (select public.v1_rls_current_actor_is_active())
  and coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  )
);

-- Global Project Engineers manage project teams without needing (or creating)
-- their own membership rows.  They can use the picker, but the picker only
-- offers people whose exact live Auth role can actually be assigned to a
-- project: Project Engineer or Site Engineer.
create or replace function public.v1_list_active_profile_directory()
returns table (
  auth_user_id uuid,
  display_name text,
  eligible_role text
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED'
      using errcode = '42501';
  end if;
  if v_role not in ('project_engineer', 'site_engineer', 'admin') then
    raise exception 'V1_PROJECT_DIRECTORY_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  perform public.v1_sync_profile_from_auth(auth.uid());

  return query
  select
    profile.auth_user_id,
    public.v1_safe_profile_display_name(
      profile.display_name,
      profile.auth_user_id
    ),
    profile.canonical_role_snapshot
  from public.v1_profiles profile
  join auth.users auth_user
    on auth_user.id = profile.auth_user_id
  where profile.is_active
    and profile.canonical_role_snapshot in ('project_engineer', 'site_engineer')
    and coalesce(auth_user.raw_app_meta_data ->> 'role', '') in (
      'project_engineer', 'site_engineer'
    )
    and (auth_user.banned_until is null or auth_user.banned_until <= clock_timestamp())
  order by lower(
    public.v1_safe_profile_display_name(
      profile.display_name,
      profile.auth_user_id
    )
  ), profile.auth_user_id;
end;
$$;

revoke all on function public.v1_canonical_role_from_exact_role(text)
  from public, anon, authenticated;
revoke all on function public.v1_current_exact_role()
  from public, anon, authenticated;
revoke all on function public.v1_current_role()
  from public, anon, authenticated;
revoke all on function public.v1_is_valid_role(text)
  from public, anon, authenticated;

commit;
