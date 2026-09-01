import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_return_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_material_return_workflow.dart';

void main() {
  test('creation workspace decodes controlled units and delivered trace', () {
    final workspace = YorksV1MaterialReturnCreationWorkspace.fromRpcJson({
      'project_id': 'project-1',
      'project_ref': 'YRA-313',
      'project_name': 'Substation Project',
      'scopes': [
        {'id': 'scope-1', 'name': 'Common', 'scope_kind': 'common'},
      ],
      'units': ['Nos', 'Mtr'],
      'candidates': [
        {
          'receipt_review_line_id': 'receipt-line-1',
          'request_id': 'request-1',
          'request_number': 'YRA313-MR001',
          'dispatch_id': 'dispatch-1',
          'dispatch_number': 'YRA313-DSP001',
          'scope_id': 'scope-1',
          'scope_name': 'Common',
          'item_description': 'Copper pipe',
          'brand_origin': 'UAE',
          'unit': 'Mtr',
          'source_kind': 'warehouse',
          'good_received_qty': 5,
          'committed_return_qty': 2,
          'eligible_return_qty': 3,
        },
      ],
      'draft': null,
    });

    expect(workspace.units, ['Nos', 'Mtr']);
    expect(workspace.candidates.single.requestNumber, 'YRA313-MR001');
    expect(workspace.candidates.single.eligibleReturnQuantity, '3');
  });

  test(
    'receipt and cancellation commands preserve controlled payload shape',
    () {
      final receipt = YorksV1MaterialReturnReceiptInput(
        returnId: 'return-1',
        expectedVersion: 4,
        idempotencyKey: 'key-1',
        receiptNote: 'Counted at warehouse',
        lineReceipts: [
          YorksV1MaterialReturnReceiptLineInput(
            returnLineId: 'line-1',
            receivedGoodQuantity: '2',
            damagedQuantity: '1',
            notReceivedQuantity: '0',
            newItemDescription: 'Site ladder',
            newItemBrandOrigin: 'Yorks',
            unit: 'Nos',
          ),
        ],
      );
      const cancellation = YorksV1MaterialReturnCancellationInput(
        returnId: 'return-2',
        expectedVersion: 2,
        idempotencyKey: 'key-2',
        reason: 'Transport no longer required',
      );

      expect(receipt.toRpcPayload()['line_receipts'], hasLength(1));
      expect(
        (receipt.toRpcPayload()['line_receipts']! as List).single,
        containsPair('damaged_qty', '1'),
      );
      expect(
        cancellation.toRpcPayload(),
        containsPair('reason', 'Transport no longer required'),
      );
    },
  );

  test('post-command return confirmation names state and confirmed lines', () {
    final copy = YorksV1MaterialReturnStrings.commandConfirmed(
      reference: 'YRA313-RTN001',
      state: YorksV1ProjectMaterialReturnState.confirmed,
      lines: 3,
    );

    expect(
      copy.primary,
      'YRA313-RTN001 · Received by warehouse · 3 lines confirmed.',
    );
    expect(copy.ar, contains('YRA313-RTN001'));
    expect(copy.ur, contains('3'));
    expect(copy.hi, contains('3'));
  });
}
