-- Material Request controlled-form approval attribution.
--
-- New requests are approved before Procurement arrangement, so the controlled
-- document must prefer the immutable request decision. Historical requests
-- keep their legacy post-arrangement approval without any rewritten rows.
--
-- Rollback is forward-only: restore the former projection in a corrective
-- migration. No request, decision, arrangement, dispatch or document data is
-- changed by this projection-only migration.

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
  v_include_commercial boolean := public.v1_has_capability('view_commercials');
  v_request jsonb;
  v_lifecycle jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DOCUMENT_NOT_READABLE'
      using errcode = '42501';
  end if;
  v_lifecycle := public.v1_material_request_line_lifecycle_projection(p_request_id);
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', coalesce(
      request_record.document_identity_snapshot ->> 'project_ref',
      project.project_ref
    ),
    'project_name', coalesce(
      request_record.document_identity_snapshot ->> 'project_name', project.name
    ),
    'job_contract_reference', coalesce(
      request_record.document_identity_snapshot ->> 'job_contract_reference',
      project.job_contract_reference
    ),
    'scope_id', request_record.scope_id,
    'scope_name', coalesce(
      request_record.document_identity_snapshot ->> 'scope_name', scope.name
    ),
    'scope_code', coalesce(
      request_record.document_identity_snapshot ->> 'scope_code', scope.scope_code
    ),
    'document_identity_verified', request_record.document_identity_verified,
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
      select jsonb_agg(public.v1_material_request_line_projection(
        line_record.id, v_include_commercial
      ) order by line_record.display_order)
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
      from public.v1_material_requests request_record
      where request_record.id = p_request_id
    ),
    'arrangement', (
      select jsonb_build_object(
        'display_name', coalesce(
          arrangement.saved_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'role', coalesce(arrangement.saved_by_exact_role, 'procurement'),
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', arrangement.saved_at
      )
      from public.v1_procurement_arrangements arrangement
      join public.v1_profiles profile
        on profile.auth_user_id = arrangement.saved_by_auth_user_id
      where arrangement.request_id = p_request_id
        and arrangement.saved_at is not null
      order by arrangement.arrangement_version desc
      limit 1
    ),
    'approval', coalesce(
      (
        select jsonb_build_object(
          'display_name', decision.decided_by_display_name_snapshot,
          'role', decision.decided_by_exact_role,
          'reference', concat('Request v', decision.request_record_version),
          'acted_at', decision.created_at
        )
        from public.v1_material_request_decisions decision
        where decision.request_id = p_request_id
          and decision.decision = 'approved'
        order by decision.created_at desc, decision.id desc
        limit 1
      ),
      (
        select jsonb_build_object(
          'display_name', coalesce(
            decision.decided_by_display_name_snapshot,
            public.v1_safe_profile_display_name(
              profile.display_name, profile.auth_user_id
            )
          ),
          'role', coalesce(
            decision.decided_by_exact_role, decision.decided_by_role
          ),
          'reference', concat('Arrangement v', arrangement.arrangement_version),
          'acted_at', decision.created_at
        )
        from public.v1_arrangement_decisions decision
        join public.v1_procurement_arrangements arrangement
          on arrangement.id = decision.arrangement_id
        join public.v1_profiles profile
          on profile.auth_user_id = decision.decided_by_auth_user_id
        where decision.request_id = p_request_id
          and decision.decision = 'approved'
        order by decision.created_at desc, decision.id desc
        limit 1
      )
    ),
    'dispatch', (
      select jsonb_build_object(
        'display_name', coalesce(
          dispatch.dispatched_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'role', coalesce(
          dispatch.dispatched_by_exact_role, dispatch.dispatched_by_role
        ),
        'reference', dispatch.delivery_reference,
        'acted_at', dispatch.dispatched_at
      )
      from public.v1_material_dispatches dispatch
      join public.v1_profiles profile
        on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = p_request_id
      order by dispatch.dispatched_at desc, dispatch.id desc
      limit 1
    ),
    'show_line_status', jsonb_array_length(v_lifecycle) > 0,
    'line_lifecycle', v_lifecycle,
    'receipt_statuses', v_lifecycle
  );
end;
$$;

revoke all on function public.v1_material_request_document_projection(uuid)
  from public, anon;
grant execute on function public.v1_material_request_document_projection(uuid)
  to authenticated, service_role;

comment on function public.v1_material_request_document_projection(uuid) is
  'Role-safe controlled MR projection using pre-arrangement request approval with legacy arrangement-decision fallback.';
