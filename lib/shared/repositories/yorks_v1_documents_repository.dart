import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yorks_v1_document.dart';
import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_feature_flags.dart';
import '../sync/connectivity_service.dart';
import 'yorks_v1_material_request_repository.dart';

/// A narrow Storage/Edge/RPC boundary. Widgets never receive a Supabase client,
/// unrestricted Storage path, or a chance to forge document finalization.
abstract interface class YorksV1DocumentStorageClient {
  Future<void> upload({
    required String bucketId,
    required String objectPath,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<Uint8List> download({
    required String bucketId,
    required String objectPath,
  });
}

abstract interface class YorksV1DocumentFinalizerClient {
  Future<Object?> finalize(String uploadIntentId);
}

class SupabaseYorksV1DocumentStorageClient
    implements YorksV1DocumentStorageClient {
  const SupabaseYorksV1DocumentStorageClient(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload({
    required String bucketId,
    required String objectPath,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await _client.storage
        .from(bucketId)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
  }

  @override
  Future<Uint8List> download({
    required String bucketId,
    required String objectPath,
  }) => _client.storage.from(bucketId).download(objectPath);
}

class SupabaseYorksV1DocumentFinalizerClient
    implements YorksV1DocumentFinalizerClient {
  const SupabaseYorksV1DocumentFinalizerClient(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> finalize(String uploadIntentId) async {
    final response = await _client.functions.invoke(
      'finalize-document-upload',
      body: {'upload_intent_id': uploadIntentId},
    );
    return response.data;
  }
}

abstract interface class YorksV1DocumentsRepository {
  Future<YorksV1DocumentWorkspace> getWorkspace(String projectId);

  Future<YorksV1DocumentWorkspace> upload(YorksV1DocumentUploadInput input);

  Future<void> linkDocument(YorksV1DocumentLinkInput input);

  Future<void> removeDocumentLink(YorksV1DocumentLinkRemovalInput input);

  Future<Uint8List> downloadDocument({
    required String bucketId,
    required String objectPath,
  });
}

class YorksV1SupabaseDocumentsRepository implements YorksV1DocumentsRepository {
  const YorksV1SupabaseDocumentsRepository({
    required YorksV1FeatureFlags featureFlags,
    required ConnectivityService connectivity,
    YorksV1MaterialRequestRpcClient? rpcClient,
    YorksV1DocumentStorageClient? storageClient,
    YorksV1DocumentFinalizerClient? finalizerClient,
  }) : _featureFlags = featureFlags,
       _connectivity = connectivity,
       _rpcClient = rpcClient,
       _storageClient = storageClient,
       _finalizerClient = finalizerClient;

  final YorksV1FeatureFlags _featureFlags;
  final ConnectivityService _connectivity;
  final YorksV1MaterialRequestRpcClient? _rpcClient;
  final YorksV1DocumentStorageClient? _storageClient;
  final YorksV1DocumentFinalizerClient? _finalizerClient;

  @override
  Future<YorksV1DocumentWorkspace> getWorkspace(String projectId) async {
    final response = await _invoke(
      functionName: 'v1_document_workspace_projection',
      parameters: {'p_project_id': projectId},
    );
    return _workspace(response);
  }

  @override
  Future<YorksV1DocumentWorkspace> upload(
    YorksV1DocumentUploadInput input,
  ) async {
    _requireReady();
    final rpc = _rpcClient!;
    final storage = _storageClient;
    final finalizer = _finalizerClient;
    if (storage == null || finalizer == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    final hash = sha256.convert(input.bytes).toString();
    final intent = _intent(
      await _rpc(
        rpc,
        functionName: 'v1_prepare_document_upload',
        parameters: {
          'p_payload': input.toRpcPayload(hash),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    if (intent.finalizedDocumentId == null) {
      try {
        await storage.upload(
          bucketId: intent.bucketId,
          objectPath: intent.objectPath,
          bytes: input.bytes,
          mimeType: intent.mimeType,
        );
      } on StorageException catch (error) {
        // A retry after an ambiguous transport failure may encounter the same
        // immutable object. The server finalizer remains the authority.
        if (!error.message.toLowerCase().contains('already exists')) rethrow;
      } catch (error) {
        throw YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        );
      }
      try {
        await finalizer.finalize(intent.id);
      } on FunctionException catch (error) {
        throw YorksV1DomainException(
          error.status == 401 || error.status == 403
              ? YorksV1DomainErrorCode.unauthorized
              : YorksV1DomainErrorCode.conflict,
          cause: error,
        );
      } catch (error) {
        throw YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
          cause: error,
        );
      }
    }
    return getWorkspace(input.projectId);
  }

  @override
  Future<void> linkDocument(YorksV1DocumentLinkInput input) async {
    await _invoke(
      functionName: 'v1_link_document',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
  }

  @override
  Future<void> removeDocumentLink(YorksV1DocumentLinkRemovalInput input) async {
    await _invoke(
      functionName: 'v1_remove_document_link',
      parameters: {
        'p_payload': input.toRpcPayload(),
        'p_idempotency_key': input.idempotencyKey,
      },
    );
  }

  @override
  Future<Uint8List> downloadDocument({
    required String bucketId,
    required String objectPath,
  }) async {
    _requireReady();
    final storage = _storageClient;
    if (storage == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
    try {
      return await storage.download(bucketId: bucketId, objectPath: objectPath);
    } on StorageException catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.unauthorized,
        cause: error,
      );
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  Future<Object?> _invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    _requireReady();
    return _rpc(
      _rpcClient!,
      functionName: functionName,
      parameters: parameters,
    );
  }

  Future<Object?> _rpc(
    YorksV1MaterialRequestRpcClient rpc, {
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    try {
      return await rpc.invoke(
        functionName: functionName,
        parameters: parameters,
      );
    } on YorksV1DomainException {
      rethrow;
    } on PostgrestException catch (error) {
      final code = switch (error.code) {
        '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
        '40001' || '23505' || '55P03' => YorksV1DomainErrorCode.conflict,
        '22023' || '22P02' => YorksV1DomainErrorCode.invalidInput,
        _ => YorksV1DomainErrorCode.backendUnavailable,
      };
      throw YorksV1DomainException(code, cause: error);
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
  }

  void _requireReady() {
    if (!_featureFlags.documents) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.featureDisabled,
      );
    }
    if (!_connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    if (_rpcClient == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
      );
    }
  }

  static YorksV1DocumentWorkspace _workspace(Object? response) {
    if (response is! Map) _unexpected();
    return YorksV1DocumentWorkspace.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static YorksV1DocumentUploadIntent _intent(Object? response) {
    if (response is! Map) _unexpected();
    return YorksV1DocumentUploadIntent.fromRpcJson(
      Map<String, dynamic>.from(response),
    );
  }

  static Never _unexpected() => throw const YorksV1DomainException(
    YorksV1DomainErrorCode.unexpectedResponse,
  );
}
