-- R35 material request numbers are scoped to a project, not globally to a
-- display reference.  Archived project references may be reused during the
-- beta phase, so a global unique constraint made a new project's first MR
-- collide with an archived project's historical MR001.
--
-- Keep the existing partial project/index uniqueness as the authority and
-- allocate the next number under the request's locked project transaction.
begin;

alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_request_number_key;

create unique index if not exists v1_material_requests_project_number_unique_idx
  on public.v1_material_requests (project_id, request_number)
  where request_number is not null;

-- Existing counters were introduced with MR001.  Preserve every issued
-- reference, then make the next allocation use the new 100-series.  A
-- counter already beyond the new floor is never moved backwards.
update public.v1_material_request_reference_counters
set next_request_sequence = greatest(next_request_sequence, 100),
    updated_at = clock_timestamp();

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
  -- Authenticate the same active creator and project again before returning a
  -- completed retry. The original state may already be submitted by then.
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
  if v_project_role is null and public.v1_current_role() <> 'admin' then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into v_display_name
  from public.v1_profiles profile where profile.auth_user_id = v_actor;

  -- The parent project is locked above, and this UPSERT atomically allocates
  -- exactly one monotonically increasing number for that project.  Do not use
  -- a client preview as an identifier: retries return the idempotent server
  -- response, and concurrent drafts receive distinct numbers.
  insert into public.v1_material_request_reference_counters (
    project_id, next_request_sequence, updated_at
  ) values (v_project.id, 101, clock_timestamp())
  on conflict (project_id) do update set
    next_request_sequence = public.v1_material_request_reference_counters.next_request_sequence + 1,
    updated_at = clock_timestamp()
  returning next_request_sequence - 1 into v_sequence;
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || v_sequence::text;
  v_before := public.v1_material_request_projection(v_request.id);

  update public.v1_material_requests
     set request_number = v_request_number,
         state = 'submitted',
         requester_display_name = v_display_name,
         requester_project_role = coalesce(v_project_role, 'project_engineer'),
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
