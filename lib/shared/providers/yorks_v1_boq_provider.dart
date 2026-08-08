import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/yorks_v1_boq_controller.dart';
import '../models/yorks_v1_boq.dart';
import 'yorks_v1_boq_repository_provider.dart';

final yorksV1BoqGroupsProvider = FutureProvider.autoDispose
    .family<List<YorksV1BoqGroup>, String>((ref, projectId) {
      return ref.watch(yorksV1BoqRepositoryProvider).listGroups(projectId);
    });

class YorksV1BoqScopeQuery {
  const YorksV1BoqScopeQuery({required this.projectId, this.scopeId});

  final String projectId;
  final String? scopeId;

  @override
  bool operator ==(Object other) =>
      other is YorksV1BoqScopeQuery &&
      other.projectId == projectId &&
      other.scopeId == scopeId;

  @override
  int get hashCode => Object.hash(projectId, scopeId);
}

final yorksV1ScopedBoqGroupsProvider = FutureProvider.autoDispose
    .family<List<YorksV1BoqGroup>, YorksV1BoqScopeQuery>((ref, query) {
      return ref
          .watch(yorksV1BoqRepositoryProvider)
          .listGroupsForScope(query.projectId, scopeId: query.scopeId);
    });

final yorksV1BoqScopeSelectionProvider = StateProvider.autoDispose
    .family<String?, String>((ref, projectId) => null);

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
