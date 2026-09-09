import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_material_request_history.dart';
import '../repositories/yorks_v1_material_request_history_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_material_request_provider.dart';
import 'yorks_v1_permission_provider.dart';

final yorksV1MaterialRequestHistoryRpcClientProvider =
    Provider<YorksV1MaterialRequestHistoryRpcClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1MaterialRequestHistoryRpcClient(client);
    });

final yorksV1MaterialRequestHistoryRepositoryProvider =
    Provider<YorksV1MaterialRequestHistoryRepository>((ref) {
      return YorksV1SupabaseMaterialRequestHistoryRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksV1MaterialRequestHistoryRpcClientProvider),
      );
    });

final yorksV1MaterialRequestHistoryPageProvider = FutureProvider.autoDispose
    .family<
      YorksV1MaterialRequestHistoryPage,
      YorksV1MaterialRequestHistoryQuery
    >((ref, query) {
      yorksV1RefreshProtectedProjectionOnPermissionRevision(ref);
      // A completed workflow command refreshes this trusted detail projection
      // immediately. The detail projection owns the recipient-scoped
      // Realtime subscription, so watching it keeps this secondary inspector
      // current without opening a duplicate subscription.
      ref.watch(yorksV1MaterialRequestDetailProvider(query.requestId));
      return ref
          .watch(yorksV1MaterialRequestHistoryRepositoryProvider)
          .getHistory(query);
    });
