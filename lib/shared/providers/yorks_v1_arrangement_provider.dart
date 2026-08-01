import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_arrangement.dart';
import 'yorks_v1_arrangement_repository_provider.dart';

final yorksV1ArrangementWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1ArrangementWorkspace, String>((ref, requestId) {
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
