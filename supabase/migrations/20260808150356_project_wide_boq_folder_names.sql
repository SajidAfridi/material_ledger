-- Yorks V1: a BOQ folder name is a project-wide structural definition.
-- Common and every active building receive an independent empty folder with
-- that name. Material rows, quantities, imports and MR sources remain owned by
-- one real scope and are never copied by this migration or command.

begin;

-- New scopes receive the 29 frozen folders plus the project's existing custom
-- folder names. This replaces only the scope seed implementation introduced by
-- R38; its trigger, privileges and trusted-call boundary remain unchanged.
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
  v_start_order integer;
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

  select coalesce(max(group_record.display_order), 0) into v_start_order
  from public.v1_boq_groups group_record
  where group_record.scope_id = v_scope.id
    and not group_record.is_archived;

  insert into public.v1_boq_groups (
    project_id, scope_id, name, worksheet_title, display_order, is_custom,
    created_by_auth_user_id, created_at, updated_at
  )
  select
    v_scope.project_id,
    v_scope.id,
    folder.name,
    folder.name,
    v_start_order + row_number() over (
      order by lower(btrim(folder.name)), folder.created_at, folder.id
    ),
    true,
    p_actor,
    clock_timestamp(),
    clock_timestamp()
  from (
    select distinct on (lower(btrim(group_record.name)))
      group_record.id, group_record.name, group_record.created_at
    from public.v1_boq_groups group_record
    where group_record.project_id = v_scope.project_id
      and group_record.is_custom
      and not group_record.is_archived
      and group_record.scope_id is distinct from v_scope.id
    order by lower(btrim(group_record.name)), group_record.created_at,
      group_record.id
  ) folder
  where not exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_scope.id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(btrim(folder.name))
  );
end;
$$;

-- Materialise missing custom folder shells for scopes that already exist.
-- Existing groups and every child row stay untouched; only empty siblings are
-- added where a normalized project folder name is absent.
with folder_definitions as (
  select distinct on (
    group_record.project_id,
    lower(btrim(group_record.name))
  )
    group_record.project_id,
    group_record.id as source_group_id,
    group_record.name,
    group_record.created_at,
    group_record.created_by_auth_user_id
  from public.v1_boq_groups group_record
  where group_record.is_custom
    and not group_record.is_archived
  order by group_record.project_id, lower(btrim(group_record.name)),
    group_record.created_at, group_record.id
), scope_maximums as (
  select
    scope_record.id as scope_id,
    scope_record.project_id,
    coalesce(max(existing.display_order), 0) as max_display_order
  from public.v1_project_scopes scope_record
  left join public.v1_boq_groups existing
    on existing.scope_id = scope_record.id
    and not existing.is_archived
  where scope_record.is_active
  group by scope_record.id, scope_record.project_id
), missing_folders as (
  select
    scope_record.scope_id,
    scope_record.project_id,
    scope_record.max_display_order,
    folder.source_group_id,
    folder.name,
    folder.created_at,
    folder.created_by_auth_user_id
  from scope_maximums scope_record
  join folder_definitions folder
    on folder.project_id = scope_record.project_id
  where not exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = scope_record.scope_id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(btrim(folder.name))
  )
), ordered_missing_folders as (
  select
    missing.*,
    row_number() over (
      partition by missing.scope_id
      order by lower(btrim(missing.name)), missing.created_at,
        missing.source_group_id
    ) as folder_offset
  from missing_folders missing
)
insert into public.v1_boq_groups (
  project_id, scope_id, name, worksheet_title, display_order, is_custom,
  created_by_auth_user_id, created_at, updated_at
)
select
  missing.project_id,
  missing.scope_id,
  missing.name,
  missing.name,
  missing.max_display_order + missing.folder_offset,
  true,
  missing.created_by_auth_user_id,
  clock_timestamp(),
  clock_timestamp()
from ordered_missing_folders missing;

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
  v_scope public.v1_project_scopes%rowtype;
  v_group public.v1_boq_groups%rowtype;
  v_origin_group public.v1_boq_groups%rowtype;
  v_response jsonb;
  v_folder_ids jsonb := '[]'::jsonb;
  v_created_count integer := 0;
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

  -- The project lock serializes name checks and per-scope display ordering.
  perform 1 from public.v1_projects project
  where project.id = v_project_id
  for update;

  if exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_scope_id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(v_name)
  ) then
    raise exception 'V1_BOQ_GROUP_NAME_ALREADY_EXISTS' using errcode = '23505';
  end if;

  for v_scope in
    select scope_record.*
    from public.v1_project_scopes scope_record
    where scope_record.project_id = v_project_id
      and scope_record.is_active
    order by
      case scope_record.scope_kind when 'common' then 0 else 1 end,
      lower(coalesce(scope_record.scope_code, '')),
      scope_record.id
  loop
    select * into v_group
    from public.v1_boq_groups existing
    where existing.scope_id = v_scope.id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(v_name)
    order by existing.created_at, existing.id
    limit 1;

    if not found then
      insert into public.v1_boq_groups (
        project_id, scope_id, name, worksheet_title, display_order, is_custom,
        created_by_auth_user_id, created_at, updated_at
      )
      values (
        v_project_id, v_scope.id, v_name, v_name,
        coalesce((
          select max(existing.display_order) + 1
          from public.v1_boq_groups existing
          where existing.scope_id = v_scope.id
            and not existing.is_archived
        ), 1),
        true, v_actor, clock_timestamp(), clock_timestamp()
      )
      returning * into v_group;
      v_created_count := v_created_count + 1;
    end if;

    if v_scope.id = v_scope_id then
      v_origin_group := v_group;
    end if;
    v_folder_ids := v_folder_ids || jsonb_build_array(v_group.id);
  end loop;

  if v_origin_group.id is null then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;

  v_response := public.v1_boq_group_projection(v_origin_group.id);
  perform public.v1_write_audit_event(
    'boq_group_created', 'boq_group', v_origin_group.id, v_project_id,
    null,
    v_response || jsonb_build_object(
      'project_wide_folder', true,
      'folder_group_ids', v_folder_ids,
      'created_scope_count', v_created_count
    ),
    'Project-wide BOQ folder name created; scope materials remain independent',
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Reconciliation recognizes the empty custom sibling shells introduced above
-- in the same way R38 recognizes empty frozen-template placeholders. It may
-- supersede only an empty shell; populated/document-linked targets still fail.
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
  v_target_display_order integer;
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

  select * into v_placeholder
  from public.v1_boq_groups group_record
  where group_record.scope_id = v_scope_id
    and not group_record.is_archived
    and (
      (
        v_group.template_id is not null
        and group_record.template_id = v_group.template_id
      )
      or (
        v_group.is_custom
        and group_record.is_custom
        and lower(btrim(group_record.name)) = lower(btrim(v_group.name))
      )
    )
  order by group_record.created_at, group_record.id
  limit 1
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
    v_target_display_order := v_placeholder.display_order;
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
      'Empty BOQ folder shell superseded by explicit legacy scope assignment',
      p_idempotency_key
    );
  elsif exists (
    select 1 from public.v1_boq_groups target_group
    where target_group.scope_id = v_scope_id
      and target_group.display_order = v_group.display_order
      and not target_group.is_archived
  ) then
    select coalesce(max(target_group.display_order), 0) + 1
      into v_target_display_order
    from public.v1_boq_groups target_group
    where target_group.scope_id = v_scope_id
      and not target_group.is_archived;
  else
    v_target_display_order := v_group.display_order;
  end if;

  v_before := public.v1_boq_group_projection(v_group_id);
  update public.v1_boq_groups
     set scope_id = v_scope_id,
         display_order = v_target_display_order,
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

revoke all on function public.v1_seed_default_boq_groups_for_scope(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.v1_seed_default_boq_groups_for_scope(uuid,uuid)
  to service_role;

revoke all on function public.v1_create_boq_group(jsonb,uuid)
  from public, anon;
grant execute on function public.v1_create_boq_group(jsonb,uuid)
  to authenticated;
revoke all on function public.v1_assign_legacy_boq_group_scope(jsonb,uuid)
  from public, anon;
grant execute on function public.v1_assign_legacy_boq_group_scope(jsonb,uuid)
  to authenticated;

commit;
