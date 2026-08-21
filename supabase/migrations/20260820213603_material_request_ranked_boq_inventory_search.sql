-- Yorks V1: ranked, non-commercial material discovery and arrangement
-- provenance. This migration is additive: the legacy inventory-only lookup
-- remains available for older clients, while current clients search the
-- selected BOQ scope, the remaining project BOQ, and inventory in that order.

begin;

create or replace function public.v1_search_material_request_candidates(
  p_project_id uuid,
  p_scope_id uuid,
  p_query text,
  p_limit integer default 18
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := lower(regexp_replace(
    btrim(coalesce(p_query, '')), '\s+', ' ', 'g'
  ));
  v_limit integer := least(greatest(coalesce(p_limit, 18), 1), 30);
begin
  if auth.uid() is null
    or not public.v1_current_actor_is_active()
    or not coalesce(public.v1_project_readable(p_project_id), false) then
    raise exception 'V1_MATERIAL_REQUEST_CANDIDATE_SEARCH_DENIED'
      using errcode = '42501';
  end if;

  if length(v_query) < 2
    or not exists (
      select 1
      from public.v1_project_scopes scope_record
      where scope_record.id = p_scope_id
        and scope_record.project_id = p_project_id
        and scope_record.is_active
    ) then
    raise exception 'V1_MATERIAL_REQUEST_CANDIDATE_SEARCH_INVALID'
      using errcode = '22023';
  end if;

  return coalesce((
    with candidates as (
      select
        row_record.id,
        case when group_record.scope_id = p_scope_id
          then 'scope_boq' else 'project_boq' end as source_kind,
        case when group_record.scope_id = p_scope_id then 0 else 1 end
          as source_priority,
        null::text as item_code,
        nullif(btrim(row_record.canonical_values ->> 'description'), '')
          as item_description,
        nullif(btrim(row_record.canonical_values ->> 'brand_origin'), '')
          as brand_origin,
        nullif(btrim(row_record.canonical_values ->> 'size'), '') as size_text,
        coalesce(
          nullif(btrim(row_record.canonical_values ->> 'model'), ''),
          nullif(btrim(row_record.canonical_values ->> 'planning_model_tag'), '')
        ) as model_reference,
        nullif(btrim(row_record.canonical_values ->> 'equipment_tag'), '')
          as equipment_tag,
        nullif(btrim(row_record.canonical_values ->> 'unit'), '') as unit,
        group_record.id as source_boq_group_id,
        row_record.id as source_boq_row_id,
        group_record.scope_id as source_scope_id,
        scope_record.name as source_scope_name,
        group_record.worksheet_title as source_group_name,
        lower(concat_ws(' ',
          row_record.canonical_values ->> 'description',
          row_record.canonical_values ->> 'brand_origin',
          row_record.canonical_values ->> 'size',
          row_record.canonical_values ->> 'model',
          row_record.canonical_values ->> 'planning_model_tag',
          row_record.canonical_values ->> 'equipment_tag',
          group_record.worksheet_title,
          scope_record.name
        )) as searchable_text
      from public.v1_boq_rows row_record
      join public.v1_boq_groups group_record
        on group_record.id = row_record.group_id
      left join public.v1_project_scopes scope_record
        on scope_record.id = group_record.scope_id
      where group_record.project_id = p_project_id
        and not group_record.is_archived
        and not row_record.is_archived
        and (scope_record.id is null or scope_record.is_active)
        and nullif(btrim(row_record.canonical_values ->> 'description'), '')
          is not null
        and nullif(btrim(row_record.canonical_values ->> 'unit'), '') is not null

      union all

      select
        item.id,
        'inventory'::text as source_kind,
        2 as source_priority,
        item.item_code,
        item.item_description,
        item.brand_origin,
        item.size_text,
        item.model_reference,
        null::text as equipment_tag,
        item.unit,
        null::uuid as source_boq_group_id,
        null::uuid as source_boq_row_id,
        null::uuid as source_scope_id,
        null::text as source_scope_name,
        null::text as source_group_name,
        lower(concat_ws(' ',
          item.item_code, item.item_description, item.brand_origin,
          item.size_text, item.model_reference, item.unit
        )) as searchable_text
      from public.v1_inventory_items item
      where item.is_active
    ), ranked as (
      select candidate.*,
        case
          when lower(coalesce(candidate.item_code, '')) = v_query then 0
          when lower(candidate.item_description) = v_query then 1
          when lower(candidate.item_description) like v_query || '%' then 2
          when lower(coalesce(candidate.item_code, '')) like v_query || '%'
            then 3
          when position(' ' || v_query in ' ' || candidate.searchable_text) > 0
            then 4
          else 5
        end as match_rank
      from candidates candidate
      where position(v_query in candidate.searchable_text) > 0
    ), limited as (
      select * from ranked
      order by source_priority, match_rank, lower(item_description), id
      limit v_limit
    )
    select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
      'id', limited.id,
      'source_kind', limited.source_kind,
      'item_code', limited.item_code,
      'item_description', limited.item_description,
      'brand_origin', limited.brand_origin,
      'size', limited.size_text,
      'model', limited.model_reference,
      'equipment_tag', limited.equipment_tag,
      'unit', limited.unit,
      'source_boq_group_id', limited.source_boq_group_id,
      'source_boq_row_id', limited.source_boq_row_id,
      'source_scope_id', limited.source_scope_id,
      'source_scope_name', limited.source_scope_name,
      'source_group_name', limited.source_group_name
    )) order by limited.source_priority, limited.match_rank,
       lower(limited.item_description), limited.id)
    from limited
  ), '[]'::jsonb);
end;
$$;

comment on function public.v1_search_material_request_candidates(
  uuid, uuid, text, integer
) is
  'Returns authorized non-commercial material suggestions ordered by selected-scope BOQ, project BOQ, then inventory; never enforces stock at request creation.';

revoke all on function public.v1_search_material_request_candidates(
  uuid, uuid, text, integer
) from public, anon;
grant execute on function public.v1_search_material_request_candidates(
  uuid, uuid, text, integer
) to authenticated;

-- Preserve the already-hardened commercial projection shape while adding the
-- immutable request-line BOQ correlation Procurement needs during arrangement.
do $arrangement_correlation$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_arrangement_projection(uuid)'::regprocedure
  );
  if position(
      $anchor$'request_source_kind', request_line.source_kind,$anchor$
      in v_definition
    ) > 0 then
    null;
  elsif position(
      $anchor$'item_description', request_line.item_description,$anchor$
      in v_definition
    ) > 0 and position(
      $anchor$join public.v1_material_request_lines request_line
            on request_line.id = arrangement_line.request_line_id
          left join public.v1_inventory_items inventory_item$anchor$
      in v_definition
    ) > 0 then
    v_definition := replace(
      v_definition,
      $anchor$'item_description', request_line.item_description,$anchor$,
      $replacement$'item_description', request_line.item_description,
            'request_source_kind', request_line.source_kind,
            'source_boq_group_id', request_line.source_boq_group_id,
            'source_boq_row_id', request_line.source_boq_row_id,
            'source_boq_group_name', source_group.worksheet_title,
            'source_scope_name', source_scope.name,$replacement$
    );
    v_definition := replace(
      v_definition,
      $anchor$join public.v1_material_request_lines request_line
            on request_line.id = arrangement_line.request_line_id
          left join public.v1_inventory_items inventory_item$anchor$,
      $replacement$join public.v1_material_request_lines request_line
            on request_line.id = arrangement_line.request_line_id
          left join public.v1_boq_groups source_group
            on source_group.id = request_line.source_boq_group_id
          left join public.v1_project_scopes source_scope
            on source_scope.id = source_group.scope_id
          left join public.v1_inventory_items inventory_item$replacement$
    );
    execute v_definition;
  else
    raise exception 'V1_ARRANGEMENT_CORRELATION_PROJECTION_ANCHOR_MISSING';
  end if;
end;
$arrangement_correlation$;

commit;
