import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/yorks_v1_project_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';

/// The raw RPC seam stays overrideable for repository/controller tests.
final yorksV1ProjectRpcClientProvider = Provider<YorksV1ProjectRpcClient?>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return client == null ? null : SupabaseYorksV1ProjectRpcClient(client);
});

/// The only Flutter-to-server project mutation implementation. It does not
/// fall back to a legacy CollectionStore or outbox for committed V1 commands.
final yorksV1ProjectRepositoryProvider = Provider<YorksV1ProjectRepository>((
  ref,
) {
  return YorksV1SupabaseProjectRepository(
    featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
    connectivity: ref.watch(connectivityProvider),
    rpcClient: ref.watch(yorksV1ProjectRpcClientProvider),
  );
});
