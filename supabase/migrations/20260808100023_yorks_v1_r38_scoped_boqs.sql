-- Yorks V1 R38: each physical building and the explicit Common scope own
-- independent BOQ worksheets.  The All view is an aggregate projection only;
-- it is never a persisted scope and never a write or MR-source boundary.
--
-- Existing project-level groups deliberately remain `scope_id is null`.
-- They are visible as legacy/unassigned records in the aggregate projection
-- until an authorized engineer explicitly maps them to one real scope.  This
-- migration does not copy, infer or reinterpret pre-R38 BOQ rows.

begin;

alter table public.v1_boq_groups
  add column if not exists scope_id uuid
    references public.v1_project_scopes (id) on delete restrict;

-- Project-wide ordering/template keys cannot describe independent scope
-- worksheets.  Nullable legacy rows stay intact while every scoped group is
-- unique inside its real Common/building scope.
alter table public.v1_boq_groups
  drop constraint if exists v1_boq_groups_project_id_display_order_key,
  drop constraint if exists v1_boq_groups_project_id_template_id_key,
  drop constraint if exists v1_boq_groups_scope_display_order_key,
  drop constraint if exists v1_boq_groups_scope_template_key;

-- Archived generated placeholders must not prevent an explicit, audited legacy
-- group reconciliation from taking its real scope/template position.
create unique index if not exists v1_boq_groups_scope_display_order_active_key
  on public.v1_boq_groups (scope_id, display_order)
  where not is_archived;
create unique index if not exists v1_boq_groups_scope_template_active_key
  on public.v1_boq_groups (scope_id, template_id)
  where not is_archived;

create index if not exists v1_boq_groups_project_scope_active_idx
  on public.v1_boq_groups (project_id, scope_id, display_order)
  where not is_archived;

-- Seed one frozen group set only when a *new* scope is introduced.  Existing
-- projects retain their project-level groups as explicitly unassigned legacy
-- data; creating a parallel empty BOQ for every old building would be an
-- unauthorized reinterpretation of their records.
create or replace function public.v1_seed_default_boq_groups_for_scope(
  p_scope_id uuid,
  p_actor uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope public.v1_project_scopes%rowtype;
begin
  select * into v_scope
  from public.v1_project_scopes scope_record
  where scope_record.id = p_scope_id;
  if not found or not v_scope.is_active then
    return;
  end if;

  insert into public.v1_boq_groups (
    project_id, scope_id, template_id, name, worksheet_title, display_order,
    is_custom, created_by_auth_user_id, created_at, updated_at
  )
  select
    v_scope.project_id, v_scope.id, template.id, template.display_name,
    template.display_name, template.display_order, false, p_actor,
    clock_timestamp(), clock_timestamp()
  from public.v1_boq_group_templates template
  where template.is_frozen and template.is_active
  order by template.display_order
  on conflict (scope_id, template_id) where not is_archived do nothing;
end;
$$;

create or replace function public.v1_seed_default_boq_groups_after_scope_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid;
begin
  -- The calling trusted command supplies auth.uid(); migration/bootstrap paths
  -- fall back to the immutable project creator for required attribution.
  v_actor := coalesce(auth.uid(), (
    select project.created_by_auth_user_id
    from public.v1_projects project
    where project.id = new.project_id
  ));
  if v_actor is null then
    raise exception 'V1_BOQ_SCOPE_SEED_ACTOR_REQUIRED' using errcode = '55000';
  end if;
  perform public.v1_seed_default_boq_groups_for_scope(new.id, v_actor);
  return new;
end;
$$;

drop trigger if exists v1_seed_default_boq_groups_after_scope_insert
  on public.v1_project_scopes;
create trigger v1_seed_default_boq_groups_after_scope_insert
after insert on public.v1_project_scopes
for each row execute function public.v1_seed_default_boq_groups_after_scope_insert();

-- Existing scopes receive empty independent folders too. This is additive: it
-- does not copy or reinterpret any project-level rows, which remain explicit
-- legacy/unassigned records until an engineer maps them. New scope creation
-- uses the trigger above; this one-time insert covers scopes that predate R38.
insert into public.v1_boq_groups (
  project_id, scope_id, template_id, name, worksheet_title, display_order,
  is_custom, created_by_auth_user_id, created_at, updated_at
)
select
  scope_record.project_id, scope_record.id, template.id, template.display_name,
  template.display_name, template.display_order, false,
  project.created_by_auth_user_id, clock_timestamp(), clock_timestamp()
from public.v1_project_scopes scope_record
join public.v1_projects project on project.id = scope_record.project_id
join public.v1_boq_group_templates template
  on template.is_frozen and template.is_active
where scope_record.is_active
on conflict (scope_id, template_id) where not is_archived do nothing;

-- The historical project-creation function still sends its old, scope-less
-- frozen-template insert.  A scope insert now seeds those rows first; suppress
-- only that obsolete internal insert and reject every other new scope-less
-- group.  Existing rows are unaffected because triggers never replay history.
create or replace function public.v1_boq_group_scope_integrity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_scope_project_id uuid;
begin
  if new.scope_id is null then
    if tg_op = 'INSERT'
      and new.template_id is not null
      and exists (
        select 1 from public.v1_project_scopes scope_record
        where scope_record.project_id = new.project_id
          and scope_record.is_active
      ) then
      return null;
    end if;
    if tg_op = 'INSERT' then
      raise exception 'V1_BOQ_SCOPE_REQUIRED' using errcode = '22023';
    end if;
    return new;
  end if;

  select scope_record.project_id into v_scope_project_id
  from public.v1_project_scopes scope_record
  where scope_record.id = new.scope_id
    and scope_record.is_active;
  if v_scope_project_id is null or v_scope_project_id <> new.project_id then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_boq_group_scope_integrity on public.v1_boq_groups;
create trigger v1_boq_group_scope_integrity
before insert or update of project_id, scope_id on public.v1_boq_groups
for each row execute function public.v1_boq_group_scope_integrity();

-- Adjust only the historic template-count assertion.  The original function
-- still creates projects, scopes, memberships and audit records atomically;
-- the scope trigger above now materialises 29 groups for each new scope.
do $create_project$
declare
  v_definition text;
  v_old text := $old$
  select count(*) into v_default_group_count
  from public.v1_boq_groups group_record
  where group_record.project_id = v_project_id
    and not group_record.is_custom;
  if v_default_group_count <> 29 then
$old$;
  v_new text := $new$
  select count(*) into v_default_group_count
  from public.v1_boq_groups group_record
  where group_record.project_id = v_project_id
    and not group_record.is_custom;
  if v_default_group_count <> (
    select count(*) * 29
    from public.v1_project_scopes scope_record
    where scope_record.project_id = v_project_id
      and scope_record.is_active
  ) then
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_create_project(jsonb,uuid)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_R38_CREATE_PROJECT_TEMPLATE_COUNT_GUARD_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$create_project$;

-- All mutation commands must reject an unassigned legacy group before they
-- can update rows/columns.  Keep the existing role, state, version and audit
-- checks unchanged.
do $editable_group_guard$
declare
  v_definition text;
  v_function regprocedure;
  v_old text :=
    'if not found or not public.v1_can_edit_boq_project(v_group.project_id) then';
  v_new text :=
    'if not found or v_group.scope_id is null or not public.v1_can_edit_boq_project(v_group.project_id) then';
begin
  foreach v_function in array array[
    'public.v1_save_boq_worksheet(jsonb,uuid)'::regprocedure,
    'public.v1_archive_boq_group(jsonb,uuid)'::regprocedure,
    'public.v1_import_boq_worksheet(jsonb,uuid)'::regprocedure
  ] loop
    v_definition := pg_get_functiondef(v_function);
    if position(v_old in v_definition) = 0 then
      raise exception 'V1_R38_BOQ_SCOPE_GUARD_NOT_FOUND: %', v_function;
    end if;
    execute replace(v_definition, v_old, v_new);
  end loop;
end;
$editable_group_guard$;

create or replace function public.v1_boq_group_projection(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', group_record.id,
    'project_id', group_record.project_id,
    'scope_id', group_record.scope_id,
    'scope_kind', scope_record.scope_kind,
    'scope_code', scope_record.scope_code,
    'scope_name', scope_record.name,
    'is_legacy_unassigned', group_record.scope_id is null,
    'name', group_record.name,
    'worksheet_title', group_record.worksheet_title,
    'display_order', group_record.display_order,
    'is_custom', group_record.is_custom,
    'is_archived', group_record.is_archived,
    'record_version', group_record.record_version,
    'row_count', (
      select count(*) from public.v1_boq_rows row_record
      where row_record.group_id = group_record.id and not row_record.is_archived
    ),
    'column_count', (
      select count(*) from public.v1_boq_columns column_record
      where column_record.group_id = group_record.id
        and not column_record.is_archived
    ),
    'updated_at', group_record.updated_at
  )
  from public.v1_boq_groups group_record
  left join public.v1_project_scopes scope_record
    on scope_record.id = group_record.scope_id
  where group_record.id = p_group_id;
$$;

-- Keep the pre-R38 one-argument projection for older clients: it selects the
-- explicit Common scope, never a synthetic all-buildings write target.
create or replace function public.v1_list_boq_groups(p_project_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_common_scope_id uuid;
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_BOQ_PROJECT_NOT_READABLE' using errcode = '42501';
  end if;
  select scope_record.id into v_common_scope_id
  from public.v1_project_scopes scope_record
  where scope_record.project_id = p_project_id
    and scope_record.scope_kind = 'common'
    and scope_record.is_active;
  return public.v1_list_boq_groups_for_scope(p_project_id, v_common_scope_id);
end;
$$;

create or replace function public.v1_list_boq_groups_for_scope(
  p_project_id uuid,
  p_scope_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_BOQ_PROJECT_NOT_READABLE' using errcode = '42501';
  end if;
  if p_scope_id is not null and not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = p_scope_id
      and scope_record.project_id = p_project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_NOT_READABLE' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.v1_boq_group_projection(group_record.id)
      order by
        case when group_record.scope_id is null then 0 else 1 end,
        case scope_record.scope_kind when 'common' then 0 else 1 end,
        lower(coalesce(scope_record.scope_code, '')),
        group_record.display_order,
        group_record.created_at)
    from public.v1_boq_groups group_record
    left join public.v1_project_scopes scope_record
      on scope_record.id = group_record.scope_id
    where group_record.project_id = p_project_id
      and not group_record.is_archived
      and (p_scope_id is null or group_record.scope_id = p_scope_id)
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_create_boq_group(
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
  v_project_id uuid;
  v_scope_id uuid;
  v_name text;
  v_existing_response jsonb;
  v_group public.v1_boq_groups%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['project_id', 'scope_id', 'name'], 'boq_group'
  );
  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_name := nullif(btrim(coalesce(p_payload ->> 'name', '')), '');
  if v_project_id is null or v_scope_id is null or v_name is null then
    raise exception 'V1_BOQ_GROUP_PROJECT_SCOPE_AND_NAME_REQUIRED' using errcode = '22023';
  end if;
  if not public.v1_can_edit_boq_project(v_project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = v_scope_id
      and scope_record.project_id = v_project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;
  if (select state from public.v1_projects where id = v_project_id)
      not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_create_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  perform 1 from public.v1_projects project where project.id = v_project_id for update;
  insert into public.v1_boq_groups (
    project_id, scope_id, name, worksheet_title, display_order, is_custom,
    created_by_auth_user_id, created_at, updated_at
  )
  values (
    v_project_id, v_scope_id, v_name, v_name,
    coalesce((select max(display_order) + 1 from public.v1_boq_groups
      where scope_id = v_scope_id), 1),
    true, v_actor, clock_timestamp(), clock_timestamp()
  )
  returning * into v_group;
  v_response := public.v1_boq_group_projection(v_group.id);
  perform public.v1_write_audit_event(
    'boq_group_created', 'boq_group', v_group.id, v_project_id,
    null, v_response, 'Custom BOQ group created', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Explicit reconciliation path for preserved project-level records.  A group
-- may be assigned only when every linked BOQ line belongs to a draft whose
-- selected scope is the chosen target; submitted history is never rewritten.
create or replace function public.v1_assign_legacy_boq_group_scope(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
  v_scope_id uuid;
  v_expected_version integer;
  v_group public.v1_boq_groups%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_placeholder public.v1_boq_groups%rowtype;
  v_placeholder_before jsonb;
  v_placeholder_replaced boolean := false;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['group_id', 'scope_id', 'expected_version'],
    'assign_legacy_boq_group_scope'
  );
  v_group_id := nullif(btrim(coalesce(p_payload ->> 'group_id', '')), '')::uuid;
  v_scope_id := nullif(btrim(coalesce(p_payload ->> 'scope_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_group_id is null or v_scope_id is null or v_expected_version is null then
    raise exception 'V1_BOQ_SCOPE_ASSIGNMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_group from public.v1_boq_groups group_record
  where group_record.id = v_group_id for update;
  if not found or not public.v1_can_edit_boq_project(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_assign_legacy_boq_group_scope', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_group.scope_id is not null then
    raise exception 'V1_BOQ_SCOPE_ALREADY_ASSIGNED' using errcode = '22023';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = v_scope_id
      and scope_record.project_id = v_group.project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;
  if v_group.template_id is not null then
    select * into v_placeholder
    from public.v1_boq_groups group_record
    where group_record.scope_id = v_scope_id
      and group_record.template_id = v_group.template_id
      and not group_record.is_archived
    for update;
    if found and v_placeholder.id <> v_group.id then
      v_placeholder_replaced := true;
      if exists (
        select 1 from public.v1_boq_rows row_record
        where row_record.group_id = v_placeholder.id and not row_record.is_archived
      ) or exists (
        select 1 from public.v1_boq_columns column_record
        where column_record.group_id = v_placeholder.id and not column_record.is_archived
      ) or exists (
        select 1 from public.v1_document_links link_record
        where link_record.entity_type = 'boq_group'
          and link_record.entity_id = v_placeholder.id
          and link_record.removed_at is null
      ) then
        raise exception 'V1_BOQ_SCOPE_ASSIGNMENT_TARGET_NOT_EMPTY'
          using errcode = '22023';
      end if;
    end if;
  end if;
  if exists (
    select 1
    from public.v1_material_request_lines line_record
    join public.v1_material_requests request_record
      on request_record.id = line_record.request_id
    where line_record.source_boq_group_id = v_group.id
      and (
        request_record.state <> 'draft'
        or request_record.scope_id <> v_scope_id
      )
  ) then
    raise exception 'V1_BOQ_SCOPE_ASSIGNMENT_HISTORY_CONFLICT' using errcode = '22023';
  end if;

  if v_placeholder_replaced then
    v_placeholder_before := public.v1_boq_group_projection(v_placeholder.id);
    update public.v1_boq_groups
       set is_archived = true,
           archived_at = clock_timestamp(),
           archived_by_auth_user_id = auth.uid(),
           record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_placeholder.id;
    perform public.v1_write_audit_event(
      'boq_group_scope_placeholder_superseded', 'boq_group', v_placeholder.id,
      v_group.project_id, v_placeholder_before,
      public.v1_boq_group_projection(v_placeholder.id),
      'Empty generated BOQ group superseded by explicit legacy scope assignment',
      p_idempotency_key
    );
  end if;
  v_before := public.v1_boq_group_projection(v_group_id);
  update public.v1_boq_groups
     set scope_id = v_scope_id,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_group_id;
  v_response := public.v1_boq_group_projection(v_group_id);
  perform public.v1_write_audit_event(
    'boq_group_scope_assigned', 'boq_group', v_group_id, v_group.project_id,
    v_before, v_response, 'Legacy BOQ scope assigned', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_assign_legacy_boq_group_scope', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- BOQ-derived MR lines are valid only in the same persisted scope as the
-- request.  This is a server-side invariant; the UI selector is convenience,
-- not authority.  Existing submitted snapshots remain untouched.
do $mr_scope_guard$
declare
  v_definition text;
  v_old text := $old$
        where group_record.id = v_source_group_id
          and group_record.project_id = v_project_id
          and row_record.id = v_source_row_id
$old$;
  v_new text := $new$
        where group_record.id = v_source_group_id
          and group_record.project_id = v_project_id
          and group_record.scope_id = v_scope_id
          and not group_record.is_archived
          and row_record.id = v_source_row_id
          and not row_record.is_archived
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_material_request_draft(jsonb)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_R38_MR_DRAFT_SCOPE_GUARD_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$mr_scope_guard$;

do $mr_submit_scope_guard$
declare
  v_definition text;
  v_old text := $old$
  if not exists (
    select 1 from public.v1_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
$old$;
  v_new text := $new$
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
  if not exists (
    select 1 from public.v1_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_submit_material_request(jsonb,uuid)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_R38_MR_SUBMIT_SCOPE_GUARD_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$mr_submit_scope_guard$;

revoke all on function public.v1_seed_default_boq_groups_for_scope(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_seed_default_boq_groups_after_scope_insert()
  from public, anon, authenticated;
revoke all on function public.v1_boq_group_scope_integrity()
  from public, anon, authenticated;
revoke all on function public.v1_list_boq_groups_for_scope(uuid,uuid)
  from public, anon;
revoke all on function public.v1_assign_legacy_boq_group_scope(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_create_boq_group(jsonb,uuid)
  from public, anon;
grant execute on function public.v1_list_boq_groups_for_scope(uuid,uuid)
  to authenticated;
grant execute on function public.v1_assign_legacy_boq_group_scope(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_create_boq_group(jsonb,uuid)
  to authenticated;

commit;
