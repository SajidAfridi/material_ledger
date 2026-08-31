import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ledger/features/workforce/application/workforce_collaboration_controller.dart';
import 'package:material_ledger/features/workforce/data/workforce_repository.dart';
import 'package:material_ledger/features/workforce/domain/workforce_collaboration_models.dart';
import 'package:material_ledger/shared/models/yorks_v1_domain_error.dart';
import 'package:material_ledger/shared/models/yorks_v1_feature_flags.dart';
import 'package:material_ledger/shared/repositories/yorks_v1_documents_repository.dart';
import 'package:material_ledger/shared/services/yorks_v1_critical_command_key_store.dart';
import 'package:material_ledger/shared/sync/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _actorId = '10000000-0000-4000-8000-000000000001';
const _periodId = '81000000-0000-4000-8000-000000000001';
const _conversationId = '82000000-0000-4000-8000-000000000001';
const _messageId = '83000000-0000-4000-8000-000000000001';
const _documentId = '84000000-0000-4000-8000-000000000001';
const _versionId = '85000000-0000-4000-8000-000000000001';
const _notificationId = '86000000-0000-4000-8000-000000000001';
const _intentId = '87000000-0000-4000-8000-000000000001';
const _key = '89000000-0000-4000-8000-000000000001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('T08 collaboration, evidence and notifications decode strictly', () {
    final projection = YorksWorkforceCollaborationProjection.fromRpcJson(
      _collaborationJson(),
    );
    expect(projection.periodId, _periodId);
    expect(projection.discussion?.messages.single.body, 'Please review');
    expect(projection.documents.single.currentVersion.fileName, 'month.pdf');
    expect(projection.unreadNotificationCount, 1);

    expect(
      () => YorksWorkforceCollaborationProjection.fromRpcJson({
        ..._collaborationJson(),
        'schema_version': 'unknown',
      }),
      throwsFormatException,
    );
    expect(
      () => YorksWorkforceEvidenceProjection.fromRpcJson({
        'schema_version': yorksWorkforceDocumentsSchema,
        'documents': [
          {..._documentJson(), 'current_version_id': _messageId},
        ],
      }),
      throwsFormatException,
    );
  });

  test('message and evidence inputs reject forged or malformed shapes', () {
    expect(
      const YorksWorkforceDiscussionMessageInput(
        periodId: _periodId,
        body: 'Review this period',
        linkedEntityType: 'workforce_monthly_period',
        linkedEntityId: _periodId,
      ).isValid,
      isTrue,
    );
    expect(
      const YorksWorkforceDiscussionMessageInput(
        periodId: _periodId,
        body: 'Review',
        linkedEntityType: 'project',
        linkedEntityId: _periodId,
      ).isValid,
      isFalse,
    );
    expect(_uploadInput(Uint8List.fromList([1, 2, 3])).isValid, isTrue);
    expect(
      const YorksWorkforceEvidenceUploadInput(
        entityType: 'workforce_worker',
        entityId: _actorId,
        fileName: 'transfer.pdf',
        mimeType: 'application/pdf',
        byteSize: 3,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        evidenceType: YorksWorkforceEvidenceType.workerTransferNote,
      ).isValid,
      isTrue,
    );
    expect(
      const YorksWorkforceEvidenceUploadInput(
        entityType: 'workforce_monthly_period',
        entityId: _periodId,
        fileName: 'month.pdf',
        mimeType: 'application/pdf',
        byteSize: 3,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        evidenceType: YorksWorkforceEvidenceType.monthlyTimesheetAttachment,
      ).isValid,
      isTrue,
    );
    expect(
      const YorksWorkforceEvidenceUploadInput(
        entityType: 'workforce_monthly_period',
        entityId: _periodId,
        fileName: 'month.pdf',
        mimeType: 'application/pdf',
        byteSize: 3,
        sha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        evidenceType: YorksWorkforceEvidenceType.monthlyTimesheetAttachment,
        periodId: _conversationId,
      ).isValid,
      isFalse,
    );
    expect(
      YorksWorkforceEvidenceUploadInput(
        entityType: 'workforce_monthly_period',
        entityId: _periodId,
        fileName: '../month.pdf',
        mimeType: 'application/pdf',
        byteSize: 3,
        sha256: List.filled(64, 'a').join(),
        evidenceType: YorksWorkforceEvidenceType.monthlyTimesheetAttachment,
        periodId: _periodId,
      ).isValid,
      isFalse,
    );
  });

  test(
    'repository fails closed for flag, offline, backend and malformed data',
    () async {
      final rpc = _RpcClient((name, parameters) => const {});
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: const YorksV1FeatureFlags(),
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).getCollaboration(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.featureDisabled)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(false),
          rpcClient: rpc,
        ).getCollaboration(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.offline)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
        ).getCollaboration(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.backendUnavailable)),
      );
      await expectLater(
        YorksSupabaseWorkforceRepository(
          featureFlags: _workforceFlags,
          connectivity: const _Connectivity(true),
          rpcClient: rpc,
        ).getCollaboration(_periodId),
        throwsA(_domainCode(YorksV1DomainErrorCode.unexpectedResponse)),
      );
    },
  );

  test(
    'repository maps dedicated RPCs and completes immutable upload',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final rpc = _RpcClient((name, parameters) {
        return switch (name) {
          'v1_get_workforce_collaboration' => _collaborationJson(),
          'v1_open_workforce_timesheet_discussion' => {
            'schema_version': yorksWorkforceDiscussionSchema,
            'period_id': _periodId,
            'conversation': _threadJson(),
          },
          'v1_send_workforce_timesheet_message' => {
            'schema_version': yorksWorkforceDiscussionMessageSchema,
            'period_id': _periodId,
            'message': _messageJson(),
            'conversation': _conversationJson(),
          },
          'v1_prepare_workforce_document_upload' => _intentJson(),
          'v1_list_workforce_documents' => {
            'schema_version': yorksWorkforceDocumentsSchema,
            'documents': [_documentJson()],
          },
          _ => const <String, dynamic>{},
        };
      });
      final storage = _StorageClient();
      final finalizer = _FinalizerClient();
      final repository = YorksSupabaseWorkforceRepository(
        featureFlags: _workforceFlags,
        connectivity: const _Connectivity(true),
        rpcClient: rpc,
        documentStorageClient: storage,
        documentFinalizerClient: finalizer,
      );

      expect(
        (await repository.getCollaboration(_periodId)).periodId,
        _periodId,
      );
      expect(
        (await repository.openDiscussion(
          periodId: _periodId,
          idempotencyKey: _key,
        )).thread.conversation.id,
        _conversationId,
      );
      expect(
        (await repository.sendDiscussionMessage(
          const YorksWorkforceDiscussionMessageInput(
            periodId: _periodId,
            body: 'Please review',
          ),
          idempotencyKey: _key,
        )).message.id,
        _messageId,
      );
      final evidence = await repository.uploadEvidence(
        _uploadInput(bytes),
        bytes: bytes,
        idempotencyKey: _key,
      );
      expect(evidence.documents.single.id, _documentId);
      expect(storage.uploads, 1);
      expect(finalizer.intentIds, [_intentId]);
      expect(
        rpc.calls,
        containsAllInOrder([
          'v1_get_workforce_collaboration',
          'v1_open_workforce_timesheet_discussion',
          'v1_send_workforce_timesheet_message',
          'v1_prepare_workforce_document_upload',
          'v1_list_workforce_documents',
        ]),
      );
    },
  );

  test(
    'uncertain message retry keeps one key and authority loss purges',
    () async {
      final repository = _CollaborationRepository(
        messageFailure: const YorksV1DomainException(
          YorksV1DomainErrorCode.backendUnavailable,
        ),
      );
      final preferences = await SharedPreferences.getInstance();
      final controller = YorksWorkforceCollaborationController(
        repository: repository,
        commandKeys: YorksV1CriticalCommandKeyStore(
          preferences: preferences,
          actorAuthUserId: _actorId,
          uuidFactory: () => _key,
        ),
        connectivity: const _Connectivity(true),
      );
      addTearDown(controller.dispose);
      expect(await controller.load(_periodId), isTrue);
      const input = YorksWorkforceDiscussionMessageInput(
        periodId: _periodId,
        body: 'Please review',
      );
      expect(await controller.sendMessage(input), isFalse);
      expect(
        controller.state.status,
        YorksWorkforceCollaborationStatus.uncertain,
      );
      expect(await controller.sendMessage(input), isFalse);
      expect(repository.messageKeys, [_key, _key]);
      controller.purgeProtectedState();
      expect(
        controller.state.status,
        YorksWorkforceCollaborationStatus.forbidden,
      );
      expect(controller.state.projection, isNull);
    },
  );
}

YorksWorkforceEvidenceUploadInput _uploadInput(Uint8List bytes) =>
    YorksWorkforceEvidenceUploadInput(
      entityType: 'workforce_monthly_period',
      entityId: _periodId,
      fileName: 'month.pdf',
      mimeType: 'application/pdf',
      byteSize: bytes.lengthInBytes,
      sha256: sha256.convert(bytes).toString(),
      evidenceType: YorksWorkforceEvidenceType.monthlyTimesheetAttachment,
      periodId: _periodId,
    );

Map<String, dynamic> _collaborationJson() => {
  'schema_version': yorksWorkforceCollaborationSchema,
  'period_id': _periodId,
  'discussion': _threadJson(),
  'documents': [_documentJson()],
  'notifications': [
    {
      'notification_id': _notificationId,
      'event_code': 'workforce_period_submitted',
      'created_at': '2026-08-30T10:00:00Z',
      'seen_at': null,
      'item_count': null,
    },
  ],
};

Map<String, dynamic> _threadJson() => {
  ..._conversationJson(),
  'participants': [
    {
      'auth_user_id': _actorId,
      'display_name': 'Faisal Ahmed',
      'exact_role': 'admin',
      'member_role': 'owner',
    },
  ],
  'messages': [_messageJson()],
};

Map<String, dynamic> _conversationJson() => {
  'id': _conversationId,
  'kind': 'group',
  'title': 'Nexus 4 · Aug 2026',
  'description': 'Timesheet Discussion',
  'project_id': null,
  'material_request_id': null,
  'created_at': '2026-08-30T09:00:00Z',
  'updated_at': '2026-08-30T10:00:00Z',
  'last_message_at': '2026-08-30T10:00:00Z',
  'is_pinned': false,
  'is_muted': false,
  'is_archived': false,
  'unread_count': 0,
  'participant_count': 1,
  'last_message': _messageJson(),
  'search_preview': null,
};

Map<String, dynamic> _messageJson() => {
  'id': _messageId,
  'conversation_id': _conversationId,
  'kind': 'message',
  'system_event_code': null,
  'sender_auth_user_id': _actorId,
  'sender_display_name': 'Faisal Ahmed',
  'sender_exact_role': 'admin',
  'body': 'Please review',
  'reply_to_message_id': null,
  'reply_preview': null,
  'linked_entity_type': 'workforce_monthly_period',
  'linked_entity_id': _periodId,
  'created_at': '2026-08-30T10:00:00Z',
  'version': 1,
  'edited_at': null,
  'deleted_at': null,
  'is_mine': true,
  'can_edit': true,
  'can_delete': true,
  'is_pinned': false,
  'acknowledgement_count': 0,
  'acknowledged_by_me': false,
  'attachments': const [],
  'mentions': const [],
  'recipient_count': 1,
  'delivered_count': 0,
  'read_count': 0,
};

Map<String, dynamic> _documentJson() => {
  'document_id': _documentId,
  'classification': 'operational',
  'current_version_id': _versionId,
  'evidence_type': 'monthly_timesheet_attachment',
  'worker_id': null,
  'attendance_day_id': null,
  'period_id': _periodId,
  'retained_project_id': null,
  'versions': [
    {
      'version_id': _versionId,
      'revision_number': 1,
      'file_name': 'month.pdf',
      'mime_type': 'application/pdf',
      'byte_size': 3,
      'sha256': sha256.convert([1, 2, 3]).toString(),
      'uploaded_at': '2026-08-30T10:00:00Z',
    },
  ],
};

Map<String, dynamic> _intentJson() => {
  'schema_version': yorksWorkforceDocumentUploadSchema,
  'upload_intent_id': _intentId,
  'bucket_id': 'yorks-documents',
  'object_path': 'documents/workforce/$_intentId/content',
  'mime_type': 'application/pdf',
  'byte_size': 3,
  'expires_at': '2026-08-30T10:15:00Z',
  'planned_revision_number': 1,
};

final class _RpcClient implements YorksWorkforceRpcClient {
  _RpcClient(this.handler);

  final Map<String, dynamic> Function(
    String name,
    Map<String, Object?> parameters,
  )
  handler;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> invoke({
    required String functionName,
    required Map<String, Object?> parameters,
  }) async {
    calls.add(functionName);
    return handler(functionName, parameters);
  }
}

final class _StorageClient implements YorksV1DocumentStorageClient {
  int uploads = 0;

  @override
  Future<Uint8List> download({
    required String bucketId,
    required String objectPath,
  }) async => Uint8List(0);

  @override
  Future<void> upload({
    required String bucketId,
    required String objectPath,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    uploads += 1;
  }
}

final class _FinalizerClient implements YorksV1DocumentFinalizerClient {
  final List<String> intentIds = [];

  @override
  Future<Object?> finalize(String uploadIntentId) async {
    intentIds.add(uploadIntentId);
    return const {};
  }
}

final class _CollaborationRepository
    implements YorksWorkforceCollaborationRepository {
  _CollaborationRepository({this.messageFailure});

  final YorksV1DomainException? messageFailure;
  final List<String> messageKeys = [];

  @override
  Future<YorksWorkforceCollaborationProjection> getCollaboration(
    String periodId,
  ) async =>
      YorksWorkforceCollaborationProjection.fromRpcJson(_collaborationJson());

  @override
  Future<YorksWorkforceDiscussionResult> openDiscussion({
    required String periodId,
    required String idempotencyKey,
  }) async => YorksWorkforceDiscussionResult.fromRpcJson({
    'schema_version': yorksWorkforceDiscussionSchema,
    'period_id': _periodId,
    'conversation': _threadJson(),
  });

  @override
  Future<YorksWorkforceDiscussionMessageResult> sendDiscussionMessage(
    YorksWorkforceDiscussionMessageInput input, {
    required String idempotencyKey,
  }) async {
    messageKeys.add(idempotencyKey);
    if (messageFailure case final error?) throw error;
    return YorksWorkforceDiscussionMessageResult.fromRpcJson({
      'schema_version': yorksWorkforceDiscussionMessageSchema,
      'period_id': _periodId,
      'message': _messageJson(),
      'conversation': _conversationJson(),
    });
  }

  @override
  Future<YorksWorkforceEvidenceProjection> listEvidence({
    String? periodId,
    String? attendanceDayId,
    String? workerId,
  }) async => YorksWorkforceEvidenceProjection.fromRpcJson({
    'schema_version': yorksWorkforceDocumentsSchema,
    'documents': [_documentJson()],
  });

  @override
  Future<YorksWorkforceEvidenceUploadIntent> prepareEvidenceUpload(
    YorksWorkforceEvidenceUploadInput input, {
    required String idempotencyKey,
  }) async => YorksWorkforceEvidenceUploadIntent.fromRpcJson(_intentJson());

  @override
  Future<YorksWorkforceEvidenceProjection> uploadEvidence(
    YorksWorkforceEvidenceUploadInput input, {
    required Uint8List bytes,
    required String idempotencyKey,
  }) => listEvidence(periodId: input.periodId);
}

final class _Connectivity implements ConnectivityService {
  const _Connectivity(this.isOnline);

  @override
  final bool isOnline;

  @override
  Stream<bool> get onChange => const Stream.empty();
}

const _workforceFlags = YorksV1FeatureFlags(
  foundation: true,
  projects: true,
  boq: true,
  excel: true,
  requests: true,
  arrangement: true,
  logistics: true,
  returnsDocuments: true,
  documents: true,
  workforce: true,
);

Matcher _domainCode(YorksV1DomainErrorCode code) =>
    isA<YorksV1DomainException>().having((error) => error.code, 'code', code);
