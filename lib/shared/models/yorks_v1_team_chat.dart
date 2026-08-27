import 'dart:typed_data';

import 'yorks_v1_role.dart';

enum YorksV1ChatKind {
  project('project'),
  materialRequest('material_request'),
  direct('direct'),
  group('group'),
  announcement('announcement');

  const YorksV1ChatKind(this.wireValue);
  final String wireValue;

  static YorksV1ChatKind parse(Object? value) => values.firstWhere(
    (kind) => kind.wireValue == value,
    orElse: () => throw const FormatException('Invalid chat kind.'),
  );
}

enum YorksV1ChatFilter {
  all,
  unread,
  projects,
  requests,
  direct,
  groups,
  announcements,
  archived,
}

enum YorksV1ChatReceiptStatus { sent, delivered, read }

class YorksV1ChatParticipant {
  const YorksV1ChatParticipant({
    required this.authUserId,
    required this.displayName,
    required this.exactRole,
    this.isOwner = false,
  });

  final String authUserId;
  final String displayName;
  final YorksV1Role exactRole;
  final bool isOwner;

  factory YorksV1ChatParticipant.fromRpcJson(Map<String, dynamic> json) {
    final role = YorksV1Role.fromServerClaim(json['exact_role']);
    if (role == null) throw const FormatException('Invalid participant role.');
    return YorksV1ChatParticipant(
      authUserId: _requiredString(json['auth_user_id']),
      displayName: _requiredString(json['display_name']),
      exactRole: role,
      isOwner: json['member_role'] == 'owner',
    );
  }
}

class YorksV1ChatAttachment {
  const YorksV1ChatAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int byteSize;

  bool get isImage => mimeType.startsWith('image/');

  factory YorksV1ChatAttachment.fromRpcJson(Map<String, dynamic> json) =>
      YorksV1ChatAttachment(
        id: _requiredString(json['id']),
        fileName: _requiredString(json['file_name']),
        mimeType: _requiredString(json['mime_type']),
        byteSize: _requiredInt(json['byte_size']),
      );
}

class YorksV1ChatReplyPreview {
  const YorksV1ChatReplyPreview({
    required this.id,
    required this.senderDisplayName,
    this.body,
    this.isDeleted = false,
  });

  final String id;
  final String senderDisplayName;
  final String? body;
  final bool isDeleted;

  factory YorksV1ChatReplyPreview.fromRpcJson(Map<String, dynamic> json) =>
      YorksV1ChatReplyPreview(
        id: _requiredString(json['id']),
        senderDisplayName: _requiredString(json['sender_display_name']),
        body: _nullableString(json['body']),
        isDeleted: json['is_deleted'] == true,
      );
}

class YorksV1ChatMessage {
  const YorksV1ChatMessage({
    required this.id,
    required this.conversationId,
    required this.kind,
    required this.createdAt,
    required this.isMine,
    required this.isPinned,
    required this.acknowledgementCount,
    required this.acknowledgedByMe,
    required this.attachments,
    required this.mentionedAuthUserIds,
    this.version = 1,
    this.canEdit = false,
    this.canDelete = false,
    this.recipientCount = 0,
    this.deliveredCount = 0,
    this.readCount = 0,
    this.body,
    this.systemEventCode,
    this.senderAuthUserId,
    this.senderDisplayName,
    this.senderExactRole,
    this.replyToMessageId,
    this.replyPreview,
    this.linkedEntityType,
    this.linkedEntityId,
    this.editedAt,
    this.deletedAt,
  });

  final String id;
  final String conversationId;
  final String kind;
  final String? systemEventCode;
  final String? senderAuthUserId;
  final String? senderDisplayName;
  final YorksV1Role? senderExactRole;
  final String? body;
  final String? replyToMessageId;
  final YorksV1ChatReplyPreview? replyPreview;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final DateTime createdAt;
  final int version;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final bool isMine;
  final bool canEdit;
  final bool canDelete;
  final bool isPinned;
  final int acknowledgementCount;
  final bool acknowledgedByMe;
  final List<YorksV1ChatAttachment> attachments;
  final List<String> mentionedAuthUserIds;
  final int recipientCount;
  final int deliveredCount;
  final int readCount;

  bool get isSystem => kind == 'system';
  bool get isEdited => editedAt != null && deletedAt == null;
  bool get isDeleted => deletedAt != null;

  YorksV1ChatReceiptStatus? get receiptStatus {
    if (!isMine || isSystem) return null;
    if (recipientCount > 0 && readCount >= recipientCount) {
      return YorksV1ChatReceiptStatus.read;
    }
    if (deliveredCount > 0) return YorksV1ChatReceiptStatus.delivered;
    return YorksV1ChatReceiptStatus.sent;
  }

  factory YorksV1ChatMessage.fromRpcJson(Map<String, dynamic> json) {
    final kind = _requiredString(json['kind']);
    if (kind != 'message' && kind != 'system') {
      throw const FormatException('Invalid message kind.');
    }
    final role = YorksV1Role.fromServerClaim(json['sender_exact_role']);
    if (kind == 'message' && role == null) {
      throw const FormatException('Invalid sender role.');
    }
    return YorksV1ChatMessage(
      id: _requiredString(json['id']),
      conversationId: _requiredString(json['conversation_id']),
      kind: kind,
      systemEventCode: _nullableString(json['system_event_code']),
      senderAuthUserId: _nullableString(json['sender_auth_user_id']),
      senderDisplayName: _nullableString(json['sender_display_name']),
      senderExactRole: role,
      body: _nullableString(json['body']),
      replyToMessageId: _nullableString(json['reply_to_message_id']),
      replyPreview: json['reply_preview'] is Map
          ? YorksV1ChatReplyPreview.fromRpcJson(
              Map<String, dynamic>.from(json['reply_preview'] as Map),
            )
          : null,
      linkedEntityType: _nullableString(json['linked_entity_type']),
      linkedEntityId: _nullableString(json['linked_entity_id']),
      createdAt: DateTime.parse(_requiredString(json['created_at'])).toLocal(),
      version: _optionalInt(json['version'], fallback: 1),
      editedAt: _nullableDate(json['edited_at']),
      deletedAt: _nullableDate(json['deleted_at']),
      isMine: json['is_mine'] == true,
      canEdit: json['can_edit'] == true,
      canDelete: json['can_delete'] == true,
      isPinned: json['is_pinned'] == true,
      acknowledgementCount: _requiredInt(json['acknowledgement_count']),
      acknowledgedByMe: json['acknowledged_by_me'] == true,
      attachments: _mapList(
        json['attachments'],
        YorksV1ChatAttachment.fromRpcJson,
      ),
      mentionedAuthUserIds: _stringList(json['mentions']),
      recipientCount: _optionalInt(json['recipient_count']),
      deliveredCount: _optionalInt(json['delivered_count']),
      readCount: _optionalInt(json['read_count']),
    );
  }
}

class YorksV1ChatConversation {
  const YorksV1ChatConversation({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isPinned,
    required this.isMuted,
    required this.isArchived,
    required this.unreadCount,
    required this.participantCount,
    this.description,
    this.projectId,
    this.materialRequestId,
    this.lastMessageAt,
    this.lastMessage,
    this.searchPreview,
  });

  final String id;
  final YorksV1ChatKind kind;
  final String title;
  final String? description;
  final String? projectId;
  final String? materialRequestId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final int unreadCount;
  final int participantCount;
  final YorksV1ChatMessage? lastMessage;
  final String? searchPreview;

  bool get hasUnread => unreadCount > 0;

  factory YorksV1ChatConversation.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksV1ChatConversation(
    id: _requiredString(json['id']),
    kind: YorksV1ChatKind.parse(json['kind']),
    title: _requiredString(json['title']),
    description: _nullableString(json['description']),
    projectId: _nullableString(json['project_id']),
    materialRequestId: _nullableString(json['material_request_id']),
    createdAt: DateTime.parse(_requiredString(json['created_at'])).toLocal(),
    updatedAt: DateTime.parse(_requiredString(json['updated_at'])).toLocal(),
    lastMessageAt: _nullableDate(json['last_message_at']),
    isPinned: json['is_pinned'] == true,
    isMuted: json['is_muted'] == true,
    isArchived: json['is_archived'] == true,
    unreadCount: _requiredInt(json['unread_count']),
    participantCount: _requiredInt(json['participant_count']),
    lastMessage: json['last_message'] is Map
        ? YorksV1ChatMessage.fromRpcJson(
            Map<String, dynamic>.from(json['last_message'] as Map),
          )
        : null,
    searchPreview: _nullableString(json['search_preview']),
  );
}

class YorksV1ChatContextTarget {
  const YorksV1ChatContextTarget({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.projectId,
  });

  final String id;
  final YorksV1ChatKind kind;
  final String title;
  final String subtitle;
  final String projectId;

  factory YorksV1ChatContextTarget.fromRpcJson(Map<String, dynamic> json) =>
      YorksV1ChatContextTarget(
        id: _requiredString(json['id']),
        kind: YorksV1ChatKind.parse(json['kind']),
        title: _requiredString(json['title']),
        subtitle: _requiredString(json['subtitle']),
        projectId: _requiredString(json['project_id']),
      );
}

class YorksV1ChatThread {
  const YorksV1ChatThread({
    required this.conversation,
    required this.participants,
    required this.messages,
  });

  final YorksV1ChatConversation conversation;
  final List<YorksV1ChatParticipant> participants;
  final List<YorksV1ChatMessage> messages;

  factory YorksV1ChatThread.fromRpcJson(Map<String, dynamic> json) =>
      YorksV1ChatThread(
        conversation: YorksV1ChatConversation.fromRpcJson(json),
        participants: _mapList(
          json['participants'],
          YorksV1ChatParticipant.fromRpcJson,
        ),
        messages: _mapList(json['messages'], YorksV1ChatMessage.fromRpcJson),
      );
}

class YorksV1ChatCreateInput {
  const YorksV1ChatCreateInput({
    required this.kind,
    required this.idempotencyKey,
    this.title,
    this.description,
    this.participantAuthUserIds = const [],
    this.projectId,
    this.materialRequestId,
  });

  final YorksV1ChatKind kind;
  final String idempotencyKey;
  final String? title;
  final String? description;
  final List<String> participantAuthUserIds;
  final String? projectId;
  final String? materialRequestId;

  Map<String, dynamic> toRpcPayload() => {
    'kind': kind.wireValue,
    if (title != null) 'title': title!.trim(),
    if (description != null) 'description': description!.trim(),
    'participant_auth_user_ids': participantAuthUserIds,
    if (projectId != null) 'project_id': projectId,
    if (materialRequestId != null) 'material_request_id': materialRequestId,
  };
}

class YorksV1PendingChatAttachment {
  const YorksV1PendingChatAttachment({
    required this.id,
    required this.bucketId,
    required this.objectPath,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    this.bytes,
  });

  final String id;
  final String bucketId;
  final String objectPath;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final Uint8List? bytes;

  factory YorksV1PendingChatAttachment.fromRpcJson(
    Map<String, dynamic> json, {
    Uint8List? bytes,
  }) => YorksV1PendingChatAttachment(
    id: _requiredString(json['attachment_id']),
    bucketId: _requiredString(json['bucket_id']),
    objectPath: _requiredString(json['object_path']),
    fileName: _requiredString(json['file_name']),
    mimeType: _requiredString(json['mime_type']),
    byteSize: _requiredInt(json['byte_size']),
    sha256: _requiredString(json['sha256']),
    bytes: bytes,
  );
}

class YorksV1ChatGroupUpdateInput {
  const YorksV1ChatGroupUpdateInput({
    required this.conversationId,
    required this.idempotencyKey,
    required this.title,
    required this.participantAuthUserIds,
    this.description,
  });

  final String conversationId;
  final String idempotencyKey;
  final String title;
  final String? description;
  final List<String> participantAuthUserIds;

  Map<String, dynamic> toRpcPayload() => {
    'conversation_id': conversationId,
    'title': title.trim(),
    if (description != null) 'description': description!.trim(),
    'participant_auth_user_ids': participantAuthUserIds,
  };
}

class YorksV1ChatSendInput {
  const YorksV1ChatSendInput({
    required this.conversationId,
    required this.idempotencyKey,
    this.body,
    this.replyToMessageId,
    this.linkedEntityType,
    this.linkedEntityId,
    this.attachmentIds = const [],
    this.mentionedAuthUserIds = const [],
  });

  final String conversationId;
  final String idempotencyKey;
  final String? body;
  final String? replyToMessageId;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final List<String> attachmentIds;
  final List<String> mentionedAuthUserIds;

  Map<String, dynamic> toRpcPayload() => {
    'conversation_id': conversationId,
    if (body != null) 'body': body!.trim(),
    if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
    if (linkedEntityType != null) 'linked_entity_type': linkedEntityType,
    if (linkedEntityId != null) 'linked_entity_id': linkedEntityId,
    'attachment_ids': attachmentIds,
    'mentioned_auth_user_ids': mentionedAuthUserIds,
  };
}

class YorksV1ChatEditInput {
  const YorksV1ChatEditInput({
    required this.messageId,
    required this.body,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String messageId;
  final String body;
  final int expectedVersion;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => {
    'message_id': messageId,
    'body': body.trim(),
    'expected_version': expectedVersion,
  };
}

class YorksV1ChatDeleteInput {
  const YorksV1ChatDeleteInput({
    required this.messageId,
    required this.expectedVersion,
    required this.idempotencyKey,
  });

  final String messageId;
  final int expectedVersion;
  final String idempotencyKey;

  Map<String, dynamic> toRpcPayload() => {
    'message_id': messageId,
    'expected_version': expectedVersion,
  };
}

DateTime? _nullableDate(Object? value) => value is String && value.isNotEmpty
    ? DateTime.parse(value).toLocal()
    : null;

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException('Missing chat field.');
}

String? _nullableString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

int _requiredInt(Object? value) => switch (value) {
  int count => count,
  num count => count.toInt(),
  String count => int.parse(count),
  _ => throw const FormatException('Invalid chat number.'),
};

int _optionalInt(Object? value, {int fallback = 0}) =>
    value == null ? fallback : _requiredInt(value);

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) parser) {
  if (value == null) return const [];
  if (value is! List) throw const FormatException('Invalid chat list.');
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) throw const FormatException('Invalid chat item.');
      return parser(Map<String, dynamic>.from(item));
    }),
  );
}

List<String> _stringList(Object? value) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Invalid chat identifiers.');
  }
  return List.unmodifiable(value.cast<String>());
}
