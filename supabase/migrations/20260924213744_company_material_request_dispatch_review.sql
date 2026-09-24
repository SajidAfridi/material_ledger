-- Additive, role-safe UI projection only. No lifecycle, stock or history writes.
-- Preserve existing Company projection authorization, fields and technical data.
-- Rollback: Company feature off / previous application artifact. Keep this
-- compatible read field and all retained requests, plans and movements.
begin;

do $$
begin
  if to_regprocedure('public.v1_company_material_request_projection_dispatch_review_base(uuid)') is null then
    alter function public.v1_company_material_request_projection(uuid)
      rename to v1_company_material_request_projection_dispatch_review_base;
  end if;
end;
$$;
revoke all on function public.v1_company_material_request_projection_dispatch_review_base(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_company_material_request_projection_dispatch_review_base(uuid) to service_role;

create or replace function public.v1_company_material_request_projection(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_supply_lines jsonb;
  v_dispatchable boolean;
begin
  -- The retained function performs the active actor and per-request access check.
  v_result := public.v1_company_material_request_projection_dispatch_review_base(p_request_id);
  if jsonb_typeof(v_result->'current_supply_plan') = 'object' then
    select coalesce(jsonb_agg(supply.value || jsonb_build_object(
      'dispatchable_qty', least(
        greatest((supply.value->>'arranged_qty')::numeric - coalesce((
          select sum(dispatch_line.dispatched_qty)
          from public.v1_company_material_dispatch_lines dispatch_line
          where dispatch_line.supply_line_id = (supply.value->>'id')::uuid
        ), 0), 0),
        greatest((request_line.value->>'withdrawable_qty')::numeric, 0)
      )::text
    ) order by supply.ordinality), '[]'::jsonb)
    into v_supply_lines
    from jsonb_array_elements(v_result->'current_supply_plan'->'lines') with ordinality supply(value, ordinality)
    join lateral jsonb_array_elements(v_result->'lines') request_line(value)
      on request_line.value->>'id' = supply.value->>'request_line_id';
    v_result := jsonb_set(v_result, '{current_supply_plan,lines}', v_supply_lines);
    select coalesce(bool_or((line->>'dispatchable_qty')::numeric > 0), false)
      into v_dispatchable from jsonb_array_elements(v_supply_lines) line;
    v_result := v_result || jsonb_build_object('can_dispatch',
      coalesce((v_result->>'can_dispatch')::boolean, false) and v_dispatchable);
  end if;
  return v_result;
end;
$$;
revoke all on function public.v1_company_material_request_projection(uuid) from public, anon;
grant execute on function public.v1_company_material_request_projection(uuid) to authenticated, service_role;

-- Search, counts and pagination apply to the complete authorized Company set.
-- The legacy inbox remains a candidate selector; every candidate is rechecked
-- against the current protected readability predicate before it is returned.
create or replace function public.v1_company_material_request_workspace_page(
  p_view text default 'requests', p_query text default '',
  p_offset integer default 0, p_limit integer default 15
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_work_ids uuid[];
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or p_view is null or p_view not in ('requests','my_work','planning','issue_history')
    or p_offset is null or p_offset < 0 or p_limit is null or p_limit < 1 or p_limit > 100
    or char_length(coalesce(p_query,'')) > 300
    or (p_view = 'planning' and public.v1_current_role() <> 'procurement') then
    raise exception 'V1_COMPANY_REGISTER_DENIED' using errcode = '42501';
  end if;
  if p_view = 'my_work' then
    select coalesce(array_agg((item->>'id')::uuid), '{}'::uuid[]) into v_work_ids
      from jsonb_array_elements(public.v1_list_company_material_request_work_inbox()) item;
  end if;
  with candidates as materialized (
    select r.*, c.display_name category_name, u.display_name responsible_unit_name,
      (select note.issue_note_number from public.v1_company_material_issue_notes note
        where note.request_id = r.id order by note.created_at desc limit 1) issue_number
    from public.v1_company_material_requests r
    join public.v1_company_material_request_categories c on c.id = r.category_id
    join public.v1_company_material_request_units u on u.id = r.responsible_unit_id
    where public.v1_company_material_request_readable(r.id)
      and (p_view <> 'my_work' or r.id = any(v_work_ids))
      and (p_view <> 'planning' or r.state in ('approved_for_procurement','arranging',
        'ready_for_delivery','partially_dispatched','receipt_pending','partially_received',
        'awaiting_beneficiary_handover','fulfilled','closed'))
      and (p_view <> 'issue_history' or exists (select 1 from public.v1_company_material_issue_notes n where n.request_id=r.id))
  ), matching as materialized (
    select * from candidates where strpos(lower(concat_ws(' ', request_number, purpose,
      requester_display_name, beneficiary_display_name, responsible_unit_name, issue_number)), lower(btrim(coalesce(p_query,'')))) > 0
  ), page as (
    select * from matching order by updated_at desc,id offset p_offset limit p_limit
  ) select jsonb_build_object(
    'total_count', (select count(*) from matching),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
      'id', r.id, 'request_number', case when p_view='issue_history' then r.issue_number else r.request_number end,
      'state', r.state, 'record_version', r.record_version, 'category_name', r.category_name,
      'responsible_unit_name', r.responsible_unit_name, 'purpose', r.purpose,
      'requester_display_name', r.requester_display_name, 'beneficiary_display_name', r.beneficiary_display_name,
      'submitted_at', r.submitted_at, 'created_at', r.created_at, 'updated_at', r.updated_at,
      'line_count', (select count(*) from public.v1_company_material_request_lines line where line.request_id=r.id)
    ) order by r.updated_at desc,r.id) from page r), '[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;
revoke all on function public.v1_company_material_request_workspace_page(text,text,integer,integer) from public, anon;
grant execute on function public.v1_company_material_request_workspace_page(text,text,integer,integer) to authenticated, service_role;

commit;
