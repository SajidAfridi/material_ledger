import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_project.dart';
import '../sync/connectivity_service.dart';

/// Narrow RPC seam for the normalized Yorks V1 project domain.
///
/// It makes repository tests independent of a live Supabase client and keeps
/// raw PostgREST values out of controller and widget code.
abstract interface class YorksV1ProjectRpcClient {
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, dynamic> parameters,
  });
}

class SupabaseYorksV1ProjectRpcClient implements YorksV1ProjectRpcClient {
  const SupabaseYorksV1ProjectRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, dynamic> parameters,
  }) async {
    final response = await _client.rpc(functionName, params: parameters);
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.length == 1 && response.single is Map) {
      return Map<String, dynamic>.from(response.single as Map);
    }
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }
}

/// Normalized project commands. Reads are intentionally not added here until
/// Batch 2 secure views and route integration establish their projection shape.
abstract interface class YorksV1ProjectRepository {
  Future<YorksV1ProjectCreationResult> createProject(
    YorksV1ProjectCreationInput input,
  );

  Future<YorksV1ProjectMembershipResult> assignProjectMember(
    YorksV1AssignProjectMemberInput input,
  );

  Future<YorksV1ProjectMembershipResult> revokeProjectMember(
    YorksV1RevokeProjectMemberInput input,
  );

  Future<YorksV1Project> setProjectState(YorksV1SetProjectStateInput input);
}

/// Connected V1 implementation. There is deliberately no local project-write
/// fallback: creation, membership and state changes require an online trusted
/// Postgres transaction.
class YorksV1SupabaseProjectRepository implements YorksV1ProjectRepository {
  const YorksV1SupabaseProjectRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1ProjectRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1ProjectRpcClient? _rpcClient;

  @override
  Future<YorksV1ProjectCreationResult> createProject(
    YorksV1ProjectCreationInput input,
  ) async {
    _throwIfInvalid(input.validate());
    final rpc = _readyRpc();
    try {
      final response = await rpc.invoke(
        functionName: 'v1_create_project',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey.trim(),
        },
      );
      return YorksV1ProjectCreationResult.fromRpcJson(response);
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

  @override
  Future<YorksV1ProjectMembershipResult> assignProjectMember(
    YorksV1AssignProjectMemberInput input,
  ) async {
    _throwIfInvalid(input.validate());
    final rpc = _readyRpc();
    try {
      final response = await rpc.invoke(
        functionName: 'v1_assign_project_member',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey.trim(),
        },
      );
      return YorksV1ProjectMembershipResult.fromRpcJson(response);
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

  @override
  Future<YorksV1ProjectMembershipResult> revokeProjectMember(
    YorksV1RevokeProjectMemberInput input,
  ) async {
    _throwIfInvalid(input.validate());
    final rpc = _readyRpc();
    try {
      final response = await rpc.invoke(
        functionName: 'v1_revoke_project_member',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey.trim(),
        },
      );
      return YorksV1ProjectMembershipResult.fromRpcJson(response);
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

  @override
  Future<YorksV1Project> setProjectState(
    YorksV1SetProjectStateInput input,
  ) async {
    _throwIfInvalid(input.validate());
    final rpc = _readyRpc();
    try {
      final response = await rpc.invoke(
        functionName: 'v1_set_project_state',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey.trim(),
        },
      );
      final projectJson = response['project'];
      if (projectJson is Map) {
        return YorksV1Project.fromRpcJson(
          Map<String, dynamic>.from(projectJson),
        );
      }
      return YorksV1Project.fromRpcJson(response);
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

  YorksV1ProjectRpcClient _readyRpc() {
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

  void _throwIfInvalid(Set<YorksV1ProjectValidationCode> errors) {
    if (errors.isEmpty) return;
    throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
  }

  YorksV1DomainException _mapPostgrestException(PostgrestException error) {
    final code = error.code;
    final domainCode = switch (code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '23505' || '40001' => YorksV1DomainErrorCode.conflict,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(domainCode, serverCode: code, cause: error);
  }
}
