import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../models/yorks_v1_inventory_supplier.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

/// Procurement/Admin-only supplier provenance boundary. Widgets never access
/// supplier tables or Storage paths directly.
abstract interface class YorksV1InventorySupplierRepository {
  Future<YorksV1InventorySupplierDirectoryWorkspace> getDirectory({
    String? search,
    YorksV1InventorySupplierStatus? status,
    int limit = 30,
    int offset = 0,
  });

  Future<YorksV1InventorySupplierFolderWorkspace> getFolder({
    required String supplierId,
    required YorksV1InventorySupplierFolderSection section,
    int limit = 50,
    int offset = 0,
  });

  Future<YorksV1InventorySupplierItemTrailWorkspace> getItemTrail({
    required String supplierId,
    required String inventoryItemId,
    YorksV1InventorySupplierItemTrailSection section =
        YorksV1InventorySupplierItemTrailSection.receiptLines,
    int limit = 50,
    int offset = 0,
  });

  Future<YorksV1InventorySupplierReceiptBatchDetailWorkspace>
  getReceiptBatchDetail({
    required String supplierId,
    required String receiptBatchId,
    YorksV1InventorySupplierReceiptBatchDetailSection section =
        YorksV1InventorySupplierReceiptBatchDetailSection.lines,
    int limit = 50,
    int offset = 0,
  });

  Future<YorksV1InventorySupplierDirectoryEntry> createSupplier(
    YorksV1InventorySupplierCreateInput input,
  );

  Future<YorksV1InventorySupplierImportResult> importInventory(
    YorksV1InventorySupplierImportInput input,
  );

  Future<YorksV1InventorySupplierImportResult> importPrepared({
    required Map<String, Object?> payload,
    required String idempotencyKey,
  });
}

class YorksV1SupabaseInventorySupplierRepository
    implements YorksV1InventorySupplierRepository {
  const YorksV1SupabaseInventorySupplierRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
    Duration timeout = const Duration(seconds: 30),
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _timeout = timeout;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;
  final Duration _timeout;

  @override
  Future<YorksV1InventorySupplierDirectoryWorkspace> getDirectory({
    String? search,
    YorksV1InventorySupplierStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_supplier_directory_projection',
        parameters: {
          'p_search': _trimToNull(search),
          'p_status': status?.wireValue,
          'p_limit': limit.clamp(1, 100),
          'p_offset': offset < 0 ? 0 : offset,
        },
      ),
    );
    return YorksV1InventorySupplierDirectoryWorkspace.fromJson(response);
  }

  @override
  Future<YorksV1InventorySupplierFolderWorkspace> getFolder({
    required String supplierId,
    required YorksV1InventorySupplierFolderSection section,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_supplier_folder_projection',
        parameters: {
          'p_supplier_id': supplierId,
          'p_section': section.wireValue,
          'p_limit': limit.clamp(1, 100),
          'p_offset': offset < 0 ? 0 : offset,
        },
      ),
    );
    return YorksV1InventorySupplierFolderWorkspace.fromJson(response);
  }

  @override
  Future<YorksV1InventorySupplierItemTrailWorkspace> getItemTrail({
    required String supplierId,
    required String inventoryItemId,
    YorksV1InventorySupplierItemTrailSection section =
        YorksV1InventorySupplierItemTrailSection.receiptLines,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_supplier_item_trail_projection',
        parameters: {
          'p_supplier_id': supplierId,
          'p_inventory_item_id': inventoryItemId,
          'p_section': section.wireValue,
          'p_limit': limit.clamp(1, 100),
          'p_offset': offset < 0 ? 0 : offset,
        },
      ),
    );
    return YorksV1InventorySupplierItemTrailWorkspace.fromJson(response);
  }

  @override
  Future<YorksV1InventorySupplierReceiptBatchDetailWorkspace>
  getReceiptBatchDetail({
    required String supplierId,
    required String receiptBatchId,
    YorksV1InventorySupplierReceiptBatchDetailSection section =
        YorksV1InventorySupplierReceiptBatchDetailSection.lines,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_supplier_receipt_batch_detail_projection',
        parameters: {
          'p_supplier_id': supplierId,
          'p_receipt_batch_id': receiptBatchId,
          'p_section': section.wireValue,
          'p_limit': limit.clamp(1, 100),
          'p_offset': offset < 0 ? 0 : offset,
        },
      ),
    );
    return YorksV1InventorySupplierReceiptBatchDetailWorkspace.fromJson(
      response,
    );
  }

  @override
  Future<YorksV1InventorySupplierDirectoryEntry> createSupplier(
    YorksV1InventorySupplierCreateInput input,
  ) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_create_supplier',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    return YorksV1InventorySupplierDirectoryEntry.fromJson(response);
  }

  @override
  Future<YorksV1InventorySupplierImportResult> importInventory(
    YorksV1InventorySupplierImportInput input,
  ) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_import_inventory_r38_9',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    return YorksV1InventorySupplierImportResult.fromJson(response);
  }

  @override
  Future<YorksV1InventorySupplierImportResult> importPrepared({
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) async {
    final response = _object(
      await _invoke(
        functionName: 'v1_import_inventory_r38_9',
        parameters: {
          'p_payload': Map<String, Object?>.unmodifiable(payload),
          'p_idempotency_key': idempotencyKey,
        },
      ),
    );
    return YorksV1InventorySupplierImportResult.fromJson(response);
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    if (!_featureFlags.inventorySuppliers) {
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
      throw _mapPostgrest(error);
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

  static Map<String, dynamic> _object(Object? response) {
    if (response is! Map) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return Map<String, dynamic>.from(response);
  }

  static YorksV1DomainException _mapPostgrest(PostgrestException error) {
    final message = error.message.toUpperCase();
    final code = switch (message) {
      final value when value.contains('INVENTORY_IMPORT') =>
        switch (error.code) {
          '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
          '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
          _ => YorksV1DomainErrorCode.invalidInput,
        },
      _ => switch (error.code) {
        '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
        '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
        '22023' ||
        '22007' ||
        '22P02' ||
        '23514' => YorksV1DomainErrorCode.invalidInput,
        _ => YorksV1DomainErrorCode.serverRejected,
      },
    };
    return YorksV1DomainException(code, serverCode: error.code, cause: error);
  }
}

String? _trimToNull(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
