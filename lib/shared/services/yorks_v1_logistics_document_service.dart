import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_logistics.dart';
import '../models/yorks_v1_logistics_strings.dart';
import 'yorks_v1_boq_workbook_service.dart';

/// Generates operational-only exports from server-derived Delivery Order and
/// return snapshots. No cost or supplier-commercial fields can enter either
/// document because the typed inputs do not contain them.
class YorksV1LogisticsDocumentService {
  const YorksV1LogisticsDocumentService({
    this.workbookCodec = const YorksV1BoqWorkbookCodec(),
  });

  final YorksV1BoqWorkbookCodec workbookCodec;

  Uint8List buildDeliveryOrderExcel({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1DeliveryOrderDispatch dispatch,
    required YorksV1DeliveryOrderRevision revision,
  }) => _buildWorkbook(
    projectId: workspace.projectId,
    sourceId: revision.id,
    title: '${dispatch.deliveryOrder!.reference} R${revision.revisionNumber}',
    headings: [
      YorksV1LogisticsStrings.serialNumber.primary,
      YorksV1LogisticsStrings.itemDescription.primary,
      YorksV1LogisticsStrings.deliveryQuantity.primary,
      YorksV1LogisticsStrings.unit.primary,
    ],
    rows: [
      for (final line in revision.lines)
        [
          line.serialNumber.toString(),
          line.description,
          line.quantity,
          line.unit,
        ],
    ],
  );

  Uint8List buildMaterialReturnExcel({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1MaterialReturn materialReturn,
  }) => _buildWorkbook(
    projectId: workspace.projectId,
    sourceId: materialReturn.id,
    title:
        materialReturn.number ??
        YorksV1LogisticsStrings.materialReturns.primary,
    headings: [
      YorksV1LogisticsStrings.serialNumber.primary,
      YorksV1LogisticsStrings.itemDescription.primary,
      YorksV1LogisticsStrings.deliveryQuantity.primary,
      YorksV1LogisticsStrings.unit.primary,
    ],
    rows: [
      for (final line in materialReturn.lines)
        [
          line.displayOrder.toString(),
          line.description,
          line.returnQuantity,
          line.unit,
        ],
    ],
  );

  Future<void> printDeliveryOrder({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1DeliveryOrderDispatch dispatch,
    required YorksV1DeliveryOrderRevision revision,
  }) => Printing.layoutPdf(
    onLayout: (format) => buildDeliveryOrderPdf(
      workspace: workspace,
      dispatch: dispatch,
      revision: revision,
      format: format,
    ),
  );

  Future<void> printMaterialReturn({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1MaterialReturn materialReturn,
  }) => Printing.layoutPdf(
    onLayout: (format) => buildMaterialReturnPdf(
      workspace: workspace,
      materialReturn: materialReturn,
      format: format,
    ),
  );

  Future<Uint8List> buildDeliveryOrderPdf({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1DeliveryOrderDispatch dispatch,
    required YorksV1DeliveryOrderRevision revision,
    required PdfPageFormat format,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pdfHeader(
          YorksV1LogisticsStrings.deliveryOrder.primary,
          '${dispatch.deliveryOrder!.reference} · '
          '${YorksV1LogisticsStrings.revision.primary} ${revision.revisionNumber}',
        ),
        build: (_) => [
          _metadata([
            _PdfMeta(
              YorksV1LogisticsStrings.project.primary,
              workspace.projectName,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.scope.primary,
              workspace.scopeName,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.dispatchAndReceipt.primary,
              dispatch.dispatchNumber,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.revision.primary,
              revision.revisionNumber.toString(),
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.goodReceived.primary,
              DateFormat('d MMM yyyy').format(revision.generatedAt.toLocal()),
            ),
          ]),
          pw.SizedBox(height: 16),
          _table(
            headers: [
              YorksV1LogisticsStrings.serialNumber.primary,
              YorksV1LogisticsStrings.itemDescription.primary,
              YorksV1LogisticsStrings.deliveryQuantity.primary,
              YorksV1LogisticsStrings.unit.primary,
            ],
            rows: [
              for (final line in revision.lines)
                [
                  line.serialNumber.toString(),
                  line.description,
                  line.quantity,
                  line.unit,
                ],
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> buildMaterialReturnPdf({
    required YorksV1ReturnsDocumentsWorkspace workspace,
    required YorksV1MaterialReturn materialReturn,
    required PdfPageFormat format,
  }) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _pdfHeader(
          YorksV1LogisticsStrings.materialReturns.primary,
          materialReturn.number ??
              YorksV1LogisticsStrings.materialReturns.primary,
        ),
        build: (_) => [
          _metadata([
            _PdfMeta(
              YorksV1LogisticsStrings.project.primary,
              workspace.projectName,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.scope.primary,
              workspace.scopeName,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.state.primary,
              yorksV1MaterialReturnStateCopy(materialReturn.state).primary,
            ),
            _PdfMeta(
              YorksV1LogisticsStrings.draftedBy.primary,
              materialReturn.draftedByDisplayName,
            ),
          ]),
          if (materialReturn.note != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              materialReturn.note!,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 16),
          _table(
            headers: [
              YorksV1LogisticsStrings.serialNumber.primary,
              YorksV1LogisticsStrings.itemDescription.primary,
              YorksV1LogisticsStrings.deliveryQuantity.primary,
              YorksV1LogisticsStrings.unit.primary,
            ],
            rows: [
              for (final line in materialReturn.lines)
                [
                  line.displayOrder.toString(),
                  line.description,
                  line.returnQuantity,
                  line.unit,
                ],
            ],
          ),
        ],
      ),
    );
    return document.save();
  }

  String suggestedDeliveryOrderExcelName(
    YorksV1DeliveryOrder deliveryOrder,
    YorksV1DeliveryOrderRevision revision,
  ) => '${_safeName(deliveryOrder.reference)}_r${revision.revisionNumber}.xlsx';

  String suggestedMaterialReturnExcelName(
    YorksV1MaterialReturn materialReturn,
  ) => '${_safeName(materialReturn.number ?? 'material_return')}.xlsx';

  Uint8List _buildWorkbook({
    required String projectId,
    required String sourceId,
    required String title,
    required List<String> headings,
    required List<List<String>> rows,
  }) {
    final columns = [
      for (var index = 0; index < headings.length; index++)
        YorksV1BoqColumn(
          id: 'logistics_column_$index',
          heading: headings[index],
          displayOrder: index + 1,
        ),
    ];
    return workbookCodec.encodeWorksheet(
      YorksV1BoqWorksheet(
        group: YorksV1BoqGroup(
          id: sourceId,
          projectId: projectId,
          name: title,
          worksheetTitle: title,
          displayOrder: 1,
          isCustom: false,
          isArchived: false,
          version: 1,
          rowCount: rows.length,
          columnCount: columns.length,
          updatedAt: DateTime.now().toUtc(),
        ),
        columns: columns,
        rows: [
          for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
            YorksV1BoqRow(
              id: '$sourceId-$rowIndex',
              displayOrder: rowIndex + 1,
              values: {
                for (var column = 0; column < rows[rowIndex].length; column++)
                  'logistics_column_$column': rows[rowIndex][column],
              },
              canonicalValues: const {},
            ),
        ],
      ),
    );
  }

  static pw.Widget _pdfHeader(String title, String reference) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        YorksV1LogisticsStrings.companyName.primary,
        style: pw.TextStyle(
          color: PdfColor.fromInt(0xFF003FB1),
          fontSize: 14,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.Text(reference, style: const pw.TextStyle(fontSize: 9)),
      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ],
  );

  static pw.Widget _metadata(List<_PdfMeta> values) => pw.Wrap(
    spacing: 18,
    runSpacing: 6,
    children: [
      for (final value in values)
        pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '${value.label}: ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                ),
              ),
              pw.TextSpan(
                text: value.value,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
    ],
  );

  static pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
  }) => pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFE7EEF9),
    ),
    cellStyle: const pw.TextStyle(fontSize: 8.5),
    headers: headers,
    data: rows,
  );

  static String _safeName(String source) {
    final safe = source.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'logistics_document' : safe;
  }
}

class _PdfMeta {
  const _PdfMeta(this.label, this.value);
  final String label;
  final String value;
}
