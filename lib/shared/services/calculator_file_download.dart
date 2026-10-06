import 'calculator_file_download_native.dart'
    if (dart.library.js_interop) 'calculator_file_download_web.dart'
    as platform;

Future<bool> downloadCalculatorFile(
  String contents, {
  required String filename,
}) => platform.downloadCalculatorFile(contents, filename: filename);
