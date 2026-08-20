begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(47);

select ok(
  has_function_privilege(
    'authenticated', 'public.v1_get_configuration_centre()', 'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_stage_configuration_setting(text,jsonb,integer,uuid)',
    'execute'
  ) and has_function_privilege(
    'authenticated',
    'public.v1_publish_configuration(text,integer,uuid)',
    'execute'
  ),
  'Authenticated clients can reach configuration only through trusted RPCs'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.v1_configuration_settings', 'select'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_configuration_draft_changes', 'insert'
  ) and not has_table_privilege(
    'authenticated', 'public.v1_configuration_publications', 'update'
  ),
  'Authenticated clients have no direct configuration table access'
);

select ok(
  not has_function_privilege(
    'authenticated', 'public.v1_assert_configuration_admin()', 'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.v1_configuration_effective_value(text)', 'execute'
  ) and not has_function_privilege(
    'authenticated',
    'public.v1_validate_configuration_setting_value(text,jsonb)', 'execute'
  ),
  'Configuration implementation helpers are not Data API endpoints'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Project Engineer cannot read organization configuration'
);
select ok(
  public.v1_list_configuration_units() @> '["Nos","Meter"]'::jsonb,
  'Project Engineer receives the non-commercial active unit register'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Site Engineer cannot read organization configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Procurement cannot read organization configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000009","role":"authenticated","app_metadata":{"role":"senior_mechanical_engineer","app_user_id":"usr-local-senior-mechanical-engineer"}}',
  true
);
select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Senior Mechanical Engineer user-management authority does not grant Configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);
select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Project Manager global project authority does not grant Configuration'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_get_configuration_centre()$$,
  'Active exact Admin can read the controlled configuration projection'
);
select is(
  public.v1_get_configuration_centre() ->> 'published_label',
  'v1.0.0',
  'The deterministic baseline starts at v1.0.0'
);
select ok(
  jsonb_array_length(
    public.v1_get_configuration_centre() -> 'settings'
  ) >= 30,
  'The projection contains the normalized configurable setting catalogue'
);

select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'workflow.append_only_audit', 'false'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000001'
  )$$,
  '22023', 'V1_CONFIGURATION_SETTING_NOT_EDITABLE',
  'A protected workflow control cannot be introduced through a guessed key'
);
select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'numbering.material_request_pattern', '"MR-{YYYY}-{###}"'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000014'
  )$$,
  '22023', 'V1_CONFIGURATION_SETTING_NOT_EDITABLE',
  'Canonical server numbering cannot be weakened through Configuration'
);
select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'procurement.default_source', '"external_supplier"'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000015'
  )$$,
  '22023', 'V1_CONFIGURATION_SETTING_NOT_EDITABLE',
  'The canonical Warehouse-first arrangement source cannot be overridden'
);
select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'documents.maximum_file_size_mb', '25'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000016'
  )$$,
  '22023', 'V1_CONFIGURATION_SETTING_NOT_EDITABLE',
  'Configuration cannot promise a file size above the enforced 20 MiB limit'
);
select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'documents.allowed_formats', '["PDF","DWG"]'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000017'
  )$$,
  '22023', 'V1_CONFIGURATION_SETTING_NOT_EDITABLE',
  'Configuration cannot advertise a format outside the enforced MIME allowlist'
);

reset role;
insert into public.v1_inventory_items (
  id, item_description, unit, is_active, created_by_auth_user_id
) values (
  'c3820000-0000-4000-8000-000000000018',
  'R38 controlled-unit publication fixture', 'Nos', true,
  '10000000-0000-4000-8000-000000000004'
);
set local role authenticated;
select lives_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_unit', 'archive',
    'c3810000-0000-4000-8000-000000000001', '{}'::jsonb,
    'Retire a unit after checking operational usage',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000019'
  )$$,
  'Admin can stage a unit archive without mutating the published register'
);
select is(
  public.v1_get_configuration_validation() ->> 'status',
  'blocked',
  'Publication is blocked while an active Warehouse item uses the unit'
);
select lives_ok(
  $$select public.v1_discard_configuration_draft(
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000020'
  )$$,
  'Admin can discard the blocked unit archive without changing master data'
);
select is(
  (
    select setting ->> 'published_value'
    from jsonb_array_elements(
      public.v1_get_configuration_centre() -> 'settings'
    ) setting
    where setting ->> 'key' = 'numbering.dispatch_pattern'
  ),
  '{PROJECT_REF}-DSP{NNN}',
  'Configuration truthfully projects the canonical per-project dispatch format'
);
select throws_ok(
  $$select public.v1_stage_configuration_setting(
    'security.minimum_password_length', '8'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000002'
  )$$,
  '22023', 'V1_CONFIGURATION_INTEGER_OUT_OF_RANGE',
  'The draft command rejects a password baseline below the protected minimum'
);

select lives_ok(
  $$select public.v1_stage_configuration_setting(
    'accounts.billing_stage_weights',
    '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":0}'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000003'
  )$$,
  'Admin can stage an internally typed but publish-invalid billing allocation'
);
select is(
  (
    select sum((entry.value #>> '{}')::numeric)
    from jsonb_each(
      (
        select setting -> 'published_value'
        from jsonb_array_elements(
          public.v1_get_configuration_centre() -> 'settings'
        ) setting
        where setting ->> 'key' = 'accounts.billing_stage_weights'
      )
    ) entry
  ),
  100::numeric,
  'Staging never mutates the published configuration'
);
select is(
  public.v1_get_configuration_validation() ->> 'status',
  'blocked',
  'The authoritative validator blocks a billing total below 100 percent'
);
select throws_ok(
  $$select public.v1_publish_configuration(
    'Attempt invalid billing publication',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000004'
  )$$,
  '23514', 'V1_CONFIGURATION_VALIDATION_BLOCKED',
  'Publication revalidates and rejects a blocking draft atomically'
);

select lives_ok(
  $$select public.v1_stage_configuration_setting(
    'accounts.billing_stage_weights',
    '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":5}'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000005'
  )$$,
  'Admin can correct the draft allocation with an optimistic revision check'
);
select is(
  public.v1_get_configuration_validation() ->> 'status',
  'recommendations',
  'Non-blocking MFA guidance remains a recommendation'
);
select throws_ok(
  $$select public.v1_publish_configuration(
    'short',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000006'
  )$$,
  '22023', 'V1_CONFIGURATION_PUBLISH_REASON_REQUIRED',
  'Publication requires a meaningful reason'
);

select lives_ok(
  $$select public.v1_stage_configuration_setting(
    'notifications.email_enabled', 'true'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000010'
  )$$,
  'Admin can stage a valid production change after correcting validation'
);

create temporary table configuration_publish_context as
select
  (public.v1_get_configuration_centre() ->> 'draft_revision')::integer
    as expected_revision,
  'c3820000-0000-4000-8000-000000000007'::uuid as idempotency_key;
grant select on table configuration_publish_context to authenticated;

select lives_ok(
  $$select public.v1_publish_configuration(
    'Approve the controlled R38 configuration test release',
    (select expected_revision from configuration_publish_context),
    (select idempotency_key from configuration_publish_context)
  )$$,
  'Admin can publish a validated draft with a reason'
);
select is(
  (
    select sum((entry.value #>> '{}')::numeric)
    from jsonb_each(
      (
        select setting -> 'published_value'
        from jsonb_array_elements(
          public.v1_get_configuration_centre() -> 'settings'
        ) setting
        where setting ->> 'key' = 'accounts.billing_stage_weights'
      )
    ) entry
  ),
  100::numeric,
  'The publication commits the validated setting value'
);
select is(
  jsonb_array_length(public.v1_get_configuration_centre() -> 'history'),
  2,
  'The immutable history contains baseline and published release'
);
set local role postgres;
select ok(
  exists (
    select 1 from public.v1_audit_events audit
    where audit.event_type = 'configuration_published'
      and audit.actor_auth_user_id =
        '10000000-0000-4000-8000-000000000004'
      and audit.actor_exact_role = 'admin'
      and audit.reason =
        'Approve the controlled R38 configuration test release'
  ),
  'Publication appends exact actor, role and reason to trusted audit history'
);
set local role authenticated;
select lives_ok(
  $$select public.v1_publish_configuration(
    'Approve the controlled R38 configuration test release',
    (select expected_revision from configuration_publish_context),
    (select idempotency_key from configuration_publish_context)
  )$$,
  'A lost-response publication retry returns the original committed result'
);

set local role postgres;
select throws_ok(
  $$update public.v1_configuration_publications
    set reason = 'Attempted rewrite of published history'
    where version_number = 2$$,
  '55000', 'V1_CONFIGURATION_HISTORY_IMMUTABLE',
  'Even a privileged direct update cannot rewrite publication history'
);
select throws_ok(
  $$update public.v1_configuration_publication_changes
    set after_value = 'null'::jsonb
    where publication_id = (
      select id from public.v1_configuration_publications
      where version_number = 2
    )$$,
  '55000', 'V1_CONFIGURATION_HISTORY_IMMUTABLE',
  'Even a privileged direct update cannot rewrite publication changes'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);
select lives_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_category', 'create',
    'c3830000-0000-4000-8000-000000000001',
    '{"name":"Configuration Test Category","parent_category_id":null}'::jsonb,
    null,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000008'
  )$$,
  'A new category is staged without becoming active master data'
);
select is(
  (
    select count(*)
    from jsonb_array_elements(
      public.v1_get_configuration_centre() -> 'material_categories'
    ) category
    where category ->> 'id' = 'c3830000-0000-4000-8000-000000000001'
  ),
  0::bigint,
  'A staged category is not inserted before publication'
);
select throws_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_category', 'create',
    'c3830000-0000-4000-8000-000000000002',
    '{"name":" configuration-test category ","parent_category_id":null}'::jsonb,
    null,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000013'
  )$$,
  '23505', 'V1_CONFIGURATION_CATEGORY_INVALID_OR_DUPLICATE',
  'Normalized duplicate categories cannot coexist in one draft'
);
select lives_ok(
  $$select public.v1_discard_configuration_draft(
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000009'
  )$$,
  'Admin can discard staged master data with an optimistic revision check'
);
select is(
  jsonb_array_length(
    public.v1_get_configuration_centre() -> 'master_actions'
  ),
  0,
  'Discard removes only unpublished master actions'
);

select lives_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_unit', 'create',
    'c3830000-0000-4000-8000-000000000003',
    '{"name":"Configuration Test Unit","short_code":"CTU","unit_type":"count","decimal_places":0}'::jsonb,
    null,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000011'
  )$$,
  'A controlled unit can be staged without changing the active register'
);
select lives_ok(
  $$select public.v1_publish_configuration(
    'Publish the controlled test unit master-data change',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c3820000-0000-4000-8000-000000000012'
  )$$,
  'A validated master-data draft publishes atomically'
);
select is(
  (
    select count(*)
    from jsonb_array_elements(
      public.v1_get_configuration_centre() -> 'material_units'
    ) unit_record
    where unit_record ->> 'id' =
      'c3830000-0000-4000-8000-000000000003'
      and (unit_record ->> 'is_active')::boolean
  ),
  1::bigint,
  'Published master data becomes available through the controlled projection'
);
select ok(
  public.v1_list_configuration_units() @> '["CTU"]'::jsonb,
  'A published unit becomes active for future operational entry'
);

set local role postgres;
select throws_ok(
  $$insert into public.v1_inventory_items (
      id, item_description, unit, created_by_auth_user_id
    ) values (
      'c3830000-0000-4000-8000-000000000004',
      'Invalid configuration unit test',
      'Retired or unknown unit',
      '10000000-0000-4000-8000-000000000004'
    )$$,
  '23514', 'V1_CONFIGURATION_UNIT_NOT_ACTIVE',
  'The database rejects an unknown unit on a future inventory row'
);

select * from finish();
rollback;
