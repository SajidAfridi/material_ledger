import '../../../../shared/models/yorks_v1_team_chat.dart';

const yorksWorkforceCollaborationSchema = 'yorks.workforce.collaboration.v1';
const yorksWorkforceDiscussionSchema = 'yorks.workforce.discussion.v1';
const yorksWorkforceDiscussionMessageSchema =
    'yorks.workforce.discussion.message.v1';
const yorksWorkforceDocumentsSchema = 'yorks.workforce.documents.v1';
const yorksWorkforceDocumentUploadSchema = 'yorks.workforce.document-upload.v1';

enum YorksWorkforceEvidenceType {
  medicalCertificate('medical_certificate'),
  leaveDocument('leave_document'),
  overtimeAuthorization('overtime_authorization'),
  workerTransferNote('worker_transfer_note'),
  siteAttendanceSheet('site_attendance_sheet'),
  dailySupportingPhoto('daily_supporting_photo'),
  monthlyTimesheetAttachment('monthly_timesheet_attachment'),
  otherWorkforceDocument('other_workforce_document');

  const YorksWorkforceEvidenceType(this.wireValue);

  final String wireValue;

  static YorksWorkforceEvidenceType fromWire(Object? value) =>
      values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => throw const FormatException('Invalid evidence type'),
      );
}

final class YorksWorkforceEvidenceVersion {
  const YorksWorkforceEvidenceVersion({
    required this.id,
    required this.revisionNumber,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.uploadedAt,
  });

  final String id;
  final int revisionNumber;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final DateTime uploadedAt;

  factory YorksWorkforceEvidenceVersion.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceEvidenceVersion(
    id: _uuid(json['version_id']),
    revisionNumber: _positiveInt(json['revision_number']),
    fileName: _requiredString(json['file_name']),
    mimeType: _requiredString(json['mime_type']),
    byteSize: _positiveInt(json['byte_size']),
    sha256: _sha256(json['sha256']),
    uploadedAt: _date(json['uploaded_at']),
  );
}

final class YorksWorkforceEvidenceDocument {
  const YorksWorkforceEvidenceDocument({
    required this.id,
    required this.classification,
    required this.currentVersionId,
    required this.evidenceType,
    required this.versions,
    this.workerId,
    this.attendanceDayId,
    this.periodId,
    this.retainedProjectId,
  });

  final String id;
  final String classification;
  final String currentVersionId;
  final YorksWorkforceEvidenceType evidenceType;
  final String? workerId;
  final String? attendanceDayId;
  final String? periodId;
  final String? retainedProjectId;
  final List<YorksWorkforceEvidenceVersion> versions;

  YorksWorkforceEvidenceVersion get currentVersion => versions.firstWhere(
    (version) => version.id == currentVersionId,
    orElse: () => throw const FormatException('Current version missing'),
  );

  factory YorksWorkforceEvidenceDocument.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    final classification = _requiredString(json['classification']);
    if (classification != 'operational') {
      throw const FormatException('Invalid Workforce classification');
    }
    final versions = _mapList(
      json['versions'],
      YorksWorkforceEvidenceVersion.fromRpcJson,
    );
    if (versions.isEmpty) {
      throw const FormatException('Evidence version history missing');
    }
    final document = YorksWorkforceEvidenceDocument(
      id: _uuid(json['document_id']),
      classification: classification,
      currentVersionId: _uuid(json['current_version_id']),
      evidenceType: YorksWorkforceEvidenceType.fromWire(json['evidence_type']),
      workerId: _nullableUuid(json['worker_id']),
      attendanceDayId: _nullableUuid(json['attendance_day_id']),
      periodId: _nullableUuid(json['period_id']),
      retainedProjectId: _nullableUuid(json['retained_project_id']),
      versions: versions,
    );
    document.currentVersion;
    return document;
  }
}

final class YorksWorkforceEvidenceProjection {
  const YorksWorkforceEvidenceProjection({required this.documents});

  final List<YorksWorkforceEvidenceDocument> documents;

  factory YorksWorkforceEvidenceProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _schema(json, yorksWorkforceDocumentsSchema);
    return YorksWorkforceEvidenceProjection(
      documents: _mapList(
        json['documents'],
        YorksWorkforceEvidenceDocument.fromRpcJson,
      ),
    );
  }
}

final class YorksWorkforceNotificationItem {
  const YorksWorkforceNotificationItem({
    required this.id,
    required this.eventCode,
    required this.createdAt,
    required this.itemCount,
    this.seenAt,
  });

  final String id;
  final String eventCode;
  final DateTime createdAt;
  final DateTime? seenAt;
  final int itemCount;

  bool get isUnread => seenAt == null;

  factory YorksWorkforceNotificationItem.fromRpcJson(
    Map<String, dynamic> json,
  ) => YorksWorkforceNotificationItem(
    id: _uuid(json['notification_id']),
    eventCode: _requiredString(json['event_code']),
    createdAt: _date(json['created_at']),
    seenAt: _nullableDate(json['seen_at']),
    itemCount: _nonNegativeInt(json['item_count'], fallback: 1),
  );
}

final class YorksWorkforceCollaborationProjection {
  const YorksWorkforceCollaborationProjection({
    required this.periodId,
    required this.documents,
    required this.notifications,
    this.discussion,
  });

  final String periodId;
  final YorksV1ChatThread? discussion;
  final List<YorksWorkforceEvidenceDocument> documents;
  final List<YorksWorkforceNotificationItem> notifications;

  int get unreadNotificationCount =>
      notifications.where((item) => item.isUnread).length;

  factory YorksWorkforceCollaborationProjection.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _schema(json, yorksWorkforceCollaborationSchema);
    final discussionJson = json['discussion'];
    if (discussionJson != null && discussionJson is! Map) {
      throw const FormatException('Invalid Workforce discussion');
    }
    return YorksWorkforceCollaborationProjection(
      periodId: _uuid(json['period_id']),
      discussion: discussionJson == null
          ? null
          : YorksV1ChatThread.fromRpcJson(
              Map<String, dynamic>.from(discussionJson),
            ),
      documents: _mapList(
        json['documents'],
        YorksWorkforceEvidenceDocument.fromRpcJson,
      ),
      notifications: _mapList(
        json['notifications'],
        YorksWorkforceNotificationItem.fromRpcJson,
      ),
    );
  }
}

final class YorksWorkforceDiscussionResult {
  const YorksWorkforceDiscussionResult({
    required this.periodId,
    required this.thread,
  });

  final String periodId;
  final YorksV1ChatThread thread;

  factory YorksWorkforceDiscussionResult.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _schema(json, yorksWorkforceDiscussionSchema);
    final conversation = json['conversation'];
    if (conversation is! Map) {
      throw const FormatException('Discussion response missing');
    }
    return YorksWorkforceDiscussionResult(
      periodId: _uuid(json['period_id']),
      thread: YorksV1ChatThread.fromRpcJson(
        Map<String, dynamic>.from(conversation),
      ),
    );
  }
}

final class YorksWorkforceDiscussionMessageResult {
  const YorksWorkforceDiscussionMessageResult({
    required this.periodId,
    required this.message,
    required this.conversation,
  });

  final String periodId;
  final YorksV1ChatMessage message;
  final YorksV1ChatConversation conversation;

  factory YorksWorkforceDiscussionMessageResult.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _schema(json, yorksWorkforceDiscussionMessageSchema);
    final message = json['message'];
    final conversation = json['conversation'];
    if (message is! Map || conversation is! Map) {
      throw const FormatException('Message response missing');
    }
    return YorksWorkforceDiscussionMessageResult(
      periodId: _uuid(json['period_id']),
      message: YorksV1ChatMessage.fromRpcJson(
        Map<String, dynamic>.from(message),
      ),
      conversation: YorksV1ChatConversation.fromRpcJson(
        Map<String, dynamic>.from(conversation),
      ),
    );
  }
}

final class YorksWorkforceDiscussionMessageInput {
  const YorksWorkforceDiscussionMessageInput({
    required this.periodId,
    required this.body,
    this.replyToMessageId,
    this.linkedEntityType,
    this.linkedEntityId,
    this.attachmentIds = const [],
    this.mentionedAuthUserIds = const [],
  });

  final String periodId;
  final String body;
  final String? replyToMessageId;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final List<String> attachmentIds;
  final List<String> mentionedAuthUserIds;

  bool get isValid {
    final linkType = linkedEntityType?.trim();
    final allowedLink =
        linkType == null ||
        linkType.isEmpty ||
        linkType == 'workforce_worker' ||
        linkType == 'workforce_attendance_day' ||
        linkType == 'workforce_monthly_period';
    return _isUuid(periodId.trim()) &&
        body.trim().isNotEmpty &&
        body.trim().length <= 4000 &&
        _nullablePair(linkType, linkedEntityId) &&
        allowedLink &&
        _nullableUuidValid(replyToMessageId) &&
        attachmentIds.length <= 12 &&
        attachmentIds.every(_isUuid) &&
        attachmentIds.toSet().length == attachmentIds.length &&
        mentionedAuthUserIds.length <= 50 &&
        mentionedAuthUserIds.every(_isUuid) &&
        mentionedAuthUserIds.toSet().length == mentionedAuthUserIds.length;
  }

  Map<String, Object?> toRpcJson() => {
    'period_id': periodId.trim(),
    'body': body.trim(),
    if (_trimmed(replyToMessageId) != null)
      'reply_to_message_id': replyToMessageId!.trim(),
    if (_trimmed(linkedEntityType) != null)
      'linked_entity_type': linkedEntityType!.trim(),
    if (_trimmed(linkedEntityId) != null)
      'linked_entity_id': linkedEntityId!.trim(),
    'attachment_ids': attachmentIds,
    'mentioned_auth_user_ids': mentionedAuthUserIds,
  };
}

final class YorksWorkforceEvidenceUploadInput {
  const YorksWorkforceEvidenceUploadInput({
    required this.entityType,
    required this.entityId,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.evidenceType,
    this.documentId,
    this.workerId,
    this.attendanceDayId,
    this.periodId,
  });

  final String entityType;
  final String entityId;
  final String? documentId;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final String sha256;
  final YorksWorkforceEvidenceType evidenceType;
  final String? workerId;
  final String? attendanceDayId;
  final String? periodId;

  bool get isValid {
    final normalizedFile = fileName.trim();
    final normalizedMime = mimeType.trim();
    return const {
          'workforce_worker',
          'workforce_attendance_day',
          'workforce_monthly_period',
        }.contains(entityType.trim()) &&
        _isUuid(entityId.trim()) &&
        _nullableUuidValid(documentId) &&
        normalizedFile.isNotEmpty &&
        normalizedFile.length <= 180 &&
        !normalizedFile.contains('/') &&
        !normalizedFile.contains('\\') &&
        const {
          'application/pdf',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'image/jpeg',
          'image/png',
        }.contains(normalizedMime) &&
        byteSize > 0 &&
        byteSize <= 6291456 &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256.trim()) &&
        _nullableUuidValid(workerId) &&
        _nullableUuidValid(attendanceDayId) &&
        _nullableUuidValid(periodId) &&
        switch (entityType.trim()) {
          'workforce_worker' =>
            workerId == null || workerId?.trim() == entityId.trim(),
          'workforce_attendance_day' =>
            attendanceDayId == null ||
                attendanceDayId?.trim() == entityId.trim(),
          'workforce_monthly_period' =>
            periodId == null || periodId?.trim() == entityId.trim(),
          _ => false,
        };
  }

  Map<String, Object?> toRpcJson() => {
    'entity_type': entityType.trim(),
    'entity_id': entityId.trim(),
    if (_trimmed(documentId) != null) 'document_id': documentId!.trim(),
    'classification': 'operational',
    'file_name': fileName.trim(),
    'mime_type': mimeType.trim(),
    'byte_size': byteSize,
    'sha256': sha256.trim().toLowerCase(),
    'evidence_type': evidenceType.wireValue,
    if (_trimmed(workerId) != null) 'worker_id': workerId!.trim(),
    if (_trimmed(attendanceDayId) != null)
      'attendance_day_id': attendanceDayId!.trim(),
    if (_trimmed(periodId) != null) 'period_id': periodId!.trim(),
  };
}

final class YorksWorkforceEvidenceUploadIntent {
  const YorksWorkforceEvidenceUploadIntent({
    required this.id,
    required this.bucketId,
    required this.objectPath,
    required this.mimeType,
    required this.byteSize,
    required this.expiresAt,
    required this.plannedRevisionNumber,
  });

  final String id;
  final String bucketId;
  final String objectPath;
  final String mimeType;
  final int byteSize;
  final DateTime expiresAt;
  final int plannedRevisionNumber;

  factory YorksWorkforceEvidenceUploadIntent.fromRpcJson(
    Map<String, dynamic> json,
  ) {
    _schema(json, yorksWorkforceDocumentUploadSchema);
    return YorksWorkforceEvidenceUploadIntent(
      id: _uuid(json['upload_intent_id']),
      bucketId: _requiredString(json['bucket_id']),
      objectPath: _requiredString(json['object_path']),
      mimeType: _requiredString(json['mime_type']),
      byteSize: _positiveInt(json['byte_size']),
      expiresAt: _date(json['expires_at']),
      plannedRevisionNumber: _positiveInt(json['planned_revision_number']),
    );
  }
}

void _schema(Map<String, dynamic> json, String expected) {
  if (json['schema_version'] != expected) {
    throw const FormatException('Unsupported Workforce schema');
  }
}

String _requiredString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw const FormatException('Required Workforce field missing');
}

String _uuid(Object? value) {
  final parsed = _requiredString(value);
  if (!_isUuid(parsed)) throw const FormatException('Invalid UUID');
  return parsed;
}

String? _nullableUuid(Object? value) {
  if (value == null) return null;
  return _uuid(value);
}

bool _nullableUuidValid(String? value) =>
    _trimmed(value) == null || _isUuid(value!.trim());

bool _nullablePair(String? left, String? right) =>
    (_trimmed(left) == null) == (_trimmed(right) == null) &&
    _nullableUuidValid(right);

String? _trimmed(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);

DateTime _date(Object? value) {
  if (value is! String) throw const FormatException('Invalid timestamp');
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw const FormatException('Invalid timestamp');
  return parsed.toLocal();
}

DateTime? _nullableDate(Object? value) => value == null ? null : _date(value);

int _positiveInt(Object? value) {
  final parsed = _nonNegativeInt(value);
  if (parsed < 1) throw const FormatException('Positive value required');
  return parsed;
}

int _nonNegativeInt(Object? value, {int? fallback}) {
  if (value == null && fallback != null) return fallback;
  final parsed = switch (value) {
    int number => number,
    num number when number == number.roundToDouble() => number.toInt(),
    String text => int.tryParse(text),
    _ => null,
  };
  if (parsed == null || parsed < 0) {
    throw const FormatException('Invalid count');
  }
  return parsed;
}

String _sha256(Object? value) {
  final parsed = _requiredString(value).toLowerCase();
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(parsed)) {
    throw const FormatException('Invalid digest');
  }
  return parsed;
}

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) parser) {
  if (value is! List) throw const FormatException('Invalid Workforce list');
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) throw const FormatException('Invalid Workforce item');
      return parser(Map<String, dynamic>.from(item));
    }),
  );
}
