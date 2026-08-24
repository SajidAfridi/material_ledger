-- Yorks V1 Configuration control plane truth and runtime enforcement.
--
-- Data preservation:
-- * existing published values, drafts, publications and master data are kept;
-- * every setting is classified as operational, protected, or planned;
-- * a protected/planned legacy draft is retained but blocks publication until
--   an Admin explicitly clears or discards it;
-- * published policy affects future commands only. Existing material requests,
--   notifications and controlled documents are never rewritten.
--
-- Rollback is forward-only: publish the previous operational values, hide the
-- new client affordances, and keep classification/history columns. Do not drop
-- publication evidence or reinterpret historical records.

begin;

alter table public.v1_configuration_settings
  add column if not exists control_mode text not null default 'planned'
    check (control_mode in ('operational', 'protected', 'planned')),
  add column if not exists impact_scope text[] not null default '{}'::text[],
  add column if not exists enforcement_target text not null
    default 'retained_reference';

update public.v1_configuration_settings
set control_mode = 'planned',
    impact_scope = array[area]::text[],
    enforcement_target = 'retained_reference';

update public.v1_configuration_settings
set control_mode = 'operational',
    impact_scope = case setting_key
      when 'notifications.push_enabled' then array['notifications']::text[]
      when 'procurement.require_external_source_readiness'
        then array['procurement_inventory']::text[]
      else array['material_requests']::text[]
    end,
    enforcement_target = case setting_key
      when 'requests.default_timing'
        then 'mr_draft_default_timing'
      when 'requests.urgent_enabled'
        then 'mr_urgent_submission_guard'
      when 'requests.allow_authorized_creator_self_approval'
        then 'mr_self_approval_guard'
      when 'procurement.require_external_source_readiness'
        then 'procurement_external_readiness_guard'
      when 'notifications.push_enabled'
        then 'notification_push_outbox'
    end
where setting_key in (
  'requests.default_timing',
  'requests.urgent_enabled',
  'requests.allow_authorized_creator_self_approval',
  'procurement.require_external_source_readiness',
  'notifications.push_enabled'
);

update public.v1_configuration_settings
set control_mode = 'protected',
    impact_scope = case
      when area = 'company_regional'
        then array['company_regional', 'documents_printing']::text[]
      else array[area]::text[]
    end,
    enforcement_target = case
      when setting_key like 'company.%'
        then 'controlled_document_identity'
      when setting_key = 'regional.currency'
        then 'aed_commercial_boundary'
      when setting_key = 'procurement.default_source'
        then 'warehouse_first_arrangement'
      when setting_key in (
        'documents.maximum_file_size_mb',
        'documents.allowed_formats',
        'documents.bilingual_header'
      ) then 'storage_document_contract'
      when setting_key in ('security.log_exports', 'security.log_access_changes')
        then 'append_only_audit_contract'
      when setting_key like 'numbering.%'
        then 'trusted_server_numbering'
      else 'product_invariant'
    end
where setting_key like 'company.%'
   or setting_key = 'regional.currency'
   or setting_key = 'procurement.default_source'
   or setting_key in (
     'documents.maximum_file_size_mb',
     'documents.allowed_formats',
     'documents.bilingual_header',
     'security.log_exports',
     'security.log_access_changes'
   )
   or setting_key like 'numbering.%';

comment on column public.v1_configuration_settings.control_mode is
  'Operational is server-consumed and publishable; protected is an invariant; planned is retained but not active.';
comment on column public.v1_configuration_settings.impact_scope is
  'Allowlisted configuration areas affected by future published use.';
comment on column public.v1_configuration_settings.enforcement_target is
  'Stable localized code for the authoritative consumer or protected/planned reason.';

-- Keep the original stage transaction/idempotency implementation, but refuse
-- configuration theatre. A legacy non-operational draft may only be cleared
-- back to its published value.
alter function public.v1_stage_configuration_setting(text, jsonb, integer, uuid)
  rename to v1_stage_configuration_setting_before_control_plane;

create or replace function public.v1_stage_configuration_setting(
  p_setting_key text,
  p_value jsonb,
  p_expected_revision integer,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_setting public.v1_configuration_settings%rowtype;
  v_has_legacy_draft boolean;
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_cleanup_payload jsonb := jsonb_build_object(
    'setting_key', p_setting_key,
    'value', p_value,
    'expected_revision', p_expected_revision,
    'operation', 'clear_non_operational_draft'
  );
begin
  perform public.v1_assert_configuration_admin();
  select * into v_setting
  from public.v1_configuration_settings setting
  where setting.setting_key = p_setting_key;
  if not found then
    raise exception 'V1_CONFIGURATION_SETTING_NOT_EDITABLE'
      using errcode = '22023';
  end if;
  select exists (
    select 1 from public.v1_configuration_draft_changes change
    where change.setting_key = p_setting_key
  ) into v_has_legacy_draft;
  if v_setting.control_mode <> 'operational' then
    if not (v_has_legacy_draft and p_value = v_setting.published_value) then
      raise exception 'V1_CONFIGURATION_SETTING_NOT_OPERATIONAL'
        using errcode = '22023',
          detail = format('%s is %s: %s', p_setting_key,
            v_setting.control_mode, v_setting.enforcement_target);
    end if;

    -- Older releases permitted some retained values that no longer pass their
    -- own legacy editor validation (for example the 90-day Accounts baseline).
    -- Clearing such a draft is a revision-checked idempotent delete, not a new
    -- value publication, so it deliberately bypasses that obsolete validator.
    v_existing := public.v1_idempotency_get_or_claim(
      'v1_clear_non_operational_configuration_draft',
      p_idempotency_key, v_cleanup_payload
    );
    if v_existing is not null then return v_existing; end if;
    select * into v_state
    from public.v1_configuration_draft_state
    where singleton
    for update;
    if p_expected_revision is null
      or p_expected_revision <> v_state.draft_revision then
      raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
        using errcode = '40001';
    end if;
    delete from public.v1_configuration_draft_changes
    where setting_key = p_setting_key;
    update public.v1_configuration_draft_state set
      draft_revision = draft_revision + 1,
      updated_by_auth_user_id = auth.uid(),
      updated_at = clock_timestamp()
    where singleton
    returning draft_revision into v_state.draft_revision;
    v_response := jsonb_build_object(
      'draft_revision', v_state.draft_revision,
      'setting_key', p_setting_key,
      'cleared', true
    );
    perform public.v1_complete_idempotency(
      'v1_clear_non_operational_configuration_draft',
      p_idempotency_key, v_response
    );
    return v_response;
  end if;
  return public.v1_stage_configuration_setting_before_control_plane(
    p_setting_key, p_value, p_expected_revision, p_idempotency_key
  );
end;
$$;

-- Validation keeps real master-data dependency checks, removes recommendations
-- for security/email/account controls that are not enforced, and proves that
-- operational settings form a coherent future policy.
alter function public.v1_get_configuration_validation()
  rename to v1_get_configuration_validation_before_control_plane;

create or replace function public.v1_get_configuration_validation()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_legacy jsonb;
  v_blocking jsonb := '[]'::jsonb;
  v_recommendations jsonb := '[]'::jsonb;
  v_urgent_enabled boolean;
  v_default_timing text;
begin
  perform public.v1_assert_configuration_admin();
  v_legacy := public.v1_get_configuration_validation_before_control_plane();

  select coalesce(jsonb_agg(issue.value), '[]'::jsonb)
    into v_blocking
  from jsonb_array_elements(coalesce(v_legacy -> 'blocking', '[]'::jsonb)) issue
  where issue.value ->> 'code' in (
    'material_category_conflict',
    'material_unit_conflict',
    'master_archive_conflict'
  );

  if exists (
    select 1
    from public.v1_configuration_draft_changes change
    join public.v1_configuration_settings setting
      on setting.setting_key = change.setting_key
    where setting.control_mode <> 'operational'
  ) then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'non_operational_draft_change',
      'area', 'overview',
      'message', 'A legacy protected or planned draft change must be cleared before publication.'
    ));
  end if;

  v_urgent_enabled := coalesce((public.v1_configuration_effective_value(
    'requests.urgent_enabled'
  ) #>> '{}')::boolean, true);
  v_default_timing := coalesce(public.v1_configuration_effective_value(
    'requests.default_timing'
  ) #>> '{}', 'normal');
  if not v_urgent_enabled and v_default_timing = 'urgent' then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'urgent_default_requires_urgent_enabled',
      'area', 'material_requests',
      'message', 'Urgent cannot be the default while urgent requests are disabled.'
    ));
  end if;

  if not coalesce((public.v1_configuration_effective_value(
    'notifications.push_enabled'
  ) #>> '{}')::boolean, true) then
    v_recommendations := v_recommendations || jsonb_build_array(
      jsonb_build_object(
        'code', 'push_notifications_recommended',
        'area', 'notifications',
        'message', 'Push notifications are disabled; durable in-app notifications remain available.'
      )
    );
  end if;

  return jsonb_build_object(
    'status', case
      when jsonb_array_length(v_blocking) > 0 then 'blocked'
      when jsonb_array_length(v_recommendations) > 0 then 'recommendations'
      else 'ready'
    end,
    'blocking', v_blocking,
    'recommendations', v_recommendations
  );
end;
$$;

-- Reset means baseline for operational settings only. Protected and planned
-- reference values never enter the publish queue.
alter function public.v1_restore_configuration_defaults(integer, uuid)
  rename to v1_restore_configuration_defaults_before_control_plane;

create or replace function public.v1_restore_configuration_defaults(
  p_expected_revision integer,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_payload jsonb := jsonb_build_object(
    'expected_revision', p_expected_revision,
    'scope', 'operational_settings'
  );
begin
  perform public.v1_assert_configuration_admin();
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_restore_configuration_defaults_control_plane',
    p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;

  select * into v_state
  from public.v1_configuration_draft_state
  where singleton
  for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  if not exists (
    select 1
    from public.v1_configuration_settings setting
    where setting.control_mode = 'operational'
      and public.v1_configuration_effective_value(setting.setting_key)
        <> setting.default_value
  ) then
    v_response := jsonb_build_object(
      'draft_revision', v_state.draft_revision,
      'restored', true,
      'unchanged', true,
      'scope', 'operational_settings'
    );
    perform public.v1_complete_idempotency(
      'v1_restore_configuration_defaults_control_plane',
      p_idempotency_key, v_response
    );
    return v_response;
  end if;

  insert into public.v1_configuration_draft_changes (
    setting_key, proposed_value, staged_by_auth_user_id, staged_at
  )
  select setting.setting_key, setting.default_value, auth.uid(),
    clock_timestamp()
  from public.v1_configuration_settings setting
  where setting.control_mode = 'operational'
    and setting.default_value <> setting.published_value
  on conflict (setting_key) do update set
    proposed_value = excluded.proposed_value,
    staged_by_auth_user_id = excluded.staged_by_auth_user_id,
    staged_at = excluded.staged_at;

  delete from public.v1_configuration_draft_changes change
  using public.v1_configuration_settings setting
  where change.setting_key = setting.setting_key
    and setting.control_mode = 'operational'
    and setting.default_value = setting.published_value;

  update public.v1_configuration_draft_state set
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = auth.uid(),
    updated_at = clock_timestamp()
  where singleton
  returning draft_revision into v_state.draft_revision;

  v_response := jsonb_build_object(
    'draft_revision', v_state.draft_revision,
    'restored', true,
    'scope', 'operational_settings'
  );
  perform public.v1_complete_idempotency(
    'v1_restore_configuration_defaults_control_plane',
    p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Enrich the exact-Admin projection without duplicating the large, already
-- hardened master/history projection.
alter function public.v1_get_configuration_centre()
  rename to v1_get_configuration_centre_before_control_plane;

create or replace function public.v1_get_configuration_centre()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_settings jsonb;
  v_draft_editor text;
begin
  perform public.v1_assert_configuration_admin();
  v_result := public.v1_get_configuration_centre_before_control_plane();

  select coalesce(jsonb_agg(
    setting_json.value || jsonb_build_object(
      'control_mode', setting.control_mode,
      'impact_scope', to_jsonb(setting.impact_scope),
      'enforcement_target', setting.enforcement_target,
      'staged_by', case when change.setting_key is null then null
        else public.v1_safe_profile_display_name(
          staged_profile.display_name, staged_profile.auth_user_id
        ) end,
      'staged_at', change.staged_at
    ) order by setting.display_order
  ), '[]'::jsonb) into v_settings
  from jsonb_array_elements(coalesce(v_result -> 'settings', '[]'::jsonb))
    setting_json(value)
  join public.v1_configuration_settings setting
    on setting.setting_key = setting_json.value ->> 'key'
  left join public.v1_configuration_draft_changes change
    on change.setting_key = setting.setting_key
  left join public.v1_profiles staged_profile
    on staged_profile.auth_user_id = change.staged_by_auth_user_id;

  select case when draft.updated_by_auth_user_id is null then null
    else public.v1_safe_profile_display_name(
      editor.display_name, editor.auth_user_id
    ) end
  into v_draft_editor
  from public.v1_configuration_draft_state draft
  left join public.v1_profiles editor
    on editor.auth_user_id = draft.updated_by_auth_user_id
  where draft.singleton;

  return (v_result - 'settings') || jsonb_build_object(
    'schema_version', 'R38.6 / 1.1',
    'settings', v_settings,
    'draft_updated_by', v_draft_editor,
    'operational_health', jsonb_build_object(
      'push_enabled', public.v1_material_request_published_policy_boolean(
        'notifications.push_enabled', true
      ),
      'active_device_count', (
        select count(*) from public.v1_push_device_tokens device
        where device.last_seen_at >= clock_timestamp() - interval '90 days'
      ),
      'pending_delivery_count', (
        select count(*) from public.v1_notification_push_outbox outbox
        where outbox.status in ('pending', 'sending', 'failed')
      ),
      'recent_failure_count', (
        select count(*) from public.v1_notification_push_outbox outbox
        where outbox.status = 'failed'
          and outbox.updated_at >= clock_timestamp() - interval '24 hours'
      ),
      'last_successful_delivery_at', (
        select max(outbox.completed_at)
        from public.v1_notification_push_outbox outbox
        where outbox.status = 'sent'
      )
    )
  );
end;
$$;

-- A narrow, role-safe runtime projection is the only client configuration
-- surface outside the Admin centre. It contains published non-sensitive policy
-- only; drafts and protected values never leave the control plane.
create or replace function public.v1_get_runtime_configuration()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_latest public.v1_configuration_publications%rowtype;
  v_role text := public.v1_current_exact_role();
begin
  if auth.uid() is null
    or not public.v1_current_actor_is_active()
    or v_role not in (
      'project_engineer', 'site_engineer', 'procurement', 'admin',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    raise exception 'V1_CONFIGURATION_ACTIVE_USER_REQUIRED'
      using errcode = '42501';
  end if;
  select * into v_latest
  from public.v1_configuration_publications publication
  order by publication.version_number desc
  limit 1;
  return jsonb_build_object(
    'schema_version', 'R38.6 / 1.1',
    'published_version', v_latest.version_number,
    'published_label', v_latest.version_label,
    'published_at', v_latest.published_at,
    'default_timing', coalesce((
      select setting.published_value #>> '{}'
      from public.v1_configuration_settings setting
      where setting.setting_key = 'requests.default_timing'
    ), 'normal'),
    'urgent_enabled', public.v1_material_request_published_policy_boolean(
      'requests.urgent_enabled', true
    ),
    'allow_authorized_creator_self_approval',
      public.v1_material_request_published_policy_boolean(
        'requests.allow_authorized_creator_self_approval', true
      ),
    'require_external_source_readiness',
      public.v1_material_request_published_policy_boolean(
        'procurement.require_external_source_readiness', false
      ),
    'push_enabled', public.v1_material_request_published_policy_boolean(
      'notifications.push_enabled', true
    )
  );
end;
$$;

create or replace function public.v1_get_configuration_publication_detail(
  p_publication_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform public.v1_assert_configuration_admin();
  select jsonb_build_object(
    'publication', jsonb_build_object(
      'id', publication.id,
      'version_number', publication.version_number,
      'version_label', publication.version_label,
      'reason', publication.reason,
      'affected_areas', publication.affected_areas,
      'published_at', publication.published_at,
      'published_by', coalesce(
        public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ), 'System baseline'
      ),
      'published_by_exact_role', publication.published_by_exact_role,
      'change_count', (
        select count(*)
        from public.v1_configuration_publication_changes change
        where change.publication_id = publication.id
      )
    ),
    'changes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', change.setting_key,
        'setting_key', change.setting_key,
        'area', change.area,
        'before_value', change.before_value,
        'after_value', change.after_value,
        'change_kind', change.change_kind
      ) order by change.area, change.setting_key)
      from public.v1_configuration_publication_changes change
      where change.publication_id = publication.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_configuration_publications publication
  left join public.v1_profiles profile
    on profile.auth_user_id = publication.published_by_auth_user_id
  where publication.id = p_publication_id;
  if v_result is null then
    raise exception 'V1_CONFIGURATION_PUBLICATION_NOT_FOUND'
      using errcode = 'P0002';
  end if;
  return v_result;
end;
$$;

-- System master records are part of the controlled import/request contract.
-- Admin may add and later archive custom records, but cannot remove the
-- baseline vocabulary that existing files and workflows depend on.
alter function public.v1_stage_configuration_master_action(
  text, text, uuid, jsonb, text, integer, uuid
) rename to v1_stage_configuration_master_action_before_control_plane;

create or replace function public.v1_stage_configuration_master_action(
  p_entity_kind text,
  p_action_kind text,
  p_target_id uuid,
  p_payload jsonb,
  p_reason text,
  p_expected_revision integer,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_assert_configuration_admin();
  if p_action_kind = 'archive' and (
    (p_entity_kind = 'material_category' and exists (
      select 1 from public.v1_inventory_categories category
      where category.id = p_target_id and category.is_system
    ))
    or (p_entity_kind = 'material_unit' and exists (
      select 1 from public.v1_configuration_units unit_record
      where unit_record.id = p_target_id and unit_record.is_system
    ))
  ) then
    raise exception 'V1_CONFIGURATION_SYSTEM_MASTER_PROTECTED'
      using errcode = '23514';
  end if;
  return public.v1_stage_configuration_master_action_before_control_plane(
    p_entity_kind, p_action_kind, p_target_id, p_payload, p_reason,
    p_expected_revision, p_idempotency_key
  );
end;
$$;

-- A publication that archives controlled master data locks its targets before
-- revalidation. New unit/category dependants take a matching key-share lock,
-- so a competing writer either commits before validation or rechecks the now
-- inactive target after publication. This closes the validation-to-commit gap.
alter function public.v1_publish_configuration(text, integer, uuid)
  rename to v1_publish_configuration_before_control_plane;

create or replace function public.v1_publish_configuration(
  p_reason text,
  p_expected_revision integer,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.v1_assert_configuration_admin();

  perform 1
  from public.v1_inventory_categories target
  join public.v1_configuration_master_actions action
    on action.target_id = target.id
   and action.entity_kind = 'material_category'
   and action.action_kind = 'archive'
  for update of target;

  perform 1
  from public.v1_configuration_units target
  join public.v1_configuration_master_actions action
    on action.target_id = target.id
   and action.entity_kind = 'material_unit'
   and action.action_kind = 'archive'
  for update of target;

  return public.v1_publish_configuration_before_control_plane(
    p_reason, p_expected_revision, p_idempotency_key
  );
end;
$$;

create or replace function public.v1_enforce_active_configuration_unit()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_unit_id uuid;
begin
  select unit_record.id into v_unit_id
  from public.v1_configuration_units unit_record
  where unit_record.is_active
    and lower(btrim(unit_record.short_code)) = lower(btrim(new.unit))
  for key share;
  if v_unit_id is null then
    raise exception 'V1_CONFIGURATION_UNIT_NOT_ACTIVE'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function public.v1_enforce_active_inventory_category_parent()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.parent_category_id is null then return new; end if;
  perform 1
  from public.v1_inventory_categories parent
  where parent.id = new.parent_category_id
    and parent.is_active
    and parent.parent_category_id is null
  for key share;
  if not found then
    raise exception 'V1_INVENTORY_CATEGORY_PARENT_INVALID'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_inventory_categories_active_parent
  on public.v1_inventory_categories;
create trigger v1_inventory_categories_active_parent
before insert or update of parent_category_id
on public.v1_inventory_categories
for each row execute function
  public.v1_enforce_active_inventory_category_parent();

-- Published urgent policy is a database guard, not merely a disabled picker.
create or replace function public.v1_enforce_published_request_timing()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.timing = 'urgent'
    and (tg_op = 'INSERT' or old.timing is distinct from 'urgent')
    and not public.v1_material_request_published_policy_boolean(
      'requests.urgent_enabled', true
    ) then
    raise exception 'V1_URGENT_REQUESTS_DISABLED'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_requests_published_timing
  on public.v1_material_requests;
create trigger v1_material_requests_published_timing
before insert or update of timing on public.v1_material_requests
for each row execute function public.v1_enforce_published_request_timing();

-- In-app notification rows remain durable. Disabling Push prevents only future
-- transport jobs; existing queued evidence is retained for reconciliation.
create or replace function public.v1_enqueue_notification_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.v1_material_request_published_policy_boolean(
    'notifications.push_enabled', true
  ) then
    return new;
  end if;
  insert into public.v1_notification_push_outbox (notification_id)
  values (new.id)
  on conflict (notification_id) do nothing;
  return new;
end;
$$;

-- Complete the exact-role unit projection introduced before the two global
-- engineering roles were added.
create or replace function public.v1_list_configuration_units()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null
    or public.v1_current_exact_role() not in (
      'project_engineer', 'site_engineer', 'procurement', 'admin',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_CONFIGURATION_ACTIVE_USER_REQUIRED'
      using errcode = '42501';
  end if;
  select coalesce(
    jsonb_agg(unit_record.short_code order by unit_record.name),
    '[]'::jsonb
  ) into v_result
  from public.v1_configuration_units unit_record
  where unit_record.is_active;
  return v_result;
end;
$$;

revoke all on function
  public.v1_stage_configuration_setting_before_control_plane(
    text, jsonb, integer, uuid
  ) from public, anon, authenticated;
revoke all on function
  public.v1_get_configuration_validation_before_control_plane()
  from public, anon, authenticated;
revoke all on function
  public.v1_restore_configuration_defaults_before_control_plane(integer, uuid)
  from public, anon, authenticated;
revoke all on function
  public.v1_get_configuration_centre_before_control_plane()
  from public, anon, authenticated;
revoke all on function public.v1_stage_configuration_setting(
  text, jsonb, integer, uuid
) from public, anon, authenticated;
revoke all on function public.v1_get_configuration_validation()
  from public, anon, authenticated;
revoke all on function public.v1_restore_configuration_defaults(integer, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_get_configuration_centre()
  from public, anon, authenticated;
revoke all on function public.v1_get_runtime_configuration()
  from public, anon, authenticated;
revoke all on function
  public.v1_get_configuration_publication_detail(uuid)
  from public, anon, authenticated;
revoke all on function
  public.v1_stage_configuration_master_action_before_control_plane(
    text, text, uuid, jsonb, text, integer, uuid
  ) from public, anon, authenticated;
revoke all on function public.v1_stage_configuration_master_action(
  text, text, uuid, jsonb, text, integer, uuid
) from public, anon, authenticated;
revoke all on function
  public.v1_publish_configuration_before_control_plane(text, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_publish_configuration(text, integer, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_enforce_active_configuration_unit()
  from public, anon, authenticated;
revoke all on function public.v1_enforce_active_inventory_category_parent()
  from public, anon, authenticated;
revoke all on function public.v1_enforce_published_request_timing()
  from public, anon, authenticated;
revoke all on function public.v1_enqueue_notification_push()
  from public, anon, authenticated;
revoke all on function public.v1_list_configuration_units()
  from public, anon, authenticated;

grant execute on function
  public.v1_stage_configuration_setting_before_control_plane(
    text, jsonb, integer, uuid
  ) to service_role;
grant execute on function
  public.v1_get_configuration_validation_before_control_plane()
  to service_role;
grant execute on function
  public.v1_restore_configuration_defaults_before_control_plane(integer, uuid)
  to service_role;
grant execute on function
  public.v1_get_configuration_centre_before_control_plane()
  to service_role;
grant execute on function public.v1_stage_configuration_setting(
  text, jsonb, integer, uuid
) to authenticated, service_role;
grant execute on function public.v1_get_configuration_validation()
  to authenticated, service_role;
grant execute on function public.v1_restore_configuration_defaults(integer, uuid)
  to authenticated, service_role;
grant execute on function public.v1_get_configuration_centre()
  to authenticated, service_role;
grant execute on function public.v1_get_runtime_configuration()
  to authenticated, service_role;
grant execute on function
  public.v1_get_configuration_publication_detail(uuid)
  to authenticated, service_role;
grant execute on function
  public.v1_stage_configuration_master_action_before_control_plane(
    text, text, uuid, jsonb, text, integer, uuid
  ) to service_role;
grant execute on function public.v1_stage_configuration_master_action(
  text, text, uuid, jsonb, text, integer, uuid
) to authenticated, service_role;
grant execute on function
  public.v1_publish_configuration_before_control_plane(text, integer, uuid)
  to service_role;
grant execute on function public.v1_publish_configuration(text, integer, uuid)
  to authenticated, service_role;
grant execute on function public.v1_enforce_active_configuration_unit()
  to service_role;
grant execute on function public.v1_enforce_active_inventory_category_parent()
  to service_role;
grant execute on function public.v1_enforce_published_request_timing()
  to service_role;
grant execute on function public.v1_enqueue_notification_push()
  to service_role;
grant execute on function public.v1_list_configuration_units()
  to authenticated, service_role;

commit;
