import 'catalogue_csv_download_stub.dart'
    if (dart.library.js_interop) 'catalogue_csv_download_web.dart';

/// Downloads on web; returns false on platforms without a browser download
/// surface so the caller can use the clipboard fallback.
Future<bool> downloadCatalogueCsv(
  String csv, {
  String filename = 'yorks-material-catalogue.csv',
}) => downloadCatalogueCsvImpl(csv, filename: filename);
