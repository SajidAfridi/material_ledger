-- Yorks V1 startup projection scale correction.
--
-- The first version correctly bounded its response, but it resolved request
-- participation twice and evaluated detail-only helpers for each launch card.
-- This replacement resolves view authority once per project, shares one
-- readable/scored request set between counts and cards, and keeps launch cards
-- deliberately lean. Opening a card still uses the existing protected detail
-- RPC, so no workflow action or record is removed.
--
-- Rollback is forward-only: restore the prior function definition in a later
-- migration. This migration changes no stored workflow or audit data.

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
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_result jsonb;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_MATERIAL_REQUEST_OVERVIEW_DENIED'
      using errcode = '42501';
  end if;

  with project_access as materialized (
    -- Capability resolution can include organization, role, person and
    -- project overrides. Resolve that authoritative decision once per project
    -- instead of once for every retained request in the project.
    select project.id as project_id,
      coalesce((
        public.v1_permission_authoritative_resolution(
          v_actor, 'material_requests.view', project.id
        ) ->> 'effective'
      )::boolean, false) as can_view,
      exists (
        select 1
        from public.v1_project_members member
        where member.project_id = project.id
          and member.member_auth_user_id = v_actor
          and member.effective_from <= clock_timestamp()
          and (
            member.effective_to is null
            or member.effective_to > clock_timestamp()
          )
      ) as has_active_membership
    from public.v1_projects project
  ), readable as materialized (
    -- This case expression is the set-based equivalent of
    -- v1_material_request_participant(request.id, v_actor). Keep its ordering:
    -- Admin can read drafts; every other role can read a draft only when it is
    -- their own; global engineers then receive organization-wide submitted
    -- work; project roles require dated membership; Procurement receives only
    -- the established procurement lifecycle states.
    select request.*, project.project_ref,
      project.name as project_name, project.job_contract_reference,
      scope.name as scope_name
    from public.v1_material_requests request
    join project_access access on access.project_id = request.project_id
    join public.v1_projects project on project.id = request.project_id
    join public.v1_project_scopes scope on scope.id = request.scope_id
    where access.can_view
      and case
        when v_exact_role = 'admin' then true
        when request.state = 'draft'
          then request.created_by_auth_user_id = v_actor
        when v_exact_role in (
          'senior_mechanical_engineer', 'project_manager',
          'workshop_in_charge', 'document_controller'
        ) then true
        when v_exact_role in ('project_engineer', 'site_engineer')
          then access.has_active_membership
        when v_exact_role = 'procurement' then request.state in (
          'submitted', 'approved_for_arrangement', 'arranging',
          'awaiting_approval', 'approved', 'partially_dispatched',
          'dispatched', 'partially_received', 'received', 'closed',
          'cancelled'
        )
        else false
      end
  ), scored as materialized (
    -- Reuse the existing server-authoritative action predicate. Closed and
    -- cancelled requests are guaranteed false and skip the helper entirely.
    select readable.*,
      case when readable.state in ('closed', 'cancelled') then false
        else public.v1_material_request_actor_has_current_action(readable.id)
      end as actor_can_act
    from readable
  ), bounded as materialized (
    select * from scored
    order by updated_at desc, id
    limit v_limit
  )
  select jsonb_build_object(
    'items', (
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
        'actor_can_act', bounded.actor_can_act,
        -- Exception, assignment and revision enrichment belong to the detail
        -- and register RPCs. Startup cards need identity/state only.
        'exception_codes', to_jsonb(array[]::text[]),
        'item_count', (
          select count(*)::integer
          from public.v1_material_request_lines line
          where line.request_id = bounded.id
        ),
        'work_assignment', jsonb_build_object(
          'request_id', bounded.id,
          'assignment_version', 0,
          'assignee_auth_user_id', null,
          'assignee_display_name', null,
          'assignee_exact_role', null,
          'assigned_at', null,
          'can_manage', false
        ),
        'change_summary', null,
        'submitted_at', bounded.submitted_at,
        'created_at', bounded.created_at,
        'updated_at', bounded.updated_at
      ) order by bounded.updated_at desc, bounded.id), '[]'::jsonb)
      from bounded
    ),
    'counts', (
      select jsonb_build_object(
        'total', count(*),
        'open', count(*) filter (where state not in (
          'draft', 'received', 'closed', 'cancelled'
        )),
        'needs_action', count(*) filter (where actor_can_act),
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
      )
      from scored
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.v1_material_request_overview(integer)
  from public, anon, authenticated;
grant execute on function public.v1_material_request_overview(integer)
  to authenticated, service_role;

comment on function public.v1_material_request_overview(integer)
is 'Set-based bounded non-commercial launch cards with exact authorized counts.';

notify pgrst, 'reload schema';
