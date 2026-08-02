import 'dart:typed_data';

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
    worksheetTitle: request.requestNumber ?? request.projectReference,
    version: request.recordVersion,
    updatedAt: request.updatedAt,
    lines: request.lines,
    includeCommercial: request.lines.any((line) => line.unitCost != null),
  );

  /// Exports the same controlled operational table while a request is still
  /// private and editable. Technical planning fields are retained as
  /// non-commercial supplemental columns; commercial values are never added to
  /// a draft export.
  Uint8List buildDraftExcel(YorksV1MaterialRequestDraft draft) => _buildExcel(
    id: draft.id,
    projectId: draft.projectId ?? 'draft',
    title: 'material_request_draft',
    worksheetTitle: 'Material Request Draft',
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
    final headings = <String>[
      YorksV1MaterialRequestStrings.rowNumber.primary,
      YorksV1MaterialRequestStrings.itemDescription.primary,
      YorksV1MaterialRequestStrings.size.primary,
      YorksV1MaterialRequestStrings.planningModelTag.primary,
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
        for (final line in lines)
          YorksV1BoqRow(
            id: line.id,
            displayOrder: line.displayOrder,
            values: {
              'mr_column_0': line.displayOrder.toString(),
              'mr_column_1': line.description,
              'mr_column_2': line.size ?? '',
              'mr_column_3': line.planningModelTag ?? '',
              'mr_column_4': line.brandOrigin ?? '',
              'mr_column_5': line.quantity,
              'mr_column_6': line.unit,
              if (includeCommercial) 'mr_column_7': line.unitCost ?? '',
              if (includeCommercial) 'mr_column_8': line.totalCost ?? '',
            },
            canonicalValues: const {},
          ),
      ],
    );
    return workbookCodec.encodeWorksheet(worksheet);
  }

  String suggestedExcelName(YorksV1MaterialRequest request) =>
      '${_safeName(request.requestNumber ?? request.projectReference)}.xlsx';

  String suggestedDraftExcelName(YorksV1MaterialRequestDraft draft) =>
      'material_request_draft_${_safeName(draft.id)}.xlsx';

  Future<void> printPdf(YorksV1MaterialRequest request) =>
      Printing.layoutPdf(onLayout: (format) => buildPdf(request, format));

  Future<Uint8List> buildPdf(
    YorksV1MaterialRequest request,
    PdfPageFormat format,
  ) async {
    final dateFormat = DateFormat('d MMM yyyy');
    final commercial = request.lines.any((line) => line.unitCost != null);
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              YorksV1MaterialRequestStrings.companyName.primary,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFF003FB1),
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              request.requestNumber ??
                  YorksV1MaterialRequestStrings.materialRequestDraft.primary,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
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
              YorksV1MaterialRequestStrings.size.primary,
              YorksV1MaterialRequestStrings.planningModelTag.primary,
              YorksV1MaterialRequestStrings.brandOrigin.primary,
              YorksV1MaterialRequestStrings.quantity.primary,
              YorksV1MaterialRequestStrings.unit.primary,
              if (commercial) YorksV1MaterialRequestStrings.unitCost.primary,
              if (commercial) YorksV1MaterialRequestStrings.totalCost.primary,
            ],
            data: [
              for (final line in request.lines)
                [
                  line.displayOrder.toString(),
                  line.description,
                  line.size ?? '',
                  line.planningModelTag ?? '',
                  line.brandOrigin ?? '',
                  line.quantity,
                  line.unit,
                  if (commercial) line.unitCost ?? '',
                  if (commercial) line.totalCost ?? '',
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

  static String _safeName(String source) {
    final safe = source.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'material_request' : safe;
  }
}
