-- Yorks V1 production cleanup: wipe Masaud + procurement users' V1 projects + workflow data.
-- IMPORTANT: run only from a trusted server-side DB session (service role / SQL Editor).
-- This script deliberately targets only the known users and their projects.

DO $$
DECLARE
  v_target_users uuid[] := ARRAY[
    'd8faa5c9-76ef-4f79-84ab-64da6b7e7043'::uuid, -- masaud (usr-masaud-khan)
    'e494a835-92d4-4e57-acb3-6fa6d1a57506'::uuid, -- shakit (usr-shakit-ahmad)
    'c89d3d1d-a6f8-4aeb-9bbb-22a8c95ba896'::uuid  -- silvin (usr-silvin-pailo)
  ];

  v_target_projects uuid[] := ARRAY[]::uuid[];
  v_request_ids uuid[] := ARRAY[]::uuid[];
  v_dispatch_ids uuid[] := ARRAY[]::uuid[];
  v_receipt_ids uuid[] := ARRAY[]::uuid[];
  v_arrangement_ids uuid[] := ARRAY[]::uuid[];
  v_arrangement_line_ids uuid[] := ARRAY[]::uuid[];
  v_return_ids uuid[] := ARRAY[]::uuid[];
  v_doc_ids uuid[] := ARRAY[]::uuid[];
  v_doc_version_ids uuid[] := ARRAY[]::uuid[];
  v_dispatch_line_ids uuid[] := ARRAY[]::uuid[];
  v_doc_object_paths text[] := ARRAY[]::text[];
  v_prev_replication_role text := current_setting('session_replication_role', true);

  v_count integer;
BEGIN
  RAISE NOTICE 'Reset start: building target sets';

  SELECT COALESCE(ARRAY_AGG(DISTINCT project_id ORDER BY project_id), ARRAY[]::uuid[])
  INTO v_target_projects
  FROM (
    SELECT id as project_id
    FROM public.v1_projects
    WHERE created_by_auth_user_id = ANY(v_target_users)
    UNION
    SELECT project_id
    FROM public.v1_project_members
    WHERE member_auth_user_id = ANY(v_target_users)
  ) p;

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_request_ids
  FROM public.v1_material_requests
  WHERE project_id = ANY(v_target_projects)
     OR created_by_auth_user_id = ANY(v_target_users);

  RAISE NOTICE 'Projects to reset: %', cardinality(v_target_projects);
  RAISE NOTICE 'Material requests to reset: %', cardinality(v_request_ids);

  -- Return and delivery chain
  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_dispatch_ids
  FROM public.v1_material_dispatches
  WHERE request_id = ANY(v_request_ids) OR project_id = ANY(v_target_projects);

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_receipt_ids
  FROM public.v1_receipt_reviews
  WHERE request_id = ANY(v_request_ids)
     OR dispatch_id = ANY(v_dispatch_ids);

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_arrangement_ids
  FROM public.v1_procurement_arrangements
  WHERE request_id = ANY(v_request_ids)
     OR id IN (
       SELECT arrangement_id
       FROM public.v1_arrangement_decisions
       WHERE request_id = ANY(v_request_ids)
     );

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_arrangement_line_ids
  FROM public.v1_procurement_arrangement_lines
  WHERE arrangement_id = ANY(v_arrangement_ids)
     OR request_line_id IN (
       SELECT id FROM public.v1_material_request_lines WHERE request_id = ANY(v_request_ids)
     );

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_return_ids
  FROM public.v1_material_returns
  WHERE project_id = ANY(v_target_projects)
     OR request_id = ANY(v_request_ids);

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_dispatch_line_ids
  FROM public.v1_material_dispatch_lines
  WHERE dispatch_id = ANY(v_dispatch_ids)
     OR request_line_id IN (SELECT id FROM public.v1_material_request_lines WHERE request_id = ANY(v_request_ids))
     OR arrangement_line_id = ANY(v_arrangement_line_ids);

  -- Documents: linked to target projects/request lifecycle
  SELECT COALESCE(ARRAY_AGG(DISTINCT document_id ORDER BY document_id), ARRAY[]::uuid[])
  INTO v_doc_ids
  FROM public.v1_document_links
  WHERE project_id = ANY(v_target_projects)
     OR linked_by_auth_user_id = ANY(v_target_users)
     OR (entity_type IN ('material_request','dispatch','material_return','delivery_order')
         AND entity_id = ANY(
           v_request_ids || v_dispatch_ids || v_return_ids
         ));

  SELECT COALESCE(ARRAY_AGG(DISTINCT id ORDER BY id), ARRAY[]::uuid[])
  INTO v_doc_version_ids
  FROM public.v1_document_versions
  WHERE document_id = ANY(v_doc_ids);

  SELECT COALESCE(ARRAY_AGG(DISTINCT object_path ORDER BY object_path), ARRAY[]::text[])
  INTO v_doc_object_paths
  FROM public.v1_document_versions
  WHERE document_id = ANY(v_doc_ids);

  -- 1) Workflow children
  DELETE FROM public.v1_material_request_line_commercials
    WHERE request_line_id IN (
      SELECT id FROM public.v1_material_request_lines WHERE request_id = ANY(v_request_ids)
    );

  DELETE FROM public.v1_material_request_line_approvals
    WHERE request_line_id IN (
      SELECT id FROM public.v1_material_request_lines WHERE request_id = ANY(v_request_ids)
    )
    OR arrangement_line_id = ANY(v_arrangement_line_ids);

  DELETE FROM public.v1_inventory_reservations
    WHERE arrangement_line_id = ANY(v_arrangement_line_ids)
       OR request_id = ANY(v_request_ids);

  DELETE FROM public.v1_arrangement_decisions
    WHERE arrangement_id = ANY(v_arrangement_ids)
       OR request_id = ANY(v_request_ids);

  DELETE FROM public.v1_material_request_line_approvals
    WHERE arrangement_id = ANY(v_arrangement_ids);

  DELETE FROM public.v1_receipt_review_lines
    WHERE receipt_review_id = ANY(v_receipt_ids);

  DELETE FROM public.v1_receipt_reviews
    WHERE id = ANY(v_receipt_ids)
       OR request_id = ANY(v_request_ids);

  DELETE FROM public.v1_material_return_lines
    WHERE material_return_id = ANY(v_return_ids)
    OR dispatch_line_id IN (
      SELECT id FROM public.v1_material_dispatch_lines WHERE dispatch_id = ANY(v_dispatch_ids)
    );

  DELETE FROM public.v1_material_returns
    WHERE id = ANY(v_return_ids)
    OR request_id = ANY(v_request_ids);

  DELETE FROM public.v1_delivery_order_revision_lines
    WHERE delivery_order_revision_id IN (
      SELECT id FROM public.v1_delivery_order_revisions
      WHERE delivery_order_id IN (
        SELECT id FROM public.v1_delivery_orders WHERE request_id = ANY(v_request_ids)
      )
    )
    OR receipt_review_line_id IN (
      SELECT id FROM public.v1_receipt_review_lines WHERE receipt_review_id = ANY(v_receipt_ids)
    );

  DELETE FROM public.v1_delivery_order_revisions
    WHERE delivery_order_id IN (
      SELECT id FROM public.v1_delivery_orders WHERE request_id = ANY(v_request_ids)
    )
    OR receipt_review_id IN (SELECT id FROM public.v1_receipt_reviews WHERE request_id = ANY(v_request_ids))
    OR delivery_order_id IN (
      SELECT id FROM public.v1_delivery_orders WHERE request_id = ANY(v_request_ids)
    );

  DELETE FROM public.v1_delivery_orders
    WHERE request_id = ANY(v_request_ids)
    OR project_id = ANY(v_target_projects);

  DELETE FROM public.v1_material_dispatch_lines
    WHERE id = ANY(v_dispatch_line_ids);

  DELETE FROM public.v1_procurement_arrangement_lines
    WHERE id = ANY(v_arrangement_line_ids);

  DELETE FROM public.v1_procurement_arrangements
    WHERE id = ANY(v_arrangement_ids);

  DELETE FROM public.v1_material_dispatches
    WHERE id = ANY(v_dispatch_ids)
    OR request_id = ANY(v_request_ids)
    OR project_id = ANY(v_target_projects);

  DELETE FROM public.v1_material_request_lines
    WHERE request_id = ANY(v_request_ids);

  DELETE FROM public.v1_material_requests
    WHERE id = ANY(v_request_ids);

  -- 2) BOQ scope/project objects
  DELETE FROM public.v1_boq_rows
    WHERE group_id IN (
      SELECT id FROM public.v1_boq_groups WHERE project_id = ANY(v_target_projects)
    );

  DELETE FROM public.v1_boq_columns
    WHERE group_id IN (
      SELECT id FROM public.v1_boq_groups WHERE project_id = ANY(v_target_projects)
    );

  DELETE FROM public.v1_boq_groups
    WHERE project_id = ANY(v_target_projects);

  DELETE FROM public.v1_project_attachment_intakes
    WHERE project_id = ANY(v_target_projects)
       OR created_by_auth_user_id = ANY(v_target_users);

  DELETE FROM public.v1_project_parties
    WHERE project_id = ANY(v_target_projects);

  -- The common project scope is immutable in normal operations, but cleanup is a
  -- controlled data-reset operation. Temporarily run in replica mode so user
  -- triggers (including common-scope protection) do not block these deletions.
  BEGIN
    PERFORM set_config('session_replication_role', 'replica', true);
    ALTER TABLE public.v1_project_scopes DISABLE TRIGGER ALL;

    DELETE FROM public.v1_project_scopes
      WHERE project_id = ANY(v_target_projects);

    ALTER TABLE public.v1_project_scopes ENABLE TRIGGER ALL;
    PERFORM set_config('session_replication_role', v_prev_replication_role, true);
  EXCEPTION
    WHEN OTHERS THEN
      ALTER TABLE public.v1_project_scopes ENABLE TRIGGER ALL;
      PERFORM set_config('session_replication_role', v_prev_replication_role, true);
      RAISE;
  END;

  -- 3) Documents/versions/links/storage references
  DELETE FROM public.v1_document_links
    WHERE document_id = ANY(v_doc_ids)
       OR project_id = ANY(v_target_projects);

  DELETE FROM public.v1_document_upload_intents
    WHERE project_id = ANY(v_target_projects)
       OR actor_auth_user_id = ANY(v_target_users)
       OR document_id = ANY(v_doc_ids)
       OR finalized_document_id = ANY(v_doc_ids)
       OR finalized_version_id = ANY(v_doc_version_ids);

  DELETE FROM public.v1_document_versions
    WHERE document_id = ANY(v_doc_ids)
       OR id = ANY(v_doc_version_ids);

  DELETE FROM public.v1_documents
    WHERE id = ANY(v_doc_ids)
       OR created_by_auth_user_id = ANY(v_target_users);

  DELETE FROM storage.objects
    WHERE bucket_id = 'yorks-documents'
      AND name = ANY(v_doc_object_paths);

  -- 4) Project and cross-cutting user-linked tables
  DELETE FROM public.v1_material_request_reference_counters
    WHERE project_id = ANY(v_target_projects);

  DELETE FROM public.v1_dispatch_reference_counters
    WHERE project_id = ANY(v_target_projects);

  DELETE FROM public.v1_return_reference_counters
    WHERE project_id = ANY(v_target_projects);

  DELETE FROM public.v1_notifications
    WHERE recipient_auth_user_id = ANY(v_target_users)
       OR project_id = ANY(v_target_projects);

  DELETE FROM public.v1_project_members
    WHERE project_id = ANY(v_target_projects)
       OR member_auth_user_id = ANY(v_target_users)
       OR assigned_by_auth_user_id = ANY(v_target_users)
       OR revoked_by_auth_user_id = ANY(v_target_users);

  DELETE FROM public.v1_audit_events
    WHERE actor_auth_user_id = ANY(v_target_users)
       OR project_id = ANY(v_target_projects);

  DELETE FROM public.v1_idempotency_keys
    WHERE actor_auth_user_id = ANY(v_target_users);

  DELETE FROM public.v1_inventory_movements
    WHERE actor_auth_user_id = ANY(v_target_users);

  DELETE FROM public.v1_projects
    WHERE id = ANY(v_target_projects);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RAISE NOTICE 'Deleted project rows: %', v_count;

  RAISE NOTICE 'Reset complete.';
END $$;
