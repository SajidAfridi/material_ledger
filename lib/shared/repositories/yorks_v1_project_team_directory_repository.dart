import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_project_team_directory_member.dart';
import '../sync/connectivity_service.dart';

/// Narrow, read-only seam for the protected V1 project team picker RPC.
///
/// The seam returns only the three fields in the safe directory projection.
/// No widget receives a Supabase client or a raw PostgREST response.
abstract interface class YorksV1ProjectTeamDirectoryRpcClient {
  Future<List<Map<String, dynamic>>> listActiveMembers();
}

class SupabaseYorksV1ProjectTeamDirectoryRpcClient
    implements YorksV1ProjectTeamDirectoryRpcClient {
  const SupabaseYorksV1ProjectTeamDirectoryRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> listActiveMembers() async {
    final response = await _client.rpc('v1_list_active_profile_directory');
    return parseResponse(response);
  }

  /// Validates the wire envelope before typed member parsing. Keeping this
  /// separate makes a malformed function response fail closed instead of
  /// becoming an empty or dynamically shaped picker state.
  static List<Map<String, dynamic>> parseResponse(Object? response) {
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    final rows = <Map<String, dynamic>>[];
    for (final row in response) {
      if (row is! Map) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      rows.add(Map<String, dynamic>.from(row));
    }
    return rows;
  }
}

abstract interface class YorksV1ProjectTeamDirectoryRepository {
  Future<List<YorksV1ProjectTeamDirectoryMember>> listActiveMembers();
}

/// Connected implementation for the one protected team-directory read.
///
/// This has no offline cache: an inactive or changed identity must not remain
/// available for a new initial project assignment.
class YorksV1SupabaseProjectTeamDirectoryRepository
    implements YorksV1ProjectTeamDirectoryRepository {
  const YorksV1SupabaseProjectTeamDirectoryRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1ProjectTeamDirectoryRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1ProjectTeamDirectoryRpcClient? _rpcClient;

  @override
  Future<List<YorksV1ProjectTeamDirectoryMember>> listActiveMembers() async {
    final rpc = _readyRpc();
    try {
      final rows = await rpc.listActiveMembers();
      final seenAuthUserIds = <String>{};
      final members = <YorksV1ProjectTeamDirectoryMember>[];
      for (final row in rows) {
        final member = YorksV1ProjectTeamDirectoryMember.fromRpcJson(row);
        if (!seenAuthUserIds.add(member.authUserId)) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          );
        }
        members.add(member);
      }
      return List.unmodifiable(members);
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  YorksV1ProjectTeamDirectoryRpcClient _readyRpc() {
    if (!_featureFlags.projects) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (!_connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    final rpc = _rpcClient;
    if (rpc == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    return rpc;
  }

  YorksV1DomainException _mapPostgrestException(PostgrestException error) {
    final code = error.code;
    final domainCode = switch (code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '40001' => YorksV1DomainErrorCode.conflict,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(domainCode, serverCode: code, cause: error);
  }
}
