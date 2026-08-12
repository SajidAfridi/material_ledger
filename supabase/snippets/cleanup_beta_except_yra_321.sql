-- Yorks V1 beta presentation cleanup.
--
-- Keeps only the exact YRA-321 project, including its project setup, BOQ,
-- team, parties and project-level attachment. Deletes every MR/workflow row,
-- every inventory item and all other projects.
--
-- IMPORTANT:
-- 1. Run only against the yorks-godownpro-demo project from a trusted SQL
--    Editor/server session.
-- 2. Before this transaction, delete Storage objects through the Storage API;
--    keep only paths under:
--      documents/5387a162-31dd-4523-92b5-dd91d71612a6/
--    Never delete directly from storage.objects because that orphans files.
-- 3. This script is intentionally non-repeatable. Its seven-project guard
--    prevents accidental reuse after the cleanup or against another dataset.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

-- Freeze the roots that can create new dependent rows during the cleanup.
lock table
  public.v1_projects,
  public.v1_material_requests,
  public.v1_inventory_items,
  public.v1_document_upload_intents,
  public.v1_document_links,
  public.v1_documents,
  public.v1_document_versions
in access exclusive mode;

create temporary table cleanup_keep_project (
  id uuid primary key
) on commit drop;

insert into cleanup_keep_project (id)
select id
from public.v1_projects
where id = '5387a162-31dd-4523-92b5-dd91d71612a6'::uuid
  and regexp_replace(lower(btrim(project_ref)), '[^a-z0-9]+', '', 'g') =
      'yra321';

do $$
begin
  if (select count(*) from cleanup_keep_project) <> 1 then
    raise exception
      'Cleanup aborted: exact retained project YRA-321 was not found';
  end if;

  if (select count(*) from public.v1_projects) <> 7 then
    raise exception
      'Cleanup aborted: expected the reviewed seven-project beta dataset';
  end if;
end
$$;

create temporary table cleanup_delete_projects (
  id uuid primary key
) on commit drop;

insert into cleanup_delete_projects (id)
select id
from public.v1_projects
where id not in (select id from cleanup_keep_project);

do $$
begin
  if (select count(*) from cleanup_delete_projects) <> 6 then
    raise exception
      'Cleanup aborted: expected exactly six projects to delete';
  end if;
end
$$;

-- Capture every entity whose workflow or inventory history is being removed.
create temporary table cleanup_entities (
  entity_type text not null,
  id uuid not null,
  primary key (entity_type, id)
) on commit drop;

insert into cleanup_entities select 'material_request', id
from public.v1_material_requests;
insert into cleanup_entities select 'material_request_line', id
from public.v1_material_request_lines;
insert into cleanup_entities select 'procurement_arrangement', id
from public.v1_procurement_arrangements;
insert into cleanup_entities select 'procurement_arrangement_line', id
from public.v1_procurement_arrangement_lines;
insert into cleanup_entities select 'dispatch', id
from public.v1_material_dispatches;
insert into cleanup_entities select 'dispatch_line', id
from public.v1_material_dispatch_lines;
insert into cleanup_entities select 'receipt_review', id
from public.v1_receipt_reviews;
insert into cleanup_entities select 'receipt_review_line', id
from public.v1_receipt_review_lines;
insert into cleanup_entities select 'delivery_order', id
from public.v1_delivery_orders;
insert into cleanup_entities select 'delivery_order_revision', id
from public.v1_delivery_order_revisions;
insert into cleanup_entities select 'delivery_order_revision_line', id
from public.v1_delivery_order_revision_lines;
insert into cleanup_entities select 'material_return', id
from public.v1_material_returns;
insert into cleanup_entities select 'material_return_line', id
from public.v1_material_return_lines;
insert into cleanup_entities select 'inventory_item', id
from public.v1_inventory_items;
insert into cleanup_entities select 'inventory_import', id
from public.v1_inventory_import_batches;

-- Identify documents connected to deleted projects or deleted workflows.
create temporary table cleanup_candidate_documents (
  document_id uuid primary key
) on commit drop;

insert into cleanup_candidate_documents (document_id)
select distinct link.document_id
from public.v1_document_links link
where link.project_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = link.entity_id
   )
on conflict do nothing;

insert into cleanup_candidate_documents (document_id)
select distinct version.document_id
from public.v1_document_versions version
where version.source_entity_id is not null
  and exists (
    select 1
    from cleanup_entities entity
    where entity.id = version.source_entity_id
  )
on conflict do nothing;

insert into cleanup_candidate_documents (document_id)
select distinct intent.document_id
from public.v1_document_upload_intents intent
where intent.document_id is not null
  and (
    intent.project_id in (select id from cleanup_delete_projects)
    or exists (
      select 1 from cleanup_entities entity
      where entity.id = intent.target_entity_id
         or entity.id = intent.source_entity_id
    )
  )
on conflict do nothing;

insert into cleanup_candidate_documents (document_id)
select distinct intent.finalized_document_id
from public.v1_document_upload_intents intent
where intent.finalized_document_id is not null
  and (
    intent.project_id in (select id from cleanup_delete_projects)
    or exists (
      select 1 from cleanup_entities entity
      where entity.id = intent.target_entity_id
         or entity.id = intent.source_entity_id
    )
  )
on conflict do nothing;

-- Remove upload intents for deleted projects/workflows while preserving the
-- retained YRA-321 project attachment intent.
delete from public.v1_document_upload_intents intent
where intent.project_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = intent.target_entity_id
        or entity.id = intent.source_entity_id
   );

-- These three triggers enforce normal immutable history. They are bypassed
-- only inside this reviewed beta-reset transaction.
alter table public.v1_document_links
  disable trigger v1_document_links_append_only;
alter table public.v1_document_versions
  disable trigger v1_document_versions_immutable;
alter table public.v1_audit_events
  disable trigger v1_audit_events_append_only;

delete from public.v1_document_links link
where link.project_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = link.entity_id
   );

create temporary table cleanup_orphan_documents (
  document_id uuid primary key
) on commit drop;

insert into cleanup_orphan_documents (document_id)
select candidate.document_id
from cleanup_candidate_documents candidate
where not exists (
  select 1
  from public.v1_document_links link
  where link.document_id = candidate.document_id
);

delete from public.v1_document_upload_intents intent
where intent.document_id in (select document_id from cleanup_orphan_documents)
   or intent.finalized_document_id in (
     select document_id from cleanup_orphan_documents
   )
   or intent.finalized_version_id in (
     select version.id
     from public.v1_document_versions version
     where version.document_id in (
       select document_id from cleanup_orphan_documents
     )
   );

update public.v1_documents document
set current_version_id = null
where document.id in (select document_id from cleanup_orphan_documents);

update public.v1_document_versions version
set supersedes_version_id = null
where version.document_id in (
  select document_id from cleanup_orphan_documents
);

delete from public.v1_document_versions version
where version.document_id in (
  select document_id from cleanup_orphan_documents
);

delete from public.v1_documents document
where document.id in (select document_id from cleanup_orphan_documents);

-- Remove notifications tied to deleted projects or any deleted workflow row.
delete from public.v1_notifications notification
where notification.project_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = notification.entity_id
   );

-- Remove only audit rows whose owning project/entity is being deleted.
delete from public.v1_audit_events audit
where audit.project_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = audit.entity_id
   )
   or audit.entity_type in ('inventory_item', 'inventory_import');

delete from public.v1_reconciliation_issues issue
where issue.resulting_v1_id in (select id from cleanup_delete_projects)
   or exists (
     select 1
     from cleanup_entities entity
     where entity.id = issue.resulting_v1_id
   );

-- Remove all critical workflow and inventory records, including those that
-- belonged to YRA-321. Inventory categories/aliases remain as configuration.
truncate table
  public.v1_delivery_order_revision_lines,
  public.v1_material_return_lines,
  public.v1_delivery_order_revisions,
  public.v1_delivery_orders,
  public.v1_receipt_review_lines,
  public.v1_material_returns,
  public.v1_receipt_reviews,
  public.v1_material_dispatch_lines,
  public.v1_inventory_reservations,
  public.v1_material_request_line_approvals,
  public.v1_arrangement_decisions,
  public.v1_material_dispatches,
  public.v1_procurement_arrangement_lines,
  public.v1_procurement_arrangements,
  public.v1_material_request_line_commercials,
  public.v1_material_request_lines,
  public.v1_material_requests,
  public.v1_material_request_reference_counters,
  public.v1_dispatch_reference_counters,
  public.v1_return_reference_counters,
  public.v1_inventory_import_rows,
  public.v1_inventory_import_batches,
  public.v1_inventory_movements,
  public.v1_inventory_balances,
  public.v1_inventory_items
restart identity;

-- Old workflow/inventory retries must not return references to deleted rows.
delete from public.v1_idempotency_keys
where command_name in (
  'v1_adjust_inventory',
  'v1_adjust_inventory_stock',
  'v1_begin_arrangement',
  'v1_cancel_material_request',
  'v1_confirm_material_return',
  'v1_confirm_receipt',
  'v1_create_inventory_item',
  'v1_decide_arrangement',
  'v1_dispatch_materials',
  'v1_generate_delivery_order',
  'v1_import_inventory',
  'v1_reject_material_return',
  'v1_save_and_submit_material_request',
  'v1_save_arrangement',
  'v1_submit_material_request',
  'v1_submit_material_return',
  'v1_update_inventory_item'
);

-- Delete BOQ and project setup for the six removed projects only.
delete from public.v1_boq_rows row_record
where row_record.group_id in (
  select group_record.id
  from public.v1_boq_groups group_record
  where group_record.project_id in (select id from cleanup_delete_projects)
);

delete from public.v1_boq_columns column_record
where column_record.group_id in (
  select group_record.id
  from public.v1_boq_groups group_record
  where group_record.project_id in (select id from cleanup_delete_projects)
);

delete from public.v1_boq_groups group_record
where group_record.project_id in (select id from cleanup_delete_projects);

delete from public.v1_project_attachment_intakes intake
where intake.project_id in (select id from cleanup_delete_projects);

delete from public.v1_project_parties party
where party.project_id in (select id from cleanup_delete_projects);

delete from public.v1_project_members member_record
where member_record.project_id in (select id from cleanup_delete_projects);

alter table public.v1_project_scopes
  disable trigger v1_common_scope_immutable;

delete from public.v1_project_scopes scope_record
where scope_record.project_id in (select id from cleanup_delete_projects);

alter table public.v1_project_scopes
  enable trigger v1_common_scope_immutable;

delete from public.v1_projects project
where project.id in (select id from cleanup_delete_projects);

-- Restore every trigger before validation/commit.
alter table public.v1_document_links
  enable trigger v1_document_links_append_only;
alter table public.v1_document_versions
  enable trigger v1_document_versions_immutable;
alter table public.v1_audit_events
  enable trigger v1_audit_events_append_only;

-- Fail closed if any requested cleanup result is incomplete.
do $$
begin
  if (select count(*) from public.v1_projects) <> 1
     or not exists (
       select 1
       from public.v1_projects
       where id = '5387a162-31dd-4523-92b5-dd91d71612a6'::uuid
         and project_ref = 'YRA-321'
     ) then
    raise exception 'Cleanup failed: retained project set is incorrect';
  end if;

  if exists (select 1 from public.v1_material_requests)
     or exists (select 1 from public.v1_procurement_arrangements)
     or exists (select 1 from public.v1_material_dispatches)
     or exists (select 1 from public.v1_receipt_reviews)
     or exists (select 1 from public.v1_delivery_orders)
     or exists (select 1 from public.v1_material_returns) then
    raise exception 'Cleanup failed: workflow rows remain';
  end if;

  if exists (select 1 from public.v1_inventory_items)
     or exists (select 1 from public.v1_inventory_balances)
     or exists (select 1 from public.v1_inventory_movements)
     or exists (select 1 from public.v1_inventory_reservations)
     or exists (select 1 from public.v1_inventory_import_rows)
     or exists (select 1 from public.v1_inventory_import_batches) then
    raise exception 'Cleanup failed: inventory rows remain';
  end if;

  if exists (
    select 1
    from public.v1_document_upload_intents intent
    where intent.project_id <>
      '5387a162-31dd-4523-92b5-dd91d71612a6'::uuid
  ) then
    raise exception 'Cleanup failed: removed-project upload intents remain';
  end if;

  if (select count(*)
      from public.v1_project_attachment_intakes
      where project_id =
        '5387a162-31dd-4523-92b5-dd91d71612a6'::uuid) <> 1 then
    raise exception 'Cleanup failed: YRA-321 attachment intake was not preserved';
  end if;
end
$$;

commit;
