import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_inventory_supplier.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_inventory_supplier_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  const enabledFlags = YorksV1FeatureFlags(
    foundation: true,
    projects: true,
    boq: true,
    excel: true,
    requests: true,
    arrangement: true,
    logistics: true,
    returnsDocuments: true,
    documents: true,
    inventorySuppliers: true,
  );

  test('directory uses a protected paginated projection', () async {
    final rpc = _RecordingRpc(_directoryResponse);
    final repository = YorksV1SupabaseInventorySupplierRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    final workspace = await repository.getDirectory(
      search: ' unknown ',
      status: YorksV1InventorySupplierStatus.identityMissing,
      limit: 25,
      offset: 50,
    );

    expect(rpc.functionName, 'v1_supplier_directory_projection');
    expect(rpc.parameters, {
      'p_search': 'unknown',
      'p_status': 'identity_missing',
      'p_limit': 25,
      'p_offset': 50,
    });
    expect(workspace.suppliers.single.isSystemUnknown, isTrue);
    expect(workspace.suppliers.single.reconciliationCount, 1240);
    expect(workspace.unitTotals.single.unit, 'Nos');
    expect(workspace.unitTotals.single.acceptedQuantity, '1240');
  });

  test(
    'item trail uses the protected complete provenance projection',
    () async {
      final rpc = _RecordingRpc(_itemTrailResponse);
      final repository = YorksV1SupabaseInventorySupplierRepository(
        featureFlags: enabledFlags,
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      final trail = await repository.getItemTrail(
        supplierId: 'supplier-1',
        inventoryItemId: 'item-1',
      );

      expect(rpc.functionName, 'v1_supplier_item_trail_projection');
      expect(rpc.parameters, {
        'p_supplier_id': 'supplier-1',
        'p_inventory_item_id': 'item-1',
        'p_section': 'receipt_lines',
        'p_limit': 50,
        'p_offset': 0,
      });
      expect(
        trail.section,
        YorksV1InventorySupplierItemTrailSection.receiptLines,
      );
      expect(trail.totalCount, 1);
      expect(trail.item.currentOnHand, '7.0000');
      expect(trail.receiptLines.single.damagedQuantity, '2.0000');
      expect(trail.destinations.single.siteReceiptOutcome, 'received');
      expect(trail.destinations.single.confirmedReturnQuantity, '1.0000');
      expect(
        trail.provenanceGaps.single.reasonCode,
        'legacy_or_unproven_stock',
      );
    },
  );

  test(
    'receipt detail keeps all line conditions and unit-safe totals',
    () async {
      final rpc = _RecordingRpc(_receiptBatchDetailResponse);
      final repository = YorksV1SupabaseInventorySupplierRepository(
        featureFlags: enabledFlags,
        connectivity: DefaultConnectivity(),
        rpcClient: rpc,
      );

      final detail = await repository.getReceiptBatchDetail(
        supplierId: 'supplier-1',
        receiptBatchId: 'batch-1',
      );

      expect(rpc.functionName, 'v1_supplier_receipt_batch_detail_projection');
      expect(rpc.parameters, {
        'p_supplier_id': 'supplier-1',
        'p_receipt_batch_id': 'batch-1',
        'p_section': 'lines',
        'p_limit': 50,
        'p_offset': 0,
      });
      expect(
        detail.section,
        YorksV1InventorySupplierReceiptBatchDetailSection.lines,
      );
      expect(detail.batch.receivedByRole, 'procurement');
      expect(detail.batch.unitTotals, hasLength(2));
      expect(detail.lines, hasLength(2));
      expect(detail.lines.first.allocatedQuantity, '3.0000');
      expect(detail.documents.single.receiptBatchId, 'batch-1');
    },
  );

  test('R38.9 import sends the strict fingerprinted command once', () async {
    final sha256 = List.filled(64, 'a').join();
    final rpc = _RecordingRpc({
      'import_batch_id': 'batch-1',
      'row_count': '1',
      'created_items': '1',
      'updated_items': '0',
      'created_suppliers': '0',
      'created_categories': '0',
      'receipt_batches': '1',
      'movements': '1',
      'warning_count': '1',
      'excluded_count': '0',
      'unknown_supplier_rows': '1',
      'unit_totals': [
        {
          'unit': 'Nos',
          'accepted_qty': '12',
          'damaged_qty': '1',
          'rejected_qty': '0',
        },
      ],
    });
    final repository = YorksV1SupabaseInventorySupplierRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );
    final result = await repository.importInventory(
      YorksV1InventorySupplierImportInput(
        fileName: 'opening.xlsx',
        fileSha256: sha256,
        openingBalanceAsOfDate: DateTime.utc(2026, 8, 20),
        rows: const [
          {
            'source_row_number': 5,
            'source_type': 'opening_balance',
            'supplier_id': '00000000-0000-4000-8000-000000000389',
          },
        ],
        idempotencyKey: 'import-command-1',
      ),
    );

    expect(rpc.functionName, 'v1_import_inventory_r38_9');
    expect(rpc.parameters?['p_idempotency_key'], 'import-command-1');
    final payload = rpc.parameters?['p_payload'] as Map<String, Object?>;
    expect(payload['file_sha256'], sha256);
    expect(payload['import_mode'], 'strict');
    expect(payload['opening_balance_as_of_date'], '2026-08-20');
    expect(result.warningCount, 1);
    expect(result.unknownSupplierRows, 1);
    expect(result.unitTotals.single.acceptedQuantity, '12');
  });

  test('supplier boundary fails closed when its rollout is disabled', () async {
    final rpc = _RecordingRpc(_directoryResponse);
    final repository = YorksV1SupabaseInventorySupplierRepository(
      featureFlags: const YorksV1FeatureFlags(
        foundation: true,
        projects: true,
        boq: true,
        excel: true,
        requests: true,
        arrangement: true,
        logistics: true,
      ),
      connectivity: DefaultConnectivity(),
      rpcClient: rpc,
    );

    await expectLater(
      repository.getDirectory(),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.featureDisabled,
        ),
      ),
    );
    expect(rpc.functionName, isNull);
  });

  test('supplier commands do not run while offline', () async {
    final rpc = _RecordingRpc(_directoryResponse);
    final repository = YorksV1SupabaseInventorySupplierRepository(
      featureFlags: enabledFlags,
      connectivity: DefaultConnectivity(online: false),
      rpcClient: rpc,
    );

    await expectLater(
      repository.getDirectory(),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.offline,
        ),
      ),
    );
    expect(rpc.functionName, isNull);
  });
}

const _directoryResponse = <String, Object?>{
  'summary': {
    'active_suppliers': 5,
    'receipt_batches': 6,
    'distinct_items': 7,
    'documents_missing': 2,
    'inactive_or_review': 1,
    'identity_missing': 1240,
  },
  'unit_totals': [
    {
      'unit': 'Nos',
      'accepted_quantity': '1240',
      'damaged_quantity': '0',
      'rejected_quantity': '0',
    },
  ],
  'suppliers': [
    {
      'id': '00000000-0000-4000-8000-000000000389',
      'supplier_code': 'SUP-UNKNOWN',
      'canonical_name': 'Unknown Supplier',
      'description': 'Controlled reconciliation folder',
      'status': 'identity_missing',
      'is_system_unknown': true,
      'receipt_batch_count': 1,
      'distinct_item_count': 1240,
      'missing_document_count': 1,
      'reconciliation_count': 1240,
      'last_receipt_at': '2026-08-20T08:00:00Z',
      'aliases': <String>[],
      'record_version': 1,
    },
  ],
  'total_count': 51,
  'limit': 25,
  'offset': 50,
};

const _itemTrailResponse = <String, Object?>{
  'section': 'receipt_lines',
  'total_count': '1',
  'limit': '50',
  'offset': '0',
  'supplier': {
    'id': 'supplier-1',
    'supplier_code': 'SUP-001',
    'canonical_name': 'Trace Supplier',
    'description': null,
    'status': 'active',
    'is_system_unknown': false,
    'receipt_batch_count': '1',
    'distinct_item_count': '1',
    'missing_document_count': '0',
    'reconciliation_count': '0',
    'last_receipt_at': '2026-08-20T08:00:00Z',
    'aliases': <String>[],
    'record_version': '1',
  },
  'item': {
    'id': 'item-1',
    'item_code': 'INV-001',
    'item_description': 'Traceable item',
    'brand_origin': 'UAE',
    'size': '300x300',
    'model_tag': 'M-1',
    'unit': 'Nos',
    'current_on_hand': '7.0000',
    'reserved_quantity': '2.0000',
    'available_quantity': '5.0000',
  },
  'receipt_lines': [
    {
      'id': 'receipt-line-1',
      'receipt_batch_id': 'batch-1',
      'receipt_number': 'RCV-0001',
      'source_type': 'external_supplier',
      'supplier_reference': 'DN-001',
      'received_date': '2026-08-20',
      'warehouse_location': 'A-1',
      'source_row_number': '2',
      'delivered_quantity': '10.0000',
      'accepted_quantity': '7.0000',
      'damaged_quantity': '2.0000',
      'rejected_quantity': '1.0000',
      'allocated_quantity': '3.0000',
      'returned_quantity': '1.0000',
      'remaining_accepted_quantity': '4.0000',
      'unit': 'Nos',
      'tracking_mode': 'bulk',
      'serial_number': null,
      'batch_lot_number': null,
    },
  ],
  'movements': [
    {
      'id': 'movement-1',
      'movement_type': 'supplier_receipt',
      'quantity_delta': '7.0000',
      'on_hand_after_quantity': '7.0000',
      'source_entity_type': 'supplier_receipt_line',
      'source_entity_id': 'receipt-line-1',
      'reason': 'Supplier receipt',
      'actor_display_name': 'Procurement User',
      'created_at': '2026-08-20T08:00:00Z',
    },
  ],
  'reservations': [
    {
      'id': 'reservation-1',
      'request_id': 'request-1',
      'request_number': 'YRA-MR001',
      'project_id': 'project-1',
      'project_reference': 'YRA',
      'project_name': 'Project',
      'scope_id': 'scope-1',
      'scope_name': 'Common',
      'reserved_quantity': '2.0000',
      'consumed_quantity': '0.0000',
      'remaining_quantity': '2.0000',
      'unit': 'Nos',
      'state': 'active',
      'created_at': '2026-08-20T09:00:00Z',
    },
  ],
  'destinations': [
    {
      'allocation_id': 'allocation-1',
      'receipt_line_id': 'receipt-line-1',
      'receipt_batch_id': 'batch-1',
      'dispatch_line_id': 'dispatch-line-1',
      'dispatch_id': 'dispatch-1',
      'dispatch_number': 'YRA-DSP001',
      'request_id': 'request-1',
      'request_number': 'YRA-MR001',
      'project_id': 'project-1',
      'project_reference': 'YRA',
      'project_name': 'Project',
      'scope_id': 'scope-1',
      'scope_name': 'Common',
      'allocated_quantity': '3.0000',
      'unit': 'Nos',
      'allocation_method': 'fifo',
      'override_reason': null,
      'dispatch_state': 'received',
      'dispatched_at': '2026-08-21T08:00:00Z',
      'site_receipt_outcome': 'received',
      'good_received_quantity': '3.0000',
      'exception_quantity': '0.0000',
      'confirmed_return_quantity': '1.0000',
      'material_return_ids': ['return-1'],
    },
  ],
  'provenance_gaps': [
    {
      'dispatch_line_id': 'dispatch-line-legacy',
      'dispatch_id': 'dispatch-legacy',
      'dispatch_number': 'YRA-DSP000',
      'request_number': 'YRA-MR000',
      'project_reference': 'YRA',
      'project_name': 'Project',
      'scope_name': 'Common',
      'unallocated_quantity': '1.0000',
      'unit': 'Nos',
      'reason_code': 'legacy_or_unproven_stock',
      'recorded_at': '2026-08-19T08:00:00Z',
    },
  ],
  'activity': [
    {
      'id': 'audit-1',
      'event_type': 'supplier_receipt_committed',
      'entity_type': 'supplier_receipt_batch',
      'entity_id': 'batch-1',
      'actor_display_name': 'Procurement User',
      'actor_role': 'procurement',
      'reason': 'Receipt committed',
      'occurred_at': '2026-08-20T08:00:00Z',
    },
  ],
};

const _receiptBatchDetailResponse = <String, Object?>{
  'section': 'lines',
  'total_count': '2',
  'limit': '50',
  'offset': '0',
  'supplier': {
    'id': 'supplier-1',
    'supplier_code': 'SUP-001',
    'canonical_name': 'Trace Supplier',
    'description': null,
    'status': 'active',
    'is_system_unknown': false,
    'receipt_batch_count': '1',
    'distinct_item_count': '2',
    'missing_document_count': '0',
    'reconciliation_count': '0',
    'last_receipt_at': '2026-08-20T08:00:00Z',
    'aliases': <String>[],
    'record_version': '1',
  },
  'batch': {
    'id': 'batch-1',
    'receipt_number': 'RCV-0001',
    'source_type': 'external_supplier',
    'supplier_reference': 'DN-001',
    'received_date': '2026-08-20',
    'warehouse_location': 'A-1',
    'status': 'committed',
    'line_count': '2',
    'document_count': '1',
    'received_by_auth_user_id': 'auth-procurement',
    'received_by_display_name': 'Procurement User',
    'received_by_role': 'procurement',
    'created_at': '2026-08-20T08:00:00Z',
    'unit_totals': [
      {
        'unit': 'Meter',
        'accepted_quantity': '4.0000',
        'damaged_quantity': '0.0000',
        'rejected_quantity': '0.0000',
      },
      {
        'unit': 'Nos',
        'accepted_quantity': '7.0000',
        'damaged_quantity': '2.0000',
        'rejected_quantity': '1.0000',
      },
    ],
  },
  'lines': [
    {
      'id': 'receipt-line-1',
      'inventory_item_id': 'item-1',
      'source_row_number': '2',
      'item_code': 'INV-001',
      'item_description': 'Traceable item',
      'category_name': 'General',
      'brand_origin': 'UAE',
      'size': '300x300',
      'model_tag': 'M-1',
      'unit': 'Nos',
      'delivered_quantity': '10.0000',
      'accepted_quantity': '7.0000',
      'damaged_quantity': '2.0000',
      'rejected_quantity': '1.0000',
      'current_on_hand': '7.0000',
      'allocated_quantity': '3.0000',
      'tracking_mode': 'bulk',
      'serial_number': null,
      'batch_lot_number': null,
      'location': 'A-1',
      'notes': null,
    },
    {
      'id': 'receipt-line-2',
      'inventory_item_id': 'item-2',
      'source_row_number': '3',
      'item_code': 'INV-002',
      'item_description': 'Second item',
      'category_name': 'General',
      'brand_origin': null,
      'size': null,
      'model_tag': null,
      'unit': 'Meter',
      'delivered_quantity': '4.0000',
      'accepted_quantity': '4.0000',
      'damaged_quantity': '0.0000',
      'rejected_quantity': '0.0000',
      'current_on_hand': '4.0000',
      'allocated_quantity': '0.0000',
      'tracking_mode': 'bulk',
      'serial_number': null,
      'batch_lot_number': null,
      'location': 'A-1',
      'notes': null,
    },
  ],
  'documents': [
    {
      'document_id': 'document-1',
      'version_id': 'version-1',
      'file_name': 'delivery-note.pdf',
      'mime_type': 'application/pdf',
      'byte_size': '100',
      'revision_number': '1',
      'classification': 'operational',
      'uploaded_at': '2026-08-20T08:00:00Z',
      'uploaded_by_display_name': 'Procurement User',
      'receipt_batch_id': 'batch-1',
    },
  ],
  'activity': [
    {
      'id': 'audit-1',
      'event_type': 'supplier_receipt_committed',
      'entity_type': 'supplier_receipt_batch',
      'entity_id': 'batch-1',
      'actor_display_name': 'Procurement User',
      'actor_role': 'procurement',
      'reason': 'Receipt committed',
      'occurred_at': '2026-08-20T08:00:00Z',
    },
  ],
};

class _RecordingRpc implements YorksV1MaterialRequestRpcClient {
  _RecordingRpc(this.response);

  final Object? response;
  String? functionName;
  Map<String, Object?>? parameters;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    this.functionName = functionName;
    this.parameters = parameters;
    return response;
  }
}
