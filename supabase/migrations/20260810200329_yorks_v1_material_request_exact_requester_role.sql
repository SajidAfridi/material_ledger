-- Material Request workflow ownership intentionally uses the canonical
-- project-engineer role for organization-wide engineers.  That normalized
-- role must not replace the requester's exact server-controlled job role in
-- controlled documents, request details, or audit-facing projections.
begin;

alter table public.v1_material_requests
  add column if not exists requester_exact_role text;

alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_requester_exact_role_check;

alter table public.v1_material_requests
  add constraint v1_material_requests_requester_exact_role_check
  check (requester_exact_role is null or requester_exact_role in (
    'project_engineer',
    'site_engineer',
    'senior_mechanical_engineer',
    'project_manager',
    'procurement',
    'admin'
  ));

comment on column public.v1_material_requests.requester_exact_role is
  'Immutable exact Auth role captured at Material Request submission. requester_project_role remains the canonical workflow role.';

-- Historical records are repaired only when their immutable submission audit
-- already captured the exact role.  Do not infer a historical role from a
-- current profile or from today's Auth metadata: those can legitimately have
-- changed since submission.
with historic_submission_roles as (
  select distinct on (request_record.id)
    request_record.id,
    audit.actor_exact_role
  from public.v1_material_requests request_record
  join public.v1_audit_events audit
    on audit.entity_id = request_record.id
   and audit.actor_auth_user_id = request_record.created_by_auth_user_id
  where request_record.requester_exact_role is null
    and audit.event_type = 'material_request_submitted'
    and audit.entity_type = 'material_request'
    and audit.actor_exact_role in (
      'project_engineer',
      'site_engineer',
      'senior_mechanical_engineer',
      'project_manager',
      'procurement',
      'admin'
    )
  order by request_record.id, audit.occurred_at asc, audit.id asc
)
update public.v1_material_requests request_record
   set requester_exact_role = historic_submission_roles.actor_exact_role
  from historic_submission_roles
 where request_record.id = historic_submission_roles.id;

create or replace function public.v1_material_request_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_include_commercial boolean := public.v1_has_capability('view_commercials');
  v_result jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_NOT_READABLE' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'job_contract_reference', project.job_contract_reference,
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
    'requester_exact_role', request_record.requester_exact_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(
        public.v1_material_request_line_projection(line_record.id, v_include_commercial)
        order by line_record.display_order
      )
      from public.v1_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_result
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;
  return v_result;
end;
$$;

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
    'job_contract_reference', project.job_contract_reference,
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
    'requester_exact_role', request_record.requester_exact_role,
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

create or replace function public.v1_submit_material_request(
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
  v_request_id uuid;
  v_expected_version integer;
  v_request public.v1_material_requests%rowtype;
  v_project public.v1_projects%rowtype;
  v_project_role text;
  v_exact_role text;
  v_sequence integer;
  v_request_number text;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_display_name text;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'], 'submit_material_request'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_request_id is null or v_expected_version is null or v_expected_version < 1 then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or v_request.created_by_auth_user_id <> v_actor then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  select * into v_project from public.v1_projects project
  where project.id = v_request.project_id for update;
  if not found or v_project.state <> 'active'
    or not public.v1_can_create_material_request(v_project.id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_SUBMITTABLE' using errcode = '42501';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_submit_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.state <> 'draft' then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if not exists (
    select 1 from public.v1_project_scopes scope
    where scope.id = v_request.scope_id and scope.project_id = v_project.id
      and scope.is_active
  ) then
    raise exception 'V1_MATERIAL_REQUEST_SCOPE_INVALID' using errcode = '22023';
  end if;
  if exists (
    select 1
    from public.v1_material_request_lines line_record
    join public.v1_boq_groups group_record
      on group_record.id = line_record.source_boq_group_id
    where line_record.request_id = v_request.id
      and line_record.source_kind = 'boq'
      and group_record.scope_id is distinct from v_request.scope_id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_BOQ_SCOPE_RECONCILIATION_REQUIRED'
      using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.v1_material_request_lines line_record
    where line_record.request_id = v_request.id
  ) then
    raise exception 'V1_MATERIAL_REQUEST_LINES_REQUIRED' using errcode = '22023';
  end if;
  if v_request.timing = 'scheduled' and v_request.scheduled_date is null then
    raise exception 'V1_MATERIAL_REQUEST_SCHEDULED_DATE_REQUIRED' using errcode = '22023';
  end if;

  select member.project_role into v_project_role
  from public.v1_project_members member
  where member.project_id = v_project.id and member.member_auth_user_id = v_actor
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null or member.effective_to > clock_timestamp())
  order by case member.project_role when 'project_engineer' then 0 else 1 end
  limit 1;
  if v_project_role is null
    and public.v1_current_role() <> 'admin'
    and not public.v1_has_active_project_membership(v_project.id, v_actor) then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;
  v_exact_role := public.v1_current_exact_role();
  if not public.v1_is_valid_role(v_exact_role) then
    raise exception 'V1_MATERIAL_REQUEST_SUBMIT_DENIED' using errcode = '42501';
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into v_display_name
  from public.v1_profiles profile where profile.auth_user_id = v_actor;

  insert into public.v1_material_request_reference_counters (
    project_id, next_request_sequence, updated_at
  ) values (v_project.id, 2, clock_timestamp())
  on conflict (project_id) do update set
    next_request_sequence = public.v1_material_request_reference_counters.next_request_sequence + 1,
    updated_at = clock_timestamp()
  returning next_request_sequence - 1 into v_sequence;
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || lpad(v_sequence::text, 3, '0');
  v_before := public.v1_material_request_projection(v_request.id);

  update public.v1_material_requests
     set request_number = v_request_number,
         state = 'submitted',
         requester_display_name = v_display_name,
         requester_project_role = coalesce(v_project_role, 'project_engineer'),
         requester_exact_role = v_exact_role,
         current_action_owner_role = 'procurement',
         current_action_code = 'arrangement_required',
         submitted_at = clock_timestamp(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_request.id;
  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_submitted', 'material_request', v_request.id, v_project.id,
    v_before,
    jsonb_build_object(
      'request_number', v_request_number,
      'record_version', v_expected_version + 1,
      'line_count', (select count(*) from public.v1_material_request_lines
        where request_id = v_request.id),
      'state', 'submitted',
      'current_action_owner_role', 'procurement'
    ),
    null, p_idempotency_key
  );
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id, created_at
  )
  select profile.auth_user_id, 'material_request_submitted', 'material_request',
    v_request.id, v_project.id, clock_timestamp()
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  perform public.v1_complete_idempotency(
    'v1_submit_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_submit_material_request(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_submit_material_request(jsonb, uuid)
  to authenticated;

commit;
