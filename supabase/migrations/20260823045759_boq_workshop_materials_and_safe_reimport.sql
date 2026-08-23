-- Product-owner revision, 23 August 2026:
--   * new Common/building BOQ scopes start with Workshop Materials only;
--   * historical default folders remain stored, and only folders carrying
--     real history remain visible;
--   * worksheet saves/imports replace the active snapshot without colliding
--     with archived display orders or with rows/columns from the prior
--     snapshot.

begin;

-- Template order used to be globally unique even for inactive templates.
-- Keep the historical catalogue intact but constrain only the active seed set.
alter table public.v1_boq_group_templates
  drop constraint if exists v1_boq_group_templates_display_order_key,
  drop constraint if exists v1_boq_group_templates_display_order_check;

alter table public.v1_boq_group_templates
  add constraint v1_boq_group_templates_display_order_check
  check (display_order > 0);

create unique index if not exists v1_boq_group_templates_active_order_key
  on public.v1_boq_group_templates (display_order)
  where is_active;

update public.v1_boq_group_templates
set is_active = false
where template_key <> 'workshop_materials'
  and is_active;

insert into public.v1_boq_group_templates (
  template_key, display_name, display_order, is_frozen, is_active
)
values ('workshop_materials', 'Workshop Materials', 1, true, true)
on conflict (template_key) do update
set display_name = excluded.display_name,
    display_order = excluded.display_order,
    is_active = true;

-- Add the new default to every real scope. Existing historical groups keep
-- their identity and ordering; the new folder takes the next safe position
-- when order 1 is already occupied.
insert into public.v1_boq_groups (
  project_id, scope_id, template_id, name, worksheet_title, display_order,
  is_custom, created_by_auth_user_id, created_at, updated_at
)
select
  scope_record.project_id,
  scope_record.id,
  template.id,
  template.display_name,
  template.display_name,
  coalesce((
    select max(existing.display_order) + 1
    from public.v1_boq_groups existing
    where existing.scope_id = scope_record.id
      and not existing.is_archived
  ), template.display_order),
  false,
  project_record.created_by_auth_user_id,
  clock_timestamp(),
  clock_timestamp()
from public.v1_project_scopes scope_record
join public.v1_projects project_record
  on project_record.id = scope_record.project_id
cross join public.v1_boq_group_templates template
where scope_record.is_active
  and template.template_key = 'workshop_materials'
  and template.is_active
  and not exists (
    select 1
    from public.v1_boq_groups existing
    where existing.scope_id = scope_record.id
      and existing.template_id = template.id
      and not existing.is_archived
  );

-- Archived rows and columns are history, not part of the active worksheet
-- coordinate system. This also permits a later import to reuse positions 1..N.
alter table public.v1_boq_columns
  drop constraint if exists v1_boq_columns_group_id_display_order_key;
alter table public.v1_boq_rows
  drop constraint if exists v1_boq_rows_group_id_display_order_key;

create unique index if not exists v1_boq_columns_active_group_order_key
  on public.v1_boq_columns (group_id, display_order)
  where not is_archived;
create unique index if not exists v1_boq_rows_active_group_order_key
  on public.v1_boq_rows (group_id, display_order)
  where not is_archived;

-- Scope listings suppress only inactive template shells with no history. A
-- legacy folder remains visible when it has ever held a row/column, is linked
-- to a document, or sourced a Material Request.
create or replace function public.v1_boq_group_has_history(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    exists (select 1 from public.v1_boq_rows row_record
      where row_record.group_id = p_group_id)
    or exists (select 1 from public.v1_boq_columns column_record
      where column_record.group_id = p_group_id)
    or exists (select 1 from public.v1_document_links link_record
      where link_record.entity_type = 'boq_group'
        and link_record.entity_id = p_group_id)
    or exists (select 1 from public.v1_material_request_lines line_record
      where line_record.source_boq_group_id = p_group_id);
$$;

create or replace function public.v1_list_boq_groups_for_scope(
  p_project_id uuid,
  p_scope_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_BOQ_PROJECT_NOT_READABLE' using errcode = '42501';
  end if;
  if p_scope_id is not null and not exists (
    select 1 from public.v1_project_scopes scope_record
    where scope_record.id = p_scope_id
      and scope_record.project_id = p_project_id
      and scope_record.is_active
  ) then
    raise exception 'V1_BOQ_SCOPE_NOT_READABLE' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.v1_boq_group_projection(group_record.id)
      order by
        case when group_record.scope_id is null then 0 else 1 end,
        case scope_record.scope_kind when 'common' then 0 else 1 end,
        lower(coalesce(scope_record.scope_code, '')),
        group_record.display_order,
        group_record.created_at)
    from public.v1_boq_groups group_record
    left join public.v1_project_scopes scope_record
      on scope_record.id = group_record.scope_id
    left join public.v1_boq_group_templates template
      on template.id = group_record.template_id
    where group_record.project_id = p_project_id
      and not group_record.is_archived
      and (p_scope_id is null or group_record.scope_id = p_scope_id)
      and (
        group_record.is_custom
        or template.is_active
        or public.v1_boq_group_has_history(group_record.id)
      )
  ), '[]'::jsonb);
end;
$$;

-- The trusted save command validates the complete proposed snapshot before it
-- moves the current active coordinates out of the way. All changes remain in
-- one transaction, so any later validation error restores the old snapshot.
create or replace function public.v1_save_boq_worksheet(
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
  v_group_id uuid;
  v_expected_version integer;
  v_title text;
  v_reason text;
  v_columns jsonb;
  v_rows jsonb;
  v_column jsonb;
  v_row jsonb;
  v_column_id uuid;
  v_row_id uuid;
  v_heading text;
  v_order integer;
  v_canonical text;
  v_is_commercial boolean;
  v_group public.v1_boq_groups%rowtype;
  v_project_state text;
  v_existing_response jsonb;
  v_response jsonb;
  v_existing_row public.v1_boq_rows%rowtype;
  v_submitted_values jsonb;
  v_clean_operational_values jsonb;
  v_clean_commercial_values jsonb;
  v_merged_values jsonb;
  v_merged_commercial_values jsonb;
  v_canonical_values jsonb;
  v_value_key text;
  v_value jsonb;
  v_archived_columns integer := 0;
  v_archived_rows integer := 0;
  v_max_submitted_column_order integer := 0;
  v_snapshot_started timestamptz := clock_timestamp();
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['group_id', 'expected_version', 'worksheet_title', 'columns', 'rows', 'reason'],
    'boq_worksheet'
  );
  v_group_id := nullif(btrim(coalesce(p_payload ->> 'group_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_title := nullif(btrim(coalesce(p_payload ->> 'worksheet_title', '')), '');
  v_reason := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_columns := coalesce(p_payload -> 'columns', '[]'::jsonb);
  v_rows := coalesce(p_payload -> 'rows', '[]'::jsonb);
  if v_group_id is null or v_expected_version is null or v_expected_version < 1
    or v_title is null or v_reason is null
    or jsonb_typeof(v_columns) <> 'array' or jsonb_typeof(v_rows) <> 'array' then
    raise exception 'V1_BOQ_WORKSHEET_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  if exists (
    select 1 from (
      select value ->> 'id' key, count(*) total
      from jsonb_array_elements(v_columns) group by value ->> 'id'
    ) duplicate where duplicate.key is null or duplicate.total > 1
  ) or exists (
    select 1 from (
      select value ->> 'display_order' key, count(*) total
      from jsonb_array_elements(v_columns) group by value ->> 'display_order'
    ) duplicate where duplicate.key is null or duplicate.total > 1
  ) then
    raise exception 'V1_BOQ_COLUMN_ID_OR_ORDER_DUPLICATE' using errcode = '22023';
  end if;
  if exists (
    select 1 from (
      select value ->> 'id' key, count(*) total
      from jsonb_array_elements(v_rows) group by value ->> 'id'
    ) duplicate where duplicate.key is null or duplicate.total > 1
  ) or exists (
    select 1 from (
      select value ->> 'display_order' key, count(*) total
      from jsonb_array_elements(v_rows) group by value ->> 'display_order'
    ) duplicate where duplicate.key is null or duplicate.total > 1
  ) then
    raise exception 'V1_BOQ_ROW_ID_OR_ORDER_DUPLICATE' using errcode = '22023';
  end if;
  if exists (
    select 1 from (
      select lower(btrim(value ->> 'heading')) key, count(*) total
      from jsonb_array_elements(v_columns)
      group by lower(btrim(value ->> 'heading'))
    ) duplicate where duplicate.key is null or duplicate.key = '' or duplicate.total > 1
  ) or exists (
    select 1 from (
      select nullif(value ->> 'canonical_field', '') key, count(*) total
      from jsonb_array_elements(v_columns)
      where nullif(value ->> 'canonical_field', '') is not null
      group by nullif(value ->> 'canonical_field', '')
    ) duplicate where duplicate.total > 1
  ) then
    raise exception 'V1_BOQ_COLUMN_MAPPING_DUPLICATE' using errcode = '22023';
  end if;

  select * into v_group from public.v1_boq_groups group_record
  where group_record.id = v_group_id for update;
  if not found or v_group.scope_id is null
    or not public.v1_can_edit_boq_project(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;
  select state into v_project_state from public.v1_projects where id = v_group.project_id;
  if v_group.is_archived or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_save_boq_worksheet', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  -- Validate row shapes and scalar cells against either an existing historical
  -- column or a column in the proposed snapshot. This runs only after project
  -- authority and version checks, so validation cannot expose another
  -- project's column identifiers.
  for v_row in select value from jsonb_array_elements(v_rows)
  loop
    perform public.v1_assert_object_keys(v_row, array['id', 'display_order', 'raw_values'], 'boq_row');
    if jsonb_typeof(coalesce(v_row -> 'raw_values', '{}'::jsonb)) <> 'object' then
      raise exception 'V1_BOQ_VALUES_MUST_BE_AN_OBJECT' using errcode = '22023';
    end if;
    for v_value_key, v_value in
      select key, value from jsonb_each(coalesce(v_row -> 'raw_values', '{}'::jsonb))
    loop
      if jsonb_typeof(v_value) not in ('string', 'number', 'boolean', 'null') then
        raise exception 'V1_BOQ_VALUES_MUST_BE_SCALARS' using errcode = '22023';
      end if;
      if not exists (
        select 1 from public.v1_boq_columns existing
        where existing.group_id = v_group_id and existing.id::text = v_value_key
      ) and not exists (
        select 1 from jsonb_array_elements(v_columns) submitted
        where submitted ->> 'id' = v_value_key
      ) then
        raise exception 'V1_BOQ_VALUE_COLUMN_NOT_ALLOWED' using errcode = '22023';
      end if;
    end loop;
  end loop;

  if exists (
    select 1 from public.v1_boq_columns existing
    join jsonb_array_elements(v_columns) submitted
      on submitted ->> 'id' = existing.id::text
    where existing.group_id <> v_group_id
  ) then
    raise exception 'V1_BOQ_COLUMN_ID_SCOPE_CONFLICT' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.v1_boq_rows existing
    join jsonb_array_elements(v_rows) submitted
      on submitted ->> 'id' = existing.id::text
    where existing.group_id <> v_group_id
  ) then
    raise exception 'V1_BOQ_ROW_ID_SCOPE_CONFLICT' using errcode = '22023';
  end if;

  select count(*) into v_archived_rows
  from public.v1_boq_rows row_record
  where row_record.group_id = v_group_id and not row_record.is_archived
    and not exists (select 1 from jsonb_array_elements(v_rows) submitted
      where submitted ->> 'id' = row_record.id::text);
  select count(*) into v_archived_columns
  from public.v1_boq_columns column_record
  where column_record.group_id = v_group_id
    and not column_record.is_archived and not column_record.is_commercial
    and not exists (select 1 from jsonb_array_elements(v_columns) submitted
      where submitted ->> 'id' = column_record.id::text);

  -- Archive the old operational snapshot first. Submitted records are
  -- reactivated below, while omitted records remain immutable history. This
  -- prevents collisions on order, heading and canonical mapping.
  update public.v1_boq_columns
  set is_archived = true, archived_at = v_snapshot_started,
      archived_by_auth_user_id = v_actor
  where group_id = v_group_id and not is_archived and not is_commercial;
  update public.v1_boq_rows
  set is_archived = true, archived_at = v_snapshot_started,
      archived_by_auth_user_id = v_actor
  where group_id = v_group_id and not is_archived;
  -- Commercial definitions are never archived by an operational import. Move
  -- them temporarily so submitted commercial columns can still be reordered.
  update public.v1_boq_columns
  set display_order = display_order + 1000000
  where group_id = v_group_id and not is_archived and is_commercial;

  for v_column in select value from jsonb_array_elements(v_columns)
  loop
    perform public.v1_assert_object_keys(
      v_column, array['id', 'heading', 'display_order', 'canonical_field', 'is_commercial'],
      'boq_column'
    );
    v_column_id := nullif(btrim(coalesce(v_column ->> 'id', '')), '')::uuid;
    v_heading := nullif(btrim(coalesce(v_column ->> 'heading', '')), '');
    v_order := nullif(v_column ->> 'display_order', '')::integer;
    v_canonical := nullif(btrim(coalesce(v_column ->> 'canonical_field', '')), '');
    v_is_commercial := coalesce((v_column ->> 'is_commercial')::boolean, false);
    if v_column_id is null or v_heading is null or v_order is null
      or v_order < 1 or v_order > 100000
      or (v_canonical is not null and v_canonical not in (
        'description', 'size', 'model', 'equipment_tag', 'brand_origin',
        'quantity', 'unit', 'unit_cost', 'total_cost', 'planning_model_tag'
      )) then
      raise exception 'V1_BOQ_COLUMN_INVALID' using errcode = '22023';
    end if;
    if public.v1_required_boq_commercial_canonical(v_heading) is not null
      and (
        v_canonical is distinct from public.v1_required_boq_commercial_canonical(v_heading)
        or not v_is_commercial
      )
      and (not v_is_commercial or public.v1_has_capability('manage_commercials')) then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if v_canonical in ('unit_cost', 'total_cost') and not v_is_commercial then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if v_is_commercial and not public.v1_has_capability('manage_commercials') then
      raise exception 'V1_BOQ_COMMERCIAL_COLUMN_DENIED' using errcode = '42501';
    end if;
    if exists (
      select 1 from public.v1_boq_columns existing
      where existing.group_id = v_group_id and existing.id = v_column_id
        and existing.is_commercial <> v_is_commercial
    ) then
      raise exception 'V1_BOQ_COLUMN_CLASSIFICATION_IMMUTABLE' using errcode = '22023';
    end if;
    insert into public.v1_boq_columns (
      id, group_id, heading, display_order, canonical_field, is_commercial,
      created_by_auth_user_id, created_at, updated_at
    ) values (
      v_column_id, v_group_id, v_heading, v_order, v_canonical, v_is_commercial,
      v_actor, clock_timestamp(), clock_timestamp()
    ) on conflict (id) do update set
      heading = excluded.heading,
      display_order = excluded.display_order,
      canonical_field = excluded.canonical_field,
      record_version = public.v1_boq_columns.record_version + 1,
      updated_at = clock_timestamp(),
      is_archived = false,
      archived_at = null,
      archived_by_auth_user_id = null
    where public.v1_boq_columns.group_id = v_group_id;
    v_max_submitted_column_order := greatest(v_max_submitted_column_order, v_order);
  end loop;

  for v_row in select value from jsonb_array_elements(v_rows)
  loop
    perform public.v1_assert_object_keys(v_row, array['id', 'display_order', 'raw_values'], 'boq_row');
    v_row_id := nullif(btrim(coalesce(v_row ->> 'id', '')), '')::uuid;
    v_order := nullif(v_row ->> 'display_order', '')::integer;
    v_submitted_values := coalesce(v_row -> 'raw_values', '{}'::jsonb);
    if v_row_id is null or v_order is null or v_order < 1 or v_order > 100000 then
      raise exception 'V1_BOQ_ROW_INVALID' using errcode = '22023';
    end if;
    -- Removed-column values may still be present in the last editable client
    -- snapshot. They remain in the archived row history but are not copied into
    -- the new active value map.
    select coalesce(jsonb_object_agg(cell.key, cell.value), '{}'::jsonb)
      into v_submitted_values
    from jsonb_each(v_submitted_values) cell
    join public.v1_boq_columns column_record
      on column_record.id::text = cell.key
      and column_record.group_id = v_group_id
      and not column_record.is_archived;
    select split.operational_values, split.commercial_values
      into v_clean_operational_values, v_clean_commercial_values
    from public.v1_split_boq_values(v_submitted_values, v_group_id) split;
    if v_clean_commercial_values <> '{}'::jsonb
      and not public.v1_has_capability('manage_commercials') then
      raise exception 'V1_BOQ_COMMERCIAL_VALUE_DENIED' using errcode = '42501';
    end if;
    select * into v_existing_row from public.v1_boq_rows existing
    where existing.id = v_row_id and existing.group_id = v_group_id;
    v_merged_values := coalesce(v_existing_row.raw_values, '{}'::jsonb)
      || v_clean_operational_values;
    v_merged_commercial_values :=
      coalesce(v_existing_row.commercial_values, '{}'::jsonb)
      || v_clean_commercial_values;
    select coalesce(jsonb_object_agg(column_record.canonical_field,
      v_merged_values -> column_record.id::text), '{}'::jsonb)
      into v_canonical_values
    from public.v1_boq_columns column_record
    where column_record.group_id = v_group_id
      and not column_record.is_archived
      and not column_record.is_commercial
      and column_record.canonical_field is not null
      and v_merged_values ? column_record.id::text;

    insert into public.v1_boq_rows (
      id, group_id, display_order, raw_values, commercial_values, canonical_values,
      created_by_auth_user_id, created_at, updated_at
    ) values (
      v_row_id, v_group_id, v_order, v_merged_values,
      v_merged_commercial_values, v_canonical_values,
      v_actor, clock_timestamp(), clock_timestamp()
    ) on conflict (id) do update set
      display_order = excluded.display_order,
      raw_values = excluded.raw_values,
      commercial_values = excluded.commercial_values,
      canonical_values = excluded.canonical_values,
      record_version = public.v1_boq_rows.record_version + 1,
      updated_at = clock_timestamp(),
      is_archived = false,
      archived_at = null,
      archived_by_auth_user_id = null
    where public.v1_boq_rows.group_id = v_group_id;
  end loop;

  update public.v1_boq_rows row_record
  set is_archived = true, archived_at = clock_timestamp(),
      archived_by_auth_user_id = v_actor, record_version = record_version + 1,
      updated_at = clock_timestamp()
  where row_record.group_id = v_group_id and row_record.is_archived
    and row_record.archived_at = v_snapshot_started
    and not exists (select 1 from jsonb_array_elements(v_rows) submitted
      where submitted ->> 'id' = row_record.id::text);

  update public.v1_boq_columns column_record
  set is_archived = true, archived_at = clock_timestamp(),
      archived_by_auth_user_id = v_actor, record_version = record_version + 1,
      updated_at = clock_timestamp()
  where column_record.group_id = v_group_id and column_record.is_archived
    and column_record.archived_at = v_snapshot_started
    and not column_record.is_commercial
    and not exists (select 1 from jsonb_array_elements(v_columns) submitted
      where submitted ->> 'id' = column_record.id::text);

  -- Commercial columns omitted from an operational import remain protected
  -- and are placed after the imported operational columns without overlap.
  with omitted_commercial as (
    select column_record.id,
      row_number() over (order by column_record.display_order, column_record.id) as position
    from public.v1_boq_columns column_record
    where column_record.group_id = v_group_id
      and not column_record.is_archived
      and column_record.is_commercial
      and not exists (select 1 from jsonb_array_elements(v_columns) submitted
        where submitted ->> 'id' = column_record.id::text)
  )
  update public.v1_boq_columns column_record
  set display_order = v_max_submitted_column_order + omitted_commercial.position,
      updated_at = clock_timestamp()
  from omitted_commercial
  where column_record.id = omitted_commercial.id;

  update public.v1_boq_groups
  set worksheet_title = v_title, record_version = record_version + 1,
      updated_at = clock_timestamp()
  where id = v_group_id;

  v_response := public.v1_get_boq_worksheet(v_group_id);
  perform public.v1_write_audit_event(
    'boq_worksheet_saved', 'boq_group', v_group_id, v_group.project_id,
    jsonb_build_object('record_version', v_expected_version),
    jsonb_build_object(
      'record_version', v_expected_version + 1,
      'column_count', jsonb_array_length(v_columns),
      'row_count', jsonb_array_length(v_rows),
      'archived_columns', v_archived_columns,
      'archived_rows', v_archived_rows
    ), v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency('v1_save_boq_worksheet', p_idempotency_key, v_response);
  return v_response;
end;
$$;

-- Replace the R38 fixed-count assertion with the current active frozen
-- template count. Scope triggers remain the single seeding authority.
do $create_project_guard$
declare
  v_definition text;
  v_old text := $old$
  if v_default_group_count <> (
    select count(*) * 29
    from public.v1_project_scopes scope_record
    where scope_record.project_id = v_project_id
      and scope_record.is_active
  ) then
$old$;
  v_new text := $new$
  if v_default_group_count <> (
    select count(*) * (
      select count(*) from public.v1_boq_group_templates template
      where template.is_frozen and template.is_active
    )
    from public.v1_project_scopes scope_record
    where scope_record.project_id = v_project_id
      and scope_record.is_active
  ) then
$new$;
begin
  v_definition := pg_get_functiondef('public.v1_create_project(jsonb,uuid)'::regprocedure);
  if position(v_old in v_definition) = 0 then
    if position('select count(*) from public.v1_boq_group_templates template' in v_definition) = 0 then
      raise exception 'V1_WORKSHOP_CREATE_PROJECT_TEMPLATE_GUARD_NOT_FOUND';
    end if;
  else
    execute replace(v_definition, v_old, v_new);
  end if;
end;
$create_project_guard$;

revoke all on function public.v1_boq_group_has_history(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_list_boq_groups_for_scope(uuid, uuid)
  from public, anon;
grant execute on function public.v1_list_boq_groups_for_scope(uuid, uuid)
  to authenticated;
revoke all on function public.v1_save_boq_worksheet(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_save_boq_worksheet(jsonb, uuid)
  to authenticated;

commit;
