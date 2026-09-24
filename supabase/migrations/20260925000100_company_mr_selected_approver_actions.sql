-- Company MR owner-approved integration: selectable independent approver,
-- pre-dispatch corrections/cancellation and Admin submitted-record oversight.
-- Additive and versioned; retain request/line IDs, snapshots and all events.
-- Rollback: feature off / previous client. Keep new states and evidence; fix forward.
begin;
alter table public.v1_company_material_requests add column if not exists selected_approver_auth_user_id uuid references public.v1_profiles(auth_user_id) on delete restrict;

create or replace function public.v1_company_material_request_readable(p_request_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.v1_current_actor_is_active() and exists (
 select 1 from public.v1_company_material_requests r where r.id=p_request_id and (
 r.created_by_auth_user_id=auth.uid()
 or (r.submitted_at is not null and (public.v1_current_exact_role()='admin' or auth.uid() in (
 r.beneficiary_auth_user_id,r.authorized_receiver_auth_user_id,r.approver_auth_user_id)))
 or ((r.state in ('approved_for_procurement','arranging','ready_for_delivery','partially_dispatched',
 'receipt_pending','partially_received','awaiting_beneficiary_handover','fulfilled','closed')
 or exists(select 1 from public.v1_company_material_request_decisions decision where decision.request_id=r.id and decision.decision='approved'))
 and public.v1_current_role()='procurement')));
$$;

-- A Yorks login is mandatory; protected dated Company authorization is additional.
create or replace function public.v1_company_eligible_approvers(p_category uuid,p_unit uuid,p_excluded uuid[])
returns table(auth_user_id uuid,display_name text) language sql stable security definer set search_path='' as $$
 select p.auth_user_id,p.display_name from public.v1_profiles p
 join auth.users u on u.id=p.auth_user_id
 where p.is_active and not (p.auth_user_id=any(p_excluded))
 and coalesce(u.raw_app_meta_data->>'role','') in ('project_engineer','senior_mechanical_engineer',
 'project_manager','workshop_in_charge','document_controller','admin')
 and public.v1_company_material_request_active_authorization(p.auth_user_id,p_category,p_unit,'approver')
 order by lower(p.display_name),p.auth_user_id;
$$;
revoke all on function public.v1_company_eligible_approvers(uuid,uuid,uuid[]) from public,anon,authenticated;

create or replace function public.v1_resolve_selected_company_approver(p_category uuid,p_unit uuid,p_excluded uuid[],p_selected uuid)
returns table(route_id uuid,policy_version text,approver_auth_user_id uuid,approver_display_name text)
language plpgsql stable security definer set search_path='' as $$
declare v_route record;
begin
 if p_selected is null then
  return query select r.* from public.v1_resolve_company_material_request_approver(p_category,p_unit,p_excluded) r
   join public.v1_company_eligible_approvers(p_category,p_unit,p_excluded) a on a.auth_user_id=r.approver_auth_user_id;
  return;
 end if;
 select r.id,r.policy_version into v_route from public.v1_company_material_request_approval_routes r
 where r.category_id=p_category and r.responsible_unit_id=p_unit and r.effective_from<=current_date
 and (r.effective_to is null or r.effective_to>=current_date);
 if not found or (select count(*) from public.v1_company_material_request_approval_routes r
 where r.category_id=p_category and r.responsible_unit_id=p_unit and r.effective_from<=current_date
 and (r.effective_to is null or r.effective_to>=current_date))<>1 then return; end if;
 return query select v_route.id,v_route.policy_version,a.auth_user_id,a.display_name
 from public.v1_company_eligible_approvers(p_category,p_unit,p_excluded) a where a.auth_user_id=p_selected;
end $$;
revoke all on function public.v1_resolve_selected_company_approver(uuid,uuid,uuid[],uuid) from public,anon,authenticated;

create or replace function public.v1_company_material_request_approval_choices(
 p_category_id uuid,p_responsible_unit_id uuid,p_beneficiary_auth_user_id uuid,
 p_authorized_receiver_auth_user_id uuid,p_selected_approver_auth_user_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_route record; v_excluded uuid[]:=array[auth.uid(),p_beneficiary_auth_user_id,p_authorized_receiver_auth_user_id];
begin
 if auth.uid() is null or not public.v1_current_actor_is_active()
 or not public.v1_company_material_request_active_authorization(auth.uid(),p_category_id,p_responsible_unit_id,'requester')
 or not public.v1_company_material_request_active_authorization(p_beneficiary_auth_user_id,p_category_id,p_responsible_unit_id,'beneficiary')
 or not public.v1_company_material_request_active_authorization(p_authorized_receiver_auth_user_id,p_category_id,p_responsible_unit_id,'receiver') then
 raise exception 'V1_COMPANY_MATERIAL_REQUEST_PREFLIGHT_DENIED' using errcode='42501'; end if;
 select * into v_route from public.v1_resolve_selected_company_approver(p_category_id,p_responsible_unit_id,v_excluded,p_selected_approver_auth_user_id);
 if not found then raise exception 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED' using errcode='22023'; end if;
 return jsonb_build_object('approval_route_id',v_route.route_id,'policy_version',v_route.policy_version,
 'approver_auth_user_id',v_route.approver_auth_user_id,'approver_display_name',v_route.approver_display_name,
 'eligible_approvers',coalesce((select jsonb_agg(to_jsonb(a)) from public.v1_company_eligible_approvers(
 p_category_id,p_responsible_unit_id,v_excluded) a),'[]'::jsonb));
end $$;
revoke all on function public.v1_company_material_request_approval_choices(uuid,uuid,uuid,uuid,uuid) from public,anon;
grant execute on function public.v1_company_material_request_approval_choices(uuid,uuid,uuid,uuid,uuid) to authenticated,service_role;

do $$ begin
 if to_regprocedure('public.v1_save_company_material_request_draft_selection_base(jsonb)') is null then
 alter function public.v1_save_company_material_request_draft(jsonb) rename to v1_save_company_material_request_draft_selection_base; end if;
end $$;
revoke all on function public.v1_save_company_material_request_draft_selection_base(jsonb) from public,anon,authenticated;
create or replace function public.v1_save_company_material_request_draft(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_result jsonb; v_selected uuid:=(p_payload->>'selected_approver_auth_user_id')::uuid;
begin
 if v_selected is not null then perform public.v1_company_material_request_approval_choices(
 (p_payload->>'category_id')::uuid,(p_payload->>'responsible_unit_id')::uuid,
 (p_payload->>'beneficiary_auth_user_id')::uuid,(p_payload->>'authorized_receiver_auth_user_id')::uuid,v_selected); end if;
 v_result:=public.v1_save_company_material_request_draft_selection_base(p_payload-'selected_approver_auth_user_id');
 update public.v1_company_material_requests set selected_approver_auth_user_id=v_selected where id=(v_result->>'id')::uuid;
 return public.v1_company_material_request_projection((v_result->>'id')::uuid);
end $$;
revoke all on function public.v1_save_company_material_request_draft(jsonb) from public,anon;
grant execute on function public.v1_save_company_material_request_draft(jsonb) to authenticated,service_role;

create or replace function public.v1_submit_company_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_role();
  v_request_id uuid;
  v_expected_version integer;
  v_existing_response jsonb;
  v_request public.v1_company_material_requests%rowtype;
  v_route record;
  v_sequence integer;
  v_response jsonb;
begin
  if v_actor is null or v_exact_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'company_material_request_submit_payload'
  );
  begin
    v_request_id := (p_payload ->> 'request_id')::uuid;
    v_expected_version := (p_payload ->> 'expected_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_submit_company_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  select * into v_request from public.v1_company_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or v_request.created_by_auth_user_id <> v_actor then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  if v_request.state <> 'draft' then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_ALREADY_SUBMITTED' using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode = '40001';
  end if;
  if not public.v1_company_material_request_active_authorization(
      v_actor, v_request.category_id, v_request.responsible_unit_id, 'requester'
    )
    or not public.v1_company_material_request_active_authorization(
      v_request.beneficiary_auth_user_id, v_request.category_id,
      v_request.responsible_unit_id, 'beneficiary'
    )
    or not public.v1_company_material_request_active_authorization(
      v_request.authorized_receiver_auth_user_id, v_request.category_id,
      v_request.responsible_unit_id, 'receiver'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_PARTICIPANT_DENIED' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.v1_company_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_LINES_REQUIRED' using errcode = '22023';
  end if;
  select * into v_route from public.v1_resolve_selected_company_approver(
    v_request.category_id,
    v_request.responsible_unit_id,
    array[v_actor, v_request.beneficiary_auth_user_id, v_request.authorized_receiver_auth_user_id],
    v_request.selected_approver_auth_user_id
  );
  if not found then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_APPROVAL_ROUTE_NOT_CONFIGURED'
      using errcode = '22023';
  end if;
  update public.v1_company_material_request_reference_counter
  set next_sequence = next_sequence + 1, updated_at = clock_timestamp()
  where singleton
  returning next_sequence - 1 into v_sequence;

  update public.v1_company_material_requests request_record
  set request_number = 'CMR-' || lpad(v_sequence::text, 6, '0'),
      state = 'awaiting_company_approval',
      approval_route_id = v_route.route_id,
      approval_policy_version = v_route.policy_version,
      approver_auth_user_id = v_route.approver_auth_user_id,
      approver_display_name = v_route.approver_display_name,
      submitted_at = clock_timestamp(),
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request.id;
  insert into public.v1_company_material_request_events (
    request_id, event_type, actor_auth_user_id, actor_exact_role, data, idempotency_key
  ) values (
    v_request.id, 'company_request_submitted', v_actor, v_exact_role,
    jsonb_build_object(
      'approval_route_id', v_route.route_id,
      'approval_policy_version', v_route.policy_version,
      'approver_auth_user_id', v_route.approver_auth_user_id,
      'beneficiary_auth_user_id', v_request.beneficiary_auth_user_id,
      'authorized_receiver_auth_user_id', v_request.authorized_receiver_auth_user_id
    ), p_idempotency_key
  );
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  ) values (
    v_route.approver_auth_user_id,
    'company_material_request_approval_requested',
    'company_material_request',
    v_request.id,
    null
  );
  v_response := public.v1_company_material_request_projection(v_request.id);
  perform public.v1_complete_idempotency(
    'v1_submit_company_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Preserve a private cancelled draft's unnumbered shape; submitted history stays numbered.
alter table public.v1_company_material_requests drop constraint if exists v1_company_material_requests_state_check;
alter table public.v1_company_material_requests add constraint v1_company_material_requests_state_check check(state in (
'draft','awaiting_company_approval','approved_for_procurement','returned_for_changes','rejected','arranging',
'ready_for_delivery','partially_dispatched','receipt_pending','partially_received','awaiting_beneficiary_handover','fulfilled','closed','cancelled'));
alter table public.v1_company_material_requests drop constraint if exists v1_company_material_requests_submission_shape_check;
alter table public.v1_company_material_requests add constraint v1_company_material_requests_submission_shape_check check(
(state in ('draft','cancelled') and request_number is null and submitted_at is null and approval_route_id is null
 and approval_policy_version is null and approver_auth_user_id is null and approver_display_name is null)
or (state<>'draft' and request_number is not null and submitted_at is not null and approval_route_id is not null
 and approval_policy_version is not null and approver_auth_user_id is not null and approver_display_name is not null));
alter table public.v1_company_material_request_events drop constraint if exists v1_company_material_request_events_event_type_check;
alter table public.v1_company_material_request_events add constraint v1_company_material_request_events_event_type_check check(event_type in (
'company_request_draft_created','company_request_submitted','company_request_approved','company_request_returned',
'company_request_rejected','company_request_resubmitted','company_supply_plan_saved','company_material_dispatched',
'company_receipt_confirmed','company_beneficiary_handover_confirmed','company_return_submitted','company_return_confirmed',
'company_return_rejected','company_request_closed','company_request_remainder_withdrawn','company_request_cancelled'));
insert into public.v1_audit_event_catalogue(event_type,severity) values('company_request_cancelled','warning') on conflict(event_type) do nothing;

create or replace function public.v1_can_edit_company_request(p_request_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.v1_current_actor_is_active() and exists(
 select 1 from public.v1_company_material_requests r where r.id=p_request_id
 and r.state in ('awaiting_company_approval','returned_for_changes','approved_for_procurement','arranging','ready_for_delivery')
 and not exists(select 1 from public.v1_company_material_dispatches d where d.request_id=r.id)
 and not exists(select 1 from public.v1_company_material_request_withdrawals w where w.request_id=r.id)
 and ((r.created_by_auth_user_id=auth.uid() and public.v1_company_material_request_active_authorization(
 auth.uid(),r.category_id,r.responsible_unit_id,'requester'))
 or (public.v1_current_role()='procurement' and r.state in ('approved_for_procurement','arranging','ready_for_delivery'))));
$$;
create or replace function public.v1_can_cancel_company_request(p_request_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.v1_current_actor_is_active() and exists(
 select 1 from public.v1_company_material_requests r where r.id=p_request_id
 and r.state in ('draft','awaiting_company_approval','returned_for_changes','approved_for_procurement','arranging','ready_for_delivery')
 and not exists(select 1 from public.v1_company_material_dispatches d where d.request_id=r.id)
 and ((r.created_by_auth_user_id=auth.uid() and public.v1_company_material_request_active_authorization(
 auth.uid(),r.category_id,r.responsible_unit_id,'requester'))
 or public.v1_company_material_request_assigned_approver(r.id,false)));
$$;
revoke all on function public.v1_can_edit_company_request(uuid),public.v1_can_cancel_company_request(uuid) from public,anon,authenticated;

create or replace function public.v1_cancel_company_material_request(p_request_id uuid,p_expected_version integer,p_reason text,p_idempotency_key uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_request public.v1_company_material_requests%rowtype; v_existing jsonb; v_actor uuid:=auth.uid();
begin
 if v_actor is null or not public.v1_current_actor_is_active() then raise exception 'V1_COMPANY_CANCEL_DENIED' using errcode='42501'; end if;
 v_existing:=public.v1_idempotency_get_or_claim('v1_cancel_company_material_request',p_idempotency_key,
 jsonb_build_object('id',p_request_id,'version',p_expected_version,'reason',p_reason));
 select * into v_request from public.v1_company_material_requests where id=p_request_id for update;
 if v_existing is not null then return public.v1_company_material_request_projection(p_request_id); end if;
 if not public.v1_can_cancel_company_request(p_request_id) then raise exception 'V1_COMPANY_CANCEL_DENIED' using errcode='42501'; end if;
 if p_expected_version is null or v_request.record_version<>p_expected_version then raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode='40001'; end if;
 if nullif(btrim(p_reason),'') is null or char_length(p_reason)>2000 then raise exception 'V1_COMPANY_CANCEL_REASON_REQUIRED' using errcode='22023'; end if;
 update public.v1_inventory_reservations set state='released',released_at=clock_timestamp(),released_by_auth_user_id=v_actor,
 release_reason=p_reason,updated_at=clock_timestamp() where request_kind='company' and request_id=p_request_id and state in ('active','partially_consumed');
 update public.v1_company_material_supply_plans set is_current=false,superseded_at=clock_timestamp() where request_id=p_request_id and is_current;
 update public.v1_company_material_requests set state='cancelled',record_version=record_version+1,updated_at=clock_timestamp() where id=p_request_id;
 insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,actor_exact_role,data,idempotency_key)
 values(p_request_id,'company_request_cancelled',v_actor,public.v1_current_exact_role(),jsonb_build_object('reason',btrim(p_reason),'previous_state',v_request.state),p_idempotency_key);
 perform public.v1_complete_idempotency('v1_cancel_company_material_request',p_idempotency_key,public.v1_company_material_request_projection(p_request_id));
 return public.v1_company_material_request_projection(p_request_id);
end $$;
revoke all on function public.v1_cancel_company_material_request(uuid,integer,text,uuid) from public,anon;
grant execute on function public.v1_cancel_company_material_request(uuid,integer,text,uuid) to authenticated,service_role;

create or replace function public.v1_revise_and_resubmit_company_material_request(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_purpose text;
  v_delivery text; v_lines jsonb; v_request public.v1_company_material_requests%rowtype;
  v_existing jsonb; v_route record; v_line jsonb; v_line_id uuid; v_qty numeric(18,4);
  v_description text; v_brand text; v_unit text; v_count integer;
begin
  perform public.v1_assert_object_keys(p_payload,array['request_id','expected_version',
    'purpose','delivery_collection_point','lines','reason'],'company_request_revision');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then raise exception 'V1_COMPANY_REVISION_INVALID' using errcode='22023'; end;
  v_purpose:=nullif(btrim(coalesce(p_payload->>'purpose','')),'');
  v_delivery:=nullif(btrim(coalesce(p_payload->>'delivery_collection_point','')),'');
  v_lines:=p_payload->'lines';
  if v_purpose is null or v_delivery is null or jsonb_typeof(v_lines)<>'array'
    or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_REVISION_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_revise_and_resubmit_company_material_request',p_idempotency_key,p_payload);
  select * into v_request from public.v1_company_material_requests where id=v_request_id for update;
  if not found or v_actor is null or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_readable(v_request_id) then
    raise exception 'V1_COMPANY_REVISION_DENIED' using errcode='42501'; end if;
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  if not public.v1_can_edit_company_request(v_request_id) or v_expected is null or v_request.record_version<>v_expected then
    raise exception 'V1_COMPANY_REVISION_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  if not public.v1_company_material_request_active_authorization(v_request.created_by_auth_user_id,v_request.category_id,
      v_request.responsible_unit_id,'requester')
    or not public.v1_company_material_request_active_authorization(v_request.beneficiary_auth_user_id,
      v_request.category_id,v_request.responsible_unit_id,'beneficiary')
    or not public.v1_company_material_request_active_authorization(
      v_request.authorized_receiver_auth_user_id,v_request.category_id,
      v_request.responsible_unit_id,'receiver') then
    raise exception 'V1_COMPANY_REVISION_PARTICIPANT_DENIED' using errcode='42501'; end if;
  select * into v_route from public.v1_resolve_selected_company_approver(
    v_request.category_id,v_request.responsible_unit_id,array[v_request.created_by_auth_user_id,v_actor,
    v_request.beneficiary_auth_user_id,v_request.authorized_receiver_auth_user_id],v_request.selected_approver_auth_user_id);
  if not found then raise exception 'V1_COMPANY_REVISION_ROUTE_UNAVAILABLE' using errcode='42501'; end if;
  if v_request.state<>'returned_for_changes' and (nullif(btrim(p_payload->>'reason'),'') is null or char_length(p_payload->>'reason')>2000) then
    raise exception 'V1_COMPANY_REVISION_REASON_REQUIRED' using errcode='22023'; end if;
  update public.v1_inventory_reservations set state='released',released_at=clock_timestamp(),released_by_auth_user_id=v_actor,
    release_reason='Company request revised',updated_at=clock_timestamp()
    where request_kind='company' and request_id=v_request_id and state in ('active','partially_consumed');
  update public.v1_company_material_supply_plans set is_current=false,superseded_at=clock_timestamp()
    where request_id=v_request_id and is_current;
  select count(*) into v_count from public.v1_company_material_request_lines where request_id=v_request_id;
  if jsonb_array_length(v_lines)<>v_count or (select count(distinct value->>'id')
    from jsonb_array_elements(v_lines))<>v_count then
    raise exception 'V1_COMPANY_REVISION_LINES_INVALID' using errcode='22023'; end if;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['id','item_description','brand_origin',
      'requested_qty','unit'],'company_request_revision_line');
    begin v_line_id:=(v_line->>'id')::uuid;
      v_qty:=(v_line->>'requested_qty')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_REVISION_LINE_INVALID' using errcode='22023'; end;
    v_description:=nullif(btrim(coalesce(v_line->>'item_description','')),'');
    v_brand:=nullif(btrim(coalesce(v_line->>'brand_origin','')),'');
    v_unit:=nullif(btrim(coalesce(v_line->>'unit','')),'');
    if v_qty is null or v_qty<=0 or v_description is null or v_unit is null or not exists(
      select 1 from public.v1_company_material_request_lines
      where id=v_line_id and request_id=v_request_id) then
      raise exception 'V1_COMPANY_REVISION_LINE_INVALID' using errcode='22023'; end if;
    update public.v1_company_material_request_lines set item_description=v_description,
      brand_origin=v_brand,requested_qty=v_qty,unit=v_unit,updated_at=clock_timestamp()
      where id=v_line_id;
  end loop;
  update public.v1_company_material_requests set purpose=v_purpose,
    delivery_collection_point=v_delivery,state='awaiting_company_approval',
    approval_route_id=v_route.route_id,approval_policy_version=v_route.policy_version,
    approver_auth_user_id=v_route.approver_auth_user_id,
    approver_display_name=v_route.approver_display_name,
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_request_resubmitted',
    v_actor,public.v1_current_role(),jsonb_build_object('approval_route_id',v_route.route_id,
    'approval_policy_version',v_route.policy_version,'reason',p_payload->>'reason','previous_state',v_request.state),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_revise_and_resubmit_company_material_request',
    p_idempotency_key,public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

do $$ begin
 if to_regprocedure('public.v1_company_material_request_projection_actions_base(uuid)') is null then
 alter function public.v1_company_material_request_projection(uuid) rename to v1_company_material_request_projection_actions_base; end if;
end $$;
revoke all on function public.v1_company_material_request_projection_actions_base(uuid) from public,anon,authenticated;
create or replace function public.v1_company_material_request_projection(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 v_result:=public.v1_company_material_request_projection_actions_base(p_request_id);
 return v_result||jsonb_build_object('selected_approver_auth_user_id',(select selected_approver_auth_user_id from public.v1_company_material_requests where id=p_request_id),
 'can_revise',public.v1_can_edit_company_request(p_request_id),'can_cancel',public.v1_can_cancel_company_request(p_request_id));
end $$;
revoke all on function public.v1_company_material_request_projection(uuid) from public,anon;
grant execute on function public.v1_company_material_request_projection(uuid) to authenticated,service_role;
create or replace function public.v1_decide_company_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_request_id uuid;
  v_expected_version integer;
  v_decision text;
  v_reason text;
  v_existing_response jsonb;
  v_request public.v1_company_material_requests%rowtype;
  v_actor_name text;
  v_next_state text;
  v_event_type text;
  v_response jsonb;
begin
  if v_actor is null or v_exact_role = ''
    or not public.v1_current_actor_is_active()
    or v_exact_role = 'procurement' then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED'
      using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version', 'decision', 'reason'],
    'company_material_request_decision_payload'
  );
  begin
    v_request_id := (p_payload ->> 'request_id')::uuid;
    v_expected_version := (p_payload ->> 'expected_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_PAYLOAD_INVALID'
      using errcode = '22023';
  end;
  v_decision := nullif(btrim(coalesce(p_payload ->> 'decision', '')), '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_decision not in ('approved', 'returned', 'rejected')
    or (v_decision = 'approved' and v_reason is not null)
    or (v_decision in ('returned', 'rejected') and v_reason is null)
    or char_length(coalesce(v_reason, '')) > 2000 then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_decide_company_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    if not public.v1_company_material_request_assigned_approver(
      v_request_id, false
    ) then
      raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED'
        using errcode = '42501';
    end if;
    return public.v1_company_material_request_projection(v_request_id);
  end if;

  select * into v_request
  from public.v1_company_material_requests request_record
  where request_record.id = v_request_id
  for update;
  if not found or not public.v1_company_material_request_assigned_approver(
    v_request_id, true
  ) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED'
      using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_CONFLICT' using errcode = '40001';
  end if;
  select display_name into v_actor_name
  from public.v1_profiles
  where auth_user_id = v_actor and is_active;
  if nullif(btrim(coalesce(v_actor_name, '')), '') is null then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_DECISION_DENIED'
      using errcode = '42501';
  end if;

  v_next_state := case v_decision
    when 'approved' then 'approved_for_procurement'
    when 'returned' then 'returned_for_changes'
    else 'rejected'
  end;
  v_event_type := case v_decision
    when 'approved' then 'company_request_approved'
    when 'returned' then 'company_request_returned'
    else 'company_request_rejected'
  end;

  insert into public.v1_company_material_request_decisions (
    request_id, request_record_version, decision, reason,
    approval_route_id, approval_policy_version,
    decided_by_auth_user_id, decided_by_display_name, decided_by_exact_role,
    idempotency_key
  ) values (
    v_request.id, v_request.record_version, v_decision, v_reason,
    v_request.approval_route_id, v_request.approval_policy_version,
    v_actor, v_actor_name, v_exact_role, p_idempotency_key
  );
  update public.v1_company_material_requests request_record
  set state = v_next_state,
      record_version = request_record.record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request.id;
  insert into public.v1_company_material_request_events (
    request_id, event_type, actor_auth_user_id, actor_exact_role, data,
    idempotency_key
  ) values (
    v_request.id, v_event_type, v_actor, v_exact_role,
    jsonb_build_object(
      'decision', v_decision,
      'reason', v_reason,
      'request_record_version', v_request.record_version,
      'approval_route_id', v_request.approval_route_id,
      'approval_policy_version', v_request.approval_policy_version
    ), p_idempotency_key
  );
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  ) values (
    v_request.created_by_auth_user_id,
    'company_material_request_' || v_decision,
    'company_material_request', v_request.id, null
  );
  v_response := public.v1_company_material_request_projection(v_request.id);
  perform public.v1_complete_idempotency(
    'v1_decide_company_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;
create or replace function public.v1_notify_company_material_request_event()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_request public.v1_company_material_requests%rowtype; v_recipient uuid; v_code text;
begin
  select * into v_request from public.v1_company_material_requests where id=new.request_id;
  if new.event_type='company_request_cancelled' then
    insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
    select distinct recipient,'company_material_request_cancelled','company_material_request',new.request_id,null::uuid
    from (
      select unnest(array[v_request.created_by_auth_user_id,v_request.approver_auth_user_id,
        v_request.authorized_receiver_auth_user_id,v_request.beneficiary_auth_user_id]) recipient
      union select p.auth_user_id from public.v1_profiles p join auth.users u on u.id=p.auth_user_id
        where p.is_active and u.raw_app_meta_data->>'role'='procurement'
        and exists(select 1 from public.v1_company_material_request_decisions d where d.request_id=new.request_id and d.decision='approved')
    ) recipients where recipient is not null and recipient<>new.actor_auth_user_id and v_request.submitted_at is not null;
    return new;
  end if;
  if new.event_type in ('company_request_approved','company_return_submitted','company_request_remainder_withdrawn','company_request_cancelled') then
    v_code:=case new.event_type when 'company_request_approved' then 'company_material_request_approved'
      when 'company_return_submitted' then 'company_material_request_return_submitted'
      when 'company_request_cancelled' then 'company_material_request_cancelled'
      else 'company_material_request_remainder_withdrawn' end;
    insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
      select p.auth_user_id,v_code,'company_material_request',new.request_id,null::uuid
      from public.v1_profiles p join auth.users u on u.id=p.auth_user_id
      where p.is_active and u.raw_app_meta_data->>'role'='procurement' and p.auth_user_id<>new.actor_auth_user_id
      and v_request.submitted_at is not null
      and (new.event_type<>'company_request_cancelled' or exists(select 1 from public.v1_company_material_request_decisions d where d.request_id=new.request_id and d.decision='approved'));
    if new.event_type in ('company_request_approved','company_return_submitted','company_request_cancelled') then return new; end if;
  end if;
  case new.event_type
    when 'company_request_resubmitted' then v_recipient:=v_request.approver_auth_user_id; v_code:='company_material_request_approval_requested';
    when 'company_supply_plan_saved' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_supply_planned';
    when 'company_material_dispatched' then v_recipient:=v_request.authorized_receiver_auth_user_id; v_code:='company_material_request_dispatched';
    when 'company_receipt_confirmed' then v_recipient:=v_request.beneficiary_auth_user_id; v_code:='company_material_request_received';
    when 'company_beneficiary_handover_confirmed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_handed_over';
    when 'company_return_confirmed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_return_confirmed';
    when 'company_return_rejected' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_return_rejected';
    when 'company_request_remainder_withdrawn' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_remainder_withdrawn';
    when 'company_request_closed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_closed';
    else return new;
  end case;
  if v_recipient is not null and v_recipient<>new.actor_auth_user_id then
    insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
      values(v_recipient,v_code,'company_material_request',new.request_id,null);
  end if;
  return new;
end $$;
create or replace function public.v1_company_material_request_assigned_approver(
  p_request_id uuid,
  p_require_pending boolean default true
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and public.v1_current_exact_role() in ('project_engineer','senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller','admin')
    and exists (
      select 1
      from public.v1_company_material_requests request_record
      where request_record.id = p_request_id
        and (not p_require_pending
          or request_record.state = 'awaiting_company_approval')
        and request_record.approver_auth_user_id = auth.uid()
        and request_record.created_by_auth_user_id <> auth.uid()
        and request_record.beneficiary_auth_user_id <> auth.uid()
        and request_record.authorized_receiver_auth_user_id <> auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(), request_record.category_id,
          request_record.responsible_unit_id, 'approver'
        )
    );
$$;
commit;
