begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select no_plan();

select ok(
  public.v1_auth_admin_audit_capability_version() >= 3
  and position(
    'v1_permission_authoritative_resolution' in pg_get_functiondef(
      'public.v1_auth_users_admin_audit_trigger()'::regprocedure
    )
  ) > 0,
  'The durable Auth trigger is capability-aware before enforcement'
);

-- Give the seeded Project Manager a bounded, person-specific administration
-- assignment. Dependencies are explicit so the authoritative resolver, not
-- test role spoofing, decides each action.
insert into public.v1_permission_assignments (
  auth_user_id, capability_key, effect, scope_kind, origin, reason,
  changed_by_auth_user_id
)
select
  '10000000-0000-4000-8000-000000000010'::uuid,
  capability_key,
  'grant',
  'organization',
  'permission_management',
  'Focused delegated User Management boundary test',
  '10000000-0000-4000-8000-000000000004'::uuid
from unnest(array[
  'users.view', 'users.create', 'users.roles.assign',
  'users.password.reset', 'users.activation.manage',
  'permissions.view', 'permissions.manage', 'permissions.delegate'
]::text[]) as capability_key;

insert into public.v1_permission_assignments (
  auth_user_id, capability_key, effect, scope_kind, origin, reason,
  changed_by_auth_user_id
)
select
  '10000000-0000-4000-8000-000000000001'::uuid,
  capability_key,
  'grant',
  'organization',
  'permission_management',
  'Focused action-only Lego permission test',
  '10000000-0000-4000-8000-000000000004'::uuid
from unnest(array[
  'users.view', 'users.password.reset'
]::text[]) as capability_key;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  '10000000-0000-4000-8000-000000000082'::uuid,
  'authenticated', 'authenticated', 'peer.audit@yorks.local.test',
  source.encrypted_password, clock_timestamp(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'role', 'project_engineer',
    'roles', jsonb_build_array('project_engineer'),
    'caps', '[]'::jsonb,
    'app_user_id', 'usr-auth-audit-peer',
    '_v1_admin_audit_context', jsonb_build_object(
      'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
      'action', 'created',
      'idempotency_key', '61000000-0000-4000-8000-000000000010',
      'request_hash', repeat('4', 64)
    )
  ),
  jsonb_build_object('full_name', 'Peer Project Engineer'),
  clock_timestamp(), clock_timestamp(), '', '', '', ''
from auth.users source
where source.id = '10000000-0000-4000-8000-000000000004'::uuid;

select throws_ok(
  $$insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change
    )
    select
      '00000000-0000-0000-0000-000000000000'::uuid,
      '10000000-0000-4000-8000-000000000083'::uuid,
      'authenticated', 'authenticated', 'malicious.audit@yorks.local.test',
      source.encrypted_password, clock_timestamp(),
      jsonb_build_object(
        'role', 'project_engineer',
        'roles', jsonb_build_array('project_engineer', 'admin'),
        'caps', '[]'::jsonb,
        'app_user_id', 'usr-auth-audit-malicious',
        '_v1_admin_audit_context', jsonb_build_object(
          'actor_auth_user_id',
            '10000000-0000-4000-8000-000000000004',
          'action', 'created',
          'idempotency_key',
            '61000000-0000-4000-8000-000000000012',
          'request_hash', repeat('6', 64)
        )
      ),
      jsonb_build_object('full_name', 'Rejected secondary role'),
      clock_timestamp(), clock_timestamp(), '', '', '', ''
    from auth.users source
    where source.id =
      '10000000-0000-4000-8000-000000000004'::uuid$$,
  '42501',
  'V1_AUTH_SERVER_OWNED_CLAIMS_REQUIRED',
  'Canonical one-step creation rejects caller-selected secondary roles'
);

update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context', jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000001',
           'action', 'password_reset',
           'idempotency_key', '61000000-0000-4000-8000-000000000011',
           'request_hash', repeat('5', 64)
         )
       )
 where id = '10000000-0000-4000-8000-000000000082'::uuid;

select ok(
  not coalesce((public.v1_permission_authoritative_resolution(
    '10000000-0000-4000-8000-000000000001'::uuid,
    'permissions.delegate', null
  ) ->> 'effective')::boolean, false)
  and exists (
    select 1 from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.actor_auth_user_id =
        '10000000-0000-4000-8000-000000000001'::uuid
      and audit.entity_id =
        '10000000-0000-4000-8000-000000000082'::uuid
  ),
  'Password reset works as an independent Lego permission within target hierarchy'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select ok(
  public.v1_current_user_can_administer_auth_target(
    'usr-auth-audit-peer', 'users.password.reset'
  ),
  'Edge receives the same positive action-only target preflight'
);
select ok(
  jsonb_array_length(
    public.v1_get_user_admin_options('usr-auth-audit-peer')
      -> 'assignable_exact_roles'
  ) = 0
  and not (public.v1_get_user_admin_options('usr-auth-audit-peer')
    ->> 'can_assign_role')::boolean
  and (public.v1_get_user_admin_options('usr-auth-audit-peer')
    ->> 'can_reset_password')::boolean
  and not (public.v1_get_user_admin_options('usr-auth-audit-peer')
    ->> 'can_manage_activation')::boolean,
  'Target options preserve an independent password-reset Lego grant without exposing role choices'
);
set local role postgres;

select ok(
  coalesce((public.v1_permission_authoritative_resolution(
    '10000000-0000-4000-8000-000000000010'::uuid,
    'users.password.reset', null
  ) ->> 'effective')::boolean, false),
  'A delegated active person receives the assigned action capability'
);

-- A bounded delegated actor may reset a lower-template account. The audit
-- stores both canonical workflow role and exact job identity.
update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context', jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000010',
           'action', 'password_reset',
           'idempotency_key', '61000000-0000-4000-8000-000000000001',
           'request_hash', repeat('a', 64)
         )
       )
 where id = '10000000-0000-4000-8000-000000000002'::uuid;

select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.entity_id =
        '10000000-0000-4000-8000-000000000002'::uuid
      and audit.actor_auth_user_id =
        '10000000-0000-4000-8000-000000000010'::uuid
      and audit.actor_role = 'project_engineer'
      and audit.actor_exact_role = 'project_manager'
      and audit.after_data ->> 'password_reset' = 'true'
  ),
  'Delegated password reset is durable and exactly attributed'
);

-- Admin and Senior Mechanical Engineer keep their established full target
-- hierarchy, independent of the delegated-actor ceiling.
update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context', jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000009',
           'action', 'password_reset',
           'idempotency_key', '61000000-0000-4000-8000-000000000002',
           'request_hash', repeat('b', 64)
         )
       )
 where id = '10000000-0000-4000-8000-000000000004'::uuid;

select ok(
  exists (
    select 1 from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.actor_exact_role = 'senior_mechanical_engineer'
      and audit.entity_id =
        '10000000-0000-4000-8000-000000000004'::uuid
      and audit.idempotency_key =
        '61000000-0000-4000-8000-000000000002'::uuid
  ),
  'Senior Mechanical Engineer preserves full existing User Management authority'
);

select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data ||
             jsonb_build_object('must_change_password', true),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context', jsonb_build_object(
               'actor_auth_user_id',
                 '10000000-0000-4000-8000-000000000010',
               'action', 'password_reset',
               'idempotency_key',
                 '61000000-0000-4000-8000-000000000003',
               'request_hash', repeat('c', 64)
             )
           )
     where id = '10000000-0000-4000-8000-000000000009'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED',
  'A delegated actor cannot mutate a Senior Mechanical Engineer'
);

select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data ||
             jsonb_build_object('must_change_password', true),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context', jsonb_build_object(
               'actor_auth_user_id',
                 '10000000-0000-4000-8000-000000000003',
               'action', 'password_reset',
               'idempotency_key',
                 '61000000-0000-4000-8000-000000000004',
               'request_hash', repeat('d', 64)
             )
           )
     where id = '10000000-0000-4000-8000-000000000002'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_CONTEXT_ACTOR_CAPABILITY_REQUIRED',
  'A forged context from an actor without the action capability fails closed'
);

select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data ||
             jsonb_build_object('must_change_password', true),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context', jsonb_build_object(
               'actor_auth_user_id',
                 '10000000-0000-4000-8000-000000000010',
               'action', 'password_reset',
               'idempotency_key',
                 '61000000-0000-4000-8000-000000000005',
               'request_hash', repeat('e', 64)
             )
           )
     where id = '10000000-0000-4000-8000-000000000010'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_SELF_MUTATION_DENIED',
  'Password administration cannot target the actor itself'
);

select throws_ok(
  $$update auth.users
       set raw_app_meta_data = raw_app_meta_data
             || jsonb_build_object(
               'role', 'admin',
               'roles', jsonb_build_array('admin'),
               'caps', public.v1_auth_expected_server_caps('admin'),
               '_v1_admin_audit_context', jsonb_build_object(
                 'actor_auth_user_id',
                   '10000000-0000-4000-8000-000000000010',
                 'action', 'role_changed',
                 'idempotency_key',
                   '61000000-0000-4000-8000-000000000006',
                 'request_hash', repeat('f', 64)
               )
             )
     where id = '10000000-0000-4000-8000-000000000002'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_TARGET_HIERARCHY_DENIED',
  'A delegated actor cannot assign a role above its delegation ceiling'
);

-- A pending V1 identity has no authority. The second audited update is safely
-- resumable and claims exactly one admin_user_created event.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  '10000000-0000-4000-8000-000000000081'::uuid,
  'authenticated', 'authenticated', 'pending.audit@yorks.local.test',
  source.encrypted_password, clock_timestamp(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'app_user_id', 'usr-auth-audit-pending',
    '_v1_admin_provisioning_pending', jsonb_build_object(
      'version', 2,
      'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
      'app_user_id', 'usr-auth-audit-pending',
      'email', 'pending.audit@yorks.local.test',
      'role', 'site_engineer',
      'idempotency_key', '61000000-0000-4000-8000-000000000007',
      'request_hash', repeat('1', 64),
      'intent_hash', repeat('a', 64)
    )
  ),
  jsonb_build_object(
    'full_name', 'Pending provisioning fixture',
    'must_change_password', true
  ),
  clock_timestamp(), clock_timestamp(), '', '', '', ''
from auth.users source
where source.id = '10000000-0000-4000-8000-000000000004'::uuid;

select ok(
  not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id =
      '10000000-0000-4000-8000-000000000081'::uuid
  )
  and exists (
    select 1 from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000081'::uuid
      and auth_user.raw_app_meta_data ? '_v1_admin_provisioning_pending'
  ),
  'A partial create is preserved as a quarantined resumable identity'
);

update auth.users
   set raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
     'role', 'site_engineer',
     'roles', jsonb_build_array('site_engineer'),
     'caps', '[]'::jsonb,
     '_v1_admin_audit_context', jsonb_build_object(
       'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
       'action', 'provisioned',
       'idempotency_key', '61000000-0000-4000-8000-000000000007',
       'request_hash', repeat('1', 64)
     )
   )
 where id = '10000000-0000-4000-8000-000000000081'::uuid;

select ok(
  (select count(*) = 1
   from public.v1_audit_events audit
   where audit.event_type = 'admin_user_created'
     and audit.entity_id =
       '10000000-0000-4000-8000-000000000081'::uuid
     and audit.idempotency_key =
       '61000000-0000-4000-8000-000000000007'::uuid)
  and exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id =
      '10000000-0000-4000-8000-000000000081'::uuid
      and profile.canonical_role_snapshot = 'site_engineer'
  )
  and exists (
    select 1 from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000081'::uuid
      and auth_user.raw_app_meta_data -> 'roles'
        = jsonb_build_array('site_engineer')
      and auth_user.raw_app_meta_data -> 'caps' = '[]'::jsonb
      and not (auth_user.raw_app_meta_data
        ? '_v1_admin_provisioning_pending')
      and not (auth_user.raw_app_meta_data ? '_v1_admin_audit_context')
  ),
  'Provisioning commits one created audit and strips every transient marker'
);

-- Create a second exact Admin, then strand a separate v2 pending identity by
-- deactivating its original Admin actor between the insert and canonical role
-- stamp. A different live exact Admin may adopt only that signed identity and
-- rotates its temporary password as part of the audited completion.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  '10000000-0000-4000-8000-000000000080'::uuid,
  'authenticated', 'authenticated', 'recovery.admin@yorks.local.test',
  source.encrypted_password, clock_timestamp(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'role', 'admin',
    'roles', jsonb_build_array('admin'),
    'caps', public.v1_auth_expected_server_caps('admin'),
    'app_user_id', 'usr-auth-audit-recovery-admin',
    '_v1_admin_audit_context', jsonb_build_object(
      'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
      'action', 'created',
      'idempotency_key', '61000000-0000-4000-8000-000000000012',
      'request_hash', repeat('4', 64)
    )
  ),
  jsonb_build_object('full_name', 'Recovery Admin'),
  clock_timestamp(), clock_timestamp(), '', '', '', ''
from auth.users source
where source.id = '10000000-0000-4000-8000-000000000004'::uuid;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  '10000000-0000-4000-8000-000000000084'::uuid,
  'authenticated', 'authenticated', 'recover.pending@yorks.local.test',
  source.encrypted_password, clock_timestamp(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email'),
    'app_user_id', 'usr-auth-audit-recover-pending',
    '_v1_admin_provisioning_pending', jsonb_build_object(
      'version', 2,
      'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
      'app_user_id', 'usr-auth-audit-recover-pending',
      'email', 'recover.pending@yorks.local.test',
      'role', 'site_engineer',
      'idempotency_key', '61000000-0000-4000-8000-000000000013',
      'request_hash', repeat('5', 64),
      'intent_hash', repeat('6', 64)
    )
  ),
  jsonb_build_object(
    'full_name', 'Stranded pending fixture',
    'must_change_password', true
  ),
  clock_timestamp(), clock_timestamp(), '', '', '', ''
from auth.users source
where source.id = '10000000-0000-4000-8000-000000000004'::uuid;

select throws_ok(
  $$update auth.users
    set raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
      'role', 'site_engineer',
      'roles', jsonb_build_array('site_engineer'),
      'caps', public.v1_auth_expected_server_caps('site_engineer'),
      '_v1_admin_audit_context', jsonb_build_object(
        'actor_auth_user_id', '10000000-0000-4000-8000-000000000009',
        'action', 'provisioning_recovered',
        'idempotency_key', '61000000-0000-4000-8000-000000000017',
        'request_hash', repeat('a', 64)
      )
    )
    where id = '10000000-0000-4000-8000-000000000084'::uuid$$,
  '42501', 'V1_ADMIN_PROVISIONING_RECOVERY_EXACT_ADMIN_REQUIRED',
  'Senior Mechanical Engineer authority does not weaken exact-Admin pending recovery'
);

update auth.users
set banned_until = clock_timestamp() + interval '1 day',
    raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
      '_v1_admin_audit_context', jsonb_build_object(
        'actor_auth_user_id', '10000000-0000-4000-8000-000000000080',
        'action', 'active_changed',
        'idempotency_key', '61000000-0000-4000-8000-000000000014',
        'request_hash', repeat('7', 64)
      )
    )
where id = '10000000-0000-4000-8000-000000000004'::uuid;

update auth.users
set encrypted_password = crypt('Recovered-Temporary-2026!', gen_salt('bf')),
    raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
      'must_change_password', true
    ),
    raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
      'role', 'site_engineer',
      'roles', jsonb_build_array('site_engineer'),
      'caps', public.v1_auth_expected_server_caps('site_engineer'),
      '_v1_admin_audit_context', jsonb_build_object(
        'actor_auth_user_id', '10000000-0000-4000-8000-000000000080',
        'action', 'provisioning_recovered',
        'idempotency_key', '61000000-0000-4000-8000-000000000015',
        'request_hash', repeat('8', 64)
      )
    )
where id = '10000000-0000-4000-8000-000000000084'::uuid;

select ok(
  (select count(*) = 1
   from auth.users auth_user
   where auth_user.raw_app_meta_data ->> 'app_user_id'
     = 'usr-auth-audit-recover-pending')
  and (select count(*) = 1
   from public.v1_audit_events audit
   where audit.event_type = 'admin_user_created'
     and audit.entity_id =
       '10000000-0000-4000-8000-000000000084'::uuid
     and audit.actor_auth_user_id =
       '10000000-0000-4000-8000-000000000080'::uuid)
  and exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id =
      '10000000-0000-4000-8000-000000000084'::uuid
      and profile.canonical_role_snapshot = 'site_engineer'
  )
  and exists (
    select 1 from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000084'::uuid
      and auth_user.encrypted_password = crypt(
        'Recovered-Temporary-2026!', auth_user.encrypted_password
      )
      and not (auth_user.raw_app_meta_data
        ? '_v1_admin_provisioning_pending')
  ),
  'A second exact Admin recovers one stranded identity with one created audit and a rotated password'
);

update auth.users
set banned_until = null,
    raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
      '_v1_admin_audit_context', jsonb_build_object(
        'actor_auth_user_id', '10000000-0000-4000-8000-000000000080',
        'action', 'active_changed',
        'idempotency_key', '61000000-0000-4000-8000-000000000016',
        'request_hash', repeat('9', 64)
      )
    )
where id = '10000000-0000-4000-8000-000000000004'::uuid;

-- A canonical V1 role update cannot carry caller-selected secondary roles or
-- compatibility capabilities.
select throws_ok(
  $$update auth.users
       set raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         'role', 'project_engineer',
         'roles', jsonb_build_array('project_engineer', 'admin'),
         'caps', '[]'::jsonb,
         '_v1_admin_audit_context', jsonb_build_object(
           'actor_auth_user_id',
             '10000000-0000-4000-8000-000000000004',
           'action', 'role_changed',
           'idempotency_key',
             '61000000-0000-4000-8000-000000000008',
           'request_hash', repeat('2', 64)
         )
       )
     where id = '10000000-0000-4000-8000-000000000081'::uuid$$,
  '42501',
  'V1_AUTH_SERVER_OWNED_CLAIMS_REQUIRED',
  'Secondary exact roles cannot enter canonical Auth metadata'
);

-- Inactive actors fail from current Auth state even if their prior person
-- assignment and a cached caller token would otherwise allow the action.
update auth.users
   set banned_until = clock_timestamp() + interval '1 hour'
 where id = '10000000-0000-4000-8000-000000000010'::uuid;
select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data ||
             jsonb_build_object('must_change_password', true),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context', jsonb_build_object(
               'actor_auth_user_id',
                 '10000000-0000-4000-8000-000000000010',
               'action', 'password_reset',
               'idempotency_key',
                 '61000000-0000-4000-8000-000000000009',
               'request_hash', repeat('3', 64)
             )
           )
     where id = '10000000-0000-4000-8000-000000000002'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN',
  'An inactive delegated actor cannot use a stale permission assignment'
);

select * from finish();
rollback;
