import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/yorks_v1_boq_workbook_service.dart';

/// Platform file operations and OOXML codec remain injectable so widget tests
/// can verify the reviewed import flow without opening a native picker.
final yorksV1BoqWorkbookFileServiceProvider =
    Provider<YorksV1BoqWorkbookFileService>(
      (ref) => const YorksV1PlatformBoqWorkbookFileService(),
    );

final yorksV1BoqWorkbookCodecProvider = Provider<YorksV1BoqWorkbookCodec>(
  (ref) => const YorksV1BoqWorkbookCodec(),
);
