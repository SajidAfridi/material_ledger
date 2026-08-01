import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/yorks_v1_logistics_repository.dart';
import '../repositories/yorks_v1_material_request_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

final yorksV1LogisticsRepositoryProvider = Provider<YorksV1LogisticsRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return YorksV1SupabaseLogisticsRepository(
      featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
      connectivity: ref.watch(connectivityProvider),
      rpcClient: client == null
          ? null
          : SupabaseYorksV1MaterialRequestRpcClient(client),
    );
  },
);
