import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_document.dart';
import 'yorks_v1_documents_repository_provider.dart';

final yorksV1DocumentWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1DocumentWorkspace, String>((ref, projectId) {
      return ref
          .watch(yorksV1DocumentsRepositoryProvider)
          .getWorkspace(projectId);
    });
