-- Company Material Requests T02: independent approval review only.
--
-- This additive slice deliberately stops at approved demand. Procurement,
-- reservation, dispatch, receipt, beneficiary issue, return and closure need
-- separately approved company quantity/custody rules. No project workflow or
-- stock relation is modified here.
--
-- Data preservation: submitted T01 rows retain their IDs, references, lines,
-- routing snapshots and events. Decisions append immutable evidence.
-- Rollback: keep the new states/decision history and disable the existing
-- feature flag. Never delete decision, event or notification history.

begin;

alter table public.v1_company_material_requests
  drop constraint if exists v1_company_material_requests_state_check;
alter table public.v1_company_material_requests
  add constraint v1_company_material_requests_state_check check (state in (
    'draft', 'awaiting_company_approval', 'approved_for_procurement',
    'returned_for_changes', 'rejected'
  ));

alter table public.v1_company_material_requests
  drop constraint if exists v1_company_material_requests_check1;
alter table public.v1_company_material_requests
  add constraint v1_company_material_requests_submission_shape_check check (
    (state = 'draft' and request_number is null and submitted_at is null
      and approval_route_id is null and approval_policy_version is null
      and approver_auth_user_id is null and approver_display_name is null)
    or (state <> 'draft' and request_number is not null
      and submitted_at is not null and approval_route_id is not null
      and approval_policy_version is not null and approver_auth_user_id is not null
      and approver_display_name is not null)
  );

alter table public.v1_company_material_request_events
  drop constraint if exists v1_company_material_request_events_event_type_check;
alter table public.v1_company_material_request_events
  add constraint v1_company_material_request_events_event_type_check
  check (event_type in (
    'company_request_draft_created', 'company_request_submitted',
    'company_request_approved', 'company_request_returned',
    'company_request_rejected'
  ));

create table if not exists public.v1_company_material_request_decisions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  request_record_version integer not null check (request_record_version > 0),
  decision text not null check (decision in ('approved', 'returned', 'rejected')),
  reason text check (
    reason is null or (btrim(reason) <> '' and char_length(reason) <= 2000)
  ),
  approval_route_id uuid not null
    references public.v1_company_material_request_approval_routes (id)
    on delete restrict,
  approval_policy_version text not null check (
    btrim(approval_policy_version) <> ''
  ),
  decided_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  decided_by_display_name text not null check (btrim(decided_by_display_name) <> ''),
  decided_by_exact_role text not null check (btrim(decided_by_exact_role) <> ''),
  idempotency_key uuid not null,
  decided_at timestamptz not null default clock_timestamp(),
  unique (request_id, request_record_version),
  unique (decided_by_auth_user_id, idempotency_key),
  check (
    (decision = 'approved' and reason is null)
    or (decision in ('returned', 'rejected') and reason is not null)
  )
);

create index if not exists v1_company_material_request_decisions_request_idx
  on public.v1_company_material_request_decisions (request_id, decided_at desc);

alter table public.v1_company_material_request_decisions enable row level security;
revoke all on table public.v1_company_material_request_decisions
  from public, anon, authenticated;
grant all on table public.v1_company_material_request_decisions to service_role;

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
    and public.v1_current_role() <> 'procurement'
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

create or replace function public.v1_company_material_request_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.v1_company_material_request_readable(p_request_id) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'request_number', request_record.request_number,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'category_id', category.id,
    'category_code', category.category_code,
    'category_name', category.display_name,
    'responsible_unit_id', unit_record.id,
    'responsible_unit_code', unit_record.unit_code,
    'responsible_unit_name', unit_record.display_name,
    'purpose', request_record.purpose,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_collection_point', request_record.delivery_collection_point,
    'beneficiary_auth_user_id', request_record.beneficiary_auth_user_id,
    'beneficiary_display_name', request_record.beneficiary_display_name,
    'authorized_receiver_auth_user_id', request_record.authorized_receiver_auth_user_id,
    'authorized_receiver_display_name', request_record.authorized_receiver_display_name,
    'requester_display_name', request_record.requester_display_name,
    'requester_exact_role', request_record.requester_exact_role,
    'approver_auth_user_id', request_record.approver_auth_user_id,
    'approver_display_name', request_record.approver_display_name,
    'approval_policy_version', request_record.approval_policy_version,
    'submitted_at', request_record.submitted_at,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'can_decide', public.v1_company_material_request_assigned_approver(
      request_record.id, true
    ),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', line_record.id,
        'display_order', line_record.display_order,
        'item_description', line_record.item_description,
        'brand_origin', line_record.brand_origin,
        'requested_qty', line_record.requested_qty::text,
        'unit', line_record.unit
      ) order by line_record.display_order)
      from public.v1_company_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb),
    'decisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', decision_record.id,
        'decision', decision_record.decision,
        'reason', decision_record.reason,
        'request_record_version', decision_record.request_record_version,
        'decided_by_display_name', decision_record.decided_by_display_name,
        'decided_by_exact_role', decision_record.decided_by_exact_role,
        'decided_at', decision_record.decided_at
      ) order by decision_record.decided_at)
      from public.v1_company_material_request_decisions decision_record
      where decision_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_company_material_requests request_record
  join public.v1_company_material_request_categories category
    on category.id = request_record.category_id
  join public.v1_company_material_request_units unit_record
    on unit_record.id = request_record.responsible_unit_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

create or replace function public.v1_list_company_material_request_approval_inbox()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_result jsonb;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_INBOX_DENIED' using errcode = '42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', request_record.id,
    'request_number', request_record.request_number,
    'record_version', request_record.record_version,
    'state', request_record.state,
    'category_name', category.display_name,
    'responsible_unit_name', unit_record.display_name,
    'purpose', request_record.purpose,
    'requester_display_name', request_record.requester_display_name,
    'beneficiary_display_name', request_record.beneficiary_display_name,
    'submitted_at', request_record.submitted_at,
    'line_count', (
      select count(*) from public.v1_company_material_request_lines line_record
      where line_record.request_id = request_record.id
    )
  ) order by request_record.submitted_at, request_record.id), '[]'::jsonb)
  into v_result
  from public.v1_company_material_requests request_record
  join public.v1_company_material_request_categories category
    on category.id = request_record.category_id
  join public.v1_company_material_request_units unit_record
    on unit_record.id = request_record.responsible_unit_id
  where request_record.state = 'awaiting_company_approval'
    and request_record.approver_auth_user_id = v_actor
    and public.v1_company_material_request_assigned_approver(
      request_record.id, true
    );
  return v_result;
end;
$$;

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
  v_exact_role text := public.v1_current_role();
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

revoke all on function public.v1_company_material_request_assigned_approver(uuid,boolean)
  from public, anon, authenticated;
grant execute on function public.v1_company_material_request_assigned_approver(uuid,boolean)
  to service_role;

revoke all on function public.v1_list_company_material_request_approval_inbox(),
  public.v1_decide_company_material_request(jsonb,uuid)
from public, anon, authenticated;
grant execute on function public.v1_list_company_material_request_approval_inbox(),
  public.v1_decide_company_material_request(jsonb,uuid)
to authenticated;

-- Reassert the existing projection grant after CREATE OR REPLACE.
revoke all on function public.v1_company_material_request_projection(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_company_material_request_projection(uuid)
  to authenticated;

commit;
