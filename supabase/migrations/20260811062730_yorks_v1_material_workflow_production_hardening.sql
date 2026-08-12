-- Yorks V1 Material Request workflow production hardening.
--
-- This additive migration closes the remaining commercial response-shape and
-- received-request lifecycle gaps. It preserves all historical rows and
-- patches the already-deployed trusted commands in place so their established
-- locks, quantity checks, reservations and audit behavior remain authoritative.

begin;

-- Arrangement costs are capability-controlled, not role-controlled. A caller
-- without view_commercials must not receive even a null commercial key because
-- response shape itself is part of the protected boundary.
do $arrangement_projection$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_arrangement_projection(uuid)'::regprocedure
  );
  if position(
      'v_role text := public.v1_current_role();' in v_definition
    ) > 0 and position(
      'v_role in (''procurement'', ''admin'')' in v_definition
    ) > 0 and position('return v_result;' in v_definition) > 0 then
    v_definition := replace(
      v_definition,
      'v_role text := public.v1_current_role();',
      'v_include_commercial boolean := public.v1_has_capability(''view_commercials'');'
    );
    v_definition := replace(
      v_definition,
      'v_role in (''procurement'', ''admin'')',
      'v_include_commercial'
    );
    v_definition := replace(
      v_definition,
      'return v_result;',
      $replacement$if not v_include_commercial then
    select jsonb_set(
      v_result,
      '{arrangements}',
      coalesce(jsonb_agg(
        (arrangement_item.value - 'procurement_note' - 'lines')
        || jsonb_build_object(
          'lines', coalesce((
            select jsonb_agg(line_item.value - 'unit_cost'
              order by line_item.ordinality)
            from jsonb_array_elements(coalesce(
              arrangement_item.value -> 'lines', '[]'::jsonb
            )) with ordinality as line_item(value, ordinality)
          ), '[]'::jsonb)
        ) order by arrangement_item.ordinality
      ), '[]'::jsonb)
    ) into v_result
    from jsonb_array_elements(coalesce(
      v_result -> 'arrangements', '[]'::jsonb
    )) with ordinality as arrangement_item(value, ordinality);
  end if;
  return v_result;$replacement$
    );
    execute v_definition;
  elsif position(
      'v_include_commercial boolean := public.v1_has_capability(''view_commercials'');'
      in v_definition
    ) > 0 and position(
      'arrangement_item.value - ''procurement_note'' - ''lines'''
      in v_definition
    ) > 0 then
    null;
  else
    raise exception 'V1_ARRANGEMENT_PROJECTION_HARDENING_ANCHOR_MISSING';
  end if;
end;
$arrangement_projection$;

-- The trusted save command rejects unauthorized cost writes before mutation.
-- A blank cost from a non-commercial operational client preserves any existing
-- protected value instead of silently clearing it.
do $arrangement_save$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_arrangement(jsonb,uuid)'::regprocedure
  );
  if position('v_actor uuid := auth.uid();' in v_definition) > 0
    and position(
      $anchor$v_unit_cost := nullif(btrim(coalesce(v_line ->> 'unit_cost', '')), '')::numeric(18, 4);$anchor$
      in v_definition
    ) > 0
    and position(
      $anchor$unit_cost = nullif(btrim(coalesce(line_json.value ->> 'unit_cost', '')), '')::numeric(18, 4),$anchor$
      in v_definition
    ) > 0 then
    v_definition := replace(
      v_definition,
      'v_actor uuid := auth.uid();',
      $replacement$v_actor uuid := auth.uid();
  v_can_manage_commercials boolean := public.v1_has_capability('manage_commercials');$replacement$
    );
    v_definition := replace(
      v_definition,
      $anchor$v_unit_cost := nullif(btrim(coalesce(v_line ->> 'unit_cost', '')), '')::numeric(18, 4);$anchor$,
      $replacement$v_unit_cost := nullif(btrim(coalesce(v_line ->> 'unit_cost', '')), '')::numeric(18, 4);
    if v_unit_cost is not null and not v_can_manage_commercials then
      raise exception 'V1_ARRANGEMENT_COMMERCIAL_WRITE_DENIED'
        using errcode = '42501';
    end if;$replacement$
    );
    v_definition := replace(
      v_definition,
      $anchor$unit_cost = nullif(btrim(coalesce(line_json.value ->> 'unit_cost', '')), '')::numeric(18, 4),$anchor$,
      $replacement$unit_cost = case
           when v_can_manage_commercials then nullif(btrim(coalesce(
             line_json.value ->> 'unit_cost', ''
           )), '')::numeric(18, 4)
           else arrangement_line.unit_cost
         end,$replacement$
    );
    execute v_definition;
  elsif position(
      'v_can_manage_commercials boolean := public.v1_has_capability(''manage_commercials'');'
      in v_definition
    ) > 0 and position(
      'V1_ARRANGEMENT_COMMERCIAL_WRITE_DENIED' in v_definition
    ) > 0 then
    null;
  else
    raise exception 'V1_ARRANGEMENT_SAVE_HARDENING_ANCHOR_MISSING';
  end if;
end;
$arrangement_save$;

-- Controlled Material Request output follows the same protected capability as
-- the interactive projection. The line projection omits commercial keys when
-- the boolean is false, so no unauthorized cache/export receives those fields.
do $material_request_document_projection$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_material_request_document_projection(uuid)'::regprocedure
  );
  if position('v_request jsonb;' in v_definition) > 0
    and position(
      'public.v1_material_request_line_projection(line_record.id, false)'
      in v_definition
    ) > 0 then
    v_definition := replace(
      v_definition,
      'v_request jsonb;',
      $replacement$v_include_commercial boolean := public.v1_has_capability('view_commercials');
  v_request jsonb;$replacement$
    );
    v_definition := replace(
      v_definition,
      'public.v1_material_request_line_projection(line_record.id, false)',
      'public.v1_material_request_line_projection(line_record.id, v_include_commercial)'
    );
    execute v_definition;
  elsif position(
      'v_include_commercial boolean := public.v1_has_capability(''view_commercials'');'
      in v_definition
    ) > 0 and position(
      'public.v1_material_request_line_projection(line_record.id, v_include_commercial)'
      in v_definition
    ) > 0 then
    null;
  else
    raise exception 'V1_MR_DOCUMENT_COMMERCIAL_HARDENING_ANCHOR_MISSING';
  end if;
end;
$material_request_document_projection$;

-- Approving an all-unavailable arrangement is a successful, auditable close,
-- not a user cancellation. Preserve cancellation fields for actual cancellation
-- commands only and keep the explicit unavailable terminal action code.
do $all_unavailable_close$
declare
  v_definition text;
  v_old text := $old$update public.v1_material_requests
       set state = 'cancelled', current_action_owner_role = 'none',
           current_action_code = 'unavailable_closed',
           cancelled_at = clock_timestamp(), cancelled_by_auth_user_id = v_actor,
           cancellation_reason = 'All requested items cannot be provided now',
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;$old$;
  v_new text := $new$update public.v1_material_requests
       set state = 'closed', current_action_owner_role = 'none',
           current_action_code = 'unavailable_closed',
           cancelled_at = null, cancelled_by_auth_user_id = null,
           cancellation_reason = null,
           record_version = record_version + 1, updated_at = clock_timestamp()
     where id = v_request.id;$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_decide_arrangement(jsonb,uuid)'::regprocedure
  );
  if position(v_old in v_definition) > 0 then
    v_definition := replace(v_definition, v_old, v_new);
    v_definition := replace(
      v_definition,
      $old$'request_state', case when v_decision = 'approved' then 'approved'
        else 'arranging' end,$old$,
      $new$'request_state', case
        when v_decision = 'approved' and not exists (
          select 1
          from public.v1_procurement_arrangement_lines arrangement_line
          where arrangement_line.arrangement_id = v_arrangement.id
            and arrangement_line.decision in ('full', 'partial')
            and arrangement_line.arranged_qty > 0
        ) then 'closed'
        when v_decision = 'approved' then 'approved'
        else 'arranging'
      end,$new$
    );
    execute v_definition;
  elsif position(v_new in v_definition) > 0 and position(
      'when v_decision = ''approved'' and not exists (' in v_definition
    ) > 0 then
    null;
  else
    raise exception 'V1_ALL_UNAVAILABLE_CLOSE_ANCHOR_MISSING';
  end if;
end;
$all_unavailable_close$;

create or replace function public.v1_can_close_material_request(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_role text := public.v1_current_role();
begin
  if auth.uid() is null or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_role = 'admin' then
    return exists (
      select 1 from public.v1_material_requests request_record
      where request_record.id = p_request_id
    );
  end if;
  select request_record.project_id into v_project_id
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  return v_project_id is not null
    and v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
end;
$$;

create or replace function public.v1_close_material_request(
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
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_approved_qty numeric(18, 4);
  v_good_qty numeric(18, 4);
  v_release_count integer;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['request_id', 'expected_version'],
    'close_material_request'
  );
  v_request_id := nullif(
    btrim(coalesce(p_payload ->> 'request_id', '')), ''
  )::uuid;
  v_expected_version := nullif(
    p_payload ->> 'expected_version', ''
  )::integer;
  if v_request_id is null or v_expected_version is null
    or v_expected_version < 1 then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id
  for update;
  if not found or not public.v1_can_close_material_request(v_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_DENIED' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_close_material_request', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then
    return v_existing_response;
  end if;
  if v_request.state <> 'received' then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_STATE_INVALID'
      using errcode = '22023';
  end if;
  if v_request.record_version <> v_expected_version then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_material_dispatches dispatch
    where dispatch.request_id = v_request.id
      and dispatch.state = 'receipt_pending'
  ) then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_RECEIPT_PENDING'
      using errcode = '22023';
  end if;

  select coalesce(sum(approval.approved_qty), 0)
    into v_approved_qty
  from public.v1_material_request_line_approvals approval
  join public.v1_material_request_lines request_line
    on request_line.id = approval.request_line_id
  where request_line.request_id = v_request.id;
  select coalesce(sum(review_line.good_qty), 0)
    into v_good_qty
  from public.v1_receipt_review_lines review_line
  join public.v1_receipt_reviews review
    on review.id = review_line.receipt_review_id
  where review.request_id = v_request.id
    and review.state = 'confirmed';
  if v_approved_qty <= 0 or v_good_qty < v_approved_qty then
    raise exception 'V1_MATERIAL_REQUEST_CLOSE_QUANTITY_INVALID'
      using errcode = '22023';
  end if;

  v_before := public.v1_material_request_projection(v_request.id);
  update public.v1_inventory_reservations reservation
     set state = 'released', released_at = clock_timestamp(),
         released_by_auth_user_id = v_actor,
         release_reason = 'material_request_closed',
         updated_at = clock_timestamp()
   where reservation.request_id = v_request.id
     and reservation.state in ('active', 'partially_consumed');
  get diagnostics v_release_count = row_count;

  update public.v1_material_requests request_record
     set state = 'closed',
         current_action_owner_role = 'none',
         current_action_code = 'closed',
         record_version = request_record.record_version + 1,
         updated_at = clock_timestamp()
   where request_record.id = v_request.id;

  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select recipient.auth_user_id, 'material_request_closed',
    'material_request', v_request.id, v_request.project_id
  from (
    select v_request.created_by_auth_user_id as auth_user_id
    union
    select profile.auth_user_id
    from public.v1_profiles profile
    where profile.is_active
      and profile.canonical_role_snapshot = 'procurement'
  ) recipient
  where recipient.auth_user_id <> v_actor;

  v_response := public.v1_material_request_projection(v_request.id);
  perform public.v1_write_audit_event(
    'material_request_closed', 'material_request', v_request.id,
    v_request.project_id, v_before,
    jsonb_build_object(
      'state', 'closed',
      'record_version', v_expected_version + 1,
      'released_reservation_count', v_release_count
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_close_material_request', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_arrangement_projection(uuid)
  from public, anon;
revoke all on function public.v1_save_arrangement(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_material_request_document_projection(uuid)
  from public, anon;
revoke all on function public.v1_decide_arrangement(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_can_close_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_close_material_request(jsonb, uuid)
  from public, anon, authenticated;

grant execute on function public.v1_arrangement_projection(uuid)
  to authenticated;
grant execute on function public.v1_save_arrangement(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_material_request_document_projection(uuid)
  to authenticated;
grant execute on function public.v1_decide_arrangement(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_close_material_request(jsonb, uuid)
  to authenticated;

commit;
