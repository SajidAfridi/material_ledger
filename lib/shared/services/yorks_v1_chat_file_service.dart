import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/yorks_v1_domain_error.dart';

class YorksV1SelectedChatFile {
  const YorksV1SelectedChatFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;

  factory YorksV1SelectedChatFile.checked({
    required String fileName,
    required Uint8List bytes,
  }) {
    final normalized = fileName.replaceAll('\\', '/').split('/').last.trim();
    final mime = _mimeType(normalized);
    if (normalized.isEmpty ||
        normalized.length > 180 ||
        mime == null ||
        bytes.isEmpty ||
        bytes.lengthInBytes > yorksV1MaxChatAttachmentBytes) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return YorksV1SelectedChatFile(
      fileName: normalized,
      mimeType: mime,
      bytes: bytes,
    );
  }
}

const yorksV1MaxChatAttachmentBytes = 20 * 1024 * 1024;

abstract interface class YorksV1ChatFileService {
  Future<List<YorksV1SelectedChatFile>> selectFiles();

  Future<bool> saveFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}

class YorksV1PlatformChatFileService implements YorksV1ChatFileService {
  const YorksV1PlatformChatFileService();

  static const _type = XTypeGroup(
    label: 'Chat attachment',
    extensions: [
      'pdf',
      'xls',
      'xlsx',
      'doc',
      'docx',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'txt',
      'csv',
    ],
    mimeTypes: [
      'application/pdf',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg',
      'image/png',
      'image/webp',
      'text/plain',
      'text/csv',
    ],
  );

  @override
  Future<List<YorksV1SelectedChatFile>> selectFiles() async {
    final files = await openFiles(acceptedTypeGroups: const [_type]);
    if (files.length > 10) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final selected = <YorksV1SelectedChatFile>[];
    for (final file in files) {
      selected.add(
        YorksV1SelectedChatFile.checked(
          fileName: file.name,
          bytes: await file.readAsBytes(),
        ),
      );
    }
    return List.unmodifiable(selected);
  }

  @override
  Future<bool> saveFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [_type],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      name: fileName,
      mimeType: mimeType,
    ).saveTo(location.path);
    return true;
  }
}

String? _mimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'pdf' => 'application/pdf',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    _ => null,
  };
}
