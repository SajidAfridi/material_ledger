-- Additive Company audit visibility and catalogue discovery. No stock/state writes.
-- Preserve source IDs, timestamps and exact recorded roles. Historical imports
-- explicitly lack event-time display-name evidence; never fabricate attribution.
-- Rollback: disable Company feature/restore previous artifact. Retain both ledgers
-- and added read functions; remove the bridge trigger only if fixing forward.
begin;

create or replace function public.v1_capture_audit_actor_display_name()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.entity_type='company_material_request'
    and new.after_data->>'snapshot_source'='company_history_import' then
    new.actor_display_name_snapshot := null;
    return new;
  end if;
  select public.v1_safe_profile_display_name(profile.display_name,profile.auth_user_id)
    into new.actor_display_name_snapshot from public.v1_profiles profile
    where profile.auth_user_id=new.actor_auth_user_id;
  return new;
end $$;

-- Some legacy commands stored the normalized workflow role in the exact-role
-- slot. Capture the trusted exact claim for new actor-authored events only;
-- never infer a historical role from the actor's present profile.
create or replace function public.v1_capture_company_event_exact_actor()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.actor_auth_user_id=auth.uid() and public.v1_current_actor_is_active() then
    new.actor_exact_role:=public.v1_current_exact_role();
  end if;
  return new;
end $$;
revoke all on function public.v1_capture_company_event_exact_actor() from public,anon,authenticated;
drop trigger if exists v1_company_event_exact_actor on public.v1_company_material_request_events;
create trigger v1_company_event_exact_actor before insert on public.v1_company_material_request_events
  for each row execute function public.v1_capture_company_event_exact_actor();

create or replace function public.v1_bridge_company_audit_event(p_event_id uuid, p_historical boolean default false)
returns void language plpgsql security definer set search_path='' as $$
begin
  insert into public.v1_audit_events(id,event_type,entity_type,entity_id,
    actor_auth_user_id,actor_role,actor_exact_role,occurred_at,idempotency_key,after_data,reason)
  select e.id,e.event_type,'company_material_request',e.request_id,
    e.actor_auth_user_id,public.v1_canonical_role_from_exact_role(e.actor_exact_role),
    e.actor_exact_role,e.occurred_at,e.id,
    jsonb_strip_nulls(jsonb_build_object(
      'request_number',r.request_number,
      'state',case when p_historical then e.data->>'state' else r.state end,
      'record_version',case when p_historical then e.data->>'record_version' else r.record_version::text end,
      'decision',e.data->>'decision',
      'line_count',e.data->'line_count',
      'snapshot_source',case when p_historical then 'company_history_import' else 'company_event' end,
      'source_event_id',e.id
    )),e.data->>'reason'
  from public.v1_company_material_request_events e
  join public.v1_company_material_requests r on r.id=e.request_id
  where e.id=p_event_id
  on conflict(id) do nothing;
end $$;
revoke all on function public.v1_bridge_company_audit_event(uuid,boolean) from public,anon,authenticated;
grant execute on function public.v1_bridge_company_audit_event(uuid,boolean) to service_role;

create or replace function public.v1_company_audit_event_trigger()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform public.v1_bridge_company_audit_event(new.id,false);
  return new;
end $$;
revoke all on function public.v1_company_audit_event_trigger() from public,anon,authenticated;
drop trigger if exists v1_company_audit_event_bridge on public.v1_company_material_request_events;
create trigger v1_company_audit_event_bridge after insert on public.v1_company_material_request_events
  for each row execute function public.v1_company_audit_event_trigger();

-- Idempotent import, not replay of commands. Original domain records remain intact.
select public.v1_bridge_company_audit_event(id,true) from public.v1_company_material_request_events;

insert into public.v1_audit_event_catalogue(event_type,severity) values
  ('company_request_draft_created','normal'), ('company_request_submitted','normal'),
  ('company_request_approved','normal'), ('company_request_returned','warning'),
  ('company_request_rejected','warning'), ('company_request_resubmitted','normal'),
  ('company_supply_plan_saved','normal'), ('company_material_dispatched','normal'),
  ('company_receipt_confirmed','normal'), ('company_beneficiary_handover_confirmed','normal'),
  ('company_return_submitted','warning'), ('company_return_confirmed','normal'),
  ('company_return_rejected','warning'), ('company_request_closed','normal'),
  ('company_request_remainder_withdrawn','warning')
on conflict(event_type) do nothing;

create or replace function public.v1_search_company_material_request_candidates(
  p_category_id uuid,
  p_responsible_unit_id uuid,
  p_query text,
  p_limit integer default 18
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_query text := lower(regexp_replace(
    btrim(coalesce(p_query, '')), '\s+', ' ', 'g'
  ));
  v_limit integer := least(greatest(coalesce(p_limit, 18), 1), 30);
begin
  if v_actor is null
    or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_active_authorization(
      v_actor, p_category_id, p_responsible_unit_id, 'requester'
    ) then
    raise exception 'V1_COMPANY_MATERIAL_SEARCH_DENIED'
      using errcode = '42501';
  end if;
  if length(v_query) < 2 or length(v_query) > 200
    or not exists (
      select 1
      from public.v1_company_material_request_categories category
      join public.v1_company_material_request_units unit_record
        on unit_record.id = p_responsible_unit_id
      where category.id = p_category_id
        and category.is_active
        and unit_record.is_active
    ) then
    raise exception 'V1_COMPANY_MATERIAL_SEARCH_INVALID'
      using errcode = '22023';
  end if;

  return coalesce((
    with ranked as (
      select item.*,
        lower(concat_ws(' ', item.item_code, item.item_description,
          item.brand_origin, item.size_text, item.model_reference, item.unit
        )) as searchable_text,
        case
          when lower(coalesce(item.item_code, '')) = v_query then 0
          when lower(item.item_description) = v_query then 1
          when strpos(lower(item.item_description), v_query) = 1 then 2
          when strpos(lower(coalesce(item.item_code, '')), v_query) = 1 then 3
          else 4
        end as match_rank
      from public.v1_inventory_items item
      where item.is_active
        and not exists (
          select 1 from unnest(regexp_split_to_array(v_query, ' ')) token
          where strpos(lower(concat_ws(' ',item.item_code,item.item_description,
            item.brand_origin,item.size_text,item.model_reference,item.unit)),token)=0
        )
    ), limited as (
      select * from ranked
      order by match_rank, lower(item_description), id
      limit v_limit
    )
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id', limited.id,
      'source_kind', 'inventory',
      'item_code', limited.item_code,
      'item_description', limited.item_description,
      'brand_origin', limited.brand_origin,
      'size', limited.size_text,
      'model', limited.model_reference,
      'unit', limited.unit
    )) order by limited.match_rank, lower(limited.item_description), limited.id)
    from limited
  ), '[]'::jsonb);
end;
$$;

comment on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) is
  'Returns non-commercial active inventory catalogue suggestions only to an active requester authorized for the selected Company category and unit; stock and project facts are omitted.';

revoke all on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) from public, anon;
grant execute on function public.v1_search_company_material_request_candidates(
  uuid, uuid, text, integer
) to authenticated;


create or replace function public.v1_company_material_request_evidence(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or not public.v1_company_material_request_readable(p_request_id) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE' using errcode='42501';
  end if;
  return jsonb_build_object(
    'events',coalesce((select jsonb_agg(jsonb_build_object(
      'id',e.id,'event_type',e.event_type,'occurred_at',e.occurred_at,
      'actor_display_name',coalesce(a.actor_display_name_snapshot,
        public.v1_safe_profile_display_name(p.display_name,p.auth_user_id)),
      'actor_exact_role',e.actor_exact_role,'reason',e.data->>'reason'
    ) order by e.occurred_at,e.id)
      from public.v1_company_material_request_events e
      left join public.v1_audit_events a on a.id=e.id
      left join public.v1_profiles p on p.auth_user_id=e.actor_auth_user_id
      where e.request_id=p_request_id),'[]'::jsonb),
    'issue_notes',public.v1_list_company_material_issue_notes(p_request_id)
  );
end $$;
revoke all on function public.v1_company_material_request_evidence(uuid) from public,anon;
grant execute on function public.v1_company_material_request_evidence(uuid) to authenticated,service_role;

commit;
