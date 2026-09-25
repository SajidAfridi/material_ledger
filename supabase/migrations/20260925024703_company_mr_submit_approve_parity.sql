-- An approver-authorized requester may use the Project MR fast path for a
-- Company request. Beneficiary/receiver identity and the dated Company
-- category/unit approval grant still exclude unsafe self-approval.
-- Additive command; no existing request, decision, stock or audit row changes.
-- Rollback: disable Company use in the client; retain committed approvals and
-- this schema for audit continuity, then fix forward.
begin;

-- Every protected caller places the requester first, followed by actors who
-- must never approve (Procurement during revision, beneficiary and receiver).
-- The first ID may be considered only when it independently has exact-role and
-- dated Company approval authority. Site Engineers remain ineligible.
create or replace function public.v1_company_eligible_approvers(
  p_category uuid, p_unit uuid, p_excluded uuid[]
)
returns table(auth_user_id uuid, display_name text)
language sql stable security definer set search_path = '' as $$
 select p.auth_user_id, p.display_name
 from public.v1_profiles p
 join auth.users u on u.id = p.auth_user_id
 where p.is_active
   and (
     not (p.auth_user_id = any(p_excluded))
     or (p.auth_user_id = p_excluded[1]
       and p.auth_user_id <> all(coalesce(
         p_excluded[2:cardinality(p_excluded)], '{}'::uuid[])))
   )
   and coalesce(u.raw_app_meta_data->>'role','') in (
     'project_engineer','senior_mechanical_engineer','project_manager',
     'workshop_in_charge','document_controller','admin')
   and public.v1_company_material_request_active_authorization(
     p.auth_user_id, p_category, p_unit, 'approver')
 order by lower(p.display_name), p.auth_user_id;
$$;
revoke all on function public.v1_company_eligible_approvers(uuid,uuid,uuid[])
  from public, anon, authenticated;

create or replace function public.v1_resolve_selected_company_approver(
  p_category uuid, p_unit uuid, p_excluded uuid[], p_selected uuid
)
returns table(route_id uuid, policy_version text, approver_auth_user_id uuid,
  approver_display_name text)
language plpgsql stable security definer set search_path = '' as $$
declare v_route record;
begin
  if p_selected is null then
    if p_excluded[1] = auth.uid() and exists (
      select 1 from public.v1_company_eligible_approvers(
        p_category, p_unit, p_excluded) a where a.auth_user_id = auth.uid()
    ) then
      p_selected := auth.uid();
    else
      return query
        select r.* from public.v1_resolve_company_material_request_approver(
          p_category, p_unit, p_excluded) r
        join public.v1_company_eligible_approvers(
          p_category, p_unit, p_excluded) a
          on a.auth_user_id = r.approver_auth_user_id;
      return;
    end if;
  end if;
  select r.id, r.policy_version into v_route
  from public.v1_company_material_request_approval_routes r
  where r.category_id = p_category and r.responsible_unit_id = p_unit
    and r.effective_from <= current_date
    and (r.effective_to is null or r.effective_to >= current_date);
  if not found or (select count(*)
    from public.v1_company_material_request_approval_routes r
    where r.category_id = p_category and r.responsible_unit_id = p_unit
      and r.effective_from <= current_date
      and (r.effective_to is null or r.effective_to >= current_date)) <> 1
  then return; end if;
  return query
    select v_route.id, v_route.policy_version, a.auth_user_id, a.display_name
    from public.v1_company_eligible_approvers(p_category,p_unit,p_excluded) a
    where a.auth_user_id = p_selected;
end $$;
revoke all on function public.v1_resolve_selected_company_approver(
  uuid,uuid,uuid[],uuid) from public, anon, authenticated;

create or replace function public.v1_company_material_request_assigned_approver(
  p_request_id uuid, p_require_pending boolean default true
)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null
   and public.v1_current_actor_is_active()
   and public.v1_current_exact_role() in (
     'project_engineer','senior_mechanical_engineer','project_manager',
     'workshop_in_charge','document_controller','admin')
   and exists (
     select 1 from public.v1_company_material_requests r
     where r.id = p_request_id
       and (not p_require_pending or r.state = 'awaiting_company_approval')
       and r.approver_auth_user_id = auth.uid()
       and r.beneficiary_auth_user_id <> auth.uid()
       and r.authorized_receiver_auth_user_id <> auth.uid()
       and public.v1_company_material_request_active_authorization(
         auth.uid(), r.category_id, r.responsible_unit_id, 'approver')
   );
$$;
revoke all on function public.v1_company_material_request_assigned_approver(
  uuid,boolean) from public, anon, authenticated;

-- One trusted transaction saves, submits and decides. Existing commands keep
-- their own idempotency namespaces, version checks, events and notifications.
-- Any denial rolls the entire call back, including the generated CMR number.
create or replace function public.v1_save_submit_and_approve_company_material_request(
  p_payload jsonb, p_idempotency_key uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_exact_role();
  v_existing jsonb;
  v_saved jsonb;
  v_submitted jsonb;
  v_decided jsonb;
  v_request_id uuid;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer','senior_mechanical_engineer',
      'project_manager','workshop_in_charge','document_controller','admin')
    or p_payload->>'selected_approver_auth_user_id' is distinct from v_actor::text
    or p_payload->>'beneficiary_auth_user_id' = v_actor::text
    or p_payload->>'authorized_receiver_auth_user_id' = v_actor::text
  then raise exception 'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED'
    using errcode = '42501'; end if;
  if not public.v1_company_material_request_active_authorization(
    v_actor, (p_payload->>'category_id')::uuid,
    (p_payload->>'responsible_unit_id')::uuid, 'approver')
  then raise exception 'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED'
    using errcode = '42501'; end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_save_submit_and_approve_company_material_request',
    p_idempotency_key, p_payload);
  if v_existing is not null then
    if not public.v1_company_material_request_readable(
      (v_existing->>'id')::uuid)
    then raise exception 'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED'
      using errcode = '42501'; end if;
    return public.v1_company_material_request_projection((v_existing->>'id')::uuid);
  end if;

  v_saved := public.v1_save_company_material_request_draft(p_payload);
  v_request_id := (v_saved->>'id')::uuid;
  v_submitted := public.v1_submit_company_material_request(
    jsonb_build_object('request_id',v_request_id,
      'expected_version',(v_saved->>'record_version')::integer),
    p_idempotency_key);
  -- The intermediate handoff is completed in this same transaction. Keep its
  -- notification row for delivery history, but do not leave an unread task.
  update public.v1_notifications set seen_at = clock_timestamp()
  where recipient_auth_user_id = v_actor
    and entity_type = 'company_material_request'
    and entity_id = v_request_id
    and event_code = 'company_material_request_approval_requested'
    and seen_at is null;
  if not public.v1_company_material_request_assigned_approver(
    v_request_id, true)
  then raise exception 'V1_COMPANY_MATERIAL_REQUEST_SELF_APPROVAL_DENIED'
    using errcode = '42501'; end if;
  v_decided := public.v1_decide_company_material_request(
    jsonb_build_object('request_id',v_request_id,
      'expected_version',(v_submitted->>'record_version')::integer,
      'decision','approved','reason',null), p_idempotency_key);

  perform public.v1_complete_idempotency(
    'v1_save_submit_and_approve_company_material_request',
    p_idempotency_key, v_decided);
  return v_decided;
end $$;
revoke all on function public.v1_save_submit_and_approve_company_material_request(
  jsonb,uuid) from public, anon;
grant execute on function public.v1_save_submit_and_approve_company_material_request(
  jsonb,uuid) to authenticated,service_role;
commit;
