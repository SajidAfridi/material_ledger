import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_project_team_directory_member.dart';
import '../repositories/yorks_v1_project_team_directory_repository.dart';
import '../sync/connectivity_service.dart';
import 'language_provider.dart';
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';

/// Overrideable low-level seam for safe-directory repository tests.
final yorksV1ProjectTeamDirectoryRpcClientProvider =
    Provider<YorksV1ProjectTeamDirectoryRpcClient?>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return client == null
          ? null
          : SupabaseYorksV1ProjectTeamDirectoryRpcClient(client);
    });

/// The only connected implementation for initial team-member selection.
final yorksV1ProjectTeamDirectoryRepositoryProvider =
    Provider<YorksV1ProjectTeamDirectoryRepository>((ref) {
      return YorksV1SupabaseProjectTeamDirectoryRepository(
        featureFlags: ref.watch(yorksV1FeatureFlagsProvider),
        connectivity: ref.watch(connectivityProvider),
        rpcClient: ref.watch(yorksV1ProjectTeamDirectoryRpcClientProvider),
      );
    });

/// The safe directory projection used by the project-creation UI.
///
/// It is queried only while the relevant access/review screen is visible and
/// is never written to local storage or an offline cache. Authentication and
/// exact-role changes invalidate its dependency graph. A signed-in user
/// without an exact V1 project-creation role never enters this provider's
/// state.
final yorksV1ActiveProjectTeamDirectoryProvider =
    FutureProvider.autoDispose<List<YorksV1ProjectTeamDirectoryMember>>((
      ref,
    ) async {
      final authUserId = ref.watch(yorksV1AuthUserIdProvider);
      if (authUserId == null || authUserId.trim().isEmpty) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unauthenticated,
        );
      }
      final role = ref.watch(yorksV1CurrentRoleProvider);
      if (role == null || !role.canCreateProject) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.unauthorized);
      }
      return ref
          .watch(yorksV1ProjectTeamDirectoryRepositoryProvider)
          .listActiveMembers();
    });
