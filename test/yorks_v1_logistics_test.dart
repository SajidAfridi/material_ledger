import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_logistics_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  test(
    'logistics workspace preserves dispatch and receipt facts without costs',
    () {
      final workspace = YorksV1LogisticsWorkspace.fromRpcJson(_workspaceJson());

      expect(workspace.canDispatch, true);
      expect(workspace.dispatchCandidates.single.stillNeededQuantity, '2');
      expect(
        workspace.dispatches.single.lines.single.receiptOutcome,
        YorksV1ReceiptOutcome.mixed,
      );
      expect(workspace.dispatches.single.lines.single.goodQuantity, '2');
      expect(workspace.dispatches.single.lines.single.missingQuantity, '0.5');
      expect(workspace.dispatches.single.lines.single.damagedQuantity, '0.5');
    },
  );

  test(
    'mixed receipt input keeps each physical exception quantity explicit',
    () {
      const input = YorksV1ReceiptLineInput(
        dispatchLineId: 'dispatch-line-1',
        outcome: YorksV1ReceiptOutcome.mixed,
        goodQuantity: '2',
        missingQuantity: '0.5',
        damagedQuantity: '0.5',
        note: 'One missing and one damaged',
      );

      expect(input.toRpcJson(), {
        'dispatch_line_id': 'dispatch-line-1',
        'outcome': 'mixed',
        'good_qty': '2',
        'missing_qty': '0.5',
        'damaged_qty': '0.5',
        'note': 'One missing and one damaged',
      });
    },
  );

  test(
    'dispatch input emits only the server-recognized transaction payload',
    () {
      final input = YorksV1DispatchInput(
        requestId: 'request-1',
        expectedRequestVersion: 5,
        dispatchDate: DateTime.utc(2026, 8, 2),
        deliveryReference: 'DN-2026-008',
        driverName: 'Yorks Driver',
        vehicleReference: 'Van 7',
        idempotencyKey: '11111111-1111-4111-8111-111111111111',
        lines: const [
          YorksV1DispatchLineInput(
            requestLineId: 'request-line-1',
            dispatchQuantity: '2.5',
          ),
        ],
      );

      expect(input.toRpcPayload(), {
        'request_id': 'request-1',
        'expected_version': 5,
        'dispatch_date': '2026-08-02',
        'delivery_reference': 'DN-2026-008',
        'driver_name': 'Yorks Driver',
        'vehicle_reference': 'Van 7',
        'lines': [
          {'request_line_id': 'request-line-1', 'dispatch_qty': '2.5'},
        ],
      });
    },
  );

  test(
    'the logistics repository fails closed before RPC while disabled',
    () async {
      final client = _RecordingRpcClient();
      final repository = YorksV1SupabaseLogisticsRepository(
        featureFlags: const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
          boq: true,
          excel: true,
          requests: true,
          arrangement: true,
        ),
        connectivity: DefaultConnectivity(),
        rpcClient: client,
      );

      await expectLater(
        repository.getWorkspace('request-1'),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.featureDisabled,
          ),
        ),
      );
      expect(client.calls, isEmpty);
    },
  );

  test('the logistics repository bounds a stalled RPC', () async {
    final repository = YorksV1SupabaseLogisticsRepository(
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
      rpcClient: _HangingRpcClient(),
      rpcTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      repository.getWorkspace('request-1'),
      throwsA(
        isA<YorksV1DomainException>().having(
          (error) => error.code,
          'code',
          YorksV1DomainErrorCode.backendUnavailable,
        ),
      ),
    );
  });

  test('Delivery Order input normalizes its globally unique reference', () {
    const input = YorksV1DeliveryOrderGenerationInput(
      requestId: 'request-1',
      dispatchId: 'dispatch-1',
      expectedRequestVersion: 2,
      expectedDispatchVersion: 3,
      deliveryOrderReference: '  yorks   do-001 ',
      idempotencyKey: '11111111-1111-4111-8111-111111111112',
    );

    expect(input.toRpcPayload()['delivery_order_reference'], 'YORKS DO-001');
  });

  test(
    'Delivery Order revision decodes receipt-reviewed quantity evidence',
    () {
      final revision = YorksV1DeliveryOrderRevision.fromRpcJson({
        'id': 'revision-1',
        'revision_number': 2,
        'snapshot_kind': 'receipt_review',
        'is_current': true,
        'generated_at': '2026-08-10T10:00:00Z',
        'generated_by_display_name': 'Site Engineer',
        'lines': [
          {
            's_no': 1,
            'item_description': 'supply duct',
            'size': '500x300mm',
            'model': 'GI',
            'quantity': '8',
            'unit': 'Nos',
          },
          {
            's_no': 2,
            'item_description': 'control panel',
            'quantity': '0',
            'unit': 'Nos',
          },
        ],
      });

      expect(
        revision.snapshotKind,
        YorksV1DeliveryOrderSnapshotKind.receiptReview,
      );
      expect(revision.lines.map((line) => line.quantity), ['8', '0']);
      expect(revision.lines.first.description, 'Supply duct');
      expect(revision.lines.first.size, '500x300mm');
      expect(revision.lines.first.model, 'GI');
    },
  );

  test(
    'returns and documents repository boundary remains default-off',
    () async {
      final client = _RecordingRpcClient();
      final repository = YorksV1SupabaseLogisticsRepository(
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
        rpcClient: client,
      );

      await expectLater(
        repository.getReturnsDocumentsWorkspace('request-1'),
        throwsA(
          isA<YorksV1DomainException>().having(
            (error) => error.code,
            'code',
            YorksV1DomainErrorCode.featureDisabled,
          ),
        ),
      );
      expect(client.calls, isEmpty);
    },
  );
}

Map<String, dynamic> _workspaceJson() => {
  'request_id': 'request-1',
  'project_id': 'project-1',
  'request_number': 'Y-001-MR001',
  'request_state': 'partially_received',
  'request_record_version': 7,
  'project_name': 'Yorks Project',
  'scope_name': 'Building A',
  'can_dispatch': true,
  'can_confirm_receipt': true,
  'dispatch_candidates': [
    {
      'request_line_id': 'request-line-1',
      'display_order': 1,
      'item_description': 'VAV Damper',
      'brand_origin': 'UAE',
      'unit': 'Nos',
      'approved_qty': '4',
      'good_received_qty': '2',
      'in_transit_qty': '0',
      'still_needed_qty': '2',
      'source_kind': 'warehouse',
      'external_supplier': null,
      'inventory_item_id': 'inventory-1',
      'reserved_remaining_qty': '1',
      'warehouse_available_qty': '1',
    },
  ],
  'dispatches': [
    {
      'id': 'dispatch-1',
      'dispatch_number': 'Y-001-DSP001',
      'dispatch_date': '2026-08-02',
      'driver_name': 'Yorks Driver',
      'vehicle_reference': 'Van 7',
      'state': 'partially_received',
      'record_version': 2,
      'dispatched_by_display_name': 'Procurement User',
      'dispatched_at': '2026-08-02T10:00:00Z',
      'can_confirm_receipt': false,
      'receipt_review': {
        'id': 'review-1',
        'reviewed_at': '2026-08-02T12:00:00Z',
        'reviewed_by_display_name': 'Site Engineer',
      },
      'lines': [
        {
          'id': 'dispatch-line-1',
          'request_line_id': 'request-line-1',
          'item_description': 'VAV Damper',
          'brand_origin': 'UAE',
          'unit': 'Nos',
          'source_kind': 'warehouse',
          'external_supplier': null,
          'dispatched_qty': '3',
          'approved_qty_snapshot': '4',
          'receipt_outcome': 'mixed',
          'good_qty': '2',
          'missing_qty': '0.5',
          'damaged_qty': '0.5',
          'exception_qty': '1',
          'receipt_note': 'One item missing',
        },
      ],
    },
  ],
};

class _RecordingRpcClient implements YorksV1MaterialRequestRpcClient {
  final List<String> calls = [];

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    return _workspaceJson();
  }
}

class _HangingRpcClient implements YorksV1MaterialRequestRpcClient {
  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => Completer<Object?>().future;
}
