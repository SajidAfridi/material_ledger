import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_arrangement.dart';
import 'yorks_v1_arrangement_repository_provider.dart';

final yorksV1ArrangementWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1ArrangementWorkspace, String>((ref, requestId) {
      // An active arrangement is a transactional editor with an expected
      // server version. Rebuilding it on every Realtime/fallback revision can
      // dispose text controllers and inventory state while Procurement is
      // typing. Lists and record details still refresh from Realtime; this
      // editor refreshes only on an explicit user action or confirmed command.
      // A competing write is rejected safely by v1_save_arrangement's version
      // check instead of being merged into the in-progress form.
      return ref
          .watch(yorksV1ArrangementRepositoryProvider)
          .getWorkspace(requestId);
    });

final yorksV1ArrangementInventoryProvider =
    FutureProvider.autoDispose<List<YorksV1InventoryItem>>((ref) {
      return ref
          .watch(yorksV1ArrangementRepositoryProvider)
          .listInventoryItems();
    });
