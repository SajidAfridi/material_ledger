import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_arrangement.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_arrangement_repository.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_material_request_repository.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';

void main() {
  test('arrangement workspace preserves non-commercial review facts only', () {
    final workspace = YorksV1ArrangementWorkspace.fromRpcJson(_workspaceJson());

    expect(workspace.canDecide, true);
    expect(workspace.currentArrangement?.lines.single.requestedQuantity, '4');
    expect(workspace.currentArrangement?.lines.single.arrangedQuantity, '2');
    expect(workspace.currentArrangement?.lines.single.reservedQuantity, '2');
    expect(
      workspace.currentArrangement?.lines.single.inventoryItemId,
      'item-1',
    );
  });

  test('save input emits complete server-recognized line decisions', () {
    final input = YorksV1SaveArrangementInput(
      requestId: 'request-1',
      arrangementId: 'arrangement-1',
      expectedRequestVersion: 4,
      expectedArrangementVersion: 1,
      idempotencyKey: '11111111-1111-4111-8111-111111111111',
      procurementNote: 'Supplier allocation checked',
      lines: const [
        YorksV1ArrangementLineInput(
          arrangementLineId: 'line-1',
          source: YorksV1ArrangementSource.warehouse,
          decision: YorksV1ArrangementDecision.partial,
          arrangedQuantity: '2.5',
          inventoryItemId: 'item-1',
          reason: 'Balance is held for another project',
          unitCost: '125.50',
        ),
      ],
    );

    expect(input.toRpcPayload(), {
      'request_id': 'request-1',
      'arrangement_id': 'arrangement-1',
      'expected_request_version': 4,
      'expected_arrangement_version': 1,
      'procurement_note': 'Supplier allocation checked',
      'lines': [
        {
          'arrangement_line_id': 'line-1',
          'source_kind': 'warehouse',
          'external_supplier': null,
          'inventory_item_id': 'item-1',
          'decision': 'partial',
          'arranged_qty': '2.5',
          'reason': 'Balance is held for another project',
          'unit_cost': '125.50',
        },
      ],
    });
  });

  test(
    'the arrangement repository fails closed before any RPC when disabled',
    () async {
      final client = _RecordingRpcClient();
      final repository = YorksV1SupabaseArrangementRepository(
        featureFlags: const YorksV1FeatureFlags(
          foundation: true,
          projects: true,
          boq: true,
          excel: true,
          requests: true,
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
  'request_state': 'awaiting_approval',
  'request_record_version': 4,
  'can_begin': false,
  'can_save': false,
  'can_decide': true,
  'arrangements': [
    {
      'id': 'arrangement-1',
      'arrangement_version': 1,
      'status': 'awaiting_approval',
      'is_current': true,
      'record_version': 2,
      'started_by_display_name': 'Procurement User',
      'started_at': '2026-08-02T00:00:00Z',
      'saved_at': '2026-08-02T00:05:00Z',
      'saved_by_display_name': 'Procurement User',
      'lines': [
        {
          'id': 'line-1',
          'request_line_id': 'request-line-1',
          'display_order': 1,
          'item_description': 'Duct Damper',
          'brand_origin': 'UAE',
          'requested_qty': '4',
          'unit': 'Nos',
          'source_kind': 'warehouse',
          'external_supplier': null,
          'decision': 'partial',
          'arranged_qty': '2',
          'reason': 'Only two in stock',
          'inventory_item_id': 'item-1',
          'inventory_item_description': 'Duct Damper',
          'warehouse_available_at_save': '5',
          'reservation_state': 'active',
          'reserved_qty': '2',
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
