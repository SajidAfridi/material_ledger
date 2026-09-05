import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_my_profile_workspace.dart';
import '../models/yorks_v1_role.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_permission_repository.dart';

abstract interface class YorksV1MyProfileWorkspaceRepository {
  Future<YorksV1MyProfileWorkspace> load({
    required String expectedAuthUserId,
    required YorksV1Role expectedRole,
    required int expectedPermissionRevision,
  });
}

/// Fetches only the P04/P05 self workspace sidecar.
///
/// The caller must first possess the strict P01 profile. Binding the actor,
/// exact role and permission revision prevents a newer aggregate response from
/// being combined with an older P01 action list.
class YorksV1SupabaseMyProfileWorkspaceRepository
    implements YorksV1MyProfileWorkspaceRepository {
  const YorksV1SupabaseMyProfileWorkspaceRepository({
    required this.enabled,
    required this.connectivity,
    required this.rpc,
    this.timeout = const Duration(seconds: 20),
  });

  final bool enabled;
  final ConnectivityService connectivity;
  final YorksV1PermissionRpcClient? rpc;
  final Duration timeout;

  @override
  Future<YorksV1MyProfileWorkspace> load({
    required String expectedAuthUserId,
    required YorksV1Role expectedRole,
    required int expectedPermissionRevision,
  }) async {
    if (!enabled) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (!connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    if (rpc == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    if (expectedAuthUserId.isEmpty || expectedPermissionRevision < 0) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }

    Object? response;
    try {
      response = await rpc!
          .invoke(
            functionName: 'v1_get_my_yorks_profile_workspace',
            parameters: const {},
          )
          .timeout(timeout);
    } on PostgrestException catch (error) {
      throw YorksV1DomainException(switch (error.code) {
        '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
        _ => YorksV1DomainErrorCode.backendUnavailable,
      });
    } catch (_) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }

    try {
      final workspace = YorksV1MyProfileWorkspace.fromRpcJson(response);
      if (workspace.authUserId != expectedAuthUserId ||
          workspace.exactRole != expectedRole ||
          workspace.permissionRevision != expectedPermissionRevision) {
        throw const FormatException('My Yorks workspace response mismatch');
      }
      return workspace;
    } on FormatException {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
  }
}
