-- Yorks V1 R35 security correction: Unit Cost and Total Cost are canonical
-- commercial meanings. A reviewed workbook may import them only through the
-- protected commercial column/value path, and only for an actor with the
-- server-controlled manage_commercials capability.
--
-- This migration is additive and data preserving. It losslessly reclassifies
-- only exact recognized legacy cost headings and moves their stable value keys
-- into protected storage; broader arbitrary technical columns are unchanged.
-- Import provenance, row IDs, column IDs, values and actor attribution remain
-- intact.

begin;

alter table public.v1_boq_columns
  drop constraint if exists v1_boq_columns_canonical_field_check;

alter table public.v1_boq_columns
  add constraint v1_boq_columns_canonical_field_check check (canonical_field in (
    'description', 'size', 'model', 'equipment_tag', 'brand_origin',
    'quantity', 'unit', 'unit_cost', 'total_cost', 'planning_model_tag'
  ));

alter table public.v1_boq_columns
  drop constraint if exists v1_boq_columns_commercial_canonical_check;

alter table public.v1_boq_columns
  add constraint v1_boq_columns_commercial_canonical_check check (
    canonical_field not in ('unit_cost', 'total_cost') or is_commercial
  );

-- Split a role-safe worksheet payload by the server-owned column
-- classification. Unknown column IDs, nested values and classification
-- guessing still fail before the worksheet can be mutated.
create or replace function public.v1_split_boq_values(
  p_values jsonb,
  p_group_id uuid
)
returns table (operational_values jsonb, commercial_values jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_value jsonb;
  v_is_commercial boolean;
begin
  if p_values is null or jsonb_typeof(p_values) <> 'object' then
    raise exception 'V1_BOQ_VALUES_MUST_BE_AN_OBJECT' using errcode = '22023';
  end if;

  operational_values := '{}'::jsonb;
  commercial_values := '{}'::jsonb;
  for v_key, v_value in select key, value from jsonb_each(p_values)
  loop
    if jsonb_typeof(v_value) not in ('string', 'number', 'boolean', 'null') then
      raise exception 'V1_BOQ_VALUES_MUST_BE_SCALARS' using errcode = '22023';
    end if;

    select column_record.is_commercial
      into v_is_commercial
    from public.v1_boq_columns column_record
    where column_record.id::text = v_key
      and column_record.group_id = p_group_id
      and not column_record.is_archived;
    if not found then
      raise exception 'V1_BOQ_VALUE_COLUMN_NOT_ALLOWED' using errcode = '22023';
    end if;

    if v_is_commercial then
      commercial_values := commercial_values || jsonb_build_object(v_key, v_value);
    else
      operational_values := operational_values || jsonb_build_object(v_key, v_value);
    end if;
  end loop;
  return next;
end;
$$;

revoke all on function public.v1_split_boq_values(jsonb, uuid)
  from public, anon, authenticated;

-- A client may omit or forge canonical_field. These exact controlled cost
-- headings and their approved commercial aliases therefore have a
-- server-owned meaning. Broader headings (for example "Operating Cost
-- Index") intentionally return null and remain arbitrary technical columns.
create or replace function public.v1_required_boq_commercial_canonical(
  p_heading text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case regexp_replace(
    lower(btrim(coalesce(p_heading, ''))), '[^a-z0-9]+', '', 'g'
  )
    when 'unitcost' then 'unit_cost'
    when 'unitprice' then 'unit_cost'
    when 'unitrate' then 'unit_cost'
    when 'totalcost' then 'total_cost'
    when 'totalprice' then 'total_cost'
    when 'totalamount' then 'total_cost'
    else null
  end;
$$;

revoke all on function public.v1_required_boq_commercial_canonical(text)
  from public, anon, authenticated;

-- Repair pre-migration imports that used an exact controlled cost heading but
-- stored the column and its values as operational. The repair fails before
-- writing if two headings would claim the same active canonical meaning or if
-- a row already carries different raw/commercial values for the same stable
-- column ID. No value is selected heuristically or overwritten.
create or replace function public.v1_reclassify_legacy_boq_commercial_columns()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_affected_group_ids uuid[] := '{}'::uuid[];
begin
  if exists (
    select 1
    from (
      select
        column_record.group_id,
        public.v1_required_boq_commercial_canonical(
          column_record.heading
        ) as required_canonical,
        count(*) as total
      from public.v1_boq_columns column_record
      where not column_record.is_archived
        and public.v1_required_boq_commercial_canonical(
          column_record.heading
        ) is not null
      group by
        column_record.group_id,
        public.v1_required_boq_commercial_canonical(column_record.heading)
    ) duplicate_target
    where duplicate_target.total > 1
  ) then
    raise exception 'V1_BOQ_COMMERCIAL_RECLASSIFICATION_DUPLICATE_TARGET'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.v1_boq_columns target_column
    join public.v1_boq_columns existing_canonical
      on existing_canonical.group_id = target_column.group_id
      and existing_canonical.id <> target_column.id
      and not existing_canonical.is_archived
      and existing_canonical.canonical_field =
        public.v1_required_boq_commercial_canonical(target_column.heading)
    where not target_column.is_archived
      and public.v1_required_boq_commercial_canonical(
        target_column.heading
      ) is not null
  ) then
    raise exception 'V1_BOQ_COMMERCIAL_RECLASSIFICATION_CANONICAL_CONFLICT'
      using errcode = '22023';
  end if;

  if exists (
    select 1
    from public.v1_boq_rows row_record
    join public.v1_boq_columns target_column
      on target_column.group_id = row_record.group_id
    where public.v1_required_boq_commercial_canonical(
        target_column.heading
      ) is not null
      and row_record.raw_values ? target_column.id::text
      and row_record.commercial_values ? target_column.id::text
      and row_record.raw_values -> target_column.id::text
        is distinct from
          row_record.commercial_values -> target_column.id::text
  ) then
    raise exception 'V1_BOQ_COMMERCIAL_RECLASSIFICATION_VALUE_CONFLICT'
      using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct column_record.group_id), '{}'::uuid[])
    into v_affected_group_ids
  from public.v1_boq_columns column_record
  where public.v1_required_boq_commercial_canonical(
      column_record.heading
    ) is not null
    and (
      not column_record.is_commercial
      or column_record.canonical_field is distinct from
        public.v1_required_boq_commercial_canonical(column_record.heading)
      or exists (
        select 1
        from public.v1_boq_rows row_record
        where row_record.group_id = column_record.group_id
          and row_record.raw_values ? column_record.id::text
      )
    );

  with target_columns as (
    select column_record.id, column_record.group_id
    from public.v1_boq_columns column_record
    where public.v1_required_boq_commercial_canonical(
      column_record.heading
    ) is not null
  ), moved_values as (
    select
      row_record.id as row_id,
      jsonb_object_agg(
        target_column.id::text,
        row_record.raw_values -> target_column.id::text
      ) as values_to_move,
      array_agg(target_column.id::text) as keys_to_remove
    from public.v1_boq_rows row_record
    join target_columns target_column
      on target_column.group_id = row_record.group_id
    where row_record.raw_values ? target_column.id::text
    group by row_record.id
  )
  update public.v1_boq_rows row_record
     set raw_values = row_record.raw_values - moved_values.keys_to_remove,
         commercial_values =
           row_record.commercial_values || moved_values.values_to_move,
         record_version = row_record.record_version + 1,
         updated_at = clock_timestamp()
    from moved_values
   where row_record.id = moved_values.row_id;

  update public.v1_boq_columns column_record
     set canonical_field =
           public.v1_required_boq_commercial_canonical(column_record.heading),
         is_commercial = true,
         record_version = column_record.record_version + 1,
         updated_at = clock_timestamp()
   where public.v1_required_boq_commercial_canonical(
       column_record.heading
     ) is not null
     and (
       not column_record.is_commercial
       or column_record.canonical_field is distinct from
         public.v1_required_boq_commercial_canonical(column_record.heading)
     );

  update public.v1_boq_groups group_record
     set record_version = group_record.record_version + 1,
         updated_at = clock_timestamp()
   where group_record.id = any(v_affected_group_ids);

  return cardinality(v_affected_group_ids);
end;
$$;

revoke all on function public.v1_reclassify_legacy_boq_commercial_columns()
  from public, anon, authenticated;

select public.v1_reclassify_legacy_boq_commercial_columns();

-- Preserve the currently installed save command (including the R38 scope
-- guard) and replace only its canonical classification and row-storage seam.
do $save_patch$
declare
  v_definition text;
  v_old_allow_list text :=
    '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
  v_new_allow_list text :=
    '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''unit_cost'', ''total_cost'', ''planning_model_tag''';
  v_old_declarations text := $old$
  v_submitted_values jsonb;
  v_clean_values jsonb;
  v_merged_values jsonb;
  v_canonical_values jsonb;
$old$;
  v_new_declarations text := $new$
  v_submitted_values jsonb;
  v_clean_operational_values jsonb;
  v_clean_commercial_values jsonb;
  v_merged_values jsonb;
  v_merged_commercial_values jsonb;
  v_canonical_values jsonb;
$new$;
  v_old_classification text := $old$
    if v_is_commercial and not public.v1_has_capability('manage_commercials') then
$old$;
  v_new_classification text := $new$
    if public.v1_required_boq_commercial_canonical(v_heading) is not null
      and (
        v_canonical is distinct from
          public.v1_required_boq_commercial_canonical(v_heading)
        or not v_is_commercial
      )
      and (
        not v_is_commercial
        or public.v1_has_capability('manage_commercials')
      ) then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if v_canonical in ('unit_cost', 'total_cost') and not v_is_commercial then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if v_is_commercial and not public.v1_has_capability('manage_commercials') then
$new$;
  v_old_row_split text := $old$
    v_clean_values := public.v1_validate_boq_values(
      v_submitted_values, v_group_id, false
    );
    select * into v_existing_row from public.v1_boq_rows row_record
    where row_record.id = v_row_id and row_record.group_id = v_group_id;
    v_merged_values := coalesce(v_existing_row.raw_values, '{}'::jsonb) || v_clean_values;
$old$;
  v_new_row_split text := $new$
    select split.operational_values, split.commercial_values
      into v_clean_operational_values, v_clean_commercial_values
    from public.v1_split_boq_values(v_submitted_values, v_group_id) split;
    if v_clean_commercial_values <> '{}'::jsonb
      and not public.v1_has_capability('manage_commercials') then
      raise exception 'V1_BOQ_COMMERCIAL_VALUE_DENIED' using errcode = '42501';
    end if;
    select * into v_existing_row from public.v1_boq_rows row_record
    where row_record.id = v_row_id and row_record.group_id = v_group_id;
    v_merged_values := coalesce(v_existing_row.raw_values, '{}'::jsonb)
      || v_clean_operational_values;
    v_merged_commercial_values :=
      coalesce(v_existing_row.commercial_values, '{}'::jsonb)
      || v_clean_commercial_values;
$new$;
  v_old_row_write text := $old$
    insert into public.v1_boq_rows (
      id, group_id, display_order, raw_values, canonical_values,
      created_by_auth_user_id, created_at, updated_at
    ) values (
      v_row_id, v_group_id, v_order, v_merged_values, v_canonical_values,
      v_actor, clock_timestamp(), clock_timestamp()
    ) on conflict (id) do update set
      display_order = excluded.display_order,
      raw_values = excluded.raw_values,
      canonical_values = excluded.canonical_values,
$old$;
  v_new_row_write text := $new$
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
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_boq_worksheet(jsonb,uuid)'::regprocedure
  );
  if position(v_new_allow_list in v_definition) > 0
    and position(v_new_declarations in v_definition) > 0
    and position(v_new_classification in v_definition) > 0
    and position(v_new_row_split in v_definition) > 0
    and position(v_new_row_write in v_definition) > 0 then
    return;
  end if;
  if position(v_old_allow_list in v_definition) = 0
    or position(v_old_declarations in v_definition) = 0
    or position(v_old_classification in v_definition) = 0
    or position(v_old_row_split in v_definition) = 0
    or position(v_old_row_write in v_definition) = 0 then
    raise exception 'V1_BOQ_COMMERCIAL_SAVE_PATCH_TARGET_UNKNOWN';
  end if;
  v_definition := replace(v_definition, v_old_allow_list, v_new_allow_list);
  v_definition := replace(v_definition, v_old_declarations, v_new_declarations);
  v_definition := replace(v_definition, v_old_classification, v_new_classification);
  v_definition := replace(v_definition, v_old_row_split, v_new_row_split);
  v_definition := replace(v_definition, v_old_row_write, v_new_row_write);
  execute v_definition;
end;
$save_patch$;

-- The import command remains the single reviewed, version-checked mutation
-- boundary. It may now forward commercial columns only for an authorized
-- actor; canonical costs marked operational are rejected before any write.
do $import_patch$
declare
  v_definition text;
  v_old_allow_list text :=
    '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
  v_new_allow_list text :=
    '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''unit_cost'', ''total_cost'', ''planning_model_tag''';
  v_old_validation text := $old$
    if v_heading is null or coalesce((v_column ->> 'is_commercial')::boolean, false) then
      raise exception 'V1_BOQ_IMPORT_COLUMN_INVALID' using errcode = '22023';
    end if;
$old$;
  -- pg_get_functiondef preserves the compact form installed by an earlier
  -- production migration. Match that exact, semantically identical body as a
  -- second fail-closed target instead of weakening this patch to a broad
  -- regular expression.
  v_old_validation_compact text := $old$
    if v_heading is null or coalesce((v_column ->> 'is_commercial')::boolean, false) then raise exception 'V1_BOQ_IMPORT_COLUMN_INVALID' using errcode = '22023'; end if;
$old$;
  v_validation_target text;
  v_new_validation text := $new$
    if v_heading is null then
      raise exception 'V1_BOQ_IMPORT_COLUMN_INVALID' using errcode = '22023';
    end if;
    if public.v1_required_boq_commercial_canonical(v_heading) is not null
      and (
        v_canonical is distinct from
          public.v1_required_boq_commercial_canonical(v_heading)
        or not coalesce((v_column ->> 'is_commercial')::boolean, false)
      )
      and (
        not coalesce((v_column ->> 'is_commercial')::boolean, false)
        or public.v1_has_capability('manage_commercials')
      ) then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if v_canonical in ('unit_cost', 'total_cost')
      and not coalesce((v_column ->> 'is_commercial')::boolean, false) then
      raise exception 'V1_BOQ_COMMERCIAL_CANONICAL_REQUIRES_CLASSIFICATION'
        using errcode = '22023';
    end if;
    if coalesce((v_column ->> 'is_commercial')::boolean, false)
      and not public.v1_has_capability('manage_commercials') then
      raise exception 'V1_BOQ_COMMERCIAL_IMPORT_DENIED' using errcode = '42501';
    end if;
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_import_boq_worksheet(jsonb,uuid)'::regprocedure
  );
  if position(v_new_allow_list in v_definition) > 0
    and position(v_new_validation in v_definition) > 0 then
    return;
  end if;
  if position(v_old_allow_list in v_definition) = 0 then
    raise exception 'V1_BOQ_COMMERCIAL_IMPORT_PATCH_TARGET_UNKNOWN';
  end if;
  if position(v_old_validation in v_definition) > 0 then
    v_validation_target := v_old_validation;
  elsif position(v_old_validation_compact in v_definition) > 0 then
    v_validation_target := v_old_validation_compact;
  else
    raise exception 'V1_BOQ_COMMERCIAL_IMPORT_PATCH_TARGET_UNKNOWN';
  end if;
  v_definition := replace(v_definition, v_old_allow_list, v_new_allow_list);
  v_definition := replace(v_definition, v_validation_target, v_new_validation);
  execute v_definition;
end;
$import_patch$;

-- Reassert the existing public boundary after replacing the definitions.
revoke all on function public.v1_save_boq_worksheet(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_save_boq_worksheet(jsonb, uuid)
  to authenticated;
revoke all on function public.v1_import_boq_worksheet(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_import_boq_worksheet(jsonb, uuid)
  to authenticated;

commit;
