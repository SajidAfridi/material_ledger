import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/accounts_office_repository.dart';
import '../domain/accounts_office_models.dart';
import 'accounts_office_controller.dart';
import 'accounts_providers.dart';

final yorksAccountsOfficeRepositoryProvider =
    Provider<YorksAccountsOfficeRepository>((ref) {
      return YorksSupabaseAccountsOfficeRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksAccountsRpcClientProvider),
      );
    });

final yorksAccountsOfficeControllerProvider = StateNotifierProvider.autoDispose
    .family<
      YorksAccountsOfficeController,
      YorksAccountsOfficeState,
      YorksAccountsOfficeSection
    >((ref, section) {
      ref.keepAlive();
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsOfficeController(
        section: section,
        repository: ref.watch(yorksAccountsOfficeRepositoryProvider),
      );
    });
