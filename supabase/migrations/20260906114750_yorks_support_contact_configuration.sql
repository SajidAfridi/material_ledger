-- Add the published Yorks support contact consumed by My Yorks.
--
-- Data preservation:
-- * existing configuration values, shared drafts and publication history stay
--   untouched;
-- * an existing support contact is never overwritten;
-- * the value is exposed only through the existing role-safe runtime RPC.
--
-- Rollback is forward-only: publish the previous number (or hide the Profile
-- affordance) and retain the setting and publication evidence.

begin;

insert into public.v1_configuration_settings (
  setting_key,
  area,
  value_type,
  default_value,
  published_value,
  display_order,
  control_mode,
  impact_scope,
  enforcement_target
)
values (
  'support.developer_whatsapp',
  'company_regional',
  'string',
  to_jsonb('+923159353145'::text),
  to_jsonb('+923159353145'::text),
  120,
  'operational',
  array['company_regional']::text[],
  'profile_support_contact'
)
on conflict (setting_key) do nothing;

-- Keep the established validation contract and add one narrowly validated
-- operational key. E.164 avoids locale-dependent or ambiguous WhatsApp URLs.
do $migration$
begin
  if to_regprocedure(
    'public.v1_validate_configuration_setting_value_before_support(text,jsonb)'
  ) is null then
    alter function public.v1_validate_configuration_setting_value(text, jsonb)
      rename to v1_validate_configuration_setting_value_before_support;
  end if;
end;
$migration$;

create or replace function public.v1_validate_configuration_setting_value(
  p_setting_key text,
  p_value jsonb
)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_contact text;
begin
  if p_setting_key <> 'support.developer_whatsapp' then
    perform public.v1_validate_configuration_setting_value_before_support(
      p_setting_key,
      p_value
    );
    return;
  end if;

  if p_value is null or jsonb_typeof(p_value) <> 'string' then
    raise exception 'V1_CONFIGURATION_STRING_REQUIRED'
      using errcode = '22023';
  end if;

  v_contact := p_value #>> '{}';
  if v_contact !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'V1_CONFIGURATION_SUPPORT_CONTACT_INVALID'
      using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.v1_validate_configuration_setting_value(
  text, jsonb
) from public, anon, authenticated;

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
      'accountant', 'senior_mechanical_engineer', 'project_manager',
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
    'schema_version', 'R38.6 / 1.2',
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
    ),
    'support_whatsapp', coalesce((
      select setting.published_value #>> '{}'
      from public.v1_configuration_settings setting
      where setting.setting_key = 'support.developer_whatsapp'
    ), '+923159353145')
  );
end;
$$;

revoke all on function public.v1_get_runtime_configuration()
  from public, anon;
grant execute on function public.v1_get_runtime_configuration()
  to authenticated, service_role;

commit;
