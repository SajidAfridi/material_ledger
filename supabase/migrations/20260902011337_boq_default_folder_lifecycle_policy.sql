-- Yorks BOQ default-folder lifecycle policy.
--
-- Product-owner revision, 2 September 2026:
-- * AC Units is no longer a seeded/protected BOQ folder. Existing retained
--   AC Units folders remain intact and may be renamed, archived and restored;
-- * Workshop Materials remains the single default for each newly created real
--   scope, but the scope owner may also rename, archive and restore it;
-- * archive is the only supported removal operation. Rows, columns, documents,
--   Material Request sources, stable IDs and audit history are never deleted.
--
-- Rollback is a corrective forward migration that clears
-- allows_scope_archive for the reviewed template keys and restores the prior
-- RPC bodies. It must not unarchive, rename or delete user-managed folders.

begin;

alter table public.v1_boq_group_templates
  add column if not exists allows_scope_archive boolean not null default false;

-- Make the forward policy explicit even when an older environment retained a
-- different catalogue state. AC Units is historical only; Workshop Materials
-- remains the sole active seed template.
update public.v1_boq_group_templates
set is_active = false,
    allows_scope_archive = true
where template_key = 'ac_units';

update public.v1_boq_group_templates
set is_active = true,
    allows_scope_archive = true
where template_key = 'workshop_materials';

create or replace function public.v1_boq_group_scope_archive_allowed(
  p_group_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(group_record.is_custom, false)
    or coalesce(template.allows_scope_archive, false)
  from public.v1_boq_groups group_record
  left join public.v1_boq_group_templates template
    on template.id = group_record.template_id
  where group_record.id = p_group_id
    and group_record.scope_id is not null;
$$;

-- Patch only the exact reviewed lifecycle checks from the 1 September RPCs.
-- Guarded source replacement makes an unexpected prior body fail the
-- migration rather than silently weakening a different authorization path.
do $archive_rpc_policy$
declare
  v_definition text;
  v_old text := $old$
  if not v_group.is_custom then
    raise exception 'V1_DEFAULT_BOQ_GROUP_CANNOT_BE_ARCHIVED'
      using errcode = '22023';
  end if;
$old$;
  v_new text := $new$
  if not public.v1_boq_group_scope_archive_allowed(v_group.id) then
    raise exception 'V1_BOQ_GROUP_ARCHIVE_PROTECTED'
      using errcode = '22023';
  end if;
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_archive_boq_group(jsonb,uuid)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    if position('v1_boq_group_scope_archive_allowed(v_group.id)' in v_definition) = 0 then
      raise exception 'V1_BOQ_ARCHIVE_POLICY_GUARD_NOT_FOUND';
    end if;
  else
    execute replace(v_definition, v_old, v_new);
  end if;
end;
$archive_rpc_policy$;

do $restore_rpc_policy$
declare
  v_definition text;
  v_old text := $old$
  if not v_group.is_custom then
    raise exception 'V1_DEFAULT_BOQ_GROUP_CANNOT_BE_RESTORED'
      using errcode = '22023';
  end if;
$old$;
  v_new text := $new$
  if not public.v1_boq_group_scope_archive_allowed(v_group.id) then
    raise exception 'V1_BOQ_GROUP_RESTORE_PROTECTED'
      using errcode = '22023';
  end if;
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_restore_boq_group(jsonb,uuid)'::regprocedure
  );
  if position(v_old in v_definition) = 0 then
    if position('v1_boq_group_scope_archive_allowed(v_group.id)' in v_definition) = 0 then
      raise exception 'V1_BOQ_RESTORE_POLICY_GUARD_NOT_FOUND';
    end if;
  else
    execute replace(v_definition, v_old, v_new);
  end if;
end;
$restore_rpc_policy$;

do $folder_management_projection_policy$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_list_boq_folder_management(uuid,uuid,boolean)'::regprocedure
  );

  if position(
    'and not group_record.is_archived and group_record.is_custom'
    in v_definition
  ) > 0 then
    v_definition := replace(
      v_definition,
      'and not group_record.is_archived and group_record.is_custom',
      'and not group_record.is_archived and public.v1_boq_group_scope_archive_allowed(group_record.id)'
    );
  elsif position(
    'and not group_record.is_archived and public.v1_boq_group_scope_archive_allowed(group_record.id)'
    in v_definition
  ) = 0 then
    raise exception 'V1_BOQ_MANAGEMENT_ARCHIVE_FLAG_GUARD_NOT_FOUND';
  end if;

  if position(
    'and group_record.is_archived and group_record.is_custom'
    in v_definition
  ) > 0 then
    v_definition := replace(
      v_definition,
      'and group_record.is_archived and group_record.is_custom',
      'and group_record.is_archived and public.v1_boq_group_scope_archive_allowed(group_record.id)'
    );
  elsif position(
    'and group_record.is_archived and public.v1_boq_group_scope_archive_allowed(group_record.id)'
    in v_definition
  ) = 0 then
    raise exception 'V1_BOQ_MANAGEMENT_RESTORE_FLAG_GUARD_NOT_FOUND';
  end if;

  if position(
    'when not group_record.is_custom then ''system_default'''
    in v_definition
  ) > 0 then
    v_definition := replace(
      v_definition,
      'when not group_record.is_custom then ''system_default''',
      'when not public.v1_boq_group_scope_archive_allowed(group_record.id) then ''protected_template'''
    );
  elsif position(
    'when not public.v1_boq_group_scope_archive_allowed(group_record.id) then ''protected_template'''
    in v_definition
  ) = 0 then
    raise exception 'V1_BOQ_MANAGEMENT_BLOCKER_GUARD_NOT_FOUND';
  end if;

  execute v_definition;
end;
$folder_management_projection_policy$;

update public.v1_capability_catalog
set description =
  'Create, rename, archive and restore scope-local BOQ folders, including reviewed template folders.'
where capability_key = 'boq.manage_folders'
  and status = 'operational';

revoke all on function public.v1_boq_group_scope_archive_allowed(uuid)
  from public, anon, authenticated;

commit;
