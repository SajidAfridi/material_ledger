import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_material_request_strings.dart';
import 'yorks_v1_boq_workbook_service.dart';

/// Produces a controlled MR export from the role-safe projection already held
/// by the caller. Commercial fields are included only when the server supplied
/// them; the service never looks up or reconstructs cost data locally.
class YorksV1MaterialRequestDocumentService {
  const YorksV1MaterialRequestDocumentService({
    this.workbookCodec = const YorksV1BoqWorkbookCodec(),
  });

  final YorksV1BoqWorkbookCodec workbookCodec;

  Uint8List buildExcel(YorksV1MaterialRequest request) => _buildExcel(
    id: request.id,
    projectId: request.projectId,
    title: request.requestNumber ?? request.projectReference,
    worksheetTitle: 'Material Request',
    version: request.recordVersion,
    updatedAt: request.updatedAt,
    lines: request.lines,
    includeCommercial: request.lines.any((line) => line.unitCost != null),
  );

  /// Exports the same controlled operational table while a request is still
  /// private and editable. Technical planning context is carried in the
  /// Item Description cell so the controlled workbook never grows BOQ-only
  /// columns, and commercial values are never added to a draft export.
  Uint8List buildDraftExcel(YorksV1MaterialRequestDraft draft) => _buildExcel(
    id: draft.id,
    projectId: draft.projectId ?? 'draft',
    title: 'Material Request',
    worksheetTitle: 'Material Request',
    version: draft.serverRecordVersion,
    updatedAt: draft.updatedAt,
    lines: draft.lines,
    includeCommercial: false,
  );

  Uint8List _buildExcel({
    required String id,
    required String projectId,
    required String title,
    required String worksheetTitle,
    required int version,
    required DateTime updatedAt,
    required List<YorksV1MaterialRequestLine> lines,
    required bool includeCommercial,
  }) {
    // Engineer projections intentionally omit commercial columns. When a
    // server-authorized commercial projection is supplied, the controlled
    // order is exactly: R No, Item Description, Brand/Origin, Qty, Unit,
    // Unit Cost, Total Cost.
    final headings = <String>[
      YorksV1MaterialRequestStrings.rowNumber.primary,
      YorksV1MaterialRequestStrings.itemDescription.primary,
      YorksV1MaterialRequestStrings.brandOrigin.primary,
      YorksV1MaterialRequestStrings.quantity.primary,
      YorksV1MaterialRequestStrings.unit.primary,
      if (includeCommercial) YorksV1MaterialRequestStrings.unitCost.primary,
      if (includeCommercial) YorksV1MaterialRequestStrings.totalCost.primary,
    ];
    final columns = [
      for (var index = 0; index < headings.length; index++)
        YorksV1BoqColumn(
          id: 'mr_column_$index',
          heading: headings[index],
          displayOrder: index + 1,
        ),
    ];
    final worksheet = YorksV1BoqWorksheet(
      group: YorksV1BoqGroup(
        id: id,
        projectId: projectId,
        name: title,
        worksheetTitle: worksheetTitle,
        displayOrder: 1,
        isCustom: false,
        isArchived: false,
        version: version,
        rowCount: lines.length,
        columnCount: columns.length,
        updatedAt: updatedAt,
      ),
      columns: columns,
      rows: [
        for (var index = 0; index < lines.length; index++)
          // R No is a presentation sequence, never an internal identifier.
          // Re-numbering here keeps exports consecutive after line deletes or
          // server-side ordering changes.
          YorksV1BoqRow(
            id: lines[index].id,
            displayOrder: index + 1,
            values: {
              'mr_column_0': (index + 1).toString(),
              'mr_column_1': _displayDescription(lines[index]),
              'mr_column_2': lines[index].brandOrigin ?? '',
              'mr_column_3': lines[index].quantity,
              'mr_column_4': lines[index].unit,
              if (includeCommercial) 'mr_column_5': lines[index].unitCost ?? '',
              if (includeCommercial)
                'mr_column_6':
                    _calculatedTotal(lines[index]) ??
                    lines[index].totalCost ??
                    '',
            },
            canonicalValues: const {},
          ),
      ],
    );
    return workbookCodec.encodeWorksheet(worksheet);
  }

  String suggestedExcelName(YorksV1MaterialRequest request) =>
      '${_safeName(request.requestNumber ?? request.projectReference)}_Material_Request.xlsx';

  String suggestedDraftExcelName(YorksV1MaterialRequestDraft draft) =>
      'Material_Request_Draft_${_safeName(draft.id)}.xlsx';

  Future<void> printPdf(YorksV1MaterialRequest request) =>
      Printing.layoutPdf(onLayout: (_) => buildPdf(request, PdfPageFormat.a4));

  Future<Uint8List> buildPdf(
    YorksV1MaterialRequest request,
    PdfPageFormat format,
  ) async {
    final dateFormat = DateFormat('d MMM yyyy');
    final commercial = request.lines.any((line) => line.unitCost != null);
    final theme = await _buildTheme();
    final logo = await _loadLogo();
    final document = pw.Document(theme: theme);
    document.addPage(
      pw.MultiPage(
        // Material Requests always print as the controlled A4 portrait
        // document, regardless of the printer's last-used format.
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 34),
        header: (_) => _pdfHeader(logo),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${YorksV1MaterialRequestStrings.companyName.primary} · ${request.requestNumber ?? YorksV1MaterialRequestStrings.materialRequestDraft.primary} · ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        build: (_) => [
          pw.SizedBox(height: 18),
          pw.Text(
            YorksV1MaterialRequestStrings.materialRequest.primary,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _meta(
                YorksV1MaterialRequestStrings.project.primary,
                '${request.projectReference} · ${request.projectName}',
              ),
              _meta(
                YorksV1MaterialRequestStrings.scope.primary,
                request.scopeName,
              ),
              _meta(
                YorksV1MaterialRequestStrings.timing.primary,
                yorksV1MaterialRequestTimingCopy(request.timing).primary,
              ),
              if (request.scheduledDate != null)
                _meta(
                  YorksV1MaterialRequestStrings.scheduledDate.primary,
                  dateFormat.format(request.scheduledDate!),
                ),
              _meta(
                YorksV1MaterialRequestStrings.state.primary,
                yorksV1MaterialRequestStateCopy(request.state).primary,
              ),
              if (request.requesterDisplayName != null)
                _meta(
                  YorksV1MaterialRequestStrings.requester.primary,
                  request.requesterDisplayName!,
                ),
              if (request.currentActionOwnerRole != null)
                _meta(
                  YorksV1MaterialRequestStrings.currentOwner.primary,
                  request.currentActionOwnerRole!,
                ),
            ],
          ),
          if (request.title != null) ...[
            pw.SizedBox(height: 12),
            pw.Text(request.title!, style: const pw.TextStyle(fontSize: 11)),
          ],
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFE7EEF9),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: [
              YorksV1MaterialRequestStrings.rowNumber.primary,
              YorksV1MaterialRequestStrings.itemDescription.primary,
              YorksV1MaterialRequestStrings.brandOrigin.primary,
              YorksV1MaterialRequestStrings.quantity.primary,
              YorksV1MaterialRequestStrings.unit.primary,
              if (commercial) YorksV1MaterialRequestStrings.unitCost.primary,
              if (commercial) YorksV1MaterialRequestStrings.totalCost.primary,
            ],
            data: [
              for (var index = 0; index < request.lines.length; index++)
                [
                  (index + 1).toString(),
                  _displayDescription(request.lines[index]),
                  request.lines[index].brandOrigin ?? '',
                  request.lines[index].quantity,
                  request.lines[index].unit,
                  if (commercial) request.lines[index].unitCost ?? '',
                  if (commercial)
                    _calculatedTotal(request.lines[index]) ??
                        request.lines[index].totalCost ??
                        '',
                ],
            ],
          ),
          if (request.deliveryNote != null) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              YorksV1MaterialRequestStrings.deliveryNoteLabel.primary,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(request.deliveryNote!),
          ],
        ],
      ),
    );
    return document.save();
  }

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

  static pw.Widget _pdfHeader(pw.MemoryImage? logo) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(width: .7)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                YorksV1MaterialRequestStrings.companyLegalName.primary,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                YorksV1MaterialRequestStrings.materialRequest.primary,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        pw.SizedBox(
          width: 56,
          child: logo == null
              ? pw.SizedBox()
              : pw.Center(child: pw.Image(logo, width: 42, height: 42)),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              YorksV1MaterialRequestStrings.companyName.ar,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8),
            ),
          ),
        ),
      ],
    ),
  );

  static pw.Widget _meta(String label, String value) => pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label: ',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        ),
        pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 9)),
      ],
    ),
  );

  static String _displayDescription(YorksV1MaterialRequestLine line) {
    final details = <String>[
      if (line.size?.trim().isNotEmpty ?? false) 'Size: ${line.size!.trim()}',
      if (line.planningModelTag?.trim().isNotEmpty ?? false)
        'Model / Tag: ${line.planningModelTag!.trim()}',
    ];
    if (details.isEmpty) return line.description;
    return '${line.description.trim()}\n${details.join('\n')}';
  }

  static String? _calculatedTotal(YorksV1MaterialRequestLine line) {
    final qty = double.tryParse(line.quantity.trim());
    final cost = double.tryParse(line.unitCost?.trim() ?? '');
    if (qty == null || cost == null) return null;
    return (qty * cost).toStringAsFixed(2);
  }

  static String _safeName(String source) {
    final safe = source.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'material_request' : safe;
  }
}
