import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_document_strings.dart';
import 'package:material_ledger/shared/models/yorks_v1_logistics.dart';
import 'package:material_ledger/shared/services/yorks_v1_boq_workbook_service.dart';
import 'package:material_ledger/shared/services/yorks_v1_logistics_document_service.dart';
import 'package:pdf/pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        size: '50x50mm',
        model: 'GI',
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
    projectReference: 'Y-001',
    jobContractReference: 'N-19957.2',
    scopeName: 'Building A',
    scopeCode: 'B-01',
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
        equals(const [
          '1',
          'Copper pipe\nSize: 50x50mm · Model: GI',
          '3',
          'Mtr',
        ]),
      );
    },
  );

  test(
    'receipt-reviewed Delivery Report exports confirmed good quantities without dropping exception lines',
    () async {
      final reviewedRevision = YorksV1DeliveryOrderRevision(
        id: 'revision-receipt-reviewed',
        revisionNumber: 3,
        isCurrent: true,
        generatedAt: DateTime.utc(2026, 8, 10),
        generatedByDisplayName: 'Project Engineer',
        snapshotKind: YorksV1DeliveryOrderSnapshotKind.receiptReview,
        lines: const [
          YorksV1DeliveryOrderLine(
            serialNumber: 1,
            description: 'Copper pipe',
            size: '50x50mm',
            model: 'GI',
            quantity: '8',
            unit: 'Mtr',
          ),
          YorksV1DeliveryOrderLine(
            serialNumber: 2,
            description: 'Refrigerant valve',
            size: '25mm',
            model: 'RV-25',
            quantity: '0',
            unit: 'Nos',
          ),
        ],
      );

      final workbook = const YorksV1BoqWorkbookCodec().decode(
        bytes: service.buildDeliveryOrderExcel(
          workspace: workspace,
          dispatch: dispatch,
          revision: reviewedRevision,
        ),
        fileName: 'delivery-report.xlsx',
      );
      expect(
        workbook.sheets.single.rows[2],
        equals(const [
          '1',
          'Copper pipe\nSize: 50x50mm · Model: GI',
          '8',
          'Mtr',
        ]),
      );
      expect(
        workbook.sheets.single.rows[3],
        equals(const [
          '2',
          'Refrigerant valve\nSize: 25mm · Model: RV-25',
          '0',
          'Nos',
        ]),
      );

      final bytes = await service.buildDeliveryOrderPdf(
        workspace: workspace,
        dispatch: dispatch,
        revision: reviewedRevision,
        format: PdfPageFormat.a4,
      );
      expect(bytes, isNotEmpty);
      if (const bool.fromEnvironment('R35_CAPTURE_EVIDENCE')) {
        await Directory('output/pdf').create(recursive: true);
        await File(
          'output/pdf/r35-delivery-report-receipt-reviewed.pdf',
        ).writeAsBytes(bytes, flush: true);
      }
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
    expect(
      YorksV1CompanyDocumentStrings.legalName.ar,
      'يوركس للتكييف والتبريد - ذ.م.م - ش.ش.و',
    );
    expect(
      YorksV1CompanyDocumentStrings.contactLine.en,
      'Tel.: 02-5509788 - Fax: 02-5509688 - P.O. Box: 4757 - Abu Dhabi - United Arab Emirates',
    );
    expect(YorksV1CompanyDocumentStrings.email, 'yorks_sk@yorks.ae');
    if (const bool.fromEnvironment('R35_CAPTURE_EVIDENCE')) {
      await Directory('output/pdf').create(recursive: true);
      await File(
        'output/pdf/r35-delivery-order-dispatch.pdf',
      ).writeAsBytes(bytes, flush: true);
    }
  });

  test('Delivery Order keeps a typical multi-line dispatch compact', () async {
    final multiLineRevision = YorksV1DeliveryOrderRevision(
      id: 'revision-compact',
      revisionNumber: 3,
      isCurrent: true,
      generatedAt: DateTime.utc(2026, 8, 10),
      generatedByDisplayName: 'Procurement User',
      lines: List.generate(
        11,
        (index) => YorksV1DeliveryOrderLine(
          serialNumber: index + 1,
          description: 'Dispatched material ${index + 1}',
          quantity: '${index + 1}',
          unit: 'Nos',
        ),
      ),
    );
    final bytes = await service.buildDeliveryOrderPdf(
      workspace: workspace,
      dispatch: dispatch,
      revision: multiLineRevision,
      format: PdfPageFormat.a4,
    );

    expect(bytes.length, greaterThan(500));
    expect(utf8.decode(bytes.take(4).toList()), equals('%PDF'));
    if (const bool.fromEnvironment('R35_CAPTURE_EVIDENCE')) {
      await Directory('output/pdf').create(recursive: true);
      await File(
        'output/pdf/r35-delivery-order-compact.pdf',
      ).writeAsBytes(bytes, flush: true);
    }
  });

  test(
    'Delivery Report keeps its fixed contact footer on every page of a long receipt',
    () async {
      final longReceiptRevision = YorksV1DeliveryOrderRevision(
        id: 'revision-long-receipt',
        revisionNumber: 4,
        isCurrent: true,
        generatedAt: DateTime.utc(2026, 8, 11),
        generatedByDisplayName: 'Project Engineer',
        snapshotKind: YorksV1DeliveryOrderSnapshotKind.receiptReview,
        lines: List.generate(
          32,
          (index) => YorksV1DeliveryOrderLine(
            serialNumber: index + 1,
            description: 'Received material ${index + 1}',
            quantity: '${index + 1}',
            unit: 'Nos',
          ),
        ),
      );
      final bytes = await service.buildDeliveryOrderPdf(
        workspace: workspace,
        dispatch: dispatch,
        revision: longReceiptRevision,
        format: PdfPageFormat.a4,
      );

      expect(bytes.length, greaterThan(500));
      expect(utf8.decode(bytes.take(4).toList()), equals('%PDF'));
      if (const bool.fromEnvironment('R35_CAPTURE_EVIDENCE')) {
        await Directory('output/pdf').create(recursive: true);
        await File(
          'output/pdf/r35-delivery-report-multipage.pdf',
        ).writeAsBytes(bytes, flush: true);
      }
    },
  );
}
