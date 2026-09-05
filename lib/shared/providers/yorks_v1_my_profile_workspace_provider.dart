import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_my_profile_workspace.dart';
import '../models/yorks_v1_role.dart';
import '../repositories/yorks_v1_my_profile_workspace_repository.dart';
import '../sync/connectivity_service.dart';
import 'session_provider.dart' show authSessionRevisionProvider;
import 'yorks_v1_feature_flags_provider.dart';
import 'yorks_v1_identity_provider.dart';
import 'yorks_v1_my_profile_provider.dart';
import 'yorks_v1_permission_provider.dart';

final yorksV1MyProfileWorkspaceRepositoryProvider =
    Provider<YorksV1MyProfileWorkspaceRepository>((ref) {
      return YorksV1SupabaseMyProfileWorkspaceRepository(
        enabled: ref.watch(yorksV1FeatureFlagsProvider).foundation,
        connectivity: ref.watch(connectivityProvider),
        rpc: ref.watch(yorksV1PermissionRpcClientProvider),
      );
    });

/// P04/P05 workspace facts are valid only beside a matching P01 response.
/// The P01 provider supplies the exact actor/role/revision binding; therefore
/// a role change, permission signal, offline state or logout clears both
/// profile surfaces rather than leaving a stale quick-action or scope card.
final yorksV1MyProfileWorkspaceProvider =
    StateNotifierProvider.autoDispose<
      YorksV1MyProfileWorkspaceController,
      AsyncValue<YorksV1MyProfileWorkspace>
    >((ref) {
      ref.watch(authSessionRevisionProvider);
      ref.watch(isOnlineProvider);
      ref.watch(
        yorksV1CurrentPermissionSnapshotProvider.select(
          (value) => (value.snapshot?.revision, value.isStale),
        ),
      );
      final profileState = ref.watch(yorksV1MyProfileProvider);
      final profile = profileState.valueOrNull;
      return YorksV1MyProfileWorkspaceController(
        repository: ref.watch(yorksV1MyProfileWorkspaceRepositoryProvider),
        authUserId: ref.watch(yorksV1AuthUserIdProvider),
        exactRole: ref.watch(yorksV1CurrentRoleProvider),
        expectedPermissionRevision: profile?.permissionRevision,
        dependencyError: profileState.error,
        dependencyStackTrace: profileState.stackTrace,
      );
    });

class YorksV1MyProfileWorkspaceController
    extends StateNotifier<AsyncValue<YorksV1MyProfileWorkspace>> {
  YorksV1MyProfileWorkspaceController({
    required this.repository,
    required this.authUserId,
    required this.exactRole,
    required this.expectedPermissionRevision,
    this.dependencyError,
    this.dependencyStackTrace,
  }) : super(
         dependencyError == null
             ? const AsyncLoading()
             : AsyncError(
                 dependencyError,
                 dependencyStackTrace ?? StackTrace.empty,
               ),
       ) {
    if (expectedPermissionRevision != null) {
      unawaited(refresh());
    }
  }

  final YorksV1MyProfileWorkspaceRepository repository;
  final String? authUserId;
  final YorksV1Role? exactRole;
  final int? expectedPermissionRevision;
  final Object? dependencyError;
  final StackTrace? dependencyStackTrace;
  int _generation = 0;

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation;
    state = const AsyncLoading();
    try {
      if (authUserId == null ||
          exactRole == null ||
          expectedPermissionRevision == null) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unauthenticated,
        );
      }
      final workspace = await repository.load(
        expectedAuthUserId: authUserId!,
        expectedRole: exactRole!,
        expectedPermissionRevision: expectedPermissionRevision!,
      );
      if (!mounted || generation != _generation) return;
      state = AsyncData(workspace);
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      state = AsyncError(error, stack);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
