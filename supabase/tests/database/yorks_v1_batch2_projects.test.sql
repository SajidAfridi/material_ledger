begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(104);

set local role postgres;
select is(
  (
    select count(*)
    from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind = 'r'
      and relation.relrowsecurity
      and relation.relname = any (array[
        'v1_reconciliation_issues',
        'v1_profiles',
        'v1_role_capability_defaults',
        'v1_user_capabilities',
        'v1_projects',
        'v1_project_parties',
        'v1_project_scopes',
        'v1_project_attachment_intakes',
        'v1_boq_group_templates',
        'v1_boq_groups',
        'v1_project_members',
        'v1_audit_events',
        'v1_idempotency_keys'
      ])
  ),
  13::bigint,
  'Every Batch 2 V1 public relation has RLS enabled'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_projects', 'insert')
    and not has_table_privilege('authenticated', 'public.v1_boq_groups', 'update')
    and not has_table_privilege('authenticated', 'public.v1_audit_events', 'insert')
    and not has_table_privilege(
      'authenticated', 'public.v1_user_capabilities', 'insert'
    ),
  'Authenticated clients have no direct V1 project, BOQ, audit or capability writer grants'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_sync_profile_from_auth(uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_safe_profile_display_name(text,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_current_actor_is_active()',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_idempotency_get_or_claim(text,uuid,jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_write_audit_event(text,text,uuid,uuid,jsonb,jsonb,text,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_commercial_capability_envelope(uuid)',
    'execute'
  ),
  'Security-definer implementation helpers are not client-callable'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_create_project(jsonb,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_list_active_profile_directory()',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_revoke_project_member(jsonb,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_rls_current_actor_is_active()',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_rls_can_use_legacy_commercial_fallback()',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_get_current_commercial_capabilities()',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_get_user_commercial_capabilities(uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_set_user_commercial_capability(jsonb,uuid)',
    'execute'
  ),
  'Only intended project/capability commands, safe directory and narrow RLS predicates are client-callable'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (select count(*) from public.v1_list_active_profile_directory()),
  2::bigint,
  'The team-picker RPC exposes only active Project/Site Engineer selection rows'
);

set local role postgres;
update public.v1_profiles
   set display_name = 'legacy.directory-email@example.test'
 where auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (
    select display_name
    from public.v1_list_active_profile_directory()
    where auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid
  ),
  '10000000-0000-4000-8000-000000000002',
  'The safe directory replaces an email-like legacy profile label with its opaque fallback'
);

set local role postgres;
update auth.users
   set raw_user_meta_data = '{}'::jsonb
 where id = '10000000-0000-4000-8000-000000000002'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (
    select display_name
    from public.v1_list_active_profile_directory()
    where auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid
  ),
  '10000000-0000-4000-8000-000000000002',
  'Profile synchronisation never falls back to an Auth email for a directory label'
);

set local role postgres;
update auth.users
   set raw_user_meta_data = jsonb_build_object(
     'full_name', 'Local Site Engineer',
     'must_change_password', false
   )
 where id = '10000000-0000-4000-8000-000000000002'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

set local role postgres;
-- Keep a second active exact Admin while this fixture bans/demotes the seeded
-- Admin.  The Auth trigger must reject a last-Admin loss even for trusted test
-- writes, so this is intentionally not bypassed.
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"admin"'::jsonb
   )
 where id = '10000000-0000-4000-8000-000000000003'::uuid;
insert into public.v1_user_capabilities (
  auth_user_id,
  capability,
  is_granted,
  reason,
  changed_by_auth_user_id
)
values (
  '10000000-0000-4000-8000-000000000004'::uuid,
  'view_commercials',
  true,
  'RLS active-actor regression fixture',
  '10000000-0000-4000-8000-000000000004'::uuid
)
on conflict (auth_user_id, capability) do update
  set is_granted = excluded.is_granted,
      reason = excluded.reason,
      changed_by_auth_user_id = excluded.changed_by_auth_user_id,
      updated_at = clock_timestamp();
update auth.users
   set banned_until = clock_timestamp() + interval '1 hour'
 where id = '10000000-0000-4000-8000-000000000004'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select is(
  (select count(*) from public.v1_profiles),
  1::bigint,
  'A banned Admin receives only its own noncommercial profile refresh signal'
);

select is(
  (select count(*) from public.v1_user_capabilities),
  1::bigint,
  'A banned Admin receives only its own capability refresh signal'
);

select is(
  (select count(*) from public.v1_boq_group_templates),
  0::bigint,
  'A banned Admin with a cached JWT cannot read V1 BOQ templates'
);

set local role postgres;
update auth.users
   set banned_until = null,
       raw_app_meta_data = jsonb_set(
         raw_app_meta_data,
         '{role}',
         '"procurement"'::jsonb
       )
 where id = '10000000-0000-4000-8000-000000000004'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-STALE-ADMIN-DENIED",
      "name":"Stale Admin denied",
      "parties":{},
      "initial_members":[],
      "buildings":[{"name":"Stale Admin Building"}],
      "attachments":[]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000018'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A stale Admin JWT is rejected after authoritative role demotion and actor synchronisation'
);

select ok(
  (select count(*) from public.v1_profiles) = 1
    and (select count(*) from public.v1_user_capabilities) = 1
    and (select count(*) from public.v1_boq_group_templates) = 0,
  'A stale Admin JWT retains only self refresh signals, never broader V1 reads'
);

set local role postgres;
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"admin"'::jsonb
   )
 where id = '10000000-0000-4000-8000-000000000004'::uuid;
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"procurement"'::jsonb
   )
 where id = '10000000-0000-4000-8000-000000000003'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select * from public.v1_list_active_profile_directory()$$,
  '42501',
  'V1_PROJECT_DIRECTORY_ACCESS_DENIED',
  'Procurement cannot read project team-directory selection data through the RPC'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-PE-001",
      "name":"Project Engineer Creation",
      "job_contract_reference":"JC-PE-001",
      "project_site":"Dubai",
      "start_date":"2026-08-01",
      "target_completion_date":"2026-12-01",
      "notes":"Five-stage server test",
      "parties":{
        "client":{"name":"Client One","contact_name":"Client Contact"},
        "consultant":{"name":"Consultant One"},
        "main_contractor":{"name":"Main Contractor One"},
        "subcontractors":[{"name":"Subcontractor One"}],
        "other_contractors":[{"name":"Other Contractor One"}]
      },
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Initial site assignment"
      }],
      "buildings":[{
        "code":"tower_a",
        "name":"Tower A",
        "floors_levels":["L1","L2"],
        "flags":{"has_basement":true},
        "delivery_address":"Tower A loading bay"
      }],
      "attachments":[{
        "file_name":"scope.pdf",
        "mime_type":"application/pdf",
        "size_bytes":1024
      }]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'AT-01: Project Engineer can create a fully populated project'
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-PE-001",
      "name":"Project Engineer Creation",
      "job_contract_reference":"JC-PE-001",
      "project_site":"Dubai",
      "start_date":"2026-08-01",
      "target_completion_date":"2026-12-01",
      "notes":"Five-stage server test",
      "parties":{
        "client":{"name":"Client One","contact_name":"Client Contact"},
        "consultant":{"name":"Consultant One"},
        "main_contractor":{"name":"Main Contractor One"},
        "subcontractors":[{"name":"Subcontractor One"}],
        "other_contractors":[{"name":"Other Contractor One"}]
      },
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Initial site assignment"
      }],
      "buildings":[{
        "code":"tower_a",
        "name":"Tower A",
        "floors_levels":["L1","L2"],
        "flags":{"has_basement":true},
        "delivery_address":"Tower A loading bay"
      }],
      "attachments":[{
        "file_name":"scope.pdf",
        "mime_type":"application/pdf",
        "size_bytes":1024
      }]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Same idempotency key/payload returns the prior project response'
);

set local role postgres;
create temporary table v1_b2_pe_response as
select response_json
from public.v1_idempotency_keys
where actor_auth_user_id = '10000000-0000-4000-8000-000000000001'::uuid
  and command_name = 'v1_create_project'
  and idempotency_key = '20000000-0000-4000-8000-000000000001'::uuid;
grant select on table v1_b2_pe_response to authenticated;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-PE-001'),
  1::bigint,
  'An idempotent create produces exactly one project'
);

select is(
  (
    select count(*)
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B2-PE-001'
      and not group_record.is_custom
  ),
  29::bigint,
  'AT-02: project creation atomically seeds all 29 default BOQ groups'
);

select is(
  (
    select array_agg(group_record.display_order order by group_record.display_order)
    from public.v1_boq_groups group_record
    join public.v1_projects project on project.id = group_record.project_id
    where project.project_ref = 'B2-PE-001'
  ),
  array[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29
  ]::integer[],
  'The frozen default BOQ order is preserved'
);

select is(
  (
    select count(*)
    from public.v1_project_scopes scope
    join public.v1_projects project on project.id = scope.project_id
    where project.project_ref = 'B2-PE-001'
      and scope.scope_kind = 'common'
      and scope.scope_code = 'common'
      and scope.name = 'Common / All Buildings'
      and scope.is_immutable
  ),
  1::bigint,
  'Every project has exactly one immutable Common / All Buildings scope'
);

select ok(
  (
    select (public.v1_create_project(
      '{
        "project_ref":"B2-PE-001",
        "name":"Project Engineer Creation",
        "job_contract_reference":"JC-PE-001",
        "project_site":"Dubai",
        "start_date":"2026-08-01",
        "target_completion_date":"2026-12-01",
        "notes":"Five-stage server test",
        "parties":{
          "client":{"name":"Client One","contact_name":"Client Contact"},
          "consultant":{"name":"Consultant One"},
          "main_contractor":{"name":"Main Contractor One"},
          "subcontractors":[{"name":"Subcontractor One"}],
          "other_contractors":[{"name":"Other Contractor One"}]
        },
        "initial_members":[{
          "auth_user_id":"10000000-0000-4000-8000-000000000002",
          "project_role":"site_engineer",
          "reason":"Initial site assignment"
        }],
        "buildings":[{
          "code":"tower_a",
          "name":"Tower A",
          "floors_levels":["L1","L2"],
          "flags":{"has_basement":true},
          "delivery_address":"Tower A loading bay"
        }],
        "attachments":[{
          "file_name":"scope.pdf",
          "mime_type":"application/pdf",
          "size_bytes":1024
        }]
      }'::jsonb,
      '20000000-0000-4000-8000-000000000001'::uuid
    ) -> 'scopes' -> 1 ->> 'project_id')::uuid
    = (
      select id from public.v1_projects where project_ref = 'B2-PE-001'
    )
    and (public.v1_create_project(
      '{
        "project_ref":"B2-PE-001",
        "name":"Project Engineer Creation",
        "job_contract_reference":"JC-PE-001",
        "project_site":"Dubai",
        "start_date":"2026-08-01",
        "target_completion_date":"2026-12-01",
        "notes":"Five-stage server test",
        "parties":{
          "client":{"name":"Client One","contact_name":"Client Contact"},
          "consultant":{"name":"Consultant One"},
          "main_contractor":{"name":"Main Contractor One"},
          "subcontractors":[{"name":"Subcontractor One"}],
          "other_contractors":[{"name":"Other Contractor One"}]
        },
        "initial_members":[{
          "auth_user_id":"10000000-0000-4000-8000-000000000002",
          "project_role":"site_engineer",
          "reason":"Initial site assignment"
        }],
        "buildings":[{
          "code":"tower_a",
          "name":"Tower A",
          "floors_levels":["L1","L2"],
          "flags":{"has_basement":true},
          "delivery_address":"Tower A loading bay"
        }],
        "attachments":[{
          "file_name":"scope.pdf",
          "mime_type":"application/pdf",
          "size_bytes":1024
        }]
      }'::jsonb,
      '20000000-0000-4000-8000-000000000001'::uuid
    ) -> 'scopes' -> 1 -> 'floors_levels') = '["L1", "L2"]'::jsonb
    and (public.v1_create_project(
      '{
        "project_ref":"B2-PE-001",
        "name":"Project Engineer Creation",
        "job_contract_reference":"JC-PE-001",
        "project_site":"Dubai",
        "start_date":"2026-08-01",
        "target_completion_date":"2026-12-01",
        "notes":"Five-stage server test",
        "parties":{
          "client":{"name":"Client One","contact_name":"Client Contact"},
          "consultant":{"name":"Consultant One"},
          "main_contractor":{"name":"Main Contractor One"},
          "subcontractors":[{"name":"Subcontractor One"}],
          "other_contractors":[{"name":"Other Contractor One"}]
        },
        "initial_members":[{
          "auth_user_id":"10000000-0000-4000-8000-000000000002",
          "project_role":"site_engineer",
          "reason":"Initial site assignment"
        }],
        "buildings":[{
          "code":"tower_a",
          "name":"Tower A",
          "floors_levels":["L1","L2"],
          "flags":{"has_basement":true},
          "delivery_address":"Tower A loading bay"
        }],
        "attachments":[{
          "file_name":"scope.pdf",
          "mime_type":"application/pdf",
          "size_bytes":1024
        }]
      }'::jsonb,
      '20000000-0000-4000-8000-000000000001'::uuid
    ) -> 'scopes' -> 1 ->> 'delivery_address') = 'Tower A loading bay'
    and (public.v1_create_project(
      '{
        "project_ref":"B2-PE-001",
        "name":"Project Engineer Creation",
        "job_contract_reference":"JC-PE-001",
        "project_site":"Dubai",
        "start_date":"2026-08-01",
        "target_completion_date":"2026-12-01",
        "notes":"Five-stage server test",
        "parties":{
          "client":{"name":"Client One","contact_name":"Client Contact"},
          "consultant":{"name":"Consultant One"},
          "main_contractor":{"name":"Main Contractor One"},
          "subcontractors":[{"name":"Subcontractor One"}],
          "other_contractors":[{"name":"Other Contractor One"}]
        },
        "initial_members":[{
          "auth_user_id":"10000000-0000-4000-8000-000000000002",
          "project_role":"site_engineer",
          "reason":"Initial site assignment"
        }],
        "buildings":[{
          "code":"tower_a",
          "name":"Tower A",
          "floors_levels":["L1","L2"],
          "flags":{"has_basement":true},
          "delivery_address":"Tower A loading bay"
        }],
        "attachments":[{
          "file_name":"scope.pdf",
          "mime_type":"application/pdf",
          "size_bytes":1024
        }]
      }'::jsonb,
      '20000000-0000-4000-8000-000000000001'::uuid
    ) -> 'scopes' -> 1 -> 'flags') = '{"has_basement": true}'::jsonb
  ),
  'Create response retains exact project_id, floors_levels, delivery_address and flags'
);

select ok(
  (
    select response_json -> 'members' -> 0 ? 'project_id'
      and response_json -> 'members' -> 0 ? 'assigned_by_auth_user_id'
      and response_json -> 'members' -> 0 ? 'assigned_by_role'
      and response_json -> 'members' -> 0 ? 'created_at'
    from v1_b2_pe_response
  ),
  'Create member projection contains project_id and assignment traceability'
);

select throws_ok(
  $$select public.v1_create_project(
    '{"project_ref":"B2-PE-CHANGED","name":"Changed","buildings":[{"name":"Tower Changed"}]}'::jsonb,
    '20000000-0000-4000-8000-000000000001'::uuid
  )$$,
  '22023',
  'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
  'Idempotency key reuse with a different payload is rejected'
);

set local role postgres;
select is(
  (
    select count(*)
    from public.v1_audit_events audit
    join public.v1_projects project on project.id = audit.project_id
    where project.project_ref = 'B2-PE-001'
      and audit.event_type = 'project_created'
  ),
  1::bigint,
  'Same-key retries produce one server-generated creation audit event'
);
set local role authenticated;

select ok(
  position(
    'pg_advisory_xact_lock' in pg_get_functiondef(
      'public.v1_idempotency_get_or_claim(text,uuid,jsonb)'::regprocedure
    )
  ) > 0,
  'The idempotency claim serializes same-key concurrent requests with a transaction lock'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

set local role postgres;
update auth.users
   set banned_until = clock_timestamp() + interval '1 hour'
 where id = '10000000-0000-4000-8000-000000000001'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$select * from public.v1_list_active_profile_directory()$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A banned actor with an already-issued JWT cannot read the team directory'
);

select throws_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-BANNED-CREATE",
      "name":"Banned actor creation",
      "parties":{},
      "initial_members":[],
      "buildings":[{"name":"Banned actor building"}],
      "attachments":[]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000014'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A banned actor with an already-issued JWT cannot create a project'
);

select throws_ok(
  $$select public.v1_assign_project_member(
    jsonb_build_object(
      'project_id', (select (response_json ->> 'project_id')::uuid from v1_b2_pe_response),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'site_engineer',
      'expected_version', 1,
      'reason', 'Banned actor assignment'
    ),
    '20000000-0000-4000-8000-000000000015'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A banned actor with an already-issued JWT cannot change project membership'
);

select throws_ok(
  $$select public.v1_revoke_project_member(
    jsonb_build_object(
      'project_id', (select (response_json ->> 'project_id')::uuid from v1_b2_pe_response),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'site_engineer',
      'expected_version', 1,
      'reason', 'Banned actor revocation'
    ),
    '20000000-0000-4000-8000-000000000016'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A banned actor with an already-issued JWT cannot revoke project membership'
);

select throws_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select (response_json ->> 'project_id')::uuid from v1_b2_pe_response),
      'state', 'on_hold',
      'expected_version', 1,
      'reason', 'Banned actor state change'
    ),
    '20000000-0000-4000-8000-000000000017'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ACTOR_REQUIRED',
  'A banned actor with an already-issued JWT cannot change project state'
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-PE-001'),
  0::bigint,
  'An inactive actor cannot read a project through the project RLS predicate'
);

set local role postgres;
update auth.users
   set banned_until = null
 where id = '10000000-0000-4000-8000-000000000001'::uuid;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_assign_project_member(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B2-PE-001'),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'project_engineer',
      'expected_version', 1,
      'reason', 'Project-specific Project Engineer authority for test'
    ),
    '20000000-0000-4000-8000-000000000012'::uuid
  )$$,
  'Setup: Project Engineer can give a base Site Engineer a dated Project Engineer membership'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_revoke_project_member(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B2-PE-001'),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'project_engineer',
      'expected_version', 2,
      'reason', 'Project-specific Project Engineer authority verified'
    ),
    '20000000-0000-4000-8000-000000000013'::uuid
  )$$,
  'A base Site Engineer with active Project Engineer membership can revoke/manage through the trusted RPC'
);

select throws_ok(
  $$select public.v1_revoke_project_member(
    jsonb_build_object(
      'project_id', (select (response_json ->> 'project_id')::uuid from v1_b2_pe_response),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'project_engineer',
      'expected_version', 2,
      'reason', 'Project-specific Project Engineer authority verified'
    ),
    '20000000-0000-4000-8000-000000000013'::uuid
  )$$,
  '42501',
  'V1_PROJECT_TEAM_MANAGEMENT_DENIED',
  'A revoked member cannot replay a completed idempotency key to read its cached response'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-SITE-001",
      "name":"Site Engineer Creation",
      "parties":{"consultant":{"name":"Consultant Two"}},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000001",
        "project_role":"project_engineer",
        "reason":"Assigned during Site creation"
      }],
      "buildings":[
        {"code":"block_a","name":"Block A","floors_levels":["01"]},
        {"code":"block_b","name":"Block B","flags":{"roof":true}}
      ],
      "attachments":[]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'AT-01: Site Engineer can create a project, assign one initial Project Engineer and multiple buildings'
);

set local role postgres;
create temporary table v1_b2_site_project as
select id as project_id
from public.v1_projects
where project_ref = 'B2-SITE-001';
grant select on table v1_b2_site_project to authenticated;
set local role authenticated;

select is(
  (
    select count(*)
    from public.v1_project_members member
    join public.v1_projects project on project.id = member.project_id
    where project.project_ref = 'B2-SITE-001'
      and member.effective_to is null
  ),
  2::bigint,
  'Site creation records both creator Site and assigned Project Engineer membership history'
);

select is(
  (
    select count(*)
    from public.v1_project_scopes scope
    join public.v1_projects project on project.id = scope.project_id
    where project.project_ref = 'B2-SITE-001'
  ),
  3::bigint,
  'Site-created project has Common plus both physical building scopes'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-ADMIN-001",
      "name":"Admin Creation",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"admin_block","name":"Admin Block"}],
      "attachments":[]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Admin can create a project through the trusted command'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-NO-PE-001",
      "name":"No Project Engineer Yet",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"no_pe","name":"No PE Building"}],
      "attachments":[]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Site Engineer may save a draft while a Project Engineer assignment is pending'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B2-NO-PE-001'),
      'state', 'active',
      'expected_version', 1
    ),
    '20000000-0000-4000-8000-000000000005'::uuid
  )$$,
  '55000',
  'V1_ACTIVE_PROJECT_REQUIRES_PROJECT_ENGINEER',
  'AT-01: activation is denied when no active Project Engineer exists'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B2-NO-PE-001'),
      'state', 'active',
      'expected_version', 1
    ),
    '20000000-0000-4000-8000-000000000006'::uuid
  )$$,
  '42501',
  'V1_PROJECT_STATE_CHANGE_DENIED',
  'Site Engineer cannot activate without Project Engineer membership authority'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select throws_ok(
  $$select public.v1_create_project(
    '{"project_ref":"B2-PROC-DENIED","name":"Denied","buildings":[{"name":"Denied Building"}]}'::jsonb,
    '20000000-0000-4000-8000-000000000007'::uuid
  )$$,
  '42501',
  'V1_ROLE_NOT_ALLOWED_TO_CREATE_PROJECT',
  'AT-01 / AT-25: Procurement cannot create a V1 project through RPC'
);

select throws_ok(
  $$insert into public.v1_projects (
      project_ref, name, created_by_auth_user_id, created_by_role
    ) values (
      'B2-PROC-TABLE-DENIED', 'Denied',
      '10000000-0000-4000-8000-000000000003'::uuid, 'procurement'
    )$$,
  '42501',
  null,
  'AT-25: Procurement cannot insert directly into V1 projects'
);

select throws_ok(
  $$insert into public.v1_boq_groups (
      project_id, name, display_order, is_custom, created_by_auth_user_id
    ) values (
      '00000000-0000-4000-8000-000000000099'::uuid,
      'Denied', 1, true,
      '10000000-0000-4000-8000-000000000003'::uuid
    )$$,
  '42501',
  null,
  'AT-25: Procurement cannot insert directly into V1 BOQ groups'
);

select throws_ok(
  $$update public.v1_projects set name = 'Procurement overwrite'
    where project_ref = 'B2-PE-001'$$,
  '42501',
  null,
  'AT-25: Procurement cannot update V1 project data directly'
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-PE-001'),
  0::bigint,
  'Procurement cannot read a draft project outside its running-project projection'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_revoke_project_member(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B2-SITE-001'),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000002',
      'project_role', 'site_engineer',
      'expected_version', 1,
      'reason', 'Site access removed for test'
    ),
    '20000000-0000-4000-8000-000000000008'::uuid
  )$$,
  'AT-21: Project Engineer can revoke assigned Site Engineer access'
);

set local role postgres;
select ok(
  (
    select member.effective_to is not null
      and member.assigned_by_auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid
      and member.assigned_by_role = 'site_engineer'
      and member.created_at is not null
      and member.revoked_reason = 'Site access removed for test'
    from public.v1_project_members member
    join public.v1_projects project on project.id = member.project_id
    where project.project_ref = 'B2-SITE-001'
      and member.member_auth_user_id = '10000000-0000-4000-8000-000000000002'::uuid
      and member.project_role = 'site_engineer'
  ),
  'AT-21: revoked membership retains actor, role, creation time and revocation history'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-SITE-001'),
  0::bigint,
  'AT-21: revoked membership blocks future project reads'
);

select throws_ok(
  $$select public.v1_assign_project_member(
    jsonb_build_object(
      'project_id', (select project_id from v1_b2_site_project),
      'member_auth_user_id', '10000000-0000-4000-8000-000000000001',
      'project_role', 'project_engineer',
      'expected_version', 2,
      'reason', 'Denied after revocation'
    ),
    '20000000-0000-4000-8000-000000000009'::uuid
  )$$,
  '42501',
  'V1_PROJECT_TEAM_MANAGEMENT_DENIED',
  'Revoked Site Engineer cannot perform a future team mutation'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000099","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-unrelated-project-engineer"}}',
  true
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-PE-001'),
  0::bigint,
  'AT-25: unrelated Project Engineer cannot read another project'
);

select throws_ok(
  $$insert into public.v1_boq_groups (
      project_id, name, display_order, is_custom, created_by_auth_user_id
    ) values (
      '00000000-0000-4000-8000-000000000099'::uuid,
      'Unrelated denied', 1, true,
      '10000000-0000-4000-8000-000000000001'::uuid
    )$$,
  '42501',
  null,
  'AT-25: unrelated Project Engineer cannot bypass BOQ command authority'
);

set local role postgres;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000098","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-legacy-engineer"}}',
  true
);

select is(
  public.v1_current_role(),
  '',
  'Legacy engineer JWT claim is not a canonical V1 role'
);

set local role authenticated;
select throws_ok(
  $$select public.v1_create_project(
    '{"project_ref":"B2-LEGACY-DENIED","name":"Legacy denied","buildings":[{"name":"Denied"}]}'::jsonb,
    '20000000-0000-4000-8000-000000000010'::uuid
  )$$,
  '42501',
  'V1_ROLE_NOT_ALLOWED_TO_CREATE_PROJECT',
  'Legacy engineer cannot create a privileged V1 project'
);

set local role postgres;
select ok(
  not exists (
    select 1
    from public.v1_profiles
    where auth_user_id = '10000000-0000-4000-8000-000000000098'::uuid
  ),
  'No automatic legacy engineer profile or Project Engineer membership is created'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B2-ATTACHMENT-DENIED",
      "name":"Attachment denied",
      "parties":{},
      "initial_members":[],
      "buildings":[{"name":"Attachment Building"}],
      "attachments":[{
        "file_name":"unsafe.pdf",
        "storage_object_path":"projects/unsafe.pdf"
      }]
    }'::jsonb,
    '20000000-0000-4000-8000-000000000011'::uuid
  )$$,
  '22023',
  'V1_ATTACHMENT_STORAGE_LINKS_ARE_DEFERRED_TO_BATCH_9',
  'Client-supplied Storage paths cannot become a Batch 2 document link'
);

select is(
  (select count(*) from public.v1_projects where project_ref = 'B2-ATTACHMENT-DENIED'),
  0::bigint,
  'A rejected attachment path leaves no partial project record'
);

select throws_ok(
  $$insert into public.v1_audit_events (
      event_type, entity_type, entity_id, actor_auth_user_id, actor_role
    ) values (
      'forged', 'project', '00000000-0000-4000-8000-000000000099'::uuid,
      '10000000-0000-4000-8000-000000000001'::uuid, 'project_engineer'
    )$$,
  '42501',
  null,
  'Clients cannot forge a server audit event through a direct insert'
);

-- Reconciliation fixtures use real Auth writes so the tests exercise the
-- trigger-driven quarantine contract rather than a synthetic profile row.
set local role postgres;
create function public.v1_b2_insert_auth_fixture(
  p_auth_user_id uuid,
  p_email text,
  p_role text,
  p_app_user_id text,
  p_audit_context jsonb default null
)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change
  )
  select
    '00000000-0000-0000-0000-000000000000'::uuid,
    p_auth_user_id,
    'authenticated',
    'authenticated',
    p_email,
    source.encrypted_password,
    clock_timestamp(),
    jsonb_build_object(
      'provider', 'email',
      'providers', jsonb_build_array('email'),
      'app_user_id', p_app_user_id
    )
      || case
        when p_role is null then '{}'::jsonb
        else jsonb_build_object('role', p_role)
      end
      || coalesce(p_audit_context, '{}'::jsonb),
    jsonb_build_object('full_name', 'Batch 2 fixture'),
    clock_timestamp(),
    clock_timestamp(),
    '',
    '',
    '',
    ''
  from auth.users source
  where source.id = '10000000-0000-4000-8000-000000000001'::uuid;
end;
$$;

select public.v1_b2_insert_auth_fixture(
  '10000000-0000-4000-8000-000000000091'::uuid,
  'audit.fixture@yorks.local.test',
  'site_engineer',
  'usr-b2-audit-fixture',
  jsonb_build_object(
    '_v1_admin_audit_context',
    jsonb_build_object(
      'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
      'action', 'created',
      'idempotency_key', '50000000-0000-4000-8000-000000000001',
      'request_hash',
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    )
  )
);
select public.v1_b2_insert_auth_fixture(
  '10000000-0000-4000-8000-000000000092'::uuid,
  'legacy.fixture@yorks.local.test',
  'engineer',
  'usr-b2-legacy-fixture'
);
select public.v1_b2_insert_auth_fixture(
  '10000000-0000-4000-8000-000000000093'::uuid,
  'missing-role.fixture@yorks.local.test',
  null,
  'usr-b2-missing-role-fixture'
);
select public.v1_b2_insert_auth_fixture(
  '10000000-0000-4000-8000-000000000094'::uuid,
  'unknown-role.fixture@yorks.local.test',
  'former_engineer',
  'usr-b2-unknown-role-fixture'
);

select ok(
  exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.source_id = '10000000-0000-4000-8000-000000000092'
      and issue.issue_code = 'legacy_engineer_requires_explicit_mapping'
      and issue.resolution_status = 'pending'
  )
  and exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.source_id = '10000000-0000-4000-8000-000000000093'
      and issue.issue_code = 'noncanonical_auth_role_requires_explicit_mapping'
      and issue.raw_payload ? 'email' = false
  )
  and exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.source_id = '10000000-0000-4000-8000-000000000094'
      and issue.issue_code = 'noncanonical_auth_role_requires_explicit_mapping'
      and issue.raw_payload ? 'email' = false
  )
  and not exists (
    select 1 from public.v1_profiles
    where auth_user_id in (
      '10000000-0000-4000-8000-000000000093'::uuid,
      '10000000-0000-4000-8000-000000000094'::uuid
    )
  ),
  'Every missing/unknown Auth role is quarantined without a V1 profile or raw email'
);

select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_created'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
      and audit.actor_auth_user_id = '10000000-0000-4000-8000-000000000004'::uuid
      and audit.after_data = '{"role":"site_engineer","active":true}'::jsonb
      and audit.idempotency_key =
        '50000000-0000-4000-8000-000000000001'::uuid
      and audit.request_hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  )
  and not exists (
    select 1
    from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000091'::uuid
      and auth_user.raw_app_meta_data ? '_v1_admin_audit_context'
  )
  and exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = '10000000-0000-4000-8000-000000000091'::uuid
      and profile.canonical_role_snapshot = 'site_engineer'
  ),
  'Auth create audit is atomic, safe and strips its transient context before profile sync'
);

insert into public.v1_reconciliation_issues (
  id,
  source_system,
  source_entity,
  source_id,
  issue_code,
  field_path,
  raw_payload,
  payload_hash,
  proposed_mapping
)
values
  (
    '30000000-0000-4000-8000-000000000001'::uuid,
    'legacy_test',
    'identity',
    'resolve-fixture',
    'ambiguous_identity',
    'legacy.user',
    '{"private_email":"must-not-escape@example.test"}'::jsonb,
    'fixture-hash-resolve',
    '{"candidate":"profile"}'::jsonb
  ),
  (
    '30000000-0000-4000-8000-000000000002'::uuid,
    'legacy_test',
    'identity',
    'reject-fixture',
    'invalid_legacy_identity',
    'legacy.user',
    '{"private_email":"must-not-escape-reject@example.test"}'::jsonb,
    'fixture-hash-reject',
    '{"candidate":"none"}'::jsonb
  );

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_resolve_reconciliation_issue(
    '{
      "issue_id":"30000000-0000-4000-8000-000000000001",
      "resolution_status":"resolved",
      "resolution_reason":"Validated explicit profile mapping",
      "resulting_v1_entity_type":"profile",
      "resulting_v1_id":"10000000-0000-4000-8000-000000000002"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'An active exact Admin can resolve a protected reconciliation issue'
);

set local role postgres;
select ok(
  exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.id = '30000000-0000-4000-8000-000000000001'::uuid
      and issue.resolution_status = 'resolved'
      and issue.resolution_reason = 'Validated explicit profile mapping'
      and issue.resolved_by_auth_user_id =
        '10000000-0000-4000-8000-000000000004'::uuid
      and issue.resolved_at is not null
      and issue.resulting_v1_entity_type = 'profile'
      and issue.resulting_v1_id =
        '10000000-0000-4000-8000-000000000002'::uuid
      and issue.source_system = 'legacy_test'
      and issue.raw_payload =
        '{"private_email":"must-not-escape@example.test"}'::jsonb
  ),
  'Resolution preserves source/raw evidence and records actor, reason, server time and V1 result'
);

select is(
  (
    select count(*)
    from public.v1_audit_events audit
    where audit.event_type = 'reconciliation_issue_resolved'
      and audit.entity_id = '30000000-0000-4000-8000-000000000001'::uuid
  ),
  1::bigint,
  'A reconciliation resolution appends exactly one trusted audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  public.v1_resolve_reconciliation_issue(
    '{
      "issue_id":"30000000-0000-4000-8000-000000000001",
      "resolution_status":"resolved",
      "resolution_reason":"Validated explicit profile mapping",
      "resulting_v1_entity_type":"profile",
      "resulting_v1_id":"10000000-0000-4000-8000-000000000002"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000001'::uuid
  ) ->> 'resolution_status',
  'resolved',
  'Same-key reconciliation retries return the original safe response'
);

select throws_ok(
  $$select public.v1_resolve_reconciliation_issue(
    '{
      "issue_id":"30000000-0000-4000-8000-000000000001",
      "resolution_status":"resolved",
      "resolution_reason":"Second resolution must fail",
      "resulting_v1_entity_type":"profile",
      "resulting_v1_id":"10000000-0000-4000-8000-000000000002"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000002'::uuid
  )$$,
  '55000',
  'V1_RECONCILIATION_ISSUE_NOT_PENDING',
  'A reconciliation issue cannot be resolved twice under a new idempotency key'
);

select lives_ok(
  $$select public.v1_resolve_reconciliation_issue(
    '{
      "issue_id":"30000000-0000-4000-8000-000000000002",
      "resolution_status":"rejected",
      "resolution_reason":"Source identity cannot be reconciled"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'An active exact Admin can reject a protected reconciliation issue'
);

set local role postgres;
select ok(
  exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.id = '30000000-0000-4000-8000-000000000002'::uuid
      and issue.resolution_status = 'rejected'
      and issue.resulting_v1_entity_type is null
      and issue.resulting_v1_id is null
  )
  and exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'reconciliation_issue_rejected'
      and audit.entity_id = '30000000-0000-4000-8000-000000000002'::uuid
  ),
  'Rejected reconciliation issues retain no resulting V1 ID and are audited'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select ok(
  (public.v1_get_reconciliation_report() ->> 'total')::integer >= 4
  and public.v1_get_reconciliation_report()::text
    not like '%must-not-escape@example.test%'
  and public.v1_get_reconciliation_report()::text
    not like '%must-not-escape-reject@example.test%',
  'Admin reconciliation report provides counts/queue metadata without raw legacy payloads'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_get_reconciliation_report()$$,
  '42501',
  'V1_ACTIVE_ADMIN_REQUIRED',
  'Procurement cannot read the protected reconciliation report'
);
select throws_ok(
  $$select public.v1_resolve_reconciliation_issue(
    '{
      "issue_id":"30000000-0000-4000-8000-000000000001",
      "resolution_status":"resolved",
      "resolution_reason":"Unauthorized",
      "resulting_v1_entity_type":"profile",
      "resulting_v1_id":"10000000-0000-4000-8000-000000000002"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000004'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ADMIN_REQUIRED',
  'Procurement cannot resolve a protected reconciliation issue'
);

set local role postgres;
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"site_engineer"'::jsonb
   ) || jsonb_build_object(
     '_v1_admin_audit_context',
     jsonb_build_object(
       'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
       'action', 'role_changed',
       'idempotency_key', '50000000-0000-4000-8000-000000000002',
       'request_hash',
         'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
     )
   )
 where id = '10000000-0000-4000-8000-000000000092'::uuid;
select ok(
  exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.source_id = '10000000-0000-4000-8000-000000000092'
      and issue.issue_code = 'legacy_engineer_requires_explicit_mapping'
      and issue.resolution_status = 'resolved'
      and issue.resulting_v1_entity_type = 'profile'
      and issue.resulting_v1_id = '10000000-0000-4000-8000-000000000092'::uuid
  )
  and exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = '10000000-0000-4000-8000-000000000092'::uuid
      and profile.canonical_role_snapshot = 'site_engineer'
  )
  and (
    select count(*)
    from public.v1_audit_events audit
    where audit.actor_auth_user_id = '10000000-0000-4000-8000-000000000004'::uuid
      and audit.entity_id in (
        '10000000-0000-4000-8000-000000000092'::uuid,
        (
          select id
          from public.v1_reconciliation_issues issue
          where issue.source_id = '10000000-0000-4000-8000-000000000092'
            and issue.issue_code = 'legacy_engineer_requires_explicit_mapping'
        )
      )
      and audit.event_type in (
        'admin_user_role_changed', 'reconciliation_issue_resolved'
      )
  ) = 2
  and not exists (
    select 1
    from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000092'::uuid
      and auth_user.raw_app_meta_data ? '_v1_admin_audit_context'
  ),
  'Legacy engineer mapping, reconciliation result and both safe audits commit atomically'
);

-- The primary Auth-admin audit is the command claim. Retrying the same exact
-- role update must not add another audit or reconciliation effect.
update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"site_engineer"'::jsonb
   ) || jsonb_build_object(
     '_v1_admin_audit_context',
     jsonb_build_object(
       'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
       'action', 'role_changed',
       'idempotency_key', '50000000-0000-4000-8000-000000000002',
       'request_hash',
         'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
     )
   )
 where id = '10000000-0000-4000-8000-000000000092'::uuid;
select is(
  (
    select count(*)
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_role_changed'
      and audit.entity_id = '10000000-0000-4000-8000-000000000092'::uuid
  ),
  1::bigint,
  'An identical role-change retry is a true Auth no-op with one trusted audit'
);

select throws_ok(
  $$update auth.users
       set raw_app_meta_data = jsonb_set(
         raw_app_meta_data,
         '{role}',
         '"site_engineer"'::jsonb
       )
     where id = '10000000-0000-4000-8000-000000000093'::uuid$$,
  '42501',
  'V1_NONCANONICAL_ROLE_MAPPING_REQUIRES_AUDITED_ADMIN_COMMAND',
  'A missing/noncanonical role cannot become V1 canonical without audited Admin context'
);

update auth.users
   set raw_app_meta_data = jsonb_set(
     raw_app_meta_data,
     '{role}',
     '"project_engineer"'::jsonb
   ) || jsonb_build_object(
     '_v1_admin_audit_context',
     jsonb_build_object(
       'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
       'action', 'role_changed',
       'idempotency_key', '50000000-0000-4000-8000-000000000008',
       'request_hash',
         '2222222222222222222222222222222222222222222222222222222222222222'
     )
   )
 where id = '10000000-0000-4000-8000-000000000094'::uuid;
select ok(
  exists (
    select 1
    from public.v1_reconciliation_issues issue
    where issue.source_id = '10000000-0000-4000-8000-000000000094'
      and issue.issue_code = 'noncanonical_auth_role_requires_explicit_mapping'
      and issue.resolution_status = 'resolved'
      and issue.resulting_v1_entity_type = 'profile'
      and issue.resulting_v1_id =
        '10000000-0000-4000-8000-000000000094'::uuid
  )
  and exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = '10000000-0000-4000-8000-000000000094'::uuid
      and profile.canonical_role_snapshot = 'project_engineer'
  )
  and (
    select count(*)
    from public.v1_audit_events audit
    where audit.actor_auth_user_id =
        '10000000-0000-4000-8000-000000000004'::uuid
      and audit.event_type in (
        'admin_user_role_changed', 'reconciliation_issue_resolved'
      )
      and audit.idempotency_key =
        '50000000-0000-4000-8000-000000000008'::uuid
  ) = 2,
  'An explicit former-engineer mapping resolves its generic reconciliation and both audits atomically'
);

select throws_ok(
  $$select public.v1_b2_insert_auth_fixture(
    '10000000-0000-4000-8000-000000000095'::uuid,
    'duplicate-create-key.fixture@yorks.local.test',
    'site_engineer',
    'usr-b2-duplicate-create-key',
    jsonb_build_object(
      '_v1_admin_audit_context',
      jsonb_build_object(
        'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
        'action', 'created',
        'idempotency_key', '50000000-0000-4000-8000-000000000001',
        'request_hash',
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      )
    )
  )$$,
  '22023',
  'V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST',
  'A create retry key cannot provision a second Auth user or second audit'
);

-- Commercial capability commands return only a typed authorization envelope;
-- they never load a commercial record to decide access.
-- The earlier stale-session RLS fixture deliberately granted the seeded Admin
-- a view override. Remove that test-only override so this section can verify
-- the role-default envelope rather than a residual fixture value.
set local role postgres;
delete from public.v1_user_capabilities
 where auth_user_id = '10000000-0000-4000-8000-000000000004'::uuid
   and capability = 'view_commercials';
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement","caps":["viewCommercials","goods"]}}',
  true
);
select ok(
  public.v1_get_current_commercial_capabilities()
    = '{"capabilities":{"view_commercials":{"role_default":true,"effective":true,"override":null},"manage_commercials":{"role_default":true,"effective":true,"override":null}}}'::jsonb,
  'Current active Procurement receives the complete noncommercial default capability envelope'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select ok(
  public.v1_get_current_commercial_capabilities()
    = '{"capabilities":{"view_commercials":{"role_default":false,"effective":false,"override":null},"manage_commercials":{"role_default":false,"effective":false,"override":null}}}'::jsonb,
  'Current Project Engineer receives no default commercial capability'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select ok(
  public.v1_get_current_commercial_capabilities()
    = '{"capabilities":{"view_commercials":{"role_default":true,"effective":true,"override":null},"manage_commercials":{"role_default":true,"effective":true,"override":null}}}'::jsonb,
  'Current active Admin receives both default commercial capabilities'
);
select lives_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000091",
      "capability":"view_commercials",
      "is_granted":true,
      "reason":"Temporary approved site access"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000010'::uuid
  )$$,
  'An active exact Admin can grant a Site Engineer view_commercials through the protected command'
);
select ok(
  public.v1_get_user_commercial_capabilities(
    '10000000-0000-4000-8000-000000000091'::uuid
  ) = '{"capabilities":{"view_commercials":{"role_default":false,"effective":true,"override":true},"manage_commercials":{"role_default":false,"effective":false,"override":null}}}'::jsonb,
  'Admin lookup exposes only the target safe capability envelope after a grant'
);

set local role postgres;
select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'commercial_capability_changed'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
      and audit.actor_auth_user_id = '10000000-0000-4000-8000-000000000004'::uuid
      and audit.before_data =
        '{"role_default":false,"effective":false,"override":null}'::jsonb
      and audit.after_data =
        '{"role_default":false,"effective":true,"override":true}'::jsonb
  ),
  'Commercial override mutation records a safe, server-generated audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select is(
  public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000091",
      "capability":"view_commercials",
      "is_granted":true,
      "reason":"Temporary approved site access"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000010'::uuid
  ) -> 'capabilities' -> 'view_commercials' ->> 'effective',
  'true',
  'Same-key commercial capability retries return the original safe response'
);

select throws_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000091",
      "capability":"manage_commercials",
      "is_granted":true,
      "reason":"Forbidden engineer manager grant"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000011'::uuid
  )$$,
  '42501',
  'V1_ENGINEER_MANAGE_COMMERCIALS_NOT_ALLOWED',
  'No Project/Site Engineer can ever receive manage_commercials'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000091","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-b2-audit-fixture"}}',
  true
);
select ok(
  public.v1_get_current_commercial_capabilities()
    = '{"capabilities":{"view_commercials":{"role_default":false,"effective":true,"override":true},"manage_commercials":{"role_default":false,"effective":false,"override":null}}}'::jsonb,
  'A granted Site Engineer receives view only and never manage access'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000003",
      "capability":"view_commercials",
      "is_granted":false,
      "reason":"Procurement access revoked for regression coverage"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000012'::uuid
  )$$,
  'Admin can revoke a Procurement commercial view capability with an idempotent command'
);

set local role postgres;
insert into public.commercial_records (
  subject_type,
  subject_id,
  unit_cost_aed,
  updated_by_app_user_id
)
values ('material', '__b2_capability_revocation_fixture__', 17, 'usr-b2-test');
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement","caps":["viewCommercials","goods"]}}',
  true
);
select ok(
  public.v1_get_current_commercial_capabilities()
    = '{"capabilities":{"view_commercials":{"role_default":true,"effective":false,"override":false},"manage_commercials":{"role_default":true,"effective":false,"override":null}}}'::jsonb
  and (select count(*) from public.commercial_records) = 0,
  'V1 Procurement revoke fails closed despite cached JWT caps and hides commercial rows'
);
select throws_ok(
  $$insert into public.commercial_records (
      subject_type, subject_id, unit_cost_aed
    ) values ('material', '__b2_revoked_procurement_write__', 18)$$,
  '42501',
  null,
  'Revoked V1 Procurement cannot write commercial records through stale JWT caps'
);

select throws_ok(
  $$select public.v1_get_user_commercial_capabilities(
    '10000000-0000-4000-8000-000000000091'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ADMIN_REQUIRED',
  'Procurement cannot inspect another user capability envelope'
);
select throws_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000091",
      "capability":"view_commercials",
      "is_granted":false,
      "reason":"Unauthorized mutation"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000013'::uuid
  )$$,
  '42501',
  'V1_ACTIVE_ADMIN_REQUIRED',
  'Procurement cannot mutate protected user capability overrides'
);

-- Exercise the remaining Auth-admin actions.  The password and active
-- snapshots are intentionally safe (no email/password/raw metadata/caps).
set local role postgres;
update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'password_reset',
           'idempotency_key', '50000000-0000-4000-8000-000000000003',
           'request_hash',
             'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;
select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
      and audit.after_data =
        '{"role":"site_engineer","active":true,"password_reset":true}'::jsonb
      and audit.after_data::text not like '%@%'
      and audit.after_data::text not like '%caps%'
  )
  and not exists (
    select 1
    from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000091'::uuid
      and auth_user.raw_app_meta_data ? '_v1_admin_audit_context'
  ),
  'Password-reset Auth mutation commits only its safe audit snapshot and no context'
);

update auth.users
   set raw_user_meta_data = raw_user_meta_data ||
         jsonb_build_object('must_change_password', true),
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'password_reset',
           'idempotency_key', '50000000-0000-4000-8000-000000000003',
           'request_hash',
             'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;
select is(
  (
    select count(*)
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_password_reset'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
  ),
  1::bigint,
  'An identical password-reset retry is a no-op with exactly one trusted audit'
);

select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data ||
             jsonb_build_object('must_change_password', false),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context',
             jsonb_build_object(
               'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
               'action', 'password_reset',
               'idempotency_key', '50000000-0000-4000-8000-000000000003',
               'request_hash',
                 '9999999999999999999999999999999999999999999999999999999999999999'
             )
           )
     where id = '10000000-0000-4000-8000-000000000091'::uuid$$,
  '22023',
  'V1_AUTH_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_REQUEST',
  'Reusing an Auth-admin key with a different opaque request hash is rejected'
);

update auth.users
   set banned_until = clock_timestamp() + interval '1 hour',
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'active_changed',
           'idempotency_key', '50000000-0000-4000-8000-000000000004',
           'request_hash',
             'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;
select ok(
  exists (
    select 1
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_active_changed'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
      and audit.after_data =
        '{"role":"site_engineer","active":false}'::jsonb
  )
  and exists (
    select 1
    from public.v1_profiles profile
    where profile.auth_user_id = '10000000-0000-4000-8000-000000000091'::uuid
      and not profile.is_active
  ),
  'Active-state Auth mutation atomically audits and refreshes the target profile'
);

create function public.v1_b2_force_auth_audit_failure()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.event_type = 'admin_user_active_changed' then
    raise exception 'V1_TEST_FORCED_AUDIT_FAILURE' using errcode = '55000';
  end if;
  return new;
end;
$$;
create trigger v1_b2_force_auth_audit_failure
before insert on public.v1_audit_events
for each row execute function public.v1_b2_force_auth_audit_failure();
select throws_ok(
  $$update auth.users
       set banned_until = null,
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context',
             jsonb_build_object(
               'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
               'action', 'active_changed',
               'idempotency_key', '50000000-0000-4000-8000-000000000005',
               'request_hash',
                 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
             )
           )
     where id = '10000000-0000-4000-8000-000000000091'::uuid$$,
  '55000',
  'V1_TEST_FORCED_AUDIT_FAILURE',
  'An Auth mutation is rolled back when its atomic audit insert fails'
);
drop trigger v1_b2_force_auth_audit_failure on public.v1_audit_events;
drop function public.v1_b2_force_auth_audit_failure();
select ok(
  exists (
    select 1
    from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000091'::uuid
      and auth_user.banned_until > clock_timestamp()
      and not (auth_user.raw_app_meta_data ? '_v1_admin_audit_context')
  )
  and (
    select count(*)
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_active_changed'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
  ) = 1,
  'Failed audit leaves neither an Auth state change nor a partial audit event'
);

-- A later valid command may change the user, but replaying an older completed
-- idempotency key must return OLD from the Auth trigger rather than reapply an
-- unlogged state change.
update auth.users
   set banned_until = null,
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'active_changed',
           'idempotency_key', '50000000-0000-4000-8000-000000000009',
           'request_hash',
             '3333333333333333333333333333333333333333333333333333333333333333'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;
update auth.users
   set banned_until = clock_timestamp() + interval '2 hours',
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'active_changed',
           'idempotency_key', '50000000-0000-4000-8000-000000000004',
           'request_hash',
             'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;
select ok(
  exists (
    select 1
    from auth.users auth_user
    where auth_user.id = '10000000-0000-4000-8000-000000000091'::uuid
      and (auth_user.banned_until is null or auth_user.banned_until <= clock_timestamp())
  )
  and (
    select count(*)
    from public.v1_audit_events audit
    where audit.event_type = 'admin_user_active_changed'
      and audit.entity_id = '10000000-0000-4000-8000-000000000091'::uuid
  ) = 2,
  'Deactivate key replay after a later reactivation is a no-op and cannot create an unlogged mutation'
);

-- Restore the deactivated fixture required by the self-only Realtime/capability
-- assertions below, with a new command key and a third, auditable transition.
update auth.users
   set banned_until = clock_timestamp() + interval '1 hour',
       raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
         '_v1_admin_audit_context',
         jsonb_build_object(
           'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
           'action', 'active_changed',
           'idempotency_key', '50000000-0000-4000-8000-000000000010',
           'request_hash',
             '4444444444444444444444444444444444444444444444444444444444444444'
         )
       )
 where id = '10000000-0000-4000-8000-000000000091'::uuid;

select throws_ok(
  $$update auth.users
       set raw_user_meta_data = raw_user_meta_data || jsonb_build_object(
             'must_change_password', false
           ),
           raw_app_meta_data = raw_app_meta_data || jsonb_build_object(
             '_v1_admin_audit_context',
             jsonb_build_object(
               'actor_auth_user_id', '10000000-0000-4000-8000-000000000003',
               'action', 'password_reset',
               'idempotency_key', '50000000-0000-4000-8000-000000000006',
               'request_hash',
                 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
             )
           )
     where id = '10000000-0000-4000-8000-000000000091'::uuid$$,
  '42501',
  'V1_ADMIN_AUDIT_CONTEXT_ACTOR_NOT_ACTIVE_ADMIN',
  'A forged non-Admin audit context cannot mutate Auth state'
);

select throws_ok(
  $$update auth.users
       set raw_app_meta_data = jsonb_set(
             raw_app_meta_data,
             '{role}',
             '"procurement"'::jsonb
           ) || jsonb_build_object(
             '_v1_admin_audit_context',
             jsonb_build_object(
               'actor_auth_user_id', '10000000-0000-4000-8000-000000000004',
               'action', 'role_changed',
               'idempotency_key', '50000000-0000-4000-8000-000000000007',
               'request_hash',
                 '1111111111111111111111111111111111111111111111111111111111111111'
             )
           )
     where id = '10000000-0000-4000-8000-000000000004'::uuid$$,
  '55000',
  'V1_LAST_ACTIVE_ADMIN_REQUIRED',
  'The Auth trigger rejects demotion of the last active exact Admin'
);

select ok(
  position(
    'pg_advisory_xact_lock' in pg_get_functiondef(
      'public.v1_auth_users_admin_audit_trigger()'::regprocedure
    )
  ) > 0,
  'Last-active-Admin enforcement serializes concurrent Auth changes with an advisory transaction lock'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000091","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-b2-audit-fixture"}}',
  true
);
select is(
  (select count(*) from public.v1_profiles),
  1::bigint,
  'A deactivated actor can receive only its own profile Realtime refresh signal'
);
select is(
  (select count(*) from public.v1_user_capabilities),
  1::bigint,
  'A deactivated actor can receive only its own capability Realtime refresh signal'
);
select throws_ok(
  $$select public.v1_get_current_commercial_capabilities()$$,
  '42501',
  'V1_ACTIVE_V1_ACTOR_REQUIRED',
  'Current capability refresh fails closed for a deactivated actor'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  $$select public.v1_set_user_commercial_capability(
    '{
      "target_auth_user_id":"10000000-0000-4000-8000-000000000091",
      "capability":"view_commercials",
      "is_granted":true,
      "reason":"Inactive grants must fail"
    }'::jsonb,
    '40000000-0000-4000-8000-000000000014'::uuid
  )$$,
  '42501',
  'V1_COMMERCIAL_CAPABILITY_GRANT_TARGET_INACTIVE',
  'Admin cannot grant a commercial capability to an inactive target'
);
select ok(
  public.v1_get_user_commercial_capabilities(
    '10000000-0000-4000-8000-000000000091'::uuid
  ) = '{"capabilities":{"view_commercials":{"role_default":false,"effective":false,"override":true},"manage_commercials":{"role_default":false,"effective":false,"override":null}}}'::jsonb,
  'Admin can inspect an inactive target safe envelope while its effective access stays false'
);

set local role postgres;
select is(
  (
    select count(*)
    from pg_catalog.pg_publication_tables publication_table
    where publication_table.pubname = 'supabase_realtime'
      and publication_table.schemaname = 'public'
      and publication_table.tablename in (
        'v1_profiles', 'v1_user_capabilities'
      )
  ),
  2::bigint,
  'Profile and capability self-refresh tables are published to Supabase Realtime'
);

select * from finish();
rollback;
