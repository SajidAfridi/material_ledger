import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/workforce_report_models.dart';

abstract interface class YorksWorkforceReportBinaryService {
  Uint8List buildExcel(YorksWorkforceReportArtifact report);
  Future<Uint8List> buildPdf(YorksWorkforceReportArtifact report);
  Future<void> saveExcelBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  );
  Future<void> savePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  );
  Future<void> printPdfBytes(Uint8List bytes);
  Future<void> sharePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  );
}

final class YorksWorkforceReportService
    implements YorksWorkforceReportBinaryService {
  const YorksWorkforceReportService();

  static const xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const pdfMimeType = 'application/pdf';

  @override
  Uint8List buildExcel(YorksWorkforceReportArtifact report) =>
      _WorkforceWorkbookWriter.encode(report);

  @override
  Future<Uint8List> buildPdf(YorksWorkforceReportArtifact report) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
    );
    final arabic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'),
    );
    final document = pw.Document(
      title: title(report.kind),
      author: report.generatedBy,
      subject: 'Yorks protected Workforce report',
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [arabic],
      ),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormatFor(report),
        margin: const pw.EdgeInsets.fromLTRB(26, 30, 26, 62),
        header: (_) => _pdfHeader(report),
        footer: (context) => _pdfFooter(report, context),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: report.columns.map((column) => column.label).toList(),
            data: [
              for (final row in report.rows)
                [
                  for (final column in report.columns)
                    _displayCell(row[column.key], column.type),
                ],
            ],
            headerDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#12365F'),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 7,
            ),
            cellStyle: const pw.TextStyle(fontSize: 6.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3.5,
              vertical: 4,
            ),
            border: pw.TableBorder.all(
              color: PdfColor.fromHex('#D7E0EB'),
              width: .45,
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  @override
  Future<void> saveExcelBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) => _save(
    bytes,
    fileName(report, 'xlsx'),
    xlsxMimeType,
    const XTypeGroup(
      label: 'Excel workbook',
      extensions: ['xlsx'],
      mimeTypes: [xlsxMimeType],
    ),
  );

  @override
  Future<void> savePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) => _save(
    bytes,
    fileName(report, 'pdf'),
    pdfMimeType,
    const XTypeGroup(
      label: 'PDF document',
      extensions: ['pdf'],
      mimeTypes: [pdfMimeType],
    ),
  );

  @override
  Future<void> printPdfBytes(Uint8List bytes) =>
      Printing.layoutPdf(onLayout: (_) async => bytes);

  @override
  Future<void> sharePdfBytes(
    Uint8List bytes,
    YorksWorkforceReportArtifact report,
  ) => Printing.sharePdf(bytes: bytes, filename: fileName(report, 'pdf'));

  String fileName(YorksWorkforceReportArtifact report, String extension) {
    final scope = _token(report.scopeReference);
    final date = DateFormat('yyyy-MM-dd').format(report.generatedAt.toUtc());
    return 'Yorks_Workforce_${_token(report.kind.wire)}_${scope}_$date.$extension';
  }

  static String title(YorksWorkforceReportKind kind) => kind.wire
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  static PdfPageFormat pageFormatFor(YorksWorkforceReportArtifact report) =>
      switch (report.kind) {
        YorksWorkforceReportKind.workerMonthlyTimesheet ||
        YorksWorkforceReportKind.supervisorTeamMonthly =>
          PdfPageFormat.a4.landscape,
        YorksWorkforceReportKind.dailyAttendanceRegister ||
        YorksWorkforceReportKind.projectWorkforce ||
        YorksWorkforceReportKind.companyWorkforceSummary =>
          report.columns.length > 8
              ? PdfPageFormat.a4.landscape
              : PdfPageFormat.a4,
        _ => PdfPageFormat.a4,
      };

  static List<String> approvedHeaderLines(YorksWorkforceReportArtifact report) {
    if (!report.isApproved || report.periodMonth == null) {
      return [
        report.companyLegalName,
        report.companySecondaryName,
        title(report.kind),
      ];
    }
    final month = DateFormat(
      'MMMM yyyy',
    ).format(DateTime.parse(report.periodMonth!));
    return [
      report.companyLegalName,
      report.companySecondaryName,
      'MONTHLY TIMESHEET',
      month,
    ];
  }

  static List<(String, String)> approvalFooterEvidence(
    YorksWorkforceReportArtifact report,
  ) {
    final evidence = <(String, String)>[
      (
        'Prepared By',
        '${report.generatedBy} (${report.generatedByRole}) · '
            '${report.generatedAt.toUtc().toIso8601String()}',
      ),
    ];
    if (report.isApproved) {
      final reviews = <String>[];
      final approvals = <String>[];
      final approvalDates = <String>[];
      final revisions = <String>[];
      for (final source in report.sources) {
        for (final value in List<Object?>.from(
          source['review_chain'] as List,
        )) {
          final transition = Map<String, dynamic>.from(value as Map);
          reviews.add(
            '${transition['actor']} (${transition['role']}) · '
            '${transition['action']} · ${transition['at']}',
          );
          approvalDates.add('${transition['action']} ${transition['at']}');
        }
        approvals.add('${source['approved_by']} (${source['approved_role']})');
        approvalDates.add('approved ${source['approved_at']}');
        revisions.add('R${source['approval_revision_number']}');
      }
      evidence
        ..add(('Reviewed By', reviews.isEmpty ? '—' : reviews.join('; ')))
        ..add(('Approved By', approvals.toSet().join('; ')))
        ..add(('Approval Dates', approvalDates.join('; ')))
        ..add(('Revision', revisions.toSet().join(', ')));
    }
    return List.unmodifiable(evidence);
  }

  static Future<void> _save(
    Uint8List bytes,
    String suggestedName,
    String mimeType,
    XTypeGroup type,
  ) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: [type],
    );
    if (location == null) return;
    await XFile.fromData(
      bytes,
      mimeType: mimeType,
      name: suggestedName,
    ).saveTo(location.path);
  }

  static pw.Widget _pdfHeader(YorksWorkforceReportArtifact report) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                report.companyLegalName,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#12365F'),
                  fontSize: 10,
                ),
              ),
              pw.Text(
                report.companySecondaryName,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#475467'),
                  fontSize: 7.5,
                ),
              ),
            ],
          ),
          pw.Text(
            report.isApproved ? 'APPROVED · LOCKED' : 'CURRENT · NOT APPROVED',
            style: pw.TextStyle(
              color: report.isApproved
                  ? PdfColor.fromHex('#087A55')
                  : PdfColor.fromHex('#B54708'),
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        report.isApproved ? 'MONTHLY TIMESHEET' : title(report.kind),
        style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
      ),
      if (report.isApproved && report.periodMonth != null)
        pw.Text(
          DateFormat('MMMM yyyy').format(DateTime.parse(report.periodMonth!)),
          style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475467')),
        ),
      pw.Text(
        'Source ${report.sourceVersion} · SHA-256 ${report.sourceHash}',
        style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#667085')),
      ),
      pw.SizedBox(height: 8),
    ],
  );

  static pw.Widget _pdfFooter(
    YorksWorkforceReportArtifact report,
    pw.Context context,
  ) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Divider(color: PdfColor.fromHex('#D7E0EB'), height: 4),
      for (final evidence in approvalFooterEvidence(report))
        pw.Text(
          '${evidence.$1}: ${evidence.$2}',
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: const pw.TextStyle(fontSize: 5.5),
        ),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            report.isApproved
                ? 'Approved and locked Workforce source'
                : 'Current operational data · Not approved',
            style: const pw.TextStyle(fontSize: 5.5),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 5.5),
          ),
        ],
      ),
    ],
  );

  static List<(String, String)> _sourceEvidence(
    YorksWorkforceReportArtifact report,
  ) {
    if (!report.isApproved) return const [];
    final evidence = <(String, String)>[];
    for (final source in report.sources) {
      for (final value in List<Object?>.from(source['review_chain'] as List)) {
        final transition = Map<String, dynamic>.from(value as Map);
        evidence.add((
          transition['action']! as String,
          '${transition['actor']} (${transition['role']}) · ${transition['at']}',
        ));
      }
      evidence.add((
        'approved_locked',
        '${source['approved_by']} (${source['approved_role']}) · '
            '${source['approved_at']} · R${source['approval_revision_number']}',
      ));
    }
    return List.unmodifiable(evidence);
  }

  static String _displayCell(
    Object? value,
    YorksWorkforceReportColumnType type,
  ) {
    if (value == null) return '—';
    if (type == YorksWorkforceReportColumnType.decimal && value is num) {
      return value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return value.toString();
  }

  static String _token(String value) {
    final token = value
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return token.isEmpty ? 'Report' : token;
  }
}

final class _WorkforceWorkbookWriter {
  static Uint8List encode(YorksWorkforceReportArtifact report) {
    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook))
      ..addFile(ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRels))
      ..addFile(ArchiveFile.string('xl/styles.xml', _styles))
      ..addFile(
        ArchiveFile.string('xl/worksheets/sheet1.xml', _dataSheet(report)),
      )
      ..addFile(
        ArchiveFile.string('xl/worksheets/sheet2.xml', _sourceSheet(report)),
      );
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _dataSheet(YorksWorkforceReportArtifact report) {
    final out = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"><pane xSplit="2" ySplit="1" '
      'topLeftCell="C2" activePane="bottomRight" state="frozen"/></sheetView>'
      '</sheetViews><sheetData>',
    );
    out.write('<row r="1">');
    for (var index = 0; index < report.columns.length; index++) {
      out.write(_textCell(index, 1, report.columns[index].label, 1));
    }
    out.write('</row>');
    for (var rowIndex = 0; rowIndex < report.rows.length; rowIndex++) {
      final sheetRow = rowIndex + 2;
      out.write('<row r="$sheetRow">');
      for (
        var columnIndex = 0;
        columnIndex < report.columns.length;
        columnIndex++
      ) {
        final column = report.columns[columnIndex];
        final value = report.rows[rowIndex][column.key];
        out.write(_cell(columnIndex, sheetRow, value, column.type));
      }
      out.write('</row>');
    }
    final lastColumn = _column(report.columns.length - 1);
    final lastRow = report.rows.length + 1;
    out.write(
      '</sheetData><autoFilter ref="A1:$lastColumn$lastRow"/>'
      '<sheetProtection sheet="false" objects="false" scenarios="false"/>'
      '</worksheet>',
    );
    return out.toString();
  }

  static String _sourceSheet(YorksWorkforceReportArtifact report) {
    final entries = <(String, String)>[
      ('Report', YorksWorkforceReportService.title(report.kind)),
      ('Company', report.companyLegalName),
      ('Secondary company name', report.companySecondaryName),
      ('Source status', report.sourceStatus),
      ('Source version', report.sourceVersion),
      ('Source SHA-256', report.sourceHash),
      ('Generated by', report.generatedBy),
      ('Generated role', report.generatedByRole),
      ('Generated at', report.generatedAt.toUtc().toIso8601String()),
      ('Artifact ID', report.artifactId),
      ('Rows', report.totals.rowCount.toString()),
      ...YorksWorkforceReportService._sourceEvidence(report),
    ];
    final out = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetViews><sheetView workbookViewId="0"/></sheetViews><sheetData>',
    );
    for (var index = 0; index < entries.length; index++) {
      final row = index + 1;
      out
        ..write('<row r="$row">')
        ..write(_textCell(0, row, entries[index].$1, index == 0 ? 1 : 2))
        ..write(_textCell(1, row, entries[index].$2, index == 0 ? 1 : 2))
        ..write('</row>');
    }
    out.write('</sheetData></worksheet>');
    return out.toString();
  }

  static String _cell(
    int column,
    int row,
    Object? value,
    YorksWorkforceReportColumnType type,
  ) {
    if (value == null) return _textCell(column, row, '', 2);
    return switch (type) {
      YorksWorkforceReportColumnType.text => _textCell(
        column,
        row,
        _safeText(value.toString()),
        2,
      ),
      YorksWorkforceReportColumnType.date =>
        '<c r="${_column(column)}$row" s="3"><v>${_excelDate(value.toString())}</v></c>',
      YorksWorkforceReportColumnType.integer =>
        '<c r="${_column(column)}$row" s="4"><v>$value</v></c>',
      YorksWorkforceReportColumnType.decimal =>
        '<c r="${_column(column)}$row" s="5"><v>$value</v></c>',
    };
  }

  static String _textCell(int column, int row, String value, int style) =>
      '<c r="${_column(column)}$row" s="$style" t="inlineStr"><is><t '
      'xml:space="preserve">${_xml(value)}</t></is></c>';

  static int _excelDate(String value) => DateTime.parse(
    value,
  ).toUtc().difference(DateTime.utc(1899, 12, 30)).inDays;

  static String _safeText(String value) {
    final normalized = value.replaceAll('\u0000', '');
    return RegExp(r'^[=+\-@]').hasMatch(normalized)
        ? "'$normalized"
        : normalized;
  }

  static const _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '</Relationships>';

  static const _workbook =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Report" sheetId="1" r:id="rId1"/>'
      '<sheet name="Source &amp; approval" sheetId="2" r:id="rId2"/></sheets>'
      '</workbook>';

  static const _workbookRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/>'
      '<numFmt numFmtId="165" formatCode="0.####"/></numFmts>'
      '<fonts count="2"><font><sz val="10"/><name val="Aptos"/></font>'
      '<font><b/><color rgb="FFFFFFFF"/><sz val="10"/><name val="Aptos"/></font></fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF12365F"/></patternFill></fill></fills>'
      '<borders count="2"><border/><border><left style="thin"><color rgb="FFD7E0EB"/></left>'
      '<right style="thin"><color rgb="FFD7E0EB"/></right><top style="thin"><color rgb="FFD7E0EB"/></top>'
      '<bottom style="thin"><color rgb="FFD7E0EB"/></bottom></border></borders>'
      '<cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="6"><xf/>'
      '<xf fontId="1" fillId="2" borderId="1" applyFont="1" applyFill="1" applyBorder="1"/>'
      '<xf borderId="1" applyBorder="1"/><xf numFmtId="164" borderId="1" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="1" borderId="1" applyNumberFormat="1" applyBorder="1"/>'
      '<xf numFmtId="165" borderId="1" applyNumberFormat="1" applyBorder="1"/>'
      '</cellXfs></styleSheet>';

  static String _column(int index) {
    var value = index + 1;
    var result = '';
    while (value > 0) {
      value--;
      result = String.fromCharCode(65 + value % 26) + result;
      value ~/= 26;
    }
    return result;
  }

  static String _xml(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
