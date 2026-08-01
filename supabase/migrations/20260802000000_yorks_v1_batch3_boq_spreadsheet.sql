-- Yorks V1 Batch 3: ordered, versioned BOQ worksheets.  This migration is
-- additive: Batch 2's 29 project groups remain intact and historical values
-- are archived rather than deleted.

alter table public.v1_boq_groups
  add column if not exists worksheet_title text,
  add column if not exists is_archived boolean not null default false,
  add column if not exists archived_at timestamptz,
  add column if not exists archived_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict;

update public.v1_boq_groups
set worksheet_title = name
where worksheet_title is null or btrim(worksheet_title) = '';

alter table public.v1_boq_groups
  alter column worksheet_title set not null;

-- Batch 2's project-creation RPC intentionally owns the frozen group insert.
-- Keep it forward-compatible without rewriting that historical command: the
-- trigger derives the editable worksheet title from the approved group name
-- whenever an older caller does not yet pass the new column.
create or replace function public.v1_boq_default_worksheet_title()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.worksheet_title := coalesce(
    nullif(btrim(coalesce(new.worksheet_title, '')), ''),
    new.name
  );
  return new;
end;
$$;

drop trigger if exists v1_boq_default_worksheet_title on public.v1_boq_groups;
create trigger v1_boq_default_worksheet_title
before insert or update of name, worksheet_title on public.v1_boq_groups
for each row execute function public.v1_boq_default_worksheet_title();

alter table public.v1_boq_groups
  drop constraint if exists v1_boq_groups_archive_metadata_check;
alter table public.v1_boq_groups
  add constraint v1_boq_groups_archive_metadata_check check (
    (not is_archived and archived_at is null and archived_by_auth_user_id is null)
    or (is_archived and archived_at is not null and archived_by_auth_user_id is not null)
  );

create table if not exists public.v1_boq_columns (
  id uuid primary key,
  group_id uuid not null references public.v1_boq_groups (id) on delete restrict,
  heading text not null check (btrim(heading) <> ''),
  display_order integer not null check (display_order > 0),
  canonical_field text check (canonical_field in (
    'description', 'brand_origin', 'quantity', 'unit', 'planning_model_tag'
  )),
  is_commercial boolean not null default false,
  is_archived boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  unique (group_id, display_order),
  check (
    (not is_archived and archived_at is null and archived_by_auth_user_id is null)
    or (is_archived and archived_at is not null and archived_by_auth_user_id is not null)
  )
);

create unique index if not exists v1_boq_columns_active_heading_unique_idx
  on public.v1_boq_columns (group_id, lower(heading))
  where not is_archived;

create unique index if not exists v1_boq_columns_active_canonical_unique_idx
  on public.v1_boq_columns (group_id, canonical_field)
  where not is_archived and canonical_field is not null;

create table if not exists public.v1_boq_rows (
  id uuid primary key,
  group_id uuid not null references public.v1_boq_groups (id) on delete restrict,
  display_order integer not null check (display_order > 0),
  raw_values jsonb not null default '{}'::jsonb
    check (jsonb_typeof(raw_values) = 'object'),
  commercial_values jsonb not null default '{}'::jsonb
    check (jsonb_typeof(commercial_values) = 'object'),
  canonical_values jsonb not null default '{}'::jsonb
    check (jsonb_typeof(canonical_values) = 'object'),
  is_archived boolean not null default false,
  record_version integer not null default 1 check (record_version > 0),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  unique (group_id, display_order),
  check (
    (not is_archived and archived_at is null and archived_by_auth_user_id is null)
    or (is_archived and archived_at is not null and archived_by_auth_user_id is not null)
  )
);

create index if not exists v1_boq_rows_active_group_order_idx
  on public.v1_boq_rows (group_id, display_order)
  where not is_archived;

-- Backfill any dormant normalized project that predates the Batch 2 create
-- command.  Existing default rows satisfy the conflict target and are left
-- untouched, so the frozen template materialises exactly once per project.
insert into public.v1_boq_groups (
  project_id,
  template_id,
  name,
  worksheet_title,
  display_order,
  is_custom,
  created_by_auth_user_id,
  created_at,
  updated_at
)
select
  project.id,
  template.id,
  template.display_name,
  template.display_name,
  template.display_order,
  false,
  project.created_by_auth_user_id,
  clock_timestamp(),
  clock_timestamp()
from public.v1_projects project
join public.v1_boq_group_templates template
  on template.is_frozen and template.is_active
on conflict (project_id, template_id) do nothing;

alter table public.v1_boq_columns enable row level security;
alter table public.v1_boq_rows enable row level security;

revoke all on table public.v1_boq_columns from public, anon, authenticated;
revoke all on table public.v1_boq_rows from public, anon, authenticated;
grant all on table public.v1_boq_columns to service_role;
grant all on table public.v1_boq_rows to service_role;

create or replace function public.v1_can_edit_boq_project(p_project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
begin
  if v_actor is null
    or v_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_role = 'admin' then
    return true;
  end if;
  return v_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(p_project_id, v_actor, null);
end;
$$;

create or replace function public.v1_boq_group_projection(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', group_record.id,
    'project_id', group_record.project_id,
    'name', group_record.name,
    'worksheet_title', group_record.worksheet_title,
    'display_order', group_record.display_order,
    'is_custom', group_record.is_custom,
    'is_archived', group_record.is_archived,
    'record_version', group_record.record_version,
    'row_count', (
      select count(*) from public.v1_boq_rows row_record
      where row_record.group_id = group_record.id and not row_record.is_archived
    ),
    'column_count', (
      select count(*) from public.v1_boq_columns column_record
      where column_record.group_id = group_record.id
        and not column_record.is_archived
    ),
    'updated_at', group_record.updated_at
  )
  from public.v1_boq_groups group_record
  where group_record.id = p_group_id;
$$;

create or replace function public.v1_list_boq_groups(p_project_id uuid)
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
  return coalesce((
    select jsonb_agg(public.v1_boq_group_projection(group_record.id)
      order by group_record.display_order)
    from public.v1_boq_groups group_record
    where group_record.project_id = p_project_id
      and not group_record.is_archived
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_get_boq_worksheet(p_group_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_group public.v1_boq_groups%rowtype;
  v_can_view_commercial boolean := public.v1_has_capability('view_commercials');
begin
  select * into v_group
  from public.v1_boq_groups group_record
  where group_record.id = p_group_id;
  if not found or not public.v1_project_readable(v_group.project_id) then
    raise exception 'V1_BOQ_GROUP_NOT_READABLE' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'group', public.v1_boq_group_projection(v_group.id),
    'columns', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', column_record.id,
        'heading', column_record.heading,
        'display_order', column_record.display_order,
        'canonical_field', column_record.canonical_field,
        'is_commercial', column_record.is_commercial,
        'record_version', column_record.record_version
      ) order by column_record.display_order)
      from public.v1_boq_columns column_record
      where column_record.group_id = v_group.id
        and not column_record.is_archived
        and (not column_record.is_commercial or v_can_view_commercial)
    ), '[]'::jsonb),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', row_record.id,
        'display_order', row_record.display_order,
        'raw_values', case when v_can_view_commercial
          then row_record.raw_values || row_record.commercial_values
          else row_record.raw_values
        end,
        'canonical_values', row_record.canonical_values,
        'record_version', row_record.record_version
      ) order by row_record.display_order)
      from public.v1_boq_rows row_record
      where row_record.group_id = v_group.id and not row_record.is_archived
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.v1_validate_boq_values(
  p_values jsonb,
  p_group_id uuid,
  p_commercial boolean
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_value jsonb;
begin
  if p_values is null or jsonb_typeof(p_values) <> 'object' then
    raise exception 'V1_BOQ_VALUES_MUST_BE_AN_OBJECT' using errcode = '22023';
  end if;
  for v_key, v_value in select key, value from jsonb_each(p_values)
  loop
    if jsonb_typeof(v_value) not in ('string', 'number', 'boolean', 'null') then
      raise exception 'V1_BOQ_VALUES_MUST_BE_SCALARS' using errcode = '22023';
    end if;
    if not exists (
      select 1 from public.v1_boq_columns column_record
      where column_record.id::text = v_key
        and column_record.group_id = p_group_id
        and not column_record.is_archived
        and column_record.is_commercial = p_commercial
    ) then
      raise exception 'V1_BOQ_VALUE_COLUMN_NOT_ALLOWED' using errcode = '22023';
    end if;
  end loop;
  return p_values;
end;
$$;

create or replace function public.v1_create_boq_group(
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
  v_project_id uuid;
  v_name text;
  v_existing_response jsonb;
  v_group public.v1_boq_groups%rowtype;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array['project_id', 'name'], 'boq_group');
  v_project_id := nullif(btrim(coalesce(p_payload ->> 'project_id', '')), '')::uuid;
  v_name := nullif(btrim(coalesce(p_payload ->> 'name', '')), '');
  if v_project_id is null or v_name is null then
    raise exception 'V1_BOQ_GROUP_PROJECT_AND_NAME_REQUIRED' using errcode = '22023';
  end if;
  if not public.v1_can_edit_boq_project(v_project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;
  if (select state from public.v1_projects where id = v_project_id)
      not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;

  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_create_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;

  perform 1 from public.v1_projects project where project.id = v_project_id for update;
  insert into public.v1_boq_groups (
    project_id, name, worksheet_title, display_order, is_custom,
    created_by_auth_user_id, created_at, updated_at
  )
  values (
    v_project_id, v_name, v_name,
    coalesce((select max(display_order) + 1 from public.v1_boq_groups
      where project_id = v_project_id), 1),
    true, v_actor, clock_timestamp(), clock_timestamp()
  )
  returning * into v_group;
  v_response := public.v1_boq_group_projection(v_group.id);
  perform public.v1_write_audit_event(
    'boq_group_created', 'boq_group', v_group.id, v_project_id,
    null, v_response, 'Custom BOQ group created', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

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
  v_clean_values jsonb;
  v_merged_values jsonb;
  v_canonical_values jsonb;
  v_archived_columns integer := 0;
  v_archived_rows integer := 0;
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

  select * into v_group from public.v1_boq_groups group_record
  where group_record.id = v_group_id for update;
  if not found or not public.v1_can_edit_boq_project(v_group.project_id) then
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

  -- Capture which active columns/rows the client intentionally omitted. They
  -- are archived below; neither their records nor their raw values disappear.
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
    if v_column_id is null or v_heading is null or v_order is null or v_order < 1
      or (v_canonical is not null and v_canonical not in (
        'description', 'brand_origin', 'quantity', 'unit', 'planning_model_tag'
      )) then
      raise exception 'V1_BOQ_COLUMN_INVALID' using errcode = '22023';
    end if;
    if v_is_commercial and not public.v1_has_capability('manage_commercials') then
      raise exception 'V1_BOQ_COMMERCIAL_COLUMN_DENIED' using errcode = '42501';
    end if;
    if exists (
      select 1 from public.v1_boq_columns column_record
      where column_record.group_id = v_group_id and column_record.id = v_column_id
        and column_record.is_commercial <> v_is_commercial
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
  end loop;

  for v_row in select value from jsonb_array_elements(v_rows)
  loop
    perform public.v1_assert_object_keys(
      v_row, array['id', 'display_order', 'raw_values'], 'boq_row'
    );
    v_row_id := nullif(btrim(coalesce(v_row ->> 'id', '')), '')::uuid;
    v_order := nullif(v_row ->> 'display_order', '')::integer;
    v_submitted_values := coalesce(v_row -> 'raw_values', '{}'::jsonb);
    if v_row_id is null or v_order is null or v_order < 1 then
      raise exception 'V1_BOQ_ROW_INVALID' using errcode = '22023';
    end if;
    v_clean_values := public.v1_validate_boq_values(
      v_submitted_values, v_group_id, false
    );
    select * into v_existing_row from public.v1_boq_rows row_record
    where row_record.id = v_row_id and row_record.group_id = v_group_id;
    v_merged_values := coalesce(v_existing_row.raw_values, '{}'::jsonb) || v_clean_values;
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
      id, group_id, display_order, raw_values, canonical_values,
      created_by_auth_user_id, created_at, updated_at
    ) values (
      v_row_id, v_group_id, v_order, v_merged_values, v_canonical_values,
      v_actor, clock_timestamp(), clock_timestamp()
    ) on conflict (id) do update set
      display_order = excluded.display_order,
      raw_values = excluded.raw_values,
      canonical_values = excluded.canonical_values,
      record_version = public.v1_boq_rows.record_version + 1,
      updated_at = clock_timestamp(),
      is_archived = false,
      archived_at = null,
      archived_by_auth_user_id = null
    where public.v1_boq_rows.group_id = v_group_id;
  end loop;

  update public.v1_boq_rows row_record
     set is_archived = true,
         archived_at = clock_timestamp(),
         archived_by_auth_user_id = v_actor,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where row_record.group_id = v_group_id
     and not row_record.is_archived
     and not exists (
       select 1 from jsonb_array_elements(v_rows) submitted
       where submitted ->> 'id' = row_record.id::text
     );
  get diagnostics v_archived_rows = row_count;

  -- Archive omitted columns only after existing rows have been validated and
  -- merged. This accepts a last editable snapshot that still carries the old
  -- values while retaining those values as history after the heading is gone.
  update public.v1_boq_columns column_record
     set is_archived = true,
         archived_at = clock_timestamp(),
         archived_by_auth_user_id = v_actor,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where column_record.group_id = v_group_id
     and not column_record.is_archived
     -- Commercial definitions are not part of an ordinary operational
     -- worksheet snapshot. They remain protected until a dedicated commercial
     -- command can make an audited change.
     and not column_record.is_commercial
     and not exists (
       select 1 from jsonb_array_elements(v_columns) submitted
       where submitted ->> 'id' = column_record.id::text
     );
  get diagnostics v_archived_columns = row_count;

  update public.v1_boq_groups
     set worksheet_title = v_title,
         record_version = record_version + 1,
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
    ),
    v_reason, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_save_boq_worksheet', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_archive_boq_group(
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
  v_group public.v1_boq_groups%rowtype;
  v_project_state text;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['group_id', 'expected_version'], 'archive_boq_group'
  );
  v_group_id := nullif(btrim(coalesce(p_payload ->> 'group_id', '')), '')::uuid;
  v_expected_version := nullif(p_payload ->> 'expected_version', '')::integer;
  if v_group_id is null or v_expected_version is null then
    raise exception 'V1_BOQ_ARCHIVE_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_group from public.v1_boq_groups group_record
  where group_record.id = v_group_id for update;
  if not found or not public.v1_can_edit_boq_project(v_group.project_id) then
    raise exception 'V1_BOQ_EDIT_DENIED' using errcode = '42501';
  end if;
  select state into v_project_state from public.v1_projects
  where id = v_group.project_id;
  if v_group.is_archived or v_project_state not in ('draft', 'active') then
    raise exception 'V1_BOQ_PROJECT_NOT_EDITABLE' using errcode = '42501';
  end if;
  if not v_group.is_custom then
    raise exception 'V1_DEFAULT_BOQ_GROUP_CANNOT_BE_ARCHIVED' using errcode = '22023';
  end if;
  if v_group.record_version <> v_expected_version then
    raise exception 'V1_BOQ_VERSION_CONFLICT' using errcode = '40001';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_archive_boq_group', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  v_before := public.v1_boq_group_projection(v_group_id);
  update public.v1_boq_groups
     set is_archived = true,
         archived_at = clock_timestamp(),
         archived_by_auth_user_id = auth.uid(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_group_id;
  v_response := jsonb_build_object('group_id', v_group_id, 'archived', true);
  perform public.v1_write_audit_event(
    'boq_group_archived', 'boq_group', v_group_id, v_group.project_id,
    v_before, v_response,
    'Custom BOQ group archived', p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_archive_boq_group', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_can_edit_boq_project(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_boq_default_worksheet_title()
  from public, anon, authenticated;
revoke all on function public.v1_boq_group_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_validate_boq_values(jsonb, uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.v1_list_boq_groups(uuid)
  from public, anon;
revoke all on function public.v1_get_boq_worksheet(uuid)
  from public, anon;
revoke all on function public.v1_create_boq_group(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_save_boq_worksheet(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_archive_boq_group(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_list_boq_groups(uuid) to authenticated;
grant execute on function public.v1_get_boq_worksheet(uuid) to authenticated;
grant execute on function public.v1_create_boq_group(jsonb, uuid) to authenticated;
grant execute on function public.v1_save_boq_worksheet(jsonb, uuid) to authenticated;
grant execute on function public.v1_archive_boq_group(jsonb, uuid) to authenticated;
