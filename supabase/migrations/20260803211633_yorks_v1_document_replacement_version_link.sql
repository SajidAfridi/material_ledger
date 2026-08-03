-- Yorks V1 R35: an existing controlled document already owns its active link.
-- A replacement creates a new immutable version and advances current_version,
-- but must not attempt to insert the same current document-link a second time.
-- This is additive: historical links and versions remain untouched.

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

  -- A replacement keeps the original active link. Reinserting that link would
  -- violate v1_document_links_one_current_target_idx and leave the new version
  -- unfinalized. New documents still receive their initial immutable link.
  if v_intent.document_id is null then
    insert into public.v1_document_links (
      id, document_id, project_id, entity_type, entity_id,
      linked_by_auth_user_id, linked_by_role
    ) values (
      gen_random_uuid(), v_document_id, v_intent.project_id,
      v_intent.target_entity_type, v_intent.target_entity_id,
      v_intent.actor_auth_user_id, v_intent.actor_role
    );
  end if;
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
