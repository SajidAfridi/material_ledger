import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/accounts_records_models.dart';

class YorksAccountsReportService {
  const YorksAccountsReportService();

  static const xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  static const pdfMimeType = 'application/pdf';

  Uint8List buildExcel(
    YorksAccountsReportProjection report, {
    List<YorksAccountsReportProjection> companionReports = const [],
  }) => _AccountsWorkbookWriter.encode([
    report,
    ...companionReports.where(
      (candidate) => candidate.reportKind != report.reportKind,
    ),
  ]);

  Future<Uint8List> buildPdf(
    YorksAccountsReportProjection report, {
    List<YorksAccountsReportProjection> companionReports = const [],
  }) async {
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
      title: _documentTitle(
        report,
        completeProjectBackup: companionReports.isNotEmpty,
      ),
      author: report.generatedByDisplayName,
      subject: 'Yorks protected Accounts report',
      theme: pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        fontFallback: [arabic],
      ),
    );
    final generated = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(report.generatedAt.toLocal());
    final reports = [
      report,
      ...companionReports.where(
        (candidate) => candidate.reportKind != report.reportKind,
      ),
    ];

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 26),
        header: (context) => _pdfHeader(
          report,
          generated,
          completeProjectBackup: reports.length > 1,
        ),
        footer: _pdfFooter,
        build: (_) => [
          if (report.reportKind == 'project_summary') ...[
            _pdfProjectSummary(report),
            pw.SizedBox(height: 18),
          ] else
            ..._pdfReportWidgets(report),
          for (final companion in reports.skip(1)) ...[
            pw.NewPage(),
            ..._pdfReportWidgets(companion),
          ],
        ],
      ),
    );
    return document.save();
  }

  Future<void> printPdf(
    YorksAccountsReportProjection report, {
    List<YorksAccountsReportProjection> companionReports = const [],
  }) async {
    final bytes = await buildPdf(report, companionReports: companionReports);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  String excelFileName(
    YorksAccountsReportProjection report, {
    bool completeProjectBackup = false,
  }) =>
      '${_fileStem(report, completeProjectBackup: completeProjectBackup)}.xlsx';

  String pdfFileName(
    YorksAccountsReportProjection report, {
    bool completeProjectBackup = false,
  }) =>
      '${_fileStem(report, completeProjectBackup: completeProjectBackup)}.pdf';

  static pw.Widget _pdfHeader(
    YorksAccountsReportProjection report,
    String generated, {
    required bool completeProjectBackup,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 42,
            height: 42,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(7),
            ),
            child: pw.Text(
              'Y',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'YORKS AC. & REF.',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: _navy,
                    fontSize: 11,
                    letterSpacing: .4,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  _documentTitle(
                    report,
                    completeProjectBackup: completeProjectBackup,
                  ),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
                if (report.projectName != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    report.projectName!,
                    style: pw.TextStyle(fontSize: 9, color: _muted),
                  ),
                ],
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _paleBlue,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              report.accessContext.replaceAll('_', ' ').toUpperCase(),
              style: pw.TextStyle(
                color: _blue,
                fontWeight: pw.FontWeight.bold,
                fontSize: 7,
              ),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 9),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F7FAFC'),
          border: pw.Border.all(color: _line, width: .5),
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              [
                if (report.projectReference != null) report.projectReference!,
                report.currency,
                'Protected commercial record',
              ].join('  |  '),
              style: pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
            pw.Text(
              'Generated by ${report.generatedByDisplayName}  |  $generated',
              style: pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 14),
    ],
  );

  static pw.Widget _pdfFooter(pw.Context context) => pw.Container(
    padding: const pw.EdgeInsets.only(top: 7),
    decoration: pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _line, width: .5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Yorks AC. & Ref. - confidential project commercial information',
          style: pw.TextStyle(fontSize: 7, color: _muted),
        ),
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: pw.TextStyle(fontSize: 7, color: _muted),
        ),
      ],
    ),
  );

  static pw.Widget _pdfProjectSummary(YorksAccountsReportProjection report) {
    if (report.rows.isEmpty) return _pdfEmptyState(report);
    final row = report.rows.first;
    final cards = <pw.Widget>[];
    for (var index = 0; index < report.columns.length; index++) {
      final column = report.columns[index];
      if (column.toLowerCase() == 'project') continue;
      cards.add(
        pw.Container(
          width: 167,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : PdfColor.fromHex('#F8FBFF'),
            border: pw.Border.all(color: _line, width: .7),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                column.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 7,
                  color: _muted,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: .35,
                ),
              ),
              pw.SizedBox(height: 7),
              pw.Text(
                _displayValue(report, index, row[index]),
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _pdfSectionTitle('Project commercial summary'),
        pw.SizedBox(height: 8),
        pw.Wrap(spacing: 8, runSpacing: 8, children: cards),
      ],
    );
  }

  static List<pw.Widget> _pdfReportWidgets(
    YorksAccountsReportProjection report,
  ) {
    if (report.rows.isEmpty) return [_pdfEmptyState(report)];
    final panels = _pdfColumnPanels(report.columns.length);
    final widgets = <pw.Widget>[];
    for (var panelIndex = 0; panelIndex < panels.length; panelIndex++) {
      final indexes = panels[panelIndex];
      final alignments = <int, pw.Alignment>{};
      for (var index = 0; index < indexes.length; index++) {
        if (_isNumericColumn(report.columns[indexes[index]])) {
          alignments[index] = pw.Alignment.centerRight;
        }
      }
      if (panelIndex > 0) widgets.add(pw.SizedBox(height: 14));
      widgets
        ..add(
          _pdfSectionTitle(
            panels.length == 1
                ? _title(report)
                : '${_title(report)} - details ${panelIndex + 1} of ${panels.length}',
          ),
        )
        ..add(pw.SizedBox(height: 8))
        ..add(
          pw.TableHelper.fromTextArray(
            headers: [for (final index in indexes) report.columns[index]],
            data: _pdfRows(report, indexes),
            headerDecoration: pw.BoxDecoration(color: _navy),
            headerAlignment: pw.Alignment.centerLeft,
            headerAlignments: alignments,
            cellAlignments: alignments,
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 7.2,
            ),
            cellStyle: pw.TextStyle(fontSize: 7.1, color: _ink),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 6,
            ),
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F7FAFC'),
            ),
            border: pw.TableBorder(
              bottom: pw.BorderSide(color: _line, width: .45),
              horizontalInside: pw.BorderSide(color: _line, width: .35),
            ),
          ),
        );
    }
    return widgets;
  }

  static List<List<String>> _pdfRows(
    YorksAccountsReportProjection report,
    List<int> indexes,
  ) {
    const chunkLength = 700;
    final result = <List<String>>[];
    for (final row in report.rows) {
      final values = [
        for (final index in indexes) _displayValue(report, index, row[index]),
      ];
      final chunkCount = values.fold<int>(
        1,
        (maximum, value) => value.length > maximum * chunkLength
            ? (value.length / chunkLength).ceil()
            : maximum,
      );
      for (var chunk = 0; chunk < chunkCount; chunk++) {
        result.add([
          for (var index = 0; index < values.length; index++)
            if (chunk > 0 && index < 2 && values[index].length <= chunkLength)
              values[index]
            else
              _textChunk(values[index], chunk, chunkLength),
        ]);
      }
    }
    return result;
  }

  static String _textChunk(String value, int chunk, int chunkLength) {
    final start = chunk * chunkLength;
    if (start >= value.length) return '';
    final end = start + chunkLength < value.length
        ? start + chunkLength
        : value.length;
    return value.substring(start, end);
  }

  static List<List<int>> _pdfColumnPanels(int columnCount) {
    if (columnCount <= 8) {
      return [List<int>.generate(columnCount, (index) => index)];
    }
    const repeatedColumns = 2;
    const detailColumnsPerPanel = 6;
    final panels = <List<int>>[];
    for (
      var start = repeatedColumns;
      start < columnCount;
      start += detailColumnsPerPanel
    ) {
      final end = (start + detailColumnsPerPanel).clamp(0, columnCount);
      panels.add([
        ...List<int>.generate(repeatedColumns, (index) => index),
        for (var index = start; index < end; index++) index,
      ]);
    }
    return panels;
  }

  static pw.Widget _pdfSectionTitle(String title) => pw.Row(
    children: [
      pw.Container(width: 4, height: 18, color: _blue),
      pw.SizedBox(width: 7),
      pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ],
  );

  static pw.Widget _pdfEmptyState(YorksAccountsReportProjection report) =>
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(28),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F7FAFC'),
          border: pw.Border.all(color: _line, width: .6),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              _title(report),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              'No records available for this protected report.',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      );

  static String _displayValue(
    YorksAccountsReportProjection report,
    int columnIndex,
    String raw,
  ) {
    final column = report.columns[columnIndex];
    if (_isMoneyColumn(column)) {
      final value = _number(raw);
      if (value != null) {
        return '${report.currency} ${NumberFormat('#,##0.00').format(value)}';
      }
    }
    if (_isPercentColumn(column)) {
      final value = _number(raw);
      if (value != null) return '${NumberFormat('0.##').format(value)}%';
    }
    if (_isDateTimeColumn(column)) {
      final value = DateTime.tryParse(raw);
      if (value != null) {
        return DateFormat('dd MMM yyyy, HH:mm').format(value.toLocal());
      }
    } else if (_isDateColumn(column)) {
      final value = DateTime.tryParse(raw);
      if (value != null) {
        return DateFormat('dd MMM yyyy').format(value.toLocal());
      }
    }
    return raw;
  }

  static String _documentTitle(
    YorksAccountsReportProjection report, {
    bool completeProjectBackup = false,
  }) => completeProjectBackup
      ? 'Complete Project Accounts Report'
      : report.reportKind == 'project_summary'
      ? 'Project Accounts Report'
      : _title(report);

  static String _title(YorksAccountsReportProjection report) => report
      .reportKind
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');

  static String _sheetName(YorksAccountsReportProjection report) {
    final title = report.reportKind == 'project_summary'
        ? 'Project Summary'
        : _title(report);
    return title.length <= 31 ? title : title.substring(0, 31);
  }

  static String _fileStem(
    YorksAccountsReportProjection report, {
    required bool completeProjectBackup,
  }) {
    final scope = report.projectReference ?? 'Portfolio';
    final stamp = DateFormat('yyyy-MM-dd').format(report.generatedAt.toLocal());
    final reportToken = completeProjectBackup
        ? 'Accounts_Backup'
        : _token(report.reportKind);
    return 'Yorks_${_token(scope)}_${reportToken}_$stamp';
  }

  static String _token(String value) => value
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp('_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _safe(String value) {
    final normalized = value.replaceAll('\u0000', '');
    return RegExp(r'^[=+\-@]').hasMatch(normalized)
        ? "'$normalized"
        : normalized;
  }

  static bool _isNumericColumn(String column) =>
      _isMoneyColumn(column) ||
      _isPercentColumn(column) ||
      _isWholeNumberColumn(column);

  static bool _isMoneyColumn(String column) {
    final value = column.toLowerCase();
    if (_isPercentColumn(column)) return false;
    return value.contains('value') ||
        value.contains('amount') ||
        value.contains('balance') ||
        value.contains('exposure') ||
        value.contains('outstanding') ||
        value.contains('confirmed work') ||
        value.contains('claimed') ||
        value.contains('certified') ||
        value == 'available to claim' ||
        value == 'active pdc' ||
        value == 'ex vat' ||
        value == 'this claim' ||
        value == 'paid' ||
        value.contains('still due') ||
        value.contains('total') ||
        value.contains('eligible');
  }

  static bool _isPercentColumn(String column) {
    final value = column.toLowerCase();
    return value.contains('%') ||
        value.contains('percent') ||
        value == 'progress';
  }

  static bool _isDateColumn(String column) {
    final value = column.toLowerCase();
    return value == 'updated' ||
        value == 'submitted' ||
        value == 'due' ||
        value.contains('date') ||
        value.endsWith(' at');
  }

  static bool _isDateTimeColumn(String column) =>
      column.toLowerCase().endsWith(' at');

  static bool _isWholeNumberColumn(String column) {
    final value = column.toLowerCase();
    return value == 'revision' ||
        value.endsWith(' revision') ||
        value == 'version' ||
        value.endsWith(' version') ||
        value.endsWith(' count') ||
        value.endsWith(' files') ||
        value.endsWith(' days') ||
        value == 'display order' ||
        value == 'sequence' ||
        value == 'size bytes';
  }

  static double? _number(String value) {
    final normalized = value.replaceAll(',', '').replaceAll('%', '').trim();
    if (RegExp(r'^[=+@]').hasMatch(normalized)) return null;
    return double.tryParse(normalized);
  }

  static final PdfColor _navy = PdfColor.fromHex('#12365E');
  static final PdfColor _blue = PdfColor.fromHex('#1769E0');
  static final PdfColor _ink = PdfColor.fromHex('#10233F');
  static final PdfColor _muted = PdfColor.fromHex('#667085');
  static final PdfColor _line = PdfColor.fromHex('#D7E0EB');
  static final PdfColor _paleBlue = PdfColor.fromHex('#EAF3FF');
}

class _AccountsWorkbookWriter {
  static Uint8List encode(List<YorksAccountsReportProjection> reports) {
    final completeProjectBackup = reports.length > 1;
    final names = <String>[];
    for (final report in reports) {
      var name = YorksAccountsReportService._sheetName(report);
      var suffix = 2;
      while (names.contains(name)) {
        final token = ' $suffix';
        final available = (31 - token.length).clamp(1, 31).toInt();
        name = '${name.substring(0, available)}$token';
        suffix++;
      }
      names.add(name);
    }
    final archive = Archive()
      ..addFile(
        ArchiveFile.string('[Content_Types].xml', _contentTypes(names.length)),
      )
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRels))
      ..addFile(
        ArchiveFile.string(
          'docProps/core.xml',
          _coreProperties(
            reports.first,
            completeProjectBackup: completeProjectBackup,
          ),
        ),
      )
      ..addFile(ArchiveFile.string('docProps/app.xml', _appProperties(names)))
      ..addFile(
        ArchiveFile.string('xl/workbook.xml', _workbook(names, reports)),
      )
      ..addFile(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          _workbookRels(names.length),
        ),
      )
      ..addFile(ArchiveFile.string('xl/styles.xml', _styles));
    for (var index = 0; index < reports.length; index++) {
      archive.addFile(
        ArchiveFile.string(
          'xl/worksheets/sheet${index + 1}.xml',
          _sheet(
            reports[index],
            index,
            completeProjectBackup: completeProjectBackup,
          ),
        ),
      );
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  static String _sheet(
    YorksAccountsReportProjection report,
    int sheetIndex, {
    required bool completeProjectBackup,
  }) {
    final lastColumnIndex = report.columns.length - 1;
    final lastColumn = _column(lastColumnIndex);
    final lastDataRow = report.rows.isEmpty ? 7 : 6 + report.rows.length;
    final out = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetPr><tabColor rgb="${sheetIndex == 0 ? 'FF1769E0' : 'FF33A36B'}"/>'
      '<pageSetUpPr fitToPage="1"/></sheetPr>'
      '<dimension ref="A1:$lastColumn$lastDataRow"/>'
      '<sheetViews><sheetView showGridLines="0" workbookViewId="0">'
      '<pane ySplit="6" topLeftCell="A7" activePane="bottomLeft" state="frozen"/>'
      '<selection pane="bottomLeft" activeCell="A7" sqref="A7"/>'
      '</sheetView></sheetViews>'
      '<sheetFormatPr defaultRowHeight="17"/>'
      '<cols>${_columns(report)}</cols>'
      '<sheetData>',
    );
    _row(
      out,
      1,
      height: 30,
      cells: [
        _textCell(
          'A1',
          YorksAccountsReportService._documentTitle(
            report,
            completeProjectBackup: completeProjectBackup,
          ),
          1,
        ),
      ],
    );
    _row(
      out,
      2,
      height: 23,
      cells: [
        _textCell(
          'A2',
          [
            if (report.projectReference != null) report.projectReference!,
            if (report.projectName != null) report.projectName!,
          ].join(' - '),
          13,
        ),
      ],
    );
    final generated = DateFormat(
      'dd MMM yyyy, HH:mm',
    ).format(report.generatedAt.toLocal());
    _row(
      out,
      3,
      cells: [
        _textCell(
          'A3',
          'Generated by ${report.generatedByDisplayName} | $generated | ${report.currency}',
          2,
        ),
      ],
    );
    _row(
      out,
      4,
      cells: [
        _textCell(
          'A4',
          'Worksheet: ${YorksAccountsReportService._title(report)} | Protected commercial record | Access: ${report.accessContext.replaceAll('_', ' ')}',
          2,
        ),
      ],
    );
    _row(out, 5, height: 8, cells: const []);
    _row(
      out,
      6,
      height: 25,
      cells: [
        for (var index = 0; index < report.columns.length; index++)
          _textCell('${_column(index)}6', report.columns[index], 3),
      ],
    );
    if (report.rows.isEmpty) {
      _row(
        out,
        7,
        height: 30,
        cells: [_textCell('A7', 'No records available for this report.', 12)],
      );
    } else {
      for (var rowIndex = 0; rowIndex < report.rows.length; rowIndex++) {
        final excelRow = rowIndex + 7;
        _row(
          out,
          excelRow,
          height: _dataRowHeight(report.rows[rowIndex]),
          cells: [
            for (
              var columnIndex = 0;
              columnIndex < report.columns.length;
              columnIndex++
            )
              _dataCell(
                '${_column(columnIndex)}$excelRow',
                report.columns[columnIndex],
                report.rows[rowIndex][columnIndex],
                rowIndex.isOdd,
              ),
          ],
        );
      }
    }
    final mergeCount = report.rows.isEmpty ? 5 : 4;
    out.write(
      '</sheetData>'
      '<autoFilter ref="A6:$lastColumn$lastDataRow"/>'
      '<mergeCells count="$mergeCount">'
      '<mergeCell ref="A1:${lastColumn}1"/>'
      '<mergeCell ref="A2:${lastColumn}2"/>'
      '<mergeCell ref="A3:${lastColumn}3"/>'
      '<mergeCell ref="A4:${lastColumn}4"/>'
      '${report.rows.isEmpty ? '<mergeCell ref="A7:${lastColumn}7"/>' : ''}'
      '</mergeCells>'
      '<printOptions horizontalCentered="0" verticalCentered="0"/>'
      '<pageMargins left="0.3" right="0.3" top="0.45" bottom="0.45" header="0.2" footer="0.2"/>'
      '<pageSetup orientation="landscape" paperSize="9" fitToWidth="1" fitToHeight="0"/>'
      '<headerFooter><oddFooter>&amp;LYorks AC. &amp; Ref. - Protected commercial record&amp;RPage &amp;P of &amp;N</oddFooter></headerFooter>'
      '</worksheet>',
    );
    return out.toString();
  }

  static String _columns(YorksAccountsReportProjection report) {
    final out = StringBuffer();
    for (var index = 0; index < report.columns.length; index++) {
      final header = report.columns[index];
      var width = header.length + 4.0;
      for (final row in report.rows.take(60)) {
        final candidate = row[index].length + 2.0;
        if (candidate > width) width = candidate;
      }
      if (YorksAccountsReportService._isMoneyColumn(header)) {
        width = width < 17 ? 17 : width;
      }
      if (header.toLowerCase().contains('evidence')) {
        width = width < 32 ? 32 : width;
      }
      if (width > 42) width = 42;
      out.write(
        '<col min="${index + 1}" max="${index + 1}" width="${width.toStringAsFixed(1)}" customWidth="1"/>',
      );
    }
    return out.toString();
  }

  static double _dataRowHeight(List<String> row) {
    final longest = row.fold<int>(
      0,
      (maximum, value) => value.length > maximum ? value.length : maximum,
    );
    if (longest > 120) return 64;
    if (longest > 40) return 40;
    return 22;
  }

  static String _dataCell(
    String reference,
    String column,
    String value,
    bool stripe,
  ) {
    if (YorksAccountsReportService._isMoneyColumn(column)) {
      final number = YorksAccountsReportService._number(value);
      if (number != null) return _numberCell(reference, number, stripe ? 7 : 6);
    }
    if (YorksAccountsReportService._isPercentColumn(column)) {
      final number = YorksAccountsReportService._number(value);
      if (number != null) {
        return _numberCell(reference, number / 100, stripe ? 9 : 8);
      }
    }
    if (YorksAccountsReportService._isDateTimeColumn(column)) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return _numberCell(reference, _excelDateSerial(date), stripe ? 17 : 16);
      }
    } else if (YorksAccountsReportService._isDateColumn(column)) {
      final date = DateTime.tryParse(value);
      if (date != null) {
        return _numberCell(reference, _excelDateSerial(date), stripe ? 11 : 10);
      }
    }
    if (YorksAccountsReportService._isWholeNumberColumn(column)) {
      final number = YorksAccountsReportService._number(value);
      if (number != null) {
        return _numberCell(reference, number, stripe ? 12 : 15);
      }
    }
    return _textCell(
      reference,
      YorksAccountsReportService._safe(value),
      stripe ? 5 : 4,
    );
  }

  static void _row(
    StringBuffer out,
    int index, {
    required List<String> cells,
    double? height,
  }) {
    out.write('<row r="$index"');
    if (height != null) {
      out.write(' ht="${height.toStringAsFixed(0)}" customHeight="1"');
    }
    out.write('>${cells.join()}</row>');
  }

  static String _textCell(String reference, String value, int style) =>
      '<c r="$reference" s="$style" t="inlineStr"><is><t xml:space="preserve">${_xml(value)}</t></is></c>';

  static String _numberCell(String reference, double value, int style) =>
      '<c r="$reference" s="$style"><v>${_numberText(value)}</v></c>';

  static String _numberText(double value) {
    final fixed = value.toStringAsFixed(8);
    final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
    return trimmed.isEmpty ? '0' : trimmed;
  }

  static double _excelDateSerial(DateTime date) {
    final local = date.toLocal();
    final wallClock = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    return wallClock.difference(DateTime.utc(1899, 12, 30)).inMicroseconds /
        Duration.microsecondsPerDay;
  }

  static String _contentTypes(int count) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
      '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '${[for (var i = 1; i <= count; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
      '</Types>';

  static const _rootRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
      '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
      '</Relationships>';

  static String _workbook(
    List<String> names,
    List<YorksAccountsReportProjection> reports,
  ) {
    final definedNames = StringBuffer('<definedNames>');
    for (var index = 0; index < names.length; index++) {
      final lastColumn = _column(reports[index].columns.length - 1);
      final lastRow = reports[index].rows.isEmpty
          ? 7
          : 6 + reports[index].rows.length;
      final escaped = _xml(names[index]);
      definedNames
        ..write(
          '<definedName name="_xlnm.Print_Titles" localSheetId="$index">&apos;$escaped&apos;!\$6:\$6</definedName>',
        )
        ..write(
          '<definedName name="_xlnm.Print_Area" localSheetId="$index">&apos;$escaped&apos;!\$A\$1:\$$lastColumn\$$lastRow</definedName>',
        );
    }
    definedNames.write('</definedNames>');
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<bookViews><workbookView activeTab="0"/></bookViews>'
        '<sheets>${[for (var i = 0; i < names.length; i++) '<sheet name="${_xml(names[i])}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}</sheets>'
        '$definedNames'
        '<calcPr calcId="191029"/>'
        '</workbook>';
  }

  static String _workbookRels(int count) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '${[for (var i = 1; i <= count; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join()}'
      '<Relationship Id="rId${count + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
      '</Relationships>';

  static String _coreProperties(
    YorksAccountsReportProjection report, {
    required bool completeProjectBackup,
  }) {
    final timestamp = report.generatedAt.toUtc().toIso8601String();
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
        'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
        '<dc:title>${_xml(YorksAccountsReportService._documentTitle(report, completeProjectBackup: completeProjectBackup))}</dc:title>'
        '<dc:creator>${_xml(report.generatedByDisplayName)}</dc:creator>'
        '<dc:subject>Yorks protected Accounts report</dc:subject>'
        '<dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created>'
        '<dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified>'
        '</cp:coreProperties>';
  }

  static String _appProperties(List<String> names) =>
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
      'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
      '<Application>Yorks AC. &amp; Ref.</Application><DocSecurity>0</DocSecurity>'
      '<HeadingPairs><vt:vector size="2" baseType="variant"><vt:variant><vt:lpstr>Worksheets</vt:lpstr></vt:variant>'
      '<vt:variant><vt:i4>${names.length}</vt:i4></vt:variant></vt:vector></HeadingPairs>'
      '<TitlesOfParts><vt:vector size="${names.length}" baseType="lpstr">'
      '${[for (final name in names) '<vt:lpstr>${_xml(name)}</vt:lpstr>'].join()}'
      '</vt:vector></TitlesOfParts></Properties>';

  static const _styles =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<numFmts count="4"><numFmt numFmtId="164" formatCode="#,##0.00"/>'
      '<numFmt numFmtId="165" formatCode="0.0%"/><numFmt numFmtId="166" formatCode="dd mmm yyyy"/>'
      '<numFmt numFmtId="167" formatCode="dd mmm yyyy hh:mm"/></numFmts>'
      '<fonts count="4">'
      '<font><sz val="10"/><color rgb="FF10233F"/><name val="Aptos"/><family val="2"/></font>'
      '<font><b/><sz val="18"/><color rgb="FFFFFFFF"/><name val="Aptos Display"/></font>'
      '<font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="Aptos"/></font>'
      '<font><b/><sz val="11"/><color rgb="FF10233F"/><name val="Aptos"/></font>'
      '</fonts>'
      '<fills count="5"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FF12365E"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFEAF3FF"/><bgColor indexed="64"/></patternFill></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFF7FAFC"/><bgColor indexed="64"/></patternFill></fill>'
      '</fills>'
      '<borders count="2"><border/><border><left style="thin"><color rgb="FFD7E0EB"/></left>'
      '<right style="thin"><color rgb="FFD7E0EB"/></right><top style="thin"><color rgb="FFD7E0EB"/></top>'
      '<bottom style="thin"><color rgb="FFD7E0EB"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="18">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyFont="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="2" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyFill="1" applyBorder="1"><alignment vertical="center" wrapText="1"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment horizontal="right" vertical="center"/></xf>'
      '<xf numFmtId="164" fontId="0" fillId="4" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment horizontal="right" vertical="center"/></xf>'
      '<xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment horizontal="right" vertical="center"/></xf>'
      '<xf numFmtId="165" fontId="0" fillId="4" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment horizontal="right" vertical="center"/></xf>'
      '<xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="166" fontId="0" fillId="4" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="4" borderId="1" xfId="0" applyFill="1" applyBorder="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="3" borderId="0" xfId="0" applyFont="1" applyFill="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="167" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '<xf numFmtId="167" fontId="0" fillId="4" borderId="1" xfId="0" applyNumberFormat="1" applyFill="1" applyBorder="1"><alignment vertical="center"/></xf>'
      '</cellXfs>'
      '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
      '<dxfs count="0"/><tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>'
      '</styleSheet>';

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
