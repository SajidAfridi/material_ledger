-- Yorks V1 bounded startup projection.
--
-- This additive read-only RPC replaces the Overview screen's unbounded full
-- request projection. It returns exact aggregate counts plus a bounded set of
-- non-commercial summaries. It changes no workflow state, quantity, role,
-- membership, audit event or historical row.
--
-- Rollback is forward-only: point the client back to the existing paginated
-- summary RPC and revoke this function in a corrective migration. No data
-- relation is created or removed.

create index if not exists v1_material_requests_startup_updated_idx
  on public.v1_material_requests (updated_at desc, id);

create or replace function public.v1_material_request_overview(
  p_limit integer default 6
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 6), 1), 15);
  v_items jsonb;
  v_counts jsonb;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_REQUEST_OVERVIEW_DENIED'
      using errcode = '42501';
  end if;

  with readable as materialized (
    select request.id, request.state
    from public.v1_material_requests request
    where public.v1_material_request_participant(request.id, auth.uid())
  )
  select jsonb_build_object(
    'total', count(*),
    'open', count(*) filter (where state not in (
      'draft', 'received', 'closed', 'cancelled'
    )),
    'needs_action', count(*) filter (
      where public.v1_material_request_actor_has_current_action(id)
    ),
    'approvals', count(*) filter (where state in (
      'awaiting_request_approval', 'awaiting_approval'
    )),
    'delivery_exceptions', count(*) filter (where state in (
      'changes_requested', 'partially_dispatched', 'partially_received'
    )),
    'receipt_pending', count(*) filter (where state in (
      'dispatched', 'partially_received'
    )),
    'drafts_and_changes', count(*) filter (where state in (
      'draft', 'changes_requested'
    )),
    'received', count(*) filter (where state = 'received'),
    'closed', count(*) filter (where state = 'closed'),
    'dispatch_ready', count(*) filter (where state in (
      'approved', 'partially_dispatched'
    )),
    'new_to_arrange', count(*) filter (where state in (
      'approved_for_arrangement', 'arranging'
    ))
  ) into v_counts
  from readable;

  -- Limit the request headers before evaluating the richer per-row helpers.
  -- This prevents work-assignment, change and exception projections for every
  -- request in the portfolio during application startup.
  with readable as materialized (
    select request.*, project.project_ref, project.name as project_name,
      project.job_contract_reference, scope.name as scope_name
    from public.v1_material_requests request
    join public.v1_projects project on project.id = request.project_id
    join public.v1_project_scopes scope on scope.id = request.scope_id
    where public.v1_material_request_participant(request.id, auth.uid())
  ), bounded as materialized (
    select * from readable
    order by updated_at desc, id
    limit v_limit
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', bounded.id,
    'project_id', bounded.project_id,
    'project_ref', bounded.project_ref,
    'project_name', bounded.project_name,
    'job_contract_reference', bounded.job_contract_reference,
    'scope_id', bounded.scope_id,
    'scope_name', bounded.scope_name,
    'state', bounded.state,
    'record_version', bounded.record_version,
    'request_number', bounded.request_number,
    'title', bounded.title,
    'timing', bounded.timing,
    'scheduled_date', bounded.scheduled_date,
    'delivery_note', bounded.delivery_note,
    'requester_display_name', bounded.requester_display_name,
    'requester_project_role', bounded.requester_project_role,
    'requester_exact_role', bounded.requester_exact_role,
    'current_action_owner_role', bounded.current_action_owner_role,
    'current_action_code', bounded.current_action_code,
    'current_action_started_at', bounded.updated_at,
    'current_action_age_hours', greatest(
      extract(epoch from (clock_timestamp() - bounded.updated_at)) / 3600,
      0
    ),
    'required_on_site_overdue', bounded.timing = 'scheduled'
      and bounded.scheduled_date < current_date
      and bounded.state not in ('received', 'closed', 'cancelled'),
    'actor_can_act', public.v1_material_request_actor_has_current_action(
      bounded.id
    ),
    'exception_codes', to_jsonb(
      public.v1_material_request_exception_codes(bounded.id)
    ),
    'item_count', (
      select count(*)::integer
      from public.v1_material_request_lines line
      where line.request_id = bounded.id
    ),
    'work_assignment', public.v1_material_request_work_assignment_projection(
      bounded.id
    ),
    'change_summary', public.v1_material_request_change_summary(bounded.id),
    'submitted_at', bounded.submitted_at,
    'created_at', bounded.created_at,
    'updated_at', bounded.updated_at
  ) order by bounded.updated_at desc, bounded.id), '[]'::jsonb)
  into v_items
  from bounded;

  return jsonb_build_object(
    'items', v_items,
    'counts', v_counts
  );
end;
$$;

revoke all on function public.v1_material_request_overview(integer)
  from public, anon, authenticated;
grant execute on function public.v1_material_request_overview(integer)
  to authenticated, service_role;

comment on function public.v1_material_request_overview(integer)
is 'Bounded non-commercial first-screen MR summaries with exact authorized counts.';

notify pgrst, 'reload schema';
