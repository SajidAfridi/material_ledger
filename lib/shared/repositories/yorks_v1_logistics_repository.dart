import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_logistics.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

/// Typed Batch 7 server boundary. Widgets can neither access a Supabase client
/// nor mutate local stock/request state; every committed effect is an RPC.
abstract interface class YorksV1LogisticsRepository {
  Future<YorksV1InventoryWorkspace> getInventory({String? search});

  Future<YorksV1InventoryItemDetail> getInventoryItem(String inventoryItemId);

  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  );

  Future<YorksV1LogisticsInventoryItem> setInventoryItemActive(
    YorksV1InventoryItemStateInput input,
  );

  Future<YorksV1LogisticsWorkspace> getWorkspace(String requestId);

  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input);

  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> getReturnsDocumentsWorkspace(
    String requestId,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> saveMaterialReturnDraft(
    YorksV1MaterialReturnDraftInput input,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> submitMaterialReturn(
    YorksV1MaterialReturnSubmissionInput input,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> confirmMaterialReturn(
    YorksV1MaterialReturnConfirmationInput input,
  );

  Future<YorksV1ReturnsDocumentsWorkspace> rejectMaterialReturn(
    YorksV1MaterialReturnRejectionInput input,
  );
}

class YorksV1SupabaseLogisticsRepository implements YorksV1LogisticsRepository {
  const YorksV1SupabaseLogisticsRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;

  @override
  Future<YorksV1InventoryWorkspace> getInventory({String? search}) async {
    final response = await _invoke(
      functionName: 'v1_inventory_workspace_projection',
      parameters: {'p_search': search?.trim().isEmpty ?? true ? null : search},
    );
    return _inventoryWorkspace(response);
  }

  @override
  Future<YorksV1InventoryItemDetail> getInventoryItem(
    String inventoryItemId,
  ) async {
    final response = await _invoke(
      functionName: 'v1_inventory_item_workspace_projection',
      parameters: {'p_inventory_item_id': inventoryItemId},
    );
    return _inventoryItemDetail(response);
  }

  @override
  Future<YorksV1LogisticsInventoryItem> adjustInventory(
    YorksV1InventoryAdjustmentInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_adjust_inventory',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _inventoryItem(response);
  }

  @override
  Future<YorksV1LogisticsInventoryItem> setInventoryItemActive(
    YorksV1InventoryItemStateInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_set_inventory_item_active',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _inventoryItem(response);
  }

  @override
  Future<YorksV1LogisticsWorkspace> getWorkspace(String requestId) async {
    final response = await _invoke(
      functionName: 'v1_logistics_workspace_projection',
      parameters: {'p_request_id': requestId},
    );
    return _workspace(response);
  }

  @override
  Future<YorksV1LogisticsWorkspace> dispatch(YorksV1DispatchInput input) async {
    final response = await _invoke(
      functionName: 'v1_dispatch_materials',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _workspace(response);
  }

  @override
  Future<YorksV1LogisticsWorkspace> confirmReceipt(
    YorksV1ReceiptConfirmationInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_confirm_receipt',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
    return _workspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> getReturnsDocumentsWorkspace(
    String requestId,
  ) async {
    final response = await _invoke(
      functionName: 'v1_returns_documents_workspace_projection',
      parameters: {'p_request_id': requestId},
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> generateDeliveryOrder(
    YorksV1DeliveryOrderGenerationInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_generate_delivery_order',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> saveMaterialReturnDraft(
    YorksV1MaterialReturnDraftInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_save_material_return_draft',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> submitMaterialReturn(
    YorksV1MaterialReturnSubmissionInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_submit_material_return',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> confirmMaterialReturn(
    YorksV1MaterialReturnConfirmationInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_confirm_material_return',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  @override
  Future<YorksV1ReturnsDocumentsWorkspace> rejectMaterialReturn(
    YorksV1MaterialReturnRejectionInput input,
  ) async {
    final response = await _invoke(
      functionName: 'v1_reject_material_return',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
      requiresReturnsDocuments: true,
    );
    return _returnsDocumentsWorkspace(response);
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
    bool requiresReturnsDocuments = false,
  }) async {
    if (!_featureFlags.logistics ||
        (requiresReturnsDocuments && !_featureFlags.returnsDocuments)) {
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
      throw _mapPostgrestException(error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  static YorksV1InventoryWorkspace _inventoryWorkspace(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1InventoryWorkspace.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1InventoryItemDetail _inventoryItemDetail(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1InventoryItemDetail.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1LogisticsInventoryItem _inventoryItem(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1LogisticsInventoryItem.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1LogisticsWorkspace _workspace(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1LogisticsWorkspace.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1ReturnsDocumentsWorkspace _returnsDocumentsWorkspace(
    Object? response,
  ) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return YorksV1ReturnsDocumentsWorkspace.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1DomainException _mapPostgrestException(
    PostgrestException error,
  ) {
    final code = switch (error.code) {
      '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
      '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
      '22023' ||
      '22007' ||
      '22P02' ||
      '23514' => YorksV1DomainErrorCode.invalidInput,
      _ => YorksV1DomainErrorCode.serverRejected,
    };
    return YorksV1DomainException(code, serverCode: error.code, cause: error);
  }
}
