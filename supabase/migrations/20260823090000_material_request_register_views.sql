-- Yorks V1 Material Request register ownership views.
--
-- Data preservation: this migration changes only a read projection. No
-- request, assignment, line, audit or private-draft row is rewritten.
-- Rollback is forward-only: restore the prior function signature in a
-- corrective migration; do not remove workflow records.

drop function if exists public.v1_list_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer
);

create function public.v1_list_material_request_summaries(
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
    or p_register_view not in ('total', 'mine', 'assigned') then
    raise exception 'V1_MATERIAL_REQUEST_SUMMARY_LIST_DENIED'
      using errcode = '42501';
  end if;
  if p_project_id is not null
    and not public.v1_project_readable(p_project_id) then
    raise exception 'V1_MATERIAL_REQUEST_PROJECT_NOT_READABLE'
      using errcode = '42501';
  end if;

  with authorized as materialized (
    select request.*, project.project_ref, project.name as project_name,
      project.job_contract_reference, scope.name as scope_name,
      (select count(*)::integer
       from public.v1_material_request_lines line
       where line.request_id = request.id) as item_count,
      public.v1_material_request_work_assignment_projection(
        request.id
      ) as work_assignment,
      public.v1_material_request_change_summary(request.id) as change_summary
    from public.v1_material_requests request
    join public.v1_projects project on project.id = request.project_id
    join public.v1_project_scopes scope on scope.id = request.scope_id
    where public.v1_material_request_participant(request.id, auth.uid())
      and (p_project_id is null or request.project_id = p_project_id)
      and (
        p_register_view = 'total'
        or (p_register_view = 'mine'
          and request.created_by_auth_user_id = auth.uid())
        or (p_register_view = 'assigned' and exists (
          select 1
          from public.v1_material_request_work_assignments assignment
          where assignment.request_id = request.id
            and assignment.assignee_auth_user_id = auth.uid()
        ))
      )
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
      'closed', count(*) filter (where state in ('closed', 'cancelled'))
    ) from authorized)
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
) is 'Authorized paginated MR register with total, creator-owned and explicitly assigned views.';

notify pgrst, 'reload schema';
