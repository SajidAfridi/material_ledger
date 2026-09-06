begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(14);

select ok(
  exists (
    select 1
    from public.v1_configuration_settings
    where setting_key = 'support.developer_whatsapp'
      and area = 'company_regional'
      and value_type = 'string'
      and control_mode = 'operational'
      and enforcement_target = 'profile_support_contact'
  ),
  'Support WhatsApp is an operational published Configuration control'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.v1_validate_configuration_setting_value(text,jsonb)',
    'execute'
  )
  and not has_function_privilege(
    'anon', 'public.v1_get_runtime_configuration()', 'execute'
  ),
  'Validation stays internal and anonymous callers cannot read runtime settings'
);

set local role postgres;

select lives_ok(
  $$select public.v1_validate_configuration_setting_value(
    'support.developer_whatsapp', '"+923159353145"'::jsonb
  )$$,
  'A canonical E.164 support number is accepted'
);

select throws_ok(
  $$select public.v1_validate_configuration_setting_value(
    'support.developer_whatsapp', '"03159353145"'::jsonb
  )$$,
  '22023',
  'V1_CONFIGURATION_SUPPORT_CONTACT_INVALID',
  'An ambiguous local-only support number is rejected'
);

select throws_ok(
  $$select public.v1_validate_configuration_setting_value(
    'support.developer_whatsapp', '923159353145'::jsonb
  )$$,
  '22023',
  'V1_CONFIGURATION_STRING_REQUIRED',
  'A non-string support number is rejected'
);

set local role authenticated;
reset role;
select throws_ok(
  $$select public.v1_validate_configuration_setting_value(
    'support.developer_whatsapp', '" +923159353145 "'::jsonb
  )$$,
  '22023', 'V1_CONFIGURATION_SUPPORT_CONTACT_INVALID',
  'Whitespace cannot create a published value rejected by the app');
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}', true);
select throws_ok(
  $$select public.v1_stage_configuration_setting('support.developer_whatsapp', '"+971501234567"'::jsonb, 0, 'e5150b99-aa0c-4d30-b96a-0be46e471002'::uuid)$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Project Engineer cannot change the company support contact');
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}', true);
select throws_ok(
  $$select public.v1_stage_configuration_setting('support.developer_whatsapp', '"+971501234567"'::jsonb, 0, 'e5150b99-aa0c-4d30-b96a-0be46e471003'::uuid)$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Site Engineer cannot change the company support contact');
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}', true);
select throws_ok(
  $$select public.v1_stage_configuration_setting('support.developer_whatsapp', '"+971501234567"'::jsonb, 0, 'e5150b99-aa0c-4d30-b96a-0be46e471004'::uuid)$$,
  '42501', 'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Procurement cannot change the company support contact');
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant","app_user_id":"usr-local-accountant"}}',
  true
);

select lives_ok(
  $$select public.v1_get_runtime_configuration()$$,
  'An active Accountant can read the non-sensitive runtime projection'
);

select is(
  public.v1_get_runtime_configuration() ->> 'support_whatsapp',
  '+923159353145',
  'Runtime configuration exposes only the published support contact'
);

select throws_ok(
  $$select public.v1_get_configuration_centre()$$,
  '42501',
  'V1_CONFIGURATION_ADMIN_REQUIRED',
  'Accountant cannot inspect or change the Admin Configuration centre'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_stage_configuration_setting(
    'support.developer_whatsapp',
    '"+971501234567"'::jsonb,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'e5150b99-aa0c-4d30-b96a-0be46e471001'::uuid
  )$$,
  'Admin can stage a validated support contact through the trusted command'
);

select ok(
  public.v1_get_runtime_configuration() ->> 'support_whatsapp' =
    '+923159353145'
  and exists (
    select 1
    from jsonb_array_elements(
      public.v1_get_configuration_centre() -> 'settings'
    ) setting
    where setting ->> 'key' = 'support.developer_whatsapp'
      and setting ->> 'effective_value' = '+971501234567'
      and (setting ->> 'changed')::boolean
  ),
  'A draft is reviewable by Admin but cannot change the live support contact'
);

select * from finish();
rollback;
