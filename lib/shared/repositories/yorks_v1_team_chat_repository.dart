import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/yorks_v1_domain_error.dart';
import '../models/yorks_v1_team_chat.dart';
import '../services/yorks_v1_chat_file_service.dart';
import '../sync/connectivity_service.dart';

abstract interface class YorksV1TeamChatRepository {
  Future<List<YorksV1ChatConversation>> listConversations();

  Future<List<YorksV1ChatConversation>> search(String query);

  Future<YorksV1ChatThread> getConversation(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  });

  Future<List<YorksV1ChatParticipant>> listDirectory();

  Future<List<YorksV1ChatContextTarget>> listContextTargets(
    YorksV1ChatKind kind,
  );

  Future<YorksV1ChatConversation> createConversation(
    YorksV1ChatCreateInput input,
  );

  Future<YorksV1ChatConversation> updateGroup(
    YorksV1ChatGroupUpdateInput input,
  );

  Future<YorksV1PendingChatAttachment> uploadAttachment({
    required String conversationId,
    required YorksV1SelectedChatFile file,
  });

  Future<YorksV1ChatMessage> sendMessage(YorksV1ChatSendInput input);

  Future<void> markRead(String conversationId);

  Future<void> markUnread(String conversationId);

  Future<void> setPreference({
    required String conversationId,
    required String preference,
    required bool enabled,
  });

  Future<void> toggleAcknowledgement(String messageId);

  Future<void> toggleMessagePin(String messageId);

  Future<({Uint8List bytes, String fileName, String mimeType})>
  downloadAttachment(String attachmentId);
}

class YorksV1SupabaseTeamChatRepository implements YorksV1TeamChatRepository {
  const YorksV1SupabaseTeamChatRepository({
    required SupabaseClient client,
    required ConnectivityService connectivity,
  }) : _client = client,
       _connectivity = connectivity;

  final SupabaseClient _client;
  final ConnectivityService _connectivity;

  void _requireOnline() {
    if (!_connectivity.isOnline) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.offline);
    }
    if (_client.auth.currentUser == null) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unauthenticated,
      );
    }
  }

  @override
  Future<List<YorksV1ChatConversation>> listConversations() async {
    final response = await _rpc('v1_list_chat_conversations');
    return _conversationList(response);
  }

  @override
  Future<List<YorksV1ChatConversation>> search(String query) async {
    final response = await _rpc(
      'v1_search_chat',
      parameters: {'p_query': query.trim(), 'p_limit': 80},
    );
    return _conversationList(response);
  }

  List<YorksV1ChatConversation> _conversationList(Object? response) {
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return List.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          );
        }
        return YorksV1ChatConversation.fromRpcJson(
          Map<String, dynamic>.from(item),
        );
      }),
    );
  }

  @override
  Future<YorksV1ChatThread> getConversation(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    final response = await _rpc(
      'v1_get_chat_conversation',
      parameters: {
        'p_conversation_id': conversationId,
        'p_before': before?.toUtc().toIso8601String(),
        'p_limit': limit,
      },
    );
    return YorksV1ChatThread.fromRpcJson(_map(response));
  }

  @override
  Future<List<YorksV1ChatParticipant>> listDirectory() async {
    final response = await _rpc('v1_list_chat_directory');
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return List.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          );
        }
        return YorksV1ChatParticipant.fromRpcJson(
          Map<String, dynamic>.from(item),
        );
      }),
    );
  }

  @override
  Future<List<YorksV1ChatContextTarget>> listContextTargets(
    YorksV1ChatKind kind,
  ) async {
    if (kind != YorksV1ChatKind.project &&
        kind != YorksV1ChatKind.materialRequest) {
      throw const YorksV1DomainException(YorksV1DomainErrorCode.invalidInput);
    }
    final response = await _rpc(
      'v1_list_chat_context_targets',
      parameters: {'p_kind': kind.wireValue},
    );
    if (response is! List) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    return List.unmodifiable(
      response.map((item) {
        if (item is! Map) {
          throw const YorksV1DomainException(
            YorksV1DomainErrorCode.unexpectedResponse,
          );
        }
        return YorksV1ChatContextTarget.fromRpcJson(
          Map<String, dynamic>.from(item),
        );
      }),
    );
  }

  @override
  Future<YorksV1ChatConversation> createConversation(
    YorksV1ChatCreateInput input,
  ) async {
    final response = _map(
      await _rpc(
        'v1_create_chat_conversation',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    return YorksV1ChatConversation.fromRpcJson(_map(response['conversation']));
  }

  @override
  Future<YorksV1ChatConversation> updateGroup(
    YorksV1ChatGroupUpdateInput input,
  ) async {
    final response = _map(
      await _rpc(
        'v1_update_chat_group',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    return YorksV1ChatConversation.fromRpcJson(_map(response['conversation']));
  }

  @override
  Future<YorksV1PendingChatAttachment> uploadAttachment({
    required String conversationId,
    required YorksV1SelectedChatFile file,
  }) async {
    _requireOnline();
    final digest = sha256.convert(file.bytes).toString();
    final response = _map(
      await _rpc(
        'v1_prepare_chat_attachment',
        parameters: {
          'p_payload': {
            'conversation_id': conversationId,
            'file_name': file.fileName,
            'mime_type': file.mimeType,
            'byte_size': file.bytes.lengthInBytes,
            'sha256': digest,
          },
          'p_idempotency_key': const Uuid().v4(),
        },
      ),
    );
    final pending = YorksV1PendingChatAttachment.fromRpcJson(
      response,
      bytes: file.bytes,
    );
    try {
      await _client.storage
          .from(pending.bucketId)
          .uploadBinary(
            pending.objectPath,
            file.bytes,
            fileOptions: FileOptions(
              contentType: pending.mimeType,
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      if (!error.message.toLowerCase().contains('already exists')) {
        throw _mapError(error);
      }
    } catch (error) {
      throw YorksV1DomainException(
        YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
    try {
      await _client.functions.invoke(
        'finalize-chat-attachment',
        body: {'upload_intent_id': pending.id},
      );
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
    return pending;
  }

  @override
  Future<YorksV1ChatMessage> sendMessage(YorksV1ChatSendInput input) async {
    final response = _map(
      await _rpc(
        'v1_send_chat_message',
        parameters: {
          'p_payload': input.toRpcPayload(),
          'p_idempotency_key': input.idempotencyKey,
        },
      ),
    );
    return YorksV1ChatMessage.fromRpcJson(_map(response['message']));
  }

  @override
  Future<void> markRead(String conversationId) =>
      _voidRpc('v1_mark_chat_read', {'p_conversation_id': conversationId});

  @override
  Future<void> markUnread(String conversationId) =>
      _voidRpc('v1_mark_chat_unread', {'p_conversation_id': conversationId});

  @override
  Future<void> setPreference({
    required String conversationId,
    required String preference,
    required bool enabled,
  }) => _voidRpc('v1_set_chat_preference', {
    'p_conversation_id': conversationId,
    'p_preference': preference,
    'p_enabled': enabled,
  });

  @override
  Future<void> toggleAcknowledgement(String messageId) =>
      _voidRpc('v1_toggle_chat_acknowledgement', {'p_message_id': messageId});

  @override
  Future<void> toggleMessagePin(String messageId) =>
      _voidRpc('v1_toggle_chat_message_pin', {'p_message_id': messageId});

  @override
  Future<({Uint8List bytes, String fileName, String mimeType})>
  downloadAttachment(String attachmentId) async {
    final projection = _map(
      await _rpc(
        'v1_download_chat_attachment',
        parameters: {'p_attachment_id': attachmentId},
      ),
    );
    final bucketId = projection['bucket_id'];
    final objectPath = projection['object_path'];
    final fileName = projection['file_name'];
    final mimeType = projection['mime_type'];
    if (bucketId is! String ||
        objectPath is! String ||
        fileName is! String ||
        mimeType is! String) {
      throw const YorksV1DomainException(
        YorksV1DomainErrorCode.unexpectedResponse,
      );
    }
    try {
      final bytes = await _client.storage.from(bucketId).download(objectPath);
      return (bytes: bytes, fileName: fileName, mimeType: mimeType);
    } catch (error) {
      throw _mapError(error);
    }
  }

  Future<void> _voidRpc(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    await _rpc(functionName, parameters: parameters);
  }

  Future<Object?> _rpc(
    String functionName, {
    Map<String, dynamic>? parameters,
  }) async {
    _requireOnline();
    try {
      return await _client.rpc(functionName, params: parameters);
    } catch (error) {
      throw _mapError(error);
    }
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const YorksV1DomainException(
      YorksV1DomainErrorCode.unexpectedResponse,
    );
  }

  YorksV1DomainException _mapError(Object error) {
    if (error is YorksV1DomainException) return error;
    if (error is PostgrestException) {
      return YorksV1DomainException(
        switch (error.code) {
          '42501' || '28000' => YorksV1DomainErrorCode.unauthorized,
          '22023' || '22P02' => YorksV1DomainErrorCode.invalidInput,
          '23505' || '40001' || '55P03' => YorksV1DomainErrorCode.conflict,
          'PGRST002' || 'PGRST003' => YorksV1DomainErrorCode.backendUnavailable,
          _ => YorksV1DomainErrorCode.serverRejected,
        },
        serverCode: error.code,
        cause: error,
      );
    }
    if (error is StorageException) {
      return YorksV1DomainException(
        error.statusCode == '401' || error.statusCode == '403'
            ? YorksV1DomainErrorCode.unauthorized
            : YorksV1DomainErrorCode.backendUnavailable,
        cause: error,
      );
    }
    return YorksV1DomainException(
      YorksV1DomainErrorCode.backendUnavailable,
      cause: error,
    );
  }
}
