-- Raise the controlled-document ceiling from 6 MiB to 20 MiB so project
-- creation and the Documents workspace share the approved product boundary.
-- Existing objects and immutable versions are unchanged. Rollback is safe only
-- when no stored version exceeds 6 MiB; restore the former bucket, constraint
-- and function bound after checking that condition.

update storage.buckets
set file_size_limit = 20971520
where id = 'yorks-documents';

alter table public.v1_document_versions
  drop constraint if exists v1_document_versions_byte_size_check;

alter table public.v1_document_versions
  add constraint v1_document_versions_byte_size_check
  check (byte_size > 0 and byte_size <= 20971520);

do $$
declare
  v_definition text;
  v_updated text;
begin
  select pg_get_functiondef(
    'public.v1_prepare_document_upload(jsonb,uuid)'::regprocedure
  ) into v_definition;

  v_updated := replace(
    v_definition,
    'v_byte_size > 6291456',
    'v_byte_size > 20971520'
  );

  if v_updated = v_definition
    and position('v_byte_size > 20971520' in v_definition) = 0 then
    raise exception 'V1_DOCUMENT_UPLOAD_LIMIT_MIGRATION_SOURCE_MISMATCH';
  end if;

  execute v_updated;
end;
$$;
