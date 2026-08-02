import 'package:flutter/services.dart';
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
    final logo = await _loadLogo();
    final theme = await _buildTheme();
    final deliveryOrder = dispatch.deliveryOrder!;
    final document = pw.Document(theme: theme);
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 28),
        header: (_) => _deliveryHeader(logo),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              YorksV1LogisticsStrings.deliveryOrderTitle.primary,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          _deliveryMetaBox(
            recipient: workspace.projectName,
            reference: deliveryOrder.reference,
            date: DateFormat(
              'dd/MM/yyyy',
            ).format(dispatch.dispatchDate.toLocal()),
          ),
          pw.SizedBox(height: 10),
          _deliveryProjectBox(workspace),
          pw.SizedBox(height: 14),
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
          pw.SizedBox(height: 22),
          _deliverySignatures(),
          pw.SizedBox(height: 14),
          pw.Center(
            child: pw.Text(
              YorksV1LogisticsStrings.goodsReceivedInGoodCondition.primary,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            ),
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

  static Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static Future<pw.ThemeData?> _buildTheme() async {
    try {
      final base = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );
      final arabic = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
      );
      return pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [arabic],
      );
    } catch (_) {
      return null;
    }
  }

  static pw.Widget _deliveryHeader(pw.MemoryImage? logo) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: .7)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            'Yorks Airconditioning & Refrigeration LLC-SPC',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (logo != null) pw.Image(logo, width: 58, height: 58),
        pw.Expanded(
          child: pw.Text(
            'يوركس للتكييف والتبريد',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _deliveryMetaBox({
    required String recipient,
    required String reference,
    required String date,
  }) => pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
    child: pw.Table(
      border: pw.TableBorder.symmetric(inside: const pw.BorderSide(width: .5)),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(2.8),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.7),
      },
      children: [
        pw.TableRow(
          children: [
            _pdfCell(YorksV1LogisticsStrings.recipient.primary, bold: true),
            _pdfCell(recipient),
            _pdfCell(YorksV1LogisticsStrings.reference.primary, bold: true),
            _pdfCell(reference),
          ],
        ),
        pw.TableRow(
          children: [
            _pdfCell(YorksV1LogisticsStrings.date.primary, bold: true),
            _pdfCell(date),
            _pdfCell(
              YorksV1LogisticsStrings.deliveryOrderTitle.primary,
              bold: true,
            ),
            _pdfCell('R35'),
          ],
        ),
      ],
    ),
  );

  static pw.Widget _deliveryProjectBox(
    YorksV1ReturnsDocumentsWorkspace workspace,
  ) => pw.Container(
    width: double.infinity,
    decoration: pw.BoxDecoration(border: pw.Border.all(width: .7)),
    padding: const pw.EdgeInsets.all(7),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfLabelValue(
          YorksV1LogisticsStrings.project.primary,
          workspace.projectName,
        ),
        pw.SizedBox(height: 4),
        _pdfLabelValue(
          YorksV1LogisticsStrings.deliveryAddress.primary,
          workspace.scopeName,
        ),
      ],
    ),
  );

  static pw.Widget _deliverySignatures() => pw.Table(
    border: pw.TableBorder.all(width: .5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.4),
      1: pw.FlexColumnWidth(1.6),
      2: pw.FlexColumnWidth(1.4),
      3: pw.FlexColumnWidth(1.6),
    },
    children: [
      pw.TableRow(
        children: [
          _pdfCell(
            YorksV1LogisticsStrings.inspectedAndChecked.primary,
            bold: true,
          ),
          _pdfCell(''),
          _pdfCell(YorksV1LogisticsStrings.receiverName.primary, bold: true),
          _pdfCell(''),
        ],
      ),
      pw.TableRow(
        children: [
          _pdfCell(YorksV1LogisticsStrings.signature.primary, bold: true),
          _pdfCell(''),
          _pdfCell(YorksV1LogisticsStrings.signature.primary, bold: true),
          _pdfCell(''),
        ],
      ),
    ],
  );

  static pw.Widget _pdfCell(String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      value,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: bold ? pw.FontWeight.bold : null,
      ),
    ),
  );

  static pw.Widget _pdfLabelValue(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
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
