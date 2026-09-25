import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_company_material_request.dart';
import '../services/analytics_service.dart';
import '../models/yorks_v1_material_request.dart';
import '../repositories/yorks_v1_company_material_request_repository.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_material_request_provider.dart';
import 'yorks_v1_permission_provider.dart';
import 'session_provider.dart' show authSessionRevisionProvider;
import 'yorks_v1_material_request_repository_provider.dart';
import '../sync/connectivity_service.dart';

final yorksV1CompanyMaterialRequestRepositoryProvider =
    Provider<YorksV1CompanyMaterialRequestRepository>((ref) {
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(authSessionRevisionProvider);
      yorksV1RefreshProtectedProjectionOnPermissionRevision(ref);
      return YorksV1SupabaseCompanyMaterialRequestRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        analytics: ref.watch(analyticsServiceProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksV1MaterialRequestRpcClientProvider),
      );
    });

final yorksV1CompanyMaterialRequestDraftOptionsProvider =
    FutureProvider.autoDispose<List<YorksV1CompanyMaterialRequestDraftOption>>((
      ref,
    ) {
      return ref
          .watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          .listDraftOptions();
    });

class YorksV1CompanyMaterialSearchKey {
  const YorksV1CompanyMaterialSearchKey({
    required this.categoryId,
    required this.responsibleUnitId,
    required this.query,
  });

  final String categoryId;
  final String responsibleUnitId;
  final String query;

  @override
  bool operator ==(Object other) =>
      other is YorksV1CompanyMaterialSearchKey &&
      other.categoryId == categoryId &&
      other.responsibleUnitId == responsibleUnitId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(categoryId, responsibleUnitId, query);
}

final yorksV1CompanyMaterialSearchProvider = FutureProvider.autoDispose
    .family<
      List<YorksV1MaterialRequestInventorySuggestion>,
      YorksV1CompanyMaterialSearchKey
    >((ref, key) {
      return ref
          .watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          .searchMaterials(
            categoryId: key.categoryId,
            responsibleUnitId: key.responsibleUnitId,
            query: key.query,
          );
    });

final yorksV1CompanyMaterialRequestApprovalInboxProvider =
    FutureProvider.autoDispose<
      List<YorksV1CompanyMaterialRequestApprovalInboxItem>
    >((ref) {
      ref.watch(yorksV1MaterialRequestRealtimeRevisionProvider);
      return ref
          .watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          .listApprovalInbox();
    });

final yorksV1CompanyMaterialRequestProvider = FutureProvider.autoDispose
    .family<YorksV1CompanyMaterialRequest, String>((ref, requestId) {
      ref.watch(yorksV1MaterialRequestRealtimeRevisionProvider);
      return ref
          .watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          .getRequest(requestId);
    });
