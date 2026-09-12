import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_company_material_request.dart';
import '../repositories/yorks_v1_company_material_request_repository.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_material_request_repository_provider.dart';
import '../sync/connectivity_service.dart';

final yorksV1CompanyMaterialRequestRepositoryProvider =
    Provider<YorksV1CompanyMaterialRequestRepository>((ref) {
      return YorksV1SupabaseCompanyMaterialRequestRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
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
