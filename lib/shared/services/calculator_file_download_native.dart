import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';

Future<bool> downloadCalculatorFile(
  String contents, {
  required String filename,
}) async {
  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: const [
      XTypeGroup(label: 'JSON', extensions: ['json']),
    ],
  );
  if (location == null) return false;
  await XFile.fromData(
    Uint8List.fromList(utf8.encode(contents)),
    name: filename,
    mimeType: 'application/json',
  ).saveTo(location.path);
  return true;
}
