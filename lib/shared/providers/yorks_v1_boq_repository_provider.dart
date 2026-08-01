import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/yorks_v1_boq_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

final yorksV1BoqRpcClientProvider = Provider<YorksV1BoqRpcClient?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseYorksV1BoqRpcClient(client);
});

final yorksV1BoqRepositoryProvider = Provider<YorksV1BoqRepository>((ref) {
  return YorksV1SupabaseBoqRepository(
    featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
    connectivity: ref.watch(connectivityProvider),
    rpcClient: ref.watch(yorksV1BoqRpcClientProvider),
  );
});
