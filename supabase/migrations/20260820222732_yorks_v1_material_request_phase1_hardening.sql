-- Yorks V1 Material Request Phase 1 hardening.
--
-- This migration is additive and data preserving. It narrows Draft reads,
-- keeps an all-unavailable arrangement editable until an authorised actor
-- cancels the request, and records mixed Missing/Damaged receipt facts without
-- weakening the existing good + exception = dispatched invariant.

alter table public.v1_receipt_review_lines
  add column if not exists missing_qty numeric(18, 4),
  add column if not exists damaged_qty numeric(18, 4);

update public.v1_receipt_review_lines
set missing_qty = case when outcome = 'missing' then exception_qty else 0 end,
    damaged_qty = case when outcome = 'damaged' then exception_qty else 0 end
where missing_qty is null or damaged_qty is null;

alter table public.v1_receipt_review_lines
  alter column missing_qty set default 0,
  alter column missing_qty set not null,
  alter column damaged_qty set default 0,
  alter column damaged_qty set not null;

alter table public.v1_receipt_review_lines
  drop constraint if exists v1_receipt_review_lines_outcome_check,
  drop constraint if exists v1_receipt_review_lines_check,
  drop constraint if exists v1_receipt_review_lines_check1;

alter table public.v1_receipt_review_lines
  add constraint v1_receipt_review_lines_outcome_check check (
    outcome in ('received', 'missing', 'damaged', 'mixed')
  ),
  add constraint v1_receipt_review_lines_missing_qty_check check (
    missing_qty >= 0
  ),
  add constraint v1_receipt_review_lines_damaged_qty_check check (
    damaged_qty >= 0
  ),
  add constraint v1_receipt_review_lines_quantity_reconciliation_check check (
    good_qty + missing_qty + damaged_qty = dispatched_qty_snapshot
    and exception_qty = missing_qty + damaged_qty
  ),
  add constraint v1_receipt_review_lines_outcome_quantities_check check (
    (outcome = 'received'
      and good_qty = dispatched_qty_snapshot
      and missing_qty = 0 and damaged_qty = 0
      and exception_qty = 0 and note is null)
    or (outcome = 'missing'
      and good_qty < dispatched_qty_snapshot
      and missing_qty > 0 and damaged_qty = 0
      and note is not null and btrim(note) <> '')
    or (outcome = 'damaged'
      and good_qty < dispatched_qty_snapshot
      and missing_qty = 0 and damaged_qty > 0
      and note is not null and btrim(note) <> '')
    or (outcome = 'mixed'
      and good_qty < dispatched_qty_snapshot
      and missing_qty > 0 and damaged_qty > 0
      and note is not null and btrim(note) <> '')
  );

comment on column public.v1_receipt_review_lines.missing_qty is
  'Immutable physical quantity missing from the confirmed dispatch receipt.';
comment on column public.v1_receipt_review_lines.damaged_qty is
  'Immutable physical quantity received damaged in the confirmed dispatch receipt.';

-- A normal working arrangement has not been saved yet. The approved
-- all-unavailable policy introduces one truthful exception: it is a saved
-- snapshot that deliberately remains working so Procurement can revise it.
-- Actor and time must therefore remain either both absent or both present.
alter table public.v1_procurement_arrangements
  drop constraint if exists v1_procurement_arrangements_check;
alter table public.v1_procurement_arrangements
  add constraint v1_procurement_arrangements_check check (
    (status = 'working' and (
      (saved_at is null and saved_by_auth_user_id is null)
      or (saved_at is not null and saved_by_auth_user_id is not null)
    ))
    or (status <> 'working'
      and saved_at is not null and saved_by_auth_user_id is not null)
  );

create or replace function public.v1_material_request_participant(
  p_request_id uuid,
  p_auth_user_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text;
begin
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;

  if not found or p_auth_user_id is null or not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = p_auth_user_id and profile.is_active
  ) then
    return false;
  end if;

  select coalesce(user_record.raw_app_meta_data ->> 'role', '')
    into v_exact_role
  from auth.users user_record
  where user_record.id = p_auth_user_id;

  if v_exact_role = 'admin' then
    return true;
  end if;

  -- A server Draft is private working input. Project membership and global
  -- Engineering authority begin only after explicit submission.
  if v_request.state = 'draft' then
    return v_request.created_by_auth_user_id = p_auth_user_id;
  end if;

  if v_exact_role in (
    'senior_mechanical_engineer', 'project_manager',
    'workshop_in_charge', 'document_controller'
  ) then
    return true;
  end if;
  if v_exact_role in ('project_engineer', 'site_engineer') then
    return exists (
      select 1 from public.v1_project_members member
      where member.project_id = v_request.project_id
        and member.member_auth_user_id = p_auth_user_id
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null
          or member.effective_to > clock_timestamp())
    );
  end if;
  if v_exact_role = 'procurement' then
    return v_request.state in (
      'submitted', 'approved_for_arrangement', 'arranging',
      'awaiting_approval', 'approved',
      'partially_dispatched', 'dispatched', 'partially_received', 'received',
      'closed', 'cancelled'
    );
  end if;
  return false;
end;
$$;

revoke all on function public.v1_material_request_participant(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_material_request_participant(uuid, uuid)
  to service_role;

create or replace function public.v1_save_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_request public.v1_material_requests%rowtype;
  v_arrangement public.v1_procurement_arrangements%rowtype;
  v_approval public.v1_material_request_decisions%rowtype;
  v_response jsonb;
  v_before jsonb;
  v_positive_count integer;
begin
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  if v_request_id is null then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_approval
  from public.v1_material_request_decisions decision
  where decision.request_id = v_request_id and decision.decision = 'approved'
  order by decision.created_at desc limit 1;
  if not found then
    return public.v1_save_arrangement_legacy_before_preapproval(
      p_payload, p_idempotency_key
    );
  end if;

  v_response := public.v1_save_arrangement_legacy_before_preapproval(
    p_payload, p_idempotency_key
  );
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id
  for update;

  if v_request.state in (
    'approved', 'closed', 'cancelled', 'partially_dispatched',
    'dispatched', 'partially_received', 'received'
  ) then
    return public.v1_arrangement_projection(v_request_id);
  end if;

  -- A retry of an already-finalised all-unavailable save returns the same
  -- authoritative editable workspace. The legacy idempotency command has
  -- already checked that the key and payload match.
  if v_request.state = 'arranging' then
    select * into v_arrangement
    from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = v_request_id and arrangement.is_current
      and arrangement.status = 'working' and arrangement.saved_at is not null
    order by arrangement.arrangement_version desc limit 1
    for update;
    if found and not exists (
      select 1
      from public.v1_procurement_arrangement_lines arrangement_line
      where arrangement_line.arrangement_id = v_arrangement.id
        and arrangement_line.decision in ('full', 'partial')
        and arrangement_line.arranged_qty > 0
    ) then
      return public.v1_arrangement_projection(v_request_id);
    end if;
  end if;

  if v_request.state <> 'awaiting_approval' then
    raise exception 'V1_PREAPPROVED_ARRANGEMENT_FINALIZE_STATE_INVALID'
      using errcode = '22023';
  end if;

  select * into v_arrangement
  from public.v1_procurement_arrangements arrangement
  where arrangement.request_id = v_request_id and arrangement.is_current
    and arrangement.status = 'awaiting_approval'
  order by arrangement.arrangement_version desc limit 1
  for update;
  if not found then
    raise exception 'V1_PREAPPROVED_ARRANGEMENT_NOT_FOUND' using errcode = '22023';
  end if;

  v_before := public.v1_arrangement_projection(v_request_id);
  select count(*) into v_positive_count
  from public.v1_procurement_arrangement_lines arrangement_line
  where arrangement_line.arrangement_id = v_arrangement.id
    and arrangement_line.decision in ('full', 'partial')
    and arrangement_line.arranged_qty > 0;

  if v_positive_count = 0 then
    update public.v1_inventory_reservations
    set state = 'released', released_at = clock_timestamp(),
        released_by_auth_user_id = auth.uid(),
        release_reason = 'all_items_unavailable', updated_at = clock_timestamp()
    where request_id = v_request_id and state in ('active', 'partially_consumed');

    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select line_record.id
      from public.v1_material_request_lines line_record
      where line_record.request_id = v_request_id
    );

    update public.v1_procurement_arrangements
    set status = 'working', record_version = record_version + 1,
        updated_at = clock_timestamp()
    where id = v_arrangement.id;
    update public.v1_material_requests
    set state = 'arranging', current_action_owner_role = 'procurement',
        current_action_code = 'all_items_unavailable_review',
        record_version = record_version + 1, updated_at = clock_timestamp()
    where id = v_request_id;
  else
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select line_record.id from public.v1_material_request_lines line_record
      where line_record.request_id = v_request_id
    );
    insert into public.v1_material_request_line_approvals (
      request_line_id, arrangement_line_id, arrangement_id, approved_qty,
      approved_by_auth_user_id
    )
    select arrangement_line.request_line_id, arrangement_line.id,
      v_arrangement.id, arrangement_line.arranged_qty,
      v_approval.decided_by_auth_user_id
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
    where id = v_request_id;
  end if;

  delete from public.v1_notifications notification
  where notification.entity_type = 'procurement_arrangement'
    and notification.entity_id = v_arrangement.id
    and notification.event_code = 'arrangement_review_required';
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id,
    case when v_positive_count = 0 then 'arrangement_completed_unavailable'
      else 'arrangement_ready_for_dispatch' end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';

  perform public.v1_write_audit_event(
    case when v_positive_count = 0 then 'all_items_unavailable_saved'
      else 'preapproved_arrangement_finalized' end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'request_state', case when v_positive_count = 0 then 'arranging'
        else 'approved' end,
      'request_action', case when v_positive_count = 0
        then 'all_items_unavailable_review' else 'dispatch_required' end,
      'request_approval_id', v_approval.id,
      'approved_engineering_version', v_approval.request_record_version,
      'positive_line_count', v_positive_count
    ), null, p_idempotency_key
  );
  return public.v1_arrangement_projection(v_request_id);
end;
$$;

revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_save_arrangement(jsonb, uuid)
  to authenticated, service_role;

-- Historical requests may still reach the former second Engineering decision.
-- A legacy approval with no positive quantity follows the same editable rule;
-- it never fabricates completion or cancellation.
create or replace function public.v1_decide_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_arrangement_id uuid;
  v_expected_request_version integer;
  v_expected_arrangement_version integer;
  v_decision text;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_arrangement public.v1_procurement_arrangements%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_has_positive_lines boolean;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'arrangement_id', 'expected_request_version',
      'expected_arrangement_version', 'decision', 'reason'],
    'decide_arrangement'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_arrangement_id := nullif(btrim(coalesce(p_payload ->> 'arrangement_id', '')), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_expected_arrangement_version := nullif(
    p_payload ->> 'expected_arrangement_version', ''
  )::integer;
  v_decision := coalesce(p_payload ->> 'decision', '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_arrangement_id is null
    or v_expected_request_version is null
    or v_expected_arrangement_version is null
    or v_expected_request_version < 1 or v_expected_arrangement_version < 1
    or v_decision not in ('approved', 'returned')
    or (v_decision = 'returned' and v_reason is null) then
    raise exception 'V1_ARRANGEMENT_DECISION_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_decide_arrangement(v_request_id) then
    raise exception 'V1_ARRANGEMENT_DECISION_DENIED' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_decide_arrangement', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  select * into v_arrangement
  from public.v1_procurement_arrangements arrangement
  where arrangement.id = v_arrangement_id and arrangement.request_id = v_request.id
  for update;
  if not found or not v_arrangement.is_current
    or v_arrangement.status <> 'awaiting_approval'
    or v_request.state <> 'awaiting_approval' then
    raise exception 'V1_ARRANGEMENT_NOT_AWAITING_DECISION' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_request_version
    or v_arrangement.record_version <> v_expected_arrangement_version then
    raise exception 'V1_ARRANGEMENT_VERSION_CONFLICT' using errcode = '40001';
  end if;

  select exists (
    select 1 from public.v1_procurement_arrangement_lines arrangement_line
    where arrangement_line.arrangement_id = v_arrangement.id
      and arrangement_line.decision in ('full', 'partial')
      and arrangement_line.arranged_qty > 0
  ) into v_has_positive_lines;

  v_before := public.v1_arrangement_projection(v_request.id);
  insert into public.v1_arrangement_decisions (
    arrangement_id, request_id, decision, reason,
    decided_by_auth_user_id, decided_by_role
  ) values (
    v_arrangement.id, v_request.id, v_decision, v_reason, v_actor, v_role
  );

  if v_decision = 'approved' and not v_has_positive_lines then
    update public.v1_inventory_reservations
       set state = 'released', released_at = clock_timestamp(),
           released_by_auth_user_id = v_actor,
           release_reason = 'all_items_unavailable', updated_at = clock_timestamp()
     where request_id = v_request.id and state in ('active', 'partially_consumed');
    delete from public.v1_material_request_line_approvals approval
    where approval.request_line_id in (
      select request_line_id from public.v1_procurement_arrangement_lines
      where arrangement_id = v_arrangement.id
    );
    update public.v1_procurement_arrangements
       set status = 'working', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'arranging', current_action_owner_role = 'procurement',
           current_action_code = 'all_items_unavailable_review',
           cancelled_at = null, cancelled_by_auth_user_id = null,
           cancellation_reason = null,
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
  else
    update public.v1_procurement_arrangements
       set status = 'returned', record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_arrangement.id;
    update public.v1_material_requests
       set state = 'arranging', current_action_owner_role = 'procurement',
           current_action_code = 'arrangement_returned',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;
  end if;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id,
    case
      when v_decision = 'approved' and not v_has_positive_lines
        then 'arrangement_completed_unavailable'
      when v_decision = 'approved' then 'arrangement_approved'
      else 'arrangement_returned'
    end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';

  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_write_audit_event(
    case
      when v_decision = 'approved' and not v_has_positive_lines
        then 'all_items_unavailable_reviewed'
      when v_decision = 'approved' then 'arrangement_approved'
      else 'arrangement_returned'
    end,
    'procurement_arrangement', v_arrangement.id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'decision', v_decision,
      'request_state', case
        when v_decision = 'approved' and v_has_positive_lines then 'approved'
        else 'arranging'
      end,
      'request_action', case
        when v_decision = 'approved' and not v_has_positive_lines
          then 'all_items_unavailable_review'
        when v_decision = 'approved' then 'dispatch_required'
        else 'arrangement_returned'
      end,
      'request_record_version', v_expected_request_version + 1,
      'arrangement_record_version', v_expected_arrangement_version + 1
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_decide_arrangement', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_decide_arrangement(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_decide_arrangement(jsonb, uuid)
  to authenticated, service_role;

create or replace function public.v1_confirm_receipt(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_dispatch_id uuid;
  v_expected_request_version integer;
  v_expected_dispatch_version integer;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_dispatch public.v1_material_dispatches%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_state_summary jsonb;
  v_line jsonb;
  v_dispatch_line_id uuid;
  v_outcome text;
  v_good_qty numeric(18, 4);
  v_missing_qty numeric(18, 4);
  v_damaged_qty numeric(18, 4);
  v_note text;
  v_dispatched_qty numeric(18, 4);
  v_line_count integer;
  v_review_id uuid;
  v_good_total numeric(18, 4) := 0;
  v_missing_total numeric(18, 4) := 0;
  v_damaged_total numeric(18, 4) := 0;
  v_dispatched_total numeric(18, 4) := 0;
  v_delivery_order_id uuid;
  v_delivery_report_revision_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'dispatch_id', 'expected_request_version',
      'expected_dispatch_version', 'lines'],
    'confirm_receipt'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_dispatch_id := nullif(btrim(coalesce(p_payload ->> 'dispatch_id', '')), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_expected_dispatch_version := nullif(
    p_payload ->> 'expected_dispatch_version', ''
  )::integer;
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_dispatch_id is null
    or v_expected_request_version is null or v_expected_dispatch_version is null
    or v_expected_request_version < 1 or v_expected_dispatch_version < 1
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_RECEIPT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_confirm_material_receipt(v_request_id) then
    raise exception 'V1_RECEIPT_CONFIRM_DENIED' using errcode = '42501';
  end if;
  select * into v_dispatch
  from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id and dispatch.request_id = v_request.id
  for update;
  if not found then
    raise exception 'V1_RECEIPT_DISPATCH_NOT_FOUND' using errcode = '22023';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_confirm_receipt', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version
    or v_dispatch.state <> 'receipt_pending'
    or v_request.state not in (
      'partially_dispatched', 'dispatched', 'partially_received'
    ) then
    raise exception 'V1_RECEIPT_STATE_OR_VERSION_INVALID' using errcode = '40001';
  end if;

  select count(*) into v_line_count
  from public.v1_material_dispatch_lines where dispatch_id = v_dispatch.id;
  if jsonb_array_length(v_lines) <> v_line_count or v_line_count = 0
    or (select count(distinct nullif(btrim(coalesce(
      value ->> 'dispatch_line_id', ''
    )), '')::uuid) from jsonb_array_elements(v_lines)) <> v_line_count then
    raise exception 'V1_RECEIPT_LINES_INCOMPLETE' using errcode = '22023';
  end if;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line,
      array['dispatch_line_id', 'outcome', 'good_qty', 'missing_qty',
        'damaged_qty', 'note'],
      'receipt_line'
    );
    v_dispatch_line_id := nullif(btrim(coalesce(
      v_line ->> 'dispatch_line_id', ''
    )), '')::uuid;
    v_outcome := coalesce(v_line ->> 'outcome', '');
    v_good_qty := nullif(v_line ->> 'good_qty', '')::numeric(18, 4);
    v_missing_qty := nullif(v_line ->> 'missing_qty', '')::numeric(18, 4);
    v_damaged_qty := nullif(v_line ->> 'damaged_qty', '')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');

    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines
    where id = v_dispatch_line_id and dispatch_id = v_dispatch.id;

    -- Backward compatibility for already released clients: single-exception
    -- outcomes may omit their explicit split, but Mixed must always state both.
    if v_outcome = 'received' then
      v_missing_qty := coalesce(v_missing_qty, 0);
      v_damaged_qty := coalesce(v_damaged_qty, 0);
    elsif v_outcome = 'missing' then
      v_missing_qty := coalesce(v_missing_qty, v_dispatched_qty - v_good_qty);
      v_damaged_qty := coalesce(v_damaged_qty, 0);
    elsif v_outcome = 'damaged' then
      v_missing_qty := coalesce(v_missing_qty, 0);
      v_damaged_qty := coalesce(v_damaged_qty, v_dispatched_qty - v_good_qty);
    end if;

    if v_dispatched_qty is null or v_good_qty is null
      or v_missing_qty is null or v_damaged_qty is null
      or v_good_qty < 0 or v_missing_qty < 0 or v_damaged_qty < 0
      or v_outcome not in ('received', 'missing', 'damaged', 'mixed')
      or v_good_qty + v_missing_qty + v_damaged_qty <> v_dispatched_qty
      or (v_outcome = 'received' and (
        v_good_qty <> v_dispatched_qty
        or v_missing_qty <> 0 or v_damaged_qty <> 0 or v_note is not null
      ))
      or (v_outcome = 'missing' and (
        v_missing_qty <= 0 or v_damaged_qty <> 0 or v_note is null
      ))
      or (v_outcome = 'damaged' and (
        v_missing_qty <> 0 or v_damaged_qty <= 0 or v_note is null
      ))
      or (v_outcome = 'mixed' and (
        v_missing_qty <= 0 or v_damaged_qty <= 0 or v_note is null
      )) then
      raise exception 'V1_RECEIPT_LINE_INVALID' using errcode = '22023';
    end if;

    v_good_total := v_good_total + v_good_qty;
    v_missing_total := v_missing_total + v_missing_qty;
    v_damaged_total := v_damaged_total + v_damaged_qty;
    v_dispatched_total := v_dispatched_total + v_dispatched_qty;
  end loop;

  v_before := public.v1_logistics_workspace_projection(v_request.id);
  insert into public.v1_receipt_reviews (
    dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
  ) values (v_dispatch.id, v_request.id, v_actor, v_role)
  returning id into v_review_id;

  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_dispatch_line_id := (v_line ->> 'dispatch_line_id')::uuid;
    v_outcome := v_line ->> 'outcome';
    v_good_qty := (v_line ->> 'good_qty')::numeric(18, 4);
    v_missing_qty := nullif(v_line ->> 'missing_qty', '')::numeric(18, 4);
    v_damaged_qty := nullif(v_line ->> 'damaged_qty', '')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines where id = v_dispatch_line_id;
    if v_outcome = 'received' then
      v_missing_qty := coalesce(v_missing_qty, 0);
      v_damaged_qty := coalesce(v_damaged_qty, 0);
    elsif v_outcome = 'missing' then
      v_missing_qty := coalesce(v_missing_qty, v_dispatched_qty - v_good_qty);
      v_damaged_qty := coalesce(v_damaged_qty, 0);
    elsif v_outcome = 'damaged' then
      v_missing_qty := coalesce(v_missing_qty, 0);
      v_damaged_qty := coalesce(v_damaged_qty, v_dispatched_qty - v_good_qty);
    end if;

    insert into public.v1_receipt_review_lines (
      receipt_review_id, dispatch_line_id, outcome, dispatched_qty_snapshot,
      good_qty, missing_qty, damaged_qty, exception_qty, note
    ) values (
      v_review_id, v_dispatch_line_id, v_outcome, v_dispatched_qty,
      v_good_qty, v_missing_qty, v_damaged_qty,
      v_missing_qty + v_damaged_qty, v_note
    );
  end loop;

  update public.v1_material_dispatches
     set state = case when v_good_total = v_dispatched_total then 'received'
       else 'partially_received' end,
         receipt_reviewed_at = clock_timestamp(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_dispatch.id;

  select delivery_order.id into v_delivery_order_id
  from public.v1_delivery_orders delivery_order
  where delivery_order.dispatch_id = v_dispatch.id
  for update;
  if found then
    v_delivery_report_revision_id :=
      public.v1_append_receipt_review_delivery_report_revision(
        v_delivery_order_id, v_review_id, v_actor, v_role
      );
  end if;

  v_state_summary := public.v1_refresh_material_request_logistics_state(v_request.id);
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id, 'receipt_review_confirmed', 'receipt_review',
    v_review_id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';

  v_response := public.v1_logistics_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'receipt_review_confirmed', 'receipt_review', v_review_id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'dispatch_id', v_dispatch.id,
      'dispatch_number', v_dispatch.dispatch_number,
      'good_qty', v_good_total::text,
      'missing_qty', v_missing_total::text,
      'damaged_qty', v_damaged_total::text,
      'exception_qty', (v_missing_total + v_damaged_total)::text,
      'request_state', v_state_summary ->> 'state',
      'request_record_version', v_expected_request_version + 1,
      'delivery_report_revision_id', v_delivery_report_revision_id,
      'delivery_report_updated', v_delivery_report_revision_id is not null
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_receipt', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_confirm_receipt(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_confirm_receipt(jsonb, uuid)
  to authenticated, service_role;

create or replace function public.v1_material_request_line_lifecycle_projection(
  p_request_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with lifecycle as (
    select
      request_line.id as request_line_id,
      request_line.display_order,
      request_line.requested_qty,
      current_arrangement.arrangement_status,
      current_arrangement.decision as arrangement_decision,
      current_arrangement.source_kind,
      current_arrangement.arranged_qty,
      current_arrangement.reason as arrangement_reason,
      coalesce(approval.approved_qty, 0::numeric) as approved_qty,
      coalesce(dispatch_totals.dispatched_qty, 0::numeric) as dispatched_qty,
      coalesce(dispatch_totals.in_transit_qty, 0::numeric) as in_transit_qty,
      coalesce(review_totals.good_qty, 0::numeric) as good_qty,
      coalesce(review_totals.missing_qty, 0::numeric) as missing_qty,
      coalesce(review_totals.damaged_qty, 0::numeric) as damaged_qty
    from public.v1_material_request_lines request_line
    left join lateral (
      select arrangement.status as arrangement_status,
        arrangement_line.decision,
        arrangement_line.source_kind,
        arrangement_line.arranged_qty,
        arrangement_line.reason
      from public.v1_procurement_arrangements arrangement
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.arrangement_id = arrangement.id
       and arrangement_line.request_line_id = request_line.id
      where arrangement.request_id = request_line.request_id
        and arrangement.is_current
      order by arrangement.arrangement_version desc
      limit 1
    ) current_arrangement on true
    left join public.v1_material_request_line_approvals approval
      on approval.request_line_id = request_line.id
    left join lateral (
      select
        coalesce(sum(dispatch_line.dispatched_qty), 0::numeric) as dispatched_qty,
        coalesce(sum(dispatch_line.dispatched_qty) filter (
          where dispatch.state = 'receipt_pending'
        ), 0::numeric) as in_transit_qty
      from public.v1_material_dispatch_lines dispatch_line
      join public.v1_material_dispatches dispatch
        on dispatch.id = dispatch_line.dispatch_id
      where dispatch_line.request_line_id = request_line.id
    ) dispatch_totals on true
    left join lateral (
      select
        coalesce(sum(review_line.good_qty), 0::numeric) as good_qty,
        coalesce(sum(review_line.missing_qty), 0::numeric) as missing_qty,
        coalesce(sum(review_line.damaged_qty), 0::numeric) as damaged_qty
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review
        on review.id = review_line.receipt_review_id
       and review.state = 'confirmed'
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      where dispatch_line.request_line_id = request_line.id
    ) review_totals on true
    where request_line.request_id = p_request_id
  ), quantities as (
    select *,
      case
        when arrangement_decision = 'unavailable' then requested_qty
        when arrangement_decision = 'partial' then greatest(
          requested_qty - coalesce(arranged_qty, 0::numeric), 0::numeric
        )
        else 0::numeric
      end as cannot_provide_qty,
      greatest(approved_qty - good_qty - in_transit_qty, 0::numeric)
        as remaining_approved_qty,
      least(
        missing_qty + damaged_qty,
        greatest(approved_qty - good_qty, 0::numeric)
      ) as replacement_eligible_qty
    from lifecycle
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'request_line_id', request_line_id,
    'requested_qty', requested_qty::text,
    'arrangement_decision', arrangement_decision,
    'arrangement_status', arrangement_status,
    'source_kind', source_kind,
    'arranged_qty', coalesce(arranged_qty, 0::numeric)::text,
    'cannot_provide_qty', cannot_provide_qty::text,
    'arrangement_reason', arrangement_reason,
    'approved_qty', approved_qty::text,
    'dispatched_qty', dispatched_qty::text,
    'in_transit_qty', in_transit_qty::text,
    'reviewed_good_qty', good_qty::text,
    'reviewed_missing_qty', missing_qty::text,
    'reviewed_damaged_qty', damaged_qty::text,
    'good_qty', good_qty::text,
    'missing_qty', missing_qty::text,
    'damaged_qty', damaged_qty::text,
    'remaining_approved_qty', remaining_approved_qty::text,
    'replacement_eligible_qty', replacement_eligible_qty::text,
    'ordinary_outstanding_qty', greatest(
      remaining_approved_qty - replacement_eligible_qty, 0::numeric
    )::text,
    'fulfilled_qty', good_qty::text,
    'status', case
      when arrangement_status is null then 'Pending arrangement'
      when arrangement_status = 'awaiting_approval' then 'Awaiting approval'
      when arrangement_status = 'returned' then 'Returned to Procurement'
      when arrangement_decision = 'unavailable' or approved_qty = 0
        then 'Cannot Provide Now'
      when good_qty >= approved_qty and in_transit_qty = 0 then 'Fully received'
      when in_transit_qty > 0 then 'Awaiting receipt review'
      when replacement_eligible_qty > 0 then 'Replacement required'
      when good_qty > 0 then 'Partially received'
      when dispatched_qty = 0 then 'Not dispatched'
      else 'Partially dispatched'
    end
  ) order by display_order), '[]'::jsonb)
  from quantities;
$$;

revoke all on function
  public.v1_material_request_line_lifecycle_projection(uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_material_request_line_lifecycle_projection(uuid)
  to service_role;

create or replace function public.v1_logistics_workspace_projection(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_can_dispatch boolean := public.v1_can_dispatch_material_request(p_request_id);
  v_can_confirm boolean := public.v1_can_confirm_material_receipt(p_request_id);
  v_result jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_LOGISTICS_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'request_id', request_record.id,
    'project_id', request_record.project_id,
    'request_number', request_record.request_number,
    'request_state', request_record.state,
    'request_record_version', request_record.record_version,
    'project_name', project.name,
    'scope_name', scope.name,
    'can_dispatch', v_can_dispatch and request_record.state in (
      'approved', 'partially_dispatched', 'partially_received'
    ),
    'can_confirm_receipt', v_can_confirm,
    'dispatch_candidates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_line_id', request_line.id,
        'display_order', request_line.display_order,
        'item_description', request_line.item_description,
        'brand_origin', request_line.brand_origin,
        'unit', request_line.unit,
        'approved_qty', approval.approved_qty::text,
        'good_received_qty', coalesce((
          select sum(review_line.good_qty)
          from public.v1_receipt_review_lines review_line
          join public.v1_receipt_reviews review
            on review.id = review_line.receipt_review_id
          join public.v1_material_dispatch_lines dispatch_line
            on dispatch_line.id = review_line.dispatch_line_id
          where review.state = 'confirmed'
            and dispatch_line.request_line_id = request_line.id
        ), 0)::text,
        'in_transit_qty', coalesce((
          select sum(dispatch_line.dispatched_qty)
          from public.v1_material_dispatch_lines dispatch_line
          join public.v1_material_dispatches dispatch
            on dispatch.id = dispatch_line.dispatch_id
          where dispatch.state = 'receipt_pending'
            and dispatch_line.request_line_id = request_line.id
        ), 0)::text,
        'still_needed_qty', greatest(0, approval.approved_qty
          - coalesce((
            select sum(review_line.good_qty)
            from public.v1_receipt_review_lines review_line
            join public.v1_receipt_reviews review
              on review.id = review_line.receipt_review_id
            join public.v1_material_dispatch_lines dispatch_line
              on dispatch_line.id = review_line.dispatch_line_id
            where review.state = 'confirmed'
              and dispatch_line.request_line_id = request_line.id
          ), 0)
          - coalesce((
            select sum(dispatch_line.dispatched_qty)
            from public.v1_material_dispatch_lines dispatch_line
            join public.v1_material_dispatches dispatch
              on dispatch.id = dispatch_line.dispatch_id
            where dispatch.state = 'receipt_pending'
              and dispatch_line.request_line_id = request_line.id
          ), 0))::text,
        'source_kind', arrangement_line.source_kind,
        'external_supplier', arrangement_line.external_supplier,
        'inventory_item_id', case when v_can_dispatch
          then arrangement_line.inventory_item_id else null end,
        'reserved_remaining_qty', case when v_can_dispatch then coalesce(
          reservation.reserved_qty - reservation.consumed_qty, 0
        )::text else null end,
        'warehouse_available_qty', case when v_can_dispatch then (
          balance.on_hand_qty - coalesce((
            select sum(other_reservation.reserved_qty - other_reservation.consumed_qty)
            from public.v1_inventory_reservations other_reservation
            where other_reservation.inventory_item_id = arrangement_line.inventory_item_id
              and other_reservation.request_id <> request_record.id
              and other_reservation.state in ('active', 'partially_consumed')
          ), 0)
        )::text else null end
      ) order by request_line.display_order)
      from public.v1_material_request_line_approvals approval
      join public.v1_material_request_lines request_line
        on request_line.id = approval.request_line_id
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.id = approval.arrangement_line_id
      left join public.v1_inventory_reservations reservation
        on reservation.arrangement_line_id = arrangement_line.id
      left join public.v1_inventory_balances balance
        on balance.inventory_item_id = arrangement_line.inventory_item_id
      where request_line.request_id = request_record.id
    ), '[]'::jsonb),
    'dispatches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', dispatch.id,
        'dispatch_number', dispatch.dispatch_number,
        'dispatch_date', dispatch.dispatch_date,
        'driver_name', dispatch.driver_name,
        'vehicle_reference', dispatch.vehicle_reference,
        'delivery_reference', dispatch.delivery_reference,
        'state', dispatch.state,
        'record_version', dispatch.record_version,
        'dispatched_by_display_name', coalesce(
          dispatch.dispatched_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            dispatcher.display_name, dispatcher.auth_user_id
          )
        ),
        'dispatched_at', dispatch.dispatched_at,
        'dispatched_by_role', coalesce(
          dispatch.dispatched_by_exact_role, dispatch.dispatched_by_role
        ),
        'can_confirm_receipt', v_can_confirm and dispatch.state = 'receipt_pending',
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', dispatch_line.id,
            'request_line_id', dispatch_line.request_line_id,
            'item_description', dispatch_line.item_description,
            'brand_origin', dispatch_line.brand_origin,
            'unit', dispatch_line.unit,
            'source_kind', dispatch_line.source_kind,
            'external_supplier', dispatch_line.external_supplier,
            'dispatched_qty', dispatch_line.dispatched_qty::text,
            'approved_qty_snapshot', dispatch_line.approved_qty_snapshot::text,
            'receipt_outcome', review_line.outcome,
            'good_qty', case when review_line.good_qty is null then null
              else review_line.good_qty::text end,
            'missing_qty', case when review_line.missing_qty is null then null
              else review_line.missing_qty::text end,
            'damaged_qty', case when review_line.damaged_qty is null then null
              else review_line.damaged_qty::text end,
            'exception_qty', case when review_line.exception_qty is null then null
              else review_line.exception_qty::text end,
            'receipt_note', review_line.note
          ) order by dispatch_line.created_at)
          from public.v1_material_dispatch_lines dispatch_line
          left join public.v1_receipt_reviews review
            on review.dispatch_id = dispatch.id and review.state = 'confirmed'
          left join public.v1_receipt_review_lines review_line
            on review_line.receipt_review_id = review.id
              and review_line.dispatch_line_id = dispatch_line.id
          where dispatch_line.dispatch_id = dispatch.id
        ), '[]'::jsonb),
        'receipt_review', (
          select jsonb_build_object(
            'id', review.id,
            'reviewed_at', review.reviewed_at,
            'reviewed_by_role', coalesce(
              review.reviewed_by_exact_role, review.reviewed_by_role
            ),
            'reviewed_by_display_name', coalesce(
              review.reviewed_by_display_name_snapshot,
              public.v1_safe_profile_display_name(
                reviewer.display_name, reviewer.auth_user_id
              )
            )
          )
          from public.v1_receipt_reviews review
          join public.v1_profiles reviewer
            on reviewer.auth_user_id = review.reviewed_by_auth_user_id
          where review.dispatch_id = dispatch.id and review.state = 'confirmed'
        )
      ) order by dispatch.dispatched_at desc)
      from public.v1_material_dispatches dispatch
      join public.v1_profiles dispatcher
        on dispatcher.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

revoke all on function public.v1_logistics_workspace_projection(uuid)
  from public, anon;
grant execute on function public.v1_logistics_workspace_projection(uuid)
  to authenticated, service_role;
