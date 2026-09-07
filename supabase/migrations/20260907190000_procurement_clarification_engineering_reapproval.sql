-- Yorks V1 Procurement item clarification Engineering reapproval.
--
-- Data preservation:
-- * existing requests begin with matching clarification/approval revisions;
-- * original Engineering request-line snapshots remain immutable;
-- * working arrangements are retained while clarification is reviewed;
-- * no quantity, reservation, movement, document, notification or audit row is
--   deleted or reinterpreted.
--
-- Rollback is forward-only. Disable the revised client and ship a corrective
-- migration; never erase the clarification or decision history.

begin;

alter table public.v1_material_requests
  add column if not exists procurement_clarification_revision integer
    not null default 0,
  add column if not exists approved_procurement_clarification_revision integer
    not null default 0;

alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_clarification_revision_check;
alter table public.v1_material_requests
  add constraint v1_material_requests_clarification_revision_check check (
    procurement_clarification_revision >= 0
    and approved_procurement_clarification_revision >= 0
    and approved_procurement_clarification_revision
      <= procurement_clarification_revision
  );

comment on column
  public.v1_material_requests.procurement_clarification_revision is
  'Monotonic revision of Procurement-authored item name/model clarifications.';
comment on column
  public.v1_material_requests.approved_procurement_clarification_revision is
  'Latest Procurement clarification revision approved by Engineering.';

-- Procurement retains read access only to the exceptional Engineering-review
-- state created by its own unsaved clarification flow. Ordinary unapproved
-- Engineering requests remain hidden from Procurement.
create or replace function public.v1_material_request_readable(
  p_request_id uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and (
      public.v1_material_request_participant(p_request_id, auth.uid())
      or (
        public.v1_can_arrange_material_request(p_request_id)
        and exists (
          select 1
          from public.v1_material_requests request_record
          where request_record.id = p_request_id
            and request_record.state = 'awaiting_request_approval'
            and request_record.procurement_clarification_revision
              > request_record.approved_procurement_clarification_revision
            and exists (
              select 1
              from public.v1_procurement_arrangements arrangement
              where arrangement.request_id = request_record.id
                and arrangement.status = 'working'
                and arrangement.saved_at is null
            )
        )
      )
    );
$$;

-- Reapproval is historical, so more than one approved decision may exist for
-- a request. A request/version pair still cannot receive duplicate approvals.
drop index if exists public.v1_material_request_one_current_approval_idx;
create unique index if not exists
  v1_material_request_approval_request_version_idx
  on public.v1_material_request_decisions (request_id, request_record_version)
  where decision = 'approved';

-- Preserve the complete role-safe projection and add the reapproval state.
alter function public.v1_arrangement_projection(uuid)
  rename to v1_arrangement_projection_before_clarification_reapproval;

create or replace function public.v1_arrangement_projection(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_request public.v1_material_requests%rowtype;
  v_has_working boolean;
  v_can_arrange boolean;
  v_review_required boolean;
begin
  v_result :=
    public.v1_arrangement_projection_before_clarification_reapproval(
      p_request_id
    );
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found then return v_result; end if;

  select exists (
    select 1
    from public.v1_procurement_arrangements arrangement
    where arrangement.request_id = p_request_id
      and arrangement.status = 'working'
      and arrangement.saved_at is null
  ) into v_has_working;
  v_can_arrange := public.v1_can_arrange_material_request(p_request_id);
  v_review_required := v_request.procurement_clarification_revision
    > v_request.approved_procurement_clarification_revision;

  return v_result || jsonb_build_object(
    'procurement_clarification_revision',
      v_request.procurement_clarification_revision,
    'approved_procurement_clarification_revision',
      v_request.approved_procurement_clarification_revision,
    'clarification_review_required', v_review_required,
    'can_clarify', v_can_arrange and v_has_working
      and v_request.state in ('arranging', 'awaiting_request_approval'),
    'can_save', coalesce((v_result ->> 'can_save')::boolean, false)
      and not v_review_required
      and v_request.state = 'arranging'
  );
end;
$$;

revoke all on function
  public.v1_arrangement_projection_before_clarification_reapproval(uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_arrangement_projection_before_clarification_reapproval(uuid)
  to service_role;
revoke all on function public.v1_arrangement_projection(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_arrangement_projection(uuid)
  to authenticated, service_role;

-- Any clarification changes the effective requested identity, so Engineering
-- must approve that exact revision before Procurement may save arrangement.
create or replace function public.v1_update_material_request_procurement_item(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_request_id uuid;
  v_line_id uuid;
  v_expected_request_version integer;
  v_description text;
  v_model text;
  v_request public.v1_material_requests%rowtype;
  v_line public.v1_material_request_lines%rowtype;
  v_existing jsonb;
  v_before jsonb;
  v_after jsonb;
  v_response jsonb;
  v_next_revision integer;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'request_line_id', 'expected_request_version',
      'item_description', 'model_reference'],
    'update_material_request_procurement_item'
  );
  v_request_id := nullif(btrim(coalesce(
    p_payload ->> 'request_id', ''
  )), '')::uuid;
  v_line_id := nullif(btrim(coalesce(
    p_payload ->> 'request_line_id', ''
  )), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_description := nullif(btrim(coalesce(
    p_payload ->> 'item_description', ''
  )), '');
  v_model := nullif(btrim(coalesce(
    p_payload ->> 'model_reference', ''
  )), '');
  if v_actor is null or v_request_id is null or v_line_id is null
    or v_expected_request_version is null or v_expected_request_version < 1
    or v_description is null or length(v_description) > 4000
    or (v_model is not null and length(v_model) > 255) then
    raise exception 'V1_PROCUREMENT_ITEM_CLARIFICATION_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id
  for update;
  if not found or not public.v1_can_arrange_material_request(v_request_id) then
    raise exception 'V1_PROCUREMENT_ITEM_CLARIFICATION_DENIED'
      using errcode = '42501';
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_update_material_request_procurement_item',
    p_idempotency_key,
    p_payload
  );
  if v_existing is not null then return v_existing; end if;

  if v_request.record_version <> v_expected_request_version then
    perform public.v1_raise_version_conflict(
      'V1_MATERIAL_REQUEST_VERSION_CONFLICT'
    );
  end if;
  if v_request.state not in ('arranging', 'awaiting_request_approval')
    or not exists (
      select 1
      from public.v1_procurement_arrangements arrangement
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.arrangement_id = arrangement.id
      where arrangement.request_id = v_request.id
        and arrangement.status = 'working'
        and arrangement.saved_at is null
        and arrangement_line.request_line_id = v_line_id
    ) then
    raise exception 'V1_PROCUREMENT_ITEM_CLARIFICATION_LOCKED'
      using errcode = '22023';
  end if;

  select * into v_line
  from public.v1_material_request_lines request_line
  where request_line.id = v_line_id
    and request_line.request_id = v_request.id
  for update;
  if not found then
    raise exception 'V1_PROCUREMENT_ITEM_CLARIFICATION_LINE_INVALID'
      using errcode = '22023';
  end if;

  v_next_revision := v_request.procurement_clarification_revision + 1;
  v_before := jsonb_strip_nulls(jsonb_build_object(
    'item_description', v_line.item_description,
    'model_reference', v_line.technical_attributes ->> 'model',
    'line_clarification_version', v_line.procurement_clarification_version,
    'request_clarification_revision',
      v_request.procurement_clarification_revision,
    'approved_clarification_revision',
      v_request.approved_procurement_clarification_revision,
    'request_state', v_request.state
  ));

  update public.v1_material_request_lines request_line
  set item_description = v_description,
      technical_attributes = case
        when v_model is null then request_line.technical_attributes - 'model'
        else jsonb_set(
          request_line.technical_attributes,
          '{model}', to_jsonb(v_model), true
        )
      end,
      procurement_clarified_at = clock_timestamp(),
      procurement_clarified_by_auth_user_id = v_actor,
      procurement_clarification_version =
        request_line.procurement_clarification_version + 1,
      updated_at = clock_timestamp()
  where request_line.id = v_line_id;

  update public.v1_material_requests request_record
  set procurement_clarification_revision = v_next_revision,
      state = 'awaiting_request_approval',
      current_action_owner_role = 'project_engineer',
      current_action_code = 'request_approval_required',
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request.id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select distinct member.member_auth_user_id,
    'material_request_updated_for_approval', 'material_request',
    v_request.id, v_request.project_id
  from public.v1_project_members member
  join public.v1_profiles profile
    on profile.auth_user_id = member.member_auth_user_id
  where member.project_id = v_request.project_id
    and member.project_role = 'project_engineer'
    and member.effective_from <= clock_timestamp()
    and (member.effective_to is null
      or member.effective_to > clock_timestamp())
    and profile.is_active
    and member.member_auth_user_id <> v_actor;

  v_after := jsonb_strip_nulls(jsonb_build_object(
    'item_description', v_description,
    'model_reference', v_model,
    'line_clarification_version',
      v_line.procurement_clarification_version + 1,
    'request_clarification_revision', v_next_revision,
    'approved_clarification_revision',
      v_request.approved_procurement_clarification_revision,
    'requested_item_description', v_line.requested_item_description,
    'requested_model_reference',
      v_line.requested_technical_attributes ->> 'model',
    'request_state', 'awaiting_request_approval'
  ));
  perform public.v1_write_audit_event(
    'procurement_item_clarified', 'material_request_line', v_line.id,
    v_request.project_id, v_before, v_after,
    'Procurement clarification sent for Engineering approval',
    p_idempotency_key
  );
  v_response := public.v1_arrangement_projection(v_request.id);
  perform public.v1_complete_idempotency(
    'v1_update_material_request_procurement_item',
    p_idempotency_key,
    v_response
  );
  return v_response;
end;
$$;

comment on function
  public.v1_update_material_request_procurement_item(jsonb, uuid) is
  'Clarifies effective MR line name/model, preserves requested evidence, and atomically returns the working arrangement to Engineering approval.';

revoke all on function
  public.v1_update_material_request_procurement_item(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_update_material_request_procurement_item(jsonb, uuid)
  to authenticated, service_role;

-- Preserve the normal first Engineering decision behavior. The wrapper owns
-- only decisions for Procurement clarification on an unsaved arrangement.
alter function public.v1_decide_material_request(jsonb, uuid)
  rename to v1_decide_material_request_before_clarification_reapproval;

create or replace function public.v1_decide_material_request(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_expected_version integer;
  v_decision text;
  v_reason text;
  v_request public.v1_material_requests%rowtype;
  v_existing jsonb;
  v_before jsonb;
  v_response jsonb;
  v_exact_role text := public.v1_current_exact_role();
  v_display_name text;
  v_is_clarification_review boolean;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version', 'decision', 'reason'],
    'decide_material_request'
  );
  v_request_id := nullif(btrim(coalesce(
    p_payload ->> 'request_id', ''
  )), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_decision := coalesce(p_payload ->> 'decision', '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  if v_request_id is null or v_expected_version is null
    or v_expected_version < 1 or v_decision not in ('approved', 'returned')
    or (v_decision = 'returned' and v_reason is null) then
    raise exception 'V1_MATERIAL_REQUEST_DECISION_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id
  for update;
  if not found then
    raise exception 'V1_MATERIAL_REQUEST_DECISION_DENIED'
      using errcode = '42501';
  end if;
  v_is_clarification_review :=
    v_request.state = 'awaiting_request_approval'
    and v_request.procurement_clarification_revision
      > v_request.approved_procurement_clarification_revision
    and exists (
      select 1
      from public.v1_procurement_arrangements arrangement
      where arrangement.request_id = v_request.id
        and arrangement.status = 'working'
        and arrangement.saved_at is null
    );
  if not v_is_clarification_review then
    return public.v1_decide_material_request_before_clarification_reapproval(
      p_payload, p_idempotency_key
    );
  end if;
  if not public.v1_can_decide_material_request(v_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DECISION_DENIED'
      using errcode = '42501';
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_decide_material_request', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  if v_request.record_version <> v_expected_version then
    perform public.v1_raise_version_conflict(
      'V1_MATERIAL_REQUEST_VERSION_CONFLICT'
    );
  end if;

  select public.v1_safe_profile_display_name(
    profile.display_name, profile.auth_user_id
  ) into v_display_name
  from public.v1_profiles profile
  where profile.auth_user_id = auth.uid();
  v_before := public.v1_arrangement_projection(v_request_id);

  insert into public.v1_material_request_decisions (
    request_id, request_record_version, decision, reason,
    decided_by_auth_user_id, decided_by_role, decided_by_exact_role,
    decided_by_display_name_snapshot
  ) values (
    v_request_id, v_expected_version, v_decision, v_reason, auth.uid(),
    public.v1_current_role(), v_exact_role, v_display_name
  );

  update public.v1_material_requests request_record
  set approved_procurement_clarification_revision = case
        when v_decision = 'approved'
          then request_record.procurement_clarification_revision
        else request_record.approved_procurement_clarification_revision
      end,
      state = 'arranging',
      current_action_owner_role = 'procurement',
      current_action_code = case when v_decision = 'approved'
        then 'arrangement_in_progress'
        else 'procurement_clarification_changes_required' end,
      record_version = record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request_id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id,
    case when v_decision = 'approved'
      then 'material_request_approved_for_arrangement'
      else 'material_request_changes_requested' end,
    'material_request', v_request_id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active
    and profile.canonical_role_snapshot in ('procurement', 'admin')
    and profile.auth_user_id <> auth.uid();

  v_response := public.v1_arrangement_projection(v_request_id);
  perform public.v1_write_audit_event(
    case when v_decision = 'approved'
      then 'procurement_clarification_approved'
      else 'procurement_clarification_returned' end,
    'material_request', v_request_id, v_request.project_id, v_before,
    jsonb_build_object(
      'decision', v_decision,
      'clarification_revision',
        v_request.procurement_clarification_revision,
      'approved_clarification_revision', case
        when v_decision = 'approved'
          then v_request.procurement_clarification_revision
        else v_request.approved_procurement_clarification_revision end,
      'record_version', v_expected_version + 1,
      'request_state', 'arranging',
      'decided_by_exact_role', v_exact_role
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_decide_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function
  public.v1_decide_material_request_before_clarification_reapproval(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_decide_material_request_before_clarification_reapproval(jsonb, uuid)
  to service_role;
revoke all on function public.v1_decide_material_request(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_decide_material_request(jsonb, uuid)
  to authenticated, service_role;

-- This outer guard is deliberately before every inherited arrangement-save
-- implementation. A stale client cannot bypass the approval checkpoint.
alter function public.v1_save_arrangement(jsonb, uuid)
  rename to v1_save_arrangement_before_clarification_reapproval;

create or replace function public.v1_save_arrangement(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_request public.v1_material_requests%rowtype;
begin
  v_request_id := nullif(btrim(coalesce(
    p_payload ->> 'request_id', ''
  )), '')::uuid;
  if v_request_id is null then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id
  for update;
  if not found then
    raise exception 'V1_SAVE_ARRANGEMENT_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  if v_request.procurement_clarification_revision
      <> v_request.approved_procurement_clarification_revision
    or v_request.state = 'awaiting_request_approval' then
    raise exception 'V1_MATERIAL_REQUEST_APPROVAL_REQUIRED'
      using errcode = '42501';
  end if;
  return public.v1_save_arrangement_before_clarification_reapproval(
    p_payload, p_idempotency_key
  );
end;
$$;

revoke all on function
  public.v1_save_arrangement_before_clarification_reapproval(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_save_arrangement_before_clarification_reapproval(jsonb, uuid)
  to service_role;
revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.v1_save_arrangement(jsonb, uuid)
  to authenticated, service_role;

commit;
