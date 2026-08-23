import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_boq.dart';
import '../models/yorks_v1_boq_workbook.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../sync/connectivity_service.dart';

/// Raw RPC seam for the normalized BOQ domain.  Keeping this small and
/// overrideable lets widget/controller tests prove the UI never reaches
/// Supabase directly.
abstract interface class YorksV1BoqRpcClient {
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  });
}

class SupabaseYorksV1BoqRpcClient implements YorksV1BoqRpcClient {
  const SupabaseYorksV1BoqRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

abstract interface class YorksV1BoqRepository {
  Future<List<YorksV1BoqGroup>> listGroups(String projectId);

  /// A non-null scope returns only that scope's worksheets. A null scope is
  /// the read-only All aggregate and may include legacy/unassigned groups.
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  });

  Future<YorksV1BoqWorksheet> getWorksheet(String groupId);

  Future<YorksV1BoqWorksheet> saveWorksheet(YorksV1SaveBoqWorksheetInput input);

  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  );

  Future<YorksV1BoqGroup> createCustomGroup(YorksV1CreateBoqGroupInput input);

  Future<YorksV1BoqGroup> assignLegacyGroupScope(
    YorksV1AssignLegacyBoqGroupScopeInput input,
  );

  Future<void> archiveGroup({
    required String groupId,
    required int expectedVersion,
    required String idempotencyKey,
  });
}

/// Server-backed BOQ repository.  A worksheet save is one version-checked
/// transaction and never falls back to the legacy Material Plan store.
class YorksV1SupabaseBoqRepository implements YorksV1BoqRepository {
  const YorksV1SupabaseBoqRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1BoqRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1BoqRpcClient? _rpcClient;

  @override
  Future<List<YorksV1BoqGroup>> listGroups(String projectId) async {
    final response = await _invoke(
      functionName: 'v1_list_boq_groups',
      parameters: {'p_project_id': projectId},
      requiresOnline: false,
    );
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return [
      for (final item in response)
        if (item is Map)
          YorksV1BoqGroup.fromRpcJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<List<YorksV1BoqGroup>> listGroupsForScope(
    String projectId, {
    String? scopeId,
  }) async {
    final response = await _invoke(
      functionName: 'v1_list_boq_groups_for_scope',
      parameters: {'p_project_id': projectId, 'p_scope_id': scopeId},
      requiresOnline: false,
    );
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return [
      for (final item in response)
        if (item is Map)
          YorksV1BoqGroup.fromRpcJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<YorksV1BoqWorksheet> getWorksheet(String groupId) async {
    final response = await _invoke(
      functionName: 'v1_get_boq_worksheet',
      parameters: {'p_group_id': groupId},
      requiresOnline: false,
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1BoqWorksheet.fromRpcJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<YorksV1BoqWorksheet> saveWorksheet(
    YorksV1SaveBoqWorksheetInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_save_boq_worksheet',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1BoqWorksheet.fromRpcJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<YorksV1BoqWorksheet> importWorksheet(
    YorksV1ImportBoqWorksheetInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_import_boq_worksheet',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresExcel: true,
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1BoqWorksheet.fromRpcJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<YorksV1BoqGroup> createCustomGroup(
    YorksV1CreateBoqGroupInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_create_boq_group',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1BoqGroup.fromRpcJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<YorksV1BoqGroup> assignLegacyGroupScope(
    YorksV1AssignLegacyBoqGroupScopeInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_assign_legacy_boq_group_scope',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1BoqGroup.fromRpcJson(Map<String, dynamic>.from(response));
  }

  @override
  Future<void> archiveGroup({
    required String groupId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    await _invoke(
      functionName: 'v1_archive_boq_group',
      parameters: {
        'p_payload': {'group_id': groupId, 'expected_version': expectedVersion},
        'p_idempotency_key': idempotencyKey,
      },
    );
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
    bool requiresOnline = true,
    bool requiresExcel = false,
  }) async {
    if (!_featureFlags.boq) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (requiresExcel && !_featureFlags.excel) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (requiresOnline && !_connectivity.isOnline) {
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
      throw _mapPostgrestException(error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  YorksV1DomainException _mapPostgrestException(PostgrestException error) {
    final message = error.message.toUpperCase();
    final domainCode = switch (error.code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '40001' => YorksV1DomainErrorCode.conflict,
      '23505' => YorksV1DomainErrorCode.invalidInput,
      'P0001'
          when message.contains('VERSION') ||
              message.contains('CONFLICT') ||
              message.contains('IDEMPOTENCY') =>
        YorksV1DomainErrorCode.conflict,
      'P0001'
          when message.contains('NOT_READABLE') ||
              message.contains('NOT_AUTHORIZED') ||
              message.contains('PERMISSION') =>
        YorksV1DomainErrorCode.unauthorized,
      'P0001'
          when message.contains('INVALID') ||
              message.contains('DUPLICATE') ||
              message.contains('REQUIRED') =>
        YorksV1DomainErrorCode.invalidInput,
      'P0001' => YorksV1DomainErrorCode.serverRejected,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(
      domainCode,
      serverCode: error.code,
      serverMessage: error.message,
      cause: error,
    );
  }
}
