-- Yorks V1 Procurement item clarification.
--
-- Engineering's submitted item remains immutable evidence. Procurement may
-- clarify only the effective item description and model while the current
-- arrangement is still working and unsaved. The request root is locked so a
-- clarification and arrangement save cannot cross in flight.
--
-- Data preservation: existing lines are backfilled into immutable requested
-- snapshots. Effective values remain unchanged. No quantity, commercial,
-- BOQ-provenance, reservation or logistics fact is rewritten.
-- Rollback is forward-only after use: revoke the command and hide its client
-- action. Retain snapshot and audit columns so historical evidence is not lost.

begin;

alter table public.v1_material_request_lines
  add column if not exists requested_item_description text,
  add column if not exists requested_technical_attributes jsonb,
  add column if not exists procurement_clarified_at timestamptz,
  add column if not exists procurement_clarified_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  add column if not exists procurement_clarification_version integer
    not null default 0;

update public.v1_material_request_lines
set requested_item_description = coalesce(
      requested_item_description, item_description
    ),
    requested_technical_attributes = coalesce(
      requested_technical_attributes, technical_attributes, '{}'::jsonb
    )
where requested_item_description is null
   or requested_technical_attributes is null;

alter table public.v1_material_request_lines
  alter column requested_item_description set not null,
  alter column requested_technical_attributes set not null;

alter table public.v1_material_request_lines
  drop constraint if exists v1_mr_lines_requested_description_check;
alter table public.v1_material_request_lines
  add constraint v1_mr_lines_requested_description_check check (
    btrim(requested_item_description) <> ''
  );
alter table public.v1_material_request_lines
  drop constraint if exists v1_mr_lines_requested_technical_object_check;
alter table public.v1_material_request_lines
  add constraint v1_mr_lines_requested_technical_object_check check (
    jsonb_typeof(requested_technical_attributes) = 'object'
  );
alter table public.v1_material_request_lines
  drop constraint if exists v1_mr_lines_clarification_version_check;
alter table public.v1_material_request_lines
  add constraint v1_mr_lines_clarification_version_check check (
    procurement_clarification_version >= 0
  );

create or replace function public.v1_material_request_line_requested_snapshot()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.requested_item_description := coalesce(
      nullif(btrim(new.requested_item_description), ''),
      new.item_description
    );
    new.requested_technical_attributes := coalesce(
      new.requested_technical_attributes,
      new.technical_attributes,
      '{}'::jsonb
    );
  elsif new.requested_item_description is distinct from
      old.requested_item_description
    or new.requested_technical_attributes is distinct from
      old.requested_technical_attributes then
    raise exception 'V1_MATERIAL_REQUEST_REQUESTED_SNAPSHOT_IMMUTABLE'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_request_line_requested_snapshot_trigger
  on public.v1_material_request_lines;
create trigger v1_material_request_line_requested_snapshot_trigger
before insert or update on public.v1_material_request_lines
for each row execute function
  public.v1_material_request_line_requested_snapshot();

revoke all on function public.v1_material_request_line_requested_snapshot()
  from public, anon, authenticated;

-- Preserve the established role-safe shape and add only non-commercial
-- clarification evidence. The current fields remain the effective values used
-- by arrangement, dispatch, receipt, return and controlled documents.
create or replace function public.v1_material_request_line_projection(
  p_line_id uuid,
  p_include_commercial boolean
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', line_record.id,
    'display_order', line_record.display_order,
    'source_kind', line_record.source_kind,
    'source_boq_group_id', line_record.source_boq_group_id,
    'source_boq_row_id', line_record.source_boq_row_id,
    'item_description', line_record.item_description,
    'brand_origin', line_record.brand_origin,
    'technical_attributes', jsonb_strip_nulls(jsonb_build_object(
      'size', line_record.technical_attributes ->> 'size',
      'model', line_record.technical_attributes ->> 'model',
      'equipment_tag', line_record.technical_attributes ->> 'equipment_tag',
      'planning_model_tag',
        line_record.technical_attributes ->> 'planning_model_tag',
      'quantity_suggested',
        line_record.technical_attributes ->> 'quantity_suggested'
    )),
    'requested_item_description', line_record.requested_item_description,
    'requested_technical_attributes', jsonb_strip_nulls(jsonb_build_object(
      'size', line_record.requested_technical_attributes ->> 'size',
      'model', line_record.requested_technical_attributes ->> 'model',
      'equipment_tag',
        line_record.requested_technical_attributes ->> 'equipment_tag',
      'planning_model_tag',
        line_record.requested_technical_attributes ->> 'planning_model_tag',
      'quantity_suggested',
        line_record.requested_technical_attributes ->> 'quantity_suggested'
    )),
    'procurement_clarified_at', line_record.procurement_clarified_at,
    'procurement_clarification_version',
      line_record.procurement_clarification_version,
    'procurement_clarified_by_display_name', case
      when clarifier.auth_user_id is null then null
      else public.v1_safe_profile_display_name(
        clarifier.display_name, clarifier.auth_user_id
      )
    end,
    'requested_qty', line_record.requested_qty::text,
    'unit', line_record.unit
  ) || case when p_include_commercial then jsonb_strip_nulls(
    jsonb_build_object(
      'unit_cost', commercial.unit_cost::text,
      'total_cost', (line_record.requested_qty * commercial.unit_cost)::text,
      'currency_code', commercial.currency_code
    )
  ) else '{}'::jsonb end
  from public.v1_material_request_lines line_record
  left join public.v1_material_request_line_commercials commercial
    on commercial.request_line_id = line_record.id
  left join public.v1_profiles clarifier
    on clarifier.auth_user_id =
      line_record.procurement_clarified_by_auth_user_id
  where line_record.id = p_line_id;
$$;

-- Extend the active arrangement projection while preserving all prior Phase 3
-- policy keys and commercial omission behavior.
alter function public.v1_arrangement_projection(uuid)
  rename to v1_arrangement_projection_before_procurement_clarification;

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
begin
  v_result := public.v1_arrangement_projection_before_procurement_clarification(
    p_request_id
  );
  select jsonb_set(
    v_result,
    '{arrangements}',
    coalesce(jsonb_agg(
      (arrangement_entry.value - 'lines') || jsonb_build_object(
        'lines', coalesce((
          select jsonb_agg(
            line_entry.value || jsonb_strip_nulls(jsonb_build_object(
              'model_reference',
                request_line.technical_attributes ->> 'model',
              'requested_item_description',
                request_line.requested_item_description,
              'requested_model_reference',
                request_line.requested_technical_attributes ->> 'model',
              'procurement_clarified_at',
                request_line.procurement_clarified_at,
              'procurement_clarification_version',
                request_line.procurement_clarification_version,
              'procurement_clarified_by_display_name', case
                when clarifier.auth_user_id is null then null
                else public.v1_safe_profile_display_name(
                  clarifier.display_name, clarifier.auth_user_id
                )
              end
            )) order by line_entry.ordinality
          )
          from jsonb_array_elements(coalesce(
            arrangement_entry.value -> 'lines', '[]'::jsonb
          )) with ordinality line_entry(value, ordinality)
          join public.v1_procurement_arrangement_lines arrangement_line
            on arrangement_line.id = (line_entry.value ->> 'id')::uuid
          join public.v1_material_request_lines request_line
            on request_line.id = arrangement_line.request_line_id
          left join public.v1_profiles clarifier
            on clarifier.auth_user_id =
              request_line.procurement_clarified_by_auth_user_id
        ), '[]'::jsonb)
      ) order by arrangement_entry.ordinality
    ), '[]'::jsonb)
  ) into v_result
  from jsonb_array_elements(coalesce(
    v_result -> 'arrangements', '[]'::jsonb
  )) with ordinality arrangement_entry(value, ordinality);
  return v_result;
end;
$$;

revoke all on function
  public.v1_arrangement_projection_before_procurement_clarification(uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_arrangement_projection_before_procurement_clarification(uuid)
  to service_role;
revoke all on function public.v1_arrangement_projection(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_arrangement_projection(uuid)
  to authenticated, service_role;

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

  -- A confirmed retry remains successful even if the first execution changed
  -- the request version or arrangement state.
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
  if v_request.state <> 'arranging' or not exists (
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

  v_before := jsonb_strip_nulls(jsonb_build_object(
    'item_description', v_line.item_description,
    'model_reference', v_line.technical_attributes ->> 'model',
    'clarification_version', v_line.procurement_clarification_version
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
  set record_version = record_version + 1,
      updated_at = clock_timestamp()
  where request_record.id = v_request.id;

  v_after := jsonb_strip_nulls(jsonb_build_object(
    'item_description', v_description,
    'model_reference', v_model,
    'clarification_version', v_line.procurement_clarification_version + 1,
    'requested_item_description', v_line.requested_item_description,
    'requested_model_reference',
      v_line.requested_technical_attributes ->> 'model'
  ));
  perform public.v1_write_audit_event(
    'procurement_item_clarified', 'material_request_line', v_line.id,
    v_request.project_id, v_before, v_after,
    'Procurement clarified item identity before arrangement save',
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
  'Clarifies effective MR line description/model during an unsaved working arrangement while retaining immutable requested evidence.';

revoke all on function
  public.v1_update_material_request_procurement_item(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function
  public.v1_update_material_request_procurement_item(jsonb, uuid)
  to authenticated, service_role;

commit;
