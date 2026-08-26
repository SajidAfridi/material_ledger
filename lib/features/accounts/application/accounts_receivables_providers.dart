import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/language_provider.dart';
import '../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../shared/services/yorks_v1_critical_command_key_store.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/accounts_receivables_repository.dart';
import 'accounts_providers.dart';
import 'accounts_receivables_controller.dart';

final yorksAccountsReceivablesRepositoryProvider =
    Provider<YorksAccountsReceivablesRepository>((ref) {
      return YorksSupabaseAccountsReceivablesRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksAccountsRpcClientProvider),
      );
    });

/// T03 remains route-less and disabled until the later Accounts UI rollout.
/// Watching exact role, permission epoch and immutable auth identity ensures
/// same-user revocation disposes every protected receivables projection.
final yorksAccountsReceivablesControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      YorksAccountsReceivablesController,
      YorksAccountsReceivablesState,
      String
    >((ref, projectId) {
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      final actorAuthUserId = ref.watch(yorksV1AuthUserIdProvider) ?? '';
      return YorksAccountsReceivablesController(
        projectId: projectId,
        repository: ref.watch(yorksAccountsReceivablesRepositoryProvider),
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: ref.watch(sharedPreferencesProvider),
          actorAuthUserId: actorAuthUserId,
        ),
      );
    });
