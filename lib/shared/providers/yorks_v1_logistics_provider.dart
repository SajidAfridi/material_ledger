import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_logistics.dart';
import '../models/yorks_v1_material_return_workflow.dart';
import '../models/yorks_v1_material_request.dart';
import '../repositories/yorks_v1_logistics_repository.dart';
import 'yorks_v1_logistics_repository_provider.dart';
import 'yorks_v1_material_request_provider.dart';

final yorksV1InventoryWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1InventoryWorkspace, String?>((ref, search) {
      return ref
          .watch(yorksV1LogisticsRepositoryProvider)
          .getInventory(search: search);
    });

final yorksV1InventoryItemDetailProvider = FutureProvider.autoDispose
    .family<YorksV1InventoryItemDetail, String>((ref, inventoryItemId) {
      return ref
          .watch(yorksV1LogisticsRepositoryProvider)
          .getInventoryItem(inventoryItemId);
    });

final yorksV1InventoryCategorySuggestionsProvider = FutureProvider.autoDispose
    .family<List<YorksV1InventoryCategorySearchResult>, String>((
      ref,
      query,
    ) async {
      final repository = ref.watch(yorksV1LogisticsRepositoryProvider);
      if (repository is! YorksV1InventoryCategorySuggestionRepository ||
          query.trim().isEmpty) {
        return const [];
      }
      final suggestionRepository =
          repository as YorksV1InventoryCategorySuggestionRepository;
      return suggestionRepository.suggestInventoryCategories(query);
    });

final yorksV1LogisticsWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1LogisticsWorkspace, String>((ref, requestId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1LogisticsRepositoryProvider)
          .getWorkspace(requestId);
    });

final yorksV1ProjectMaterialMovementsProvider = FutureProvider.autoDispose
    .family<List<YorksV1ProjectMaterialMovement>, String>((ref, projectId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1LogisticsRepositoryProvider)
          .getProjectMaterialMovements(projectId);
    });

final yorksV1ReturnsDocumentsWorkspaceProvider = FutureProvider.autoDispose
    .family<YorksV1ReturnsDocumentsWorkspace, String>((ref, requestId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return ref
          .watch(yorksV1LogisticsRepositoryProvider)
          .getReturnsDocumentsWorkspace(requestId);
    });

class YorksV1MaterialReturnRegisterQuery {
  const YorksV1MaterialReturnRegisterQuery({
    this.projectId,
    this.state,
    this.search,
  });

  final String? projectId;
  final String? state;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is YorksV1MaterialReturnRegisterQuery &&
      other.projectId == projectId &&
      other.state == state &&
      other.search == search;

  @override
  int get hashCode => Object.hash(projectId, state, search);
}

final yorksV1MaterialReturnRegisterProvider = FutureProvider.autoDispose
    .family<
      List<YorksV1MaterialReturnRegisterItem>,
      YorksV1MaterialReturnRegisterQuery
    >((ref, query) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return _projectReturnRepository(ref).listProjectMaterialReturns(
        projectId: query.projectId,
        state: query.state,
        search: query.search,
      );
    });

final yorksV1MaterialReturnProjectsProvider =
    FutureProvider.autoDispose<List<YorksV1MaterialRequestProjectOption>>(
      (ref) => _projectReturnRepository(ref).listMaterialReturnProjects(),
    );

final yorksV1ProjectMaterialReturnProvider = FutureProvider.autoDispose
    .family<YorksV1ProjectMaterialReturn, String>((ref, returnId) {
      ref.listen<int>(yorksV1MaterialRequestRealtimeRevisionProvider, (
        previous,
        next,
      ) {
        if (previous != null && previous != next) ref.invalidateSelf();
      });
      return _projectReturnRepository(ref).getProjectMaterialReturn(returnId);
    });

typedef YorksV1MaterialReturnCreationKey = ({
  String projectId,
  String? returnId,
});

final yorksV1MaterialReturnCreationWorkspaceProvider = FutureProvider
    .autoDispose
    .family<
      YorksV1MaterialReturnCreationWorkspace,
      YorksV1MaterialReturnCreationKey
    >((ref, key) {
      return _projectReturnRepository(ref).getMaterialReturnCreationWorkspace(
        projectId: key.projectId,
        returnId: key.returnId,
      );
    });

YorksV1ProjectMaterialReturnRepository _projectReturnRepository(Ref ref) {
  final repository = ref.watch(yorksV1LogisticsRepositoryProvider);
  if (repository is! YorksV1ProjectMaterialReturnRepository) {
    throw const YorksV1DomainException(YorksV1DomainErrorCode.featureDisabled);
  }
  return repository as YorksV1ProjectMaterialReturnRepository;
}
