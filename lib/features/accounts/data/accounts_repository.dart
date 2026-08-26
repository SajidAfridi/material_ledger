import 'dart:convert';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/yorks_v1_domain_error.dart';
import '../../../shared/models/yorks_v1_feature_flags.dart';
import '../../../shared/sync/connectivity_service.dart';
import '../domain/accounts_inputs.dart';
import '../domain/accounts_models.dart';

abstract interface class YorksAccountsRpcClient {
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  });
}

final class SupabaseYorksAccountsRpcClient implements YorksAccountsRpcClient {
  const SupabaseYorksAccountsRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    final stopwatch = Stopwatch()..start();
    final supportReference = _accountsSupportReference();
    try {
      final response = await _client.rpc(functionName, params: parameters);
      final result = switch (response) {
        final Map value => Map<String, dynamic>.from(value),
        final List value when value.length == 1 && value.single is Map =>
          Map<String, dynamic>.from(value.single as Map),
        _ => throw const YorksV1DomainException(
          YorksV1DomainErrorCode.unexpectedResponse,
        ),
      };
      _logAccountsRpc(
        functionName: functionName,
        outcome: 'success',
        latencyMs: stopwatch.elapsedMilliseconds,
        supportReference: supportReference,
      );
      return result;
    } on PostgrestException catch (error) {
      final mapped = _mapAccountsPostgrest(error, supportReference);
      _logAccountsRpc(
        functionName: functionName,
        outcome: _accountsOutcome(mapped.code),
        latencyMs: stopwatch.elapsedMilliseconds,
        supportReference: supportReference,
        serverCode: error.code,
        level: 900,
      );
      throw mapped;
    } on YorksV1DomainException catch (error) {
      final decorated = YorksV1DomainException(
        error.code,
        serverCode: error.serverCode,
        serverMessage: error.serverMessage,
        supportReference: error.supportReference ?? supportReference,
        cause: error.cause,
      );
      _logAccountsRpc(
        functionName: functionName,
        outcome: _accountsOutcome(decorated.code),
        latencyMs: stopwatch.elapsedMilliseconds,
        supportReference: decorated.supportReference!,
        serverCode: decorated.serverCode,
        level: 900,
      );
      throw decorated;
    } catch (_) {
      _logAccountsRpc(
        functionName: functionName,
        outcome: 'infrastructure_failure',
        latencyMs: stopwatch.elapsedMilliseconds,
        supportReference: supportReference,
        level: 1000,
      );
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        supportReference: supportReference,
      );
    }
  }
}

String _accountsSupportReference() {
  final hex = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final padded = hex.padLeft(12, '0');
  return 'ACC-${padded.substring(padded.length - 12).toUpperCase()}';
}

YorksV1DomainException _mapAccountsPostgrest(
  PostgrestException error,
  String supportReference,
) {
  final message = [
    error.message,
    error.details?.toString(),
    error.hint?.toString(),
  ].whereType<String>().join(' ').toUpperCase();
  final code = error.code;
  final domainCode = switch (code) {
    _
        when message.contains(
              'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
            ) ||
            message.contains('IDEMPOTENCY_PAYLOAD_MISMATCH') =>
      YorksV1DomainErrorCode.conflict,
    'PGRST301' ||
    'PGRST302' ||
    'PGRST303' ||
    '28000' => YorksV1DomainErrorCode.unauthenticated,
    '42501' => YorksV1DomainErrorCode.unauthorized,
    'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
    '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
    '22023' ||
    '22007' ||
    '22P02' ||
    '23514' => YorksV1DomainErrorCode.invalidInput,
    _ when message.contains('R39_ACCOUNTS_ACCESS_DENIED') =>
      YorksV1DomainErrorCode.unauthorized,
    _ when message.contains('R39_ACCOUNTS_STALE_VERSION') =>
      YorksV1DomainErrorCode.conflict,
    _ when message.contains('IDEMPOTENCY_IN_PROGRESS') =>
      YorksV1DomainErrorCode.backendUnavailable,
    _
        when message.contains('BASELINE_ALREADY_INITIALIZED') ||
            message.contains('IMMUTABLE') =>
      YorksV1DomainErrorCode.immutableRecord,
    _ when message.contains('BASELINE_NOT_FOUND') =>
      YorksV1DomainErrorCode.invalidTransition,
    _
        when message.contains('INVALID_') ||
            message.contains('EVIDENCE_REQUIRED') ||
            message.contains('COMMON_SCOPE_FORBIDDEN') =>
      YorksV1DomainErrorCode.invalidInput,
    _ => YorksV1DomainErrorCode.serverRejected,
  };
  return YorksV1DomainException(
    domainCode,
    serverCode: code,
    serverMessage: _safeAccountsServerMessage(message),
    supportReference: supportReference,
    cause: error,
  );
}

String? _safeAccountsServerMessage(String message) => RegExp(
  r'(?:R39|V1)_[A-Z0-9_]+|IDEMPOTENCY_[A-Z0-9_]+|BASELINE_[A-Z0-9_]+',
).firstMatch(message)?.group(0);

String _accountsOutcome(YorksV1DomainErrorCode code) => switch (code) {
  YorksV1DomainErrorCode.conflict => 'conflict',
  YorksV1DomainErrorCode.backendUnavailable => 'infrastructure_failure',
  YorksV1DomainErrorCode.unexpectedResponse => 'invalid_response',
  _ => 'rejected',
};

void _logAccountsRpc({
  required String functionName,
  required String outcome,
  required int latencyMs,
  required String supportReference,
  String? serverCode,
  int level = 800,
}) {
  developer.log(
    jsonEncode({
      'module': 'accounts',
      'operation': functionName,
      'outcome': outcome,
      'latency_ms': latencyMs,
      'support_reference': supportReference,
      'server_code': ?serverCode,
    }),
    name: 'yorks.accounts.rpc',
    level: level,
  );
}

abstract interface class YorksAccountsRepository {
  Future<YorksAccountsBaselineProjection> getBaseline(String projectId);

  Future<YorksAccountsProgressProjection> listProgress(
    String projectId, {
    String? buildingScopeId,
    String? stageKey,
    String? actionOwner,
    bool? hasEvidence,
  });

  Future<YorksAccountsProgressRevisionProjection> listProgressRevisions(
    String projectId,
    String progressEntryId, {
    int? beforeRevisionNumber,
    int limit = 50,
  });

  Future<YorksAccountsCommandResult> initializeBaseline(
    YorksAccountsBaselineInput input, {
    required String idempotencyKey,
  });

  Future<YorksAccountsCommandResult> reviseBaseline(
    YorksAccountsBaselineInput input, {
    required String idempotencyKey,
  });

  Future<YorksAccountsCommandResult> suggestProgress(
    YorksAccountsProgressInput input, {
    required String idempotencyKey,
  });

  Future<YorksAccountsCommandResult> confirmProgress(
    YorksAccountsProgressInput input, {
    required String idempotencyKey,
  });

  Future<YorksAccountsCommandResult> reviewProgress(
    YorksAccountsReviewInput input, {
    required String idempotencyKey,
  });
}

final class YorksSupabaseAccountsRepository implements YorksAccountsRepository {
  const YorksSupabaseAccountsRepository({
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
  Future<YorksAccountsBaselineProjection> getBaseline(String projectId) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return _invalidInput();
    final response = await _invoke(
      functionName: 'v1_get_project_commercial_baseline',
      parameters: {'p_project_id': normalized},
    );
    try {
      final projection = YorksAccountsBaselineProjection.fromRpcJson(response);
      _requireMatchingId(projection.projectId, normalized);
      return projection;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  @override
  Future<YorksAccountsProgressProjection> listProgress(
    String projectId, {
    String? buildingScopeId,
    String? stageKey,
    String? actionOwner,
    bool? hasEvidence,
  }) async {
    final normalized = projectId.trim();
    if (normalized.isEmpty) return _invalidInput();
    final response = await _invoke(
      functionName: 'v1_list_billing_progress',
      parameters: {
        'p_project_id': normalized,
        'p_building_scope_id': _nullableTrimmed(buildingScopeId),
        'p_stage_key': _nullableTrimmed(stageKey),
        'p_action_owner': _nullableTrimmed(actionOwner),
        'p_has_evidence': hasEvidence,
      },
    );
    try {
      final projection = YorksAccountsProgressProjection.fromRpcJson(response);
      _requireMatchingId(projection.projectId, normalized);
      for (final entry in projection.progress) {
        _requireMatchingId(entry.projectId, normalized);
        final baselineRevisionId = projection.baselineRevisionId;
        if (baselineRevisionId == null ||
            entry.baselineRevisionId != baselineRevisionId) {
          throw const FormatException(
            'Accounts progress response has inconsistent baseline identity.',
          );
        }
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
  Future<YorksAccountsProgressRevisionProjection> listProgressRevisions(
    String projectId,
    String progressEntryId, {
    int? beforeRevisionNumber,
    int limit = 50,
  }) async {
    final normalizedProjectId = projectId.trim();
    final normalizedProgressEntryId = progressEntryId.trim();
    if (normalizedProjectId.isEmpty ||
        normalizedProgressEntryId.isEmpty ||
        (beforeRevisionNumber != null && beforeRevisionNumber <= 0) ||
        limit < 1 ||
        limit > 100) {
      return _invalidInput();
    }
    final response = await _invoke(
      functionName: 'v1_list_billing_progress_revisions',
      parameters: {
        'p_project_id': normalizedProjectId,
        'p_progress_entry_id': normalizedProgressEntryId,
        'p_before_revision_number': beforeRevisionNumber,
        'p_limit': limit,
      },
    );
    try {
      final projection = YorksAccountsProgressRevisionProjection.fromRpcJson(
        response,
      );
      _requireMatchingId(projection.projectId, normalizedProjectId);
      _requireMatchingId(projection.progressEntryId, normalizedProgressEntryId);
      return projection;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  @override
  Future<YorksAccountsCommandResult> initializeBaseline(
    YorksAccountsBaselineInput input, {
    required String idempotencyKey,
  }) {
    if (input.isRevision || !input.isValid) return _invalidInput();
    return _command(
      functionName: 'v1_initialize_project_commercial_baseline',
      parameters: _baselineParameters(input, idempotencyKey),
      expectedProjectId: input.projectId,
      requireBaselineEntityIdentity: true,
    );
  }

  @override
  Future<YorksAccountsCommandResult> reviseBaseline(
    YorksAccountsBaselineInput input, {
    required String idempotencyKey,
  }) {
    if (!input.isRevision || !input.isValid) return _invalidInput();
    return _command(
      functionName: 'v1_revise_project_commercial_baseline',
      parameters: _baselineParameters(input, idempotencyKey),
      expectedProjectId: input.projectId,
      requireBaselineEntityIdentity: true,
    );
  }

  @override
  Future<YorksAccountsCommandResult> suggestProgress(
    YorksAccountsProgressInput input, {
    required String idempotencyKey,
  }) {
    if (!input.isValidSuggestion) return _invalidInput();
    return _command(
      functionName: 'v1_suggest_billing_progress',
      parameters: _progressParameters(
        input,
        idempotencyKey,
        percentKey: 'p_suggested_percent',
      ),
      expectedProjectId: input.projectId,
      expectedEntityId: input.progressEntryId,
    );
  }

  @override
  Future<YorksAccountsCommandResult> confirmProgress(
    YorksAccountsProgressInput input, {
    required String idempotencyKey,
  }) {
    if (!input.isValidConfirmation) return _invalidInput();
    return _command(
      functionName: 'v1_confirm_billing_progress',
      parameters: _progressParameters(
        input,
        idempotencyKey,
        percentKey: 'p_confirmed_percent',
      ),
      expectedProjectId: input.projectId,
      expectedEntityId: input.progressEntryId,
    );
  }

  @override
  Future<YorksAccountsCommandResult> reviewProgress(
    YorksAccountsReviewInput input, {
    required String idempotencyKey,
  }) {
    if (!input.isValid) return _invalidInput();
    return _command(
      functionName: 'v1_review_commercial_progress',
      parameters: {
        'p_project_id': input.projectId.trim(),
        'p_progress_entry_id': input.progressEntryId.trim(),
        'p_expected_version': input.expectedVersion,
        'p_decision': input.decision.wireValue,
        'p_reason': input.reason.trim(),
        'p_idempotency_key': idempotencyKey.trim(),
      },
      expectedProjectId: input.projectId,
      expectedEntityId: input.progressEntryId,
    );
  }

  Map<String, Object?> _baselineParameters(
    YorksAccountsBaselineInput input,
    String idempotencyKey,
  ) => {
    'p_project_id': input.projectId.trim(),
    if (input.expectedBaselineVersion != null)
      'p_expected_baseline_version': input.expectedBaselineVersion,
    'p_contract_value': input.contractValue.postgresText,
    'p_currency_code': input.currencyCode.trim().toUpperCase(),
    'p_vat_rate': input.vatRate.postgresText,
    'p_payment_terms_days': input.paymentTermsDays,
    'p_reminder_lead_days': input.reminderLeadDays,
    'p_building_allocations': input.buildingAllocations
        .map((item) => item.toRpcJson())
        .toList(growable: false),
    'p_stage_allocations': input.stageAllocations
        .map((item) => item.toRpcJson())
        .toList(growable: false),
    'p_management_review_policy': input.managementReviewPolicy.toRpcJson(),
    'p_reason': input.reason.trim(),
    'p_idempotency_key': idempotencyKey.trim(),
  };

  Map<String, Object?> _progressParameters(
    YorksAccountsProgressInput input,
    String idempotencyKey, {
    required String percentKey,
  }) => {
    'p_project_id': input.projectId.trim(),
    'p_progress_entry_id': input.progressEntryId.trim(),
    'p_expected_version': input.expectedVersion,
    percentKey: input.percent.postgresText,
    'p_evidence_summary': input.evidenceSummary.trim(),
    'p_evidence_document_ids': input.evidenceDocumentIds
        .map((id) => id.trim())
        .toList(growable: false),
    'p_reason': input.reason.trim(),
    'p_idempotency_key': idempotencyKey.trim(),
  };

  Future<YorksAccountsCommandResult> _command({
    required String functionName,
    required Map<String, Object?> parameters,
    required String expectedProjectId,
    String? expectedEntityId,
    bool requireBaselineEntityIdentity = false,
  }) async {
    final response = await _invoke(
      functionName: functionName,
      parameters: parameters,
    );
    try {
      final result = YorksAccountsCommandResult.fromRpcJson(response);
      _requireMatchingId(result.projectId, expectedProjectId.trim());
      if (expectedEntityId case final expected?) {
        _requireMatchingId(result.entityId, expected.trim());
      }
      if (requireBaselineEntityIdentity) {
        final baselineRevisionId = response['baseline_revision_id'];
        if (baselineRevisionId is! String ||
            baselineRevisionId.trim() != result.entityId) {
          throw const FormatException(
            'Accounts baseline command response has inconsistent identity.',
          );
        }
      }
      return result;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  Future<Map<String, dynamic>> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    final rpc = _readyRpc();
    try {
      return await rpc.invoke(
        functionName: functionName,
        parameters: parameters,
      );
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

  YorksAccountsRpcClient _readyRpc() {
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
    return rpc;
  }

  YorksV1DomainException _mapPostgrestException(PostgrestException error) {
    final message = [
      error.message,
      error.details?.toString(),
      error.hint?.toString(),
    ].whereType<String>().join(' ').toUpperCase();
    final code = error.code;
    final domainCode = switch (code) {
      _
          when message.contains(
                'V1_IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD',
              ) ||
              message.contains('IDEMPOTENCY_PAYLOAD_MISMATCH') =>
        YorksV1DomainErrorCode.conflict,
      'PGRST301' ||
      'PGRST302' ||
      'PGRST303' ||
      '28000' => YorksV1DomainErrorCode.unauthenticated,
      '42501' => YorksV1DomainErrorCode.unauthorized,
      'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
      '40001' || '23505' => YorksV1DomainErrorCode.conflict,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      _ when message.contains('R39_ACCOUNTS_ACCESS_DENIED') =>
        YorksV1DomainErrorCode.unauthorized,
      _
          when message.contains('R39_ACCOUNTS_STALE_VERSION') ||
              message.contains('IDEMPOTENCY_PAYLOAD_MISMATCH') =>
        YorksV1DomainErrorCode.conflict,
      _ when message.contains('IDEMPOTENCY_IN_PROGRESS') =>
        YorksV1DomainErrorCode.backendUnavailable,
      _
          when message.contains('BASELINE_ALREADY_INITIALIZED') ||
              message.contains('IMMUTABLE') =>
        YorksV1DomainErrorCode.immutableRecord,
      _ when message.contains('BASELINE_NOT_FOUND') =>
        YorksV1DomainErrorCode.invalidTransition,
      _
          when message.contains('INVALID_') ||
              message.contains('EVIDENCE_REQUIRED') ||
              message.contains('COMMON_SCOPE_FORBIDDEN') =>
        YorksV1DomainErrorCode.invalidInput,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(
      domainCode,
      serverCode: code,
      serverMessage: error.message,
      cause: error,
    );
  }
}

void _requireMatchingId(String actual, String expected) {
  if (expected.isEmpty || actual != expected) {
    throw const FormatException('Accounts response identity mismatch.');
  }
}

String? _nullableTrimmed(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Future<T> _invalidInput<T>() => Future.error(
  const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput),
);
