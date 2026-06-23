import 'package:flutter_test/flutter_test.dart';

import 'package:material_ledger/shared/models/material_request.dart';
import 'package:material_ledger/shared/models/project.dart';
import 'package:material_ledger/shared/services/receipt_pdf.dart';
import 'package:pdf/pdf.dart';

/// Smoke tests: the PDF must actually build (table, multi-page, footer,
/// watermark, etc.) without throwing — something `flutter analyze` can't catch.
/// ASCII-only content so it passes with the bundled fallback font when the
/// Noto web font can't be fetched in the test sandbox.
MaterialRequest _request({
  RequestStatus status = RequestStatus.pending,
  int lines = 3,
  String? notes,
}) => MaterialRequest(
  id: 'req-abc12345',
  projectName: 'Al Raha Beach Tower — HVAC',
  projectNameSecondary: '',
  status: status,
  requestDate: DateTime(2026, 6, 12, 9, 14),
  itemCount: lines,
  priority: RequestPriority.urgent,
  siteLocation: 'Al Raha Beach, Abu Dhabi',
  notes: notes,
  lineItems: [
    for (var i = 0; i < lines; i++)
      RequestLineItem(
        materialId: 'mat-$i',
        materialName: 'Copper pipe ${i + 1}/2 inch',
        materialNameSecondary: '',
        quantity: (i + 1) * 10,
        unitSymbol: 'pcs',
        spec: 'Type L, 6m',
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a non-empty PDF for a normal request', () async {
    final bytes = await buildRequestReceiptPdf(
      _request(notes: 'Required before the Thursday pour.'),
      PdfPageFormat.a4,
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  test('builds a PDF for a cancelled request (watermark path)', () async {
    final bytes = await buildRequestReceiptPdf(
      _request(status: RequestStatus.cancelled),
      PdfPageFormat.a4,
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  test('builds a multi-page PDF for a long item list', () async {
    final bytes = await buildRequestReceiptPdf(
      _request(lines: 60),
      PdfPageFormat.a4,
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  test('builds with no notes and no line items', () async {
    final bytes = await buildRequestReceiptPdf(
      _request(lines: 0),
      PdfPageFormat.a4,
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  test('builds with bilingual (Arabic) content via the font fallback', () async {
    final req = MaterialRequest(
      id: 'req-bilingual',
      projectName: 'Marina Bay — Chiller Plant',
      projectNameSecondary: 'مرسى الخليج — محطة التبريد',
      status: RequestStatus.dispatched,
      requestDate: DateTime(2026, 6, 12),
      itemCount: 1,
      priority: RequestPriority.normal,
      lineItems: const [
        RequestLineItem(
          materialId: 'mat-ar',
          materialName: 'Copper pipe 1 inch',
          materialNameSecondary: 'تانبے کا پائپ ۱ انچ',
          quantity: 25,
          unitSymbol: 'pcs',
          spec: 'Type L',
        ),
      ],
    );
    final bytes = await buildRequestReceiptPdf(req, PdfPageFormat.a4);
    expect(bytes.lengthInBytes, greaterThan(1000));
  });
}
