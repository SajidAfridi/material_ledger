-- Yorks V1 Material Request action intelligence.
--
-- This release adds read-only operational projections over the already
-- authoritative request, arrangement, reservation, dispatch, receipt and
-- return facts. It does not rewrite a request state, quantity, membership,
-- commercial value or historical event.
--
-- Action-age is deliberately measured from the request row's latest trusted
-- workflow update. No synthetic SLA or action due date is invented here. The
-- latter remains a business-policy decision and is reported as unconfigured.
-- Rollback is forward-only: restore the former read functions in a corrective
-- migration. Never remove underlying workflow or audit rows.

create index if not exists v1_arrangement_lines_external_due_idx
  on public.v1_procurement_arrangement_lines (external_expected_date)
  where source_kind = 'external_supplier'
    and external_expected_date is not null;

create index if not exists v1_material_returns_requested_due_idx
  on public.v1_material_returns (requested_return_date, project_id)
  where requested_return_date is not null
    and state not in ('confirmed', 'rejected', 'cancelled');

create or replace function public.v1_material_request_actor_has_current_action(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found or not public.v1_material_request_participant(
    p_request_id, auth.uid()
  ) then
    return false;
  end if;

  if v_request.state = 'draft' then
    return v_request.created_by_auth_user_id = auth.uid();
  elsif v_request.state in ('submitted', 'awaiting_request_approval') then
    return public.v1_can_decide_material_request(p_request_id);
  elsif v_request.state = 'changes_requested' then
    return public.v1_can_edit_material_request_before_approval(p_request_id);
  elsif v_request.state in ('approved_for_arrangement', 'arranging') then
    return public.v1_can_arrange_material_request(p_request_id);
  elsif v_request.state = 'awaiting_approval' then
    return public.v1_can_decide_arrangement(p_request_id);
  elsif v_request.current_action_code = 'receipt_review_required'
    or v_request.state = 'dispatched' then
    return public.v1_can_confirm_material_receipt(p_request_id);
  elsif v_request.current_action_code = 'material_request_close_review'
    or v_request.state = 'received' then
    return public.v1_can_close_material_request(p_request_id);
  elsif v_request.state in (
    'approved', 'partially_dispatched', 'partially_received'
  ) then
    return public.v1_can_dispatch_material_request(p_request_id);
  end if;
  return false;
end;
$$;

revoke all on function
  public.v1_material_request_actor_has_current_action(uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_material_request_actor_has_current_action(uuid)
  to service_role;

comment on function public.v1_material_request_actor_has_current_action(uuid)
is 'Server-authoritative current-action eligibility used by the MR My Work register.';

create or replace function public.v1_material_request_exception_codes(
  p_request_id uuid
) returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_state text;
  v_active boolean;
  v_codes text[] := array[]::text[];
  v_has_missing boolean := false;
  v_has_damaged boolean := false;
  v_has_replacement boolean := false;
begin
  select request_record.state into v_state
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if v_state is null then
    return v_codes;
  end if;
  v_active := v_state not in ('closed', 'cancelled');

  if v_active and exists (
    select 1
    from public.v1_procurement_arrangements arrangement
    join public.v1_procurement_arrangement_lines line
      on line.arrangement_id = arrangement.id
    where arrangement.request_id = p_request_id
      and arrangement.is_current
      and line.decision = 'unavailable'
  ) then
    v_codes := array_append(v_codes, 'unavailable_supply');
  end if;

  if v_active and exists (
    select 1
    from public.v1_procurement_arrangements arrangement
    join public.v1_procurement_arrangement_lines line
      on line.arrangement_id = arrangement.id
    where arrangement.request_id = p_request_id
      and arrangement.is_current
      and line.decision = 'partial'
  ) then
    v_codes := array_append(v_codes, 'partial_arrangement');
  end if;

  if v_active and exists (
    select 1
    from public.v1_procurement_arrangements arrangement
    join public.v1_procurement_arrangement_lines line
      on line.arrangement_id = arrangement.id
    where arrangement.request_id = p_request_id
      and arrangement.is_current
      and line.source_kind = 'external_supplier'
      and line.external_source_ready is false
      and line.external_expected_date < current_date
  ) then
    v_codes := array_append(v_codes, 'late_external_supply');
  end if;

  if v_active then
    with line_facts as (
      select request_line.id,
        coalesce(approval.approved_qty, 0::numeric) approved_qty,
        coalesce(receipts.good_qty, 0::numeric) good_qty,
        coalesce(receipts.missing_qty, 0::numeric) missing_qty,
        coalesce(receipts.damaged_qty, 0::numeric) damaged_qty
      from public.v1_material_request_lines request_line
      left join public.v1_material_request_line_approvals approval
        on approval.request_line_id = request_line.id
      left join lateral (
        select coalesce(sum(review_line.good_qty), 0::numeric) good_qty,
          coalesce(sum(review_line.missing_qty), 0::numeric) missing_qty,
          coalesce(sum(review_line.damaged_qty), 0::numeric) damaged_qty
        from public.v1_receipt_review_lines review_line
        join public.v1_receipt_reviews review
          on review.id = review_line.receipt_review_id
         and review.state = 'confirmed'
        join public.v1_material_dispatch_lines dispatch_line
          on dispatch_line.id = review_line.dispatch_line_id
        where dispatch_line.request_line_id = request_line.id
      ) receipts on true
      where request_line.request_id = p_request_id
    )
    select
      coalesce(bool_or(
        missing_qty > 0 and approved_qty - good_qty > 0
      ), false),
      coalesce(bool_or(
        damaged_qty > 0 and approved_qty - good_qty > 0
      ), false),
      coalesce(bool_or(
        least(
          missing_qty + damaged_qty,
          greatest(approved_qty - good_qty, 0::numeric)
        ) > 0
      ), false)
    into v_has_missing, v_has_damaged, v_has_replacement
    from line_facts;
  end if;

  if v_has_missing then
    v_codes := array_append(v_codes, 'missing_receipt');
  end if;
  if v_has_damaged then
    v_codes := array_append(v_codes, 'damaged_receipt');
  end if;
  if v_has_replacement then
    v_codes := array_append(v_codes, 'replacement_required');
  end if;

  if exists (
    select 1
    from public.v1_material_returns material_return
    where material_return.request_id = p_request_id
      and material_return.requested_return_date < current_date
      and material_return.state not in ('confirmed', 'rejected', 'cancelled')
  ) then
    v_codes := array_append(v_codes, 'overdue_return');
  end if;

  return v_codes;
end;
$$;

revoke all on function public.v1_material_request_exception_codes(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_material_request_exception_codes(uuid)
  to service_role;

comment on function public.v1_material_request_exception_codes(uuid)
is 'Current unresolved non-commercial MR exception codes for protected registers.';

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
      current_arrangement.arrangement_line_id,
      current_arrangement.arrangement_status,
      current_arrangement.decision as arrangement_decision,
      current_arrangement.source_kind,
      current_arrangement.arranged_qty,
      current_arrangement.reason as arrangement_reason,
      coalesce(approval.approved_qty, 0::numeric) as approved_qty,
      coalesce(reservation_totals.reserved_qty, 0::numeric) as reserved_qty,
      coalesce(dispatch_totals.dispatched_qty, 0::numeric) as dispatched_qty,
      coalesce(dispatch_totals.in_transit_qty, 0::numeric) as in_transit_qty,
      coalesce(review_totals.good_qty, 0::numeric) as good_qty,
      coalesce(review_totals.missing_qty, 0::numeric) as missing_qty,
      coalesce(review_totals.damaged_qty, 0::numeric) as damaged_qty,
      coalesce(return_totals.returned_qty, 0::numeric) as returned_qty
    from public.v1_material_request_lines request_line
    left join lateral (
      select arrangement_line.id as arrangement_line_id,
        arrangement.status as arrangement_status,
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
      select coalesce(sum(greatest(
        reservation.reserved_qty - reservation.consumed_qty, 0::numeric
      )) filter (where reservation.state in (
        'active', 'partially_consumed'
      )), 0::numeric) as reserved_qty
      from public.v1_inventory_reservations reservation
      where reservation.arrangement_line_id =
        current_arrangement.arrangement_line_id
    ) reservation_totals on true
    left join lateral (
      select
        coalesce(sum(dispatch_line.dispatched_qty), 0::numeric) dispatched_qty,
        coalesce(sum(dispatch_line.dispatched_qty) filter (
          where dispatch.state = 'receipt_pending'
        ), 0::numeric) in_transit_qty
      from public.v1_material_dispatch_lines dispatch_line
      join public.v1_material_dispatches dispatch
        on dispatch.id = dispatch_line.dispatch_id
      where dispatch_line.request_line_id = request_line.id
    ) dispatch_totals on true
    left join lateral (
      select
        coalesce(sum(review_line.good_qty), 0::numeric) good_qty,
        coalesce(sum(review_line.missing_qty), 0::numeric) missing_qty,
        coalesce(sum(review_line.damaged_qty), 0::numeric) damaged_qty
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review
        on review.id = review_line.receipt_review_id
       and review.state = 'confirmed'
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      where dispatch_line.request_line_id = request_line.id
    ) review_totals on true
    left join lateral (
      select coalesce(sum(coalesce(
        return_line.received_good_quantity,
        return_line.return_quantity
      )), 0::numeric) returned_qty
      from public.v1_material_return_lines return_line
      join public.v1_material_returns material_return
        on material_return.id = return_line.material_return_id
       and material_return.state = 'confirmed'
      where return_line.request_line_id = request_line.id
        and return_line.origin_kind = 'delivered'
    ) return_totals on true
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
      greatest(requested_qty - good_qty - in_transit_qty, 0::numeric)
        as still_needed_qty,
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
    'reserved_qty', reserved_qty::text,
    'dispatched_qty', dispatched_qty::text,
    'in_transit_qty', in_transit_qty::text,
    'reviewed_good_qty', good_qty::text,
    'reviewed_missing_qty', missing_qty::text,
    'reviewed_damaged_qty', damaged_qty::text,
    'good_qty', good_qty::text,
    'missing_qty', missing_qty::text,
    'damaged_qty', damaged_qty::text,
    'returned_qty', returned_qty::text,
    'remaining_approved_qty', remaining_approved_qty::text,
    'still_needed_qty', still_needed_qty::text,
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
      when good_qty >= approved_qty and in_transit_qty = 0
        then 'Fully received'
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

create or replace function public.v1_material_request_operations_dashboard(
  p_project_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_REQUEST_OPERATIONS_DENIED'
      using errcode = '42501';
  end if;
  if p_project_id is not null
    and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE'
      using errcode = '42501';
  end if;

  with readable as materialized (
    select request_record.*,
      public.v1_material_request_actor_has_current_action(
        request_record.id
      ) actor_can_act,
      public.v1_material_request_exception_codes(
        request_record.id
      ) exception_codes
    from public.v1_material_requests request_record
    where public.v1_material_request_participant(
        request_record.id, auth.uid()
      )
      and (p_project_id is null
        or request_record.project_id = p_project_id)
  ), request_approval as materialized (
    select readable.id request_id,
      min(decision.created_at) approved_at
    from readable
    join public.v1_material_request_decisions decision
      on decision.request_id = readable.id
     and decision.decision = 'approved'
    group by readable.id
  ), arrangement as materialized (
    select approval.request_id, min(arrangement.saved_at) saved_at
    from request_approval approval
    join public.v1_procurement_arrangements arrangement
      on arrangement.request_id = approval.request_id
     and arrangement.saved_at is not null
     and arrangement.saved_at >= approval.approved_at
    group by approval.request_id
  ), warehouse_approved as (
    select coalesce(sum(approval.approved_qty), 0::numeric) quantity
    from readable
    join public.v1_material_request_lines request_line
      on request_line.request_id = readable.id
    join public.v1_material_request_line_approvals approval
      on approval.request_line_id = request_line.id
    join public.v1_procurement_arrangement_lines arrangement_line
      on arrangement_line.id = approval.arrangement_line_id
    where arrangement_line.source_kind = 'warehouse'
  ), warehouse_good as (
    select coalesce(sum(review_line.good_qty), 0::numeric) quantity
    from readable
    join public.v1_material_dispatches dispatch
      on dispatch.request_id = readable.id
    join public.v1_material_dispatch_lines dispatch_line
      on dispatch_line.dispatch_id = dispatch.id
     and dispatch_line.source_kind = 'warehouse'
    join public.v1_receipt_review_lines review_line
      on review_line.dispatch_line_id = dispatch_line.id
    join public.v1_receipt_reviews review
      on review.id = review_line.receipt_review_id
     and review.state = 'confirmed'
  ), replacement as (
    select coalesce(sum(least(
      coalesce(receipts.missing_qty, 0::numeric)
        + coalesce(receipts.damaged_qty, 0::numeric),
      greatest(
        coalesce(approval.approved_qty, 0::numeric)
          - coalesce(receipts.good_qty, 0::numeric),
        0::numeric
      )
    )), 0::numeric) quantity
    from readable
    join public.v1_material_request_lines request_line
      on request_line.request_id = readable.id
    left join public.v1_material_request_line_approvals approval
      on approval.request_line_id = request_line.id
    left join lateral (
      select coalesce(sum(review_line.good_qty), 0::numeric) good_qty,
        coalesce(sum(review_line.missing_qty), 0::numeric) missing_qty,
        coalesce(sum(review_line.damaged_qty), 0::numeric) damaged_qty
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review
        on review.id = review_line.receipt_review_id
       and review.state = 'confirmed'
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      where dispatch_line.request_line_id = request_line.id
    ) receipts on true
  ), return_closure as (
    select material_return.id,
      extract(epoch from (
        material_return.decided_at - material_return.submitted_at
      )) / 3600.0 hours
    from readable
    join public.v1_material_returns material_return
      on material_return.request_id = readable.id
    where material_return.state = 'confirmed'
      and material_return.submitted_at is not null
      and material_return.decided_at is not null
  ), receipt_turnaround as (
    select dispatch.id,
      extract(epoch from (
        dispatch.receipt_reviewed_at - dispatch.dispatched_at
      )) / 3600.0 hours
    from readable
    join public.v1_material_dispatches dispatch
      on dispatch.request_id = readable.id
    where dispatch.receipt_reviewed_at is not null
  )
  select jsonb_build_object(
    'my_work_count', count(*) filter (where actor_can_act),
    'exception_request_count', count(*) filter (
      where cardinality(exception_codes) > 0
    ),
    'required_date_overdue_count', count(*) filter (
      where timing = 'scheduled'
        and scheduled_date < current_date
        and state not in ('received', 'closed', 'cancelled')
    ),
    'action_due_policy', 'not_configured',
    'average_approval_hours', (
      select round(avg(extract(epoch from (
        approval.approved_at - request_record.submitted_at
      )) / 3600.0)::numeric, 2)
      from request_approval approval
      join readable request_record on request_record.id = approval.request_id
      where request_record.submitted_at is not null
    ),
    'average_arrangement_hours', (
      select round(avg(extract(epoch from (
        arrangement.saved_at - approval.approved_at
      )) / 3600.0)::numeric, 2)
      from arrangement
      join request_approval approval
        on approval.request_id = arrangement.request_id
    ),
    'warehouse_fill_rate_percent', (
      select case when warehouse_approved.quantity = 0 then null
        else round(least(
          warehouse_good.quantity / warehouse_approved.quantity * 100,
          100::numeric
        ), 2) end
      from warehouse_approved cross join warehouse_good
    ),
    'average_receipt_turnaround_hours', (
      select round(avg(hours)::numeric, 2) from receipt_turnaround
    ),
    'outstanding_replacement_quantity', (
      select quantity::text from replacement
    ),
    'average_return_closure_hours', (
      select round(avg(hours)::numeric, 2) from return_closure
    )
  ) into v_result
  from readable;

  return v_result;
end;
$$;

revoke all on function public.v1_material_request_operations_dashboard(uuid)
  from public, anon;
grant execute on function public.v1_material_request_operations_dashboard(uuid)
  to authenticated, service_role;

comment on function public.v1_material_request_operations_dashboard(uuid)
is 'Authorized non-commercial MR operational metrics over trusted workflow facts.';

create or replace function public.v1_list_material_request_summaries(
  p_project_id uuid default null,
  p_search text default null,
  p_states text[] default null,
  p_scope_id uuid default null,
  p_requester text default null,
  p_updated_after timestamptz default null,
  p_attention_only boolean default false,
  p_metric text default 'all',
  p_sort text default 'updated_desc',
  p_limit integer default 15,
  p_offset integer default 0,
  p_register_view text default 'total'
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 15), 1), 100);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
  v_result jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or p_sort not in ('updated_desc', 'updated_asc')
    or p_metric not in (
      'all', 'open', 'in_progress', 'dispatched', 'received', 'closed'
    )
    or p_register_view not in (
      'total', 'mine', 'assigned', 'my_work', 'exceptions'
    ) then
    raise exception 'V1_MATERIAL_REQUEST_SUMMARY_LIST_DENIED'
      using errcode = '42501';
  end if;
  if p_project_id is not null
    and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE'
      using errcode = '42501';
  end if;

  with readable as materialized (
    select request.*, project.project_ref, project.name as project_name,
      project.job_contract_reference, scope.name as scope_name,
      (select count(*)::integer
       from public.v1_material_request_lines line
       where line.request_id = request.id) as item_count,
      public.v1_material_request_work_assignment_projection(
        request.id
      ) as work_assignment,
      public.v1_material_request_change_summary(request.id) as change_summary,
      public.v1_material_request_actor_has_current_action(
        request.id
      ) as actor_can_act,
      public.v1_material_request_exception_codes(
        request.id
      ) as exception_codes
    from public.v1_material_requests request
    join public.v1_projects project on project.id = request.project_id
    join public.v1_project_scopes scope on scope.id = request.scope_id
    where public.v1_material_request_participant(request.id, auth.uid())
      and (p_project_id is null or request.project_id = p_project_id)
  ), authorized as materialized (
    select * from readable request
    where p_register_view = 'total'
      or (p_register_view = 'mine'
        and request.created_by_auth_user_id = auth.uid())
      or (p_register_view = 'assigned' and exists (
        select 1
        from public.v1_material_request_work_assignments assignment
        where assignment.request_id = request.id
          and assignment.assignee_auth_user_id = auth.uid()
      ))
      or (p_register_view = 'my_work' and request.actor_can_act)
      or (p_register_view = 'exceptions'
        and cardinality(request.exception_codes) > 0)
  ), filtered as materialized (
    select * from authorized request
    where (p_states is null or request.state = any(p_states))
      and (p_scope_id is null or request.scope_id = p_scope_id)
      and (p_requester is null
        or request.requester_display_name = p_requester)
      and (p_updated_after is null or request.updated_at >= p_updated_after)
      and (not p_attention_only or (
        request.state not in ('draft', 'closed', 'cancelled') and (
          coalesce(request.current_action_code, '') <> ''
          or request.state in (
            'awaiting_request_approval', 'changes_requested', 'arranging',
            'dispatched', 'partially_dispatched', 'partially_received',
            'received'
          )
        )
      ))
      and (p_metric = 'all'
        or (p_metric = 'open' and request.state in (
          'draft', 'submitted', 'awaiting_request_approval',
          'changes_requested'
        ))
        or (p_metric = 'in_progress' and request.state not in (
          'draft', 'submitted', 'awaiting_request_approval',
          'changes_requested', 'partially_dispatched', 'dispatched',
          'partially_received', 'received', 'closed', 'cancelled'
        ))
        or (p_metric = 'dispatched' and request.state in (
          'partially_dispatched', 'dispatched'
        ))
        or (p_metric = 'received' and request.state in (
          'partially_received', 'received'
        ))
        or (p_metric = 'closed' and request.state in ('closed', 'cancelled'))
      )
      and (v_search is null
        or request.request_number ilike '%' || v_search || '%'
        or coalesce(request.title, '') ilike '%' || v_search || '%'
        or request.project_ref ilike '%' || v_search || '%'
        or request.project_name ilike '%' || v_search || '%'
        or request.scope_name ilike '%' || v_search || '%'
        or coalesce(request.requester_display_name, '')
          ilike '%' || v_search || '%'
        or exists (
          select 1 from public.v1_material_request_lines line
          where line.request_id = request.id
            and line.item_description ilike '%' || v_search || '%'
        )
      )
  ), page as materialized (
    select * from filtered request
    order by
      case when p_sort = 'updated_desc' then request.updated_at end desc,
      case when p_sort = 'updated_asc' then request.updated_at end asc,
      request.id
    limit v_limit offset v_offset
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'project_id', page.project_id,
        'project_ref', page.project_ref,
        'project_name', page.project_name,
        'job_contract_reference', page.job_contract_reference,
        'scope_id', page.scope_id,
        'scope_name', page.scope_name,
        'state', page.state,
        'record_version', page.record_version,
        'request_number', page.request_number,
        'title', page.title,
        'timing', page.timing,
        'scheduled_date', page.scheduled_date,
        'delivery_note', page.delivery_note,
        'requester_display_name', page.requester_display_name,
        'requester_project_role', page.requester_project_role,
        'requester_exact_role', page.requester_exact_role,
        'current_action_owner_role', page.current_action_owner_role,
        'current_action_code', page.current_action_code,
        'current_action_started_at', page.updated_at,
        'current_action_age_hours', greatest(
          extract(epoch from (clock_timestamp() - page.updated_at)) / 3600,
          0
        ),
        'required_on_site_overdue', page.timing = 'scheduled'
          and page.scheduled_date < current_date
          and page.state not in ('received', 'closed', 'cancelled'),
        'actor_can_act', page.actor_can_act,
        'exception_codes', to_jsonb(page.exception_codes),
        'item_count', page.item_count,
        'work_assignment', page.work_assignment,
        'change_summary', page.change_summary,
        'submitted_at', page.submitted_at,
        'created_at', page.created_at,
        'updated_at', page.updated_at
      ) order by
        case when p_sort = 'updated_desc' then page.updated_at end desc,
        case when p_sort = 'updated_asc' then page.updated_at end asc,
        page.id)
      from page
    ), '[]'::jsonb),
    'total_count', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset,
    'has_more', v_offset + (select count(*) from page)
      < (select count(*) from filtered),
    'metrics', (select jsonb_build_object(
      'total', count(*),
      'open', count(*) filter (where state in (
        'draft', 'submitted', 'awaiting_request_approval', 'changes_requested'
      )),
      'in_progress', count(*) filter (where state not in (
        'draft', 'submitted', 'awaiting_request_approval',
        'changes_requested', 'partially_dispatched', 'dispatched',
        'partially_received', 'received', 'closed', 'cancelled'
      )),
      'dispatched', count(*) filter (where state in (
        'partially_dispatched', 'dispatched'
      )),
      'received', count(*) filter (where state in (
        'partially_received', 'received'
      )),
      'closed', count(*) filter (where state in ('closed', 'cancelled')),
      'my_work', count(*) filter (where actor_can_act),
      'exceptions', count(*) filter (
        where cardinality(exception_codes) > 0
      ),
      'required_date_overdue', count(*) filter (
        where timing = 'scheduled'
          and scheduled_date < current_date
          and state not in ('received', 'closed', 'cancelled')
      )
    ) from readable)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text
) from public, anon, authenticated;
grant execute on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text
) to authenticated, service_role;

comment on function public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text
) is 'Authorized paginated MR register with creator, coordinator, My Work and Exceptions views.';

notify pgrst, 'reload schema';
