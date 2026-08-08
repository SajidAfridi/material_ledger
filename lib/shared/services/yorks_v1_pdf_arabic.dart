// The pdf package exposes Arabic shaping internally but, with its default
// bidi option, does not apply that shaping to mixed-direction controlled
// document text. Keep this small compatibility boundary local to PDF output.
// ignore: implementation_imports
import 'package:pdf/src/pdf/font/arabic.dart' as pdf_arabic;

/// Returns connected Arabic presentation forms in the visual order expected
/// by a left-to-right PDF text run.
String yorksV1ShapeArabicForPdf(String value) => pdf_arabic.convert(value);
