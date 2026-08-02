-- Yorks V1 Batch 9: controlled documents and safe audit projections.
--
-- Objects stay in a private Storage bucket.  This schema records immutable
-- versions and links them to authoritative Yorks entities; a path alone never
-- grants a read.  The upload flow deliberately has two trusted steps:
-- authenticated callers obtain a short-lived, scoped upload intent, and the
-- server-side finalizer verifies the uploaded bytes before materialising the
-- document version and its first link.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'yorks-documents',
  'yorks-documents',
  false,
  6291456,
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png'
  ]
)
on conflict (id) do nothing;

create table if not exists public.v1_documents (
  id uuid primary key,
  classification text not null check (classification in (
    'operational', 'commercial', 'admin_restricted'
  )),
  current_version_id uuid,
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_by_role text not null check (created_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_document_versions (
  id uuid primary key,
  document_id uuid not null references public.v1_documents (id)
    on delete restrict,
  revision_number integer not null check (revision_number > 0),
  bucket_id text not null default 'yorks-documents'
    check (bucket_id = 'yorks-documents'),
  object_path text not null check (btrim(object_path) <> ''),
  original_file_name text not null check (
    btrim(original_file_name) <> ''
    and length(original_file_name) <= 180
    and position('/' in original_file_name) = 0
    and position(chr(92) in original_file_name) = 0
  ),
  mime_type text not null check (mime_type in (
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/jpeg',
    'image/png'
  )),
  byte_size bigint not null check (byte_size > 0 and byte_size <= 6291456),
  sha256 text not null check (sha256 ~ '^[a-f0-9]{64}$'),
  origin text not null check (origin in ('uploaded', 'generated')),
  source_entity_type text,
  source_entity_id uuid,
  source_revision text,
  uploaded_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  uploaded_by_role text not null check (uploaded_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  uploaded_at timestamptz not null default clock_timestamp(),
  supersedes_version_id uuid references public.v1_document_versions (id)
    on delete restrict,
  unique (document_id, revision_number),
  unique (bucket_id, object_path),
  check (
    (origin = 'uploaded'
      and source_entity_type is null
      and source_entity_id is null
      and source_revision is null)
    or
    (origin = 'generated'
      and source_entity_type in (
        'material_request', 'delivery_order', 'material_return'
      )
      and source_entity_id is not null
      and source_revision is not null
      and btrim(source_revision) <> '')
  )
);

alter table public.v1_documents
  drop constraint if exists v1_documents_current_version_fk;
alter table public.v1_documents
  add constraint v1_documents_current_version_fk
  foreign key (current_version_id)
  references public.v1_document_versions (id)
  deferrable initially deferred;

create table if not exists public.v1_document_links (
  id uuid primary key,
  document_id uuid not null references public.v1_documents (id)
    on delete restrict,
  project_id uuid not null references public.v1_projects (id)
    on delete restrict,
  entity_type text not null check (entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch',
    'material_return', 'delivery_order'
  )),
  entity_id uuid not null,
  linked_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  linked_by_role text not null check (linked_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  linked_at timestamptz not null default clock_timestamp(),
  cross_project_reason text,
  removed_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  removed_by_role text check (removed_by_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  removed_at timestamptz,
  removal_reason text,
  check (
    (removed_at is null
      and removed_by_auth_user_id is null
      and removed_by_role is null
      and removal_reason is null)
    or
    (removed_at is not null
      and removed_by_auth_user_id is not null
      and removed_by_role is not null
      and removal_reason is not null
      and btrim(removal_reason) <> '')
  )
);

create unique index if not exists v1_document_links_one_current_target_idx
  on public.v1_document_links (document_id, entity_type, entity_id)
  where removed_at is null;
create index if not exists v1_document_links_project_current_idx
  on public.v1_document_links (project_id, linked_at desc)
  where removed_at is null;
create index if not exists v1_document_versions_document_revision_idx
  on public.v1_document_versions (document_id, revision_number desc);

create table if not exists public.v1_document_upload_intents (
  id uuid primary key,
  project_id uuid not null references public.v1_projects (id)
    on delete restrict,
  target_entity_type text not null check (target_entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch',
    'material_return', 'delivery_order'
  )),
  target_entity_id uuid not null,
  document_id uuid references public.v1_documents (id) on delete restrict,
  planned_revision_number integer not null check (planned_revision_number > 0),
  classification text not null check (classification in (
    'operational', 'commercial', 'admin_restricted'
  )),
  original_file_name text not null,
  mime_type text not null,
  byte_size bigint not null,
  expected_sha256 text not null,
  origin text not null check (origin in ('uploaded', 'generated')),
  source_entity_type text,
  source_entity_id uuid,
  source_revision text,
  bucket_id text not null default 'yorks-documents'
    check (bucket_id = 'yorks-documents'),
  object_path text not null unique,
  actor_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  actor_role text not null check (actor_role in (
    'project_engineer', 'site_engineer', 'procurement', 'admin'
  )),
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  expires_at timestamptz not null,
  finalized_document_id uuid references public.v1_documents (id)
    on delete restrict,
  finalized_version_id uuid references public.v1_document_versions (id)
    on delete restrict,
  finalized_at timestamptz,
  check (expires_at > created_at),
  check (
    (finalized_at is null
      and finalized_document_id is null
      and finalized_version_id is null)
    or
    (finalized_at is not null
      and finalized_document_id is not null
      and finalized_version_id is not null)
  )
);

create index if not exists v1_document_upload_intents_actor_idx
  on public.v1_document_upload_intents (actor_auth_user_id, expires_at desc);

alter table public.v1_documents enable row level security;
alter table public.v1_document_versions enable row level security;
alter table public.v1_document_links enable row level security;
alter table public.v1_document_upload_intents enable row level security;

revoke all on table public.v1_documents from public, anon, authenticated;
revoke all on table public.v1_document_versions from public, anon, authenticated;
revoke all on table public.v1_document_links from public, anon, authenticated;
revoke all on table public.v1_document_upload_intents from public, anon, authenticated;
grant all on table public.v1_documents to service_role;
grant all on table public.v1_document_versions to service_role;
grant all on table public.v1_document_links to service_role;
grant all on table public.v1_document_upload_intents to service_role;

create or replace function public.v1_document_target_project_id(
  p_entity_type text,
  p_entity_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
begin
  case p_entity_type
    when 'project' then
      select project.id into v_project_id
      from public.v1_projects project where project.id = p_entity_id;
    when 'boq_group' then
      select boq_group.project_id into v_project_id
      from public.v1_boq_groups boq_group where boq_group.id = p_entity_id;
    when 'material_request' then
      select request_record.project_id into v_project_id
      from public.v1_material_requests request_record
      where request_record.id = p_entity_id;
    when 'dispatch' then
      select request_record.project_id into v_project_id
      from public.v1_material_dispatches dispatch_record
      join public.v1_material_requests request_record
        on request_record.id = dispatch_record.request_id
      where dispatch_record.id = p_entity_id;
    when 'material_return' then
      select material_return.project_id into v_project_id
      from public.v1_material_returns material_return
      where material_return.id = p_entity_id;
    when 'delivery_order' then
      select request_record.project_id into v_project_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = delivery_order.dispatch_id
      join public.v1_material_requests request_record
        on request_record.id = dispatch_record.request_id
      where delivery_order.id = p_entity_id;
    else
      raise exception 'V1_DOCUMENT_TARGET_TYPE_INVALID' using errcode = '22023';
  end case;

  if v_project_id is null then
    raise exception 'V1_DOCUMENT_TARGET_NOT_FOUND' using errcode = '22023';
  end if;
  return v_project_id;
end;
$$;

create or replace function public.v1_document_target_readable(
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_project_id uuid;
begin
  case p_entity_type
    when 'project' then
      return public.v1_project_readable(p_entity_id);
    when 'boq_group' then
      select project_id into v_project_id from public.v1_boq_groups
      where id = p_entity_id;
      return v_project_id is not null and public.v1_project_readable(v_project_id);
    when 'material_request' then
      return public.v1_material_request_readable(p_entity_id);
    when 'dispatch' then
      select request_id into v_request_id from public.v1_material_dispatches
      where id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    when 'material_return' then
      select request_id into v_request_id from public.v1_material_returns
      where id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    when 'delivery_order' then
      select dispatch_record.request_id into v_request_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id = delivery_order.dispatch_id
      where delivery_order.id = p_entity_id;
      return v_request_id is not null
        and public.v1_material_request_readable(v_request_id);
    else
      return false;
  end case;
end;
$$;

create or replace function public.v1_document_classification_writable(
  p_classification text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  return case p_classification
    when 'operational' then true
    when 'commercial' then public.v1_has_capability('view_commercials')
    when 'admin_restricted' then public.v1_current_role() = 'admin'
    else false
  end;
end;
$$;

create or replace function public.v1_document_target_writable(
  p_entity_type text,
  p_entity_id uuid,
  p_classification text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
begin
  if not public.v1_document_target_readable(p_entity_type, p_entity_id)
    or not public.v1_document_classification_writable(p_classification) then
    return false;
  end if;
  v_project_id := public.v1_document_target_project_id(p_entity_type, p_entity_id);
  select state into v_project_state from public.v1_projects where id = v_project_id;
  return v_project_state in ('draft', 'active', 'on_hold', 'completed');
end;
$$;

create or replace function public.v1_document_readable(p_document_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_classification text;
  v_links_readable boolean;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select classification into v_classification from public.v1_documents
  where id = p_document_id;
  if v_classification is null then return false; end if;

  select count(*) > 0 and bool_and(
    public.v1_document_target_readable(link.entity_type, link.entity_id)
  )
  into v_links_readable
  from public.v1_document_links link
  where link.document_id = p_document_id
    and link.removed_at is null;

  if not coalesce(v_links_readable, false) then return false; end if;
  return case v_classification
    when 'operational' then true
    when 'commercial' then public.v1_has_capability('view_commercials')
    when 'admin_restricted' then public.v1_current_role() = 'admin'
    else false
  end;
end;
$$;

create or replace function public.v1_document_writable(p_document_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_classification text;
  v_project_count integer;
begin
  select classification into v_classification from public.v1_documents
  where id = p_document_id;
  if v_classification is null
    or not public.v1_document_readable(p_document_id)
    or not public.v1_document_classification_writable(v_classification) then
    return false;
  end if;
  select count(distinct project_id) into v_project_count
  from public.v1_document_links
  where document_id = p_document_id and removed_at is null;
  return v_project_count <= 1 or public.v1_current_role() = 'admin';
end;
$$;

create or replace function public.v1_storage_upload_intent_permits(
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and public.v1_current_actor_is_active()
    and exists (
      select 1
      from public.v1_document_upload_intents intent
      where intent.object_path = p_object_path
        and intent.actor_auth_user_id = auth.uid()
        and intent.finalized_at is null
        and intent.expires_at > clock_timestamp()
    );
$$;

create or replace function public.v1_storage_document_readable(
  p_bucket_id text,
  p_object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_bucket_id = 'yorks-documents'
    and exists (
      select 1
      from public.v1_document_versions version_record
      where version_record.bucket_id = p_bucket_id
        and version_record.object_path = p_object_path
        and public.v1_document_readable(version_record.document_id)
    );
$$;

drop policy if exists v1_yorks_documents_insert_intent on storage.objects;
create policy v1_yorks_documents_insert_intent
on storage.objects for insert to authenticated
with check (
  bucket_id = 'yorks-documents'
  and public.v1_storage_upload_intent_permits(name)
);

drop policy if exists v1_yorks_documents_select_linked on storage.objects;
create policy v1_yorks_documents_select_linked
on storage.objects for select to authenticated
using (public.v1_storage_document_readable(bucket_id, name));

create or replace function public.v1_document_versions_immutable_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op <> 'INSERT' then
    raise exception 'V1_DOCUMENT_VERSION_IMMUTABLE' using errcode = '55000';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_document_versions_immutable on public.v1_document_versions;
create trigger v1_document_versions_immutable
before update or delete on public.v1_document_versions
for each row execute function public.v1_document_versions_immutable_trigger();

create or replace function public.v1_document_links_append_only_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'V1_DOCUMENT_LINK_DELETE_FORBIDDEN' using errcode = '55000';
  end if;
  if old.document_id is distinct from new.document_id
    or old.project_id is distinct from new.project_id
    or old.entity_type is distinct from new.entity_type
    or old.entity_id is distinct from new.entity_id
    or old.linked_by_auth_user_id is distinct from new.linked_by_auth_user_id
    or old.linked_by_role is distinct from new.linked_by_role
    or old.linked_at is distinct from new.linked_at
    or old.cross_project_reason is distinct from new.cross_project_reason
    or old.removed_at is not null
    or new.removed_at is null then
    raise exception 'V1_DOCUMENT_LINK_APPEND_ONLY' using errcode = '55000';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_document_links_append_only on public.v1_document_links;
create trigger v1_document_links_append_only
before update or delete on public.v1_document_links
for each row execute function public.v1_document_links_append_only_trigger();

create or replace function public.v1_prepare_document_upload(
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
  v_role text := public.v1_current_role();
  v_project_id uuid;
  v_target_project_id uuid;
  v_entity_type text;
  v_entity_id uuid;
  v_document_id uuid;
  v_document public.v1_documents%rowtype;
  v_revision integer;
  v_classification text;
  v_file_name text;
  v_mime_type text;
  v_byte_size bigint;
  v_sha256 text;
  v_origin text;
  v_source_entity_type text;
  v_source_entity_id uuid;
  v_source_revision text;
  v_intent_id uuid := gen_random_uuid();
  v_response jsonb;
  v_existing jsonb;
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'entity_type', 'entity_id', 'document_id',
      'classification', 'file_name', 'mime_type', 'byte_size', 'sha256',
      'origin', 'source_entity_type', 'source_entity_id', 'source_revision'
    ],
    'document_upload'
  );

  v_project_id := nullif(p_payload ->> 'project_id', '')::uuid;
  v_entity_type := nullif(btrim(p_payload ->> 'entity_type'), '');
  v_entity_id := nullif(p_payload ->> 'entity_id', '')::uuid;
  v_document_id := nullif(p_payload ->> 'document_id', '')::uuid;
  v_classification := nullif(btrim(p_payload ->> 'classification'), '');
  v_file_name := nullif(btrim(p_payload ->> 'file_name'), '');
  v_mime_type := nullif(btrim(p_payload ->> 'mime_type'), '');
  v_byte_size := nullif(p_payload ->> 'byte_size', '')::bigint;
  v_sha256 := lower(nullif(btrim(p_payload ->> 'sha256'), ''));
  v_origin := nullif(btrim(p_payload ->> 'origin'), '');
  v_source_entity_type := nullif(btrim(p_payload ->> 'source_entity_type'), '');
  v_source_entity_id := nullif(p_payload ->> 'source_entity_id', '')::uuid;
  v_source_revision := nullif(btrim(p_payload ->> 'source_revision'), '');

  if v_project_id is null or v_entity_type is null or v_entity_id is null
    or v_classification not in ('operational', 'commercial', 'admin_restricted')
    or v_file_name is null or length(v_file_name) > 180
    or position('/' in v_file_name) > 0 or position(chr(92) in v_file_name) > 0
    or v_mime_type not in (
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg', 'image/png'
    )
    or v_byte_size is null or v_byte_size <= 0 or v_byte_size > 6291456
    or v_sha256 is null or v_sha256 !~ '^[a-f0-9]{64}$'
    or v_origin not in ('uploaded', 'generated') then
    raise exception 'V1_DOCUMENT_UPLOAD_PAYLOAD_INVALID' using errcode = '22023';
  end if;

  if (v_origin = 'uploaded' and (
        v_source_entity_type is not null or v_source_entity_id is not null
        or v_source_revision is not null
      ))
    or (v_origin = 'generated' and (
      v_source_entity_type not in ('material_request', 'delivery_order', 'material_return')
      or v_source_entity_id is null or v_source_revision is null
    )) then
    raise exception 'V1_DOCUMENT_SOURCE_INVALID' using errcode = '22023';
  end if;

  v_target_project_id := public.v1_document_target_project_id(v_entity_type, v_entity_id);
  if v_target_project_id <> v_project_id
    or not public.v1_document_target_writable(
      v_entity_type, v_entity_id, v_classification
    ) then
    raise exception 'V1_DOCUMENT_TARGET_WRITE_DENIED' using errcode = '42501';
  end if;

  if v_origin = 'generated'
    and public.v1_document_target_project_id(
      v_source_entity_type, v_source_entity_id
    ) <> v_project_id then
    raise exception 'V1_DOCUMENT_SOURCE_PROJECT_MISMATCH' using errcode = '22023';
  end if;

  if v_document_id is not null then
    select * into v_document from public.v1_documents where id = v_document_id
    for update;
    if not found or not public.v1_document_writable(v_document_id)
      or v_document.classification <> v_classification then
      raise exception 'V1_DOCUMENT_VERSION_WRITE_DENIED' using errcode = '42501';
    end if;
    select coalesce(max(revision_number), 0) + 1 into v_revision
    from public.v1_document_versions where document_id = v_document_id;
  else
    v_revision := 1;
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_prepare_document_upload', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  insert into public.v1_document_upload_intents (
    id, project_id, target_entity_type, target_entity_id, document_id,
    planned_revision_number, classification, original_file_name, mime_type,
    byte_size, expected_sha256, origin, source_entity_type, source_entity_id,
    source_revision, object_path, actor_auth_user_id, actor_role,
    idempotency_key, expires_at
  )
  values (
    v_intent_id, v_project_id, v_entity_type, v_entity_id, v_document_id,
    v_revision, v_classification, v_file_name, v_mime_type, v_byte_size,
    v_sha256, v_origin, v_source_entity_type, v_source_entity_id,
    v_source_revision,
    'documents/' || v_project_id::text || '/' || v_intent_id::text || '/content',
    v_actor, v_role, p_idempotency_key, clock_timestamp() + interval '15 minutes'
  );

  v_response := jsonb_build_object(
    'upload_intent_id', v_intent_id,
    'bucket_id', 'yorks-documents',
    'object_path', 'documents/' || v_project_id::text || '/' || v_intent_id::text || '/content',
    'mime_type', v_mime_type,
    'byte_size', v_byte_size,
    'expires_at', clock_timestamp() + interval '15 minutes',
    'planned_revision_number', v_revision
  );
  perform public.v1_complete_idempotency(
    'v1_prepare_document_upload', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_document_upload_intent_projection(
  p_upload_intent_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_intent public.v1_document_upload_intents%rowtype;
begin
  select * into v_intent from public.v1_document_upload_intents
  where id = p_upload_intent_id;
  if not found or v_intent.actor_auth_user_id <> auth.uid()
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_DOCUMENT_UPLOAD_INTENT_READ_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'upload_intent_id', v_intent.id,
    'bucket_id', v_intent.bucket_id,
    'object_path', v_intent.object_path,
    'mime_type', v_intent.mime_type,
    'byte_size', v_intent.byte_size,
    'expires_at', v_intent.expires_at,
    'finalized_document_id', v_intent.finalized_document_id,
    'finalized_version_id', v_intent.finalized_version_id
  );
end;
$$;

create or replace function public.v1_create_document_version(
  p_upload_intent_id uuid,
  p_verified_sha256 text,
  p_verified_byte_size bigint,
  p_verified_mime_type text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_intent public.v1_document_upload_intents%rowtype;
  v_document_id uuid;
  v_version_id uuid;
  v_previous_version_id uuid;
  v_object storage.objects%rowtype;
  v_metadata_size bigint;
  v_metadata_mime text;
  v_request_hash text;
  v_response jsonb;
begin
  if coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'V1_DOCUMENT_FINALIZER_SERVICE_ONLY' using errcode = '42501';
  end if;
  select * into v_intent from public.v1_document_upload_intents
  where id = p_upload_intent_id for update;
  if not found then
    raise exception 'V1_DOCUMENT_UPLOAD_INTENT_NOT_FOUND' using errcode = '22023';
  end if;
  if v_intent.finalized_at is not null then
    return jsonb_build_object(
      'document_id', v_intent.finalized_document_id,
      'document_version_id', v_intent.finalized_version_id,
      'revision_number', v_intent.planned_revision_number
    );
  end if;
  if v_intent.expires_at <= clock_timestamp() then
    raise exception 'V1_DOCUMENT_UPLOAD_INTENT_EXPIRED' using errcode = '22023';
  end if;
  if lower(p_verified_sha256) <> v_intent.expected_sha256
    or p_verified_byte_size <> v_intent.byte_size
    or p_verified_mime_type <> v_intent.mime_type then
    raise exception 'V1_DOCUMENT_OBJECT_VERIFICATION_FAILED' using errcode = '22023';
  end if;

  select * into v_object from storage.objects
  where bucket_id = v_intent.bucket_id and name = v_intent.object_path;
  if not found or coalesce(v_object.owner_id, '') <> v_intent.actor_auth_user_id::text then
    raise exception 'V1_DOCUMENT_OBJECT_NOT_OWNED_BY_INTENT' using errcode = '42501';
  end if;
  v_metadata_size := nullif(v_object.metadata ->> 'size', '')::bigint;
  v_metadata_mime := coalesce(
    nullif(v_object.metadata ->> 'mimetype', ''),
    nullif(v_object.metadata ->> 'contentType', '')
  );
  if v_metadata_size <> v_intent.byte_size
    or v_metadata_mime <> v_intent.mime_type then
    raise exception 'V1_DOCUMENT_STORAGE_METADATA_MISMATCH' using errcode = '22023';
  end if;

  v_document_id := coalesce(v_intent.document_id, gen_random_uuid());
  if v_intent.document_id is null then
    insert into public.v1_documents (
      id, classification, created_by_auth_user_id, created_by_role
    ) values (
      v_document_id, v_intent.classification, v_intent.actor_auth_user_id,
      v_intent.actor_role
    );
  else
    select current_version_id into v_previous_version_id
    from public.v1_documents where id = v_document_id for update;
  end if;

  v_version_id := gen_random_uuid();
  insert into public.v1_document_versions (
    id, document_id, revision_number, bucket_id, object_path,
    original_file_name, mime_type, byte_size, sha256, origin,
    source_entity_type, source_entity_id, source_revision,
    uploaded_by_auth_user_id, uploaded_by_role, supersedes_version_id
  ) values (
    v_version_id, v_document_id, v_intent.planned_revision_number,
    v_intent.bucket_id, v_intent.object_path, v_intent.original_file_name,
    v_intent.mime_type, v_intent.byte_size, v_intent.expected_sha256,
    v_intent.origin, v_intent.source_entity_type, v_intent.source_entity_id,
    v_intent.source_revision, v_intent.actor_auth_user_id, v_intent.actor_role,
    v_previous_version_id
  );
  update public.v1_documents set current_version_id = v_version_id
  where id = v_document_id;
  insert into public.v1_document_links (
    id, document_id, project_id, entity_type, entity_id,
    linked_by_auth_user_id, linked_by_role
  ) values (
    gen_random_uuid(), v_document_id, v_intent.project_id,
    v_intent.target_entity_type, v_intent.target_entity_id,
    v_intent.actor_auth_user_id, v_intent.actor_role
  );
  update public.v1_document_upload_intents set
    finalized_document_id = v_document_id,
    finalized_version_id = v_version_id,
    finalized_at = clock_timestamp()
  where id = v_intent.id;

  v_response := jsonb_build_object(
    'document_id', v_document_id,
    'document_version_id', v_version_id,
    'revision_number', v_intent.planned_revision_number
  );
  update public.v1_idempotency_keys set
    response_json = response_json || v_response
  where actor_auth_user_id = v_intent.actor_auth_user_id
    and command_name = 'v1_prepare_document_upload'
    and idempotency_key = v_intent.idempotency_key;
  select request_hash into v_request_hash from public.v1_idempotency_keys
  where actor_auth_user_id = v_intent.actor_auth_user_id
    and command_name = 'v1_prepare_document_upload'
    and idempotency_key = v_intent.idempotency_key;
  insert into public.v1_audit_events (
    event_type, entity_type, entity_id, project_id, actor_auth_user_id,
    actor_role, occurred_at, idempotency_key, after_data, request_hash
  ) values (
    case when v_previous_version_id is null
      then 'document_version_created' else 'document_version_superseded' end,
    'document_version', v_version_id, v_intent.project_id,
    v_intent.actor_auth_user_id, v_intent.actor_role, clock_timestamp(),
    v_intent.idempotency_key,
    jsonb_build_object(
      'document_id', v_document_id,
      'revision_number', v_intent.planned_revision_number,
      'classification', v_intent.classification,
      'origin', v_intent.origin
    ),
    v_request_hash
  );
  return v_response;
end;
$$;

create or replace function public.v1_link_document(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_document_id uuid := nullif(p_payload ->> 'document_id', '')::uuid;
  v_entity_type text := nullif(btrim(p_payload ->> 'entity_type'), '');
  v_entity_id uuid := nullif(p_payload ->> 'entity_id', '')::uuid;
  v_reason text := nullif(btrim(p_payload ->> 'cross_project_reason'), '');
  v_project_id uuid;
  v_existing_project_id uuid;
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_link_id uuid := gen_random_uuid();
  v_existing jsonb;
  v_response jsonb;
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload, array['document_id', 'entity_type', 'entity_id', 'cross_project_reason'],
    'document_link'
  );
  if v_document_id is null or v_entity_type is null or v_entity_id is null then
    raise exception 'V1_DOCUMENT_LINK_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  if not public.v1_document_writable(v_document_id) then
    raise exception 'V1_DOCUMENT_LINK_WRITE_DENIED' using errcode = '42501';
  end if;
  select project_id into v_existing_project_id from public.v1_document_links
  where document_id = v_document_id and removed_at is null
  order by linked_at limit 1;
  v_project_id := public.v1_document_target_project_id(v_entity_type, v_entity_id);
  if not public.v1_document_target_writable(
    v_entity_type, v_entity_id,
    (select classification from public.v1_documents where id = v_document_id)
  ) then
    raise exception 'V1_DOCUMENT_LINK_TARGET_WRITE_DENIED' using errcode = '42501';
  end if;
  if v_existing_project_id <> v_project_id
    and (v_role <> 'admin' or v_reason is null) then
    raise exception 'V1_DOCUMENT_CROSS_PROJECT_LINK_REQUIRES_ADMIN_REASON'
      using errcode = '42501';
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_link_document', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  insert into public.v1_document_links (
    id, document_id, project_id, entity_type, entity_id,
    linked_by_auth_user_id, linked_by_role, cross_project_reason
  ) values (
    v_link_id, v_document_id, v_project_id, v_entity_type, v_entity_id,
    v_actor, v_role,
    case when v_existing_project_id <> v_project_id then v_reason end
  );
  v_response := jsonb_build_object('document_link_id', v_link_id, 'document_id', v_document_id);
  perform public.v1_complete_idempotency('v1_link_document', p_idempotency_key, v_response);
  perform public.v1_write_audit_event(
    'document_linked', 'document_link', v_link_id, v_project_id, null,
    jsonb_build_object('document_id', v_document_id, 'entity_type', v_entity_type),
    case when v_existing_project_id <> v_project_id then v_reason else null end,
    p_idempotency_key
  );
  return v_response;
end;
$$;

create or replace function public.v1_remove_document_link(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_link_id uuid := nullif(p_payload ->> 'document_link_id', '')::uuid;
  v_reason text := nullif(btrim(p_payload ->> 'reason'), '');
  v_link public.v1_document_links%rowtype;
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_existing jsonb;
  v_response jsonb;
begin
  if v_actor is null or v_role = '' or not public.v1_current_actor_is_active() then
    raise exception 'V1_ACTIVE_ACTOR_REQUIRED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload, array['document_link_id', 'reason'], 'document_link_removal'
  );
  if v_link_id is null or v_reason is null then
    raise exception 'V1_DOCUMENT_LINK_REMOVAL_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_link from public.v1_document_links where id = v_link_id
  for update;
  if not found or v_link.removed_at is not null
    or not public.v1_document_writable(v_link.document_id)
    or not public.v1_document_target_writable(
      v_link.entity_type, v_link.entity_id,
      (select classification from public.v1_documents where id = v_link.document_id)
    ) then
    raise exception 'V1_DOCUMENT_LINK_REMOVAL_DENIED' using errcode = '42501';
  end if;
  if (select count(*) from public.v1_document_links
      where document_id = v_link.document_id and removed_at is null) <= 1 then
    raise exception 'V1_DOCUMENT_LAST_LINK_REMOVAL_FORBIDDEN' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_remove_document_link', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  update public.v1_document_links set
    removed_by_auth_user_id = v_actor,
    removed_by_role = v_role,
    removed_at = clock_timestamp(),
    removal_reason = v_reason
  where id = v_link.id;
  v_response := jsonb_build_object('document_link_id', v_link.id, 'removed', true);
  perform public.v1_complete_idempotency(
    'v1_remove_document_link', p_idempotency_key, v_response
  );
  perform public.v1_write_audit_event(
    'document_link_removed', 'document_link', v_link.id, v_link.project_id,
    null, jsonb_build_object('document_id', v_link.document_id), v_reason,
    p_idempotency_key
  );
  return v_response;
end;
$$;

create or replace function public.v1_project_audit_projection(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_AUDIT_PROJECTION_READ_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', audit.id,
        'event_type', audit.event_type,
        'entity_type', audit.entity_type,
        'entity_id', audit.entity_id,
        'occurred_at', audit.occurred_at,
        'actor_auth_user_id', audit.actor_auth_user_id,
        'actor_display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
        'actor_role', audit.actor_role,
        'reason', audit.reason
      ) order by audit.occurred_at desc, audit.id desc
    )
    from public.v1_audit_events audit
    join public.v1_profiles profile on profile.auth_user_id = audit.actor_auth_user_id
    where audit.project_id = p_project_id
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_document_workspace_projection(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_DOCUMENT_WORKSPACE_READ_DENIED' using errcode = '42501';
  end if;
  return jsonb_build_object(
    'project_id', p_project_id,
    'documents', coalesce((
      select jsonb_agg(document_projection order by document_uploaded_at desc)
      from (
        select jsonb_build_object(
          'id', document_record.id,
          'classification', document_record.classification,
          'created_at', document_record.created_at,
          'current_version', jsonb_build_object(
            'id', version_record.id,
            'revision_number', version_record.revision_number,
            'bucket_id', version_record.bucket_id,
            'object_path', version_record.object_path,
            'original_file_name', version_record.original_file_name,
            'mime_type', version_record.mime_type,
            'byte_size', version_record.byte_size,
            'sha256', version_record.sha256,
            'origin', version_record.origin,
            'source_entity_type', version_record.source_entity_type,
            'source_entity_id', version_record.source_entity_id,
            'source_revision', version_record.source_revision,
            'uploaded_at', version_record.uploaded_at,
            'uploaded_by_auth_user_id', version_record.uploaded_by_auth_user_id,
            'uploaded_by_role', version_record.uploaded_by_role,
            'uploaded_by_display_name', public.v1_safe_profile_display_name(
              profile.display_name, profile.auth_user_id
            )
          ),
          'links', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', link.id,
              'project_id', link.project_id,
              'entity_type', link.entity_type,
              'entity_id', link.entity_id,
              'linked_at', link.linked_at,
              'cross_project_reason', link.cross_project_reason
            ) order by link.linked_at asc)
            from public.v1_document_links link
            where link.document_id = document_record.id and link.removed_at is null
          ), '[]'::jsonb)
        ) as document_projection,
        version_record.uploaded_at as document_uploaded_at
        from public.v1_documents document_record
        join public.v1_document_versions version_record
          on version_record.id = document_record.current_version_id
        join public.v1_profiles profile
          on profile.auth_user_id = version_record.uploaded_by_auth_user_id
        where exists (
          select 1 from public.v1_document_links project_link
          where project_link.document_id = document_record.id
            and project_link.project_id = p_project_id
            and project_link.removed_at is null
        )
          and public.v1_document_readable(document_record.id)
      ) documents
    ), '[]'::jsonb),
    'audit_entries', public.v1_project_audit_projection(p_project_id)
  );
end;
$$;

revoke all on function public.v1_document_target_project_id(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_target_readable(text, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_classification_writable(text)
  from public, anon, authenticated;
revoke all on function public.v1_document_target_writable(text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.v1_document_readable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_writable(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_storage_upload_intent_permits(text)
  from public, anon, authenticated;
revoke all on function public.v1_storage_document_readable(text, text)
  from public, anon, authenticated;
revoke all on function public.v1_document_versions_immutable_trigger()
  from public, anon, authenticated;
revoke all on function public.v1_document_links_append_only_trigger()
  from public, anon, authenticated;
revoke all on function public.v1_prepare_document_upload(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_upload_intent_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_create_document_version(uuid, text, bigint, text)
  from public, anon, authenticated;
revoke all on function public.v1_link_document(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_remove_document_link(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_project_audit_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_document_workspace_projection(uuid)
  from public, anon, authenticated;

grant execute on function public.v1_storage_upload_intent_permits(text)
  to authenticated;
grant execute on function public.v1_storage_document_readable(text, text)
  to authenticated;
grant execute on function public.v1_prepare_document_upload(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_document_upload_intent_projection(uuid)
  to authenticated;
grant execute on function public.v1_link_document(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_remove_document_link(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_project_audit_projection(uuid)
  to authenticated;
grant execute on function public.v1_document_workspace_projection(uuid)
  to authenticated;
grant execute on function public.v1_create_document_version(uuid, text, bigint, text)
  to service_role;
