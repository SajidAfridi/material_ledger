import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/accounts_portfolio_repository.dart';
import 'accounts_portfolio_controller.dart';
import 'accounts_providers.dart';

final yorksAccountsPortfolioRepositoryProvider =
    Provider<YorksAccountsPortfolioRepository>((ref) {
      return YorksSupabaseAccountsPortfolioRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksAccountsRpcClientProvider),
      );
    });

final yorksAccountsPortfolioControllerProvider =
    StateNotifierProvider.autoDispose<
      YorksAccountsPortfolioController,
      YorksAccountsPortfolioState
    >((ref) {
      // Preserve the confirmed portfolio while users inspect a project,
      // export a register, or return through browser history. Identity,
      // role, and permission-epoch changes below still invalidate the cache.
      ref.keepAlive();
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsPortfolioController(
        ref.watch(yorksAccountsPortfolioRepositoryProvider),
      );
    });

final yorksAccountsProjectOverviewControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      YorksAccountsProjectOverviewController,
      YorksAccountsProjectOverviewState,
      String
    >((ref, projectId) {
      // Keep the latest confirmed projection across Accounts tab routes and
      // browser print round-trips. Any identity, role or permission-epoch
      // change below still invalidates this provider and purges the cache.
      ref.keepAlive();
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsProjectOverviewController(
        projectId: projectId,
        repository: ref.watch(yorksAccountsPortfolioRepositoryProvider),
      );
    });
