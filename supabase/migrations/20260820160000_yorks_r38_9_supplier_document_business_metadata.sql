-- Yorks R38.9: controlled supplier-document business metadata.
--
-- This migration is deliberately additive. Existing supplier document
-- versions remain readable with null business metadata; no historical type,
-- reference, or note is inferred. New supplier uploads persist normalized
-- metadata beside the upload intent and copy the exact snapshot to the
-- immutable document version in the same transaction as finalization.
--
-- Rollback: the client may stop sending the three supplier metadata keys and
-- this migration's replacement RPC/trigger/tables may be removed. Storage
-- objects, controlled documents, versions, links, and historical audit events
-- are not changed or deleted by this migration.

create table if not exists public.v1_supplier_document_upload_metadata (
  upload_intent_id uuid primary key
    references public.v1_document_upload_intents (id) on delete restrict,
  supplier_id uuid not null
    references public.v1_suppliers (id) on delete restrict,
  supplier_document_type text not null check (supplier_document_type in (
    'delivery_note', 'invoice', 'packing_list',
    'product_data_sheet', 'other'
  )),
  business_reference text,
  notes text,
  created_at timestamptz not null default clock_timestamp(),
  check (
    business_reference is null
    or (
      business_reference = btrim(business_reference)
      and business_reference <> ''
      and length(business_reference) <= 180
    )
  ),
  check (
    supplier_document_type not in ('delivery_note', 'invoice')
    or business_reference is not null
  ),
  check (
    notes is null
    or (
      notes = btrim(notes)
      and notes <> ''
      and length(notes) <= 1000
    )
  )
);

create index if not exists v1_supplier_document_upload_metadata_supplier_idx
  on public.v1_supplier_document_upload_metadata (supplier_id, created_at desc);

create table if not exists public.v1_supplier_document_version_metadata (
  document_version_id uuid primary key
    references public.v1_document_versions (id) on delete restrict,
  upload_intent_id uuid not null unique
    references public.v1_document_upload_intents (id) on delete restrict,
  document_id uuid not null
    references public.v1_documents (id) on delete restrict,
  supplier_id uuid not null
    references public.v1_suppliers (id) on delete restrict,
  supplier_document_type text not null check (supplier_document_type in (
    'delivery_note', 'invoice', 'packing_list',
    'product_data_sheet', 'other'
  )),
  business_reference text,
  notes text,
  created_at timestamptz not null default clock_timestamp(),
  check (
    business_reference is null
    or (
      business_reference = btrim(business_reference)
      and business_reference <> ''
      and length(business_reference) <= 180
    )
  ),
  check (
    supplier_document_type not in ('delivery_note', 'invoice')
    or business_reference is not null
  ),
  check (
    notes is null
    or (
      notes = btrim(notes)
      and notes <> ''
      and length(notes) <= 1000
    )
  )
);

create index if not exists v1_supplier_document_version_metadata_document_idx
  on public.v1_supplier_document_version_metadata (
    document_id, created_at desc, document_version_id
  );
create index if not exists v1_supplier_document_version_metadata_supplier_idx
  on public.v1_supplier_document_version_metadata (
    supplier_id, created_at desc, document_version_id
  );

alter table public.v1_supplier_document_upload_metadata enable row level security;
alter table public.v1_supplier_document_version_metadata enable row level security;

revoke all on table public.v1_supplier_document_upload_metadata
  from public, anon, authenticated;
revoke all on table public.v1_supplier_document_version_metadata
  from public, anon, authenticated;
grant all on table public.v1_supplier_document_upload_metadata to service_role;
grant all on table public.v1_supplier_document_version_metadata to service_role;

create or replace function public.v1_supplier_document_metadata_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'V1_SUPPLIER_DOCUMENT_METADATA_IMMUTABLE'
    using errcode = '42501';
end;
$$;

drop trigger if exists v1_supplier_document_version_metadata_immutable
  on public.v1_supplier_document_version_metadata;
create trigger v1_supplier_document_version_metadata_immutable
before update or delete on public.v1_supplier_document_version_metadata
for each row execute function public.v1_supplier_document_metadata_immutable();

create or replace function public.v1_finalize_supplier_document_metadata()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_metadata public.v1_supplier_document_upload_metadata%rowtype;
  v_document_id uuid;
begin
  if new.finalized_version_id is null
    or old.finalized_version_id is not null then
    return new;
  end if;

  select * into v_metadata
  from public.v1_supplier_document_upload_metadata metadata
  where metadata.upload_intent_id = new.id;
  if not found then
    return new;
  end if;

  if new.target_entity_type not in ('supplier', 'supplier_receipt_batch')
    or (
      new.target_entity_type = 'supplier'
      and new.target_entity_id <> v_metadata.supplier_id
    )
    or (
      new.target_entity_type = 'supplier_receipt_batch'
      and not exists (
        select 1
        from public.v1_supplier_receipt_batches receipt_batch
        where receipt_batch.id = new.target_entity_id
          and receipt_batch.supplier_id = v_metadata.supplier_id
      )
    ) then
    raise exception 'V1_SUPPLIER_DOCUMENT_METADATA_TARGET_MISMATCH'
      using errcode = '22023';
  end if;

  select version_record.document_id into v_document_id
  from public.v1_document_versions version_record
  where version_record.id = new.finalized_version_id;
  if not found or v_document_id <> new.finalized_document_id then
    raise exception 'V1_SUPPLIER_DOCUMENT_METADATA_VERSION_MISMATCH'
      using errcode = '22023';
  end if;

  insert into public.v1_supplier_document_version_metadata (
    document_version_id, upload_intent_id, document_id, supplier_id,
    supplier_document_type, business_reference, notes
  ) values (
    new.finalized_version_id, new.id, v_document_id, v_metadata.supplier_id,
    v_metadata.supplier_document_type, v_metadata.business_reference,
    v_metadata.notes
  );
  return new;
end;
$$;

drop trigger if exists v1_finalize_supplier_document_metadata
  on public.v1_document_upload_intents;
create trigger v1_finalize_supplier_document_metadata
after update of finalized_version_id on public.v1_document_upload_intents
for each row execute function public.v1_finalize_supplier_document_metadata();

create or replace function public.v1_prepare_supplier_document_upload(
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
  v_supplier_id uuid;
  v_entity_type text;
  v_entity_id uuid;
  v_document_id uuid;
  v_document public.v1_documents%rowtype;
  v_previous_metadata public.v1_supplier_document_version_metadata%rowtype;
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
  v_supplier_document_type text;
  v_business_reference text;
  v_notes text;
  v_intent_id uuid := gen_random_uuid();
  v_expires_at timestamptz := clock_timestamp() + interval '15 minutes';
  v_object_path text;
  v_response jsonb;
  v_existing jsonb;
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'entity_type', 'entity_id', 'document_id',
      'classification', 'file_name', 'mime_type', 'byte_size', 'sha256',
      'origin', 'source_entity_type', 'source_entity_id', 'source_revision',
      'supplier_document_type', 'business_reference',
      'supplier_document_notes'
    ],
    'supplier_document_upload'
  );
  begin
    v_supplier_id := nullif(p_payload ->> 'project_id', '')::uuid;
    v_entity_id := nullif(p_payload ->> 'entity_id', '')::uuid;
    v_document_id := nullif(p_payload ->> 'document_id', '')::uuid;
    v_byte_size := nullif(p_payload ->> 'byte_size', '')::bigint;
    v_source_entity_id := nullif(p_payload ->> 'source_entity_id', '')::uuid;
  exception when others then
    raise exception 'V1_SUPPLIER_DOCUMENT_UPLOAD_PAYLOAD_INVALID'
      using errcode = '22023';
  end;
  v_entity_type := nullif(btrim(p_payload ->> 'entity_type'), '');
  v_classification := nullif(btrim(p_payload ->> 'classification'), '');
  v_file_name := nullif(btrim(p_payload ->> 'file_name'), '');
  v_mime_type := nullif(btrim(p_payload ->> 'mime_type'), '');
  v_sha256 := lower(nullif(btrim(p_payload ->> 'sha256'), ''));
  v_origin := nullif(btrim(p_payload ->> 'origin'), '');
  v_source_entity_type := nullif(btrim(p_payload ->> 'source_entity_type'), '');
  v_source_revision := nullif(btrim(p_payload ->> 'source_revision'), '');
  v_supplier_document_type := lower(nullif(
    btrim(p_payload ->> 'supplier_document_type'), ''
  ));
  v_business_reference := nullif(
    btrim(p_payload ->> 'business_reference'), ''
  );
  v_notes := nullif(btrim(p_payload ->> 'supplier_document_notes'), '');

  if v_supplier_id is null
    or v_entity_type not in ('supplier', 'supplier_receipt_batch')
    or v_entity_id is null
    or v_classification not in (
      'operational', 'commercial', 'admin_restricted'
    )
    or v_file_name is null or length(v_file_name) > 180
    or position('/' in v_file_name) > 0 or position(chr(92) in v_file_name) > 0
    or v_mime_type not in (
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg', 'image/png'
    )
    or v_byte_size is null or v_byte_size <= 0 or v_byte_size > 20971520
    or v_sha256 is null or v_sha256 !~ '^[a-f0-9]{64}$'
    or v_origin <> 'uploaded'
    or v_source_entity_type is not null or v_source_entity_id is not null
    or v_source_revision is not null
    or v_supplier_document_type is null
    or v_supplier_document_type not in (
      'delivery_note', 'invoice', 'packing_list',
      'product_data_sheet', 'other'
    )
    or length(coalesce(v_business_reference, '')) > 180
    or length(coalesce(v_notes, '')) > 1000
    or (
      v_supplier_document_type in ('delivery_note', 'invoice')
      and v_business_reference is null
    )
    or not exists(
      select 1 from public.v1_suppliers supplier
      where supplier.id = v_supplier_id
    )
    or (v_entity_type = 'supplier' and v_entity_id <> v_supplier_id)
    or (v_entity_type = 'supplier_receipt_batch' and not exists(
      select 1 from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.id = v_entity_id
        and receipt_batch.supplier_id = v_supplier_id
        and receipt_batch.state = 'committed'
    )) then
    raise exception 'V1_SUPPLIER_DOCUMENT_UPLOAD_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  if v_supplier_document_type = 'invoice'
    and v_classification <> 'commercial' then
    raise exception 'V1_SUPPLIER_DOCUMENT_CLASSIFICATION_INVALID'
      using errcode = '22023';
  end if;
  if not public.v1_document_target_writable(
    v_entity_type, v_entity_id, v_classification
  ) then
    raise exception 'V1_SUPPLIER_DOCUMENT_WRITE_DENIED' using errcode = '42501';
  end if;

  if v_document_id is not null then
    select * into v_document from public.v1_documents
    where id = v_document_id for update;
    if not found or v_document.classification <> v_classification
      or not public.v1_document_writable(v_document_id)
      or not exists (
        select 1 from public.v1_document_links link
        where link.document_id = v_document_id
          and link.entity_type = v_entity_type
          and link.entity_id = v_entity_id
          and link.removed_at is null
      ) then
      raise exception 'V1_SUPPLIER_DOCUMENT_VERSION_WRITE_DENIED'
        using errcode = '42501';
    end if;
    select coalesce(max(revision_number), 0) + 1 into v_revision
    from public.v1_document_versions where document_id = v_document_id;
    select metadata.* into v_previous_metadata
    from public.v1_supplier_document_version_metadata metadata
    where metadata.document_version_id = v_document.current_version_id;
    if found
      and v_previous_metadata.supplier_document_type <>
        v_supplier_document_type then
      raise exception 'V1_SUPPLIER_DOCUMENT_TYPE_IMMUTABLE'
        using errcode = '22023';
    end if;
  else
    v_revision := 1;
  end if;

  v_existing := public.v1_idempotency_get_or_claim(
    'v1_prepare_document_upload', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_object_path := 'documents/suppliers/' || v_supplier_id::text || '/'
    || v_intent_id::text || '/content';
  insert into public.v1_document_upload_intents (
    id, project_id, target_entity_type, target_entity_id, document_id,
    planned_revision_number, classification, original_file_name, mime_type,
    byte_size, expected_sha256, origin, source_entity_type, source_entity_id,
    source_revision, object_path, actor_auth_user_id, actor_role,
    idempotency_key, expires_at
  ) values (
    v_intent_id, null, v_entity_type, v_entity_id, v_document_id,
    v_revision, v_classification, v_file_name, v_mime_type, v_byte_size,
    v_sha256, 'uploaded', null, null, null, v_object_path,
    v_actor, v_role, p_idempotency_key, v_expires_at
  );
  insert into public.v1_supplier_document_upload_metadata (
    upload_intent_id, supplier_id, supplier_document_type,
    business_reference, notes
  ) values (
    v_intent_id, v_supplier_id, v_supplier_document_type,
    v_business_reference, v_notes
  );
  v_response := jsonb_build_object(
    'upload_intent_id', v_intent_id,
    'bucket_id', 'yorks-documents',
    'object_path', v_object_path,
    'mime_type', v_mime_type,
    'byte_size', v_byte_size,
    'expires_at', v_expires_at,
    'planned_revision_number', v_revision
  );
  perform public.v1_complete_idempotency(
    'v1_prepare_document_upload', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_supplier_document_workspace_projection(
  p_supplier_id uuid,
  p_receipt_batch_id uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_document_target_readable('supplier', p_supplier_id)
    or (p_receipt_batch_id is not null and not exists(
      select 1 from public.v1_supplier_receipt_batches receipt_batch
      where receipt_batch.id = p_receipt_batch_id
        and receipt_batch.supplier_id = p_supplier_id
    )) then
    raise exception 'V1_SUPPLIER_DOCUMENT_WORKSPACE_DENIED'
      using errcode = '42501';
  end if;
  return jsonb_build_object(
    -- The shared client calls this routing value project_id. It identifies the
    -- supplier workspace only; document links/intents persist project_id null.
    'project_id', p_supplier_id,
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
            ),
            'supplier_document_type', metadata.supplier_document_type,
            'business_reference', metadata.business_reference,
            'supplier_document_notes', metadata.notes
          ),
          'links', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', link.id,
              'project_id', p_supplier_id,
              'entity_type', link.entity_type,
              'entity_id', link.entity_id,
              'linked_at', link.linked_at,
              'cross_project_reason', link.cross_project_reason
            ) order by link.linked_at, link.id)
            from public.v1_document_links link
            where link.document_id = document_record.id
              and link.removed_at is null
              and (
                (link.entity_type = 'supplier'
                  and link.entity_id = p_supplier_id)
                or
                (link.entity_type = 'supplier_receipt_batch' and exists(
                  select 1
                  from public.v1_supplier_receipt_batches receipt_batch
                  where receipt_batch.id = link.entity_id
                    and receipt_batch.supplier_id = p_supplier_id
                ))
              )
          ), '[]'::jsonb)
        ) document_projection,
        version_record.uploaded_at document_uploaded_at
        from public.v1_documents document_record
        join public.v1_document_versions version_record
          on version_record.id = document_record.current_version_id
        join public.v1_profiles profile
          on profile.auth_user_id = version_record.uploaded_by_auth_user_id
        left join public.v1_supplier_document_version_metadata metadata
          on metadata.document_version_id = version_record.id
        where public.v1_document_readable(document_record.id)
          and exists(
            select 1 from public.v1_document_links target_link
            where target_link.document_id = document_record.id
              and target_link.removed_at is null
              and (
                (p_receipt_batch_id is null
                  and target_link.entity_type = 'supplier'
                  and target_link.entity_id = p_supplier_id)
                or
                (target_link.entity_type = 'supplier_receipt_batch'
                  and (p_receipt_batch_id is null
                    or target_link.entity_id = p_receipt_batch_id)
                  and exists(
                    select 1
                    from public.v1_supplier_receipt_batches receipt_batch
                    where receipt_batch.id = target_link.entity_id
                      and receipt_batch.supplier_id = p_supplier_id
                  ))
              )
          )
      ) documents
    ), '[]'::jsonb),
    'audit_entries', coalesce((
      select jsonb_agg(jsonb_build_object(
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
      ) order by audit.occurred_at desc, audit.id desc)
      from public.v1_audit_events audit
      join public.v1_profiles profile
        on profile.auth_user_id = audit.actor_auth_user_id
      where audit.after_data ->> 'document_id' in (
        select document_record.id::text
        from public.v1_documents document_record
        where public.v1_document_readable(document_record.id)
          and exists(
            select 1 from public.v1_document_links target_link
            where target_link.document_id = document_record.id
              and target_link.removed_at is null
              and (
                (p_receipt_batch_id is null
                  and target_link.entity_type = 'supplier'
                  and target_link.entity_id = p_supplier_id)
                or
                (target_link.entity_type = 'supplier_receipt_batch'
                  and (p_receipt_batch_id is null
                    or target_link.entity_id = p_receipt_batch_id)
                  and exists(
                    select 1
                    from public.v1_supplier_receipt_batches receipt_batch
                    where receipt_batch.id = target_link.entity_id
                      and receipt_batch.supplier_id = p_supplier_id
                  ))
              )
          )
      )
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_supplier_document_metadata_immutable()
  from public, anon, authenticated;
revoke all on function public.v1_finalize_supplier_document_metadata()
  from public, anon, authenticated;
revoke all on function public.v1_prepare_supplier_document_upload(jsonb,uuid)
  from public, anon, authenticated;
revoke all on function public.v1_supplier_document_workspace_projection(uuid,uuid)
  from public, anon, authenticated;

grant execute on function public.v1_prepare_supplier_document_upload(jsonb,uuid)
  to authenticated, service_role;
grant execute on function public.v1_supplier_document_workspace_projection(uuid,uuid)
  to authenticated, service_role;
