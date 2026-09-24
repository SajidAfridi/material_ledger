import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_workspace_search.dart';
import '../repositories/yorks_v1_workspace_search_repository.dart';
import 'yorks_v1_boq_repository_provider.dart';
import 'yorks_v1_documents_repository_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_logistics_repository_provider.dart';
import 'yorks_v1_material_request_repository_provider.dart';
import 'yorks_v1_project_portfolio_provider.dart';
import 'session_provider.dart' show authSessionRevisionProvider;
import 'yorks_v1_permission_provider.dart';
import 'yorks_v1_company_material_request_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import '../repositories/yorks_v1_company_material_request_repository.dart';

final yorksV1WorkspaceSearchRepositoryProvider =
    Provider<YorksV1WorkspaceSearchRepository>((ref) {
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(authSessionRevisionProvider);
      yorksV1RefreshProtectedProjectionOnPermissionRevision(ref);
      final company =
          ref.watch(yorksV1FeatureFlagsProvider).companyMaterialRequests
          ? ref.watch(yorksV1CompanyMaterialRequestRepositoryProvider)
          : null;
      return YorksV1WorkspaceSearchRepository(
        companyRequests: company is YorksV1CompanyMaterialRequestPagedRepository
            ? company as YorksV1CompanyMaterialRequestPagedRepository
            : null,
        projects: ref.watch(yorksV1ProjectPortfolioRepositoryProvider),
        materialRequests: ref.watch(yorksV1MaterialRequestRepositoryProvider),
        boq: ref.watch(yorksV1BoqRepositoryProvider),
        documents: ref.watch(yorksV1DocumentsRepositoryProvider),
        logistics: ref.watch(yorksV1LogisticsRepositoryProvider),
      );
    });

final yorksV1WorkspaceSearchResultsProvider = FutureProvider.autoDispose
    .family<YorksV1WorkspaceSearchResponse, String>((ref, query) {
      final role = ref.watch(yorksV1CurrentRoleProvider);
      return ref
          .watch(yorksV1WorkspaceSearchRepositoryProvider)
          .search(query, role: role);
    });
