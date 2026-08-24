begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(31);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_get_runtime_configuration()', 'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_get_runtime_configuration()', 'execute'
  ),
  'Only authenticated Yorks actors can reach the role-safe runtime configuration'
);

select ok(
  (select control_mode = 'operational'
   from public.v1_configuration_settings
   where setting_key = 'requests.default_timing')
  and (select control_mode = 'operational'
       from public.v1_configuration_settings
       where setting_key = 'requests.urgent_enabled')
  and (select control_mode = 'operational'
       from public.v1_configuration_settings
       where setting_key = 'notifications.push_enabled')
  and (select control_mode = 'protected'
       from public.v1_configuration_settings
       where setting_key = 'numbering.material_request_pattern')
  and (select control_mode = 'planned'
       from public.v1_configuration_settings
       where setting_key = 'accounts.payment_terms_days'),
  'The catalogue distinguishes operational, protected and planned controls'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_configuration_publications', 'select'
  )
  and not has_table_privilege(
    'authenticated',
    'public.v1_configuration_publication_changes',
    'select'
  ),
  'Authenticated runtime readers cannot inspect Admin publication detail tables'
);

select ok(
  position(
    'for update of target' in lower(pg_get_functiondef(
      'public.v1_publish_configuration(text,integer,uuid)'::regprocedure
    ))
  ) > 0,
  'Configuration publication locks staged master-data archive targets before validation and commit'
);

select ok(
  position(
    'for key share' in lower(pg_get_functiondef(
      'public.v1_enforce_active_configuration_unit()'::regprocedure
    ))
  ) > 0,
  'Controlled unit consumers take a lock that serializes against a competing archive publication'
);

select ok(
  exists (
    select 1
    from pg_trigger trigger_record
    where trigger_record.tgrelid =
      'public.v1_inventory_categories'::regclass
      and trigger_record.tgname = 'v1_inventory_categories_active_parent'
      and not trigger_record.tgisinternal
  )
  and position(
    'for key share' in lower(pg_get_functiondef(
      'public.v1_enforce_active_inventory_category_parent()'::regprocedure
    ))
  ) > 0,
  'New category children recheck their active parent across competing archive commits'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Project Engineer receives role-safe runtime configuration'
);

select ok(
  public.v1_get_runtime_configuration() ? 'default_timing'
  and public.v1_get_runtime_configuration() ? 'urgent_enabled'
  and public.v1_get_runtime_configuration()
      ? 'allow_authorized_creator_self_approval'
  and public.v1_get_runtime_configuration()
      ? 'require_external_source_readiness'
  and public.v1_get_runtime_configuration() ? 'push_enabled'
  and not (public.v1_get_runtime_configuration() ? 'history')
  and not (public.v1_get_runtime_configuration() ? 'draft_revision'),
  'The runtime projection contains effective controls without Admin draft or publication metadata'
);

do $fixture$
begin
  perform public.v1_create_project(
    '{
      "project_ref":"CFG-CTRL-001",
      "name":"Configuration control-plane proof",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"cfg","name":"Configuration Building"}],
      "attachments":[]
    }'::jsonb,
    'c3900000-0000-4000-8000-000000000001'::uuid
  );
end;
$fixture$;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Site Engineer receives role-safe runtime configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Procurement receives role-safe runtime configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Admin receives role-safe runtime configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Senior Mechanical Engineer receives role-safe runtime configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Project Manager receives role-safe runtime configuration'
);

set local role postgres;
update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"workshop_in_charge"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"workshop_in_charge","app_user_id":"usr-local-project-manager"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Workshop In-Charge receives role-safe runtime configuration'
);

set local role postgres;
update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"document_controller"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"document_controller","app_user_id":"usr-local-project-manager"}}',
  true
);
select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'Document Controller receives role-safe runtime configuration'
);

select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501',
  'V1_CONFIGURATION_ADMIN_REQUIRED',
  'A non-Admin runtime reader cannot open the Admin Configuration centre or its publication history'
);

select throws_ok(
  $$select public.v1_get_configuration_publication_detail(
    'c3800000-0000-4000-8000-000000000001'::uuid
  )$$,
  '42501',
  'V1_CONFIGURATION_ADMIN_REQUIRED',
  'A non-Admin runtime reader cannot inspect an individual Configuration publication'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_stage_configuration_master_action(
      'material_category', 'archive',
      '41000000-0000-4000-8000-000000000001'::uuid, '{}'::jsonb,
      'Attempt to remove baseline category',
      (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
      'c3900000-0000-4000-8000-000000000020'::uuid
    )$$,
  '23514',
  'V1_CONFIGURATION_SYSTEM_MASTER_PROTECTED',
  'Admin cannot archive a system material category'
);

select throws_ok(
  $$select public.v1_stage_configuration_master_action(
      'material_unit', 'archive',
      'c3810000-0000-4000-8000-000000000001'::uuid, '{}'::jsonb,
      'Attempt to remove baseline unit',
      (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
      'c3900000-0000-4000-8000-000000000021'::uuid
    )$$,
  '23514',
  'V1_CONFIGURATION_SYSTEM_MASTER_PROTECTED',
  'Admin cannot archive a system material unit'
);

select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'numbering.material_request_pattern',
    '"MR-{YYYY}-{###}"'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3900000-0000-4000-8000-000000000002'::uuid
  )$$,
  '22023',
  'V1_CONFIGURATION_SETTING_NOT_OPERATIONAL',
  'Admin cannot stage a protected server-authoritative control'
);

select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'accounts.payment_terms_days',
    '60'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3900000-0000-4000-8000-000000000003'::uuid
  )$$,
  '22023',
  'V1_CONFIGURATION_SETTING_NOT_OPERATIONAL',
  'Admin cannot stage a planned control that has no authoritative consumer'
);

set local role postgres;
insert into public.v1_configuration_draft_changes (
  setting_key, proposed_value, staged_by_auth_user_id
) values (
  'accounts.payment_terms_days',
  '60'::jsonb,
  '10000000-0000-4000-8000-000000000004'
)
on conflict (setting_key) do update set
  proposed_value = excluded.proposed_value,
  staged_by_auth_user_id = excluded.staged_by_auth_user_id,
  staged_at = clock_timestamp();

set local role authenticated;
select lives_ok(
  $$select public.v1_stage_configuration_setting(
    'accounts.payment_terms_days',
    '90'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3900000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Returning a legacy planned draft to its published value remains an allowed cleanup operation'
);

set local role postgres;
select ok(
  not exists (
    select 1
    from public.v1_configuration_draft_changes
    where setting_key = 'accounts.payment_terms_days'
  ),
  'The legacy planned draft is cleared rather than published'
);

set local role authenticated;
select lives_ok(
  $stage$
  do $body$
  declare
    v_revision integer;
  begin
    select (public.v1_get_configuration_centre()
      ->> 'draft_revision')::integer into v_revision;
    perform public.v1_stage_configuration_setting(
      'requests.default_timing', '"scheduled"'::jsonb, v_revision,
      'c3900000-0000-4000-8000-000000000005'::uuid
    );

    select (public.v1_get_configuration_centre()
      ->> 'draft_revision')::integer into v_revision;
    perform public.v1_stage_configuration_setting(
      'requests.urgent_enabled', 'false'::jsonb, v_revision,
      'c3900000-0000-4000-8000-000000000006'::uuid
    );

    select (public.v1_get_configuration_centre()
      ->> 'draft_revision')::integer into v_revision;
    perform public.v1_stage_configuration_setting(
      'notifications.push_enabled', 'false'::jsonb, v_revision,
      'c3900000-0000-4000-8000-000000000007'::uuid
    );
  end;
  $body$
  $stage$,
  'Admin can stage all three operational runtime controls'
);

select ok(
  public.v1_get_runtime_configuration()
      ->> 'default_timing' = 'normal'
  and (public.v1_get_runtime_configuration()
      ->> 'urgent_enabled')::boolean
  and (public.v1_get_runtime_configuration()
      ->> 'push_enabled')::boolean,
  'Staged operational values remain inert until an explicit publication'
);

select lives_ok(
  $$select public.v1_publish_configuration(
    'Activate tested runtime controls',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3900000-0000-4000-8000-000000000008'::uuid
  )$$,
  'Admin can publish the reviewed operational control changes atomically'
);

select ok(
  public.v1_get_runtime_configuration()
      ->> 'default_timing' = 'scheduled'
  and not (public.v1_get_runtime_configuration()
      ->> 'urgent_enabled')::boolean
  and not (public.v1_get_runtime_configuration()
      ->> 'push_enabled')::boolean,
  'Runtime consumers observe default timing, urgent and push changes only after publication'
);

set local role postgres;
select throws_ok(
  $$insert into public.v1_material_requests (
      id, project_id, scope_id, title, timing, state, record_version,
      created_by_auth_user_id, requester_display_name,
      requester_project_role, requester_exact_role,
      current_action_owner_role, current_action_code, created_at, updated_at
    )
    select
      'c3900000-0000-4000-8000-000000000009'::uuid,
      project.id,
      scope.id,
      'Urgent request blocked by published policy',
      'urgent',
      'draft',
      1,
      '10000000-0000-4000-8000-000000000001'::uuid,
      'Local Project Engineer',
      'project_engineer',
      'project_engineer',
      'project_engineer',
      'draft_owner',
      clock_timestamp(),
      clock_timestamp()
    from public.v1_projects project
    join public.v1_project_scopes scope
      on scope.project_id = project.id
      and scope.scope_kind = 'building'
    where project.project_ref = 'CFG-CTRL-001'
    limit 1$$,
  '23514',
  'V1_URGENT_REQUESTS_DISABLED',
  'Published urgent-disabled policy rejects a new urgent Material Request at the table boundary'
);

insert into public.v1_notifications (
  id, recipient_auth_user_id, event_code, entity_type, entity_id, created_at
) values (
  'c3900000-0000-4000-8000-000000000010',
  '10000000-0000-4000-8000-000000000001',
  'configuration_control_plane_test',
  'configuration_publication',
  'c3900000-0000-4000-8000-000000000011',
  clock_timestamp()
);

select ok(
  exists (
    select 1 from public.v1_notifications
    where id = 'c3900000-0000-4000-8000-000000000010'
  )
  and not exists (
    select 1 from public.v1_notification_push_outbox
    where notification_id = 'c3900000-0000-4000-8000-000000000010'
  ),
  'Push-disabled preserves the in-app notification while suppressing its new push outbox job'
);

update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"workshop_in_charge"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"workshop_in_charge","app_user_id":"usr-local-project-manager"}}',
  true
);
select ok(
  jsonb_array_length(public.v1_list_configuration_units()) > 0,
  'Workshop In-Charge can list the role-safe active unit register'
);

set local role postgres;
update auth.users
set raw_app_meta_data = jsonb_set(
  coalesce(raw_app_meta_data, '{}'::jsonb),
  '{role}',
  '"document_controller"'::jsonb
)
where id = '10000000-0000-4000-8000-000000000010';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"document_controller","app_user_id":"usr-local-project-manager"}}',
  true
);
select ok(
  jsonb_array_length(public.v1_list_configuration_units()) > 0,
  'Document Controller can list the role-safe active unit register'
);

select * from finish();
rollback;
