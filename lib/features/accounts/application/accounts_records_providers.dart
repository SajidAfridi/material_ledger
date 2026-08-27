import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/yorks_v1_documents_repository_provider.dart';
import '../../../shared/providers/yorks_v1_feature_flags_provider.dart';
import '../../../shared/providers/yorks_v1_identity_provider.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../data/accounts_records_repository.dart';
import '../data/accounts_report_service.dart';
import 'accounts_providers.dart';
import 'accounts_records_controller.dart';

final yorksAccountsRecordsRepositoryProvider =
    Provider<YorksAccountsRecordsRepository>((ref) {
      return YorksSupabaseAccountsRecordsRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksAccountsRpcClientProvider),
      );
    });

final yorksAccountsReportServiceProvider = Provider<YorksAccountsReportService>(
  (_) => const YorksAccountsReportService(),
);

final yorksAccountsDocumentsControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      YorksAccountsDocumentsController,
      YorksAccountsDocumentsState,
      String
    >((ref, projectId) {
      ref.keepAlive();
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsDocumentsController(
        projectId: projectId,
        repository: ref.watch(yorksV1AccountsDocumentsRepositoryProvider),
      );
    });

final yorksAccountsActivityControllerProvider = StateNotifierProvider
    .autoDispose
    .family<
      YorksAccountsActivityController,
      YorksAccountsActivityState,
      String
    >((ref, projectId) {
      ref.keepAlive();
      ref.watch(yorksV1CurrentRoleProvider);
      ref.watch(yorksV1AuthUserIdProvider);
      ref.watch(yorksAccountsPermissionEpochProvider);
      return YorksAccountsActivityController(
        projectId: projectId,
        repository: ref.watch(yorksAccountsRecordsRepositoryProvider),
      );
    });
