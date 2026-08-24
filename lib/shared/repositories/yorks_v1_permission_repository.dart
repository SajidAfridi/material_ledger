import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_permission_management.dart';
import '../sync/connectivity_service.dart';

abstract interface class YorksV1PermissionRpcClient {
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  });
}

class SupabaseYorksV1PermissionRpcClient implements YorksV1PermissionRpcClient {
  const SupabaseYorksV1PermissionRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

class YorksV1SetPermissionAssignmentInput {
  const YorksV1SetPermissionAssignmentInput({
    required this.targetAppUserId,
    required this.capabilityKey,
    required this.effect,
    required this.scope,
    required this.reason,
    required this.expectedRevision,
    required this.idempotencyKey,
    this.effectiveFrom,
    this.effectiveUntil,
  });

  final String targetAppUserId;
  final String capabilityKey;
  final YorksV1PermissionAssignmentEffect effect;
  final YorksV1PermissionScope scope;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final String reason;
  final int expectedRevision;
  final String idempotencyKey;
}

class YorksV1ClearPermissionAssignmentInput {
  const YorksV1ClearPermissionAssignmentInput({
    required this.targetAppUserId,
    required this.assignmentId,
    required this.reason,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String targetAppUserId;
  final String assignmentId;
  final String reason;
  final int expectedRevision;
  final String idempotencyKey;
}

class YorksV1ApplyPermissionChangesInput {
  const YorksV1ApplyPermissionChangesInput({
    required this.targetAppUserId,
    required this.changes,
    required this.reason,
    required this.expectedRevision,
    required this.idempotencyKey,
  });

  final String targetAppUserId;
  final List<YorksV1PermissionChange> changes;
  final String reason;
  final int expectedRevision;
  final String idempotencyKey;
}

class YorksV1PermissionHistoryQuery {
  const YorksV1PermissionHistoryQuery({
    required this.targetAppUserId,
    this.limit = 50,
    this.beforeOccurredAt,
    this.beforeId,
  });

  final String targetAppUserId;
  final int limit;
  final DateTime? beforeOccurredAt;
  final String? beforeId;
}

abstract interface class YorksV1PermissionRepository {
  Future<YorksV1CurrentPermissionSnapshot> getCurrentSnapshot();

  Future<YorksV1UserAdminOptions> getUserAdminOptions({
    String? targetAppUserId,
  });

  Future<YorksV1UserPermissionWorkspace> getUserWorkspace({
    required String targetAppUserId,
  });

  Future<YorksV1UserPermissionWorkspace> setAssignment(
    YorksV1SetPermissionAssignmentInput input,
  );

  Future<YorksV1UserPermissionWorkspace> clearAssignment(
    YorksV1ClearPermissionAssignmentInput input,
  );

  Future<YorksV1UserPermissionWorkspace> applyChanges(
    YorksV1ApplyPermissionChangesInput input,
  );

  Future<YorksV1PermissionHistoryPage> listHistory(
    YorksV1PermissionHistoryQuery query,
  );
}

class YorksV1SupabasePermissionRepository
    implements YorksV1PermissionRepository {
  const YorksV1SupabasePermissionRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1PermissionRpcClient? rpcClient,
    Duration rpcTimeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _rpcTimeout = rpcTimeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1PermissionRpcClient? _rpcClient;
  final Duration _rpcTimeout;

  @override
  Future<YorksV1CurrentPermissionSnapshot> getCurrentSnapshot() async {
    final response = await _invoke(
      functionName: 'v1_get_current_permission_snapshot',
      parameters: const {},
    );
    return _decode(response, YorksV1CurrentPermissionSnapshot.fromRpcJson);
  }

  @override
  Future<YorksV1UserAdminOptions> getUserAdminOptions({
    String? targetAppUserId,
  }) async {
    final normalizedTarget = targetAppUserId == null
        ? null
        : _requiredText(targetAppUserId);
    final response = await _invoke(
      functionName: 'v1_get_user_admin_options',
      parameters: {'p_target_app_user_id': normalizedTarget},
    );
    final options = _decode(response, YorksV1UserAdminOptions.fromRpcJson);
    if (options.targetAppUserId != normalizedTarget) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return options;
  }

  @override
  Future<YorksV1UserPermissionWorkspace> getUserWorkspace({
    required String targetAppUserId,
  }) async {
    final target = _requiredText(targetAppUserId);
    final response = await _invoke(
      functionName: 'v1_get_user_permission_workspace',
      parameters: {'p_target_app_user_id': target},
    );
    return _decodeWorkspaceForTarget(response, target);
  }

  @override
  Future<YorksV1UserPermissionWorkspace> setAssignment(
    YorksV1SetPermissionAssignmentInput input,
  ) async {
    final target = _requiredText(input.targetAppUserId);
    final capability = _capabilityKey(input.capabilityKey);
    if (!YorksV1CapabilityKeys.all.contains(capability)) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final reason = _reason(input.reason);
    _expectedRevision(input.expectedRevision);
    _uuid(input.idempotencyKey);
    if (!input.effect.isExplicit) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    for (final projectId in input.scope.projectIds) {
      _uuid(projectId);
    }
    final effectiveFrom = input.effectiveFrom?.toUtc();
    final effectiveUntil = input.effectiveUntil?.toUtc();
    if (effectiveFrom != null &&
        effectiveUntil != null &&
        !effectiveUntil.isAfter(effectiveFrom)) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final response = await _invoke(
      functionName: 'v1_set_user_permission_assignment',
      parameters: {
        'p_target_app_user_id': target,
        'p_capability_key': capability,
        'p_effect': input.effect.wireValue,
        'p_scope_kind': input.scope.kind.wireValue,
        'p_project_ids': input.scope.projectIds,
        'p_effective_from': effectiveFrom?.toIso8601String(),
        'p_effective_until': effectiveUntil?.toIso8601String(),
        'p_reason': reason,
        'p_expected_revision': input.expectedRevision,
        'p_idempotency_key': input.idempotencyKey.trim(),
      },
    );
    return _decodeWorkspaceForTarget(response, target);
  }

  @override
  Future<YorksV1UserPermissionWorkspace> clearAssignment(
    YorksV1ClearPermissionAssignmentInput input,
  ) async {
    final target = _requiredText(input.targetAppUserId);
    _uuid(input.assignmentId);
    _uuid(input.idempotencyKey);
    final reason = _reason(input.reason);
    _expectedRevision(input.expectedRevision);
    final response = await _invoke(
      functionName: 'v1_clear_user_permission_assignment',
      parameters: {
        'p_target_app_user_id': target,
        'p_assignment_id': input.assignmentId.trim(),
        'p_reason': reason,
        'p_expected_revision': input.expectedRevision,
        'p_idempotency_key': input.idempotencyKey.trim(),
      },
    );
    return _decodeWorkspaceForTarget(response, target);
  }

  @override
  Future<YorksV1UserPermissionWorkspace> applyChanges(
    YorksV1ApplyPermissionChangesInput input,
  ) async {
    final target = _requiredText(input.targetAppUserId);
    final reason = _reason(input.reason);
    _expectedRevision(input.expectedRevision);
    _uuid(input.idempotencyKey);
    if (input.changes.isEmpty || input.changes.length > 200) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final identities = <String>{};
    for (final change in input.changes) {
      if (!identities.add(change.identity)) {
        throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
      }
      switch (change.operation) {
        case YorksV1PermissionChangeOperation.set:
          final capability = _capabilityKey(change.capabilityKey!);
          if (!YorksV1CapabilityKeys.all.contains(capability)) {
            throw const YorksV1DomainException(
              YorksV1DomainErrorCode.invalidInput,
            );
          }
          for (final projectId in change.scope!.projectIds) {
            _uuid(projectId);
          }
          break;
        case YorksV1PermissionChangeOperation.clear:
          _uuid(change.assignmentId!);
          break;
      }
    }
    final response = await _invoke(
      functionName: 'v1_apply_user_permission_changes',
      parameters: {
        'p_target_app_user_id': target,
        'p_changes': input.changes
            .map((change) => change.toRpcJson())
            .toList(growable: false),
        'p_reason': reason,
        'p_expected_revision': input.expectedRevision,
        'p_idempotency_key': input.idempotencyKey.trim(),
      },
    );
    return _decodeWorkspaceForTarget(response, target);
  }

  @override
  Future<YorksV1PermissionHistoryPage> listHistory(
    YorksV1PermissionHistoryQuery query,
  ) async {
    final target = _requiredText(query.targetAppUserId);
    if (query.limit < 1 || query.limit > 200) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    if ((query.beforeOccurredAt == null) != (query.beforeId == null)) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    if (query.beforeId != null) _uuid(query.beforeId!);
    final response = await _invoke(
      functionName: 'v1_list_user_permission_history',
      parameters: {
        'p_target_app_user_id': target,
        'p_limit': query.limit,
        'p_before_occurred_at': query.beforeOccurredAt
            ?.toUtc()
            .toIso8601String(),
        'p_before_id': query.beforeId?.trim(),
      },
    );
    final page = _decode(response, YorksV1PermissionHistoryPage.fromRpcJson);
    if (page.targetAppUserId != target) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return page;
  }

  YorksV1UserPermissionWorkspace _decodeWorkspaceForTarget(
    Object? response,
    String targetAppUserId,
  ) {
    final workspace = _decode(
      response,
      YorksV1UserPermissionWorkspace.fromRpcJson,
    );
    if (workspace.target.appUserId != targetAppUserId) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return workspace;
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
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
      return await rpc
          .invoke(functionName: functionName, parameters: parameters)
          .timeout(_rpcTimeout);
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

  T _decode<T>(Object? response, T Function(Map<String, dynamic>) decode) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    try {
      return decode(Map<String, dynamic>.from(response));
    } on YorksV1DomainException {
      rethrow;
    } on FormatException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
        cause: error,
      );
    }
  }

  static YorksV1DomainException _mapPostgrest(PostgrestException error) {
    final code = switch (error.code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '40001' || '55P03' || '23505' => YorksV1DomainErrorCode.conflict,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23503' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      'PGRST002' ||
      'PGRST003' ||
      'PGRST202' => YorksV1DomainErrorCode.backendUnavailable,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(
      code,
      serverCode: error.code,
      serverMessage: error.message,
      cause: error,
    );
  }

  static String _requiredText(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return normalized;
  }

  static String _capabilityKey(String value) {
    final normalized = _requiredText(value);
    if (!RegExp(
      r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$',
    ).hasMatch(normalized)) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return normalized;
  }

  static String _reason(String value) {
    final normalized = _requiredText(value);
    if (normalized.length > 2000) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    return normalized;
  }

  static void _expectedRevision(int value) {
    if (value < 0) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
  }

  static void _uuid(String value) {
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim())) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
  }
}
