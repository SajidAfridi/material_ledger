import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import '../models/yorks_v1_domain_error.dart';

/// Cross-platform picker for the tightly bounded controlled-document formats.
/// The server independently revalidates MIME type, byte size and SHA-256.
abstract interface class YorksV1DocumentFileService {
  Future<YorksV1SelectedDocument?> selectDocument();

  Future<bool> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  });
}

class YorksV1SelectedDocument {
  const YorksV1SelectedDocument({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  final String fileName;
  final String mimeType;
  final Uint8List bytes;
}

class YorksV1PlatformDocumentFileService implements YorksV1DocumentFileService {
  const YorksV1PlatformDocumentFileService();

  static const _type = XTypeGroup(
    label: 'Controlled document',
    extensions: ['pdf', 'xlsx', 'docx', 'jpg', 'jpeg', 'png'],
    mimeTypes: [
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg',
      'image/png',
    ],
  );

  @override
  Future<YorksV1SelectedDocument?> selectDocument() async {
    final file = await openFile(acceptedTypeGroups: const [_type]);
    if (file == null) return null;
    final mimeType = _mimeFor(file.name);
    if (mimeType == null) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes > 6 * 1024 * 1024) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return YorksV1SelectedDocument(
      fileName: _fileName(file.name),
      mimeType: mimeType,
      bytes: bytes,
    );
  }

  @override
  Future<bool> saveDocument({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final location = await getSaveLocation(
      suggestedName: _fileName(fileName),
      acceptedTypeGroups: const [_type],
    );
    if (location == null) return false;
    final file = XFile.fromData(
      bytes,
      name: _fileName(fileName),
      mimeType: mimeType,
    );
    await file.saveTo(location.path);
    return true;
  }

  static String _fileName(String value) {
    final normalized = value.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  static String? _mimeFor(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }
}
