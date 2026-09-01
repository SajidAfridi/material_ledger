-- Yorks BOQ scope-local folder management.
--
-- Product-owner revision, 1 September 2026:
-- * Common and each building own their folder names independently;
-- * a custom folder is created only in the selected real scope;
-- * any active folder, including Workshop Materials, may be renamed without
--   changing its stable group/template identity or worksheet title;
-- * custom folders may be soft-archived and restored in that same scope;
-- * the protected boq.manage_folders capability is authoritative.
--
-- Data preservation: this migration neither rewrites nor removes an existing
-- BOQ group, child row/column, document link, Material Request source, stable
-- ID, template ID or audit event. Empty sibling shells created by the former
-- project-wide behavior remain ordinary independent groups until a user
-- deliberately renames or archives them. Rollback is a corrective forward
-- migration restoring the prior RPC bodies and capability authorization mode;
-- retained folder/audit history must never be deleted.

begin;

-- Fail explicitly rather than silently choosing a winner if historical data
-- already contains two active names that the new scope-local uniqueness rule
-- cannot represent.
do $active_name_preflight$
begin
  if exists (
    select 1
    from public.v1_boq_groups group_record
    where group_record.scope_id is not null
      and not group_record.is_archived
    group by group_record.scope_id, lower(btrim(group_record.name))
    having count(*) > 1
  ) then
    raise exception 'V1_BOQ_ACTIVE_SCOPE_NAME_RECONCILIATION_REQUIRED'
      using errcode = '23514';
  end if;
end;
$active_name_preflight$;

create unique index if not exists v1_boq_groups_scope_active_name_key
  on public.v1_boq_groups (scope_id, lower(btrim(name)))
  where scope_id is not null and not is_archived;

create or replace function public.v1_validate_boq_group_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if v_name is null
    or char_length(v_name) > 120
    or v_name ~ '[[:cntrl:]]' then
    raise exception 'V1_BOQ_GROUP_NAME_INVALID' using errcode = '22023';
  end if;
  return v_name;
end;
$$;

-- Structural eligibility remains role/membership based and boq.edit remains a
-- required dependency. The newly enforced granular capability may further
-- grant/deny an otherwise eligible person, but can never manufacture project
-- access for Procurement, Accountant or an unassigned Engineering user.
create or replace function public.v1_can_manage_boq_folders(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_project_id is not null
    and public.v1_can_edit_boq_project(p_project_id)
    and public.v1_current_user_has_capability(
      'boq.manage_folders', p_project_id
    );
$$;

-- A newly inserted scope receives only the active frozen seed template(s).
-- It never copies a custom folder name from Common or another building.
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
  v_template public.v1_boq_group_templates%rowtype;
  v_display_order integer;
begin
  select * into v_scope
  from public.v1_project_scopes scope_record
  where scope_record.id = p_scope_id;
  if not found or not v_scope.is_active then
    return;
  end if;
  if p_actor is null or not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = p_actor
  ) then
    raise exception 'V1_BOQ_SCOPE_SEED_ACTOR_REQUIRED' using errcode = '55000';
  end if;

  for v_template in
    select template.*
    from public.v1_boq_group_templates template
    where template.is_frozen and template.is_active
    order by template.display_order, template.id
  loop
    if exists (
      select 1 from public.v1_boq_groups existing
      where existing.scope_id = v_scope.id
        and existing.template_id = v_template.id
        and not existing.is_archived
    ) then
      continue;
    end if;
    if exists (
      select 1 from public.v1_boq_groups existing
      where existing.scope_id = v_scope.id
        and not existing.is_archived
        and lower(btrim(existing.name)) = lower(btrim(v_template.display_name))
    ) then
      raise exception 'V1_BOQ_DEFAULT_GROUP_NAME_CONFLICT'
        using errcode = '23505';
    end if;

    v_display_order := v_template.display_order;
    if exists (
      select 1 from public.v1_boq_groups existing
      where existing.scope_id = v_scope.id
        and existing.display_order = v_display_order
        and not existing.is_archived
    ) then
      select coalesce(max(existing.display_order), 0) + 1
        into v_display_order
      from public.v1_boq_groups existing
      where existing.scope_id = v_scope.id
        and not existing.is_archived;
    end if;

    insert into public.v1_boq_groups (
      project_id, scope_id, template_id, name, worksheet_title,
      display_order, is_custom, created_by_auth_user_id, created_at,
      updated_at
    ) values (
      v_scope.project_id, v_scope.id, v_template.id,
      v_template.display_name, v_template.display_name, v_display_order,
      false, p_actor, clock_timestamp(), clock_timestamp()
    );
  end loop;
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
  v_project_state text;
  v_existing_response jsonb;
  v_group public.v1_boq_groups%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['project_id', 'scope_id', 'name'], 'boq_group'
  );
  v_project_id := nullif(
    btrim(coalesce(p_payload ->> 'project_id', '')), ''
  )::uuid;
  v_scope_id := nullif(
    btrim(coalesce(p_payload ->> 'scope_id', '')), ''
  )::uuid;
  v_name := public.v1_validate_boq_group_name(p_payload ->> 'name');
  if v_project_id is null or v_scope_id is null then
    raise exception 'V1_BOQ_GROUP_PROJECT_SCOPE_AND_NAME_REQUIRED'
      using errcode = '22023';
  end if;
  if not public.v1_can_manage_boq_folders(v_project_id) then
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

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_create_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  select project.state into v_project_state
  from public.v1_projects project
  where project.id = v_project_id
  for update;
  if not found or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = v_scope_id
      and scope_record.project_id = v_project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_scope_id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(btrim(v_name))
  ) then
    raise exception 'V1_BOQ_GROUP_NAME_ALREADY_EXISTS' using errcode = '23505';
  end if;

  insert into public.v1_boq_groups (
    project_id, scope_id, name, worksheet_title, display_order, is_custom,
    created_by_auth_user_id, created_at, updated_at
  ) values (
    v_project_id, v_scope_id, v_name, v_name,
    coalesce((
      select max(existing.display_order) + 1
      from public.v1_boq_groups existing
      where existing.scope_id = v_scope_id
        and not existing.is_archived
    ), 1),
    true, v_actor, clock_timestamp(), clock_timestamp()
  ) returning * into v_group;

  v_response := public.v1_boq_group_projection(v_group.id);
  perform public.v1_write_audit_event(
    'boq_group_created', 'boq_group', v_group.id, v_project_id,
    null, v_response, 'Scope-local custom BOQ folder created',
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_rename_boq_group(
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
  v_expected_version integer;
  v_name text;
  v_reason text;
  v_project_state text;
  v_group public.v1_boq_groups%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['group_id', 'expected_version', 'name', 'reason'],
    'rename_boq_group'
  );
  v_group_id := nullif(
    btrim(coalesce(p_payload ->> 'group_id', '')), ''
  )::uuid;
  v_expected_version := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_name := public.v1_validate_boq_group_name(p_payload ->> 'name');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_group_id is null or v_expected_version is null
    or v_expected_version < 1 or v_reason is null
    or char_length(v_reason) > 2000 then
    raise exception 'V1_BOQ_RENAME_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id;
  if not found or v_group.scope_id is null
    or not public.v1_can_manage_boq_folders(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_rename_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  perform 1 from public.v1_projects project
  where project.id = v_group.project_id
  for update;
  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id
  for update;
  select project.state into v_project_state
  from public.v1_projects project
  where project.id = v_group.project_id;
  if v_group.is_archived
    or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_group.scope_id
      and existing.id <> v_group.id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(btrim(v_name))
  ) then
    raise exception 'V1_BOQ_GROUP_NAME_ALREADY_EXISTS' using errcode = '23505';
  end if;

  v_before := public.v1_boq_group_projection(v_group.id);
  update public.v1_boq_groups
  set name = v_name,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_group.id;
  v_response := public.v1_boq_group_projection(v_group.id);
  perform public.v1_write_audit_event(
    'boq_group_renamed', 'boq_group', v_group.id, v_group.project_id,
    v_before, v_response, v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_rename_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_archive_boq_group(
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
  v_expected_version integer;
  v_reason text;
  v_project_state text;
  v_group public.v1_boq_groups%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['group_id', 'expected_version', 'reason'],
    'archive_boq_group'
  );
  v_group_id := nullif(
    btrim(coalesce(p_payload ->> 'group_id', '')), ''
  )::uuid;
  v_expected_version := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_group_id is null or v_expected_version is null
    or v_expected_version < 1
    or (v_reason is not null and char_length(v_reason) > 2000) then
    raise exception 'V1_BOQ_ARCHIVE_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id;
  if not found or v_group.scope_id is null
    or not public.v1_can_manage_boq_folders(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_archive_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  perform 1 from public.v1_projects project
  where project.id = v_group.project_id
  for update;
  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id
  for update;
  select project.state into v_project_state
  from public.v1_projects project
  where project.id = v_group.project_id;
  if v_group.is_archived
    or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if not v_group.is_custom then
    raise exception 'V1_DEFAULT_BOQ_GROUP_CANNOT_BE_ARCHIVED'
      using errcode = '22023';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;

  v_before := public.v1_boq_group_projection(v_group.id);
  update public.v1_boq_groups
  set is_archived = true,
      archived_at = clock_timestamp(),
      archived_by_auth_user_id = auth.uid(),
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_group.id;
  v_response := public.v1_boq_group_projection(v_group.id)
    || jsonb_build_object('archived', true);
  perform public.v1_write_audit_event(
    'boq_group_archived', 'boq_group', v_group.id, v_group.project_id,
    v_before, v_response,
    coalesce(v_reason, 'Scope-local custom BOQ folder archived'),
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_archive_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_restore_boq_group(
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
  v_expected_version integer;
  v_reason text;
  v_project_state text;
  v_group public.v1_boq_groups%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_display_order integer;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['group_id', 'expected_version', 'reason'],
    'restore_boq_group'
  );
  v_group_id := nullif(
    btrim(coalesce(p_payload ->> 'group_id', '')), ''
  )::uuid;
  v_expected_version := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_group_id is null or v_expected_version is null
    or v_expected_version < 1 or v_reason is null
    or char_length(v_reason) > 2000 then
    raise exception 'V1_BOQ_RESTORE_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id;
  if not found or v_group.scope_id is null
    or not public.v1_can_manage_boq_folders(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_restore_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;

  perform 1 from public.v1_projects project
  where project.id = v_group.project_id
  for update;
  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = v_group_id
  for update;
  select project.state into v_project_state
  from public.v1_projects project
  where project.id = v_group.project_id;
  if not v_group.is_archived
    or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if not v_group.is_custom then
    raise exception 'V1_DEFAULT_BOQ_GROUP_CANNOT_BE_RESTORED'
      using errcode = '22023';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_group.scope_id
      and existing.id <> v_group.id
      and not existing.is_archived
      and lower(btrim(existing.name)) = lower(btrim(v_group.name))
  ) then
    raise exception 'V1_BOQ_GROUP_NAME_ALREADY_EXISTS' using errcode = '23505';
  end if;

  v_display_order := v_group.display_order;
  if exists (
    select 1 from public.v1_boq_groups existing
    where existing.scope_id = v_group.scope_id
      and existing.id <> v_group.id
      and existing.display_order = v_display_order
      and not existing.is_archived
  ) then
    select coalesce(max(existing.display_order), 0) + 1
      into v_display_order
    from public.v1_boq_groups existing
    where existing.scope_id = v_group.scope_id
      and not existing.is_archived;
  end if;

  v_before := public.v1_boq_group_projection(v_group.id);
  update public.v1_boq_groups
  set is_archived = false,
      archived_at = null,
      archived_by_auth_user_id = null,
      display_order = v_display_order,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_group.id;
  v_response := public.v1_boq_group_projection(v_group.id)
    || jsonb_build_object('archived', false);
  perform public.v1_write_audit_event(
    'boq_group_restored', 'boq_group', v_group.id, v_group.project_id,
    v_before, v_response, v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_restore_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_list_boq_folder_management(
  p_project_id uuid,
  p_scope_id uuid,
  p_include_archived boolean default true
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_state text;
  v_project_editable boolean;
begin
  if p_project_id is null or p_scope_id is null
    or not public.v1_can_manage_boq_folders(p_project_id) then
    raise exception 'V1_BOQ_FOLDER_MANAGEMENT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = p_scope_id
      and scope_record.project_id = p_project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_INVALID' using errcode = '22023';
  end if;
  select project.state into v_project_state
  from public.v1_projects project
  where project.id = p_project_id;
  v_project_editable := v_project_state in ('draft', 'active');

  return coalesce((
    select jsonb_agg(
      public.v1_boq_group_projection(group_record.id)
      || jsonb_build_object(
        'template_key', template.template_key,
        'is_system_default', not group_record.is_custom,
        'archived_at', group_record.archived_at,
        'can_rename', v_project_editable and not group_record.is_archived,
        'can_archive', v_project_editable
          and not group_record.is_archived and group_record.is_custom,
        'can_restore', v_project_editable
          and group_record.is_archived and group_record.is_custom
          and not exists (
            select 1 from public.v1_boq_groups active_group
            where active_group.scope_id = group_record.scope_id
              and active_group.id <> group_record.id
              and not active_group.is_archived
              and lower(btrim(active_group.name)) =
                lower(btrim(group_record.name))
          ),
        'archive_blocker', case
          when not v_project_editable then 'project_not_editable'
          when group_record.is_archived then 'already_archived'
          when not group_record.is_custom then 'system_default'
          else null
        end,
        'restore_blocker', case
          when not v_project_editable then 'project_not_editable'
          when not group_record.is_archived then 'not_archived'
          when not group_record.is_custom then 'system_default'
          when exists (
            select 1 from public.v1_boq_groups active_group
            where active_group.scope_id = group_record.scope_id
              and active_group.id <> group_record.id
              and not active_group.is_archived
              and lower(btrim(active_group.name)) =
                lower(btrim(group_record.name))
          ) then 'active_name_exists'
          else null
        end
      )
      order by group_record.is_archived, group_record.display_order,
        lower(group_record.name), group_record.created_at, group_record.id
    )
    from public.v1_boq_groups group_record
    left join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.project_id = p_project_id
      and group_record.scope_id = p_scope_id
      and (p_include_archived or not group_record.is_archived)
      and (
        group_record.is_custom
        or template.is_active
        or public.v1_boq_group_has_history(group_record.id)
      )
  ), '[]'::jsonb);
end;
$$;

-- This migration is the complete protected consumer for folder management.
-- Existing exact-role defaults preserve current access; person-specific
-- project/organization grants and denies now become authoritative.
update public.v1_capability_catalog
set description = 'Create, rename, archive and restore scope-local BOQ folders.',
    authorization_mode = 'enforced'
where capability_key = 'boq.manage_folders'
  and status = 'operational';

do $capability_cutover_guard$
begin
  if not exists (
    select 1 from public.v1_capability_catalog catalog
    where catalog.capability_key = 'boq.manage_folders'
      and catalog.authorization_mode = 'enforced'
      and catalog.is_assignable
      and catalog.requires_project_access
  ) then
    raise exception 'V1_BOQ_FOLDER_CAPABILITY_CUTOVER_FAILED'
      using errcode = '23514';
  end if;
end;
$capability_cutover_guard$;

select public.v1_invalidate_active_permission_snapshots();

revoke all on function public.v1_validate_boq_group_name(text)
  from public, anon, authenticated;
revoke all on function public.v1_can_manage_boq_folders(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_seed_default_boq_groups_for_scope(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.v1_seed_default_boq_groups_for_scope(uuid,uuid)
  to service_role;

revoke all on function public.v1_create_boq_group(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_rename_boq_group(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_archive_boq_group(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_restore_boq_group(jsonb,uuid)
  from public, anon;
revoke all on function public.v1_list_boq_folder_management(uuid,uuid,boolean)
  from public, anon;

grant execute on function public.v1_create_boq_group(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_rename_boq_group(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_archive_boq_group(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_restore_boq_group(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_list_boq_folder_management(uuid,uuid,boolean)
  to authenticated;

commit;
