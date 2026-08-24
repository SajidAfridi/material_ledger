-- Yorks scoped capability cutover: protected User and Permission Management.
--
-- Every key enabled here has a trusted consumer: admin-users authorizes the
-- caller with their JWT before any service-role operation, exact-role changes
-- have an additional database-owned delegation preflight, and permission
-- workspaces/mutations are protected RPCs with revision, idempotency, ceiling,
-- self-escalation and last-manager guards. The retained local profile editor
-- remains shadow because it is not yet a normalized server command.
--
-- Data preservation: exact Admin and Senior Mechanical Engineer behavior is
-- reproduced by the role templates and exact-role preflight. No Auth/profile,
-- assignment or history row is rewritten.
--
-- Rollback: a corrective forward migration may return only these keys to
-- `shadow`. Keep assignments, revisions and immutable history intact.

begin;

-- Versioned proof used by the cutover assertion below. The capability catalog
-- must never become authoritative until the durable auth.users boundary has
-- been replaced in the same transaction.
create or replace function public.v1_auth_admin_audit_capability_version()
returns integer
language sql
immutable
set search_path = ''
as $$
  select 3;
$$;

create or replace function public.v1_auth_expected_server_caps(
  p_exact_role text
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case p_exact_role
    when 'admin' then jsonb_build_array(
      'viewCommercials', 'salary', 'finance', 'rentals', 'writeRentals',
      'people', 'writePeople', 'goods', 'approveLeave'
    )
    when 'procurement' then jsonb_build_array(
      'viewCommercials', 'rentals', 'writeRentals', 'people', 'writePeople',
      'goods', 'approveLeave'
    )
    else '[]'::jsonb
  end;
$$;

-- Existing raw compatibility claims can still authorize retained modules, so
-- User Administration must not become authoritative while they differ from
-- the exact-role server template. This report deliberately contains only
-- stable app-user IDs and safe counts. Secondary role arrays are reported for
-- reconciliation but never interpreted as grants and do not affect this gate.
create or replace function public.v1_auth_claim_compatibility_report()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with active_identity as (
    select
      auth_user.id as auth_user_id,
      profile.legacy_app_user_id as app_user_id,
      public.v1_permission_exact_role(auth_user.id) as exact_role,
      auth_user.raw_app_meta_data -> 'caps' as raw_caps,
      auth_user.raw_app_meta_data -> 'roles' as raw_roles
    from auth.users auth_user
    join public.v1_profiles profile
      on profile.auth_user_id = auth_user.id
    where nullif(btrim(profile.legacy_app_user_id), '') is not null
      and public.v1_permission_exact_role(auth_user.id) <> ''
  ), evaluated as (
    select
      identity.app_user_id,
      identity.exact_role,
      identity.raw_roles is distinct from
        jsonb_build_array(identity.exact_role) as stale_secondary_roles,
      (
        (
          identity.raw_caps is null
          and public.v1_auth_expected_server_caps(identity.exact_role)
            = '[]'::jsonb
        ) or (
          jsonb_typeof(identity.raw_caps) = 'array'
          and not exists (
            select 1
            from jsonb_array_elements(
              case when jsonb_typeof(identity.raw_caps) = 'array'
                then identity.raw_caps else '[]'::jsonb end
            ) item
            where jsonb_typeof(item) <> 'string'
          )
          and (
            select count(*)
            from jsonb_array_elements_text(
              case when jsonb_typeof(identity.raw_caps) = 'array'
                then identity.raw_caps else '[]'::jsonb end
            ) value
          ) = (
            select count(distinct value)
            from jsonb_array_elements_text(
              case when jsonb_typeof(identity.raw_caps) = 'array'
                then identity.raw_caps else '[]'::jsonb end
            ) value
          )
        )
      ) as caps_shape_valid,
      case when jsonb_typeof(identity.raw_caps) = 'array' then (
        select count(*)
        from jsonb_array_elements_text(identity.raw_caps) actual(value)
        where not exists (
          select 1
          from jsonb_array_elements_text(
            public.v1_auth_expected_server_caps(identity.exact_role)
          ) expected(value)
          where expected.value = actual.value
        )
      ) else 0 end as extra_count,
      (
        select count(*)
        from jsonb_array_elements_text(
          public.v1_auth_expected_server_caps(identity.exact_role)
        ) expected(value)
        where not exists (
          select 1
          from jsonb_array_elements_text(
            case when jsonb_typeof(identity.raw_caps) = 'array'
              then identity.raw_caps else '[]'::jsonb end
          ) actual(value)
          where actual.value = expected.value
        )
      ) as missing_count
    from active_identity identity
  ), mismatch as (
    select *
    from evaluated
    where not caps_shape_valid or extra_count <> 0 or missing_count <> 0
  )
  select jsonb_build_object(
    'schema_version', 1,
    'active_identity_count', (select count(*) from active_identity),
    'mismatch_count', (select count(*) from mismatch),
    'mismatches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'app_user_id', sample.app_user_id,
        'caps_shape_valid', sample.caps_shape_valid,
        'extra_count', sample.extra_count,
        'missing_count', sample.missing_count
      ) order by sample.app_user_id)
      from (
        select * from mismatch order by app_user_id limit 50
      ) sample
    ), '[]'::jsonb),
    'stale_secondary_roles_count', (
      select count(*) from evaluated where stale_secondary_roles
    ),
    'stale_secondary_role_app_user_ids', coalesce((
      select jsonb_agg(sample.app_user_id order by sample.app_user_id)
      from (
        select evaluated.app_user_id
        from evaluated
        where stale_secondary_roles
        order by evaluated.app_user_id
        limit 50
      ) sample
    ), '[]'::jsonb)
  );
$$;

create or replace function public.v1_assert_auth_claim_compatibility()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_report jsonb := public.v1_auth_claim_compatibility_report();
begin
  if coalesce((v_report ->> 'mismatch_count')::bigint, 0) <> 0 then
    raise exception 'V1_AUTH_COMPATIBILITY_CLAIMS_RECONCILIATION_REQUIRED'
      using errcode = '23514', detail = v_report::text;
  end if;
  return v_report;
end;
$$;

-- Target hierarchy is independent of auth.uid(): Auth Admin mutations run via
-- service_role, so the trigger resolves the verified Edge actor UUID against
-- live Auth, profile and immutable role-template data. Admin and Senior
-- Mechanical Engineer retain their established full hierarchy. A delegated
-- actor can manage only role templates wholly inside that actor's delegation
-- ceiling, and can never manage either protected top-level role.
create or replace function public.v1_auth_admin_actor_can_manage_role(
  p_actor_auth_user_id uuid,
  p_target_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_exact_role text := public.v1_permission_exact_role(
    p_actor_auth_user_id
  );
begin
  if v_actor_exact_role = ''
    or not coalesce(public.v1_is_valid_role(p_target_exact_role), false) then
    return false;
  end if;
  if v_actor_exact_role in ('admin', 'senior_mechanical_engineer') then
    return true;
  end if;
  if p_target_exact_role in ('admin', 'senior_mechanical_engineer') then
    return false;
  end if;
  return not exists (
    select 1
    from public.v1_permission_role_defaults target_default
    join public.v1_capability_catalog catalog
      on catalog.capability_key = target_default.capability_key
    where target_default.role_name = p_target_exact_role
      and target_default.is_granted
      and catalog.status = 'operational'
      and not exists (
        select 1
        from public.v1_permission_role_defaults actor_ceiling
        where actor_ceiling.role_name = v_actor_exact_role
          and actor_ceiling.capability_key = target_default.capability_key
          and actor_ceiling.can_delegate
      )
  );
end;
$$;

-- Target-aware preflight for password and activation actions. It mirrors the
-- trigger hierarchy before Edge invokes GoTrue, while the trigger remains the
-- final transaction authority.
create or replace function public.v1_current_user_can_administer_auth_target(
  p_target_app_user_id text,
  p_capability_key text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_exact_role text;
  v_target uuid;
  v_target_exact_role text;
begin
  if v_actor is null
    or p_capability_key not in (
      'users.password.reset', 'users.activation.manage'
    )
    or not public.v1_current_actor_is_active()
    or not public.v1_current_user_has_capability(
      p_capability_key, null
    ) then
    return false;
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null or v_target = v_actor then
    return false;
  end if;
  v_actor_exact_role := public.v1_permission_exact_role(v_actor);
  select coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    into v_target_exact_role
  from auth.users auth_user
  where auth_user.id = v_target;
  if not found then
    return false;
  end if;
  if not coalesce(public.v1_is_valid_role(v_target_exact_role), false) then
    return v_actor_exact_role = 'admin';
  end if;
  return public.v1_auth_admin_actor_can_manage_role(
    v_actor, v_target_exact_role
  );
end;
$$;

-- Strengthen the existing role preflight with both the current target
-- template and requested template. This prevents a bounded delegated actor
-- from demoting a protected role merely because the destination role is low.
create or replace function public.v1_current_user_can_assign_exact_role(
  p_target_app_user_id text,
  p_requested_exact_role text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_actor_exact_role text;
  v_target uuid;
  v_target_exact_role text;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  v_target := public.v1_permission_target_auth_id(p_target_app_user_id);
  if v_target is null or v_target = v_actor then
    return false;
  end if;
  if not public.v1_permission_actor_can_assign_role_template(
    p_requested_exact_role
  ) then
    return false;
  end if;
  v_actor_exact_role := public.v1_permission_exact_role(v_actor);
  select coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    into v_target_exact_role
  from auth.users auth_user
  where auth_user.id = v_target;
  if not found then
    return false;
  end if;
  if not coalesce(public.v1_is_valid_role(v_target_exact_role), false) then
    return v_actor_exact_role = 'admin';
  end if;
  return public.v1_auth_admin_actor_can_manage_role(
    v_actor, v_target_exact_role
  );
end;
$$;

-- One target-aware server projection drives every User Management action
-- control. The client never reconstructs hierarchy from visible role labels.
-- A null target is create mode; an existing target is evaluated independently
-- for role assignment, password reset and activation. Only stable exact-role
-- keys leave this boundary -- Auth UUIDs and role-template internals do not.
create or replace function public.v1_get_user_admin_options(
  p_target_app_user_id text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_target_app_user_id text := nullif(btrim(p_target_app_user_id), '');
  v_assignable_roles text[] := '{}'::text[];
  v_role text;
  v_can_assign_roles boolean := false;
  v_has_password_action boolean := false;
  v_has_activation_action boolean := false;
  v_can_reset_password boolean := false;
  v_can_manage_activation boolean := false;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_USER_ADMIN_OPTIONS_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  v_can_assign_roles := public.v1_current_user_has_capability(
    'users.roles.assign', null
  );
  v_has_password_action := public.v1_current_user_has_capability(
    'users.password.reset', null
  );
  v_has_activation_action := public.v1_current_user_has_capability(
    'users.activation.manage', null
  );
  if not public.v1_current_user_has_capability('users.view', null)
    or not (
      v_can_assign_roles or v_has_password_action or v_has_activation_action
    ) then
    raise exception 'V1_USER_ADMIN_OPTIONS_ACCESS_DENIED'
      using errcode = '42501';
  end if;

  if v_can_assign_roles then
    for v_role in
      select distinct role_default.role_name
      from public.v1_permission_role_defaults role_default
      order by role_default.role_name
    loop
      if (
        v_target_app_user_id is null
        and public.v1_current_user_can_assign_new_exact_role(v_role)
      ) or (
        v_target_app_user_id is not null
        and public.v1_current_user_can_assign_exact_role(
          v_target_app_user_id, v_role
        )
      ) then
        v_assignable_roles := array_append(v_assignable_roles, v_role);
      end if;
    end loop;
  end if;

  if v_target_app_user_id is not null then
    v_can_reset_password :=
      public.v1_current_user_can_administer_auth_target(
        v_target_app_user_id, 'users.password.reset'
      );
    v_can_manage_activation :=
      public.v1_current_user_can_administer_auth_target(
        v_target_app_user_id, 'users.activation.manage'
      );
  end if;

  return jsonb_build_object(
    'schema_version', 1,
    'target_app_user_id', v_target_app_user_id,
    'assignable_exact_roles', to_jsonb(v_assignable_roles),
    'can_assign_role', cardinality(v_assignable_roles) > 0,
    'can_reset_password', v_can_reset_password,
    'can_manage_activation', v_can_manage_activation
  );
end;
$$;

-- Durable Auth command boundary for action-scoped person permissions.
-- Context remains service-only and transient; every decision is rechecked
-- against current Auth/profile state using the actor UUID inside that context.
create or replace function public.v1_auth_users_admin_audit_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_app_metadata jsonb := coalesce(new.raw_app_meta_data, '{}'::jsonb);
  v_context jsonb;
  v_actor_text text;
  v_actor_auth_user_id uuid;
  v_actor_auth auth.users%rowtype;
  v_actor_exact_role text;
  v_actor_canonical_role text;
  v_action text;
  v_required_capability text;
  v_idempotency_text text;
  v_idempotency_key uuid;
  v_request_hash text;
  v_event_type text;
  v_before_data jsonb;
  v_after_data jsonb;
  v_reason text;
  v_existing_audit public.v1_audit_events%rowtype;
  v_is_retry boolean := false;
  v_is_recovery boolean := false;
  v_old_raw_role text;
  v_new_raw_role text;
  v_pending jsonb;
  v_reconciliation_issue_code text;
  v_reconciliation_issue public.v1_reconciliation_issues%rowtype;
  v_reconciliation_before jsonb;
begin
  -- Preserve the serialized last-active-Admin invariant even for a future
  -- trusted Auth writer that does not use the current Edge context.
  if tg_op = 'UPDATE'
    and coalesce(old.raw_app_meta_data ->> 'role', '') = 'admin'
    and public.v1_auth_user_is_active(old.banned_until)
    and (
      coalesce(new.raw_app_meta_data ->> 'role', '') <> 'admin'
      or not public.v1_auth_user_is_active(new.banned_until)
    )
  then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('v1_last_active_exact_admin', 0)
    );
    if not exists (
      select 1
      from auth.users other_user
      where other_user.id <> old.id
        and coalesce(other_user.raw_app_meta_data ->> 'role', '') = 'admin'
        and public.v1_auth_user_is_active(other_user.banned_until)
    ) then
      raise exception 'V1_LAST_ACTIVE_ADMIN_REQUIRED'
        using errcode = '55000';
    end if;
  end if;

  v_context := v_new_app_metadata -> '_v1_admin_audit_context';
  if v_context is null then
    if tg_op = 'UPDATE'
      and not public.v1_is_valid_role(
        coalesce(old.raw_app_meta_data ->> 'role', '')
      )
      and public.v1_is_valid_role(
        coalesce(new.raw_app_meta_data ->> 'role', '')
      )
    then
      raise exception
        'V1_NONCANONICAL_ROLE_MAPPING_REQUIRES_AUDITED_ADMIN_COMMAND'
        using errcode = '42501';
    end if;
    return new;
  end if;

  perform public.v1_assert_object_keys(
    v_context,
    array[
      'actor_auth_user_id', 'action', 'idempotency_key', 'request_hash'
    ],
    'admin_audit_context'
  );
  v_actor_text := nullif(
    btrim(coalesce(v_context ->> 'actor_auth_user_id', '')), ''
  );
  v_action := nullif(btrim(coalesce(v_context ->> 'action', '')), '');
  v_idempotency_text := nullif(
    btrim(coalesce(v_context ->> 'idempotency_key', '')), ''
  );
  v_request_hash := lower(nullif(
    btrim(coalesce(v_context ->> 'request_hash', '')), ''
  ));
  if v_actor_text is null
    or v_action is null
    or v_idempotency_text is null
    or v_request_hash is null then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_REQUIRED_FIELDS_MISSING'
      using errcode = '22023';
  end if;
  begin
    v_actor_auth_user_id := v_actor_text::uuid;
  exception when invalid_text_representation then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_INVALID'
      using errcode = '22023';
  end;
  begin
    v_idempotency_key := v_idempotency_text::uuid;
  exception when invalid_text_representation then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_IDEMPOTENCY_KEY_INVALID'
      using errcode = '22023';
  end;
  if v_request_hash !~ '^[a-f0-9]{64}$' then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_REQUEST_HASH_INVALID'
      using errcode = '22023';
  end if;
  if v_action not in (
    'created', 'provisioned', 'provisioning_recovered', 'role_changed',
    'password_reset', 'active_changed'
  ) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTION_INVALID'
      using errcode = '22023';
  end if;
  if (tg_op = 'INSERT' and v_action <> 'created')
    or (tg_op = 'UPDATE' and v_action = 'created') then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTION_INVALID_FOR_OPERATION'
      using errcode = '22023';
  end if;

  v_event_type := 'admin_user_' || case v_action
    when 'provisioned' then 'created'
    when 'provisioning_recovered' then 'created'
    else v_action
  end;
  v_required_capability := case v_action
    when 'created' then 'users.create'
    when 'provisioned' then 'users.create'
    when 'provisioning_recovered' then 'users.create'
    when 'role_changed' then 'users.roles.assign'
    when 'password_reset' then 'users.password.reset'
    else 'users.activation.manage'
  end;

  select * into v_actor_auth
  from auth.users actor_user
  where actor_user.id = v_actor_auth_user_id
  for key share;
  if not found or not public.v1_auth_user_is_active(
    v_actor_auth.banned_until
  ) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN'
      using errcode = '42501';
  end if;
  v_actor_exact_role := coalesce(
    v_actor_auth.raw_app_meta_data ->> 'role', ''
  );
  if not coalesce(public.v1_is_valid_role(v_actor_exact_role), false) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN'
      using errcode = '42501';
  end if;
  v_actor_canonical_role := public.v1_canonical_role_from_exact_role(
    v_actor_exact_role
  );
  perform public.v1_sync_profile_from_auth(v_actor_auth_user_id);
  if not exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = v_actor_auth_user_id
      and profile.is_active
      and profile.canonical_role_snapshot = v_actor_canonical_role
  ) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN'
      using errcode = '42501';
  end if;
  if not coalesce((
    public.v1_permission_authoritative_resolution(
      v_actor_auth_user_id, v_required_capability, null
    ) ->> 'effective'
  )::boolean, false) then
    raise exception 'V1_ADMIN_AUDIT_CONTEXT_ACTOR_CAPABILITY_REQUIRED'
      using errcode = '42501';
  end if;

  v_old_raw_role := case when tg_op = 'UPDATE'
    then coalesce(old.raw_app_meta_data ->> 'role', '') else '' end;
  v_new_raw_role := coalesce(v_new_app_metadata ->> 'role', '');

  -- A canonical one-step INSERT is retained only for trusted compatibility
  -- callers and must already carry the exact server-owned singleton/default
  -- claims. Current V1 provisioning uses the resumable path below.
  if v_action = 'created'
    and coalesce(public.v1_is_valid_role(v_new_raw_role), false) then
    if v_new_app_metadata -> 'roles'
        is distinct from jsonb_build_array(v_new_raw_role)
      or v_new_app_metadata -> 'caps'
        is distinct from public.v1_auth_expected_server_caps(v_new_raw_role)
      or v_new_app_metadata ? 'legacyShell'
      or v_new_app_metadata ? 'legacy_shell' then
      raise exception 'V1_AUTH_SERVER_OWNED_CLAIMS_REQUIRED'
        using errcode = '42501';
    end if;
  end if;

  -- Retained legacy provisioning/mapping is exact-Admin-only at the durable
  -- boundary. The Edge feature flag is separately off by default.
  if (v_action = 'created' or v_action = 'role_changed')
    and (
      not coalesce(public.v1_is_valid_role(v_new_raw_role), false)
      or (tg_op = 'UPDATE' and not coalesce(
        public.v1_is_valid_role(v_old_raw_role), false
      ))
    )
    and v_actor_exact_role <> 'admin' then
    raise exception 'V1_ADMIN_AUDIT_LEGACY_EXACT_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;

  if tg_op = 'UPDATE'
    and v_action in ('role_changed', 'password_reset', 'active_changed')
    and new.id = v_actor_auth_user_id then
    raise exception 'V1_ADMIN_AUDIT_SELF_MUTATION_DENIED'
      using errcode = '42501';
  end if;
  if tg_op = 'UPDATE'
    and nullif(btrim(coalesce(
      old.raw_app_meta_data ->> 'app_user_id', ''
    )), '') is not null
    and old.raw_app_meta_data ->> 'app_user_id'
      is distinct from v_new_app_metadata ->> 'app_user_id' then
    raise exception 'V1_AUTH_APP_USER_ID_IMMUTABLE'
      using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    v_before_data := null;
  else
    v_before_data := jsonb_build_object(
      'role', public.v1_safe_auth_audit_role(old.raw_app_meta_data),
      'active', public.v1_auth_user_is_active(old.banned_until)
    );
  end if;
  v_after_data := jsonb_build_object(
    'role', public.v1_safe_auth_audit_role(v_new_app_metadata),
    'active', public.v1_auth_user_is_active(new.banned_until)
  );
  if v_action = 'password_reset' then
    v_after_data := v_after_data || jsonb_build_object(
      'password_reset', true
    );
  end if;

  -- Claim/replay before validating a pending marker so two identical
  -- completion requests serialize to one audit and one final Auth state.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor_auth_user_id::text || '|' || v_event_type || '|'
        || v_idempotency_key::text,
      0
    )
  );
  select * into v_existing_audit
  from public.v1_audit_events audit
  where audit.actor_auth_user_id = v_actor_auth_user_id
    and audit.event_type = v_event_type
    and audit.idempotency_key = v_idempotency_key
  for update;
  if found then
    if v_existing_audit.entity_type <> 'auth_user'
      or v_existing_audit.entity_id <> new.id
      or v_existing_audit.request_hash is distinct from v_request_hash
      or v_existing_audit.after_data is distinct from v_after_data then
      raise exception 'V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST'
        using errcode = '22023';
    end if;
    if tg_op = 'UPDATE' then
      return old;
    end if;
    v_is_retry := true;
  end if;

  -- The two-stage V1 create resumes only from the exact HMAC-bound pending
  -- marker emitted with the first GoTrue insert. Both transient objects are
  -- removed before profile sync observes the canonical account.
  if not v_is_retry
    and v_action in ('provisioned', 'provisioning_recovered') then
    if tg_op <> 'UPDATE'
      or coalesce(public.v1_is_valid_role(v_old_raw_role), false)
      or not coalesce(public.v1_is_valid_role(v_new_raw_role), false) then
      raise exception 'V1_ADMIN_PROVISIONING_STATE_INVALID'
        using errcode = '55000';
    end if;
    v_pending := old.raw_app_meta_data -> '_v1_admin_provisioning_pending';
    perform public.v1_assert_object_keys(
      v_pending,
      array[
        'version', 'actor_auth_user_id', 'app_user_id', 'idempotency_key',
        'request_hash', 'email', 'role', 'intent_hash'
      ],
      'admin_provisioning_pending'
    );
    if v_new_app_metadata -> '_v1_admin_provisioning_pending'
        is distinct from v_pending
      or v_pending ->> 'version' <> '2'
      or v_pending ->> 'app_user_id'
        is distinct from v_new_app_metadata ->> 'app_user_id'
      or lower(coalesce(v_pending ->> 'email', ''))
        is distinct from lower(coalesce(new.email, ''))
      or v_pending ->> 'role' is distinct from v_new_raw_role
      or coalesce(v_pending ->> 'actor_auth_user_id', '')
        !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or coalesce(v_pending ->> 'idempotency_key', '')
        !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      or lower(coalesce(v_pending ->> 'request_hash', ''))
        !~ '^[a-f0-9]{64}$'
      or lower(coalesce(v_pending ->> 'intent_hash', ''))
        !~ '^[a-f0-9]{64}$' then
      raise exception 'V1_ADMIN_PROVISIONING_MARKER_INVALID'
        using errcode = '42501';
    end if;
    if v_action = 'provisioned' then
      if v_pending ->> 'actor_auth_user_id'
          <> v_actor_auth_user_id::text
        or v_pending ->> 'idempotency_key' <> v_idempotency_key::text
        or lower(v_pending ->> 'request_hash') <> v_request_hash then
        raise exception 'V1_ADMIN_PROVISIONING_MARKER_INVALID'
          using errcode = '42501';
      end if;
    else
      v_is_recovery := true;
      if v_actor_exact_role <> 'admin'
        or v_pending ->> 'actor_auth_user_id'
          = v_actor_auth_user_id::text then
        raise exception 'V1_ADMIN_PROVISIONING_RECOVERY_EXACT_ADMIN_REQUIRED'
          using errcode = '42501';
      end if;
    end if;
    if v_new_app_metadata -> 'roles'
        is distinct from jsonb_build_array(v_new_raw_role)
      or v_new_app_metadata -> 'caps'
        is distinct from public.v1_auth_expected_server_caps(v_new_raw_role)
      or v_new_app_metadata ? 'legacyShell'
      or v_new_app_metadata ? 'legacy_shell' then
      raise exception 'V1_AUTH_SERVER_OWNED_CLAIMS_REQUIRED'
        using errcode = '42501';
    end if;
  end if;

  if not v_is_retry and v_action = 'role_changed'
    and coalesce(public.v1_is_valid_role(v_new_raw_role), false) then
    if not coalesce(public.v1_is_valid_role(v_old_raw_role), false) then
      -- Explicit legacy reconciliation is exact-Admin-only above. Normalize
      -- retained compatibility claims instead of carrying them into V1.
      v_new_app_metadata := (
        v_new_app_metadata || jsonb_build_object(
          'roles', jsonb_build_array(v_new_raw_role),
          'caps', public.v1_auth_expected_server_caps(v_new_raw_role)
        )
      ) - 'legacyShell' - 'legacy_shell';
    elsif v_new_app_metadata -> 'roles'
        is distinct from jsonb_build_array(v_new_raw_role)
      or v_new_app_metadata -> 'caps'
        is distinct from public.v1_auth_expected_server_caps(v_new_raw_role)
      or v_new_app_metadata ? 'legacyShell'
      or v_new_app_metadata ? 'legacy_shell' then
        raise exception 'V1_AUTH_SERVER_OWNED_CLAIMS_REQUIRED'
          using errcode = '42501';
    end if;
  end if;

  if not v_is_retry
    and v_action in (
      'created', 'provisioned', 'provisioning_recovered', 'role_changed'
    )
    and coalesce(public.v1_is_valid_role(v_new_raw_role), false)
    and v_actor_exact_role not in ('admin', 'senior_mechanical_engineer')
    and not coalesce((
      public.v1_permission_authoritative_resolution(
        v_actor_auth_user_id, 'permissions.delegate', null
      ) ->> 'effective'
    )::boolean, false) then
    raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
      using errcode = '42501';
  end if;

  if not v_is_retry
    and v_action in ('provisioned', 'provisioning_recovered')
    and not public.v1_auth_admin_actor_can_manage_role(
      v_actor_auth_user_id, v_new_raw_role
    ) then
    raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
      using errcode = '42501';
  end if;
  if not v_is_retry and v_action = 'created'
    and coalesce(public.v1_is_valid_role(v_new_raw_role), false)
    and not public.v1_auth_admin_actor_can_manage_role(
      v_actor_auth_user_id, v_new_raw_role
    ) then
    raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
      using errcode = '42501';
  end if;
  if not v_is_retry and v_action = 'role_changed' then
    if coalesce(public.v1_is_valid_role(v_old_raw_role), false)
      and (
        not public.v1_auth_admin_actor_can_manage_role(
          v_actor_auth_user_id, v_old_raw_role
        )
        or not public.v1_auth_admin_actor_can_manage_role(
          v_actor_auth_user_id, v_new_raw_role
        )
      ) then
      raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
        using errcode = '42501';
    end if;
  end if;
  if not v_is_retry and v_action in ('password_reset', 'active_changed') then
    if coalesce(public.v1_is_valid_role(v_old_raw_role), false) then
      if not public.v1_auth_admin_actor_can_manage_role(
        v_actor_auth_user_id, v_old_raw_role
      ) then
        raise exception 'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED'
          using errcode = '42501';
      end if;
    elsif v_actor_exact_role <> 'admin' then
      raise exception 'V1_ADMIN_AUDIT_LEGACY_EXACT_ADMIN_REQUIRED'
        using errcode = '42501';
    end if;
  end if;

  v_reason := case v_action
    when 'created' then 'User Management legacy provisioning command'
    when 'provisioned' then 'User Management V1 provisioning command'
    when 'provisioning_recovered'
      then 'User Management V1 provisioning recovery command'
    when 'role_changed' then 'User Management exact-role change'
    when 'password_reset' then 'User Management password reset command'
    when 'active_changed' then 'User Management account activation change'
  end;

  if not v_is_retry then
    insert into public.v1_audit_events (
      event_type, entity_type, entity_id, project_id,
      actor_auth_user_id, actor_role, actor_exact_role, occurred_at,
      idempotency_key, before_data, after_data, reason, request_hash
    ) values (
      v_event_type, 'auth_user', new.id, null,
      v_actor_auth_user_id, v_actor_canonical_role, v_actor_exact_role,
      clock_timestamp(), v_idempotency_key, v_before_data, v_after_data,
      v_reason, v_request_hash
    );
  end if;

  if tg_op = 'UPDATE'
    and not v_is_retry
    and not coalesce(public.v1_is_valid_role(v_old_raw_role), false)
    and coalesce(public.v1_is_valid_role(v_new_raw_role), false) then
    if v_action not in (
      'role_changed', 'provisioned', 'provisioning_recovered'
    ) then
      raise exception
        'V1_NONCANONICAL_ROLE_MAPPING_REQUIRES_ROLE_AUDIT_ACTION'
        using errcode = '22023';
    end if;
    v_reconciliation_issue_code := case v_old_raw_role
      when 'engineer' then 'legacy_engineer_requires_explicit_mapping'
      else 'noncanonical_auth_role_requires_explicit_mapping'
    end;
    select * into v_reconciliation_issue
    from public.v1_reconciliation_issues issue
    where issue.source_system = 'auth'
      and issue.source_entity = 'users'
      and issue.source_id = new.id::text
      and issue.issue_code = v_reconciliation_issue_code
    for update;
    if not found then
      raise exception 'V1_NONCANONICAL_ROLE_RECONCILIATION_NOT_FOUND'
        using errcode = '55000';
    end if;
    if v_reconciliation_issue.resolution_status <> 'pending' then
      raise exception 'V1_NONCANONICAL_ROLE_RECONCILIATION_NOT_PENDING'
        using errcode = '55000';
    end if;
    v_reconciliation_before := jsonb_build_object(
      'resolution_status', v_reconciliation_issue.resolution_status
    );
    update public.v1_reconciliation_issues issue
       set resolution_status = 'resolved',
           resolution_reason =
             'Audited User Management command resolved noncanonical Auth role reconciliation',
           resolved_by_auth_user_id = v_actor_auth_user_id,
           resolved_at = clock_timestamp(),
           resulting_v1_entity_type = 'profile',
           resulting_v1_id = new.id
     where issue.id = v_reconciliation_issue.id
     returning * into v_reconciliation_issue;

    insert into public.v1_audit_events (
      event_type, entity_type, entity_id, project_id,
      actor_auth_user_id, actor_role, actor_exact_role, occurred_at,
      idempotency_key, before_data, after_data, reason, request_hash
    ) values (
      'reconciliation_issue_resolved', 'reconciliation_issue',
      v_reconciliation_issue.id, null, v_actor_auth_user_id,
      v_actor_canonical_role, v_actor_exact_role, clock_timestamp(),
      v_idempotency_key, v_reconciliation_before,
      jsonb_build_object(
        'resolution_status', v_reconciliation_issue.resolution_status,
        'resulting_v1_entity_type',
          v_reconciliation_issue.resulting_v1_entity_type,
        'resulting_v1_id', v_reconciliation_issue.resulting_v1_id,
        'resolved_by_auth_user_id',
          v_reconciliation_issue.resolved_by_auth_user_id,
        'resolved_at', v_reconciliation_issue.resolved_at
      ),
      v_reconciliation_issue.resolution_reason, v_request_hash
    );
  end if;

  new.raw_app_meta_data := v_new_app_metadata
    - '_v1_admin_audit_context'
    - '_v1_admin_provisioning_pending';
  return new;
end;
$$;

drop trigger if exists v1_auth_users_admin_audit on auth.users;
create trigger v1_auth_users_admin_audit
before insert or update of raw_app_meta_data, raw_user_meta_data, banned_until
on auth.users
for each row execute function public.v1_auth_users_admin_audit_trigger();

revoke all on function public.v1_auth_admin_audit_capability_version()
  from public, anon, authenticated;
revoke all on function public.v1_auth_expected_server_caps(text)
  from public, anon, authenticated;
revoke all on function public.v1_auth_claim_compatibility_report()
  from public, anon, authenticated;
revoke all on function public.v1_assert_auth_claim_compatibility()
  from public, anon, authenticated;
grant execute on function public.v1_auth_claim_compatibility_report()
  to service_role;
grant execute on function public.v1_assert_auth_claim_compatibility()
  to service_role;
revoke all on function public.v1_auth_admin_actor_can_manage_role(uuid, text)
  from public, anon, authenticated;
revoke all on function public.v1_current_user_can_administer_auth_target(
  text, text
) from public, anon;
grant execute on function public.v1_current_user_can_administer_auth_target(
  text, text
) to authenticated;
revoke all on function public.v1_get_user_admin_options(text)
  from public, anon;
grant execute on function public.v1_get_user_admin_options(text)
  to authenticated;

do $enable_user_administration_capabilities$
declare
  v_keys constant text[] := array[
    'users.view', 'users.create', 'users.roles.assign',
    'users.password.reset', 'users.activation.manage',
    'permissions.view', 'permissions.manage', 'permissions.delegate'
  ]::text[];
  v_updated integer;
begin
  if to_regprocedure(
      'public.v1_auth_admin_audit_capability_version()'
    ) is null
    or public.v1_auth_admin_audit_capability_version() < 3 then
    raise exception 'V1_USER_ADMIN_CUTOVER_TRUSTED_AUTH_BOUNDARY_MISSING';
  end if;
  if to_regprocedure(
      'public.v1_current_user_can_assign_exact_role(text,text)'
    ) is null
    or to_regprocedure(
      'public.v1_current_user_can_assign_new_exact_role(text)'
    ) is null
    or to_regprocedure(
      'public.v1_get_user_admin_options(text)'
    ) is null then
    raise exception 'V1_USER_ADMIN_CUTOVER_ROLE_PREFLIGHT_MISSING';
  end if;

  perform public.v1_assert_auth_claim_compatibility();
  perform public.v1_assert_permission_cutover_parity(v_keys);
  update public.v1_capability_catalog catalog
  set authorization_mode = 'enforced'
  where catalog.capability_key = any(v_keys)
    and catalog.status = 'operational';
  get diagnostics v_updated = row_count;
  if v_updated <> cardinality(v_keys) then
    raise exception
      'V1_USER_ADMIN_CUTOVER_CATALOG_MISMATCH: expected %, updated %',
      cardinality(v_keys), v_updated;
  end if;

  if not exists (
    select 1
    from public.v1_capability_catalog catalog
    where catalog.capability_key = 'users.create'
      and catalog.dependencies @> array[
        'users.view', 'users.roles.assign'
      ]::text[]
  ) then
    raise exception 'V1_USER_ADMIN_CUTOVER_CREATE_DEPENDENCIES_MISSING';
  end if;
  if not exists (
    select 1
    from public.v1_capability_catalog catalog
    where catalog.capability_key = 'permissions.view'
      and catalog.dependencies @> array['users.view']::text[]
  ) then
    raise exception 'V1_USER_ADMIN_CUTOVER_PERMISSION_VIEW_DEPENDENCY_MISSING';
  end if;
end;
$enable_user_administration_capabilities$;

-- Open clients must atomically re-fetch once authorization mode changes.
update public.v1_permission_revisions revision
set revision = revision.revision + 1,
    updated_by_auth_user_id = null,
    updated_at = clock_timestamp()
from public.v1_profiles profile
where profile.auth_user_id = revision.auth_user_id
  and profile.is_active;

commit;
