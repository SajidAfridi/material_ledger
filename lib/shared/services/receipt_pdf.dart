import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/material_request.dart';

/// A professional, paginated "Material Requisition" document for a request.
/// Engineer-facing: no unit costs or values are shown (FR-092).

// ─── Company letterhead (update TRN/contact with the real values) ──────
const _companyName = 'Yorks Airconditioning & Refrigeration LLC';
const _companyLocation = 'Abu Dhabi, United Arab Emirates';
const _companyTrn = 'TRN 100XXXXXXXXXXXX';

// ─── Palette ───────────────────────────────────────────────────────────
const _brand = PdfColor.fromInt(0xFF003FB1);
const _ink = PdfColor.fromInt(0xFF1E293B);
const _muted = PdfColor.fromInt(0xFF64748B);
const _faint = PdfColor.fromInt(0xFF94A3B8);
const _line = PdfColor.fromInt(0xFFE2E8F0);
const _zebra = PdfColor.fromInt(0xFFF6F8FC);
const _panelBg = PdfColor.fromInt(0xFFF8FAFC);

Future<pw.MemoryImage?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/logo.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  } catch (_) {
    return null;
  }
}

/// Bundled Unicode fonts — no network dependency, so the receipt renders
/// reliably offline (em-dash, accents) with an Arabic/Urdu fallback for the
/// bilingual secondary names. Falls back to the built-in Latin font only if the
/// bundled assets somehow fail to load.
Future<pw.ThemeData?> _buildTheme() async {
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

PdfColor _statusColor(RequestStatus s) => switch (s) {
  RequestStatus.draft => _muted,
  RequestStatus.pending || RequestStatus.sourcing || RequestStatus.onHold =>
    const PdfColor.fromInt(0xFFB45309), // amber
  RequestStatus.partial || RequestStatus.dispatched => _brand,
  RequestStatus.received => const PdfColor.fromInt(0xFF0F6E56), // teal/green
  RequestStatus.cancelled => const PdfColor.fromInt(0xFFB91C1C), // red
};

Future<Uint8List> buildRequestReceiptPdf(
  MaterialRequest req,
  PdfPageFormat format,
) async {
  final theme = await _buildTheme();
  final logo = await _loadLogo();

  final df = DateFormat('d MMM yyyy');
  String fmtQty(double q) => q.toStringAsFixed(q % 1 == 0 ? 0 : 1);

  final totalQty = req.lineItems.fold<double>(0, (s, l) => s + l.quantity);
  final statusColor = _statusColor(req.status);
  final showWatermark =
      req.status == RequestStatus.draft ||
      req.status == RequestStatus.cancelled;

  final doc = pw.Document(theme: theme);

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: format,
        theme: theme,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
        buildBackground: showWatermark
            ? (context) => _watermark(req.status.label)
            : null,
      ),
      header: (context) => context.pageNumber == 1
          ? pw.SizedBox()
          : _continuationHeader(req),
      footer: _footer,
      build: (context) => [
        _letterhead(req, logo, statusColor),
        pw.SizedBox(height: 16),
        _metaStrip(req, df),
        pw.SizedBox(height: 14),
        _partyPanels(req, df),
        pw.SizedBox(height: 18),
        _itemsTable(req, fmtQty),
        pw.SizedBox(height: 8),
        _summary(req.lineItems.length, totalQty, fmtQty),
        if ((req.notes ?? '').isNotEmpty) ...[
          pw.SizedBox(height: 16),
          _notes(req.notes!),
        ],
        pw.SizedBox(height: 36),
        _signatures(),
      ],
    ),
  );
  return doc.save();
}

// ─── Letterhead (brand banner) ──────────────────────────────────────────
const _white80 = PdfColor(1, 1, 1, 0.82);
const _white65 = PdfColor(1, 1, 1, 0.65);

/// A small status pill. NOTE: the corner radius MUST stay well below half the
/// pill's height — a radius larger than the box (the old `circular(999)`) makes
/// the pdf package emit a self-intersecting path that floods the page with a
/// giant filled wedge.
pw.Widget _statusChip(String label, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: pw.BoxDecoration(
    color: PdfColors.white,
    borderRadius: pw.BorderRadius.circular(4),
  ),
  child: pw.Text(
    label.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 8.5,
      color: color,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 0.3,
    ),
  ),
);

pw.Widget _letterhead(
  MaterialRequest req,
  pw.MemoryImage? logo,
  PdfColor statusColor,
) => pw.Container(
  padding: const pw.EdgeInsets.all(16),
  decoration: pw.BoxDecoration(
    color: _brand,
    borderRadius: pw.BorderRadius.circular(8),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // ─── Left: logo tile + company ───────────────────────
      pw.Expanded(
        flex: 5,
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 44,
              height: 44,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(7),
              ),
              child: logo != null
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    )
                  : pw.Text(
                      'Y',
                      style: pw.TextStyle(
                        color: _brand,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _companyName,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      lineSpacing: 1.5,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    _companyLocation,
                    style: pw.TextStyle(fontSize: 9, color: _white80),
                  ),
                  pw.Text(
                    _companyTrn,
                    style: pw.TextStyle(fontSize: 8.5, color: _white65),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 12),
      // ─── Right: document title + id + status ──────────────
      pw.Expanded(
        flex: 4,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'MATERIAL REQUISITION',
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 12.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              req.id.toUpperCase(),
              style: pw.TextStyle(fontSize: 10.5, color: _white80),
            ),
            pw.SizedBox(height: 8),
            _statusChip(req.status.label, statusColor),
          ],
        ),
      ),
    ],
  ),
);

// ─── Slim header on continuation pages ──────────────────────────────────
pw.Widget _continuationHeader(MaterialRequest req) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            _companyName,
            style: pw.TextStyle(
              fontSize: 9,
              color: _muted,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            'Material Requisition · ${req.id.toUpperCase()}',
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
      pw.SizedBox(height: 6),
      pw.Container(height: 1, color: _line),
    ],
  ),
);

// ─── Meta strip (4 cells) ───────────────────────────────────────────────
pw.Widget _metaStrip(MaterialRequest req, DateFormat df) {
  pw.Widget cell(String label, String value) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: _panelBg,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _faint)),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 10,
              color: _ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
  return pw.Row(
    children: [
      cell('Document no.', req.id.toUpperCase()),
      cell('Issue date', df.format(req.requestDate)),
      cell('Priority', req.priority.label),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: pw.BoxDecoration(
            color: _panelBg,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Line items',
                style: pw.TextStyle(fontSize: 8, color: _faint),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${req.lineItems.length}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: _ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─── Project / Requested-by panels ──────────────────────────────────────
pw.Widget _partyPanels(MaterialRequest req, DateFormat df) {
  pw.Widget panel(String label, List<pw.Widget> children) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: _faint, letterSpacing: 1),
          ),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    ),
  );
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      panel('PROJECT', [
        pw.Text(
          req.projectName,
          style: pw.TextStyle(
            fontSize: 11,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (req.projectNameSecondary.isNotEmpty)
          pw.Text(
            req.projectNameSecondary,
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
        if ((req.siteLocation ?? '').isNotEmpty)
          pw.Text(
            req.siteLocation!,
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
      ]),
      pw.SizedBox(width: 10),
      panel('REQUESTED BY', [
        pw.Text(
          'Site Engineer',
          style: pw.TextStyle(
            fontSize: 11,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          df.format(req.requestDate),
          style: pw.TextStyle(fontSize: 9, color: _muted),
        ),
      ]),
    ],
  );
}

// ─── Items table ────────────────────────────────────────────────────────
pw.Widget _itemsTable(MaterialRequest req, String Function(double) fmtQty) {
  pw.Widget headerCell(String t, {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Container(
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(
          t,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );

  pw.Widget cell(
    pw.Widget child, {
    pw.Alignment align = pw.Alignment.centerLeft,
  }) => pw.Container(
    alignment: align,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: child,
  );

  const widths = {
    0: pw.FixedColumnWidth(22),
    1: pw.FlexColumnWidth(3.2),
    2: pw.FlexColumnWidth(2),
    3: pw.FixedColumnWidth(38),
    4: pw.FixedColumnWidth(38),
  };

  return pw.Table(
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _brand),
        children: [
          headerCell('#'),
          headerCell('Description'),
          headerCell('Specification'),
          headerCell('Qty', align: pw.Alignment.centerRight),
          headerCell('Unit'),
        ],
      ),
      for (var i = 0; i < req.lineItems.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: i.isOdd ? _zebra : PdfColors.white,
            border: const pw.Border(
              bottom: pw.BorderSide(color: _line, width: .5),
            ),
          ),
          children: [
            cell(
              pw.Text(
                '${i + 1}',
                style: pw.TextStyle(fontSize: 9.5, color: _muted),
              ),
            ),
            cell(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    req.lineItems[i].materialName,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (req.lineItems[i].materialNameSecondary.isNotEmpty)
                    pw.Text(
                      req.lineItems[i].materialNameSecondary,
                      textDirection: pw.TextDirection.rtl,
                      style: pw.TextStyle(fontSize: 8, color: _muted),
                    ),
                ],
              ),
            ),
            cell(
              pw.Text(
                req.lineItems[i].spec,
                style: pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ),
            cell(
              pw.Text(
                fmtQty(req.lineItems[i].quantity),
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _ink,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              align: pw.Alignment.centerRight,
            ),
            cell(
              pw.Text(
                req.lineItems[i].unitSymbol,
                style: pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ),
          ],
        ),
    ],
  );
}

// ─── Summary ────────────────────────────────────────────────────────────
pw.Widget _summary(int items, double totalQty, String Function(double) fmtQty) =>
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text(
          'Total line items: ',
          style: pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
        pw.Text(
          '$items',
          style: pw.TextStyle(
            fontSize: 9.5,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 18),
        pw.Text(
          'Total quantity: ',
          style: pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
        pw.Text(
          '${fmtQty(totalQty)} units',
          style: pw.TextStyle(
            fontSize: 9.5,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );

// ─── Notes ──────────────────────────────────────────────────────────────
pw.Widget _notes(String notes) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  decoration: pw.BoxDecoration(
    border: pw.Border.all(color: _line),
    borderRadius: pw.BorderRadius.circular(6),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'NOTES',
        style: pw.TextStyle(fontSize: 8, color: _faint, letterSpacing: 1),
      ),
      pw.SizedBox(height: 3),
      pw.Text(notes, style: pw.TextStyle(fontSize: 9.5, color: _muted)),
    ],
  ),
);

// ─── Signatures ─────────────────────────────────────────────────────────
pw.Widget _signatures() {
  pw.Widget block(String label, String role) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.only(right: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 26),
          pw.Container(height: 1, color: _ink),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: _ink,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(role, style: pw.TextStyle(fontSize: 8.5, color: _faint)),
        ],
      ),
    ),
  );
  return pw.Row(
    children: [
      block('Requested by', 'Site Engineer'),
      block('Issued by', 'Store / Procurement'),
      block('Received by', 'Site'),
    ],
  );
}

// ─── Footer (every page) ────────────────────────────────────────────────
pw.Widget _footer(pw.Context context) {
  final now = DateTime.now();
  final stamp =
      '${DateFormat('d MMM yyyy').format(now)}, ${DateFormat('h:mm a').format(now)}';
  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Column(
      children: [
        pw.Container(height: .5, color: _line),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Computer-generated by Yorks GodownPro · $stamp',
              style: pw.TextStyle(fontSize: 7.5, color: _faint),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 7.5, color: _faint),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Status watermark (draft / cancelled) ───────────────────────────────
pw.Widget _watermark(String text) => pw.Center(
  child: pw.Transform.rotate(
    angle: 0.6,
    child: pw.Opacity(
      opacity: 0.06,
      child: pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 120,
          fontWeight: pw.FontWeight.bold,
          color: _ink,
        ),
      ),
    ),
  ),
);

/// Opens the system print / preview dialog for the request receipt.
Future<void> printRequestReceipt(MaterialRequest req) => Printing.layoutPdf(
  name: '${req.id}.pdf',
  onLayout: (format) => buildRequestReceiptPdf(req, format),
);

/// Shares / saves the request receipt as a PDF file.
///
/// [bounds] is the origin rectangle for the iOS/iPad share popover; pass the
/// tapped widget's global rect or the share sheet can fail to present on iPad.
Future<void> shareRequestReceipt(MaterialRequest req, {Rect? bounds}) async {
  final bytes = await buildRequestReceiptPdf(req, PdfPageFormat.a4);
  await Printing.sharePdf(
    bytes: bytes,
    filename: '${req.id}.pdf',
    bounds: bounds,
  );
}
