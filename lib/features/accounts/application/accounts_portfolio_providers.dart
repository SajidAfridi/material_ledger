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
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsProjectOverviewController(
        projectId: projectId,
        repository: ref.watch(yorksAccountsPortfolioRepositoryProvider),
      );
    });
