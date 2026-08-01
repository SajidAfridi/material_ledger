import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_boq_controller.dart';
import '../models/yorks_v1_boq.dart';
import 'yorks_v1_boq_repository_provider.dart';

final yorksV1BoqGroupsProvider = FutureProvider.autoDispose
    .family<List<YorksV1BoqGroup>, String>((ref, projectId) {
      return ref.watch(yorksV1BoqRepositoryProvider).listGroups(projectId);
    });

final yorksV1BoqWorksheetControllerProvider = StateNotifierProvider.autoDispose
    .family<YorksV1BoqWorksheetController, YorksV1BoqWorksheetState, String>((
      ref,
      groupId,
    ) {
      final controller = YorksV1BoqWorksheetController(
        groupId: groupId,
        repository: ref.watch(yorksV1BoqRepositoryProvider),
      );
      Future<void>.microtask(controller.load);
      return controller;
    });
