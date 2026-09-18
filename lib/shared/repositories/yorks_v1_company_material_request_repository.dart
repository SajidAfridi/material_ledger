import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_company_material_request.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

abstract interface class YorksV1CompanyMaterialRequestRepository {
  Future<List<YorksV1CompanyMaterialRequestDraftOption>> listDraftOptions();
  Future<YorksV1CompanyMaterialRequestApprovalPreflight> preflightApproval({
    required String categoryId,
    required String responsibleUnitId,
    required String beneficiaryAuthUserId,
    required String authorizedReceiverAuthUserId,
  });
  Future<YorksV1CompanyMaterialRequest> saveDraft(
    YorksV1CompanyMaterialRequestDraft draft,
  );
  Future<YorksV1CompanyMaterialRequest> submit({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  });
  Future<YorksV1CompanyMaterialRequest> saveAndSubmit(
    YorksV1CompanyMaterialRequestDraft draft,
  );
}

class YorksV1SupabaseCompanyMaterialRequestRepository
    implements YorksV1CompanyMaterialRequestRepository {
  const YorksV1SupabaseCompanyMaterialRequestRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
    Duration timeout = const Duration(seconds: 20),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _timeout = timeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;
  final Duration _timeout;

  @override
  Future<List<YorksV1CompanyMaterialRequestDraftOption>>
  listDraftOptions() async {
    final response = await _invoke(
      'v1_list_company_material_request_draft_options',
      const {},
    );
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return [
      for (final item in response)
        if (item is Map)
          YorksV1CompanyMaterialRequestDraftOption.fromRpcJson(
            Map<String, dynamic>.from(item),
          ),
    ];
  }

  @override
  Future<YorksV1CompanyMaterialRequestApprovalPreflight> preflightApproval({
    required String categoryId,
    required String responsibleUnitId,
    required String beneficiaryAuthUserId,
    required String authorizedReceiverAuthUserId,
  }) async {
    final response =
        await _invoke('v1_company_material_request_approval_preflight', {
          'p_category_id': categoryId,
          'p_responsible_unit_id': responsibleUnitId,
          'p_beneficiary_auth_user_id': beneficiaryAuthUserId,
          'p_authorized_receiver_auth_user_id': authorizedReceiverAuthUserId,
        });
    return YorksV1CompanyMaterialRequestApprovalPreflight.fromRpcJson(
      _map(response),
    );
  }

  @override
  Future<YorksV1CompanyMaterialRequest> saveDraft(
    YorksV1CompanyMaterialRequestDraft draft,
  ) async => _requestFromResponse(
    await _invoke('v1_save_company_material_request_draft', {
      'p_payload': draft.toSavePayload(),
    }),
  );

  @override
  Future<YorksV1CompanyMaterialRequest> submit({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => _requestFromResponse(
    await _invoke('v1_submit_company_material_request', {
      'p_payload': {
        'request_id': requestId,
        'expected_version': expectedVersion,
      },
      'p_idempotency_key': idempotencyKey,
    }),
  );

  @override
  Future<YorksV1CompanyMaterialRequest> saveAndSubmit(
    YorksV1CompanyMaterialRequestDraft draft,
  ) async => _requestFromResponse(
    await _invoke('v1_save_and_submit_company_material_request', {
      'p_payload': draft.toSavePayload(),
      'p_idempotency_key': draft.submissionIdempotencyKey,
    }),
  );

  Future<Object?> _invoke(
    String functionName,
    Map<String, Object?> parameters,
  ) async {
    if (!_featureFlags.companyMaterialRequests) {
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
          .timeout(_timeout);
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      throw YorksV1DomainException(
        switch (error.code) {
          '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
          '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
          '22023' ||
          '22007' ||
          '22P02' ||
          '23514' => YorksV1DomainErrorCode.invalidInput,
          _ => YorksV1DomainErrorCode.serverRejected,
        },
        serverCode: error.code,
        cause: error,
      );
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

  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return Map<String, dynamic>.from(value);
  }

  static YorksV1CompanyMaterialRequest _requestFromResponse(Object? value) =>
      YorksV1CompanyMaterialRequest.fromRpcJson(_map(value));
}
