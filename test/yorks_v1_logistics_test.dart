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
        YorksV1ReceiptOutcome.missing,
      );
      expect(workspace.dispatches.single.lines.single.goodQuantity, '2');
    },
  );

  test(
    'dispatch input emits only the server-recognized transaction payload',
    () {
      final input = YorksV1DispatchInput(
        requestId: 'request-1',
        expectedRequestVersion: 5,
        dispatchDate: DateTime.utc(2026, 8, 2),
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
}

Map<String, dynamic> _workspaceJson() => {
  'request_id': 'request-1',
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
          'receipt_outcome': 'missing',
          'good_qty': '2',
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
