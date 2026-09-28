-- Create exactly one controlled Company-use Material Request through the same
-- trusted save-and-submit command used by the Flutter client. This operator
-- fixture is staging-only, deterministic and safe to replay with the same
-- idempotency key. It stops at independent approval and never arranges,
-- reserves, dispatches or adjusts inventory.

begin;
set local statement_timeout = '30s';
set local lock_timeout = '5s';

do $target_guard$
begin
  if (select count(*) from auth.users) <> 7
    or exists (
      select 1
      from auth.users auth_user
      where auth_user.email not like '%@yorks.local.test'
    ) then
    raise exception
      'CONTROLLED_COMPANY_MR_REFUSES_NON_TECHNICAL_STAGING_TARGET';
  end if;
end;
$target_guard$;

create temporary table controlled_company_mr_before on commit drop as
select
  exists (
    select 1
    from public.v1_company_material_requests request_record
    where request_record.id =
      '5dc29000-0000-4000-8000-000000000001'::uuid
  ) as target_existed,
  (select count(*) from public.v1_material_requests) as project_request_count,
  (select count(*) from public.v1_company_material_requests)
    as company_request_count,
  (select count(*) from public.v1_company_material_request_lines)
    as company_line_count,
  (select count(*) from public.v1_inventory_movements)
    as inventory_movement_count,
  (select count(*) from public.v1_inventory_reservations)
    as inventory_reservation_count;
create temporary table controlled_company_mr_result (
  response jsonb not null
) on commit drop;
grant insert, select on table controlled_company_mr_result to authenticated;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', '10000000-0000-4000-8000-000000000004',
    'role', 'authenticated',
    'app_metadata', jsonb_build_object(
      'role', 'admin',
      'app_user_id', 'usr-local-admin'
    )
  )::text,
  true
);
set local role authenticated;

insert into controlled_company_mr_result (response)
select public.v1_save_and_submit_company_material_request(
  jsonb_build_object(
    'request_id', '5dc29000-0000-4000-8000-000000000001',
    'expected_version', 0,
    'category_id', '5dc10000-0000-4000-8000-000000000001',
    'responsible_unit_id', '5dc11000-0000-4000-8000-000000000001',
    'purpose', 'STAGING CONTROLLED COMPANY USE — 2026-09-29',
    'timing', 'normal',
    'scheduled_date', null,
    'delivery_collection_point',
      'Staging demonstration only — no fulfilment',
    'beneficiary_auth_user_id',
      '10000000-0000-4000-8000-000000000002',
    'authorized_receiver_auth_user_id',
      '10000000-0000-4000-8000-000000000001',
    'selected_approver_auth_user_id',
      '10000000-0000-4000-8000-000000000009',
    'lines', jsonb_build_array(jsonb_build_object(
      'id', '5dc29100-0000-4000-8000-000000000001',
      'display_order', 1,
      'item_description',
        'Controlled staging PPE sample — no stock action',
      'brand_origin', null,
      'size', 'Demonstration',
      'model', 'STAGING-CONTROL-20260929',
      'equipment_tag', 'COMPANY-MR-CONTROL',
      'requested_qty', '1',
      'unit', 'Nos'
    ))
  ),
  '5dc29200-0000-4000-8000-000000000001'::uuid
);

reset role;

do $postconditions$
declare
  v_before controlled_company_mr_before%rowtype;
  v_expected_delta integer;
begin
  select * into v_before from controlled_company_mr_before;
  v_expected_delta := case when v_before.target_existed then 0 else 1 end;

  if (select count(*) from public.v1_material_requests)
      <> v_before.project_request_count
    or (select count(*) from public.v1_company_material_requests)
      <> v_before.company_request_count + v_expected_delta
    or (select count(*) from public.v1_company_material_request_lines)
      <> v_before.company_line_count + v_expected_delta
    or (select count(*) from public.v1_inventory_movements)
      <> v_before.inventory_movement_count
    or (select count(*) from public.v1_inventory_reservations)
      <> v_before.inventory_reservation_count then
    raise exception 'CONTROLLED_COMPANY_MR_DATA_PRESERVATION_FAILED';
  end if;

  if not exists (
    select 1
    from public.v1_company_material_requests request_record
    where request_record.id =
        '5dc29000-0000-4000-8000-000000000001'::uuid
      and request_record.state = 'awaiting_company_approval'
      and request_record.request_number is not null
      and request_record.approver_auth_user_id =
        '10000000-0000-4000-8000-000000000009'::uuid
  ) or (select count(*)
        from public.v1_company_material_request_lines line_record
        where line_record.request_id =
          '5dc29000-0000-4000-8000-000000000001'::uuid) <> 1
    or (select count(*)
        from public.v1_company_material_request_events event_record
        where event_record.request_id =
          '5dc29000-0000-4000-8000-000000000001'::uuid
          and event_record.event_type = 'company_request_submitted') <> 1
    or (select count(*)
        from public.v1_notifications notification
        where notification.entity_type = 'company_material_request'
          and notification.entity_id =
            '5dc29000-0000-4000-8000-000000000001'::uuid
          and notification.event_code =
            'company_material_request_approval_requested'
          and notification.recipient_auth_user_id =
            '10000000-0000-4000-8000-000000000009'::uuid) <> 1
    or exists (
      select 1
      from public.v1_company_material_supply_plans supply_plan
      where supply_plan.request_id =
        '5dc29000-0000-4000-8000-000000000001'::uuid
    )
    or exists (
      select 1
      from public.v1_company_material_dispatches dispatch
      where dispatch.request_id =
        '5dc29000-0000-4000-8000-000000000001'::uuid
    ) then
    raise exception 'CONTROLLED_COMPANY_MR_WORKFLOW_POSTCONDITION_FAILED';
  end if;
end;
$postconditions$;

select
  response ->> 'request_number' as request_number,
  response ->> 'state' as state,
  response ->> 'purpose' as purpose,
  jsonb_array_length(response -> 'lines') as line_count,
  response ->> 'approver_display_name' as approver_display_name
from controlled_company_mr_result;

commit;
