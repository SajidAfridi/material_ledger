import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/yorks_v1_documents_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_material_request_repository_provider.dart';

final yorksV1DocumentsRepositoryProvider = Provider<YorksV1DocumentsRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return YorksV1SupabaseDocumentsRepository(
      featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
      connectivity: ref.watch(connectivityProvider),
      rpcClient: ref.watch(yorksV1MaterialRequestRpcClientProvider),
      storageClient: client == null
          ? null
          : SupabaseYorksV1DocumentStorageClient(client),
      finalizerClient: client == null
          ? null
          : SupabaseYorksV1DocumentFinalizerClient(client),
    );
  },
);
