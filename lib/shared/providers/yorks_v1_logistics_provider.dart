import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_logistics.dart';
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
