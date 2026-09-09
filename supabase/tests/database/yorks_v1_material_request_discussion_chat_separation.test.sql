begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_ensure_material_request_discussion(uuid,uuid)',
    'execute'
  )
  and has_function_privilege(
    'authenticated',
    'public.v1_start_material_request_team_conversation(uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_ensure_material_request_discussion(uuid,uuid)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_start_material_request_team_conversation(uuid,uuid)',
    'execute'
  ),
  'Discussion and explicit Team Chat start use authenticated protected RPCs'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.v1_chat_conversations'::regclass
      and tgname = 'v1_default_material_request_discussion_hidden'
      and not tgisinternal
  ),
  'New Material Request backing conversations default to hidden'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"MR-DISC-SEPARATION-001",
      "name":"Discussion separation proof",
      "parties":{},
      "initial_members":[],
      "buildings":[{"code":"disc","name":"Discussion Building"}],
      "attachments":[]
    }'::jsonb,
    'e9000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Manager creates the isolated discussion project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (
        select id from public.v1_projects
        where project_ref = 'MR-DISC-SEPARATION-001'
      ),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for discussion separation testing'
    ),
    'e9000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The isolated discussion project is active'
);

set local role postgres;
insert into public.v1_material_requests (
  id, project_id, scope_id, request_number, title, timing, state,
  record_version, created_by_auth_user_id, requester_display_name,
  requester_project_role, requester_exact_role, current_action_owner_role,
  current_action_code, submitted_at, created_at, updated_at
) values (
  'e9000000-0000-4000-8000-000000000010',
  (select id from public.v1_projects
    where project_ref = 'MR-DISC-SEPARATION-001'),
  (select scope.id from public.v1_project_scopes scope
    join public.v1_projects project on project.id = scope.project_id
    where project.project_ref = 'MR-DISC-SEPARATION-001'
      and scope.scope_kind = 'building'
    limit 1),
  'MR-DISC-SEPARATION-001-MR001',
  'Record-only discussion proof',
  'normal', 'submitted', 1,
  '10000000-0000-4000-8000-000000000010',
  'Local Project Manager', 'project_engineer', 'project_manager',
  'procurement', 'arrangement_required', clock_timestamp(),
  clock_timestamp(), clock_timestamp()
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000010","role":"authenticated","app_metadata":{"role":"project_manager","app_user_id":"usr-local-project-manager"}}',
  true
);

select lives_ok(
  $$select public.v1_add_material_request_comment(
    jsonb_build_object(
      'request_id', 'e9000000-0000-4000-8000-000000000010',
      'body', 'Record-only discussion message',
      'mentioned_auth_user_ids', '[]'::jsonb,
      'attachment_ids', '[]'::jsonb,
      'parent_comment_id', null,
      'context_type', 'material_request',
      'context_entity_id', 'e9000000-0000-4000-8000-000000000010'
    ),
    'e9000000-0000-4000-8000-000000000011'::uuid
  )$$,
  'Posting a request comment succeeds without an explicit Team Chat start'
);

select is(
  (
    select conversation.is_listed_in_team_chat
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id =
        'e9000000-0000-4000-8000-000000000010'
  ),
  false,
  'The comment backing conversation stays record-only'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.v1_list_chat_conversations()) item
    where item ->> 'material_request_id' =
      'e9000000-0000-4000-8000-000000000010'
  ),
  'Record-only discussion does not appear in the Team Chat register'
);

select is(
  jsonb_array_length(public.v1_search_chat('Record-only discussion', 50)),
  0,
  'Team Chat search excludes a record-only discussion'
);

select is(
  jsonb_array_length(
    public.v1_list_material_request_comments(
      'e9000000-0000-4000-8000-000000000010'
    ) -> 'items'
  ),
  1,
  'The comment remains visible on the Material Request record'
);

select lives_ok(
  $$select public.v1_ensure_material_request_discussion(
    'e9000000-0000-4000-8000-000000000010',
    'e9000000-0000-4000-8000-000000000012'::uuid
  )$$,
  'Attachment preparation can reuse the record-bound discussion'
);

select is(
  (
    select conversation.is_listed_in_team_chat
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id =
        'e9000000-0000-4000-8000-000000000010'
  ),
  false,
  'Attachment preparation does not publish the discussion in Team Chat'
);

select lives_ok(
  $$select public.v1_start_material_request_team_conversation(
    'e9000000-0000-4000-8000-000000000010',
    'e9000000-0000-4000-8000-000000000013'::uuid
  )$$,
  'An explicit Start team conversation promotes the retained thread'
);

select is(
  (
    select conversation.is_listed_in_team_chat
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id =
        'e9000000-0000-4000-8000-000000000010'
  ),
  true,
  'The explicitly started conversation becomes discoverable'
);

select ok(
  exists (
    select 1
    from jsonb_array_elements(public.v1_list_chat_conversations()) item
    where item ->> 'material_request_id' =
      'e9000000-0000-4000-8000-000000000010'
  ),
  'The promoted conversation appears in the Team Chat register'
);

select is(
  jsonb_array_length(public.v1_search_chat('Record-only discussion', 50)),
  1,
  'The promoted conversation becomes searchable in Team Chat'
);

select lives_ok(
  $$select public.v1_ensure_material_request_discussion(
    'e9000000-0000-4000-8000-000000000010',
    'e9000000-0000-4000-8000-000000000014'::uuid
  )$$,
  'Later request comments continue using the promoted conversation'
);

select is(
  (
    select conversation.is_listed_in_team_chat
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id =
        'e9000000-0000-4000-8000-000000000010'
  ),
  true,
  'A later record comment never hides an explicitly started Team Chat'
);

set local role anon;
select set_config(
  'request.jwt.claims',
  '{"role":"anon"}',
  true
);

select throws_ok(
  $$select public.v1_ensure_material_request_discussion(
    'e9000000-0000-4000-8000-000000000010',
    'e9000000-0000-4000-8000-000000000015'::uuid
  )$$,
  '42501',
  null,
  'Anonymous users cannot open a request discussion'
);

select * from finish();
rollback;
