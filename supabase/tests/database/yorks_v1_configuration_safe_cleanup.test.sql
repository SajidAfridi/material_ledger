begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select ok(
  pg_get_functiondef(
    'public.v1_publish_configuration_before_control_plane(text,integer,uuid)'
      ::regprocedure
  ) ~* 'delete from public\.v1_configuration_draft_changes as draft_change[[:space:]]+where draft_change\.setting_key is not null',
  'Configuration publication clears staged settings with an explicit primary-key predicate'
);

select ok(
  pg_get_functiondef(
    'public.v1_publish_configuration_before_control_plane(text,integer,uuid)'
      ::regprocedure
  ) ~* 'delete from public\.v1_configuration_master_actions as master_action[[:space:]]+where master_action\.id is not null',
  'Configuration publication clears staged master actions with an explicit primary-key predicate'
);

select ok(
  pg_get_functiondef(
    'public.v1_discard_configuration_draft(integer,uuid)'::regprocedure
  ) ~* 'delete from public\.v1_configuration_draft_changes as draft_change[[:space:]]+where draft_change\.setting_key is not null',
  'Discard draft clears staged settings with an explicit primary-key predicate'
);

select ok(
  pg_get_functiondef(
    'public.v1_discard_configuration_draft(integer,uuid)'::regprocedure
  ) ~* 'delete from public\.v1_configuration_master_actions as master_action[[:space:]]+where master_action\.id is not null',
  'Discard draft clears staged master actions with an explicit primary-key predicate'
);

insert into public.v1_inventory_categories (
  id,
  name,
  normalized_name,
  is_system,
  is_active,
  created_by_auth_user_id
) values (
  'c2700000-0000-4000-8000-000000000001'::uuid,
  'Temporary test category',
  'temporary test category',
  false,
  true,
  '10000000-0000-4000-8000-000000000004'::uuid
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_category',
    'archive',
    'c2700000-0000-4000-8000-000000000001'::uuid,
    '{}'::jsonb,
    'Test category is no longer required',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c2700000-0000-4000-8000-000000000002'::uuid
  )$$,
  'Admin can stage a non-system category archive'
);

select lives_ok(
  $$select public.v1_stage_configuration_master_action(
    'material_unit',
    'create',
    'c2700000-0000-4000-8000-000000000003'::uuid,
    '{"name":"Bundle","short_code":"Bundle","unit_type":"count","decimal_places":0}'::jsonb,
    null,
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c2700000-0000-4000-8000-000000000004'::uuid
  )$$,
  'Admin can stage a controlled material unit creation'
);

select lives_ok(
  $$select public.v1_publish_configuration(
    'Publish tested category cleanup and new Bundle unit',
    (public.v1_get_configuration_centre() ->> 'draft_revision')::integer,
    'c2700000-0000-4000-8000-000000000005'::uuid
  )$$,
  'A category archive and unit creation publish atomically with production-safe cleanup'
);

reset role;

select ok(
  not (select is_active from public.v1_inventory_categories
       where id = 'c2700000-0000-4000-8000-000000000001'::uuid)
  and exists (
    select 1
    from public.v1_configuration_units
    where id = 'c2700000-0000-4000-8000-000000000003'::uuid
      and name = 'Bundle'
      and short_code = 'Bundle'
      and is_active
  ),
  'Published master-data changes preserve the requested archive and unit creation'
);

select * from finish();
rollback;
