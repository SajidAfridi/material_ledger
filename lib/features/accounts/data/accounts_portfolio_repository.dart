import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../domain/accounts_portfolio_models.dart';
import 'accounts_repository.dart';

abstract interface class YorksAccountsPortfolioRepository {
  Future<YorksAccountsPortfolioProjection> getPortfolio(
    YorksAccountsPortfolioFilters filters,
  );

  Future<YorksAccountsProjectOverviewProjection> getProjectOverview(
    String projectId,
  );
}

final class YorksSupabaseAccountsPortfolioRepository
    implements YorksAccountsPortfolioRepository {
  const YorksSupabaseAccountsPortfolioRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksAccountsRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksAccountsRpcClient? _rpcClient;

  @override
  Future<YorksAccountsPortfolioProjection> getPortfolio(
    YorksAccountsPortfolioFilters filters,
  ) async {
    if (filters.limit < 1 || filters.limit > 100) return _invalidInput();
    final response = await _invoke(
      'v1_get_accounts_portfolio',
      filters.toRpcParameters(),
    );
    try {
      return YorksAccountsPortfolioProjection.fromRpcJson(response);
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  @override
  Future<YorksAccountsProjectOverviewProjection> getProjectOverview(
    String projectId,
  ) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return _invalidInput();
    final response = await _invoke('v1_get_project_accounts_overview', {
      'p_project_id': normalized,
    });
    try {
      final projection = YorksAccountsProjectOverviewProjection.fromRpcJson(
        response,
      );
      if (projection.projectId != normalized) {
        throw const FormatException('Accounts project identity mismatch.');
      }
      return projection;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String functionName,
    Map<String, Object?> parameters,
  ) async {
    if (!_featureFlags.accounts) {
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
      return await rpc.invoke(
        functionName: functionName,
        parameters: parameters,
      );
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      final message = [
        error.message,
        error.details?.toString(),
        error.hint?.toString(),
      ].whereType<String>().join(' ').toUpperCase();
      final code = switch (error.code) {
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' ||
        '28000' => YorksV1DomainErrorCode.unauthenticated,
        '42501' => YorksV1DomainErrorCode.unauthorized,
        '22023' || '22P02' => YorksV1DomainErrorCode.invalidInput,
        'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
        _ when message.contains('R39_ACCOUNTS_ACCESS_DENIED') =>
          YorksV1DomainErrorCode.unauthorized,
        _ => YorksV1DomainErrorCode.serverRejected,
      };
      throw YorksV1DomainException(
        code,
        serverCode: error.code,
        serverMessage: error.message,
        cause: error,
      );
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }
}

Never _invalidInput() =>
    throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
