-- A current-session commercial-capability lookup synchronises the caller's
-- server-owned profile mirror before calculating the protected envelope.
--
-- The original upsert wrote `updated_at = clock_timestamp()` even when every
-- mirror field already matched Auth. Because v1_profiles is published to
-- Realtime, each read emitted a self-only profile event, the Flutter client
-- re-read the envelope, and the cycle continued. Besides unnecessary RPC
-- traffic, a deny-by-default recheck made the Unit Cost control flicker.
--
-- Keep the existing security-definer boundary and Auth-derived values, but
-- make an unchanged profile sync a genuine no-op. A role, active-state, name
-- or legacy-ID change still writes one new profile row version and therefore
-- remains an immediate authorized refresh signal.
create or replace function public.v1_sync_profile_from_auth(
  p_auth_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user auth.users%rowtype;
  v_role text;
  v_legacy_app_user_id text;
  v_display_name text;
  v_is_active boolean;
begin
  select * into v_user
  from auth.users
  where id = p_auth_user_id;

  if not found then
    raise exception 'V1_AUTH_USER_NOT_FOUND'
      using errcode = '22023';
  end if;

  v_role := case coalesce(v_user.raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end;

  if v_role = '' then
    update public.v1_profiles
       set is_active = false,
           updated_at = clock_timestamp()
     where auth_user_id = p_auth_user_id
       and is_active is distinct from false;

    insert into public.v1_reconciliation_issues (
      source_system,
      source_entity,
      source_id,
      issue_code,
      field_path,
      raw_payload,
      payload_hash
    )
    values (
      'auth',
      'users',
      p_auth_user_id::text,
      case coalesce(v_user.raw_app_meta_data ->> 'role', '')
        when 'engineer' then 'legacy_engineer_requires_explicit_mapping'
        else 'noncanonical_auth_role_requires_explicit_mapping'
      end,
      'raw_app_meta_data.role',
      jsonb_build_object(
        'role', v_user.raw_app_meta_data ->> 'role',
        'legacy_app_user_id', v_user.raw_app_meta_data ->> 'app_user_id'
      ),
      encode(
        extensions.digest(
          convert_to(coalesce(v_user.raw_app_meta_data::text, ''), 'utf8'),
          'sha256'
        ),
        'hex'
      )
    )
    on conflict (source_system, source_entity, source_id, issue_code)
      do nothing;

    return;
  end if;

  v_legacy_app_user_id := nullif(
    btrim(coalesce(v_user.raw_app_meta_data ->> 'app_user_id', '')),
    ''
  );
  v_display_name := public.v1_safe_profile_display_name(
    v_user.raw_user_meta_data ->> 'full_name',
    p_auth_user_id
  );
  v_is_active := v_user.banned_until is null
    or v_user.banned_until <= clock_timestamp();

  if v_legacy_app_user_id is not null and exists (
    select 1
    from public.v1_profiles profile
    where profile.legacy_app_user_id = v_legacy_app_user_id
      and profile.auth_user_id <> p_auth_user_id
  ) then
    insert into public.v1_reconciliation_issues (
      source_system,
      source_entity,
      source_id,
      issue_code,
      field_path,
      raw_payload,
      payload_hash
    )
    values (
      'auth',
      'users',
      p_auth_user_id::text,
      'duplicate_legacy_app_user_id',
      'raw_app_meta_data.app_user_id',
      jsonb_build_object('legacy_app_user_id', v_legacy_app_user_id),
      encode(
        extensions.digest(convert_to(v_legacy_app_user_id, 'utf8'), 'sha256'),
        'hex'
      )
    )
    on conflict (source_system, source_entity, source_id, issue_code)
      do nothing;
    v_legacy_app_user_id := null;
  end if;

  insert into public.v1_profiles (
    auth_user_id,
    legacy_app_user_id,
    display_name,
    canonical_role_snapshot,
    is_active
  )
  values (
    p_auth_user_id,
    v_legacy_app_user_id,
    v_display_name,
    v_role,
    v_is_active
  )
  on conflict (auth_user_id) do update
    set legacy_app_user_id = coalesce(
          public.v1_profiles.legacy_app_user_id,
          excluded.legacy_app_user_id
        ),
        display_name = excluded.display_name,
        canonical_role_snapshot = excluded.canonical_role_snapshot,
        is_active = excluded.is_active,
        updated_at = clock_timestamp()
    where (
      public.v1_profiles.legacy_app_user_id,
      public.v1_profiles.display_name,
      public.v1_profiles.canonical_role_snapshot,
      public.v1_profiles.is_active
    ) is distinct from (
      coalesce(
        public.v1_profiles.legacy_app_user_id,
        excluded.legacy_app_user_id
      ),
      excluded.display_name,
      excluded.canonical_role_snapshot,
      excluded.is_active
    );
end;
$$;
