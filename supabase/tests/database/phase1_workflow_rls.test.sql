begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(24);

insert into public.projects (id, data)
values (
  '__batch8_project__',
  '{
    "id":"__batch8_project__",
    "name":"Batch 8 RLS Project",
    "lifecycleStatus":"planning",
    "awaitingApproval":true,
    "assignedEngineerId":"usr-batch8-engineer",
    "designEngineerUserIds":["usr-batch8-engineer"]
  }'::jsonb
);

insert into public.projects (id, data)
values (
  '__batch8_without_plan__',
  '{
    "id":"__batch8_without_plan__",
    "name":"No Plan Project",
    "lifecycleStatus":"planning",
    "assignedEngineerId":"usr-batch8-engineer",
    "designEngineerUserIds":["usr-batch8-engineer"]
  }'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000081","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-batch8-engineer","caps":[]}}',
  true
);

select lives_ok(
  $$insert into public."materialPlans" (id, data)
    values (
      '__batch8_plan__',
      '{
        "id":"__batch8_plan__",
        "projectId":"__batch8_project__",
        "status":"Submitted",
        "version":1,
        "submittedAt":"2026-07-24T04:30:00Z",
        "currentOwnerRole":"procurement",
        "updatedByUserId":"usr-batch8-engineer",
        "items":[{
          "id":"line-1",
          "materialId":"mat-001",
          "description":"Copper Pipe",
          "size":"22 mm",
          "modelSerial":"CP-22",
          "makeOrigin":"Yorks / UAE",
          "quantity":12,
          "unitSymbol":"m",
          "note":"Level 1",
          "buildingId":"project-wide",
          "isCustom":false,
          "status":"Pending",
          "proposedSource":"notReviewed"
        }],
        "versions":[{
          "version":1,
          "items":[{
            "id":"line-1",
            "description":"Copper Pipe",
            "size":"22 mm",
            "modelSerial":"CP-22",
            "makeOrigin":"Yorks / UAE",
            "quantity":12,
            "unitSymbol":"m",
            "note":"Level 1",
            "buildingId":"project-wide",
            "isCustom":false,
            "status":"Pending",
            "proposedSource":"notReviewed"
          }],
          "createdAt":"2026-07-24T04:30:00Z",
          "createdByUserId":"usr-batch8-engineer",
          "createdByName":"Batch 8 Engineer",
          "createdByRole":"Engineer"
        }],
        "activity":[{
          "action":"Plan submitted",
          "detail":"Version 1",
          "actorUserId":"usr-batch8-engineer",
          "actorName":"Batch 8 Engineer",
          "actorRole":"Engineer",
          "timestamp":"2026-07-24T04:30:00Z"
        }],
        "comments":[]
      }'::jsonb
    )$$,
  'Engineer can submit an assigned-project Phase 1 plan'
);

select is(
  (select count(*) from public.phase1_plans
    where legacy_id = '__batch8_plan__'),
  1::bigint,
  'Submitted snapshot creates one normalized plan'
);

select is(
  (select count(*)
   from public.phase1_plan_versions version
   join public.phase1_plans plan on plan.id = version.plan_id
   where plan.legacy_id = '__batch8_plan__'),
  1::bigint,
  'Submitted snapshot creates one immutable version'
);

select is(
  (select count(*)
   from public.phase1_plan_lines line
   join public.phase1_plan_versions version on version.id = line.version_id
   join public.phase1_plans plan on plan.id = version.plan_id
   where plan.legacy_id = '__batch8_plan__'),
  1::bigint,
  'Submitted snapshot creates one normalized line'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000082","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-batch8-procurement","caps":["goods"]}}',
  true
);

select lives_ok(
  $$update public."materialPlans"
    set data = jsonb_set(
      jsonb_set(
        jsonb_set(
          jsonb_set(data, '{status}', '"Under Procurement Review"'),
          '{items,0,proposedSource}',
          '"warehouse"'
        ),
        '{items,0,onHandQtySnapshot}',
        '30'
      ),
      '{items,0,availableQtySnapshot}',
      '24'
    )
    where id = '__batch8_plan__'$$,
  'Procurement can record advisory source and availability'
);

select is(
  (
    select line.proposed_source
    from public.phase1_plan_lines line
    join public.phase1_plan_versions version on version.id = line.version_id
    join public.phase1_plans plan on plan.id = version.plan_id
    where plan.legacy_id = '__batch8_plan__'
  ),
  'warehouse',
  'Advisory source is projected to the normalized line'
);

select throws_ok(
  $$update public."materialPlans"
    set data = jsonb_set(data, '{items,0,reservedQty}', '12')
    where id = '__batch8_plan__'$$,
  '22023',
  'Phase 1 review cannot reserve stock'
);

select lives_ok(
  $$update public."materialPlans"
    set data = jsonb_set(
      data,
      '{comments}',
      '[{
        "id":"comment-1",
        "authorUserId":"usr-batch8-procurement",
        "authorName":"Batch 8 Procurement",
        "authorRole":"Procurement",
        "text":"Use warehouse stock first.",
        "timestamp":"2026-07-24T04:35:00Z",
        "lineItemId":"line-1"
      }]'::jsonb
    )
    where id = '__batch8_plan__'$$,
  'Procurement can add a line-level comment'
);

select is(
  (
    select comment.legacy_line_id
    from public.phase1_plan_comments comment
    join public.phase1_plans plan on plan.id = comment.plan_id
    where plan.legacy_id = '__batch8_plan__'
  ),
  'line-1',
  'Line comment retains its source line'
);

select lives_ok(
  $$update public."materialPlans"
    set data = jsonb_set(
      jsonb_set(data, '{status}', '"Ready for approval"'),
      '{currentOwnerRole}',
      '"engineer"'
    )
    where id = '__batch8_plan__'$$,
  'Procurement can send a fully reviewed plan for approval'
);

select throws_ok(
  $$update public."materialPlans"
    set data = jsonb_set(data, '{status}', '"Approved"')
    where id = '__batch8_plan__'$$,
  '42501',
  'Procurement cannot approve the plan'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000081","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-batch8-engineer","caps":[]}}',
  true
);

select lives_ok(
  $$update public."materialPlans"
    set data = jsonb_set(
      jsonb_set(
        jsonb_set(data, '{status}', '"Approved"'),
        '{approvedAt}',
        '"2026-07-24T04:40:00Z"'
      ),
      '{currentOwnerRole}',
      '"none"'
    )
    where id = '__batch8_plan__'$$,
  'Engineer can give final approval'
);

select is(
  (select data ->> 'lifecycleStatus'
   from public.projects
   where id = '__batch8_project__'),
  'active',
  'Final approval activates the project in the same transaction'
);

select is(
  (select data -> 'phase' ->> 'state'
   from public.projects
   where id = '__batch8_project__'),
  'Active',
  'Atomic activation records the active project phase'
);

select is(
  (
    select version.status
    from public.phase1_plan_versions version
    join public.phase1_plans plan on plan.id = version.plan_id
    where plan.legacy_id = '__batch8_plan__'
      and version.version_no = 1
  ),
  'approved',
  'Approved normalized version is retained'
);

select throws_ok(
  $$update public."materialPlans"
    set data = jsonb_set(data, '{items,0,quantity}', '15')
    where id = '__batch8_plan__'$$,
  '42501',
  'An approved plan cannot be overwritten'
);

select lives_ok(
  $$update public.projects
    set data = jsonb_set(
      data,
      '{progressStages}',
      '[
        {"id":"cooling-load-design","label":"Cooling Load Design","weightPercent":10,"progressPercent":100},
        {"id":"material-supply","label":"Material Supply","weightPercent":50,"progressPercent":50},
        {"id":"progress-installation","label":"Progress Installation","weightPercent":30,"progressPercent":20},
        {"id":"commissioning-handover","label":"Commissioning & Handover","weightPercent":5,"progressPercent":0},
        {"id":"energizing-substation","label":"Energizing Substation","weightPercent":5,"progressPercent":0}
      ]'::jsonb
    )
    where id = '__batch8_project__'$$,
  'Engineer can record progress against the standard stage definitions'
);

select throws_ok(
  $$update public.projects
    set data = jsonb_set(
      data,
      '{progressStages,0,label}',
      '"Renamed by Engineer"'
    )
    where id = '__batch8_project__'$$,
  '42501',
  'Engineer cannot change progress stage definitions'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000082","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-batch8-procurement","caps":["goods"]}}',
  true
);

select throws_ok(
  $$update public.projects
    set data = jsonb_set(data, '{progressStages,0,progressPercent}', '90')
    where id = '__batch8_project__'$$,
  '42501',
  'Procurement has read-only project progress access'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000084","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-batch8-admin","caps":["goods"]}}',
  true
);

select lives_ok(
  $$update public.projects
    set data = jsonb_set(
      data,
      '{progressStages,0,label}',
      '"Cooling Design"'
    )
    where id = '__batch8_project__'$$,
  'Admin can configure project-specific stage definitions'
);

select throws_ok(
  $$update public.projects
    set data = jsonb_set(data, '{progressStages,0,weightPercent}', '20')
    where id = '__batch8_project__'$$,
  '22023',
  'Project progress weights must remain reconciled to 100'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000081","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-batch8-engineer","caps":[]}}',
  true
);

select throws_ok(
  $$update public.projects
    set data = jsonb_set(data, '{lifecycleStatus}', '"active"')
    where id = '__batch8_without_plan__'$$,
  '55000',
  'A project cannot activate without an approved Phase 1 plan'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000083","role":"authenticated","app_metadata":{"role":"engineer","app_user_id":"usr-other-engineer","caps":[]}}',
  true
);

select is(
  (select count(*) from public.phase1_plans
   where legacy_id = '__batch8_plan__'),
  0::bigint,
  'Another Engineer cannot read the normalized plan'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000082","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-batch8-procurement","caps":["goods"]}}',
  true
);

select is(
  (select count(*) from public.phase1_plans
   where legacy_id = '__batch8_plan__'),
  1::bigint,
  'Procurement can read the normalized plan'
);

select * from finish();
rollback;
