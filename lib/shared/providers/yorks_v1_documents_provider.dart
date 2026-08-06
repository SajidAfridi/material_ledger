import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_document.dart';
import 'yorks_v1_documents_repository_provider.dart';
import 'yorks_v1_material_request_provider.dart';

final yorksV1DocumentWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1DocumentWorkspace, String>((ref, projectId) {
      // A receipt confirmation or Delivery Order can change the visible
      // project-document links. Re-fetch the authorized workspace on the same
      // metadata-only Material Request signal.
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1DocumentsRepositoryProvider)
          .getWorkspace(projectId);
    });
