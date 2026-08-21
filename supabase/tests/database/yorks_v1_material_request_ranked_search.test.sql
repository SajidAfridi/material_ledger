begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(17);

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_search_material_request_candidates(uuid,uuid,text,integer)',
    'execute'
  ) and not has_function_privilege(
    'anon',
    'public.v1_search_material_request_candidates(uuid,uuid,text,integer)',
    'execute'
  ),
  'Ranked material search is authenticated-only'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"MR-SRCH-001",
      "name":"Ranked Material Discovery",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Material request author"
      }],
      "buildings":[{"code":"ranked","name":"Ranked Building"}],
      "attachments":[]
    }'::jsonb,
    'be000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates the ranked-search project fixture'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects
        where project_ref = 'MR-SRCH-001'),
      'state', 'active',
      'expected_version', 1,
      'reason', 'Ready for material discovery testing'
    ),
    'be000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The ranked-search project is activated'
);

set local role postgres;
create temporary table v1_ranked_targets as
select project.id as project_id,
  building.id as building_scope_id,
  common.id as common_scope_id,
  (select group_record.id from public.v1_boq_groups group_record
    where group_record.scope_id = building.id and not group_record.is_archived
    order by group_record.display_order limit 1) as building_group_id,
  (select group_record.id from public.v1_boq_groups group_record
    where group_record.scope_id = common.id and not group_record.is_archived
    order by group_record.display_order limit 1) as common_group_id
from public.v1_projects project
join public.v1_project_scopes building
  on building.project_id = project.id and building.scope_kind = 'building'
join public.v1_project_scopes common
  on common.project_id = project.id and common.scope_kind = 'common'
where project.project_ref = 'MR-SRCH-001';

select lives_ok(
  $$insert into public.v1_boq_rows (
    id, group_id, display_order, raw_values, canonical_values,
    created_by_auth_user_id
  ) values
  (
    'be100000-0000-4000-8000-000000000001'::uuid,
    (select building_group_id from v1_ranked_targets), 1, '{}'::jsonb,
    '{"description":"Smart Damper Scope","brand_origin":"UAE","size":"500 x 500","model":"SD-SCOPE","unit":"Nos"}'::jsonb,
    '10000000-0000-4000-8000-000000000001'::uuid
  ),
  (
    'be100000-0000-4000-8000-000000000002'::uuid,
    (select common_group_id from v1_ranked_targets), 1, '{}'::jsonb,
    '{"description":"Smart Damper Project","brand_origin":"UAE","size":"600 x 600","model":"SD-PROJECT","unit":"Nos"}'::jsonb,
    '10000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Selected-scope and wider-project BOQ rows are available for discovery'
);
grant select on table v1_ranked_targets to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_adjust_inventory(
    jsonb_build_object(
      'inventory_item_id', null,
      'item_description', 'Smart Damper Inventory',
      'brand_origin', 'Germany',
      'unit', 'Nos',
      'quantity_delta', '5',
      'reason', 'Ranked discovery fixture'
    ),
    'be200000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Procurement creates the inventory fallback fixture'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select is(
  jsonb_array_length(public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  )),
  3,
  'Authorized Site Engineer receives BOQ and inventory candidates'
);

select is(
  (select jsonb_agg(item ->> 'source_kind' order by ordinality)
   from jsonb_array_elements(public.v1_search_material_request_candidates(
     (select project_id from v1_ranked_targets),
     (select building_scope_id from v1_ranked_targets),
     'Smart Damper', 18
   )) with ordinality as result(item, ordinality)),
  '["scope_boq", "project_boq", "inventory"]'::jsonb,
  'Candidates are ordered by selected scope, project BOQ, then inventory'
);

select ok(
  not exists (
    select 1
    from jsonb_array_elements(public.v1_search_material_request_candidates(
      (select project_id from v1_ranked_targets),
      (select building_scope_id from v1_ranked_targets),
      'Smart Damper', 18
    )) as result(item)
    where item ?| array[
      'unit_cost', 'total_cost', 'on_hand_qty', 'available_qty',
      'reserved_qty', 'minimum_stock', 'location'
    ]
  ),
  'Engineering search shape contains no commercial or stock quantities'
);

select ok(
  (public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  ) -> 0 ->> 'source_boq_row_id') =
    'be100000-0000-4000-8000-000000000001'
  and (public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  ) -> 0 ->> 'source_scope_id') =
    (select building_scope_id::text from v1_ranked_targets),
  'Selected-scope BOQ result retains exact row and scope provenance'
);

select ok(
  (public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  ) -> 1 ->> 'source_boq_row_id') =
    'be100000-0000-4000-8000-000000000002'
  and (public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  ) -> 1 ->> 'source_scope_id') =
    (select common_scope_id::text from v1_ranked_targets),
  'Wider-project BOQ result identifies its different real scope'
);

select ok(
  not (public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  ) -> 2) ? 'source_boq_row_id',
  'Inventory fallback cannot masquerade as a BOQ source'
);

select is(
  jsonb_array_length(public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'missing custom description', 18
  )),
  0,
  'No match returns an empty list so the client can retain free text'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);
select lives_ok(
  $$select public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  )$$,
  'Procurement can use the same correlation during arrangement'
);

select throws_ok(
  $$select public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    'be900000-0000-4000-8000-000000000001'::uuid,
    'Smart Damper', 18
  )$$,
  '22023', 'V1_MATERIAL_REQUEST_CANDIDATE_SEARCH_INVALID',
  'A scope outside the project is rejected'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"be900000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"inactive"}}',
  true
);
select throws_ok(
  $$select public.v1_search_material_request_candidates(
    (select project_id from v1_ranked_targets),
    (select building_scope_id from v1_ranked_targets),
    'Smart Damper', 18
  )$$,
  '42501', 'V1_MATERIAL_REQUEST_CANDIDATE_SEARCH_DENIED',
  'An inactive or unknown actor cannot search project materials'
);

set local role postgres;
select ok(
  position(
    '''request_source_kind'', request_line.source_kind'
    in pg_get_functiondef(
      'public.v1_arrangement_projection_before_phase3(uuid)'::regprocedure
    )
  ) > 0
  and position(
    '''source_boq_group_name'', source_group.worksheet_title'
    in pg_get_functiondef(
      'public.v1_arrangement_projection_before_phase3(uuid)'::regprocedure
    )
  ) > 0,
  'Wrapped arrangement projection retains immutable request BOQ correlation'
);

select ok(
  to_regprocedure(
    'public.v1_search_material_request_inventory_items(uuid,text,integer)'
  ) is not null,
  'Legacy inventory-only search remains available for older clients'
);

select * from finish();
rollback;
