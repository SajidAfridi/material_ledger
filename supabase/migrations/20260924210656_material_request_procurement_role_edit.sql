-- Explicit per-request Procurement-role grant. Existing named grants stay unchanged.
-- Rollback: revoke role grants through the audited command before reverting functions;
-- retain this additive column and all audit history. Never infer role scope from NULL editor.
alter table public.v1_material_requests
  add column if not exists procurement_role_edit_enabled boolean not null default false;
alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_procurement_role_edit_check;
alter table public.v1_material_requests
  add constraint v1_material_requests_procurement_role_edit_check check (
    not procurement_role_edit_enabled or
    (post_approval_edit_enabled and procurement_editor_auth_user_id is null)
  );

create or replace function public.v1_can_edit_material_request_post_approval(
  p_request_id uuid
) returns boolean
language plpgsql stable security definer set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request from public.v1_material_requests
  where id = p_request_id;
  if not found or not v_request.post_approval_edit_enabled
    or (v_request.state <> 'approved_for_arrangement'
      and not (v_request.post_approval_amendment_pending
        and v_request.state in ('awaiting_request_approval', 'changes_requested')))
    or exists (select 1 from public.v1_procurement_arrangements
      where request_id = p_request_id) then return false; end if;
  if public.v1_can_manage_material_request_post_approval_edit(p_request_id) then
    return true;
  end if;
  return public.v1_current_exact_role() = 'procurement'
    and (v_request.procurement_role_edit_enabled
      or auth.uid() = v_request.procurement_editor_auth_user_id)
    and public.v1_current_user_has_capability(
      'procurement.arrange', v_request.project_id
    );
end;
$$;

create or replace function public.v1_set_material_request_post_approval_edit(
  p_payload jsonb, p_idempotency_key uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_enabled boolean;
  v_editor uuid;
  v_role_enabled boolean;
  v_request public.v1_material_requests%rowtype;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload,
    array['request_id', 'expected_version', 'enabled',
      'procurement_editor_auth_user_id', 'procurement_role_edit_enabled'], 'set_material_request_post_approval_edit');
  v_request_id := nullif(p_payload ->> 'request_id', '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_enabled := (p_payload ->> 'enabled')::boolean;
  v_editor := nullif(p_payload ->> 'procurement_editor_auth_user_id', '')::uuid;
  v_role_enabled := coalesce((p_payload ->> 'procurement_role_edit_enabled')::boolean, false);
  if v_request_id is null or v_expected_version is null or v_expected_version < 1
    or v_enabled is null or (not v_enabled and (v_editor is not null or v_role_enabled))
    or (v_role_enabled and v_editor is not null) then
    raise exception 'V1_POST_APPROVAL_EDIT_GRANT_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests
    where id = v_request_id for update;
  if not found or not public.v1_can_manage_material_request_post_approval_edit(
    v_request_id) then
    raise exception 'V1_POST_APPROVAL_EDIT_GRANT_DENIED' using errcode = '42501';
  end if;
  if v_editor is not null and not exists (
    select 1 from public.v1_profiles profile
    join auth.users user_record on user_record.id = profile.auth_user_id
    where profile.auth_user_id = v_editor and profile.is_active
      and user_record.raw_app_meta_data ->> 'role' = 'procurement'
      and coalesce((public.v1_permission_authoritative_resolution(
        v_editor, 'procurement.arrange', v_request.project_id
      ) ->> 'effective')::boolean, false)
  ) then
    raise exception 'V1_POST_APPROVAL_EDIT_EDITOR_INVALID' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_set_material_request_post_approval_edit', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_request.record_version <> v_expected_version then
    perform public.v1_raise_version_conflict('V1_MATERIAL_REQUEST_VERSION_CONFLICT');
  end if;
  v_before := public.v1_material_request_projection(v_request_id);
  update public.v1_material_requests set
    post_approval_edit_enabled = v_enabled,
    procurement_role_edit_enabled = v_role_enabled,
    procurement_editor_auth_user_id = v_editor,
    record_version = record_version + 1,
    updated_at = clock_timestamp()
  where id = v_request_id;
  v_response := public.v1_material_request_projection(v_request_id);
  perform public.v1_write_audit_event(
    'material_request_post_approval_edit_grant_changed', 'material_request',
    v_request_id, v_request.project_id, v_before,
    jsonb_build_object('enabled', v_enabled,
      'procurement_role_edit_enabled', v_role_enabled,
      'procurement_editor_auth_user_id', v_editor,
      'record_version', v_expected_version + 1),
    null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_set_material_request_post_approval_edit', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_material_request_projection(
  p_request_id uuid
) returns jsonb
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
    'can_edit_before_approval',
      public.v1_can_edit_material_request_before_approval(request_record.id),
    'procurement_role_edit_enabled', request_record.procurement_role_edit_enabled,
    'post_approval_edit_enabled', request_record.post_approval_edit_enabled,
    'post_approval_amendment_pending', request_record.post_approval_amendment_pending,
    'procurement_editor_auth_user_id', request_record.procurement_editor_auth_user_id,
    'can_manage_post_approval_edit',
      case when request_record.state = 'approved_for_arrangement'
        or request_record.post_approval_amendment_pending
        then public.v1_can_manage_material_request_post_approval_edit(request_record.id)
        else false end,
    'can_edit_post_approval',
      case when request_record.post_approval_edit_enabled and (
        request_record.state = 'approved_for_arrangement'
        or request_record.post_approval_amendment_pending)
        then public.v1_can_edit_material_request_post_approval(request_record.id)
        else false end,
    'can_decide_request', public.v1_can_decide_material_request(request_record.id)
      and request_record.state = 'awaiting_request_approval',
    'request_decision', (
      select jsonb_build_object(
        'id', decision.id,
        'decision', decision.decision,
        'reason', decision.reason,
        'request_record_version', decision.request_record_version,
        'decided_by_display_name', decision.decided_by_display_name_snapshot,
        'decided_by_role', decision.decided_by_role,
        'decided_by_exact_role', decision.decided_by_exact_role,
        'decided_at', decision.created_at
      )
      from public.v1_material_request_decisions decision
      where decision.request_id = request_record.id
      order by decision.created_at desc, decision.id desc limit 1
    ),
    'comments', public.v1_material_request_comment_projection(request_record.id),
    'lines', coalesce((
      select jsonb_agg(public.v1_material_request_line_projection(
        line_record.id, v_include_commercial
      ) order by line_record.display_order)
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
  v_has_view boolean := false;
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

  v_has_view := coalesce((
    public.v1_permission_authoritative_resolution(
      p_auth_user_id, 'material_requests.view', v_request.project_id
    ) ->> 'effective'
  )::boolean, false);
  if not v_has_view then
    return false;
  end if;

  select coalesce(user_record.raw_app_meta_data ->> 'role', '')
    into v_exact_role
  from auth.users user_record
  where user_record.id = p_auth_user_id;

  if v_exact_role = 'admin' then
    return true;
  end if;
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
        and (
          member.effective_to is null
          or member.effective_to > clock_timestamp()
        )
    );
  end if;
  if v_exact_role = 'procurement' then
    return v_request.state in (
      'submitted', 'approved_for_arrangement', 'arranging',
      'awaiting_approval', 'approved', 'partially_dispatched',
      'dispatched', 'partially_received', 'received', 'closed', 'cancelled'
    ) or (v_request.post_approval_amendment_pending
      and v_request.post_approval_edit_enabled
      and (v_request.procurement_role_edit_enabled
        or v_request.procurement_editor_auth_user_id = p_auth_user_id)
      and v_request.state in ('awaiting_request_approval', 'changes_requested')
      and not exists (select 1 from public.v1_procurement_arrangements
        where request_id = p_request_id));
  end if;
  return false;
end;
$$;
