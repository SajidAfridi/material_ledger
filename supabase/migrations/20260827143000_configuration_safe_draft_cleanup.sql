begin;

-- Production enables pg-safeupdate. The configuration transaction already
-- intends to clear every staged row only after the publication/discard has
-- passed its version and authority checks, but the original unqualified
-- DELETE statements are rejected by that guard. Keep the existing functions
-- byte-for-byte apart from explicit non-null primary-key predicates.
do $migration$
declare
  v_definition text;
  v_updated text;
begin
  select pg_get_functiondef(
    'public.v1_publish_configuration_before_control_plane(text,integer,uuid)'
      ::regprocedure
  ) into v_definition;

  if position(
    'delete from public.v1_configuration_draft_changes;' in v_definition
  ) = 0 or position(
    'delete from public.v1_configuration_master_actions;' in v_definition
  ) = 0 then
    raise exception 'V1_CONFIGURATION_PUBLISH_SAFE_CLEANUP_TARGET_MISSING';
  end if;

  v_updated := replace(
    replace(
      v_definition,
      'delete from public.v1_configuration_draft_changes;',
      'delete from public.v1_configuration_draft_changes as draft_change
  where draft_change.setting_key is not null;'
    ),
    'delete from public.v1_configuration_master_actions;',
    'delete from public.v1_configuration_master_actions as master_action
  where master_action.id is not null;'
  );
  if v_updated = v_definition then
    raise exception 'V1_CONFIGURATION_PUBLISH_SAFE_CLEANUP_PATCH_NOT_APPLIED';
  end if;
  execute v_updated;

  select pg_get_functiondef(
    'public.v1_discard_configuration_draft(integer,uuid)'::regprocedure
  ) into v_definition;
  if position(
    'delete from public.v1_configuration_draft_changes;' in v_definition
  ) = 0 or position(
    'delete from public.v1_configuration_master_actions;' in v_definition
  ) = 0 then
    raise exception 'V1_CONFIGURATION_DISCARD_SAFE_CLEANUP_TARGET_MISSING';
  end if;
  v_updated := replace(
    replace(
      v_definition,
      'delete from public.v1_configuration_draft_changes;',
      'delete from public.v1_configuration_draft_changes as draft_change
  where draft_change.setting_key is not null;'
    ),
    'delete from public.v1_configuration_master_actions;',
    'delete from public.v1_configuration_master_actions as master_action
  where master_action.id is not null;'
  );
  if v_updated = v_definition then
    raise exception 'V1_CONFIGURATION_DISCARD_SAFE_CLEANUP_PATCH_NOT_APPLIED';
  end if;
  execute v_updated;
end;
$migration$;

comment on function
  public.v1_publish_configuration_before_control_plane(text, integer, uuid)
is 'Publishes a validated configuration draft and clears staged rows through pg-safeupdate-compatible primary-key predicates.';
comment on function public.v1_discard_configuration_draft(integer, uuid)
is 'Discards the current configuration draft through pg-safeupdate-compatible primary-key predicates.';

-- CREATE OR REPLACE retains ACLs. Reassert the narrow callable surface so a
-- restored or replayed environment cannot accidentally broaden access.
revoke all on function
  public.v1_publish_configuration_before_control_plane(text, integer, uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_publish_configuration_before_control_plane(text, integer, uuid)
  to service_role;
revoke all on function public.v1_discard_configuration_draft(integer, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_discard_configuration_draft(integer, uuid)
  to authenticated, service_role;

commit;
