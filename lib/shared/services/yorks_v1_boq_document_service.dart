import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_boq_strings.dart';
import '../models/yorks_v1_material_request_strings.dart';

/// Prints the exact role-safe BOQ projection already held by the caller.
class YorksV1BoqDocumentService {
  const YorksV1BoqDocumentService();

  Future<void> printWorksheet(
    YorksV1BoqWorksheet worksheet, {
    required bool canViewCommercials,
    bool draftCopy = false,
  }) async {
    final bytes = await buildPdf(
      [worksheet],
      canViewCommercials: canViewCommercials,
      draftCopy: draftCopy,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> printScope(
    List<YorksV1BoqWorksheet> worksheets, {
    required bool canViewCommercials,
  }) async {
    final bytes = await buildPdf(
      worksheets,
      canViewCommercials: canViewCommercials,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> buildPdf(
    List<YorksV1BoqWorksheet> worksheets, {
    required bool canViewCommercials,
    bool draftCopy = false,
    DateTime? generatedAt,
  }) async {
    final generated = (generatedAt ?? DateTime.now()).toUtc();
    final document = pw.Document(
      theme: await _theme(),
      title: 'Yorks Bill of Quantities',
      author: YorksV1MaterialRequestStrings.companyLegalName.primary,
      creator: 'Yorks Project Management',
    );
    final logo = await _logo();
    for (final worksheet in worksheets) {
      final columns = worksheet.columns
          .where((column) => canViewCommercials || !column.isCommercial)
          .toList(growable: false);
      document.addPage(
        pw.MultiPage(
          pageTheme: _pageTheme(draftCopy),
          header: (_) => _header(
            logo,
            worksheet,
            draftCopy: draftCopy,
            generatedAt: generated,
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${YorksV1BoqStrings.page.primary} ${context.pageNumber} '
              '${YorksV1BoqStrings.of.primary} ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ),
          build: (_) => [
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: [
                YorksV1BoqStrings.serialNumber.primary,
                for (final column in columns) column.heading,
              ],
              data: [
                for (
                  var rowIndex = 0;
                  rowIndex < worksheet.rows.length;
                  rowIndex++
                )
                  [
                    '${rowIndex + 1}',
                    for (final column in columns)
                      _value(worksheet.rows[rowIndex].valueFor(column.id)),
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey700, width: .5),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
            ),
          ],
        ),
      );
    }
    return document.save(enableEventLoopBalancing: true);
  }

  static pw.Widget _header(
    pw.MemoryImage logo,
    YorksV1BoqWorksheet worksheet, {
    required bool draftCopy,
    required DateTime generatedAt,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey800),
        ),
        child: pw.Row(
          children: [
            pw.Image(logo, width: 44, height: 44),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    YorksV1MaterialRequestStrings.companyLegalName.primary,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    YorksV1BoqStrings.boq.primary.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        '${YorksV1BoqStrings.folderName.primary}: ${worksheet.group.name}',
        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
      ),
      if (worksheet.group.worksheetTitle.trim().isNotEmpty &&
          worksheet.group.worksheetTitle.trim() != worksheet.group.name.trim())
        pw.Text(
          '${YorksV1BoqStrings.worksheetTitle.primary}: '
          '${worksheet.group.worksheetTitle.trim()}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      if (worksheet.group.scopeName?.trim().isNotEmpty == true)
        pw.Text(
          worksheet.group.scopeName!,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      pw.Text(
        '${YorksV1BoqStrings.revision.primary}: '
        '${worksheet.group.version}  ·  '
        '${YorksV1BoqStrings.generated.primary}: '
        '${generatedAt.toIso8601String()}',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
      if (draftCopy)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'DRAFT',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red700,
            ),
          ),
        ),
    ],
  );

  static pw.PageTheme _pageTheme(bool draftCopy) => pw.PageTheme(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(24),
    buildBackground: draftCopy
        ? (_) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Center(
              child: pw.Transform.rotate(
                angle: -.45,
                child: pw.Opacity(
                  opacity: .08,
                  child: pw.Text(
                    'DRAFT',
                    style: pw.TextStyle(
                      fontSize: 82,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.red700,
                    ),
                  ),
                ),
              ),
            ),
          )
        : null,
  );

  static String _value(Object? value) => value == null ? '' : '$value';

  static Future<pw.MemoryImage>? _logoFuture;
  static Future<pw.ThemeData>? _themeFuture;

  static Future<pw.MemoryImage> _logo() => _logoFuture ??= () async {
    final data = await rootBundle.load('assets/logo.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }();

  static Future<pw.ThemeData> _theme() => _themeFuture ??= () async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final arabic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
      fontFallback: [arabic],
    );
  }();
}
