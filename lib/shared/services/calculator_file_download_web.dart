import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> downloadCalculatorFile(
  String contents, {
  required String filename,
}) async {
  final blob = web.Blob(
    <JSAny>[contents.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
