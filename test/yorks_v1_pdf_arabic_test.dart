import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/shared/models/yorks_v1_company_document_strings.dart';
import 'package:material_ledger/shared/services/yorks_v1_pdf_arabic.dart';

void main() {
  test('PDF Arabic letterhead keeps the legal name in right-to-left order', () {
    final shaped = yorksV1ShapeArabicForPdf(
      YorksV1CompanyDocumentStrings.legalName.ar,
    );
    final tokens = shaped.split(' ');

    // The PDF renderer places this shaped string in a left-to-right run. The
    // first visual token therefore belongs at the left of the letterhead, and
    // the legal company name begins at the right edge.
    expect(tokens.first, yorksV1ShapeArabicForPdf('ش.ش.و'));
    expect(tokens.last, yorksV1ShapeArabicForPdf('يوركس'));
  });
}
