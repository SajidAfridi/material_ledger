import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_audit_workspace.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../sync/connectivity_service.dart';

abstract interface class YorksV1AuditRpcClient {
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  });
}

class SupabaseYorksV1AuditRpcClient implements YorksV1AuditRpcClient {
  const SupabaseYorksV1AuditRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

abstract interface class YorksV1AuditRepository {
  Future<YorksV1AuditWorkspace> getWorkspace(YorksV1AuditFilter filter);
  Future<YorksV1AuditWorkspace> exportWorkspace(
    YorksV1AuditFilter filter,
    String id,
  );
}

class YorksV1SupabaseAuditRepository implements YorksV1AuditRepository {
  const YorksV1SupabaseAuditRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1AuditRpcClient? rpcClient,
    Duration rpcTimeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _rpcTimeout = rpcTimeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1AuditRpcClient? _rpcClient;
  final Duration _rpcTimeout;

  @override
  Future<YorksV1AuditWorkspace> getWorkspace(YorksV1AuditFilter filter) async {
    return _invoke('v1_get_audit_workspace_v2', filter.toRpcParameters());
  }

  @override
  Future<YorksV1AuditWorkspace> exportWorkspace(
    YorksV1AuditFilter filter,
    String id,
  ) async {
    final workspace = await _invoke('v1_export_audit_workspace', {
      'p_filters': filter.toRpcParameters(),
      'p_id': id,
    });
    if (workspace.offset != 0 ||
        workspace.filteredCount > 5000 ||
        workspace.events.length != workspace.filteredCount) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return workspace;
  }

  Future<YorksV1AuditWorkspace> _invoke(
    String function,
    Map<String, Object?> parameters,
  ) async {
    if (!_featureFlags.foundation) {
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

    try {
      final response = await rpc
          .invoke(function, parameters: parameters)
          .timeout(_rpcTimeout);
      if (response is! Map) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      return YorksV1AuditWorkspace.fromRpcJson(
        Map<String, dynamic>.from(response),
      );
    } on YorksV1DomainException {
      rethrow;
    } on TimeoutException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    } on PostgrestException catch (error) {
      throw _mapPostgrest(error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  static YorksV1DomainException _mapPostgrest(PostgrestException error) {
    final code = switch (error.code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '22023' || '22007' || '22P02' => YorksV1DomainErrorCode.invalidInput,
      'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(code, serverCode: error.code, cause: error);
  }
}
