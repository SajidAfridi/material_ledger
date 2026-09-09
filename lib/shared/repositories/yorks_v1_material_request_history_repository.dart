import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_material_request_history.dart';
import '../sync/connectivity_service.dart';

abstract interface class YorksV1MaterialRequestHistoryRpcClient {
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  });
}

class SupabaseYorksV1MaterialRequestHistoryRpcClient
    implements YorksV1MaterialRequestHistoryRpcClient {
  const SupabaseYorksV1MaterialRequestHistoryRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

abstract interface class YorksV1MaterialRequestHistoryRepository {
  Future<YorksV1MaterialRequestHistoryPage> getHistory(
    YorksV1MaterialRequestHistoryQuery query,
  );
}

class YorksV1SupabaseMaterialRequestHistoryRepository
    implements YorksV1MaterialRequestHistoryRepository {
  const YorksV1SupabaseMaterialRequestHistoryRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestHistoryRpcClient? rpcClient,
    Duration rpcTimeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _rpcTimeout = rpcTimeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestHistoryRpcClient? _rpcClient;
  final Duration _rpcTimeout;

  @override
  Future<YorksV1MaterialRequestHistoryPage> getHistory(
    YorksV1MaterialRequestHistoryQuery query,
  ) async {
    if (!_featureFlags.requests) {
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
          .invoke(
            'v1_get_material_request_history',
            parameters: query.toRpcParameters(),
          )
          .timeout(_rpcTimeout);
      if (response is! Map) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      return YorksV1MaterialRequestHistoryPage.fromRpcJson(
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
      final code = switch (error.code) {
        '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
        '22023' || '22007' || '22P02' => YorksV1DomainErrorCode.invalidInput,
        'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
        _ => YorksV1DomainErrorCode.serverRejected,
      };
      throw YorksV1DomainException(code, serverCode: error.code, cause: error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }
}
