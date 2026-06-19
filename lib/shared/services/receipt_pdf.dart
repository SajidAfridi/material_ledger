import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/material_request.dart';

/// Builds a clean, printable order/receipt slip for a material request.
/// Engineer-facing: no unit costs or values are shown (FR-092).
const _brand = PdfColor.fromInt(0xFF003FB1);
const _ink = PdfColor.fromInt(0xFF1E293B);
const _muted = PdfColor.fromInt(0xFF64748B);
const _line = PdfColor.fromInt(0xFFE2E8F0);

Future<Uint8List> buildRequestReceiptPdf(
  MaterialRequest req,
  PdfPageFormat format,
) async {
  // Load a Unicode font so bilingual content (Arabic/Urdu project names, notes)
  // doesn't throw during save. PdfGoogleFonts fetches on first use; if offline
  // we fall back to the built-in Latin font rather than failing the whole PDF.
  pw.ThemeData? theme;
  try {
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );
  } catch (_) {
    theme = null;
  }
  final doc = pw.Document(theme: theme);
  final df = DateFormat('MMM d, yyyy');
  final tf = DateFormat('h:mm a');
  String fmtQty(double q) => q.toStringAsFixed(q % 1 == 0 ? 0 : 1);

  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Yorks AC',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: _brand,
                    ),
                  ),
                  pw.Text(
                    'Material Request',
                    style: pw.TextStyle(fontSize: 12, color: _muted),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    req.id.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: pw.BoxDecoration(
                      color: const PdfColor.fromInt(0xFFE9EDFB),
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                    child: pw.Text(
                      req.status.label,
                      style: pw.TextStyle(fontSize: 9, color: _brand),
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: _line),
          pw.SizedBox(height: 12),
          _meta('Project', req.projectName),
          if ((req.siteLocation ?? '').isNotEmpty)
            _meta('Site', req.siteLocation!),
          _meta('Priority', req.priority.label),
          _meta(
            'Issued',
            '${df.format(req.requestDate)} · ${tf.format(req.requestDate)}',
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Items (${req.lineItems.length})',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: null,
            headerHeight: 26,
            cellHeight: 26,
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0F172A),
            ),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: pw.TextStyle(fontSize: 10, color: _ink),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5)),
            ),
            headerAlignments: {
              0: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FixedColumnWidth(46),
              4: const pw.FixedColumnWidth(46),
            },
            headers: ['#', 'Material', 'Spec', 'Qty', 'Unit'],
            data: [
              for (var i = 0; i < req.lineItems.length; i++)
                [
                  '${i + 1}',
                  req.lineItems[i].materialName,
                  req.lineItems[i].spec,
                  fmtQty(req.lineItems[i].quantity),
                  req.lineItems[i].unitSymbol,
                ],
            ],
          ),
          if ((req.notes ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Notes',
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              req.notes!,
              style: pw.TextStyle(fontSize: 10, color: _muted),
            ),
          ],
          pw.Spacer(),
          pw.Divider(color: _line),
          pw.Text(
            'Generated by Yorks GodownPro — ${df.format(DateTime.now())} ${tf.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _meta(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 70,
        child: pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _muted)),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            color: _ink,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    ],
  ),
);

/// Opens the system print / preview dialog for the request receipt
/// (this is also the "nice receipt view" — a rendered, paginated slip).
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
  await Printing.sharePdf(bytes: bytes, filename: '${req.id}.pdf', bounds: bounds);
}
