// The pdf package exposes Arabic shaping internally but, with its default
// bidi option, does not apply that shaping to mixed-direction controlled
// document text. Keep this small compatibility boundary local to PDF output.
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/arabic.dart' as pdf_arabic;

/// Returns connected Arabic presentation forms in the visual order expected
/// by a left-to-right PDF text run.
///
/// `pdf_arabic.convert` shapes the characters but leaves the word tokens in
/// logical order.  Because the PDF text run itself is left-to-right, that put
/// the final Arabic word at the right edge of the controlled-document header
/// (the reverse of the approved letterhead).  Preserve every shaped token,
/// while reversing their display order for the left-to-right PDF run.
String yorksV1ShapeArabicForPdf(String value) {
  final shapedTokens = pdf_arabic.convert(value).split(' ');
  return shapedTokens.reversed.join(' ');
}
