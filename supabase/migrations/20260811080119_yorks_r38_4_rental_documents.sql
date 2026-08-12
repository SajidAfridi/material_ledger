-- Yorks R38.4: connect rental lease files to the existing immutable Yorks
-- Documents boundary. Rental properties are deliberately not projects, so
-- their links and upload intents carry no forged project id. Existing project
-- document rows, links, versions and storage objects are unchanged.

alter table public.v1_document_links
  alter column project_id drop not null;

alter table public.v1_document_upload_intents
  alter column project_id drop not null;

alter table public.v1_document_links
  drop constraint if exists v1_document_links_entity_type_check;
alter table public.v1_document_links
  add constraint v1_document_links_entity_type_check check (entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch',
    'material_return', 'delivery_order', 'rental_property'
  ));

alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_target_entity_type_check;
alter table public.v1_document_upload_intents
  add constraint v1_document_upload_intents_target_entity_type_check check (
    target_entity_type in (
      'project', 'boq_group', 'material_request', 'dispatch',
      'material_return', 'delivery_order', 'rental_property'
    )
  );

create index if not exists v1_document_links_rental_current_idx
  on public.v1_document_links (entity_id, linked_at desc)
  where entity_type = 'rental_property' and removed_at is null;

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
    when 'rental_property' then
      return auth.uid() is not null
        and public.v1_current_actor_is_active()
        and public.v1_current_role() = 'admin'
        and exists (
          select 1 from public.v1_rental_properties property_record
          where property_record.id = p_entity_id
        );
    else
      return false;
  end case;
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
  if p_entity_type = 'rental_property' then
    return p_classification = 'commercial'
      and exists (
        select 1 from public.v1_rental_properties property_record
        where property_record.id = p_entity_id
          and not property_record.is_archived
      );
  end if;
  v_project_id := public.v1_document_target_project_id(p_entity_type, p_entity_id);
  select state into v_project_state from public.v1_projects where id = v_project_id;
  return v_project_state in ('draft', 'active', 'on_hold', 'completed');
end;
$$;

create or replace function public.v1_prepare_rental_document_upload(
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
  v_property_id uuid;
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
  v_expires_at timestamptz := clock_timestamp() + interval '15 minutes';
  v_object_path text;
  v_response jsonb;
  v_existing jsonb;
begin
  if v_actor is null or v_role <> 'admin'
    or not public.v1_current_actor_is_active() then
    raise exception 'V1_RENTAL_DOCUMENT_ADMIN_REQUIRED' using errcode = '42501';
  end if;
  perform public.v1_assert_object_keys(
    p_payload,
    array[
      'project_id', 'entity_type', 'entity_id', 'document_id',
      'classification', 'file_name', 'mime_type', 'byte_size', 'sha256',
      'origin', 'source_entity_type', 'source_entity_id', 'source_revision'
    ],
    'rental_document_upload'
  );

  -- The client model calls this field project_id. At this boundary it carries
  -- the rental property id and is never persisted as a project relationship.
  v_property_id := nullif(p_payload ->> 'project_id', '')::uuid;
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

  if v_property_id is null or v_entity_type <> 'rental_property'
    or v_entity_id is distinct from v_property_id
    or v_classification <> 'commercial'
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
    or v_source_revision is not null then
    raise exception 'V1_RENTAL_DOCUMENT_UPLOAD_PAYLOAD_INVALID'
      using errcode = '22023';
  end if;
  if not public.v1_document_target_writable(
    'rental_property', v_property_id, 'commercial'
  ) then
    raise exception 'V1_RENTAL_DOCUMENT_WRITE_DENIED' using errcode = '42501';
  end if;

  if v_document_id is not null then
    select * into v_document from public.v1_documents
    where id = v_document_id for update;
    if not found or v_document.classification <> 'commercial'
      or not public.v1_document_writable(v_document_id)
      or not exists (
        select 1 from public.v1_document_links link
        where link.document_id = v_document_id
          and link.entity_type = 'rental_property'
          and link.entity_id = v_property_id
          and link.removed_at is null
      ) then
      raise exception 'V1_RENTAL_DOCUMENT_VERSION_WRITE_DENIED'
        using errcode = '42501';
    end if;
    select coalesce(max(revision_number), 0) + 1 into v_revision
    from public.v1_document_versions where document_id = v_document_id;
  else
    v_revision := 1;
  end if;

  -- The existing finalizer completes this exact command name. Keeping it
  -- shared preserves its lost-response idempotency contract.
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_prepare_document_upload', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;

  v_object_path := 'documents/rentals/' || v_property_id::text || '/'
    || v_intent_id::text || '/content';
  insert into public.v1_document_upload_intents (
    id, project_id, target_entity_type, target_entity_id, document_id,
    planned_revision_number, classification, original_file_name, mime_type,
    byte_size, expected_sha256, origin, source_entity_type, source_entity_id,
    source_revision, object_path, actor_auth_user_id, actor_role,
    idempotency_key, expires_at
  ) values (
    v_intent_id, null, 'rental_property', v_property_id, v_document_id,
    v_revision, 'commercial', v_file_name, v_mime_type, v_byte_size,
    v_sha256, 'uploaded', null, null, null, v_object_path,
    v_actor, v_role, p_idempotency_key, v_expires_at
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

create or replace function public.v1_rental_document_workspace_projection(
  p_property_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_document_target_readable('rental_property', p_property_id) then
    raise exception 'V1_RENTAL_DOCUMENT_WORKSPACE_READ_DENIED'
      using errcode = '42501';
  end if;
  return jsonb_build_object(
    -- Preserve the shared client workspace shape without asserting that a
    -- rental property is a project in the database.
    'project_id', p_property_id,
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
              'project_id', link.entity_id,
              'entity_type', link.entity_type,
              'entity_id', link.entity_id,
              'linked_at', link.linked_at,
              'cross_project_reason', link.cross_project_reason
            ) order by link.linked_at asc)
            from public.v1_document_links link
            where link.document_id = document_record.id
              and link.removed_at is null
          ), '[]'::jsonb)
        ) as document_projection,
        version_record.uploaded_at as document_uploaded_at
        from public.v1_documents document_record
        join public.v1_document_versions version_record
          on version_record.id = document_record.current_version_id
        join public.v1_profiles profile
          on profile.auth_user_id = version_record.uploaded_by_auth_user_id
        where exists (
          select 1 from public.v1_document_links rental_link
          where rental_link.document_id = document_record.id
            and rental_link.entity_type = 'rental_property'
            and rental_link.entity_id = p_property_id
            and rental_link.removed_at is null
        )
          and public.v1_document_readable(document_record.id)
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
        select rental_link.document_id::text
        from public.v1_document_links rental_link
        where rental_link.entity_type = 'rental_property'
          and rental_link.entity_id = p_property_id
          and rental_link.removed_at is null
      )
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_prepare_rental_document_upload(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function public.v1_rental_document_workspace_projection(uuid)
  from public, anon, authenticated;

grant execute on function public.v1_prepare_rental_document_upload(jsonb, uuid)
  to authenticated, service_role;
grant execute on function public.v1_rental_document_workspace_projection(uuid)
  to authenticated, service_role;

-- Rollback: remove the two rental RPCs and rental-only index, then remove the
-- rental entity value only after proving no rental links or intents exist.
-- Project document rows and functions must not be rolled back or rewritten.
