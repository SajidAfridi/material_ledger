-- Yorks R38 Configuration Centre.
--
-- Data preservation: this migration adds a normalized, Admin-only
-- configuration publication boundary. Existing workflow, stock, request,
-- document, rental and legacy material-master rows are not rewritten. Draft
-- values are inert until v1_publish_configuration commits them. Category and
-- unit retirement is an archive operation; historical references are retained.
--
-- Rollback: revoke the RPC grants and redeploy the prior client. Keep every
-- publication, publication change, draft and master-data row. Never drop a
-- publication that has been used to create a controlled record. A published
-- error is corrected by a later publication, not by rewriting history.

begin;

create table if not exists public.v1_configuration_settings (
  setting_key text primary key check (
    setting_key ~ '^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$'
  ),
  area text not null check (area in (
    'company_regional', 'projects_teams', 'boq_materials',
    'material_requests', 'procurement_inventory', 'accounts',
    'documents_printing', 'notifications', 'security_audit',
    'numbering_data'
  )),
  value_type text not null check (value_type in (
    'string', 'boolean', 'integer', 'string_array', 'weights'
  )),
  default_value jsonb not null,
  published_value jsonb not null,
  display_order integer not null check (display_order > 0),
  updated_at timestamptz not null default clock_timestamp(),
  constraint v1_configuration_settings_default_type_check check (
    (value_type = 'string' and jsonb_typeof(default_value) = 'string')
    or (value_type = 'boolean' and jsonb_typeof(default_value) = 'boolean')
    or (value_type = 'integer' and jsonb_typeof(default_value) = 'number')
    or (value_type = 'string_array' and jsonb_typeof(default_value) = 'array')
    or (value_type = 'weights' and jsonb_typeof(default_value) = 'object')
  ),
  constraint v1_configuration_settings_published_type_check check (
    (value_type = 'string' and jsonb_typeof(published_value) = 'string')
    or (value_type = 'boolean' and jsonb_typeof(published_value) = 'boolean')
    or (value_type = 'integer' and jsonb_typeof(published_value) = 'number')
    or (value_type = 'string_array' and jsonb_typeof(published_value) = 'array')
    or (value_type = 'weights' and jsonb_typeof(published_value) = 'object')
  )
);

create table if not exists public.v1_configuration_draft_state (
  singleton boolean primary key default true check (singleton),
  base_version integer not null default 1 check (base_version > 0),
  draft_revision integer not null default 0 check (draft_revision >= 0),
  updated_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  updated_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_configuration_draft_changes (
  setting_key text primary key references public.v1_configuration_settings
    (setting_key) on delete restrict,
  proposed_value jsonb not null,
  staged_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  staged_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_configuration_master_actions (
  id uuid primary key,
  entity_kind text not null check (entity_kind in (
    'material_category', 'material_unit'
  )),
  action_kind text not null check (action_kind in ('create', 'archive')),
  target_id uuid not null,
  payload jsonb not null default '{}'::jsonb check (
    jsonb_typeof(payload) = 'object'
  ),
  reason text,
  staged_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  staged_at timestamptz not null default clock_timestamp(),
  unique (entity_kind, action_kind, target_id),
  check (
    (action_kind = 'create' and reason is null)
    or (action_kind = 'archive' and btrim(coalesce(reason, '')) <> '')
  )
);

create table if not exists public.v1_configuration_units (
  id uuid primary key,
  name text not null check (btrim(name) <> '' and length(name) <= 80),
  short_code text not null check (
    btrim(short_code) <> '' and length(short_code) <= 20
  ),
  unit_type text not null check (unit_type in (
    'count', 'length', 'area', 'volume', 'weight', 'other'
  )),
  decimal_places integer not null default 0 check (
    decimal_places between 0 and 4
  ),
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);

create unique index if not exists v1_configuration_units_code_active_idx
  on public.v1_configuration_units (lower(btrim(short_code)))
  where is_active;
create index if not exists v1_configuration_units_active_name_idx
  on public.v1_configuration_units (is_active, name);

create table if not exists public.v1_configuration_publications (
  id uuid primary key default gen_random_uuid(),
  version_number integer not null unique check (version_number > 0),
  version_label text not null unique check (
    version_label ~ '^v[0-9]+\.[0-9]+\.[0-9]+$'
  ),
  reason text not null check (
    btrim(reason) <> '' and length(reason) between 8 and 500
  ),
  affected_areas text[] not null check (cardinality(affected_areas) > 0),
  published_by_auth_user_id uuid references public.v1_profiles (auth_user_id)
    on delete restrict,
  published_by_exact_role text not null check (
    published_by_exact_role in ('admin', 'system')
  ),
  published_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid,
  unique nulls not distinct (published_by_auth_user_id, idempotency_key)
);

create index if not exists v1_configuration_publications_time_idx
  on public.v1_configuration_publications (published_at desc, id desc);

create table if not exists public.v1_configuration_publication_changes (
  publication_id uuid not null references public.v1_configuration_publications
    (id) on delete restrict,
  setting_key text not null,
  area text not null,
  before_value jsonb,
  after_value jsonb,
  change_kind text not null check (change_kind in (
    'setting', 'master_create', 'master_archive'
  )),
  primary key (publication_id, setting_key)
);

create index if not exists v1_configuration_publication_changes_area_idx
  on public.v1_configuration_publication_changes (area, publication_id);

insert into public.v1_configuration_settings (
  setting_key, area, value_type, default_value, published_value, display_order
)
values
  ('company.legal_name', 'company_regional', 'string',
    to_jsonb('Yorks Air Conditioning & Refrigeration LLC-SPC'::text),
    to_jsonb('Yorks Air Conditioning & Refrigeration LLC-SPC'::text), 10),
  ('company.short_name', 'company_regional', 'string',
    to_jsonb('Yorks AC. & Ref.'::text),
    to_jsonb('Yorks AC. & Ref.'::text), 20),
  ('company.arabic_name', 'company_regional', 'string',
    to_jsonb('يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و'::text),
    to_jsonb('يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و'::text), 30),
  ('company.workspace_name', 'company_regional', 'string',
    to_jsonb('Yorks Project & Material Management'::text),
    to_jsonb('Yorks Project & Material Management'::text), 40),
  ('regional.country', 'company_regional', 'string',
    to_jsonb('United Arab Emirates'::text),
    to_jsonb('United Arab Emirates'::text), 50),
  ('regional.timezone', 'company_regional', 'string',
    to_jsonb('Asia/Dubai'::text), to_jsonb('Asia/Dubai'::text), 60),
  ('regional.date_format', 'company_regional', 'string',
    to_jsonb('DD-MM-YYYY'::text), to_jsonb('DD-MM-YYYY'::text), 70),
  ('regional.currency', 'company_regional', 'string',
    to_jsonb('AED'::text), to_jsonb('AED'::text), 80),
  ('regional.primary_language', 'company_regional', 'string',
    to_jsonb('English'::text), to_jsonb('English'::text), 90),
  ('regional.secondary_language', 'company_regional', 'string',
    to_jsonb('Arabic'::text), to_jsonb('Arabic'::text), 100),
  ('regional.financial_year_start', 'company_regional', 'string',
    to_jsonb('1 January'::text), to_jsonb('1 January'::text), 110),
  ('requests.default_timing', 'material_requests', 'string',
    to_jsonb('normal'::text), to_jsonb('normal'::text), 210),
  ('requests.urgent_enabled', 'material_requests', 'boolean',
    'true'::jsonb, 'true'::jsonb, 220),
  ('procurement.default_source', 'procurement_inventory', 'string',
    to_jsonb('warehouse'::text), to_jsonb('warehouse'::text), 310),
  ('accounts.billing_stage_weights', 'accounts', 'weights',
    '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":5}'::jsonb,
    '{"design":10,"material_supply":50,"installation":30,"commissioning_handover":5,"energizing":5}'::jsonb, 410),
  ('accounts.payment_terms_days', 'accounts', 'integer',
    '90'::jsonb, '90'::jsonb, 420),
  ('accounts.pdc_reminder_days', 'accounts', 'integer',
    '10'::jsonb, '10'::jsonb, 430),
  ('documents.maximum_file_size_mb', 'documents_printing', 'integer',
    '20'::jsonb, '20'::jsonb, 510),
  ('documents.retention_years', 'documents_printing', 'integer',
    '7'::jsonb, '7'::jsonb, 520),
  ('documents.allowed_formats', 'documents_printing', 'string_array',
    '["PDF","DOCX","XLSX","JPG","JPEG","PNG"]'::jsonb,
    '["PDF","DOCX","XLSX","JPG","JPEG","PNG"]'::jsonb, 530),
  ('documents.bilingual_header', 'documents_printing', 'boolean',
    'true'::jsonb, 'true'::jsonb, 540),
  ('notifications.push_enabled', 'notifications', 'boolean',
    'true'::jsonb, 'true'::jsonb, 610),
  ('notifications.email_enabled', 'notifications', 'boolean',
    'false'::jsonb, 'false'::jsonb, 620),
  ('security.session_timeout_hours', 'security_audit', 'integer',
    '8'::jsonb, '8'::jsonb, 710),
  ('security.minimum_password_length', 'security_audit', 'integer',
    '10'::jsonb, '10'::jsonb, 720),
  ('security.admin_mfa_required', 'security_audit', 'boolean',
    'false'::jsonb, 'false'::jsonb, 730),
  ('security.log_exports', 'security_audit', 'boolean',
    'true'::jsonb, 'true'::jsonb, 740),
  ('security.log_access_changes', 'security_audit', 'boolean',
    'true'::jsonb, 'true'::jsonb, 750),
  ('security.audit_retention_years', 'security_audit', 'integer',
    '7'::jsonb, '7'::jsonb, 760),
  ('numbering.project_pattern', 'numbering_data', 'string',
    to_jsonb('Admin-controlled unique reference'::text),
    to_jsonb('Admin-controlled unique reference'::text), 810),
  ('numbering.material_request_pattern', 'numbering_data', 'string',
    to_jsonb('{PROJECT_REF}-MR{NNN}'::text),
    to_jsonb('{PROJECT_REF}-MR{NNN}'::text), 820),
  ('numbering.dispatch_pattern', 'numbering_data', 'string',
    to_jsonb('{PROJECT_REF}-DSP{NNN}'::text),
    to_jsonb('{PROJECT_REF}-DSP{NNN}'::text), 830),
  ('numbering.return_pattern', 'numbering_data', 'string',
    to_jsonb('{PROJECT_REF}-RTN{NNN}'::text),
    to_jsonb('{PROJECT_REF}-RTN{NNN}'::text), 840),
  ('numbering.invoice_pattern', 'numbering_data', 'string',
    to_jsonb('INV-{PROJECT}-{###}'::text),
    to_jsonb('INV-{PROJECT}-{###}'::text), 850)
on conflict (setting_key) do nothing;

insert into public.v1_configuration_draft_state (singleton, base_version)
values (true, 1)
on conflict (singleton) do nothing;

insert into public.v1_configuration_publications (
  id, version_number, version_label, reason, affected_areas,
  published_by_exact_role, published_at
)
values (
  'c3800000-0000-4000-8000-000000000001', 1, 'v1.0.0',
  'Initial controlled R38 configuration baseline',
  array[
    'company_regional', 'projects_teams', 'boq_materials',
    'material_requests', 'procurement_inventory', 'accounts',
    'documents_printing', 'notifications', 'security_audit',
    'numbering_data'
  ],
  'system', '2026-08-14 00:00:00+00'
)
on conflict (version_number) do nothing;

insert into public.v1_configuration_units (
  id, name, short_code, unit_type, decimal_places, is_system
)
values
  ('c3810000-0000-4000-8000-000000000001', 'Number', 'Nos', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000002', 'Set', 'Set', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000003', 'Metre', 'Meter', 'length', 3, true),
  ('c3810000-0000-4000-8000-000000000004', 'Centimetre', 'Cm', 'length', 3, true),
  ('c3810000-0000-4000-8000-000000000005', 'Length', 'Length', 'length', 3, true),
  ('c3810000-0000-4000-8000-000000000006', 'Pair', 'Pairs', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000007', 'Roll', 'Roll', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000008', 'Box', 'Box', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000009', 'Each', 'Each', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000010', 'Tonne', 'Ton', 'weight', 3, true),
  ('c3810000-0000-4000-8000-000000000011', 'Boxes', 'Boxes', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000012', 'Kilogram', 'Kg', 'weight', 3, true),
  ('c3810000-0000-4000-8000-000000000013', 'Litre', 'Litre', 'volume', 3, true),
  ('c3810000-0000-4000-8000-000000000014', 'Pack', 'Pack', 'count', 0, true),
  ('c3810000-0000-4000-8000-000000000015', 'Lot', 'Lot', 'other', 0, true),
  ('c3810000-0000-4000-8000-000000000016', 'Metre abbreviation', 'Mtr', 'length', 3, true)
on conflict (id) do nothing;

create or replace function public.v1_assert_configuration_admin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null
    or public.v1_current_exact_role() <> 'admin'
    or not public.v1_current_actor_is_active()
  then
    raise exception 'V1_CONFIGURATION_ADMIN_REQUIRED'
      using errcode = '42501';
  end if;
end;
$$;

create or replace function public.v1_configuration_effective_value(
  p_setting_key text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(change.proposed_value, setting.published_value)
  from public.v1_configuration_settings setting
  left join public.v1_configuration_draft_changes change
    on change.setting_key = setting.setting_key
  where setting.setting_key = p_setting_key;
$$;

create or replace function public.v1_validate_configuration_setting_value(
  p_setting_key text,
  p_value jsonb
)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
  v_number numeric;
  v_keys text[];
begin
  if p_value is null then
    raise exception 'V1_CONFIGURATION_VALUE_REQUIRED'
      using errcode = '22023';
  end if;

  if p_setting_key in (
    'company.legal_name', 'company.short_name', 'company.workspace_name',
    'regional.country', 'regional.timezone', 'regional.date_format',
    'regional.currency', 'regional.primary_language',
    'regional.secondary_language', 'regional.financial_year_start',
    'requests.default_timing'
  ) then
    if jsonb_typeof(p_value) <> 'string' then
      raise exception 'V1_CONFIGURATION_STRING_REQUIRED'
        using errcode = '22023';
    end if;
    v_text := btrim(p_value #>> '{}');
    if v_text = '' or length(v_text) > 180 then
      raise exception 'V1_CONFIGURATION_STRING_INVALID'
        using errcode = '22023';
    end if;
  elsif p_setting_key = 'company.arabic_name' then
    if jsonb_typeof(p_value) <> 'string'
      or length(p_value #>> '{}') > 180 then
      raise exception 'V1_CONFIGURATION_ARABIC_NAME_INVALID'
        using errcode = '22023';
    end if;
  elsif p_setting_key in (
    'requests.urgent_enabled', 'documents.bilingual_header',
    'notifications.push_enabled', 'notifications.email_enabled',
    'security.admin_mfa_required', 'security.log_exports',
    'security.log_access_changes'
  ) then
    if jsonb_typeof(p_value) <> 'boolean' then
      raise exception 'V1_CONFIGURATION_BOOLEAN_REQUIRED'
        using errcode = '22023';
    end if;
  elsif p_setting_key in (
    'accounts.payment_terms_days', 'accounts.pdc_reminder_days',
    'documents.retention_years',
    'security.session_timeout_hours', 'security.minimum_password_length',
    'security.audit_retention_years'
  ) then
    if jsonb_typeof(p_value) <> 'number' then
      raise exception 'V1_CONFIGURATION_INTEGER_REQUIRED'
        using errcode = '22023';
    end if;
    v_number := (p_value #>> '{}')::numeric;
    if trunc(v_number) <> v_number then
      raise exception 'V1_CONFIGURATION_INTEGER_REQUIRED'
        using errcode = '22023';
    end if;
    if (p_setting_key = 'security.minimum_password_length' and v_number < 10)
      or (p_setting_key = 'security.session_timeout_hours'
        and v_number not between 1 and 24)
      or (p_setting_key <> 'security.session_timeout_hours'
        and p_setting_key <> 'security.minimum_password_length'
        and v_number not between 0 and 50)
    then
      raise exception 'V1_CONFIGURATION_INTEGER_OUT_OF_RANGE'
        using errcode = '22023';
    end if;
  elsif p_setting_key = 'accounts.billing_stage_weights' then
    if jsonb_typeof(p_value) <> 'object' then
      raise exception 'V1_CONFIGURATION_WEIGHTS_INVALID'
        using errcode = '22023';
    end if;
    select array_agg(key order by key) into v_keys
    from jsonb_object_keys(p_value) key;
    if v_keys <> array[
      'commissioning_handover', 'design', 'energizing', 'installation',
      'material_supply'
    ]::text[] or exists (
      select 1 from jsonb_each(p_value) entry
      where jsonb_typeof(entry.value) <> 'number'
        or (entry.value #>> '{}')::numeric < 0
        or (entry.value #>> '{}')::numeric > 100
    ) then
      raise exception 'V1_CONFIGURATION_WEIGHTS_INVALID'
        using errcode = '22023';
    end if;
  else
    raise exception 'V1_CONFIGURATION_SETTING_NOT_EDITABLE'
      using errcode = '22023';
  end if;

  if p_setting_key = 'requests.default_timing'
    and v_text not in ('normal', 'urgent', 'scheduled') then
    raise exception 'V1_CONFIGURATION_TIMING_INVALID'
      using errcode = '22023';
  end if;
  if p_setting_key = 'regional.currency' and v_text <> 'AED' then
    raise exception 'V1_CONFIGURATION_CURRENCY_INVALID'
      using errcode = '22023';
  end if;
end;
$$;

create or replace function public.v1_get_configuration_validation()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_blocking jsonb := '[]'::jsonb;
  v_recommendations jsonb := '[]'::jsonb;
  v_weights jsonb;
  v_weight_total numeric;
begin
  perform public.v1_assert_configuration_admin();

  v_weights := public.v1_configuration_effective_value(
    'accounts.billing_stage_weights'
  );
  select coalesce(sum((entry.value #>> '{}')::numeric), 0)
    into v_weight_total
  from jsonb_each(v_weights) entry;

  if v_weight_total <> 100 then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'billing_weights_total',
      'area', 'accounts',
      'message', format(
        'Accounts billing stage weights total %s%%. They must total 100%%.',
        v_weight_total
      )
    ));
  end if;

  if btrim(coalesce(public.v1_configuration_effective_value(
    'company.legal_name'
  ) #>> '{}', '')) = '' then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'company_legal_name_required',
      'area', 'company_regional',
      'message', 'Legal Company Name is required.'
    ));
  end if;

  if lower(public.v1_configuration_effective_value(
      'regional.primary_language'
    ) #>> '{}') = lower(public.v1_configuration_effective_value(
      'regional.secondary_language'
    ) #>> '{}') then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'languages_must_differ',
      'area', 'company_regional',
      'message', 'Primary and secondary languages must be different.'
    ));
  end if;

  if btrim(coalesce(public.v1_configuration_effective_value(
    'company.arabic_name'
  ) #>> '{}', '')) = '' then
    v_recommendations := v_recommendations || jsonb_build_array(
      jsonb_build_object(
        'code', 'arabic_company_name_recommended',
        'area', 'company_regional',
        'message', 'Add the formal Arabic company name for bilingual controlled documents.'
      )
    );
  end if;
  if not (public.v1_configuration_effective_value(
    'security.admin_mfa_required'
  ) #>> '{}')::boolean then
    v_recommendations := v_recommendations || jsonb_build_array(
      jsonb_build_object(
        'code', 'admin_mfa_recommended',
        'area', 'security_audit',
        'message', 'Admin MFA is not enabled.'
      )
    );
  end if;
  if not (public.v1_configuration_effective_value(
    'notifications.push_enabled'
  ) #>> '{}')::boolean then
    v_recommendations := v_recommendations || jsonb_build_array(
      jsonb_build_object(
        'code', 'push_notifications_recommended',
        'area', 'notifications',
        'message', 'Push notifications are disabled; mobile reminders may be missed.'
      )
    );
  end if;

  if exists (
    select 1
    from public.v1_configuration_master_actions action
    join public.v1_inventory_categories category
      on category.normalized_name = public.v1_inventory_category_key(
        action.payload ->> 'name'
      )
    where action.entity_kind = 'material_category'
      and action.action_kind = 'create'
  ) then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'material_category_conflict',
      'area', 'boq_materials',
      'message', 'A staged material category now conflicts with existing master data.'
    ));
  end if;

  if exists (
    select 1
    from public.v1_configuration_master_actions action
    join public.v1_configuration_units unit_record
      on lower(btrim(unit_record.short_code)) =
        lower(btrim(action.payload ->> 'short_code'))
      and unit_record.is_active
    where action.entity_kind = 'material_unit'
      and action.action_kind = 'create'
  ) then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'material_unit_conflict',
      'area', 'boq_materials',
      'message', 'A staged material unit now conflicts with existing master data.'
    ));
  end if;

  if exists (
    select 1
    from public.v1_configuration_master_actions action
    where action.action_kind = 'archive'
      and (
        (action.entity_kind = 'material_category' and (
          not exists (
            select 1 from public.v1_inventory_categories category
            where category.id = action.target_id and category.is_active
          )
          or exists (
            select 1 from public.v1_inventory_categories child
            where child.parent_category_id = action.target_id
              and child.is_active
          )
        ))
        or (action.entity_kind = 'material_unit' and (
          not exists (
            select 1 from public.v1_configuration_units unit_record
            where unit_record.id = action.target_id and unit_record.is_active
          )
          or exists (
            select 1
            from public.v1_configuration_units unit_record
            join public.v1_inventory_items inventory_item
              on lower(btrim(inventory_item.unit)) =
                lower(btrim(unit_record.short_code))
            where unit_record.id = action.target_id
              and inventory_item.is_active
          )
          or exists (
            select 1
            from public.v1_configuration_units unit_record
            join public.v1_material_request_lines request_line
              on lower(btrim(request_line.unit)) =
                lower(btrim(unit_record.short_code))
            join public.v1_material_requests request_record
              on request_record.id = request_line.request_id
            where unit_record.id = action.target_id
              and request_record.state not in ('closed', 'cancelled')
          )
        ))
      )
  ) then
    v_blocking := v_blocking || jsonb_build_array(jsonb_build_object(
      'code', 'master_archive_conflict',
      'area', 'boq_materials',
      'message', 'A staged archive is no longer valid against current master data.'
    ));
  end if;

  return jsonb_build_object(
    'status', case
      when jsonb_array_length(v_blocking) > 0 then 'blocked'
      when jsonb_array_length(v_recommendations) > 0 then 'recommendations'
      else 'ready'
    end,
    'blocking', v_blocking,
    'recommendations', v_recommendations
  );
end;
$$;

create or replace function public.v1_get_configuration_centre()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform public.v1_assert_configuration_admin();

  select jsonb_build_object(
    'schema_version', 'R38.5 / 1.0',
    'environment', 'server_managed',
    'published_version', latest.version_number,
    'published_label', latest.version_label,
    'published_at', latest.published_at,
    'published_by', coalesce(profile.display_name, 'System baseline'),
    'draft_revision', draft.draft_revision,
    'draft_base_version', draft.base_version,
    'draft_updated_at', draft.updated_at,
    'settings', coalesce((
      select jsonb_agg(jsonb_build_object(
        'key', setting.setting_key,
        'area', setting.area,
        'type', setting.value_type,
        'published_value', setting.published_value,
        'draft_value', change.proposed_value,
        'effective_value', coalesce(change.proposed_value,
          setting.published_value),
        'changed', change.setting_key is not null
      ) order by setting.display_order)
      from public.v1_configuration_settings setting
      left join public.v1_configuration_draft_changes change
        on change.setting_key = setting.setting_key
    ), '[]'::jsonb),
    'master_actions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', action.id,
        'entity_kind', action.entity_kind,
        'action_kind', action.action_kind,
        'target_id', action.target_id,
        'payload', action.payload,
        'reason', action.reason,
        'staged_at', action.staged_at
      ) order by action.staged_at, action.id)
      from public.v1_configuration_master_actions action
    ), '[]'::jsonb),
    'material_categories', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', category.id,
        'name', category.name,
        'parent_category_id', category.parent_category_id,
        'is_system', category.is_system,
        'is_active', category.is_active,
        'item_count', (
          select count(*)
          from public.v1_inventory_items item
          where item.category_id = category.id
            and item.is_active
        )
      ) order by category.is_active desc, category.name)
      from public.v1_inventory_categories category
    ), '[]'::jsonb),
    'material_units', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', unit_record.id,
        'name', unit_record.name,
        'short_code', unit_record.short_code,
        'unit_type', unit_record.unit_type,
        'decimal_places', unit_record.decimal_places,
        'is_system', unit_record.is_system,
        'is_active', unit_record.is_active
      ) order by unit_record.is_active desc, unit_record.name)
      from public.v1_configuration_units unit_record
    ), '[]'::jsonb),
    'boq_group_templates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'template_key', template.template_key,
        'display_name', template.display_name,
        'display_order', template.display_order,
        'is_frozen', template.is_frozen,
        'is_active', template.is_active
      ) order by template.display_order)
      from public.v1_boq_group_templates template
      where template.is_active
    ), '[]'::jsonb),
    'history', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', history.id,
        'version_number', history.version_number,
        'version_label', history.version_label,
        'reason', history.reason,
        'affected_areas', history.affected_areas,
        'published_at', history.published_at,
        'published_by', coalesce(history_profile.display_name,
          'System baseline'),
        'published_by_exact_role', history.published_by_exact_role,
        'change_count', (
          select count(*)
          from public.v1_configuration_publication_changes history_change
          where history_change.publication_id = history.id
        )
      ) order by history.version_number desc)
      from public.v1_configuration_publications history
      left join public.v1_profiles history_profile
        on history_profile.auth_user_id = history.published_by_auth_user_id
    ), '[]'::jsonb),
    'validation', public.v1_get_configuration_validation()
  ) into v_result
  from public.v1_configuration_publications latest
  cross join public.v1_configuration_draft_state draft
  left join public.v1_profiles profile
    on profile.auth_user_id = latest.published_by_auth_user_id
  order by latest.version_number desc
  limit 1;

  return v_result;
end;
$$;

create or replace function public.v1_list_configuration_units()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null
    or public.v1_current_exact_role() not in (
      'project_engineer', 'site_engineer', 'procurement', 'admin',
      'senior_mechanical_engineer', 'project_manager'
    )
    or not public.v1_current_actor_is_active()
  then
    raise exception 'V1_CONFIGURATION_ACTIVE_USER_REQUIRED'
      using errcode = '42501';
  end if;

  select coalesce(
    jsonb_agg(unit_record.short_code order by unit_record.name),
    '[]'::jsonb
  ) into v_result
  from public.v1_configuration_units unit_record
  where unit_record.is_active;
  return v_result;
end;
$$;

create or replace function public.v1_enforce_active_configuration_unit()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.v1_configuration_units unit_record
    where unit_record.is_active
      and lower(btrim(unit_record.short_code)) = lower(btrim(new.unit))
  ) then
    raise exception 'V1_CONFIGURATION_UNIT_NOT_ACTIVE'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_request_lines_controlled_unit
  on public.v1_material_request_lines;
create trigger v1_material_request_lines_controlled_unit
before insert or update of unit on public.v1_material_request_lines
for each row execute function public.v1_enforce_active_configuration_unit();

drop trigger if exists v1_inventory_items_controlled_unit
  on public.v1_inventory_items;
create trigger v1_inventory_items_controlled_unit
before insert or update of unit on public.v1_inventory_items
for each row execute function public.v1_enforce_active_configuration_unit();

create or replace function public.v1_stage_configuration_setting(
  p_setting_key text,
  p_value jsonb,
  p_expected_revision integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_state public.v1_configuration_draft_state%rowtype;
  v_setting public.v1_configuration_settings%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_payload jsonb := jsonb_build_object(
    'setting_key', p_setting_key,
    'value', p_value,
    'expected_revision', p_expected_revision
  );
begin
  perform public.v1_assert_configuration_admin();
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_stage_configuration_setting', p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;

  select * into v_state from public.v1_configuration_draft_state
  where singleton for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;

  select * into v_setting from public.v1_configuration_settings
  where setting_key = p_setting_key;
  if not found then
    raise exception 'V1_CONFIGURATION_SETTING_NOT_EDITABLE'
      using errcode = '22023';
  end if;
  perform public.v1_validate_configuration_setting_value(
    p_setting_key, p_value
  );

  if p_value = public.v1_configuration_effective_value(p_setting_key) then
    v_response := jsonb_build_object(
      'draft_revision', v_state.draft_revision,
      'setting_key', p_setting_key,
      'unchanged', true
    );
    perform public.v1_complete_idempotency(
      'v1_stage_configuration_setting', p_idempotency_key, v_response
    );
    return v_response;
  end if;

  if p_value = v_setting.published_value then
    delete from public.v1_configuration_draft_changes
    where setting_key = p_setting_key;
  else
    insert into public.v1_configuration_draft_changes (
      setting_key, proposed_value, staged_by_auth_user_id, staged_at
    ) values (p_setting_key, p_value, v_actor, clock_timestamp())
    on conflict (setting_key) do update set
      proposed_value = excluded.proposed_value,
      staged_by_auth_user_id = excluded.staged_by_auth_user_id,
      staged_at = excluded.staged_at;
  end if;

  update public.v1_configuration_draft_state set
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where singleton
  returning draft_revision into v_state.draft_revision;

  v_response := jsonb_build_object(
    'draft_revision', v_state.draft_revision,
    'setting_key', p_setting_key
  );
  perform public.v1_complete_idempotency(
    'v1_stage_configuration_setting', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_stage_configuration_master_action(
  p_entity_kind text,
  p_action_kind text,
  p_target_id uuid,
  p_payload jsonb,
  p_reason text,
  p_expected_revision integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_action_id uuid;
  v_existing_action public.v1_configuration_master_actions%rowtype;
  v_category_name text;
  v_category_key text;
  v_payload jsonb := jsonb_build_object(
    'entity_kind', p_entity_kind, 'action_kind', p_action_kind,
    'target_id', p_target_id, 'payload', p_payload, 'reason', p_reason,
    'expected_revision', p_expected_revision
  );
begin
  perform public.v1_assert_configuration_admin();
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_stage_configuration_master_action', p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;

  select * into v_state from public.v1_configuration_draft_state
  where singleton for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if p_target_id is null
    or p_entity_kind not in ('material_category', 'material_unit')
    or p_action_kind not in ('create', 'archive') then
    raise exception 'V1_CONFIGURATION_MASTER_ACTION_INVALID'
      using errcode = '22023';
  end if;

  if p_action_kind = 'create' then
    if p_entity_kind = 'material_category' then
      perform public.v1_assert_object_keys(
        p_payload, array['name', 'parent_category_id'],
        'configuration_category'
      );
      v_category_name := public.v1_inventory_category_display_name(
        p_payload ->> 'name'
      );
      v_category_key := public.v1_inventory_category_key(v_category_name);
      if v_category_key = ''
        or length(v_category_name) > 100
        or exists (
          select 1 from public.v1_inventory_categories category
          where category.normalized_name = v_category_key
        )
        or exists (
          select 1 from public.v1_configuration_master_actions action
          where action.entity_kind = 'material_category'
            and action.action_kind = 'create'
            and action.target_id <> p_target_id
            and public.v1_inventory_category_key(
              action.payload ->> 'name'
            ) = v_category_key
        ) then
        raise exception 'V1_CONFIGURATION_CATEGORY_INVALID_OR_DUPLICATE'
          using errcode = '23505';
      end if;
      if nullif(p_payload ->> 'parent_category_id', '') is not null
        and not exists (
          select 1 from public.v1_inventory_categories category
          where category.id = (p_payload ->> 'parent_category_id')::uuid
            and category.is_active
            and category.parent_category_id is null
        ) then
        raise exception 'V1_CONFIGURATION_CATEGORY_PARENT_INVALID'
          using errcode = '23503';
      end if;
      if nullif(p_payload ->> 'parent_category_id', '') is not null
        and exists (
          select 1 from public.v1_configuration_master_actions action
          where action.entity_kind = 'material_category'
            and action.action_kind = 'archive'
            and action.target_id =
              (p_payload ->> 'parent_category_id')::uuid
        ) then
        raise exception 'V1_CONFIGURATION_CATEGORY_PARENT_INVALID'
          using errcode = '23503';
      end if;
    else
      perform public.v1_assert_object_keys(
        p_payload, array['name', 'short_code', 'unit_type', 'decimal_places'],
        'configuration_unit'
      );
      if btrim(coalesce(p_payload ->> 'name', '')) = ''
        or length(btrim(p_payload ->> 'name')) > 80
        or btrim(coalesce(p_payload ->> 'short_code', '')) = ''
        or length(btrim(p_payload ->> 'short_code')) > 20
        or coalesce(p_payload ->> 'unit_type', '') not in (
          'count', 'length', 'area', 'volume', 'weight', 'other'
        )
        or coalesce(p_payload ->> 'decimal_places', '') !~ '^[0-4]$'
        or exists (
          select 1 from public.v1_configuration_units unit_record
          where lower(btrim(unit_record.short_code)) =
            lower(btrim(p_payload ->> 'short_code'))
            and unit_record.is_active
        )
        or exists (
          select 1 from public.v1_configuration_master_actions action
          where action.entity_kind = 'material_unit'
            and action.action_kind = 'create'
            and action.target_id <> p_target_id
            and lower(btrim(action.payload ->> 'short_code')) =
              lower(btrim(p_payload ->> 'short_code'))
        ) then
        raise exception 'V1_CONFIGURATION_UNIT_INVALID_OR_DUPLICATE'
          using errcode = '23505';
      end if;
    end if;
  else
    if btrim(coalesce(p_reason, '')) = '' or length(btrim(p_reason)) > 500 then
      raise exception 'V1_CONFIGURATION_ARCHIVE_REASON_REQUIRED'
        using errcode = '22023';
    end if;
    if p_entity_kind = 'material_category' and not exists (
      select 1 from public.v1_inventory_categories category
      where category.id = p_target_id and category.is_active
    ) then
      raise exception 'V1_CONFIGURATION_CATEGORY_NOT_ACTIVE'
        using errcode = 'P0002';
    end if;
    if p_entity_kind = 'material_category' and (
      exists (
        select 1 from public.v1_inventory_categories child
        where child.parent_category_id = p_target_id and child.is_active
      )
      or exists (
        select 1 from public.v1_configuration_master_actions action
        where action.entity_kind = 'material_category'
          and action.action_kind = 'create'
          and nullif(action.payload ->> 'parent_category_id', '')::uuid =
            p_target_id
      )
    ) then
      raise exception 'V1_CONFIGURATION_CATEGORY_HAS_ACTIVE_CHILDREN'
        using errcode = '23514';
    end if;
    if p_entity_kind = 'material_unit' and not exists (
      select 1 from public.v1_configuration_units unit_record
      where unit_record.id = p_target_id and unit_record.is_active
    ) then
      raise exception 'V1_CONFIGURATION_UNIT_NOT_ACTIVE'
        using errcode = 'P0002';
    end if;
  end if;

  select * into v_existing_action
  from public.v1_configuration_master_actions action
  where action.entity_kind = p_entity_kind
    and action.action_kind = p_action_kind
    and action.target_id = p_target_id;
  if found
    and v_existing_action.payload = coalesce(p_payload, '{}'::jsonb)
    and v_existing_action.reason is not distinct from
      nullif(btrim(coalesce(p_reason, '')), '')
  then
    v_response := jsonb_build_object(
      'draft_revision', v_state.draft_revision,
      'action_id', v_existing_action.id,
      'unchanged', true
    );
    perform public.v1_complete_idempotency(
      'v1_stage_configuration_master_action', p_idempotency_key, v_response
    );
    return v_response;
  end if;

  insert into public.v1_configuration_master_actions (
    id, entity_kind, action_kind, target_id, payload, reason,
    staged_by_auth_user_id
  ) values (
    p_idempotency_key, p_entity_kind, p_action_kind, p_target_id,
    coalesce(p_payload, '{}'::jsonb), nullif(btrim(coalesce(p_reason, '')), ''),
    v_actor
  )
  on conflict (entity_kind, action_kind, target_id) do update set
    payload = excluded.payload,
    reason = excluded.reason,
    staged_by_auth_user_id = excluded.staged_by_auth_user_id,
    staged_at = clock_timestamp()
  returning id into v_action_id;

  update public.v1_configuration_draft_state set
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where singleton
  returning draft_revision into v_state.draft_revision;

  v_response := jsonb_build_object(
    'draft_revision', v_state.draft_revision,
    'action_id', v_action_id
  );
  perform public.v1_complete_idempotency(
    'v1_stage_configuration_master_action', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_discard_configuration_draft(
  p_expected_revision integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_payload jsonb := jsonb_build_object(
    'expected_revision', p_expected_revision
  );
begin
  perform public.v1_assert_configuration_admin();
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_discard_configuration_draft', p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;
  select * into v_state from public.v1_configuration_draft_state
  where singleton for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  delete from public.v1_configuration_draft_changes;
  delete from public.v1_configuration_master_actions;
  update public.v1_configuration_draft_state set
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = auth.uid(),
    updated_at = clock_timestamp()
  where singleton returning draft_revision into v_state.draft_revision;
  v_response := jsonb_build_object(
    'draft_revision', v_state.draft_revision, 'discarded', true
  );
  perform public.v1_complete_idempotency(
    'v1_discard_configuration_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_restore_configuration_defaults(
  p_expected_revision integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_response jsonb;
  v_payload jsonb := jsonb_build_object(
    'expected_revision', p_expected_revision
  );
begin
  perform public.v1_assert_configuration_admin();
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_restore_configuration_defaults', p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;
  select * into v_state from public.v1_configuration_draft_state
  where singleton for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if not exists (
    select 1
    from public.v1_configuration_settings setting
    where public.v1_configuration_effective_value(setting.setting_key) <>
      setting.default_value
  ) then
    v_response := jsonb_build_object(
      'draft_revision', v_state.draft_revision,
      'restored', true,
      'unchanged', true
    );
    perform public.v1_complete_idempotency(
      'v1_restore_configuration_defaults', p_idempotency_key, v_response
    );
    return v_response;
  end if;
  insert into public.v1_configuration_draft_changes (
    setting_key, proposed_value, staged_by_auth_user_id, staged_at
  )
  select setting.setting_key, setting.default_value, auth.uid(),
    clock_timestamp()
  from public.v1_configuration_settings setting
  where setting.default_value <> setting.published_value
  on conflict (setting_key) do update set
    proposed_value = excluded.proposed_value,
    staged_by_auth_user_id = excluded.staged_by_auth_user_id,
    staged_at = excluded.staged_at;
  delete from public.v1_configuration_draft_changes change
  using public.v1_configuration_settings setting
  where change.setting_key = setting.setting_key
    and setting.default_value = setting.published_value;
  update public.v1_configuration_draft_state set
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = auth.uid(), updated_at = clock_timestamp()
  where singleton returning draft_revision into v_state.draft_revision;
  v_response := jsonb_build_object(
    'draft_revision', v_state.draft_revision, 'restored', true
  );
  perform public.v1_complete_idempotency(
    'v1_restore_configuration_defaults', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_publish_configuration(
  p_reason text,
  p_expected_revision integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_state public.v1_configuration_draft_state%rowtype;
  v_existing jsonb;
  v_validation jsonb;
  v_publication_id uuid := gen_random_uuid();
  v_next_version integer;
  v_version_label text;
  v_areas text[];
  v_response jsonb;
  v_payload jsonb := jsonb_build_object(
    'reason', btrim(coalesce(p_reason, '')),
    'expected_revision', p_expected_revision
  );
  v_action public.v1_configuration_master_actions%rowtype;
begin
  perform public.v1_assert_configuration_admin();
  if length(btrim(coalesce(p_reason, ''))) not between 8 and 500 then
    raise exception 'V1_CONFIGURATION_PUBLISH_REASON_REQUIRED'
      using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_publish_configuration', p_idempotency_key, v_payload
  );
  if v_existing is not null then return v_existing; end if;

  select * into v_state from public.v1_configuration_draft_state
  where singleton for update;
  if p_expected_revision is null
    or p_expected_revision <> v_state.draft_revision then
    raise exception 'V1_CONFIGURATION_DRAFT_VERSION_CONFLICT'
      using errcode = '40001';
  end if;
  if not exists (select 1 from public.v1_configuration_draft_changes)
    and not exists (select 1 from public.v1_configuration_master_actions) then
    raise exception 'V1_CONFIGURATION_NO_DRAFT_CHANGES'
      using errcode = '22023';
  end if;
  v_validation := public.v1_get_configuration_validation();
  if v_validation ->> 'status' = 'blocked' then
    raise exception 'V1_CONFIGURATION_VALIDATION_BLOCKED'
      using errcode = '23514', detail = v_validation::text;
  end if;

  select coalesce(max(version_number), 0) + 1 into v_next_version
  from public.v1_configuration_publications;
  v_version_label := format('v1.%s.0', v_next_version - 1);
  select array_agg(area order by area) into v_areas from (
    select distinct setting.area
    from public.v1_configuration_draft_changes change
    join public.v1_configuration_settings setting
      on setting.setting_key = change.setting_key
    union
    select 'boq_materials'::text
    from public.v1_configuration_master_actions
  ) affected;

  insert into public.v1_configuration_publications (
    id, version_number, version_label, reason, affected_areas,
    published_by_auth_user_id, published_by_exact_role, idempotency_key
  ) values (
    v_publication_id, v_next_version, v_version_label, btrim(p_reason),
    v_areas, v_actor, public.v1_current_exact_role(), p_idempotency_key
  );

  insert into public.v1_configuration_publication_changes (
    publication_id, setting_key, area, before_value, after_value, change_kind
  )
  select v_publication_id, setting.setting_key, setting.area,
    setting.published_value, change.proposed_value, 'setting'
  from public.v1_configuration_draft_changes change
  join public.v1_configuration_settings setting
    on setting.setting_key = change.setting_key;

  update public.v1_configuration_settings setting set
    published_value = change.proposed_value,
    updated_at = clock_timestamp()
  from public.v1_configuration_draft_changes change
  where change.setting_key = setting.setting_key;

  for v_action in
    select * from public.v1_configuration_master_actions
    order by entity_kind, action_kind, target_id
  loop
    if v_action.entity_kind = 'material_category'
      and v_action.action_kind = 'create' then
      insert into public.v1_inventory_categories (
        id, name, normalized_name, parent_category_id, is_system,
        is_active, created_by_auth_user_id
      ) values (
        v_action.target_id,
        public.v1_inventory_category_display_name(
          v_action.payload ->> 'name'
        ),
        public.v1_inventory_category_key(v_action.payload ->> 'name'),
        nullif(v_action.payload ->> 'parent_category_id', '')::uuid,
        false, true, v_actor
      );
    elsif v_action.entity_kind = 'material_category'
      and v_action.action_kind = 'archive' then
      update public.v1_inventory_categories set
        is_active = false,
        record_version = record_version + 1,
        updated_at = clock_timestamp()
      where id = v_action.target_id and is_active;
    elsif v_action.entity_kind = 'material_unit'
      and v_action.action_kind = 'create' then
      insert into public.v1_configuration_units (
        id, name, short_code, unit_type, decimal_places, is_system,
        created_by_auth_user_id
      ) values (
        v_action.target_id, btrim(v_action.payload ->> 'name'),
        btrim(v_action.payload ->> 'short_code'),
        v_action.payload ->> 'unit_type',
        (v_action.payload ->> 'decimal_places')::integer, false, v_actor
      );
    elsif v_action.entity_kind = 'material_unit'
      and v_action.action_kind = 'archive' then
      update public.v1_configuration_units set
        is_active = false, updated_at = clock_timestamp()
      where id = v_action.target_id and is_active;
    end if;

    insert into public.v1_configuration_publication_changes (
      publication_id, setting_key, area, before_value, after_value,
      change_kind
    ) values (
      v_publication_id,
      format('%s.%s', v_action.entity_kind, v_action.target_id),
      'boq_materials',
      case when v_action.action_kind = 'archive'
        then jsonb_build_object('active', true) else null end,
      v_action.payload || jsonb_build_object(
        'active', v_action.action_kind = 'create',
        'reason', v_action.reason
      ),
      case when v_action.action_kind = 'create'
        then 'master_create' else 'master_archive' end
    );
  end loop;

  delete from public.v1_configuration_draft_changes;
  delete from public.v1_configuration_master_actions;
  update public.v1_configuration_draft_state set
    base_version = v_next_version,
    draft_revision = draft_revision + 1,
    updated_by_auth_user_id = v_actor,
    updated_at = clock_timestamp()
  where singleton returning draft_revision into v_state.draft_revision;

  perform public.v1_write_audit_event(
    'configuration_published', 'configuration_publication',
    v_publication_id, null, null,
    jsonb_build_object(
      'version', v_version_label,
      'areas', to_jsonb(v_areas),
      'record_version', v_next_version
    ), btrim(p_reason), p_idempotency_key
  );
  v_response := jsonb_build_object(
    'publication_id', v_publication_id,
    'version_number', v_next_version,
    'version_label', v_version_label,
    'draft_revision', v_state.draft_revision,
    'affected_areas', to_jsonb(v_areas)
  );
  perform public.v1_complete_idempotency(
    'v1_publish_configuration', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_configuration_history_immutable()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'V1_CONFIGURATION_HISTORY_IMMUTABLE'
    using errcode = '55000';
end;
$$;

drop trigger if exists v1_configuration_publications_immutable
  on public.v1_configuration_publications;
create trigger v1_configuration_publications_immutable
before update or delete on public.v1_configuration_publications
for each row execute function public.v1_configuration_history_immutable();

drop trigger if exists v1_configuration_publication_changes_immutable
  on public.v1_configuration_publication_changes;
create trigger v1_configuration_publication_changes_immutable
before update or delete on public.v1_configuration_publication_changes
for each row execute function public.v1_configuration_history_immutable();

alter table public.v1_configuration_settings enable row level security;
alter table public.v1_configuration_draft_state enable row level security;
alter table public.v1_configuration_draft_changes enable row level security;
alter table public.v1_configuration_master_actions enable row level security;
alter table public.v1_configuration_units enable row level security;
alter table public.v1_configuration_publications enable row level security;
alter table public.v1_configuration_publication_changes enable row level security;

revoke all on table public.v1_configuration_settings,
  public.v1_configuration_draft_state,
  public.v1_configuration_draft_changes,
  public.v1_configuration_master_actions,
  public.v1_configuration_units,
  public.v1_configuration_publications,
  public.v1_configuration_publication_changes
from public, anon, authenticated;

grant all on table public.v1_configuration_settings,
  public.v1_configuration_draft_state,
  public.v1_configuration_draft_changes,
  public.v1_configuration_master_actions,
  public.v1_configuration_units,
  public.v1_configuration_publications,
  public.v1_configuration_publication_changes
to service_role;

revoke all on function public.v1_assert_configuration_admin() from public;
revoke all on function public.v1_configuration_effective_value(text) from public;
revoke all on function public.v1_validate_configuration_setting_value(text,jsonb)
  from public;
revoke all on function public.v1_get_configuration_validation() from public;
revoke all on function public.v1_get_configuration_centre() from public;
revoke all on function public.v1_list_configuration_units() from public;
revoke all on function public.v1_enforce_active_configuration_unit()
  from public;
revoke all on function public.v1_stage_configuration_setting(
  text,jsonb,integer,uuid
) from public;
revoke all on function public.v1_stage_configuration_master_action(
  text,text,uuid,jsonb,text,integer,uuid
) from public;
revoke all on function public.v1_discard_configuration_draft(integer,uuid)
  from public;
revoke all on function public.v1_restore_configuration_defaults(integer,uuid)
  from public;
revoke all on function public.v1_publish_configuration(text,integer,uuid)
  from public;
revoke all on function public.v1_configuration_history_immutable() from public;

grant execute on function public.v1_get_configuration_validation()
  to authenticated;
grant execute on function public.v1_get_configuration_centre()
  to authenticated;
grant execute on function public.v1_list_configuration_units()
  to authenticated;
grant execute on function public.v1_stage_configuration_setting(
  text,jsonb,integer,uuid
) to authenticated;
grant execute on function public.v1_stage_configuration_master_action(
  text,text,uuid,jsonb,text,integer,uuid
) to authenticated;
grant execute on function public.v1_discard_configuration_draft(integer,uuid)
  to authenticated;
grant execute on function public.v1_restore_configuration_defaults(integer,uuid)
  to authenticated;
grant execute on function public.v1_publish_configuration(text,integer,uuid)
  to authenticated;

commit;
