-- Yorks R35 Material Request lifecycle hardening.
--
-- The existing commands already own authorization, reservations, stock and
-- audit history.  This migration closes the remaining lifecycle gaps without
-- rewriting historical workflow rows or granting table access to clients.

begin;

-- Arrangement data is still operational by default.  Commercial values remain
-- in the protected material-request commercial table and are only projected to
-- actors with the existing capability.
alter table public.v1_procurement_arrangements
  add column if not exists procurement_note text;
alter table public.v1_procurement_arrangement_lines
  add column if not exists unit_cost numeric(18, 4)
    check (unit_cost is null or unit_cost >= 0);

-- A Cannot Provide Now line has no source, supplier, inventory item or
-- reservation.  Existing full/partial rows retain their original constraint.
alter table public.v1_procurement_arrangement_lines
  alter column source_kind drop not null;
alter table public.v1_procurement_arrangement_lines
  drop constraint if exists v1_procurement_arrangement_lines_source_kind_check;
alter table public.v1_procurement_arrangement_lines
  add constraint v1_procurement_arrangement_lines_source_kind_check
  check (source_kind is null or source_kind in ('warehouse', 'external_supplier'));

-- Delivery Note / Dispatch Reference is an external operational reference and
-- is deliberately separate from the Yorks-generated internal dispatch number.
alter table public.v1_material_dispatches
  add column if not exists delivery_reference text;
update public.v1_material_dispatches
   set delivery_reference = dispatch_number
 where delivery_reference is null or btrim(delivery_reference) = '';
alter table public.v1_material_dispatches
  alter column delivery_reference set not null;
alter table public.v1_material_dispatches
  drop constraint if exists v1_material_dispatches_delivery_reference_nonempty;
alter table public.v1_material_dispatches
  add constraint v1_material_dispatches_delivery_reference_nonempty
  check (btrim(delivery_reference) <> '');

-- Project-engineer names used in the official operational MR are frozen at
-- submission.  Membership changes therefore cannot change old document bytes.
alter table public.v1_material_requests
  add column if not exists project_engineer_snapshot jsonb not null default '[]'::jsonb;
alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_project_engineer_snapshot_array;
alter table public.v1_material_requests
  add constraint v1_material_requests_project_engineer_snapshot_array
  check (jsonb_typeof(project_engineer_snapshot) = 'array');

create or replace function public.v1_snapshot_material_request_engineers()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state = 'draft' and new.state = 'submitted' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'display_name', public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      )
    ) order by lower(profile.display_name), profile.auth_user_id), '[]'::jsonb)
      into new.project_engineer_snapshot
    from public.v1_project_members member
    join public.v1_profiles profile
      on profile.auth_user_id = member.member_auth_user_id
    where member.project_id = new.project_id
      and member.project_role = 'project_engineer'
      and member.effective_from <= clock_timestamp()
      and (member.effective_to is null or member.effective_to > clock_timestamp())
      and profile.is_active;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_snapshot_material_request_engineers
  on public.v1_material_requests;
create trigger v1_snapshot_material_request_engineers
  before update of state on public.v1_material_requests
  for each row execute function public.v1_snapshot_material_request_engineers();

-- Preserve the names visible on documents created before this migration. This
-- is a one-time compatibility snapshot, not a live membership lookup.
update public.v1_material_requests request_record
   set project_engineer_snapshot = coalesce((
     select jsonb_agg(jsonb_build_object(
       'display_name', public.v1_safe_profile_display_name(
         profile.display_name, profile.auth_user_id
       )
     ) order by lower(profile.display_name), profile.auth_user_id)
     from public.v1_project_members member
     join public.v1_profiles profile
       on profile.auth_user_id = member.member_auth_user_id
     where member.project_id = request_record.project_id
       and member.project_role = 'project_engineer'
       and member.effective_from <= clock_timestamp()
       and (member.effective_to is null or member.effective_to > clock_timestamp())
       and profile.is_active
   ), '[]'::jsonb)
 where request_record.state <> 'draft'
   and request_record.project_engineer_snapshot = '[]'::jsonb;

-- Atomic save-and-submit eliminates the stale-version window between the
-- former two browser calls.  The outer idempotency record is completed only
-- after both draft replacement and submission have committed.
create or replace function public.v1_save_and_submit_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_existing_response jsonb;
  v_saved jsonb;
  v_response jsonb;
begin
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  if v_request_id is null then
    raise exception 'V1_MATERIAL_REQUEST_DRAFT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  -- A retry after a lost response must return the one submitted request,
  -- rather than attempting to edit its now-immutable draft.
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_and_submit_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if exists (
    select 1 from jsonb_array_elements(coalesce(p_payload -> 'lines', '[]'::jsonb)) value
    where value ->> 'source_kind' = 'boq'
    group by nullif(btrim(coalesce(value ->> 'source_boq_row_id', '')), '')
    having count(*) > 1
  ) then
    raise exception 'V1_MATERIAL_REQUEST_BOQ_SOURCE_DUPLICATE' using errcode = '22023';
  end if;
  v_saved := public.v1_save_material_request_draft(p_payload);
  v_response := public.v1_submit_material_request(
    jsonb_build_object(
      'request_id', v_request_id,
      'expected_version', (v_saved ->> 'record_version')::integer
    ),
    p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_and_submit_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Draft creation is meaningful only for Active projects; the old Draft option
-- could be selected but was guaranteed to fail at Submit.
do $project_picker$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_list_material_request_projects()'::regprocedure
  );
  if position($find$project.state in ('draft', 'active')$find$ in v_definition) = 0 then
    raise exception 'V1_R35_PROJECT_PICKER_DEFINITION_UNEXPECTED';
  end if;
  execute replace(
    v_definition,
    $find$project.state in ('draft', 'active')$find$,
    $replacement$project.state = 'active'$replacement$
  );
end;
$project_picker$;

-- Retain the existing pessimistic locks and reservation maths, but make
-- unavailable rows source-free and include an optional protected unit cost and
-- overall Procurement note in the persisted arrangement.
do $arrangement_save$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_arrangement(jsonb,uuid)'::regprocedure
  );
  if position($find$'expected_arrangement_version', 'lines'$find$ in v_definition) = 0
    or position($find$v_reason text;$find$ in v_definition) = 0
    or position($find$v_source_kind not in ('warehouse', 'external_supplier')$find$ in v_definition) = 0 then
    raise exception 'V1_R35_ARRANGEMENT_DEFINITION_UNEXPECTED';
  end if;
  v_definition := replace(
    v_definition,
    $find$'expected_arrangement_version', 'lines'$find$,
    $replacement$'expected_arrangement_version', 'procurement_note', 'lines'$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_reason text;$find$,
    $replacement$v_reason text;
  v_procurement_note text;
  v_unit_cost numeric(18, 4);$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);$find$,
    $replacement$v_procurement_note := nullif(btrim(coalesce(p_payload ->> 'procurement_note', '')), '');
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$'inventory_item_id', 'decision', 'arranged_qty', 'reason'$find$,
    $replacement$'inventory_item_id', 'decision', 'arranged_qty', 'reason', 'unit_cost'$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_reason := nullif(btrim(coalesce(v_line ->> 'reason', '')), '');$find$,
    $replacement$v_reason := nullif(btrim(coalesce(v_line ->> 'reason', '')), '');
    v_unit_cost := nullif(btrim(coalesce(v_line ->> 'unit_cost', '')), '')::numeric(18, 4);$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$or v_arranged_qty is null or v_arranged_qty < 0$find$,
    $replacement$or v_arranged_qty is null or v_arranged_qty < 0
      or (v_unit_cost is not null and v_unit_cost < 0)$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_source_kind not in ('warehouse', 'external_supplier')$find$,
    $replacement$(v_decision <> 'unavailable' and v_source_kind not in ('warehouse', 'external_supplier'))$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$(v_source_kind = 'warehouse' and v_inventory_item_id is null)$find$,
    $replacement$(v_decision <> 'unavailable' and v_source_kind = 'warehouse' and v_inventory_item_id is null)$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$(v_source_kind = 'warehouse' and v_external_supplier is not null)$find$,
    $replacement$(v_decision <> 'unavailable' and v_source_kind = 'warehouse' and v_external_supplier is not null)$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$(v_source_kind = 'external_supplier' and (
        v_external_supplier is null or v_inventory_item_id is not null
      ))$find$,
    $replacement$(v_decision <> 'unavailable' and v_source_kind = 'external_supplier' and (
        v_external_supplier is null or v_inventory_item_id is not null
      ))$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$where value ->> 'source_kind' = 'warehouse'
    order by 1$find$,
    $replacement$where value ->> 'source_kind' = 'warehouse'
        and value ->> 'decision' <> 'unavailable'
    order by 1$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$set source_kind = line_json.value ->> 'source_kind',$find$,
    $replacement$set source_kind = case when line_json.value ->> 'decision' = 'unavailable' then null
           else line_json.value ->> 'source_kind' end,$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$external_supplier = nullif(btrim(coalesce(
           line_json.value ->> 'external_supplier', ''
         )), ''),$find$,
    $replacement$external_supplier = case when line_json.value ->> 'decision' = 'unavailable' then null
           else nullif(btrim(coalesce(line_json.value ->> 'external_supplier', '')), '') end,$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$inventory_item_id = nullif(btrim(coalesce(
           line_json.value ->> 'inventory_item_id', ''
         )), '')::uuid,$find$,
    $replacement$inventory_item_id = case when line_json.value ->> 'decision' = 'unavailable' then null
           else nullif(btrim(coalesce(line_json.value ->> 'inventory_item_id', '')), '')::uuid end,$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$reason = nullif(btrim(coalesce(line_json.value ->> 'reason', '')), ''),$find$,
    $replacement$reason = nullif(btrim(coalesce(line_json.value ->> 'reason', '')), ''),
         unit_cost = nullif(btrim(coalesce(line_json.value ->> 'unit_cost', '')), '')::numeric(18, 4),$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$update public.v1_procurement_arrangements
     set status = 'awaiting_approval',$find$,
    $replacement$update public.v1_procurement_arrangements
     set procurement_note = v_procurement_note,
         status = 'awaiting_approval',$replacement$
  );
  execute v_definition;
end;
$arrangement_save$;

-- Commercial data is accepted and stored by the trusted Procurement command,
-- but the arrangement projection keeps it out of Project/Site Engineer JSON.
do $arrangement_projection$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_arrangement_projection(uuid)'::regprocedure
  );
  if position($find$declare
  v_result jsonb;$find$ in v_definition) = 0
    or position($find$'reason', arrangement_line.reason,$find$ in v_definition) = 0 then
    raise exception 'V1_R35_ARRANGEMENT_PROJECTION_UNEXPECTED';
  end if;
  v_definition := replace(
    v_definition,
    $find$declare
  v_result jsonb;$find$,
    $replacement$declare
  v_role text := public.v1_current_role();
  v_result jsonb;$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$'decision', ($find$,
    $replacement$'procurement_note', case when v_role in ('procurement', 'admin')
          then arrangement.procurement_note else null end,
        'decision', ($replacement$
  );
  v_definition := replace(
    v_definition,
    $find$'reason', arrangement_line.reason,$find$,
    $replacement$'reason', arrangement_line.reason,
            'unit_cost', case when v_role in ('procurement', 'admin')
              and arrangement_line.unit_cost is not null
              then arrangement_line.unit_cost::text else null end,$replacement$
  );
  execute v_definition;
end;
$arrangement_projection$;

-- An all-unavailable arrangement is acknowledged and closes the request; it
-- cannot appear as an Approved request with no dispatchable lines.
do $arrangement_decision$
declare
  v_definition text;
  v_old text;
  v_new text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_decide_arrangement(jsonb,uuid)'::regprocedure
  );
  v_old := $old$if v_decision = 'approved' then
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select request_line_id from public.v1_procurement_arrangement_lines
      where arrangement_id = v_arrangement.id
    );
    insert into public.v1_material_request_line_approvals (
      request_line_id, arrangement_line_id, arrangement_id, approved_qty,
      approved_by_auth_user_id
    )
    select arrangement_line.request_line_id, arrangement_line.id,
      v_arrangement.id, arrangement_line.arranged_qty, v_actor
    from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id;
    update public.v1_procurement_arrangements
       set status = 'approved', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'approved', current_action_owner_role = 'procurement',
           current_action_code = 'dispatch_required',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  else$old$;
  v_new := $new$if v_decision = 'approved' and not exists (
    select 1 from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id
      and arrangement_line.decision in ('full', 'partial')
      and arrangement_line.arranged_qty > 0
  ) then
    update public.v1_inventory_reservations
       set state = 'released', released_at = clock_timestamp(),
           released_by_auth_user_id = v_actor,
           release_reason = 'all_items_unavailable', updated_at = clock_timestamp()
     where request_id = v_request.id and state in ('active', 'partially_consumed');
    update public.v1_procurement_arrangements
       set status = 'approved', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'cancelled', current_action_owner_role = 'none',
           current_action_code = 'unavailable_closed',
           cancelled_at = clock_timestamp(), cancelled_by_auth_user_id = v_actor,
           cancellation_reason = 'All requested items cannot be provided now',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  elsif v_decision = 'approved' then
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select request_line_id from public.v1_procurement_arrangement_lines
      where arrangement_id = v_arrangement.id
    );
    insert into public.v1_material_request_line_approvals (
      request_line_id, arrangement_line_id, arrangement_id, approved_qty,
      approved_by_auth_user_id
    )
    select arrangement_line.request_line_id, arrangement_line.id,
      v_arrangement.id, arrangement_line.arranged_qty, v_actor
    from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id;
    update public.v1_procurement_arrangements
       set status = 'approved', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'approved', current_action_owner_role = 'procurement',
           current_action_code = 'dispatch_required',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  else$new$;
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_R35_DECIDE_DEFINITION_UNEXPECTED';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$arrangement_decision$;

-- Delivery reference is now part of the same trusted command.  Function-body
-- patching preserves the established row locking and stock transaction while
-- enforcing the added input across every client.
do $dispatch_command$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_dispatch_materials(jsonb,uuid)'::regprocedure
  );
  if position($find$v_vehicle_reference text;$find$ in v_definition) = 0
    or position($find$'dispatch_date', 'driver_name',$find$ in v_definition) = 0 then
    raise exception 'V1_R35_DISPATCH_DEFINITION_UNEXPECTED';
  end if;
  v_definition := replace(
    v_definition,
    $find$v_vehicle_reference text;$find$,
    $replacement$v_vehicle_reference text;
  v_delivery_reference text;$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$'request_id', 'expected_version', 'dispatch_date', 'driver_name',$find$,
    $replacement$'request_id', 'expected_version', 'dispatch_date', 'delivery_reference', 'driver_name',$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_dispatch_date := nullif(p_payload ->> 'dispatch_date', '')::date;$find$,
    $replacement$v_dispatch_date := nullif(p_payload ->> 'dispatch_date', '')::date;
  v_delivery_reference := nullif(btrim(coalesce(p_payload ->> 'delivery_reference', '')), '');$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$or v_dispatch_date is null or jsonb_typeof(v_lines) <> 'array' then$find$,
    $replacement$or v_dispatch_date is null or v_delivery_reference is null or jsonb_typeof(v_lines) <> 'array' then$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$request_id, project_id, dispatch_number, dispatch_date, driver_name,$find$,
    $replacement$request_id, project_id, dispatch_number, dispatch_date, delivery_reference, driver_name,$replacement$
  );
  v_definition := replace(
    v_definition,
    $find$v_request.id, v_request.project_id, v_dispatch_number, v_dispatch_date,
    v_driver_name,$find$,
    $replacement$v_request.id, v_request.project_id, v_dispatch_number, v_dispatch_date,
    v_delivery_reference, v_driver_name,$replacement$
  );
  execute v_definition;
end;
$dispatch_command$;

-- Delivery Order PDFs use the operational header fields from the same
-- workspace projection as their preview. The client never guesses a project
-- reference, receiving party, material context or delivery address.
do $returns_documents_projection$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_returns_documents_workspace_projection(uuid)'::regprocedure
  );
  if position($find$'project_name', project.name,$find$ in v_definition) = 0
    or position($find$'scope_name', scope.name,$find$ in v_definition) = 0 then
    raise exception 'V1_R35_RETURNS_DOCUMENTS_PROJECTION_UNEXPECTED';
  end if;
  v_definition := replace(
    v_definition,
    $find$'project_name', project.name,
    'scope_name', scope.name,$find$,
    $replacement$'project_name', project.name,
    'project_ref', project.project_ref,
    'main_contractor_name', (
      select party.party_name from public.v1_project_parties party
      where party.project_id = project.id and party.party_kind = 'main_contractor'
      order by party.party_order, party.id limit 1
    ),
    'delivery_address', scope.delivery_address,
    'material_context', request_record.title,
    'scope_name', scope.name,$replacement$
  );
  execute v_definition;
end;
$returns_documents_projection$;

-- Official MR output is one cost-free operational variant.  It uses the
-- submission snapshot for Project Engineers and one cumulative status per
-- request line, so preview/print/download cannot vary by viewer or receipt
-- history ordering.
create or replace function public.v1_material_request_document_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DOCUMENT_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'scope_id', request_record.scope_id,
    'scope_name', scope.name,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'request_number', request_record.request_number,
    'title', request_record.title,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_note', request_record.delivery_note,
    'requester_display_name', request_record.requester_display_name,
    'requester_project_role', request_record.requester_project_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(public.v1_material_request_line_projection(line_record.id, false)
        order by line_record.display_order)
      from public.v1_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_request
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return jsonb_build_object(
    'request', v_request,
    'project_engineers', (
      select request_record.project_engineer_snapshot
      from public.v1_material_requests request_record where request_record.id = p_request_id
    ),
    'approval', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id),
        'role', decision.decided_by_role,
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', decision.created_at
      )
      from public.v1_arrangement_decisions decision
      join public.v1_procurement_arrangements arrangement on arrangement.id = decision.arrangement_id
      join public.v1_profiles profile on profile.auth_user_id = decision.decided_by_auth_user_id
      where decision.request_id = p_request_id and decision.decision = 'approved'
      order by decision.created_at desc limit 1
    ),
    'dispatch', (
      select jsonb_build_object(
        'display_name', public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id),
        'role', dispatch.dispatched_by_role,
        'reference', dispatch.delivery_reference,
        'acted_at', dispatch.dispatched_at
      )
      from public.v1_material_dispatches dispatch
      join public.v1_profiles profile on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = p_request_id
      -- Prefer the latest dispatch with a completed receipt when one exists;
      -- an unrelated pending replacement must not overwrite the final
      -- document's delivery reference or receipt context.
      order by case when dispatch.state in ('partially_received', 'received')
          then 0 else 1 end,
        dispatch.dispatched_at desc, dispatch.id desc limit 1
    ),
    'receipt_statuses', coalesce((
      with line_totals as (
        select request_line.id as request_line_id,
          coalesce(approval.approved_qty, 0) as approved_qty,
          coalesce(sum(review_line.good_qty) filter (where review.state = 'confirmed'), 0) as good_qty,
          coalesce(sum(review_line.exception_qty) filter (where review.state = 'confirmed' and review_line.outcome = 'missing'), 0) as missing_qty,
          coalesce(sum(review_line.exception_qty) filter (where review.state = 'confirmed' and review_line.outcome = 'damaged'), 0) as damaged_qty,
          coalesce(sum(dispatch_line.dispatched_qty) filter (where dispatch.state = 'receipt_pending'), 0) as in_transit_qty
        from public.v1_material_request_lines request_line
        left join public.v1_material_request_line_approvals approval on approval.request_line_id = request_line.id
        left join public.v1_material_dispatch_lines dispatch_line on dispatch_line.request_line_id = request_line.id
        left join public.v1_material_dispatches dispatch on dispatch.id = dispatch_line.dispatch_id
        left join public.v1_receipt_review_lines review_line on review_line.dispatch_line_id = dispatch_line.id
        left join public.v1_receipt_reviews review on review.id = review_line.receipt_review_id
        where request_line.request_id = p_request_id
        group by request_line.id, approval.approved_qty
      )
      select jsonb_agg(jsonb_build_object(
        'request_line_id', request_line_id,
        'status', case
          when approved_qty = 0 then 'Cannot Provide Now'
          when good_qty >= approved_qty and in_transit_qty = 0 then 'Received'
          when in_transit_qty > 0 and good_qty > 0 then 'In Transit / Partially Received'
          when in_transit_qty > 0 then 'In Transit'
          when good_qty > 0 and missing_qty > 0 and damaged_qty > 0 then 'Mixed Issues'
          when good_qty > 0 and missing_qty > 0 then 'Partial / Missing'
          when good_qty > 0 and damaged_qty > 0 then 'Partial / Damaged'
          when missing_qty > 0 and damaged_qty > 0 then 'Mixed Issues'
          when missing_qty > 0 then 'Missing'
          when damaged_qty > 0 then 'Damaged'
          else 'Pending'
        end
      ) order by request_line_id)
      from line_totals
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_snapshot_material_request_engineers() from public, anon, authenticated;
revoke all on function public.v1_save_and_submit_material_request(jsonb,uuid) from public, anon;
grant execute on function public.v1_save_and_submit_material_request(jsonb,uuid) to authenticated;

commit;
