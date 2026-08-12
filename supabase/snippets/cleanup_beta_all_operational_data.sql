-- Yorks V1 one-time beta-to-Phase-1 operational data reset.
--
-- Preserves authentication users, profiles, role/capability configuration,
-- inventory categories/aliases and the 29 BOQ group templates. Removes all
-- project, BOQ, Material Request, procurement, inventory, dispatch, receipt,
-- Delivery Order, return, document, notification and rental operational data.
--
-- The single Storage object was backed up and removed through the Storage API
-- before this transaction. Never delete storage.objects directly.

begin;

set local lock_timeout = '5s';
set local statement_timeout = '120s';

lock table
  public.v1_projects,
  public.v1_material_requests,
  public.v1_inventory_items,
  public.v1_documents,
  public.v1_rental_properties,
  public.projects,
  public."materialRequests",
  public.materials,
  public."rentalUnits",
  public.phase1_plans
in access exclusive mode;

-- Fail closed if the reviewed beta dataset changed after preflight.
do $$
begin
  if (select count(*) from public.v1_projects) <> 1
     or not exists (
       select 1
       from public.v1_projects
       where project_ref = 'YRA-321'
     )
     or (select count(*) from public.v1_material_requests) <> 3
     or (select count(*) from public.v1_inventory_items) <> 5
     or (select count(*) from public.v1_material_dispatches) <> 6
     or (select count(*) from public.v1_receipt_reviews) <> 6
     or (select count(*) from public.v1_delivery_orders) <> 6
     or exists (select 1 from public.v1_rental_properties)
     or (select count(*) from public.projects) <> 2
     or (select count(*) from public."materialRequests") <> 3
     or (select count(*) from public.materials) <> 56
     or (select count(*) from public."materialPlans") <> 1
     or (select count(*) from public."stockMovements") <> 16
     or (select count(*) from public.returns) <> 1
     or (select count(*) from public.phase1_plans) <> 1
     or exists (select 1 from public."rentalUnits")
     or exists (select 1 from storage.objects) then
    raise exception
      'Beta cleanup aborted: production data changed after reviewed preflight';
  end if;
end
$$;

-- Every FK-connected operational table is named explicitly. Do not add
-- CASCADE: configuration and identity tables are intentionally preserved.
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
  public.v1_inventory_items,
  public.v1_boq_rows,
  public.v1_boq_columns,
  public.v1_boq_groups,
  public.v1_project_attachment_intakes,
  public.v1_project_parties,
  public.v1_project_members,
  public.v1_project_scopes,
  public.v1_document_upload_intents,
  public.v1_document_links,
  public.v1_document_versions,
  public.v1_documents,
  public.v1_notification_push_outbox,
  public.v1_notifications,
  public.v1_rental_cheques,
  public.v1_rental_receipts,
  public.v1_rental_periods,
  public.v1_rental_leases,
  public.v1_rental_properties,
  public.v1_projects,
  public.v1_reconciliation_issues,
  public.v1_idempotency_keys,
  public.phase1_plan_lines,
  public.phase1_plan_activity,
  public.phase1_plan_comments,
  public.phase1_plan_versions,
  public.phase1_plans,
  public."goodsReceipts",
  public.returns,
  public."stockMovements",
  public."materialRequests",
  public."materialPlans",
  public.commercial_records,
  public.materials,
  public.notifications,
  public."rentPayments",
  public."rentalUnits",
  public.projects,
  public."auditLogs",
  public.v1_audit_events
restart identity;

-- Retain one truthful record that the previously backed-up beta history was
-- intentionally cleared under the Owner/Admin's explicit authorization.
insert into public.v1_audit_events (
  event_type,
  entity_type,
  entity_id,
  project_id,
  actor_auth_user_id,
  actor_role,
  actor_exact_role,
  actor_display_name_snapshot,
  before_data,
  after_data,
  reason
) values (
  'beta_environment_reset',
  'environment',
  '2f34a26c-d8fc-47c6-a5dc-6e52e7202608'::uuid,
  null,
  '0fe08d87-2e5b-4691-8187-fe824ea90a8c'::uuid,
  'admin',
  'admin',
  'Owner',
  jsonb_build_object(
    'projects', 1,
    'material_requests', 3,
    'inventory_items', 5,
    'dispatches', 6,
    'receipt_reviews', 6,
    'delivery_orders', 6,
    'legacy_projects', 2,
    'legacy_material_requests', 3,
    'legacy_materials', 56,
    'legacy_material_plans', 1,
    'legacy_stock_movements', 16,
    'legacy_returns', 1,
    'phase1_plans', 1,
    'storage_objects', 1
  ),
  jsonb_build_object(
    'projects', 0,
    'material_requests', 0,
    'inventory_items', 0,
    'dispatches', 0,
    'receipt_reviews', 0,
    'delivery_orders', 0,
    'legacy_projects', 0,
    'legacy_material_requests', 0,
    'legacy_materials', 0,
    'legacy_material_plans', 0,
    'legacy_stock_movements', 0,
    'legacy_returns', 0,
    'phase1_plans', 0,
    'storage_objects', 0,
    'preserved_auth_users', 26,
    'preserved_profiles', 24,
    'preserved_inventory_categories', 17,
    'preserved_boq_templates', 29,
    'preserved_legacy_material_categories', 8,
    'preserved_legacy_material_units', 20
  ),
  'Authorized beta cleanup before Yorks Phase 1 real-world testing'
);

-- Assert the blank operational state and the required preserved foundations.
do $$
begin
  if exists (select 1 from public.v1_projects)
     or exists (select 1 from public.v1_boq_groups)
     or exists (select 1 from public.v1_material_requests)
     or exists (select 1 from public.v1_procurement_arrangements)
     or exists (select 1 from public.v1_inventory_items)
     or exists (select 1 from public.v1_material_dispatches)
     or exists (select 1 from public.v1_receipt_reviews)
     or exists (select 1 from public.v1_delivery_orders)
     or exists (select 1 from public.v1_material_returns)
     or exists (select 1 from public.v1_documents)
     or exists (select 1 from public.v1_notifications)
     or exists (select 1 from public.v1_rental_properties)
     or exists (select 1 from public.projects)
     or exists (select 1 from public."materialRequests")
     or exists (select 1 from public.materials)
     or exists (select 1 from public."materialPlans")
     or exists (select 1 from public."stockMovements")
     or exists (select 1 from public.returns)
     or exists (select 1 from public.phase1_plans)
     or exists (select 1 from public."rentalUnits")
     or exists (select 1 from storage.objects) then
    raise exception 'Beta cleanup failed: operational rows remain';
  end if;

  if (select count(*) from auth.users) <> 26
     or (select count(*) from public.v1_profiles) <> 24
     or (select count(*) from public.v1_inventory_categories) <> 17
     or (select count(*) from public.v1_boq_group_templates) <> 29
     or (select count(*) from public."materialCategories") <> 8
     or (select count(*) from public."materialUnits") <> 20 then
    raise exception 'Beta cleanup failed: preserved foundation changed';
  end if;

  if (select count(*) from public.v1_audit_events) <> 1
     or not exists (
       select 1
       from public.v1_audit_events
       where event_type = 'beta_environment_reset'
     ) then
    raise exception 'Beta cleanup failed: cleanup audit record is missing';
  end if;
end
$$;

commit;
