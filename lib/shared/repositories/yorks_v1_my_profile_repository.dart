import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_my_profile.dart';
import '../models/yorks_v1_role.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_permission_repository.dart';

abstract interface class YorksV1MyProfileRepository {
  Future<YorksV1MyProfile> load({
    required String expectedAuthUserId,
    required YorksV1Role expectedRole,
    int projectOffset = 0,
    int projectLimit = 25,
  });
}

class YorksV1SupabaseMyProfileRepository implements YorksV1MyProfileRepository {
  const YorksV1SupabaseMyProfileRepository({
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
  Future<YorksV1MyProfile> load({
    required String expectedAuthUserId,
    required YorksV1Role expectedRole,
    int projectOffset = 0,
    int projectLimit = 25,
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
    if (projectOffset < 0 ||
        projectLimit < 1 ||
        projectLimit > 50 ||
        expectedAuthUserId.isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    Object? response;
    try {
      response = await rpc!
          .invoke(
            functionName: 'v1_get_my_yorks_profile',
            parameters: {
              'p_project_offset': projectOffset,
              'p_project_limit': projectLimit,
            },
          )
          .timeout(timeout);
    } on PostgrestException catch (error) {
      throw YorksV1DomainException(switch (error.code) {
        '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
        '22023' => YorksV1DomainErrorCode.invalidInput,
        _ => YorksV1DomainErrorCode.backendUnavailable,
      });
    } catch (_) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    try {
      final profile = YorksV1MyProfile.fromRpcJson(response);
      if (profile.authUserId != expectedAuthUserId ||
          profile.exactRole != expectedRole ||
          profile.projectOffset != projectOffset ||
          profile.projects.length > projectLimit) {
        throw const FormatException(
          'My Yorks response identity or page mismatch',
        );
      }
      return profile;
    } on FormatException {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
  }
}
