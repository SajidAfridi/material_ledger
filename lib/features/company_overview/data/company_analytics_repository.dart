import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../domain/company_analytics_models.dart';

abstract interface class CompanyAnalyticsRpcClient {
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  });
}

class SupabaseCompanyAnalyticsRpcClient implements CompanyAnalyticsRpcClient {
  const SupabaseCompanyAnalyticsRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke(
    String functionName, {
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

abstract interface class CompanyAnalyticsRepository {
  Future<CompanyAnalyticsProjection> getProjection(
    CompanyAnalyticsFilters filters,
  );
}

class SupabaseCompanyAnalyticsRepository implements CompanyAnalyticsRepository {
  const SupabaseCompanyAnalyticsRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    CompanyAnalyticsRpcClient? rpcClient,
    Duration timeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _timeout = timeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final CompanyAnalyticsRpcClient? _rpcClient;
  final Duration _timeout;

  @override
  Future<CompanyAnalyticsProjection> getProjection(
    CompanyAnalyticsFilters filters,
  ) async {
    if (!_featureFlags.analytics) {
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
      final raw = await rpc
          .invoke(
            'v1_get_operational_analytics_foundation',
            parameters: filters.toRpcParameters(),
          )
          .timeout(_timeout);
      if (raw is! Map) {
        throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        );
      }
      return CompanyAnalyticsProjection.fromRpcJson(
        Map<String, dynamic>.from(raw),
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
