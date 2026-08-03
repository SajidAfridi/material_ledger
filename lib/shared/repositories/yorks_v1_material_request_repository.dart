import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_material_request.dart';
import '../models/yorks_v1_material_request_document.dart';
import '../sync/connectivity_service.dart';

/// Narrow RPC boundary for V1 requests. It prevents widgets and local draft
/// storage from ever constructing a direct database mutation.
abstract interface class YorksV1MaterialRequestRpcClient {
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  });
}

class SupabaseYorksV1MaterialRequestRpcClient
    implements YorksV1MaterialRequestRpcClient {
  const SupabaseYorksV1MaterialRequestRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) => _client.rpc(functionName, params: parameters);
}

abstract interface class YorksV1MaterialRequestRepository {
  Future<List<YorksV1MaterialRequestProjectOption>> listDraftProjects();

  Future<List<YorksV1MaterialRequestScopeOption>> listScopes(String projectId);

  Future<List<YorksV1MaterialRequest>> listRequests({String? projectId});

  Future<YorksV1MaterialRequest> getRequest(String requestId);

  Future<YorksV1MaterialRequestDocumentModel> getDocumentModel(
    String requestId,
  );

  Future<YorksV1MaterialRequest> saveDraft(
    YorksV1SaveMaterialRequestDraftInput input,
  );

  Future<void> deleteDraft(String requestId);

  Future<YorksV1MaterialRequest> submit(
    YorksV1SubmitMaterialRequestInput input,
  );

  Future<YorksV1MaterialRequest> cancel(
    YorksV1CancelMaterialRequestInput input,
  );
}

/// Server-backed normalized MR repository. The only local persistence lives in
/// a creator-owned recoverable draft controller; submitted state never falls
/// back to the legacy collection/outbox authority.
class YorksV1SupabaseMaterialRequestRepository
    implements YorksV1MaterialRequestRepository {
  const YorksV1SupabaseMaterialRequestRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
    Duration rpcTimeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _rpcTimeout = rpcTimeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;
  final Duration _rpcTimeout;

  @override
  Future<List<YorksV1MaterialRequestProjectOption>> listDraftProjects() async {
    final response = await _invoke(
      functionName: 'v1_list_material_request_projects',
      parameters: const {},
    );
    return _list(response)
        .map((item) {
          return YorksV1MaterialRequestProjectOption.fromRpcJson(item);
        })
        .toList(growable: false);
  }

  @override
  Future<List<YorksV1MaterialRequestScopeOption>> listScopes(
    String projectId,
  ) async {
    final response = await _invoke(
      functionName: 'v1_list_material_request_scopes',
      parameters: {'p_project_id': projectId},
    );
    return _list(response)
        .map((item) {
          return YorksV1MaterialRequestScopeOption.fromRpcJson(item);
        })
        .toList(growable: false);
  }

  @override
  Future<List<YorksV1MaterialRequest>> listRequests({String? projectId}) async {
    final response = await _invoke(
      functionName: 'v1_list_material_requests',
      parameters: {'p_project_id': projectId},
    );
    return _list(
      response,
    ).map(YorksV1MaterialRequest.fromRpcJson).toList(growable: false);
  }

  @override
  Future<YorksV1MaterialRequest> getRequest(String requestId) async {
    final response = await _invoke(
      functionName: 'v1_material_request_projection',
      parameters: {'p_request_id': requestId},
    );
    return _single(response);
  }

  @override
  Future<YorksV1MaterialRequestDocumentModel> getDocumentModel(
    String requestId,
  ) async {
    final response = await _invoke(
      functionName: 'v1_material_request_document_projection',
      parameters: {'p_request_id': requestId},
    );
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1MaterialRequestDocumentModel.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  @override
  Future<YorksV1MaterialRequest> saveDraft(
    YorksV1SaveMaterialRequestDraftInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_save_material_request_draft',
      parameters: {'p_payload': input.toRpcPayload()},
    );
    return _single(response);
  }

  @override
  Future<void> deleteDraft(String requestId) async {
    await _invoke(
      functionName: 'v1_delete_material_request_draft',
      parameters: {'p_request_id': requestId},
    );
  }

  @override
  Future<YorksV1MaterialRequest> submit(
    YorksV1SubmitMaterialRequestInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_submit_material_request',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _single(response);
  }

  @override
  Future<YorksV1MaterialRequest> cancel(
    YorksV1CancelMaterialRequestInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_cancel_material_request',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _single(response);
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
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
      return await rpc
          .invoke(functionName: functionName, parameters: parameters)
          .timeout(_rpcTimeout);
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      throw _mapPostgrestException(error);
    } on TimeoutException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  static List<Map<String, dynamic>> _list(Object? response) {
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return [
      for (final item in response)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static YorksV1MaterialRequest _single(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1MaterialRequest.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1DomainException _mapPostgrestException(
    PostgrestException error,
  ) {
    final code = switch (error.code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
      'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(code, serverCode: error.code, cause: error);
  }
}
