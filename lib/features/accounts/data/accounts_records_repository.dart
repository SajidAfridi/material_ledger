import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../domain/accounts_records_models.dart';
import 'accounts_repository.dart';

abstract interface class YorksAccountsRecordsRepository {
  Future<YorksAccountsActivityProjection> getActivity(
    String projectId,
    YorksAccountsActivityFilters filters,
  );

  Future<YorksAccountsReportProjection> getReport(
    YorksAccountsReportKind kind, {
    String? projectId,
    required String idempotencyKey,
  });
}

final class YorksSupabaseAccountsRecordsRepository
    implements YorksAccountsRecordsRepository {
  const YorksSupabaseAccountsRecordsRepository({
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
  Future<YorksAccountsActivityProjection> getActivity(
    String projectId,
    YorksAccountsActivityFilters filters,
  ) async {
    final normalizedProjectId = projectId.trim();
    if (normalizedProjectId.isEmpty || !filters.isValid) return _invalid();
    final response = await _invoke(
      'v1_get_accounts_activity',
      filters.toRpcParameters(normalizedProjectId),
    );
    try {
      final projection = YorksAccountsActivityProjection.fromRpcJson(response);
      if (projection.projectId != normalizedProjectId) {
        throw const FormatException('Accounts activity identity mismatch.');
      }
      return projection;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  @override
  Future<YorksAccountsReportProjection> getReport(
    YorksAccountsReportKind kind, {
    String? projectId,
    required String idempotencyKey,
  }) async {
    final normalizedProjectId = _nullable(projectId);
    final normalizedKey = idempotencyKey.trim();
    if ((kind != YorksAccountsReportKind.portfolio &&
            normalizedProjectId == null) ||
        normalizedKey.isEmpty) {
      return _invalid();
    }
    final response = await _invoke('v1_get_accounts_export', {
      'p_export_kind': kind.wireValue,
      'p_project_id': normalizedProjectId,
      'p_idempotency_key': normalizedKey,
    });
    try {
      final report = YorksAccountsReportProjection.fromRpcJson(response);
      if (report.reportKind != kind.wireValue ||
          report.projectId != normalizedProjectId) {
        throw const FormatException('Accounts report identity mismatch.');
      }
      return report;
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
      final code = switch (error.code) {
        'PGRST301' ||
        'PGRST302' ||
        'PGRST303' ||
        '28000' => YorksV1DomainErrorCode.unauthenticated,
        '42501' => YorksV1DomainErrorCode.unauthorized,
        '22023' || '22P02' => YorksV1DomainErrorCode.invalidInput,
        '40001' || '23505' => YorksV1DomainErrorCode.conflict,
        'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
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

String? _nullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Future<T> _invalid<T>() => Future.error(
  const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput),
);
