-- Additive read-only register integration. No data, stock, policy or schema rewrite.
-- Requires the Company Admin submitted-read policy shipped in 20260925000100.
-- Rollback: revert the client/disable Company flag; retain requests and audit history.
-- Existing Project-only endpoints stay unchanged. Never call full Company projections
-- per candidate; decorate only the page, after authorization/filtering/sorting.
create or replace function public.v1_list_unified_material_request_summaries(
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
  p_register_view text default 'total',
  p_request_kind text default 'all'
) returns jsonb
language plpgsql
volatile
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
    or p_request_kind is null or p_request_kind not in ('all','project','company')
    or p_sort is null or p_metric is null or p_register_view is null
    or char_length(coalesce(p_search,'')) > 300
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
    select request.id, request.project_id, request.scope_id, request.state, request.record_version, request.request_number, request.title, request.timing, request.scheduled_date, request.delivery_note, request.requester_display_name, request.requester_project_role, request.requester_exact_role, request.current_action_owner_role, request.current_action_code, request.submitted_at, request.created_at, request.updated_at, request.created_by_auth_user_id, project.project_ref, project.name as project_name,
      project.job_contract_reference, scope.name as scope_name,
      'project'::text as request_kind, null::text as category_name,
      null::text as responsible_unit_name,
      exists(select 1 from public.v1_material_request_work_assignments a
        where a.request_id=request.id and a.assignee_auth_user_id=auth.uid()) as assigned_to_actor,
      public.v1_material_request_actor_has_current_action(request.id) as actor_can_act,
      public.v1_material_request_exception_codes(request.id) as exception_codes
    from public.v1_material_requests request
    join public.v1_projects project on project.id=request.project_id
    join public.v1_project_scopes scope on scope.id=request.scope_id
    where p_request_kind in ('all','project') and public.v1_material_request_participant(request.id,auth.uid())
      and (p_project_id is null or request.project_id=p_project_id)
    union all
    select r.id, null::uuid, null::uuid, r.state, r.record_version, r.request_number, r.purpose, r.timing, r.scheduled_date, null::text, r.requester_display_name, null::text, r.requester_exact_role, case when r.state in ('awaiting_company_approval','submitted_pending_approval') then 'company_approver' when r.state in ('approved_for_procurement','arranging','ready_for_delivery','partially_dispatched','partially_received') then 'procurement' when r.state='receipt_pending' then 'authorized_receiver' when r.state='awaiting_beneficiary_handover' then 'beneficiary' when r.state in ('closed','cancelled','rejected') then null else 'requester' end, case when r.state in ('awaiting_company_approval','submitted_pending_approval') then 'approve' when r.state in ('approved_for_procurement','arranging','partially_received') then 'arrange' when r.state in ('ready_for_delivery','partially_dispatched') then 'dispatch' when r.state='receipt_pending' then 'receive' when r.state='awaiting_beneficiary_handover' then 'handover' when r.state='fulfilled' then 'close' when r.state='returned_for_changes' then 'revise' else null end, r.submitted_at, r.created_at, r.updated_at, r.created_by_auth_user_id, null::text, null::text, null::text, null::text,
      'company'::text, c.display_name, u.display_name,
      r.approver_auth_user_id=auth.uid(),
      ((r.state in ('awaiting_company_approval','submitted_pending_approval')
          and public.v1_company_material_request_assigned_approver(r.id,true))
        or (r.state='returned_for_changes' and r.created_by_auth_user_id=auth.uid())
        or (public.v1_current_role()='procurement' and (
          r.state in ('approved_for_procurement','arranging','ready_for_delivery','partially_dispatched','partially_received')
          or exists(select 1 from public.v1_company_material_returns ret where ret.request_id=r.id and ret.state='submitted')))
        or (r.state='receipt_pending' and r.authorized_receiver_auth_user_id=auth.uid())
        or (r.state='awaiting_beneficiary_handover' and auth.uid() in (r.authorized_receiver_auth_user_id,r.beneficiary_auth_user_id))
        or (r.state='fulfilled' and public.v1_current_role()<>'procurement'
          and auth.uid() in (r.created_by_auth_user_id,r.authorized_receiver_auth_user_id,r.approver_auth_user_id))),
      case when r.state in ('draft','closed','cancelled','rejected') then '{}'::text[] else
        array_remove(array[
          case when exists(select 1 from public.v1_company_material_supply_plans p join public.v1_company_material_supply_lines l on l.plan_id=p.id
            where p.request_id=r.id and p.is_current and l.decision='unavailable') then 'unavailable_supply' end,
          case when exists(select 1 from public.v1_company_material_supply_plans p join public.v1_company_material_supply_lines l on l.plan_id=p.id
            where p.request_id=r.id and p.is_current and l.decision='partial') then 'partial_arrangement' end
        ],null) end
    from public.v1_company_material_requests r
    join public.v1_company_material_request_categories c on c.id=r.category_id
    join public.v1_company_material_request_units u on u.id=r.responsible_unit_id
    where p_project_id is null and p_request_kind in ('all','company') and public.v1_company_material_request_readable(r.id)
  ), authorized as materialized (
    select * from readable request
    where p_register_view = 'total'
      or (p_register_view = 'mine'
        and request.created_by_auth_user_id = auth.uid())
      or (p_register_view = 'assigned' and request.assigned_to_actor)
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
        request.state not in ('draft', 'closed', 'cancelled', 'rejected') and (
          coalesce(request.current_action_code, '') <> ''
          or request.state in (
            'awaiting_request_approval', 'changes_requested', 'submitted_pending_approval', 'awaiting_company_approval', 'returned_for_changes', 'arranging',
            'dispatched', 'partially_dispatched', 'partially_received',
            'received'
          )
        )
      ))
      and (p_metric = 'all'
        or (p_metric = 'open' and request.state in (
          'draft', 'submitted', 'awaiting_request_approval',
          'changes_requested', 'submitted_pending_approval', 'awaiting_company_approval', 'returned_for_changes'
        ))
        or (p_metric = 'in_progress' and request.state not in (
          'draft', 'submitted', 'awaiting_request_approval',
          'changes_requested', 'submitted_pending_approval', 'awaiting_company_approval', 'returned_for_changes', 'partially_dispatched', 'dispatched', 'receipt_pending',
          'partially_received', 'received', 'awaiting_beneficiary_handover', 'fulfilled', 'closed', 'cancelled', 'rejected'
        ))
        or (p_metric = 'dispatched' and request.state in (
          'partially_dispatched', 'dispatched', 'receipt_pending'
        ))
        or (p_metric = 'received' and request.state in (
          'partially_received', 'received', 'awaiting_beneficiary_handover', 'fulfilled'
        ))
        or (p_metric = 'closed' and request.state in ('closed', 'cancelled', 'rejected'))
      )
      and (v_search is null
        or request.request_number ilike '%' || v_search || '%'
        or coalesce(request.title, '') ilike '%' || v_search || '%'
        or request.project_ref ilike '%' || v_search || '%'
        or request.project_name ilike '%' || v_search || '%'
        or request.scope_name ilike '%' || v_search || '%'
        or request.category_name ilike '%' || v_search || '%'
        or request.responsible_unit_name ilike '%' || v_search || '%'
        or coalesce(request.requester_display_name, '')
          ilike '%' || v_search || '%'
        or exists (
          select 1 from public.v1_material_request_lines line
          where request.request_kind='project' and line.request_id = request.id
            and line.item_description ilike '%' || v_search || '%'
        )
        or exists (select 1 from public.v1_company_material_request_lines line
          where request.request_kind='company' and line.request_id=request.id
            and line.item_description ilike '%' || v_search || '%')
      )
  ), page as materialized (
    select * from filtered request
    order by
      case when p_sort = 'updated_desc' then request.updated_at end desc,
      case when p_sort = 'updated_asc' then request.updated_at end asc,
      request.id, request.request_kind
    limit v_limit offset v_offset
  ), decorated_page as materialized (
    select page.*,
      case when request_kind='project' then (select count(*)::integer from public.v1_material_request_lines l where l.request_id=page.id)
        else (select count(*)::integer from public.v1_company_material_request_lines l where l.request_id=page.id) end as item_count,
      case when request_kind='project' then public.v1_material_request_work_assignment_projection(page.id) else null end as work_assignment,
      case when request_kind='project' then public.v1_material_request_change_summary(page.id) else null end as change_summary
    from page
  )
  select jsonb_build_object(
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'request_kind', page.request_kind,
        'category_name', page.category_name,
        'responsible_unit_name', page.responsible_unit_name,
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
          and page.state not in ('received', 'fulfilled', 'closed', 'cancelled', 'rejected'),
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
        page.id, page.request_kind)
      from decorated_page page
    ), '[]'::jsonb),
    'total_count', (select count(*) from filtered),
    'limit', v_limit,
    'offset', v_offset,
    'has_more', v_offset + (select count(*) from page)
      < (select count(*) from filtered),
    'metrics', (select jsonb_build_object(
      'total', count(*),
      'open', count(*) filter (where state in (
        'draft', 'submitted', 'awaiting_request_approval', 'changes_requested', 'submitted_pending_approval', 'awaiting_company_approval', 'returned_for_changes'
      )),
      'in_progress', count(*) filter (where state not in (
        'draft', 'submitted', 'awaiting_request_approval',
        'changes_requested', 'submitted_pending_approval', 'awaiting_company_approval', 'returned_for_changes', 'partially_dispatched', 'dispatched', 'receipt_pending',
        'partially_received', 'received', 'awaiting_beneficiary_handover', 'fulfilled', 'closed', 'cancelled', 'rejected'
      )),
      'dispatched', count(*) filter (where state in (
        'partially_dispatched', 'dispatched', 'receipt_pending'
      )),
      'received', count(*) filter (where state in (
        'partially_received', 'received', 'awaiting_beneficiary_handover', 'fulfilled'
      )),
      'closed', count(*) filter (where state in ('closed', 'cancelled', 'rejected')),
      'my_work', count(*) filter (where actor_can_act),
      'exceptions', count(*) filter (
        where cardinality(exception_codes) > 0
      ),
      'required_date_overdue', count(*) filter (
        where timing = 'scheduled'
          and scheduled_date < current_date
          and state not in ('received', 'fulfilled', 'closed', 'cancelled', 'rejected')
      )
    ) from readable)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.v1_list_unified_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text, text
) from public, anon, authenticated;
grant execute on function public.v1_list_unified_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text, text
) to authenticated, service_role;

comment on function public.v1_list_unified_material_request_summaries(
  uuid, text, text[], uuid, text, timestamptz, boolean, text, text, integer,
  integer, text, text
) is 'Authorized Project and Company MR union; stable combined paging/counts, native states, no commercial fields or Company Project identities.';

notify pgrst, 'reload schema';
