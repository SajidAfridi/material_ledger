import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/yorks_v1_document_file_service.dart';

final yorksV1DocumentFileServiceProvider = Provider<YorksV1DocumentFileService>(
  (_) => const YorksV1PlatformDocumentFileService(),
);
