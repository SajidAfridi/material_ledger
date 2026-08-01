-- Yorks V1 Batch 4: versioned XLSX BOQ import provenance. Workbook bytes are
-- intentionally parsed in the client preview and are never stored in a public
-- table; the trusted command stores only reviewed normalized rows and a small
-- auditable source descriptor.

alter table public.v1_boq_groups
  add column if not exists last_imported_at timestamptz,
  add column if not exists last_imported_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  add column if not exists last_import_source jsonb;

alter table public.v1_boq_groups
  drop constraint if exists v1_boq_groups_last_import_source_check;
alter table public.v1_boq_groups
  add constraint v1_boq_groups_last_import_source_check check (
    last_import_source is null
    or jsonb_typeof(last_import_source) = 'object'
  );

create or replace function public.v1_import_boq_worksheet(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group_id uuid;
  v_expected_version integer;
  v_title text;
  v_columns jsonb;
  v_rows jsonb;
  v_source jsonb;
  v_file_name text;
  v_sheet_name text;
  v_header_row_number integer;
  v_group public.v1_boq_groups%rowtype;
  v_existing_response jsonb;
  v_save_response jsonb;
  v_before jsonb;
  v_source_projection jsonb;
  v_column jsonb;
  v_heading text;
  v_canonical text;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'group_id', 'expected_version', 'worksheet_title', 'columns', 'rows',
      'source'
    ],
    'boq_workbook_import'
  );
  v_group_id := nullif(btrim(coalesce(p_payload ->> 'group_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  v_title := nullif(btrim(coalesce(p_payload ->> 'worksheet_title', '')), '');
  v_columns := coalesce(p_payload -> 'columns', '[]'::jsonb);
  v_rows := coalesce(p_payload -> 'rows', '[]'::jsonb);
  v_source := p_payload -> 'source';
  if v_group_id is null or v_expected_version is null or v_expected_version < 1
    or v_title is null or jsonb_typeof(v_columns) <> 'array'
    or jsonb_typeof(v_rows) <> 'array' or jsonb_typeof(v_source) <> 'object' then
    raise exception 'V1_BOQ_IMPORT_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  perform public.v1_assert_object_keys(
    v_source, array['file_name', 'worksheet_name', 'header_row_number'],
    'boq_workbook_import_source'
  );
  v_file_name := nullif(btrim(coalesce(v_source ->> 'file_name', '')), '');
  v_sheet_name := nullif(btrim(coalesce(v_source ->> 'worksheet_name', '')), '');
  v_header_row_number := nullif(v_source ->> 'header_row_number', '')::integer;
  if v_file_name is null or char_length(v_file_name) > 255
    or v_sheet_name is null or char_length(v_sheet_name) > 128
    or v_header_row_number is null or v_header_row_number < 1 then
    raise exception 'V1_BOQ_IMPORT_SOURCE_INVALID' using errcode = '22023';
  end if;

  select * into v_group from public.v1_boq_groups group_record
  where group_record.id = v_group_id for update;
  if not found or not public.v1_can_edit_boq_project(v_group.project_id) then
    raise exception 'V1_BOQ_IMPORT_DENIED' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_import_boq_worksheet', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  if v_group.is_archived
    or (select state from public.v1_projects where id = v_group.project_id)
      not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;
  if exists (
    select 1 from public.v1_boq_columns column_record
    where column_record.group_id = v_group_id
      and not column_record.is_archived
      and column_record.is_commercial
  ) and not public.v1_has_capability('manage_commercials') then
    raise exception 'V1_BOQ_COMMERCIAL_IMPORT_DENIED' using errcode = '42501';
  end if;

  -- Validate the reviewed mapping before entering the shared worksheet-save
  -- path. This gives malformed import an all-or-nothing failure and prevents
  -- a second canonical meaning from being inferred for one worksheet.
  for v_column in select value from jsonb_array_elements(v_columns)
  loop
    perform public.v1_assert_object_keys(
      v_column,
      array['id', 'heading', 'display_order', 'canonical_field', 'is_commercial'],
      'boq_import_column'
    );
    v_heading := nullif(btrim(coalesce(v_column ->> 'heading', '')), '');
    v_canonical := nullif(btrim(coalesce(v_column ->> 'canonical_field', '')), '');
    if v_heading is null or coalesce((v_column ->> 'is_commercial')::boolean, false) then
      raise exception 'V1_BOQ_IMPORT_COLUMN_INVALID' using errcode = '22023';
    end if;
    if v_canonical is not null and v_canonical not in (
      'description', 'brand_origin', 'quantity', 'unit', 'planning_model_tag'
    ) then
      raise exception 'V1_BOQ_IMPORT_COLUMN_INVALID' using errcode = '22023';
    end if;
  end loop;
  if exists (
    select 1
    from (
      select lower(btrim(value ->> 'heading')) as heading, count(*) as total
      from jsonb_array_elements(v_columns)
      group by lower(btrim(value ->> 'heading'))
    ) duplicate_heading
    where duplicate_heading.total > 1
  ) or exists (
    select 1
    from (
      select nullif(value ->> 'canonical_field', '') as canonical_field,
        count(*) as total
      from jsonb_array_elements(v_columns)
      where nullif(value ->> 'canonical_field', '') is not null
      group by nullif(value ->> 'canonical_field', '')
    ) duplicate_canonical
    where duplicate_canonical.total > 1
  ) then
    raise exception 'V1_BOQ_IMPORT_COLUMN_MAPPING_DUPLICATE' using errcode = '22023';
  end if;

  v_before := public.v1_boq_group_projection(v_group_id);
  v_save_response := public.v1_save_boq_worksheet(
    jsonb_build_object(
      'group_id', v_group_id,
      'expected_version', v_expected_version,
      'worksheet_title', v_title,
      'columns', v_columns,
      'rows', v_rows,
      'reason', 'Reviewed XLSX workbook import'
    ),
    gen_random_uuid()
  );
  v_source_projection := jsonb_build_object(
    'file_name', v_file_name,
    'worksheet_name', v_sheet_name,
    'header_row_number', v_header_row_number
  );
  update public.v1_boq_groups
     set last_imported_at = clock_timestamp(),
         last_imported_by_auth_user_id = auth.uid(),
         last_import_source = v_source_projection,
         updated_at = clock_timestamp()
   where id = v_group_id;
  perform public.v1_write_audit_event(
    'boq_import_committed', 'boq_group', v_group_id, v_group.project_id,
    v_before,
    jsonb_build_object(
      'source', v_source_projection,
      'record_version', v_expected_version + 1,
      'column_count', jsonb_array_length(v_columns),
      'row_count', jsonb_array_length(v_rows)
    ),
    'Reviewed XLSX workbook import', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_import_boq_worksheet', p_idempotency_key, v_save_response
  );
  return v_save_response;
end;
$$;

revoke all on function public.v1_import_boq_worksheet(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_import_boq_worksheet(jsonb, uuid)
  to authenticated;
