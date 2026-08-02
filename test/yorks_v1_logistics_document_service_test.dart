import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_logistics_document_service.dart';
import 'package:pdf/pdf.dart';

void main() {
  const service = YorksV1LogisticsDocumentService();
  final revision = YorksV1DeliveryOrderRevision(
    id: 'revision-1',
    revisionNumber: 2,
    isCurrent: true,
    generatedAt: DateTime.utc(2026, 8, 2),
    generatedByDisplayName: 'Procurement User',
    lines: const [
      YorksV1DeliveryOrderLine(
        serialNumber: 1,
        description: 'Copper pipe',
        quantity: '3',
        unit: 'Mtr',
      ),
      YorksV1DeliveryOrderLine(
        serialNumber: 2,
        description: 'Refrigerant valve',
        quantity: '1',
        unit: 'Nos',
      ),
    ],
  );
  final deliveryOrder = YorksV1DeliveryOrder(
    id: 'order-1',
    dispatchId: 'dispatch-1',
    reference: 'Y-DO-001',
    recordVersion: 2,
    currentRevisionId: revision.id,
    revisions: [revision],
  );
  final dispatch = YorksV1DeliveryOrderDispatch(
    dispatchId: 'dispatch-1',
    dispatchNumber: 'Y-DSP-001',
    dispatchDate: DateTime.utc(2026, 8, 2),
    dispatchRecordVersion: 1,
    canGenerate: true,
    deliveryOrder: deliveryOrder,
  );
  final workspace = YorksV1ReturnsDocumentsWorkspace(
    requestId: 'request-1',
    projectId: 'project-1',
    requestNumber: 'Y-MR-001',
    requestState: 'received',
    requestRecordVersion: 1,
    projectName: 'Yorks Project',
    scopeName: 'Building A',
    canGenerateDeliveryOrder: true,
    canSubmitMaterialReturn: true,
    canConfirmMaterialReturn: true,
    deliveryOrderDispatches: [dispatch],
    returnCandidates: const [],
    materialReturns: const [],
    returnInventoryItems: const [],
  );

  test(
    'Delivery Order export has only the frozen four operational columns',
    () {
      final bytes = service.buildDeliveryOrderExcel(
        workspace: workspace,
        dispatch: dispatch,
        revision: revision,
      );
      final workbook = const YorksV1BoqWorkbookCodec().decode(
        bytes: bytes,
        fileName: 'delivery-order.xlsx',
      );

      expect(workbook.sheets, hasLength(1));
      expect(
        workbook.sheets.single.rows[1],
        equals(const ['S:No', 'Item Description', 'Qty', 'Unit']),
      );
      expect(
        workbook.sheets.single.rows[2],
        equals(const ['1', 'Copper pipe', '3', 'Mtr']),
      );
    },
  );

  test('Delivery Order PDF supports the printable snapshot', () async {
    final bytes = await service.buildDeliveryOrderPdf(
      workspace: workspace,
      dispatch: dispatch,
      revision: revision,
      format: PdfPageFormat.a4,
    );

    expect(bytes.length, greaterThan(500));
    expect(utf8.decode(bytes.take(4).toList()), equals('%PDF'));
  });
}
