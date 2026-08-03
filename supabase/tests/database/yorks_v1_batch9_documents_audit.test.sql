begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(30);

select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.v1_documents'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_document_versions'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_document_links'::regclass)
  and (select relrowsecurity from pg_class
    where oid = 'public.v1_document_upload_intents'::regclass),
  'Batch 9 document, version, link and upload-intent relations enable RLS'
);

select ok(
  not has_table_privilege('authenticated', 'public.v1_documents', 'insert')
  and not has_table_privilege('authenticated', 'public.v1_document_versions', 'update')
  and not has_table_privilege('authenticated', 'public.v1_document_links', 'delete')
  and not has_table_privilege('authenticated', 'public.v1_document_upload_intents', 'select')
  and has_function_privilege(
    'authenticated', 'public.v1_prepare_document_upload(jsonb,uuid)', 'execute'
  ) and not has_function_privilege(
    'authenticated', 'public.v1_create_document_version(uuid,text,bigint,text)', 'execute'
  ),
  'Clients can use the document commands but have no direct document/finalizer access'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B9-DOC-001",
      "name":"Controlled document project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"site_engineer",
        "reason":"Document reviewer"
      }],
      "buildings":[{"code":"b9a","name":"Document Building"}],
      "attachments":[]
    }'::jsonb,
    '90000000-0000-4000-8000-000000000001'::uuid
  )$$,
  'Project Engineer creates a controlled-document project'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B9-DOC-001'),
      'state', 'active', 'expected_version', 1, 'reason', 'Ready for controlled documents'
    ), '90000000-0000-4000-8000-000000000002'::uuid
  )$$,
  'The controlled-document project is active'
);

set local role postgres;
create temporary table v1_b9_targets as
select project.id as project_id,
  (select id from public.v1_boq_groups
   where project_id = project.id order by display_order limit 1) as boq_group_id
from public.v1_projects project
where project.project_ref = 'B9-DOC-001';
grant select on table v1_b9_targets to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select throws_ok(
  $$insert into public.v1_documents (
    id, classification, created_by_auth_user_id, created_by_role
  ) values (
    gen_random_uuid(), 'operational', auth.uid(), 'project_engineer'
  )$$,
  '42501', null,
  'A Project Engineer cannot bypass the document command with a direct insert'
);

select lives_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_b9_targets),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_targets),
      'document_id', null,
      'classification', 'operational',
      'file_name', 'approved_layout.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('a', 64),
      'origin', 'uploaded',
      'source_entity_type', null,
      'source_entity_id', null,
      'source_revision', null
    ), '90000000-0000-4000-8000-000000000003'::uuid
  )$$,
  'Project Engineer obtains a scoped operational upload intent'
);

set local role postgres;
create temporary table v1_b9_intent as
select id as upload_intent_id, object_path
from public.v1_document_upload_intents
where idempotency_key = '90000000-0000-4000-8000-000000000003'::uuid;
grant select on table v1_b9_intent to authenticated, service_role;

set local role authenticated;
select throws_ok(
  $$insert into storage.objects (
    bucket_id, name, owner_id, metadata
  ) values (
    'yorks-documents', 'documents/guessed/not-authorized/content', auth.uid()::text,
    '{"size":12,"mimetype":"application/pdf"}'::jsonb
  )$$,
  '42501', null,
  'Storage rejects a guessed document path without a live intent'
);

select lives_ok(
  $$insert into storage.objects (
    bucket_id, name, owner_id, metadata
  ) values (
    'yorks-documents', (select object_path from v1_b9_intent), auth.uid()::text,
    '{"size":12,"mimetype":"application/pdf"}'::jsonb
  )$$,
  'Storage accepts exactly the scoped private object path'
);

select throws_ok(
  $$select public.v1_create_document_version(
    (select upload_intent_id from v1_b9_intent), repeat('a', 64), 12, 'application/pdf'
  )$$,
  '42501', null,
  'A client cannot finalise an uploaded object or forge its hash evidence'
);

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

select lives_ok(
  $$select public.v1_create_document_version(
    (select upload_intent_id from v1_b9_intent), repeat('a', 64), 12, 'application/pdf'
  )$$,
  'The trusted finalizer verifies object metadata and creates the first immutable version'
);

select lives_ok(
  $$select public.v1_create_document_version(
    (select upload_intent_id from v1_b9_intent), repeat('a', 64), 12, 'application/pdf'
  )$$,
  'A finalizer retry returns the existing immutable version'
);

set local role postgres;
create temporary table v1_b9_document as
select finalized_document_id as document_id, finalized_version_id as version_id
from public.v1_document_upload_intents
where id = (select upload_intent_id from v1_b9_intent);
grant select on table v1_b9_document to authenticated;

select ok(
  (select count(*) = 1 from public.v1_documents)
  and (select count(*) = 1 from public.v1_document_versions)
  and (select count(*) = 1 from public.v1_document_links)
  and (select current_version_id = (select version_id from v1_b9_document)
       from public.v1_documents where id = (select document_id from v1_b9_document))
  and (select count(*) = 1 from public.v1_audit_events
       where event_type = 'document_version_created'),
  'Finalization creates one document, one immutable version, one link and one server audit event'
);

select throws_ok(
  $$update public.v1_document_versions set original_file_name = 'changed.pdf'
    where id = (select version_id from v1_b9_document)$$,
  '55000', 'V1_DOCUMENT_VERSION_IMMUTABLE',
  'An immutable document version cannot be rewritten even by a trusted direct session'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select lives_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_b9_targets),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_targets),
      'document_id', (select document_id from v1_b9_document),
      'classification', 'operational',
      'file_name', 'approved_layout_rev2.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('e', 64),
      'origin', 'uploaded',
      'source_entity_type', null,
      'source_entity_id', null,
      'source_revision', null
    ), '90000000-0000-4000-8000-000000000013'::uuid
  )$$,
  'A Project Engineer can prepare a replacement version for the same document'
);

set local role postgres;
create temporary table v1_b9_replacement_intent as
select id as upload_intent_id, object_path
from public.v1_document_upload_intents
where idempotency_key = '90000000-0000-4000-8000-000000000013'::uuid;
grant select on table v1_b9_replacement_intent to authenticated, service_role;

set local role authenticated;
select lives_ok(
  $$insert into storage.objects (
    bucket_id, name, owner_id, metadata
  ) values (
    'yorks-documents', (select object_path from v1_b9_replacement_intent), auth.uid()::text,
    '{"size":12,"mimetype":"application/pdf"}'::jsonb
  )$$,
  'Storage accepts the replacement object only through its scoped intent'
);

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select lives_ok(
  $$select public.v1_create_document_version(
    (select upload_intent_id from v1_b9_replacement_intent), repeat('e', 64), 12, 'application/pdf'
  )$$,
  'The trusted finalizer creates the replacement document version'
);

set local role postgres;
select ok(
  (select count(*) = 2 from public.v1_document_versions
   where document_id = (select document_id from v1_b9_document))
  and (select revision_number = 2 from public.v1_document_versions
       where id = (select finalized_version_id from public.v1_document_upload_intents
                   where id = (select upload_intent_id from v1_b9_replacement_intent)))
  and (select current_version_id = finalized_version_id
       from public.v1_documents document_record
       join public.v1_document_upload_intents intent
         on intent.finalized_document_id = document_record.id
       where intent.id = (select upload_intent_id from v1_b9_replacement_intent))
  and (select count(*) = 1 from public.v1_document_links
       where document_id = (select document_id from v1_b9_document)
         and removed_at is null)
  and (select count(*) = 1 from public.v1_audit_events
       where event_type = 'document_version_superseded'),
  'Replacement advances one document to revision 2 without duplicating its active link'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);

select ok(
  (select count(*) = 1 from storage.objects
   where bucket_id = 'yorks-documents'
     and name = (select object_path from v1_b9_intent)),
  'An active assigned Site Engineer can read a linked operational Storage object'
);

select lives_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_b9_targets),
      'entity_type', 'boq_group',
      'entity_id', (select boq_group_id from v1_b9_targets),
      'document_id', null,
      'classification', 'operational',
      'file_name', 'site_markups.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('b', 64),
      'origin', 'uploaded',
      'source_entity_type', null,
      'source_entity_id', null,
      'source_revision', null
    ), '90000000-0000-4000-8000-000000000004'::uuid
  )$$,
  'An assigned Site Engineer can create a scoped operational BOQ upload intent'
);

select throws_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_b9_targets),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_targets),
      'document_id', null,
      'classification', 'commercial',
      'file_name', 'costed_offer.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('c', 64),
      'origin', 'uploaded',
      'source_entity_type', null,
      'source_entity_id', null,
      'source_revision', null
    ), '90000000-0000-4000-8000-000000000005'::uuid
  )$$,
  '42501', 'V1_DOCUMENT_TARGET_WRITE_DENIED',
  'An Engineer without commercial capability cannot create a commercial document intent'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000003","role":"authenticated","app_metadata":{"role":"procurement","app_user_id":"usr-local-procurement"}}',
  true
);

select lives_ok(
  $$select public.v1_prepare_document_upload(
    jsonb_build_object(
      'project_id', (select project_id from v1_b9_targets),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_targets),
      'document_id', null,
      'classification', 'commercial',
      'file_name', 'supplier_comparison.pdf',
      'mime_type', 'application/pdf',
      'byte_size', 12,
      'sha256', repeat('d', 64),
      'origin', 'uploaded',
      'source_entity_type', null,
      'source_entity_id', null,
      'source_revision', null
    ), '90000000-0000-4000-8000-000000000006'::uuid
  )$$,
  'Procurement with commercial capability can prepare a commercial document'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_create_project(
    '{
      "project_ref":"B9-DOC-002",
      "name":"Second document project",
      "parties":{},
      "initial_members":[{
        "auth_user_id":"10000000-0000-4000-8000-000000000002",
        "project_role":"project_engineer",
        "reason":"Independent project authority for access-isolation test"
      }],
      "buildings":[{"code":"b9b","name":"Second Building"}],
      "attachments":[]
    }'::jsonb,
    '90000000-0000-4000-8000-000000000007'::uuid
  )$$,
  'A second project exists for cross-project document-link enforcement'
);

select lives_ok(
  $$select public.v1_set_project_state(
    jsonb_build_object(
      'project_id', (select id from public.v1_projects where project_ref = 'B9-DOC-002'),
      'state', 'active', 'expected_version', 1, 'reason', 'Ready for authorised cross-link test'
    ), '90000000-0000-4000-8000-000000000008'::uuid
  )$$,
  'The second project is active'
);

set local role postgres;
create temporary table v1_b9_second_project as
select id as project_id from public.v1_projects where project_ref = 'B9-DOC-002';
grant select on table v1_b9_second_project to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_link_document(
    jsonb_build_object(
      'document_id', (select document_id from v1_b9_document),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_second_project),
      'cross_project_reason', null
    ), '90000000-0000-4000-8000-000000000009'::uuid
  )$$,
  '42501', 'V1_DOCUMENT_CROSS_PROJECT_LINK_REQUIRES_ADMIN_REASON',
  'Even an Admin must supply a reason before creating a cross-project document link'
);

select lives_ok(
  $$select public.v1_link_document(
    jsonb_build_object(
      'document_id', (select document_id from v1_b9_document),
      'entity_type', 'project',
      'entity_id', (select project_id from v1_b9_second_project),
      'cross_project_reason', 'Shared authority-approved commissioning record'
    ), '90000000-0000-4000-8000-000000000010'::uuid
  )$$,
  'Admin can create a reasoned cross-project document link'
);

set local role postgres;
create temporary table v1_b9_cross_link as
select id as document_link_id from public.v1_document_links
where document_id = (select document_id from v1_b9_document)
  and project_id = (select project_id from v1_b9_second_project)
  and removed_at is null;
grant select on table v1_b9_cross_link to authenticated;

select ok(
  (select cross_project_reason = 'Shared authority-approved commissioning record'
   from public.v1_document_links
   where id = (select document_link_id from v1_b9_cross_link))
  and (select count(*) = 1 from public.v1_audit_events
       where event_type = 'document_linked'),
  'The cross-project link stores its reason and one server-generated audit event'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',
  true
);

select ok(
  (public.v1_document_workspace_projection((select project_id from v1_b9_targets))
    -> 'documents') = '[]'::jsonb,
  'A reader must be authorised for every current link; the original Engineer loses the shared document projection'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select lives_ok(
  $$select public.v1_remove_document_link(
    jsonb_build_object(
      'document_link_id', (select document_link_id from v1_b9_cross_link),
      'reason', 'Cross-project reference no longer needed'
    ), '90000000-0000-4000-8000-000000000011'::uuid
  )$$,
  'Admin removes a non-final document link through an auditable soft-removal command'
);

set local role postgres;
create temporary table v1_b9_remaining_link as
select id as document_link_id from public.v1_document_links
where document_id = (select document_id from v1_b9_document)
  and removed_at is null;
grant select on table v1_b9_remaining_link to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin","app_user_id":"usr-local-admin"}}',
  true
);

select throws_ok(
  $$select public.v1_remove_document_link(
    jsonb_build_object(
      'document_link_id', (select document_link_id from v1_b9_remaining_link),
      'reason', 'Attempt to remove final link'
    ), '90000000-0000-4000-8000-000000000012'::uuid
  )$$,
  '22023', 'V1_DOCUMENT_LAST_LINK_REMOVAL_FORBIDDEN',
  'The final current link cannot be removed and orphan a controlled document'
);

select ok(
  not (public.v1_project_audit_projection((select project_id from v1_b9_second_project))::text
    like '%after_data%')
  and public.v1_project_audit_projection((select project_id from v1_b9_second_project))::text
    like '%document_link_removed%',
  'The audit projection is a safe event envelope and link removal is server-audited'
);

select * from finish();
rollback;
