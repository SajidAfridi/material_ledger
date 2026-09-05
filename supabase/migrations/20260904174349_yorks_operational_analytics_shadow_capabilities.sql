-- Yorks Operational Analytics A02: additive, route-less capability catalogue.
--
-- The two keys begin planned/shadow/nonassignable. No existing route, RPC,
-- role or response changes in this migration. The next reviewed migration may
-- promote only analytics.view after its protected server consumer exists.
--
-- Data preservation: no operational or permission-history row is changed.
-- Rollback: leave the planned rows retained. They resolve false and cannot be
-- assigned, so dropping them is neither required nor permitted.

begin;

insert into public.v1_capability_catalog (
  capability_key, module_key, action_key, label, description, risk_level,
  allowed_scope_kinds, requires_project_access, dependencies, status,
  authorization_mode, is_assignable, display_order
)
values
  (
    'analytics.view', 'analytics', 'view', 'View Analytics',
    'Read the server-confirmed company Analytics workspace without widening any source-domain authority.',
    'high', array['organization']::text[], false, '{}'::text[],
    'planned', 'shadow', false, 440
  ),
  (
    'analytics.export', 'analytics', 'export', 'Export Analytics',
    'Export an approved server-defined Analytics register. No export consumer exists in the foundation release.',
    'high', array['organization']::text[], false,
    array['analytics.view']::text[], 'planned', 'shadow', false, 441
  )
on conflict (capability_key) do nothing;

insert into public.v1_permission_role_defaults (
  role_name, capability_key, is_granted, can_delegate
)
select
  role_name,
  capability.capability_key,
  false,
  false
from unnest(array[
  'project_engineer', 'site_engineer',
  'senior_mechanical_engineer', 'project_manager',
  'workshop_in_charge', 'document_controller',
  'procurement', 'accountant', 'admin'
]::text[]) role_name
cross join public.v1_capability_catalog capability
where capability.capability_key in ('analytics.view', 'analytics.export')
on conflict (role_name, capability_key) do nothing;

do $$
begin
  if (
    select count(*)
    from public.v1_capability_catalog capability
    where capability.capability_key in ('analytics.view', 'analytics.export')
      and capability.status = 'planned'
      and capability.authorization_mode = 'shadow'
      and not capability.is_assignable
  ) <> 2 then
    raise exception 'YORKS_ANALYTICS_SHADOW_CATALOG_MISMATCH';
  end if;

  if (
    select count(*)
    from public.v1_permission_role_defaults role_default
    where role_default.capability_key in (
      'analytics.view', 'analytics.export'
    )
  ) <> 18 then
    raise exception 'YORKS_ANALYTICS_SHADOW_ROLE_DEFAULTS_MISMATCH';
  end if;

  if exists (
    select 1
    from public.v1_permission_role_defaults role_default
    where role_default.capability_key in (
      'analytics.view', 'analytics.export'
    )
      and (role_default.is_granted or role_default.can_delegate)
  ) then
    raise exception 'YORKS_ANALYTICS_SHADOW_MUST_RESOLVE_FALSE';
  end if;
end;
$$;

commit;
