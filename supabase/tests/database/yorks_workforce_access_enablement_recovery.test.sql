begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_overview(jsonb)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_assign_user_workforce_organization(text,text,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_apply_user_permission_changes_with_workforce(text,jsonb,text,bigint,boolean,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'authenticated',
    'public.v1_get_workforce_overview_authorized_data(jsonb)',
    'execute'
  ),
  'Only the reviewed Workforce recovery boundaries are client-callable'
);

insert into public.v1_permission_assignments(
  id, auth_user_id, capability_key, effect, scope_kind, origin,
  effective_from, reason, changed_by_auth_user_id
) values (
  '5ae10000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000002',
  'workforce.view', 'grant', 'organization', 'permission_management',
  '2026-08-01', 'Capability-only empty-state negative',
  '10000000-0000-4000-8000-000000000004'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor"}'::jsonb
  )$$,
  '42501', 'V1_WORKFORCE_T10_READ_DENIED',
  'Capability without dated responsibility still fails closed'
);
select throws_ok(
  $$select public.v1_assign_user_workforce_organization(
    'usr-local-site-engineer',
    'Unauthorized responsibility attempt',
    '5ae20000-0000-4000-8000-000000000001'
  )$$,
  '42501', 'V1_WORKFORCE_ADMIN_REQUIRED',
  'A non-Admin cannot assign organization Workforce responsibility'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_apply_user_permission_changes_with_workforce(
    'usr-local-project-engineer',
    '[
      {"operation":"set","capability_key":"workforce.view","effect":"grant","scope_kind":"organization","project_ids":[],"effective_from":null,"effective_until":null},
      {"operation":"set","capability_key":"workforce.attendance.maintain","effect":"grant","scope_kind":"organization","project_ids":[],"effective_from":null,"effective_until":null}
    ]'::jsonb,
    'Enable supervised attendance with reviewed prerequisites',
    (select revision from public.v1_permission_revisions
      where app_user_id = 'usr-local-project-engineer'),
    true,
    '5ae30000-0000-4000-8000-000000000001'
  )$$,
  'The reviewed permission batch and responsibility commit atomically'
);
select is(
  public.v1_get_user_permission_workspace('usr-local-project-engineer')
    #>> '{workforce_access,has_operational_access}',
  'true',
  'The protected workspace confirms effective Workforce view access'
);
select ok(
  public.v1_get_user_permission_workspace('usr-local-project-engineer')
    #> '{workforce_access,organization_responsibility}' <> 'null'::jsonb,
  'The protected workspace exposes the effective organization responsibility'
);
select is(
  public.v1_get_user_permission_workspace('usr-local-project-engineer')
    #>> '{workforce_access,active_team_count}',
  '0',
  'The protected workspace reports the genuine empty Workforce setup'
);
select lives_ok(
  $$select public.v1_apply_user_permission_changes_with_workforce(
    'usr-local-project-engineer',
    '[
      {"operation":"set","capability_key":"workforce.view","effect":"grant","scope_kind":"organization","project_ids":[],"effective_from":null,"effective_until":null},
      {"operation":"set","capability_key":"workforce.attendance.maintain","effect":"grant","scope_kind":"organization","project_ids":[],"effective_from":null,"effective_until":null}
    ]'::jsonb,
    'Enable supervised attendance with reviewed prerequisites',
    0,
    true,
    '5ae30000-0000-4000-8000-000000000001'
  )$$,
  'An exact retry returns the completed response without duplicate effects'
);
reset role;

select is(
  (select count(*)::integer
   from public.v1_permission_assignments assignment
   where assignment.auth_user_id =
       '10000000-0000-4000-8000-000000000001'
     and assignment.capability_key in (
       'workforce.view', 'workforce.attendance.maintain'
     )
     and assignment.effect = 'grant'
     and assignment.scope_kind = 'organization'),
  2,
  'The reviewed grant persists its explicit prerequisite exactly once'
);
select is(
  (select count(*)::integer
   from public.v1_workforce_responsibility_assignments responsibility
   where responsibility.auth_user_id =
       '10000000-0000-4000-8000-000000000001'
     and responsibility.scope_kind = 'organization'),
  1,
  'The organization responsibility remains idempotent'
);
select is(
  (select count(*)::integer
   from public.v1_permission_change_events event
   where event.idempotency_key =
       '5ae30000-0000-4000-8000-000000000001'),
  2,
  'Both reviewed permission rows retain one auditable batch identity'
);
select is(
  (select count(*)::integer
   from public.v1_audit_events event
   where event.idempotency_key =
       '5ae30000-0000-4000-8000-000000000001'
     and event.entity_type = 'workforce_responsibility_assignment'),
  1,
  'Responsibility creation retains one append-only audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select is(
  jsonb_array_length(public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor"}'::jsonb
  ) -> 'teams'),
  0,
  'An authorized supervisor receives the genuine empty state, not access denied'
);
select is(
  public.v1_get_workforce_overview(
    '{"overview_kind":"supervisor"}'::jsonb
  ) #>> '{summary,worker_count}',
  '0',
  'The empty overview preserves the strict server-confirmed summary shape'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select ok(
  not (
    public.v1_get_user_permission_workspace('usr-local-project-engineer')
      ? 'workforce_access'
  ),
  'Non-Admin permission viewers receive no responsibility metadata or counts'
);
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select throws_ok(
  $$select public.v1_apply_user_permission_changes_with_workforce(
    'usr-local-procurement',
    '[{"operation":"set","capability_key":"workforce.attendance.maintain","effect":"grant","scope_kind":"organization","project_ids":[],"effective_from":null,"effective_until":null}]'::jsonb,
    'Rejected incomplete Workforce enablement',
    (select revision from public.v1_permission_revisions
      where app_user_id = 'usr-local-procurement'),
    true,
    '5ae40000-0000-4000-8000-000000000001'
  )$$,
  '23514', 'V1_PERMISSION_DEPENDENCY_NOT_EFFECTIVE',
  'A missing permission prerequisite rejects the complete enablement'
);
reset role;
select ok(
  not exists (
    select 1
    from public.v1_permission_assignments assignment
    where assignment.auth_user_id =
        '10000000-0000-4000-8000-000000000003'
      and assignment.capability_key = 'workforce.attendance.maintain'
  )
  and not exists (
    select 1
    from public.v1_workforce_responsibility_assignments responsibility
    where responsibility.auth_user_id =
        '10000000-0000-4000-8000-000000000003'
      and responsibility.scope_kind = 'organization'
  ),
  'A failed combined command leaves neither permission nor responsibility'
);

select * from finish();
rollback;
